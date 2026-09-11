"use strict";

const assert = require("assert");
const {Readable} = require("stream");
const {boundedDownload, descriptor, revokePrivateDownloadTokens} =
  require("../protected_downloads");

describe("límites de descargas privadas", () => {
  it("tolera 25 MiB exactos y limita por contador incluso con metadata falsa",
      async () => {
        const limit = 25 * 1024 * 1024;
        const data = Buffer.alloc(limit, 7);
        assert.equal((await boundedDownload({createReadStream: () =>
          Readable.from([data])}, limit)).length, limit);
        await assert.rejects(() => boundedDownload({createReadStream: () =>
          Readable.from([data, Buffer.from([1])])}, limit),
        {code: "failed-precondition"});
        await assert.rejects(() => boundedDownload({createReadStream: () =>
          Readable.from([Buffer.from([1, 2])])}, 1),
        {code: "failed-precondition"});
      });
  it("rechaza lectura incompleta, rutas y contenido activo", async () => {
    await assert.rejects(() => boundedDownload({createReadStream: () =>
      Readable.from([Buffer.from([1])])}, 2), {code: "failed-precondition"});
    const value = {name: "guia.pdf", contentType: "application/pdf",
      sizeBytes: 12, storagePath: "files/id/guia.pdf"};
    assert.equal(descriptor(value, "id", false).path, value.storagePath);
    for (const extra of [{storagePath: "files/other/guia.pdf"},
      {contentType: "text/html"}, {sizeBytes: 26 * 1024 * 1024},
      {name: "x\r\nSet-Cookie.pdf"}]) {
      assert.throws(() => descriptor({...value, ...extra}, "id", false),
          {code: "failed-precondition"});
    }
  });

  it("revoca con precondiciones y el fallo es reintentable", async () => {
    const metadata = {generation: "10", metageneration: "4", size: "5",
      contentType: "application/pdf", metadata: {other: "conservar",
        firebaseStorageDownloadTokens: "token"}};
    await revokePrivateDownloadTokens({setMetadata: async (patch, options) => {
      assert.deepEqual(patch.metadata, {other: "conservar",
        firebaseStorageDownloadTokens: null});
      assert.deepEqual(options, {ifGenerationMatch: "10",
        ifMetagenerationMatch: "4"});
      return [{...metadata, metadata: {other: "conservar"}}];
    }}, metadata);
    await assert.rejects(() => revokePrivateDownloadTokens({
      setMetadata: async () => {
        throw Object.assign(new Error("precondition failed"), {code: 412});
      },
    }, metadata), {code: "unavailable"});
  });
});
