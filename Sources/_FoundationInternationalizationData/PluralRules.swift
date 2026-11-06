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

#if FOUNDATION_PLURAL_RULES_SWIFT

/// The plural category of a number, which selects a grammatical form such as "1 day" or "2 days".
package enum PluralCategory: String, Sendable, Hashable, CaseIterable {
    case zero
    case one
    case two
    case few
    case many
    case other
}

/// The kind of number that plural rules select a form for.
package enum PluralRuleType: Sendable, Hashable {
    /// A count, such as "1 day" or "2 days".
    case cardinal
    /// A position, such as "1st" or "2nd".
    case ordinal
}

/// The plural rules of a locale.
package struct PluralRules: Sendable, Hashable {
    private let ruleSet: Int

    /// The rules for a locale identifier such as `en_US` or `pt-PT`.
    ///
    /// The lookup ignores keywords after `@`, and removes trailing subtags until it finds rules, so `pt_BR` gets the rules of `pt`. A locale with no rules gets the rules of the fallback locale chosen when the data was built, by default one where every number is `other`.
    package init(localeIdentifier: String, type: PluralRuleType) {
        let normalized = Self.normalizedIdentifier(localeIdentifier)
        let span = normalized.utf8Span.span
        var length = span.count
        while true {
            if let ruleSet = Self.searchLocale(span.extracting(0 ..< length), type: type) {
                self.ruleSet = ruleSet
                return
            }
            var underscore = length
            while underscore > 0 && span[underscore - 1] != UInt8(ascii: "_") { underscore -= 1 }
            guard underscore > 0 else { break }
            length = underscore - 1
        }
        switch type {
        case .cardinal: ruleSet = Int(PluralRulesData.cardinalFallback)
        case .ordinal: ruleSet = Int(PluralRulesData.ordinalFallback)
        }
    }

    /// The category of the number with these operands.
    ///
    /// The result is exact for every integer, also above 2^53: French 9999999999999999 is `other`, and English 1000000000000000001 is `other`.
    package func category(for operands: PluralOperands) -> PluralCategory {
        let set = PluralRulesData.ruleSets[ruleSet]
        for index in Int(set.ruleStart) ..< Int(set.ruleEnd) {
            let rule = PluralRulesData.rules[index]
            if Self.matches(relations: Int(rule.relationStart) ..< Int(rule.relationEnd), operands) {
                return rule.category
            }
        }
        return .other
    }

    /// Whether the relations hold: they are `and` groups joined by `or`.
    private static func matches(relations: Range<Int>, _ operands: PluralOperands) -> Bool {
        var alternativeHolds = true
        for index in relations {
            let relation = PluralRulesData.relations[index]
            if relation.startsAlternative {
                if alternativeHolds { return true }
                alternativeHolds = true
            }
            if alternativeHolds && !holds(relation, operands) {
                alternativeHolds = false
            }
        }
        return alternativeHolds
    }

    private static func holds(_ relation: PluralRelation, _ operands: PluralOperands) -> Bool {
        var value: UInt64
        switch relation.operand {
        case .absoluteValue:
            // A value with fraction digits other than zero isn't equal to any integer in the ranges.
            guard operands.fractionDigitsWithoutTrailingZeros == 0 else { return relation.isNegated }
            value = operands.integerDigits
        case .integerDigits: value = operands.integerDigits
        case .fractionDigitCount: value = UInt64(operands.fractionDigitCount)
        case .fractionDigitCountWithoutTrailingZeros: value = UInt64(operands.fractionDigitCountWithoutTrailingZeros)
        case .fractionDigits: value = operands.fractionDigits
        case .fractionDigitsWithoutTrailingZeros: value = operands.fractionDigitsWithoutTrailingZeros
        case .exponent: value = UInt64(operands.exponent)
        }
        if let modulus = relation.modulus {
            value %= UInt64(modulus)
        }
        var isInRanges = false
        for index in Int(relation.rangeStart) ..< Int(relation.rangeEnd) {
            let range = PluralRulesData.ranges[index]
            if UInt64(range.lowerBound) <= value && value <= UInt64(range.upperBound) {
                isInRanges = true
                break
            }
        }
        return isInRanges != relation.isNegated
    }

    // MARK: - Locale lookup

    /// The identifier in the form the data uses: no keywords, `_` separators, a lowercase language, a title-case script, and an uppercase region.
    private static func normalizedIdentifier(_ identifier: String) -> String {
        let utf8 = identifier.utf8
        var result: [UInt8] = []
        result.reserveCapacity(utf8.count)
        let subtags = utf8[..<(utf8.firstIndex(of: UInt8(ascii: "@")) ?? utf8.endIndex)].split(omittingEmptySubsequences: false) { $0 == UInt8(ascii: "_") || $0 == UInt8(ascii: "-") }
        for (subtagIndex, subtag) in subtags.enumerated() {
            if subtagIndex > 0 { result.append(UInt8(ascii: "_")) }
            for (position, byte) in subtag.enumerated() where Unicode.ASCII.isASCII(byte) {
                if subtagIndex == 0 {
                    result.append(lowercasedASCII(byte))
                } else if subtagIndex == 1 && subtag.count == 4 {
                    result.append(position == 0 ? uppercasedASCII(byte) : lowercasedASCII(byte))
                } else if subtag.count == 2 {
                    result.append(uppercasedASCII(byte))
                } else {
                    result.append(byte)
                }
            }
        }
        return String(decoding: result, as: UTF8.self)
    }

    private static func uppercasedASCII(_ byte: UInt8) -> UInt8 {
        (UInt8(ascii: "a") ... UInt8(ascii: "z")).contains(byte) ? byte - UInt8(ascii: "a") + UInt8(ascii: "A") : byte
    }

    private static func lowercasedASCII(_ byte: UInt8) -> UInt8 {
        (UInt8(ascii: "A") ... UInt8(ascii: "Z")).contains(byte) ? byte - UInt8(ascii: "A") + UInt8(ascii: "a") : byte
    }

    private static func searchLocale(_ target: Span<UInt8>, type: PluralRuleType) -> Int? {
        var low = 0
        var high: Int
        switch type {
        case .cardinal: high = PluralRulesData.cardinalLocales.count - 1
        case .ordinal: high = PluralRulesData.ordinalLocales.count - 1
        }
        while low <= high {
            let middle = (low + high) / 2
            let entry: PluralLocaleEntry
            switch type {
            case .cardinal: entry = PluralRulesData.cardinalLocales[middle]
            case .ordinal: entry = PluralRulesData.ordinalLocales[middle]
            }
            let order = compareLocale(target, Int(entry.locale))
            if order == 0 { return Int(entry.ruleSet) }
            if order > 0 { low = middle + 1 } else { high = middle - 1 }
        }
        return nil
    }

    /// Byte-wise comparison of `target` with locale `index` of the pool: negative if `target` sorts first, zero if equal, positive if it sorts after.
    private static func compareLocale(_ target: Span<UInt8>, _ index: Int) -> Int {
        let start = Int(PluralRulesData.localeOffsets[index])
        let count = Int(PluralRulesData.localeOffsets[index + 1]) - start
        for position in 0 ..< min(target.count, count) {
            let byte = PluralRulesData.localeBytes[start + position]
            if target[position] != byte { return target[position] < byte ? -1 : 1 }
        }
        return target.count - count
    }
}

