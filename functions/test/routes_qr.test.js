"use strict";
/* eslint-disable max-len */
const assert = require("assert");
const crypto = require("crypto");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {routeFunctions} = require("../routes");
const {credentialId} = require("../qr_identity");

describe("Recogida con QR y confirmación", () => {
  let app; let db; let api;
  const scope = {institution: "i", campus: "c", academicYearId: "y", academicYear: 2026};
  const operator = {uid: "operator", ...scope, role: "Docente", status: "activo", permissions: ["rutas.ver"]};
  const payload = `LLQ1:${"a".repeat(43)}`;
  const payload2 = `LLQ1:${"b".repeat(43)}`;
  const call = (name, data, user = operator) => api[name].run({data, user});
  const identification = {method: "qr", payload, credentialRevision: 1, source: "camera", clientPlatform: "android"};
  const pickup = (extra = {}) => call("operarRecorrido", {id: "daily", command: "pickup", requestId: "confirm-1",
    studentId: "student", identification, ...extra});
  before(() => {
    assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
    app = initializeApp({projectId: "sistema-educativo-routes-qr-test"}, "routes-qr");
    db = getFirestore(app);
    api = routeFunctions(db, async (request) => request.user, async () => ({id: "y", year: 2026}));
  });
  after(() => deleteApp(app));
  beforeEach(async () => {
    for (const name of ["users", "academic_years", "daily_routes", "qr_credentials", "qr_audit", "route_history", "route_push_events"]) {
      await db.recursiveDelete(db.collection(name));
    }
    await db.doc("users/operator").set(operator);
    await db.doc("academic_years/y").set({institutionId: "i", campusId: "c", status: "active"});
    await db.doc("daily_routes/daily").set({...scope, estado: "activa", gestionador: "operator", nombreRuta: "Recorrido QA"});
    for (const [id, token] of [["student", payload], ["sibling", payload2]]) {
      await db.doc(`users/${id}`).set({...scope, role: "Estudiante", status: "activo", firstName: id, lastName: "Prueba"});
      await db.doc(`daily_routes/daily/students/${id}`).set({...scope, activo: true, recogido: false, anulado: false, mapEnabled: true, direccion: "Parada compartida"});
      await db.doc(`qr_credentials/${credentialId("user", id)}`).set({targetType: "user", targetId: id,
        institutionId: "i", campusId: "c", payload: token, tokenHash: crypto.createHash("sha256").update(token).digest("hex"), status: "active", revision: 1});
    }
  });
  it("prepara identidad sin marcar recogida, historial ni push", async () => {
    const result = await call("prepararRecogidaQr", {dailyRouteId: "daily", payload});
    assert.equal(result.studentId, "student"); assert.equal(result.identificationOnly, true);
    assert.equal(result.credentialRevision, 1);
    assert.equal((await db.doc("daily_routes/daily/students/student").get()).data().recogido, false);
    assert.equal((await db.collection("route_history").get()).size, 0);
    assert.equal((await db.collection("route_push_events").get()).size, 0);
    assert.equal((await db.collection("qr_audit").get()).size, 1);
  });
  it("confirma por motor compartido, conserva manual y agrupa hermanos sin duplicar", async () => {
    await pickup();
    await pickup();
    assert.equal((await db.collection("route_history").get()).size, 1);
    assert.equal((await db.collection("route_push_events").get()).size, 0);
    await pickup({studentId: "sibling", requestId: "manual-2", identification: undefined});
    const events = await db.collection("route_push_events").get();
    assert.equal(events.size, 1); assert.deepEqual(events.docs[0].data().studentIds.sort(), ["sibling", "student"]);
    const histories = (await db.collection("route_history").get()).docs.map((doc) => doc.data());
    assert.equal(histories.length, 2);
    assert.deepEqual(histories.map((h) => h.inputMethod).sort(), ["manual", "qr"]);
    assert.equal(JSON.stringify(histories).includes(payload), false);
    assert.equal((await db.doc("daily_routes/daily/students/student").get()).data().mapEnabled, false);
    const audits = (await db.collection("qr_audit").get()).docs.map((doc) => doc.data());
    assert.equal(audits.length, 1); assert.equal(audits[0].context, "rutas");
  });
  it("revocar entre lectura y confirmación invalida el intento sin escritura operativa", async () => {
    await call("prepararRecogidaQr", {dailyRouteId: "daily", payload});
    await db.doc(`qr_credentials/${credentialId("user", "student")}`).update({status: "revoked"});
    await assert.rejects(pickup(), (error) => error.code === "permission-denied");
    assert.equal((await db.collection("route_history").get()).size, 0);
    assert.equal((await db.doc("daily_routes/daily/students/student").get()).data().recogido, false);
  });
  it("rechaza estudiante distinto, otro tipo QR y reutilización de requestId", async () => {
    await assert.rejects(pickup({studentId: "sibling"}), (error) => error.code === "permission-denied");
    await db.doc(`qr_credentials/${credentialId("user", "student")}`).update({targetType: "event"});
    await assert.rejects(pickup(), (error) => error.code === "permission-denied");
    await db.doc(`qr_credentials/${credentialId("user", "student")}`).update({targetType: "user"});
    await pickup();
    await assert.rejects(pickup({studentId: "sibling", identification: {...identification, payload: payload2}}),
        (error) => error.code === "already-exists");
    assert.equal((await db.doc("daily_routes/daily/students/sibling").get()).data().recogido, false);
  });
  it("revalida actor, permiso, asignación y año de la sede", async () => {
    for (const change of [{status: "inactivo"}, {permissions: []}, {campus: "other"}, {role: "Familiar"}, {mustChangePassword: true}]) {
      await db.doc("users/operator").set({...operator, ...change});
      await assert.rejects(pickup(), (error) => error.code === "permission-denied");
    }
    await db.doc("users/operator").set(operator);
    await db.doc("daily_routes/daily").update({gestionador: "replacement"});
    await assert.rejects(pickup(), (error) => error.code === "permission-denied");
    await db.doc("daily_routes/daily").update({gestionador: "operator"});
    for (const change of [{status: "closed", campusId: "c"}, {status: "active", campusId: "other"}]) {
      await db.doc("academic_years/y").update(change);
      await assert.rejects(pickup(), (error) => error.code === "failed-precondition");
    }
    assert.equal((await db.collection("route_history").get()).size, 0);
  });
  it("rechaza alumno retirado, fuera de sede o recorrido no activo", async () => {
    for (const change of [{status: "inactivo", campus: "c"}, {status: "activo", campus: "other"}]) {
      await db.doc("users/student").update(change);
      await assert.rejects(pickup(), (error) => error.code === "permission-denied");
    }
    await db.doc("users/student").update({status: "activo", campus: "c"});
    for (const state of ["pendiente", "finalizada", "cancelada"]) {
      await db.doc("daily_routes/daily").update({estado: state});
      await assert.rejects(call("prepararRecogidaQr", {dailyRouteId: "daily", payload}),
          (error) => error.code === "failed-precondition");
      await assert.rejects(pickup(), (error) => error.code === "failed-precondition");
    }
  });
  it("dos confirmaciones concurrentes manual/QR guardan una sola recogida", async () => {
    const results = await Promise.allSettled([pickup(), pickup({identification: undefined, requestId: "manual-race"})]);
    assert.equal(results.filter((result) => result.status === "fulfilled").length, 1);
    assert.equal((await db.collection("route_history").get()).size, 1);
    assert.equal((await db.doc("daily_routes/daily/students/student").get()).data().recogido, true);
  });
  it("auxiliar asignado con permiso opera sin permisos QR administrativos", async () => {
    const auxiliary = {...operator, role: "Auxiliar"};
    await db.doc("users/operator").set(auxiliary);
    const result = await call("prepararRecogidaQr", {dailyRouteId: "daily", payload}, auxiliary);
    assert.equal(result.studentId, "student");
    await call("operarRecorrido", {id: "daily", command: "pickup", requestId: "auxiliary-1", studentId: "student", identification}, auxiliary);
    assert.equal((await db.doc("daily_routes/daily/students/student").get()).data().recogido, true);
  });
});
