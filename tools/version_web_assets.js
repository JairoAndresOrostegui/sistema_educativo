"use strict";
const fs = require("node:fs");
const path = require("node:path");
const {createHash} = require("node:crypto");
function versionWebAssets(folder) {
  const versionFile = (name) => {
    const data = fs.readFileSync(path.join(folder, name));
    const hash = createHash("sha256").update(data).digest("hex").slice(0, 20);
    const versioned = name.replace(/\.js$/, `.${hash}.js`);
    fs.writeFileSync(path.join(folder, versioned), data);
    return versioned;
  };
  const main = versionFile("main.dart.js");
  const bootstrapPath = path.join(folder, "flutter_bootstrap.js");
  const original = fs.readFileSync(bootstrapPath, "utf8");
  if (!original.includes('"mainJsPath":"main.dart.js"')) {
    throw new Error("Unexpected Flutter bootstrap; refusing unversioned deployment");
  }
  fs.writeFileSync(bootstrapPath, original.replaceAll(
      '"mainJsPath":"main.dart.js"', `"mainJsPath":"${main}"`));
  const bootstrap = versionFile("flutter_bootstrap.js");
  const indexPath = path.join(folder, "index.html");
  const index = fs.readFileSync(indexPath, "utf8");
  if (!index.includes('src="flutter_bootstrap.js"')) {
    throw new Error("Unexpected index bootstrap reference");
  }
  fs.writeFileSync(indexPath, index.replace('src="flutter_bootstrap.js"',
      `src="${bootstrap}"`));
  return {main, bootstrap};
}
module.exports = {versionWebAssets};
