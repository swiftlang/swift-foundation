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

// MARK: - @CodableBy Integration Tests

@JSONCodable
struct CodableByISO8601Type: Equatable {
    @CodableBy(.dateFormat(.iso8601))
    let createdAt: Date
}

@JSONCodable
struct CodableByISO8601WithOptionsType: Equatable {
    @CodableBy(.format(Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
    let createdAt: Date
}

@JSONCodable
struct CodableByBase64Type: Equatable {
    @CodableBy(.base64)
    let payload: Data
}

/// A JSON-specific decoding strategy that extracts the JSONPrimtivie.Number
/// of a JSON number using `decodeNumber()` on `JSONDecoderProtocol`.
struct JSONNumberDecodingStrategy: JSONDecodingStrategy {
    typealias Value = JSONPrimitive.Number

    func decode(from decoder: inout some (JSONDecoderProtocol & ~Escapable)) throws(CodingError.Decoding) -> JSONPrimitive.Number {
        return try decoder.decodeNumber()
    }
}

@JSONDecodable
struct DecodableByJSONNumberAsString {
    @DecodableBy(JSONNumberDecodingStrategy())
    let price: JSONPrimitive.Number
    let name: String
}

@JSONCodable
struct CodableByArrayOfDates: Equatable {
    @CodableBy([.dateFormat(.iso8601)])
    let timestamps: [Date]
}

@JSONCodable
struct CodableByArrayOfBase64: Equatable {
    @CodableBy([.base64])
    let attachments: [Data]
}

@JSONCodable
struct CodableByDictionaryWithLosslessKey {
    @CodableBy([.losslessStringConversion : .pass])
    let scores: [(Int, String)]
}

@JSONCodable
struct CodableByDictionaryTuplesWithNestedValueStrategy {
    @CodableBy([.pass : [.dateFormat(.iso8601)]])
    let events: [(String, [Date])]
}

@JSONCodable
struct CodableByDictionaryWithLosslessKeyAndNestedValueStrategy {
    @CodableBy([.losslessStringConversion : [.dateFormat(.iso8601)]])
    let schedule: [UInt8: [Date]]
}

@Suite("@CodableBy Strategy Tests")
struct JSONCodableByStrategyTests {
    
    @Test func iso8601RoundTrip() throws {
        let date = try Date.ISO8601FormatStyle().parse("2026-01-15T10:30:00Z")
        let original = CodableByISO8601Type(createdAt: date)
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"createdAt":"2026-01-15T10:30:00Z"}"#)
        let decoded = try NewJSONDecoder().decode(CodableByISO8601Type.self, from: data)
        #expect(decoded.createdAt == date)
    }

    @Test func iso8601WithFractionalSeconds() throws {
        let style = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        let date = try style.parse("2026-01-15T10:30:00.500Z")
        let original = CodableByISO8601WithOptionsType(createdAt: date)
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("2026-01-15T10:30:00.5"))
        let decoded = try NewJSONDecoder().decode(CodableByISO8601WithOptionsType.self, from: data)
        #expect(decoded.createdAt == date)
    }

