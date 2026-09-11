"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const {versionWebAssets} = require("./version_web_assets");
test("production HTML and bootstrap use content-versioned JavaScript", () => {
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), "llinas-assets-test-"));
  fs.writeFileSync(path.join(folder, "main.dart.js"), "new application");
  fs.writeFileSync(path.join(folder, "flutter_bootstrap.js"),
      '{"mainJsPath":"main.dart.js"}');
  fs.writeFileSync(path.join(folder, "index.html"),
      '<script src="flutter_bootstrap.js"></script>');
  const result = versionWebAssets(folder);
  assert.match(result.main, /^main\.dart\.[a-f0-9]{20}\.js$/);
  assert.ok(fs.readFileSync(path.join(folder, "index.html"), "utf8")
      .includes(result.bootstrap));
  assert.ok(fs.readFileSync(path.join(folder, result.bootstrap), "utf8")
      .includes(result.main));
  assert.equal(fs.readFileSync(path.join(folder, result.main), "utf8"),
      "new application");
  assert.throws(() => versionWebAssets(folder), /Unexpected Flutter bootstrap/);
});
