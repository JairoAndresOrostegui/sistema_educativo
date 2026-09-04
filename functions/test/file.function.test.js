"use strict";

const assert = require("assert");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {getStorage} = require("firebase-admin/storage");
const {seedAcademicYear} = require("./academic_year_fixture");

const projectId = "sistema-educativo-file-test";
const functionsBase = `http://127.0.0.1:5002/${projectId}/us-central1`;
const authBase = "http://127.0.0.1:9098/identitytoolkit.googleapis.com/v1";
let app;
let auth;
let db;
let bucket;

async function clearFirestore() {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  const response = await fetch(
      `http://${host}/emulator/v1/projects/${projectId}/databases/` +
      "(default)/documents",
      {method: "DELETE"},
  );
  assert.ok(response.ok);
}

async function clearAuth() {
  const users = await auth.listUsers(1000);
  if (users.users.length) {
    await auth.deleteUsers(users.users.map((user) => user.uid));
  }
}

async function seedUser(uid, role, permissions = [], extra = {}) {
  const email = `${uid}@colegio.test`;
  await auth.createUser({uid, email, password: "Clave123!"});
  await db.collection("users").doc(uid).set({
    firstName: uid,
    lastName: "Prueba",
    institutionalEmail: email,
    document: `10${uid.length}00000`,
    role,
    status: "activo",
    institution: "inst-1",
    campus: "campus-1",
    permissions,
    isSuperadmin: false,
    ...extra,
  });
  return email;
}

async function signIn(email) {
  const response = await fetch(
      `${authBase}/accounts:signInWithPassword?key=x`,
      {
        method: "POST",
        headers: {"content-type": "application/json"},
        body: JSON.stringify({
          email, password: "Clave123!", returnSecureToken: true,
        }),
      },
  );
  const body = await response.json();
  assert.ok(body.idToken, JSON.stringify(body));
  return body.idToken;
}

async function callFunction(name, data, token) {
  const response = await fetch(`${functionsBase}/${name}`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "authorization": `Bearer ${token}`,
    },
    body: JSON.stringify({data}),
  });
  return {status: response.status, body: await response.json()};
}

function reservation(sizeBytes = 12) {
  return {
    name: "guia.pdf",
    contentType: "application/pdf",
    sizeBytes,
    institutionId: "inst-1",
    campusId: "campus-1",
    audienceType: "groups",
    targetGroupIds: ["group-5a"],
    targetStudentIds: [],
    message: "Revisar antes del viernes",
  };
}

function assertError(response, status) {
  assert.ok(response.body.error, JSON.stringify(response.body));
  assert.equal(response.body.error.status, status);
}

