"use strict";
/* eslint-disable max-len */
// Fixture temporal autorizado para validar Rutas con la cuenta real de Sara.
// Solo opera sobre identificadores reservados y conserva auditoria de alta/baja.
const {cloudAccess} = require("./cloud_access");
const {decode, encode} = require("./production_projection");

const PROJECT = "sistema-educativo-rl-prod";
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const RESOURCE = BASE.slice(BASE.indexOf("projects/"));
const SARA_UID = "gJNXZux0NkPheNMmsbOfP1iQdnG3";
const OWNER_UID = "qhUeXTpqALbKAkVXlXj8pjk0HQT2";
const ROUTE_ID = "playstore_validation_route_20260908";
const day = new Intl.DateTimeFormat("en-CA", {
  timeZone: "America/Bogota",
}).format(new Date());
const DAILY_ID = `${ROUTE_ID}_${day}`;

async function optional(request, path) {
  try {
    return await request(`${BASE}/${path}`);
  } catch (error) {
    if (error.status === 404) return null;
    throw error;
  }
}

function update(path, data, exists) {
  return {
    update: {
      name: `${RESOURCE}/${path}`,
      fields: encode(data).mapValue.fields,
    },
    currentDocument: {exists},
  };
}

function remove(path) {
  return {
    delete: `${RESOURCE}/${path}`,
    currentDocument: {exists: true},
  };
}

function patch(path, data, fields, exists = true) {
  return {
    update: {
      name: `${RESOURCE}/${path}`,
      fields: encode(data).mapValue.fields,
    },
    updateMask: {fieldPaths: fields},
    currentDocument: {exists},
  };
}

async function loadContext(request) {
  const [saraDoc, ownerDoc, settingsList] = await Promise.all([
    request(`${BASE}/users/${SARA_UID}`),
    request(`${BASE}/users/${OWNER_UID}`),
    request(`${BASE}/academic_year_settings?pageSize=100`),
  ]);
  const sara = decode({mapValue: {fields: saraDoc.fields}});
  const owner = decode({mapValue: {fields: ownerDoc.fields}});
  if (sara.status !== "activo" || sara.role !== "Estudiante" ||
      sara.institution !== "Rodolfo Llinas" || sara.campus !== "Piedecuesta") {
    throw new Error("Sara no coincide con el perfil productivo esperado");
  }
  if (owner.status !== "activo" || owner.isSuperadmin !== true ||
      owner.institution !== sara.institution || owner.campus !== sara.campus) {
    throw new Error("El responsable productivo no coincide con la sede");
  }
  const settings = (settingsList.documents || []).map((doc) => ({
    id: doc.name.split("/").pop(),
    ...decode({mapValue: {fields: doc.fields}}),
  })).find((value) => value.institutionId === sara.institution &&
    value.campusId === sara.campus);
  if (!settings?.activeYearId || !Number.isInteger(settings.activeYear)) {
    throw new Error("No hay anio lectivo activo en Piedecuesta");
  }
  const yearDoc = await request(`${BASE}/academic_years/${settings.activeYearId}`);
  const year = decode({mapValue: {fields: yearDoc.fields}});
  if (year.status !== "active" || year.year !== settings.activeYear) {
    throw new Error("La configuracion del anio activo no es consistente");
  }
  return {sara, owner, yearId: settings.activeYearId, year: settings.activeYear};
}

