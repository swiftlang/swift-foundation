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

import Testing

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif os(WASI)
import WASILibc
#elseif os(Windows)
import CRT
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable import FoundationEssentials
#endif

@Suite("String")
private struct StringTests {
    // MARK: - Case mapping

    @Test func testCapitalize() {
        func test(_ string: String, _ expected: String, sourceLocation: SourceLocation = #_sourceLocation) {
            #expect(string.capitalized == expected, sourceLocation: sourceLocation)
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

    @Test func testTrimmingWhitespace() {
        func test(_ string: String, _ expected: String, sourceLocation: SourceLocation = #_sourceLocation) {
            #expect(string._trimmingWhitespace() == expected, sourceLocation: sourceLocation)
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

    @Test func testTrimmingCharactersWithPredicate() {
        typealias TrimmingPredicate = (Character) -> Bool
        
        func test(_ str: String, while predicate: TrimmingPredicate, _ expected: Substring, sourceLocation: SourceLocation = #_sourceLocation) {
            #expect(str._trimmingCharacters(while: predicate) == expected, sourceLocation: sourceLocation)
        }

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

    func _testRangeOfString(_ tested: String, string: String, anchored: Bool, backwards: Bool, _ expectation: Range<Int>?, sourceLocation: SourceLocation = #_sourceLocation) {
        let result = tested._range(of: string, anchored: anchored, backwards: backwards)
        var exp: Range<String.Index>?
        if let expectation {
            exp = tested.index(tested.startIndex, offsetBy: expectation.lowerBound) ..< tested.index(tested.startIndex, offsetBy: expectation.upperBound)
        } else {
            exp = nil
        }

        var message: Comment
        if let result {
            let readableRange = tested.distance(from: tested.startIndex, to: result.lowerBound)..<tested.distance(from: tested.startIndex, to: result.upperBound)
            message = "Actual: \(readableRange)"
        } else {
            message = "Actual: nil"
        }
        #expect(result == exp, message, sourceLocation: sourceLocation)
    }

    @Test func testRangeOfString() {
        var tested: String
        func testASCII(_ string: String, anchored: Bool, backwards: Bool, _ expectation: Range<Int>?, sourceLocation: SourceLocation = #_sourceLocation) {
            return _testRangeOfString(tested, string: string, anchored: anchored, backwards: backwards, expectation, sourceLocation: sourceLocation)
        }

        tested = "ABCDEFGAbcABCDE"
        testASCII("", anchored: false, backwards: false, 0..<0)
        testASCII("A", anchored: false, backwards: false, 0..<1)
        testASCII("B", anchored: false, backwards: false, 1..<2)
        testASCII("b", anchored: false, backwards: false, 8..<9)
        testASCII("FG", anchored: false, backwards: false, 5..<7)
        testASCII("FGH", anchored: false, backwards: false, nil)
        testASCII("cde", anchored: false, backwards: false, nil)
        testASCII("CDE", anchored: false, backwards: false, 2..<5)

        testASCII("", anchored: true, backwards: false, 0..<0)
        testASCII("AB", anchored: true, backwards: false, 0..<2)
        testASCII("ab", anchored: true, backwards: false, nil)
        testASCII("BC", anchored: true, backwards: false, nil)
        testASCII("bc", anchored: true, backwards: false, nil)

        testASCII("", anchored: false, backwards: true, 15..<15)
        testASCII("A", anchored: false, backwards: true, 10..<11)
        testASCII("B", anchored: false, backwards: true, 11..<12)
        testASCII("b", anchored: false, backwards: true, 8..<9)
        testASCII("FG", anchored: false, backwards: true, 5..<7)
        testASCII("FGH", anchored: false, backwards: true, nil)
        testASCII("cde", anchored: false, backwards: true, nil)
        testASCII("CDE", anchored: false, backwards: true, 12..<15)

        testASCII("", anchored: true, backwards: true, 15..<15)
        testASCII("AB", anchored: true, backwards: true, nil)
        testASCII("ab", anchored: true, backwards: true, nil)
        testASCII("BC", anchored: true, backwards: true, nil)
        testASCII("bc", anchored: true, backwards: true, nil)
        testASCII("bcd", anchored: true, backwards: true, nil)
        testASCII("B", anchored: true, backwards: true, nil)
        testASCII("b", anchored: true, backwards: true, nil)
        testASCII("FG", anchored: true, backwards: true, nil)
        testASCII("FGH", anchored: true, backwards: true, nil)
        testASCII("cde", anchored: true, backwards: true, nil)
        testASCII("CDE", anchored: true, backwards: true, 12..<15)
        testASCII("ABCDE", anchored: true, backwards: true, 10..<15)
        testASCII("E", anchored: true, backwards: true, 14..<15)

        tested = ""
        testASCII("ABCDER", anchored: false, backwards: false, nil)
    }

    @Test func testRangeOfString_graphemeCluster() {
        var tested: String
        func test(_ string: String, anchored: Bool, backwards: Bool, _ expectation: Range<Int>?, sourceLocation: SourceLocation = #_sourceLocation) {
            return _testRangeOfString(tested, string: string, anchored: anchored, backwards: backwards, expectation, sourceLocation: sourceLocation)
        }

        do {
            // 🏳️‍🌈 = U+1F3F3 U+FE0F U+200D U+1F308
            // 👩‍👩‍👧‍👦 = U+1F469 U+200D U+1F469 U+200D U+1F467 U+200D U+1F466
            // 🕵️‍♀️ = U+1F575 U+FE0F U+200D U+2640 U+FE0F
            tested = "🏳️‍🌈AB👩‍👩‍👧‍👦ab🕵️‍♀️"

            test("🏳️‍🌈", anchored: false, backwards: false, 0..<1)
            test("🏳", anchored: false, backwards: false, nil) // U+1F3F3

            test("🏳️‍🌈A", anchored: false, backwards: false, 0..<2)

            test("B👩‍👩‍👧‍👦a", anchored: false, backwards: false, 2..<5)
            test("b🕵️‍♀️", anchored: false, backwards: false, 5..<7)


            test("🏳️‍🌈A", anchored: true, backwards: false, 0..<2)
            test("ＡＢ", anchored: true, backwards: false, nil)
            test("B👩‍👩‍👧‍👦a", anchored: true, backwards: false, nil)
            test("b🕵️‍♀️", anchored: true, backwards: false, nil)

            test("🏳️‍🌈", anchored: true, backwards: true, nil)
            test("B👩‍👩‍👧‍👦a", anchored: true, backwards: true, nil)
            test("🕵️‍♀️", anchored: true, backwards: true, 6..<7)
            test("b🕵️‍♀️", anchored: true, backwards: true, 5..<7)
            test("B🕵️‍♀️", anchored: true, backwards: true, nil)

        }
    }

    @Test func testRangeOfString_lineSeparator() {
        func test(_ tested: String, _ string: String, anchored: Bool, backwards: Bool, _ expectation: Range<Int>?, sourceLocation: SourceLocation = #_sourceLocation) {
            return _testRangeOfString(tested, string: string, anchored: anchored, backwards: backwards, expectation, sourceLocation: sourceLocation)
        }
        test("\r\n \r", "\r", anchored: false, backwards: false, 2..<3)
        test("\r\n \r", "\r", anchored: true, backwards: false, nil)
        test("\r\n \r", "\r", anchored: false, backwards: true, 2..<3)
        test("\r\n \r", "\r", anchored: true, backwards: true, 2..<3)

        test("\r \r\n \r", "\r", anchored: false, backwards: false, 0..<1)
        test("\r \r\n \r", "\r", anchored: true, backwards: false, 0..<1)
        test("\r \r\n \r", "\r", anchored: false, backwards: true, 4..<5)
        test("\r \r\n \r", "\r", anchored: true, backwards: true, 4..<5)
    }

    @Test func testTryFromUTF16() {
        func test(_ utf16Buffer: [UInt16], expected: String?, sourceLocation: SourceLocation = #_sourceLocation) {
            let result = utf16Buffer.withUnsafeBufferPointer {
                String(_utf16: $0)
            }

            #expect(result == expected, sourceLocation: sourceLocation)
        }

        test([], expected: "")
        test([ 0x00 ], expected: "\u{0000}")
        test([ 0x24 ], expected: "$")
        test([ 0x41, 0x42 ], expected: "AB")
        test([ 0x20AC ], expected: "\u{20AC}")
        test([ 0x3040, 0x3041, 0xFFEF ], expected: "\u{3040}\u{3041}\u{FFEF}")
        test([ 0x0939, 0x0940 ], expected: "\u{0939}\u{0940}")

        // surrogates
        test([ 0xD801, 0xDC37 ], expected: "\u{10437}")
        test([ 0xD852, 0xDF62 ], expected: "\u{24B62}")
        test([ 0x41, 0x42, 0xD852, 0xDF62 ], expected: "AB\u{24B62}")

        // invalid input
        test([ 0xD800 ], expected: nil)
        test([ 0x42, 0xD800 ], expected: nil)
        test([ 0xD800, 0x42 ], expected: nil)
    }

    @Test func testTryFromUTF16_roundtrip() {

        func test(_ string: String, sourceLocation: SourceLocation = #_sourceLocation) {
            let utf16Array = Array(string.utf16)
            let res = utf16Array.withUnsafeBufferPointer {
                String(_utf16: $0)
            }
            #expect(res == string, sourceLocation: sourceLocation)
        }

        // BMP: consists code points up to U+FFFF
        test("")
        test("\t\t\n abcFooFOO \n FOOc\t \t 123 \n")
        test("the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy the quick brown fox jumps over the lazy dogz")
        test("\u{3040}\u{3041}\u{FFEF}")
        test("\u{3040}\u{3041}\u{FFEF}abbbc\u{FFFF}\u{FFF0}\u{FFF1}")

        // surrogates: U+010000 to U+10FFFF
        test("\u{10437}\u{24B62}\u{10001}\u{10FFFF}")

        test("\u{1F425}")
        test("🏳️‍🌈AB👩‍👩‍👧‍👦ab🕵️‍♀️")
    }

    @Test func testRangeRegexB() throws {
        let str = "self.name"
        let range = try str[...]._range(of: "\\bname"[...], options: .regularExpression)
        let start = str.index(str.startIndex, offsetBy: 5)
        let end = str.index(str.startIndex, offsetBy: 9)
        #expect(range == start ..< end)
    }
    
    @Test func testParagraphLineRangeOfSeparator() {
        for separator in ["\n", "\r", "\r\n", "\u{2029}", "\u{2028}", "\u{85}"] {
            let range = separator.startIndex ..< separator.endIndex
            let paragraphResult = separator._paragraphBounds(around: range)
            let lineResult = separator._lineBounds(around: range)
            #expect(paragraphResult.start ..< paragraphResult.end == range)
            #expect(lineResult.start ..< lineResult.end == range)
        }
    }
    
    @Test func testAlmostMatchingSeparator() {
        let string = "A\u{200D}B" // U+200D Zero Width Joiner (ZWJ) matches U+2028 Line Separator except for the final UTF-8 scalar
        let lineResult = string._lineBounds(around: string.startIndex ..< string.startIndex)
        #expect(lineResult.start == string.startIndex)
        #expect(lineResult.end == string.endIndex)
        #expect(lineResult.contentsEnd == string.endIndex)
    }
    
    @Test func testFileSystemRepresentation() throws {
        func assertCString(_ ptr: UnsafePointer<CChar>, equals other: String, sourceLocation: SourceLocation = #_sourceLocation) {
            #expect(String(cString: ptr) == other, sourceLocation: sourceLocation)
        }

#if os(Windows)
        let original = #"\Path1\Path Two\Path Three\Some Really Long File Name Section.txt"#
#else
        let original = "/Path1/Path Two/Path Three/Some Really Long File Name Section.txt"
#endif
        try original.withFileSystemRepresentation {
            assertCString(try #require($0), equals: original)
        }
        
        let withWhitespace = original + "\u{2000}\u{2001}"
        try withWhitespace.withFileSystemRepresentation {
            assertCString(try #require($0), equals: withWhitespace)
        }
        
        let withHangul = original + "\u{AC00}\u{AC01}"
        try withHangul.withFileSystemRepresentation { buf1 in
            let buf1 = try #require(buf1)
            try buf1.withMemoryRebound(to: UInt8.self, capacity: strlen(buf1)) { buf1Rebound in
                let fsr = String(decodingCString: buf1Rebound, as: UTF8.self)
                try fsr.withFileSystemRepresentation { buf2 in
                    let buf2 = try #require(buf2)
                    #expect(strcmp(buf1, buf2) == 0)
                }
            }
        }
        
        let withNullSuffix = original + "\u{0000}\u{0000}"
        try withNullSuffix.withFileSystemRepresentation {
            assertCString(try #require($0), equals: original)
        }
        
#if canImport(Darwin) || FOUNDATION_FRAMEWORK
        // The buffer should dynamically grow and not be limited to a size of PATH_MAX
        Array(repeating: "A", count: Int(PATH_MAX) - 1).joined().withFileSystemRepresentation { ptr in
            #expect(ptr != nil)
        }
        
        Array(repeating: "A", count: Int(PATH_MAX)).joined().withFileSystemRepresentation { ptr in
            #expect(ptr != nil)
        }
        
        // The buffer should fit the scalars that expand the most during decomposition
        for string in ["\u{1D160}", "\u{0CCB}", "\u{0390}"] {
            string.withFileSystemRepresentation { ptr in
                #expect(ptr != nil, "Could not create file system representation for \(string.debugDescription)")
            }
        }
#endif
    }

    @Test func testLastPathComponent() {
        #expect("".lastPathComponent == "")
        #expect("a".lastPathComponent == "a")
        #expect("/a".lastPathComponent == "a")
        #expect("a/".lastPathComponent == "a")
        #expect("/a/".lastPathComponent == "a")

        #expect("a/b".lastPathComponent == "b")
        #expect("/a/b".lastPathComponent == "b")
        #expect("a/b/".lastPathComponent == "b")
        #expect("/a/b/".lastPathComponent == "b")

        #expect("a//".lastPathComponent == "a")
        #expect("a////".lastPathComponent == "a")
        #expect("/a//".lastPathComponent == "a")
        #expect("/a////".lastPathComponent == "a")
        #expect("//a//".lastPathComponent == "a")
        #expect("/a/b//".lastPathComponent == "b")
        #expect("//a//b////".lastPathComponent == "b")

        #expect("/".lastPathComponent == "/")
        #expect("//".lastPathComponent == "/")
        #expect("/////".lastPathComponent == "/")
        #expect("/./..//./..//".lastPathComponent == "..")
        #expect("/😎/😂/❤️/".lastPathComponent == "❤️")
    }

    @Test func testRemovingDotSegments() {
        #expect(".".removingDotSegments == "")
        #expect("..".removingDotSegments == "")
        #expect("../".removingDotSegments == "")
        #expect("../.".removingDotSegments == "")
        #expect("../..".removingDotSegments == "")
        #expect("../../".removingDotSegments == "")
        #expect("../../.".removingDotSegments == "")
        #expect("../../..".removingDotSegments == "")
        #expect("../../../".removingDotSegments == "")
        #expect("../.././".removingDotSegments == "")
        #expect("../../a".removingDotSegments == "a")
        #expect("../../a/".removingDotSegments == "a/")
        #expect(".././".removingDotSegments == "")
        #expect(".././.".removingDotSegments == "")
        #expect(".././..".removingDotSegments == "")
        #expect(".././../".removingDotSegments == "")
        #expect("../././".removingDotSegments == "")
        #expect(".././a".removingDotSegments == "a")
        #expect(".././a/".removingDotSegments == "a/")
        #expect("../a".removingDotSegments == "a")
        #expect("../a/".removingDotSegments == "a/")
        #expect("../a/.".removingDotSegments == "a/")
        #expect("../a/..".removingDotSegments == "/")
        #expect("../a/../".removingDotSegments == "/")
        #expect("../a/./".removingDotSegments == "a/")
        #expect("../a/b".removingDotSegments == "a/b")
        #expect("../a/b/".removingDotSegments == "a/b/")
        #expect("./".removingDotSegments == "")
        #expect("./.".removingDotSegments == "")
        #expect("./..".removingDotSegments == "")
        #expect("./../".removingDotSegments == "")
        #expect("./../.".removingDotSegments == "")
        #expect("./../..".removingDotSegments == "")
        #expect("./../../".removingDotSegments == "")
        #expect("./.././".removingDotSegments == "")
        #expect("./../a".removingDotSegments == "a")
        #expect("./../a/".removingDotSegments == "a/")
        #expect("././".removingDotSegments == "")
        #expect("././.".removingDotSegments == "")
        #expect("././..".removingDotSegments == "")
        #expect("././../".removingDotSegments == "")
        #expect("./././".removingDotSegments == "")
        #expect("././a".removingDotSegments == "a")
        #expect("././a/".removingDotSegments == "a/")
        #expect("./a".removingDotSegments == "a")
        #expect("./a/".removingDotSegments == "a/")
        #expect("./a/.".removingDotSegments == "a/")
        #expect("./a/..".removingDotSegments == "/")
        #expect("./a/../".removingDotSegments == "/")
        #expect("./a/./".removingDotSegments == "a/")
        #expect("./a/b".removingDotSegments == "a/b")
        #expect("./a/b/".removingDotSegments == "a/b/")
        #expect("/".removingDotSegments == "/")
        #expect("/.".removingDotSegments == "/")
        #expect("/..".removingDotSegments == "/")
        #expect("/../".removingDotSegments == "/")
        #expect("/../.".removingDotSegments == "/")
        #expect("/../..".removingDotSegments == "/")
        #expect("/../../".removingDotSegments == "/")
        #expect("/../../.".removingDotSegments == "/")
        #expect("/../../..".removingDotSegments == "/")
        #expect("/../../../".removingDotSegments == "/")
        #expect("/../.././".removingDotSegments == "/")
        #expect("/../../a".removingDotSegments == "/a")
        #expect("/../../a/".removingDotSegments == "/a/")
        #expect("/.././".removingDotSegments == "/")
        #expect("/.././.".removingDotSegments == "/")
        #expect("/.././..".removingDotSegments == "/")
        #expect("/.././../".removingDotSegments == "/")
        #expect("/../././".removingDotSegments == "/")
        #expect("/.././a".removingDotSegments == "/a")
        #expect("/.././a/".removingDotSegments == "/a/")
        #expect("/../a".removingDotSegments == "/a")
        #expect("/../a/".removingDotSegments == "/a/")
        #expect("/../a/.".removingDotSegments == "/a/")
        #expect("/../a/..".removingDotSegments == "/")
        #expect("/../a/../".removingDotSegments == "/")
        #expect("/../a/./".removingDotSegments == "/a/")
        #expect("/../a/b".removingDotSegments == "/a/b")
        #expect("/../a/b/".removingDotSegments == "/a/b/")
        #expect("/./".removingDotSegments == "/")
        #expect("/./.".removingDotSegments == "/")
        #expect("/./..".removingDotSegments == "/")
        #expect("/./../".removingDotSegments == "/")
        #expect("/./../.".removingDotSegments == "/")
        #expect("/./../..".removingDotSegments == "/")
        #expect("/./../../".removingDotSegments == "/")
        #expect("/./.././".removingDotSegments == "/")
        #expect("/./../a".removingDotSegments == "/a")
        #expect("/./../a/".removingDotSegments == "/a/")
        #expect("/././".removingDotSegments == "/")
        #expect("/././.".removingDotSegments == "/")
        #expect("/././..".removingDotSegments == "/")
        #expect("/././../".removingDotSegments == "/")
        #expect("/./././".removingDotSegments == "/")
        #expect("/././a".removingDotSegments == "/a")
        #expect("/././a/".removingDotSegments == "/a/")
        #expect("/./a".removingDotSegments == "/a")
        #expect("/./a/".removingDotSegments == "/a/")
        #expect("/./a/.".removingDotSegments == "/a/")
        #expect("/./a/..".removingDotSegments == "/")
        #expect("/./a/../".removingDotSegments == "/")
        #expect("/./a/./".removingDotSegments == "/a/")
        #expect("/./a/b".removingDotSegments == "/a/b")
        #expect("/./a/b/".removingDotSegments == "/a/b/")
        #expect("/a".removingDotSegments == "/a")
        #expect("/a/".removingDotSegments == "/a/")
        #expect("/a/.".removingDotSegments == "/a/")
        #expect("/a/..".removingDotSegments == "/")
        #expect("/a/../".removingDotSegments == "/")
        #expect("/a/../.".removingDotSegments == "/")
        #expect("/a/../..".removingDotSegments == "/")
        #expect("/a/../../".removingDotSegments == "/")
        #expect("/a/.././".removingDotSegments == "/")
        #expect("/a/../b".removingDotSegments == "/b")
        #expect("/a/../b/".removingDotSegments == "/b/")
        #expect("/a/./".removingDotSegments == "/a/")
        #expect("/a/./.".removingDotSegments == "/a/")
        #expect("/a/./..".removingDotSegments == "/")
        #expect("/a/./../".removingDotSegments == "/")
        #expect("/a/././".removingDotSegments == "/a/")
        #expect("/a/./b".removingDotSegments == "/a/b")
        #expect("/a/./b/".removingDotSegments == "/a/b/")
        #expect("/a/b".removingDotSegments == "/a/b")
        #expect("/a/b/".removingDotSegments == "/a/b/")
        #expect("/a/b/.".removingDotSegments == "/a/b/")
        #expect("/a/b/..".removingDotSegments == "/a/")
        #expect("/a/b/../".removingDotSegments == "/a/")
        #expect("/a/b/../.".removingDotSegments == "/a/")
        #expect("/a/b/../..".removingDotSegments == "/")
        #expect("/a/b/../../".removingDotSegments == "/")
        #expect("/a/b/.././".removingDotSegments == "/a/")
        #expect("/a/b/../c".removingDotSegments == "/a/c")
        #expect("/a/b/../c/".removingDotSegments == "/a/c/")
        #expect("/a/b/./".removingDotSegments == "/a/b/")
        #expect("/a/b/./.".removingDotSegments == "/a/b/")
        #expect("/a/b/./..".removingDotSegments == "/a/")
        #expect("/a/b/./../".removingDotSegments == "/a/")
        #expect("/a/b/././".removingDotSegments == "/a/b/")
        #expect("/a/b/./c".removingDotSegments == "/a/b/c")
        #expect("/a/b/./c/".removingDotSegments == "/a/b/c/")
        #expect("/a/b/c".removingDotSegments == "/a/b/c")
        #expect("/a/b/c/".removingDotSegments == "/a/b/c/")
        #expect("/a/b/c/.".removingDotSegments == "/a/b/c/")
        #expect("/a/b/c/..".removingDotSegments == "/a/b/")
        #expect("/a/b/c/../".removingDotSegments == "/a/b/")
        #expect("/a/b/c/./".removingDotSegments == "/a/b/c/")
        #expect("a".removingDotSegments == "a")
        #expect("a/".removingDotSegments == "a/")
        #expect("a/.".removingDotSegments == "a/")
        #expect("a/..".removingDotSegments == "/")
        #expect("a/../".removingDotSegments == "/")
        #expect("a/../.".removingDotSegments == "/")
        #expect("a/../..".removingDotSegments == "/")
        #expect("a/../../".removingDotSegments == "/")
        #expect("a/.././".removingDotSegments == "/")
        #expect("a/../b".removingDotSegments == "/b")
        #expect("a/../b/".removingDotSegments == "/b/")
        #expect("a/./".removingDotSegments == "a/")
        #expect("a/./.".removingDotSegments == "a/")
        #expect("a/./..".removingDotSegments == "/")
        #expect("a/./../".removingDotSegments == "/")
        #expect("a/././".removingDotSegments == "a/")
        #expect("a/./b".removingDotSegments == "a/b")
        #expect("a/./b/".removingDotSegments == "a/b/")
        #expect("a/b".removingDotSegments == "a/b")
        #expect("a/b/".removingDotSegments == "a/b/")
        #expect("a/b/.".removingDotSegments == "a/b/")
        #expect("a/b/..".removingDotSegments == "a/")
        #expect("a/b/../".removingDotSegments == "a/")
        #expect("a/b/../.".removingDotSegments == "a/")
        #expect("a/b/../..".removingDotSegments == "/")
        #expect("a/b/../../".removingDotSegments == "/")
        #expect("a/b/.././".removingDotSegments == "a/")
        #expect("a/b/../c".removingDotSegments == "a/c")
        #expect("a/b/../c/".removingDotSegments == "a/c/")
        #expect("a/b/./".removingDotSegments == "a/b/")
        #expect("a/b/./.".removingDotSegments == "a/b/")
        #expect("a/b/./..".removingDotSegments == "a/")
        #expect("a/b/./../".removingDotSegments == "a/")
        #expect("a/b/././".removingDotSegments == "a/b/")
        #expect("a/b/./c".removingDotSegments == "a/b/c")
        #expect("a/b/./c/".removingDotSegments == "a/b/c/")
        #expect("a/b/c".removingDotSegments == "a/b/c")
        #expect("a/b/c/".removingDotSegments == "a/b/c/")
        #expect("a/b/c/.".removingDotSegments == "a/b/c/")
        #expect("a/b/c/..".removingDotSegments == "a/b/")
        #expect("a/b/c/../".removingDotSegments == "a/b/")
        #expect("a/b/c/./".removingDotSegments == "a/b/c/")

        // None of the inputs below contain "." or ".." and should therefore be treated as regular path components

        #expect("...".removingDotSegments == "...")
        #expect(".../".removingDotSegments == ".../")
        #expect(".../...".removingDotSegments == ".../...")
        #expect(".../.../".removingDotSegments == ".../.../")
        #expect(".../..a".removingDotSegments == ".../..a")
        #expect(".../..a/".removingDotSegments == ".../..a/")
        #expect(".../.a".removingDotSegments == ".../.a")
        #expect(".../.a/".removingDotSegments == ".../.a/")
        #expect(".../a.".removingDotSegments == ".../a.")
        #expect(".../a..".removingDotSegments == ".../a..")
        #expect(".../a../".removingDotSegments == ".../a../")
        #expect(".../a./".removingDotSegments == ".../a./")
        #expect("..a".removingDotSegments == "..a")
        #expect("..a/".removingDotSegments == "..a/")
        #expect("..a/...".removingDotSegments == "..a/...")
        #expect("..a/.../".removingDotSegments == "..a/.../")
        #expect("..a/..b".removingDotSegments == "..a/..b")
        #expect("..a/..b/".removingDotSegments == "..a/..b/")
        #expect("..a/.b".removingDotSegments == "..a/.b")
        #expect("..a/.b/".removingDotSegments == "..a/.b/")
        #expect("..a/b.".removingDotSegments == "..a/b.")
        #expect("..a/b..".removingDotSegments == "..a/b..")
        #expect("..a/b../".removingDotSegments == "..a/b../")
        #expect("..a/b./".removingDotSegments == "..a/b./")
        #expect(".a".removingDotSegments == ".a")
        #expect(".a/".removingDotSegments == ".a/")
        #expect(".a/...".removingDotSegments == ".a/...")
        #expect(".a/.../".removingDotSegments == ".a/.../")
        #expect(".a/..b".removingDotSegments == ".a/..b")
        #expect(".a/..b/".removingDotSegments == ".a/..b/")
        #expect(".a/.b".removingDotSegments == ".a/.b")
        #expect(".a/.b/".removingDotSegments == ".a/.b/")
        #expect(".a/b.".removingDotSegments == ".a/b.")
        #expect(".a/b..".removingDotSegments == ".a/b..")
        #expect(".a/b../".removingDotSegments == ".a/b../")
        #expect(".a/b./".removingDotSegments == ".a/b./")
        #expect("/".removingDotSegments == "/")
        #expect("/...".removingDotSegments == "/...")
        #expect("/.../".removingDotSegments == "/.../")
        #expect("/..a".removingDotSegments == "/..a")
        #expect("/..a/".removingDotSegments == "/..a/")
        #expect("/.a".removingDotSegments == "/.a")
        #expect("/.a/".removingDotSegments == "/.a/")
        #expect("/a.".removingDotSegments == "/a.")
        #expect("/a..".removingDotSegments == "/a..")
        #expect("/a../".removingDotSegments == "/a../")
        #expect("/a./".removingDotSegments == "/a./")
        #expect("a.".removingDotSegments == "a.")
        #expect("a..".removingDotSegments == "a..")
        #expect("a../".removingDotSegments == "a../")
        #expect("a../...".removingDotSegments == "a../...")
        #expect("a../.../".removingDotSegments == "a../.../")
        #expect("a../..b".removingDotSegments == "a../..b")
        #expect("a../..b/".removingDotSegments == "a../..b/")
        #expect("a../.b".removingDotSegments == "a../.b")
        #expect("a../.b/".removingDotSegments == "a../.b/")
        #expect("a../b.".removingDotSegments == "a../b.")
        #expect("a../b..".removingDotSegments == "a../b..")
        #expect("a../b../".removingDotSegments == "a../b../")
        #expect("a../b./".removingDotSegments == "a../b./")
        #expect("a./".removingDotSegments == "a./")
        #expect("a./...".removingDotSegments == "a./...")
        #expect("a./.../".removingDotSegments == "a./.../")
        #expect("a./..b".removingDotSegments == "a./..b")
        #expect("a./..b/".removingDotSegments == "a./..b/")
        #expect("a./.b".removingDotSegments == "a./.b")
        #expect("a./.b/".removingDotSegments == "a./.b/")
        #expect("a./b.".removingDotSegments == "a./b.")
        #expect("a./b..".removingDotSegments == "a./b..")
        #expect("a./b../".removingDotSegments == "a./b../")
        #expect("a./b./".removingDotSegments == "a./b./")

        // Repeated slashes should not be resolved when only removing dot segments

        #expect("../..//".removingDotSegments == "/")
        #expect(".././/".removingDotSegments == "/")
        #expect("..//".removingDotSegments == "/")
        #expect("..//.".removingDotSegments == "/")
        #expect("..//..".removingDotSegments == "/")
        #expect("..//../".removingDotSegments == "/")
        #expect("..//./".removingDotSegments == "/")
        #expect("..///".removingDotSegments == "//")
        #expect("..//a".removingDotSegments == "/a")
        #expect("..//a/".removingDotSegments == "/a/")
        #expect("../a//".removingDotSegments == "a//")
        #expect("./..//".removingDotSegments == "/")
        #expect("././/".removingDotSegments == "/")
        #expect(".//".removingDotSegments == "/")
        #expect(".//.".removingDotSegments == "/")
        #expect(".//..".removingDotSegments == "/")
        #expect(".//../".removingDotSegments == "/")
        #expect(".//./".removingDotSegments == "/")
        #expect(".///".removingDotSegments == "//")
        #expect(".//a".removingDotSegments == "/a")
        #expect(".//a/".removingDotSegments == "/a/")
        #expect("./a//".removingDotSegments == "a//")
        #expect("/../..//".removingDotSegments == "//")
        #expect("/.././/".removingDotSegments == "//")
        #expect("/..//".removingDotSegments == "//")
        #expect("/..//.".removingDotSegments == "//")
        #expect("/..//..".removingDotSegments == "/")
        #expect("/..//../".removingDotSegments == "/")
        #expect("/..//./".removingDotSegments == "//")
        #expect("/..///".removingDotSegments == "///")
        #expect("/..//a".removingDotSegments == "//a")
        #expect("/..//a/".removingDotSegments == "//a/")
        #expect("/../a//".removingDotSegments == "/a//")
        #expect("/./..//".removingDotSegments == "//")
        #expect("/././/".removingDotSegments == "//")
        #expect("/.//".removingDotSegments == "//")
        #expect("/.//.".removingDotSegments == "//")
        #expect("/.//..".removingDotSegments == "/")
        #expect("/.//../".removingDotSegments == "/")
        #expect("/.//./".removingDotSegments == "//")
        #expect("/.///".removingDotSegments == "///")
        #expect("/.//a".removingDotSegments == "//a")
        #expect("/.//a/".removingDotSegments == "//a/")
        #expect("/./a//".removingDotSegments == "/a//")
        #expect("//".removingDotSegments == "//")
        #expect("//.".removingDotSegments == "//")
        #expect("//..".removingDotSegments == "/")
        #expect("//../".removingDotSegments == "/")
        #expect("//./".removingDotSegments == "//")
        #expect("///".removingDotSegments == "///")
        #expect("//a".removingDotSegments == "//a")
        #expect("//a/".removingDotSegments == "//a/")
        #expect("/a/..//".removingDotSegments == "//")
        #expect("/a/.//".removingDotSegments == "/a//")
        #expect("/a//".removingDotSegments == "/a//")
        #expect("/a//.".removingDotSegments == "/a//")
        #expect("/a//..".removingDotSegments == "/a/")
        #expect("/a//../".removingDotSegments == "/a/")
        #expect("/a//./".removingDotSegments == "/a//")
        #expect("/a///".removingDotSegments == "/a///")
        #expect("/a//b".removingDotSegments == "/a//b")
        #expect("/a//b/".removingDotSegments == "/a//b/")
        #expect("/a/b/..//".removingDotSegments == "/a//")
        #expect("/a/b/.//".removingDotSegments == "/a/b//")
        #expect("/a/b//".removingDotSegments == "/a/b//")
        #expect("/a/b//.".removingDotSegments == "/a/b//")
        #expect("/a/b//..".removingDotSegments == "/a/b/")
        #expect("/a/b//../".removingDotSegments == "/a/b/")
        #expect("/a/b//./".removingDotSegments == "/a/b//")
        #expect("/a/b///".removingDotSegments == "/a/b///")
        #expect("/a/b//c".removingDotSegments == "/a/b//c")
        #expect("/a/b//c/".removingDotSegments == "/a/b//c/")
        #expect("/a/b/c//".removingDotSegments == "/a/b/c//")
        #expect("a/..//".removingDotSegments == "//")
        #expect("a/.//".removingDotSegments == "a//")
        #expect("a//".removingDotSegments == "a//")
        #expect("a//.".removingDotSegments == "a//")
        #expect("a//..".removingDotSegments == "a/")
        #expect("a//../".removingDotSegments == "a/")
        #expect("a//./".removingDotSegments == "a//")
        #expect("a///".removingDotSegments == "a///")
        #expect("a//b".removingDotSegments == "a//b")
        #expect("a//b/".removingDotSegments == "a//b/")
        #expect("a/b/..//".removingDotSegments == "a//")
        #expect("a/b/.//".removingDotSegments == "a/b//")
        #expect("a/b//".removingDotSegments == "a/b//")
        #expect("a/b//.".removingDotSegments == "a/b//")
        #expect("a/b//..".removingDotSegments == "a/b/")
        #expect("a/b//../".removingDotSegments == "a/b/")
        #expect("a/b//./".removingDotSegments == "a/b//")
        #expect("a/b///".removingDotSegments == "a/b///")
        #expect("a/b//c".removingDotSegments == "a/b//c")
        #expect("a/b//c/".removingDotSegments == "a/b//c/")
        #expect("a/b/c//".removingDotSegments == "a/b/c//")
    }

    @Test func testPathExtension() {
        let stringNoExtension = "0123456789"
        let stringWithExtension = "\(stringNoExtension).foo"
        #expect(stringNoExtension.appendingPathExtension("foo") == stringWithExtension)

        var invalidExtensions = [String]()
        for scalar in String.invalidExtensionScalars {
            invalidExtensions.append("\(scalar)foo")
            invalidExtensions.append("foo\(scalar)")
            invalidExtensions.append("f\(scalar)oo")
        }
        let invalidExtensionStrings = invalidExtensions.map { "\(stringNoExtension).\($0)" }

        #expect(stringNoExtension.pathExtension == "")
        #expect(stringWithExtension.pathExtension == "foo")
        #expect(stringNoExtension.deletingPathExtension() == stringNoExtension)
        #expect(stringWithExtension.deletingPathExtension() == stringNoExtension)

        for invalidExtensionString in invalidExtensionStrings {
            if invalidExtensionString.last == "/" {
                continue
            }
            #expect(invalidExtensionString.pathExtension == "")
            #expect(invalidExtensionString.deletingPathExtension() == invalidExtensionString)
        }

        for invalidExtension in invalidExtensions {
            #expect(stringNoExtension.appendingPathExtension(invalidExtension) == stringNoExtension)
        }
    }

    @Test func testAppendingPathExtension() {
        #expect("".appendingPathExtension("foo") == ".foo")
        #expect("/".appendingPathExtension("foo") == "/.foo")
        #expect("//".appendingPathExtension("foo") == "/.foo/")
        #expect("/path".appendingPathExtension("foo") == "/path.foo")
        #expect("/path.zip".appendingPathExtension("foo") == "/path.zip.foo")
        #expect("/path/".appendingPathExtension("foo") == "/path.foo/")
        #expect("/path//".appendingPathExtension("foo") == "/path.foo/")
        #expect("path".appendingPathExtension("foo") == "path.foo")
        #expect("path/".appendingPathExtension("foo") == "path.foo/")
        #expect("path//".appendingPathExtension("foo") == "path.foo/")
    }

    @Test func testDeletingPathExtenstion() {
        #expect("".deletingPathExtension() == "")
        #expect("/".deletingPathExtension() == "/")
        #expect("/foo/bar".deletingPathExtension() == "/foo/bar")
        #expect("/foo/bar.zip".deletingPathExtension() == "/foo/bar")
        #expect("/foo/bar.baz.zip".deletingPathExtension() == "/foo/bar.baz")
        #expect(".".deletingPathExtension() == ".")
        #expect(".zip".deletingPathExtension() == ".zip")
        #expect("zip.".deletingPathExtension() == "zip.")
        #expect(".zip.".deletingPathExtension() == ".zip.")
        #expect("/foo/bar/.zip".deletingPathExtension() == "/foo/bar/.zip")
        #expect("..".deletingPathExtension() == "..")
        #expect("..zip".deletingPathExtension() == "..zip")
        #expect("/foo/bar/..zip".deletingPathExtension() == "/foo/bar/..zip")
        #expect("/foo/bar/baz..zip".deletingPathExtension() == "/foo/bar/baz.")
        #expect("...".deletingPathExtension() == "...")
        #expect("...zip".deletingPathExtension() == "...zip")
        #expect("/foo/bar/...zip".deletingPathExtension() == "/foo/bar/...zip")
        #expect("/foo/bar/baz...zip".deletingPathExtension() == "/foo/bar/baz..")
        #expect("/foo.bar/bar.baz/baz.zip".deletingPathExtension() == "/foo.bar/bar.baz/baz")
        #expect("/.././.././a.zip".deletingPathExtension() == "/.././.././a")
        #expect("/.././.././.".deletingPathExtension() == "/.././.././.")

        #expect("path.foo".deletingPathExtension() == "path")
        #expect("path.foo.zip".deletingPathExtension() == "path.foo")
        #expect("/path.foo".deletingPathExtension() == "/path")
        #expect("/path.foo.zip".deletingPathExtension() == "/path.foo")
        #expect("path.foo/".deletingPathExtension() == "path/")
        #expect("path.foo//".deletingPathExtension() == "path/")
        #expect("/path.foo/".deletingPathExtension() == "/path/")
        #expect("/path.foo//".deletingPathExtension() == "/path/")
    }

    @Test func testPathComponents() {
        let tests: [(String, [String])] = [
            ("", []),
            ("/", ["/"]),
            ("//", ["/", "/"]),
            ("a", ["a"]),
            ("/a", ["/", "a"]),
            ("a/", ["a", "/"]),
            ("/a/", ["/", "a", "/"]),
            ("///", ["/", "/"]),
            ("//a", ["/", "a"]),
            ("a//", ["a", "/"]),
            ("//a//", ["/", "a", "/"]),
            ("a/b/c", ["a", "b", "c"]),
            ("/a/b/c", ["/", "a", "b", "c"]),
            ("a/b/c/", ["a", "b", "c", "/"]),
            ("/a/b/c/", ["/", "a", "b", "c", "/"]),
            ("/abc//def///ghi/jkl//123///456/7890//", ["/", "abc", "def", "ghi", "jkl", "123", "456", "7890", "/"]),
            ("/😎/😂/❤️/", ["/", "😎", "😂", "❤️", "/"]),
            ("J'aime//le//café//☕️", ["J'aime", "le", "café", "☕️"]),
            ("U+2215∕instead∕of∕slash(U+002F)", ["U+2215∕instead∕of∕slash(U+002F)"]),
        ]
        for (input, expected) in tests {
            let result = input.pathComponents
            #expect(result == expected)
        }
    }

    @Test func dataUsingEncoding() {
        let s = "hello 🧮"
        
        // Verify things work on substrings too
        let s2 = "x" + s + "x"
        let subString = s2[s2.index(after: s2.startIndex)..<s2.index(before: s2.endIndex)]
        
        // UTF16 - specific endianness
        
        let utf16BEExpected = Data([0, 104, 0, 101, 0, 108, 0, 108, 0, 111, 0, 32, 216, 62, 221, 238])
        let utf16BEOutput = s.data(using: String._Encoding.utf16BigEndian)
        #expect(utf16BEOutput == utf16BEExpected)
        
        let utf16BEOutputSubstring = subString.data(using: String._Encoding.utf16BigEndian)
        #expect(utf16BEOutputSubstring == utf16BEExpected)
        
        let utf16LEExpected = Data([104, 0, 101, 0, 108, 0, 108, 0, 111, 0, 32, 0, 62, 216, 238, 221])
        let utf16LEOutput = s.data(using: String._Encoding.utf16LittleEndian)
        #expect(utf16LEOutput == utf16LEExpected)

        let utf16LEOutputSubstring = subString.data(using: String._Encoding.utf16LittleEndian)
        #expect(utf16LEOutputSubstring == utf16LEExpected)

        // UTF32 - specific endianness
        
        let utf32BEExpected = Data([0, 0, 0, 104, 0, 0, 0, 101, 0, 0, 0, 108, 0, 0, 0, 108, 0, 0, 0, 111, 0, 0, 0, 32, 0, 1, 249, 238])
        let utf32BEOutput = s.data(using: String._Encoding.utf32BigEndian)
        #expect(utf32BEOutput == utf32BEExpected)

        let utf32LEExpected = Data([104, 0, 0, 0, 101, 0, 0, 0, 108, 0, 0, 0, 108, 0, 0, 0, 111, 0, 0, 0, 32, 0, 0, 0, 238, 249, 1, 0])
        let utf32LEOutput = s.data(using: String._Encoding.utf32LittleEndian)
        #expect(utf32LEOutput == utf32LEExpected)
        
        
        // UTF16 and 32, platform endianness
        let utf16LEWithBOM = Data([0xFF, 0xFE]) + utf16LEExpected
        let utf32LEWithBOM = Data([0xFF, 0xFE, 0x00, 0x00]) + utf32LEExpected
        let utf16BEWithBOM = Data([0xFE, 0xFF]) + utf16BEExpected
        let utf32BEWithBOM = Data([0x00, 0x00, 0xFE, 0xFF]) + utf32BEExpected

        let utf16Output = s.data(using: String._Encoding.utf16)!
        let utf32Output = s.data(using: String._Encoding.utf32)!
        
        let bom = 0xFFFE
        
        if bom.littleEndian == bom {
            // We are on a little endian system. Expect a LE BOM
            #expect(utf16Output == utf16LEWithBOM)
            #expect(utf32Output == utf32LEWithBOM)
        } else if bom.bigEndian == bom {
            // We are on a big endian system. Expect a BE BOM
            #expect(utf16Output == utf16BEWithBOM)
            #expect(utf32Output == utf32BEWithBOM)
        } else {
            fatalError("Unknown endianness")
        }
        
        // UTF16
        
        let utf16BEString = String(bytes: utf16BEExpected, encoding: String._Encoding.utf16BigEndian)
        #expect(s == utf16BEString)
        
        let utf16LEString = String(bytes: utf16LEExpected, encoding: String._Encoding.utf16LittleEndian)
        #expect(s == utf16LEString)
        
        let utf16LEBOMString = String(bytes: utf16LEWithBOM, encoding: String._Encoding.utf16)
        #expect(s == utf16LEBOMString)
        
        let utf16BEBOMString = String(bytes: utf16BEWithBOM, encoding: String._Encoding.utf16)
        #expect(s == utf16BEBOMString)
        
        // No BOM, no encoding specified. We assume the data is big endian, which leads to garbage (but not nil).
        let utf16LENoBOMString = String(bytes: utf16LEExpected, encoding: String._Encoding.utf16)
        #expect(utf16LENoBOMString != nil)

        // No BOM, no encoding specified. We assume the data is big endian, which leads to an expected value.
        let utf16BENoBOMString = String(bytes: utf16BEExpected, encoding: String._Encoding.utf16)
        #expect(s == utf16BENoBOMString)

        // UTF32
        
        let utf32BEString = String(bytes: utf32BEExpected, encoding: String._Encoding.utf32BigEndian)
        #expect(s == utf32BEString)
        
        let utf32LEString = String(bytes: utf32LEExpected, encoding: String._Encoding.utf32LittleEndian)
        #expect(s == utf32LEString)
        
        
        let utf32BEBOMString = String(bytes: utf32BEWithBOM, encoding: String._Encoding.utf32)
        #expect(s == utf32BEBOMString)
        
        let utf32LEBOMString = String(bytes: utf32LEWithBOM, encoding: String._Encoding.utf32)
        #expect(s == utf32LEBOMString)
        
        // No BOM, no encoding specified. We assume the data is big endian, which leads to a nil.
        let utf32LENoBOMString = String(bytes: utf32LEExpected, encoding: String._Encoding.utf32)
        #expect(utf32LENoBOMString == nil)
        
        // No BOM, no encoding specified. We assume the data is big endian, which leads to an expected value.
        let utf32BENoBOMString = String(bytes: utf32BEExpected, encoding: String._Encoding.utf32)
        #expect(s == utf32BENoBOMString)

        // Check what happens when we mismatch a string with a BOM and the encoding. The bytes are interpreted according to the specified encoding regardless of the BOM, the BOM is preserved, and the String will look garbled. However the bytes are preserved as-is. This is the expected behavior for UTF16.
        let utf16LEBOMStringMismatch = String(bytes: utf16LEWithBOM, encoding: String._Encoding.utf16BigEndian)
        let utf16LEBOMStringMismatchBytes = utf16LEBOMStringMismatch?.data(using: String._Encoding.utf16BigEndian)
        #expect(utf16LEWithBOM == utf16LEBOMStringMismatchBytes)
        
        let utf16BEBOMStringMismatch = String(bytes: utf16BEWithBOM, encoding: String._Encoding.utf16LittleEndian)
        let utf16BEBomStringMismatchBytes = utf16BEBOMStringMismatch?.data(using: String._Encoding.utf16LittleEndian)
        #expect(utf16BEWithBOM == utf16BEBomStringMismatchBytes)

        // For a UTF32 mismatch, the string creation simply returns nil.
        let utf32LEBOMStringMismatch = String(bytes: utf32LEWithBOM, encoding: String._Encoding.utf32BigEndian)
        #expect(utf32LEBOMStringMismatch == nil)
        
        let utf32BEBOMStringMismatch = String(bytes: utf32BEWithBOM, encoding: String._Encoding.utf32LittleEndian)
        #expect(utf32BEBOMStringMismatch == nil)
        
        // UTF-8 With BOM
        
        let utf8BOM = Data([0xEF, 0xBB, 0xBF])
        let helloWorld = Data("Hello, world".utf8)
        #expect(String(bytes: utf8BOM + helloWorld, encoding: String._Encoding.utf8) == "Hello, world")
        #expect(String(bytes: helloWorld + utf8BOM, encoding: String._Encoding.utf8) == "Hello, world\u{FEFF}")
    }

    @Test func dataUsingEncoding_preservingBOM() {
        func roundTrip(_ data: Data) -> Bool {
            let str = String(data: data, encoding: .utf8)!
            let strAsUTF16BE = str.data(using: String._Encoding.utf16BigEndian)!
            let strRoundTripUTF16BE = String(data: strAsUTF16BE, encoding: .utf16BigEndian)!
            return strRoundTripUTF16BE == str
        }
        
        // Verify that the BOM is preserved through a UTF8/16 transformation.

        // ASCII '2' followed by UTF8 BOM
        #expect(roundTrip(Data([ 0x32, 0xef, 0xbb, 0xbf ])))
        
        // UTF8 BOM followed by ASCII '4'
        #expect(roundTrip(Data([ 0xef, 0xbb, 0xbf, 0x34 ])))
    }
    
    @Test func dataUsingEncoding_ascii() {
        #expect("abc".data(using: .ascii) == Data([UInt8(ascii: "a"), UInt8(ascii: "b"), UInt8(ascii: "c")]))
        #expect("abc".data(using: .nonLossyASCII) == Data([UInt8(ascii: "a"), UInt8(ascii: "b"), UInt8(ascii: "c")]))
        #expect("e\u{301}\u{301}f".data(using: String._Encoding.ascii) == nil)
        #expect("e\u{301}\u{301}f".data(using: String._Encoding.nonLossyASCII) == nil)
        
        #expect("abc".data(using: .ascii, allowLossyConversion: true) == Data([UInt8(ascii: "a"), UInt8(ascii: "b"), UInt8(ascii: "c")]))
        #expect("abc".data(using: .nonLossyASCII, allowLossyConversion: true) == Data([UInt8(ascii: "a"), UInt8(ascii: "b"), UInt8(ascii: "c")]))
        #expect("e\u{301}\u{301}f".data(using: .ascii, allowLossyConversion: true) == Data([UInt8(ascii: "e"), 0xFF, 0xFF, UInt8(ascii: "f")]))
        #expect("e\u{301}\u{301}f".data(using: .nonLossyASCII, allowLossyConversion: true) == Data([UInt8(ascii: "e"), UInt8(ascii: "?"), UInt8(ascii: "?"), UInt8(ascii: "f")]))
    }
    
    @Test func initWithBytes_ascii() {
        #expect(String(bytes: "abc".utf8, encoding: String._Encoding.ascii) == "abc")
        #expect(String(bytes: "abc".utf8, encoding: String._Encoding.nonLossyASCII) == "abc")
        #expect(String(bytes: "e\u{301}\u{301}f".utf8, encoding: String._Encoding.ascii) == nil)
        #expect(String(bytes: "e\u{301}\u{301}f".utf8, encoding: String._Encoding.nonLossyASCII) == nil)
    }

    @Test func compressingSlashes() {
        let testCases: [(String, String)] = [
            ("", ""),                       // Empty string
            ("/", "/"),                     // Single slash
            ("/////", "/"),                 // All slashes
            ("ABCDE", "ABCDE"),             // No slashes
            ("//ABC", "/ABC"),              // Starts with multiple slashes
            ("/ABCD", "/ABCD"),             // Starts with single slash
            ("ABC//", "ABC/"),              // Ends with multiple slashes
            ("ABCD/", "ABCD/"),             // Ends with single slash
            ("//ABC//", "/ABC/"),           // Starts and ends with multiple slashes
            ("AB/CD", "AB/CD"),             // Single internal slash
            ("AB//DF/GH//I", "AB/DF/GH/I"), // Internal slashes
            ("//😎///😂/❤️//", "/😎/😂/❤️/")
        ]
        for (testString, expectedResult) in testCases {
            let result = testString
                ._compressingSlashes()
            #expect(result == expectedResult)
        }
    }

    @Test func pathHasDotDotComponent() {
        let testCases: [(String, Bool)] = [
            ("../AB", true),            // Begins with ..
            ("/ABC/..", true),          // Ends with ..
            ("/ABC/../DEF", true),      // Internal ..
            ("/ABC/DEF..", false),      // Ends with .. but not part of path
            ("ABC/../../DEF", true),    // Multiple internal dot dot
            ("/AB/./CD", false),        // Internal single dot
            ("/AB/..../CD", false),     // Internal multiple dots
            ("..", true),               // Dot dot only
            ("...", false),
            ("..AB", false),
            ("..AB/", false),
            ("..AB/..", true),
            (".AB/./.", false),
            ("/..AB/", false),
            ("A../", false),
            ("/..", true),
            ("././/./.", false)
        ]
        for (testString, expectedResult) in testCases {
            let result = testString
                ._hasDotDotComponent()
            #expect(result == expectedResult)
        }
    }

    @Test func init_contentsOfFile_encoding() throws {
        try withTemporaryStringFile { existingURL, nonExistentURL in
            let content = try String(contentsOfFile: existingURL.path, encoding: String._Encoding.ascii)
            #expect(temporaryFileContents == content)

            #expect(throws: (any Error).self) {
                _ = try String(contentsOfFile: nonExistentURL.path, encoding: String._Encoding.ascii)
            }
        }
    }

    @Test func init_contentsOfFile_usedEncoding() throws {
        try withTemporaryStringFile { existingURL, nonExistentURL in
            var usedEncoding: String._Encoding = String._Encoding(rawValue: 0)
            let content = try String(contentsOfFile: existingURL.path(), usedEncoding: &usedEncoding)
            #expect(0 != usedEncoding.rawValue)
            #expect(temporaryFileContents == content)
        }

    }


    @Test func init_contentsOf_encoding() throws {
        try withTemporaryStringFile { existingURL, nonExistentURL in
            let content = try String(contentsOf: existingURL, encoding: String._Encoding.ascii)
            #expect(temporaryFileContents == content)

            #expect(throws: (any Error).self) {
                _ = try String(contentsOf: nonExistentURL, encoding: String._Encoding.ascii)
            }
        }

    }

    @Test func init_contentsOf_usedEncoding() throws {
#if FOUNDATION_FRAMEWORK
        let encs : [String._Encoding] = [
            .ascii,
            .nextstep,
            .japaneseEUC,
            .utf8,
            .isoLatin1,
            .nonLossyASCII,
            .shiftJIS,
            .isoLatin2,
            .unicode,
            .windowsCP1251,
            .windowsCP1252,
            .windowsCP1253,
            .windowsCP1254,
            .windowsCP1250,
            .iso2022JP,
            .macOSRoman,
            .utf16,
            .utf16BigEndian,
            .utf16LittleEndian,
            .utf32,
            .utf32BigEndian,
            .utf32LittleEndian
        ]
#else
        var encs : [String._Encoding] = [
            .utf8,
            .utf16,
            .utf32,
        ]
        
        // A note about utf16/32 little/big endian
        // Foundation will only write out the BOM for encoded string data when using the unspecified encoding versions (.utf16, .utf32). It will, however, write the extended attribute if it can.
        // On non-Darwin platforms, where we have less guarantee that the extended attribute was succesfully written, we cannot actually promise that the round-trip below will work. If the xattr fails to write (which we do not report as an error, for both historical and practical reasons), and the BOM is not present, then we will just read the data back in as UTF8.
        // Therefore, we only test here the utf8/16/32 encodings.
        
        #if canImport(Darwin)
        // Only test non-UTF encodings on platforms where we successfully read/write the extended file attribute
        encs += [
            .ascii,
            .macOSRoman,
            .isoLatin1
        ]
        #endif
#endif
        
        for encoding in encs {
            try withTemporaryStringFile(encoding: encoding) { existingURL, _ in
                var usedEncoding = String._Encoding(rawValue: 0)
                let content = try String(contentsOf: existingURL, usedEncoding: &usedEncoding)
                
                #expect(encoding == usedEncoding)
                #expect(temporaryFileContents == content)
            }
        }
        
        // Test non-existent file
        try withTemporaryStringFile { _, nonExistentURL in
            var usedEncoding: String._Encoding = String._Encoding(rawValue: 0)
            #expect(throws: (any Error).self) {
                _ = try String(contentsOf: nonExistentURL, usedEncoding: &usedEncoding)
            }
            #expect(0 == usedEncoding.rawValue)
        }
    }
    
#if FOUNDATION_FRAMEWORK
    @Test func extendedAttributeEncodings() throws {
        // XAttr is supported on some platforms, but not all. For now we just test this code on Darwin.
        let encs : [String._Encoding] = [
            .ascii,
            .nextstep,
            .japaneseEUC,
            .utf8,
            .isoLatin1,
            .nonLossyASCII,
            .shiftJIS,
            .isoLatin2,
            .unicode,
            .windowsCP1251,
            .windowsCP1252,
            .windowsCP1253,
            .windowsCP1254,
            .windowsCP1250,
            .iso2022JP,
            .macOSRoman,
            .utf16,
            .utf16BigEndian,
            .utf16LittleEndian,
            .utf32,
            .utf32BigEndian,
            .utf32LittleEndian
        ]
        
        for encoding in encs {
            // Round trip the 
            let packageData = try #require(extendedAttributeData(for: encoding))
            
            let back = encodingFromDataForExtendedAttribute(packageData)
            #expect(back == encoding)
        }
        
        #expect(encodingFromDataForExtendedAttribute("us-ascii;1536".data(using: .utf8)!)!.rawValue == String._Encoding.ascii.rawValue)
        #expect(encodingFromDataForExtendedAttribute("x-nextstep;2817".data(using: .utf8)!)!.rawValue == String._Encoding.nextstep.rawValue)
        #expect(encodingFromDataForExtendedAttribute("euc-jp;2336".data(using: .utf8)!)!.rawValue == String._Encoding.japaneseEUC.rawValue)
        #expect(encodingFromDataForExtendedAttribute("utf-8;134217984".data(using: .utf8)!)!.rawValue == String._Encoding.utf8.rawValue)
        #expect(encodingFromDataForExtendedAttribute("iso-8859-1;513".data(using: .utf8)!)!.rawValue == String._Encoding.isoLatin1.rawValue)
        #expect(encodingFromDataForExtendedAttribute(";3071".data(using: .utf8)!)!.rawValue == String._Encoding.nonLossyASCII.rawValue)
        #expect(encodingFromDataForExtendedAttribute("cp932;1056".data(using: .utf8)!)!.rawValue == String._Encoding.shiftJIS.rawValue)
        #expect(encodingFromDataForExtendedAttribute("iso-8859-2;514".data(using: .utf8)!)!.rawValue == String._Encoding.isoLatin2.rawValue)
        #expect(encodingFromDataForExtendedAttribute("utf-16;256".data(using: .utf8)!)!.rawValue == String._Encoding.unicode.rawValue)
        #expect(encodingFromDataForExtendedAttribute("windows-1251;1282".data(using: .utf8)!)!.rawValue == String._Encoding.windowsCP1251.rawValue)
        #expect(encodingFromDataForExtendedAttribute("windows-1252;1280".data(using: .utf8)!)!.rawValue == String._Encoding.windowsCP1252.rawValue)
        #expect(encodingFromDataForExtendedAttribute("windows-1253;1283".data(using: .utf8)!)!.rawValue == String._Encoding.windowsCP1253.rawValue)
        #expect(encodingFromDataForExtendedAttribute("windows-1254;1284".data(using: .utf8)!)!.rawValue == String._Encoding.windowsCP1254.rawValue)
        #expect(encodingFromDataForExtendedAttribute("windows-1250;1281".data(using: .utf8)!)!.rawValue == String._Encoding.windowsCP1250.rawValue)
        #expect(encodingFromDataForExtendedAttribute("iso-2022-jp;2080".data(using: .utf8)!)!.rawValue == String._Encoding.iso2022JP.rawValue)
        #expect(encodingFromDataForExtendedAttribute("macintosh;0".data(using: .utf8)!)!.rawValue == String._Encoding.macOSRoman.rawValue)
        #expect(encodingFromDataForExtendedAttribute("utf-16;256".data(using: .utf8)!)!.rawValue == String._Encoding.utf16.rawValue)
        #expect(encodingFromDataForExtendedAttribute("utf-16be;268435712".data(using: .utf8)!)!.rawValue == String._Encoding.utf16BigEndian.rawValue)
        #expect(encodingFromDataForExtendedAttribute("utf-16le;335544576".data(using: .utf8)!)!.rawValue == String._Encoding.utf16LittleEndian.rawValue)
        #expect(encodingFromDataForExtendedAttribute("utf-32;201326848".data(using: .utf8)!)!.rawValue == String._Encoding.utf32.rawValue)
        #expect(encodingFromDataForExtendedAttribute("utf-32be;402653440".data(using: .utf8)!)!.rawValue == String._Encoding.utf32BigEndian.rawValue)
        #expect(encodingFromDataForExtendedAttribute("utf-32le;469762304".data(using: .utf8)!)!.rawValue == String._Encoding.utf32LittleEndian.rawValue)
    }
#endif

    @Test func write_toFile() throws {
        try withTemporaryStringFile { existingURL, nonExistentURL in
            let nonExistentPath = nonExistentURL.path()
            let s = "Lorem ipsum dolor sit amet, consectetur adipisicing elit"
            try s.write(toFile: nonExistentPath, atomically: false, encoding: String._Encoding.ascii)

            let content = try String(contentsOfFile: nonExistentPath, encoding: String._Encoding.ascii)

            #expect(s == content)
        }

    }

    @Test func write_to() throws {
        try withTemporaryStringFile { existingURL, nonExistentURL in
            let nonExistentPath = nonExistentURL.path()
            let s = "Lorem ipsum dolor sit amet, consectetur adipisicing elit"
            try s.write(to: nonExistentURL, atomically: false, encoding: String._Encoding.ascii)
            
            let content = try String(contentsOfFile: nonExistentPath, encoding: String._Encoding.ascii)
            
            #expect(s == content)
        }

    }
    
    func verifyEncoding(_ encoding: String._Encoding, valid: [String], invalid: [String], sourceLocation: SourceLocation = #_sourceLocation) throws {
        for string in valid {
            let data = try #require(string.data(using: encoding), "Failed to encode \(string.debugDescription)", sourceLocation: sourceLocation)
            #expect(String(data: data, encoding: encoding) != nil, "Failed to decode \(data) (\(string.debugDescription))", sourceLocation: sourceLocation)
        }
        for string in invalid {
            #expect(string.data(using: String._Encoding.macOSRoman) == nil, "Incorrectly successfully encoded \(string.debugDescription)", sourceLocation: sourceLocation)
        }
    }
    
    @Test func testISOLatin1Encoding() throws {
        try verifyEncoding(.isoLatin1, valid: [
            "abcdefghijklmnopqrstuvwxyz",
            "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
            "0123456789",
            "!\"#$%&'()*+,-./",
            "¡¶ÅÖæöÿ\u{0080}\u{00A0}~",
            "Hello\nworld",
            "Hello\r\nworld"
        ], invalid: [
            "🎺",
            "מ",
            "✁",
            "abcd🎺efgh"
        ])
    }
    
    @Test func testMacRomanEncoding() throws {
        try verifyEncoding(.macOSRoman, valid: [
            "abcdefghijklmnopqrstuvwxyz",
            "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
            "0123456789",
            "!\"#$%&'()*+,-./",
            "ÄÇçÑû¶≠∏\u{00A0}÷Êˇ"
        ], invalid: [
            "🎺",
            "מ",
            "✁",
            "abcd🎺efgh"
        ])
    }
}

// MARK: - Helper functions

let temporaryFileContents = "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."

func withTemporaryStringFile(encoding: String._Encoding = .utf8, _ block: (_ existingURL: URL, _ nonExistentURL: URL) throws -> ()) throws {

    let rootURL = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fileURL = rootURL.appending(path: "NSStringTest.txt", directoryHint: .notDirectory)
    try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

    try temporaryFileContents.write(to: fileURL, atomically: true, encoding: encoding)
    
    let nonExisting = rootURL.appending(path: "-NonExist", directoryHint: .notDirectory)
    try block(fileURL, nonExisting)
    try FileManager.default.removeItem(at: rootURL)
}

// MARK: -

#if FOUNDATION_FRAMEWORK

struct StringTestsStdlib {

    // The most simple subclass of NSString that CoreFoundation does not know
    // about.
    class NonContiguousNSString : NSString {
        required init(coder aDecoder: NSCoder) {
            fatalError("don't call this initializer")
        }
        required init(itemProviderData data: Data, typeIdentifier: String) throws {
            fatalError("don't call this initializer")
        }

        override init() {
            _value = []
            super.init()
        }

        init(_ value: [UInt16]) {
            _value = value
            super.init()
        }

#if os(macOS) // for AppKit
        required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
            fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
        }
#endif

        @objc(copyWithZone:) override func copy(with zone: NSZone?) -> Any {
            // Ensure that copying this string produces a class that CoreFoundation
            // does not know about.
            return self
        }

        @objc override var length: Int {
            return _value.count
        }

        @objc override func character(at index: Int) -> unichar {
            return _value[index]
        }

        var _value: [UInt16]
    }

    @Test func Encodings() {
        let availableEncodings: [String.Encoding] = String.availableStringEncodings
        #expect(0 != availableEncodings.count)

        let defaultCStringEncoding = String.defaultCStringEncoding
        #expect(availableEncodings.contains(defaultCStringEncoding))

        #expect("" != String.localizedName(of: .utf8))
    }

    @Test func NSStringEncoding() {
        // Make sure NSStringEncoding and its values are type-compatible.
        var enc: String.Encoding
        enc = .windowsCP1250
        enc = .utf32LittleEndian
        enc = .utf32BigEndian
        enc = .ascii
        enc = .utf8
        #expect(.utf8 == enc)
    }

    @Test func NSStringEncoding_Hashable() {
        let instances: [String.Encoding] = [
            .windowsCP1250,
            .utf32LittleEndian,
            .utf32BigEndian,
            .ascii,
            .utf8,
        ]
        checkHashable(instances, equalityOracle: { $0 == $1 })
    }

    @Test func localizedStringWithFormat() {
        let world: NSString = "world"
        #expect("Hello, world!%42" == String.localizedStringWithFormat(
            "Hello, %@!%%%ld", world, 42))

        #expect("0.5" == String.init(format: "%g", locale: Locale(identifier: "en_US"), 0.5))
        #expect("0,5" == String.init(format: "%g", locale: Locale(identifier: "uk"), 0.5))
    }

    @Test func init_cString_encoding() {
        "foo, a basmati bar!".withCString {
            #expect("foo, a basmati bar!" ==
                        String(cString: $0, encoding: String.defaultCStringEncoding))
        }
    }

    @Test func init_utf8String() {
        let s = "foo あいう"
        let up = UnsafeMutablePointer<UInt8>.allocate(capacity: 100)
        var i = 0
        for b in s.utf8 {
            up[i] = b
            i += 1
        }
        up[i] = 0
        let cstr = UnsafeMutableRawPointer(up)
            .bindMemory(to: CChar.self, capacity: 100)
        #expect(s == String(utf8String: cstr))
        up.deallocate()
    }

    @Test func canBeConvertedToEncoding() {
        #expect("foo".canBeConverted(to: .ascii))
        #expect(!"あいう".canBeConverted(to: .ascii))
    }

    @Test func capitalized() {
        #expect("Foo Foo Foo Foo" == "foo Foo fOO FOO".capitalized)
        #expect("Жжж" == "жжж".capitalized)
    }

    @Test func localizedCapitalized() {
        #expect(
            "Foo Foo Foo Foo" ==
            "foo Foo fOO FOO".capitalized(with: Locale(identifier: "en")))
        #expect("Жжж" == "жжж".capitalized(with: Locale(identifier: "en")))

        //
        // Special casing.
        //

        // U+0069 LATIN SMALL LETTER I
        // to upper case:
        // U+0049 LATIN CAPITAL LETTER I
        #expect("Iii Iii" == "iii III".capitalized(with: Locale(identifier: "en")))

        // U+0069 LATIN SMALL LETTER I
        // to upper case in Turkish locale:
        // U+0130 LATIN CAPITAL LETTER I WITH DOT ABOVE
        #expect("\u{0130}ii Iıı" == "iii III".capitalized(with: Locale(identifier: "tr")))
    }

