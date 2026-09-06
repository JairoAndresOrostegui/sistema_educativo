"use strict";
/* eslint-disable max-len */
const crypto = require("crypto");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {FieldValue} = require("firebase-admin/firestore");

function pushDeviceFunctions(db, getCaller) {
  return {gestionarDispositivoPush: onCall(async (request) => {
    const caller = await getCaller(request);
    const {slot, sessionId, action, token} = request.data || {};
    if (!["web", "mobile"].includes(slot) ||
        !["begin", "enable", "refresh", "disable", "status"].includes(action) ||
        typeof sessionId !== "string" || !/^[a-f0-9]{64}$/.test(sessionId)) {
      throw new HttpsError("invalid-argument", "Dispositivo no válido.");
    }
    const authTime = Number(request.auth.token.auth_time);
    if (!Number.isFinite(authTime) || authTime <= 0) {
      throw new HttpsError("unauthenticated", "Inicia sesión nuevamente.");
    }
    const sessionHash = crypto.createHash("sha256").update(sessionId).digest("hex");
    const ownerRef = db.collection("push_device_sessions").doc(caller.uid);
    const userRef = db.collection("users").doc(caller.uid);
    return db.runTransaction(async (tx) => {
      const owner = (await tx.get(ownerRef)).data()?.[slot];
      const user = (await tx.get(userRef)).data();
      if (!user || user.status !== "activo") throw new HttpsError("permission-denied", "Cuenta no activa.");
      const mine = owner?.sessionHash === sessionHash;
      if (action === "status") return {current: mine, enabled: mine && owner.enabled === true};
      if (action === "begin") {
        if (mine) return {current: true, enabled: owner.enabled === true};
        if (owner && authTime <= owner.authTime) {
          throw new HttpsError("failed-precondition", "Otro dispositivo inició sesión después. Vuelve a iniciar sesión para recibir avisos aquí.");
        }
        tx.set(ownerRef, {[slot]: {sessionHash, authTime, enabled: false}}, {merge: true});
        tx.update(userRef, {[`notificationTokens.${slot}`]: FieldValue.delete(),
          fcmToken: FieldValue.delete(), fcmTokens: FieldValue.delete(),
          webPushToken: FieldValue.delete(), mobilePushToken: FieldValue.delete()});
        return {current: true, enabled: false};
      }
      if (!mine) {
        if (action === "disable" || action === "refresh") return {current: false, enabled: false};
        throw new HttpsError("failed-precondition", "Este dispositivo fue reemplazado. Inicia sesión nuevamente.");
      }
      if (action === "disable") {
        tx.update(ownerRef, {[`${slot}.enabled`]: false});
        tx.update(userRef, {[`notificationTokens.${slot}`]: FieldValue.delete()});
        return {current: true, enabled: false};
      }
      if (action === "refresh" && !owner.enabled) return {current: true, enabled: false};
      if (typeof token !== "string" || token.length < 20 || token.length > 4096) {
        throw new HttpsError("invalid-argument", "Token no válido.");
      }
      tx.update(ownerRef, {[`${slot}.enabled`]: true});
      tx.update(userRef, {[`notificationTokens.${slot}`]: token});
      return {current: true, enabled: true};
    });
  })};
}
module.exports = {pushDeviceFunctions};
