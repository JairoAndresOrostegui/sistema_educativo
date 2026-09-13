"use strict";
/* eslint-disable max-len */

// Aprovisionamiento administrativo explícito SOLO QA. Sin passwords en consola
// ni en Git; todas las operaciones de eventos usan las Functions desplegadas.
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const crypto = require("node:crypto");
const {Firestore, FieldValue} = require("@google-cloud/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {cloudCredentials, cloudCredential} = require("./cloud_access");

const PROJECT = "sistema-educativo-rl";
const FIXTURE = "qa_events_qr_2026_09";
const ADMIN = "qhUeXTpqALbKAkVXlXj8pjk0HQT2";
const SARA = "gJNXZux0NkPheNMmsbOfP1iQdnG3";
const API_KEY = "AIzaSyBjfpuzVCTvKEMdYGYjMa619SSJ1yL8Jho";
const privateDirectory = path.join(os.homedir(), ".config", "sistema_educativo");
const credentialPath = path.join(privateDirectory, "qa-eventos-2026-09.json");
const guidePath = path.join(privateDirectory, "GUIA_PRUEBAS_QA_EVENTOS.md");
const definitions = [
  {key: "admin", role: "Administrador", name: "Administrador QA Eventos", permissions: ["eventos.ver", "eventos.crear", "eventos.editar", "rutas.ver", "rutas.crear", "rutas.editar", "codigoqr.ver", "codigoqr.crear", "codigoqr.editar"]},
  {key: "docente", role: "Docente", name: "Docente QA Eventos", permissions: ["eventos.ver", "eventos.crear", "eventos.editar", "rutas.ver"]},
  {key: "familiar1", role: "Familiar", name: "Familiar QA Uno", permissions: ["eventos.ver", "rutas.ver"]},
  {key: "familiar2", role: "Familiar", name: "Familiar QA Dos", permissions: ["eventos.ver", "rutas.ver"]},
];

function requireQa(args = process.argv.slice(2)) {
  if (args.find((a) => a.startsWith("--project=")) !== `--project=${PROJECT}` ||
      process.env.FIRESTORE_EMULATOR_HOST || process.env.FIREBASE_AUTH_EMULATOR_HOST) {
    throw new Error(`Este script solo admite --project=${PROJECT}, sin emuladores.`);
  }
}

function services() {
  const db = new Firestore({projectId: PROJECT, credentials: cloudCredentials()});
  const app = initializeApp({projectId: PROJECT, credential: cloudCredential()}, FIXTURE);
  return {db, auth: getAuth(app)};
}

async function checkedContext(db, auth) {
  const [admin, sara, adminAuth, saraAuth] = await Promise.all([
    db.doc(`users/${ADMIN}`).get(), db.doc(`users/${SARA}`).get(),
    auth.getUser(ADMIN), auth.getUser(SARA),
  ]);
  const owner = admin.data() || {};
  const student = sara.data() || {};
  if (owner.status !== "activo" || owner.role !== "Administrador" || !owner.isSuperadmin ||
      student.role !== "Estudiante" || student.status !== "activo" ||
      student.institution !== owner.institution || student.campus !== owner.campus ||
      !owner.permissions?.includes("eventos.editar") || !student.permissions?.includes("eventos.ver") ||
      adminAuth.disabled || saraAuth.disabled) {
    throw new Error("Revisar admin/Sara QA: rol, estado, alcance o permiso no coinciden; no se modificaron.");
  }
  const group = await db.doc(`academic_groups/${student.groupId}`).get();
  const year = await db.doc(`academic_years/${group.data()?.academicYearId}`).get();
  if (!group.exists || !group.data().active || !year.exists || year.data().status !== "active" ||
      year.data().institutionId !== owner.institution || year.data().campusId !== owner.campus) {
    throw new Error("El grupo o año de Sara no es válido.");
  }
  return {owner, student, groupId: group.id, group: group.data(), yearId: year.id,
    year: year.data().year, institution: owner.institution, campus: owner.campus,
    ownerEmail: adminAuth.email, studentEmail: saraAuth.email};
}

function credentials(create) {
  if (fs.existsSync(credentialPath)) {
    const value = JSON.parse(fs.readFileSync(credentialPath, "utf8"));
    if (value.projectId !== PROJECT || value.fixtureId !== FIXTURE) throw new Error("Archivo privado ajeno al fixture.");
    return value;
  }
  if (!create) throw new Error("Falta aprovisionar las identidades QA.");
  const value = {projectId: PROJECT, fixtureId: FIXTURE, accounts: definitions.map((item) => ({
    ...item, uid: `${FIXTURE}_${item.key}`,
    email: `qa.eventos.${item.key}@desarrolloytecnologiasantander.com`,
    password: `Qa!7${crypto.randomBytes(16).toString("base64url")}`,
  }))};
  fs.mkdirSync(privateDirectory, {recursive: true});
  fs.writeFileSync(credentialPath, JSON.stringify(value, null, 2), {encoding: "utf8", flag: "wx", mode: 0o600});
  return value;
}

async function provisionIdentity(db, auth, context, account) {
  let authUser;
  try {
    authUser = await auth.getUser(account.uid);
  } catch (error) {
    if (error.code !== "auth/user-not-found") throw error;
  }
  const profileRef = db.doc(`users/${account.uid}`);
  const before = await profileRef.get();
  if (before.exists && before.data().testFixtureId !== FIXTURE ||
      authUser && (authUser.email !== account.email || authUser.displayName !== account.name)) {
    throw new Error("Identidad existente ajena al fixture; detenido sin reemplazarla.");
  }
  if (before.exists) {
    if (!authUser || before.data().role !== account.role || before.data().institution !== context.institution ||
        before.data().campus !== context.campus) throw new Error("Fixture inconsistente; no se sobrescribe.");
    if (before.data().status !== "activo") throw new Error("La cuenta QA fue desactivada; no reactivarla automáticamente.");
    // Recovery only for an Auth account left disabled by interrupted provisioning.
    if (authUser.disabled && before.data().qaProvisioning === true) {
      await auth.updateUser(account.uid, {disabled: false});
      await profileRef.update({qaProvisioning: false});
    } else if (authUser.disabled) throw new Error("La cuenta QA fue desactivada en Auth.");
    return;
  }
  if (!authUser) {
    await auth.createUser({uid: account.uid, email: account.email, password: account.password,
      displayName: account.name, emailVerified: true, disabled: true});
  }
  const family = account.role === "Familiar";
  const profile = {
    id: account.uid, firstName: account.name, lastName: "Prueba temporal",
    institutionalEmail: account.email, personalEmail: account.email,
    document: `QA-EVENTOS-${account.key.toUpperCase()}`, documentType: "CC",
    role: account.role, institution: context.institution, campus: context.campus,
    permissions: account.permissions, status: "activo", revision: 1,
    isSuperadmin: false, mustChangePassword: false, photoUrl: "", phones: [],
    address: "Datos ficticios QA", studentIds: family ? [SARA] : [],
    activeStudentId: family ? SARA : null,
    testFixtureId: FIXTURE, qaProvisioning: true,
    createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
  };
  const directory = {id: account.uid, firstName: profile.firstName, lastName: profile.lastName,
    role: account.role, institution: context.institution, campus: context.campus,
    status: "activo", isSuperadmin: false, photoUrl: "", studentIds: profile.studentIds,
    testFixtureId: FIXTURE};
  const keys = ["document", "personalEmail", "institutionalEmail"].map((field) => {
    const value = profile[field].trim().toLowerCase();
    return {field, value, ref: db.doc(`user_unique_keys/${crypto.createHash("sha256").update(`${field}\u0000${value}`).digest("hex")}`)};
  });
  await db.runTransaction(async (tx) => {
    const snapshots = await tx.getAll(profileRef, ...keys.map((item) => item.ref), db.doc(`users/${SARA}`));
    if (snapshots[0].exists || snapshots.slice(1, -1).some((item) => item.exists) ||
        snapshots.at(-1).data()?.status !== "activo") throw new Error("Cambió una identidad o vínculo durante el aprovisionamiento.");
    tx.create(profileRef, profile);
    tx.create(db.doc(`user_directory/${account.uid}`), directory);
    for (const item of keys) {
      tx.create(item.ref, {uid: account.uid, field: item.field, value: item.value,
        createdAt: FieldValue.serverTimestamp()});
    }
    tx.create(db.doc(`user_history/${FIXTURE}_${account.key}`), {usuarioId: account.uid,
      accion: "aprovisionamiento_qa_eventos", performedBy: ADMIN, institution: context.institution,
      campus: context.campus, rol: account.role, testFixtureId: FIXTURE, fecha: FieldValue.serverTimestamp()});
  });
  await auth.updateUser(account.uid, {disabled: false});
  await profileRef.update({qaProvisioning: false});
}

async function session(account) {
  const response = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API_KEY}`, {
    method: "POST", headers: {"Content-Type": "application/json"},
    body: JSON.stringify({email: account.email, password: account.password, returnSecureToken: true}),
  });
  const result = await response.json();
  if (!response.ok || result.localId !== account.uid || typeof result.idToken !== "string") {
    throw new Error(`No se pudo autenticar fixture ${account.key}: ${result.error?.message || response.status}`);
  }
  const claims = JSON.parse(Buffer.from(result.idToken.split(".")[1], "base64url").toString("utf8"));
  if (claims.aud !== PROJECT || claims.email_verified !== true) throw new Error("Sesión fuera de QA o no verificada.");
  return async (name, data = {}) => {
    if (!/^[A-Za-z][A-Za-z0-9]+$/.test(name)) throw new Error("Function inválida.");
    const response = await fetch(`https://us-central1-${PROJECT}.cloudfunctions.net/${name}`, {
      method: "POST", headers: {"Content-Type": "application/json", "Authorization": `Bearer ${result.idToken}`},
      body: JSON.stringify({data}), signal: AbortSignal.timeout(65000),
    });
    const body = await response.json();
    if (!response.ok || body.error) {
      const error = new Error(`${name}: ${body.error?.message || response.status}`);
      error.code = body.error?.status || response.status;
      throw error;
    }
    return body.result;
  };
}

