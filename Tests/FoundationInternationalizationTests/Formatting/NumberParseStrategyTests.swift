// Copyright (c) 2014 - 2018 Apple Inc. and the Swift project authors
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

#if canImport(FoundationInternationalization)
@testable import FoundationEssentials
@testable import FoundationInternationalization
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#endif

final class NumberParseStrategyTests : XCTestCase {
    func testIntStrategy() {
        let format: IntegerFormatStyle<Int> = .init()
        let strategy = IntegerParseStrategy(format: format, lenient: true)
        XCTAssert(try! strategy.parse("123,123") == 123123)
        XCTAssert(try! strategy.parse(" -123,123 ") == -123123)
        XCTAssert(try! strategy.parse("+8,765,000") == 8765000)
        XCTAssert(try! strategy.parse("+87,650,000") == 87650000)
    }

    func testParsingCurrency() throws {
        let currencyStyle: IntegerFormatStyle<Int>.Currency = .init(code: "USD", locale: Locale(identifier: "en_US"))
        let strategy = IntegerParseStrategy(format: currencyStyle, lenient: true)
        XCTAssertEqual(try! strategy.parse("$1.00"), 1)
        XCTAssertEqual(try! strategy.parse("1.00 US dollars"), 1)
        XCTAssertEqual(try! strategy.parse("USD\u{00A0}1.00"), 1)

        XCTAssertEqual(try! strategy.parse("$1,234.56"), 1234)
        XCTAssertEqual(try! strategy.parse("1,234.56 US dollars"), 1234)
        XCTAssertEqual(try! strategy.parse("USD\u{00A0}1,234.56"), 1234)

        XCTAssertEqual(try! strategy.parse("-$1,234.56"), -1234)
        XCTAssertEqual(try! strategy.parse("-1,234.56 US dollars"), -1234)
        XCTAssertEqual(try! strategy.parse("-USD\u{00A0}1,234.56"), -1234)

        let accounting = IntegerParseStrategy(format: currencyStyle.sign(strategy: .accounting), lenient: true)
        XCTAssertEqual(try! accounting.parse("($1,234.56)"), -1234)
    }

    func testParsingIntStyle() throws {
        func _verifyResult(_ testData: [String], _ expected: [Int], _ style: IntegerFormatStyle<Int>, _ testName: String = "") {
            for i in 0..<testData.count {
                let parsed = try! Int(testData[i], strategy: style.parseStrategy)
                XCTAssertEqual(parsed, expected[i], testName)
            }
        }

        let locale = Locale(identifier: "en_US")
        let style: IntegerFormatStyle<Int> = .init(locale: locale)
        let data = [
            87650000, 8765000, 876500, 87650, 8765, 876, 87, 8, 0
        ]

        _verifyResult([ "8.765E7", "8.765E6", "8.765E5", "8.765E4", "8.765E3", "8.76E2", "8.7E1", "8E0", "0E0" ], data, style.notation(.scientific), "int style, notation: scientific")
        _verifyResult([ "87,650,000.", "8,765,000.", "876,500.", "87,650.", "8,765.", "876.", "87.", "8.", "0." ], data, style.decimalSeparator(strategy: .always), "int style, decimal separator: always")
    }

