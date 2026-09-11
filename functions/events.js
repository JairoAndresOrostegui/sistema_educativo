"use strict";
/* eslint-disable max-len */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {FieldValue, Timestamp} = require("firebase-admin/firestore");

const EVENT_STATES = new Set(["draft", "published", "closed", "cancelled", "archived"]);
const ATTENDANCE_STATES = new Set(["present", "absent"]);

function eventFunctions(db, getCaller, activeYear) {
  const deny = (message = "No tienes acceso a este evento.") => {
    throw new HttpsError("permission-denied", message);
  };
  const permission = (user, action) => user.isSuperadmin === true ||
    Array.isArray(user.permissions) && user.permissions.includes(`eventos.${action}`);
  const admin = (user, action = "ver") => user.isSuperadmin === true ||
    user.role === "Administrador" && permission(user, action);
  const sameTenant = (user, value) => user.isSuperadmin === true ||
    user.institution === value.institutionId && user.campus === value.campusId;
  const id = (value, label = "identificador") => {
    if (typeof value !== "string" || !value.trim() || value.includes("/") || value.length > 160) {
      throw new HttpsError("invalid-argument", `${label} no es válido.`);
    }
    return value.trim();
  };
  const text = (value, label, max, required = true) => {
    const result = typeof value === "string" ? value.trim() : "";
    if ((required && !result) || result.length > max) {
      throw new HttpsError("invalid-argument", `${label} no es válido.`);
    }
    return result;
  };
  const scope = (user, input) => {
    const institutionId = user.isSuperadmin === true ?
      id(input?.institutionId || user.institution, "institución") : user.institution;
    const campusId = user.isSuperadmin === true ?
      id(input?.campusId || user.campus, "sede") : user.campus;
    if (!sameTenant(user, {institutionId, campusId})) deny();
    return {institutionId, campusId};
  };
  const millis = (value, label) => {
    const result = Number(value);
    if (!Number.isSafeInteger(result) || result < 0 || result > 253402300799999) {
      throw new HttpsError("invalid-argument", `${label} no es válida.`);
    }
    return result;
  };
  const colombiaYear = (value) => Number(new Intl.DateTimeFormat("en", {
    timeZone: "America/Bogota", year: "numeric",
  }).format(new Date(value)));
  const stringIds = (value, label, max = 200) => {
    if (!Array.isArray(value) || value.length > max) {
      throw new HttpsError("invalid-argument", `${label} no es válida.`);
    }
    const result = [...new Set(value.map((item) => id(item, label)))];
    if (result.length !== value.length) {
      throw new HttpsError("invalid-argument", `${label} contiene duplicados.`);
    }
    return result;
  };
  // Read the year and actor in the mutation transaction. Closing a year or
  // transferring/deactivating a teacher must invalidate an in-flight write.
  const mutationActor = async (tx, user, value) => {
    const [actorSnapshot, yearSnapshot] = await Promise.all([
      tx.get(db.collection("users").doc(user.uid)),
      tx.get(db.collection("academic_years").doc(value.academicYearId)),
    ]);
    const actor = actorSnapshot.data() || {};
    const year = yearSnapshot.data() || {};
    if (!actorSnapshot.exists || actor.status !== "activo") deny();
    if (!yearSnapshot.exists || year.status !== "active" ||
        year.institutionId !== value.institutionId || year.campusId !== value.campusId) {
      throw new HttpsError("failed-precondition", "El año lectivo del evento está cerrado. Solo puede consultarse.");
    }
    return {...actor, uid: user.uid};
  };
  const completeSnapshot = async (query) => {
    const snapshot = await query.limit(2001).get();
    if (snapshot.size > 2000) {
      throw new HttpsError("resource-exhausted", "La consulta supera 2000 eventos. Reduce el rango del reporte.");
    }
    return snapshot;
  };
  const teacherGroupIds = async (user, year, tx = null) => {
    const query = db.collection("subjects")
        .where("academicYearId", "==", year.id)
        .where("teacherId", "==", user.uid);
    const subjects = await (tx ? tx.get(query) : query.get());
    const result = new Set(subjects.docs.map((item) => item.data().groupId));
    if (user.tutorGroupId) result.add(user.tutorGroupId);
    return result;
  };
  const activeGroups = async (tenant, year, tx = null) => {
    const query = db.collection("academic_groups")
        .where("institutionId", "==", tenant.institutionId)
        .where("campusId", "==", tenant.campusId)
        .where("academicYearId", "==", year.id)
        .where("active", "==", true);
    const snapshot = await (tx ? tx.get(query) : query.get());
    return new Map(snapshot.docs.map((item) => [item.id, item.data()]));
  };
  const checkedStudent = async (user, requestedId) => {
    let studentId;
    if (user.role === "Estudiante") studentId = user.uid;
    else if (user.role === "Familiar") {
      studentId = id(requestedId || user.activeStudentId, "estudiante");
      if (studentId !== user.activeStudentId ||
          !Array.isArray(user.studentIds) || !user.studentIds.includes(studentId)) {
        deny("Selecciona un hijo activo vinculado.");
      }
    } else deny();
    const snapshot = await db.collection("users").doc(studentId).get();
    const student = snapshot.data() || {};
    if (!snapshot.exists || student.status !== "activo" || student.role !== "Estudiante" ||
        student.institution !== user.institution || student.campus !== user.campus) deny();
    return {id: snapshot.id, ...student};
  };
  const eventResponse = (snapshot, extra = {}, includeAudience = true) => {
    const value = snapshot.data();
    return {
      id: snapshot.id,
      title: value.title,
      description: value.description,
      location: value.location,
      startAtMillis: value.startAt?.toMillis?.() || null,
      endAtMillis: value.endAt?.toMillis?.() || null,
      status: value.status,
      audienceType: value.audienceType,
      ...(includeAudience ? {
        targetGroupIds: value.targetGroupIds || [],
        targetStudentIds: value.targetStudentIds || [],
      } : {targetGroupIds: []}),
      responsibleUserIds: value.responsibleUserIds || [],
      responsibleNames: value.responsibleNames || {},
      links: value.links || [],
      registrationRequired: value.registrationRequired === true,
      requiresFamilyAuthorization: value.requiresFamilyAuthorization === true,
      capacity: value.capacity || null,
      confirmedCount: Number(value.confirmedCount || 0),
      revision: Number(value.revision || 1),
      attendanceRevision: Number(value.attendanceRevision || 1),
      ...extra,
    };
  };
  const validateResponsibleUsers = async (ids, tenant, tx = null) => {
    if (!ids.length) throw new HttpsError("invalid-argument", "Selecciona un responsable.");
    const refs = ids.map((uid) => db.collection("users").doc(uid));
    const snapshots = await (tx ? tx.getAll(...refs) : db.getAll(...refs));
    const names = {};
    for (const snapshot of snapshots) {
      const value = snapshot.data() || {};
      if (!snapshot.exists || value.status !== "activo" ||
          !["Administrador", "Docente"].includes(value.role) ||
          value.institution !== tenant.institutionId || value.campus !== tenant.campusId) {
        deny("Hay un responsable fuera de la sede.");
      }
      names[snapshot.id] = `${value.firstName || ""} ${value.lastName || ""}`.trim();
    }
    return names;
  };
  const validateAudience = async (input, tenant, year, user, tx = null) => {
    const audienceType = ["all", "groups", "students"].includes(input.audienceType) ?
      input.audienceType : "groups";
    const groups = await activeGroups(tenant, year, tx);
    // Materialized IDs from a group draft are not an individual audience.
    // Parsing them as such prevented publishing groups over 200 students.
    let targetGroupIds = audienceType === "groups" ?
      stringIds(input.targetGroupIds || [], "grupos") : [];
    let requestedStudentIds = audienceType === "students" ?
      stringIds(input.targetStudentIds || [], "estudiantes", 2000) : [];
    if (audienceType === "all") targetGroupIds = [...groups.keys()];
    if (audienceType === "groups" && !targetGroupIds.length) {
      throw new HttpsError("invalid-argument", "Selecciona al menos un grupo.");
    }
    for (const groupId of targetGroupIds) {
      if (!groups.has(groupId)) deny("La audiencia contiene un grupo no vigente.");
    }
    let allowedTeacherGroups = null;
    if (user.role === "Docente" && user.isSuperadmin !== true) {
      if (audienceType === "all") deny("Un docente no puede publicar a toda la sede.");
      allowedTeacherGroups = await teacherGroupIds(user, year, tx);
      if (targetGroupIds.some((groupId) => !allowedTeacherGroups.has(groupId))) {
        deny("La audiencia supera tu carga docente.");
      }
    }
    let studentSnapshots;
    if (audienceType === "students") {
      if (!requestedStudentIds.length) {
        throw new HttpsError("invalid-argument", "Selecciona al menos un estudiante.");
      }
      const refs = requestedStudentIds.map((studentId) => db.collection("users").doc(studentId));
      studentSnapshots = await (tx ? tx.getAll(...refs) : db.getAll(...refs));
      for (const snapshot of studentSnapshots) {
        const value = snapshot.data() || {};
        if (!snapshot.exists || value.status !== "activo" || value.role !== "Estudiante" ||
            value.institution !== tenant.institutionId || value.campus !== tenant.campusId ||
            !groups.has(value.groupId)) deny("La audiencia contiene un estudiante no vigente.");
        if (allowedTeacherGroups && !allowedTeacherGroups.has(value.groupId)) {
          deny("La audiencia supera tu carga docente.");
        }
      }
      targetGroupIds = [...new Set(studentSnapshots.map((item) => item.data().groupId))];
    } else {
      const query = db.collection("users")
          .where("institution", "==", tenant.institutionId)
          .where("campus", "==", tenant.campusId)
          .where("role", "==", "Estudiante")
          .where("status", "==", "activo");
      const snapshot = await (tx ? tx.get(query) : query.get());
      studentSnapshots = snapshot.docs.filter((item) => targetGroupIds.includes(item.data().groupId));
      requestedStudentIds = studentSnapshots.map((item) => item.id);
    }
    if (requestedStudentIds.length > 2000) {
      throw new HttpsError("resource-exhausted", "La audiencia supera 2000 estudiantes.");
    }
    const studentNames = Object.fromEntries(studentSnapshots.map((item) => [
      item.id, `${item.data().firstName || ""} ${item.data().lastName || ""}`.trim(),
    ]));
    return {audienceType, targetGroupIds, targetStudentIds: requestedStudentIds, studentNames};
  };
  const recipientUsers = async (studentIds, responsibleUserIds, tenant, tx = null) => {
    const refs = [...new Set([...studentIds, ...responsibleUserIds])]
        .map((uid) => db.collection("users").doc(uid));
    const users = refs.length ? await (tx ? tx.getAll(...refs) : db.getAll(...refs)) : [];
    const activeStudents = [];
    const recipients = new Set();
    for (const item of users) {
      const value = item.data() || {};
      if (!item.exists || value.status !== "activo" || value.institution !== tenant.institutionId ||
          value.campus !== tenant.campusId) continue;
      if (studentIds.includes(item.id) && value.role === "Estudiante") {
        activeStudents.push(item.id);
        recipients.add(item.id);
      } else if (responsibleUserIds.includes(item.id) &&
          ["Administrador", "Docente"].includes(value.role)) recipients.add(item.id);
    }
    for (let offset = 0; offset < activeStudents.length; offset += 30) {
      const chunk = activeStudents.slice(offset, offset + 30);
      const query = db.collection("users").where("studentIds", "array-contains-any", chunk);
      const families = await (tx ? tx.get(query) : query.get());
      families.docs.filter((item) => {
        const value = item.data();
        return value.role === "Familiar" && value.status === "activo" &&
          value.institution === tenant.institutionId && value.campus === tenant.campusId;
      }).forEach((item) => recipients.add(item.id));
    }
    return [...recipients];
  };
  const checkedManageEvent = async (user, event, action) => {
    if (!sameTenant(user, event) || !permission(user, action)) deny();
    if (admin(user, action)) return;
    if (user.role !== "Docente" || !event.responsibleUserIds?.includes(user.uid)) {
      deny("No eres responsable de este evento.");
    }
  };

  const listarContextosEventos = onCall(async (request) => {
    const user = await getCaller(request);
    if (!["Administrador", "Docente"].includes(user.role) || !permission(user, "ver")) deny();
    const tenant = scope(user, request.data);
    const year = await activeYear(tenant.institutionId, tenant.campusId);
    let groups = await activeGroups(tenant, year);
    if (user.role === "Docente" && user.isSuperadmin !== true) {
      const allowed = await teacherGroupIds(user, year);
      groups = new Map([...groups].filter(([groupId]) => allowed.has(groupId)));
    }
    const userSnapshot = await db.collection("users")
        .where("institution", "==", tenant.institutionId)
        .where("campus", "==", tenant.campusId)
        .where("status", "==", "activo").get();
    let responsibleUsers;
    if (admin(user, "crear")) {
      responsibleUsers = userSnapshot.docs.filter((item) =>
        ["Administrador", "Docente"].includes(item.data().role)).map((item) => ({
        id: item.id,
        name: `${item.data().firstName || ""} ${item.data().lastName || ""}`.trim(),
        role: item.data().role,
      })).sort((a, b) => a.name.localeCompare(b.name));
    } else {
      responsibleUsers = [{id: user.uid,
        name: `${user.firstName || ""} ${user.lastName || ""}`.trim(), role: user.role}];
    }
    let allowedStudentGroups = new Set(groups.keys());
    if (user.role === "Docente" && user.isSuperadmin !== true) {
      allowedStudentGroups = await teacherGroupIds(user, year);
    }
    const students = userSnapshot.docs.filter((item) => {
      const value = item.data();
      return value.role === "Estudiante" && groups.has(value.groupId) &&
        allowedStudentGroups.has(value.groupId);
    }).map((item) => ({
      id: item.id,
      name: `${item.data().firstName || ""} ${item.data().lastName || ""}`.trim(),
      groupId: item.data().groupId,
      groupName: groups.get(item.data().groupId)?.name || "Grupo",
    })).sort((a, b) => a.name.localeCompare(b.name));
    return {academicYearId: year.id, academicYear: year.year,
      groups: [...groups].map(([groupId, value]) => ({id: groupId, name: value.name}))
          .sort((a, b) => a.name.localeCompare(b.name)), responsibleUsers, students};
  });

  const guardarEvento = onCall(async (request) => {
    const user = await getCaller(request);
    const input = request.data || {};
    const eventId = input.eventId == null || input.eventId === "" ? null : id(input.eventId, "evento");
    const action = eventId ? "editar" : "crear";
    if (!["Administrador", "Docente"].includes(user.role) || !permission(user, action)) deny();
    const tenant = scope(user, input);
    const year = await activeYear(tenant.institutionId, tenant.campusId);
    const startAtMillis = millis(input.startAtMillis, "fecha inicial");
    const endAtMillis = millis(input.endAtMillis, "fecha final");
    if (endAtMillis <= startAtMillis) {
      throw new HttpsError("invalid-argument", "La fecha final debe ser posterior al inicio.");
    }
    if (colombiaYear(startAtMillis) !== Number(year.year)) {
      throw new HttpsError("failed-precondition", "El evento debe pertenecer al año activo.");
    }
    const links = Array.isArray(input.links) ? input.links.map((item) => ({
      label: text(item?.label, "Nombre del enlace", 80),
      url: text(item?.url, "URL", 500),
    })) : [];
    if (links.length > 5 || links.some((item) => {
      try {
        const url = new URL(item.url);
        return url.protocol !== "https:" || !url.hostname || !!url.username || !!url.password;
      } catch {
        return true;
      }
    })) {
      throw new HttpsError("invalid-argument", "Los adjuntos deben ser hasta 5 enlaces HTTPS.");
    }
    let responsibleUserIds = stringIds(input.responsibleUserIds || [], "responsables", 20);
    if (user.role === "Docente" && user.isSuperadmin !== true) responsibleUserIds = [user.uid];
    const responsibleNames = await validateResponsibleUsers(responsibleUserIds, tenant);
    const audience = await validateAudience(input, tenant, year, user);
    const capacity = input.capacity == null ? null : Number(input.capacity);
    if (capacity != null && (!Number.isInteger(capacity) || capacity < 1 || capacity > 2000)) {
      throw new HttpsError("invalid-argument", "El cupo no es válido.");
    }
    const value = {
      ...tenant, academicYearId: year.id, academicYear: year.year,
      title: text(input.title, "Título", 120),
      description: text(input.description, "Descripción", 3000),
      location: text(input.location, "Lugar", 250),
      startAt: Timestamp.fromMillis(startAtMillis),
      endAt: Timestamp.fromMillis(endAtMillis),
      ...audience, responsibleUserIds, responsibleNames, links,
      registrationRequired: input.registrationRequired === true,
      requiresFamilyAuthorization: input.requiresFamilyAuthorization === true,
      capacity, updatedAt: FieldValue.serverTimestamp(),
    };
    const ref = eventId ? db.collection("school_events").doc(eventId) :
      db.collection("school_events").doc();
    return db.runTransaction(async (tx) => {
      const snapshot = await tx.get(ref);
      const actor = await mutationActor(tx, user, value);
      if (!sameTenant(actor, value) || !permission(actor, action)) deny();
      value.responsibleNames = await validateResponsibleUsers(responsibleUserIds, tenant, tx);
      Object.assign(value, await validateAudience(input, tenant, year, actor, tx));
      if (eventId) {
        if (!snapshot.exists) deny();
        const current = snapshot.data();
        await mutationActor(tx, user, current);
        await checkedManageEvent(actor, current, "editar");
        if (current.institutionId !== value.institutionId || current.campusId !== value.campusId ||
            current.academicYearId !== value.academicYearId) deny("No se puede trasladar un evento a otra sede o año.");
        if (current.status !== "draft") {
          throw new HttpsError("failed-precondition", "Solo se edita un borrador.");
        }
        const expectedRevision = Number(input.expectedRevision);
        if (expectedRevision !== Number(current.revision || 1)) {
          throw new HttpsError("aborted", "El evento cambió. Recarga antes de guardar.");
        }
        value.revision = expectedRevision + 1;
        tx.update(ref, value);
      } else {
        value.status = "draft";
        value.revision = 1;
        value.attendanceRevision = 1;
        value.confirmedCount = 0;
        value.createdBy = user.uid;
        value.createdAt = FieldValue.serverTimestamp();
        tx.create(ref, value);
      }
      tx.create(db.collection("event_history").doc(), {
        action: eventId ? "event_updated" : "event_created", eventId: ref.id,
        ...tenant, academicYearId: year.id, performedBy: user.uid,
        createdAt: FieldValue.serverTimestamp(),
      });
      return {eventId: ref.id, revision: value.revision};
    });
  });

  const cambiarEstadoEvento = onCall(async (request) => {
    const user = await getCaller(request);
    const eventId = id(request.data?.eventId, "evento");
    const targetStatus = request.data?.status;
    if (!EVENT_STATES.has(targetStatus) || targetStatus === "draft") {
      throw new HttpsError("invalid-argument", "El estado solicitado no es válido.");
    }
    const ref = db.collection("school_events").doc(eventId);
    const snapshot = await ref.get();
    if (!snapshot.exists) deny();
    const current = snapshot.data();
    await checkedManageEvent(user, current, "editar");
    const transitions = {
      draft: new Set(["published", "cancelled"]),
      published: new Set(["closed", "cancelled"]),
      closed: new Set(["archived"]),
      cancelled: new Set(["archived"]),
      archived: new Set(),
    };
    if (!transitions[current.status]?.has(targetStatus)) {
      throw new HttpsError("failed-precondition", "La transición del evento no es válida.");
    }
    if (targetStatus === "published" && current.startAt.toMillis() <= Date.now()) {
      throw new HttpsError("failed-precondition", "No se puede publicar un evento ya iniciado.");
    }
    if (targetStatus === "closed" && current.startAt.toMillis() > Date.now()) {
      throw new HttpsError("failed-precondition", "El evento todavía no ha iniciado.");
    }
    const expectedRevision = Number(request.data?.expectedRevision);
    return db.runTransaction(async (tx) => {
      const fresh = await tx.get(ref);
      const value = fresh.data() || {};
      if (!fresh.exists || expectedRevision !== Number(value.revision || 1) ||
          value.status !== current.status) {
        throw new HttpsError("aborted", "El evento cambió. Recarga antes de continuar.");
      }
      const actor = await mutationActor(tx, user, value);
      await checkedManageEvent(actor, value, "editar");
      let publicationAudience = null;
      let responsibleNames = value.responsibleNames || {};
      const tenant = {institutionId: value.institutionId, campusId: value.campusId};
      if (targetStatus === "published") {
        if (value.startAt.toMillis() <= Date.now()) {
          throw new HttpsError("failed-precondition", "No se puede publicar un evento ya iniciado.");
        }
        const year = {id: value.academicYearId, year: value.academicYear};
        responsibleNames = await validateResponsibleUsers(value.responsibleUserIds || [], tenant, tx);
        publicationAudience = await validateAudience(value, tenant, year, actor, tx);
      }
      const recipientStudentIds = publicationAudience?.targetStudentIds || value.targetStudentIds || [];
      const recipients = targetStatus === "archived" ? [] :
        await recipientUsers(recipientStudentIds, value.responsibleUserIds || [], {
          institutionId: value.institutionId, campusId: value.campusId,
        }, tx);
      const revision = expectedRevision + 1;
      tx.update(ref, {status: targetStatus, revision,
        responsibleNames,
        ...(publicationAudience || {}),
        ...(targetStatus === "published" ? {recipientUserIds: recipients} : {}),
        updatedAt: FieldValue.serverTimestamp(),
        [`${targetStatus}At`]: FieldValue.serverTimestamp(),
        [`${targetStatus}By`]: user.uid});
      tx.create(db.collection("event_history").doc(), {
        action: `event_${targetStatus}`, eventId, previousStatus: value.status,
        status: targetStatus, institutionId: value.institutionId,
        campusId: value.campusId, academicYearId: value.academicYearId,
        performedBy: user.uid, createdAt: FieldValue.serverTimestamp(),
      });
      if (recipients.length) {
        const title = targetStatus === "cancelled" ? "Evento cancelado" :
          targetStatus === "published" ? "Nuevo evento" : "Evento finalizado";
        tx.create(db.collection("event_notification_events").doc(), {
          eventId, recipientUserIds: recipients,
          institutionId: value.institutionId, campusId: value.campusId,
          academicYearId: value.academicYearId, title,
          body: `${value.title}: ${value.location}`,
          createdAt: FieldValue.serverTimestamp(),
        });
      }
      return {success: true, revision};
    });
  });

  const listarEventos = onCall(async (request) => {
    const user = await getCaller(request);
    if (!permission(user, "ver")) deny();
    if (!["Administrador", "Docente", "Estudiante", "Familiar"].includes(user.role)) deny();
    if (["Estudiante", "Familiar"].includes(user.role)) {
      const student = await checkedStudent(user, request.data?.studentId);
      const year = await activeYear(student.institution, student.campus);
      const snapshot = await completeSnapshot(db.collection("school_events")
          .where("institutionId", "==", student.institution)
          .where("campusId", "==", student.campus)
          .where("academicYearId", "==", year.id));
      const visible = snapshot.docs.filter((item) =>
        (["published", "closed"].includes(item.data().status) ||
          item.data().status === "cancelled" && !!item.data().publishedAt) &&
        item.data().targetStudentIds?.includes(student.id));
      const responseRefs = visible.map((item) =>
        db.collection("event_responses").doc(`${item.id}_${student.id}`));
      const attendanceRefs = visible.map((item) =>
        db.collection("event_attendance").doc(`${item.id}_${student.id}`));
      const responses = responseRefs.length ? await db.getAll(...responseRefs) : [];
      const attendance = attendanceRefs.length ? await db.getAll(...attendanceRefs) : [];
      return {student: {id: student.id,
        name: `${student.firstName || ""} ${student.lastName || ""}`.trim()},
      events: visible.map((item, index) => eventResponse(item, {
        myResponse: responses[index].exists ? responses[index].data().response : null,
        myAttendance: attendance[index].exists ? attendance[index].data().state : null,
      }, false)).sort((a, b) => a.startAtMillis - b.startAtMillis)};
    }
    const tenant = scope(user, request.data);
    const year = await activeYear(tenant.institutionId, tenant.campusId);
    const snapshot = await completeSnapshot(db.collection("school_events")
        .where("institutionId", "==", tenant.institutionId)
        .where("campusId", "==", tenant.campusId)
        .where("academicYearId", "==", year.id));
    let events = snapshot.docs;
    if (user.role === "Docente" && user.isSuperadmin !== true) {
      const groups = await teacherGroupIds(user, year);
      events = events.filter((item) => item.data().responsibleUserIds?.includes(user.uid) ||
        item.data().targetGroupIds?.some((groupId) => groups.has(groupId)));
    }
    return {events: events.map((item) => eventResponse(item, {},
        admin(user) || item.data().responsibleUserIds?.includes(user.uid)))
        .sort((a, b) => a.startAtMillis - b.startAtMillis)};
  });

  const responderEvento = onCall(async (request) => {
    const user = await getCaller(request);
    if (user.role !== "Familiar" || !permission(user, "ver")) deny();
    const student = await checkedStudent(user, request.data?.studentId);
    const eventId = id(request.data?.eventId, "evento");
    const response = request.data?.response;
    if (!["attending", "declined"].includes(response)) {
      throw new HttpsError("invalid-argument", "La respuesta no es válida.");
    }
    const eventRef = db.collection("school_events").doc(eventId);
    const responseRef = db.collection("event_responses").doc(`${eventId}_${student.id}`);
    return db.runTransaction(async (tx) => {
      const eventSnapshot = await tx.get(eventRef);
      const event = eventSnapshot.data() || {};
      if (!eventSnapshot.exists || !sameTenant(user, event) || event.status !== "published" ||
          !event.targetStudentIds?.includes(student.id)) deny();
      const actor = await mutationActor(tx, user, event);
      const studentSnapshot = await tx.get(db.collection("users").doc(student.id));
      const freshStudent = studentSnapshot.data() || {};
      if (actor.role !== "Familiar" || !permission(actor, "ver") || !sameTenant(actor, event) ||
          actor.activeStudentId !== student.id || !actor.studentIds?.includes(student.id) ||
          !studentSnapshot.exists || freshStudent.status !== "activo" ||
          freshStudent.role !== "Estudiante" || freshStudent.institution !== event.institutionId ||
          freshStudent.campus !== event.campusId) deny();
      if (!event.registrationRequired && !event.requiresFamilyAuthorization) {
        throw new HttpsError("failed-precondition", "Este evento no requiere respuesta.");
      }
      if (event.startAt.toMillis() <= Date.now()) {
        throw new HttpsError("failed-precondition", "El evento ya inició.");
      }
      const previous = await tx.get(responseRef);
      const before = previous.data()?.response || null;
      let confirmedCount = Number(event.confirmedCount || 0);
      if (before !== "attending" && response === "attending") confirmedCount++;
      if (before === "attending" && response !== "attending") confirmedCount--;
      if (response === "attending" && event.capacity && confirmedCount > event.capacity) {
        throw new HttpsError("resource-exhausted", "El evento ya completó su cupo.");
      }
      tx.set(responseRef, {
        eventId, studentId: student.id,
        studentName: `${student.firstName || ""} ${student.lastName || ""}`.trim(),
        response, respondedBy: user.uid,
        institutionId: event.institutionId, campusId: event.campusId,
        academicYearId: event.academicYearId,
        createdAt: previous.data()?.createdAt || FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.update(eventRef, {confirmedCount: Math.max(0, confirmedCount),
        updatedAt: FieldValue.serverTimestamp()});
      tx.create(db.collection("event_history").doc(), {
        action: "response_saved", eventId, studentId: student.id,
        before, response, institutionId: event.institutionId,
        campusId: event.campusId, academicYearId: event.academicYearId,
        performedBy: user.uid, createdAt: FieldValue.serverTimestamp(),
      });
      return {success: true, response};
    });
  });

  const guardarAsistenciaEvento = onCall(async (request) => {
    const user = await getCaller(request);
    const eventId = id(request.data?.eventId, "evento");
    const entries = Array.isArray(request.data?.entries) ? request.data.entries : [];
    if (!entries.length || entries.length > 400) {
      throw new HttpsError("invalid-argument", "La asistencia no es válida.");
    }
    const normalized = new Map();
    for (const entry of entries) {
      const studentId = id(entry?.studentId, "estudiante");
      if (normalized.has(studentId) || !ATTENDANCE_STATES.has(entry?.state)) {
        throw new HttpsError("invalid-argument", "Hay marcas duplicadas o no válidas.");
      }
      normalized.set(studentId, entry.state);
    }
    const eventRef = db.collection("school_events").doc(eventId);
    const eventSnapshot = await eventRef.get();
    if (!eventSnapshot.exists) deny();
    const event = eventSnapshot.data();
    await checkedManageEvent(user, event, "editar");
    if (!["published", "closed"].includes(event.status) || event.startAt.toMillis() > Date.now()) {
      throw new HttpsError("failed-precondition", "La asistencia se registra al iniciar el evento.");
    }
    for (const studentId of normalized.keys()) {
      if (!event.targetStudentIds?.includes(studentId)) deny("Hay un estudiante fuera del evento.");
    }
    const expectedRevision = Number(request.data?.expectedRevision);
    return db.runTransaction(async (tx) => {
      const fresh = await tx.get(eventRef);
      const value = fresh.data() || {};
      if (!fresh.exists || expectedRevision !== Number(value.attendanceRevision || 1)) {
        throw new HttpsError("aborted", "La asistencia cambió. Recarga antes de guardar.");
      }
      const actor = await mutationActor(tx, user, value);
      await checkedManageEvent(actor, value, "editar");
      if (!["published", "closed"].includes(value.status) || value.startAt.toMillis() > Date.now()) {
        throw new HttpsError("failed-precondition", "El evento ya no permite registrar asistencia.");
      }
      for (const studentId of normalized.keys()) {
        if (!value.targetStudentIds?.includes(studentId)) deny("Hay un estudiante fuera del evento.");
      }
      const priorRefs = [...normalized.keys()].map((studentId) =>
        db.collection("event_attendance").doc(`${eventId}_${studentId}`));
      const priorSnapshots = await tx.getAll(...priorRefs);
      const beforeByStudent = new Map(priorSnapshots.map((item) => [item.data()?.studentId, item.data()]));
      const changes = [];
      for (const [studentId, state] of normalized) {
        const before = beforeByStudent.get(studentId);
        if (before?.state === state) continue;
        changes.push({studentId, before: before?.state || null, after: state});
        tx.set(db.collection("event_attendance").doc(`${eventId}_${studentId}`), {
          eventId, studentId, studentName: value.studentNames?.[studentId] || studentId,
          state, institutionId: value.institutionId, campusId: value.campusId,
          academicYearId: value.academicYearId,
          firstMarkedBy: before?.firstMarkedBy || before?.markedBy || user.uid,
          firstMarkedAt: before?.firstMarkedAt || before?.updatedAt || FieldValue.serverTimestamp(),
          markedBy: user.uid, updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }
      if (!changes.length) return {success: true, saved: 0, revision: expectedRevision};
      const revision = expectedRevision + 1;
      tx.update(eventRef, {attendanceRevision: revision,
        updatedAt: FieldValue.serverTimestamp()});
      tx.create(db.collection("event_history").doc(), {
        action: "attendance_saved", eventId,
        studentIds: changes.map((change) => change.studentId), changes, institutionId: value.institutionId,
        campusId: value.campusId, academicYearId: value.academicYearId,
        attendanceRevision: revision, performedBy: user.uid,
        createdAt: FieldValue.serverTimestamp(),
      });
      return {success: true, saved: changes.length, revision};
    });
  });

  const obtenerAsistenciaEvento = onCall(async (request) => {
    const user = await getCaller(request);
    const eventId = id(request.data?.eventId, "evento");
    const snapshot = await db.collection("school_events").doc(eventId).get();
    if (!snapshot.exists) deny();
    const event = snapshot.data();
    await checkedManageEvent(user, event, "ver");
    const studentIds = event.targetStudentIds || [];
    const responseRefs = studentIds.map((studentId) =>
      db.collection("event_responses").doc(`${eventId}_${studentId}`));
    const attendanceRefs = studentIds.map((studentId) =>
      db.collection("event_attendance").doc(`${eventId}_${studentId}`));
    const responses = responseRefs.length ? await db.getAll(...responseRefs) : [];
    const attendance = attendanceRefs.length ? await db.getAll(...attendanceRefs) : [];
    return {event: eventResponse(snapshot), roster: studentIds.map((studentId, index) => ({
      studentId,
      studentName: event.studentNames?.[studentId] || studentId,
      response: responses[index].exists ? responses[index].data().response : null,
      state: attendance[index].exists ? attendance[index].data().state : null,
    })).sort((a, b) => a.studentName.localeCompare(b.studentName))};
  });

  const generarReporteEventos = onCall(async (request) => {
    const user = await getCaller(request);
    if (!["Administrador", "Docente"].includes(user.role) || !permission(user, "ver")) deny();
    const tenant = scope(user, request.data);
    const year = await activeYear(tenant.institutionId, tenant.campusId);
    const fromMillis = millis(request.data?.fromMillis, "fecha inicial");
    const toMillis = millis(request.data?.toMillis, "fecha final");
    if (toMillis < fromMillis || toMillis - fromMillis > 366 * 86400000) {
      throw new HttpsError("invalid-argument", "El rango debe estar entre 1 y 366 días.");
    }
    const requestedStatus = request.data?.status;
    if (requestedStatus != null && !EVENT_STATES.has(requestedStatus)) {
      throw new HttpsError("invalid-argument", "El estado del reporte no es válido.");
    }
    const snapshot = await completeSnapshot(db.collection("school_events")
        .where("institutionId", "==", tenant.institutionId)
        .where("campusId", "==", tenant.campusId)
        .where("academicYearId", "==", year.id)
        .where("startAt", ">=", Timestamp.fromMillis(fromMillis))
        .where("startAt", "<=", Timestamp.fromMillis(toMillis)));
    let rows = snapshot.docs.filter((item) => {
      const value = item.data();
      const start = value.startAt?.toMillis?.();
      return Number.isFinite(start) && start >= fromMillis && start <= toMillis &&
        (requestedStatus == null || value.status === requestedStatus);
    });
    if (user.role === "Docente" && user.isSuperadmin !== true) {
      const groups = await teacherGroupIds(user, year);
      rows = rows.filter((item) => item.data().responsibleUserIds?.includes(user.uid) ||
        item.data().targetGroupIds?.some((groupId) => groups.has(groupId)));
    }
    return {fromMillis, toMillis, count: rows.length,
      rows: rows.map((item) => {
        const value = item.data();
        return {id: item.id, title: value.title, location: value.location,
          status: value.status, startAtMillis: value.startAt.toMillis(),
          endAtMillis: value.endAt.toMillis(),
          targetCount: value.targetStudentIds?.length || 0,
          confirmedCount: Number(value.confirmedCount || 0)};
      }).sort((a, b) => a.startAtMillis - b.startAtMillis)};
  });

  const procesarRecordatoriosEventos = onSchedule({
    schedule: "every 15 minutes", timeoutSeconds: 540, maxInstances: 1,
  }, async () => {
    const now = Date.now();
    const until = now + 24 * 60 * 60 * 1000;
    const query = db.collection("school_events")
        .where("status", "==", "published")
        .where("startAt", ">", Timestamp.fromMillis(now))
        .where("startAt", "<=", Timestamp.fromMillis(until))
        .orderBy("startAt").limit(500);
    let cursor = null;
    // Page past previously reminded events; they must not starve later pages.
    while (true) {
      const snapshot = await (cursor ? query.startAfter(cursor) : query).get();
      if (snapshot.empty) break;
      for (const item of snapshot.docs) {
        const initial = item.data();
        if (initial.reminderSentAt) continue;
        const eventRef = item.ref;
        const notificationRef = db.collection("event_notification_events")
            .doc(`reminder_${item.id}`);
        await db.runTransaction(async (tx) => {
          const [fresh, notification] = await Promise.all([
            tx.get(eventRef), tx.get(notificationRef),
          ]);
          const value = fresh.data() || {};
          const startAt = value.startAt?.toMillis?.();
          if (!fresh.exists || notification.exists || value.status !== "published" ||
            value.reminderSentAt || !Number.isFinite(startAt) ||
            startAt <= Date.now() || startAt > Date.now() + 24 * 60 * 60 * 1000) return;
          const yearSnapshot = await tx.get(db.collection("academic_years").doc(value.academicYearId));
          const year = yearSnapshot.data() || {};
          if (!yearSnapshot.exists || year.status !== "active" ||
            year.institutionId !== value.institutionId || year.campusId !== value.campusId) return;
          // Publication audience is historical. Re-resolve active linked families
          // and current responsible staff for each future notification.
          const recipients = await recipientUsers(value.targetStudentIds || [],
              value.responsibleUserIds || [], {
                institutionId: value.institutionId, campusId: value.campusId,
              }, tx);
          tx.update(eventRef, {reminderSentAt: FieldValue.serverTimestamp()});
          tx.create(notificationRef, {
            eventId: item.id,
            recipientUserIds: recipients,
            institutionId: value.institutionId,
            campusId: value.campusId,
            academicYearId: value.academicYearId,
            title: "Recordatorio de evento",
            body: `${value.title}: ${value.location}`,
            kind: "reminder",
            createdAt: FieldValue.serverTimestamp(),
          });
        });
      }
      cursor = snapshot.docs[snapshot.docs.length - 1];
      if (snapshot.size < 500) break;
    }
  });

  return {
    listarContextosEventos,
    guardarEvento,
    cambiarEstadoEvento,
    listarEventos,
    responderEvento,
    guardarAsistenciaEvento,
    obtenerAsistenciaEvento,
    generarReporteEventos,
    procesarRecordatoriosEventos,
  };
}

module.exports = {eventFunctions};
/* eslint-enable max-len */
