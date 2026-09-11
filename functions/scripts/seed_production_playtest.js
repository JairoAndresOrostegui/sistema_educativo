"use strict";
/* eslint-disable max-len */

// Conjunto temporal y aislado para la prueba cerrada de Google Play.
// No contiene la contrasena: se recibe por PLAYTEST_PASSWORD_BASE.
// Ejecucion segura:
//   node scripts/seed_production_playtest.js              (plan)
//   node scripts/seed_production_playtest.js --apply      (aplica)

const crypto = require("crypto");
const {cloudAccess} = require("./cloud_access");
const {decode, encode} = require("./production_projection");

const PROJECT = "sistema-educativo-rl-prod";
const API_KEY = "AIzaSyBjvzhsUcfEXCZVW6pZxOCVdZsQJmU75rw";
const FIXTURE_ID = "play_store_closed_test_2026_09";
const INSTITUTION = "Rodolfo Llinas";
const CAMPUS = "Piedecuesta";
const YEAR = 2026;
const YEAR_ID = "967a4e35d5055eafdcfa18ca8bf9f51abb0f6ffc153f83db24c014a902f7db19";
const FIRESTORE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const RESOURCE = FIRESTORE.replace("https://firestore.googleapis.com/v1/", "");

const GROUPS = [
  {key: "g1", id: "playtest_2026_cuarto_prueba_a", level: "Cuarto Prueba", section: "A", name: "Cuarto Prueba A", order: 904},
  {key: "g2", id: "playtest_2026_septimo_prueba_a", level: "Séptimo Prueba", section: "A", name: "Séptimo Prueba A", order: 907},
];

const ACCOUNTS = [
  {key: "admin01", role: "Administrador", firstName: "Admin", lastName: "Prueba Uno"},
  {key: "admin02", role: "Administrador", firstName: "Admin", lastName: "Prueba Dos"},
  {key: "docente01", role: "Docente", firstName: "Laura", lastName: "Docente Prueba", group: "g1"},
  {key: "docente02", role: "Docente", firstName: "Diana", lastName: "Docente Prueba", group: "g2"},
  {key: "estudiante01", role: "Estudiante", firstName: "Andrés", lastName: "Estudiante Prueba", group: "g1"},
  {key: "estudiante02", role: "Estudiante", firstName: "Valentina", lastName: "Estudiante Prueba", group: "g1"},
  {key: "estudiante03", role: "Estudiante", firstName: "Sofía", lastName: "Estudiante Prueba", group: "g2"},
  {key: "estudiante04", role: "Estudiante", firstName: "Mateo", lastName: "Estudiante Prueba", group: "g2"},
  {key: "familiar01", role: "Familiar", firstName: "Familiar", lastName: "Hermanos Prueba", students: ["estudiante01", "estudiante03"]},
  {key: "familiar02", role: "Familiar", firstName: "Familiar", lastName: "Estudiante Uno", students: ["estudiante01"]},
  {key: "familiar03", role: "Familiar", firstName: "Familiar", lastName: "Estudiante Dos A", students: ["estudiante02"]},
  {key: "familiar04", role: "Familiar", firstName: "Familiar", lastName: "Estudiante Dos B", students: ["estudiante02"]},
  {key: "familiar05", role: "Familiar", firstName: "Familiar", lastName: "Estudiante Tres", students: ["estudiante03"]},
  {key: "familiar06", role: "Familiar", firstName: "Familiar", lastName: "Estudiante Cuatro A", students: ["estudiante04"]},
  {key: "familiar07", role: "Familiar", firstName: "Familiar", lastName: "Estudiante Cuatro B", students: ["estudiante04"]},
  {key: "familiar08", role: "Familiar", firstName: "Familiar", lastName: "Adicional Prueba", students: ["estudiante04"]},
].map((item, index) => ({
  ...item,
  email: `playtest.${item.key}@desarrolloytecnologiasantander.com`,
  document: `PT202609${String(index + 1).padStart(3, "0")}`,
}));

