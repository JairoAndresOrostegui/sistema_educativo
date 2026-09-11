"use strict";
const fs = require("fs");
const path = require("path");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  collection,
  documentId,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} = require("firebase/firestore");

const projectId = "sistema-educativo-rules-test";
let env;

const activeUser = (role, extra = {}) => ({
  firstName: "Prueba",
  lastName: "Usuario",
  role,
  status: "activo",
  institution: "inst-1",
  campus: "campus-1",
  isSuperadmin: false,
  permissions: [],
  ...extra,
});

describe("Reglas Firestore", () => {
  before(async () => {
    env = await initializeTestEnvironment({
      projectId,
      firestore: {
        host: "127.0.0.1",
        port: 8180,
        rules: fs.readFileSync(
            path.resolve(__dirname, "../../firestore.rules"),
            "utf8",
        ),
      },
    });
    const authenticatedContext = env.authenticatedContext.bind(env);
    env.authenticatedContext = (uid, token = {}) =>
      authenticatedContext(uid, {email_verified: true, ...token});
  });

  beforeEach(async () => {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "users/admin"), activeUser("Administrador", {
        permissions: [
          "matricula.ver", "matricula.editar",
          "autorizaciones.ver", "autorizaciones.editar",
          "horarios.ver", "horarios.crear", "horarios.editar",
          "archivos.ver", "archivos.eliminar",
          "parametros.ver",
          "mensajeria.ver",
          "historial.ver",
        ],
      }));
      await setDoc(doc(db, "users/superadmin"), activeUser("Administrador", {
        isSuperadmin: true,
      }));
      await setDoc(doc(db, "users/site-editor"), activeUser("Administrador", {
        permissions: ["sitio_web.ver", "sitio_web.editar"],
      }));
      await setDoc(doc(db, "users/site-editor-foreign"),
          activeUser("Administrador", {
            institution: "inst-2",
            campus: "campus-2",
            permissions: ["sitio_web.ver", "sitio_web.editar"],
          }));
      await setDoc(doc(db, "users/admin-no-enrollment"), activeUser(
          "Administrador",
      ));
      await setDoc(doc(db, "users/user-manager"), activeUser("Docente", {
        permissions: ["usuarios.ver"],
      }));
      await setDoc(doc(db, "users/student"), activeUser("Estudiante", {
        groupId: "group-5a",
        groupName: "Quinto A",
        permissions: ["horarios.ver", "archivos.ver", "mensajeria.ver"],
      }));
      await setDoc(doc(db, "users/teacher"), activeUser("Docente", {
        groupId: "group-5a",
        groupName: "Quinto A",
        permissions: [
          "matricula.ver", "autorizaciones.ver", "horarios.ver",
          "archivos.ver", "mensajeria.ver",
        ],
      }));
      await setDoc(doc(db, "users/teacher-other"), activeUser("Docente", {
        groupId: "group-6a",
        groupName: "Sexto A",
        permissions: ["matricula.ver"],
      }));
      await setDoc(doc(db, "users/family"), activeUser("Familiar", {
        studentIds: ["student"],
        activeStudentId: "student",
        permissions: [
          "matricula.ver", "autorizaciones.ver", "horarios.ver",
          "archivos.ver", "mensajeria.ver",
        ],
      }));
      await setDoc(doc(db, "users/family-other-active"), activeUser(
          "Familiar", {
            studentIds: ["student", "peer"], activeStudentId: "peer",
            permissions: ["matricula.ver"],
          },
      ));
      await setDoc(doc(db, "users/family-no-enrollment"), activeUser(
          "Familiar", {
            studentIds: ["student"], activeStudentId: "student",
          },
      ));
      await setDoc(doc(db, "users/peer"), activeUser("Estudiante"));
      await setDoc(doc(db, "users/removed"), activeUser("Estudiante", {
        status: "eliminado",
        administrativeRemoval: true,
      }));
      await setDoc(doc(db, "users/other"), activeUser("Estudiante", {
        institution: "inst-2",
        campus: "campus-2",
      }));
      await setDoc(doc(db, "academic_years/year-local"), {
        institutionId: "inst-1", campusId: "campus-1",
        year: 2026, status: "active",
      });
      await setDoc(doc(db, "academic_years/year-foreign"), {
        institutionId: "inst-2", campusId: "campus-2",
        year: 2026, status: "active",
      });
      await setDoc(doc(db, "parameters/document-type"), {
        clave: "documentType", etiqueta: "Cedula", valor: "CC",
        orden: 1, activo: true,
      });
      await setDoc(doc(db, "website_submissions/example"), {
        institutionId: "inst-1",
        campusId: "campus-1",
        pageId: "contact",
        name: "Familia de prueba",
        email: "familia@example.test",
        phone: "3000000000",
        message: "Solicitud de información",
        status: "new",
      });
      await setDoc(doc(db, "enrollments/local"), {
        institution: "inst-1",
        campus: "campus-1",
        academicYearId: "year-local", academicYear: 2026,
        estado: "prematriculado",
        data: {groupId: "group-5a", groupName: "Quinto A"},
      });
      await setDoc(doc(db, "enrollments/foreign"), {
        institution: "inst-2",
        campus: "campus-2",
        academicYearId: "year-foreign", academicYear: 2026,
        estado: "prematriculado",
        data: {groupId: "group-5a", groupName: "Quinto A"},
      });
      await setDoc(doc(db, "enrollment_notification_events/local-event"), {
        institution: "inst-1",
        campus: "campus-1",
        enrollmentId: "local",
      });
      await setDoc(doc(db, "authorization_requests/local-auth"), {
        institutionId: "inst-1",
        campusId: "campus-1",
        academicYearId: "year-local", academicYear: 2026,
        studentId: "student",
        requesterId: "family",
        groupId: "group-5a",
        groupName: "Quinto A",
        status: "pending",
      });
      await setDoc(doc(db, "subjects/grade-5a"), {
        institutionId: "inst-1",
        campusId: "campus-1",
        academicYearId: "year-local", academicYear: 2026,
        subject: "Matematicas",
        teacherId: "teacher",
        teacherName: "Prueba Usuario",
        groupId: "group-5a",
        groupName: "Quinto A",
        day: "lunes",
      });
      await setDoc(doc(db, "subjects/grade-6a"), {
        institutionId: "inst-1",
        campusId: "campus-1",
        academicYearId: "year-local", academicYear: 2026,
        subject: "Ciencias",
        teacherId: "teacher-other",
        teacherName: "Prueba Usuario",
        groupId: "group-6a",
        groupName: "Sexto A",
        day: "lunes",
      });
      await setDoc(doc(db, "schedule_notification_events/local-event"), {
        institutionId: "inst-1",
        campusId: "campus-1",
        subjectId: "grade-5a",
      });
      await setDoc(doc(db, "schedule_history/local-history"), {
        institutionId: "inst-1",
        campusId: "campus-1",
        subjectId: "grade-5a",
        action: "create_subject",
      });
      await setDoc(doc(db, "schedule_history/foreign-history"), {
        institutionId: "inst-2",
        campusId: "campus-2",
        subjectId: "foreign",
        action: "create_subject",
      });
      await setDoc(doc(db, "user_logs/local"), {
        institution: "inst-1",
        campus: "campus-1",
        academicYearId: "year-local", academicYear: 2026,
        userId: "student",
      });
      await setDoc(doc(db, "user_logs/foreign"), {
        institution: "inst-2",
        campus: "campus-2",
        userId: "other",
      });
      for (const collectionName of [
        "user_history", "route_history", "file_history",
      ]) {
        await setDoc(doc(db, `${collectionName}/local`), {
          institution: "inst-1",
          campus: "campus-1",
          institutionId: "inst-1",
          campusId: "campus-1",
          action: "test",
        });
        await setDoc(doc(db, `${collectionName}/foreign`), {
          institution: "inst-2",
          campus: "campus-2",
          institutionId: "inst-2",
          campusId: "campus-2",
          action: "test",
        });
      }
      await setDoc(doc(db, "daily_routes/history-local"), {
        institution: "inst-1",
        campus: "campus-1",
        gestionador: "teacher",
        estado: "finalizada",
      });
      await setDoc(doc(db, "daily_routes/history-local/students/student"), {
        institution: "inst-1",
        campus: "campus-1",
        nombre: "Estudiante",
      });
      await setDoc(doc(db, "daily_routes/history-foreign"), {
        institution: "inst-2",
        campus: "campus-2",
        gestionador: "teacher",
        estado: "finalizada",
      });
      await setDoc(doc(db, "files/publication"), {
        institutionId: "inst-1",
        campusId: "campus-1",
        academicYearId: "year-local",
        academicYear: 2026,
        status: "active",
        audienceType: "groups",
        targetGroupIds: ["group-5a"],
        targetStudentIds: ["student"],
        recipientUserIds: ["teacher", "student", "family"],
        recipientContextKeys: ["family:student"],
      });
      await setDoc(doc(db, "message_channels/group-5a"), {
        institutionId: "inst-1", campusId: "campus-1",
        academicYearId: "year-local", academicYear: 2026,
        channelType: "academic_group", status: "active",
        memberUserIds: ["admin", "teacher", "student", "family"],
        messageSequence: 1,
      });
      await setDoc(doc(
          db, "message_channels/group-5a/messages/message-1",
      ), {
        senderId: "teacher", senderName: "Prueba Usuario",
        senderRole: "Docente", sequence: 1, body: "Evaluacion el viernes",
      });
      await setDoc(doc(db, "message_channels/private-student-teacher"), {
        institutionId: "inst-1", campusId: "campus-1",
        academicYearId: "year-local", academicYear: 2026,
        channelType: "supervised_student", status: "active",
        memberUserIds: ["teacher", "student", "family"],
        messageSequence: 1,
      });
    });
  });

  after(async () => env.cleanup());

  it("impide fabricar QR o consultar credenciales directamente", async () => {
    const student = env.authenticatedContext("student").firestore();
    await assertFails(updateDoc(doc(student, "users/student"), {
      qrPayload: "inventado", qrEnabled: true,
    }));
    for (const uid of ["student", "admin", "superadmin"]) {
      const db = env.authenticatedContext(uid).firestore();
      for (const name of ["qr_credentials", "qr_audit", "events"]) {
        await assertFails(setDoc(doc(db, name, "fake"), {status: "active"}));
        await assertFails(getDocs(collection(db, name)));
      }
    }
  });

  it("impide leer perfiles sin autenticacion", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, "users/student")));
  });

  it("envia toda actualizacion del perfil propio al backend", async () => {
    const db = env.authenticatedContext("student").firestore();
    await assertSucceeds(getDoc(doc(db, "users/student")));
    await assertFails(updateDoc(doc(db, "users/student"), {
      photoUrl: "https://example.test/photo.jpg",
    }));
    await assertFails(updateDoc(doc(db, "users/student"), {
      role: "Administrador",
    }));
  });

  it("separa perfiles de instituciones distintas", async () => {
    const db = env.authenticatedContext("student").firestore();
    await assertFails(getDoc(doc(db, "users/other")));
  });

  it("solo expone perfiles ajenos a gestores autorizados", async () => {
    const studentDb = env.authenticatedContext("student").firestore();
    const managerDb = env.authenticatedContext("user-manager").firestore();
    await assertFails(getDoc(doc(studentDb, "users/peer")));
    await assertSucceeds(getDoc(doc(managerDb, "users/peer")));
  });

  it("exige correo verificado a adultos pero no a estudiantes", async () => {
    const adult = env.authenticatedContext("teacher", {email_verified: false})
        .firestore();
    const student = env.authenticatedContext("student", {email_verified: false})
        .firestore();
    await assertFails(getDocs(collection(adult, "parameters")));
    await assertSucceeds(getDocs(collection(student, "parameters")));
    await assertSucceeds(getDoc(doc(adult, "users/teacher")));
  });

  it("consulta hijos activos de Autorizaciones con alcance", async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "user_directory/student"),
          activeUser("Estudiante", {groupId: "group-5a"}));
      await setDoc(doc(context.firestore(), "user_directory/removed"),
          activeUser("Estudiante", {status: "eliminado"}));
    });
    const db = env.authenticatedContext("family").firestore();
    const base = [
      where(documentId(), "in", ["student"]),
      where("institution", "==", "inst-1"),
      where("campus", "==", "campus-1"),
    ];
    // Los IDs exactos permiten evaluar candidatos. No atribuir el error de
    // permisos reportado a una falta de índice ni a esta consulta por sí sola.
    await assertSucceeds(getDocs(query(
        collection(db, "user_directory"), ...base)));
    await assertSucceeds(getDocs(query(collection(db, "user_directory"),
        ...base, where("status", "==", "activo"),
        where("role", "==", "Estudiante"))));
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "user_directory/foreign-child"),
          activeUser("Estudiante", {
            institution: "inst-2", campus: "campus-2",
          }));
    });
    await assertFails(getDocs(query(collection(db, "user_directory"),
        where(documentId(), "in", ["foreign-child"]),
        where("institution", "==", "inst-2"),
        where("campus", "==", "campus-2"),
        where("status", "==", "activo"))));
  });

  it("oculta bajas administrativas salvo al superadministrador", async () => {
    const managerDb = env.authenticatedContext("user-manager").firestore();
    const superDb = env.authenticatedContext("superadmin").firestore();
    await assertFails(getDoc(doc(managerDb, "users/removed")));
    await assertSucceeds(getDoc(doc(superDb, "users/removed")));
    await assertSucceeds(getDocs(query(
        collection(managerDb, "users"),
        where("institution", "==", "inst-1"),
        where("campus", "==", "campus-1"),
        where("status", "in", ["activo", "inactivo"]),
    )));
    await assertFails(getDocs(collection(managerDb, "users")));
  });

  it("impide eliminaciones directas incluso al superadmin", async () => {
    const adminDb = env.authenticatedContext("admin").firestore();
    const superDb = env.authenticatedContext("superadmin").firestore();
    await assertFails(deleteDoc(doc(adminDb, "users/peer")));
    await assertFails(deleteDoc(doc(superDb, "users/peer")));
  });

  it("protege archivos y obliga a listar mediante Functions", async () => {
    const familyDb = env.authenticatedContext("family").firestore();
    const teacherDb = env.authenticatedContext("teacher").firestore();
    const otherDb = env.authenticatedContext("teacher-other").firestore();
    await assertFails(getDocs(query(
        collection(familyDb, "files"),
        where("institutionId", "==", "inst-1"),
        where("campusId", "==", "campus-1"),
        where("recipientContextKeys", "array-contains", "family:student"),
        where("status", "==", "active"),
    )));
    await assertSucceeds(getDoc(doc(familyDb, "files/publication")));
    await assertSucceeds(getDoc(doc(teacherDb, "files/publication")));
    await assertFails(getDoc(doc(otherDb, "files/publication")));
    await assertFails(deleteDoc(doc(
        teacherDb, "files/publication",
    )));
  });

  it("revoca archivos del familiar al perder vigencia o vinculo del hijo",
      async () => {
        const familyDb = env.authenticatedContext("family").firestore();
        const publication = doc(familyDb, "files/publication");
        await assertSucceeds(getDoc(publication));
        for (const changes of [
          {status: "inactivo"},
          {status: "activo", campus: "campus-2"},
          {campus: "campus-1", role: "Docente"},
        ]) {
          await env.withSecurityRulesDisabled(async (context) => {
            await updateDoc(doc(context.firestore(), "users/student"), changes);
          });
          await assertFails(getDoc(publication));
        }
        await env.withSecurityRulesDisabled(async (context) => {
          await updateDoc(doc(context.firestore(), "users/student"), {
            role: "Estudiante",
          });
          await updateDoc(doc(context.firestore(), "users/family"), {
            studentIds: [],
          });
        });
        await assertFails(getDoc(publication));
      });

  it("protege canales, mensajes y membresia desde backend", async () => {
    const studentDb = env.authenticatedContext("student").firestore();
    const teacherDb = env.authenticatedContext("teacher").firestore();
    const outsiderDb = env.authenticatedContext("teacher-other").firestore();
    const adminDb = env.authenticatedContext("admin").firestore();
    const superDb = env.authenticatedContext("superadmin").firestore();
    await assertSucceeds(getDoc(doc(
        studentDb, "message_channels/group-5a",
    )));
    await assertSucceeds(getDoc(doc(
        teacherDb, "message_channels/group-5a/messages/message-1",
    )));
    await assertFails(getDoc(doc(
        outsiderDb, "message_channels/group-5a",
    )));
    await assertSucceeds(getDoc(doc(
        adminDb, "message_channels/group-5a",
    )));
    await assertFails(getDoc(doc(
        adminDb, "message_channels/private-student-teacher",
    )));
    await assertSucceeds(getDoc(doc(
        superDb, "message_channels/private-student-teacher",
    )));
    await assertFails(setDoc(doc(
        studentDb, "message_channels/group-5a/messages/forged",
    ), {senderId: "student", sequence: 2, body: "sin validar"}));
    await assertFails(updateDoc(doc(
        teacherDb, "message_channels/group-5a",
    ), {mutedByAdmin: true}));
  });

  it("obliga a crear usuarios mediante Cloud Functions", async () => {
    const db = env.authenticatedContext("admin").firestore();
    await assertFails(setDoc(
        doc(db, "users/new-local"),
        activeUser("Docente"),
    ));
    await assertFails(setDoc(
        doc(db, "users/new-foreign"),
        activeUser("Docente", {institution: "inst-2"}),
    ));
  });

  it("obliga a crear matriculas mediante Cloud Functions", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(setDoc(doc(db, "enrollments/public-ok"), {
      createdByRole: "publico",
      estado: "prematriculado",
      institution: "inst-1",
      campus: "campus-1",
      data: {numeroIdentidad: "123456"},
    }));
    await assertFails(setDoc(doc(db, "enrollments/public-admin"), {
      createdByRole: "admin",
      estado: "matriculado",
      data: {numeroIdentidad: "123456"},
    }));
  });

  it("aísla matrículas y logs por sede salvo para superadmin", async () => {
    const adminDb = env.authenticatedContext("admin").firestore();
    const superDb = env.authenticatedContext("superadmin").firestore();
    await assertSucceeds(getDoc(doc(adminDb, "enrollments/local")));
    await assertFails(getDoc(doc(adminDb, "enrollments/foreign")));
    await assertSucceeds(getDoc(doc(superDb, "enrollments/foreign")));
    await assertSucceeds(getDoc(doc(adminDb, "user_logs/local")));
    await assertFails(getDoc(doc(adminDb, "user_logs/foreign")));
    await assertSucceeds(getDoc(doc(superDb, "user_logs/foreign")));
  });

  it("limita al docente por grupo y al familiar por vinculo", async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "enrollments/grade-5a"), {
        institution: "inst-1",
        campus: "campus-1",
        academicYearId: "year-local", academicYear: 2026,
        estado: "prematriculado",
        createdByUserId: "another-family",
        vinculaUsuarioId: "student",
        data: {groupId: "group-5a", groupName: "Quinto A"},
      });
    });
    const teacherDb = env.authenticatedContext("teacher").firestore();
    const otherTeacherDb = env.authenticatedContext("teacher-other")
        .firestore();
    const familyDb = env.authenticatedContext("family").firestore();
    const otherActiveFamilyDb = env
        .authenticatedContext("family-other-active").firestore();
    await assertSucceeds(getDoc(doc(teacherDb, "enrollments/grade-5a")));
    await assertFails(getDoc(doc(otherTeacherDb, "enrollments/grade-5a")));
    await assertSucceeds(getDoc(doc(familyDb, "enrollments/grade-5a")));
    await assertFails(getDoc(doc(
        otherActiveFamilyDb, "enrollments/grade-5a",
    )));
    await assertFails(updateDoc(doc(teacherDb, "enrollments/grade-5a"), {
      estado: "matriculado",
    }));
  });

  it("exige permiso para leer matriculas y sus eventos", async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "enrollments/family-linked"), {
        institution: "inst-1",
        campus: "campus-1",
        academicYearId: "year-local", academicYear: 2026,
        estado: "prematriculado",
        vinculaUsuarioId: "student",
        data: {groupId: "group-5a", groupName: "Quinto A"},
      });
    });
    const familyDb = env.authenticatedContext("family-no-enrollment")
        .firestore();
    const adminDb = env.authenticatedContext("admin-no-enrollment")
        .firestore();
    await assertFails(getDoc(doc(familyDb, "enrollments/family-linked")));
    await assertFails(getDoc(doc(
        adminDb, "enrollment_notification_events/local-event",
    )));
  });

  it("protege autorizaciones por rol y obliga a usar Functions", async () => {
    const adminDb = env.authenticatedContext("admin").firestore();
    const teacherDb = env.authenticatedContext("teacher").firestore();
    const familyDb = env.authenticatedContext("family").firestore();
    const studentDb = env.authenticatedContext("student").firestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), "users/family-other-active"), {
        permissions: ["autorizaciones.ver"],
      });
    });
    const otherActiveChildDb = env
        .authenticatedContext("family-other-active").firestore();
    const target = "authorization_requests/local-auth";
    await assertSucceeds(getDoc(doc(adminDb, target)));
    await assertSucceeds(getDoc(doc(teacherDb, target)));
    await assertSucceeds(getDoc(doc(familyDb, target)));
    await assertFails(getDoc(doc(otherActiveChildDb, target)));
    await assertFails(getDoc(doc(studentDb, target)));
    await assertFails(updateDoc(doc(adminDb, target), {status: "approved"}));
    await assertFails(setDoc(doc(familyDb, "authorization_requests/forged"), {
      institutionId: "inst-1",
      campusId: "campus-1",
      studentId: "student",
      requesterId: "family",
      groupId: "group-5a",
      groupName: "Quinto A",
      status: "pending",
    }));
  });

  it("revoca autorizaciones y matriculas de hijos retirados", async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "enrollments/family-linked"), {
        institution: "inst-1", campus: "campus-1",
        academicYearId: "year-local", academicYear: 2026,
        vinculaUsuarioId: "student", data: {groupId: "group-5a"},
      });
    });
    const db = env.authenticatedContext("family").firestore();
    const targets = ["authorization_requests/local-auth",
      "enrollments/family-linked"];
    for (const target of targets) {
      await assertSucceeds(getDoc(doc(db, target)));
    }
    for (const change of [
      {status: "inactivo"},
      {status: "activo", campus: "campus-2"},
      {campus: "campus-1", role: "Docente"},
    ]) {
      await env.withSecurityRulesDisabled(async (context) => {
        await updateDoc(doc(context.firestore(), "users/student"), change);
      });
      for (const target of targets) {
        await assertFails(getDoc(doc(db, target)));
      }
    }
  });

  it("limita horarios por rol, grupo e hijo activo", async () => {
    const adminDb = env.authenticatedContext("admin").firestore();
    const teacherDb = env.authenticatedContext("teacher").firestore();
    const familyDb = env.authenticatedContext("family").firestore();
    const studentDb = env.authenticatedContext("student").firestore();
    await assertSucceeds(getDoc(doc(adminDb, "subjects/grade-6a")));
    await assertSucceeds(getDoc(doc(teacherDb, "subjects/grade-5a")));
    await assertFails(getDoc(doc(teacherDb, "subjects/grade-6a")));
    await assertSucceeds(getDoc(doc(studentDb, "subjects/grade-5a")));
    await assertFails(getDoc(doc(studentDb, "subjects/grade-6a")));
    await assertSucceeds(getDoc(doc(familyDb, "subjects/grade-5a")));
    await assertFails(getDoc(doc(familyDb, "subjects/grade-6a")));
    await assertFails(setDoc(doc(adminDb, "subjects/forged"), {
      institutionId: "inst-1",
      campusId: "campus-1",
      groupId: "group-5a",
      groupName: "Quinto A",
      day: "lunes",
    }));
    await assertFails(updateDoc(doc(adminDb, "subjects/grade-5a"), {
      teacherId: "teacher-other",
    }));
    await assertFails(deleteDoc(doc(adminDb, "subjects/grade-5a")));
    await assertSucceeds(getDoc(doc(
        adminDb, "schedule_notification_events/local-event",
    )));
    const noPermissionDb = env.authenticatedContext(
        "admin-no-enrollment",
    ).firestore();
    await assertFails(getDoc(doc(
        noPermissionDb, "schedule_notification_events/local-event",
    )));
    await assertSucceeds(getDocs(query(
        collection(adminDb, "schedule_history"),
        where("institutionId", "==", "inst-1"),
        where("campusId", "==", "campus-1"),
    )));
    await assertFails(getDocs(collection(adminDb, "schedule_history")));
  });

  it("impide que el cliente falsifique registros de auditoría", async () => {
    const adminDb = env.authenticatedContext("admin").firestore();
    await assertFails(setDoc(doc(adminDb, "user_history/forged"), {
      institution: "inst-1",
      campus: "campus-1",
      accion: "falsa",
    }));
  });

  it("exige permiso de historial para consultar auditorías", async () => {
    const withoutHistory = env.authenticatedContext("admin-no-enrollment")
        .firestore();
    const withHistory = env.authenticatedContext("admin").firestore();
    await assertFails(getDoc(doc(withoutHistory, "user_logs/local")));
    await assertSucceeds(getDoc(doc(withHistory, "user_logs/local")));
    for (const collectionName of [
      "user_history", "route_history", "file_history",
    ]) {
      await assertFails(getDoc(doc(withoutHistory, `${collectionName}/local`)));
      await assertSucceeds(getDoc(doc(withHistory, `${collectionName}/local`)));
      await assertFails(getDoc(doc(withHistory, `${collectionName}/foreign`)));
    }
    await assertFails(getDoc(doc(
        withoutHistory, "daily_routes/history-local",
    )));
    await assertSucceeds(getDoc(doc(
        withHistory, "daily_routes/history-local",
    )));
    await assertSucceeds(getDoc(doc(
        withHistory, "daily_routes/history-local/students/student",
    )));
    await assertFails(getDoc(doc(
        withHistory, "daily_routes/history-foreign",
    )));
  });

  it("mantiene parametros autenticados e inmutables", async () => {
    const publicDb = env.unauthenticatedContext().firestore();
    const adminDb = env.authenticatedContext("admin").firestore();
    const superDb = env.authenticatedContext("superadmin").firestore();
    const target = "parameters/document-type";
    await assertFails(getDoc(doc(publicDb, target)));
    await assertSucceeds(getDoc(doc(adminDb, target)));
    await assertFails(updateDoc(doc(adminDb, target), {valor: "Ataque"}));
    await assertFails(deleteDoc(doc(superDb, target)));
    await assertFails(setDoc(doc(superDb, "parameters/forged"), {
      clave: "permission", valor: "usuarios.eliminar", activo: true,
    }));
  });

  it("permite leer el sitio publico pero no modificarlo " +
    "sin sesion", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertSucceeds(getDoc(doc(db, "website/main")));
    await assertFails(setDoc(doc(db, "website/main"), {schoolName: "Ataque"}));
  });

  it("solo permite editar el sitio con el permiso " +
    "correspondiente", async () => {
    const adminDb = env.authenticatedContext("admin").firestore();
    const editorDb = env.authenticatedContext("site-editor").firestore();
    await assertFails(setDoc(doc(adminDb, "website/main"), {schoolName: "No"}));
    await assertSucceeds(setDoc(doc(editorDb, "website/main"), {
      institutionId: "inst-1",
      campusId: "campus-1",
      schoolName: "Liceo Bilingüe Rodolfo R. Llinás",
    }));
    await assertSucceeds(setDoc(doc(editorDb, "website/config"), {
      institutionId: "inst-1",
      campusId: "campus-1",
      revision: 1,
      schoolName: "Colegio",
    }));
    await assertFails(setDoc(doc(adminDb, "website_pages/about"), {
      label: "Ataque",
    }));
    const publication = writeBatch(editorDb);
    publication.update(doc(editorDb, "website/config"), {revision: 2});
    publication.set(doc(editorDb, "website_pages/about"), {
      institutionId: "inst-1",
      campusId: "campus-1",
      publicationRevision: 2,
      label: "About",
      slug: "about",
      rows: [],
    });
    await assertSucceeds(publication.commit());
    await assertFails(updateDoc(doc(editorDb, "website_pages/about"), {
      label: "Cambio fuera de publicación",
    }));
    const foreignDb = env.authenticatedContext("site-editor-foreign")
        .firestore();
    await assertFails(updateDoc(doc(foreignDb, "website/main"), {
      schoolName: "Secuestro entre instituciones",
    }));
    await assertFails(deleteDoc(doc(foreignDb, "website_pages/about")));
  });

  it("mantiene publicas las paginas pero protege los formularios", async () => {
    const publicDb = env.unauthenticatedContext().firestore();
    const editorDb = env.authenticatedContext("site-editor").firestore();
    const foreignDb = env.authenticatedContext("site-editor-foreign")
        .firestore();
    await assertSucceeds(getDoc(doc(publicDb, "website_pages/about")));
    await assertFails(setDoc(doc(publicDb, "website_submissions/spam"), {
      message: "contenido no validado",
    }));
    await assertSucceeds(getDoc(doc(editorDb, "website_submissions/example")));
    await assertFails(getDoc(doc(foreignDb, "website_submissions/example")));
    await assertSucceeds(updateDoc(
        doc(editorDb, "website_submissions/example"), {status: "read"}));
    await assertFails(updateDoc(
        doc(editorDb, "website_submissions/example"), {status: "archived"}));
    await assertFails(updateDoc(
        doc(editorDb, "website_submissions/example"), {
          message: "Contenido alterado",
        }));
    await assertFails(deleteDoc(
        doc(env.authenticatedContext("admin").firestore(),
            "website_submissions/example")));
    await assertSucceeds(deleteDoc(
        doc(editorDb, "website_submissions/example")));
  });

  it("obliga a editar usuarios mediante Cloud Functions", async () => {
    const adminDb = env.authenticatedContext("admin").firestore();
    const superDb = env.authenticatedContext("superadmin").firestore();
    await assertFails(updateDoc(doc(adminDb, "users/student"), {
      permissions: ["sitio_web.editar"],
    }));
    await assertFails(updateDoc(doc(adminDb, "users/student"), {
      permissions: ["autorizaciones.ver", "autorizaciones.editar"],
    }));
    await assertFails(updateDoc(doc(superDb, "users/student"), {
      permissions: ["sitio_web.editar"],
    }));
  });

  it("bloquea la edicion directa del perfil propio", async () => {
    const studentDb = env.authenticatedContext("student").firestore();
    await assertFails(updateDoc(doc(studentDb, "users/student"), {
      photoUrl: "https://example.test/nueva.jpg",
    }));
    await assertFails(updateDoc(doc(studentDb, "users/student"), {
      address: "Direccion manipulada",
    }));
    await assertFails(updateDoc(doc(studentDb, "users/student"), {
      phones: ["3000000000"],
    }));
  });

  it("obliga a operar asistencia mediante Cloud Functions", async () => {
    for (const uid of ["admin", "teacher", "student", "family", "superadmin"]) {
      const clientDb = env.authenticatedContext(uid).firestore();
      for (const collectionName of [
        "attendance_sessions",
        "attendance_records",
        "attendance_history",
        "attendance_notification_events",
      ]) {
        await assertFails(getDoc(doc(clientDb, collectionName, "example")));
        await assertFails(setDoc(doc(clientDb, collectionName, "forged"), {
          institutionId: "inst-1",
          campusId: "campus-1",
        }));
      }
    }
  });

  it("obliga a operar eventos mediante Cloud Functions", async () => {
    for (const uid of ["admin", "teacher", "student", "family", "superadmin"]) {
      const clientDb = env.authenticatedContext(uid).firestore();
      for (const collectionName of [
        "school_events",
        "event_responses",
        "event_attendance",
        "event_history",
        "event_notification_events",
      ]) {
        await assertFails(getDoc(doc(clientDb, collectionName, "example")));
        await assertFails(setDoc(doc(clientDb, collectionName, "forged"), {
          institutionId: "inst-1",
          campusId: "campus-1",
        }));
      }
    }
  });

  it("una clave temporal solo permite leer el perfil propio", async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "users/temporary-student"),
          activeUser("Estudiante", {
            groupId: "group-5a", mustChangePassword: true,
          }));
    });
    const temporaryDb = env.authenticatedContext("temporary-student")
        .firestore();
    await assertSucceeds(getDoc(doc(temporaryDb, "users/temporary-student")));
    await assertFails(getDoc(doc(temporaryDb, "academic_groups/group-5a")));
    await assertFails(updateDoc(doc(temporaryDb, "users/temporary-student"), {
      photoUrl: "https://example.test/blocked.jpg",
    }));
  });
});
