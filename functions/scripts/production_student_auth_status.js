"use strict";
// Diagnostico sin secretos para la cuenta productiva de Sara.
const {cloudAccess} = require("./cloud_access");
const {decode} = require("./production_projection");

const PROJECT = "sistema-educativo-rl-prod";
const UID = "gJNXZux0NkPheNMmsbOfP1iQdnG3";
const FIRESTORE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;

async function main() {
  const request = await cloudAccess();
  const [profileDoc, authResult] = await Promise.all([
    request(`${FIRESTORE}/users/${UID}`),
    request(
        `https://identitytoolkit.googleapis.com/v1/projects/${PROJECT}/accounts:lookup`,
        "POST",
        {localId: [UID]},
    ),
  ]);
  const profile = decode({mapValue: {fields: profileDoc.fields}});
  const account = authResult.users?.[0];
  if (!account || account.localId !== UID) {
    throw new Error("La cuenta de Auth no existe");
  }
  console.log(JSON.stringify({
    profileActive: profile.status === "activo",
    roleStudent: profile.role === "Estudiante",
    authDisabled: account.disabled === true,
    authEmailMatchesProfile: account.email?.toLowerCase() ===
      profile.institutionalEmail?.toLowerCase(),
    mustChangePassword: profile.mustChangePassword === true,
    resetOperationPresent: Boolean(profile.passwordResetOperationId),
    resetCompleted: Boolean(profile.passwordResetCompletedAt),
    passwordChanged: Boolean(profile.passwordChangedAt),
  }));
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