const ADMIN_PERMISSIONS = [
  "usuarios.ver", "usuarios.crear", "usuarios.editar", "usuarios.eliminar",
  "matricula.ver", "matricula.editar", "autorizaciones.ver", "autorizaciones.editar",
  "horarios.ver", "horarios.crear", "horarios.editar", "horarios.eliminar",
  "archivos.ver", "archivos.crear", "archivos.eliminar", "mensajeria.ver",
  "codigoqr.crear", "codigoqr.editar", "rutas.ver", "rutas.crear", "rutas.editar",
  "rutas.eliminar", "historial.ver", "sitio_web.ver", "sitio_web.editar",
  "parametros.ver", "parametros.editar", "asistencia.ver",
  "asistencia.crear", "asistencia.editar",
  "eventos.ver", "eventos.crear", "eventos.editar",
];
const TEACHER_PERMISSIONS = [
  "matricula.ver", "autorizaciones.ver", "horarios.ver", "archivos.ver",
  "archivos.crear", "mensajeria.ver", "rutas.ver", "asistencia.ver",
  "asistencia.crear",
  "eventos.ver", "eventos.crear", "eventos.editar",
];
const STUDENT_PERMISSIONS = [
  "horarios.ver", "archivos.ver", "mensajeria.ver", "rutas.ver",
  "asistencia.ver",
  "eventos.ver",
];
const FAMILY_PERMISSIONS = [
  "matricula.ver", "autorizaciones.ver", "horarios.ver", "archivos.ver",
  "mensajeria.ver", "rutas.ver", "asistencia.ver",
  "eventos.ver",
];

function passwordFor(account) {
  const base = process.env.PLAYTEST_PASSWORD_BASE;
  if (!base || base.length < 14) {
    throw new Error("PLAYTEST_PASSWORD_BASE debe tener al menos 14 caracteres.");
  }
  return `${base}-${account.key}`;
}

function accountPermissions(role) {
  if (role === "Administrador") return ADMIN_PERMISSIONS;
  if (role === "Docente") return TEACHER_PERMISSIONS;
  if (role === "Estudiante") return STUDENT_PERMISSIONS;
  return FAMILY_PERMISSIONS;
}

async function publicRequest(url, body) {
  const response = await fetch(url, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify(body),
  });
  const data = await response.json();
  if (!response.ok) {
    const error = new Error(data.error?.message || `HTTP ${response.status}`);
    error.status = response.status;
    throw error;
  }
  return data;
}

function firestoreWrite(path, data, exists = false) {
  return {
    update: {name: `${RESOURCE}/${path}`, fields: encode(data).mapValue.fields},
    currentDocument: {exists},
  };
}

function directoryData(profile) {
  const fields = [
    "firstName", "lastName", "role", "status", "institution", "campus",
    "groupId", "groupName", "studentIds", "activeStudentId", "photoUrl",
    "routeAddress",
  ];
  return Object.fromEntries(fields.filter((field) => profile[field] !== undefined)
      .map((field) => [field, profile[field]]));
}

async function getDocument(request, path) {
  try {
    const raw = await request(`${FIRESTORE}/${path}`);
    return {raw, data: decode({mapValue: {fields: raw.fields}})};
  } catch (error) {
    if (error.status === 404) return null;
    throw error;
  }
}

async function lookupAccount(request, email) {
  const result = await request(
      `https://identitytoolkit.googleapis.com/v1/projects/${PROJECT}/accounts:lookup`,
      "POST", {email: [email]},
  );
  return result.users?.[0] || null;
}

