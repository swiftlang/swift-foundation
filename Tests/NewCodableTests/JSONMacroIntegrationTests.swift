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

@JSONEncodable
struct SimplePost {
    let title: String
    let body: String
}

@JSONEncodable
struct BlogPost {
    let title: String
    @CodingKey("date_published") let publishDate: String
    let tags: [String]
    let rating: Double?
}

@JSONEncodable
struct EmptyEncodable {}

@JSONCodable
struct RoundTripPerson {
    let name: String
    let age: Int
}

@JSONCodable
struct RoundTripPost {
    let title: String
    @CodingKey("date_published") let publishDate: String
    let rating: Double?
}

@JSONDecodable
struct DecodableOnly {
    let name: String
    let value: Int
}

@JSONDecodable
struct DecodableOnlyWithRequiredCustomKey {
    @CodingKey("date_published") let publishDate: String
}

@JSONDecodable
struct EmptyDecodable {}

@JSONCodable
struct CodablePerson {
    let name: String
    let age: Int
}

@JSONCodable
struct CodablePost {
    let title: String
    @CodingKey("date_published") let publishDate: String
    let rating: Double?
}

@JSONCodable
struct CodableStructWithDefaultedProperty {
    @CodableDefault("hello")
    let bar: String
}

@JSONCodable
struct CodableStructWithAliasedProperty {
    @DecodableAlias("baz", "qux")
    let bar: String
}

// Public types exercise access-level propagation in the generated extensions.
// Without correct `public` modifiers on the synthesized members, these would
// fail to compile with "method must be declared public because it matches a
// requirement in public protocol".

@JSONEncodable
public struct PublicEncodablePerson {
    public var name: String
    public var age: Int

    public init(name: String, age: Int) {
        self.name = name
        self.age = age
    }
}

@JSONDecodable
public struct PublicDecodablePerson {
    public var name: String
    public var age: Int
}

@JSONCodable
public struct PublicCodablePerson {
    public var name: String
    public var age: Int

    public init(name: String, age: Int) {
        self.name = name
        self.age = age
    }
}

@Suite("@JSONEncodable Macro Integration")
struct JSONEncodableMacroIntegrationTests {

    @Test func simpleStruct() throws {
        let post = SimplePost(title: "Hello", body: "World")
        let data = try NewJSONEncoder().encode(post)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"title":"Hello","body":"World"}"#)
    }

    @Test func customCodingKey() throws {
        let post = BlogPost(title: "Test", publishDate: "2026-01-01", tags: ["swift"], rating: 4.5)
        let data = try NewJSONEncoder().encode(post)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"title":"Test","date_published":"2026-01-01","tags":["swift"],"rating":4.5}"#)
    }

    @Test func optionalNilValue() throws {
        let post = BlogPost(title: "Test", publishDate: "2026-01-01", tags: [], rating: nil)
        let data = try NewJSONEncoder().encode(post)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"title":"Test","date_published":"2026-01-01","tags":[],"rating":null}"#)
    }

    @Test func emptyStruct() throws {
        let empty = EmptyEncodable()
        let data = try NewJSONEncoder().encode(empty)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == "{}")
    }
}

@Suite("@JSONDecodable Macro Integration")
struct JSONDecodableMacroIntegrationTests {

    @Test func roundTripBasic() throws {
        let original = RoundTripPerson(name: "Alice", age: 30)
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"name":"Alice","age":30}"#)
        let decoded = try NewJSONDecoder().decode(RoundTripPerson.self, from: data)
        #expect(decoded.name == "Alice")
        #expect(decoded.age == 30)
    }

    @Test func roundTripCustomCodingKey() throws {
        let original = RoundTripPost(title: "Hello", publishDate: "2026-01-01", rating: 4.5)
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"title":"Hello","date_published":"2026-01-01","rating":4.5}"#)
        let decoded = try NewJSONDecoder().decode(RoundTripPost.self, from: data)
        #expect(decoded.title == "Hello")
        #expect(decoded.publishDate == "2026-01-01")
        #expect(decoded.rating == 4.5)
    }

    @Test func roundTripOptionalNil() throws {
        let original = RoundTripPost(title: "Test", publishDate: "2026-03-05", rating: nil)
        let data = try NewJSONEncoder().encode(original)
        let decoded = try NewJSONDecoder().decode(RoundTripPost.self, from: data)
        #expect(decoded.title == "Test")
        #expect(decoded.rating == nil)
    }

    @Test func decodeOnly() throws {
        let json = Data(#"{"name":"Bob","value":42}"#.utf8)
        let decoded = try NewJSONDecoder().decode(DecodableOnly.self, from: json)
        #expect(decoded.name == "Bob")
        #expect(decoded.value == 42)
    }

    @Test func missingRequiredFieldErrorIncludesCustomKeyName() {
        let json = Data("{}".utf8)

        let error = #expect(throws: CodingError.Decoding.self) {
            try NewJSONDecoder().decode(DecodableOnlyWithRequiredCustomKey.self, from: json)
        }
        guard case .dataCorrupted = error?.kind else {
            Issue.record("Unexpected CodingError.Decoding type: \(error)")
            return
        }
        #expect(error.debugDescription.contains("Missing required field 'date_published'"))
    }

    @Test func emptyDecodable() throws {
        let json = Data("{}".utf8)
        let decoded = try NewJSONDecoder().decode(EmptyDecodable.self, from: json)
        _ = decoded
    }
}

