"use strict";
// Publish only a verified build. A fresh temporary checkout preserves history.
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const {execFileSync, spawnSync} = require("node:child_process");
require("./verify_production_web");
const root = path.resolve(__dirname, "..");
// actions/checkout credentials are local to its checkout. Pass them in memory
// to the temporary repository, never embed them in its remote or files.
const credential = spawnSync("git", ["config", "--get",
  "http.https://github.com/.extraheader"], {cwd: root, encoding: "utf8"});
const gitEnv = credential.status === 0 ? {...process.env,
  GIT_CONFIG_COUNT: "1", GIT_CONFIG_KEY_0: "http.https://github.com/.extraheader",
  GIT_CONFIG_VALUE_0: credential.stdout.trim(),
} : process.env;
const git = (args, cwd = root) => execFileSync("git", args,
    {cwd, encoding: "utf8", env: gitEnv}).trim();
const remote = git(["remote", "get-url", "origin"]);
if (!/^https:\/\/github\.com\/JairoAndresOrostegui\/sistema_educativo(?:\.git)?$/.test(remote)) {
  throw new Error("Unexpected production repository");
}
const revision = git(["rev-parse", "HEAD"]);
const folder = fs.mkdtempSync(path.join(os.tmpdir(), "llinas-production-web-"));
git(["init", "--initial-branch=production-web", folder]);
git(["remote", "add", "origin", remote], folder);
git(["fetch", "origin", "production-web"], folder);
git(["reset", "--mixed", "FETCH_HEAD"], folder);
fs.cpSync(path.join(root, "build/web-prod"), folder, {recursive: true});
fs.copyFileSync(path.join(__dirname, "hostinger.htaccess"), path.join(folder, ".htaccess"));
fs.writeFileSync(path.join(folder, "release.json"), JSON.stringify({
  sourceCommit: revision, environment: "prod", builtAt: new Date().toISOString(),
}));
git(["config", "user.name", "Llinas Web Deployment"], folder);
git(["config", "user.email", "deploy@liceobilinguerodolfollinas.edu.co"], folder);
git(["add", "--all"], folder);
git(["commit", "-m", `Deploy production web ${revision}`], folder);
git(["push", "origin", "HEAD:refs/heads/production-web"], folder);
console.log(`Published ${git(["rev-parse", "HEAD"], folder)}; recovery copy: ${folder}`);
