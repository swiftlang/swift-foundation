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

import Testing

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif os(WASI)
import WASILibc
#elseif os(Windows)
import CRT
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@_spi(SwiftCorelibsFoundation)
@testable import FoundationEssentials
#endif

struct DecimalTests {
#if !FOUNDATION_FRAMEWORK // These tests tests the stub implementations
    func assertMantissaEquals(lhs: Decimal, rhs: Decimal.Mantissa, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(lhs[0] == rhs.0, "Mantissa.0 does not equal: \(lhs[0]) vs \(rhs.0)", sourceLocation: sourceLocation)
        #expect(lhs[1] == rhs.1, "Mantissa.1 does not equal: \(lhs[1]) vs \(rhs.1)", sourceLocation: sourceLocation)
        #expect(lhs[2] == rhs.2, "Mantissa.2 does not equal: \(lhs[2]) vs \(rhs.2)", sourceLocation: sourceLocation)
        #expect(lhs[3] == rhs.3, "Mantissa.3 does not equal: \(lhs[3]) vs \(rhs.3)", sourceLocation: sourceLocation)
        #expect(lhs[4] == rhs.4, "Mantissa.4 does not equal: \(lhs[4]) vs \(rhs.4)", sourceLocation: sourceLocation)
        #expect(lhs[5] == rhs.5, "Mantissa.5 does not equal: \(lhs[5]) vs \(rhs.5)", sourceLocation: sourceLocation)
        #expect(lhs[6] == rhs.6, "Mantissa.6 does not equal: \(lhs[6]) vs \(rhs.6)", sourceLocation: sourceLocation)
        #expect(lhs[7] == rhs.7, "Mantissa.7 does not equal: \(lhs[7]) vs \(rhs.7)", sourceLocation: sourceLocation)
    }

    @Test(arguments: 0 ..< 100)
    func testDecimalRoundtripFuzzing(iteration: Int) {
        // Exponent is only 8 bits long
        let exponent: CInt = CInt(Int8.random(in: Int8.min ..< Int8.max))
        // Length is only 4 bits long
        var length: CUnsignedInt = .random(in: 0 ..< 0xF)
        let isNegative: CUnsignedInt = .random(in: 0 ..< 1)
        let isCompact: CUnsignedInt = .random(in: 0 ..< 1)
        // Reserved is 18 bits long
        let reserved: CUnsignedInt = .random(in: 0 ..< 0x3FFFF)
        let mantissa: Decimal.Mantissa = (
            .random(in: 0 ..< UInt16.max),
            .random(in: 0 ..< UInt16.max),
            .random(in: 0 ..< UInt16.max),
            .random(in: 0 ..< UInt16.max),
            .random(in: 0 ..< UInt16.max),
            .random(in: 0 ..< UInt16.max),
            .random(in: 0 ..< UInt16.max),
            .random(in: 0 ..< UInt16.max)
        )
        
        var decimal = Decimal(
            _exponent: exponent,
            _length: length,
            _isNegative: isNegative,
            _isCompact: isCompact,
            _reserved: reserved,
            _mantissa: mantissa
        )
        
        #expect(decimal._exponent == exponent)
        #expect(decimal._length == length)
        #expect(decimal._isNegative == isNegative)
        #expect(decimal._isCompact == isCompact)
        #expect(decimal._reserved == reserved)
        assertMantissaEquals(
            lhs: decimal,
            rhs: mantissa
        )
        
        // Update invidividual values
        length = .random(in: 0 ..< 0xF)
        decimal._length = length
        #expect(decimal._length == length)
    }
#endif

    @Test func testAbusiveCompact() {
        var decimal = Decimal()
        decimal._exponent = 5
        decimal._length = 5
        decimal.compact()
        #expect(Decimal.zero == decimal)
    }

    @Test func test_Description() {
        #expect("0" == Decimal().description)
        #expect("0" == Decimal(0).description)
        #expect("10" == Decimal(_exponent: 1, _length: 1, _isNegative: 0, _isCompact: 1, _reserved: 0, _mantissa: (1, 0, 0, 0, 0, 0, 0, 0)).description)
        #expect("10" == Decimal(10).description)
        #expect("123.458" == Decimal(_exponent: -3, _length: 2, _isNegative: 0, _isCompact:1, _reserved: 0, _mantissa: (57922, 1, 0, 0, 0, 0, 0, 0)).description)
        #expect("123.458" == Decimal(123.458).description)
        #expect("123" == Decimal(UInt8(123)).description)
        #expect("45" == Decimal(Int8(45)).description)
        #expect("3.14159265358979323846264338327950288419" == Decimal.pi.description)
        #expect("-30000000000" == Decimal(sign: .minus, exponent: 10, significand: Decimal(3)).description)
        #expect("300000" == Decimal(sign: .plus, exponent: 5, significand: Decimal(3)).description)
        #expect("5" == Decimal(signOf: Decimal(3), magnitudeOf: Decimal(5)).description)
        #expect("-5" == Decimal(signOf: Decimal(-3), magnitudeOf: Decimal(5)).description)
        #expect("5" == Decimal(signOf: Decimal(3), magnitudeOf: Decimal(-5)).description)
        #expect("-5" == Decimal(signOf: Decimal(-3), magnitudeOf: Decimal(-5)).description)
    }

    @Test func test_BasicConstruction() {
        let zero = Decimal()
        #expect(20 == MemoryLayout<Decimal>.size)
        #expect(0 == zero._exponent)
        #expect(0 == zero._length)
        #expect(0 == zero._isNegative)
        #expect(0 == zero._isCompact)
        #expect(0 == zero._reserved)
        let (m0, m1, m2, m3, m4, m5, m6, m7) = zero._mantissa
        #expect(0 == m0)
        #expect(0 == m1)
        #expect(0 == m2)
        #expect(0 == m3)
        #expect(0 == m4)
        #expect(0 == m5)
        #expect(0 == m6)
        #expect(0 == m7)
        #expect(8 == Decimal.maxSize)
        #expect(32767 == CShort.max)
        #expect(!zero.isNormal)
        #expect(zero.isFinite)
        #expect(zero.isZero)
        #expect(!zero.isSubnormal)
        #expect(!zero.isInfinite)
        #expect(!zero.isNaN)
        #expect(!zero.isSignaling)

        let d1 = Decimal(1234567890123456789 as UInt64)
        #expect(d1._exponent == 0)
        #expect(d1._length == 4)
    }

