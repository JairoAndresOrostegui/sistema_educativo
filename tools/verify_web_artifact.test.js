"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const {verifyWebArtifact} = require("./verify_web_artifact");

function fixture(t) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "web-artifact-test-"));
  t.after(() => fs.rmSync(directory, {recursive: true, force: true}));
  const files = {"index.html": "<html></html>", "flutter.js": "js", "flutter_bootstrap.js": "js",
    "main.dart.js": "js", "version.json": "{}", "manifest.json": "{}", "favicon.png": "png",
    "environment.json": JSON.stringify({environment: "qa", projectId: "sistema-educativo-rl"}),
    "firebase-runtime.js": "self.firebaseRuntime={projectId:'sistema-educativo-rl'};",
    "firebase-messaging-sw.js": "js", "assets/FontManifest.json": '[{"fonts":[{"asset":"font.ttf"}]}]',
    "assets/AssetManifest.bin": "binary", "assets/AssetManifest.bin.json": '"base64"',
    "assets/font.ttf": "font"};
  for (const [name, content] of Object.entries(files)) {
    fs.mkdirSync(path.dirname(path.join(directory, name)), {recursive: true});
    fs.writeFileSync(path.join(directory, name), content);
  }
  return directory;
}
test("validates a complete isolated web artifact", (t) => {
  assert.equal(verifyWebArtifact(fixture(t), "qa").verified, true);
});
test("rejects the incomplete staging directory before deployment", (t) => {
  const dir = fixture(t);
  fs.unlinkSync(path.join(dir, "assets/FontManifest.json"));
  assert.throws(() => verifyWebArtifact(dir, "qa"), /Incomplete.*FontManifest/);
});
test("rejects missing push workers and mismatched environments", (t) => {
  const dir = fixture(t);
  assert.throws(() => verifyWebArtifact(dir, "prod"), /environment mismatch/);
  fs.unlinkSync(path.join(dir, "firebase-messaging-sw.js"));
  assert.throws(() => verifyWebArtifact(dir, "qa"), /Incomplete.*firebase-messaging/);
});
