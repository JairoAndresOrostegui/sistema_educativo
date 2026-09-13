"use strict";
/* eslint-disable max-len */
const crypto = require("crypto");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {FieldValue} = require("firebase-admin/firestore");
const {readQrCredential, recordQrResolution} = require("./qr_identity");

const hash = (value) => crypto.createHash("sha256").update(value).digest("hex");
const fail = (message = "No tienes acceso a esta operación del evento.") => {
  throw new HttpsError("permission-denied", message);
};
const invalid = (message) => {
  throw new HttpsError("invalid-argument", message);
};
const identifier = (value, label = "identificador") => {
  if (typeof value !== "string" || !value.trim() || value.length > 160 || value.includes("/")) invalid(`${label} no es válido.`);
  return value.trim();
};
const string = (value, label, max, required = false) => {
  if (value != null && typeof value !== "string") invalid(`${label} no es válido.`);
  const result = value?.trim() || "";
  if (result.length > max || required && !result) invalid(`${label} no es válido.`);
  return result;
};
const money = (value, required = false) => {
  if (value == null && !required) return null;
  if (!Number.isSafeInteger(value) || value < 0 || value > 1000000000) invalid("Indica un importe entero entre 0 y 1.000.000.000 COP.");
  return value;
};
const boolean = (value, label) => {
  if (typeof value !== "boolean") invalid(`${label} no es válido.`);
  return value;
};
const secureUrl = (value) => {
  const result = string(value, "Enlace", 500);
  if (!result) return "";
  try {
    const url = new URL(result);
    if (url.protocol !== "https:" || !url.hostname || url.username || url.password) invalid("Usa un enlace HTTPS sin credenciales.");
  } catch {
    invalid("Usa un enlace HTTPS válido.");
  }
  return result;
};
const revision = (value) => {
  if (!Number.isSafeInteger(value) || value < 0) invalid("Recarga los datos antes de guardar.");
  return value;
};
const checkRevision = (snapshot, expected) => {
  if ((snapshot.exists ? Number(snapshot.data().revision) : 0) !== expected) {
    throw new HttpsError("aborted", "Otra persona modificó estos datos. Recarga antes de guardar.");
  }
};
const nameOf = (user) => `${user.firstName || ""} ${user.lastName || ""}`.trim();
const now = () => FieldValue.serverTimestamp();
const eventScope = (event) => ({institutionId: event.institutionId, campusId: event.campusId,
  academicYearId: event.academicYearId, academicYear: event.academicYear});
const sameScope = (value, event) => value.institutionId === event.institutionId &&
  value.campusId === event.campusId && value.academicYearId === event.academicYearId;
const serial = (snapshot) => {
  const value = snapshot.data();
  const result = {id: snapshot.id};
  for (const [key, item] of Object.entries(value)) {
    if (item?.toMillis) result[`${key}Millis`] = item.toMillis();
    else result[key] = item;
  }
  return result;
};

function normalizeEventConfiguration(input) {
  if (!["student_presentation", "parent_meeting"].includes(input.eventType)) invalid("Selecciona presentación estudiantil o reunión de padres.");
  const foodEnabled = input.foodEnabled == null ? false : boolean(input.foodEnabled, "Alimentación");
  if (foodEnabled && input.eventType !== "student_presentation") invalid("La alimentación solo está disponible en presentaciones estudiantiles.");
  if (input.requirements != null && !Array.isArray(input.requirements)) invalid("Los requisitos no son válidos.");
  const requirements = input.requirements || [];
  if (requirements.length > 40) invalid("Un evento admite hasta 40 requisitos.");
  const seen = new Set();
  const normalized = requirements.map((item) => {
    const id = identifier(item?.id, "Requisito");
    if (id.length > 80 || seen.has(id)) invalid("Los requisitos necesitan identificadores únicos de hasta 80 caracteres.");
    seen.add(id);
    if (!["student", "family"].includes(item.targetType) ||
        !["manual", "attendance", "payment"].includes(item.completionType)) invalid("El tipo de requisito no es válido.");
    const amountCop = money(item.amountCop);
    if (item.completionType !== "payment" && amountCop != null) invalid("Solo un requisito de pago admite importe.");
    return {id, label: string(item.label, "Nombre del requisito", 120, true),
      instructions: string(item.instructions, "Instrucciones", 2000),
      targetType: item.targetType, completionType: item.completionType,
      required: boolean(item.required, "Obligatorio"), amountCop};
  });
  if (input.publicity != null && (typeof input.publicity !== "object" || Array.isArray(input.publicity))) invalid("La publicidad no es válida.");
  return {schemaVersion: 2, eventType: input.eventType,
    subtitle: string(input.subtitle, "Subtítulo", 200), foodEnabled,
    publicity: {text: string(input.publicity?.text, "Publicidad", 2000),
      url: secureUrl(input.publicity?.url)}, requirements: normalized};
}

