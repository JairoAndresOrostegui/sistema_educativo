"use strict";

// Notification tokens are only delivery addresses, never proof of continuing
// access to a student's event or attendance. Called on every send/retry.
function createAcademicPushValidator(db) {
  const safeId = (value) => typeof value === "string" && value.length > 0 &&
    value.length <= 160 && !value.includes("/");
  const ids = (value) => Array.isArray(value) ?
    [...new Set(value.filter(safeId))] : [];
  const scopeMatches = (value, job) =>
    value.institutionId === job.institutionId &&
    value.campusId === job.campusId &&
    value.academicYearId === job.academicYearId;
  const userInScope = (value, job) => value.status === "activo" &&
    value.institution === job.institutionId && value.campus === job.campusId;
  const canView = (user, module) => user.isSuperadmin === true ||
    Array.isArray(user.permissions) &&
      user.permissions.includes(`${module}.ver`);

  return async (job, tokens) => {
    const type = job.message?.data?.type;
    if (!["attendance", "event"].includes(type)) return tokens;
    if (!tokens.length || !safeId(job.notificationEventId) ||
        !safeId(job.institutionId) || !safeId(job.campusId) ||
        !safeId(job.academicYearId)) return [];
    const isAttendance = type === "attendance";
    const entityId = job.message.data[isAttendance ? "sessionId" : "eventId"];
    if (!safeId(entityId)) return [];
    const [entitySnapshot, outboxSnapshot] = await Promise.all([
      db.collection(isAttendance ? "attendance_sessions" : "school_events")
          .doc(entityId).get(),
      db.collection(isAttendance ? "attendance_notification_events" :
        "event_notification_events").doc(job.notificationEventId).get(),
    ]);
    const entity = entitySnapshot.data() || {};
    const outbox = outboxSnapshot.data() || {};
    if (!entitySnapshot.exists || !outboxSnapshot.exists ||
        !scopeMatches(entity, job) || !scopeMatches(outbox, job) ||
        outbox[isAttendance ? "sessionId" : "eventId"] !== entityId) return [];
    if (isAttendance ? entity.status !== "closed" :
      !["published", "closed", "cancelled"].includes(entity.status) ||
        entity.status === "cancelled" && !entity.publishedAt) return [];
    if (!isAttendance && outbox.kind === "reminder" &&
        entity.status !== "published") return [];

    const recipientIds = new Set(ids(outbox.recipientUserIds));
    const roster = new Set(ids(isAttendance ? entity.studentIds :
      entity.targetStudentIds));
    const targetIds = isAttendance ? ids(outbox.studentIds)
        .filter((studentId) => roster.has(studentId)) : [...roster];
    const studentRefs = targetIds.map((studentId) =>
      db.collection("users").doc(studentId));
    const studentSnapshots = studentRefs.length ?
      await db.getAll(...studentRefs) : [];
    const activeTargets = new Set(studentSnapshots.filter((snapshot) => {
      const user = snapshot.data() || {};
      return snapshot.exists && user.role === "Estudiante" &&
        userInScope(user, job);
    }).map((snapshot) => snapshot.id));
    const responsibleIds = new Set(ids(entity.responsibleUserIds));
    const allowedTokens = new Set();
    for (let offset = 0; offset < tokens.length; offset += 30) {
      const chunk = tokens.slice(offset, offset + 30);
      for (const slot of ["web", "mobile"]) {
        const matches = await db.collection("users")
            .where(`notificationTokens.${slot}`, "in", chunk).get();
        for (const snapshot of matches.docs) {
          const user = snapshot.data();
          if (!userInScope(user, job) ||
              !canView(user, isAttendance ? "asistencia" : "eventos") ||
              !isAttendance && !recipientIds.has(snapshot.id)) continue;
          const allowed = user.role === "Estudiante" ?
            activeTargets.has(snapshot.id) : user.role === "Familiar" ?
              ids(user.studentIds).some((studentId) =>
                activeTargets.has(studentId)) :
              !isAttendance &&
                ["Administrador", "Docente"].includes(user.role) &&
                responsibleIds.has(snapshot.id);
          if (allowed) allowedTokens.add(user.notificationTokens[slot]);
        }
      }
    }
    return tokens.filter((token) => allowedTokens.has(token));
  };
}

module.exports = {createAcademicPushValidator};
