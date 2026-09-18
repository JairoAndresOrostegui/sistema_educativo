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
const permission = "mensajeria.ver";
const migrationId = "messaging_teacher_permissions_v1";

async function inspect() {
  const [teachers, parameters] = await Promise.all([
    db.collection("users")
        .where("role", "==", "Docente")
        .where("status", "==", "activo").get(),
    db.collection("parameters")
        .where("clave", "==", "permission")
        .where("valor", "==", permission).get(),
  ]);
  const pending = teachers.docs.filter((item) => {
    const permissions = Array.isArray(item.data().permissions) ?
      item.data().permissions : [];
    return !permissions.includes(permission);
  });
  return {teachers, pending, catalogMissing: parameters.empty};
}

async function applyMigration(state) {
  const writer = db.bulkWriter();
  if (state.catalogMissing) {
    writer.set(db.collection("parameters").doc("permission_mensajeria_ver"), {
      clave: "permission",
      etiqueta: "Mensajeria",
      renglon: "mensajeria",
      valor: permission,
      orden: 700,
      activo: true,
    }, {merge: true});
  }
  for (const teacher of state.pending) {
    const data = teacher.data();
    writer.set(
        db.collection("migration_backups_messaging_teacher_permissions_v1")
            .doc(teacher.id),
        {
          userId: teacher.id,
          role: data.role,
          status: data.status,
          permissions: Array.isArray(data.permissions) ? data.permissions : [],
          projectId,
          backedUpAt: FieldValue.serverTimestamp(),
        },
        {merge: false},
    );
    writer.update(teacher.ref, {
      permissions: FieldValue.arrayUnion(permission),
      updatedAt: FieldValue.serverTimestamp(),
    }, {lastUpdateTime: teacher.updateTime});
  }
  await writer.close();
  await db.collection("migration_audit").doc(migrationId).set({
    migration: migrationId,
    projectId,
    activeTeachers: state.teachers.size,
    updatedTeachers: state.pending.length,
    catalogCreated: state.catalogMissing,
    completedAt: FieldValue.serverTimestamp(),
  }, {merge: false});
}

async function main() {
  const before = await inspect();
  if (apply && (before.catalogMissing || before.pending.length)) {
    await applyMigration(before);
  }
  const after = await inspect();
  console.log(JSON.stringify({
    projectId,
    apply,
    verify,
    activeTeachers: after.teachers.size,
    teachersMissingPermission: after.pending.length,
    catalogMissing: after.catalogMissing,
  }));
  if (verify && (after.catalogMissing || after.pending.length)) {
    process.exitCode = 2;
  }
}

main().catch((error) => {
  console.error(error.code || error.message);
  process.exitCode = 1;
});
/* eslint-enable max-len */
