import { Actor, HttpAgent } from "@dfinity/agent";

// Imports and re-exports candid interface
import pkg from './debugstorage_backend.did.js';
const { idlFactory } = pkg;
// CANISTER_ID is replaced by webpack based on node environment
export const canisterId = process.env.DEBUGSTORAGE_BACKEND_CANISTER_ID;

/**
 * 
 * @param {string | import("@dfinity/principal").Principal} canisterId Canister ID of Agent
 * @param {{agentOptions?: import("@dfinity/agent").HttpAgentOptions; actorOptions?: import("@dfinity/agent").ActorConfig}} [options]
 * @return {import("@dfinity/agent").ActorSubclass<import("./debugstorage_backend.did.js")._SERVICE>}
 */
export const createActor = (canisterId, options) => {
  const agent = new HttpAgent(options ? { ...options.agentOptions } : {});
  
  // Fetch root key for certificate validation during development
  if (process.env.NODE_ENV !== "production") {
    agent.fetchRootKey().catch(err => {
      console.warn("Unable to fetch root key. Check to ensure that your local replica is running");
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
  
/**
 * A ready-to-use agent for the debugstorage_backend canister
 * @type {import("@dfinity/agent").ActorSubclass<import("./debugstorage_backend.did.js")._SERVICE>}
 */
export const debugstorage_backend = createActor(canisterId);