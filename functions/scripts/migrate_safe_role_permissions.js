"use strict";
/* eslint-disable max-len */

const {FieldValue} = require("firebase-admin/firestore");
const {Firestore} = require("@google-cloud/firestore");
const {cloudCredentials} = require("./cloud_access");

const allowedProjects = new Set([
  "sistema-educativo-rl",
  "sistema-educativo-rl-prod",
]);
const projectArgument = process.argv.find((item) => item.startsWith("--project="));
const projectId = projectArgument?.split("=")[1];
if (!allowedProjects.has(projectId)) {
  throw new Error("Indica --project con el proyecto QA o produccion.");
}

const apply = process.argv.includes("--apply");
const verify = process.argv.includes("--verify");
const db = new Firestore({projectId, credentials: cloudCredentials()});
const migrationId = "safe_role_permissions_v1";

const permissionsByRole = new Map([
  ["Administrador", [
    "usuarios.ver",
    "matricula.ver", "matricula.editar",
    "autorizaciones.ver", "autorizaciones.editar",
    "horarios.ver", "horarios.crear", "horarios.editar",
    "archivos.ver", "archivos.crear",
    "mensajeria.ver",
    "codigoqr.crear",
    "rutas.ver", "rutas.crear", "rutas.editar",
    "sitio_web.ver", "parametros.ver",
    "asistencia.ver", "asistencia.crear", "asistencia.editar",
    "eventos.ver", "eventos.crear", "eventos.editar",
  ]],
  ["Docente", [
    "matricula.ver", "autorizaciones.ver", "horarios.ver",
    "archivos.ver", "archivos.crear", "mensajeria.ver", "rutas.ver",
    "asistencia.ver", "asistencia.crear",
    "eventos.ver", "eventos.crear", "eventos.editar",
  ]],
  ["Auxiliar", ["rutas.ver"]],
  ["Estudiante", [
    "horarios.ver", "archivos.ver", "mensajeria.ver", "rutas.ver",
    "asistencia.ver", "eventos.ver",
  ]],
  ["Familiar", [
    "matricula.ver", "autorizaciones.ver", "horarios.ver", "archivos.ver",
    "mensajeria.ver", "rutas.ver", "asistencia.ver", "eventos.ver",
  ]],
]);

// Estos permisos permiten cambios destructivos, administración de identidades
// o configuración global. Permanecen exclusivamente en superadministradores.
const forbiddenForRegularUsers = new Set([
  "usuarios.crear", "usuarios.editar", "usuarios.eliminar",
  "horarios.eliminar", "archivos.eliminar", "rutas.eliminar",
  "codigoqr.editar", "historial.ver", "sitio_web.editar",
  "parametros.editar",
]);

function normalizedPermissions(user) {
  const required = permissionsByRole.get(user.role) || [];
  const current = Array.isArray(user.permissions) ? user.permissions : [];
  return [...new Set([...current, ...required]
      .filter((item) => typeof item === "string" && item.trim())
      .map((item) => item.trim())
      .filter((item) => !forbiddenForRegularUsers.has(item)))]
      .sort();
}

function samePermissions(left, right) {
  const a = [...left].sort();
  const b = [...right].sort();
  return a.length === b.length && a.every((item, index) => item === b[index]);
}

function memberData(members) {
  const memberUserIds = [...members.keys()].sort();
  const memberNames = {};
  const memberRoles = {};
  for (const [userId, user] of members) {
    memberNames[userId] = `${user.firstName || ""} ${user.lastName || ""}`.trim();
    memberRoles[userId] = user.role || "";
  }
  return {memberUserIds, memberNames, memberRoles};
}

function sameJson(left, right) {
  return JSON.stringify(left) === JSON.stringify(right);
}

