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

/// Tests that verify correct behavior when multiple codable macros are stacked
/// on a single type. Each macro generates its own independent JSONCodingFields type:
/// - JSON macros generate `JSONCodingFields` (conforming to JSONOptimized*Field protocols)
/// - Common macros generate `CommonCodingFields` (conforming to StaticString*Field protocols)
///
/// Each macro always generates its own fields unconditionally, regardless of order.
@Suite("Combined Codable Macros")
struct CombinedMacroTests {

    // MARK: - @JSONCodable @CommonCodable (JSON first)

    @Test func jsonCodableAndCommonCodable() {
        assertMacroExpansion(
            """
            @JSONCodable @CommonCodable
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
            macros: combinedTestMacros
        )
    }

    // MARK: - @CommonCodable @JSONCodable (Common first — order independence)

    @Test func commonCodableAndJSONCodable() {
        assertMacroExpansion(
            """
            @CommonCodable @JSONCodable
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
            macros: combinedTestMacros
        )
    }

    // MARK: - Mixed partial macros

    @Test func jsonEncodableAndCommonDecodable() {
        assertMacroExpansion(
            """
            @JSONEncodable @CommonDecodable
            struct Item {
                let name: String
                let value: Int
            }
            """,
            expandedSource: """
            struct Item {
                let name: String
                let value: Int
            }

            extension Item {
                enum JSONCodingFields: JSONOptimizedEncodingField {
                    case name
                    case value

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .name:
                            "name"
                        case .value:
                            "value"
                        }
                    }
                }
            }

            extension Item: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 2) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: JSONCodingFields.name, value: self.name)
                        try structEncoder.encode(field: JSONCodingFields.value, value: self.value)
                    }
                }
            }

            extension Item {
                enum CommonCodingFields: StaticStringDecodingField {
                    case name
                    case value
                    case unknown

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .name:
                            "name"
                        case .value:
                            "value"
                        case .unknown:
                            fatalError()
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> CommonCodingFields {
                        switch UTF8SpanComparator(key) {
                        case "name":
                            .name
                        case "value":
                            .value
                        default:
                            .unknown
                        }
                    }
                }
            }

            extension Item: CommonDecodable {
                static func decode(from decoder: inout some CommonDecoder & ~Escapable) throws(CodingError.Decoding) -> Item {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var name: String?
                        var value: Int?
                        var _codingField: CommonCodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(CommonCodingFields.self)
                        } andValue: { valueDecoder throws(CodingError.Decoding) in
                            switch _codingField! {
                            case .name:
                                name = try valueDecoder.decode(String.self)
                            case .value:
                                value = try valueDecoder.decode(Int.self)
                            case .unknown:
                                break
                            }
                        }
                        guard let name else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'name'")
                        }
                        guard let value else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'value'")
                        }
                        return Item(name: name, value: value)
                    }
                }
            }
            """,
            macros: combinedTestMacros
        )
    }

    @Test func commonEncodableAndJSONDecodable() {
        assertMacroExpansion(
            """
            @CommonEncodable @JSONDecodable
            struct Item {
                let name: String
                let value: Int
            }
            """,
            expandedSource: """
            struct Item {
                let name: String
                let value: Int
            }

            extension Item {
                enum CommonCodingFields: StaticStringEncodingField {
                    case name
                    case value

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .name:
                            "name"
                        case .value:
                            "value"
                        }
                    }
                }
            }

            extension Item: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 2) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: CommonCodingFields.name, value: self.name)
                        try structEncoder.encode(field: CommonCodingFields.value, value: self.value)
                    }
                }
            }

            extension Item {
                enum JSONCodingFields: JSONOptimizedDecodingField {
                    case name
                    case value
                    case unknown

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .name:
                            "name"
                        case .value:
                            "value"
                        case .unknown:
                            fatalError()
                        }
                    }

                    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> JSONCodingFields {
                        switch UTF8SpanComparator(key) {
                        case "name":
                            .name
                        case "value":
                            .value
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
                        var value: Int?
                        var _codingField: JSONCodingFields?
                        try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                            _codingField = try fieldDecoder.decode(JSONCodingFields.self)
                        } andValue: { valueDecoder throws(CodingError.Decoding) in
                            switch _codingField! {
                            case .name:
                                name = try valueDecoder.decode(String.self)
                            case .value:
                                value = try valueDecoder.decode(Int.self)
                            case .unknown:
                                break
                            }
                        }
                        guard let name else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'name'")
                        }
                        guard let value else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required field 'value'")
                        }
                        return Item(name: name, value: value)
                    }
                }
            }
            """,
            macros: combinedTestMacros
        )
    }

    // MARK: - Empty struct with both macros

    @Test func emptyStructWithBothMacros() {
        assertMacroExpansion(
            """
            @JSONCodable @CommonCodable
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
            macros: combinedTestMacros
        )
    }

    // MARK: - Custom CodingKey with both macros

    @Test func customCodingKeyWithBothMacros() {
        assertMacroExpansion(
            """
            @JSONCodable @CommonCodable
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
            macros: combinedTestMacros
        )
    }

    // MARK: - Enum with both macros

    @Test func enumWithBothMacros() {
        assertMacroExpansion(
            """
            @JSONCodable @CommonCodable
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
            macros: combinedTestMacros
        )
    }

    // MARK: - Enum with associated values and both macros

    @Test func enumWithAssociatedValuesAndBothMacros() {
        assertMacroExpansion(
            """
            @JSONCodable @CommonCodable
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
            macros: combinedTestMacros
        )
    }
}

private let combinedTestMacros: [String: Macro.Type] = [
    "JSONCodable": JSONCodableMacro.self,
    "JSONEncodable": JSONEncodableMacro.self,
    "JSONDecodable": JSONDecodableMacro.self,
    "CommonCodable": CommonCodableMacro.self,
    "CommonEncodable": CommonEncodableMacro.self,
    "CommonDecodable": CommonDecodableMacro.self,
    "CodingKey": CodingKeyMacro.self,
    "CodableDefault": CodableDefaultMacro.self,
    "DecodableAlias": DecodableAliasMacro.self,
]
