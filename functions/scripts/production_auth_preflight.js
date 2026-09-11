"use strict";
/* eslint-disable max-len */
const {cloudAccess} = require("./cloud_access");
const {SOURCE, TARGET, REAL_USERS} = require("./production_readiness");

async function main() {
  const request = await cloudAccess();
  for (const project of [SOURCE, TARGET]) {
    try {
      const config = await request(`https://identitytoolkit.googleapis.com/admin/v2/projects/${project}/config`);
      const users = await request(`https://identitytoolkit.googleapis.com/v1/projects/${project}/accounts:batchGet?maxResults=1000`);
      console.log(JSON.stringify({project, emailEnabled: config.signIn?.email?.enabled,
        domains: config.authorizedDomains, subtype: config.subtype,
        hashAvailable: Boolean(config.signIn?.hashConfig?.signerKey),
        users: users.users?.length || 0, morePages: Boolean(users.nextPageToken),
        approved: (users.users || []).filter((u) => REAL_USERS.includes(u.localId)).map((u) => ({
          uid: u.localId, hasPasswordHash: Boolean(u.passwordHash),
          disabled: u.disabled === true, emailVerified: u.emailVerified === true,
        }))}));
    } catch (e) {
      console.log(JSON.stringify({project, error: e.message}));
      process.exitCode = 1;
    }
  }
}
main().catch((e) => {
  console.error(e.message); process.exitCode = 1;
});
