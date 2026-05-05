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


@CommonCodable
struct CommonCodableStructWithAliasedProperty {
    @DecodableAlias("baz", "qux")
    let bar: String
}


@Suite("@CommonEncodable Macro Integration")
struct CommonEncodableMacroIntegrationTests {

    @Test func simpleStruct() throws {
        let post = CommonSimplePost(title: "Hello", body: "World")
        let data = try NewJSONEncoder().encode(post)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"title":"Hello","body":"World"}"#)
    }

    @Test func customCodingKey() throws {
        let post = CommonBlogPost(title: "Test", publishDate: "2026-01-01", tags: ["swift"], rating: 4.5)
        let data = try NewJSONEncoder().encode(post)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"title":"Test","date_published":"2026-01-01","tags":["swift"],"rating":4.5}"#)
    }

    @Test func optionalNilValue() throws {
        let post = CommonBlogPost(title: "Test", publishDate: "2026-01-01", tags: [], rating: nil)
        let data = try NewJSONEncoder().encode(post)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"title":"Test","date_published":"2026-01-01","tags":[],"rating":null}"#)
    }

    @Test func emptyStruct() throws {
        let empty = CommonEmptyEncodable()
        let data = try NewJSONEncoder().encode(empty)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == "{}")
    }
}

// MARK: - @CodableBy with @CommonCodable Integration Tests

@CommonCodable
struct CommonCodableByISO8601Type: Equatable {
    @CodableBy(.dateFormat(.iso8601))
    let createdAt: Date
}

@CommonCodable
struct CommonCodableByBase64Type: Equatable {
    @CodableBy(.base64)
    let payload: Data
}

@Suite("@CodableBy with @CommonCodable Integration")
struct CommonCodableByIntegrationTests {

    @Test func iso8601RoundTrip() throws {
        let date = try Date.ISO8601FormatStyle().parse("2026-01-15T10:30:00Z")
        let original = CommonCodableByISO8601Type(createdAt: date)
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"createdAt":"2026-01-15T10:30:00Z"}"#)
        let decoded = try NewJSONDecoder().decode(CommonCodableByISO8601Type.self, from: data)
        #expect(decoded.createdAt == date)
    }

    @Test func base64RoundTrip() throws {
        let bytes = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let original = CommonCodableByBase64Type(payload: bytes)
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"payload":"3q2+7w=="}"#)
        let decoded = try NewJSONDecoder().decode(CommonCodableByBase64Type.self, from: data)
        #expect(decoded.payload == bytes)
    }
}

@Suite("@CommonDecodable Macro Integration")
struct CommonDecodableMacroIntegrationTests {

    @Test func roundTripBasic() throws {
        let original = CommonRoundTripPerson(name: "Alice", age: 30)
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"name":"Alice","age":30}"#)
        let decoded = try NewJSONDecoder().decode(CommonRoundTripPerson.self, from: data)
        #expect(decoded.name == "Alice")
        #expect(decoded.age == 30)
    }

    @Test func roundTripCustomCodingKey() throws {
        let original = CommonRoundTripPost(title: "Hello", publishDate: "2026-01-01", rating: 4.5)
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"title":"Hello","date_published":"2026-01-01","rating":4.5}"#)
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
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"name":"Alice","age":30}"#)
        let decoded = try NewJSONDecoder().decode(CommonCodablePerson.self, from: data)
        #expect(decoded.name == "Alice")
        #expect(decoded.age == 30)
    }

    @Test func roundTripWithCustomKey() throws {
        let original = CommonCodablePost(title: "Hello", publishDate: "2026-01-01", rating: 4.5)
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"title":"Hello","date_published":"2026-01-01","rating":4.5}"#)
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
        #expect(json == #"{"active":{}}"#)
        let decoded = try NewJSONDecoder().decode(CommonSimpleStatus.self, from: data)
        #expect(decoded == original)

        let inactive = CommonSimpleStatus.inactive
        let data2 = try NewJSONEncoder().encode(inactive)
        let json2 = String(data: data2, encoding: .utf8)!
        #expect(json2 == #"{"inactive":{}}"#)
        let decoded2 = try NewJSONDecoder().decode(CommonSimpleStatus.self, from: data2)
        #expect(decoded2 == inactive)
    }

    @Test func enumWithCodingKey() throws {
        let original = CommonTaskStatus.inProgress
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"in_progress":{}}"#)
        let decoded = try NewJSONDecoder().decode(CommonTaskStatus.self, from: data)
        #expect(decoded == original)
    }

    @Test func enumWithDecodableAlias() throws {
        let original = CommonFlexibleStatus.inProgress
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"in_progress":{}}"#)

        // Decode using the alias key
        let aliasJSON = Data(#"{"in-progress":{}}"#.utf8)
        let decoded = try NewJSONDecoder().decode(CommonFlexibleStatus.self, from: aliasJSON)
        #expect(decoded == .inProgress)
    }

    @Test func enumWithLabeledAssociatedValues() throws {
        let circle = CommonShape.circle(radius: 3.14)
        let data = try NewJSONEncoder().encode(circle)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"circle":{"radius":3.14}}"#)
        let decoded = try NewJSONDecoder().decode(CommonShape.self, from: data)
        #expect(decoded == circle)

        let point = CommonShape.point
        let data2 = try NewJSONEncoder().encode(point)
        let json2 = String(data: data2, encoding: .utf8)!
        #expect(json2 == #"{"point":{}}"#)
        let decoded2 = try NewJSONDecoder().decode(CommonShape.self, from: data2)
        #expect(decoded2 == point)
    }

    @Test func enumWithUnlabeledAssociatedValues() throws {
        let single = CommonWrapper.single(42)
        let data = try NewJSONEncoder().encode(single)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"single":{"_0":42}}"#)
        let decoded = try NewJSONDecoder().decode(CommonWrapper.self, from: data)
        #expect(decoded == single)

        let pair = CommonWrapper.pair("hello", 99)
        let data2 = try NewJSONEncoder().encode(pair)
        let json2 = String(data: data2, encoding: .utf8)!
        #expect(json2 == #"{"pair":{"_0":"hello","_1":99}}"#)
        let decoded2 = try NewJSONDecoder().decode(CommonWrapper.self, from: data2)
        #expect(decoded2 == pair)
    }
}
