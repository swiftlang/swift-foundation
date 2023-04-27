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

final class StringTests: XCTestCase {
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
}
