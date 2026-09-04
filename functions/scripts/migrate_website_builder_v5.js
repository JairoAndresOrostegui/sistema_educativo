"use strict";
/* eslint-disable max-len */

const {applicationDefault, initializeApp} = require("firebase-admin/app");
const {FieldValue, getFirestore} = require("firebase-admin/firestore");
const fs = require("fs");
const os = require("os");
const path = require("path");

function firebaseToolsModule(relativePath) {
  const roots = [
    process.env.APPDATA ? path.join(process.env.APPDATA, "npm", "node_modules") : "",
    ...require("module").globalPaths,
  ].filter(Boolean);
  const root = roots.find((item) => fs.existsSync(path.join(item, "firebase-tools")));
  if (!root) throw new Error("No se encontró Firebase CLI.");
  return require(path.join(root, "firebase-tools", relativePath));
}

let credential;
if (process.argv.includes("--firebase-cli-auth")) {
  const firebaseAuth = firebaseToolsModule("lib/auth");
  const firebaseApi = firebaseToolsModule("lib/api");
  const account = firebaseAuth.getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) {
    throw new Error("Firebase CLI no tiene una sesión activa.");
  }
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "website-v5-"));
  const credentialPath = path.join(directory, "credentials.json");
  fs.writeFileSync(credentialPath, JSON.stringify({
    type: "authorized_user",
    client_id: firebaseApi.clientId(),
    client_secret: firebaseApi.clientSecret(),
    refresh_token: account.tokens.refresh_token,
  }), {encoding: "utf8", mode: 0o600});
  process.env.GOOGLE_APPLICATION_CREDENTIALS = credentialPath;
  credential = applicationDefault();
}

initializeApp({credential, projectId: process.env.GCLOUD_PROJECT || "sistema-educativo-rl"});
const db = getFirestore();
const apply = process.argv.includes("--apply");
const verify = process.argv.includes("--verify");

const asset = (value) => {
  if (value && typeof value === "object") {
    return {url: String(value.url || ""), storagePath: String(value.storagePath || "")};
  }
  return {url: String(value || ""), storagePath: ""};
};

function component(block, index) {
  const type = block.type === "imageText" ? "text" :
    ["hero", "text", "image", "button", "contactForm", "divider", "spacer", "socialLinks"]
        .includes(block.type) ? block.type : "text";
  return {
    id: String(block.id || `component_${index}`),
    type,
    title: String(block.title || ""),
    body: String(block.body || ""),
    url: String(block.buttonUrl || ""),
    buttonLabel: String(block.buttonLabel || ""),
    image: asset(block.image || block.imageUrl),
    items: [],
    enabled: block.enabled !== false,
    widthPercent: 100,
    componentAlignment: "left",
    alignment: String(block.textAlignment || "left"),
    imageFit: String(block.imageFit || "cover"),
    backgroundColor: String(block.backgroundColor || "#FFFFFF"),
    textColor: String(block.textColor || "#292323"),
    accentColor: String(block.accentColor || "#A63D40"),
    titleSize: Number(block.titleSize || 34),
    bodySize: Number(block.bodySize || 16),
    padding: Number(block.padding || 20),
    autoplay: true,
    intervalSeconds: 5,
  };
}

function rowForBlock(block, index) {
  const base = component(block, index);
  if (block.type === "imageText" && base.image.url) {
    const imageFirst = block.imagePosition !== "right";
    const imageComponent = {...base, id: `${base.id}_image`, type: "image", title: "", body: "", url: "", buttonLabel: "", backgroundColor: "#FFFFFF", padding: 0};
    const textComponent = {...base, id: `${base.id}_text`, type: "text", image: asset(null)};
    const columns = imageFirst ?
      [{id: `${base.id}_image_column`, span: 1, backgroundColor: "#FFFFFF", padding: 8, components: [imageComponent]},
        {id: `${base.id}_text_column`, span: 1, backgroundColor: "#FFFFFF", padding: 8, components: [textComponent]}] :
      [{id: `${base.id}_text_column`, span: 1, backgroundColor: "#FFFFFF", padding: 8, components: [textComponent]},
        {id: `${base.id}_image_column`, span: 1, backgroundColor: "#FFFFFF", padding: 8, components: [imageComponent]}];
    return {id: `row_${base.id}`, enabled: base.enabled, backgroundColor: String(block.backgroundColor || "#FFFFFF"), padding: 24, gap: 20, maxWidth: 1280, stackOnMobile: true, columns};
  }
  return {
    id: `row_${base.id}`,
    enabled: base.enabled,
    backgroundColor: String(block.backgroundColor || "#FFFFFF"),
    padding: block.type === "hero" ? 0 : 24,
    gap: 20,
    maxWidth: block.type === "hero" ? 1920 : 1280,
    stackOnMobile: true,
    columns: [{id: `column_${base.id}`, span: 1, backgroundColor: "#FFFFFF", padding: block.type === "hero" ? 0 : 8, components: [base]}],
  };
}

function structuralComponent(id, type, values = {}) {
  return {
    id, type, title: "", body: "", url: "", buttonLabel: "",
    image: asset(null), items: [], enabled: true, widthPercent: 100,
    componentAlignment: "left", alignment: "left",
    imageFit: "cover", backgroundColor: "#FFFFFF", textColor: "#292323",
    accentColor: "#A63D40", titleSize: 34, bodySize: 16, padding: 12,
    autoplay: true, intervalSeconds: 5, ...values,
  };
}