    /// Checks that executing the operation in the locale with the given
    /// `localeID` (or unlocalized if `localeID` is `nil`) gives
    /// the expected result, and that executing the operation with a nil
    /// locale gives the same result as explicitly passing the system
    /// locale.
    ///
    /// - Parameter expected: the expected result when the operation is
    ///   executed in the given localeID
    func expectLocalizedEquality(
        _ expected: String,
        _ op: (_: Locale?) -> String,
        _ localeID: String? = nil,
        _ message: @autoclosure () -> Comment? = nil,
        showFrame: Bool = true,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {

        let locale = localeID.map {
            Locale(identifier: $0)
        } ?? nil

        #expect(expected == op(locale), message(), sourceLocation: sourceLocation)
    }

    @Test func capitalizedString() {
        expectLocalizedEquality(
            "Foo Foo Foo Foo",
            { loc in "foo Foo fOO FOO".capitalized(with: loc) })

        expectLocalizedEquality("Жжж", { loc in "жжж".capitalized(with: loc) })

        #expect(
            "Foo Foo Foo Foo" ==
            "foo Foo fOO FOO".capitalized(with: nil))
        #expect("Жжж" == "жжж".capitalized(with: nil))

        //
        // Special casing.
        //

        // U+0069 LATIN SMALL LETTER I
        // to upper case:
        // U+0049 LATIN CAPITAL LETTER I
        expectLocalizedEquality(
            "Iii Iii",
            { loc in "iii III".capitalized(with: loc) }, "en")

        // U+0069 LATIN SMALL LETTER I
        // to upper case in Turkish locale:
        // U+0130 LATIN CAPITAL LETTER I WITH DOT ABOVE
        expectLocalizedEquality(
            "İii Iıı",
            { loc in "iii III".capitalized(with: loc) }, "tr")
    }

