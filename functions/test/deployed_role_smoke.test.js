"use strict";
/* eslint-disable max-len */
const assert = require("assert");
const path = require("path");
const {credentialsFromDocxXml, loadCredentials, runSmoke} = require("../scripts/deployed_role_smoke");
const row = (values) => `<w:tr>${values.map((value) => `<w:tc><w:p><w:r><w:t>${value}</w:t></w:r></w:p></w:tc>`).join("")}</w:tr>`;

describe("smoke desplegado sin secretos ni mutaciones", () => {
  it("extrae solo fixtures de tablas y conserva caracteres escapados", () => {
    const email = "playtest.admin01@desarrolloytecnologiasantander.com";
    const xml = `<w:document><w:tbl>${row(["Nombre", "Correo", "Contraseña", "Rol"])}${row(["Prueba", email, "Clave&amp;ficticia&lt;1&gt;", "Administrador"])}${row(["Real", "persona@example.invalid", "NoLeer", "Administrador"])}</w:tbl></w:document>`;
    assert.deepEqual(credentialsFromDocxXml(xml), [{email, password: "Clave&ficticia<1>"}]);
  });
  it("sin guía no carga credenciales y rechaza archivos dentro del repo", () => {
    assert.deepEqual(loadCredentials(), []);
    assert.throws(() => loadCredentials(path.resolve(__dirname, "fake.docx")), /fuera del repositorio/);
  });
  it("no admite un proyecto arbitrario ni siquiera sin cuentas", async () => {
    await assert.rejects(runSmoke("otro-proyecto", [], () => {}), /Proyecto no autorizado/);
  });
});
