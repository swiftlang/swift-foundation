//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing

#if canImport(_FoundationInternationalizationData) && FOUNDATION_PLURAL_RULES_SWIFT
import _FoundationInternationalizationData

#if canImport(FoundationInternationalization)
@testable import FoundationEssentials
@testable import FoundationInternationalization
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#endif

/// The locales that share one rule set, and the samples of each rule.
struct PluralRulesSampleSet: Sendable, CustomTestStringConvertible {
    let type: PluralRuleType
    let locales: [String]
    let rules: [(category: String, integer: String, decimal: String)]

    var testDescription: String { "\(type) \(locales.prefix(3).joined(separator: ","))" }
}

/// Expands sample text such as `0~15, 100, 0.00~0.04, 1c3, …` into single numbers.
///
/// A range steps by one unit of its last digit, so `0.00~0.04` has five numbers.
private func expandSamples(_ text: String) throws -> [String] {
    var result: [String] = []
    for item in text.split(separator: ",").map({ String($0.filter { $0 != " " }) }) where !item.isEmpty && item != "…" {
        let bounds = item.split(separator: "~").map(String.init)
        guard bounds.count == 2 else {
            result.append(item)
            continue
        }
        let fractionCount = bounds[0].split(separator: ".").dropFirst().first?.count ?? 0
        let lower = try #require(Int(bounds[0].filter { $0 != "." }))
        let upper = try #require(Int(bounds[1].filter { $0 != "." }))
        for scaled in lower ... upper {
            guard fractionCount > 0 else {
                result.append(String(scaled))
                continue
            }
            var digits = String(scaled)
            while digits.count <= fractionCount { digits = "0" + digits }
            digits.insert(".", at: digits.index(digits.endIndex, offsetBy: -fractionCount))
            result.append(digits)
        }
    }
    return result
}

@Suite("PluralRules")
private struct PluralRulesTests {
    @Test(arguments: pluralRulesSamples)
    func cldrSamples(_ set: PluralRulesSampleSet) throws {
        for locale in set.locales {
            let rules = PluralRules(localeIdentifier: locale, type: set.type)
            for rule in set.rules {
                let category = try #require(PluralCategory(rawValue: rule.category))
                for sample in try expandSamples(rule.integer) + expandSamples(rule.decimal) {
                    let operands = try #require(PluralOperands(sample))
                    #expect(rules.category(for: operands) == category, "\(locale) \(sample)")
                }
            }
        }
    }

    @Test(arguments: [
        ("en", "1", PluralCategory.one),
        ("en", "1.0", .other),
        ("en", "0", .other),
        ("en", "-1", .one),
        ("ru", "1", .one),
        ("ru", "2", .few),
        ("ru", "5", .many),
        ("ru", "11", .many),
        ("ru", "21", .one),
        ("ru", "1.5", .other),
        ("ar", "0", .zero),
        ("ar", "2", .two),
        ("ar", "3", .few),
        ("ar", "11", .many),
        ("ar", "100", .other),
        ("fr", "1.5", .one),
        ("fr", "1000000", .many),
        ("fr", "1c6", .many),
        ("fr", "1.2c6", .many),
        ("fr", "1.2c3", .other),
        ("pt", "0", .one),
        ("pt_PT", "0", .other),
        ("lv", "0.1", .one),
        ("lv", "10", .zero),
    ])
    func cardinal(locale: String, number: String, expected: PluralCategory) throws {
        let operands = try #require(PluralOperands(number))
        #expect(PluralRules(localeIdentifier: locale, type: .cardinal).category(for: operands) == expected)
    }

    /// Integers above 2^53 get the category of their exact value.
    @Test(arguments: [
        ("fr", "9999999999999999", PluralCategory.other),
        ("fr", "10000000000000000", .many),
        ("fr", "10000000000000001", .other),
        ("en", "1000000000000000001", .other),
        ("en", "-1000000000000000001", .other),
        ("en", "100000000000000000000001", .other),
        ("ru", "1000000000000000001", .one),
        ("ru", "100000000000000000000001", .one),
    ])
    func largeIntegers(locale: String, number: String, expected: PluralCategory) throws {
        let operands = try #require(PluralOperands(number))
        #expect(PluralRules(localeIdentifier: locale, type: .cardinal).category(for: operands) == expected)
        if let value = Int(number) {
            #expect(PluralRules(localeIdentifier: locale, type: .cardinal).category(for: PluralOperands(value)) == expected)
        }
    }

    @Test(arguments: [
        (1, PluralCategory.one),
        (2, .two),
        (3, .few),
        (4, .other),
        (11, .other),
        (12, .other),
        (21, .one),
        (102, .two),
        (113, .other),
    ])
    func englishOrdinal(number: Int, expected: PluralCategory) {
        #expect(PluralRules(localeIdentifier: "en", type: .ordinal).category(for: PluralOperands(number)) == expected)
    }

    @Test(arguments: [
        ("EN_us", 1, PluralCategory.one),
        ("en-US", 1, .one),
        ("pt-PT", 0, .other),
        ("pt_pt", 0, .other),
        ("pt_PT@calendar=gregorian", 0, .other),
        ("pt_BR", 0, .one),
        ("pt_Latn_PT", 0, .one),
        ("iw", 2, .two),
        ("sr_Latn_RS", 21, .one),
        ("zz", 1, .other),
        ("", 1, .other),
        ("root", 1, .other),
    ])
    func localeLookup(identifier: String, number: Int, expected: PluralCategory) {
        #expect(PluralRules(localeIdentifier: identifier, type: .cardinal).category(for: PluralOperands(number)) == expected)
    }

    @Test(arguments: [
        ("1.50", PluralOperands(integerDigits: 1, fractionDigits: 50, fractionDigitCount: 2)),
        ("-3", PluralOperands(integerDigits: 3)),
        ("0.000", PluralOperands(integerDigits: 0, fractionDigits: 0, fractionDigitCount: 3)),
        ("1.2c6", PluralOperands(integerDigits: 1_200_000, exponent: 6)),
        ("1.2345c3", PluralOperands(integerDigits: 1234, fractionDigits: 5, fractionDigitCount: 1, exponent: 3)),
        ("1e3", PluralOperands(integerDigits: 1000, exponent: 3)),
        ("1234567890123456789012", PluralOperands(integerDigits: 1_000_000_000_000_000_000 + 567_890_123_456_789_012)),
    ])
    func operandsFromText(text: String, expected: PluralOperands) throws {
        #expect(try #require(PluralOperands(text)) == expected)
    }

    @Test func operandsWithoutTrailingZeros() throws {
        let operands = try #require(PluralOperands("1.50"))
        #expect(operands.fractionDigitsWithoutTrailingZeros == 5)
        #expect(operands.fractionDigitCountWithoutTrailingZeros == 1)
        #expect(PluralOperands(-21) == PluralOperands(integerDigits: 21))
        #expect(PluralOperands(Int.min) == PluralOperands(integerDigits: 9_223_372_036_854_775_808))
    }

    @Test(arguments: ["", "-", "1.", ".5", "1.2.3", "abc", "1c", "1 ", "1.0000000000000000001"])
    func invalidOperandsText(text: String) {
        #expect(PluralOperands(text) == nil)
    }
}

#endif
