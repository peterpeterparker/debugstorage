import { readFile } from "fs/promises";
import fetch from "node-fetch";
import { Actor, HttpAgent } from "@dfinity/agent";

import { idlFactory } from "./src/declarations/debugstorage_backend/debugstorage_backend.did.mjs";

const createActor = (canisterId, options) => {
  const agent = new HttpAgent(options ? { ...options.agentOptions } : {});

  // Fetch root key for certificate validation during development
  if (process.env.NODE_ENV !== "production") {
    agent.fetchRootKey().catch((err) => {
      console.warn(
        "Unable to fetch root key. Check to ensure that your local replica is running"
      );
      console.error(err);
    });
  }

  // Creates an actor with using the candid interface and the HttpAgent
  return Actor.createActor(idlFactory, {
    agent,
    canisterId,
    ...(options ? options.actorOptions : {}),
  });
};

const MAINNET = false;

// Production: "okoji-rqaaa-aaaap-qasma-cai"
// local rrkah-fqaaa-aaaaa-aaaaq-cai
const canisterId = MAINNET
  ? "okoji-rqaaa-aaaap-qasma-cai"
  : "rrkah-fqaaa-aaaaa-aaaaq-cai";

const storageActor = createActor(canisterId, {
  agentOptions: {
    fetch,
    host: MAINNET ? "https://ic0.app" : "http://localhost:8000",
  },
});

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
