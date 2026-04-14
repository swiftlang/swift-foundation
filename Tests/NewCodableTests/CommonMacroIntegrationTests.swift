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

@CommonEncodable
struct CommonSimplePost {
    let title: String
    let body: String
}

@CommonEncodable
struct CommonBlogPost {
    let title: String
    @CodingKey("date_published") let publishDate: String
    let tags: [String]
    let rating: Double?
}

@CommonEncodable
struct CommonEmptyEncodable {}

@CommonCodable
struct CommonRoundTripPerson {
    let name: String
    let age: Int
}

@CommonCodable
struct CommonRoundTripPost {
    let title: String
    @CodingKey("date_published") let publishDate: String
    let rating: Double?
}

@CommonDecodable
struct CommonDecodableOnly {
    let name: String
    let value: Int
}

@CommonDecodable
struct CommonDecodableOnlyWithRequiredCustomKey {
    @CodingKey("date_published") let publishDate: String
}

@CommonDecodable
struct CommonEmptyDecodable {}

@CommonCodable
struct CommonCodablePerson {
    let name: String
    let age: Int
}

@CommonCodable
struct CommonCodablePost {
    let title: String
    @CodingKey("date_published") let publishDate: String
    let rating: Double?
}

@CommonCodable
struct CommonCodableStructWithDefaultedProperty {
    @CodableDefault("hello")
    let bar: String
}

// Public types exercise access-level propagation in the generated extensions.

@CommonEncodable
public struct PublicCommonEncodablePerson {
    public var name: String

    public init(name: String) {
        self.name = name
    }
}

@CommonDecodable
public struct PublicCommonDecodablePerson {
    public var name: String
}

@CommonCodable
public struct PublicCommonCodablePerson {
    public var name: String

    public init(name: String) {
        self.name = name
    }
}


struct CommonCodableStructWithAliasedProperty {
    @DecodableAlias("baz", "qux")
    let bar: String
}

extension CommonCodableStructWithAliasedProperty {
    enum CodingFields: StaticStringCodingField {
        case bar
        case unknown
        
        @_transparent
        var staticString: StaticString {
            switch self {
            case .bar:
                "bar"
            case .unknown:
                fatalError()
            }
        }
        
        static func field(for key: UTF8Span) throws(CodingError.Decoding) -> CodingFields {
            switch UTF8SpanComparator(key) {
            case "bar":
                    .bar
            case "baz":
                    .bar
            case "qux":
                    .bar
            default:
                    .unknown
            }
        }
    }
}

extension CommonCodableStructWithAliasedProperty: CommonEncodable {
    func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeStructFields(count: 1) { structEncoder throws(CodingError.Encoding) in
            try structEncoder.encode(field: CodingFields.bar, value: self.bar)
        }
    }
}

extension CommonCodableStructWithAliasedProperty: CommonDecodable {
    static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> CommonCodableStructWithAliasedProperty {
        try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
            var bar: String?
            var _codingField: CodingFields?
            try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                _codingField = try fieldDecoder.decode(CodingFields.self)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                switch _codingField! {
                case .bar:
                    bar = try valueDecoder.decode(String.self)
                case .unknown:
                    break
                }
            }
            guard let bar else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required field 'bar'")
            }
            return CommonCodableStructWithAliasedProperty(bar: bar)
        }
    }
}


@Suite("@CommonEncodable Macro Integration")
struct CommonEncodableMacroIntegrationTests {

    @Test func simpleStruct() throws {
        let post = CommonSimplePost(title: "Hello", body: "World")
        let data = try NewJSONEncoder().encode(post)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"title\":\"Hello\""))
        #expect(json.contains("\"body\":\"World\""))
    }

    @Test func customCodingKey() throws {
        let post = CommonBlogPost(title: "Test", publishDate: "2026-01-01", tags: ["swift"], rating: 4.5)
        let data = try NewJSONEncoder().encode(post)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"date_published\":\"2026-01-01\""))
        #expect(json.contains("\"title\":\"Test\""))
        #expect(json.contains("\"tags\":[\"swift\"]"))
        #expect(json.contains("\"rating\":4.5"))
    }

    @Test func optionalNilValue() throws {
        let post = CommonBlogPost(title: "Test", publishDate: "2026-01-01", tags: [], rating: nil)
        let data = try NewJSONEncoder().encode(post)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"rating\":null"))
    }

    @Test func emptyStruct() throws {
        let empty = CommonEmptyEncodable()
        let data = try NewJSONEncoder().encode(empty)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == "{}")
    }
}

@Suite("@CommonDecodable Macro Integration")
struct CommonDecodableMacroIntegrationTests {

    @Test func roundTripBasic() throws {
        let original = CommonRoundTripPerson(name: "Alice", age: 30)
        let data = try NewJSONEncoder().encode(original)
        let decoded = try NewJSONDecoder().decode(CommonRoundTripPerson.self, from: data)
        #expect(decoded.name == "Alice")
        #expect(decoded.age == 30)
    }

