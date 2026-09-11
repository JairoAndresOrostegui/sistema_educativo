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
    await assert.rejects(op("start", {}, admin),
        (e) => e.code === "permission-denied");
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
  it("audita la creacion de rutas con nombre y estado", async () => {
    await db.doc("users/t").set({...teacher, status: "activo"});
    await db.doc("routes/r").delete();
    const now = Date.now();
    const result = await call("guardarRutaSegura", {
      nombre: "Ruta nueva", direccionInicio: "Colegio", gestionador: "t",
      estudiantes: ["s1", "s2"], institution: "i", campus: "c",
      fechaInicio: now, fechaFin: now + 86400000,
      horaInicio: now, horaFin: now + 3600000,
    }, admin);
    const history = await db.collection("route_history")
        .where("routeId", "==", result.id).get();
    assert.equal(history.size, 1);
    assert.equal(history.docs[0].data().action, "route_created");
    assert.equal(history.docs[0].data().routeName, "Ruta nueva");
    assert.equal(history.docs[0].data().before, null);
    assert.equal(history.docs[0].data().after.nombre, "Ruta nueva");
  });
  it("impide estudiantes duplicados y ediciones con revision vencida",
      async () => {
        await db.doc("users/t").set({...teacher, status: "activo"});
        const now = Date.now();
        const payload = {
          id: "r", nombre: "Ruta editada", direccionInicio: "Colegio",
          gestionador: "t", estudiantes: ["s1", "s2"],
          institution: "i", campus: "c", fechaInicio: now,
          fechaFin: now + 86400000, horaInicio: now,
          horaFin: now + 3600000, expectedRevision: 0,
        };
        await call("guardarRutaSegura", payload, admin);
        await assert.rejects(call("guardarRutaSegura", payload, admin),
            (e) => e.code === "aborted");
        await assert.rejects(call("guardarRutaSegura", {
          ...payload, id: undefined, expectedRevision: undefined,
          nombre: "Ruta duplicada",
        }, admin), (e) => e.code === "already-exists");
      });
  it("valida fechas y conserva como baja logica una ruta sin recorridos",
      async () => {
        await db.doc("users/t").set({...teacher, status: "activo"});
        await db.doc("routes/r").delete();
        await db.doc("daily_routes/r_today").delete();
        const now = Date.now();
        const payload = {
          nombre: "Ruta temporal", direccionInicio: "Colegio",
          gestionador: "t", estudiantes: ["s1", "s2"],
          institution: "i", campus: "c", fechaInicio: now,
          fechaFin: now + 86400000, horaInicio: now,
          horaFin: now + 3600000,
        };
        await assert.rejects(call("guardarRutaSegura", {
          ...payload, fechaInicio: now + 86400000, fechaFin: now,
        }, admin), (e) => e.code === "invalid-argument");
        const created = await call("guardarRutaSegura", payload, admin);
        await call("eliminarRutaSegura", {id: created.id}, admin);
        const removed = (await db.doc(`routes/${created.id}`).get()).data();
        assert.equal(removed.status, "deleted");
        assert.equal(removed.revision, 2);
      });
  it("ano cerrado no admite operacion", async () => {
    await db.doc("academic_years/y").update({status: "closed"});
    await assert.rejects(op("start"));
  });
  it("solo prepara rutas vigentes con todos sus estudiantes activos", async () => {
    const now = Date.now();
    await db.doc("routes/r").update({
      fechaInicio: Timestamp.fromMillis(now + 86400000),
      fechaFin: Timestamp.fromMillis(now + (2 * 86400000)),
    });
    await assert.rejects(call("prepararRecorrido", {routeId: "r"}),
        (e) => e.code === "failed-precondition");

    await db.doc("routes/r").update({
      fechaInicio: Timestamp.fromMillis(now - 86400000),
      fechaFin: Timestamp.fromMillis(now + 86400000),
    });
    await db.doc("users/s2").update({status: "inactivo"});
    await assert.rejects(call("prepararRecorrido", {routeId: "r"}),
        (e) => e.code === "failed-precondition");

    await db.doc("users/s2").update({status: "activo"});
    const result = await call("prepararRecorrido", {routeId: "r"});
    assert.ok(result.id.startsWith("r_"));
    assert.equal((await db.doc(`daily_routes/${result.id}/students/s1`).get())
        .exists, true);
    assert.equal((await db.doc(`daily_routes/${result.id}/students/s2`).get())
        .exists, true);
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
    assert.equal(result.items[0].revision, 1);
    await assert.rejects(call("gestionarConductores", data, admin),
        (e) => e.code === "already-exists");
    await call("gestionarConductores", {
      ...data, id: result.items[0].id, expectedRevision: 1, active: false,
    }, admin);
    await assert.rejects(call("gestionarConductores", {
      ...data, id: result.items[0].id, expectedRevision: 1,
    }, admin), (e) => e.code === "aborted");
    assert.equal((await db.collection("users").get()).size, 2);
    assert.equal((await call("gestionarConductores", {}, {...admin, campus: "otra"})).items.length, 0);
  });
  it("entrega participantes y direcciones solo al administrador autorizado", async () => {
    await db.doc("users/t").set({...teacher, status: "activo", firstName: "Docente", lastName: "Ruta"});
    await db.doc("users/foreign").set({...scope, institution: "otra", role: "Estudiante", status: "activo", routeAddress: "Privada"});
    const result = await call("listarParticipantesRuta", {institution: "i", campus: "c"}, admin);
    assert.deepEqual(result.students.map((item) => item.id).sort(), ["s1", "s2"]);
    assert.equal(result.students[0].routeAddress, "Misma dirección");
    assert.deepEqual(result.managers.map((item) => item.id), ["t"]);
    await assert.rejects(call("listarParticipantesRuta", {}, teacher), (e) => e.code === "permission-denied");
    await assert.rejects(call("listarParticipantesRuta", {}, {...admin, permissions: ["rutas.ver"]}), (e) => e.code === "permission-denied");
  });
  it("automatico no consume APIs mientras no este habilitado", async () => {
    await op("start");
    await assert.rejects(call("calcularTiemposRuta", {id: "r_today"}), (e) => e.code === "failed-precondition");
  });
  it("sin asignacion responde vacio y conserva estados antes y despues", async () => {
    await db.doc("users/s3").set({...scope, role: "Estudiante", status: "activo"});
    const unassigned = {...scope, uid: "s3", role: "Estudiante", permissions: ["rutas.ver"]};
    const empty = await call("consultarMiRecorrido", {}, unassigned);
    assert.equal(empty.id, null);
    const today = new Intl.DateTimeFormat("en-CA", {timeZone: "America/Bogota"}).format(new Date());
    const todayRef = db.doc(`daily_routes/r_${today}`);
    await todayRef.set({...scope, idRuta: "r", gestionador: "t", estado: "pendiente", fecha: Timestamp.now()});
    await todayRef.collection("students").doc("s1").set({...scope, activo: true, recogido: false, anulado: false});
    const assigned = {...scope, uid: "s1", role: "Estudiante", permissions: ["rutas.ver"]};
    assert.equal((await call("consultarMiRecorrido", {}, assigned)).id, `r_${today}`);
    await todayRef.update({estado: "finalizada"});
    assert.equal((await call("consultarMiRecorrido", {}, assigned)).id, `r_${today}`);
  });
  it("rechaza datos incompletos y estados desconocidos sin error interno", async () => {
    await db.doc("daily_routes/r_today/students/s1").update({direccion: null});
    await assert.rejects(op("start"), (e) => e.code === "failed-precondition");
    await db.doc("daily_routes/r_today").update({estado: "corrupta"});
    await assert.rejects(op("start"), (e) => e.code === "failed-precondition");
  });
  it("finalizar elimina GPS y toda operacion posterior queda controlada", async () => {
    await op("start");
    await op("position", {latitude: 7, longitude: -73});
    await op("pickup", {studentId: "s1"});
    await op("absent", {studentId: "s2", reason: "No se presentó"});
    await op("finish");
    assert.equal((await db.doc("daily_routes/r_today/live/location").get()).exists, false);
    await assert.rejects(op("position", {latitude: 7, longitude: -73}),
        (e) => e.code === "failed-precondition");
  });
  it("abre todas las paradas proximas y no duplica avisos con GPS", async () => {
    await op("start");
    for (const id of ["s1", "s2"]) {
      await db.doc(`daily_routes/r_today/students/${id}`).update({
        direccion: id, estimatedArrivalAt: Timestamp.fromMillis(Date.now() + 9 * 60000),
      });
    }
    await op("position", {latitude: 7, longitude: -73});
    await op("position", {latitude: 7.01, longitude: -73});
    for (const id of ["s1", "s2"]) assert.equal((await db.doc(`daily_routes/r_today/students/${id}`).get()).data().mapEnabled, true);
    assert.equal((await db.collection("route_push_events").get()).size, 3);
    assert.equal((await db.doc("daily_routes/r_today").get()).data().teacherPosition, undefined);
    assert.ok((await db.doc("daily_routes/r_today/live/location").get()).data().teacherPosition);
  });
  it("ventana manual se conserva con demora y cierra al recoger; anuncios siguen", async () => {
    await op("start");
    await op("eta", {studentId: "s1", minutes: 20});
    await op("position", {latitude: 7, longitude: -73});
    assert.notEqual((await db.doc("daily_routes/r_today/students/s1").get()).data().mapEnabled, true);
    await op("eta", {studentId: "s1", minutes: 8});
    await op("eta", {studentId: "s1", minutes: 25});
    assert.equal((await db.doc("daily_routes/r_today/students/s1").get()).data().mapEnabled, true);
    await op("pickup", {studentId: "s1"});
    assert.equal((await db.doc("daily_routes/r_today/students/s1").get()).data().mapEnabled, false);
    await op("announcement", {reason: "Demora por tráfico"});
    const events = (await db.collection("route_push_events").get()).docs.map((d) => d.data());
    assert.deepEqual(events.find((e) => e.title === "Novedad del recorrido").studentIds.sort(), ["s1", "s2"]);
    await assert.rejects(op("announcement", {reason: "Ajeno"}, {...teacher, uid: "otro"}));
  });
});
