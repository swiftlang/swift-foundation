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

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import SwiftSyntaxMacrosGenericTestSupport
import Testing
import NewCodableMacros

@Suite("@CommonCodable Macro")
struct CommonCodableMacroTests {

    @Test func basicStruct() {
        assertMacroExpansion(
            """
            @CommonCodable
            struct Person {
                let name: String
                let age: Int
            }
            """,
            expandedSource: """
            struct Person {
                let name: String
                let age: Int
            }
            
            extension Person {
                enum CodingFields: StaticStringCodingField {
                    case name
                    case age
                    case unknown

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .name:
                            "name"
                        case .age:
                            "age"
                        case .unknown:
                            fatalError()
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> CodingFields {
                        switch UTF8SpanComparator(key) {
                        case "name":
                            .name
                        case "age":
                            .age
                        default:
                            .unknown
                        }
                    }
                }
            }

            extension Person: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 2) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: CodingFields.name, value: self.name)
                        try structEncoder.encode(field: CodingFields.age, value: self.age)
                    }
                }
            }

            extension Person: CommonDecodable {
                static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> Person {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var name: String?
                        var age: Int?
                        var _codingField: CodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(CodingFields.self)
                        } andValue: { valueDecoder throws(CodingError.Decoding) in
                            switch _codingField! {
                            case .name:
                                name = try valueDecoder.decode(String.self)
                            case .age:
                                age = try valueDecoder.decode(Int.self)
                            case .unknown:
                                break
                            }
                        }
                        guard let name else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'name'")
                        }
                        guard let age else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'age'")
                        }
                        return Person(name: name, age: age)
                    }
                }
            }
            """,
            macros: codableTestMacros
        )
    }

    @Test func optionalProperty() {
        assertMacroExpansion(
            """
            @CommonCodable
            struct Item {
                let name: String
                let rating: Double?
            }
            """,
            expandedSource: """
            struct Item {
                let name: String
                let rating: Double?
            }
            
            extension Item {
                enum CodingFields: StaticStringCodingField {
                    case name
                    case rating
                    case unknown

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .name:
                            "name"
                        case .rating:
                            "rating"
                        case .unknown:
                            fatalError()
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> CodingFields {
                        switch UTF8SpanComparator(key) {
                        case "name":
                            .name
                        case "rating":
                            .rating
                        default:
                            .unknown
                        }
                    }
                }
            }

            extension Item: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 2) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: CodingFields.name, value: self.name)
                        try structEncoder.encode(field: CodingFields.rating, value: self.rating)
                    }
                }
            }

            extension Item: CommonDecodable {
                static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> Item {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var name: String?
                        var rating: Double?
                        var _codingField: CodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(CodingFields.self)
                        } andValue: { valueDecoder throws(CodingError.Decoding) in
                            switch _codingField! {
                            case .name:
                                name = try valueDecoder.decode(String.self)
                            case .rating:
                                rating = try valueDecoder.decode(Double?.self)
                            case .unknown:
                                break
                            }
                        }
                        guard let name else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'name'")
                        }
                        return Item(name: name, rating: rating)
                    }
                }
            }
            """,
            macros: codableTestMacros
        )
    }

    @Test func customCodingKey() {
        assertMacroExpansion(
            """
            @CommonCodable
            struct Post {
                @CodingKey("date_published") let publishDate: String
                let title: String
            }
            """,
            expandedSource: """
            struct Post {
                let publishDate: String
                let title: String
            }
            
            extension Post {
                enum CodingFields: StaticStringCodingField {
                    case publishDate
                    case title
                    case unknown

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .publishDate:
                            "date_published"
                        case .title:
                            "title"
                        case .unknown:
                            fatalError()
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> CodingFields {
                        switch UTF8SpanComparator(key) {
                        case "date_published":
                            .publishDate
                        case "title":
                            .title
                        default:
                            .unknown
                        }
                    }
                }
            }

            extension Post: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 2) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: CodingFields.publishDate, value: self.publishDate)
                        try structEncoder.encode(field: CodingFields.title, value: self.title)
                    }
                }
            }

            extension Post: CommonDecodable {
                static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> Post {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var publishDate: String?
                        var title: String?
                        var _codingField: CodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(CodingFields.self)
                        } andValue: { valueDecoder throws(CodingError.Decoding) in
                            switch _codingField! {
                            case .publishDate:
                                publishDate = try valueDecoder.decode(String.self)
                            case .title:
                                title = try valueDecoder.decode(String.self)
                            case .unknown:
                                break
                            }
                        }
                        guard let publishDate else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'date_published'")
                        }
                        guard let title else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'title'")
                        }
                        return Post(publishDate: publishDate, title: title)
                    }
                }
            }
            """,
            macros: codableTestMacros
        )
    }

    @Test func emptyStruct() {
        assertMacroExpansion(
            """
            @CommonCodable
            struct Empty {
            }
            """,
            expandedSource: """
            struct Empty {
            }

            extension Empty: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 0) { _ throws(CodingError.Encoding) in
                    }
                }
            }

            extension Empty: CommonDecodable {
                static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> Empty {
                    try decoder.decodeStruct { _ throws(CodingError.Decoding) in
                        Empty()
                    }
                }
            }
            """,
            macros: codableTestMacros
        )
    }

