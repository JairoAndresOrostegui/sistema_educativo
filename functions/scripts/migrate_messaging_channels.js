"use strict";
/* eslint-disable max-len */

const {applicationDefault, initializeApp} = require("firebase-admin/app");
const {FieldValue, getFirestore} = require("firebase-admin/firestore");
const fs = require("fs");
const os = require("os");
const path = require("path");

function firebaseToolsModule(relativePath) {
  const roots = [
    process.env.APPDATA ? path.join(process.env.APPDATA, "npm", "node_modules") : "",
    ...require("module").globalPaths,
  ].filter(Boolean);
  const root = roots.find((item) => fs.existsSync(path.join(item, "firebase-tools")));
  if (!root) throw new Error("No se encontro Firebase CLI.");
  return require(path.join(root, "firebase-tools", relativePath));
}

let credential;
let credentialDirectory;
if (process.argv.includes("--firebase-cli-auth")) {
  const firebaseAuth = firebaseToolsModule("lib/auth");
  const firebaseApi = firebaseToolsModule("lib/api");
  const account = firebaseAuth.getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) {
    throw new Error("Firebase CLI no tiene una sesion activa.");
  }
  credentialDirectory = fs.mkdtempSync(path.join(os.tmpdir(), "messaging-migration-"));
  const credentialPath = path.join(credentialDirectory, "adc.json");
  fs.writeFileSync(credentialPath, JSON.stringify({
    type: "authorized_user",
    client_id: firebaseApi.clientId(),
    client_secret: firebaseApi.clientSecret(),
    refresh_token: account.tokens.refresh_token,
  }), {encoding: "utf8", mode: 0o600});
  process.env.GOOGLE_APPLICATION_CREDENTIALS = credentialPath;
  credential = applicationDefault();
}

initializeApp({credential});
const db = getFirestore();
const apply = process.argv.includes("--apply");
const verify = process.argv.includes("--verify");

function name(user) {
  return `${user.firstName || ""} ${user.lastName || ""}`.trim();
}

function memberData(users) {
  const memberUserIds = [...users.keys()].sort();
  const memberNames = {};
  const memberRoles = {};
  users.forEach((user, id) => {
    memberNames[id] = name(user);
    memberRoles[id] = user.role || "";
  });
  return {memberUserIds, memberNames, memberRoles};
}

async function commitWrites(writes) {
  for (let index = 0; index < writes.length; index += 400) {
    const batch = db.batch();
    for (const write of writes.slice(index, index + 400)) write(batch);
    await batch.commit();
  }
}

async function loadState() {
  const [groups, users, subjects, legacy, channels] = await Promise.all([
    db.collection("academic_groups").get(),
    db.collection("users").get(),
    db.collection("subjects").get(),
    db.collection("message_threads").get(),
    db.collection("message_channels").get(),
  ]);
  return {groups, users, subjects, legacy, channels};
}

