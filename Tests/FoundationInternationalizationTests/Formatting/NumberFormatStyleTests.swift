// Copyright (c) 2014 - 2023 Apple Inc. and the Swift project authors
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

@Suite("Number FormatStyle")
private struct NumberFormatStyleTests {
    let enUSLocale = Locale(identifier: "en_US")
    let frFRLocale = Locale(identifier: "fr_FR")

    let testNegativePositiveIntegerData: [Int] = [ -98, -9, 0, 9, 98 ]
    let testNegativePositiveDoubleData: [Double] = [ 87650, 8765, 876.5, 87.65, 8.765, 0.8765, 0.08765, 0.008765, 0, -0.008765, -876.5, -87650 ]
    let testNegativePositiveDecimalData: [Decimal] = [  Decimal(string:"87650")!, Decimal(string:"8765")!, Decimal(string:"876.5")!, Decimal(string:"87.65")!, Decimal(string:"8.765")!, Decimal(string:"0.8765")!, Decimal(string:"0.08765")!, Decimal(string:"0.008765")!, Decimal(string:"0")!, Decimal(string:"-0.008765")!, Decimal(string:"-876.5")!, Decimal(string:"-87650")! ]

    func _testNegativePositiveInt<F: FormatStyle>(_ style: F, _ expected: [String], _ testName: Comment? = nil, sourceLocation: SourceLocation = #_sourceLocation) where F.FormatInput == Int, F.FormatOutput == String {
        for i in 0..<testNegativePositiveIntegerData.count {
            #expect(style.format(testNegativePositiveIntegerData[i]) == expected[i], testName, sourceLocation: sourceLocation)
        }
    }
    func _testNegativePositiveDouble<F: FormatStyle>(_ style: F, _ expected: [String], _ testName: Comment? = nil, sourceLocation: SourceLocation = #_sourceLocation) where F.FormatInput == Double, F.FormatOutput == String {
        for i in 0..<testNegativePositiveDoubleData.count {
            #expect(style.format(testNegativePositiveDoubleData[i]) == expected[i], testName, sourceLocation: sourceLocation)
        }
    }

    func _testNegativePositiveDecimal<F: FormatStyle>(_ style: F, _ expected: [String], _ testName: Comment? = nil, sourceLocation: SourceLocation = #_sourceLocation) where F.FormatInput == Decimal, F.FormatOutput == String {
        for i in 0..<testNegativePositiveDecimalData.count {
            #expect((testNegativePositiveDecimalData[i]).formatted(style) == expected[i], testName, sourceLocation: sourceLocation)
        }
    }

    @Test func nsICUNumberFormatter() throws {
        let locale = Locale(identifier: "en_US")
        let style = IntegerFormatStyle<Int64>().locale(locale)
        let formatter = try #require(ICUNumberFormatter.create(for: style))

        #expect(formatter.format(42 as Int64) == "42")
        #expect(formatter.format(42 as Double) == "42")

        // Test strings longer than the stack buffer
        let longStyle = IntegerFormatStyle<Int64>().locale(locale).precision(.integerAndFractionLength(integerLimits: 40..., fractionLimits: 0..<1))
        let formatter_long = try #require(ICUNumberFormatter.create(for: longStyle))
        #expect(formatter_long.format(42 as Int64) == "0,000,000,000,000,000,000,000,000,000,000,000,000,042")
        #expect(formatter_long.format(42 as Double) == "0,000,000,000,000,000,000,000,000,000,000,000,000,042")
    }

#if !os(watchOS) // 99504292
    @Test func nsICUNumberFormatterCache() throws {

        let intStyle = IntegerFormatStyle<Int64>(locale: Locale(identifier: "en_US"))
        let intFormatter = try #require(ICUNumberFormatter.create(for: intStyle))

        let int64Style = IntegerFormatStyle<Int64>(locale: Locale(identifier: "en_US"))
        let int64Formatter = try #require(ICUNumberFormatter.create(for: int64Style))

        #expect(intFormatter.uformatter == int64Formatter.uformatter)

        // --

        let int64StyleFr = IntegerFormatStyle<Int64>(locale: Locale(identifier: "fr_FR"))
        let int64FrFormatter = try #require(ICUNumberFormatter.create(for: int64StyleFr))

        // Different formatter for different locale
        #expect(intFormatter.uformatter != int64FrFormatter.uformatter)

        let int64StylePrecision = IntegerFormatStyle<Int64>(locale: Locale(identifier: "en_US")).precision(.integerLength(10...))
        let int64PrecisionFormatter = try #require(ICUNumberFormatter.create(for: int64StylePrecision))

        // Different formatter for different precision
        #expect(intFormatter.uformatter != int64PrecisionFormatter.uformatter)

        // --

        let floatStyle = FloatingPointFormatStyle<Float>(locale: Locale(identifier: "en_US"))
        let floatFormatter = try #require(ICUNumberFormatter.create(for: floatStyle))
        #expect(floatFormatter.uformatter == int64Formatter.uformatter)

        let doubleStyle = FloatingPointFormatStyle<Double>(locale: Locale(identifier: "en_US"))
        let doubleFormatter = try #require(ICUNumberFormatter.create(for: doubleStyle))
        #expect(doubleFormatter.uformatter == floatFormatter.uformatter)

        let doubleCurrencyStyle = FloatingPointFormatStyle<Double>.Currency(code: "USD", locale: Locale(identifier: "en_US"))
        let doubleCurrencyFormatter = try #require(ICUCurrencyNumberFormatter.create(for: doubleCurrencyStyle))
        #expect(doubleCurrencyFormatter.uformatter != doubleFormatter.uformatter, "Should use a different uformatter for an unseen style")
    }
#endif

    @Test func integerFormatStyle() throws {

        let testData: [Int] = [
            87650000, 8765000, 876500, 87650, 8765, 876, 87, 8, 0
        ]

        func testIntValues(_ style: IntegerFormatStyle<Int>, expected: [String], sourceLocation: SourceLocation = #_sourceLocation) {
            for i in 0..<testData.count {
                #expect(style.format(testData[i]) == expected[i], sourceLocation: sourceLocation)
            }
        }

        let locale = Locale(identifier: "en_US")
        testIntValues(IntegerFormatStyle<Int>(locale: locale), expected: [ "87,650,000", "8,765,000", "876,500", "87,650", "8,765", "876", "87", "8", "0" ])

        // Single modifier
        testIntValues(IntegerFormatStyle<Int>(locale: locale).notation(.scientific), expected: [ "8.765E7", "8.765E6", "8.765E5", "8.765E4", "8.765E3", "8.76E2", "8.7E1", "8E0", "0E0" ])

        testIntValues(IntegerFormatStyle<Int>(locale: locale).sign(strategy: .always()), expected: [ "+87,650,000", "+8,765,000", "+876,500", "+87,650", "+8,765", "+876", "+87", "+8", "+0" ])
    }

    @Test func integerFormatStyleFixedWidthLimits() throws {
        func test<I: FixedWidthInteger>(type: I.Type = I.self, min: String, max: String, sourceLocation: SourceLocation = #_sourceLocation) {
            do {
                let style = IntegerFormatStyle<I>(locale: Locale(identifier: "en_US_POSIX"))
                #expect(style.format(I.min) == I.min.description, sourceLocation: sourceLocation)
                #expect(style.format(I.max) == I.max.description, sourceLocation: sourceLocation)
            }

            do {
                let style = IntegerFormatStyle<I>(locale: Locale(identifier: "en_US"))
                #expect(style.format(I.min) == min, sourceLocation: sourceLocation)
                #expect(style.format(I.max) == max, sourceLocation: sourceLocation)
            }

            do {
                let style = IntegerFormatStyle<I>.Percent(locale: Locale(identifier: "en_US"))
                #expect(style.format(I.min) == min + "%", sourceLocation: sourceLocation)
                #expect(style.format(I.max) == max + "%", sourceLocation: sourceLocation)
            }

            do {
                let style = IntegerFormatStyle<I>.Currency(code: "USD", locale: Locale(identifier: "en_US")).presentation(.narrow)
                let negativeSign = (min.first == "-" ? "-" : "")
                #expect(style.format(I.min) == "\(negativeSign)$\(min.drop(while: { $0 == "-" })).00", sourceLocation: sourceLocation)
                #expect(style.format(I.max) == "$\(max).00", sourceLocation: sourceLocation)
            }
        }

        test(type: Int8.self, min: "-128", max: "127")
        test(type: Int16.self, min: "-32,768", max: "32,767")
        test(type: Int32.self, min: "-2,147,483,648", max: "2,147,483,647")
        test(type: Int64.self, min: "-9,223,372,036,854,775,808", max: "9,223,372,036,854,775,807")

        test(type: UInt8.self, min: "0", max: "255")
        test(type: UInt16.self, min: "0", max: "65,535")
        test(type: UInt32.self, min: "0", max: "4,294,967,295")
        test(type: UInt64.self, min: "0", max: "18,446,744,073,709,551,615")
    }

    @Test func integer_Precision() throws {
        let style = IntegerFormatStyle<Int>(locale: Locale(identifier: "en_US"))
        _testNegativePositiveInt(style.precision(.significantDigits(3...3)), [ "-98.0", "-9.00", "0.00", "9.00", "98.0" ], "exact significant digits")
        _testNegativePositiveInt(style.precision(.significantDigits(2...)), [ "-98", "-9.0", "0.0", "9.0", "98" ], "min significant digits")

        _testNegativePositiveInt(style.precision(.integerAndFractionLength(integerLimits: 4..., fractionLimits: 0...0)), [ "-0,098", "-0,009", "0,000", "0,009", "0,098" ])
    }

    @Test func integerFormatStyle_Percent() throws {
        let style = IntegerFormatStyle<Int>.Percent(locale: Locale(identifier: "en_US"))
        _testNegativePositiveInt(style, [ "-98%", "-9%", "0%", "9%", "98%" ], "percent default")
        _testNegativePositiveInt(style.precision(.significantDigits(3...3)), [ "-98.0%", "-9.00%", "0.00%", "9.00%", "98.0%" ], "percent + significant digit")
    }

    @Test func integerFormatStyle_Currency() throws {
        let style = IntegerFormatStyle<Int>.Currency(code: "GBP", locale: Locale(identifier: "en_US"))
        _testNegativePositiveInt(style.presentation(.narrow), [ "-£98.00", "-£9.00", "£0.00", "£9.00", "£98.00" ], "currency narrow")
        _testNegativePositiveInt(style.presentation(.isoCode), [ "-GBP 98.00", "-GBP 9.00", "GBP 0.00", "GBP 9.00", "GBP 98.00" ], "currency isoCode")
        _testNegativePositiveInt(style.presentation(.standard), [ "-£98.00", "-£9.00", "£0.00", "£9.00", "£98.00" ], "currency standard")
        _testNegativePositiveInt(style.presentation(.fullName), [ "-98.00 British pounds", "-9.00 British pounds", "0.00 British pounds", "9.00 British pounds", "98.00 British pounds" ], "currency fullname")

        let styleUSD = IntegerFormatStyle<Int>.Currency(code: "USD", locale: Locale(identifier: "en_CA"))
        _testNegativePositiveInt(styleUSD.presentation(.standard), [ "-US$98.00", "-US$9.00", "US$0.00", "US$9.00", "US$98.00" ], "currency standard")
    }

    @Test func floatingPointFormatStyle() throws {
        let style = FloatingPointFormatStyle<Double>(locale: Locale(identifier: "en_US"))
        _testNegativePositiveDouble(style.precision(.significantDigits(...2)), [ "88,000", "8,800", "880", "88", "8.8", "0.88", "0.088", "0.0088", "0", "-0.0088", "-880", "-88,000" ], "max 2 significant digits")
        _testNegativePositiveDouble(style.precision(.fractionLength(1...3)), [ "87,650.0", "8,765.0", "876.5", "87.65", "8.765", "0.876", "0.088", "0.009", "0.0", "-0.009", "-876.5", "-87,650.0" ], "fraction limit")
        _testNegativePositiveDouble(style.precision(.integerLength(3...)), [ "87,650", "8,765", "876.5", "087.65", "008.765", "000.8765", "000.08765", "000.008765", "000", "-000.008765", "-876.5", "-87,650" ], "min 3 integer digits")
        _testNegativePositiveDouble(style.precision(.integerLength(1...3)), [ "650", "765", "876.5", "87.65", "8.765", "0.8765", "0.08765", "0.008765", "0", "-0.008765", "-876.5", "-650" ], "min 1 max 3 integer digits")
        _testNegativePositiveDouble(style.precision(.integerLength(2...2)), [ "50", "65", "76.5", "87.65", "08.765", "00.8765", "00.08765", "00.008765", "00", "-00.008765", "-76.5", "-50"], "exact 2 integer digits")

        _testNegativePositiveDouble(style.precision(.integerAndFractionLength(integerLimits: 2...2, fractionLimits: 0...0)), [ "50", "65", "76", "88", "09", "01", "00", "00", "00", "-00", "-76", "-50"], "exact 2 integer digits")
        _testNegativePositiveDouble(style.precision(.integerAndFractionLength(integerLimits: 3..., fractionLimits: 0...0)), [ "87,650", "8,765", "876", "088", "009", "001", "000", "000", "000", "-000", "-876", "-87,650" ], "min 3 integer digits")

        // Setting 0 integer length is not currently supported for numbers with non-zero integer part. Expected to be fixed in ICU 70.
        _testNegativePositiveDouble(style.precision(.integerLength(0)), [ "87,650", "8,765", "876.5", "87.65", "8.765", ".8765", ".08765", ".008765", "0", "-.008765", "-876.5", "-87,650"], "exact 0 integer digits")
        _testNegativePositiveDouble(style.precision(.integerLength(0...0)), [ "87,650", "8,765", "876.5", "87.65", "8.765", ".8765", ".08765", ".008765", "0", "-.008765", "-876.5", "-87,650"], "exact 0 integer digits")
        _testNegativePositiveDouble(style.precision(.integerAndFractionLength(integerLimits: 0...0, fractionLimits: 2...2)), [ "87,650.00", "8,765.00", "876.50", "87.65", "8.76", ".88", ".09", ".01", ".00", "-.01", "-876.50", "-87,650.00"], "exact 2 integer digits")
    }

