// Copyright (c) 2014 - 2018 Apple Inc. and the Swift project authors
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

@Suite("Number ParseStrategy")
private struct NumberParseStrategyTests {
    @Test func intStrategy() throws {
        let format: IntegerFormatStyle<Int> = .init(locale: Locale(identifier: "en_US"))
        let strategy = IntegerParseStrategy(format: format, lenient: true)
        #expect(try strategy.parse("123,123") == 123123)
        #expect(try strategy.parse(" -123,123 ") == -123123)
        #expect(try strategy.parse("+8,765,000") == 8765000)
        #expect(try strategy.parse("+87,650,000") == 87650000)
    }
    
    @Test func parsingCurrency() throws {
        let currencyStyle: IntegerFormatStyle<Int>.Currency = .init(code: "USD", locale: Locale(identifier: "en_US"))
        let strategy = IntegerParseStrategy(format: currencyStyle, lenient: true)
        #expect(try strategy.parse("$1.00") == 1)
        #expect(try strategy.parse("1.00 US dollars") == 1)
        #expect(try strategy.parse("USD\u{00A0}1.00") == 1)
        
        #expect(try strategy.parse("$1,234.56") == 1234)
        #expect(try strategy.parse("1,234.56 US dollars") == 1234)
        #expect(try strategy.parse("USD\u{00A0}1,234.56") == 1234)
        
        #expect(try strategy.parse("-$1,234.56") == -1234)
        #expect(try strategy.parse("-1,234.56 US dollars") == -1234)
        #expect(try strategy.parse("-USD\u{00A0}1,234.56") == -1234)
        
        let accounting = IntegerParseStrategy(format: currencyStyle.sign(strategy: .accounting), lenient: true)
        #expect(try accounting.parse("($1,234.56)") == -1234)
    }
    
    @Test func parsingIntStyle() throws {
        func _verifyResult(_ testData: [String], _ expected: [Int], _ style: IntegerFormatStyle<Int>, _ testName: Comment? = nil) throws {
            for i in 0..<testData.count {
                let parsed = try Int(testData[i], strategy: style.parseStrategy)
                #expect(parsed == expected[i], testName)
            }
        }
        
        let locale = Locale(identifier: "en_US")
        let style: IntegerFormatStyle<Int> = .init(locale: locale)
        let data = [
            87650000, 8765000, 876500, 87650, 8765, 876, 87, 8, 0
        ]
        
        try _verifyResult([ "8.765E7", "8.765E6", "8.765E5", "8.765E4", "8.765E3", "8.76E2", "8.7E1", "8E0", "0E0" ], data, style.notation(.scientific), "int style, notation: scientific")
        try _verifyResult([ "87,650,000.", "8,765,000.", "876,500.", "87,650.", "8,765.", "876.", "87.", "8.", "0." ], data, style.decimalSeparator(strategy: .always), "int style, decimal separator: always")
    }
    
