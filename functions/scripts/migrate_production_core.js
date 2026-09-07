"use strict";
/* eslint-disable max-len */
const crypto = require("crypto");
const {cloudAccess} = require("./cloud_access");
const {SOURCE, TARGET, REAL_USERS} = require("./production_readiness");
const {decode, encode, projectCore} = require("./production_projection");
const MIGRATION = "production_core_v1";
const base = (project) => `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
const canonical = (value) => JSON.stringify(value, (key, item) => {
  return item && !Array.isArray(item) && typeof item === "object" ?
    Object.fromEntries(Object.keys(item).sort().map((k) => [k, item[k]])) : item;
});
async function main() {
  if (SOURCE !== "sistema-educativo-rl" || TARGET !== "sistema-educativo-rl-prod") throw new Error("Unexpected projects");
  const apply = process.argv.includes("--apply");
  const request = await cloudAccess();
  const list = async (project, collection) => {
    let page = "";
    const docs = [];
    do {
      const result = await request(`${base(project)}/${collection}?pageSize=100&pageToken=${encodeURIComponent(page)}`);
      docs.push(...(result.documents || []).map((d) => ({id: d.name.split("/").pop(), data: decode({mapValue: {fields: d.fields}}), raw: d})));
      page = result.nextPageToken || "";
    } while (page);
    return docs;
  };
  const get = async (path) => {
    try {
      const raw = await request(`${base(TARGET)}/${path}`);
      return {raw, data: decode({mapValue: {fields: raw.fields}})};
    } catch (e) {
      if (e.status === 404) return null;
      throw e;
    }
  };
  const commit = (writes) => request(`${base(TARGET)}:commit`, "POST", {writes});
  const write = (path, data, currentDocument) => ({update: {name: `${base(TARGET).replace("https://firestore.googleapis.com/v1/", "")}/${path}`,
    fields: encode(data).mapValue.fields}, ...(currentDocument ? {currentDocument} : {})});
  const authUsers = async (project) => {
    const data = await request(`https://identitytoolkit.googleapis.com/v1/projects/${project}/accounts:batchGet?maxResults=1000`);
    if (data.nextPageToken) throw new Error("Auth pagination requires review before migration");
    return data.users || [];
  };
  const journalPath = `migration_audit/${MIGRATION}`;
  let journal = await get(journalPath);
  if (journal?.data.phase === "complete") {
    const profiles = await list(TARGET, "users");
    const accounts = await authUsers(TARGET);
    for (const uid of REAL_USERS) {
      if (!profiles.some((d) => d.id === uid && d.data.status === "activo") || !accounts.some((u) => u.localId === uid && !u.disabled)) throw new Error(`Completed migration account mismatch ${uid}`);
    }
    console.log(JSON.stringify({phase: "complete", verifiedUsers: REAL_USERS.length, noWrites: true}));
    return;
  }
  const source = {};
  for (const c of ["users", "academic_groups", "academic_years", "academic_year_settings", "configuracion_colegios", "parameters"]) source[c] = await list(SOURCE, c);
  const projected = projectCore(source);
  const sourceAuth = await authUsers(SOURCE);
  const normalizedAuthEmails = [];
  const accounts = REAL_USERS.map((uid) => {
    const account = sourceAuth.find((u) => u.localId === uid);
    const profile = projected.find((d) => d.path === `users/${uid}`).data;
    if (account?.email && profile.role === "Estudiante" &&
        account.email.toLowerCase() !== profile.institutionalEmail.toLowerCase()) {
      profile.institutionalEmail = account.email.toLowerCase();
      normalizedAuthEmails.push(uid);
    }
    if (!account || account.disabled || !account.passwordHash || !account.salt ||
        account.email?.toLowerCase() !== profile.institutionalEmail.toLowerCase()) throw new Error(`Auth/profile mismatch ${uid}: ${JSON.stringify({exists: Boolean(account), disabled: account?.disabled === true, hash: Boolean(account?.passwordHash), salt: Boolean(account?.salt), institutionalMatches: account?.email?.toLowerCase() === profile.institutionalEmail.toLowerCase(), personalMatches: account?.email?.toLowerCase() === profile.personalEmail.toLowerCase()})}`);
    if ((account.providerUserInfo || []).some((p) => p.providerId !== "password")) throw new Error(`Review federated login ${uid}`);
    return {localId: uid, email: account.email, emailVerified: account.emailVerified === true,
      displayName: account.displayName || `${profile.firstName} ${profile.lastName}`,
      passwordHash: account.passwordHash, salt: account.salt, disabled: true};
  });
  const config = await request(`https://identitytoolkit.googleapis.com/admin/v2/projects/${SOURCE}/config`);
  if (new Set(accounts.map((a) => a.email.toLowerCase())).size !== accounts.length) throw new Error("Duplicate approved Auth email");
  const documents = projected.filter((d) => d.path.startsWith("users/")).map((d) => d.data.document);
  if (documents.some((d) => typeof d !== "string" || !d.trim()) || new Set(documents).size !== accounts.length) throw new Error("Missing or duplicate approved identity document");
  const hash = config.signIn?.hashConfig;
  if (hash?.algorithm !== "SCRYPT" || !hash.signerKey || !hash.rounds || !hash.memoryCost) throw new Error("Missing compatible password hash configuration");
  const targetConfig = await request(`https://identitytoolkit.googleapis.com/admin/v2/projects/${TARGET}/config`);
  if (!targetConfig.signIn?.email?.enabled || !targetConfig.signIn.email.passwordRequired) throw new Error("Enable production email/password first");
  const planHash = crypto.createHash("sha256").update(canonical({projected, accounts})).digest("hex");
  if (journal && journal.data.planHash !== planHash) throw new Error("Source changed since preparation. Review instead of overwriting production");
  const targetAccounts = await authUsers(TARGET);
  if (targetAccounts.some((u) => !REAL_USERS.includes(u.localId))) throw new Error("Unexpected production Auth account");
  if (!journal) {
    if (targetAccounts.length) throw new Error("Production Auth must be empty before initial migration");
    for (const c of [...new Set(projected.map((d) => d.path.split("/")[0]))]) {
      if ((await list(TARGET, c)).length) throw new Error(`Production ${c} is not empty`);
    }
  }
  const summary = {source: SOURCE, target: TARGET, apply, users: accounts.length,
    documents: projected.length, collections: Object.fromEntries([...new Set(projected.map((d) => d.path.split("/")[0]))].map((c) => [c, projected.filter((d) => d.path.startsWith(`${c}/`)).length])),
    deferredImageProfiles: source.users.filter((d) => REAL_USERS.includes(d.id) && d.data.photoUrl).length,
    normalizedAuthEmails, phase: journal?.data.phase || "not started"};
  console.log(JSON.stringify(summary));
  if (!apply) return;
  const owner = crypto.randomUUID();
  if (journal?.data.leaseUntil > new Date()) throw new Error("Migration already leased; wait for lease expiry before resuming");
  const journalData = {phase: "prepared", source: SOURCE, target: TARGET,
    planHash, approvedUids: REAL_USERS, owner, leaseUntil: new Date(Date.now() + 10 * 60 * 1000),
    preparedAt: journal?.data.preparedAt || new Date(), summary};
  const seed = projected.map((d) => ({...d, data: d.path.startsWith("users/") || d.path.startsWith("user_directory/") ? {...d.data, status: "inactivo"} : d.data}));
  if (!journal) {
    await commit([...seed.map((d) => write(d.path, d.data, {exists: false})), write(journalPath, journalData, {exists: false})]);
  } else {
    for (const d of seed) {
      const existing = await get(d.path);
      if (!existing || canonical(existing.data) !== canonical(d.data)) throw new Error(`Prepared data changed ${d.path}`);
    }
    await commit([write(journalPath, journalData, {updateTime: journal.raw.updateTime})]);
  }
  journal = await get(journalPath);
  const missing = accounts.filter((u) => !targetAccounts.some((t) => t.localId === u.localId));
  if (missing.length) {
    const imported = await request(`https://identitytoolkit.googleapis.com/v1/projects/${TARGET}/accounts:batchCreate`, "POST", {
      hashAlgorithm: "SCRYPT", signerKey: hash.signerKey, saltSeparator: hash.saltSeparator || "",
      rounds: hash.rounds, memoryCost: hash.memoryCost, users: missing, allowOverwrite: false,
    });
    if (imported.error?.length) throw new Error(`Auth import failed for ${imported.error.length} accounts; prepared profiles remain inactive`);
  }
  let importedAccounts = await authUsers(TARGET);
  for (const expected of accounts) {
    const actual = importedAccounts.find((u) => u.localId === expected.localId);
    if (!actual || actual.email !== expected.email || actual.emailVerified !== expected.emailVerified) throw new Error(`Imported account mismatch ${expected.localId}`);
  }
  for (const expected of accounts) {
    if (importedAccounts.find((u) => u.localId === expected.localId).disabled) {
      await request(`https://identitytoolkit.googleapis.com/v1/projects/${TARGET}/accounts:update`, "POST", {localId: expected.localId, disableUser: false});
    }
  }
  importedAccounts = await authUsers(TARGET);
  if (importedAccounts.length !== accounts.length || importedAccounts.some((u) => u.disabled)) throw new Error("Account activation verification failed");
  // No access is granted until every Auth account exists and this atomic commit succeeds.
  const activate = [];
  for (const d of projected.filter((d) => d.path.startsWith("users/") || d.path.startsWith("user_directory/"))) {
    const existing = await get(d.path);
    if (!existing || canonical(existing.data) !== canonical({...d.data, status: "inactivo"})) throw new Error(`Unexpected profile state ${d.path}`);
    activate.push(write(d.path, d.data, {updateTime: existing.raw.updateTime}));
  }
  activate.push(write(journalPath, {...journalData, phase: "complete", completedAt: new Date(), leaseUntil: new Date(0)}, {updateTime: journal.raw.updateTime}));
  await commit(activate);
  console.log(JSON.stringify({phase: "complete", users: accounts.length, copiedOperationalData: false,
    passwordLoginPhysicallyTested: false}));
}
if (require.main === module) {
  main().catch((e) => {
    console.error(e.message); process.exitCode = 1;
  });
}
