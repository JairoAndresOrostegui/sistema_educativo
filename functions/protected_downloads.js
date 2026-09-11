"use strict";

const {onRequest, HttpsError} = require("firebase-functions/v2/https");

const MAX_BYTES = 25 * 1024 * 1024;
const MIME_TYPES = new Set([
  "application/pdf", "application/msword", "application/vnd.ms-excel",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
]);
const ORIGINS = {
  "https://sistema-educativo-rl.web.app": [
    "https://sistema-educativo-rl.web.app",
    "https://sistema-educativo-rl.firebaseapp.com",
  ],
  "https://liceobilinguerodolfollinas.edu.co": [
    "https://liceobilinguerodolfollinas.edu.co",
    "https://www.liceobilinguerodolfollinas.edu.co",
    "https://sistema-educativo-rl-prod.web.app",
  ],
  "http://localhost:5000": ["http://localhost:5000"],
};

function documentId(value) {
  if (typeof value !== "string" || !value || value.length > 160 ||
      /[/\\]/.test(value) || [...value].some((c) => c.charCodeAt(0) < 32) ||
      [".", ".."].includes(value)) {
    throw new HttpsError("invalid-argument", "Identificador no válido.");
  }
  return value;
}

function descriptor(value, id, attachment) {
  const name = value.name;
  if (typeof name !== "string" || !name || name.length > 180 ||
      /[/\\]/.test(name) ||
      [...name].some((c) => c.charCodeAt(0) < 32 || c.charCodeAt(0) === 127) ||
      !/\.(pdf|doc|docx|xls|xlsx)$/i.test(name)) {
    throw new HttpsError("failed-precondition", "Archivo no disponible.");
  }
  const expectedPath = attachment ?
    `message_attachments/${documentId(value.channelId)}/${id}/${name}` :
    `files/${id}/${name}`;
  if (value.storagePath !== expectedPath ||
      !MIME_TYPES.has(value.contentType) ||
      !Number.isInteger(value.sizeBytes) || value.sizeBytes <= 0 ||
      value.sizeBytes > MAX_BYTES) {
    throw new HttpsError("failed-precondition", "Archivo no disponible.");
  }
  return {path: expectedPath, name, contentType: value.contentType,
    sizeBytes: value.sizeBytes};
}

// La respuesta HTTP es única (no streaming): Gen2 admite 32 MiB para este
// modo, pero solo 10 MiB para respuestas streaming. La lectura interna está
// limitada antes de concatenar; jamás se carga un objeto arbitrario completo.
async function boundedDownload(file, expectedSize) {
  const chunks = [];
  let size = 0;
  const stream = file.createReadStream({start: 0, end: MAX_BYTES});
  try {
    for await (const chunk of stream) {
      size += chunk.length;
      if (size > MAX_BYTES || size > expectedSize) {
        throw new HttpsError("failed-precondition", "Archivo no disponible.");
      }
      chunks.push(chunk);
    }
  } finally {
    stream.destroy();
  }
  if (size !== expectedSize) {
    throw new HttpsError("failed-precondition", "Archivo no disponible.");
  }
  return Buffer.concat(chunks, size);
}

function sendError(response, error) {
  const errors = {
    "unauthenticated": [401, "Inicia sesión nuevamente para descargar."],
    "permission-denied": [403, "No tienes acceso a este archivo."],
    "invalid-argument": [400, "Solicitud de descarga no válida."],
    "failed-precondition": [409, "El archivo o el acceso ya no está vigente."],
    "not-found": [404, "El archivo ya no está disponible."],
    "resource-exhausted": [429, "Intenta nuevamente más tarde."],
  };
  const code = error instanceof HttpsError ? error.code :
    Number(error?.code) === 404 ? "not-found" : "internal";
  const [status, message] = errors[code] ||
    [500, "No se pudo descargar el archivo. Intenta nuevamente."];
  response.status(status).json({error: {
    status: code.replace(/-/g, "_").toUpperCase(), message,
  }});
}

// Firebase puede crear un token de descarga durante la carga. Se revoca antes
// de hacer visible la publicación/adjunto, sin cambiar otras claves ni bytes.
async function revokePrivateDownloadTokens(file, metadata) {
  try {
    if (!metadata.generation || !metadata.metageneration) throw new Error();
    const [updated] = await file.setMetadata({metadata: {
      ...(metadata.metadata || {}), firebaseStorageDownloadTokens: null,
    }}, {ifGenerationMatch: metadata.generation,
      ifMetagenerationMatch: metadata.metageneration});
    if (updated.generation !== metadata.generation ||
        Number(updated.size) !== Number(metadata.size) ||
        updated.contentType !== metadata.contentType ||
        updated.metadata?.firebaseStorageDownloadTokens) throw new Error();
  } catch (error) {
    console.warn("No se pudo proteger metadata de carga", {
      code: error.code || "metadata-mismatch",
    });
    throw new HttpsError("unavailable",
        "No se pudo proteger la carga. Reintenta confirmar o cancélala.");
  }
}

