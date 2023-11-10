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
    
    /// Formats `self` in "Numeric string" format (https://speleotrove.com/decimal/daconvs.html)
    /// which is the required input form for certain ICU functions (e.g. `unum_formatDecimal`).
    ///
    /// This produces output that (at time of writing) looks identical to the `description` for
    /// many `BinaryInteger` types, such as the built-in integer types.  However, the format of
    /// `description` is not specifically defined by `BinaryInteger` (or anywhere else, really),
    /// and as such cannot be relied upon.  Thus this purpose-built method, instead.
    ///
    internal var numericStringRepresentation: ArraySlice<UInt8> {
        numericStringRepresentationForBinaryInteger(words: self.words, isSigned: Self.isSigned)
    }
}

/// Formats `words` in "Numeric string" format (https://speleotrove.com/decimal/daconvs.html)
/// which is the required input form for certain ICU functions (e.g. `unum_formatDecimal`).
///
/// - Parameters:
///   - words: The binary integer's words (least-significant word first).
///   - isSigned: The binary integer's signedness.  If true, `words` must be in two's complement form.
///
internal func numericStringRepresentationForBinaryInteger(
words: some Collection<UInt>, isSigned: Bool) -> ArraySlice<UInt8> {
    // Copies the words and then passes them to a non-generic, mutating, word-based algorithm.
    withUnsafeTemporaryAllocation(of: UInt.self, capacity: words.count) {
        let initializedEndIndex = $0.initialize(fromContentsOf: words)
        let initialized = UnsafeMutableBufferPointer(rebasing: $0[..<initializedEndIndex])
                
        defer {
            initialized.deinitialize()
        }
        
        return numericStringRepresentationForMutableBinaryInteger(words: initialized, isSigned: isSigned)
    }
}

/// Formats `words` in "Numeric string" format (https://speleotrove.com/decimal/daconvs.html)
/// which is the required input form for certain ICU functions (e.g. `unum_formatDecimal`).
///
/// - Parameters:
///   - words: The binary integer's mutable words.
///   - isSigned: The binary integer's signedness.
///
/// This method consumes the `words` such that the buffer is filled with zeros when it returns.
///
private func numericStringRepresentationForMutableBinaryInteger(
words: UnsafeMutableBufferPointer<UInt>, isSigned: Bool) -> ArraySlice<UInt8> {
    //  Note that negative values are in two's complement form.
    let isLessThanZero = isSigned && Int(bitPattern: words.last ?? 0) < 0
    //  The magnitude is formed when the words represent a negative value.
    if  isLessThanZero {
        formTwosComplementForBinaryInteger(words: words)
    }
    
    let radix: (exponent: Int, power: UInt) = maxDecimalExponentAndPowerForUnsignedIntegerWord()
    let capacity = maxDecimalDigitCountForUnsignedInteger(bitWidth: words.count * UInt.bitWidth) + (isLessThanZero ? 1 : 0)
    var ascii = ContiguousArray(repeating: UInt8(ascii: "0"), count: capacity) // Set initial ASCII zeros (see later steps).
    
    var wordsIndex = words.endIndex
    var writeIndex = ascii.endIndex
    var asciiIndex = ascii.endIndex
    
    ascii.withUnsafeMutableBufferPointer { ascii in
        repeat {
            // Mutating division prevents unnecessary big integer allocations.
            let remainder = formQuotientWithRemainderForUnsignedInteger(words: words[..<wordsIndex], dividingBy: radix.power)
            // Trim the quotient's most significant zeros for flexible-width performance and to end the loop.
            wordsIndex  = words[..<wordsIndex].reversed().drop(while:{ $0 == 0 as UInt }).startIndex.base
            // The remainder's numeric string representation is written to the array's trailing edge, up to the ASCII index.
            writeIndex  = formTrailingNumericStringRepresentationForUnsignedInteger(word: remainder, into: ascii[..<asciiIndex])
            // Because the array is pre-filled with ASCII zeros, we can skip ahead; only the final loop's zeros are trimmed.
            asciiIndex -= radix.exponent
            // The entire magnitude has been encoded when the formed quotient is empty.
        }   while wordsIndex > words.startIndex
        
        // Jump to the most significant digit.
        asciiIndex = writeIndex
        
        // Add a minus sign to negative values.
        if isLessThanZero {
            ascii.formIndex(before: &asciiIndex)
            ascii[asciiIndex] = UInt8(ascii: "-")
        }
    }
    
    assert(words.allSatisfy({ $0 == 0 }))
    return ascii.suffix(from: asciiIndex) as ArraySlice<UInt8>
}

