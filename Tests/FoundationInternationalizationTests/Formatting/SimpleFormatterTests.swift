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

import Testing

#if canImport(FoundationInternationalization)
@testable import FoundationEssentials
@testable import FoundationInternationalization
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#endif

#if !FOUNDATION_LIST_FORMAT_ICU
/// `SimpleFormatter` decomposes patterns into prefix / connector / suffix at
/// formatter init. The `ListFormatStyle` format tests cover this indirectly;
/// these cases pin the parser's contract directly.
@Suite("SimpleFormatter")
private struct SimpleFormatterTests {
    @Test func parseCanonicalPattern() {
        let p = SimpleFormatter("{0}, {1}")
        #expect(p?.prefix == "")
        #expect(p?.connector == ", ")
        #expect(p?.suffix == "")
        #expect(p?.connectorStartsWithSpace == false)
        #expect(p?.connectorEndsWithSpace == true)
    }

    @Test func parseSpanishPattern() {
        let p = SimpleFormatter("{0} y {1}")
        #expect(p?.connector == " y ")
        #expect(p?.connectorStartsWithSpace == true)
        #expect(p?.connectorEndsWithSpace == true)
    }

    @Test func parseWithPrefixAndSuffix() {
        let p = SimpleFormatter("foo{0}…{1}bar")
        #expect(p?.prefix == "foo")
        #expect(p?.connector == "…")
        #expect(p?.suffix == "bar")
        #expect(p?.connectorStartsWithSpace == false)
        #expect(p?.connectorEndsWithSpace == false)
    }

    @Test func parseRejectsMalformed() {
        #expect(SimpleFormatter("garbage") == nil)
        #expect(SimpleFormatter("{0}") == nil)            // missing {1}
        #expect(SimpleFormatter("{1}, {0}") == nil)       // wrong order
        #expect(SimpleFormatter("{0, {1}") == nil)        // unclosed brace
        #expect(SimpleFormatter("") == nil)
    }
}
#endif
