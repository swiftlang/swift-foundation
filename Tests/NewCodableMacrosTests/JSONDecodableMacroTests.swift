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

@Suite("@JSONDecodable Macro")
struct JSONDecodableMacroTests {

    @Test func basicStruct() {
        assertMacroExpansion(
            """
            @JSONDecodable
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
                enum JSONCodingFields: JSONOptimizedDecodingField {
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

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
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

            extension Person: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Person {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var name: String?
                        var age: Int?
                        var _codingField: JSONCodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(JSONCodingFields.self)
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
            macros: decodableTestMacros
        )
    }

    @Test func optionalProperty() {
        assertMacroExpansion(
            """
            @JSONDecodable
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
                enum JSONCodingFields: JSONOptimizedDecodingField {
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

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
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

            extension Item: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Item {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var name: String?
                        var rating: Double?
                        var _codingField: JSONCodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(JSONCodingFields.self)
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
            macros: decodableTestMacros
        )
    }

    @Test func allOptionalProperties() {
        assertMacroExpansion(
            """
            @JSONDecodable
            struct Preferences {
                let theme: String?
                let fontSize: Int?
            }
            """,
            expandedSource: """
            struct Preferences {
                let theme: String?
                let fontSize: Int?
            }

            extension Preferences {
                enum JSONCodingFields: JSONOptimizedDecodingField {
                    case theme
                    case fontSize
                    case unknown

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .theme:
                            "theme"
                        case .fontSize:
                            "fontSize"
                        case .unknown:
                            fatalError()
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
                        switch UTF8SpanComparator(key) {
                        case "theme":
                            .theme
                        case "fontSize":
                            .fontSize
                        default:
                            .unknown
                        }
                    }
                }
            }

            extension Preferences: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Preferences {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var theme: String?
                        var fontSize: Int?
                        var _codingField: JSONCodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(JSONCodingFields.self)
                        } andValue: { valueDecoder throws(CodingError.Decoding) in
                            switch _codingField! {
                            case .theme:
                                theme = try valueDecoder.decode(String?.self)
                            case .fontSize:
                                fontSize = try valueDecoder.decode(Int?.self)
                            case .unknown:
                                break
                            }
                        }
                        return Preferences(theme: theme, fontSize: fontSize)
                    }
                }
            }
            """,
            macros: decodableTestMacros
        )
    }

    @Test func customCodingKey() {
        assertMacroExpansion(
            """
            @JSONDecodable
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
                enum JSONCodingFields: JSONOptimizedDecodingField {
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

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
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

            extension Post: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Post {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var publishDate: String?
                        var title: String?
                        var _codingField: JSONCodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(JSONCodingFields.self)
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
            macros: decodableTestMacros
        )
    }

    @Test func computedPropertySkipped() {
        assertMacroExpansion(
            """
            @JSONDecodable
            struct Thing {
                let name: String
                var displayName: String {
                    get { name.uppercased() }
                }
            }
            """,
            expandedSource: """
            struct Thing {
                let name: String
                var displayName: String {
                    get { name.uppercased() }
                }
            }

            extension Thing {
                enum JSONCodingFields: JSONOptimizedDecodingField {
                    case name
                    case unknown

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .name:
                            "name"
                        case .unknown:
                            fatalError()
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
                        switch UTF8SpanComparator(key) {
                        case "name":
                            .name
                        default:
                            .unknown
                        }
                    }
                }
            }

            extension Thing: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Thing {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var name: String?
                        var _codingField: JSONCodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(JSONCodingFields.self)
                        } andValue: { valueDecoder throws(CodingError.Decoding) in
                            switch _codingField! {
                            case .name:
                                name = try valueDecoder.decode(String.self)
                            case .unknown:
                                break
                            }
                        }
                        guard let name else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'name'")
                        }
                        return Thing(name: name)
                    }
                }
            }
            """,
            macros: decodableTestMacros
        )
    }

    @Test func staticPropertySkipped() {
        assertMacroExpansion(
            """
            @JSONDecodable
            struct Config {
                static let defaultName = "test"
                let name: String
            }
            """,
            expandedSource: """
            struct Config {
                static let defaultName = "test"
                let name: String
            }

            extension Config {
                enum JSONCodingFields: JSONOptimizedDecodingField {
                    case name
                    case unknown

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .name:
                            "name"
                        case .unknown:
                            fatalError()
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
                        switch UTF8SpanComparator(key) {
                        case "name":
                            .name
                        default:
                            .unknown
                        }
                    }
                }
            }

            extension Config: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Config {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var name: String?
                        var _codingField: JSONCodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(JSONCodingFields.self)
                        } andValue: { valueDecoder throws(CodingError.Decoding) in
                            switch _codingField! {
                            case .name:
                                name = try valueDecoder.decode(String.self)
                            case .unknown:
                                break
                            }
                        }
                        guard let name else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'name'")
                        }
                        return Config(name: name)
                    }
                }
            }
            """,
            macros: decodableTestMacros
        )
    }

    @Test func lazyVarSkipped() {
        assertMacroExpansion(
            """
            @JSONDecodable
            struct Cached {
                let name: String
                lazy var uppercasedName: String = name.uppercased()
            }
            """,
            expandedSource: """
            struct Cached {
                let name: String
                lazy var uppercasedName: String = name.uppercased()
            }
            
            extension Cached {
                enum JSONCodingFields: JSONOptimizedDecodingField {
                    case name
                    case unknown

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .name:
                            "name"
                        case .unknown:
                            fatalError()
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
                        switch UTF8SpanComparator(key) {
                        case "name":
                            .name
                        default:
                            .unknown
                        }
                    }
                }
            }

            extension Cached: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Cached {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var name: String?
                        var _codingField: JSONCodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(JSONCodingFields.self)
                        } andValue: { valueDecoder throws(CodingError.Decoding) in
                            switch _codingField! {
                            case .name:
                                name = try valueDecoder.decode(String.self)
                            case .unknown:
                                break
                            }
                        }
                        guard let name else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'name'")
                        }
                        return Cached(name: name)
                    }
                }
            }
            """,
            macros: decodableTestMacros
        )
    }

    @Test func emptyStruct() {
        assertMacroExpansion(
            """
            @JSONDecodable
            struct Empty {
            }
            """,
            expandedSource: """
            struct Empty {
            }

            extension Empty: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Empty {
                    try decoder.decodeStruct { _ throws(CodingError.Decoding) in
                        Empty()
                    }
                }
            }
            """,
            macros: decodableTestMacros
        )
    }

    @Test func errorOnNonStruct() {
        assertMacroExpansion(
            """
            @JSONDecodable
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
                DiagnosticSpec(message: "@JSONDecodable can only be applied to structs or enums", line: 1, column: 1)
            ],
            macros: decodableTestMacros
        )
    }

    @Test func propertyWithoutTypeAnnotation() {
        assertMacroExpansion(
            """
            @JSONDecodable
            struct Bad {
                let name = "default"
            }
            """,
            expandedSource: """
            struct Bad {
                let name = "default"
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@JSONDecodable requires all stored properties to have explicit type annotations", line: 3, column: 9)
            ],
            macros: decodableTestMacros
        )
    }

    @Test func defaultValue() {
        assertMacroExpansion(
            """
            @JSONDecodable
            struct Config {
                let name: String
                @CodableDefault("en") let locale: String
                @CodableDefault(0) let retryCount: Int
            }
            """,
            expandedSource: """
            struct Config {
                let name: String
                let locale: String
                let retryCount: Int
            }

            extension Config {
                enum JSONCodingFields: JSONOptimizedDecodingField {
                    case name
                    case locale
                    case retryCount
                    case unknown

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .name:
                            "name"
                        case .locale:
                            "locale"
                        case .retryCount:
                            "retryCount"
                        case .unknown:
                            fatalError()
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
                        switch UTF8SpanComparator(key) {
                        case "name":
                            .name
                        case "locale":
                            .locale
                        case "retryCount":
                            .retryCount
                        default:
                            .unknown
                        }
                    }
                }
            }

            extension Config: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Config {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var name: String?
                        var locale: String?
                        var retryCount: Int?
                        var _codingField: JSONCodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(JSONCodingFields.self)
                        } andValue: { valueDecoder throws(CodingError.Decoding) in
                            switch _codingField! {
                            case .name:
                                name = try valueDecoder.decode(String.self)
                            case .locale:
                                locale = try valueDecoder.decode(String.self)
                            case .retryCount:
                                retryCount = try valueDecoder.decode(Int.self)
                            case .unknown:
                                break
                            }
                        }
                        guard let name else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'name'")
                        }
                        return Config(name: name, locale: locale ?? "en", retryCount: retryCount ?? 0)
                    }
                }
            }
            """,
            macros: decodableTestMacros
        )
    }

    @Test func allDefaultValues() {
        assertMacroExpansion(
            """
            @JSONDecodable
            struct Defaults {
                @CodableDefault("hello") let greeting: String
                @CodableDefault(false) let verbose: Bool
            }
            """,
            expandedSource: """
            struct Defaults {
                let greeting: String
                let verbose: Bool
            }

            extension Defaults {
                enum JSONCodingFields: JSONOptimizedDecodingField {
                    case greeting
                    case verbose
                    case unknown

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .greeting:
                            "greeting"
                        case .verbose:
                            "verbose"
                        case .unknown:
                            fatalError()
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
                        switch UTF8SpanComparator(key) {
                        case "greeting":
                            .greeting
                        case "verbose":
                            .verbose
                        default:
                            .unknown
                        }
                    }
                }
            }

            extension Defaults: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Defaults {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var greeting: String?
                        var verbose: Bool?
                        var _codingField: JSONCodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(JSONCodingFields.self)
                        } andValue: { valueDecoder throws(CodingError.Decoding) in
                            switch _codingField! {
                            case .greeting:
                                greeting = try valueDecoder.decode(String.self)
                            case .verbose:
                                verbose = try valueDecoder.decode(Bool.self)
                            case .unknown:
                                break
                            }
                        }
                        return Defaults(greeting: greeting ?? "hello", verbose: verbose ?? false)
                    }
                }
            }
            """,
            macros: decodableTestMacros
        )
    }

    @Test func defaultWithCodingKey() {
        assertMacroExpansion(
            """
            @JSONDecodable
            struct Setting {
                @CodingKey("max_retries") @CodableDefault(3) let maxRetries: Int
            }
            """,
            expandedSource: """
            struct Setting {
                let maxRetries: Int
            }

            extension Setting {
                enum JSONCodingFields: JSONOptimizedDecodingField {
                    case maxRetries
                    case unknown

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .maxRetries:
                            "max_retries"
                        case .unknown:
                            fatalError()
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
                        switch UTF8SpanComparator(key) {
                        case "max_retries":
                            .maxRetries
                        default:
                            .unknown
                        }
                    }
                }
            }

            extension Setting: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Setting {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var maxRetries: Int?
                        var _codingField: JSONCodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(JSONCodingFields.self)
                        } andValue: { valueDecoder throws(CodingError.Decoding) in
                            switch _codingField! {
                            case .maxRetries:
                                maxRetries = try valueDecoder.decode(Int.self)
                            case .unknown:
                                break
                            }
                        }
                        return Setting(maxRetries: maxRetries ?? 3)
                    }
                }
            }
            """,
            macros: decodableTestMacros
        )
    }

    @Test func defaultOnOptionalProperty() {
        assertMacroExpansion(
            """
            @JSONDecodable
            struct Prefs {
                @CodableDefault("en") let locale: String?
            }
            """,
            expandedSource: """
            struct Prefs {
                let locale: String?
            }

            extension Prefs {
                enum JSONCodingFields: JSONOptimizedDecodingField {
                    case locale
                    case unknown

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .locale:
                            "locale"
                        case .unknown:
                            fatalError()
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
                        switch UTF8SpanComparator(key) {
                        case "locale":
                            .locale
                        default:
                            .unknown
                        }
                    }
                }
            }

            extension Prefs: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Prefs {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var locale: String?
                        var _codingField: JSONCodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(JSONCodingFields.self)
                        } andValue: { valueDecoder throws(CodingError.Decoding) in
                            switch _codingField! {
                            case .locale:
                                locale = try valueDecoder.decode(String?.self)
                            case .unknown:
                                break
                            }
                        }
                        return Prefs(locale: locale ?? "en")
                    }
                }
            }
            """,
            macros: decodableTestMacros
        )
    }

    @Test func defaultWithArbitraryExpression() {
        assertMacroExpansion(
            """
            @JSONDecodable
            struct WithExpr {
                @CodableDefault([]) let tags: [String]
            }
            """,
            expandedSource: """
            struct WithExpr {
                let tags: [String]
            }

            extension WithExpr {
                enum JSONCodingFields: JSONOptimizedDecodingField {
                    case tags
                    case unknown

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .tags:
                            "tags"
                        case .unknown:
                            fatalError()
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
                        switch UTF8SpanComparator(key) {
                        case "tags":
                            .tags
                        default:
                            .unknown
                        }
                    }
                }
            }

            extension WithExpr: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> WithExpr {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var tags: [String]?
                        var _codingField: JSONCodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(JSONCodingFields.self)
                        } andValue: { valueDecoder throws(CodingError.Decoding) in
                            switch _codingField! {
                            case .tags:
                                tags = try valueDecoder.decode([String].self)
                            case .unknown:
                                break
                            }
                        }
                        return WithExpr(tags: tags ?? [])
                    }
                }
            }
            """,
            macros: decodableTestMacros
        )
    }

    @Test func aliasBasic() {
        assertMacroExpansion(
            """
            @JSONDecodable
            struct User {
                @DecodableAlias("user_name") let userName: String
                let age: Int
            }
            """,
            expandedSource: """
            struct User {
                let userName: String
                let age: Int
            }

            extension User {
                enum JSONCodingFields: JSONOptimizedDecodingField {
                    case userName
                    case age
                    case unknown

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .userName:
                            "userName"
                        case .age:
                            "age"
                        case .unknown:
                            fatalError()
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
                        switch UTF8SpanComparator(key) {
                        case "userName":
                            .userName
                        case "user_name":
                            .userName
                        case "age":
                            .age
                        default:
                            .unknown
                        }
                    }
                }
            }

            extension User: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> User {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var userName: String?
                        var age: Int?
                        var _codingField: JSONCodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(JSONCodingFields.self)
                        } andValue: { valueDecoder throws(CodingError.Decoding) in
                            switch _codingField! {
                            case .userName:
                                userName = try valueDecoder.decode(String.self)
                            case .age:
                                age = try valueDecoder.decode(Int.self)
                            case .unknown:
                                break
                            }
                        }
                        guard let userName else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'userName'")
                        }
                        guard let age else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'age'")
                        }
                        return User(userName: userName, age: age)
                    }
                }
            }
            """,
            macros: decodableTestMacros
        )
    }

    @Test func aliasCombinedWithCodingKey() {
        assertMacroExpansion(
            """
            @JSONDecodable
            struct User {
                @CodingKey("user_name") @DecodableAlias("username") let userName: String
            }
            """,
            expandedSource: """
            struct User {
                let userName: String
            }

            extension User {
                enum JSONCodingFields: JSONOptimizedDecodingField {
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

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
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

            extension User: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> User {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var userName: String?
                        var _codingField: JSONCodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(JSONCodingFields.self)
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
            macros: decodableTestMacros
        )
    }

    @Test func aliasMultiple() {
        assertMacroExpansion(
            """
            @JSONDecodable
            struct User {
                @DecodableAlias("a", "b", "c") let name: String
            }
            """,
            expandedSource: """
            struct User {
                let name: String
            }

            extension User {
                enum JSONCodingFields: JSONOptimizedDecodingField {
                    case name
                    case unknown

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .name:
                            "name"
                        case .unknown:
                            fatalError()
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
                        switch UTF8SpanComparator(key) {
                        case "name":
                            .name
                        case "a":
                            .name
                        case "b":
                            .name
                        case "c":
                            .name
                        default:
                            .unknown
                        }
                    }
                }
            }

            extension User: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> User {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var name: String?
                        var _codingField: JSONCodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(JSONCodingFields.self)
                        } andValue: { valueDecoder throws(CodingError.Decoding) in
                            switch _codingField! {
                            case .name:
                                name = try valueDecoder.decode(String.self)
                            case .unknown:
                                break
                            }
                        }
                        guard let name else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'name'")
                        }
                        return User(name: name)
                    }
                }
            }
            """,
            macros: decodableTestMacros
        )
    }

    @Test func publicStructEmitsPublicMembers() {
        assertMacroExpansion(
            """
            @JSONDecodable
            public struct Person {
                public let name: String
            }
            """,
            expandedSource: """
            public struct Person {
                public let name: String
            }

            extension Person {
                enum JSONCodingFields: JSONOptimizedDecodingField {
                    case name
                    case unknown

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .name:
                            "name"
                        case .unknown:
                            fatalError()
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
                        switch UTF8SpanComparator(key) {
                        case "name":
                            .name
                        default:
                            .unknown
                        }
                    }
                }
            }

            extension Person: JSONDecodable {
                public static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Person {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var name: String?
                        var _codingField: JSONCodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(JSONCodingFields.self)
                        } andValue: { valueDecoder throws(CodingError.Decoding) in
                            switch _codingField! {
                            case .name:
                                name = try valueDecoder.decode(String.self)
                            case .unknown:
                                break
                            }
                        }
                        guard let name else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'name'")
                        }
                        return Person(name: name)
                    }
                }
            }
            """,
            macros: decodableTestMacros
        )
    }

    // MARK: - Enum Tests

    @Test func enumNoAssociatedValues() {
        assertMacroExpansion(
            """
            @JSONDecodable
            enum Direction {
                case north
                case south
                case east
                case west
            }
            """,
            expandedSource: """
            enum Direction {
                case north
                case south
                case east
                case west
            }

            extension Direction {
                enum JSONCodingFields: JSONOptimizedDecodingField {
                    case north
                    case south
                    case east
                    case west

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .north:
                            "north"
                        case .south:
                            "south"
                        case .east:
                            "east"
                        case .west:
                            "west"
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
                        switch UTF8SpanComparator(key) {
                        case "north":
                            .north
                        case "south":
                            .south
                        case "east":
                            .east
                        case "west":
                            .west
                        default:
                            throw CodingError.unknownKey(key)
                        }
                    }
                }
            }

            extension Direction: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Direction {
                    var _codingField: JSONCodingFields?
                    return try decoder.decodeEnumCase { fieldDecoder throws(CodingError.Decoding) in
                        _codingField = try fieldDecoder.decode(JSONCodingFields.self)
                    } associatedValues: { valuesDecoder throws(CodingError.Decoding) in
                        return switch _codingField! {
                        case .north:
                            .north
                        case .south:
                            .south
                        case .east:
                            .east
                        case .west:
                            .west
                        }
                    }
                }
            }
            """,
            macros: decodableTestMacros
        )
    }

    @Test func enumWithLabeledAssociatedValues() {
        assertMacroExpansion(
            """
            @JSONDecodable
            enum Shape {
                case circle(radius: Double)
                case rectangle(width: Int, height: Int)
            }
            """,
            expandedSource: """
            enum Shape {
                case circle(radius: Double)
                case rectangle(width: Int, height: Int)
            }

            extension Shape {
                enum JSONCodingFields: JSONOptimizedDecodingField {
                    case circle
                    case rectangle

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .circle:
                            "circle"
                        case .rectangle:
                            "rectangle"
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
                        switch UTF8SpanComparator(key) {
                        case "circle":
                            .circle
                        case "rectangle":
                            .rectangle
                        default:
                            throw CodingError.unknownKey(key)
                        }
                    }

                    enum CircleFields: JSONOptimizedDecodingField {
                        case radius

                        @_transparent
                        var staticString: StaticString {
                            switch self {
                            case .radius:
                                "radius"
                            }
                        }

                        static func field(for key: UTF8Span) throws(CodingError.Decoding) -> CircleFields {
                            switch UTF8SpanComparator(key) {
                            case "radius":
                                .radius
                            default:
                                throw CodingError.unknownKey(key)
                            }
                        }

                        static func decode(from decoder: inout some JSONDictionaryDecoder & ~Escapable) throws(CodingError.Decoding) -> Shape {
                            var radius: Double?
                            var _field: CircleFields?
                            try decoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                                _field = try fieldDecoder.decode(CircleFields.self)
                            } andValue: { valueDecoder throws(CodingError.Decoding) in
                                switch _field! {
                                case .radius:
                                    radius = try valueDecoder.decode(Double.self)
                                }
                            }
                            guard let radius else {
                                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
                            }
                            return .circle(radius: radius)
                        }
                    }

                    enum RectangleFields: JSONOptimizedDecodingField {
                        case width
                        case height

                        @_transparent
                        var staticString: StaticString {
                            switch self {
                            case .width:
                                "width"
                            case .height:
                                "height"
                            }
                        }

                        static func field(for key: UTF8Span) throws(CodingError.Decoding) -> RectangleFields {
                            switch UTF8SpanComparator(key) {
                            case "width":
                                .width
                            case "height":
                                .height
                            default:
                                throw CodingError.unknownKey(key)
                            }
                        }

                        static func decode(from decoder: inout some JSONDictionaryDecoder & ~Escapable) throws(CodingError.Decoding) -> Shape {
                            var width: Int?
                            var height: Int?
                            var _field: RectangleFields?
                            try decoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                                _field = try fieldDecoder.decode(RectangleFields.self)
                            } andValue: { valueDecoder throws(CodingError.Decoding) in
                                switch _field! {
                                case .width:
                                    width = try valueDecoder.decode(Int.self)
                                case .height:
                                    height = try valueDecoder.decode(Int.self)
                                }
                            }
                            guard let width, let height else {
                                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
                            }
                            return .rectangle(width: width, height: height)
                        }
                    }
                }
            }

            extension Shape: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Shape {
                    var _codingField: JSONCodingFields?
                    return try decoder.decodeEnumCase { fieldDecoder throws(CodingError.Decoding) in
                        _codingField = try fieldDecoder.decode(JSONCodingFields.self)
                    } associatedValues: { valuesDecoder throws(CodingError.Decoding) in
                        return switch _codingField! {
                        case .circle:
                            try JSONCodingFields.CircleFields.decode(from: &valuesDecoder)
                        case .rectangle:
                            try JSONCodingFields.RectangleFields.decode(from: &valuesDecoder)
                        }
                    }
                }
            }
            """,
            macros: decodableTestMacros
        )
    }

    @Test func enumMixedCases() {
        assertMacroExpansion(
            """
            @JSONDecodable
            enum Result {
                case success(value: String)
                case failure
            }
            """,
            expandedSource: """
            enum Result {
                case success(value: String)
                case failure
            }

            extension Result {
                enum JSONCodingFields: JSONOptimizedDecodingField {
                    case success
                    case failure

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .success:
                            "success"
                        case .failure:
                            "failure"
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
                        switch UTF8SpanComparator(key) {
                        case "success":
                            .success
                        case "failure":
                            .failure
                        default:
                            throw CodingError.unknownKey(key)
                        }
                    }

                    enum SuccessFields: JSONOptimizedDecodingField {
                        case value

                        @_transparent
                        var staticString: StaticString {
                            switch self {
                            case .value:
                                "value"
                            }
                        }

                        static func field(for key: UTF8Span) throws(CodingError.Decoding) -> SuccessFields {
                            switch UTF8SpanComparator(key) {
                            case "value":
                                .value
                            default:
                                throw CodingError.unknownKey(key)
                            }
                        }

                        static func decode(from decoder: inout some JSONDictionaryDecoder & ~Escapable) throws(CodingError.Decoding) -> Result {
                            var value: String?
                            var _field: SuccessFields?
                            try decoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                                _field = try fieldDecoder.decode(SuccessFields.self)
                            } andValue: { valueDecoder throws(CodingError.Decoding) in
                                switch _field! {
                                case .value:
                                    value = try valueDecoder.decode(String.self)
                                }
                            }
                            guard let value else {
                                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
                            }
                            return .success(value: value)
                        }
                    }
                }
            }

            extension Result: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Result {
                    var _codingField: JSONCodingFields?
                    return try decoder.decodeEnumCase { fieldDecoder throws(CodingError.Decoding) in
                        _codingField = try fieldDecoder.decode(JSONCodingFields.self)
                    } associatedValues: { valuesDecoder throws(CodingError.Decoding) in
                        return switch _codingField! {
                        case .success:
                            try JSONCodingFields.SuccessFields.decode(from: &valuesDecoder)
                        case .failure:
                            .failure
                        }
                    }
                }
            }
            """,
            macros: decodableTestMacros
        )
    }

    @Test func enumWithUnlabeledAssociatedValues() {
        assertMacroExpansion(
            """
            @JSONDecodable
            enum Wrapper {
                case single(Int)
                case pair(String, Int)
            }
            """,
            expandedSource: """
            enum Wrapper {
                case single(Int)
                case pair(String, Int)
            }

            extension Wrapper {
                enum JSONCodingFields: JSONOptimizedDecodingField {
                    case single
                    case pair

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .single:
                            "single"
                        case .pair:
                            "pair"
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
                        switch UTF8SpanComparator(key) {
                        case "single":
                            .single
                        case "pair":
                            .pair
                        default:
                            throw CodingError.unknownKey(key)
                        }
                    }

                    enum SingleFields: JSONOptimizedDecodingField {
                        case _0

                        @_transparent
                        var staticString: StaticString {
                            switch self {
                            case ._0:
                                "_0"
                            }
                        }

                        static func field(for key: UTF8Span) throws(CodingError.Decoding) -> SingleFields {
                            switch UTF8SpanComparator(key) {
                            case "_0":
                                ._0
                            default:
                                throw CodingError.unknownKey(key)
                            }
                        }

                        static func decode(from decoder: inout some JSONDictionaryDecoder & ~Escapable) throws(CodingError.Decoding) -> Wrapper {
                            var _0: Int?
                            var _field: SingleFields?
                            try decoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                                _field = try fieldDecoder.decode(SingleFields.self)
                            } andValue: { valueDecoder throws(CodingError.Decoding) in
                                switch _field! {
                                case ._0:
                                    _0 = try valueDecoder.decode(Int.self)
                                }
                            }
                            guard let _0 else {
                                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
                            }
                            return .single(_0)
                        }
                    }

                    enum PairFields: JSONOptimizedDecodingField {
                        case _0
                        case _1

                        @_transparent
                        var staticString: StaticString {
                            switch self {
                            case ._0:
                                "_0"
                            case ._1:
                                "_1"
                            }
                        }

                        static func field(for key: UTF8Span) throws(CodingError.Decoding) -> PairFields {
                            switch UTF8SpanComparator(key) {
                            case "_0":
                                ._0
                            case "_1":
                                ._1
                            default:
                                throw CodingError.unknownKey(key)
                            }
                        }

                        static func decode(from decoder: inout some JSONDictionaryDecoder & ~Escapable) throws(CodingError.Decoding) -> Wrapper {
                            var _0: String?
                            var _1: Int?
                            var _field: PairFields?
                            try decoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                                _field = try fieldDecoder.decode(PairFields.self)
                            } andValue: { valueDecoder throws(CodingError.Decoding) in
                                switch _field! {
                                case ._0:
                                    _0 = try valueDecoder.decode(String.self)
                                case ._1:
                                    _1 = try valueDecoder.decode(Int.self)
                                }
                            }
                            guard let _0, let _1 else {
                                throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
                            }
                            return .pair(_0, _1)
                        }
                    }
                }
            }

            extension Wrapper: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Wrapper {
                    var _codingField: JSONCodingFields?
                    return try decoder.decodeEnumCase { fieldDecoder throws(CodingError.Decoding) in
                        _codingField = try fieldDecoder.decode(JSONCodingFields.self)
                    } associatedValues: { valuesDecoder throws(CodingError.Decoding) in
                        return switch _codingField! {
                        case .single:
                            try JSONCodingFields.SingleFields.decode(from: &valuesDecoder)
                        case .pair:
                            try JSONCodingFields.PairFields.decode(from: &valuesDecoder)
                        }
                    }
                }
            }
            """,
            macros: decodableTestMacros
        )
    }

    @Test func enumWithCustomCodingKey() {
        assertMacroExpansion(
            """
            @JSONDecodable
            enum Status {
                @CodingKey("in_progress") case inProgress
                case done
            }
            """,
            expandedSource: """
            enum Status {
                case inProgress
                case done
            }

            extension Status {
                enum JSONCodingFields: JSONOptimizedDecodingField {
                    case inProgress
                    case done

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .inProgress:
                            "in_progress"
                        case .done:
                            "done"
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
                        switch UTF8SpanComparator(key) {
                        case "in_progress":
                            .inProgress
                        case "done":
                            .done
                        default:
                            throw CodingError.unknownKey(key)
                        }
                    }
                }
            }

            extension Status: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Status {
                    var _codingField: JSONCodingFields?
                    return try decoder.decodeEnumCase { fieldDecoder throws(CodingError.Decoding) in
                        _codingField = try fieldDecoder.decode(JSONCodingFields.self)
                    } associatedValues: { valuesDecoder throws(CodingError.Decoding) in
                        return switch _codingField! {
                        case .inProgress:
                            .inProgress
                        case .done:
                            .done
                        }
                    }
                }
            }
            """,
            macros: decodableTestMacros
        )
    }

    @Test func enumWithDecodableAlias() {
        assertMacroExpansion(
            """
            @JSONDecodable
            enum Status {
                @DecodableAlias("in-progress") @CodingKey("in_progress") case inProgress
                case done
            }
            """,
            expandedSource: """
            enum Status {
                case inProgress
                case done
            }

            extension Status {
                enum JSONCodingFields: JSONOptimizedDecodingField {
                    case inProgress
                    case done

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .inProgress:
                            "in_progress"
                        case .done:
                            "done"
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
                        switch UTF8SpanComparator(key) {
                        case "in_progress":
                            .inProgress
                        case "in-progress":
                            .inProgress
                        case "done":
                            .done
                        default:
                            throw CodingError.unknownKey(key)
                        }
                    }
                }
            }

            extension Status: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Status {
                    var _codingField: JSONCodingFields?
                    return try decoder.decodeEnumCase { fieldDecoder throws(CodingError.Decoding) in
                        _codingField = try fieldDecoder.decode(JSONCodingFields.self)
                    } associatedValues: { valuesDecoder throws(CodingError.Decoding) in
                        return switch _codingField! {
                        case .inProgress:
                            .inProgress
                        case .done:
                            .done
                        }
                    }
                }
            }
            """,
            macros: decodableTestMacros
        )
    }
}

private let decodableTestMacros: [String: Macro.Type] = [
    "JSONDecodable": JSONDecodableMacro.self,
    "CodingKey": CodingKeyMacro.self,
    "CodableDefault": CodableDefaultMacro.self,
    "DecodableAlias": DecodableAliasMacro.self,
]
