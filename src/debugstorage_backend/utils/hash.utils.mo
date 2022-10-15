import Blob "mo:base/Blob";
import SHA256 "mo:sha256/SHA256";

module {
    public func hashNat8(values: [[Nat8]]) : Blob {
        let d = SHA256.Digest();

        for (value in values.vals()) {
          d.write(value);
        };

        return Blob.fromArray(d.sum());
    };

    public func hashBlob(blobs: [Blob]) : Blob {
        let d = SHA256.Digest();

        for (blob in blobs.vals()) {
          d.write(Blob.toArray(blob));
        };

        return Blob.fromArray(d.sum());
    };
};
