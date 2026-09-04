"use strict";

const assert = require("assert");
const {applicationDefault, initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");
const fs = require("fs");
const os = require("os");
const path = require("path");

function firebaseToolsModule(relativePath) {
  const roots = [
    process.env.APPDATA ?
      path.join(process.env.APPDATA, "npm", "node_modules") : "",
    ...require("module").globalPaths,
  ].filter(Boolean);
  const root = roots.find((item) =>
    fs.existsSync(path.join(item, "firebase-tools")));
  if (!root) throw new Error("No se encontro Firebase CLI.");
  return require(path.join(root, "firebase-tools", relativePath));
}

const firebaseAuth = firebaseToolsModule("lib/auth");
const firebaseApi = firebaseToolsModule("lib/api");
const account = firebaseAuth.getGlobalDefaultAccount();
if (!account?.tokens?.refresh_token) {
  throw new Error("Firebase CLI no tiene una sesion activa.");
}
const credentialDirectory = fs.mkdtempSync(
    path.join(os.tmpdir(), "teacher-transfer-smoke-"),
);
const credentialPath = path.join(
    credentialDirectory, "application_default_credentials.json",
);
fs.writeFileSync(credentialPath, JSON.stringify({
  type: "authorized_user",
  client_id: firebaseApi.clientId(),
  client_secret: firebaseApi.clientSecret(),
  refresh_token: account.tokens.refresh_token,
}), {encoding: "utf8", mode: 0o600});
process.env.GOOGLE_APPLICATION_CREDENTIALS = credentialPath;

const projectId = "sistema-educativo-rl";
const apiKey = "AIzaSyBjfpuzVCTvKEMdYGYjMa619SSJ1yL8Jho";
const functionsBase =
  `https://us-central1-${projectId}.cloudfunctions.net`;
const app = initializeApp({credential: applicationDefault(), projectId});
const auth = getAuth(app);
const db = getFirestore(app);
const runId = `qa-smoke-${Date.now()}`;
const password = `Qa-${Date.now()}-A9!`;
const ids = {
  admin: `${runId}-admin`,
  source: `${runId}-source`,
  target: `${runId}-target`,
  subject: `${runId}-subject`,
  route: `${runId}-route`,
  dailyRoute: `${runId}-daily-route`,
  thread: `${runId}-thread`,
  file: `${runId}-file`,
};
let transferId;

async function signIn(email) {
  const response = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:` +
        `signInWithPassword?key=${apiKey}`,
      {
        method: "POST",
        headers: {"content-type": "application/json"},
        body: JSON.stringify({email, password, returnSecureToken: true}),
      },
  );
  const body = await response.json();
  return {ok: response.ok, body};
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
  const body = await response.json();
  assert.ok(response.ok && body.result, `${name}: ${JSON.stringify(body)}`);
  return body.result;
}

async function createUser(uid, email, role, scope, extra = {}) {
  await auth.createUser({uid, email, password, emailVerified: true});
  const profile = {
    firstName: "Prueba QA",
    lastName: role,
    document: uid,
    institutionalEmail: email,
    role,
    status: "activo",
    institution: scope.institutionId,
    campus: scope.campusId,
    permissions: [],
    isSuperadmin: false,
    ...extra,
  };
  await Promise.all([
    db.collection("users").doc(uid).set(profile),
    db.collection("user_directory").doc(uid).set(profile),
  ]);
}

async function cleanup() {
  const deletions = [
    ["subjects", ids.subject],
    ["routes", ids.route],
    ["daily_routes", ids.dailyRoute],
    ["message_threads", ids.thread],
    ["files", ids.file],
    ["teacher_transfers", transferId],
    ["users", ids.admin],
    ["users", ids.source],
    ["users", ids.target],
    ["user_directory", ids.admin],
    ["user_directory", ids.source],
    ["user_directory", ids.target],
  ].filter((item) => item[1]);
  const batch = db.batch();
  deletions.forEach(([collection, id]) =>
    batch.delete(db.collection(collection).doc(id)));
  await batch.commit();
  const authResult = await auth.deleteUsers([
    ids.admin, ids.source, ids.target,
  ]);
  assert.equal(authResult.failureCount, 0, "Quedaron cuentas de prueba.");
  const remaining = await Promise.all(deletions.map(([collection, id]) =>
    db.collection(collection).doc(id).get()));
  assert.ok(
      remaining.every((item) => !item.exists),
      "Quedaron documentos de prueba.",
  );
}

async function run() {
  const settings = await db.collection("academic_year_settings").limit(1).get();
  assert.equal(settings.size, 1, "QA no tiene un ano lectivo activo.");
  const scope = settings.docs[0].data();
  const year = await db.collection("academic_years")
      .doc(scope.activeYearId).get();
  assert.equal(year.data()?.status, "active");
  const groups = await db.collection("academic_groups")
      .where("institutionId", "==", scope.institutionId)
      .where("campusId", "==", scope.campusId)
      .where("academicYearId", "==", scope.activeYearId)
      .where("active", "==", true).limit(1).get();
  assert.equal(groups.size, 1, "QA no tiene grupos activos para la prueba.");
  const group = groups.docs[0];
  const sourceEmail = `${ids.source}@qa-smoke.test`;
  const targetEmail = `${ids.target}@qa-smoke.test`;
  const adminEmail = `${ids.admin}@qa-smoke.test`;
  await createUser(ids.admin, adminEmail, "Administrador", scope, {
    permissions: ["usuarios.editar"],
  });
  await createUser(ids.source, sourceEmail, "Docente", scope, {
    tutorGroupId: group.id,
  });
  await createUser(ids.target, targetEmail, "Docente", scope);

  const common = {
    institutionId: scope.institutionId,
    campusId: scope.campusId,
    academicYearId: scope.activeYearId,
    academicYear: scope.activeYear,
  };
  await Promise.all([
    db.collection("subjects").doc(ids.subject).set({
      ...common,
      teacherId: ids.source,
      teacherName: "Prueba QA Docente",
      groupId: group.id,
      groupName: group.data().name,
      subject: "Prueba continuidad",
      day: "lunes",
      startMinutes: 420,
      endMinutes: 480,
      revision: 1,
    }),
    db.collection("routes").doc(ids.route).set({
      institution: scope.institutionId,
      campus: scope.campusId,
      academicYearId: scope.activeYearId,
      academicYear: scope.activeYear,
      gestionador: ids.source,
    }),
    db.collection("daily_routes").doc(ids.dailyRoute).set({
      institution: scope.institutionId,
      campus: scope.campusId,
      academicYearId: scope.activeYearId,
      academicYear: scope.activeYear,
      gestionador: ids.source,
    }),
    db.collection("message_threads").doc(ids.thread).set({
      ...common,
      participantIds: [ids.source, ids.admin],
      participantNames: {
        [ids.source]: "Prueba QA Docente",
        [ids.admin]: "Prueba QA Administrador",
      },
      participantRoles: {
        [ids.source]: "Docente",
        [ids.admin]: "Administrador",
      },
    }),
    db.collection("files").doc(ids.file).set({
      ...common,
      uploadedBy: ids.source,
      recipientUserIds: [ids.source],
      status: "active",
      name: "archivo-prueba.pdf",
    }),
  ]);

  const adminLogin = await signIn(adminEmail);
  assert.ok(adminLogin.ok, JSON.stringify(adminLogin.body));
  const sourceLogin = await signIn(sourceEmail);
  assert.ok(sourceLogin.ok, JSON.stringify(sourceLogin.body));
  const preview = await callFunction("previsualizarTrasladoDocente", {
    sourceTeacherId: ids.source,
    targetTeacherId: ids.target,
  }, adminLogin.body.idToken);
  assert.deepEqual(preview.impact, {
    schedules: 1,
    tutoring: 1,
    routes: 1,
    dailyRoutes: 1,
    messageThreads: 1,
    accessibleFiles: 1,
  });
  const moved = await callFunction("ejecutarTrasladoDocente", {
    sourceTeacherId: ids.source,
    targetTeacherId: ids.target,
    mode: "temporary",
    allowMerge: false,
    endsAtMillis: Date.now() + 7 * 24 * 60 * 60 * 1000,
  }, adminLogin.body.idToken);
  transferId = moved.id;

  const [sourceAfter, targetAfter, subjectAfter, threadAfter, fileAfter] =
    await Promise.all([
      db.collection("users").doc(ids.source).get(),
      db.collection("users").doc(ids.target).get(),
      db.collection("subjects").doc(ids.subject).get(),
      db.collection("message_threads").doc(ids.thread).get(),
      db.collection("files").doc(ids.file).get(),
    ]);
  assert.equal(sourceAfter.data().status, "inactivo");
  assert.equal((await auth.getUser(ids.source)).disabled, true);
  assert.equal(targetAfter.data().tutorGroupId, group.id);
  assert.equal(subjectAfter.data().teacherId, ids.target);
  assert.ok(threadAfter.data().participantIds.includes(ids.target));
  assert.equal(fileAfter.data().uploadedBy, ids.source);
  assert.ok(fileAfter.data().recipientUserIds.includes(ids.target));
  assert.equal((await signIn(sourceEmail)).ok, false);

  await callFunction("revertirTrasladoDocenteTemporal", {
    id: transferId,
  }, adminLogin.body.idToken);
  const [restoredSource, restoredSubject, restoredThread, restoredFile] =
    await Promise.all([
      db.collection("users").doc(ids.source).get(),
      db.collection("subjects").doc(ids.subject).get(),
      db.collection("message_threads").doc(ids.thread).get(),
      db.collection("files").doc(ids.file).get(),
    ]);
  assert.equal(restoredSource.data().status, "activo");
  assert.equal((await auth.getUser(ids.source)).disabled, false);
  assert.equal(restoredSubject.data().teacherId, ids.source);
  assert.ok(!restoredThread.data().participantIds.includes(ids.target));
  assert.ok(!restoredFile.data().recipientUserIds.includes(ids.target));
  assert.equal(restoredFile.data().uploadedBy, ids.source);
  assert.ok((await signIn(sourceEmail)).ok);
  console.log("Prueba QA correcta: traslado, bloqueo, autoria y reversion.");
}

(async () => {
  try {
    await run();
  } finally {
    await cleanup().catch((error) =>
      console.error("Limpieza incompleta:", error));
    fs.rmSync(credentialDirectory, {recursive: true, force: true});
  }
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
