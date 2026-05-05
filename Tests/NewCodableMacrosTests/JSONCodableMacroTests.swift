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

@Suite("@JSONCodable Macro")
struct JSONCodableMacroTests {

    @Test func basicStruct() {
        AssertMacroExpansion(
            """
            @JSONCodable
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
                enum JSONCodingFields: JSONOptimizedCodingField {
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

            extension Person: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 2) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: JSONCodingFields.name, value: self.name)
                        try structEncoder.encode(field: JSONCodingFields.age, value: self.age)
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
            macros: codableTestMacros
        )
    }

    @Test func optionalProperty() {
        AssertMacroExpansion(
            """
            @JSONCodable
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
                enum JSONCodingFields: JSONOptimizedCodingField {
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

            extension Item: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 2) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: JSONCodingFields.name, value: self.name)
                        try structEncoder.encode(field: JSONCodingFields.rating, value: self.rating)
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
            macros: codableTestMacros
        )
    }

    @Test func customCodingKey() {
        AssertMacroExpansion(
            """
            @JSONCodable
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
                enum JSONCodingFields: JSONOptimizedCodingField {
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

            extension Post: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 2) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: JSONCodingFields.publishDate, value: self.publishDate)
                        try structEncoder.encode(field: JSONCodingFields.title, value: self.title)
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
            macros: codableTestMacros
        )
    }

    @Test func emptyStruct() {
        AssertMacroExpansion(
            """
            @JSONCodable
            struct Empty {
            }
            """,
            expandedSource: """
            struct Empty {
            }

            extension Empty: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 0) { _ throws(CodingError.Encoding) in
                    }
                }
            }

            extension Empty: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Empty {
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
            @JSONCodable
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
                enum JSONCodingFields: JSONOptimizedCodingField {
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

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
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

            extension Config: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 2) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: JSONCodingFields.name, value: self.name)
                        try structEncoder.encode(field: JSONCodingFields.locale, value: self.locale)
                    }
                }
            }

            extension Config: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Config {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var name: String?
                        var locale: String?
                        var _codingField: JSONCodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(JSONCodingFields.self)
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
            @JSONCodable
            struct User {
                @DecodableAlias("user_name") let userName: String
            }
            """,
            expandedSource: """
            struct User {
                let userName: String
            }
            
            extension User {
                enum JSONCodingFields: JSONOptimizedCodingField {
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

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
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

            extension User: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 1) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: JSONCodingFields.userName, value: self.userName)
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
            @JSONCodable
            struct User {
                @CodingKey("user_name") @DecodableAlias("username") let userName: String
            }
            """,
            expandedSource: """
            struct User {
                let userName: String
            }
            
            extension User {
                enum JSONCodingFields: JSONOptimizedCodingField {
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

            extension User: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 1) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: JSONCodingFields.userName, value: self.userName)
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
            macros: codableTestMacros
        )
    }

    @Test func publicStructEmitsPublicMembers() {
        AssertMacroExpansion(
            """
            @JSONCodable
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
                enum JSONCodingFields: JSONOptimizedCodingField {
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

            extension Person: JSONEncodable {
                public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 2) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: JSONCodingFields.name, value: self.name)
                        try structEncoder.encode(field: JSONCodingFields.age, value: self.age)
                    }
                }
            }

            extension Person: JSONDecodable {
                public static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Person {
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
            macros: codableTestMacros
        )
    }

    @Test func packageStructEmitsPackageMembers() {
        AssertMacroExpansion(
            """
            @JSONCodable
            package struct Person {
                package let name: String
            }
            """,
            expandedSource: """
            package struct Person {
                package let name: String
            }

            extension Person {
                enum JSONCodingFields: JSONOptimizedCodingField {
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

            extension Person: JSONEncodable {
                package func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 1) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: JSONCodingFields.name, value: self.name)
                    }
                }
            }

            extension Person: JSONDecodable {
                package static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Person {
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
            macros: codableTestMacros
        )
    }

    @Test func errorOnNonStruct() {
        AssertMacroExpansion(
            """
            @JSONCodable
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
                DiagnosticSpec(message: "@JSONCodable can only be applied to structs or enums", line: 1, column: 1),
            ],
            macros: codableTestMacros
        )
    }

    // MARK: - Enum Tests

    @Test func enumNoAssociatedValues() {
        AssertMacroExpansion(
            """
            @JSONCodable
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
                enum JSONCodingFields: JSONOptimizedCodingField {
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

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
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

            extension Direction: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    switch self {
                    case .north:
                        try encoder.encodeEnumCase(JSONCodingFields.north)
                    case .south:
                        try encoder.encodeEnumCase(JSONCodingFields.south)
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
            @JSONCodable
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
                enum JSONCodingFields: JSONOptimizedCodingField {
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

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
                        switch UTF8SpanComparator(key) {
                        case "circle":
                            .circle
                        case "point":
                            .point
                        default:
                            throw CodingError.unknownKey(key)
                        }
                    }

                    enum CircleFields: JSONOptimizedCodingField {
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
                }
            }

            extension Shape: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    switch self {
                    case .circle(let radius):
                        try encoder.encodeEnumCase(JSONCodingFields.circle, associatedValueCount: 1) { valueEncoder throws(CodingError.Encoding) in
                            try valueEncoder.encode(field: JSONCodingFields.CircleFields.radius, value: radius)
                        }
                    case .point:
                        try encoder.encodeEnumCase(JSONCodingFields.point)
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

    @Test func enumWithCustomCodingKey() {
        AssertMacroExpansion(
            """
            @JSONCodable
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
                enum JSONCodingFields: JSONOptimizedCodingField {
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

            extension Status: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    switch self {
                    case .inProgress:
                        try encoder.encodeEnumCase(JSONCodingFields.inProgress)
                    case .done:
                        try encoder.encodeEnumCase(JSONCodingFields.done)
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
            macros: codableTestMacros
        )
    }

    @Test func enumWithDecodableAlias() {
        AssertMacroExpansion(
            """
            @JSONCodable
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
                enum JSONCodingFields: JSONOptimizedCodingField {
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

            extension Status: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    switch self {
                    case .inProgress:
                        try encoder.encodeEnumCase(JSONCodingFields.inProgress)
                    case .done:
                        try encoder.encodeEnumCase(JSONCodingFields.done)
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
            macros: codableTestMacros
        )
    }


    // MARK: - CodableBy tests

    @Test func codableBy() {
        AssertMacroExpansion(
        """
        @JSONCodable
        struct MyType {
            @CodableBy(.dateFormat(.iso8601))
            let foo: Date
        }
        """,
        expandedSource:
        """
        struct MyType {
            let foo: Date
        }

        extension MyType {
            enum JSONCodingFields: JSONOptimizedCodingField {
                case foo
                case unknown

                @_transparent
                var staticString: StaticString {
                    switch self {
                    case .foo:
                        "foo"
                    case .unknown:
                        fatalError()
                    }
                }

                static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
                    switch UTF8SpanComparator(key) {
                    case "foo":
                        .foo
                    default:
                        .unknown
                    }
                }
            }
        }

        extension MyType: JSONEncodable {
            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeStructFields(count: 1) { structEncoder throws(CodingError.Encoding) in
                    try structEncoder.encode(field: JSONCodingFields.foo) { valueEncoder throws(CodingError.Encoding) in
                        try valueEncoder.encode(self.foo, using: .dateFormat(.iso8601))
                    }
                }
            }
        }

        extension MyType: JSONDecodable {
            static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> MyType {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var foo: Date?
                    var _codingField: JSONCodingFields?
                    try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                        _codingField = try fieldDecoder.decode(JSONCodingFields.self)
                    } andValue: { valueDecoder throws(CodingError.Decoding) in
                        switch _codingField! {
                        case .foo:
                            foo = try valueDecoder.decode(using: .dateFormat(.iso8601))
                        case .unknown:
                            break
                        }
                    }
                    guard let foo else {
                        throw CodingError.dataCorrupted(debugDescription: "Missing required field 'foo'")
                    }
                    return MyType(foo: foo)
                }
            }
        }
        """,
        macros: codableTestMacros)
    }

    @Test func codableByISO8601WithOptions() {
        AssertMacroExpansion(
        """
        @JSONCodable
        struct MyType {
            @CodableBy(.dateFormat(.iso8601(.init(includingFractionalSeconds: true))))
            let timestamp: Date
        }
        """,
        expandedSource:
        """
        struct MyType {
            let timestamp: Date
        }

        extension MyType {
            enum JSONCodingFields: JSONOptimizedCodingField {
                case timestamp
                case unknown

                @_transparent
                var staticString: StaticString {
                    switch self {
                    case .timestamp:
                        "timestamp"
                    case .unknown:
                        fatalError()
                    }
                }

                static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
                    switch UTF8SpanComparator(key) {
                    case "timestamp":
                        .timestamp
                    default:
                        .unknown
                    }
                }
            }
        }

        extension MyType: JSONEncodable {
            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeStructFields(count: 1) { structEncoder throws(CodingError.Encoding) in
                    try structEncoder.encode(field: JSONCodingFields.timestamp) { valueEncoder throws(CodingError.Encoding) in
                        try valueEncoder.encode(self.timestamp, using: .dateFormat(.iso8601(.init(includingFractionalSeconds: true))))
                    }
                }
            }
        }

        extension MyType: JSONDecodable {
            static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> MyType {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var timestamp: Date?
                    var _codingField: JSONCodingFields?
                    try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                        _codingField = try fieldDecoder.decode(JSONCodingFields.self)
                    } andValue: { valueDecoder throws(CodingError.Decoding) in
                        switch _codingField! {
                        case .timestamp:
                            timestamp = try valueDecoder.decode(using: .dateFormat(.iso8601(.init(includingFractionalSeconds: true))))
                        case .unknown:
                            break
                        }
                    }
                    guard let timestamp else {
                        throw CodingError.dataCorrupted(debugDescription: "Missing required field 'timestamp'")
                    }
                    return MyType(timestamp: timestamp)
                }
            }
        }
        """,
        macros: codableTestMacros)
    }

    @Test func codableByBase64() {
        AssertMacroExpansion(
        """
        @JSONCodable
        struct MyType {
            @CodableBy(.base64)
            let payload: Data
        }
        """,
        expandedSource:
        """
        struct MyType {
            let payload: Data
        }

        extension MyType {
            enum JSONCodingFields: JSONOptimizedCodingField {
                case payload
                case unknown

                @_transparent
                var staticString: StaticString {
                    switch self {
                    case .payload:
                        "payload"
                    case .unknown:
                        fatalError()
                    }
                }

                static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
                    switch UTF8SpanComparator(key) {
                    case "payload":
                        .payload
                    default:
                        .unknown
                    }
                }
            }
        }

        extension MyType: JSONEncodable {
            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeStructFields(count: 1) { structEncoder throws(CodingError.Encoding) in
                    try structEncoder.encode(field: JSONCodingFields.payload) { valueEncoder throws(CodingError.Encoding) in
                        try valueEncoder.encode(self.payload, using: .base64)
                    }
                }
            }
        }

        extension MyType: JSONDecodable {
            static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> MyType {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var payload: Data?
                    var _codingField: JSONCodingFields?
                    try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                        _codingField = try fieldDecoder.decode(JSONCodingFields.self)
                    } andValue: { valueDecoder throws(CodingError.Decoding) in
                        switch _codingField! {
                        case .payload:
                            payload = try valueDecoder.decode(using: .base64)
                        case .unknown:
                            break
                        }
                    }
                    guard let payload else {
                        throw CodingError.dataCorrupted(debugDescription: "Missing required field 'payload'")
                    }
                    return MyType(payload: payload)
                }
            }
        }
        """,
        macros: codableTestMacros)
    }

    @Test func codableByMultipleFields() {
        AssertMacroExpansion(
        """
        @JSONCodable
        struct MyType {
            @CodableBy(.dateFormat(.iso8601))
            let createdAt: Date
            let name: String
            @CodableBy(.base64)
            let data: Data
        }
        """,
        expandedSource:
        """
        struct MyType {
            let createdAt: Date
            let name: String
            let data: Data
        }

        extension MyType {
            enum JSONCodingFields: JSONOptimizedCodingField {
                case createdAt
                case name
                case data
                case unknown

                @_transparent
                var staticString: StaticString {
                    switch self {
                    case .createdAt:
                        "createdAt"
                    case .name:
                        "name"
                    case .data:
                        "data"
                    case .unknown:
                        fatalError()
                    }
                }

                static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
                    switch UTF8SpanComparator(key) {
                    case "createdAt":
                        .createdAt
                    case "name":
                        .name
                    case "data":
                        .data
                    default:
                        .unknown
                    }
                }
            }
        }

        extension MyType: JSONEncodable {
            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeStructFields(count: 3) { structEncoder throws(CodingError.Encoding) in
                    try structEncoder.encode(field: JSONCodingFields.createdAt) { valueEncoder throws(CodingError.Encoding) in
                        try valueEncoder.encode(self.createdAt, using: .dateFormat(.iso8601))
                    }
                    try structEncoder.encode(field: JSONCodingFields.name, value: self.name)
                    try structEncoder.encode(field: JSONCodingFields.data) { valueEncoder throws(CodingError.Encoding) in
                        try valueEncoder.encode(self.data, using: .base64)
                    }
                }
            }
        }

        extension MyType: JSONDecodable {
            static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> MyType {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var createdAt: Date?
                    var name: String?
                    var data: Data?
                    var _codingField: JSONCodingFields?
                    try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                        _codingField = try fieldDecoder.decode(JSONCodingFields.self)
                    } andValue: { valueDecoder throws(CodingError.Decoding) in
                        switch _codingField! {
                        case .createdAt:
                            createdAt = try valueDecoder.decode(using: .dateFormat(.iso8601))
                        case .name:
                            name = try valueDecoder.decode(String.self)
                        case .data:
                            data = try valueDecoder.decode(using: .base64)
                        case .unknown:
                            break
                        }
                    }
                    guard let createdAt else {
                        throw CodingError.dataCorrupted(debugDescription: "Missing required field 'createdAt'")
                    }
                    guard let name else {
                        throw CodingError.dataCorrupted(debugDescription: "Missing required field 'name'")
                    }
                    guard let data else {
                        throw CodingError.dataCorrupted(debugDescription: "Missing required field 'data'")
                    }
                    return MyType(createdAt: createdAt, name: name, data: data)
                }
            }
        }
        """,
        macros: codableTestMacros)
    }
    
    @Test func codableByComplex() {
        AssertMacroExpansion("""
            @JSONCodable
            struct CodableByDictionaryWithLosslessKeyAndArrayValue {
                @CodableBy([.pass : [.dateFormat(.iso8601)]])
                let schedule: [UInt8: [Date]]
            }
            """,
            expandedSource: """
            struct CodableByDictionaryWithLosslessKeyAndArrayValue {
                let schedule: [UInt8: [Date]]
            }

            extension CodableByDictionaryWithLosslessKeyAndArrayValue {
                enum JSONCodingFields: JSONOptimizedCodingField {
                    case schedule
                    case unknown

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .schedule:
                            "schedule"
                        case .unknown:
                            fatalError()
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
                        switch UTF8SpanComparator(key) {
                        case "schedule":
                            .schedule
                        default:
                            .unknown
                        }
                    }
                }
            }

            extension CodableByDictionaryWithLosslessKeyAndArrayValue: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 1) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: JSONCodingFields.schedule) { valueEncoder throws(CodingError.Encoding) in
                            try valueEncoder.encode(self.schedule, using: .dictionary(key: .passthrough(), value: .array(.dateFormat(.iso8601))))
                        }
                    }
                }
            }

            extension CodableByDictionaryWithLosslessKeyAndArrayValue: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> CodableByDictionaryWithLosslessKeyAndArrayValue {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var schedule: [UInt8: [Date]]?
                        var _codingField: JSONCodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(JSONCodingFields.self)
                        } andValue: { valueDecoder throws(CodingError.Decoding) in
                            switch _codingField! {
                            case .schedule:
                                schedule = try valueDecoder.decode(using: .dictionary(key: .passthrough(), value: .array(.dateFormat(.iso8601))))
                            case .unknown:
                                break
                            }
                        }
                        guard let schedule else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'schedule'")
                        }
                        return CodableByDictionaryWithLosslessKeyAndArrayValue(schedule: schedule)
                    }
                }
            }
            """,
            macros: codableTestMacros)
    }

    // MARK: - CodableBy diagnostic tests

    @Test func codableByInvalidCollectionLiterals() {
        AssertMacroExpansion(
        """
        @JSONCodable
        struct BadStrategies {
            @CodableBy([.losslessStringConversion, .pass])
            let tooManyArray: [Int]
            @CodableBy([])
            let emptyArray: [Int]
            @CodableBy([:])
            let emptyDict: [Int:String]
            @CodableBy([.losslessStringConversion : .pass, .pass : .losslessStringConversion])
            let tooManyDict: [Int:String]
        }
        """,
        expandedSource:
        """
        struct BadStrategies {
            let tooManyArray: [Int]
            let emptyArray: [Int]
            let emptyDict: [Int:String]
            let tooManyDict: [Int:String]
        }

        extension BadStrategies {
            enum JSONCodingFields: JSONOptimizedCodingField {
                case tooManyArray
                case emptyArray
                case emptyDict
                case tooManyDict
                case unknown

                @_transparent
                var staticString: StaticString {
                    switch self {
                    case .tooManyArray:
                        "tooManyArray"
                    case .emptyArray:
                        "emptyArray"
                    case .emptyDict:
                        "emptyDict"
                    case .tooManyDict:
                        "tooManyDict"
                    case .unknown:
                        fatalError()
                    }
                }

                static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
                    switch UTF8SpanComparator(key) {
                    case "tooManyArray":
                        .tooManyArray
                    case "emptyArray":
                        .emptyArray
                    case "emptyDict":
                        .emptyDict
                    case "tooManyDict":
                        .tooManyDict
                    default:
                        .unknown
                    }
                }
            }
        }

        extension BadStrategies: JSONEncodable {
            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeStructFields(count: 4) { structEncoder throws(CodingError.Encoding) in
                    try structEncoder.encode(field: JSONCodingFields.tooManyArray) { valueEncoder throws(CodingError.Encoding) in
                        try valueEncoder.encode(self.tooManyArray, using: [.losslessStringConversion, .pass])
                    }
                    try structEncoder.encode(field: JSONCodingFields.emptyArray) { valueEncoder throws(CodingError.Encoding) in
                        try valueEncoder.encode(self.emptyArray, using: [])
                    }
                    try structEncoder.encode(field: JSONCodingFields.emptyDict) { valueEncoder throws(CodingError.Encoding) in
                        try valueEncoder.encode(self.emptyDict, using: [:])
                    }
                    try structEncoder.encode(field: JSONCodingFields.tooManyDict) { valueEncoder throws(CodingError.Encoding) in
                        try valueEncoder.encode(self.tooManyDict, using: [.losslessStringConversion : .pass, .pass : .losslessStringConversion])
                    }
                }
            }
        }

        extension BadStrategies: JSONDecodable {
            static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> BadStrategies {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var tooManyArray: [Int]?
                    var emptyArray: [Int]?
                    var emptyDict: [Int: String]?
                    var tooManyDict: [Int: String]?
                    var _codingField: JSONCodingFields?
                    try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                        _codingField = try fieldDecoder.decode(JSONCodingFields.self)
                    } andValue: { valueDecoder throws(CodingError.Decoding) in
                        switch _codingField! {
                        case .tooManyArray:
                            tooManyArray = try valueDecoder.decode(using: [.losslessStringConversion, .pass])
                        case .emptyArray:
                            emptyArray = try valueDecoder.decode(using: [])
                        case .emptyDict:
                            emptyDict = try valueDecoder.decode(using: [:])
                        case .tooManyDict:
                            tooManyDict = try valueDecoder.decode(using: [.losslessStringConversion : .pass, .pass : .losslessStringConversion])
                        case .unknown:
                            break
                        }
                    }
                    guard let tooManyArray else {
                        throw CodingError.dataCorrupted(debugDescription: "Missing required field 'tooManyArray'")
                    }
                    guard let emptyArray else {
                        throw CodingError.dataCorrupted(debugDescription: "Missing required field 'emptyArray'")
                    }
                    guard let emptyDict else {
                        throw CodingError.dataCorrupted(debugDescription: "Missing required field 'emptyDict'")
                    }
                    guard let tooManyDict else {
                        throw CodingError.dataCorrupted(debugDescription: "Missing required field 'tooManyDict'")
                    }
                    return BadStrategies(tooManyArray: tooManyArray, emptyArray: emptyArray, emptyDict: emptyDict, tooManyDict: tooManyDict)
                }
            }
        }
        """,
        diagnostics: [
            DiagnosticSpec(message: "@CodableBy array literal must contain exactly one element (the element strategy)", line: 3, column: 16),
            DiagnosticSpec(message: "@CodableBy array literal must contain exactly one element (the element strategy)", line: 5, column: 16),
            DiagnosticSpec(message: "@CodableBy dictionary literal must contain exactly one key-value pair (the key and value strategies)", line: 7, column: 16),
            DiagnosticSpec(message: "@CodableBy dictionary literal must contain exactly one key-value pair (the key and value strategies)", line: 9, column: 16),
        ],
        macros: codableTestMacros)
    }
}

private let codableTestMacros: [String: Macro.Type] = [
    "JSONCodable": JSONCodableMacro.self,
    "CodingKey": CodingKeyMacro.self,
    "CodableDefault": CodableDefaultMacro.self,
    "CodableBy": CodableByMacro.self,
    "DecodableAlias": DecodableAliasMacro.self,
]
