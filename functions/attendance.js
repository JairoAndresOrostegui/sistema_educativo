"use strict";
/* eslint-disable max-len */

const crypto = require("crypto");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {FieldValue} = require("firebase-admin/firestore");

const STATES = new Set(["present", "absent", "late", "excused"]);
const isoDay = () => new Intl.DateTimeFormat("en-CA", {
  timeZone: "America/Bogota",
}).format(new Date());
const hash = (value) => crypto.createHash("sha256").update(value).digest("hex");

function attendanceFunctions(db, getCaller, activeYear) {
  const deny = (message = "No tienes acceso a esta asistencia.") => {
    throw new HttpsError("permission-denied", message);
  };
  const permission = (user, action) => user.isSuperadmin === true ||
    Array.isArray(user.permissions) &&
    user.permissions.includes(`asistencia.${action}`);
  const staff = (user) => ["Administrador", "Docente"].includes(user.role);
  const admin = (user, action = "ver") => user.isSuperadmin === true ||
    user.role === "Administrador" && permission(user, action);
  const sameTenant = (user, value) => user.isSuperadmin === true ||
    user.institution === value.institutionId &&
    user.campus === value.campusId;
  const id = (value, label = "identificador") => {
    if (typeof value !== "string" || !value.trim() || value.includes("/") ||
        value.length > 160) {
      throw new HttpsError("invalid-argument", `${label} no es válido.`);
    }
    return value.trim();
  };
  const date = (value) => {
    if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value) ||
        Number.isNaN(Date.parse(`${value}T12:00:00Z`)) ||
        new Date(`${value}T12:00:00Z`).toISOString().slice(0, 10) !== value) {
      throw new HttpsError("invalid-argument", "La fecha no es válida.");
    }
    if (value > isoDay()) {
      throw new HttpsError(
          "failed-precondition", "No se puede registrar asistencia futura.",
      );
    }
    return value;
  };
  const scope = (user, input) => {
    const institutionId = user.isSuperadmin === true ?
      id(input?.institutionId || user.institution, "institución") :
      user.institution;
    const campusId = user.isSuperadmin === true ?
      id(input?.campusId || user.campus, "sede") : user.campus;
    if (!sameTenant(user, {institutionId, campusId})) deny();
    return {institutionId, campusId};
  };
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
      throw new HttpsError("failed-precondition", "El año lectivo de la asistencia está cerrado. Solo puede consultarse.");
    }
    return {...actor, uid: user.uid};
  };
  const completeSnapshot = async (query) => {
    const snapshot = await query.limit(5001).get();
    if (snapshot.size > 5000) {
      throw new HttpsError("resource-exhausted", "La consulta supera 5000 registros. Reduce el rango o selecciona un grupo en el reporte.");
    }
    return snapshot;
  };
  const teacherGroups = async (user, year) => {
    const subjects = await db.collection("subjects")
        .where("academicYearId", "==", year.id)
        .where("teacherId", "==", user.uid).get();
    const groups = new Set(subjects.docs.map((item) => item.data().groupId));
    if (typeof user.tutorGroupId === "string" && user.tutorGroupId) {
      groups.add(user.tutorGroupId);
    }
    return {subjects: subjects.docs, groupIds: groups};
  };
  const checkedGroup = async (groupId, tenant, year) => {
    const snapshot = await db.collection("academic_groups").doc(groupId).get();
    const group = snapshot.data() || {};
    if (!snapshot.exists || group.active !== true ||
        group.institutionId !== tenant.institutionId ||
        group.campusId !== tenant.campusId ||
        group.academicYearId !== year.id) deny("El grupo no está vigente.");
    return {id: snapshot.id, ...group};
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
    if (!snapshot.exists || student.status !== "activo" ||
        student.role !== "Estudiante" || student.institution !== user.institution ||
        student.campus !== user.campus) deny();
    return {id: snapshot.id, ...student};
  };
  const canOperateSession = async (user, session, action) => {
    if (!sameTenant(user, session) || !staff(user) || !permission(user, action)) {
      deny();
    }
    if (admin(user, action)) return;
    if (user.role !== "Docente" || session.responsibleTeacherId !== user.uid) {
      deny("La sesión pertenece a otro responsable.");
    }
  };
  const sessionResponse = (snapshot) => {
    const value = snapshot.data();
    return {
      id: snapshot.id,
      institutionId: value.institutionId,
      campusId: value.campusId,
      academicYearId: value.academicYearId,
      academicYear: value.academicYear,
      groupId: value.groupId,
      groupName: value.groupName,
      subjectId: value.subjectId || null,
      subjectName: value.subjectName || null,
      sessionType: value.sessionType,
      date: value.date,
      status: value.status,
      responsibleTeacherId: value.responsibleTeacherId,
      responsibleTeacherName: value.responsibleTeacherName,
      revision: Number(value.revision || 1),
      studentCount: Array.isArray(value.studentIds) ? value.studentIds.length : 0,
      markedCount: Number(value.markedCount || 0),
      createdAtMillis: value.createdAt?.toMillis?.() || null,
      closedAtMillis: value.closedAt?.toMillis?.() || null,
    };
  };

  const listarContextosAsistencia = onCall(async (request) => {
    const user = await getCaller(request);
    if (!staff(user) || !permission(user, "ver")) deny();
    const tenant = scope(user, request.data);
    const year = await activeYear(tenant.institutionId, tenant.campusId);
    let groups = await db.collection("academic_groups")
        .where("institutionId", "==", tenant.institutionId)
        .where("campusId", "==", tenant.campusId)
        .where("academicYearId", "==", year.id)
        .where("active", "==", true).get();
    let subjects = await db.collection("subjects")
        .where("institutionId", "==", tenant.institutionId)
        .where("campusId", "==", tenant.campusId)
        .where("academicYearId", "==", year.id).get();
    if (user.role === "Docente" && user.isSuperadmin !== true) {
      const workload = await teacherGroups(user, year);
      groups = {docs: groups.docs.filter((item) =>
        workload.groupIds.has(item.id))};
      subjects = {docs: subjects.docs.filter((item) =>
        item.data().teacherId === user.uid)};
    }
    return {
      academicYearId: year.id,
      academicYear: year.year,
      groups: groups.docs.map((item) => ({
        id: item.id, name: item.data().name,
      })).sort((a, b) => a.name.localeCompare(b.name)),
      subjects: subjects.docs.map((item) => ({
        id: item.id,
        name: item.data().subject,
        groupId: item.data().groupId,
        teacherId: item.data().teacherId,
        teacherName: item.data().teacherName,
      })).sort((a, b) => a.name.localeCompare(b.name)),
    };
  });

  const abrirSesionAsistencia = onCall(async (request) => {
    const user = await getCaller(request);
    if (!staff(user) || !permission(user, "crear")) deny();
    const input = request.data || {};
    const tenant = scope(user, input);
    const year = await activeYear(tenant.institutionId, tenant.campusId);
    const group = await checkedGroup(id(input.groupId, "grupo"), tenant, year);
    const attendanceDate = date(input.date || isoDay());
    if (Number(attendanceDate.slice(0, 4)) !== Number(year.year)) {
      throw new HttpsError(
          "failed-precondition",
          "La fecha debe pertenecer al año académico activo.",
      );
    }
    const subjectId = typeof input.subjectId === "string" && input.subjectId ?
      id(input.subjectId, "asignatura") : null;
    let subject = null;
    if (subjectId) {
      const snapshot = await db.collection("subjects").doc(subjectId).get();
      subject = snapshot.data();
      if (!snapshot.exists || subject.academicYearId !== year.id ||
          subject.groupId !== group.id ||
          subject.institutionId !== tenant.institutionId ||
          subject.campusId !== tenant.campusId) deny("Asignatura fuera del grupo.");
    }
    if (user.role === "Docente" && user.isSuperadmin !== true) {
      const workload = await teacherGroups(user, year);
      const allowed = subject ? subject.teacherId === user.uid :
        user.tutorGroupId === group.id;
      if (!allowed || !workload.groupIds.has(group.id)) {
        deny("No tienes carga docente para abrir esta sesión.");
      }
    }
    const students = await db.collection("users")
        .where("institution", "==", tenant.institutionId)
        .where("campus", "==", tenant.campusId)
        .where("role", "==", "Estudiante")
        .where("status", "==", "activo")
        .where("groupId", "==", group.id).get();
    if (students.empty) {
      throw new HttpsError("failed-precondition", "El grupo no tiene estudiantes activos.");
    }
    if (students.size > 200) {
      throw new HttpsError("resource-exhausted", "El grupo supera 200 estudiantes.");
    }
    const sessionType = subject ? "subject" : "daily";
    const stableId = hash([
      tenant.institutionId, tenant.campusId, year.id, group.id,
      attendanceDate, subjectId || "daily",
    ].join("\u0000"));
    const ref = db.collection("attendance_sessions").doc(stableId);
    const teacherId = user.role === "Docente" ? user.uid :
      (typeof input.responsibleTeacherId === "string" ?
        id(input.responsibleTeacherId, "responsable") : user.uid);
    let teacherName = `${user.firstName || ""} ${user.lastName || ""}`.trim();
    if (teacherId !== user.uid) {
      if (!admin(user, "crear")) deny();
      const teacherSnapshot = await db.collection("users").doc(teacherId).get();
      const teacher = teacherSnapshot.data() || {};
      if (!teacherSnapshot.exists || teacher.status !== "activo" ||
          !["Docente", "Administrador"].includes(teacher.role) ||
          teacher.institution !== tenant.institutionId ||
          teacher.campus !== tenant.campusId) deny("Responsable fuera de la sede.");
      teacherName = `${teacher.firstName || ""} ${teacher.lastName || ""}`.trim();
    }
    const roster = students.docs.map((item) => ({
      id: item.id,
      name: `${item.data().firstName || ""} ${item.data().lastName || ""}`.trim(),
    })).sort((a, b) => a.name.localeCompare(b.name));
    const value = {
      ...tenant,
      academicYearId: year.id,
      academicYear: year.year,
      groupId: group.id,
      groupName: group.name,
      subjectId,
      subjectName: subject?.subject || null,
      sessionType,
      date: attendanceDate,
      status: "open",
      responsibleTeacherId: teacherId,
      responsibleTeacherName: teacherName,
      studentIds: roster.map((item) => item.id),
      studentNames: Object.fromEntries(roster.map((item) => [item.id, item.name])),
      markedCount: 0,
      revision: 1,
      createdBy: user.uid,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };
    try {
      await db.runTransaction(async (tx) => {
        const actor = await mutationActor(tx, user, value);
        if (!staff(actor) || !sameTenant(actor, value) || !permission(actor, "crear")) deny();
        const freshGroup = (await tx.get(db.collection("academic_groups").doc(group.id))).data() || {};
        if (freshGroup.active !== true || freshGroup.institutionId !== tenant.institutionId ||
            freshGroup.campusId !== tenant.campusId || freshGroup.academicYearId !== year.id) deny("El grupo no está vigente.");
        if (subjectId) {
          const freshSubject = (await tx.get(db.collection("subjects").doc(subjectId))).data() || {};
          if (freshSubject.groupId !== group.id || freshSubject.academicYearId !== year.id ||
              freshSubject.institutionId !== tenant.institutionId || freshSubject.campusId !== tenant.campusId ||
              (actor.role === "Docente" && actor.isSuperadmin !== true && freshSubject.teacherId !== actor.uid)) deny();
        } else if (actor.role === "Docente" && actor.isSuperadmin !== true && actor.tutorGroupId !== group.id) deny();
        if ((await tx.get(ref)).exists) {
          throw new HttpsError(
              "already-exists", "Ya existe esa asistencia para el grupo y fecha.",
          );
        }
        tx.create(ref, value);
        tx.create(db.collection("attendance_history").doc(), {
          action: "session_opened", sessionId: ref.id, ...tenant,
          academicYearId: year.id, groupId: group.id,
          performedBy: user.uid, createdAt: FieldValue.serverTimestamp(),
        });
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      throw error;
    }
    return {sessionId: ref.id, revision: 1, roster};
  });

  const listarSesionesAsistencia = onCall(async (request) => {
    const user = await getCaller(request);
    if (!staff(user) || !permission(user, "ver")) deny();
    const tenant = scope(user, request.data);
    const year = await activeYear(tenant.institutionId, tenant.campusId);
    let query = db.collection("attendance_sessions")
        .where("institutionId", "==", tenant.institutionId)
        .where("campusId", "==", tenant.campusId)
        .where("academicYearId", "==", year.id);
    if (user.role === "Docente" && user.isSuperadmin !== true) {
      query = query.where("responsibleTeacherId", "==", user.uid);
    }
    const snapshot = await completeSnapshot(query);
    let sessions = snapshot.docs;
    if (user.role === "Docente" && user.isSuperadmin !== true) {
      sessions = sessions.filter((item) =>
        item.data().responsibleTeacherId === user.uid);
    }
    return {sessions: sessions.map(sessionResponse).sort((a, b) =>
      b.date.localeCompare(a.date) || b.createdAtMillis - a.createdAtMillis)};
  });

  const obtenerSesionAsistencia = onCall(async (request) => {
    const user = await getCaller(request);
    const sessionId = id(request.data?.sessionId, "sesión");
    const snapshot = await db.collection("attendance_sessions").doc(sessionId).get();
    if (!snapshot.exists) deny();
    const session = snapshot.data();
    await canOperateSession(user, session, "ver");
    const records = await db.collection("attendance_records")
        .where("sessionId", "==", sessionId).get();
    const byStudent = Object.fromEntries(records.docs.map((item) => [
      item.data().studentId,
      {
        state: item.data().state,
        observation: item.data().observation || "",
        updatedAtMillis: item.data().updatedAt?.toMillis?.() || null,
      },
    ]));
    const roster = (session.studentIds || []).map((studentId) => ({
      id: studentId,
      name: session.studentNames?.[studentId] || studentId,
      ...byStudent[studentId],
    }));
    return {session: sessionResponse(snapshot), roster};
  });

  const guardarAsistencia = onCall(async (request) => {
    const user = await getCaller(request);
    const sessionId = id(request.data?.sessionId, "sesión");
    const entries = Array.isArray(request.data?.entries) ? request.data.entries : [];
    const expectedRevision = Number(request.data?.expectedRevision);
    if (!Number.isInteger(expectedRevision) || expectedRevision < 1 ||
        !entries.length || entries.length > 200) {
      throw new HttpsError("invalid-argument", "La lista o revisión no es válida.");
    }
    const normalized = new Map();
    for (const entry of entries) {
      const studentId = id(entry?.studentId, "estudiante");
      if (normalized.has(studentId) || !STATES.has(entry?.state)) {
        throw new HttpsError("invalid-argument", "Hay marcas duplicadas o no válidas.");
      }
      const observation = typeof entry.observation === "string" ?
        entry.observation.trim() : "";
      if (observation.length > 500) {
        throw new HttpsError("invalid-argument", "La observación supera 500 caracteres.");
      }
      normalized.set(studentId, {studentId, state: entry.state, observation});
    }
    const sessionRef = db.collection("attendance_sessions").doc(sessionId);
    return db.runTransaction(async (tx) => {
      const snapshot = await tx.get(sessionRef);
      if (!snapshot.exists) deny();
      const session = snapshot.data();
      const action = session.status === "closed" ? "editar" : "crear";
      const actor = await mutationActor(tx, user, session);
      await canOperateSession(actor, session, action);
      if (!["open", "closed"].includes(session.status)) deny();
      if (session.status === "closed" && !admin(actor, "editar")) {
        deny("Solo administración corrige una sesión cerrada.");
      }
      if (Number(session.revision || 1) !== expectedRevision) {
        throw new HttpsError("aborted", "La asistencia cambió. Recarga antes de guardar.");
      }
      const roster = new Set(session.studentIds || []);
      for (const studentId of normalized.keys()) {
        if (!roster.has(studentId)) deny("La lista contiene un estudiante ajeno.");
      }
      const refs = [...normalized.keys()].map((studentId) =>
        db.collection("attendance_records").doc(`${sessionId}_${studentId}`));
      const previous = refs.length ? await tx.getAll(...refs) : [];
      const changes = [];
      refs.forEach((ref, index) => {
        const entry = normalized.get([...normalized.keys()][index]);
        const before = previous[index].data() || null;
        if (before?.state === entry.state &&
            (before?.observation || "") === entry.observation) return;
        changes.push({
          studentId: entry.studentId,
          before: before ? {state: before.state, observation: before.observation || ""} : null,
          after: {state: entry.state, observation: entry.observation},
        });
        tx.set(ref, {
          sessionId,
          studentId: entry.studentId,
          studentName: session.studentNames?.[entry.studentId] || entry.studentId,
          state: entry.state,
          observation: entry.observation,
          institutionId: session.institutionId,
          campusId: session.campusId,
          academicYearId: session.academicYearId,
          academicYear: session.academicYear,
          groupId: session.groupId,
          groupName: session.groupName,
          subjectId: session.subjectId || null,
          subjectName: session.subjectName || null,
          sessionType: session.sessionType,
          responsibleTeacherId: session.responsibleTeacherId,
          responsibleTeacherName: session.responsibleTeacherName,
          date: session.date,
          firstMarkedBy: before?.firstMarkedBy || user.uid,
          firstMarkedAt: before?.firstMarkedAt || FieldValue.serverTimestamp(),
          updatedBy: user.uid,
          updatedAt: FieldValue.serverTimestamp(),
        });
      });
      if (!changes.length) return {success: true, revision: expectedRevision};
      const nextRevision = expectedRevision + 1;
      const existingIds = new Set(previous.filter((item) => item.exists)
          .map((item) => item.data().studentId));
      const addedCount = changes.filter((item) => !existingIds.has(item.studentId)).length;
      tx.update(sessionRef, {
        markedCount: Math.min(roster.size, Number(session.markedCount || 0) + addedCount),
        revision: nextRevision,
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.create(db.collection("attendance_history").doc(), {
        action: session.status === "closed" ? "records_corrected" : "records_saved",
        sessionId, institutionId: session.institutionId,
        campusId: session.campusId, academicYearId: session.academicYearId,
        groupId: session.groupId, changes, performedBy: user.uid,
        createdAt: FieldValue.serverTimestamp(),
      });
      if (session.status === "closed") {
        tx.create(db.collection("attendance_notification_events").doc(), {
          sessionId,
          studentIds: changes.map((item) => item.studentId),
          institutionId: session.institutionId,
          campusId: session.campusId,
          academicYearId: session.academicYearId,
          title: "Corrección de asistencia",
          body: `Se corrigió un registro de asistencia en ${session.groupName}.`,
          createdAt: FieldValue.serverTimestamp(),
        });
      }
      return {success: true, revision: nextRevision};
    });
  });

  const cerrarSesionAsistencia = onCall(async (request) => {
    const user = await getCaller(request);
    const sessionId = id(request.data?.sessionId, "sesión");
    const expectedRevision = Number(request.data?.expectedRevision);
    const ref = db.collection("attendance_sessions").doc(sessionId);
    return db.runTransaction(async (tx) => {
      const snapshot = await tx.get(ref);
      if (!snapshot.exists) deny();
      const session = snapshot.data();
      const actor = await mutationActor(tx, user, session);
      await canOperateSession(actor, session, "crear");
      if (session.status !== "open") {
        throw new HttpsError("failed-precondition", "La sesión ya está cerrada.");
      }
      if (Number(session.revision || 1) !== expectedRevision) {
        throw new HttpsError("aborted", "La asistencia cambió. Recarga antes de cerrar.");
      }
      if (Number(session.markedCount || 0) !== (session.studentIds || []).length) {
        throw new HttpsError("failed-precondition", "Marca a todos los estudiantes antes de cerrar.");
      }
      const records = await tx.get(db.collection("attendance_records")
          .where("sessionId", "==", sessionId));
      const validRecords = new Map(records.docs.map((item) => [item.data().studentId, item.data()]));
      if (!(session.studentIds || []).every((studentId) => STATES.has(validRecords.get(studentId)?.state))) {
        throw new HttpsError("failed-precondition", "Faltan marcas válidas. Recarga y completa la lista antes de cerrar.");
      }
      const notifyStudentIds = records.docs.filter((item) =>
        ["absent", "late"].includes(item.data().state))
          .map((item) => item.data().studentId);
      const nextRevision = expectedRevision + 1;
      tx.update(ref, {
        status: "closed", revision: nextRevision, closedBy: user.uid,
        closedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
      });
      tx.create(db.collection("attendance_history").doc(), {
        action: "session_closed", sessionId,
        institutionId: session.institutionId, campusId: session.campusId,
        academicYearId: session.academicYearId, groupId: session.groupId,
        performedBy: user.uid, createdAt: FieldValue.serverTimestamp(),
      });
      if (notifyStudentIds.length) {
        tx.create(db.collection("attendance_notification_events").doc(), {
          sessionId, studentIds: notifyStudentIds,
          institutionId: session.institutionId, campusId: session.campusId,
          academicYearId: session.academicYearId,
          title: "Novedad de asistencia",
          body: `Se registró una ausencia o llegada tarde en ${session.groupName}.`,
          createdAt: FieldValue.serverTimestamp(),
        });
      }
      return {success: true, revision: nextRevision};
    });
  });

  const consultarMiAsistencia = onCall(async (request) => {
    const user = await getCaller(request);
    if (!permission(user, "ver")) deny();
    const student = await checkedStudent(user, request.data?.studentId);
    const year = await activeYear(student.institution, student.campus);
    const snapshot = await completeSnapshot(db.collection("attendance_records")
        .where("academicYearId", "==", year.id)
        .where("studentId", "==", student.id));
    const sessionRefs = [...new Set(snapshot.docs.map((item) =>
      item.data().sessionId))].map((sessionId) =>
      db.collection("attendance_sessions").doc(sessionId));
    const sessionSnapshots = sessionRefs.length ?
      await db.getAll(...sessionRefs) : [];
    const closedSessionIds = new Set(sessionSnapshots
        .filter((item) => item.exists && item.data().status === "closed" &&
          item.data().institutionId === student.institution && item.data().campusId === student.campus &&
          item.data().academicYearId === year.id && item.data().studentIds?.includes(student.id))
        .map((item) => item.id));
    const records = snapshot.docs.filter((item) =>
      closedSessionIds.has(item.data().sessionId)).map((item) => {
      const value = item.data();
      return {
        id: item.id, sessionId: value.sessionId, date: value.date,
        groupName: value.groupName, state: value.state,
        observation: value.observation || "",
        updatedAtMillis: value.updatedAt?.toMillis?.() || null,
      };
    }).sort((a, b) => b.date.localeCompare(a.date));
    return {student: {id: student.id,
      name: `${student.firstName || ""} ${student.lastName || ""}`.trim()}, records};
  });

  const generarReporteAsistencia = onCall(async (request) => {
    const user = await getCaller(request);
    if (!staff(user) || !permission(user, "ver")) deny();
    const input = request.data || {};
    const tenant = scope(user, input);
    const year = await activeYear(tenant.institutionId, tenant.campusId);
    const dateFrom = date(input.dateFrom);
    const dateTo = date(input.dateTo);
    if (dateFrom > dateTo) {
      throw new HttpsError("invalid-argument", "El rango de fechas no es válido.");
    }
    const days = Math.floor((Date.parse(`${dateTo}T12:00:00Z`) -
      Date.parse(`${dateFrom}T12:00:00Z`)) / 86400000);
    if (days > 366) {
      throw new HttpsError("invalid-argument", "El reporte admite hasta 366 días.");
    }
    const groupId = typeof input.groupId === "string" && input.groupId ?
      id(input.groupId, "grupo") : null;
    const studentId = typeof input.studentId === "string" && input.studentId ?
      id(input.studentId, "estudiante") : null;
    if (groupId) await checkedGroup(groupId, tenant, year);
    let query = db.collection("attendance_sessions")
        .where("institutionId", "==", tenant.institutionId)
        .where("campusId", "==", tenant.campusId)
        .where("academicYearId", "==", year.id)
        .where("date", ">=", dateFrom).where("date", "<=", dateTo);
    if (groupId) query = query.where("groupId", "==", groupId);
    if (user.role === "Docente" && user.isSuperadmin !== true) {
      query = query.where("responsibleTeacherId", "==", user.uid);
    }
    const snapshot = await completeSnapshot(query);
    let sessions = snapshot.docs.filter((item) => {
      const value = item.data();
      return value.status === "closed" && value.date >= dateFrom &&
        value.date <= dateTo && (!groupId || value.groupId === groupId);
    });
    if (user.role === "Docente" && user.isSuperadmin !== true) {
      sessions = sessions.filter((item) =>
        item.data().responsibleTeacherId === user.uid);
    }
    const sessionById = new Map(sessions.map((item) => [item.id, item.data()]));
    const rows = [];
    const sessionIds = [...sessionById.keys()];
    for (let offset = 0; offset < sessionIds.length; offset += 30) {
      const chunk = sessionIds.slice(offset, offset + 30);
      const records = await db.collection("attendance_records")
          .where("sessionId", "in", chunk).get();
      for (const record of records.docs) {
        const value = record.data();
        if (studentId && value.studentId !== studentId) continue;
        const session = sessionById.get(value.sessionId);
        rows.push({
          date: session.date,
          groupName: session.groupName,
          subjectName: session.subjectName || "Jornada completa",
          studentId: value.studentId,
          studentName: value.studentName,
          state: value.state,
          observation: value.observation || "",
          responsibleTeacherName: session.responsibleTeacherName || "",
        });
      }
    }
    rows.sort((a, b) => b.date.localeCompare(a.date) ||
      a.studentName.localeCompare(b.studentName));
    if (rows.length > 5000) {
      throw new HttpsError(
          "resource-exhausted",
          "El reporte supera 5000 registros. Reduce el rango o selecciona un grupo.",
      );
    }
    const summary = Object.fromEntries([...STATES].map((state) => [
      state, rows.filter((row) => row.state === state).length,
    ]));
    return {dateFrom, dateTo, sessionCount: sessions.length,
      recordCount: rows.length, summary, rows};
  });

  return {
    listarContextosAsistencia,
    abrirSesionAsistencia,
    listarSesionesAsistencia,
    obtenerSesionAsistencia,
    guardarAsistencia,
    cerrarSesionAsistencia,
    consultarMiAsistencia,
    generarReporteAsistencia,
  };
}

module.exports = {attendanceFunctions};
/* eslint-enable max-len */
