"use strict";

const assert = require("assert");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");
const {getStorage} = require("firebase-admin/storage");
const {seedAcademicYear} = require("./academic_year_fixture");

const projectId = "sistema-educativo-download-test";
const functionsPort = process.env.RELEASE_FUNCTIONS_PORT || "5002";
const authPort = process.env.RELEASE_AUTH_PORT || "9098";
const base = `http://127.0.0.1:${functionsPort}/${projectId}/us-central1`;
const authBase = `http://127.0.0.1:${authPort}/identitytoolkit.googleapis.com/v1`;
const payload = Buffer.from("%PDF-1.4\nDocumento de prueba privado\n");
let app;
let db;
let auth;
let bucket;
let yearId;
let file;
let attachment;
let tokens;

async function seedUser(uid, role, extra = {}) {
  const email = `${uid}@descargas.test`;
  await auth.createUser({uid, email, password: "Clave123!",
    emailVerified: true});
  await db.collection("users").doc(uid).set({
    firstName: uid, lastName: "Prueba", role, status: "activo",
    institution: "inst-1", campus: "campus-1", institutionalEmail: email,
    permissions: ["archivos.ver", "mensajeria.ver"], isSuperadmin: false,
    ...extra,
  });
  const response = await fetch(
      `${authBase}/accounts:signInWithPassword?key=x`, {
        method: "POST", headers: {"content-type": "application/json"},
        body: JSON.stringify({email, password: "Clave123!",
          returnSecureToken: true}),
      });
  const body = await response.json();
  assert.ok(body.idToken, JSON.stringify(body));
  return body.idToken;
}

async function download(kind, token, options = {}) {
  const isFile = kind === "file";
  const name = isFile ? "descargarArchivoProtegido" :
    "descargarAdjuntoProtegido";
  const query = isFile ? "fileId=file-1" : "attachmentId=attachment-1";
  return fetch(`${base}/${name}?${query}`, {
    ...options,
    headers: {...(token ? {authorization: `Bearer ${token}`} : {}),
      ...options.headers},
  });
}

async function expectError(response, status) {
  assert.equal(response.status, status);
  const body = await response.json();
  assert.ok(body.error?.status, JSON.stringify(body));
  assert.ok(body.error?.message);
  assert.ok(!body.error.stack);
}