    @Test func roundtripParsing_percent() throws {
        func _verifyRoundtripPercent(_ testData: [Int], _ style: IntegerFormatStyle<Int>.Percent, _ testName: String = "", sourceLocation: SourceLocation = #_sourceLocation) throws {
            for value in testData {
                let str = style.format(value)
                let parsed = try Int(str, strategy: style.parseStrategy)
                #expect(value == parsed, "\(testName): formatted string: \(str) parsed: \(parsed)", sourceLocation: sourceLocation)
                
                let nonLenientParsed = try Int(str, format: style, lenient: false)
                #expect(value == nonLenientParsed, sourceLocation: sourceLocation)
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
        try _verifyRoundtripPercent(testData, percentStyle, "percent style")
        try _verifyRoundtripPercent(testData, percentStyle.sign(strategy: .always()), "percent style, sign: always")
        try _verifyRoundtripPercent(testData, percentStyle.grouping(.never), "percent style, grouping: never")
        try _verifyRoundtripPercent(testData, percentStyle.notation(.scientific), "percent style, scientific notation")
        try _verifyRoundtripPercent(testData, percentStyle.decimalSeparator(strategy: .always), "percent style, decimal display: always")

        try _verifyRoundtripPercent(negativeData, percentStyle, "percent style")
        try _verifyRoundtripPercent(negativeData, percentStyle.grouping(.never), "percent style, grouping: never")
        try _verifyRoundtripPercent(negativeData, percentStyle.notation(.scientific), "percent style, scientific notation")
        try _verifyRoundtripPercent(negativeData, percentStyle.decimalSeparator(strategy: .always), "percent style, decimal display: always")

        func _verifyRoundtripPercent(_ testData: [Double], _ style: FloatingPointFormatStyle<Double>.Percent, _ testName: String = "", sourceLocation: SourceLocation = #_sourceLocation) throws {
            for value in testData {
                let str = style.format(value)
                let parsed = try Double(str, format: style, lenient: true)
                #expect(value == parsed, "\(testName): formatted string: \(str) parsed: \(parsed)", sourceLocation: sourceLocation)

                let nonLenientParsed = try Double(str, format: style, lenient: false)
                #expect(value == nonLenientParsed, sourceLocation: sourceLocation)
            }
        }

        let floatData = testData.map { Double($0) }
        let floatStyle: FloatingPointFormatStyle<Double>.Percent = .init(locale: locale)
        try _verifyRoundtripPercent(floatData, floatStyle, "percent style")
        try _verifyRoundtripPercent(floatData, floatStyle.sign(strategy: .always()), "percent style, sign: always")
        try _verifyRoundtripPercent(floatData, floatStyle.grouping(.never), "percent style, grouping: never")
        try _verifyRoundtripPercent(floatData, floatStyle.notation(.scientific), "percent style, scientific notation")
        try _verifyRoundtripPercent(floatData, floatStyle.decimalSeparator(strategy: .always), "percent style, decimal display: always")
    }

    @Test func roundtripCurrency() {
        let testData: [Int] = [
            87650000, 8765000, 876500, 87650, 8765, 876, 87, 8, 0
        ]
        let negativeData: [Int] = [
            -87650000, -8765000, -876500, -87650, -8765, -876, -87, -8
        ]

        func _verifyRoundtripCurrency(_ testData: [Int], _ style: IntegerFormatStyle<Int>.Currency, _ testName: String = "", sourceLocation: SourceLocation = #_sourceLocation) {
            for value in testData {
                let str = style.format(value)
                let parsed = try! Int(str, strategy: style.parseStrategy)
                #expect(value == parsed, "\(testName): formatted string: \(str) parsed: \(parsed)", sourceLocation: sourceLocation)

                let nonLenientParsed = try! Int(str, format: style, lenient: false)
                #expect(value == nonLenientParsed, sourceLocation: sourceLocation)
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

    @Test func parseCurrencyWithDifferentCodes() throws {
        let enUS = Locale(identifier: "en_US")
        // Decimal
        let style = Decimal.FormatStyle.Currency(code: "GBP", locale: enUS).presentation(.isoCode)
        #expect(style.format(3.14) == "GBP 3.14")

        let parsed = try style.parseStrategy.parse("GBP 3.14")
        #expect(parsed == 3.14)

        // Floating point
        let floatingPointStyle: FloatingPointFormatStyle<Double>.Currency = .init(code: "GBP", locale: enUS).presentation(.isoCode)
        #expect(floatingPointStyle.format(3.14) == "GBP 3.14")

        let parsedFloatingPoint = try floatingPointStyle.parseStrategy.parse("GBP 3.14")
        #expect(parsedFloatingPoint == 3.14)

        // Integer
        let integerStyle: IntegerFormatStyle<Int32>.Currency = .init(code: "GBP", locale: enUS).presentation(.isoCode)
        #expect(integerStyle.format(32) == "GBP 32.00")

        let parsedInt = try integerStyle.parseStrategy.parse("GBP 32.00")
        #expect(parsedInt == 32)
    }

    @Test func roundtripForeignCurrency() throws {
        let testData: [Int] = [
            87650000, 8765000, 876500, 87650, 8765, 876, 87, 8, 0
        ]
        let negativeData: [Int] = [
            -87650000, -8765000, -876500, -87650, -8765, -876, -87, -8
        ]

        func _verifyRoundtripCurrency(_ testData: [Int], _ style: IntegerFormatStyle<Int>.Currency, _ testName: String = "", sourceLocation: SourceLocation = #_sourceLocation) throws {
            for value in testData {
                let str = style.format(value)
                let parsed = try Int(str, strategy: style.parseStrategy)
                #expect(value == parsed, "\(testName): formatted string: \(str) parsed: \(parsed)", sourceLocation: sourceLocation)

                let nonLenientParsed = try Int(str, format: style, lenient: false)
                #expect(value == nonLenientParsed, sourceLocation: sourceLocation)
            }
        }

        let currencyStyle: IntegerFormatStyle<Int>.Currency = .init(code: "EUR", locale: Locale(identifier: "en_US"))
        try _verifyRoundtripCurrency(testData, currencyStyle, "currency style")
        try _verifyRoundtripCurrency(testData, currencyStyle.sign(strategy: .always()), "currency style, sign: always")
        try _verifyRoundtripCurrency(testData, currencyStyle.grouping(.never), "currency style, grouping: never")
        try _verifyRoundtripCurrency(testData, currencyStyle.presentation(.isoCode), "currency style, presentation: iso code")
        try _verifyRoundtripCurrency(testData, currencyStyle.presentation(.fullName), "currency style, presentation: iso code")
        try _verifyRoundtripCurrency(testData, currencyStyle.presentation(.narrow), "currency style, presentation: iso code")
        try _verifyRoundtripCurrency(testData, currencyStyle.decimalSeparator(strategy: .always), "currency style, decimal display: always")

        try _verifyRoundtripCurrency(negativeData, currencyStyle, "currency style")
        try _verifyRoundtripCurrency(negativeData, currencyStyle.sign(strategy: .accountingAlways()), "currency style, sign: always")
        try _verifyRoundtripCurrency(negativeData, currencyStyle.grouping(.never), "currency style, grouping: never")
        try _verifyRoundtripCurrency(negativeData, currencyStyle.presentation(.isoCode), "currency style, presentation: iso code")
        try _verifyRoundtripCurrency(negativeData, currencyStyle.presentation(.fullName), "currency style, presentation: iso code")
        try _verifyRoundtripCurrency(negativeData, currencyStyle.presentation(.narrow), "currency style, presentation: iso code")
        try _verifyRoundtripCurrency(negativeData, currencyStyle.decimalSeparator(strategy: .always), "currency style, decimal display: always")
    }

    @Test func parseStategyCodable_sameCurrency() throws {
        // same currency code
        let fs: IntegerFormatStyle<Int32>.Currency = .init(code: "USD", locale: Locale(identifier:"en_US"))
        let p = IntegerParseStrategy(format: fs)
        // Valid JSON representation for `p`
        let existingSerializedParseStrategy = """
            {"formatStyle":{"locale":{"current":0,"identifier":"en_US"},"collection":{"presentation":{"option":1}},"currencyCode":"USD"},"numberFormatType":{"currency":{"_0":{"presentation":{"option":1}}}},"lenient":true,"locale":{"identifier":"en_US","current":0}}
        """

        let existingData = try #require(existingSerializedParseStrategy.data(using: .utf8))

        let decoded: IntegerParseStrategy<IntegerFormatStyle<Int32>.Currency> = try JSONDecoder().decode(IntegerParseStrategy<IntegerFormatStyle<Int32>.Currency>.self, from: existingData)
        #expect(decoded == p)
        #expect(decoded.formatStyle == fs)
        #expect(decoded.formatStyle.currencyCode == "USD")
    }

    @Test func parseStategyCodable_differentCurrency() throws {
        let fs: IntegerFormatStyle<Int32>.Currency = .init(code: "GBP", locale: Locale(identifier:"en_US"))
        let p = IntegerParseStrategy(format: fs)
        // Valid JSON representation for `p`
        let existingSerializedParseStrategy = """
            {"formatStyle":{"collection":{"presentation":{"option":1}},"locale":{"current":0,"identifier":"en_US"},"currencyCode":"GBP"},"lenient":true,"locale":{"current":0,"identifier":"en_US"},"numberFormatType":{"currency":{"_0":{"presentation":{"option":1}}}}}
        """

        let existingData = try #require(existingSerializedParseStrategy.data(using: .utf8))
        let decoded: IntegerParseStrategy<IntegerFormatStyle<Int32>.Currency> = try JSONDecoder().decode(IntegerParseStrategy<IntegerFormatStyle<Int32>.Currency>.self, from: existingData)
        #expect(decoded == p)
        #expect(decoded.formatStyle == fs)
        #expect(decoded.formatStyle.currencyCode == "GBP")
    }

    let testNegativePositiveDecimalData: [Decimal] = [  Decimal(string:"87650")!, Decimal(string:"8765")!,
        Decimal(string:"876.5")!, Decimal(string:"87.65")!, Decimal(string:"8.765")!, Decimal(string:"0.8765")!, Decimal(string:"0.08765")!, Decimal(string:"0.008765")!, Decimal(string:"0")!, Decimal(string:"-0.008765")!, Decimal(string:"-876.5")!, Decimal(string:"-87650")! ]

    @Test func decimalParseStrategy() throws {
        func _verifyRoundtrip(_ testData: [Decimal], _ style: Decimal.FormatStyle, _ testName: Comment = "") throws {
            for value in testData {
                let str = style.format(value)
                let parsed = try Decimal(str, strategy: Decimal.ParseStrategy(formatStyle: style, lenient: true))
                #expect(value == parsed, "\(testName): formatted string: \(str) parsed: \(parsed)")
            }
        }

        let style = Decimal.FormatStyle(locale: Locale(identifier: "en_US"))
        try _verifyRoundtrip(testNegativePositiveDecimalData, style)
    }

    @Test func decimalParseStrategy_Currency() throws {
        let currencyStyle = Decimal.FormatStyle.Currency(code: "USD", locale: Locale(identifier: "en_US"))
        let strategy = Decimal.ParseStrategy(formatStyle: currencyStyle, lenient: true)
        #expect(try strategy.parse("$1.00") == 1)
        #expect(try strategy.parse("1.00 US dollars") == 1)
        #expect(try strategy.parse("USD\u{00A0}1.00") == 1)

        #expect(try strategy.parse("$1,234.56") == Decimal(string: "1234.56")!)
        #expect(try strategy.parse("1,234.56 US dollars") == Decimal(string: "1234.56")!)
        #expect(try strategy.parse("USD\u{00A0}1,234.56") == Decimal(string: "1234.56")!)

        #expect(try strategy.parse("-$1,234.56") == Decimal(string: "-1234.56")!)
        #expect(try strategy.parse("-1,234.56 US dollars") == Decimal(string: "-1234.56")!)
        #expect(try strategy.parse("-USD\u{00A0}1,234.56") == Decimal(string: "-1234.56")!)
    }

    @Test func numericBoundsParsing() throws {
        let locale = Locale(identifier: "en_US")
        do {
            let format: IntegerFormatStyle<Int8> = .init(locale: locale)
            let parseStrategy = IntegerParseStrategy(format: format, lenient: true)
            #expect(try parseStrategy.parse(Int8.min.formatted(format)) == Int8.min)
            #expect(try parseStrategy.parse(Int8.max.formatted(format)) == Int8.max)
            #expect(throws: (any Error).self) {
                try parseStrategy.parse("-129")
            }
            #expect(throws: (any Error).self) {
                try parseStrategy.parse("128")
            }
        }
        
        do {
            let format: IntegerFormatStyle<Int64> = .init(locale: locale)
            let parseStrategy = IntegerParseStrategy(format: format, lenient: true)
            #expect(try parseStrategy.parse(Int64.min.formatted(format)) == Int64.min)
            #expect(try parseStrategy.parse(Int64.max.formatted(format)) == Int64.max)
            #expect(throws: (any Error).self) {
                try parseStrategy.parse("-9223372036854775809")
            }
            #expect(throws: (any Error).self) {
                try parseStrategy.parse("9223372036854775808")
            }
        }
        
        do {
            let format: IntegerFormatStyle<UInt8> = .init(locale: locale)
            let parseStrategy = IntegerParseStrategy(format: format, lenient: true)
            #expect(try parseStrategy.parse(UInt8.min.formatted(format)) == UInt8.min)
            #expect(try parseStrategy.parse(UInt8.max.formatted(format)) == UInt8.max)
            #expect(throws: (any Error).self) {
                try parseStrategy.parse("-1")
            }
            #expect(throws: (any Error).self) {
                try parseStrategy.parse("256")
            }
        }
        
