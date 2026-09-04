"use strict";

const assert = require("assert");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");
const {
  academicYearId,
  seedAcademicYear,
} = require("./academic_year_fixture");

const projectId = "sistema-educativo-users-test";
const functionsBase = `http://127.0.0.1:5002/${projectId}/us-central1`;
const authBase = "http://127.0.0.1:9098/identitytoolkit.googleapis.com/v1";
let app;
let auth;
let db;

const profile = (role, extra = {}) => ({
  firstName: "Usuario",
  lastName: "Prueba",
  document: "10000000",
  institutionalEmail: "usuario@colegio.test",
  role,
  status: "activo",
  institution: "inst-1",
  campus: "campus-1",
  permissions: [],
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
  const email = extra.institutionalEmail || `${uid}@colegio.test`;
  await auth.createUser({uid, email, password: "Clave123!"});
  await db.collection("users").doc(uid).set(profile(role, {
    institutionalEmail: email,
    ...extra,
  }));
  await db.collection("user_directory").doc(uid).set(profile(role, {
    institutionalEmail: email,
    ...extra,
  }));
  return email;
}

async function signInAttempt(email) {
  const url = `${authBase}/accounts:signInWithPassword?key=x`;
  const response = await fetch(url, {
    method: "POST",
    headers: {"content-type": "application/json"},
    body: JSON.stringify({
      email,
      password: "Clave123!",
      returnSecureToken: true,
    }),
  });
  return response.json();
}

async function signIn(email) {
  const body = await signInAttempt(email);
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

async function seedRelations(uid) {
  await db.collection("users").doc("family").set(profile("Familiar", {
    studentIds: [uid],
    activeStudentId: uid,
  }));
  await db.collection("routes").doc("route").set({
    institution: "inst-1",
    campus: "campus-1",
    estudiantes: [uid],
    gestionador: uid,
  });
  await db.collection("subjects").doc("subject").set({
    institution: "inst-1",
    campus: "campus-1",
    teacherId: uid,
  });
  await db.collection("enrollments").doc("enrollment").set({
    institution: "inst-1",
    campus: "campus-1",
    createdByUserId: uid,
    vinculaUsuarioId: uid,
    data: {numeroIdentidad: "10000000"},
  });
  await db.collection("authorization_requests").doc("authorization").set({
    institutionId: "inst-1",
    campusId: "campus-1",
    requesterId: uid,
    studentId: uid,
  });
  const thread = db.collection("message_channels").doc("thread");
  await thread.set({
    institutionId: "inst-1",
    campusId: "campus-1",
    channelType: "private",
    memberUserIds: [uid, "family"],
  });
  await thread.collection("messages").doc("message").set({senderId: uid});
  const daily = db.collection("daily_routes").doc("daily");
  await daily.set({
    institution: "inst-1",
    campus: "campus-1",
    gestionador: uid,
  });
  await daily.collection("students").doc(uid).set({status: "pending"});
  await db.collection("user_logs").doc("audit-log").set({
    userId: uid,
    institution: "inst-1",
    campus: "campus-1",
  });
}

function createPayload({
  document = "70000001",
  email = "nuevo@colegio.test",
  personalEmail = "personal@correo.test",
  role = "Estudiante",
  institution = "inst-1",
  campus = "campus-1",
  permissions = [],
  studentIds = [],
  activeStudentId = null,
} = {}) {
  return {
    email,
    password: document,
    nombres: "Nuevo",
    apellidos: "Usuario",
    rol: role,
    documento: document,
    profile: profile(role, {
      firstName: "Nuevo",
      lastName: "Usuario",
      document,
      documentType: role === "Estudiante" ? "TI" : "CC",
      institutionalEmail: email,
      personalEmail,
      institution,
      campus,
      groupId: ["Estudiante", "Docente"].includes(role) ?
        "group-5a" : null,
      groupName: ["Estudiante", "Docente"].includes(role) ?
        "Quinto A" : null,
      permissions,
      studentIds,
      activeStudentId,
    }),
  };
}

describe("baja y eliminacion de usuarios", () => {
  before(() => {
    app = initializeApp({
      projectId,
      storageBucket: `${projectId}.appspot.com`,
    }, "user-function-tests");
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
    const yearId = await seedAcademicYear(db, "inst-1", "campus-1");
    const campus2YearId = await seedAcademicYear(db, "inst-1", "campus-2");
    await db.collection("academic_groups").doc("group-5a").set({
      institutionId: "inst-1", campusId: "campus-1", level: "Quinto",
      academicYearId: yearId, academicYear: 2026,
      section: "A", name: "Quinto A", order: 5, active: true,
    });
    await db.collection("academic_groups").doc("group-5a-campus-2").set({
      institutionId: "inst-1", campusId: "campus-2", level: "Quinto",
      academicYearId: campus2YearId, academicYear: 2026,
      section: "A", name: "Quinto A", order: 5, active: true,
    });
  });

  after(async () => {
    await deleteApp(app);
  });

  it("informa todas las dependencias sin modificarlas", async () => {
    const adminEmail = await seedUser("admin", "Administrador", {
      permissions: ["usuarios.eliminar"],
    });
    await seedUser("target", "Estudiante");
    await seedRelations("target");
    const token = await signIn(adminEmail);

    const response = await callFunction(
        "obtenerImpactoEliminacionUsuario",
        {uid: "target"},
        token,
    );
    assert.ok(response.body.result);
    const impact = Object.fromEntries(
        response.body.result.impact.map((item) => [item.key, item.count]),
    );
    assert.equal(impact.enrollments, 1);
    assert.equal(impact.authorizations, 1);
    assert.equal(impact.messages, 1);
    assert.equal(impact.families, 1);
    assert.equal(impact.routes, 1);
    assert.equal(impact.subjects, 1);
    assert.equal(impact.audit, 1);
    assert.ok((await db.collection("users").doc("target").get()).exists);
  });

  it("permite al admin dejar inactivo sin borrar relaciones", async () => {
    const adminEmail = await seedUser("admin", "Administrador", {
      permissions: ["usuarios.eliminar", "usuarios.editar"],
    });
    const targetEmail = await seedUser("target", "Estudiante");
    await seedRelations("target");
    const token = await signIn(adminEmail);

    const response = await callFunction(
        "eliminarUsuarioAuth",
        {uid: "target", mode: "inactive"},
        token,
    );
    assert.equal(response.body.result.deletionType, "inactive");
    const target = await db.collection("users").doc("target").get();
    assert.equal(target.data().status, "inactivo");
    assert.equal((await auth.getUser("target")).disabled, true);
    assert.ok((await db.collection("enrollments").doc("enrollment").get())
        .exists);
    const rejected = await signInAttempt(targetEmail);
    assert.equal(rejected.error.message, "USER_DISABLED");

    const reactivated = await callFunction(
        "actualizarEstadoUsuario",
        {uid: "target", status: "activo"},
        token,
    );
    assert.equal(reactivated.body.result.status, "activo");
    assert.equal((await auth.getUser("target")).disabled, false);
    assert.ok((await signInAttempt(targetEmail)).idToken);
  });

  it("retira al usuario del listado administrativo sin borrarlo", async () => {
    const adminEmail = await seedUser("admin", "Administrador", {
      permissions: ["usuarios.eliminar"],
    });
    await seedUser("target", "Estudiante");
    const token = await signIn(adminEmail);

    const response = await callFunction(
        "eliminarUsuarioAuth",
        {uid: "target", mode: "soft"},
        token,
    );
    assert.equal(response.body.result.deletionType, "soft");
    const target = await db.collection("users").doc("target").get();
    assert.equal(target.data().status, "eliminado");
    assert.equal(target.data().administrativeRemoval, true);
    assert.equal((await auth.getUser("target")).disabled, true);
  });

  it("reserva la eliminacion definitiva al superadmin", async () => {
    const adminEmail = await seedUser("admin", "Administrador", {
      permissions: ["usuarios.eliminar"],
    });
    await seedUser("target", "Estudiante");
    const token = await signIn(adminEmail);

    const response = await callFunction(
        "eliminarUsuarioAuth",
        {uid: "target", mode: "permanent", confirmation: "ELIMINAR target"},
        token,
    );
    assert.equal(response.body.error.status, "PERMISSION_DENIED");
    assert.ok((await db.collection("users").doc("target").get()).exists);
  });

  it("ejecuta la cascada y conserva la auditoria", async () => {
    const superEmail = await seedUser("super", "Administrador", {
      isSuperadmin: true,
    });
    await seedUser("target", "Estudiante");
    await seedRelations("target");
    const token = await signIn(superEmail);

    const response = await callFunction(
        "eliminarUsuarioAuth",
        {uid: "target", mode: "permanent", confirmation: "ELIMINAR target"},
        token,
    );
    assert.ok(response.body.result, JSON.stringify(response.body));
    assert.equal((await db.collection("users").doc("target").get()).exists,
        false);
    await assert.rejects(auth.getUser("target"), /no user record/i);
    assert.equal((await db.collection("enrollments").doc("enrollment").get())
        .exists, false);
    assert.equal((await db.collection("authorization_requests")
        .doc("authorization").get()).exists, false);
    assert.equal((await db.collection("message_channels").doc("thread").get())
        .exists, false);
    const family = await db.collection("users").doc("family").get();
    assert.deepEqual(family.data().studentIds, []);
    const route = await db.collection("routes").doc("route").get();
    assert.deepEqual(route.data().estudiantes, []);
    assert.equal(route.data().gestionador, null);
    const subject = await db.collection("subjects").doc("subject").get();
    assert.equal(subject.data().teacherId, "");
    assert.ok((await db.collection("user_logs").doc("audit-log").get()).exists);
    const history = await db.collection("user_history")
        .where("usuarioId", "==", "target").get();
    assert.ok(history.size >= 1);
  });

  it("crea estudiantes solo con permiso y dentro de la sede", async () => {
    const adminEmail = await seedUser("admin", "Administrador", {
      permissions: ["usuarios.crear"],
    });
    const token = await signIn(adminEmail);
    const response = await callFunction(
        "crearUsuarioDesdeAdmin",
        createPayload(),
        token,
    );
    assert.ok(response.body.result.exito);
    const uid = response.body.result.uid;
    const created = await db.collection("users").doc(uid).get();
    assert.equal(created.data().institution, "inst-1");
    assert.equal(created.data().campus, "campus-1");
    assert.equal(created.data().role, "Estudiante");
    assert.equal((await auth.getUser(uid)).emailVerified, false);

    const withoutPermission = await seedUser(
        "admin-no-create", "Administrador",
    );
    const deniedToken = await signIn(withoutPermission);
    const denied = await callFunction(
        "crearUsuarioDesdeAdmin",
        createPayload({
          document: "70000002",
          email: "denegado@colegio.test",
          personalEmail: "denegado@correo.test",
        }),
        deniedToken,
    );
    assert.equal(denied.body.error.status, "PERMISSION_DENIED");
  });

  it("impide al admin crear en otra sede o crear administradores", async () => {
    const adminEmail = await seedUser("admin", "Administrador", {
      permissions: ["usuarios.crear"],
    });
    const token = await signIn(adminEmail);
    const otherCampus = await callFunction(
        "crearUsuarioDesdeAdmin",
        createPayload({campus: "campus-2"}),
        token,
    );
    assert.equal(otherCampus.body.error.status, "PERMISSION_DENIED");
    const administrator = await callFunction(
        "crearUsuarioDesdeAdmin",
        createPayload({
          role: "Administrador",
          document: "70000003",
          email: "admin2@colegio.test",
          personalEmail: "admin2@correo.test",
        }),
        token,
    );
    assert.equal(administrator.body.error.status, "PERMISSION_DENIED");
  });

  it("permite al superadmin crear administradores entre sedes", async () => {
    const superEmail = await seedUser("super", "Administrador", {
      isSuperadmin: true,
    });
    const token = await signIn(superEmail);
    const response = await callFunction(
        "crearUsuarioDesdeAdmin",
        createPayload({
          role: "Administrador",
          campus: "campus-2",
          document: "70000004",
          email: "admin.sede2@colegio.test",
          personalEmail: "admin.sede2@correo.test",
        }),
        token,
    );
    assert.ok(response.body.result.exito, JSON.stringify(response.body));
    const created = await db.collection("users")
        .doc(response.body.result.uid).get();
    assert.equal(created.data().campus, "campus-2");
    assert.equal(created.data().role, "Administrador");
    const oobResponse = await fetch(
        `http://127.0.0.1:9098/emulator/v1/projects/${projectId}/oobCodes`,
    );
    const oobCodes = await oobResponse.json();
    assert.ok(oobCodes.oobCodes.some(
        (code) => code.email === "admin.sede2@colegio.test",
    ));
  });

  it("rechaza incluso al superadmin una sede no configurada", async () => {
    const superEmail = await seedUser("super", "Administrador", {
      isSuperadmin: true,
    });
    const token = await signIn(superEmail);
    const response = await callFunction(
        "crearUsuarioDesdeAdmin",
        createPayload({campus: "campus-inventado"}),
        token,
    );
    assert.equal(response.body.error.status, "FAILED_PRECONDITION");
  });

  it("rechaza documentos y correos duplicados desde el backend", async () => {
    const superEmail = await seedUser("super", "Administrador", {
      isSuperadmin: true,
    });
    await seedUser("existing", "Estudiante", {
      document: "70000005",
      personalEmail: "duplicado@correo.test",
      institutionalEmail: "existente@colegio.test",
    });
    const token = await signIn(superEmail);
    const duplicatedDocument = await callFunction(
        "crearUsuarioDesdeAdmin",
        createPayload({
          document: "70000005",
          email: "otro@colegio.test",
          personalEmail: "otro@correo.test",
        }),
        token,
    );
    assert.equal(duplicatedDocument.body.error.status, "ALREADY_EXISTS");
    const duplicatedPersonal = await callFunction(
        "crearUsuarioDesdeAdmin",
        createPayload({
          document: "70000006",
          email: "otro2@colegio.test",
          personalEmail: "duplicado@correo.test",
        }),
        token,
    );
    assert.equal(duplicatedPersonal.body.error.status, "ALREADY_EXISTS");
  });

  it("valida vinculos familiares activos de la misma sede", async () => {
    const superEmail = await seedUser("super", "Administrador", {
      isSuperadmin: true,
    });
    await seedUser("student-local", "Estudiante");
    await seedUser("student-foreign", "Estudiante", {campus: "campus-2"});
    const token = await signIn(superEmail);
    const valid = await callFunction(
        "crearUsuarioDesdeAdmin",
        createPayload({
          role: "Familiar",
          document: "70000007",
          email: "familiar@colegio.test",
          personalEmail: "familiar@correo.test",
          studentIds: ["student-local"],
          activeStudentId: "student-local",
        }),
        token,
    );
    assert.ok(valid.body.result.exito);
    const invalid = await callFunction(
        "crearUsuarioDesdeAdmin",
        createPayload({
          role: "Familiar",
          document: "70000008",
          email: "familiar2@colegio.test",
          personalEmail: "familiar2@correo.test",
          studentIds: ["student-foreign"],
        }),
        token,
    );
    assert.equal(invalid.body.error.status, "FAILED_PRECONDITION");
    await assert.rejects(
        auth.getUserByEmail("familiar2@colegio.test"),
        /no user record/i,
    );
  });

  it("filtra permisos restringidos al crear", async () => {
    const adminEmail = await seedUser("admin", "Administrador", {
      permissions: ["usuarios.crear"],
    });
    const token = await signIn(adminEmail);
    const response = await callFunction(
        "crearUsuarioDesdeAdmin",
        createPayload({
          document: "70000009",
          email: "permisos@colegio.test",
          personalEmail: "permisos@correo.test",
          permissions: ["rutas.ver", "matricula.ver", "usuarios.ver"],
        }),
        token,
    );
    const created = await db.collection("users")
        .doc(response.body.result.uid).get();
    assert.deepEqual(created.data().permissions.sort(), [
      "matricula.ver",
      "rutas.ver",
    ]);
  });

  it("limita permisos de autorizaciones segun el rol", async () => {
    const superEmail = await seedUser("super", "Administrador", {
      isSuperadmin: true,
    });
    const token = await signIn(superEmail);
    const requested = [
      "autorizaciones.ver",
      "autorizaciones.crear",
      "autorizaciones.editar",
      "autorizaciones.eliminar",
    ];
    const student = await callFunction(
        "crearUsuarioDesdeAdmin",
        createPayload({
          document: "70000019",
          email: "student.permissions@colegio.test",
          personalEmail: "student.permissions@correo.test",
          permissions: requested,
        }),
        token,
    );
    const studentProfile = await db.collection("users")
        .doc(student.body.result.uid).get();
    assert.deepEqual(studentProfile.data().permissions, []);

    const family = await callFunction(
        "crearUsuarioDesdeAdmin",
        createPayload({
          role: "Familiar",
          document: "70000020",
          email: "family.permissions@colegio.test",
          personalEmail: "family.permissions@correo.test",
          permissions: requested,
        }),
        token,
    );
    const familyProfile = await db.collection("users")
        .doc(family.body.result.uid).get();
    assert.deepEqual(familyProfile.data().permissions, [
      "autorizaciones.ver",
    ]);
  });

  it("edita en la sede y reserva movimientos al superadmin", async () => {
    const adminEmail = await seedUser("admin", "Administrador", {
      permissions: ["usuarios.editar"],
    });
    await seedUser("target", "Estudiante", {
      document: "80000001",
      personalEmail: "antes@correo.test",
      groupId: "group-5a",
      groupName: "Quinto A",
      notificationTokens: {mobile: "token-prueba"},
    });
    const token = await signIn(adminEmail);
    const current = (await db.collection("users").doc("target").get()).data();
    const localEdit = await callFunction(
        "actualizarUsuarioDesdeAdmin",
        {uid: "target", profile: {...current,
          firstName: "Editado", personalEmail: "despues@correo.test"}},
        token,
    );
    assert.ok(localEdit.body.result, JSON.stringify(localEdit.body));
    assert.ok(localEdit.body.result.success);
    assert.equal((await db.collection("users").doc("target").get())
        .data().firstName, "Editado");
    assert.equal((await db.collection("users").doc("target").get())
        .data().notificationTokens.mobile, "token-prueba");

    const otherCampus = await callFunction(
        "actualizarUsuarioDesdeAdmin",
        {uid: "target", profile: {...current, campus: "campus-2"}},
        token,
    );
    assert.equal(otherCampus.body.error.status, "PERMISSION_DENIED");

    const superEmail = await seedUser("super", "Administrador", {
      isSuperadmin: true,
    });
    const superToken = await signIn(superEmail);
    const latest = (await db.collection("users").doc("target").get()).data();
    const moved = await callFunction(
        "actualizarUsuarioDesdeAdmin",
        {uid: "target", profile: {
          ...latest,
          campus: "campus-2",
          groupId: "group-5a-campus-2",
          groupName: "Quinto A",
        }},
        superToken,
    );
    assert.ok(moved.body.result.success, JSON.stringify(moved.body));
    assert.equal((await db.collection("users").doc("target").get())
        .data().campus, "campus-2");
  });

  it("no mueve de sede un usuario con relaciones institucionales", async () => {
    const superEmail = await seedUser("super", "Administrador", {
      isSuperadmin: true,
    });
    await seedUser("target", "Estudiante", {
      document: "80000002",
      personalEmail: "relacionado@correo.test",
      groupId: "group-5a",
      groupName: "Quinto A",
    });
    await seedRelations("target");
    const token = await signIn(superEmail);
    const current = (await db.collection("users").doc("target").get()).data();
    const response = await callFunction(
        "actualizarUsuarioDesdeAdmin",
        {uid: "target", profile: {
          ...current,
          campus: "campus-2",
          groupId: "group-5a-campus-2",
          groupName: "Quinto A",
        }},
        token,
    );
    assert.equal(response.body.error.status, "FAILED_PRECONDITION");
    assert.equal((await db.collection("users").doc("target").get())
        .data().campus, "campus-1");
  });

  it("traslada y revierte la carga sin falsear autoria", async () => {
    const adminEmail = await seedUser("admin", "Administrador", {
      permissions: ["usuarios.editar"],
    });
    await seedUser("source-teacher", "Docente", {
      firstName: "Docente", lastName: "Saliente", tutorGroupId: "group-5a",
    });
    await seedUser("target-teacher", "Docente", {
      firstName: "Docente", lastName: "Reemplazo",
    });
    const yearId = academicYearId("inst-1", "campus-1");
    await db.collection("subjects").doc("source-subject").set({
      institutionId: "inst-1", campusId: "campus-1",
      academicYearId: yearId, academicYear: 2026,
      teacherId: "source-teacher", teacherName: "Docente Saliente",
      groupId: "group-5a", groupName: "Quinto A", subject: "Ciencias",
      day: "lunes", startMinutes: 480, endMinutes: 540, revision: 1,
    });
    await db.collection("routes").doc("teacher-route").set({
      institution: "inst-1", campus: "campus-1",
      academicYearId: yearId, academicYear: 2026,
      gestionador: "source-teacher",
    });
    await db.collection("daily_routes").doc("teacher-daily-route").set({
      institution: "inst-1", campus: "campus-1",
      academicYearId: yearId, academicYear: 2026,
      gestionador: "source-teacher", gestionadaPorNombre: "Docente Saliente",
    });
    await db.collection("message_channels").doc("teacher-thread").set({
      institutionId: "inst-1", campusId: "campus-1",
      academicYearId: yearId, academicYear: 2026,
      channelType: "private",
      memberUserIds: ["source-teacher", "student"],
      memberNames: {
        "source-teacher": "Docente Saliente", "student": "Estudiante",
      },
      memberRoles: {
        "source-teacher": "Docente", "student": "Estudiante",
      },
    });
    await db.collection("message_channels").doc("teacher-thread")
        .collection("messages").doc("historic-message").set({
          senderId: "source-teacher", senderName: "Docente Saliente",
        });
    await db.collection("files").doc("teacher-file").set({
      institutionId: "inst-1", campusId: "campus-1",
      academicYearId: yearId, academicYear: 2026,
      uploadedBy: "source-teacher",
      recipientUserIds: ["source-teacher"],
    });
    const token = await signIn(adminEmail);
    const preview = await callFunction("previsualizarTrasladoDocente", {
      sourceTeacherId: "source-teacher",
      targetTeacherId: "target-teacher",
    }, token);
    assert.equal(preview.body.result.impact.schedules, 1);
    assert.equal(preview.body.result.impact.messageThreads, 2);
    assert.deepEqual(preview.body.result.conflicts, []);

    const moved = await callFunction("ejecutarTrasladoDocente", {
      sourceTeacherId: "source-teacher",
      targetTeacherId: "target-teacher",
      mode: "temporary",
      endsAtMillis: Date.now() + 7 * 24 * 60 * 60 * 1000,
      allowMerge: false,
    }, token);
    assert.ok(moved.body.result.success, JSON.stringify(moved.body));
    assert.equal((await auth.getUser("source-teacher")).disabled, true);
    assert.equal((await db.collection("subjects").doc("source-subject").get())
        .data().teacherId, "target-teacher");
    const thread = (await db.collection("message_channels")
        .doc("teacher-thread").get()).data();
    assert.ok(thread.memberUserIds.includes("target-teacher"));
    const message = (await db.collection("message_channels")
        .doc("teacher-thread").collection("messages")
        .doc("historic-message").get()).data();
    assert.equal(message.senderId, "source-teacher");
    assert.equal((await db.collection("files").doc("teacher-file").get())
        .data().uploadedBy, "source-teacher");

    const reverted = await callFunction("revertirTrasladoDocenteTemporal", {
      id: moved.body.result.id,
    }, token);
    assert.ok(reverted.body.result.success, JSON.stringify(reverted.body));
    assert.equal((await auth.getUser("source-teacher")).disabled, false);
    assert.equal((await db.collection("subjects").doc("source-subject").get())
        .data().teacherId, "source-teacher");
  });

  it("prepara y activa el siguiente anio sin borrar el historico", async () => {
    const adminEmail = await seedUser("admin", "Administrador");
    const token = await signIn(adminEmail);
    const prepared = await callFunction("prepararAnioLectivo", {
      institutionId: "inst-1",
      campusId: "campus-1",
      year: 2027,
      cloneGroups: true,
      cloneSchedules: false,
    }, token);
    assert.ok(prepared.body.result.success, JSON.stringify(prepared.body));
    assert.equal(prepared.body.result.copiedGroups, 1);
    const newYearId = prepared.body.result.id;
    assert.equal((await db.collection("academic_years").doc(newYearId).get())
        .data().status, "draft");
    const groups = await db.collection("academic_groups")
        .where("academicYearId", "==", newYearId).get();
    assert.equal(groups.size, 1);
    assert.notEqual(groups.docs[0].id, "group-5a");

    const activated = await callFunction("activarAnioLectivo", {
      academicYearId: newYearId,
      confirmation: "ACTIVAR 2027",
    }, token);
    assert.ok(activated.body.result.success, JSON.stringify(activated.body));
    assert.equal((await db.collection("academic_years").doc(newYearId).get())
        .data().status, "active");
    const oldYearId = academicYearId("inst-1", "campus-1", 2026);
    assert.equal((await db.collection("academic_years").doc(oldYearId).get())
        .data().status, "closed");
    assert.ok((await db.collection("academic_groups").doc("group-5a").get())
        .exists);
  });
});
