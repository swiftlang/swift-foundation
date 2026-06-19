//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020-2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
@preconcurrency import Glibc
#elseif canImport(ucrt)
import ucrt
#endif

#if !FOUNDATION_FRAMEWORK

/// A structure representing a base-10 number.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public struct Decimal: Sendable {
    internal struct Storage: Sendable {
        var exponent: Int8
        // Layout:
        // |  0  1  2  3 | 4 | 5 | 6  7 |
        // | -> _length  | | | | | ->_reserved
        // |             | | | |-> _isCompact
        // |             | |-> _isNegative
        var lengthFlagsAndReserved: UInt8
        // 18 bits long
        var reserved: UInt16
        var mantissa: Mantissa
    }

    internal var storage: Storage

    // Int8
    internal var _exponent: Int32 {
        get {
            return Int32(self.storage.exponent)
        }
        set {
            self.storage.exponent = Int8(newValue)
        }
    }

    // 4 bits
    internal var _length: UInt32 {
        get {
            return UInt32(self.storage.lengthFlagsAndReserved >> 4)
        }
        set {
            let newLength = (UInt8(truncatingIfNeeded: newValue) & 0x0F) << 4
            self.storage.lengthFlagsAndReserved &= 0x0F // clear the length
            self.storage.lengthFlagsAndReserved |= newLength // set the new length
        }
    }
    
    // Bool
    internal var _isNegative: UInt32 {
        get {
            return UInt32((self.storage.lengthFlagsAndReserved >> 3) & 0x01)
        }
        set {
            if (newValue & 0x1) != 0 {
                self.storage.lengthFlagsAndReserved |= 0b00001000
            } else {
                self.storage.lengthFlagsAndReserved &= 0b11110111
            }
        }
    }
    
    // Bool
    internal var _isCompact: UInt32 {
        get {
            return UInt32((self.storage.lengthFlagsAndReserved >> 2) & 0x01)
        }
        set {
            if (newValue & 0x1) != 0 {
                self.storage.lengthFlagsAndReserved |= 0b00000100
            } else {
                self.storage.lengthFlagsAndReserved &= 0b11111011
            }
        }
    }
    
    // Only 18 bits
    internal var _reserved: UInt32 {
        get {
            return (UInt32(self.storage.lengthFlagsAndReserved & 0x03) << 16) | UInt32(self.storage.reserved)
        }
        set {
            // Bottom 16 bits
            self.storage.reserved = UInt16(newValue & 0xFFFF)
            self.storage.lengthFlagsAndReserved &= 0xFC
            self.storage.lengthFlagsAndReserved |= UInt8(newValue >> 16) & 0xFF
        }
    }

    internal var _mantissa: Mantissa {
        get {
            return self.storage.mantissa
        }
        set {
            self.storage.mantissa = newValue
        }
    }

    internal var _lengthFlagsAndReserved: UInt8 {
        get {
            return self.storage.lengthFlagsAndReserved
        }
        set {
            self.storage.lengthFlagsAndReserved = newValue
        }
    }

    @_spi(SwiftCorelibsFoundation)
    public init(
        _exponent: Int32 = 0,
        _length: UInt32,
        _isNegative: UInt32 = 0,
        _isCompact: UInt32,
        _reserved: UInt32 = 0,
        _mantissa: Mantissa
    ) {
        let length: UInt8 = (UInt8(truncatingIfNeeded: _length) & 0xF) << 4
        let isNegative: UInt8 = UInt8(truncatingIfNeeded: _isNegative & 0x1) == 0 ? 0 : 0b00001000
        let isCompact: UInt8 = UInt8(truncatingIfNeeded: _isCompact & 0x1) == 0 ? 0 : 0b00000100
        let reservedLeft: UInt8 = UInt8(truncatingIfNeeded: (_reserved & 0x3FFFF) >> 16)
        self.storage = .init(
            exponent: Int8(truncatingIfNeeded: _exponent),
            lengthFlagsAndReserved: length | isNegative | isCompact | reservedLeft,
            reserved: UInt16(truncatingIfNeeded: _reserved & 0xFFFF),
            mantissa: _mantissa
        )
    }

    @_spi(SwiftCorelibsFoundation)
    public init(mantissa: UInt64, exponent: Int16, isNegative: Bool) {
        var d = Decimal(mantissa)
        d._exponent += Int32(exponent)
        d._isNegative = isNegative ? 1 : 0
        self = d
    }

    /// Creates a decimal initialized to `0`.
    public init() {
        self.storage = .init(
            exponent: 0,
            lengthFlagsAndReserved: 0,
            reserved: 0,
            mantissa: (0, 0, 0, 0, 0, 0, 0, 0)
        )
    }
}

