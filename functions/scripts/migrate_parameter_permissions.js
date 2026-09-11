"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");
const {applicationDefault, initializeApp} = require("firebase-admin/app");
const {FieldValue, getFirestore} = require("firebase-admin/firestore");

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

const firebaseToolsBase = path.join(
    process.env.APPDATA, "npm/node_modules/firebase-tools/lib",
);
const account = require(path.join(firebaseToolsBase, "auth"))
    .getGlobalDefaultAccount();
if (!account?.tokens?.refresh_token) {
  throw new Error("Firebase CLI no tiene una sesion activa.");
}
const api = require(path.join(firebaseToolsBase, "api"));
const temporaryDirectory = fs.mkdtempSync(
    path.join(os.tmpdir(), "parameter-permissions-"),
);
const credentialPath = path.join(temporaryDirectory, "adc.json");
fs.writeFileSync(credentialPath, JSON.stringify({
  type: "authorized_user",
  client_id: api.clientId(),
  client_secret: api.clientSecret(),
  refresh_token: account.tokens.refresh_token,
}), {encoding: "utf8", mode: 0o600});
process.env.GOOGLE_APPLICATION_CREDENTIALS = credentialPath;
process.on("exit", () => {
  fs.rmSync(temporaryDirectory, {recursive: true, force: true});
});

initializeApp({projectId, credential: applicationDefault()});
const db = getFirestore();
const apply = process.argv.includes("--apply");
const verify = process.argv.includes("--verify");
const requiredPermissions = ["parametros.ver", "parametros.editar"];

async function inspect() {
  const [parameters, administrators] = await Promise.all([
    db.collection("parameters").where("clave", "==", "permission").get(),
    db.collection("users").where("role", "==", "Administrador").get(),
  ]);
  const existing = new Set(parameters.docs.map((item) => item.data().valor));
  const activeAdministrators = administrators.docs.filter((item) =>
    item.data().status === "activo");
  const pendingAdministrators = activeAdministrators.filter((item) => {
    const permissions = Array.isArray(item.data().permissions) ?
      item.data().permissions : [];
    return requiredPermissions.some((permission) =>
      !permissions.includes(permission));
  });
  return {
    missingCatalog: requiredPermissions.filter((item) => !existing.has(item)),
    activeAdministrators,
    pendingAdministrators,
  };
}

async function main() {
  const before = await inspect();
  if (apply && (before.missingCatalog.length ||
      before.pendingAdministrators.length)) {
    const batch = db.batch();
    const catalog = [
      {id: "permission_parametros_ver", valor: "parametros.ver", orden: 910},
      {
        id: "permission_parametros_editar",
        valor: "parametros.editar",
        orden: 911,
      },
    ];
    for (const item of catalog) {
      batch.set(db.collection("parameters").doc(item.id), {
        clave: "permission",
        etiqueta: "Configuracion academica",
        valor: item.valor,
        orden: item.orden,
        activo: true,
      }, {merge: true});
    }
    for (const administrator of before.pendingAdministrators) {
      batch.update(administrator.ref, {
        permissions: FieldValue.arrayUnion(...requiredPermissions),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    batch.set(db.collection("migration_audit")
        .doc("parameter_permissions_v1"), {
      projectId,
      migration: "parameter_permissions_v1",
      activeAdministrators: before.activeAdministrators.length,
      updatedAdministrators: before.pendingAdministrators.length,
      completedAt: FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
  const after = await inspect();
  const result = {
    projectId,
    apply,
    verify,
    activeAdministrators: after.activeAdministrators.length,
    missingCatalog: after.missingCatalog.length,
    administratorsMissingPermissions: after.pendingAdministrators.length,
  };
  console.log(JSON.stringify(result));
  if (verify && (after.missingCatalog.length ||
      after.pendingAdministrators.length)) process.exitCode = 2;
}

main().catch((error) => {
  console.error(error.code || error.message);
  process.exitCode = 1;
});
