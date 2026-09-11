"use strict";
// Additive, bounded releases: Firebase recommends groups of at most 10.
const fs = require("node:fs");
const path = require("node:path");
const {spawn} = require("node:child_process");

async function main() {
  const project = process.argv.find((arg) => arg.startsWith("--project="))?.slice(10);
  if (!["sistema-educativo-rl", "sistema-educativo-rl-prod"].includes(project)) {
    throw new Error("Specify an allowlisted --project");
  }
  process.env.GCLOUD_PROJECT = project;
  const available = Object.keys(require("../functions/index.js"));
  const selected = process.argv.find((arg) => arg.startsWith("--functions="))?.slice(12);
  const names = selected ? [...new Set(selected.split(","))] : available;
  if (!names.length || names.some((name) => !available.includes(name) || !/^[a-zA-Z0-9_]+$/.test(name))) {
    throw new Error("Only explicitly defined local functions can be deployed");
  }
  const batches = [];
  for (let i = 0; i < names.length; i += 8) batches.push(names.slice(i, i + 8));
  console.log(JSON.stringify({project, functions: names.length, batches}));
  if (!process.argv.includes("--apply")) return;
  const root = path.resolve(__dirname, "..");
  const cli = path.join(process.env.APPDATA, "npm/node_modules/firebase-tools/lib/bin/firebase.js");
  if (!fs.existsSync(cli)) throw new Error("Firebase CLI entry point not found");
  const directory = path.join(root, ".buildlog");
  fs.mkdirSync(directory, {recursive: true});
  for (let i = 0; i < batches.length; i++) {
    const batch = batches[i];
    let succeeded = false;
    for (let attempt = 1; attempt <= 2; attempt++) {
      const file = path.join(directory, `${project}-functions-batch-${i + 1}-${attempt}.log`);
      const log = fs.createWriteStream(file);
      const child = spawn(process.execPath, [cli, "deploy", "--project", project,
        "--only", batch.map((name) => `functions:${name}`).join(","),
        "--non-interactive", "--force"], {cwd: root, windowsHide: true,
        stdio: ["ignore", "pipe", "pipe"]});
      child.stdout.pipe(log, {end: false});
      child.stderr.pipe(log, {end: false});
      const code = await new Promise((resolve, reject) => {
        child.on("error", reject); child.on("close", resolve);
      });
      await new Promise((resolve) => log.end(resolve));
      console.log(JSON.stringify({project, batch: i + 1, of: batches.length, attempt, exitCode: code, functions: batch}));
      if (code === 0) { succeeded = true; break; }
      const quota = /quota exceeded|RESOURCE_EXHAUSTED|HTTP Error: 429/i.test(fs.readFileSync(file, "utf8"));
      if (!quota || attempt === 2) throw new Error(`Batch ${i + 1} failed; see ${file}`);
      // Async pause; the calling terminal remains yieldable for progress updates.
      await new Promise((resolve) => setTimeout(resolve, 60000));
    }
    if (!succeeded) throw new Error(`Batch ${i + 1} incomplete`);
  }
  console.log(JSON.stringify({project, completed: true, functions: names.length}));
}
main().catch((error) => {console.error(error.message); process.exitCode = 1;});
