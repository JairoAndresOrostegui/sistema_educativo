"use strict";

const assert = require("assert");
const crypto = require("crypto");
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
    path.join(os.tmpdir(), "academic-year-smoke-"),
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
const app = initializeApp({credential: applicationDefault(), projectId});
const auth = getAuth(app);
const db = getFirestore(app);
const apply = process.argv.includes("--apply");
const runId = `qa-year-${Date.now()}`;
const email = `${runId}@qa-smoke.test`;
const password = `Qa-${Date.now()}-A9!`;

const academicYearId = (institution, campus, year) =>
  crypto.createHash("sha256")
      .update(`${institution}\u0000${campus}\u0000${year}`)
      .digest("hex");

async function signIn() {
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
  assert.ok(response.ok && body.idToken, JSON.stringify(body));
  return body.idToken;
}

async function callFunction(name, data, token) {
  const response = await fetch(
      `https://us-central1-${projectId}.cloudfunctions.net/${name}`,
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "authorization": `Bearer ${token}`,
        },
        body: JSON.stringify({data}),
      },
  );
  const body = await response.json();
  assert.ok(response.ok && body.result, `${name}: ${JSON.stringify(body)}`);
  return body.result;
}

async function createAdmin(scope) {
  await auth.createUser({uid: runId, email, password, emailVerified: true});
  const profile = {
    firstName: "Prueba QA",
    lastName: "Ano lectivo",
    document: runId,
    institutionalEmail: email,
    role: "Administrador",
    status: "activo",
    institution: scope.institutionId,
    campus: scope.campusId,
    permissions: [],
    isSuperadmin: false,
  };
  await Promise.all([
    db.collection("users").doc(runId).set(profile),
    db.collection("user_directory").doc(runId).set(profile),
  ]);
}

async function cleanupAdmin() {
  const batch = db.batch();
  batch.delete(db.collection("users").doc(runId));
  batch.delete(db.collection("user_directory").doc(runId));
  await batch.commit();
  await auth.deleteUser(runId).catch((error) => {
    if (error.code !== "auth/user-not-found") throw error;
  });
  const [user, directory] = await Promise.all([
    db.collection("users").doc(runId).get(),
    db.collection("user_directory").doc(runId).get(),
  ]);
  assert.ok(!user.exists && !directory.exists, "Quedo el admin de prueba.");
}

async function selectScope() {
  const settings = await db.collection("academic_year_settings").get();
  assert.ok(!settings.empty, "QA no tiene anos lectivos configurados.");
  const scopes = settings.docs.map((item) => item.data());
  scopes.sort((a, b) => a.campusId.localeCompare(b.campusId));
  scopes.forEach((item) => console.log(
      `${item.institutionId} / ${item.campusId}: ${item.activeYear} activo`,
  ));
  return scopes.find((item) =>
    item.campusId.toLowerCase().includes("piedecuesta")) || scopes[0];
}

async function verifyDraft(scope, sourceGroups, sourceSubjects) {
  const targetId = academicYearId(scope.institutionId, scope.campusId, 2027);
  const [settings, currentYear, targetYear, groups, subjects] =
    await Promise.all([
      db.collection("academic_year_settings")
          .where("institutionId", "==", scope.institutionId)
          .where("campusId", "==", scope.campusId).limit(1).get(),
      db.collection("academic_years").doc(scope.activeYearId).get(),
      db.collection("academic_years").doc(targetId).get(),
      db.collection("academic_groups")
          .where("academicYearId", "==", targetId).get(),
      db.collection("subjects").where("academicYearId", "==", targetId).get(),
    ]);
  assert.equal(settings.docs[0].data().activeYearId, scope.activeYearId);
  assert.equal(settings.docs[0].data().activeYear, 2026);
  assert.equal(currentYear.data().status, "active");
  assert.equal(targetYear.data().status, "draft");
  assert.equal(groups.size, sourceGroups.size);
  assert.equal(subjects.size, sourceSubjects.size);
  assert.ok(groups.docs.every((item) => item.data().sourceGroupId));
  assert.ok(subjects.docs.every((item) => item.data().sourceSubjectId));
  console.log(
      `Verificacion correcta: 2026 sigue activo; 2027 quedo en borrador ` +
      `con ${groups.size} grupos y ${subjects.size} horarios.`,
  );
}

async function run() {
  const scope = await selectScope();
  assert.equal(scope.activeYear, 2026, "La sede no tiene 2026 activo.");
  const targetId = academicYearId(scope.institutionId, scope.campusId, 2027);
  const [target, sourceGroups, sourceSubjects] = await Promise.all([
    db.collection("academic_years").doc(targetId).get(),
    db.collection("academic_groups")
        .where("institutionId", "==", scope.institutionId)
        .where("campusId", "==", scope.campusId)
        .where("academicYearId", "==", scope.activeYearId).get(),
    db.collection("subjects")
        .where("institutionId", "==", scope.institutionId)
        .where("campusId", "==", scope.campusId)
        .where("academicYearId", "==", scope.activeYearId).get(),
  ]);
  console.log(
      `Sede elegida: ${scope.campusId}; ${sourceGroups.size} grupos y ` +
      `${sourceSubjects.size} horarios para copiar.`,
  );
  if (!target.exists) {
    if (!apply) {
      console.log("Simulacion correcta. Usa --apply para preparar 2027.");
      return;
    }
    await createAdmin(scope);
    const token = await signIn();
    await callFunction("prepararAnioLectivo", {
      year: 2027,
      cloneGroups: true,
      cloneSchedules: true,
    }, token);
  } else {
    assert.equal(
        target.data().status, "draft", "2027 ya existe y no es draft.",
    );
    console.log("2027 ya existia como borrador; solo se verificara.");
  }
  await verifyDraft(scope, sourceGroups, sourceSubjects);
}

(async () => {
  try {
    await run();
  } finally {
    await cleanupAdmin().catch((error) =>
      console.error("Limpieza del admin incompleta:", error));
    fs.rmSync(credentialDirectory, {recursive: true, force: true});
  }
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
