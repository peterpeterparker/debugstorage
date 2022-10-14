import fetch from "node-fetch";
import { Actor, HttpAgent } from "@dfinity/agent";

import { idlFactory } from "../src/declarations/debugstorage_backend/debugstorage_backend.did.mjs";

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

const MAINNET = true;

// Production: "okoji-rqaaa-aaaap-qasma-cai"
// local rrkah-fqaaa-aaaaa-aaaaq-cai
export const canisterId = MAINNET
    ? "okoji-rqaaa-aaaap-qasma-cai"
    : "rrkah-fqaaa-aaaaa-aaaaq-cai";

export const storageActor = createActor(canisterId, {
    agentOptions: {
        fetch,
        host: MAINNET ? "https://ic0.app" : "http://localhost:8000",
    },
});