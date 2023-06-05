// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// RUN: %target-run-simple-swift
// REQUIRES: executable_test
// REQUIRES: objc_interop

#if canImport(TestSupport)
import TestSupport
#endif

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
final class ByteCountFormatStyleTests : XCTestCase {
    let locales = [Locale(identifier: "en_US"), .init(identifier: "fr_FR"), .init(identifier: "zh_TW"), .init(identifier: "zh_CN"), .init(identifier: "ar")]

    func test_zeroSpelledOutKb() {
        let localizedZerosSpelledOutKb: [Locale: String] = [
            Locale(identifier: "en_US"): "Zero kB",
            Locale(identifier: "fr_FR"): "Zéro ko",
            Locale(identifier: "zh_TW"): "0 kB",
            Locale(identifier: "zh_CN"): "0 kB",
            Locale(identifier: "ar"): "صفر كيلوبايت",
        ]

        for locale in locales {
            XCTAssertEqual(0.formatted(.byteCount(style: .memory, spellsOutZero: true).locale(locale)), localizedZerosSpelledOutKb[locale], "locale: \(locale.identifier) failed expectation" )
        }
    }

    func test_zeroSpelledOutBytes() {
        let localizedZerosSpelledOutBytes: [Locale: String] = [
            Locale(identifier: "en_US"): "Zero bytes",
            Locale(identifier: "fr_FR"): "Zéro octet",
            Locale(identifier: "zh_TW"): "0 byte",
            Locale(identifier: "zh_CN"): "0字节",
            Locale(identifier: "ar"): "صفر بايت",
        ]

        for locale in locales {
            XCTAssertEqual(0.formatted(.byteCount(style: .memory, allowedUnits: .bytes, spellsOutZero: true).locale(locale)), localizedZerosSpelledOutBytes[locale], "locale: \(locale.identifier) failed expectation")
        }
    }

    let localizedSingular: [Locale: [String]] = [
        Locale(identifier: "en_US"): [
        "1 byte",
        "1 kB",
        "1 MB",
        "1 GB",
        "1 TB",
        "1 PB",
        ],
        Locale(identifier: "fr_FR"): [
        "1 octet",
        "1 ko",
        "1 Mo",
        "1 Go",
        "1 To",
        "1 Po",
        ],
        Locale(identifier: "zh_TW"): [
        "1 byte",
        "1 kB",
        "1 MB",
        "1 GB",
        "1 TB",
        "1 PB",
        ],
        Locale(identifier: "zh_CN"): [
        "1 byte",
        "1 kB",
        "1 MB",
        "1 GB",
        "1 TB",
        "1 PB",
        ],
        Locale(identifier: "ar"): [
        "١ بايت",
        "١ كيلوبايت",
        "١ ميغابايت",
        "١ غيغابايت",
        "١ تيرابايت",
        "١ بيتابايت",
        ]
    ]

#if FIXED_86386674
    func test_singularUnitsBinary() {
        for locale in locales {
            for i in 0...5 {
                let value: Int64 = (1 << (i*10))
                XCTAssertEqual((value).formatted(.byteCount(style: .memory).locale(locale)), localizedSingular[locale]![i])
            }
        }
    }
#endif

#if FIXED_86386684
    func test_singularUnitsDecimal() {
        for locale in locales {
            for i in 0...5 {
                XCTAssertEqual(Int64(pow(10.0, Double(i*3))).formatted(.byteCount(style: .file).locale(locale)), localizedSingular[locale]![i])
            }
        }
    }
#endif

    func test_localizedParens() {
        XCTAssertEqual(1024.formatted(.byteCount(style: ByteCountFormatStyle.Style.binary, includesActualByteCount: true).locale(.init(identifier: "zh_TW"))), "1 kB（1,024 byte）")
        XCTAssertEqual(1024.formatted(.byteCount(style: ByteCountFormatStyle.Style.binary, includesActualByteCount: true).locale(.init(identifier: "en_US"))), "1 kB (1,024 bytes)")
    }

    func testActualByteCount() {
        XCTAssertEqual(1024.formatted(.byteCount(style: ByteCountFormatStyle.Style.file, includesActualByteCount: true)), "1 kB (1,024 bytes)")
    }

    func test_RTL() {
        XCTAssertEqual(1024.formatted(.byteCount(style: ByteCountFormatStyle.Style.binary, includesActualByteCount: true).locale(.init(identifier: "ar"))), "١ كيلوبايت (١٬٠٢٤ بايت)")
    }