    func testRoundtripParsing_percent() {
        func _verifyRoundtripPercent(_ testData: [Int], _ style: IntegerFormatStyle<Int>.Percent, _ testName: String = "", file: StaticString = #filePath, line: UInt = #line) {
            for value in testData {
                let str = style.format(value)
                let parsed = try! Int(str, strategy: style.parseStrategy)
                XCTAssertEqual(value, parsed, "\(testName): formatted string: \(str) parsed: \(parsed)", file: file, line: line)

                let nonLenientParsed = try! Int(str, format: style, lenient: false)
                XCTAssertEqual(value, nonLenientParsed, file: file, line: line)
            }
        }
        let locale = Locale(identifier: "en_US")
        let percentStyle: IntegerFormatStyle<Int>.Percent = .init(locale: locale)
        let testData: [Int] = [
            87650000, 8765000, 876500, 87650, 8765, 876, 87, 8, 0
        ]
        let negativeData: [Int] = [
            -87650000, -8765000, -876500, -87650, -8765, -876, -87, -8
        ]
        _verifyRoundtripPercent(testData, percentStyle, "percent style")
        _verifyRoundtripPercent(testData, percentStyle.sign(strategy: .always()), "percent style, sign: always")
        _verifyRoundtripPercent(testData, percentStyle.grouping(.never), "percent style, grouping: never")
        _verifyRoundtripPercent(testData, percentStyle.notation(.scientific), "percent style, scientific notation")
        _verifyRoundtripPercent(testData, percentStyle.decimalSeparator(strategy: .always), "percent style, decimal display: always")

        _verifyRoundtripPercent(negativeData, percentStyle, "percent style")
        _verifyRoundtripPercent(negativeData, percentStyle.grouping(.never), "percent style, grouping: never")
        _verifyRoundtripPercent(negativeData, percentStyle.notation(.scientific), "percent style, scientific notation")
        _verifyRoundtripPercent(negativeData, percentStyle.decimalSeparator(strategy: .always), "percent style, decimal display: always")

        func _verifyRoundtripPercent(_ testData: [Double], _ style: FloatingPointFormatStyle<Double>.Percent, _ testName: String = "", file: StaticString = #filePath, line: UInt = #line) {
            for value in testData {
                let str = style.format(value)
                let parsed = try! Double(str, format: style, lenient: true)
                XCTAssertEqual(value, parsed, "\(testName): formatted string: \(str) parsed: \(parsed)", file: file, line: line)

                let nonLenientParsed = try! Double(str, format: style, lenient: false)
                XCTAssertEqual(value, nonLenientParsed, file: file, line: line)
            }
        }

        let floatData = testData.map { Double($0) }
        let floatStyle: FloatingPointFormatStyle<Double>.Percent = .init(locale: locale)
        _verifyRoundtripPercent(floatData, floatStyle, "percent style")
        _verifyRoundtripPercent(floatData, floatStyle.sign(strategy: .always()), "percent style, sign: always")
        _verifyRoundtripPercent(floatData, floatStyle.grouping(.never), "percent style, grouping: never")
        _verifyRoundtripPercent(floatData, floatStyle.notation(.scientific), "percent style, scientific notation")
        _verifyRoundtripPercent(floatData, floatStyle.decimalSeparator(strategy: .always), "percent style, decimal display: always")
    }

    func test_roundtripCurrency() {
        let testData: [Int] = [
            87650000, 8765000, 876500, 87650, 8765, 876, 87, 8, 0
        ]
        let negativeData: [Int] = [
            -87650000, -8765000, -876500, -87650, -8765, -876, -87, -8
        ]

        func _verifyRoundtripCurrency(_ testData: [Int], _ style: IntegerFormatStyle<Int>.Currency, _ testName: String = "", file: StaticString = #filePath, line: UInt = #line) {
            for value in testData {
                let str = style.format(value)
                let parsed = try! Int(str, strategy: style.parseStrategy)
                XCTAssertEqual(value, parsed, "\(testName): formatted string: \(str) parsed: \(parsed)", file: file, line: line)

                let nonLenientParsed = try! Int(str, format: style, lenient: false)
                XCTAssertEqual(value, nonLenientParsed, file: file, line: line)
            }
        }

        let currencyStyle: IntegerFormatStyle<Int>.Currency = .init(code: "USD", locale: Locale(identifier: "en_US"))
        _verifyRoundtripCurrency(testData, currencyStyle, "currency style")
        _verifyRoundtripCurrency(testData, currencyStyle.sign(strategy: .always()), "currency style, sign: always")
        _verifyRoundtripCurrency(testData, currencyStyle.grouping(.never), "currency style, grouping: never")
        _verifyRoundtripCurrency(testData, currencyStyle.presentation(.isoCode), "currency style, presentation: iso code")
        _verifyRoundtripCurrency(testData, currencyStyle.presentation(.fullName), "currency style, presentation: iso code")
        _verifyRoundtripCurrency(testData, currencyStyle.presentation(.narrow), "currency style, presentation: iso code")
        _verifyRoundtripCurrency(testData, currencyStyle.decimalSeparator(strategy: .always), "currency style, decimal display: always")

        _verifyRoundtripCurrency(negativeData, currencyStyle, "currency style")
        _verifyRoundtripCurrency(negativeData, currencyStyle.sign(strategy: .accountingAlways()), "currency style, sign: always")
        _verifyRoundtripCurrency(negativeData, currencyStyle.grouping(.never), "currency style, grouping: never")
        _verifyRoundtripCurrency(negativeData, currencyStyle.presentation(.isoCode), "currency style, presentation: iso code")
        _verifyRoundtripCurrency(negativeData, currencyStyle.presentation(.fullName), "currency style, presentation: iso code")
        _verifyRoundtripCurrency(negativeData, currencyStyle.presentation(.narrow), "currency style, presentation: iso code")
        _verifyRoundtripCurrency(negativeData, currencyStyle.decimalSeparator(strategy: .always), "currency style, decimal display: always")
    }

