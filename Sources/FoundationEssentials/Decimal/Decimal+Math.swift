//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(Darwin)
import Darwin
#elseif canImport(Bionic)
@preconcurrency import Bionic
#elseif canImport(Glibc)
@preconcurrency import Glibc
#elseif canImport(Musl)
@preconcurrency import Musl
#elseif canImport(CRT)
import CRT
#elseif os(WASI)
@preconcurrency import WASILibc
#endif

private let _pow10: [39 of UInt128] = [
                                                      1,    //  0
                                                     10,    //  1
                                                    100,    //  2
                                                  1_000,    //  3
                                                 10_000,    //  4
                                                100_000,    //  5
                                              1_000_000,    //  6
                                             10_000_000,    //  7
                                            100_000_000,    //  8
                                          1_000_000_000,    //  9
                                         10_000_000_000,    // 10
                                        100_000_000_000,    // 11
                                      1_000_000_000_000,    // 12
                                     10_000_000_000_000,    // 13
                                    100_000_000_000_000,    // 14
                                  1_000_000_000_000_000,    // 15
                                 10_000_000_000_000_000,    // 16
                                100_000_000_000_000_000,    // 17
                              1_000_000_000_000_000_000,    // 18
                             10_000_000_000_000_000_000,    // 19
                            100_000_000_000_000_000_000,    // 20
                          1_000_000_000_000_000_000_000,    // 21
                         10_000_000_000_000_000_000_000,    // 22
                        100_000_000_000_000_000_000_000,    // 23
                      1_000_000_000_000_000_000_000_000,    // 24
                     10_000_000_000_000_000_000_000_000,    // 25
                    100_000_000_000_000_000_000_000_000,    // 26
                  1_000_000_000_000_000_000_000_000_000,    // 27
                 10_000_000_000_000_000_000_000_000_000,    // 28
                100_000_000_000_000_000_000_000_000_000,    // 29
              1_000_000_000_000_000_000_000_000_000_000,    // 30
             10_000_000_000_000_000_000_000_000_000_000,    // 31
            100_000_000_000_000_000_000_000_000_000_000,    // 32
          1_000_000_000_000_000_000_000_000_000_000_000,    // 33
         10_000_000_000_000_000_000_000_000_000_000_000,    // 34
        100_000_000_000_000_000_000_000_000_000_000_000,    // 35
      1_000_000_000_000_000_000_000_000_000_000_000_000,    // 36
     10_000_000_000_000_000_000_000_000_000_000_000_000,    // 37
    100_000_000_000_000_000_000_000_000_000_000_000_000,    // 38
]

extension UInt128 {
    @inline(__always)
    internal static func _compare(_ lhs: Self, _ rhs: Self) -> ComparisonResult {
        if lhs == rhs { return .orderedSame }
        if lhs < rhs { return .orderedAscending }
        return .orderedDescending
    }
    
    // Division by constant integer by multiplication and shift.
    @inline(__always)
    internal func _quotientAndRemainderDividingBy10() -> (quotient: Self, remainder: Self) {
        let m = 0xCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCD as UInt128
        let q = self.multipliedFullWidth(by: m).high &>> 3
        let r = self &- q &* 10
        return (q, r)
    }
    
    @inline(__always)
    internal func _quotientAndRemainderDividingBy10000() -> (quotient: Self, remainder: Self) {
        let m = 0xD1B71758E219652BD3C36113404EA4A9 as UInt128
        let q = self.multipliedFullWidth(by: m).high &>> 13
        let r = self &- q &* 10000
        return (q, r)
    }
    
    @inline(__always)
    internal static func _10DividingFullWidth(
        _ dividend: (high: Self, low: Self)
    ) -> (quotient: Self, remainder: Self) {
        assert(dividend.high < 10)
        let (q1, r1): (UInt128, UInt128) = (34028236692093846346337460743176821145, 6) // (2^128 / 10, 2^128 % 10)
        let (sum_, carry_) = dividend.low.addingReportingOverflow(dividend.high &* r1)
        let carry: UInt128 = carry_ ? 1 : 0
        let (q2, r2) = (sum_ &+ carry &* r1)._quotientAndRemainderDividingBy10()
        return (dividend.high &* q1 &+ carry &* q1 &+ q2, r2)
    }
    
