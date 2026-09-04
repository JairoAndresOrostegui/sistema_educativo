"use strict";

const assert = require("assert");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");
const {seedAcademicYear} = require("./academic_year_fixture");

const projectId = "sistema-educativo-authorization-test";
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
  groupId: ["Docente", "Estudiante"].includes(role) ? "group-5a" : null,
  groupName: ["Docente", "Estudiante"].includes(role) ? "Quinto A" : null,
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

function requestData(studentId = "student") {
  const start = new Date(2026, 7, 10, 8, 0).getTime();
  const end = new Date(2026, 7, 10, 10, 0).getTime();
  return {
    studentId,
    allDay: false,
    multiDay: false,
    dateFrom: start,
    dateTo: null,
    startTime: start,
    endTime: end,
    reason: "Cita medica de control",
  };
}

function assertError(response, expectedStatus) {
  assert.ok(response.body.error, JSON.stringify(response.body));
  assert.equal(response.body.error.status, expectedStatus);
}

async function familyFixture() {
  await seedUser("student", "Estudiante", {
    firstName: "Ana",
    lastName: "Llinas",
  });
  const familyToken = await signIn(await seedUser("family", "Familiar", {
    studentIds: ["student"],
    permissions: ["autorizaciones.ver"],
  }));
  return familyToken;
}

