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
#if FOUNDATION_FRAMEWORK
@_spi(Unstable) internal import CollectionsInternal
#elseif canImport(_RopeModule)
internal import _RopeModule
#elseif canImport(_FoundationCollections)
internal import _FoundationCollections
#endif

@Suite("URL.Template Value")
private enum ValueTests {
    @Test
    static func creating() {
        #expect(
            URL.Template.Value.text("foo").underlying ==
            URL.Template.Value.Underlying.text("foo")
        )
        #expect(
            URL.Template.Value.list(["bar", "baz"]).underlying ==
            URL.Template.Value.Underlying.list(["bar", "baz"])
        )
        #expect(
            URL.Template.Value.associativeList(["bar": "baz"]).underlying ==
            URL.Template.Value.Underlying.associativeList(["bar": "baz"])
        )
    }

    @Test
    static func expressibleByLiteral() {
        let a: URL.Template.Value = "foo"
        #expect(
            a.underlying ==
            URL.Template.Value.Underlying.text("foo")
        )

        let b: URL.Template.Value = "1234"
        #expect(
            b.underlying ==
            URL.Template.Value.Underlying.text("1234")
        )

        let c: URL.Template.Value = ["bar", "baz"]
        #expect(
            c.underlying ==
            URL.Template.Value.Underlying.list(["bar", "baz"])
        )

        let d: URL.Template.Value = [
            "bar": "baz",
            "qux": "2"
        ]
        #expect(
            d.underlying ==
            URL.Template.Value.Underlying.associativeList(["bar": "baz", "qux": "2"])
        )
    }
}