extension Decimal {
    /// An enumeration that specifies possible rounding modes.
    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public enum RoundingMode: UInt, Sendable {
        case plain
        case down
        case up
        case bankers
    }

    /// An enumeration that specifies possible calculation errors.
    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public enum CalculationError: UInt, Sendable {
        case noError
        case lossOfPrecision
        case overflow
        case underflow
        case divideByZero
    }
}

#endif // !FOUNDATION_FRAMEWORK

extension Decimal {
#if FOUNDATION_FRAMEWORK
    internal typealias Mantissa = (UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16)
#else
    @_spi(SwiftCorelibsFoundation)
    public typealias Mantissa = (UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16)
#endif

    internal var _significand: UInt128 {
        // Note that per project policy we no longer consider big-endian architectures.
        @inline(__always) get {
#if FOUNDATION_FRAMEWORK
            return unsafeBitCast(_mantissa, to: UInt128.self)
#else
            return unsafeBitCast(storage.mantissa, to: UInt128.self)
#endif
        }
        // Note that if `_significand` is set to `0` while `_isNegative == 1`, setting `_length` results in NaN.
        @inline(__always) set {
#if FOUNDATION_FRAMEWORK
            _mantissa = unsafeBitCast(newValue, to: Mantissa.self)
            _length = UInt32((128 &- newValue.leadingZeroBitCount &+ 15) / 16)
#else
            self.storage.mantissa = unsafeBitCast(newValue, to: Mantissa.self)
            self._length = UInt32((128 &- newValue.leadingZeroBitCount &+ 15) / 16)
#endif
        }
    }
}

// MARK: - String

// Table to look up two digits at once.
private let _asciiDigits: [100 of (UInt8, UInt8)] = [
  (0x30, 0x30), (0x30, 0x31), (0x30, 0x32), (0x30, 0x33), (0x30, 0x34),
  (0x30, 0x35), (0x30, 0x36), (0x30, 0x37), (0x30, 0x38), (0x30, 0x39),
  (0x31, 0x30), (0x31, 0x31), (0x31, 0x32), (0x31, 0x33), (0x31, 0x34),
  (0x31, 0x35), (0x31, 0x36), (0x31, 0x37), (0x31, 0x38), (0x31, 0x39),
  (0x32, 0x30), (0x32, 0x31), (0x32, 0x32), (0x32, 0x33), (0x32, 0x34),
  (0x32, 0x35), (0x32, 0x36), (0x32, 0x37), (0x32, 0x38), (0x32, 0x39),
  (0x33, 0x30), (0x33, 0x31), (0x33, 0x32), (0x33, 0x33), (0x33, 0x34),
  (0x33, 0x35), (0x33, 0x36), (0x33, 0x37), (0x33, 0x38), (0x33, 0x39),
  (0x34, 0x30), (0x34, 0x31), (0x34, 0x32), (0x34, 0x33), (0x34, 0x34),
  (0x34, 0x35), (0x34, 0x36), (0x34, 0x37), (0x34, 0x38), (0x34, 0x39),
  (0x35, 0x30), (0x35, 0x31), (0x35, 0x32), (0x35, 0x33), (0x35, 0x34),
  (0x35, 0x35), (0x35, 0x36), (0x35, 0x37), (0x35, 0x38), (0x35, 0x39),
  (0x36, 0x30), (0x36, 0x31), (0x36, 0x32), (0x36, 0x33), (0x36, 0x34),
  (0x36, 0x35), (0x36, 0x36), (0x36, 0x37), (0x36, 0x38), (0x36, 0x39),
  (0x37, 0x30), (0x37, 0x31), (0x37, 0x32), (0x37, 0x33), (0x37, 0x34),
  (0x37, 0x35), (0x37, 0x36), (0x37, 0x37), (0x37, 0x38), (0x37, 0x39),
  (0x38, 0x30), (0x38, 0x31), (0x38, 0x32), (0x38, 0x33), (0x38, 0x34),
  (0x38, 0x35), (0x38, 0x36), (0x38, 0x37), (0x38, 0x38), (0x38, 0x39),
  (0x39, 0x30), (0x39, 0x31), (0x39, 0x32), (0x39, 0x33), (0x39, 0x34),
  (0x39, 0x35), (0x39, 0x36), (0x39, 0x37), (0x39, 0x38), (0x39, 0x39)
]

