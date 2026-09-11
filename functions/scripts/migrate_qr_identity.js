"use strict";
const path = require("path");
const fs = require("fs");
const os = require("os");
const crypto = require("crypto");
const {initializeApp, applicationDefault} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {credentialId} = require("../qr_identity");

async function main() {
  const cliAuth = require(path.join(process.env.APPDATA,
      "npm/node_modules/firebase-tools/lib/auth"));
  const account = cliAuth.getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) {
    throw new Error("Inicia sesion en Firebase CLI");
  }
  const cliApi = require(path.join(process.env.APPDATA,
      "npm/node_modules/firebase-tools/lib/api"));
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "qr-migration-"));
  const credentialPath = path.join(temporary, "adc.json");
  fs.writeFileSync(credentialPath, JSON.stringify({type: "authorized_user",
    client_id: cliApi.clientId(), client_secret: cliApi.clientSecret(),
    refresh_token: account.tokens.refresh_token}), {mode: 0o600});
  process.on("exit", () => {
    fs.unlinkSync(credentialPath);
    fs.rmdirSync(temporary);
  });
  process.env.GOOGLE_APPLICATION_CREDENTIALS = credentialPath;
  initializeApp({projectId: "sistema-educativo-rl",
    credential: applicationDefault()});
  const db = getFirestore();
  const snapshot = await db.collection("users").get();
  let affected = 0;
  for (const item of snapshot.docs) {
    const old = item.data();
    const legacy = ["qrPayload", "qrEnabled", "qrUpdatedAt"];
    if (!legacy.some((key) => key in old)) continue;
    affected++;
    if (!process.argv.includes("--apply")) continue;
    await db.runTransaction(async (tx) => {
      const current = (await tx.get(item.ref)).data();
      const ref = db.collection("qr_credentials")
          .doc(credentialId("user", item.id));
      const existing = await tx.get(ref);
      if (!existing.exists && current.status === "activo" &&
          current.qrEnabled === true) {
        const payload = `LLQ1:${crypto.randomBytes(32).toString("base64url")}`;
        tx.create(ref, {targetType: "user", targetId: item.id,
          institutionId: current.institution, campusId: current.campus,
          status: "active", payload,
          tokenHash: crypto.createHash("sha256").update(payload).digest("hex"),
          createdAt: FieldValue.serverTimestamp()});
      }
      tx.update(item.ref, {qrPayload: FieldValue.delete(),
        qrEnabled: FieldValue.delete(), qrUpdatedAt: FieldValue.delete()});
      tx.create(db.collection("qr_audit").doc(), {action: "legacy_migrated",
        performedBy: "migration:qr-identity-v1", targetType: "user",
        targetId: item.id, institutionId: current.institution,
        campusId: current.campus, createdAt: FieldValue.serverTimestamp()});
    });
  }
  console.log(JSON.stringify({apply: process.argv.includes("--apply"),
    affected}));
}
main().catch((error) => {
  console.error(error.code || error.message); process.exitCode = 1;
});
