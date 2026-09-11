"use strict";

const assert = require("assert");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

const projectId = "sistema-educativo-website-test";
const functionsPort = process.env.RELEASE_FUNCTIONS_PORT || "5002";
const functionsBase = `http://127.0.0.1:${functionsPort}/${projectId}/us-central1`;
let app;
let db;

async function clearFirestore() {
  const response = await fetch(
      `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/` +
      `${projectId}/databases/(default)/documents`,
      {method: "DELETE"},
  );
  assert.ok(response.ok);
}

async function submit(data) {
  const response = await fetch(`${functionsBase}/submitWebsiteForm`, {
    method: "POST",
    headers: {"content-type": "application/json"},
    body: JSON.stringify({data}),
  });
  return {status: response.status, body: await response.json()};
}

const formData = {
  pageId: "contacto",
  blockId: "formulario",
  name: "Familia Prueba",
  email: "familia@example.test",
  phone: "3000000000",
  message: "Deseo recibir información del colegio.",
};

async function seedPage(extra = {}) {
  await db.collection("website_pages").doc("contacto").set({
    institutionId: "inst-1",
    campusId: "campus-1",
    enabled: true,
    rows: [{
      id: "fila",
      columns: [{
        id: "columna",
        components: [{
          id: "formulario",
          type: "contactForm",
          enabled: true,
        }],
      }],
    }],
    ...extra,
  });
}

describe("formulario público del sitio", () => {
  before(() => {
    app = initializeApp({projectId}, "website-function-tests");
    db = getFirestore(app);
  });

  beforeEach(clearFirestore);

  after(async () => deleteApp(app));

  it("acepta el componente vigente y conserva institución y sede", async () => {
    await seedPage();
    const response = await submit(formData);
    assert.equal(response.status, 200, JSON.stringify(response.body));
    assert.equal(response.body.result.success, true);
    const saved = await db.collection("website_submissions").get();
    assert.equal(saved.size, 1);
    assert.equal(saved.docs[0].data().institutionId, "inst-1");
    assert.equal(saved.docs[0].data().campusId, "campus-1");
  });

  it("rechaza páginas desactivadas", async () => {
    await seedPage({enabled: false});
    const response = await submit(formData);
    assert.equal(response.body.error.status, "FAILED_PRECONDITION");
  });

  it("no acepta la estructura antigua sin alcance institucional", async () => {
    await db.collection("website_pages").doc("contacto").set({
      enabled: true,
      blocks: [{id: "formulario", type: "contactForm", enabled: true}],
    });
    const response = await submit(formData);
    assert.equal(response.body.error.status, "FAILED_PRECONDITION");
  });
});