async function run() {
  const state = await loadState();
  const users = new Map(state.users.docs.map((item) => [item.id, item.data()]));
  const plans = [];
  for (const groupDocument of state.groups.docs) {
    const group = groupDocument.data();
    const students = [...users].filter(([, user]) =>
      user.role === "Estudiante" && user.status === "activo" &&
      user.institution === group.institutionId && user.campus === group.campusId &&
      user.groupId === groupDocument.id);
    const studentIds = students.map(([id]) => id);
    const teacherIds = new Set(state.subjects.docs.filter((item) => {
      const subject = item.data();
      return subject.academicYearId === group.academicYearId &&
        subject.groupId === groupDocument.id;
    }).map((item) => item.data().teacherId));
    for (const [id, user] of users) {
      if (user.role === "Docente" && user.status === "activo" &&
          user.tutorGroupId === groupDocument.id) teacherIds.add(id);
    }
    const members = new Map(students);
    for (const teacherId of teacherIds) {
      const teacher = users.get(teacherId);
      if (teacher?.status === "activo") members.set(teacherId, teacher);
    }
    const familyIds = [];
    for (const [id, user] of users) {
      if (user.role !== "Familiar" || user.status !== "activo" ||
          user.institution !== group.institutionId || user.campus !== group.campusId) continue;
      if (Array.isArray(user.studentIds) &&
          user.studentIds.some((studentId) => studentIds.includes(studentId))) {
        members.set(id, user);
        familyIds.push(id);
      }
    }
    const channelRef = db.collection("message_channels")
        .doc(`academic_${groupDocument.id}`);
    const channelExists = state.channels.docs.some((item) =>
      item.ref.path === channelRef.path);
    plans.push({
      ref: channelRef,
      data: {
        channelType: "academic_group", category: "academic", iconKey: "school",
        title: `Grupo ${group.name || groupDocument.id}`,
        groupId: groupDocument.id, groupName: group.name || groupDocument.id,
        institutionId: group.institutionId, campusId: group.campusId,
        academicYearId: group.academicYearId, academicYear: group.academicYear,
        status: group.active === true ? "active" : "archived",
        postingPolicy: "members", studentIds,
        teacherIds: [...teacherIds], familyIds: [...new Set(familyIds)],
        ...memberData(members),
        ...(channelExists ? {} : {
          mutedByAdmin: false, messageSequence: 0,
          readSequences: {}, readAtByUser: {},
          createdAt: FieldValue.serverTimestamp(),
        }),
        updatedAt: FieldValue.serverTimestamp(),
      },
    });
  }

  const legacyPlans = [];
  for (const legacy of state.legacy.docs) {
    const data = legacy.data();
    const messages = await legacy.ref.collection("messages")
        .orderBy("createdAt").get();
    const ids = Array.isArray(data.participantIds) ? data.participantIds : [];
    const members = new Map(ids.filter((id) => users.has(id))
        .map((id) => [id, users.get(id)]));
    const target = db.collection("message_channels").doc(`legacy_${legacy.id}`);
    legacyPlans.push({legacy, target, messages, data: {
      channelType: "private", category: "private", iconKey: "private",
      title: "Conversacion privada", institutionId: data.institutionId,
      campusId: data.campusId, academicYearId: data.academicYearId,
      academicYear: data.academicYear, status: "active", postingPolicy: "members",
      mutedByAdmin: false,
      contextStudentId: data.contextStudentId || null,
      contextStudentName: data.contextStudentName || null,
      contextStudentGroupId: data.contextStudentGroupId || null,
      contextStudentGroupName: data.contextStudentGroupName || null,
      messageSequence: messages.size, readSequences: {}, readAtByUser: {},
      lastMessage: data.lastMessage || null, lastSenderId: data.lastSenderId || null,
      lastSenderName: data.lastSenderName || null,
      lastMessageAt: data.lastMessageAt || null, ...memberData(members),
      createdAt: data.createdAt || FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }});
  }

  const summary = {
    mode: verify ? "verify" : apply ? "apply" : "dry-run",
    academicChannels: plans.length,
    legacyThreads: legacyPlans.length,
    legacyMessages: legacyPlans.reduce((total, item) => total + item.messages.size, 0),
    existingChannels: state.channels.size,
  };
  if (verify) {
    const missing = plans.filter((plan) =>
      !state.channels.docs.some((item) => item.ref.path === plan.ref.path));
    if (state.legacy.size || missing.length) {
      throw new Error(`Verificacion fallo: ${state.legacy.size} hilos antiguos y ` +
        `${missing.length} canales academicos faltantes.`);
    }
    console.log(JSON.stringify({...summary, ok: true}, null, 2));
    return;
  }
  if (!apply) {
    console.log(JSON.stringify(summary, null, 2));
    return;
  }
  await commitWrites(plans.map((plan) => (batch) =>
    batch.set(plan.ref, plan.data, {merge: true})));
  for (const plan of legacyPlans) {
    await plan.target.set(plan.data, {merge: true});
    let sequence = 0;
    await commitWrites(plan.messages.docs.map((message) => (batch) => {
      sequence += 1;
      batch.set(plan.target.collection("messages").doc(message.id), {
        ...message.data(), sequence,
      });
    }));
    await commitWrites(plan.messages.docs.map((message) =>
      (batch) => batch.delete(message.ref)));
    await plan.legacy.ref.delete();
  }
  await db.collection("migration_backups").doc("messaging_channels_v1").set({
    ...summary, appliedAt: FieldValue.serverTimestamp(),
  });
  console.log(JSON.stringify({...summary, applied: true}, null, 2));
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}).finally(() => {
  if (credentialDirectory) {
    fs.rmSync(credentialDirectory, {recursive: true, force: true});
  }
});