    @Test func caseInsensitiveCompare() {
        #expect(ComparisonResult.orderedSame ==
                    "abCD".caseInsensitiveCompare("AbCd"))
        #expect(ComparisonResult.orderedAscending ==
                    "abCD".caseInsensitiveCompare("AbCdE"))

        #expect(ComparisonResult.orderedSame ==
                    "абвг".caseInsensitiveCompare("АбВг"))
        #expect(ComparisonResult.orderedAscending ==
                    "абВГ".caseInsensitiveCompare("АбВгД"))
    }

    @Test func commonPrefix() {
        #expect("ab" ==
                    "abcd".commonPrefix(with: "abdc", options: []))
        #expect("abC" ==
                    "abCd".commonPrefix(with: "abce", options: .caseInsensitive))

        #expect("аб" ==
                    "абвг".commonPrefix(with: "абгв", options: []))
        #expect("абВ" ==
                    "абВг".commonPrefix(with: "абвд", options: .caseInsensitive))
    }

    @Test func compare() {
        #expect(ComparisonResult.orderedSame ==
                    "abc".compare("abc"))
        #expect(ComparisonResult.orderedAscending ==
                    "абв".compare("где"))

        #expect(ComparisonResult.orderedSame ==
                    "abc".compare("abC", options: .caseInsensitive))
        #expect(ComparisonResult.orderedSame ==
                    "абв".compare("абВ", options: .caseInsensitive))

        do {
            let s = "abcd"
            let r = s.index(after: s.startIndex)..<s.endIndex
            #expect(ComparisonResult.orderedSame ==
                        s.compare("bcd", range: r))
        }
        do {
            let s = "абвг"
            let r = s.index(after: s.startIndex)..<s.endIndex
            #expect(ComparisonResult.orderedSame ==
                        s.compare("бвг", range: r))
        }

        #expect(ComparisonResult.orderedSame ==
                    "abc".compare("abc", locale: nil))
        #expect(ComparisonResult.orderedSame ==
                    "абв".compare("абв", locale: nil))
    }

    @Test func completePath() throws {
        try withTemporaryStringFile { existingURL, nonExistentURL in
            let existingPath = existingURL.path()
            let nonExistentPath = nonExistentURL.path()
            do {
                let count = nonExistentPath.completePath(caseSensitive: false)
                #expect(0 == count)
            }

            do {
                var outputName = "None Found"
                let count = nonExistentPath.completePath(
                    into: &outputName, caseSensitive: false)

                #expect(0 == count)
                #expect("None Found" == outputName)
            }

            do {
                var outputName = "None Found"
                var outputArray: [String] = ["foo", "bar"]
                let count = nonExistentPath.completePath(
                    into: &outputName, caseSensitive: false, matchesInto: &outputArray)

                #expect(0 == count)
                #expect("None Found" == outputName)
                #expect(["foo", "bar"] == outputArray)
            }

            do {
                let count = existingPath.completePath(caseSensitive: false)
                #expect(1 == count)
            }

            do {
                var outputName = "None Found"
                let count = existingPath.completePath(
                    into: &outputName, caseSensitive: false)

                #expect(1 == count)
                #expect(existingPath == outputName)
            }

            do {
                var outputName = "None Found"
                var outputArray: [String] = ["foo", "bar"]
                let count = existingPath.completePath(
                    into: &outputName, caseSensitive: false, matchesInto: &outputArray)

                #expect(1 == count)
                #expect(existingPath == outputName)
                #expect([existingPath] == outputArray)
            }

            do {
                var outputName = "None Found"
                let count = existingPath.completePath(
                    into: &outputName, caseSensitive: false, filterTypes: ["txt"])

                #expect(1 == count)
                #expect(existingPath == outputName)
            }
        }

    }

    @Test func components_separatedBy_characterSet() {
        #expect([""] == "".components(
            separatedBy: CharacterSet.decimalDigits))

        #expect(
            ["абв", "", "あいう", "abc"] ==
            "абв12あいう3abc".components(
                separatedBy: CharacterSet.decimalDigits))

        #expect(
            ["абв", "", "あいう", "abc"] ==
            "абв\u{1F601}\u{1F602}あいう\u{1F603}abc"
                .components(
                    separatedBy: CharacterSet(charactersIn: "\u{1F601}\u{1F602}\u{1F603}")))

        // Performs Unicode scalar comparison.
        #expect(
            ["abcし\u{3099}def"] ==
            "abcし\u{3099}def".components(
                separatedBy: CharacterSet(charactersIn: "\u{3058}")))
    }

    @Test func components_separatedBy_string() {
        #expect([""] == "".components(separatedBy: "//"))

        #expect(
            ["абв", "あいう", "abc"] ==
            "абв//あいう//abc".components(separatedBy: "//"))

        // Performs normalization.
        #expect(
            ["abc", "def"] ==
            "abcし\u{3099}def".components(separatedBy: "\u{3058}"))
    }

    @Test func cString() {
        #expect("абв".cString(using: .ascii) == nil)

        let expectedBytes: [UInt8] = [ 0xd0, 0xb0, 0xd0, 0xb1, 0xd0, 0xb2, 0 ]
        let expectedStr: [CChar] = expectedBytes.map { CChar(bitPattern: $0) }
        #expect(expectedStr ==
                    "абв".cString(using: .utf8)!)
    }

     @Test func data() throws {
         #expect("あいう".data(using: .ascii, allowLossyConversion: false) == nil)

         do {
             let data = try #require("あいう".data(using: .utf8))
             let expectedBytes = Data([
                0xe3, 0x81, 0x82, 0xe3, 0x81, 0x84, 0xe3, 0x81, 0x86
             ])

             #expect(expectedBytes == data)
         }
     }

    @Test func initWithData() {
        let bytes: [UInt8] = [0xe3, 0x81, 0x82, 0xe3, 0x81, 0x84, 0xe3, 0x81, 0x86]
        let data = Data(bytes)

        #expect(String(data: data, encoding: .nonLossyASCII) == nil)

        #expect("あいう" == String(data: data, encoding: .utf8)!)
    }

    @Test func decomposedStringWithCanonicalMapping() {
        #expect("abc" == "abc".decomposedStringWithCanonicalMapping)
        #expect("\u{305f}\u{3099}くてん" == "だくてん".decomposedStringWithCanonicalMapping)
        #expect("\u{ff80}\u{ff9e}ｸﾃﾝ" == "ﾀﾞｸﾃﾝ".decomposedStringWithCanonicalMapping)
    }

    @Test func decomposedStringWithCompatibilityMapping() {
        #expect("abc" == "abc".decomposedStringWithCompatibilityMapping)
        #expect("\u{30bf}\u{3099}クテン" == "ﾀﾞｸﾃﾝ".decomposedStringWithCompatibilityMapping)
    }

    @Test func enumerateLines() {
        var lines: [String] = []
        "abc\n\ndefghi\njklm".enumerateLines {
            (line: String, stop: inout Bool)
            in
            lines.append(line)
            if lines.count == 3 {
                stop = true
            }
        }
        #expect(["abc", "", "defghi"] == lines)
    }

    @Test func enumerateLinguisticTagsIn() {
        let s: String = "Абв. Глокая куздра штеко будланула бокра и кудрячит бокрёнка. Абв."
        let startIndex = s.index(s.startIndex, offsetBy: 5)
        let endIndex = s.index(s.startIndex, offsetBy: 62)
        var tags: [String] = []
        var tokens: [String] = []
        var sentences: [String] = []
        let range = startIndex..<endIndex
        let scheme: NSLinguisticTagScheme = .tokenType
        s.enumerateLinguisticTags(in: range,
                                  scheme: scheme.rawValue,
                                  options: [],
                                  orthography: nil) {
            (tag: String, tokenRange: Range<String.Index>, sentenceRange: Range<String.Index>, stop: inout Bool)
            in
            tags.append(tag)
            tokens.append(String(s[tokenRange]))
            sentences.append(String(s[sentenceRange]))
            if tags.count == 3 {
                stop = true
            }
        }
        #expect([
            NSLinguisticTag.word.rawValue,
            NSLinguisticTag.whitespace.rawValue,
            NSLinguisticTag.word.rawValue
        ] == tags)
        #expect(["Глокая", " ", "куздра"] == tokens)
        let sentence = String(s[startIndex..<endIndex])
        #expect([sentence, sentence, sentence] == sentences)
    }

    @Test func enumerateSubstringsIn() {
        let s = "え\u{304b}\u{3099}お\u{263a}\u{fe0f}😀😊"
        let startIndex = s.index(s.startIndex, offsetBy: 1)
        let endIndex = s.index(s.startIndex, offsetBy: 5)
        do {
            var substrings: [String] = []
            // FIXME(strings): this API should probably change to accept a Substring?
            // instead of a String? and a range.
            s.enumerateSubstrings(in: startIndex..<endIndex,
                                  options: String.EnumerationOptions.byComposedCharacterSequences) {
                (substring: String?, substringRange: Range<String.Index>,
                 enclosingRange: Range<String.Index>, stop: inout Bool)
                in
                substrings.append(substring!)
                #expect(substring == String(s[substringRange]))
                #expect(substring == String(s[enclosingRange]))
            }
            #expect(["\u{304b}\u{3099}", "お", "☺️", "😀"] == substrings)
        }
        do {
            var substrings: [String] = []
            s.enumerateSubstrings(in: startIndex..<endIndex,
                                  options: [.byComposedCharacterSequences, .substringNotRequired]) {
                (substring_: String?, substringRange: Range<String.Index>,
                 enclosingRange: Range<String.Index>, stop: inout Bool)
                in
                #expect(substring_ == nil)
                let substring = s[substringRange]
                substrings.append(String(substring))
                #expect(substring == s[enclosingRange])
            }
            #expect(["\u{304b}\u{3099}", "お", "☺️", "😀"] == substrings)
        }
    }

    @Test func fastestEncoding() {
        let availableEncodings: [String.Encoding] = String.availableStringEncodings
        #expect(availableEncodings.contains("abc".fastestEncoding))
    }

    @Test func getBytes() {
        let s = "abc абв def где gh жз zzz"
        let startIndex = s.index(s.startIndex, offsetBy: 8)
        let endIndex = s.index(s.startIndex, offsetBy: 22)
        do {
            // 'maxLength' is limiting.
            let bufferLength = 100
            var expectedStr: [UInt8] = Array("def где ".utf8)
            while (expectedStr.count != bufferLength) {
                expectedStr.append(0xff)
            }
            var buffer = [UInt8](repeating: 0xff, count: bufferLength)
            var usedLength = 0
            var remainingRange = startIndex..<endIndex
            let result = s.getBytes(&buffer, maxLength: 11, usedLength: &usedLength,
                                    encoding: .utf8,
                                    options: [],
                                    range: startIndex..<endIndex, remaining: &remainingRange)
            #expect(result)
            #expect(expectedStr == buffer)
            #expect(11 == usedLength)
            #expect(remainingRange.lowerBound == s.index(startIndex, offsetBy: 8))
            #expect(remainingRange.upperBound == endIndex)
        }
        do {
            // 'bufferLength' is limiting.  Note that the buffer is not filled
            // completely, since doing that would break a UTF sequence.
            let bufferLength = 5
            var expectedStr: [UInt8] = Array("def ".utf8)
            while (expectedStr.count != bufferLength) {
                expectedStr.append(0xff)
            }
            var buffer = [UInt8](repeating: 0xff, count: bufferLength)
            var usedLength = 0
            var remainingRange = startIndex..<endIndex
            let result = s.getBytes(&buffer, maxLength: 11, usedLength: &usedLength,
                                    encoding: .utf8,
                                    options: [],
                                    range: startIndex..<endIndex, remaining: &remainingRange)
            #expect(result)
            #expect(expectedStr == buffer)
            #expect(4 == usedLength)
            #expect(remainingRange.lowerBound == s.index(startIndex, offsetBy: 4))
            #expect(remainingRange.upperBound == endIndex)
        }
        do {
            // 'range' is converted completely.
            let bufferLength = 100
            var expectedStr: [UInt8] = Array("def где gh жз ".utf8)
            while (expectedStr.count != bufferLength) {
                expectedStr.append(0xff)
            }
            var buffer = [UInt8](repeating: 0xff, count: bufferLength)
            var usedLength = 0
            var remainingRange = startIndex..<endIndex
            let result = s.getBytes(&buffer, maxLength: bufferLength,
                                    usedLength: &usedLength, encoding: .utf8,
                                    options: [],
                                    range: startIndex..<endIndex, remaining: &remainingRange)
            #expect(result)
            #expect(expectedStr == buffer)
            #expect(19 == usedLength)
            #expect(remainingRange.lowerBound == endIndex)
            #expect(remainingRange.upperBound == endIndex)
        }
        do {
            // Inappropriate encoding.
            let bufferLength = 100
            var expectedStr: [UInt8] = Array("def ".utf8)
            while (expectedStr.count != bufferLength) {
                expectedStr.append(0xff)
            }
            var buffer = [UInt8](repeating: 0xff, count: bufferLength)
            var usedLength = 0
            var remainingRange = startIndex..<endIndex
            let result = s.getBytes(&buffer, maxLength: bufferLength,
                                    usedLength: &usedLength, encoding: .ascii,
                                    options: [],
                                    range: startIndex..<endIndex, remaining: &remainingRange)
            #expect(result)
            #expect(expectedStr == buffer)
            #expect(4 == usedLength)
            #expect(remainingRange.lowerBound == s.index(startIndex, offsetBy: 4))
            #expect(remainingRange.upperBound == endIndex)
        }
    }

    @Test func getCString() {
        let s = "abc あかさた"
        do {
            // A significantly too small buffer
            let bufferLength = 1
            var buffer = Array(
                repeating: CChar(bitPattern: 0xff), count: bufferLength)
            let result = s.getCString(&buffer, maxLength: 100,
                                      encoding: .utf8)
            #expect(!result)
            let result2 = s.getCString(&buffer, maxLength: 1,
                                       encoding: .utf8)
            #expect(!result2)
        }
        do {
            // The largest buffer that cannot accommodate the string plus null terminator.
            let bufferLength = 16
            var buffer = Array(
                repeating: CChar(bitPattern: 0xff), count: bufferLength)
            let result = s.getCString(&buffer, maxLength: 100,
                                      encoding: .utf8)
            #expect(!result)
            let result2 = s.getCString(&buffer, maxLength: 16,
                                       encoding: .utf8)
            #expect(!result2)
        }
        do {
            // The smallest buffer where the result can fit.
            let bufferLength = 17
            var expectedStr = "abc あかさた\0".utf8.map { CChar(bitPattern: $0) }
            while (expectedStr.count != bufferLength) {
                expectedStr.append(CChar(bitPattern: 0xff))
            }
            var buffer = Array(
                repeating: CChar(bitPattern: 0xff), count: bufferLength)
            let result = s.getCString(&buffer, maxLength: 100,
                                      encoding: .utf8)
            #expect(result)
            #expect(expectedStr == buffer)
            let result2 = s.getCString(&buffer, maxLength: 17,
                                       encoding: .utf8)
            #expect(result2)
            #expect(expectedStr == buffer)
        }
        do {
            // Limit buffer size with 'maxLength'.
            let bufferLength = 100
            var buffer = Array(
                repeating: CChar(bitPattern: 0xff), count: bufferLength)
            let result = s.getCString(&buffer, maxLength: 8,
                                      encoding: .utf8)
            #expect(!result)
        }
        do {
            // String with unpaired surrogates.
            let illFormedUTF16 = NonContiguousNSString([ 0xd800 ]) as String
            let bufferLength = 100
            var buffer = Array(
                repeating: CChar(bitPattern: 0xff), count: bufferLength)
            let result = illFormedUTF16.getCString(&buffer, maxLength: 100,
                                                   encoding: .utf8)
            #expect(!result)
        }
    }

    @Test func getLineStart() {
        let s = "Глокая куздра\nштеко будланула\nбокра и кудрячит\nбокрёнка."
        let r = s.index(s.startIndex, offsetBy: 16)..<s.index(s.startIndex, offsetBy: 35)
        do {
            var outStartIndex = s.startIndex
            var outLineEndIndex = s.startIndex
            var outContentsEndIndex = s.startIndex
            s.getLineStart(&outStartIndex, end: &outLineEndIndex,
                           contentsEnd: &outContentsEndIndex, for: r)
            #expect("штеко будланула\nбокра и кудрячит\n" ==
                        s[outStartIndex..<outLineEndIndex])
            #expect("штеко будланула\nбокра и кудрячит" ==
                        s[outStartIndex..<outContentsEndIndex])
        }
    }

    @Test func getParagraphStart() {
        let s = "Глокая куздра\nштеко будланула\u{2028}бокра и кудрячит\u{2028}бокрёнка.\n Абв."
        let r = s.index(s.startIndex, offsetBy: 16)..<s.index(s.startIndex, offsetBy: 35)
        do {
            var outStartIndex = s.startIndex
            var outEndIndex = s.startIndex
            var outContentsEndIndex = s.startIndex
            s.getParagraphStart(&outStartIndex, end: &outEndIndex,
                                contentsEnd: &outContentsEndIndex, for: r)
            #expect("штеко будланула\u{2028}бокра и кудрячит\u{2028}бокрёнка.\n" ==
                        s[outStartIndex..<outEndIndex])
            #expect("штеко будланула\u{2028}бокра и кудрячит\u{2028}бокрёнка." ==
                        s[outStartIndex..<outContentsEndIndex])
        }
    }

    @Test func hash() {
        let s: String = "abc"
        let nsstr: NSString = "abc"
        #expect(nsstr.hash == s.hash)
    }

    @Test func init_bytes_encoding() {
        let s = "abc あかさた"
        #expect(s == String(bytes: s.utf8, encoding: .utf8))

        /*
         FIXME: Test disabled because the NSString documentation is unclear about
         what should actually happen in this case.

         XCTAssertNil(String(bytes: bytes, length: bytes.count,
         encoding: .ascii))
         */

        // FIXME: add a test where this function actually returns nil.
    }

    @available(*, deprecated)
    @Test func init_bytesNoCopy_length_encoding_freeWhenDone() {
        let s = "abc あかさた"
        var bytes: [UInt8] = Array(s.utf8)
        #expect(s == String(bytesNoCopy: &bytes,
                              length: bytes.count, encoding: .utf8,
                              freeWhenDone: false))

        /*
         FIXME: Test disabled because the NSString documentation is unclear about
         what should actually happen in this case.

         XCTAssertNil(String(bytesNoCopy: &bytes, length: bytes.count,
         encoding: .ascii, freeWhenDone: false))
         */

        // FIXME: add a test where this function actually returns nil.
    }

    @Test func init_utf16CodeUnits_count() {
        let expected = "abc абв \u{0001F60A}"
        let chars: [unichar] = Array(expected.utf16)

        #expect(expected == String(utf16CodeUnits: chars, count: chars.count))
    }

    @available(*, deprecated)
    @Test func init_utf16CodeUnitsNoCopy() {
        let expected = "abc абв \u{0001F60A}"
        let chars: [unichar] = Array(expected.utf16)

        #expect(expected == String(utf16CodeUnitsNoCopy: chars,
                                     count: chars.count, freeWhenDone: false))
    }

    @Test func init_format() {
        #expect("" == String(format: ""))
        #expect(
            "abc абв \u{0001F60A}" == String(format: "abc абв \u{0001F60A}"))

        let world: NSString = "world"
        #expect("Hello, world!%42" ==
                    String(format: "Hello, %@!%%%ld", world, 42))

        // test for rdar://problem/18317906
        #expect("3.12" == String(format: "%.2f", 3.123456789))
        #expect("3.12" == NSString(format: "%.2f", 3.123456789))
    }

    @Test func init_format_arguments() {
        #expect("" == String(format: "", arguments: []))
        #expect(
            "abc абв \u{0001F60A}" ==
            String(format: "abc абв \u{0001F60A}", arguments: []))

        let world: NSString = "world"
        let args: [CVarArg] = [ world, 42 ]
        #expect("Hello, world!%42" ==
                    String(format: "Hello, %@!%%%ld", arguments: args))
    }

    @Test func init_format_locale() {
        let world: NSString = "world"
        #expect("Hello, world!%42" == String(format: "Hello, %@!%%%ld",
                                               locale: nil, world, 42))
    }

    @Test func init_format_locale_arguments() {
        let world: NSString = "world"
        let args: [CVarArg] = [ world, 42 ]
        #expect("Hello, world!%42" == String(format: "Hello, %@!%%%ld",
                                               locale: nil, arguments: args))
    }

    @Test func utf16Count() {
        #expect(1 == "a".utf16.count)
        #expect(2 == "\u{0001F60A}".utf16.count)
    }

    @Test func lengthOfBytesUsingEncoding() {
        #expect(1 == "a".lengthOfBytes(using: .utf8))
        #expect(2 == "あ".lengthOfBytes(using: .shiftJIS))
    }

    @Test func lineRangeFor() {
        let s = "Глокая куздра\nштеко будланула\nбокра и кудрячит\nбокрёнка."
        let r = s.index(s.startIndex, offsetBy: 16)..<s.index(s.startIndex, offsetBy: 35)
        do {
            let result = s.lineRange(for: r)
            #expect("штеко будланула\nбокра и кудрячит\n" == s[result])
        }
    }

    @Test func linguisticTagsIn() {
        let s: String = "Абв. Глокая куздра штеко будланула бокра и кудрячит бокрёнка. Абв."
        let startIndex = s.index(s.startIndex, offsetBy: 5)
        let endIndex = s.index(s.startIndex, offsetBy: 17)
        var tokenRanges: [Range<String.Index>] = []
        let scheme = NSLinguisticTagScheme.tokenType
        let tags = s.linguisticTags(in: startIndex..<endIndex,
                                    scheme: scheme.rawValue,
                                    options: [],
                                    orthography: nil, tokenRanges: &tokenRanges)
        #expect([
            NSLinguisticTag.word.rawValue,
            NSLinguisticTag.whitespace.rawValue,
            NSLinguisticTag.word.rawValue
        ] == tags)
        #expect(["Глокая", " ", "куздра"] ==
                    tokenRanges.map { String(s[$0]) } )
    }

    @Test func localizedCaseInsensitiveCompare() {
        #expect(ComparisonResult.orderedSame ==
                    "abCD".localizedCaseInsensitiveCompare("AbCd"))
        #expect(ComparisonResult.orderedAscending ==
                    "abCD".localizedCaseInsensitiveCompare("AbCdE"))

        #expect(ComparisonResult.orderedSame ==
                    "абвг".localizedCaseInsensitiveCompare("АбВг"))
        #expect(ComparisonResult.orderedAscending ==
                    "абВГ".localizedCaseInsensitiveCompare("АбВгД"))
    }

    @Test func localizedCompare() {
        #expect(ComparisonResult.orderedAscending ==
                    "abCD".localizedCompare("AbCd"))

        #expect(ComparisonResult.orderedAscending ==
                    "абвг".localizedCompare("АбВг"))
    }

    @Test func localizedStandardCompare() {
        #expect(ComparisonResult.orderedAscending ==
                    "abCD".localizedStandardCompare("AbCd"))

        #expect(ComparisonResult.orderedAscending ==
                    "абвг".localizedStandardCompare("АбВг"))
    }

    @Test func localizedLowercase() {
        let en = Locale(identifier: "en")
        let ru = Locale(identifier: "ru")
        #expect("abcd" == "abCD".lowercased(with: en))
        #expect("абвг" == "абВГ".lowercased(with: en))
        #expect("абвг" == "абВГ".lowercased(with: ru))
        #expect("たちつてと" == "たちつてと".lowercased(with: ru))

        //
        // Special casing.
        //

        // U+0130 LATIN CAPITAL LETTER I WITH DOT ABOVE
        // to lower case:
        // U+0069 LATIN SMALL LETTER I
        // U+0307 COMBINING DOT ABOVE
        #expect("\u{0069}\u{0307}" == "\u{0130}".lowercased(with: Locale(identifier: "en")))

        // U+0130 LATIN CAPITAL LETTER I WITH DOT ABOVE
        // to lower case in Turkish locale:
        // U+0069 LATIN SMALL LETTER I
        #expect("\u{0069}" == "\u{0130}".lowercased(with: Locale(identifier: "tr")))

        // U+0049 LATIN CAPITAL LETTER I
        // U+0307 COMBINING DOT ABOVE
        // to lower case:
        // U+0069 LATIN SMALL LETTER I
        // U+0307 COMBINING DOT ABOVE
        #expect("\u{0069}\u{0307}" == "\u{0049}\u{0307}".lowercased(with: Locale(identifier: "en")))

        // U+0049 LATIN CAPITAL LETTER I
        // U+0307 COMBINING DOT ABOVE
        // to lower case in Turkish locale:
        // U+0069 LATIN SMALL LETTER I
        #expect("\u{0069}" == "\u{0049}\u{0307}".lowercased(with: Locale(identifier: "tr")))
    }

    @Test func lowercased() {
        expectLocalizedEquality("abcd", { loc in "abCD".lowercased(with: loc) }, "en")

        expectLocalizedEquality("абвг", { loc in "абВГ".lowercased(with: loc) }, "en")
        expectLocalizedEquality("абвг", { loc in "абВГ".lowercased(with: loc) }, "ru")

        expectLocalizedEquality("たちつてと", { loc in "たちつてと".lowercased(with: loc) }, "ru")

        //
        // Special casing.
        //

        // U+0130 LATIN CAPITAL LETTER I WITH DOT ABOVE
        // to lower case:
        // U+0069 LATIN SMALL LETTER I
        // U+0307 COMBINING DOT ABOVE
        expectLocalizedEquality("\u{0069}\u{0307}", { loc in "\u{0130}".lowercased(with: loc) }, "en")

        // U+0130 LATIN CAPITAL LETTER I WITH DOT ABOVE
        // to lower case in Turkish locale:
        // U+0069 LATIN SMALL LETTER I
        expectLocalizedEquality("\u{0069}", { loc in "\u{0130}".lowercased(with: loc) }, "tr")

        // U+0049 LATIN CAPITAL LETTER I
        // U+0307 COMBINING DOT ABOVE
        // to lower case:
        // U+0069 LATIN SMALL LETTER I
        // U+0307 COMBINING DOT ABOVE
        expectLocalizedEquality("\u{0069}\u{0307}", { loc in "\u{0049}\u{0307}".lowercased(with: loc) }, "en")

        // U+0049 LATIN CAPITAL LETTER I
        // U+0307 COMBINING DOT ABOVE
        // to lower case in Turkish locale:
        // U+0069 LATIN SMALL LETTER I
        expectLocalizedEquality("\u{0069}", { loc in "\u{0049}\u{0307}".lowercased(with: loc) }, "tr")
    }

    @Test func maximumLengthOfBytesUsingEncoding() {
        do {
            let s = "abc"
            #expect(s.utf8.count <= s.maximumLengthOfBytes(using: .utf8))
        }
        do {
            let s = "abc абв"
            #expect(s.utf8.count <= s.maximumLengthOfBytes(using: .utf8))
        }
        do {
            let s = "\u{1F60A}"
            #expect(s.utf8.count <= s.maximumLengthOfBytes(using: .utf8))
        }
    }

    @Test func paragraphRangeFor() {
        let s = "Глокая куздра\nштеко будланула\u{2028}бокра и кудрячит\u{2028}бокрёнка.\n Абв."
        let r = s.index(s.startIndex, offsetBy: 16)..<s.index(s.startIndex, offsetBy: 35)
        do {
            let result = s.paragraphRange(for: r)
            #expect("штеко будланула\u{2028}бокра и кудрячит\u{2028}бокрёнка.\n" == s[result])
        }
    }

    @Test func pathComponents() {
        #expect([ "/", "foo", "bar" ] as [NSString] == ("/foo/bar" as NSString).pathComponents as [NSString])
        #expect([ "/", "абв", "где" ] as [NSString] == ("/абв/где" as NSString).pathComponents as [NSString])
    }

    @Test func precomposedStringWithCanonicalMapping() {
        #expect("abc" == "abc".precomposedStringWithCanonicalMapping)
        #expect("だくてん" ==
                    "\u{305f}\u{3099}くてん".precomposedStringWithCanonicalMapping)
        #expect("ﾀﾞｸﾃﾝ" ==
                    "\u{ff80}\u{ff9e}ｸﾃﾝ".precomposedStringWithCanonicalMapping)
        #expect("\u{fb03}" == "\u{fb03}".precomposedStringWithCanonicalMapping)
    }

    @Test func precomposedStringWithCompatibilityMapping() {
        #expect("abc" == "abc".precomposedStringWithCompatibilityMapping)
        /*
         Test disabled because of:
         <rdar://problem/17041347> NFKD normalization as implemented by
         'precomposedStringWithCompatibilityMapping:' is not idempotent

         #expect("\u{30c0}クテン" ==
         "\u{ff80}\u{ff9e}ｸﾃﾝ".precomposedStringWithCompatibilityMapping)
         */
        #expect("ffi" == "\u{fb03}".precomposedStringWithCompatibilityMapping)
    }

    @Test func propertyList() {
        #expect(["foo", "bar"] ==
                    "(\"foo\", \"bar\")".propertyList() as! [String])
    }

    @Test func propertyListFromStringsFileFormat() {
        #expect(["foo": "bar", "baz": "baz"] ==
                    "/* comment */\n\"foo\" = \"bar\";\n\"baz\";"
            .propertyListFromStringsFileFormat() as Dictionary<String, String>)
    }

    @Test func rangeOfCharacterFrom() {
        do {
            let charset = CharacterSet(charactersIn: "абв")
            do {
                let s = "Глокая куздра"
                let r = s.rangeOfCharacter(from: charset)!
                #expect(s.index(s.startIndex, offsetBy: 4) == r.lowerBound)
                #expect(s.index(s.startIndex, offsetBy: 5) == r.upperBound)
            }
            do {
                #expect("клмн".rangeOfCharacter(from: charset) == nil)
            }
            do {
                let s = "абвклмнабвклмн"
                let r = s.rangeOfCharacter(from: charset,
                                           options: .backwards)!
                #expect(s.index(s.startIndex, offsetBy: 9) == r.lowerBound)
                #expect(s.index(s.startIndex, offsetBy: 10) == r.upperBound)
            }
            do {
                let s = "абвклмнабв"
                let r = s.rangeOfCharacter(from: charset,
                                           range: s.index(s.startIndex, offsetBy: 3)..<s.endIndex)!
                #expect(s.index(s.startIndex, offsetBy: 7) == r.lowerBound)
                #expect(s.index(s.startIndex, offsetBy: 8) == r.upperBound)
            }
        }

        do {
            let charset = CharacterSet(charactersIn: "\u{305f}\u{3099}")
            #expect("\u{3060}".rangeOfCharacter(from: charset) == nil)
        }
        do {
            let charset = CharacterSet(charactersIn: "\u{3060}")
            #expect("\u{305f}\u{3099}".rangeOfCharacter(from: charset) == nil)
        }

        do {
            let charset = CharacterSet(charactersIn: "\u{1F600}")
            do {
                let s = "abc\u{1F600}"
                #expect("\u{1F600}" ==
                            s[s.rangeOfCharacter(from: charset)!])
            }
            do {
                #expect("abc\u{1F601}".rangeOfCharacter(from: charset) == nil)
            }
        }
    }

    @Test func rangeOfComposedCharacterSequence() {
        let s = "\u{1F601}abc \u{305f}\u{3099} def"
        #expect("\u{1F601}" == s[s.rangeOfComposedCharacterSequence(
            at: s.startIndex)])
        #expect("a" == s[s.rangeOfComposedCharacterSequence(
            at: s.index(s.startIndex, offsetBy: 1))])
        #expect("\u{305f}\u{3099}" == s[s.rangeOfComposedCharacterSequence(
            at: s.index(s.startIndex, offsetBy: 5))])
        #expect(" " == s[s.rangeOfComposedCharacterSequence(
            at: s.index(s.startIndex, offsetBy: 6))])
    }

    @Test func rangeOfComposedCharacterSequences() {
        let s = "\u{1F601}abc さ\u{3099}し\u{3099}す\u{3099}せ\u{3099}そ\u{3099}"

        #expect("\u{1F601}a" == s[s.rangeOfComposedCharacterSequences(
            for: s.startIndex..<s.index(s.startIndex, offsetBy: 2))])
        #expect("せ\u{3099}そ\u{3099}" == s[s.rangeOfComposedCharacterSequences(
            for: s.index(s.startIndex, offsetBy: 8)..<s.index(s.startIndex, offsetBy: 10))])
    }

    func toIntRange<S : StringProtocol>(
        _ string: S, _ maybeRange: Range<String.Index>?
    ) -> Range<Int>? where S.Index == String.Index {
        guard let range = maybeRange else { return nil }

        return string.distance(from: string.startIndex, to: range.lowerBound) ..< string.distance(from: string.startIndex, to: range.upperBound)
    }

    @Test func range() {
        do {
            let s = ""
            #expect(s.range(of: "") == nil)
            #expect(s.range(of: "abc") == nil)
        }
        do {
            let s = "abc"
            #expect(s.range(of: "") == nil)
            #expect(s.range(of: "def") == nil)
            #expect(0..<3 == toIntRange(s, s.range(of: "abc")))
        }
        do {
            let s = "さ\u{3099}し\u{3099}す\u{3099}せ\u{3099}そ\u{3099}"
            #expect(2..<3 == toIntRange(s, s.range(of: "す\u{3099}")))
            #expect(2..<3 == toIntRange(s, s.range(of: "\u{305a}")))

            #expect(s.range(of: "\u{3099}す") == nil)
            #expect(s.range(of: "す") == nil)

            #expect(s.range(of: "\u{3099}") == nil)
            #expect("\u{3099}" == s[s.range(of: "\u{3099}", options: .literal)!])
        }
        do {
            let s = "а\u{0301}б\u{0301}в\u{0301}г\u{0301}"
            #expect(0..<1 == toIntRange(s, s.range(of: "а\u{0301}")))
            #expect(1..<2 == toIntRange(s, s.range(of: "б\u{0301}")))

            #expect(s.range(of: "б") == nil)
            #expect(s.range(of: "\u{0301}б") == nil)

            #expect(s.range(of: "\u{0301}") == nil)
            #expect("\u{0301}" == s[s.range(of: "\u{0301}", options: .literal)!])
        }
    }

    @Test func contains() {
            #expect(!"".contains(""))
            #expect(!"".contains("a"))
            #expect(!"a".contains(""))
            #expect(!"a".contains("b"))
            #expect("a".contains("a"))
            #expect(!"a".contains("A"))
            #expect(!"A".contains("a"))
            #expect(!"a".contains("a\u{0301}"))
            #expect("a\u{0301}".contains("a\u{0301}"))
            #expect(!"a\u{0301}".contains("a"))
            #expect(!"a\u{0301}".contains("\u{0301}")) // Update to match stdlib's `firstRange` and `contains` result
            #expect(!"a".contains("\u{0301}"))

            #expect(!"i".contains("I"))
            #expect(!"I".contains("i"))
            #expect(!"\u{0130}".contains("i"))
            #expect(!"i".contains("\u{0130}"))
            #expect(!"\u{0130}".contains("ı"))
    }

    @Test func localizedCaseInsensitiveContains() {
        let en = Locale(identifier: "en")
        #expect(!"".localizedCaseInsensitiveContains("", locale: en))
        #expect(!"".localizedCaseInsensitiveContains("a", locale: en))
        #expect(!"a".localizedCaseInsensitiveContains("", locale: en))
        #expect(!"a".localizedCaseInsensitiveContains("b", locale: en))
        #expect("a".localizedCaseInsensitiveContains("a", locale: en))
        #expect("a".localizedCaseInsensitiveContains("A", locale: en))
        #expect("A".localizedCaseInsensitiveContains("a", locale: en))
        #expect(!"a".localizedCaseInsensitiveContains("a\u{0301}", locale: en))
        #expect("a\u{0301}".localizedCaseInsensitiveContains("a\u{0301}", locale: en))
        #expect(!"a\u{0301}".localizedCaseInsensitiveContains("a", locale: en))
        #expect("a\u{0301}".localizedCaseInsensitiveContains("\u{0301}", locale: en))
        #expect(!"a".localizedCaseInsensitiveContains("\u{0301}", locale: en))

        #expect("i".localizedCaseInsensitiveContains("I", locale: en))
        #expect("I".localizedCaseInsensitiveContains("i", locale: en))
        #expect(!"\u{0130}".localizedCaseInsensitiveContains("i", locale: en))
        #expect(!"i".localizedCaseInsensitiveContains("\u{0130}", locale: en))

        #expect(!"\u{0130}".localizedCaseInsensitiveContains("ı", locale: Locale(identifier: "tr")))
    }

    @Test func localizedStandardContains() {
        let en = Locale(identifier: "en")
        #expect(!"".localizedStandardContains("", locale: en))
        #expect(!"".localizedStandardContains("a", locale: en))
        #expect(!"a".localizedStandardContains("", locale: en))
        #expect(!"a".localizedStandardContains("b", locale: en))
        #expect("a".localizedStandardContains("a", locale: en))
        #expect("a".localizedStandardContains("A", locale: en))
        #expect("A".localizedStandardContains("a", locale: en))
        #expect("a".localizedStandardContains("a\u{0301}", locale: en))
        #expect("a\u{0301}".localizedStandardContains("a\u{0301}", locale: en))
        #expect("a\u{0301}".localizedStandardContains("a", locale: en))
        #expect("a\u{0301}".localizedStandardContains("\u{0301}", locale: en))
        #expect(!"a".localizedStandardContains("\u{0301}", locale: en))

        #expect("i".localizedStandardContains("I", locale: en))
        #expect("I".localizedStandardContains("i", locale: en))
        #expect("\u{0130}".localizedStandardContains("i", locale: en))
        #expect("i".localizedStandardContains("\u{0130}", locale: en))

        #expect("\u{0130}".localizedStandardContains("ı", locale: Locale(identifier: "tr")))
    }

    @Test func localizedStandardRange() {
        func rangeOf(_ string: String, _ substring: String, locale: Locale) -> Range<Int>? {
            return toIntRange(
                string, string.localizedStandardRange(of: substring, locale: locale))
        }

        let en = Locale(identifier: "en")

        #expect(rangeOf("", "", locale: en) == nil)
        #expect(rangeOf("", "a", locale: en) == nil)
        #expect(rangeOf("a", "", locale: en) == nil)
        #expect(rangeOf("a", "b", locale: en) == nil)
        #expect(0..<1 == rangeOf("a", "a", locale: en))
        #expect(0..<1 == rangeOf("a", "A", locale: en))
        #expect(0..<1 == rangeOf("A", "a", locale: en))
        #expect(0..<1 == rangeOf("a", "a\u{0301}", locale: en))
        #expect(0..<1 == rangeOf("a\u{0301}", "a\u{0301}", locale: en))
        #expect(0..<1 == rangeOf("a\u{0301}", "a", locale: en))
        do {
        // FIXME: Indices that don't correspond to grapheme cluster boundaries.
            let s = "a\u{0301}"
            #expect(
                "\u{0301}" == s[s.localizedStandardRange(of: "\u{0301}", locale: en)!])
        }
        #expect(rangeOf("a", "\u{0301}", locale: en) == nil)

        #expect(0..<1 == rangeOf("i", "I", locale: en))
        #expect(0..<1 == rangeOf("I", "i", locale: en))
        #expect(0..<1 == rangeOf("\u{0130}", "i", locale: en))
        #expect(0..<1 == rangeOf("i", "\u{0130}", locale: en))


        let tr = Locale(identifier: "tr")
        #expect(0..<1 == rangeOf("\u{0130}", "ı", locale: tr))
    }

    @Test func smallestEncoding() {
        let availableEncodings: [String.Encoding] = String.availableStringEncodings
        #expect(availableEncodings.contains("abc".smallestEncoding))
    }

    @Test func addingPercentEncoding() {
        #expect(
            "abcd1234" ==
            "abcd1234".addingPercentEncoding(withAllowedCharacters: .alphanumerics))
        #expect(
            "abcd%20%D0%B0%D0%B1%D0%B2%D0%B3" ==
            "abcd абвг".addingPercentEncoding(withAllowedCharacters: .alphanumerics))
    }

    @Test func appendingFormat() {
        #expect("" == "".appendingFormat(""))
        #expect("a" == "a".appendingFormat(""))
        #expect(
            "abc абв \u{0001F60A}" ==
            "abc абв \u{0001F60A}".appendingFormat(""))

        let formatArg: NSString = "привет мир \u{0001F60A}"
        #expect(
            "abc абв \u{0001F60A}def привет мир \u{0001F60A} 42" ==
            "abc абв \u{0001F60A}"
                .appendingFormat("def %@ %ld", formatArg, 42))
    }

    @Test func appending() {
        #expect("" == "".appending(""))
        #expect("a" == "a".appending(""))
        #expect("a" == "".appending("a"))
        #expect("さ\u{3099}" == "さ".appending("\u{3099}"))
    }

    @Test func folding() {

        func fwo(
            _ s: String, _ options: String.CompareOptions
        ) -> (Locale?) -> String {
            return { loc in s.folding(options: options, locale: loc) }
        }

        expectLocalizedEquality("abcd", fwo("abCD", .caseInsensitive), "en")

        // U+0130 LATIN CAPITAL LETTER I WITH DOT ABOVE
        // to lower case:
        // U+0069 LATIN SMALL LETTER I
        // U+0307 COMBINING DOT ABOVE
        expectLocalizedEquality(
            "\u{0069}\u{0307}", fwo("\u{0130}", .caseInsensitive), "en")

        // U+0130 LATIN CAPITAL LETTER I WITH DOT ABOVE
        // to lower case in Turkish locale:
        // U+0069 LATIN SMALL LETTER I
        expectLocalizedEquality(
            "\u{0069}", fwo("\u{0130}", .caseInsensitive), "tr")

        expectLocalizedEquality(
            "example123", fwo("ｅｘａｍｐｌｅ１２３", .widthInsensitive), "en")
    }

    @Test func padding() {
        #expect(
            "abc абв \u{0001F60A}" ==
            "abc абв \u{0001F60A}".padding(
                toLength: 10, withPad: "XYZ", startingAt: 0))
        #expect(
            "abc абв \u{0001F60A}XYZXY" ==
            "abc абв \u{0001F60A}".padding(
                toLength: 15, withPad: "XYZ", startingAt: 0))
        #expect(
            "abc абв \u{0001F60A}YZXYZ" ==
            "abc абв \u{0001F60A}".padding(
                toLength: 15, withPad: "XYZ", startingAt: 1))
    }

    @Test func replacingCharacters() {
        do {
            let empty = ""
            #expect("" == empty.replacingCharacters(
                in: empty.startIndex..<empty.startIndex, with: ""))
        }

        let s = "\u{1F601}abc さ\u{3099}し\u{3099}す\u{3099}せ\u{3099}そ\u{3099}"

        #expect(s == s.replacingCharacters(
            in: s.startIndex..<s.startIndex, with: ""))
        #expect(s == s.replacingCharacters(
            in: s.endIndex..<s.endIndex, with: ""))
        #expect("zzz" + s == s.replacingCharacters(
            in: s.startIndex..<s.startIndex, with: "zzz"))
        #expect(s + "zzz" == s.replacingCharacters(
            in: s.endIndex..<s.endIndex, with: "zzz"))

        #expect(
            "す\u{3099}せ\u{3099}そ\u{3099}" ==
            s.replacingCharacters(
                in: s.startIndex..<s.index(s.startIndex, offsetBy: 7), with: ""))
        #expect(
            "zzzす\u{3099}せ\u{3099}そ\u{3099}" ==
            s.replacingCharacters(
                in: s.startIndex..<s.index(s.startIndex, offsetBy: 7), with: "zzz"))
        #expect(
            "\u{1F602}す\u{3099}せ\u{3099}そ\u{3099}" ==
            s.replacingCharacters(
                in: s.startIndex..<s.index(s.startIndex, offsetBy: 7), with: "\u{1F602}"))

        #expect("\u{1F601}" == s.replacingCharacters(
            in: s.index(after: s.startIndex)..<s.endIndex, with: ""))
        #expect("\u{1F601}zzz" == s.replacingCharacters(
            in: s.index(after: s.startIndex)..<s.endIndex, with: "zzz"))
        #expect("\u{1F601}\u{1F602}" == s.replacingCharacters(
            in: s.index(after: s.startIndex)..<s.endIndex, with: "\u{1F602}"))

        #expect(
            "\u{1F601}aす\u{3099}せ\u{3099}そ\u{3099}" ==
            s.replacingCharacters(
                in: s.index(s.startIndex, offsetBy: 2)..<s.index(s.startIndex, offsetBy: 7), with: ""))
        #expect(
            "\u{1F601}azzzす\u{3099}せ\u{3099}そ\u{3099}" ==
            s.replacingCharacters(
                in: s.index(s.startIndex, offsetBy: 2)..<s.index(s.startIndex, offsetBy: 7), with: "zzz"))
        #expect(
            "\u{1F601}a\u{1F602}す\u{3099}せ\u{3099}そ\u{3099}" ==
            s.replacingCharacters(
                in: s.index(s.startIndex, offsetBy: 2)..<s.index(s.startIndex, offsetBy: 7),
                with: "\u{1F602}"))
    }

    @Test func replacingOccurrences() {
        do {
            let empty = ""
            #expect("" == empty.replacingOccurrences(
                of: "", with: ""))
            #expect("" == empty.replacingOccurrences(
                of: "", with: "xyz"))
            #expect("" == empty.replacingOccurrences(
                of: "abc", with: "xyz"))
        }

        let s = "\u{1F601}abc さ\u{3099}し\u{3099}す\u{3099}せ\u{3099}そ\u{3099}"

        #expect(s == s.replacingOccurrences(of: "", with: "xyz"))
        #expect(s == s.replacingOccurrences(of: "xyz", with: ""))

        #expect("" == s.replacingOccurrences(of: s, with: ""))

        #expect(
            "\u{1F601}xyzbc さ\u{3099}し\u{3099}す\u{3099}せ\u{3099}そ\u{3099}" ==
            s.replacingOccurrences(of: "a", with: "xyz"))

        #expect(
            "\u{1F602}\u{1F603}abc さ\u{3099}し\u{3099}す\u{3099}せ\u{3099}そ\u{3099}" ==
            s.replacingOccurrences(
                of: "\u{1F601}", with: "\u{1F602}\u{1F603}"))

        #expect(
            "\u{1F601}abc さ\u{3099}xyzす\u{3099}せ\u{3099}そ\u{3099}" ==
            s.replacingOccurrences(
                of: "し\u{3099}", with: "xyz"))

        #expect(
            "\u{1F601}abc さ\u{3099}xyzす\u{3099}せ\u{3099}そ\u{3099}" ==
            s.replacingOccurrences(
                of: "し\u{3099}", with: "xyz"))

        #expect(
            "\u{1F601}abc さ\u{3099}xyzす\u{3099}せ\u{3099}そ\u{3099}" ==
            s.replacingOccurrences(
                of: "\u{3058}", with: "xyz"))

        //
        // Use non-default 'options:'
        //

        #expect(
            "\u{1F602}\u{1F603}abc さ\u{3099}し\u{3099}す\u{3099}せ\u{3099}そ\u{3099}" ==
            s.replacingOccurrences(
                of: "\u{1F601}", with: "\u{1F602}\u{1F603}",
                options: String.CompareOptions.literal))

        #expect(s == s.replacingOccurrences(
            of: "\u{3058}", with: "xyz",
            options: String.CompareOptions.literal))

        //
        // Use non-default 'range:'
        //

        #expect(
            "\u{1F602}\u{1F603}abc さ\u{3099}し\u{3099}す\u{3099}せ\u{3099}そ\u{3099}" ==
            s.replacingOccurrences(
                of: "\u{1F601}", with: "\u{1F602}\u{1F603}",
                options: String.CompareOptions.literal,
                range: s.startIndex..<s.index(s.startIndex, offsetBy: 1)))

        #expect(s == s.replacingOccurrences(
            of: "\u{1F601}", with: "\u{1F602}\u{1F603}",
            options: String.CompareOptions.literal,
            range: s.index(s.startIndex, offsetBy: 1)..<s.index(s.startIndex, offsetBy: 3)))
    }

    @Test func removingPercentEncoding() {
        #expect(
            "abcd абвг" ==
            "abcd абвг".removingPercentEncoding)

        #expect(
            "abcd абвг\u{0000}\u{0001}" ==
            "abcd абвг%00%01".removingPercentEncoding)

        #expect(
            "abcd абвг" ==
            "%61%62%63%64%20%D0%B0%D0%B1%D0%B2%D0%B3".removingPercentEncoding)

        #expect(
            "abcd абвг" ==
            "ab%63d %D0%B0%D0%B1%D0%B2%D0%B3".removingPercentEncoding)

        #expect("%ED%B0".removingPercentEncoding == nil)

        #expect("%zz".removingPercentEncoding == nil)

        #expect("abcd%FF".removingPercentEncoding == nil)

        #expect("%".removingPercentEncoding == nil)
    }

    @Test func removingPercentEncoding_() {
        #expect("" == "".removingPercentEncoding)
    }

    @Test func trimmingCharacters() {
        #expect("" == "".trimmingCharacters(
            in: CharacterSet.decimalDigits))

        #expect("abc" == "abc".trimmingCharacters(
            in: CharacterSet.decimalDigits))

        #expect("" == "123".trimmingCharacters(
            in: CharacterSet.decimalDigits))

        #expect("abc" == "123abc789".trimmingCharacters(
            in: CharacterSet.decimalDigits))

        // Performs Unicode scalar comparison.
        #expect(
            "し\u{3099}abc" ==
            "し\u{3099}abc".trimmingCharacters(
                in: CharacterSet(charactersIn: "\u{3058}")))
    }

    @Test func NSString_stringsByAppendingPaths() {
        #expect([] as [NSString] == ("" as NSString).strings(byAppendingPaths: []) as [NSString])
        #expect(
            [ "/tmp/foo", "/tmp/bar" ] as [NSString] ==
            ("/tmp" as NSString).strings(byAppendingPaths: [ "foo", "bar" ]) as [NSString])
    }

    @available(*, deprecated)
    @Test func substring_from() {
        let s = "\u{1F601}abc さ\u{3099}し\u{3099}す\u{3099}せ\u{3099}そ\u{3099}"

        #expect(s == s.substring(from: s.startIndex))
        #expect("せ\u{3099}そ\u{3099}" ==
                    s.substring(from: s.index(s.startIndex, offsetBy: 8)))
        #expect("" == s.substring(from: s.index(s.startIndex, offsetBy: 10)))
    }

    @available(*, deprecated)
    @Test func substring_to() {
        let s = "\u{1F601}abc さ\u{3099}し\u{3099}す\u{3099}せ\u{3099}そ\u{3099}"

        #expect("" == s.substring(to: s.startIndex))
        #expect("\u{1F601}abc さ\u{3099}し\u{3099}す\u{3099}" ==
                    s.substring(to: s.index(s.startIndex, offsetBy: 8)))
        #expect(s == s.substring(to: s.index(s.startIndex, offsetBy: 10)))
    }

    @available(*, deprecated)
    @Test func substring_with() {
        let s = "\u{1F601}abc さ\u{3099}し\u{3099}す\u{3099}せ\u{3099}そ\u{3099}"

        #expect("" == s.substring(with: s.startIndex..<s.startIndex))
        #expect(
            "" ==
            s.substring(with: s.index(s.startIndex, offsetBy: 1)..<s.index(s.startIndex, offsetBy: 1)))
        #expect("" == s.substring(with: s.endIndex..<s.endIndex))
        #expect(s == s.substring(with: s.startIndex..<s.endIndex))
        #expect(
            "さ\u{3099}し\u{3099}す\u{3099}" ==
            s.substring(with: s.index(s.startIndex, offsetBy: 5)..<s.index(s.startIndex, offsetBy: 8)))
    }

    @Test func localizedUppercase() {
        #expect("ABCD" == "abCD".uppercased(with: Locale(identifier: "en")))

        #expect("АБВГ" == "абВГ".uppercased(with: Locale(identifier: "en")))

        #expect("АБВГ" == "абВГ".uppercased(with: Locale(identifier: "ru")))

        #expect("たちつてと" == "たちつてと".uppercased(with: Locale(identifier: "ru")))

        //
        // Special casing.
        //

        // U+0069 LATIN SMALL LETTER I
        // to upper case:
        // U+0049 LATIN CAPITAL LETTER I
        #expect("\u{0049}" == "\u{0069}".uppercased(with: Locale(identifier: "en")))

        // U+0069 LATIN SMALL LETTER I
        // to upper case in Turkish locale:
        // U+0130 LATIN CAPITAL LETTER I WITH DOT ABOVE
        #expect("\u{0130}" == "\u{0069}".uppercased(with: Locale(identifier: "tr")))

        // U+00DF LATIN SMALL LETTER SHARP S
        // to upper case:
        // U+0053 LATIN CAPITAL LETTER S
        // U+0073 LATIN SMALL LETTER S
        // But because the whole string is converted to uppercase, we just get two
        // U+0053.
        #expect("\u{0053}\u{0053}" == "\u{00df}".uppercased(with: Locale(identifier: "en")))

        // U+FB01 LATIN SMALL LIGATURE FI
        // to upper case:
        // U+0046 LATIN CAPITAL LETTER F
        // U+0069 LATIN SMALL LETTER I
        // But because the whole string is converted to uppercase, we get U+0049
        // LATIN CAPITAL LETTER I.
        #expect("\u{0046}\u{0049}" == "\u{fb01}".uppercased(with: Locale(identifier: "ru")))
    }

    @Test func uppercased() {
        expectLocalizedEquality("ABCD", { loc in "abCD".uppercased(with: loc) }, "en")

        expectLocalizedEquality("АБВГ", { loc in "абВГ".uppercased(with: loc) }, "en")
        expectLocalizedEquality("АБВГ", { loc in "абВГ".uppercased(with: loc) }, "ru")

        expectLocalizedEquality("たちつてと", { loc in "たちつてと".uppercased(with: loc) }, "ru")

        //
        // Special casing.
        //

        // U+0069 LATIN SMALL LETTER I
        // to upper case:
        // U+0049 LATIN CAPITAL LETTER I
        expectLocalizedEquality("\u{0049}", { loc in "\u{0069}".uppercased(with: loc) }, "en")

        // U+0069 LATIN SMALL LETTER I
        // to upper case in Turkish locale:
        // U+0130 LATIN CAPITAL LETTER I WITH DOT ABOVE
        expectLocalizedEquality("\u{0130}", { loc in "\u{0069}".uppercased(with: loc) }, "tr")

        // U+00DF LATIN SMALL LETTER SHARP S
        // to upper case:
        // U+0053 LATIN CAPITAL LETTER S
        // U+0073 LATIN SMALL LETTER S
        // But because the whole string is converted to uppercase, we just get two
        // U+0053.
        expectLocalizedEquality("\u{0053}\u{0053}", { loc in "\u{00df}".uppercased(with: loc) }, "en")

        // U+FB01 LATIN SMALL LIGATURE FI
        // to upper case:
        // U+0046 LATIN CAPITAL LETTER F
        // U+0069 LATIN SMALL LETTER I
        // But because the whole string is converted to uppercase, we get U+0049
        // LATIN CAPITAL LETTER I.
        expectLocalizedEquality("\u{0046}\u{0049}", { loc in "\u{fb01}".uppercased(with: loc) }, "ru")
    }

    @Test func applyingTransform() {
        do {
            let source = "tre\u{300}s k\u{fc}hl"
            #expect(
                "tres kuhl" ==
                source.applyingTransform(.stripDiacritics, reverse: false))
        }
        do {
            let source = "hiragana"
            #expect(
                "ひらがな" ==
                source.applyingTransform(.latinToHiragana, reverse: false))
        }
        do {
            let source = "ひらがな"
            #expect(
                "hiragana" ==
                source.applyingTransform(.latinToHiragana, reverse: true))
        }
    }

    @Test func SameTypeComparisons() {
        // U+0323 COMBINING DOT BELOW
        // U+0307 COMBINING DOT ABOVE
        // U+1E63 LATIN SMALL LETTER S WITH DOT BELOW
        let xs = "\u{1e69}"
        #expect(xs == "s\u{323}\u{307}")
        #expect(!(xs != "s\u{323}\u{307}"))
        #expect("s\u{323}\u{307}" == xs)
        #expect(!("s\u{323}\u{307}" != xs))
        #expect("\u{1e69}" == "s\u{323}\u{307}")
        #expect(!("\u{1e69}" != "s\u{323}\u{307}"))
        #expect(xs == xs)
        #expect(!(xs != xs))
    }

    @Test func MixedTypeComparisons() {
        // U+0323 COMBINING DOT BELOW
        // U+0307 COMBINING DOT ABOVE
        // U+1E63 LATIN SMALL LETTER S WITH DOT BELOW
        // NSString does not decompose characters, so the two strings will be (==) in
        // swift but not in Foundation.
        let xs = "\u{1e69}"
        let ys: NSString = "s\u{323}\u{307}"
        #expect(!(ys == "\u{1e69}"))
        #expect(ys != "\u{1e69}")
        #expect(!("\u{1e69}" == ys))
        #expect("\u{1e69}" != ys)
        #expect(!(xs as NSString == ys))
        #expect(xs as NSString != ys)
        #expect(ys == ys)
        #expect(!(ys != ys))
    }

    @Test func copy_construction() {
        let expected = "abcd"
        let x = NSString(string: expected as NSString)
        #expect(expected == x as String)
        let y = NSMutableString(string: expected as NSString)
        #expect(expected == y as String)
    }
}

