"use strict";
/* eslint-disable max-len */
const assert = require("assert");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");
const {seedAcademicYear} = require("./academic_year_fixture");
const {eventFunctions} = require("../events");

const projectId = "sistema-educativo-events-test";
const functionsBase = `http://127.0.0.1:${process.env.RELEASE_FUNCTIONS_PORT || 5002}/${projectId}/us-central1`;
const authBase = `http://127.0.0.1:${process.env.RELEASE_AUTH_PORT || 9098}/identitytoolkit.googleapis.com/v1`;
let app; let auth; let db; let yearId;
const tokens = {};

async function clear() {
  await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${projectId}/databases/(default)/documents`, {method: "DELETE"});
  const users = await auth.listUsers(1000);
  if (users.users.length) await auth.deleteUsers(users.users.map((user) => user.uid));
  for (const key of Object.keys(tokens)) delete tokens[key];
}

async function seedUser(uid, role, extra = {}) {
  const email = `${uid}@colegio.test`;
  await auth.createUser({uid, email, password: "Clave123!", emailVerified: true});
  await db.collection("users").doc(uid).set({
    firstName: uid, lastName: "Prueba", institutionalEmail: email,
    role, status: "activo", institution: "i", campus: "c",
    permissions: [], studentIds: [], ...extra,
  });
  const response = await fetch(`${authBase}/accounts:signInWithPassword?key=x`, {
    method: "POST", headers: {"content-type": "application/json"},
    body: JSON.stringify({email, password: "Clave123!", returnSecureToken: true}),
  });
  tokens[uid] = (await response.json()).idToken;
}

async function call(name, data, uid) {
  const response = await fetch(`${functionsBase}/${name}`, {
    method: "POST", headers: {
      "content-type": "application/json",
      "authorization": `Bearer ${tokens[uid]}`,
    },
    body: JSON.stringify({data}),
  });
  return response.json();
}

function status(response, expected) {
  assert.equal(response.error?.status, expected, JSON.stringify(response));
}

function futureEvent(overrides = {}) {
  const start = Date.now() + 86400000;
  return {
    title: "Salida pedagógica", description: "Visita al museo",
    location: "Museo", startAtMillis: start,
    endAtMillis: start + 7200000, audienceType: "groups",
    targetGroupIds: ["g1"], targetStudentIds: [],
    responsibleUserIds: ["teacher"], registrationRequired: true,
    requiresFamilyAuthorization: true, capacity: 2, links: [], ...overrides,
  };
}

describe("eventos institucionales", () => {
  before(() => {
    app = initializeApp({projectId}, "event-function-tests");
    auth = getAuth(app); db = getFirestore(app);
  });
  after(() => deleteApp(app));
  beforeEach(async () => {
    await clear();
    yearId = await seedAcademicYear(db, "i", "c");
    for (const [id, name] of [["g1", "Quinto A"], ["g2", "Sexto A"]]) {
      await db.collection("academic_groups").doc(id).set({
        institutionId: "i", campusId: "c", academicYearId: yearId,
        academicYear: 2026, name, active: true,
      });
    }
    await seedUser("teacher", "Docente", {
      permissions: ["eventos.ver", "eventos.crear", "eventos.editar"],
      tutorGroupId: "g1",
    });
    await seedUser("replacement", "Docente", {
      permissions: ["eventos.ver", "eventos.crear", "eventos.editar"],
    });
    await seedUser("student1", "Estudiante", {
      permissions: ["eventos.ver"], groupId: "g1", groupName: "Quinto A",
    });
    await seedUser("student2", "Estudiante", {
      permissions: ["eventos.ver"], groupId: "g1", groupName: "Quinto A",
    });
    await seedUser("outsider", "Estudiante", {
      permissions: ["eventos.ver"], groupId: "g2", groupName: "Sexto A",
    });
    await seedUser("family", "Familiar", {
      permissions: ["eventos.ver"], studentIds: ["student1"],
      activeStudentId: "student1",
    });
    await seedUser("admin", "Administrador", {
      permissions: ["eventos.ver", "eventos.crear", "eventos.editar", "usuarios.editar"],
    });
  });

  it("limita al docente y materializa de nuevo la audiencia al publicar", async () => {
    const contexts = (await call("listarContextosEventos", {}, "teacher")).result;
    assert.deepEqual(contexts.groups.map((item) => item.id), ["g1"]);
    assert.deepEqual(contexts.students.map((item) => item.id).sort(), ["student1", "student2"]);
    status(await call("guardarEvento", futureEvent({targetGroupIds: ["g2"]}), "teacher"), "PERMISSION_DENIED");
    status(await call("guardarEvento", futureEvent({
      audienceType: "students", targetGroupIds: [], targetStudentIds: ["outsider"],
    }), "teacher"), "PERMISSION_DENIED");
    const individual = await call("guardarEvento", futureEvent({
      audienceType: "students", targetGroupIds: [], targetStudentIds: ["student1"],
    }), "teacher");
    assert.deepEqual((await db.collection("school_events").doc(individual.result.eventId).get())
        .data().targetStudentIds, ["student1"]);
    const created = await call("guardarEvento", futureEvent(), "teacher");
    assert.ok(created.result.eventId, JSON.stringify(created));
    await seedUser("student3", "Estudiante", {
      permissions: ["eventos.ver"], groupId: "g1", groupName: "Quinto A",
    });
    const published = await call("cambiarEstadoEvento", {
      eventId: created.result.eventId, expectedRevision: 1, status: "published",
    }, "teacher");
    assert.equal(published.result.revision, 2);
    const stored = (await db.collection("school_events").doc(created.result.eventId).get()).data();
    assert.deepEqual(stored.targetStudentIds.sort(), ["student1", "student2", "student3"]);
    assert.deepEqual(stored.recipientUserIds.sort(),
        ["family", "student1", "student2", "student3", "teacher"]);
    assert.equal((await db.collection("event_notification_events").get()).size, 1);
    const report = (await call("generarReporteEventos", {
      fromMillis: Date.now(), toMillis: Date.now() + 2 * 86400000,
      status: "published",
    }, "teacher")).result;
    assert.equal(report.count, 1);
    assert.equal(report.rows[0].targetCount, 3);
    status(await call("generarReporteEventos", {
      fromMillis: Date.now(), toMillis: Date.now() + 2 * 86400000,
    }, "student1"), "PERMISSION_DENIED");
  });

  it("mantiene privacidad por hijo, respuestas independientes y controla el cupo", async () => {
    const created = (await call("guardarEvento", futureEvent({capacity: 1}), "admin")).result;
    await call("cambiarEstadoEvento", {
      eventId: created.eventId, expectedRevision: 1, status: "published",
    }, "admin");
    const learner = (await call("listarEventos", {}, "student1")).result;
    assert.equal(learner.events.length, 1);
    assert.deepEqual(learner.events[0].targetGroupIds, []);
    assert.equal(Object.hasOwn(learner.events[0], "targetStudentIds"), false);
    status(await call("listarEventos", {studentId: "student2"}, "family"), "PERMISSION_DENIED");
    assert.equal((await call("responderEvento", {
      eventId: created.eventId, studentId: "student1", response: "attending",
    }, "family")).result.response, "attending");
    await seedUser("family2", "Familiar", {
      permissions: ["eventos.ver"], studentIds: ["student2"], activeStudentId: "student2",
    });
    status(await call("responderEvento", {
      eventId: created.eventId, studentId: "student2", response: "attending",
    }, "family2"), "RESOURCE_EXHAUSTED");
  });

  it("registra asistencia solo al iniciar y audita cada operación", async () => {
    const created = (await call("guardarEvento", futureEvent(), "admin")).result;
    await call("cambiarEstadoEvento", {
      eventId: created.eventId, expectedRevision: 1, status: "published",
    }, "admin");
    status(await call("guardarAsistenciaEvento", {
      eventId: created.eventId,
      expectedRevision: 1,
      entries: [{studentId: "student1", state: "present"}],
    }, "teacher"), "FAILED_PRECONDITION");
    await db.collection("school_events").doc(created.eventId).update({
      startAt: new Date(Date.now() - 3600000), endAt: new Date(Date.now() + 3600000),
    });
    const saved = await call("guardarAsistenciaEvento", {
      eventId: created.eventId,
      expectedRevision: 1,
      entries: [
        {studentId: "student1", state: "present"},
        {studentId: "student2", state: "absent"},
      ],
    }, "teacher");
    assert.equal(saved.result.saved, 2);
    status(await call("guardarAsistenciaEvento", {
      eventId: created.eventId, expectedRevision: 1,
      entries: [{studentId: "student1", state: "absent"}],
    }, "teacher"), "ABORTED");
    status(await call("guardarAsistenciaEvento", {
      eventId: created.eventId,
      expectedRevision: 2,
      entries: [{studentId: "outsider", state: "present"}],
    }, "teacher"), "PERMISSION_DENIED");
    assert.equal((await db.collection("event_history").where("action", "==", "attendance_saved").get()).size, 1);
  });

  it("incluye eventos futuros en traslado temporal y reversión", async () => {
    const eventId = (await call("guardarEvento", futureEvent(), "teacher")).result.eventId;
    const preview = await call("previsualizarTrasladoDocente", {
      sourceTeacherId: "teacher", targetTeacherId: "replacement",
    }, "admin");
    assert.equal(preview.result.impact.futureEvents, 1);
    const transfer = await call("ejecutarTrasladoDocente", {
      sourceTeacherId: "teacher", targetTeacherId: "replacement",
      mode: "temporary", allowMerge: true, endsAtMillis: Date.now() + 86400000,
    }, "admin");
    assert.deepEqual((await db.collection("school_events").doc(eventId).get()).data().responsibleUserIds, ["replacement"]);
    await call("revertirTrasladoDocenteTemporal", {id: transfer.result.id}, "admin");
    assert.deepEqual((await db.collection("school_events").doc(eventId).get()).data().responsibleUserIds, ["teacher"]);
  });

  it("rechaza fechas inválidas, enlaces con credenciales y ediciones de años cerrados", async () => {
    await db.collection("users").doc("teacher").update({permissions: ["eventos.ver", "eventos.editar"]});
    status(await call("guardarEvento", futureEvent({eventId: 1}), "teacher"), "INVALID_ARGUMENT");
    status(await call("guardarEvento", futureEvent(), "teacher"), "PERMISSION_DENIED");
    status(await call("guardarEvento", futureEvent({startAtMillis: Number.MAX_SAFE_INTEGER}), "admin"), "INVALID_ARGUMENT");
    status(await call("guardarEvento", futureEvent({links: [{label: "Documento", url: "https://usuario:clave@example.com"}]}), "admin"), "INVALID_ARGUMENT");
    const eventId = (await call("guardarEvento", futureEvent(), "admin")).result.eventId;
    await db.collection("academic_years").doc(yearId).update({status: "closed"});
    await seedAcademicYear(db, "i", "c", 2027);
    status(await call("cambiarEstadoEvento", {
      eventId, expectedRevision: 1, status: "published",
    }, "admin"), "FAILED_PRECONDITION");
    assert.equal((await db.collection("school_events").doc(eventId).get()).data().status, "draft");
  });

  it("publica grupos de más de 200 estudiantes sin confundir audiencia derivada con individual", async () => {
    const batch = db.batch();
    for (let index = 0; index < 201; index++) {
      batch.set(db.collection("users").doc(`bulk_${index}`), {
        role: "Estudiante", status: "activo", institution: "i", campus: "c",
        groupId: "g1", firstName: `Estudiante ${index}`, lastName: "Prueba",
      });
    }
    await batch.commit();
    const created = await call("guardarEvento", futureEvent(), "teacher");
    const published = await call("cambiarEstadoEvento", {
      eventId: created.result.eventId, expectedRevision: 1, status: "published",
    }, "teacher");
    assert.equal(published.result?.revision, 2, JSON.stringify(published));
    assert.equal((await db.collection("school_events").doc(created.result.eventId).get()).data().targetStudentIds.length, 203);
  });

  it("vuelve a validar responsables y conserva cancelaciones publicadas visibles sin filtrar borradores", async () => {
    const eventId = (await call("guardarEvento", futureEvent(), "admin")).result.eventId;
    await db.collection("users").doc("teacher").update({status: "inactivo"});
    status(await call("cambiarEstadoEvento", {eventId, expectedRevision: 1, status: "published"}, "admin"), "PERMISSION_DENIED");
    await db.collection("users").doc("teacher").update({status: "activo"});
    await call("cambiarEstadoEvento", {eventId, expectedRevision: 1, status: "published"}, "admin");
    await call("cambiarEstadoEvento", {eventId, expectedRevision: 2, status: "cancelled"}, "admin");
    const draftId = (await call("guardarEvento", futureEvent(), "admin")).result.eventId;
    await call("cambiarEstadoEvento", {eventId: draftId, expectedRevision: 1, status: "cancelled"}, "admin");
    const visible = (await call("listarEventos", {}, "student1")).result.events;
    assert.deepEqual(visible.map((item) => item.id), [eventId]);
    assert.equal(visible[0].status, "cancelled");
  });

  it("no trunca listas y reportes después de los primeros 250 eventos", async () => {
    const startAt = new Date(Date.now() + 3600000);
    const batch = db.batch();
    for (let index = 0; index < 260; index++) {
      batch.set(db.collection("school_events").doc(`bulk_${index}`), {
        institutionId: "i", campusId: "c", academicYearId: yearId,
        title: `Evento ${index}`, location: "Colegio", status: "published",
        startAt, endAt: new Date(startAt.getTime() + 3600000),
        targetStudentIds: ["student1"], targetGroupIds: ["g1"], responsibleUserIds: ["teacher"],
      });
    }
    await batch.commit();
    assert.equal((await call("listarEventos", {}, "student1")).result.events.length, 260);
    const report = (await call("generarReporteEventos", {
      fromMillis: Date.now(), toMillis: Date.now() + 86400000,
    }, "teacher")).result;
    assert.equal(report.count, 260);
  });

  it("pagina recordatorios, revalida familiares y no duplica el outbox", async () => {
    const created = (await call("guardarEvento", futureEvent({
      startAtMillis: Date.now() + 7200000, endAtMillis: Date.now() + 10800000,
    }), "admin")).result;
    await call("cambiarEstadoEvento", {eventId: created.eventId, expectedRevision: 1, status: "published"}, "admin");
    await db.collection("users").doc("family").update({studentIds: [], activeStudentId: null});
    await seedUser("newfamily", "Familiar", {
      permissions: ["eventos.ver"], studentIds: ["student1"], activeStudentId: "student1",
    });
    const template = (await db.collection("school_events").doc(created.eventId).get()).data();
    for (let offset = 0; offset < 501; offset += 450) {
      const batch = db.batch();
      for (let index = offset; index < Math.min(offset + 450, 501); index++) {
        batch.set(db.collection("school_events").doc(`reminded_${index}`), {
          ...template, startAt: new Date(Date.now() + 3600000), reminderSentAt: new Date(),
        });
      }
      await batch.commit();
    }
    const scheduler = eventFunctions(db, null, null).procesarRecordatoriosEventos;
    await scheduler.run({});
    const reminderRef = db.collection("event_notification_events").doc(`reminder_${created.eventId}`);
    const reminder = (await reminderRef.get()).data();
    assert.ok(reminder, "A pending event after the first page must receive its reminder");
    assert.ok(!reminder.recipientUserIds.includes("family"));
    assert.ok(reminder.recipientUserIds.includes("newfamily"));
    assert.ok(reminder.recipientUserIds.includes("teacher"));
    await scheduler.run({});
    assert.equal((await db.collection("event_notification_events").where("kind", "==", "reminder").get()).size, 1);
  });

  it("una cancelación o traslado concurrente no permite guardar asistencia con datos anteriores", async () => {
    const eventId = (await call("guardarEvento", futureEvent(), "admin")).result.eventId;
    const eventRef = db.collection("school_events").doc(eventId);
    await eventRef.update({status: "published", startAt: new Date(Date.now() - 3600000)});
    const teacher = {...(await db.collection("users").doc("teacher").get()).data(), uid: "teacher"};
    let concurrentUpdate = {status: "cancelled"};
    const raceDb = new Proxy(db, {
      get(target, key) {
        if (key === "runTransaction") {
          return async (callback) => {
            await eventRef.update(concurrentUpdate);
            return target.runTransaction(callback);
          };
        }
        const value = target[key];
        return typeof value === "function" ? value.bind(target) : value;
      },
    });
    const functions = eventFunctions(raceDb, async () => teacher, null);
    const data = {eventId, expectedRevision: 1, entries: [{studentId: "student1", state: "present"}]};
    await assert.rejects(functions.guardarAsistenciaEvento.run({data}), {code: "failed-precondition"});
    await eventRef.update({status: "published"});
    concurrentUpdate = {responsibleUserIds: ["replacement"]};
    await assert.rejects(functions.guardarAsistenciaEvento.run({data}), {code: "permission-denied"});
    assert.equal((await db.collection("event_attendance").get()).size, 0);
  });
});
/* eslint-enable max-len */
