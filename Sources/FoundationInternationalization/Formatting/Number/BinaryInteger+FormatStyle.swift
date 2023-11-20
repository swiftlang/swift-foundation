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
    internal var numericStringRepresentation: String {
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
internal func numericStringRepresentationForBinaryInteger(words: some Collection<UInt>, isSigned: Bool) -> String {
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
private func numericStringRepresentationForMutableBinaryInteger(words: UnsafeMutableBufferPointer<UInt>, isSigned: Bool) -> String {
    //  We reinterpret the words as an unsigned binary integer.
    var magnitude = /* consume */ words
    //  Note that negative values are in two's complement form.
    let isLessThanZero = isSigned && Int(bitPattern: magnitude.last ?? .zero) < .zero
    //  The **unsigned** magnitude is formed when the words represent a negative value.
    if  isLessThanZero {
        formTwosComplementForBinaryInteger(words: magnitude)
    }
    
    let capacity = maxDecimalDigitCountForUnsignedInteger(bitWidth: magnitude.count * UInt.bitWidth) + (isLessThanZero ? 1 : 0)
    return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: capacity) {
        // We rebase $0 because capacity <= $0.count.
        let ascii = UnsafeMutableBufferPointer(start: $0.baseAddress, count: capacity)
        // Set initial ASCII zeros (see later steps).
        ascii.initialize(repeating: UInt8(ascii: "0"))
        // Deferred deinitialization of initialized memory.
        defer {
            ascii.deinitialize()
        }
        
        // We get decimal digits in chunks as we divide the magnitude by pow(10,radix.exponent).
        // We then extract the decimal digits from each chunk by repeatedly dividing them by 10.
        let radix: (exponent: Int, power: UInt) = maxDecimalExponentAndPowerForUnsignedIntegerWord()
        
        var chunkIndex = ascii.endIndex // The index of the current iteration's chunk.
        var writeIndex = ascii.endIndex // The index of the last character we encoded.
        
        dividing: while true {
            // Mutating division prevents unnecessary big integer allocations.
            var chunk = formQuotientWithRemainderForUnsignedInteger(words: magnitude, dividingBy: radix.power)
            // We trim the magnitude's most significant zeros for flexible-width performance and to end the loop.
            magnitude = .init(rebasing: magnitude[..<magnitude[...].reversed().drop(while:{ $0 == .zero }).startIndex.base])
            // We write the chunk's decimal digits to the buffer. Note that chunk < radix.power.
            repeat {
                
                let digit: UInt
                (chunk,digit) = chunk.quotientAndRemainder(dividingBy: 10)
                precondition(writeIndex > ascii.startIndex, "the buffer must accommodate the magnitude's decimal digits")
                ascii.formIndex(before: &writeIndex)
                ascii[writeIndex] = UInt8(ascii: "0") &+ UInt8(truncatingIfNeeded: digit)
                
            } while chunk != .zero
            // We break the loop when every decimal digit has been encoded.
            if magnitude.isEmpty { break }
            // The resulting index is always in bounds because we form it after checking if there are digits left.
            chunkIndex = ascii.index(chunkIndex, offsetBy: -radix.exponent)
            // Set the next iterations's index in case this one ended in zeros. Note that zeros are pre-initialized.
            writeIndex = chunkIndex
        }
        
        //  Add a minus sign to negative values.
        if  isLessThanZero {
            precondition(writeIndex > ascii.startIndex, "must add 1 to the buffer's capacity for integers less than zero")
            ascii.formIndex(before: &writeIndex)
            ascii[writeIndex] = UInt8(ascii: "-")
        }
        
        // We copy the sequence from the last character we encoded.
        let result = UnsafeBufferPointer(rebasing: ascii[writeIndex...])
        return String(unsafeUninitializedCapacity: result.count) { _ = $0.initialize(fromContentsOf: result); return result.count }
    }
}

/// Returns an upper bound for the [number of decimal digits][algorithm] needed
/// to represent an unsigned integer with the given `bitWidth`.
///
/// [algorithm]: https://www.exploringbinary.com/number-of-decimal-digits-in-a-binary-integer
///
/// - Parameter bitWidth: An unsigned binary integer's bit width. It must be non-negative.
///
/// - Returns: Some integer greater than or equal to `1`.
///
private func maxDecimalDigitCountForUnsignedInteger(bitWidth: Int) -> Int {
    // - Int.init(some BinaryFloatingPoint) rounds to zero.
    // - Double.init(exactly:) and UInt.init(_:) for correctness.
    // - log10(2.0) is: 1.0021010002000002002101⌈01...⌉ * 2^(-2).
    // - It's an upper bound, so Double/nextUp for peace of mind.
    return Int(Double(exactly: UInt(bitWidth))! * log10(2.0).nextUp) + 1
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
/// - Note: The optimizer should inline this as a constant.
///
/// - Note: Dividing an integer by `power` yields the first `exponent` number of decimal digits in the
///   remainder. The quotient is the integer with its first `exponent` number of decimal digits removed.
///
private func maxDecimalExponentAndPowerForUnsignedIntegerWord() -> (exponent: Int, power: UInt) {
    var exponent: Int = 1, power: UInt = 10
    
    while true {
        let next = power.multipliedReportingOverflow(by: 10)
        if  next.overflow { break }
        
        exponent += 1
        power = next.partialValue
    }
    
    return (exponent: exponent, power: power)
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

/// Forms the `quotient` of dividing the `dividend` by the `divisor`, then returns the `remainder`.
///
/// - Parameters:
///   - dividend: An unsigned binary integer's words. It becomes the `quotient` once this function returns.
///   - divisor:  An unsigned binary integer's only word.
///
/// - Returns: The `remainder`, which is a value in the range of `0 ..< divisor`.
///
private func formQuotientWithRemainderForUnsignedInteger(words dividend: UnsafeMutableBufferPointer<UInt>, dividingBy divisor: UInt) -> UInt {
    var remainder = UInt.zero
    
    for index in dividend.indices.reversed() {
        (dividend[index], remainder) = divisor.dividingFullWidth((high: remainder, low: dividend[index]))
    }
    
    return remainder
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
