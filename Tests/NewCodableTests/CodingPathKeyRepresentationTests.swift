//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing
#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif FOUNDATION_FRAMEWORK
import Foundation
#endif
import NewCodable

struct CodingPathKeyRepresentationTests {
    static let combinedEscapedKey = "slash/\u{08}\u{0C}\n\r\t"

    struct KeyCase: Sendable {
        let json: String
        let expected: String
    }

    static let cases: [KeyCase] = [
        .init(json: #"{"name": 1}"#, expected: "name"),
        .init(json: #"{"café": 1}"#, expected: "café"),
        .init(json: #"{"n\u0061me": 1}"#, expected: "name"),
        .init(json: #"{"quo\"te": 1}"#, expected: "quo\"te"),
        .init(json: #"{"slash\\key": 1}"#, expected: "slash\\key"),
        .init(json: #"{"slash\/\b\f\n\r\t": 1}"#, expected: combinedEscapedKey),
        .init(json: #"{"": 1}"#, expected: ""),
        .init(json: #"{"\uD83D\uDE80": 1}"#, expected: "🚀"),
    ]

    enum PathComponent: Equatable {
        case string(String)
        case integer(Int)
        case index(Int)
    }

    static func pathComponents(of path: CodingPath) -> [PathComponent] {
        path.components.map { component in
            switch component {
            case .stringKey(let key): .string(key)
            case .integerKey(let key): .integer(key)
            case .index(let index): .index(index)
            }
        }
    }

    struct Capture: JSONDecodable {
        var keys: [String] = []
        var pathKeys: [String] = []

        static func decode<D: JSONDecoderProtocol & ~Escapable>(
            from decoder: inout D
        ) throws(CodingError.Decoding) -> Self {
            var result = Self()
            try decoder.decodeStruct { object throws(CodingError.Decoding) in
                try object.decodeEachKeyAndValue { key, value throws(CodingError.Decoding) in
                    result.keys.append(key)
                    for component in value.codingPath.components {
                        if case .stringKey(let pathKey) = component {
                            result.pathKeys.append(pathKey)
                        }
                    }
                    _ = try value.decode(Int.self)
                    return false
                }
            }
            return result
        }
    }

    @Test(arguments: cases)
    func parserUsesSemanticKeys(testCase: KeyCase) throws {
        let result = try NewJSONDecoder().decode(Capture.self, from: Data(testCase.json.utf8))
        #expect(result.keys == [testCase.expected])
        #expect(result.pathKeys == [testCase.expected])
    }

    @Test(arguments: cases)
    func primitiveUsesSemanticKeys(testCase: KeyCase) throws {
        let value = try NewJSONDecoder().decode(JSONPrimitive.self, from: Data(testCase.json.utf8))
        var decoder = JSONPrimitiveDecoder(value: value)
        let result = try decoder.decode(Capture.self)
        #expect(result.keys == [testCase.expected])
        #expect(result.pathKeys == [testCase.expected])
    }

    @Test
    func decodeEachFieldUsesSemanticKeyAfterFieldCallbackReturns() throws {
        struct FieldCapture: JSONDecodable {
            let path: [PathComponent]

            static func decode<D: JSONDecoderProtocol & ~Escapable>(
                from decoder: inout D
            ) throws(CodingError.Decoding) -> Self {
                var path: [PathComponent] = []
                try decoder.decodeStruct { object throws(CodingError.Decoding) in
                    try object.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                        let matches = fieldDecoder.matches("slash/\u{08}\u{0C}\n\r\t")
                        #expect(matches)
                    } andValue: { valueDecoder throws(CodingError.Decoding) in
                        path = CodingPathKeyRepresentationTests.pathComponents(of: valueDecoder.codingPath)
                        _ = try valueDecoder.decode(Int.self)
                    }
                }
                return Self(path: path)
            }
        }

        let json = #"{"slash\/\b\f\n\r\t": 1}"#
        let result = try NewJSONDecoder().decode(FieldCapture.self, from: Data(json.utf8))
        #expect(result.path == [.string(Self.combinedEscapedKey)])
    }

    @Test
    func decodeEnumCaseReportsSemanticCaseKeyBeforeAssociatedFields() throws {
        struct EnumCapture: JSONDecodable {
            let path: [PathComponent]

            static func decode<D: JSONDecoderProtocol & ~Escapable>(
                from decoder: inout D
            ) throws(CodingError.Decoding) -> Self {
                var path: [PathComponent] = []
                try decoder.decodeEnumCase { fieldDecoder throws(CodingError.Decoding) in
                    let matches = fieldDecoder.matches("slash/\u{08}\u{0C}\n\r\t")
                    #expect(matches)
                } associatedValues: { valuesDecoder throws(CodingError.Decoding) in
                    path = CodingPathKeyRepresentationTests.pathComponents(of: valuesDecoder.codingPath)
                }
                return Self(path: path)
            }
        }

        let json = #"{"slash\/\b\f\n\r\t":{}}"#
        let result = try NewJSONDecoder().decode(EnumCapture.self, from: Data(json.utf8))
        #expect(result.path == [.string(Self.combinedEscapedKey)])
    }

    @Test
    func nestedObjectArrayErrorReportsSemanticPathComponents() throws {
        struct NestedFailure: JSONDecodable {
            static func decode<D: JSONDecoderProtocol & ~Escapable>(
                from decoder: inout D
            ) throws(CodingError.Decoding) -> Self {
                try decoder.decodeStruct { root throws(CodingError.Decoding) in
                    try root.decodeEachKeyAndValue { _, valueDecoder throws(CodingError.Decoding) in
                        try valueDecoder.decodeStruct { object throws(CodingError.Decoding) in
                            try object.decodeEachKeyAndValue { _, valueDecoder throws(CodingError.Decoding) in
                                try valueDecoder.decodeArray { array throws(CodingError.Decoding) in
                                    try array.decodeEachElement { element throws(CodingError.Decoding) in
                                        try element.decodeStruct { item throws(CodingError.Decoding) in
                                            try item.decodeEachKeyAndValue { _, valueDecoder throws(CodingError.Decoding) in
                                                _ = try valueDecoder.decode(Int.self)
                                                return false
                                            }
                                        }
                                    }
                                }
                                return false
                            }
                        }
                        return false
                    }
                }
                return Self()
            }
        }

        let json = #"{"outer\/\b\f\n\r\t":{"items\/\b\f\n\r\t":[{"leaf\/\b\f\n\r\t":"not-an-int"}]}}"#
        do {
            _ = try NewJSONDecoder().decode(NestedFailure.self, from: Data(json.utf8))
            Issue.record("Expected nested decode to throw")
        } catch {
            let codingPath = try #require(error.codingPath)
            #expect(CodingPathKeyRepresentationTests.pathComponents(of: codingPath) == [
                .string("outer/\u{08}\u{0C}\n\r\t"),
                .string("items/\u{08}\u{0C}\n\r\t"),
                .index(0),
                .string("leaf/\u{08}\u{0C}\n\r\t"),
            ])
        }
    }

    @Test
    func optimizedExpectedOrderFieldReportsPlainKey() throws {
        struct OrderedCapture: JSONDecodable {
            let path: [PathComponent]

            enum Field: JSONOptimizedDecodingField {
                case name

                var staticString: StaticString { "name" }

                static func field(for key: UTF8Span) throws(CodingError.Decoding) -> Self {
                    switch UTF8SpanComparator(key) {
                    case "name": .name
                    default: throw CodingError.unknownKey(key)
                    }
                }
            }

            static func decode<D: JSONDecoderProtocol & ~Escapable>(
                from decoder: inout D
            ) throws(CodingError.Decoding) -> Self {
                var path: [PathComponent] = []
                try decoder.decodeStruct { object throws(CodingError.Decoding) in
                    var inOrder = true
                    try object.decodeExpectedOrderField(Field.name, inOrder: &inOrder) {
                        valueDecoder throws(CodingError.Decoding) in
                        path = CodingPathKeyRepresentationTests.pathComponents(of: valueDecoder.codingPath)
                        _ = try valueDecoder.decode(Int.self)
                    }
                    #expect(inOrder)
                }
                return Self(path: path)
            }
        }

        let json = #"{"name":1}"#
        let result = try NewJSONDecoder().decode(OrderedCapture.self, from: Data(json.utf8))
        #expect(result.path == [.string("name")])
    }
}
