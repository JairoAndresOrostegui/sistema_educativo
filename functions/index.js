"use strict";

const {setGlobalOptions} = require("firebase-functions/v2");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();
setGlobalOptions({maxInstances: 10, region: "us-central1"});

const db = admin.firestore();
const ALLOWED_ROLES = new Set([
  "Administrador",
  "Docente",
  "Estudiante",
  "Familiar",
]);

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
 * Comprueba que dos perfiles pertenezcan a la misma sede.
 * @param {Object} caller Perfil que ejecuta la accion.
 * @param {Object} target Perfil objetivo.
 * @return {boolean} Verdadero si puede operar sobre el tenant.
 */
function sameTenant(caller, target) {
  return caller.isSuperadmin === true ||
    (caller.institution === target.institution &&
      caller.campus === target.campus);
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

exports.enviarNotificacion = onCall(async (request) => {
  const caller = await getCaller(request);
  const data = request.data || {};
  const titulo = requiredString(data.titulo, "titulo", 120);
  const cuerpo = requiredString(data.cuerpo, "cuerpo", 500);

  if (!Array.isArray(data.tokens) || data.tokens.length === 0 ||
      data.tokens.length > 1000) {
    throw new HttpsError(
        "invalid-argument",
        "La lista de tokens no es valida.",
    );
  }

  const requestedTokens = [...new Set(data.tokens
      .filter((token) => typeof token === "string")
      .map((token) => token.trim())
      .filter((token) => token.length >= 20 && token.length <= 4096))];
  const cleanTokens = await filterTenantTokens(caller, requestedTokens);
  if (cleanTokens.length === 0) {
    throw new HttpsError("invalid-argument", "No hay tokens validos.");
  }

  let successCount = 0;
  let failureCount = 0;
  const invalidTokens = [];

  for (let i = 0; i < cleanTokens.length; i += 500) {
    const batch = cleanTokens.slice(i, i + 500);
    const response = await admin.messaging().sendEachForMulticast({
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
  const snapshot = await db.collection("users")
      .where("document", "==", documento)
      .where("role", "==", "Estudiante")
      .limit(1)
      .get();

  if (snapshot.empty) {
    throw new HttpsError(
        "not-found",
        "No existe una cuenta con ese documento.",
    );
  }
  const user = snapshot.docs[0].data();
  if ((user.status || "").toString().toLowerCase() !== "activo") {
    throw new HttpsError("permission-denied", "La cuenta esta inactiva.");
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

  try {
    const usuario = await admin.auth().createUser({
      email,
      password,
      displayName: `${nombres} ${apellidos}`.trim(),
    });
    return {exito: true, uid: usuario.uid};
  } catch (error) {
    console.error("Error creando usuario:", error.code);
    if (error.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "El correo ya esta registrado.");
    }
    throw new HttpsError("internal", "No se pudo crear el usuario.");
  }
});

exports.eliminarUsuarioAuth = onCall(async (request) => {
  const caller = await getCaller(request);
  requireAdmin(caller);
  const uid = requiredString(request.data?.uid, "uid", 128);
  if (uid === caller.uid) {
    throw new HttpsError(
        "failed-precondition",
        "No puedes eliminar tu propia cuenta.",
    );
  }

  const targetSnap = await db.collection("users").doc(uid).get();
  if (!targetSnap.exists || !sameTenant(caller, targetSnap.data())) {
    throw new HttpsError(
        "permission-denied",
        "No puedes eliminar este usuario.",
    );
  }

  try {
    await admin.auth().deleteUser(uid);
    return {success: true};
  } catch (error) {
    console.error("Error eliminando usuario:", error.code);
    if (error.code === "auth/user-not-found") return {success: true};
    throw new HttpsError("internal", "No se pudo eliminar el usuario.");
  }
});
