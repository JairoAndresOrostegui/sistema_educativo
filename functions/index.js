"use strict";

const {setGlobalOptions} = require("firebase-functions/v2");
const {onCall} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();
setGlobalOptions({maxInstances: 10});

exports.enviarNotificacion = onCall(async (request) => {
  const {tokens, titulo, cuerpo} = request.data;

  if (!tokens || !Array.isArray(tokens) || tokens.length === 0) {
    throw new Error("No se proporcionaron tokens validos.");
  }

  const cleanTokens = [...new Set(tokens
      .filter((token) => typeof token === "string")
      .map((token) => token.trim())
      .filter((token) => token.length > 0))];

  if (cleanTokens.length === 0) {
    throw new Error("No se proporcionaron tokens validos.");
  }

  let successCount = 0;
  let failureCount = 0;

  for (let i = 0; i < cleanTokens.length; i += 500) {
    const batch = cleanTokens.slice(i, i + 500);
    const mensaje = {
      notification: {
        title: titulo,
        body: cuerpo,
      },
      tokens: batch,
    };

    const respuesta = await admin.messaging().sendEachForMulticast(mensaje);
    successCount += respuesta.successCount;
    failureCount += respuesta.failureCount;
  }

  return {
    exitosos: successCount,
    fallidos: failureCount,
  };
});

exports.crearUsuarioDesdeAdmin = onCall(async (request) => {
  const {email, password, nombres, apellidos, rol, documento} = request.data;

  if (!email || !password || !nombres || !apellidos || !rol || !documento) {
    throw new Error("Faltan datos obligatorios");
  }

  try {
    const usuario = await admin.auth().createUser({email, password});
    return {exito: true, uid: usuario.uid};
  } catch (error) {
    console.error("Error creando usuario desde admin:", error);
    throw new Error("No se pudo crear el usuario: " + error.message);
  }
});

exports.eliminarUsuarioAuth = onCall(async (request) => {
  const {uid} = request.data;

  if (!uid) {
    throw new Error("Se requiere el UID del usuario para eliminarlo.");
  }

  try {
    await admin.auth().deleteUser(uid);
    return {success: true};
  } catch (error) {
    console.error("Error al eliminar usuario de Auth:", error);
    throw new Error("No se pudo eliminar el usuario.");
  }
});
