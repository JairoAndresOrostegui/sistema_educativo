"use strict";
/* eslint-disable max-len */
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const {initializeTestEnvironment, assertSucceeds, assertFails} = require("@firebase/rules-unit-testing");
const {doc, setDoc, getDoc, updateDoc, deleteDoc} = require("firebase/firestore");
describe("Regresiones de seguridad Rutas y slots push", () => {
  let env;
  const scope = {institution: "i", campus: "c", academicYearId: "y"};
  const user = (role, extra = {}) => ({...scope, role, status: "activo", isSuperadmin: false, permissions: ["rutas.ver"], ...extra});
  const dbFor = (uid) => env.authenticatedContext(uid, {email_verified: true}).firestore();
  before(async () => {
    assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
    const port = Number(process.env.FIRESTORE_EMULATOR_HOST.split(":").at(-1));
    env = await initializeTestEnvironment({projectId: "sistema-educativo-route-audit-test", firestore: {host: "127.0.0.1", port,
      rules: fs.readFileSync(path.resolve(__dirname, "../../firestore.rules"), "utf8")}});
  });
  after(() => env.cleanup());
  beforeEach(async () => {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (c) => {
      const fixtures = {
        "users/admin": user("Administrador"), "users/other": user("Administrador", {campus: "other"}),
        "users/super": user("Administrador", {isSuperadmin: true}), "users/teacher": user("Docente"),
        "users/student": user("Estudiante"), "users/stranger": user("Estudiante"),
        "users/family": user("Familiar", {studentIds: ["student"], activeStudentId: "student"}),
        "academic_years/y": {institutionId: "i", campusId: "c", status: "closed"},
        "routes/r": {...scope, gestionador: "someone-else", estudiantes: ["stranger"]},
        "daily_routes/d": {...scope, gestionador: "teacher", idRuta: "r", estado: "finalizada"},
        "daily_routes/d/students/stranger": {...scope, direccion: "Ficticia", recogido: false},
        "daily_routes/d/students/student": {...scope, direccion: "Propia", recogido: false},
      };
      for (const [id, data] of Object.entries(fixtures)) await setDoc(doc(c.firestore(), id), data);
    });
  });
  it("aisla sede y admite superadmin", async () => {
    await assertFails(getDoc(doc(dbFor("other"), "routes/r")));
    await assertSucceeds(getDoc(doc(dbFor("super"), "routes/r")));
  });
  it("familiar/estudiante leen solo parada propia incluso en historia", async () => {
    for (const uid of ["family", "student"]) {
      await assertFails(getDoc(doc(dbFor(uid), "daily_routes/d/students/stranger")));
      await assertSucceeds(getDoc(doc(dbFor(uid), "daily_routes/d/students/student")));
    }
  });
  it("ningun cliente crea/modifica/elimina recorridos ni rutas", async () => {
    for (const uid of ["admin", "super", "teacher"]) {
      await assertFails(setDoc(doc(dbFor(uid), "daily_routes/new"), {...scope, gestionador: uid}));
      await assertFails(updateDoc(doc(dbFor(uid), "daily_routes/d/students/stranger"), {recogido: true}));
      await assertFails(deleteDoc(doc(dbFor(uid), "routes/r")));
    }
  });
  it("no permite escribir tokens ni sesiones desde cliente", async () => {
    await assertFails(updateDoc(doc(dbFor("student"), "users/student"), {"notificationTokens.mobile": "forged"}));
    await assertFails(setDoc(doc(dbFor("student"), "push_device_sessions/student"), {mobile: {}}));
  });
  it("GPS exige ventana del hijo activo y se revoca al recoger", async () => {
    const patch = async (values) => env.withSecurityRulesDisabled(async (c) => {
      await updateDoc(doc(c.firestore(), "academic_years/y"), {status: "active"});
      await updateDoc(doc(c.firestore(), "daily_routes/d"), {estado: "activa"});
      await setDoc(doc(c.firestore(), "daily_routes/d/live/location"), {teacherPosition: "privada"});
      await updateDoc(doc(c.firestore(), "daily_routes/d/students/student"), {activo: true, anulado: false, ...values});
    });
    await patch({mapEnabled: false});
    await assertFails(getDoc(doc(dbFor("family"), "daily_routes/d/live/location")));
    await patch({mapEnabled: true});
    for (const uid of ["family", "student", "teacher", "admin"]) await assertSucceeds(getDoc(doc(dbFor(uid), "daily_routes/d/live/location")));
    await assertFails(getDoc(doc(dbFor("stranger"), "daily_routes/d/live/location")));
    await patch({recogido: true});
    await assertFails(getDoc(doc(dbFor("family"), "daily_routes/d/live/location")));
    await assertSucceeds(getDoc(doc(dbFor("family"), "daily_routes/d/students/student")));
  });
  it("cerrar el año revoca GPS aunque el recorrido antiguo siga activo", async () => {
    await env.withSecurityRulesDisabled(async (c) => {
      await updateDoc(doc(c.firestore(), "academic_years/y"), {status: "active"});
      await updateDoc(doc(c.firestore(), "daily_routes/d"), {estado: "activa"});
      await setDoc(doc(c.firestore(), "daily_routes/d/live/location"), {teacherPosition: "privada"});
      await updateDoc(doc(c.firestore(), "daily_routes/d/students/student"), {
        activo: true, anulado: false, recogido: false, mapEnabled: true,
      });
    });
    const viewers = ["family", "student", "teacher", "admin", "super"];
    for (const uid of viewers) await assertSucceeds(getDoc(doc(dbFor(uid), "daily_routes/d/live/location")));
    await env.withSecurityRulesDisabled(async (c) => {
      await updateDoc(doc(c.firestore(), "academic_years/y"), {status: "closed"});
    });
    for (const uid of viewers) await assertFails(getDoc(doc(dbFor(uid), "daily_routes/d/live/location")));
    await assertSucceeds(getDoc(doc(dbFor("family"), "daily_routes/d/students/student")));
  });
});
