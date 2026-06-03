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

private let powerOfTen: [Decimal.VariableLengthInteger] = [
    /*^00*/ [0x0001],
    /*^01*/ [0x000a],
    /*^02*/ [0x0064],
    /*^03*/ [0x03e8],
    /*^04*/ [0x2710],
    /*^05*/ [0x86a0, 0x0001],
    /*^06*/ [0x4240, 0x000f],
    /*^07*/ [0x9680, 0x0098],
    /*^08*/ [0xe100, 0x05f5],
    /*^09*/ [0xca00, 0x3b9a],
    /*^10*/ [0xe400, 0x540b, 0x0002],
    /*^11*/ [0xe800, 0x4876, 0x0017],
    /*^12*/ [0x1000, 0xd4a5, 0x00e8],
    /*^13*/ [0xa000, 0x4e72, 0x0918],
    /*^14*/ [0x4000, 0x107a, 0x5af3],
    /*^15*/ [0x8000, 0xa4c6, 0x8d7e, 0x0003],
    /*^16*/ [0x0000, 0x6fc1, 0x86f2, 0x0023],
    /*^17*/ [0x0000, 0x5d8a, 0x4578, 0x0163],
    /*^18*/ [0x0000, 0xa764, 0xb6b3, 0x0de0],
    /*^19*/ [0x0000, 0x89e8, 0x2304, 0x8ac7],
    /*^20*/ [0x0000, 0x6310, 0x5e2d, 0x6bc7, 0x0005],
    /*^21*/ [0x0000, 0xdea0, 0xadc5, 0x35c9, 0x0036],
    /*^22*/ [0x0000, 0xb240, 0xc9ba, 0x19e0, 0x021e],
    /*^23*/ [0x0000, 0xf680, 0xe14a, 0x02c7, 0x152d],
    /*^24*/ [0x0000, 0xa100, 0xcced, 0x1bce, 0xd3c2],
    /*^25*/ [0x0000, 0x4a00, 0x0148, 0x1614, 0x4595, 0x0008],
    /*^26*/ [0x0000, 0xe400, 0x0cd2, 0xdcc8, 0xb7d2, 0x0052],
    /*^27*/ [0x0000, 0xe800, 0x803c, 0x9fd0, 0x2e3c, 0x033b],
    /*^28*/ [0x0000, 0x1000, 0x0261, 0x3e25, 0xce5e, 0x204f],
    /*^29*/ [0x0000, 0xa000, 0x17ca, 0x6d72, 0x0fae, 0x431e, 0x0001],
    /*^30*/ [0x0000, 0x4000, 0xedea, 0x4674, 0x9cd0, 0x9f2c, 0x000c],
    /*^31*/ [0x0000, 0x8000, 0x4b26, 0xc091, 0x2022, 0x37be, 0x007e],
    /*^32*/ [0x0000, 0x0000, 0xef81, 0x85ac, 0x415b, 0x2d6d, 0x04ee],
    /*^33*/ [0x0000, 0x0000, 0x5b0a, 0x38c1, 0x8d93, 0xc644, 0x314d],
    /*^34*/ [0x0000, 0x0000, 0x8e64, 0x378d, 0x87c0, 0xbead, 0xed09, 0x0001],
    /*^35*/ [0x0000, 0x0000, 0x8fe8, 0x2b87, 0x4d82, 0x72c7, 0x4261, 0x0013],
    /*^36*/ [0x0000, 0x0000, 0x9f10, 0xb34b, 0x0715, 0x7bc9, 0x97ce, 0x00c0],
    /*^37*/ [0x0000, 0x0000, 0x36a0, 0x00f4, 0x46d9, 0xd5da, 0xee10, 0x0785],
    /*^38*/ [0x0000, 0x0000, 0x2240, 0x098a, 0xc47a, 0x5a86, 0x4ca8, 0x4b3b],
]

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
}

