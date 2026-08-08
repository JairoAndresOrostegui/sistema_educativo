"use strict";

const assert = require("assert");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");

const projectId = "sistema-educativo-enrollment-test";
const functionsBase = `http://127.0.0.1:5002/${projectId}/us-central1`;
const authBase = "http://127.0.0.1:9098/identitytoolkit.googleapis.com/v1";
let app;
let auth;
let db;

const profile = (role, extra = {}) => ({
  firstName: "Usuario",
  lastName: "Prueba",
  document: "10000000",
  institutionalEmail: `${role.toLowerCase()}@colegio.test`,
  role,
  status: "activo",
  institution: "inst-1",
  campus: "campus-1",
  groupId: role === "Docente" || role === "Estudiante" ? "group-5a" : null,
  groupName: role === "Docente" || role === "Estudiante" ? "Quinto A" : null,
  permissions: [],
  studentIds: [],
  isSuperadmin: false,
  ...extra,
});

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

async function seedUser(uid, role, extra = {}) {
  const email = `${uid}@colegio.test`;
  await auth.createUser({uid, email, password: "Clave123!"});
  await db.collection("users").doc(uid).set(profile(role, {
    institutionalEmail: email,
    ...extra,
  }));
  return email;
}

async function signIn(email) {
  const response = await fetch(
      `${authBase}/accounts:signInWithPassword?key=x`,
      {
        method: "POST",
        headers: {"content-type": "application/json"},
        body: JSON.stringify({
          email,
          password: "Clave123!",
          returnSecureToken: true,
        }),
      },
  );
  const body = await response.json();
  assert.ok(body.idToken, JSON.stringify(body));
  return body.idToken;
}

async function callFunction(name, data, token) {
  const headers = {"content-type": "application/json"};
  if (token) headers.authorization = `Bearer ${token}`;
  const response = await fetch(`${functionsBase}/${name}`, {
    method: "POST",
    headers,
    body: JSON.stringify({data}),
  });
  return {status: response.status, body: await response.json()};
}

function enrollmentData(document = "12345678", groupId = "group-5a") {
  return {
    numeroIdentidad: document,
    groupId,
    nombresApellidosAlumno: "Estudiante Prueba",
  };
}

function createPayload(extra = {}) {
  return {
    data: enrollmentData(),
    institution: "inst-1",
    campus: "campus-1",
    anioMatricula: 2026,
    ...extra,
  };
}

function assertError(response, expectedStatus) {
  assert.ok(response.body.error, JSON.stringify(response.body));
  assert.equal(response.body.error.status, expectedStatus);
}

