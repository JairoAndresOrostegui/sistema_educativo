"use strict";

const {applicationDefault, initializeApp} = require("firebase-admin/app");
const {
  FieldPath,
  FieldValue,
  getFirestore,
} = require("firebase-admin/firestore");
const {getStorage} = require("firebase-admin/storage");
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

let credential;
if (process.argv.includes("--firebase-cli-auth")) {
  const firebaseAuth = firebaseToolsModule("lib/auth");
  const firebaseApi = firebaseToolsModule("lib/api");
  const account = firebaseAuth.getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) {
    throw new Error("Firebase CLI no tiene una sesion activa.");
  }
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "file-audience-"));
  const credentialPath = path.join(directory, "credentials.json");
  fs.writeFileSync(credentialPath, JSON.stringify({
    type: "authorized_user",
    client_id: firebaseApi.clientId(),
    client_secret: firebaseApi.clientSecret(),
    refresh_token: account.tokens.refresh_token,
  }), {encoding: "utf8", mode: 0o600});
  process.env.GOOGLE_APPLICATION_CREDENTIALS = credentialPath;
  credential = applicationDefault();
}

initializeApp({
  credential,
  storageBucket: process.env.FIREBASE_STORAGE_BUCKET ||
    "sistema-educativo-rl.firebasestorage.app",
});
const db = getFirestore();
const bucket = getStorage().bucket();
const apply = process.argv.includes("--apply");
const verify = process.argv.includes("--verify");

async function usersByIds(base, ids) {
  const documents = [];
  for (let index = 0; index < ids.length; index += 30) {
    const snapshot = await base.where(FieldPath.documentId(), "in",
        ids.slice(index, index + 30)).get();
    documents.push(...snapshot.docs);
  }
  return documents;
}

async function audienceFor(file) {
  const institution = file.institutionId;
  const campus = file.campusId;
  const groupIds = Array.isArray(file.targetGroupIds) ?
    file.targetGroupIds : [file.groupId].filter(Boolean);
  const groupDocs = await Promise.all(groupIds.map((id) =>
    db.collection("academic_groups").doc(id).get()));
  if (!institution || !campus || groupDocs.some((item) => !item.exists)) {
    throw new Error("El archivo no tiene una sede y grupos validos.");
  }
  const base = db.collection("users")
      .where("institution", "==", institution)
      .where("campus", "==", campus);
  const studentSnapshots = await Promise.all(groupIds.map((groupId) =>
    base.where("role", "==", "Estudiante")
        .where("status", "==", "activo")
        .where("groupId", "==", groupId).get()));
  const students = studentSnapshots.flatMap((item) => item.docs);
  const studentIds = students.map((item) => item.id);
  const recipients = new Set(studentIds);
  const recipientContextKeys = new Set();
  for (let index = 0; index < studentIds.length; index += 30) {
    const families = await base.where("role", "==", "Familiar")
        .where("status", "==", "activo")
        .where("studentIds", "array-contains-any",
            studentIds.slice(index, index + 30)).get();
    families.docs.forEach((item) => {
      recipients.add(item.id);
      const links = Array.isArray(item.data().studentIds) ?
        item.data().studentIds : [];
      studentIds.filter((id) => links.includes(id))
          .forEach((id) => recipientContextKeys.add(`${item.id}:${id}`));
    });
  }
  const uploader = await db.collection("users").doc(file.uploadedBy).get();
  if (uploader.exists && (uploader.data().role === "Administrador" ||
      uploader.data().isSuperadmin === true)) {
    const teacherIds = new Set();
    for (const groupId of groupIds) {
      const subjects = await db.collection("subjects")
          .where("institutionId", "==", institution)
          .where("campusId", "==", campus)
          .where("groupId", "==", groupId).get();
      subjects.docs.forEach((item) => teacherIds.add(item.data().teacherId));
    }
    const teachers = await usersByIds(base, [...teacherIds].filter(Boolean));
    teachers.filter((item) => item.data().status === "activo")
        .forEach((item) => recipients.add(item.id));
  }
  if (file.uploadedBy) recipients.add(file.uploadedBy);
  return {
    audienceType: "groups",
    targetGroupIds: groupIds,
    targetGroupNames: groupDocs.map((item) => item.data().name || item.id),
    targetStudentIds: studentIds,
    recipientUserIds: [...recipients],
    recipientContextKeys: [...recipientContextKeys],
  };
}

async function migrate(document) {
  const file = document.data();
  const audience = await audienceFor(file);
  const fileName = (file.name || document.id).toString()
      .replace(/[\\/#?]/g, "_");
  const oldPath = (file.storagePath || "").toString();
  const newPath = `files/${document.id}/${fileName}`;
  console.log(`${document.ref.path}: ${oldPath} -> ${newPath}`);
  if (!apply) return;

  let copied = false;
  if (oldPath && oldPath !== newPath) {
    const oldObject = bucket.file(oldPath);
    const [exists] = await oldObject.exists();
    if (!exists) throw new Error(`No existe ${oldPath}.`);
    await oldObject.copy(bucket.file(newPath));
    copied = true;
  }
  try {
    await document.ref.update({
      ...audience,
      message: typeof file.message === "string" ? file.message : "",
      sentAt: file.sentAt || file.confirmedAt || file.createdAt ||
        FieldValue.serverTimestamp(),
      storagePath: newPath,
      groupId: FieldValue.delete(),
      groupName: FieldValue.delete(),
      migratedFileAudienceAt: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    if (copied) await bucket.file(newPath).delete({ignoreNotFound: true});
    throw error;
  }
  if (copied) await bucket.file(oldPath).delete({ignoreNotFound: true});
}

async function verifyMigration() {
  const snapshot = await db.collection("files").get();
  const violations = [];
  for (const document of snapshot.docs) {
    const file = document.data();
    const expectedPrefix = `files/${document.id}/`;
    if (!["all", "groups", "students"].includes(file.audienceType) ||
        !Array.isArray(file.targetGroupIds) ||
        !Array.isArray(file.targetStudentIds) ||
        !Array.isArray(file.recipientUserIds) || !file.sentAt ||
        !Array.isArray(file.recipientContextKeys) ||
        Object.hasOwn(file, "groupId") ||
        !file.storagePath?.startsWith(expectedPrefix)) {
      violations.push(`${document.ref.path}: esquema no canonico`);
      continue;
    }
    if (file.status === "active" &&
        !(await bucket.file(file.storagePath).exists())[0]) {
      violations.push(`${document.ref.path}: objeto ausente`);
    }
  }
  console.log(JSON.stringify({files: snapshot.size, violations}, null, 2));
  if (violations.length) throw new Error("La verificacion fallo.");
}

async function main() {
  if (verify) return verifyMigration();
  console.log(apply ? "MODO APPLY" : "MODO DRY-RUN");
  const snapshot = await db.collection("files").get();
  for (const document of snapshot.docs) await migrate(document);
  console.log(`${snapshot.size} archivos ${apply ? "migrados" : "planeados"}.`);
}

main().then(() => process.exit(0)).catch((error) => {
  console.error(error);
  process.exit(1);
});
