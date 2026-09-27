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

// The methods in this extension originally existed to match the protocol requirements of `FloatingPoint`, even if we can't conform directly.
// Semantics that differ from those of `FloatingPoint` are explicitly documented below.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Decimal /* : FloatingPoint */ {
    @available(*, deprecated, message: "Use '-Decimal.greatestFiniteMagnitude' instead")
    public static let leastFiniteMagnitude = Decimal(
        _exponent: 127,
        _length: 8,
        _isNegative: 1,
        _isCompact: 1,
        _reserved: 0,
        _mantissa: (0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff)
    )

    /// The greatest finite number representable by this type.
    ///
    /// This value compares greater than or equal to all finite numbers.
    /// As `Decimal` does not represent infinity, no values compare greater than this value.
    public static let greatestFiniteMagnitude = Decimal(
        _exponent: 127,
        _length: 8,
        _isNegative: 0,
        _isCompact: 1,
        _reserved: 0,
        _mantissa: (0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff)
    )

    /// The least positive normal number representable by this type.
    ///
    /// This value compares less than or equal to all positive normal numbers.
    /// Smaller positive numbers are *subnormal*, meaning that they are represented with less precision than normal numbers.
    public static let leastNormalMagnitude = Decimal(
        _exponent: -128,
        _length: 8,
        _isNegative: 0,
        _isCompact: 1,
        _reserved: 0,
        _mantissa: (0x999a, 0x9999, 0x9999, 0x9999, 0x9999, 0x9999, 0x9999, 0x1999)
    )

    /// The least positive number representable by this type.
    ///
    /// This value compares less than or equal to all positive numbers but greater than zero.
    public static let leastNonzeroMagnitude = Decimal(
        _exponent: -128,
        _length: 1,
        _isNegative: 0,
        _isCompact: 1,
        _reserved: 0,
        _mantissa: (0x0001, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000)
    )

    /// The mathematical constant pi (π), approximately equal to 3.14159.
    ///
    /// When measuring an angle in radians, π is equivalent to a half-turn.
    ///
    /// This value is provided at its best possible precision, rounded to nearest.
    public static let pi = Decimal(
        _exponent: -38,
        _length: 8,
        _isNegative: 0,
        _isCompact: 1,
        _reserved: 0,
        _mantissa: (0x6624, 0x7d57, 0x16e7, 0xad0d, 0xaf52, 0x4641, 0xdfa7, 0xec58)
    )

    @available(*, unavailable, message: "Decimal does not represent infinity")
    public static var infinity: Decimal { fatalError("Decimal does not represent infinity") }

    @available(*, unavailable, message: "Decimal does not represent signaling NaN")
    public static var signalingNaN: Decimal { fatalError("Decimal does not represent signaling NaN") }

    @available(*, deprecated, renamed: "nan")
    public static var quietNaN: Decimal { nan }

    /// A quiet NaN ("not a number").
    ///
    /// Unlike `FloatingPoint.nan`, a NaN of type `Decimal` compares equal to itself and less than every other value.
    public static let nan = Decimal(
        _exponent: 0,
        _length: 0,
        _isNegative: 1,
        _isCompact: 0,
        _reserved: 0,
        _mantissa: (0, 0, 0, 0, 0, 0, 0, 0)
    )

    /// The radix, or base of exponentiation, for a floating-point type.
    ///
    /// The magnitude of a floating-point value *x* of type F can be calculated by the following formula,
    /// where `**` is exponentiation:
    ///
    ///     x.significand * (F.radix ** x.exponent)
    @inline(always)
    public static var radix: Int { 10 }

    /// Creates and initializes a decimal with the provided unsigned integer value.
    public init(_ value: UInt8) {
        self.init(UInt64(value))
    }

    /// Creates and initializes a decimal with the provided integer value.
    public init(_ value: Int8) {
        self.init(Int64(value))
    }

    /// Creates and initializes a decimal with the provided unsigned integer value.
    public init(_ value: UInt16) {
        self.init(UInt64(value))
    }

    /// Creates and initializes a decimal with the provided integer value.
    public init(_ value: Int16) {
        self.init(Int64(value))
    }

    /// Creates and initializes a decimal with the provided unsigned integer value.
    public init(_ value: UInt32) {
        self.init(UInt64(value))
    }

    /// Creates and initializes a decimal with the provided integer value.
    public init(_ value: Int32) {
        self.init(Int64(value))
    }

    /// Creates and initializes a decimal with the provided unsigned integer value.
    public init(_ value: UInt64) {
        self = Decimal()
        if value == 0 { return }
        _significand = UInt128(truncatingIfNeeded: value)
        _exponent = 0
        _isCompact = 0
        compact()
    }

    /// Creates and initializes a decimal with the provided integer value.
    public init(_ value: Int64) {
        self = .init(value.magnitude)
        if value < 0 {
            self._isNegative = 1
        }
    }

    /// Creates and initializes a decimal with the provided unsigned integer value.
    public init(_ value: UInt) {
        self.init(UInt64(value))
    }

    /// Creates and initializes a decimal with the provided integer value.
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

    /// Creates a new value from the given sign, exponent, and significand.
    ///
    /// The following example uses this initializer to create a new `Decimal` instance.
    ///
    ///     let x = Decimal(sign: .plus, exponent: -2, significand: 1.5)
    ///     // x == 0.015
    ///
    /// This initializer is equivalent to the following calculation, where `**` is exponentiation,
    /// computed as if by a single, correctly rounded floating-point operation:
    ///
    ///     let sign: FloatingPointSign = .plus
    ///     let exponent = -2
    ///     let significand: Decimal = 1.5
    ///     let y = (sign == .minus ? -1 : 1) * significand * (10 ** exponent)
    ///     // y == 0.015
    ///
    /// - Parameters:
    ///   - sign: The sign to use for the new value.
    ///   - exponent: The new value's exponent.
    ///   - significand: The new value's significand.
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
            self = try significand._multiplyByPowerOfTen(power: exponent, roundingMode: .bankers)
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

    /// Creates a new value using the sign of one value and the magnitude of another.
    ///
    /// - Parameters:
    ///   - sign: A `Decimal` with the sign to use for the new value.
    ///   - magnitude: A `Decimal` with the magnitude of the new value.
    public init(signOf sign: Decimal, magnitudeOf magnitude: Decimal) {
        self.init(
            _exponent: magnitude._exponent,
            _length: magnitude._length,
            _isNegative: sign._isNegative,
            _isCompact: magnitude._isCompact,
            _reserved: 0,
            _mantissa: magnitude._mantissa)
    }

    /// The exponent of the decimal floating-point value.
    ///
    /// For a finite `Decimal` value `x`, the magnitude can be calculated as the following,
    /// where `**` is exponentiation:
    ///
    ///     x.significand * (10 ** x.exponent)
    ///
    /// In the next example, `y` has a value of `21.5`, represented as `215 * (10 ** -1)`.
    ///
    ///     let y = Decimal(string: "21.5")!
    ///     // y.significand == 215
    ///     // y.exponent == -1
    ///
    /// This property is the exponent of the value's stored representation.
    /// Equal values can have different stored exponents and significands.
    ///
    /// Unlike `FloatingPoint.exponent`, this property is not the decimal logarithm of the magnitude rounded down to an integer,
    /// and it has no edge cases where the value is zero or NaN.
    public var exponent: Int {
        return Int(_exponent)
    }

    /// The significand of the decimal floating-point value.
    ///
    /// For a finite `Decimal` value `x`, the magnitude can be calculated as the following,
    /// where `**` is exponentiation:
    ///
    ///     x.significand * (10 ** x.exponent)
    ///
    /// In the next example, `y` has a value of `21.5`, represented as `215 * (10 ** -1)`.
    ///
    ///     let y = Decimal(string: "21.5")!
    ///     // y.significand == 215
    ///     // y.exponent == -1
    ///
    /// For a finite nonzero value, this property is the significand (or mantissa) of the value's stored representation.
    /// Equal values can have different stored exponents and significands.
    /// If the value is zero or NaN, then `significand` is zero or NaN, respectively.
    ///
    /// Unlike `FloatingPoint.significand`, this property is not scaled to the range `1 ..< radix`.
    public var significand: Decimal {
        let length = _length
        let isCompact = _isCompact
        var result = Decimal(
            _exponent: 0,
            _length: length,
            _isNegative: length == 0 ? _isNegative : 0,
            _isCompact: isCompact,
            _reserved: 0,
            _mantissa: _mantissa)
        if isCompact != 0 && !result._isActuallyCompact { result._isCompact = 0 }
        return result
    }

    /// The sign of the decimal floating-point value.
    ///
    /// The `sign` property is `.minus` if the value's signbit is set and `.plus` otherwise.
    /// If a `Decimal` value `x` is NaN, `x.sign` is `.minus`.
    public var sign: FloatingPointSign {
        return _isNegative == 0 ? FloatingPointSign.plus : FloatingPointSign.minus
    }

    /// The unit in the last place of this value.
    ///
    /// This is the unit of the least significant digit in this value's significand when represented with as much precision as possible.
    /// For most numbers `x`, this is the difference between `x` and the next greater (in magnitude) representable number.
    /// If `x` is NaN, then `x.ulp` is NaN.
    /// `greatestFiniteMagnitude.ulp` is a finite number, even though no greater number is representable.
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

    /// The floating-point classification of this value.
    ///
    /// `Decimal` does not represent values with classification `negativeInfinity`, `negativeZero`, `positiveInfinity`, or `signalingNaN`.
    public var floatingPointClass: FloatingPointClassification {
        if _length == 0 {
            return _isNegative == 1 ? .quietNaN : .positiveZero
        }
        if _isNegative == 1 {
            return isSubnormal ? .negativeSubnormal : .negativeNormal
        }
        if isSubnormal {
            return .positiveSubnormal
        }
        return .positiveNormal
    }

    /// A Boolean value indicating whether this instance's representation is in its canonical form.
    @available(*, deprecated, message: "Decimal does not fully adopt FloatingPoint")
    public var isCanonical: Bool { true }

    /// A Boolean value indicating whether this instance's sign is minus.
    ///
    /// For a `Decimal` value `x`, `x.isSignMinus` is equivalent to the following comparison: `x.sign == .minus`.
    /// This property is `true` when the value is negative or NaN; otherwise, `false`.
    public var isSignMinus: Bool { _isNegative != 0 }

    /// A Boolean value indicating whether this instance is equal to zero.
    ///
    /// For a `Decimal` value `x`, `x.isZero` is equivalent to the following comparison: `x == 0.0`.
    public var isZero: Bool { _length == 0 && _isNegative == 0 }

    /// A Boolean value indicating whether this instance is subnormal.
    ///
    /// A *subnormal* value is a nonzero number that has a lesser magnitude than the smallest normal number.
    /// Subnormal values don't use the full precision available to values of a type.
    ///
    /// Zero is neither a normal nor a subnormal number.
    /// Subnormal numbers are also called *denormal* or *denormalized*—these are different names for the same concept.
    public var isSubnormal: Bool {
        guard _length != 0 else { return false }
        guard _exponent < -90 else { return false }

        let m = _significand
        // Deliberately underestimate the max "headroom" for scaling up,
        // using 1233/4096 as a close approximation of 1/log2(10) -- cf. Hacker's Delight, ch. 11.
        let shift = ((m|1).leadingZeroBitCount &* 1233) &>> 12
        let available = Int(_exponent &+ 128)
        // Since our underestimate is off by at most one,
        // it's subnormal if `shift > available` and normal if `shift < available`.
        if shift != available { return shift > available }
        // If `shift == available`, determine if the actual headroom was underestimated
        // (and hence exceeds the available exponent range).
        return m &* _uint128_pow10[shift] <= 34028236692093846346337460743176821145 /* UInt128.max / 10 */
    }

    /// A Boolean value indicating whether this instance is normal.
    ///
    /// A *normal* value is a finite number that uses the full precision available to values of a type.
    /// Zero is neither a normal nor a subnormal number.
    public var isNormal: Bool { _length != 0 && !isSubnormal }

    /// A Boolean value indicating whether this value is finite.
    ///
    /// All `Decimal` values other than NaN are finite, whether zero, subnormal, or normal.
    public var isFinite: Bool { !isNaN }

    /// A Boolean value indicating whether this value is infinite.
    ///
    /// `Decimal` does not represent infinity, so this property is always `false`.
    public var isInfinite: Bool { false }

    /// A Boolean value indicating whether this value is NaN ("not a number").
    ///
    /// For a value `x` specifically of `Decimal` type, `x.isNaN` is equivalent to the following comparison: `x == .nan`.
    public var isNaN: Bool { _length == 0 && _isNegative == 1 }

    @available(*, deprecated, renamed: "isSignalingNaN")
    public var isSignaling: Bool { false }

    /// A Boolean value indicating whether this value is a signaling NaN.
    ///
    /// `Decimal` does not represent signaling NaN, so this property is always `false`.
    public var isSignalingNaN: Bool { false }

    @available(*, unavailable, message: "Decimal does not fully adopt FloatingPoint")
    public mutating func formTruncatingRemainder(dividingBy other: Decimal) { fatalError("Decimal does not fully adopt FloatingPoint") }

    /// The least representable value that compares greater than this value.
    ///
    /// For any finite `Decimal` value `x` except `greatestFiniteMagnitude`, `x.nextUp` is greater than `x`.
    /// For `greatestFiniteMagnitude`, `x.nextUp` is NaN.
    /// For `nan`, `x.nextUp` is `x` itself.
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

    /// The greatest representable value that compares less than this value.
    ///
    /// For any finite `Decimal` value `x`, `x.nextDown` is less than `x`.
    /// For `nan`, `x.nextDown` is `x` itself.
    public var nextDown: Decimal {
        return -(-self).nextUp
    }

    /// Returns a Boolean value indicating whether this instance is equal to the given value.
    ///
    /// - Parameter other: The value to compare with this value.
    /// - Returns: `true` if `other` has the same value as this instance; otherwise `false`.
    ///   If both this value and `other` are NaN, the result of this method is `true`; otherwise, if either is NaN, the result is `false`.
    public func isEqual(to other: Decimal) -> Bool {
        return self == other
    }

    /// Returns a Boolean value indicating whether this instance is less than the given value.
    ///
    /// - Parameter other: The value to compare with this value.
    /// - Returns: `true` if this value is less than `other`; otherwise `false`.
    ///   If `other` is NaN, the result of this method is `false`; otherwise, if this value is NaN, the result is `true`.
    public func isLess(than other: Decimal) -> Bool {
        return Decimal._compare(lhs: self, rhs: other) == .orderedAscending
    }

    /// Returns a Boolean value indicating whether this instance is less than or equal to the given value.
    ///
    /// - Parameter other: The value to compare with this value.
    /// - Returns: `true` if this value is not greater than `other`; otherwise `false`.
    ///   If this value is NaN, the result of this method is `true`; otherwise, if `other` is NaN, the result is `false`.
    public func isLessThanOrEqualTo(_ other: Decimal) -> Bool {
        let order = Decimal._compare(lhs: self, rhs: other)
        return order == .orderedAscending || order == .orderedSame
    }

    /// Returns a Boolean value indicating whether this instance should precede or tie positions with the given value in an ascending sort.
    @available(*, deprecated, message: "Decimal does not fully adopt FloatingPoint")
    public func isTotallyOrdered(belowOrEqualTo other: Decimal) -> Bool {
        // Unfortunately, this implementation doesn't provide a total order:
        // for example, NaN compared to itself returns `false`.

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
    /// Creates a `Decimal` instance initialized to the specified floating-point value.
    ///
    /// Do not call this initializer directly. Instead, initialize a variable or constant using a floating-point literal. For example:
    ///
    ///     let x: Decimal = 21.5
    ///
    /// In this example, the assignment to the `x` constant calls this floating-point literal initializer behind the scenes.
    public init(floatLiteral value: Double) {
        self.init(value)
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Decimal : ExpressibleByIntegerLiteral {
    /// Creates a `Decimal` instance initialized to the specified integer value.
    ///
    /// Do not call this initializer directly. Instead, initialize a variable or constant using an integer literal. For example:
    ///
    ///     let x: Decimal = 42
    ///
    /// In this example, the assignment to the `x` constant calls this integer literal initializer behind the scenes.
    public init(integerLiteral value: Int) {
        self.init(value)
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Decimal: Hashable {
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
    /// The magnitude of this decimal floating-point value.
    ///
    /// For any numeric value `x`, `x.magnitude` is the absolute value of `x`.
    /// You can also use the global `abs(_:)` function when you need to find an absolute value.
    public var magnitude: Decimal {
        guard _length != 0 else { return self }
        return Decimal(
            _exponent: self._exponent, _length: self._length,
            _isNegative: 0, _isCompact: self._isCompact,
            _reserved: 0, _mantissa: self._mantissa)
    }

    /// Creates a new decimal floating-point value, if the given integer can be represented exactly.
    ///
    /// If the given integer cannot be represented exactly as a `Decimal`, the result is `nil`.
    ///
    /// - Parameter source: The integer to convert to a decimal floating-point value.
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

    /// Adds two decimal floating-point values and stores the result in the left-hand-side variable,
    /// rounding to a representable value.
    ///
    /// Overflow results in NaN.
    ///
    /// If the unrounded result of this operation requires more precision than the `Decimal` type can provide,
    /// the result is rounded using the ``Decimal/RoundingMode/bankers`` rounding mode (round to nearest, ties to even).
    /// To specify a different rounding mode, use the ``NSDecimalAdd(_:_:_:_:)`` function instead.
    ///
    /// - Parameters:
    ///   - lhs: The first value to add.
    ///   - rhs: The second value to add.
    public static func +=(lhs: inout Decimal, rhs: Decimal) {
        do {
            let result = try lhs._add(rhs: rhs, roundingMode: .bankers)
            lhs = result
        } catch {
            lhs = .nan
        }
    }

    /// Subtracts the second decimal floating-point value from the first and stores the difference in the left-hand-side variable,
    /// rounding to a representable value.
    ///
    /// Overflow results in NaN.
    ///
    /// If the unrounded result of this operation requires more precision than the `Decimal` type can provide,
    /// the result is rounded using the ``Decimal/RoundingMode/bankers`` rounding mode (round to nearest, ties to even).
    /// To specify a different rounding mode, use the ``NSDecimalSubtract(_:_:_:_:)`` function instead.
    ///
    /// - Parameters:
    ///   - lhs: A numeric value.
    ///   - rhs: The value to subtract from `lhs`.
    public static func -=(lhs: inout Decimal, rhs: Decimal) {
        do {
            let result = try lhs._subtract(rhs: rhs, roundingMode: .bankers)
            lhs = result
        } catch {
            lhs = .nan
        }
    }

    /// Multiplies two decimal floating-point values and stores the result in the left-hand-side variable,
    /// rounding to a representable value.
    ///
    /// Overflow results in NaN.
    ///
    /// If the unrounded result of this operation requires more precision than the `Decimal` type can provide,
    /// the result is rounded using the ``Decimal/RoundingMode/bankers`` rounding mode (round to nearest, ties to even).
    /// To specify a different rounding mode, use the ``NSDecimalMultiply(_:_:_:_:)`` function instead.
    ///
    /// - Parameters:
    ///   - lhs: The first value to multiply.
    ///   - rhs: The second value to multiply.
    public static func *=(lhs: inout Decimal, rhs: Decimal) {
        do {
            let result = try lhs._multiply(by: rhs, roundingMode: .bankers)
            lhs = result
        } catch _CalculationError.underflow {
            lhs = .zero
        } catch {
            lhs = .nan
        }
    }

    /// Divides the first decimal floating-point value by the second and stores the quotient in the left-hand-side variable,
    /// rounding to a representable value.
    ///
    /// Overflow results in NaN. If `rhs` is zero, the result of the division is NaN.
    ///
    /// When the unrounded result of this operation requires more precision than the `Decimal` type can provide,
    /// the result is rounded using the ``Decimal/RoundingMode/bankers`` rounding mode (round to nearest, ties to even).
    /// To specify a different rounding mode, use the ``NSDecimalDivide(_:_:_:_:)`` function instead.
    ///
    /// - Parameters:
    ///   - lhs: The value to divide.
    ///   - rhs: The value to divide `lhs` by.
    public static func /=(lhs: inout Decimal, rhs: Decimal) {
        do {
            let result = try lhs._divide(by: rhs, roundingMode: .bankers)
            lhs = result
        } catch _CalculationError.underflow {
            lhs = .zero
        } catch {
            lhs = .nan
        }
    }

    /// Adds two decimal floating-point values and produces their sum, rounded to a representable value.
    ///
    /// Overflow results in NaN.
    ///
    /// If the unrounded result of this operation requires more precision than the `Decimal` type can provide,
    /// the result is rounded using the ``Decimal/RoundingMode/bankers`` rounding mode (round to nearest, ties to even).
    /// To specify a different rounding mode, use the ``NSDecimalAdd(_:_:_:_:)`` function instead.
    ///
    /// - Parameters:
    ///   - lhs: The first value to add.
    ///   - rhs: The second value to add.
    /// - Returns: The result of adding `lhs` and `rhs`.
    public static func +(lhs: Decimal, rhs: Decimal) -> Decimal {
        var answer = lhs
        answer += rhs
        return answer
    }

    /// Subtracts one decimal floating-point value from another and produces their difference, rounded to a representable value.
    ///
    /// Overflow results in NaN.
    ///
    /// If the unrounded result of this operation requires more precision than the `Decimal` type can provide,
    /// the result is rounded using the ``Decimal/RoundingMode/bankers`` rounding mode (round to nearest, ties to even).
    /// To specify a different rounding mode, use the ``NSDecimalSubtract(_:_:_:_:)`` function instead.
    ///
    /// - Parameters:
    ///   - lhs: A numeric value.
    ///   - rhs: The value to subtract from `lhs`.
    /// - Returns: The result of subtracting `rhs` from `lhs`.
    public static func -(lhs: Decimal, rhs: Decimal) -> Decimal {
        var answer = lhs
        answer -= rhs
        return answer
    }

    /// Multiplies two decimal floating-point values and produces their product, rounded to a representable value.
    ///
    /// Overflow results in NaN.
    ///
    /// If the unrounded result of this operation requires more precision than the `Decimal` type can provide,
    /// the result is rounded using the ``Decimal/RoundingMode/bankers`` rounding mode (round to nearest, ties to even).
    /// To specify a different rounding mode, use the ``NSDecimalMultiply(_:_:_:_:)`` function instead.
    ///
    /// - Parameters:
    ///   - lhs: The first value to multiply.
    ///   - rhs: The second value to multiply.
    /// - Returns: The result of multiplying `lhs` by `rhs`.
    public static func *(lhs: Decimal, rhs: Decimal) -> Decimal {
        var answer = lhs
        answer *= rhs
        return answer
    }

    /// Divides one decimal floating-point value by another and produces their quotient, rounded to a representable value.
    ///
    /// Overflow results in NaN. If `rhs` is zero, the result of the division is NaN.
    ///
    /// When the unrounded result of this operation requires more precision than the `Decimal` type can provide,
    /// the result is rounded using the ``Decimal/RoundingMode/bankers`` rounding mode (round to nearest, ties to even).
    /// To specify a different rounding mode, use the ``NSDecimalDivide(_:_:_:_:)`` function instead.
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

    /// Replaces this decimal floating-point value with its additive inverse.
    ///
    /// The result is always exact.
    /// If the value is zero or NaN, it is unchanged.
    public mutating func negate() {
        guard self._length != 0 else { return }
        self._isNegative = self._isNegative == 0 ? 1 : 0
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Decimal : Strideable {
    /// Returns the distance from this value to the given value, expressed as a stride.
    ///
    /// Using this method with `Decimal` may result in an approximation due to rounding.
    public func distance(to other: Decimal) -> Decimal {
        return other - self
    }

    /// Returns a value that is offset the specified distance from this value.
    ///
    /// Use the `advanced(by:)` method in generic code to offset a value by a specified distance.
    /// If you're working directly with numeric values, use the addition operator (`+`) instead of this method.
    /// Using this method with `Decimal` may result in an approximation due to rounding.
    public func advanced(by n: Decimal) -> Decimal {
        return self + n
    }
}