    @Test func test_ExplicitConstruction() {
        var explicit = Decimal(
            _exponent: 0x17f,
            _length: 0xff,
            _isNegative: 3,
            _isCompact: 4,
            _reserved: UInt32(1<<18 + 1<<17 + 1),
            _mantissa: (6, 7, 8, 9, 10, 11, 12, 13)
        )
        #expect(0x7f == explicit._exponent)
        #expect(0x7f == explicit.exponent)
        #expect(0x0f == explicit._length)
        #expect(1 == explicit._isNegative)
        #expect(FloatingPointSign.minus == explicit.sign)
        #expect(explicit.isSignMinus)
        #expect(0 == explicit._isCompact)
        #expect(UInt32(1<<17 + 1) == explicit._reserved)
        let (m0, m1, m2, m3, m4, m5, m6, m7) = explicit._mantissa
        #expect(6 == m0)
        #expect(7 == m1)
        #expect(8 == m2)
        #expect(9 == m3)
        #expect(10 == m4)
        #expect(11 == m5)
        #expect(12 == m6)
        #expect(13 == m7)
        explicit._isCompact = 5
        explicit._isNegative = 6
        #expect(0 == explicit._isNegative)
        #expect(1 == explicit._isCompact)
        #expect(FloatingPointSign.plus == explicit.sign)
        #expect(!explicit.isSignMinus)
        #expect(explicit.isNormal)

        let significand = explicit.significand
        #expect(0 == significand._exponent)
        #expect(0 == significand.exponent)
        #expect(0x0f == significand._length)
        #expect(0 == significand._isNegative)
        #expect(1 == significand._isCompact)
        #expect(0 == significand._reserved)
        let (sm0, sm1, sm2, sm3, sm4, sm5, sm6, sm7) = significand._mantissa
        #expect(6 == sm0)
        #expect(7 == sm1)
        #expect(8 == sm2)
        #expect(9 == sm3)
        #expect(10 == sm4)
        #expect(11 == sm5)
        #expect(12 == sm6)
        #expect(13 == sm7)
    }

    @Test func test_ScanDecimal() throws {
        let testCases = [
            // expected, value
            ( 123.456e78, "123.456e78", "123456000000000000000000000000000000000000000000000000000000000000000000000000000" ),
            ( -123.456e78, "-123.456e78", "-123456000000000000000000000000000000000000000000000000000000000000000000000000000" ),
            ( 123.456, " 123.456 ", "123.456" ),
            ( 3.14159, " 3.14159e0", "3.14159" ),
            ( 3.14159, " 3.14159e-0", "3.14159" ),
            ( 0.314159, " 3.14159e-1", "0.314159" ),
            ( 3.14159, " 3.14159e+0", "3.14159"),
            ( 31.4159, " 3.14159e+1", "31.4159"),
            ( 12.34, " 01234e-02", "12.34"),
        ]
        for testCase in testCases {
            let (expected, string, _) = testCase
            let decimal = try #require(Decimal(string: string))
            let aboutOne = Decimal(expected) / decimal
            #expect(aboutOne >= Decimal(0.99999) && aboutOne <= Decimal(1.00001), "\(expected) ~= \(decimal)")
        }
        let answer = try #require(Decimal(string:"12345679012345679012345679012345679012.3"))
        let ones = try #require(Decimal(string:"111111111111111111111111111111111111111"))
        let num = ones / Decimal(9)
        #expect(answer == num, "\(ones) / 9 = \(answer) \(num)")

        // Exponent overflow, returns nil
        #expect(Decimal(string: "1e200") == nil)
        #expect(Decimal(string: "1e-200") == nil)
        #expect(Decimal(string: "1e300") == nil)
        #expect(Decimal(string: "1" + String(repeating: "0", count: 170)) == nil)
        #expect(Decimal(string: "0." + String(repeating: "0", count: 170) + "1") == nil)
        #expect(Decimal(string: "0e200") == nil)

        // Parsing zero in different forms
        let zero1 = try #require(Decimal(string: "000.000e123"))
        #expect(zero1.isZero)
        #expect(zero1._isNegative == 0)
        #expect(zero1._length == 0)
        #expect(zero1.description == "0")

        let zero2 = try #require(Decimal(string: "+000.000e-123"))
        #expect(zero2.isZero)
        #expect(zero2._isNegative == 0)
        #expect(zero2._length == 0)
        #expect(zero2.description == "0")

        let zero3 = try #require(Decimal(string: "-0.0e1"))
        #expect(zero3.isZero)
        #expect(zero3._isNegative == 0)
        #expect(zero3._length == 0)
        #expect(zero3.description == "0")

        // Bin compat: invalid strings starting with E should be parsed as 0
        var zeroE = try #require(Decimal(string: "en"))
        #expect(zeroE.isZero)
        zeroE = try #require(Decimal(string: "e"))
        #expect(zeroE.isZero)
        // Partitally valid strings ending with e shold be parsed
        let notZero = try #require(Decimal(string: "123e"))
        #expect(notZero == Decimal(123))
    }

    @Test func testStringPartialMatch() throws {
        // This tests makes sure Decimal still has the
        // same behavior that it only requires the beginning
        // of the string to be valid number
        let decimal = try #require(Decimal(string: "3.14notanumber"))
        #expect(decimal.description == "3.14")
    }

    @Test func testStringNoMatch() {
        // This test makes sure Decimal returns nil
        // if the does not start with a number
        var notDecimal = Decimal(string: "A Flamingo's head has to be upside down when it eats.")
        #expect(notDecimal == nil)
        // Same if the number does not appear at the beginning
        notDecimal = Decimal(string: "Jump 22 Street")
        #expect(notDecimal == nil)
    }

