"use strict";
/* eslint-disable max-len */
const crypto = require("crypto");
const path = require("path");
const {cloudAccess} = require("./cloud_access");
const {SOURCE, TARGET, REAL_USERS} = require("./production_readiness");
const {decode, encode} = require("./production_projection");
const SOURCE_BUCKET = `${SOURCE}.firebasestorage.app`;
const TARGET_BUCKET = `${TARGET}.firebasestorage.app`;
const MIGRATION = "production_assets_v1";
const db = (project) => `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
const objectUrl = (bucket, name) => `https://storage.googleapis.com/storage/v1/b/${bucket}/o/${encodeURIComponent(name)}`;
const hash = (value) => crypto.createHash("sha256").update(value).digest("hex");
function storagePath(url) {
  if (typeof url !== "string" || !url.startsWith("https://firebasestorage.googleapis.com/")) return null;
  const parsed = new URL(url);
  const match = parsed.pathname.match(/^\/v0\/b\/([^/]+)\/o\/(.+)$/);
  if (!match || match[1] !== SOURCE_BUCKET) throw new Error("Unexpected source Storage bucket");
  const name = decodeURIComponent(match[2]);
  if (!name.startsWith("website/") && name !== "logo/Logo.svg" &&
      !REAL_USERS.some((id) => name.startsWith(`fotos_perfil/${id}/`))) throw new Error("Asset outside approved scope");
  return name;
}
function walk(value, transform) {
  if (typeof value === "string") return transform(value);
  if (value instanceof Date || value === null) return value;
  if (Array.isArray(value)) return value.map((v) => walk(v, transform));
  if (typeof value === "object") return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, walk(v, transform)]));
  return value;
}
async function main() {
  const request = await cloudAccess();
  const apply = process.argv.includes("--apply");
  const getDoc = async (project, name) => {
    try {
      const raw = await request(`${db(project)}/${name}`);
      return {raw, data: decode({mapValue: {fields: raw.fields}})};
    } catch (e) {
      if (e.status === 404) return null;
      throw e;
    }
  };
  const write = (name, data, currentDocument, updateMask) => ({
    update: {name: `${db(TARGET).replace("https://firestore.googleapis.com/v1/", "")}/${name}`, fields: encode(data).mapValue.fields},
    currentDocument, ...(updateMask ? {updateMask: {fieldPaths: updateMask}} : {}),
  });
  const commit = (writes) => request(`${db(TARGET)}:commit`, "POST", {writes});
  const journalPath = `migration_audit/${MIGRATION}`;
  let journal = await getDoc(TARGET, journalPath);
  if (journal?.data.phase === "complete") {
    for (const asset of journal.data.assets) {
      const object = await request(objectUrl(TARGET_BUCKET, asset.destination));
      if (object.crc32c !== asset.crc32c || object.size !== asset.size) throw new Error("Migrated asset changed or missing");
    }
    console.log(JSON.stringify({phase: "complete", verifiedObjects: journal.data.assets.length, noWrites: true}));
    return;
  }
  const candidates = [];
  const config = await getDoc(SOURCE, "website/config");
  if (config?.data.version !== 5) throw new Error("Expected website schema v5");
  const website = {...config.data, pendingAssetCleanup: []};
  delete website.cleanupUpdatedAt;
  candidates.push({name: "website/config", data: website});
  const pages = await request(`${db(SOURCE)}/website_pages?pageSize=100`);
  if (pages.nextPageToken) throw new Error("Unexpected page count");
  for (const raw of pages.documents || []) candidates.push({name: `website_pages/${raw.name.split("/").pop()}`, data: decode({mapValue: {fields: raw.fields}})});
  const schoolName = "configuracion_colegios/desarrolloytecnologiasantander.com";
  const school = await getDoc(SOURCE, schoolName);
  candidates.push({name: schoolName, data: {logoUrl: school.data.logoUrl}, mask: ["logoUrl"]});
  for (const uid of REAL_USERS) {
    const user = await getDoc(SOURCE, `users/${uid}`);
    if (user.data.photoUrl) {
      candidates.push({name: `users/${uid}`, data: {photoUrl: user.data.photoUrl}, mask: ["photoUrl"]});
      candidates.push({name: `user_directory/${uid}`, data: {photoUrl: user.data.photoUrl}, mask: ["photoUrl"]});
    }
  }
  const names = new Set();
  for (const d of candidates) {
    walk(d.data, (value) => {
      const name = storagePath(value);
      if (name) names.add(name);
      return value;
    });
  }
  const assets = [];
  const missingProfileImages = [];
  for (const name of names) {
    let meta;
    try {
      meta = await request(objectUrl(SOURCE_BUCKET, name));
    } catch (e) {
      if (e.status === 404 && name.startsWith("fotos_perfil/")) {
        missingProfileImages.push(name);
        continue;
      }
      throw new Error(`Source image unavailable: ${name} (${e.status})`, {cause: e});
    }
    if (!meta.contentType?.startsWith("image/") || Number(meta.size) > 10 * 1024 * 1024) throw new Error("Unexpected image type/size");
    const destination = name.startsWith("website/") ? `website/institucional_${hash(`${name}:${meta.generation}`).slice(0, 24)}${path.posix.extname(name)}` : name;
    assets.push({source: name, destination, generation: meta.generation, size: meta.size, crc32c: meta.crc32c, contentType: meta.contentType});
  }
  for (let i = candidates.length - 1; i >= 0; i--) {
    if (candidates[i].mask?.[0] === "photoUrl" && missingProfileImages.includes(storagePath(candidates[i].data.photoUrl))) candidates.splice(i, 1);
  }
  const bytes = assets.reduce((n, a) => n + Number(a.size), 0);
  if (bytes > 50 * 1024 * 1024) throw new Error("Review asset total size");
  const planHash = hash(JSON.stringify({candidates, assets, missingProfileImages}));
  if (journal && journal.data.planHash !== planHash) throw new Error("Source assets/site changed; review previous migration");
  console.log(JSON.stringify({apply, objects: assets.length, bytes, documents: candidates.length, missingProfileImages, phase: journal?.data.phase || "not started"}));
  if (!apply) return;
  const targets = [];
  for (const candidate of candidates) {
    const target = await getDoc(TARGET, candidate.name);
    if (candidate.mask) {
      if (!target || target.data[candidate.mask[0]]) throw new Error(`Target already has image or is missing: ${candidate.name}`);
    } else if (target) throw new Error(`Website target already exists: ${candidate.name}`);
    targets.push(target);
  }
  if (!journal) {
    await commit([write(journalPath, {phase: "copying", planHash, assets, missingProfileImages, bytes, createdAt: new Date()}, {exists: false})]);
    journal = await getDoc(TARGET, journalPath);
  }
  const urls = new Map();
  for (const asset of assets) {
    let target;
    try {
      target = await request(objectUrl(TARGET_BUCKET, asset.destination));
    } catch (e) {
      if (e.status !== 404) throw e;
    }
    if (!target) {
      let response;
      let rewriteToken = "";
      const token = crypto.randomUUID();
      do {
        const url = `${objectUrl(SOURCE_BUCKET, asset.source)}/rewriteTo/b/${TARGET_BUCKET}/o/${encodeURIComponent(asset.destination)}?ifSourceGenerationMatch=${asset.generation}&ifGenerationMatch=0${rewriteToken ? `&rewriteToken=${encodeURIComponent(rewriteToken)}` : ""}`;
        response = await request(url, "POST", {contentType: asset.contentType,
          metadata: {firebaseStorageDownloadTokens: token, migration: MIGRATION, sourceGeneration: asset.generation}});
        rewriteToken = response.rewriteToken || "";
        if (!response.done && !rewriteToken) throw new Error("Missing copy continuation");
      } while (!response.done);
      target = await request(objectUrl(TARGET_BUCKET, asset.destination));
    }
    if (target.metadata?.migration !== MIGRATION || target.metadata.sourceGeneration !== asset.generation ||
        target.crc32c !== asset.crc32c || target.size !== asset.size || !target.metadata.firebaseStorageDownloadTokens) throw new Error("Destination object integrity mismatch");
    urls.set(asset.source, `https://firebasestorage.googleapis.com/v0/b/${TARGET_BUCKET}/o/${encodeURIComponent(asset.destination)}?alt=media&token=${target.metadata.firebaseStorageDownloadTokens}`);
  }
  const mapped = candidates.map((candidate) => walk(candidate.data, (value) => {
    const name = storagePath(value);
    if (name) return urls.get(name);
    const asset = assets.find((a) => a.source === value);
    return asset ? asset.destination : value;
  }));
  if (JSON.stringify(mapped).includes(SOURCE_BUCKET) || JSON.stringify(mapped).includes(`${SOURCE}.appspot.com`)) throw new Error("QA references remain");
  const writes = candidates.map((candidate, i) => write(candidate.name, mapped[i], targets[i] ? {updateTime: targets[i].raw.updateTime} : {exists: false}, candidate.mask));
  writes.push(write(journalPath, {...journal.data, phase: "complete", completedAt: new Date()}, {updateTime: journal.raw.updateTime}));
  await commit(writes);
  console.log(JSON.stringify({phase: "complete", objects: assets.length, bytes, documents: writes.length - 1, deletedSourceObjects: 0}));
}
if (require.main === module) {
  main().catch((e) => {
    console.error(e.message); process.exitCode = 1;
  });
}
module.exports = {storagePath, walk};
