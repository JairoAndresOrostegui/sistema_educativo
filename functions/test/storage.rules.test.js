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
const verifiedContext = (uid) =>
  env.authenticatedContext(uid, {email_verified: true});

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
      firestore: {host: "127.0.0.1", port: Number(
          (process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8180")
              .split(":").at(-1),
      )},
      storage: {
        host: "127.0.0.1",
        port: Number((process.env.FIREBASE_STORAGE_EMULATOR_HOST ||
          "127.0.0.1:9299").split(":").at(-1)),
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
      await setDoc(doc(db, "users/other"), activeUser({
        institution: "inst-2",
        campus: "campus-2",
        permissions: ["sitio_web.editar"],
      }));
      await setDoc(doc(db, "users/teacher"), activeUser({
        role: "Docente",
        audienceType: "groups",
        targetGroupIds: ["group-5a"],
        targetStudentIds: ["student"],
        recipientUserIds: ["teacher", "student", "family"],
        recipientContextKeys: ["family:student"],
        permissions: ["archivos.ver", "archivos.crear", "mensajeria.ver"],
      }));
      await setDoc(doc(db, "users/student"), activeUser({
        role: "Estudiante",
        groupId: "group-5a",
        permissions: ["archivos.ver", "mensajeria.ver"],
      }));
      await setDoc(doc(db, "users/student-other"), activeUser({
        role: "Estudiante",
        groupId: "group-6a",
        permissions: ["archivos.ver", "mensajeria.ver"],
      }));
      await setDoc(doc(db, "users/family"), activeUser({
        role: "Familiar",
        studentIds: ["student"],
        activeStudentId: "student",
        permissions: ["archivos.ver", "mensajeria.ver"],
      }));
    });
  });

  after(async () => env.cleanup());

  it("bloquea correo adulto sin verificar y contraseña temporal", async () => {
    const unverified = env.authenticatedContext("editor", {
      email_verified: false,
    }).storage(`gs://${projectId}.firebasestorage.app`);
    await assertFails(unverified.ref("website/inst-1/campus-1/unverified.png")
        .put(Buffer.from("imagen"), {contentType: "image/png"}));
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "users/editor"), {
        mustChangePassword: true,
      }, {merge: true});
    });
    const temporary = env.authenticatedContext("editor", {
      email_verified: true,
    }).storage(`gs://${projectId}.firebasestorage.app`);
    await assertFails(temporary.ref("website/inst-1/campus-1/temporary.png")
        .put(Buffer.from("imagen"), {contentType: "image/png"}));
  });

  const upload = (userId, name, contentType, scope = "inst-1/campus-1") => {
    const storage = verifiedContext(userId).storage(
        `gs://${projectId}.firebasestorage.app`,
    );
    return storage.ref(`website/${scope}/${name}`).put(
        Buffer.from("imagen de prueba"),
        {contentType},
    );
  };

  const uploadProfile = (actorId, userId, name, contentType = "image/jpeg") => {
    const storage = verifiedContext(actorId).storage(
        `gs://${projectId}.firebasestorage.app`,
    );
    return storage.ref(`fotos_perfil/${userId}/${name}`).put(
        Buffer.from("imagen de perfil"),
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

  it("aísla los recursos web por institución y sede", async () => {
    await assertFails(upload("editor", "ajena.png", "image/png",
        "inst-2/campus-2"));
    await assertSucceeds(upload("other", "propia.png", "image/png",
        "inst-2/campus-2"));
  });

  it("protege fotos propias y administrativas por sede", async () => {
    await assertSucceeds(uploadProfile("student", "student", "propia.jpg"));
    await assertFails(uploadProfile("student", "teacher", "ajena.jpg"));
    await assertSucceeds(uploadProfile("admin", "student", "gestionada.png",
        "image/png"));
    await assertFails(uploadProfile("admin", "other", "otra-sede.jpg"));
    await assertFails(uploadProfile("student", "student", "archivo.pdf",
        "application/pdf"));
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
    const storage = verifiedContext("teacher").storage(
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

  it("descargas privadas requieren backend, incluso siendo destinatario",
      async () => {
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
        const teacherStorage = verifiedContext("teacher").storage(
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
        const studentRef = verifiedContext("student").storage(
            `gs://${projectId}.firebasestorage.app`,
        ).ref(reference.fullPath);
        const familyRef = verifiedContext("family").storage(
            `gs://${projectId}.firebasestorage.app`,
        ).ref(reference.fullPath);
        const otherRef = verifiedContext("student-other").storage(
            `gs://${projectId}.firebasestorage.app`,
        ).ref(reference.fullPath);
        await assertFails(studentRef.getMetadata());
        await assertFails(familyRef.getMetadata());
        await assertFails(verifiedContext("superadmin").storage(
            `gs://${projectId}.firebasestorage.app`,
        ).ref(reference.fullPath).getMetadata());
        await assertFails(otherRef.getMetadata());
        await assertFails(reference.delete());
      });

  it("permite reserva de adjunto y deniega descarga directa", async () => {
    const bytes = Buffer.from("circular del canal");
    const path = "message_attachments/channel-1/attachment-1/circular.pdf";
    await env.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "message_channels/channel-1"), {
        institutionId: "inst-1",
        campusId: "campus-1",
        status: "active",
        memberUserIds: ["teacher", "student", "family"],
      });
      await setDoc(doc(db, "message_attachments/attachment-1"), {
        institutionId: "inst-1",
        campusId: "campus-1",
        channelId: "channel-1",
        status: "uploading",
        uploadedBy: "teacher",
        expectedSize: bytes.length,
        contentType: "application/pdf",
        storagePath: path,
      });
    });
    const teacherRef = verifiedContext("teacher").storage(
        `gs://${projectId}.firebasestorage.app`,
    ).ref(path);
    await assertSucceeds(teacherRef.put(bytes, {
      contentType: "application/pdf",
      customMetadata: {
        attachmentId: "attachment-1",
        channelId: "channel-1",
        uploadedBy: "teacher",
      },
    }));
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(),
          "message_attachments/attachment-1"), {
        status: "attached",
      }, {merge: true});
    });
    await assertFails(verifiedContext("family").storage(
        `gs://${projectId}.firebasestorage.app`,
    ).ref(path).getMetadata());
    await assertFails(verifiedContext("student-other").storage(
        `gs://${projectId}.firebasestorage.app`,
    ).ref(path).getMetadata());
    await assertFails(teacherRef.delete());
  });
});