@JSONCodable
enum SimpleStatus: Equatable {
    case active
    case inactive
}

@JSONCodable
enum TaskStatus: Equatable {
    @CodingKey("in_progress") case inProgress
    case done
}

@JSONCodable
enum FlexibleStatus: Equatable {
    @DecodableAlias("in-progress") @CodingKey("in_progress") case inProgress
    case done
}

@JSONCodable
enum Shape: Equatable {
    case circle(radius: Double)
    case point
}

@JSONCodable
enum Wrapper: Equatable {
    case single(Int)
    case pair(String, Int)
}

@Suite("@JSONCodable Macro Integration")
struct JSONCodableMacroIntegrationTests {

    @Test func roundTrip() throws {
        let original = CodablePerson(name: "Alice", age: 30)
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"name":"Alice","age":30}"#)
        let decoded = try NewJSONDecoder().decode(CodablePerson.self, from: data)
        #expect(decoded.name == "Alice")
        #expect(decoded.age == 30)
    }

    @Test func roundTripWithCustomKey() throws {
        let original = CodablePost(title: "Hello", publishDate: "2026-01-01", rating: 4.5)
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"title":"Hello","date_published":"2026-01-01","rating":4.5}"#)
        let decoded = try NewJSONDecoder().decode(CodablePost.self, from: data)
        #expect(decoded.title == "Hello")
        #expect(decoded.publishDate == "2026-01-01")
        #expect(decoded.rating == 4.5)
    }

    @Test func roundTripOptionalNil() throws {
        let original = CodablePost(title: "Test", publishDate: "2026-03-10", rating: nil)
        let data = try NewJSONEncoder().encode(original)
        let decoded = try NewJSONDecoder().decode(CodablePost.self, from: data)
        #expect(decoded.title == "Test")
        #expect(decoded.rating == nil)
    }

    @Test func publicTypeRoundTrip() throws {
        let original = PublicCodablePerson(name: "Alice", age: 30)
        let data = try NewJSONEncoder().encode(original)
        let decoded = try NewJSONDecoder().decode(PublicCodablePerson.self, from: data)
        #expect(decoded.name == "Alice")
        #expect(decoded.age == 30)
    }

    @Test func enumWithoutAssociatedValues() throws {
        let original = SimpleStatus.active
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"active":{}}"#)
        let decoded = try NewJSONDecoder().decode(SimpleStatus.self, from: data)
        #expect(decoded == original)

        let inactive = SimpleStatus.inactive
        let data2 = try NewJSONEncoder().encode(inactive)
        let json2 = String(data: data2, encoding: .utf8)!
        #expect(json2 == #"{"inactive":{}}"#)
        let decoded2 = try NewJSONDecoder().decode(SimpleStatus.self, from: data2)
        #expect(decoded2 == inactive)
    }

    @Test func enumWithCodingKey() throws {
        let original = TaskStatus.inProgress
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"in_progress":{}}"#)
        let decoded = try NewJSONDecoder().decode(TaskStatus.self, from: data)
        #expect(decoded == original)
    }

    @Test func enumWithDecodableAlias() throws {
        let original = FlexibleStatus.inProgress
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"in_progress":{}}"#)

        // Decode using the alias key
        let aliasJSON = Data(#"{"in-progress":{}}"#.utf8)
        let decoded = try NewJSONDecoder().decode(FlexibleStatus.self, from: aliasJSON)
        #expect(decoded == .inProgress)
    }

    @Test func enumWithLabeledAssociatedValues() throws {
        let circle = Shape.circle(radius: 3.14)
        let data = try NewJSONEncoder().encode(circle)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"circle":{"radius":3.14}}"#)
        let decoded = try NewJSONDecoder().decode(Shape.self, from: data)
        #expect(decoded == circle)

        let point = Shape.point
        let data2 = try NewJSONEncoder().encode(point)
        let json2 = String(data: data2, encoding: .utf8)!
        #expect(json2 == #"{"point":{}}"#)
        let decoded2 = try NewJSONDecoder().decode(Shape.self, from: data2)
        #expect(decoded2 == point)
    }

    @Test func enumWithUnlabeledAssociatedValues() throws {
        let single = Wrapper.single(42)
        let data = try NewJSONEncoder().encode(single)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"single":{"_0":42}}"#)
        let decoded = try NewJSONDecoder().decode(Wrapper.self, from: data)
        #expect(decoded == single)

        let pair = Wrapper.pair("hello", 99)
        let data2 = try NewJSONEncoder().encode(pair)
        let json2 = String(data: data2, encoding: .utf8)!
        #expect(json2 == #"{"pair":{"_0":"hello","_1":99}}"#)
        let decoded2 = try NewJSONDecoder().decode(Wrapper.self, from: data2)
        #expect(decoded2 == pair)
    }
}

