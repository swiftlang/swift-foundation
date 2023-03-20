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

#if canImport(TestSupport)
import TestSupport
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable import FoundationEssentials
#endif // FOUNDATION_FRAMEWORK

final class BuiltInUnicodeScalarSetTest: XCTestCase {

    func testMembership() {
        func setContainsScalar(_ set: BuiltInUnicodeScalarSet, _ scalar: Unicode.Scalar, _ expect: Bool, file: StaticString = #file, line: UInt = #line) {
            let actual = set.contains(scalar)
            XCTAssertEqual(actual, expect, file: file, line: line)
        }

        setContainsScalar(.lowercaseLetter, "a", true)
        setContainsScalar(.lowercaseLetter, "ô", true)
        setContainsScalar(.lowercaseLetter, "\u{01FB}", true)
        setContainsScalar(.lowercaseLetter, "\u{1FF7}", true)
        setContainsScalar(.lowercaseLetter, "\u{1D467}", true)
        setContainsScalar(.lowercaseLetter, "A", false)

        setContainsScalar(.uppercaseLetter, "A", true)
        setContainsScalar(.uppercaseLetter, "À", true)
        setContainsScalar(.uppercaseLetter, "\u{01CF}", true)
        setContainsScalar(.uppercaseLetter, "\u{1E5C}", true)
        setContainsScalar(.uppercaseLetter, "\u{1D4A9}", true)
        setContainsScalar(.uppercaseLetter, "a", false)

        setContainsScalar(.caseIgnorable, "'", true)
        setContainsScalar(.caseIgnorable, "ʻ", true)
        setContainsScalar(.caseIgnorable, "\u{00B4}", true) // ACUTE ACCENT
        setContainsScalar(.caseIgnorable, "\u{10792}", true) // MODIFIER LETTER SMALL CAPITAL G
        setContainsScalar(.caseIgnorable, "\u{E0020}", true)
        setContainsScalar(.caseIgnorable, "0", false)

        setContainsScalar(.graphemeExtend, "\u{0300}", true)
        setContainsScalar(.graphemeExtend, "\u{0610}", true)
        setContainsScalar(.graphemeExtend, "\u{302A}", true) // IDEOGRAPHIC LEVEL TONE MARK
        setContainsScalar(.graphemeExtend, "\u{1D17B}", true) // MUSICAL SYMBOL COMBINING ACCENT
        setContainsScalar(.graphemeExtend, "\u{E0020}", true) // TAG SPACE
        setContainsScalar(.graphemeExtend, "A", false)
        setContainsScalar(.graphemeExtend, "~", false)
    }

}