async function verifyFixture(request, verifyPasswords) {
  const fixture = await getDocument(request, `test_fixtures/${FIXTURE_ID}`);
  if (!fixture || fixture.data.phase !== "complete" || fixture.data.cleanupRequired !== true) {
    throw new Error("El inventario temporal no está completo.");
  }
  const authByKey = new Map();
  for (const account of ACCOUNTS) {
    const auth = await lookupAccount(request, account.email);
    if (!auth || auth.disabled === true) throw new Error(`Auth ausente o inactivo: ${account.key}`);
    if ((account.role !== "Estudiante") !== (auth.emailVerified === true)) {
      throw new Error(`Verificación de correo inesperada: ${account.key}`);
    }
    const profile = await getDocument(request, `users/${auth.localId}`);
    const directory = await getDocument(request, `user_directory/${auth.localId}`);
    if (!profile || !directory || profile.data.status !== "activo" ||
        profile.data.testFixtureId !== FIXTURE_ID || profile.data.role !== account.role ||
        directory.data.status !== "activo" || directory.data.role !== account.role) {
      throw new Error(`Perfil o directorio inconsistente: ${account.key} ` + JSON.stringify({
        profile: profile && {status: profile.data.status, role: profile.data.role,
          fixture: profile.data.testFixtureId},
        directory: directory && {status: directory.data.status, role: directory.data.role,
          fixture: directory.data.testFixtureId},
      }));
    }
    if (verifyPasswords) {
      await publicRequest(
          `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API_KEY}`,
          {email: account.email, password: passwordFor(account), returnSecureToken: false},
      );
    }
    authByKey.set(account.key, auth);
  }
  for (const group of GROUPS) {
    const doc = await getDocument(request, `academic_groups/${group.id}`);
    if (!doc || doc.data.active !== true || doc.data.academicYearId !== YEAR_ID ||
        doc.data.institutionId !== INSTITUTION || doc.data.campusId !== CAMPUS) {
      throw new Error(`Grupo inconsistente: ${group.id}`);
    }
    const channel = await getDocument(request, `message_channels/academic_${group.id}`);
    if (!channel || channel.data.status !== "active" || channel.data.groupId !== group.id) {
      throw new Error(`Canal académico inconsistente: ${group.id}`);
    }
  }
  const siblingFamily = await getDocument(request, `users/${authByKey.get("familiar01").localId}`);
  const siblingIds = new Set(siblingFamily.data.studentIds || []);
  if (!siblingIds.has(authByKey.get("estudiante01").localId) ||
      !siblingIds.has(authByKey.get("estudiante03").localId)) {
    throw new Error("El vínculo de hermanos entre grados no quedó materializado.");
  }
  for (const path of [
    "subjects/playtest_matematicas_g1", "subjects/playtest_lenguaje_g1",
    "subjects/playtest_ciencias_g2", "subjects/playtest_sociales_g2",
    "authorization_requests/playtest_authorization_pending",
    "routes/playtest_route_2026",
  ]) {
    const doc = await getDocument(request, path);
    if (!doc || doc.data.testFixtureId !== FIXTURE_ID) throw new Error(`Dato temporal ausente: ${path}`);
  }
  console.log(JSON.stringify({project: PROJECT, fixtureId: FIXTURE_ID, verified: true,
    accounts: ACCOUNTS.length, passwordLogins: verifyPasswords ? ACCOUNTS.length : 0,
    groups: GROUPS.length, enrollments: 4, schedules: 4, channels: 2,
    authorizationRequests: 1, routes: 1, cleanupRequired: true}, null, 2));
}

async function repairFixtureDirectories(request) {
  const writes = [];
  for (const account of ACCOUNTS) {
    const auth = await lookupAccount(request, account.email);
    if (!auth) throw new Error(`Auth ausente: ${account.key}`);
    const profile = await getDocument(request, `users/${auth.localId}`);
    const directory = await getDocument(request, `user_directory/${auth.localId}`);
    if (!profile || profile.data.testFixtureId !== FIXTURE_ID || !directory) {
      throw new Error(`No es seguro reparar el directorio de ${account.key}.`);
    }
    writes.push(firestoreWrite(`user_directory/${auth.localId}`, {
      ...directory.data, status: "activo",
    }, true));
  }
  await request(`${FIRESTORE}:commit`, "POST", {writes});
  console.log(JSON.stringify({fixtureId: FIXTURE_ID, repairedDirectories: writes.length}));
}

