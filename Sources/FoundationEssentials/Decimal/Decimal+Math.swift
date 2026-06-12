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

private extension UInt128 {
    @inline(__always)
    static func _compare(_ lhs: Self, _ rhs: Self) -> ComparisonResult {
        if lhs == rhs { return .orderedSame }
        if lhs < rhs { return .orderedAscending }
        return .orderedDescending
    }
    
    @inline(__always)
    func _multipliedFullWidth(by1e exponent: Int) -> (high: Self, low: Self) {
        if exponent <= 19 && self <= 18446744073709551615 /* UInt64.max */ {
            let (hi, lo) = UInt64(truncatingIfNeeded: self)
                .multipliedFullWidth(by: UInt64(truncatingIfNeeded: _pow10[exponent]))
            return (0, UInt128(truncatingIfNeeded: hi) &<< 64 | UInt128(truncatingIfNeeded: lo))
        }
        return self.multipliedFullWidth(by: _pow10[exponent])
    }

    // Division by constant integer using multiplication and shift (cf. Granlund and Montgomery, 1991).
    @inline(__always)
    func _quotientAndRemainderDividingBy10() -> (quotient: Self, remainder: Self) {
        let m = 0xCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCD as UInt128
        let q = self.multipliedFullWidth(by: m).high &>> 3
        let r = self &- q &* 10
        return (q, r)
    }

    @inline(__always)
    func _quotientAndRemainderDividingBy10000() -> (quotient: Self, remainder: Self) {
        let m = 0xD1B71758E219652BD3C36113404EA4A9 as UInt128
        let q = self.multipliedFullWidth(by: m).high &>> 13
        let r = self &- q &* 10000
        return (q, r)
    }

    // Full-width division of `(high * 2**128 + low)` by a constant divisor,
    // using a single step of schoolbook short division in base `2**128` (cf. Knuth exercise 4.3.1-16).
    @inline(__always)
    static func _10DividingFullWidth(
        _ dividend: (high: Self, low: Self)
    ) -> (quotient: Self, remainder: Self) {
        assert(dividend.high < 10) // ...or else the result would overflow `UInt128`.

        // Since base `2**128` is not a multiple of the divisor `d`,
        // which in this case is 10, we split the base into `q1 * d + r1`.
        let (q1, r1): (UInt128, UInt128) = (34028236692093846346337460743176821145, 6) // (2**128 / 10, 2**128 % 10)

        // Substituting, the dividend becomes `high * (q1 * d + r1) + low`. Rearranging, `d * (high * q1) + (high * r1 + low)`.
        // The result of full-width flooring division by `d` is then `(high * q1) + ⌊ (high * r1 + low) / d ⌋`,
        // and the remainder is `(high * r1 + low) % d`.
        //
        // Compute `high * r1 + low`, which may overflow by a single carry bit
        // (`high * r1` itself can't overflow because `high < d` and `r1 < d` and `d * d < UInt128.max`):
        let (sum_, carry_) = dividend.low.addingReportingOverflow(dividend.high &* r1)
        let carry: UInt128 = carry_ ? 1 : 0
        // Compute `⌊ (high * r1 + low) / d ⌋` and `(high * r1 + low) % d`.
        // When there's been a carry, we again use the identity `2**128 = q1 * d + r1`, giving us:
        // `(high * r1 + low) / d = (sum_ + 2**128) / d = (sum_ + q1 * d + r1) / d = (sum_ + r1) / d + q1`.
        // That is, we need to add `carry * r1` to the value to be divided by `d`...
        let (q2, r2) = (sum_ &+ carry &* r1)._quotientAndRemainderDividingBy10()
        // ...and we need to add `carry * q1` to the final quotient.
        return (dividend.high &* q1 &+ carry &* q1 &+ q2, r2)
    }

