"use strict";

const {applicationDefault, initializeApp} = require("firebase-admin/app");
const {FieldValue, getFirestore} = require("firebase-admin/firestore");

const projectArg = process.argv.find((value) => value.startsWith("--project="));
const projectId = projectArg?.split("=")[1] || process.env.GOOGLE_CLOUD_PROJECT;
if (!projectId) throw new Error("Indica --project=<firebase-project-id>.");

const apply = process.argv.includes("--apply");
const verify = process.argv.includes("--verify");
const privateFields = ["routeAddress", "direccionRuta"];

const useCli = process.argv.includes("--firebase-cli-auth");
const {cloudCredential, cloudCredentials} = require("./cloud_access");
initializeApp({projectId,
  credential: useCli ? cloudCredential() : applicationDefault()});
const db = useCli ? new (require("@google-cloud/firestore").Firestore)({
  projectId, credentials: cloudCredentials(),
}) : getFirestore();

async function main() {
  const snapshot = await db.collection("user_directory").get();
  const affected = snapshot.docs.filter((document) => privateFields.some(
      (field) => Object.prototype.hasOwnProperty.call(document.data(), field),
  ));
  const summary = {
    projectId,
    mode: verify ? "verify" : apply ? "apply" : "dry-run",
    scanned: snapshot.size,
    affected: affected.length,
  };
  console.log(JSON.stringify(summary, null, 2));

  if (verify) {
    if (affected.length > 0) {
      throw new Error(
          `${affected.length} perfiles publicos conservan campos privados.`,
      );
    }
    return;
  }
  if (!apply || affected.length === 0) return;

  for (let offset = 0; offset < affected.length; offset += 400) {
    const batch = db.batch();
    for (const document of affected.slice(offset, offset + 400)) {
      batch.update(document.ref, {
        routeAddress: FieldValue.delete(),
        direccionRuta: FieldValue.delete(),
      }, {lastUpdateTime: document.updateTime});
    }
    await batch.commit();
  }
  await db.collection("migration_audit").doc("directory_private_fields_v1")
      .set({projectId, removedFields: privateFields,
        updatedDocuments: affected.length,
        completedAt: FieldValue.serverTimestamp()});
  console.log(`Se sanearon ${affected.length} perfiles del directorio.`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
