"use strict";
const fs = require("fs");
const path = require("path");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {doc, setDoc} = require("firebase/firestore");

const projectId = "sistema-educativo-rl";
let env;

const activeUser = (extra = {}) => ({
  role: "Administrador",
  status: "activo",
  institution: "inst-1",
  campus: "campus-1",
  isSuperadmin: false,
  permissions: [],
  ...extra,
});

describe("Reglas Storage del sitio web", () => {
  before(async () => {
    env = await initializeTestEnvironment({
      projectId,
      firestore: {host: "127.0.0.1", port: 8180},
      storage: {
        host: "127.0.0.1",
        port: 9299,
        rules: fs.readFileSync(
            path.resolve(__dirname, "../../storage.rules"),
            "utf8",
        ),
      },
    });
  });

  beforeEach(async () => {
    await env.clearFirestore();
    await env.clearStorage();
    await env.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "users/superadmin"), activeUser({
        isSuperadmin: true,
      }));
      await setDoc(doc(db, "users/editor"), activeUser({
        permissions: ["sitio_web.editar"],
      }));
      await setDoc(doc(db, "users/admin"), activeUser());
      await setDoc(doc(db, "users/teacher"), activeUser({
        role: "Docente",
        audienceType: "groups",
        targetGroupIds: ["group-5a"],
        targetStudentIds: ["student"],
        recipientUserIds: ["teacher", "student", "family"],
        recipientContextKeys: ["family:student"],
        permissions: ["archivos.ver", "archivos.crear"],
      }));
      await setDoc(doc(db, "users/student"), activeUser({
        role: "Estudiante",
        groupId: "group-5a",
        permissions: ["archivos.ver"],
      }));
      await setDoc(doc(db, "users/student-other"), activeUser({
        role: "Estudiante",
        groupId: "group-6a",
        permissions: ["archivos.ver"],
      }));
      await setDoc(doc(db, "users/family"), activeUser({
        role: "Familiar",
        studentIds: ["student"],
        activeStudentId: "student",
        permissions: ["archivos.ver"],
      }));
    });
  });

  after(async () => env.cleanup());

  const upload = (userId, name, contentType) => {
    const storage = env.authenticatedContext(userId).storage(
        `gs://${projectId}.firebasestorage.app`,
    );
    return storage.ref(`website/${name}`).put(
        Buffer.from("imagen de prueba"),
        {contentType},
    );
  };

  it("permite PNG y JPEG a un superadministrador", async () => {
    await assertSucceeds(upload("superadmin", "imagen.png", "image/png"));
    await assertSucceeds(upload("superadmin", "imagen.jpeg", "image/jpeg"));
  });

  it("permite JPEG al usuario con sitio_web.editar", async () => {
    await assertSucceeds(upload("editor", "banner.jpeg", "image/jpeg"));
  });

  it("rechaza la carga a quien no administra el sitio", async () => {
    await assertFails(upload("admin", "rechazado.png", "image/png"));
  });

  it("solo carga con reserva exacta y metadatos correctos", async () => {
    const bytes = Buffer.from("archivo de prueba");
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "files/file-1"), {
        institutionId: "inst-1",
        campusId: "campus-1",
        groupId: "group-5a",
        status: "uploading",
        uploadedBy: "teacher",
        expectedSize: bytes.length,
        contentType: "application/pdf",
        storagePath: "files/file-1/guia.pdf",
      });
    });
    const storage = env.authenticatedContext("teacher").storage(
        `gs://${projectId}.firebasestorage.app`,
    );
    await assertSucceeds(storage.ref("files/file-1/guia.pdf").put(
        bytes,
        {
          contentType: "application/pdf",
          customMetadata: {
            fileId: "file-1",
            uploadedBy: "teacher",
          },
        },
    ));
    await assertFails(storage.ref("files/file-1/otro.pdf").put(
        bytes,
        {contentType: "application/pdf"},
    ));
  });

  it("aísla las descargas por grupo e hijo activo", async () => {
    const bytes = Buffer.from("archivo de prueba");
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "files/file-2"), {
        institutionId: "inst-1",
        campusId: "campus-1",
        audienceType: "groups",
        targetGroupIds: ["group-5a"],
        targetStudentIds: ["student"],
        recipientUserIds: ["teacher", "student", "family"],
        recipientContextKeys: ["family:student"],
        status: "uploading",
        uploadedBy: "teacher",
        expectedSize: bytes.length,
        contentType: "application/pdf",
        storagePath: "files/file-2/guia.pdf",
      });
    });
    const teacherStorage = env.authenticatedContext("teacher").storage(
        `gs://${projectId}.firebasestorage.app`,
    );
    const reference = teacherStorage.ref("files/file-2/guia.pdf");
    await reference.put(bytes, {
      contentType: "application/pdf",
      customMetadata: {
        fileId: "file-2",
        uploadedBy: "teacher",
      },
    });
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "files/file-2"), {
        status: "active",
      }, {merge: true});
    });
    const studentRef = env.authenticatedContext("student").storage(
        `gs://${projectId}.firebasestorage.app`,
    ).ref(reference.fullPath);
    const familyRef = env.authenticatedContext("family").storage(
        `gs://${projectId}.firebasestorage.app`,
    ).ref(reference.fullPath);
    const otherRef = env.authenticatedContext("student-other").storage(
        `gs://${projectId}.firebasestorage.app`,
    ).ref(reference.fullPath);
    await assertSucceeds(studentRef.getMetadata());
    await assertSucceeds(familyRef.getMetadata());
    await assertFails(otherRef.getMetadata());
    await assertFails(reference.delete());
  });
});
