export const idlFactory = ({ IDL }) => {
  const HashTree__1 = IDL.Rec();
  const HeaderField__1 = IDL.Tuple(IDL.Text, IDL.Text);
  const HeaderField = IDL.Tuple(IDL.Text, IDL.Text);
  const HttpRequest = IDL.Record({
    'url' : IDL.Text,
    'method' : IDL.Text,
    'body' : IDL.Vec(IDL.Nat8),
    'headers' : IDL.Vec(HeaderField),
  });
  const StreamingCallbackToken__1 = IDL.Record({
    'token' : IDL.Opt(IDL.Text),
    'sha256' : IDL.Opt(IDL.Vec(IDL.Nat8)),
    'fullPath' : IDL.Text,
    'headers' : IDL.Vec(HeaderField),
    'index' : IDL.Nat,
  });
  const StreamingStrategy = IDL.Variant({
    'Callback' : IDL.Record({
      'token' : StreamingCallbackToken__1,
      'callback' : IDL.Func([], [], []),
    }),
  });
  const HttpResponse = IDL.Record({
    'body' : IDL.Vec(IDL.Nat8),
    'headers' : IDL.Vec(HeaderField),
    'upgrade' : IDL.Opt(IDL.Bool),
    'streaming_strategy' : IDL.Opt(StreamingStrategy),
    'status_code' : IDL.Nat16,
  });
  const StreamingCallbackToken = IDL.Record({
    'token' : IDL.Opt(IDL.Text),
    'sha256' : IDL.Opt(IDL.Vec(IDL.Nat8)),
    'fullPath' : IDL.Text,
    'headers' : IDL.Vec(HeaderField),
    'index' : IDL.Nat,
  });
  const StreamingCallbackHttpResponse = IDL.Record({
    'token' : IDL.Opt(StreamingCallbackToken__1),
    'body' : IDL.Vec(IDL.Nat8),
  });
  const AssetKey = IDL.Record({
    'token' : IDL.Opt(IDL.Text),
    'sha256' : IDL.Opt(IDL.Vec(IDL.Nat8)),
    'name' : IDL.Text,
    'fullPath' : IDL.Text,
    'folder' : IDL.Text,
  });
  const Key = IDL.Vec(IDL.Nat8);
  const Value = IDL.Vec(IDL.Vec(IDL.Nat8));
  const Hash = IDL.Vec(IDL.Nat8);
  HashTree__1.fill(
    IDL.Variant({
      'labeled' : IDL.Tuple(Key, HashTree__1),
      'fork' : IDL.Tuple(HashTree__1, HashTree__1),
      'leaf' : Value,
      'empty' : IDL.Null,
      'pruned' : Hash,
    })
  );
  const HashTree = IDL.Variant({
    'labeled' : IDL.Tuple(Key, HashTree__1),
    'fork' : IDL.Tuple(HashTree__1, HashTree__1),
    'leaf' : Value,
    'empty' : IDL.Null,
    'pruned' : Hash,
  });
  const Chunk = IDL.Record({
    'content' : IDL.Vec(IDL.Nat8),
    'batchId' : IDL.Nat,
  });
  return IDL.Service({
    'commitUpload' : IDL.Func(
        [
          IDL.Record({
            'headers' : IDL.Vec(HeaderField__1),
            'chunkIds' : IDL.Vec(IDL.Nat),
            'batchId' : IDL.Nat,
          }),
        ],
        [],
        [],
      ),
    'del' : IDL.Func(
        [IDL.Record({ 'token' : IDL.Opt(IDL.Text), 'fullPath' : IDL.Text })],
        [],
        [],
      ),
    'http_request' : IDL.Func([HttpRequest], [HttpResponse], ['query']),
    'http_request_streaming_callback' : IDL.Func(
        [StreamingCallbackToken],
        [StreamingCallbackHttpResponse],
        ['query'],
      ),
    'initUpload' : IDL.Func(
        [AssetKey],
        [IDL.Record({ 'batchId' : IDL.Nat })],
        [],
      ),
    'list' : IDL.Func([IDL.Opt(IDL.Text)], [IDL.Vec(AssetKey)], ['query']),
    'tree' : IDL.Func([IDL.Text], [HashTree], ['query']),
    'uploadChunk' : IDL.Func(
        [Chunk],
        [IDL.Record({ 'chunkId' : IDL.Nat })],
        [],
      ),
  });
};
export const init = ({ IDL }) => { return []; };
