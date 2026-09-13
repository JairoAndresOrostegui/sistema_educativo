"use strict";
/* eslint-disable max-len */
const crypto = require("crypto");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {FieldValue} = require("firebase-admin/firestore");
const hash = (value) => crypto.createHash("sha256").update(value).digest("hex");
const credentialId = (type, id) => hash(`${type}:${id}`);

async function readQrCredential(db, payload, {tx = null, expectedType = null} = {}) {
  const deny = () => {
    throw new HttpsError("permission-denied", "QR no disponible para esta operación.");
  };
  if (typeof payload !== "string" || !/^LLQ1:[A-Za-z0-9_-]{43}$/.test(payload)) deny();
  const read = (ref) => tx ? tx.get(ref) : ref.get();
  const rows = await read(db.collection("qr_credentials").where("tokenHash", "==", hash(payload)).limit(1));
  if (rows.empty) deny();
  const value = rows.docs[0].data();
  if (value.status !== "active" || !["user", "event"].includes(value.targetType) ||
      expectedType && value.targetType !== expectedType ||
      typeof value.targetId !== "string" || !value.targetId || value.targetId.includes("/")) deny();
  const entity = await read(db.collection(value.targetType === "user" ? "users" : "school_events").doc(value.targetId));
  const raw = entity.data();
  if (!entity.exists || (value.targetType === "user" ? raw.status !== "activo" :
    !["published", "closed"].includes(raw.status))) deny();
  const institutionId = value.targetType === "user" ? raw.institution : raw.institutionId;
  const campusId = value.targetType === "user" ? raw.campus : raw.campusId;
  if (!institutionId || !campusId || value.institutionId !== institutionId || value.campusId !== campusId) deny();
  if (value.targetType === "event") {
    if (typeof raw.academicYearId !== "string" || !raw.academicYearId || raw.academicYearId.includes("/")) deny();
    const year = (await read(db.collection("academic_years").doc(raw.academicYearId))).data();
    if (!year || year.status !== "active" || year.institutionId !== institutionId || year.campusId !== campusId) deny();
  }
  return {credentialId: rows.docs[0].id, revision: Number(value.revision || 0),
    targetType: value.targetType, targetId: value.targetId, institutionId, campusId, raw};
}