    @Test func testNormalize() throws {
        var one = Decimal(1)
        var ten = Decimal(-10)
        var lossPrecision = try Decimal._normalize(a: &one, b: &ten, roundingMode: .plain)
        #expect(!lossPrecision)
        #expect(Decimal(1) == one)
        #expect(Decimal(-10) == ten)
        #expect(1 == one._length)
        #expect(1 == ten._length)
        one = Decimal(1)
        ten = Decimal(10)
        lossPrecision = try Decimal._normalize(a: &one, b: &ten, roundingMode: .plain)
        #expect(!lossPrecision)
        #expect(Decimal(1) == one)
        #expect(Decimal(10) == ten)
        #expect(1 == one._length)
        #expect(1 == ten._length)

        // Normalise with loss of precision
        let a = try #require(Decimal(string: "498.7509045"))
        let b = try #require(Decimal(string: "8.453441368210501065891847765109162027"))

        var aNormalized = a
        var bNormalized = b

        lossPrecision = try Decimal._normalize(
            a: &aNormalized, b: &bNormalized, roundingMode: .plain)
        #expect(lossPrecision)

        #expect(aNormalized.exponent == -31)
        #expect(aNormalized._mantissa.0 == 0)
        #expect(aNormalized._mantissa.1 == 21760)
        #expect(aNormalized._mantissa.2 == 45355)
        #expect(aNormalized._mantissa.3 == 11455)
        #expect(aNormalized._mantissa.4 == 62709)
        #expect(aNormalized._mantissa.5 == 14050)
        #expect(aNormalized._mantissa.6 == 62951)
        #expect(aNormalized._mantissa.7 == 0)
        #expect(bNormalized.exponent == -31)
        #expect(bNormalized._mantissa.0 == 56467)
        #expect(bNormalized._mantissa.1 == 17616)
        #expect(bNormalized._mantissa.2 == 59987)
        #expect(bNormalized._mantissa.3 == 21635)
        #expect(bNormalized._mantissa.4 == 5988)
        #expect(bNormalized._mantissa.5 == 63852)
        #expect(bNormalized._mantissa.6 == 1066)
        #expect(bNormalized._length == 7)
        #expect(a == aNormalized)
        #expect(b != bNormalized)   // b had a loss Of Precision when normalising
    }

    @Test func testAdditionWithNormalization() throws {
        let one: Decimal = Decimal(1)
        var addend: Decimal = one
        // 2 digits
        addend._exponent = -1
        var (result, lostPrecision) = try one._add(rhs: addend, roundingMode: .plain)
        var expected: Decimal = Decimal()
        expected._isNegative = 0
        expected._isCompact = 0
        expected._exponent = -1
        expected._length = 1
        expected._mantissa.0 = 11
        #expect(Decimal._compare(lhs: result, rhs: expected) == .orderedSame)
        // 38 digits
        addend._exponent = -37
        expected._exponent = -37;
        expected._length = 8;
        expected._mantissa.0 = 0x0001;
        expected._mantissa.1 = 0x0000;
        expected._mantissa.2 = 0x36a0;
        expected._mantissa.3 = 0x00f4;
        expected._mantissa.4 = 0x46d9;
        expected._mantissa.5 = 0xd5da;
        expected._mantissa.6 = 0xee10;
        expected._mantissa.7 = 0x0785;
        (result, _) = try one._add(rhs: addend, roundingMode: .plain)
        #expect(Decimal._compare(lhs: expected, rhs: result) == .orderedSame)
        // 39 Digits -- not guaranteed to work
        addend._exponent = -38
        (result, lostPrecision) = try one._add(rhs: addend, roundingMode: .plain)
        if !lostPrecision {
            expected._exponent = -38;
            expected._length = 8;
            expected._mantissa.0 = 0x0001;
            expected._mantissa.1 = 0x0000;
            expected._mantissa.2 = 0x2240;
            expected._mantissa.3 = 0x098a;
            expected._mantissa.4 = 0xc47a;
            expected._mantissa.5 = 0x5a86;
            expected._mantissa.6 = 0x4ca8;
            expected._mantissa.7 = 0x4b3b;
            #expect(Decimal._compare(lhs: expected, rhs: result) == .orderedSame)
        } else {
            #expect(Decimal._compare(lhs: one, rhs: result) == .orderedSame)
        }
        // 40 Digits -- does NOT work, make sure we round
        addend._exponent = -39
        (result, lostPrecision) = try one._add(rhs: addend, roundingMode: .plain)
        #expect(lostPrecision)
        #expect("1" == result.description)
        #expect(Decimal._compare(lhs: one, rhs: result) == .orderedSame)
    }

    @Test func testSimpleMultiplication() throws {
        var multiplicand = Decimal()
        multiplicand._isNegative = 0
        multiplicand._isCompact = 0
        multiplicand._length = 1
        multiplicand._exponent = 1
        var multiplier = multiplicand
        multiplier._exponent = 2

        var expected = multiplicand
        expected._isNegative = 0
        expected._isCompact = 0
        expected._exponent = 3
        expected._length = 1

        for i in 1 ..< UInt8.max {
            multiplicand._mantissa.0 = UInt16(i)
            for j in 1 ..< UInt8.max {
                multiplier._mantissa.0 = UInt16(j)
                expected._mantissa.0 = UInt16(i) * UInt16(j)

                let result = try multiplicand._multiply(
                    by: multiplier, roundingMode: .plain
                )
                #expect(Decimal._compare(lhs: expected, rhs: result) == .orderedSame)
            }
        }
    }

    @Test func testNegativeAndZeroMultiplication() throws {
        let one = Decimal(1)
        let zero = Decimal(0)
        var negativeOne = one
        negativeOne._isNegative = 1

        // 1 * 1
        var result = try one._multiply(by: one, roundingMode: .plain)
        #expect(Decimal._compare(lhs: one, rhs: result) == .orderedSame)
        // 1 * -1
        result = try one._multiply(by: negativeOne, roundingMode: .plain)
        #expect(Decimal._compare(lhs: negativeOne, rhs: result) == .orderedSame)
        // -1 * 1
        result = try negativeOne._multiply(by: one, roundingMode: .plain)
        #expect(Decimal._compare(lhs: negativeOne, rhs: result) == .orderedSame)
        // -1 * -1
        result = try negativeOne._multiply(by: negativeOne, roundingMode: .plain)
        #expect(Decimal._compare(lhs: one, rhs: result) == .orderedSame)
        // 1 * 0
        result = try one._multiply(by: zero, roundingMode: .plain)
        #expect(Decimal._compare(lhs: zero, rhs: result) == .orderedSame)
        // 0 * 1
        result = try zero._multiply(by: negativeOne, roundingMode: .plain)
        #expect(Decimal._compare(lhs: zero, rhs: result) == .orderedSame)
    }

    @Test func testMultiplicationOverflow() throws {
        let multiplicand = Decimal(
            _exponent: 0,
            _length: 8,
            _isNegative: 0,
            _isCompact: 0,
            _reserved: 0,
            _mantissa: (0xffff, 0xffff, 0xffff, 0xffff,
                        0xffff, 0xffff, 0xffff, 0xffff)
        )
        var multiplier = Decimal(1)
        multiplier._mantissa.0 = 2

        // This test makes sure the following does NOT throw
        // max_mantissa * 2
        _ = try multiplicand._multiply(
            by: multiplier, roundingMode: .plain)
        // 2 * max_mantissa
        _ = try multiplier._multiply(
            by: multiplicand, roundingMode: .plain)

        // The following should throw .overlow
        multiplier._exponent = 0x7F
        #expect {
            // 2e127 * max_mantissa
            _ = try multiplicand._multiply(
                by: multiplier, roundingMode: .plain)
        } throws: {
            ($0 as? Decimal._CalculationError) == .overflow
        }

