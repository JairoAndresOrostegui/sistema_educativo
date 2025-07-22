"use strict";

const {setGlobalOptions} = require("firebase-functions/v2");
const {onCall} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();
setGlobalOptions({maxInstances: 10});

exports.enviarNotificacionRuta = onCall(async (request) => {
  const {tokens, titulo, cuerpo} = request.data;

  if (!tokens || !Array.isArray(tokens) || tokens.length === 0) {
    throw new Error("No se proporcionaron tokens válidos.");
  }

  const mensaje = {
    notification: {
      title: titulo,
      body: cuerpo,
    },
    tokens,
  };

  const respuesta = await admin
      .messaging()
      .sendEachForMulticast(mensaje);


  return {
    exitosos: respuesta.successCount,
    fallidos: respuesta.failureCount,
  };
});

exports.crearUsuarioDesdeAdmin = onCall(async (request) => {
  const {email, password, nombres, apellidos, rol, documento} = request.data;

  if (!email || !password || !nombres || !apellidos || !rol || !documento) {
    throw new Error("Faltan datos obligatorios");
  }

  try {
    const usuario = await admin.auth().createUser({
      email,
      password,
    });

    const userData = {
      nombres,
      apellidos,
      correo: email,
      documento,
      rol,
      activo: true,
      esSuperadmin: false,
      creadoEn: admin.firestore.FieldValue.serverTimestamp(),
    };

    await admin.firestore()
        .collection("usuarios")
        .doc(usuario.uid)
        .set(userData);

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