describe("descargas HTTP privadas", () => {
  before(() => {
    app = initializeApp({projectId, storageBucket: `${projectId}.appspot.com`},
        "protected-download-tests");
    db = getFirestore(app);
    auth = getAuth(app);
    bucket = getStorage(app).bucket();
  });
  after(async () => deleteApp(app));
  beforeEach(async () => {
    assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
    assert.ok(process.env.FIREBASE_STORAGE_EMULATOR_HOST);
    const clear = await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}` +
      `/emulator/v1/projects/${projectId}/databases/(default)/documents`,
    {method: "DELETE"});
    assert.ok(clear.ok);
    const users = await auth.listUsers(1000);
    if (users.users.length) {
      await auth.deleteUsers(users.users.map((item) => item.uid));
    }
    yearId = await seedAcademicYear(db, "inst-1", "campus-1");
    await db.collection("academic_groups").doc("group-a").set({
      institutionId: "inst-1", campusId: "campus-1", active: true,
      academicYearId: yearId, name: "Grupo prueba", academicYear: 2026,
    });
    tokens = {};
    tokens.student = await seedUser("student", "Estudiante",
        {groupId: "group-a"});
    tokens.family = await seedUser("family", "Familiar", {
      studentIds: ["student"], activeStudentId: "student",
    });
    tokens.teacher = await seedUser("teacher", "Docente", {
      tutorGroupId: "group-a",
    });
    tokens.admin = await seedUser("admin", "Administrador");
    await db.collection("subjects").doc("subject-a").set({
      institutionId: "inst-1", campusId: "campus-1", academicYearId: yearId,
      groupId: "group-a", teacherId: "teacher",
    });
    await db.collection("message_channels").doc("channel-a").set({
      institutionId: "inst-1", campusId: "campus-1", academicYearId: yearId,
      status: "active", channelType: "academic_group", groupId: "group-a",
      memberUserIds: ["student", "family", "teacher", "admin"],
    });
    file = {status: "active", institutionId: "inst-1", campusId: "campus-1",
      academicYearId: yearId, name: "guía.pdf",
      storagePath: "files/file-1/guía.pdf",
      contentType: "application/pdf", sizeBytes: payload.length,
      recipientUserIds: ["student", "family", "teacher"],
      recipientContextKeys: ["family:student"], targetStudentIds: ["student"],
      targetGroupIds: ["group-a"], uploadedBy: "admin"};
    attachment = {...file, status: "attached", channelId: "channel-a",
      messageId: "message-1",
      storagePath: "message_attachments/channel-a/attachment-1/guía.pdf"};
    await db.collection("files").doc("file-1").set(file);
    await db.collection("message_attachments").doc("attachment-1")
        .set(attachment);
    for (const item of [file, attachment]) {
      await bucket.file(item.storagePath).save(payload,
          {metadata: {contentType: "application/pdf"}, resumable: false});
    }
  });

  it("autoriza cuatro roles, descarga bytes y no fabrica acuses", async () => {
    for (const kind of ["file", "attachment"]) {
      for (const token of Object.values(tokens)) {
        const result = await download(kind, token);
        assert.equal(result.status, 200, await result.clone().text());
        assert.deepEqual(Buffer.from(await result.arrayBuffer()), payload);
        assert.equal(result.headers.get("content-type"), "application/pdf");
        assert.ok(result.headers.get("cache-control").includes("no-store"));
        assert.ok(result.headers.get("content-disposition")
            .includes("filename*=UTF-8''gu%C3%ADa.pdf"));
      }
    }
    for (const collection of ["file_download_receipts",
      "message_attachment_downloads"]) {
      assert.equal((await db.collection(collection).get()).size, 0);
    }
  });

  it("rechaza sesión ausente o token inválido en ambos endpoints", async () => {
    for (const kind of ["file", "attachment"]) {
      await expectError(await download(kind), 401);
      await expectError(await download(kind, "invalid-token"), 401);
    }
  });

  it("rechaza perfil inactivo y permisos retirados aunque siga en audiencia",
      async () => {
        await db.collection("users").doc("student")
            .update({status: "inactivo"});
        await db.collection("users").doc("family").update({permissions: []});
        for (const kind of ["file", "attachment"]) {
          await expectError(await download(kind, tokens.student), 403);
          await expectError(await download(kind, tokens.family), 403);
        }
      });

  it("rechaza vínculo familiar revocado aunque persistiera materializado",
      async () => {
        await db.collection("users").doc("family").update({studentIds: []});
        for (const kind of ["file", "attachment"]) {
          await expectError(await download(kind, tokens.family), 403);
        }
      });

  it("rechaza hijo retirado y de otra institución", async () => {
    for (const changes of [{status: "inactivo"},
      {status: "activo", institution: "inst-2"}]) {
      await db.collection("users").doc("student").update(changes);
      for (const kind of ["file", "attachment"]) {
        await expectError(await download(kind, tokens.family), 409);
      }
    }
  });

  it("rechaza otro año para alumnos y permite archivo histórico al admin",
      async () => {
        await db.collection("files").doc("file-1")
            .update({academicYearId: "old-year"});
        await db.collection("message_attachments").doc("attachment-1")
            .update({academicYearId: "old-year"});
        await db.collection("message_channels").doc("channel-a")
            .update({academicYearId: "old-year"});
        for (const kind of ["file", "attachment"]) {
          await expectError(await download(kind, tokens.student), 403);
          assert.equal((await download(kind, tokens.admin)).status, 200);
        }
      });

  it("objeto eliminado devuelve 404 conservador y no acuse", async () => {
    for (const item of [file, attachment]) {
      await bucket.file(item.storagePath).delete();
    }
    for (const kind of ["file", "attachment"]) {
      await expectError(await download(kind, tokens.family), 404);
    }
  });

  it("rechaza reserva pendiente, ruta ajena y MIME adulterado", async () => {
    await db.collection("message_attachments").doc("attachment-1")
        .update({status: "ready"});
    await expectError(await download("attachment", tokens.student), 403);
    await db.collection("files").doc("file-1")
        .update({storagePath: attachment.storagePath});
    await expectError(await download("file", tokens.student), 409);
    await db.collection("files").doc("file-1")
        .update({storagePath: file.storagePath});
    await bucket.file(file.storagePath)
        .setMetadata({contentType: "text/html"});
    await expectError(await download("file", tokens.student), 409);
  });

  it("revoca adjuntos al cambiar grupo o docente", async () => {
    await db.collection("users").doc("student")
        .update({groupId: "group-other"});
    await db.collection("users").doc("teacher").update({tutorGroupId: null});
    await db.collection("subjects").doc("subject-a").delete();
    for (const token of [tokens.student, tokens.family, tokens.teacher]) {
      await expectError(await download("attachment", token), 403);
    }
  });

  it("CORS exacto, nativo sin Origin y métodos acotados", async () => {
    const origin = "http://localhost:5000";
    const options = await download("file", null, {method: "OPTIONS",
      headers: {origin}});
    assert.equal(options.status, 204);
    assert.equal(options.headers.get("access-control-allow-origin"), origin);
    const cross = await download("file", tokens.student,
        {headers: {origin: "https://evil.example"}});
    await expectError(cross, 403);
    assert.equal(cross.headers.get("access-control-allow-origin"), null);
    await expectError(await download("file", tokens.student,
        {method: "POST"}), 405);
  });

  it("revoca cuenta Auth deshabilitada y el traslado de sede", async () => {
    await auth.updateUser("student", {disabled: true});
    await db.collection("users").doc("family").update({campus: "campus-2"});
    for (const kind of ["file", "attachment"]) {
      await expectError(await download(kind, tokens.student), 401);
      await expectError(await download(kind, tokens.family), 403);
    }
  });

  it("revalida canal supervisado sin modificar membresía ni lecturas",
      async () => {
        const ref = db.collection("message_channels").doc("channel-a");
        await ref.update({channelType: "supervised_student",
          supervisedStudentId: "student", supervisedStaffId: "teacher"});
        assert.equal((await download("attachment", tokens.family)).status, 200);
        assert.equal((await download("attachment", tokens.teacher))
            .status, 200);
        assert.equal((await ref.get()).data().readAtByUser?.family, undefined);
        await db.collection("users").doc("teacher")
            .update({tutorGroupId: null});
        await db.collection("subjects").doc("subject-a").delete();
        await expectError(await download("attachment", tokens.family), 403);
      });

  it("privados familiares requieren un grupo compartido actual", async () => {
    await seedUser("student-other", "Estudiante", {groupId: "group-a"});
    const tokenOther = await seedUser("family-other", "Familiar", {
      studentIds: ["student-other"], activeStudentId: "student-other",
    });
    await db.collection("message_channels").doc("channel-a").update({
      channelType: "private", memberUserIds: ["family", "family-other"],
      familyGroupId: "group-a", contextStudentId: "student",
    });
    assert.equal((await download("attachment", tokens.family)).status, 200);
    assert.equal((await download("attachment", tokenOther)).status, 200);
    await db.collection("users").doc("family-other").update({studentIds: []});
    await expectError(await download("attachment", tokens.family), 403);
  });

  it("docente ya trasladado no descarga publicación de sus grupos anteriores",
      async () => {
        await db.collection("subjects").doc("subject-a").delete();
        await expectError(await download("file", tokens.teacher), 403);
      });

  it("servicios silenciados permiten descarga pero un grupo cerrado no",
      async () => {
        await db.collection("message_channels").doc("channel-a").update({
          channelType: "service", targetGroupIds: ["group-a"],
          mutedByAdmin: true,
        });
        assert.equal((await download("attachment", tokens.family)).status, 200);
        await db.collection("academic_groups").doc("group-a")
            .update({active: false});
        await expectError(await download("attachment", tokens.family), 403);
      });

  it("entrega 25 MiB completos con Content-Length sin respuesta chunked",
      async () => {
        const bytes = Buffer.alloc(25 * 1024 * 1024, 42);
        await db.collection("files").doc("file-1")
            .update({sizeBytes: bytes.length});
        await bucket.file(file.storagePath).save(bytes,
            {metadata: {contentType: "application/pdf"}, resumable: false});
        const response = await download("file", tokens.student);
        assert.equal(response.status, 200, await response.clone().text());
        assert.equal(response.headers.get("content-length"),
            String(bytes.length));
        assert.equal(response.headers.get("transfer-encoding"), null);
        assert.deepEqual(Buffer.from(await response.arrayBuffer()), bytes);
      });

  for (const kind of ["Archivo", "AdjuntoMensaje"]) {
    for (const retainedToken of [false, true]) {
      const title = retainedToken ? "retiene reserva si persiste token" :
        "confirma sin token conservando claves";
      it(`${kind}: ${title}`, async () => {
        await db.collection("users").doc("admin").update({
          permissions: ["archivos.ver", "archivos.crear", "mensajeria.ver"],
        });
        const isFile = kind === "Archivo";
        async function call(name, data, expectedStatus = 200) {
          const response = await fetch(`${base}/${name}`, {
            method: "POST", headers: {"content-type": "application/json",
              "authorization": `Bearer ${tokens.admin}`},
            body: JSON.stringify({data}),
          });
          const result = await response.json();
          assert.equal(response.status, expectedStatus, JSON.stringify(result));
          return result.result || result.error;
        }
        const reservation = await call(isFile ? "solicitarCargaArchivo" :
        "solicitarAdjuntoMensaje", {name: "documento.pdf",
          sizeBytes: payload.length, contentType: "application/pdf",
          institutionId: "inst-1", campusId: "campus-1", audienceType: "groups",
          targetGroupIds: ["group-a"], channelId: "channel-a"});
        const object = bucket.file(reservation.storagePath);
        await object.save(payload, {resumable: false,
          metadata: {contentType: "application/pdf", metadata: {
            uploadedBy: "admin", customKey: "mantener",
            ...(retainedToken ? {
              firebaseStorageDownloadTokens: "token-que-debe-revocarse",
            } : {}),
          }}});
        const [before] = await object.getMetadata();
        await call(isFile ? "confirmarCargaArchivo" : "confirmarAdjuntoMensaje",
            {id: reservation.id}, retainedToken ? 503 : 200);
        const [after] = await object.getMetadata();
        if (retainedToken) {
        // Firebase emulator 15.9 mantiene downloadTokens por separado y no
        // implementa su revocación mediante metadata=null. Backend no omite
        // esta comprobación: falla cerrado y conserva la reserva reintentable.
          assert.ok(after.metadata.firebaseStorageDownloadTokens);
          const pending = (await db.collection(isFile ? "files" :
          "message_attachments").doc(reservation.id).get()).data();
          assert.equal(pending.status, "uploading");
          const usage = await db.collection("file_storage_usage").get();
          assert.equal(usage.docs[0].data().usedBytes, 0);
          assert.equal(usage.docs[0].data().reservedBytes, payload.length);
          return;
        }
        assert.equal(after.metadata.firebaseStorageDownloadTokens, undefined);
        assert.equal(after.metadata.customKey, "mantener");
        assert.equal(after.metadata.uploadedBy, "admin");
        assert.equal(after.generation, before.generation);
        assert.equal(after.size, before.size);
        assert.deepEqual((await object.download())[0], payload);
        const saved = (await db.collection(isFile ? "files" :
        "message_attachments").doc(reservation.id).get()).data();
        assert.equal(saved.status, isFile ? "active" : "ready");
      });
    }
  }
});
