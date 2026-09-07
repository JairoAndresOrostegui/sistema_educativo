"use strict";
/* eslint-disable max-len */
const fs = require("fs"); const path = require("path"); const os = require("os");
const {initializeApp, applicationDefault} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
async function main() {
  const base = path.join(process.env.APPDATA, "npm/node_modules/firebase-tools/lib");
  const account = require(path.join(base, "auth")).getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) throw new Error("Inicia sesión en Firebase CLI");
  const api = require(path.join(base, "api"));
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "route-migration-"));
  const credentialPath = path.join(temporary, "adc.json");
  fs.writeFileSync(credentialPath, JSON.stringify({type: "authorized_user", client_id: api.clientId(),
    client_secret: api.clientSecret(), refresh_token: account.tokens.refresh_token}), {mode: 0o600});
  process.on("exit", () => {
    fs.unlinkSync(credentialPath); fs.rmdirSync(temporary);
  });
  process.env.GOOGLE_APPLICATION_CREDENTIALS = credentialPath;
  initializeApp({projectId: "sistema-educativo-rl", credential: applicationDefault()});
  const db = getFirestore(); const apply = process.argv.includes("--apply");
  let profiles = 0;
  for (const item of (await db.collection("users").get()).docs) {
    const d = item.data();
    if (!["direccionRuta", "fcmToken", "fcmTokens", "webPushToken", "mobilePushToken"].some((k) => k in d)) continue;
    profiles++;
    if (apply) {
      await db.runTransaction(async (tx) => {
        const current = (await tx.get(item.ref)).data();
        const changes = {direccionRuta: FieldValue.delete(), fcmToken: FieldValue.delete(), fcmTokens: FieldValue.delete(),
          webPushToken: FieldValue.delete(), mobilePushToken: FieldValue.delete()};
        if (!current.routeAddress && current.direccionRuta) changes.routeAddress = current.direccionRuta;
        tx.update(item.ref, changes);
      });
    }
  }
  const role = db.collection("parameters").doc("role_auxiliar");
  const missingRole = !(await role.get()).exists;
  if (apply && missingRole) await role.set({clave: "role", valor: "Auxiliar", etiqueta: "Auxiliar", activo: true, orden: 5});
  const routes = await db.collection("routes").get();
  const runs = await db.collection("daily_routes").get();
  let legacyLocations = 0;
  for (const run of runs.docs) {
    if (!("teacherPosition" in run.data()) && !("lastUpdate" in run.data())) continue;
    legacyLocations++;
    if (apply) await run.ref.update({teacherPosition: FieldValue.delete(), lastUpdate: FieldValue.delete()});
  }
  const missingParents = runs.docs.filter((r) => !routes.docs.some((t) => t.id === r.data().idRuta)).length;
  console.log(JSON.stringify({apply, profiles, missingRole, routes: routes.size, dailyRoutes: runs.size, missingParents, legacyLocations}));
}
main().catch((e) => {
  console.error(e.code || e.message); process.exitCode = 1;
});
