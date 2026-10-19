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

/// The values of a number that plural rules test, for the number as it is shown.
///
/// "1" and "1.0" have different operands: the second has one visible fraction digit. All operands describe the absolute value.
package struct PluralOperands: Sendable, Hashable {
    /// The integer digits.
    ///
    /// A value read from text with more than 18 integer digits keeps `10^18 + (value % 10^18)`. That gives the same result for every rule as the exact value, because every modulus in the rules divides 10^18 and every compared value is smaller. A value from an `Int` is stored exactly.
    package var integerDigits: UInt64

    /// The visible fraction digits as an integer, with trailing zeros: 50 for "1.50".
    package var fractionDigits: UInt64

    /// The number of visible fraction digits, with trailing zeros: 2 for "1.50".
    package var fractionDigitCount: Int

    /// The compact decimal exponent: 6 for 1.2 million shown as "1.2M".
    package var exponent: Int

    package init(integerDigits: UInt64, fractionDigits: UInt64 = 0, fractionDigitCount: Int = 0, exponent: Int = 0) {
        self.integerDigits = integerDigits
        self.fractionDigits = fractionDigits
        self.fractionDigitCount = fractionDigitCount
        self.exponent = exponent
    }

    package init(_ value: Int) {
        self.init(integerDigits: UInt64(value.magnitude))
    }

    /// Reads a number such as `3`, `-1.50` or `1.2c6`, where `c` or `e` gives the compact decimal exponent.
    ///
    /// The exponent moves the decimal point: `1.2c6` has the integer digits 1200000, no fraction digits, and the exponent 6. Returns `nil` if the text isn't such a number, or if it has more than 18 fraction digits after the exponent is applied.
    package init?(_ text: some StringProtocol) {
        var utf8 = Substring(text).utf8[...]
        if utf8.first == UInt8(ascii: "-") { utf8 = utf8.dropFirst() }

        func readDigits(_ utf8: inout Substring.UTF8View.SubSequence) -> Substring.UTF8View.SubSequence {
            let end = utf8.firstIndex { $0 < UInt8(ascii: "0") || $0 > UInt8(ascii: "9") } ?? utf8.endIndex
            defer { utf8 = utf8[end...] }
            return utf8[..<end]
        }
        let integerPart = readDigits(&utf8)
        guard !integerPart.isEmpty else { return nil }
        var fractionPart = utf8[utf8.startIndex ..< utf8.startIndex]
        if utf8.first == UInt8(ascii: ".") {
            utf8 = utf8.dropFirst()
            fractionPart = readDigits(&utf8)
            guard !fractionPart.isEmpty else { return nil }
        }
        var exponent = 0
        if let marker = utf8.first, marker == UInt8(ascii: "c") || marker == UInt8(ascii: "e") {
            utf8 = utf8.dropFirst()
            let exponentPart = readDigits(&utf8)
            guard !exponentPart.isEmpty, exponentPart.count <= 4 else { return nil }
            for digit in exponentPart { exponent = exponent * 10 + Int(digit &- UInt8(ascii: "0")) }
        }
        guard utf8.isEmpty else { return nil }

        // The exponent moves digits from the fraction to the integer part, then adds zeros.
        var integerDigits = Self.ExactInteger()
        for digit in integerPart { integerDigits.append(digit &- UInt8(ascii: "0")) }
        let movedCount = min(exponent, fractionPart.count)
        for digit in fractionPart.prefix(movedCount) { integerDigits.append(digit &- UInt8(ascii: "0")) }
        for _ in movedCount ..< exponent { integerDigits.append(0) }

        let remainingFraction = fractionPart.dropFirst(movedCount)
        guard remainingFraction.count <= 18 else { return nil }
        var fractionDigits: UInt64 = 0
        for digit in remainingFraction { fractionDigits = fractionDigits * 10 + UInt64(digit &- UInt8(ascii: "0")) }

        self.init(integerDigits: integerDigits.value, fractionDigits: fractionDigits, fractionDigitCount: remainingFraction.count, exponent: exponent)
    }

    /// Builds the integer digits one digit at a time, keeping the form that `integerDigits` describes.
    private struct ExactInteger {
        static let limit: UInt64 = 1_000_000_000_000_000_000
        var low: UInt64 = 0
        var isLarge = false

        mutating func append(_ digit: UInt8) {
            low = low * 10 + UInt64(digit)
            if low >= Self.limit {
                low %= Self.limit
                isLarge = true
            }
        }

        var value: UInt64 { isLarge ? Self.limit + low : low }
    }

    /// The visible fraction digits without trailing zeros: 5 for "1.50".
    package var fractionDigitsWithoutTrailingZeros: UInt64 {
        var digits = fractionDigits
        while digits != 0 && digits % 10 == 0 { digits /= 10 }
        return digits
    }

    /// The number of visible fraction digits without trailing zeros: 1 for "1.50".
    package var fractionDigitCountWithoutTrailingZeros: Int {
        guard fractionDigits != 0 else { return 0 }
        var count = fractionDigitCount
        var digits = fractionDigits
        while digits % 10 == 0 {
            digits /= 10
            count -= 1
        }
        return count
    }
}

#endif // FOUNDATION_PLURAL_RULES_SWIFT
