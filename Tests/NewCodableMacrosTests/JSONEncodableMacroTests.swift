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
                DiagnosticSpec(message: "@JSONEncodable can only be applied to structs or enums", line: 1, column: 1)
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

    @Test func publicStructEmitsPublicMembers() {
        assertMacroExpansion(
            """
            @JSONEncodable
            public struct Person {
                public let name: String
            }
            """,
            expandedSource: """
            public struct Person {
                public let name: String
            }

            extension Person {
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

            extension Person: JSONEncodable {
                public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 1) { structEncoder throws(CodingError.Encoding) in
                        try structEncoder.encode(field: CodingFields.name, value: self.name)
                    }
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - Enum Tests

    @Test func enumNoAssociatedValues() {
        assertMacroExpansion(
            """
            @JSONEncodable
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
                enum CodingFields: JSONOptimizedEncodingField {
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
                }
            }

            extension Direction: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    switch self {
                    case .north:
                        try encoder.encodeEnumCase(CodingFields.north)
                    case .south:
                        try encoder.encodeEnumCase(CodingFields.south)
                    case .east:
                        try encoder.encodeEnumCase(CodingFields.east)
                    case .west:
                        try encoder.encodeEnumCase(CodingFields.west)
                    }
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test func enumWithLabeledAssociatedValues() {
        assertMacroExpansion(
            """
            @JSONEncodable
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
                enum CodingFields: JSONOptimizedEncodingField {
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

                    enum CircleFields: JSONOptimizedEncodingField {
                        case radius

                        @_transparent
                        var staticString: StaticString {
                            switch self {
                            case .radius:
                                "radius"
                            }
                        }
                    }

                    enum RectangleFields: JSONOptimizedEncodingField {
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
                    }
                }
            }

            extension Shape: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    switch self {
                    case .circle(let radius):
                        try encoder.encodeEnumCase(CodingFields.circle, associatedValueCount: 1) { valueEncoder throws(CodingError.Encoding) in
                            try valueEncoder.encode(field: CodingFields.CircleFields.radius, value: radius)
                        }
                    case .rectangle(let width, let height):
                        try encoder.encodeEnumCase(CodingFields.rectangle, associatedValueCount: 2) { valueEncoder throws(CodingError.Encoding) in
                            try valueEncoder.encode(field: CodingFields.RectangleFields.width, value: width)
                            try valueEncoder.encode(field: CodingFields.RectangleFields.height, value: height)
                        }
                    }
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test func enumMixedCases() {
        assertMacroExpansion(
            """
            @JSONEncodable
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
                enum CodingFields: JSONOptimizedEncodingField {
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

                    enum SuccessFields: JSONOptimizedEncodingField {
                        case value

                        @_transparent
                        var staticString: StaticString {
                            switch self {
                            case .value:
                                "value"
                            }
                        }
                    }
                }
            }

            extension Result: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    switch self {
                    case .success(let value):
                        try encoder.encodeEnumCase(CodingFields.success, associatedValueCount: 1) { valueEncoder throws(CodingError.Encoding) in
                            try valueEncoder.encode(field: CodingFields.SuccessFields.value, value: value)
                        }
                    case .failure:
                        try encoder.encodeEnumCase(CodingFields.failure)
                    }
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test func enumWithUnlabeledAssociatedValues() {
        assertMacroExpansion(
            """
            @JSONEncodable
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
                enum CodingFields: JSONOptimizedEncodingField {
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

                    enum SingleFields: JSONOptimizedEncodingField {
                        case _0

                        @_transparent
                        var staticString: StaticString {
                            switch self {
                            case ._0:
                                "_0"
                            }
                        }
                    }

                    enum PairFields: JSONOptimizedEncodingField {
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

            extension Wrapper: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
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
            macros: testMacros
        )
    }

    @Test func enumWithCustomCodingKey() {
        assertMacroExpansion(
            """
            @JSONEncodable
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
                enum CodingFields: JSONOptimizedEncodingField {
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

            extension Status: JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    switch self {
                    case .inProgress:
                        try encoder.encodeEnumCase(CodingFields.inProgress)
                    case .done:
                        try encoder.encodeEnumCase(CodingFields.done)
                    }
                }
            }
            """,
            macros: testMacros
        )
    }
}
