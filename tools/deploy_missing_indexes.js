"use strict";

// Additive-only index deployment. No rules, documents, updates or deletions.
const fs = require("node:fs");
const path = require("node:path");
const {indexKey} = require("./release_preflight");
const {cloudAccess} = require("../functions/scripts/cloud_access");
const PROJECTS = new Set([
  "sistema-educativo-rl", "sistema-educativo-rl-prod",
]);

async function listIndexes(request, base) {
  const indexes = [];
  let pageToken = "";
  do {
    const page = await request(`${base}/-/indexes` +
      (pageToken ? `?pageToken=${encodeURIComponent(pageToken)}` : ""));
    indexes.push(...(page.indexes || []));
    pageToken = page.nextPageToken || "";
  } while (pageToken);
  return indexes;
}

async function deployMissingIndexes({projectId, expected, apply = false, request}) {
  if (!PROJECTS.has(projectId)) throw new Error("Project is not allowlisted");
  if (!Array.isArray(expected)) throw new Error("Invalid local indexes");
  const desired = new Map();
  for (const index of expected) {
    if (!/^[A-Za-z0-9_-]+$/.test(index.collectionGroup || "") ||
        !["COLLECTION", "COLLECTION_GROUP"].includes(index.queryScope) ||
        !Array.isArray(index.fields) || index.fields.length < 2) {
      throw new Error("Invalid composite index definition");
    }
    desired.set(indexKey(index), index);
  }
  const base = "https://firestore.googleapis.com/v1/projects/" +
    `${projectId}/databases/(default)/collectionGroups`;
  const before = await listIndexes(request, base);
  const existing = new Set(before.map(indexKey));
  const missing = [...desired.values()].filter((index) =>
    !existing.has(indexKey(index)));
  const operations = [];
  if (apply) {
    for (const index of missing) {
      try {
        const operation = await request(
            `${base}/${index.collectionGroup}/indexes`, "POST", {
              queryScope: index.queryScope,
              fields: index.fields,
            });
        if (operation.error) throw new Error("Index operation failed");
        operations.push({key: indexKey(index), name: operation.name,
          done: operation.done === true});
      } catch (error) {
        // A concurrent release may have created the exact same index.
        if (error.status !== 409) throw error;
        operations.push({key: indexKey(index), alreadyExists: true});
      }
    }
  }
  const after = apply ? await listIndexes(request, base) : before;
  const byKey = new Map(after.map((index) => [indexKey(index), index]));
  const remainingMissing = [...desired.keys()].filter((key) => !byKey.has(key));
  const pending = [...desired.keys()].filter((key) =>
    byKey.has(key) && byKey.get(key).state !== "READY")
      .map((key) => ({key, state: byKey.get(key).state}));
  return {projectId, mode: apply ? "apply-additive" : "dry-run",
    expectedCount: desired.size, liveCountBefore: before.length,
    liveCountAfter: after.length,
    missingBefore: missing.map(indexKey), operations,
    remainingMissing, pending,
    readyCount: desired.size - remainingMissing.length - pending.length};
}

async function main() {
  const args = process.argv.slice(2);
  if (args.some((arg) => arg !== "--apply" && !arg.startsWith("--project="))) {
    throw new Error("Usage: --project=allowlisted-project [--apply]");
  }
  const projectId = args.find((arg) => arg.startsWith("--project="))?.slice(10);
  if (!PROJECTS.has(projectId)) throw new Error("Project is not allowlisted");
  const expected = JSON.parse(fs.readFileSync(
      path.resolve(__dirname, "../firestore.indexes.json"), "utf8")).indexes;
  const result = await deployMissingIndexes({projectId, expected,
    apply: args.includes("--apply"), request: await cloudAccess()});
  const reportDir = path.resolve(__dirname, "../.buildlog");
  fs.mkdirSync(reportDir, {recursive: true});
  fs.writeFileSync(path.join(reportDir,
      `${projectId}-indexes-${result.mode}.json`), JSON.stringify(result, null, 2));
  console.log(JSON.stringify(result, null, 2));
  if (result.pending.some((index) => index.state === "NEEDS_REPAIR")) {
    process.exitCode = 1;
  }
}

if (require.main === module) main().catch((error) => {
  console.error(error.code || error.message);
  process.exitCode = 1;
});
module.exports = {deployMissingIndexes};
