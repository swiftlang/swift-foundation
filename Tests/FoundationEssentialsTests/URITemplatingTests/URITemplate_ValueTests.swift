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
#if FOUNDATION_FRAMEWORK
@_spi(Unstable) internal import CollectionsInternal
#elseif canImport(_RopeModule)
internal import _RopeModule
#elseif canImport(_FoundationCollections)
internal import _FoundationCollections
#endif

final class ValueTests: XCTestCase {
    func testCreating() {
        XCTAssertEqual(
            URL.Template.Value.text("foo").underlying,
            URL.Template.Value.Underlying.text("foo")
        )
        XCTAssertEqual(
            URL.Template.Value.list(["bar", "baz"]).underlying,
            URL.Template.Value.Underlying.list(["bar", "baz"])
        )
        XCTAssertEqual(
            URL.Template.Value.associativeList(["bar": "baz"]).underlying,
            URL.Template.Value.Underlying.associativeList(["bar": "baz"])
        )
    }

    func testExpressibleByLiteral() {
        let a: URL.Template.Value = "foo"
        XCTAssertEqual(
            a.underlying,
            URL.Template.Value.Underlying.text("foo")
        )

        let b: URL.Template.Value = "1234"
        XCTAssertEqual(
            b.underlying,
            URL.Template.Value.Underlying.text("1234")
        )

        let c: URL.Template.Value = ["bar", "baz"]
        XCTAssertEqual(
            c.underlying,
            URL.Template.Value.Underlying.list(["bar", "baz"])
        )

        let d: URL.Template.Value = [
            "bar": "baz",
            "qux": "2"
        ]
        XCTAssertEqual(
            d.underlying,
            URL.Template.Value.Underlying.associativeList(["bar": "baz", "qux": "2"])
        )
    }
}
