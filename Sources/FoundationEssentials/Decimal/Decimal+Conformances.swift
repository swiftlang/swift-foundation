//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024-2026 Apple Inc. and the Swift project authors
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
    /// Creates and initializes a decimal by parsing a string according to the provided locale's conventions.
    ///
    /// - Parameters:
    ///   - string: A string containing a formatted decimal value.
    ///   - locale: A locale that indicates the formatting conventions used by `string`.
    public init?(string: __shared String, locale: __shared Locale? = nil) {
        let decimalSeparator = locale?.decimalSeparator ?? "."
        guard let (value, _, _) = try? Decimal.__decimal(
            from: string.utf8Span.span,
            prevalidatedUTF8: true,
            decimalSeparator: decimalSeparator.utf8Span,
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
    /// The decimal that contains the smallest possible non-infinite magnitude for the underlying representation.
    public static let leastFiniteMagnitude = Decimal(
        _exponent: 127,
        _length: 8,
        _isNegative: 1,
        _isCompact: 1,
        _reserved: 0,
        _mantissa: (0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff)
    )

    /// The decimal that contains the largest possible non-infinite magnitude for the underlying representation.
    public static let greatestFiniteMagnitude = Decimal(
        _exponent: 127,
        _length: 8,
        _isNegative: 0,
        _isCompact: 1,
        _reserved: 0,
        _mantissa: (0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff)
    )

    /// The decimal value that represents the smallest possible normal magnitude for the underlying representation.
    public static let leastNormalMagnitude = Decimal(
        _exponent: -127,
        _length: 1,
        _isNegative: 0,
        _isCompact: 1,
        _reserved: 0,
        _mantissa: (0x0001, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000)
    )

    /// The decimal value that represents the smallest possible non-zero value for the underlying representation.
    public static let leastNonzeroMagnitude = Decimal(
        _exponent: -127,
        _length: 1,
        _isNegative: 0,
        _isCompact: 1,
        _reserved: 0,
        _mantissa: (0x0001, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000)
    )

    /// The mathematical constant pi.
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

    /// A quiet representation of not-a-number.
    public static var quietNaN: Decimal {
        return Decimal(
            _exponent: 0, _length: 0, _isNegative: 1, _isCompact: 0,
            _reserved: 0, _mantissa: (0, 0, 0, 0, 0, 0, 0, 0))
    }

    /// The value that represents "not a number."
    public static var nan: Decimal { quietNaN }

    /// The radix used by decimal numbers.
    public static var radix: Int { 10 }

    /// Creates a new decimal floating-point value from the given unsigned integer value.
    ///
    /// - Parameter value: The integer to convert to a decimal floating-point value.
    @inlinable
    public init(_ value: UInt8) {
        self.init(UInt64(value))
    }

    /// Creates a new decimal floating-point value from the given signed integer value.
    ///
    /// - Parameter value: The integer to convert to a decimal floating-point value.
    @inlinable
    public init(_ value: Int8) {
        self.init(Int64(value))
    }

    /// Creates a new decimal floating-point value from the given unsigned integer value.
    ///
    /// - Parameter value: The integer to convert to a decimal floating-point value.
    @inlinable
    public init(_ value: UInt16) {
        self.init(UInt64(value))
    }

    /// Creates a new decimal floating-point value from the given signed integer value.
    ///
    /// - Parameter value: The integer to convert to a decimal floating-point value.
    @inlinable
    public init(_ value: Int16) {
        self.init(Int64(value))
    }

    /// Creates a new decimal floating-point value from the given unsigned integer value.
    ///
    /// - Parameter value: The integer to convert to a decimal floating-point value.
    @inlinable
    public init(_ value: UInt32) {
        self.init(UInt64(value))
    }

    /// Creates a new decimal floating-point value from the given signed integer value.
    ///
    /// - Parameter value: The integer to convert to a decimal floating-point value.
    @inlinable
    public init(_ value: Int32) {
        self.init(Int64(value))
    }

    /// Creates a new decimal floating-point value from the given unsigned integer value.
    ///
    /// - Parameter value: The integer to convert to a decimal floating-point value.
    public init(_ value: UInt64) {
        self = Decimal()
        if value == 0 { return }
        _significand = UInt128(truncatingIfNeeded: value)
        _exponent = 0
        _isCompact = 0
        compact()
    }

    /// Creates a new decimal floating-point value from the given signed integer value.
    ///
    /// - Parameter value: The integer to convert to a decimal floating-point value.
    public init(_ value: Int64) {
        self = .init(value.magnitude)
        if value < 0 {
            self._isNegative = 1
        }
    }

    /// Creates a new decimal floating-point value from the given unsigned integer value.
    ///
    /// - Parameter value: The integer to convert to a decimal floating-point value.
    public init(_ value: UInt) {
        self.init(UInt64(value))
    }

    /// Creates a new decimal floating-point value from the given signed integer value.
    ///
    /// - Parameter value: The integer to convert to a decimal floating-point value.
    public init(_ value: Int) {
        self.init(Int64(value))
    }

    /// Creates and initializes a decimal with the provided floating point value.
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

    /// Creates a decimal initialized with the given sign, exponent, and significand.
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
            self = try significand._multiplied(byPowerOfTen: exponent, rounding: .toNearestOrAwayFromZero)
        } catch _CalculationError.underflow {
            self = 0
            return
        } catch {
            self = .nan
            return
        }
        if sign == .minus {
            negate()
        }
    }

    /// Creates and initializes a decimal with the sign and magnitude of the given decimals.
    ///
    /// - Parameters:
    ///   - signOf: A `Decimal` to use for the sign of the newly-created `Decimal`.
    ///   - magnitude: A `Decimal` to use for the magnitude of the newly-created `Decimal`.
    public init(signOf: Decimal, magnitudeOf magnitude: Decimal) {
        self.init(
            _exponent: magnitude._exponent,
            _length: magnitude._length,
            _isNegative: signOf._isNegative,
            _isCompact: magnitude._isCompact,
            _reserved: 0,
            _mantissa: magnitude._mantissa)
    }

    /// The exponent of the decimal.
    public var exponent: Int {
        return Int(_exponent)
    }

    /// The significand of the decimal.
    public var significand: Decimal {
        let isCompact = _isCompact
        var result = Decimal(
            _exponent: 0, _length: _length, _isNegative: 0, _isCompact: isCompact,
            _reserved: 0, _mantissa: _mantissa)
        if isCompact != 0 && !result._isActuallyCompact { result._isCompact = 0 }
        return result
    }

    /// The sign of the decimal.
    public var sign: FloatingPointSign {
        return _isNegative == 0 ? FloatingPointSign.plus : FloatingPointSign.minus
    }

    /// The unit in the last place of the decimal.
    public var ulp: Decimal {
        guard isFinite else { return .nan }

        let exponent: Int32
        if isZero {
            exponent = .min
        } else {
            let m = _significand
            // Deliberately underestimate the max "headroom" for scaling up,
            // using 1233/4096 as a close approximation of 1/log2(10) -- cf. Hacker's Delight, ch. 11.
            var shift = ((m|1).leadingZeroBitCount &* 1233) &>> 12
            if m &* _uint128_pow10[shift] <= 34028236692093846346337460743176821145 /* UInt128.max / 10 */ {
                shift &+= 1
            }
            exponent = _exponent &- Int32(truncatingIfNeeded: shift)
        }

        return Decimal(
            _exponent: max(exponent, -128), _length: 1, _isNegative: 0, _isCompact: 1,
            _reserved: 0, _mantissa: (0x0001, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000))
    }

    /// The IEEE 754 class of this type.
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

    /// A Boolean value indicating whether the representation of this decimal is canonical.
    public var isCanonical: Bool { true }

    /// A Boolean value indicating whether this decimal has a negative sign.
    ///
    /// This property is `true` when the value is negative or `-0.0`; otherwise, `false`.
    public var isSignMinus: Bool { _isNegative != 0 }

    /// A Boolean value indicating whether this value is zero.
    ///
    /// This property is `true` for `-0.0` and `+0.0` and `false` for all other values.
    public var isZero: Bool { _length == 0 && _isNegative == 0 }

    /// A Boolean value indicating whether this decimal is subnormal.
    public var isSubnormal: Bool { false }

    /// A Boolean value indicating whether this decimal is normal (not zero, subnormal, infinity, or NaN).
    public var isNormal: Bool { !isZero && !isInfinite && !isNaN }

    /// A Boolean value indicating whether this decimal is zero, subnormal, or normal (not infinity or NaN).
    public var isFinite: Bool { !isNaN }

    /// A Boolean value indicating whether this decimal is infinity.
    public var isInfinite: Bool { false }

    /// A Boolean value indicating whether this decimal is NaN.
    public var isNaN: Bool { _length == 0 && _isNegative == 1 }

    /// A Boolean value indicating whether this decimal is a signaling NaN.
    public var isSignaling: Bool { false }

    /// A Boolean value indicating whether this decimal is a signaling NaN.
    public var isSignalingNaN: Bool { false }

    /// The least representable value that is greater than this decimal.
    public var nextUp: Decimal {
        if _isNegative == 1 {
            if _length != 0 && _exponent > -128 && _significand == 0x1999_9999_9999_9999_9999_9999_9999_999a {
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
            if _length != 0 && _significand == .max {
                guard _exponent < 127 else { return .nan }
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

    /// The greatest representable value that is less than this decimal.
    public var nextDown: Decimal {
        return -(-self).nextUp
    }

    /// Indicates whether this decimal is equal to the specified one.
    public func isEqual(to other: Decimal) -> Bool {
        return self == other
    }

    /// Indicates whether this decimal is less than the specified one.
    public func isLess(than other: Decimal) -> Bool {
        return Decimal._compare(lhs: self, rhs: other) == .orderedAscending
    }

    /// Indicates whether this decimal is less than or equal to the specified one.
    public func isLessThanOrEqualTo(_ other: Decimal) -> Bool {
        let order = Decimal._compare(lhs: self, rhs: other)
        return order == .orderedAscending || order == .orderedSame
    }

    /// Returns a Boolean value indicating whether this instance should precede the given value in an ascending sort.
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
    /// Creates and initializes a decimal with the provided floating point value.
    public init(floatLiteral value: Double) {
        self.init(value)
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Decimal : ExpressibleByIntegerLiteral {
    /// Creates and initializes a decimal with the provided integer value.
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
        var value = self
        if value._isCompact == 0 {
            value.compact()
        }
        hasher.combine(value._isNegative)
        if value._length != 0 {
            hasher.combine(value._exponent)
            hasher.combine(value._significand)
        }
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
            lhs._storage.bitFields == rhs._storage.bitFields &&
            lhs._storage.mantissa.0 == rhs._storage.mantissa.0 &&
            lhs._storage.mantissa.1 == rhs._storage.mantissa.1 &&
            lhs._storage.mantissa.2 == rhs._storage.mantissa.2 &&
            lhs._storage.mantissa.3 == rhs._storage.mantissa.3 &&
            lhs._storage.mantissa.4 == rhs._storage.mantissa.4 &&
            lhs._storage.mantissa.5 == rhs._storage.mantissa.5 &&
            lhs._storage.mantissa.6 == rhs._storage.mantissa.6 &&
            lhs._storage.mantissa.7 == rhs._storage.mantissa.7
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
        // _length takes only 4 bits even though it is encoded as CUnsignedInt
        guard length <= Decimal.maxSize else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "length field exceeds max value 8"
                )
            )
        }
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
        // Validate compactness.
        if isCompact && !self._isActuallyCompact { self._isCompact = 0 }
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
    /// The magnitude of this decimal.
    public var magnitude: Decimal {
        guard _length != 0 else { return self }
        return Decimal(
            _exponent: self._exponent, _length: self._length,
            _isNegative: 0, _isCompact: self._isCompact,
            _reserved: 0, _mantissa: self._mantissa)
    }

    /// Creates a new decimal value exactly representing the provided integer.
    ///
    /// If `source` isn't representable as a `Decimal` instance, the result is `nil`.
    ///
    /// - Parameter source: The integer to convert.
    public init?<T : BinaryInteger>(exactly source: T) {
        let zero = 0 as T

        if source == zero {
            self = Decimal.zero
            return
        }

        let negative: UInt32 = (T.isSigned && source < zero) ? 1 : 0
        var mantissa = source.magnitude
        var exponent: Int32 = 0

        if mantissa <= UInt128.max {
            self = Decimal()
            self._significand = UInt128(truncatingIfNeeded: mantissa)
            self._exponent = exponent
            self._isCompact = 0
            self.compact()
            self._isNegative = negative
            return
        }

        let maxExponent = Int8.max
        while mantissa.isMultiple(of: 10) && (exponent < maxExponent) {
            exponent += 1
            mantissa /= 10
        }
        // If the mantissa still requires more than 128 bits of storage then it is too large.
        if mantissa > UInt128.max { return nil }
        self = Decimal()
        self._significand = UInt128(truncatingIfNeeded: mantissa)
        self._exponent = exponent
        self._isCompact = 1
        self._isNegative = negative
    }

#if FOUNDATION_FRAMEWORK
    @usableFromInline internal static var __zeroForABI: Decimal {
        @_silgen_name("$sSo9NSDecimala10FoundationE4zeroABvgZ")
        get {
            return Decimal(0)
        }
    }
#endif

    /// Adds two decimal numbers, storing the result in the first number.
    ///
    /// If the result of this operation requires more precision than the `Decimal`
    /// type can provide, the result is rounded using the
    /// ``Decimal/RoundingMode/plain`` rounding mode.
    ///
    /// - Parameters:
    ///   - lhs: A value to add.
    ///   - rhs: Another value to add.
    public static func +=(lhs: inout Decimal, rhs: Decimal) {
        do {
            let result = try lhs._adding(rhs, rounding: .toNearestOrAwayFromZero)
            lhs = result
        } catch {
            lhs = .nan
        }
    }

    /// Subtracts one decimal number from another, storing the result in the first number.
    ///
    /// If the result of this operation requires more precision than the `Decimal`
    /// type can provide, the result is rounded using the
    /// ``Decimal/RoundingMode/plain`` rounding mode.
    ///
    /// - Parameters:
    ///   - lhs: The value to subtract from.
    ///   - rhs: The value to subtract.
    public static func -=(lhs: inout Decimal, rhs: Decimal) {
        do {
            let result = try lhs._subtracting(rhs, rounding: .toNearestOrAwayFromZero)
            lhs = result
        } catch {
            lhs = .nan
        }
    }

    /// Multiplies two decimal numbers, storing the result in the first number.
    ///
    /// If the result of this operation requires more precision than the `Decimal`
    /// type can provide, the result is rounded using the
    /// ``Decimal/RoundingMode/plain`` rounding mode.
    ///
    /// - Parameters:
    ///   - lhs: A value to multiply.
    ///   - rhs: Another value to multiply.
    public static func *=(lhs: inout Decimal, rhs: Decimal) {
        do {
            let result = try lhs._multiplied(by: rhs, rounding: .toNearestOrAwayFromZero)
            lhs = result
        } catch _CalculationError.underflow {
            lhs = .zero
        } catch {
            lhs = .nan
        }
    }

    /// Divides one decimal number by another, storing the result in the first number.
    ///
    /// If the result of this operation requires more precision than the `Decimal`
    /// type can provide, the result is rounded using the
    /// ``Decimal/RoundingMode/plain`` rounding mode.
    ///
    /// - Parameters:
    ///   - lhs: The value to divide.
    ///   - rhs: The value to divide `lhs` by.
    public static func /=(lhs: inout Decimal, rhs: Decimal) {
        do {
            let result = try lhs._divided(by: rhs, rounding: .toNearestOrAwayFromZero)
            lhs = result
        } catch _CalculationError.underflow {
            lhs = .zero
        } catch {
            lhs = .nan
        }
    }

    /// Adds two decimal numbers.
    ///
    /// If the result of this operation requires more precision than the `Decimal`
    /// type can provide, the result is rounded using the
    /// ``Decimal/RoundingMode/plain`` rounding mode.
    ///
    /// - Parameters:
    ///   - lhs: A value to add.
    ///   - rhs: Another value to add.
    /// - Returns: The result of adding `lhs` and `rhs`.
    public static func +(lhs: Decimal, rhs: Decimal) -> Decimal {
        var answer = lhs
        answer += rhs
        return answer
    }

    /// Subtracts one decimal number from another.
    ///
    /// If the result of this operation requires more precision than the `Decimal`
    /// type can provide, the result is rounded using the
    /// ``Decimal/RoundingMode/plain`` rounding mode.
    ///
    /// - Parameters:
    ///   - lhs: The value to subtract from.
    ///   - rhs: The value to subtract.
    /// - Returns: The result of subtracting `rhs` from `lhs`.
    public static func -(lhs: Decimal, rhs: Decimal) -> Decimal {
        var answer = lhs
        answer -= rhs
        return answer
    }

    /// Multiplies two decimal numbers.
    ///
    /// If the result of this operation requires more precision than the `Decimal`
    /// type can provide, the result is rounded using the
    /// ``Decimal/RoundingMode/plain`` rounding mode.
    ///
    /// - Parameters:
    ///   - lhs: A value to multiply.
    ///   - rhs: Another value to multiply.
    /// - Returns: The result of multiplying `lhs` by `rhs`.
    public static func *(lhs: Decimal, rhs: Decimal) -> Decimal {
        var answer = lhs
        answer *= rhs
        return answer
    }

    /// Divides one decimal number by another.
    ///
    /// If the result of this operation requires more precision than the `Decimal`
    /// type can provide, the result is rounded using the
    /// ``Decimal/RoundingMode/plain`` rounding mode. 
    ///
    /// - Parameters:
    ///   - lhs: The value to divide.
    ///   - rhs: The value to divide `lhs` by.
    /// - Returns: The result of dividing `lhs` by `rhs`.
    public static func /(lhs: Decimal, rhs: Decimal) -> Decimal {
        var answer = lhs
        answer /= rhs
        return answer
    }

    /// Negates this decimal.
    public mutating func negate() {
        guard self._length != 0 else { return }
        self._isNegative = self._isNegative == 0 ? 1 : 0
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Decimal : Strideable {
    /// Returns the distance from this value to the specified value.
    public func distance(to other: Decimal) -> Decimal {
        return other - self
    }

    /// Returns a new value advanced by the given distance.
    public func advanced(by n: Decimal) -> Decimal {
        return self + n
    }
}

// MARK: - APIs inspired by FloatingPoint

@available(FoundationPreview 6.5, *)
extension Decimal {
    /// Creates a new decimal floating-point value from the given unsigned integer value.
    ///
    /// - Parameter value: The integer to convert to a decimal floating-point value.
    public init(_ value: UInt128) {
        self = Decimal()
        if value == 0 { return }
        _significand = value
        _exponent = 0
        _isCompact = 0
        compact()
    }

    /// Creates a new decimal floating-point value from the given signed integer value.
    ///
    /// - Parameter value: The integer to convert to a decimal floating-point value.
    public init(_ value: Int128) {
        self = .init(value.magnitude)
        if value < 0 {
            self._isNegative = 1
        }
    }
}

@available(FoundationPreview 6.5, *)
extension Decimal {
    /// Adds the product of the two given values to this value in place,
    /// computed without intermediate rounding.
    ///
    /// - Parameters:
    ///   - lhs: One of the values to multiply before adding to this value.
    ///   - rhs: The other value to multiply.
    @inlinable
    public mutating func addProduct(_ lhs: Decimal, _ rhs: Decimal) {
        self = self.addingProduct(lhs, rhs)
    }

    /// Returns the result of adding the product of the two given values to this value,
    /// computed without intermediate rounding.
    ///
    /// This method is the fused multiply-add operation.
    ///
    /// - Parameters:
    ///   - lhs: One of the values to multiply before adding to this value.
    ///   - rhs: The other value to multiply.
    /// - Returns: The product of `lhs` and `rhs`, added to this value.
    public func addingProduct(_ lhs: Decimal, _ rhs: Decimal) -> Decimal {
        do {
            return try self._addingProductReportingInexact(
                lhs,
                rhs,
                rounding: .toNearestOrEven
            ).value
        } catch _CalculationError.underflow {
            return .zero
        } catch {
            return .nan
        }
    }

    /// Replaces this value with the remainder of itself divided by the given value.
    ///
    /// For two finite values `x` and `y`,
    /// the remainder of dividing `x` by `y` satisfies `x == y * q + r`,
    /// where `q` is the integer nearest to `x / y`.
    /// If `x / y` is exactly halfway between two integers, `q` is chosen to be even.
    /// Note that `q` is *not* `x / y` computed in floating-point arithmetic,
    /// and that `q` may not be representable in any available integer type.
    ///
    /// If this value and `other` are both finite numbers,
    /// the remainder is in the closed range `-abs(other / 2)...abs(other / 2)`.
    /// This method is always exact.
    ///
    /// - Parameter other: The value to use when dividing this value.
    @inlinable
    public mutating func formRemainder(dividingBy other: Decimal) {
        self = self.remainder(dividingBy: other)
    }

    /// Replaces this value with its square root, rounded to a representable value.
    @inlinable
    public mutating func formSquareRoot() {
        self = self.squareRoot()
    }

    /// Replaces this value with the remainder of itself divided by the given value
    /// using truncating division.
    ///
    /// Performing truncating division with floating-point values results in a truncated integer quotient and a remainder.
    /// For values `x` and `y` and their truncated integer quotient `q`,
    /// the remainder `r` satisfies `x == y * q + r`.
    ///
    /// If this value and `other` are both finite numbers,
    /// the truncating remainder has the same sign as this value if nonzero and is strictly smaller in magnitude than `other`.
    /// This method is always exact.
    ///
    /// - Parameter other: The value to use when dividing this value.
    @inlinable
    public mutating func formTruncatingRemainder(dividingBy other: Decimal) {
        self = self.truncatingRemainder(dividingBy: other)
    }

#if false
    /// Returns the value with greater magnitude.
    ///
    /// This method returns the value with greater magnitude of the two given values,
    /// preserving order and eliminating NaN when possible.
    /// For two values `x` and `y`, the result of `maximumMagnitudeNumber(x, y)` is:
    /// `x` if `x.magnitude > y.magnitude`, `y` if `x.magnitude < y.magnitude`,
    /// or whichever of `x` or `y` is a number if the other is NaN.
    /// If both `x` and `y` are NaN, the result is NaN.
    /// If `x` and `y` are of equal magnitude, the result is the same as that of `maximumNumber(x, y)`.
    ///
    /// - Parameters:
    ///   - x: A decimal floating-point value to compare.
    ///   - y: Another decimal floating-point value to compare.
    /// - Returns: Whichever of `x` or `y` has greater magnitude, or whichever is a number if the other is NaN.
    @inlinable
    public static func maximumMagnitudeNumber(
        _ x: Decimal,
        _ y: Decimal
    ) -> Decimal {
        if x.isNaN && y.isNaN { return x }
        if x.isNaN { return y }
        if y.isNaN { return x }
        let abs = (x: abs(x), y: abs(y))
        if abs.x > abs.y { return x }
        if abs.y > abs.x { return y }
        // Tiebreaker: return the greater value.
        return x > y ? x : y
    }

    /// Returns the greater of the two given values.
    ///
    /// This method returns the maximum of two values,
    /// preserving order and eliminating NaN when possible.
    /// For two values `x` and `y`, the result of `maximumNumber(x, y)` is:
    /// `x` if `x > y`, `y` if `x < y`, or whichever of `x` or `y` is a number if the other is NaN.
    /// If both `x` and `y` are NaN, the result is NaN.
    ///
    /// - Parameters:
    ///   - x: A decimal floating-point value to compare.
    ///   - y: Another decimal floating-point value to compare.
    /// - Returns: The greater of `x` and `y`, or whichever is a number if the other is NaN.
    @inlinable
    public static func maximumNumber(_ x: Decimal, _ y: Decimal) -> Decimal {
        if x.isNaN && y.isNaN { return x }
        if x.isNaN { return y }
        if y.isNaN { return x }
        return x > y ? x : y
    }

    /// Returns the value with the lesser magnitude.
    ///
    /// This method returns the value with lesser magnitude of the two given values,
    /// preserving order and eliminating NaN when possible.
    /// For two values `x` and `y`, the result of `minimumMagnitudeNumber(x, y)` is:
    /// `x` if `x.magnitude < y.magnitude`, `y` if `y.magnitude < x.magnitude`,
    /// or whichever of `x` or `y` is a number if the other is NaN.
    /// If both `x` and `y` are NaN, the result is NaN.
    /// If `x` and `y` are of equal magnitude, the result is the same as that of `minimumNumber(x, y)`.
    ///
    /// - Parameters:
    ///   - x: A decimal floating-point value to compare.
    ///   - y: Another decimal floating-point value to compare.
    /// - Returns: Whichever of `x` or `y` has lesser magnitude, or whichever is a number if the other is NaN.
    @inlinable
    public static func minimumMagnitudeNumber(
        _ x: Decimal,
        _ y: Decimal
    ) -> Decimal {
        if x.isNaN && y.isNaN { return x }
        if x.isNaN { return y }
        if y.isNaN { return x }
        let abs = (x: abs(x), y: abs(y))
        if abs.x < abs.y { return x }
        if abs.y < abs.x { return y }
        // Tiebreaker: return the lesser value.
        return x < y ? x : y
    }

    /// Returns the lesser of the two given values.
    ///
    /// This method returns the minimum of two values,
    /// preserving order and eliminating NaN when possible.
    /// For two values `x` and `y`, the result of `minimumNumber(x, y)` is:
    /// `x` if `x < y`, `y` if `y < x`, or whichever of `x` or `y` is a number if the other is NaN.
    /// If both `x` and `y` are NaN, the result is NaN.
    ///
    /// - Parameters:
    ///   - x: A decimal floating-point value to compare.
    ///   - y: Another decimal floating-point value to compare.
    /// - Returns: The lesser of `x` and `y`, or whichever is a number if the other is NaN.
    @inlinable
    public static func minimumNumber(_ x: Decimal, _ y: Decimal) -> Decimal {
        if x.isNaN && y.isNaN { return x }
        if x.isNaN { return y }
        if y.isNaN { return x }
        return x < y ? x : y
    }
#endif

    /// Returns the remainder of this value divided by the given value.
    ///
    /// For two finite values `x` and `y`,
    /// the remainder of dividing `x` by `y` satisfies `x == y * q + r`,
    /// where `q` is the integer nearest to `x / y`.
    /// If `x / y` is exactly halfway between two integers, `q` is chosen to be even.
    /// Note that `q` is *not* `x / y` computed in floating-point arithmetic,
    /// and that `q` may not be representable in any available integer type.
    ///
    /// If this value and `other` are both finite numbers,
    /// the remainder is in the closed range `-abs(other / 2)...abs(other / 2)`.
    /// This method is always exact.
    ///
    /// - Parameter other: The value to use when dividing this value.
    /// - Returns: The remainder of this value divided by `other`.
    public func remainder(dividingBy other: Decimal) -> Decimal {
        do {
            return try self._remainder(truncating: false, dividingBy: other)
        } catch {
            return .nan
        }
    }

    /// Rounds the value to an integral value using the specified rounding rule.
    ///
    /// For more information about the available rounding rules,
    /// see the `FloatingPointRoundingRule` type.
    ///
    /// - Parameter rule: The rounding rule to use.
    @inlinable
    public mutating func round(
        _ rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero
    ) {
        self = self.rounded(rule)
    }

    /// Returns this value rounded to an integral value using the specified rounding rule.
    ///
    /// For more information about the available rounding rules,
    /// see the `FloatingPointRoundingRule` type.
    ///
    /// - Parameter rule: The rounding rule to use.
    /// - Returns: The integral value found by rounding using `rule`.
    public func rounded(
        _ rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero
    ) -> Decimal {
        do {
            return try self._rounded(rule, minExponent: 0)
        } catch _CalculationError.underflow {
            return .zero
        } catch {
            return .nan
        }
    }

    /// Returns the square root of the value, rounded to a representable value.
    ///
    /// - Returns: The square root of the value.
    public func squareRoot() -> Decimal {
        do {
            return try self._squareRootReportingInexact(rounding: .toNearestOrEven).value
        } catch _CalculationError.underflow {
            return .zero
        } catch {
            return .nan
        }
    }

    /// Returns the remainder of this value divided by the given value using truncating division.
    ///
    /// Performing truncating division with floating-point values results in a truncated integer quotient and a remainder.
    /// For values `x` and `y` and their truncated integer quotient `q`,
    /// the remainder `r` satisfies `x == y * q + r`.
    ///
    /// If this value and `other` are both finite numbers,
    /// the truncating remainder has the same sign as this value if nonzero and is strictly smaller in magnitude than `other`.
    /// This method is always exact.
    ///
    /// - Parameter other: The value to use when dividing this value.
    /// - Returns: The remainder of this value divided by `other` using truncating division.
    public func truncatingRemainder(dividingBy other: Decimal) -> Decimal {
        do {
            return try self._remainder(truncating: true, dividingBy: other)
        } catch {
            return .nan
        }
    }
}

@inline(always)
private func _boundedMinExponent(scale: Int) -> Int32 {
    precondition(scale >= -165, "Scale must not be less than -165")
    return -Int32(min(scale, -Int(Decimal._minExponent)))
}

@available(FoundationPreview 6.5, *)
extension Decimal {
    /// Adds the given value to this value in place.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// - Parameters:
    ///   - other: The value to add to this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    @inlinable
    public mutating func add(
        _ other: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) {
        self = self.adding(other, rounding: rule, scale: scale)
    }

    /// Adds the given value to this value in place, reporting whether the result is inexact.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// If either operand is NaN, the result is NaN and this method returns `false`.
    /// If the result overflows to NaN or underflows to zero, this method returns `true`.
    ///
    /// - Parameters:
    ///   - other: The value to add to this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: `true` if rounding changed the exact result or if the result overflowed or underflowed; otherwise, `false`.
    @inlinable
    public mutating func addReportingInexact(
        _ other: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> Bool {
        let addition = self.addingReportingInexact(
            other,
            rounding: rule,
            scale: scale
        )
        self = addition.value
        return addition.inexact
    }

    /// Returns the sum of this value and the given value.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// - Parameters:
    ///   - other: The value to add to this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: The sum of this value and `other`, rounded as specified.
    public func adding(
        _ other: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> Decimal {
        do throws(_CalculationError) {
            return try self._adding(
                other,
                rounding: rule,
                minExponent: _boundedMinExponent(scale: scale)
            )
        } catch .overflow {
            return .nan
        } catch .underflow {
            return .zero
        } catch {
            fatalError("Unexpected calculation error")
        }
    }

    /// Returns the sum of this value and the given value, along with a Boolean value indicating whether the result is inexact.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// If either operand is NaN, the result is NaN and `inexact` is `false`.
    /// If the result overflows to NaN or underflows to zero, `inexact` is `true`.
    ///
    /// - Parameters:
    ///   - other: The value to add to this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: A tuple containing the sum of this value and `other`, rounded as specified,
    ///   and a Boolean value indicating whether rounding changed the exact result or the result overflowed or underflowed.
    public func addingReportingInexact(
        _ other: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> (value: Decimal, inexact: Bool) {
        if self.isNaN || other.isNaN {
            return (.nan, false)
        }
        do throws(_CalculationError) {
            return try self._addingReportingInexact(
                other,
                rounding: rule,
                minExponent: _boundedMinExponent(scale: scale)
            )
        } catch .overflow {
            return (.nan, true)
        } catch .underflow {
            return (.zero, true)
        } catch {
            fatalError("Unexpected calculation error")
        }
    }

    /// Subtracts the given value from this value in place.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// - Parameters:
    ///   - other: The value to subtract from this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    @inlinable
    public mutating func subtract(
        _ other: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) {
        self = self.subtracting(
            other,
            rounding: rule,
            scale: scale
        )
    }

    /// Subtracts the given value from this value in place, reporting whether the result is inexact.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// If either operand is NaN, the result is NaN and this method returns `false`.
    /// If the result overflows to NaN or underflows to zero, this method returns `true`.
    ///
    /// - Parameters:
    ///   - other: The value to subtract from this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: `true` if rounding changed the exact result or if the result overflowed or underflowed; otherwise, `false`.
    @inlinable
    public mutating func subtractReportingInexact(
        _ other: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> Bool {
        let subtraction = self.subtractingReportingInexact(
            other,
            rounding: rule,
            scale: scale
        )
        self = subtraction.value
        return subtraction.inexact
    }

    /// Returns the difference obtained by subtracting the given value from this value.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// - Parameters:
    ///   - other: The value to subtract from this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: The difference of this value and `other`, rounded as specified.
    public func subtracting(
        _ other: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> Decimal {
        do throws(_CalculationError) {
            return try self._subtracting(
                other,
                rounding: rule,
                minExponent: _boundedMinExponent(scale: scale)
            )
        } catch .overflow {
            return .nan
        } catch .underflow {
            return .zero
        } catch {
            fatalError("Unexpected calculation error")
        }
    }

    /// Returns the difference obtained by subtracting the given value from this value,
    /// along with a Boolean value indicating whether the result is inexact.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// If either operand is NaN, the result is NaN and `inexact` is `false`.
    /// If the result overflows to NaN or underflows to zero, `inexact` is `true`.
    ///
    /// - Parameters:
    ///   - other: The value to subtract from this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: A tuple containing the difference of this value and `other`, rounded as specified,
    ///   and a Boolean value indicating whether rounding changed the exact result or the result overflowed or underflowed.
    public func subtractingReportingInexact(
        _ other: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> (value: Decimal, inexact: Bool) {
        if self.isNaN || other.isNaN {
            return (.nan, false)
        }
        do throws(_CalculationError) {
            return try self._subtractingReportingInexact(
                other,
                rounding: rule,
                minExponent: _boundedMinExponent(scale: scale)
            )
        } catch .overflow {
            return (.nan, true)
        } catch .underflow {
            return (.zero, true)
        } catch {
            fatalError("Unexpected calculation error")
        }
    }

    /// Multiplies this value by the given value in place.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// - Parameters:
    ///   - other: The value to multiply by this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    @inlinable
    public mutating func multiply(
        by other: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) {
        self = self.multiplied(
            by: other,
            rounding: rule,
            scale: scale
        )
    }

    /// Multiplies this value by the given value in place, reporting whether the result is inexact.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// If either operand is NaN, the result is NaN and this method returns `false`.
    /// If the result overflows to NaN or underflows to zero, this method returns `true`.
    ///
    /// - Parameters:
    ///   - other: The value to multiply by this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: `true` if rounding changed the exact result or if the result overflowed or underflowed; otherwise, `false`.
    @inlinable
    public mutating func multiplyReportingInexact(
        by other: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> Bool {
        let multiplication = self.multipliedReportingInexact(
            by: other,
            rounding: rule,
            scale: scale
        )
        self = multiplication.value
        return multiplication.inexact
    }

    /// Returns the product of this value and the given value.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// - Parameters:
    ///   - other: The value to multiply by this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: The product of this value and `other`, rounded as specified.
    public func multiplied(
        by other: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> Decimal {
        do throws(_CalculationError) {
            return try self._multiplied(
                by: other,
                rounding: rule,
                minExponent: _boundedMinExponent(scale: scale)
            )
        } catch .overflow {
            return .nan
        } catch .underflow {
            return .zero
        } catch {
            fatalError("Unexpected calculation error")
        }
    }

    /// Returns the product of this value and the given value,
    /// along with a Boolean value indicating whether the result is inexact.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// If either operand is NaN, the result is NaN and `inexact` is `false`.
    /// If the result overflows to NaN or underflows to zero, `inexact` is `true`.
    ///
    /// - Parameters:
    ///   - other: The value to multiply by this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: A tuple containing the product of this value and `other`, rounded as specified,
    ///   and a Boolean value indicating whether rounding changed the exact result or the result overflowed or underflowed.
    public func multipliedReportingInexact(
        by other: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> (value: Decimal, inexact: Bool) {
        if self.isNaN || other.isNaN {
            return (.nan, false)
        }
        do throws(_CalculationError) {
            return try self._multipliedReportingInexact(
                by: other,
                rounding: rule,
                minExponent: _boundedMinExponent(scale: scale)
            )
        } catch .overflow {
            return (.nan, true)
        } catch .underflow {
            return (.zero, true)
        } catch {
            fatalError("Unexpected calculation error")
        }
    }

    /// Multiplies this value by the given power of ten in place.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// - Parameters:
    ///   - power: The power of ten by which to multiply this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    @inlinable
    public mutating func multiply(
        byPowerOfTen power: Int,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) {
        self = self.multiplied(
            byPowerOfTen: power,
            rounding: rule,
            scale: scale
        )
    }

    /// Multiplies this value by the given power of ten in place, reporting whether the result is inexact.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// If this value is NaN, the result is NaN and this method returns `false`.
    /// If the result overflows to NaN or underflows to zero, this method returns `true`.
    ///
    /// - Parameters:
    ///   - power: The power of ten by which to multiply this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: `true` if rounding changed the exact result or if the result overflowed or underflowed; otherwise, `false`.
    @inlinable
    public mutating func multiplyReportingInexact(
        byPowerOfTen power: Int,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> Bool {
        let multiplication = self.multipliedReportingInexact(
            byPowerOfTen: power,
            rounding: rule,
            scale: scale
        )
        self = multiplication.value
        return multiplication.inexact
    }

    /// Returns this value multiplied by the given power of ten.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// - Parameters:
    ///   - power: The power of ten by which to multiply this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: The result of this value multiplied by ten raised to `power`, rounded as specified.
    public func multiplied(
        byPowerOfTen power: Int,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> Decimal {
        do throws(_CalculationError) {
            return try self._multiplied(
                byPowerOfTen: power,
                rounding: rule,
                minExponent: _boundedMinExponent(scale: scale)
            )
        } catch .overflow {
            return .nan
        } catch .underflow {
            return .zero
        } catch {
            fatalError("Unexpected calculation error")
        }
    }

    /// Returns this value multiplied by the given power of ten,
    /// along with a Boolean value indicating whether the result is inexact.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// If this value is NaN, the result is NaN and `inexact` is `false`.
    /// If the result overflows to NaN or underflows to zero, `inexact` is `true`.
    ///
    /// - Parameters:
    ///   - power: The power of ten by which to multiply this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: A tuple containing the result of this value multiplied by ten raised to `power`, rounded as specified,
    ///   and a Boolean value indicating whether rounding changed the exact result or the result overflowed or underflowed.
    public func multipliedReportingInexact(
        byPowerOfTen power: Int,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> (value: Decimal, inexact: Bool) {
        if self.isNaN {
            return (.nan, false)
        }
        do throws(_CalculationError) {
            return try self._multipliedReportingInexact(
                byPowerOfTen: power,
                rounding: rule,
                minExponent: _boundedMinExponent(scale: scale)
            )
        } catch .overflow {
            return (.nan, true)
        } catch .underflow {
            return (.zero, true)
        } catch {
            fatalError("Unexpected calculation error")
        }
    }

    /// Divides this value by the given value in place.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// - Parameters:
    ///   - other: The value by which to divide this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    @inlinable
    public mutating func divide(
        by other: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) {
        self = self.divided(by: other, rounding: rule, scale: scale)
    }

    /// Divides this value by the given value in place, reporting whether the result is inexact.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// If either operand is NaN or if `other` is zero, the result is NaN and this method returns `false`.
    /// If the result overflows to NaN or underflows to zero, this method returns `true`.
    ///
    /// - Parameters:
    ///   - other: The value by which to divide this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: `true` if rounding changed the exact result or if the result overflowed or underflowed; otherwise, `false`.
    @inlinable
    public mutating func divideReportingInexact(
        by other: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> Bool {
        let division = self.dividedReportingInexact(
            by: other,
            rounding: rule,
            scale: scale
        )
        self = division.value
        return division.inexact
    }

    /// Returns the quotient obtained by dividing this value by the given value.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// - Parameters:
    ///   - other: The value by which to divide this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: The quotient of this value and `other`, rounded as specified.
    public func divided(
        by other: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> Decimal {
        do throws(_CalculationError) {
            return try self._divided(
                by: other,
                rounding: rule,
                minExponent: _boundedMinExponent(scale: scale)
            )
        } catch .overflow {
            return .nan
        } catch .underflow {
            return .zero
        } catch /* divideByZero */ {
            // Work around a compiler bug that both requires a catch-all
            // and warns it'll never be executed.
            precondition(error == .divideByZero)
            return .nan
        }
    }

    /// Returns the quotient obtained by dividing this value by the given value,
    /// along with a Boolean value indicating whether the result is inexact.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// If either operand is NaN or if `other` is zero, the result is NaN and `inexact` is `false`.
    /// If the result overflows to NaN or underflows to zero, `inexact` is `true`.
    ///
    /// - Parameters:
    ///   - other: The value by which to divide this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: A tuple containing the quotient of this value and `other`, rounded as specified,
    ///   and a Boolean value indicating whether rounding changed the exact result or the result overflowed or underflowed.
    public func dividedReportingInexact(
        by other: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> (value: Decimal, inexact: Bool) {
        if self.isNaN || other.isNaN {
            return (.nan, false)
        }
        do throws(_CalculationError) {
            return try self._dividedReportingInexact(
                by: other,
                rounding: rule,
                minExponent: _boundedMinExponent(scale: scale)
            )
        } catch .overflow {
            return (.nan, true)
        } catch .underflow {
            return (.zero, true)
        } catch /* .divideByZero */ {
            // Work around a compiler bug that both requires a catch-all
            // and warns it'll never be executed.
            precondition(error == .divideByZero)
            return (.nan, false)
        }
    }

    /// Adds the product of the two given values to this value in place,
    /// computed without intermediate rounding.
    ///
    /// This method is the fused multiply-add operation.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// - Parameters:
    ///   - lhs: One of the values to multiply before adding to this value.
    ///   - rhs: The other value to multiply.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    @inlinable
    public mutating func addProduct(
        _ lhs: Decimal,
        _ rhs: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) {
        self = self.addingProduct(
            lhs,
            rhs,
            rounding: rule,
            scale: scale
        )
    }

    /// Adds the product of the two given values to this value in place,
    /// computed without intermediate rounding, reporting whether the result is inexact.
    ///
    /// This method is the fused multiply-add operation.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// If any operand is NaN, the result is NaN and this method returns `false`.
    /// If the result overflows to NaN or underflows to zero, this method returns `true`.
    ///
    /// - Parameters:
    ///   - lhs: One of the values to multiply before adding to this value.
    ///   - rhs: The other value to multiply.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: `true` if rounding changed the exact result or if the result overflowed or underflowed; otherwise, `false`.
    @inlinable
    public mutating func addProductReportingInexact(
        _ lhs: Decimal,
        _ rhs: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> Bool {
        let addition = self.addingProductReportingInexact(
            lhs,
            rhs,
            rounding: rule,
            scale: scale
        )
        self = addition.value
        return addition.inexact
    }

    /// Returns the result of adding the product of the two given values to this value,
    /// computed without intermediate rounding.
    ///
    /// This method is the fused multiply-add operation.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// - Parameters:
    ///   - lhs: One of the values to multiply before adding to this value.
    ///   - rhs: The other value to multiply.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: The product of `lhs` and `rhs`, added to this value, rounded as specified.
    public func addingProduct(
        _ lhs: Decimal,
        _ rhs: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> Decimal {
        do throws(_CalculationError) {
            return try self._addingProductReportingInexact(
                lhs,
                rhs,
                rounding: rule,
                minExponent: _boundedMinExponent(scale: scale)
            ).value
        } catch .overflow {
            return .nan
        } catch .underflow {
            return .zero
        } catch {
            fatalError("Unexpected calculation error")
        }
    }

    /// Returns the result of adding the product of the two given values to this value,
    /// computed without intermediate rounding, along with a Boolean value indicating whether the result is inexact.
    ///
    /// This method is the fused multiply-add operation.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// If any operand is NaN, the result is NaN and `inexact` is `false`.
    /// If the result overflows to NaN or underflows to zero, `inexact` is `true`.
    ///
    /// - Parameters:
    ///   - lhs: One of the values to multiply before adding to this value.
    ///   - rhs: The other value to multiply.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: A tuple containing the product of `lhs` and `rhs`, added to this value, rounded as specified,
    ///   and a Boolean value indicating whether rounding changed the exact result or the result overflowed or underflowed.
    public func addingProductReportingInexact(
        _ lhs: Decimal,
        _ rhs: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> (value: Decimal, inexact: Bool) {
        if self.isNaN || lhs.isNaN || rhs.isNaN {
            return (.nan, false)
        }
        do throws(_CalculationError) {
            return try self._addingProductReportingInexact(
                lhs,
                rhs,
                rounding: rule,
                minExponent: _boundedMinExponent(scale: scale)
            )
        } catch .overflow {
            return (.nan, true)
        } catch .underflow {
            return (.zero, true)
        } catch {
            fatalError("Unexpected calculation error")
        }
    }

    /// Replaces this value with its square root.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// - Parameters:
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    @inlinable
    public mutating func formSquareRoot(
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) {
        self = self.squareRoot(rounding: rule, scale: scale)
    }

    /// Replaces this value with its square root, reporting whether the result is inexact.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// If this value is NaN or negative, the result is NaN and this method returns `false`.
    ///
    /// - Parameters:
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: `true` if rounding changed the exact result; otherwise, `false`.
    @inlinable
    public mutating func formSquareRootReportingInexact(
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> Bool {
        let root = self.squareRootReportingInexact(
            rounding: rule,
            scale: scale
        )
        self = root.value
        return root.inexact
    }

    /// Rounds this value in place using the specified rounding rule and scale.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// - Parameters:
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    @inlinable
    public mutating func round(
        _ rule: FloatingPointRoundingRule,
        scale: Int
    ) {
        self = self.rounded(rule, scale: scale)
    }

    /// Returns this value rounded using the specified rounding rule and scale.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// - Parameters:
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: The value found by rounding using `rule` and `scale`.
    public func rounded(
        _ rule: FloatingPointRoundingRule,
        scale: Int
    ) -> Decimal {
        do throws(_CalculationError) {
            return try self._roundedReportingInexact(
                rule,
                minExponent: _boundedMinExponent(scale: scale)
            ).value
        } catch .overflow {
            return .nan
        } catch .underflow {
            return .zero
        } catch {
            fatalError("Unexpected calculation error")
        }
    }

    /// Returns the square root of this value.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// - Parameters:
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: The square root of this value, rounded as specified.
    public func squareRoot(
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> Decimal {
        do throws(_CalculationError) {
            return try self._squareRootReportingInexact(
                rounding: rule,
                minExponent: _boundedMinExponent(scale: scale)
            ).value
        } catch .overflow {
            return .nan
        } catch .underflow {
            return .zero
        } catch {
            fatalError("Unexpected calculation error")
        }
    }

    /// Returns the square root of this value, along with a Boolean value indicating whether the result is inexact.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// If this value is NaN or less than zero, the result is NaN and `inexact` is `false`.
    ///
    /// - Parameters:
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: A tuple containing the square root of this value, rounded as specified,
    ///   and a Boolean value indicating whether rounding changed the exact result.
    public func squareRootReportingInexact(
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> (value: Decimal, inexact: Bool) {
        if self.isNaN || self < .zero {
            return (.nan, false)
        }
        do throws(_CalculationError) {
            return try self._squareRootReportingInexact(
                rounding: rule,
                minExponent: _boundedMinExponent(scale: scale)
            )
        } catch .overflow {
            return (.nan, true)
        } catch .underflow {
            return (.zero, true)
        } catch {
            fatalError("Unexpected calculation error")
        }
    }
}
