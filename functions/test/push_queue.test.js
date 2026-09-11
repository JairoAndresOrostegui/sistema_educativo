"use strict";
const assert = require("assert");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {createPushQueue} = require("../push_queue");

describe("cola push", () => {
  let app;
  let db;
  before(() => {
    assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
    app = initializeApp({projectId: "sistema-educativo-push-test"});
    db = getFirestore(app);
  });
  after(() => deleteApp(app));
  beforeEach(async () => {
    await db.recursiveDelete(db.collection("push_jobs"));
  });
  const scope = {institutionId: "i", campusId: "c", type: "test"};
  it("divide 1201 dispositivos sin duplicados", async () => {
    const calls = [];
    const queue = createPushQueue(db, {
      sendEachForMulticast: async (payload) => {
        calls.push(payload.tokens.length);
        return {responses: payload.tokens.map(() => ({success: true}))};
      }}, async (_, tokens) => tokens);
    const tokens = Array.from({length: 1201}, (_, i) => `token-${i}`);
    await queue.enqueue({notification: {title: "t"},
      tokens: [...tokens, tokens[0]]}, scope, "event-1");
    const jobs = await db.collection("push_jobs").get();
    assert.equal(jobs.size, 3);
    for (const item of jobs.docs) {
      await Promise.all([queue.process(item.ref), queue.process(item.ref)]);
      await queue.process(item.ref);
    }
    assert.deepEqual(calls.sort((a, b) => a - b), [201, 500, 500]);
    await queue.enqueue({tokens}, scope, "event-1");
    for (const item of jobs.docs) await queue.process(item.ref);
    assert.equal(calls.length, 3);
  });
  it("reintenta temporales y descarta credenciales invalidas", async () => {
    let first = true;
    const calls = [];
    const invalidated = [];
    const queue = createPushQueue(db, {
      sendEachForMulticast: async ({tokens}) => {
        calls.push(tokens);
        if (!first) return {responses: [{success: true}]};
        first = false;
        return {responses: [{success: true}, {success: false, error: {
          code: "messaging/internal-error",
        }}, {success: false, error: {
          code: "messaging/registration-token-not-registered",
        }}]};
      }}, async (_, tokens) => tokens, async (_, tokens) => {
      invalidated.push(...tokens);
    });
    await queue.enqueue({tokens: ["ok", "retry", "invalid"]}, scope);
    const ref = (await db.collection("push_jobs").get()).docs[0].ref;
    await queue.process(ref);
    assert.deepEqual((await ref.get()).data().pendingTokens, ["retry"]);
    await ref.update({dueAt: Timestamp.fromMillis(0)});
    await queue.process(ref);
    const result = (await ref.get()).data();
    assert.equal(result.accepted, 2);
    assert.equal(result.rejected, 1);
    assert.equal(result.status, "partial");
    assert.deepEqual(calls[1], ["retry"]);
    assert.deepEqual(invalidated, ["invalid"]);
  });
  it("se detiene tras cinco intentos y revalida dispositivos", async () => {
    const queue = createPushQueue(db, {sendEachForMulticast: async () => {
      throw Object.assign(new Error("temporary"),
          {code: "messaging/internal-error"});
    }}, async (_, tokens) => tokens);
    await queue.enqueue({tokens: ["retry"]}, scope);
    const ref = (await db.collection("push_jobs").get()).docs[0].ref;
    for (let i = 0; i < 5; i++) {
      await ref.update({dueAt: Timestamp.fromMillis(0)});
      await queue.process(ref);
    }
    assert.equal((await ref.get()).data().status, "failed");
    const inactive = createPushQueue(db, {sendEachForMulticast: async () => {
      assert.fail("No debe enviar a un dispositivo sin acceso");
    }}, async () => []);
    await ref.update({status: "pending", dueAt: Timestamp.fromMillis(0),
      attempts: 0});
    await inactive.process(ref);
    assert.equal((await ref.get()).data().skipped, 1);
    assert.equal((await ref.get()).data().status, "skipped");
  });
  for (const wholeBatch of [false, true]) {
    it(`conserva dispositivos si INVALID_ARGUMENT afecta ${
      wholeBatch ? "el lote" : "una respuesta"}`, async () => {
      const invalidated = [];
      const failure = Object.assign(new Error("invalid payload"), {
        code: "messaging/invalid-argument",
      });
      const queue = createPushQueue(db, {
        sendEachForMulticast: async () => {
          if (wholeBatch) throw failure;
          return {responses: [{success: false, error: failure}]};
        },
      }, async (_, tokens) => tokens, async (_, tokens) => {
        invalidated.push(...tokens);
      });
      await queue.enqueue({tokens: ["still-valid"]}, scope);
      const ref = (await db.collection("push_jobs").get()).docs[0].ref;
      await queue.process(ref);
      const result = (await ref.get()).data();
      assert.deepEqual(invalidated, []);
      assert.deepEqual(result.pendingTokens, ["still-valid"]);
      assert.equal(result.rejected, 0);
      assert.equal(result.status, "retry");
    });
  }
});