async function seedEvents(db, context, privateData) {
  const api = await session(privateData.accounts.find((a) => a.key === "admin"));
  const manifestRef = db.doc(`migration_audit/${FIXTURE}`);
  const existing = (await manifestRef.get()).data() || {};
  const manifest = {...existing, eventIds: {...existing.eventIds}};
  const start = new Date();
  start.setUTCDate(start.getUTCDate() + 3);
  start.setUTCHours(20, 0, 0, 0);
  const examples = [
    {key: "presentacion", title: "QA · Presentación de baile", eventType: "student_presentation",
      subtitle: "Ensayo con reserva de alimentos", foodEnabled: true,
      requirements: [{id: "traje", label: "Traje preparado", instructions: "Marcar tras comprobar el traje de ensayo.", targetType: "student", completionType: "manual", required: true},
        {id: "aporte", label: "Aporte de ensayo", instructions: "Simulación; no pagar dinero real.", targetType: "student", completionType: "payment", required: false, amountCop: 5000}]},
    {key: "padres", title: "QA · Encuentro de padres", eventType: "parent_meeting",
      subtitle: "Entrega de boletines", foodEnabled: false,
      requirements: [{id: "boletin", label: "Boletín entregado", instructions: "Confirmar individualmente al adulto que lo recibe.", targetType: "family", completionType: "manual", required: true},
        {id: "asistencia", label: "Asistencia del familiar", instructions: "Registrar desde el inicio del encuentro, por cada adulto.", targetType: "family", completionType: "attendance", required: true}]},
  ];
  for (const example of examples) {
    let eventId = manifest.eventIds[example.key];
    if (!eventId) {
      const candidates = await db.collection("school_events").where("createdBy", "==",
          privateData.accounts.find((a) => a.key === "admin").uid).get();
      const matches = candidates.docs.filter((doc) => {
        const value = doc.data();
        return value.title === example.title && value.institutionId === context.institution &&
          value.campusId === context.campus && value.targetStudentIds?.length === 1 &&
          value.targetStudentIds[0] === SARA;
      });
      if (matches.length > 1) throw new Error("Hay borradores QA repetidos; revisar antes de continuar.");
      if (matches.length === 1) eventId = matches[0].id;
    }
    if (!eventId) {
      const eventStart = example.key === "padres" ? Date.now() + 300000 : start.getTime();
      const value = await api("guardarEvento", {...example, key: undefined,
        description: "Evento temporal exclusivo de QA para practicar. Sin cobros ni compromisos reales.",
        location: "Patio del colegio · demostración QA", startAtMillis: eventStart,
        endAtMillis: eventStart + (example.key === "padres" ? 86400000 : 7200000), audienceType: "students", targetStudentIds: [SARA],
        responsibleUserIds: [ADMIN, privateData.accounts.find((a) => a.key === "docente").uid],
        registrationRequired: true, requiresFamilyAuthorization: false, links: [],
        publicity: {text: "Presentación de prueba: no asistir ni realizar pagos reales.", url: ""},
      });
      eventId = value.eventId;
    }
    const current = (await db.doc(`school_events/${eventId}`).get()).data();
    if (!current || current.createdBy !== privateData.accounts.find((a) => a.key === "admin").uid ||
        current.title !== example.title || current.institutionId !== context.institution || current.campusId !== context.campus ||
        current.testFixtureId && current.testFixtureId !== FIXTURE) throw new Error("Evento ajeno al manifiesto QA; no modificarlo.");
    manifest.eventIds[example.key] = eventId;
    await manifestRef.set({projectId: PROJECT, testFixtureId: FIXTURE, eventIds: manifest.eventIds,
      institutionId: context.institution, campusId: context.campus, performedBy: ADMIN,
      updatedAt: FieldValue.serverTimestamp()}, {merge: true});
    await db.doc(`school_events/${eventId}`).update({testFixtureId: FIXTURE});
    if (current.status !== "draft") continue;
    const food = await db.collection("event_food_items").where("eventId", "==", eventId).get();
    if (example.foodEnabled && food.empty) {
      for (const item of [{name: "Jugo de prueba", priceCop: 3000}, {name: "Sándwich de prueba", priceCop: 6000}]) {
        await api("guardarAlimentoEvento", {eventId, ...item, description: "Reserva de ensayo sin cobro real", active: true});
      }
    }
    const materials = await db.collection("event_materials").where("eventId", "==", eventId).get();
    if (example.foodEnabled && materials.empty) {
      await api("guardarMaterialEvento", {eventId, kind: "costume", name: "Traje de ensayo",
        instructions: "Camiseta blanca y pantalón oscuro que ya tengas; no comprar.",
        amountCop: 0, address: "Consultar al docente en el colegio", url: "", groupIds: [context.groupId], active: true});
    }
    const fresh = (await db.doc(`school_events/${eventId}`).get()).data();
    await api("cambiarEstadoEvento", {eventId, expectedRevision: fresh.revision, status: "published"});
  }
  await manifestRef.set({seedCompletedAt: FieldValue.serverTimestamp()}, {merge: true});
  return manifest.eventIds;
}

