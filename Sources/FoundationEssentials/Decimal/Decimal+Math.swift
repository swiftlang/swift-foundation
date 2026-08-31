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
#elseif os(Emscripten)
@preconcurrency import EmscriptenLibc
#endif

internal let _uint128_pow10: [39 of UInt128] = [
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
    
    @inline(__always)
    internal func _multipliedFullWidth(by1e exponent: Int) -> (high: Self, low: Self) {
        if exponent <= 19 && self <= 18446744073709551615 /* UInt64.max */ {
            let (hi, lo) = UInt64(truncatingIfNeeded: self)
                .multipliedFullWidth(by: UInt64(truncatingIfNeeded: _uint128_pow10[exponent]))
            return (0, UInt128(truncatingIfNeeded: hi) &<< 64 | UInt128(truncatingIfNeeded: lo))
        }
        return self.multipliedFullWidth(by: _uint128_pow10[exponent])
    }

    // Division by constant integer using multiplication and shift (cf. Granlund and Montgomery, 1994).
    @inline(__always)
    internal func _quotientAndRemainder(
        dividingBy1e exponent: Int
    ) -> (quotient: Self, remainder: Self) {
        let (multiplier, shift): (UInt128, Int) = switch exponent {
        case  1: (0xCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCD,  2)
        case  2: (0xA3D70A3D70A3D70A3D70A3D70A3D70A4,  4)
        case  3: (0x83126E978D4FDF3B645A1CAC083126EA,  6)
        case  4: (0xD1B71758E219652BD3C36113404EA4A9,  9)
        case  5: (0xA7C5AC471B4784230FCF80DC33721D54, 11)
        case  6: (0x8637BD05AF6C69B5A63F9A49C2C1B110, 13)
        case  7: (0xD6BF94D5E57A42BC3D32907604691B4D, 16)
        case  8: (0xABCC77118461CEFCFDC20D2B36BA7C3E, 18)
        case  9: (0x89705F4136B4A59731680A88F8953031, 20)
        case 10: (0xDBE6FECEBDEDD5BEB573440E5A884D1C, 23)
        case 11: (0xAFEBFF0BCB24AAFEF78F69A51539D749, 25)
        case 12: (0x8CBCCC096F5088CBF93F87B7442E45D4, 27)
        case 13: (0xE12E13424BB40E132865A5F206B06FBA, 30)
        case 14: (0xB424DC35095CD80F538484C19EF38C95, 32)
        case 15: (0x901D7CF73AB0ACD90F9D37014BF60A11, 34)
        case 16: (0xE69594BEC44DE15B4C2EBE687989A9B4, 37)
        case 17: (0xB877AA3236A4B44909BEFEB9FAD487C3, 39)
        case 18: (0x9392EE8E921D5D073AFF322E62439FD0, 41)
        case 19: (0xEC1E4A7DB69561A52B31E9E3D06C32E6, 44)
        case 20: (0xBCE5086492111AEA88F4BB1CA6BCF585, 46)
        case 21: (0x971DA05074DA7BEED3F6FC16EBCA5E04, 48)
        case 22: (0xF1C90080BAF72CB15324C68B12DD6339, 51)
        case 23: (0xC16D9A0095928A2775B7053C0F178294, 53)
        case 24: (0x9ABE14CD44753B52C4926A9672793543, 55)
        case 25: (0xF79687AED3EEC5513A83DDBD83F52205, 58)
        case 26: (0xC612062576589DDA95364AFE032A819E, 60)
        case 27: (0x9E74D1B791E07E48775EA264CF55347E, 62)
        case 28: (0xFD87B5F28300CA0D8BCA9D6E188853FD, 65)
        case 29: (0xCAD2F7F5359A3B3E096EE45813A04331, 67)
        case 30: (0xA2425FF75E14FC31A1258379A94D028E, 69)
        case 31: (0x81CEB32C4B43FCF480EACF948770CED8, 71)
        case 32: (0xCFB11EAD453994BA67DE18EDA5814AF3, 74)
        case 33: (0xA6274BBDD0FADD61ECB1AD8AEACDD58F, 76)
        case 34: (0x84EC3C97DA624AB4BD5AF13BEF0B113F, 78)
        case 35: (0xD4AD2DBFC3D07787955E4EC64B44E865, 81)
        case 36: (0xAA242499697392D2DDE50BD1D5D0B9EA, 83)
        case 37: (0x881CEA14545C75757E50D64177DA2E55, 85)
        case 38: (0xD9C7DCED53C7225596E7BD358C904A22, 88)
        default: preconditionFailure()
        }
        let q = (self &>> exponent).multipliedFullWidth(by: multiplier).high &>> shift
        let r = self &- q &* _uint128_pow10[exponent]
        return (q, r)
    }

    @inline(__always)
    internal static func _quotientAndRemainder(
        fullWidth dividend: (high: Self, low: Self),
        dividingBy1e exponent: Int
    ) -> (quotient: Self, remainder: Self) {
        assert(dividend.high < _uint128_pow10[exponent])

        // One round of short division in base `2**128` (cf. Knuth exercise 4.3.1-16).
        // Requires `e <= 19` and `high < 10**e`, s.t. `high * r1` overflows at most once.
        @inline(__always)
        func _divide(high: Self, low: Self, by1e e: Int) -> (Self, Self) {
            // Since base `2**128` is not a multiple of the divisor `10**e`,
            // we split the base into `q1 * d + r1`.
            let (q1, r1): (UInt128, UInt128) = switch e {
            case  1: (34028236692093846346337460743176821145, 6)
            case  2: (3402823669209384634633746074317682114, 56)
            case  3: (340282366920938463463374607431768211, 456)
            case  4: (34028236692093846346337460743176821, 1456)
            case  5: (3402823669209384634633746074317682, 11456)
            case  6: (340282366920938463463374607431768, 211456)
            case  7: (34028236692093846346337460743176, 8211456)
            case  8: (3402823669209384634633746074317, 68211456)
            case  9: (340282366920938463463374607431, 768211456)
            case 10: (34028236692093846346337460743, 1768211456)
            case 11: (3402823669209384634633746074, 31768211456)
            case 12: (340282366920938463463374607, 431768211456)
            case 13: (34028236692093846346337460, 7431768211456)
            case 14: (3402823669209384634633746,  7431768211456) // (sic)
            case 15: (340282366920938463463374, 607431768211456)
            case 16: (34028236692093846346337, 4607431768211456)
            case 17: (3402823669209384634633, 74607431768211456)
            case 18: (340282366920938463463, 374607431768211456)
            case 19: (34028236692093846346, 3374607431768211456)
            default: preconditionFailure()
            }
            // Substituting, the dividend becomes `high * (q1 * d + r1) + low`.
            // Rearranging, `d * (high * q1) + (high * r1 + low)`.
            //
            // The result of full-width flooring division by `d` is then
            // `(high * q1) + ⌊ (high * r1 + low) / d ⌋`, and the remainder is
            // `(high * r1 + low) % d`.
            //
            // Compute `high * r1 + low`, which may overflow by a carry bit
            // (`high * r1` itself can't overflow, since `high < d` and `r1 < d`
            // and `d * d < UInt128.max`):
            let (sum_, carry_) = low.addingReportingOverflow(high &* r1)
            let carry: UInt128 = carry_ ? 1 : 0
            // Compute `⌊ (high * r1 + low) / d ⌋` and `(high * r1 + low) % d`.
            // When there's been a carry, we again use the identity
            // `2**128 = q1 * d + r1`, giving us:
            //
            //     (high * r1 + low) / d = (sum_ + 2**128) / d = (sum_ + q1 * d + r1) / d = (sum_ + r1) / d + q1
            //
            // That is, we add `carry * r1` to the value to be divided by `d`...
            let (q2, r2) = (sum_ &+ carry &* r1)._quotientAndRemainder(dividingBy1e: e)
            // ...and we need to add `carry * q1` to the final quotient.
            return (high &* q1 &+ carry &* q1 &+ q2, r2)
        }

        if exponent <= 19 {
            return _divide(high: dividend.high, low: dividend.low, by1e: exponent)
        }
        // First divide by `10**19`, then by `10**(e - 19)`.
        let (q1, r1) = dividend.high._quotientAndRemainder(dividingBy1e: 19)
        let (q2, r2) = _divide(high: r1, low: dividend.low, by1e: 19)
        let (q3, r3) = _divide(high: q1, low: q2, by1e: exponent &- 19)
        return (q3, r3 &* 10_000_000_000_000_000_000 &+ r2)
    }

    // Exact division by a constant (cf. Granlund and Montgomery, 1994 §9).
    // See discussion on analogous `UInt64` extensions for more.
    @inline(__always)
    internal func _quotientIfExactDividingBy10() -> Self? {
        let m = 0xCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCD as UInt128 // Inverse of 5 (mod 2**128).
        let p = self &* m
        let q = p &>> 1 | p &<< 127
        guard q <= 34028236692093846346337460743176821145 /* UInt128.max / 10 */ else { return nil }
        return q
    }

    @inline(__always)
    internal func _quotientIfExactDividingBy100() -> Self? {
        let m = 0x28F5C28F5C28F5C28F5C28F5C28F5C29 as UInt128 // Inverse of 5**2 (mod 2**128).
        let p = self &* m
        let q = p &>> 2 | p &<< 126
        guard q <= 3402823669209384634633746074317682114 /* UInt128.max / 100 */ else { return nil }
        return q
    }

    @inline(__always)
    internal func _quotientIfExactDividingBy10000() -> Self? {
        let m = 0x495182A9930BE0DED288CE703AFB7E91 as UInt128 // Inverse of 5**4 (mod 2**128).
        let p = self &* m
        let q = p &>> 4 | p &<< 124
        guard q <= 34028236692093846346337460743176821 /* UInt128.max / 10**4 */ else { return nil }
        return q
    }

    @inline(__always)
    internal func _quotientIfExactDividingBy1e8() -> Self? {
        let m = 0xF36B7213EE9F5A78C767074B22E90E21 as UInt128 // Inverse of 5**8 (mod 2**128).
        let p = self &* m
        let q = p &>> 8 | p &<< 120
        guard q <= 3402823669209384634633746074317 /* UInt128.max / 10**8 */ else { return nil }
        return q
    }

    @inline(__always)
    internal func _quotientIfExactDividingBy1e16() -> Self? {
        let m = 0xF60B3275305C1066E4A4D1417CD9A041 as UInt128 // Inverse of 5**16 (mod 2**128).
        let p = self &* m
        let q = p &>> 16 | p &<< 112
        guard q <= 34028236692093846346337 /* UInt128.max / 10**16 */ else { return nil }
        return q
    }

    @inline(__always)
    internal func _quotientIfExactDividingBy1e32() -> Self? {
        let m = 0x62B42691AD836EB116590F420A835081 as UInt128 // Inverse of 5**32 (mod 2**128).
        let p = self &* m
        let q = p &>> 32 | p &<< 96
        guard q <= 3402823 /* UInt128.max / 10**32 */ else { return nil }
        return q
    }
}

