"use strict";
/* eslint-disable max-len */
const assert = require("assert/strict");
const {cloudAccess} = require("./cloud_access");
const {TARGET, REAL_USERS} = require("./production_readiness");
const {decode} = require("./production_projection");
async function main() {
  const request = await cloudAccess();
  const base = `https://firestore.googleapis.com/v1/projects/${TARGET}/databases/(default)/documents`;
  const list = async (collection) => {
    let page = "";
    const docs = [];
    do {
      const result = await request(`${base}/${collection}?pageSize=100&pageToken=${encodeURIComponent(page)}`);
      docs.push(...(result.documents || []).map((d) => ({id: d.name.split("/").pop(), data: decode({mapValue: {fields: d.fields}})})));
      page = result.nextPageToken || "";
    } while (page);
    return docs;
  };
  const users = await list("users");
  const directory = await list("user_directory");
  const groups = await list("academic_groups");
  const years = await list("academic_years");
  const settings = await list("academic_year_settings");
  const auth = await request(`https://identitytoolkit.googleapis.com/v1/projects/${TARGET}/accounts:batchGet?maxResults=1000`);
  assert.equal(auth.nextPageToken, undefined);
  assert.deepEqual(users.map((d) => d.id).sort(), [...REAL_USERS].sort());
  assert.deepEqual(directory.map((d) => d.id).sort(), [...REAL_USERS].sort());
  assert.deepEqual(auth.users.map((u) => u.localId).sort(), [...REAL_USERS].sort());
  for (const {id, data} of users) {
    assert.equal(data.status, "activo", `Inactive ${id}`);
    const account = auth.users.find((u) => u.localId === id);
    assert.notEqual(account.disabled, true, `Disabled Auth ${id}`);
    assert.equal(account.email.toLowerCase(), data.institutionalEmail.toLowerCase(), `Login email mismatch ${id}`);
    const entry = directory.find((d) => d.id === id).data;
    for (const [key, value] of Object.entries(entry)) assert.deepEqual(value, data[key], `Directory mismatch ${id}/${key}`);
    assert.ok(!Object.keys(data).some((k) => /token|loginAttempts|qr/i.test(k)), `Session data copied ${id}`);
    if (data.groupId) {
      const group = groups.find((g) => g.id === data.groupId)?.data;
      assert.ok(group && group.institutionId === data.institution && group.campusId === data.campus, `Group mismatch ${id}`);
    }
    assert.ok(data.studentIds.every((child) => REAL_USERS.includes(child)));
    assert.ok(!JSON.stringify(data).includes("sistema-educativo-rl.firebasestorage.app"));
  }
  assert.equal(groups.length, 30);
  assert.equal(years.length, 2);
  assert.equal(settings.length, 2);
  for (const {data} of groups) {
    const year = years.find((y) => y.id === data.academicYearId)?.data;
    assert.ok(year?.status === "active" && year.year === 2026 && year.campusId === data.campusId && year.institutionId === data.institutionId);
  }
  const empty = ["enrollments", "files", "authorization_requests", "subjects", "routes", "daily_routes", "message_channels", "push_jobs", "push_events", "push_device_sessions", "qr_credentials", "user_history", "user_logs", "route_history", "schedule_history"];
  for (const collection of empty) assert.equal((await list(collection)).length, 0, `Unexpected operational data: ${collection}`);
  console.log(JSON.stringify({project: TARGET, readOnly: true, users: users.length, authUsers: auth.users.length, directory: directory.length,
    groups: groups.length, academicYears: years.length, emptyOperationalCollections: empty.length,
    verified: true, passwordLoginTested: false}));
}
main().catch((e) => {
  console.error(e.message); process.exitCode = 1;
});
