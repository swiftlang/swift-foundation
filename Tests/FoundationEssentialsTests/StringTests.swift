//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable import FoundationEssentials
#endif // FOUNDATION_FRAMEWORK

#if canImport(TestSupport)
import TestSupport
#endif

final class StringTests : XCTestCase {
    // MARK: - Case mapping

    func testCapitalize() {
        func test(_ string: String, _ expected: String, file: StaticString = #file, line: UInt = #line) {
            XCTAssertEqual(string._capitalized(), expected, file: file, line: line)
        }

        test("iı", "Iı")
        test("ıi", "Ii")

        // Word boundaries
        test("Th.he.EVERYWHERE",
             "Th.He.Everywhere")
        test("HELLO world\t\t\tThere.here.EVERYWHERE 78dollars",
             "Hello World\t\t\tThere.Here.Everywhere 78Dollars")
        test("GOOd Evening WOrld!", "Good Evening World!")

        // We don't do title case, so minor words are also capitalized
        test("train your mind for peak performance: a science-based approach for achieving your goals!", "Train Your Mind For Peak Performance: A Science-Based Approach For Achieving Your Goals!")
        test("cAt! ʻeTc.", "Cat! ʻEtc.")
        test("a ʻCaT. A ʻdOg! ʻeTc.",  "A ʻCat. A ʻDog! ʻEtc.")
        test("49ERS", "49Ers")
        test("«丰(aBc)»", "«丰(Abc)»")
        test("Nat’s test can’t run", "Nat’s Test Can’t Run")
        
        test("ijssEl iglOo IJSSEL", "Ijssel Igloo Ijssel")
        test("\u{00DF}", "Ss") // Sharp S
        test("\u{FB00}", "Ff") // Ligature FF
        test("\u{1F80}", "\u{1F88}")

        // Width variants
        test("ｈｅｌｌｏ，ｗｏＲＬＤ\tｈｅｒｅ．ＴＨＥＲＥ？ｅＶｅｒＹＷＨＥＲＥ",
             "Ｈｅｌｌｏ，Ｗｏｒｌｄ\tＨｅｒｅ．Ｔｈｅｒｅ？Ｅｖｅｒｙｗｈｅｒｅ")

        // Diacritics
        test("ĤĒḺḶŐ ẀỌṜŁÐ", "Ĥēḻḷő Ẁọṝłð")

        // Hiragana, Katacana -- case not affected
        test("ァィゥㇳ゚ェォ ヶ゜ アイウエオ", "ァィゥㇳ゚ェォ ヶ゜ アイウエオ")
        test("ぁぃぅぇぉ ど ゕゖくけこ", "ぁぃぅぇぉ ど ゕゖくけこ")
    }

    func testTrimmingWhitespace() {
        func test(_ str: String, _ expected: String, file: StaticString = #file, line: UInt = #line) {
            XCTAssertEqual(str._trimmingWhitespace(), expected, file: file, line: line)
        }
        test(" \tABCDEFGAbc \t \t  ", "ABCDEFGAbc")
        test("ABCDEFGAbc \t \t  ", "ABCDEFGAbc")
        test(" \tABCDEFGAbc", "ABCDEFGAbc")
        test(" \t\t\t    \t\t   \t", "")
        test(" X", "X")
        test("X ", "X")
        test("X", "X")
        test("", "")
        test("X\u{00A0}", "X") // NBSP
        test(" \u{202F}\u{00A0} X \u{202F}\u{00A0}", "X") // NBSP and narrow NBSP
    }

    func testTrimmingCharactersWithPredicate() {
        func test(_ str: String, while predicate: (Character) -> Bool, _ expected: Substring, file: StaticString = #file, line: UInt = #line) {
            XCTAssertEqual(str._trimmingCharacters(while: predicate), expected, file: file, line: line)
        }

        typealias TrimmingPredicate = (Character) -> Bool

        let isNewline: TrimmingPredicate = { $0.isNewline }

        test("\u{2028}ABCDEFGAbc \u{2028}", while: isNewline, "ABCDEFGAbc ")
        test("\nABCDEFGAbc \n\n", while: isNewline, "ABCDEFGAbc ")
        test("\n\u{2028}ABCDEFGAbc \n\u{2028}\n", while: isNewline, "ABCDEFGAbc ")
        test("\u{2029}ABCDEFGAbc \u{2029}", while: isNewline, "ABCDEFGAbc ")
        test("\nABCDEFGAbc \n\u{2029}\n", while: isNewline, "ABCDEFGAbc ")
        test(" \n    \n\n\t   \n\t\n", while: { $0.isNewline || $0.isWhitespace }, "")

        let isNumber: TrimmingPredicate = { $0.isNumber }

        test("1B", while: isNumber, "B")
        test("11 B22", while: isNumber, " B")
        test("11 B\u{0662}\u{0661}", while: isNumber, " B") // ARABIC-INDIC DIGIT TWO and ONE
        test(" B 22", while: isNumber, " B ")
        test(" B \u{0662}\u{0661}", while: isNumber, " B ")

        test("11 B\u{0662}\u{0661}", while: { $0.isNumber || $0.isASCII }, "") // ARABIC-INDIC DIGIT TWO and ONE
        test("\u{ffff}a\u{ffff}", while: { !$0.isNumber && !$0.isASCII }, "a")

        let isLowercase: TrimmingPredicate = { $0.isLowercase }
        let isLetter: TrimmingPredicate = { $0.isLetter }
        let isUppercase: TrimmingPredicate = { $0.isUppercase }

        test("AB🏳️‍🌈xyz👩‍👩‍👧‍👦ab", while: isLetter, "🏳️‍🌈xyz👩‍👩‍👧‍👦")
        test("AB🏳️‍🌈xyz👩‍👩‍👧‍👦ab", while: isUppercase, "🏳️‍🌈xyz👩‍👩‍👧‍👦ab")
        test("AB🏳️‍🌈xyz👩‍👩‍👧‍👦ab", while: isLowercase, "AB🏳️‍🌈xyz👩‍👩‍👧‍👦")

        test("cafe\u{0301}abcABC123", while: { $0.isLetter || $0.isNumber }, "")
        test("cafe\u{0301}abcABC123", while: isLetter, "123")
        test("cafe\u{0301}abcABC123", while: isLowercase, "ABC123")

        test("\u{0301}abc123xyz\u{0301}", while: isLetter, "\u{0301}abc123") // \u{0301} isn't a letter on its own, but it is when normalized and combined with the previous character
        test("\u{0301}abc123xyz\u{0301}", while: isLowercase, "\u{0301}abc123")

        test("+a+b+c+1+2+3++", while: { $0.isSymbol }, "a+b+c+1+2+3")
        test("+a+b+c+1+2+3!!", while: { $0.isPunctuation }, "+a+b+c+1+2+3")

        let alwaysReject: TrimmingPredicate = { _ in return false }

        test("", while: alwaysReject, "")
        test("🏳️‍🌈xyz👩‍👩‍👧‍👦", while: alwaysReject, "🏳️‍🌈xyz👩‍👩‍👧‍👦")
        test("11 B\u{0662}\u{0661}", while: alwaysReject, "11 B\u{0662}\u{0661}")

        let alwaysTrim: TrimmingPredicate = { _ in return true }

        test("🏳️‍🌈xyz👩‍👩‍👧‍👦", while: alwaysTrim, "")
        test("11 B\u{0662}\u{0661}", while: alwaysTrim, "")
    }
}
