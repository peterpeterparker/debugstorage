/**
 * The CBOR encoding of a HashTree, according to
 * https://internetcomputer.org/docs/current/references/ic-interface-spec/#certification-encoding
 * This data structure needs only very few features of CBOR, so instead of writing
 * a full-fledged CBOR encoding library, I just directly write out the bytes for the
 * few construct we need here.
 *
 * Credits to Joachim Breitner (https://github.com/nomeata)
 *
 * Original code: https://github.com/nomeata/motoko-certified-http
*/
module {
    public type Hash = Blob;
    public type Key = Blob;
    public type Value = [[Nat8]];
    
    public type HashTree = {
        #empty;
        #pruned : Hash;
        #fork : (HashTree, HashTree);
        #labeled : (Key, HashTree);
        #leaf : Value;
    };
};
