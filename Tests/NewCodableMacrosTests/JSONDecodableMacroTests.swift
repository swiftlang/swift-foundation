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

            extension Preferences: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Preferences {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var theme: String?
                        var fontSize: Int?
                        try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                            switch key {
                            case "theme": theme = try valueDecoder.decode(String.self)
                            case "fontSize": fontSize = try valueDecoder.decode(Int.self)
                            default: break
                            }
                            return false
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

            extension Thing: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Thing {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var name: String?
                        try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                            switch key {
                            case "name": name = try valueDecoder.decode(String.self)
                            default: break
                            }
                            return false
                        }
                        guard let name else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
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

            extension Config: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Config {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var name: String?
                        try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                            switch key {
                            case "name": name = try valueDecoder.decode(String.self)
                            default: break
                            }
                            return false
                        }
                        guard let name else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
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

            extension Cached: JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> Cached {
                    try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                        var name: String?
                        try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                            switch key {
                            case "name": name = try valueDecoder.decode(String.self)
                            default: break
                            }
                            return false
                        }
                        guard let name else {
                            throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
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
                DiagnosticSpec(message: "@JSONDecodable can only be applied to structs", line: 1, column: 1)
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
                DiagnosticSpec(message: "@JSONDecodable requires all stored properties to have explicit type annotations", line: 3, column: 5)
            ],
            macros: decodableTestMacros
        )
    }
}

private let decodableTestMacros: [String: Macro.Type] = [
    "JSONDecodable": JSONDecodableMacro.self,
    "CodingKey": CodingKeyMacro.self,
]
