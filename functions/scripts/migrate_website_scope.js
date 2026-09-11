"use strict";

const {applicationDefault, initializeApp} = require("firebase-admin/app");
const {FieldValue, getFirestore} = require("firebase-admin/firestore");

function argument(name) {
  const index = process.argv.indexOf(`--${name}`);
  return index >= 0 ? String(process.argv[index + 1] || "").trim() : "";
}

const projectId = argument("project") || process.env.GCLOUD_PROJECT;
const institutionId = argument("institution");
const campusId = argument("campus");
const apply = process.argv.includes("--apply");

if (!projectId || !institutionId || !campusId) {
  throw new Error(
      "Usa --project ID --institution ID --campus ID [--apply].",
  );
}

initializeApp({
  projectId,
  credential: process.argv.includes("--firebase-cli-auth") ?
    require("./cloud_access").cloudCredential() : applicationDefault(),
});
const db = process.argv.includes("--firebase-cli-auth") ?
  new (require("@google-cloud/firestore").Firestore)({
    projectId, credentials: require("./cloud_access").cloudCredentials(),
  }) : getFirestore();

async function run() {
  const [config, pages, submissions] = await Promise.all([
    db.collection("website").doc("config").get(),
    db.collection("website_pages").get(),
    db.collection("website_submissions").get(),
  ]);
  if (!config.exists) throw new Error("No existe website/config.");
  const documents = [config, ...pages.docs, ...submissions.docs];
  const conflicting = documents.filter((document) => {
    const data = document.data() || {};
    return (data.institutionId && data.institutionId !== institutionId) ||
      (data.campusId && data.campusId !== campusId);
  });
  if (conflicting.length) {
    throw new Error(
        `Hay ${conflicting.length} documentos asignados a otro alcance.`,
    );
  }
  const pending = documents.filter((document) => {
    const data = document.data() || {};
    return data.institutionId !== institutionId || data.campusId !== campusId;
  });
  console.log(JSON.stringify({
    projectId,
    institutionId,
    campusId,
    pages: pages.size,
    submissions: submissions.size,
    pending: pending.length,
    apply,
  }, null, 2));
  if (!apply || pending.length === 0) return;

  for (let offset = 0; offset < pending.length; offset += 400) {
    const batch = db.batch();
    for (const document of pending.slice(offset, offset + 400)) {
      batch.update(document.ref, {
        institutionId,
        campusId,
        scopeMigratedAt: FieldValue.serverTimestamp(),
        ...(document.ref.path === "website/config" &&
          typeof document.data()?.revision !== "number" ? {revision: 0} : {}),
        ...(document.ref.parent.id === "website_pages" &&
          typeof document.data()?.publicationRevision !== "number" ?
          {publicationRevision: 0} : {}),
      }, {lastUpdateTime: document.updateTime});
    }
    await batch.commit();
  }
  await db.collection("migration_audit").doc("website_scope_v1").set({
    projectId, institutionId, campusId, updatedDocuments: pending.length,
    completedAt: FieldValue.serverTimestamp(),
  });
  console.log("Alcance institucional del sitio migrado correctamente.");
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
