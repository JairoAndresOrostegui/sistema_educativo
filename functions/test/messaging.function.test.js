"use strict";

const assert = require("assert");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");
const {seedAcademicYear} = require("./academic_year_fixture");

const projectId = "sistema-educativo-messaging-test";
const functionsBase = `http://127.0.0.1:5002/${projectId}/us-central1`;
const authBase = "http://127.0.0.1:9098/identitytoolkit.googleapis.com/v1";
let app;
let auth;
let db;

const profile = (role, extra = {}) => ({
  firstName: "Usuario", lastName: "Prueba", document: "10000000",
  institutionalEmail: `${role.toLowerCase()}@colegio.test`,
  role, status: "activo", institution: "inst-1", campus: "campus-1",
  permissions: ["mensajeria.ver"], studentIds: [], isSuperadmin: false,
  ...extra,
});

async function clearFirestore() {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  const response = await fetch(
      `http://${host}/emulator/v1/projects/${projectId}/databases/` +
      "(default)/documents", {method: "DELETE"},
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
    institutionalEmail: email, ...extra,
  }));
  return email;
}

async function signIn(email) {
  const response = await fetch(
      `${authBase}/accounts:signInWithPassword?key=x`, {
        method: "POST", headers: {"content-type": "application/json"},
        body: JSON.stringify({
          email, password: "Clave123!", returnSecureToken: true,
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

function assertError(response, status) {
  assert.ok(response.body.error, JSON.stringify(response.body));
  assert.equal(response.body.error.status, status);
}

describe("mensajeria institucional", () => {
  before(() => {
    app = initializeApp({projectId}, "messaging-function-tests");
    auth = getAuth(app);
    db = getFirestore(app);
  });

  beforeEach(async () => {
    await clearFirestore();
    await clearAuth();
    const yearId = await seedAcademicYear(db, "inst-1", "campus-1");
    for (const [id, name] of [["group-4a", "Cuarto A"],
      ["group-5a", "Quinto A"]]) {
      await db.collection("academic_groups").doc(id).set({
        institutionId: "inst-1", campusId: "campus-1",
        academicYearId: yearId, academicYear: 2026,
        level: name.split(" ")[0], section: "A", name, active: true,
      });
    }
    await seedUser("student-1", "Estudiante", {
      firstName: "Ana", groupId: "group-4a", groupName: "Cuarto A",
    });
    await seedUser("student-2", "Estudiante", {
      firstName: "Luis", groupId: "group-4a", groupName: "Cuarto A",
    });
    await seedUser("student-other", "Estudiante", {
      groupId: "group-5a", groupName: "Quinto A",
    });
    await seedUser("teacher", "Docente", {firstName: "Laura"});
    await seedUser("family", "Familiar", {
      studentIds: ["student-1"], activeStudentId: "student-1",
    });
    await db.collection("subjects").doc("math-4a").set({
      institutionId: "inst-1", campusId: "campus-1",
      academicYearId: yearId, academicYear: 2026,
      groupId: "group-4a", groupName: "Cuarto A",
      teacherId: "teacher", teacherName: "Laura Prueba",
      subject: "Matematicas",
    });
  });

  after(async () => deleteApp(app));

  it("sincroniza grupo y limita la conversacion a sus miembros", async () => {
    const adminToken = await signIn(await seedUser("admin", "Administrador"));
    const sync = await callFunction(
        "sincronizarCanalesMensajeria", {}, adminToken,
    );
    assert.equal(sync.body.result.channelCount, 2);
    const ref = db.collection("message_channels").doc("academic_group-4a");
    const channel = (await ref.get()).data();
    assert.deepEqual(
        new Set(channel.studentIds), new Set(["student-1", "student-2"]),
    );
    assert.ok(channel.memberUserIds.includes("teacher"));
    assert.ok(channel.memberUserIds.includes("family"));

    const studentToken = await signIn("student-1@colegio.test");
    const sent = await callFunction("enviarMensajeCanal", {
      channelId: ref.id, body: "Hola grupo",
    }, studentToken);
    assert.equal(sent.body.result.success, true);
    assert.equal((await ref.get()).data().messageSequence, 1);

    const outsiderToken = await signIn("student-other@colegio.test");
    assertError(await callFunction("enviarMensajeCanal", {
      channelId: ref.id, body: "No pertenezco",
    }, outsiderToken), "PERMISSION_DENIED");
  });

  it("silencia grupos, admite anuncios admin y registra lecturas", async () => {
    const adminToken = await signIn(await seedUser("admin", "Administrador"));
    await callFunction("sincronizarCanalesMensajeria", {}, adminToken);
    const channelId = "academic_group-4a";
    await callFunction("configurarSilencioCanalMensajeria", {
      channelId, muted: true,
    }, adminToken);
    const studentToken = await signIn("student-1@colegio.test");
    assertError(await callFunction("enviarMensajeCanal", {
      channelId, body: "Mensaje bloqueado",
    }, studentToken), "FAILED_PRECONDITION");
    const sent = await callFunction("enviarMensajeCanal", {
      channelId, body: "Comunicado oficial",
    }, adminToken);
    assert.equal(sent.body.result.success, true);
    await callFunction("marcarCanalMensajeriaLeido", {channelId}, studentToken);
    const channel = (await db.collection("message_channels")
        .doc(channelId).get()).data();
    assert.equal(channel.readSequences["student-1"], 1);
    assert.equal((await db.collection("messaging_audit").get()).size, 3);
  });

  it("limita privados y crea canales de servicio", async () => {
    const studentToken = await signIn("student-1@colegio.test");
    assertError(await callFunction("enviarMensajeCanal", {
      recipientId: "student-2", body: "Trabajo en grupo",
    }, studentToken), "PERMISSION_DENIED");
    const yearId = await seedAcademicYear(db, "inst-1", "campus-1");
    await db.collection("message_channels").doc("old-student-private").set({
      channelType: "private", status: "active", postingPolicy: "members",
      institutionId: "inst-1", campusId: "campus-1",
      academicYearId: yearId, memberUserIds: ["student-1", "student-2"],
    });
    assertError(await callFunction("enviarMensajeCanal", {
      channelId: "old-student-private", body: "Privado anterior",
    }, studentToken), "PERMISSION_DENIED");
    const contacts = await callFunction(
        "listarDestinatariosMensajeria", {}, studentToken);
    assert.ok(contacts.body.result.contacts.every((item) =>
      item.role !== "Estudiante"));
    assertError(await callFunction("enviarMensajeCanal", {
      recipientId: "student-other", body: "Fuera del grupo",
    }, studentToken), "PERMISSION_DENIED");

    const adminToken = await signIn(await seedUser("admin", "Administrador"));
    const service = await callFunction("crearCanalServicioMensajeria", {
      title: "Menu de restaurante", category: "restaurant",
      audienceType: "groups", groupIds: ["group-4a"],
    }, adminToken);
    assert.equal(service.body.result.success, true);
    const channel = (await db.collection("message_channels")
        .doc(service.body.result.channelId).get()).data();
    assert.equal(channel.postingPolicy, "announcements");
    assert.ok(channel.memberUserIds.includes("family"));
  });

  it("permite familiares del mismo grupo y revalida vinculos al responder",
      async () => {
        const first = await signIn("family@colegio.test");
        const second = await signIn(await seedUser("family-2", "Familiar", {
          studentIds: ["student-2"], activeStudentId: "student-2",
        }));
        await seedUser("family-other", "Familiar", {
          studentIds: ["student-other"], activeStudentId: "student-other",
        });
        const list = await callFunction("listarDestinatariosMensajeria", {
          studentContextId: "student-1",
        }, first);
        assert.ok(list.body.result.contacts.some((item) =>
          item.id === "family-2"));
        assert.ok(!list.body.result.contacts.some((item) =>
          ["family-other", "family"].includes(item.id)));
        assertError(await callFunction("enviarMensajeCanal", {
          recipientId: "family-other", studentContextId: "student-1",
          body: "Hola",
        }, first), "PERMISSION_DENIED");
        const sent = await callFunction("enviarMensajeCanal", {
          recipientId: "family-2", studentContextId: "student-1", body: "Hola",
        }, first);
        assert.equal(sent.body.result.success, true);
        const channelId = sent.body.result.channelId;
        const reply = await callFunction("enviarMensajeCanal", {
          channelId, body: "Respuesta con mi propio hijo activo",
        }, second);
        assert.equal(reply.body.result.success, true);
        const reopened = await callFunction("enviarMensajeCanal", {
          recipientId: "family", studentContextId: "student-2",
          body: "Otro mensaje",
        }, second);
        assert.equal(reopened.body.result.channelId, channelId);
        assert.equal((await db.collection("message_channels").doc(channelId)
            .get()).data().messageSequence, 3);
        await db.collection("users").doc("student-2").update({
          status: "inactivo",
        });
        assertError(await callFunction("enviarMensajeCanal", {
          channelId, body: "Ya no hay hijos activos compartiendo grupo",
        }, first), "PERMISSION_DENIED");
        await db.collection("users").doc("student-2").update({
          status: "activo", groupId: "group-5a",
        });
        assertError(await callFunction("enviarMensajeCanal", {
          channelId, body: "Cambio de grupo",
        }, first), "PERMISSION_DENIED");
        await db.collection("users").doc("family-2").update({
          studentIds: ["student-2", "student-1"],
        });
        assert.equal((await callFunction("enviarMensajeCanal", {
          channelId, body: "Otro hijo vinculado conserva el grupo compartido",
        }, first)).body.result.success, true);
        await db.collection("users").doc("family-2").update({
          campus: "campus-2",
        });
        assertError(await callFunction("enviarMensajeCanal", {
          channelId, body: "Otra sede",
        }, first), "PERMISSION_DENIED");
      });
});
