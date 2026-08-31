"use strict";

const crypto = require("crypto");

const academicYearId = (institution, campus, year = 2026) =>
  crypto.createHash("sha256")
      .update(`${institution}\u0000${campus}\u0000${year}`).digest("hex");

const settingsId = (institution, campus) => crypto.createHash("sha256")
    .update(`${institution}\u0000${campus}`).digest("hex");

async function seedAcademicYear(db, institution, campus, year = 2026) {
  const id = academicYearId(institution, campus, year);
  await db.collection("academic_years").doc(id).set({
    institutionId: institution,
    campusId: campus,
    year,
    status: "active",
  });
  await db.collection("academic_year_settings")
      .doc(settingsId(institution, campus)).set({
        institutionId: institution,
        campusId: campus,
        activeYearId: id,
        activeYear: year,
      });
  return id;
}

module.exports = {academicYearId, seedAcademicYear};
