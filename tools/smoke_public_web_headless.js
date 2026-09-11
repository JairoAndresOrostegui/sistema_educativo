"use strict";

// Read-only public-page smoke. No credentials, personal browser profile or GUI.
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const {spawn} = require("node:child_process");
const {setTimeout: pause} = require("node:timers/promises");

const ORIGINS = {
  qa: "https://sistema-educativo-rl.web.app",
  prod: "https://liceobilinguerodolfollinas.edu.co",
};

function safeUrl(value) {
  try {
    const url = new URL(value);
    if (!["https:", "http:", "wss:", "ws:"].includes(url.protocol)) {
      return `${url.protocol}[inline-resource]`;
    }
    // Neither API keys nor storage download tokens belong in test artifacts.
    const hadQuery = url.search.length > 0;
    url.search = "";
    url.username = "";
    url.password = "";
    return `${url.origin}${url.pathname}${hadQuery ? "?[redacted]" : ""}${url.hash}`;
  } catch {
    return String(value).slice(0, 1500);
  }
}

function safeText(value) {
  return String(value).replace(/https?:\/\/[^\s"'<>]+/g, safeUrl).slice(0, 4000);
}

class Cdp {
  constructor(socket) {
    this.socket = socket;
    this.nextId = 0;
    this.pending = new Map();
    this.listeners = new Map();
    socket.addEventListener("message", (event) => {
      const message = JSON.parse(String(event.data));
      if (message.id) {
        const pending = this.pending.get(message.id);
        if (!pending) return;
        clearTimeout(pending.timer);
        this.pending.delete(message.id);
        if (message.error) pending.reject(new Error(message.error.message));
        else pending.resolve(message.result);
      } else {
        for (const listener of this.listeners.get(message.method) || []) {
          listener(message.params || {});
        }
      }
    });
    socket.addEventListener("close", () => {
      for (const pending of this.pending.values()) {
        clearTimeout(pending.timer);
        pending.reject(new Error("Browser connection closed"));
      }
      this.pending.clear();
    });
  }

  static async connect(url) {
    const socket = new WebSocket(url);
    await new Promise((resolve, reject) => {
      socket.addEventListener("open", resolve, {once: true});
      socket.addEventListener("error", () => reject(new Error("CDP connect failed")),
          {once: true});
    });
    return new Cdp(socket);
  }

  on(method, listener) {
    if (!this.listeners.has(method)) this.listeners.set(method, []);
    this.listeners.get(method).push(listener);
  }

  send(method, params = {}) {
    const id = ++this.nextId;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`CDP timeout: ${method}`));
      }, 20000);
      this.pending.set(id, {resolve, reject, timer});
      this.socket.send(JSON.stringify({id, method, params}));
    });
  }

  async evaluate(expression) {
    const result = await this.send("Runtime.evaluate", {
      expression, returnByValue: true, awaitPromise: true,
    });
    if (result.exceptionDetails) {
      throw new Error(safeText(result.exceptionDetails.text));
    }
    return result.result?.value;
  }
}

async function browserAddress(profile, browser) {
  const marker = path.join(profile, "DevToolsActivePort");
  for (let attempt = 0; attempt < 100; attempt++) {
    if (browser.exitCode !== null) throw new Error("Headless browser exited");
    if (fs.existsSync(marker)) {
      const [port, browserPath] = fs.readFileSync(marker, "utf8").trim().split(/\r?\n/);
      return {port: Number(port), websocket: `ws://127.0.0.1:${port}${browserPath}`};
    }
    await pause(100);
  }
  throw new Error("Headless browser did not start CDP");
}