    @Test func floatingPointFormatStyle_Percent() throws {
        let style = FloatingPointFormatStyle<Double>.Percent(locale: Locale(identifier: "en_US"))
        _testNegativePositiveDouble(style, [ "8,765,000%", "876,500%", "87,650%", "8,765%", "876.5%", "87.65%", "8.765%", "0.8765%", "0%", "-0.8765%", "-87,650%", "-8,765,000%" ] , "percent default")
        _testNegativePositiveDouble(style.precision(.significantDigits(2)), [ "8,800,000%", "880,000%", "88,000%", "8,800%", "880%", "88%", "8.8%", "0.88%", "0.0%", "-0.88%", "-88,000%", "-8,800,000%" ], "percent 2 significant digits")
    }

    @Test func floatingPointFormatStyle_BigNumber() throws {
        let bigData: [(Double, String)] = [
            (9007199254740992, "9,007,199,254,740,992.00"), // Maximum integer that can be precisely represented by a double
            (-9007199254740992, "-9,007,199,254,740,992.00"), // Minimum integer that can be precisely represented by a double

            (9007199254740992.5, "9,007,199,254,740,992.00"), // Would round to the closest
            (9007199254740991.5, "9,007,199,254,740,992.00"), // Would round to the closest
        ]

        let style = FloatingPointFormatStyle<Double>(locale: Locale(identifier: "en_US")).precision(.fractionLength(2...))
        for (v, expected) in bigData {
            #expect(style.format(v) == expected)
        }

        #expect(Float64.greatestFiniteMagnitude.formatted(.number.locale(enUSLocale)) == "179,769,313,486,231,570,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000")
        #expect(Float64.infinity.formatted(.number.locale(enUSLocale)) == "∞")
        #expect(Float64.leastNonzeroMagnitude.formatted(.number.locale(enUSLocale)) == "0")
        #expect(Float64.nan.formatted(.number.locale(enUSLocale)) == "NaN")
        #expect(Float64.nan.formatted(.number.locale(enUSLocale).precision(.fractionLength(2))) == "NaN")
        #expect(Float64.nan.formatted(.number.locale(Locale(identifier: "uz_Cyrl"))) == "ҳақиқий сон эмас")

        #expect(Float64.greatestFiniteMagnitude.formatted(.percent.locale(enUSLocale)) == "17,976,931,348,623,157,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000%")
        #expect(Float64.infinity.formatted(.percent.locale(enUSLocale)) == "∞%")
        #expect(Float64.leastNonzeroMagnitude.formatted(.percent.locale(enUSLocale)) == "0%")
        #expect(Float64.nan.formatted(.percent.locale(enUSLocale)) == "NaN%")
        #expect(Float64.nan.formatted(.percent.locale(enUSLocale).precision(.fractionLength(2))) == "NaN%")
        #expect(Float64.nan.formatted(.percent.locale(Locale(identifier: "uz_Cyrl"))) == "ҳақиқий сон эмас%")

        #expect(Float64.greatestFiniteMagnitude.formatted(.currency(code: "USD").locale(enUSLocale)) == "$179,769,313,486,231,570,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000.00")
        #expect(Float64.infinity.formatted(.currency(code: "USD").locale(enUSLocale)) == "$∞")
        #expect(Float64.leastNonzeroMagnitude.formatted(.currency(code: "USD").locale(enUSLocale)) == "$0.00")
        #expect(Float64.nan.formatted(.currency(code: "USD").locale(enUSLocale)) == "$NaN")
        #expect(Float64.nan.formatted(.currency(code: "USD").locale(enUSLocale).precision(.fractionLength(2))) == "$NaN")
        #expect(Float64.nan.formatted(.currency(code: "USD").locale(Locale(identifier: "uz_Cyrl"))) == "ҳақиқий сон эмас US$")
    }

    @Test func formattedAttributedLeadingDotSyntax() throws {
        let int = 42
        #expect(int.formatted(.number.attributed) == IntegerFormatStyle().attributed.format(int))
        #expect(int.formatted(.percent.attributed) == IntegerFormatStyle.Percent().attributed.format(int))
        #expect(int.formatted(.currency(code: "GBP").attributed) == IntegerFormatStyle.Currency(code: "GBP").attributed.format(int))

        let float = 3.14159
        #expect(float.formatted(.number.attributed) == FloatingPointFormatStyle<Double>().attributed.format(float))
        #expect(float.formatted(.percent.attributed) == FloatingPointFormatStyle.Percent().attributed.format(float))
        #expect(float.formatted(.currency(code: "GBP").attributed) == FloatingPointFormatStyle.Currency(code: "GBP").attributed.format(float))

        let decimal = Decimal(2.999)
        #expect(decimal.formatted(.number.attributed) == Decimal.FormatStyle().attributed.format(decimal))
        #expect(decimal.formatted(.percent.attributed) == Decimal.FormatStyle.Percent().attributed.format(decimal))
        #expect(decimal.formatted(.currency(code: "GBP").attributed) == Decimal.FormatStyle.Currency(code: "GBP").attributed.format(decimal))
    }

    @Test func decimalFormatStyle() throws {
        let style = Decimal.FormatStyle(locale: enUSLocale)
        _testNegativePositiveDecimal(style.precision(.significantDigits(...2)), [ "88,000", "8,800", "880", "88", "8.8", "0.88", "0.088", "0.0088", "0", "-0.0088", "-880", "-88,000" ], "max 2 significant digits")
        _testNegativePositiveDecimal(style.precision(.fractionLength(1...3)), [ "87,650.0", "8,765.0", "876.5", "87.65", "8.765", "0.876", "0.088", "0.009", "0.0", "-0.009", "-876.5", "-87,650.0" ], "fraction limit")
        _testNegativePositiveDecimal(style.precision(.fractionLength(0)), [ "87,650", "8,765", "876", "88", "9", "1", "0", "0", "0", "-0", "-876", "-87,650" ], "0 fractional digits")

        _testNegativePositiveDecimal(style.precision(.integerLength(3...)), [ "87,650", "8,765", "876.5", "087.65", "008.765", "000.8765", "000.08765", "000.008765", "000", "-000.008765", "-876.5", "-87,650" ], "min 3 integer digits")
        _testNegativePositiveDecimal(style.precision(.integerAndFractionLength(integerLimits: 3..., fractionLimits: 0...0)), [ "87,650", "8,765", "876", "088", "009", "001", "000", "000", "000", "-000", "-876", "-87,650" ], "min 3 integer digits")

        _testNegativePositiveDecimal(style.precision(.integerLength(1...3)), [ "650", "765", "876.5", "87.65", "8.765", "0.8765", "0.08765", "0.008765", "0", "-0.008765", "-876.5", "-650" ], "min 1 max 3 integer digits")
        _testNegativePositiveDecimal(style.precision(.integerAndFractionLength(integerLimits: 1...3, fractionLimits: 0...0)), [ "650", "765", "876", "88", "9", "1", "0", "0", "0", "-0", "-876", "-650" ], "min 1 max 3 integer digits")

        _testNegativePositiveDecimal(style.precision(.integerLength(2...2)), [ "50", "65", "76.5", "87.65", "08.765", "00.8765", "00.08765", "00.008765", "00", "-00.008765", "-76.5", "-50"], "exact 2 integer digits")
        _testNegativePositiveDecimal(style.precision(.integerAndFractionLength(integerLimits: 2...2, fractionLimits: 0...0)), [ "50", "65", "76", "88", "09", "01", "00", "00", "00", "-00", "-76", "-50"], "exact 2 integer digits; 0 fractional digits")
    }

    @Test func decimalFormatStyle_Percent() throws {
        let style = Decimal.FormatStyle.Percent(locale: enUSLocale)
        _testNegativePositiveDecimal(style.precision(.significantDigits(...2)), [ "8,800,000%", "880,000%", "88,000%", "8,800%", "880%", "88%", "8.8%", "0.88%", "0%", "-0.88%", "-88,000%", "-8,800,000%" ], "max 2 significant digits")
        _testNegativePositiveDecimal(style.precision(.fractionLength(1...3)), [ "8,765,000.0%",
                                                                                "876,500.0%",
                                                                                "87,650.0%",
                                                                                "8,765.0%",
                                                                                "876.5%",
                                                                                "87.65%",
                                                                                "8.765%",
                                                                                "0.876%",
                                                                                "0.0%",
                                                                                "-0.876%",
                                                                                "-87,650.0%",
                                                                                "-8,765,000.0%" ], "fraction limit")
        _testNegativePositiveDecimal(style.precision(.integerLength(3...)), [ "8,765,000%",
                                                                              "876,500%",
                                                                              "87,650%",
                                                                              "8,765%",
                                                                              "876.5%",
                                                                              "087.65%",
                                                                              "008.765%",
                                                                              "000.8765%",
                                                                              "000%",
                                                                              "-000.8765%",
                                                                              "-87,650%",
                                                                              "-8,765,000%" ], "min 3 integer digits")
        _testNegativePositiveDecimal(style.precision(.integerLength(1...3)), [ "0%",
                                                                               "500%",
                                                                               "650%",
                                                                               "765%",
                                                                               "876.5%",
                                                                               "87.65%",
                                                                               "8.765%",
                                                                               "0.8765%",
                                                                               "0%",
                                                                               "-0.8765%",
                                                                               "-650%",
                                                                               "-0%" ], "min 1 max 3 integer digits")
        _testNegativePositiveDecimal(style.precision(.integerLength(2...2)), [ "00%",
                                                                               "00%",
                                                                               "50%",
                                                                               "65%",
                                                                               "76.5%",
                                                                               "87.65%",
                                                                               "08.765%",
                                                                               "00.8765%",
                                                                               "00%",
                                                                               "-00.8765%",
                                                                               "-50%",
                                                                               "-00%" ], "exact 2 integer digits")
    }

    @Test func decimalFormatStyle_Currency() throws {
        let style = Decimal.FormatStyle.Currency(code: "USD", locale: enUSLocale)
        _testNegativePositiveDecimal(style, [ "$87,650.00", "$8,765.00", "$876.50", "$87.65", "$8.76", "$0.88", "$0.09", "$0.01", "$0.00", "-$0.01", "-$876.50", "-$87,650.00" ], "currency style")

    }

    @Test func decimal_withCustomShorthand() async {
        await usingCurrentInternationalizationPreferences {
            // This test can only be run with the system set to the en_US language
            var prefs = LocalePreferences()
            prefs.languages = ["en-US"]
            prefs.locale = "en_US"
            LocaleCache.cache.resetCurrent(to: prefs)
            
            #expect((12345 as Decimal).formatted(.number.grouping(.never)) == "12345")
            #expect((12345.678 as Decimal).formatted(.percent.sign(strategy: .always())) == "+1,234,567.8%")
            #expect((-3000.14159 as Decimal).formatted(.currency(code:"USD").sign(strategy: .accounting)) == "($3,000.14)")
        }
    }

    @Test func decimal_withShorthand_enUS() async {
        await usingCurrentInternationalizationPreferences {
            // This test can only be run with the system set to the en_US language
            var prefs = LocalePreferences()
            prefs.languages = ["en-US"]
            prefs.locale = "en_US"
            LocaleCache.cache.resetCurrent(to: prefs)
            
            
            #expect((12345 as Decimal).formatted(.number) == "12,345")
            #expect((12345.678 as Decimal).formatted(.number) == "12,345.678")
            #expect((0 as Decimal).formatted(.number) == "0")
            #expect((3.14159 as Decimal).formatted(.number) == "3.14159")
            #expect((-3.14159 as Decimal).formatted(.number) == "-3.14159")
            #expect((-3000.14159 as Decimal).formatted(.number) == "-3,000.14159")
            
            #expect((0.12345 as Decimal).formatted(.percent) == "12.345%")
            #expect((0.0012345 as Decimal).formatted(.percent) == "0.12345%")
            #expect((12345 as Decimal).formatted(.percent) == "1,234,500%")
            #expect((12345.678 as Decimal).formatted(.percent) == "1,234,567.8%")
            #expect((0 as Decimal).formatted(.percent) == "0%")
            #expect((3.14159 as Decimal).formatted(.percent) == "314.159%")
            #expect((-3.14159 as Decimal).formatted(.percent) == "-314.159%")
            #expect((-3000.14159 as Decimal).formatted(.percent) == "-300,014.159%")
            
            #expect((12345 as Decimal).formatted(.currency(code:"USD")) == "$12,345.00")
            #expect((12345.678 as Decimal).formatted(.currency(code:"USD")) == "$12,345.68")
            #expect((0 as Decimal).formatted(.currency(code:"USD")) == "$0.00")
            #expect((3.14159 as Decimal).formatted(.currency(code:"USD")) == "$3.14")
            #expect((-3.14159 as Decimal).formatted(.currency(code:"USD")) == "-$3.14")
            #expect((-3000.14159 as Decimal).formatted(.currency(code:"USD")) == "-$3,000.14")
        }
    }

    @Test func decimal_default() async {
        await usingCurrentInternationalizationPreferences {
            let style = Decimal.FormatStyle()
            #expect((12345 as Decimal).formatted() == style.format(12345))
            #expect((12345.678 as Decimal).formatted() == style.format(12345.678))
            #expect((0 as Decimal).formatted() == style.format(0))
            #expect((3.14159 as Decimal).formatted() == style.format(3.14159))
            #expect((-3.14159 as Decimal).formatted() == style.format(-3.14159))
            #expect((-3000.14159 as Decimal).formatted() == style.format(-3000.14159))
        }
    }

    @Test func decimal_default_enUS() async {
        await usingCurrentInternationalizationPreferences {
            // This test can only be run with the system set to the en_US language
            var prefs = LocalePreferences()
            prefs.languages = ["en-US"]
            prefs.locale = "en_US"
            LocaleCache.cache.resetCurrent(to: prefs)
            
            #expect((12345 as Decimal).formatted() == "12,345")
            #expect((12345.678 as Decimal).formatted() == "12,345.678")
            #expect((0 as Decimal).formatted() == "0")
            #expect((3.14159 as Decimal).formatted() == "3.14159")
            #expect((-3.14159 as Decimal).formatted() == "-3.14159")
            #expect((-3000.14159 as Decimal).formatted() == "-3,000.14159")
        }
    }

