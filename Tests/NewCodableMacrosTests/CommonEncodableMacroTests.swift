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

let commonTestMacros: [String: Macro.Type] = [
    "CommonEncodable": CommonEncodableMacro.self,
    "CodingKey": CodingKeyMacro.self,
    "DecodableAlias": DecodableAliasMacro.self,
]

@Suite("@CommonEncodable Macro")
struct CommonEncodableMacroTests {

    @Test func basicStruct() {
        assertMacroExpansion(
            """
            @CommonEncodable
            struct Person {
                let name: String
                let age: Int
            }
            """,
            expandedSource: """
            struct Person {
                let name: String
                let age: Int

                enum CodingFields: StaticStringEncodingField {
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

            extension Person: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Escapable) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 2) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: CodingFields.name, value: self.name)
                        try structEncoder.encode(field: CodingFields.age, value: self.age)
                    }
                }
            }
            """,
            macros: commonTestMacros
        )
    }

    @Test func customCodingKey() {
        assertMacroExpansion(
            """
            @CommonEncodable
            struct Post {
                @CodingKey("date_published") let publishDate: String
                let title: String
            }
            """,
            expandedSource: """
            struct Post {
                let publishDate: String
                let title: String

                enum CodingFields: StaticStringEncodingField {
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

            extension Post: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Escapable) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 2) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: CodingFields.publishDate, value: self.publishDate)
                        try structEncoder.encode(field: CodingFields.title, value: self.title)
                    }
                }
            }
            """,
            macros: commonTestMacros
        )
    }

    @Test func optionalProperty() {
        assertMacroExpansion(
            """
            @CommonEncodable
            struct Item {
                let name: String
                let rating: Double?
            }
            """,
            expandedSource: """
            struct Item {
                let name: String
                let rating: Double?

                enum CodingFields: StaticStringEncodingField {
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

            extension Item: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Escapable) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 2) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: CodingFields.name, value: self.name)
                        try structEncoder.encode(field: CodingFields.rating, value: self.rating)
                    }
                }
            }
            """,
            macros: commonTestMacros
        )
    }

    @Test func computedPropertySkipped() {
        assertMacroExpansion(
            """
            @CommonEncodable
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

                enum CodingFields: StaticStringEncodingField {
                    case name

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .name: "name"
                        }
                    }
                }
            }

            extension Thing: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Escapable) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 1) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: CodingFields.name, value: self.name)
                    }
                }
            }
            """,
            macros: commonTestMacros
        )
    }

    @Test func staticPropertySkipped() {
        assertMacroExpansion(
            """
            @CommonEncodable
            struct Config {
                static let defaultName = "test"
                let name: String
            }
            """,
            expandedSource: """
            struct Config {
                static let defaultName = "test"
                let name: String

                enum CodingFields: StaticStringEncodingField {
                    case name

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .name: "name"
                        }
                    }
                }
            }

            extension Config: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Escapable) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 1) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: CodingFields.name, value: self.name)
                    }
                }
            }
            """,
            macros: commonTestMacros
        )
    }

    @Test func errorOnNonStruct() {
        assertMacroExpansion(
            """
            @CommonEncodable
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
                DiagnosticSpec(message: "@CommonEncodable can only be applied to structs", line: 1, column: 1)
            ],
            macros: commonTestMacros
        )
    }

    @Test func emptyStruct() {
        assertMacroExpansion(
            """
            @CommonEncodable
            struct Empty {
            }
            """,
            expandedSource: """
            struct Empty {
            }

            extension Empty: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Escapable) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 0) { _ throws(CodingError.Encoding) in }
                }
            }
            """,
            macros: commonTestMacros
        )
    }

    @Test func lazyVarSkipped() {
        assertMacroExpansion(
            """
            @CommonEncodable
            struct Cached {
                let name: String
                lazy var uppercasedName: String = name.uppercased()
            }
            """,
            expandedSource: """
            struct Cached {
                let name: String
                lazy var uppercasedName: String = name.uppercased()

                enum CodingFields: StaticStringEncodingField {
                    case name

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .name: "name"
                        }
                    }
                }
            }

            extension Cached: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Escapable) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 1) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: CodingFields.name, value: self.name)
                    }
                }
            }
            """,
            macros: commonTestMacros
        )
    }

    @Test func codingKeyOnMultipleBindingsError() {
        assertMacroExpansion(
            """
            @CommonEncodable
            struct Multi {
                @CodingKey("custom") var x, y: Int
            }
            """,
            expandedSource: """
            struct Multi {
                var x, y: Int
            }

            extension Multi: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Escapable) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 0) { _ throws(CodingError.Encoding) in }
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@CodingKey cannot be applied to a declaration with multiple bindings", line: 3, column: 5)
            ],
            macros: commonTestMacros
        )
    }

    @Test func propertyWithDefaultValue() {
        assertMacroExpansion(
            """
            @CommonEncodable
            struct WithDefault {
                let name: String = "default"
                let age: Int
            }
            """,
            expandedSource: """
            struct WithDefault {
                let name: String = "default"
                let age: Int

                enum CodingFields: StaticStringEncodingField {
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

            extension WithDefault: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Escapable) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 2) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: CodingFields.name, value: self.name)
                        try structEncoder.encode(field: CodingFields.age, value: self.age)
                    }
                }
            }
            """,
            macros: commonTestMacros
        )
    }

    @Test func decodableAliasIgnoredForEncodingOnly() {
        assertMacroExpansion(
            """
            @CommonEncodable
            struct User {
                @DecodableAlias("user_name", "username") let userName: String
                let age: Int
            }
            """,
            expandedSource: """
            struct User {
                let userName: String
                let age: Int

                enum CodingFields: StaticStringEncodingField {
                    case userName
                    case age

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .userName: "userName"
                        case .age: "age"
                        }
                    }
                }
            }

            extension User: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Escapable) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 2) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: CodingFields.userName, value: self.userName)
                        try structEncoder.encode(field: CodingFields.age, value: self.age)
                    }
                }
            }
            """,
            macros: commonTestMacros
        )
    }

    @Test func propertyWithObservers() {
        assertMacroExpansion(
            """
            @CommonEncodable
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

                enum CodingFields: StaticStringEncodingField {
                    case count
                    case name

                    @_transparent
                    var staticString: StaticString {
                        switch self {
                        case .count: "count"
                        case .name: "name"
                        }
                    }
                }
            }

            extension Observed: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Escapable) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 2) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: CodingFields.count, value: self.count)
                        try structEncoder.encode(field: CodingFields.name, value: self.name)
                    }
                }
            }
            """,
            macros: commonTestMacros
        )
    }
}