async function inspectPage(browserCdp, address, url, label, folder) {
  const target = await browserCdp.send("Target.createTarget", {url: "about:blank"});
  const pages = await (await fetch(`http://127.0.0.1:${address.port}/json/list`)).json();
  const page = pages.find((item) => item.id === target.targetId);
  if (!page?.webSocketDebuggerUrl) throw new Error("Missing browser page");
  const cdp = await Cdp.connect(page.webSocketDebuggerUrl);
  const report = {label, url: safeUrl(url), console: [], errors: [],
    failedRequests: [], httpErrors: [], requests: []};
  const requestUrls = new Map();
  cdp.on("Runtime.consoleAPICalled", (event) => {
    report.console.push({type: event.type, text: safeText((event.args || [])
        .map((arg) => arg.value ?? arg.description ?? arg.type).join(" "))});
  });
  cdp.on("Runtime.exceptionThrown", (event) => {
    const details = event.exceptionDetails;
    report.errors.push(safeText(details?.exception?.description || details?.text));
  });
  cdp.on("Log.entryAdded", ({entry}) => {
    if (["warning", "error"].includes(entry.level)) {
      report.console.push({type: entry.level, text: safeText(entry.text)});
    }
  });
  cdp.on("Network.requestWillBeSent", (event) => {
    requestUrls.set(event.requestId, safeUrl(event.request.url));
    report.requests.push({url: safeUrl(event.request.url),
      method: event.request.method, type: event.type});
  });
  cdp.on("Network.responseReceived", (event) => {
    if (event.response.status >= 400) {
      report.httpErrors.push({url: safeUrl(event.response.url),
        status: event.response.status, mimeType: event.response.mimeType});
    }
  });
  cdp.on("Network.loadingFailed", (event) => {
    report.failedRequests.push({url: requestUrls.get(event.requestId),
      error: safeText(event.errorText), canceled: event.canceled === true,
      blockedReason: event.blockedReason});
  });
  try {
    await Promise.all([cdp.send("Page.enable"), cdp.send("Runtime.enable"),
      cdp.send("Network.enable"), cdp.send("Log.enable")]);
    await cdp.send("Emulation.setDeviceMetricsOverride", {
      width: 1366, height: 900, deviceScaleFactor: 1, mobile: false,
    });
    await cdp.send("Network.setCacheDisabled", {cacheDisabled: true});
    const navigation = await cdp.send("Page.navigate", {url});
    if (navigation.errorText) throw new Error(navigation.errorText);
    // Flutter's canvas is not sufficient proof of content; capture after data
    // and fonts settle, then collect accessibility labels for manual review.
    let mounted = false;
    for (let attempt = 0; attempt < 45; attempt++) {
      mounted = await cdp.evaluate(
          "!!document.querySelector('flutter-view,flt-glass-pane')");
      if (mounted) break;
      await pause(1000);
    }
    await pause(12000);
    report.flutterMounted = mounted;
    report.document = await cdp.evaluate(`({
      title: document.title, readyState: document.readyState,
      location: location.origin + location.pathname + location.hash,
      canvasCount: document.querySelectorAll('canvas').length,
      scripts: Array.from(document.scripts).map(s => s.src).filter(Boolean),
      bodyText: document.body.innerText.slice(0, 4000)
    })`);
    report.document.scripts = report.document.scripts.map(safeUrl);
    report.build = await cdp.evaluate(`(async () => {
      const markers = {};
      for (const file of ['environment.json', 'version.json']) {
        try {
          const response = await fetch('/' + file, {
            cache: 'no-store', credentials: 'omit'
          });
          markers[file] = {status: response.status, data: await response.json()};
        } catch { markers[file] = {unavailable: true}; }
      }
      return markers;
    })()`);
    await cdp.evaluate(`(() => {
      function enable(root) {
        const toggle = root.querySelector('flt-semantics-placeholder');
        if (toggle) { toggle.click(); return true; }
        for (const node of root.querySelectorAll('*')) {
          if (node.shadowRoot && enable(node.shadowRoot)) return true;
        }
        return false;
      }
      return enable(document);
    })()`);
    await pause(1000);
    const accessibility = await cdp.send("Accessibility.getFullAXTree");
    report.accessibility = accessibility.nodes.filter((node) => !node.ignored)
        .map((node) => ({role: node.role?.value, name: safeText(node.name?.value || "")}));
    const screenshot = await cdp.send("Page.captureScreenshot", {
      format: "png", captureBeyondViewport: false,
    });
    fs.writeFileSync(path.join(folder, `${label}.png`), Buffer.from(screenshot.data, "base64"));
    report.screenshot = `${label}.png`;
    return report;
  } finally {
    cdp.socket.close();
    await browserCdp.send("Target.closeTarget", {targetId: target.targetId});
  }
}

