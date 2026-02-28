//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing
import TestSupport

#if canImport(FoundationEssentials)
@_spi(SwiftCorelibsFoundation)
import FoundationEssentials
#endif

// MARK: - Test Suite

@Suite("PropertyListDecoder") private struct PropertyListDecoderTests {
    @Suite struct DataCorrupted {
        @Suite struct OpenStep {
            @Test func `empty data`() throws {
                let (_, underlyingError) = try expectPlistData(
                    Data(),
                    decodingAs: [String: String].self,
                    validator: DecodingErrorValidator.dataCorrupted(
                        codingPath: [],
                        debugDescription: "The given data was not a valid property list."
                    )
                )

                let underlying = try #require(underlyingError)
                let cocoaError = try #require(underlying as? CocoaError)

                #expect(cocoaError.code == .propertyListReadCorrupt)
            }

            @Test func `invalid plist`() throws {

            }
        }

        /// Make sure our utility function works as expected
        @Test func plistEncoded() throws {
            let binary = try [String: String]()
                .plistEncoded(as: .binary)
            #expect(binary.count == 42)

            let xml = try [String: String]()
                .plistEncoded(as: .xml)
            #expect(String(decoding: xml, as: UTF8.self) == """
                <?xml version="1.0" encoding="UTF-8"?>
                <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
                <plist version="1.0">
                <dict/>
                </plist>

                """)
        }

        @Test func `invalid binary plist`() throws {
            let data = try [String: String]()
                .plistEncoded(as: .binary)
                .dropLast(1)

            try expectPlistData(
                data,
                decodingAs: [String: String].self,
                validator: DecodingErrorValidator.dataCorrupted(
                    codingPath: [],
                    debugDescription: "The given data was not a valid property list."
                )
            )
        }

        @Test func `invalid xml plist`() throws {
            let data = try [String: String]()
                .plistEncoded(as: .xml)
                .dropLast(10)

            try expectPlistData(
                data,
                decodingAs: [String: String].self,
                validator: DecodingErrorValidator.dataCorrupted(
                    codingPath: [],
                    debugDescription: "The given data was not a valid property list."
                )
            )
        }

        @Test func `unknown encoding`() throws {
            try expectPlistData(
                Data(
                """
                <?xml version="1.0" encoding="ABC-123"?>
                """.utf8
                ),
                decodingAs: [String: String].self,
                validator: DecodingErrorValidator.dataCorrupted(
                    codingPath: [],
                    debugDescription: "Encountered unknown encoding"
                )
            )
        }

        @Test func `incomplete encoding name`() throws {
            try expectPlistData(
                Data(
                """
                <?xml version="1.0" encod
                """.utf8
                ),
                decodingAs: [String: String].self,
                validator: DecodingErrorValidator.dataCorrupted(
                    codingPath: [],
                    debugDescription: "End of buffer while looking for encoding name"
                )
            )
        }

        @Test func `cannot convert input to UTF-16`() throws {
            // If UTF-8 decoding fails, PropertyListDecoder falls back to parsing
            // the data as an OpenStep plist, which requires UTF-16 encoding. So
            // we need to use code points that are both invalid UTF-8 and invalid
            // UTF-16 to reach the code path we want to test here.
            //
            // UTF-8:
            // 0xC3 starts a 2-byte UTF-8 sequence, but 0x28 is not a valid continuation byte
            // (continuations must be in 0x80...0xBF), so this data is not valid UTF-8.
            //
            // UTF-16:
            // The code in question does not actually do a check for whether the
            // string is UTF-16, since it bails out if the string is not UTF-8,
            // but the error message says it is not UTF-16. We check for the
            // existing error message to document the current behavior in this test.
            let data = Data([0xC3, 0x28])

            try expectPlistData(
                data,
                decodingAs: [String: String].self,
                validator: DecodingErrorValidator.dataCorrupted(
                    codingPath: [],
                    debugDescription: "Cannot convert input to UTF-16"
                )
            )
        }
    }

    @Suite struct ValueNotFound {
        @Test func `expected value is null`() throws {
            let data = try [
                "integer": (nil as Int?),
            ].plistEncoded(as: .xml)

            try expectPlistData(
                data,
                decodingAs: [String: String].self,
                validator: DecodingErrorValidator.valueNotFound(
                    expectedType: String.self,
                    codingPath: ["integer"],
                    debugDescription: "Found null value instead"
                )
            )
        }

        @Suite struct `Un-keyed container reaches end` {
            @Test func `root un-keyed container`() throws {
                let data = try ["a-string"]
                    .plistEncoded(as: .xml)

                try expectPlistData(
                    data,
                    decodingAs: TwoUnkeyedOf<String>.self,
                    validator: DecodingErrorValidator.valueNotFound(
                        expectedType: String.self,
                        codingPath: ["Index 1"],
                        debugDescription: "Unkeyed container is at end."
                    )
                )
            }

            @Test func `nested un-keyed container`() throws {
                let data = try [["a", "b", "c"]]
                    .plistEncoded(as: .xml)

                try expectPlistData(
                    data,
                    decodingAs: TwoUnkeyedOf<TwoUnkeyedOf<String>>.self,
                    validator: DecodingErrorValidator.valueNotFound(
                        expectedType: TwoUnkeyedOf<String>.self,
                        codingPath: ["Index 1"],
                        debugDescription: "Unkeyed container is at end."
                    )
                )
            }

            @Test func `nestedUnkeyedContainer past end`() throws {
                let data = try ["only"]
                    .plistEncoded(as: .xml)

                try expectPlistData(
                    data,
                    decodingAs: AsksForNestedUnkeyedContainerAtEnd.self,
                    validator: DecodingErrorValidator.valueNotFound(
                        expectedType: UnkeyedDecodingContainer.self,
                        codingPath: ["Index 1"],
                        debugDescription: "Cannot get nested unkeyed container -- unkeyed container is at end."
                    )
                )
            }

            @Test func `superDecoder past end`() throws {
                let data = try ["only"]
                    .plistEncoded(as: .xml)

                try expectPlistData(
                    data,
                    decodingAs: AsksForSuperDecoderAtEnd.self,
                    validator: DecodingErrorValidator.valueNotFound(
                        expectedType: UnkeyedDecodingContainer.self,
                        codingPath: ["Index 1"],
                        debugDescription: "Cannot get nested unkeyed container -- unkeyed container is at end."
                        // ⚠️ Does not match JSONDecoder, which mentions superDecoder() in error for equivalent situation
                    )
                )
            }
        }
    }
}

// MARK: - Helpers

private extension Encodable {
    func plistEncoded(
        as format: PropertyListDecoder.PropertyListFormat
    ) throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = format
        let data = try encoder.encode(self)
        return data
    }
}

@discardableResult
private func expectPlistData<Value: Decodable>(
    _ data: Data,
    decodingAs _: Value.Type,
    updatingDecoder updateDecoder: (PropertyListDecoder) -> Void = { _ in },
    validator: DecodingErrorValidator.Validator,
    sourceLocation: SourceLocation = #_sourceLocation
) throws -> (error: DecodingError, underlyingError: (any Error)?) {
    let decoder = PropertyListDecoder()
    updateDecoder(decoder)

    let error = #expect(throws: DecodingError.self, sourceLocation: sourceLocation) {
        _ = try decoder.decode(Value.self, from: data)
    }

    let unwrappedError = try #require(error, sourceLocation: sourceLocation)

    let underlyingError = validator(unwrappedError)

    return (unwrappedError, underlyingError)
}

/// Attempts to decode two values of type `T` from an un-keyed container.
private struct TwoUnkeyedOf<T: Decodable>: Decodable {
    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        _ = try container.decode(T.self)
        _ = try container.decode(T.self)
    }
}

/// Decodes an un-keyed container, consumes exactly 1 element, then attempts to
/// request a nested un-keyed container from an already-ended un-keyed container.
private struct AsksForNestedUnkeyedContainerAtEnd: Decodable {
    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        #expect(container.count == 1, "use this type with a container that contains a single element")
        _ = try container.decode(String.self)
        _ = try container.nestedUnkeyedContainer() // this will always fail
    }
}

/// Decodes an unkeyed container, consumes exactly 1 element, then attempts to
/// request a `superDecoder()` from an already-ended unkeyed container.
private struct AsksForSuperDecoderAtEnd: Decodable {
    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        #expect(container.count == 1, "use this type with a container that contains a single element")
        _ = try container.decode(String.self)
        _ = try container.superDecoder() // this will always fail
    }
}