    let testNegativePositiveDecimalData: [Decimal] = [  Decimal(string:"87650")!, Decimal(string:"8765")!,
        Decimal(string:"876.5")!, Decimal(string:"87.65")!, Decimal(string:"8.765")!, Decimal(string:"0.8765")!, Decimal(string:"0.08765")!, Decimal(string:"0.008765")!, Decimal(string:"0")!, Decimal(string:"-0.008765")!, Decimal(string:"-876.5")!, Decimal(string:"-87650")! ]

    func testDecimalParseStrategy() throws {
        func _verifyRoundtrip(_ testData: [Decimal], _ style: Decimal.FormatStyle, _ testName: String = "") {
            for value in testData {
                let str = style.format(value)
                let parsed = try! Decimal(str, strategy: Decimal.ParseStrategy(formatStyle: style, lenient: true))
                XCTAssertEqual(value, parsed, "\(testName): formatted string: \(str) parsed: \(parsed)")
            }
        }

        let style = Decimal.FormatStyle(locale: Locale(identifier: "en_US"))
        _verifyRoundtrip(testNegativePositiveDecimalData, style)
    }

    func testDecimalParseStrategy_Currency() throws {
        let currencyStyle = Decimal.FormatStyle.Currency(code: "USD", locale: Locale(identifier: "en_US"))
        let strategy = Decimal.ParseStrategy(formatStyle: currencyStyle, lenient: true)
        XCTAssertEqual(try! strategy.parse("$1.00"), 1)
        XCTAssertEqual(try! strategy.parse("1.00 US dollars"), 1)
        XCTAssertEqual(try! strategy.parse("USD\u{00A0}1.00"), 1)

        XCTAssertEqual(try! strategy.parse("$1,234.56"), Decimal(string: "1234.56")!)
        XCTAssertEqual(try! strategy.parse("1,234.56 US dollars"), Decimal(string: "1234.56")!)
        XCTAssertEqual(try! strategy.parse("USD\u{00A0}1,234.56"), Decimal(string: "1234.56")!)

        XCTAssertEqual(try! strategy.parse("-$1,234.56"), Decimal(string: "-1234.56")!)
        XCTAssertEqual(try! strategy.parse("-1,234.56 US dollars"), Decimal(string: "-1234.56")!)
        XCTAssertEqual(try! strategy.parse("-USD\u{00A0}1,234.56"), Decimal(string: "-1234.56")!)
    }
    
