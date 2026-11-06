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

private struct EnumPathCapture: JSONDecodable {
    let associatedPath: String
    let valuePaths: [String]
    let values: [Int]
    let restoredPath: String

    static func decode<D: JSONDecoderProtocol & ~Escapable>(
        from decoder: inout D
    ) throws(CodingError.Decoding) -> Self {
        var associatedPath = ""
        var valuePaths: [String] = []
        var values: [Int] = []

        try decoder.decodeEnumCase { field throws(CodingError.Decoding) in
            let matches = field.matches("payload")
            #expect(matches)
        } associatedValues: { associatedValues throws(CodingError.Decoding) in
            associatedPath = associatedValues.codingPath.description
            try associatedValues.decodeEachKeyAndValue { key, value throws(CodingError.Decoding) in
                valuePaths.append(value.codingPath.description)
                switch key {
                case "first", "second", "stop":
                    values.append(try value.decode(Int.self))
                case "detail":
                    _ = try value.decode(NestedObject.self)
                case "nested":
                    _ = try value.decode(Self.self)
                case "items":
                    _ = try value.decode([Int].self)
                default:
                    // Unknown associated fields are deliberately skipped.
                    break
                }
                return key == "stop"
            }
        }

        return Self(associatedPath: associatedPath, valuePaths: valuePaths, values: values,
                    restoredPath: decoder.codingPath.description)
    }
}

private struct NestedObject: JSONDecodable {
    static func decode<D: JSONDecoderProtocol & ~Escapable>(
        from decoder: inout D
    ) throws(CodingError.Decoding) -> Self {
        try decoder.decodeStruct { fields throws(CodingError.Decoding) in
            try fields.decodeEachKeyAndValue { key, value throws(CodingError.Decoding) in
                if key == "count" {
                    _ = try value.decode(Int.self)
                }
                return false
            }
            return Self()
        }
    }
}

private struct OrdinaryStructPathCapture: JSONDecodable {
    let valuePath: String

    static func decode<D: JSONDecoderProtocol & ~Escapable>(
        from decoder: inout D
    ) throws(CodingError.Decoding) -> Self {
        var valuePath = ""
        try decoder.decodeStruct { fields throws(CodingError.Decoding) in
            try fields.decodeEachKeyAndValue { _, value throws(CodingError.Decoding) in
                valuePath = value.codingPath.description
                _ = try value.decode(Int.self)
                return false
            }
        }
        return Self(valuePath: valuePath)
    }
}

private func decode<T: JSONDecodable>(
    _ type: T.Type,
    from json: String,
    withPrimitiveDecoder: Bool
) throws -> T {
    let data = Data(json.utf8)
    let parser = NewJSONDecoder()
    if withPrimitiveDecoder {
        let value = try parser.decode(JSONPrimitive.self, from: data)
        var decoder = JSONPrimitiveDecoder(value: value)
        return try decoder.decode(type)
    }
    return try parser.decode(type, from: data)
}

struct EnumCodingPathTests {
    @Test(arguments: [false, true])
    func retainsCasePathAndSiblingPaths(withPrimitiveDecoder: Bool) throws {
        let result = try decode(
            EnumPathCapture.self,
            from: #"{"payload":{"first":1,"unknown":true,"second":2}}"#,
            withPrimitiveDecoder: withPrimitiveDecoder
        )

        #expect(result.associatedPath == "payload")
        #expect(result.valuePaths == ["payload.first", "payload.unknown", "payload.second"])
        #expect(result.values == [1, 2])
        #expect(result.restoredPath.isEmpty)
    }

    @Test(arguments: [false, true])
    func retainsCasePathForEmptyAssociatedObject(withPrimitiveDecoder: Bool) throws {
        let result = try decode(
            EnumPathCapture.self,
            from: #"{"payload":{}}"#,
            withPrimitiveDecoder: withPrimitiveDecoder
        )

        #expect(result.associatedPath == "payload")
        #expect(result.valuePaths.isEmpty)
    }

    @Test(arguments: [false, true], [
        (#"{"payload":{"first":false}}"#, "payload.first"),
        (#"{"payload":{"detail":{"count":false}}}"#, "payload.detail.count"),
        (#"{"payload":{"items":[1,false]}}"#, "payload.items[1]"),
        (#"{"payload":{"nested":{"payload":{"first":false}}}}"#, "payload.nested.payload.first"),
    ])
    func reportsTypeErrorAtFullPath(withPrimitiveDecoder: Bool, example: (String, String)) throws {
        do {
            _ = try decode(EnumPathCapture.self, from: example.0, withPrimitiveDecoder: withPrimitiveDecoder)
            Issue.record("Expected a type mismatch")
        } catch let error as CodingError.Decoding {
            let path = try #require(error.codingPath)
            #expect(path.description == example.1)
        }
    }

    @Test(arguments: [false, true])
    func restoresParentPathAndFinishesUnreadFields(withPrimitiveDecoder: Bool) throws {
        let result = try decode(
            [EnumPathCapture].self,
            from: #"[{"payload":{"stop":1,"unknown":{"items":[true]}}},{"payload":{"first":2}}]"#,
            withPrimitiveDecoder: withPrimitiveDecoder
        )

        #expect(result.map(\.valuePaths) == [["[0].payload.stop"], ["[1].payload.first"]])
        #expect(result.map(\.associatedPath) == ["[0].payload", "[1].payload"])
        #expect(result.map(\.restoredPath) == ["[0]", "[1]"])
        #expect(result.map(\.values) == [[1], [2]])
    }

    @Test(arguments: [false, true])
    func ordinaryStructPathRemainsUnchanged(withPrimitiveDecoder: Bool) throws {
        let result = try decode(
            OrdinaryStructPathCapture.self,
            from: #"{"value":1}"#,
            withPrimitiveDecoder: withPrimitiveDecoder
        )

        #expect(result.valuePath == "value")
    }

    @Test(arguments: [
        (#"{"payload":{"first":1},"#, "payload"),
        (#"{"payload":{"first":1},"other":{}}"#, "payload"),
        (#"{"payload":{"first":1 "second":2}}"#, "payload.first"),
        (#"{"payload":{"stop":1,"unknown":{"nested":?}}}"#, "payload.unknown.nested"),
    ])
    func parserReportsMalformedJSONAtFullPath(example: (String, String)) throws {
        do {
            _ = try decode(EnumPathCapture.self, from: example.0, withPrimitiveDecoder: false)
            Issue.record("Expected malformed JSON to fail")
        } catch let error as CodingError.Decoding {
            let path = try #require(error.codingPath)
            #expect(path.description == example.1)
        }
    }
}
