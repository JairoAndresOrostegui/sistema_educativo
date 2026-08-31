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
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
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
        ],
      }));
      await setDoc(doc(db, "users/superadmin"), activeUser("Administrador", {
        isSuperadmin: true,
      }));
      await setDoc(doc(db, "users/site-editor"), activeUser("Administrador", {
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
        permissions: ["horarios.ver", "archivos.ver"],
      }));
      await setDoc(doc(db, "users/teacher"), activeUser("Docente", {
        groupId: "group-5a",
        groupName: "Quinto A",
        permissions: [
          "matricula.ver", "autorizaciones.ver", "horarios.ver",
          "archivos.ver",
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
          "archivos.ver",
        ],
      }));
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
    });
  });

  after(async () => env.cleanup());

  it("impide leer perfiles sin autenticacion", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, "users/student")));
  });

  it("permite actualizar solo campos propios seguros", async () => {
    const db = env.authenticatedContext("student").firestore();
    await assertSucceeds(getDoc(doc(db, "users/student")));
    await assertSucceeds(updateDoc(doc(db, "users/student"), {
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
    await assertSucceeds(getDoc(doc(teacherDb, "enrollments/grade-5a")));
    await assertFails(getDoc(doc(otherTeacherDb, "enrollments/grade-5a")));
    await assertSucceeds(getDoc(doc(familyDb, "enrollments/grade-5a")));
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
    const target = "authorization_requests/local-auth";
    await assertSucceeds(getDoc(doc(adminDb, target)));
    await assertSucceeds(getDoc(doc(teacherDb, target)));
    await assertSucceeds(getDoc(doc(familyDb, target)));
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
      schoolName: "Liceo Bilingüe Rodolfo R. Llinás",
    }));
    await assertFails(setDoc(doc(adminDb, "website_pages/about"), {
      label: "Ataque",
    }));
    await assertSucceeds(setDoc(doc(editorDb, "website_pages/about"), {
      label: "About",
      slug: "about",
      blocks: [],
    }));
  });

  it("mantiene publicas las paginas pero protege los formularios", async () => {
    const publicDb = env.unauthenticatedContext().firestore();
    const editorDb = env.authenticatedContext("site-editor").firestore();
    await assertSucceeds(getDoc(doc(publicDb, "website_pages/about")));
    await assertFails(setDoc(doc(publicDb, "website_submissions/spam"), {
      message: "contenido no validado",
    }));
    await assertSucceeds(getDoc(doc(editorDb, "website_submissions/example")));
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

  it("limita la edicion del perfil propio a campos seguros", async () => {
    const studentDb = env.authenticatedContext("student").firestore();
    await assertSucceeds(updateDoc(doc(studentDb, "users/student"), {
      photoUrl: "https://example.test/nueva.jpg",
    }));
    await assertFails(updateDoc(doc(studentDb, "users/student"), {
      address: "Direccion manipulada",
    }));
    await assertFails(updateDoc(doc(studentDb, "users/student"), {
      phones: ["3000000000"],
    }));
  });
});
