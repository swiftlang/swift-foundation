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

let testMacros: [String: Macro.Type] = [
    "JSONEncodable": JSONEncodableMacro.self,
    "CodingKey": CodingKeyMacro.self,
    "DecodableAlias": DecodableAliasMacro.self,
]

@Suite("@JSONEncodable Macro")
struct JSONEncodableMacroTests {

    @Test func basicStruct() {
        assertMacroExpansion(
            """
            @JSONEncodable
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
                enum CodingFields: JSONOptimizedEncodingField {
                    case name
                    case age

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .name:
                            "name"
                        case .age:
                            "age"
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
            """,
            macros: testMacros
        )
    }

    @Test func customCodingKey() {
        assertMacroExpansion(
            """
            @JSONEncodable
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
                enum CodingFields: JSONOptimizedEncodingField {
                    case publishDate
                    case title

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .publishDate:
                            "date_published"
                        case .title:
                            "title"
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
            """,
            macros: testMacros
        )
    }

    @Test func optionalProperty() {
        assertMacroExpansion(
            """
            @JSONEncodable
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
                enum CodingFields: JSONOptimizedEncodingField {
                    case name
                    case rating

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .name:
                            "name"
                        case .rating:
                            "rating"
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
            """,
            macros: testMacros
        )
    }

    @Test func computedPropertySkipped() {
        assertMacroExpansion(
            """
            @JSONEncodable
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
                enum CodingFields: JSONOptimizedEncodingField {
                    case name

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .name:
                            "name"
                        }
                    }
                }
            }

            extension Thing: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 1) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: CodingFields.name, value: self.name)
                    }
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test func staticPropertySkipped() {
        assertMacroExpansion(
            """
            @JSONEncodable
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
                enum CodingFields: JSONOptimizedEncodingField {
                    case name

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .name:
                            "name"
                        }
                    }
                }
            }

            extension Config: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 1) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: CodingFields.name, value: self.name)
                    }
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test func errorOnNonStruct() {
        assertMacroExpansion(
            """
            @JSONEncodable
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
                DiagnosticSpec(message: "@JSONEncodable can only be applied to structs", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }

    @Test func emptyStruct() {
        assertMacroExpansion(
            """
            @JSONEncodable
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
            """,
            macros: testMacros
        )
    }

    @Test func lazyVarSkipped() {
        assertMacroExpansion(
            """
            @JSONEncodable
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
                enum CodingFields: JSONOptimizedEncodingField {
                    case name

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .name:
                            "name"
                        }
                    }
                }
            }

            extension Cached: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 1) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: CodingFields.name, value: self.name)
                    }
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test func propertyWithDefaultValue() {
        assertMacroExpansion(
            """
            @JSONEncodable
            struct WithDefault {
                let name: String = "default"
                let age: Int
            }
            """,
            expandedSource: """
            struct WithDefault {
                let name: String = "default"
                let age: Int
            }
            
            extension WithDefault {
                enum CodingFields: JSONOptimizedEncodingField {
                    case name
                    case age

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .name:
                            "name"
                        case .age:
                            "age"
                        }
                    }
                }
            }

            extension WithDefault: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 2) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: CodingFields.name, value: self.name)
                        try structEncoder.encode(field: CodingFields.age, value: self.age)
                    }
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test func decodableAliasIgnoredForEncodingOnly() {
        assertMacroExpansion(
            """
            @JSONEncodable
            struct User {
                @DecodableAlias("user_name", "username") let userName: String
                let age: Int
            }
            """,
            expandedSource: """
            struct User {
                let userName: String
                let age: Int
            }

            extension User {
                enum CodingFields: JSONOptimizedEncodingField {
                    case userName
                    case age

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .userName:
                            "userName"
                        case .age:
                            "age"
                        }
                    }
                }
            }

            extension User: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 2) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: CodingFields.userName, value: self.userName)
                        try structEncoder.encode(field: CodingFields.age, value: self.age)
                    }
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test func propertyWithObservers() {
        assertMacroExpansion(
            """
            @JSONEncodable
            struct Observed {
                var count: Int {
                    didSet { print(count) }
                }
                let name: String
            }
            """,
            expandedSource: """
            struct Observed {
                var count: Int {
                    didSet { print(count) }
                }
                let name: String
            }

            extension Observed {
                enum CodingFields: JSONOptimizedEncodingField {
                    case count
                    case name

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .count:
                            "count"
                        case .name:
                            "name"
                        }
                    }
                }
            }

            extension Observed: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 2) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: CodingFields.count, value: self.count)
                        try structEncoder.encode(field: CodingFields.name, value: self.name)
                    }
                }
            }
            """,
            macros: testMacros
        )
    }
}
