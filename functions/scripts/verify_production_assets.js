"use strict";
/* eslint-disable max-len */
const {cloudAccess} = require("./cloud_access");
const {TARGET, SOURCE, REAL_USERS, PLAYTEST_FIXTURE_ID} = require("./production_readiness");
const {decode} = require("./production_projection");
const {walk} = require("./migrate_production_assets");
async function main() {
  const request = await cloudAccess();
  const base = `https://firestore.googleapis.com/v1/projects/${TARGET}/databases/(default)/documents`;
  const fixtureRaw = await request(`${base}/test_fixtures/${PLAYTEST_FIXTURE_ID}`);
  const fixture = decode({mapValue: {fields: fixtureRaw.fields}});
  const approvedUsers = new Set([
    ...REAL_USERS,
    ...(fixture.phase === "complete" && fixture.cleanupRequired === true ? fixture.authUids || [] : []),
  ]);
  const urls = new Set();
  let count = 0;
  for (const collection of ["website", "website_pages", "configuracion_colegios", "users", "user_directory"]) {
    const result = await request(`${base}/${collection}?pageSize=100`);
    if (result.nextPageToken) throw new Error("Unexpected verification page count");
    for (const raw of result.documents || []) {
      const id = raw.name.split("/").pop();
      if (["users", "user_directory"].includes(collection) && !approvedUsers.has(id)) throw new Error("Unexpected profile");
      const data = decode({mapValue: {fields: raw.fields}});
      walk(data, (value) => {
        if (value.includes(`${SOURCE}.firebasestorage.app`) || value.includes(`${SOURCE}.appspot.com`)) throw new Error(`QA asset reference in ${collection}/${id}`);
        if (value.startsWith("https://firebasestorage.googleapis.com/")) {
          if (!new URL(value).pathname.startsWith(`/v0/b/${TARGET}.firebasestorage.app/o/`)) throw new Error("Foreign asset bucket");
          urls.add(value);
        }
        return value;
      });
      count++;
    }
  }
  for (const url of urls) {
    const response = await fetch(url, {method: "HEAD"});
    if (!response.ok || !response.headers.get("content-type")?.startsWith("image/")) throw new Error(`Production image is not accessible: HTTP ${response.status}`);
  }
  console.log(JSON.stringify({readOnly: true, inspectedDocuments: count, accessibleImages: urls.size, noQaReferences: true}));
}
main().catch((e) => {
  console.error(e.message); process.exitCode = 1;
});
