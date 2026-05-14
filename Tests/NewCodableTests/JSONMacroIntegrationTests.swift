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

// MARK: - Naming Convention Integration Tests

// Each struct below uses the same comprehensive set of field names to exercise
// word splitting edge cases (single char, single word, all-caps, numerics,
// leading underscores, diacritics, emoji) across every naming strategy.

@JSONCodable(fieldNaming: .snake_case)
struct SnakeCaseNamingChecks: Equatable {
    let a: Int
    let single: Int
    let ALLCAPS: Int
    let ALL_CAPS: Int
    let userName: String
    let parseHTTPResponse: Int
    let one2Three: Int
    let one2three: Int
    let camelCaseField: String
    let _myField: Int
    let __doubleUnderscore: Int
    let snake_ćase: String
    let _one_two_three_: Int
    let caféName: String
    let data📦Size: Int
}

@JSONCodable(fieldNaming: .SCREAMING_SNAKE_CASE)
struct ScreamingSnakeCaseNamingChecks: Equatable {
    let a: Int
    let single: Int
    let ALLCAPS: Int
    let ALL_CAPS: Int
    let userName: String
    let parseHTTPResponse: Int
    let one2Three: Int
    let one2three: Int
    let camelCaseField: String
    let _myField: Int
    let __doubleUnderscore: Int
    let snake_ćase: String
    let _one_two_three_: Int
    let caféName: String
    let data📦Size: Int
}

@JSONCodable(fieldNaming: .kebab_case)
struct KebabCaseNamingChecks: Equatable {
    let a: Int
    let single: Int
    let ALLCAPS: Int
    let ALL_CAPS: Int
    let userName: String
    let parseHTTPResponse: Int
    let one2Three: Int
    let one2three: Int
    let camelCaseField: String
    let _myField: Int
    let __doubleUnderscore: Int
    let snake_ćase: String
    let _one_two_three_: Int
    let caféName: String
    let data📦Size: Int
}

@JSONCodable(fieldNaming: .SCREAMING_KEBAB_CASE)
struct ScreamingKebabCaseNamingChecks: Equatable {
    let a: Int
    let single: Int
    let ALLCAPS: Int
    let ALL_CAPS: Int
    let userName: String
    let parseHTTPResponse: Int
    let one2Three: Int
    let one2three: Int
    let camelCaseField: String
    let _myField: Int
    let __doubleUnderscore: Int
    let snake_ćase: String
    let _one_two_three_: Int
    let caféName: String
    let data📦Size: Int
}

@JSONCodable(fieldNaming: .PascalCase)
struct PascalCaseNamingChecks: Equatable {
    let a: Int
    let single: Int
    let ALLCAPS: Int
    let ALL_CAPS: Int
    let userName: String
    let parseHTTPResponse: Int
    let one2Three: Int
    let one2three: Int
    let camelCaseField: String
    let _myField: Int
    let __doubleUnderscore: Int
    let snake_ćase: String
    let _one_two_three_: Int
    let caféName: String
    let data📦Size: Int
}

@JSONCodable(fieldNaming: .camelCase)
struct CamelCaseNamingChecks: Equatable {
    let A: Int
    let Single: Int
    let ALLCAPS: Int
    let ALL_CAPS: Int
    let UserName: String
    let ParseHTTPResponse: Int
    let One2Three: Int
    let One2three: Int
    let CamelCaseField: String
    let _MyField: Int
    let __DoubleUnderscore: Int
    let Snake_Ćase: String
    let _One_Two_Three_: Int
    let CaféName: String
    let Data📦Size: Int
}

@JSONCodable(fieldNaming: .lowercase)
struct LowercaseNamingChecks: Equatable {
    let a: Int
    let single: Int
    let ALLCAPS: Int
    let userName: String
    let parseHTTPResponse: Int
    let one2Three: Int
    let camelCaseField: String
    let _myField: Int
    let __doubleUnderscore: Int
    let snake_ćase: String
    let _one_two_three_: Int
    let caféName: String
    let data📦Size: Int
}

