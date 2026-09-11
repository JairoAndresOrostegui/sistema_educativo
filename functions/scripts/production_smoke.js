"use strict";
/* eslint-disable max-len */
const {TARGET} = require("./production_readiness");
async function main() {
  const functions = ["consultarHorarios", "listarArchivos", "listarEntidadesQr", "consultarHistorialRuta", "listarAniosLectivos"];
  for (const name of functions) {
    const response = await fetch(`https://us-central1-${TARGET}.cloudfunctions.net/${name}`, {
      method: "POST", headers: {"Content-Type": "application/json"}, body: JSON.stringify({data: {}}),
    });
    const body = await response.json();
    if (response.status !== 401 || body.error?.status !== "UNAUTHENTICATED") throw new Error(`Unexpected unauthenticated response: ${name} HTTP ${response.status}`);
    console.log(JSON.stringify({function: name, rejectsUnauthenticated: true}));
  }
}
main().catch((e) => {
  console.error(e.message); process.exitCode = 1;
});
