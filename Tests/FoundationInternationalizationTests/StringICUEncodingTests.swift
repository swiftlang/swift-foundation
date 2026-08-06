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

