"use strict";
/* eslint-disable max-len */

const {applicationDefault, initializeApp} = require("firebase-admin/app");
const {FieldValue, getFirestore} = require("firebase-admin/firestore");
const fs = require("fs");
const os = require("os");
const path = require("path");

const DOCUMENT_TYPES = [
  ["CC", "Cédula de ciudadanía"],
  ["TI", "Tarjeta de identidad"],
  ["RC", "Registro civil de nacimiento"],
  ["CE", "Cédula de extranjería"],
  ["PA", "Pasaporte"],
  ["PT", "Permiso por Protección Temporal"],
  ["CD", "Carné diplomático"],
  ["SC", "Salvoconducto"],
  ["PE", "Permiso Especial de Permanencia"],
  ["CN", "Certificado de nacido vivo"],
  ["DE", "Documento extranjero"],
  ["MS", "Menor sin identificación"],
  ["AS", "Adulto sin identificación"],
  ["SI", "Sin identificación"],
];

// Códigos del listado oficial de EPS vigentes del Ministerio de Salud. Los
// registros se conservan como catálogo global y deben revisarse periódicamente.
const EPS = [
  ["ESS024-EPS042", "Coosalud EPS-S"],
  ["EPS037-EPSS41", "Nueva EPS"],
  ["ESS207-EPS048", "Mutual Ser"],
  ["EPS046", "Salud Mía"],
  ["EPS001", "Aliansalud EPS"],
  ["EPS002", "Salud Total EPS"],
  ["EPS005", "EPS Sanitas"],
  ["EPS010", "EPS SURA"],
  ["EPS017", "Famisanar"],
  ["EPS018", "Servicio Occidental de Salud EPS SOS"],
  ["EPS012", "Comfenalco Valle"],
  ["EPS008", "Compensar EPS"],
  ["EAS016", "Empresas Públicas de Medellín - EPM"],
  ["EAS027", "Fondo de Pasivo Social de Ferrocarriles Nacionales"],
  ["CCF055", "Proteger EPS (antes Cajacopi)"],
  ["EPS025", "Capresoca"],
  ["CCF102", "Comfachocó"],
  ["CCF050", "Comfaoriente"],
  ["CCF033", "EPS Familiar de Colombia"],
  ["ESS062", "Asmet Salud"],
  ["ESS118", "Emssanar E.S.S."],
  ["EPSS34", "Capital Salud EPS-S"],
  ["EPSS40", "Savia Salud EPS"],
  ["EPSI01", "Dusakawi EPSI"],
  ["EPSI03", "Asociación Indígena del Cauca EPSI"],
  ["EPSI04", "Anas Wayuu EPSI"],
  ["EPSI05", "Mallamas EPSI"],
  ["EPSI06", "Pijaos Salud EPSI"],
];

const projectArg = process.argv.find((value) => value.startsWith("--project="));
const projectId = projectArg?.split("=")[1] || process.env.GOOGLE_CLOUD_PROJECT;
if (!projectId) throw new Error("Indica --project=<firebase-project-id>.");
const apply = process.argv.includes("--apply");
const verify = process.argv.includes("--verify");

let credentialDirectory;
if (process.argv.includes("--firebase-cli-auth")) {
  const base = path.join(process.env.APPDATA,
      "npm/node_modules/firebase-tools/lib");
  const account = require(path.join(base, "auth")).getGlobalDefaultAccount();
  const api = require(path.join(base, "api"));
  if (!account?.tokens?.refresh_token) throw new Error("Firebase CLI sin sesión.");
  credentialDirectory = fs.mkdtempSync(path.join(os.tmpdir(), "catalog-sync-"));
  const credentialPath = path.join(credentialDirectory, "adc.json");
  fs.writeFileSync(credentialPath, JSON.stringify({
    type: "authorized_user", client_id: api.clientId(),
    client_secret: api.clientSecret(),
    refresh_token: account.tokens.refresh_token,
  }), {encoding: "utf8", mode: 0o600});
  process.env.GOOGLE_APPLICATION_CREDENTIALS = credentialPath;
}
initializeApp({credential: applicationDefault(), projectId});
const db = getFirestore();

function normalizeDocumentType(value) {
  const normalized = String(value || "").normalize("NFKD")
      .replace(/[\u0300-\u036f]/g, "").trim().toUpperCase();
  const aliases = new Map([
    ["CEDULA DE CIUDADANIA", "CC"], ["CEDULA CIUDADANIA", "CC"],
    ["TARJETA DE IDENTIDAD", "TI"], ["REGISTRO CIVIL", "RC"],
    ["REGISTRO CIVIL DE NACIMIENTO", "RC"],
    ["CEDULA DE EXTRANJERIA", "CE"], ["PAS", "PA"],
    ["PASAPORTE", "PA"], ["PPT", "PT"],
    ["PERMISO POR PROTECCION TEMPORAL", "PT"],
  ]);
  return aliases.get(normalized) || normalized;
}

