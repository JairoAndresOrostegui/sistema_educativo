"use strict";
/* eslint-disable max-len */
// Infrastructure only. Never imports users, deploys code or changes QA/DNS.
const path = require("path");
const {refreshToken} = require("firebase-admin/app");
const {TARGET} = require("./production_readiness");

async function main() {
  if (TARGET !== "sistema-educativo-rl-prod") throw new Error("Unexpected production project");
  const apply = process.argv.includes("--apply");
  const base = path.join(process.env.APPDATA, "npm/node_modules/firebase-tools/lib");
  const account = require(path.join(base, "auth")).getGlobalDefaultAccount();
  const api = require(path.join(base, "api"));
  if (!account?.tokens?.refresh_token) throw new Error("Firebase CLI login required");
  const token = await refreshToken({type: "authorized_user", client_id: api.clientId(),
    client_secret: api.clientSecret(), refresh_token: account.tokens.refresh_token}).getAccessToken();
  const request = async (url, method = "GET", body) => {
    const r = await fetch(url, {method, headers: {"Authorization": `Bearer ${token.access_token}`,
      "Content-Type": "application/json"}, body: body === undefined ? undefined : JSON.stringify(body)});
    const data = await r.json();
    if (!r.ok) {
      const error = new Error(`HTTP ${r.status}: ${data.error?.status || "request failed"}`);
      error.status = r.status;
      throw error;
    }
    return data;
  };
  const billing = await request(`https://cloudbilling.googleapis.com/v1/projects/${TARGET}/billingInfo`);
  if (!billing.billingEnabled) throw new Error("Enable billing before provisioning");
  console.log(JSON.stringify({project: TARGET, billingEnabled: true, apply}));
  const services = ["firestore.googleapis.com", "firebasestorage.googleapis.com", "identitytoolkit.googleapis.com"];
  for (const service of services) {
    const url = `https://serviceusage.googleapis.com/v1/projects/${TARGET}/services/${service}`;
    const state = await request(url);
    if (state.state !== "ENABLED" && apply) {
      const op = await request(`${url}:enable`, "POST", {});
      console.log(JSON.stringify({service, operation: op.name}));
      // A subsequent invocation resumes safely after API propagation.
    } else console.log(JSON.stringify({service, state: state.state}));
  }
  const resources = [
    {kind: "firestore", get: `https://firestore.googleapis.com/v1/projects/${TARGET}/databases/(default)`,
      create: `https://firestore.googleapis.com/v1/projects/${TARGET}/databases?databaseId=(default)`,
      body: {locationId: "us-central1", type: "FIRESTORE_NATIVE", deleteProtectionState: "DELETE_PROTECTION_ENABLED"}},
    {kind: "storage", get: `https://firebasestorage.googleapis.com/v1alpha/projects/${TARGET}/defaultBucket`,
      create: `https://firebasestorage.googleapis.com/v1alpha/projects/${TARGET}/defaultBucket`,
      body: {location: "US-CENTRAL1"}},
  ];
  for (const resource of resources) {
    try {
      const existing = await request(resource.get);
      const location = existing.locationId || existing.location;
      if (location?.toLowerCase() !== "us-central1") throw new Error(`Unexpected ${resource.kind} location`);
      if (resource.kind === "firestore" && existing.deleteProtectionState !== "DELETE_PROTECTION_ENABLED") {
        throw new Error("Production database delete protection is not enabled");
      }
      console.log(JSON.stringify({kind: resource.kind, state: "exists", name: existing.name, location}));
    } catch (error) {
      if (error.status !== 404) throw error;
      if (!apply) {
        console.log(JSON.stringify({kind: resource.kind, state: "missing"}));
        continue;
      }
      const created = await request(resource.create, "POST", resource.body);
      console.log(JSON.stringify({kind: resource.kind, state: "creation requested", name: created.name}));
    }
  }
}
main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
