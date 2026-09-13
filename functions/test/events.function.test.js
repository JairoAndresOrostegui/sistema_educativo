"use strict";
/* eslint-disable max-len */
const assert = require("assert");
const crypto = require("crypto");
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
    eventType: "student_presentation", subtitle: "", foodEnabled: false,
    publicity: {text: "", url: ""}, requirements: [],
    title: "Salida pedagógica", description: "Visita al museo",
    location: "Museo", startAtMillis: start,
    endAtMillis: start + 7200000, audienceType: "groups",
    targetGroupIds: ["g1"], targetStudentIds: [],
    responsibleUserIds: ["teacher"], registrationRequired: true,
    requiresFamilyAuthorization: true, capacity: 2, links: [], ...overrides,
  };
}

async function operationalEvent(overrides = {}) {
  const created = await call("guardarEvento", futureEvent({foodEnabled: true,
    requirements: [
      {id: "uniform", label: "Traje preparado", instructions: "", targetType: "student", completionType: "manual", required: true, amountCop: null},
      {id: "meeting", label: "Asistencia familiar", instructions: "", targetType: "family", completionType: "attendance", required: true, amountCop: null},
      {id: "fee", label: "Aporte del evento", instructions: "", targetType: "student", completionType: "payment", required: false, amountCop: 12000},
    ], ...overrides}), "admin");
  assert.ok(created.result?.eventId, JSON.stringify(created));
  const eventId = created.result.eventId;
  const published = await call("cambiarEstadoEvento", {eventId, expectedRevision: 1, status: "published"}, "admin");
  assert.equal(published.result?.revision, 2, JSON.stringify(published));
  return eventId;
}

async function foodItem(eventId, priceCop = 7000) {
  const result = await call("guardarAlimentoEvento", {
    eventId, name: "Refrigerio", description: "Porción individual", priceCop, active: true,
  }, "admin");
  assert.ok(result.result?.itemId, JSON.stringify(result));
  return result.result.itemId;
}

