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

struct EnumCodingPathTests {
    enum Backend: CaseIterable, Sendable {
        case parser
        case primitive
    }

    enum Component: Equatable {
        case key(String)
        case integer(Int)
        case index(Int)
    }

    static func components(of path: CodingPath) -> [Component] {
        path.components.map {
            switch $0 {
            case .stringKey(let key): .key(key)
            case .integerKey(let key): .integer(key)
            case .index(let index): .index(index)
            }
        }
    }

    static func decode<T: JSONDecodable>(
        _ type: T.Type,
        from json: String,
        backend: Backend
    ) throws -> T {
        let data = Data(json.utf8)
        switch backend {
        case .parser:
            return try NewJSONDecoder().decode(type, from: data)
        case .primitive:
            let primitive = try NewJSONDecoder().decode(JSONPrimitive.self, from: data)
            var decoder = JSONPrimitiveDecoder(value: primitive)
            return try decoder.decode(type)
        }
    }

    struct EnumCapture: JSONDecodable {
        var entryPath: [Component] = []
        var valuePaths: [[Component]] = []
        var values: [Int] = []

        static func decode<D: JSONDecoderProtocol & ~Escapable>(
            from decoder: inout D
        ) throws(CodingError.Decoding) -> Self {
            var result = Self()
            try decoder.decodeEnumCase { field throws(CodingError.Decoding) in
                let matches = field.matches("case")
                #expect(matches)
            } associatedValues: { associated throws(CodingError.Decoding) in
                result.entryPath = EnumCodingPathTests.components(of: associated.codingPath)
                try associated.decodeEachKeyAndValue { _, value throws(CodingError.Decoding) in
                    result.valuePaths.append(EnumCodingPathTests.components(of: value.codingPath))
                    result.values.append(try value.decode(Int.self))
                    return false
                }
            }
            return result
        }
    }

    struct FirstValueCapture: JSONDecodable {
        var entryPath: [Component] = []
        var firstPath: [Component] = []
        var firstValue: Int?

        static func decode<D: JSONDecoderProtocol & ~Escapable>(
            from decoder: inout D
        ) throws(CodingError.Decoding) -> Self {
            var result = Self()
            try decoder.decodeEnumCase { field throws(CodingError.Decoding) in
                let matches = field.matches("case")
                #expect(matches)
            } associatedValues: { associated throws(CodingError.Decoding) in
                result.entryPath = EnumCodingPathTests.components(of: associated.codingPath)
                try associated.decodeEachKeyAndValue { _, value throws(CodingError.Decoding) in
                    result.firstPath = EnumCodingPathTests.components(of: value.codingPath)
                    result.firstValue = try value.decode(Int.self)
                    return true
                }
            }
            return result
        }
    }

    struct OuterCapture: JSONDecodable {
        var enums: [EnumCapture] = []
        var first: FirstValueCapture?
        var afterPath: [Component] = []
        var afterValue: Int?

        static func decode<D: JSONDecoderProtocol & ~Escapable>(
            from decoder: inout D
        ) throws(CodingError.Decoding) -> Self {
            var result = Self()
            try decoder.decodeStruct { object throws(CodingError.Decoding) in
                try object.decodeEachKeyAndValue { key, value throws(CodingError.Decoding) in
                    switch key {
                    case "items":
                        try value.decodeArray { array throws(CodingError.Decoding) in
                            try array.decodeEachElement { element throws(CodingError.Decoding) in
                                result.enums.append(try element.decode(EnumCapture.self))
                            }
                        }
                    case "first":
                        result.first = try value.decode(FirstValueCapture.self)
                    case "after":
                        result.afterPath = EnumCodingPathTests.components(of: value.codingPath)
                        result.afterValue = try value.decode(Int.self)
                    default:
                        break
                    }
                    return false
                }
            }
            return result
        }
    }

    struct NestedEnumCapture: JSONDecodable {
        var inner: EnumCapture?

        static func decode<D: JSONDecoderProtocol & ~Escapable>(
            from decoder: inout D
        ) throws(CodingError.Decoding) -> Self {
            var result = Self()
            try decoder.decodeEnumCase { field throws(CodingError.Decoding) in
                let matches = field.matches("case")
                #expect(matches)
            } associatedValues: { associated throws(CodingError.Decoding) in
                try associated.decodeEachKeyAndValue { _, value throws(CodingError.Decoding) in
                    result.inner = try value.decode(EnumCapture.self)
                    return false
                }
            }
            return result
        }
    }

    struct ErrorCapture: JSONDecodable {
        static func decode<D: JSONDecoderProtocol & ~Escapable>(
            from decoder: inout D
        ) throws(CodingError.Decoding) -> Self {
            let originalPath = EnumCodingPathTests.components(of: decoder.codingPath)
            do {
                try decoder.decodeEnumCase { field throws(CodingError.Decoding) in
                    let matches = field.matches("case")
                    #expect(matches)
                } associatedValues: { associated throws(CodingError.Decoding) in
                    try associated.decodeEachKeyAndValue { _, value throws(CodingError.Decoding) in
                        _ = try value.decode(Int.self)
                        return false
                    }
                }
            } catch {
                let restoredPath = EnumCodingPathTests.components(of: decoder.codingPath)
                #expect(restoredPath == originalPath)
                throw error
            }
            return Self()
        }
    }