    @Test func defaultValue() {
        assertMacroExpansion(
            """
            @CommonCodable
            struct Config {
                let name: String
                @CodableDefault("en") let locale: String
            }
            """,
            expandedSource: """
            struct Config {
                let name: String
                let locale: String
            }
            
            extension Config {
                enum CodingFields: StaticStringCodingField {
                    case name
                    case locale
                    case unknown

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .name:
                            "name"
                        case .locale:
                            "locale"
                        case .unknown:
                            fatalError()
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> CodingFields {
                        switch UTF8SpanComparator(key) {
                        case "name":
                            .name
                        case "locale":
                            .locale
                        default:
                            .unknown
                        }
                    }
                }
            }

            extension Config: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 2) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: CodingFields.name, value: self.name)
                        try structEncoder.encode(field: CodingFields.locale, value: self.locale)
                    }
                }
            }

            extension Config: CommonDecodable {
                static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> Config {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var name: String?
                        var locale: String?
                        var _codingField: CodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(CodingFields.self)
                        } andValue: { valueDecoder throws(CodingError.Decoding) in
                            switch _codingField! {
                            case .name:
                                name = try valueDecoder.decode(String.self)
                            case .locale:
                                locale = try valueDecoder.decode(String.self)
                            case .unknown:
                                break
                            }
                        }
                        guard let name else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'name'")
                        }
                        return Config(name: name, locale: locale ?? "en")
                    }
                }
            }
            """,
            macros: codableTestMacros
        )
    }

    @Test func aliasFullRoundtrip() {
        assertMacroExpansion(
            """
            @CommonCodable
            struct User {
                @DecodableAlias("user_name") let userName: String
            }
            """,
            expandedSource: """
            struct User {
                let userName: String
            }
            
            extension User {
                enum CodingFields: StaticStringCodingField {
                    case userName
                    case unknown

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .userName:
                            "userName"
                        case .unknown:
                            fatalError()
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> CodingFields {
                        switch UTF8SpanComparator(key) {
                        case "userName":
                            .userName
                        case "user_name":
                            .userName
                        default:
                            .unknown
                        }
                    }
                }
            }

            extension User: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 1) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: CodingFields.userName, value: self.userName)
                    }
                }
            }

            extension User: CommonDecodable {
                static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> User {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var userName: String?
                        var _codingField: CodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(CodingFields.self)
                        } andValue: { valueDecoder throws(CodingError.Decoding) in
                            switch _codingField! {
                            case .userName:
                                userName = try valueDecoder.decode(String.self)
                            case .unknown:
                                break
                            }
                        }
                        guard let userName else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'userName'")
                        }
                        return User(userName: userName)
                    }
                }
            }
            """,
            macros: codableTestMacros
        )
    }

    @Test func aliasCombinedWithCodingKey() {
        assertMacroExpansion(
            """
            @CommonCodable
            struct User {
                @CodingKey("user_name") @DecodableAlias("username") let userName: String
            }
            """,
            expandedSource: """
            struct User {
                let userName: String
            }
            
            extension User {
                enum CodingFields: StaticStringCodingField {
                    case userName
                    case unknown

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .userName:
                            "user_name"
                        case .unknown:
                            fatalError()
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> CodingFields {
                        switch UTF8SpanComparator(key) {
                        case "user_name":
                            .userName
                        case "username":
                            .userName
                        default:
                            .unknown
                        }
                    }
                }
            }

            extension User: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 1) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: CodingFields.userName, value: self.userName)
                    }
                }
            }

            extension User: CommonDecodable {
                static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> User {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var userName: String?
                        var _codingField: CodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(CodingFields.self)
                        } andValue: { valueDecoder throws(CodingError.Decoding) in
                            switch _codingField! {
                            case .userName:
                                userName = try valueDecoder.decode(String.self)
                            case .unknown:
                                break
                            }
                        }
                        guard let userName else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'user_name'")
                        }
                        return User(userName: userName)
                    }
                }
            }
            """,
            macros: codableTestMacros
        )
    }

    @Test func publicStructEmitsPublicMembers() {
        assertMacroExpansion(
            """
            @CommonCodable
            public struct Person {
                public let name: String
                public let age: Int
            }
            """,
            expandedSource: """
            public struct Person {
                public let name: String
                public let age: Int
            }

            extension Person {
                enum CodingFields: StaticStringCodingField {
                    case name
                    case age
                    case unknown

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .name:
                            "name"
                        case .age:
                            "age"
                        case .unknown:
                            fatalError()
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> CodingFields {
                        switch UTF8SpanComparator(key) {
                        case "name":
                            .name
                        case "age":
                            .age
                        default:
                            .unknown
                        }
                    }
                }
            }

            extension Person: CommonEncodable {
                public func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 2) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: CodingFields.name, value: self.name)
                        try structEncoder.encode(field: CodingFields.age, value: self.age)
                    }
                }
            }

            extension Person: CommonDecodable {
                public static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> Person {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var name: String?
                        var age: Int?
                        var _codingField: CodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(CodingFields.self)
                        } andValue: { valueDecoder throws(CodingError.Decoding) in
                            switch _codingField! {
                            case .name:
                                name = try valueDecoder.decode(String.self)
                            case .age:
                                age = try valueDecoder.decode(Int.self)
                            case .unknown:
                                break
                            }
                        }
                        guard let name else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'name'")
                        }
                        guard let age else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'age'")
                        }
                        return Person(name: name, age: age)
                    }
                }
            }
            """,
            macros: codableTestMacros
        )
    }

    @Test func errorOnNonStruct() {
        assertMacroExpansion(
            """
            @CommonCodable
            class NotAStruct {
                let name: String = ""
            }
            """,
            expandedSource: """
            class NotAStruct {
                let name: String = ""
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@CommonCodable can only be applied to structs", line: 1, column: 1),
            ],
            macros: codableTestMacros
        )
    }
}

private let codableTestMacros: [String: Macro.Type] = [
    "CommonCodable": CommonCodableMacro.self,
    "CodingKey": CodingKeyMacro.self,
    "CodableDefault": CodableDefaultMacro.self,
    "DecodableAlias": DecodableAliasMacro.self,
]
