"use strict";
// Read-only environment/schema/index inventory. Never prints user credentials.
const fs = require("node:fs");
const path = require("node:path");
const {createRequire} = require("node:module");
const dep = createRequire(path.resolve(__dirname, "../functions/package.json"));
const {initializeApp, deleteApp} = dep("firebase-admin/app");
const {Firestore} = dep("@google-cloud/firestore");
const {getAuth} = dep("firebase-admin/auth");
const {cloudCredential, cloudCredentials, cloudAccess} = require("../functions/scripts/cloud_access");

function indexKey(index) {
  const group = index.collectionGroup || index.name.split("/collectionGroups/")[1].split("/")[0];
  return JSON.stringify([group, index.queryScope, index.fields
      .filter((field) => field.fieldPath !== "__name__")
      .map((field) => [field.fieldPath, field.order || field.arrayConfig])]);
}

async function inspect(projectId) {
  const app = initializeApp({projectId, credential: cloudCredential()}, projectId);
  try {
    const db = new Firestore({projectId, credentials: cloudCredentials()});
    const request = await cloudAccess();
    const [users, website, configs, authUsers] = await Promise.all([
      db.collection("users").get(), db.doc("website/config").get(),
      db.collection("configuracion_colegios").get(), getAuth(app).listUsers(1000),
    ]);
    const liveFunctions = [];
    let functionPageToken = "";
    do {
      const result = await request(`https://cloudfunctions.googleapis.com/v2/projects/${projectId}/locations/us-central1/functions?pageSize=100${functionPageToken ? `&pageToken=${encodeURIComponent(functionPageToken)}` : ""}`);
      liveFunctions.push(...(result.functions || []));
      functionPageToken = result.nextPageToken || "";
    } while (functionPageToken);
    const expected = JSON.parse(fs.readFileSync(path.resolve(__dirname, "../firestore.indexes.json"), "utf8")).indexes;
    const liveIndexes = [];
    let pageToken = "";
    do {
      const result = await request(`https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/collectionGroups/-/indexes${pageToken ? `?pageToken=${encodeURIComponent(pageToken)}` : ""}`);
      liveIndexes.push(...(result.indexes || []));
      pageToken = result.nextPageToken || "";
    } while (pageToken);
    const byIndex = new Map(liveIndexes.map((item) => [indexKey(item), item]));
    const byUid = new Map(authUsers.users.map((item) => [item.uid, item]));
    const privateDocuments = [];
    const {descriptor} = require("../functions/protected_downloads");
    for (const collection of ["files", "message_attachments"]) {
      const snapshot = await db.collection(collection).get();
      let invalidDescriptors = 0;
      for (const document of snapshot.docs) {
        if (!["active", "attached"].includes(document.data().status)) continue;
        try {
          descriptor(document.data(), document.id, collection === "message_attachments");
        } catch {
          invalidDescriptors++;
        }
      }
      privateDocuments.push({collection, count: snapshot.size, invalidDescriptors});
    }
    if (authUsers.pageToken) throw new Error("Auth inventory needs pagination before release");
    const roles = {};
    for (const user of users.docs) roles[user.data().role] = (roles[user.data().role] || 0) + 1;
    return {
      projectId, users: users.size, roles, privateDocuments,
      activeAdultsUnverified: users.docs.filter((item) => item.data().status === "activo" &&
        item.data().role !== "Estudiante" && !byUid.get(item.id)?.emailVerified)
          .map((item) => ({uid: item.id, role: item.data().role})),
      websiteScope: {institutionId: website.data()?.institutionId,
        campusId: website.data()?.campusId, revision: website.data()?.revision},
      institutionConfigs: configs.docs.map((item) => ({id: item.id,
        institutionId: item.data().institutionId, campuses: item.data().sedes})),
      functions: liveFunctions.map((item) => ({
        name: item.name.split("/").pop(), state: item.state, updated: item.updateTime,
      })),
      missingIndexes: expected.filter((item) => !byIndex.has(indexKey(item))),
      pendingIndexes: liveIndexes.filter((item) => item.state !== "READY")
          .map((item) => ({key: indexKey(item), state: item.state})),
    };
  } finally {
    await deleteApp(app);
  }
}

async function main() {
  const project = process.argv.find((item) => item.startsWith("--project="))?.slice(10);
  if (!["sistema-educativo-rl", "sistema-educativo-rl-prod"].includes(project)) {
    throw new Error("Specify --project=QA-or-prod-id");
  }
  const result = await inspect(project);
  const reportDir = path.resolve(__dirname, "../.buildlog");
  fs.mkdirSync(reportDir, {recursive: true});
  fs.writeFileSync(path.join(reportDir, `${project}-preflight.json`), JSON.stringify(result, null, 2));
  const {functions, missingIndexes, ...summary} = result;
  console.log(JSON.stringify({...summary, functionCount: functions.length,
    unhealthyFunctions: functions.filter((item) => item.state !== "ACTIVE"),
    missingIndexes: missingIndexes.length,
    missingIndexCollections: [...new Set(missingIndexes.map((item) => item.collectionGroup))],
  }, null, 2));
}

if (require.main === module) main().catch((error) => {
  console.error(error.code || error.message);
  process.exitCode = 1;
});
module.exports = {indexKey, inspect};
