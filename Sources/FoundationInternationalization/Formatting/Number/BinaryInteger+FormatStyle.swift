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
    ///
    /// This property's type is a Slice rather than a straight ContiguousArray because it's computationally more expensive to size the array exactly right (whether by pre-calculating the required size more precisely, or by dynamically resizing it during execution of the iterative algorithm).  Since this is intended to only be a transient value, for the purposes of translating from BinaryInteger to the ICU libraries, this is the right compromise of runtime speed (CPU time) and memory efficiency.
    internal var numericStringRepresentation: ArraySlice<UInt8> {
        // Fast-path for values that fit into a UInt, as the conversion to a UInt should be virtually free if it's possible (it's essentially just self.words[0]) and there's a specialisation of this function for UInt that's faster (and exists irrespective of this optimisation as it's required for the algorithm below).
        if let fastForm = UInt(exactly: self) {
            return fastForm.numericStringRepresentation
        }

        assert(.zero != self) // Zero isn't handled correctly in the algorithm below (it will result in an empty array) because it's more work to do so, which is unnecessary as the fast path above should handle that case.

        // The algorithm here is conceptually fairly simple.  In a nutshell, the value of self is broken down into Word-sized chunks, each of which is converted to its numeric string representation and glued into the final result.
        //
        // A conceptually simpler approach is to just divide by 10 repeatedly until the value hits zero, each iteration producing one more digit for the resulting string.  The difference is performance - native integer division (for machine-word-sized integers) is essentially O(1), whereas division of arbitrary-precision integers is essentially O(log2(bitWidth)) since it's composed of _multiple_ machine-word-sized divides proportionate to its binary magnitude.
        //
        // So we replace some of those expensive O(log2(bitWidth)) divides with simpler O(1) divides, by first dividing by the largest multiple of ten such that the remainder fits in a single machine word (UInt), and then using regular integer division CPU instructions to further divide that simple machine-word-sized remainder down into individual digits.

        let (decimalDigitsPerWord, wordMagnitude) = Self.decimalDigitsAndMagnitudePerWord()
        let positive = 0 <= self.signum()
        let maximumDigits = (Self.maximumDecimalDigitsForUnsigned(bitWidth: self.bitWidth - (positive ? 0 : 1))
                             + (positive ? 0 : 1)) // Include room for "-" prefix if necessary.
        var actualDigits: Int = Int.min // Actually initialised inside the closure below, but the compiler mistakenly demands a default value anyway.

        return ContiguousArray<UInt8>(unsafeUninitializedCapacity: maximumDigits) { buffer, initialisedCount in
            var tmp = self
            var wordInsertionPoint = buffer.endIndex.advanced(by: -1)

            while .zero != tmp {
                let (quotient, remainder) = tmp.quotientAndRemainder(dividingBy: wordMagnitude)

                let remainderIsNegative = 0 > remainder.signum()

                // By definition the remainder has to be a single word (since the divisor, `wordMagnitude`, fits in a single word), so we can avoid working on a BinaryInteger generically and just use the first word directly, which is concretely UInt.
                assert(remainder.bitWidth <= Words.Element.max.bitWidth + (remainderIsNegative ? 1 : 0)) // When we're working with negative values the reported `bitWidth` will be one greater than that of the magnitude because it counts the sign bit, but we don't care about that sign bit.
                var word = remainder.words.first ?? 0

                if remainderIsNegative {
                    // The remainder is negative, but luckily for us `words` is defined to be in two's complement form, so we can manually flip the sign.  This doesn't normally work because two's complement cannot represent the positive version of its most negative value, but we know we won't have that here because it's the remainder from division by `wordMagnitude`, which is always going to be less than UInt.max because it's decimal.
                    word = ~word &+ 1
                }

                // This is not recursive - it's utilising the specialisation for UInt that's defined a little later in this file.  The precondition it a bit paranoid but just ensures this invariant is never broken (or at least that this code will have to be proactively reworked if the invariant is broken).
                precondition(Words.Element.self == UInt.self)
                let digitsAdded = word.numericStringRepresentation(intoEndOfBuffer: &buffer[...wordInsertionPoint])
                let nextWordInsertPoint: UnsafeMutableBufferPointer<UInt8>.Index

                if .zero != quotient { // Not on the last word, so need to fill in leading zeroes etc.
                    nextWordInsertPoint = wordInsertionPoint.advanced(by: -decimalDigitsPerWord)
                    let leadingZeroes = decimalDigitsPerWord - digitsAdded

                    if 0 < leadingZeroes {
                        buffer[nextWordInsertPoint.advanced(by: 1)...nextWordInsertPoint.advanced(by: leadingZeroes)].initialize(repeating: UInt8(ascii: "0"))
                    }
                } else { // Last (or only) word, so need to be careful about buffer sizing.
                    nextWordInsertPoint = wordInsertionPoint.advanced(by: -digitsAdded)
                }

                wordInsertionPoint = nextWordInsertPoint
                tmp = quotient
            }

            if !positive {
                buffer[wordInsertionPoint] = UInt8(ascii: "-")
                wordInsertionPoint = wordInsertionPoint.advanced(by: -1)
            }

            actualDigits = wordInsertionPoint.distance(to: buffer.endIndex) - 1

            let unusedDigits = maximumDigits - actualDigits

            if 0 < unusedDigits {
                buffer[0..<unusedDigits].initialize(repeating: 0) // The buffer is permitted to be partially uninitialised, but only at the end.  So we have to initialise the unused portion at the start, in principle.  Technically this probably doesn't matter given we never subsequently read this part of the buffer, but there's no way to express that such that the compiler can ensure it for us.
            }

            initialisedCount = maximumDigits
        }[(maximumDigits - actualDigits)...]
    }
    
    /// Determines the maximum number of decimal digits required for an unsigned binary integer of a given bit width.
    /// - Parameter bitWidth: The bit width of interest.  Must be zero or positive.
    /// - Returns: The maximum number of decimal digits that a value of the given bit width may contain.  This is an upper bound - the actual number of digits may be lower for some values, depending on their exact value.
    internal static func maximumDecimalDigitsForUnsigned(bitWidth: Int) -> Int {
        guard 0 < bitWidth else { return 0 }
        guard 1 != bitWidth else { return 1 } // Algorithm below only works for bit widths of _two_ and above.

        let log10_of_2: Double = 0.3010299956639812 // Precomputed to avoid having to pull in Glibc/Darwin for the log10 function.
        return Int((Double(bitWidth) * log10_of_2).rounded(.up)) + 1 // https://www.exploringbinary.com/number-of-decimal-digits-in-a-binary-integer
    }

    /// Determines the magnitude (the largest round decimal value that fits in Word, e.g. 100 for UInt8) and "maximum" digits per word (e.g. two for UInt8).
    ///
    /// Note that 'maximum' in this case is context-specific to the `numericStringRepresentation` algorithm.  It is not necessarily the maximum digits required for _any_ Word, but rather any value of Word type which is less than the maximum decimal magnitude.  Typically this is two digit less.
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

            if !overflowed || .zero == nextValue {
                count += 1
            }

            if overflowed {
                return (count - 1, Self(value))
            }

            value = nextValue
        }
    }
}

