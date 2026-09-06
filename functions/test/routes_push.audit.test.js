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
  const dbFor = (uid) => env.authenticatedContext(uid).firestore();
  before(async () => {
    assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
    env = await initializeTestEnvironment({projectId: "sistema-educativo-route-audit-test", firestore: {host: "127.0.0.1", port: 8180,
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
        "academic_years/y": {...scope, status: "closed"},
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
});