function recordQrResolution(tx, db, caller, identity, metadata = {}) {
  const source = ["camera", "manual"].includes(metadata.source) ? metadata.source : "manual";
  const clientPlatform = ["android", "ios", "web"].includes(metadata.clientPlatform) ? metadata.clientPlatform : "other";
  tx.create(db.collection("qr_audit").doc(), {action: "resolved", result: "success", source,
    clientPlatform, performedBy: caller.uid, targetType: identity.targetType, targetId: identity.targetId,
    credentialId: identity.credentialId, credentialRevision: identity.revision,
    institutionId: identity.institutionId, campusId: identity.campusId,
    context: ["eventos", "rutas"].includes(metadata.context) ? metadata.context : "identification",
    createdAt: FieldValue.serverTimestamp()});
}

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
    const ref = db.collection(type === "user" ? "users" : "school_events").doc(id);
    const snapshot = tx ? await tx.get(ref) : await ref.get();
    if (!snapshot.exists) fail();
    const raw = snapshot.data();
    const scope = {institutionId: type === "user" ? raw.institution : raw.institutionId,
      campusId: type === "user" ? raw.campus : raw.campusId};
    if (!tenant(caller, scope) || (type === "user" ? raw.status !== "activo" :
      !["published", "closed"].includes(raw.status))) fail();
    if (type === "event") {
      if (typeof raw.academicYearId !== "string" || !raw.academicYearId || raw.academicYearId.includes("/")) fail();
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
  async function eventAccess(caller, value, tx) {
    if (!tenant(caller, value) || !caller.isSuperadmin &&
        !(caller.permissions || []).includes("eventos.ver")) fail();
    if (caller.isSuperadmin || caller.role === "Administrador") return;
    if (caller.role === "Docente") {
      if (value.raw.responsibleUserIds?.includes(caller.uid)) return;
      const query = db.collection("subjects").where("academicYearId", "==", value.raw.academicYearId)
          .where("teacherId", "==", caller.uid);
      const subjects = tx ? await tx.get(query) : await query.get();
      const groups = new Set(subjects.docs.filter((row) => row.data().institutionId === value.institutionId &&
        row.data().campusId === value.campusId).map((row) => row.data().groupId));
      if (caller.tutorGroupId) groups.add(caller.tutorGroupId);
      if (value.raw.targetGroupIds?.some((id) => groups.has(id))) return;
      fail();
    }
    const studentId = caller.role === "Estudiante" ? caller.uid :
      caller.role === "Familiar" && caller.studentIds?.includes(caller.activeStudentId) ? caller.activeStudentId : null;
    if (!studentId || !value.raw.targetStudentIds?.includes(studentId)) fail();
    const ref = db.collection("users").doc(studentId);
    const student = (tx ? await tx.get(ref) : await ref.get()).data();
    if (!student || student.status !== "activo" || student.role !== "Estudiante" ||
        student.institution !== value.institutionId || student.campus !== value.campusId) fail();
  }
  const obtenerCredencialQr = onCall(async (request) => {
    const caller = await getCaller(request);
    const type = request.data?.targetType || "user";
    const id = request.data?.targetId || caller.uid;
    if (type === "user" && !userAccess(caller, id)) fail();
    const ref = db.collection("qr_credentials").doc(credentialId(type, id));
    return db.runTransaction(async (tx) => {
      const value = await target(caller, type, id, tx);
      if (type === "event") await eventAccess(caller, value, tx);
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
    return db.runTransaction(async (tx) => {
      const actor = (await tx.get(db.collection("users").doc(caller.uid))).data();
      if (!actor || actor.status !== "activo" || actor.mustChangePassword === true) fail();
      const freshCaller = {...actor, uid: caller.uid};
      const entity = await readQrCredential(db, request.data?.payload, {tx});
      if (!tenant(freshCaller, entity)) fail();
      if (entity.targetType === "event") await eventAccess(freshCaller, entity, tx);
      else if (!userAccess(freshCaller, entity.targetId)) fail();
      const result = {targetType: entity.targetType, targetId: entity.targetId,
        name: entity.targetType === "user" ?
          `${entity.raw.firstName || ""} ${entity.raw.lastName || ""}`.trim() : entity.raw.title,
        institutionId: entity.institutionId, campusId: entity.campusId,
        identificationOnly: true, children: [],
        ...(entity.targetType === "event" ? {eventId: entity.targetId, action: "open_event"} : {})};
      if (entity.targetType === "user" && entity.raw.role === "Familiar") {
        for (const id of entity.raw.studentIds || []) {
          const child = await tx.get(db.collection("users").doc(id));
          const data = child.data();
          if (data?.role === "Estudiante" && data.status === "activo" &&
              data.institution === entity.institutionId && data.campus === entity.campusId) {
            result.children.push({id, name: `${data.firstName} ${data.lastName}`,
              groupId: data.groupId || null, groupName: data.groupName || null});
          }
        }
      }
      recordQrResolution(tx, db, freshCaller, entity, request.data);
      return result;
    });
  });
  const crearIdentificadorEventoQr = onCall(async (request) => {
    await getCaller(request);
    if (typeof request.data?.eventId !== "string" || !request.data.eventId) {
      throw new HttpsError("failed-precondition", "Crea y publica el evento desde Eventos antes de obtener su QR.");
    }
    return obtenerCredencialQr.run({...request, data: {targetType: "event", targetId: request.data.eventId}});
  });
  const listarEntidadesQr = onCall(async (request) => {
    const caller = await getCaller(request);
    if (!admin(caller) && !admin(caller, "editar")) fail();
    const entities = [];
    for (const type of ["user", "event"]) {
      let query = db.collection(type === "user" ? "users" : "school_events");
      if (!caller.isSuperadmin) {
        query = query.where(type === "user" ? "institution" : "institutionId", "==", caller.institution)
            .where(type === "user" ? "campus" : "campusId", "==", caller.campus);
      }
      const rows = await query.limit(1000).get();
      for (const item of rows.docs) {
        const raw = item.data();
        if (type === "user" ? raw.status !== "activo" : !["published", "closed"].includes(raw.status)) continue;
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
module.exports = {qrFunctions, credentialId, readQrCredential, recordQrResolution};