describe("archivos seguros", () => {
  before(() => {
    app = initializeApp({
      projectId,
      storageBucket: `${projectId}.appspot.com`,
    }, "file-function-tests");
    auth = getAuth(app);
    db = getFirestore(app);
    bucket = getStorage(app).bucket();
  });

  beforeEach(async () => {
    await clearFirestore();
    await clearAuth();
    const yearId = await seedAcademicYear(db, "inst-1", "campus-1");
    await db.collection("academic_groups").doc("group-5a").set({
      institutionId: "inst-1", campusId: "campus-1", level: "Quinto",
      academicYearId: yearId, academicYear: 2026,
      section: "A", name: "Quinto A", order: 5, active: true,
    });
    await db.collection("academic_groups").doc("group-6a").set({
      institutionId: "inst-1", campusId: "campus-1", level: "Sexto",
      academicYearId: yearId, academicYear: 2026,
      section: "A", name: "Sexto A", order: 6, active: true,
    });
    await db.collection("subjects").doc("subject-5a").set({
      institutionId: "inst-1", campusId: "campus-1",
      academicYearId: yearId, academicYear: 2026,
      groupId: "group-5a", teacherId: "teacher",
    });
    await seedUser("student-5a", "Estudiante", ["archivos.ver"], {
      groupId: "group-5a", groupName: "Quinto A",
    });
    await seedUser("student-6a", "Estudiante", ["archivos.ver"], {
      groupId: "group-6a", groupName: "Sexto A",
    });
    await seedUser("family-5a", "Familiar", ["archivos.ver"], {
      studentIds: ["student-5a"], activeStudentId: "student-5a",
    });
  });

  after(async () => deleteApp(app));

  it("reserva cuota solo para personal autorizado y su grupo", async () => {
    const token = await signIn(await seedUser(
        "teacher", "Docente", ["archivos.crear", "archivos.ver"],
        {groupId: "group-5a", groupName: "Quinto A"},
    ));
    const result = await callFunction(
        "solicitarCargaArchivo", reservation(), token,
    );
    assert.equal(result.body.result.moduleLimitBytes, 1024 * 1024 * 1024);
    const file = (await db.collection("files")
        .doc(result.body.result.id).get()).data();
    assert.equal(file.status, "uploading");
    assert.deepEqual(file.targetGroupIds, ["group-5a"]);
    assert.deepEqual(file.targetStudentIds, ["student-5a"]);
    assert.ok(file.recipientUserIds.includes("family-5a"));
    assert.ok(file.recipientContextKeys.includes("family-5a:student-5a"));
    assert.equal(file.message, "Revisar antes del viernes");

    const listed = await callFunction(
        "listarArchivos", {}, token,
    );
    assert.equal(listed.body.result.files.length, 0);

    assertError(await callFunction(
        "solicitarCargaArchivo",
        reservation(26 * 1024 * 1024), token,
    ), "INVALID_ARGUMENT");
    assertError(await callFunction(
        "solicitarCargaArchivo",
        {...reservation(), targetGroupIds: ["group-6a"]}, token,
    ), "PERMISSION_DENIED");
  });

  it("confirma, contabiliza y elimina sin huerfanos", async () => {
    const bytes = Buffer.from("guia semanal");
    const teacherToken = await signIn(await seedUser(
        "teacher", "Docente", ["archivos.crear", "archivos.ver"],
        {groupId: "group-5a", groupName: "Quinto A"},
    ));
    const adminToken = await signIn(await seedUser(
        "admin", "Administrador", ["archivos.eliminar", "archivos.ver"],
    ));
    const reserved = await callFunction(
        "solicitarCargaArchivo", reservation(bytes.length), teacherToken,
    );
    const {id, storagePath} = reserved.body.result;
    await bucket.file(storagePath).save(bytes, {
      contentType: "application/pdf",
      metadata: {metadata: {
        fileId: id, uploadedBy: "teacher",
      }},
    });
    const confirmed = await callFunction(
        "confirmarCargaArchivo", {id}, teacherToken,
    );
    assert.equal(confirmed.body.result.sizeBytes, bytes.length);
    assert.equal((await db.collection("files").doc(id).get()).data().status,
        "active");
    const listed = await callFunction("listarArchivos", {}, teacherToken);
    assert.equal(listed.body.result.files.length, 1);
    assert.equal(listed.body.result.files[0].id, id);
    const familyToken = await signIn("family-5a@colegio.test");
    const familyFiles = await callFunction(
        "listarArchivos", {activeStudentId: "student-5a"}, familyToken,
    );
    assert.equal(familyFiles.body.result.files.length, 1);
    assertError(await callFunction(
        "listarArchivos", {activeStudentId: "student-6a"}, familyToken,
    ), "PERMISSION_DENIED");

    const deleted = await callFunction(
        "eliminarArchivos", {ids: [id]}, adminToken,
    );
    assert.equal(deleted.body.result.deleted, 1);
    assert.equal((await db.collection("files").doc(id).get()).exists, false);
    assert.equal((await bucket.file(storagePath).exists())[0], false);
    assert.equal((await db.collection("file_history")
        .where("fileId", "==", id).get()).size, 2);
  });

  it("rechaza el borrado docente aunque manipule el permiso", async () => {
    const token = await signIn(await seedUser(
        "teacher", "Docente", ["archivos.eliminar"],
        {groupId: "group-5a"},
    ));
    assertError(await callFunction(
        "eliminarArchivos", {ids: ["cualquiera"]}, token,
    ), "PERMISSION_DENIED");
  });

  it("solo superadmin limpia archivos de mas de 60 dias", async () => {
    const adminToken = await signIn(await seedUser(
        "admin", "Administrador", ["archivos.eliminar"],
    ));
    const superToken = await signIn(await seedUser(
        "super", "Administrador", [], {isSuperadmin: true},
    ));
    const path = "files/old-file/antiguo.pdf";
    await bucket.file(path).save(Buffer.from("antiguo"), {
      contentType: "application/pdf",
    });
    await db.collection("files").doc("old-file").set({
      name: "antiguo.pdf",
      institutionId: "inst-1",
      campusId: "campus-1",
      audienceType: "groups",
      targetGroupIds: ["group-5a"],
      targetGroupNames: ["Quinto A"],
      targetStudentIds: ["student-5a"],
      recipientUserIds: ["student-5a", "family-5a"],
      storagePath: path,
      sizeBytes: 7,
      status: "active",
      uploadedBy: "teacher",
      createdAt: Timestamp.fromMillis(Date.now() - 61 * 86400000),
    });
    assertError(await callFunction(
        "limpiarArchivosAntiguos", {}, adminToken,
    ), "PERMISSION_DENIED");
    const result = await callFunction(
        "limpiarArchivosAntiguos", {}, superToken,
    );
    assert.equal(result.body.result.deleted, 1);
    assert.equal((await db.collection("files").doc("old-file").get()).exists,
        false);
    assert.equal((await bucket.file(path).exists())[0], false);
  });
});