function protectedDownloadFunctions({db, auth, getBucket, getCaller,
  requireFileDownloadAccess, requireAttachmentDownloadAccess,
  runtimeEnvironment}) {
  function handler(attachment) {
    return async (request, response) => {
      response.set("Cache-Control", "private, no-store, max-age=0");
      response.set("X-Content-Type-Options", "nosniff");
      response.set("Vary", "Origin");
      try {
        const origin = request.get("Origin");
        const allowed = ORIGINS[runtimeEnvironment().publicAppUrl] || [];
        if (origin && !allowed.includes(origin)) {
          throw new HttpsError("permission-denied", "Origen no permitido.");
        }
        if (origin) {
          response.set("Access-Control-Allow-Origin", origin);
          response.set("Access-Control-Allow-Methods", "GET, OPTIONS");
          response.set("Access-Control-Allow-Headers", "Authorization");
          response.set("Access-Control-Expose-Headers", "Content-Disposition");
        }
        if (request.method === "OPTIONS") {
          response.status(204).end();
          return;
        }
        if (request.method !== "GET") {
          response.set("Allow", "GET, OPTIONS");
          response.status(405).json({error: {
            status: "INVALID_ARGUMENT", message: "Usa GET para descargar.",
          }});
          return;
        }
        const match = /^Bearer ([^\s]+)$/.exec(
            request.get("Authorization") || "");
        if (!match) {
          throw new HttpsError("unauthenticated", "Sesión requerida.");
        }
        let decoded;
        try {
          decoded = await auth.verifyIdToken(match[1], true);
        } catch {
          throw new HttpsError("unauthenticated", "Sesión no válida.");
        }
        const callerRequest = {auth: {uid: decoded.uid, token: decoded}};
        const id = documentId(request.query[attachment ? "attachmentId" :
          "fileId"]);
        const ref = db.collection(attachment ? "message_attachments" : "files")
            .doc(id);
        const validate = attachment ? requireAttachmentDownloadAccess :
          requireFileDownloadAccess;
        async function authorizedDescriptor() {
          const caller = await getCaller(callerRequest);
          const snapshot = await ref.get();
          if (!snapshot.exists) {
            throw new HttpsError("not-found", "Archivo no disponible.");
          }
          await validate(caller, snapshot.data());
          return descriptor(snapshot.data(), id, attachment);
        }
        const item = await authorizedDescriptor();
        const bucket = getBucket();
        const [metadata] = await bucket.file(item.path).getMetadata();
        if (Number(metadata.size) !== item.sizeBytes ||
            metadata.contentType !== item.contentType || !metadata.generation) {
          throw new HttpsError("failed-precondition", "Archivo no disponible.");
        }
        const file = bucket.file(item.path, {generation: metadata.generation});
        const bytes = await boundedDownload(file, item.sizeBytes);
        const current = await authorizedDescriptor();
        if (JSON.stringify(current) !== JSON.stringify(item)) {
          throw new HttpsError("failed-precondition", "El archivo cambió.");
        }
        const ascii = item.name.replace(/[^a-zA-Z0-9._ -]/g, "_");
        const encoded = encodeURIComponent(item.name)
            .replace(/['()*]/g, (character) =>
              `%${character.charCodeAt(0).toString(16).toUpperCase()}`);
        response.set("Content-Type", item.contentType);
        response.set("Content-Length", String(bytes.length));
        response.set("Content-Disposition",
            `attachment; filename="${ascii}"; filename*=UTF-8''${encoded}`);
        response.status(200).send(bytes);
      } catch (error) {
        sendError(response, error);
      }
    };
  }
  const options = {memory: "512MiB", concurrency: 4,
    timeoutSeconds: 120, invoker: "public", cors: false};
  return {
    descargarArchivoProtegido: onRequest(options, handler(false)),
    descargarAdjuntoProtegido: onRequest(options, handler(true)),
  };
}

module.exports = {protectedDownloadFunctions, boundedDownload, descriptor,
  revokePrivateDownloadTokens};