    @Test(arguments: Backend.allCases)
    func associatedFieldsKeepCaseParent(backend: Backend) throws {
        let result = try Self.decode(
            EnumCapture.self,
            from: #"{"case":{"value":1}}"#,
            backend: backend
        )
        #expect(result.entryPath == [.key("case")])
        #expect(result.valuePaths == [[.key("case"), .key("value")]])
        #expect(result.values == [1])
    }

    @Test(arguments: Backend.allCases)
    func escapedCaseKeepsDecodedParent(backend: Backend) throws {
        let result = try Self.decode(
            EnumCapture.self,
            from: #"{"c\u0061se":{"value":1}}"#,
            backend: backend
        )
        #expect(result.entryPath == [.key("case")])
        #expect(result.valuePaths == [[.key("case"), .key("value")]])
    }

    @Test(arguments: Backend.allCases)
    func nestedArrayAndObjectPrefixesRemain(backend: Backend) throws {
        let result = try Self.decode(
            OuterCapture.self,
            from: #"{"items":[{"case":{"value":1}},{"case":{"value":2}}],"after":3}"#,
            backend: backend
        )
        #expect(result.enums.map(\.entryPath) == [
            [.key("items"), .index(0), .key("case")],
            [.key("items"), .index(1), .key("case")],
        ])
        #expect(result.enums.map(\.valuePaths) == [
            [[.key("items"), .index(0), .key("case"), .key("value")]],
            [[.key("items"), .index(1), .key("case"), .key("value")]],
        ])
        #expect(result.enums.map(\.values) == [[1], [2]])
        #expect(result.afterPath == [.key("after")])
        #expect(result.afterValue == 3)
    }

    @Test(arguments: Backend.allCases)
    func nestedEnumsKeepBothCaseParents(backend: Backend) throws {
        let result = try Self.decode(
            NestedEnumCapture.self,
            from: #"{"case":{"nested":{"case":{"value":1}}}}"#,
            backend: backend
        )
        let inner = try #require(result.inner)
        #expect(inner.entryPath == [.key("case"), .key("nested"), .key("case")])
        #expect(inner.valuePaths == [[.key("case"), .key("nested"), .key("case"), .key("value")]])
        #expect(inner.values == [1])
    }

    @Test(arguments: Backend.allCases)
    func finishingAssociatedValuesLeavesOuterSibling(backend: Backend) throws {
        let result = try Self.decode(
            FirstValueCapture.self,
            from: #"{"case":{"value":1,"ignored":2}}"#,
            backend: backend
        )
        #expect(result.entryPath == [.key("case")])
        #expect(result.firstPath == [.key("case"), .key("value")])
        #expect(result.firstValue == 1)

        let outer = try Self.decode(
            OuterCapture.self,
            from: #"{"first":{"case":{"value":1,"ignored":2}},"after":3}"#,
            backend: backend
        )
        let first = try #require(outer.first)
        #expect(first.entryPath == [.key("first"), .key("case")])
        #expect(first.firstPath == [.key("first"), .key("case"), .key("value")])
        #expect(first.firstValue == 1)
        #expect(outer.afterPath == [.key("after")])
        #expect(outer.afterValue == 3)
    }

    @Test(arguments: Backend.allCases)
    func emptyAssociatedObjectKeepsCasePath(backend: Backend) throws {
        let result = try Self.decode(
            EnumCapture.self,
            from: #"{"case":{}}"#,
            backend: backend
        )
        #expect(result.entryPath == [.key("case")])
        #expect(result.valuePaths.isEmpty)
        #expect(result.values.isEmpty)
    }

    @Test
    func parserErrorIncludesCaseParent() throws {
        do {
            _ = try Self.decode(
                ErrorCapture.self,
                from: #"{"case":{"value":"not-an-int"}}"#,
                backend: .parser
            )
            Issue.record("Expected a type mismatch")
        } catch let error as CodingError.Decoding {
            let codingPath = try #require(error.codingPath)
            #expect(Self.components(of: codingPath) == [.key("case"), .key("value")])
        }
    }

    @Test
    func malformedOuterWrapperUsesEnumPath() throws {
        do {
            _ = try Self.decode(
                EnumCapture.self,
                from: #"{"case":{"value":1} "after":2}"#,
                backend: .parser
            )
            Issue.record("Expected malformed outer object to throw")
        } catch let error as CodingError.Decoding {
            let codingPath = try #require(error.codingPath)
            #expect(Self.components(of: codingPath) == [.key("case")])
        }
    }
}
