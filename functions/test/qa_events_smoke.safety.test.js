"use strict";
const assert = require("node:assert/strict");
const {requireArguments, safeCode, realAccountProjection} =
  require("../scripts/qa_events_smoke");

describe("guardas del smoke de Eventos exclusivo QA", () => {
  it("rechaza producción, proyecto ausente y argumentos no admitidos", () => {
    assert.throws(() => requireArguments([]));
    assert.throws(() => requireArguments([
      "--project=sistema-educativo-rl-prod", "--run",
    ]));
    assert.throws(() => requireArguments([
      "--project=sistema-educativo-rl", "--delete-all",
    ]), {code: "INVALID_ARGUMENTS"});
    assert.doesNotThrow(() => requireArguments([
      "--project=sistema-educativo-rl",
    ]));
  });

  it("solo permite códigos conocidos, nunca mensajes ni credenciales", () => {
    assert.equal(safeCode({code: "PERMISSION_DENIED"}), "PERMISSION_DENIED");
    assert.equal(safeCode({code: "cualquier-secreto-opaco"}),
        "UNEXPECTED_ERROR");
    assert.equal(safeCode({message: "email password idToken"}),
        "UNEXPECTED_ERROR");
    assert.equal(safeCode({name: "AssertionError", actual: "secreto"}),
        "CHECK_FAILED");
  });

  it("compara perfiles sin correo, contraseña ni tokens", () => {
    const value = realAccountProjection({role: "Estudiante", permissions: [],
      institutionalEmail: "private@example.com", password: "secret",
      notificationTokens: {mobile: "token"}}, {disabled: false,
      email: "private@example.com", passwordHash: "hash"});
    assert.equal(value.role, "Estudiante");
    assert.ok(!JSON.stringify(value).includes("private@example.com"));
    assert.ok(!JSON.stringify(value).includes("secret"));
    assert.ok(!JSON.stringify(value).includes("\"token\""));
    assert.ok(!JSON.stringify(value).includes("\"hash\""));
  });
});