async function qrFor(uid, type = "user") {
  const payload = `LLQ1:${crypto.randomBytes(32).toString("base64url")}`;
  const credentialId = crypto.createHash("sha256").update(`${type}:${uid}`).digest("hex");
  await db.collection("qr_credentials").doc(credentialId).set({
    targetType: type, targetId: uid, institutionId: "i", campusId: "c",
    tokenHash: crypto.createHash("sha256").update(payload).digest("hex"),
    payload, revision: 1, status: "active",
  });
  return {payload, credentialId};
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

  it("valida tipo, publicidad y requisitos, reservando configuración para administración", async () => {
    status(await call("guardarEvento", futureEvent({eventType: "festival"}), "admin"), "INVALID_ARGUMENT");
    status(await call("guardarEvento", futureEvent({eventType: "parent_meeting", foodEnabled: true}), "admin"), "INVALID_ARGUMENT");
    status(await call("guardarEvento", futureEvent({publicity: {text: "Aviso", url: "https://a:b@colegio.test"}}), "admin"), "INVALID_ARGUMENT");
    const requirement = {id: "x", label: "Uniforme", targetType: "student", completionType: "manual", required: true};
    status(await call("guardarEvento", futureEvent({requirements: [requirement, requirement]}), "admin"), "INVALID_ARGUMENT");
    status(await call("guardarEvento", futureEvent({requirements: [requirement]}), "teacher"), "PERMISSION_DENIED");
    status(await call("guardarEvento", futureEvent({foodEnabled: true}), "teacher"), "PERMISSION_DENIED");
    const draft = futureEvent({foodEnabled: true, requirements: [requirement]});
    const draftId = (await call("guardarEvento", draft, "admin")).result.eventId;
    assert.equal((await call("guardarEvento", {...draft, eventId: draftId, expectedRevision: 1, title: "Nombre corregido"}, "teacher")).result.revision, 2);
    status(await call("guardarEvento", {...draft, eventId: draftId, expectedRevision: 2, requirements: []}, "teacher"), "PERMISSION_DENIED");
    const eventId = await operationalEvent();
    const detail = (await call("obtenerDetalleEvento", {eventId}, "student1")).result;
    assert.equal(detail.event.schemaVersion, 2);
    assert.equal(detail.event.eventType, "student_presentation");
    assert.equal(detail.event.requirements.length, 3);
    assert.deepEqual(detail.participants, []);
    assert.equal(detail.capabilities.canOrder, false);
    status(await call("guardarEvento", futureEvent({eventId, expectedRevision: 2}), "admin"), "FAILED_PRECONDITION");
  });

  it("calcula preventa en backend, separa familiares e impide precios manipulados", async () => {
    const eventId = await operationalEvent();
    const itemId = await foodItem(eventId);
    status(await call("guardarAlimentoEvento", {eventId, name: "Comida", priceCop: 1, active: true}, "teacher"), "PERMISSION_DENIED");
    status(await call("guardarAlimentoEvento", {eventId, name: "Comida", priceCop: 0.1, active: true}, "admin"), "INVALID_ARGUMENT");
    const request = {eventId, studentId: "student1", expectedRevision: 0, requestId: "reserve-1", lines: [{itemId, quantity: 2}]};
    status(await call("reservarAlimentosEvento", {...request, totalCop: 1}, "family"), "INVALID_ARGUMENT");
    status(await call("reservarAlimentosEvento", {...request, lines: [{itemId, quantity: 1, priceCop: 1}]}, "family"), "INVALID_ARGUMENT");
    status(await call("reservarAlimentosEvento", request, "student1"), "PERMISSION_DENIED");
    const saved = await call("reservarAlimentosEvento", request, "family");
    assert.equal(saved.result?.totalCop, 14000, JSON.stringify(saved));
    assert.deepEqual((await call("reservarAlimentosEvento", request, "family")).result, saved.result);
    status(await call("reservarAlimentosEvento", {...request, lines: [{itemId, quantity: 3}]}, "family"), "ALREADY_EXISTS");
    assert.equal((await db.collection("event_history").where("action", "==", "food_order_saved").get()).size, 1);
    await seedUser("familyOther", "Familiar", {permissions: ["eventos.ver"], studentIds: ["student1"], activeStudentId: "student1"});
    assert.deepEqual((await call("obtenerDetalleEvento", {eventId, studentId: "student1"}, "familyOther")).result.orders, []);
    const other = await call("reservarAlimentosEvento", request, "familyOther");
    assert.notEqual(other.result.orderId, saved.result.orderId);
    assert.equal((await call("obtenerDetalleEvento", {eventId}, "admin")).result.orders.length, 2);
    const own = (await call("obtenerDetalleEvento", {eventId, studentId: "student1"}, "family")).result;
    assert.equal(own.orders.length, 1);
    assert.equal(own.orders[0].familyId, "family");
    const notice = (await db.collection("event_notification_events").where("kind", "==", "order_changed").get()).docs
        .find((item) => item.data().familyIds.includes("familyOther")).data();
    assert.ok(notice.recipientUserIds.includes("familyOther"));
    assert.ok(notice.recipientUserIds.includes("admin"));
    assert.ok(!notice.recipientUserIds.includes("family"));
    assert.ok(!notice.recipientUserIds.includes("student1"));
  });

  it("serializa carritos concurrentes y conserva precios históricos al cambiar catálogo", async () => {
    const eventId = await operationalEvent();
    const itemId = await foodItem(eventId);
    const base = {eventId, studentId: "student1", expectedRevision: 0, lines: [{itemId, quantity: 1}]};
    const results = await Promise.all(["first", "second"].map((requestId) => call("reservarAlimentosEvento", {...base, requestId}, "family")));
    assert.equal(results.filter((result) => result.result).length, 1);
    assert.equal(results.filter((result) => result.error?.status === "ABORTED").length, 1);
    await call("guardarAlimentoEvento", {eventId, itemId, expectedRevision: 1, name: "Refrigerio", priceCop: 9000, active: false}, "admin");
    const detail = (await call("obtenerDetalleEvento", {eventId}, "family")).result;
    assert.deepEqual(detail.foodItems, []);
    assert.equal(detail.orders[0].totalCop, 7000);
    status(await call("reservarAlimentosEvento", {...base, expectedRevision: 1, requestId: "disabled"}, "family"), "FAILED_PRECONDITION");
    const cancelled = await call("reservarAlimentosEvento", {...base, lines: [], expectedRevision: 1, requestId: "cancel", cancel: true}, "family");
    assert.equal(cancelled.result?.revision, 2, JSON.stringify(cancelled));
    assert.equal((await db.collection("event_food_orders").doc(cancelled.result.orderId).get()).data().state, "cancelled");
  });

  it("pago y entrega son manuales, auditados y bloquean cambios del carrito", async () => {
    const eventId = await operationalEvent();
    const itemId = await foodItem(eventId);
    const order = (await call("reservarAlimentosEvento", {eventId, studentId: "student1", expectedRevision: 0, requestId: "order", lines: [{itemId, quantity: 1}]}, "family")).result;
    const base = {eventId, orderId: order.orderId, expectedRevision: 1, requestId: "paid", paymentState: "paid"};
    status(await call("gestionarPedidoEvento", base, "family"), "PERMISSION_DENIED");
    status(await call("gestionarPedidoEvento", base, "replacement"), "PERMISSION_DENIED");
    status(await call("gestionarPedidoEvento", {...base, paymentState: null, deliveryState: "delivered"}, "teacher"), "FAILED_PRECONDITION");
    assert.equal((await call("gestionarPedidoEvento", base, "teacher")).result.revision, 2);
    assert.equal((await call("gestionarPedidoEvento", base, "teacher")).result.revision, 2);
    status(await call("reservarAlimentosEvento", {eventId, studentId: "student1", expectedRevision: 2, requestId: "rewrite", lines: [{itemId, quantity: 2}]}, "family"), "FAILED_PRECONDITION");
    status(await call("gestionarPedidoEvento", {...base, expectedRevision: 2, requestId: "early-deliver", deliveryState: "delivered"}, "teacher"), "FAILED_PRECONDITION");
    await db.collection("school_events").doc(eventId).update({startAt: new Date(Date.now() - 60000)});
    assert.equal((await call("gestionarPedidoEvento", {...base, expectedRevision: 2, requestId: "deliver", deliveryState: "delivered"}, "teacher")).result.revision, 3);
    status(await call("gestionarPedidoEvento", {...base, expectedRevision: 3, requestId: "undo", paymentState: "pending", deliveryState: "pending"}, "teacher"), "INVALID_ARGUMENT");
    assert.equal((await call("gestionarPedidoEvento", {...base, expectedRevision: 3, requestId: "undo-ok", paymentState: "pending", deliveryState: "pending", reason: "Marcación equivocada"}, "admin")).result.revision, 4);
  });

  it("materiales usan responsabilidad vigente y grupos de la audiencia", async () => {
    const eventId = await operationalEvent();
    const input = {eventId, kind: "costume", name: "Traje de presentación", instructions: "Traer preparado", amountCop: 12000,
      address: "Taller del barrio", url: "https://example.com/traje", groupIds: ["g1"], active: true};
    status(await call("guardarMaterialEvento", {...input, groupIds: ["g2"]}, "teacher"), "PERMISSION_DENIED");
    status(await call("guardarMaterialEvento", input, "family"), "PERMISSION_DENIED");
    status(await call("guardarMaterialEvento", input, "replacement"), "PERMISSION_DENIED");
    const saved = (await call("guardarMaterialEvento", input, "teacher")).result;
    assert.ok(saved.materialId);
    const transfer = (await call("ejecutarTrasladoDocente", {
      sourceTeacherId: "teacher", targetTeacherId: "replacement", mode: "temporary", allowMerge: true, endsAtMillis: Date.now() + 86400000,
    }, "admin")).result;
    const changed = await call("guardarMaterialEvento", {...input, materialId: saved.materialId, expectedRevision: 1, name: "Traje delegado"}, "replacement");
    assert.equal(changed.result?.revision, 2, JSON.stringify(changed));
    assert.equal((await db.collection("event_materials").doc(saved.materialId).get()).data().createdBy, "teacher");
    const completed = await call("guardarCumplimientoEvento", {eventId, requirementId: "uniform", targetType: "student", targetId: "student1", studentId: "student1", completed: true, expectedRevision: 0, requestId: "delegated"}, "replacement");
    assert.ok(completed.result?.completionId, JSON.stringify(completed));
    await call("revertirTrasladoDocenteTemporal", {id: transfer.id}, "admin");
    status(await call("guardarMaterialEvento", {...input, materialId: saved.materialId, expectedRevision: 2}, "replacement"), "PERMISSION_DENIED");
    assert.equal((await call("guardarMaterialEvento", {...input, materialId: saved.materialId, expectedRevision: 2}, "teacher")).result.revision, 3);
    assert.equal((await db.collection("event_requirement_completions").doc(completed.result.completionId).get()).data().performedBy, "replacement");
  });

  it("cumplimiento familiar es individual y no modifica asistencia ni otro adulto", async () => {
    const eventId = await operationalEvent();
    await seedUser("familyOther", "Familiar", {permissions: ["eventos.ver"], studentIds: ["student1"], activeStudentId: "student1"});
    const data = {eventId, requirementId: "meeting", targetType: "family", targetId: "family", studentId: "student1", completed: true, expectedRevision: 0, requestId: "meeting"};
    status(await call("guardarCumplimientoEvento", data, "admin"), "FAILED_PRECONDITION");
    await db.collection("school_events").doc(eventId).update({startAt: new Date(Date.now() - 60000)});
    status(await call("guardarCumplimientoEvento", data, "family"), "PERMISSION_DENIED");
    const saved = await call("guardarCumplimientoEvento", data, "teacher");
    assert.equal(saved.result?.revision, 1, JSON.stringify(saved));
    assert.deepEqual((await call("guardarCumplimientoEvento", data, "teacher")).result, saved.result);
    const own = (await call("obtenerDetalleEvento", {eventId}, "family")).result;
    assert.equal(own.completions.length, 1);
    assert.equal(own.completions[0].targetId, "family");
    assert.ok(own.completions[0].completedAtMillis);
    assert.deepEqual((await call("obtenerDetalleEvento", {eventId}, "familyOther")).result.completions, []);
    assert.deepEqual((await call("obtenerDetalleEvento", {eventId}, "student1")).result.completions, []);
    assert.equal((await db.collection("event_attendance").get()).size, 0);
    status(await call("guardarCumplimientoEvento", {...data, expectedRevision: 1, completed: false, requestId: "undo"}, "teacher"), "INVALID_ARGUMENT");
    assert.equal((await call("guardarCumplimientoEvento", {...data, expectedRevision: 1, completed: false, requestId: "undo-ok", reason: "Se identificó otro familiar"}, "teacher")).result.revision, 2);
  });

  it("pago de requisito usa importe administrativo y resuelve escrituras simultáneas", async () => {
    const eventId = await operationalEvent();
    const data = {eventId, requirementId: "fee", targetType: "student", targetId: "student1", studentId: "student1", completed: true, expectedRevision: 0};
    status(await call("guardarCumplimientoEvento", {...data, requestId: "price", amountCop: 1}, "teacher"), "INVALID_ARGUMENT");
    const results = await Promise.all(["first", "second"].map((requestId) => call("guardarCumplimientoEvento", {...data, requestId}, "teacher")));
    assert.equal(results.filter((result) => result.result).length, 1);
    assert.equal(results.filter((result) => result.error?.status === "ABORTED").length, 1);
    const stored = (await db.collection("event_requirement_completions").get()).docs[0].data();
    assert.equal(stored.amountCop, 12000);
    assert.deepEqual(stored.studentContextIds, ["student1"]);
  });

  it("QR prepara solo destinatarios del evento y guardar revalida revocación y vínculo", async () => {
    const eventId = await operationalEvent();
    await db.collection("users").doc("family").update({studentIds: ["student1", "outsider"]});
    const qr = await qrFor("family");
    const prepared = await call("prepararAccionesEventoQr", {eventId, payload: qr.payload, source: "camera"}, "teacher");
    assert.equal(prepared.result?.targetType, "family", JSON.stringify(prepared));
    assert.deepEqual(prepared.result.students.map((item) => item.id), ["student1"]);
    assert.ok(prepared.result.requirementIds.includes("uniform"));
    assert.equal((await db.collection("event_requirement_completions").get()).size, 0);
    const data = {eventId, requirementId: "uniform", targetType: "student", targetId: "student1", studentId: "student1", completed: true, expectedRevision: 0, requestId: "qr-complete", qrPayload: qr.payload};
    await db.collection("qr_credentials").doc(qr.credentialId).update({status: "revoked"});
    status(await call("guardarCumplimientoEvento", data, "teacher"), "PERMISSION_DENIED");
    await db.collection("qr_credentials").doc(qr.credentialId).update({status: "active"});
    await db.collection("users").doc("family").update({studentIds: ["outsider"]});
    status(await call("guardarCumplimientoEvento", data, "teacher"), "PERMISSION_DENIED");
    await db.collection("users").doc("family").update({studentIds: ["student1"]});
    assert.equal((await call("guardarCumplimientoEvento", data, "teacher")).result.revision, 1);
    const audit = (await db.collection("qr_audit").get()).docs;
    assert.ok(audit.length >= 2);
    assert.ok(audit.every((item) => !JSON.stringify(item.data()).includes(qr.payload)));
  });

  it("QR evento respeta hijo activo y QR de otro estudiante no confirma requisito", async () => {
    const eventId = await operationalEvent();
    const eventQr = await qrFor(eventId, "event");
    const prepared = await call("prepararAccionesEventoQr", {payload: eventQr.payload}, "family");
    assert.equal(prepared.result?.eventId, eventId, JSON.stringify(prepared));
    assert.deepEqual(prepared.result.students.map((item) => item.id), ["student1"]);
    status(await call("prepararAccionesEventoQr", {eventId, payload: eventQr.payload, studentId: "student2"}, "family"), "PERMISSION_DENIED");
    const qr = await qrFor("student2");
    status(await call("guardarCumplimientoEvento", {eventId, requirementId: "uniform", targetType: "student", targetId: "student1", studentId: "student1", completed: true, expectedRevision: 0, requestId: "wrong-qr", qrPayload: qr.payload}, "teacher"), "PERMISSION_DENIED");
  });

  it("retiro, cambio de hijo, sede, cancelación y cierre de año bloquean operaciones", async () => {
    const eventId = await operationalEvent();
    const itemId = await foodItem(eventId);
    const order = {eventId, studentId: "student1", expectedRevision: 0, requestId: "order", lines: [{itemId, quantity: 1}]};
    await db.collection("users").doc("family").update({activeStudentId: "student2", studentIds: ["student1", "student2"]});
    status(await call("reservarAlimentosEvento", order, "family"), "PERMISSION_DENIED");
    await db.collection("users").doc("family").update({activeStudentId: "student1"});
    await db.collection("users").doc("student1").update({status: "inactivo"});
    status(await call("reservarAlimentosEvento", order, "family"), "PERMISSION_DENIED");
    await db.collection("users").doc("student1").update({status: "activo"});
    await db.collection("users").doc("family").update({campus: "otra"});
    status(await call("obtenerDetalleEvento", {eventId}, "family"), "PERMISSION_DENIED");
    await db.collection("users").doc("family").update({campus: "c"});
    await db.collection("school_events").doc(eventId).update({status: "cancelled"});
    status(await call("reservarAlimentosEvento", order, "family"), "FAILED_PRECONDITION");
    await db.collection("school_events").doc(eventId).update({status: "published"});
    await db.collection("academic_years").doc(yearId).update({status: "closed"});
    status(await call("reservarAlimentosEvento", order, "family"), "FAILED_PRECONDITION");
    assert.equal((await call("obtenerDetalleEvento", {eventId}, "admin")).result.capabilities.canManageFulfillment, false);
    status(await call("obtenerDetalleEvento", {eventId}, "family"), "PERMISSION_DENIED");
  });

  it("un cambio de precio exige confirmar el total actualizado y no crea reserva fallida", async () => {
    const eventId = await operationalEvent();
    const itemId = await foodItem(eventId);
    const data = {eventId, studentId: "student1", expectedRevision: 0, requestId: "price-change", expectedTotalCop: 7000, lines: [{itemId, quantity: 1}]};
    await call("guardarAlimentoEvento", {eventId, itemId, expectedRevision: 1, name: "Refrigerio", priceCop: 9000, active: true}, "admin");
    status(await call("reservarAlimentosEvento", data, "family"), "ABORTED");
    assert.equal((await db.collection("event_food_orders").get()).size, 0);
    assert.equal((await db.collection("event_operation_requests").get()).size, 0);
    assert.equal((await call("reservarAlimentosEvento", {...data, expectedTotalCop: 9000}, "family")).result.totalCop, 9000);
  });
});
/* eslint-enable max-len */
