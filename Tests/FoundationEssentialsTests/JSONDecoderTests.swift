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

@Suite("JSONDecoder") private struct JSONDecoderTests {
    @Test func keyNotFound() throws {
        struct MyStruct: Decodable {
            var a: String
            var b: String
        }

        try expectJSONString(
            """
            [
                {
                    "a": "A!"
                }
            ]
            """,
            decodingAs: [MyStruct].self,
            validator: DecodingErrorValidator.keyNotFound(
                keyStringValue: "b",
                codingPath: ["Index 0"],
                debugDescription: ""
            )
        )
    }

    @Suite struct TypeMismatch {
        @Test func stringForInt() throws {
            try expectJSONString(
                """
                [
                    { "int here": "actually I am a string" }
                ]
                """,
                decodingAs: [[String: Int]].self,
                validator: DecodingErrorValidator.typeMismatch(
                    expectedType: Int.self,
                    codingPath: ["Index 0", "int here"],
                    debugDescription: "found a string instead."
                )
            )
        }

        @Test func stringForBool() throws {
            try expectJSONString(
                """
                [
                    { "a real bool": true },
                    { "not a bool at all": "see, I told you" }
                ]
                """,
                decodingAs: [[String: Bool]].self,
                validator: DecodingErrorValidator.typeMismatch(
                    expectedType: Bool.self,
                    codingPath: ["Index 1", "not a bool at all"],
                    debugDescription: "found a string instead."
                )
            )
        }

        @Test func stringForDecimal() throws {
            try expectJSONString(
                """
                { "decimal": "nope" }
                """,
                decodingAs: [String: Decimal].self,
                validator: DecodingErrorValidator.typeMismatch(
                    expectedType: Decimal.self,
                    codingPath: ["decimal"],
                    debugDescription: ""
                )
            )
        }

        @Test func `string instead of unkeyed container`() throws {
            try expectJSONString(
                """
                { "not": "an array" }
                """,
                decodingAs: [String: [Int]].self,
                validator: DecodingErrorValidator.typeMismatch(
                    expectedType: [Any].self,
                    codingPath: ["not"],
                    debugDescription: "Expected to decode Array<Any> but found a string instead."
                )
            )
        }

        @Test func `string instead of nested dictionary`() throws {
            try expectJSONString(
                """
                { "dictionary": "not a dictionary" }
                """,
                decodingAs: [String: [String: Int]].self,
                validator: DecodingErrorValidator.typeMismatch(
                    expectedType: [String: Any].self,
                    codingPath: ["dictionary"],
                    debugDescription: "Expected to decode Dictionary<String, Any> but found a string instead."
                )
            )
        }

        @Test func `string instead of nested dictionary, non-default coding keys`() throws {
            try expectJSONString(
                """
                { "dictionaryGoesHere": "not a dictionary" }
                """,
                decodingAs: [String: [String: Int]].self,
                updatingDecoder: {
                    $0.keyDecodingStrategy = .convertFromSnakeCase
                },
                validator: DecodingErrorValidator.typeMismatch(
                    expectedType: [String: Any].self,
                    codingPath: ["dictionaryGoesHere"],
                    debugDescription: "Expected to decode Dictionary<String, Any> but found a string instead."
                )
            )
        }
    }

    @Suite struct ValueNotFound {
        @Test func `expected value is null`() throws {
            try expectJSONString(
                """
                { "value goes here": null }
                """,
                decodingAs: [String: Int].self,
                validator: DecodingErrorValidator.valueNotFound(
                    expectedType: Int.self,
                    codingPath: ["value goes here"],
                    debugDescription: ""
                )
            )
        }

        @Suite struct `Un-keyed container reaches end` {
            @Test func `root un-keyed container`() throws {
                try expectJSONString(
                    """
                    ["a-string"]
                    """,
                    decodingAs: TwoUnkeyedOf<String>.self,
                    validator: DecodingErrorValidator.valueNotFound(
                        expectedType: String.self,
                        codingPath: ["Index 1"],
                        debugDescription: "Unkeyed container is at end."
                    )
                )
            }

