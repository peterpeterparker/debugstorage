import type { Principal } from '@dfinity/principal';
import type { ActorMethod } from '@dfinity/agent';

export interface AssetKey {
  'token' : [] | [string],
  'sha256' : [] | [Array<number>],
  'name' : string,
  'fullPath' : string,
  'folder' : string,
}
export interface Chunk { 'content' : Array<number>, 'batchId' : bigint }
export type Hash = Array<number>;
export type HashTree = { 'labeled' : [Key, HashTree__1] } |
  { 'fork' : [HashTree__1, HashTree__1] } |
  { 'leaf' : Value } |
  { 'empty' : null } |
  { 'pruned' : Hash };
export type HashTree__1 = { 'labeled' : [Key, HashTree__1] } |
  { 'fork' : [HashTree__1, HashTree__1] } |
  { 'leaf' : Value } |
  { 'empty' : null } |
  { 'pruned' : Hash };
export type HeaderField = [string, string];
export type HeaderField__1 = [string, string];
export interface HttpRequest {
  'url' : string,
  'method' : string,
  'body' : Array<number>,
  'headers' : Array<HeaderField>,
}
export interface HttpResponse {
  'body' : Array<number>,
  'headers' : Array<HeaderField>,
  'upgrade' : [] | [boolean],
  'streaming_strategy' : [] | [StreamingStrategy],
  'status_code' : number,
}
export type Key = Array<number>;
export interface StreamingCallbackHttpResponse {
  'token' : [] | [StreamingCallbackToken__1],
  'body' : Array<number>,
}
export interface StreamingCallbackToken {
  'token' : [] | [string],
  'sha256' : [] | [Array<number>],
  'fullPath' : string,
  'headers' : Array<HeaderField>,
  'index' : bigint,
}
export interface StreamingCallbackToken__1 {
  'token' : [] | [string],
  'sha256' : [] | [Array<number>],
  'fullPath' : string,
  'headers' : Array<HeaderField>,
  'index' : bigint,
}
export type StreamingStrategy = {
    'Callback' : {
      'token' : StreamingCallbackToken__1,
      'callback' : [Principal, string],
    }
  };
export type Value = Array<Array<number>>;
export interface _SERVICE {
  'commitUpload' : ActorMethod<
    [
      {
        'headers' : Array<HeaderField__1>,
        'chunkIds' : Array<bigint>,
        'batchId' : bigint,
      },
    ],
    undefined,
  >,
  'del' : ActorMethod<
    [{ 'token' : [] | [string], 'fullPath' : string }],
    undefined,
  >,
  'http_request' : ActorMethod<[HttpRequest], HttpResponse>,
  'http_request_streaming_callback' : ActorMethod<
    [StreamingCallbackToken],
    StreamingCallbackHttpResponse,
  >,
  'initUpload' : ActorMethod<[AssetKey], { 'batchId' : bigint }>,
  'list' : ActorMethod<[[] | [string]], Array<AssetKey>>,
  'tree' : ActorMethod<[string], HashTree>,
  'uploadChunk' : ActorMethod<[Chunk], { 'chunkId' : bigint }>,
}