@JSONCodable(fieldNaming: .UPPERCASE)
struct UppercaseNamingChecks: Equatable {
    let a: Int
    let single: Int
    let ALLCAPS: Int
    let userName: String
    let parseHTTPResponse: Int
    let one2Three: Int
    let camelCaseField: String
    let _myField: Int
    let __doubleUnderscore: Int
    let snake_ćase: String
    let _one_two_three_: Int
    let caféName: String
    let data📦Size: Int
}

@JSONCodable(fieldNaming: .snake_case)
struct NamingWithCodingKeyOverride: Equatable {
    let userName: String
    @CodingKey("custom_email") let emailAddress: String
}

@JSONCodable(caseNaming: .snake_case)
enum SnakeCaseEnum: Equatable {
    case myCase
    case anotherLongCase
}

@JSONCodable(caseNaming: .SCREAMING_SNAKE_CASE)
enum ScreamingSnakeCaseEnum: Equatable {
    case myCase
    case anotherLongCase
}

@JSONCodable(caseNaming: .kebab_case)
enum KebabCaseEnum: Equatable {
    case myCase
    case anotherLongCase
}

@JSONCodable(caseNaming: .snake_case, associatedValueLabelNaming: .snake_case)
enum SnakeCaseEnumWithAssocValues: Equatable {
    case userProfile(firstName: String, lastName: String)
    case errorCode(Int)
}

@JSONCodable(caseNaming: .snake_case)
enum SnakeCaseEnumWithCodingKeyOverride: Equatable {
    @CodingKey("custom_case") case myCase
    case anotherLongCase
}

@Suite("Naming Convention Integration")
struct NamingConventionIntegrationTests {

    // MARK: - Struct fieldNaming tests