extension UInt {
    /// Formats `self` in "Numeric string" format (https://speleotrove.com/decimal/daconvs.html) which is the required input form for certain ICU functions (e.g. `unum_formatDecimal`).
    ///
    /// This is solely intended to be used by `numericStringRepresentation` (both the specialised form below and the generic one for all BinaryIntegers, above).  That's why its interface is so unusual.  Prefer using `numericStringRepresentation` for all other use-cases.
    ///
    /// - Parameter intoEndOfBuffer: The buffer to write into.  The formatted output is placed into the _end_ of this buffer ("right-aligned", if you will), though the output is numerically still left-to-right.  The contents of this buffer do not have to be pre-initialised.
    /// - Returns: How many entries (UInt8s) of the buffer were used.  Note that zero is a valid return value, as nothing is written to the buffer if `self` is zero (this may be odd but it's acceptable to `numericStringRepresentation` and it simplifies the overall implementation).
    func numericStringRepresentation(intoEndOfBuffer buffer: inout Slice<UnsafeMutableBufferPointer<UInt8>>) -> Int {
        guard .zero != self else { return 0 } // Easier to special-case this here than deal with it below (annoying off-by-one potential errors).

        var insertionPoint = buffer.endIndex.advanced(by: -1)
        var tmp = self

        // Keep dividing by ten until the value disappears.  Each time we divide, we get one more digit for the output as the remainder of the division.  Since with this approach digits "pop off" from least significant to most, the output buffer is filled in reverse.
        while .zero != tmp {
            let (quotient, remainderAsSelf) = tmp.quotientAndRemainder(dividingBy: 10)

            buffer[insertionPoint] = UInt8(ascii: "0") + UInt8(remainderAsSelf)

            if .zero != quotient {
                insertionPoint = insertionPoint.advanced(by: -1)
                assert(insertionPoint >= buffer.startIndex)
            }

            tmp = quotient
        }

        return insertionPoint.distance(to: buffer.endIndex)
    }

