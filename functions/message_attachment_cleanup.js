"use strict";

const {FieldValue} = require("firebase-admin/firestore");
const {HttpsError} = require("firebase-functions/v2/https");

/**
 * Claims an immutable attachment before touching Storage. Retries may repeat
 * the object deletion, but only one transaction discounts its quota.
 */
async function deleteMessageAttachment({
  db, bucket, ref, usageRefForInstitution, authorize, kind, performedBy,
  threshold = null, expectedStatus = null,
}) {
  const deletingStatus = kind === "retention" ? "deleting" : "canceling";
  const attachment = await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    if (!snapshot.exists) return null;
    const current = snapshot.data();
    authorize(current);
    const allowed = kind === "retention" ?
      ["ready", "attached", deletingStatus] :
      ["uploading", "ready", deletingStatus];
    if (!allowed.includes(current.status) ||
        (expectedStatus && current.status !== expectedStatus &&
         current.status !== deletingStatus)) {
      throw new HttpsError("failed-precondition",
          "El adjunto ya fue enviado o esta siendo procesado.");
    }
    if (kind === "retention" &&
        (!current.retentionExpiresAt?.toMillis || !threshold ||
         current.retentionExpiresAt.toMillis() > threshold.toMillis())) {
      return null;
    }
    if (current.status !== deletingStatus) {
      const claimed = {
        status: deletingStatus,
        deletionQuotaKind: current.status === "uploading" ? "reserved" : "used",
        deletionBytes: Number(current.expectedSize || current.sizeBytes || 0),
        deletionRequestedAt: FieldValue.serverTimestamp(),
      };
      tx.update(ref, claimed);
      return {...current, ...claimed};
    }
    return current;
  });
  if (!attachment) return false;

  // Never return to ready/attached after a failed or interrupted deletion.
  // The retryable state also blocks a concurrent send or confirmation.
  await bucket.file(attachment.storagePath).delete({ignoreNotFound: true});

  const receipts = await db.collection("message_attachment_downloads")
      .where("attachmentId", "==", ref.id).get();
  for (let offset = 0; offset < receipts.size; offset += 400) {
    const batch = db.batch();
    receipts.docs.slice(offset, offset + 400)
        .forEach((receipt) => batch.delete(receipt.ref));
    await batch.commit();
  }
  const usageRef = usageRefForInstitution(attachment.institutionId);
  return db.runTransaction(async (tx) => {
    const [fresh, usageSnapshot] = await Promise.all([
      tx.get(ref), tx.get(usageRef),
    ]);
    if (!fresh.exists) return false;
    const current = fresh.data();
    if (current.status !== deletingStatus) {
      throw new HttpsError("failed-precondition",
          "La eliminacion requiere revision antes de continuar.");
    }
    const field = current.deletionQuotaKind === "reserved" ?
      "reservedBytes" : "usedBytes";
    const usage = usageSnapshot.data() || {};
    tx.set(usageRef, {
      [field]: Math.max(0, Number(usage[field] || 0) -
        Number(current.deletionBytes || 0)),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    tx.create(db.collection("messaging_audit").doc(), {
      action: kind === "retention" ?
        "attachment_deleted_by_retention" : "attachment_cancelled",
      attachmentId: ref.id,
      channelId: current.channelId,
      institutionId: current.institutionId,
      campusId: current.campusId,
      academicYearId: current.academicYearId,
      performedBy,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.delete(ref);
    return true;
  });
}

/** Retries requested cancellations, never published attachments. */
async function retryMessageAttachmentCancellations({
  db, bucket, usageRefForInstitution,
}) {
  const snapshot = await db.collection("message_attachments")
      .where("status", "==", "canceling").limit(100).get();
  let removed = 0;
  const failures = [];
  for (const item of snapshot.docs) {
    try {
      const deleted = await deleteMessageAttachment({
        db, bucket, ref: item.ref, usageRefForInstitution,
        kind: "cancel", expectedStatus: "canceling",
        performedBy: "system:attachment-cancel-retry",
        authorize: (value) => {
          if (value.status !== "canceling") {
            throw new HttpsError("failed-precondition",
                "La cancelacion ya no esta pendiente.");
          }
        },
      });
      if (deleted) removed++;
    } catch (error) {
      failures.push({id: item.id, code: String(error.code || "unavailable")});
    }
  }
  return {checked: snapshot.size, removed, failures};
}

module.exports = {deleteMessageAttachment, retryMessageAttachmentCancellations};
