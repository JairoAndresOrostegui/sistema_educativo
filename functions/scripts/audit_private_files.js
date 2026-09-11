"use strict";

// Solo lectura: inventario acotado sin imprimir nombres, URL ni credenciales.
const {Firestore} = require("@google-cloud/firestore");
const {Storage} = require("@google-cloud/storage");
const {cloudCredentials} = require("./cloud_access");

async function main() {
  const projectId = "sistema-educativo-rl";
  const credentials = cloudCredentials();
  const db = new Firestore({projectId, credentials});
  const storage = new Storage({projectId, credentials});
  const snapshot = await db.collection("files").get();
  for (const document of snapshot.docs) {
    const value = document.data();
    if (value.status !== "active") continue;
    const path = value.storagePath || "";
    let metadata;
    if (path) {
      try {
        [metadata] = await storage.bucket(`${projectId}.firebasestorage.app`)
            .file(path).getMetadata();
      } catch (error) {
        metadata = {error: error.code || "unknown"};
      }
    }
    console.log(JSON.stringify({id: document.id, fields: Object.keys(value),
      nameType: typeof value.name, nameLength: value.name?.length,
      extension: typeof value.name === "string" ?
        value.name.split(".").pop().toLowerCase() : null,
      nameIsLastPath: value.name === path.split("/").pop(),
      pathPrefix: path.split("/")[0],
      pathEntityIsId: path.split("/")[1] === document.id, hasPath: !!path,
      contentType: value.contentType, sizeBytes: value.sizeBytes,
      metadata: metadata && {error: metadata.error, size: metadata.size,
        contentType: metadata.contentType, generation: metadata.generation,
        hasDownloadToken: !!metadata.metadata?.firebaseStorageDownloadTokens},
    }));
  }
  await db.terminate();
}

main().catch((error) => {
  console.error(error.code || error.message);
  process.exitCode = 1;
});
