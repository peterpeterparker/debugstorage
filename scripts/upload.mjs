import { readFile } from "fs/promises";
import { storageActor } from "./actor.mjs";

// debug https://a4gq6-oaaaa-aaaab-qaa4q-cai.raw.ic0.app/?id=okoji-rqaaa-aaaap-qasma-cai
// https://forum.dfinity.org/t/feature-request-map-appropriate-http-request-methods-to-update-calls/4303/28

const uploadHtml = async ({ name, folder, src, fullPath }) => {
  const buffer = await readFile(src);

  const { batchId } = await storageActor.initUpload({
    name,
    mimeType: "text/html",
    fullPath,
    token: [],
    folder,
    sha256: [],
  });

  console.log(`[${name}] Init.`);

  const { chunkId } = await storageActor.uploadChunk({
    batchId,
    content: [...new Uint8Array(buffer)],
  });

  console.log(`[${name}] Chunk.`);

  await storageActor.commitUpload({
    batchId,
    chunkIds: [chunkId],
    headers: [
      ["Content-Type", "text/html"],
      ["accept-ranges", "bytes"],
      ...[["Cache-Control", `max-age=0`]],
    ],
  });

  console.log(`[${name}] Commit.`);
};

const upload = async () => {
  await Promise.all([
    uploadHtml({
      src: "./data/index.html",
      name: "index.html",
      folder: "resources",
      fullPath: "/",
    }),
    uploadHtml({
      src: "./data/post.html",
      name: "post1234",
      folder: "d",
      fullPath: "/d/post1234",
    }),
  ]);
};

upload().then(() => {
  console.log("Done.");
});
