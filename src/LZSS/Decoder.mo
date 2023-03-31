import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";

import It "mo:itertools/Iter";

import Common "Common";
import Option "mo:base/Option";

module{
    type Buffer<A> = Buffer.Buffer<A>;
    type LZSSEntry = Common.LZSSEntry;

    public func decode (compressed_buffer: Buffer<LZSSEntry>): Blob {
        let compressed_data = Buffer.toArray(compressed_buffer);
        let buffer = Buffer.Buffer<Nat8>(8);

        for (entry in compressed_data.vals()) {
            switch(entry){
                case(#literal(byte)){
                    buffer.add(byte);
                };
                case(#pointer((backward_offset, len))){
                    if (backward_offset > buffer.size()){
                        Debug.trap("LZSS decode(): Invalid LZSS #pointer (backward_offset > decompressed data size)");
                    };

                    let index = ((buffer.size() - backward_offset) : Nat) : Nat;
                    
                    for (i in It.range(index, index + len)){
                        if (i >= buffer.size()){
                            let rle_index = index + (i % buffer.size());
                            buffer.add(buffer.get(rle_index));
                        }else{
                            buffer.add(buffer.get(i));
                        }
                    };
                };
            }
        };

        let array = Buffer.toArray(buffer);
        Blob.fromArray(array);
    };

    public class Decoder(output_buffer: ?Buffer<Nat8>){
        
        let buffer = Option.get(output_buffer, Buffer.Buffer<Nat8>(8));

        public func decodeEntry(entry: LZSSEntry) {
            switch(entry){
                case(#literal(byte)){
                    buffer.add(byte);
                };
                case(#pointer((backward_offset, len))){
                    if (backward_offset > buffer.size()){
                        Debug.trap("LZSS decode(): Invalid LZSS #pointer (backward_offset > decompressed data size)");
                    };

                    let index = ((buffer.size() - backward_offset) : Nat) : Nat;
                    
                    for (i in It.range(index, index + len)){
                        if (i >= buffer.size()){
                            let rle_index = index + (i % buffer.size());
                            buffer.add(buffer.get(rle_index));
                        }else{
                            buffer.add(buffer.get(i));
                        }
                    };
                };
            };
        };

        public func decode (compressed_buffer: Buffer<LZSSEntry>) {
            let compressed_data = Buffer.toArray(compressed_buffer);

            for (entry in compressed_data.vals()) {
                decodeEntry(entry);
            };
        };

        public func getBuffer() : Buffer<Nat8> { buffer };
    };
}