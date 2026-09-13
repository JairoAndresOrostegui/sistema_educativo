"use strict";

// QA-only authenticated acceptance. Never logs credentials, AX text, screenshots,
// request bodies, tokens or student names. Login/push ownership affects only the
// explicitly provisioned disposable fixtures, never the real administrator/Sara.
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const crypto = require("node:crypto");
const {spawn} = require("node:child_process");
const {setTimeout: pause} = require("node:timers/promises");
const {Cdp, browserAddress} = require("./smoke_public_web_headless");

const ORIGIN = "https://sistema-educativo-rl.web.app";
const PROJECT = "sistema-educativo-rl";
const FIXTURE = "qa_events_qr_2026_09";
const PRIVATE_FILE = path.join(os.homedir(), ".config", "sistema_educativo", "qa-eventos-2026-09.json");
const ROLES = {admin: "Administrador", docente: "Docente", familiar1: "Familiar"};
const HOME = {admin: "/admin_dashboard", docente: "/teacher_dashboard", familiar1: "/student_dashboard"};

class SmokeFailure extends Error {
  constructor(code) { super(code); this.code = code; }
}
function check(value, code) { if (!value) throw new SmokeFailure(code); }
function hash(bytes) { return crypto.createHash("sha256").update(bytes).digest("hex"); }

function readFixtures() {
  check(fs.existsSync(PRIVATE_FILE), "FIXTURES_NOT_PROVISIONED");
  const data = JSON.parse(fs.readFileSync(PRIVATE_FILE, "utf8"));
  check(data.projectId === PROJECT && data.fixtureId === FIXTURE, "PRIVATE_FILE_NOT_QA_FIXTURE");
  return Object.entries(ROLES).map(([key, role]) => {
    const account = data.accounts.find((item) => item.key === key);
    check(account && account.uid === `${FIXTURE}_${key}` && account.role === role &&
      account.email === `qa.eventos.${key}@desarrolloytecnologiasantander.com` &&
      typeof account.password === "string" && account.password.length >= 16, "UNSAFE_FIXTURE_IDENTITY");
    return account;
  });
}

async function verifyHostedBuild(expectedHash) {
  check(/^[a-f0-9]{64}$/.test(expectedHash || ""), "EXPECTED_BUILD_HASH_REQUIRED");
  const [envResponse, appResponse] = await Promise.all([
    fetch(`${ORIGIN}/environment.json?smoke=${Date.now()}`, {cache: "no-store", signal: AbortSignal.timeout(30000)}),
    fetch(`${ORIGIN}/main.dart.js?smoke=${Date.now()}`, {cache: "no-store", signal: AbortSignal.timeout(30000)}),
  ]);
  check(envResponse.ok && appResponse.ok, "QA_BUILD_NOT_AVAILABLE");
  const env = await envResponse.json();
  check(env.projectId === PROJECT && env.environment === "qa", "HOSTED_ENVIRONMENT_NOT_QA");
  check(hash(Buffer.from(await appResponse.arrayBuffer())) === expectedHash, "HOSTED_BUILD_IS_NOT_EXPECTED_BUILD");
}

async function enableSemantics(cdp) {
  return cdp.evaluate(`(() => {
    function visit(root) {
      const toggle = root.querySelector('flt-semantics-placeholder');
      if (toggle) { toggle.click(); return true; }
      for (const node of root.querySelectorAll('*')) {
        if (node.shadowRoot && visit(node.shadowRoot)) return true;
      }
      return false;
    }
    return visit(document);
  })()`);
}
async function ax(cdp) {
  const tree = await cdp.send("Accessibility.getFullAXTree");
  return tree.nodes.filter((item) => !item.ignored);
}
function matches(node, text, role) {
  return (!role || node.role?.value === role) && text.test(node.name?.value || "");
}
async function waitNode(cdp, text, {role, attempts = 25, scroll = false} = {}) {
  for (let attempt = 0; attempt < attempts; attempt++) {
    await enableSemantics(cdp);
    const nodes = await ax(cdp);
    const found = nodes.find((item) => matches(item, text, role));
    if (found) return found;
    if (scroll && attempt > 1) await wheel(cdp, 420);
    await pause(350);
  }
  return null;
}
async function wheel(cdp, deltaY) {
  const viewport = await cdp.evaluate("({width: innerWidth, height: innerHeight})");
  await cdp.send("Input.dispatchMouseEvent", {type: "mouseWheel", x: Math.floor(viewport.width / 2),
    y: Math.floor(viewport.height * 0.65), deltaX: 0, deltaY});
  await pause(150);
}
async function clickNode(cdp, node) {
  check(node?.backendDOMNodeId, "SEMANTICS_NODE_UNAVAILABLE");
  await cdp.send("DOM.scrollIntoViewIfNeeded", {backendNodeId: node.backendDOMNodeId}).catch(() => {});
  await pause(100);
  const box = await cdp.send("DOM.getBoxModel", {backendNodeId: node.backendDOMNodeId});
  const corners = box.model.border;
  const x = (corners[0] + corners[2] + corners[4] + corners[6]) / 4;
  const y = (corners[1] + corners[3] + corners[5] + corners[7]) / 4;
  const viewport = await cdp.evaluate("({width: innerWidth, height: innerHeight})");
  check(x > 0 && y > 0 && x < viewport.width && y < viewport.height, "TARGET_OUTSIDE_VIEWPORT");
  await cdp.send("Input.dispatchMouseEvent", {type: "mouseMoved", x, y});
  await cdp.send("Input.dispatchMouseEvent", {type: "mousePressed", x, y, button: "left", clickCount: 1});
  await cdp.send("Input.dispatchMouseEvent", {type: "mouseReleased", x, y, button: "left", clickCount: 1});
  await pause(250);
}