    @inline(__always)
    static func _10000DividingFullWidth(
        _ dividend: (high: Self, low: Self)
    ) -> (quotient: Self, remainder: Self) {
        assert(dividend.high < 10000)
        let (q1, r1): (UInt128, UInt128) = (34028236692093846346337460743176821, 1456) // (2**128 / 10000, 2**128 % 10000)
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
        if a._exponent == b._exponent {
            if a._isNegative == b._isNegative {
                let (sum, carry) = a._significand.addingReportingOverflow(b._significand)
                if !carry {
                    var result = a
                    result._significand = sum
                    result._isCompact = 0
                    result.compact()
                    return (result, false)
                }
                let (result, inexact) = try Self._assemble(
                    isNegative: a._isNegative != 0,
                    significand: (1, sum),
                    exponent: a._exponent,
                    roundingMode: roundingMode)
                return (result, inexact)
            } else {
                if a._significand == b._significand {
                    return (.zero, false)
                }
                if a._significand < b._significand {
                    swap(&a, &b)
                }
                var result = a
                result._significand -= b._significand
                result._isCompact = 0
                result.compact()
                return (result, false)
            }
        }
        if a._exponent < b._exponent { swap(&a, &b) }

        let commonExponent = max(b._exponent, a._exponent - 38)
        let shift = (a: Int(a._exponent - commonExponent), b: Int(commonExponent - b._exponent))

        var (hi, lo) = a._significand._multipliedFullWidth(by1e: shift.a)
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
            // Same sign: add magnitudes.
            isNegative = a._isNegative
            let carry: Bool
            (lo, carry) = lo.addingReportingOverflow(q)
            if carry { hi &+= 1 }
        } else if hi != 0 || lo > q {
            // Opposite sign, |a| > |b|.
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
            // Opposite sign, |b| >= |a|.
            isNegative = b._isNegative
            lo = q - lo
        }