describe("matriculas seguras", () => {
  before(() => {
    app = initializeApp({projectId}, "enrollment-function-tests");
    auth = getAuth(app);
    db = getFirestore(app);
  });

  beforeEach(async () => {
    await clearFirestore();
    await clearAuth();
    await db.collection("configuracion_colegios").doc("inst-1").set({
      institutionId: "inst-1",
      nombre: "Colegio de prueba",
      sedes: ["campus-1", "campus-2"],
    });
    await db.collection("academic_groups").doc("group-5a").set({
      institutionId: "inst-1", campusId: "campus-1", level: "Quinto",
      section: "A", name: "Quinto A", order: 5, active: true,
    });
    await db.collection("academic_groups").doc("group-6a").set({
      institutionId: "inst-1", campusId: "campus-1", level: "Sexto",
      section: "A", name: "Sexto A", order: 6, active: true,
    });
    await db.collection("academic_groups").doc("group-5a-campus-2").set({
      institutionId: "inst-1", campusId: "campus-2", level: "Quinto",
      section: "A", name: "Quinto A", order: 5, active: true,
    });
  });

  after(async () => deleteApp(app));

  it("fuerza la solicitud publica y deja auditoria", async () => {
    const response = await callFunction(
        "crearMatricula",
        createPayload({matricularAhora: true}),
    );
    assert.equal(response.body.result.estado, "prematriculado");
    const id = response.body.result.id;
    const saved = (await db.collection("enrollments").doc(id).get()).data();
    assert.equal(saved.createdByRole, "publico");
    assert.equal(saved.createdByUserId, null);
    assert.equal((await db.collection("enrollment_history").get()).size, 1);
    assert.equal(
        (await db.collection("enrollment_notification_events").get()).size,
        1,
    );
  });

  it("impide documento y ano duplicados concurrentes", async () => {
    const payload = createPayload();
    const [first, second] = await Promise.all([
      callFunction("crearMatricula", payload),
      callFunction("crearMatricula", payload),
    ]);
    const results = [first, second];
    assert.equal(results.filter((item) => item.body.result).length, 1);
    assert.equal(results.filter((item) => item.body.error).length, 1);
    assert.equal((await db.collection("enrollments").get()).size, 1);
  });

  it("limita solicitudes publicas repetidas", async () => {
    for (let index = 0; index < 5; index += 1) {
      const response = await callFunction("crearMatricula", createPayload({
        data: enrollmentData(`1234567${index}`),
      }));
      assert.ok(response.body.result, JSON.stringify(response.body));
    }
    const blocked = await callFunction("crearMatricula", createPayload({
      data: enrollmentData("12345699"),
    }));
    assertError(blocked, "RESOURCE_EXHAUSTED");
  });

  it("rechaza estudiantes y familiares sin vinculo", async () => {
    const studentToken = await signIn(
        await seedUser("student-login", "Estudiante"),
    );
    const deniedStudent = await callFunction(
        "crearMatricula", createPayload(), studentToken,
    );
    assertError(deniedStudent, "PERMISSION_DENIED");

    const familyToken = await signIn(
        await seedUser("family", "Familiar"),
    );
    const deniedFamily = await callFunction(
        "crearMatricula",
        createPayload({vinculaUsuarioId: "student-login"}),
        familyToken,
    );
    assertError(deniedFamily, "PERMISSION_DENIED");
  });

  it("permite al familiar solo su estudiante vinculado", async () => {
    await seedUser("student", "Estudiante");
    const familyToken = await signIn(await seedUser("family", "Familiar", {
      studentIds: ["student"],
    }));
    const response = await callFunction(
        "crearMatricula",
        createPayload({vinculaUsuarioId: "student"}),
        familyToken,
    );
    assert.equal(response.body.result.estado, "prematriculado");
    const saved = (await db.collection("enrollments")
        .doc(response.body.result.id).get()).data();
    assert.equal(saved.createdByUserId, "family");
    assert.equal(saved.vinculaUsuarioId, "student");
  });

  it("limita admin a su sede y permite cruce al superadmin", async () => {
    const adminToken = await signIn(await seedUser("admin", "Administrador", {
      permissions: ["matricula.editar"],
    }));
    const foreign = await callFunction(
        "crearMatricula",
        createPayload({campus: "campus-2"}),
        adminToken,
    );
    assertError(foreign, "PERMISSION_DENIED");

    const superToken = await signIn(await seedUser("super", "Administrador", {
      isSuperadmin: true,
      campus: "campus-1",
    }));
    const allowed = await callFunction(
        "crearMatricula",
        createPayload({
          campus: "campus-2",
          data: enrollmentData("87654321", "group-5a-campus-2"),
        }),
        superToken,
    );
    assert.equal(allowed.body.result.estado, "pendiente_revision");
  });

  it("reserva las decisiones finales al administrador", async () => {
    await seedUser("student", "Estudiante");
    const adminToken = await signIn(await seedUser("admin", "Administrador", {
      permissions: ["matricula.editar"],
    }));
    const created = await callFunction(
        "crearMatricula",
        createPayload({vinculaUsuarioId: "student"}),
        adminToken,
    );
    const id = created.body.result.id;

    const noReason = await callFunction(
        "actualizarMatricula", {id, action: "reject"}, adminToken,
    );
    assertError(noReason, "INVALID_ARGUMENT");
    const approved = await callFunction(
        "actualizarMatricula", {id, action: "approve"}, adminToken,
    );
    assert.equal(approved.body.result.estado, "matriculado");
    const invalidBackwards = await callFunction(
        "actualizarMatricula", {id, action: "approve"}, adminToken,
    );
    assertError(invalidBackwards, "FAILED_PRECONDITION");
  });

  it("no matricula sin un usuario estudiante activo vinculado", async () => {
    const adminToken = await signIn(await seedUser("admin", "Administrador", {
      permissions: ["matricula.editar"],
    }));
    const created = await callFunction(
        "crearMatricula", createPayload(), adminToken,
    );
    const response = await callFunction("actualizarMatricula", {
      id: created.body.result.id,
      action: "approve",
    }, adminToken);
    assertError(response, "INVALID_ARGUMENT");
  });

  it("docente opera solo su grado y nunca aprueba", async () => {
    const adminToken = await signIn(await seedUser("admin", "Administrador", {
      permissions: ["matricula.editar"],
    }));
    const created = await callFunction(
        "crearMatricula", createPayload(), adminToken,
    );
    const id = created.body.result.id;
    const teacherToken = await signIn(await seedUser("teacher", "Docente", {
      groupId: "group-5a",
      groupName: "Quinto A",
      permissions: ["matricula.ver", "matricula.editar"],
    }));
    const observed = await callFunction("actualizarMatricula", {
      id,
      action: "observe",
      observation: "Documentos revisados.",
    }, teacherToken);
    assert.equal(observed.body.result.estado, "pendiente_revision");
    const correction = await callFunction("actualizarMatricula", {
      id,
      action: "request_correction",
      observation: "Falta corregir el nombre.",
    }, teacherToken);
    assert.equal(correction.body.result.estado, "correccion_solicitada");
    const approve = await callFunction(
        "actualizarMatricula", {id, action: "approve"}, teacherToken,
    );
    assertError(approve, "INVALID_ARGUMENT");

    const otherTeacher = await signIn(
        await seedUser("other-teacher", "Docente", {
          groupId: "group-6a",
          permissions: ["matricula.editar"],
        }),
    );
    const foreignGrade = await callFunction("actualizarMatricula", {
      id,
      action: "observe",
      observation: "Intento indebido.",
    }, otherTeacher);
    assertError(foreignGrade, "PERMISSION_DENIED");
  });

  it("el familiar corrige solo cuando fue solicitado", async () => {
    await seedUser("student", "Estudiante");
    const familyToken = await signIn(await seedUser("family", "Familiar", {
      studentIds: ["student"],
    }));
    const created = await callFunction("crearMatricula", createPayload({
      vinculaUsuarioId: "student",
    }), familyToken);
    const id = created.body.result.id;
    const early = await callFunction("actualizarMatricula", {
      id,
      action: "resubmit",
      data: enrollmentData(),
    }, familyToken);
    assertError(early, "PERMISSION_DENIED");

    const teacherToken = await signIn(await seedUser("teacher", "Docente", {
      permissions: ["matricula.editar"],
    }));
    await callFunction("actualizarMatricula", {
      id,
      action: "request_correction",
      observation: "Corrija el formulario.",
    }, teacherToken);
    const corrected = await callFunction("actualizarMatricula", {
      id,
      action: "resubmit",
      data: {...enrollmentData(), nombresApellidosAlumno: "Nombre Corregido"},
    }, familyToken);
    assert.equal(corrected.body.result.estado, "pendiente_revision");
  });
});
