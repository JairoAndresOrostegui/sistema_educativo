"use strict";

const assert = require("assert");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");

const projectId = "sistema-educativo-schedule-test";
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

function schedule(extra = {}) {
  return {
    subject: "Matematicas",
    teacherId: "teacher-1",
    groupId: "group-5a",
    day: "lunes",
    institutionId: "inst-1",
    campusId: "campus-1",
    startMinutes: 8 * 60,
    endMinutes: 9 * 60,
    ...extra,
  };
}

function assertError(response, expectedStatus) {
  assert.ok(response.body.error, JSON.stringify(response.body));
  assert.equal(response.body.error.status, expectedStatus);
}

describe("horarios seguros", () => {
  before(() => {
    app = initializeApp({projectId}, "schedule-function-tests");
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
    await seedUser("teacher-1", "Docente", {
      firstName: "Ada",
      lastName: "Lovelace",
      permissions: ["horarios.ver"],
    });
    await seedUser("teacher-2", "Docente", {
      firstName: "Alan",
      lastName: "Turing",
      groupId: "group-6a",
      groupName: "Sexto A",
      permissions: ["horarios.ver"],
    });
  });

  after(async () => deleteApp(app));

  it("crea datos derivados, auditoria y evento de notificacion", async () => {
    const token = await signIn(await seedUser("admin", "Administrador", {
      permissions: ["horarios.crear"],
    }));
    const response = await callFunction("crearHorario", schedule(), token);
    assert.equal(response.body.result.success, true);
    const saved = (await db.collection("subjects")
        .doc(response.body.result.id).get()).data();
    assert.equal(saved.teacherName, "Ada Lovelace");
    assert.equal(saved.startMinutes, 480);
    assert.equal(saved.institutionId, "inst-1");
    assert.equal((await db.collection("schedule_history").get()).size, 1);
    assert.equal(
        (await db.collection("schedule_notification_events").get()).size,
        1,
    );
  });

  it("aplica permisos de accion y rechaza docentes y estudiantes", async () => {
    for (const [uid, role, permissions] of [
      ["admin-no", "Administrador", ["horarios.ver"]],
      ["teacher-caller", "Docente", ["horarios.crear"]],
      ["student-caller", "Estudiante", ["horarios.crear"]],
    ]) {
      const token = await signIn(await seedUser(uid, role, {permissions}));
      assertError(
          await callFunction("crearHorario", schedule(), token),
          "PERMISSION_DENIED",
      );
    }
  });

  it("limita al admin a su sede y permite cruce al superadmin", async () => {
    await seedUser("teacher-campus-2", "Docente", {
      campus: "campus-2",
      groupId: "group-5a-campus-2",
      groupName: "Quinto A",
    });
    const foreign = schedule({
      teacherId: "teacher-campus-2",
      campusId: "campus-2",
      groupId: "group-5a-campus-2",
    });
    const adminToken = await signIn(await seedUser("admin", "Administrador", {
      permissions: ["horarios.crear"],
    }));
    assertError(
        await callFunction("crearHorario", foreign, adminToken),
        "PERMISSION_DENIED",
    );
    const superToken = await signIn(await seedUser("super", "Administrador", {
      isSuperadmin: true,
    }));
    const response = await callFunction("crearHorario", foreign, superToken);
    assert.equal(response.body.result.success, true);
  });

  it("rechaza horas, dias y docentes invalidos", async () => {
    const token = await signIn(await seedUser("admin", "Administrador", {
      permissions: ["horarios.crear"],
    }));
    assertError(
        await callFunction("crearHorario", schedule({
          startMinutes: 600,
          endMinutes: 500,
        }), token),
        "INVALID_ARGUMENT",
    );
    assertError(
        await callFunction("crearHorario", schedule({day: "domingo"}), token),
        "INVALID_ARGUMENT",
    );
    assertError(
        await callFunction("crearHorario", schedule({teacherId: "missing"}),
            token),
        "FAILED_PRECONDITION",
    );
  });

  it("bloquea cruces del mismo grado o docente y admite horas contiguas",
      async () => {
        const token = await signIn(await seedUser("admin", "Administrador", {
          permissions: ["horarios.crear"],
        }));
        const first = await callFunction("crearHorario", schedule(), token);
        assert.equal(first.body.result.success, true);
        assertError(await callFunction("crearHorario", schedule({
          teacherId: "teacher-2",
          startMinutes: 510,
          endMinutes: 570,
        }), token), "ALREADY_EXISTS");
        assertError(await callFunction("crearHorario", schedule({
          groupId: "group-6a",
          startMinutes: 510,
          endMinutes: 570,
        }), token), "ALREADY_EXISTS");
        const adjacent = await callFunction("crearHorario", schedule({
          teacherId: "teacher-2",
          startMinutes: 540,
          endMinutes: 600,
        }), token);
        assert.equal(adjacent.body.result.success, true);
      });

  it("edita y elimina en su sede dejando historial", async () => {
    const token = await signIn(await seedUser("admin", "Administrador", {
      permissions: [
        "horarios.crear", "horarios.editar", "horarios.eliminar",
      ],
    }));
    const created = await callFunction("crearHorario", schedule(), token);
    const id = created.body.result.id;
    const edited = await callFunction("editarHorario", {
      id,
      expectedRevision: 1,
      ...schedule({subject: "Ciencias", startMinutes: 600, endMinutes: 660}),
    }, token);
    assert.equal(edited.body.result.success, true);
    assert.equal((await db.collection("subjects").doc(id).get()).data().subject,
        "Ciencias");
    assert.equal((await db.collection("subjects").doc(id).get())
        .data().revision, 2);
    const removed = await callFunction(
        "eliminarHorario", {id, expectedRevision: 2}, token,
    );
    assert.equal(removed.body.result.success, true);
    assert.equal((await db.collection("subjects").doc(id).get()).exists, false);
    assert.equal((await db.collection("schedule_history").get()).size, 3);
  });

  it("rechaza campos arbitrarios y serializa ediciones concurrentes",
      async () => {
        const token = await signIn(await seedUser("admin", "Administrador", {
          permissions: ["horarios.crear", "horarios.editar"],
        }));
        assertError(await callFunction("crearHorario", schedule({
          isSuperadmin: true,
        }), token), "INVALID_ARGUMENT");
        const created = await callFunction("crearHorario", schedule(), token);
        const id = created.body.result.id;
        const [first, second] = await Promise.all([
          callFunction("editarHorario", {
            id, expectedRevision: 1,
            ...schedule({subject: "Ciencias"}),
          }, token),
          callFunction("editarHorario", {
            id, expectedRevision: 1,
            ...schedule({subject: "Lenguaje"}),
          }, token),
        ]);
        const responses = [first, second];
        assert.equal(responses.filter((item) => item.body.result).length, 1);
        assert.equal(responses.filter((item) =>
          item.body.error?.status === "ABORTED").length, 1);
        assert.equal((await db.collection("subjects").doc(id).get())
            .data().revision, 2);
      });

  it("consulta por rol y permite al docente todos sus grupos", async () => {
    const adminToken = await signIn(await seedUser("admin", "Administrador", {
      permissions: ["horarios.crear"],
    }));
    const first = await callFunction("crearHorario", schedule(), adminToken);
    assert.ok(first.body.result);
    const second = await callFunction("crearHorario", schedule({
      teacherId: "teacher-2",
      startMinutes: 9 * 60,
      endMinutes: 10 * 60,
    }), adminToken);
    assert.ok(second.body.result);

    const teacherToken = await signIn("teacher-1@colegio.test");
    const own = await callFunction(
        "consultarHorarios", {mode: "teacher"}, teacherToken,
    );
    assert.equal(own.body.result.subjects.length, 1);
    assert.deepEqual(own.body.result.groups, [
      {id: "group-5a", name: "Quinto A"},
    ]);
    const group = await callFunction("consultarHorarios", {
      mode: "group", groupId: "group-5a",
    }, teacherToken);
    assert.equal(group.body.result.subjects.length, 2);
    assertError(await callFunction("consultarHorarios", {
      mode: "group", groupId: "group-6a",
    }, teacherToken), "PERMISSION_DENIED");

    const studentToken = await signIn(await seedUser(
        "student", "Estudiante", {permissions: ["horarios.ver"]},
    ));
    const student = await callFunction(
        "consultarHorarios", {mode: "group"}, studentToken,
    );
    assert.equal(student.body.result.subjects.length, 2);

    const familyToken = await signIn(await seedUser("family", "Familiar", {
      studentIds: ["student"], activeStudentId: "student",
      permissions: ["horarios.ver"],
    }));
    const family = await callFunction("consultarHorarios", {
      mode: "group", studentId: "student",
    }, familyToken);
    assert.equal(family.body.result.subjects.length, 2);
    assertError(await callFunction("consultarHorarios", {
      mode: "group", studentId: "teacher-1",
    }, familyToken), "PERMISSION_DENIED");
  });

  it("solo permite seleccionar un hijo activo y realmente vinculado",
      async () => {
        await seedUser("student", "Estudiante");
        await seedUser("unlinked", "Estudiante");
        const familyToken = await signIn(await seedUser("family", "Familiar", {
          studentIds: ["student"],
          permissions: ["horarios.ver"],
        }));
        const selected = await callFunction(
            "seleccionarHijoActivo", {studentId: "student"}, familyToken,
        );
        assert.equal(selected.body.result.studentId, "student");
        assert.equal((await db.collection("users").doc("family").get())
            .data().activeStudentId, "student");
        assertError(await callFunction(
            "seleccionarHijoActivo", {studentId: "unlinked"}, familyToken,
        ), "PERMISSION_DENIED");
        const studentToken = await signIn("student@colegio.test");
        assertError(await callFunction(
            "seleccionarHijoActivo", {studentId: "student"}, studentToken,
        ), "PERMISSION_DENIED");
      });
});