        let (result, inexact) = try Self._assemble(
            isNegative: isNegative != 0,
            significand: (hi, lo),
            tail: (r, divisor),
            exponent: commonExponent,
            roundingMode: roundingMode)
        return (result, inexact)
    }

    internal func _add(_ amount: UInt16) throws -> Decimal {
        let (sum, carry) = self._significand.addingReportingOverflow(UInt128(amount))
        if carry { throw _CalculationError.overflow }
        var result = self
        result._significand = sum
        return result
    }

    internal func _subtractReportingInexact(
        rhs: Decimal,
        roundingMode: RoundingMode
    ) throws -> (result: Decimal, inexact: Bool) {
        var right = rhs
        if right._length != 0 {
            right._isNegative ^= 1
        }
        let (result, inexact) = try self._add(
            rhs: right,
            roundingMode: roundingMode
        )
        return (result, inexact)
    }

    internal func _subtract(
        rhs: Decimal,
        roundingMode: RoundingMode
    ) throws -> Decimal {
        return try self._subtractReportingInexact(
            rhs: rhs,
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

    internal func _multiplyReportingInexact(
        by multiplicand: Decimal,
        roundingMode: RoundingMode
    ) throws -> (result: Decimal, inexact: Bool) {
        if self.isNaN || multiplicand.isNaN {
            throw _CalculationError.overflow
        }
        if self._length == 0 || multiplicand._length == 0 {
            return (.zero, false)
        }
        let product: (high: UInt128, low: UInt128)
        if self._length <= 4 && multiplicand._length <= 4 {
            let (hi, lo) = UInt64(truncatingIfNeeded: self._significand)
                .multipliedFullWidth(by: UInt64(truncatingIfNeeded: multiplicand._significand))
            product = (0, UInt128(truncatingIfNeeded: hi) &<< 64 | UInt128(truncatingIfNeeded: lo))
        } else {
            product = self._significand.multipliedFullWidth(by: multiplicand._significand)
        }
        return try Self._assemble(
            isNegative: self._isNegative != multiplicand._isNegative,
            significand: product,
            exponent: self._exponent + multiplicand._exponent,
            roundingMode: roundingMode)
    }

    internal func _multiply(
        by multiplicand: Decimal,
        roundingMode: RoundingMode
    ) throws -> Decimal {
        return try self._multiplyReportingInexact(
            by: multiplicand,
            roundingMode: roundingMode
        ).result
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

    internal func _divideReportingInexact(
        by divisor: Decimal,
        roundingMode: RoundingMode
    ) throws -> (result: Decimal, inexact: Bool) {
        guard !self.isNaN && !divisor.isNaN else {
            throw _CalculationError.overflow
        }
        guard divisor._length > 0 else {
            throw _CalculationError.divideByZero
        }
        if self._length == 0 {
            return (.zero, false)
        }

        let isNegative = self._isNegative != divisor._isNegative
        let dm = divisor._significand // Nonzero.
        // Power-of-ten divisor.
        if dm == 1 {
            return try Self._assemble(
                isNegative: isNegative,
                significand: (0, self._significand),
                exponent: self._exponent - divisor._exponent,
                roundingMode: roundingMode)
        }
        // Scale dividend significand maximally for quotient precision.
        let sm = self._significand
        // Deliberately underestimate the max "headroom" for scaling up,
        // using 1233/4096 as a close approximation of 1/log2(10) -- cf. Hacker's Delight, ch. 11.
        var shift = ((sm|1).leadingZeroBitCount &* 1233) &>> 12
        var scaled = sm * _pow10[shift]
        // Top up our estimate, if needed.
        if scaled <= 34028236692093846346337460743176821145 /* UInt128.max / 10 */ {
            shift &+= 1
            scaled &*= 10
        }
        let (hi, lo) = scaled.multipliedFullWidth(by: _pow10[38])
        let (q1, r1) = hi.quotientAndRemainder(dividingBy: dm)
        let (q2, r2) = dm.dividingFullWidth((r1, lo))
        return try Self._assemble(
            isNegative: isNegative,
            significand: (q1, q2),
            tail: (r2, dm),
            exponent: self._exponent - divisor._exponent - Int32(shift) - 38,
            roundingMode: roundingMode)
    }

    internal func _divide(
        by divisor: Decimal,
        roundingMode: RoundingMode
    ) throws -> Decimal {
        return try self._divideReportingInexact(
            by: divisor,
            roundingMode: roundingMode
        ).result
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

        // Compare nonzero magnitudes.
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
                let (high, low) = rhs._significand._multipliedFullWidth(by1e: diffExp)
                result = (high != 0) ? .orderedAscending : UInt128._compare(lhs._significand, low)
            }
        } else {
            // `lhs` has the larger exponent.
            if diffExp >= 39 {
                result = .orderedDescending
            } else {
                let (high, low) = lhs._significand._multipliedFullWidth(by1e: diffExp)
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

    // We're keeping the signature (for now at least), but this function doesn't throw.
    internal static func _normalize(
        a: inout Decimal,
        b: inout Decimal,
        roundingMode: RoundingMode
    ) throws -> Bool {
        let diffExp = Int(a._exponent - b._exponent)
        // If the two numbers share the same exponents,
        // the normalization is already done
        if diffExp == 0 {
            return false
        }
        if a._length == 0 {
            a._exponent = b._exponent
            a._isCompact = 0
            // Don't compact.
            return false
        }
        if b._length == 0 {
            b._exponent = a._exponent
            b._isCompact = 0
            // Don't compact.
            return false
        }

        func __normalize(
            large: inout Decimal,
            small: inout Decimal,
            diffExp: Int,
            roundingMode: RoundingMode
        ) -> Bool {
            let lm = large._significand
            if diffExp <= 38 {
                let (hi, lo) = lm._multipliedFullWidth(by1e: diffExp)
                if hi == 0 {
                    large._significand = lo
                    large._exponent = small._exponent
                    large._isCompact = 0
                    // Don't compact.
                    return false // Exact.
                }
            }
            // Deliberately underestimate the max "headroom" for scaling up the significand of the value with larger exponent,
            // using 1233/4096 as a close approximation of 1/log2(10)--cf. Hacker's Delight, ch. 11.
            var shift1 = ((lm|1).leadingZeroBitCount &* 1233) &>> 12
            var scaled = lm * _pow10[shift1]
            // Top up our estimate, if needed.
            if scaled <= 34028236692093846346337460743176821145 /* UInt128.max / 10 */ {
                shift1 &+= 1
                scaled &*= 10
            }
            large._significand = scaled
            large._exponent -= Int32(shift1)
            large._isCompact = 0
            // Don't compact.

            let shift2 = diffExp - shift1
            let divisor: UInt128
            var q: UInt128
            let r: UInt128
            if shift2 < 39 {
                divisor = _pow10[shift2]
                (q, r) = small._significand.quotientAndRemainder(dividingBy: divisor)
            } else {
                // A nonzero proxy value under 0.5 ulp.
                divisor = 10
                (q, r) = (0, 1)
            }
            if r != 0 && _roundAway(
                isNegative: small._isNegative != 0,
                isSignificandOdd: (q & 1) != 0,
                tail: (r, divisor),
                roundingMode: roundingMode
            ) {
                q &+= 1
            }
            small._significand = q
            if q == 0 { small._isNegative = 0 }
            small._exponent += Int32(shift2)
            small._isCompact = 0
            // Don't compact.
            return r != 0
        }

        if diffExp < 0 {
            return __normalize(large: &b, small: &a, diffExp: -diffExp, roundingMode: roundingMode)
        }
        return __normalize(large: &a, small: &b, diffExp: diffExp, roundingMode: roundingMode)
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
        var changed = false
        var exponent = self._exponent
        while (significand & 15) == 0 {
            let (q, r) = significand._quotientAndRemainderDividingBy10000()
            if r != 0 { break }
            significand = q
            exponent += 4
            changed = true
        }
        while (significand & 1) == 0 {
            let (q, r) = significand._quotientAndRemainderDividingBy10()
            if r != 0 { break }
            significand = q
            exponent += 1
            changed = true
        }
        if changed {
            // Regrow if the exponent is beyond range.
            while exponent > Int8.max {
                significand &*= 10
                exponent &-= 1
            }
            self._significand = significand
            self._exponent = exponent
        }
        // Mark the value as compact.
        self._isCompact = 1
    }

    internal func _round(
        scale: Int,
        roundingMode: RoundingMode
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

// MARK: - Significand Rounding, etc.
extension Decimal {
    private static func _roundAway(
        isNegative: Bool,
        isSignificandOdd: Bool,
        tail: (numerator: UInt128, denominator: UInt128),
        roundingMode: RoundingMode
    ) -> Bool {
        let cmp = UInt128._compare(tail.numerator, tail.denominator - tail.numerator)
        switch roundingMode {
        case .down:
            return isNegative
        case .up:
            return !isNegative
        case .bankers:
            return cmp == .orderedDescending || (cmp == .orderedSame && isSignificandOdd)
        case .plain:
            fallthrough
        @unknown default:
            return cmp != .orderedAscending
        }
    }

    private static func _assemble(
        isNegative: Bool,
        significand: (high: UInt128, low: UInt128),
        tail: (numerator: UInt128, denominator: UInt128) = (0, 1),
        exponent: Int32,
        minExponent: Int32 = -128,
        roundingMode: RoundingMode
    ) throws -> (result: Decimal, inexact: Bool) {
        if significand == (0, 0) && tail.numerator == 0 {
            return (.zero, false)
        }

        var (high, low) = significand
        var exponent = exponent
        var roundDigits = 0 as UInt128
        var sticky = tail.numerator != 0
        var shifted = false
        var underflowed = false

        // Fit significand in 128 bits.
        while high >= 10000 {
            if roundDigits != 0 { sticky = true }
            let (q1, r1) = high._quotientAndRemainderDividingBy10000()
            let (q2, r2) = UInt128._10000DividingFullWidth((r1, low))
            high = q1
            low = q2
            roundDigits = r2
            exponent += 4
            shifted = true
        }
        while high != 0 {
            if roundDigits != 0 { sticky = true }
            let (q1, r1) = high._quotientAndRemainderDividingBy10()
            let (q2, r2) = UInt128._10DividingFullWidth((r1, low))
            high = q1
            low = q2
            roundDigits = r2
            exponent += 1
            shifted = true
        }

        // Shrink significand further, if necessary, so that `exponent >= minExponent`.
        // This step and the regrowing step below are obviously mutually exclusive.
        if exponent < minExponent {
            var k = minExponent - exponent
            while k > 4 {
                if roundDigits != 0 { sticky = true }
                (low, roundDigits) = low._quotientAndRemainderDividingBy10000()
                exponent += 4
                k -= 4
            }
            while k > 0 {
                if roundDigits != 0 { sticky = true }
                (low, roundDigits) = low._quotientAndRemainderDividingBy10()
                exponent += 1
                k -= 1
            }
            shifted = true
            underflowed = true
        }
        assert(roundDigits < 10)

        // Round.
        var inexact = false
        if shifted {
            if sticky && (roundDigits == 0 || roundDigits == 5) {
                // Nudge `roundDigits` to break ties.
                roundDigits += 1
            }
            if roundDigits != 0 {
                inexact = true
                if _roundAway(
                    isNegative: isNegative,
                    isSignificandOdd: (low & 1) != 0,
                    tail: (roundDigits, 10),
                    roundingMode: roundingMode
                ) {
                    if low == .max {
                        low = 34028236692093846346337460743176821146 // 2**128 / 10, rounded away.
                        exponent += 1
                    } else {
                        low += 1
                    }
                }
            }
        } else if sticky {
            inexact = true
            if _roundAway(
                isNegative: isNegative,
                isSignificandOdd: (low & 1) != 0,
                tail: tail,
                roundingMode: roundingMode
            ) {
                if low == .max {
                    low = 34028236692093846346337460743176821146 // 2**128 / 10, rounded away.
                    exponent += 1
                } else {
                    low += 1
                }
            }
        }

        // Handle zero, distinguishing flush-to-zero underflow from rounding to zero.
        if low == 0 {
            if underflowed { throw _CalculationError.underflow }
            return (.zero, inexact)
        }

        // Regrow significand, if necessary, so that `exponent <= maxExponent`.
        while exponent > 127 /* maxExponent */ {
            if low > 34028236692093846346337460743176821145 /* UInt128.max / 10 */ {
                throw _CalculationError.overflow
            }
            low *= 10
            exponent -= 1
        }

        var result = Decimal()
        result._significand = low
        result._isNegative = isNegative ? 1 : 0
        result._exponent = exponent
        result._isCompact = 0
        result.compact()
        return (result, inexact)
    }
}
