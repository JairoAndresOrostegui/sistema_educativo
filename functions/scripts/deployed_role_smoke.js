"use strict";
/* eslint-disable max-len */

// Lecturas con credenciales reales de fixtures. No crea datos ni actualiza
// contextos familiares, contraseñas, QR, lecturas, descargas o slots push.
// Auth registra el login permitido; nunca se imprime el ID token ni el correo.
// Por defecto solo prepara un plan local. --run habilita las solicitudes.
// node scripts/deployed_role_smoke.js --project qa --credentials <archivo.docx> --run
const fs = require("fs");
const path = require("path");
const {execFileSync} = require("child_process");
const {cloudAccess} = require("./cloud_access");
const {decode, encode} = require("./production_projection");

const ROOT = path.resolve(__dirname, "../..");
const PROJECTS = {qa: "sistema-educativo-rl", prod: "sistema-educativo-rl-prod"};
const FIXTURE = "play_store_closed_test_2026_09";
const READ_FUNCTIONS = new Set([
  "obtenerOpcionesMatriculaPublica", "obtenerHijosVinculados",
  "consultarHorarios", "listarArchivos", "listarEventos",
  "listarContextosAsistencia", "listarSesionesAsistencia", "consultarMiAsistencia",
  "listarEntidadesQr", "listarGruposAcademicosAdministracion",
]);
const unescapeXml = (text) => text.replace(/&#(x[\da-f]+|\d+);/gi,
    (_, value) => String.fromCodePoint(value[0].toLowerCase() === "x" ?
      parseInt(value.slice(1), 16) : Number(value)))
    .replace(/&lt;/g, "<").replace(/&gt;/g, ">")
    .replace(/&quot;/g, "\"").replace(/&apos;/g, "'").replace(/&amp;/g, "&");

function credentialsFromDocxXml(xml) {
  const accounts = [];
  for (const table of xml.matchAll(/<w:tbl\b[^>]*>([\s\S]*?)<\/w:tbl>/g)) {
    let emailIndex = -1; let passwordIndex = -1;
    for (const row of table[1].matchAll(/<w:tr\b[^>]*>([\s\S]*?)<\/w:tr>/g)) {
      const cells = [...row[1].matchAll(/<w:tc\b[^>]*>([\s\S]*?)<\/w:tc>/g)]
          .map((cell) => [...cell[1].matchAll(/<w:t\b[^>]*>([\s\S]*?)<\/w:t>/g)]
              .map((part) => unescapeXml(part[1])).join("").trim());
      const normalized = cells.map((cell) => cell.toLowerCase());
      if (normalized.includes("correo") && normalized.includes("contraseña")) {
        emailIndex = normalized.indexOf("correo");
        passwordIndex = normalized.indexOf("contraseña");
        continue;
      }
      if (emailIndex < 0 || passwordIndex < 0) continue;
      const email = cells[emailIndex]; const password = cells[passwordIndex];
      // Solo cuentas temporales reconocibles; no reutilizar cuentas personales.
      if (/^playtest\.[a-z]+\d+@desarrolloytecnologiasantander\.com$/i.test(email || "") && password) {
        accounts.push({email: email.toLowerCase(), password});
      }
    }
  }
  return [...new Map(accounts.map((account) => [account.email, account])).values()];
}

