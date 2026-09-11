"use strict";
const assert = require("node:assert/strict");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {deleteFile, cancelUpload} = require("../file_cleanup");

describe("Archivos: limpieza recuperable y cuota exacta", () => {
  let app;
  let db;
  let ref;
  let usage;
  const projectId = "sistema-educativo-file-cleanup-test";
  before(() => {
    assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
    app = initializeApp({projectId}, "file-cleanup-regression");
    db = getFirestore(app);
  });
  beforeEach(async () => {
    await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/` +
      `projects/${projectId}/databases/(default)/documents`,
    {method: "DELETE"});
    ref = db.doc("files/file1");
    usage = db.doc("file_storage_usage/inst");
    await usage.set({usedBytes: 300, reservedBytes: 0});
    await ref.set({status: "active", institutionId: "inst", campusId: "campus",
      academicYearId: "year", academicYear: 2026,
      name: "Guía.pdf", storagePath: "files/file1/guia.pdf", sizeBytes: 100});
    await db.doc("file_download_receipts/receipt").set({fileId: ref.id});
  });
  after(async () => deleteApp(app));
  const remove = (bucket, authorize = () => {}) => deleteFile({
    db, ref, bucket, authorize, source: "manual", caller: {uid: "admin"},
    usageRefForInstitution: () => usage,
  });
  const bucket = {file: () => ({delete: async () => {}})};

  it("conserva cuota ante Storage fallido y reintenta", async () => {
    await assert.rejects(remove({file: () => ({delete: async () => {
      throw new Error("storage-unavailable");
    }})}));
    assert.equal((await ref.get()).data().status, "deleting");
    assert.equal((await usage.get()).data().usedBytes, 300);
    assert.equal((await db.doc("file_download_receipts/receipt").get())
        .exists, true);
    assert.equal(await remove(bucket), true);
    assert.equal((await ref.get()).exists, false);
    assert.equal((await usage.get()).data().usedBytes, 200);
    assert.equal((await db.doc("file_download_receipts/receipt").get())
        .exists, false);
    assert.equal((await db.collection("file_history").get()).size, 1);
  });

  it("eliminaciones concurrentes descuentan y auditan una vez", async () => {
    const result = await Promise.all([remove(bucket), remove(bucket)]);
    assert.equal(result.filter(Boolean).length, 1);
    assert.equal((await usage.get()).data().usedBytes, 200);
    assert.equal((await db.collection("file_history").get()).size, 1);
  });

  it("libera reservas sin descontar archivos confirmados", async () => {
    await ref.update({status: "uploading", expectedSize: 80});
    await usage.update({reservedBytes: 80});
    await remove(bucket);
    assert.equal((await usage.get()).data().usedBytes, 300);
    assert.equal((await usage.get()).data().reservedBytes, 0);
  });

  it("rechaza alcance ajeno antes de tocar Storage", async () => {
    let calls = 0;
    await assert.rejects(remove({file: () => ({delete: async () => calls++})},
        () => {
          throw new Error("permission-denied");
        }));
    assert.equal(calls, 0);
    assert.equal((await ref.get()).data().status, "active");
  });

  const cancel = (storageBucket = bucket) => cancelUpload({
    db, ref, bucket: storageBucket, source: "cancel_upload",
    caller: {uid: "teacher", institution: "inst", campus: "campus"},
    usageRefForInstitution: () => usage,
  });

  it("cancelar no borra una publicación que ya fue confirmada", async () => {
    await ref.update({uploadedBy: "teacher"});
    let calls = 0;
    await assert.rejects(cancel({file: () => ({delete: async () => calls++})}),
        {code: "permission-denied"});
    assert.equal(calls, 0);
    assert.equal((await ref.get()).data().status, "active");
  });

  it("cancelación fallida es reintentable sin confirmar", async () => {
    await ref.update({uploadedBy: "teacher", status: "uploading",
      expectedSize: 80});
    await usage.update({reservedBytes: 80});
    await assert.rejects(cancel({file: () => ({delete: async () => {
      throw new Error("storage-unavailable");
    }})}));
    assert.equal((await ref.get()).data().status, "deleting");
    assert.equal((await usage.get()).data().reservedBytes, 80);
    await Promise.all([cancel(), cancel()]);
    assert.equal((await usage.get()).data().usedBytes, 300);
    assert.equal((await usage.get()).data().reservedBytes, 0);
    assert.equal((await db.collection("file_history").get()).size, 1);
  });
});
