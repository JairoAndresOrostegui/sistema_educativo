"use strict";
/* eslint-disable max-len */
const assert = require("assert");
const {createAcademicPushValidator} = require("../academic_push_access");

function fixture() {
  const values = new Map();
  const snapshot = (path) => ({
    id: path.split("/").pop(), exists: values.has(path),
    data: () => values.get(path),
  });
  const db = {
    collection: (name) => ({
      doc: (id) => ({path: `${name}/${id}`,
        get: async () => snapshot(`${name}/${id}`)}),
      where: (field, operator, list) => ({get: async () => ({
        docs: [...values].filter(([path, value]) =>
          path.startsWith(`${name}/`) && operator === "in" &&
          list.includes(field.split(".").reduce((item, key) =>
            item?.[key], value))).map(([path]) => snapshot(path)),
      })}),
    }),
    getAll: async (...refs) => refs.map((ref) => snapshot(ref.path)),
  };
  const tenant = {institutionId: "i", campusId: "c", academicYearId: "year"};
  const user = (role, extra = {}) => ({
    institution: "i", campus: "c", status: "activo", role,
    permissions: ["eventos.ver", "asistencia.ver"], ...extra,
  });
  values.set("users/childA", user("Estudiante", {
    notificationTokens: {mobile: "token-A"},
  }));
  values.set("users/childB", user("Estudiante", {
    notificationTokens: {mobile: "token-B"},
  }));
  values.set("users/family", user("Familiar", {studentIds: ["childA"],
    activeStudentId: "childB", notificationTokens: {web: "token-family"},
  }));
  values.set("users/teacher", user("Docente", {
    notificationTokens: {mobile: "token-teacher"},
  }));
  values.set("school_events/event", {...tenant, status: "published",
    publishedAt: new Date(), targetStudentIds: ["childA"],
    responsibleUserIds: ["teacher"],
  });
  values.set("event_notification_events/event-notice", {...tenant,
    eventId: "event", recipientUserIds: ["childA", "family", "teacher"],
  });
  values.set("attendance_sessions/session", {...tenant, status: "closed",
    studentIds: ["childA", "childB"],
  });
  values.set("attendance_notification_events/attendance-notice", {...tenant,
    sessionId: "session", studentIds: ["childA"],
  });
  const jobs = {
    event: {...tenant, notificationEventId: "event-notice",
      message: {data: {type: "event", eventId: "event"}}},
    attendance: {...tenant, notificationEventId: "attendance-notice",
      message: {data: {type: "attendance", sessionId: "session"}}},
  };
  return {values, user, jobs, validate: createAcademicPushValidator(db)};
}

describe("revalidación de avisos de Eventos y Asistencia", () => {
  it("usa vínculos vigentes sin exigir que ese hijo sea el seleccionado", async () => {
    const {validate, jobs, values} = fixture();
    const tokens = ["token-A", "token-B", "token-family", "token-teacher"];
    assert.deepEqual(await validate(jobs.event, tokens),
        ["token-A", "token-family", "token-teacher"]);
    assert.deepEqual(await validate(jobs.attendance, tokens),
        ["token-A", "token-family"]);
    values.get("users/family").studentIds = ["childB"];
    assert.deepEqual(await validate(jobs.attendance, tokens), ["token-A"]);
    assert.deepEqual(await validate(jobs.event, tokens),
        ["token-A", "token-teacher"]);
  });

  it("en un reintento excluye docentes trasladados, usuarios inactivos y permisos retirados", async () => {
    const {validate, jobs, values} = fixture();
    values.get("school_events/event").responsibleUserIds = ["replacement"];
    values.get("users/childA").status = "inactivo";
    assert.deepEqual(await validate(jobs.event,
        ["token-A", "token-family", "token-teacher"]), []);
    values.get("users/childA").status = "activo";
    values.get("users/family").permissions = [];
    assert.deepEqual(await validate(jobs.event,
        ["token-A", "token-family", "token-teacher"]), ["token-A"]);
  });

  it("falla cerrado sin outbox original o con cualquier alcance discordante", async () => {
    const {validate, jobs, values} = fixture();
    assert.deepEqual(await validate({...jobs.event,
      notificationEventId: undefined}, ["token-A"]), []);
    assert.deepEqual(await validate({...jobs.event,
      campusId: "otra"}, ["token-A"]), []);
    values.get("attendance_notification_events/attendance-notice")
        .academicYearId = "otro-year";
    assert.deepEqual(await validate(jobs.attendance, ["token-A"]), []);
    values.delete("event_notification_events/event-notice");
    assert.deepEqual(await validate(jobs.event, ["token-A"]), []);
  });

  it("permite avisos de cancelación publicada, nunca borradores ni sesiones abiertas", async () => {
    const {validate, jobs, values} = fixture();
    values.get("school_events/event").status = "cancelled";
    assert.deepEqual(await validate(jobs.event, ["token-A"]), ["token-A"]);
    values.get("event_notification_events/event-notice").kind = "reminder";
    assert.deepEqual(await validate(jobs.event, ["token-A"]), []);
    delete values.get("event_notification_events/event-notice").kind;
    delete values.get("school_events/event").publishedAt;
    assert.deepEqual(await validate(jobs.event, ["token-A"]), []);
    values.get("attendance_sessions/session").status = "open";
    assert.deepEqual(await validate(jobs.attendance, ["token-A"]), []);
    values.get("school_events/event").status = "archived";
    assert.deepEqual(await validate(jobs.event, ["token-A"]), []);
  });

  it("no amplía destinatarios ni usa un token reemplazado por otro login", async () => {
    const {validate, jobs, values, user} = fixture();
    values.get("users/childA").notificationTokens.mobile = "new-token-A";
    values.set("users/newfamily", user("Familiar", {studentIds: ["childA"],
      notificationTokens: {web: "new-family-token"},
    }));
    assert.deepEqual(await validate(jobs.event,
        ["token-A", "new-family-token"]), []);
    values.get("users/family").campus = "otra";
    assert.deepEqual(await validate(jobs.event, ["token-family"]), []);
  });
});
