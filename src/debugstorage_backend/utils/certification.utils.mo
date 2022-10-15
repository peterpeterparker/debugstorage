import CertifiedData "mo:base/CertifiedData";
import Blob "mo:base/Blob";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Nat8 "mo:base/Nat8";
import Buffer "mo:base/Buffer";
import Text "mo:base/Text";

import HTTP "../types/http.types";

import CertificationTypes "../types/certification.types";

import HashUtils "./hash.utils";
import MerkleTreeUtils "./merkletree.utils";

/**
 * Credits to Joachim Breitner (https://github.com/nomeata)
 *
 * Original code: https://github.com/nomeata/motoko-certified-http
 *
 * https://forum.dfinity.org/t/certified-assets-from-motoko-poc-tutorial/7263/5
 * https://forum.dfinity.org/t/has-anyone-implemented-the-hash-algorithm-and-merkle-tree-in-motoko-language/6857
 *
 * https://gist.github.com/nomeata/f325fcd2a6692df06e38adedf9ca1877
 */

module {
  private type HeaderField = HTTP.HeaderField;

  private type Hash = CertificationTypes.Hash;
  private type HashTree = CertificationTypes.HashTree;

  /**
    * From SW:
    const hashTree = cbor.decode(new Uint8Array(tree));
    const reconstructed = await reconstruct(hashTree);
    const witness = cert.lookup([
        'canister',
        canisterId.toUint8Array(),
        'certified_data',
    ]);
    if (!witness) {
        throw new Error('Could not find certified data for this canister in the certificate.');
    }
    // First validate that the Tree is as good as the certification.
    if (!equal(witness, reconstructed)) {
        console.error('Witness != Tree passed in ic-certification');
        return false;
    }
    */

  /*
     *   This header contains the certificate obtained from the system, which we just pass through,
      *  and our hash tree. There is CBOR and Base64 encoding involved here.
    */
  public func certification_header(content : [[Nat8]], url : Text, tree : MerkleTreeUtils.Tree) : HeaderField {

    let cert = switch (CertifiedData.getCertificate()) {
      case (?c) c;
      case null {
        // unfortunately, we cannot do
        //   throw Error.reject("getCertificate failed. Call this as a query call!")
        // here, because this function isn’t async, but we can’t make it async
        // because it is called from a query (and it would do the wrong thing) :-(
        //
        // So just return erronous data instead
        "getCertificate failed. Call this as a query call!" : Blob;
      };
    };
    return (
      "ic-certificate",
      "certificate=:" # base64(cert) # ":, " # "tree=:" # base64(cbor_tree(asset_tree(content, url, tree))) # ":",
    );
  };

  /*
The (undocumented) interface for certified assets requires the service to put
all HTTP resources into such a tree. We only have one resource, so that is simple:
*/

  // func asset_tree() : HashTree {
  // #labeled ("http_assets",
  // #labeled ("/",
  // #leaf (h(main_page()))
  // )
  // );
  // };

  func asset_tree(content: [[Nat8]], url : Text, tree : MerkleTreeUtils.Tree) : HashTree {
    // #labeled (Text.encodeUtf8("http_assets"),
    //  MerkleTreeUtils.reveal(tree, Text.encodeUtf8(url)),
    //);
    MerkleTreeUtils.witnessUnderLabel(Text.encodeUtf8("http_assets"), MerkleTreeUtils.reveal(tree, Text.encodeUtf8(url)));
    // MerkleTreeUtils.hashUnderLabel(Text.encodeUtf8("http_assets"), MerkleTreeUtils.treeHash(tree));
    // MerkleTreeUtils.witnessUnderLabel(Text.encodeUtf8("http_assets"), MerkleTreeUtils.reveals(tree, Iter.fromArray([Text.encodeUtf8("/"), Text.encodeUtf8("/d/post1234")])));

    /* 
    #labeled (Text.encodeUtf8("http_assets"),
      #labeled(
        Text.encodeUtf8(url), #leaf content
      )
    ); */

  };

  /*
     * Base64 encoding.
    */
  private func base64(b : Blob) : Text {
    let base64_chars : [Text] = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "+", "/"];
    let bytes = Blob.toArray(b);
    let pad_len = if (bytes.size() % 3 == 0) { 0 } else {
      3 - bytes.size() % 3 : Nat;
    };
    let padded_bytes = Array.append(bytes, Array.tabulate<Nat8>(pad_len, func(_) { 0 }));
    var out = "";
    for (j in Iter.range(1, padded_bytes.size() / 3)) {
      let i = j - 1 : Nat; // annoying inclusive upper bound in Iter.range
      let b1 = padded_bytes[3 * i];
      let b2 = padded_bytes[3 * i +1];
      let b3 = padded_bytes[3 * i +2];
      let c1 = (b1 >> 2) & 63;
      let c2 = (b1 << 4 | b2 >> 4) & 63;
      let c3 = (b2 << 2 | b3 >> 6) & 63;
      let c4 = (b3) & 63;
      out #= base64_chars[Nat8.toNat(c1)] # base64_chars[Nat8.toNat(c2)] # (if (3 * i +1 >= bytes.size()) { "=" } else { base64_chars[Nat8.toNat(c3)] }) # (if (3 * i +2 >= bytes.size()) { "=" } else { base64_chars[Nat8.toNat(c4)] });
    };
    return out;
  };

  private func cbor_tree(tree : HashTree) : Blob {
    let buf = Buffer.Buffer<Nat8>(100);

    // CBOR self-describing tag
    buf.add(0xD9);
    buf.add(0xD9);
    buf.add(0xF7);

    func add_blob(b : Blob) {
      // Only works for blobs with less than 256 bytes
      buf.add(0x58);
      buf.add(Nat8.fromNat(b.size()));
      for (c in Blob.toArray(b).vals()) {
        buf.add(c);
      };
    };

    func addNat8(b : [[Nat8]]) {
      buf.add(0x58);
      for (chunk in b.vals()) {
        buf.add(Nat8.fromNat(chunk.size()));
        for (c in chunk.vals()) {
          buf.add(c);
        };
      };
    };

    func go(t : HashTree) {
      switch (t) {
        case (#empty) { buf.add(0x81); buf.add(0x00) };
        case (#fork(t1, t2)) { buf.add(0x83); buf.add(0x01); go(t1); go(t2) };
        case (#labeled(l, t)) {
          buf.add(0x83);
          buf.add(0x02);
          add_blob(l);
          go(t);
        };
        case (#leaf(v)) { buf.add(0x82); buf.add(0x03); addNat8(v) };
        case (#pruned(h)) { buf.add(0x82); buf.add(0x04); add_blob(h) };
      };
    };

    go(tree);

    return Blob.fromArray(buf.toArray());
  };

  public func update_asset_hash(tree : MerkleTreeUtils.Tree) {
    let certifiedData = MerkleTreeUtils.hashUnderLabel(Text.encodeUtf8("http_assets"), MerkleTreeUtils.treeHash(tree));
    CertifiedData.set(certifiedData);
  };

};
