"use strict";
/* eslint-disable max-len */
const {cloudAccess} = require("./cloud_access");
const {SOURCE, TARGET} = require("./production_readiness");
async function main() {
  const request = await cloudAccess();
  const list = async (project) => {
    const data = await request(`https://cloudfunctions.googleapis.com/v2/projects/${project}/locations/us-central1/functions?pageSize=1000`);
    if (data.nextPageToken) throw new Error("Unexpected function page count");
    return (data.functions || []).map((f) => ({name: f.name.split("/").pop(), state: f.state}));
  };
  const source = await list(SOURCE);
  const target = await list(TARGET);
  const pending = source.filter((s) => !target.some((t) => t.name === s.name && t.state === "ACTIVE"));
  const iam = await request(`https://cloudresourcemanager.googleapis.com/v1/projects/${TARGET}:getIamPolicy`, "POST", {});
  const agent = "serviceAccount:service-325430927285@gcp-sa-eventarc.iam.gserviceaccount.com";
  console.log(JSON.stringify({sourceCount: source.length, targetCount: target.length,
    active: target.filter((f) => f.state === "ACTIVE").length,
    pending: pending.map((f) => f.name), states: target.filter((f) => f.state !== "ACTIVE"),
    eventarcAgentRolePresent: (iam.bindings || []).some((b) => b.role === "roles/eventarc.serviceAgent" && b.members?.includes(agent))}));
}
main().catch((e) => {
  console.error(e.message); process.exitCode = 1;
});
