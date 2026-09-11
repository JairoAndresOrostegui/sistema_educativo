"use strict";
/* eslint-disable max-len */
const {cloudAccess} = require("./cloud_access");
const {SOURCE} = require("./production_readiness");

async function main() {
  const request = await cloudAccess();
  const base = `https://firestore.googleapis.com/v1/projects/${SOURCE}/databases/(default)/documents`;
  console.log(await request(`${base}:listCollectionIds`, "POST", {}));
  for (const collection of ["academic_groups", "academic_years", "institutions", "campuses", "configuracion_colegios", "roles", "users"]) {
    const data = await request(`${base}/${collection}?pageSize=100`);
    console.log(JSON.stringify({collection, count: data.documents?.length || 0,
      morePages: Boolean(data.nextPageToken),
      keys: [...new Set((data.documents || []).flatMap((d) => Object.keys(d.fields || {})))],
      ids: collection === "users" ? undefined : (data.documents || []).map((d) => d.name.split("/").pop())}));
  }
  for (const collection of ["academic_year_settings", "academic_years", "parameters"]) {
    const data = await request(`${base}/${collection}?pageSize=100`);
    console.log(JSON.stringify({collection, documents: (data.documents || []).map((d) => ({
      id: d.name.split("/").pop(), fields: collection === "parameters" ? Object.keys(d.fields || {}) : d.fields,
    }))}));
  }
}
main().catch((e) => {
  console.error(e.message); process.exitCode = 1;
});