async function main() {
  const args = process.argv.slice(2);
  const environment = args.find((arg) => arg.startsWith("--env="))?.slice(6);
  if (!ORIGINS[environment] || args.some((arg) =>
    arg !== "--run" && !arg.startsWith("--env="))) {
    throw new Error("Usage: --env=qa|prod [--run]. Without --run no browser opens.");
  }
  const candidates = ["C:/Program Files/Google/Chrome/Application/chrome.exe",
    "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"];
  const executable = candidates.find((item) => fs.existsSync(item));
  if (!executable) throw new Error("Chrome/Edge not installed");
  if (!args.includes("--run")) {
    console.log(JSON.stringify({mode: "prepared", executable,
      urls: [ORIGINS[environment], `${ORIGINS[environment]}/#/login`]}));
    return;
  }
  const folder = path.resolve(__dirname, "../.buildlog",
      `web-smoke-${environment}-${Date.now()}`);
  fs.mkdirSync(folder, {recursive: true});
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), "llinas-smoke-"));
  const browser = spawn(executable, ["--headless=new", "--no-first-run",
    "--no-default-browser-check", "--disable-background-networking",
    "--disable-extensions", "--remote-debugging-port=0",
    `--user-data-dir=${profile}`, "--use-angle=swiftshader",
    "--enable-unsafe-swiftshader", "about:blank"],
  {windowsHide: true, stdio: ["ignore", "ignore", "pipe"]});
  let stderr = "";
  browser.stderr.on("data", (chunk) => {stderr += safeText(chunk);});
  let browserCdp;
  try {
    const address = await browserAddress(profile, browser);
    browserCdp = await Cdp.connect(address.websocket);
    const reports = [];
    for (const [label, suffix] of [["public", "/"], ["login", "/#/login"]]) {
      const report = await inspectPage(browserCdp, address,
          `${ORIGINS[environment]}${suffix}`, label, folder);
      reports.push(report);
      fs.writeFileSync(path.join(folder, `${label}.json`), JSON.stringify(report, null, 2));
      console.log(JSON.stringify({environment, page: label, folder,
        mounted: report.flutterMounted, errors: report.errors.length,
        httpErrors: report.httpErrors.length, failedRequests: report.failedRequests.length}));
    }
    if (reports.some((report) => !report.flutterMounted || report.errors.length)) {
      process.exitCode = 1;
    }
  } finally {
    if (browserCdp) {
      await browserCdp.send("Browser.close").catch(() => {});
      browserCdp.socket.close();
    }
    for (let attempt = 0; attempt < 50 && browser.exitCode === null; attempt++) {
      await pause(100);
    }
    if (browser.exitCode === null) {
      const closer = spawn("taskkill.exe", ["/PID", String(browser.pid), "/T", "/F"],
          {windowsHide: true, stdio: "ignore"});
      await new Promise((resolve) => closer.once("exit", resolve));
      await pause(1000);
    }
    fs.writeFileSync(path.join(folder, "browser.log"), stderr);
    const resolvedProfile = path.resolve(profile);
    const tempRoot = path.resolve(os.tmpdir()) + path.sep;
    if (resolvedProfile.startsWith(tempRoot) &&
        path.basename(resolvedProfile).startsWith("llinas-smoke-") &&
        browser.exitCode !== null) {
      fs.rmSync(resolvedProfile, {recursive: true, force: true, maxRetries: 3});
    } else {
      console.log(JSON.stringify({temporaryProfilePreserved: resolvedProfile}));
    }
  }
}

if (require.main === module) main().catch((error) => {
  console.error(safeText(error.message));
  process.exitCode = 1;
});
module.exports = {safeUrl, safeText};