private extension UInt64 {
    func _ascii(_ buffer: inout MutableRawSpan) -> Range<Int> {
        // We need a `MutableRawSpan` to use wide store/load operations.
        var value = self
        var offset = buffer.byteCount

        if value == 0 {
            offset &-= 1
            buffer.storeBytes(
                of: 0x30 /* "0" */,
                toUncheckedByteOffset: offset,
                as: UInt8.self)
        } else {
            while value >= 10 {
                offset &-= 2
                buffer.storeBytes(
                    of: _asciiDigits[unchecked: Int(truncatingIfNeeded: value % 100)],
                    toUncheckedByteOffset: offset,
                    as: (UInt8, UInt8).self)
                value /= 100
            }
            if value != 0 {
                offset &-= 1
                buffer.storeBytes(
                    of: UInt8(truncatingIfNeeded: value) | 0x30,
                    toUncheckedByteOffset: offset,
                    as: UInt8.self)
            }
        }
        return offset..<buffer.byteCount
    }
}

private extension UInt128 {
    func _ascii(_ buffer: inout MutableRawSpan) -> Range<Int> {
        if self <= 0xffff_ffff_ffff_ffff /* UInt64.max */ {
            return UInt64(truncatingIfNeeded: self)._ascii(&buffer)
        }
        var value = self
        var remainder: Self
        var offset = buffer.byteCount
        (value, remainder) = value._quotientAndRemainder(dividingBy1e: 19)
        _ = UInt64(truncatingIfNeeded: remainder)._ascii(&buffer)
        var b = buffer._mutatingExtracting(unchecked: 0..<(offset &- 19))
        if value < 10_000_000_000_000_000_000 {
            offset =
                UInt64(truncatingIfNeeded: value)._ascii(&b).lowerBound
        } else {
            (value, remainder) = value._quotientAndRemainder(dividingBy1e: 19)
            _ = UInt64(truncatingIfNeeded: remainder)._ascii(&b)
            offset &-= 39
            b.storeBytes(
                of: UInt8(truncatingIfNeeded: value) | 0x30,
                toUncheckedByteOffset: offset,
                as: UInt8.self)

        }
        return offset..<buffer.byteCount
    }
}

extension Decimal {
#if FOUNDATION_FRAMEWORK
#else
    @_spi(SwiftCorelibsFoundation)
    public func toString(with locale: Locale? = nil) -> String {
        let separator: String
        if let locale = locale,
           let localizedSeparator = locale.decimalSeparator {
            separator = localizedSeparator
        } else {
            separator = "."
        }
        return _toString(withDecimalSeparator: separator)
    }
    
