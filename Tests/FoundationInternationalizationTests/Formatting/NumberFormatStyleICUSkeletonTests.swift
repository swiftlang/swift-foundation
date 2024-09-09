// Copyright (c) 2014 - 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing

#if canImport(FoundationInternationalization)
@testable import FoundationEssentials
@testable import FoundationInternationalization
#elseif FOUNDATION_FRAMEWORK
@testable import Foundation
#endif

struct NumberFormatStyleICUSkeletonTests {

    @Test func testNumberConfigurationSkeleton() throws {
        typealias Configuration = NumberFormatStyleConfiguration.Collection
        #expect(Configuration().skeleton == "")
    }

    @Test func testPrecisionSkeleton() throws {
        typealias Precision = NumberFormatStyleConfiguration.Precision

        #expect(Precision.significantDigits(3...3).skeleton == "@@@")
        #expect(Precision.significantDigits(2...).skeleton == "@@+")
        #expect(Precision.significantDigits(...4).skeleton == "@###")
        #expect(Precision.significantDigits(3...4).skeleton == "@@@#")

        // Invalid configuration. We'll force at least one significant digits.
        #expect(Precision.significantDigits(0...0).skeleton == "@")
        #expect(Precision.significantDigits(...0).skeleton == "@")

        #expect(Precision.fractionLength(...0).skeleton == "precision-integer")
        #expect(Precision.fractionLength(0...0).skeleton == "precision-integer")
        #expect(Precision.fractionLength(3...3).skeleton == ".000")
        #expect(Precision.fractionLength(1...).skeleton == ".0+")
        #expect(Precision.fractionLength(...1).skeleton == ".#")
        #expect(Precision.fractionLength(1...3).skeleton == ".0##")

        #expect(Precision.integerLength(0...).skeleton == "integer-width/+")
        #expect(Precision.integerLength(1...).skeleton == "integer-width/+0")
        #expect(Precision.integerLength(3...).skeleton == "integer-width/+000")
        #expect(Precision.integerLength(1...3).skeleton == "integer-width/##0")
        #expect(Precision.integerLength(2...2).skeleton == "integer-width/00")
        #expect(Precision.integerLength(...3).skeleton == "integer-width/###")

        // Special case
        #expect(Precision.integerLength(...0).skeleton == "integer-width/*")
    }

    @Test func testSignDisplaySkeleton() throws {
        typealias SignDisplay = NumberFormatStyleConfiguration.SignDisplayStrategy
        #expect(SignDisplay.never.skeleton == "sign-never")
        #expect(SignDisplay.always().skeleton == "sign-always")
        #expect(SignDisplay.always(includingZero: true).skeleton == "sign-always")
        #expect(SignDisplay.always(includingZero: false).skeleton == "sign-except-zero")
        #expect(SignDisplay.automatic.skeleton == "sign-auto")
    }

    @Test func testCurrencySkeleton() throws {
        typealias SignDisplay = CurrencyFormatStyleConfiguration.SignDisplayStrategy
        #expect(SignDisplay.automatic.skeleton == "sign-auto")
        #expect(SignDisplay.always().skeleton == "sign-always")
        #expect(SignDisplay.always(showZero: true).skeleton == "sign-always")
        #expect(SignDisplay.always(showZero: false).skeleton == "sign-except-zero")
        #expect(SignDisplay.accounting.skeleton == "sign-accounting")
        #expect(SignDisplay.accountingAlways().skeleton == "sign-accounting-except-zero")
        #expect(SignDisplay.accountingAlways(showZero: true).skeleton == "sign-accounting-always")
        #expect(SignDisplay.accountingAlways(showZero: false).skeleton == "sign-accounting-except-zero")
        #expect(SignDisplay.never.skeleton == "sign-never")

        let style: IntegerFormatStyle<Int>.Currency = .init(code: "USD", locale: Locale(identifier: "en_US"))
        let formatter = ICUCurrencyNumberFormatter.create(for: style)!
        #expect(formatter.skeleton == "currency/USD unit-width-short")

        let accountingStyle = style.sign(strategy: .accounting)
        let accountingFormatter = ICUCurrencyNumberFormatter.create(for: accountingStyle)!
        #expect(accountingFormatter.skeleton == "currency/USD unit-width-short sign-accounting")

        let isoCodeStyle = style.sign(strategy: .never).presentation(.isoCode)
        let isoCodeFormatter = ICUCurrencyNumberFormatter.create(for: isoCodeStyle)!
        #expect(isoCodeFormatter.skeleton == "currency/USD unit-width-iso-code sign-never")
    }