    func testAttributed() {
        var expected: [Segment]

        // Zero kB
        expected = [
            .init(string: "Zero", number: nil, symbol: nil, byteCount: .spelledOutValue),
            .space,
            .init(string: "kB", number: nil, symbol: nil, byteCount: .unit(.kb))]
        XCTAssertEqual(0.formatted(.byteCount(style: .file, spellsOutZero: true).attributed), expected.attributedString)

        // 1 byte
        expected = [
            .init(string: "1", number: .integer, symbol: nil, byteCount: .value),
            .space,
            .init(string: "byte", number: nil, symbol: nil, byteCount: .unit(.byte))]
        XCTAssertEqual(1.formatted(.byteCount(style: .file).attributed), expected.attributedString)

        // 1,000 bytes
        expected = [
            .init(string: "1", number: .integer, symbol: nil, byteCount: .value),
            .init(string: ",", number: .integer, symbol: .groupingSeparator, byteCount: .value),
            .init(string: "000", number: .integer, symbol: nil, byteCount: .value),
            .space,
            .init(string: "bytes", number: nil, symbol: nil, byteCount: .unit(.byte))]
        XCTAssertEqual(1000.formatted(.byteCount(style: .memory).attributed), expected.attributedString)

        // 1,016 kB
        expected = [
            .init(string: "1", number: .integer, symbol: nil, byteCount: .value),
            .init(string: ",", number: .integer, symbol: .groupingSeparator, byteCount: .value),
            .init(string: "016", number: .integer, symbol: nil, byteCount: .value),
            .space,
            .init(string: "kB", number: nil, symbol: nil, byteCount: .unit(.kb))]
        XCTAssertEqual(1_040_000.formatted(.byteCount(style: .memory).attributed), expected.attributedString)

        // 1.1 MB
        expected = [
            .init(string: "1", number: .integer, symbol: nil, byteCount: .value),
            .init(string: ".", number: nil, symbol: .decimalSeparator, byteCount: .value),
            .init(string: "1", number: .fraction, symbol: nil, byteCount: .value),
            .space,
            .init(string: "MB", number: nil, symbol: nil, byteCount: .unit(.mb))]
        XCTAssertEqual(1_100_000.formatted(.byteCount(style: .file).attributed), expected.attributedString)

        // 4.2 GB (4,200,000 bytes)
        expected = [
            .init(string: "4", number: .integer, symbol: nil, byteCount: .value),
            .init(string: ".", number: nil, symbol: .decimalSeparator, byteCount: .value),
            .init(string: "2", number: .fraction, symbol: nil, byteCount: .value),
            .space,
            .init(string: "GB", number: nil, symbol: nil, byteCount: .unit(.gb)),
            .space,
            .openParen,
            .init(string: "4", number: .integer, symbol: nil, byteCount: .actualByteCount),
            .init(string: ",", number: .integer, symbol: .groupingSeparator, byteCount: .actualByteCount),
            .init(string: "200", number: .integer, symbol: nil, byteCount: .actualByteCount),
            .init(string: ",", number: .integer, symbol: .groupingSeparator, byteCount: .actualByteCount),
            .init(string: "000", number: .integer, symbol: nil, byteCount: .actualByteCount),
            .init(string: ",", number: .integer, symbol: .groupingSeparator, byteCount: .actualByteCount),
            .init(string: "000", number: .integer, symbol: nil, byteCount: .actualByteCount),
            .space,
            .init(string: "bytes", number: nil, symbol: nil, byteCount: .unit(.byte)),
            .closedParen]
        XCTAssertEqual(Int64(4_200_000_000).formatted(.byteCount(style: .file, includesActualByteCount: true).attributed), expected.attributedString)
    }

#if !os(watchOS)
    func testEveryAllowedUnit() {
        // 84270854: The largest unit supported currently is pb
        let expectations: [ByteCountFormatStyle.Units: String] = [
            .bytes: "10,000,000,000,000,000 bytes",
            .kb: "10,000,000,000,000 kB",
            .mb: "10,000,000,000 MB",
            .gb: "10,000,000 GB",
            .tb: "10,000 TB",
            .pb: "10 PB",
            .eb: "10 PB",
            .zb: "10 PB",
            .ybOrHigher: "10 PB"
        ]

        for (units, expectation) in expectations {
            XCTAssertEqual(10_000_000_000_000_000.formatted(.byteCount(style: .file, allowedUnits: units).locale(Locale(identifier: "en_US"))), expectation)
        }
    }
#endif
}

fileprivate struct Segment {
    let string: String
    let number: AttributeScopes.FoundationAttributes.NumberFormatAttributes.NumberPartAttribute.NumberPart?
    let symbol: AttributeScopes.FoundationAttributes.NumberFormatAttributes.SymbolAttribute.Symbol?
    let byteCount: AttributeScopes.FoundationAttributes.ByteCountAttribute.Component?

    static var space: Self {
        return .init(string: " ", number: nil, symbol: nil, byteCount: nil)
    }

    static var openParen: Self {
        return .init(string: "(", number: nil, symbol: nil, byteCount: nil)
    }

    static var closedParen: Self {
        return .init(string: ")", number: nil, symbol: nil, byteCount: nil)
    }

}

extension Sequence where Element == Segment {
    var attributedString: AttributedString {
        self.map { segment in
            var attributed = AttributedString(segment.string)

            if let symbol = segment.symbol {
                attributed.numberSymbol = symbol
            }
            if let number = segment.number {
                attributed.numberPart = number
            }
            if let byteCount = segment.byteCount {
                attributed.byteCount = byteCount
            }

            return attributed
        }.reduce(AttributedString(), +)
    }
}
