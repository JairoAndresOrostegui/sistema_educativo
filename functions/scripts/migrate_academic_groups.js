const {
  applicationDefault,
  initializeApp,
} = require("firebase-admin/app");
const {
  FieldValue,
  Timestamp,
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
const argumentValue = (name) => {
  const prefix = `--${name}=`;
  return process.argv.find((argument) => argument.startsWith(prefix))
      ?.slice(prefix.length);
};
const repairSubjectId = argumentValue("repair-subject");
const repairEndMinutesValue = argumentValue("end-minutes");
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

function scheduleMinutes(data, field, timestampField) {
  if (Number.isInteger(data[field])) return data[field];
  const date = data[timestampField]?.toDate?.();
  if (!(date instanceof Date)) return -1;
  const bogotaHour = (date.getUTCHours() + 19) % 24;
  return bogotaHour * 60 + date.getUTCMinutes();
}

async function repairScheduleEndTime() {
  if (!apply) {
    throw new Error("La reparacion puntual requiere --apply.");
  }
  const endMinutes = Number(repairEndMinutesValue);
  if (!repairSubjectId || !Number.isInteger(endMinutes) ||
      endMinutes < 1 || endMinutes >= 1440) {
    throw new Error("Indique --repair-subject y --end-minutes validos.");
  }

  const subjectRef = db.collection("subjects").doc(repairSubjectId);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(subjectRef);
    if (!snapshot.exists) throw new Error("El horario indicado no existe.");
    const before = snapshot.data();
    const startMinutes = scheduleMinutes(
        before, "startMinutes", "startTime",
    );
    if (startMinutes < 0 || endMinutes <= startMinutes) {
      throw new Error("La hora final debe ser posterior a la inicial.");
    }

    const revision = Number.isInteger(before.revision) ?
      before.revision + 1 : 2;
    const patch = {
      endMinutes,
      endTime: Timestamp.fromMillis(
          Date.UTC(2000, 0, 1) + (endMinutes + 300) * 60000,
      ),
      revision,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: "migration:schedule_time_repair",
    };
    const backupRef = db.collection("migration_backups").doc();
    const historyRef = db.collection("schedule_history").doc();
    transaction.create(backupRef, {
      migration: "schedule_time_repair",
      sourcePath: subjectRef.path,
      sourceData: before,
      createdAt: FieldValue.serverTimestamp(),
    });
    transaction.update(subjectRef, patch);
    transaction.create(historyRef, {
      action: "repair_subject_time",
      subjectId: subjectRef.id,
      institutionId: before.institutionId,
      campusId: before.campusId,
      groupId: before.groupId,
      before,
      after: {...before, ...patch},
      performedBy: "migration:schedule_time_repair",
      performedByRole: "Sistema",
      createdAt: FieldValue.serverTimestamp(),
    });
  });
  console.log(
      `Horario ${repairSubjectId} reparado: fin ${endMinutes} minutos.`,
  );
}

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

  const subjects = await db.collection("subjects").get();
  const usersSnapshot = await db.collection("users").get();
  const usersById = new Map(usersSnapshot.docs.map((item) => [
    item.id, item.data(),
  ]));
  const scheduleRows = [];
  for (const document of subjects.docs) {
    const data = document.data();
    if (!Number.isInteger(data.revision) || data.revision < 1) {
      violations.push(`subjects/${document.id}: revision ausente o invalida`);
    }
    const start = scheduleMinutes(data, "startMinutes", "startTime");
    const end = scheduleMinutes(data, "endMinutes", "endTime");
    if (!new Set(["lunes", "martes", "miercoles", "jueves", "viernes"])
        .has(data.day) || start < 0 || end <= start || end >= 24 * 60) {
      violations.push(
          `subjects/${document.id}: franja o dia invalido ` +
          `(${data.subject || "sin materia"}, ` +
          `${data.groupName || "sin grupo"}, ` +
          `${data.day}, ${start}-${end}, ` +
          `${data.startTime?.toDate?.()?.toISOString?.() || "sin inicio"}, ` +
          `${data.endTime?.toDate?.()?.toISOString?.() || "sin fin"})`,
      );
    }
    const group = groupsSnapshot.docs.find((item) => item.id === data.groupId)
        ?.data();
    if (!group || group.institutionId !== data.institutionId ||
        group.campusId !== data.campusId || group.name !== data.groupName) {
      violations.push(`subjects/${document.id}: grupo o sede inconsistente`);
    }
    const teacher = usersById.get(data.teacherId);
    const teacherName = `${teacher?.firstName || ""} ` +
      `${teacher?.lastName || ""}`.trim();
    const teacherIssues = [
      !teacher ? "inexistente" : null,
      teacher && teacher.role !== "Docente" ? `rol=${teacher.role}` : null,
      teacher && teacher.status !== "activo" ?
        `estado=${teacher.status}` : null,
      teacher && teacher.institution !== data.institutionId ?
        "institucion" : null,
      teacher && teacher.campus !== data.campusId ? "sede" : null,
      teacher && teacherName.trim() !== (data.teacherName || "").trim() ?
        "nombre derivado" : null,
    ].filter(Boolean);
    if (teacherIssues.length) {
      violations.push(
          `subjects/${document.id}: docente inconsistente ` +
          `(${teacherIssues.join(", ")})`,
      );
    }
    scheduleRows.push({id: document.id, ...data, start, end});
  }
  for (let left = 0; left < scheduleRows.length; left += 1) {
    for (let right = left + 1; right < scheduleRows.length; right += 1) {
      const a = scheduleRows[left];
      const b = scheduleRows[right];
      if (a.institutionId !== b.institutionId ||
          a.campusId !== b.campusId || a.day !== b.day ||
          a.start >= b.end || a.end <= b.start) continue;
      if (a.groupId === b.groupId || a.teacherId === b.teacherId) {
        violations.push(
            `subjects/${a.id} y subjects/${b.id}: cruce de horario`,
        );
      }
    }
  }

  const channels = await db.collection("message_channels").get();
  for (const document of channels.docs) {
    const data = document.data();
    if (Object.hasOwn(data, "contextStudentGrade")) {
      violations.push(
          `message_channels/${document.id}: contexto antiguo ` +
          `${JSON.stringify(data.contextStudentGrade)}`,
      );
    }
    const groupId = data.groupId || data.contextStudentGroupId;
    if (groupId && !groupIds.has(groupId)) {
      violations.push(`message_channels/${document.id}: grupo inexistente`);
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
    subjects: subjects.size,
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
  if (repairSubjectId || repairEndMinutesValue) {
    await repairScheduleEndTime();
    return;
  }
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

  await migrateCollection("subjects", async (data) => {
    const update = {};
    if (!Number.isInteger(data.revision) || data.revision < 1) {
      update.revision = 1;
    }
    if (!Number.isInteger(data.startMinutes)) {
      const start = scheduleMinutes(data, "startMinutes", "startTime");
      if (start >= 0) update.startMinutes = start;
    }
    if (!Number.isInteger(data.endMinutes)) {
      const end = scheduleMinutes(data, "endMinutes", "endTime");
      if (end >= 0) update.endMinutes = end;
    }
    if (data.day === "miércoles") update.day = "miercoles";
    const [group, teacher] = await Promise.all([
      db.collection("academic_groups").doc(data.groupId || "_").get(),
      db.collection("users").doc(data.teacherId || "_").get(),
    ]);
    if (group.exists && group.data().institutionId === data.institutionId &&
        group.data().campusId === data.campusId &&
        data.groupName !== group.data().name) {
      update.groupName = group.data().name;
    }
    if (teacher.exists && teacher.data().role === "Docente" &&
        teacher.data().institution === data.institutionId &&
        teacher.data().campus === data.campusId) {
      const name = `${teacher.data().firstName || ""} ` +
        `${teacher.data().lastName || ""}`.trim();
      if (name.trim() !== (data.teacherName || "").trim()) {
        update.teacherName = name.trim();
      }
    }
    return Object.keys(update).length ? update : null;
  });

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
