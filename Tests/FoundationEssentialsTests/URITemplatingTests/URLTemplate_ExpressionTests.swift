//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationEssentials)
@testable import FoundationEssentials
import struct FoundationEssentials.URL
#endif
#if FOUNDATION_FRAMEWORK
@testable import Foundation
import struct Foundation.URL
#endif
import Testing

private typealias Expression = URL.Template.Expression
private typealias Element = URL.Template.Expression.Element

@Suite("URL.Template Expression")
private enum ExpressionTests {
    @Test
    static func parsingWithSingleName() throws {
        #expect(
            try Expression("var") ==
            Expression(
                operator: nil,
                elements: [
                    Element(
                        name: .init("var"),
                        maximumLength: nil,
                        explode: false
                    ),
                ]
            )
        )
        #expect(
            try Expression("+var") ==
            Expression(
                operator: .reserved,
                elements: [
                    Element(
                        name: .init("var"),
                        maximumLength: nil,
                        explode: false
                    ),
                ]
            )
        )
        #expect(
            try Expression("#hello") ==
            Expression(
                operator: .fragment,
                elements: [
                    Element(
                        name: .init("hello"),
                        maximumLength: nil,
                        explode: false
                    ),
                ]
            )
        )
        #expect(
            try Expression(".list") ==
            Expression(
                operator: .nameLabel,
                elements: [
                    Element(
                        name: .init("list"),
                        maximumLength: nil,
                        explode: false
                    ),
                ]
            )
        )
        #expect(
            try Expression("/foo") ==
            Expression(
                operator: .pathSegment,
                elements: [
                    Element(
                        name: .init("foo"),
                        maximumLength: nil,
                        explode: false
                    ),
                ]
            )
        )
        #expect(
            try Expression(";name") ==
            Expression(
                operator: .pathParameter,
                elements: [
                    Element(
                        name: .init("name"),
                        maximumLength: nil,
                        explode: false
                    ),
                ]
            )
        )
        #expect(
            try Expression("?count") ==
            Expression(
                operator: .queryComponent,
                elements: [
                    Element(
                        name: .init("count"),
                        maximumLength: nil,
                        explode: false
                    ),
                ]
            )
        )
        #expect(
            try Expression("&max") ==
            Expression(
                operator: .continuation,
                elements: [
                    Element(
                        name: .init("max"),
                        maximumLength: nil,
                        explode: false
                    ),
                ]
            )
        )
        #expect(
            try Expression("var:30") ==
            Expression(
                operator: nil,
                elements: [
                    Element(
                        name: .init("var"),
                        maximumLength: 30,
                        explode: false
                    ),
                ]
            )
        )
        #expect(
            try Expression("+var:30") ==
            Expression(
                operator: .reserved,
                elements: [
                    Element(
                        name: .init("var"),
                        maximumLength: 30,
                        explode: false
                    ),
                ]
            )
        )
        #expect(
            try Expression("list*") ==
            Expression(
                operator: nil,
                elements: [
                    Element(
                        name: .init("list"),
                        maximumLength: nil,
                        explode: true
                    ),
                ]
            )
        )
        #expect(
            try Expression("&list*") ==
            Expression(
                operator: .continuation,
                elements: [
                    Element(
                        name: .init("list"),
                        maximumLength: nil,
                        explode: true
                    ),
                ]
            )
        )
    }

    @Test
    static func parsingWithMultipleNames() throws {
        #expect(
            try Expression("x,y") ==
            Expression(
                operator: nil,
                elements: [
                    Element(
                        name: .init("x"),
                        maximumLength: nil,
                        explode: false
                    ),
                    Element(
                        name: .init("y"),
                        maximumLength: nil,
                        explode: false
                    ),
                ]
            )
        )
        #expect(
            try Expression("&x,y,empty") ==
            Expression(
                operator: .continuation,
                elements: [
                    Element(
                        name: .init("x"),
                        maximumLength: nil,
                        explode: false
                    ),
                    Element(
                        name: .init("y"),
                        maximumLength: nil,
                        explode: false
                    ),
                    Element(
                        name: .init("empty"),
                        maximumLength: nil,
                        explode: false
                    ),
                ]
            )
        )
        #expect(
            try Expression("?q,lang") ==
            Expression(
                operator: .queryComponent,
                elements: [
                    Element(
                        name: .init("q"),
                        maximumLength: nil,
                        explode: false
                    ),
                    Element(
                        name: .init("lang"),
                        maximumLength: nil,
                        explode: false
                    ),
                ]
            )
        )
        #expect(
            try Expression("/list*,path:4") ==
            Expression(
                operator: .pathSegment,
                elements: [
                    Element(
                        name: .init("list"),
                        maximumLength: nil,
                        explode: true
                    ),
                    Element(
                        name: .init("path"),
                        maximumLength: 4,
                        explode: false
                    ),
                ]
            )
        )
    }

    @Test(arguments: [
        "path:a",
        "path:-1",
    ])
    static func invalid(
        input: String
    ) {
        #expect((try? Expression(input)) == nil, "Should fail to parse, but not crash.")
    }
}