async function ensureAuthAccounts(request, apply) {
  const result = new Map();
  for (const account of ACCOUNTS) {
    let auth = await lookupAccount(request, account.email);
    if (!auth && apply) {
      const created = await publicRequest(
          `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${API_KEY}`,
          {email: account.email, password: passwordFor(account), returnSecureToken: false},
      );
      auth = {localId: created.localId, email: created.email};
      await request(
          `https://identitytoolkit.googleapis.com/v1/projects/${PROJECT}/accounts:update`,
          "POST", {localId: auth.localId, disableUser: true},
      );
    }
    if (auth) {
      const profile = await getDocument(request, `users/${auth.localId}`);
      if (profile && profile.data.testFixtureId !== FIXTURE_ID) {
        throw new Error(`El correo ${account.email} ya pertenece a un usuario no temporal.`);
      }
      result.set(account.key, {...auth, createdNow: !profile});
    }
  }
  return result;
}

function profileFor(account, uids, now) {
  const group = GROUPS.find((item) => item.key === account.group);
  const studentIds = (account.students || []).map((key) => uids.get(key).localId);
  const profile = {
    id: uids.get(account.key).localId,
    firstName: account.firstName,
    lastName: account.lastName,
    personalEmail: account.email,
    institutionalEmail: account.email,
    document: account.document,
    documentType: account.role === "Estudiante" ? "TI" : "CC",
    address: "Dirección temporal para prueba cerrada",
    phones: ["3000000000"],
    role: account.role,
    institution: INSTITUTION,
    campus: CAMPUS,
    permissions: accountPermissions(account.role),
    photoUrl: "",
    status: "inactivo",
    studentIds,
    activeStudentId: studentIds[0] || null,
    isSuperadmin: false,
    mustChangePassword: false,
    testFixtureId: FIXTURE_ID,
    temporaryPlayTest: true,
    createdAt: now,
    updatedAt: now,
  };
  if (group) {
    profile.groupId = group.id;
    profile.groupName = group.name;
    if (account.role === "Docente") profile.tutorGroupId = group.id;
  }
  if (account.role === "Estudiante") {
    profile.routeAddress = account.key === "estudiante01" || account.key === "estudiante03" ?
      "Carrera 10 # 20-30, dirección hermanos prueba" :
      `Calle ${20 + Number(account.key.slice(-2))} # 10-20, dirección prueba`;
  }
  if (account.role === "Familiar") profile.familyRelation = "Acudiente de prueba";
  return profile;
}

function enrollmentData(account, group, index) {
  return {
    nombresAlumno: account.firstName,
    apellidosAlumno: account.lastName,
    nombresApellidosAlumno: `${account.firstName} ${account.lastName}`,
    lugarNacimiento: "Piedecuesta",
    fechaNacimiento: `201${index + 2}-05-10`,
    edad: String(14 - index),
    tipoSangre: "O",
    rh: "+",
    tipoIdentidad: "TI",
    numeroIdentidad: account.document,
    direccionAlumno: "Dirección temporal para prueba cerrada",
    telefonoAlumno: "3000000000",
    epsEstudiante: "EPS de prueba",
    nombrePadre: "Padre de Prueba",
    cedulaPadre: `90000${index}01`,
    emailPadre: `padre${index + 1}@example.com`,
    celularPadre: "3000000001",
    nombreMadre: "Madre de Prueba",
    cedulaMadre: `90000${index}02`,
    emailMadre: `madre${index + 1}@example.com`,
    celularMadre: "3000000002",
    tieneAcudienteDiferente: "false",
    acudientePrincipal: "padre",
    facturaElectronica: "false",
    sedeAspirada: CAMPUS,
    groupId: group.id,
    groupName: group.name,
    nivelesCursadosInstitucion: [],
    servicioLonchera: "false",
    servicioAlmuerzo: "false",
    servicioTransporte: "true",
    servicioTransporteTipo: "tiempo_completo",
    observacionesPadres: "Registro temporal para validación de Google Play.",
    fueReferido: "false",
    institucion: INSTITUTION,
  };
}

