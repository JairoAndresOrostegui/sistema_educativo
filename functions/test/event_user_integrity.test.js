"use strict";
const assert = require("node:assert/strict");
const {eventUserReferences, requireNoEventReferences,
  RELATIONS} = require("../event_user_integrity");

function fakeDb(documents) {
  return {collection: (name) => ({where: (field, operator, uid) => ({
    limit: (maximum) => ({get: async () => {
      const docs = documents.filter((item) => item.collection === name &&
        (operator === "array-contains" ? item[field]?.includes(uid) :
          item[field] === uid)).slice(0, maximum)
          .map((item) => ({ref: {path: `${name}/${item.id}`}}));
      return {docs, size: docs.length};
    }}),
  })})};
}

describe("Integridad de identidades usadas en Eventos", () => {
  it("no bloquea usuarios sin relaciones de eventos", async () => {
    const result = await eventUserReferences(fakeDb([]), "user");
    assert.equal(result.count, 0);
    requireNoEventReferences(result);
  });
  it("cuenta una sola vez un documento con dos relaciones", async () => {
    const db = fakeDb([{collection: "school_events", id: "e1", createdBy: "u",
      responsibleUserIds: ["u"]}]);
    const result = await eventUserReferences(db, "u");
    assert.equal(result.count, 1);
    assert.throws(() => requireNoEventReferences(result),
        (error) => error.code === "failed-precondition");
  });
  for (const [collection, field, operator] of RELATIONS) {
    it(`impide huérfanos por ${collection}.${field}`, async () => {
      const db = fakeDb([{collection, id: "related", [field]:
        operator === "array-contains" ? ["target"] : "target"},
      {collection, id: "unrelated", [field]: "other"}]);
      assert.equal((await eventUserReferences(db, "target")).count, 1);
    });
  }
  it("acota el conteo sin impedir la baja lógica", async () => {
    const db = fakeDb(Array.from({length: 2001}, (_, index) => ({
      collection: "event_food_orders", id: String(index), familyId: "u",
    })));
    const result = await eventUserReferences(db, "u");
    assert.equal(result.count, 2001);
    assert.equal(result.truncated, true);
    assert.throws(() => requireNoEventReferences(result),
        (error) => error.code === "failed-precondition");
  });
});
