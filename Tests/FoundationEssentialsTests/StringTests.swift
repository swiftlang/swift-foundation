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

    func _testRangeOfString(_ tested: String, string: String, anchored: Bool, backwards: Bool, _ expectation: Range<Int>?, file: StaticString = #file, line: UInt = #line) {
        let result = tested._range(of: string, anchored: anchored, backwards: backwards)
        var exp: Range<String.Index>?
        if let expectation {
            exp = tested.index(tested.startIndex, offsetBy: expectation.lowerBound) ..< tested.index(tested.startIndex, offsetBy: expectation.upperBound)
        } else {
            exp = nil
        }

        var message: String
        if let result {
            let readableRange = tested.distance(from: tested.startIndex, to: result.lowerBound)..<tested.distance(from: tested.startIndex, to: result.upperBound)
            message = "Actual: \(readableRange)"
        } else {
            message = "Actual: nil"
        }
        XCTAssertEqual(result, exp, message, file: file, line: line)
    }

    func testRangeOfString() {
        var tested: String
        func testASCII(_ string: String, anchored: Bool, backwards: Bool, _ expectation: Range<Int>?, file: StaticString = #file, line: UInt = #line) {
            return _testRangeOfString(tested, string: string, anchored: anchored, backwards: backwards, expectation, file: file, line: line)
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

    func testRangeOfString_graphemeCluster() {
        var tested: String
        func test(_ string: String, anchored: Bool, backwards: Bool, _ expectation: Range<Int>?, file: StaticString = #file, line: UInt = #line) {
            return _testRangeOfString(tested, string: string, anchored: anchored, backwards: backwards, expectation, file: file, line: line)
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

    func testRangeOfString_lineSeparator() {
        func test(_ tested: String, _ string: String, anchored: Bool, backwards: Bool, _ expectation: Range<Int>?, file: StaticString = #file, line: UInt = #line) {
            return _testRangeOfString(tested, string: string, anchored: anchored, backwards: backwards, expectation, file: file, line: line)
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

    func testTryFromUTF16() {
        func test(_ utf16Buffer: [UInt16], expected: String?, file: StaticString = #file, line: UInt = #line) {
            let result = utf16Buffer.withUnsafeBufferPointer {
                String(_utf16: $0)
            }

            XCTAssertEqual(result, expected, file: file, line: line)
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

    func testTryFromUTF16_roundtrip() {

        func test(_ string: String, file: StaticString = #file, line: UInt = #line) {
            let utf16Array = Array(string.utf16)
            let res = utf16Array.withUnsafeBufferPointer {
                String(_utf16: $0)
            }
            XCTAssertNotNil(res, file: file, line: line)
            XCTAssertEqual(res, string, file: file, line: line)
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
    
    func testParagraphLineRangeOfSeparator() {
        for separator in ["\n", "\r", "\r\n", "\u{2029}", "\u{2028}", "\u{85}"] {
            let range = separator.startIndex ..< separator.endIndex
            let paragraphResult = separator._paragraphBounds(around: range)
            let lineResult = separator._lineBounds(around: range)
            XCTAssertEqual(paragraphResult.start ..< paragraphResult.end, range)
            XCTAssertEqual(lineResult.start ..< lineResult.end, range)
        }
    }
    
    func testAlmostMatchingSeparator() {
        let string = "A\u{200D}B" // U+200D Zero Width Joiner (ZWJ) matches U+2028 Line Separator except for the final UTF-8 scalar
        let lineResult = string._lineBounds(around: string.startIndex ..< string.startIndex)
        XCTAssertEqual(lineResult.start, string.startIndex)
        XCTAssertEqual(lineResult.end, string.endIndex)
        XCTAssertEqual(lineResult.contentsEnd, string.endIndex)
    }

}


#if FOUNDATION_FRAMEWORK
internal var _temporaryLocaleCurrentLocale: NSLocale?

extension NSLocale {

    @objc
    public class func __swiftUnittest_currentLocale() -> NSLocale {
        return _temporaryLocaleCurrentLocale!
    }
}

extension String {
    var lines: [Substring] {
        self.split(separator: "\n")
    }
}

final class StringTestsStdlib: XCTestCase {

   public func withOverriddenLocaleCurrentLocale<Result>(
        _ temporaryLocale: NSLocale,
        _ body: () -> Result
    ) -> Result {
        
        guard let oldMethod = class_getClassMethod(
            NSLocale.self, #selector(getter: NSLocale.current)) as Optional
        else {
            preconditionFailure("Could not find +[Locale currentLocale]")
        }

        guard let newMethod = class_getClassMethod(
            NSLocale.self, #selector(NSLocale.__swiftUnittest_currentLocale)) as Optional
        else {
            preconditionFailure("Could not find +[Locale __swiftUnittest_currentLocale]")
        }

        precondition(_temporaryLocaleCurrentLocale == nil,
                     "Nested calls to withOverriddenLocaleCurrentLocale are not supported")

        _temporaryLocaleCurrentLocale = temporaryLocale
        method_exchangeImplementations(oldMethod, newMethod)
        let result = body()
        method_exchangeImplementations(newMethod, oldMethod)
        _temporaryLocaleCurrentLocale = nil

        return result
    }

    public func withOverriddenLocaleCurrentLocale<Result>(
        _ temporaryLocaleIdentifier: String,
        _ body: () -> Result
    ) -> Result {
        precondition(
            NSLocale.availableLocaleIdentifiers.contains(temporaryLocaleIdentifier),
            "Requested locale \(temporaryLocaleIdentifier) is not available")

        return withOverriddenLocaleCurrentLocale(
            NSLocale(localeIdentifier: temporaryLocaleIdentifier), body)
    }


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

        required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
            fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
        }
        
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

    let temporaryFileContents =
    "Lorem ipsum dolor sit amet, consectetur adipisicing elit,\n" +
    "sed do eiusmod tempor incididunt ut labore et dolore magna\n" +
    "aliqua.\n"


    func withTemporaryStringFile(_ block: (_ existingURL: URL, _ nonExistentURL: URL) -> ()) {
        let rootURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = rootURL.appending(path: "NSStringTest.txt", directoryHint: .notDirectory)
        try! FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer {
            do {
                try FileManager.default.removeItem(at: rootURL)
            } catch {
                XCTFail()
            }
        }


        try! Data(temporaryFileContents.utf8).write(to: fileURL)
        let nonExisting = rootURL.appending(path: "-NonExist", directoryHint: .notDirectory)
        block(fileURL, nonExisting)
    }

    func test_Encodings() {
        let availableEncodings: [String.Encoding] = String.availableStringEncodings
        expectNotEqual(0, availableEncodings.count)

        let defaultCStringEncoding = String.defaultCStringEncoding
        expectTrue(availableEncodings.contains(defaultCStringEncoding))

        expectNotEqual("", String.localizedName(of: .utf8))
    }

    func test_NSStringEncoding() {
        // Make sure NSStringEncoding and its values are type-compatible.
        var enc: String.Encoding
        enc = .windowsCP1250
        enc = .utf32LittleEndian
        enc = .utf32BigEndian
        enc = .ascii
        enc = .utf8
        expectEqual(.utf8, enc)
    }

    func test_NSStringEncoding_Hashable() {
        let instances: [String.Encoding] = [
            .windowsCP1250,
            .utf32LittleEndian,
            .utf32BigEndian,
            .ascii,
            .utf8,
        ]
        checkHashable(instances, equalityOracle: { $0 == $1 })
    }

    func test_localizedStringWithFormat() {
        let world: NSString = "world"
        expectEqual("Hello, world!%42", String.localizedStringWithFormat(
            "Hello, %@!%%%ld", world, 42))

        expectEqual("0.5", String.init(format: "%g", locale: Locale(identifier: "en_US"), 0.5))
        expectEqual("0,5", String.init(format: "%g", locale: Locale(identifier: "uk"), 0.5))
    }

    func test_init_contentsOfFile_encoding() {
        withTemporaryStringFile { existingURL, nonExistentURL in
            do {
                let content = try String(
                    contentsOfFile: existingURL.path, encoding: .ascii)
                expectEqual(
                    "Lorem ipsum dolor sit amet, consectetur adipisicing elit,",
                    content.lines[0])
            } catch {
                XCTFail(error.localizedDescription)
            }

            do {
                let _ = try String(
                    contentsOfFile: nonExistentURL.path, encoding: .ascii)
                XCTFail()
            } catch {
            }
        }
    }

    func test_init_contentsOfFile_usedEncoding() {
        withTemporaryStringFile { existingURL, nonExistentURL in
            do {
                var usedEncoding: String.Encoding = String.Encoding(rawValue: 0)
                let content = try String(
                    contentsOfFile: existingURL.path(), usedEncoding: &usedEncoding)
                expectNotEqual(0, usedEncoding.rawValue)
                expectEqual(
                    "Lorem ipsum dolor sit amet, consectetur adipisicing elit,",
                    content.lines[0])
            } catch {
                XCTFail(error.localizedDescription)
            }

            let usedEncoding: String.Encoding = String.Encoding(rawValue: 0)
            do {
                _ = try String(contentsOfFile: nonExistentURL.path())
                XCTFail()
            } catch {
                expectEqual(0, usedEncoding.rawValue)
            }
        }

    }


    func test_init_contentsOf_encoding() {
        withTemporaryStringFile { existingURL, nonExistentURL in
            do {
                let content = try String(
                    contentsOf: existingURL, encoding: .ascii)
                expectEqual(
                    "Lorem ipsum dolor sit amet, consectetur adipisicing elit,",
                    content.lines[0])
            } catch {
                XCTFail(error.localizedDescription)
            }

            do {
                _ = try String(contentsOf: nonExistentURL, encoding: .ascii)
                XCTFail()
            } catch {
            }
        }

    }

    func test_init_contentsOf_usedEncoding() {
        withTemporaryStringFile { existingURL, nonExistentURL in
            do {
                var usedEncoding: String.Encoding = String.Encoding(rawValue: 0)
                let content = try String(
                    contentsOf: existingURL, usedEncoding: &usedEncoding)

                expectNotEqual(0, usedEncoding.rawValue)
                expectEqual(
                    "Lorem ipsum dolor sit amet, consectetur adipisicing elit,",
                    content.lines[0])
            } catch {
                XCTFail(error.localizedDescription)
            }

            var usedEncoding: String.Encoding = String.Encoding(rawValue: 0)
            do {
                _ = try String(contentsOf: nonExistentURL, usedEncoding: &usedEncoding)
                XCTFail()
            } catch {
                expectEqual(0, usedEncoding.rawValue)
            }
        }

    }

    func test_init_cString_encoding() {
        "foo, a basmati bar!".withCString {
            expectEqual("foo, a basmati bar!",
                        String(cString: $0, encoding: String.defaultCStringEncoding))
        }
    }

    func test_init_utf8String() {
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
        expectEqual(s, String(utf8String: cstr))
        up.deallocate()
    }

    func test_canBeConvertedToEncoding() {
        expectTrue("foo".canBeConverted(to: .ascii))
        expectFalse("あいう".canBeConverted(to: .ascii))
    }

    func test_capitalized() {
        expectEqual("Foo Foo Foo Foo", "foo Foo fOO FOO".capitalized)
        expectEqual("Жжж", "жжж".capitalized)
    }

    func test_localizedCapitalized() {
        if #available(OSX 10.11, iOS 9.0, *) {
            expectEqual(
                "Foo Foo Foo Foo",
                "foo Foo fOO FOO".capitalized(with: Locale(identifier: "en")))
            expectEqual("Жжж", "жжж".capitalized(with: Locale(identifier: "en")))

            //
            // Special casing.
            //

            // U+0069 LATIN SMALL LETTER I
            // to upper case:
            // U+0049 LATIN CAPITAL LETTER I
            expectEqual("Iii Iii", "iii III".capitalized(with: Locale(identifier: "en")))

            // U+0069 LATIN SMALL LETTER I
            // to upper case in Turkish locale:
            // U+0130 LATIN CAPITAL LETTER I WITH DOT ABOVE
            expectEqual("\u{0130}ii Iıı", "iii III".capitalized(with: Locale(identifier: "tr")))
        }
    }

    /// Checks that executing the operation in the locale with the given
    /// `localeID` (or if `localeID` is `nil`, the current locale) gives
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
        _ message: @autoclosure () -> String = "",
        showFrame: Bool = true,
        file: String = #file, line: UInt = #line
    ) {

        let locale = localeID.map {
            Locale(identifier: $0)
        } ?? Locale.current

        expectEqual(
            expected, op(locale),
            message())
    }

    func test_capitalizedString() {
        expectLocalizedEquality(
            "Foo Foo Foo Foo",
            { loc in "foo Foo fOO FOO".capitalized(with: loc) })

        expectLocalizedEquality("Жжж", { loc in "жжж".capitalized(with: loc) })

        expectEqual(
            "Foo Foo Foo Foo",
            "foo Foo fOO FOO".capitalized(with: nil))
        expectEqual("Жжж", "жжж".capitalized(with: nil))

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

    func test_caseInsensitiveCompare() {
        expectEqual(ComparisonResult.orderedSame,
                    "abCD".caseInsensitiveCompare("AbCd"))
        expectEqual(ComparisonResult.orderedAscending,
                    "abCD".caseInsensitiveCompare("AbCdE"))

        expectEqual(ComparisonResult.orderedSame,
                    "абвг".caseInsensitiveCompare("АбВг"))
        expectEqual(ComparisonResult.orderedAscending,
                    "абВГ".caseInsensitiveCompare("АбВгД"))
    }

    func test_commonPrefix() {
        expectEqual("ab",
                    "abcd".commonPrefix(with: "abdc", options: []))
        expectEqual("abC",
                    "abCd".commonPrefix(with: "abce", options: .caseInsensitive))

        expectEqual("аб",
                    "абвг".commonPrefix(with: "абгв", options: []))
        expectEqual("абВ",
                    "абВг".commonPrefix(with: "абвд", options: .caseInsensitive))
    }

    func test_compare() {
        expectEqual(ComparisonResult.orderedSame,
                    "abc".compare("abc"))
        expectEqual(ComparisonResult.orderedAscending,
                    "абв".compare("где"))

        expectEqual(ComparisonResult.orderedSame,
                    "abc".compare("abC", options: .caseInsensitive))
        expectEqual(ComparisonResult.orderedSame,
                    "абв".compare("абВ", options: .caseInsensitive))

        do {
            let s = "abcd"
            let r = s.index(after: s.startIndex)..<s.endIndex
            expectEqual(ComparisonResult.orderedSame,
                        s.compare("bcd", range: r))
        }
        do {
            let s = "абвг"
            let r = s.index(after: s.startIndex)..<s.endIndex
            expectEqual(ComparisonResult.orderedSame,
                        s.compare("бвг", range: r))
        }

        expectEqual(ComparisonResult.orderedSame,
                    "abc".compare("abc", locale: Locale.current))
        expectEqual(ComparisonResult.orderedSame,
                    "абв".compare("абв", locale: Locale.current))
    }

    func test_completePath() {
        withTemporaryStringFile { existingURL, nonExistentURL in
            let existingPath = existingURL.path()
            let nonExistentPath = nonExistentURL.path()
            do {
                let count = nonExistentPath.completePath(caseSensitive: false)
                expectEqual(0, count)
            }

            do {
                var outputName = "None Found"
                let count = nonExistentPath.completePath(
                    into: &outputName, caseSensitive: false)

                expectEqual(0, count)
                expectEqual("None Found", outputName)
            }

            do {
                var outputName = "None Found"
                var outputArray: [String] = ["foo", "bar"]
                let count = nonExistentPath.completePath(
                    into: &outputName, caseSensitive: false, matchesInto: &outputArray)

                expectEqual(0, count)
                expectEqual("None Found", outputName)
                expectEqual(["foo", "bar"], outputArray)
            }

            do {
                let count = existingPath.completePath(caseSensitive: false)
                expectEqual(1, count)
            }

            do {
                var outputName = "None Found"
                let count = existingPath.completePath(
                    into: &outputName, caseSensitive: false)

                expectEqual(1, count)
                expectEqual(existingPath, outputName)
            }

            do {
                var outputName = "None Found"
                var outputArray: [String] = ["foo", "bar"]
                let count = existingPath.completePath(
                    into: &outputName, caseSensitive: false, matchesInto: &outputArray)

                expectEqual(1, count)
                expectEqual(existingPath, outputName)
                expectEqual([existingPath], outputArray)
            }

            do {
                var outputName = "None Found"
                let count = existingPath.completePath(
                    into: &outputName, caseSensitive: false, filterTypes: ["txt"])

                expectEqual(1, count)
                expectEqual(existingPath, outputName)
            }
        }

    }

    func test_components_separatedBy_characterSet() {
        expectEqual([""], "".components(
            separatedBy: CharacterSet.decimalDigits))

        expectEqual(
            ["абв", "", "あいう", "abc"],
            "абв12あいう3abc".components(
                separatedBy: CharacterSet.decimalDigits))

        expectEqual(
            ["абв", "", "あいう", "abc"],
            "абв\u{1F601}\u{1F602}あいう\u{1F603}abc"
                .components(
                    separatedBy: CharacterSet(charactersIn: "\u{1F601}\u{1F602}\u{1F603}")))

        // Performs Unicode scalar comparison.
        expectEqual(
            ["abcし\u{3099}def"],
            "abcし\u{3099}def".components(
                separatedBy: CharacterSet(charactersIn: "\u{3058}")))
    }

    func test_components_separatedBy_string() {
        expectEqual([""], "".components(separatedBy: "//"))

        expectEqual(
            ["абв", "あいう", "abc"],
            "абв//あいう//abc".components(separatedBy: "//"))

        // Performs normalization.
        expectEqual(
            ["abc", "def"],
            "abcし\u{3099}def".components(separatedBy: "\u{3058}"))
    }

    func test_cString() {
        XCTAssertNil("абв".cString(using: .ascii))

        let expectedBytes: [UInt8] = [ 0xd0, 0xb0, 0xd0, 0xb1, 0xd0, 0xb2, 0 ]
        let expectedStr: [CChar] = expectedBytes.map { CChar(bitPattern: $0) }
        expectEqual(expectedStr,
                    "абв".cString(using: .utf8)!)
    }

     func test_data() {
         XCTAssertNil("あいう".data(using: .ascii, allowLossyConversion: false))

         do {
             let data = "あいう".data(using: .utf8)!
             let expectedBytes: [UInt8] = [
                0xe3, 0x81, 0x82, 0xe3, 0x81, 0x84, 0xe3, 0x81, 0x86
             ]

             expectEqualSequence(expectedBytes, data)
         }
     }

    func test_init() {
        let bytes: [UInt8] = [0xe3, 0x81, 0x82, 0xe3, 0x81, 0x84, 0xe3, 0x81, 0x86]
        let data = Data(bytes)

        XCTAssertNil(String(data: data, encoding: .nonLossyASCII))

        XCTAssertEqual(
            "あいう",
            String(data: data, encoding: .utf8)!)
    }

    func test_decomposedStringWithCanonicalMapping() {
        expectEqual("abc", "abc".decomposedStringWithCanonicalMapping)
        expectEqual("\u{305f}\u{3099}くてん", "だくてん".decomposedStringWithCanonicalMapping)
        expectEqual("\u{ff80}\u{ff9e}ｸﾃﾝ", "ﾀﾞｸﾃﾝ".decomposedStringWithCanonicalMapping)
    }

    func test_decomposedStringWithCompatibilityMapping() {
        expectEqual("abc", "abc".decomposedStringWithCompatibilityMapping)
        expectEqual("\u{30bf}\u{3099}クテン", "ﾀﾞｸﾃﾝ".decomposedStringWithCompatibilityMapping)
    }

    func test_enumerateLines() {
        var lines: [String] = []
        "abc\n\ndefghi\njklm".enumerateLines {
            (line: String, stop: inout Bool)
            in
            lines.append(line)
            if lines.count == 3 {
                stop = true
            }
        }
        expectEqual(["abc", "", "defghi"], lines)
    }

    func test_enumerateLinguisticTagsIn() {
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
        expectEqual([
            NSLinguisticTag.word.rawValue,
            NSLinguisticTag.whitespace.rawValue,
            NSLinguisticTag.word.rawValue
        ], tags)
        expectEqual(["Глокая", " ", "куздра"], tokens)
        let sentence = String(s[startIndex..<endIndex])
        expectEqual([sentence, sentence, sentence], sentences)
    }

    func test_enumerateSubstringsIn() {
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
                expectEqual(substring, String(s[substringRange]))
                expectEqual(substring, String(s[enclosingRange]))
            }
            expectEqual(["\u{304b}\u{3099}", "お", "☺️", "😀"], substrings)
        }
        do {
            var substrings: [String] = []
            s.enumerateSubstrings(in: startIndex..<endIndex,
                                  options: [.byComposedCharacterSequences, .substringNotRequired]) {
                (substring_: String?, substringRange: Range<String.Index>,
                 enclosingRange: Range<String.Index>, stop: inout Bool)
                in
                XCTAssertNil(substring_)
                let substring = s[substringRange]
                substrings.append(String(substring))
                expectEqual(substring, s[enclosingRange])
            }
            expectEqual(["\u{304b}\u{3099}", "お", "☺️", "😀"], substrings)
        }
    }

    func test_fastestEncoding() {
        let availableEncodings: [String.Encoding] = String.availableStringEncodings
        expectTrue(availableEncodings.contains("abc".fastestEncoding))
    }

    func test_getBytes() {
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
            expectTrue(result)
            XCTAssertEqual(expectedStr, buffer)
            expectEqual(11, usedLength)
            expectEqual(remainingRange.lowerBound, s.index(startIndex, offsetBy: 8))
            expectEqual(remainingRange.upperBound, endIndex)
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
            expectTrue(result)
            XCTAssertEqual(expectedStr, buffer)
            expectEqual(4, usedLength)
            expectEqual(remainingRange.lowerBound, s.index(startIndex, offsetBy: 4))
            expectEqual(remainingRange.upperBound, endIndex)
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
            expectTrue(result)
            XCTAssertEqual(expectedStr, buffer)
            expectEqual(19, usedLength)
            expectEqual(remainingRange.lowerBound, endIndex)
            expectEqual(remainingRange.upperBound, endIndex)
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
            expectTrue(result)
            XCTAssertEqual(expectedStr, buffer)
            expectEqual(4, usedLength)
            expectEqual(remainingRange.lowerBound, s.index(startIndex, offsetBy: 4))
            expectEqual(remainingRange.upperBound, endIndex)
        }
    }

    func test_getCString() {
        let s = "abc あかさた"
        do {
            // A significantly too small buffer
            let bufferLength = 1
            var buffer = Array(
                repeating: CChar(bitPattern: 0xff), count: bufferLength)
            let result = s.getCString(&buffer, maxLength: 100,
                                      encoding: .utf8)
            expectFalse(result)
            let result2 = s.getCString(&buffer, maxLength: 1,
                                       encoding: .utf8)
            expectFalse(result2)
        }
        do {
            // The largest buffer that cannot accommodate the string plus null terminator.
            let bufferLength = 16
            var buffer = Array(
                repeating: CChar(bitPattern: 0xff), count: bufferLength)
            let result = s.getCString(&buffer, maxLength: 100,
                                      encoding: .utf8)
            expectFalse(result)
            let result2 = s.getCString(&buffer, maxLength: 16,
                                       encoding: .utf8)
            expectFalse(result2)
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
            expectTrue(result)
            XCTAssertEqual(expectedStr, buffer)
            let result2 = s.getCString(&buffer, maxLength: 17,
                                       encoding: .utf8)
            expectTrue(result2)
            XCTAssertEqual(expectedStr, buffer)
        }
        do {
            // Limit buffer size with 'maxLength'.
            let bufferLength = 100
            var buffer = Array(
                repeating: CChar(bitPattern: 0xff), count: bufferLength)
            let result = s.getCString(&buffer, maxLength: 8,
                                      encoding: .utf8)
            expectFalse(result)
        }
        do {
            // String with unpaired surrogates.
            let illFormedUTF16 = NonContiguousNSString([ 0xd800 ]) as String
            let bufferLength = 100
            var buffer = Array(
                repeating: CChar(bitPattern: 0xff), count: bufferLength)
            let result = illFormedUTF16.getCString(&buffer, maxLength: 100,
                                                   encoding: .utf8)
            expectFalse(result)
        }
    }

    func test_getLineStart() {
        let s = "Глокая куздра\nштеко будланула\nбокра и кудрячит\nбокрёнка."
        let r = s.index(s.startIndex, offsetBy: 16)..<s.index(s.startIndex, offsetBy: 35)
        do {
            var outStartIndex = s.startIndex
            var outLineEndIndex = s.startIndex
            var outContentsEndIndex = s.startIndex
            s.getLineStart(&outStartIndex, end: &outLineEndIndex,
                           contentsEnd: &outContentsEndIndex, for: r)
            expectEqual("штеко будланула\nбокра и кудрячит\n",
                        s[outStartIndex..<outLineEndIndex])
            expectEqual("штеко будланула\nбокра и кудрячит",
                        s[outStartIndex..<outContentsEndIndex])
        }
    }

    func test_getParagraphStart() {
        let s = "Глокая куздра\nштеко будланула\u{2028}бокра и кудрячит\u{2028}бокрёнка.\n Абв."
        let r = s.index(s.startIndex, offsetBy: 16)..<s.index(s.startIndex, offsetBy: 35)
        do {
            var outStartIndex = s.startIndex
            var outEndIndex = s.startIndex
            var outContentsEndIndex = s.startIndex
            s.getParagraphStart(&outStartIndex, end: &outEndIndex,
                                contentsEnd: &outContentsEndIndex, for: r)
            expectEqual("штеко будланула\u{2028}бокра и кудрячит\u{2028}бокрёнка.\n",
                        s[outStartIndex..<outEndIndex])
            expectEqual("штеко будланула\u{2028}бокра и кудрячит\u{2028}бокрёнка.",
                        s[outStartIndex..<outContentsEndIndex])
        }
    }

    func test_hash() {
        let s: String = "abc"
        let nsstr: NSString = "abc"
        expectEqual(nsstr.hash, s.hash)
    }

    func test_init_bytes_encoding() {
        var s: String = "abc あかさた"
        expectEqual(
            s, String(bytes: s.utf8, encoding: .utf8))

        /*
         FIXME: Test disabled because the NSString documentation is unclear about
         what should actually happen in this case.

         XCTAssertNil(String(bytes: bytes, length: bytes.count,
         encoding: .ascii))
         */

        // FIXME: add a test where this function actually returns nil.
    }

    @available(*, deprecated)
    func test_init_bytesNoCopy_length_encoding_freeWhenDone() {
        var s: String = "abc あかさた"
        var bytes: [UInt8] = Array(s.utf8)
        expectEqual(s, String(bytesNoCopy: &bytes,
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

    func test_init_utf16CodeUnits_count() {
        let expected = "abc абв \u{0001F60A}"
        let chars: [unichar] = Array(expected.utf16)

        expectEqual(expected, String(utf16CodeUnits: chars, count: chars.count))
    }

    @available(*, deprecated)
    func test_init_utf16CodeUnitsNoCopy() {
        let expected = "abc абв \u{0001F60A}"
        let chars: [unichar] = Array(expected.utf16)

        expectEqual(expected, String(utf16CodeUnitsNoCopy: chars,
                                     count: chars.count, freeWhenDone: false))
    }

    func test_init_format() {
        expectEqual("", String(format: ""))
        expectEqual(
            "abc абв \u{0001F60A}", String(format: "abc абв \u{0001F60A}"))

        let world: NSString = "world"
        expectEqual("Hello, world!%42",
                    String(format: "Hello, %@!%%%ld", world, 42))

        // test for rdar://problem/18317906
        expectEqual("3.12", String(format: "%.2f", 3.123456789))
        expectEqual("3.12", NSString(format: "%.2f", 3.123456789))
    }

    func test_init_format_arguments() {
        expectEqual("", String(format: "", arguments: []))
        expectEqual(
            "abc абв \u{0001F60A}",
            String(format: "abc абв \u{0001F60A}", arguments: []))

        let world: NSString = "world"
        let args: [CVarArg] = [ world, 42 ]
        expectEqual("Hello, world!%42",
                    String(format: "Hello, %@!%%%ld", arguments: args))
    }

    func test_init_format_locale() {
        let world: NSString = "world"
        expectEqual("Hello, world!%42", String(format: "Hello, %@!%%%ld",
                                               locale: nil, world, 42))
    }

    func test_init_format_locale_arguments() {
        let world: NSString = "world"
        let args: [CVarArg] = [ world, 42 ]
        expectEqual("Hello, world!%42", String(format: "Hello, %@!%%%ld",
                                               locale: nil, arguments: args))
    }

    func test_utf16Count() {
        expectEqual(1, "a".utf16.count)
        expectEqual(2, "\u{0001F60A}".utf16.count)
    }

    func test_lengthOfBytesUsingEncoding() {
        expectEqual(1, "a".lengthOfBytes(using: .utf8))
        expectEqual(2, "あ".lengthOfBytes(using: .shiftJIS))
    }

    func test_lineRangeFor() {
        let s = "Глокая куздра\nштеко будланула\nбокра и кудрячит\nбокрёнка."
        let r = s.index(s.startIndex, offsetBy: 16)..<s.index(s.startIndex, offsetBy: 35)
        do {
            let result = s.lineRange(for: r)
            expectEqual("штеко будланула\nбокра и кудрячит\n", s[result])
        }
    }

    func test_linguisticTagsIn() {
        let s: String = "Абв. Глокая куздра штеко будланула бокра и кудрячит бокрёнка. Абв."
        let startIndex = s.index(s.startIndex, offsetBy: 5)
        let endIndex = s.index(s.startIndex, offsetBy: 17)
        var tokenRanges: [Range<String.Index>] = []
        let scheme = NSLinguisticTagScheme.tokenType
        let tags = s.linguisticTags(in: startIndex..<endIndex,
                                    scheme: scheme.rawValue,
                                    options: [],
                                    orthography: nil, tokenRanges: &tokenRanges)
        expectEqual([
            NSLinguisticTag.word.rawValue,
            NSLinguisticTag.whitespace.rawValue,
            NSLinguisticTag.word.rawValue
        ], tags)
        expectEqual(["Глокая", " ", "куздра"],
                    tokenRanges.map { String(s[$0]) } )
    }

    func test_localizedCaseInsensitiveCompare() {
        expectEqual(ComparisonResult.orderedSame,
                    "abCD".localizedCaseInsensitiveCompare("AbCd"))
        expectEqual(ComparisonResult.orderedAscending,
                    "abCD".localizedCaseInsensitiveCompare("AbCdE"))

        expectEqual(ComparisonResult.orderedSame,
                    "абвг".localizedCaseInsensitiveCompare("АбВг"))
        expectEqual(ComparisonResult.orderedAscending,
                    "абВГ".localizedCaseInsensitiveCompare("АбВгД"))
    }

    func test_localizedCompare() {
        expectEqual(ComparisonResult.orderedAscending,
                    "abCD".localizedCompare("AbCd"))

        expectEqual(ComparisonResult.orderedAscending,
                    "абвг".localizedCompare("АбВг"))
    }

    func test_localizedStandardCompare() {
        expectEqual(ComparisonResult.orderedAscending,
                    "abCD".localizedStandardCompare("AbCd"))

        expectEqual(ComparisonResult.orderedAscending,
                    "абвг".localizedStandardCompare("АбВг"))
    }

    func test_localizedLowercase() {
        let en = Locale(identifier: "en")
        let ru = Locale(identifier: "ru")
        if #available(OSX 10.11, iOS 9.0, *) {
            expectEqual("abcd", "abCD".lowercased(with: en))
            expectEqual("абвг", "абВГ".lowercased(with: en))
            expectEqual("абвг", "абВГ".lowercased(with: ru))
            expectEqual("たちつてと", "たちつてと".lowercased(with: ru))

            //
            // Special casing.
            //

            // U+0130 LATIN CAPITAL LETTER I WITH DOT ABOVE
            // to lower case:
            // U+0069 LATIN SMALL LETTER I
            // U+0307 COMBINING DOT ABOVE
            expectEqual("\u{0069}\u{0307}", "\u{0130}".lowercased(with: Locale(identifier: "en")))

            // U+0130 LATIN CAPITAL LETTER I WITH DOT ABOVE
            // to lower case in Turkish locale:
            // U+0069 LATIN SMALL LETTER I
            expectEqual("\u{0069}", "\u{0130}".lowercased(with: Locale(identifier: "tr")))

            // U+0049 LATIN CAPITAL LETTER I
            // U+0307 COMBINING DOT ABOVE
            // to lower case:
            // U+0069 LATIN SMALL LETTER I
            // U+0307 COMBINING DOT ABOVE
            expectEqual("\u{0069}\u{0307}", "\u{0049}\u{0307}".lowercased(with: Locale(identifier: "en")))

            // U+0049 LATIN CAPITAL LETTER I
            // U+0307 COMBINING DOT ABOVE
            // to lower case in Turkish locale:
            // U+0069 LATIN SMALL LETTER I
            expectEqual("\u{0069}", "\u{0049}\u{0307}".lowercased(with: Locale(identifier: "tr")))
        }
    }

    func test_lowercased() {
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

    func test_maximumLengthOfBytesUsingEncoding() {
        do {
            let s = "abc"
            XCTAssertLessThanOrEqual(s.utf8.count,
                                     s.maximumLengthOfBytes(using: .utf8))
        }
        do {
            let s = "abc абв"
            XCTAssertLessThanOrEqual(s.utf8.count,
                                     s.maximumLengthOfBytes(using: .utf8))
        }
        do {
            let s = "\u{1F60A}"
            XCTAssertLessThanOrEqual(s.utf8.count,
                                     s.maximumLengthOfBytes(using: .utf8))
        }
    }

    func test_paragraphRangeFor() {
        let s = "Глокая куздра\nштеко будланула\u{2028}бокра и кудрячит\u{2028}бокрёнка.\n Абв."
        let r = s.index(s.startIndex, offsetBy: 16)..<s.index(s.startIndex, offsetBy: 35)
        do {
            let result = s.paragraphRange(for: r)
            expectEqual("штеко будланула\u{2028}бокра и кудрячит\u{2028}бокрёнка.\n", s[result])
        }
    }

    func test_pathComponents() {
        expectEqual([ "/", "foo", "bar" ] as [NSString], ("/foo/bar" as NSString).pathComponents as [NSString])
        expectEqual([ "/", "абв", "где" ] as [NSString], ("/абв/где" as NSString).pathComponents as [NSString])
    }

    func test_precomposedStringWithCanonicalMapping() {
        expectEqual("abc", "abc".precomposedStringWithCanonicalMapping)
        expectEqual("だくてん",
                    "\u{305f}\u{3099}くてん".precomposedStringWithCanonicalMapping)
        expectEqual("ﾀﾞｸﾃﾝ",
                    "\u{ff80}\u{ff9e}ｸﾃﾝ".precomposedStringWithCanonicalMapping)
        expectEqual("\u{fb03}", "\u{fb03}".precomposedStringWithCanonicalMapping)
    }

    func test_precomposedStringWithCompatibilityMapping() {
        expectEqual("abc", "abc".precomposedStringWithCompatibilityMapping)
        /*
         Test disabled because of:
         <rdar://problem/17041347> NFKD normalization as implemented by
         'precomposedStringWithCompatibilityMapping:' is not idempotent

         expectEqual("\u{30c0}クテン",
         "\u{ff80}\u{ff9e}ｸﾃﾝ".precomposedStringWithCompatibilityMapping)
         */
        expectEqual("ffi", "\u{fb03}".precomposedStringWithCompatibilityMapping)
    }

    func test_propertyList() {
        expectEqual(["foo", "bar"],
                    "(\"foo\", \"bar\")".propertyList() as! [String])
    }

    func test_propertyListFromStringsFileFormat() {
        expectEqual(["foo": "bar", "baz": "baz"],
                    "/* comment */\n\"foo\" = \"bar\";\n\"baz\";"
            .propertyListFromStringsFileFormat() as Dictionary<String, String>)
    }

    func test_rangeOfCharacterFrom() {
        do {
            let charset = CharacterSet(charactersIn: "абв")
            do {
                let s = "Глокая куздра"
                let r = s.rangeOfCharacter(from: charset)!
                expectEqual(s.index(s.startIndex, offsetBy: 4), r.lowerBound)
                expectEqual(s.index(s.startIndex, offsetBy: 5), r.upperBound)
            }
            do {
                XCTAssertNil("клмн".rangeOfCharacter(from: charset))
            }
            do {
                let s = "абвклмнабвклмн"
                let r = s.rangeOfCharacter(from: charset,
                                           options: .backwards)!
                expectEqual(s.index(s.startIndex, offsetBy: 9), r.lowerBound)
                expectEqual(s.index(s.startIndex, offsetBy: 10), r.upperBound)
            }
            do {
                let s = "абвклмнабв"
                let r = s.rangeOfCharacter(from: charset,
                                           range: s.index(s.startIndex, offsetBy: 3)..<s.endIndex)!
                expectEqual(s.index(s.startIndex, offsetBy: 7), r.lowerBound)
                expectEqual(s.index(s.startIndex, offsetBy: 8), r.upperBound)
            }
        }

        do {
            let charset = CharacterSet(charactersIn: "\u{305f}\u{3099}")
            XCTAssertNil("\u{3060}".rangeOfCharacter(from: charset))
        }
        do {
            let charset = CharacterSet(charactersIn: "\u{3060}")
            XCTAssertNil("\u{305f}\u{3099}".rangeOfCharacter(from: charset))
        }

        do {
            let charset = CharacterSet(charactersIn: "\u{1F600}")
            do {
                let s = "abc\u{1F600}"
                expectEqual("\u{1F600}",
                            s[s.rangeOfCharacter(from: charset)!])
            }
            do {
                XCTAssertNil("abc\u{1F601}".rangeOfCharacter(from: charset))
            }
        }
    }

    func test_rangeOfComposedCharacterSequence() {
        let s = "\u{1F601}abc \u{305f}\u{3099} def"
        expectEqual("\u{1F601}", s[s.rangeOfComposedCharacterSequence(
            at: s.startIndex)])
        expectEqual("a", s[s.rangeOfComposedCharacterSequence(
            at: s.index(s.startIndex, offsetBy: 1))])
        expectEqual("\u{305f}\u{3099}", s[s.rangeOfComposedCharacterSequence(
            at: s.index(s.startIndex, offsetBy: 5))])
        expectEqual(" ", s[s.rangeOfComposedCharacterSequence(
            at: s.index(s.startIndex, offsetBy: 6))])
    }

    func test_rangeOfComposedCharacterSequences() {
        let s = "\u{1F601}abc さ\u{3099}し\u{3099}す\u{3099}せ\u{3099}そ\u{3099}"

        expectEqual("\u{1F601}a", s[s.rangeOfComposedCharacterSequences(
            for: s.startIndex..<s.index(s.startIndex, offsetBy: 2))])
        expectEqual("せ\u{3099}そ\u{3099}", s[s.rangeOfComposedCharacterSequences(
            for: s.index(s.startIndex, offsetBy: 8)..<s.index(s.startIndex, offsetBy: 10))])
    }

    func toIntRange<S : StringProtocol>(
        _ string: S, _ maybeRange: Range<String.Index>?
    ) -> Range<Int>? where S.Index == String.Index {
        guard let range = maybeRange else { return nil }

        return string.distance(from: string.startIndex, to: range.lowerBound) ..< string.distance(from: string.startIndex, to: range.upperBound)
    }

    func test_range() {
        do {
            let s = ""
            XCTAssertNil(s.range(of: ""))
            XCTAssertNil(s.range(of: "abc"))
        }
        do {
            let s = "abc"
            XCTAssertNil(s.range(of: ""))
            XCTAssertNil(s.range(of: "def"))
            expectEqual(0..<3, toIntRange(s, s.range(of: "abc")))
        }
        do {
            let s = "さ\u{3099}し\u{3099}す\u{3099}せ\u{3099}そ\u{3099}"
            expectEqual(2..<3, toIntRange(s, s.range(of: "す\u{3099}")))
            expectEqual(2..<3, toIntRange(s, s.range(of: "\u{305a}")))

            XCTAssertNil(s.range(of: "\u{3099}す"))
            XCTAssertNil(s.range(of: "す"))

            XCTAssertNil(s.range(of: "\u{3099}"))
            expectEqual("\u{3099}", s[s.range(of: "\u{3099}", options: .literal)!])
        }
        do {
            let s = "а\u{0301}б\u{0301}в\u{0301}г\u{0301}"
            expectEqual(0..<1, toIntRange(s, s.range(of: "а\u{0301}")))
            expectEqual(1..<2, toIntRange(s, s.range(of: "б\u{0301}")))

            XCTAssertNil(s.range(of: "б"))
            XCTAssertNil(s.range(of: "\u{0301}б"))

            XCTAssertNil(s.range(of: "\u{0301}"))
            expectEqual("\u{0301}", s[s.range(of: "\u{0301}", options: .literal)!])
        }
    }

    func test_contains() {
            expectFalse("".contains(""))
            expectFalse("".contains("a"))
            expectFalse("a".contains(""))
            expectFalse("a".contains("b"))
            expectTrue("a".contains("a"))
            expectFalse("a".contains("A"))
            expectFalse("A".contains("a"))
            expectFalse("a".contains("a\u{0301}"))
            expectTrue("a\u{0301}".contains("a\u{0301}"))
            expectFalse("a\u{0301}".contains("a"))
            expectFalse("a\u{0301}".contains("\u{0301}")) // Update to match stdlib's `firstRange` and `contains` result
            expectFalse("a".contains("\u{0301}"))

            expectFalse("i".contains("I"))
            expectFalse("I".contains("i"))
            expectFalse("\u{0130}".contains("i"))
            expectFalse("i".contains("\u{0130}"))
            expectFalse("\u{0130}".contains("ı"))
    }

    func test_localizedCaseInsensitiveContains() {
        withOverriddenLocaleCurrentLocale("en") { () -> Void in
            expectFalse("".localizedCaseInsensitiveContains(""))
            expectFalse("".localizedCaseInsensitiveContains("a"))
            expectFalse("a".localizedCaseInsensitiveContains(""))
            expectFalse("a".localizedCaseInsensitiveContains("b"))
            expectTrue("a".localizedCaseInsensitiveContains("a"))
            expectTrue("a".localizedCaseInsensitiveContains("A"))
            expectTrue("A".localizedCaseInsensitiveContains("a"))
            expectFalse("a".localizedCaseInsensitiveContains("a\u{0301}"))
            expectTrue("a\u{0301}".localizedCaseInsensitiveContains("a\u{0301}"))
            expectFalse("a\u{0301}".localizedCaseInsensitiveContains("a"))
            expectTrue("a\u{0301}".localizedCaseInsensitiveContains("\u{0301}"))
            expectFalse("a".localizedCaseInsensitiveContains("\u{0301}"))

            expectTrue("i".localizedCaseInsensitiveContains("I"))
            expectTrue("I".localizedCaseInsensitiveContains("i"))
            expectFalse("\u{0130}".localizedCaseInsensitiveContains("i"))
            expectFalse("i".localizedCaseInsensitiveContains("\u{0130}"))

            return ()
        }

        withOverriddenLocaleCurrentLocale("tr") {
            expectFalse("\u{0130}".localizedCaseInsensitiveContains("ı"))
        }
    }

    func test_localizedStandardContains() {
        if #available(OSX 10.11, iOS 9.0, *) {
            withOverriddenLocaleCurrentLocale("en") { () -> Void in
                expectFalse("".localizedStandardContains(""))
                expectFalse("".localizedStandardContains("a"))
                expectFalse("a".localizedStandardContains(""))
                expectFalse("a".localizedStandardContains("b"))
                expectTrue("a".localizedStandardContains("a"))
                expectTrue("a".localizedStandardContains("A"))
                expectTrue("A".localizedStandardContains("a"))
                expectTrue("a".localizedStandardContains("a\u{0301}"))
                expectTrue("a\u{0301}".localizedStandardContains("a\u{0301}"))
                expectTrue("a\u{0301}".localizedStandardContains("a"))
                expectTrue("a\u{0301}".localizedStandardContains("\u{0301}"))
                expectFalse("a".localizedStandardContains("\u{0301}"))

                expectTrue("i".localizedStandardContains("I"))
                expectTrue("I".localizedStandardContains("i"))
                expectTrue("\u{0130}".localizedStandardContains("i"))
                expectTrue("i".localizedStandardContains("\u{0130}"))

                return ()
            }

            withOverriddenLocaleCurrentLocale("tr") {
                expectTrue("\u{0130}".localizedStandardContains("ı"))
            }
        }
    }

    func test_localizedStandardRange() {
        if #available(OSX 10.11, iOS 9.0, *) {
            func rangeOf(_ string: String, _ substring: String) -> Range<Int>? {
                return toIntRange(
                    string, string.localizedStandardRange(of: substring))
            }
            withOverriddenLocaleCurrentLocale("en") { () -> Void in
                XCTAssertNil(rangeOf("", ""))
                XCTAssertNil(rangeOf("", "a"))
                XCTAssertNil(rangeOf("a", ""))
                XCTAssertNil(rangeOf("a", "b"))
                expectEqual(0..<1, rangeOf("a", "a"))
                expectEqual(0..<1, rangeOf("a", "A"))
                expectEqual(0..<1, rangeOf("A", "a"))
                expectEqual(0..<1, rangeOf("a", "a\u{0301}"))
                expectEqual(0..<1, rangeOf("a\u{0301}", "a\u{0301}"))
                expectEqual(0..<1, rangeOf("a\u{0301}", "a"))
                do {
                    // FIXME: Indices that don't correspond to grapheme cluster boundaries.
                    let s = "a\u{0301}"
                    expectEqual(
                        "\u{0301}", s[s.localizedStandardRange(of: "\u{0301}")!])
                }
                XCTAssertNil(rangeOf("a", "\u{0301}"))

                expectEqual(0..<1, rangeOf("i", "I"))
                expectEqual(0..<1, rangeOf("I", "i"))
                expectEqual(0..<1, rangeOf("\u{0130}", "i"))
                expectEqual(0..<1, rangeOf("i", "\u{0130}"))
                return ()
            }

            withOverriddenLocaleCurrentLocale("tr") {
                expectEqual(0..<1, rangeOf("\u{0130}", "ı"))
            }
        }
    }

    func test_smallestEncoding() {
        let availableEncodings: [String.Encoding] = String.availableStringEncodings
        expectTrue(availableEncodings.contains("abc".smallestEncoding))
    }

    func getHomeDir() -> String {
#if os(macOS)
        return String(cString: getpwuid(getuid()).pointee.pw_dir)
#elseif canImport(Darwin)
        // getpwuid() returns null in sandboxed apps under iOS simulator.
        return NSHomeDirectory()
#else
        preconditionFailed("implement")
#endif
    }

    func test_addingPercentEncoding() {
        expectEqual(
            "abcd1234",
            "abcd1234".addingPercentEncoding(withAllowedCharacters: .alphanumerics))
        expectEqual(
            "abcd%20%D0%B0%D0%B1%D0%B2%D0%B3",
            "abcd абвг".addingPercentEncoding(withAllowedCharacters: .alphanumerics))
    }

    func test_appendingFormat() {
        expectEqual("", "".appendingFormat(""))
        expectEqual("a", "a".appendingFormat(""))
        expectEqual(
            "abc абв \u{0001F60A}",
            "abc абв \u{0001F60A}".appendingFormat(""))

        let formatArg: NSString = "привет мир \u{0001F60A}"
        expectEqual(
            "abc абв \u{0001F60A}def привет мир \u{0001F60A} 42",
            "abc абв \u{0001F60A}"
                .appendingFormat("def %@ %ld", formatArg, 42))
    }

    func test_appending() {
        expectEqual("", "".appending(""))
        expectEqual("a", "a".appending(""))
        expectEqual("a", "".appending("a"))
        expectEqual("さ\u{3099}", "さ".appending("\u{3099}"))
    }

    func test_folding() {

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

    func test_padding() {
        expectEqual(
            "abc абв \u{0001F60A}",
            "abc абв \u{0001F60A}".padding(
                toLength: 10, withPad: "XYZ", startingAt: 0))
        expectEqual(
            "abc абв \u{0001F60A}XYZXY",
            "abc абв \u{0001F60A}".padding(
                toLength: 15, withPad: "XYZ", startingAt: 0))
        expectEqual(
            "abc абв \u{0001F60A}YZXYZ",
            "abc абв \u{0001F60A}".padding(
                toLength: 15, withPad: "XYZ", startingAt: 1))
    }

    func test_replacingCharacters() {
        do {
            let empty = ""
            expectEqual("", empty.replacingCharacters(
                in: empty.startIndex..<empty.startIndex, with: ""))
        }

        let s = "\u{1F601}abc さ\u{3099}し\u{3099}す\u{3099}せ\u{3099}そ\u{3099}"

        expectEqual(s, s.replacingCharacters(
            in: s.startIndex..<s.startIndex, with: ""))
        expectEqual(s, s.replacingCharacters(
            in: s.endIndex..<s.endIndex, with: ""))
        expectEqual("zzz" + s, s.replacingCharacters(
            in: s.startIndex..<s.startIndex, with: "zzz"))
        expectEqual(s + "zzz", s.replacingCharacters(
            in: s.endIndex..<s.endIndex, with: "zzz"))

        expectEqual(
            "す\u{3099}せ\u{3099}そ\u{3099}",
            s.replacingCharacters(
                in: s.startIndex..<s.index(s.startIndex, offsetBy: 7), with: ""))
        expectEqual(
            "zzzす\u{3099}せ\u{3099}そ\u{3099}",
            s.replacingCharacters(
                in: s.startIndex..<s.index(s.startIndex, offsetBy: 7), with: "zzz"))
        expectEqual(
            "\u{1F602}す\u{3099}せ\u{3099}そ\u{3099}",
            s.replacingCharacters(
                in: s.startIndex..<s.index(s.startIndex, offsetBy: 7), with: "\u{1F602}"))

        expectEqual("\u{1F601}", s.replacingCharacters(
            in: s.index(after: s.startIndex)..<s.endIndex, with: ""))
        expectEqual("\u{1F601}zzz", s.replacingCharacters(
            in: s.index(after: s.startIndex)..<s.endIndex, with: "zzz"))
        expectEqual("\u{1F601}\u{1F602}", s.replacingCharacters(
            in: s.index(after: s.startIndex)..<s.endIndex, with: "\u{1F602}"))

        expectEqual(
            "\u{1F601}aす\u{3099}せ\u{3099}そ\u{3099}",
            s.replacingCharacters(
                in: s.index(s.startIndex, offsetBy: 2)..<s.index(s.startIndex, offsetBy: 7), with: ""))
        expectEqual(
            "\u{1F601}azzzす\u{3099}せ\u{3099}そ\u{3099}",
            s.replacingCharacters(
                in: s.index(s.startIndex, offsetBy: 2)..<s.index(s.startIndex, offsetBy: 7), with: "zzz"))
        expectEqual(
            "\u{1F601}a\u{1F602}す\u{3099}せ\u{3099}そ\u{3099}",
            s.replacingCharacters(
                in: s.index(s.startIndex, offsetBy: 2)..<s.index(s.startIndex, offsetBy: 7),
                with: "\u{1F602}"))
    }

    func test_replacingOccurrences() {
        do {
            let empty = ""
            expectEqual("", empty.replacingOccurrences(
                of: "", with: ""))
            expectEqual("", empty.replacingOccurrences(
                of: "", with: "xyz"))
            expectEqual("", empty.replacingOccurrences(
                of: "abc", with: "xyz"))
        }

        let s = "\u{1F601}abc さ\u{3099}し\u{3099}す\u{3099}せ\u{3099}そ\u{3099}"

        expectEqual(s, s.replacingOccurrences(of: "", with: "xyz"))
        expectEqual(s, s.replacingOccurrences(of: "xyz", with: ""))

        expectEqual("", s.replacingOccurrences(of: s, with: ""))

        expectEqual(
            "\u{1F601}xyzbc さ\u{3099}し\u{3099}す\u{3099}せ\u{3099}そ\u{3099}",
            s.replacingOccurrences(of: "a", with: "xyz"))

        expectEqual(
            "\u{1F602}\u{1F603}abc さ\u{3099}し\u{3099}す\u{3099}せ\u{3099}そ\u{3099}",
            s.replacingOccurrences(
                of: "\u{1F601}", with: "\u{1F602}\u{1F603}"))

        expectEqual(
            "\u{1F601}abc さ\u{3099}xyzす\u{3099}せ\u{3099}そ\u{3099}",
            s.replacingOccurrences(
                of: "し\u{3099}", with: "xyz"))

        expectEqual(
            "\u{1F601}abc さ\u{3099}xyzす\u{3099}せ\u{3099}そ\u{3099}",
            s.replacingOccurrences(
                of: "し\u{3099}", with: "xyz"))

        expectEqual(
            "\u{1F601}abc さ\u{3099}xyzす\u{3099}せ\u{3099}そ\u{3099}",
            s.replacingOccurrences(
                of: "\u{3058}", with: "xyz"))

        //
        // Use non-default 'options:'
        //

        expectEqual(
            "\u{1F602}\u{1F603}abc さ\u{3099}し\u{3099}す\u{3099}せ\u{3099}そ\u{3099}",
            s.replacingOccurrences(
                of: "\u{1F601}", with: "\u{1F602}\u{1F603}",
                options: String.CompareOptions.literal))

        expectEqual(s, s.replacingOccurrences(
            of: "\u{3058}", with: "xyz",
            options: String.CompareOptions.literal))

        //
        // Use non-default 'range:'
        //

        expectEqual(
            "\u{1F602}\u{1F603}abc さ\u{3099}し\u{3099}す\u{3099}せ\u{3099}そ\u{3099}",
            s.replacingOccurrences(
                of: "\u{1F601}", with: "\u{1F602}\u{1F603}",
                options: String.CompareOptions.literal,
                range: s.startIndex..<s.index(s.startIndex, offsetBy: 1)))

        expectEqual(s, s.replacingOccurrences(
            of: "\u{1F601}", with: "\u{1F602}\u{1F603}",
            options: String.CompareOptions.literal,
            range: s.index(s.startIndex, offsetBy: 1)..<s.index(s.startIndex, offsetBy: 3)))
    }

    func test_removingPercentEncoding() {
        expectEqual(
            "abcd абвг",
            "abcd абвг".removingPercentEncoding)

        expectEqual(
            "abcd абвг\u{0000}\u{0001}",
            "abcd абвг%00%01".removingPercentEncoding)

        expectEqual(
            "abcd абвг",
            "%61%62%63%64%20%D0%B0%D0%B1%D0%B2%D0%B3".removingPercentEncoding)

        expectEqual(
            "abcd абвг",
            "ab%63d %D0%B0%D0%B1%D0%B2%D0%B3".removingPercentEncoding)

        XCTAssertNil("%ED%B0".removingPercentEncoding)

        XCTAssertNil("%zz".removingPercentEncoding)

        XCTAssertNil("abcd%FF".removingPercentEncoding)

        XCTAssertNil("%".removingPercentEncoding)
    }

    func test_removingPercentEncoding_() {
        expectEqual("", "".removingPercentEncoding)
    }

    func test_trimmingCharacters() {
        expectEqual("", "".trimmingCharacters(
            in: CharacterSet.decimalDigits))

        expectEqual("abc", "abc".trimmingCharacters(
            in: CharacterSet.decimalDigits))

        expectEqual("", "123".trimmingCharacters(
            in: CharacterSet.decimalDigits))

        expectEqual("abc", "123abc789".trimmingCharacters(
            in: CharacterSet.decimalDigits))

        // Performs Unicode scalar comparison.
        expectEqual(
            "し\u{3099}abc",
            "し\u{3099}abc".trimmingCharacters(
                in: CharacterSet(charactersIn: "\u{3058}")))
    }

    func test_NSString_stringsByAppendingPaths() {
        expectEqual([] as [NSString], ("" as NSString).strings(byAppendingPaths: []) as [NSString])
        expectEqual(
            [ "/tmp/foo", "/tmp/bar" ] as [NSString],
            ("/tmp" as NSString).strings(byAppendingPaths: [ "foo", "bar" ]) as [NSString])
    }

    @available(*, deprecated)
    func test_substring_from() {
        let s = "\u{1F601}abc さ\u{3099}し\u{3099}す\u{3099}せ\u{3099}そ\u{3099}"

        expectEqual(s, s.substring(from: s.startIndex))
        expectEqual("せ\u{3099}そ\u{3099}",
                    s.substring(from: s.index(s.startIndex, offsetBy: 8)))
        expectEqual("", s.substring(from: s.index(s.startIndex, offsetBy: 10)))
    }

    @available(*, deprecated)
    func test_substring_to() {
        let s = "\u{1F601}abc さ\u{3099}し\u{3099}す\u{3099}せ\u{3099}そ\u{3099}"

        expectEqual("", s.substring(to: s.startIndex))
        expectEqual("\u{1F601}abc さ\u{3099}し\u{3099}す\u{3099}",
                    s.substring(to: s.index(s.startIndex, offsetBy: 8)))
        expectEqual(s, s.substring(to: s.index(s.startIndex, offsetBy: 10)))
    }

    @available(*, deprecated)
    func test_substring_with() {
        let s = "\u{1F601}abc さ\u{3099}し\u{3099}す\u{3099}せ\u{3099}そ\u{3099}"

        expectEqual("", s.substring(with: s.startIndex..<s.startIndex))
        expectEqual(
            "",
            s.substring(with: s.index(s.startIndex, offsetBy: 1)..<s.index(s.startIndex, offsetBy: 1)))
        expectEqual("", s.substring(with: s.endIndex..<s.endIndex))
        expectEqual(s, s.substring(with: s.startIndex..<s.endIndex))
        expectEqual(
            "さ\u{3099}し\u{3099}す\u{3099}",
            s.substring(with: s.index(s.startIndex, offsetBy: 5)..<s.index(s.startIndex, offsetBy: 8)))
    }

    func test_localizedUppercase() {
        if #available(OSX 10.11, iOS 9.0, *) {
            expectEqual("ABCD", "abCD".uppercased(with: Locale(identifier: "en")))

            expectEqual("АБВГ", "абВГ".uppercased(with: Locale(identifier: "en")))

            expectEqual("АБВГ", "абВГ".uppercased(with: Locale(identifier: "ru")))

            expectEqual("たちつてと", "たちつてと".uppercased(with: Locale(identifier: "ru")))

            //
            // Special casing.
            //

            // U+0069 LATIN SMALL LETTER I
            // to upper case:
            // U+0049 LATIN CAPITAL LETTER I
            expectEqual("\u{0049}", "\u{0069}".uppercased(with: Locale(identifier: "en")))

            // U+0069 LATIN SMALL LETTER I
            // to upper case in Turkish locale:
            // U+0130 LATIN CAPITAL LETTER I WITH DOT ABOVE
            expectEqual("\u{0130}", "\u{0069}".uppercased(with: Locale(identifier: "tr")))

            // U+00DF LATIN SMALL LETTER SHARP S
            // to upper case:
            // U+0053 LATIN CAPITAL LETTER S
            // U+0073 LATIN SMALL LETTER S
            // But because the whole string is converted to uppercase, we just get two
            // U+0053.
            expectEqual("\u{0053}\u{0053}", "\u{00df}".uppercased(with: Locale(identifier: "en")))

            // U+FB01 LATIN SMALL LIGATURE FI
            // to upper case:
            // U+0046 LATIN CAPITAL LETTER F
            // U+0069 LATIN SMALL LETTER I
            // But because the whole string is converted to uppercase, we get U+0049
            // LATIN CAPITAL LETTER I.
            expectEqual("\u{0046}\u{0049}", "\u{fb01}".uppercased(with: Locale(identifier: "ru")))
        }
    }

    func test_uppercased() {
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

    func test_write_toFile() {
        withTemporaryStringFile { existingURL, nonExistentURL in
            let nonExistentPath = nonExistentURL.path()
            do {
                let s = "Lorem ipsum dolor sit amet, consectetur adipisicing elit"
                try s.write(
                    toFile: nonExistentPath, atomically: false, encoding: .ascii)

                let content = try String(
                    contentsOfFile: nonExistentPath, encoding: .ascii)

                expectEqual(s, content)
            } catch {

                XCTFail(error.localizedDescription)
            }
        }

    }

    func test_write_to() {
        withTemporaryStringFile { existingURL, nonExistentURL in
            let nonExistentPath = nonExistentURL.path()
            do {
                let s = "Lorem ipsum dolor sit amet, consectetur adipisicing elit"
                try s.write(
                    to: nonExistentURL, atomically: false, encoding: .ascii)

                let content = try String(
                    contentsOfFile: nonExistentPath, encoding: .ascii)

                expectEqual(s, content)
            } catch {
                XCTFail(error.localizedDescription)
            }
        }

    }

    func test_applyingTransform() {
        if #available(OSX 10.11, iOS 9.0, *) {
            do {
                let source = "tre\u{300}s k\u{fc}hl"
                expectEqual(
                    "tres kuhl",
                    source.applyingTransform(.stripDiacritics, reverse: false))
            }
            do {
                let source = "hiragana"
                expectEqual(
                    "ひらがな",
                    source.applyingTransform(.latinToHiragana, reverse: false))
            }
            do {
                let source = "ひらがな"
                expectEqual(
                    "hiragana",
                    source.applyingTransform(.latinToHiragana, reverse: true))
            }
        }
    }

    func test_SameTypeComparisons() {
        // U+0323 COMBINING DOT BELOW
        // U+0307 COMBINING DOT ABOVE
        // U+1E63 LATIN SMALL LETTER S WITH DOT BELOW
        let xs = "\u{1e69}"
        expectTrue(xs == "s\u{323}\u{307}")
        expectFalse(xs != "s\u{323}\u{307}")
        expectTrue("s\u{323}\u{307}" == xs)
        expectFalse("s\u{323}\u{307}" != xs)
        expectTrue("\u{1e69}" == "s\u{323}\u{307}")
        expectFalse("\u{1e69}" != "s\u{323}\u{307}")
        expectTrue(xs == xs)
        expectFalse(xs != xs)
    }

    func test_MixedTypeComparisons() {
        // U+0323 COMBINING DOT BELOW
        // U+0307 COMBINING DOT ABOVE
        // U+1E63 LATIN SMALL LETTER S WITH DOT BELOW
        // NSString does not decompose characters, so the two strings will be (==) in
        // swift but not in Foundation.
        let xs = "\u{1e69}"
        let ys: NSString = "s\u{323}\u{307}"
        expectFalse(ys == "\u{1e69}")
        expectTrue(ys != "\u{1e69}")
        expectFalse("\u{1e69}" == ys)
        expectTrue("\u{1e69}" != ys)
        expectFalse(xs as NSString == ys)
        expectTrue(xs as NSString != ys)
        expectTrue(ys == ys)
        expectFalse(ys != ys)
    }

    func test_copy_construction() {
        let expected = "abcd"
        let x = NSString(string: expected as NSString)
        expectEqual(expected, x as String)
        let y = NSMutableString(string: expected as NSString)
        expectEqual(expected, y as String)
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

final class StdlibSubstringTests: XCTestCase {

    func test_range_of_NilRange() {
        let ss = "aabcdd"[1, -1]
        let range = ss.range(of: "bc")
        expectEqual("bc", range.map { ss[$0] })
    }

    func test_range_of_NonNilRange() {
        let s = "aabcdd"
        let ss = s[1, -1]
        let searchRange = s.range(fromStart: 2, fromEnd: -2)
        let range = ss.range(of: "bc", range: searchRange)
        expectEqual("bc", range.map { ss[$0] })
    }

    func test_rangeOfCharacter() {
        let ss = "__hello__"[2, -2]
        let range = ss.rangeOfCharacter(from: CharacterSet.alphanumerics)
        expectEqual("h", range.map { ss[$0] })
    }

    func test_compare_optionsNilRange() {
        let needle = "hello"
        let haystack = "__hello__"[2, -2]
        expectEqual(.orderedSame, haystack.compare(needle))
    }

    func test_compare_optionsNonNilRange() {
        let needle = "hello"
        let haystack = "__hello__"
        let range = haystack.range(fromStart: 2, fromEnd: -2)
        expectEqual(.orderedSame, haystack[range].compare(needle, range: range))
    }

    func test_replacingCharacters() {
        let s = "__hello, world"
        let range = s.range(fromStart: 2, fromEnd: -7)
        let expected = "__goodbye, world"
        let replacement = "goodbye"
        expectEqual(expected,
                    s.replacingCharacters(in: range, with: replacement))
        expectEqual(expected[2, 0],
                    s[2, 0].replacingCharacters(in: range, with: replacement))

        expectEqual(replacement,
                    s.replacingCharacters(in: s.startIndex..., with: replacement))
        expectEqual(replacement,
                    s.replacingCharacters(in: ..<s.endIndex, with: replacement))
        expectEqual(expected[2, 0],
                    s[2, 0].replacingCharacters(in: range, with: replacement[...]))
    }

    func test_replacingOccurrences_NilRange() {
        let s = "hello"

        expectEqual("he11o", s.replacingOccurrences(of: "l", with: "1"))
        expectEqual("he11o", s.replacingOccurrences(of: "l"[...], with: "1"))
        expectEqual("he11o", s.replacingOccurrences(of: "l", with: "1"[...]))
        expectEqual("he11o", s.replacingOccurrences(of: "l"[...], with: "1"[...]))

        expectEqual("he11o",
                    s[...].replacingOccurrences(of: "l", with: "1"))
        expectEqual("he11o",
                    s[...].replacingOccurrences(of: "l"[...], with: "1"))
        expectEqual("he11o",
                    s[...].replacingOccurrences(of: "l", with: "1"[...]))
        expectEqual("he11o",
                    s[...].replacingOccurrences(of: "l"[...], with: "1"[...]))
    }

    func test_replacingOccurrences_NonNilRange() {
        let s = "hello"
        let r = s.range(fromStart: 1, fromEnd: -2)

        expectEqual("he1lo",
                    s.replacingOccurrences(of: "l", with: "1", range: r))
        expectEqual("he1lo",
                    s.replacingOccurrences(of: "l"[...], with: "1", range: r))
        expectEqual("he1lo",
                    s.replacingOccurrences(of: "l", with: "1"[...], range: r))
        expectEqual("he1lo",
                    s.replacingOccurrences(of: "l"[...], with: "1"[...], range: r))

        expectEqual("he1lo",
                    s[...].replacingOccurrences(of: "l", with: "1", range: r))
        expectEqual("he1lo",
                    s[...].replacingOccurrences(of: "l"[...], with: "1", range: r))
        expectEqual("he1lo",
                    s[...].replacingOccurrences(of: "l", with: "1"[...], range: r))
        expectEqual("he1lo",
                    s[...].replacingOccurrences(of: "l"[...], with: "1"[...], range: r))

        let ss = s[1, -1]
        expectEqual("e1l",
                    ss.replacingOccurrences(of: "l", with: "1", range: r))
        expectEqual("e1l",
                    ss.replacingOccurrences(of: "l"[...], with: "1", range: r))
        expectEqual("e1l",
                    ss.replacingOccurrences(of: "l", with: "1"[...], range: r))
        expectEqual("e1l",
                    ss.replacingOccurrences(of: "l"[...], with: "1"[...], range: r))
    }

    @available(*, deprecated)
    func test_substring() {
        let s = "hello, world"
        let r = s.range(fromStart: 7, fromEnd: 0)
        expectEqual("world", s.substring(with: r))
        expectEqual("world", s[...].substring(with: r))
        expectEqual("world", s[1, 0].substring(with: r))
    }
}
#endif // FOUNDATION_FRAMEWORK
