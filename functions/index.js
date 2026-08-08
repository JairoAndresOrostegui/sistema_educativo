"use strict";

const {setGlobalOptions} = require("firebase-functions/v2");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentWritten} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {
  FieldPath,
  FieldValue,
  getFirestore,
  Timestamp,
} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const {getStorage} = require("firebase-admin/storage");
const crypto = require("crypto");

initializeApp();
setGlobalOptions({maxInstances: 10, region: "us-central1"});

const db = getFirestore();
const auth = getAuth();
const messaging = getMessaging();
const storage = getStorage();
const ALLOWED_ROLES = new Set([
  "Administrador",
  "Docente",
  "Estudiante",
  "Familiar",
]);
const DIRECTORY_FIELDS = [
  "firstName", "lastName", "role", "status", "institution", "campus",
  "groupId", "groupName", "studentIds", "activeStudentId", "photoUrl",
  "routeAddress", "direccionRuta",
];
const PROFILE_FIELDS = [
  "firstName", "lastName", "personalEmail", "institutionalEmail",
  "document", "documentType", "address", "phones", "birthDate", "role",
  "groupId", "groupName", "institution", "campus", "permissions",
  "photoUrl", "status",
  "birthCountry", "birthDepartment", "birthCity", "residenceCountry",
  "residenceDepartment", "residenceCity", "familyRelation", "studentIds",
  "activeStudentId", "routeAddress", "direccionRuta", "qrPayload",
  "qrEnabled", "qrUpdatedAt",
];
const AUTH_WEB_API_KEY = "AIzaSyBjfpuzVCTvKEMdYGYjMa619SSJ1yL8Jho";
const EMAIL_VERIFICATION_CONTINUE_URL =
  "https://sistema-educativo-rl.web.app/#/login";
const RESTRICTED_DELEGATED_PERMISSIONS = new Set([
  "usuarios.crear",
  "usuarios.editar",
  "usuarios.eliminar",
  "usuarios.ver",
  "historial.ver",
  "sitio_web.editar",
]);
const FILE_MODULE_LIMIT_BYTES = 300 * 1024 * 1024;
const FILE_UPLOAD_LIMIT_BYTES = 25 * 1024 * 1024;
const FILE_RETENTION_DAYS = 60;
const FILE_MIME_TYPES = new Set([
  "application/pdf",
  "application/msword",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  "application/vnd.ms-excel",
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
]);

/**
 * Impone permisos compatibles con el rol, incluso si se omite la interfaz.
 * @param {string} role Rol objetivo.
 * @param {string[]} permissions Permisos solicitados.
 * @return {string[]} Permisos permitidos.
 */
function permissionsForRole(role, permissions) {
  if (role === "Estudiante") {
    return permissions.filter((item) =>
      !item.startsWith("autorizaciones."));
  }
  if (role === "Familiar") {
    return permissions.filter((item) =>
      !item.startsWith("autorizaciones.") ||
      item === "autorizaciones.ver");
  }
  return permissions;
}

/**
 * Valida y normaliza una cadena recibida por una funcion callable.
 * @param {*} value Valor de entrada.
 * @param {string} field Nombre del campo.
 * @param {number} maxLength Longitud maxima.
 * @return {string} Cadena validada.
 */
function requiredString(value, field, maxLength = 200) {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${field} es obligatorio.`);
  }
  const clean = value.trim();
  if (!clean || clean.length > maxLength) {
    throw new HttpsError("invalid-argument", `${field} no es valido.`);
  }
  return clean;
}

/** @param {string} value Correo normalizado. @return {boolean} Valido. */
function validEmail(value) {
  return value.length <= 254 &&
    !value.includes("..") &&
    /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(value);
}

/**
 * Solicita a Firebase Auth el correo de verificacion para una cuenta nueva.
 * @param {string} email Correo institucional de la cuenta.
 * @param {string} password Contrasena inicial, usada solo para crear la sesion.
 * @return {Promise<void>}
 */
async function sendInstitutionalVerificationEmail(email, password) {
  const emulatorHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  const identityBase = emulatorHost ?
    `http://${emulatorHost}/identitytoolkit.googleapis.com/v1` :
    "https://identitytoolkit.googleapis.com/v1";
  const signInResponse = await fetch(
      `${identityBase}/accounts:signInWithPassword?key=${AUTH_WEB_API_KEY}`,
      {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify({email, password, returnSecureToken: true}),
      },
  );
  const signInData = await signInResponse.json();
  if (!signInResponse.ok || typeof signInData.idToken !== "string") {
    throw new Error(signInData.error?.message || "No se pudo iniciar sesion.");
  }

  const verificationResponse = await fetch(
      `${identityBase}/accounts:sendOobCode?key=${AUTH_WEB_API_KEY}`,
      {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify({
          requestType: "VERIFY_EMAIL",
          idToken: signInData.idToken,
          continueUrl: EMAIL_VERIFICATION_CONTINUE_URL,
        }),
      },
  );
  const verificationData = await verificationResponse.json();
  if (!verificationResponse.ok) {
    throw new Error(
        verificationData.error?.message ||
          "No se pudo enviar el correo de verificacion.",
    );
  }
}

/**
 * Obtiene el perfil activo del usuario autenticado.
 * @param {*} request Solicitud callable.
 * @return {Promise<Object>} Perfil del usuario llamador.
 */
async function getCaller(request) {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesion.");
  }

  const snap = await db.collection("users").doc(uid).get();
  if (!snap.exists) {
    throw new HttpsError("permission-denied", "Usuario no registrado.");
  }

  const data = snap.data() || {};
  if ((data.status || "").toString().toLowerCase() !== "activo") {
    throw new HttpsError("permission-denied", "La cuenta no esta activa.");
  }
  return {uid, ...data};
}

/** @param {Object} caller Perfil que debe ser administrador. */
function requireAdmin(caller) {
  if (caller.isSuperadmin === true || caller.role === "Administrador") return;
  throw new HttpsError("permission-denied", "Se requiere rol administrador.");
}

/**
 * Exige el permiso granular del modulo Usuarios.
 * @param {Object} caller Usuario llamador.
 * @param {string} action Accion crear, editar, eliminar o ver.
 */
function requireUserAction(caller, action) {
  if (caller.isSuperadmin === true) return;
  const permissions = Array.isArray(caller.permissions) ?
    caller.permissions : [];
  if (caller.role === "Administrador" &&
      permissions.includes(`usuarios.${action}`)) return;
  throw new HttpsError(
      "permission-denied", `No tienes permiso para ${action} usuarios.`,
  );
}

/**
 * Comprueba que dos perfiles pertenezcan a la misma sede.
 * @param {Object} caller Perfil que ejecuta la accion.
 * @param {Object} target Perfil objetivo.
 * @return {boolean} Verdadero si puede operar sobre el tenant.
 */
function sameTenant(caller, target) {
  const institution = target.institution || target.institutionId;
  const campus = target.campus || target.campusId;
  return caller.isSuperadmin === true ||
    (caller.institution === institution && caller.campus === campus);
}

/**
 * @param {Object} source Perfil completo.
 * @return {Object} Directorio seguro.
 */
function directoryData(source) {
  const result = {};
  for (const field of DIRECTORY_FIELDS) {
    if (source[field] !== undefined) result[field] = source[field];
  }
  return result;
}

/**
 * Filtra y valida un perfil enviado por un administrador.
 * @param {Object} input Datos del perfil.
 * @param {Object} caller Administrador creador.
 * @param {string} uid UID asignado por Firebase Auth.
 * @return {Object} Perfil listo para Firestore.
 */
function validatedProfile(input, caller, uid) {
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    throw new HttpsError("invalid-argument", "El perfil no es valido.");
  }
  const profile = {};
  for (const field of PROFILE_FIELDS) {
    if (input[field] !== undefined) profile[field] = input[field];
  }
  profile.firstName = requiredString(profile.firstName, "nombres", 100);
  profile.lastName = requiredString(profile.lastName, "apellidos", 100);
  profile.document = requiredString(profile.document, "documento", 40);
  profile.institutionalEmail = requiredString(
      profile.institutionalEmail,
      "correo institucional",
      254,
  ).toLowerCase();
  profile.personalEmail = requiredString(
      profile.personalEmail,
      "correo personal",
      254,
  ).toLowerCase();
  if (!validEmail(profile.personalEmail) ||
      !validEmail(profile.institutionalEmail)) {
    throw new HttpsError("invalid-argument", "El correo no es valido.");
  }
  profile.role = requiredString(profile.role, "rol", 30);
  profile.institution = requiredString(profile.institution, "institucion", 120);
  profile.campus = requiredString(profile.campus, "sede", 120);
  if (!ALLOWED_ROLES.has(profile.role)) {
    throw new HttpsError("invalid-argument", "El rol no es valido.");
  }
  if (profile.document.length < 6) {
    throw new HttpsError(
        "invalid-argument", "El documento debe tener al menos 6 caracteres.",
    );
  }
  if (["Estudiante", "Docente"].includes(profile.role)) {
    profile.groupId = requiredString(profile.groupId, "grupo", 160);
  } else {
    delete profile.groupId;
    delete profile.groupName;
  }
  if (caller.isSuperadmin !== true && profile.role === "Administrador") {
    throw new HttpsError(
        "permission-denied",
        "Solo el superadministrador puede crear administradores.",
    );
  }
  if (!sameTenant(caller, profile)) {
    throw new HttpsError(
        "permission-denied",
        "No puedes crear usuarios en otra institucion o sede.",
    );
  }
  const requestedPermissions = Array.isArray(profile.permissions) ?
    [...new Set(profile.permissions
        .filter((item) => typeof item === "string")
        .map((item) => item.trim().toLowerCase())
        .filter((item) => item && item.length <= 100))] : [];
  profile.permissions = caller.isSuperadmin === true ?
    requestedPermissions : requestedPermissions.filter(
        (permission) => !RESTRICTED_DELEGATED_PERMISSIONS.has(permission),
    );
  profile.permissions = permissionsForRole(profile.role, profile.permissions);
  profile.studentIds = Array.isArray(profile.studentIds) ?
    profile.studentIds : [];
  profile.phones = Array.isArray(profile.phones) ? profile.phones : [];
  profile.isSuperadmin = false;
  profile.status = profile.status === "inactivo" ? "inactivo" : "activo";
  profile.id = uid;
  profile.createdAt = FieldValue.serverTimestamp();
  profile.updatedAt = FieldValue.serverTimestamp();
  return profile;
}

/**
 * Comprueba que el grupo academico pertenezca exactamente a la sede.
 * @param {Object} profile Perfil u objeto con tenant y groupId.
 * @return {Promise<Object>} Grupo validado.
 */
async function requireAcademicGroup(profile) {
  const groupId = requiredString(profile.groupId, "grupo", 160);
  const snapshot = await db.collection("academic_groups").doc(groupId).get();
  const group = snapshot.data() || {};
  const institution = profile.institution || profile.institutionId;
  const campus = profile.campus || profile.campusId;
  if (!snapshot.exists || group.active !== true ||
      group.institutionId !== institution || group.campusId !== campus) {
    throw new HttpsError(
        "failed-precondition", "El grupo no pertenece a la sede seleccionada.",
    );
  }
  return {id: snapshot.id, ...group};
}

/** @param {Object} profile Perfil a completar. @return {Promise<void>} */
async function attachValidatedGroup(profile) {
  if (!["Estudiante", "Docente"].includes(profile.role)) return;
  const group = await requireAcademicGroup(profile);
  profile.groupId = group.id;
  profile.groupName = group.name;
}

/**
 * Impide documentos y correos duplicados incluso si se omite el formulario.
 * @param {Object} profile Perfil normalizado.
 * @param {string?} excludeUid Usuario excluido durante una edicion.
 */
async function ensureUniqueProfile(profile, excludeUid = null) {
  const checks = [
    ["document", profile.document, "El documento ya esta registrado."],
    ["personalEmail", profile.personalEmail,
      "El correo personal ya esta registrado."],
    ["institutionalEmail", profile.institutionalEmail,
      "El correo institucional ya esta registrado."],
  ];
  for (const [field, value, message] of checks) {
    const snapshot = await db.collection("users")
        .where(field, "==", value).limit(2).get();
    if (snapshot.docs.some((item) => item.id !== excludeUid)) {
      throw new HttpsError("already-exists", message);
    }
  }
}

/**
 * Verifica que un familiar solo quede ligado a estudiantes de su misma sede.
 * @param {Object} profile Perfil normalizado.
 */
async function validateFamilyLinks(profile) {
  if (profile.role !== "Familiar") {
    profile.studentIds = [];
    profile.activeStudentId = null;
    return;
  }
  const uniqueIds = [...new Set(profile.studentIds)];
  if (uniqueIds.length > 20) {
    throw new HttpsError(
        "invalid-argument", "Un familiar tiene demasiados estudiantes.",
    );
  }
  for (const uid of uniqueIds) {
    if (typeof uid !== "string" || !uid.trim()) {
      throw new HttpsError("invalid-argument", "Vinculo familiar no valido.");
    }
    const student = await db.collection("users").doc(uid).get();
    const data = student.data() || {};
    if (!student.exists || data.role !== "Estudiante" ||
        data.status !== "activo" ||
        data.institution !== profile.institution ||
        data.campus !== profile.campus) {
      throw new HttpsError(
          "failed-precondition",
          "El familiar contiene estudiantes no validos para esta sede.",
      );
    }
  }
  profile.studentIds = uniqueIds;
  if (profile.activeStudentId &&
      !uniqueIds.includes(profile.activeStudentId)) {
    throw new HttpsError(
        "invalid-argument", "El estudiante activo no esta vinculado.",
    );
  }
}

/**
 * Confirma que la sede exista dentro de la institucion configurada.
 * @param {Object} profile Perfil normalizado.
 */