    @_spi(SwiftCorelibsFoundation)
    public static func decimal(
        from stringView: String.UTF8View,
        decimalSeparator: String.UTF8View,
        matchEntireString: Bool
    ) -> (result: Decimal?, processedLength: Int) {
        do {
            let (result, _, processedCodeUnits) = try Self.__decimal(
                from: stringView.span,
                prevalidatedUTF8: true,
                decimalSeparator: UTF8Span(unchecked: decimalSeparator.span),
                matchEntireString: matchEntireString)
            return (result, processedCodeUnits)
        } catch {
            return (nil, 0)
        }
    }
#endif

    internal func _toString(withDecimalSeparator separator: String) -> String {
        if self._length == 0 {
            return self._isNegative == 0 ? "0" : "NaN"
        }
        let isNegative = (self._isNegative != 0)
        let significand = self._significand
        var digits = [39 of UTF8.CodeUnit](repeating: 0x30 /* "0" */)
        var span = digits.mutableSpan, bytes = span.mutableBytes
        let range = significand._ascii(&bytes)
        let digitCount = range.count
        let separatorCount = separator.utf8.count
        let exponent = Int(self._exponent)
        let byteCount = (isNegative ? 1 : 0)
            + (exponent >= 0
                ? digitCount + exponent
                : -exponent < digitCount
                    ? digitCount + separatorCount
                    : 1 + separatorCount + (-exponent))
        return String(unsafeUninitializedCapacity: byteCount) { buffer in
            var i = 0
            func put(_ byte: UInt8) {
                buffer[i] = byte
                i &+= 1
            }
            if isNegative { put(0x2D /* "-" */) }
            if exponent >= 0 {
                for j in range { put(digits[unchecked: j]) }
                for _ in 0..<exponent { put(0x30 /* "0" */) }
            } else {
                let scale = -exponent
                if scale < digitCount {
                    let n = digitCount - scale
                    for j in range.prefix(n) { put(digits[unchecked: j]) }
                    for byte in separator.utf8 { put(byte) }
                    for k in range.dropFirst(n) { put(digits[unchecked: k])}
                } else {
                    put(0x30)
                    for byte in separator.utf8 { put(byte) }
                    for _ in 0..<(scale - digitCount) { put(0x30) }
                    for j in range { put(digits[unchecked: j]) }
                }
            }
            assert(i == byteCount)
            return i
        }
    }

    internal enum _ParseError: Error {
        case empty
        case invalid
        case overflow(processedCodeUnits: Int)
        case underflow(processedCodeUnits: Int)
        case quirkyZero(processedCodeUnits: Int) // Compatibility quirk.
    }

