"use strict";
const path = require("path");
const {refreshToken} = require("firebase-admin/app");

function cloudCredentials() {
  const base = path.join(process.env.APPDATA,
      "npm/node_modules/firebase-tools/lib");
  const account = require(path.join(base, "auth")).getGlobalDefaultAccount();
  const api = require(path.join(base, "api"));
  if (!account?.tokens?.refresh_token) {
    throw new Error("Firebase CLI login required");
  }
  return {type: "authorized_user",
    client_id: api.clientId(), client_secret: api.clientSecret(),
    refresh_token: account.tokens.refresh_token};
}

function cloudCredential() {
  return refreshToken(cloudCredentials());
}

async function cloudAccess() {
  const credential = cloudCredential();
  return async (url, method = "GET", body) => {
    const token = await credential.getAccessToken();
    const response = await fetch(url, {method,
      headers: {"Authorization": `Bearer ${token.access_token}`,
        "Content-Type": "application/json"},
      body: body === undefined ? undefined : JSON.stringify(body)});
    const data = await response.json();
    if (!response.ok) {
      const error = new Error(`HTTP ${response.status}: ` +
        (data.error?.status || "Cloud request failed"));
      error.status = response.status;
      throw error;
    }
    return data;
  };
}
module.exports = {cloudAccess, cloudCredential, cloudCredentials};