function planDocuments(uids) {
  const now = new Date();
  const docs = [];
  const add = (path, data) => docs.push({path, data: {...data, testFixtureId: FIXTURE_ID, temporaryPlayTest: true}});
  for (const group of GROUPS) {
    add(`academic_groups/${group.id}`, {
      institutionId: INSTITUTION, campusId: CAMPUS, academicYearId: YEAR_ID,
      academicYear: YEAR, level: group.level, section: group.section,
      name: group.name, order: group.order, active: true, createdAt: now, updatedAt: now,
    });
  }
  const profiles = new Map();
  for (const account of ACCOUNTS) {
    const profile = profileFor(account, uids, now);
    profiles.set(account.key, profile);
    add(`users/${profile.id}`, profile);
    add(`user_directory/${profile.id}`, directoryData(profile));
    add(`user_history/playtest_create_${account.key}`, {
      usuarioId: profile.id, nombres: profile.firstName, apellidos: profile.lastName,
      rol: profile.role, accion: "creado_para_prueba_cerrada", realizadoPor: "Provisionamiento controlado",
      performedBy: "system_playtest_seed", institution: INSTITUTION, campus: CAMPUS, fecha: now,
    });
  }
  const students = ACCOUNTS.filter((item) => item.role === "Estudiante");
  students.forEach((account, index) => {
    const profile = profiles.get(account.key);
    const group = GROUPS.find((item) => item.key === account.group);
    const id = crypto.createHash("sha256").update(`${INSTITUTION}:${YEAR}:${account.document.toLowerCase()}`).digest("hex");
    const data = enrollmentData(account, group, index);
    add(`enrollments/${id}`, {
      id, estado: "matriculado", createdByRole: "admin", createdByUserId: uids.get("admin01").localId,
      token: null, fuente: "provisionamiento_prueba", vinculaUsuarioId: profile.id,
      anioMatricula: YEAR, academicYearId: YEAR_ID, academicYear: YEAR,
      institution: INSTITUTION, campus: CAMPUS, data,
      fechaDiligenciamiento: now, createdAt: now, updatedAt: now,
    });
    add(`enrollment_history/playtest_${account.key}`, {
      enrollmentId: id, action: "created", fromStatus: null, toStatus: "matriculado",
      performedBy: uids.get("admin01").localId, performedByRole: "Administrador",
      institution: INSTITUTION, campus: CAMPUS, groupId: group.id,
      groupName: group.name, createdAt: now,
    });
  });
  const schedules = [
    {id: "playtest_matematicas_g1", subject: "Matemáticas", teacher: "docente01", group: "g1", day: "lunes", start: 480, end: 540},
    {id: "playtest_lenguaje_g1", subject: "Lenguaje", teacher: "docente01", group: "g1", day: "miércoles", start: 540, end: 600},
    {id: "playtest_ciencias_g2", subject: "Ciencias", teacher: "docente02", group: "g2", day: "martes", start: 480, end: 540},
    {id: "playtest_sociales_g2", subject: "Sociales", teacher: "docente02", group: "g2", day: "jueves", start: 540, end: 600},
  ];
  const baseDate = Date.UTC(2000, 0, 1);
  for (const item of schedules) {
    const teacher = profiles.get(item.teacher);
    const group = GROUPS.find((entry) => entry.key === item.group);
    const value = {
      subject: item.subject, teacherId: teacher.id,
      teacherName: `${teacher.firstName} ${teacher.lastName}`,
      groupId: group.id, groupName: group.name, day: item.day,
      startMinutes: item.start, endMinutes: item.end,
      startTime: new Date(baseDate + (item.start + 300) * 60000),
      endTime: new Date(baseDate + (item.end + 300) * 60000),
      institutionId: INSTITUTION, campusId: CAMPUS, academicYearId: YEAR_ID,
      academicYear: YEAR, revision: 1, createdBy: uids.get("admin01").localId,
      createdAt: now, updatedAt: now,
    };
    add(`subjects/${item.id}`, value);
    add(`schedule_history/${item.id}`, {
      subjectId: item.id, action: "create_subject", before: null, after: value,
      performedBy: uids.get("admin01").localId, performedByRole: "Administrador",
      institutionId: INSTITUTION, campusId: CAMPUS, academicYearId: YEAR_ID,
      academicYear: YEAR, groupId: group.id, groupName: group.name, createdAt: now,
    });
  }
  for (const group of GROUPS) {
    const groupStudents = students.filter((item) => item.group === group.key).map((item) => profiles.get(item.key));
    const teacher = profiles.get(group.key === "g1" ? "docente01" : "docente02");
    const families = ACCOUNTS.filter((item) => item.role === "Familiar" &&
      (item.students || []).some((studentKey) => profiles.get(studentKey).groupId === group.id)).map((item) => profiles.get(item.key));
    const members = [...groupStudents, teacher, ...families];
    add(`message_channels/academic_${group.id}`, {
      channelType: "academic_group", category: "academic", iconKey: "school",
      title: `Grupo ${group.name}`, groupId: group.id, groupName: group.name,
      institutionId: INSTITUTION, campusId: CAMPUS, academicYearId: YEAR_ID,
      academicYear: YEAR, status: "active", postingPolicy: "members",
      studentIds: groupStudents.map((item) => item.id), teacherIds: [teacher.id],
      familyIds: families.map((item) => item.id), memberUserIds: members.map((item) => item.id).sort(),
      memberNames: Object.fromEntries(members.map((item) => [item.id, `${item.firstName} ${item.lastName}`])),
      memberRoles: Object.fromEntries(members.map((item) => [item.id, item.role])),
      mutedByAdmin: false, messageSequence: 0, readSequences: {}, readAtByUser: {},
      createdAt: now, updatedAt: now,
    });
  }
  const requester = profiles.get("familiar01");
  const authStudent = profiles.get("estudiante01");
  const authId = "playtest_authorization_pending";
  const authStart = new Date(Date.now() + 24 * 60 * 60 * 1000);
  const authEnd = new Date(authStart.getTime() + 2 * 60 * 60 * 1000);
  add(`authorization_requests/${authId}`, {
    id: authId, institutionId: INSTITUTION, campusId: CAMPUS,
    academicYearId: YEAR_ID, academicYear: YEAR, studentId: authStudent.id,
    studentFullName: `${authStudent.firstName} ${authStudent.lastName}`,
    groupId: authStudent.groupId, groupName: authStudent.groupName,
    allDay: false, multiDay: false, dateFrom: authStart, dateTo: null,
    startTime: authStart, endTime: authEnd,
    reason: "Cita de prueba para validar el flujo de autorizaciones.",
    requesterId: requester.id, requesterFullName: `${requester.firstName} ${requester.lastName}`,
    status: "pending", adminNote: null, evidence: null, requiresRequesterEdit: false,
    createdAt: now, updatedAt: now,
  });
  add(`authorization_history/${authId}`, {
    authorizationId: authId, action: "created", fromStatus: null, toStatus: "pending",
    performedBy: requester.id, performedByRole: "Familiar", institutionId: INSTITUTION,
    campusId: CAMPUS, academicYearId: YEAR_ID, academicYear: YEAR,
    groupId: authStudent.groupId, groupName: authStudent.groupName, createdAt: now,
  });
  const routeId = "playtest_route_2026";
  add(`routes/${routeId}`, {
    institution: INSTITUTION, campus: CAMPUS, academicYearId: YEAR_ID,
    academicYear: YEAR, nombre: "Ruta temporal prueba Play Store",
    direccionInicio: "Liceo Bilingüe Rodolfo Llinás, Piedecuesta",
    gestionador: profiles.get("docente01").id,
    estudiantes: students.map((item) => profiles.get(item.key).id),
    status: "active", fechaInicio: new Date("2026-09-01T05:00:00.000Z"),
    fechaFin: new Date("2026-10-31T05:00:00.000Z"),
    horaInicio: new Date("2000-01-01T11:30:00.000Z"),
    horaFin: new Date("2000-01-01T13:00:00.000Z"), revision: 1,
  });
  add(`route_history/${routeId}`, {
    institution: INSTITUTION, campus: CAMPUS, academicYearId: YEAR_ID,
    academicYear: YEAR, routeId, dailyRouteId: null,
    performedBy: uids.get("admin01").localId, action: "route_created_for_playtest", createdAt: now,
  });
  return docs;
}