        do {
            // TODO: Parse integers greater than Int64
            let format: IntegerFormatStyle<UInt64> = .init(locale: locale)
            let parseStrategy = IntegerParseStrategy(format: format, lenient: true)
            #expect(try parseStrategy.parse(UInt64.min.formatted(format)) == UInt64.min)
            #expect(throws: (any Error).self) {
                try parseStrategy.parse(UInt64.max.formatted(format))
            }
            #expect(throws: (any Error).self) {
                try parseStrategy.parse("-1")
            }
            #expect(throws: (any Error).self) {
                try parseStrategy.parse("18446744073709551616")
            }
            
            // TODO: Parse integers greater than Int64
            let maxInt64 = UInt64(Int64.max)
            #expect(try parseStrategy.parse((maxInt64 + 0).formatted(format)) == maxInt64) // not a Double
            #expect(throws: (any Error).self) {
                try parseStrategy.parse((maxInt64 + 1).formatted(format))           // exact Doubl
            }
            #expect(throws: (any Error).self) {
                try parseStrategy.parse((maxInt64 + 2).formatted(format))           // not a Doubl
            }
            #expect(throws: (any Error).self) {
                try parseStrategy.parse((maxInt64 + 3).formatted(format))           // not a Doubl
            }
        }
    }
    
    @Test func integerParseStrategyDoesNotRoundLargeIntegersToNearestDouble() throws {
        #expect(Double("9007199254740992") == Double(exactly: UInt64(1) << 53)!) // +2^53 + 0 -> +2^53
        #expect(Double("9007199254740993") == Double(exactly: UInt64(1) << 53)!) // +2^53 + 1 -> +2^53
        #expect(Double.significandBitCount == 52, "Double can represent each integer in -2^53 ... 2^53")
        let locale = Locale(identifier: "en_US")

        do {
            let format: IntegerFormatStyle<Int64> = .init(locale: locale)
            let parseStrategy = IntegerParseStrategy(format: format, lenient: true)
            #expect(throws: (any Error).self) {
                try parseStrategy.parse("-9223372036854776832") // -2^63 - 1024 (Double: -2^63)
            }
            #expect(throws: (any Error).self) {
                try parseStrategy.parse("-9223372036854776833") // -2^63 - 1025 (Double: -2^63 - 2048)
            }
        }
        
        do {
            let format: IntegerFormatStyle<UInt64> = .init(locale: locale)
            let parseStrategy = IntegerParseStrategy(format: format, lenient: true)
            #expect(throws: (any Error).self) {
                try parseStrategy.parse("9223372036854776832") // +2^63 + 1024 (Double: +2^63)
            }
            #expect(throws: (any Error).self) {
                try parseStrategy.parse("9223372036854776833") // +2^63 + 1025 (Double: +2^63 + 2048)
            }
        }
    }
}

