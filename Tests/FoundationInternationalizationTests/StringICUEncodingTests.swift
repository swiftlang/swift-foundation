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

import Testing

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable import FoundationEssentials
@testable import FoundationInternationalization
#endif // FOUNDATION_FRAMEWORK

@Suite("String (ICU Encoding)")
private struct StringICUEncodingTests {
    private func _test_roundTripConversion(
        string: String,
        data: Data,
        encoding: String.Encoding,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(
            string.data(using: encoding) == data, "Failed to convert string to data.",
            sourceLocation: sourceLocation
        )
        #expect(
            string == String(data: data, encoding: encoding), "Failed to convert data to string.",
            sourceLocation: sourceLocation
        )
    }

    @Test func japaneseEUC() {
        // Confirm that https://github.com/swiftlang/swift-foundation/issues/1016 is fixed.

        // ASCII
        _test_roundTripConversion(
            string: "ABC",
            data: Data([0x41, 0x42, 0x43]),
            encoding: .japaneseEUC
        )

        // Plane 1 Row 1
        _test_roundTripConversion(
            string: "、。◇",
            data: Data([
                0xA1, 0xA2,
                0xA1, 0xA3,
                0xA1, 0xFE,
            ]),
            encoding: .japaneseEUC
        )

        // Plane 1 Row 4 (Hiragana)
        _test_roundTripConversion(
            string: "ひらがな",
            data:  Data([
                0xA4, 0xD2,
                0xA4, 0xE9,
                0xA4, 0xAC,
                0xA4, 0xCA,
            ]),
            encoding: .japaneseEUC
        )

        // Plane 1 Row 5 (Katakana)
        _test_roundTripConversion(
            string: "ヴヵヶ",
            data: Data([
                0xA5, 0xF4,
                0xA5, 0xF5,
                0xA5, 0xF6,
            ]),
            encoding: .japaneseEUC
        )

        // Plane 1 Row 6 (Greek Alphabets)
        _test_roundTripConversion(
            string: "Σπ",
            data: Data([
                0xA6, 0xB2,
                0xA6, 0xD0,
            ]),
            encoding: .japaneseEUC
        )

        // Basic Kanji
        _test_roundTripConversion(
            string: "日本",
            data: Data([
                0xC6, 0xFC,
                0xCB, 0xDC,
            ]),
            encoding: .japaneseEUC
        )

        // Amendment by JIS83/JIS90
        _test_roundTripConversion(
            string: "扉⇔穴",
            data: Data([
                0xC8, 0xE2,
                0xA2, 0xCE,
                0xB7, 0xEA,
            ]),
            encoding: .japaneseEUC
        )

        // Unsupported characters
        let onsen = "Onsen♨" // BMP emoji
        let sushi = "Sushi🍣" // non-BMP emoji
        #expect(onsen.data(using: .japaneseEUC) == nil)
        #expect(sushi.data(using: .japaneseEUC) == nil)
        #expect(
            onsen.data(using: .japaneseEUC, allowLossyConversion: true) ==
            "Onsen?".data(using: .utf8)
        )
        #if FOUNDATION_FRAMEWORK
        // NOTE: Foundation framework replaces an unsupported non-BMP character
        //       with "??"(two question marks).
        #expect(
            sushi.data(using: .japaneseEUC, allowLossyConversion: true) ==
            "Sushi??".data(using: .utf8)
        )
        #else
        #expect(
            sushi.data(using: .japaneseEUC, allowLossyConversion: true) ==
            "Sushi?".data(using: .utf8)
        )
        #endif
    }
}


@Suite("ICU.StringConverter lossy decoding")
private struct ICUStringConverterLossyDecodeTests {
    private func converter(_ encoding: String.Encoding, sourceLocation: SourceLocation = #_sourceLocation) throws -> ICU.StringConverter {
        try #require(ICU.StringConverter(encoding: encoding), sourceLocation: sourceLocation)
    }