    func testNumericBoundsParsing() throws {
        let locale = Locale(identifier: "en_US")
        do {
            let format: IntegerFormatStyle<UInt64> = .init(locale: locale)
            let parseStrategy = IntegerParseStrategy(format: format, lenient: true)
            XCTAssertEqual(try parseStrategy.parse(0.formatted(format)), 0)
            let aboveInt64Max = UInt64(Int64.max) + 1
            XCTAssertEqual(try parseStrategy.parse(aboveInt64Max.formatted(format)), aboveInt64Max)
            XCTAssertThrowsError(try parseStrategy.parse("-1"))
            XCTAssertThrowsError(try parseStrategy.parse("-1,000,000"))
        }
        
        do {
            let format: IntegerFormatStyle<Int8> = .init(locale: locale)
            let parseStrategy = IntegerParseStrategy(format: format, lenient: true)
            XCTAssertEqual(try parseStrategy.parse(Int8.min.formatted(format)), Int8.min)
            XCTAssertEqual(try parseStrategy.parse(Int8.max.formatted(format)), Int8.max)
            XCTAssertThrowsError(try parseStrategy.parse("-129"))
            XCTAssertThrowsError(try parseStrategy.parse("128"))
        }
    }
}

final class NumberExtensionParseStrategyTests: XCTestCase {
    let enUS = Locale(identifier: "en_US")

    func testDecimal_stringLength() throws {
        let numberStyle = Decimal.FormatStyle(locale: enUS)
        XCTAssertNotNil(try Decimal("-3,000.14159", format: numberStyle))
        XCTAssertNotNil(try Decimal("-3.14159", format: numberStyle))
        XCTAssertNotNil(try Decimal("12,345.678", format: numberStyle))
        XCTAssertNotNil(try Decimal("0.00", format: numberStyle))

        let percentStyle = Decimal.FormatStyle.Percent(locale: enUS)
        XCTAssertNotNil(try Decimal("-3,000.14159%", format: percentStyle))
        XCTAssertNotNil(try Decimal("-3.14159%", format: percentStyle))
        XCTAssertNotNil(try Decimal("12,345.678%", format: percentStyle))
        XCTAssertNotNil(try Decimal("0.00%", format: percentStyle))

        let currencyStyle = Decimal.FormatStyle.Currency(code: "USD", locale: enUS)
        XCTAssertNotNil(try Decimal("$12,345.00", format: currencyStyle))
        XCTAssertNotNil(try Decimal("$12345.68", format: currencyStyle))
        XCTAssertNotNil(try Decimal("$0.00", format: currencyStyle))
        XCTAssertNotNil(try Decimal("-$3000.0000014", format: currencyStyle))
    }

    func testDecimal_withFormat() throws {
        XCTAssertEqual(try Decimal("+3000", format: .number.locale(enUS).grouping(.never).sign(strategy: .always())), Decimal(3000))
        XCTAssertEqual(try Decimal("$3000", format: .currency(code: "USD").locale(enUS).grouping(.never)), Decimal(3000))
    }

    func testDecimal_withFormat_localeDependent() throws {
        guard Locale.autoupdatingCurrent.identifier == "en_US" else {
            print("Your current locale is \(Locale.autoupdatingCurrent). Set it to en_US to run this test")
            return
        }
        XCTAssertEqual(try Decimal("-3,000.14159", format: .number), Decimal(-3000.14159))
        XCTAssertEqual(try Decimal("-3.14159", format: .number), Decimal(-3.14159))
        XCTAssertEqual(try Decimal("12,345.678", format: .number), Decimal(12345.678))
        XCTAssertEqual(try Decimal("0.00", format: .number), 0)

        XCTAssertEqual(try Decimal("-3,000.14159%", format: .percent), Decimal(-30.0014159))
        XCTAssertEqual(try Decimal("-314.159%", format: .percent), Decimal(-3.14159))
        XCTAssertEqual(try Decimal("12,345.678%", format: .percent), Decimal(123.45678))
        XCTAssertEqual(try Decimal("0.00%", format: .percent), 0)

        XCTAssertEqual(try Decimal("$12,345.00", format: .currency(code: "USD")), Decimal(12345))
        XCTAssertEqual(try Decimal("$12345.68", format: .currency(code: "USD")), Decimal(12345.68))
        XCTAssertEqual(try Decimal("$0.00", format: .currency(code: "USD")), Decimal(0))
        XCTAssertEqual(try Decimal("-$3000.0000014", format: .currency(code: "USD")), Decimal(string: "-3000.0000014")!)
    }
}
