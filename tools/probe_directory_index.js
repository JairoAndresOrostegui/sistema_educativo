"use strict";
// Read-only query-plan probe. Prints no user fields or identifiers.
const path = require("node:path");
const {createRequire} = require("node:module");
const dep = createRequire(path.resolve(__dirname, "../functions/package.json"));
const {Firestore, FieldPath} = dep("@google-cloud/firestore");
const {cloudCredentials} = require("../functions/scripts/cloud_access");

async function main() {
  const projectId = process.argv.find((arg) =>
    arg.startsWith("--project="))?.slice(10);
  if (!["sistema-educativo-rl", "sistema-educativo-rl-prod"].includes(projectId)) {
    throw new Error("Project is not allowlisted");
  }
  const db = new Firestore({projectId, credentials: cloudCredentials()});
  try {
    const directory = db.collection("user_directory");
    const sample = await directory.limit(1).get();
    if (sample.empty) throw new Error("No directory sample to test");
    const item = sample.docs[0];
    const profile = item.data();
    if (!profile.institution || !profile.campus) {
      throw new Error("Directory sample lacks institutional scope");
    }
    const result = await directory
        .where(FieldPath.documentId(), "in", [item.id])
        .where("institution", "==", profile.institution)
        .where("campus", "==", profile.campus)
        .where("status", "==", "activo")
        .where("role", "==", "Estudiante").limit(1).get();
    console.log(JSON.stringify({projectId, indexedQuerySucceeded: true,
      resultCount: result.size}));
  } finally {
    await db.terminate();
  }
}
main().catch((error) => {
  console.error(JSON.stringify({code: error.code || null,
    error: error.details || error.message}));
  process.exitCode = 1;
});