    @inline(__always)
    internal static func _10000DividingFullWidth(
        _ dividend: (high: Self, low: Self)
    ) -> (quotient: Self, remainder: Self) {
        assert(dividend.high < 10000)
        let (q1, r1): (UInt128, UInt128) = (34028236692093846346337460743176821, 1456) // (2^128 / 10000, 2^128 % 10000)
        let (sum_, carry_) = dividend.low.addingReportingOverflow(dividend.high &* r1)
        let carry: UInt128 = carry_ ? 1 : 0
        let (q2, r2) = (sum_ &+ carry &* r1)._quotientAndRemainderDividingBy10000()
        return (dividend.high &* q1 &+ carry &* q1 &+ q2, r2)
    }
}

// MARK: - Mathematics
extension Decimal {
    internal static let maxSize: UInt32 = 8

    internal enum _CalculationError: Error {
        case overflow
        case underflow
        case divideByZero
    }

    internal func _add(
        rhs: Decimal,
        roundingMode: RoundingMode
    ) throws -> (result: Decimal, lossOfPrecision: Bool) {
        if self.isNaN || rhs.isNaN {
            throw _CalculationError.overflow
        }
        if self._length == 0 {
            return (result: rhs, lossOfPrecision: false)
        }
        if rhs._length == 0 {
            return (result: self, lossOfPrecision: false)
        }
        
        var a = self
        var b = rhs
        if a._exponent < b._exponent { swap(&a, &b) }
        let commonExponent = max(b._exponent, a._exponent - 38)
        let shift = (a: Int(a._exponent - commonExponent), b: Int(commonExponent - b._exponent))
        
        var (hi, lo) = a._significand.multipliedFullWidth(by: _pow10[shift.a])
        let divisor: UInt128
        let q: UInt128
        var r: UInt128
        if shift.b == 0 {
            divisor = 1
            (q, r) = (b._significand, 0)
        } else if shift.b < 39 {
            divisor = _pow10[shift.b]
            (q, r) = b._significand.quotientAndRemainder(dividingBy: divisor)
        } else {
            // A nonzero proxy value under 0.5 ulp.
            divisor = 10
            (q, r) = (0, 1)
        }
        
        let isNegative: UInt32
        if a._isNegative == b._isNegative {
            isNegative = a._isNegative
            let carry: Bool
            (lo, carry) = lo.addingReportingOverflow(q)
            if carry { hi &+= 1 }
        } else if hi != 0 || lo > q {
            isNegative = a._isNegative
            let borrow: Bool
            (lo, borrow) = lo.subtractingReportingOverflow(q)
            if borrow { hi &-= 1 }
            if r != 0 {
                // We have a "negative" remainder, so we need to borrow 1 ulp
                // and set the remainder to (divisor - remainder) / divisor.
                let borrow_: Bool
                (lo, borrow_) = lo.subtractingReportingOverflow(1)
                if borrow_ { hi &-= 1 }
                r = divisor - r
            }
        } else {
            isNegative = b._isNegative
            lo = q - lo
        }
        
        let (fitted, shift_, lossOfPrecision): (UInt128, Int32, Bool)
        if hi != 0 {
            (fitted, shift_, lossOfPrecision) = Self._fitSignificand(isNegative: isNegative != 0, high: hi, low: lo, inexact: r != 0, roundingMode: roundingMode)
        } else {
            (fitted, shift_) = Self._roundSignificandByRemainderAfterDivision(isNegative: isNegative != 0, significand: lo, remainder: r, divisor: divisor, roundingMode: roundingMode)
            lossOfPrecision = r != 0
        }
        
        if fitted == 0 {
            return (.zero, lossOfPrecision)
        }
        let exponent = commonExponent + shift_
        if exponent > Int8.max {
            throw _CalculationError.overflow
            //TODO: Consider conditions under which it might be possible to adjust the significand so that the exponent fits.
        }
        
        var result = Decimal()
        result._significand = fitted
        result._isNegative = isNegative
        result._exponent = exponent
        result._isCompact = 0
        result.compact()
        return (result, lossOfPrecision)
    }

