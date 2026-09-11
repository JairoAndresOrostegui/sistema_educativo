"use strict";

const fs = require("node:fs");
const {createRequire} = require("node:module");
const os = require("node:os");
const path = require("node:path");
const requireFunctions = createRequire(path.resolve(
    __dirname, "../functions/package.json",
));
const {GoogleAuth} = requireFunctions("google-auth-library");

const PACKAGE_NAME = "com.desarrolloytecnologiasantander.serodolfollinas";
const DEFAULT_TRACK = "alpha";
const DEFAULT_CREDENTIALS = path.join(
    os.homedir(), ".config", "sistema_educativo", "play-publisher.json",
);

async function jsonRequest(url, token, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: {
      authorization: `Bearer ${token}`,
      ...(options.body && !(options.body instanceof Uint8Array) ?
        {"content-type": "application/json"} : {}),
      ...(options.headers || {}),
    },
  });
  const text = await response.text();
  const payload = text ? JSON.parse(text) : {};
  if (!response.ok) {
    throw new Error(
        `Google Play API ${response.status}: ${payload.error?.message || text}`,
    );
  }
  return payload;
}

async function main() {
  const statusOnly = process.argv.includes("--status");
  if (!process.argv.includes("--apply") && !statusOnly) {
    throw new Error("Usa --status para consultar o --apply --version=N para enviar a prueba cerrada.");
  }
  const bundleArg = process.argv.find((item) => item.startsWith("--bundle="));
  const trackArg = process.argv.find((item) => item.startsWith("--track="));
  const bundlePath = path.resolve(bundleArg?.slice(9) || path.join(
      "build", "app", "outputs", "bundle", "prodRelease",
      "app-prod-release.aab",
  ));
  const track = trackArg?.slice(8) || DEFAULT_TRACK;
  if (track !== DEFAULT_TRACK) throw new Error("Solo está autorizada la prueba cerrada alpha.");
  const expectedVersion = Number(process.argv.find((item) =>
    item.startsWith("--version="))?.slice(10));
  if (!statusOnly && (!Number.isSafeInteger(expectedVersion) || expectedVersion < 1)) {
    throw new Error("Indica --version=N con el código del AAB verificado.");
  }
  const credentialsPath = process.env.PLAY_PUBLISHER_CREDENTIALS ||
    DEFAULT_CREDENTIALS;
  if (!statusOnly && !fs.existsSync(bundlePath)) throw new Error("No se encontro el AAB.");
  if (!fs.existsSync(credentialsPath)) {
    throw new Error("No se encontraron las credenciales de Google Play.");
  }

  const auth = new GoogleAuth({
    keyFile: credentialsPath,
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
  const token = await auth.getAccessToken();
  if (!token) throw new Error("No fue posible autenticar Google Play.");
  const base = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE_NAME}`;
  const edit = await jsonRequest(`${base}/edits`, token, {
    method: "POST", body: JSON.stringify({}),
  });
  try {
    const current = await jsonRequest(`${base}/edits/${edit.id}/tracks`, token);
    const bundles = await jsonRequest(`${base}/edits/${edit.id}/bundles`, token);
    if (statusOnly) {
      console.log(JSON.stringify({packageName: PACKAGE_NAME,
        tracks: current.tracks, versionCodes: (bundles.bundles || [])
            .map((item) => item.versionCode)}, null, 2));
      await jsonRequest(`${base}/edits/${edit.id}`, token, {method: "DELETE"});
      return;
    }
    const highest = Math.max(0, ...(bundles.bundles || []).map((item) => Number(item.versionCode)));
    if (expectedVersion <= highest) {
      throw new Error(`El código ${expectedVersion} ya está usado o es anterior al ${highest}.`);
    }
    const bytes = new Uint8Array(fs.readFileSync(bundlePath));
    const bundle = await jsonRequest(
        `https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/${PACKAGE_NAME}/edits/${edit.id}/bundles?uploadType=media`,
        token,
        {method: "POST", body: bytes, headers: {"content-type": "application/octet-stream"}},
    );
    if (Number(bundle.versionCode) !== expectedVersion) {
      throw new Error(`El AAB tiene versionCode inesperado: ${bundle.versionCode}`);
    }
    await jsonRequest(`${base}/edits/${edit.id}/tracks/${track}`, token, {
      method: "PUT",
      body: JSON.stringify({
        track,
        releases: [{
          name: `2026-09-CB-v1.0.0 (${expectedVersion})`,
          versionCodes: [String(bundle.versionCode)],
          status: "completed",
          releaseNotes: [{
            language: "es-419",
            text: "Correcciones de acceso para familiares, autorizaciones y perfiles. Mejoras de seguridad en archivos y mensajes. Revisión de rutas, horarios, matrículas, asistencia y eventos.",
          }],
        }],
      }),
    });
    await jsonRequest(`${base}/edits/${edit.id}:validate`, token, {
      method: "POST", body: JSON.stringify({}),
    });
    await jsonRequest(`${base}/edits/${edit.id}:commit`, token, {
      method: "POST", body: JSON.stringify({}),
    });
    console.log(JSON.stringify({
      submitted: true,
      packageName: PACKAGE_NAME,
      track,
      versionCode: bundle.versionCode,
    }));
  } catch (error) {
    await jsonRequest(`${base}/edits/${edit.id}`, token, {method: "DELETE"})
        .catch(() => {});
    throw error;
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
