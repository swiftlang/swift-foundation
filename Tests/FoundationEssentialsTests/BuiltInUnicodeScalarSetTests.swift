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

import Testing

#if canImport(FoundationEssentials)
@testable import FoundationEssentials
#else
@testable import Foundation
#endif

@Suite("BuiltInUnicodeScalarSet")
private struct BuiltInUnicodeScalarSetTests {

    func setContainsScalar(_ set: BuiltInUnicodeScalarSet, _ scalar: Unicode.Scalar, _ expect: Bool, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(set.contains(scalar) == expect, sourceLocation: sourceLocation)
    }

    @Test func membership() {
        setContainsScalar(.lowercaseLetters, "a", true)
        setContainsScalar(.lowercaseLetters, "ô", true)
        setContainsScalar(.lowercaseLetters, "\u{01FB}", true)
        setContainsScalar(.lowercaseLetters, "\u{1FF7}", true)
        setContainsScalar(.lowercaseLetters, "\u{1D467}", true)
        setContainsScalar(.lowercaseLetters, "A", false)

        setContainsScalar(.uppercaseLetters, "A", true)
        setContainsScalar(.uppercaseLetters, "À", true)
        setContainsScalar(.uppercaseLetters, "\u{01CF}", true)
        setContainsScalar(.uppercaseLetters, "\u{1E5C}", true)
        setContainsScalar(.uppercaseLetters, "\u{1D4A9}", true)
        setContainsScalar(.uppercaseLetters, "a", false)

        setContainsScalar(.caseIgnorables, "'", true)
        setContainsScalar(.caseIgnorables, "ʻ", true)
        setContainsScalar(.caseIgnorables, "\u{00B4}", true) // ACUTE ACCENT
        setContainsScalar(.caseIgnorables, "\u{10792}", true) // MODIFIER LETTER SMALL CAPITAL G
        setContainsScalar(.caseIgnorables, "\u{E0020}", true)
        setContainsScalar(.caseIgnorables, "0", false)

        setContainsScalar(.graphemeExtends, "\u{0300}", true)
        setContainsScalar(.graphemeExtends, "\u{0610}", true)
        setContainsScalar(.graphemeExtends, "\u{302A}", true) // IDEOGRAPHIC LEVEL TONE MARK
        setContainsScalar(.graphemeExtends, "\u{1D17B}", true) // MUSICAL SYMBOL COMBINING ACCENT
        setContainsScalar(.graphemeExtends, "\u{E0020}", true) // TAG SPACE
        setContainsScalar(.graphemeExtends, "A", false)
        setContainsScalar(.graphemeExtends, "~", false)
    }

    @Test func bmpMembership() {
        setContainsScalar(.uppercaseLetters, "\u{FFFF}", false)
        setContainsScalar(.lowercaseLetters, "\u{FFFF}", false)
        setContainsScalar(BuiltInUnicodeScalarSet(type: .letter), "\u{FFFF}", false)
        setContainsScalar(BuiltInUnicodeScalarSet(type: .alphanumeric), "\u{FFFF}", false)
        setContainsScalar(BuiltInUnicodeScalarSet(type: .decimalDigit), "\u{FFFF}", false)
    }

    @Test func nonBMPMembership() {
        setContainsScalar(BuiltInUnicodeScalarSet(type: .letter), "\u{10000}", true) // LINEAR B SYLLABLE B008 A
        setContainsScalar(BuiltInUnicodeScalarSet(type: .alphanumeric), "\u{10000}", true) // LINEAR B SYLLABLE B008 A
        setContainsScalar(.uppercaseLetters, "\u{10000}", false)
        setContainsScalar(.lowercaseLetters, "\u{10000}", false)
        setContainsScalar(BuiltInUnicodeScalarSet(type: .decimalDigit), "\u{10000}", false)
    }

    @Test func illegalSetMembership() {
        let illegal = BuiltInUnicodeScalarSet(type: .illegal)
        setContainsScalar(illegal, "A", false)
        setContainsScalar(illegal, "0", false)
        setContainsScalar(illegal, "a", false)
        setContainsScalar(illegal, "\u{E0001}", false) // LANGUAGE TAG
        setContainsScalar(illegal, "\u{E0020}", false) // TAG SPACE
        setContainsScalar(illegal, "\u{E007F}", false) // CANCEL TAG
        setContainsScalar(illegal, "\u{E0000}", true)
    }

