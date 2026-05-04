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
        AssertMacroExpansion(
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
                enum CommonCodingFields: StaticStringCodingField {
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

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> CommonCodingFields {
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
                        try structEncoder.encode(field: CommonCodingFields.name, value: self.name)
                        try structEncoder.encode(field: CommonCodingFields.age, value: self.age)
                    }
                }
            }

            extension Person: CommonDecodable {
                static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> Person {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var name: String?
                        var age: Int?
                        var _codingField: CommonCodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(CommonCodingFields.self)
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
        AssertMacroExpansion(
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
                enum CommonCodingFields: StaticStringCodingField {
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

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> CommonCodingFields {
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
                        try structEncoder.encode(field: CommonCodingFields.name, value: self.name)
                        try structEncoder.encode(field: CommonCodingFields.rating, value: self.rating)
                    }
                }
            }

            extension Item: CommonDecodable {
                static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> Item {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var name: String?
                        var rating: Double?
                        var _codingField: CommonCodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(CommonCodingFields.self)
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
        AssertMacroExpansion(
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
                enum CommonCodingFields: StaticStringCodingField {
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

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> CommonCodingFields {
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
                        try structEncoder.encode(field: CommonCodingFields.publishDate, value: self.publishDate)
                        try structEncoder.encode(field: CommonCodingFields.title, value: self.title)
                    }
                }
            }

            extension Post: CommonDecodable {
                static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> Post {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var publishDate: String?
                        var title: String?
                        var _codingField: CommonCodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(CommonCodingFields.self)
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
        AssertMacroExpansion(
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
        AssertMacroExpansion(
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
                enum CommonCodingFields: StaticStringCodingField {
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

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> CommonCodingFields {
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
                        try structEncoder.encode(field: CommonCodingFields.name, value: self.name)
                        try structEncoder.encode(field: CommonCodingFields.locale, value: self.locale)
                    }
                }
            }

            extension Config: CommonDecodable {
                static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> Config {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var name: String?
                        var locale: String?
                        var _codingField: CommonCodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(CommonCodingFields.self)
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
        AssertMacroExpansion(
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
                enum CommonCodingFields: StaticStringCodingField {
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

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> CommonCodingFields {
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
                        try structEncoder.encode(field: CommonCodingFields.userName, value: self.userName)
                    }
                }
            }

            extension User: CommonDecodable {
                static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> User {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var userName: String?
                        var _codingField: CommonCodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(CommonCodingFields.self)
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
        AssertMacroExpansion(
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
                enum CommonCodingFields: StaticStringCodingField {
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

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> CommonCodingFields {
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
                        try structEncoder.encode(field: CommonCodingFields.userName, value: self.userName)
                    }
                }
            }

            extension User: CommonDecodable {
                static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> User {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var userName: String?
                        var _codingField: CommonCodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(CommonCodingFields.self)
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
        AssertMacroExpansion(
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
                enum CommonCodingFields: StaticStringCodingField {
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

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> CommonCodingFields {
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
                        try structEncoder.encode(field: CommonCodingFields.name, value: self.name)
                        try structEncoder.encode(field: CommonCodingFields.age, value: self.age)
                    }
                }
            }

            extension Person: CommonDecodable {
                public static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> Person {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var name: String?
                        var age: Int?
                        var _codingField: CommonCodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(CommonCodingFields.self)
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
        AssertMacroExpansion(
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
                DiagnosticSpec(message: "@CommonCodable can only be applied to structs or enums", line: 1, column: 1),
            ],
            macros: codableTestMacros
        )
    }

    // MARK: - Enum Tests

    @Test func enumNoAssociatedValues() {
        AssertMacroExpansion(
            """
            @CommonCodable
            enum Direction {
                case north
                case south
            }
            """,
            expandedSource: """
            enum Direction {
                case north
                case south
            }

            extension Direction {
                enum CommonCodingFields: StaticStringCodingField {
                    case north
                    case south

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .north:
                            "north"
                        case .south:
                            "south"
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> CommonCodingFields {
                        switch UTF8SpanComparator(key) {
                        case "north":
                            .north
                        case "south":
                            .south
                        default:
                            throw CodingError.unknownKey(key)
                        }
                    }
                }
            }

            extension Direction: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
                    switch self {
                    case .north:
                        try encoder.encodeEnumCase(CommonCodingFields.north)
                    case .south:
                        try encoder.encodeEnumCase(CommonCodingFields.south)
                    }
                }
            }

            extension Direction: CommonDecodable {
                static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> Direction {
                    var _codingField: CommonCodingFields?
                    return try decoder.decodeEnumCase { fieldDecoder throws(CodingError.Decoding) in
                        _codingField = try fieldDecoder.decode(CommonCodingFields.self)
                    } associatedValues: { valuesDecoder throws(CodingError.Decoding) in
                        return switch _codingField! {
                        case .north:
                            .north
                        case .south:
                            .south
                        }
                    }
                }
            }
            """,
            macros: codableTestMacros
        )
    }

    @Test func enumWithAssociatedValues() {
        AssertMacroExpansion(
            """
            @CommonCodable
            enum Shape {
                case circle(radius: Double)
                case point
            }
            """,
            expandedSource: """
            enum Shape {
                case circle(radius: Double)
                case point
            }

            extension Shape {
                enum CommonCodingFields: StaticStringCodingField {
                    case circle
                    case point

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .circle:
                            "circle"
                        case .point:
                            "point"
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> CommonCodingFields {
                        switch UTF8SpanComparator(key) {
                        case "circle":
                            .circle
                        case "point":
                            .point
                        default:
                            throw CodingError.unknownKey(key)
                        }
                    }

                    enum CircleFields: StaticStringCodingField {
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

                        static func decode(from decoder: inout some CommonStructDecoder & ~Escapable) throws(CodingError.Decoding) -> Shape {
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
                }
            }

            extension Shape: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
                    switch self {
                    case .circle(let radius):
                        try encoder.encodeEnumCase(CommonCodingFields.circle, associatedValueCount: 1) { valueEncoder throws(CodingError.Encoding) in
                            try valueEncoder.encode(field: CommonCodingFields.CircleFields.radius, value: radius)
                        }
                    case .point:
                        try encoder.encodeEnumCase(CommonCodingFields.point)
                    }
                }
            }

            extension Shape: CommonDecodable {
                static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> Shape {
                    var _codingField: CommonCodingFields?
                    return try decoder.decodeEnumCase { fieldDecoder throws(CodingError.Decoding) in
                        _codingField = try fieldDecoder.decode(CommonCodingFields.self)
                    } associatedValues: { valuesDecoder throws(CodingError.Decoding) in
                        return switch _codingField! {
                        case .circle:
                            try CommonCodingFields.CircleFields.decode(from: &valuesDecoder)
                        case .point:
                            .point
                        }
                    }
                }
            }
            """,
            macros: codableTestMacros
        )
    }

    @Test func enumWithUnlabeledAssociatedValues() {
        AssertMacroExpansion(
            """
            @CommonCodable
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
                enum CommonCodingFields: StaticStringCodingField {
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

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> CommonCodingFields {
                        switch UTF8SpanComparator(key) {
                        case "single":
                            .single
                        case "pair":
                            .pair
                        default:
                            throw CodingError.unknownKey(key)
                        }
                    }

                    enum SingleFields: StaticStringCodingField {
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

                        static func decode(from decoder: inout some CommonStructDecoder & ~Escapable) throws(CodingError.Decoding) -> Wrapper {
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

                    enum PairFields: StaticStringCodingField {
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

                        static func decode(from decoder: inout some CommonStructDecoder & ~Escapable) throws(CodingError.Decoding) -> Wrapper {
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

            extension Wrapper: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
                    switch self {
                    case .single(let _0):
                        try encoder.encodeEnumCase(CommonCodingFields.single, associatedValueCount: 1) { valueEncoder throws(CodingError.Encoding) in
                            try valueEncoder.encode(field: CommonCodingFields.SingleFields._0, value: _0)
                        }
                    case .pair(let _0, let _1):
                        try encoder.encodeEnumCase(CommonCodingFields.pair, associatedValueCount: 2) { valueEncoder throws(CodingError.Encoding) in
                            try valueEncoder.encode(field: CommonCodingFields.PairFields._0, value: _0)
                            try valueEncoder.encode(field: CommonCodingFields.PairFields._1, value: _1)
                        }
                    }
                }
            }

            extension Wrapper: CommonDecodable {
                static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> Wrapper {
                    var _codingField: CommonCodingFields?
                    return try decoder.decodeEnumCase { fieldDecoder throws(CodingError.Decoding) in
                        _codingField = try fieldDecoder.decode(CommonCodingFields.self)
                    } associatedValues: { valuesDecoder throws(CodingError.Decoding) in
                        return switch _codingField! {
                        case .single:
                            try CommonCodingFields.SingleFields.decode(from: &valuesDecoder)
                        case .pair:
                            try CommonCodingFields.PairFields.decode(from: &valuesDecoder)
                        }
                    }
                }
            }
            """,
            macros: codableTestMacros
        )
    }

    @Test func enumWithCustomCodingKey() {
        AssertMacroExpansion(
            """
            @CommonCodable
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
                enum CommonCodingFields: StaticStringCodingField {
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

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> CommonCodingFields {
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

            extension Status: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
                    switch self {
                    case .inProgress:
                        try encoder.encodeEnumCase(CommonCodingFields.inProgress)
                    case .done:
                        try encoder.encodeEnumCase(CommonCodingFields.done)
                    }
                }
            }

            extension Status: CommonDecodable {
                static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> Status {
                    var _codingField: CommonCodingFields?
                    return try decoder.decodeEnumCase { fieldDecoder throws(CodingError.Decoding) in
                        _codingField = try fieldDecoder.decode(CommonCodingFields.self)
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
            macros: codableTestMacros
        )
    }

    @Test func enumWithDecodableAlias() {
        AssertMacroExpansion(
            """
            @CommonCodable
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
                enum CommonCodingFields: StaticStringCodingField {
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

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> CommonCodingFields {
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

            extension Status: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
                    switch self {
                    case .inProgress:
                        try encoder.encodeEnumCase(CommonCodingFields.inProgress)
                    case .done:
                        try encoder.encodeEnumCase(CommonCodingFields.done)
                    }
                }
            }

            extension Status: CommonDecodable {
                static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> Status {
                    var _codingField: CommonCodingFields?
                    return try decoder.decodeEnumCase { fieldDecoder throws(CodingError.Decoding) in
                        _codingField = try fieldDecoder.decode(CommonCodingFields.self)
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