function migrateConfig(old) {
  const primary = String(old.primaryColor || "#A63D40");
  const footer = old.footer || {};
  const footerBackground = String(footer.backgroundColor || "#2B1718");
  const footerText = String(footer.textColor || "#FFFFFF");
  const footerComponent = (id, type, values = {}) => structuralComponent(id, type, {
    backgroundColor: footerBackground, textColor: footerText,
    accentColor: String(footer.accentColor || primary), ...values,
  });
  return {
    version: 5,
    schoolName: String(old.schoolName || ""),
    tagline: String(old.tagline || ""),
    logo: asset(old.logo || old.logoUrl),
    phone: String(old.phone || ""),
    email: String(old.email || ""),
    address: String(old.address || ""),
    primaryColor: primary,
    fontFamily: String(old.fontFamily || "Montserrat"),
    navigation: Array.isArray(old.navigation) ? old.navigation : [],
    socialLinks: Array.isArray(old.socialLinks) ? old.socialLinks : [],
    header: {
      enabled: true,
      sticky: true,
      rows: [{
        id: "header_main", enabled: true, backgroundColor: "#FFFFFF", padding: 12,
        gap: 20, maxWidth: 1280, stackOnMobile: true,
        columns: [
          {id: "header_brand", span: 1, backgroundColor: "#FFFFFF", padding: 8, components: [structuralComponent("site_identity", "siteIdentity")]},
          {id: "header_navigation", span: 2, backgroundColor: "#FFFFFF", padding: 8, components: [structuralComponent("site_navigation", "navigation", {alignment: "right", accentColor: primary})]},
        ],
      }],
    },
    footer: {
      enabled: footer.enabled !== false,
      copyrightText: String(footer.copyrightText || ""),
      rows: [{
        id: "footer_main", enabled: true, backgroundColor: footerBackground,
        padding: Number(footer.padding || 34), gap: 28,
        maxWidth: Number(footer.maxWidth || 1280), stackOnMobile: true,
        columns: [
          {id: "footer_identity", span: 1, backgroundColor: footerBackground, padding: 8, components: [
            footerComponent("footer_brand", "siteIdentity"),
            footerComponent("footer_social", "socialLinks"),
          ]},
          {id: "footer_contact", span: 1, backgroundColor: footerBackground, padding: 8, components: [footerComponent("footer_contact_component", "contactInfo", {title: String(footer.contactTitle || "Contáctanos")})]},
          ...(footer.showNavigation === true ? [{id: "footer_links", span: 1, backgroundColor: footerBackground, padding: 8, components: [footerComponent("footer_navigation", "navigation", {title: String(footer.linksTitle || "Enlaces")})]}] : []),
        ],
      }],
    },
    migratedAt: FieldValue.serverTimestamp(),
  };
}

async function run() {
  const configRef = db.collection("website").doc("config");
  const [configSnapshot, pagesSnapshot] = await Promise.all([
    configRef.get(), db.collection("website_pages").orderBy("sortOrder").get(),
  ]);
  if (!configSnapshot.exists) throw new Error("No existe website/config.");
  const old = configSnapshot.data();
  if (old.version === 5) {
    console.log(`El sitio ya usa v5: ${pagesSnapshot.size} páginas.`);
    return;
  }
  const pages = pagesSnapshot.docs.map((document) => ({
    reference: document.ref,
    value: {
      label: String(document.data().label || document.id),
      slug: String(document.data().slug || document.id),
      enabled: document.data().enabled !== false,
      showInNavigation: document.data().showInNavigation !== false,
      sortOrder: Number(document.data().sortOrder || 0),
      rows: (Array.isArray(document.data().blocks) ? document.data().blocks : [])
          .map(rowForBlock),
      migratedAt: FieldValue.serverTimestamp(),
    },
  }));
  console.log(`website/config: v${old.version || "sin versión"} -> v5`);
  for (const page of pages) {
    console.log(`${page.reference.path}: ${(page.value.rows || []).length} filas`);
  }
  if (!apply) {
    console.log("Simulación terminada. Usa --apply para escribir los cambios.");
    return;
  }
  const stamp = new Date().toISOString().replace(/[.:]/g, "-");
  const batch = db.batch();
  batch.set(db.collection("migration_backups").doc(`website_v4_${stamp}`), {
    source: "website/config", data: old, createdAt: FieldValue.serverTimestamp(),
  });
  for (const document of pagesSnapshot.docs) {
    batch.set(db.collection("migration_backups").doc(`website_v4_${stamp}`).collection("pages").doc(document.id), {
      source: document.ref.path, data: document.data(), createdAt: FieldValue.serverTimestamp(),
    });
  }
  batch.set(configRef, migrateConfig(old));
  for (const page of pages) batch.set(page.reference, page.value);
  batch.delete(db.collection("website").doc("main"));
  await batch.commit();
  console.log("Migración aplicada con respaldo y lote atómico.");
}

async function verifyMigration() {
  const [configSnapshot, pagesSnapshot] = await Promise.all([
    db.collection("website").doc("config").get(), db.collection("website_pages").get(),
  ]);
  const errors = [];
  const config = configSnapshot.data() || {};
  if (config.version !== 5) errors.push("website/config no usa version 5");
  if (!Array.isArray(config.header?.rows) || !Array.isArray(config.footer?.rows)) {
    errors.push("Header o Footer no tiene filas");
  }
  for (const document of pagesSnapshot.docs) {
    const data = document.data();
    if (!Array.isArray(data.rows) || Object.hasOwn(data, "blocks")) {
      errors.push(`${document.ref.path} no usa el esquema canónico`);
    }
  }
  if (errors.length) throw new Error(errors.join("\n"));
  console.log(`Verificación correcta: ${pagesSnapshot.size} páginas en esquema v5.`);
}

(verify ? verifyMigration() : run()).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
