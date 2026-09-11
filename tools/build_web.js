"use strict";
// Build output only; source QA configuration is never overwritten.
const {spawnSync} = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");
const environment = process.argv[2];
if (!["qa", "prod"].includes(environment)) {
  throw new Error("Usage: node tools/build_web.js qa|prod");
}
if (environment === "prod" && !process.env.WEB_VAPID_KEY) {
  throw new Error("Set production WEB_VAPID_KEY before building production web.");
}
const root = path.resolve(__dirname, "..");
const output = environment === "prod" ? "build/web-prod" : "build/web";
const args = ["build", "web", "--release", `--output=${output}`,
  `--dart-define=APP_ENV=${environment}`];
if (process.env.WEB_VAPID_KEY) {
  if (!/^[A-Za-z0-9_-]+$/.test(process.env.WEB_VAPID_KEY)) {
    throw new Error("Invalid public VAPID key format");
  }
  args.push(`--dart-define=WEB_VAPID_KEY=${process.env.WEB_VAPID_KEY}`);
}
const result = spawnSync(process.platform === "win32" ? "flutter.bat" : "flutter",
    args, {cwd: root, stdio: "inherit", windowsHide: true,
      shell: process.platform === "win32"});
if (result.error || result.status !== 0) {
  throw new Error("Flutter build failed; do not deploy this output.");
}
if (environment === "prod") {
  const config = {
    apiKey: "AIzaSyBXPXXueD4pGhrM7TK9hLTuYQ2LLpsF-5Q",
    appId: "1:325430927285:web:4825f7f65a75fd6ee103fc",
    messagingSenderId: "325430927285", projectId: "sistema-educativo-rl-prod",
    authDomain: "sistema-educativo-rl-prod.firebaseapp.com",
    storageBucket: "sistema-educativo-rl-prod.firebasestorage.app",
  };
  fs.writeFileSync(path.join(root, output, "firebase-runtime.js"),
      `self.firebaseRuntime = ${JSON.stringify(config, null, 2)};\n`);
  require("./version_web_assets").versionWebAssets(path.join(root, output));
}
fs.writeFileSync(path.join(root, output, "environment.json"),
    JSON.stringify({environment, projectId: environment === "prod" ?
      "sistema-educativo-rl-prod" : "sistema-educativo-rl"}));
