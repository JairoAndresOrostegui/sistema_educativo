"use strict";

// Migración única QA. No modifica contenido, nombres, rutas ni audiencias.
// Por defecto solo inspecciona; --apply exige un plan completamente válido.
const fs = require("fs");
const path = require("path");
const {Firestore, FieldValue} = require("@google-cloud/firestore");
const {Storage} = require("@google-cloud/storage");
const {cloudCredentials} = require("./cloud_access");
const {boundedDownload, descriptor} = require("../protected_downloads");
const PROJECT = "sistema-educativo-rl";
const IDS = ["Tk9F7DpJ5Zxny4MBHrr9", "YP41GKKiSTvtGxBhozVL",
  "oqykHpgNvKjldwr5uujs", "wAzXl249Z4KHvaS3aD9s"];
const MIGRATION = "private_file_downloads_v1";

function docxContainer(bytes) {
  if (bytes.length < 22 || bytes.readUInt32LE(0) !== 0x04034b50) return false;
  let end = bytes.length - 22;
  const min = Math.max(0, bytes.length - 65557);
  while (end >= min && bytes.readUInt32LE(end) !== 0x06054b50) end--;
  if (end < min || bytes.readUInt16LE(end + 4) !== 0 ||
      bytes.readUInt16LE(end + 6) !== 0) return false;
  const count = bytes.readUInt16LE(end + 10);
  let offset = bytes.readUInt32LE(end + 16);
  const names = new Set();
  for (let index = 0; index < count; index++) {
    if (offset + 46 > end ||
        bytes.readUInt32LE(offset) !== 0x02014b50) return false;
    const nameLength = bytes.readUInt16LE(offset + 28);
    const extraLength = bytes.readUInt16LE(offset + 30);
    const commentLength = bytes.readUInt16LE(offset + 32);
    const next = offset + 46 + nameLength + extraLength + commentLength;
    if (next > end) return false;
    names.add(bytes.subarray(offset + 46, offset + 46 + nameLength)
        .toString("utf8"));
    offset = next;
  }
  return names.has("[Content_Types].xml") && names.has("word/document.xml");
}

async function inspect(db, bucket) {
  const plans = [];
  for (const id of IDS) {
    const snapshot = await db.collection("files").doc(id).get();
    const data = snapshot.data();
    if (!data || data.status !== "active") {
      throw new Error(`Archivo no activo: ${id}`);
    }
    const extension = String(data.name || "").split(".").pop().toLowerCase();
    const expected = extension === "pdf" ? "application/pdf" :
      extension === "docx" ? "application/vnd.openxmlformats-officedocument." +
      "wordprocessingml.document" : null;
    if (!expected) throw new Error(`Extensión ambigua: ${id}`);
    descriptor({...data, contentType: expected}, id, false);
    const object = bucket.file(data.storagePath);
    const [metadata] = await object.getMetadata();
    if (Number(metadata.size) !== data.sizeBytes || !metadata.generation ||
        !metadata.metageneration) {
      throw new Error(`Metadatos inconsistentes: ${id}`);
    }
    const fixed = bucket.file(data.storagePath,
        {generation: metadata.generation});
    let signatureValid;
    if (extension === "docx") {
      const bytes = await boundedDownload(fixed, data.sizeBytes);
      signatureValid = docxContainer(bytes);
    } else {
      const chunks = [];
      for await (const chunk of fixed.createReadStream({start: 0, end: 7})) {
        chunks.push(chunk);
      }
      signatureValid = Buffer.concat(chunks).subarray(0, 5)
          .equals(Buffer.from("%PDF-"));
    }
    if (!signatureValid) throw new Error(`Firma ambigua: ${id}`);
    plans.push({id, snapshot, data, metadata, expected, object});
  }
  return plans;
}

async function main() {
  if (process.env.FIRESTORE_EMULATOR_HOST ||
      process.env.FIREBASE_STORAGE_EMULATOR_HOST) {
    throw new Error("La migración requiere el proyecto QA real explícito.");
  }
  const apply = process.argv.includes("--apply");
  const credentials = cloudCredentials();
  const db = new Firestore({projectId: PROJECT, credentials});
  const bucket = new Storage({projectId: PROJECT, credentials})
      .bucket(`${PROJECT}.firebasestorage.app`);
  try {
    const plans = await inspect(db, bucket);
    console.log(JSON.stringify({projectId: PROJECT, apply,
      files: plans.map((item) => ({id: item.id,
        mimeChanged: item.data.contentType !== item.expected,
        tokenRevocation:
          !!item.metadata.metadata?.firebaseStorageDownloadTokens,
        signatureVerified: true, sizeBytes: item.data.sizeBytes}))}));
    if (!apply) return;
    const backupPath = path.resolve(__dirname,
        "../../.buildlog/private-file-downloads-qa-backup.json");
    if (!fs.existsSync(backupPath)) {
      fs.writeFileSync(backupPath, JSON.stringify({projectId: PROJECT,
        migration: MIGRATION, createdAt: new Date().toISOString(),
        files: plans.map(({id, data, metadata}) => ({id, data, metadata})),
      }, null, 2), {flag: "wx", mode: 0o600});
    }
    const audit = db.collection("migration_audit").doc(MIGRATION);
    await audit.set({projectId: PROJECT, status: "running",
      fileIds: IDS, startedAt: FieldValue.serverTimestamp()}, {merge: true});
    for (const plan of plans) {
      const fresh = await plan.snapshot.ref.get();
      if (!fresh.updateTime.isEqual(plan.snapshot.updateTime)) {
        throw new Error(`Archivo cambió antes de migrar: ${plan.id}`);
      }
      const [updated] = await plan.object.setMetadata({
        contentType: plan.expected,
        metadata: {...(plan.metadata.metadata || {}),
          firebaseStorageDownloadTokens: null},
      }, {ifGenerationMatch: plan.metadata.generation,
        ifMetagenerationMatch: plan.metadata.metageneration});
      if (updated.generation !== plan.metadata.generation ||
          updated.metadata?.firebaseStorageDownloadTokens) {
        throw new Error(`Metadatos no confirmados: ${plan.id}`);
      }
      const batch = db.batch();
      batch.update(plan.snapshot.ref, {contentType: plan.expected,
        privateDownloadMigratedAt: FieldValue.serverTimestamp()},
      {lastUpdateTime: plan.snapshot.updateTime});
      batch.set(audit.collection("files").doc(plan.id), {
        institutionId: plan.data.institutionId, campusId: plan.data.campusId,
        previousContentType: plan.data.contentType, contentType: plan.expected,
        generation: plan.metadata.generation, contentUnchanged: true,
        downloadTokensRevoked: true, completedAt: FieldValue.serverTimestamp(),
      });
      await batch.commit();
    }
    await audit.set({status: "complete",
      completedAt: FieldValue.serverTimestamp()}, {merge: true});
    console.log("Migración QA completada: cuatro objetos, contenido intacto.");
  } finally {
    await db.terminate();
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error.code || error.message);
    process.exitCode = 1;
  });
}
module.exports = {docxContainer};
