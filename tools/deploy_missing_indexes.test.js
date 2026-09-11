"use strict";
const assert = require("node:assert/strict");
const {test} = require("node:test");
const {deployMissingIndexes} = require("./deploy_missing_indexes");
const expected = [{collectionGroup: "events", queryScope: "COLLECTION", fields: [
  {fieldPath: "institutionId", order: "ASCENDING"},
  {fieldPath: "campusId", order: "ASCENDING"},
]}];
const projectId = "sistema-educativo-rl";
const live = {...expected[0], state: "READY"};

test("dry run never writes and rejects unknown projects", async () => {
  const request = async (url, method = "GET") => {
    assert.equal(method, "GET");
    return {indexes: []};
  };
  const result = await deployMissingIndexes({projectId, expected, request});
  assert.equal(result.remainingMissing.length, 1);
  assert.equal(result.operations.length, 0);
  await assert.rejects(deployMissingIndexes({projectId: "other", expected,
    request}), /allowlisted/);
});

test("creates only missing indexes and skips existing indexes", async () => {
  let posted = false;
  const calls = [];
  const request = async (url, method = "GET", body) => {
    calls.push({url, method});
    if (method === "GET") return {indexes: posted ? [live] : []};
    assert.equal(method, "POST");
    assert.ok(url.endsWith("/collectionGroups/events/indexes"));
    assert.deepEqual(body, {queryScope: live.queryScope, fields: live.fields});
    posted = true;
    return {name: "operations/create-1", done: true};
  };
  const result = await deployMissingIndexes({projectId, expected,
    apply: true, request});
  assert.equal(result.readyCount, 1);
  assert.equal(result.operations.length, 1);
  const rerun = await deployMissingIndexes({projectId, expected,
    apply: true, request});
  assert.equal(rerun.operations.length, 0);
  assert.equal(calls.filter((call) => call.method === "POST").length, 1);
});

test("reports creation pending without treating it as ready", async () => {
  const result = await deployMissingIndexes({projectId, expected,
    request: async () => ({indexes: [{...live, state: "CREATING"}]})});
  assert.equal(result.readyCount, 0);
  assert.equal(result.pending[0].state, "CREATING");
});
