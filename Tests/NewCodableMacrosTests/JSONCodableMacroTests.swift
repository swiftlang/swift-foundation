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
        assertMacroExpansion(
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

                enum CodingFields: Int, JSONOptimizedCodingField {
                    case name
                    case age

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .name: "name"
                        case .age: "age"
                        }
                    }
                }
            }

            extension Person: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 2) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: CodingFields.name, value: self.name)
                        try structEncoder.encode(field: CodingFields.age, value: self.age)
                    }
                }
            }

            extension Person: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Person {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var name: String?
                        var age: Int?
                        try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                            switch key {
                            case "name": name = try valueDecoder.decode(String.self)
                            case "age": age = try valueDecoder.decode(Int.self)
                            default: break
                            }
                            return false
                        }
                        guard let name, let age else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
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

                enum CodingFields: Int, JSONOptimizedCodingField {
                    case name
                    case rating

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .name: "name"
                        case .rating: "rating"
                        }
                    }
                }
            }

            extension Item: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 2) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: CodingFields.name, value: self.name)
                        try structEncoder.encode(field: CodingFields.rating, value: self.rating)
                    }
                }
            }

            extension Item: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Item {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var name: String?
                        var rating: Double?
                        try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                            switch key {
                            case "name": name = try valueDecoder.decode(String.self)
                            case "rating": rating = try valueDecoder.decode(Double.self)
                            default: break
                            }
                            return false
                        }
                        guard let name else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
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

                enum CodingFields: Int, JSONOptimizedCodingField {
                    case publishDate
                    case title

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .publishDate: "date_published"
                        case .title: "title"
                        }
                    }
                }
            }

            extension Post: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 2) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: CodingFields.publishDate, value: self.publishDate)
                        try structEncoder.encode(field: CodingFields.title, value: self.title)
                    }
                }
            }

            extension Post: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Post {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var publishDate: String?
                        var title: String?
                        try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                            switch key {
                            case "date_published": publishDate = try valueDecoder.decode(String.self)
                            case "title": title = try valueDecoder.decode(String.self)
                            default: break
                            }
                            return false
                        }
                        guard let publishDate, let title else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
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
            @JSONCodable
            struct Empty {
            }
            """,
            expandedSource: """
            struct Empty {
            }

            extension Empty: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 0) { _ throws(CodingError.Encoding) in }
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

    @Test func errorOnNonStruct() {
        assertMacroExpansion(
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
                DiagnosticSpec(message: "@JSONEncodable can only be applied to structs", line: 1, column: 1),
                DiagnosticSpec(message: "@JSONDecodable can only be applied to structs", line: 1, column: 1),
            ],
            macros: codableTestMacros
        )
    }
}

private let codableTestMacros: [String: Macro.Type] = [
    "JSONCodable": JSONCodableMacro.self,
    "CodingKey": CodingKeyMacro.self,
]
