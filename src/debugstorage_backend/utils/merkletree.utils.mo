/**
 * Credits to Joachim Breitner (https://github.com/nomeata)
 *
 * Original code: https://github.com/nomeata/motoko-merkle-tree
 */


/// **A merkle tree**
///
/// This library provides a simple merkle tree data structure for Motoko.
/// It provides a key-value store, where both keys and values are of type Blob.
///
/// ```motoko
/// var t = MerkleTree.empty();
/// t := MerkleTree.put(t, "Alice", "\00\01");
/// t := MerkleTree.put(t, "Bob", "\00\02");
///
/// let w = MerkleTree.reveals(t, ["Alice" : Blob, "Malfoy": Blob].vals());
/// ```
/// will produce
/// ```
/// #fork (#labeled ("\3B…\43", #leaf("\00\01")), #pruned ("\EB…\87"))
/// ```
///
/// The witness format is compatible with
/// the [HashTree] used by the Internet Computer,
/// so client-side, the same logic can be used, but note
///
///  * the trees produces here are flat; no nested subtrees
//     (but see `witnessUnderLabel` to place the whole tree under a label).
///  * keys need to be SHA256-hashed before they are looked up in the witness
///  * no CBOR encoding is provided here. The assumption is that the witnesses are transferred
///    via Candid, and decoded to a data type understood by the client-side library.
///
/// Revealing multiple keys at once is supported, and so is proving absence of a key.
///
/// By ordering the entries by the _hash_ of the key, and branching the tree
/// based on the bits of that hash (i.e. a patricia trie), the merkle tree and thus the root
/// hash is unique for a given tree. This in particular means that insertions are efficient,
/// and that the tree can be reconstructed from the data, independently of the insertion order.
///
/// A functional API is provided (instead of an object-oriented one), so that
/// the actual tree can easily be stored in stable memory.
///
/// The tree-related functions are still limited, only insertion so far, no
/// lookup, deletion, modification, or more fancy operations. These can be added
/// when needed.
///
/// [HashTree]: <https://sdk.dfinity.org/docs/interface-spec/index.html#_certificate>

import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Debug "mo:base/Debug";
import Blob "mo:base/Blob";
import Nat8 "mo:base/Nat8";
import Buffer "mo:base/Buffer";
import SHA256 "mo:sha256/SHA256";

import Dyadic "./dyadic.utils";

import CertificationTypes "../types/certification.types";
import HashUtils "./hash.utils";

