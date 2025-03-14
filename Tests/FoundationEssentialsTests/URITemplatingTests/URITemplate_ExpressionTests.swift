//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
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
import XCTest

private typealias Expression = URL.Template.Expression
private typealias Element = URL.Template.Expression.Element

final class ExpressionTests: XCTestCase {
    func testParsingWithSingleName() {
        XCTAssertEqual(
            try Expression("var"),
            Expression(
                operator: nil,
                elements: [
                    Element(
                        name: "var",
                        maximumLength: nil,
                        explode: false
                    ),
                ]
            )
        )
        XCTAssertEqual(
            try Expression("+var"),
            Expression(
                operator: .reserved,
                elements: [
                    Element(
                        name: "var",
                        maximumLength: nil,
                        explode: false
                    ),
                ]
            )
        )
        XCTAssertEqual(
            try Expression("#hello"),
            Expression(
                operator: .fragment,
                elements: [
                    Element(
                        name: "hello",
                        maximumLength: nil,
                        explode: false
                    ),
                ]
            )
        )
        XCTAssertEqual(
            try Expression(".list"),
            Expression(
                operator: .nameLabel,
                elements: [
                    Element(
                        name: "list",
                        maximumLength: nil,
                        explode: false
                    ),
                ]
            )
        )
        XCTAssertEqual(
            try Expression("/foo"),
            Expression(
                operator: .pathSegment,
                elements: [
                    Element(
                        name: "foo",
                        maximumLength: nil,
                        explode: false
                    ),
                ]
            )
        )
        XCTAssertEqual(
            try Expression(";name"),
            Expression(
                operator: .pathParameter,
                elements: [
                    Element(
                        name: "name",
                        maximumLength: nil,
                        explode: false
                    ),
                ]
            )
        )
        XCTAssertEqual(
            try Expression("?count"),
            Expression(
                operator: .queryComponent,
                elements: [
                    Element(
                        name: "count",
                        maximumLength: nil,
                        explode: false
                    ),
                ]
            )
        )
        XCTAssertEqual(
            try Expression("&max"),
            Expression(
                operator: .continuation,
                elements: [
                    Element(
                        name: "max",
                        maximumLength: nil,
                        explode: false
                    ),
                ]
            )
        )
        XCTAssertEqual(
            try Expression("var:30"),
            Expression(
                operator: nil,
                elements: [
                    Element(
                        name: "var",
                        maximumLength: 30,
                        explode: false
                    ),
                ]
            )
        )
        XCTAssertEqual(
            try Expression("+var:30"),
            Expression(
                operator: .reserved,
                elements: [
                    Element(
                        name: "var",
                        maximumLength: 30,
                        explode: false
                    ),
                ]
            )
        )
        XCTAssertEqual(
            try Expression("list*"),
            Expression(
                operator: nil,
                elements: [
                    Element(
                        name: "list",
                        maximumLength: nil,
                        explode: true
                    ),
                ]
            )
        )
        XCTAssertEqual(
            try Expression("&list*"),
            Expression(
                operator: .continuation,
                elements: [
                    Element(
                        name: "list",
                        maximumLength: nil,
                        explode: true
                    ),
                ]
            )
        )
    }

    func testParsingWithMultipleNames() {
        XCTAssertEqual(
            try Expression("x,y"),
            Expression(
                operator: nil,
                elements: [
                    Element(
                        name: "x",
                        maximumLength: nil,
                        explode: false
                    ),
                    Element(
                        name: "y",
                        maximumLength: nil,
                        explode: false
                    ),
                ]
            )
        )
        XCTAssertEqual(
            try Expression("&x,y,empty"),
            Expression(
                operator: .continuation,
                elements: [
                    Element(
                        name: "x",
                        maximumLength: nil,
                        explode: false
                    ),
                    Element(
                        name: "y",
                        maximumLength: nil,
                        explode: false
                    ),
                    Element(
                        name: "empty",
                        maximumLength: nil,
                        explode: false
                    ),
                ]
            )
        )
        XCTAssertEqual(
            try Expression("?q,lang"),
            Expression(
                operator: .queryComponent,
                elements: [
                    Element(
                        name: "q",
                        maximumLength: nil,
                        explode: false
                    ),
                    Element(
                        name: "lang",
                        maximumLength: nil,
                        explode: false
                    ),
                ]
            )
        )
        XCTAssertEqual(
            try Expression("/list*,path:4"),
            Expression(
                operator: .pathSegment,
                elements: [
                    Element(
                        name: "list",
                        maximumLength: nil,
                        explode: true
                    ),
                    Element(
                        name: "path",
                        maximumLength: 4,
                        explode: false
                    ),
                ]
            )
        )
    }
}