function writeGuide(context, privateData, eventIds) {
  const lines = ["# Pruebas de Eventos y QR en QA", "", "Solo https://sistema-educativo-rl.web.app . No usar producción.", "",
    `Jairo: ${context.ownerEmail}. Conserva su contraseña actual de QA y rol administrador.`,
    `Sara: ${context.studentEmail}. Conserva su contraseña actual de QA y rol estudiante.`,
    "No se cambiaron sus contraseñas ni se concedió administración a Sara.", "",
    "## Cuentas temporales para probar los demás roles", ""];
  for (const account of privateData.accounts) {
    lines.push(account.name, `Correo: ${account.email}`,
        `Contraseña: ${account.password}`, `Rol: ${account.role}`, "");
  }
  lines.push("Cada familiar de prueba está vinculado a Sara solo en QA. No compartir este archivo fuera del grupo de prueba.", "",
      "## Recorrido de prueba", "",
      "Administrador: abrir Eventos. Revisar Presentación de baile y Encuentro de padres. Para crear otro, guardar borrador, configurar requisitos y alimentos cuando correspondan, y publicar.", "",
      "Familiar Uno: abrir Eventos con Sara seleccionada. En Presentación, reservar un jugo y un sándwich. Anotar el total calculado. Abrir su propio QR para que lo escanee el docente.", "",
      "Familiar Dos: entrar con su cuenta y comprobar que su pedido/asistencia no se marcó al operar con Familiar Uno.", "",
      "Docente: abrir Encuentro de padres, Seguimiento. Escanear QR de Familiar Uno y confirmar Boletín entregado. Registrar asistencia solo cuando llegue la hora del evento. Para presentación, revisar materiales y registrar pago del pedido de prueba. La entrega se habilita al iniciar el evento; antes debe quedar bloqueada.", "",
      "Sara: consultar ambos eventos y materiales. Mostrar su carnet QR. No debe poder reservar alimentos ni marcar pagos o cumplimientos.", "",
      "QR de evento: administrador abre Administrar QR en el tablero, busca QA · Presentación de baile en Buscar usuario o evento y lo selecciona para mostrar el código. El familiar abre su módulo QR, pulsa Leer con cámara y abre la ficha del evento con Sara seleccionada.", "",
      "Rutas: responsable abre un recorrido iniciado con Sara pendiente, escanea su QR y confirma recogida. Se conserva el botón manual. Escanear sin confirmar no debe recogerla.", "",
      "Antes de probar Rutas con Sara: su ruta antigua de QA aún tiene fechas de 2025 y recorridos históricos abiertos. No se modificaron durante esta ampliación. Hace falta preparar una ruta vigente con su responsable; no volver a grabar ni probar GPS usando esos recorridos antiguos.", "",
      "GPS: fuera de ventana no debe verse mapa familiar; con aviso de hasta diez minutos sí; después de recoger/finalizar se revoca. Comprobar GPS real y cámara en Android con APK QA.", "",
      "Push: iniciar sesión y activar avisos en cada equipo QA. Publicación, pedido y cumplimiento generan avisos a sus destinatarios. Una aceptación del servidor no confirma que el equipo los mostró.", "",
      "Los pagos son marcas manuales de ensayo. No existe pasarela ni stock reservado garantizado. No pagar dinero real.", "",
      ...Object.entries(eventIds || {}).map(([key, id]) => `${key}: https://sistema-educativo-rl.web.app/#/events?eventId=${encodeURIComponent(id)}`), "");
  fs.writeFileSync(guidePath, lines.join("\n"), {encoding: "utf8", mode: 0o600});
}