    @Test func roundTripCustomCodingKey() throws {
        let original = CommonRoundTripPost(title: "Hello", publishDate: "2026-01-01", rating: 4.5)
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"date_published\":\"2026-01-01\""))
        let decoded = try NewJSONDecoder().decode(CommonRoundTripPost.self, from: data)
        #expect(decoded.title == "Hello")
        #expect(decoded.publishDate == "2026-01-01")
        #expect(decoded.rating == 4.5)
    }

    @Test func roundTripOptionalNil() throws {
        let original = CommonRoundTripPost(title: "Test", publishDate: "2026-03-05", rating: nil)
        let data = try NewJSONEncoder().encode(original)
        let decoded = try NewJSONDecoder().decode(CommonRoundTripPost.self, from: data)
        #expect(decoded.title == "Test")
        #expect(decoded.rating == nil)
    }

    @Test func decodeOnly() throws {
        let json = Data(#"{"name":"Bob","value":42}"#.utf8)
        let decoded = try NewJSONDecoder().decode(CommonDecodableOnly.self, from: json)
        #expect(decoded.name == "Bob")
        #expect(decoded.value == 42)
    }

    @Test func missingRequiredFieldErrorIncludesCustomKeyName() {
        let json = Data("{}".utf8)

        let error = #expect(throws: CodingError.Decoding.self) {
            try NewJSONDecoder().decode(CommonDecodableOnlyWithRequiredCustomKey.self, from: json)
        }
        guard case .dataCorrupted = error?.kind else {
            Issue.record("Unexpected CodingError.Decoding type: \(error)")
            return
        }
        #expect(error.debugDescription.contains("Missing required field 'date_published'"))
    }

    @Test func emptyDecodable() throws {
        let json = Data("{}".utf8)
        let decoded = try NewJSONDecoder().decode(CommonEmptyDecodable.self, from: json)
        _ = decoded
    }
}

@CommonCodable
enum CommonSimpleStatus: Equatable {
    case active
    case inactive
}

@CommonCodable
enum CommonTaskStatus: Equatable {
    @CodingKey("in_progress") case inProgress
    case done
}

@CommonCodable
enum CommonFlexibleStatus: Equatable {
    @DecodableAlias("in-progress") @CodingKey("in_progress") case inProgress
    case done
}

@CommonCodable
enum CommonShape: Equatable {
    case circle(radius: Double)
    case point
}

@CommonCodable
enum CommonWrapper: Equatable {
    case single(Int)
    case pair(String, Int)
}

@Suite("@CommonCodable Macro Integration")
struct CommonCodableMacroIntegrationTests {

    @Test func roundTrip() throws {
        let original = CommonCodablePerson(name: "Alice", age: 30)
        let data = try NewJSONEncoder().encode(original)
        let decoded = try NewJSONDecoder().decode(CommonCodablePerson.self, from: data)
        #expect(decoded.name == "Alice")
        #expect(decoded.age == 30)
    }

    @Test func roundTripWithCustomKey() throws {
        let original = CommonCodablePost(title: "Hello", publishDate: "2026-01-01", rating: 4.5)
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"date_published\":\"2026-01-01\""))
        let decoded = try NewJSONDecoder().decode(CommonCodablePost.self, from: data)
        #expect(decoded.title == "Hello")
        #expect(decoded.publishDate == "2026-01-01")
        #expect(decoded.rating == 4.5)
    }

    @Test func roundTripOptionalNil() throws {
        let original = CommonCodablePost(title: "Test", publishDate: "2026-03-10", rating: nil)
        let data = try NewJSONEncoder().encode(original)
        let decoded = try NewJSONDecoder().decode(CommonCodablePost.self, from: data)
        #expect(decoded.title == "Test")
        #expect(decoded.rating == nil)
    }

    @Test func enumWithoutAssociatedValues() throws {
        let original = CommonSimpleStatus.active
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"active\""))
        let decoded = try NewJSONDecoder().decode(CommonSimpleStatus.self, from: data)
        #expect(decoded == original)

        let inactive = CommonSimpleStatus.inactive
        let data2 = try NewJSONEncoder().encode(inactive)
        let decoded2 = try NewJSONDecoder().decode(CommonSimpleStatus.self, from: data2)
        #expect(decoded2 == inactive)
    }

    @Test func enumWithCodingKey() throws {
        let original = CommonTaskStatus.inProgress
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"in_progress\""))
        #expect(!json.contains("\"inProgress\""))
        let decoded = try NewJSONDecoder().decode(CommonTaskStatus.self, from: data)
        #expect(decoded == original)
    }

    @Test func enumWithDecodableAlias() throws {
        let original = CommonFlexibleStatus.inProgress
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"in_progress\""))

        // Decode using the alias key
        let aliasJSON = Data(#"{"in-progress":{}}"#.utf8)
        let decoded = try NewJSONDecoder().decode(CommonFlexibleStatus.self, from: aliasJSON)
        #expect(decoded == .inProgress)
    }

    @Test func enumWithLabeledAssociatedValues() throws {
        let circle = CommonShape.circle(radius: 3.14)
        let data = try NewJSONEncoder().encode(circle)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"circle\""))
        #expect(json.contains("\"radius\""))
        let decoded = try NewJSONDecoder().decode(CommonShape.self, from: data)
        #expect(decoded == circle)

        let point = CommonShape.point
        let data2 = try NewJSONEncoder().encode(point)
        let decoded2 = try NewJSONDecoder().decode(CommonShape.self, from: data2)
        #expect(decoded2 == point)
    }

    @Test func enumWithUnlabeledAssociatedValues() throws {
        let single = CommonWrapper.single(42)
        let data = try NewJSONEncoder().encode(single)
        let decoded = try NewJSONDecoder().decode(CommonWrapper.self, from: data)
        #expect(decoded == single)

        let pair = CommonWrapper.pair("hello", 99)
        let data2 = try NewJSONEncoder().encode(pair)
        let decoded2 = try NewJSONDecoder().decode(CommonWrapper.self, from: data2)
        #expect(decoded2 == pair)
    }
}
