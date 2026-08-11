const {
  applicationDefault,
  initializeApp,
} = require("firebase-admin/app");
const {FieldValue, getFirestore} = require("firebase-admin/firestore");
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
let temporaryCredentialDirectory;
if (process.argv.includes("--firebase-cli-auth")) {
  const firebaseAuth = firebaseToolsModule("lib/auth");
  const firebaseApi = firebaseToolsModule("lib/api");
  const account = firebaseAuth.getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) {
    throw new Error("Firebase CLI no tiene una sesion activa.");
  }
  temporaryCredentialDirectory = fs.mkdtempSync(
      path.join(os.tmpdir(), "school-migration-"),
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

initializeApp({
  credential,
  storageBucket: process.env.FIREBASE_STORAGE_BUCKET ||
    "sistema-educativo-rl.firebasestorage.app",
});
const db = getFirestore();
const bucket = getStorage().bucket();
const apply = process.argv.includes("--apply");
const verify = process.argv.includes("--verify");
const fileModuleLimitBytes = 1024 * 1024 * 1024;
const enrollmentDataFields = new Set([
  "anioInscripcion", "fechaInscripcion", "nombresAlumno",
  "apellidosAlumno", "nombresApellidosAlumno", "lugarNacimiento",
  "fechaNacimiento", "edad", "tipoSangre", "rh", "tipoIdentidad",
  "numeroIdentidad", "direccionAlumno", "telefonoAlumno", "epsEstudiante",
  "nombrePadre", "cedulaPadre", "emailPadre", "celularPadre",
  "lugarTrabajoPadre", "ocupacionPadre", "cargoPadre", "nombreMadre",
  "cedulaMadre", "emailMadre", "celularMadre", "lugarTrabajoMadre",
  "ocupacionMadre", "cargoMadre", "tieneAcudienteDiferente",
  "acudientePrincipal", "nombreAcudiente", "cedulaAcudiente",
  "emailAcudiente", "celularAcudiente", "lugarTrabajoAcudiente",
  "ocupacionAcudiente", "cargoAcudiente", "facturaElectronica",
  "sedeAspirada", "groupId", "groupName", "nivelesCursadosInstitucion",
  "servicioLonchera", "servicioAlmuerzo", "servicioTransporte",
  "servicioTransporteTipo", "observacionesPadres", "fueReferido",
  "nombreReferido", "nombrePadresReferentes", "telefonoReferentes",
  "celularReferentes", "institucion",
]);
const requiredEnrollmentFields = [
  "nombresAlumno", "apellidosAlumno", "lugarNacimiento",
  "fechaNacimiento", "tipoSangre", "rh", "tipoIdentidad",
  "numeroIdentidad", "direccionAlumno", "epsEstudiante", "nombrePadre",
  "cedulaPadre", "emailPadre", "celularPadre", "nombreMadre",
  "cedulaMadre", "emailMadre", "celularMadre", "sedeAspirada", "groupId",
];

const slug = (value) => value.toString().normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "").toLowerCase()
    .replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "");

const groupIdFor = (institution, campus, level) =>
  `${slug(institution)}__${slug(campus)}__${slug(level)}__a`;

async function commitOperations(operations) {
  if (!apply) return;
  for (let offset = 0; offset < operations.length; offset += 400) {
    const batch = db.batch();
    for (const operation of operations.slice(offset, offset + 400)) {
      if (operation.type === "delete") batch.delete(operation.ref);
      else batch.set(operation.ref, operation.data, {merge: true});
    }
    await batch.commit();
  }
}

function tenant(data) {
  return {
    institution: (data.institutionId || data.institution || "").toString(),
    campus: (data.campusId || data.campus || "").toString(),
  };
}

function oldLevel(data) {
  return (data.grade || data.grado || data.gradoAspirado || "")
      .toString().trim();
}

function groupPatch(data, nested = false) {
  const source = nested ? (data.data || {}) : data;
  const level = oldLevel(source);
  const scope = tenant(data);
  if (!level || !scope.institution || !scope.campus ||
      level.toLowerCase() === "no aplica") return null;
  return {
    groupId: groupIdFor(scope.institution, scope.campus, level),
    groupName: `${level} A`,
  };
}

