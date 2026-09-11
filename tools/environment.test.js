"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const root = path.resolve(__dirname, "..");
const dart = fs.readFileSync(path.join(root, "lib/config/firebase_options.dart"), "utf8");
for (const env of ["qa", "prod"]) {
  test(`${env}: native SDK identifiers agree with Flutter`, () => {
    const sdk = JSON.parse(fs.readFileSync(path.join(root,
        `android/app/src/${env}/google-services.json`), "utf8"));
    const client = sdk.client[0];
    assert.ok(dart.includes(client.client_info.mobilesdk_app_id));
    assert.ok(dart.includes(client.api_key[0].current_key));
    assert.equal(sdk.project_info.project_id,
        env === "prod" ? "sistema-educativo-rl-prod" : "sistema-educativo-rl");
  });
}
test("QA worker rejects production origins", () => {
  const code = fs.readFileSync(path.join(root, "web/firebase-runtime.js"), "utf8");
  for (const hostname of ["liceobilinguerodolfollinas.edu.co",
    "www.liceobilinguerodolfollinas.edu.co", "sistema-educativo-rl-prod.web.app"]) {
    assert.throws(() => vm.runInNewContext(code, {self: {location: {hostname}}}));
  }
  const self = {location: {hostname: "sistema-educativo-rl.web.app"}};
  vm.runInNewContext(code, {self});
  assert.equal(self.firebaseRuntime.projectId, "sistema-educativo-rl");
  assert.ok(dart.includes(self.firebaseRuntime.apiKey));
  assert.ok(dart.includes(self.firebaseRuntime.appId));
});
