//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension BinaryInteger {

    /// Format `self` using `IntegerFormatStyle()`
    public func formatted() -> String {
        IntegerFormatStyle().format(Int(self))
    }

    /// Format `self` with the given format.
    public func formatted<S>(_ format: S) -> S.FormatOutput where Self == S.FormatInput, S: FormatStyle {
        format.format(self)
    }

    /// Format `self` with the given format. `self` is first converted to `S.FormatInput` type, then format with the given format.
    public func formatted<S>(_ format: S) -> S.FormatOutput where S: FormatStyle, S.FormatInput: BinaryInteger {
        format.format(S.FormatInput(self))
    }

}

// MARK: - BinaryInteger + Numeric string representation

extension BinaryInteger {
    /// Formats `self` in "Numeric string" format (https://speleotrove.com/decimal/daconvs.html) which is the required input form for certain ICU functions (e.g. `unum_formatDecimal`).
    ///
    /// This produces output that (at time of writing) looks identical to the standard `description`.  However, the format of `description`'s result is not specifically defined to match the "Numeric string" format needed by ICU, and might change in future.  Thus this purpose-built method.
    ///
    /// It might be worth moving this into the Swift standard library one day, so that it can be used as the basis for the default `description` instead of duplicating that conversion process.  At least while `description`'s output happens to match this one's.
    internal var numericStringRepresentation: ContiguousArray<UInt8> {
        // Fast-path for values that fit into a UInt, as the conversion to a UInt should be virtually free if it's possible (it's essentially just self.words[0]) and there's a specialisation of this function for UInt that's faster (and exists irrespective of this optimisation as it's required for the algorithm below).
        if let fastForm = UInt(exactly: self) {
            return fastForm.numericStringRepresentation
        }

        assert(0 != self) // Zero isn't handled correctly in the algorithm below (it will result in an empty array) because it's more work to do so, which is unnecessary as the fast path above should handle that case.

        // The algorithm here is a little complicated in the details, but conceptually it's fairly simple.  In a nutshell, the value of self is repeatedly divided by a special constant (wordMagnitude) and the remainder at each step is converted to its numeric string representation, and then those are glued together for the final result.  The details are mostly just about dealing with things like negative values and buffer sizing.
        //
        // It's easier to understand the algorithm if you pretend `wordMagnitude` is 10.  In that case it's basically just repeatedly dividing the number by ten, with the remainder at each step being another digit in the result.
        //
        // The reason that nice & simple approach isn't taken is performance - division is expensive, but especially-so with BinaryInteger generically since it can be arbitrarily large.  So instead, we divide by the largest multiple of ten that fits in a single word (UInt), and then (in a specialisation of this method for UInt) divide that simple word down into digits.  More complicated, but it reduces how many complex divisions are needed by at least an order of magnitude (a "complex" division being a division of self, with arbitrarily large size & execution cost, vs a series of "simple" divisions on UInt).

        let (decimalDigitsPerWord, wordMagnitude) = Self.decimalDigitsAndMagnitudePerWord()

        let positive = 0 <= self.signum()

        let wordCount = words.count + ((positive
                                        ? wordMagnitude <= self
                                        : 0 - wordMagnitude >= self)
                                       ? 1
                                       : 0)

        let wordStrings = ContiguousArray<ContiguousArray<UInt8>>(unsafeUninitializedCapacity: wordCount) { buffer, initialisedCount in
            var tmp = self

            while 0 != tmp {
                let (quotient, remainder) = tmp.quotientAndRemainder(dividingBy: wordMagnitude)

                // By definition the remainder has to be a single word, so we can avoid working on a BinaryInteger generically and just use the first word directly, which is concretely UInt.
                assert(remainder.bitWidth <= Words.Element.max.bitWidth)
                precondition(Words.Element.self == UInt.self)
                var word = remainder.words.first ?? 0

                if 0 > remainder.signum() {
                    // The remainder is negative, but luckily for us `words` is defined to be in two's complement form, so we can manually flip the sign.  This doesn't normally work because two's complement cannot represent the positive version of its most negative value, but we know we won't have that here because it's the remainder from division by `wordMagnitude`, which is always going to be less than UInt.max because it's decimal.
                    word = ~word &+ 1
                }

                buffer[initialisedCount] = word.numericStringRepresentation // This is not recursive - it's utilising the specialisation for UInt that's defined a little later in this file.  The precondition a few lines up is ensuring this invariant is never broken.
                initialisedCount += 1

                tmp = quotient
            }
        }

        let resultDigits = (positive ? 0 : 1) + (wordStrings.last ?? []).count + ((wordStrings.count - 1) * (decimalDigitsPerWord - 1))

        return ContiguousArray<UInt8>(unsafeUninitializedCapacity: resultDigits) { buffer, initialisedCount in
            var iter = wordStrings.reversed().makeIterator()

            guard let first = iter.next() else { return }

            if !positive {
                buffer[initialisedCount] = UInt8(ascii: "-")
                initialisedCount += 1
            }

            initialisedCount = buffer[initialisedCount...].initialize(fromContentsOf: first)

            while let wordString = iter.next() {
                let leadingZeroes = decimalDigitsPerWord - 1 - wordString.count

                if 0 < leadingZeroes {
                    buffer[initialisedCount...(initialisedCount + leadingZeroes)].initialize(repeating: UInt8(ascii: "0"))
                    initialisedCount += leadingZeroes
                }

                initialisedCount = buffer[initialisedCount...].initialize(fromContentsOf: wordString)
            }
        }
    }