    internal func _add(_ amount: UInt16) throws -> Decimal {
        let (sum, carry) = self._significand.addingReportingOverflow(UInt128(amount))
        if carry { throw _CalculationError.overflow }
        var result = self
        result._significand = sum
        return result
    }

    internal func _subtract(
        rhs: Decimal,
        roundingMode: RoundingMode
    ) throws -> Decimal {
        var right = rhs
        if right._length != 0 {
            right._isNegative = right._isNegative == 0 ? 1 : 0
        }
        return try self._add(
            rhs: right,
            roundingMode: roundingMode
        ).result
    }

    internal func _multiply(byShort multiplicand: UInt16) throws -> Decimal {
        var result = self
        if multiplicand == 0 {
            result._length = 0
            return result
        }
        var carry: UInt32 = 0
        var index: UInt32 = 0
        while index < result._length {
            let acc = UInt32(result[index]) *
            UInt32(multiplicand) + carry
            carry = acc >> 16
            result[index] = UInt16(acc & 0xFFFF)
            index += 1
        }
        if carry != 0 {
            if result._length >= Decimal.maxSize {
                throw _CalculationError.overflow
            }
            result[index] = UInt16(carry)
            index += 1
        }
        result._length = index
        return result
    }

    internal func _multiply(
        by multiplicand: Decimal,
        roundingMode: RoundingMode
    ) throws -> Decimal {
        if self.isNaN || multiplicand.isNaN {
            throw _CalculationError.overflow
        }
        if self._length == 0 || multiplicand._length == 0 {
            return .zero
        }
        
        let isNegative = self._isNegative != multiplicand._isNegative
        let (high, low) = self._significand.multipliedFullWidth(by: multiplicand._significand)
        var exponent = self._exponent + multiplicand._exponent
        let fitted: UInt128
        if high == 0 {
            fitted = low
        } else {
            //FIXME: Track loss of precision.
            let (fitted_, shift, _) = Self._fitSignificand(isNegative: isNegative, high: high, low: low, roundingMode: roundingMode)
            fitted = fitted_
            exponent += shift
        }
        
        if exponent > Int8.max { throw _CalculationError.overflow }
        //FIXME: `.underflow` only when subnormal-like loss of precision still won't fit: enhance `_fitSignificand` to take a `maxDigits` parameter.
        if exponent < Int8.min { throw _CalculationError.underflow }
        
        var result = Decimal()
        result._significand = fitted
        result._isNegative = isNegative ? 1 : 0
        result._exponent = exponent
        result._isCompact = 0
        result.compact()
        return result
    }

    internal func _multiplyByPowerOfTen(
        power: Int, roundingMode: RoundingMode
    ) throws -> Decimal {
        if self.isNaN {
            throw _CalculationError.overflow
        }
        if self._length == 0 {
            return .zero
        }
        var result = self
        let secureExponent = result._exponent + Int32(power)
        if secureExponent < CChar.min {
            throw _CalculationError.underflow
        }
        if secureExponent > CChar.max {
            throw _CalculationError.overflow
        }
        result._exponent = secureExponent
        return result
    }
    
    internal func _multiplyBy10AndAdd(
        number: UInt16
    ) throws -> Decimal {
        do {
            var result = try _multiply(byShort: 10)
            result = try result._add(number)
            return result
        } catch {
            throw _CalculationError.overflow
        }
    }

    internal func _divide(by divisor: UInt16) throws -> (result: Decimal, remainder: UInt16) {
        guard divisor != 0 else { throw _CalculationError.divideByZero }
        let (q, r) = self._significand.quotientAndRemainder(dividingBy: UInt128(divisor))
        var result = self
        result._significand = q
        return (result, UInt16(r))
    }

