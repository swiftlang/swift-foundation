//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK
internal import _ForSwiftFoundation
#endif // FOUNDATION_FRAMEWORK

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Decimal : CustomStringConvertible {
    public init?(string: __shared String, locale: __shared Locale? = nil) {
        let decimalSeparator = locale?.decimalSeparator ?? "."
        guard case let .success(value, _) = Decimal._decimal(
            from: string.utf8,
            decimalSeparator: decimalSeparator.utf8,
            matchEntireString: false
        ) else {
            return nil
        }
        self = value
    }

    public var description: String {
        return self._toString(withDecimalSeparator: ".")
    }
}

// The methods in this extension exist to match the protocol requirements of
// FloatingPoint, even if we can't conform directly.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Decimal /* : FloatingPoint */ {
    public static let leastFiniteMagnitude = Decimal(
        _exponent: 127,
        _length: 8,
        _isNegative: 1,
        _isCompact: 1,
        _reserved: 0,
        _mantissa: (0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff)
    )

    public static let greatestFiniteMagnitude = Decimal(
        _exponent: 127,
        _length: 8,
        _isNegative: 0,
        _isCompact: 1,
        _reserved: 0,
        _mantissa: (0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff)
    )

    public static let leastNormalMagnitude = Decimal(
        _exponent: -127,
        _length: 1,
        _isNegative: 0,
        _isCompact: 1,
        _reserved: 0,
        _mantissa: (0x0001, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000)
    )

    public static let leastNonzeroMagnitude = Decimal(
        _exponent: -127,
        _length: 1,
        _isNegative: 0,
        _isCompact: 1,
        _reserved: 0,
        _mantissa: (0x0001, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000)
    )

    public static let pi = Decimal(
        _exponent: -38,
        _length: 8,
        _isNegative: 0,
        _isCompact: 1,
        _reserved: 0,
        _mantissa: (0x6623, 0x7d57, 0x16e7, 0xad0d, 0xaf52, 0x4641, 0xdfa7, 0xec58)
    )

    @available(*, unavailable, message: "Decimal does not yet fully adopt FloatingPoint.")
    public static var infinity: Decimal { fatalError("Decimal does not yet fully adopt FloatingPoint") }

    @available(*, unavailable, message: "Decimal does not yet fully adopt FloatingPoint.")
    public static var signalingNaN: Decimal { fatalError("Decimal does not yet fully adopt FloatingPoint") }

    public static var quietNaN: Decimal {
        return Decimal(
            _exponent: 0, _length: 0, _isNegative: 1, _isCompact: 0,
            _reserved: 0, _mantissa: (0, 0, 0, 0, 0, 0, 0, 0))
    }

    public static var nan: Decimal { quietNaN }

    public static var radix: Int { 10 }

    public init(_ value: UInt8) {
        self.init(UInt64(value))
    }

    public init(_ value: Int8) {
        self.init(Int64(value))
    }

    public init(_ value: UInt16) {
        self.init(UInt64(value))
    }

    public init(_ value: Int16) {
        self.init(Int64(value))
    }

    public init(_ value: UInt32) {
        self.init(UInt64(value))
    }

    public init(_ value: Int32) {
        self.init(Int64(value))
    }

    public init(_ value: UInt64) {
        self = Decimal()
        if value == 0 {
            return
        }

        var compactValue = value
        var exponent: Int32 = 0
        while compactValue % 10 == 0 {
            compactValue /= 10
            exponent += 1
        }
        _isCompact = 1
        _exponent = exponent

        let wordCount = ((UInt64.bitWidth - compactValue.leadingZeroBitCount) + (UInt16.bitWidth - 1)) / UInt16.bitWidth
        _length = UInt32(wordCount)
        _mantissa.0 = UInt16(truncatingIfNeeded: compactValue >> 0)
        _mantissa.1 = UInt16(truncatingIfNeeded: compactValue >> 16)
        _mantissa.2 = UInt16(truncatingIfNeeded: compactValue >> 32)
        _mantissa.3 = UInt16(truncatingIfNeeded: compactValue >> 48)
    }

    public init(_ value: Int64) {
        self = .init(value.magnitude)
        if value < 0 {
            self._isNegative = 1
        }
    }

    public init(_ value: UInt) {
        self.init(UInt64(value))
    }

    public init(_ value: Int) {
        self.init(Int64(value))
    }

    public init(_ value: Double) {
        precondition(!value.isInfinite, "Decimal does not yet fully adopt FloatingPoint")
        if value.isNaN {
            self = Decimal.nan
        } else if value == 0.0 {
            self = Decimal()
        } else {
            self = Decimal()
            let negative = value < 0
            var val = negative ? -1 * value : value
            var exponent: Int8 = 0

            // Try to get val as close to UInt64.max whilst adjusting the exponent
            // to reduce the number of digits after the decimal point.
            while val < Double(UInt64.max - 1) {
                guard exponent > Int8.min else {
                    self = .nan
                    return
                }
                val *= 10.0
                exponent -= 1
            }
            while Double(UInt64.max) <= val {
                guard exponent < Int8.max else {
                    self = .nan
                    return
                }
                val /= 10.0
                exponent += 1
            }
            var mantissa: UInt64
            let maxMantissa = Double(UInt64.max).nextDown
            if val > maxMantissa {
                // UInt64(Double(UInt64.max)) gives an overflow error,
                // this is the largest mantissa that can be set.
                mantissa = UInt64(maxMantissa)
            } else {
                mantissa = UInt64(val)
            }

            var i: UInt32 = 0
            // This is a bit ugly but it is the closest approximation of the C
            // initializer that can be expressed here.
            while mantissa != 0 && i < 8 /* NSDecimalMaxSize */ {
                switch i {
                case 0:
                    _mantissa.0 = UInt16(truncatingIfNeeded: mantissa)
                case 1:
                    _mantissa.1 = UInt16(truncatingIfNeeded: mantissa)
                case 2:
                    _mantissa.2 = UInt16(truncatingIfNeeded: mantissa)
                case 3:
                    _mantissa.3 = UInt16(truncatingIfNeeded: mantissa)
                case 4:
                    _mantissa.4 = UInt16(truncatingIfNeeded: mantissa)
                case 5:
                    _mantissa.5 = UInt16(truncatingIfNeeded: mantissa)
                case 6:
                    _mantissa.6 = UInt16(truncatingIfNeeded: mantissa)
                case 7:
                    _mantissa.7 = UInt16(truncatingIfNeeded: mantissa)
                default:
                    fatalError("initialization overflow")
                }
                mantissa = mantissa >> 16
                i += 1
            }
            _length = i
            _isNegative = negative ? 1 : 0
            _isCompact = 0
            _exponent = Int32(exponent)
            self.compact()
        }
    }

    public init(sign: FloatingPointSign, exponent: Int, significand: Decimal) {
#if FOUNDATION_FRAMEWORK
        // Compatibility path
        if Self.compatibility1 {
            self.init(
                _exponent: Int32(exponent) + significand._exponent,
                _length: significand._length,
                _isNegative: sign == .plus ? 0 : 1,
                _isCompact: significand._isCompact,
                _reserved: 0,
                _mantissa: significand._mantissa
            )
            return
        }
#endif

        self = significand
        do {
            self = try significand._multiplyByPowerOfTen(
                power: Int(Int16(clamping: exponent)), roundingMode: .plain)
        } catch {
            guard let actual = error as? Decimal._CalculationError else {
                self = .nan
                return
            }
            if actual == .underflow {
                self = 0
            } else {
                self = .nan
            }
        }
        if sign == .minus {
            negate()
        }
    }

    public init(signOf: Decimal, magnitudeOf magnitude: Decimal) {
        self.init(
            _exponent: magnitude._exponent,
            _length: magnitude._length,
            _isNegative: signOf._isNegative,
            _isCompact: magnitude._isCompact,
            _reserved: 0,
            _mantissa: magnitude._mantissa)
    }

    public var exponent: Int {
        return Int(_exponent)
    }

    public var significand: Decimal {
        return Decimal(
            _exponent: 0, _length: _length, _isNegative: 0, _isCompact: _isCompact,
            _reserved: 0, _mantissa: _mantissa)
    }

    public var sign: FloatingPointSign {
        return _isNegative == 0 ? FloatingPointSign.plus : FloatingPointSign.minus
    }

    public var ulp: Decimal {
        guard isFinite else { return .nan }

        let exponent: Int32
        if isZero {
            exponent = .min
        } else {
            let shift = _powersOfTenDividingUInt128Max.firstIndex {
                return significand > $0
            } ?? _powersOfTenDividingUInt128Max.count
            exponent = _exponent &- Int32(shift)
        }

        return Decimal(
            _exponent: max(exponent, -128), _length: 1, _isNegative: 0, _isCompact: 1,
            _reserved: 0, _mantissa: (0x0001, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000))
    }

    /// The IEEE 754 "class" of this type.
    public var floatingPointClass: FloatingPointClassification {
        if _length == 0 && _isNegative == 1 {
            return .quietNaN
        } else if _length == 0 {
            return .positiveZero
        }
        // NSDecimal does not really represent normal and subnormal in the same
        // manner as the IEEE standard, for now we can probably claim normal for
        // any nonzero, non-NaN values.
        if _isNegative == 1 {
            return .negativeNormal
        } else {
            return .positiveNormal
        }
    }

    public var isCanonical: Bool { true }

    /// `true` if `self` is negative, `false` otherwise.
    public var isSignMinus: Bool { _isNegative != 0 }

    /// `true` if `self` is +0.0 or -0.0, `false` otherwise.
    public var isZero: Bool { _length == 0 && _isNegative == 0 }

    /// `true` if `self` is subnormal, `false` otherwise.
    public var isSubnormal: Bool { false }

    /// `true` if `self` is normal (not zero, subnormal, infinity, or NaN),
    /// `false` otherwise.
    public var isNormal: Bool { !isZero && !isInfinite && !isNaN }

    /// `true` if `self` is zero, subnormal, or normal (not infinity or NaN),
    /// `false` otherwise.
    public var isFinite: Bool { !isNaN }

    /// `true` if `self` is infinity, `false` otherwise.
    public var isInfinite: Bool { false }

    /// `true` if `self` is NaN, `false` otherwise.
    public var isNaN: Bool { _length == 0 && _isNegative == 1 }

    /// `true` if `self` is a signaling NaN, `false` otherwise.
    public var isSignaling: Bool { false }

    /// `true` if `self` is a signaling NaN, `false` otherwise.
    public var isSignalingNaN: Bool { false }

    @available(*, unavailable, message: "Decimal does not yet fully adopt FloatingPoint.")
    public mutating func formTruncatingRemainder(dividingBy other: Decimal) { fatalError("Decimal does not yet fully adopt FloatingPoint") }

    public var nextUp: Decimal {
        if _isNegative == 1 {
            if _exponent > -128 &&
               (_mantissa.0, _mantissa.1, _mantissa.2, _mantissa.3) == (0x999a, 0x9999, 0x9999, 0x9999) &&
               (_mantissa.4, _mantissa.5, _mantissa.6, _mantissa.7) == (0x9999, 0x9999, 0x9999, 0x1999) {
                return Decimal(
                    _exponent: _exponent &- 1,
                    _length: 8,
                    _isNegative: 1,
                    _isCompact: 1,
                    _reserved: 0,
                    _mantissa: (0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff)
                )
            }
        } else {
            if _exponent < 127 &&
               (_mantissa.0, _mantissa.1, _mantissa.2, _mantissa.3) == (0xffff, 0xffff, 0xffff, 0xffff) &&
               (_mantissa.4, _mantissa.5, _mantissa.6, _mantissa.7) == (0xffff, 0xffff, 0xffff, 0xffff) {
                return Decimal(
                    _exponent: _exponent &+ 1,
                    _length: 8,
                    _isNegative: 0,
                    _isCompact: 1,
                    _reserved: 0,
                    _mantissa: (0x999a, 0x9999, 0x9999, 0x9999, 0x9999, 0x9999, 0x9999, 0x1999)
                )
            }
        }
        return self + ulp
    }

    public var nextDown: Decimal {
        return -(-self).nextUp
    }

    public func isEqual(to other: Decimal) -> Bool {
        return self == other
    }

    public func isLess(than other: Decimal) -> Bool {
        return Decimal._compare(lhs: self, rhs: other) == .orderedAscending
    }

    public func isLessThanOrEqualTo(_ other: Decimal) -> Bool {
        let order = Decimal._compare(lhs: self, rhs: other)
        return order == .orderedAscending || order == .orderedSame
    }

    public func isTotallyOrdered(belowOrEqualTo other: Decimal) -> Bool {
        // Note: Decimal does not have -0 or infinities to worry about
        if self.isNaN {
            return false
        }
        if self < other {
            return true
        }
        if other < self {
            return false
        }
        // Fall through to == behavior
        return true
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Decimal : ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self.init(value)
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Decimal : ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(value)
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Decimal: Hashable {
    internal subscript(index: UInt32) -> UInt16 {
        get {
            switch index {
            case 0: return _mantissa.0
            case 1: return _mantissa.1
            case 2: return _mantissa.2
            case 3: return _mantissa.3
            case 4: return _mantissa.4
            case 5: return _mantissa.5
            case 6: return _mantissa.6
            case 7: return _mantissa.7
            default: fatalError("Invalid index \(index) for _mantissa")
            }
        }
        set {
            switch index {
            case 0: _mantissa.0 = newValue
            case 1: _mantissa.1 = newValue
            case 2: _mantissa.2 = newValue
            case 3: _mantissa.3 = newValue
            case 4: _mantissa.4 = newValue
            case 5: _mantissa.5 = newValue
            case 6: _mantissa.6 = newValue
            case 7: _mantissa.7 = newValue
            default: fatalError("Invalid index \(index) for _mantissa")
            }
        }
    }

    public func hash(into hasher: inout Hasher) {
        // FIXME: This is a weak hash.  We should rather normalize self to a
        // canonical member of the exact same equivalence relation that
        // NSDecimalCompare implements, then simply feed all components to the
        // hasher.
        hasher.combine(doubleValue)
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Decimal : Equatable {
    public static func ==(lhs: Decimal, rhs: Decimal) -> Bool {
#if FOUNDATION_FRAMEWORK
        let bitwiseEqual: Bool =
            lhs._exponent == rhs._exponent &&
            lhs._length == rhs._length &&
            lhs._isNegative == rhs._isNegative &&
            lhs._isCompact == rhs._isCompact &&
            lhs._reserved == rhs._reserved &&
            lhs._mantissa.0 == rhs._mantissa.0 &&
            lhs._mantissa.1 == rhs._mantissa.1 &&
            lhs._mantissa.2 == rhs._mantissa.2 &&
            lhs._mantissa.3 == rhs._mantissa.3 &&
            lhs._mantissa.4 == rhs._mantissa.4 &&
            lhs._mantissa.5 == rhs._mantissa.5 &&
            lhs._mantissa.6 == rhs._mantissa.6 &&
            lhs._mantissa.7 == rhs._mantissa.7
#else
        let bitwiseEqual: Bool =
            lhs.storage.exponent == rhs.storage.exponent &&
            lhs.storage.lengthFlagsAndReserved == rhs.storage.lengthFlagsAndReserved &&
            lhs.storage.reserved == rhs.storage.reserved &&
            lhs.storage.mantissa.0 == rhs.storage.mantissa.0 &&
            lhs.storage.mantissa.1 == rhs.storage.mantissa.1 &&
            lhs.storage.mantissa.2 == rhs.storage.mantissa.2 &&
            lhs.storage.mantissa.3 == rhs.storage.mantissa.3 &&
            lhs.storage.mantissa.4 == rhs.storage.mantissa.4 &&
            lhs.storage.mantissa.5 == rhs.storage.mantissa.5 &&
            lhs.storage.mantissa.6 == rhs.storage.mantissa.6 &&
            lhs.storage.mantissa.7 == rhs.storage.mantissa.7
#endif
        if bitwiseEqual {
            return true
        }
        return Decimal._compare(lhs: lhs, rhs: rhs) == .orderedSame
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Decimal : Comparable {
    public static func <(lhs: Decimal, rhs: Decimal) -> Bool {
        return Decimal._compare(lhs: lhs, rhs: rhs) == .orderedAscending
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Decimal : Codable {
    private enum CodingKeys : Int, CodingKey {
        case exponent
        case length
        case isNegative
        case isCompact
        case mantissa
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let exponent = try container.decode(CInt.self, forKey: .exponent)
        let length = try container.decode(CUnsignedInt.self, forKey: .length)
        let isNegative = try container.decode(Bool.self, forKey: .isNegative)
        let isCompact = try container.decode(Bool.self, forKey: .isCompact)

        var mantissaContainer = try container.nestedUnkeyedContainer(forKey: .mantissa)
        var mantissa: (CUnsignedShort, CUnsignedShort, CUnsignedShort, CUnsignedShort,
                       CUnsignedShort, CUnsignedShort, CUnsignedShort, CUnsignedShort) = (0,0,0,0,0,0,0,0)
        mantissa.0 = try mantissaContainer.decode(CUnsignedShort.self)
        mantissa.1 = try mantissaContainer.decode(CUnsignedShort.self)
        mantissa.2 = try mantissaContainer.decode(CUnsignedShort.self)
        mantissa.3 = try mantissaContainer.decode(CUnsignedShort.self)
        mantissa.4 = try mantissaContainer.decode(CUnsignedShort.self)
        mantissa.5 = try mantissaContainer.decode(CUnsignedShort.self)
        mantissa.6 = try mantissaContainer.decode(CUnsignedShort.self)
        mantissa.7 = try mantissaContainer.decode(CUnsignedShort.self)

        self = Decimal(_exponent: exponent,
                       _length: length,
                       _isNegative: CUnsignedInt(isNegative ? 1 : 0),
                       _isCompact: CUnsignedInt(isCompact ? 1 : 0),
                       _reserved: 0,
                       _mantissa: mantissa)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(_exponent, forKey: .exponent)
        try container.encode(_length, forKey: .length)
        try container.encode(_isNegative == 0 ? false : true, forKey: .isNegative)
        try container.encode(_isCompact == 0 ? false : true, forKey: .isCompact)

        var mantissaContainer = container.nestedUnkeyedContainer(forKey: .mantissa)
        try mantissaContainer.encode(_mantissa.0)
        try mantissaContainer.encode(_mantissa.1)
        try mantissaContainer.encode(_mantissa.2)
        try mantissaContainer.encode(_mantissa.3)
        try mantissaContainer.encode(_mantissa.4)
        try mantissaContainer.encode(_mantissa.5)
        try mantissaContainer.encode(_mantissa.6)
        try mantissaContainer.encode(_mantissa.7)
    }
}

// MARK: - SignedNumeric
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Decimal : SignedNumeric {
    public var magnitude: Decimal {
        guard _length != 0 else { return self }
        return Decimal(
            _exponent: self._exponent, _length: self._length,
            _isNegative: 0, _isCompact: self._isCompact,
            _reserved: 0, _mantissa: self._mantissa)
    }

    public init?<T : BinaryInteger>(exactly source: T) {
        let zero = 0 as T

        if source == zero {
            self = Decimal.zero
            return
        }

        let negative: UInt32 = (T.isSigned && source < zero) ? 1 : 0
        var mantissa = source.magnitude
        var exponent: Int32 = 0

        let maxExponent = Int8.max
        while mantissa.isMultiple(of: 10) && (exponent < maxExponent) {
            exponent += 1
            mantissa /= 10
        }

        // If the mantissa still requires more than 128 bits of storage then it is too large.
        if mantissa.bitWidth > 128 && (mantissa >> 128 != zero) { return nil }

        let mantissaParts: (UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16)
        let loWord = UInt64(truncatingIfNeeded: mantissa)
        var length = ((loWord.bitWidth - loWord.leadingZeroBitCount) + (UInt16.bitWidth - 1)) / UInt16.bitWidth
        mantissaParts.0 = UInt16(truncatingIfNeeded: loWord >> 0)
        mantissaParts.1 = UInt16(truncatingIfNeeded: loWord >> 16)
        mantissaParts.2 = UInt16(truncatingIfNeeded: loWord >> 32)
        mantissaParts.3 = UInt16(truncatingIfNeeded: loWord >> 48)

        let hiWord = mantissa.bitWidth > 64 ? UInt64(truncatingIfNeeded: mantissa >> 64) : 0
        if hiWord != 0 {
            length = 4 + ((hiWord.bitWidth - hiWord.leadingZeroBitCount) + (UInt16.bitWidth - 1)) / UInt16.bitWidth
            mantissaParts.4 = UInt16(truncatingIfNeeded: hiWord >> 0)
            mantissaParts.5 = UInt16(truncatingIfNeeded: hiWord >> 16)
            mantissaParts.6 = UInt16(truncatingIfNeeded: hiWord >> 32)
            mantissaParts.7 = UInt16(truncatingIfNeeded: hiWord >> 48)
        } else {
            mantissaParts.4 = 0
            mantissaParts.5 = 0
            mantissaParts.6 = 0
            mantissaParts.7 = 0
        }

        self = Decimal(_exponent: exponent, _length: UInt32(length), _isNegative: negative, _isCompact: 1, _reserved: 0, _mantissa: mantissaParts)
    }

#if FOUNDATION_FRAMEWORK
    @usableFromInline internal static var __zeroForABI: Decimal {
        @_silgen_name("$sSo9NSDecimala10FoundationE4zeroABvgZ")
        get {
            return Decimal(0)
        }
    }
#endif

    public static func +=(lhs: inout Decimal, rhs: Decimal) {
        do {
            let result = try lhs._add(rhs: rhs, roundingMode: .plain)
            lhs = result.result
        } catch {
            lhs = .nan
        }
    }

    public static func -=(lhs: inout Decimal, rhs: Decimal) {
        do {
            let result = try lhs._subtract(rhs: rhs, roundingMode: .plain)
            lhs = result
        } catch {
            lhs = .nan
        }
    }

    public static func *=(lhs: inout Decimal, rhs: Decimal) {
        do {
            let result = try lhs._multiply(by: rhs, roundingMode: .plain)
            lhs = result
        } catch {
            lhs = .nan
        }
    }

    public static func /=(lhs: inout Decimal, rhs: Decimal) {
        do {
            let result = try lhs._divide(by: rhs, roundingMode: .plain)
            lhs = result
        } catch {
            lhs = .nan
        }
    }

    public static func +(lhs: Decimal, rhs: Decimal) -> Decimal {
        var answer = lhs
        answer += rhs
        return answer
    }

    public static func -(lhs: Decimal, rhs: Decimal) -> Decimal {
        var answer = lhs
        answer -= rhs
        return answer
    }

    public static func *(lhs: Decimal, rhs: Decimal) -> Decimal {
        var answer = lhs
        answer *= rhs
        return answer
    }

    public static func /(lhs: Decimal, rhs: Decimal) -> Decimal {
        var answer = lhs
        answer /= rhs
        return answer
    }

    public mutating func negate() {
        guard self._length != 0 else { return }
        self._isNegative = self._isNegative == 0 ? 1 : 0
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Decimal : Strideable {
    public func distance(to other: Decimal) -> Decimal {
        return other - self
    }

    public func advanced(by n: Decimal) -> Decimal {
        return self + n
    }
}

// Max power
private extension Decimal {
    // Creates a value with zero exponent.
    // (Used by `_powersOfTenDividingUInt128Max`.)
    init(
        _length: UInt32,
        _isCompact: UInt32,
        _mantissa: (UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16)
    ) {
        self.init(
            _exponent: 0,
            _length: _length,
            _isNegative: 0,
            _isCompact: _isCompact,
            _reserved: 0,
            _mantissa: _mantissa
        )
    }
}

private let _powersOfTenDividingUInt128Max = [
    /* 10**00 dividing UInt128.max is deliberately omitted. */
    /* 10**01 */ Decimal(_length: 8, _isCompact: 1, _mantissa: (0x9999, 0x9999, 0x9999, 0x9999, 0x9999, 0x9999, 0x9999, 0x1999)),
    /* 10**02 */ Decimal(_length: 8, _isCompact: 1, _mantissa: (0xf5c2, 0x5c28, 0xc28f, 0x28f5, 0x8f5c, 0xf5c2, 0x5c28, 0x028f)),
    /* 10**03 */ Decimal(_length: 8, _isCompact: 1, _mantissa: (0x1893, 0x5604, 0x2d0e, 0x9db2, 0xa7ef, 0x4bc6, 0x8937, 0x0041)),
    /* 10**04 */ Decimal(_length: 8, _isCompact: 1, _mantissa: (0x0275, 0x089a, 0x9e1b, 0x295e, 0x10cb, 0xbac7, 0x8db8, 0x0006)),
    /* 10**05 */ Decimal(_length: 7, _isCompact: 1, _mantissa: (0x3372, 0x80dc, 0x0fcf, 0x8423, 0x1b47, 0xac47, 0xa7c5,0)),
    /* 10**06 */ Decimal(_length: 7, _isCompact: 1, _mantissa: (0x3858, 0xf349, 0xb4c7, 0x8d36, 0xb5ed, 0xf7a0, 0x10c6,0)),
    /* 10**07 */ Decimal(_length: 7, _isCompact: 1, _mantissa: (0xec08, 0x6520, 0x787a, 0xf485, 0xabca, 0x7f29, 0x01ad,0)),
    /* 10**08 */ Decimal(_length: 7, _isCompact: 1, _mantissa: (0x4acd, 0x7083, 0xbf3f, 0x1873, 0xc461, 0xf31d, 0x002a,0)),
    /* 10**09 */ Decimal(_length: 7, _isCompact: 1, _mantissa: (0x5447, 0x8b40, 0x2cb9, 0xb5a5, 0xfa09, 0x4b82, 0x0004,0)),
    /* 10**10 */ Decimal(_length: 6, _isCompact: 1, _mantissa: (0xa207, 0x5ab9, 0xeadf, 0x5ef6, 0x7f67, 0x6df3,0,0)),
    /* 10**11 */ Decimal(_length: 6, _isCompact: 1, _mantissa: (0xf69a, 0xef78, 0x4aaf, 0xbcb2, 0xbff0, 0x0afe,0,0)),
    /* 10**12 */ Decimal(_length: 6, _isCompact: 1, _mantissa: (0x7f0f, 0x97f2, 0xa111, 0x12de, 0x7998, 0x0119,0,0)),
    /* 10**13 */ Decimal(_length: 6, _isCompact: 0, _mantissa: (0x0cb4, 0xc265, 0x7681, 0x6849, 0x25c2, 0x001c,0,0)),
    /* 10**14 */ Decimal(_length: 6, _isCompact: 1, _mantissa: (0x4e12, 0x603d, 0x2573, 0x70d4, 0xd093, 0x0002,0,0)),
    /* 10**15 */ Decimal(_length: 5, _isCompact: 1, _mantissa: (0x87ce, 0x566c, 0x9d58, 0xbe7b, 0x480e,0,0,0)),
    /* 10**16 */ Decimal(_length: 5, _isCompact: 1, _mantissa: (0xda61, 0x6f0a, 0xf622, 0xaca5, 0x0734,0,0,0)),
    /* 10**17 */ Decimal(_length: 5, _isCompact: 1, _mantissa: (0x4909, 0xa4b4, 0x3236, 0x77aa, 0x00b8,0,0,0)),
    /* 10**18 */ Decimal(_length: 5, _isCompact: 1, _mantissa: (0xa0e7, 0x43ab, 0xd1d2, 0x725d, 0x0012,0,0,0)),
    /* 10**19 */ Decimal(_length: 5, _isCompact: 1, _mantissa: (0xc34a, 0x6d2a, 0x94fb, 0xd83c, 0x0001,0,0,0)),
    /* 10**20 */ Decimal(_length: 4, _isCompact: 1, _mantissa: (0x46ba, 0x2484, 0x4219, 0x2f39,0,0,0,0)),
    /* 10**21 */ Decimal(_length: 4, _isCompact: 1, _mantissa: (0xd3df, 0x83a6, 0xed02, 0x04b8,0,0,0,0)),
    /* 10**22 */ Decimal(_length: 4, _isCompact: 1, _mantissa: (0x7b96, 0x405d, 0xe480, 0x0078,0,0,0,0)),
    /* 10**23 */ Decimal(_length: 4, _isCompact: 1, _mantissa: (0x5928, 0xa009, 0x16d9, 0x000c,0,0,0,0)),
    /* 10**24 */ Decimal(_length: 4, _isCompact: 1, _mantissa: (0x88ea, 0x299a, 0x357c, 0x0001,0,0,0,0)),
    /* 10**25 */ Decimal(_length: 3, _isCompact: 1, _mantissa: (0xda7d, 0xd0f5, 0x1ef2,0,0,0,0,0)),
    /* 10**26 */ Decimal(_length: 3, _isCompact: 1, _mantissa: (0x95d9, 0x4818, 0x0318,0,0,0,0,0)),
    /* 10**27 */ Decimal(_length: 3, _isCompact: 0, _mantissa: (0xdbc8, 0x3a68, 0x004f,0,0,0,0,0)),
    /* 10**28 */ Decimal(_length: 3, _isCompact: 1, _mantissa: (0xaf94, 0xec3d, 0x0007,0,0,0,0,0)),
    /* 10**29 */ Decimal(_length: 2, _isCompact: 1, _mantissa: (0xf7f5, 0xcad2,0,0,0,0,0,0)),
    /* 10**30 */ Decimal(_length: 2, _isCompact: 1, _mantissa: (0x4bfe, 0x1448,0,0,0,0,0,0)),
    /* 10**31 */ Decimal(_length: 2, _isCompact: 1, _mantissa: (0x3acc, 0x0207,0,0,0,0,0,0)),
    /* 10**32 */ Decimal(_length: 2, _isCompact: 1, _mantissa: (0xec47, 0x0033,0,0,0,0,0,0)),
    /* 10**33 */ Decimal(_length: 2, _isCompact: 1, _mantissa: (0x313a, 0x0005,0,0,0,0,0,0)),
    /* 10**34 */ Decimal(_length: 1, _isCompact: 1, _mantissa: (0x84ec,0,0,0,0,0,0,0)),
    /* 10**35 */ Decimal(_length: 1, _isCompact: 1, _mantissa: (0x0d4a,0,0,0,0,0,0,0)),
    /* 10**36 */ Decimal(_length: 1, _isCompact: 0, _mantissa: (0x0154,0,0,0,0,0,0,0)),
    /* 10**37 */ Decimal(_length: 1, _isCompact: 1, _mantissa: (0x0022,0,0,0,0,0,0,0)),
    /* 10**38 */ Decimal(_length: 1, _isCompact: 1, _mantissa: (0x0003,0,0,0,0,0,0,0))
]