@Suite("Number Extension ParseStrategy")
private struct NumberExtensionParseStrategyTests {
    let enUS = Locale(identifier: "en_US")

    @Test func decimal_stringLength() throws {
        let numberStyle = Decimal.FormatStyle(locale: enUS)
        #expect(throws: Never.self) {
            try Decimal("-3,000.14159", format: numberStyle)
        }
        #expect(throws: Never.self) {
            try Decimal("-3.14159", format: numberStyle)
        }
        #expect(throws: Never.self) {
            try Decimal("12,345.678", format: numberStyle)
        }
        #expect(throws: Never.self) {
            try Decimal("0.00", format: numberStyle)
        }

        let percentStyle = Decimal.FormatStyle.Percent(locale: enUS)
        #expect(throws: Never.self) {
            try Decimal("-3,000.14159%", format: percentStyle)
        }
        #expect(throws: Never.self) {
            try Decimal("-3.14159%", format: percentStyle)
        }
        #expect(throws: Never.self) {
            try Decimal("12,345.678%", format: percentStyle)
        }
        #expect(throws: Never.self) {
            try Decimal("0.00%", format: percentStyle)
        }

        let currencyStyle = Decimal.FormatStyle.Currency(code: "USD", locale: enUS)
        #expect(throws: Never.self) {
            try Decimal("$12,345.00", format: currencyStyle)
        }
        #expect(throws: Never.self) {
            try Decimal("$12345.68", format: currencyStyle)
        }
        #expect(throws: Never.self) {
            try Decimal("$0.00", format: currencyStyle)
        }
        #expect(throws: Never.self) {
            try Decimal("-$3000.0000014", format: currencyStyle)
        }
    }

    @Test func decimal_withFormat() throws {
        #expect(try Decimal("+3000", format: .number.locale(enUS).grouping(.never).sign(strategy: .always())) == Decimal(3000))
        #expect(try Decimal("$3000", format: .currency(code: "USD").locale(enUS).grouping(.never)) == Decimal(3000))
    }

    @Test func decimal_withFormat_localeDependent() throws {
        let locale = Locale(identifier: "en_US")
        #expect(try Decimal("-3,000.14159", format: .number.locale(locale)) == Decimal(-3000.14159))
        #expect(try Decimal("-3.14159", format: .number.locale(locale)) == Decimal(-3.14159))
        #expect(try Decimal("12,345.678", format: .number.locale(locale)) == Decimal(12345.678))
        #expect(try Decimal("0.00", format: .number.locale(locale)) == 0)

        #expect(try Decimal("-3,000.14159%", format: .percent.locale(locale)) == Decimal(-30.0014159))
        #expect(try Decimal("-314.159%", format: .percent.locale(locale)) == Decimal(-3.14159))
        #expect(try Decimal("12,345.678%", format: .percent.locale(locale)) == Decimal(123.45678))
        #expect(try Decimal("0.00%", format: .percent.locale(locale)) == 0)

        #expect(try Decimal("$12,345.00", format: .currency(code: "USD").locale(locale)) == Decimal(12345))
        #expect(try Decimal("$12345.68", format: .currency(code: "USD").locale(locale)) == Decimal(12345.68))
        #expect(try Decimal("$0.00", format: .currency(code: "USD").locale(locale)) == Decimal(0))
        #expect(try Decimal("-$3000.0000014", format: .currency(code: "USD").locale(locale)) == Decimal(string: "-3000.0000014")!)
    }
}

