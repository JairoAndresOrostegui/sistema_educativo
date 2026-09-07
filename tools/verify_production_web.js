"use strict";
const fs = require("node:fs");
const path = require("node:path");
const root = path.resolve(__dirname, "../build/web-prod");
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
