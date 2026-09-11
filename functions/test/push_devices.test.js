"use strict";
/* eslint-disable max-len */
const assert = require("assert");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {pushDeviceFunctions} = require("../push_devices");
describe("Propiedad de slots push", () => {
  let app; let db; let api;
  const id1 = "1".repeat(64); const id2 = "2".repeat(64);
  const token1 = "a".repeat(30); const token2 = "b".repeat(30);
  before(() => {
    assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
    app = initializeApp({projectId: "sistema-educativo-device-test"}, "devices");
    db = getFirestore(app);
    api = pushDeviceFunctions(db, async () => ({uid: "u"}));
  });
  after(() => deleteApp(app));
  beforeEach(async () => {
    await db.doc("push_device_sessions/u").delete();
    await db.doc("users/u").set({status: "activo"});
  });
  const call = (action, slot = "mobile", sessionId = id1, time = 1, token = token1) =>
    api.gestionarDispositivoPush.run({auth: {uid: "u", token: {auth_time: time}}, data: {action, slot, sessionId, token}});
  it("conserva web al reemplazar movil; logout/refresh anteriores no lo alteran", async () => {
    await call("begin"); await call("enable");
    await call("begin", "web"); await call("enable", "web");
    await call("begin", "mobile", id2, 2); await call("enable", "mobile", id2, 2, token2);
    await call("disable"); await call("refresh");
    await assert.rejects(call("begin"), (e) => e.code === "failed-precondition");
    assert.deepEqual((await db.doc("users/u").get()).data().notificationTokens, {web: token1, mobile: token2});
  });
  it("sin permiso desplaza al anterior y desactivacion no resucita con refresh", async () => {
    await call("begin"); await call("enable");
    await call("begin", "mobile", id2, 2);
    assert.equal((await db.doc("users/u").get()).data().notificationTokens?.mobile, undefined);
    await call("enable", "mobile", id2, 2, token2);
    await call("disable", "mobile", id2, 2);
    await call("refresh", "mobile", id2, 2, token2);
    assert.equal((await db.doc("users/u").get()).data().notificationTokens?.mobile, undefined);
  });
  it("no admite token invalido ni tercer slot", async () => {
    await assert.rejects(call("begin", "other"));
    await call("begin");
    await assert.rejects(call("enable", "mobile", id1, 1, "short"));
  });
});
