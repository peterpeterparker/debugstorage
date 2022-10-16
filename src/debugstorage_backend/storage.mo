import Nat "mo:base/Nat";
import Text "mo:base/Text";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Error "mo:base/Error";
import Blob "mo:base/Blob";
import Principal "mo:base/Principal";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";

import Result "mo:base/Result";

import Types "./types/types";
import HTTP "./types/http.types";
import CertificationTypes "./types/certification.types";

import StorageTypes "./storage.types";

import Utils "./utils/utils";
import WalletUtils "./utils/wallet.utils";
import CertificationtUtils "./utils/certification.utils";
import MerkleTreeUtils "./utils/merkletree.utils";

import StorageStore "./storage.store";

actor Storage {

  private let BATCH_EXPIRY_NANOS = 300_000_000_000;

  private type Asset = StorageTypes.Asset;
  private type AssetKey = StorageTypes.AssetKey;
  private type AssetEncoding = StorageTypes.AssetEncoding;
  private type Chunk = StorageTypes.Chunk;

  private type HashTree = CertificationTypes.HashTree;

  private type HttpRequest = HTTP.HttpRequest;
  private type HttpResponse = HTTP.HttpResponse;
  private type HeaderField = HTTP.HeaderField;
  private type StreamingCallbackHttpResponse = HTTP.StreamingCallbackHttpResponse;
  private type StreamingCallbackToken = HTTP.StreamingCallbackToken;
  private type StreamingStrategy = HTTP.StreamingStrategy;

  private let walletUtils : WalletUtils.WalletUtils = WalletUtils.WalletUtils();

  // Preserve the application state on upgrades
  private stable var entries : [(Text, Asset)] = [];

  let storageStore : StorageStore.StorageStore = StorageStore.StorageStore();

  /**
     * HTTP
     */

  private func httpRequest({ method : Text; url : Text } : HttpRequest, upgrade : ?Bool) : HttpResponse {
    if (Text.notEqual(method, "GET")) {
      return {
        upgrade;
        body = Blob.toArray(Text.encodeUtf8("Method Not Allowed."));
        headers = [];
        status_code = 405;
        streaming_strategy = null;
      };
    };

    let result : Result.Result<Asset, Text> = storageStore.getAssetForUrl(url);

    switch (result) {
      case (#ok { key : AssetKey; headers : [HeaderField]; encoding : AssetEncoding }) {
        // TODO: issue https://forum.dfinity.org/t/http-request-how-to-not-upgrade-for-raw-domain/15876
        let certificationHeaders = CertificationtUtils.certification_header(encoding.contentChunks, key.fullPath, saveTree);

        // TODO: issue https://forum.dfinity.org/t/array-to-buffer-in-motoko/15880
        // let tmp = Buffer.fromArray<HeaderField>(headers);
        let concatHeaders = Buffer.Buffer<HeaderField>(headers.size());
        for (elem in headers.vals()) {
          concatHeaders.add(elem);
        };
        concatHeaders.add(certificationHeaders);

        return {
          upgrade;
          body = encoding.contentChunks[0];
          headers = concatHeaders.toArray();
          status_code = 200;
          streaming_strategy = createStrategy(key, encoding, headers)
        };
      };
      case (#err error) {};
    };

    return {
      upgrade;
      body = Blob.toArray(Text.encodeUtf8("Permission denied. Could not perform this operation."));
      headers = [];
      status_code = 403;
      streaming_strategy = null;
    };
  };

  public shared query func http_request(request : HttpRequest) : async HttpResponse {
    try {
      return httpRequest(request, ?false);
    } catch (err) {
      return {
        upgrade = null;
        body = Blob.toArray(Text.encodeUtf8("Unexpected error: " # Error.message(err)));
        headers = [];
        status_code = 500;
        streaming_strategy = null;
      };
    };
  };

  public shared query ({ caller }) func http_request_streaming_callback(
    streamingToken : StreamingCallbackToken,
  ) : async StreamingCallbackHttpResponse {
    let result : Result.Result<Asset, Text> = storageStore.getAsset(
      streamingToken.fullPath,
      streamingToken.token,
    );

    switch (result) {
      case (#ok { key : AssetKey; headers : [HeaderField]; encoding : AssetEncoding }) {
        return {
          token = createToken(key, streamingToken.index, encoding, headers);
          body = encoding.contentChunks[streamingToken.index];
        };
      };
      case (#err error) {
        throw Error.reject("Streamed asset not found: " # error);
      };
    };
  };

  private func createStrategy(key : AssetKey, encoding : AssetEncoding, headers : [HeaderField]) : ?StreamingStrategy {
    let streamingToken : ?StreamingCallbackToken = createToken(key, 0, encoding, headers);

    switch (streamingToken) {
      case (null) { null };
      case (?streamingToken) {
        // Hack: https://forum.dfinity.org/t/cryptic-error-from-icx-proxy/6944/8
        // Issue: https://github.com/dfinity/candid/issues/273

        let self : Principal = Principal.fromActor(Storage);
        let canisterId : Text = Principal.toText(self);

        let canister = actor (canisterId) : actor {
          http_request_streaming_callback : shared () -> async ();
        };

        return ?#Callback({
          token = streamingToken;
          callback = canister.http_request_streaming_callback;
        });
      };
    };
  };

  private func createToken(
    key : AssetKey,
    chunkIndex : Nat,
    encoding : AssetEncoding,
    headers : [HeaderField],
  ) : ?StreamingCallbackToken {
    if (chunkIndex + 1 >= encoding.contentChunks.size()) {
      return null;
    };

    let streamingToken : ?StreamingCallbackToken = ?{
      fullPath = key.fullPath;
      token = key.token;
      headers;
      index = chunkIndex + 1;
      sha256 = key.sha256;
    };

    return streamingToken;
  };

  /**
     * Upload
     */

  public shared ({ caller }) func initUpload(key : AssetKey) : async ({
    batchId : Nat;
  }) {
    let nextBatchID : Nat = storageStore.createBatch(key);

    return { batchId = nextBatchID };
  };

  public shared ({ caller }) func uploadChunk(chunk : Chunk) : async ({
    chunkId : Nat;
  }) {
    let (result : { #chunkId : Nat; #error : Text }) = storageStore.createChunk(chunk);

    switch (result) {
      case (#error error) {
        throw Error.reject(error);
      };
      case (#chunkId chunkId) {
        return { chunkId };
      };
    };
  };

  public shared ({ caller }) func commitUpload(
    { batchId; chunkIds; headers } : {
      batchId : Nat;
      headers : [HeaderField];
      chunkIds : [Nat];
    },
  ) : async () {
    let ({ error } : { error : ?Text }) = storageStore.commitBatch({
      batchId;
      headers;
      chunkIds;
    });

    switch (error) {
      case (?error) {
        throw Error.reject(error);
      };
      case null {
        // TODO: don't need to recaculate everything but just put
        saveTree := storageStore.assetTree();

        CertificationtUtils.update_asset_hash(saveTree);
      };
    };
  };

  /**
     * List and delete
     */

  public shared query ({ caller }) func list(folder : ?Text) : async [AssetKey] {
    let keys : [AssetKey] = storageStore.getKeys(folder);
    return keys;
  };

  public shared query func tree(url: Text): async HashTree {
    #labeled (Text.encodeUtf8("http_assets"),
      MerkleTreeUtils.reveal(saveTree, Text.encodeUtf8(url)),
    );
  };

  public shared ({ caller }) func del({ fullPath; token } : { fullPath : Text; token : ?Text }) : async () {
    let result : Result.Result<Asset, Text> = storageStore.deleteAsset(fullPath, token);

    switch (result) {
      case (#ok asset) {};
      case (#err error) {
        throw Error.reject("Asset cannot be deleted: " # error);
      };
    };
  };

  var saveTree: MerkleTreeUtils.Tree = MerkleTreeUtils.empty();

  system func preupgrade() {
    entries := Iter.toArray(storageStore.preupgrade().entries());
  };

  system func postupgrade() {
    storageStore.postupgrade(entries);
    entries := [];

    saveTree := storageStore.assetTree();

    CertificationtUtils.update_asset_hash(saveTree);
  };
};