async function navigateHash(cdp, route) {
  // Location hash only: preserves the app session without injecting Auth state.
  await cdp.evaluate(`location.hash = ${JSON.stringify(`#${route}`)}`);
  await pause(700);
}

async function inspectRole(executable, account) {
  const report = {role: account.key, login: false, menu: false, eventsList: false,
    details: [], jsErrors: 0, consoleErrors: 0, consoleWarnings: 0, httpErrors: [],
    failedRequests: 0, functions: [], screenshots: false, credentialsLogged: false};
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), "llinas-qa-events-"));
  const browser = spawn(executable, ["--headless=new", "--no-first-run", "--no-default-browser-check",
    "--disable-background-networking", "--disable-extensions", "--remote-debugging-port=0",
    `--user-data-dir=${profile}`, "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "about:blank"],
  {windowsHide: true, stdio: "ignore"});
  let browserCdp;
  let cdp;
  const eventIds = new Map();
  const responseIds = new Set();
  const observedFunctions = new Set();
  const responseJobs = new Set();
  try {
    const address = await browserAddress(profile, browser);
    browserCdp = await Cdp.connect(address.websocket);
    await browserCdp.send("Browser.setPermission", {permission: {name: "notifications"}, setting: "denied", origin: ORIGIN});
    const target = await browserCdp.send("Target.createTarget", {url: "about:blank"});
    const pages = await (await fetch(`http://127.0.0.1:${address.port}/json/list`)).json();
    const page = pages.find((item) => item.id === target.targetId);
    cdp = await Cdp.connect(page.webSocketDebuggerUrl);
    cdp.on("Runtime.exceptionThrown", () => { report.jsErrors++; });
    cdp.on("Runtime.consoleAPICalled", ({type}) => {
      if (type === "error") report.consoleErrors++;
      if (type === "warning") report.consoleWarnings++;
    });
    cdp.on("Network.loadingFailed", ({canceled}) => { if (!canceled) report.failedRequests++; });
    cdp.on("Network.requestWillBeSent", ({request}) => {
      const url = new URL(request.url);
      if (url.hostname === `us-central1-${PROJECT}.cloudfunctions.net`) {
        const name = url.pathname.slice(1);
        if (/^[A-Za-z][A-Za-z0-9]+$/.test(name)) observedFunctions.add(name);
      }
    });
    cdp.on("Network.responseReceived", ({requestId, response}) => {
      const url = new URL(response.url);
      if (response.status >= 400) report.httpErrors.push({host: url.hostname, status: response.status});
      if (url.hostname === `us-central1-${PROJECT}.cloudfunctions.net` && url.pathname === "/listarEventos" && response.status === 200) {
        responseIds.add(requestId);
      }
    });
    cdp.on("Network.loadingFinished", ({requestId}) => {
      if (!responseIds.delete(requestId)) return;
      const job = (async () => {
        const body = await cdp.send("Network.getResponseBody", {requestId});
        const data = JSON.parse(body.base64Encoded ? Buffer.from(body.body, "base64").toString("utf8") : body.body);
        for (const event of data.result?.events || []) {
          if (event.title === "QA · Presentación de baile") eventIds.set("presentation", event.id);
          if (event.title === "QA · Encuentro de padres") eventIds.set("meeting", event.id);
        }
      })().catch(() => {});
      responseJobs.add(job);
      void job.finally(() => responseJobs.delete(job));
    });
    await Promise.all([cdp.send("Page.enable"), cdp.send("Runtime.enable"), cdp.send("Network.enable"), cdp.send("Accessibility.enable")]);
    await cdp.send("Emulation.setDeviceMetricsOverride", {width: 1366, height: 900, deviceScaleFactor: 1, mobile: false});
    await cdp.send("Network.setCacheDisabled", {cacheDisabled: true});
    await cdp.send("Page.navigate", {url: `${ORIGIN}/#/login`});
    const email = await waitNode(cdp, /correo/i, {role: "textbox", attempts: 100});
    check(email, "LOGIN_EMAIL_FIELD_NOT_ACCESSIBLE");
    await clickNode(cdp, email);
    await cdp.send("Input.insertText", {text: account.email});
    const password = await waitNode(cdp, /contras[eñn]/i, {role: "textbox"});
    check(password, "LOGIN_PASSWORD_FIELD_NOT_ACCESSIBLE");
    await clickNode(cdp, password);
    await cdp.send("Input.insertText", {text: account.password});
    const login = await waitNode(cdp, /iniciar sesi[oó]n/i, {role: "button"});
    check(login, "LOGIN_BUTTON_NOT_ACCESSIBLE");
    await clickNode(cdp, login);
    let route = "";
    for (let attempt = 0; attempt < 100; attempt++) {
      route = await cdp.evaluate("location.hash.split('?')[0]");
      if (route === `#${HOME[account.key]}`) break;
      await pause(350);
    }
    check(route === `#${HOME[account.key]}`, "FIXTURE_LOGIN_DID_NOT_REACH_ITS_DASHBOARD");
    report.login = true;
    const menu = await waitNode(cdp, /^Eventos\b/, {role: "button", scroll: true});
    check(menu, "EVENTS_MENU_NOT_ACCESSIBLE");
    await clickNode(cdp, menu);
    report.menu = true;
    check(await waitNode(cdp, /QA · Presentación de baile/), "QA_EVENT_NOT_VISIBLE_IN_LIST");
    await Promise.all([...responseJobs]);
    check(eventIds.has("presentation") && eventIds.has("meeting"), "QA_FIXTURE_EVENT_IDS_NOT_OBSERVED");
    report.eventsList = true;
    for (const width of [1366, 320]) {
      await cdp.send("Emulation.setDeviceMetricsOverride", {width, height: 900, deviceScaleFactor: 1, mobile: false});
      for (const kind of ["presentation", "meeting"]) {
        await navigateHash(cdp, HOME[account.key]);
        check(await waitNode(cdp, /^Eventos\b/, {role: "button", scroll: true}), "HOME_NOT_RESTORED");
        await navigateHash(cdp, `/events?eventId=${encodeURIComponent(eventIds.get(kind))}`);
        check(await waitNode(cdp, /^Detalle del evento$/), "EVENT_DETAIL_NOT_OPENED");
        const seen = new Set();
        for (let step = 0; step < 12; step++) {
          for (const node of await ax(cdp)) {
            const label = node.name?.value || "";
            // Store only allowlisted UI labels, never people, fields or content.
            for (const expected of ["Información", "Preparación", "Alimentos", "Seguimiento", "Hijo seleccionado",
              "Agregar alimento", "Agregar material o traje", "Registrar cumplimiento", "Reservar alimentos"] ) {
              // Flutter merges some expanded tiles and field values into their
              // accessible name; validate the fixed leading control label.
              if (label === expected || label.startsWith(`${expected}\n`) || label.startsWith(`${expected} `)) seen.add(expected);
            }
          }
          await wheel(cdp, 450);
        }
        const item = {width, kind, information: seen.has("Información"), preparation: seen.has("Preparación"),
          tracking: seen.has("Seguimiento"), food: seen.has("Alimentos"), familySelector: seen.has("Hijo seleccionado"),
          configureFood: seen.has("Agregar alimento"), materials: seen.has("Agregar material o traje"),
          fulfillment: seen.has("Registrar cumplimiento"), reserve: seen.has("Reservar alimentos")};
        report.details.push(item);
        check(item.information && item.preparation && item.tracking && item.food === (kind === "presentation"), "DETAIL_SECTIONS_MISSING");
        check(item.fulfillment === (account.key !== "familiar1"), "FULFILLMENT_ROLE_CONTROLS_MISMATCH");
        check(item.materials === (account.key !== "familiar1"), "MATERIAL_ROLE_CONTROLS_MISMATCH");
        check(item.configureFood === (kind === "presentation" && account.key === "admin"), "FOOD_ADMIN_CONTROL_MISMATCH");
        check(item.reserve === (kind === "presentation" && account.key === "familiar1"), "FAMILY_RESERVATION_CONTROL_MISMATCH");
        check(item.familySelector === (account.key === "familiar1"), "FAMILY_STUDENT_SELECTOR_MISMATCH");
      }
    }
    // A normal logout clears only this fixture's owned web slot.
    await navigateHash(cdp, "/logout");
    check(await waitNode(cdp, /iniciar sesi[oó]n/i, {role: "button"}), "FIXTURE_LOGOUT_FAILED");
    report.logout = true;
  } catch (error) {
    report.failure = error instanceof SmokeFailure ? error.code : "BROWSER_AUTOMATION_ERROR";
    // Diagnose semantic matching with allowlisted words only, no actual labels.
    if (cdp) {
      const nodes = await ax(cdp).catch(() => []);
      report.semanticHints = nodes.flatMap((node) =>
        ["Eventos", "Información", "Preparación", "Alimentos", "Seguimiento"].filter((word) =>
          (node.name?.value || "").includes(word)).map((word) => ({word, role: node.role?.value,
          exact: node.name?.value === word})));
    }
  } finally {
    if (cdp && report.login && !report.logout) {
      try {
        await navigateHash(cdp, "/logout");
        report.logout = !!await waitNode(cdp, /iniciar sesi[oó]n/i, {role: "button"});
      } catch { report.logout = false; }
    }
    report.functions = [...observedFunctions].sort();
    if (cdp) cdp.socket.close();
    if (browserCdp) {
      await browserCdp.send("Browser.close").catch(() => {});
      browserCdp.socket.close();
    }
    for (let attempt = 0; attempt < 50 && browser.exitCode === null; attempt++) await pause(100);
    if (browser.exitCode === null) {
      const closer = spawn("taskkill.exe", ["/PID", String(browser.pid), "/T", "/F"], {windowsHide: true, stdio: "ignore"});
      await new Promise((resolve) => closer.once("exit", resolve));
      await pause(500);
    }
    const resolved = path.resolve(profile);
    check(resolved.startsWith(path.resolve(os.tmpdir()) + path.sep) && path.basename(resolved).startsWith("llinas-qa-events-"), "UNSAFE_PROFILE_CLEANUP_PATH");
    if (browser.exitCode !== null) {
      try { fs.rmSync(resolved, {recursive: true, force: true, maxRetries: 3}); report.temporaryProfileRemoved = true; }
      catch { report.temporaryProfileRemoved = false; }
    } else report.temporaryProfileRemoved = false;
  }
  return report;
}