    internal func _divide(
        by divisor: Decimal,
        roundingMode: RoundingMode
    ) throws -> Decimal {
        guard !self.isNaN && !divisor.isNaN else {
            throw _CalculationError.overflow
        }
        guard divisor._length > 0 else {
            throw _CalculationError.divideByZero
        }
        if self._length == 0 {
            return .zero
        }
        
        //TODO: Consider multiple-of-10 fast path.

        var a = self
        var b = divisor

        /// If the precision of the left operand is much smaller
        /// than that of the right operand (for example,
        /// 20 and 0.112314123094856724234234572), then the
        /// difference in their exponents is large and a lot of
        /// precision will be lost below. This is particularly
        /// true as the difference approaches 38 or larger.
        /// Normalizing here looses some precision on the
        /// individual operands, but often produces a more
        /// accurate result later. I chose 19 arbitrarily
        /// as half of the magic 38, so that normalization
        /// doesn't always occur. - cjk 5 Aug 1999
        if 19 <= a._exponent - b._exponent {
            _ = try Decimal._normalize(
                a: &a, b: &b, roundingMode: roundingMode
            )
            // Sometimes the normalization done is inappropriate
            // and forces one of the operands to b 0. If this
            // happens, restore both
            // <rdar://problem/5197585>, <rdar://problem/2354750>
            if a._length == 0 || b._length == 0 {
                a = self
                b = divisor
            }
        }

        let isNegative = a._isNegative != b._isNegative
        
        let bm = b._significand // Nonzero.
        let (hi, lo) = a._significand.multipliedFullWidth(by: _pow10[38])
        let (q1, r1) = hi.quotientAndRemainder(dividingBy: bm)
        let (q2, r2) = bm.dividingFullWidth((r1, lo))
        
        let fitted: UInt128
        var exponent = a._exponent - b._exponent - 38
        if q1 == 0 {
            //FIXME: Track loss of precision.
            let (fitted_, shift) = Self._roundSignificandByRemainderAfterDivision(isNegative: isNegative, significand: q2, remainder: r2, divisor: bm, roundingMode: roundingMode)
            fitted = fitted_
            exponent += shift
        } else {
            //FIXME: Track loss of precision.
            let (fitted_, shift, _) = Self._fitSignificand(isNegative: isNegative, high: q1, low: q2, inexact: r2 != 0, roundingMode: roundingMode)
            fitted = fitted_
            exponent += shift
        }
        
        if fitted == 0 {
            //TODO: Tiny dividend, huge divisor, to be addressed soon.
            return .zero
        }
        if exponent > Int8.max { throw _CalculationError.overflow }
        if exponent < Int8.min { throw _CalculationError.underflow }
        
        var result = Decimal()
        result._significand = fitted
        result._isNegative = isNegative ? 1 : 0
        result._exponent = exponent
        result._isCompact = 0
        result.compact()
        return result
    }

    internal func _power(
        exponent: Int, roundingMode: RoundingMode
    ) throws -> Decimal {
        if self.isNaN {
            throw _CalculationError.overflow
        }
        if exponent == 0 {
            return Decimal(1)
        }
        if self == .zero {
            // Technically 0^-n is undefined, return NaN
            return exponent > 0 ? Decimal(0) : .nan
        }
        var power = abs(exponent)
        var result = self
        var temporary = Decimal(1)
        while power > 1 {
            if power & 1 == 1 {
                temporary = try temporary._multiply(
                    by: result, roundingMode: roundingMode
                )
                power -= 1
            }
            if power != 0 {
                result = try result._multiply(
                    by: result, roundingMode: roundingMode
                )
                power /= 2
            }
        }
        result = try temporary._multiply(
            by: result, roundingMode: roundingMode
        )
        // Negative Exponent Rule
        // x^-n = 1/(x^n)
        if exponent < 0 {
            result = try Decimal(1)._divide(
                by: result,
                roundingMode: roundingMode
            )
        }
        return result
    }

