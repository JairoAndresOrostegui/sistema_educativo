"use strict";
const {HttpsError} = require("firebase-functions/v2/https");

// Projection for the public form: no profiles or enrollment records.
async function publicEnrollmentOptions(db, activeYear) {
  const website = await db.doc("website/config").get();
  const institutionId = website.data()?.institutionId;
  if (typeof institutionId !== "string" || !institutionId.trim()) {
    throw new HttpsError("failed-precondition",
        "El colegio todavía no ha habilitado la matrícula pública.");
  }
  const institutions = await db.collection("configuracion_colegios")
      .where("institutionId", "==", institutionId).limit(2).get();
  if (institutions.size !== 1) {
    throw new HttpsError("failed-precondition",
        "La configuración de la institución requiere revisión.");
  }
  const institution = institutions.docs[0].data();
  const campuses = [...new Set((institution.sedes || []).map((item) =>
    typeof item === "string" ? item : item?.id || item?.nombre)
      .filter((item) => typeof item === "string" && item.trim()))];
  if (!campuses.length || campuses.length > 30) {
    throw new HttpsError("failed-precondition",
        "El colegio debe revisar las sedes habilitadas para matrícula.");
  }
  const groups = [];
  const availableCampuses = [];
  for (const campusId of campuses) {
    let year;
    try {
      year = await activeYear(institutionId, campusId);
    } catch (error) {
      if (error.code === "failed-precondition") continue;
      throw error;
    }
    const snapshot = await db.collection("academic_groups")
        .where("institutionId", "==", institutionId)
        .where("campusId", "==", campusId)
        .where("academicYearId", "==", year.id)
        .where("active", "==", true).limit(501).get();
    if (snapshot.size > 500) {
      throw new HttpsError("resource-exhausted",
          "El colegio debe revisar la cantidad de grupos de matrícula.");
    }
    availableCampuses.push(campusId);
    for (const document of snapshot.docs) {
      const value = document.data();
      groups.push({id: document.id, institutionId, campusId,
        academicYearId: year.id, academicYear: year.year,
        level: value.level || "", section: value.section || "",
        name: value.name || "", order: Number(value.order) || 0,
        active: true});
    }
  }
  if (!availableCampuses.length) {
    throw new HttpsError("failed-precondition",
        "El colegio todavía no tiene un año lectivo habilitado.");
  }
  const catalog = async (key) => {
    const snapshot = await db.collection("parameters")
        .where("clave", "==", key).where("activo", "==", true).get();
    return snapshot.docs.map((document) => {
      const value = document.data();
      return {valor: String(value.valor || ""),
        etiqueta: String(value.etiqueta || value.valor || ""),
        orden: Number(value.orden) || 0};
    }).filter((item) => item.valor).sort((a, b) => a.orden - b.orden);
  };
  const [documentTypes, eps] = await Promise.all([
    catalog("documentType"), catalog("eps"),
  ]);
  return {groups: groups.sort((a, b) => a.order - b.order),
    institutions: [{id: institutionId,
      label: String(institution.nombre || institutionId),
      campuses: availableCampuses}], documentTypes, eps};
}
module.exports = {publicEnrollmentOptions};
