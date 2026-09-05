"use strict";

const {FieldValue, Timestamp} = require("firebase-admin/firestore");
const crypto = require("crypto");
const TERMINAL = new Set([
  "messaging/invalid-registration-token",
  "messaging/registration-token-not-registered",
  "messaging/mismatched-credential",
  "messaging/invalid-argument",
]);

/** Persistent, leased batches. FCM acceptance is not a delivery receipt. */
function createPushQueue(db, transport, validateTokens) {
  const collection = db.collection("push_jobs");
  async function enqueue(payload, scope, eventId = crypto.randomUUID()) {
    const tokens = [...new Set(payload.tokens)];
    const jobs = [];
    for (let i = 0; i < tokens.length; i += 500) {
      const id = crypto.createHash("sha256")
          .update(`${eventId}:${i}`).digest("hex");
      const {tokens: ignored, ...message} = payload;
      void ignored;
      jobs.push({ref: collection.doc(id), value: {
        ...scope, message, pendingTokens: tokens.slice(i, i + 500),
        status: "pending", attempts: 0, accepted: 0, rejected: 0, skipped: 0,
        total: tokens.slice(i, i + 500).length,
        createdAt: FieldValue.serverTimestamp(), dueAt: Timestamp.now(),
      }});
    }
    if (jobs.length) {
      await db.runTransaction(async (tx) => {
        const snapshots = await tx.getAll(...jobs.map((job) => job.ref));
        jobs.forEach((job, i) => {
          if (!snapshots[i].exists) tx.create(job.ref, job.value);
        });
      });
    }
    return {queued: tokens.length};
  }
  async function process(ref) {
    const lease = crypto.randomUUID();
    const job = await db.runTransaction(async (tx) => {
      const snapshot = await tx.get(ref);
      const value = snapshot.data();
      if (!value || !value.dueAt || value.dueAt.toMillis() > Date.now() ||
          !["pending", "retry", "sending"].includes(value.status)) return null;
      tx.update(ref, {status: "sending", lease, attempts: value.attempts + 1,
        dueAt: Timestamp.fromMillis(Date.now() + 10 * 60 * 1000)});
      return value;
    });
    if (!job) return;
    let pending = [];
    let accepted = 0;
    let rejected = 0;
    let skipped = 0;
    let lastError = null;
    let attemptedTokens = job.pendingTokens;
    try {
      const valid = await validateTokens(job, job.pendingTokens);
      attemptedTokens = valid;
      skipped = job.pendingTokens.length - valid.length;
      if (valid.length) {
        const result = await transport.sendEachForMulticast({
          ...job.message, tokens: valid,
        });
        result.responses.forEach((response, index) => {
          if (response.success) accepted++;
          else {
            lastError = response.error?.code || "messaging/unknown-error";
            if (TERMINAL.has(lastError)) rejected++;
            else pending.push(valid[index]);
          }
        });
      }
    } catch (error) {
      lastError = error.code || "messaging/unknown-error";
      if (TERMINAL.has(lastError)) rejected = attemptedTokens.length;
      else pending = attemptedTokens;
    }
    const attempts = job.attempts + 1;
    const status = pending.length ? (attempts >= 5 ? "failed" : "retry") :
      ((job.rejected || 0) + rejected > 0 ? "partial" : "accepted");
    await db.runTransaction(async (tx) => {
      const current = await tx.get(ref);
      if (current.data()?.lease !== lease) return;
      tx.update(ref, {
        status, pendingTokens: pending, lastError,
        accepted: FieldValue.increment(accepted),
        rejected: FieldValue.increment(rejected),
        skipped: FieldValue.increment(skipped),
        dueAt: status === "retry" ?
          Timestamp.fromMillis(Date.now() + 60000 * Math.pow(2, attempts)) :
          FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(), lease: FieldValue.delete(),
      });
    });
  }
  return {enqueue, process};
}

module.exports = {createPushQueue, TERMINAL};