    private func lossyDecode(_ converter: ICU.StringConverter, _ bytes: [UInt8], substitution: String = "\u{FFFD}") -> (string: String, invalidByteCount: Int)? {
        let data = Data(bytes)
        return converter.lossyDecode(bytes: data.bytes, substitution: substitution)
    }

    @Test func validData() throws {
        let result = lossyDecode(try converter(.japaneseEUC), [0xA4, 0xD2, 0xA4, 0xE9, 0x41])
        #expect(result?.string == "ひらA")
        #expect(result?.invalidByteCount == 0)
    }

    @Test func oneSubstitutionForEachBadByte() throws {
        let utf8 = lossyDecode(try converter(.utf8), [0x41, 0xFF, 0x42])
        #expect(utf8?.string == "A\u{FFFD}B")
        #expect(utf8?.invalidByteCount == 1)

        // A lead byte followed by a byte that is not a valid trail byte.
        let eucJP = lossyDecode(try converter(.japaneseEUC), [0x41, 0xA4, 0xFF])
        #expect(eucJP?.string == "A\u{FFFD}\u{FFFD}")
        #expect(eucJP?.invalidByteCount == 2)

        // A lead byte at the end of the data.
        let shiftJIS = lossyDecode(try converter(.shiftJIS), [0x82, 0xA0, 0x82])
        #expect(shiftJIS?.string == "あ\u{FFFD}")
        #expect(shiftJIS?.invalidByteCount == 1)
    }

    @Test func substitutionString() throws {
        let converter = try converter(.utf8)
        #expect(lossyDecode(converter, [0x41, 0xFF, 0x42], substitution: "<?>")?.string == "A<?>B")
        let empty = lossyDecode(converter, [0x41, 0xFF, 0x42], substitution: "")
        #expect(empty?.string == "AB")
        #expect(empty?.invalidByteCount == 1)
    }

    @Test func emptyData() throws {
        let result = lossyDecode(try converter(.utf8), [])
        #expect(result?.string == "")
        #expect(result?.invalidByteCount == 0)
    }

    @Test func dataLongerThanOneChunk() throws {
        // More output than one 1024-UChar chunk, with bad bytes on both sides of the chunk boundary.
        var bytes = [UInt8](repeating: UInt8(ascii: "a"), count: 3000)
        bytes[10] = 0xFF
        bytes[2990] = 0xFF
        var expected = bytes
        expected[10] = UInt8(ascii: "?")
        expected[2990] = UInt8(ascii: "?")
        let result = lossyDecode(try converter(.utf8), bytes, substitution: "?")
        #expect(result?.string == String(decoding: expected, as: UTF8.self))
        #expect(result?.invalidByteCount == 2)
    }

    @Test func maxInvalidByteCount() throws {
        let converter = try converter(.utf8)
        let atLimit = converter.lossyDecode(bytes: Data([0x41, 0xFF, 0x42]).bytes, substitution: "?", maxInvalidByteCount: 1)
        #expect(atLimit?.string == "A?B")
        #expect(atLimit?.invalidByteCount == 1)
        #expect(converter.lossyDecode(bytes: Data([0x41, 0xFF, 0x42, 0xFF]).bytes, substitution: "?", maxInvalidByteCount: 1) == nil)
        // The converter is reset after a conversion that stopped early.
        #expect(lossyDecode(converter, [0x43, 0xFF], substitution: "?")?.string == "C?")
    }

    @Test func converterIsUnchangedAfterLossyDecode() throws {
        // The lossy decode must put back the converter's own callback, because converters are shared.
        let converter = try converter(.utf8)
        let data = Data([0x41, 0xFF, 0x42])
        let before = converter.decode(data: data)
        _ = lossyDecode(converter, [0x41, 0xFF, 0x42], substitution: "<?>")
        #expect(converter.decode(data: data) == before)
        #expect(lossyDecode(converter, [0xFF], substitution: "?")?.invalidByteCount == 1)
    }
}
