"use strict";
/* eslint-disable max-len */
const assert = require("assert");
const {projectCore, encode, decode} = require("../scripts/production_projection");
function fixture() {
  const scope = {institutionId: "Rodolfo Llinas"};
  return {
    academic_years: ["Piedecuesta", "Barrancabermeja"].map((campusId, i) => ({id: `y${i}`, data: {...scope, campusId, year: 2026, status: "active"}})),
    academic_year_settings: ["Piedecuesta", "Barrancabermeja"].map((campusId, i) => ({id: `s${i}`, data: {...scope, campusId, activeYear: 2026, activeYearId: `y${i}`}})),
    academic_groups: ["Piedecuesta", "Barrancabermeja"].map((campusId, i) => ({id: `g${i}`, data: {...scope, campusId, academicYearId: `y${i}`, academicYear: 2026, active: true, name: "Cuarto A"}})),
    configuracion_colegios: [{id: "school", data: {...scope, nombre: "Colegio", sedes: ["Piedecuesta", "Barrancabermeja"], logoUrl: "qa-logo"}}],
    parameters: [],
    users: [{id: "real", data: {institution: scope.institutionId, campus: "Piedecuesta", role: "Estudiante", status: "activo", groupId: "g0", firstName: "Real", studentIds: [""], notificationTokens: {web: "secret-token"}, loginAttempts: 10, photoUrl: "qa-photo"}},
      {id: "test", data: {firstName: "Test"}}],
  };
}
describe("Production core projection", () => {
  it("copies only approved profiles and strips sessions, tokens and QA images", () => {
    const projected = projectCore(fixture(), ["real"]);
    const user = projected.find((d) => d.path === "users/real").data;
    assert.equal(projected.some((d) => d.path === "users/test"), false);
    assert.equal(user.notificationTokens, undefined);
    assert.equal(user.loginAttempts, undefined);
    assert.equal(user.photoUrl, "");
    assert.deepEqual(user.studentIds, []);
    assert.equal(user.groupName, "Cuarto A");
  });
  it("excludes draft academic years and their groups", () => {
    const data = fixture();
    data.academic_years.push({id: "future", data: {status: "draft", year: 2027}});
    data.academic_groups.push({id: "future-group", data: {academicYearId: "future", active: true}});
    assert.equal(projectCore(data, ["real"]).some((d) => d.path.includes("future")), false);
  });
  it("rejects cross-campus groups even when names match", () => {
    const data = fixture(); data.users[0].data.groupId = "g1";
    assert.throws(() => projectCore(data, ["real"]), /Invalid group/);
  });
  it("rejects QA-only linked children", () => {
    const data = fixture(); data.users[0].data.studentIds = ["test"];
    assert.throws(() => projectCore(data, ["real"]), /QA-only child/);
  });
  it("rejects a misconfigured active academic year", () => {
    const data = fixture(); data.academic_year_settings[0].data.campusId = "Barrancabermeja";
    assert.throws(() => projectCore(data, ["real"]), /tenant mismatch/);
  });
  it("roundtrips Firestore typed values without changing dates", () => {
    const data = {created: new Date("2026-09-07T00:00:00Z"), n: 2026, ok: false, list: [null, "value", 1.5]};
    assert.deepEqual(decode(encode(data)), data);
  });
});
