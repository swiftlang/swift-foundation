//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020 - 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
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
    /// This produces output that (at time of writing) looks identical to the `description` for many `BinaryInteger` types, such as the built-in integer types.  However, the format of `description` is not specifically defined by `BinaryInteger` (or anywhere else, really), and as such cannot be relied upon.  Thus this purpose-built method, instead.
    internal var numericStringRepresentation: ArraySlice<UInt8> {
        // It might be worth moving this method into the Swift standard library one day, so that it can be used as the basis for the default `description` instead of duplicating that conversion process.  At least while `description`'s output happens to match this one's.
        //
        // This property's type is an ArraySlice rather than a straight ContiguousArray because it's computationally more expensive to size the array exactly right (whether by pre-calculating the required size more precisely, or by dynamically resizing it during execution of the iterative algorithm).  Since this is intended to only be a transient value, for the purposes of translating from BinaryInteger to the ICU libraries, this is the right compromise of runtime speed (CPU time) and memory efficiency (it's usually only off by a byte or two, if that).

        // Fast-path for values that fit into a UInt, as the conversion to a UInt should be virtually free if it's possible (it's essentially just self.words[0]) and there's a specialisation of this function for UInt that's faster.
        if let fastForm = UInt(exactly: self) {
            return fastForm.numericStringRepresentation
        }

        precondition(.zero != self, "Value of zero (for self) should have been handled by fast path, but wasn't.") // Zero isn't handled correctly in the algorithm below (no numbers will actually be emitted) because it's more work to do so, which is unnecessary as the fast path above should handle that case.

        // The algorithm here is conceptually fairly simple.  In a nutshell, the value of self is broken down into Word-sized chunks, each of which is divided by ten repeatedly until the value dimishes to zero.  The remainder of each division is the next digit of the result (starting with the least significant).
        //
        // A conceptually simpler approach is to skip the first step of breaking things into Word-sized chunks, and just do the division by 10 on the whole value of `self`.  The difference is performance - native integer division (for machine-word-sized integers) is essentially O(1), whereas division of arbitrary-precision integers is essentially O(log2(bitWidth)) since it's composed of _multiple_ machine-word-sized divides proportionate to its binary magnitude.
        //
        // So we replace some of those expensive O(log2(bitWidth)) divides with simpler O(1) divides, by first dividing by the largest multiple of ten such that the remainder fits in a single machine word (UInt), and then using regular integer division CPU instructions to further divide that simple machine-word-sized remainder down into individual digits.

        let (decimalDigitsPerWord, wordMagnitude) = Self.decimalDigitsAndMagnitudePerWord()
        let negative = 0 > self
        let maximumDigits = (Self.maximumDecimalDigitsForUnsigned(bitWidth: self.magnitudeBitWidth)
                             + (negative ? 1 : 0)) // Include room for "-" prefix if necessary.
        var actualDigits: Int = Int.min // Actually initialised inside the closure below, but the compiler mistakenly demands a default value anyway.

        return ContiguousArray<UInt8>(unsafeUninitializedCapacity: maximumDigits) { buffer, initialisedCount in
            var tmp = self
            var wordInsertionPoint = buffer.endIndex - 1

            while .zero != tmp {
                let (quotient, remainder) = tmp.quotientAndRemainder(dividingBy: wordMagnitude)
                precondition(.zero == remainder || (negative == (0 > remainder)), "Starting value \(tmp) is \(negative ? "negative" : "positive (or zero)") yet the remainder of division by \(wordMagnitude) is not: \(remainder).  quotientAndRemainder(dividingBy:) is not implemented correctly for \(type(of: self)) (it might be using F-division instead of T-division).") // It's an entirely understandable error for an implementor to use F-division for their integer quotient and remainder, but they're supposed to use T-division.  i.e. the quotient is supposed to be rounded towards zero rather than down (and that effects the modulus correspondingly, since either way the results must satisfy r = d ⨉ (r idiv i) + (r mod i)).  T-division is convenient because its remainder is neatly the value of interest to this algorithm, rather than being offset by the divisor if r is negative.  While it would be technically possible to assume F-division if the remainder's sign doesn't match, the incorrect implementation of quotientAndRemainder(dividingBy:) will probably still break other algorithms and so we shouldn't encourage it.

                // By definition the remainder has to be a single word (since the divisor, `wordMagnitude`, fits in a single word), so we can avoid working on a BinaryInteger generically and just use the first word directly, which is concretely UInt.
                assert(remainder.magnitudeBitWidth <= Words.Element.bitWidth,
                       "The remainder of dividing \(tmp) by \(wordMagnitude), \(remainder), should fit into a single word, yet it does not (its magnitude bit width is \(remainder.magnitudeBitWidth) which is greater than the \(Words.Element.bitWidth) bits of Words.Element (\(Words.Element.self))).")
                var word = remainder.words.first ?? 0

                if negative {
                    // Luckily for us `words` is defined to be in two's complement form, so we can manually flip the sign.  This doesn't normally work because two's complement cannot represent the positive version of its most negative value, but we know we won't have that here because it's the remainder from division by `wordMagnitude`, which is always going to be less than UInt.max because `wordMagnitude` itself has to fit into UInt (and the remainder of division is always at least one smaller than the divisor).
                    // Note that for a word of zero (no remainder) this does technically overflow but it's intentional - zero is special since there's no distinct representation for -0 vs +0, but ~UInt(0) &+ 1 is 0, conveniently!  So we can trade a conditional (for avoiding this block if `word` is .zero) for two trivial arithmetic instructions.
                    word = ~word &+ 1
                }

                let digitsAdded = word.numericStringRepresentation(intoEndOfBuffer: &buffer[...wordInsertionPoint])

                if .zero != quotient { // Not on the last word, so need to fill in leading zeroes etc.
                    wordInsertionPoint -= decimalDigitsPerWord

                    let leadingZeroes = decimalDigitsPerWord - digitsAdded
                    assert(0 <= leadingZeroes, "Negative leading zeroes \(leadingZeroes)!  Expected \(decimalDigitsPerWord) digits per word and added \(digitsAdded).")

                    if 0 < leadingZeroes {
                        buffer[(wordInsertionPoint + 1)...(wordInsertionPoint + leadingZeroes)].initialize(repeating: UInt8(ascii: "0"))
                    }
                } else {
                    wordInsertionPoint -= digitsAdded
                }

                tmp = quotient
            }

            if negative {
                buffer[wordInsertionPoint] = UInt8(ascii: "-")
                wordInsertionPoint -= 1
            }

            actualDigits = wordInsertionPoint.distance(to: buffer.endIndex) - 1

            let unusedDigits = maximumDigits - actualDigits
            assert(0 <= unusedDigits, "Negative unused digits \(unusedDigits)!  Expected at most \(maximumDigits) digit(s) but emitted \(actualDigits).")

            if 0 < unusedDigits {
                buffer[0..<unusedDigits].initialize(repeating: 0) // The buffer is permitted to be partially uninitialised, but only at the end.  So we have to initialise the unused portion at the start, in principle.  Technically this probably doesn't matter given we never subsequently read this part of the buffer, but there's no way to express that such that the compiler can ensure it for us.
            }

            initialisedCount = maximumDigits
        }[(maximumDigits - actualDigits)...]
    }
    
    /// - Parameter bitWidth: The bit width of interest.  Must be zero or positive.
    /// - Returns: The maximum number of decimal digits that an unsigned value of the given bit width may contain.
    internal static func maximumDecimalDigitsForUnsigned(bitWidth: Int) -> Int {
        guard 0 < bitWidth else { return 0 }
        guard 1 != bitWidth else { return 1 } // Algorithm below only works for bit widths of _two_ and above.

        return Int((Double(bitWidth) * log10(2)).rounded(.up)) + 1 // https://www.exploringbinary.com/number-of-decimal-digits-in-a-binary-integer
    }
    
    /// The bit width of the magnitude of `self`.
    ///
    /// This is useful for determining how many bits are needed to store the magnitude of `self` (an unsigned integer) _without_ actually determining the magnitude (via the `magnitude` property) since that is relatively expensive (in memory if not also runtime, depending on the size and implementation of the underlying type).
    ///
    /// It is never less than one.
    internal var magnitudeBitWidth: Int {
        // `BinaryInteger` does provide a `bitWidth` property which could be used to help with this, but for three things:
        //
        //   1. For `FixedWidthInteger`s it returns the fixed (maximum) size of the type, not the (minimum) size required to represent `self`.
        //
        //   2. It returns the size of the value in two's complement representation, which includes the sign bit that we don't care about.  But we can't just subtract one from that value [for signed types], because for negative powers of two the signed form is one bit shorter than the [unsigned] magnitude's (signed types can represent -(2^N) through +(2^N)-1 - note the asymmetry).  That special case can technically be handled, but it requires determining if `self` is a negative power of two which is relatively expensive for large `BinaryInteger`s.
        //
        //   3. Some `BinaryInteger` implementations implement `bitWidth` wrong, due to its terse and ambiguous documentation.  e.g. some are also `FixedWidthInteger`s yet _don't_ return the maximum bit width of the type (or vice versa), some have off-by-one errors for negative powers of two, etc.  Although it's not this code's responsibility to allow for implementation errors, it's nice to.
        //
        // So, it's both necessary and preferable (respectively) to just examine `words` directly.

        if .zero == self {
            return 1
        } else if .zero <= self {
            // Find the highest-order word with any bits set, determine the overall index of the highest set bit, and return that plus one (index to count conversion).

            for (i, word) in words.reversed().enumerated() {
                if .zero != word {
                    let fullWidth = type(of: word).bitWidth
                    return ((words.count - i - 1) * fullWidth) + (fullWidth - word.leadingZeroBitCount)
                }
            }

            preconditionFailure("\(type(of: self)) \(self) compared as not zero yet all its words are zero.")
        } else { // `self` is negative.
            // Perform two's complement one word at a time, keeping track of the index of the highest set bit seen so far.  After enumerating all the words, return that index plus one (index to count conversion).

            var carryingOne = true // Covers both the initial +1 (as part of two's complement) and overflow between words.
            var indexOfHighestSetBitSeenSoFar = 0

            for (i, word) in words.enumerated() {
                var positiveWord = ~word

                if carryingOne {
                    (positiveWord, carryingOne) = positiveWord.addingReportingOverflow(1)
                }

                let fullWidth = type(of: word).bitWidth

                if carryingOne {
                    indexOfHighestSetBitSeenSoFar += fullWidth
                } else if .zero != positiveWord {
                    indexOfHighestSetBitSeenSoFar = (fullWidth * i) + (fullWidth - positiveWord.leadingZeroBitCount) - 1
                }
            }

            return indexOfHighestSetBitSeenSoFar + 1
        }
    }

    /// Determines the magnitude (the largest decimal magnitude that fits in Word, e.g. 100 for UInt8) and "maximum" digits per word (e.g. two for UInt8).
    ///
    /// Note that 'maximum' in this case is context-specific to the `numericStringRepresentation` algorithm.  It is not necessarily the maximum digits required for _any_ Word, but rather any value of Word type which is less than the maximum decimal magnitude.  Typically this is one digit less.
    internal // For unit test accessibility, otherwise would be fileprivate.
    static func decimalDigitsAndMagnitudePerWord() -> (digits: Int, magnitude: Self) {
        // This method cannot be defined statically because it depends on the types of both Self and Word.  The compiler can in principle fold this down to the resulting values at compile time - since it knows the concrete types for any given call site - and then just inline those into the caller.

        // First, a fast-path that works for any type (for `Self`) which can (essentially) represent a UInt (or larger).
        let guessDigits = Int(Double(Words.Element.bitWidth) * log10(2))
        let guessMagnitude = pow(10, Double(guessDigits))

        if let magnitudeAsSelf = Self(exactly: guessMagnitude) {
            return (guessDigits, magnitudeAsSelf)
        }

        // Alas `Self` is smaller than UInt, so fall back to a truly generic - but slower - algorithm to find the results.  This is because BinaryIntegers - unlike e.g. FixedWidthIntegers - don't provide APIs for questions like "what is the maximum bit width of Self?".

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
    /// This is intended to be used only by the `numericStringRepresentation` property (both the specialised form below and the generic one for all BinaryIntegers, above).  Prefer the `numericStringRepresentation` property for all other use-cases.
    ///
    /// - Parameter intoEndOfBuffer: The buffer to write into, which _must_ contain enough space for the result.  The formatted output is placed into the _end_ of this buffer ("right-aligned", if you will), though the output is numerically still left-to-right.  The contents of this buffer do not have to be pre-initialised.
    /// - Returns: How many entries (UInt8s) of the buffer were used.  Note that zero is a valid return value, as nothing is written to the buffer if `self` is zero (this may be odd but it's acceptable to `numericStringRepresentation` and it simplifies the overall implementation).
    fileprivate func numericStringRepresentation(intoEndOfBuffer buffer: inout Slice<UnsafeMutableBufferPointer<UInt8>>) -> Int {
        guard .zero != self else { return 0 } // Easier to special-case this here than deal with it below (annoying off-by-one potential errors).

        var insertionPoint = buffer.endIndex - 1
        var tmp = self

        // Keep dividing by ten until the value disappears.  Each time we divide, we get one more digit for the output as the remainder of the division.  Since with this approach digits "pop off" from least significant to most, the output buffer is filled in reverse.
        while .zero != tmp {
            let (quotient, remainder) = tmp.quotientAndRemainder(dividingBy: 10)

            buffer[insertionPoint] = UInt8(ascii: "0") + UInt8(remainder)

            if .zero != quotient {
                insertionPoint -= 1
                assert(insertionPoint >= buffer.startIndex, "Buffer is too small (\(buffer.count) UInt8s) to contain the result.")
            }

            tmp = quotient
        }

        return insertionPoint.distance(to: buffer.endIndex)
    }

    /// Formats `self` in "Numeric string" format (https://speleotrove.com/decimal/daconvs.html) which is the required input form for certain ICU functions (e.g. `unum_formatDecimal`).
    ///
    /// This specialisation (for UInt) is faster than the generic BinaryIntegers implementation (earlier in this file).  It is used as an opportunistic fast-path in the generic implementation, for any values that happen to fit into a UInt.
    internal var numericStringRepresentation: ArraySlice<UInt8> {
        // This property's type is an ArraySlice rather than a straight ContiguousArray because it's computationally more expensive to size the array exactly right (whether by pre-calculating the required size more precisely, or by dynamically resizing it during execution of the iterative algorithm).  Since this is intended to only be a transient value, for the purposes of translating from BinaryInteger to the ICU libraries, this is the right compromise of runtime speed (CPU time) and memory efficiency (usually just one excess byte, if any).

        // It's easier to just special-case zero than handle it in the main algorithm.
        guard .zero != self else {
            return [UInt8(ascii: "0")]
        }

        let maximumDigits = Self.maximumDecimalDigitsForUnsigned(bitWidth: self.magnitudeBitWidth)
        var actualDigits: Int = Int.min // Actually initialised inside the closure below, but the compiler mistakenly demands a default value anyway.

        return ContiguousArray(unsafeUninitializedCapacity: maximumDigits) { buffer, initialisedCount in
            actualDigits = numericStringRepresentation(intoEndOfBuffer: &buffer[...])

            let unusedDigits = maximumDigits - actualDigits
            assert(0 <= unusedDigits, "Negative unused digits \(unusedDigits)!  Expected at most \(maximumDigits) digit(s) but emitted \(actualDigits).")

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