async function commit(writes) {
  for (let index = 0; index < writes.length; index += 400) {
    const batch = db.batch();
    writes.slice(index, index + 400).forEach((write) => write(batch));
    await batch.commit();
  }
}

async function main() {
  const [parameters, users, enrollments] = await Promise.all([
    db.collection("parameters").get(), db.collection("users").get(),
    db.collection("enrollments").get(),
  ]);
  const writes = [];
  const canonicalIds = new Set();
  DOCUMENT_TYPES.forEach(([code, label], index) => {
    const ref = db.collection("parameters").doc(`documentType_${code}`);
    canonicalIds.add(ref.id);
    writes.push((batch) => batch.set(ref, {
      clave: "documentType", etiqueta: label, valor: code,
      orden: index + 1, activo: true,
      updatedBy: "migration:colombia_catalogs_v1",
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true}));
  });
  EPS.forEach(([code, label], index) => {
    const ref = db.collection("parameters").doc(`eps_${code.replace(/[^A-Za-z0-9]/g, "_")}`);
    canonicalIds.add(ref.id);
    writes.push((batch) => batch.set(ref, {
      clave: "eps", etiqueta: label, valor: code,
      orden: index + 1, activo: true,
      updatedBy: "migration:colombia_catalogs_v1",
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true}));
  });
  const legacyCatalogs = parameters.docs.filter((item) =>
    ["eps", "documentType"].includes(item.data().clave) &&
    !canonicalIds.has(item.id));
  legacyCatalogs.forEach((item) => writes.push((batch) => batch.set(item.ref, {
    activo: false, updatedBy: "migration:colombia_catalogs_v1",
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true})));
  const legacyEnrollmentYears = parameters.docs.filter((item) =>
    item.id === "enrollment_year" || item.data().clave === "enrollment_year");
  legacyEnrollmentYears.forEach((item) => writes.push((batch) =>
    batch.set(item.ref, {
      activo: false, replacedBy: "academic_year_settings",
      updatedBy: "migration:colombia_catalogs_v1",
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true})));

  let normalizedUsers = 0;
  users.docs.forEach((item) => {
    const before = item.data().documentType;
    const after = normalizeDocumentType(before);
    if (before && after !== before && DOCUMENT_TYPES.some(([code]) => code === after)) {
      normalizedUsers += 1;
      writes.push((batch) => batch.update(item.ref, {
        documentType: after, updatedAt: FieldValue.serverTimestamp(),
      }));
    }
  });
  let normalizedEnrollments = 0;
  enrollments.docs.forEach((item) => {
    const data = item.data().data || {};
    const update = {};
    for (const field of ["documentType", "tipoDocumento", "tipoIdentidad"]) {
      const before = data[field];
      const after = normalizeDocumentType(before);
      if (before && after !== before && DOCUMENT_TYPES.some(([code]) => code === after)) {
        normalizedEnrollments += 1;
        update[`data.${field}`] = after;
      }
    }
    if (Object.keys(update).length) {
      writes.push((batch) => batch.update(item.ref, {
        ...update, updatedAt: FieldValue.serverTimestamp(),
      }));
    }
  });

  const summary = {projectId, mode: verify ? "verify" : apply ? "apply" : "dry-run",
    documentTypes: DOCUMENT_TYPES.length, eps: EPS.length,
    legacyCatalogsDisabled: legacyCatalogs.length,
    legacyEnrollmentYearsDisabled: legacyEnrollmentYears.length,
    normalizedUsers, normalizedEnrollments};
  if (verify) {
    const active = parameters.docs.filter((item) => item.data().activo === true);
    const docsOk = DOCUMENT_TYPES.every(([code]) => active.some((item) =>
      item.data().clave === "documentType" && item.data().valor === code));
    const epsOk = EPS.every(([code]) => active.some((item) =>
      item.data().clave === "eps" && item.data().valor === code));
    const invalidUsers = users.docs.filter((item) => item.data().documentType &&
      !DOCUMENT_TYPES.some(([code]) => code === item.data().documentType));
    if (!docsOk || !epsOk || invalidUsers.length) {
      throw new Error(`Verificación falló: docs=${docsOk}, eps=${epsOk}, usuarios=${invalidUsers.length}.`);
    }
    console.log(JSON.stringify({...summary, ok: true}, null, 2));
    return;
  }
  if (!apply) {
    console.log(JSON.stringify(summary, null, 2));
    return;
  }
  await db.collection("migration_backups").doc("colombia_catalogs_v1").set({
    previousCatalogs: parameters.docs.filter((item) =>
      ["eps", "documentType"].includes(item.data().clave)).map((item) =>
      ({id: item.id, ...item.data()})),
    appliedAt: FieldValue.serverTimestamp(),
  });
  await commit(writes);
  console.log(JSON.stringify({...summary, applied: true}, null, 2));
}

main().catch((error) => {
  console.error(error); process.exitCode = 1;
}).finally(() => {
  if (credentialDirectory) {
    fs.rmSync(credentialDirectory, {recursive: true, force: true});
  }
});
