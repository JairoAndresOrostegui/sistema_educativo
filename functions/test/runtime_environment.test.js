"use strict";
const assert = require("assert");
const {runtimeEnvironment} = require("../runtime_environment");

describe("Runtime environment isolation", () => {
  it("keeps QA and production auth keys and links separate", () => {
    const qa = runtimeEnvironment({GCLOUD_PROJECT: "sistema-educativo-rl"});
    const prod = runtimeEnvironment({
      GCLOUD_PROJECT: "sistema-educativo-rl-prod",
    });
    assert.notEqual(qa.authWebApiKey, prod.authWebApiKey);
    assert.equal(prod.publicAppUrl, "https://liceobilinguerodolfollinas.edu.co");
    assert.equal(prod.verificationContinueUrl,
        "https://liceobilinguerodolfollinas.edu.co/#/login");
  });
  it("rejects unknown projects instead of falling back to QA", () => {
    assert.throws(() => runtimeEnvironment({GCLOUD_PROJECT: "unknown"}));
  });
  it("rejects a production link override to QA", () => {
    assert.throws(() => runtimeEnvironment({
      GCLOUD_PROJECT: "sistema-educativo-rl-prod",
      PUBLIC_APP_URL: "https://sistema-educativo-rl.web.app",
    }));
  });
  it("uses local-only configuration in emulators", () => {
    const config = runtimeEnvironment({FUNCTIONS_EMULATOR: "true"});
    assert.equal(config.authWebApiKey, "emulator-only");
    assert.equal(config.publicAppUrl, "http://localhost:5000");
  });
});
