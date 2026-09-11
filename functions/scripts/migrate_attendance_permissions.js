"use strict";

const {FieldValue} = require("firebase-admin/firestore");
const {Firestore} = require("@google-cloud/firestore");
const {cloudCredentials} = require("./cloud_access");

const projectArgument = process.argv.find((item) =>
  item.startsWith("--project="));
const projectId = projectArgument?.split("=")[1];
const allowedProjects = new Set([
  "sistema-educativo-rl",
  "sistema-educativo-rl-prod",
]);
if (!allowedProjects.has(projectId)) {
  throw new Error("Indica --project con el proyecto QA o produccion.");
}

const db = new Firestore({projectId, credentials: cloudCredentials()});
const apply = process.argv.includes("--apply");
const verify = process.argv.includes("--verify");
const permissionsByRole = new Map([
  ["Administrador", [
    "asistencia.ver", "asistencia.crear", "asistencia.editar",
  ]],
  ["Docente", ["asistencia.ver", "asistencia.crear"]],
  ["Estudiante", ["asistencia.ver"]],
  ["Familiar", ["asistencia.ver"]],
]);
const catalog = [
  {id: "permission_asistencia_ver", valor: "asistencia.ver", orden: 920},
  {id: "permission_asistencia_crear", valor: "asistencia.crear", orden: 921},
  {id: "permission_asistencia_editar", valor: "asistencia.editar", orden: 922},
];

async function inspect() {
  const [parameters, users] = await Promise.all([
    db.collection("parameters").where("clave", "==", "permission").get(),
    db.collection("users").where("status", "==", "activo").get(),
  ]);
  const existing = new Set(parameters.docs.map((item) => item.data().valor));
  const eligible = users.docs.filter((item) =>
    permissionsByRole.has(item.data().role));
  const pending = eligible.filter((item) => {
    const required = permissionsByRole.get(item.data().role);
    const current = Array.isArray(item.data().permissions) ?
      item.data().permissions : [];
    return required.some((permission) => !current.includes(permission));
  });
  return {
    missingCatalog: catalog.filter((item) => !existing.has(item.valor)),
    eligible,
    pending,
  };
}

async function main() {
  const before = await inspect();
  if (apply && (before.missingCatalog.length || before.pending.length)) {
    const writer = db.bulkWriter();
    for (const item of catalog) {
      writer.set(db.collection("parameters").doc(item.id), {
        clave: "permission",
        etiqueta: "Lista de asistencia",
        renglon: "asistencia",
        valor: item.valor,
        orden: item.orden,
        activo: true,
      }, {merge: true});
    }
    for (const user of before.pending) {
      writer.update(user.ref, {
        permissions: FieldValue.arrayUnion(
            ...permissionsByRole.get(user.data().role),
        ),
        updatedAt: FieldValue.serverTimestamp(),
      }, {lastUpdateTime: user.updateTime});
    }
    await writer.close();
    await db.collection("migration_audit").doc("attendance_permissions_v1")
        .set({
          projectId,
          migration: "attendance_permissions_v1",
          eligibleUsers: before.eligible.length,
          updatedUsers: before.pending.length,
          completedAt: FieldValue.serverTimestamp(),
        });
  }
  const after = await inspect();
  console.log(JSON.stringify({
    projectId,
    apply,
    verify,
    eligibleUsers: after.eligible.length,
    missingCatalog: after.missingCatalog.length,
    usersMissingPermissions: after.pending.length,
  }));
  if (verify && (after.missingCatalog.length || after.pending.length)) {
    process.exitCode = 2;
  }
}

main().catch((error) => {
  console.error(error.code || error.message);
  process.exitCode = 1;
});
