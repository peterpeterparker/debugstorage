import { storageActor } from "./actor.mjs";

const list = async () => storageActor.list([]);

list().then((results) => console.log(results));
