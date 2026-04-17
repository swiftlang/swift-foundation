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
        #expect(json.contains("\"title\":\"Hello\""))
        #expect(json.contains("\"body\":\"World\""))
    }

    @Test func customCodingKey() throws {
        let post = BlogPost(title: "Test", publishDate: "2026-01-01", tags: ["swift"], rating: 4.5)
        let data = try NewJSONEncoder().encode(post)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"date_published\":\"2026-01-01\""))
        #expect(json.contains("\"title\":\"Test\""))
        #expect(json.contains("\"tags\":[\"swift\"]"))
        #expect(json.contains("\"rating\":4.5"))
    }

    @Test func optionalNilValue() throws {
        let post = BlogPost(title: "Test", publishDate: "2026-01-01", tags: [], rating: nil)
        let data = try NewJSONEncoder().encode(post)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"rating\":null"))
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
        let decoded = try NewJSONDecoder().decode(RoundTripPerson.self, from: data)
        #expect(decoded.name == "Alice")
        #expect(decoded.age == 30)
    }

    @Test func roundTripCustomCodingKey() throws {
        let original = RoundTripPost(title: "Hello", publishDate: "2026-01-01", rating: 4.5)
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"date_published\":\"2026-01-01\""))
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

@Suite("@JSONCodable Macro Integration")
struct JSONCodableMacroIntegrationTests {

    @Test func roundTrip() throws {
        let original = CodablePerson(name: "Alice", age: 30)
        let data = try NewJSONEncoder().encode(original)
        let decoded = try NewJSONDecoder().decode(CodablePerson.self, from: data)
        #expect(decoded.name == "Alice")
        #expect(decoded.age == 30)
    }

    @Test func roundTripWithCustomKey() throws {
        let original = CodablePost(title: "Hello", publishDate: "2026-01-01", rating: 4.5)
        let data = try NewJSONEncoder().encode(original)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"date_published\":\"2026-01-01\""))
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
}
