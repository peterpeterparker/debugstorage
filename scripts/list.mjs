import { storageActor } from "./actor.mjs";

const list = async () => storageActor.tree("/d/post1234");

list().then((results) => console.log(JSON.stringify(results)));
