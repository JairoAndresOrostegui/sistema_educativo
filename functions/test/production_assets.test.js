"use strict";
const assert = require("assert");
const {storagePath, walk} = require("../scripts/migrate_production_assets");
describe("Production asset scope", () => {
  const prefix = "https://firebasestorage.googleapis.com/v0/b/";
  it("accepts institutional website objects", () => {
    assert.equal(storagePath(`${prefix}sistema-educativo-rl.` +
      "firebasestorage.app/o/website%2Fimage.png?alt=media&token=old"),
    "website/image.png");
  });
  it("rejects operational files and unapproved profile photos", () => {
    const names = ["files%2Ftest.pdf", "fotos_perfil%2Ftest-user%2Fphoto.png"];
    for (const name of names) {
      assert.throws(() => storagePath(`${prefix}sistema-educativo-rl.` +
        `firebasestorage.app/o/${name}`));
    }
  });
  it("rejects another Firebase bucket", () => {
    assert.throws(() => storagePath(`${prefix}another/o/website%2Fimage.png`));
  });
  it("preserves social links and nested timestamps", () => {
    const date = new Date();
    const source = {date, rows: [{url: "https://instagram.com/school"}]};
    assert.deepEqual(walk(source, (v) => v), source);
    assert.equal(storagePath(source.rows[0].url), null);
  });
});
