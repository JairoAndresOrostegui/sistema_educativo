"use strict";
/* eslint-disable max-len */
const {REAL_USERS} = require("./production_readiness");
const INSTITUTION = "Rodolfo Llinas";
const CAMPUSES = ["Piedecuesta", "Barrancabermeja"];
const PROFILE = ["firstName", "lastName", "personalEmail", "institutionalEmail",
  "document", "documentType", "address", "phones", "birthDate", "role",
  "groupId", "groupName", "institution", "campus", "permissions", "status",
  "birthCountry", "birthDepartment", "birthCity", "residenceCountry",
  "residenceDepartment", "residenceCity", "familyRelation", "studentIds",
  "activeStudentId", "routeAddress", "isSuperadmin"];
const DIRECTORY = ["firstName", "lastName", "role", "status", "institution", "campus",
  "groupId", "groupName", "studentIds", "activeStudentId", "routeAddress"];
const pick = (value, keys) => Object.fromEntries(keys.filter((k) => value[k] !== undefined).map((k) => [k, value[k]]));
function decode(v) {
  if (v.mapValue) return Object.fromEntries(Object.entries(v.mapValue.fields || {}).map(([k, x]) => [k, decode(x)]));
  if (v.arrayValue) return (v.arrayValue.values || []).map(decode);
  if (v.timestampValue) return new Date(v.timestampValue);
  if (v.integerValue !== undefined) return Number(v.integerValue);
  if (v.doubleValue !== undefined) return v.doubleValue;
  if (v.booleanValue !== undefined) return v.booleanValue;
  if (v.nullValue !== undefined) return null;
  if (v.stringValue !== undefined) return v.stringValue;
  throw new Error("Unsupported Firestore value; review projection");
}
function encode(v) {
  if (v === null) return {nullValue: null};
  if (v instanceof Date) return {timestampValue: v.toISOString()};
  if (Array.isArray(v)) return {arrayValue: {values: v.map(encode)}};
  if (typeof v === "object") return {mapValue: {fields: Object.fromEntries(Object.entries(v).map(([k, x]) => [k, encode(x)]))}};
  if (typeof v === "string") return {stringValue: v};
  if (typeof v === "boolean") return {booleanValue: v};
  if (Number.isFinite(v)) return Number.isInteger(v) ? {integerValue: String(v)} : {doubleValue: v};
  throw new Error("Unsupported projected value");
}
function projectCore(source, approved = REAL_USERS) {
  const result = [];
  const add = (collection, id, data) => result.push({path: `${collection}/${id}`, data});
  const years = source.academic_years.filter((d) => d.data.status === "active" &&
    d.data.institutionId === INSTITUTION && CAMPUSES.includes(d.data.campusId));
  if (years.length !== 2 || years.some((d) => d.data.year !== 2026) ||
      new Set(years.map((d) => d.data.campusId)).size !== 2) throw new Error("Review active academic years");
  for (const d of years) add("academic_years", d.id, pick(d.data, ["institutionId", "campusId", "year", "status"]));
  const settings = source.academic_year_settings.filter((d) => years.some((y) => y.id === d.data.activeYearId));
  if (settings.length !== 2) throw new Error("Missing academic year settings");
  for (const d of settings) {
    const year = years.find((y) => y.id === d.data.activeYearId).data;
    if (year.institutionId !== d.data.institutionId || year.campusId !== d.data.campusId || d.data.activeYear !== year.year) throw new Error("Year settings tenant mismatch");
    add("academic_year_settings", d.id, pick(d.data, ["institutionId", "campusId", "activeYear", "activeYearId"]));
  }
  const groups = source.academic_groups.filter((d) => years.some((y) => y.id === d.data.academicYearId) && d.data.active === true);
  for (const d of groups) {
    const year = years.find((y) => y.id === d.data.academicYearId).data;
    if (d.data.institutionId !== year.institutionId || d.data.campusId !== year.campusId || d.data.academicYear !== year.year) throw new Error("Group tenant/year mismatch");
    add("academic_groups", d.id, pick(d.data, ["institutionId", "campusId", "academicYearId", "academicYear", "level", "section", "name", "order", "active"]));
  }
  const schools = source.configuracion_colegios.filter((d) => d.data.institutionId === INSTITUTION);
  if (schools.length !== 1) throw new Error("Review institution configuration");
  const school = schools[0];
  const campuses = school.data.sedes.map((s) => typeof s === "string" ? s : s.id || s.nombre);
  if (CAMPUSES.some((c) => !campuses.includes(c))) throw new Error("Missing institution campus");
  // Images are migrated separately; never preserve a QA Storage URL in production.
  add("configuracion_colegios", school.id, {...pick(school.data, ["institutionId", "nombre", "sedes", "fuenteTitulos", "fuenteGeneral", "colorLabel", "colorTextoTitulo", "colorFondo"]), logoUrl: ""});
  for (const d of source.parameters) add("parameters", d.id, pick(d.data, ["clave", "valor", "etiqueta", "orden", "activo"]));
  for (const uid of approved) {
    const original = source.users.find((d) => d.id === uid)?.data;
    if (!original || original.status !== "activo" || original.institution !== INSTITUTION || !CAMPUSES.includes(original.campus)) throw new Error(`Invalid approved profile ${uid}`);
    const data = {...pick(original, PROFILE), id: uid, photoUrl: ""};
    if (!["Docente", "Administrador", "Estudiante"].includes(data.role)) throw new Error(`Unexpected role ${uid}`);
    if (data.groupId) {
      const group = groups.find((g) => g.id === data.groupId)?.data;
      if (!group || group.institutionId !== data.institution || group.campusId !== data.campus) throw new Error(`Invalid group ${uid}`);
      data.groupName = group.name;
    } else if (["Docente", "Estudiante"].includes(data.role)) throw new Error(`Missing group ${uid}`);
    data.studentIds = [...new Set((data.studentIds || []).filter(Boolean))];
    if (data.studentIds.some((id) => !approved.includes(id))) throw new Error(`QA-only child reference ${uid}`);
    for (const child of data.studentIds) {
      const linked = source.users.find((u) => u.id === child)?.data;
      if (linked?.role !== "Estudiante" || linked.status !== "activo" || linked.institution !== data.institution || linked.campus !== data.campus) throw new Error(`Invalid child ${uid}`);
    }
    if (data.activeStudentId && !data.studentIds.includes(data.activeStudentId)) throw new Error(`Invalid active child ${uid}`);
    if (!data.activeStudentId) delete data.activeStudentId;
    add("users", uid, data);
    add("user_directory", uid, {...pick(data, DIRECTORY), photoUrl: ""});
  }
  const serialized = JSON.stringify(result);
  if (serialized.includes("sistema-educativo-rl.firebasestorage.app") || serialized.includes("sistema-educativo-rl.appspot.com")) throw new Error("QA storage reference remains in core projection");
  return result;
}
module.exports = {decode, encode, projectCore};
