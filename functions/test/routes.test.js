"use strict";
/* eslint-disable max-len */
const assert = require("assert");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {routeFunctions} = require("../routes");
describe("Recorridos seguros", () => {
  let app; let db; let api;
  const scope = {institution: "i", campus: "c", academicYearId: "y", academicYear: 2026};
  const teacher = {...scope, uid: "t", role: "Docente", permissions: ["rutas.ver"]};
  const admin = {...scope, uid: "a", role: "Administrador", permissions: ["rutas.ver", "rutas.editar", "rutas.crear", "rutas.eliminar"]};
  const call = (name, data, user = teacher) => api[name].run({data, auth: {uid: user.uid}, user});
  let sequence = 0;
  const op = (command, data = {}, user = teacher) => call("operarRecorrido", {id: "r_today", command, requestId: `request-${sequence++}`, ...data}, user);
  before(() => {
    assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
    app = initializeApp({projectId: "sistema-educativo-routes-test"}, "routes"); db = getFirestore(app);
    api = routeFunctions(db, async (r) => r.user, async () => ({id: "y", year: 2026}));
  });
  after(() => deleteApp(app));
  beforeEach(async () => {
    for (const name of ["routes", "daily_routes", "route_history", "route_push_events", "users"]) await db.recursiveDelete(db.collection(name));
    await db.doc("academic_years/y").set({...scope, status: "active"});
    await db.doc("routes/r").set({...scope, gestionador: "t", estudiantes: ["s1", "s2"], nombre: "Ruta"});
    await db.doc("daily_routes/r_today").set({...scope, idRuta: "r", gestionador: "t", estado: "pendiente", fecha: Timestamp.now()});
    for (const id of ["s1", "s2"]) {
      await db.doc(`users/${id}`).set({...scope, role: "Estudiante", status: "activo", routeAddress: "Misma dirección"});
      await db.doc(`daily_routes/r_today/students/${id}`).set({...scope, id, nombre: id, direccion: "Misma dirección", activo: true, recogido: false, anulado: false});
    }
  });
  it("bloquea responsable ajeno y direccion despues de iniciar", async () => {
    await assert.rejects(op("start", {}, {...teacher, uid: "other"}));
    await op("start");
    await assert.rejects(op("address", {studentId: "s1", address: "Otra"}));
    assert.equal((await db.doc("daily_routes/r_today").get()).data().estado, "activa");
  });
  it("dos hermanos generan un solo evento al completar parada y no duplica operacion", async () => {
    await op("start");
    await op("pickup", {studentId: "s1", requestId: "one"});
    assert.equal((await db.collection("route_push_events").get()).size, 1);
    await op("pickup", {studentId: "s2", requestId: "two"});
    await op("pickup", {studentId: "s2", requestId: "two"});
    const events = await db.collection("route_push_events").get();
    assert.equal(events.size, 2);
    assert.equal(events.docs.find((d) => d.data().title === "Recogida actualizada").data().studentIds.length, 2);
    await op("finish");
    await assert.rejects(op("pickup", {studentId: "s1"}));
    assert.equal((await db.collection("route_history").get()).size, 4);
  });
  it("impide cierre con pendientes y elimina solo rutas sin recorridos", async () => {
    await op("start"); await assert.rejects(op("finish"));
    await assert.rejects(call("eliminarRutaSegura", {id: "r"}, admin));
    assert.equal((await db.doc("routes/r").get()).exists, true);
  });
  it("ano cerrado no admite operacion", async () => {
    await db.doc("academic_years/y").update({status: "closed"});
    await assert.rejects(op("start"));
  });
  it("consultas e historial requieren permiso de rutas", async () => {
    const student = {...scope, uid: "s1", role: "Estudiante", permissions: []};
    await assert.rejects(call("consultarMiRecorrido", {}, student), (e) => e.code === "permission-denied");
    await assert.rejects(call("consultarHistorialRuta", {}, student), (e) => e.code === "permission-denied");
    await assert.rejects(call("consultarHistorialRuta", {}, {...teacher, permissions: []}), (e) => e.code === "permission-denied");
  });
  it("familiar solicita, admin aprueba antes de inicio; despues no cambia", async () => {
    const family = {...scope, uid: "f", role: "Familiar", permissions: ["rutas.ver"], studentIds: ["s1"], activeStudentId: "s1"};
    await call("solicitarCambioParada", {dailyRouteId: "r_today", studentId: "s1", address: "Otra parada", reason: "Solo hoy"}, family);
    await assert.rejects(call("solicitarCambioParada", {dailyRouteId: "r_today", studentId: "s2", address: "Otra", reason: "No es hijo"}, family));
    await call("gestionarCambiosParada", {action: "decide", dailyRouteId: "r_today", studentId: "s1", approved: true, reason: "Aprobado"}, admin);
    assert.equal((await db.doc("daily_routes/r_today/students/s1").get()).data().direccion, "Otra parada");
    await op("start");
    await assert.rejects(call("solicitarCambioParada", {dailyRouteId: "r_today", studentId: "s1", address: "Cambio tardio", reason: "No permitido"}, family));
  });
  it("conductor no crea cuenta; registro limitado a admin de sede", async () => {
    const data = {action: "save", name: "Conductor", document: "123", phone: "300", license: "C2"};
    await assert.rejects(call("gestionarConductores", data));
    const result = await call("gestionarConductores", data, admin);
    assert.equal(result.items.length, 1);
    assert.equal((await db.collection("users").get()).size, 2);
    assert.equal((await call("gestionarConductores", {}, {...admin, campus: "otra"})).items.length, 0);
  });
  it("automatico no consume APIs mientras no este habilitado", async () => {
    await op("start");
    await assert.rejects(call("calcularTiemposRuta", {id: "r_today"}), (e) => e.code === "failed-precondition");
  });
});
