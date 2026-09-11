"use strict";
/* eslint-disable max-len */
const crypto = require("crypto");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {FieldValue} = require("firebase-admin/firestore");
const hash = (value) => crypto.createHash("sha256").update(value).digest("hex");
const credentialId = (type, id) => hash(`${type}:${id}`);

function qrFunctions(db, getCaller, activeYear) {
  const fail = () => {
    throw new HttpsError("permission-denied", "QR no disponible para esta cuenta.");
  };
  const admin = (user, action = "crear") => user.isSuperadmin === true ||
    user.role === "Administrador" && (user.permissions || []).includes(`codigoqr.${action}`);
  const tenant = (caller, value) => caller.isSuperadmin === true ||
    caller.institution === value.institutionId && caller.campus === value.campusId;
  const audit = (tx, caller, value, action) => tx.create(db.collection("qr_audit").doc(), {
    action, performedBy: caller.uid, targetType: value.targetType,
    targetId: value.targetId, institutionId: value.institutionId,
    campusId: value.campusId, createdAt: FieldValue.serverTimestamp(),
  });
  async function target(caller, type, id, tx) {
    if (!["user", "event"].includes(type) || typeof id !== "string" || !id || id.includes("/")) fail();
    const ref = db.collection(type === "user" ? "users" : "events").doc(id);
    const snapshot = tx ? await tx.get(ref) : await ref.get();
    if (!snapshot.exists) fail();
    const raw = snapshot.data();
    const scope = {institutionId: type === "user" ? raw.institution : raw.institutionId,
      campusId: type === "user" ? raw.campus : raw.campusId};
    if (!tenant(caller, scope) || raw.status !== (type === "user" ? "activo" : "active")) fail();
    if (type === "event") {
      const yearRef = db.collection("academic_years").doc(raw.academicYearId);
      const year = tx ? await tx.get(yearRef) : await yearRef.get();
      if (!year.exists || year.data().status !== "active" ||
          year.data().institutionId !== scope.institutionId ||
          year.data().campusId !== scope.campusId) fail();
    }
    return {...scope, targetType: type, targetId: id, raw};
  }
  function userAccess(caller, id) {
    return caller.uid === id || admin(caller) || admin(caller, "editar") ||
      caller.role === "Familiar" && caller.activeStudentId === id &&
      (caller.studentIds || []).includes(id);
  }
  const obtenerCredencialQr = onCall(async (request) => {
    const caller = await getCaller(request);
    const type = request.data?.targetType || "user";
    const id = request.data?.targetId || caller.uid;
    if (type === "user" ? !userAccess(caller, id) :
      !admin(caller) && !admin(caller, "editar")) fail();
    const ref = db.collection("qr_credentials").doc(credentialId(type, id));
    return db.runTransaction(async (tx) => {
      const value = await target(caller, type, id, tx);
      const existing = await tx.get(ref);
      if (existing.exists) {
        if (existing.data().institutionId !== value.institutionId ||
            existing.data().campusId !== value.campusId) fail();
        const current = existing.data();
        if (current.status !== "active") {
          if (!admin(caller, "editar")) fail();
          return {payload: null, status: current.status,
            revision: Number(current.revision || 0), targetType: type, targetId: id};
        }
        return {payload: current.payload, status: "active",
          revision: Number(current.revision || 0), targetType: type, targetId: id};
      }
      const payload = `LLQ1:${crypto.randomBytes(32).toString("base64url")}`;
      const {raw, ...identity} = value;
      void raw;
      tx.create(ref, {...identity, payload, tokenHash: hash(payload), status: "active", revision: 1,
        createdAt: FieldValue.serverTimestamp()});
      audit(tx, caller, value, "issued");
      return {payload, status: "active", revision: 1, targetType: type, targetId: id};
    });
  });
  const administrarCredencialQr = onCall(async (request) => {
    const caller = await getCaller(request);
    if (!admin(caller, "editar")) fail();
    const {targetType, targetId, action} = request.data || {};
    if (!["revoke", "rotate"].includes(action)) fail();
    if (request.data?.confirmation !== `${action}:${targetId}`) fail();
    const expectedRevision = Number(request.data?.expectedRevision);
    if (!Number.isInteger(expectedRevision) || expectedRevision < 0) {
      throw new HttpsError("invalid-argument", "Recarga la credencial antes de modificarla.");
    }
    const ref = db.collection("qr_credentials").doc(credentialId(targetType, targetId));
    return db.runTransaction(async (tx) => {
      const value = await target(caller, targetType, targetId, tx);
      const existing = await tx.get(ref);
      if (!existing.exists) fail();
      const current = existing.data();
      if (Number(current.revision || 0) !== expectedRevision) {
        throw new HttpsError("aborted", "La credencial cambió. Recarga antes de continuar.");
      }
      if (action === "revoke") {
        if (current.status !== "active") {
          throw new HttpsError("failed-precondition", "La credencial ya está revocada.");
        }
        tx.update(ref, {status: "revoked", payload: FieldValue.delete(),
          tokenHash: FieldValue.delete(), revision: expectedRevision + 1,
          updatedAt: FieldValue.serverTimestamp()});
      } else {
        const payload = `LLQ1:${crypto.randomBytes(32).toString("base64url")}`;
        tx.update(ref, {status: "active", payload, tokenHash: hash(payload),
          institutionId: value.institutionId, campusId: value.campusId,
          revision: expectedRevision + 1,
          updatedAt: FieldValue.serverTimestamp()});
      }
      audit(tx, caller, value, action);
      return {success: true, status: action === "revoke" ? "revoked" : "active",
        revision: expectedRevision + 1};
    });
  });
  const resolverCredencialQr = onCall(async (request) => {
    const caller = await getCaller(request);
    const payload = request.data?.payload;
    const source = ["camera", "manual"].includes(request.data?.source) ?
      request.data.source : "manual";
    const clientPlatform = ["android", "ios", "web"].includes(
        request.data?.clientPlatform) ? request.data.clientPlatform : "other";
    if (typeof payload !== "string" || !/^LLQ1:[A-Za-z0-9_-]{43}$/.test(payload)) fail();
    const matches = await db.collection("qr_credentials").where("tokenHash", "==", hash(payload)).limit(1).get();
    if (matches.empty) fail();
    const value = matches.docs[0].data();
    if (value.status !== "active") fail();
    const entity = await target(caller, value.targetType, value.targetId);
    if (entity.institutionId !== value.institutionId || entity.campusId !== value.campusId) fail();
    if (value.targetType === "user" && !userAccess(caller, value.targetId)) fail();
    const result = {targetType: value.targetType, targetId: value.targetId,
      name: value.targetType === "user" ?
        `${entity.raw.firstName || ""} ${entity.raw.lastName || ""}`.trim() : entity.raw.title,
      institutionId: entity.institutionId, campusId: entity.campusId,
      identificationOnly: true, children: []};
    if (value.targetType === "user" && entity.raw.role === "Familiar") {
      for (const id of entity.raw.studentIds || []) {
        const child = await db.collection("users").doc(id).get();
        const data = child.data();
        if (data?.role === "Estudiante" && data.status === "activo" &&
            data.institution === entity.institutionId && data.campus === entity.campusId) {
          result.children.push({id, name: `${data.firstName} ${data.lastName}`,
            groupId: data.groupId || null, groupName: data.groupName || null});
        }
      }
    }
    await db.runTransaction(async (tx) => {
      const ref = db.collection("qr_audit").doc();
      tx.create(ref, {action: "resolved", result: "success", source,
        clientPlatform, performedBy: caller.uid,
        targetType: entity.targetType, targetId: entity.targetId,
        institutionId: entity.institutionId, campusId: entity.campusId,
        createdAt: FieldValue.serverTimestamp()});
    });
    return result;
  });
  const crearIdentificadorEventoQr = onCall(async (request) => {
    const caller = await getCaller(request);
    if (!admin(caller)) fail();
    const title = typeof request.data?.title === "string" ? request.data.title.trim() : "";
    if (!title || title.length > 120) throw new HttpsError("invalid-argument", "Indica un nombre de hasta 120 caracteres.");
    const institutionId = caller.isSuperadmin ? request.data?.institutionId || caller.institution : caller.institution;
    const campusId = caller.isSuperadmin ? request.data?.campusId || caller.campus : caller.campus;
    if (!caller.isSuperadmin && (request.data?.institutionId && request.data.institutionId !== institutionId ||
        request.data?.campusId && request.data.campusId !== campusId)) fail();
    const year = await activeYear(institutionId, campusId);
    const ref = db.collection("events").doc();
    const payload = `LLQ1:${crypto.randomBytes(32).toString("base64url")}`;
    const identity = {targetType: "event", targetId: ref.id, institutionId, campusId};
    const batch = db.batch();
    batch.create(ref, {title, institutionId, campusId, academicYearId: year.id,
      academicYear: year.year, status: "active", purpose: "identification_only",
      createdBy: caller.uid, createdAt: FieldValue.serverTimestamp()});
    batch.create(db.collection("qr_credentials").doc(credentialId("event", ref.id)), {
      ...identity, payload, tokenHash: hash(payload), status: "active", revision: 1,
      createdAt: FieldValue.serverTimestamp(),
    });
    audit(batch, caller, identity, "event_created");
    await batch.commit();
    return {...identity, payload};
  });
  const listarEntidadesQr = onCall(async (request) => {
    const caller = await getCaller(request);
    if (!admin(caller) && !admin(caller, "editar")) fail();
    const entities = [];
    for (const type of ["user", "event"]) {
      let query = db.collection(type === "user" ? "users" : "events");
      if (!caller.isSuperadmin) {
        query = query.where(type === "user" ? "institution" : "institutionId", "==", caller.institution)
            .where(type === "user" ? "campus" : "campusId", "==", caller.campus);
      }
      const rows = await query.limit(1000).get();
      for (const item of rows.docs) {
        const raw = item.data();
        if (raw.status !== (type === "user" ? "activo" : "active")) continue;
        entities.push({targetType: type, targetId: item.id,
          name: type === "user" ? `${raw.firstName || ""} ${raw.lastName || ""}`.trim() : raw.title,
          role: raw.role || "Evento", institutionId: raw.institutionId || raw.institution,
          campusId: raw.campusId || raw.campus});
      }
    }
    return {entities};
  });
  return {obtenerCredencialQr, administrarCredencialQr, listarEntidadesQr,
    resolverCredencialQr, crearIdentificadorEventoQr};
}
module.exports = {qrFunctions, credentialId};