async function main() {
  requireQa();
  const {db, auth} = services();
  const context = await checkedContext(db, auth);
  const legacy = await db.collection("events").count().get();
  if (legacy.data().count) throw new Error("Hay identificadores de evento antiguos; migración explícita necesaria antes de continuar.");
  const applyIdentities = process.argv.includes("--apply-identities");
  const applyEvents = process.argv.includes("--seed-events");
  const guideOnly = process.argv.includes("--write-guide");
  if (!applyIdentities && !applyEvents && !guideOnly) {
    console.log(JSON.stringify({projectId: PROJECT, planOnly: true, realAccountsUnchanged: true,
      temporaryAccounts: definitions.map(({key, role}) => ({key, role})), legacyEvents: 0}));
    return;
  }
  const privateData = credentials(applyIdentities);
  if (applyIdentities) {
    for (const account of privateData.accounts) await provisionIdentity(db, auth, context, account);
  }
  const eventIds = applyEvents ? await seedEvents(db, context, privateData) :
    (await db.doc(`migration_audit/${FIXTURE}`).get()).data()?.eventIds || {};
  writeGuide(context, privateData, eventIds);
  console.log(JSON.stringify({projectId: PROJECT, identitiesProvisioned: applyIdentities,
    eventIds, guidePath, realAccountsUnchanged: true}));
}

module.exports = {PROJECT, FIXTURE, ADMIN, SARA, requireQa, services, checkedContext, credentials, session};
if (require.main === module) {
  main().catch((error) => {
    console.error(error.code || error.message);
    process.exitCode = 1;
  });
}