extension String {
    func range(fromStart: Int, fromEnd: Int) -> Range<String.Index> {
        return index(startIndex, offsetBy: fromStart) ..<
           index(endIndex, offsetBy: fromEnd)
    }
    subscript(fromStart: Int, fromEnd: Int) -> SubSequence {
        return self[range(fromStart: fromStart, fromEnd: fromEnd)]
    }
}

struct StdlibSubstringTests {

    @Test func range_of_NilRange() {
        let ss = "aabcdd"[1, -1]
        let range = ss.range(of: "bc")
        #expect("bc" == range.map { ss[$0] })
    }

    @Test func range_of_NonNilRange() {
        let s = "aabcdd"
        let ss = s[1, -1]
        let searchRange = s.range(fromStart: 2, fromEnd: -2)
        let range = ss.range(of: "bc", range: searchRange)
        #expect("bc" == range.map { ss[$0] })
    }

    @Test func rangeOfCharacter() {
        let ss = "__hello__"[2, -2]
        let range = ss.rangeOfCharacter(from: CharacterSet.alphanumerics)
        #expect("h" == range.map { ss[$0] })
    }

    @Test func compare_optionsNilRange() {
        let needle = "hello"
        let haystack = "__hello__"[2, -2]
        #expect(.orderedSame == haystack.compare(needle))
    }