    @Test func testStyleSkeleton_integer_precisionAndRounding() throws {
        let style: IntegerFormatStyle<Int> = .init(locale: Locale(identifier: "en_US"))
        #expect(style.precision(.fractionLength(3...3)).rounded(increment: 5).collection.skeleton == "precision-increment/5.000 rounding-mode-half-even")
        #expect(style.precision(.fractionLength(3...)).rounded(increment: 5).collection.skeleton == "precision-increment/5.000 rounding-mode-half-even")
        #expect(style.precision(.fractionLength(...3)).rounded(increment: 5).collection.skeleton == "precision-increment/5 rounding-mode-half-even")

        #expect(style.precision(.integerLength(2...2)).rounded(increment: 5).collection.skeleton == "precision-increment/5 integer-width/00 rounding-mode-half-even")
        #expect(style.precision(.integerLength(2...)).rounded(increment: 5).collection.skeleton == "precision-increment/5 integer-width/+00 rounding-mode-half-even")
        #expect(style.precision(.integerLength(...2)).rounded(increment: 5).collection.skeleton == "precision-increment/5 integer-width/## rounding-mode-half-even")

        #expect(style.precision(.integerAndFractionLength(integerLimits: 2...2, fractionLimits: 3...3)).rounded(increment: 5).collection.skeleton == "precision-increment/5.000 integer-width/00 rounding-mode-half-even")
    }

    @Test func testStyleSkeleton_floatingPoint_precisionAndRounding() throws {
        let style: FloatingPointFormatStyle<Double> = .init(locale: Locale(identifier: "en_US"))
        #expect(style.precision(.fractionLength(3...3)).rounded(increment: 0.314).collection.skeleton == "precision-increment/0.314 rounding-mode-half-even")
        #expect(style.precision(.fractionLength(3...)).rounded(increment: 0.314).collection.skeleton == "precision-increment/0.314 rounding-mode-half-even")
        #expect(style.precision(.fractionLength(...3)).rounded(increment: 0.314).collection.skeleton == "precision-increment/0.314 rounding-mode-half-even")
        #expect(style.precision(.fractionLength(...1)).rounded(increment: 0.314).collection.skeleton == "precision-increment/0.314 rounding-mode-half-even")

        #expect(style.precision(.fractionLength(3...3)).rounded(increment: 0.3).collection.skeleton == "precision-increment/0.300 rounding-mode-half-even")
        #expect(style.precision(.fractionLength(3...)).rounded(increment: 0.3).collection.skeleton == "precision-increment/0.300 rounding-mode-half-even")

        #expect(style.precision(.integerLength(2...2)).rounded(increment: 0.314).collection.skeleton == "precision-increment/0.314 integer-width/00 rounding-mode-half-even")
        #expect(style.precision(.integerLength(2...)).rounded(increment: 0.314).collection.skeleton == "precision-increment/0.314 integer-width/+00 rounding-mode-half-even")
        #expect(style.precision(.integerLength(...2)).rounded(increment: 0.314).collection.skeleton == "precision-increment/0.314 integer-width/## rounding-mode-half-even")

        #expect(style.precision(.integerAndFractionLength(integerLimits: 2...2, fractionLimits: 3...3)).rounded(increment: 0.314).collection.skeleton == "precision-increment/0.314 integer-width/00 rounding-mode-half-even")
        #expect(style.precision(.integerAndFractionLength(integerLimits: 2..., fractionLimits: 3...3)).rounded(increment: 0.314).collection.skeleton == "precision-increment/0.314 integer-width/+00 rounding-mode-half-even")
        #expect(style.precision(.integerAndFractionLength(integerLimits: ...2, fractionLimits: 3...3)).rounded(increment: 0.314).collection.skeleton == "precision-increment/0.314 integer-width/## rounding-mode-half-even")

        #expect(style.precision(.integerAndFractionLength(integerLimits: 2...2, fractionLimits: 3...3)).rounded(increment: 0.3).collection.skeleton == "precision-increment/0.300 integer-width/00 rounding-mode-half-even")
        #expect(style.precision(.integerAndFractionLength(integerLimits: 2..., fractionLimits: 3...3)).rounded(increment: 0.3).collection.skeleton == "precision-increment/0.300 integer-width/+00 rounding-mode-half-even")
        #expect(style.precision(.integerAndFractionLength(integerLimits: ...2, fractionLimits: 3...3)).rounded(increment: 0.3).collection.skeleton == "precision-increment/0.300 integer-width/## rounding-mode-half-even")
    }
}