    /// Determines the magnitude (the largest round decimal value that fits in Word, e.g. 100 for UInt8) and maximum digits per word (e.g. two for UInt8).
    ///
    /// This cannot be defined statically because Word is UInt which has no fixed size - e.g. it could be UInt64 (most common at time of writing) but also UInt32 (for older or embedded platforms), or technically any other finite-sized unsigned integer.  The compiler can in principle fold this down to the resulting values at compile time - since the only variable is the concrete type of Word - and then just inline those into the caller.
    ///
    /// Alternatively, FixedWidthInteger could be extended with constants for these two values, and the appropriate values hard-coded for every concrete fixed-width unsigned integer.  But that seems like more work both up-front and in future (re. adding new unsigned integer types).
    internal static func decimalDigitsAndMagnitudePerWord() -> (digits: Int, magnitude: Self) { // Internal for unit test accessibility, otherwise would be fileprivate.
        var count = 1
        var value: Words.Element = 1

        while true {
            var (nextValue, overflowed) = value.multipliedReportingOverflow(by: 10)

            // Words.Element might be wider than the actual type, e.g. if Self is UInt8 (and UInt is not).  The magnitude is limited by the smallest of the two.
            if !overflowed && nil == Self(exactly: nextValue) {
                overflowed = true
            }

            if !overflowed || 0 == nextValue {
                count += 1
            }

            if overflowed {
                return (count, Self(value))
            }

            value = nextValue
        }
    }
}

extension BinaryInteger where Self == UInt {
    /// Formats `self` in "Numeric string" format (https://speleotrove.com/decimal/daconvs.html) which is the required input form for certain ICU functions (e.g. `unum_formatDecimal`).
    ///
    /// This specialisation (for UInt) is critical as the building-block upon which the generic implementation (above) is built.  UInt is the required element type within the array `BinaryInteger.words`, so while it superficially looks like the generic implementation (above) is self-recursive, it's actually only calling into this specialisation; no recursion happens.
    ///
    /// This is also utilised as a fast-path for the generic implementation, for any values that happen to fit into a UInt.
    internal var numericStringRepresentation: ContiguousArray<UInt8> {
        // It's easier to just special-case zero than handle it in the main algorithm.
        guard .zero != self else {
            return [UInt8(ascii: "0")]
        }

        // In this approach, we first determine how many digits are needed so we can pre-allocate the resulting ContiguousArray to precisely the correct size.  This avoids wasting any memory vs pre-allocating a large enough ContiguousArray to fit any UInt's representation (20 bytes if UInt == UInt64), but at the expense of costing more CPU time.  This trade-off was chosen somewhat arbitrarily, based on a presumption that the additional CPU time will be insignificant compared to the total, overall CPU time spent on localised formatting (the only purpose for which this property is used, at time of writing), whereas the memory wasted is unbounded (for BinaryInteger generically) because there can be an unbounded number of words.
        var digitCount = 0
        var magnitude: Self = 1

        // Keep multiplying by ten until we exceed the value of `self`; for each iteration in which we don't, we know we need at least one more digit to represent self.
        while magnitude <= self {
            digitCount += 1

            let (newMagnitude, overflowed) = magnitude.multipliedReportingOverflow(by: 10)

            guard !overflowed else {
                break
            }

            magnitude = newMagnitude
        }

        return ContiguousArray(unsafeUninitializedCapacity: digitCount) { buffer, initialisedCount in
            var tmp = self

            // Keep dividing by ten until the value disappears.  Each time we divide, we get one more digit for the output as the remainder of the division.  Since with this approach digits "pop off" from least significant to most, the output buffer is filled in reverse.
            while 0 != tmp {
                let (quotient, remainderAsSelf) = tmp.quotientAndRemainder(dividingBy: 10)

                initialisedCount += 1
                buffer[digitCount - initialisedCount] = UInt8(ascii: "0") + UInt8(remainderAsSelf)

                tmp = quotient
            }

            assert(initialisedCount == digitCount)
        }
    }
}

// MARK: - BinaryInteger + Parsing

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension BinaryInteger {
    /// Initialize an instance by parsing `value` with the given `strategy`.
    public init<S: ParseStrategy>(_ value: S.ParseInput, strategy: S) throws where S.ParseOutput : BinaryInteger {
        let parsed = try strategy.parse(value)
        self = Self(parsed)
    }

    public init<S: ParseStrategy>(_ value: S.ParseInput, strategy: S) throws where S.ParseOutput == Self {
        self = try strategy.parse(value)
    }

    public init(_ value: String, format: IntegerFormatStyle<Self>, lenient: Bool = true) throws {
        let parsed = try IntegerParseStrategy(format: format, lenient: lenient).parse(value)
        self = Self(parsed)
    }

    public init(_ value: String, format: IntegerFormatStyle<Self>.Percent, lenient: Bool = true) throws {
        let parsed = try IntegerParseStrategy(format: format, lenient: lenient).parse(value)
        self = Self(parsed)
    }

    public init(_ value: String, format: IntegerFormatStyle<Self>.Currency, lenient: Bool = true) throws {
        let parsed = try IntegerParseStrategy(format: format, lenient: lenient).parse(value)
        self = Self(parsed)
    }
}