function loadCredentials(file) {
  if (!file) return [];
  const resolved = path.resolve(file);
  const relative = path.relative(ROOT, resolved);
  if (!relative.startsWith(`..${path.sep}`) && !path.isAbsolute(relative)) {
    throw new Error("La guía de credenciales debe permanecer fuera del repositorio.");
  }
  if (path.extname(resolved).toLowerCase() !== ".docx") {
    throw new Error("Usa la guía privada DOCX original; no copies secretos al repositorio.");
  }
  // FileShare.ReadWrite permite lectura aun si Word está abierto, sin cerrarlo.
  const script = `$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
$stream = [IO.File]::Open($env:SMOKE_DOCX_PATH, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
$zip = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Read)
try {
  $reader = [IO.StreamReader]::new($zip.GetEntry('word/document.xml').Open())
  try { [Console]::OutputEncoding = [Text.Encoding]::UTF8; [Console]::Write($reader.ReadToEnd()) }
  finally { $reader.Dispose() }
} finally { $zip.Dispose(); $stream.Dispose() }`;
  let xml;
  try {
    xml = execFileSync("powershell.exe", ["-NoProfile", "-NonInteractive", "-EncodedCommand",
      Buffer.from(script, "utf16le").toString("base64")], {
      env: {...process.env, SMOKE_DOCX_PATH: resolved}, windowsHide: true,
      encoding: "utf8", maxBuffer: 4 * 1024 * 1024, stdio: ["ignore", "pipe", "pipe"],
    });
  } catch (error) {
    throw new Error("No se pudo leer la guía privada externa.", {cause: error});
  }
  return credentialsFromDocxXml(xml);
}

function apiKey(environment) {
  const dart = fs.readFileSync(path.join(ROOT, "lib/config/firebase_options.dart"), "utf8");
  const name = environment === "prod" ? "productionAndroid" : "android";
  const block = dart.match(new RegExp(`static const(?: FirebaseOptions)? ${name} = FirebaseOptions\\(([\\s\\S]*?)\\);`));
  const key = block?.[1].match(/apiKey:\s*'([^']+)'/);
  if (!key) throw new Error("No se encontró configuración pública Firebase.");
  return key[1];
}

function documents(body) {
  return body.filter((item) => item.document).map(({document}) => ({
    id: document.name.split("/").at(-1),
    ...decode({mapValue: {fields: document.fields || {}}}),
  }));
}