module {

  public type Key = CertificationTypes.Key;
  public type Value = CertificationTypes.Value;
  public type Witness = CertificationTypes.HashTree;

  /// This is the main type of this module: a possibly empty tree that maps
  /// `Key`s to `Value`s.
  public type Tree = InternalT;

  type InternalT = ?T;

  type T = {
    // All values in this fork are contained in the `interval`.
    // Moreover, the `left` subtree is contained in the left half of the interval
    // And the `right` subtree is contained in the right half of the interval
    #fork : {
      interval : Dyadic.Interval;
      hash : Hash; // simple memoization of the HashTree hash
      left : T;
      right : T;
    };
    #leaf : {
      key : Key; // currently unused, but will be useful for iteration
      keyHash : Hash;
      prefix : [Nat8];
      hash : Hash; // simple memoization of the HashTree hash
      value : Value;
    };
  };

  public type Hash = Blob;

  /// Nat8 is easier to work with so far
  type Prefix = [Nat8];

  // Hash-related functions
  func hp(b : Blob) : [Nat8] {
    SHA256.sha256(Blob.toArray(b));
  };

  let prefixToHash : [Nat8] -> Blob = Blob.fromArray;

  // Functions on Tree (the possibly empty tree)

  /// The root hash of the merkle tree. This is the value that you would sign
  /// or pass to `CertifiedData.set`
  public func treeHash(t : Tree) : Hash {
    switch t {
      case null HashUtils.hashBlob(["\11ic-hashtree-empty"]);
      case (?t) hashT(t);
    }
  };


  /// Tree construction: The empty tree
  public func empty() : Tree {
    return null
  };

  /// Tree construction: Inserting a key into the tree. An existing value under that key is overridden.
  public func put(t : Tree, k : Key, v : Value) : Tree {
    switch t {
      case null {? (mkLeaf(k,v))};
      case (?t) {? (putT(t, hp(k), k, v))};
    }
  };


  // Now on the real T (the non-empty tree)

  func hashT(t : T) : Hash {
    switch t {
      case (#fork(f)) f.hash;
      case (#leaf(l)) l.hash;
    }
  };

  func intervalT(t : T) : Dyadic.Interval {
    switch t {
      case (#fork(f)) { f.interval };
      case (#leaf(l)) { Dyadic.singleton(l.prefix) };
    }
  };

  // Smart contructors (memoize the hashes and other data)

  func hashValNode(v : Value) : Hash {
    let d = SHA256.Digest();
    d.write(Blob.toArray("\10ic-hashtree-leaf"));

    for (value in v.vals()) {
      d.write(value);
    };

    return Blob.fromArray(d.sum());
  };

  func mkLeaf(k : Key, v : Value) : T {
    let keyPrefix = hp(k);
    let keyHash = prefixToHash(keyPrefix);

    #leaf {
      key = k;
      keyHash = keyHash;
      prefix = keyPrefix;
      hash = HashUtils.hashBlob(["\13ic-hashtree-labeled", keyHash, hashValNode(v)]);
      value = v;
    }
  };

  func mkFork(i : Dyadic.Interval, t1 : T, t2 : T) : T {
    #fork {
      interval = i;
      hash = HashUtils.hashBlob(["\10ic-hashtree-fork", hashT(t1), hashT(t2)]);
      left = t1;
      right = t2;
    }
  };

  // Insertion

  func putT(t : T, p : Prefix, k : Key, v : Value) : T {
    switch (Dyadic.find(p, intervalT(t))) {
      case (#before(i)) {
        mkFork({ prefix = p; len = i }, mkLeaf(k, v), t)
      };
      case (#after(i)) {
        mkFork({ prefix = p; len = i }, t, mkLeaf(k, v))
      };
      case (#equal) {
	      // This overrides the existing value
        mkLeaf(k,v)
      };
      case (#in_left_half) {
        putLeft(t, p, k, v);
      };
      case (#in_right_half) {
        putRight(t, p, k, v);
      };
    }
  };

  func putLeft(t : T, p : Prefix, k : Key, v : Value) : T {
    switch (t) {
      case (#fork(f)) {
        mkFork(f.interval, putT(f.left,p,k,v), f.right)
      };
      case _ {
        Debug.print("putLeft: Not a fork");
        t
      }
    }
  };

  func putRight(t : T, p : Prefix, k : Key, v : Value) : T {
    switch (t) {
      case (#fork(f)) {
        mkFork(f.interval, f.left, putT(f.right,p,k,v))
      };
      case _ {
        Debug.print("putRight: Not a fork");
        t
      }
    }
  };

  // Witness construction

  /// Create a witness that reveals the value of the key `k` in the tree `tree`.
  ///
  /// If `k` is not in the tree, the witness will prove that fact.
  public func reveal(tree : Tree, k : Key) : Witness {
    switch tree {
      case null {#empty};
      case (?t) {
        let (_, w, _) = revealT(t, hp(k));
        w
      };
    }
  };

  // Returned bools indicate whether to also reveal left or right neighbor
  func revealT(t : T, p : Prefix) : (Bool, Witness, Bool) {
    switch (Dyadic.find(p, intervalT(t))) {
      case (#before(i)) {
        (true, revealMinKey(t), false);
      };
      case (#after(i)) {
        (false, revealMaxKey(t), true);
      };
      case (#equal(i)) {
        (false, revealLeaf(t), false);
      };
      case (#in_left_half) {
        revealLeft(t, p);
      };
      case (#in_right_half) {
        revealRight(t, p);
      };
    }
  };

  func revealMinKey(t : T) : Witness {
    switch (t) {
      case (#fork(f)) {
        #fork(revealMinKey(f.left), #pruned(hashT(f.right)))
      };
      case (#leaf(l)) {
        #labeled(l.keyHash, #pruned(hashValNode(l.value)));
      }
    }
  };

  func revealMaxKey(t : T) : Witness {
    switch (t) {
      case (#fork(f)) {
        #fork(#pruned(hashT(f.left)), revealMaxKey(f.right))
      };
      case (#leaf(l)) {
        #labeled(l.keyHash, #pruned(hashValNode(l.value)));
      }
    }
  };

  func revealLeaf(t : T) : Witness {
    switch (t) {
      case (#fork(f)) {
        Debug.print("revealLeaf: Not a leaf");
        #empty
      };
      case (#leaf(l)) {
        #labeled(l.keyHash, #leaf(l.value));
      }
    }
  };

  func revealLeft(t : T, p : Prefix) : (Bool, Witness, Bool) {
    switch (t) {
      case (#fork(f)) {
        let (b1,w1,b2) = revealT(f.left, p);
        let w2 = if b2 { revealMinKey(f.right) } else { #pruned(hashT(f.right)) };
        (b1, #fork(w1, w2), false);
      };
      case (#leaf(l)) {
        Debug.print("revealLeft: Not a fork");
        (false, #empty, false)
      }
    }
  };

  func revealRight(t : T, p : Prefix) : (Bool, Witness, Bool) {
    switch (t) {
      case (#fork(f)) {
        let (b1,w2,b2) = revealT(f.right, p);
        let w1 = if b1 { revealMaxKey(f.left) } else { #pruned(hashT(f.left)) };
        (false, #fork(w1, w2), b2);
      };
      case (#leaf(l)) {
        Debug.print("revealRight: Not a fork");
        (false, #empty, false)
      }
    }
  };

  /// Merges two witnesses, to reveal multiple values.
  ///
  /// The two witnesses must come from the same tree, else this function is
  /// undefined (and may trap).
  public func merge(w1 : Witness, w2 : Witness) : Witness {
    switch (w1, w2) {
      case (#pruned(h1), #pruned(h2)) {
        if (h1 != h2) Debug.print("MerkleTree.merge: pruned hashes differ");
        #pruned(h1)
      };
      case (#pruned _, w2) w2;
      case (w1, #pruned _) w1;
      // If both witnesses are not pruned, they must be headed by the same
      // constructor:
      case (#empty, #empty) #empty;
      case (#labeled(l1, w1), #labeled(l2, w2)) {
        if (l1 != l2) Debug.print("MerkleTree.merge: labels differ");
        #labeled(l1, merge(w1, w2));
      };
      case (#fork(w11, w12), #fork(w21, w22)) {
        #fork(merge(w11, w21), merge(w12, w22))
      };
      case (#leaf(v1), #leaf(v2)) {
        if (v1 != v2) Debug.print("MerkleTree.merge: values differ");
        #leaf(v2)
      };
      case (_,_) {
        Debug.print("MerkleTree.merge: shapes differ");
        #empty;
      }
    }
  };

  /// Reveal nothing from the tree. Mostly useful as a netural element to `merge`.
  public func revealNothing(tree : Tree) : Witness {
    #pruned(treeHash(tree))
  };

  /// Reveals multiple keys
  public func reveals(tree : Tree, ks : Iter.Iter<Key>) : Witness {
    // Odd, no Iter.fold? Then let’s do a mutable loop
    var w = revealNothing(tree);
    for (k in ks) { w := merge(w, reveal(tree, k)); };
    return w;
  };

  /// Nests a witness under a label. This can be used when you want to use this
  /// library (which only produces flat labeled tree), but want to be forward
  /// compatible to a world where you actually produce nested labeled trees, or
  /// to be compatibe with an external specification that requires you to put
  /// this hash-of-blob-labeled tree in a subtree.
  ///
  /// To not pass the result of this function to `merge`! of this ru
  public func witnessUnderLabel(l : Blob, w : Witness) : Witness {
    #labeled(l, w)
  };

  /// This goes along `witnessUnderLabel`, and transforms the hash
  /// that is calculated by `treeHash` accordingly.
  ///
  /// If you wrap your witnesses using `witnessUnderLabel` before
  /// sending them out, make sure to wrap your tree hash with `hashUnderLabel`
  /// before passing them to `CertifiedData.set`.
  public func hashUnderLabel(l : Blob, h : Hash) : Hash {
    HashUtils.hashBlob(["\13ic-hashtree-labeled", prefixToHash(hp(l)), h]);
  };
}