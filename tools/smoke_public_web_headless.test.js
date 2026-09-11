"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {safeUrl, safeText} = require("./smoke_public_web_headless");

test("browser reports omit credentials and query tokens", () => {
  const input = "https://user:password@example.com/object?alt=media&token=secret";
  assert.equal(safeUrl(input), "https://example.com/object?[redacted]");
  const message = safeText(`Failed ${input} network request`);
  assert.ok(!message.includes("secret"));
  assert.ok(!message.includes("password"));
});