async function main() {
  const args = process.argv.slice(2);
  check(args.every((arg) => arg === "--run" || arg.startsWith("--expected-main-sha256=") || arg.startsWith("--roles=")), "INVALID_ARGUMENTS");
  const roleKeys = args.find((arg) => arg.startsWith("--roles="))?.slice(8).split(",") || Object.keys(ROLES);
  check(roleKeys.length > 0 && roleKeys.every((key) => Object.hasOwn(ROLES, key)), "UNSAFE_ROLE_FILTER");
  const executable = ["C:/Program Files/Google/Chrome/Application/chrome.exe",
    "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"].find((value) => fs.existsSync(value));
  check(executable, "NO_HEADLESS_BROWSER_INSTALLED");
  if (!args.includes("--run")) {
    console.log(JSON.stringify({prepared: true, environment: "qa", credentialsPresent: fs.existsSync(PRIVATE_FILE),
      accountKeys: Object.keys(ROLES), requiresExpectedHostedBuildHash: true,
      screenshots: false, loginSideEffects: "Only disposable QA fixture web session/push slots"}));
    return;
  }
  const expectedHash = args.find((arg) => arg.startsWith("--expected-main-sha256="))?.split("=")[1];
  await verifyHostedBuild(expectedHash);
  const accounts = readFixtures().filter((account) => roleKeys.includes(account.key));
  const folder = path.resolve(__dirname, "../.buildlog", `qa-events-ui-${Date.now()}`);
  fs.mkdirSync(folder, {recursive: true});
  const reports = [];
  for (const account of accounts) {
    const report = await inspectRole(executable, account);
    reports.push(report);
    fs.writeFileSync(path.join(folder, `${account.key}.json`), JSON.stringify(report, null, 2));
    console.log(JSON.stringify({role: report.role, login: report.login, menu: report.menu,
      detailsChecked: report.details.length, failure: report.failure || null, folder}));
  }
  if (reports.some((report) => report.failure || report.jsErrors || report.consoleErrors ||
      report.httpErrors.length || report.failedRequests || !report.logout || !report.temporaryProfileRemoved)) process.exitCode = 1;
}
if (require.main === module) main().catch((error) => {
  console.error(error instanceof SmokeFailure ? error.code : "QA_SMOKE_FAILED_WITHOUT_LOGGING_SENSITIVE_DETAILS");
  process.exitCode = 1;
});
module.exports = {readFixtures, verifyHostedBuild};