// MARK: - Table entries

/// An operand of a plural rule.
internal enum PluralOperand: UInt8, Sendable {
    /// The absolute value of the number.
    case absoluteValue
    case integerDigits
    case fractionDigitCount
    case fractionDigitCountWithoutTrailingZeros
    case fractionDigits
    case fractionDigitsWithoutTrailingZeros
    case exponent
}

/// The values from `lowerBound` to `upperBound`, both included.
internal struct PluralRange: Sendable {
    internal let lowerBound: UInt32
    internal let upperBound: UInt32

    internal init(_ lowerBound: UInt32, _ upperBound: UInt32) {
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }
}

/// A test such as `i % 10 = 2..4`. It holds when the operand, after the modulus, is in one of the ranges, or isn't when the relation is negated.
internal struct PluralRelation: Sendable {
    internal let operand: PluralOperand
    internal let isNegated: Bool
    /// Whether this relation starts a new group of `and` relations, after an `or`.
    internal let startsAlternative: Bool
    internal let modulus: UInt32?
    internal let rangeStart: UInt16
    internal let rangeEnd: UInt16

    internal init(_ operand: PluralOperand, modulus: UInt32?, isNegated: Bool, startsAlternative: Bool, ranges rangeStart: UInt16, _ rangeEnd: UInt16) {
        self.operand = operand
        self.modulus = modulus
        self.isNegated = isNegated
        self.startsAlternative = startsAlternative
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
    }
}

/// A category and the relations that select it.
internal struct PluralRule: Sendable {
    internal let category: PluralCategory
    internal let relationStart: UInt16
    internal let relationEnd: UInt16

    internal init(_ category: PluralCategory, relations relationStart: UInt16, _ relationEnd: UInt16) {
        self.category = category
        self.relationStart = relationStart
        self.relationEnd = relationEnd
    }
}

/// The rules of a locale, tried in order.
internal struct PluralRuleSet: Sendable {
    internal let ruleStart: UInt16
    internal let ruleEnd: UInt16

    internal init(rules ruleStart: UInt16, _ ruleEnd: UInt16) {
        self.ruleStart = ruleStart
        self.ruleEnd = ruleEnd
    }
}

/// A locale, as an index into the locale pool, and the index of its rule set.
internal struct PluralLocaleEntry: Sendable {
    internal let locale: UInt16
    internal let ruleSet: UInt16

    internal init(_ locale: UInt16, _ ruleSet: UInt16) {
        self.locale = locale
        self.ruleSet = ruleSet
    }
}

#endif // FOUNDATION_PLURAL_RULES_SWIFT
