"use strict";
/* eslint-env mocha */

const fs = require("fs");
const path = require("path");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {doc, getDoc, setDoc, updateDoc} = require("firebase/firestore");

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
        port: 8080,
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
      await setDoc(doc(db, "users/admin"), activeUser("Administrador"));
      await setDoc(doc(db, "users/superadmin"), activeUser("Administrador", {
        isSuperadmin: true,
      }));
      await setDoc(doc(db, "users/site-editor"), activeUser("Administrador", {
        permissions: ["sitio_web.ver", "sitio_web.editar"],
      }));
      await setDoc(doc(db, "users/student"), activeUser("Estudiante"));
      await setDoc(doc(db, "users/other"), activeUser("Estudiante", {
        institution: "inst-2",
        campus: "campus-2",
      }));
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

  it("limita al administrador a usuarios de su sede", async () => {
    const db = env.authenticatedContext("admin").firestore();
    await assertSucceeds(setDoc(
        doc(db, "users/new-local"),
        activeUser("Docente"),
    ));
    await assertFails(setDoc(
        doc(db, "users/new-foreign"),
        activeUser("Docente", {institution: "inst-2"}),
    ));
  });

  it("limita la prematricula publica", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertSucceeds(setDoc(doc(db, "enrollments/public-ok"), {
      createdByRole: "publico",
      estado: "prematriculado",
      data: {numeroIdentidad: "123456"},
    }));
    await assertFails(setDoc(doc(db, "enrollments/public-admin"), {
      createdByRole: "admin",
      estado: "matriculado",
      data: {numeroIdentidad: "123456"},
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
  });

  it("reserva la asignacion de permisos al superadministrador", async () => {
    const adminDb = env.authenticatedContext("admin").firestore();
    const superDb = env.authenticatedContext("superadmin").firestore();
    await assertFails(updateDoc(doc(adminDb, "users/student"), {
      permissions: ["sitio_web.editar"],
    }));
    await assertSucceeds(updateDoc(doc(superDb, "users/student"), {
      permissions: ["sitio_web.editar"],
    }));
  });
});
