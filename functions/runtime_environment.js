"use strict";

const CONFIG = Object.freeze({
  "sistema-educativo-rl": {
    authWebApiKey: "AIzaSyBjfpuzVCTvKEMdYGYjMa619SSJ1yL8Jho",
    publicAppUrl: "https://sistema-educativo-rl.web.app",
  },
  "sistema-educativo-rl-prod": {
    authWebApiKey: "AIzaSyBXPXXueD4pGhrM7TK9hLTuYQ2LLpsF-5Q",
    publicAppUrl: "https://liceobilinguerodolfollinas.edu.co",
  },
});

function runtimeEnvironment(env = process.env) {
  const firebase = JSON.parse(env.FIREBASE_CONFIG || "{}");
  const project = env.GCLOUD_PROJECT || env.GOOGLE_CLOUD_PROJECT ||
    firebase.projectId;
  if (env.FUNCTIONS_EMULATOR === "true") {
    return {authWebApiKey: "emulator-only", publicAppUrl: "http://localhost:5000",
      verificationContinueUrl: "http://localhost:5000/#/login"};
  }
  const config = CONFIG[project];
  if (!config) throw new Error("Unknown Firebase runtime project");
  if (env.PUBLIC_APP_URL && env.PUBLIC_APP_URL !== config.publicAppUrl) {
    throw new Error("PUBLIC_APP_URL does not match the Firebase project");
  }
  return {...config,
    verificationContinueUrl: `${config.publicAppUrl}/#/login`};
}

module.exports = {runtimeEnvironment};
