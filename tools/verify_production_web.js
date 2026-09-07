"use strict";
const fs = require("node:fs");
const path = require("node:path");
const root = path.resolve(__dirname, "../build/web-prod");
const index = fs.readFileSync(path.join(root, "index.html"), "utf8");
const entry = index.match(/src="(flutter_bootstrap\.[a-f0-9]{20}\.js)"/);
if (!entry) throw new Error("Production requires a content-versioned bootstrap");
const bootstrap = fs.readFileSync(path.join(root, entry[1]), "utf8");
const main = bootstrap.match(/"mainJsPath":"(main\.dart\.[a-f0-9]{20}\.js)"/);
if (!main || !fs.existsSync(path.join(root, main[1]))) {
  throw new Error("Production requires a content-versioned application");
}
const marker = JSON.parse(fs.readFileSync(path.join(root, "environment.json"), "utf8"));
if (marker.environment !== "prod" || marker.projectId !== "sistema-educativo-rl-prod") {
  throw new Error("Not a production build");
}
const worker = fs.readFileSync(path.join(root, "firebase-runtime.js"), "utf8");
if (!worker.includes('"projectId": "sistema-educativo-rl-prod"') ||
    worker.includes("732639994966")) {
  throw new Error("Production worker contains an incorrect Firebase configuration");
}
if (process.env.GCLOUD_PROJECT && process.env.GCLOUD_PROJECT !== marker.projectId) {
  throw new Error("Firebase deploy target is not production");
}
console.log("Production web environment verified.");
