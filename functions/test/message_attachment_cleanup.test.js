"use strict";

const assert = require("assert");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {deleteMessageAttachment, retryMessageAttachmentCancellations} =
  require("../message_attachment_cleanup");

describe("Cancelacion y retencion seguras de adjuntos", () => {
  let app;
  let db;
  let ref;
  let deletes;
  const usageRef = () => db.doc("file_storage_usage/institution");
  const options = (overrides = {}) => ({
    db, ref,
    bucket: {file: () => ({delete: async () => deletes++})},
    usageRefForInstitution: usageRef,
    authorize: (value) => assert.equal(value.uploadedBy, "owner"),
    kind: "cancel", performedBy: "owner",
    ...overrides,
  });
  before(() => {
    assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
    app = initializeApp({projectId: "sistema-educativo-push-test"},
        "attachment-cleanup-tests");
    db = getFirestore(app);
    ref = db.doc("message_attachments/attachment");
  });
  after(() => deleteApp(app));
  beforeEach(async () => {
    for (const collection of ["message_attachments", "messaging_audit",
      "message_attachment_downloads", "file_storage_usage"]) {
      await db.recursiveDelete(db.collection(collection));
    }
    deletes = 0;
    await ref.set({
      status: "ready", uploadedBy: "owner", channelId: "channel",
      institutionId: "institution", campusId: "campus", academicYearId: "year",
      storagePath: "message_attachments/channel/attachment/test.pdf",
      sizeBytes: 100,
      retentionExpiresAt: Timestamp.fromMillis(0),
    });
    await usageRef().set({usedBytes: 1000, reservedBytes: 300});
  });

  it("un adjunto enviado nunca se cancela ni pierde su objeto", async () => {
    await ref.update({status: "attached"});
    await assert.rejects(deleteMessageAttachment(options()),
        (error) => error.code === "failed-precondition");
    assert.equal(deletes, 0);
    assert.equal((await ref.get()).data().status, "attached");
    assert.equal((await usageRef().get()).data().usedBytes, 1000);
  });

  it("bloquea un envio concurrente antes de borrar Storage", async () => {
    let reachedDelete;
    const deleting = new Promise((resolve) => reachedDelete = resolve);
    let releaseDelete;
    const released = new Promise((resolve) => releaseDelete = resolve);
    const operation = deleteMessageAttachment(options({
      bucket: {file: () => ({delete: async () => {
        reachedDelete();
        await released;
      }})},
    }));
    await deleting;
    try {
      await assert.rejects(db.runTransaction(async (tx) => {
        const snapshot = await tx.get(ref);
        if (snapshot.data().status !== "ready") throw new Error("not-ready");
        tx.update(ref, {status: "attached"});
      }), /not-ready/);
      assert.equal((await ref.get()).data().status, "canceling");
      assert.equal((await usageRef().get()).data().usedBytes, 1000);
    } finally {
      releaseDelete();
    }
    await operation;
    assert.equal((await usageRef().get()).data().usedBytes, 900);
  });

  it("conserva cuota ante fallo Storage y permite reintentar", async () => {
    await assert.rejects(deleteMessageAttachment(options({
      bucket: {file: () => ({delete: async () => {
        throw new Error("storage unavailable");
      }})},
    })), /storage unavailable/);
    assert.equal((await ref.get()).data().status, "canceling");
    assert.equal((await usageRef().get()).data().usedBytes, 1000);
    assert.equal(await deleteMessageAttachment(options()), true);
    assert.equal(await deleteMessageAttachment(options()), false);
    assert.equal((await usageRef().get()).data().usedBytes, 900);
    assert.equal((await db.collection("messaging_audit").get()).size, 1);
  });

  it("dos limpiezas concurrentes descuentan una sola vez", async () => {
    await ref.update({status: "attached"});
    await db.doc("message_attachment_downloads/receipt").set({
      attachmentId: ref.id,
    });
    const retention = options({kind: "retention", threshold: Timestamp.now()});
    const results = await Promise.all([
      deleteMessageAttachment(retention), deleteMessageAttachment(retention),
    ]);
    assert.equal(results.filter(Boolean).length, 1);
    assert.equal((await usageRef().get()).data().usedBytes, 900);
    const receipts = await db.collection("message_attachment_downloads").get();
    assert.equal(receipts.size,
        0);
    assert.equal((await db.collection("messaging_audit").get()).size, 1);
  });

  it("una reserva incompleta libera solo bytes reservados", async () => {
    await ref.update({status: "uploading", sizeBytes: 0, expectedSize: 100});
    await deleteMessageAttachment(options());
    const usage = (await usageRef().get()).data();
    assert.equal(usage.usedBytes, 1000);
    assert.equal(usage.reservedBytes, 200);
  });

  it("barrido recupera cancelacion fallida sin esperar retencion", async () => {
    await ref.update({status: "uploading", expectedSize: 100,
      retentionExpiresAt: Timestamp.fromMillis(Date.now() + 60 * 86400000)});
    const brokenBucket = {file: () => ({delete: async () => {
      throw new Error("storage unavailable");
    }})};
    await assert.rejects(deleteMessageAttachment(options({
      bucket: brokenBucket,
    })), /storage unavailable/);
    const preserved = {...(await ref.get()).data(), status: "attached"};
    await db.doc("message_attachments/attached").set(preserved);
    const failed = await retryMessageAttachmentCancellations({
      db, bucket: brokenBucket, usageRefForInstitution: usageRef,
    });
    assert.equal(failed.failures.length, 1);
    assert.equal((await usageRef().get()).data().reservedBytes, 300);
    const restored = await retryMessageAttachmentCancellations(options());
    assert.equal(restored.removed, 1);
    assert.equal(restored.failures.length, 0);
    assert.equal((await usageRef().get()).data().reservedBytes, 200);
    assert.equal((await usageRef().get()).data().usedBytes, 1000);
    const repeated = await retryMessageAttachmentCancellations(options());
    assert.equal(repeated.checked, 0);
    assert.equal((await db.doc("message_attachments/attached").get())
        .data().status, "attached");
    assert.equal((await db.collection("messaging_audit").get()).size, 1);
  });

  it("no elimina antes de vencer ni ante fallo de autorizacion", async () => {
    await ref.update({retentionExpiresAt:
      Timestamp.fromMillis(Date.now() + 60000)});
    assert.equal(await deleteMessageAttachment(options({
      kind: "retention", threshold: Timestamp.now(),
    })), false);
    await assert.rejects(deleteMessageAttachment(options({
      authorize: () => {
        throw new Error("forbidden");
      },
    })), /forbidden/);
    assert.equal(deletes, 0);
    assert.equal((await ref.get()).data().status, "ready");
  });
});