async function apply(request, context) {
  const paths = [
    `routes/${ROUTE_ID}`,
    `daily_routes/${DAILY_ID}`,
    `daily_routes/${DAILY_ID}/students/${SARA_UID}`,
    `daily_routes/${DAILY_ID}/live/location`,
  ];
  const existing = await Promise.all(paths.map((path) => optional(request, path)));
  if (existing.some(Boolean)) {
    throw new Error("El fixture ya existe; usa --status o --cleanup");
  }
  const now = new Date();
  const start = new Date(now.getTime() - 5 * 60 * 1000);
  const end = new Date(now.getTime() + 90 * 60 * 1000);
  const scope = {
    institution: context.sara.institution,
    campus: context.sara.campus,
    academicYearId: context.yearId,
    academicYear: context.year,
  };
  const route = {
    ...scope,
    nombre: "VALIDACION PLAY STORE - ELIMINAR",
    direccionInicio: "Liceo Bilingue Rodolfo Llinas - Piedecuesta",
    gestionador: OWNER_UID,
    estudiantes: [SARA_UID],
    fechaInicio: start,
    fechaFin: end,
    horaInicio: start,
    horaFin: end,
    status: "active",
    revision: 1,
    temporaryProductionFixture: true,
  };
  const daily = {
    ...scope,
    idRuta: ROUTE_ID,
    dailyId: DAILY_ID,
    nombreRuta: route.nombre,
    gestionador: OWNER_UID,
    gestionadaPorNombre: `${context.owner.firstName || ""} ${context.owner.lastName || ""}`.trim(),
    fecha: now,
    estado: "activa",
    revision: 1,
    mode: "manual",
    horaInicio: start,
    horaFin: null,
    temporaryProductionFixture: true,
  };
  const stop = {
    ...scope,
    id: SARA_UID,
    nombre: `${context.sara.firstName || ""} ${context.sara.lastName || ""}`.trim(),
    direccion: "Parada temporal de validacion en Piedecuesta",
    activo: true,
    recogido: false,
    anulado: false,
    orden: 0,
    avisosEnviados: 0,
    avisoEnviado: false,
    horaRecogida: null,
    estimatedMinutes: 5,
    estimatedArrivalAt: new Date(now.getTime() + 5 * 60 * 1000),
    estimatedAt: now,
    mapEnabled: true,
    temporaryProductionFixture: true,
  };
  const live = {
    ...scope,
    teacherPosition: {__geoPoint: true},
    lastUpdate: now,
    temporaryProductionFixture: true,
  };
  const liveFields = encode({...live, teacherPosition: null}).mapValue.fields;
  liveFields.teacherPosition = {
    geoPointValue: {latitude: 6.98754, longitude: -73.05061},
  };
  const audit = {
    ...scope,
    routeId: ROUTE_ID,
    dailyRouteId: DAILY_ID,
    performedBy: OWNER_UID,
    action: "production_validation_fixture_created",
    studentIds: [SARA_UID],
    createdAt: now,
  };
  const writes = [
    update(`routes/${ROUTE_ID}`, route, false),
    update(`daily_routes/${DAILY_ID}`, daily, false),
    update(`daily_routes/${DAILY_ID}/students/${SARA_UID}`, stop, false),
    {
      update: {name: `${RESOURCE}/daily_routes/${DAILY_ID}/live/location`, fields: liveFields},
      currentDocument: {exists: false},
    },
    update(`route_history/${ROUTE_ID}_created_${day}`, audit, false),
  ];
  const cleanPermissions = (context.sara.permissions || []).filter(
      (permission) => !permission.startsWith("autorizaciones."),
  );
  if (cleanPermissions.length !== (context.sara.permissions || []).length) {
    writes.push(patch(`users/${SARA_UID}`, {
      permissions: cleanPermissions,
      updatedAt: now,
    }, ["permissions", "updatedAt"]));
    writes.push(update(`user_history/${ROUTE_ID}_student_permissions_${day}`, {
      usuarioId: SARA_UID,
      nombres: context.sara.firstName || "",
      apellidos: context.sara.lastName || "",
      rol: context.sara.role,
      accion: "permisos_estudiante_normalizados",
      performedBy: OWNER_UID,
      institution: context.sara.institution,
      campus: context.sara.campus,
      removedPermissions: (context.sara.permissions || []).filter(
          (permission) => permission.startsWith("autorizaciones."),
      ),
      fecha: now,
    }, false));
  }
  await request(`${BASE}:commit`, "POST", {writes});
}

async function cleanup(request, context) {
  const paths = [
    `daily_routes/${DAILY_ID}/live/location`,
    `daily_routes/${DAILY_ID}/students/${SARA_UID}`,
    `daily_routes/${DAILY_ID}`,
    `routes/${ROUTE_ID}`,
  ];
  const docs = await Promise.all(paths.map((path) => optional(request, path)));
  const writes = [];
  docs.forEach((doc, index) => {
    if (!doc) return;
    const value = decode({mapValue: {fields: doc.fields}});
    if (value.temporaryProductionFixture !== true) {
      throw new Error(`Proteccion: ${paths[index]} no es el fixture temporal`);
    }
    writes.push(remove(paths[index]));
  });
  const cleanupAuditPath = `route_history/${ROUTE_ID}_cleaned_${day}`;
  if (!await optional(request, cleanupAuditPath)) {
    writes.push(update(cleanupAuditPath, {
      institution: context.sara.institution,
      campus: context.sara.campus,
      academicYearId: context.yearId,
      academicYear: context.year,
      routeId: ROUTE_ID,
      dailyRouteId: DAILY_ID,
      performedBy: OWNER_UID,
      action: "production_validation_fixture_cleaned",
      studentIds: [SARA_UID],
      removedDocuments: writes.length,
      createdAt: new Date(),
    }, false));
  }
  if (writes.length) await request(`${BASE}:commit`, "POST", {writes});
}

async function main() {
  const request = await cloudAccess();
  const context = await loadContext(request);
  if (process.argv.includes("--apply")) await apply(request, context);
  if (process.argv.includes("--cleanup")) await cleanup(request, context);
  const [route, daily, stop, live] = await Promise.all([
    optional(request, `routes/${ROUTE_ID}`),
    optional(request, `daily_routes/${DAILY_ID}`),
    optional(request, `daily_routes/${DAILY_ID}/students/${SARA_UID}`),
    optional(request, `daily_routes/${DAILY_ID}/live/location`),
  ]);
  console.log(JSON.stringify({
    project: PROJECT,
    day,
    routeId: ROUTE_ID,
    dailyRouteId: DAILY_ID,
    saraHasRoutesPermission: (context.sara.permissions || []).includes("rutas.ver"),
    saraHasInvalidAuthorizationPermission: (context.sara.permissions || []).some((permission) => permission.startsWith("autorizaciones.")),
    fixture: {route: Boolean(route), daily: Boolean(daily), stop: Boolean(stop), live: Boolean(live)},
  }));
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
