"use strict";
/* eslint-disable max-len */
const {cloudAccess} = require("./cloud_access");
const {spawnSync} = require("node:child_process");
const path = require("node:path");
const PROJECT = "325430927285";
const SERVICE = "maps-android-backend.googleapis.com";
const KEY = `projects/${PROJECT}/locations/global/keys/production-android-maps`;
const PACKAGE = "com.desarrolloytecnologiasantander.serodolfollinas";
const fingerprints = ["b8fb1630fef7c084b3c7b5768914d65ff0ecc8eb", "53cd8d361241b13cf2a229cbbca1eff92679246a"];
const restrictions = {androidKeyRestrictions: {allowedApplications:
  fingerprints.map((sha1Fingerprint) => ({sha1Fingerprint, packageName: PACKAGE}))},
apiTargets: [{service: SERVICE}]};
async function main() {
  const request = await cloudAccess();
  async function wait(operation, origin) {
    for (let i = 0; i < 45; i++) {
      if (operation.done) {
        if (operation.error) throw new Error(`Cloud operation failed: ${operation.error.code}`);
        return;
      }
      await new Promise((resolve) => setTimeout(resolve, 1000));
      operation = await request(`${origin}/v1/${operation.name}`);
    }
    throw new Error("Cloud operation pending; rerun to inspect state");
  }
  const serviceUrl = `https://serviceusage.googleapis.com/v1/projects/${PROJECT}/services/${SERVICE}`;
  let service = await request(serviceUrl);
  if (service.state !== "ENABLED" && process.argv.includes("--apply")) {
    await wait(await request(`${serviceUrl}:enable`, "POST", {}), "https://serviceusage.googleapis.com");
    service = await request(serviceUrl);
  }
  let key;
  try {
    key = await request(`https://apikeys.googleapis.com/v2/${KEY}`);
  } catch (error) {
    if (error.status !== 404 || !process.argv.includes("--apply")) throw error;
    const operation = await request(`https://apikeys.googleapis.com/v2/projects/${PROJECT}/locations/global/keys?keyId=production-android-maps`, "POST", {
      displayName: "Production Android Maps (Play and signed APK)", restrictions,
    });
    // API Keys long-running operations use the v2 endpoint.
    for (let i = 0; i < 45; i++) {
      const status = await request(`https://apikeys.googleapis.com/v2/${operation.name}`);
      if (status.done) {
        if (status.error) throw new Error(`Key creation failed: ${status.error.code}`, {cause: error});
        break;
      }
      await new Promise((resolve) => setTimeout(resolve, 1000));
    }
    key = await request(`https://apikeys.googleapis.com/v2/${KEY}`);
  }
  const actual = key.restrictions;
  const apps = actual?.androidKeyRestrictions?.allowedApplications || [];
  if (service.state !== "ENABLED" || actual?.apiTargets?.length !== 1 ||
    actual.apiTargets[0].service !== SERVICE || apps.length !== 2 ||
    apps.some((app) => app.packageName !== PACKAGE || !fingerprints.includes(app.sha1Fingerprint.toLowerCase().replaceAll(":", "")))) {
    throw new Error("Unexpected Maps restrictions; do not build");
  }
  console.log(JSON.stringify({mapsSdkEnabled: true, restrictedToPackage: PACKAGE, certificates: apps.length, routesAutomaticUnchanged: true}));
  if (process.argv.includes("--build")) {
    const versionArgument = process.argv.find((item) => item.startsWith("--build-number="));
    const buildNumber = versionArgument?.split("=")[1];
    if (!/^[1-9][0-9]*$/.test(buildNumber || "")) {
      throw new Error("Indica --build-number=<codigo de version> para compilar.");
    }
    const value = await request(`https://apikeys.googleapis.com/v2/${KEY}/keyString`);
    if (!/^AIza[\w-]+$/.test(value.keyString || "")) throw new Error("Invalid Maps key response");
    const root = path.resolve(__dirname, "../..");
    for (const kind of process.argv.includes("--bundle-only") ? ["appbundle"] : ["apk", "appbundle"]) {
      const result = spawnSync(process.platform === "win32" ? "flutter.bat" : "flutter",
          ["build", kind, "--flavor", "prod", "--release", "--dart-define=APP_ENV=prod", `--build-number=${buildNumber}`], {
            cwd: root, stdio: "inherit", windowsHide: true, shell: process.platform === "win32",
            env: {...process.env, ORG_GRADLE_PROJECT_PROD_MAPS_API_KEY: value.keyString},
          });
      if (result.error || result.status !== 0) throw new Error(`Production ${kind} build failed`);
    }
  }
}
main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