    /// Formats `self` in "Numeric string" format (https://speleotrove.com/decimal/daconvs.html) which is the required input form for certain ICU functions (e.g. `unum_formatDecimal`).
    ///
    /// This specialisation (for UInt) is critical as the building-block upon which the generic implementation (above) is built.  UInt is the required element type within the array `BinaryInteger.words`, so while it superficially looks like the generic implementation (above) is self-recursive, it's actually only calling into this specialisation; no recursion happens.
    ///
    /// This is also utilised as a fast-path for the generic implementation, for any values that happen to fit into a UInt.
    /// 
    /// This property's type is a Slice rather than a straight ContiguousArray because it's computationally more expensive to size the array exactly right (whether by pre-calculating the required size more precisely, or by dynamically resizing it during execution of the iterative algorithm).  Since this is intended to only be a transient value, for the purposes of translating from BinaryInteger to the ICU libraries, this is the right compromise of runtime speed (CPU time) and memory efficiency.
    internal var numericStringRepresentation: ArraySlice<UInt8> {
        // It's easier to just special-case zero than handle it in the main algorithm.
        guard .zero != self else {
            return [UInt8(ascii: "0")]
        }

        // In this approach, we first determine the maximum number of decimal digits in the value (`self`) so we can pre-allocate the resulting ContiguousArray to a sufficient size - but not necessarily the exact size.  This may waste a byte of memory, but that's insignificant in any case - the result of this function is intended to be transient - and it's significantly slower (in CPU runtime) to determine the exact number of bytes required.
        let maximumDigits = Self.maximumDecimalDigitsForUnsigned(bitWidth: self.bitWidth)
        var actualDigits: Int = Int.min // Actually initialised inside the closure below, but the compiler mistakenly demands a default value anyway.

        return ContiguousArray(unsafeUninitializedCapacity: maximumDigits) { buffer, initialisedCount in
            actualDigits = numericStringRepresentation(intoEndOfBuffer: &buffer[...])

            let unusedDigits = maximumDigits - actualDigits

            if 0 < unusedDigits {
                buffer[0..<unusedDigits].initialize(repeating: 0) // The buffer is permitted to be partially uninitialised, but only at the end.  So we have to initialise the unused portion at the start, in principle.  Technically this probably doesn't matter given we never subsequently read this part of the buffer, but there's no way to express that such that the compiler can ensure it for us.
            }

            initialisedCount = maximumDigits
        }[(maximumDigits - actualDigits)...]
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
