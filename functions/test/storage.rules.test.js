"use strict";
/* eslint-env mocha */

const fs = require("fs");
const path = require("path");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {doc, setDoc} = require("firebase/firestore");

const projectId = "sistema-educativo-rl";
let env;

const activeUser = (extra = {}) => ({
  role: "Administrador",
  status: "activo",
  institution: "inst-1",
  campus: "campus-1",
  isSuperadmin: false,
  permissions: [],
  ...extra,
});

describe("Reglas Storage del sitio web", () => {
  before(async () => {
    env = await initializeTestEnvironment({
      projectId,
      firestore: {host: "127.0.0.1", port: 8080},
      storage: {
        host: "127.0.0.1",
        port: 9199,
        rules: fs.readFileSync(
            path.resolve(__dirname, "../../storage.rules"),
            "utf8",
        ),
      },
    });
  });

  beforeEach(async () => {
    await env.clearFirestore();
    await env.clearStorage();
    await env.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "users/superadmin"), activeUser({
        isSuperadmin: true,
      }));
      await setDoc(doc(db, "users/editor"), activeUser({
        permissions: ["sitio_web.editar"],
      }));
      await setDoc(doc(db, "users/admin"), activeUser());
    });
  });

  after(async () => env.cleanup());

  const upload = (userId, name, contentType) => {
    const storage = env.authenticatedContext(userId).storage(
        `gs://${projectId}.firebasestorage.app`,
    );
    return storage.ref(`website/${name}`).put(
        Buffer.from("imagen de prueba"),
        {contentType},
    );
  };

  it("permite PNG y JPEG a un superadministrador", async () => {
    await assertSucceeds(upload("superadmin", "imagen.png", "image/png"));
    await assertSucceeds(upload("superadmin", "imagen.jpeg", "image/jpeg"));
  });

  it("permite JPEG al usuario con sitio_web.editar", async () => {
    await assertSucceeds(upload("editor", "banner.jpeg", "image/jpeg"));
  });

  it("rechaza la carga a quien no administra el sitio", async () => {
    await assertFails(upload("admin", "rechazado.png", "image/png"));
  });
});