function eventOperations(db, getCaller, helpers) {
  const {permission, admin, sameTenant, mutationActor, checkedStudent,
    checkedManageEvent, eventResponse, teacherGroupIds, recipientUsers} = helpers;
  const activeUser = (value, event, role) => value.status === "activo" &&
    value.institution === event.institutionId && value.campus === event.campusId &&
    (!role || value.role === role);
  const operator = (user, event, action = "editar") => sameTenant(user, event) &&
    permission(user, action) && (admin(user, action) || user.role === "Docente" &&
      event.responsibleUserIds?.includes(user.uid));
  const published = (event) => ["published", "closed"].includes(event.status) ||
    event.status === "cancelled" && !!event.publishedAt;
  const stateAllowed = (event, states, beforeStart = false) => {
    if (!states.includes(event.status) || beforeStart && event.startAt?.toMillis?.() <= Date.now()) {
      throw new HttpsError("failed-precondition", "El estado o la fecha del evento ya no permite esta operación.");
    }
  };
  const checkedEvent = async (tx, user, eventId, states, beforeStart = false) => {
    const ref = db.collection("school_events").doc(eventId);
    const snapshot = await tx.get(ref);
    if (!snapshot.exists) fail();
    const event = snapshot.data();
    const actor = await mutationActor(tx, user, event);
    if (!sameTenant(actor, event) || !permission(actor, "ver")) fail();
    stateAllowed(event, states, beforeStart);
    return {ref, snapshot, event, actor};
  };
  const checkedTargetStudent = async (tx, event, studentId) => {
    if (!event.targetStudentIds?.includes(studentId)) fail("El estudiante no pertenece al evento.");
    const snapshot = await tx.get(db.collection("users").doc(studentId));
    const value = snapshot.data() || {};
    if (!snapshot.exists || !activeUser(value, event, "Estudiante")) fail("El estudiante ya no está activo en esta sede.");
    return {...value, uid: snapshot.id};
  };
  const checkedFamily = (actor, studentId) => {
    if (actor.role !== "Familiar" || actor.activeStudentId !== studentId || !actor.studentIds?.includes(studentId)) fail("Selecciona un hijo activo vinculado.");
  };
  const history = (tx, eventId, event, actor, action, detail = {}) => tx.create(db.collection("event_history").doc(), {
    ...eventScope(event), eventId, action, ...detail, performedBy: actor.uid,
    performedByName: nameOf(actor), createdAt: now(),
  });
  const beginRequest = async (tx, actor, eventId, action, input, data) => {
    const requestId = identifier(input.requestId, "Identificador de operación");
    const ref = db.collection("event_operation_requests").doc(hash(JSON.stringify([eventId, actor.uid, action, requestId])));
    const fingerprint = hash(JSON.stringify(data));
    const snapshot = await tx.get(ref);
    if (snapshot.exists && snapshot.data().fingerprint !== fingerprint) {
      throw new HttpsError("already-exists", "Ese identificador ya corresponde a otra operación. Recarga antes de continuar.");
    }
    return {ref, fingerprint, result: snapshot.exists ? snapshot.data().result : null};
  };
  const finishRequest = (tx, request, eventId, event, actor, result) => tx.create(request.ref, {
    ...eventScope(event), eventId, actorId: actor.uid, fingerprint: request.fingerprint, result, createdAt: now(),
  });
  const completeQuery = async (query, limit = 2000) => {
    const snapshot = await query.limit(limit + 1).get();
    if (snapshot.size > limit) throw new HttpsError("resource-exhausted", "El evento supera el límite de consulta. Contacta a administración.");
    return snapshot.docs;
  };
  const notificationRecipients = async (tx, event, studentIds, familyIds = null, includeStudents = true) => {
    const recipients = new Set(await recipientUsers(studentIds, event.responsibleUserIds || [], event, tx));
    const administrators = await tx.get(db.collection("users")
        .where("institution", "==", event.institutionId).where("campus", "==", event.campusId)
        .where("role", "==", "Administrador").where("status", "==", "activo"));
    administrators.docs.filter((item) => permission(item.data(), "editar") && permission(item.data(), "ver"))
        .forEach((item) => recipients.add(item.id));
    if (familyIds != null || !includeStudents) {
      const refs = [...recipients].map((uid) => db.collection("users").doc(uid));
      const users = refs.length ? await tx.getAll(...refs) : [];
      for (const snapshot of users) {
        const user = snapshot.data();
        if (user.role === "Familiar" && familyIds != null && !familyIds.includes(snapshot.id) ||
            user.role === "Estudiante" && !includeStudents) recipients.delete(snapshot.id);
      }
    }
    return [...recipients];
  };
  const notify = (tx, eventId, event, recipients, kind, title, detail = {}) => {
    if (!recipients.length || !["published", "closed"].includes(event.status)) return;
    tx.create(db.collection("event_notification_events").doc(), {
      ...eventScope(event), eventId, recipientUserIds: recipients, kind, title,
      body: `Hay una novedad en ${event.title}. Consulta el evento.`, ...detail, createdAt: now(),
    });
  };

  // Every returned collection is filtered before serialization, not by the UI.
  const obtenerDetalleEvento = onCall(async (request) => {
    const user = await getCaller(request);
    const eventId = identifier(request.data?.eventId, "Evento");
    const snapshot = await db.collection("school_events").doc(eventId).get();
    const event = snapshot.data() || {};
    if (!snapshot.exists || !sameTenant(user, event) || !permission(user, "ver")) fail();
    let student = null;
    const isStaff = ["Administrador", "Docente"].includes(user.role);
    const canOperate = operator(user, event, "ver");
    if (!isStaff) {
      student = await checkedStudent(user, request.data?.studentId);
      if (!published(event) || !event.targetStudentIds?.includes(student.id)) fail();
    } else if (!canOperate) {
      const groups = await teacherGroupIds(user, {id: event.academicYearId});
      if (user.role !== "Docente" || !event.targetGroupIds?.some((groupId) => groups.has(groupId))) fail();
    }
    const yearSnapshot = await db.collection("academic_years").doc(event.academicYearId).get();
    const year = yearSnapshot.data() || {};
    const active = yearSnapshot.exists && year.status === "active" &&
      year.institutionId === event.institutionId && year.campusId === event.campusId;
    if (!isStaff && !active) fail("Este evento pertenece a un año cerrado.");
    const query = (collection) => db.collection(collection).where("eventId", "==", eventId);
    const [foods, orders, materials, completions] = await Promise.all([
      completeQuery(query("event_food_items"), 200),
      student ? user.role === "Familiar" ? completeQuery(query("event_food_orders")
          .where("familyId", "==", user.uid).where("studentId", "==", student.id)) : [] :
        canOperate ? completeQuery(query("event_food_orders")) : [],
      completeQuery(query("event_materials"), 200),
      student ? completeQuery(query("event_requirement_completions")
          .where("studentContextIds", "array-contains", student.id)) :
        canOperate ? completeQuery(query("event_requirement_completions")) : [],
    ]);
    const participants = [];
    if (canOperate) {
      const studentRefs = (event.targetStudentIds || []).map((uid) => db.collection("users").doc(uid));
      const students = studentRefs.length ? await db.getAll(...studentRefs) : [];
      const families = await completeQuery(db.collection("users")
          .where("institution", "==", event.institutionId).where("campus", "==", event.campusId)
          .where("role", "==", "Familiar").where("status", "==", "activo"), 8000);
      for (const item of students) {
        const value = item.data() || {};
        if (!item.exists || !activeUser(value, event, "Estudiante")) continue;
        participants.push({studentId: item.id, studentName: nameOf(value), groupId: value.groupId || "",
          families: families.filter((family) => family.data().studentIds?.includes(item.id))
              .map((family) => ({id: family.id, name: nameOf(family.data())}))});
      }
    }
    const within = (item) => sameScope(item.data(), event);
    const canEdit = active && operator(user, event);
    return {event: eventResponse(snapshot, {}, canOperate),
      foodItems: event.foodEnabled ? foods.filter((item) => within(item) && (canOperate || item.data().active === true)).map(serial) : [],
      orders: orders.filter(within).map(serial),
      materials: materials.filter((item) => within(item) && (canOperate || item.data().active === true &&
        (!student || item.data().groupIds?.includes(student.groupId)))).map(serial),
      completions: completions.filter((item) => within(item) && (!student ||
        item.data().targetType === "student" && item.data().targetId === student.id ||
        item.data().targetType === "family" && user.role === "Familiar" && item.data().targetId === user.uid)).map(serial),
      participants,
      capabilities: {
        canConfigure: canEdit && admin(user, "editar") && ["draft", "published"].includes(event.status) && event.startAt.toMillis() > Date.now(),
        canManageMaterials: canEdit && ["draft", "published"].includes(event.status),
        canManageFulfillment: canEdit && ["published", "closed"].includes(event.status),
        canOrder: active && user.role === "Familiar" && event.status === "published" && event.foodEnabled === true && event.startAt.toMillis() > Date.now(),
      }};
  });

  const guardarAlimentoEvento = onCall(async (request) => {
    const user = await getCaller(request);
    const input = request.data || {};
    const eventId = identifier(input.eventId, "Evento");
    const itemId = input.itemId == null ? null : identifier(input.itemId, "Alimento");
    const expected = revision(input.expectedRevision ?? 0);
    const value = {name: string(input.name, "Nombre", 120, true), description: string(input.description, "Descripción", 2000),
      priceCop: money(input.priceCop, true), active: boolean(input.active, "Activo")};
    const ref = itemId ? db.collection("event_food_items").doc(itemId) : db.collection("event_food_items").doc();
    return db.runTransaction(async (tx) => {
      const {event, actor} = await checkedEvent(tx, user, eventId, ["draft", "published"], true);
      if (!admin(actor, "editar") || !event.foodEnabled || event.eventType !== "student_presentation") fail();
      const previous = await tx.get(ref);
      if (itemId && !previous.exists || previous.exists && (previous.data().eventId !== eventId || !sameScope(previous.data(), event))) fail();
      checkRevision(previous, expected);
      const recipients = event.status === "published" ? await notificationRecipients(tx, event, event.targetStudentIds || []) : [];
      const next = expected + 1;
      tx.set(ref, {...eventScope(event), eventId, ...value, revision: next,
        createdBy: previous.data()?.createdBy || actor.uid, createdAt: previous.data()?.createdAt || now(), updatedAt: now()});
      history(tx, eventId, event, actor, "food_saved", {itemId: ref.id, revision: next, before: previous.data() || null, after: value});
      notify(tx, eventId, event, recipients, "food_changed", "Alimentación del evento actualizada");
      return {itemId: ref.id, revision: next};
    });
  });

  const guardarMaterialEvento = onCall(async (request) => {
    const user = await getCaller(request);
    const input = request.data || {};
    const eventId = identifier(input.eventId, "Evento");
    const materialId = input.materialId == null ? null : identifier(input.materialId, "Material");
    const expected = revision(input.expectedRevision ?? 0);
    if (!["material", "costume"].includes(input.kind)) invalid("Selecciona material o traje.");
    if (!Array.isArray(input.groupIds) || !input.groupIds.length || input.groupIds.length > 200) invalid("Selecciona los grupos del material.");
    const groupIds = input.groupIds.map((value) => identifier(value, "Grupo"));
    if (new Set(groupIds).size !== groupIds.length) invalid("No repitas grupos.");
    const value = {kind: input.kind, name: string(input.name, "Nombre", 120, true),
      instructions: string(input.instructions, "Instrucciones", 2000), amountCop: money(input.amountCop),
      address: string(input.address, "Dirección", 250), url: secureUrl(input.url), groupIds,
      active: boolean(input.active, "Activo")};
    const ref = materialId ? db.collection("event_materials").doc(materialId) : db.collection("event_materials").doc();
    return db.runTransaction(async (tx) => {
      const {event, actor} = await checkedEvent(tx, user, eventId, ["draft", "published"]);
      if (!operator(actor, event)) fail();
      // Explicit event responsibility is delegated by administration and follows
      // teacher transfer. Creating an event remains limited to teaching groups.
      if (groupIds.some((groupId) => !event.targetGroupIds?.includes(groupId))) fail("Los grupos superan la audiencia del evento.");
      const previous = await tx.get(ref);
      if (materialId && !previous.exists || previous.exists && (previous.data().eventId !== eventId || !sameScope(previous.data(), event))) fail();
      checkRevision(previous, expected);
      const recipients = event.status === "published" ? await notificationRecipients(tx, event, event.targetStudentIds || []) : [];
      const next = expected + 1;
      tx.set(ref, {...eventScope(event), eventId, ...value, revision: next,
        createdBy: previous.data()?.createdBy || actor.uid, createdAt: previous.data()?.createdAt || now(), updatedAt: now()});
      history(tx, eventId, event, actor, "material_saved", {materialId: ref.id, revision: next, before: previous.data() || null, after: value});
      notify(tx, eventId, event, recipients, "materials_changed", "Preparación del evento actualizada");
      return {materialId: ref.id, revision: next};
    });
  });

  const reservarAlimentosEvento = onCall(async (request) => {
    const user = await getCaller(request);
    const input = request.data || {};
    const eventId = identifier(input.eventId, "Evento");
    const studentId = identifier(input.studentId, "Estudiante");
    const expected = revision(input.expectedRevision);
    const cancel = input.cancel == null ? false : boolean(input.cancel, "Cancelar");
    const expectedTotalCop = money(input.expectedTotalCop);
    if (!Array.isArray(input.lines) || input.lines.length > 40 || !cancel && !input.lines.length) invalid("Selecciona entre 1 y 40 alimentos.");
    if (input.totalCop != null || input.priceCop != null || input.paymentState != null || input.deliveryState != null) invalid("Los precios y estados de pago se administran en el colegio.");
    const seen = new Set();
    const lines = input.lines.map((line) => {
      const itemId = identifier(line?.itemId, "Alimento");
      if (seen.has(itemId) || !Number.isInteger(line.quantity) || line.quantity < 1 || line.quantity > 100 ||
          Object.keys(line).some((key) => !["itemId", "quantity"].includes(key))) invalid("Hay alimentos repetidos o cantidades no válidas (1 a 100).");
      seen.add(itemId);
      return {itemId, quantity: line.quantity};
    }).sort((a, b) => a.itemId.localeCompare(b.itemId));
    if (cancel && lines.length) invalid("Una cancelación no admite líneas nuevas.");
    const ref = db.collection("event_food_orders").doc(hash(JSON.stringify([eventId, studentId, user.uid])));
    return db.runTransaction(async (tx) => {
      const {event, actor} = await checkedEvent(tx, user, eventId, ["published"], true);
      checkedFamily(actor, studentId);
      if (!event.foodEnabled || event.eventType !== "student_presentation") fail();
      const student = await checkedTargetStudent(tx, event, studentId);
      const operation = await beginRequest(tx, actor, eventId, "food_order", input,
          {studentId, expected, cancel, lines, expectedTotalCop});
      if (operation.result) return operation.result;
      const previous = await tx.get(ref);
      checkRevision(previous, expected);
      const before = previous.data() || {};
      if (previous.exists && (!sameScope(before, event) || before.eventId !== eventId || before.familyId !== actor.uid || before.studentId !== studentId)) fail();
      if (cancel && !previous.exists) throw new HttpsError("failed-precondition", "No existe un pedido para cancelar.");
      if (before.paymentState === "paid" || before.deliveryState === "delivered") {
        throw new HttpsError("failed-precondition", "El colegio ya registró pago o entrega. Solicita la corrección a administración.");
      }
      const items = lines.length ? await tx.getAll(...lines.map((line) => db.collection("event_food_items").doc(line.itemId))) : [];
      const storedLines = items.map((item, index) => {
        const value = item.data() || {};
        if (!item.exists || value.eventId !== eventId || !sameScope(value, event) || value.active !== true) {
          throw new HttpsError("failed-precondition", "Un alimento ya no está disponible. Recarga el catálogo.");
        }
        return {itemId: item.id, name: value.name, priceCop: money(value.priceCop, true), quantity: lines[index].quantity};
      });
      const totalCop = cancel ? Number(before.totalCop || 0) : storedLines.reduce((sum, line) => sum + line.priceCop * line.quantity, 0);
      money(totalCop, true);
      if (!cancel && expectedTotalCop != null && expectedTotalCop !== totalCop) {
        throw new HttpsError("aborted", "El precio cambió. Recarga el catálogo y confirma el nuevo total.");
      }
      const recipients = await notificationRecipients(tx, event, [studentId], [actor.uid], false);
      const next = expected + 1;
      const result = {orderId: ref.id, revision: next, totalCop};
      tx.set(ref, {...eventScope(event), eventId, familyId: actor.uid, familyName: nameOf(actor),
        studentId, studentName: nameOf(student), lines: cancel ? before.lines : storedLines, totalCop,
        state: cancel ? "cancelled" : "reserved", paymentState: "pending", deliveryState: "pending", revision: next,
        createdAt: before.createdAt || now(), updatedAt: now()});
      history(tx, eventId, event, actor, cancel ? "food_order_cancelled" : "food_order_saved", {
        orderId: ref.id, studentId, familyId: actor.uid, revision: next, totalCop,
        before: previous.exists ? before : null,
      });
      notify(tx, eventId, event, recipients, "order_changed", "Reserva de alimentos actualizada", {
        studentIds: [studentId], familyIds: [actor.uid], includeStudents: false,
      });
      finishRequest(tx, operation, eventId, event, actor, result);
      return result;
    });
  });

  const gestionarPedidoEvento = onCall(async (request) => {
    const user = await getCaller(request);
    const input = request.data || {};
    const eventId = identifier(input.eventId, "Evento");
    const orderId = identifier(input.orderId, "Pedido");
    const expected = revision(input.expectedRevision);
    const paymentState = input.paymentState ?? null;
    const deliveryState = input.deliveryState ?? null;
    if (paymentState == null && deliveryState == null || paymentState != null && !["pending", "paid"].includes(paymentState) ||
        deliveryState != null && !["pending", "delivered"].includes(deliveryState)) invalid("Selecciona un estado de pago o entrega válido.");
    const reason = string(input.reason, "Motivo", 1000);
    const ref = db.collection("event_food_orders").doc(orderId);
    return db.runTransaction(async (tx) => {
      const {event, actor} = await checkedEvent(tx, user, eventId, ["published", "closed"]);
      if (!operator(actor, event)) fail();
      const previous = await tx.get(ref);
      const before = previous.data() || {};
      if (!previous.exists || before.eventId !== eventId || !sameScope(before, event)) fail();
      await checkedTargetStudent(tx, event, before.studentId);
      const family = await tx.get(db.collection("users").doc(before.familyId));
      if (!family.exists || !activeUser(family.data(), event, "Familiar") || !family.data().studentIds?.includes(before.studentId)) fail("El familiar ya no está vinculado al estudiante.");
      const operation = await beginRequest(tx, actor, eventId, "manage_order", input,
          {orderId, expected, paymentState, deliveryState, reason});
      if (operation.result) return operation.result;
      checkRevision(previous, expected);
      if (before.state !== "reserved") throw new HttpsError("failed-precondition", "El pedido está cancelado.");
      const afterPayment = paymentState ?? before.paymentState;
      const afterDelivery = deliveryState ?? before.deliveryState;
      if (afterDelivery === "delivered" && before.deliveryState !== "delivered" && event.startAt.toMillis() > Date.now()) {
        throw new HttpsError("failed-precondition", "La entrega de alimentos se confirma cuando inicia el evento.");
      }
      if (afterDelivery === "delivered" && afterPayment !== "paid" && before.totalCop > 0) {
        throw new HttpsError("failed-precondition", "Registra el pago antes de confirmar la entrega.");
      }
      const correction = before.paymentState === "paid" && afterPayment !== "paid" ||
        before.deliveryState === "delivered" && afterDelivery !== "delivered";
      if (correction && !reason) invalid("Indica el motivo de la corrección.");
      const changed = afterPayment !== before.paymentState || afterDelivery !== before.deliveryState;
      const recipients = changed ? await notificationRecipients(tx, event, [before.studentId], [before.familyId], false) : [];
      const next = changed ? expected + 1 : expected;
      const result = {revision: next};
      if (changed) {
        tx.update(ref, {paymentState: afterPayment, deliveryState: afterDelivery, revision: next,
          performedBy: actor.uid, performedByName: nameOf(actor), updatedAt: now(),
          ...(afterPayment !== before.paymentState ? {paymentUpdatedAt: now()} : {}),
          ...(afterDelivery !== before.deliveryState ? {deliveryUpdatedAt: now()} : {})});
        history(tx, eventId, event, actor, "food_order_fulfilled", {orderId, studentId: before.studentId,
          familyId: before.familyId, reason, before: {paymentState: before.paymentState, deliveryState: before.deliveryState},
          after: {paymentState: afterPayment, deliveryState: afterDelivery}, revision: next});
        notify(tx, eventId, event, recipients, "order_changed", "Pago o entrega de alimentos registrado", {
          studentIds: [before.studentId], familyIds: [before.familyId], includeStudents: false,
        });
      }
      finishRequest(tx, operation, eventId, event, actor, result);
      return result;
    });
  });

  const guardarCumplimientoEvento = onCall(async (request) => {
    const user = await getCaller(request);
    const input = request.data || {};
    const eventId = identifier(input.eventId, "Evento");
    const requirementId = identifier(input.requirementId, "Requisito");
    const targetId = identifier(input.targetId, "Destinatario");
    const studentId = identifier(input.studentId, "Estudiante");
    const targetType = input.targetType;
    if (!["student", "family"].includes(targetType)) invalid("El destinatario no es válido.");
    const completed = boolean(input.completed, "Cumplimiento");
    const expected = revision(input.expectedRevision);
    const reason = string(input.reason, "Motivo", 1000);
    if (input.amountCop != null) invalid("El importe pertenece al requisito configurado por el colegio.");
    const ref = db.collection("event_requirement_completions").doc(hash(JSON.stringify([eventId, requirementId, targetType, targetId])));
    return db.runTransaction(async (tx) => {
      const {event, actor} = await checkedEvent(tx, user, eventId, ["published", "closed"]);
      if (!operator(actor, event)) fail();
      const requirement = event.requirements?.find((item) => item.id === requirementId);
      if (!requirement || requirement.targetType !== targetType) invalid("El requisito no corresponde a ese destinatario.");
      if (requirement.completionType === "attendance" && event.startAt.toMillis() > Date.now()) {
        throw new HttpsError("failed-precondition", "La asistencia se registra cuando inicia el evento.");
      }
      await checkedTargetStudent(tx, event, studentId);
      if (targetType === "student" && targetId !== studentId) fail();
      if (targetType === "family") {
        const target = await tx.get(db.collection("users").doc(targetId));
        if (!target.exists || !activeUser(target.data(), event, "Familiar") || !target.data().studentIds?.includes(studentId)) fail("El familiar no está vinculado al estudiante.");
      }
      let identity = null;
      if (input.qrPayload != null) {
        identity = await readQrCredential(db, input.qrPayload, {tx, expectedType: "user"});
        if (identity.institutionId !== event.institutionId || identity.campusId !== event.campusId) fail();
        const qrUser = identity.raw;
        if (targetType === "family" ? identity.targetId !== targetId || qrUser.role !== "Familiar" :
          !(identity.targetId === studentId && qrUser.role === "Estudiante" ||
            qrUser.role === "Familiar" && qrUser.studentIds?.includes(studentId))) fail("El QR no corresponde al destinatario de este requisito.");
      }
      const operation = await beginRequest(tx, actor, eventId, "requirement", input,
          {requirementId, targetType, targetId, studentId, completed, expected, reason,
            credentialId: identity?.credentialId || null, credentialRevision: identity?.revision || null});
      if (operation.result) return operation.result;
      const previous = await tx.get(ref);
      const before = previous.data() || {};
      if (previous.exists && (before.eventId !== eventId || !sameScope(before, event) || before.targetId !== targetId || before.requirementId !== requirementId)) fail();
      checkRevision(previous, expected);
      if (previous.exists && before.completed !== completed && !reason) invalid("Indica el motivo de la corrección.");
      const studentContextIds = [...new Set([...(before.studentContextIds || []), studentId])];
      const changed = !previous.exists || before.completed !== completed || studentContextIds.length !== before.studentContextIds?.length;
      const recipients = changed ? await notificationRecipients(tx, event, [studentId], targetType === "family" ? [targetId] : null, targetType === "student") : [];
      const next = changed ? expected + 1 : expected;
      const result = {completionId: ref.id, revision: next};
      if (changed) {
        tx.set(ref, {...eventScope(event), eventId, requirementId, targetType, targetId, studentContextIds,
          completed, completionType: requirement.completionType, amountCop: requirement.completionType === "payment" ? requirement.amountCop : null,
          revision: next, performedBy: actor.uid, performedByName: nameOf(actor),
          createdAt: before.createdAt || now(), updatedAt: now(), completedAt: completed ? now() : null,
          ...(identity ? {qrCredentialId: identity.credentialId, qrRevision: identity.revision} : {})});
        history(tx, eventId, event, actor, "requirement_saved", {requirementId, targetType, targetId, studentId,
          before: previous.exists ? before.completed : null, completed, revision: next, reason,
          source: identity ? "qr" : "manual"});
        notify(tx, eventId, event, recipients, "requirement_changed", "Requisito del evento actualizado", {
          studentIds: [studentId], familyIds: targetType === "family" ? [targetId] : null,
          includeStudents: targetType === "student",
        });
        if (identity) recordQrResolution(tx, db, actor, identity, {source: input.source, clientPlatform: input.clientPlatform, context: "eventos"});
      }
      finishRequest(tx, operation, eventId, event, actor, result);
      return result;
    });
  });

  const prepararAccionesEventoQr = onCall(async (request) => {
    const user = await getCaller(request);
    const input = request.data || {};
    return db.runTransaction(async (tx) => {
      const identity = await readQrCredential(db, input.payload, {tx});
      const eventId = identifier(input.eventId || (identity.targetType === "event" ? identity.targetId : null), "Evento");
      const {event, actor} = await checkedEvent(tx, user, eventId, ["published", "closed"]);
      if (identity.institutionId !== event.institutionId || identity.campusId !== event.campusId) fail();
      let targetType; let students;
      if (identity.targetType === "event") {
        if (identity.targetId !== eventId) fail();
        targetType = "event";
        if (["Familiar", "Estudiante"].includes(actor.role)) {
          const studentId = actor.role === "Estudiante" ? actor.uid : identifier(input.studentId || actor.activeStudentId, "Estudiante");
          if (actor.role === "Familiar") checkedFamily(actor, studentId);
          const student = await checkedTargetStudent(tx, event, studentId);
          students = [{id: studentId, name: nameOf(student)}];
        } else {
          await checkedManageEvent(actor, event, "ver");
          students = [];
        }
      } else {
        if (!operator(actor, event)) fail();
        const raw = identity.raw;
        targetType = raw.role === "Estudiante" ? "student" : raw.role === "Familiar" ? "family" : null;
        if (!targetType) fail("Este QR no corresponde a un estudiante o familiar del evento.");
        const ids = targetType === "student" ? [identity.targetId] : raw.studentIds || [];
        students = [];
        for (const studentId of ids) {
          if (!event.targetStudentIds?.includes(studentId)) continue;
          const snapshot = await tx.get(db.collection("users").doc(studentId));
          const value = snapshot.data() || {};
          if (snapshot.exists && activeUser(value, event, "Estudiante")) students.push({id: studentId, name: nameOf(value)});
        }
        if (!students.length) fail("El QR no tiene estudiantes activos dentro del evento.");
      }
      recordQrResolution(tx, db, actor, identity, {source: input.source, clientPlatform: input.clientPlatform, context: "eventos"});
      return {eventId, eventTitle: event.title, targetType, targetId: identity.targetId,
        name: identity.targetType === "event" ? event.title : nameOf(identity.raw), students,
        credentialRevision: identity.revision,
        requirementIds: (event.requirements || []).filter((item) => targetType === "event" ||
          item.targetType === "student" || targetType === "family" && item.targetType === "family").map((item) => item.id)};
    });
  });

  return {obtenerDetalleEvento, guardarAlimentoEvento, guardarMaterialEvento,
    reservarAlimentosEvento, gestionarPedidoEvento, guardarCumplimientoEvento, prepararAccionesEventoQr};
}

module.exports = {eventOperations, normalizeEventConfiguration};
/* eslint-enable max-len */