async function main() {
  if (process.env.GCLOUD_PROJECT && process.env.GCLOUD_PROJECT !== PROJECT) {
    throw new Error("Proyecto inesperado en GCLOUD_PROJECT.");
  }
  const apply = process.argv.includes("--apply");
  if (apply) passwordFor(ACCOUNTS[0]);
  const request = await cloudAccess();
  const fixture = await getDocument(request, `test_fixtures/${FIXTURE_ID}`);
  if (fixture?.data.phase === "complete") {
    if (process.argv.includes("--repair-directory-status")) {
      await repairFixtureDirectories(request);
      return;
    }
    if (process.argv.includes("--verify")) {
      await verifyFixture(request, Boolean(process.env.PLAYTEST_PASSWORD_BASE));
      return;
    }
    console.log(JSON.stringify({project: PROJECT, fixtureId: FIXTURE_ID, phase: "complete", noWrites: true}));
    return;
  }
  const uids = await ensureAuthAccounts(request, apply);
  if (!apply && uids.size !== ACCOUNTS.length) {
    console.log(JSON.stringify({project: PROJECT, fixtureId: FIXTURE_ID, mode: "dry-run", accounts: ACCOUNTS.length,
      existingFixtureAccounts: uids.size, groups: GROUPS.length, students: 4, families: 8,
      note: "Ejecuta con --apply y PLAYTEST_PASSWORD_BASE para crear."}, null, 2));
    return;
  }
  if (uids.size !== ACCOUNTS.length) throw new Error("No se pudieron resolver todas las cuentas de Auth.");
  const documents = planDocuments(uids);
  const existingPaths = [];
  for (const document of documents) {
    const existing = await getDocument(request, document.path);
    if (existing) {
      if (existing.data.testFixtureId !== FIXTURE_ID) throw new Error(`Documento no temporal ya existe: ${document.path}`);
      existingPaths.push(document.path);
    }
  }
  if (existingPaths.length) {
    throw new Error(`Provisionamiento parcial detectado (${existingPaths.length} documentos). Revisar antes de reintentar.`);
  }
  const fixtureData = {
    id: FIXTURE_ID, phase: "prepared", project: PROJECT, institution: INSTITUTION,
    campus: CAMPUS, academicYearId: YEAR_ID, accountEmails: ACCOUNTS.map((item) => item.email),
    authUids: ACCOUNTS.map((item) => uids.get(item.key).localId),
    documentPaths: documents.map((item) => item.path), createdAt: new Date(),
    cleanupRequired: true, temporaryPlayTest: true,
  };
  const writes = documents.map((item) => firestoreWrite(item.path, item.data, false));
  writes.push(firestoreWrite(`test_fixtures/${FIXTURE_ID}`, fixtureData, false));
  for (let index = 0; index < writes.length; index += 400) {
    await request(`${FIRESTORE}:commit`, "POST", {writes: writes.slice(index, index + 400)});
  }
  const activate = documents.filter((item) => item.path.startsWith("users/") || item.path.startsWith("user_directory/"))
      .map((item) => firestoreWrite(item.path, {...item.data, status: "activo", updatedAt: new Date()}, true));
  activate.push(firestoreWrite(`test_fixtures/${FIXTURE_ID}`, {...fixtureData, phase: "complete", completedAt: new Date()}, true));
  await request(`${FIRESTORE}:commit`, "POST", {writes: activate});
  for (const account of ACCOUNTS) {
    const auth = uids.get(account.key);
    await request(
        `https://identitytoolkit.googleapis.com/v1/projects/${PROJECT}/accounts:update`,
        "POST", {
          localId: auth.localId, password: passwordFor(account),
          displayName: `${account.firstName} ${account.lastName}`,
          emailVerified: account.role !== "Estudiante", disableUser: false,
        },
    );
  }
  console.log(JSON.stringify({project: PROJECT, fixtureId: FIXTURE_ID, phase: "complete",
    accounts: ACCOUNTS.length, documents: documents.length, groups: GROUPS.map((item) => item.name),
    cleanupRequired: true}, null, 2));
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