async function migrateCollection(name, transform) {
  const snapshot = await db.collection(name).get();
  const operations = [];
  for (const document of snapshot.docs) {
    const patch = await transform(document.data(), document);
    if (patch) operations.push({type: "set", ref: document.ref, data: patch});
  }
  await commitOperations(operations);
  const status = apply ? "migrados" : "detectados";
  console.log(`${name}: ${operations.length} documentos ${status}`);
}

async function verifyMigration() {
  const violations = [];
  const groupsSnapshot = await db.collection("academic_groups").get();
  const groupIds = new Set(groupsSnapshot.docs.map((document) => document.id));

  const directCollections = [
    "users", "user_directory", "subjects", "authorization_requests",
    "authorization_history", "schedule_history", "file_history",
    "notification_events", "user_history",
  ];
  for (const collection of directCollections) {
    const snapshot = await db.collection(collection).get();
    for (const document of snapshot.docs) {
      const data = document.data();
      if (Object.hasOwn(data, "grade") || Object.hasOwn(data, "grado")) {
        violations.push(`${collection}/${document.id}: campo de grado antiguo`);
      }
      if (data.groupId && !groupIds.has(data.groupId)) {
        violations.push(
            `${collection}/${document.id}: grupo inexistente ${data.groupId}`,
        );
      }
    }
  }

  const enrollments = await db.collection("enrollments").get();
  for (const document of enrollments.docs) {
    const data = document.data().data || {};
    if (["grade", "grado", "gradoAspirado"].some((key) =>
      Object.hasOwn(data, key))) {
      violations.push(`enrollments/${document.id}: campo de grado antiguo`);
    }
    if (data.groupId && !groupIds.has(data.groupId)) {
      violations.push(`enrollments/${document.id}: grupo inexistente`);
    }
    const unknownFields = Object.keys(data).filter((key) =>
      !enrollmentDataFields.has(key));
    if (unknownFields.length) {
      violations.push(
          `enrollments/${document.id}: campos no permitidos ` +
          unknownFields.join(", "),
      );
    }
    const missingFields = requiredEnrollmentFields.filter((key) =>
      !data[key]?.toString().trim());
    if (missingFields.length) {
      violations.push(
          `enrollments/${document.id}: campos obligatorios ausentes ` +
          missingFields.join(", "),
      );
    }
    const history = Array.isArray(data.nivelesCursadosInstitucion) ?
      data.nivelesCursadosInstitucion : [];
    if (history.some((item) => item && Object.hasOwn(item, "grado"))) {
      violations.push(
          `enrollments/${document.id}: historial con campo grado antiguo`,
      );
    }
  }

  const threads = await db.collection("message_threads").get();
  for (const document of threads.docs) {
    const data = document.data();
    if (Object.hasOwn(data, "contextStudentGrade")) {
      violations.push(
          `message_threads/${document.id}: contexto antiguo ` +
          `${JSON.stringify(data.contextStudentGrade)}`,
      );
    }
    if (data.contextStudentGroupId &&
        !groupIds.has(data.contextStudentGroupId)) {
      violations.push(`message_threads/${document.id}: grupo inexistente`);
    }
  }

  let activeFileBytes = 0;
  const files = await db.collection("files").get();
  for (const document of files.docs) {
    const data = document.data();
    if (Object.hasOwn(data, "grade") || Object.hasOwn(data, "groupId") ||
        !Array.isArray(data.targetGroupIds) ||
        data.targetGroupIds.some((id) => !groupIds.has(id)) ||
        !Array.isArray(data.targetStudentIds) ||
        !Array.isArray(data.recipientUserIds) ||
        !Array.isArray(data.recipientContextKeys)) {
      violations.push(`files/${document.id}: audiencia invalida`);
    }
    if (data.status === "active") {
      const storagePath = (data.storagePath || "").toString();
      const expectedPrefix = `files/${document.id}/`;
      if (!storagePath.startsWith(expectedPrefix)) {
        violations.push(`files/${document.id}: ruta de Storage invalida`);
      } else {
        const [exists] = await bucket.file(storagePath).exists();
        if (!exists) {
          violations.push(`files/${document.id}: objeto ausente en Storage`);
        }
      }
      activeFileBytes += Number(data.sizeBytes || 0);
    }
  }

  const usageSnapshot = await db.collection("file_storage_usage").get();
  for (const document of usageSnapshot.docs) {
    if (Number(document.data().limitBytes || 0) !== fileModuleLimitBytes) {
      violations.push(
          `file_storage_usage/${document.id}: limite institucional invalido`,
      );
    }
  }

  const gradeParameters = await db.collection("parameters")
      .where("clave", "==", "grade").get();
  if (!gradeParameters.empty) {
    violations.push(`parameters: ${gradeParameters.size} grados antiguos`);
  }

  const legacyCollections = [
    "historial_usuarios", "historial_rutas_admin", "historial_horarios",
    "archivos", "students", "estudiantes",
  ];
  const legacyCounts = {};
  for (const collection of legacyCollections) {
    const aggregate = await db.collection(collection).count().get();
    const count = aggregate.data().count;
    legacyCounts[collection] = count;
    if (count > 0) {
      violations.push(`${collection}: ${count} documentos antiguos`);
    }
  }
  for (const collection of ["routes", "daily_routes"]) {
    const snapshot = await db.collection(collection).get();
    for (const document of snapshot.docs) {
      if (Object.hasOwn(document.data(), "manager")) {
        violations.push(`${collection}/${document.id}: gestor antiguo`);
      }
    }
  }

  console.log(JSON.stringify({
    academicGroups: groupsSnapshot.size,
    academicGroupIds: [...groupIds].sort(),
    enrollments: enrollments.size,
    files: files.size,
    activeFileBytes,
    fileStorageUsageDocuments: usageSnapshot.size,
    fileModuleLimitBytes,
    legacyCounts,
    violations,
  }, null, 2));
  if (violations.length) {
    throw new Error(`Auditoria fallida: ${violations.length} hallazgos.`);
  }
  console.log("Auditoria de migracion aprobada.");
}