describe("autorizaciones seguras", () => {
  before(() => {
    app = initializeApp({projectId}, "authorization-function-tests");
    auth = getAuth(app);
    db = getFirestore(app);
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
  });

  after(async () => deleteApp(app));

  it("familiar con ver crea y el servidor deriva los datos", async () => {
    const familyToken = await familyFixture();
    await seedUser("admin", "Administrador", {
      permissions: ["autorizaciones.ver"],
    });
    const response = await callFunction(
        "crearAutorizacion", requestData(), familyToken,
    );
    assert.equal(response.body.result.status, "pending");
    const saved = (await db.collection("authorization_requests")
        .doc(response.body.result.id).get()).data();
    assert.equal(saved.requesterId, "family");
    assert.equal(saved.studentFullName, "Ana Llinas");
    assert.equal(saved.groupId, "group-5a");
    assert.equal(saved.groupName, "Quinto A");
    assert.equal((await db.collection("authorization_history").get()).size, 1);
    assert.equal(
        (await db.collection("authorization_notification_events").get()).size,
        1,
    );
  });

  it("estudiante no accede aun si tiene autorizaciones.ver", async () => {
    const token = await signIn(await seedUser("student", "Estudiante", {
      permissions: ["autorizaciones.ver"],
    }));
    const response = await callFunction(
        "crearAutorizacion", requestData("student"), token,
    );
    assertError(response, "PERMISSION_DENIED");
  });

  it("familiar sin ver o sin vinculo no puede crear", async () => {
    await seedUser("student", "Estudiante");
    const withoutPermission = await signIn(
        await seedUser("family-no-permission", "Familiar", {
          studentIds: ["student"],
        }),
    );
    assertError(
        await callFunction(
            "crearAutorizacion", requestData(), withoutPermission,
        ),
        "PERMISSION_DENIED",
    );
    const unlinked = await signIn(
        await seedUser("family-unlinked", "Familiar", {
          permissions: ["autorizaciones.ver"],
        }),
    );
    assertError(
        await callFunction("crearAutorizacion", requestData(), unlinked),
        "PERMISSION_DENIED",
    );
  });

  it("permite correccion solamente al familiar solicitante", async () => {
    const familyToken = await familyFixture();
    const adminToken = await signIn(await seedUser("admin", "Administrador", {
      permissions: ["autorizaciones.editar"],
    }));
    const created = await callFunction(
        "crearAutorizacion", requestData(), familyToken,
    );
    const id = created.body.result.id;
    const correction = await callFunction("actualizarAutorizacion", {
      id,
      action: "request_correction",
      note: "Debe ampliar el motivo.",
    }, adminToken);
    assert.equal(correction.body.result.status, "pending");
    const resubmitted = await callFunction("actualizarAutorizacion", {
      id,
      action: "resubmit",
      ...requestData(),
      reason: "Cita medica de control con especialista",
    }, familyToken);
    assert.equal(resubmitted.body.result.status, "pending");
    const saved = (await db.collection("authorization_requests").doc(id).get())
        .data();
    assert.equal(saved.requiresRequesterEdit, false);
  });

  it("admin solo opera su sede y superadmin cruza sedes", async () => {
    await seedUser("student-2", "Estudiante", {campus: "campus-2"});
    const foreignYearId = await seedAcademicYear(
        db, "inst-1", "campus-2",
    );
    const foreignRef = db.collection("authorization_requests").doc("foreign");
    await foreignRef.set({
      institutionId: "inst-1",
      campusId: "campus-2",
      academicYearId: foreignYearId,
      academicYear: 2026,
      studentId: "student-2",
      studentFullName: "Estudiante Dos",
      requesterId: "family-2",
      groupId: "group-5a",
      groupName: "Quinto A",
      status: "pending",
      requiresRequesterEdit: false,
    });
    const adminToken = await signIn(await seedUser("admin", "Administrador", {
      permissions: ["autorizaciones.editar"],
    }));
    assertError(await callFunction("actualizarAutorizacion", {
      id: "foreign",
      action: "approve",
    }, adminToken), "PERMISSION_DENIED");

    const superToken = await signIn(await seedUser("super", "Administrador", {
      isSuperadmin: true,
    }));
    const approved = await callFunction("actualizarAutorizacion", {
      id: "foreign",
      action: "approve",
    }, superToken);
    assert.equal(approved.body.result.status, "approved");
  });

  it("exige observacion para rechazar y para finalizar", async () => {
    const familyToken = await familyFixture();
    const adminToken = await signIn(await seedUser("admin", "Administrador", {
      permissions: ["autorizaciones.editar"],
    }));
    const first = await callFunction(
        "crearAutorizacion", requestData(), familyToken,
    );
    assertError(await callFunction("actualizarAutorizacion", {
      id: first.body.result.id,
      action: "reject",
    }, adminToken), "INVALID_ARGUMENT");

    await callFunction("actualizarAutorizacion", {
      id: first.body.result.id,
      action: "approve",
    }, adminToken);
    assertError(await callFunction("actualizarAutorizacion", {
      id: first.body.result.id,
      action: "finish",
    }, adminToken), "INVALID_ARGUMENT");
    const finished = await callFunction("actualizarAutorizacion", {
      id: first.body.result.id,
      action: "finish",
      evidence: "El estudiante salio con su acudiente a las 10:15.",
    }, adminToken);
    assert.equal(finished.body.result.status, "finished");
  });

  it("solo superadmin reabre una finalizada dejando auditoria", async () => {
    const familyToken = await familyFixture();
    const adminToken = await signIn(await seedUser("admin", "Administrador", {
      permissions: ["autorizaciones.editar"],
    }));
    const created = await callFunction(
        "crearAutorizacion", requestData(), familyToken,
    );
    const id = created.body.result.id;
    await callFunction(
        "actualizarAutorizacion", {id, action: "approve"}, adminToken,
    );
    await callFunction("actualizarAutorizacion", {
      id,
      action: "finish",
      evidence: "Salida finalizada sin novedad.",
    }, adminToken);
    assertError(await callFunction("actualizarAutorizacion", {
      id,
      action: "request_correction",
      note: "Intento de reapertura",
    }, adminToken), "FAILED_PRECONDITION");

    const superToken = await signIn(await seedUser("super", "Administrador", {
      isSuperadmin: true,
    }));
    assertError(await callFunction("actualizarAutorizacion", {
      id,
      action: "super_override",
      targetStatus: "approved",
    }, superToken), "INVALID_ARGUMENT");
    const reopened = await callFunction("actualizarAutorizacion", {
      id,
      action: "super_override",
      targetStatus: "approved",
      note: "Se corrige cierre registrado por error operativo.",
    }, superToken);
    assert.equal(reopened.body.result.status, "approved");
    const logs = await db.collection("authorization_history")
        .where("authorizationId", "==", id).get();
    assert.ok(logs.docs.some((item) =>
      item.data().action === "super_override" &&
      item.data().performedBy === "super"));
  });
});