// MARK: - Mathmatics
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
        var lossOfPrecision = try Decimal._normalize(a: &a, b: &b, roundingMode: roundingMode)
        //TODO: Review how `_normalize` determines `lossOfPrecision` and standardize semantics so that it's only `true` when nonzero figures are actually discarded.
        if a._length == 0 {
            return (result: b, lossOfPrecision: lossOfPrecision)
        }
        if b._length == 0 {
            return (result: a, lossOfPrecision: lossOfPrecision)
        }
        var result = a
        if a._isNegative == b._isNegative {
            result._isNegative = a._isNegative
            let (sum, carry) = a._significand.addingReportingOverflow(b._significand)
            if !carry {
                result._significand = sum
            } else {
                var (fitted, remainder) = (10 as UInt128).dividingFullWidth((1, sum))
                if remainder != 0 { lossOfPrecision = true }
                // We've never actually supported non-default rounding modes; so let's not pretend.
                // guard roundingMode == .plain else { fatalError("Not implemented") }
                if remainder >= 5 { fitted += 1 }
                if result._exponent + 1 > Int8.max { throw _CalculationError.overflow }
                result._exponent += 1
                result._significand = fitted
            }
        } else {
            let am = a._significand, bm = b._significand
            if am == bm {
                return (result: .zero, lossOfPrecision: lossOfPrecision)
            }
            if am > bm {
                result._significand = am &- bm
                result._isNegative = a._isNegative
            } else {
                result._significand = bm &- am
                result._isNegative = b._isNegative
            }
        }
        result._isCompact = 0
        result.compact()
        return (result: result, lossOfPrecision: lossOfPrecision)
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
            let (fitted_, shift, _) = Self._fitSignificand(high: high, low: low, roundingMode: roundingMode, isNegative: isNegative)
            fitted = fitted_
            exponent += shift
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
        let (resultValue, remainder) = try Self._integerDivideByShort(
            self.asVariableLengthInteger(), UInt32(divisor)
        )
        var result = self
        try result.copyVariableLengthInteger(resultValue)
        result._length = UInt32(resultValue.count)
        return (result: result, remainder: UInt16(remainder))
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

        var a = self
        var b = divisor
        let bigSize = Int(Decimal.maxSize) * 2
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
        var bigResult = try Self._integerMultiplyByPowerOfTen(
            lhs: a.asVariableLengthInteger(),
            power: 38,
            maxResultLength: bigSize
        )
        bigResult = try Self._integerDivide(
            dividend: bigResult,
            divisor: b.asVariableLengthInteger(),
            maxResultLength: bigResult.count
        )
        var exponent: Int = 0
        (bigResult, exponent, _) = try Self._fitMantissa(
            bigResult, roundingMode: .down
        )
        var result = Decimal()
        try result.copyVariableLengthInteger(bigResult)
        result._length = UInt32(bigResult.count)
        result._isNegative = a._isNegative != b._isNegative ? 1 : 0
        exponent = Int(a._exponent) - Int(b._exponent) - 38 + exponent
        if exponent < CChar.min {
            throw _CalculationError.underflow
        }
        if exponent > CChar.max {
            throw _CalculationError.overflow
        }
        result._exponent = Int32(exponent)
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

    internal static func _normalize(a: inout Decimal, b: inout Decimal, roundingMode: RoundingMode) throws -> Bool {
        var diffExp = Int(a._exponent - b._exponent)
        // If the two numbers share the same exponents,
        // the normalization is already done
        if diffExp == 0 {
            return false
        }

        return try withUnsafeMutablePointer(to: &a) { aPtr -> Bool in
            return try withUnsafeMutablePointer(to: &b) { bPtr -> Bool in
                // Put the smaller number in aa
                let aa: UnsafeMutablePointer<Decimal>
                let bb: UnsafeMutablePointer<Decimal>
                if diffExp < 0 {
                    aa = bPtr
                    bb = aPtr
                    diffExp = -diffExp
                } else {
                    aa = aPtr
                    bb = bPtr
                }
                // Try to multiply aa to reach the same exponent level as bb
                let multiplyResult = try? self._integerMultiplyByPowerOfTen(
                    lhs: aa.pointee.asVariableLengthInteger(),
                    power: diffExp,
                    maxResultLength: Int(Decimal.maxSize)
                )
                if let multiplyResult = multiplyResult {
                    // Success! Adjust the length/exponent info
                    try aa.pointee.copyVariableLengthInteger(multiplyResult)
                    aa.pointee._length = UInt32(multiplyResult.count)
                    aa.pointee._exponent = bb.pointee._exponent
                    aa.pointee._isCompact = 0
                    return false
                }
                // What is the maximum pow10 we can apply to aa?
                let maxPowerTen = self._integerMaxPowerOfTenMultiplier(
                    number: aa.pointee.asVariableLengthInteger(),
                    maxResultLength: Int(Decimal.maxSize)
                )
                // Divide bb by this value
                let divideResult = try self._integerMultiplyByPowerOfTen(
                    lhs: bb.pointee.asVariableLengthInteger(),
                    power: maxPowerTen - diffExp,
                    maxResultLength: Int(Decimal.maxSize)
                )
                try bb.pointee.copyVariableLengthInteger(divideResult)
                bb.pointee._length = UInt32(Int32(divideResult.count))
                bb.pointee._exponent -= Int32(maxPowerTen - diffExp)
                bb.pointee._isCompact = 0
                // If bb > 0 multiply aa by the same value
                if bb.pointee._length != 0 {
                    let aaResult = try self._integerMultiplyByPowerOfTen(
                        lhs: aa.pointee.asVariableLengthInteger(),
                        power: maxPowerTen,
                        maxResultLength: Int(Decimal.maxSize)
                    )
                    try aa.pointee.copyVariableLengthInteger(aaResult)
                    aa.pointee._length = UInt32(aaResult.count)
                    aa.pointee._exponent -= Int32(maxPowerTen)
                    aa.pointee._isCompact = 0
                } else {
                    bb.pointee._exponent = aa.pointee._exponent
                }

                // Now the two exponents are identical, but we've lost
                // some digits in the operation
                return true
            }
        }
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

// MARK: - Integer Mathmatics
extension Decimal {
    /// Fixed-capacity inline buffer for intermediate integer arithmetic,
    /// replacing `[UInt16]` to eliminate heap allocations on the critical path.
    struct VariableLengthInteger: ExpressibleByArrayLiteral, Sendable {
        // 2 x Mantissa is 16 + 1 for carry
        static var maxCapacity: Int {
            InlineStorage.count
        }
        typealias InlineStorage = InlineArray<17, UInt16>
        
        var count: Int
        var storage: InlineStorage
        
        init() {
            self.count = 0
            self.storage = .init(repeating: 0)
        }
        
        init(repeating value: UInt16, count: Int) {
            self.count = count
            self.storage = .init(repeating: value)
        }
        
        init(mantissa: (UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16)) {
            self.storage = .init(repeating: 0)
            self.storage[0] = mantissa.0
            self.storage[1] = mantissa.1
            self.storage[2] = mantissa.2
            self.storage[3] = mantissa.3
            self.storage[4] = mantissa.4
            self.storage[5] = mantissa.5
            self.storage[6] = mantissa.6
            self.storage[7] = mantissa.7
            
            self.count = 8
            while self.count > 0 && self.storage[self.count - 1] == 0 {
                self.count -= 1
            }
        }
        
        init(arrayLiteral elements: UInt16...) {
            self.storage = .init(initializingWith: { span in
                for idx in 0..<elements.count {
                    span.append(elements[idx])
                }
                for _ in elements.count..<Self.maxCapacity {
                    span.append(0)
                }
            })
            self.count = elements.count
        }
        
        var isEmpty: Bool {
            self.count == 0
        }
        
        var last: UInt16? {
            guard self.count > 0 else { return nil }
            return self[self.count - 1]
        }
        
        subscript(index: Int) -> UInt16 {
            get {
                return self.storage[index]
            }
            set {
                self.storage[index] = newValue
            }
        }
        
        mutating func append(_ value: UInt16) {
            self.storage[self.count] = value
            self.count += 1
        }
        
        mutating func removeLast() {
            self.removeLast(1)
        }
        
        mutating func removeLast(_ n: Int) {
            precondition(self.count >= n, "Cannot removeLast \(n) from \(self.count) VariableLengthInteger")
            self.count -= n
        }
    }
    
    private func asVariableLengthInteger() -> VariableLengthInteger {
        VariableLengthInteger(mantissa: _mantissa)
    }
    
    internal mutating func copyVariableLengthInteger(_ source: VariableLengthInteger) throws {
        guard source.count <= Decimal.maxSize else {
            throw _CalculationError.overflow
        }
        self._length = UInt32(source.count)
        switch source.count {
        case 0:
            self._mantissa = (0, 0, 0, 0, 0, 0, 0, 0)
        case 1:
            self._mantissa = (source[0], 0, 0, 0, 0, 0, 0, 0)
        case 2:
            self._mantissa = (source[0], source[1], 0, 0, 0, 0, 0, 0)
        case 3:
            self._mantissa = (source[0], source[1], source[2], 0, 0, 0, 0, 0)
        case 4:
            self._mantissa = (source[0], source[1], source[2], source[3], 0, 0, 0, 0)
        case 5:
            self._mantissa = (source[0], source[1], source[2], source[3], source[4], 0, 0, 0)
        case 6:
            self._mantissa = (source[0], source[1], source[2], source[3], source[4], source[5], 0, 0)
        case 7:
            self._mantissa = (source[0], source[1], source[2], source[3], source[4], source[5], source[6], 0)
        case 8:
            self._mantissa = (source[0], source[1], source[2], source[3], source[4], source[5], source[6], source[7])
        default:
            throw _CalculationError.overflow
        }
    }
    
    private static func _integerAddShort(_ lhs: VariableLengthInteger, rhs: UInt32, maxResultLength: Int? = nil) throws -> VariableLengthInteger {
        var carry: UInt32 = rhs
        var result = VariableLengthInteger(repeating: 0, count: lhs.count)
        for index in 0 ..< lhs.count {
            let acc = UInt32(lhs[index]) + carry
            carry = acc >> 16
            result[index] = UInt16(acc & 0xFFFF)
        }
        if carry != 0 {
            if let maxResultLength = maxResultLength, result.count == maxResultLength {
                throw _CalculationError.overflow
            }
            result.append(UInt16(carry))
        }
        return result
    }
    
    private static func _integerDivideByShort(
        _ dividend: VariableLengthInteger,
        _ divisor: UInt32
    ) throws -> (quotient: VariableLengthInteger, remainder: UInt32) {
        if divisor == 0 {
            throw _CalculationError.divideByZero
        }
        var carry: UInt32 = 0
        var acc: UInt32 = 0
        var result = VariableLengthInteger(repeating: 0, count: dividend.count)
        for directIndex in 0 ..< dividend.count {
            let index = dividend.count - directIndex - 1
            acc = (UInt32(dividend[index]) + carry * (1 << 16))
            result[index] = UInt16(acc / divisor)
            carry = acc % divisor
        }
        while result.last == 0 {
            result.removeLast()
        }
        return (quotient: result, remainder: carry)
    }
    
    private static func _integerDivide(
        dividend: VariableLengthInteger,
        divisor: VariableLengthInteger,
        maxResultLength: Int
    ) throws -> VariableLengthInteger {
        if divisor.isEmpty {
            throw _CalculationError.divideByZero
        }
        // If dividend < divisor, the result is appromixtly 0
        if self._integerCompare(lhs: dividend, rhs: divisor) == .orderedAscending {
            return VariableLengthInteger() // zero
        }
        // Fast algorithm
        if divisor.count == 1 {
            return try self._integerDivideByShort(
                dividend, UInt32(divisor[0])
            ).quotient
        }
        
        // D1: Normalize
        // Calculate d such that `d*highest_dight_of_divisor >= b/2 (0x8000)
        let d: UInt32 = (1 << 16) / (UInt32(divisor[divisor.count - 1]) + 1)
        // This is to make the whole algorithm work and
        // (dividend * d) / (divisor * d) == dividend / divisor
        var normalizedDividend = try self._integerMultiplyByShort(
            lhs: dividend,
            mulplicand: d,
            maxResultLength: dividend.count + 1
        )
        var normalizedDivisor = try self._integerMultiplyByShort(
            lhs: divisor,
            mulplicand: d,
            maxResultLength: divisor.count + 1
        )
        // Set a zero at the leftmost dividend position if the
        // multiplication do not have a carry
        if normalizedDividend.count == dividend.count {
            normalizedDividend.append(0)
        }
        let dividendLength = normalizedDividend.count
        // Set a zero at the leftmost divisor position.
        // The algorithm will use it during the multiplication/
        // subtraction phase
        let divivisorLength = normalizedDivisor.count
        // Intentionally appened after `divivisorLength` has been captured
        normalizedDivisor.append(0)
        // Determine the approxmite size of the quotient
        let quotientLength = normalizedDividend.count - divivisorLength
        // Some useful constant for the loop
        let v1: UInt32 = UInt32(normalizedDivisor[divivisorLength - 1])
        let v2: UInt32 = divivisorLength > 1 ? UInt32(normalizedDivisor[divivisorLength - 2]) : 0
        
        var result = VariableLengthInteger(repeating: 0, count: maxResultLength)
        // D2: Initialize j
        // On each pass, build a single value for the quotient
        for j in 0 ..< quotientLength {
            // D3: calculate q^
            let tmp: UInt32 = (UInt32(normalizedDividend[dividendLength - j - 1]) << 16) + UInt32(normalizedDividend[dividendLength - j - 2])
            var tmpRemainder = UInt32(tmp % v1)
            var q: UInt32 = tmp / v1
            
            // This test catches all cases where q is really q+2 and
            // most where it is q+1
            if (q == (1 << 16)) ||
                (v2 * q > (tmpRemainder << 16) + UInt32(normalizedDividend[dividendLength - j - 3]))  {
                q -= 1
                tmpRemainder += v1
                
                if (tmpRemainder < (1 << 16)) &&
                    ((q == (1 << 16) ) ||
                     ( v2 * q > (tmpRemainder << 16) + UInt32(normalizedDividend[dividendLength - j - 3]))) {
                    q -= 1
                }
            }
            // D4: multiply and subtract
            var multiplyCarry: UInt32 = 0
            var subtractCarry: UInt32 = 1
            for i in 0 ..< divivisorLength + 1 {
                // Multiply
                var acc = q * UInt32(normalizedDivisor[i]) + multiplyCarry
                multiplyCarry = acc >> 16
                acc = acc & 0xFFFF
                // Subtract
                acc = 0xFFFF + UInt32(normalizedDividend[dividendLength - divivisorLength + i - j - 1]) - acc + subtractCarry
                subtractCarry = acc >> 16
                normalizedDividend[dividendLength - divivisorLength + i - j - 1] = UInt16(acc & 0xFFFF)
            }
            
            // D5: Test remainder
            // This test catches cases where q is still q + 1
            if subtractCarry == 0 {
                // D6: Add back
                var additionCarry: UInt32 = 0
                // Subtract one from quotient digit
                q -= 1
                for i in 0 ..< divivisorLength {
                    let acc = UInt32(normalizedDivisor[i]) + UInt32(normalizedDividend[dividendLength - divivisorLength + i - j - 1]) + additionCarry
                    additionCarry = acc >> 16
                    normalizedDividend[dividendLength - divivisorLength + i - j - 1] = UInt16(acc & 0xFFFF)
                }
            }
            result[quotientLength - j - 1] = UInt16(q)
            // D7: Loop on j
        }
        // Remove extra zeros
        while result.last == 0 {
            result.removeLast()
        }
        
        return result
    }
    
    private static func _integerMultiply(
        lhs: VariableLengthInteger,
        rhs: VariableLengthInteger,
        maxResultLength: Int
    ) throws -> VariableLengthInteger {
        if lhs.isEmpty || rhs.isEmpty {
            return VariableLengthInteger()
        }
        var resultLength = maxResultLength
        if resultLength > lhs.count + rhs.count {
            resultLength = lhs.count + rhs.count
        }
        var result = VariableLengthInteger(repeating: 0, count: resultLength)
        var carry: UInt32 = 0
        for j in 0 ..< rhs.count {
            carry = 0
            for i in 0 ..< lhs.count {
                if i + j < resultLength {
                    let acc = carry + UInt32(result[j + i]) + UInt32(rhs[j]) * UInt32(lhs[i])
                    carry = acc >> 16
                    // FIXME: Check if truncate is okay here
                    result[j + i] = UInt16(truncatingIfNeeded:acc) & 0xFFFF
                } else if carry != 0 || (rhs[j] > 0 && lhs[i] > 0) {
                    throw _CalculationError.overflow
                }
            }
            
            if carry != 0 {
                if lhs.count + j < resultLength {
                    result[lhs.count + j] = UInt16(carry)
                } else {
                    throw _CalculationError.overflow
                }
            }
        }
        while result.last == 0 {
            result.removeLast()
        }
        return result
    }
    
    private static func _integerMultiplyByShort(
        lhs: VariableLengthInteger,
        mulplicand: UInt32, maxResultLength: Int
    ) throws -> VariableLengthInteger {
        if mulplicand == 0 {
            return VariableLengthInteger()
        }
        if maxResultLength < lhs.count {
            throw _CalculationError.overflow
        }
        var result = VariableLengthInteger(repeating: 0, count: lhs.count)
        var carry: UInt32 = 0
        for index in 0 ..< lhs.count {
            let acc = UInt32(lhs[index]) * mulplicand + carry
            carry = acc >> 16
            result[index] = UInt16(acc & 0xFFFF)
        }
        if carry != 0 {
            if maxResultLength == lhs.count {
                throw _CalculationError.overflow
            }
            result.append(UInt16(carry))
        }
        return result
    }
    
    private static func _integerMultiplyByPowerOfTen(
        lhs: VariableLengthInteger,
        power: Int,
        maxResultLength: Int
    ) throws -> VariableLengthInteger {
        // 10^0 == 1, it's just a copy
        if power == 0 {
            return lhs
        }
        var result = lhs
        let isNegative = power < 0
        var powerValue = abs(power)
        let maxPowerTen = powerOfTen.count - 1
        // Handle powers above maxPowerTen
        while powerValue > maxPowerTen {
            powerValue -= maxPowerTen
            let p10 = powerOfTen[maxPowerTen]
            if !isNegative {
                result = try self._integerMultiply(
                    lhs: result,
                    rhs: p10,
                    maxResultLength: maxResultLength
                )
            } else {
                result = try self._integerDivide(
                    dividend: result,
                    divisor: p10,
                    maxResultLength: maxResultLength
                )
            }
        }
        // Handle reset of the power (<= max)
        let p10 = powerOfTen[powerValue]
        if !isNegative {
            result = try self._integerMultiply(
                lhs: result,
                rhs: p10,
                maxResultLength: maxResultLength
            )
        } else {
            result = try self._integerDivide(
                dividend: result,
                divisor: p10,
                maxResultLength: maxResultLength
            )
        }
        return result
    }
    
    private static func _integerMaxPowerOfTenMultiplier(
        number: VariableLengthInteger,
        maxResultLength: Int
    ) -> Int {
        let lengthDiff = maxResultLength - number.count
        // 4.8 ~= log-base-10(2^16)
        let trialValue = floor(Double(lengthDiff) * 4.81647993)
        return Int(trialValue)
    }
    
    private static func _integerCompare(lhs: VariableLengthInteger, rhs: VariableLengthInteger) -> ComparisonResult {
        if lhs.count > rhs.count {
            return .orderedDescending
        }
        if lhs.count < rhs.count {
            return .orderedAscending
        }
        
        for index in (1 ..< lhs.count + 1).reversed() {
            let left = lhs[index - 1]
            let right = rhs[index - 1]
            if left > right {
                return .orderedDescending
            }
            if left < right {
                return .orderedAscending
            }
        }
        return .orderedSame
    }
    
    private static func _fitMantissa(
        _ value: VariableLengthInteger,
        roundingMode: RoundingMode
    ) throws -> (result: VariableLengthInteger, exponent: Int, lossOfPrecision: Bool) {
        if value.count <= Decimal.maxSize {
            return (result: value, exponent: 0, lossOfPrecision: false)
        }
        // Divide by 10 as much as possible
        var result = value
        var premdr: UInt32 = 0
        var remdr: UInt32 = 0
        var exponent: Int = 0
        while result.count > Decimal.maxSize + 1 {
            if remdr != 0 {
                premdr = 1
            }
            let (quotient, remainder) = try _integerDivideByShort(result, 10000)
            result = quotient
            remdr = remainder
            exponent += 4
        }
        while result.count > Decimal.maxSize {
            if remdr != 0 {
                premdr = 1
            }
            let (quotient, remainder) = try _integerDivideByShort(result, 10)
            result = quotient
            remdr = remainder
            exponent += 1
        }
        // If we are on a tie, adjust with premdr. .50001 is equivalent to .6
        if premdr != 0 && (remdr == 0 || remdr == 5) {
            remdr += 1
        }
        if remdr == 0 {
            return (result: result, exponent: exponent, lossOfPrecision: false)
        }
        // Round the result
        switch roundingMode {
        case .down:
            break
        case .bankers:
            if (remdr == 5) && (result[0] & 1) != 0 {
                break
            }
            fallthrough
        case .plain:
            if remdr < 5 {
                break
            }
            fallthrough
        case .up:
            let size = result.count
            var rounded = try Self._integerAddShort(
                result, rhs: 1,
                maxResultLength: result.count + 1
            )
            if size > rounded.count {
                // The last digit is 0, remove it.
                let (_rounded, _) = try Self._integerDivideByShort(rounded, 10)
                exponent += 1
                rounded = _rounded
            }
        @unknown default:
            break
        }
        return (result: result, exponent: exponent, lossOfPrecision: true)
    }
    
    private static func _fitSignificand(
        high: UInt128,
        low: UInt128,
        roundingMode: RoundingMode,
        isNegative: Bool
    ) -> (result: UInt128, exponent: Int32, lossOfPrecision: Bool) {
        if high == 0 {
            return (result: low, exponent: 0, lossOfPrecision: false)
        }
        
        var high = high
        var low = low
        var lastDropped = 0 as UInt128
        var exponent = 0 as Int32
        var droppedNonzeroDigit = false
        
        while high >= 10000 {
            if lastDropped != 0 { droppedNonzeroDigit = true }
            let (q1, r1) = high._quotientAndRemainderDividingBy10000()
            let (q2, r2) = (10000 as UInt128).dividingFullWidth((r1, low))
            high = q1
            low = q2
            lastDropped = r2
            exponent += 4
        }
        while high != 0 {
            if lastDropped != 0 { droppedNonzeroDigit = true }
            let (q1, r1) = high._quotientAndRemainderDividingBy10()
            let (q2, r2) = (10 as UInt128).dividingFullWidth((r1, low))
            high = q1
            low = q2
            lastDropped = r2
            exponent += 1
        }
        
        // Nudge ties if necessary.
        assert(lastDropped < 10)
        if droppedNonzeroDigit && (lastDropped == 0 || lastDropped == 5) {
            lastDropped += 1
        }
        if lastDropped == 0 {
            return (low, exponent, false)
        }
        
        // Round if necessary.
        let roundAway = switch roundingMode {
        case .down: isNegative
        case .up: !isNegative
        case .plain: lastDropped >= 5
        case .bankers: lastDropped > 5 || (lastDropped == 5 && (low & 1) == 1)
        @unknown default: fatalError("Not implemented") //TODO: Determine a consistent sensible behavior for unknown rounding mode.
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
}
