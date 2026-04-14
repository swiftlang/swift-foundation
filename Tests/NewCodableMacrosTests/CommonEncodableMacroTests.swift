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
            }

            extension Person {
                enum CodingFields: StaticStringEncodingField {
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

            extension Person: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
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
            }

            extension Post {
                enum CodingFields: StaticStringEncodingField {
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

            extension Post: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
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
            }

            extension Item {
                enum CodingFields: StaticStringEncodingField {
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

            extension Item: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
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
            }

            extension Thing {
                enum CodingFields: StaticStringEncodingField {
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

            extension Thing: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
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
            }

            extension Config {
                enum CodingFields: StaticStringEncodingField {
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

            extension Config: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
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
                DiagnosticSpec(message: "@CommonEncodable can only be applied to structs or enums", line: 1, column: 1)
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
                func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 0) { _ throws(CodingError.Encoding) in
                    }
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
            }

            extension Cached {
                enum CodingFields: StaticStringEncodingField {
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

            extension Cached: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 1) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: CodingFields.name, value: self.name)
                    }
                }
            }
            """,
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
            }

            extension WithDefault {
                enum CodingFields: StaticStringEncodingField {
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

            extension WithDefault: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
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
            }

            extension User {
                enum CodingFields: StaticStringEncodingField {
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

            extension User: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
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
            }

            extension Observed {
                enum CodingFields: StaticStringEncodingField {
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

            extension Observed: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
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

    @Test func publicStructEmitsPublicMembers() {
        assertMacroExpansion(
            """
            @CommonEncodable
            public struct Person {
                public let name: String
            }
            """,
            expandedSource: """
            public struct Person {
                public let name: String
            }

            extension Person {
                enum CodingFields: StaticStringEncodingField {
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

            extension Person: CommonEncodable {
                public func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 1) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: CodingFields.name, value: self.name)
                    }
                }
            }
            """,
            macros: commonTestMacros
        )
    }

    // MARK: - Enum Tests

    @Test func enumNoAssociatedValues() {
        assertMacroExpansion(
            """
            @CommonEncodable
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
                enum CodingFields: StaticStringEncodingField {
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
                }
            }

            extension Direction: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
                    switch self {
                    case .north:
                        try encoder.encodeEnumCase(CodingFields.north)
                    case .south:
                        try encoder.encodeEnumCase(CodingFields.south)
                    }
                }
            }
            """,
            macros: commonTestMacros
        )
    }

    @Test func enumWithAssociatedValues() {
        assertMacroExpansion(
            """
            @CommonEncodable
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
                enum CodingFields: StaticStringEncodingField {
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

                    enum CircleFields: StaticStringEncodingField {
                        case radius

                        @_transparent
                        var staticString: StaticString {
                            switch self {
                            case .radius:
                                "radius"
                            }
                        }
                    }
                }
            }

            extension Shape: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
                    switch self {
                    case .circle(let radius):
                        try encoder.encodeEnumCase(CodingFields.circle, associatedValueCount: 1) { valueEncoder throws(CodingError.Encoding) in
                            try valueEncoder.encode(field: CodingFields.CircleFields.radius, value: radius)
                        }
                    case .point:
                        try encoder.encodeEnumCase(CodingFields.point)
                    }
                }
            }
            """,
            macros: commonTestMacros
        )
    }

    @Test func enumWithUnlabeledAssociatedValues() {
        assertMacroExpansion(
            """
            @CommonEncodable
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
                enum CodingFields: StaticStringEncodingField {
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

                    enum SingleFields: StaticStringEncodingField {
                        case _0

                        @_transparent
                        var staticString: StaticString {
                            switch self {
                            case ._0:
                                "_0"
                            }
                        }
                    }

                    enum PairFields: StaticStringEncodingField {
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
                    }
                }
            }

            extension Wrapper: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
                    switch self {
                    case .single(let _0):
                        try encoder.encodeEnumCase(CodingFields.single, associatedValueCount: 1) { valueEncoder throws(CodingError.Encoding) in
                            try valueEncoder.encode(field: CodingFields.SingleFields._0, value: _0)
                        }
                    case .pair(let _0, let _1):
                        try encoder.encodeEnumCase(CodingFields.pair, associatedValueCount: 2) { valueEncoder throws(CodingError.Encoding) in
                            try valueEncoder.encode(field: CodingFields.PairFields._0, value: _0)
                            try valueEncoder.encode(field: CodingFields.PairFields._1, value: _1)
                        }
                    }
                }
            }
            """,
            macros: commonTestMacros
        )
    }

    @Test func enumWithCustomCodingKey() {
        assertMacroExpansion(
            """
            @CommonEncodable
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
                enum CodingFields: StaticStringEncodingField {
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
                }
            }

            extension Status: CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
                    switch self {
                    case .inProgress:
                        try encoder.encodeEnumCase(CodingFields.inProgress)
                    case .done:
                        try encoder.encodeEnumCase(CodingFields.done)
                    }
                }
            }
            """,
            macros: commonTestMacros
        )
    }
}
