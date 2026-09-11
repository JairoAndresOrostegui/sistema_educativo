"use strict";
/* eslint-disable max-len */
const assert = require("assert");
const {getFirestore} = require("firebase-admin/firestore");
const {getApp, deleteApp} = require("firebase-admin/app");

describe("Auditoria funcion real de notificaciones, transporte externo bloqueado",
    () => {
      let api; let db;
      const mobile = "mobile-synthetic-token-123456789";
      const web = "web-synthetic-token-123456789";
      const call = () => api.enviarNotificacion.run({auth: {uid: "teacher", token: {email_verified: true}},
        data: {titulo: "Prueba local", cuerpo: "Solo emulador",
          notificationType: "schedule", audience: {studentIds: ["student"]}}});
      before(() => {
        assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
        process.env.FUNCTIONS_EMULATOR = "true";
        process.env.GCLOUD_PROJECT = "sistema-educativo-push-audit-test";
        api = require("../index");
        db = getFirestore();
      });
      after(() => deleteApp(getApp()));
      beforeEach(async () => {
        for (const name of ["users", "push_jobs", "notification_rate_limits"]) {
          await db.recursiveDelete(db.collection(name));
        }
        const scope = {institution: "i", campus: "c", status: "activo"};
        await db.doc("users/teacher").set({...scope, role: "Administrador",
          permissions: []});
        await db.doc("users/student").set({...scope, role: "Estudiante"});
      });
      for (const [name, slots, expected] of [
        ["solo movil", {mobile}, [mobile]],
        ["solo web", {web}, [web]],
        ["ambos", {mobile, web}, [mobile, web]],
      ]) {
        it(`encola ${name} sin exigir el otro dispositivo`, async () => {
          await db.doc("users/student").update({notificationTokens: slots});
          assert.equal((await call()).encolados, expected.length);
          const job = (await db.collection("push_jobs").get()).docs[0];
          assert.deepEqual(job.data().pendingTokens.sort(), expected.sort());
        });
      }
      it("ninguno es una omision valida", async () => {
        assert.equal((await call()).encolados, 0);
      });
      it("revalida y omite token reemplazado antes de procesar", async () => {
        await db.doc("users/student").update({notificationTokens: {mobile}});
        await call();
        const job = (await db.collection("push_jobs").get()).docs[0];
        await db.doc("users/student").update({notificationTokens: {
          mobile: "replacement-synthetic-token-123456789"}});
        await api.procesarNotificacionPendiente.run({data: job});
        const result = (await job.ref.get()).data();
        assert.equal(result.skipped, 1);
        assert.equal(result.accepted, 0);
      });
      it("rechaza avisos de ruta genericos aunque sea docente",
          async () => {
            await db.doc("users/student").update({notificationTokens: {mobile}});
            await assert.rejects(api.enviarNotificacion.run({auth: {uid: "teacher", token: {email_verified: true}},
              data: {titulo: "Prueba", cuerpo: "Prueba", notificationType: "route", audience: {studentIds: ["student"]}}}),
            (e) => e.code === "permission-denied");
          });
      it("un docente no puede fabricar avisos genéricos para otros grupos",
          async () => {
            await db.doc("users/teacher").update({role: "Docente",
              groupId: "group-1"});
            await assert.rejects(call(), (error) =>
              error.code === "permission-denied");
          });
    });
