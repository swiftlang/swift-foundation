// Copyright (c) 2014 - 2021 Apple Inc. and the Swift project authors
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

final class NumberFormatStyleICUSkeletonTests: XCTestCase {

    func testNumberConfigurationSkeleton() throws {
        typealias Configuration = NumberFormatStyleConfiguration.Collection
        XCTAssertEqual(Configuration().skeleton, "")
    }

    func testPrecisionSkeleton() throws {
        typealias Precision = NumberFormatStyleConfiguration.Precision

        XCTAssertEqual(Precision.significantDigits(3...3).skeleton, "@@@")
        XCTAssertEqual(Precision.significantDigits(2...).skeleton, "@@+")
        XCTAssertEqual(Precision.significantDigits(...4).skeleton, "@###")
        XCTAssertEqual(Precision.significantDigits(3...4).skeleton, "@@@#")

        // Invalid configuration. We'll force at least one significant digits.
        XCTAssertEqual(Precision.significantDigits(0...0).skeleton, "@")
        XCTAssertEqual(Precision.significantDigits(...0).skeleton, "@")

        XCTAssertEqual(Precision.fractionLength(...0).skeleton, "precision-integer")
        XCTAssertEqual(Precision.fractionLength(0...0).skeleton, "precision-integer")
        XCTAssertEqual(Precision.fractionLength(3...3).skeleton, ".000")
        XCTAssertEqual(Precision.fractionLength(1...).skeleton, ".0+")
        XCTAssertEqual(Precision.fractionLength(...1).skeleton, ".#")
        XCTAssertEqual(Precision.fractionLength(1...3).skeleton, ".0##")

        XCTAssertEqual(Precision.integerLength(0...).skeleton, "integer-width/+")
        XCTAssertEqual(Precision.integerLength(1...).skeleton, "integer-width/+0")
        XCTAssertEqual(Precision.integerLength(3...).skeleton, "integer-width/+000")
        XCTAssertEqual(Precision.integerLength(1...3).skeleton, "integer-width/##0")
        XCTAssertEqual(Precision.integerLength(2...2).skeleton, "integer-width/00")
        XCTAssertEqual(Precision.integerLength(...3).skeleton, "integer-width/###")

        // Special case
        XCTAssertEqual(Precision.integerLength(...0).skeleton, "integer-width/*")
    }

    func testSignDisplaySkeleton() throws {
        typealias SignDisplay = NumberFormatStyleConfiguration.SignDisplayStrategy
        XCTAssertEqual(SignDisplay.never.skeleton, "sign-never")
        XCTAssertEqual(SignDisplay.always().skeleton, "sign-always")
        XCTAssertEqual(SignDisplay.always(includingZero: true).skeleton, "sign-always")
        XCTAssertEqual(SignDisplay.always(includingZero: false).skeleton, "sign-except-zero")
        XCTAssertEqual(SignDisplay.automatic.skeleton, "sign-auto")
    }

    func testCurrencySkeleton() throws {
        typealias SignDisplay = CurrencyFormatStyleConfiguration.SignDisplayStrategy
        XCTAssertEqual(SignDisplay.automatic.skeleton, "sign-auto")
        XCTAssertEqual(SignDisplay.always().skeleton, "sign-always")
        XCTAssertEqual(SignDisplay.always(showZero: true).skeleton, "sign-always")
        XCTAssertEqual(SignDisplay.always(showZero: false).skeleton, "sign-except-zero")
        XCTAssertEqual(SignDisplay.accounting.skeleton, "sign-accounting")
        XCTAssertEqual(SignDisplay.accountingAlways().skeleton, "sign-accounting-except-zero")
        XCTAssertEqual(SignDisplay.accountingAlways(showZero: true).skeleton, "sign-accounting-always")
        XCTAssertEqual(SignDisplay.accountingAlways(showZero: false).skeleton, "sign-accounting-except-zero")
        XCTAssertEqual(SignDisplay.never.skeleton, "sign-never")

        let style: IntegerFormatStyle<Int>.Currency = .init(code: "USD", locale: Locale(identifier: "en_US"))
        let formatter = ICUCurrencyNumberFormatter.create(for: style)!
        XCTAssertEqual(formatter.skeleton, "currency/USD unit-width-short")

        let accountingStyle = style.sign(strategy: .accounting)
        let accountingFormatter = ICUCurrencyNumberFormatter.create(for: accountingStyle)!
        XCTAssertEqual(accountingFormatter.skeleton, "currency/USD unit-width-short sign-accounting")

        let isoCodeStyle = style.sign(strategy: .never).presentation(.isoCode)
        let isoCodeFormatter = ICUCurrencyNumberFormatter.create(for: isoCodeStyle)!
        XCTAssertEqual(isoCodeFormatter.skeleton, "currency/USD unit-width-iso-code sign-never")
    }