/// Writes `word` in "Numeric string" format (https://speleotrove.com/decimal/daconvs.html)  to
/// the trailing edge of `buffer`, then returns the least significant `buffer` index written to.
///
/// - Parameters:
///   - word: An unsigned binary integer's only word.
///   - buffer: A buffer with enough memory to accommodate the format.
///
private func formTrailingNumericStringRepresentationForUnsignedInteger(
word: UInt, into buffer: Slice<UnsafeMutableBufferPointer<UInt8>>) -> Int {
    var magnitude = word
    var index = buffer.endIndex
    
    repeat {
        precondition(index > buffer.startIndex)
        buffer.base.formIndex(before: &index)
        
        let remainder: UInt
        (magnitude, remainder) = magnitude.quotientAndRemainder(dividingBy: 10)
        buffer.base[index] = UInt8(ascii: "0") &+ UInt8(truncatingIfNeeded: remainder)
    }   while magnitude != 0 as UInt
    
    return index
}

/// Forms the `quotient` of dividing the `dividend` by the `divisor`, then returns the `remainder`.
///
/// - Parameters:
///   - dividend: An unsigned binary integer's words.  This is modified to be the quotient once this function returns.
///   - divisor:  An unsigned binary integer's only word.
///
/// - Returns: The `remainder`, which is a value in the range of `0 ..< divisor`.
///
private func formQuotientWithRemainderForUnsignedInteger(
words dividend: Slice<UnsafeMutableBufferPointer<UInt>>, dividingBy divisor: UInt) -> UInt {
    var remainder = UInt.zero
    
    for index in (dividend.startIndex ..< dividend.endIndex).reversed() {
        (dividend.base[index], remainder) = divisor.dividingFullWidth((high: remainder, low: dividend.base[index]))
    }
    
    return remainder
}

/// Forms the `two's complement` of a binary integer.
///
/// - Parameter words: A binary integer's mutable words.
///
private func formTwosComplementForBinaryInteger(words: UnsafeMutableBufferPointer<UInt>) {
    var carry =  true
    for index in words.indices {
        (words[index], carry) = (~words[index]).addingReportingOverflow(carry ? 1 : 0)
    }
}

/// Returns the largest `exponent` and `power` in `pow(10, exponent) <= UInt.max + 1`.
///
/// The `exponent` is also the maximum number of decimal digits needed to represent a binary integer
/// in the range of `0 ..< power`. Another method is used to estimate the total number of digits, however.
/// This is so that binary integers can be rabased and encoded in the same loop.
///
/// ```
/// 32-bit: (exponent:  9, power:           1000000000)
/// 64-bit: (exponent: 19, power: 10000000000000000000)
/// ```
///
private func maxDecimalExponentAndPowerForUnsignedIntegerWord() -> (exponent: Int, power: UInt) {
    var exponent = 1 as  Int
    var power = 0010 as UInt
    
    while true {
        let next = power.multipliedReportingOverflow(by: 10)
        if  next.overflow { break }
        
        exponent += 1
        power = next.partialValue
    }
    
    return (exponent: exponent, power: power)
}

/// Returns an upper bound for the [number of decimal digits][algorithm] needed
/// to represent an unsigned integer with the given `bitWidth`.
///
/// [algorithm]: https://www.exploringbinary.com/number-of-decimal-digits-in-a-binary-integer
///
/// - Parameter bitWidth: The unsigned binary integer's bit width.
///
private func maxDecimalDigitCountForUnsignedInteger(bitWidth: Int) -> Int {
    // - Int.init(some BinaryFloatingPoint) rounds to zero.
    // - Double.init(exactly:) and UInt.init(_:) for correctness.
    // - log10(2.0) is: 1.0011010001000001001101⌈01...⌉ * 2^(-2).
    return Int(Double(exactly: UInt(bitWidth))! * log10(2.0)) + 1
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