        #expect {
            // max_mantissa * 2e127
            _ = try multiplier._multiply(
                by: multiplicand, roundingMode: .plain)
        } throws: {
            ($0 as? Decimal._CalculationError) == .overflow
        }
    }

    @Test func testMultiplyByPowerOfTen() throws {
        let a = Decimal(1234)
        var result = try a._multiplyByPowerOfTen(power: 1, roundingMode: .plain)
        #expect(result == Decimal(12340))
        result = try a._multiplyByPowerOfTen(power: 2, roundingMode: .plain)
        #expect(result == Decimal(123400))
        result = try a._multiplyByPowerOfTen(power: 0, roundingMode: .plain)
        #expect(result == Decimal(1234))
        result = try a._multiplyByPowerOfTen(power: -2, roundingMode: .plain)
        #expect(result == Decimal(12.34))

        // Overflow
        #expect {
            _ = try a._multiplyByPowerOfTen(power: 128, roundingMode: .plain)
        } throws: {
            ($0 as? Decimal._CalculationError) == .overflow
        }

        // Underflow
        #expect {
            _ = try Decimal(12.34)._multiplyByPowerOfTen(power: -128, roundingMode: .plain)
        } throws: {
            ($0 as? Decimal._CalculationError) == .underflow
        }
    }

    @Test func testRepeatingDivision() throws {
        let repeatingNumerator = Decimal(16)
        let repeatingDenominator = Decimal(9)
        let repeating = try repeatingNumerator._divide(
            by: repeatingDenominator, roundingMode: .plain
        )
        let numerator = Decimal(1010)
        let result = try numerator._divide(
            by: repeating, roundingMode: .plain
        )
        var expected = Decimal()
        expected._exponent = -35
        expected._length = 8
        expected._isNegative = 0
        expected._isCompact = 1
        expected._reserved = 0
        expected._mantissa.0 = 51946
        expected._mantissa.1 = 3
        expected._mantissa.2 = 15549
        expected._mantissa.3 = 55864
        expected._mantissa.4 = 57984
        expected._mantissa.5 = 55436
        expected._mantissa.6 = 45186
        expected._mantissa.7 = 10941
        #expect(Decimal._compare(lhs: expected, rhs: result) == .orderedSame)
    }

#if _pointerBitWidth(_64)
    // This test require Int to be Int64
    @Test func testCrashingDivision() throws {
        // This test makes sure the following division
        // does not crash
        let first: Decimal = Decimal(1147858867)
        let second: Decimal = Decimal(4294967295)
        let result = first / second
        let expected: Decimal = Decimal(
            _exponent: -38,
            _length: 8,
            _isNegative: 0,
            _isCompact: 1,
            _reserved: 0,
            _mantissa: (
                58076,
                13229,
                12316,
                25502,
                15252,
                32996,
                11611,
                5147
            )
        )
        #expect(result == expected)
    }