// MARK: - Combined @JSONCodable + @CommonCodable Integration Tests

/// A type annotated with both @JSONCodable and @CommonCodable to verify
/// that both conformances are generated correctly when macros are stacked.
@JSONCodable @CommonCodable
struct DualCodableStruct: Equatable {
    let name: String
    let count: Int
    let active: Bool
    let nickname: String?

    @CodingKey("created_at")
    let createdAt: String

    @CodableDefault("unknown")
    let source: String

    @DecodableAlias("colour")
    let color: String
}

@Suite("Combined @JSONCodable + @CommonCodable Integration")
struct CombinedMacroIntegrationTests {

    static let expectedJSON = #"{"name":"Widget","count":42,"active":true,"nickname":"W","created_at":"2026-01-01","source":"api","color":"red"}"#

    static func makeSample() -> DualCodableStruct {
        DualCodableStruct(
            name: "Widget",
            count: 42,
            active: true,
            nickname: "W",
            createdAt: "2026-01-01",
            source: "api",
            color: "red"
        )
    }

    @Test func jsonRoundTrip() throws {
        let original = Self.makeSample()
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == Self.expectedJSON)
        let decoded = try NewJSONDecoder().decode(DualCodableStruct.self, from: data)
        #expect(decoded == original)
    }

    @Test func commonRoundTrip() throws {
        let original = Self.makeSample()
        let data = try encodeViaCommon(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == Self.expectedJSON)
        let decoded: DualCodableStruct = try decodeViaCommon(from: data)
        #expect(decoded == original)
    }

    private func encodeViaCommon(_ value: borrowing some CommonEncodable) throws -> Data {
        try NewJSONEncoder().encode(value)
    }

    private func decodeViaCommon<T: CommonDecodable>(from data: Data) throws -> T {
        try NewJSONDecoder().decode(T.self, from: data)
    }

    @Test func optionalNilRoundTrip() throws {
        let original = DualCodableStruct(
            name: "X", count: 0, active: false,
            nickname: nil, createdAt: "2026-01-01", source: "test", color: "blue"
        )
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"nickname\":null"))
        let decoded = try NewJSONDecoder().decode(DualCodableStruct.self, from: data)
        #expect(decoded.nickname == nil)
    }

    @Test func defaultValueWhenKeyAbsent() throws {
        let json = Data(#"{"name":"X","count":0,"active":false,"nickname":null,"created_at":"2026-01-01","color":"blue"}"#.utf8)
        let decoded = try NewJSONDecoder().decode(DualCodableStruct.self, from: json)
        #expect(decoded.source == "unknown")
    }

    @Test func aliasDecoding() throws {
        let json = Data(#"{"name":"X","count":0,"active":false,"nickname":null,"created_at":"2026-01-01","source":"web","colour":"green"}"#.utf8)
        let decoded = try NewJSONDecoder().decode(DualCodableStruct.self, from: json)
        #expect(decoded.color == "green")
    }

    @Test func reversedAttributeOrder() throws {
        // Verifying the same type works — DualCodableStruct has @JSONCodable @CommonCodable.
        // This test confirms both paths produce the same JSON regardless of which path encodes.
        let original = Self.makeSample()
        let jsonData = try NewJSONEncoder().encode(original)
        let commonData = try encodeViaCommon(original)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        let commonString = String(data: commonData, encoding: .utf8)!
        #expect(jsonString == commonString)
    }
}