async function validateInstitutionCampus(profile) {
  const byField = await db.collection("configuracion_colegios")
      .where("institutionId", "==", profile.institution).limit(1).get();
  let institution = byField.docs[0];
  if (!institution) {
    const byId = await db.collection("configuracion_colegios")
        .doc(profile.institution).get();
    if (byId.exists) institution = byId;
  }
  if (!institution) {
    throw new HttpsError(
        "failed-precondition", "La institucion seleccionada no existe.",
    );
  }
  const rawCampuses = institution.data().sedes;
  const campuses = Array.isArray(rawCampuses) ? rawCampuses.map((item) => {
    if (item && typeof item === "object") {
      return (item.id || item.nombre || "").toString().trim();
    }
    return (item || "").toString().trim();
  }) : [];
  if (!campuses.includes(profile.campus)) {
    throw new HttpsError(
        "failed-precondition",
        "La sede no pertenece a la institucion seleccionada.",
    );
  }
}

/**
 * Elimina por lotes todos los documentos de una consulta.
 * @param {FirebaseFirestore.Query} query Consulta a eliminar.
 * @return {Promise<void>}
 */
async function deleteQuery(query) {
  const snapshot = await query.limit(400).get();
  if (snapshot.empty) return;
  const batch = db.batch();
  snapshot.docs.forEach((item) => batch.delete(item.ref));
  await batch.commit();
  return deleteQuery(query);
}

/** @param {FirebaseFirestore.QuerySnapshot} snapshot Consulta realizada. */
function snapshotDocuments(snapshot) {
  return snapshot.docs || [];
}

/**
 * Une documentos sin repetir referencias.
 * @param {Array<Array<FirebaseFirestore.QueryDocumentSnapshot>>} groups Listas.
 * @return {Array<FirebaseFirestore.QueryDocumentSnapshot>} Documentos unicos.
 */
function uniqueDocuments(...groups) {
  const found = new Map();
  groups.flat().forEach((item) => found.set(item.ref.path, item));
  return [...found.values()];
}

/**
 * Carga todas las relaciones conocidas de un usuario antes de eliminarlo.
 * Los historiales se cuentan, pero se conservan como evidencia institucional.
 * @param {FirebaseFirestore.DocumentSnapshot} targetSnap Usuario objetivo.
 * @return {Promise<Object>} Relaciones e impacto legible.
 */
async function userDeletionContext(targetSnap) {
  const uid = targetSnap.id;
  const target = targetSnap.data() || {};
  const document = (target.document || "").toString().trim();

  const [familiesSnap, routeStudentsSnap, routeManagersSnap,
    subjectsSnap, enrollmentCreatorsSnap, enrollmentUsersSnap,
    authorizationRequestersSnap,
    authorizationStudentsSnap, filesSnap, threadsSnap, logsSnap,
    historySnap, dailyRoutesSnap] = await Promise.all([
    db.collection("users").where("studentIds", "array-contains", uid).get(),
    db.collection("routes").where("estudiantes", "array-contains", uid).get(),
    db.collection("routes").where("gestionador", "==", uid).get(),
    db.collection("subjects").where("teacherId", "==", uid).get(),
    db.collection("enrollments").where("createdByUserId", "==", uid).get(),
    db.collection("enrollments").where("vinculaUsuarioId", "==", uid).get(),
    db.collection("authorization_requests")
        .where("requesterId", "==", uid).get(),
    db.collection("authorization_requests")
        .where("studentId", "==", uid).get(),
    db.collection("files").where("uploadedBy", "==", uid).get(),
    db.collection("message_threads")
        .where("participantIds", "array-contains", uid).get(),
    db.collection("user_logs").where("userId", "==", uid).get(),
    db.collection("user_history").where("usuarioId", "==", uid).get(),
    db.collection("daily_routes")
        .where("institution", "==", target.institution)
        .where("campus", "==", target.campus).get(),
  ]);

  let enrollmentDocuments = [];
  if (document) {
    enrollmentDocuments = snapshotDocuments(
        await db.collection("enrollments")
            .where("data.numeroIdentidad", "==", document).get(),
    );
  }

  const dailyStudentRefs = [];
  const dailyManagerDocs = [];
  for (const route of dailyRoutesSnap.docs) {
    if (route.data().gestionador === uid) {
      dailyManagerDocs.push(route);
    }
    const studentRef = route.ref.collection("students").doc(uid);
    if ((await studentRef.get()).exists) dailyStudentRefs.push(studentRef);
  }

  const families = snapshotDocuments(familiesSnap);
  const routes = uniqueDocuments(
      snapshotDocuments(routeStudentsSnap),
      snapshotDocuments(routeManagersSnap),
  );
  const subjects = snapshotDocuments(subjectsSnap);
  const enrollments = uniqueDocuments(
      snapshotDocuments(enrollmentCreatorsSnap),
      snapshotDocuments(enrollmentUsersSnap),
      enrollmentDocuments,
  );
  const authorizations = uniqueDocuments(
      snapshotDocuments(authorizationRequestersSnap),
      snapshotDocuments(authorizationStudentsSnap),
  );
  const files = snapshotDocuments(filesSnap);
  const threads = snapshotDocuments(threadsSnap);
  const auditCount = logsSnap.size + historySnap.size;

  const impact = [
    {key: "enrollments", label: "Matriculas", count: enrollments.length,
      action: "delete"},
    {key: "authorizations", label: "Autorizaciones",
      count: authorizations.length, action: "delete"},
    {key: "files", label: "Archivos subidos", count: files.length,
      action: "delete"},
    {key: "messages", label: "Conversaciones", count: threads.length,
      action: "delete"},
    {key: "families", label: "Vinculos familiares", count: families.length,
      action: "unlink"},
    {key: "routes", label: "Rutas", count: routes.length,
      action: "unlink"},
    {key: "dailyRoutes", label: "Ejecuciones de ruta",
      count: dailyStudentRefs.length + dailyManagerDocs.length,
      action: "unlink"},
    {key: "subjects", label: "Materias u horarios", count: subjects.length,
      action: "unlink"},
    {key: "audit", label: "Registros de auditoria", count: auditCount,
      action: "preserve"},
  ];

  return {
    target,
    families,
    routes,
    subjects,
    enrollments,
    authorizations,
    files,
    threads,
    dailyStudentRefs,
    dailyManagerDocs,
    impact,
    storagePaths: files.map((item) => item.data().storagePath)
        .filter((path) => typeof path === "string" && path.trim()),
  };
}

/**
 * Elimina referencias por lotes.
 * @param {Array<FirebaseFirestore.DocumentSnapshot>} documents Documentos.
 * @return {Promise<void>}
 */
async function deleteDocuments(documents) {
  for (let i = 0; i < documents.length; i += 400) {
    const batch = db.batch();
    documents.slice(i, i + 400)
        .forEach((item) => batch.delete(item.ref || item));
    await batch.commit();
  }
}

/**
 * Exige un permiso granular de matriculas a administradores o docentes.
 * @param {Object} caller Usuario llamador.
 * @param {string} action Accion solicitada.
 */
function requireEnrollmentAction(caller, action) {
  if (caller.isSuperadmin === true) return;
  const permissions = Array.isArray(caller.permissions) ?
    caller.permissions : [];
  if (["Administrador", "Docente"].includes(caller.role) &&
      permissions.includes(`matricula.${action}`)) return;
  throw new HttpsError(
      "permission-denied", `No tienes permiso de matricula.${action}.`,
  );
}

/** @param {Object} data Datos de matricula. @return {string} Grupo. */
function enrollmentGroupId(data) {
  return (data.groupId || "").toString().trim();
}

/** @param {Object} data Datos. @param {Object} group Grupo. @return {Object} */
function normalizedEnrollmentData(data, group) {
  const clean = {...data};
  clean.groupId = group.id;
  clean.groupName = group.name;
  return clean;
}

/**
 * Valida el usuario estudiantil asociado a una matricula.
 * @param {string} uid Usuario estudiante.
 * @param {string} institution Institucion.
 * @param {string} campus Sede.
 * @return {Promise<Object>} Perfil estudiantil.
 */
async function requireLinkedStudent(uid, institution, campus) {
  const cleanUid = requiredString(uid, "estudiante vinculado", 128);
  const snapshot = await db.collection("users").doc(cleanUid).get();
  const student = snapshot.data() || {};
  if (!snapshot.exists || student.role !== "Estudiante" ||
      student.status !== "activo" ||
      student.institution !== institution || student.campus !== campus) {
    throw new HttpsError(
        "failed-precondition",
        "El estudiante vinculado no es valido para esta sede.",
    );
  }
  return {uid: cleanUid, ...student};
}

/**
 * Registra y envia una notificacion de matricula sin bloquear el tramite.
 * @param {Object} enrollment Matricula resultante.
 * @param {string} event Evento.
 * @return {Promise<void>}
 */
