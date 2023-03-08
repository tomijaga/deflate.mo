import Buffer "mo:base/Buffer";
import Deque "mo:base/Deque";
import LZSSEncoder "Encoder";
import Decoder "Decoder";

import Common "Common";

module {
    type Buffer<A> = Buffer.Buffer<A>;
    public type LZSSEntry = Common.LZSSEntry;

    public func encode(blob: Blob) : Buffer<LZSSEntry> = LZSSEncoder.encode(blob);
    public let decode = Decoder.decode;

    public let Encoder = LZSSEncoder.Encoder;

}