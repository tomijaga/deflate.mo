import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";

import ActorSpec "utils/ActorSpec2";
import Gzip "../src/Gzip";
import Example "data-files/dickens5";
import LZSS "../src/LZSS";
import PrefixTable "../src/LZSS/Encoder/PrefixTable";

actor {

    public func runTests() : async (Bool, Text) {
        let testGroups = [
            LzssTest.Encoder,
            LzssTest.PrefixTable,
            GzipTest.Encoder,
            GzipTest.Decoder,
        ];

        var output = "";
        var res = true;

        label for_loop for (testGroup in testGroups.vals()) {
            let (success, text) = testGroup();
            output #= text;

            if (success) {
                output #= "\1b[23;42;3m Success!\1b[0m";
            } else {
                output #= "\1b[46;41mTests Failed\1b[0m";
            };

            output #= "\n";

            res := res and success;
        };

        (res, output);
    };

    let {
        assertTrue;
        assertFalse;
        assertAllTrue;
        describe;
        it;
        skip;
        pending;
        run;
    } = ActorSpec;

    let fixed_huffman_encoder = Gzip.DefaultEncoder();
    let gzip_decoder = Gzip.Decoder();

    let GzipTest = {
        Encoder = func() : (Bool, Text) {
            run([
                describe(
                    " Gzip Encoder",
                    [
                        it(
                            "No compression",
                            do {
                                let gzip_encoder = Gzip.EncoderBuilder().noCompression().build();
                                let input = Text.encodeUtf8("Hello World");

                                gzip_encoder.encode(Blob.toArray(input));
                                let output = gzip_encoder.finish();

                                gzip_decoder.decode(output);
                                let res = gzip_decoder.finish(); // returns the decoded bytes and resets the decoder
                                let decoded = Blob.fromArray(Buffer.toArray(res.bytes));

                                assertTrue(
                                    decoded == input
                                );
                            },
                        ),
                        describe(
                            "Compression: Fixed Huffman codes",
                            [
                                it(
                                    "Compress \"Hello world\" (no back references)",
                                    do {
                                        let input = Text.encodeUtf8("Hello World");

                                        fixed_huffman_encoder.encode(Blob.toArray(input));
                                        let output = fixed_huffman_encoder.finish();

                                        gzip_decoder.decode(output);
                                        let res = gzip_decoder.finish();
                                        let decoded = Blob.fromArray(Buffer.toArray(res.bytes));

                                        assertTrue(decoded == input);
                                    },
                                ),
                                it(
                                    "Compress short text",
                                    do {
                                        let text = "Literature is full of repetition. Literary writers constantly use the literary device of repeated words. I think the only type of repetition which is bad is sloppy repetition. Repetition which is unintentional, which sounds awkward.";
                                        let input = Text.encodeUtf8(text);

                                        fixed_huffman_encoder.encode(Blob.toArray(input));
                                        let output = fixed_huffman_encoder.finish();
                                        Debug.print("short text example: " # debug_show (text.size()) # " -> " # debug_show output.size() # " bytes");

                                        gzip_decoder.decode(output);
                                        let res = gzip_decoder.finish();
                                        let decoded = Blob.fromArray(Buffer.toArray(res.bytes));

                                        assertTrue(decoded == input);
                                    },
                                ),
                                it(
                                    "Compression of large files with Fixed Huffman codes",
                                    do {
                                        let input = Text.encodeUtf8(Example.text);

                                        fixed_huffman_encoder.encode(Blob.toArray(input));
                                        let output = fixed_huffman_encoder.finish();
                                        Debug.print("Example: " # debug_show (Example.text.size()) # " -> " # debug_show output.size() # " bytes");

                                        assert output.size() < input.size() * 7 / 10;

                                        gzip_decoder.decode(output);
                                        let res = gzip_decoder.finish();
                                        let decoded = Blob.fromArray(Buffer.toArray(res.bytes));

                                        assertTrue(decoded == input);
                                    },
                                ),
                            ],
                        ),
                    ],
                )
            ]);
        };
        Decoder = func() : (Bool, Text) {
            run([
                describe(
                    "Gzip Decoder",
                    [
                        it(
                            "Dynamic Compression: short example",
                            do {
                                let blob : Blob = "\1f\8b\08\00\00\00\00\00\00\03\6d\8e\d1\09\c3\30\0c\44\57\d1\00\25\7b\14\f2\d5\0d\d4\58\21\22\46\32\92\5c\e3\ed\1b\87\e6\23\d0\2f\1d\c7\bb\d3\cd\1c\64\18\d5\08\d8\61\ad\39\83\ae\60\54\28\38\58\65\82\f9\24\ac\43\b3\a1\1c\16\15\0f\94\c8\1d\aa\13\c4\46\90\2f\26\d1\87\17\ba\2a\30\28\41\53\4b\3e\c1\f3\00\59\f6\13\57\39\b2\d1\0b\dd\7f\41\db\78\d9\c6\8e\37\a6\71\3c\6b\29\fd\b6\e6\f5\87\ae\c2\12\24\c3\c4\fc\f8\f9\ae\55\92\03\b6\bd\a1\a5\e9\0b\7e\9c\b5\21\e8\00\00\00";
                                let compressed_bytes = Blob.toArray(blob);

                                let gzip_decoder = Gzip.Decoder();
                                gzip_decoder.decode(compressed_bytes);
                                let res = gzip_decoder.finish();
                                let decoded = Blob.fromArray(Buffer.toArray(res.bytes));

                                assertTrue(
                                    decoded == "Literature is full of repetition. Literary writers constantly use the literary device of repeated words. I think the only type of repetition which is bad is sloppy repetition. Repetition which is unintentional, which sounds awkward."
                                );
                            },
                        ),

                        it(
                            "Dynamic Compression: long example",
                            do {
                                let blob : Blob = Example.dynamic_code_compression;
                                let compressed_bytes = Blob.toArray(blob);

                                let gzip_decoder = Gzip.Decoder();
                                gzip_decoder.decode(compressed_bytes);
                                let res = gzip_decoder.finish();
                                let decoded = Blob.fromArray(Buffer.toArray(res.bytes));

                                assertTrue(
                                    decoded == Text.encodeUtf8(Example.text)
                                )

                            },
                        ),
                    ],
                )
            ]);
        };
    };

    let LzssTest = {
        Encoder = func() : (Bool, Text) {
            run([
                describe(
                    "LZSS Encoding",
                    [
                        it(
                            "encoding",
                            do {
                                let input = Text.encodeUtf8("abracadabra");
                                let encoded = LZSS.encode(Blob.toArray(input));
                                let bytes = LZSS.decode(encoded);
                                let decoded = Blob.fromArray(Buffer.toArray(bytes));

                                assertTrue(input == decoded);
                            },
                        ),
                        describe(
                            "encode repeated patterns",
                            [
                                // it(
                                //     "'abcaaaaad' -> 'abc<3,5>d'",
                                //     do {
                                //         let bytes = Text.encodeUtf8("abcaaaaad");
                                //         let encoded = LZSS.encode(bytes);

                                //         Buffer.toArray(encoded) == [
                                //             #literal(0x61 : Nat8),
                                //             #literal(0x62 : Nat8),
                                //             #literal(0x63 : Nat8),
                                //             #pointer(3, 5),
                                //             #literal(0x64 : Nat8),
                                //         ];
                                //     },
                                // ),

                                // it(
                                //     "'fr-en-ch-en-en-end' -> 'fr-en-ch<6,9>d'",
                                //     do {
                                //         let bytes = Text.encodeUtf8("fr-en-ch-en-en-end");
                                //         let encoded = LZSS.encode(bytes);

                                //         Buffer.toArray(encoded) == [
                                //             #literal(0x66 : Nat8),
                                //             #literal(0x72 : Nat8),
                                //             #literal(0x2d : Nat8),
                                //             #literal(0x65 : Nat8),
                                //             #literal(0x6e : Nat8),
                                //             #literal(0x2d : Nat8),
                                //             #literal(0x63 : Nat8),
                                //             #literal(0x68 : Nat8),
                                //             #pointer(6, 9),
                                //             #literal(0x64 : Nat8),
                                //         ];
                                //     },
                                // ),

                            ],
                        ),
                        describe(
                            "Class Encoder",
                            [
                                it(
                                    "encoding",
                                    do {
                                        let blob = Text.encodeUtf8("abracadabra");
                                        let bytes = Blob.toArray(blob);
                                        let lzss = LZSS.Encoder(null);
                                        let buffer = Buffer.Buffer<LZSS.LZSSEntry>(8);

                                        lzss.encode(bytes, buffer);

                                        let decoded = LZSS.decode(buffer);
                                        assertTrue(bytes == Buffer.toArray(decoded));
                                    },
                                ),
                                it(
                                    "Prefix Encoder",
                                    do {
                                        for (i in Iter.range(0, 1)) {

                                            let lzss = LZSS.Encoder(null);
                                            let blob = Text.encodeUtf8(Example.text);
                                            let bytes = Blob.toArray(blob);

                                            let buffer = Buffer.Buffer<LZSS.LZSSEntry>(8);
                                            lzss.encodeBlob(blob, buffer);

                                            Debug.print("No: " # debug_show (i + 1));
                                            Debug.print("Example text size: " # debug_show (lzss.size()));

                                            let decoded = LZSS.decode(buffer);
                                            assert Buffer.toArray(decoded) == Blob.toArray(blob);
                                        };
                                        Debug.print("Prefix Encoder: Success!");
                                        assertTrue(true);
                                    },
                                ),
                            ],
                        ),
                    ],
                ),
            ]);
        };
        PrefixTable = func() : (Bool, Text) {
            run([
                describe(
                    "Prefix Table",
                    [
                        it(
                            "insert()",
                            do {
                                let table = PrefixTable.PrefixTable();

                                let bytes : [Nat8] = [1, 2, 3, 4, 5, 1, 2, 3, 4, 5, 1, 2, 3, 4, 5];

                                assertAllTrue([
                                    table.insert(bytes, 0, 3, 0) == null, // [1, 2, 3]
                                    table.insert(bytes, 1, 3, 1) == null, // [2, 3, 4]
                                    table.insert(bytes, 2, 3, 2) == null, // [3, 4, 5]

                                    table.insert(bytes, 5, 3, 5) == ?0,
                                    table.insert(bytes, 6, 3, 6) == ?1,
                                    table.insert(bytes, 7, 3, 7) == ?2,

                                    table.insert(bytes, 10, 3, 10) == ?5,
                                    table.insert(bytes, 11, 3, 11) == ?6,
                                    table.insert(bytes, 12, 3, 12) == ?7,
                                ]);
                            },
                        ),
                    ],
                ),
            ]);
        };
    };
};
