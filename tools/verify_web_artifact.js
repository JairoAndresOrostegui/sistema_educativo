"use strict";
const fs = require("node:fs");
const path = require("node:path");

function verifyWebArtifact(directory, environment) {
  if (!["qa", "prod"].includes(environment)) throw new Error("Invalid web environment");
  const required = ["index.html", "flutter.js", "flutter_bootstrap.js", "main.dart.js",
    "version.json", "environment.json", "manifest.json", "favicon.png",
    "firebase-runtime.js", "firebase-messaging-sw.js", "assets/FontManifest.json",
    "assets/AssetManifest.bin", "assets/AssetManifest.bin.json"];
  for (const name of required) {
    const file = path.join(directory, name);
    if (!fs.existsSync(file) || !fs.statSync(file).isFile() || fs.statSync(file).size === 0) {
      throw new Error(`Incomplete ${environment} web artifact: ${name}`);
    }
  }
  const json = (name) => JSON.parse(fs.readFileSync(path.join(directory, name), "utf8"));
  const marker = json("environment.json");
  const project = environment === "prod" ? "sistema-educativo-rl-prod" : "sistema-educativo-rl";
  if (marker.environment !== environment || marker.projectId !== project) {
    throw new Error("Web artifact environment mismatch");
  }
  const runtime = fs.readFileSync(path.join(directory, "firebase-runtime.js"), "utf8");
  const runtimeProject = runtime.match(/["']?projectId["']?\s*:\s*["']([^"']+)["']/)?.[1];
  if (runtimeProject !== project) {
    throw new Error("Web worker Firebase project mismatch");
  }
  const fonts = json("assets/FontManifest.json");
  if (!Array.isArray(fonts) || fonts.length === 0) throw new Error("Invalid font manifest");
  for (const family of fonts) for (const font of family.fonts || []) {
    if (typeof font.asset !== "string" || font.asset.includes("..") ||
      !fs.existsSync(path.join(directory, "assets", font.asset))) {
      throw new Error("Web artifact references a missing font");
    }
  }
  json("version.json"); json("manifest.json"); json("assets/AssetManifest.bin.json");
  return {environment, projectId: project, verified: true};
}
if (require.main === module) {
  const environment = process.argv[2];
  const directory = path.resolve(__dirname, `../build/web-${environment}`);
  const result = verifyWebArtifact(directory, environment);
  if (process.env.GCLOUD_PROJECT && process.env.GCLOUD_PROJECT !== result.projectId) {
    throw new Error("Hosting target project does not match the web artifact");
  }
  console.log(JSON.stringify(result));
}
module.exports = {verifyWebArtifact};