    internal static func _compare(lhs: Decimal, rhs: Decimal) -> ComparisonResult {
        if lhs.isNaN {
            if rhs.isNaN {
                return .orderedSame
            }
            return .orderedAscending
        }
        if rhs.isNaN {
            return .orderedDescending
        }
        // Check the sign
        if lhs._isNegative > rhs._isNegative {
            return .orderedAscending
        }
        if lhs._isNegative < rhs._isNegative {
            return .orderedDescending
        }
        // If one of the two is 0, the other is bigger
        // because 0 implies isNegative = 0
        if lhs._length == 0 {
            return rhs._length != 0 ? .orderedAscending : .orderedSame
        }
        if rhs._length == 0 {
            return lhs._length != 0 ? .orderedDescending : .orderedSame
        }
        
        // Compare nonzero magnitudes
        let result: ComparisonResult
        let diffExp = Int(lhs._exponent - rhs._exponent)
        if diffExp == 0 {
            result = UInt128._compare(lhs._significand, rhs._significand)
        } else if diffExp < 0 {
            // `rhs` has the larger exponent.
            let diffExp = -diffExp
            if diffExp >= 39 {
                result = .orderedAscending
            } else {
                let (high, low) = rhs._significand.multipliedFullWidth(by: _pow10[diffExp])
                result = (high != 0) ? .orderedAscending : UInt128._compare(lhs._significand, low)
            }
        } else {
            // `lhs` has the larger exponent.
            if diffExp >= 39 {
                result = .orderedDescending
            } else {
                let (high, low) = lhs._significand.multipliedFullWidth(by: _pow10[diffExp])
                result = (high != 0) ? .orderedDescending : UInt128._compare(low, rhs._significand)
            }
        }

        if lhs._isNegative != 0 {
            switch result {
            case .orderedSame:
                return result
            case .orderedAscending:
                return .orderedDescending
            case .orderedDescending:
                return .orderedAscending
            }
        }
        return result
    }

    // `_normalize` has always unconditionally truncated regardless of `roundingMode`.
    internal static func _normalize(a: inout Decimal, b: inout Decimal, roundingMode _: RoundingMode) throws -> Bool {
        let diffExp = Int(a._exponent - b._exponent)
        // If the two numbers share the same exponents,
        // the normalization is already done
        if diffExp == 0 {
            return false
        }
        
        func __normalize(large: inout Decimal, small: inout Decimal, diffExp: Int) throws -> Bool {
            let lm = large._significand
            if lm == 0 {
                large._exponent = small._exponent
                large._isCompact = 0
                // Don't compact.
                return false // Exact.
            }
            
            if diffExp <= 38 {
                let (hi, lo) = lm.multipliedFullWidth(by: _pow10[diffExp])
                if hi == 0 {
                    large._significand = lo
                    large._exponent = small._exponent
                    large._isCompact = 0
                    // Don't compact.
                    return false // Exact.
                }
            }
            
            // Deliberately underestimate the max "headroom" for scaling up `large._significand`.
            let maxPowerOfTen = ((lm|1).leadingZeroBitCount &* 1233) &>> 12
            let idx = diffExp - maxPowerOfTen
            let sm_ = idx < 39 ? small._significand / _pow10[idx] : 0
            if sm_ == 0 {
                if small._significand != 0 {
                    // Strip sign bit if truncating a nonzero magnitude,
                    // so that the result isn't spuriously NaN.
                    small = Decimal()
                }
                small._exponent = large._exponent
                small._isCompact = 0
                // Don't compact.
                return true // Inexact.
            }
            small._significand = sm_
            small._exponent += Int32(diffExp - maxPowerOfTen)
            small._isCompact = 0
            
            let (hi, lo) = lm.multipliedFullWidth(by: _pow10[maxPowerOfTen])
            assert(hi == 0)
            large._significand = lo
            large._exponent -= Int32(maxPowerOfTen)
            large._isCompact = 0
            // Don't compact.
            return true // Inexact.
        }
        
        if diffExp < 0 {
            return try __normalize(large: &b, small: &a, diffExp: -diffExp)
        }
        return try __normalize(large: &a, small: &b, diffExp: diffExp)
    }

    internal mutating func compact() {
        if self._isCompact != 0 || self._length == 0 { return }

        // Divide by 10 as much as possible.
        var significand = self._significand
        if significand == 0 {
            // This branch is not reachable except with invalid values, such as in the test case.
            self = .zero
            return
        }
        var exponent = self._exponent
        while true {
            let (q, r) = significand._quotientAndRemainderDividingBy10000()
            if r != 0 { break }
            significand = q
            exponent += 4
        }
        while true {
            let (q, r) = significand._quotientAndRemainderDividingBy10()
            if r != 0 { break }
            significand = q
            exponent += 1
        }
        // Regrow if the exponent is beyond range.
        while exponent > Int8.max {
            significand &*= 10
            exponent &-= 1
        }
        self._significand = significand
        self._exponent = exponent
        // Mark the value as compact.
        self._isCompact = 1
    }

