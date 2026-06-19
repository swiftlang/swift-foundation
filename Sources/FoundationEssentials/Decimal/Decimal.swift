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
        if self <= 18446744073709551615 /* UInt64.max */ {
            return UInt64(truncatingIfNeeded: self)._ascii(&buffer)
        }
        var value = self
        var remainder: Self
        var offset = buffer.byteCount
        (value, remainder) = value._quotientAndRemainder(dividingBy1e: 19)
        _ = UInt64(truncatingIfNeeded: remainder)._ascii(&buffer)
        var b = buffer._mutatingExtracting(unchecked: 0..<(offset &- 19))
        if value < 10000000000000000000 {
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
        _decimal(from: stringView, decimalSeparator: decimalSeparator, matchEntireString: matchEntireString).asOptional
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

    @_specialize(where UTF8Collection == String.UTF8View)
    @_specialize(where UTF8Collection == BufferView<UInt8>)
    internal static func _decimal<UTF8Collection: Collection<UTF8.CodeUnit>>(
        from utf8: UTF8Collection,
        decimalSeparator: String.UTF8View = ".".utf8,
        matchEntireString: Bool,
        lenient: Bool = false
    ) -> DecimalParseResult {
        @inline(__always)
        func isASCIIWhitespace(_ b: UInt8) -> Bool {
            b == 0x20 || (0x09...0x0D).contains(b)
            // Although *Unicode scalars* 0x85 (NEL) and 0xA0 (NO-BREAK SPACE)
            // are whitespace, as *UTF-8 code units* they're continuation bytes.
        }

        func skipASCIIWhitespaces(from index: UTF8Collection.Index) -> UTF8Collection.Index {
            var index = index
            while index != utf8.endIndex && isASCIIWhitespace(utf8[index]) {
                utf8.formIndex(after: &index)
            }
            return index
        }

        func stringViewContainsDecimalSeparator(
            at index: UTF8Collection.Index
        ) -> UTF8Collection.Index? {
            var index = index
            var decimalIndex = decimalSeparator.startIndex
            while decimalIndex != decimalSeparator.endIndex {
                guard index != utf8.endIndex else {
                    // Input ran out before we matched the entire separator.
                    return nil
                }
                if utf8[index] != decimalSeparator[decimalIndex] {
                    return nil
                }
                decimalSeparator.formIndex(after: &decimalIndex)
                utf8.formIndex(after: &index)
            }
            return index
        }

        func stringViewContainsLowercasedASCII(
            at index: UTF8Collection.Index,
            _ pattern: String.UTF8View // Must be lowercased ASCII.
        ) -> UTF8Collection.Index? {
            var index = index
            for b in pattern {
                guard index != utf8.endIndex, b == (utf8[index] | 0x20) else {
                    return nil
                }
                utf8.formIndex(after: &index)
            }
            return index
        }

        var index = utf8.startIndex
        index = skipASCIIWhitespaces(from: index)

        // Get the sign.
        var isNegative = false
        if index != utf8.endIndex &&
            (utf8[index] == UInt8._plus || utf8[index] == UInt8._minus) {
            isNegative = (utf8[index] == UInt8._minus)
            utf8.formIndex(after: &index)
        }

        // Handle NaN.
        if let i = stringViewContainsLowercasedASCII(at: index, "nan".utf8) {
            index = i
            // If required to match the entire string, trim trailing whitespace
            // and check if we are at the end of the string.
            if matchEntireString {
                index = skipASCIIWhitespaces(from: index)
                guard index == utf8.endIndex else {
                    return .parseFailure
                }
            }
            let processedLength = utf8.distance(from: utf8.startIndex, to: index)
            return .success(.nan, processedLength: processedLength)
        }

        // Build mantissa and exponent.
        var significand: UInt128 = 0
        var full = false // We're 'full' if the significand is at capacity and further digits need to be dropped.
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
            if significand == 0 && digit == 0 {
                // Decrement exponent if a fractional digit.
                if fraction { exponent -= 1 }
                return
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

        while index != utf8.endIndex, let digitValue = utf8[index].digitValue {
            defer { utf8.formIndex(after: &index) }
            consume(digitValue, false)
        }
        // Get the decimal point.
        if let i = stringViewContainsDecimalSeparator(at: index) {
            index = i
            // Continue building the mantissa.
            while index != utf8.endIndex, let digitValue = utf8[index].digitValue {
                defer { utf8.formIndex(after: &index) }
                consume(digitValue, true)
            }
        }
        // Get the exponent, if any.
        if index < utf8.endIndex && (utf8[index] == UInt8._E || utf8[index] == UInt8._e) {
            utf8.formIndex(after: &index)
            var eIsNegative = false
            var eIsOverlarge = false
            var e = 0
            // Preserve parsing quirk: if there is no content or invalid content after 'e',
            // deem the exponent as '0' rather than rejecting the string as invalid.
            if index != utf8.endIndex && (utf8[index] == UInt8._minus || utf8[index] == UInt8._plus) {
                eIsNegative = utf8[index] == UInt8._minus
                utf8.formIndex(after: &index)
            }
            var combined = exponent
            if eIsNegative {
                while index != utf8.endIndex, let digitValue = utf8[index].digitValue {
                    if !eIsOverlarge {
                        e = e * 10 + digitValue
                        combined = exponent - e
                        if combined < -32768 { eIsOverlarge = true }
                    }
                    utf8.formIndex(after: &index)
                }
                exponent = eIsOverlarge ? -32768 : combined
            } else {
                while index != utf8.endIndex, let digitValue = utf8[index].digitValue {
                    if !eIsOverlarge {
                        e = e * 10 + digitValue
                        combined = exponent + e
                        if combined > 32767 { eIsOverlarge = true }
                    }
                    utf8.formIndex(after: &index)
                }
                exponent = eIsOverlarge ? 32767 : combined
            }
        }

        // If required to match the entire string, trim trailing whitespace
        // and check if we are at the end of the string.
        if matchEntireString {
            index = skipASCIIWhitespaces(from: index)
            guard index == utf8.endIndex else {
                return .parseFailure
            }
        }
        // If nothing was consumed, the entire string isn't a valid decimal.
        // Preserve parsing quirk: if only "e" was consumed, it's not a failure.
        if index == utf8.startIndex {
            return .parseFailure
        }
        let processedLength = utf8.distance(from: utf8.startIndex, to: index)
        if significand == 0 {
            if lenient || (-128...127).contains(exponent) {
                return .success(.zero, processedLength: processedLength)
            }
            return .overlargeValue // Compatibility behavior is to reject "0e1000".
        }

        do {
            let (result, _) = try Self._assemble(
                isNegative: isNegative,
                significand: (0, significand),
                tail: (UInt128(truncatingIfNeeded: round &<< 1) | (sticky ? 1 : 0), 20),
                // See `_assemble` itself for more on handling the round digit and sticky bit.
                exponent: Int32(exponent),
                // Use the minimum exponent for *storage* irrespective of the default scale for arithmetic operations:
                minExponent: -128,
                // Round ties to even irrespective of the default rounding mode for arithmetic operations:
                roundingMode: .bankers)
            return .success(result, processedLength: processedLength)
        } catch _CalculationError.underflow {
            if lenient {
                return .success(.zero, processedLength: processedLength)
            }
            return .overlargeValue // Compatibility behavior is to reject.
        } catch {
            return .overlargeValue
        }
    }
}
