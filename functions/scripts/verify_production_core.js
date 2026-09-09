"use strict";
/* eslint-disable max-len */
const assert = require("assert/strict");
const {cloudAccess} = require("./cloud_access");
const {TARGET, REAL_USERS, PLAYTEST_FIXTURE_ID} = require("./production_readiness");
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
  const fixtures = await list("test_fixtures");
  const playtest = fixtures.find((d) => d.id === PLAYTEST_FIXTURE_ID)?.data;
  const playtestUids = playtest?.phase === "complete" && playtest.cleanupRequired === true ?
    playtest.authUids || [] : [];
  const approvedUsers = new Set([...REAL_USERS, ...playtestUids]);
  const auth = await request(`https://identitytoolkit.googleapis.com/v1/projects/${TARGET}/accounts:batchGet?maxResults=1000`);
  assert.equal(auth.nextPageToken, undefined);
  assert.deepEqual(users.map((d) => d.id).sort(), [...approvedUsers].sort());
  assert.deepEqual(directory.map((d) => d.id).sort(), [...approvedUsers].sort());
  assert.deepEqual(auth.users.map((u) => u.localId).sort(), [...approvedUsers].sort());
  for (const {id, data} of users) {
    assert.equal(data.status, "activo", `Inactive ${id}`);
    const account = auth.users.find((u) => u.localId === id);
    assert.notEqual(account.disabled, true, `Disabled Auth ${id}`);
    assert.equal(account.email.toLowerCase(), data.institutionalEmail.toLowerCase(), `Login email mismatch ${id}`);
    const entry = directory.find((d) => d.id === id).data;
    for (const [key, value] of Object.entries(entry)) assert.deepEqual(value, data[key], `Directory mismatch ${id}/${key}`);
    assert.ok(!Object.keys(data).some((k) =>
      k !== "notificationTokens" && /token|loginAttempts|qr/i.test(k)), `Unexpected session data ${id}`);
    if (data.notificationTokens) {
      const slots = Object.keys(data.notificationTokens);
      assert.ok(slots.every((slot) => ["mobile", "web"].includes(slot)), `Unexpected push slot ${id}`);
      assert.ok(slots.every((slot) => typeof data.notificationTokens[slot] === "string"),
          `Invalid push token shape ${id}`);
    }
    if (data.groupId) {
      const group = groups.find((g) => g.id === data.groupId)?.data;
      assert.ok(group && group.institutionId === data.institution && group.campusId === data.campus, `Group mismatch ${id}`);
    }
    assert.ok((data.studentIds || []).every((child) => approvedUsers.has(child)));
    if (!REAL_USERS.includes(id)) {
      assert.equal(data.testFixtureId, PLAYTEST_FIXTURE_ID, `Uncontrolled test user ${id}`);
    }
    assert.ok(!JSON.stringify(data).includes("sistema-educativo-rl.firebasestorage.app"));
  }
  assert.equal(groups.length, 30 + (playtestUids.length ? 2 : 0));
  assert.equal(years.length, 2);
  assert.equal(settings.length, 2);
  for (const {data} of groups) {
    const year = years.find((y) => y.id === data.academicYearId)?.data;
    assert.ok(year?.status === "active" && year.year === 2026 && year.campusId === data.campusId && year.institutionId === data.institutionId);
  }
  const operational = ["enrollments", "files", "authorization_requests", "subjects", "routes", "daily_routes", "message_channels", "push_jobs", "push_events", "push_device_sessions", "qr_credentials", "user_history", "user_logs", "route_history", "schedule_history"];
  const operationalCounts = {};
  for (const collection of operational) {
    const documents = await list(collection);
    operationalCounts[collection] = documents.length;
  }
  console.log(JSON.stringify({project: TARGET, readOnly: true, users: users.length, authUsers: auth.users.length, directory: directory.length,
    realUsers: REAL_USERS.length, playtestUsers: playtestUids.length, groups: groups.length,
    academicYears: years.length, inspectedOperationalCollections: operational.length, operationalCounts,
    playtestCleanupRequired: playtest?.cleanupRequired === true,
    verified: true, passwordLoginTested: false}));
}
main().catch((e) => {
  console.error(e.message); process.exitCode = 1;
});
