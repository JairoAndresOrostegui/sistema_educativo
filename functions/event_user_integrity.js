"use strict";

const {HttpsError} = require("firebase-functions/v2/https");

// An event keeps historical identity and financial acknowledgements. Until a
// dedicated archival/anonymization workflow exists, permanent deletion must
// stop before Auth, Storage or profiles are modified. Logical retirement works.
const RELATIONS = [
  ["school_events", "createdBy", "=="],
  ["school_events", "responsibleUserIds", "array-contains"],
  ["school_events", "targetStudentIds", "array-contains"],
  ["event_responses", "studentId", "=="],
  ["event_responses", "respondedBy", "=="],
  ["event_attendance", "studentId", "=="],
  ["event_attendance", "markedBy", "=="],
  ["event_food_items", "createdBy", "=="],
  ["event_materials", "createdBy", "=="],
  ["event_food_orders", "familyId", "=="],
  ["event_food_orders", "studentId", "=="],
  ["event_food_orders", "performedBy", "=="],
  ["event_requirement_completions", "targetId", "=="],
  ["event_requirement_completions", "studentContextIds", "array-contains"],
  ["event_requirement_completions", "performedBy", "=="],
];

async function eventUserReferences(db, uid) {
  const snapshots = await Promise.all(RELATIONS.map(([name, field, operator]) =>
    db.collection(name).where(field, operator, uid).limit(2001).get()));
  // A bounded preview must not prevent logical retirement. The count becomes
  // a lower bound on overflow; any known relation still blocks deletion.
  const truncated = snapshots.some((snapshot) => snapshot.size > 2000);
  const paths = new Set();
  for (const snapshot of snapshots) {
    for (const doc of snapshot.docs) paths.add(doc.ref.path);
  }
  return {count: paths.size, truncated};
}

function requireNoEventReferences(value) {
  if (value.count) {
    throw new HttpsError("failed-precondition",
        "El usuario conserva registros de Eventos, pedidos o cumplimientos. " +
        "Usa la baja lógica: la eliminación definitiva dejaría " +
        "registros sin identidad y no está permitida.");
  }
}

module.exports = {eventUserReferences, requireNoEventReferences, RELATIONS};
