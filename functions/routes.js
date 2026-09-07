"use strict";
/* eslint-disable max-len */
const crypto = require("crypto");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {FieldValue, Timestamp} = require("firebase-admin/firestore");
const hash = (s) => crypto.createHash("sha256").update(s).digest("hex");
const day = () => new Intl.DateTimeFormat("en-CA", {timeZone: "America/Bogota"}).format(new Date());

function routeFunctions(db, getCaller, activeYear) {
  const fail = (message = "No tienes acceso a esta ruta.") => {
    throw new HttpsError("permission-denied", message);
  };
  const same = (u, d) => u.isSuperadmin === true || u.institution === d.institution && u.campus === d.campus;
  const admin = (u, action) => u.isSuperadmin === true || u.role === "Administrador" && (u.permissions || []).includes(`rutas.${action}`);
  const operator = (u, d) => same(u, d) && (admin(u, "editar") || d.gestionador === u.uid && ["Docente", "Administrador", "Auxiliar"].includes(u.role) && (u.permissions || []).includes("rutas.ver"));
  const ident = (v) => {
    if (typeof v !== "string" || !v || v.includes("/") || v.length > 150) fail(); return v;
  };
  const text = (v, max = 200) => {
    if (typeof v !== "string" || !v.trim() || v.length > max) throw new HttpsError("invalid-argument", "Completa los campos requeridos."); return v.trim();
  };
  const scope = (u, data) => {
    const d = {institution: data.institution || u.institution, campus: data.campus || u.campus};
    if (!same(u, d)) fail(); return d;
  };
  const audit = (tx, u, d, action, extra = {}) => tx.create(db.collection("route_history").doc(), {
    institution: d.institution, campus: d.campus, academicYearId: d.academicYearId,
    academicYear: d.academicYear, routeId: d.idRuta || null, dailyRouteId: d.dailyId || null,
    performedBy: u.uid, action, createdAt: FieldValue.serverTimestamp(), ...extra,
  });
  const event = (tx, id, d, studentIds, title, body) => {
    tx.set(db.collection("route_push_events").doc(hash(id)), {
      institution: d.institution, campus: d.campus, academicYearId: d.academicYearId,
      academicYear: d.academicYear, dailyRouteId: d.dailyId, studentIds: [...new Set(studentIds)],
      title, body, createdAt: FieldValue.serverTimestamp(),
    });
  };
  async function checkedYear(tx, d) {
    const year = (await tx.get(db.doc(`academic_years/${ident(d.academicYearId)}`))).data();
    if (!year || year.status !== "active") throw new HttpsError("failed-precondition", "El año está cerrado.");
  }
  // Opens all due stops, not just the next one. No Maps request here.
  function openWindows(tx, ref, d, students) {
    const groups = new Map();
    for (const s of students) {
      if (!s.activo || s.recogido || s.anulado || s.mapEnabled ||
          !s.estimatedArrivalAt || s.estimatedArrivalAt.toMillis() > Date.now() + 600000) continue;
      tx.update(ref.collection("students").doc(s.id), {mapEnabled: true, approachNotifiedAt: FieldValue.serverTimestamp()});
      const key = s.direccion.trim().toLocaleLowerCase();
      if (!groups.has(key)) groups.set(key, []);
      groups.get(key).push(s.id);
    }
    for (const [key, ids] of groups) {
      event(tx, `${ref.id}:approach:${hash(key)}`, {...d, dailyId: ref.id}, ids,
          "Prepárense para la recogida", "Llegada estimada en 10 minutos o menos. Ya puedes ver el mapa en Rutas. El tiempo puede variar.");
    }
  }
  async function child(u, id) {
    ident(id);
    if (u.role === "Familiar" && (!(u.studentIds || []).includes(id) || u.activeStudentId !== id)) fail("Selecciona un hijo vinculado.");
    if (u.role === "Estudiante" && u.uid !== id) fail();
    const d = (await db.doc(`users/${id}`).get()).data();
    if (!d || d.status !== "activo" || d.role !== "Estudiante" || !same(u, d)) fail();
    return d;
  }

  const guardarRutaSegura = onCall(async (request) => {
    const u = await getCaller(request); const data = request.data || {};
    if (!admin(u, data.id ? "editar" : "crear")) fail();
    const s = scope(u, data); const year = await activeYear(s.institution, s.campus);
    const ref = data.id ? db.doc(`routes/${ident(data.id)}`) : db.collection("routes").doc();
    const ids = [...new Set(data.estudiantes || [])];
    if (!ids.length || ids.length > 200) throw new HttpsError("invalid-argument", "Selecciona entre 1 y 200 estudiantes.");
    ids.forEach(ident);
    const managerId = ident(data.gestionador);
    const value = {...s, academicYearId: year.id, academicYear: year.year,
      nombre: text(data.nombre), direccionInicio: text(data.direccionInicio),
      gestionador: managerId, estudiantes: ids, status: "active"};
    if (data.driverId) value.driverId = ident(data.driverId);
    for (const key of ["fechaInicio", "fechaFin", "horaInicio", "horaFin"]) {
      if (!Number.isFinite(data[key])) throw new HttpsError("invalid-argument", "Configura fechas y horarios.");
      value[key] = Timestamp.fromMillis(data[key]);
    }
    return db.runTransaction(async (tx) => {
      const old = await tx.get(ref);
      if (value.driverId) {
        const driver = (await tx.get(db.doc(`route_drivers/${value.driverId}`))).data();
        if (!driver || !driver.active || driver.institution !== s.institution || driver.campus !== s.campus) fail("Conductor no disponible en esta sede.");
      }
      await checkedYear(tx, value);
      const profiles = await tx.getAll(...[managerId, ...ids].map((id) => db.doc(`users/${id}`)));
      if (profiles.some((p) => !p.exists || p.data().status !== "activo" || p.data().institution !== s.institution || p.data().campus !== s.campus)) fail("Participantes no válidos en esta sede.");
      if (!["Docente", "Administrador", "Auxiliar"].includes(profiles[0].data().role) || profiles.slice(1).some((p) => p.data().role !== "Estudiante")) fail();
      if (old.exists && (!same(u, old.data()) || old.data().academicYearId !== year.id)) fail();
      const running = await tx.get(db.collection("daily_routes").where("idRuta", "==", ref.id).where("estado", "==", "activa"));
      if (!running.empty) throw new HttpsError("failed-precondition", "No se modifica una ruta iniciada.");
      tx.set(ref, {...value, revision: Number(old.data()?.revision || 0) + 1});
      audit(tx, u, {...value, idRuta: ref.id}, old.exists ? "route_updated" : "route_created");
      return {id: ref.id};
    });
  });
  const eliminarRutaSegura = onCall(async (request) => {
    const u = await getCaller(request);
    if (!admin(u, "eliminar")) fail();
    const ref = db.doc(`routes/${ident(request.data?.id)}`);
    return db.runTransaction(async (tx) => {
      const d = (await tx.get(ref)).data(); if (!d || !same(u, d)) fail();
      await checkedYear(tx, d);
      const runs = await tx.get(db.collection("daily_routes").where("idRuta", "==", ref.id).limit(1));
      if (!runs.empty) throw new HttpsError("failed-precondition", "Tiene recorridos e historial. Conserva la ruta; no se puede eliminar.");
      tx.delete(ref); audit(tx, u, {...d, idRuta: ref.id}, "route_deleted");
      return {ok: true};
    });
  });
  const prepararRecorrido = onCall(async (request) => {
    const u = await getCaller(request); const routeId = ident(request.data?.routeId);
    const ref = db.doc(`daily_routes/${routeId}_${day()}`);
    return db.runTransaction(async (tx) => {
      const route = (await tx.get(db.doc(`routes/${routeId}`))).data();
      if (!route || !operator(u, route)) fail();
      await checkedYear(tx, route);
      const existing = await tx.get(ref);
      if (existing.exists) return {id: ref.id};
      const students = await tx.getAll(...route.estudiantes.map((id) => db.doc(`users/${ident(id)}`)));
      const d = {institution: route.institution, campus: route.campus,
        academicYearId: route.academicYearId, academicYear: route.academicYear,
        idRuta: routeId, dailyId: ref.id, nombreRuta: route.nombre,
        gestionador: route.gestionador, gestionadaPorNombre: `${u.firstName || ""} ${u.lastName || ""}`.trim(),
        fecha: Timestamp.now(), estado: "pendiente", revision: 0, mode: "manual",
        horaInicio: null, horaFin: null};
      tx.create(ref, d);
      students.filter((s) => s.exists && s.data().status === "activo" && s.data().institution === d.institution && s.data().campus === d.campus).forEach((s, i) => {
        const address = s.data().routeAddress || "";
        tx.create(ref.collection("students").doc(s.id), {
          institution: d.institution, campus: d.campus, academicYearId: d.academicYearId,
          academicYear: d.academicYear, id: s.id, nombre: `${s.data().firstName || ""} ${s.data().lastName || ""}`.trim(),
          direccion: address, activo: true, recogido: false, anulado: false,
          orden: i, avisosEnviados: 0, avisoEnviado: false, horaRecogida: null,
        });
      });
      audit(tx, u, d, "prepared"); return {id: ref.id};
    });
  });
  const operarRecorrido = onCall(async (request) => {
    const u = await getCaller(request); const data = request.data || {};
    const ref = db.doc(`daily_routes/${ident(data.id)}`);
    const command = ident(data.command); const requestId = ident(data.requestId);
    return db.runTransaction(async (tx) => {
      const d = (await tx.get(ref)).data();
      if (!d || !operator(u, d)) fail();
      await checkedYear(tx, d);
      const operationRef = ref.collection("operations").doc(hash(`${u.uid}:${requestId}`));
      if ((await tx.get(operationRef)).exists) return {ok: true};
      if (d.estado === "finalizada") throw new HttpsError("failed-precondition", "Recorrido finalizado: solo consulta.");
      const snapshot = await tx.get(ref.collection("students"));
      const students = snapshot.docs.map((s) => ({...s.data(), id: s.id}));
      const target = students.find((s) => s.id === data.studentId);
      const running = d.estado === "activa";
      const updated = {...d, dailyId: ref.id};
      let affected = [];
      if (command === "start") {
        if (running) throw new HttpsError("failed-precondition", "Ya inició.");
        if (!students.some((s) => s.activo) || students.some((s) => s.activo && !s.direccion.trim())) throw new HttpsError("failed-precondition", "Completa direcciones y estudiantes antes de iniciar.");
        tx.update(ref, {estado: "activa", horaInicio: FieldValue.serverTimestamp()});
        affected = students.filter((s) => s.activo).map((s) => s.id);
        event(tx, `${ref.id}:start`, updated, affected, "Ruta iniciada", "El recorrido escolar ha iniciado.");
      } else if (command === "finish") {
        if (!running || students.some((s) => s.activo && !s.recogido && !s.anulado)) throw new HttpsError("failed-precondition", "Revisa los estudiantes pendientes antes de finalizar.");
        tx.update(ref, {estado: "finalizada", horaFin: FieldValue.serverTimestamp(), teacherPosition: FieldValue.delete()});
        tx.delete(ref.collection("live").doc("location"));
        affected = students.filter((s) => s.activo).map((s) => s.id);
        event(tx, `${ref.id}:finish`, updated, affected, "Ruta finalizada", "El recorrido escolar ha finalizado.");
      } else if (command === "position") {
        if (!running || !Number.isFinite(data.latitude) || Math.abs(data.latitude) > 90 || !Number.isFinite(data.longitude) || Math.abs(data.longitude) > 180) fail();
        const {GeoPoint} = require("firebase-admin/firestore");
        tx.set(ref.collection("live").doc("location"), {institution: d.institution, campus: d.campus,
          academicYearId: d.academicYearId, academicYear: d.academicYear,
          teacherPosition: new GeoPoint(data.latitude, data.longitude), lastUpdate: FieldValue.serverTimestamp()});
        openWindows(tx, ref, d, students);
      } else if (command === "announcement") {
        if (!running) fail();
        const body = text(data.reason, 500);
        affected = students.filter((s) => s.activo).map((s) => s.id);
        event(tx, `${ref.id}:announcement:${requestId}`, updated, affected, "Novedad del recorrido", body);
      } else if (command === "address" || command === "active") {
        if (running || !target) throw new HttpsError("failed-precondition", "Las paradas están bloqueadas después de iniciar.");
        const changes = command === "address" ? {direccion: text(data.address, 500)} : {activo: data.active === true};
        tx.update(ref.collection("students").doc(target.id), changes); affected = [target.id];
      } else if (command === "manual" || command === "automatic") {
        if (command === "automatic" && process.env.MAPS_ROUTING_ENABLED !== "true") throw new HttpsError("failed-precondition", "Google Maps automático está pendiente de habilitación. Usa modo manual.");
        tx.update(ref, {mode: command});
      } else if (["pickup", "absent", "arrival", "eta"].includes(command)) {
        if (!running || !target || !target.activo) fail();
        const group = students.filter((s) => s.activo && s.direccion.trim().toLocaleLowerCase() === target.direccion.trim().toLocaleLowerCase());
        if (command === "pickup" || command === "absent") {
          if (target.recogido || target.anulado) throw new HttpsError("failed-precondition", "La asistencia ya fue registrada.");
          const changes = command === "pickup" ? {recogido: true, mapEnabled: false, horaRecogida: FieldValue.serverTimestamp()} : {anulado: true, mapEnabled: false, observacion: text(data.reason, 500)};
          tx.update(ref.collection("students").doc(target.id), changes);
          Object.assign(target, changes); affected = [target.id];
          // Una notificacion agrupada al cerrar la parada, no una por hermano.
          if (group.every((s) => s.id === target.id || s.recogido || s.anulado)) {
            event(tx, `${ref.id}:stop:${hash(target.direccion.trim().toLocaleLowerCase())}`, updated,
                group.map((s) => s.id), "Recogida actualizada", "Se registró el resultado de la recogida en tu parada. Consulta el detalle de tus hijos en Rutas.");
          }
        } else {
          affected = group.filter((s) => !s.recogido && !s.anulado).map((s) => s.id);
          if (!affected.length) throw new HttpsError("failed-precondition", "Parada completada.");
          let body = "El transporte está esperando en tu parada.";
          if (command === "eta") {
            if (!Number.isInteger(data.minutes) || data.minutes < 1 || data.minutes > 240) throw new HttpsError("invalid-argument", "Minutos entre 1 y 240.");
            body = `Tiempo aproximado de llegada: ${data.minutes} minutos.`;
          }
          event(tx, `${ref.id}:${requestId}`, updated, affected, "Aviso de ruta escolar", body);
          const minutes = command === "arrival" ? 0 : data.minutes;
          for (const s of group.filter((s) => affected.includes(s.id))) {
            s.estimatedArrivalAt = Timestamp.fromMillis(Date.now() + minutes * 60000);
            // This explicit notice already alerts the family; avoid a second push.
            const changes = {estimatedArrivalAt: s.estimatedArrivalAt, estimatedMinutes: minutes,
              estimatedAt: FieldValue.serverTimestamp()};
            if (minutes <= 10) changes.mapEnabled = true;
            tx.update(ref.collection("students").doc(s.id), changes);
          }
        }
      } else throw new HttpsError("invalid-argument", "Acción no válida.");
      if (command !== "position") audit(tx, u, updated, command, {studentIds: affected, reason: typeof data.reason === "string" ? data.reason.slice(0, 500) : null});
      tx.create(operationRef, {createdAt: FieldValue.serverTimestamp(), command});
      return {ok: true};
    });
  });
  const consultarMiRecorrido = onCall(async (request) => {
    const u = await getCaller(request); const id = request.data?.studentId || u.uid;
    if (!(u.permissions || []).includes("rutas.ver")) fail();
    if (!["Estudiante", "Familiar"].includes(u.role)) fail();
    const student = await child(u, id);
    const year = await activeYear(student.institution, student.campus);
    const runs = await db.collection("daily_routes").where("institution", "==", student.institution).where("campus", "==", student.campus).where("academicYearId", "==", year.id).get();
    for (const run of runs.docs) {
      if (!run.id.endsWith(`_${day()}`)) continue;
      if ((await run.ref.collection("students").doc(id).get()).exists) return {id: run.id};
    }
    return {id: null};
  });
  const consultarHistorialRuta = onCall(async (request) => {
    const u = await getCaller(request); const s = scope(u, request.data || {});
    if (!u.isSuperadmin && !(u.permissions || []).includes("rutas.ver")) fail();
    const studentId = request.data?.studentId;
    if (["Familiar", "Estudiante"].includes(u.role)) await child(u, studentId || u.uid);
    else if (!admin(u, "ver") && !["Docente", "Auxiliar"].includes(u.role)) fail();
    let query = db.collection("route_history").where("institution", "==", s.institution).where("campus", "==", s.campus);
    if (["Familiar", "Estudiante"].includes(u.role)) query = query.where("studentIds", "array-contains", studentId || u.uid);
    else if (!admin(u, "ver")) query = query.where("performedBy", "==", u.uid);
    // Consulta acotada y orden estable requieren indice compuesto.
    query = query.orderBy("createdAt", "desc").limit(100);
    const rows = await query.get();
    return {items: rows.docs.map((r) => {
      const d = r.data(); return {id: r.id, action: d.action, date: d.createdAt?.toMillis() || null,
        dailyRouteId: d.dailyRouteId, reason: d.reason || null};
    })};
  });
  const gestionarConductores = onCall(async (request) => {
    const u = await getCaller(request); const data = request.data || {}; const s = scope(u, data);
    if (!admin(u, data.action === "save" ? "editar" : "ver")) fail();
    if (data.action === "save") {
      const ref = data.id ? db.doc(`route_drivers/${ident(data.id)}`) : db.collection("route_drivers").doc();
      const value = {...s, name: text(data.name, 150), document: text(data.document, 40),
        phone: text(data.phone, 40), license: text(data.license, 100),
        notes: typeof data.notes === "string" ? data.notes.slice(0, 2000) : "",
        active: data.active !== false};
      await db.runTransaction(async (tx) => {
        const old = await tx.get(ref); if (old.exists && !same(u, old.data())) fail();
        tx.set(ref, {...value, updatedAt: FieldValue.serverTimestamp()});
        tx.create(db.collection("staff_audit").doc(), {...s, driverId: ref.id,
          performedBy: u.uid, action: "driver_saved", createdAt: FieldValue.serverTimestamp()});
      });
    }
    const rows = await db.collection("route_drivers").where("institution", "==", s.institution).where("campus", "==", s.campus).limit(300).get();
    return {items: rows.docs.map((d) => ({id: d.id, ...d.data(), updatedAt: null}))};
  });
  const calcularTiemposRuta = onCall(async (request) => {
    const u = await getCaller(request); const ref = db.doc(`daily_routes/${ident(request.data?.id)}`);
    const d = (await ref.get()).data();
    if (!d || !operator(u, d)) fail();
    if (d.estado !== "activa") throw new HttpsError("failed-precondition", "Inicia el recorrido antes de calcular tiempos desde la posición actual.");
    if (process.env.MAPS_ROUTING_ENABLED !== "true") throw new HttpsError("failed-precondition", "Cálculo automático pendiente de habilitación y presupuesto de Google Maps. El modo manual está disponible.");
    const students = (await ref.collection("students").orderBy("orden").get()).docs
        .map((s) => ({id: s.id, ...s.data()})).filter((s) => s.activo && !s.recogido && !s.anulado);
    const stops = [...new Set(students.map((s) => s.direccion.trim()))];
    if (!stops.length) return {items: []};
    if (stops.length > 26) throw new HttpsError("failed-precondition", "Este recorrido requiere cálculo por segmentos. Usa modo manual.");
    const location = (await ref.collection("live").doc("location").get()).data();
    if (!location?.teacherPosition || !location.lastUpdate || Date.now() - location.lastUpdate.toMillis() > 120000) throw new HttpsError("failed-precondition", "Se necesita una posición reciente del responsable.");
    const quotaRef = db.collection("maps_route_quotas").doc(day());
    await db.runTransaction(async (tx) => {
      const count = Number((await tx.get(quotaRef)).data()?.count || 0);
      if (count >= 100) throw new HttpsError("resource-exhausted", "Se alcanzó el límite diario de cálculos. Usa modo manual.");
      tx.set(quotaRef, {count: count + 1});
    });
    const {applicationDefault} = require("firebase-admin/app");
    const access = await applicationDefault().getAccessToken();
    const response = await fetch("https://routes.googleapis.com/directions/v2:computeRoutes", {
      method: "POST", headers: {"Authorization": `Bearer ${access.access_token}`,
        "X-Goog-User-Project": process.env.GCLOUD_PROJECT,
        "X-Goog-FieldMask": "routes.legs.duration,routes.legs.distanceMeters", "Content-Type": "application/json"},
      body: JSON.stringify({origin: {location: {latLng: {latitude: location.teacherPosition.latitude, longitude: location.teacherPosition.longitude}}},
        destination: {address: stops.at(-1)}, intermediates: stops.slice(0, -1).map((address) => ({address})),
        travelMode: "DRIVE", routingPreference: "TRAFFIC_AWARE", languageCode: "es"}),
      signal: AbortSignal.timeout(15000),
    });
    if (!response.ok) throw new HttpsError("unavailable", "Google Maps no pudo calcular. Conserva el modo manual e intenta más tarde.");
    const legs = (await response.json()).routes?.[0]?.legs;
    if (!legs || legs.length !== stops.length) throw new HttpsError("unavailable", "No se encontró un recorrido completo.");
    let seconds = 0; const items = stops.map((address, i) => {
      seconds += Number.parseFloat(legs[i].duration);
      const result = {address, minutes: Math.max(1, Math.ceil(seconds / 60)), distanceMeters: legs[i].distanceMeters,
        studentIds: students.filter((s) => s.direccion.trim() === address).map((s) => s.id)};
      seconds += 60; return result; // Un minuto operativo por parada: estimación, no hora garantizada.
    });
    await db.runTransaction(async (tx) => {
      const current = (await tx.get(ref)).data(); await checkedYear(tx, current);
      const currentStudents = await tx.get(ref.collection("students"));
      const pendingIds = currentStudents.docs.filter((s) => s.data().activo && !s.data().recogido && !s.data().anulado).map((s) => s.id).sort();
      if (current.estado !== "activa" || !operator(u, current) || JSON.stringify(pendingIds) !== JSON.stringify(students.map((s) => s.id).sort())) throw new HttpsError("aborted", "El recorrido cambió durante el cálculo. Reintenta.");
      tx.update(ref, {mode: "automatic", estimateUpdatedAt: FieldValue.serverTimestamp()});
      for (const item of items) {
        for (const id of item.studentIds) {
          const arrival = Timestamp.fromMillis(Date.now() + item.minutes * 60000);
          tx.update(ref.collection("students").doc(id), {
            estimatedMinutes: item.minutes, distanceMeters: item.distanceMeters, estimatedAt: FieldValue.serverTimestamp(),
            estimatedArrivalAt: arrival,
          });
          Object.assign(students.find((s) => s.id === id), {estimatedArrivalAt: arrival,
            mapEnabled: currentStudents.docs.find((s) => s.id === id).data().mapEnabled === true});
        }
      }
      audit(tx, u, {...current, dailyId: ref.id}, "eta_calculated");
      openWindows(tx, ref, current, students);
    });
    return {items};
  });
  const solicitarCambioParada = onCall(async (request) => {
    const u = await getCaller(request); const data = request.data || {};
    if (u.role !== "Familiar" || !(u.permissions || []).includes("rutas.ver")) fail();
    await child(u, data.studentId);
    const ref = db.doc(`daily_routes/${ident(data.dailyRouteId)}`);
    return db.runTransaction(async (tx) => {
      const d = (await tx.get(ref)).data(); const student = await tx.get(ref.collection("students").doc(ident(data.studentId)));
      if (!d || !same(u, d) || !student.exists) fail();
      await checkedYear(tx, d);
      if (d.estado !== "pendiente") throw new HttpsError("failed-precondition", "La ruta ya inició: no se cambian paradas.");
      const change = ref.collection("change_requests").doc(data.studentId);
      const old = await tx.get(change);
      if (old.data()?.status === "pending") throw new HttpsError("already-exists", "Ya existe una solicitud pendiente para este hijo.");
      tx.set(change, {studentId: data.studentId, requestedBy: u.uid, status: "pending",
        address: text(data.address, 500), reason: text(data.reason, 500), createdAt: FieldValue.serverTimestamp()});
      audit(tx, u, {...d, dailyId: ref.id}, "address_requested", {studentIds: [data.studentId]});
      return {ok: true};
    });
  });
  const gestionarCambiosParada = onCall(async (request) => {
    const u = await getCaller(request); const data = request.data || {};
    if (!admin(u, "editar")) fail();
    if (data.action === "decide") {
      const ref = db.doc(`daily_routes/${ident(data.dailyRouteId)}`);
      await db.runTransaction(async (tx) => {
        const d = (await tx.get(ref)).data(); if (!d || !same(u, d)) fail();
        await checkedYear(tx, d);
        const change = ref.collection("change_requests").doc(ident(data.studentId));
        const value = (await tx.get(change)).data();
        const student = await tx.get(ref.collection("students").doc(data.studentId));
        if (!student.exists || !value || value.status !== "pending") throw new HttpsError("failed-precondition", "Solicitud ya resuelta o estudiante no disponible.");
        if (d.estado !== "pendiente") throw new HttpsError("failed-precondition", "No se modifican paradas después del inicio.");
        tx.update(change, {status: data.approved === true ? "approved" : "rejected", decidedBy: u.uid,
          decisionReason: text(data.reason, 500), decidedAt: FieldValue.serverTimestamp()});
        if (data.approved === true) tx.update(student.ref, {direccion: value.address});
        audit(tx, u, {...d, dailyId: ref.id}, data.approved === true ? "address_approved" : "address_rejected", {studentIds: [data.studentId], reason: data.reason});
        event(tx, `${ref.id}:change:${value.createdAt.toMillis()}`, {...d, dailyId: ref.id}, [data.studentId], "Solicitud de parada resuelta", "Consulta la decisión del colegio en el historial de Rutas.");
      });
    }
    const s = scope(u, data); const year = await activeYear(s.institution, s.campus);
    const rows = await db.collection("daily_routes").where("institution", "==", s.institution).where("campus", "==", s.campus).where("academicYearId", "==", year.id).where("estado", "==", "pendiente").get();
    const items = [];
    for (const row of rows.docs) {
      const changes = await row.ref.collection("change_requests").where("status", "==", "pending").get();
      changes.docs.forEach((c) => items.push({dailyRouteId: row.id, routeName: row.data().nombreRuta,
        studentId: c.id, address: c.data().address, reason: c.data().reason}));
    }
    return {items};
  });
  return {guardarRutaSegura, eliminarRutaSegura, prepararRecorrido, operarRecorrido, consultarMiRecorrido, consultarHistorialRuta,
    gestionarConductores, solicitarCambioParada, gestionarCambiosParada, calcularTiemposRuta};
}
module.exports = {routeFunctions};