    @Test func decimal_withShorthand() throws {
        let style = Decimal.FormatStyle(locale: enUSLocale)
        #expect((12345 as Decimal).formatted(.number.locale(enUSLocale)) == style.format(12345))
        #expect((12345.678 as Decimal).formatted(.number.locale(enUSLocale)) == style.format(12345.678))
        #expect((0 as Decimal).formatted(.number.locale(enUSLocale)) == style.format(0))
        #expect((3.14159 as Decimal).formatted(.number.locale(enUSLocale)) == style.format(3.14159))
        #expect((-3.14159 as Decimal).formatted(.number.locale(enUSLocale)) == style.format(-3.14159))
        #expect((-3000.14159 as Decimal).formatted(.number.locale(enUSLocale)) == style.format(-3000.14159))

        let percentStyle = Decimal.FormatStyle.Percent(locale: enUSLocale)
        #expect((12345 as Decimal).formatted(.percent.locale(enUSLocale)) == percentStyle.format(12345))
        #expect((12345.678 as Decimal).formatted(.percent.locale(enUSLocale)) == percentStyle.format(12345.678))
        #expect((0 as Decimal).formatted(.percent.locale(enUSLocale)) == percentStyle.format(0))
        #expect((3.14159 as Decimal).formatted(.percent.locale(enUSLocale)) == percentStyle.format(3.14159))
        #expect((-3.14159 as Decimal).formatted(.percent.locale(enUSLocale)) == percentStyle.format(-3.14159))
        #expect((-3000.14159 as Decimal).formatted(.percent.locale(enUSLocale)) == percentStyle.format(-3000.14159))

        let currencyStyle = Decimal.FormatStyle.Currency(code: "USD", locale: enUSLocale)
        #expect((12345 as Decimal).formatted(.currency(code:"USD").locale(enUSLocale)) == currencyStyle.format(12345))
        #expect((12345.678 as Decimal).formatted(.currency(code:"USD").locale(enUSLocale)) == currencyStyle.format(12345.678))
        #expect((0 as Decimal).formatted(.currency(code:"USD").locale(enUSLocale)) == currencyStyle.format(0))
        #expect((3.14159 as Decimal).formatted(.currency(code:"USD").locale(enUSLocale)) == currencyStyle.format(3.14159))
        #expect((-3.14159 as Decimal).formatted(.currency(code:"USD").locale(enUSLocale)) == currencyStyle.format(-3.14159))
        #expect((-3000.14159 as Decimal).formatted(.currency(code:"USD").locale(enUSLocale)) == currencyStyle.format(-3000.14159))
    }

#if FOUNDATION_FRAMEWORK
    @Test func autoupdatingCurrentChangesFormatResults() async {
        await usingCurrentInternationalizationPreferences {
            let locale = Locale.autoupdatingCurrent
            let number = 50_000
#if FOUNDATION_FRAMEWORK
            // Measurement is not yet available in the package
            let measurement = Measurement(value: 0.8, unit: UnitLength.meters)
#endif
            let currency = Decimal(123.45)
            let percent = 54.32
            let bytes = 1_234_567_890
            
            // Get a formatted result from es-ES
            var prefs = LocalePreferences()
            prefs.languages = ["es-ES"]
            prefs.locale = "es_ES"
            LocaleCache.cache.resetCurrent(to: prefs)
            let formattedSpanishNumber = number.formatted(.number.locale(locale))
#if FOUNDATION_FRAMEWORK
            let formattedSpanishMeasurement = measurement.formatted(.measurement(width: .narrow).locale(locale))
#endif
            let formattedSpanishCurrency = currency.formatted(.currency(code: "USD").locale(locale))
            let formattedSpanishPercent = percent.formatted(.percent.locale(locale))
            let formattedSpanishBytes = bytes.formatted(.byteCount(style: .decimal).locale(locale))
            
            // Get a formatted result from en-US
            prefs.languages = ["en-US"]
            prefs.locale = "en_US"
            LocaleCache.cache.resetCurrent(to: prefs)
            let formattedEnglishNumber = number.formatted(.number.locale(locale))
#if FOUNDATION_FRAMEWORK
            let formattedEnglishMeasurement = measurement.formatted(.measurement(width: .narrow).locale(locale))
#endif
            let formattedEnglishCurrency = currency.formatted(.currency(code: "USD").locale(locale))
            let formattedEnglishPercent = percent.formatted(.percent.locale(locale))
            let formattedEnglishBytes = bytes.formatted(.byteCount(style: .decimal).locale(locale))
            
            // Reset to current preferences before any possibility of failing this test
            LocaleCache.cache.reset()
            
            // No matter what 'current' was before this test was run, formattedSpanish and formattedEnglish should be different.
            #expect(formattedSpanishNumber != formattedEnglishNumber)
#if FOUNDATION_FRAMEWORK
            #expect(formattedSpanishMeasurement != formattedEnglishMeasurement)
#endif
            #expect(formattedSpanishCurrency != formattedEnglishCurrency)
            #expect(formattedSpanishPercent != formattedEnglishPercent)
            #expect(formattedSpanishBytes != formattedEnglishBytes)
        }
    }
#endif // FOUNDATION_PREVIEW

#if !os(watchOS) // These tests require Int to be Int64, which is not always true on watch OSs yet
    @Test func currency_compactName() throws {
        let baseStyle = Decimal.FormatStyle.Currency(code: "USD", locale: Locale(identifier: "en_US")).notation(.compactName)

        // significant digits
        // `compactName` naturally rounds the number to the closest "name".
        #expect( (922337203685477 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "$920T")
        #expect(  (92233720368547 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "$92T")
        #expect(   (9223372036854 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "$9.2T")
        #expect(    (922337203685 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "$920B")
        #expect(     (92233720368 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "$92B")
        #expect(      (9223372036 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "$9.2B")
        #expect(       (922337203 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "$920M")
        #expect(        (92233720 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "$92M")
        #expect(         (9223372 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "$9.2M")
        #expect(          (922337 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "$920K")
        #expect(           (92233 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "$92K")
        #expect(            (9223 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "$9.2K")
        #expect(             (922 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "$920")
        #expect(              (92 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "$92")
        #expect(               (9 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "$9.0")
        #expect(               (0 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "$0.0")
        #expect(              (-9 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "-$9.0")
        #expect(             (-92 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "-$92")
        #expect(            (-922 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "-$920")
        #expect(           (-9223 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "-$9.2K")
        #expect(          (-92233 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "-$92K")
        #expect(         (-922337 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "-$920K")
        #expect(        (-9223372 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "-$9.2M")
        #expect(       (-92233720 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "-$92M")
        #expect(      (-922337203 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "-$920M")
        #expect(     (-9223372036 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "-$9.2B")
        #expect(    (-92233720368 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "-$92B")
        #expect(   (-922337203685 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "-$920B")
        #expect(  (-9223372036854 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "-$9.2T")
        #expect( (-92233720368547 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "-$92T")
        #expect((-922337203685477 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "-$920T")

        // fraction length
        #expect( (922337203685477 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "$922.34T")
        #expect(  (92233720368547 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "$92.23T")
        #expect(   (9223372036854 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "$9.22T")
        #expect(    (922337203685 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "$922.34B")
        #expect(     (92233720368 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "$92.23B")
        #expect(      (9223372036 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "$9.22B")
        #expect(       (922337203 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "$922.34M")
        #expect(        (92233720 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "$92.23M")
        #expect(         (9223372 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "$9.22M")
        #expect(          (922337 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "$922.34K")
        #expect(           (92233 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "$92.23K")
        #expect(            (9223 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "$9.22K")
        #expect(             (922 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "$922.00")
        #expect(              (92 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "$92.00")
        #expect(               (9 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "$9.00")
        #expect(               (0 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "$0.00")
        #expect(              (-9 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "-$9.00")
        #expect(             (-92 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "-$92.00")
        #expect(            (-922 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "-$922.00")
        #expect(           (-9223 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "-$9.22K")
        #expect(          (-92233 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "-$92.23K")
        #expect(         (-922337 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "-$922.34K")
        #expect(        (-9223372 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "-$9.22M")
        #expect(       (-92233720 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "-$92.23M")
        #expect(      (-922337203 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "-$922.34M")
        #expect(     (-9223372036 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "-$9.22B")
        #expect(    (-92233720368 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "-$92.23B")
        #expect(   (-922337203685 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "-$922.34B")
        #expect(  (-9223372036854 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "-$9.22T")
        #expect( (-92233720368547 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "-$92.23T")
        #expect((-922337203685477 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "-$922.34T")

        // rounded
        #expect( (922337203685477 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "$1000T")
        #expect(  (92233720368547 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "$100T")
        #expect(   (9223372036854 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "$100T")
        #expect(    (922337203685 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "$100T")
        #expect(     (92233720368 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "$100B")
        #expect(      (9223372036 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "$100B")
        #expect(       (922337203 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "$100B")
        #expect(        (92233720 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "$100M")
        #expect(         (9223372 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "$100M")
        #expect(          (922337 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "$100M")
        #expect(           (92233 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "$100K")
        #expect(            (9223 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "$100K")
        #expect(             (922 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "$100K")
        #expect(              (92 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "$100")
        #expect(               (9 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "$100")
        #expect(               (0 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "$0")
        #expect(              (-9 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "-$100")
        #expect(             (-92 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "-$100")
        #expect(            (-922 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "-$100K")
        #expect(           (-9223 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "-$100K")
        #expect(          (-92233 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "-$100K")
        #expect(         (-922337 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "-$100M")
        #expect(        (-9223372 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "-$100M")
        #expect(       (-92233720 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "-$100M")
        #expect(      (-922337203 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "-$100B")
        #expect(     (-9223372036 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "-$100B")
        #expect(    (-92233720368 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "-$100B")
        #expect(   (-922337203685 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "-$100T")
        #expect(  (-9223372036854 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "-$100T")
        #expect( (-92233720368547 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "-$100T")
        #expect((-922337203685477 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "-$1000T")
    }