    internal static func __decimal(
        from utf8: Span<UInt8>,
        prevalidatedUTF8: Bool = false,
        decimalSeparator: UTF8Span,
        matchEntireString: Bool
    ) throws(_ParseError) -> (result: Decimal, inexact: Bool, processedCodeUnits: Int) {
        let count = utf8.count
        guard count > 0 else { throw _ParseError.empty }

        @inline(__always)
        func isWhitespace(_ codeUnit: UInt8) -> Bool {
            codeUnit == 0x20 || (0x09...0x0D).contains(codeUnit)
            // Although *Unicode scalars* 0x85 (NEL) and 0xA0 (NO-BREAK SPACE)
            // are whitespace, as *UTF-8 code units* they're continuation bytes.
        }

        func skipWhitespaces(from index: Int) -> Int {
            var i = index
            while i != count && isWhitespace(utf8[unchecked: i]) {
                i &+= 1
            }
            return i
        }

        func containsASCII(
            at index: Int,
            _ needle: Span<UInt8>
        ) -> Int? {
            var i = index
            for j in 0..<needle.count {
                let codeUnit = needle[unchecked: j]
                guard i != count, codeUnit == utf8[unchecked: i] else {
                    return nil
                }
                i &+= 1
            }
            return i
        }

        func containsCaseInsensitiveASCII(
            at index: Int,
            lowercasedAlphabetic needle: Span<UInt8> // Must be lowercased a-z.
        ) -> Int? {
            var i = index
            for j in 0..<needle.count {
                let codeUnit = needle[unchecked: j]
                guard i != count, codeUnit == (utf8[unchecked: i] | 0x20) else {
                    return nil
                }
                i &+= 1
            }
            return i
        }

        var index = 0
        index = skipWhitespaces(from: index)

        // Get the sign.
        var isNegative = false
        if index != utf8.count
            && (utf8[unchecked: index] == UInt8._plus
                || utf8[unchecked: index] == UInt8._minus) {
            isNegative = (utf8[unchecked: index] == UInt8._minus)
            index &+= 1
        }

        // Handle NaN.
        let nan: [3 of UInt8] = [0x6e, 0x61, 0x6e]
        if let i = containsCaseInsensitiveASCII(at: index, lowercasedAlphabetic: nan.span) {
            index = i
            // If required to match the entire string, trim trailing whitespace
            // and check if we are at the end of the string.
            if matchEntireString {
                index = skipWhitespaces(from: index)
                guard index == utf8.count else {
                    throw _ParseError.invalid
                }
            }
            return (.nan, false, index)
        }

        // Build mantissa and exponent.
        var significand: UInt128 = 0
        var low: UInt64 = 0
        var full = false
        // We're 'full' if the significand is at capacity and further digits need to be dropped.
        var halfFull = false
        var round = 0
        var sticky = false
        var exponent = 0

        @inline(__always)
        func consume(_ digit: Int, _ fraction: Bool) {
            if full {
                if digit != 0 { sticky = true }
                // Increment exponent if dropping a non-fractional digit.
                if !fraction { exponent += 1 }
                return
            }
            if !halfFull {
                if low == 0 && digit == 0 {
                    // Decrement exponent if a fractional digit.
                    if fraction { exponent -= 1 }
                    return
                }
                if low < 1_000_000_000_000_000_000 {
                    low = low &* 10 &+ UInt64(truncatingIfNeeded:  digit)
                    if fraction { exponent -= 1 }
                    return
                }
                significand = UInt128(truncatingIfNeeded: low)
                halfFull = true
            }
            let (product, ov1) = significand.multipliedReportingOverflow(by: 10)
            let (sum, ov2) = product.addingReportingOverflow(UInt128(truncatingIfNeeded: digit))
            if ov1 || ov2 {
                full = true
                round = digit
                // Increment exponent if dropping a non-fractional digit.
                if !fraction { exponent += 1 }
                return
            }
            significand = sum
            // Decrement exponent if a fractional digit.
            if fraction { exponent -= 1 }
        }

        @inline(__always)
        func digit(_ codeUnit: UInt8) -> Int? {
            guard codeUnit >= 0x30 && codeUnit <= 0x39 else { return nil }
            return Int(truncatingIfNeeded: codeUnit ^ 0x30)
        }

        while index != utf8.count, let digitValue = digit(utf8[unchecked: index]) {
            consume(digitValue, false)
            index &+= 1
        }
        // Get the decimal separator.
        let i: Int?
        let separator = decimalSeparator.span
        if separator.count == 1 && (separator[unchecked: 0] < 0x80) {
            i = containsASCII(at: index, separator)
        } else {
            do throws(UTF8.ValidationError) {
                var needle = decimalSeparator.makeCharacterIterator()
                var haystack = prevalidatedUTF8
                    ? UTF8Span(unchecked: utf8.extracting(unchecked: index..<count))
                        .makeCharacterIterator()
                    : try UTF8Span(validating: utf8.extracting(unchecked: index..<count))
                        .makeCharacterIterator()
                var unmatched = false
                while let n = needle.next() {
                    guard let h = haystack.next(), n == h else {
                        unmatched = true
                        break
                    }
                }
                i = unmatched ? nil : index + haystack.currentCodeUnitOffset
            } catch {
                throw _ParseError.invalid
            }
        }
        if let i {
            index = i
            // Continue building the mantissa.
            while index != utf8.count, let digitValue = digit(utf8[unchecked: index]) {
                consume(digitValue, true)
                index &+= 1
            }
        }
        if !halfFull {
            significand = UInt128(truncatingIfNeeded: low)
        }
        // Get the exponent, if any.
        let e: [1 of UInt8] = [0x65]
        if let i = containsCaseInsensitiveASCII(at: index, lowercasedAlphabetic: e.span) {
            index = i
            var eIsNegative = false
            var eIsOverlarge = false
            var e_ = 0
            // Preserve parsing quirk: if there is no content or invalid content after 'e',
            // deem the exponent as '0' rather than rejecting the string as invalid.
            if index != utf8.count
                && (utf8[unchecked: index] == UInt8._minus
                    || utf8[unchecked: index] == UInt8._plus) {
                eIsNegative = (utf8[unchecked: index] == UInt8._minus)
                index &+= 1
            }
            var combined = exponent
            if eIsNegative {
                while index != utf8.count, let digitValue = digit(utf8[unchecked: index]) {
                    if !eIsOverlarge {
                        e_ = e_ &* 10 &+ digitValue
                        combined = exponent - e_
                        if combined < -32768 { eIsOverlarge = true }
                    }
                    index &+= 1
                }
                exponent = eIsOverlarge ? -32768 : combined
            } else {
                while index != utf8.count, let digitValue = digit(utf8[unchecked: index]) {
                    if !eIsOverlarge {
                        e_ = e_ &* 10 &+ digitValue
                        combined = exponent + e_
                        if combined > 32767 { eIsOverlarge = true }
                    }
                    index &+= 1
                }
                exponent = eIsOverlarge ? 32767 : combined
            }
        }

        // If required to match the entire string, trim trailing whitespace
        // and check if we are at the end of the string.
        if matchEntireString {
            index = skipWhitespaces(from: index)
            guard index == utf8.count else {
                throw _ParseError.invalid
            }
        }
        // If nothing was consumed, the entire string isn't a valid decimal.
        // Preserve parsing quirk: if only "e" was consumed, it's not a failure.
        if index == 0 { throw _ParseError.invalid }
        if significand == 0 {
            if (-128...127).contains(exponent) {
                return (.zero, false, index)
            }
            // Compatibility behavior is to reject "0e1000".
            throw _ParseError.quirkyZero(processedCodeUnits: index)
        }

        do throws(_CalculationError) {
            let (result, inexact) = try Self._assemble(
                isNegative: isNegative,
                significand: (0, significand),
                tail: (UInt128(truncatingIfNeeded: round &<< 1) | (sticky ? 1 : 0), 20),
                // See `_assemble` itself for more on handling the round digit and sticky bit.
                exponent: Int32(exponent),
                // Use the minimum exponent for *storage* irrespective of the default scale for arithmetic operations:
                minExponent: -128,
                // Round ties to even irrespective of the default rounding mode for arithmetic operations:
                roundingMode: .bankers)
            return (result, inexact, index)
        } catch .underflow {
            throw _ParseError.underflow(processedCodeUnits: index)
        } catch .overflow {
            throw _ParseError.overflow(processedCodeUnits: index)
        } catch {
            fatalError() // Unreachable.
        }
    }

    internal enum DecimalParseResult {
        case success(Decimal, processedLength: Int)
        case parseFailure
        case overlargeValue

        var asOptional: (result: Decimal?, processedLength: Int) {
            switch self {
            case let .success(decimal, processedLength): (decimal, processedLength: processedLength)
            default: (nil, processedLength: 0)
            }
        }
    }

    internal static func _decimal(
        from utf8: BufferView<UInt8>,
        matchEntireString: Bool
    ) -> DecimalParseResult {
        do {
            let (result, _, processedCodeUnits) = try Self.__decimal(
                from: utf8.span,
                decimalSeparator: ".".utf8Span,
                matchEntireString: matchEntireString)
            return .success(result, processedLength: processedCodeUnits)
        } catch _ParseError.underflow, _ParseError.overflow, _ParseError.quirkyZero {
            return .overlargeValue
        } catch {
            return .parseFailure
        }
    }
}