#endif

    @Test func testPower() throws {
        var a = Decimal(1234)
        var result = try a._power(exponent: 0, roundingMode: .plain)
        #expect(Decimal._compare(lhs: result, rhs: Decimal(1)) == .orderedSame)
        a = Decimal(8)
        result = try a._power(exponent: 2, roundingMode: .plain)
        #expect(Decimal._compare(lhs: result, rhs: Decimal(64)) == .orderedSame)
        a = Decimal(-2)
        result = try a._power(exponent: 3, roundingMode: .plain)
        #expect(Decimal._compare(lhs: result, rhs: Decimal(-8)) == .orderedSame)
        result = try a._power(exponent: 0, roundingMode: .plain)
        #expect(Decimal._compare(lhs: result, rhs: Decimal(1)) == .orderedSame)
        // Positive base
        let six = Decimal(6)
        for exponent in 1 ..< 10 {
            result = try six._power(exponent: exponent, roundingMode: .plain)
            #expect(result.doubleValue == pow(6.0, Double(exponent)))
        }
        // Negative base
        let negativeSix = Decimal(-6)
        for exponent in 1 ..< 10 {
            result = try negativeSix._power(exponent: exponent, roundingMode: .plain)
            #expect(result.doubleValue == pow(-6.0, Double(exponent)))
        }
        for i in -2 ... 10 {
            for j in 0 ... 5 {
                let actual = Decimal(i)
                let result = try actual._power(
                    exponent: j, roundingMode: .plain
                )
                let expected = Decimal(pow(Double(i), Double(j)))
                #expect(expected == result, "\(result) == \(i)^\(j)")
            }
        }
    }

    @Test func testNaNInput() throws {
        let nan = Decimal.nan
        let one = Decimal(1)

        #expect {
            // NaN + 1
            _ = try nan._add(rhs: one, roundingMode: .plain)
        } throws: {
            ($0 as? Decimal._CalculationError) == .overflow
        }
        #expect {
            // 1 + NaN
            _ = try one._add(rhs: nan, roundingMode: .plain)
        } throws: {
            ($0 as? Decimal._CalculationError) == .overflow
        }

        #expect {
            // NaN - 1
            _ = try nan._subtract(rhs: one, roundingMode: .plain)
        } throws: {
            ($0 as? Decimal._CalculationError) == .overflow
        }
        #expect {
            // 1 - NaN
            _ = try one._subtract(rhs: nan, roundingMode: .plain)
        } throws: {
            ($0 as? Decimal._CalculationError) == .overflow
        }

        #expect {
            // NaN * 1
            _ = try nan._multiply(by: one, roundingMode: .plain)
        } throws: {
            ($0 as? Decimal._CalculationError) == .overflow
        }
        #expect {
            // 1 * NaN
            _ = try one._multiply(by: nan, roundingMode: .plain)
        } throws: {
            ($0 as? Decimal._CalculationError) == .overflow
        }

        #expect {
            // NaN / 1
            _ = try nan._divide(by: one, roundingMode: .plain)
        } throws: {
            ($0 as? Decimal._CalculationError) == .overflow
        }
        #expect {
            // 1 / NaN
            _ = try one._divide(by: nan, roundingMode: .plain)
        } throws: {
            ($0 as? Decimal._CalculationError) == .overflow
        }

        #expect {
            // NaN ^ 0
            _ = try nan._power(exponent: 0, roundingMode: .plain)
        } throws: {
            ($0 as? Decimal._CalculationError) == .overflow
        }
        #expect {
            // NaN ^ 1
            _ = try nan._power(exponent: 1, roundingMode: .plain)
        } throws: {
            ($0 as? Decimal._CalculationError) == .overflow
        }

        // Overflow doubles
        #expect(Decimal(Double.leastNonzeroMagnitude).isNaN)
        #expect(Decimal(Double.leastNormalMagnitude).isNaN)
        #expect(Decimal(Double.greatestFiniteMagnitude).isNaN)
        #expect(Decimal(Double("1e-129")!).isNaN)
        #expect(Decimal(Double("0.1e-128")!).isNaN)
    }

    @Test func testDecimalRoundBankers() throws {
        let onePointTwo = Decimal(1.2)
        var result = try onePointTwo._round(scale: 1, roundingMode: .bankers)
        #expect((1.1009 ... 1.2001).contains(result.doubleValue))

        let onePointTwoOne = Decimal(1.21)
        result = try onePointTwoOne._round(scale: 1, roundingMode: .bankers)
        #expect((1.1009 ... 1.2001).contains(result.doubleValue))

        let onePointTwoFive = Decimal(1.25)
        result = try onePointTwoFive._round(scale: 1, roundingMode: .bankers)
        #expect((1.1009 ... 1.2001).contains(result.doubleValue))

        let onePointThreeFive = Decimal(1.35)
        result = try onePointThreeFive._round(scale: 1, roundingMode: .bankers)
        #expect((1.3009 ... 1.4001).contains(result.doubleValue))

        let onePointTwoSeven = Decimal(1.27)
        result = try onePointTwoSeven._round(scale: 1, roundingMode: .bankers)
        #expect((1.2009 ... 3.2001).contains(result.doubleValue))

        let minusEightPointFourFive = Decimal(-8.45)
        result = try minusEightPointFourFive._round(scale: 1, roundingMode: .bankers)
        #expect((-8.4001 ... -8.3009).contains(result.doubleValue))

        let minusFourPointNineEightFive = Decimal(-4.985)
        result = try minusFourPointNineEightFive._round(scale: 2, roundingMode: .bankers)
        #expect((-4.9801 ... -4.9709).contains(result.doubleValue))
    }

    @Test func test_Round() throws {
        let testCases: [(Double, Double, Int, Decimal.RoundingMode)] = [
            // expected, start, scale, round
            ( 0, 0.5, 0, .down ),
            ( 1, 0.5, 0, .up ),
            ( 2, 2.5, 0, .bankers ),
            ( 4, 3.5, 0, .bankers ),
            ( 5, 5.2, 0, .plain ),
            ( 4.5, 4.5, 1, .down ),
            ( 5.5, 5.5, 1, .up ),
            ( 6.5, 6.5, 1, .plain ),
            ( 7.5, 7.5, 1, .bankers ),

            ( -1, -0.5, 0, .down ),
            ( -2, -2.5, 0, .up ),
            ( -2, -2.5, 0, .bankers ),
            ( -4, -3.5, 0, .bankers ),
            ( -5, -5.2, 0, .plain ),
            ( -4.5, -4.5, 1, .down ),
            ( -5.5, -5.5, 1, .up ),
            ( -6.5, -6.5, 1, .plain ),
            ( -7.5, -7.5, 1, .bankers ),
        ]
        for testCase in testCases {
            let (expected, start, scale, mode) = testCase
            let num = Decimal(start)
            let actual = try num._round(scale: scale, roundingMode: mode)
            #expect(Decimal(expected) == actual, "Failed test case: \(testCase)")
        }
    }

    @Test func test_Maths() {
        for i in -2...10 {
            for j in 0...5 {
                #expect(Decimal(i*j) == Decimal(i) * Decimal(j), "\(Decimal(i*j)) == \(i) * \(j)")
                #expect(Decimal(i+j) == Decimal(i) + Decimal(j), "\(Decimal(i+j)) == \(i)+\(j)")
                #expect(Decimal(i-j) == Decimal(i) - Decimal(j), "\(Decimal(i-j)) == \(i)-\(j)")
                if j != 0 {
                    let approximation = Decimal(Double(i)/Double(j))
                    let answer = Decimal(i) / Decimal(j)
                    let answerDescription = answer.description
                    let approximationDescription = approximation.description
                    var failed: Bool = false
                    var count = 0
                    let SIG_FIG = 14
                    for (a, b) in zip(answerDescription, approximationDescription) {
                        if a != b {
                            failed = true
                            break
                        }
                        if count == 0 && (a == "-" || a == "0" || a == ".") {
                            continue // don't count these as significant figures
                        }
                        if count >= SIG_FIG {
                            break
                        }
                        count += 1
                    }
                    #expect(!failed, "\(Decimal(i/j)) == \(i)/\(j)")
                }
            }
        }

        #expect(Decimal(186243 * 15673 as Int64) == Decimal(186243) * Decimal(15673))

        #expect(Decimal(string: "5538")! + Decimal(string: "2880.4")! == Decimal(string: "8418.4")!)

        #expect(Decimal(string: "5538.0")! - Decimal(string: "2880.4")! == Decimal(string: "2657.6")!)
        #expect(Decimal(string: "2880.4")! - Decimal(5538) == Decimal(string: "-2657.6")!)
        #expect(Decimal(0x10000) - Decimal(0x1000) == Decimal(0xf000))
#if !os(watchOS)
        #expect(Decimal(0x1_0000_0000) - Decimal(0x1000) == Decimal(0xFFFFF000))
        #expect(Decimal(0x1_0000_0000_0000) - Decimal(0x1000) == Decimal(0xFFFFFFFFF000))
#endif
        #expect(Decimal(1234_5678_9012_3456_7899 as UInt64) - Decimal(1234_5678_9012_3456_7890 as UInt64) == Decimal(9))
        #expect(Decimal(0xffdd_bb00_8866_4422 as UInt64) - Decimal(0x7777_7777) == Decimal(0xFFDD_BB00_10EE_CCAB as UInt64))

        let highBit = Decimal(_exponent: 0, _length: 8, _isNegative: 0, _isCompact: 1, _reserved: 0, _mantissa: (0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x8000))
        let otherBits = Decimal(_exponent: 0, _length: 8, _isNegative: 0, _isCompact: 1, _reserved: 0, _mantissa: (0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0x7fff))
        #expect(highBit - otherBits == Decimal(1))
        #expect(otherBits + Decimal(1) == highBit)
    }

    @Test func testMisc() throws {
        #expect(Decimal(-5.2).sign == .minus)
        #expect(Decimal(5.2).sign == .plus)
        var d = Decimal(5.2)
        #expect(d.sign == .plus)
        d.negate()
        #expect(d.sign == .minus)
        d.negate()
        #expect(d.sign == .plus)
        var e = Decimal(0)
        e.negate()
        #expect(e == Decimal(0))
        #expect(Decimal(3.5).isEqual(to: Decimal(3.5)))
        #expect(Decimal.nan.isEqual(to: Decimal.nan))
        #expect(Decimal(1.28).isLess(than: Decimal(2.24)))
        #expect(!Decimal(2.28).isLess(than: Decimal(2.24)))
        #expect(Decimal(1.28).isTotallyOrdered(belowOrEqualTo: Decimal(2.24)))
        #expect(!Decimal(2.28).isTotallyOrdered(belowOrEqualTo: Decimal(2.24)))
        #expect(Decimal(1.2).isTotallyOrdered(belowOrEqualTo: Decimal(1.2)))
        #expect(Decimal.nan.isEqual(to: Decimal.nan))
        #expect(Decimal.nan.isLess(than: Decimal(0)))
        #expect(!Decimal.nan.isLess(than: Decimal.nan))
        #expect(Decimal.nan.isLessThanOrEqualTo(Decimal(0)))
        #expect(Decimal.nan.isLessThanOrEqualTo(Decimal.nan))
        #expect(!Decimal.nan.isTotallyOrdered(belowOrEqualTo: Decimal.nan))
        #expect(!Decimal.nan.isTotallyOrdered(belowOrEqualTo: Decimal(2.3)))
        #expect(Decimal(2) < Decimal(3))
        #expect(Decimal(3) > Decimal(2))
        #expect(Decimal(-9) == Decimal(1) - Decimal(10))
        #expect(Decimal(476) == Decimal(1024).distance(to: Decimal(1500)))
        #expect(Decimal(68040) == Decimal(386).advanced(by: Decimal(67654)))
        #expect(Decimal(1.234) == abs(Decimal(1.234)))
        #expect(Decimal(1.234) == abs(Decimal(-1.234)))
        #expect(Decimal.nan.magnitude.isNaN)
        #expect(Decimal.leastFiniteMagnitude.magnitude == -Decimal.leastFiniteMagnitude)

        #expect(Decimal(-9) == Decimal(1) - Decimal(10))
        #expect(Decimal(1.234) == abs(Decimal(1.234)))
        #expect(Decimal(1.234) == abs(Decimal(-1.234)))
        #expect((0 as Decimal).magnitude == 0 as Decimal)
        #expect((1 as Decimal).magnitude == 1 as Decimal)
        #expect((1 as Decimal).magnitude == abs(1 as Decimal))
        #expect((1 as Decimal).magnitude == abs(-1 as Decimal))
        #expect((-1 as Decimal).magnitude == abs(-1 as Decimal))
        #expect((-1 as Decimal).magnitude == abs(1 as Decimal))
        #expect(Decimal.greatestFiniteMagnitude.magnitude == Decimal.greatestFiniteMagnitude)

        var a = Decimal(1234)
        var result = try a._multiplyByPowerOfTen(power: 1, roundingMode: .plain)
        #expect(Decimal(12340) == result)
        a = Decimal(1234)
        result = try a._multiplyByPowerOfTen(power: 2, roundingMode: .plain)
        #expect(Decimal(123400) == result)
        a = result
        #expect {
            result = try a._multiplyByPowerOfTen(power: 128, roundingMode: .plain)
        } throws: {
            ($0 as? Decimal._CalculationError) == .overflow
        }
        a = Decimal(1234)
        result = try a._multiplyByPowerOfTen(power: -2, roundingMode: .plain)
        #expect(Decimal(12.34) == result)
        a = result
        #expect {
            result = try a._multiplyByPowerOfTen(power: -128, roundingMode: .plain)
        } throws: {
            ($0 as? Decimal._CalculationError) == .underflow
        }
        a = Decimal(1234)
        result = try a._power(exponent: 0, roundingMode: .plain)
        #expect(Decimal(1) == result)
        a = Decimal(8)
        result = try a._power(exponent: 2, roundingMode: .plain)
        #expect(Decimal(64) == result)
        a = Decimal(-2)
        result = try a._power(exponent: 3, roundingMode: .plain)
        #expect(Decimal(-8) == result)
        for i in -2...10 {
            for j in 0...5 {
                let power = Decimal(i)
                let actual = try power._power(exponent: j, roundingMode: .plain)
                let expected = Decimal(pow(Double(i), Double(j)))
                #expect(expected == actual, "\(actual) == \(i)^\(j)")
                #expect(try expected == power._power(exponent: j, roundingMode: .plain))
            }
        }

        do {
            // SR-13015
            let a = try #require(Decimal(string: "119.993"))
            let b = try #require(Decimal(string: "4.1565"))
            let c = try #require(Decimal(string: "18.209"))
            let d = try #require(Decimal(string: "258.469"))
            let ab = a * b
            let aDivD = a / d
            let caDivD = c * aDivD
            #expect(try ab == #require(Decimal(string: "498.7509045")))
            #expect(try aDivD == #require(Decimal(string: "0.46424522863476857959755328492004843907")))
            #expect(try caDivD == #require(Decimal(string: "8.453441368210501065891847765109162027")))

            let result = (a * b) + (c * (a / d))
            #expect(try result == #require(Decimal(string: "507.2043458682105010658918477651091")))
        }
    }

    @Test func test_Constants() {
        let smallest = Decimal(_exponent: 127, _length: 8, _isNegative: 1, _isCompact: 1, _reserved: 0, _mantissa: (UInt16.max, UInt16.max, UInt16.max, UInt16.max, UInt16.max, UInt16.max, UInt16.max, UInt16.max))
        #expect(smallest == Decimal.leastFiniteMagnitude)
        let biggest = Decimal(_exponent: 127, _length: 8, _isNegative: 0, _isCompact: 1, _reserved: 0, _mantissa: (UInt16.max, UInt16.max, UInt16.max, UInt16.max, UInt16.max, UInt16.max, UInt16.max, UInt16.max))
        #expect(biggest == Decimal.greatestFiniteMagnitude)
        let leastNormal = Decimal(_exponent: -127, _length: 1, _isNegative: 0, _isCompact: 1, _reserved: 0, _mantissa: (1, 0, 0, 0, 0, 0, 0, 0))
        #expect(leastNormal == Decimal.leastNormalMagnitude)
        let leastNonzero = Decimal(_exponent: -127, _length: 1, _isNegative: 0, _isCompact: 1, _reserved: 0, _mantissa: (1, 0, 0, 0, 0, 0, 0, 0))
        #expect(leastNonzero == Decimal.leastNonzeroMagnitude)
        let pi = Decimal(_exponent: -38, _length: 8, _isNegative: 0, _isCompact: 1, _reserved: 0, _mantissa: (0x6623, 0x7d57, 0x16e7, 0xad0d, 0xaf52, 0x4641, 0xdfa7, 0xec58))
        #expect(pi == Decimal.pi)
        #expect(10 == Decimal.radix)
        #expect(Decimal().isCanonical)
        #expect(!Decimal().isSignalingNaN)
        #expect(!Decimal.nan.isSignalingNaN)
        #expect(Decimal.nan.isNaN)
        #expect(.quietNaN == Decimal.nan.floatingPointClass)
        #expect(.positiveZero == Decimal().floatingPointClass)
        #expect(.negativeNormal == smallest.floatingPointClass)
        #expect(.positiveNormal == biggest.floatingPointClass)
        #expect(!Double.nan.isFinite)
        #expect(!Double.nan.isInfinite)
    }

    @Test func test_parseDouble() throws {
        #expect(Decimal(Double(0.0)) == Decimal(Int.zero))
        #expect(Decimal(Double(-0.0)) == Decimal(Int.zero))

        // These values can only be represented as Decimal.nan
        #expect(Decimal(Double.nan) == Decimal.nan)
        #expect(Decimal(Double.signalingNaN) == Decimal.nan)

        // These values are out out range for Decimal
        #expect(Decimal(-Double.leastNonzeroMagnitude) == Decimal.nan)
        #expect(Decimal(Double.leastNonzeroMagnitude) == Decimal.nan)
        #expect(Decimal(-Double.leastNormalMagnitude) == Decimal.nan)
        #expect(Decimal(Double.leastNormalMagnitude) == Decimal.nan)
        #expect(Decimal(-Double.greatestFiniteMagnitude) == Decimal.nan)
        #expect(Decimal(Double.greatestFiniteMagnitude) == Decimal.nan)

        // SR-13837
        let testDoubles: [(Double, String)] = [
            (1.8446744073709550E18, "1844674407370954752"),
            (1.8446744073709551E18, "1844674407370954752"),
            (1.8446744073709552E18, "1844674407370955264"),
            (1.8446744073709553E18, "1844674407370955264"),
            (1.8446744073709554E18, "1844674407370955520"),
            (1.8446744073709555E18, "1844674407370955520"),

            (1.8446744073709550E19, "18446744073709547520"),
            (1.8446744073709551E19, "18446744073709552640"),
            (1.8446744073709552E19, "18446744073709552640"),
            (1.8446744073709553E19, "18446744073709552640"),
            (1.8446744073709554E19, "18446744073709555200"),
            (1.8446744073709555E19, "18446744073709555200"),

            (1.8446744073709550E20, "184467440737095526400"),
            (1.8446744073709551E20, "184467440737095526400"),
            (1.8446744073709552E20, "184467440737095526400"),
            (1.8446744073709553E20, "184467440737095526400"),
            (1.8446744073709554E20, "184467440737095552000"),
            (1.8446744073709555E20, "184467440737095552000"),
        ]

        for (d, s) in testDoubles {
            #expect(Decimal(d) == Decimal(string: s))
            let parsed = try #require(Decimal(string: s))
            #expect(Decimal(d).description == parsed.description)
        }
    }

    @Test func test_initExactly() {
        // This really requires some tests using a BinaryInteger of bitwidth > 128 to test failures.
        let d1 = Decimal(exactly: UInt64.max)
        #expect(d1 != nil)
        #expect(d1?.description == UInt64.max.description)
        #expect(d1?._length == 4)

        let d2 = Decimal(exactly: Int64.min)
        #expect(d2 != nil)
        #expect(d2?.description == Int64.min.description)
        #expect(d2?._length == 4)

        let d3 = Decimal(exactly: Int64.max)
        #expect(d3 != nil)
        #expect(d3?.description == Int64.max.description)
        #expect(d3?._length == 4)

        let d4 = Decimal(exactly: Int32.min)
        #expect(d4 != nil)
        #expect(d4?.description == Int32.min.description)
        #expect(d4?._length == 2)

        let d5 = Decimal(exactly: Int32.max)
        #expect(d5 != nil)
        #expect(d5?.description == Int32.max.description)
        #expect(d5?._length == 2)

        let d6 = Decimal(exactly: 0)
        #expect(d6 != nil)
        #expect(d6 == Decimal.zero)
        #expect(d6?.description == "0")
        #expect(d6?._length == 0)

        let d7 = Decimal(exactly: 1)
        #expect(d7 != nil)
        #expect(d7?.description == "1")
        #expect(d7?._length == 1)

        let d8 = Decimal(exactly: -1)
        #expect(d8 != nil)
        #expect(d8?.description == "-1")
        #expect(d8?._length == 1)
    }

    @Test func test_Strideable() {
        let x = 42 as Decimal
        #expect(x.distance(to: 43) == 1)
        #expect(x.advanced(by: 1) == 43)
        #expect(x.distance(to: 41) == -1)
        #expect(x.advanced(by: -1) == 41)
    }

    @Test func test_Significand() {
        var x = -42 as Decimal
        #expect(x.significand.sign == .plus)
        var y = Decimal(sign: .plus, exponent: 0, significand: x)
        #expect(y == -42)
        y = Decimal(sign: .minus, exponent: 0, significand: x)
        #expect(y == 42)

        x = 42 as Decimal
        #expect(x.significand.sign == .plus)
        y = Decimal(sign: .plus, exponent: 0, significand: x)
        #expect(y == 42)
        y = Decimal(sign: .minus, exponent: 0, significand: x)
        #expect(y == -42)

        let a = Decimal.leastNonzeroMagnitude
        #expect(Decimal(sign: .plus, exponent: -10, significand: a) == 0)
        #expect(Decimal(sign: .plus, exponent: .min, significand: a) == 0)
        let b = Decimal.greatestFiniteMagnitude
        #expect(Decimal(sign: .plus, exponent: 10, significand: b).isNaN)
        #expect(Decimal(sign: .plus, exponent: .max, significand: b).isNaN)
    }

    @Test func test_ULP() {
        var x = 0.1 as Decimal
        #expect(x.ulp <= x)

        x = .nan
        #expect(x.ulp.isNaN)
        #expect(x.nextDown.isNaN)
        #expect(x.nextUp.isNaN)

        x = .greatestFiniteMagnitude
        #expect(x.ulp == Decimal(string: "1e127")!)
        #expect(x.nextDown == x - Decimal(string: "1e127")!)
        #expect(x.nextUp.isNaN)

        // '4' is an important value to test because the max supported
        // significand of this type is not 10 ** 38 - 1 but rather 2 ** 128 - 1,
        // for which reason '4.ulp' is not equal to '1.ulp' despite having the
        // same decimal exponent.
        x = 4
        #expect(x.ulp == Decimal(string: "1e-37")!)
        #expect(x.nextDown == x - Decimal(string: "1e-37")!)
        #expect(x.nextUp == x + Decimal(string: "1e-37")!)
        #expect(x.nextDown.nextUp == x)
        #expect(x.nextUp.nextDown == x)
        #expect(x.nextDown != x)
        #expect(x.nextUp != x)

        // For similar reasons, '3.40282366920938463463374607431768211455',
        // which has the same significand as 'Decimal.greatestFiniteMagnitude',
        // is an important value to test because the distance to the next
        // representable value is more than 'ulp' and instead requires
        // incrementing '_exponent'.
        x = Decimal(string: "3.40282366920938463463374607431768211455")!
        #expect(x.ulp == Decimal(string: "0.00000000000000000000000000000000000001")!)
        #expect(x.nextUp == Decimal(string: "3.4028236692093846346337460743176821146")!)
        x = Decimal(string: "3.4028236692093846346337460743176821146")!
        #expect(x.ulp == Decimal(string: "0.0000000000000000000000000000000000001")!)
        #expect(x.nextDown == Decimal(string: "3.40282366920938463463374607431768211455")!)

        x = 1
        #expect(x.ulp == Decimal(string: "1e-38")!)
        #expect(x.nextDown == x - Decimal(string: "1e-38")!)
        #expect(x.nextUp == x + Decimal(string: "1e-38")!)
        #expect(x.nextDown.nextUp == x)
        #expect(x.nextUp.nextDown == x)
        #expect(x.nextDown != x)
        #expect(x.nextUp != x)

        x = 0
        #expect(x.ulp == Decimal(string: "1e-128")!)
        #expect(x.nextDown == -Decimal(string: "1e-128")!)
        #expect(x.nextUp == Decimal(string: "1e-128")!)
        #expect(x.nextDown.nextUp == x)
        #expect(x.nextUp.nextDown == x)
        #expect(x.nextDown != x)
        #expect(x.nextUp != x)

        x = -1
        #expect(x.ulp == Decimal(string: "1e-38")!)
        #expect(x.nextDown == x - Decimal(string: "1e-38")!)
        #expect(x.nextUp == x + Decimal(string: "1e-38")!)
        let y = x - x.ulp + x.ulp
        #expect(x == y)
        #expect(x.nextDown.nextUp == x)
        #expect(x.nextUp.nextDown == x)
        #expect(x.nextDown != x)
        #expect(x.nextUp != x)
    }

    #if FOUNDATION_FRAMEWORK
    #else
    @Test func test_int64Value() {
        #expect(Decimal(-1).int64Value == -1)
        #expect(Decimal(0).int64Value == 0)
        #expect(Decimal(1).int64Value == 1)
        #expect(Decimal.nan.int64Value == 0)
        #expect(Decimal(1e50).int64Value == 0)
        #expect(Decimal(1e-50).int64Value == 0)

        #expect(Decimal(UInt64.max).uint64Value == UInt64.max)
        #expect((Decimal(UInt64.max) + 1).uint64Value == 0)
        #expect(Decimal(Int64.max).int64Value == Int64.max)
        #expect((Decimal(Int64.max) + 1 ).int64Value == Int64.min)
        #expect((Decimal(Int64.max) + 1 ).uint64Value == UInt64(Int64.max) + 1)
        #expect(Decimal(Int64.min).int64Value == Int64.min)

        #expect(Decimal(Int.min).int64Value == Int64(Int.min))

        let div3 = Decimal(10) / 3
        #expect(div3.int64Value == 3)
        let pi = Decimal(Double.pi)
        #expect(pi.int64Value == 3)
    }

    @Test func test_doubleValue() {
        #expect(Decimal(0).doubleValue == 0)
        #expect(Decimal(1).doubleValue == 1)
        #expect(Decimal(-1).doubleValue == -1)
        #expect(Decimal.nan.doubleValue.isNaN)
        #expect(Decimal(UInt64.max).doubleValue == Double(1.8446744073709552e+19))
    }
    
    @Test func test_decimalFromString() {
        let string = "x123x"
        let scanLocation = 1
        
        let start = string.index(string.startIndex, offsetBy: scanLocation, limitedBy: string.endIndex)!
        let substring = string[start..<string.endIndex]
        let view = String(substring).utf8
        let (result, length) = Decimal.decimal(from: view, decimalSeparator: ".".utf8, matchEntireString: false)
        #expect(result == Decimal(123))
        #expect(length == 3)
    }
    #endif

    @Test func testNegativePower() throws {
        func test(withBase base: Decimal, power: Int, sourceLocation: SourceLocation = #_sourceLocation) throws {
            #expect(
                try base._power(exponent: -power, roundingMode: .plain) ==
                Decimal(1)/base._power(exponent: power, roundingMode: .plain),
                "Base: \(base), Power: \(power)",
                sourceLocation: sourceLocation
            )
        }
        // Negative Exponent Rule
        // x^-n = 1/(x^n)
        for power in 2 ..< 10 {
            // Positive Integer base
            try test(withBase: Decimal(Int.random(in: 1 ..< 10)), power: power)

            // Negative Integer base
            try test(withBase: Decimal(Int.random(in: -10 ..< -1)), power: power)

            // Postive Double base
            try test(withBase: Decimal(Double.random(in: 0 ..< 1.0)), power: power)

            // Negative Double base
            try test(withBase: Decimal(Double.random(in: -1.0 ..< 0.0)), power: power)

            // For zero base: 0^n = 0; 0^(-n) = nan
            #expect(
                try Decimal(0)._power(exponent: power, roundingMode: .plain) ==
                Decimal(0)
            )
            #expect(
                try Decimal(0)._power(exponent: -power, roundingMode: .plain) ==
                Decimal.nan
            )
        }

    }
}
