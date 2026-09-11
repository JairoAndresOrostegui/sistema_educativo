"use strict";
/* eslint-disable max-len */
const {cloudAccess} = require("./cloud_access");
const {SOURCE, REAL_USERS} = require("./production_readiness");
const {decode} = require("./production_projection");
async function main() {
  const request = await cloudAccess();
  const base = `https://firestore.googleapis.com/v1/projects/${SOURCE}/databases/(default)/documents`;
  for (const collection of ["website", "website_pages", "configuracion_colegios", "users"]) {
    const result = await request(`${base}/${collection}?pageSize=100`);
    if (result.nextPageToken) throw new Error("Add pagination before inspecting more documents");
    for (const doc of result.documents || []) {
      const id = doc.name.split("/").pop();
      if (collection === "users" && !REAL_USERS.includes(id)) continue;
      const data = decode({mapValue: {fields: doc.fields}});
      const urls = [];
      const walk = (value, field) => {
        if (typeof value === "string" && /^https?:/.test(value)) {
          const url = new URL(value);
          urls.push({field, origin: url.origin, path: url.pathname});
        } else if (value && typeof value === "object") {
          for (const [key, item] of Object.entries(value)) walk(item, `${field}.${key}`);
        }
      };
      if (collection === "users") walk(data.photoUrl, "photoUrl");
      else walk(data, "");
      if (collection !== "users" || urls.length) {
        console.log(JSON.stringify({collection, id,
          keys: collection === "users" ? undefined : Object.keys(data), urls}));
      }
    }
  }
}
main().catch((e) => {
  console.error(e.message); process.exitCode = 1;
});