async function main() {
  if (verify) {
    await verifyMigration();
    return;
  }
  console.log(apply ? "MODO APPLY" : "MODO DRY-RUN");
  const configs = await db.collection("configuracion_colegios").get();
  const gradeParameters = await db.collection("parameters")
      .where("clave", "==", "grade").get();
  const levels = gradeParameters.docs.map((doc) => ({
    name: (doc.data().valor || doc.data().etiqueta || "").toString().trim(),
    order: Number(doc.data().orden || 0),
  })).filter((item) => item.name && item.name.toLowerCase() !== "no aplica");

  const groupOperations = [];
  for (const config of configs.docs) {
    const data = config.data();
    const institution = (data.institutionId || config.id).toString();
    const campuses = Array.isArray(data.sedes) ? data.sedes.map((item) =>
      typeof item === "string" ? item : item.id || item.nombre,
    ).filter(Boolean) : [];
    for (const campus of campuses) {
      for (const level of levels) {
        const id = groupIdFor(institution, campus, level.name);
        groupOperations.push({
          type: "set",
          ref: db.collection("academic_groups").doc(id),
          data: {
            institutionId: institution,
            campusId: campus,
            level: level.name,
            section: "A",
            name: `${level.name} A`,
            order: level.order,
            active: true,
            migratedAt: FieldValue.serverTimestamp(),
          },
        });
      }
    }
  }
  await commitOperations(groupOperations);
  const groupStatus = apply ? "creados" : "planeados";
  console.log(
      `academic_groups: ${groupOperations.length} grupos ${groupStatus}`,
  );

  const directCollections = [
    "users", "user_directory", "subjects", "authorization_requests",
    "authorization_history", "schedule_history", "file_history",
    "notification_events", "user_history",
  ];
  for (const collection of directCollections) {
    await migrateCollection(collection, async (data, document) => {
      const patch = groupPatch(data);
      const update = {...(patch || {})};
      if (collection === "user_directory" && data.groupId) {
        const canonicalUser = await db.collection("users")
            .doc(document.id).get();
        const canonicalData = canonicalUser.data();
        if (canonicalData?.groupId && canonicalData.groupId !== data.groupId) {
          update.groupId = canonicalData.groupId;
          update.groupName = canonicalData.groupName || "";
        }
      }
      if (Object.hasOwn(data, "grade")) {
        update.grade = FieldValue.delete();
      }
      if (Object.hasOwn(data, "grado")) {
        update.grado = FieldValue.delete();
      }
      return Object.keys(update).length ? update : null;
    });
  }

  for (const collection of ["routes", "daily_routes"]) {
    await migrateCollection(collection, (data) => {
      if (!Object.hasOwn(data, "manager")) return null;
      return {
        ...(data.gestionador ? {} : {gestionador: data.manager || null}),
        manager: FieldValue.delete(),
      };
    });
  }

  await migrateCollection("enrollments", (data) => {
    const patch = groupPatch(data, true);
    const enrollmentData = data.data || {};
    const hasLegacyField = ["grade", "grado", "gradoAspirado"].some((key) =>
      Object.hasOwn(enrollmentData, key));
    const history = Array.isArray(enrollmentData.nivelesCursadosInstitucion) ?
      enrollmentData.nivelesCursadosInstitucion : [];
    const hasLegacyHistory = history.some((item) =>
      item && Object.hasOwn(item, "grado"));
    if (!patch && !hasLegacyField && !hasLegacyHistory) return null;
    return {
      data: {
        ...(patch || {}),
        ...(hasLegacyHistory ? {
          nivelesCursadosInstitucion: history.map((item) => ({
            ...Object.fromEntries(
                Object.entries(item).filter(([key]) => key !== "grado"),
            ),
            groupName: item.groupName || item.grado || "",
          })),
        } : {}),
        grade: FieldValue.delete(),
        grado: FieldValue.delete(),
        gradoAspirado: FieldValue.delete(),
      },
    };
  });

  await migrateCollection("message_threads", (data) => {
    const level = (data.contextStudentGrade || "").toString().trim();
    const scope = tenant(data);
    const update = {};
    if (level) {
      update.contextStudentGroupId = groupIdFor(
          scope.institution, scope.campus, level,
      );
      update.contextStudentGroupName = `${level} A`;
    }
    if (Object.hasOwn(data, "contextStudentGrade")) {
      update.contextStudentGrade = FieldValue.delete();
    }
    return Object.keys(update).length ? update : null;
  });

  console.log(
      "Archivos usa su migracion dedicada migrate_file_audiences.js.",
  );

  if (apply) {
    const files = await db.collection("files")
        .where("status", "==", "active").get();
    const usage = new Map();
    for (const document of files.docs) {
      const data = document.data();
      const id = slug(data.institutionId || "");
      usage.set(id, {
        institutionId: data.institutionId,
        usedBytes: (usage.get(id)?.usedBytes || 0) +
          Number(data.sizeBytes || 0),
        reservedBytes: 0,
        limitBytes: fileModuleLimitBytes,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    await commitOperations([...usage.entries()].map(([id, data]) => ({
      type: "set", ref: db.collection("file_storage_usage").doc(id), data,
    })));
  }

  const parameterDeletes = gradeParameters.docs.map((doc) => ({
    type: "delete", ref: doc.ref,
  }));
  await commitOperations(parameterDeletes);
  const parameterStatus = apply ? "eliminados" : "por eliminar";
  console.log(
      `parameters/grade: ${parameterDeletes.length} ${parameterStatus}`,
  );
  console.log("Migracion finalizada.");
}

main()
    .catch((error) => {
      console.error(error);
      process.exitCode = 1;
    })
    .finally(() => {
      if (temporaryCredentialDirectory) {
        fs.rmSync(temporaryCredentialDirectory, {recursive: true, force: true});
      }
    });