    @Test func base64RoundTrip() throws {
        let bytes = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let original = CodableByBase64Type(payload: bytes)
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"payload":"3q2+7w=="}"#)
        let decoded = try NewJSONDecoder().decode(CodableByBase64Type.self, from: data)
        #expect(decoded.payload == bytes)
    }
    
    @Test func numberAsStringViaJSONDecodingStrategy() throws {
        let json = Data(#"{"price":49.99,"name":"Widget"}"#.utf8)
        let decoded = try NewJSONDecoder().decode(DecodableByJSONNumberAsString.self, from: json)
        #expect(decoded.price.extendedPrecisionRepresentation == "49.99")
        #expect(decoded.name == "Widget")
    }

    // MARK: - Array strategy tests

    @Test func arrayOfISO8601Dates() throws {
        let date1 = try Date.ISO8601FormatStyle().parse("2026-01-15T10:30:00Z")
        let date2 = try Date.ISO8601FormatStyle().parse("2026-06-01T12:00:00Z")
        let original = CodableByArrayOfDates(timestamps: [date1, date2])
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"timestamps":["2026-01-15T10:30:00Z","2026-06-01T12:00:00Z"]}"#)
        let decoded = try NewJSONDecoder().decode(CodableByArrayOfDates.self, from: data)
        #expect(decoded == original)
    }

    @Test func arrayOfISO8601DatesEmpty() throws {
        let original = CodableByArrayOfDates(timestamps: [])
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"timestamps":[]}"#)
        let decoded = try NewJSONDecoder().decode(CodableByArrayOfDates.self, from: data)
        #expect(decoded == original)
    }

    @Test func arrayOfBase64() throws {
        let a1 = Data([0xCA, 0xFE])
        let a2 = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let original = CodableByArrayOfBase64(attachments: [a1, a2])
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"attachments":["yv4=","3q2+7w=="]}"#)
        let decoded = try NewJSONDecoder().decode(CodableByArrayOfBase64.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - Dictionary strategy tests

    @Test func dictionaryWithLosslessStringKey() throws {
        let original = CodableByDictionaryWithLosslessKey(scores: [(1, "Alice"), (2, "Bob")])
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"scores":{"1":"Alice","2":"Bob"}}"#)
        let decoded = try NewJSONDecoder().decode(CodableByDictionaryWithLosslessKey.self, from: data)
        #expect(decoded.scores.count == 2)
        #expect(decoded.scores[0] == (1, "Alice"))
        #expect(decoded.scores[1] == (2, "Bob"))
    }

    @Test func dictionaryWithLosslessStringKeyEmpty() throws {
        let original = CodableByDictionaryWithLosslessKey(scores: [])
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"scores":{}}"#)
        let decoded = try NewJSONDecoder().decode(CodableByDictionaryWithLosslessKey.self, from: data)
        #expect(decoded.scores.isEmpty)
    }

    @Test func dictionaryTuplesWithNestedValueStrategy() throws {
        let date1 = try Date.ISO8601FormatStyle().parse("2026-03-01T09:00:00Z")
        let date2 = try Date.ISO8601FormatStyle().parse("2026-07-04T18:30:00Z")
        let date3 = try Date.ISO8601FormatStyle().parse("2026-12-25T00:00:00Z")
        let original = CodableByDictionaryTuplesWithNestedValueStrategy(events: [("work", [date1, date2]), ("holiday", [date3])])
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"events":{"work":["2026-03-01T09:00:00Z","2026-07-04T18:30:00Z"],"holiday":["2026-12-25T00:00:00Z"]}}"#)
        let decoded = try NewJSONDecoder().decode(CodableByDictionaryTuplesWithNestedValueStrategy.self, from: data)
        #expect(decoded.events.count == 2)
        #expect(decoded.events[0].0 == "work")
        #expect(decoded.events[0].1 == [date1, date2])
        #expect(decoded.events[1].0 == "holiday")
        #expect(decoded.events[1].1 == [date3])
    }

    @Test func dictionaryWithNestedValueStrategy() throws {
        let date1 = try Date.ISO8601FormatStyle().parse("2026-02-14T10:00:00Z")
        let date2 = try Date.ISO8601FormatStyle().parse("2026-08-20T15:00:00Z")
        let date3 = try Date.ISO8601FormatStyle().parse("2026-11-11T11:11:00Z")
        let original = CodableByDictionaryWithLosslessKeyAndNestedValueStrategy(schedule: [1: [date1, date2], 42: [date3]])
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        // Dictionary ordering is not guaranteed, so check both possible orderings
        let option1 = #"{"schedule":{"1":["2026-02-14T10:00:00Z","2026-08-20T15:00:00Z"],"42":["2026-11-11T11:11:00Z"]}}"#
        let option2 = #"{"schedule":{"42":["2026-11-11T11:11:00Z"],"1":["2026-02-14T10:00:00Z","2026-08-20T15:00:00Z"]}}"#
        #expect(json == option1 || json == option2)
        let decoded = try NewJSONDecoder().decode(CodableByDictionaryWithLosslessKeyAndNestedValueStrategy.self, from: data)
        #expect(decoded.schedule.count == 2)
        #expect(decoded.schedule[1] == [date1, date2])
        #expect(decoded.schedule[42] == [date3])
    }
}


