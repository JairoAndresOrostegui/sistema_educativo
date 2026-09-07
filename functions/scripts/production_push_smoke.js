"use strict";
/* eslint-disable max-len */
// Explicit owner-requested test. Never sends to teachers, families or students.
const {cloudAccess} = require("./cloud_access");
const {decode, encode} = require("./production_projection");
const UID = "qhUeXTpqALbKAkVXlXj8pjk0HQT2";
const BASE = "https://firestore.googleapis.com/v1/projects/sistema-educativo-rl-prod/databases/(default)/documents";
const RUN = "production-owner-push-20260907";
async function main() {
  const request = await cloudAccess();
  if (process.argv.includes("--send")) {
    const snapshot = await request(`${BASE}/users/${UID}`);
    const user = decode({mapValue: {fields: snapshot.fields}});
    if (user.status !== "activo" || user.isSuperadmin !== true) throw new Error("Owner account is not active superadmin");
    const writes = [];
    const slots = [];
    for (const slot of ["mobile", "web"]) {
      const token = user.notificationTokens?.[slot];
      if (!token) continue;
      slots.push(slot);
      const data = {
        institutionId: user.institution, campusId: user.campus, type: "diagnostic",
        message: {
          notification: {title: "Llinás · Prueba de producción", body: `Jairo, esta es la prueba en ${slot === "mobile" ? "tu móvil" : "tu navegador"}. Confirma que aparece este aviso.`},
          android: {priority: "high"},
          webpush: {fcmOptions: {link: "https://liceobilinguerodolfollinas.edu.co/"}},
        },
        pendingTokens: [token], status: "pending", attempts: 0,
        accepted: 0, rejected: 0, skipped: 0, total: 1,
        createdAt: new Date(), dueAt: new Date(),
      };
      writes.push({update: {name: `${BASE.slice(BASE.indexOf("projects/"))}/push_jobs/${RUN}-${slot}`, fields: encode(data).mapValue.fields}, currentDocument: {exists: false}});
    }
    if (!slots.length) throw new Error("No registered devices; nothing sent");
    writes.push({update: {name: `${BASE.slice(BASE.indexOf("projects/"))}/notification_test_audit/${RUN}`, fields: encode({
      recipientId: UID, slots, requestedBy: "owner-explicit-chat-request",
      executedBy: "firebase-cli-operator", createdAt: new Date(),
      institutionId: user.institution, campusId: user.campus,
    }).mapValue.fields}, currentDocument: {exists: false}});
    await request(`${BASE}:commit`, "POST", {writes});
    console.log(JSON.stringify({queuedSlots: slots, duplicateProtection: RUN}));
  }
  for (const slot of ["mobile", "web"]) {
    try {
      const snapshot = await request(`${BASE}/push_jobs/${RUN}-${slot}`);
      const job = decode({mapValue: {fields: snapshot.fields}});
      console.log(JSON.stringify({slot, status: job.status, accepted: job.accepted,
        rejected: job.rejected, skipped: job.skipped, lastError: job.lastError || null}));
    } catch (error) {
      if (error.status !== 404) throw error;
      console.log(JSON.stringify({slot, status: "not_queued"}));
    }
  }
}
main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