    @Test func controlAndFormatterSetMembership() {
        let controlAndFormatter = BuiltInUnicodeScalarSet(type: .controlAndFormatter)
        setContainsScalar(controlAndFormatter, "\u{0001}", true) // START OF HEADING
        setContainsScalar(controlAndFormatter, "\u{0007}", true) // BELL
        setContainsScalar(controlAndFormatter, "\u{200B}", true) // ZERO WIDTH SPACE
        setContainsScalar(controlAndFormatter, "a", false)
        setContainsScalar(controlAndFormatter, "0", false)
        setContainsScalar(controlAndFormatter, "\u{E0001}", true) // LANGUAGE TAG
        setContainsScalar(controlAndFormatter, "\u{E0020}", true) // TAG SPACE
        setContainsScalar(controlAndFormatter, "\u{E007F}", true) // CANCEL TAG
        setContainsScalar(controlAndFormatter, "\u{E0000}", false)
    }

    @Test func whitespaceSetMembership() {
        let whitespace = BuiltInUnicodeScalarSet(type: .whitespace)
        setContainsScalar(whitespace, " ", true)
        setContainsScalar(whitespace, "\u{0009}", true) // CHARACTER TABULATION
        setContainsScalar(whitespace, "\u{00A0}", true) // NO-BREAK SPACE
        setContainsScalar(whitespace, "\u{1680}", true) // OGHAM SPACE MARK
        setContainsScalar(whitespace, "\u{2000}", true) // EN QUAD
        setContainsScalar(whitespace, "\u{200B}", true) // ZERO WIDTH SPACE
        setContainsScalar(whitespace, "\u{202F}", true) // NARROW NO-BREAK SPACE
        setContainsScalar(whitespace, "\u{205F}", true) // MEDIUM MATHEMATICAL SPACE
        setContainsScalar(whitespace, "\u{3000}", true) // IDEOGRAPHIC SPACE
        setContainsScalar(whitespace, "\u{000A}", false) // LINE FEED
        setContainsScalar(whitespace, "a", false)
    }

    @Test func newlineSetMembership() {
        let newline = BuiltInUnicodeScalarSet(type: .newline)
        setContainsScalar(newline, "\u{000A}", true) // LINE FEED
        setContainsScalar(newline, "\u{000B}", true) // LINE TABULATION
        setContainsScalar(newline, "\u{000C}", true) // FORM FEED
        setContainsScalar(newline, "\u{000D}", true) // CARRIAGE RETURN
        setContainsScalar(newline, "\u{0085}", true) // NEXT LINE
        setContainsScalar(newline, "\u{2028}", true) // LINE SEPARATOR
        setContainsScalar(newline, "\u{2029}", true) // PARAGRAPH SEPARATOR
        setContainsScalar(newline, " ", false)
        setContainsScalar(newline, "a", false)
    }

    @Test func whitespaceAndNewlineSetMembership() {
        let whitespaceAndNewline = BuiltInUnicodeScalarSet(type: .whitespaceAndNewline)
        setContainsScalar(whitespaceAndNewline, " ", true)
        setContainsScalar(whitespaceAndNewline, "\u{000A}", true) // LINE FEED
        setContainsScalar(whitespaceAndNewline, "\u{2028}", true) // LINE SEPARATOR
        setContainsScalar(whitespaceAndNewline, "\u{3000}", true) // IDEOGRAPHIC SPACE
        setContainsScalar(whitespaceAndNewline, "a", false)
    }

    @Test func unsupportedNonBMPPlaneMembership() {
        setContainsScalar(.uppercaseLetters, "\u{D0000}", false)
        setContainsScalar(.lowercaseLetters, "\u{D0000}", false)
        setContainsScalar(BuiltInUnicodeScalarSet(type: .decimalDigit), "\u{D0000}", false)
    }

    @Test func illegalSetUnsupportedNonBMPNonSpecialPlaneMembership() {
        let illegal = BuiltInUnicodeScalarSet(type: .illegal)
        setContainsScalar(illegal, "\u{10000}", false) // LINEAR B SYLLABLE B008 A
        setContainsScalar(illegal, "\u{1D7CF}", false) // MATHEMATICAL BOLD DIGIT ZERO
        setContainsScalar(illegal, "\u{D0000}", false)
    }

    @Test func illegalSetUnsupportedPlane15And16Membership() {
        let illegal = BuiltInUnicodeScalarSet(type: .illegal)
        setContainsScalar(illegal, "\u{F0000}", false)
        setContainsScalar(illegal, "\u{FFFFE}", false)
        setContainsScalar(illegal, "\u{100000}", false)
        setContainsScalar(illegal, "\u{10FFFD}", false)
    }

    @Test func controlAndFormatterSetUnsupportedNonBMPNonPlane14() {
        let controlAndFormatter = BuiltInUnicodeScalarSet(type: .controlAndFormatter)
        setContainsScalar(controlAndFormatter, "\u{10000}", false) // LINEAR B SYLLABLE B008 A
        setContainsScalar(controlAndFormatter, "\u{1D7CF}", false) // MATHEMATICAL BOLD DIGIT ZERO
        setContainsScalar(controlAndFormatter, "\u{D0000}", false)
    }

}