            @Test func `nested un-keyed container`() throws {
                try expectJSONString(
                    """
                    [
                        ["a", "b", "c"]
                    ]
                    """,
                    decodingAs: TwoUnkeyedOf<TwoUnkeyedOf<String>>.self,
                    validator: DecodingErrorValidator.valueNotFound(
                        expectedType: TwoUnkeyedOf<String>.self,
                        codingPath: ["Index 1"],
                        debugDescription: "Unkeyed container is at end."
                    )
                )
            }

            @Test func `nestedUnkeyedContainer past end`() throws {
                try expectJSONString(
                    """
                    ["only"]
                    """,
                    decodingAs: AsksForNestedUnkeyedContainerAtEnd.self,
                    validator: DecodingErrorValidator.valueNotFound(
                        expectedType: UnkeyedDecodingContainer.self,
                        codingPath: ["Index 1"],
                        debugDescription: "Unkeyed container is at end."
                    )
                )
            }

            @Test func `superDecoder past end`() throws {
                try expectJSONString(
                    """
                    ["only"]
                    """,
                    decodingAs: AsksForSuperDecoderAtEnd.self,
                    validator: DecodingErrorValidator.valueNotFound(
                        expectedType: Decoder.self,
                        codingPath: ["Index 1"],
                        debugDescription: "Cannot get superDecoder() -- unkeyed container is at end."
                    )
                )
            }
        }

        @Test
        func `found null instead of keyed container`() throws {
            try expectJSONString(
                """
                [
                    {
                        "values": null,
                    }
                ]
                """,
                decodingAs: [[String: [String: Date]]].self,
                validator: DecodingErrorValidator.valueNotFound(
                    expectedType: [String: Any].self,
                    codingPath: ["Index 0", "values"],
                    debugDescription: "Cannot get keyed decoding container -- found null value instead"
                )
            )
        }

        @Test func `found null instead of unkeyed container`() throws {
            try expectJSONString(
                """
                [
                    ["a-string", "b-string"],
                    null   
                ]
                """,
                decodingAs: [TwoUnkeyedOf<String>].self,
                validator: DecodingErrorValidator.valueNotFound(
                    expectedType: [Any].self,
                    codingPath: ["Index 1"],
                    debugDescription: "Cannot get unkeyed decoding container -- found null value instead"
                )
            )
        }
    }

    @Suite struct DataCorrupted {
        @Test func `invalid JSON`() throws {
            // Invalid JSON (missing value before comma)
            try expectJSONString(
                """
                {"a": ,}
                """,
                decodingAs: [String: Int].self,
                validator: DecodingErrorValidator.dataCorrupted(
                    codingPath: [],
                    debugDescription: "The given data was not valid JSON."
                )
            )
        }

        @Test func `ISO 8601 Date`() throws {
            try expectJSONString(
                """
                { "date": "Tuesday" }
                """,
                decodingAs: [String: Date].self,
                updatingDecoder: {
                    $0.dateDecodingStrategy = .iso8601
                },
                validator: DecodingErrorValidator.dataCorrupted(
                    codingPath: [],
                    debugDescription: "Expected date string to be ISO8601-formatted, but found 'Tuesday'."
                )
            )
        }

        @Test func intForURL() throws {
            try expectJSONString(
                """
                { "url": "" }
                """,
                decodingAs: [String: URL].self,
                validator: DecodingErrorValidator.dataCorrupted(
                    codingPath: ["url"],
                    debugDescription: "Invalid URL string."
                )
            )
        }
    }
}

// MARK: - Helpers

@discardableResult
private func expectJSONString<Value: Decodable>(
    _ string: String,
    decodingAs _: Value.Type,
    updatingDecoder updateDecoder: (JSONDecoder) -> Void = { _ in },
    validator: DecodingErrorValidator.Validator,
    sourceLocation: SourceLocation = #_sourceLocation
) throws -> DecodingError {
    let jsonData = Data(string.utf8)

    let decoder = JSONDecoder()
    updateDecoder(decoder)

    let error = #expect(throws: DecodingError.self, sourceLocation: sourceLocation) {
        _ = try decoder.decode(Value.self, from: jsonData)
    }

    let unwrappedError = try #require(error, sourceLocation: sourceLocation)

    _ = validator(unwrappedError)

    return unwrappedError
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
