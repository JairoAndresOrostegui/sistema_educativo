"use strict";

const assert = require("assert");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

const projectId = "sistema-educativo-auth-test";
const endpoint = `http://127.0.0.1:5002/${projectId}/us-central1/` +
  "resolverLoginPorDocumento";
let app;
let db;

async function clearFirestore() {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  assert.ok(host, "La prueba debe ejecutarse con el emulador Firestore.");
  const response = await fetch(
      `http://${host}/emulator/v1/projects/${projectId}/databases/` +
      "(default)/documents",
      {method: "DELETE"},
  );
  assert.ok(response.ok, `No se pudo limpiar Firestore: ${response.status}`);
}

async function callResolver(documento) {
  const response = await fetch(endpoint, {
    method: "POST",
    headers: {"content-type": "application/json"},
    body: JSON.stringify({data: {documento}}),
  });
  return {status: response.status, body: await response.json()};
}

async function seedUser(id, data) {
  await db.collection("users").doc(id).set({
    institutionalEmail: `${id}@estudiantes.colegio.test`,
    role: "Estudiante",
    status: "activo",
    ...data,
  });
}

describe("resolverLoginPorDocumento", () => {
  before(() => {
    app = initializeApp({projectId}, "auth-function-tests");
    db = getFirestore(app);
  });

  beforeEach(async () => {
    await clearFirestore();
  });

  after(async () => {
    await deleteApp(app);
  });

  it("resuelve el correo ficticio de un estudiante activo", async () => {
    await seedUser("student-active", {
      document: "10000001",
      institutionalEmail: "ESTUDIANTE@COLEGIO.TEST",
    });

    const response = await callResolver("10000001");
    assert.equal(response.status, 200);
    assert.deepEqual(response.body.result, {
      email: "estudiante@colegio.test",
    });
  });

  it("no permite resolver el documento de un adulto", async () => {
    await seedUser("teacher", {
      document: "20000001",
      role: "Docente",
      institutionalEmail: "docente@colegio.test",
    });

    const response = await callResolver("20000001");
    assert.equal(response.body.error.status, "PERMISSION_DENIED");
    assert.equal(
        response.body.error.message,
        "No fue posible validar las credenciales.",
    );
  });

  it("no distingue entre estudiante inactivo e inexistente", async () => {
    await seedUser("student-inactive", {
      document: "30000001",
      status: "inactivo",
    });

    const inactive = await callResolver("30000001");
    await clearFirestore();
    const missing = await callResolver("99999999");
    assert.equal(inactive.body.error.status, "PERMISSION_DENIED");
    assert.equal(missing.body.error.status, "PERMISSION_DENIED");
    assert.equal(inactive.body.error.message, missing.body.error.message);
  });

  it("limita a diez intentos por minuto desde una misma IP", async () => {
    await seedUser("student-rate", {document: "40000001"});

    for (let attempt = 0; attempt < 10; attempt += 1) {
      const response = await callResolver("40000001");
      assert.ok(
          response.body.result,
          `Fallo anticipado en intento ${attempt + 1}`,
      );
    }
    const blocked = await callResolver("40000001");
    assert.equal(blocked.body.error.status, "RESOURCE_EXHAUSTED");
  });
});
