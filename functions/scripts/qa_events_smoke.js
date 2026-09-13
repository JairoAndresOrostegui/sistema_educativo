"use strict";
/* eslint-disable max-len */

// Live integration verification, explicitly QA-only. Secrets are obtained from
// the existing private fixture file and never included in reports or errors.
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const assert = require("node:assert/strict");
const {FieldValue} = require("@google-cloud/firestore");
const {PROJECT, FIXTURE, ADMIN, SARA, requireQa, services, checkedContext,
  credentials, session} = require("./qa_events_fixture");

const ROLES = Object.freeze({admin: "Administrador", docente: "Docente",
  familiar1: "Familiar", familiar2: "Familiar"});
const reportDirectory = path.resolve(__dirname, "../../.buildlog");
const SAFE_CODES = new Set(["PERMISSION_DENIED", "INVALID_ARGUMENT", "FAILED_PRECONDITION",
  "UNAUTHENTICATED", "ABORTED", "ALREADY_EXISTS", "NOT_FOUND", "UNAVAILABLE", "INTERNAL",
  "RESOURCE_EXHAUSTED", "DEADLINE_EXCEEDED", "INVALID_ARGUMENTS", "ENOENT", "EACCES",
  "auth/user-not-found", "auth/insufficient-permission"]);
const safeCode = (error) => SAFE_CODES.has(error?.code) ?
  error.code : error?.name === "AssertionError" ? "CHECK_FAILED" : "UNEXPECTED_ERROR";
const requireArguments = (args) => {
  requireQa(args);
  if (args.some((arg) => arg !== "--run" && arg !== `--project=${PROJECT}`)) {
    throw Object.assign(new Error("Argumentos de prueba no válidos."), {code: "INVALID_ARGUMENTS"});
  }
};
const realAccountProjection = (profile, authUser) => ({
  role: profile.role, status: profile.status, institution: profile.institution,
  campus: profile.campus, permissions: profile.permissions,
  isSuperadmin: profile.isSuperadmin === true, groupId: profile.groupId || null,
  studentIds: profile.studentIds || [], activeStudentId: profile.activeStudentId || null,
  disabled: authUser.disabled, emailVerified: authUser.emailVerified,
  tokensValidAfterTime: authUser.tokensValidAfterTime,
});

async function realAccounts(db, auth) {
  const values = {};
  for (const [key, uid] of [["admin", ADMIN], ["student", SARA]]) {
    const [profile, account] = await Promise.all([db.doc(`users/${uid}`).get(), auth.getUser(uid)]);
    assert.ok(profile.exists);
    values[key] = realAccountProjection(profile.data(), account);
  }
  return values;
}

async function validateFixture(db, auth, context, privateData) {
  assert.equal(privateData.projectId, PROJECT);
  assert.equal(privateData.fixtureId, FIXTURE);
  assert.equal(privateData.accounts.length, 4);
  const accounts = {};
  for (const account of privateData.accounts) {
    assert.equal(account.role, ROLES[account.key]);
    assert.equal(account.uid, `${FIXTURE}_${account.key}`);
    assert.ok(!accounts[account.key]);
    const [profile, authUser] = await Promise.all([db.doc(`users/${account.uid}`).get(), auth.getUser(account.uid)]);
    const value = profile.data() || {};
    assert.ok(profile.exists);
    assert.equal(value.testFixtureId, FIXTURE);
    assert.equal(value.status, "activo");
    assert.equal(value.role, account.role);
    assert.equal(value.isSuperadmin, false);
    assert.equal(value.institution, context.institution);
    assert.equal(value.campus, context.campus);
    assert.ok(value.permissions.includes("eventos.ver"));
    assert.equal(authUser.disabled, false);
    assert.equal(authUser.emailVerified, true);
    assert.equal(authUser.email, account.email);
    if (account.role === "Familiar") {
      assert.deepEqual(value.studentIds, [SARA]);
      assert.equal(value.activeStudentId, SARA);
    }
    accounts[account.key] = account;
  }
  assert.deepEqual(Object.keys(accounts).sort(), Object.keys(ROLES).sort());
  return accounts;
}