    func testStyleSkeleton_integer_precisionAndRounding() throws {
        let style: IntegerFormatStyle<Int> = .init(locale: Locale(identifier: "en_US"))
        XCTAssertEqual(style.precision(.fractionLength(3...3)).rounded(increment: 5).collection.skeleton, "precision-increment/5.000 rounding-mode-half-even")
        XCTAssertEqual(style.precision(.fractionLength(3...)).rounded(increment: 5).collection.skeleton, "precision-increment/5.000 rounding-mode-half-even")
        XCTAssertEqual(style.precision(.fractionLength(...3)).rounded(increment: 5).collection.skeleton, "precision-increment/5 rounding-mode-half-even")

        XCTAssertEqual(style.precision(.integerLength(2...2)).rounded(increment: 5).collection.skeleton, "precision-increment/5 integer-width/00 rounding-mode-half-even")
        XCTAssertEqual(style.precision(.integerLength(2...)).rounded(increment: 5).collection.skeleton, "precision-increment/5 integer-width/+00 rounding-mode-half-even")
        XCTAssertEqual(style.precision(.integerLength(...2)).rounded(increment: 5).collection.skeleton, "precision-increment/5 integer-width/## rounding-mode-half-even")

        XCTAssertEqual(style.precision(.integerAndFractionLength(integerLimits: 2...2, fractionLimits: 3...3)).rounded(increment: 5).collection.skeleton, "precision-increment/5.000 integer-width/00 rounding-mode-half-even")
    }

    func testStyleSkeleton_floatingPoint_precisionAndRounding() throws {
        let style: FloatingPointFormatStyle<Double> = .init(locale: Locale(identifier: "en_US"))
        XCTAssertEqual(style.precision(.fractionLength(3...3)).rounded(increment: 0.314).collection.skeleton, "precision-increment/0.314 rounding-mode-half-even")
        XCTAssertEqual(style.precision(.fractionLength(3...)).rounded(increment: 0.314).collection.skeleton, "precision-increment/0.314 rounding-mode-half-even")
        XCTAssertEqual(style.precision(.fractionLength(...3)).rounded(increment: 0.314).collection.skeleton, "precision-increment/0.314 rounding-mode-half-even")
        XCTAssertEqual(style.precision(.fractionLength(...1)).rounded(increment: 0.314).collection.skeleton, "precision-increment/0.314 rounding-mode-half-even")

        XCTAssertEqual(style.precision(.fractionLength(3...3)).rounded(increment: 0.3).collection.skeleton, "precision-increment/0.300 rounding-mode-half-even")
        XCTAssertEqual(style.precision(.fractionLength(3...)).rounded(increment: 0.3).collection.skeleton, "precision-increment/0.300 rounding-mode-half-even")

        XCTAssertEqual(style.precision(.integerLength(2...2)).rounded(increment: 0.314).collection.skeleton, "precision-increment/0.314 integer-width/00 rounding-mode-half-even")
        XCTAssertEqual(style.precision(.integerLength(2...)).rounded(increment: 0.314).collection.skeleton, "precision-increment/0.314 integer-width/+00 rounding-mode-half-even")
        XCTAssertEqual(style.precision(.integerLength(...2)).rounded(increment: 0.314).collection.skeleton, "precision-increment/0.314 integer-width/## rounding-mode-half-even")

        XCTAssertEqual(style.precision(.integerAndFractionLength(integerLimits: 2...2, fractionLimits: 3...3)).rounded(increment: 0.314).collection.skeleton, "precision-increment/0.314 integer-width/00 rounding-mode-half-even")
        XCTAssertEqual(style.precision(.integerAndFractionLength(integerLimits: 2..., fractionLimits: 3...3)).rounded(increment: 0.314).collection.skeleton, "precision-increment/0.314 integer-width/+00 rounding-mode-half-even")
        XCTAssertEqual(style.precision(.integerAndFractionLength(integerLimits: ...2, fractionLimits: 3...3)).rounded(increment: 0.314).collection.skeleton, "precision-increment/0.314 integer-width/## rounding-mode-half-even")

        XCTAssertEqual(style.precision(.integerAndFractionLength(integerLimits: 2...2, fractionLimits: 3...3)).rounded(increment: 0.3).collection.skeleton, "precision-increment/0.300 integer-width/00 rounding-mode-half-even")
        XCTAssertEqual(style.precision(.integerAndFractionLength(integerLimits: 2..., fractionLimits: 3...3)).rounded(increment: 0.3).collection.skeleton, "precision-increment/0.300 integer-width/+00 rounding-mode-half-even")
        XCTAssertEqual(style.precision(.integerAndFractionLength(integerLimits: ...2, fractionLimits: 3...3)).rounded(increment: 0.3).collection.skeleton, "precision-increment/0.300 integer-width/## rounding-mode-half-even")
    }
}