    @Test func currency_Codable() throws {
        let gbpInUS = Decimal.FormatStyle.Currency(code: "GBP", locale: enUSLocale)
        let _ = try JSONEncoder().encode(gbpInUS)
        // Valid JSON presentation of the format style
        let previouslyEncoded = try #require("""
        {
            "collection":
            {
                "presentation":
                {
                    "option": 1
                }
            },
            "currencyCode": "GBP",
            "locale":
            {
                "current": 0,
                "identifier": "en_US"
            }
        }
        """.data(using: .utf8))

        let decoded = try JSONDecoder().decode(Decimal.FormatStyle.Currency.self, from: previouslyEncoded)
        #expect(decoded == gbpInUS)
    }

    @Test func currency_scientific() throws {
        let baseStyle = Decimal.FormatStyle.Currency(code: "USD", locale: Locale(identifier: "en_US")).notation(.scientific)

        // significant digits
        // `compactName` naturally rounds the number to the closest "name".
        #expect( (922337203685477 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "$9.2E14")
        #expect(  (92233720368547 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "$9.2E13")
        #expect(   (9223372036854 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "$9.2E12")
        #expect(    (922337203685 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "$9.2E11")
        #expect(     (92233720368 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "$9.2E10")
        #expect(      (9223372036 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "$9.2E9")
        #expect(       (922337203 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "$9.2E8")
        #expect(        (92233720 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "$9.2E7")
        #expect(         (9223372 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "$9.2E6")
        #expect(          (922337 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "$9.2E5")
        #expect(           (92233 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "$9.2E4")
        #expect(            (9223 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "$9.2E3")
        #expect(             (922 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "$9.2E2")
        #expect(              (92 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "$9.2E1")
        #expect(               (9 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "$9.0E0")
        #expect(               (0 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "$0.0E0")
        #expect(              (-9 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "-$9.0E0")
        #expect(             (-92 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "-$9.2E1")
        #expect(            (-922 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "-$9.2E2")
        #expect(           (-9223 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "-$9.2E3")
        #expect(          (-92233 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "-$9.2E4")
        #expect(         (-922337 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "-$9.2E5")
        #expect(        (-9223372 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "-$9.2E6")
        #expect(       (-92233720 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "-$9.2E7")
        #expect(      (-922337203 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "-$9.2E8")
        #expect(     (-9223372036 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "-$9.2E9")
        #expect(    (-92233720368 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "-$9.2E10")
        #expect(   (-922337203685 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "-$9.2E11")
        #expect(  (-9223372036854 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "-$9.2E12")
        #expect( (-92233720368547 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "-$9.2E13")
        #expect((-922337203685477 as Decimal).formatted(baseStyle.precision(.significantDigits(2...2))) == "-$9.2E14")

        // fraction length
        #expect( (922337203685477 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "$9.22E14")
        #expect(  (92233720368547 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "$9.22E13")
        #expect(   (9223372036854 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "$9.22E12")
        #expect(    (922337203685 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "$9.22E11")
        #expect(     (92233720368 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "$9.22E10")
        #expect(      (9223372036 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "$9.22E9")
        #expect(       (922337203 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "$9.22E8")
        #expect(        (92233720 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "$9.22E7")
        #expect(         (9223372 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "$9.22E6")
        #expect(          (922337 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "$9.22E5")
        #expect(           (92233 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "$9.22E4")
        #expect(            (9223 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "$9.22E3")
        #expect(             (922 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "$9.22E2")
        #expect(              (92 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "$9.20E1")
        #expect(               (9 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "$9.00E0")
        #expect(               (0 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "$0.00E0")
        #expect(              (-9 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "-$9.00E0")
        #expect(             (-92 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "-$9.20E1")
        #expect(            (-922 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "-$9.22E2")
        #expect(           (-9223 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "-$9.22E3")
        #expect(          (-92233 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "-$9.22E4")
        #expect(         (-922337 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "-$9.22E5")
        #expect(        (-9223372 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "-$9.22E6")
        #expect(       (-92233720 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "-$9.22E7")
        #expect(      (-922337203 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "-$9.22E8")
        #expect(     (-9223372036 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "-$9.22E9")
        #expect(    (-92233720368 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "-$9.22E10")
        #expect(   (-922337203685 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "-$9.22E11")
        #expect(  (-9223372036854 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "-$9.22E12")
        #expect( (-92233720368547 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "-$9.22E13")
        #expect((-922337203685477 as Decimal).formatted(baseStyle.precision(.fractionLength(2...2))) == "-$9.22E14")

        // rounded
        #expect( (922337203685477 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "$100E15")
        #expect(  (92233720368547 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "$100E14")
        #expect(   (9223372036854 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "$100E13")
        #expect(    (922337203685 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "$100E12")
        #expect(     (92233720368 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "$100E11")
        #expect(      (9223372036 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "$100E10")
        #expect(       (922337203 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "$100E9")
        #expect(        (92233720 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "$100E8")
        #expect(         (9223372 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "$100E7")
        #expect(          (922337 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "$100E6")
        #expect(           (92233 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "$100E5")
        #expect(            (9223 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "$100E4")
        #expect(             (922 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "$100E3")
        #expect(              (92 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "$100E2")
        #expect(               (9 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "$100E1")
        #expect(               (0 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "$0E0")
        #expect(              (-9 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "-$100E1")
        #expect(             (-92 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "-$100E2")
        #expect(            (-922 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "-$100E3")
        #expect(           (-9223 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "-$100E4")
        #expect(          (-92233 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "-$100E5")
        #expect(         (-922337 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "-$100E6")
        #expect(        (-9223372 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "-$100E7")
        #expect(       (-92233720 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "-$100E8")
        #expect(      (-922337203 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "-$100E9")
        #expect(     (-9223372036 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "-$100E10")
        #expect(    (-92233720368 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "-$100E11")
        #expect(   (-922337203685 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "-$100E12")
        #expect(  (-9223372036854 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "-$100E13")
        #expect( (-92233720368547 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "-$100E14")
        #expect((-922337203685477 as Decimal).formatted(baseStyle.rounded(rule: .awayFromZero, increment: 100)) == "-$100E15")
    }
#endif // !os(watchOS)
}

extension NumberFormatStyleConfiguration.Collection {
    var debugDescription: String {
        var des = ""
        if let scale = scale { des += ".scale(\(scale))" }
        if let precision = precision { des += ".precision(.\(precision.option))" }
        if let group = group { des += ".grouping(.\(group))" }
        if let signDisplayStrategy = signDisplayStrategy { des += ".sign(strategy: .\(signDisplayStrategy))" }
        if let decimalSeparatorStrategy = decimalSeparatorStrategy { des += ".decimalSeparator(strategy: .\(decimalSeparatorStrategy))" }
        if let rounding = rounding {
            des += ".rounded(rule: .\(rounding)"
            if let roundingIncrement = roundingIncrement {
                des += ", increment: \(roundingIncrement)"
            }
            des += ")"
        }
        if let notation = notation { des += ".notation(.\(notation))" }
        return des
    }
}

extension IntegerFormatStyle {
    var debugDescription : String {
        let collectionDescription = collection.debugDescription
        return collectionDescription.count > 0 ? collectionDescription : "IntegerFormatStyle"
    }
}

#if !os(watchOS) // These tests require Int to be 64 bits, which is not always true on watch OSs yet
@Suite("IntegerFormatStyle (Exhaustive)")
private struct IntegerFormatStyleExhaustiveTests {
    let exhaustiveIntNumbers : [Int64] = [9223372036854775807, 922337203685477580, 92233720368547758, 9223372036854775, 922337203685477, 92233720368547, 9223372036854, 922337203685, 92233720368, 9223372036, 922337203, 92233720, 9223372, 922337, 92233, 9223, 922, 92, 9, 0, -9, -92, -922, -9223, -92233, -922337, -9223372, -92233720, -922337203, -9223372036, -92233720368, -922337203685, -9223372036854, -92233720368547, -922337203685477, -9223372036854775, -92233720368547758, -922337203685477580, -9223372036854775808 ]
    let baseStyle = IntegerFormatStyle<Int>(locale: Locale(identifier: "en_US"))

    @Test(.timeLimit(.minutes(1))) func integerLongStyles() throws {
        let testSuperLongStyles: [IntegerFormatStyle<Int>] = [
            baseStyle.precision(.significantDigits(Int.max...)),
            baseStyle.precision(.significantDigits(Int.min...Int.max)),
            baseStyle.precision(.integerLength(Int.max...)),
            baseStyle.precision(.integerLength(Int.max...Int.max)),
            baseStyle.precision(.integerAndFractionLength(integerLimits: Int.max..., fractionLimits: Int.max...)),
            baseStyle.precision(.integerAndFractionLength(integerLimits: Int.max...Int.max, fractionLimits: Int.max...Int.max)),
            baseStyle.precision(.fractionLength(Int.max...)),
            baseStyle.precision(.fractionLength(Int.max...Int.max)),
            baseStyle.precision(.fractionLength(...Int.max)),
            
            // Styles that do not make sense
            baseStyle.precision(.significantDigits(...Int.min)),
            baseStyle.precision(.integerAndFractionLength(integerLimits: ...Int.min, fractionLimits: ...Int.min)),
            
            baseStyle.scale(Double(Int.max)),
            baseStyle.scale(Double(Int.min)),
        ]
        
        // The results are too long so let's just verify that they're not empty and they won't spin
        for style in testSuperLongStyles {
            for value in exhaustiveIntNumbers {
                #expect(style.format(Int(value)).count > 0)
            }
        }
    }

    @Test func equivalentStyles() throws {
        let equivalentStyles: [[IntegerFormatStyle<Int>]] = [
            [
                baseStyle.precision(.significantDigits(2..<2)),
                baseStyle.precision(.significantDigits(2...2)),
                baseStyle.precision(.significantDigits(2)),
            ],
            [
                baseStyle.precision(.integerLength(2..<2)),
                baseStyle.precision(.integerLength(2...2)),
                baseStyle.precision(.integerLength(2)),
            ],
            [
                // There's no fractional parts in integers, so setting the maximum fraction length is no-op as it's always 0.
                baseStyle.precision(.fractionLength(...2)),
                baseStyle.precision(.fractionLength(...10)),
                baseStyle.precision(.fractionLength(...Int.max)),
            ],
            [
                // There's no fractional parts in integers, so setting the minimum fraction length appends the specified number of 0s.
                baseStyle.precision(.fractionLength(2...)),
                baseStyle.precision(.fractionLength(2...2)),
                baseStyle.precision(.fractionLength(2..<2)),
            ],
            [
                baseStyle.rounded(increment: 0),
                baseStyle.rounded(increment: -10),
                baseStyle.rounded(increment: nil),
            ],
        ]

        for styles in equivalentStyles {
            var previousResults: [Int64: String]?
            var previousStyle: IntegerFormatStyle<Int>?
            for style in styles {
                var results: [Int64: String] = [:]
                for value in exhaustiveIntNumbers {
                    results[value] = style.format(Int(value))
                }
                if let previousResults = previousResults, let previousStyle = previousStyle {
                    #expect(results == previousResults, "style: \(style.debugDescription) and style: \(previousStyle.debugDescription) should produce the same strings")
                }
                previousResults = results
                previousStyle = style
            }
        }
    }

    @Test func plainStyle_scale() throws {
        let expectations: [IntegerFormatStyle<Int> : [String]] = [
            baseStyle: [ "9,223,372,036,854,775,807",
                         "922,337,203,685,477,580",
                         "92,233,720,368,547,758",
                         "9,223,372,036,854,775",
                         "922,337,203,685,477",
                         "92,233,720,368,547",
                         "9,223,372,036,854",
                         "922,337,203,685",
                         "92,233,720,368",
                         "9,223,372,036",
                         "922,337,203",
                         "92,233,720",
                         "9,223,372",
                         "922,337",
                         "92,233",
                         "9,223",
                         "922",
                         "92",
                         "9",
                         "0",
                         "-9",
                         "-92",
                         "-922",
                         "-9,223",
                         "-92,233",
                         "-922,337",
                         "-9,223,372",
                         "-92,233,720",
                         "-922,337,203",
                         "-9,223,372,036",
                         "-92,233,720,368",
                         "-922,337,203,685",
                         "-9,223,372,036,854",
                         "-92,233,720,368,547",
                         "-922,337,203,685,477",
                         "-9,223,372,036,854,775",
                         "-92,233,720,368,547,758",
                         "-922,337,203,685,477,580",
                         "-9,223,372,036,854,775,808",
                       ],
            baseStyle.scale(0): [ "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "-0", "-0", "-0", "-0", "-0", "-0", "-0", "-0", "-0", "-0", "-0", "-0", "-0", "-0", "-0", "-0", "-0", "-0", "-0", ],
            baseStyle.scale(0.1): [ "922,337,203,685,477,580.7",
                                    "92,233,720,368,547,758",
                                    "9,223,372,036,854,775.8",
                                    "922,337,203,685,477.5",
                                    "92,233,720,368,547.7",
                                    "9,223,372,036,854.7",
                                    "922,337,203,685.4",
                                    "92,233,720,368.5",
                                    "9,223,372,036.8",
                                    "922,337,203.6",
                                    "92,233,720.3",
                                    "9,223,372",
                                    "922,337.2",
                                    "92,233.7",
                                    "9,223.3",
                                    "922.3",
                                    "92.2",
                                    "9.2",
                                    "0.9",
                                    "0",
                                    "-0.9",
                                    "-9.2",
                                    "-92.2",
                                    "-922.3",
                                    "-9,223.3",
                                    "-92,233.7",
                                    "-922,337.2",
                                    "-9,223,372",
                                    "-92,233,720.3",
                                    "-922,337,203.6",
                                    "-9,223,372,036.8",
                                    "-92,233,720,368.5",
                                    "-922,337,203,685.4",
                                    "-9,223,372,036,854.7",
                                    "-92,233,720,368,547.7",
                                    "-922,337,203,685,477.5",
                                    "-9,223,372,036,854,775.8",
                                    "-92,233,720,368,547,758",
                                    "-922,337,203,685,477,580.8",
                                  ],
            baseStyle.scale(10): [ "92,233,720,368,547,758,070",
                                   "9,223,372,036,854,775,800",
                                   "922,337,203,685,477,580",
                                   "92,233,720,368,547,750",
                                   "9,223,372,036,854,770",
                                   "922,337,203,685,470",
                                   "92,233,720,368,540",
                                   "9,223,372,036,850",
                                   "922,337,203,680",
                                   "92,233,720,360",
                                   "9,223,372,030",
                                   "922,337,200",
                                   "92,233,720",
                                   "9,223,370",
                                   "922,330",
                                   "92,230",
                                   "9,220",
                                   "920",
                                   "90",
                                   "0",
                                   "-90",
                                   "-920",
                                   "-9,220",
                                   "-92,230",
                                   "-922,330",
                                   "-9,223,370",
                                   "-92,233,720",
                                   "-922,337,200",
                                   "-9,223,372,030",
                                   "-92,233,720,360",
                                   "-922,337,203,680",
                                   "-9,223,372,036,850",
                                   "-92,233,720,368,540",
                                   "-922,337,203,685,470",
                                   "-9,223,372,036,854,770",
                                   "-92,233,720,368,547,750",
                                   "-922,337,203,685,477,580",
                                   "-9,223,372,036,854,775,800",
                                   "-92,233,720,368,547,758,080",
                                 ],
            baseStyle.scale(-0.1): [ "-922,337,203,685,477,580.7",
                                     "-92,233,720,368,547,758",
                                     "-9,223,372,036,854,775.8",
                                     "-922,337,203,685,477.5",
                                     "-92,233,720,368,547.7",
                                     "-9,223,372,036,854.7",
                                     "-922,337,203,685.4",
                                     "-92,233,720,368.5",
                                     "-9,223,372,036.8",
                                     "-922,337,203.6",
                                     "-92,233,720.3",
                                     "-9,223,372",
                                     "-922,337.2",
                                     "-92,233.7",
                                     "-9,223.3",
                                     "-922.3",
                                     "-92.2",
                                     "-9.2",
                                     "-0.9",
                                     "0",
                                     "0.9",
                                     "9.2",
                                     "92.2",
                                     "922.3",
                                     "9,223.3",
                                     "92,233.7",
                                     "922,337.2",
                                     "9,223,372",
                                     "92,233,720.3",
                                     "922,337,203.6",
                                     "9,223,372,036.8",
                                     "92,233,720,368.5",
                                     "922,337,203,685.4",
                                     "9,223,372,036,854.7",
                                     "92,233,720,368,547.7",
                                     "922,337,203,685,477.5",
                                     "9,223,372,036,854,775.8",
                                     "92,233,720,368,547,758",
                                     "922,337,203,685,477,580.8",
                                   ],
            baseStyle.scale(-10): [ "-92,233,720,368,547,758,070",
                                    "-9,223,372,036,854,775,800",
                                    "-922,337,203,685,477,580",
                                    "-92,233,720,368,547,750",
                                    "-9,223,372,036,854,770",
                                    "-922,337,203,685,470",
                                    "-92,233,720,368,540",
                                    "-9,223,372,036,850",
                                    "-922,337,203,680",
                                    "-92,233,720,360",
                                    "-9,223,372,030",
                                    "-922,337,200",
                                    "-92,233,720",
                                    "-9,223,370",
                                    "-922,330",
                                    "-92,230",
                                    "-9,220",
                                    "-920",
                                    "-90",
                                    "0",
                                    "90",
                                    "920",
                                    "9,220",
                                    "92,230",
                                    "922,330",
                                    "9,223,370",
                                    "92,233,720",
                                    "922,337,200",
                                    "9,223,372,030",
                                    "92,233,720,360",
                                    "922,337,203,680",
                                    "9,223,372,036,850",
                                    "92,233,720,368,540",
                                    "922,337,203,685,470",
                                    "9,223,372,036,854,770",
                                    "92,233,720,368,547,750",
                                    "922,337,203,685,477,580",
                                    "9,223,372,036,854,775,800",
                                    "92,233,720,368,547,758,080",
                                  ],
            baseStyle.grouping(.never): [ "9223372036854775807",
                                          "922337203685477580",
                                          "92233720368547758",
                                          "9223372036854775",
                                          "922337203685477",
                                          "92233720368547",
                                          "9223372036854",
                                          "922337203685",
                                          "92233720368",
                                          "9223372036",
                                          "922337203",
                                          "92233720",
                                          "9223372",
                                          "922337",
                                          "92233",
                                          "9223",
                                          "922",
                                          "92",
                                          "9",
                                          "0",
                                          "-9",
                                          "-92",
                                          "-922",
                                          "-9223",
                                          "-92233",
                                          "-922337",
                                          "-9223372",
                                          "-92233720",
                                          "-922337203",
                                          "-9223372036",
                                          "-92233720368",
                                          "-922337203685",
                                          "-9223372036854",
                                          "-92233720368547",
                                          "-922337203685477",
                                          "-9223372036854775",
                                          "-92233720368547758",
                                          "-922337203685477580",
                                          "-9223372036854775808",
                                        ],
        ]

        for (style, expectedStrings) in expectations {
            for i in 0..<exhaustiveIntNumbers.count {
                #expect(style.format(Int(exhaustiveIntNumbers[i])) == expectedStrings[i], "Style: \(style.collection.debugDescription) is failing")
            }
        }
    }

    @Test func test_plainStyle_signStrategy() throws {
        let expectations: [IntegerFormatStyle<Int> : [String]] = [
            baseStyle.sign(strategy: .never): [ "9,223,372,036,854,775,807",
                                                "922,337,203,685,477,580",
                                                "92,233,720,368,547,758",
                                                "9,223,372,036,854,775",
                                                "922,337,203,685,477",
                                                "92,233,720,368,547",
                                                "9,223,372,036,854",
                                                "922,337,203,685",
                                                "92,233,720,368",
                                                "9,223,372,036",
                                                "922,337,203",
                                                "92,233,720",
                                                "9,223,372",
                                                "922,337",
                                                "92,233",
                                                "9,223",
                                                "922",
                                                "92",
                                                "9",
                                                "0",
                                                "9",
                                                "92",
                                                "922",
                                                "9,223",
                                                "92,233",
                                                "922,337",
                                                "9,223,372",
                                                "92,233,720",
                                                "922,337,203",
                                                "9,223,372,036",
                                                "92,233,720,368",
                                                "922,337,203,685",
                                                "9,223,372,036,854",
                                                "92,233,720,368,547",
                                                "922,337,203,685,477",
                                                "9,223,372,036,854,775",
                                                "92,233,720,368,547,758",
                                                "922,337,203,685,477,580",
                                                "9,223,372,036,854,775,808",
                                              ],
            baseStyle.sign(strategy: .always(includingZero: false)): [ "+9,223,372,036,854,775,807",
                                                                       "+922,337,203,685,477,580",
                                                                       "+92,233,720,368,547,758",
                                                                       "+9,223,372,036,854,775",
                                                                       "+922,337,203,685,477",
                                                                       "+92,233,720,368,547",
                                                                       "+9,223,372,036,854",
                                                                       "+922,337,203,685",
                                                                       "+92,233,720,368",
                                                                       "+9,223,372,036",
                                                                       "+922,337,203",
                                                                       "+92,233,720",
                                                                       "+9,223,372",
                                                                       "+922,337",
                                                                       "+92,233",
                                                                       "+9,223",
                                                                       "+922",
                                                                       "+92",
                                                                       "+9",
                                                                       "0",
                                                                       "-9",
                                                                       "-92",
                                                                       "-922",
                                                                       "-9,223",
                                                                       "-92,233",
                                                                       "-922,337",
                                                                       "-9,223,372",
                                                                       "-92,233,720",
                                                                       "-922,337,203",
                                                                       "-9,223,372,036",
                                                                       "-92,233,720,368",
                                                                       "-922,337,203,685",
                                                                       "-9,223,372,036,854",
                                                                       "-92,233,720,368,547",
                                                                       "-922,337,203,685,477",
                                                                       "-9,223,372,036,854,775",
                                                                       "-92,233,720,368,547,758",
                                                                       "-922,337,203,685,477,580",
                                                                       "-9,223,372,036,854,775,808",
                                                                     ],
            baseStyle.sign(strategy: .always(includingZero: true)): [ "+9,223,372,036,854,775,807",
                                                                      "+922,337,203,685,477,580",
                                                                      "+92,233,720,368,547,758",
                                                                      "+9,223,372,036,854,775",
                                                                      "+922,337,203,685,477",
                                                                      "+92,233,720,368,547",
                                                                      "+9,223,372,036,854",
                                                                      "+922,337,203,685",
                                                                      "+92,233,720,368",
                                                                      "+9,223,372,036",
                                                                      "+922,337,203",
                                                                      "+92,233,720",
                                                                      "+9,223,372",
                                                                      "+922,337",
                                                                      "+92,233",
                                                                      "+9,223",
                                                                      "+922",
                                                                      "+92",
                                                                      "+9",
                                                                      "+0",
                                                                      "-9",
                                                                      "-92",
                                                                      "-922",
                                                                      "-9,223",
                                                                      "-92,233",
                                                                      "-922,337",
                                                                      "-9,223,372",
                                                                      "-92,233,720",
                                                                      "-922,337,203",
                                                                      "-9,223,372,036",
                                                                      "-92,233,720,368",
                                                                      "-922,337,203,685",
                                                                      "-9,223,372,036,854",
                                                                      "-92,233,720,368,547",
                                                                      "-922,337,203,685,477",
                                                                      "-9,223,372,036,854,775",
                                                                      "-92,233,720,368,547,758",
                                                                      "-922,337,203,685,477,580",
                                                                      "-9,223,372,036,854,775,808",
                                                                    ],
        ]
        for (style, expectedStrings) in expectations {
            for i in 0..<exhaustiveIntNumbers.count {
                #expect(style.format(Int(exhaustiveIntNumbers[i])) == expectedStrings[i], "Style: \(style.collection.debugDescription) is failing")
            }
        }
    }
    @Test func plainStyle_rounded() throws {
        let expectations: [IntegerFormatStyle<Int> : [String]] = [
            baseStyle.rounded(rule: .toNearestOrEven, increment: 5): [ "9,223,372,036,854,775,805",
                                                                       "922,337,203,685,477,580",
                                                                       "92,233,720,368,547,760",
                                                                       "9,223,372,036,854,775",
                                                                       "922,337,203,685,475",
                                                                       "92,233,720,368,545",
                                                                       "9,223,372,036,855",
                                                                       "922,337,203,685",
                                                                       "92,233,720,370",
                                                                       "9,223,372,035",
                                                                       "922,337,205",
                                                                       "92,233,720",
                                                                       "9,223,370",
                                                                       "922,335",
                                                                       "92,235",
                                                                       "9,225",
                                                                       "920",
                                                                       "90",
                                                                       "10",
                                                                       "0",
                                                                       "-10",
                                                                       "-90",
                                                                       "-920",
                                                                       "-9,225",
                                                                       "-92,235",
                                                                       "-922,335",
                                                                       "-9,223,370",
                                                                       "-92,233,720",
                                                                       "-922,337,205",
                                                                       "-9,223,372,035",
                                                                       "-92,233,720,370",
                                                                       "-922,337,203,685",
                                                                       "-9,223,372,036,855",
                                                                       "-92,233,720,368,545",
                                                                       "-922,337,203,685,475",
                                                                       "-9,223,372,036,854,775",
                                                                       "-92,233,720,368,547,760",
                                                                       "-922,337,203,685,477,580",
                                                                       "-9,223,372,036,854,775,810",
                                                                     ],
            baseStyle.rounded(rule: .toNearestOrEven, increment: 100): [    "9,223,372,036,854,775,800",
                                                                            "922,337,203,685,477,600",
                                                                            "92,233,720,368,547,800",
                                                                            "9,223,372,036,854,800",
                                                                            "922,337,203,685,500",
                                                                            "92,233,720,368,500",
                                                                            "9,223,372,036,900",
                                                                            "922,337,203,700",
                                                                            "92,233,720,400",
                                                                            "9,223,372,000",
                                                                            "922,337,200",
                                                                            "92,233,700",
                                                                            "9,223,400",
                                                                            "922,300",
                                                                            "92,200",
                                                                            "9,200",
                                                                            "900",
                                                                            "100",
                                                                            "0",
                                                                            "0",
                                                                            "-0",
                                                                            "-100",
                                                                            "-900",
                                                                            "-9,200",
                                                                            "-92,200",
                                                                            "-922,300",
                                                                            "-9,223,400",
                                                                            "-92,233,700",
                                                                            "-922,337,200",
                                                                            "-9,223,372,000",
                                                                            "-92,233,720,400",
                                                                            "-922,337,203,700",
                                                                            "-9,223,372,036,900",
                                                                            "-92,233,720,368,500",
                                                                            "-922,337,203,685,500",
                                                                            "-9,223,372,036,854,800",
                                                                            "-92,233,720,368,547,800",
                                                                            "-922,337,203,685,477,600",
                                                                            "-9,223,372,036,854,775,800",
                                                                       ],
        ]

        for (idx, (style, expectedStrings)) in expectations.enumerated() {
            for i in 0..<exhaustiveIntNumbers.count {
                #expect(style.format(Int(exhaustiveIntNumbers[i])) == expectedStrings[i], "Style: \(style.collection.debugDescription) is failing for #\(idx), #\(i)")
            }
        }
    }

#if FOUNDATION_FRAMEWORK // Re-enable this test when ICU is updated to 72
    @Test func plainStyle_rounded_largeIncrement() {
        let style = baseStyle.rounded(rule: .up, increment: Int.max)

        let expectations = [
            "9,223,372,036,854,775,807",
            "9,223,372,036,854,775,807",
            "9,223,372,036,854,775,807",
            "9,223,372,036,854,775,807",
            "9,223,372,036,854,775,807",
            "9,223,372,036,854,775,807",
            "9,223,372,036,854,775,807",
            "9,223,372,036,854,775,807",
            "9,223,372,036,854,775,807",
            "9,223,372,036,854,775,807",
            "9,223,372,036,854,775,807",
            "9,223,372,036,854,775,807",
            "9,223,372,036,854,775,807",
            "9,223,372,036,854,775,807",
            "9,223,372,036,854,775,807",
            "9,223,372,036,854,775,807",
            "9,223,372,036,854,775,807",
            "9,223,372,036,854,775,807",
            "9,223,372,036,854,775,807",
            "0",
            "-0",
            "-0",
            "-0",
            "-0",
            "-0",
            "-0",
            "-0",
            "-0",
            "-0",
            "-0",
            "-0",
            "-0",
            "-0",
            "-0",
            "-0",
            "-0",
            "-0",
            "-0",
            "-9,223,372,036,854,775,807",
        ]
        for i in 0..<exhaustiveIntNumbers.count {
            #expect(style.format(Int(exhaustiveIntNumbers[i])) == expectations[i], "Style: \(style.collection.debugDescription) is failing for number #\(Int(exhaustiveIntNumbers[i]))")
        }
    }
#endif

    @Test func plainStyle_scientific() throws {
        let expectations: [IntegerFormatStyle<Int> : [String]] = [
            baseStyle.notation(.scientific): [ "9.223372E18",
                                              "9.223372E17",
                                              "9.223372E16",
                                              "9.223372E15",
                                              "9.223372E14",
                                              "9.223372E13",
                                              "9.223372E12",
                                              "9.223372E11",
                                              "9.223372E10",
                                              "9.223372E9",
                                              "9.223372E8",
                                              "9.223372E7",
                                              "9.223372E6",
                                              "9.22337E5",
                                              "9.2233E4",
                                              "9.223E3",
                                              "9.22E2",
                                              "9.2E1",
                                              "9E0",
                                              "0E0",
                                              "-9E0",
                                              "-9.2E1",
                                              "-9.22E2",
                                              "-9.223E3",
                                              "-9.2233E4",
                                              "-9.22337E5",
                                              "-9.223372E6",
                                              "-9.223372E7",
                                              "-9.223372E8",
                                              "-9.223372E9",
                                              "-9.223372E10",
                                              "-9.223372E11",
                                              "-9.223372E12",
                                              "-9.223372E13",
                                              "-9.223372E14",
                                              "-9.223372E15",
                                              "-9.223372E16",
                                              "-9.223372E17",
                                              "-9.223372E18",
                                            ],
            baseStyle.precision(.significantDigits(2...2)).notation(.scientific): [
                 "9.2E18",
                 "9.2E17",
                 "9.2E16",
                 "9.2E15",
                 "9.2E14",
                 "9.2E13",
                 "9.2E12",
                 "9.2E11",
                 "9.2E10",
                 "9.2E9",
                 "9.2E8",
                 "9.2E7",
                 "9.2E6",
                 "9.2E5",
                 "9.2E4",
                 "9.2E3",
                 "9.2E2",
                 "9.2E1",
                 "9.0E0",
                 "0.0E0",
                 "-9.0E0",
                 "-9.2E1",
                 "-9.2E2",
                 "-9.2E3",
                 "-9.2E4",
                 "-9.2E5",
                 "-9.2E6",
                 "-9.2E7",
                 "-9.2E8",
                 "-9.2E9",
                 "-9.2E10",
                 "-9.2E11",
                 "-9.2E12",
                 "-9.2E13",
                 "-9.2E14",
                 "-9.2E15",
                 "-9.2E16",
                 "-9.2E17",
                 "-9.2E18",
               ],
            baseStyle.notation(.scientific).precision(.fractionLength(2...2)): [
                  "9.22E18",
                  "9.22E17",
                  "9.22E16",
                  "9.22E15",
                  "9.22E14",
                  "9.22E13",
                  "9.22E12",
                  "9.22E11",
                  "9.22E10",
                  "9.22E9",
                  "9.22E8",
                  "9.22E7",
                  "9.22E6",
                  "9.22E5",
                  "9.22E4",
                  "9.22E3",
                  "9.22E2",
                  "9.20E1",
                  "9.00E0",
                  "0.00E0",
                  "-9.00E0",
                  "-9.20E1",
                  "-9.22E2",
                  "-9.22E3",
                  "-9.22E4",
                  "-9.22E5",
                  "-9.22E6",
                  "-9.22E7",
                  "-9.22E8",
                  "-9.22E9",
                  "-9.22E10",
                  "-9.22E11",
                  "-9.22E12",
                  "-9.22E13",
                  "-9.22E14",
                  "-9.22E15",
                  "-9.22E16",
                  "-9.22E17",
                  "-9.22E18",
                ],
        ]
        for (style, expectedStrings) in expectations {
            for i in 0..<exhaustiveIntNumbers.count {
                #expect(style.format(Int(exhaustiveIntNumbers[i])) == expectedStrings[i], "Style: \(style.collection.debugDescription) is failing")
            }
        }
    }

    @Test func plainStyle_compactName() throws {
        let expectations: [IntegerFormatStyle<Int> : [String]] = [
            // `compactName` naturally rounds the number to the closest "name".
            baseStyle.precision(.significantDigits(2...2)).notation(.compactName): [
                "9,200,000T",
                "920,000T",
                "92,000T",
                "9200T",
                "920T",
                "92T",
                "9.2T",
                "920B",
                "92B",
                "9.2B",
                "920M",
                "92M",
                "9.2M",
                "920K",
                "92K",
                "9.2K",
                "920",
                "92",
                "9.0",
                "0.0",
                "-9.0",
                "-92",
                "-920",
                "-9.2K",
                "-92K",
                "-920K",
                "-9.2M",
                "-92M",
                "-920M",
                "-9.2B",
                "-92B",
                "-920B",
                "-9.2T",
                "-92T",
                "-920T",
                "-9200T",
                "-92,000T",
                "-920,000T",
                "-9,200,000T",
            ],
            baseStyle.notation(.compactName).precision(.fractionLength(2...2)): [
                "9,223,372.04T",
                "922,337.20T",
                "92,233.72T",
                "9223.37T",
                "922.34T",
                "92.23T",
                "9.22T",
                "922.34B",
                "92.23B",
                "9.22B",
                "922.34M",
                "92.23M",
                "9.22M",
                "922.34K",
                "92.23K",
                "9.22K",
                "922.00",
                "92.00",
                "9.00",
                "0.00",
                "-9.00",
                "-92.00",
                "-922.00",
                "-9.22K",
                "-92.23K",
                "-922.34K",
                "-9.22M",
                "-92.23M",
                "-922.34M",
                "-9.22B",
                "-92.23B",
                "-922.34B",
                "-9.22T",
                "-92.23T",
                "-922.34T",
                "-9223.37T",
                "-92,233.72T",
                "-922,337.20T",
                "-9,223,372.04T",
            ],
            baseStyle.notation(.compactName).rounded(rule: .awayFromZero, increment: 100): [
                "9,223,400T",
                "922,400T",
                "92,300T",
                "9300T",
                "1000T",
                "100T",
                "100T",
                "100T",
                "100B",
                "100B",
                "100B",
                "100M",
                "100M",
                "100M",
                "100K",
                "100K",
                "100K",
                "100",
                "100",
                "0",
                "-100",
                "-100",
                "-100K",
                "-100K",
                "-100K",
                "-100M",
                "-100M",
                "-100M",
                "-100B",
                "-100B",
                "-100B",
                "-100T",
                "-100T",
                "-100T",
                "-1000T",
                "-9300T",
                "-92,300T",
                "-922,400T",
                "-9,223,400T",
            ],
        ]
        for (style, expectedStrings) in expectations {
            for i in 0..<exhaustiveIntNumbers.count {
                #expect(style.format(Int(exhaustiveIntNumbers[i])) == expectedStrings[i], "Style: \(style.collection.debugDescription) is failing")
            }
        }
    }
}

#endif // !os(watchOS)

// MARK: - Attributed string

fileprivate typealias Segment = (String, AttributeScopes.FoundationAttributes.NumberFormatAttributes.NumberPartAttribute.NumberPart?, AttributeScopes.FoundationAttributes.NumberFormatAttributes.SymbolAttribute.Symbol?)

extension Sequence where Element == Segment {
    var attributedString: AttributedString {
        self.map { tuple in
            if tuple.1 == nil && tuple.2 == nil {
                return AttributedString(tuple.0)
            } else if let partAttr = tuple.1, let symbolAttr = tuple.2 {
                return AttributedString(tuple.0, attributes: .init().numberSymbol(symbolAttr).numberPart(partAttr))
            } else if let partAttr = tuple.1 {
                return AttributedString(tuple.0, attributes: .init().numberPart(partAttr))
            } else {
                return AttributedString(tuple.0, attributes: .init().numberSymbol(tuple.2!))
            }
        }.reduce(AttributedString(), +)
    }
}

extension AttributedString {
    fileprivate var string: String {
        String(self.characters)
    }
}

@Suite("Number Attributed FormatStyle")
private struct NumberAttributedFormatStyleTests {
    let enUS = Locale(identifier: "en_US")
    let frFR = Locale(identifier: "fr_FR")

    @Test func integerStyle() throws {
        let style = IntegerFormatStyle<Int>(locale: enUS)
        let value = -12345
        let expectations: [IntegerFormatStyle<Int> : [Segment]] = [
            style: [("-", nil, .sign), ("12", .integer, nil), (",", .integer, .groupingSeparator), ("345", .integer, nil)],
            style.precision(.fractionLength(2...2)): [("-", nil, .sign), ("12", .integer, nil), (",", .integer, .groupingSeparator), ("345", .integer, nil), (".", nil, .decimalSeparator), ("00", .fraction, nil )],
            style.grouping(.never): [("-", nil, .sign), ("12345", .integer, nil)],
            style.decimalSeparator(strategy: .always): [("-", nil, .sign), ("12", .integer, nil), (",", .integer, .groupingSeparator), ("345", .integer, nil), (".", nil, .decimalSeparator)],
        ]

        for (style, expectation) in expectations {
            let formatted = style.attributed.format(value)
            #expect(formatted == expectation.attributedString)
        }
    }

    @Test func integerStyle_Currency() throws {
        let style = IntegerFormatStyle<Int>.Currency(code: "EUR", locale: enUS)
        let value = -12345
        let expectations: [IntegerFormatStyle<Int>.Currency : [Segment]] = [
            style: [("-", nil, .sign), ("€", nil, .currency), ("12", .integer, nil), (",", .integer, .groupingSeparator), ("345", .integer, nil), (".", nil, .decimalSeparator), ("00", .fraction, nil)],
            style.grouping(.never): [("-", nil, .sign), ("€", nil, .currency), ("12345", .integer, nil), (".", nil, .decimalSeparator), ("00", .fraction, nil)],
            style.sign(strategy: .accounting): [("(", nil, nil), ("€", nil, .currency), ("12", .integer, nil), (",", .integer, .groupingSeparator), ("345", .integer, nil), (".", nil, .decimalSeparator), ("00", .fraction, nil), (")", nil, nil)],
        ]

        for (style, expectation) in expectations {
            let formatted = style.attributed.format(value)
            #expect(formatted == expectation.attributedString)
        }
    }

    @Test func integerStyle_Percent() throws {
        let style = IntegerFormatStyle<Int>.Percent(locale: enUS)
        let value = -12345
        let expectations: [IntegerFormatStyle<Int>.Percent : [Segment]] = [
            style: [("-", nil, .sign), ("12", .integer, nil), (",", .integer, .groupingSeparator), ("345", .integer, nil), ("%", nil, .percent)],
            style.precision(.fractionLength(2...2)): [("-", nil, .sign), ("12", .integer, nil), (",", .integer, .groupingSeparator), ("345", .integer, nil), (".", nil, .decimalSeparator), ("00", .fraction, nil), ("%", nil, .percent)],
        ]

        for (style, expectation) in expectations {
            let formatted = style.attributed.format(value)
            #expect(formatted == expectation.attributedString)
        }
    }

    @Test func floatingPoint() throws {
        let style: FloatingPointFormatStyle<Double> = .init(locale: enUS)
        let value = -3000.14
        #expect(style.attributed.format(value) ==
                       [("-", nil, .sign), ("3", .integer, nil), (",", .integer, .groupingSeparator), ("000", .integer, nil), (".", nil, .decimalSeparator), ("14", .fraction, nil)].attributedString)
        #expect(style.precision(.fractionLength(3...3)).attributed.format(value) ==
                       [("-", nil, .sign), ("3", .integer, nil), (",", .integer, .groupingSeparator), ("000", .integer, nil), (".", nil, .decimalSeparator), ("140", .fraction, nil)].attributedString)
        #expect(style.grouping(.never).attributed.format(value) ==
                       [("-", nil, .sign), ("3000", .integer, nil), (".", nil, .decimalSeparator), ("14", .fraction, nil)].attributedString)

        let percent: FloatingPointFormatStyle<Double>.Percent = .init(locale: enUS)
        #expect(percent.attributed.format(value) ==
                       [("-", nil, .sign), ("300", .integer, nil), (",", .integer, .groupingSeparator), ("014", .integer, nil), ("%", nil, .percent)].attributedString)

        let currency: FloatingPointFormatStyle<Double>.Currency = .init(code: "EUR", locale: Locale(identifier: "zh_TW"))
        #expect(currency.grouping(.never).attributed.format(value) ==
                       [("-", nil, .sign), ("€", nil, .currency), ("3000", .integer, nil), (".", nil, .decimalSeparator), ("14", .fraction, nil)].attributedString)
        #expect(currency.presentation(.fullName).attributed.format(value) ==
                       [("-", nil, .sign), ("3", .integer, nil), (",", .integer, .groupingSeparator), ("000", .integer, nil), (".", nil, .decimalSeparator), ("14", .fraction, nil), ("歐元", nil, .currency)].attributedString)

    }

    @Test func decimalStyle() throws {
        let style = Decimal.FormatStyle(locale: enUS)
        let value = Decimal(-3000.14)
        #expect(style.attributed.format(value) ==
                       [("-", nil, .sign), ("3", .integer, nil), (",", .integer, .groupingSeparator), ("000", .integer, nil), (".", nil, .decimalSeparator), ("14", .fraction, nil)].attributedString)
        #expect(style.precision(.fractionLength(3...3)).attributed.format(value) ==
                       [("-", nil, .sign), ("3", .integer, nil), (",", .integer, .groupingSeparator), ("000", .integer, nil), (".", nil, .decimalSeparator), ("140", .fraction, nil)].attributedString)
        #expect(style.grouping(.never).attributed.format(value) ==
                       [("-", nil, .sign), ("3000", .integer, nil), (".", nil, .decimalSeparator), ("14", .fraction, nil)].attributedString)

        let percent = Decimal.FormatStyle.Percent(locale: enUS)
        #expect(percent.attributed.format(value) ==
                       [("-", nil, .sign), ("300", .integer, nil), (",", .integer, .groupingSeparator), ("014", .integer, nil), ("%", nil, .percent)].attributedString)

        let currency = Decimal.FormatStyle.Currency(code: "EUR", locale: Locale(identifier: "zh_TW"))
        #expect(currency.grouping(.never).attributed.format(value) ==
                       [("-", nil, .sign), ("€", nil, .currency), ("3000", .integer, nil), (".", nil, .decimalSeparator), ("14", .fraction, nil)].attributedString)
        #expect(currency.presentation(.fullName).attributed.format(value) ==
                       [("-", nil, .sign), ("3", .integer, nil), (",", .integer, .groupingSeparator), ("000", .integer, nil), (".", nil, .decimalSeparator), ("14", .fraction, nil), ("歐元", nil, .currency)].attributedString)
    }

    @Test func settingLocale() throws {
        let int = 42000
        let double = 42000.123
        let decimal = Decimal(42000.123)

        #expect(int.formatted(.number.attributed.locale(enUS)).string == "42,000")
        #expect(int.formatted(.number.attributed.locale(frFR)).string == "42 000")

        #expect(int.formatted(.number.locale(enUS).attributed).string == "42,000")
        #expect(int.formatted(.number.locale(frFR).attributed).string == "42 000")

        #expect(int.formatted(.percent.attributed.locale(enUS)).string == "42,000%")
        #expect(int.formatted(.percent.attributed.locale(frFR)).string == "42 000 %")

        #expect(int.formatted(.percent.locale(enUS).attributed).string == "42,000%")
        #expect(int.formatted(.percent.locale(frFR).attributed).string == "42 000 %")

        #expect(int.formatted(.currency(code: "USD").presentation(.fullName).attributed.locale(enUS)).string == "42,000.00 US dollars")
        #expect(int.formatted(.currency(code: "USD").presentation(.fullName).attributed.locale(frFR)).string == "42 000,00 dollars des États-Unis")

        #expect(int.formatted(.currency(code: "USD").presentation(.fullName).locale(enUS).attributed).string == "42,000.00 US dollars")
        #expect(int.formatted(.currency(code: "USD").presentation(.fullName).locale(frFR).attributed).string == "42 000,00 dollars des États-Unis")

        // Double

        #expect(double.formatted(FloatingPointFormatStyle.number.attributed.locale(enUS)).string == "42,000.123")
        #expect(double.formatted(FloatingPointFormatStyle.number.attributed.locale(frFR)).string == "42 000,123")

        #expect(double.formatted(FloatingPointFormatStyle.number.locale(enUS).attributed).string == "42,000.123")
        #expect(double.formatted(FloatingPointFormatStyle.number.locale(frFR).attributed).string == "42 000,123")

        #expect(double.formatted(FloatingPointFormatStyle.Percent.percent.attributed.locale(enUS)).string == "4,200,012.3%")
        #expect(double.formatted(FloatingPointFormatStyle.Percent.percent.attributed.locale(frFR)).string == "4 200 012,3 %")

        #expect(double.formatted(FloatingPointFormatStyle.Percent.percent.locale(enUS).attributed).string == "4,200,012.3%")
        #expect(double.formatted(FloatingPointFormatStyle.Percent.percent.locale(frFR).attributed).string == "4 200 012,3 %")

        #expect(double.formatted(.currency(code: "USD").presentation(.fullName).attributed.locale(enUS)).string == "42,000.12 US dollars")
        #expect(double.formatted(.currency(code: "USD").presentation(.fullName).attributed.locale(frFR)).string == "42 000,12 dollars des États-Unis")

        #expect(double.formatted(.currency(code: "USD").presentation(.fullName).locale(enUS).attributed).string == "42,000.12 US dollars")
        #expect(double.formatted(.currency(code: "USD").presentation(.fullName).locale(frFR).attributed).string == "42 000,12 dollars des États-Unis")

        // Decimal

        #expect(decimal.formatted(.number.attributed.locale(enUS)).string == "42,000.123")
        #expect(decimal.formatted(.number.attributed.locale(frFR)).string == "42 000,123")

        #expect(decimal.formatted(.number.locale(enUS).attributed).string == "42,000.123")
        #expect(decimal.formatted(.number.locale(frFR).attributed).string == "42 000,123")

        #expect(decimal.formatted(.percent.attributed.locale(enUS)).string == "4,200,012.3%")
        #expect(decimal.formatted(.percent.attributed.locale(frFR)).string == "4 200 012,3 %")

        #expect(decimal.formatted(.percent.locale(enUS).attributed).string == "4,200,012.3%")
        #expect(decimal.formatted(.percent.locale(frFR).attributed).string == "4 200 012,3 %")

        #expect(decimal.formatted(.currency(code: "USD").presentation(.fullName).attributed.locale(enUS)).string == "42,000.12 US dollars")
        #expect(decimal.formatted(.currency(code: "USD").presentation(.fullName).attributed.locale(frFR)).string == "42 000,12 dollars des États-Unis")

        #expect(decimal.formatted(.currency(code: "USD").presentation(.fullName).locale(enUS).attributed).string == "42,000.12 US dollars")
        #expect(decimal.formatted(.currency(code: "USD").presentation(.fullName).locale(frFR).attributed).string == "42 000,12 dollars des États-Unis")
    }
}

// MARK: Pattern Matching
@Suite("FormatStyle Pattern Matching")
private struct FormatStylePatternMatchingTests {
    let frFR = Locale(identifier: "fr_FR")
    let enUS = Locale(identifier: "en_US")

    typealias TestCase = (string: String, style: IntegerFormatStyle<Int>, value: Int?)

    @Test func integerFormatStyle_Consumer() {
        let style: IntegerFormatStyle<Int> = .init()
        let string = "42,000,000"

        _verifyMatching(string, formatStyle: style, expectedUpperBound: string.endIndex, expectedValue: 42000000)
        _verifyMatching("\(string) text", formatStyle: style, expectedUpperBound: string.endIndex, expectedValue: 42000000)
        // We can't find a match because the matching starts at the first character
        let newStr = "text \(string)"
        _verifyMatching(newStr, formatStyle: style, expectedUpperBound: nil, expectedValue: nil)
        let matchRange = newStr.firstIndex(of: "4")! ..< newStr.endIndex
        // Now we should find a match
        _verifyMatching(newStr, formatStyle: style, range: matchRange, expectedUpperBound: newStr.endIndex, expectedValue: 42000000)
        // Invalid number
        _verifyMatching("NotANumber", formatStyle: style, expectedUpperBound: nil, expectedValue: nil)
        // Different locale
        let frenchString = "42 420 000"
        _verifyMatching(frenchString, formatStyle: style.locale(frFR), expectedUpperBound: frenchString.endIndex, expectedValue: 42420000)
        _verifyMatching("\(frenchString) pommes", formatStyle: style.locale(frFR), expectedUpperBound: frenchString.endIndex, expectedValue: 42420000)
        let newFrenchStr = "pommes \(frenchString)"
        let frenchMatchRange = newFrenchStr.firstIndex(of: "4")! ..< newFrenchStr.endIndex
        _verifyMatching(newFrenchStr, formatStyle: style.locale(frFR), range: frenchMatchRange, expectedUpperBound: newFrenchStr.endIndex, expectedValue: 42420000)
        // Different signs
        let signTests = [
            (string: "-42", value: -42),
            (string: "77", value: 77),
            (string: "0", value: 0),
        ]
        for testCase in signTests {
            _verifyMatching(testCase.string, formatStyle: style, expectedUpperBound: testCase.string.endIndex, expectedValue: testCase.value)
        }
        // Scientific notation
        let scientificTests = [
            (string: "4.2E4", value: 42000),
            (string: "-128.82E6", value: -128820000)
        ]
        for testCase in scientificTests {
            _verifyMatching(testCase.string, formatStyle: style, expectedUpperBound: testCase.string.endIndex, expectedValue: testCase.value)
        }
    }

    @Test func percentFormatStyle_Consumer() {
        let style = IntegerFormatStyle<Int>.Percent()
        let string = "42%"

        _verifyMatching(string, formatStyle: style, expectedUpperBound: string.endIndex, expectedValue: 42)
        _verifyMatching("\(string) text", formatStyle: style, expectedUpperBound: string.endIndex, expectedValue: 42)
        // We can't find a match because the matching starts at the first character
        let newStr = "text \(string)"
        _verifyMatching(newStr, formatStyle: style, expectedUpperBound: nil, expectedValue: nil)
        let matchRange = newStr.firstIndex(of: "4")! ..< newStr.endIndex
        // Now we should find a match
        _verifyMatching(newStr, formatStyle: style, range: matchRange, expectedUpperBound: newStr.endIndex, expectedValue: 42)
        // Invalid number
        _verifyMatching("NotANumber", formatStyle: style, expectedUpperBound: nil, expectedValue: nil)
        // Different locale
        let frenchString = "42 %"
        _verifyMatching(frenchString, formatStyle: style.locale(frFR), expectedUpperBound: frenchString.endIndex, expectedValue: 42)
        _verifyMatching("\(frenchString) pommes", formatStyle: style.locale(frFR), expectedUpperBound: frenchString.endIndex, expectedValue: 42)
        let newFrenchStr = "pommes \(frenchString)"
        let frenchMatchRange = newFrenchStr.firstIndex(of: "4")! ..< newFrenchStr.endIndex
        _verifyMatching(newFrenchStr, formatStyle: style.locale(frFR), range: frenchMatchRange, expectedUpperBound: newFrenchStr.endIndex, expectedValue: 42)
        // Different signs
        let signTests = [
            (string: "-45%", value: -45),
            (string: "+80%", value: 80),
            (string: "-0%", value: 0)
        ]
        for testCase in signTests {
            _verifyMatching(testCase.string, formatStyle: style.sign(strategy: .always(includingZero: true)), expectedUpperBound: testCase.string.endIndex, expectedValue: testCase.value)
        }

        // Scientific notation
        let scientificTests = [
            (string: "9.723E5%", value: 972300),
            (string: "-2.3E3%", value: -2300)
        ]
        for testCase in scientificTests {
            _verifyMatching(testCase.string, formatStyle: style, expectedUpperBound: testCase.string.endIndex, expectedValue: testCase.value)
        }
    }

    @Test func currencyFormatStyle_Consumer() {
        let style = IntegerFormatStyle<Int>.Currency(code: "USD", locale: enUS)
        let floatStyle = FloatingPointFormatStyle<Double>.Currency(code: "USD", locale: enUS)
        let decimalStyle = Decimal.FormatStyle.Currency(code: "USD", locale: enUS)

        let string = "$52,249"

        _verifyMatching(string, formatStyle: style, expectedUpperBound: string.endIndex, expectedValue: 52249)
        _verifyMatching(string, formatStyle: floatStyle, expectedUpperBound: string.endIndex, expectedValue: 52249)
        _verifyMatching(string, formatStyle: decimalStyle, expectedUpperBound: string.endIndex, expectedValue: 52249)

        _verifyMatching("\(string) seems like a lot", formatStyle: style, expectedUpperBound: string.endIndex, expectedValue: 52249)
        _verifyMatching("\(string) seems like a lot", formatStyle: floatStyle, expectedUpperBound: string.endIndex, expectedValue: 52249)
        _verifyMatching("\(string) seems like a lot", formatStyle: decimalStyle, expectedUpperBound: string.endIndex, expectedValue: Decimal(52249))

        // We can't find a match because the matching starts at the first character
        let newStr = "<fill in the blank> costs \(string)"
        _verifyMatching(newStr, formatStyle: style, expectedUpperBound: nil, expectedValue: nil)
        _verifyMatching(newStr, formatStyle: floatStyle, expectedUpperBound: nil, expectedValue: nil)
        _verifyMatching(newStr, formatStyle: decimalStyle, expectedUpperBound: nil, expectedValue: nil)

        let matchRange = newStr.firstIndex(of: "$")! ..< newStr.endIndex
        // Now we should find a match
        _verifyMatching(newStr, formatStyle: style, range: matchRange, expectedUpperBound: newStr.endIndex, expectedValue: 52249)
        _verifyMatching(newStr, formatStyle: floatStyle, range: matchRange, expectedUpperBound: newStr.endIndex, expectedValue: 52249)
        _verifyMatching(newStr, formatStyle: decimalStyle, range: matchRange, expectedUpperBound: newStr.endIndex, expectedValue: 52249)

        // Invalid USD currency
        _verifyMatching("€52,249", formatStyle: style, expectedUpperBound: nil, expectedValue: nil)
        _verifyMatching("€52,249", formatStyle: floatStyle, expectedUpperBound: nil, expectedValue: nil)
        _verifyMatching("€52,249", formatStyle: decimalStyle, expectedUpperBound: nil, expectedValue: nil)

        let frenchStyle: IntegerFormatStyle<Int>.Currency = .init(code: "EUR", locale: frFR)
        let frenchPrice = frenchStyle.format(57379)
        #expect(frenchPrice == "57 379,00 €")
        _verifyMatching("57 379,00 €", formatStyle: frenchStyle, expectedUpperBound: "57 379,00 €".endIndex, expectedValue: 57379)
        _verifyMatching("57 379 €", formatStyle: frenchStyle, expectedUpperBound: "57 379 €".endIndex, expectedValue: 57379)
        _verifyMatching("57 379,00 € semble beaucoup", formatStyle: frenchStyle, expectedUpperBound: "57 379,00 €".endIndex, expectedValue: 57379)

        // Does not match when matching with USD style
        _verifyMatching("57 379,00 €", formatStyle: floatStyle.locale(frFR), expectedUpperBound: nil, expectedValue: nil)
        _verifyMatching("57 379,00 €", formatStyle: decimalStyle.locale(frFR), expectedUpperBound: nil, expectedValue: nil)

        // Mix currency and locale
        _verifyMatching("57 379,00 $US", formatStyle: floatStyle.locale(frFR), expectedUpperBound: "57 379,00 $US".endIndex, expectedValue: 57379)
        _verifyMatching("57 379,00 $US", formatStyle: decimalStyle.locale(frFR), expectedUpperBound: "57 379,00 $US".endIndex, expectedValue: 57379)
        _verifyMatching("57 379,00 $US semble beaucoup", formatStyle: floatStyle.locale(frFR), expectedUpperBound: "57 379,00 $US".endIndex, expectedValue: 57379)
        _verifyMatching("57 379,00 $US semble beaucoup", formatStyle: decimalStyle.locale(frFR), expectedUpperBound: "57 379,00 $US".endIndex, expectedValue: 57379)

        // Range tests
        let newFrenchStr = "<remplir le blanc> coûte \(frenchPrice)"
        let frenchMatchRange = newFrenchStr.firstIndex(of: "5")! ..< newFrenchStr.endIndex
        _verifyMatching(newFrenchStr, formatStyle: frenchStyle, range: frenchMatchRange, expectedUpperBound: newFrenchStr.endIndex, expectedValue: 57379)

        // Mix currency and locale range tests
        let newFrenchUSDStr = "<remplir le blanc> coûte 57 379,00 $US"
        let usdPriceRange = newFrenchUSDStr.firstIndex(of: "5")! ..< newFrenchUSDStr.endIndex
        _verifyMatching(newFrenchUSDStr, formatStyle: floatStyle.locale(frFR), range: usdPriceRange, expectedUpperBound: newFrenchUSDStr.endIndex, expectedValue: 57379)
        _verifyMatching(newFrenchUSDStr, formatStyle: decimalStyle.locale(frFR), range: usdPriceRange, expectedUpperBound: newFrenchUSDStr.endIndex, expectedValue: 57379)

        // Sign tests
        let signTests = [
            (string: "-$8,234", value: -8234),
            (string: "+$9,654", value: 9654),
            (string: "-$0", value: 0)
        ]
        for testCase in signTests {
            _verifyMatching(testCase.string, formatStyle: style.sign(strategy: .always()), expectedUpperBound: testCase.string.endIndex, expectedValue: testCase.value)
            _verifyMatching(testCase.string, formatStyle: floatStyle.sign(strategy: .always()), expectedUpperBound: testCase.string.endIndex, expectedValue: Double(testCase.value))
            _verifyMatching(testCase.string, formatStyle: decimalStyle.sign(strategy: .always()), expectedUpperBound: testCase.string.endIndex, expectedValue: Decimal(string: "\(testCase.value)"))
        }
        // Scientific notation
        let scientificTests = [
            (string: "$1.023E5", value: 102300),
            (string: "-$3.1415E5", value: -314150)
        ]
        for testCase in scientificTests {
            _verifyMatching(testCase.string, formatStyle: style, expectedUpperBound: testCase.string.endIndex, expectedValue: testCase.value)
            _verifyMatching(testCase.string, formatStyle: floatStyle, expectedUpperBound: testCase.string.endIndex, expectedValue: Double(testCase.value))
            _verifyMatching(testCase.string, formatStyle: decimalStyle, expectedUpperBound: testCase.string.endIndex, expectedValue: Decimal(string: "\(testCase.value)"))
        }

        // Decimal point
        let decimalPointTests = [
            (string: "-$8,234.245", value: -8234.245),
            (string: "+$9,654.88", value: 9654.88),
            (string: "-$0.75", value: -0.75),
            (string: "-$34,567.", value: -34567),
        ]
        for testCase in decimalPointTests {
            _verifyMatching(testCase.string, formatStyle: style.sign(strategy: .always()), expectedUpperBound: testCase.string.endIndex, expectedValue: Int(testCase.value))
            _verifyMatching(testCase.string, formatStyle: floatStyle.sign(strategy: .always()), expectedUpperBound: testCase.string.endIndex, expectedValue: testCase.value)
            _verifyMatching(testCase.string, formatStyle: decimalStyle.sign(strategy: .always()), expectedUpperBound: testCase.string.endIndex, expectedValue: Decimal(string: "\(testCase.value)"))
        }
    }

    @Test func matchPartialRange_Number() {
        let decimalStyle = Decimal.FormatStyle(locale: enUS)
        let intStyle = IntegerFormatStyle<Int>(locale: enUS)
        let floatStyle = FloatingPointFormatStyle<Double>(locale: enUS)
        let string = "12,345,678,900"

        _match(string, decimalStyle, range: 0..<6,
               expectedUpperBound: 6, expectedValue: 12345) // "12,345"
        _match(string, decimalStyle, range: 0..<7,
               expectedUpperBound: 6, expectedValue: 12345) // "12,345,"

        _match(string, decimalStyle, range: 0..<10,
               expectedUpperBound: 10, expectedValue: 12345678) // "12,345,678"
        _match(string, decimalStyle, range: 0..<11,
               expectedUpperBound: 10, expectedValue: 12345678) // "12,345,678,"

        _match(string, decimalStyle, range: 3..<10,
               expectedUpperBound: 10, expectedValue: 345678) // "345,678"
        _match(string, decimalStyle, range: 3..<11,
               expectedUpperBound: 10, expectedValue: 345678) // "345,678,"

        // Test starting at non-zero position
        _match(string, decimalStyle, startingAt: 1, range: 0..<6,
               expectedUpperBound: 6, expectedValue: 2345) // "2,345"
        _match(string, decimalStyle, startingAt: 3, range: 0..<6,
               expectedUpperBound: 6, expectedValue: 345) // "345"

        _match(string, decimalStyle, startingAt: 7, range: 3..<10,
               expectedUpperBound: 10, expectedValue: 678) // "678"
        _match(string, decimalStyle, startingAt: 7, range: 3..<11,
               expectedUpperBound: 10, expectedValue: 678) // "678,"

        /*
        // FIXME: This matches ",345" as it matches ICU's decimal format "#,##0.###"
        // but would this come as unexpected?
        _match(string, style, startingAt: 2, range: 0..<6,
               expectedUpperBound: nil, expectedValue: nil) // ",345"
        */


        _match(string, intStyle, range: 0..<6,
               expectedUpperBound: 6, expectedValue: 12345) // "12,345"
        _match(string, intStyle, range: 0..<7,
               expectedUpperBound: 6, expectedValue: 12345) // "12,345,"

        _match(string, intStyle, range: 0..<10,
               expectedUpperBound: 10, expectedValue: 12345678) // "12,345,678"
        _match(string, intStyle, range: 0..<11,
               expectedUpperBound: 10, expectedValue: 12345678) // "12,345,678,"

        _match(string, intStyle, range: 3..<10,
               expectedUpperBound: 10, expectedValue: 345678) // "345,678"
        _match(string, intStyle, range: 3..<11,
               expectedUpperBound: 10, expectedValue: 345678) // "345,678,"

        // Test starting at non-zero position
        _match(string, intStyle, startingAt: 1, range: 0..<6,
               expectedUpperBound: 6, expectedValue: 2345) // "2,345"
        _match(string, intStyle, startingAt: 3, range: 0..<6,
               expectedUpperBound: 6, expectedValue: 345) // "345"

        _match(string, intStyle, startingAt: 7, range: 3..<10,
               expectedUpperBound: 10, expectedValue: 678) // "678"
        _match(string, intStyle, startingAt: 7, range: 3..<11,
               expectedUpperBound: 10, expectedValue: 678) // "678,"

        _match(string, floatStyle, range: 0..<6,
               expectedUpperBound: 6, expectedValue: 12345) // "12,345"
        _match(string, floatStyle, range: 0..<7,
               expectedUpperBound: 6, expectedValue: 12345) // "12,345,"

        _match(string, floatStyle, range: 0..<10,
               expectedUpperBound: 10, expectedValue: 12345678) // "12,345,678"
        _match(string, floatStyle, range: 0..<11,
               expectedUpperBound: 10, expectedValue: 12345678) // "12,345,678,"

        _match(string, floatStyle, range: 3..<10,
               expectedUpperBound: 10, expectedValue: 345678) // "345,678"
        _match(string, floatStyle, range: 3..<11,
               expectedUpperBound: 10, expectedValue: 345678) // "345,678,"

        // Test starting at non-zero position
        _match(string, floatStyle, startingAt: 1, range: 0..<6,
               expectedUpperBound: 6, expectedValue: 2345) // "2,345"
        _match(string, floatStyle, startingAt: 3, range: 0..<6,
               expectedUpperBound: 6, expectedValue: 345) // "345"

        _match(string, floatStyle, startingAt: 7, range: 3..<10,
               expectedUpperBound: 10, expectedValue: 678) // "678"
        _match(string, floatStyle, startingAt: 7, range: 3..<11,
               expectedUpperBound: 10, expectedValue: 678) // "678,"

        let floatString = "3.14159"

        _match(floatString, intStyle, range: 0..<7, expectedUpperBound: 7, expectedValue: 3) // "3.14159"
        _match(floatString, intStyle, range: 0..<3, expectedUpperBound: 3, expectedValue: 3) // "3.1"
        _match(floatString, intStyle, range: 0..<2, expectedUpperBound: 2, expectedValue: 3) // "3."
        _match(floatString, intStyle, startingAt: 1, range: 0..<3, expectedUpperBound: 3, expectedValue: 0) // ".1"
        _match(floatString, intStyle, startingAt: 5, range: 0..<7, expectedUpperBound: 7, expectedValue: 59) // "59"

        _match(floatString, floatStyle, range: 0..<7, expectedUpperBound: 7, expectedValue: 3.14159) // "3.14159"
        _match(floatString, floatStyle, range: 0..<3, expectedUpperBound: 3, expectedValue: 3.1) // "3.1"
        _match(floatString, floatStyle, range: 0..<2, expectedUpperBound: 2, expectedValue: 3) // "3."
        _match(floatString, floatStyle, startingAt: 1, range: 0..<3, expectedUpperBound: 3, expectedValue: 0.1) // ".1"
        _match(floatString, floatStyle, startingAt: 5, range: 0..<7, expectedUpperBound: 7, expectedValue: 59) // "59"

        _match(floatString, decimalStyle, range: 0..<7, expectedUpperBound: 7, expectedValue: Decimal(string: "3.14159")!) // "3.14159"
        _match(floatString, decimalStyle, range: 0..<3, expectedUpperBound: 3, expectedValue: Decimal(string: "3.1")!) // "3.1"
        _match(floatString, decimalStyle, range: 0..<2, expectedUpperBound: 2, expectedValue: Decimal(string: "3")!) // "3."
        _match(floatString, decimalStyle, startingAt: 1, range: 0..<3, expectedUpperBound: 3, expectedValue: Decimal(string: "0.1")!) // ".1"
        _match(floatString, decimalStyle, startingAt: 5, range: 0..<7, expectedUpperBound: 7, expectedValue: Decimal(string: "59")!) // "59"
    }

    /* FIXME: These return nil currently. Should these return greedily-matched numbers?
    @Test func greedyMatchPartialRange() {
        let style = Decimal.FormatStyle(locale: enUS)
        _match(string, style, range: 0..<8,
            expectedUpperBound: 6, expectedValue: 12345) // "12,345,6"
        _match(string, style, range: 0..<9,
            expectedUpperBound: 6, expectedValue: 12345) // "12,345,67"
    }
     */

}

extension FormatStylePatternMatchingTests {
    private func _match<Value: Equatable, Consumer: CustomConsumingRegexComponent> (
        _ str: String,
        _ formatStyle: Consumer,
        startingAt: Int? = nil,
        range: Range<Int>,
        expectedUpperBound: Int?,
        expectedValue: Value?,
        sourceLocation: SourceLocation = #_sourceLocation) where Consumer.RegexOutput == Value {
            let upperInString = expectedUpperBound != nil ? str.index(str.startIndex, offsetBy: expectedUpperBound!) : nil
            let rangeInString = str.index(str.startIndex, offsetBy: range.lowerBound)..<str.index(str.startIndex, offsetBy: range.upperBound)
            let startingAtInStr = startingAt != nil ? str.index(str.startIndex, offsetBy: startingAt!) : nil
            _verifyMatching(str, formatStyle: formatStyle, startingAt: startingAtInStr, range: rangeInString, expectedUpperBound: upperInString, expectedValue: expectedValue, sourceLocation: sourceLocation)

    }

    private func _verifyMatching<Value: Equatable, Consumer: CustomConsumingRegexComponent> (
        _ str: String,
        formatStyle: Consumer,
        startingAt: String.Index? = nil,
        range: Range<String.Index>? = nil,
        expectedUpperBound: String.Index?,
        expectedValue: Value?,
        sourceLocation: SourceLocation = #_sourceLocation) where Consumer.RegexOutput == Value {
        let resolvedRange = range ?? str.startIndex ..< str.endIndex
        let m = try? formatStyle.consuming(str, startingAt: startingAt ?? resolvedRange.lowerBound, in: resolvedRange)
        let upperBound = m?.upperBound
        let match = m?.output

        let upperBoundDescription = upperBound?.utf16Offset(in: str)
        let expectedUpperBoundDescription = expectedUpperBound?.utf16Offset(in: str)
            #expect(upperBound == expectedUpperBound,
            "found upperBound: \(String(describing: upperBoundDescription)); expected: \(String(describing: expectedUpperBoundDescription))",
            sourceLocation: sourceLocation)
        #expect(match == expectedValue, sourceLocation: sourceLocation)
    }
}

// MARK: - FoundationPreview Disabled Tests
#if FOUNDATION_FRAMEWORK
extension NumberFormatStyleTests {
    @Test func formattedLeadingDotSyntax() async {
        let locale = Locale(identifier: "ja_JP")
        let integer = 12345
        #expect(integer.formatted(.number.locale(locale)) == integer.formatted(IntegerFormatStyle.number.locale(locale)))
        #expect(integer.formatted(.percent.locale(locale)) == integer.formatted(IntegerFormatStyle.Percent.percent.locale(locale)))
        #expect(integer.formatted(.currency(code: "usd").locale(locale)) == integer.formatted(IntegerFormatStyle.Currency.currency(code: "usd").locale(locale)))

        let double = 1.2345
        #expect(double.formatted(.number.locale(locale)) == double.formatted(FloatingPointFormatStyle.number.locale(locale)))
        #expect(double.formatted(.percent.locale(locale)) == double.formatted(FloatingPointFormatStyle.Percent.percent.locale(locale)))
        #expect(double.formatted(.currency(code: "usd").locale(locale)) == double.formatted(FloatingPointFormatStyle.Currency.currency(code: "usd").locale(locale)))


        func parseableFunc<Style: ParseableFormatStyle>(_ value: Style.FormatInput, style: Style) -> Style { style }

        #expect(parseableFunc(UInt8(), style: .number.locale(locale)) == parseableFunc(UInt8(), style: IntegerFormatStyle.number.locale(locale)))
        #expect(parseableFunc(Int16(), style: .percent.locale(locale)) == parseableFunc(Int16(), style: IntegerFormatStyle.Percent.percent.locale(locale)))
        #expect(parseableFunc(Int(), style: .currency(code: "usd").locale(locale)) == parseableFunc(Int(), style: IntegerFormatStyle.Currency.currency(code: "usd").locale(locale)))

        #expect(parseableFunc(Float(), style: .number.locale(locale)) == parseableFunc(Float(), style: FloatingPointFormatStyle.number.locale(locale)))
        #expect(parseableFunc(Double(), style: .percent.locale(locale)) == parseableFunc(Double(), style: FloatingPointFormatStyle.Percent.percent.locale(locale)))
        #expect(parseableFunc(CGFloat(), style: .currency(code: "usd").locale(locale)) == parseableFunc(CGFloat(), style: FloatingPointFormatStyle.Currency.currency(code: "usd").locale(locale)))

        #expect(parseableFunc(Decimal(), style: .number.locale(locale)) == parseableFunc(Decimal(), style: Decimal.FormatStyle.number.locale(locale)))
        #expect(parseableFunc(Decimal(), style: .percent.locale(locale)) == parseableFunc(Decimal(), style: Decimal.FormatStyle.Percent.percent.locale(locale)))
        #expect(parseableFunc(Decimal(), style: .currency(code: "usd").locale(locale)) == parseableFunc(Decimal(), style: Decimal.FormatStyle.Currency.currency(code: "usd").locale(locale)))

        struct GenericWrapper<V> {}
        func parseableWrapperFunc<Style: ParseableFormatStyle>(_ value: GenericWrapper<Style.FormatInput>, style: Style) -> Style { style }
        #expect(parseableWrapperFunc(GenericWrapper<Double>(), style: .number.locale(locale)) == parseableWrapperFunc(GenericWrapper<Double>(), style: FloatingPointFormatStyle.number.locale(locale)))
    }
}
#endif

// MARK: - Big Integer Tests

extension NumberFormatStyleTests {

    @Test func integerFormatStyleBigNumberNoCrash() throws {
        let uint64Style = IntegerFormatStyle<UInt64>(locale: enUSLocale)
        #expect(uint64Style.format(UInt64.max) == "18,446,744,073,709,551,615")
        #expect(UInt64.max.formatted(.number.locale(enUSLocale)) == "18,446,744,073,709,551,615")

        let uint64Percent = IntegerFormatStyle<UInt64>.Percent(locale: enUSLocale)
        #expect(uint64Percent.format(UInt64.max) == "18,446,744,073,709,551,615%")
        #expect(UInt64.max.formatted(.percent.locale(enUSLocale)) == "18,446,744,073,709,551,615%")

        let uint64Currency = IntegerFormatStyle<UInt64>.Currency(code: "USD", locale: enUSLocale)
        #expect(uint64Currency.format(UInt64.max) == "$18,446,744,073,709,551,615.00")
        #expect(UInt64.max.formatted(.currency(code: "USD").locale(enUSLocale)) == "$18,446,744,073,709,551,615.00")

        let uint64StyleAttributed: IntegerFormatStyle<UInt64>.Attributed = IntegerFormatStyle<UInt64>(locale: enUSLocale).attributed
        #expect(String(uint64StyleAttributed.format(UInt64.max).characters) == "18,446,744,073,709,551,615")
        #expect(String(UInt64.max.formatted(.number.locale(enUSLocale).attributed).characters) == "18,446,744,073,709,551,615")

        let uint64PercentAttributed: IntegerFormatStyle<UInt64>.Attributed = IntegerFormatStyle<UInt64>.Percent(locale: enUSLocale).attributed
        #expect(String(uint64PercentAttributed.format(UInt64.max).characters) == "18,446,744,073,709,551,615%")
        #expect(String(UInt64.max.formatted(.percent.locale(enUSLocale).attributed).characters) == "18,446,744,073,709,551,615%")

        let uint64CurrencyAttributed: IntegerFormatStyle<UInt64>.Attributed = IntegerFormatStyle<UInt64>.Currency(code: "USD", locale: enUSLocale).attributed
        #expect(String(uint64CurrencyAttributed.format(UInt64.max).characters) == "$18,446,744,073,709,551,615.00")
        #expect(String(UInt64.max.formatted(.currency(code: "USD").locale(enUSLocale).attributed).characters) == "$18,446,744,073,709,551,615.00")

        let int64Style = IntegerFormatStyle<Int64>(locale: enUSLocale)
        #expect(int64Style.format(Int64.max) == "9,223,372,036,854,775,807")
        #expect(int64Style.format(Int64.min) == "-9,223,372,036,854,775,808")
        #expect(Int64.max.formatted(.number.locale(enUSLocale)) == "9,223,372,036,854,775,807")
        #expect(Int64.min.formatted(.number.locale(enUSLocale)) == "-9,223,372,036,854,775,808")

        let int64Percent = IntegerFormatStyle<Int64>.Percent(locale: enUSLocale)
        #expect(int64Percent.format(Int64.max) == "9,223,372,036,854,775,807%")
        #expect(int64Percent.format(Int64.min) == "-9,223,372,036,854,775,808%")
        #expect(Int64.max.formatted(.percent.locale(enUSLocale)) == "9,223,372,036,854,775,807%")
        #expect(Int64.min.formatted(.percent.locale(enUSLocale)) == "-9,223,372,036,854,775,808%")

        let int64Currency = IntegerFormatStyle<Int64>.Currency(code: "USD", locale: enUSLocale)
        #expect(int64Currency.format(Int64.max) == "$9,223,372,036,854,775,807.00")
        #expect(int64Currency.format(Int64.min) == "-$9,223,372,036,854,775,808.00")
        #expect(Int64.max.formatted(.currency(code: "USD").locale(enUSLocale)) == "$9,223,372,036,854,775,807.00")
        #expect(Int64.min.formatted(.currency(code: "USD").locale(enUSLocale)) == "-$9,223,372,036,854,775,808.00")
    }
}