    internal func _round(
        scale: Int, roundingMode: RoundingMode
    ) throws -> Decimal {
        var s = scale + Int(self._exponent)
        if scale == CShort.max || s >= 0 {
            return self
        }
        s = -s
        var exponent = Int(self._exponent) + s
        var result = self
        var remainder: UInt16 = 0
        var premainder: UInt16 = 0
        while s > 4 {
            if remainder != 0 {
                premainder = 1
            }
            (result, remainder) = try result._divide(by: 10000)
            s -= 4
        }
        while s != 0 {
            if remainder != 0 {
                premainder = 1
            }
            (result, remainder) = try result._divide(by: 10)
            s -= 1
        }
        // If we are on a tie, adjust with premdr.
        // 0.50001 is equivalent to .6
        if premainder != 0 && (remainder == 0 || remainder == 5) {
            remainder += 1
        }
        if remainder != 0 {
            if self._isNegative != 0 {
                switch roundingMode {
                case .up:
                    break
                case .bankers:
                    if remainder == 5 && result._mantissa.0 & 1 == 0 {
                        remainder -= 1
                    }
                    fallthrough
                case .plain:
                    if remainder < 5 {
                        break
                    }
                    fallthrough
                case .down:
                    result = try result._add(1)
                    break
                @unknown default:
                    break
                }
                if result._length == 0 {
                    result._isNegative = 0
                }
            } else {
                switch roundingMode {
                case .down:
                    break
                case .bankers:
                    if remainder == 5 && result._mantissa.0 & 1 == 0 {
                        remainder -= 1
                    }
                    fallthrough
                case .plain:
                    if remainder < 5 {
                        break
                    }
                    fallthrough
                case .up:
                    result = try result._add(1)
                @unknown default:
                    break
                }
            }
        }
        result._isCompact = 0

        while exponent > CChar.max {
            exponent -= 1
            result = try result._multiply(byShort: 10)
        }
        result._exponent = Int32(exponent)
        result.compact()
        return result
    }
}

// MARK: - Numeric Values
extension Decimal {
    internal var doubleValue: Double {
        if _length == 0 {
            return _isNegative == 1 ? Double.nan : 0
        }

        var d = 0.0
        for idx in (0..<min(_length, 8)).reversed() {
            d = d * 65536 + Double(self[idx])
        }

        if _exponent < 0 {
            for _ in _exponent..<0 {
                d /= 10.0
            }
        } else {
            for _ in 0..<_exponent {
                d *= 10.0
            }
        }
        return _isNegative != 0 ? -d : d
    }

    private var _unsignedInt64Value: UInt64 {
        // Quick check if number if has too many zeros before decimal point or too many trailing zeros after decimal point.
        // Log10 (2^64) ~ 19, log10 (2^128) ~ 38
        if self._exponent < -38 || self._exponent > 20 {
            return 0
        }
        if self._length == 0 || self.isZero || self.magnitude < (0 as Decimal) {
            return 0
        }
        var value = self.significand

        for _ in 0 ..< abs(self._exponent) {
            if self._exponent < 0 {
                if let result = try? value._divide(by: 10) {
                    value = result.result
                }
            } else {
                if let result = try? value._multiply(byShort: 10) {
                    value = result
                }
            }
        }
        return UInt64(value._mantissa.3) << 48 | UInt64(value._mantissa.2) << 32 | UInt64(value._mantissa.1) << 16 | UInt64(value._mantissa.0)
    }

    internal var int64Value: Int64 {
        let uint64Value = self._unsignedInt64Value
        if self._isNegative > 0 {
            if uint64Value == Int64.max.magnitude + 1 {
                return Int64.min
            }
            if uint64Value <= Int64.max.magnitude {
                var value = Int64(uint64Value)
                value.negate()
                return value
            }
        }
        return Int64(bitPattern: uint64Value)
    }