async function notifyEnrollment(enrollment, event) {
  try {
    const groupId = enrollmentGroupId(enrollment.data || {});
    const recipientIds = new Set();
    if (event === "created" || event === "resubmitted") {
      const staff = await db.collection("users")
          .where("institution", "==", enrollment.institution)
          .where("campus", "==", enrollment.campus)
          .where("status", "==", "activo").get();
      staff.docs.forEach((item) => {
        const user = item.data();
        const permissions = Array.isArray(user.permissions) ?
          user.permissions : [];
        const adminAllowed = user.isSuperadmin === true ||
          (user.role === "Administrador" &&
           (permissions.includes("matricula.ver") ||
            permissions.includes("matricula.editar")));
        const teacherAllowed = user.role === "Docente" &&
          user.groupId === groupId &&
          (permissions.includes("matricula.ver") ||
           permissions.includes("matricula.editar"));
        if (adminAllowed || teacherAllowed) recipientIds.add(item.id);
      });
    } else {
      if (enrollment.createdByUserId) {
        recipientIds.add(enrollment.createdByUserId);
      }
      if (enrollment.vinculaUsuarioId) {
        const families = await db.collection("users")
            .where("studentIds", "array-contains",
                enrollment.vinculaUsuarioId).get();
        families.docs.forEach((item) => recipientIds.add(item.id));
      }
    }

    const tokens = new Set();
    for (const uid of recipientIds) {
      const user = await db.collection("users").doc(uid).get();
      const tokenMap = user.data()?.notificationTokens || {};
      for (const token of [tokenMap.web, tokenMap.mobile]) {
        if (typeof token === "string" && token.trim()) tokens.add(token);
      }
    }
    const title = "Matricula actualizada";
    const body = `Estado: ${enrollment.estado}`;
    if (tokens.size) {
      await messaging.sendEachForMulticast({
        notification: {title, body},
        tokens: [...tokens],
      });
    }
    await db.collection("enrollment_notification_events").add({
      enrollmentId: enrollment.id,
      event,
      estado: enrollment.estado,
      recipientIds: [...recipientIds],
      institution: enrollment.institution,
      campus: enrollment.campus,
      groupId,
      groupName: enrollment.data?.groupName || "",
      createdAt: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.error("Notificacion de matricula omitida:", error.code || error);
  }
}

/** @param {Object} caller Usuario. @param {string} action Permiso. */
function requireAuthorizationAction(caller, action) {
  if (caller.isSuperadmin === true) return;
  const permissions = Array.isArray(caller.permissions) ?
    caller.permissions : [];
  if (caller.role === "Administrador" &&
      permissions.includes(`autorizaciones.${action}`)) return;
  throw new HttpsError(
      "permission-denied", `No tienes permiso de autorizaciones.${action}.`,
  );
}

/** @param {Object} caller Usuario. @param {string} action Permiso. */
function requireScheduleAction(caller, action) {
  if (caller.isSuperadmin === true) return;
  const permissions = Array.isArray(caller.permissions) ?
    caller.permissions : [];
  if (caller.role === "Administrador" &&
      permissions.includes(`horarios.${action}`)) return;
  throw new HttpsError(
      "permission-denied", `No tienes permiso de horarios.${action}.`,
  );
}

/** @param {Object} caller Usuario. @param {string} action Accion. */
function requireFileAction(caller, action) {
  if (caller.isSuperadmin === true) return;
  const permissions = Array.isArray(caller.permissions) ?
    caller.permissions : [];
  if (["Administrador", "Docente"].includes(caller.role) &&
      permissions.includes(`archivos.${action}`)) return;
  throw new HttpsError(
      "permission-denied", `No tienes permiso de archivos.${action}.`,
  );
}

/** @param {string} institution Institucion. @return {string} Documento. */
function fileUsageId(institution) {
  return crypto.createHash("sha256").update(institution).digest("hex");
}

/** @param {*} value Bytes esperados. @return {number} Bytes validados. */
function validatedFileSize(value) {
  const size = Number(value);
  if (!Number.isInteger(size) || size <= 0 ||
      size > FILE_UPLOAD_LIMIT_BYTES) {
    throw new HttpsError(
        "invalid-argument", "El archivo supera el limite de 25 MiB.",
    );
  }
  return size;
}

/** @param {*} value MIME. @return {string} MIME validado. */
function validatedFileMime(value) {
  const mime = requiredString(value, "tipo de archivo", 150).toLowerCase();
  if (!FILE_MIME_TYPES.has(mime)) {
    throw new HttpsError("invalid-argument", "Tipo de archivo no permitido.");
  }
  return mime;
}

/** @param {string} name Nombre original. @return {string} Nombre seguro. */
function safeFileName(name) {
  const clean = [...requiredString(name, "nombre del archivo", 180)]
      .map((character) => character === "/" || character === "\\" ||
        character.charCodeAt(0) < 32 ? "_" : character)
      .join("");
  if (!/\.(pdf|doc|docx|xls|xlsx)$/i.test(clean)) {
    throw new HttpsError("invalid-argument", "Extension no permitida.");
  }
  return clean;
}

/**
 * Comprueba acceso de escritura a un grupo.
 * @param {Object} caller Usuario.
 * @param {Object} group Grupo.
 */
function requireFileGroupAccess(caller, group) {
  if (!sameTenant(caller, group)) {
    throw new HttpsError("permission-denied", "Grupo fuera de tu sede.");
  }
  if (caller.isSuperadmin !== true && caller.role === "Docente" &&
      caller.groupId !== group.id) {
    throw new HttpsError(
        "permission-denied", "Solo puedes publicar para tu grupo asignado.",
    );
  }
}

const SCHEDULE_DAYS = new Set([
  "lunes", "martes", "miercoles", "jueves", "viernes",
]);

/** @param {*} value Minutos del dia. @param {string} field Campo. */
function scheduleMinutes(value, field) {
  const minutes = Number(value);
  if (!Number.isInteger(minutes) || minutes < 0 || minutes >= 24 * 60) {
    throw new HttpsError("invalid-argument", `${field} no es valida.`);
  }
  return minutes;
}

/** @param {*} value Timestamp antiguo. @return {number} Minutos Bogota. */
function legacyScheduleMinutes(value) {
  const date = value?.toDate?.();
  if (!(date instanceof Date)) return -1;
  const bogotaHour = (date.getUTCHours() + 19) % 24;
  return bogotaHour * 60 + date.getUTCMinutes();
}

/**
 * Valida horario, docente y sede.
 * @param {Object} input Datos recibidos.
 * @param {string} institution Institucion.
 * @param {string} campus Sede.
 * @return {Promise<Object>} Horario normalizado.
 */
async function validatedScheduleData(input, institution, campus) {
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    throw new HttpsError("invalid-argument", "Horario no valido.");
  }
  const subject = requiredString(input.subject, "materia", 120);
  const group = await requireAcademicGroup({
    groupId: input.groupId,
    institutionId: institution,
    campusId: campus,
  });
  const day = requiredString(input.day, "dia", 20).toLowerCase();
  if (!SCHEDULE_DAYS.has(day)) {
    throw new HttpsError("invalid-argument", "Dia no valido.");
  }
  const startMinutes = scheduleMinutes(input.startMinutes, "hora inicial");
  const endMinutes = scheduleMinutes(input.endMinutes, "hora final");
  if (endMinutes <= startMinutes) {
    throw new HttpsError(
        "invalid-argument", "La hora final debe ser posterior.",
    );
  }
  const teacherId = requiredString(input.teacherId, "docente", 128);
  const teacherSnapshot = await db.collection("users").doc(teacherId).get();
  const teacher = teacherSnapshot.data() || {};
  if (!teacherSnapshot.exists || teacher.role !== "Docente" ||
      teacher.status !== "activo" || teacher.institution !== institution ||
      teacher.campus !== campus) {
    throw new HttpsError(
        "failed-precondition", "El docente no es valido para esta sede.",
    );
  }
  const baseDate = Date.UTC(2000, 0, 1);
  return {
    subject,
    groupId: group.id,
    groupName: group.name,
    day,
    teacherId,
    teacherName: `${teacher.firstName || ""} ` +
      `${teacher.lastName || ""}`.trim(),
    startMinutes,
    endMinutes,
    startTime: Timestamp.fromMillis(baseDate + (startMinutes + 300) * 60000),
    endTime: Timestamp.fromMillis(baseDate + (endMinutes + 300) * 60000),
    institutionId: institution,
    campusId: campus,
  };
}

/**
 * Detecta choques de grado o docente.
 * @param {FirebaseFirestore.Transaction} transaction Transaccion.
 * @param {Object} schedule Horario propuesto.
 * @param {string?} excludeId Documento excluido.
 */
async function ensureNoScheduleConflict(transaction, schedule, excludeId) {
  const query = db.collection("subjects")
      .where("institutionId", "==", schedule.institutionId)
      .where("campusId", "==", schedule.campusId)
      .where("day", "==", schedule.day);
  const snapshot = await transaction.get(query);
  for (const item of snapshot.docs) {
    if (item.id === excludeId) continue;
    const current = item.data();
    const start = Number.isInteger(current.startMinutes) ?
      current.startMinutes : legacyScheduleMinutes(current.startTime);
    const end = Number.isInteger(current.endMinutes) ?
      current.endMinutes : legacyScheduleMinutes(current.endTime);
    const overlaps = start >= 0 && end >= 0 &&
      schedule.startMinutes < end && schedule.endMinutes > start;
    if (!overlaps) continue;
    if (current.groupId === schedule.groupId) {
      throw new HttpsError(
          "already-exists", "El grupo ya tiene clase en ese horario.",
      );
    }
    if (current.teacherId === schedule.teacherId) {
      throw new HttpsError(
          "already-exists", "El docente ya tiene clase en ese horario.",
      );
    }
  }
}

/** @param {Object} schedule Horario. @param {string} event Evento. */
async function notifySchedule(schedule, event) {
  try {
    const snapshot = await db.collection("users")
        .where("institution", "==", schedule.institutionId)
        .where("campus", "==", schedule.campusId)
        .where("status", "==", "activo").get();
    const studentsById = new Map();
    snapshot.docs.forEach((item) => {
      const user = item.data();
      if (user.role === "Estudiante") studentsById.set(item.id, user);
    });
    const recipients = new Set();
    snapshot.docs.forEach((item) => {
      const user = item.data();
      const permissions = Array.isArray(user.permissions) ?
        user.permissions : [];
      if (!permissions.includes("horarios.ver")) return;
      if (user.role === "Estudiante" &&
          user.groupId === schedule.groupId) {
        recipients.add(item.id);
      }
      if (user.role === "Familiar" && Array.isArray(user.studentIds) &&
          user.studentIds.some((id) =>
            studentsById.get(id)?.groupId === schedule.groupId)) {
        recipients.add(item.id);
      }
      if (user.role === "Docente" &&
          (item.id === schedule.teacherId ||
           user.groupId === schedule.groupId)) {
        recipients.add(item.id);
      }
    });
    const tokens = new Set();
    for (const uid of recipients) {
      const tokenMap = snapshot.docs.find((item) => item.id === uid)
          ?.data()?.notificationTokens || {};
      for (const token of [tokenMap.web, tokenMap.mobile]) {
        if (typeof token === "string" && token.trim()) tokens.add(token);
      }
    }
    if (tokens.size) {
      await messaging.sendEachForMulticast({
        notification: {
          title: "Horario actualizado",
          body: `${schedule.groupName}: ${schedule.subject} ` +
            `(${schedule.day})`,
        },
        tokens: [...tokens],
      });
    }
    await db.collection("schedule_notification_events").add({
      subjectId: schedule.id,
      event,
      institutionId: schedule.institutionId,
      campusId: schedule.campusId,
      groupId: schedule.groupId,
      groupName: schedule.groupName,
      recipientIds: [...recipients],
      createdAt: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.error("Notificacion de horario omitida:", error.code || error);
  }
}

/** @param {*} value Marca temporal. @param {string} field Campo. */
function authorizationTimestamp(value, field) {
  const millis = Number(value);
  if (!Number.isFinite(millis) || millis < 0) {
    throw new HttpsError("invalid-argument", `${field} no es valida.`);
  }
  return Timestamp.fromMillis(millis);
}

/**
 * Valida los campos modificables de una solicitud.
 * @param {Object} input Campos recibidos.
 * @param {Object} student Estudiante validado.
 * @return {Object} Datos normalizados.
 */
function validatedAuthorizationData(input, student) {
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    throw new HttpsError("invalid-argument", "Solicitud no valida.");
  }
  const allDay = input.allDay === true;
  const multiDay = input.multiDay === true;
  const dateFrom = authorizationTimestamp(input.dateFrom, "fecha inicial");
  const dateTo = multiDay ?
    authorizationTimestamp(input.dateTo, "fecha final") : null;
  if (dateTo && dateTo.toMillis() < dateFrom.toMillis()) {
    throw new HttpsError(
        "invalid-argument", "La fecha final no puede ser anterior.",
    );
  }
  let startTime = null;
  let endTime = null;
  if (!allDay) {
    startTime = authorizationTimestamp(input.startTime, "hora inicial");
    if (input.endTime != null) {
      endTime = authorizationTimestamp(input.endTime, "hora final");
      if (endTime.toMillis() <= startTime.toMillis()) {
        throw new HttpsError(
            "invalid-argument", "La hora final debe ser posterior.",
        );
      }
    }
  }
  const reason = requiredString(input.reason, "motivo", 2000);
  return {
    studentId: student.uid,
    studentFullName:
      `${student.firstName || ""} ${student.lastName || ""}`.trim(),
    groupId: requiredString(student.groupId, "grupo del estudiante", 160),
    groupName: requiredString(
        student.groupName, "nombre del grupo del estudiante", 80,
    ),
    allDay,
    multiDay,
    dateFrom,
    dateTo,
    startTime,
    endTime,
    reason,
  };
}

/**
 * Notifica eventos de autorizacion sin bloquear la operacion principal.
 * @param {Object} authorization Solicitud resultante.
 * @param {string} event Evento.
 */
async function notifyAuthorization(authorization, event) {
  try {
    const recipients = new Set();
    const staff = await db.collection("users")
        .where("institution", "==", authorization.institutionId)
        .where("campus", "==", authorization.campusId)
        .where("status", "==", "activo").get();
    staff.docs.forEach((item) => {
      const user = item.data();
      const permissions = Array.isArray(user.permissions) ?
        user.permissions : [];
      const adminAllowed = user.isSuperadmin === true ||
        (user.role === "Administrador" &&
         (permissions.includes("autorizaciones.ver") ||
          permissions.includes("autorizaciones.editar")));
      const teacherAllowed = user.role === "Docente" &&
        user.groupId === authorization.groupId &&
        permissions.includes("autorizaciones.ver");
      if (adminAllowed || teacherAllowed) recipients.add(item.id);
    });
    if (event !== "created" && authorization.requesterId) {
      recipients.add(authorization.requesterId);
    }
    const tokens = new Set();
    for (const uid of recipients) {
      const user = await db.collection("users").doc(uid).get();
      const tokenMap = user.data()?.notificationTokens || {};
      for (const token of [tokenMap.web, tokenMap.mobile]) {
        if (typeof token === "string" && token.trim()) tokens.add(token);
      }
    }
    if (tokens.size) {
      await messaging.sendEachForMulticast({
        notification: {
          title: event === "created" ?
            "Nueva autorizacion" : "Autorizacion actualizada",
          body: `${authorization.studentFullName}: ${authorization.status}`,
        },
        tokens: [...tokens],
      });
    }
    await db.collection("authorization_notification_events").add({
      authorizationId: authorization.id,
      event,
      status: authorization.status,
      recipientIds: [...recipients],
      institutionId: authorization.institutionId,
      campusId: authorization.campusId,
      groupId: authorization.groupId,
      groupName: authorization.groupName,
      createdAt: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.error("Notificacion de autorizacion omitida:", error.code || error);
  }
}

/**
 * Conserva solo tokens registrados para usuarios del tenant del llamador.
 * @param {Object} caller Perfil que envia la notificacion.
 * @param {string[]} requested Tokens solicitados.
 * @return {Promise<string[]>} Tokens autorizados.
 */
async function filterTenantTokens(caller, requested) {
  const allowed = new Set();
  for (let i = 0; i < requested.length; i += 30) {
    const chunk = requested.slice(i, i + 30);
    for (const slot of ["web", "mobile"]) {
      const snapshot = await db.collection("users")
          .where(`notificationTokens.${slot}`, "in", chunk)
          .get();
      snapshot.docs.forEach((item) => {
        const user = item.data();
        const authorized = user.status === "activo" &&
          (caller.isSuperadmin === true ||
           (user.institution === caller.institution &&
            user.campus === caller.campus));
        const token = user.notificationTokens?.[slot];
        if (authorized && typeof token === "string") allowed.add(token);
      });
    }
  }
  return requested.filter((token) => allowed.has(token));
}

/**
 * @param {Object} caller Usuario llamador.
 * @param {string} type Flujo.
 * @return {void}
 */
function requireNotificationAccess(caller, type) {
  const permissions = Array.isArray(caller.permissions) ?
    caller.permissions : [];
  const privileged = caller.isSuperadmin === true ||
    caller.role === "Administrador";
  if (type === "authorization") return;
  if (type === "messaging" &&
      (privileged || permissions.includes("mensajeria.ver"))) return;
  if (["route", "schedule", "file"].includes(type) &&
      (privileged || caller.role === "Docente")) return;
  throw new HttpsError(
      "permission-denied",
      "No tienes permiso para este tipo de notificacion.",
  );
}

/**
 * Limita el abuso sin impedir los envios masivos legitimos de rutas.
 * @param {string} uid Usuario llamador.
 * @return {Promise<void>}
 */
async function enforceNotificationRateLimit(uid) {
  const ref = db.collection("notification_rate_limits").doc(uid);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const now = Date.now();
    const value = snapshot.data() || {};
    const windowStart = value.windowStart?.toMillis?.() || 0;
    const sameWindow = now - windowStart < 60 * 1000;
    const count = sameWindow ? Number(value.count || 0) : 0;
    if (count >= 300) {
      throw new HttpsError(
          "resource-exhausted",
          "Demasiadas notificaciones. Intenta nuevamente en un minuto.",
      );
    }
    transaction.set(ref, {
      count: count + 1,
      windowStart: sameWindow ? value.windowStart :
        Timestamp.fromMillis(now),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
}

/**
 * Resuelve destinatarios sin exponer tokens al cliente.
 * @param {Object} caller Usuario llamador.
 * @param {Object} audience Audiencia solicitada.
 * @return {Promise<string[]>} Tokens autorizados.
 */
async function resolveAudienceTokens(caller, audience) {
  const users = new Map();
  const base = db.collection("users")
      .where("institution", "==", caller.institution)
      .where("campus", "==", caller.campus);
  const addDocs = (snapshot) => snapshot.docs.forEach((item) => {
    const value = item.data();
    if (value.status === "activo") users.set(item.id, value);
  });
  const userIds = Array.isArray(audience.userIds) ?
    [...new Set(audience.userIds.filter((id) => typeof id === "string"))] : [];
  const studentIds = Array.isArray(audience.studentIds) ?
    [...new Set(audience.studentIds
        .filter((id) => typeof id === "string"))] : [];
  const roles = Array.isArray(audience.roles) ?
    [...new Set(audience.roles.filter((role) => ALLOWED_ROLES.has(role)))] : [];
  if (userIds.length > 500 || studentIds.length > 500 || roles.length > 5) {
    throw new HttpsError(
        "invalid-argument",
        "La audiencia es demasiado grande.",
    );
  }
  const groupId = typeof audience.groupId === "string" ?
    audience.groupId.trim() : "";

  for (let i = 0; i < userIds.length; i += 30) {
    addDocs(await base.where(FieldPath.documentId(), "in",
        userIds.slice(i, i + 30)).get());
  }
  for (let i = 0; i < studentIds.length; i += 30) {
    addDocs(await base.where(FieldPath.documentId(), "in",
        studentIds.slice(i, i + 30)).get());
  }
  for (const role of roles) {
    let query = base.where("role", "==", role).where("status", "==", "activo");
    if (groupId && role !== "Administrador") {
      query = query.where("groupId", "==", groupId);
    }
    addDocs(await query.get());
  }

  let familyStudentIds = [...studentIds];
  if (audience.includeFamiliesForGroup === true && groupId) {
    const students = await base.where("role", "==", "Estudiante")
        .where("status", "==", "activo")
        .where("groupId", "==", groupId).get();
    addDocs(students);
    familyStudentIds = [
      ...new Set([
        ...familyStudentIds,
        ...students.docs.map((item) => item.id),
      ]),
    ];
  }
  if (audience.includeFamilies === true ||
      audience.includeFamiliesForGroup === true) {
    for (let i = 0; i < familyStudentIds.length; i += 30) {
      addDocs(await base.where("role", "==", "Familiar")
          .where("studentIds", "array-contains-any",
              familyStudentIds.slice(i, i + 30)).get());
    }
  }

  const tokens = new Set();
  users.forEach((user) => {
    for (const slot of ["web", "mobile"]) {
      const token = user.notificationTokens?.[slot];
      if (typeof token === "string" && token.length >= 20) tokens.add(token);
    }
    for (const legacy of [user.fcmToken, user.webPushToken,
      user.mobilePushToken]) {
      if (typeof legacy === "string" && legacy.length >= 20) tokens.add(legacy);
    }
  });
  return [...tokens];
}

exports.enviarNotificacion = onCall(async (request) => {
  const caller = await getCaller(request);
  const data = request.data || {};
  const titulo = requiredString(data.titulo, "titulo", 120);
  const cuerpo = requiredString(data.cuerpo, "cuerpo", 500);
  const notificationType = requiredString(data.notificationType, "tipo", 30);
  requireNotificationAccess(caller, notificationType);
  await enforceNotificationRateLimit(caller.uid);

  const rawTokens = Array.isArray(data.tokens) ? data.tokens : [];
  const requestedTokens = [...new Set(rawTokens
      .filter((token) => typeof token === "string")
      .map((token) => token.trim())
      .filter((token) => token.length >= 20 && token.length <= 4096))];
  if (requestedTokens.length > 1000) {
    throw new HttpsError("invalid-argument", "Hay demasiados destinatarios.");
  }
  const legacyTokens = requestedTokens.length > 0 ?
    await filterTenantTokens(caller, requestedTokens) : [];
  const audienceTokens = data.audience && typeof data.audience === "object" ?
    await resolveAudienceTokens(caller, data.audience) : [];
  const cleanTokens = [...new Set([...legacyTokens, ...audienceTokens])];
  if (cleanTokens.length === 0) {
    throw new HttpsError("invalid-argument", "No hay tokens validos.");
  }

  let successCount = 0;
  let failureCount = 0;
  const invalidTokens = [];

  for (let i = 0; i < cleanTokens.length; i += 500) {
    const batch = cleanTokens.slice(i, i + 500);
    const response = await messaging.sendEachForMulticast({
      notification: {title: titulo, body: cuerpo},
      android: {priority: "high"},
      apns: {payload: {aps: {sound: "default"}}},
      tokens: batch,
    });
    successCount += response.successCount;
    failureCount += response.failureCount;
    response.responses.forEach((item, index) => {
      const code = item.error?.code || "";
      if (code === "messaging/invalid-registration-token" ||
          code === "messaging/registration-token-not-registered") {
        invalidTokens.push(batch[index]);
      }
    });
  }

  return {
    exitosos: successCount,
    fallidos: failureCount,
    tokensInvalidos: invalidTokens,
  };
});

exports.resolverLoginPorDocumento = onCall(async (request) => {
  const documento = requiredString(request.data?.documento, "documento", 40);
  const remoteAddress = (request.rawRequest.ip || "unknown").toString();
  const rateId = crypto.createHash("sha256")
      .update(`student-login:${remoteAddress}`)
      .digest("hex");
  const rateRef = db.collection("student_login_rate_limits").doc(rateId);
  const now = Timestamp.now();
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(rateRef);
    const value = snapshot.data() || {};
    const windowStart = value.windowStart;
    const sameWindow = windowStart instanceof Timestamp &&
      now.toMillis() - windowStart.toMillis() < 60000;
    const attempts = sameWindow ? Number(value.attempts || 0) : 0;
    if (attempts >= 10) {
      throw new HttpsError(
          "resource-exhausted",
          "Demasiados intentos. Espera un minuto.",
      );
    }
    transaction.set(rateRef, {
      attempts: attempts + 1,
      windowStart: sameWindow ? windowStart : now,
      expiresAt: Timestamp.fromMillis(
          now.toMillis() + 24 * 60 * 60 * 1000,
      ),
    });
  });
  const snapshot = await db.collection("users")
      .where("document", "==", documento)
      .where("role", "==", "Estudiante")
      .limit(1)
      .get();

  if (snapshot.empty) {
    throw new HttpsError(
        "permission-denied",
        "No fue posible validar las credenciales.",
    );
  }
  const user = snapshot.docs[0].data();
  if ((user.status || "").toString().toLowerCase() !== "activo") {
    throw new HttpsError(
        "permission-denied",
        "No fue posible validar las credenciales.",
    );
  }
  const email = requiredString(
      user.institutionalEmail,
      "correo institucional",
      254,
  )
      .toLowerCase();
  return {email};
});

exports.crearUsuarioDesdeAdmin = onCall(async (request) => {
  const caller = await getCaller(request);
  requireAdmin(caller);
  requireUserAction(caller, "crear");
  const data = request.data || {};
  const email = requiredString(data.email, "email", 254).toLowerCase();
  const password = requiredString(data.password, "password", 128);
  const nombres = requiredString(data.nombres, "nombres", 100);
  const apellidos = requiredString(data.apellidos, "apellidos", 100);
  const rol = requiredString(data.rol, "rol", 30);
  requiredString(data.documento, "documento", 40);

  if (!ALLOWED_ROLES.has(rol) || password.length < 6) {
    throw new HttpsError("invalid-argument", "Rol o contrasena no validos.");
  }

  const profile = validatedProfile(data.profile, caller, "pending");
  if (profile.institutionalEmail !== email || profile.role !== rol ||
      profile.document !== data.documento.trim()) {
    throw new HttpsError(
        "invalid-argument",
        "El perfil no coincide con las credenciales solicitadas.",
    );
  }
  await ensureUniqueProfile(profile);
  await validateInstitutionCampus(profile);
  await attachValidatedGroup(profile);
  await validateFamilyLinks(profile);

  let usuario;
  try {
    usuario = await auth.createUser({
      email,
      password,
      displayName: `${nombres} ${apellidos}`.trim(),
    });
    profile.id = usuario.uid;
    if (rol !== "Estudiante") {
      await sendInstitutionalVerificationEmail(email, password);
      await auth.revokeRefreshTokens(usuario.uid);
    }
    const batch = db.batch();
    batch.create(db.collection("users").doc(usuario.uid), profile);
    batch.set(
        db.collection("user_directory").doc(usuario.uid),
        directoryData(profile),
    );
    batch.create(db.collection("user_history").doc(), {
      usuarioId: usuario.uid,
      nombres: profile.firstName,
      apellidos: profile.lastName,
      rol: profile.role,
      accion: "creado",
      realizadoPor: `${caller.firstName || ""} ${caller.lastName || ""}`.trim(),
      performedBy: caller.uid,
      institution: profile.institution,
      campus: profile.campus,
      fecha: FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return {exito: true, uid: usuario.uid};
  } catch (error) {
    console.error("Error creando usuario:", error.code);
    if (usuario?.uid) {
      try {
        await auth.deleteUser(usuario.uid);
      } catch (cleanupError) {
        console.error("Error revirtiendo usuario:", cleanupError.code);
      }
    }
    if (error.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "El correo ya esta registrado.");
    }
    if (error instanceof HttpsError) throw error;
    throw new HttpsError(
        "internal",
        "No se pudo crear el usuario ni enviar su correo de verificacion.",
    );
  }
});

exports.actualizarUsuarioDesdeAdmin = onCall(async (request) => {
  const caller = await getCaller(request);
  requireAdmin(caller);
  requireUserAction(caller, "editar");
  const uid = requiredString(request.data?.uid, "uid", 128);
  const targetRef = db.collection("users").doc(uid);
  const targetSnap = await targetRef.get();
  if (!targetSnap.exists || !sameTenant(caller, targetSnap.data())) {
    throw new HttpsError(
        "permission-denied", "No puedes modificar este usuario.",
    );
  }
  const target = targetSnap.data();
  if (target.status === "eliminado" || target.status === "eliminando") {
    throw new HttpsError(
        "failed-precondition", "No se puede editar un usuario retirado.",
    );
  }
  if (caller.isSuperadmin !== true &&
      (target.isSuperadmin === true || target.role === "Administrador")) {
    throw new HttpsError(
        "permission-denied",
        "Solo el superadministrador modifica administradores.",
    );
  }

  const profile = validatedProfile(request.data?.profile, caller, uid);
  await validateInstitutionCampus(profile);
  await attachValidatedGroup(profile);
  if (profile.institutionalEmail !== target.institutionalEmail) {
    throw new HttpsError(
        "failed-precondition",
        "El correo institucional requiere un flujo de cambio independiente.",
    );
  }
  if (caller.isSuperadmin !== true &&
      (profile.institution !== target.institution ||
       profile.campus !== target.campus)) {
    throw new HttpsError(
        "permission-denied", "No puedes mover usuarios entre sedes.",
    );
  }
  const changesTenant = profile.institution !== target.institution ||
    profile.campus !== target.campus;
  const changesRole = profile.role !== target.role;
  if (changesTenant || changesRole) {
    const context = await userDeletionContext(targetSnap);
    const linkedRecords = context.impact
        .filter((item) => item.action !== "preserve")
        .reduce((total, item) => total + item.count, 0);
    if (linkedRecords > 0) {
      throw new HttpsError(
          "failed-precondition",
          "El usuario tiene relaciones institucionales. Debes resolverlas " +
            "antes de cambiar su sede o rol.",
      );
    }
  }
  profile.status = target.status;
  profile.isSuperadmin = target.isSuperadmin === true;
  profile.createdAt = target.createdAt || FieldValue.serverTimestamp();
  profile.updatedAt = FieldValue.serverTimestamp();
  if (target.notificationTokens) {
    profile.notificationTokens = target.notificationTokens;
  }
  await ensureUniqueProfile(profile, uid);
  await validateInstitutionCampus(profile);
  await validateFamilyLinks(profile);

  const batch = db.batch();
  batch.set(targetRef, profile, {merge: true});
  batch.set(
      db.collection("user_directory").doc(uid),
      directoryData(profile),
      {merge: false},
  );
  batch.create(db.collection("user_history").doc(), {
    usuarioId: uid,
    nombres: profile.firstName,
    apellidos: profile.lastName,
    rol: profile.role,
    accion: "editado",
    realizadoPor:
      `${caller.firstName || ""} ${caller.lastName || ""}`.trim(),
    performedBy: caller.uid,
    institution: profile.institution,
    campus: profile.campus,
    fecha: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  return {success: true};
});

exports.crearMatricula = onCall(async (request) => {
  const input = request.data || {};
  const data = input.data;
  if (!data || typeof data !== "object" || Array.isArray(data) ||
      JSON.stringify(data).length > 100000) {
    throw new HttpsError("invalid-argument", "Formulario no valido.");
  }
  const document = requiredString(
      data.numeroIdentidad, "numero de identidad", 40,
  );
  if (document.length < 5) {
    throw new HttpsError("invalid-argument", "Documento no valido.");
  }
  const institution = requiredString(input.institution, "institucion", 120);
  const campus = requiredString(input.campus, "sede", 120);
  const year = Number(input.anioMatricula);
  if (!Number.isInteger(year) || year < 2000 || year > 2100) {
    throw new HttpsError("invalid-argument", "Ano de matricula no valido.");
  }
  await validateInstitutionCampus({institution, campus});
  let authenticatedCaller = null;
  if (request.auth?.uid) {
    authenticatedCaller = await getCaller(request);
    if (authenticatedCaller.role === "Administrador") {
      requireEnrollmentAction(authenticatedCaller, "editar");
      if (!sameTenant(authenticatedCaller, {institution, campus})) {
        throw new HttpsError(
            "permission-denied", "No puedes crear en otra sede.",
        );
      }
    }
  }
  const group = await requireAcademicGroup({
    groupId: data.groupId,
    institution,
    campus,
  });

  const caller = authenticatedCaller;
  let createdByRole = "publico";
  let createdByUserId = null;
  let linkedStudentId = input.vinculaUsuarioId || null;
  let estado = "prematriculado";
  if (request.auth?.uid) {
    createdByUserId = caller.uid;
    if (caller.role === "Familiar") {
      createdByRole = "padre";
      if (!Array.isArray(caller.studentIds) ||
          !caller.studentIds.includes(linkedStudentId)) {
        throw new HttpsError(
            "permission-denied",
            "Solo puedes matricular estudiantes vinculados a tu familia.",
        );
      }
      await requireLinkedStudent(linkedStudentId, institution, campus);
    } else if (caller.role === "Administrador") {
      createdByRole = "admin";
      estado = input.matricularAhora === true ?
        "matriculado" : "pendiente_revision";
      if (estado === "matriculado") {
        await requireLinkedStudent(linkedStudentId, institution, campus);
      }
    } else {
      throw new HttpsError(
          "permission-denied", "Tu rol no puede crear matriculas.",
      );
    }
  } else {
    const remoteAddress = (request.rawRequest.ip || "unknown").toString();
    const rateId = crypto.createHash("sha256")
        .update(`public-enrollment:${remoteAddress}`).digest("hex");
    const rateRef = db.collection("enrollment_rate_limits").doc(rateId);
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(rateRef);
      const value = snapshot.data() || {};
      const now = Timestamp.now();
      const start = value.windowStart;
      const sameWindow = start instanceof Timestamp &&
        now.toMillis() - start.toMillis() < 60 * 60 * 1000;
      const attempts = sameWindow ? Number(value.attempts || 0) : 0;
      if (attempts >= 5) {
        throw new HttpsError(
            "resource-exhausted", "Demasiadas solicitudes publicas.",
        );
      }
      transaction.set(rateRef, {
        attempts: attempts + 1,
        windowStart: sameWindow ? start : now,
        expiresAt: Timestamp.fromMillis(
            now.toMillis() + 24 * 60 * 60 * 1000,
        ),
      });
    });
    linkedStudentId = null;
  }

  const duplicate = await db.collection("enrollments")
      .where("data.numeroIdentidad", "==", document)
      .where("anioMatricula", "==", year).limit(1).get();
  if (!duplicate.empty) {
    throw new HttpsError(
        "already-exists",
        "Ya existe una matricula para este documento y ano escolar.",
    );
  }

  const enrollmentId = crypto.createHash("sha256")
      .update(`${year}:${document.toLowerCase()}`).digest("hex");
  const enrollmentRef = db.collection("enrollments").doc(enrollmentId);
  const enrollment = {
    id: enrollmentRef.id,
    estado,
    createdByRole,
    createdByUserId,
    token: typeof input.token === "string" ? input.token.slice(0, 200) : null,
    fuente: createdByRole === "publico" ? "qr_publico" :
      createdByRole === "padre" ? "app_padre" : "admin",
    vinculaUsuarioId: linkedStudentId,
    anioMatricula: year,
    institution,
    campus,
    data: normalizedEnrollmentData(
        {...data, numeroIdentidad: document}, group,
    ),
    fechaDiligenciamiento: FieldValue.serverTimestamp(),
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };
  const batch = db.batch();
  batch.create(enrollmentRef, enrollment);
  batch.create(db.collection("enrollment_history").doc(), {
    enrollmentId: enrollmentRef.id,
    action: "created",
    fromStatus: null,
    toStatus: estado,
    performedBy: caller?.uid || null,
    performedByRole: caller?.role || "publico",
    institution,
    campus,
    groupId: group.id,
    groupName: group.name,
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  await notifyEnrollment(enrollment, "created");
  return {success: true, id: enrollmentRef.id, estado};
});

exports.actualizarMatricula = onCall(async (request) => {
  const caller = await getCaller(request);
  const id = requiredString(request.data?.id, "matricula", 128);
  const action = requiredString(request.data?.action, "accion", 40);
  const ref = db.collection("enrollments").doc(id);
  const snapshot = await ref.get();
  if (!snapshot.exists) {
    throw new HttpsError("not-found", "La matricula no existe.");
  }
  const current = snapshot.data();
  if (!sameTenant(caller, current)) {
    throw new HttpsError("permission-denied", "Matricula fuera de tu sede.");
  }
  let groupId = enrollmentGroupId(current.data || {});
  let groupName = (current.data?.groupName || "").toString();
  const observation = typeof request.data?.observation === "string" ?
    request.data.observation.trim().slice(0, 2000) : "";
  const changes = {updatedAt: FieldValue.serverTimestamp()};
  let nextStatus = current.estado;

  if (caller.role === "Docente") {
    requireEnrollmentAction(caller, "editar");
    if (!caller.groupId || caller.groupId !== groupId) {
      throw new HttpsError(
          "permission-denied", "Solo puedes operar sobre tu grupo.",
      );
    }
    if (!["observe", "request_correction"].includes(action) || !observation) {
      throw new HttpsError(
          "invalid-argument", "La observacion docente es obligatoria.",
      );
    }
    changes.teacherObservation = observation;
    changes.teacherObservationBy = caller.uid;
    changes.teacherObservationAt = FieldValue.serverTimestamp();
    if (action === "request_correction") {
      if (!["prematriculado", "pendiente_revision"].includes(current.estado)) {
        throw new HttpsError(
            "failed-precondition", "Este estado no admite correcciones.",
        );
      }
      nextStatus = "correccion_solicitada";
    }
  } else if (caller.role === "Familiar") {
    const owns = current.createdByUserId === caller.uid ||
      (Array.isArray(caller.studentIds) &&
       caller.studentIds.includes(current.vinculaUsuarioId));
    if (!owns || action !== "resubmit" ||
        current.estado !== "correccion_solicitada") {
      throw new HttpsError(
          "permission-denied", "No puedes corregir esta matricula.",
      );
    }
    const data = request.data?.data;
    if (!data || typeof data !== "object" || Array.isArray(data) ||
        JSON.stringify(data).length > 100000) {
      throw new HttpsError("invalid-argument", "Formulario no valido.");
    }
    if ((data.numeroIdentidad || "").toString().trim() !==
        (current.data.numeroIdentidad || "").toString().trim()) {
      throw new HttpsError(
          "failed-precondition", "No puedes cambiar el documento.",
      );
    }
    const correctedGroup = await requireAcademicGroup({
      groupId: data.groupId,
      institution: current.institution,
      campus: current.campus,
    });
    changes.data = normalizedEnrollmentData({
      ...data,
      numeroIdentidad: current.data.numeroIdentidad,
    }, correctedGroup);
    groupId = correctedGroup.id;
    groupName = correctedGroup.name;
    nextStatus = "pendiente_revision";
  } else if (caller.role === "Administrador") {
    requireEnrollmentAction(caller, "editar");
    const requestedLinkedStudent = request.data?.vinculaUsuarioId;
    if (requestedLinkedStudent != null) {
      const linked = await requireLinkedStudent(
          requestedLinkedStudent, current.institution, current.campus,
      );
      changes.vinculaUsuarioId = linked.uid;
    }
    const transitions = {
      save_review: [
        ["prematriculado", "pendiente_revision"],
        ["pendiente_revision", "pendiente_revision"],
      ],
      update_enrolled: [["matriculado", "matriculado"]],
      approve: [
        ["prematriculado", "matriculado"],
        ["pendiente_revision", "matriculado"],
      ],
      reject: [
        ["prematriculado", "rechazado"],
        ["pendiente_revision", "rechazado"],
      ],
      withdraw: [["matriculado", "desmatriculado"]],
    };
    const selected = transitions[action] || [];
    const transition = selected.find((item) => item[0] === current.estado);
    if (!transition) {
      throw new HttpsError(
          "failed-precondition", "Transicion de matricula no permitida.",
      );
    }
    nextStatus = transition[1];
    const submittedData = request.data?.data;
    if (submittedData != null) {
      if (typeof submittedData !== "object" || Array.isArray(submittedData) ||
          JSON.stringify(submittedData).length > 100000) {
        throw new HttpsError("invalid-argument", "Formulario no valido.");
      }
      const submittedDocument = requiredString(
          submittedData.numeroIdentidad, "numero de identidad", 40,
      );
      const submittedGroup = await requireAcademicGroup({
        groupId: submittedData.groupId,
        institution: current.institution,
        campus: current.campus,
      });
      if (submittedDocument !== current.data.numeroIdentidad) {
        const duplicate = await db.collection("enrollments")
            .where("data.numeroIdentidad", "==", submittedDocument)
            .where("anioMatricula", "==", current.anioMatricula)
            .limit(2).get();
        if (duplicate.docs.some((item) => item.id !== id)) {
          throw new HttpsError(
              "already-exists",
              "Ya existe una matricula para este documento y ano escolar.",
          );
        }
      }
      changes.data = normalizedEnrollmentData({
        ...submittedData,
        numeroIdentidad: submittedDocument,
      }, submittedGroup);
      groupId = submittedGroup.id;
      groupName = submittedGroup.name;
    }
    if (action === "reject") {
      if (!observation) {
        throw new HttpsError(
            "invalid-argument", "El motivo de rechazo es obligatorio.",
        );
      }
      changes.rechazoMotivo = observation;
    }
    if (action === "approve") {
      await requireLinkedStudent(
          changes.vinculaUsuarioId || current.vinculaUsuarioId,
          current.institution,
          current.campus,
      );
      changes.fechaMatricula = FieldValue.serverTimestamp();
    }
    changes.revisadoPor = caller.uid;
  } else {
    throw new HttpsError(
        "permission-denied", "Tu rol no puede modificar matriculas.",
    );
  }

  changes.estado = nextStatus;
  const batch = db.batch();
  batch.update(ref, changes);
  batch.create(db.collection("enrollment_history").doc(), {
    enrollmentId: id,
    action,
    fromStatus: current.estado,
    toStatus: nextStatus,
    observation: observation || null,
    performedBy: caller.uid,
    performedByRole: caller.role,
    institution: current.institution,
    campus: current.campus,
    groupId,
    groupName,
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  await notifyEnrollment({...current, ...changes, id, estado: nextStatus},
      action === "resubmit" ? "resubmitted" : "updated");
  return {success: true, estado: nextStatus};
});

exports.crearAutorizacion = onCall(async (request) => {
  const caller = await getCaller(request);
  const permissions = Array.isArray(caller.permissions) ?
    caller.permissions : [];
  if (caller.role !== "Familiar" ||
      !permissions.includes("autorizaciones.ver")) {
    throw new HttpsError(
        "permission-denied", "Tu rol no puede crear autorizaciones.",
    );
  }
  const studentId = requiredString(
      request.data?.studentId, "estudiante", 128,
  );
  if (!Array.isArray(caller.studentIds) ||
      !caller.studentIds.includes(studentId)) {
    throw new HttpsError(
        "permission-denied", "El estudiante no esta vinculado a tu familia.",
    );
  }
  const student = await requireLinkedStudent(
      studentId, caller.institution, caller.campus,
  );
  const form = validatedAuthorizationData(request.data, student);
  const ref = db.collection("authorization_requests").doc();
  const authorization = {
    id: ref.id,
    institutionId: caller.institution,
    campusId: caller.campus,
    ...form,
    requesterId: caller.uid,
    requesterFullName:
      `${caller.firstName || ""} ${caller.lastName || ""}`.trim(),
    status: "pending",
    adminNote: null,
    evidence: null,
    requiresRequesterEdit: false,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };
  const batch = db.batch();
  batch.create(ref, authorization);
  batch.create(db.collection("authorization_history").doc(), {
    authorizationId: ref.id,
    action: "created",
    fromStatus: null,
    toStatus: "pending",
    performedBy: caller.uid,
    performedByRole: caller.role,
    institutionId: caller.institution,
    campusId: caller.campus,
    groupId: form.groupId,
    groupName: form.groupName,
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  await notifyAuthorization(authorization, "created");
  return {success: true, id: ref.id, status: "pending"};
});

exports.actualizarAutorizacion = onCall(async (request) => {
  const caller = await getCaller(request);
  const id = requiredString(request.data?.id, "autorizacion", 128);
  const action = requiredString(request.data?.action, "accion", 40);
  const ref = db.collection("authorization_requests").doc(id);
  const snapshot = await ref.get();
  if (!snapshot.exists) {
    throw new HttpsError("not-found", "La autorizacion no existe.");
  }
  const current = snapshot.data();
  if (!sameTenant(caller, {
    institution: current.institutionId,
    campus: current.campusId,
  })) {
    throw new HttpsError("permission-denied", "Autorizacion fuera de tu sede.");
  }
  const note = typeof request.data?.note === "string" ?
    request.data.note.trim().slice(0, 2000) : "";
  const evidence = typeof request.data?.evidence === "string" ?
    request.data.evidence.trim().slice(0, 4000) : "";
  const changes = {updatedAt: FieldValue.serverTimestamp()};
  let nextStatus = current.status;

  if (caller.role === "Familiar") {
    const permissions = Array.isArray(caller.permissions) ?
      caller.permissions : [];
    if (!permissions.includes("autorizaciones.ver") ||
        current.requesterId !== caller.uid || action !== "resubmit" ||
        current.status !== "pending" ||
        current.requiresRequesterEdit !== true) {
      throw new HttpsError(
          "permission-denied", "No puedes corregir esta autorizacion.",
      );
    }
    const studentId = requiredString(
        request.data?.studentId, "estudiante", 128,
    );
    if (!Array.isArray(caller.studentIds) ||
        !caller.studentIds.includes(studentId)) {
      throw new HttpsError(
          "permission-denied", "El estudiante no esta vinculado.",
      );
    }
    const student = await requireLinkedStudent(
        studentId, caller.institution, caller.campus,
    );
    Object.assign(changes, validatedAuthorizationData(request.data, student), {
      requiresRequesterEdit: false,
      adminNote: null,
    });
  } else if (caller.role === "Administrador") {
    requireAuthorizationAction(caller, "editar");
    const transitions = {
      request_correction: [["pending", "pending"]],
      approve: [["pending", "approved"]],
      reject: [["pending", "rejected"]],
      finish: [["approved", "finished"]],
    };
    if (action === "super_override") {
      if (caller.isSuperadmin !== true || current.status !== "finished") {
        throw new HttpsError(
            "permission-denied", "Solo el superadmin modifica una finalizada.",
        );
      }
      if (!note) {
        throw new HttpsError(
            "invalid-argument", "El motivo de reapertura es obligatorio.",
        );
      }
      const targetStatus = requiredString(
          request.data?.targetStatus, "estado destino", 30,
      );
      if (!["pending", "approved", "rejected"].includes(targetStatus)) {
        throw new HttpsError("invalid-argument", "Estado destino no valido.");
      }
      nextStatus = targetStatus;
      changes.superadminOverrideReason = note;
      changes.superadminOverrideBy = caller.uid;
      changes.superadminOverrideAt = FieldValue.serverTimestamp();
      changes.requiresRequesterEdit = false;
    } else {
      const transition = (transitions[action] || [])
          .find((item) => item[0] === current.status);
      if (!transition) {
        throw new HttpsError(
            "failed-precondition", "Transicion no permitida.",
        );
      }
      nextStatus = transition[1];
      if (["request_correction", "reject"].includes(action) && !note) {
        throw new HttpsError(
            "invalid-argument", "La observacion es obligatoria.",
        );
      }
      if (action === "finish" && !evidence) {
        throw new HttpsError(
            "invalid-argument", "La observacion de cierre es obligatoria.",
        );
      }
      changes.adminNote = note || null;
      changes.evidence = action === "finish" ? evidence : null;
      changes.requiresRequesterEdit = action === "request_correction";
    }
    changes.reviewedBy = caller.uid;
    changes.reviewedAt = FieldValue.serverTimestamp();
  } else {
    throw new HttpsError(
        "permission-denied", "Tu rol no puede modificar autorizaciones.",
    );
  }

  changes.status = nextStatus;
  const batch = db.batch();
  batch.update(ref, changes);
  batch.create(db.collection("authorization_history").doc(), {
    authorizationId: id,
    action,
    fromStatus: current.status,
    toStatus: nextStatus,
    note: note || null,
    evidence: evidence || null,
    performedBy: caller.uid,
    performedByRole: caller.role,
    institutionId: current.institutionId,
    campusId: current.campusId,
    groupId: changes.groupId || current.groupId,
    groupName: changes.groupName || current.groupName,
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  await notifyAuthorization({...current, ...changes, id},
      action === "resubmit" ? "resubmitted" : "updated");
  return {success: true, status: nextStatus};
});

exports.crearHorario = onCall(async (request) => {
  const caller = await getCaller(request);
  requireScheduleAction(caller, "crear");
  const institution = requiredString(
      request.data?.institutionId, "institucion", 120,
  );
  const campus = requiredString(request.data?.campusId, "sede", 120);
  if (!sameTenant(caller, {institution, campus})) {
    throw new HttpsError("permission-denied", "No puedes crear en otra sede.");
  }
  await validateInstitutionCampus({institution, campus});
  const schedule = await validatedScheduleData(
      request.data, institution, campus,
  );
  const ref = db.collection("subjects").doc();
  await db.runTransaction(async (transaction) => {
    await ensureNoScheduleConflict(transaction, schedule, null);
    transaction.create(ref, {
      ...schedule,
      createdBy: caller.uid,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.create(db.collection("schedule_history").doc(), {
      subjectId: ref.id,
      action: "create_subject",
      before: null,
      after: schedule,
      performedBy: caller.uid,
      institutionId: institution,
      campusId: campus,
      groupId: schedule.groupId,
      groupName: schedule.groupName,
      createdAt: FieldValue.serverTimestamp(),
    });
  });
  await notifySchedule({...schedule, id: ref.id}, "created");
  return {success: true, id: ref.id};
});

exports.editarHorario = onCall(async (request) => {
  const caller = await getCaller(request);
  requireScheduleAction(caller, "editar");
  const id = requiredString(request.data?.id, "horario", 128);
  const ref = db.collection("subjects").doc(id);
  const snapshot = await ref.get();
  if (!snapshot.exists || !sameTenant(caller, snapshot.data())) {
    throw new HttpsError("permission-denied", "Horario fuera de tu sede.");
  }
  const current = snapshot.data();
  const schedule = await validatedScheduleData(
      request.data, current.institutionId, current.campusId,
  );
  await db.runTransaction(async (transaction) => {
    const fresh = await transaction.get(ref);
    if (!fresh.exists) {
      throw new HttpsError("not-found", "El horario no existe.");
    }
    await ensureNoScheduleConflict(transaction, schedule, id);
    transaction.update(ref, {
      ...schedule,
      updatedBy: caller.uid,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.create(db.collection("schedule_history").doc(), {
      subjectId: id,
      action: "edit_subject",
      before: fresh.data(),
      after: schedule,
      performedBy: caller.uid,
      institutionId: current.institutionId,
      campusId: current.campusId,
      groupId: schedule.groupId,
      groupName: schedule.groupName,
      createdAt: FieldValue.serverTimestamp(),
    });
  });
  await notifySchedule({...schedule, id}, "updated");
  return {success: true};
});

exports.eliminarHorario = onCall(async (request) => {
  const caller = await getCaller(request);
  requireScheduleAction(caller, "eliminar");
  const id = requiredString(request.data?.id, "horario", 128);
  const ref = db.collection("subjects").doc(id);
  let deletedSchedule;
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists || !sameTenant(caller, snapshot.data())) {
      throw new HttpsError("permission-denied", "Horario fuera de tu sede.");
    }
    const current = snapshot.data();
    deletedSchedule = current;
    transaction.delete(ref);
    transaction.create(db.collection("schedule_history").doc(), {
      subjectId: id,
      action: "delete_subject",
      before: current,
      after: null,
      performedBy: caller.uid,
      institutionId: current.institutionId,
      campusId: current.campusId,
      groupId: current.groupId,
      groupName: current.groupName,
      createdAt: FieldValue.serverTimestamp(),
    });
  });
  await notifySchedule({...deletedSchedule, id}, "deleted");
  return {success: true};
});

/** @param {Object} caller Usuario. */
function requireAcademicGroupAdmin(caller) {
  if (caller.isSuperadmin === true) return;
  const permissions = Array.isArray(caller.permissions) ?
    caller.permissions : [];
  if (caller.role === "Administrador" &&
      permissions.includes("usuarios.editar")) return;
  throw new HttpsError(
      "permission-denied", "No tienes permiso para administrar grupos.",
  );
}

exports.crearGrupoAcademico = onCall(async (request) => {
  const caller = await getCaller(request);
  requireAcademicGroupAdmin(caller);
  const institution = requiredString(
      request.data?.institutionId, "institucion", 120,
  );
  const campus = requiredString(request.data?.campusId, "sede", 120);
  if (!sameTenant(caller, {institution, campus})) {
    throw new HttpsError("permission-denied", "Sede fuera de tu alcance.");
  }
  await validateInstitutionCampus({institution, campus});
  const level = requiredString(request.data?.level, "nivel", 80);
  const section = requiredString(request.data?.section, "grupo", 10)
      .toUpperCase();
  const name = `${level} ${section}`;
  const duplicate = await db.collection("academic_groups")
      .where("institutionId", "==", institution)
      .where("campusId", "==", campus)
      .where("name", "==", name).limit(1).get();
  if (!duplicate.empty) {
    throw new HttpsError("already-exists", "El grupo ya existe en esta sede.");
  }
  const order = Number(request.data?.order);
  const ref = db.collection("academic_groups").doc();
  const group = {
    institutionId: institution,
    campusId: campus,
    level,
    section,
    name,
    order: Number.isInteger(order) ? order : 0,
    active: true,
    createdBy: caller.uid,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };
  const batch = db.batch();
  batch.create(ref, group);
  batch.create(db.collection("academic_group_history").doc(), {
    groupId: ref.id,
    action: "created",
    after: group,
    performedBy: caller.uid,
    institutionId: institution,
    campusId: campus,
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  return {success: true, id: ref.id, name};
});

exports.actualizarGrupoAcademico = onCall(async (request) => {
  const caller = await getCaller(request);
  requireAcademicGroupAdmin(caller);
  const id = requiredString(request.data?.id, "grupo", 160);
  const ref = db.collection("academic_groups").doc(id);
  const snapshot = await ref.get();
  const current = snapshot.data() || {};
  if (!snapshot.exists || !sameTenant(caller, current)) {
    throw new HttpsError("permission-denied", "Grupo fuera de tu alcance.");
  }
  const active = request.data?.active;
  if (typeof active !== "boolean") {
    throw new HttpsError("invalid-argument", "Estado de grupo no valido.");
  }
  const order = Number(request.data?.order);
  const level = requiredString(request.data?.level, "nivel", 80);
  const section = requiredString(request.data?.section, "grupo", 10)
      .toUpperCase();
  const name = `${level} ${section}`;
  const duplicate = await db.collection("academic_groups")
      .where("institutionId", "==", current.institutionId)
      .where("campusId", "==", current.campusId)
      .where("name", "==", name).get();
  if (duplicate.docs.some((item) => item.id !== id)) {
    throw new HttpsError("already-exists", "El grupo ya existe en esta sede.");
  }
  const changes = {
    active,
    level,
    section,
    name,
    order: Number.isInteger(order) ? order : Number(current.order || 0),
    updatedBy: caller.uid,
    updatedAt: FieldValue.serverTimestamp(),
  };
  const batch = db.batch();
  batch.update(ref, changes);
  batch.create(db.collection("academic_group_history").doc(), {
    groupId: id,
    action: "updated",
    before: current,
    after: {...current, ...changes},
    performedBy: caller.uid,
    institutionId: current.institutionId,
    campusId: current.campusId,
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  return {success: true};
});

exports.eliminarGrupoAcademico = onCall(async (request) => {
  const caller = await getCaller(request);
  requireAcademicGroupAdmin(caller);
  const id = requiredString(request.data?.id, "grupo", 160);
  const ref = db.collection("academic_groups").doc(id);
  const snapshot = await ref.get();
  const current = snapshot.data() || {};
  if (!snapshot.exists || !sameTenant(caller, current)) {
    throw new HttpsError("permission-denied", "Grupo fuera de tu alcance.");
  }
  const collections = [
    ["users", "groupId"],
    ["subjects", "groupId"],
    ["authorization_requests", "groupId"],
    ["files", "groupId"],
    ["message_threads", "contextStudentGroupId"],
  ];
  for (const [collection, field] of collections) {
    const linked = await db.collection(collection)
        .where(field, "==", id).limit(1).get();
    if (!linked.empty) {
      throw new HttpsError(
          "failed-precondition",
          "El grupo tiene informacion institucional y no puede eliminarse.",
      );
    }
  }
  const enrollments = await db.collection("enrollments")
      .where("data.groupId", "==", id).limit(1).get();
  if (!enrollments.empty) {
    throw new HttpsError(
        "failed-precondition", "El grupo tiene matriculas vinculadas.",
    );
  }
  const batch = db.batch();
  batch.delete(ref);
  batch.create(db.collection("academic_group_history").doc(), {
    groupId: id,
    action: "deleted",
    before: current,
    performedBy: caller.uid,
    institutionId: current.institutionId,
    campusId: current.campusId,
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  return {success: true};
});

exports.solicitarCargaArchivo = onCall(async (request) => {
  const caller = await getCaller(request);
  requireFileAction(caller, "crear");
  const institution = requiredString(
      request.data?.institutionId, "institucion", 120,
  );
  const campus = requiredString(request.data?.campusId, "sede", 120);
  if (!sameTenant(caller, {institution, campus})) {
    throw new HttpsError("permission-denied", "No puedes cargar en otra sede.");
  }
  const group = await requireAcademicGroup({
    groupId: request.data?.groupId,
    institution,
    campus,
  });
  requireFileGroupAccess(caller, group);
  const name = safeFileName(request.data?.name);
  const contentType = validatedFileMime(request.data?.contentType);
  const expectedSize = validatedFileSize(request.data?.sizeBytes);
  const ref = db.collection("files").doc();
  const usageRef = db.collection("file_storage_usage")
      .doc(fileUsageId(institution));
  const storagePath = `files/${group.id}/${ref.id}/${name}`;
  await db.runTransaction(async (transaction) => {
    const usageSnapshot = await transaction.get(usageRef);
    const usage = usageSnapshot.data() || {};
    const usedBytes = Number(usage.usedBytes || 0);
    const reservedBytes = Number(usage.reservedBytes || 0);
    if (usedBytes + reservedBytes + expectedSize > FILE_MODULE_LIMIT_BYTES) {
      throw new HttpsError(
          "resource-exhausted",
          "La cuota de 300 MiB de Archivos no tiene espacio suficiente.",
      );
    }
    transaction.set(usageRef, {
      institutionId: institution,
      usedBytes,
      reservedBytes: reservedBytes + expectedSize,
      limitBytes: FILE_MODULE_LIMIT_BYTES,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    transaction.create(ref, {
      id: ref.id,
      name,
      contentType,
      expectedSize,
      sizeBytes: 0,
      groupId: group.id,
      groupName: group.name,
      uploadedBy: caller.uid,
      uploaderName:
        `${caller.firstName || ""} ${caller.lastName || ""}`.trim(),
      institutionId: institution,
      campusId: campus,
      storagePath,
      status: "uploading",
      createdAt: FieldValue.serverTimestamp(),
      expiresAt: Timestamp.fromMillis(Date.now() + 60 * 60 * 1000),
    });
  });
  return {
    id: ref.id,
    storagePath,
    maxFileBytes: FILE_UPLOAD_LIMIT_BYTES,
    moduleLimitBytes: FILE_MODULE_LIMIT_BYTES,
  };
});

exports.confirmarCargaArchivo = onCall(async (request) => {
  const caller = await getCaller(request);
  requireFileAction(caller, "crear");
  const id = requiredString(request.data?.id, "archivo", 128);
  const ref = db.collection("files").doc(id);
  const snapshot = await ref.get();
  const file = snapshot.data() || {};
  if (!snapshot.exists || file.status !== "uploading" ||
      file.uploadedBy !== caller.uid || !sameTenant(caller, file)) {
    throw new HttpsError("permission-denied", "Reserva de archivo no valida.");
  }
  const [metadata] = await storage.bucket().file(file.storagePath)
      .getMetadata();
  const actualSize = Number(metadata.size || 0);
  if (!Number.isInteger(actualSize) || actualSize <= 0 ||
      actualSize > file.expectedSize || actualSize > FILE_UPLOAD_LIMIT_BYTES ||
      metadata.contentType !== file.contentType) {
    await storage.bucket().file(file.storagePath)
        .delete({ignoreNotFound: true});
    const usageRef = db.collection("file_storage_usage")
        .doc(fileUsageId(file.institutionId));
    await db.runTransaction(async (transaction) => {
      const [fresh, usageSnapshot] = await Promise.all([
        transaction.get(ref), transaction.get(usageRef),
      ]);
      if (!fresh.exists || fresh.data().status !== "uploading") return;
      const usage = usageSnapshot.data() || {};
      transaction.set(usageRef, {
        reservedBytes: Math.max(
            0, Number(usage.reservedBytes || 0) - file.expectedSize,
        ),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      transaction.delete(ref);
    });
    throw new HttpsError(
        "failed-precondition", "El archivo cargado no coincide con la reserva.",
    );
  }
  const usageRef = db.collection("file_storage_usage")
      .doc(fileUsageId(file.institutionId));
  await db.runTransaction(async (transaction) => {
    const [fresh, usageSnapshot] = await Promise.all([
      transaction.get(ref), transaction.get(usageRef),
    ]);
    if (!fresh.exists || fresh.data().status !== "uploading") {
      throw new HttpsError("failed-precondition", "La carga ya fue procesada.");
    }
    const usage = usageSnapshot.data() || {};
    transaction.update(ref, {
      status: "active",
      sizeBytes: actualSize,
      expectedSize: FieldValue.delete(),
      expiresAt: FieldValue.delete(),
      confirmedAt: FieldValue.serverTimestamp(),
    });
    transaction.set(usageRef, {
      usedBytes: Number(usage.usedBytes || 0) + actualSize,
      reservedBytes: Math.max(
          0, Number(usage.reservedBytes || 0) - file.expectedSize,
      ),
      limitBytes: FILE_MODULE_LIMIT_BYTES,
      institutionId: file.institutionId,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    transaction.create(db.collection("file_history").doc(), {
      fileId: id,
      action: "uploaded",
      performedBy: caller.uid,
      institutionId: file.institutionId,
      campusId: file.campusId,
      groupId: file.groupId,
      groupName: file.groupName,
      sizeBytes: actualSize,
      createdAt: FieldValue.serverTimestamp(),
    });
  });
  try {
    const tokens = await resolveAudienceTokens(caller, {
      roles: ["Estudiante"],
      groupId: file.groupId,
      includeFamiliesForGroup: true,
    });
    if (tokens.length) {
      await messaging.sendEachForMulticast({
        notification: {title: "Nuevo archivo disponible", body: file.name},
        tokens,
      });
    }
  } catch (error) {
    console.error("Notificacion de archivo omitida:", error.code || error);
  }
  return {success: true, sizeBytes: actualSize};
});

exports.cancelarCargaArchivo = onCall(async (request) => {
  const caller = await getCaller(request);
  const id = requiredString(request.data?.id, "archivo", 128);
  const ref = db.collection("files").doc(id);
  const snapshot = await ref.get();
  const file = snapshot.data() || {};
  if (!snapshot.exists || file.status !== "uploading" ||
      (file.uploadedBy !== caller.uid && caller.isSuperadmin !== true)) {
    throw new HttpsError("permission-denied", "Reserva no disponible.");
  }
  await storage.bucket().file(file.storagePath).delete({ignoreNotFound: true});
  const usageRef = db.collection("file_storage_usage")
      .doc(fileUsageId(file.institutionId));
  await db.runTransaction(async (transaction) => {
    const usageSnapshot = await transaction.get(usageRef);
    const usage = usageSnapshot.data() || {};
    transaction.set(usageRef, {
      reservedBytes: Math.max(
          0, Number(usage.reservedBytes || 0) - file.expectedSize,
      ),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    transaction.delete(ref);
  });
  return {success: true};
});

/**
 * Elimina objetos primero y metadatos despues, dejando estado reintentable.
 * @param {Object} caller Usuario.
 * @param {string[]} ids Archivos.
 * @param {string} source Origen de la limpieza.
 * @return {Promise<number>} Cantidad eliminada.
 */
async function deleteFileRecords(caller, ids, source) {
  const uniqueIds = [...new Set(ids)].slice(0, 100);
  const files = [];
  for (const id of uniqueIds) {
    const snapshot = await db.collection("files").doc(id).get();
    if (!snapshot.exists) continue;
    const file = snapshot.data();
    if (!sameTenant(caller, file) ||
        (caller.isSuperadmin !== true && caller.role === "Docente" &&
         file.uploadedBy !== caller.uid)) {
      throw new HttpsError("permission-denied", "Archivo fuera de tu alcance.");
    }
    files.push({id, ref: snapshot.ref, ...file});
  }
  for (const file of files) {
    await file.ref.update({
      status: "deleting",
      deletionRequestedBy: caller.uid,
      deletionRequestedAt: FieldValue.serverTimestamp(),
    });
  }
  try {
    for (const file of files) {
      await storage.bucket().file(file.storagePath)
          .delete({ignoreNotFound: true});
    }
  } catch (error) {
    for (const file of files) {
      await file.ref.update({status: file.status || "active"});
    }
    throw error;
  }
  for (const file of files) {
    const usageRef = db.collection("file_storage_usage")
        .doc(fileUsageId(file.institutionId));
    await db.runTransaction(async (transaction) => {
      const usageSnapshot = await transaction.get(usageRef);
      const usage = usageSnapshot.data() || {};
      const usedDelta = file.status === "active" ?
        Number(file.sizeBytes || 0) : 0;
      const reservedDelta = file.status === "uploading" ?
        Number(file.expectedSize || 0) : 0;
      transaction.set(usageRef, {
        usedBytes: Math.max(0, Number(usage.usedBytes || 0) - usedDelta),
        reservedBytes: Math.max(
            0, Number(usage.reservedBytes || 0) - reservedDelta,
        ),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      transaction.create(db.collection("file_history").doc(), {
        fileId: file.id,
        action: "deleted",
        source,
        performedBy: caller.uid,
        institutionId: file.institutionId,
        campusId: file.campusId,
        groupId: file.groupId,
        groupName: file.groupName,
        sizeBytes: Number(file.sizeBytes || 0),
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.delete(file.ref);
    });
  }
  return files.length;
}

exports.eliminarArchivos = onCall(async (request) => {
  const caller = await getCaller(request);
  requireFileAction(caller, "eliminar");
  const ids = Array.isArray(request.data?.ids) ? request.data.ids
      .filter((id) => typeof id === "string" && id.trim()) : [];
  if (!ids.length || ids.length > 100) {
    throw new HttpsError(
        "invalid-argument", "Seleccion de archivos no valida.",
    );
  }
  const deleted = await deleteFileRecords(caller, ids, "manual");
  return {success: true, deleted};
});

exports.limpiarArchivosAntiguos = onCall(async (request) => {
  const caller = await getCaller(request);
  if (caller.isSuperadmin !== true) {
    throw new HttpsError(
        "permission-denied", "Solo el superadmin ejecuta la limpieza global.",
    );
  }
  const threshold = Timestamp.fromMillis(
      Date.now() - FILE_RETENTION_DAYS * 24 * 60 * 60 * 1000,
  );
  const snapshot = await db.collection("files")
      .where("status", "==", "active")
      .where("createdAt", "<=", threshold)
      .limit(100).get();
  const deleted = await deleteFileRecords(
      caller, snapshot.docs.map((item) => item.id), "older_than_60_days",
  );
  return {success: true, deleted, retentionDays: FILE_RETENTION_DAYS};
});

exports.obtenerResumenArchivos = onCall(async (request) => {
  const caller = await getCaller(request);
  if (caller.isSuperadmin !== true &&
      caller.role !== "Administrador" && caller.role !== "Docente") {
    throw new HttpsError(
        "permission-denied", "Solo el personal autorizado consulta la cuota.",
    );
  }
  if (caller.isSuperadmin !== true &&
      !(Array.isArray(caller.permissions) && caller.permissions.some(
          (permission) => [
            "archivos.ver", "archivos.crear", "archivos.eliminar",
          ].includes(permission),
      ))) {
    throw new HttpsError(
        "permission-denied", "No tienes acceso a la cuota de Archivos.",
    );
  }
  const institution = caller.isSuperadmin === true &&
      typeof request.data?.institutionId === "string" ?
    request.data.institutionId.trim() : caller.institution;
  if (!institution) {
    throw new HttpsError("invalid-argument", "Institucion no valida.");
  }
  const usage = await db.collection("file_storage_usage")
      .doc(fileUsageId(institution)).get();
  const data = usage.data() || {};
  const oldThreshold = Timestamp.fromMillis(
      Date.now() - FILE_RETENTION_DAYS * 24 * 60 * 60 * 1000,
  );
  let oldQuery = db.collection("files").where("status", "==", "active");
  if (caller.isSuperadmin !== true) {
    oldQuery = oldQuery.where("institutionId", "==", institution);
  }
  const oldFiles = await oldQuery.where("createdAt", "<=", oldThreshold).get();
  return {
    institutionId: institution,
    usedBytes: Number(data.usedBytes || 0),
    reservedBytes: Number(data.reservedBytes || 0),
    limitBytes: FILE_MODULE_LIMIT_BYTES,
    oldFilesCount: oldFiles.size,
    retentionDays: FILE_RETENTION_DAYS,
    maxFileBytes: FILE_UPLOAD_LIMIT_BYTES,
  };
});

exports.obtenerImpactoEliminacionUsuario = onCall(async (request) => {
  const caller = await getCaller(request);
  requireAdmin(caller);
  const uid = requiredString(request.data?.uid, "uid", 128);
  const targetSnap = await db.collection("users").doc(uid).get();
  if (!targetSnap.exists || !sameTenant(caller, targetSnap.data())) {
    throw new HttpsError(
        "permission-denied", "No puedes consultar este usuario.",
    );
  }
  const context = await userDeletionContext(targetSnap);
  return {
    uid,
    status: context.target.status || "",
    fullName: `${context.target.firstName || ""} ` +
      `${context.target.lastName || ""}`.trim(),
    impact: context.impact,
    linkedRecords: context.impact
        .filter((item) => item.action !== "preserve")
        .reduce((total, item) => total + item.count, 0),
  };
});

exports.actualizarEstadoUsuario = onCall(async (request) => {
  const caller = await getCaller(request);
  requireAdmin(caller);
  const uid = requiredString(request.data?.uid, "uid", 128);
  const status = requiredString(request.data?.status, "estado", 20);
  if (!["activo", "inactivo"].includes(status)) {
    throw new HttpsError("invalid-argument", "El estado no es valido.");
  }
  if (uid === caller.uid && status !== "activo") {
    throw new HttpsError(
        "failed-precondition", "No puedes desactivar tu propia cuenta.",
    );
  }
  const permissions = Array.isArray(caller.permissions) ?
    caller.permissions : [];
  if (caller.isSuperadmin !== true &&
      (caller.role !== "Administrador" ||
       !permissions.includes("usuarios.editar"))) {
    throw new HttpsError(
        "permission-denied", "No tienes permiso para cambiar el estado.",
    );
  }
  const targetRef = db.collection("users").doc(uid);
  const targetSnap = await targetRef.get();
  if (!targetSnap.exists || !sameTenant(caller, targetSnap.data())) {
    throw new HttpsError(
        "permission-denied", "No puedes modificar este usuario.",
    );
  }
  const target = targetSnap.data();
  if (target.status === "eliminado" || target.status === "eliminando") {
    throw new HttpsError(
        "failed-precondition",
        "Un usuario retirado no se reactiva desde la edicion normal.",
    );
  }
  if (caller.isSuperadmin !== true &&
      (target.isSuperadmin === true || target.role === "Administrador")) {
    throw new HttpsError(
        "permission-denied",
        "Solo el superadministrador modifica administradores.",
    );
  }

  let authUser = null;
  try {
    authUser = await auth.getUser(uid);
    await auth.updateUser(uid, {disabled: status !== "activo"});
  } catch (error) {
    if (error.code !== "auth/user-not-found") throw error;
  }

  const batch = db.batch();
  const userChanges = {
    status,
    administrativeRemoval: false,
    updatedAt: FieldValue.serverTimestamp(),
  };
  if (status === "inactivo") {
    userChanges.notificationTokens = FieldValue.delete();
    userChanges.fcmToken = FieldValue.delete();
    userChanges.fcmTokens = FieldValue.delete();
  }
  batch.update(targetRef, userChanges);
  batch.set(db.collection("user_directory").doc(uid), {
    status,
    administrativeRemoval: false,
  }, {merge: true});
  batch.create(db.collection("user_history").doc(), {
    usuarioId: uid,
    nombres: target.firstName || "",
    apellidos: target.lastName || "",
    rol: target.role || "",
    accion: status === "activo" ? "reactivado" : "desactivado",
    realizadoPor:
      `${caller.firstName || ""} ${caller.lastName || ""}`.trim(),
    performedBy: caller.uid,
    institution: target.institution,
    campus: target.campus,
    fecha: FieldValue.serverTimestamp(),
  });
  try {
    await batch.commit();
  } catch {
    if (authUser) {
      try {
        await auth.updateUser(uid, {disabled: authUser.disabled});
      } catch (rollbackError) {
        console.error("No se pudo revertir Auth:", rollbackError.code);
      }
    }
    throw new HttpsError(
        "internal", "No se cambio el estado; la operacion se revirtio.",
    );
  }
  return {success: true, status};
});

exports.eliminarUsuarioAuth = onCall(async (request) => {
  const caller = await getCaller(request);
  requireAdmin(caller);
  const uid = requiredString(request.data?.uid, "uid", 128);
  const mode = requiredString(request.data?.mode || "soft", "mode", 20);
  if (!["inactive", "soft", "permanent"].includes(mode)) {
    throw new HttpsError("invalid-argument", "El tipo de baja no es valido.");
  }
  if (uid === caller.uid) {
    throw new HttpsError(
        "failed-precondition", "No puedes eliminar tu propia cuenta.",
    );
  }

  const targetSnap = await db.collection("users").doc(uid).get();
  if (!targetSnap.exists || !sameTenant(caller, targetSnap.data())) {
    throw new HttpsError(
        "permission-denied",
        "No puedes eliminar este usuario.",
    );
  }

  const target = targetSnap.data();
  const targetRef = targetSnap.ref;
  const permissions = Array.isArray(caller.permissions) ?
    caller.permissions : [];
  if (caller.isSuperadmin !== true &&
      (caller.role !== "Administrador" ||
       !permissions.includes("usuarios.eliminar"))) {
    throw new HttpsError(
        "permission-denied", "No tienes permiso para retirar usuarios.",
    );
  }
  if (caller.isSuperadmin !== true &&
      (target.isSuperadmin === true || target.role === "Administrador")) {
    throw new HttpsError(
        "permission-denied",
        "Solo el superadministrador puede retirar administradores.",
    );
  }

  const context = await userDeletionContext(targetSnap);
  const impactSummary = Object.fromEntries(
      context.impact.map((item) => [item.key, item.count]),
  );

  if (mode !== "permanent") {
    let authUser = null;
    try {
      authUser = await auth.getUser(uid);
      if (!authUser.disabled) await auth.updateUser(uid, {disabled: true});
    } catch (error) {
      if (error.code !== "auth/user-not-found") throw error;
    }
    const status = mode === "inactive" ? "inactivo" : "eliminado";
    const action = mode === "inactive" ? "desactivado" : "retirado";
    const batch = db.batch();
    batch.update(targetRef, {
      status,
      administrativeRemoval: mode === "soft",
      administrativeRemovalAt: FieldValue.serverTimestamp(),
      administrativeRemovalBy: caller.uid,
      previousStatus: target.status || "activo",
      notificationTokens: FieldValue.delete(),
      fcmToken: FieldValue.delete(),
      fcmTokens: FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    batch.set(db.collection("user_directory").doc(uid), {
      status,
      administrativeRemoval: mode === "soft",
    }, {merge: true});
    batch.create(db.collection("user_history").doc(), {
      usuarioId: uid,
      nombres: target.firstName || "",
      apellidos: target.lastName || "",
      rol: target.role || "",
      accion: action,
      impacto: impactSummary,
      realizadoPor:
        `${caller.firstName || ""} ${caller.lastName || ""}`.trim(),
      performedBy: caller.uid,
      institution: target.institution,
      campus: target.campus,
      fecha: FieldValue.serverTimestamp(),
    });
    try {
      await batch.commit();
    } catch {
      if (authUser && !authUser.disabled) {
        try {
          await auth.updateUser(uid, {disabled: false});
        } catch (rollbackError) {
          console.error("No se pudo revertir Auth:", rollbackError.code);
        }
      }
      throw new HttpsError(
          "internal", "No se completo la baja; los cambios se revirtieron.",
      );
    }
    return {success: true, deletionType: mode, impact: context.impact};
  }

  if (caller.isSuperadmin !== true) {
    throw new HttpsError(
        "permission-denied",
        "Solo el superadministrador puede eliminar definitivamente.",
    );
  }
  if (request.data?.confirmation !== `ELIMINAR ${uid}`) {
    throw new HttpsError(
        "failed-precondition", "Falta la confirmacion de eliminacion.",
    );
  }

  try {
    await targetRef.update({
      status: "eliminando",
      deletionState: "pending",
      deletionRequestedAt: FieldValue.serverTimestamp(),
      deletionRequestedBy: caller.uid,
      deletionManifest: {storagePaths: context.storagePaths},
      deletionImpact: impactSummary,
    });

    for (let i = 0; i < context.families.length; i += 400) {
      const batch = db.batch();
      context.families.slice(i, i + 400).forEach((family) => {
        const changes = {
          studentIds: FieldValue.arrayRemove(uid),
        };
        if (family.data().activeStudentId === uid) {
          changes.activeStudentId = null;
        }
        batch.update(family.ref, changes);
      });
      await batch.commit();
    }

    for (const route of context.routes) {
      const data = route.data();
      const changes = {estudiantes: FieldValue.arrayRemove(uid)};
      if (data.gestionador === uid) changes.gestionador = null;
      changes.userDeleted = true;
      await route.ref.update(changes);
    }
    for (const subject of context.subjects) {
      await subject.ref.update({teacherId: "", teacherDeleted: true});
    }
    for (const route of context.dailyManagerDocs) {
      const changes = {managerDeleted: true};
      if (route.data().gestionador === uid) changes.gestionador = null;
      await route.ref.update(changes);
    }
    await deleteDocuments(context.dailyStudentRefs);
    await deleteDocuments(context.enrollments);
    await deleteDocuments(context.authorizations);

    for (const thread of context.threads) {
      await deleteQuery(thread.ref.collection("messages"));
      await thread.ref.delete();
    }

    await deleteDocuments(context.files);
    const manifest = target.deletionManifest?.storagePaths ||
      context.storagePaths;
    for (const path of manifest) {
      try {
        await storage.bucket().file(path).delete({ignoreNotFound: true});
      } catch (error) {
        console.error("Error eliminando archivo:", path, error.code);
        throw error;
      }
    }
    await storage.bucket().deleteFiles({
      prefix: `fotos_perfil/${uid}/`,
    });
    try {
      await auth.updateUser(uid, {disabled: true});
      await auth.deleteUser(uid);
    } catch (error) {
      if (error.code !== "auth/user-not-found") throw error;
    }

    const finalBatch = db.batch();
    finalBatch.create(db.collection("user_history").doc(), {
      usuarioId: uid,
      nombres: target.firstName || "",
      apellidos: target.lastName || "",
      rol: target.role || "",
      accion: "eliminado",
      realizadoPor:
        `${caller.firstName || ""} ${caller.lastName || ""}`.trim(),
      performedBy: caller.uid,
      impacto: target.deletionImpact || impactSummary,
      institution: target.institution,
      campus: target.campus,
      fecha: FieldValue.serverTimestamp(),
    });
    finalBatch.delete(db.collection("user_directory").doc(uid));
    finalBatch.delete(db.collection("notification_rate_limits").doc(uid));
    finalBatch.delete(targetRef);
    await finalBatch.commit();
    return {success: true, deletionType: "permanent",
      impact: context.impact};
  } catch (error) {
    console.error("Error eliminando usuario:", error.code || error.message);
    await targetRef.set({
      status: "eliminando",
      deletionState: "error",
      deletionErrorAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    throw new HttpsError(
        "internal",
        "La eliminacion quedo pendiente. Puedes reintentar sin reactivar " +
          "la cuenta.",
    );
  }
});

exports.sincronizarDirectorioUsuarios = onDocumentWritten(
    "users/{userId}",
    async (event) => {
      const target = db.collection("user_directory").doc(event.params.userId);
      if (!event.data?.after.exists) {
        await target.delete();
        return;
      }
      await target.set(directoryData(event.data.after.data()), {merge: false});
    },
);

exports.registrarAuditoria = onCall(async (request) => {
  const caller = await getCaller(request);
  const data = request.data || {};
  const type = requiredString(data.type, "type", 40);
  const payload = data.payload && typeof data.payload === "object" ?
    data.payload : {};
  const callerName =
    `${caller.firstName || ""} ${caller.lastName || ""}`.trim();
  const now = FieldValue.serverTimestamp();

  if (type === "user_log") {
    const event = requiredString(payload.event, "event", 60);
    const allowed = new Set(["login", "logout", "file_download"]);
    if (!allowed.has(event)) {
      throw new HttpsError("invalid-argument", "Evento no permitido.");
    }
    await db.collection("user_logs").add({
      userId: caller.uid,
      fullName: callerName,
      role: caller.role,
      institution: caller.institution,
      campus: caller.campus,
      groupId: caller.groupId || "",
      groupName: caller.groupName || "",
      event,
      env: payload.env && typeof payload.env === "object" ? payload.env : {},
      extra: payload.extra && typeof payload.extra === "object" ?
        payload.extra : {},
      timestamp: now,
    });
    return {success: true};
  }

  requireAdmin(caller);
  if (type === "user_history") {
    const targetUid = requiredString(payload.userId, "userId", 128);
    const target = await db.collection("users").doc(targetUid).get();
    if (!target.exists || !sameTenant(caller, target.data())) {
      throw new HttpsError("permission-denied", "Usuario fuera de tu sede.");
    }
    const action = requiredString(payload.action, "action", 30);
    if (!new Set(["editado", "eliminado"]).has(action)) {
      throw new HttpsError("invalid-argument", "Accion no permitida.");
    }
    const user = target.data();
    await db.collection("user_history").add({
      usuarioId: targetUid,
      nombres: user.firstName || "",
      apellidos: user.lastName || "",
      rol: user.role || "",
      accion: action,
      realizadoPor: callerName,
      performedBy: caller.uid,
      institution: user.institution,
      campus: user.campus,
      fecha: now,
    });
    return {success: true};
  }

  if (type === "route_history") {
    await db.collection("routes_admin_history").add({
      routeId: requiredString(payload.routeId, "routeId", 128),
      routeName: requiredString(payload.routeName, "routeName", 200),
      action: requiredString(payload.action, "action", 30),
      performedBy: caller.uid,
      adminName: callerName,
      institution: caller.institution,
      campus: caller.campus,
      date: now,
      changes: payload.changes && typeof payload.changes === "object" ?
        payload.changes : {},
    });
    return {success: true};
  }

  if (type === "schedule_history") {
    await db.collection("schedule_history").add({
      action: requiredString(payload.action, "action", 50),
      timestamp: now,
      userId: caller.uid,
      userName: callerName,
      institutionId: caller.institution,
      campusId: caller.campus,
      subjectData: payload.subjectData &&
        typeof payload.subjectData === "object" ? payload.subjectData : {},
      message: typeof payload.message === "string" ?
        payload.message.slice(0, 500) : "",
    });
    return {success: true};
  }

  throw new HttpsError("invalid-argument", "Tipo de auditoria no permitido.");
});

exports.obtenerHijosVinculados = onCall(async (request) => {
  const caller = await getCaller(request);
  if (caller.role !== "Familiar") {
    throw new HttpsError("permission-denied", "La cuenta no es familiar.");
  }
  const ids = Array.isArray(caller.studentIds) ? caller.studentIds : [];
  if (ids.length === 0) return {children: []};
  const children = [];
  for (let i = 0; i < ids.length; i += 30) {
    const snapshot = await db.collection("users")
        .where(
            FieldPath.documentId(),
            "in",
            ids.slice(i, i + 30),
        )
        .get();
    snapshot.docs.forEach((item) => {
      const child = item.data();
      if (sameTenant(caller, child) && child.role === "Estudiante") {
        children.push({
          id: item.id,
          firstName: child.firstName || "",
          lastName: child.lastName || "",
          document: child.document || "",
          documentType: child.documentType || "",
          groupId: child.groupId || "",
          groupName: child.groupName || "",
          birthDate: child.birthDate || null,
          institution: child.institution,
          campus: child.campus,
        });
      }
    });
  }
  return {children};
});

exports.seleccionarHijoActivo = onCall(async (request) => {
  const caller = await getCaller(request);
  if (caller.role !== "Familiar") {
    throw new HttpsError("permission-denied", "La cuenta no es familiar.");
  }
  const studentId = requiredString(
      request.data?.studentId, "estudiante", 128,
  );
  if (!Array.isArray(caller.studentIds) ||
      !caller.studentIds.includes(studentId)) {
    throw new HttpsError(
        "permission-denied", "El estudiante no esta vinculado a tu familia.",
    );
  }
  await requireLinkedStudent(studentId, caller.institution, caller.campus);
  await db.collection("users").doc(caller.uid).update({
    activeStudentId: studentId,
    updatedAt: FieldValue.serverTimestamp(),
  });
  await db.collection("user_directory").doc(caller.uid).set({
    activeStudentId: studentId,
  }, {merge: true});
  return {success: true, studentId};
});

exports.submitWebsiteForm = onCall(async (request) => {
  const data = request.data || {};
  if (typeof data.website === "string" && data.website.trim() !== "") {
    return {success: true};
  }

  const pageId = requiredString(data.pageId, "pageId", 80);
  const blockId = requiredString(data.blockId, "blockId", 120);
  const name = requiredString(data.name, "nombre", 120);
  const email = requiredString(data.email, "correo", 254).toLowerCase();
  const message = requiredString(data.message, "mensaje", 3000);
  const phone = typeof data.phone === "string" ? data.phone.trim() : "";
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || phone.length > 40) {
    throw new HttpsError(
        "invalid-argument",
        "Los datos de contacto no son validos.",
    );
  }

  const pageSnapshot = await db.collection("website_pages").doc(pageId).get();
  const blocks = pageSnapshot.data()?.blocks;
  const validForm = pageSnapshot.exists && Array.isArray(blocks) &&
    blocks.some((block) => block?.id === blockId &&
      block?.type === "contactForm" && block?.enabled !== false);
  if (!validForm) {
    throw new HttpsError(
        "failed-precondition",
        "El formulario no esta disponible.",
    );
  }

  const remoteAddress = (request.rawRequest.ip || "unknown").toString();
  const rateId = crypto.createHash("sha256")
      .update(`website-form:${remoteAddress}`)
      .digest("hex");
  const rateRef = db.collection("website_form_rate_limits").doc(rateId);
  const now = Timestamp.now();
  await db.runTransaction(async (transaction) => {
    const rateSnapshot = await transaction.get(rateRef);
    const lastAt = rateSnapshot.data()?.lastAt;
    if (lastAt instanceof Timestamp &&
        now.toMillis() - lastAt.toMillis() < 60000) {
      throw new HttpsError(
          "resource-exhausted",
          "Espera un momento antes de enviar otro mensaje.",
      );
    }
    transaction.set(rateRef, {
      lastAt: now,
      expiresAt: Timestamp.fromMillis(
          now.toMillis() + 24 * 60 * 60 * 1000,
      ),
    });
  });

  await db.collection("website_submissions").add({
    pageId,
    blockId,
    name,
    email,
    phone,
    message,
    status: "new",
    createdAt: FieldValue.serverTimestamp(),
  });
  return {success: true};
});
