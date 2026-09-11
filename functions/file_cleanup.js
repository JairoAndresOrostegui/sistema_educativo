"use strict";
const {FieldValue} = require("firebase-admin/firestore");
const {HttpsError} = require("firebase-functions/v2/https");

// Storage cannot participate in Firestore transactions. Claim first, retain a
// retryable tombstone on failure, and account for each object exactly once.
async function deleteFile({db, bucket, ref, usageRefForInstitution,
  authorize, caller, source}) {
  const file = await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    if (!snapshot.exists) return null;
    const value = snapshot.data();
    await authorize(value);
    if (!["active", "uploading", "deleting"].includes(value.status)) {
      throw new HttpsError("failed-precondition",
          "El archivo tiene un estado que requiere revisión.");
    }
    if (value.status !== "deleting") {
      tx.update(ref, {status: "deleting",
        deletionPreviousStatus: value.status,
        deletionRequestedBy: caller.uid,
        deletionRequestedAt: FieldValue.serverTimestamp()});
    } else if (!["active", "uploading"]
        .includes(value.deletionPreviousStatus)) {
      throw new HttpsError("failed-precondition",
          "La eliminación anterior requiere revisar su reserva de cuota.");
    }
    return value;
  });
  if (!file) return false;
  // A failure leaves 'deleting'; never revive a physically removed file.
  await bucket.file(file.storagePath).delete({ignoreNotFound: true});
  const receipts = await db.collection("file_download_receipts")
      .where("fileId", "==", ref.id).get();
  for (let offset = 0; offset < receipts.size; offset += 400) {
    const batch = db.batch();
    receipts.docs.slice(offset, offset + 400).forEach((item) =>
      batch.delete(item.ref));
    await batch.commit();
  }
  return db.runTransaction(async (tx) => {
    const current = await tx.get(ref);
    if (!current.exists) return false;
    const value = current.data();
    if (value.status !== "deleting") {
      throw new HttpsError("aborted", "El estado del archivo cambió.");
    }
    const usageRef = usageRefForInstitution(value.institutionId);
    const usage = (await tx.get(usageRef)).data() || {};
    const used = value.deletionPreviousStatus === "active" ?
      Number(value.sizeBytes || 0) : 0;
    const reserved = value.deletionPreviousStatus === "uploading" ?
      Number(value.expectedSize || 0) : 0;
    tx.set(usageRef, {
      usedBytes: Math.max(0, Number(usage.usedBytes || 0) - used),
      reservedBytes: Math.max(0, Number(usage.reservedBytes || 0) - reserved),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    tx.create(db.collection("file_history").doc(), {
      fileId: ref.id, fileName: value.name || "",
      storagePath: value.storagePath,
      action: "deleted", source, performedBy: caller.uid,
      performedByName:
        `${caller.firstName || ""} ${caller.lastName || ""}`.trim(),
      institutionId: value.institutionId, campusId: value.campusId,
      academicYearId: value.academicYearId || "",
      academicYear: value.academicYear || null,
      audienceType: value.audienceType || "groups",
      targetGroupIds: value.targetGroupIds || [],
      groupId: value.targetGroupIds?.length === 1 ?
        value.targetGroupIds[0] : "",
      groupName: value.targetGroupNames?.length === 1 ?
        value.targetGroupNames[0] : "",
      targetStudentIds: value.targetStudentIds || [],
      sizeBytes: Number(value.sizeBytes || 0),
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.delete(ref);
    return true;
  });
}
async function cancelUpload(options) {
  const {caller} = options;
  return deleteFile({...options, authorize: (file) => {
    const owns = caller.isSuperadmin === true ||
      (file.uploadedBy === caller.uid &&
       file.institutionId === caller.institution &&
       file.campusId === caller.campus);
    const uploading = file.status === "uploading" ||
      (file.status === "deleting" &&
       file.deletionPreviousStatus === "uploading");
    if (!owns || !uploading) {
      throw new HttpsError("permission-denied", "Reserva no disponible.");
    }
  }});
}
module.exports = {deleteFile, cancelUpload};
