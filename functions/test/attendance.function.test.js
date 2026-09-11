"use strict";
/* eslint-disable max-len */
const assert = require("assert");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");
const {seedAcademicYear} = require("./academic_year_fixture");

const projectId = "sistema-educativo-attendance-test";
const functionsBase = `http://127.0.0.1:${process.env.RELEASE_FUNCTIONS_PORT || 5002}/${projectId}/us-central1`;
const authBase = `http://127.0.0.1:${process.env.RELEASE_AUTH_PORT || 9098}/identitytoolkit.googleapis.com/v1`;
let app; let auth; let db; let yearId;
const tokens = {};
const today = () => new Intl.DateTimeFormat("en-CA", {
  timeZone: "America/Bogota",
}).format(new Date());

async function clear() {
  await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${projectId}/databases/(default)/documents`, {method: "DELETE"});
  const users = await auth.listUsers(1000);
  if (users.users.length) await auth.deleteUsers(users.users.map((user) => user.uid));
  for (const key of Object.keys(tokens)) delete tokens[key];
}

async function seedUser(uid, role, extra = {}) {
  const email = `${uid}@colegio.test`;
  await auth.createUser({uid, email, password: "Clave123!", emailVerified: true});
  await db.collection("users").doc(uid).set({
    firstName: uid, lastName: "Prueba", institutionalEmail: email,
    role, status: "activo", institution: "i", campus: "c",
    permissions: [], studentIds: [], ...extra,
  });
  const response = await fetch(`${authBase}/accounts:signInWithPassword?key=x`, {
    method: "POST", headers: {"content-type": "application/json"},
    body: JSON.stringify({email, password: "Clave123!", returnSecureToken: true}),
  });
  tokens[uid] = (await response.json()).idToken;
}

async function call(name, data, uid) {
  const response = await fetch(`${functionsBase}/${name}`, {
    method: "POST", headers: {
      "content-type": "application/json",
      "authorization": `Bearer ${tokens[uid]}`,
    },
    body: JSON.stringify({data}),
  });
  return response.json();
}

function status(response, expected) {
  assert.equal(response.error?.status, expected, JSON.stringify(response));
}

describe("lista de asistencia", () => {
  before(() => {
    app = initializeApp({projectId}, "attendance-function-tests");
    auth = getAuth(app); db = getFirestore(app);
  });
  after(() => deleteApp(app));
  beforeEach(async () => {
    await clear();
    yearId = await seedAcademicYear(db, "i", "c");
    await db.collection("academic_groups").doc("g1").set({
      institutionId: "i", campusId: "c", academicYearId: yearId,
      academicYear: 2026, name: "Quinto A", level: "Quinto", section: "A",
      active: true,
    });
    await db.collection("academic_groups").doc("g2").set({
      institutionId: "i", campusId: "c", academicYearId: yearId,
      academicYear: 2026, name: "Sexto A", level: "Sexto", section: "A",
      active: true,
    });
    await seedUser("teacher", "Docente", {
      permissions: ["asistencia.ver", "asistencia.crear"], tutorGroupId: "g1",
    });
    await seedUser("replacement", "Docente", {
      permissions: ["asistencia.ver", "asistencia.crear"], groupId: "g2",
    });
    await seedUser("student1", "Estudiante", {
      permissions: ["asistencia.ver"], groupId: "g1", groupName: "Quinto A",
    });
    await seedUser("student2", "Estudiante", {
      permissions: ["asistencia.ver"], groupId: "g1", groupName: "Quinto A",
    });
    await seedUser("outsider", "Estudiante", {
      permissions: ["asistencia.ver"], groupId: "g2", groupName: "Sexto A",
    });
    await seedUser("family", "Familiar", {
      permissions: ["asistencia.ver"], studentIds: ["student1"],
      activeStudentId: "student1",
    });
    await seedUser("admin", "Administrador", {
      permissions: ["asistencia.ver", "asistencia.crear", "asistencia.editar", "usuarios.editar"],
    });
    await db.collection("subjects").doc("subject1").set({
      institutionId: "i", campusId: "c", academicYearId: yearId,
      academicYear: 2026, groupId: "g1", groupName: "Quinto A",
      subject: "Matemáticas", teacherId: "teacher", teacherName: "teacher Prueba",
    });
  });

  it("limita contextos docentes, congela la lista y evita sesiones duplicadas", async () => {
    const contexts = (await call("listarContextosAsistencia", {}, "teacher")).result;
    assert.deepEqual(contexts.groups.map((group) => group.id), ["g1"]);
    assert.deepEqual(contexts.subjects.map((subject) => subject.id), ["subject1"]);
    const opened = await call("abrirSesionAsistencia", {
      groupId: "g1", subjectId: "subject1", date: today(),
    }, "teacher");
    assert.ok(opened.result.sessionId, JSON.stringify(opened));
    assert.equal(opened.result.roster.length, 2);
    status(await call("abrirSesionAsistencia", {
      groupId: "g1", subjectId: "subject1", date: today(),
    }, "teacher"), "ALREADY_EXISTS");
    await seedUser("student3", "Estudiante", {
      permissions: ["asistencia.ver"], groupId: "g1", groupName: "Quinto A",
    });
    const loaded = (await call("obtenerSesionAsistencia", {
      sessionId: opened.result.sessionId,
    }, "teacher")).result;
    assert.equal(loaded.roster.length, 2);
    status(await call("abrirSesionAsistencia", {
      groupId: "g2", date: today(),
    }, "teacher"), "PERMISSION_DENIED");
  });

  it("serializa marcas, exige lista completa y audita corrección cerrada", async () => {
    const sessionId = (await call("abrirSesionAsistencia", {
      groupId: "g1", subjectId: "subject1", date: today(),
    }, "teacher")).result.sessionId;
    const first = await call("guardarAsistencia", {
      sessionId, expectedRevision: 1,
      entries: [{studentId: "student1", state: "absent", observation: "Sin aviso"}],
    }, "teacher");
    assert.equal(first.result.revision, 2);
    status(await call("guardarAsistencia", {
      sessionId, expectedRevision: 1,
      entries: [{studentId: "student2", state: "present"}],
    }, "teacher"), "ABORTED");
    status(await call("guardarAsistencia", {
      sessionId, expectedRevision: 2,
      entries: [{studentId: "outsider", state: "present"}],
    }, "teacher"), "PERMISSION_DENIED");
    status(await call("cerrarSesionAsistencia", {
      sessionId, expectedRevision: 2,
    }, "teacher"), "FAILED_PRECONDITION");
    const second = await call("guardarAsistencia", {
      sessionId, expectedRevision: 2,
      entries: [{studentId: "student2", state: "late"}],
    }, "teacher");
    assert.equal(second.result.revision, 3);
    const closed = await call("cerrarSesionAsistencia", {
      sessionId, expectedRevision: 3,
    }, "teacher");
    assert.equal(closed.result.revision, 4);
    assert.equal((await db.collection("attendance_notification_events").get()).size, 1);
    status(await call("guardarAsistencia", {
      sessionId, expectedRevision: 4,
      entries: [{studentId: "student1", state: "excused", observation: "Excusa"}],
    }, "teacher"), "PERMISSION_DENIED");
    const correction = await call("guardarAsistencia", {
      sessionId, expectedRevision: 4,
      entries: [{studentId: "student1", state: "excused", observation: "Excusa"}],
    }, "admin");
    assert.equal(correction.result.revision, 5);
    const history = await db.collection("attendance_history")
        .where("action", "==", "records_corrected").get();
    assert.equal(history.size, 1);
    assert.equal((await db.collection("attendance_notification_events").get()).size, 2);
    const report = (await call("generarReporteAsistencia", {
      dateFrom: today(), dateTo: today(), groupId: "g1",
    }, "teacher")).result;
    assert.equal(report.sessionCount, 1);
    assert.equal(report.recordCount, 2);
    assert.equal(report.summary.excused, 1);
    assert.equal(report.summary.late, 1);
    status(await call("generarReporteAsistencia", {
      dateFrom: today(), dateTo: today(),
    }, "student1"), "PERMISSION_DENIED");
  });

  it("mantiene lectura independiente por estudiante e hijo activo", async () => {
    const sessionId = (await call("abrirSesionAsistencia", {
      groupId: "g1", date: today(),
    }, "admin")).result.sessionId;
    await call("guardarAsistencia", {
      sessionId, expectedRevision: 1,
      entries: [
        {studentId: "student1", state: "present"},
        {studentId: "student2", state: "absent"},
      ],
    }, "admin");
    assert.equal((await call("consultarMiAsistencia", {}, "student1")).result.records.length, 0);
    await call("cerrarSesionAsistencia", {
      sessionId, expectedRevision: 2,
    }, "admin");
    assert.equal((await call("consultarMiAsistencia", {}, "student1")).result.records.length, 1);
    assert.equal((await call("consultarMiAsistencia", {studentId: "student1"}, "family")).result.records[0].state, "present");
    status(await call("consultarMiAsistencia", {studentId: "student2"}, "family"), "PERMISSION_DENIED");
  });

  it("integra sesiones abiertas con traslado temporal y reversión", async () => {
    const sessionId = (await call("abrirSesionAsistencia", {
      groupId: "g1", subjectId: "subject1", date: today(),
    }, "teacher")).result.sessionId;
    const preview = await call("previsualizarTrasladoDocente", {
      sourceTeacherId: "teacher", targetTeacherId: "replacement",
    }, "admin");
    assert.equal(preview.result.impact.openAttendanceSessions, 1);
    const transfer = await call("ejecutarTrasladoDocente", {
      sourceTeacherId: "teacher", targetTeacherId: "replacement",
      mode: "temporary", allowMerge: true,
      endsAtMillis: Date.now() + 86400000,
    }, "admin");
    assert.equal((await db.collection("attendance_sessions").doc(sessionId).get()).data().responsibleTeacherId, "replacement");
    await call("revertirTrasladoDocenteTemporal", {id: transfer.result.id}, "admin");
    assert.equal((await db.collection("attendance_sessions").doc(sessionId).get()).data().responsibleTeacherId, "teacher");
  });

  it("rechaza fechas inexistentes y escrituras en años cerrados", async () => {
    status(await call("abrirSesionAsistencia", {groupId: "g1", date: "2026-02-31"}, "admin"), "INVALID_ARGUMENT");
    const sessionId = (await call("abrirSesionAsistencia", {groupId: "g1", date: today()}, "admin")).result.sessionId;
    await db.collection("academic_years").doc(yearId).update({status: "closed"});
    await seedAcademicYear(db, "i", "c", 2027);
    status(await call("guardarAsistencia", {
      sessionId, expectedRevision: 1,
      entries: [{studentId: "student1", state: "present"}],
    }, "admin"), "FAILED_PRECONDITION");
    status(await call("cerrarSesionAsistencia", {sessionId, expectedRevision: 1}, "admin"), "FAILED_PRECONDITION");
    assert.equal((await db.collection("attendance_records").get()).size, 0);
  });

  it("no confía solo en el contador para cerrar una lista incompleta", async () => {
    const sessionId = (await call("abrirSesionAsistencia", {groupId: "g1", date: today()}, "admin")).result.sessionId;
    await db.collection("attendance_sessions").doc(sessionId).update({markedCount: 2});
    status(await call("cerrarSesionAsistencia", {sessionId, expectedRevision: 1}, "admin"), "FAILED_PRECONDITION");
    assert.equal((await db.collection("attendance_sessions").doc(sessionId).get()).data().status, "open");
  });

  it("no trunca historial individual ni listas docentes al superar 250 registros", async () => {
    for (let offset = 0; offset < 260; offset += 200) {
      const batch = db.batch();
      for (let index = offset; index < Math.min(offset + 200, 260); index++) {
        const sessionId = `bulk_${index}`;
        const common = {institutionId: "i", campusId: "c", academicYearId: yearId,
          academicYear: 2026, groupId: "g1", groupName: "Quinto A", date: today()};
        batch.set(db.collection("attendance_sessions").doc(sessionId), {
          ...common, responsibleTeacherId: "teacher", status: "closed",
          studentIds: ["student1"], markedCount: 1,
        });
        batch.set(db.collection("attendance_records").doc(`${sessionId}_student1`), {
          ...common, sessionId, studentId: "student1", studentName: "Estudiante Uno", state: "present",
        });
      }
      await batch.commit();
    }
    assert.equal((await call("listarSesionesAsistencia", {}, "teacher")).result.sessions.length, 260);
    assert.equal((await call("consultarMiAsistencia", {}, "student1")).result.records.length, 260);
    const report = (await call("generarReporteAsistencia", {dateFrom: today(), dateTo: today(), groupId: "g1"}, "teacher")).result;
    assert.equal(report.recordCount, 260);
  });
});
/* eslint-enable max-len */