async function runSmoke(environment, accounts, output = console.log) {
  const project = PROJECTS[environment];
  if (!project) throw new Error("Proyecto no autorizado; selecciona qa o prod.");
  const report = {project, checks: [], credentialsAvailable: accounts.length, accountsTested: 0};
  const add = (check, ok, details = {}) => {
    const record = {check, ok, ...details};
    report.checks.push(record); output(JSON.stringify({project, ...record}));
  };
  const base = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
  const fnBase = `https://us-central1-${project}.cloudfunctions.net`;
  const request = async (url, body, token) => {
    const response = await fetch(url, {
      method: body === undefined ? "GET" : "POST",
      headers: {"Content-Type": "application/json", ...(token ? {Authorization: `Bearer ${token}`} : {})},
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: AbortSignal.timeout(60000),
    });
    let result;
    try {
      result = await response.json();
    } catch {
      result = {};
    }
    return {ok: response.ok, status: response.status, result};
  };
  const callable = async (name, data = {}, token) => {
    if (!READ_FUNCTIONS.has(name)) throw new Error("Operación excluida del smoke de solo lectura.");
    return request(`${fnBase}/${name}`, {data}, token);
  };
  const query = async (collectionId, filters, token) => {
    const all = filters.map(([fieldPath, op, value]) => ({fieldFilter: {
      field: {fieldPath}, op, value: encode(value),
    }}));
    return request(`${base}:runQuery`, {structuredQuery: {
      from: [{collectionId}],
      where: {compositeFilter: {op: "AND", filters: all}}, limit: 10,
    }}, token);
  };
  const checkCallable = async (label, name, data, token, denied = false) => {
    const response = await callable(name, data, token);
    const ok = denied ? response.result.error?.status === "PERMISSION_DENIED" :
      response.ok && !!response.result.result;
    add(label, ok, {http: response.status,
      ...(response.result.error ? {code: response.result.error.status} : {})});
    return response.result.result;
  };
  for (const name of READ_FUNCTIONS) {
    if (name === "obtenerOpcionesMatriculaPublica") continue;
    const response = await callable(name);
    add(`anonymous:${name}`, response.status === 401 && response.result.error?.status === "UNAUTHENTICATED",
        {http: response.status, code: response.result.error?.status});
  }
  const projection = await callable("obtenerOpcionesMatriculaPublica");
  const options = projection.result.result;
  add("anonymous:publicEnrollment", projection.ok && Array.isArray(options?.groups) &&
    Array.isArray(options?.eps) && Array.isArray(options?.documentTypes), {http: projection.status,
    groups: options?.groups?.length || 0, eps: options?.eps?.length || 0,
    documentTypes: options?.documentTypes?.length || 0});
  if (!accounts.length) return report;

  // Consulta administrativa usada solamente para confirmar que las cuentas de
  // la guía existen en este proyecto. Las pruebas usan su ID token, no IAM.
  let cloud;
  let existing;
  try {
    cloud = await cloudAccess();
    const authUsers = await cloud(`https://identitytoolkit.googleapis.com/v1/projects/${project}/accounts:batchGet?maxResults=1000`);
    if (authUsers.nextPageToken) throw new Error("Paginación de Auth requiere revisión explícita.");
    existing = new Map((authUsers.users || []).map((user) => [user.email?.toLowerCase(), user]));
  } catch {
    add("fixtureDiscovery", false, {reason: "No se pudo confirmar existencia de fixtures sin intentos de contraseña."});
    return report;
  }
  const key = apiKey(environment);
  for (let index = 0; index < accounts.length; index++) {
    const account = accounts[index];
    const target = existing.get(account.email);
    const label = `fixture${String(index + 1).padStart(2, "0")}`;
    if (!target) {
      add(`${label}:availability`, true, {skipped: "Cuenta de guía no existe en este proyecto"});
      continue;
    }
    const raw = await cloud(`${base}/users/${encodeURIComponent(target.localId)}`);
    const profile = decode({mapValue: {fields: raw.fields || {}}});
    if (profile.testFixtureId !== FIXTURE || profile.status !== "activo" || target.disabled || profile.mustChangePassword === true) {
      add(`${label}:availability`, false, {skipped: "Fixture no vigente o requiere cambio de clave"});
      continue;
    }
    const login = await request(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${key}`,
        {email: account.email, password: account.password, returnSecureToken: true});
    if (!login.ok || !login.result.idToken) {
      add(`${label}:login`, false, {http: login.status, code: "AUTH_LOGIN_FAILED"});
      continue;
    }
    const token = login.result.idToken;
    const uid = login.result.localId;
    report.accountsTested++;
    const role = profile.role;
    const prefix = `${label}:${role}`;
    add(`${prefix}:login`, true);
    const self = await request(`${base}/users/${encodeURIComponent(uid)}`, undefined, token);
    add(`${prefix}:profile`, self.ok, {http: self.status});
    const scope = [["institutionId", "EQUAL", profile.institution], ["campusId", "EQUAL", profile.campus]];
    const yearQuery = await query("academic_year_settings", scope, token);
    add(`${prefix}:academicYearIndex`, yearQuery.ok, {http: yearQuery.status, code: yearQuery.result.error?.status});
    if (!yearQuery.ok) continue;
    const year = documents(yearQuery.result)[0];
    if (!year?.activeYearId) {
      add(`${prefix}:academicYear`, false); continue;
    }
    const inYear = [...scope, ["academicYearId", "EQUAL", year.activeYearId]];
    const groups = await query("academic_groups", [...inYear, ["active", "EQUAL", true]], token);
    add(`${prefix}:groupsIndex`, groups.ok, {http: groups.status, code: groups.result.error?.status});
    const groupList = groups.ok ? documents(groups.result) : [];
    const studentId = role === "Familiar" ? profile.activeStudentId : role === "Estudiante" ? uid : undefined;
    if (role === "Familiar") {
      await checkCallable(`${prefix}:children`, "obtenerHijosVinculados", {}, token);
      if (profile.studentIds?.length) {
        const directory = await request(`${base}:runQuery`, {structuredQuery: {from: [{collectionId: "user_directory"}],
          where: {compositeFilter: {op: "AND", filters: [
            {fieldFilter: {field: {fieldPath: "__name__"}, op: "IN", value: {arrayValue: {values: profile.studentIds.slice(0, 10).map((id) => ({referenceValue: `${base.replace("https://firestore.googleapis.com/v1/", "")}/user_directory/${id}`}))}}}},
            ...[["institution", profile.institution], ["campus", profile.campus], ["status", "activo"], ["role", "Estudiante"]]
                .map(([fieldPath, value]) => ({fieldFilter: {field: {fieldPath}, op: "EQUAL", value: encode(value)}})),
          ]}}, limit: 10}}, token);
        add(`${prefix}:childrenDirectoryIndex`, directory.ok, {http: directory.status, code: directory.result.error?.status});
      }
      if (!studentId || !profile.studentIds?.includes(studentId)) {
        add(`${prefix}:studentContext`, true, {skipped: "Sin hijo activo; no se modifica contexto"});
        continue;
      }
    }
    const authorizationFilters = [...inYear];
    if (role === "Docente") authorizationFilters.push(["groupId", "EQUAL", profile.groupId || ""]);
    if (role === "Familiar" || role === "Estudiante") authorizationFilters.push(["studentId", "EQUAL", studentId]);
    const authorization = await query("authorization_requests", authorizationFilters, token);
    add(`${prefix}:authorizationsRulesAndIndex`, role === "Estudiante" ? authorization.status === 403 : authorization.ok,
        {http: authorization.status, code: authorization.result.error?.status});
    const scheduleData = role === "Docente" ? {mode: "teacher"} : role === "Administrador" ?
      {groupId: groupList[0]?.id} : studentId ? {studentId} : {};
    if (role !== "Administrador" || scheduleData.groupId) {
      await checkCallable(`${prefix}:schedules`, "consultarHorarios", scheduleData, token);
    } else add(`${prefix}:schedules`, true, {skipped: "Sin grupos vigentes"});
    await checkCallable(`${prefix}:files`, "listarArchivos", role === "Familiar" ? {activeStudentId: studentId} : {}, token);
    await checkCallable(`${prefix}:events`, "listarEventos", studentId ? {studentId} : {}, token);
    if (role === "Administrador" || role === "Docente") {
      await checkCallable(`${prefix}:attendanceContexts`, "listarContextosAsistencia", {}, token);
      await checkCallable(`${prefix}:attendanceSessions`, "listarSesionesAsistencia", {}, token);
    } else {
      await checkCallable(`${prefix}:attendance`, "consultarMiAsistencia", {studentId}, token);
    }
    await checkCallable(`${prefix}:qrRegistryReadOnly`, "listarEntidadesQr", {}, token, role !== "Administrador");
  }
  return report;
}

async function main() {
  const args = process.argv.slice(2);
  const value = (flag) => args.includes(flag) ? args[args.indexOf(flag) + 1] : undefined;
  const environment = value("--project");
  if (!PROJECTS[environment]) throw new Error("Indica --project qa o --project prod.");
  const accounts = loadCredentials(value("--credentials") || process.env.SMOKE_CREDENTIALS_PATH);
  if (!args.includes("--run")) {
    console.log(JSON.stringify({mode: "plan", project: PROJECTS[environment], credentialsFound: accounts.length,
      mutationPolicy: "Solo login Auth y lecturas; ningún cambio de datos, QR, sesiones push ni vínculo familiar"}));
    return;
  }
  const report = await runSmoke(environment, accounts);
  console.log(JSON.stringify({project: report.project, accountsTested: report.accountsTested,
    checks: report.checks.length, failures: report.checks.filter((check) => !check.ok).length}));
  if (report.checks.some((check) => !check.ok)) process.exitCode = 1;
}
if (require.main === module) {
  main().catch(() => {
    console.error("El smoke no terminó. Revisar conectividad/configuración; no se imprimen errores con datos privados.");
    process.exitCode = 1;
  });
}
module.exports = {credentialsFromDocxXml, loadCredentials, runSmoke};
