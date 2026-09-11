"use strict";
/* eslint-disable max-len */

const {applicationDefault, initializeApp} = require("firebase-admin/app");
const {FieldValue, getFirestore} = require("firebase-admin/firestore");
const crypto = require("crypto");
const fs = require("fs");
const os = require("os");
const path = require("path");

const projectArg = process.argv.find((value) => value.startsWith("--project="));
const projectId = projectArg?.split("=")[1] || process.env.GOOGLE_CLOUD_PROJECT;
if (!projectId) throw new Error("Indica --project=<firebase-project-id>.");

let credentialDirectory;
if (process.argv.includes("--firebase-cli-auth")) {
  const base = path.join(process.env.APPDATA,
      "npm/node_modules/firebase-tools/lib");
  const account = require(path.join(base, "auth")).getGlobalDefaultAccount();
  const api = require(path.join(base, "api"));
  if (!account?.tokens?.refresh_token) throw new Error("Firebase CLI sin sesion.");
  credentialDirectory = fs.mkdtempSync(path.join(os.tmpdir(), "supervised-chat-"));
  const credentialPath = path.join(credentialDirectory, "adc.json");
  fs.writeFileSync(credentialPath, JSON.stringify({
    type: "authorized_user",
    client_id: api.clientId(),
    client_secret: api.clientSecret(),
    refresh_token: account.tokens.refresh_token,
  }), {encoding: "utf8", mode: 0o600});
  process.env.GOOGLE_APPLICATION_CREDENTIALS = credentialPath;
}
initializeApp({credential: applicationDefault(), projectId});
const db = getFirestore();
const apply = process.argv.includes("--apply");
const verify = process.argv.includes("--verify");

function fullName(user) {
  return `${user.firstName || ""} ${user.lastName || ""}`.trim();
}

function memberData(members) {
  const memberUserIds = [...members.keys()].sort();
  const memberNames = {};
  const memberRoles = {};
  members.forEach((user, id) => {
    memberNames[id] = fullName(user);
    memberRoles[id] = user.role || "";
  });
  return {memberUserIds, memberNames, memberRoles};
}

async function main() {
  const [usersSnapshot, channelsSnapshot] = await Promise.all([
    db.collection("users").get(),
    db.collection("message_channels").get(),
  ]);
  const users = new Map(usersSnapshot.docs.map((item) =>
    [item.id, {uid: item.id, ...item.data()}]));
  const plans = [];
  let readReceiptWrites = 0;

  for (const channelSnapshot of channelsSnapshot.docs) {
    const channel = channelSnapshot.data();
    if (!["private", "supervised_student"].includes(channel.channelType)) continue;
    const currentIds = Array.isArray(channel.memberUserIds) ?
      channel.memberUserIds : [];
    const current = currentIds.map((id) => users.get(id)).filter(Boolean);
    let student = channel.supervisedStudentId ?
      users.get(channel.supervisedStudentId) : null;
    let staff = channel.supervisedStaffId ?
      users.get(channel.supervisedStaffId) : null;
    if (!student && channel.contextStudentId) {
      student = users.get(channel.contextStudentId);
    }
    if (!student) student = current.find((user) => user.role === "Estudiante");
    if (!staff) {
      staff = current.find((user) =>
        ["Docente", "Administrador"].includes(user.role));
    }
    if (!student || student.role !== "Estudiante" || !staff) {
      continue;
    }

    const families = [...users.values()].filter((user) =>
      user.role === "Familiar" && user.status === "activo" &&
      user.institution === student.institution && user.campus === student.campus &&
      Array.isArray(user.studentIds) && user.studentIds.includes(student.uid));
    const members = new Map([[student.uid, student], [staff.uid, staff]]);
    families.forEach((family) => members.set(family.uid, family));
    const data = {
      channelType: "supervised_student",
      title: "Conversacion supervisada",
      supervisedStudentId: student.uid,
      supervisedStaffId: staff.uid,
      contextStudentId: student.uid,
      contextStudentName: fullName(student),
      contextStudentGroupId: student.groupId || null,
      contextStudentGroupName: student.groupName || null,
      studentIds: [student.uid],
      teacherIds: staff.role === "Docente" ? [staff.uid] : [],
      familyIds: families.map((family) => family.uid),
      ...memberData(members),
      updatedAt: FieldValue.serverTimestamp(),
    };
    plans.push({ref: channelSnapshot.ref, before: channel, data});

    const messages = await channelSnapshot.ref.collection("messages").get();
    for (const message of messages.docs) {
      const messageData = message.data();
      const sequence = Number(messageData.sequence || 0);
      const existingReads = messageData.readAtByUser || {};
      const reads = {};
      const readNames = {};
      const readRoles = {};
      for (const [uid, readSequence] of Object.entries(channel.readSequences || {})) {
        if (uid !== messageData.senderId && Number(readSequence) >= sequence &&
            !existingReads[uid] && channel.readAtByUser?.[uid]) {
          reads[uid] = channel.readAtByUser[uid];
          readNames[uid] = fullName(users.get(uid) || {}) || "Usuario";
          readRoles[uid] = users.get(uid)?.role || "";
        }
      }
      const recipients = [...members.keys()].filter((uid) =>
        uid !== messageData.senderId);
      const updates = {
        recipientUserIds: recipients,
        recipientNames: Object.fromEntries(recipients.map((uid) =>
          [uid, fullName(members.get(uid)) || "Usuario"])),
        recipientRoles: Object.fromEntries(recipients.map((uid) =>
          [uid, members.get(uid)?.role || ""])),
      };
      for (const [uid, date] of Object.entries(reads)) {
        updates[`readAtByUser.${uid}`] = date;
        updates[`readNames.${uid}`] = readNames[uid];
        updates[`readRoles.${uid}`] = readRoles[uid];
      }
      data._messageUpdates = data._messageUpdates || [];
      data._messageUpdates.push({ref: message.ref, updates});
      if (Object.keys(reads).length) {
        readReceiptWrites += 1;
      }
    }
  }

  const result = {
    projectId,
    mode: verify ? "verify" : apply ? "apply" : "dry-run",
    supervisedChannels: plans.length,
    channelsConverted: plans.filter((plan) =>
      plan.before.channelType !== "supervised_student").length,
    readReceiptWrites,
  };
  if (verify) {
    const invalid = plans.filter((plan) =>
      plan.before.channelType !== "supervised_student" ||
      !plan.before.supervisedStudentId || !plan.before.supervisedStaffId);
    if (invalid.length) {
      throw new Error(`${invalid.length} conversaciones requieren migracion.`);
    }
    console.log(JSON.stringify({...result, ok: true}, null, 2));
    return;
  }
  if (!apply) {
    console.log(JSON.stringify(result, null, 2));
    return;
  }

  for (const plan of plans) {
    const messageUpdates = plan.data._messageUpdates || [];
    delete plan.data._messageUpdates;
    await plan.ref.set(plan.data, {merge: true});
    for (let index = 0; index < messageUpdates.length; index += 400) {
      const batch = db.batch();
      for (const message of messageUpdates.slice(index, index + 400)) {
        batch.update(message.ref, message.updates);
      }
      await batch.commit();
    }
  }
  await db.collection("migration_backups")
      .doc(`supervised_student_channels_v1_${crypto.randomUUID()}`).set({
        ...result,
        appliedAt: FieldValue.serverTimestamp(),
      });
  console.log(JSON.stringify({...result, applied: true}, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}).finally(() => {
  if (credentialDirectory) {
    fs.rmSync(credentialDirectory, {recursive: true, force: true});
  }
});