async function synchronizeMessagingMemberships() {
  const [groups, users, subjects, channels] = await Promise.all([
    db.collection("academic_groups").where("active", "==", true).get(),
    db.collection("users").where("status", "==", "activo").get(),
    db.collection("subjects").get(),
    db.collection("message_channels").get(),
  ]);
  const userMap = new Map(users.docs.map((item) => [item.id, item.data()]));
  const channelMap = new Map(channels.docs.map((item) =>
    [item.id, item.data()]));
  const audienceByGroup = new Map();
  for (const groupDocument of groups.docs) {
    const group = groupDocument.data();
    const students = users.docs.filter((item) => {
      const user = item.data();
      return user.role === "Estudiante" && user.groupId === groupDocument.id &&
        user.institution === group.institutionId && user.campus === group.campusId;
    });
    const studentIds = students.map((item) => item.id);
    const teacherIds = new Set(subjects.docs.filter((item) => {
      const subject = item.data();
      return subject.academicYearId === group.academicYearId &&
        subject.institutionId === group.institutionId &&
        subject.campusId === group.campusId &&
        subject.groupId === groupDocument.id;
    }).map((item) => item.data().teacherId));
    users.docs.forEach((item) => {
      const user = item.data();
      if (user.role === "Docente" &&
          user.institution === group.institutionId &&
          user.campus === group.campusId &&
          user.tutorGroupId === groupDocument.id) teacherIds.add(item.id);
    });
    const activeTeachers = [...teacherIds].filter((userId) => {
      const user = userMap.get(userId);
      return user?.role === "Docente" &&
        user.institution === group.institutionId &&
        user.campus === group.campusId;
    });
    const families = users.docs.filter((item) => {
      const user = item.data();
      return user.role === "Familiar" &&
        user.institution === group.institutionId &&
        user.campus === group.campusId &&
        Array.isArray(user.studentIds) &&
        user.studentIds.some((studentId) => studentIds.includes(studentId));
    });
    const admins = users.docs.filter((item) => {
      const user = item.data();
      return user.role === "Administrador" &&
        user.institution === group.institutionId &&
        user.campus === group.campusId;
    });
    const members = new Map();
    [...students, ...families, ...admins].forEach((item) =>
      members.set(item.id, item.data()));
    activeTeachers.forEach((userId) =>
      members.set(userId, userMap.get(userId)));
    audienceByGroup.set(groupDocument.id, {
      group,
      studentIds,
      teacherIds: activeTeachers.sort(),
      familyIds: families.map((item) => item.id).sort(),
      members,
    });
  }

  const plans = [];
  for (const [groupId, audience] of audienceByGroup) {
    const channelId = `academic_${groupId}`;
    const current = channelMap.get(channelId);
    const membership = memberData(audience.members);
    const desired = {
      ...membership,
      studentIds: [...audience.studentIds].sort(),
      teacherIds: audience.teacherIds,
      familyIds: audience.familyIds,
      status: "active",
    };
    const unchanged = current && Object.entries(desired).every(([key, value]) =>
      sameJson(current[key], value));
    if (!unchanged) {
      plans.push({
        id: channelId,
        type: "academic_group",
        before: current || null,
        data: current ? desired : {
          channelType: "academic_group",
          category: "academic",
          iconKey: "school",
          title: `Grupo ${audience.group.name || groupId}`,
          groupId,
          groupName: audience.group.name || groupId,
          institutionId: audience.group.institutionId,
          campusId: audience.group.campusId,
          academicYearId: audience.group.academicYearId,
          academicYear: audience.group.academicYear,
          postingPolicy: "members",
          mutedByAdmin: false,
          messageSequence: 0,
          readSequences: {},
          readAtByUser: {},
          createdAt: FieldValue.serverTimestamp(),
          ...desired,
        },
      });
    }
  }
  for (const channelDocument of channels.docs) {
    const channel = channelDocument.data();
    if (channel.channelType !== "service" || channel.status !== "active") {
      continue;
    }
    const members = new Map();
    for (const groupId of channel.targetGroupIds || []) {
      for (const [userId, user] of
        audienceByGroup.get(groupId)?.members || []) members.set(userId, user);
    }
    users.docs.filter((item) => {
      const user = item.data();
      return user.role === "Administrador" &&
        user.institution === channel.institutionId &&
        user.campus === channel.campusId;
    }).forEach((item) => members.set(item.id, item.data()));
    const desired = memberData(members);
    if (!Object.entries(desired).every(([key, value]) =>
      sameJson(channel[key], value))) {
      plans.push({
        id: channelDocument.id,
        type: "service",
        before: channel,
        data: desired,
      });
    }
  }

  const writer = db.bulkWriter();
  for (const plan of plans) {
    const before = plan.before || {};
    writer.set(
        db.collection("migration_backups_safe_role_permissions_v1_channels")
            .doc(plan.id),
        {
          channelId: plan.id,
          channelType: plan.type,
          existed: plan.before !== null,
          memberUserIds: before.memberUserIds || [],
          memberNames: before.memberNames || {},
          memberRoles: before.memberRoles || {},
          studentIds: before.studentIds || [],
          teacherIds: before.teacherIds || [],
          familyIds: before.familyIds || [],
          projectId,
          backedUpAt: FieldValue.serverTimestamp(),
        },
        {merge: false},
    );
    writer.set(db.collection("message_channels").doc(plan.id), {
      ...plan.data,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  }
  await writer.close();
  await db.collection("migration_audit")
      .doc(`${migrationId}_messaging_sync`).set({
        migration: `${migrationId}_messaging_sync`,
        projectId,
        synchronizedChannels: plans.length,
        academicGroups: audienceByGroup.size,
        completedAt: FieldValue.serverTimestamp(),
      }, {merge: false});
  return plans.length;
}

async function inspect() {
  const [users, backups, audit, groups, subjects, channels] = await Promise.all([
    db.collection("users").where("status", "==", "activo").get(),
    db.collection("migration_backups_safe_role_permissions_v1").get(),
    db.collection("migration_audit").doc(migrationId).get(),
    db.collection("academic_groups").where("active", "==", true).get(),
    db.collection("subjects").get(),
    db.collection("message_channels").get(),
  ]);
  const eligible = users.docs.filter((item) =>
    item.data().isSuperadmin !== true &&
    permissionsByRole.has(item.data().role));
  const pending = eligible.filter((item) => {
    const current = Array.isArray(item.data().permissions) ?
      item.data().permissions : [];
    return !samePermissions(current, normalizedPermissions(item.data()));
  });
  const byRole = {};
  const pendingByRole = {};
  const additions = {};
  const removals = {};
  for (const item of eligible) {
    const role = item.data().role;
    byRole[role] = (byRole[role] || 0) + 1;
  }
  for (const item of pending) {
    const data = item.data();
    const role = data.role;
    const before = new Set(Array.isArray(data.permissions) ?
      data.permissions : []);
    const after = new Set(normalizedPermissions(data));
    pendingByRole[role] = (pendingByRole[role] || 0) + 1;
    for (const permission of after) {
      if (!before.has(permission)) {
        additions[permission] = (additions[permission] || 0) + 1;
      }
    }
    for (const permission of before) {
      if (!after.has(permission)) {
        removals[permission] = (removals[permission] || 0) + 1;
      }
    }
  }
  const userMap = new Map(users.docs.map((item) => [item.id, item.data()]));
  const channelMap = new Map(channels.docs.map((item) =>
    [item.id, item.data()]));
  const expectedByGroup = new Map();
  for (const groupDocument of groups.docs) {
    const group = groupDocument.data();
    const studentIds = users.docs.filter((item) => {
      const user = item.data();
      return user.role === "Estudiante" && user.groupId === groupDocument.id &&
        user.institution === group.institutionId && user.campus === group.campusId;
    }).map((item) => item.id);
    const expected = new Set(studentIds);
    subjects.docs.filter((item) => {
      const subject = item.data();
      return subject.academicYearId === group.academicYearId &&
        subject.institutionId === group.institutionId &&
        subject.campusId === group.campusId &&
        subject.groupId === groupDocument.id;
    }).forEach((item) => expected.add(item.data().teacherId));
    users.docs.forEach((item) => {
      const user = item.data();
      if (user.institution !== group.institutionId ||
          user.campus !== group.campusId) return;
      if (user.role === "Docente" && user.tutorGroupId === groupDocument.id) {
        expected.add(item.id);
      }
      if (user.role === "Administrador") expected.add(item.id);
      if (user.role === "Familiar" && Array.isArray(user.studentIds) &&
          user.studentIds.some((studentId) => studentIds.includes(studentId))) {
        expected.add(item.id);
      }
    });
    expectedByGroup.set(groupDocument.id, expected);
  }
  const membershipGaps = [];
  for (const [groupId, expected] of expectedByGroup) {
    const channel = channelMap.get(`academic_${groupId}`);
    const actual = new Set(channel?.memberUserIds || []);
    for (const userId of expected) {
      const user = userMap.get(userId);
      if (user?.permissions?.includes("mensajeria.ver") &&
          !actual.has(userId)) {
        membershipGaps.push(`academic_${groupId}:${userId}`);
      }
    }
  }
  for (const channelDocument of channels.docs) {
    const channel = channelDocument.data();
    if (channel.channelType !== "service" || channel.status !== "active") {
      continue;
    }
    const expected = new Set();
    for (const groupId of channel.targetGroupIds || []) {
      for (const userId of expectedByGroup.get(groupId) || []) {
        expected.add(userId);
      }
    }
    const actual = new Set(channel.memberUserIds || []);
    for (const userId of expected) {
      const user = userMap.get(userId);
      if (user?.permissions?.includes("mensajeria.ver") &&
          !actual.has(userId)) {
        membershipGaps.push(`${channelDocument.id}:${userId}`);
      }
    }
  }
  return {
    eligible,
    pending,
    byRole,
    pendingByRole,
    additions,
    removals,
    backupCount: backups.size,
    auditRecorded: audit.exists,
    auditedUpdates: Number(audit.data()?.updatedUsers || 0),
    messagingMembershipGaps: membershipGaps.length,
  };
}

async function applyMigration(state) {
  const writer = db.bulkWriter();
  for (const user of state.pending) {
    const data = user.data();
    const before = Array.isArray(data.permissions) ? data.permissions : [];
    const after = normalizedPermissions(data);
    writer.set(
        db.collection("migration_backups_safe_role_permissions_v1")
            .doc(user.id),
        {
          userId: user.id,
          role: data.role,
          status: data.status,
          permissions: before,
          resultingPermissions: after,
          projectId,
          backedUpAt: FieldValue.serverTimestamp(),
        },
        {merge: false},
    );
    writer.update(user.ref, {
      permissions: after,
      updatedAt: FieldValue.serverTimestamp(),
    }, {lastUpdateTime: user.updateTime});
  }
  await writer.close();
  await db.collection("migration_audit").doc(migrationId).set({
    migration: migrationId,
    projectId,
    eligibleUsers: state.eligible.length,
    updatedUsers: state.pending.length,
    roles: state.byRole,
    forbiddenPermissions: [...forbiddenForRegularUsers].sort(),
    completedAt: FieldValue.serverTimestamp(),
  }, {merge: false});
}

async function main() {
  const before = await inspect();
  if (apply && before.pending.length) await applyMigration(before);
  const synchronizedChannels = apply ?
    await synchronizeMessagingMemberships() : 0;
  const after = await inspect();
  console.log(JSON.stringify({
    projectId,
    apply,
    verify,
    eligibleUsers: after.eligible.length,
    usersPending: after.pending.length,
    roles: after.byRole,
    pendingByRole: apply ? before.pendingByRole : after.pendingByRole,
    additions: apply ? before.additions : after.additions,
    removals: apply ? before.removals : after.removals,
    plannedUpdates: apply ? before.pending.length : after.pending.length,
    backupCount: after.backupCount,
    auditRecorded: after.auditRecorded,
    auditedUpdates: after.auditedUpdates,
    messagingMembershipGaps: after.messagingMembershipGaps,
    synchronizedChannels,
  }));
  if (verify && (after.pending.length || !after.auditRecorded ||
      after.backupCount < after.auditedUpdates ||
      after.messagingMembershipGaps)) process.exitCode = 2;
}

main().catch((error) => {
  console.error(error.code || error.message);
  process.exitCode = 1;
});
/* eslint-enable max-len */