async function expectedFailure(api, name, data, code) {
  let rejected = null;
  try {
    await api(name, data);
  } catch (error) {
    rejected = error;
  }
  assert.ok(rejected, "Se esperaba un rechazo del backend.");
  assert.equal(rejected.code, code);
}

function createReport(runId, run) {
  return {projectId: PROJECT, runId, mode: run ? "live-api" : "read-only-plan",
    startedAt: new Date().toISOString(), checks: [],
    realAccountsChanged: null, credentialsExposed: false,
    eventId: null, cleanup: "not-needed", status: "running"};
}

async function main(args = process.argv.slice(2)) {
  requireArguments(args);
  const run = args.includes("--run");
  const runId = `qa_events_smoke_${new Date().toISOString().replace(/[^0-9]/g, "")}_${crypto.randomBytes(4).toString("hex")}`;
  const report = createReport(runId, run);
  const reportPath = path.join(reportDirectory, `${runId}.json`);
  const persist = () => {
    fs.mkdirSync(reportDirectory, {recursive: true});
    fs.writeFileSync(reportPath, JSON.stringify(report, null, 2), {encoding: "utf8", mode: 0o600});
  };
  const check = async (name, task) => {
    const started = Date.now();
    try {
      const result = await task();
      report.checks.push({name, status: "passed", durationMs: Date.now() - started});
      persist();
      return result;
    } catch (error) {
      report.checks.push({name, status: "failed", code: safeCode(error), durationMs: Date.now() - started});
      persist();
      throw error;
    }
  };
  const {db, auth} = services();
  let context; let accounts; let initialReal; let api; let ownedEventId;
  const manifestRef = db.doc(`migration_audit/${runId}`);
  const title = `QA · Integración automática · ${runId.slice(-8)}`;
  try {
    context = await check("real_accounts_and_academic_scope_read_only", () => checkedContext(db, auth));
    initialReal = await realAccounts(db, auth);
    accounts = await check("four_existing_fixture_identities", () => validateFixture(db, auth, context, credentials(false)));
    if (!run) {
      report.status = "ready-not-executed";
      report.plan = ["Create one marked temporary event through deployed QA API",
        "Use four fixture sessions only; no real-user login",
        "Check catalogs, separate carts, prices, materials, QR and individual compliance",
        "Reject early attendance/delivery and unauthorized mutations",
        "Cancel and archive only the temporary owned event; preserve demos and history"];
      return report;
    }
    api = {};
    await check("fixture_authentication_project_and_email_verification", async () => {
      for (const key of Object.keys(ROLES)) api[key] = await session(accounts[key]);
    });
    await manifestRef.create({projectId: PROJECT, testFixtureId: FIXTURE, testSmokeRunId: runId,
      institutionId: context.institution, campusId: context.campus, academicYearId: context.yearId,
      performedBy: accounts.admin.uid, status: "running", createdAt: FieldValue.serverTimestamp()});
    await check("role_scoped_event_contexts", async () => {
      const adminContext = await api.admin("listarContextosEventos");
      const teacherContext = await api.docente("listarContextosEventos");
      assert.equal(adminContext.academicYearId, context.yearId);
      assert.equal(teacherContext.academicYearId, context.yearId);
      assert.ok(adminContext.groups.some((group) => group.id === context.groupId));
      await expectedFailure(api.familiar1, "listarContextosEventos", {}, "PERMISSION_DENIED");
    });
    const startAtMillis = Date.now() + 4 * 3600000;
    const eventData = {title, description: `Prueba automática aislada ${runId}. Sin pagos, entregas ni compromisos reales.`,
      eventType: "student_presentation", subtitle: "Verificación QA; no participar",
      foodEnabled: true, location: "QA · ubicación ficticia", startAtMillis, endAtMillis: startAtMillis + 3600000,
      audienceType: "students", targetStudentIds: [SARA], responsibleUserIds: [accounts.docente.uid],
      registrationRequired: false, requiresFamilyAuthorization: false, links: [],
      publicity: {text: "Ensayo automatizado: no realizar compras reales.", url: ""},
      requirements: [
        {id: "manual_family", label: "Entrega ficticia al familiar", targetType: "family", completionType: "manual", required: true},
        {id: "manual_student", label: "Preparación ficticia", targetType: "student", completionType: "manual", required: true},
        {id: "attendance_family", label: "Asistencia ficticia", targetType: "family", completionType: "attendance", required: false},
      ]};
    ownedEventId = await check("create_and_mark_isolated_draft", async () => {
      let created;
      try {
        created = await api.admin("guardarEvento", eventData);
      } catch (error) {
        // A lost HTTP response must not cause another draft to be created.
        const candidates = (await db.collection("school_events").where("title", "==", title).get()).docs.filter((item) => {
          const value = item.data();
          return value.createdBy === accounts.admin.uid && value.description === eventData.description &&
            value.institutionId === context.institution && value.campusId === context.campus &&
            value.academicYearId === context.yearId && value.status === "draft";
        });
        if (candidates.length !== 1) throw error;
        created = {eventId: candidates[0].id};
      }
      const ref = db.doc(`school_events/${created.eventId}`);
      const snapshot = await ref.get();
      assert.equal(snapshot.data()?.createdBy, accounts.admin.uid);
      assert.equal(snapshot.data()?.description, eventData.description);
      assert.equal(snapshot.data()?.status, "draft");
      ownedEventId = created.eventId;
      report.eventId = ownedEventId;
      report.cleanup = "pending";
      // Marker only: event business data is never written with Admin SDK.
      await ref.update({testFixtureId: FIXTURE, testSmokeRunId: runId}, {lastUpdateTime: snapshot.updateTime});
      await manifestRef.update({eventId: ownedEventId});
      return ownedEventId;
    });
    const eventId = ownedEventId;
    await check("publish_temporary_event", async () => {
      const published = await api.admin("cambiarEstadoEvento", {eventId, expectedRevision: 1, status: "published"});
      assert.equal(published.revision, 2);
    });
    let itemId;
    await check("admin_catalog_and_teacher_denial", async () => {
      const data = {eventId, name: "Alimento ficticio QA", description: "No pagar ni consumir: dato de prueba", priceCop: 3000, active: true};
      await expectedFailure(api.docente, "guardarAlimentoEvento", data, "PERMISSION_DENIED");
      const item = await api.admin("guardarAlimentoEvento", data);
      itemId = item.itemId;
      assert.equal(item.revision, 1);
    });
    const orderInput = {eventId, studentId: SARA, expectedRevision: 0,
      requestId: `${runId}_order1`, expectedTotalCop: 3000, lines: [{itemId, quantity: 1}]};
    let firstOrder; let secondOrder;
    await check("price_tampering_and_parent_scope_rejected", async () => {
      await expectedFailure(api.familiar1, "reservarAlimentosEvento", {...orderInput, totalCop: 1}, "INVALID_ARGUMENT");
      await expectedFailure(api.familiar1, "reservarAlimentosEvento", {...orderInput, studentId: ADMIN}, "PERMISSION_DENIED");
      await expectedFailure(api.familiar1, "guardarAlimentoEvento", {eventId, name: "No permitido", priceCop: 1, active: true}, "PERMISSION_DENIED");
    });
    await check("family_order_and_idempotent_replay", async () => {
      firstOrder = await api.familiar1("reservarAlimentosEvento", orderInput);
      assert.equal(firstOrder.totalCop, 3000);
      assert.deepEqual(await api.familiar1("reservarAlimentosEvento", orderInput), firstOrder);
    });
    await check("second_family_independent_cart_and_private_projection", async () => {
      const before = await api.familiar2("obtenerDetalleEvento", {eventId, studentId: SARA});
      assert.deepEqual(before.orders, []);
      assert.deepEqual(before.participants, []);
      secondOrder = await api.familiar2("reservarAlimentosEvento", {...orderInput,
        requestId: `${runId}_order2`, expectedTotalCop: 6000, lines: [{itemId, quantity: 2}]});
      assert.notEqual(firstOrder.orderId, secondOrder.orderId);
      const firstDetail = await api.familiar1("obtenerDetalleEvento", {eventId, studentId: SARA});
      const secondDetail = await api.familiar2("obtenerDetalleEvento", {eventId, studentId: SARA});
      assert.equal(firstDetail.orders.length, 1);
      assert.equal(secondDetail.orders.length, 1);
      assert.equal(firstDetail.orders[0].familyId, accounts.familiar1.uid);
      assert.equal(secondDetail.orders[0].familyId, accounts.familiar2.uid);
    });
    await check("delegated_teacher_material_without_fake_schedule", async () => {
      const created = await api.docente("guardarMaterialEvento", {eventId, kind: "costume", name: "Traje ficticio QA",
        instructions: "No comprar; comprobación automática", amountCop: 0, address: "Dirección ficticia", url: "",
        groupIds: [context.groupId], active: true});
      assert.equal(created.revision, 1);
      const detail = await api.familiar1("obtenerDetalleEvento", {eventId});
      assert.ok(detail.materials.some((item) => item.id === created.materialId));
    });
    await check("payment_permissions_and_early_delivery_rejected", async () => {
      const data = {eventId, orderId: firstOrder.orderId, expectedRevision: 1,
        requestId: `${runId}_pay`, paymentState: "paid"};
      await expectedFailure(api.familiar1, "gestionarPedidoEvento", data, "PERMISSION_DENIED");
      await expectedFailure(api.docente, "gestionarPedidoEvento", {...data,
        requestId: `${runId}_early_delivery`, deliveryState: "delivered"}, "FAILED_PRECONDITION");
      // This is only a fictional accounting mark in the isolated QA event.
      assert.equal((await api.docente("gestionarPedidoEvento", data)).revision, 2);
      await expectedFailure(api.familiar1, "reservarAlimentosEvento", {...orderInput,
        expectedRevision: 2, requestId: `${runId}_paid_edit`}, "FAILED_PRECONDITION");
    });
    let familyQr;
    await check("family_qr_preparation_has_no_business_side_effect", async () => {
      familyQr = await api.familiar1("obtenerCredencialQr", {targetType: "user", targetId: accounts.familiar1.uid});
      assert.equal(familyQr.status, "active");
      const prepared = await api.docente("prepararAccionesEventoQr", {eventId, payload: familyQr.payload, source: "manual", clientPlatform: "web"});
      assert.equal(prepared.targetType, "family");
      assert.deepEqual(prepared.students.map((student) => student.id), [SARA]);
      assert.ok(prepared.requirementIds.includes("manual_family"));
      const detail = await api.familiar1("obtenerDetalleEvento", {eventId});
      assert.deepEqual(detail.completions, []);
    });
    await check("explicit_qr_confirmation_individual_and_idempotent", async () => {
      const data = {eventId, requirementId: "manual_family", targetType: "family", targetId: accounts.familiar1.uid,
        studentId: SARA, completed: true, expectedRevision: 0, requestId: `${runId}_family_complete`, qrPayload: familyQr.payload};
      const saved = await api.docente("guardarCumplimientoEvento", data);
      assert.equal(saved.revision, 1);
      assert.deepEqual(await api.docente("guardarCumplimientoEvento", data), saved);
      const first = await api.familiar1("obtenerDetalleEvento", {eventId});
      const second = await api.familiar2("obtenerDetalleEvento", {eventId});
      assert.equal(first.completions.length, 1);
      assert.equal(first.completions[0].targetId, accounts.familiar1.uid);
      assert.deepEqual(second.completions, []);
      await expectedFailure(api.docente, "guardarCumplimientoEvento", {...data,
        requirementId: "attendance_family", requestId: `${runId}_early_attendance`}, "FAILED_PRECONDITION");
    });
    await check("student_requirement_is_visible_to_both_linked_families", async () => {
      await api.docente("guardarCumplimientoEvento", {eventId, requirementId: "manual_student", targetType: "student",
        targetId: SARA, studentId: SARA, completed: true, expectedRevision: 0, requestId: `${runId}_student_complete`});
      for (const key of ["familiar1", "familiar2"]) {
        const detail = await api[key]("obtenerDetalleEvento", {eventId});
        assert.equal(detail.completions.filter((item) => item.requirementId === "manual_student" && item.completed).length, 1);
      }
    });
    await check("event_qr_opens_context_and_revocation_is_enforced", async () => {
      const qr = await api.admin("obtenerCredencialQr", {targetType: "event", targetId: eventId});
      const prepared = await api.familiar1("prepararAccionesEventoQr", {payload: qr.payload, studentId: SARA});
      assert.equal(prepared.eventId, eventId);
      await api.admin("administrarCredencialQr", {targetType: "event", targetId: eventId, action: "revoke",
        expectedRevision: qr.revision, confirmation: `revoke:${eventId}`});
      await expectedFailure(api.familiar1, "prepararAccionesEventoQr", {payload: qr.payload, studentId: SARA}, "PERMISSION_DENIED");
    });
    await check("notification_audiences_exclude_uninvolved_family", async () => {
      const notifications = await db.collection("event_notification_events").where("eventId", "==", eventId).get();
      const firstOrders = notifications.docs.map((item) => item.data()).filter((value) => value.kind === "order_changed" && value.familyIds?.includes(accounts.familiar1.uid));
      assert.ok(firstOrders.length >= 2);
      assert.ok(firstOrders.every((value) => value.recipientUserIds.includes(accounts.familiar1.uid) && !value.recipientUserIds.includes(accounts.familiar2.uid) && !value.recipientUserIds.includes(SARA)));
      report.notificationEvidence = "outbox-audience-only; not-device-delivery";
    });
    report.status = "passed";
  } catch (error) {
    report.status = "failed";
    report.failureCode = safeCode(error);
    process.exitCode = 1;
  } finally {
    if (run && ownedEventId && api?.admin) {
      try {
        await check("archive_only_owned_temporary_event", async () => {
          const ref = db.doc(`school_events/${ownedEventId}`);
          let current = (await ref.get()).data();
          assert.equal(current?.testSmokeRunId, runId);
          assert.equal(current?.testFixtureId, FIXTURE);
          assert.equal(current?.createdBy, accounts.admin.uid);
          assert.equal(current?.institutionId, context.institution);
          assert.equal(current?.campusId, context.campus);
          if (["draft", "published"].includes(current.status)) {
            await api.admin("cambiarEstadoEvento", {eventId: ownedEventId, expectedRevision: current.revision, status: "cancelled"});
            current = (await ref.get()).data();
          }
          if (["closed", "cancelled"].includes(current.status)) {
            await api.admin("cambiarEstadoEvento", {eventId: ownedEventId, expectedRevision: current.revision, status: "archived"});
          }
          assert.equal((await ref.get()).data()?.status, "archived");
          report.cleanup = "archived-history-preserved";
        });
      } catch (error) {
        report.cleanup = "pending-manual-review-owned-event-only";
        report.cleanupCode = safeCode(error);
        report.status = "failed";
        process.exitCode = 1;
      }
    }
    if (initialReal) {
      try {
        await check("real_admin_and_student_profiles_auth_unchanged", async () => {
          assert.deepEqual(await realAccounts(db, auth), initialReal);
          report.realAccountsChanged = false;
        });
      } catch {
        report.realAccountsChanged = "concurrent-change-detected-investigate";
        report.status = "failed";
        process.exitCode = 1;
      }
    }
    report.finishedAt = new Date().toISOString();
    persist();
    if (run) {
      try {
        if ((await manifestRef.get()).exists) {
          await manifestRef.update({status: report.status,
            cleanup: report.cleanup, completedChecks: report.checks.filter((item) => item.status === "passed").length,
            finishedAt: FieldValue.serverTimestamp()});
        }
      } catch {
        report.manifestAudit = "update-failed-local-report-preserved";
        persist();
      }
    }
    console.log(JSON.stringify({projectId: PROJECT, status: report.status,
      passed: report.checks.filter((item) => item.status === "passed").length,
      failed: report.checks.filter((item) => item.status === "failed").map((item) => ({name: item.name, code: item.code})),
      cleanup: report.cleanup, reportPath}));
  }
  return report;
}

module.exports = {main, requireArguments, safeCode, realAccountProjection};
if (require.main === module) {
  main().catch((error) => {
    console.error(JSON.stringify({status: "failed-before-run", code: safeCode(error)}));
    process.exitCode = 1;
  });
}
/* eslint-enable max-len */
