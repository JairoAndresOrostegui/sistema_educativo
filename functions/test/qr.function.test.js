"use strict";
/* eslint-disable max-len */
const assert = require("assert");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");
const {seedAcademicYear} = require("./academic_year_fixture");
const {credentialId} = require("../qr_identity");
const projectId = "sistema-educativo-qr-test";
let app; let db; let auth;
const tokens = {};
async function call(name, data, uid) {
  const response = await fetch(`http://127.0.0.1:5002/${projectId}/us-central1/${name}`, {
    method: "POST", headers: {"content-type": "application/json", "authorization": `Bearer ${tokens[uid]}`},
    body: JSON.stringify({data}),
  });
  return response.json();
}
async function seed(uid, role, extra = {}) {
  await auth.createUser({uid, email: `${uid}@colegio.test`, password: "Clave123!", emailVerified: true});
  await db.collection("users").doc(uid).set({role, status: "activo",
    firstName: uid, lastName: "Prueba", institution: "i", campus: "c",
    permissions: [], studentIds: [], ...extra});
  const response = await fetch("http://127.0.0.1:9098/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=x", {
    method: "POST", headers: {"content-type": "application/json"},
    body: JSON.stringify({email: `${uid}@colegio.test`, password: "Clave123!", returnSecureToken: true}),
  });
  tokens[uid] = (await response.json()).idToken;
}
describe("identificadores QR", () => {
  before(() => {
    app = initializeApp({projectId}); db = getFirestore(app); auth = getAuth(app);
  });
  after(() => deleteApp(app));
  beforeEach(async () => {
    await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${projectId}/databases/(default)/documents`, {method: "DELETE"});
    const users = await auth.listUsers(1000);
    if (users.users.length) await auth.deleteUsers(users.users.map((u) => u.uid));
    await seedAcademicYear(db, "i", "c");
    await seed("student", "Estudiante");
    await seed("other", "Estudiante");
    await seed("family", "Familiar", {studentIds: ["student"], activeStudentId: "student"});
    await seed("teacher", "Docente");
    await seed("admin", "Administrador", {permissions: ["codigoqr.crear", "codigoqr.editar"]});
    await seed("super", "Administrador", {isSuperadmin: true});
  });
  it("emite un QR opaco estable por usuario y rechaza el JSON antiguo", async () => {
    for (const uid of ["student", "family", "teacher", "admin"]) {
      const first = await call("obtenerCredencialQr", {}, uid);
      assert.match(first.result.payload, /^LLQ1:[A-Za-z0-9_-]{43}$/);
      assert.equal((await call("obtenerCredencialQr", {}, uid)).result.payload, first.result.payload);
      assert.equal((await call("resolverCredencialQr", {payload: first.result.payload}, uid)).result.targetId, uid);
    }
    assert.equal((await call("resolverCredencialQr", {payload: "{\"uid\":\"student\"}"}, "admin")).error.status, "PERMISSION_DENIED");
    assert.equal((await call("obtenerCredencialQr", {targetId: "other"}, "student")).error.status, "PERMISSION_DENIED");
  });
  it("consulta hijos vigentes sin conceder autorizacion de recogida", async () => {
    const qr = (await call("obtenerCredencialQr", {}, "family")).result.payload;
    const resolved = (await call("resolverCredencialQr", {
      payload: qr, source: "camera", clientPlatform: "android",
    }, "admin")).result;
    assert.equal(resolved.children[0].id, "student");
    assert.equal(resolved.identificationOnly, true);
    const audit = await db.collection("qr_audit")
        .where("action", "==", "resolved").get();
    const resolution = audit.docs.map((doc) => doc.data())
        .find((entry) => entry.targetId === "family");
    assert.equal(resolution.result, "success");
    assert.equal(resolution.source, "camera");
    assert.equal(resolution.clientPlatform, "android");
    assert.ok((await call("obtenerCredencialQr", {targetId: "student"}, "family")).result);
    assert.equal((await call("obtenerCredencialQr", {targetId: "other"}, "family")).error.status, "PERMISSION_DENIED");
    await db.collection("users").doc("student").update({status: "inactivo"});
    assert.deepEqual((await call("resolverCredencialQr", {payload: qr}, "admin")).result.children, []);
  });
  it("revoca, reemplaza, aisla sedes y elimina la credencial en cascada", async () => {
    const original = (await call("obtenerCredencialQr", {}, "student")).result;
    const qr = original.payload;
    const rotated = await call("administrarCredencialQr", {targetType: "user", targetId: "student", action: "rotate", confirmation: "rotate:student", expectedRevision: original.revision}, "admin");
    assert.equal(rotated.result.revision, 2);
    assert.equal((await call("administrarCredencialQr", {targetType: "user", targetId: "student", action: "rotate", confirmation: "rotate:student", expectedRevision: original.revision}, "admin")).error.status, "ABORTED");
    assert.equal((await call("resolverCredencialQr", {payload: qr}, "admin")).error.status, "PERMISSION_DENIED");
    const revoked = await call("administrarCredencialQr", {targetType: "user", targetId: "student", action: "revoke", confirmation: "revoke:student", expectedRevision: rotated.result.revision}, "admin");
    assert.equal(revoked.result.revision, 3);
    assert.equal((await call("obtenerCredencialQr", {}, "student")).error.status, "PERMISSION_DENIED");
    const adminView = (await call("obtenerCredencialQr", {targetId: "student"}, "admin")).result;
    assert.equal(adminView.payload, null);
    assert.equal(adminView.status, "revoked");
    assert.equal(adminView.revision, 3);
    await db.collection("users").doc("other").update({campus: "other-campus"});
    assert.equal((await call("obtenerCredencialQr", {targetId: "other"}, "admin")).error.status, "PERMISSION_DENIED");
    assert.ok((await call("obtenerCredencialQr", {targetId: "other"}, "super")).result);
    const deletion = await call("eliminarUsuarioAuth", {uid: "student", mode: "permanent", confirmation: "ELIMINAR student"}, "super");
    assert.ok(deletion.result, JSON.stringify(deletion));
    assert.equal((await db.collection("qr_credentials").doc(credentialId("user", "student")).get()).exists, false);
  });
  it("identifica eventos sin registrar asistencia y respeta el año", async () => {
    const denied = await call("crearIdentificadorEventoQr", {title: "Reunion"}, "student");
    assert.equal(denied.error.status, "PERMISSION_DENIED");
    const event = (await call("crearIdentificadorEventoQr", {title: "Reunion"}, "admin")).result;
    assert.ok(event);
    const read = (await call("resolverCredencialQr", {payload: event.payload}, "student")).result;
    assert.equal(read.targetType, "event"); assert.equal(read.identificationOnly, true);
    const source = (await db.collection("events").doc(event.targetId).get()).data();
    await db.collection("academic_years").doc(source.academicYearId).update({campusId: "otra"});
    assert.equal((await call("resolverCredencialQr", {payload: event.payload}, "student")).error.status, "PERMISSION_DENIED");
    await db.collection("academic_years").doc(source.academicYearId).update({campusId: "c"});
    await db.collection("academic_years").doc(source.academicYearId).update({status: "closed"});
    assert.equal((await call("resolverCredencialQr", {payload: event.payload}, "student")).error.status, "PERMISSION_DENIED");
  });
});
