"use strict";

const {applicationDefault, initializeApp} = require("firebase-admin/app");
const {FieldValue, getFirestore} = require("firebase-admin/firestore");
const crypto = require("crypto");
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
let temporaryCredentialDirectory;
if (process.argv.includes("--firebase-cli-auth")) {
  const firebaseAuth = firebaseToolsModule("lib/auth");
  const firebaseApi = firebaseToolsModule("lib/api");
  const account = firebaseAuth.getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) {
    throw new Error("Firebase CLI no tiene una sesion activa.");
  }
  temporaryCredentialDirectory = fs.mkdtempSync(
      path.join(os.tmpdir(), "academic-years-migration-"),
  );
  const credentialPath = path.join(
      temporaryCredentialDirectory, "application_default_credentials.json",
  );
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
const currentYearArgument = process.argv.find((item) =>
  item.startsWith("--current-year="));
const currentYear = Number(currentYearArgument?.split("=")[1] || 2026);
if (!Number.isInteger(currentYear) || currentYear < 2020 ||
    currentYear > 2100) {
  throw new Error("--current-year no es valido.");
}

const yearId = (institution, campus, year) => crypto.createHash("sha256")
    .update(`${institution}\u0000${campus}\u0000${year}`).digest("hex");
const settingsId = (institution, campus) => crypto.createHash("sha256")
    .update(`${institution}\u0000${campus}`).digest("hex");
const tenantKey = (institution, campus) => `${institution}\u0000${campus}`;

function tenant(data) {
  return {
    institution: (data.institutionId || data.institution || "").toString()
        .trim(),
    campus: (data.campusId || data.campus || "").toString().trim(),
  };
}

async function configuredTenants() {
  const snapshot = await db.collection("configuracion_colegios").get();
  const result = new Map();
  for (const item of snapshot.docs) {
    const data = item.data();
    const institution = (data.institutionId || item.id).toString().trim();
    for (const raw of Array.isArray(data.sedes) ? data.sedes : []) {
      const campus = (raw && typeof raw === "object" ?
        raw.id || raw.nombre : raw || "").toString().trim();
      if (institution && campus) {
        result.set(tenantKey(institution, campus), {institution, campus});
      }
    }
  }
  return result;
}

async function commit(operations) {
  if (!apply) return;
  for (let index = 0; index < operations.length; index += 400) {
    const batch = db.batch();
    for (const operation of operations.slice(index, index + 400)) {
      batch.set(operation.ref, operation.data, {merge: true});
    }
    await batch.commit();
  }
}

const collections = [
  "academic_groups",
  "subjects",
  "enrollments",
  "authorization_requests",
  "authorization_history",
  "files",
  "file_history",
  "message_threads",
  "routes",
  "daily_routes",
  "schedule_history",
  "enrollment_history",
  "enrollment_notification_events",
  "schedule_notification_events",
  "authorization_notification_events",
  "file_notification_events",
  "academic_group_history",
];

async function migrate() {
  const tenants = await configuredTenants();
  const discoveredYears = new Map();
  const operations = [];
  for (const collection of collections) {
    const snapshot = await db.collection(collection).get();
    let count = 0;
    for (const document of snapshot.docs) {
      const data = document.data();
      const scope = tenant(data);
      if (!scope.institution || !scope.campus) continue;
      tenants.set(tenantKey(scope.institution, scope.campus), scope);
      const academicYear = Number(
          data.academicYear || data.anioMatricula || currentYear,
      );
      if (!Number.isInteger(academicYear)) continue;
      const id = yearId(scope.institution, scope.campus, academicYear);
      discoveredYears.set(
          `${tenantKey(scope.institution, scope.campus)}\u0000${academicYear}`,
          {...scope, year: academicYear, id},
      );
      if (data.academicYearId !== id || data.academicYear !== academicYear) {
        operations.push({
          ref: document.ref,
          data: {
            academicYearId: id,
            academicYear,
            migratedAcademicYearAt: FieldValue.serverTimestamp(),
          },
        });
        count += 1;
      }
    }
    console.log(`${collection}: ${count} documento(s) por etiquetar.`);
  }

  for (const scope of tenants.values()) {
    const id = yearId(scope.institution, scope.campus, currentYear);
    discoveredYears.set(
        `${tenantKey(scope.institution, scope.campus)}\u0000${currentYear}`,
        {...scope, year: currentYear, id},
    );
    operations.push({
      ref: db.collection("academic_year_settings")
          .doc(settingsId(scope.institution, scope.campus)),
      data: {
        institutionId: scope.institution,
        campusId: scope.campus,
        activeYearId: id,
        activeYear: currentYear,
        updatedBy: "migration:academic_years_v1",
        updatedAt: FieldValue.serverTimestamp(),
      },
    });
  }
  for (const item of discoveredYears.values()) {
    operations.push({
      ref: db.collection("academic_years").doc(item.id),
      data: {
        institutionId: item.institution,
        campusId: item.campus,
        year: item.year,
        status: item.year === currentYear ? "active" :
          item.year < currentYear ? "closed" : "draft",
        migratedBy: "migration:academic_years_v1",
        updatedAt: FieldValue.serverTimestamp(),
      },
    });
  }
  await commit(operations);
  console.log(`${operations.length} operacion(es) ${
    apply ? "aplicadas" : "detectadas (simulacion)"}.`);
}

async function verifyMigration() {
  const violations = [];
  for (const collection of collections) {
    const snapshot = await db.collection(collection).get();
    for (const document of snapshot.docs) {
      const data = document.data();
      const scope = tenant(data);
      if (!scope.institution || !scope.campus) {
        violations.push(`${document.ref.path}: no tiene institucion/sede`);
      } else if (typeof data.academicYearId !== "string" ||
          !Number.isInteger(Number(data.academicYear))) {
        violations.push(`${document.ref.path}: no tiene anio lectivo`);
      }
    }
  }
  if (violations.length) {
    throw new Error(`Migracion incompleta:\n${violations.join("\n")}`);
  }
  console.log("Verificacion correcta: no hay documentos operativos huerfanos.");
}

(async () => {
  try {
    if (verify) await verifyMigration();
    else await migrate();
  } finally {
    if (temporaryCredentialDirectory) {
      fs.rmSync(temporaryCredentialDirectory, {recursive: true, force: true});
    }
  }
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
