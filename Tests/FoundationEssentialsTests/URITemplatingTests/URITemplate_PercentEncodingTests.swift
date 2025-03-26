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
#endif
#if FOUNDATION_FRAMEWORK
@testable import Foundation
#endif
import Testing
#if FOUNDATION_FRAMEWORK
@_spi(Unstable) internal import CollectionsInternal
#elseif canImport(_RopeModule)
internal import _RopeModule
#elseif canImport(_FoundationCollections)
internal import _FoundationCollections
#endif

extension String {
    fileprivate func encoded(
        _ allowed: URL.Template.Expression.Operator.AllowedCharacters
    ) -> String {
        normalizedAddingPercentEncoding(withAllowedCharacters: allowed)
    }
}

@Suite("URL.Template PercentEncoding")
private enum PercentEncodingTests {
    @Test
    static func allowedUnreserved() {
        // unreserved     =  ALPHA / DIGIT / "-" / "." / "_" / "~"
        let expected: Set<UInt8> = {
            var expected = Set<UInt8>()
            expected.formUnion(0x61...0x7a) // "a"..."z"
            expected.formUnion(0x41...0x5a) // "A"..."Z"
            expected.formUnion(0x30...0x39) // "0"..."9"
            expected.formUnion([0x2d, 0x2e, 0x5f, 0x7e]) // `-` `.` `_` `~`
            return expected
        }()
        let unreserved = URL.Template.Expression.Operator.AllowedCharacters.unreserved
        for c in UInt8.min...UInt8.max {
            #expect(unreserved.isAllowedCodeUnit(c) == expected.contains(c), "\(c)")
        }
    }

    @Test
    static func allowedUnreservedReserved() {
        // unreserved     =  ALPHA / DIGIT / "-" / "." / "_" / "~"
        let expected: Set<UInt8> = {
            var expected = Set<UInt8>()
            expected.formUnion(0x61...0x7a) // "a"..."z"
            expected.formUnion(0x41...0x5a) // "A"..."Z"
            expected.formUnion(0x30...0x39) // "0"..."9"
            expected.formUnion([0x2d, 0x2e, 0x5f, 0x7e]) // `-` `.` `_` `~`
            expected.formUnion([0x3a, 0x2f, 0x3f, 0x23, 0x5b, 0x5d, 0x40]) // `:` `/` `?` `#` `[` `]` `@`
            expected.formUnion([0x21, 0x24, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x3b, 0x3d]) // `!` `$` `&` `'` `(` `)` `*` `+` `,` `;` `=`
            return expected
        }()
        let unreservedReserved = URL.Template.Expression.Operator.AllowedCharacters.unreservedReserved
        for c in UInt8.min...UInt8.max {
            #expect(unreservedReserved.isAllowedCodeUnit(c) == expected.contains(c), "\(c)")
        }
    }

    @Test
    static func normalizedAddingPercentEncoding_unreservedReserved() {
        #expect("".encoded(.unreservedReserved) == "")
        #expect("a".encoded(.unreservedReserved) == "a")
        #expect("a1-._~b2".encoded(.unreservedReserved) == "a1-._~b2")
        #expect(":/?#[]@".encoded(.unreservedReserved) == ":/?#[]@")
        #expect("!$&'()*+,;=".encoded(.unreservedReserved) == "!$&'()*+,;=")
        #expect("ä".encoded(.unreservedReserved) == "%C3%A4")

        // Percent encoded characters will be copied literally.
        // But the `%` character will be encoded (since it’s not allowed)
        // if it’s not part of a `pct-encoded` sequence.
        #expect("a%20b".encoded(.unreservedReserved) == "a%20b")
        #expect("a%g0b".encoded(.unreservedReserved) == "a%25g0b")
        #expect("a%0gb".encoded(.unreservedReserved) == "a%250gb")
        #expect("a%@0b".encoded(.unreservedReserved) == "a%25@0b")
        #expect("a%0@b".encoded(.unreservedReserved) == "a%250@b")
        #expect("a%/0b".encoded(.unreservedReserved) == "a%25/0b")
        #expect("a%0/b".encoded(.unreservedReserved) == "a%250/b")
        #expect("a%:0b".encoded(.unreservedReserved) == "a%25:0b")
        #expect("a%0:b".encoded(.unreservedReserved) == "a%250:b")
        #expect("a%aab".encoded(.unreservedReserved) == "a%aab")
        #expect("a%AAb".encoded(.unreservedReserved) == "a%AAb")
        #expect("a%ffb".encoded(.unreservedReserved) == "a%ffb")
        #expect("a%FFb".encoded(.unreservedReserved) == "a%FFb")
        #expect("a%b".encoded(.unreservedReserved) == "a%25b")
        #expect("a%2".encoded(.unreservedReserved) == "a%252")
        #expect("a%2 ".encoded(.unreservedReserved) == "a%252%20")
        #expect("a%2 ".encoded(.unreservedReserved) == "a%252%20")
        #expect("a%%".encoded(.unreservedReserved) == "a%25%25")
        #expect("a%%2".encoded(.unreservedReserved) == "a%25%252")
        #expect("a%%20".encoded(.unreservedReserved) == "a%25%20")
    }

    @Test
    static func normalizedAddingPercentEncoding_unreserved() {
        #expect("".encoded(.unreserved) == "")
        #expect("a".encoded(.unreserved) == "a")
        #expect("a1-._~b2".encoded(.unreserved) == "a1-._~b2")
        #expect(":/?#[]@".encoded(.unreserved) == "%3A%2F%3F%23%5B%5D%40")
        #expect("!$&'()*+,;=".encoded(.unreserved) == "%21%24%26%27%28%29%2A%2B%2C%3B%3D")
        #expect("ä".encoded(.unreservedReserved) == "%C3%A4")

        // In the `unreserved` case, `%` will always get encoded:
        #expect("a%20b".encoded(.unreserved) == "a%2520b")
        #expect("a%b".encoded(.unreserved) == "a%25b")
        #expect("a%22".encoded(.unreserved) == "a%2522")
        #expect("a%%22".encoded(.unreserved) == "a%25%2522")
    }

    @Test
    static func convertToNFCAndPercentEncode() {
        // Percent-encode everything to make tests easier to read:
        func encodeAll(_ input: String) -> String {
            input.addingPercentEncodingToNFC(allowed: .unreserved)
        }

        #expect(encodeAll("") == "")
        #expect(encodeAll("a") == "a")
        #expect(encodeAll("\u{1}") == "%01")
        #expect(encodeAll("\u{C5}") == "%C3%85")
        #expect(encodeAll("\u{41}\u{30A}") == "%C3%85", "combining mark")
        #expect(encodeAll("\u{41}\u{300}\u{323}") == "%E1%BA%A0%CC%80", "Ordering of combining marks.")
        #expect(encodeAll("a b c \u{73}\u{323}\u{307} d e f") == "a%20b%20c%20%E1%B9%A9%20d%20e%20f")
        #expect(encodeAll("a b c \u{1e69} d e f") == "a%20b%20c%20%E1%B9%A9%20d%20e%20f")
    }
}
