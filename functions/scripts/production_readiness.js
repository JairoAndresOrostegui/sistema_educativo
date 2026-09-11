"use strict";
/* eslint-disable max-len */
// Read-only preflight. Never logs tokens, password hashes or full profiles.
const path = require("path");
const {refreshToken} = require("firebase-admin/app");
const SOURCE = "sistema-educativo-rl";
const TARGET = "sistema-educativo-rl-prod";
const PLAYTEST_FIXTURE_ID = "play_store_closed_test_2026_09";
const REAL_USERS = [
  "176sNjmWSXbNePE7zzHEJyKSD1G2", "3b7TWoz2R9d9n8pDaFXcrU4N5dq2", "4nGxhgcXjCcCWo5zrLeHjGAF30e2",
  "BHYawHIo4bdAAlqIeAI9loM7Bw62", "LrA7aBbr0Re0IoVim2gg9U8IkxA2", "O5tf0tAiScMBJjI6oQ3ca5BFe3w1",
  "Oskb4iQNo1Y0aaZHoBQoqTWv7lP2", "PebBphHKChVRpWQIGl0UU3vSvA03", "aJQ9p2cZAheWp4GUzaDzDw8tcIf2",
  "euylmIodesWhMZUNldRC7WCvBXZ2", "fXLWGoUpnMXaBMczFG5Pumi5Ba43", "gJNXZux0NkPheNMmsbOfP1iQdnG3",
  "nckhVOHbVwSsews3se3eny0P1A83", "oCWuatURPOTEK9ReAr0dbWEw2bb2", "qBi8msgOTWc7C8usBbQhRPDsNYz1",
  "qhUeXTpqALbKAkVXlXj8pjk0HQT2", "sTUhBfhyYvOPx02dzsjvgLnQgT92", "zeYc2UIoGgPpXXzITM1tfP2ZYAr2",
];
async function main() {
  const base = path.join(process.env.APPDATA, "npm/node_modules/firebase-tools/lib");
  const account = require(path.join(base, "auth")).getGlobalDefaultAccount();
  const api = require(path.join(base, "api"));
  if (!account?.tokens?.refresh_token) throw new Error("Firebase CLI login required");
  const token = await refreshToken({type: "authorized_user", client_id: api.clientId(),
    client_secret: api.clientSecret(), refresh_token: account.tokens.refresh_token}).getAccessToken();
  const get = async (url) => {
    const r = await fetch(url, {headers: {Authorization: `Bearer ${token.access_token}`}});
    if (!r.ok) throw new Error(`Read failed HTTP ${r.status}`);
    return r.json();
  };
  const list = async (collection) => {
    let page = ""; const docs = [];
    do {
      const r = await get(`https://firestore.googleapis.com/v1/projects/${SOURCE}/databases/(default)/documents/${collection}?pageSize=100&pageToken=${encodeURIComponent(page)}`);
      docs.push(...r.documents || []); page = r.nextPageToken || "";
    } while (page);
    return docs;
  };
  const [users, groups] = await Promise.all([list("users"), list("academic_groups")]);
  const scalar = (d, k) => d.fields?.[k]?.stringValue ?? d.fields?.[k]?.booleanValue ?? null;
  const reports = REAL_USERS.map((id) => {
    const u = users.find((d) => d.name.endsWith(`/${id}`));
    if (!u) return {id, issue: "Missing approved user"};
    const groupId = scalar(u, "groupId");
    const group = groups.find((g) => g.name.endsWith(`/${groupId}`));
    const childIds = u.fields?.studentIds?.arrayValue?.values?.map((v) => v.stringValue) || [];
    return {id, name: `${scalar(u, "firstName")} ${scalar(u, "lastName")}`, role: scalar(u, "role"),
      status: scalar(u, "status"), groupId, groupName: group ? scalar(group, "name") : null,
      missingGroup: Boolean(groupId && !group), linkedQaOnlyChildren: childIds.filter((c) => !REAL_USERS.includes(c)),
      hasInstitutionalEmail: Boolean(scalar(u, "institutionalEmail")), hasPersonalEmail: Boolean(scalar(u, "personalEmail"))};
  });
  let billing;
  try {
    const r = await get(`https://cloudbilling.googleapis.com/v1/projects/${TARGET}/billingInfo`);
    billing = {billingEnabled: r.billingEnabled === true};
  } catch (e) {
    billing = {checkError: e.message};
  }
  console.log(JSON.stringify({source: SOURCE, target: TARGET, readOnly: true, sourceCount: users.length,
    selectedCount: REAL_USERS.length, qaOnlyCount: users.length - reports.filter((r) => !r.issue).length, billing, users: reports}, null, 2));
}
if (require.main === module) {
  main().catch((e) => {
    console.error(e.code || e.message); process.exitCode = 1;
  });
}
module.exports = {REAL_USERS, SOURCE, TARGET, PLAYTEST_FIXTURE_ID};