// MARK: - Mathematics
extension Decimal {
    internal static let maxSize: UInt32 = 8

    // The smallest exponent that mathematical operations produce by default.
    // If, by policy, it is greater than the storage floor (`Int8.min`), smaller
    // exponents are still accepted as inputs.
    internal static var _minExponent: Int32 {
        @inline(__always) get { -128 }
    }

    internal enum _CalculationError: Error {
        case overflow
        case underflow
        case divideByZero
    }

    internal func _addReportingInexact(
        rhs: Decimal,
        minExponent: Int32 = Self._minExponent,
        roundingMode: RoundingMode
    ) throws(_CalculationError) -> (result: Decimal, inexact: Bool) {
        if self.isNaN || rhs.isNaN {
            throw .overflow
        }
        if self._length == 0 {
            if minExponent <= rhs._exponent { return (rhs, false) }
            return try rhs._roundReportingInexact(
                minExponent: minExponent,
                roundingMode: roundingMode)
        }
        if rhs._length == 0 {
            if minExponent <= self._exponent { return (self, false) }
            return try self._roundReportingInexact(
                minExponent: minExponent,
                roundingMode: roundingMode)
        }

        var a = self
        var b = rhs
        if a._exponent == b._exponent {
            if a._isNegative == b._isNegative {
                let (sum, carry) = a._significand.addingReportingOverflow(b._significand)
                if !carry {
                    if sum == 0 {
                        // `sum` is nonzero unless `a` or `b` is malformed.
                        return (.zero, false)
                    }
                    var result = a
                    result._significand = sum
                    result._isCompact = 0
                    result.compact()
                    if minExponent <= a._exponent { return (result, false) }
                    return try result._roundReportingInexact(
                        minExponent: minExponent,
                        roundingMode: roundingMode)
                }
                return try Self._assemble(
                    isNegative: a._isNegative != 0,
                    significand: (1, sum),
                    exponent: a._exponent,
                    minExponent: minExponent,
                    roundingMode: roundingMode)
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
                if minExponent <= a._exponent { return (result, false) }
                return try result._roundReportingInexact(
                    minExponent: minExponent,
                    roundingMode: roundingMode)
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
            divisor = _uint128_pow10[shift.b]
            (q, r) = b._significand._quotientAndRemainder(dividingBy1e: shift.b)
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

        return try Self._assemble(
            isNegative: isNegative != 0,
            significand: (hi, lo),
            tail: (r, divisor),
            exponent: commonExponent,
            minExponent: minExponent,
            roundingMode: roundingMode)
    }

    internal func _add(
        rhs: Decimal,
        minExponent: Int32 = Self._minExponent,
        roundingMode: RoundingMode
    ) throws(_CalculationError) -> Decimal {
        return try self._addReportingInexact(
            rhs: rhs,
            minExponent: minExponent,
            roundingMode: roundingMode
        ).result
    }

    internal func _subtractReportingInexact(
        rhs: Decimal,
        minExponent: Int32 = Self._minExponent,
        roundingMode: RoundingMode
    ) throws(_CalculationError) -> (result: Decimal, inexact: Bool) {
        var right = rhs
        if right._length != 0 {
            right._isNegative ^= 1
        }
        return try self._addReportingInexact(
            rhs: right,
            minExponent: minExponent,
            roundingMode: roundingMode)
    }

    internal func _subtract(
        rhs: Decimal,
        minExponent: Int32 = Self._minExponent,
        roundingMode: RoundingMode
    ) throws(_CalculationError) -> Decimal {
        return try self._subtractReportingInexact(
            rhs: rhs,
            minExponent: minExponent,
            roundingMode: roundingMode
        ).result
    }

    internal func _multiplyReportingInexact(
        by multiplicand: Decimal,
        minExponent: Int32 = Self._minExponent,
        roundingMode: RoundingMode
    ) throws(_CalculationError) -> (result: Decimal, inexact: Bool) {
        if self.isNaN || multiplicand.isNaN {
            throw .overflow
        }
        if self._length == 0 || multiplicand._length == 0 {
            return (.zero, false)
        }
        let product: (high: UInt128, low: UInt128)
        let lm = self._significand, rm = multiplicand._significand
        if lm <= 0xffff_ffff_ffff_ffff && rm <= 0xffff_ffff_ffff_ffff {
            let (hi, lo) = UInt64(truncatingIfNeeded: lm)
                .multipliedFullWidth(by: UInt64(truncatingIfNeeded: rm))
            product = (0, UInt128(truncatingIfNeeded: hi) &<< 64 | UInt128(truncatingIfNeeded: lo))
        } else {
            product = lm.multipliedFullWidth(by: rm)
        }
        return try Self._assemble(
            isNegative: self._isNegative != multiplicand._isNegative,
            significand: product,
            exponent: self._exponent + multiplicand._exponent,
            minExponent: minExponent,
            roundingMode: roundingMode)
    }

    internal func _multiply(
        by multiplicand: Decimal,
        minExponent: Int32 = Self._minExponent,
        roundingMode: RoundingMode
    ) throws(_CalculationError) -> Decimal {
        return try self._multiplyReportingInexact(
            by: multiplicand,
            minExponent: minExponent,
            roundingMode: roundingMode
        ).result
    }

    internal func _multiplyByPowerOfTenReportingInexact(
        power: Int,
        minExponent: Int32 = Self._minExponent,
        roundingMode: RoundingMode
    ) throws(_CalculationError) -> (result: Decimal, inexact: Bool) {
        if self.isNaN {
            throw .overflow
        }
        if self._length == 0 {
            return (.zero, false)
        }
        let power = min(max(power, -32768), 32767)
        let exponent = self._exponent + Int32(power)
        if exponent >= minExponent && exponent <= 127 {
            var result = self
            result._exponent = exponent
            result._isCompact = 0
            result.compact()
            return (result, false)
        }
        if exponent >= 166 {
            throw .overflow
        }
        return try Self._assemble(
            isNegative: self._isNegative != 0,
            significand: (0, self._significand),
            exponent: max(exponent, -167), // Clamp lower bound and reuse rounding logic.
            minExponent: minExponent,
            roundingMode: roundingMode)
    }

    internal func _multiplyByPowerOfTen(
        power: Int,
        minExponent: Int32 = Self._minExponent,
        roundingMode: RoundingMode
    ) throws(_CalculationError) -> Decimal {
        return try self._multiplyByPowerOfTenReportingInexact(
            power: power,
            minExponent: minExponent,
            roundingMode: roundingMode
        ).result
    }

    internal func _divideReportingInexact(
        by divisor: Decimal,
        minExponent: Int32 = Self._minExponent,
        roundingMode: RoundingMode
    ) throws(_CalculationError) -> (result: Decimal, inexact: Bool) {
        guard !self.isNaN && !divisor.isNaN else {
            throw .overflow
        }
        guard divisor._length > 0 else {
            throw .divideByZero
        }

        let dm = divisor._significand
        guard dm != 0 else {
            // `dm` is nonzero unless `divisor` is malformed.
            throw .divideByZero
        }
        if self._length == 0 {
            return (.zero, false)
        }

        let isNegative = self._isNegative != divisor._isNegative
        // Power-of-ten divisor.
        if dm == 1 {
            return try Self._assemble(
                isNegative: isNegative,
                significand: (0, self._significand),
                exponent: self._exponent - divisor._exponent,
                minExponent: minExponent,
                roundingMode: roundingMode)
        }
        // Scale dividend significand maximally for quotient precision.
        let sm = self._significand
        // Deliberately underestimate the max "headroom" for scaling up,
        // using 1233/4096 as a close approximation of 1/log2(10) -- cf. Hacker's Delight, ch. 11.
        var shift = ((sm|1).leadingZeroBitCount &* 1233) &>> 12
        var scaled = sm * _uint128_pow10[shift]
        // Top up our estimate, if needed.
        if scaled <= 34028236692093846346337460743176821145 /* UInt128.max / 10 */ {
            shift &+= 1
            scaled &*= 10
        }
        let (hi, lo) = scaled.multipliedFullWidth(by: 100_000_000_000_000_000_000_000_000_000_000_000_000)
        let (q1, r1) = hi.quotientAndRemainder(dividingBy: dm)
        let (q2, r2) = dm.dividingFullWidth((r1, lo))
        return try Self._assemble(
            isNegative: isNegative,
            significand: (q1, q2),
            tail: (r2, dm),
            exponent: self._exponent - divisor._exponent - Int32(shift) - 38,
            minExponent: minExponent,
            roundingMode: roundingMode)
    }

    internal func _divide(
        by divisor: Decimal,
        minExponent: Int32 = Self._minExponent,
        roundingMode: RoundingMode
    ) throws(_CalculationError) -> Decimal {
        return try self._divideReportingInexact(
            by: divisor,
            minExponent: minExponent,
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
                result = (rhs._significand != 0) // Nonzero unless `rhs` is malformed.
                    ? .orderedAscending
                    : (lhs._significand == 0 ? .orderedSame : .orderedDescending)
            } else {
                let (high, low) = rhs._significand._multipliedFullWidth(by1e: diffExp)
                result = (high != 0) ? .orderedAscending : UInt128._compare(lhs._significand, low)
            }
        } else {
            // `lhs` has the larger exponent.
            if diffExp >= 39 {
                result = (lhs._significand != 0) // Nonzero unless `lhs` is malformed.
                    ? .orderedDescending
                    : (rhs._significand == 0 ? .orderedSame : .orderedAscending)
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

    internal static func _normalize(
        a: inout Decimal,
        b: inout Decimal,
        roundingMode: RoundingMode
    ) -> Bool {
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
        if a._significand == 0 {
            // Malformed zero: set `_length` and `_isNegative`.
            a._length = 0
            a._isNegative = 0
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
        if b._significand == 0 {
            // Malformed zero: set `_length` and `_isNegative`.
            b._length = 0
            b._isNegative = 0
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
            var scaled = lm * _uint128_pow10[shift1]
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
                divisor = _uint128_pow10[shift2]
                (q, r) = small._significand._quotientAndRemainder(dividingBy1e: shift2)
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

        var significand = self._significand
        if significand == 0 {
            // This branch is not reachable except with malformed values, such as in the test case.
            self = .zero
            return
        }
        // Divide by 10 as much as possible.
        guard (significand & 1) == 0, let q = significand._quotientIfExactDividingBy10() else {
            self._isCompact = 1
            return
        }
        significand = q
        var exponent = self._exponent + 1
        if (significand & 0xFFFFFFFF) == 0, let q = significand._quotientIfExactDividingBy1e32() {
            significand = q
            exponent += 32
        }
        if (significand & 0xFFFF) == 0, let q = significand._quotientIfExactDividingBy1e16() {
            significand = q
            exponent += 16
        }
        if (significand & 0xFF) == 0, let q = significand._quotientIfExactDividingBy1e8() {
            significand = q
            exponent += 8
        }
        if (significand & 0xF) == 0, let q = significand._quotientIfExactDividingBy10000() {
            significand = q
            exponent += 4
        }
        if (significand & 0x3) == 0, let q = significand._quotientIfExactDividingBy100() {
            significand = q
            exponent += 2
        }
        if (significand & 0x1) == 0, let q = significand._quotientIfExactDividingBy10() {
            significand = q
            exponent += 1
        }
        // Regrow if the exponent is beyond range.
        if exponent > 127 /* Int8.max */ {
            significand *= _uint128_pow10[Int(exponent - 127)]
            exponent = 127
        }
        self._significand = significand
        self._exponent = exponent
        // Mark the value as compact.
        self._isCompact = 1
    }

    internal var _isActuallyCompact: Bool {
        @inline(__always)
        get {
            // `compact()` never sets `_isCompact` when `_length == 0`.
            if _length == 0 { return false }
            if (_mantissa.0 & 1) != 0 { return true }
            let significand = _significand
            // `compact()` rewrites values with zero significand to `.zero`.
            if significand == 0 { return false }
            if significand._quotientIfExactDividingBy10() == nil { return true }
            return _exponent == 127
        }
    }

    internal func _roundReportingInexact(
        minExponent: Int32 = Self._minExponent,
        roundingMode: RoundingMode
    ) throws(_CalculationError) -> (result: Decimal, inexact: Bool) {
        if self._length == 0 {
            return (self, false)
        }
        if minExponent <= self._exponent {
            return (self, false)
        }
        let shift = Int(minExponent - self._exponent)
        let divisor: UInt128
        let (q, r): (UInt128, UInt128)
        if shift < 39 {
            divisor = _uint128_pow10[shift]
            (q, r) = self._significand._quotientAndRemainder(dividingBy1e: shift)
        } else {
            // A nonzero proxy value under 0.5 ulp.
            divisor = 10
            (q, r) = (0, 1)
        }
        return try Self._assemble(
            isNegative: self._isNegative != 0,
            significand: (0, q),
            tail: (r, divisor),
            exponent: minExponent,
            roundingMode: roundingMode)
    }

    internal func _round(
        scale: Int,
        roundingMode: RoundingMode
    ) throws(_CalculationError) -> Decimal {
        let scale = min(max(scale, -32768), 32767)
        return try _roundReportingInexact(
            minExponent: Int32(-scale),
            roundingMode: roundingMode
        ).result
    }
}

// MARK: - Numeric Values
private extension Decimal {
    func _truncatingMagnitude() -> (result: Decimal, inexact: Bool) {
        if self._length == 0 {
            return (.zero, false)
        }
        let e = self._exponent
        var result = self
        if e >= 0 {
            result._isNegative = 0
            return (result, false)
        }
        if e <= -39 {
            return (.zero, self._significand != 0)
        }
        let r: UInt128
        (result._significand, r) =
            self._significand._quotientAndRemainder(dividingBy1e: -Int(e))
        result._exponent = 0
        result._isNegative = 0
        result._isCompact = 0
        // Don't compact.
        return (result, r != 0)
    }
}

extension FixedWidthInteger {
    // Dual of `Decimal.init?<T: BinaryInteger>(exactly:)`.
    internal static func _convert(from value: Decimal) -> (value: Self?, inexact: Bool) {
        if value.isNaN {
            return (nil, false)
        }
        let (truncated, inexact) = value._truncatingMagnitude()
        let isNegative = (value._isNegative != 0)
        guard Self.isSigned || !isNegative else {
            // A negative value isn't representable as an unsigned integer,
            // *unless* the integer part is zero.
            return (truncated.isZero ? 0 : nil, inexact)
        }
        guard var magnitude = Magnitude(exactly: truncated._significand) else {
            return (nil, inexact)
        }
        var scale = Int(truncated._exponent)
        while scale > 0 {
            let x = Swift.min(scale, 38)
            guard let multiplier = Magnitude(exactly: _uint128_pow10[x]) else {
                return (nil, inexact)
            }
            guard case (let product, false) = magnitude.multipliedReportingOverflow(by: multiplier) else {
                return (nil, inexact)
            }
            magnitude = product
            scale &-= x
        }
        if let magnitude_ = Self(exactly: magnitude) {
            return (isNegative ? 0 - magnitude_ : magnitude_, inexact)
        } else if isNegative && magnitude == Self.min.magnitude {
            return (Self.min, inexact)
        }
        return (nil, inexact)
    }

    internal init(_ source: Decimal) {
        // Truncating conversion, trapping if out of range or NaN.
        guard let value = Self._convert(from: source).value else {
            preconditionFailure("Decimal value cannot be converted to \(Self.self): out of range or NaN")
        }
        self = value
    }

    internal init?(exactly source: Decimal) {
        // Exact conversion, nil if inexact, out of range, or NaN.
        guard case (let value?, false) = Self._convert(from: source) else {
            return nil
        }
        self = value
    }
}

// Note: Methods for conversion to integer types in the following extension are
// preserved for their quirks--they exhibit unspecified behavior for some inputs
// and aren't performant.
extension Decimal {
    private func _multiply(byShort multiplicand: UInt16) throws -> Decimal {
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

    private func _divide(by divisor: UInt16) throws -> (result: Decimal, remainder: UInt16) {
        guard divisor != 0 else { throw _CalculationError.divideByZero }
        let (q, r) = self._significand.quotientAndRemainder(dividingBy: UInt128(divisor))
        var result = self
        result._significand = q
        return (result, UInt16(r))
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

    internal static func _assemble(
        isNegative: Bool,
        significand: (high: UInt128, low: UInt128),
        tail: (numerator: UInt128, denominator: UInt128) = (0, 1),
        exponent: Int32,
        minExponent: Int32 = Self._minExponent,
        roundingMode: RoundingMode
    ) throws(_CalculationError) -> (result: Decimal, inexact: Bool) {
        if significand == (0, 0) && tail.numerator == 0 {
            return (.zero, false)
        }

        var (high, low) = significand
        var exponent = exponent
        var round = 0 as UInt128
        var sticky = tail.numerator != 0
        var shifted = false
        var underflowed = false

        // Fit significand in 128 bits.
        if high != 0 {
            // Use a deliberate underestimate of the decimal digit count of `high`,
            // using 19/64 as a close (but not too close!) approximation of 1/log2(10).
            //
            // See:
            // - Hacker's Delight, ch. 11
            // - https://lemire.me/blog/2021/05/28/computing-the-number-of-digits-of-an-integer-quickly/
            //
            // A rational approximation `a / b` is too close if `⌊ 127 * a / b ⌋ == 38`
            // because attempts to compute `10 ** (38 + 1)` result in overflow.
            // But an approximation is not close enough if (as is the case with 9/32)
            // it'd result in underestimation of the true digit count by more than 1.
            let estimate = (((127 &- (high|1).leadingZeroBitCount) &* 19) &>> 6) &+ 1

            let (q1, r1) = high._quotientAndRemainder(dividingBy1e: estimate)
            let (q2, r2) = UInt128._quotientAndRemainder(
                fullWidth: (r1, low), dividingBy1e: estimate)
            if q1 != 0 {
                if r2 != 0 { sticky = true }
                // Correct for underestimation.
                (low, round) = UInt128._quotientAndRemainder(
                    fullWidth: (q1, q2), dividingBy1e: 1)
                exponent += Int32(estimate &+ 1)
            } else {
                if estimate == 1 {
                    (low, round) = (q2, r2)
                } else {
                    low = q2
                    let r3: UInt128
                    (round, r3) = r2._quotientAndRemainder(
                        dividingBy1e: estimate &- 1)
                    if r3 != 0 { sticky = true }
                }
                exponent += Int32(estimate)
            }
            high = 0
            shifted = true
        }

        // Shrink significand further, if necessary, so that `exponent >= minExponent`.
        // This step and the regrowing step below are obviously mutually exclusive.
        if exponent < minExponent {
            if round != 0 { sticky = true }
            let k = Int(minExponent - exponent)
            if k > 39 {
                if low != 0 { sticky = true }
                (low, round) = (0, 0)
            } else {
                if k == 1 {
                    (low, round) = low._quotientAndRemainder(dividingBy1e: 1)
                } else {
                    let (q, r) = low._quotientAndRemainder(
                        dividingBy1e: k &- 1)
                    if r != 0 { sticky = true }
                    (low, round) = q._quotientAndRemainder(dividingBy1e: 1)
                }
            }
            exponent = minExponent
            shifted = true
            underflowed = (minExponent <= Self._minExponent)
        }

        // Round.
        var inexact = false
        if shifted {
            // Double `round`; nudge to break ties if `sticky`.
            round = (round &<< 1) | (sticky ? 1 : 0)
            if round != 0 {
                inexact = true
                if _roundAway(
                    isNegative: isNegative,
                    isSignificandOdd: (low & 1) != 0,
                    tail: (round, 20),
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
            if underflowed { throw .underflow }
            return (.zero, inexact)
        }

        // Regrow significand, if necessary, so that `exponent <= maxExponent`.
        if exponent > 127 /* maxExponent */ {
            let k = Int(exponent - 127)
            // Deliberately underestimate the max "headroom" for scaling up,
            // using 1233/4096 as a close approximation of 1/log2(10) -- cf. Hacker's Delight, ch. 11.
            let shift = ((low|1).leadingZeroBitCount &* 1233) &>> 12
            if k <= shift {
                low &*= _uint128_pow10[k]
            } else if k == shift &+ 1 {
                low &*= _uint128_pow10[shift]
                if low > 34028236692093846346337460743176821145 /* UInt128.max / 10 */ {
                    throw .overflow
                }
                low &*= 10
            } else {
                throw .overflow
            }
            exponent = 127
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