    internal var uint64Value: UInt64 {
        let value = self._unsignedInt64Value
        if self._isNegative == 0 {
            return value
        }
        if value == Int64.max.magnitude + 1 {
            return UInt64(bitPattern: Int64.min)
        }
        if value <= Int64.max.magnitude {
            var value = Int64(value)
            value.negate()
            return UInt64(bitPattern: value)
        }
        return value
    }
    
    #if FOUNDATION_FRAMEWORK
    #else
    @_spi(SwiftCorelibsFoundation)
    public var _int64Value: Int64 { int64Value }
    
    @_spi(SwiftCorelibsFoundation)
    public var _uint64Value: UInt64 { uint64Value }
    
    @_spi(SwiftCorelibsFoundation)
    public var _doubleValue: Double { doubleValue }
    #endif
}

// MARK: - Significand Rounding
extension Decimal {
    private static func _fitSignificand(
        isNegative: Bool,
        high: UInt128,
        low: UInt128,
        inexact: Bool = false,
        roundingMode: RoundingMode
    ) -> (result: UInt128, exponent: Int32, lossOfPrecision: Bool) {
        if high == 0 {
            // An internal invariant is that we don't use this code path with a sticky bit;
            // otherwise, we'd have to consider rounding mode here.
            assert(!inexact)
            return (result: low, exponent: 0, lossOfPrecision: false)
        }
        
        var high = high
        var low = low
        var lastTruncated = 0 as UInt128
        var exponent = 0 as Int32
        var inexact = inexact
        
        while high >= 10000 {
            if lastTruncated != 0 { inexact = true }
            let (q1, r1) = high._quotientAndRemainderDividingBy10000()
            let (q2, r2) = UInt128._10000DividingFullWidth((r1, low))
            high = q1
            low = q2
            lastTruncated = r2
            exponent += 4
        }
        while high != 0 {
            if lastTruncated != 0 { inexact = true }
            let (q1, r1) = high._quotientAndRemainderDividingBy10()
            let (q2, r2) = UInt128._10DividingFullWidth((r1, low))
            high = q1
            low = q2
            lastTruncated = r2
            exponent += 1
        }
        
        // Nudge if necessary.
        assert(lastTruncated < 10)
        if inexact && (lastTruncated == 0 || lastTruncated == 5) {
            lastTruncated &+= 1
        }
        if lastTruncated == 0 {
            return (low, exponent, false)
        }
        
        // Round if necessary.
        let roundAway =
            switch roundingMode {
            case .down: isNegative
            case .up: !isNegative
            case .plain: lastTruncated >= 5
            case .bankers: lastTruncated > 5 || (lastTruncated == 5 && (low & 1) == 1)
            @unknown default: fatalError("Not implemented")  //TODO: Determine a consistent sensible behavior for unknown rounding mode.
            }
        if roundAway {
            if low == .max {
                low = 34028236692093846346337460743176821146 // 2^128 / 10, rounded (always away from zero).
                exponent += 1
            } else {
                low &+= 1
            }
        }
        return (low, exponent, true)
    }
    
    private static func _roundSignificandByRemainderAfterDivision(
        isNegative: Bool,
        significand: UInt128,
        remainder: UInt128,
        divisor: UInt128,
        roundingMode: RoundingMode
    ) -> (result: UInt128, exponent: Int32) {
        guard remainder != 0 else { return (significand, 0) }
        let cmp = UInt128._compare(remainder, divisor &- remainder)
        let roundAway =
            switch roundingMode {
            case .down: isNegative
            case .up: !isNegative
            case .plain: cmp != .orderedAscending
            case .bankers: cmp == .orderedDescending || (cmp == .orderedSame && (significand & 1) == 1)
            @unknown default: fatalError("Not implemented") //TODO: Determine a consistent sensible behavior for unknown rounding mode.
            }
        if roundAway {
            if significand == .max {
                return (34028236692093846346337460743176821146, 1) // See above.
            }
            return (significand &+ 1, 0)
        }
        return (significand, 0)
    }
}