    @Test func structSnakeCase() throws {
        let original = SnakeCaseNamingChecks(
            a: 1, single: 2, ALLCAPS: 3, ALL_CAPS: 9, userName: "alice",
            parseHTTPResponse: 200, one2Three: 4, one2three: 5,
            camelCaseField: "x", _myField: 6, __doubleUnderscore: 7,
            snake_ćase: "ć", _one_two_three_: 10, caféName: "Café", data📦Size: 8
        )
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains(#""a":1"#))
        #expect(json.contains(#""single":2"#))
        #expect(json.contains(#""allcaps":3"#))
        #expect(json.contains(#""all_caps":9"#))
        #expect(json.contains(#""user_name":"alice""#))
        #expect(json.contains(#""parse_http_response":200"#))
        #expect(json.contains(#""one2_three":4"#))
        #expect(json.contains(#""one2three":5"#))
        #expect(json.contains(#""camel_case_field":"x""#))
        #expect(json.contains(#""_my_field":6"#))
        #expect(json.contains(#""__double_underscore":7"#))
        #expect(json.contains(#""snake_ćase":"ć""#))
        #expect(json.contains(#""_one_two_three_":10"#))
        #expect(json.contains(#""café_name":"Café""#))
        #expect(json.contains(#""data📦_size":8"#))
        let decoded = try NewJSONDecoder().decode(SnakeCaseNamingChecks.self, from: data)
        #expect(decoded == original)
    }

    @Test func structScreamingSnakeCase() throws {
        let original = ScreamingSnakeCaseNamingChecks(
            a: 1, single: 2, ALLCAPS: 3, ALL_CAPS: 9, userName: "alice",
            parseHTTPResponse: 200, one2Three: 4, one2three: 5,
            camelCaseField: "x", _myField: 6, __doubleUnderscore: 7,
            snake_ćase: "ć", _one_two_three_: 10, caféName: "Café", data📦Size: 8
        )
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains(#""A":1"#))
        #expect(json.contains(#""SINGLE":2"#))
        #expect(json.contains(#""ALLCAPS":3"#))
        #expect(json.contains(#""ALL_CAPS":9"#))
        #expect(json.contains(#""USER_NAME":"alice""#))
        #expect(json.contains(#""PARSE_HTTP_RESPONSE":200"#))
        #expect(json.contains(#""ONE2_THREE":4"#))
        #expect(json.contains(#""ONE2THREE":5"#))
        #expect(json.contains(#""CAMEL_CASE_FIELD":"x""#))
        #expect(json.contains(#""_MY_FIELD":6"#))
        #expect(json.contains(#""__DOUBLE_UNDERSCORE":7"#))
        #expect(json.contains(#""SNAKE_ĆASE":"ć""#))
        #expect(json.contains(#""_ONE_TWO_THREE_":10"#))
        #expect(json.contains(#""CAFÉ_NAME":"Café""#))
        #expect(json.contains(#""DATA📦_SIZE":8"#))
        let decoded = try NewJSONDecoder().decode(ScreamingSnakeCaseNamingChecks.self, from: data)
        #expect(decoded == original)
    }

    @Test func structKebabCase() throws {
        let original = KebabCaseNamingChecks(
            a: 1, single: 2, ALLCAPS: 3, ALL_CAPS: 9, userName: "alice",
            parseHTTPResponse: 200, one2Three: 4, one2three: 5,
            camelCaseField: "x", _myField: 6, __doubleUnderscore: 7,
            snake_ćase: "ć", _one_two_three_: 10, caféName: "Café", data📦Size: 8
        )
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains(#""a":1"#))
        #expect(json.contains(#""single":2"#))
        #expect(json.contains(#""allcaps":3"#))
        #expect(json.contains(#""all-caps":9"#))
        #expect(json.contains(#""user-name":"alice""#))
        #expect(json.contains(#""parse-http-response":200"#))
        #expect(json.contains(#""one2-three":4"#))
        #expect(json.contains(#""one2three":5"#))
        #expect(json.contains(#""camel-case-field":"x""#))
        #expect(json.contains(#""_my-field":6"#))
        #expect(json.contains(#""__double-underscore":7"#))
        #expect(json.contains(#""snake-ćase":"ć""#))
        #expect(json.contains(#""_one-two-three_":10"#))
        #expect(json.contains(#""café-name":"Café""#))
        #expect(json.contains(#""data📦-size":8"#))
        let decoded = try NewJSONDecoder().decode(KebabCaseNamingChecks.self, from: data)
        #expect(decoded == original)
    }

    @Test func structScreamingKebabCase() throws {
        let original = ScreamingKebabCaseNamingChecks(
            a: 1, single: 2, ALLCAPS: 3, ALL_CAPS: 9, userName: "alice",
            parseHTTPResponse: 200, one2Three: 4, one2three: 5,
            camelCaseField: "x", _myField: 6, __doubleUnderscore: 7,
            snake_ćase: "ć", _one_two_three_: 10, caféName: "Café", data📦Size: 8
        )
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains(#""A":1"#))
        #expect(json.contains(#""SINGLE":2"#))
        #expect(json.contains(#""ALLCAPS":3"#))
        #expect(json.contains(#""ALL-CAPS":9"#))
        #expect(json.contains(#""USER-NAME":"alice""#))
        #expect(json.contains(#""PARSE-HTTP-RESPONSE":200"#))
        #expect(json.contains(#""ONE2-THREE":4"#))
        #expect(json.contains(#""ONE2THREE":5"#))
        #expect(json.contains(#""CAMEL-CASE-FIELD":"x""#))
        #expect(json.contains(#""_MY-FIELD":6"#))
        #expect(json.contains(#""__DOUBLE-UNDERSCORE":7"#))
        #expect(json.contains(#""SNAKE-ĆASE":"ć""#))
        #expect(json.contains(#""_ONE-TWO-THREE_":10"#))
        #expect(json.contains(#""CAFÉ-NAME":"Café""#))
        #expect(json.contains(#""DATA📦-SIZE":8"#))
        let decoded = try NewJSONDecoder().decode(ScreamingKebabCaseNamingChecks.self, from: data)
        #expect(decoded == original)
    }

    @Test func structPascalCase() throws {
        let original = PascalCaseNamingChecks(
            a: 1, single: 2, ALLCAPS: 3, ALL_CAPS: 9, userName: "alice",
            parseHTTPResponse: 200, one2Three: 4, one2three: 5,
            camelCaseField: "x", _myField: 6, __doubleUnderscore: 7,
            snake_ćase: "ć", _one_two_three_: 10, caféName: "Café", data📦Size: 8
        )
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains(#""A":1"#))
        #expect(json.contains(#""Single":2"#))
        #expect(json.contains(#""Allcaps":3"#))
        #expect(json.contains(#""AllCaps":9"#))
        #expect(json.contains(#""UserName":"alice""#))
        #expect(json.contains(#""ParseHttpResponse":200"#))
        #expect(json.contains(#""One2Three":4"#))
        #expect(json.contains(#""One2three":5"#))
        #expect(json.contains(#""CamelCaseField":"x""#))
        #expect(json.contains(#""_MyField":6"#))
        #expect(json.contains(#""__DoubleUnderscore":7"#))
        #expect(json.contains(#""SnakeĆase":"ć""#))
        #expect(json.contains(#""_OneTwoThree_":10"#))
        #expect(json.contains(#""CaféName":"Café""#))
        #expect(json.contains(#""Data📦Size":8"#))
        let decoded = try NewJSONDecoder().decode(PascalCaseNamingChecks.self, from: data)
        #expect(decoded == original)
    }

    @Test func structCamelCase() throws {
        let original = CamelCaseNamingChecks(
            A: 1, Single: 2, ALLCAPS: 3, ALL_CAPS: 9, UserName: "alice",
            ParseHTTPResponse: 200, One2Three: 4, One2three: 5,
            CamelCaseField: "x", _MyField: 6, __DoubleUnderscore: 7,
            Snake_Ćase: "ć", _One_Two_Three_: 10, CaféName: "Café", Data📦Size: 8
        )
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains(#""a":1"#))
        #expect(json.contains(#""single":2"#))
        #expect(json.contains(#""allcaps":3"#))
        #expect(json.contains(#""allCaps":9"#))
        #expect(json.contains(#""userName":"alice""#))
        #expect(json.contains(#""parseHttpResponse":200"#))
        #expect(json.contains(#""one2Three":4"#))
        #expect(json.contains(#""one2three":5"#))
        #expect(json.contains(#""camelCaseField":"x""#))
        #expect(json.contains(#""_myField":6"#))
        #expect(json.contains(#""__doubleUnderscore":7"#))
        #expect(json.contains(#""snakeĆase":"ć""#))
        #expect(json.contains(#""_oneTwoThree_":10"#))
        #expect(json.contains(#""caféName":"Café""#))
        #expect(json.contains(#""data📦Size":8"#))
        let decoded = try NewJSONDecoder().decode(CamelCaseNamingChecks.self, from: data)
        #expect(decoded == original)
    }

    @Test func structLowercase() throws {
        let original = LowercaseNamingChecks(
            a: 1, single: 2, ALLCAPS: 3, userName: "alice",
            parseHTTPResponse: 200, one2Three: 4,
            camelCaseField: "x", _myField: 6, __doubleUnderscore: 7,
            snake_ćase: "ć", _one_two_three_: 10, caféName: "Café", data📦Size: 8
        )
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains(#""a":1"#))
        #expect(json.contains(#""single":2"#))
        #expect(json.contains(#""allcaps":3"#))
        #expect(json.contains(#""username":"alice""#))
        #expect(json.contains(#""parsehttpresponse":200"#))
        #expect(json.contains(#""one2three":4"#))
        #expect(json.contains(#""camelcasefield":"x""#))
        #expect(json.contains(#""_myfield":6"#))
        #expect(json.contains(#""__doubleunderscore":7"#))
        #expect(json.contains(#""snakećase":"ć""#))
        #expect(json.contains(#""_onetwothree_":10"#))
        #expect(json.contains(#""caféname":"Café""#))
        #expect(json.contains(#""data📦size":8"#))
        let decoded = try NewJSONDecoder().decode(LowercaseNamingChecks.self, from: data)
        #expect(decoded == original)
    }

    @Test func structUppercase() throws {
        let original = UppercaseNamingChecks(
            a: 1, single: 2, ALLCAPS: 3, userName: "alice",
            parseHTTPResponse: 200, one2Three: 4,
            camelCaseField: "x", _myField: 6, __doubleUnderscore: 7,
            snake_ćase: "ć", _one_two_three_: 10, caféName: "Café", data📦Size: 8
        )
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains(#""A":1"#))
        #expect(json.contains(#""SINGLE":2"#))
        #expect(json.contains(#""ALLCAPS":3"#))
        #expect(json.contains(#""USERNAME":"alice""#))
        #expect(json.contains(#""PARSEHTTPRESPONSE":200"#))
        #expect(json.contains(#""ONE2THREE":4"#))
        #expect(json.contains(#""CAMELCASEFIELD":"x""#))
        #expect(json.contains(#""_MYFIELD":6"#))
        #expect(json.contains(#""__DOUBLEUNDERSCORE":7"#))
        #expect(json.contains(#""SNAKEĆASE":"ć""#))
        #expect(json.contains(#""_ONETWOTHREE_":10"#))
        #expect(json.contains(#""CAFÉNAME":"Café""#))
        #expect(json.contains(#""DATA📦SIZE":8"#))
        let decoded = try NewJSONDecoder().decode(UppercaseNamingChecks.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - CodingKey override

    @Test func codingKeyOverridesNamingConvention() throws {
        let original = NamingWithCodingKeyOverride(userName: "alice", emailAddress: "a@b.com")
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        // userName → snake_case → "user_name", but emailAddress has @CodingKey("custom_email")
        #expect(json == #"{"user_name":"alice","custom_email":"a@b.com"}"#)
        let decoded = try NewJSONDecoder().decode(NamingWithCodingKeyOverride.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - Enum caseNaming tests

    @Test func enumSnakeCase() throws {
        let original = SnakeCaseEnum.anotherLongCase
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"another_long_case":{}}"#)
        let decoded = try NewJSONDecoder().decode(SnakeCaseEnum.self, from: data)
        #expect(decoded == original)
    }

    @Test func enumScreamingSnakeCase() throws {
        let original = ScreamingSnakeCaseEnum.anotherLongCase
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"ANOTHER_LONG_CASE":{}}"#)
        let decoded = try NewJSONDecoder().decode(ScreamingSnakeCaseEnum.self, from: data)
        #expect(decoded == original)
    }

    @Test func enumKebabCase() throws {
        let original = KebabCaseEnum.anotherLongCase
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"another-long-case":{}}"#)
        let decoded = try NewJSONDecoder().decode(KebabCaseEnum.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - Enum associatedValueLabelNaming tests

    @Test func enumWithAssociatedValueNaming() throws {
        let original = SnakeCaseEnumWithAssocValues.userProfile(firstName: "Alice", lastName: "Smith")
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        // Case name → snake_case: "user_profile", labels → snake_case: "first_name", "last_name"
        #expect(json == #"{"user_profile":{"first_name":"Alice","last_name":"Smith"}}"#)
        let decoded = try NewJSONDecoder().decode(SnakeCaseEnumWithAssocValues.self, from: data)
        #expect(decoded == original)
    }

    @Test func enumWithUnlabeledAssociatedValueUnaffectedByNaming() throws {
        // Unlabeled associated values use positional names (_0, _1) which should not be transformed
        let original = SnakeCaseEnumWithAssocValues.errorCode(404)
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == #"{"error_code":{"_0":404}}"#)
        let decoded = try NewJSONDecoder().decode(SnakeCaseEnumWithAssocValues.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - Enum CodingKey override

    @Test func enumCodingKeyOverridesNamingConvention() throws {
        let original = SnakeCaseEnumWithCodingKeyOverride.myCase
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        // myCase has @CodingKey("custom_case"), so it uses "custom_case" not "my_case"
        #expect(json == #"{"custom_case":{}}"#)
        let decoded = try NewJSONDecoder().decode(SnakeCaseEnumWithCodingKeyOverride.self, from: data)
        #expect(decoded == original)

        // anotherLongCase has no override, so caseNaming applies
        let original2 = SnakeCaseEnumWithCodingKeyOverride.anotherLongCase
        let data2 = try NewJSONEncoder().encode(original2)
        let json2 = String(data: data2, encoding: .utf8)!
        #expect(json2 == #"{"another_long_case":{}}"#)
        let decoded2 = try NewJSONDecoder().decode(SnakeCaseEnumWithCodingKeyOverride.self, from: data2)
        #expect(decoded2 == original2)
    }
}
