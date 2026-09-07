"use strict";
/* eslint-disable max-len */
const {cloudAccess} = require("./cloud_access");
const {TARGET} = require("./production_readiness");

async function main() {
  if (TARGET !== "sistema-educativo-rl-prod") throw new Error("Unexpected project");
  const request = await cloudAccess();
  const url = `https://identitytoolkit.googleapis.com/admin/v2/projects/${TARGET}/config`;
  let config;
  try {
    config = await request(url);
  } catch (e) {
    if (e.status === 404) throw new Error("Initialize Firebase Authentication with Get Started in production console first. Do not upgrade to Identity Platform.", {cause: e});
    throw e;
  }
  const authorizedDomains = [...new Set([...(config.authorizedDomains || []),
    `${TARGET}.firebaseapp.com`, `${TARGET}.web.app`,
    "liceobilinguerodolfollinas.edu.co", "www.liceobilinguerodolfollinas.edu.co"])];
  if (process.argv.includes("--apply")) {
    config = await request(`${url}?updateMask=authorizedDomains,signIn.email`, "PATCH", {
      authorizedDomains, signIn: {email: {enabled: true, passwordRequired: true}},
    });
    config = await request(url);
    if (!config.signIn?.email?.enabled || !config.signIn.email.passwordRequired ||
        authorizedDomains.some((domain) => !config.authorizedDomains?.includes(domain))) {
      throw new Error("Auth configuration verification failed");
    }
  }
  console.log(JSON.stringify({project: TARGET, applied: process.argv.includes("--apply"),
    subtype: config.subtype, emailEnabled: config.signIn?.email?.enabled,
    passwordRequired: config.signIn?.email?.passwordRequired,
    authorizedDomains: config.authorizedDomains}));
}
main().catch((e) => {
  console.error(e.message); process.exitCode = 1;
});