    @Test func compare_optionsNonNilRange() {
        let needle = "hello"
        let haystack = "__hello__"
        let range = haystack.range(fromStart: 2, fromEnd: -2)
        #expect(.orderedSame == haystack[range].compare(needle, range: range))
    }

    @Test func replacingCharacters() {
        let s = "__hello, world"
        let range = s.range(fromStart: 2, fromEnd: -7)
        let expected = "__goodbye, world"
        let replacement = "goodbye"
        #expect(expected ==
                    s.replacingCharacters(in: range, with: replacement))
        #expect(expected[2, 0] ==
                    s[2, 0].replacingCharacters(in: range, with: replacement))

        #expect(replacement ==
                    s.replacingCharacters(in: s.startIndex..., with: replacement))
        #expect(replacement ==
                    s.replacingCharacters(in: ..<s.endIndex, with: replacement))
        #expect(expected[2, 0] ==
                    s[2, 0].replacingCharacters(in: range, with: replacement[...]))
    }

    @Test func replacingOccurrences_NilRange() {
        let s = "hello"

        #expect("he11o" == s.replacingOccurrences(of: "l", with: "1"))
        #expect("he11o" == s.replacingOccurrences(of: "l"[...], with: "1"))
        #expect("he11o" == s.replacingOccurrences(of: "l", with: "1"[...]))
        #expect("he11o" == s.replacingOccurrences(of: "l"[...], with: "1"[...]))

        #expect("he11o" ==
                    s[...].replacingOccurrences(of: "l", with: "1"))
        #expect("he11o" ==
                    s[...].replacingOccurrences(of: "l"[...], with: "1"))
        #expect("he11o" ==
                    s[...].replacingOccurrences(of: "l", with: "1"[...]))
        #expect("he11o" ==
                    s[...].replacingOccurrences(of: "l"[...], with: "1"[...]))
    }

    @Test func replacingOccurrences_NonNilRange() {
        let s = "hello"
        let r = s.range(fromStart: 1, fromEnd: -2)

        #expect("he1lo" ==
                    s.replacingOccurrences(of: "l", with: "1", range: r))
        #expect("he1lo" ==
                    s.replacingOccurrences(of: "l"[...], with: "1", range: r))
        #expect("he1lo" ==
                    s.replacingOccurrences(of: "l", with: "1"[...], range: r))
        #expect("he1lo" ==
                    s.replacingOccurrences(of: "l"[...], with: "1"[...], range: r))

        #expect("he1lo" ==
                    s[...].replacingOccurrences(of: "l", with: "1", range: r))
        #expect("he1lo" ==
                    s[...].replacingOccurrences(of: "l"[...], with: "1", range: r))
        #expect("he1lo" ==
                    s[...].replacingOccurrences(of: "l", with: "1"[...], range: r))
        #expect("he1lo" ==
                    s[...].replacingOccurrences(of: "l"[...], with: "1"[...], range: r))

        let ss = s[1, -1]
        #expect("e1l" ==
                    ss.replacingOccurrences(of: "l", with: "1", range: r))
        #expect("e1l" ==
                    ss.replacingOccurrences(of: "l"[...], with: "1", range: r))
        #expect("e1l" ==
                    ss.replacingOccurrences(of: "l", with: "1"[...], range: r))
        #expect("e1l" ==
                    ss.replacingOccurrences(of: "l"[...], with: "1"[...], range: r))
    }

    @available(*, deprecated)
    @Test func substring() {
        let s = "hello, world"
        let r = s.range(fromStart: 7, fromEnd: 0)
        #expect("world" == s.substring(with: r))
        #expect("world" == s[...].substring(with: r))
        #expect("world" == s[1, 0].substring(with: r))
    }
}
#endif // FOUNDATION_FRAMEWORK
