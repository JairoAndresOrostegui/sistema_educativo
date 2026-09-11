"use strict";

// Verificación real solo lectura. No crea usuarios ni usa sesiones del colegio.
const assert = require("assert");
const {Firestore} = require("@google-cloud/firestore");
const {Storage} = require("@google-cloud/storage");
const {cloudCredentials} = require("./cloud_access");
const {boundedDownload, descriptor} = require("../protected_downloads");

async function main() {
  if (process.env.FIRESTORE_EMULATOR_HOST ||
      process.env.FIREBASE_STORAGE_EMULATOR_HOST) {
    throw new Error("Este diagnóstico requiere QA real, no emuladores.");
  }
  const projectId = "sistema-educativo-rl";
  const base = `https://us-central1-${projectId}.cloudfunctions.net`;
  const qaOrigin = "https://sistema-educativo-rl.web.app";
  const prodOrigin = "https://liceobilinguerodolfollinas.edu.co";
  const results = [];
  for (const [name, parameter] of [
    ["descargarArchivoProtegido", "fileId"],
    ["descargarAdjuntoProtegido", "attachmentId"],
  ]) {
    const url = `${base}/${name}?${parameter}=probe-no-auth`;
    const unauthenticated = await fetch(url);
    const error = await unauthenticated.json();
    assert.equal(unauthenticated.status, 401);
    assert.equal(error.error.status, "UNAUTHENTICATED");
    assert.ok(unauthenticated.headers.get("cache-control")
        .includes("no-store"));
    results.push({endpoint: name, case: "GET sin sesión", status: 401,
      errorStatus: error.error.status, noStore: true});

    for (const origin of [qaOrigin, prodOrigin]) {
      const response = await fetch(url, {method: "OPTIONS", headers: {
        "origin": origin, "access-control-request-method": "GET",
        "access-control-request-headers": "authorization",
      }});
      const expectedStatus = origin === qaOrigin ? 204 : 403;
      assert.equal(response.status, expectedStatus);
      const allowedOrigin = response.headers.get("access-control-allow-origin");
      assert.equal(allowedOrigin, origin === qaOrigin ? qaOrigin : null);
      if (origin === qaOrigin) {
        assert.equal(response.headers.get("access-control-allow-methods"),
            "GET, OPTIONS");
        assert.equal(response.headers.get("access-control-allow-headers"),
            "Authorization");
      }
      results.push({endpoint: name, case: "OPTIONS", origin,
        status: response.status, allowedOrigin});
    }
  }

  const credentials = cloudCredentials();
  const db = new Firestore({projectId, credentials});
  try {
    const id = "YP41GKKiSTvtGxBhozVL";
    const snapshot = await db.collection("files").doc(id).get();
    assert.ok(snapshot.exists);
    const item = descriptor(snapshot.data(), id, false);
    const bucket = new Storage({projectId, credentials})
        .bucket(`${projectId}.firebasestorage.app`);
    const [metadata] = await bucket.file(item.path).getMetadata();
    assert.equal(metadata.contentType, item.contentType);
    assert.equal(Number(metadata.size), item.sizeBytes);
    assert.ok(!metadata.metadata?.firebaseStorageDownloadTokens);
    const object = bucket.file(item.path, {generation: metadata.generation});
    const bytes = await boundedDownload(object, item.sizeBytes);
    assert.ok(bytes.subarray(0, 5).equals(Buffer.from("%PDF-")));
    results.push({case: "Storage QA lectura administrativa acotada",
      fileId: id, sizeBytes: bytes.length, contentType: item.contentType,
      generationPinned: true, downloadTokenAbsent: true, pdfSignature: true});
  } finally {
    await db.terminate();
  }
  console.log(JSON.stringify({projectId, emulator: false,
    authenticatedHttpUserSessionTested: false, checks: results}, null, 2));
}

main().catch((error) => {
  console.error(error.code || error.message);
  process.exitCode = 1;
});
