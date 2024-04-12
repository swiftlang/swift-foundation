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

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable import FoundationEssentials
#endif // FOUNDATION_FRAMEWORK

struct BuiltInUnicodeScalarSetTest {

    @Test func testMembership() {
        func setContainsScalar(_ set: BuiltInUnicodeScalarSet, _ scalar: Unicode.Scalar, _ expect: Bool, file: StaticString = #file, line: UInt = #line) {
            let actual = set.contains(scalar)
            #expect(
                actual == expect,
                sourceLocation: .init(
                    filePath: String(describing: file),
                    line: Int(line)
                )
            )
        }

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

}
