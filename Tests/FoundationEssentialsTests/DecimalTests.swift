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

#if canImport(TestSupport)
import TestSupport
#endif  // canImport(TestSupport)

#if FOUNDATION_FRAMEWORK
import Foundation
#else
@_spi(SwiftCorelibsFoundation)
import FoundationEssentials
#endif

final class DecimalTests : XCTestCase {
#if !FOUNDATION_FRAMEWORK // These tests tests the stub implementations
    func assertMantissaEquals(lhs: Decimal, rhs: Decimal.Mantissa) {
        XCTAssertEqual(lhs[0], rhs.0, "Mantissa.0 does not equal: \(lhs[0]) vs \(rhs.0)")
        XCTAssertEqual(lhs[1], rhs.1, "Mantissa.1 does not equal: \(lhs[1]) vs \(rhs.1)")
        XCTAssertEqual(lhs[2], rhs.2, "Mantissa.2 does not equal: \(lhs[2]) vs \(rhs.2)")
        XCTAssertEqual(lhs[3], rhs.3, "Mantissa.3 does not equal: \(lhs[3]) vs \(rhs.3)")
        XCTAssertEqual(lhs[4], rhs.4, "Mantissa.4 does not equal: \(lhs[4]) vs \(rhs.4)")
        XCTAssertEqual(lhs[5], rhs.5, "Mantissa.5 does not equal: \(lhs[5]) vs \(rhs.5)")
        XCTAssertEqual(lhs[6], rhs.6, "Mantissa.6 does not equal: \(lhs[6]) vs \(rhs.6)")
        XCTAssertEqual(lhs[7], rhs.7, "Mantissa.7 does not equal: \(lhs[7]) vs \(rhs.7)")
    }

    func testDecimalRoundtripFuzzing() {
        let iterations = 100
        for _ in 0 ..< iterations {
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

            XCTAssertEqual(decimal._exponent, exponent)
            XCTAssertEqual(decimal._length, length)
            XCTAssertEqual(decimal._isNegative, isNegative)
            XCTAssertEqual(decimal._isCompact, isCompact)
            XCTAssertEqual(decimal._reserved, reserved)
            assertMantissaEquals(
                lhs: decimal,
                rhs: mantissa
            )

            // Update invidividual values
            length = .random(in: 0 ..< 0xF)
            decimal._length = length
            XCTAssertEqual(decimal._length, length)
        }
    }

#endif

    func testAbusiveCompact() {
        var decimal = Decimal()
        decimal._exponent = 5
        decimal._length = 5
        decimal.compact()
        XCTAssertEqual(Decimal.zero, decimal);
    }

    func test_Description() {
        XCTAssertEqual("0", Decimal().description)
        XCTAssertEqual("0", Decimal(0).description)
        XCTAssertEqual("10", Decimal(_exponent: 1, _length: 1, _isNegative: 0, _isCompact: 1, _reserved: 0, _mantissa: (1, 0, 0, 0, 0, 0, 0, 0)).description)
        XCTAssertEqual("10", Decimal(10).description)
        XCTAssertEqual("123.458", Decimal(_exponent: -3, _length: 2, _isNegative: 0, _isCompact:1, _reserved: 0, _mantissa: (57922, 1, 0, 0, 0, 0, 0, 0)).description)
        XCTAssertEqual("123.458", Decimal(123.458).description)
        XCTAssertEqual("123", Decimal(UInt8(123)).description)
        XCTAssertEqual("45", Decimal(Int8(45)).description)
        XCTAssertEqual("3.14159265358979323846264338327950288419", Decimal.pi.description)
        XCTAssertEqual("-30000000000", Decimal(sign: .minus, exponent: 10, significand: Decimal(3)).description)
        XCTAssertEqual("300000", Decimal(sign: .plus, exponent: 5, significand: Decimal(3)).description)
        XCTAssertEqual("5", Decimal(signOf: Decimal(3), magnitudeOf: Decimal(5)).description)
        XCTAssertEqual("-5", Decimal(signOf: Decimal(-3), magnitudeOf: Decimal(5)).description)
        XCTAssertEqual("5", Decimal(signOf: Decimal(3), magnitudeOf: Decimal(-5)).description)
        XCTAssertEqual("-5", Decimal(signOf: Decimal(-3), magnitudeOf: Decimal(-5)).description)
    }

    func test_DescriptionWithLocale() {
        let decimal = Decimal(string: "-123456.789")!
        XCTAssertEqual(decimal._toString(withDecimalSeparator: "."), "-123456.789")
        let en = decimal._toString(withDecimalSeparator: Locale(identifier: "en_GB").decimalSeparator!)
        XCTAssertEqual(en, "-123456.789")
        let fr = decimal._toString(withDecimalSeparator: Locale(identifier: "fr_FR").decimalSeparator!)
        XCTAssertEqual(fr, "-123456,789")
    }

    func test_BasicConstruction() {
        let zero = Decimal()
        XCTAssertEqual(20, MemoryLayout<Decimal>.size)
        XCTAssertEqual(0, zero._exponent)
        XCTAssertEqual(0, zero._length)
        XCTAssertEqual(0, zero._isNegative)
        XCTAssertEqual(0, zero._isCompact)
        XCTAssertEqual(0, zero._reserved)
        let (m0, m1, m2, m3, m4, m5, m6, m7) = zero._mantissa
        XCTAssertEqual(0, m0)
        XCTAssertEqual(0, m1)
        XCTAssertEqual(0, m2)
        XCTAssertEqual(0, m3)
        XCTAssertEqual(0, m4)
        XCTAssertEqual(0, m5)
        XCTAssertEqual(0, m6)
        XCTAssertEqual(0, m7)
        XCTAssertEqual(8, Decimal.maxSize)
        XCTAssertEqual(32767, CShort.max)
        XCTAssertFalse(zero.isNormal)
        XCTAssertTrue(zero.isFinite)
        XCTAssertTrue(zero.isZero)
        XCTAssertFalse(zero.isSubnormal)
        XCTAssertFalse(zero.isInfinite)
        XCTAssertFalse(zero.isNaN)
        XCTAssertFalse(zero.isSignaling)

        let d1 = Decimal(1234567890123456789 as UInt64)
        XCTAssertEqual(d1._exponent, 0)
        XCTAssertEqual(d1._length, 4)
    }

    func test_ExplicitConstruction() {
        var explicit = Decimal(
            _exponent: 0x17f,
            _length: 0xff,
            _isNegative: 3,
            _isCompact: 4,
            _reserved: UInt32(1<<18 + 1<<17 + 1),
            _mantissa: (6, 7, 8, 9, 10, 11, 12, 13)
        )
        XCTAssertEqual(0x7f, explicit._exponent)
        XCTAssertEqual(0x7f, explicit.exponent)
        XCTAssertEqual(0x0f, explicit._length)
        XCTAssertEqual(1, explicit._isNegative)
        XCTAssertEqual(FloatingPointSign.minus, explicit.sign)
        XCTAssertTrue(explicit.isSignMinus)
        XCTAssertEqual(0, explicit._isCompact)
        XCTAssertEqual(UInt32(1<<17 + 1), explicit._reserved)
        let (m0, m1, m2, m3, m4, m5, m6, m7) = explicit._mantissa
        XCTAssertEqual(6, m0)
        XCTAssertEqual(7, m1)
        XCTAssertEqual(8, m2)
        XCTAssertEqual(9, m3)
        XCTAssertEqual(10, m4)
        XCTAssertEqual(11, m5)
        XCTAssertEqual(12, m6)
        XCTAssertEqual(13, m7)
        explicit._isCompact = 5
        explicit._isNegative = 6
        XCTAssertEqual(0, explicit._isNegative)
        XCTAssertEqual(1, explicit._isCompact)
        XCTAssertEqual(FloatingPointSign.plus, explicit.sign)
        XCTAssertFalse(explicit.isSignMinus)
        XCTAssertTrue(explicit.isNormal)

        let significand = explicit.significand
        XCTAssertEqual(0, significand._exponent)
        XCTAssertEqual(0, significand.exponent)
        XCTAssertEqual(0x0f, significand._length)
        XCTAssertEqual(0, significand._isNegative)
        XCTAssertEqual(1, significand._isCompact)
        XCTAssertEqual(0, significand._reserved)
        let (sm0, sm1, sm2, sm3, sm4, sm5, sm6, sm7) = significand._mantissa
        XCTAssertEqual(6, sm0)
        XCTAssertEqual(7, sm1)
        XCTAssertEqual(8, sm2)
        XCTAssertEqual(9, sm3)
        XCTAssertEqual(10, sm4)
        XCTAssertEqual(11, sm5)
        XCTAssertEqual(12, sm6)
        XCTAssertEqual(13, sm7)
    }

    func test_ScanDecimal() throws {
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
            let decimal = Decimal(string:string)!
            let aboutOne = Decimal(expected) / decimal
            let approximatelyRight = aboutOne >= Decimal(0.99999) && aboutOne <= Decimal(1.00001)
            XCTAssertTrue(approximatelyRight, "\(expected) ~= \(decimal) : \(aboutOne) \(aboutOne >= Decimal(0.99999)) \(aboutOne <= Decimal(1.00001))" )
        }
        guard let answer = Decimal(string:"12345679012345679012345679012345679012.3") else {
            XCTFail("Unable to parse Decimal(string:'12345679012345679012345679012345679012.3')")
            return
        }
        guard let ones = Decimal(string:"111111111111111111111111111111111111111") else {
            XCTFail("Unable to parse Decimal(string:'111111111111111111111111111111111111111')")
            return
        }
        let num = ones / Decimal(9)
        XCTAssertEqual(answer,num,"\(ones) / 9 = \(answer) \(num)")

        // Exponent overflow, returns nil
        XCTAssertNil(Decimal(string: "1e200"))
        XCTAssertNil(Decimal(string: "1e-200"))
        XCTAssertNil(Decimal(string: "1e300"))
        XCTAssertNil(Decimal(string: "1" + String(repeating: "0", count: 170)))
        XCTAssertNil(Decimal(string: "0." + String(repeating: "0", count: 170) + "1"))
        XCTAssertNil(Decimal(string: "0e200"))

        // Parsing zero in different forms
        let zero1 = try XCTUnwrap(Decimal(string: "000.000e123"))
        XCTAssertTrue(zero1.isZero)
        XCTAssertEqual(zero1._isNegative, 0)
        XCTAssertEqual(zero1._length, 0)
        XCTAssertEqual(zero1.description, "0")

        let zero2 = try XCTUnwrap(Decimal(string: "+000.000e-123"))
        XCTAssertTrue(zero2.isZero)
        XCTAssertEqual(zero2._isNegative, 0)
        XCTAssertEqual(zero2._length, 0)
        XCTAssertEqual(zero2.description, "0")

        let zero3 = try XCTUnwrap(Decimal(string: "-0.0e1"))
        XCTAssertTrue(zero3.isZero)
        XCTAssertEqual(zero3._isNegative, 0)
        XCTAssertEqual(zero3._length, 0)
        XCTAssertEqual(zero3.description, "0")

        // Bin compat: invalid strings starting with E should be parsed as 0
        var zeroE = try XCTUnwrap(Decimal(string: "en"))
        XCTAssertTrue(zeroE.isZero)
        zeroE = try XCTUnwrap(Decimal(string: "e"))
        XCTAssertTrue(zeroE.isZero)
        // Partitally valid strings ending with e shold be parsed
        let notZero = try XCTUnwrap(Decimal(string: "123e"))
        XCTAssertEqual(notZero, Decimal(123))
    }

    func test_stringWithLocale() {

        let en_US = Locale(identifier: "en_US")
        let fr_FR = Locale(identifier: "fr_FR")

        XCTAssertEqual(Decimal(string: "1,234.56")! * 1000, Decimal(1000))
        XCTAssertEqual(Decimal(string: "1,234.56", locale: en_US)! * 1000, Decimal(1000))
        XCTAssertEqual(Decimal(string: "1,234.56", locale: fr_FR)! * 1000, Decimal(1234))
        XCTAssertEqual(Decimal(string: "1.234,56", locale: en_US)! * 1000, Decimal(1234))
        XCTAssertEqual(Decimal(string: "1.234,56", locale: fr_FR)! * 1000, Decimal(1000))

        XCTAssertEqual(Decimal(string: "-1,234.56")! * 1000, Decimal(-1000))
        XCTAssertEqual(Decimal(string: "+1,234.56")! * 1000, Decimal(1000))
        XCTAssertEqual(Decimal(string: "+1234.56e3"), Decimal(1234560))
        XCTAssertEqual(Decimal(string: "+1234.56E3"), Decimal(1234560))
        XCTAssertEqual(Decimal(string: "+123456000E-3"), Decimal(123456))

        XCTAssertNil(Decimal(string: ""))
        XCTAssertNil(Decimal(string: "x"))
        XCTAssertEqual(Decimal(string: "-x"), Decimal.zero)
        XCTAssertEqual(Decimal(string: "+x"), Decimal.zero)
        XCTAssertEqual(Decimal(string: "-"), Decimal.zero)
        XCTAssertEqual(Decimal(string: "+"), Decimal.zero)
        XCTAssertEqual(Decimal(string: "-."), Decimal.zero)
        XCTAssertEqual(Decimal(string: "+."), Decimal.zero)

        XCTAssertEqual(Decimal(string: "-0"), Decimal.zero)
        XCTAssertEqual(Decimal(string: "+0"), Decimal.zero)
        XCTAssertEqual(Decimal(string: "-0."), Decimal.zero)
        XCTAssertEqual(Decimal(string: "+0."), Decimal.zero)
        XCTAssertEqual(Decimal(string: "e1"), Decimal.zero)
        XCTAssertEqual(Decimal(string: "e-5"), Decimal.zero)
        XCTAssertEqual(Decimal(string: ".3e1"), Decimal(3))

        XCTAssertEqual(Decimal(string: "."), Decimal.zero)
        XCTAssertEqual(Decimal(string: ".", locale: en_US), Decimal.zero)
        XCTAssertNil(Decimal(string: ".", locale: fr_FR))

        XCTAssertNil(Decimal(string: ","))
        XCTAssertEqual(Decimal(string: ",", locale: fr_FR), Decimal.zero)
        XCTAssertNil(Decimal(string: ",", locale: en_US))

        let s1 = "1234.5678"
        XCTAssertEqual(Decimal(string: s1, locale: en_US)?.description, s1)
        XCTAssertEqual(Decimal(string: s1, locale: fr_FR)?.description, "1234")

        let s2 = "1234,5678"
        XCTAssertEqual(Decimal(string: s2, locale: en_US)?.description, "1234")
        XCTAssertEqual(Decimal(string: s2, locale: fr_FR)?.description, s1)
    }

    func testStringPartialMatch() {
        // This tests makes sure Decimal still has the
        // same behavior that it only requires the beginning
        // of the string to be valid number
        let decimal = Decimal(string: "3.14notanumber")
        XCTAssertNotNil(decimal)
        XCTAssertEqual(decimal!.description, "3.14")
    }

    func testStringNoMatch() {
        // This test makes sure Decimal returns nil
        // if the does not start with a number
        var notDecimal = Decimal(string: "A Flamingo's head has to be upside down when it eats.")
        XCTAssertNil(notDecimal)
        // Same if the number does not appear at the beginning
        notDecimal = Decimal(string: "Jump 22 Street")
        XCTAssertNil(notDecimal)
    }

    func testNormalize() throws {
        var one = Decimal(1)
        var ten = Decimal(-10)
        var lossPrecision = try Decimal._normalize(a: &one, b: &ten, roundingMode: .plain)
        XCTAssertFalse(lossPrecision)
        XCTAssertEqual(Decimal(1), one)
        XCTAssertEqual(Decimal(-10), ten)
        XCTAssertEqual(1, one._length)
        XCTAssertEqual(1, ten._length)
        one = Decimal(1)
        ten = Decimal(10)
        lossPrecision = try Decimal._normalize(a: &one, b: &ten, roundingMode: .plain)
        XCTAssertFalse(lossPrecision)
        XCTAssertEqual(Decimal(1), one)
        XCTAssertEqual(Decimal(10), ten)
        XCTAssertEqual(1, one._length)
        XCTAssertEqual(1, ten._length)

        // Normalise with loss of precision
        let a = try XCTUnwrap(Decimal(string: "498.7509045"))
        let b = try XCTUnwrap(Decimal(string: "8.453441368210501065891847765109162027"))

        var aNormalized = a
        var bNormalized = b

        lossPrecision = try Decimal._normalize(
            a: &aNormalized, b: &bNormalized, roundingMode: .plain)
        XCTAssertTrue(lossPrecision)

        XCTAssertEqual(aNormalized.exponent, -31)
        XCTAssertEqual(aNormalized._mantissa.0, 0)
        XCTAssertEqual(aNormalized._mantissa.1, 21760)
        XCTAssertEqual(aNormalized._mantissa.2, 45355)
        XCTAssertEqual(aNormalized._mantissa.3, 11455)
        XCTAssertEqual(aNormalized._mantissa.4, 62709)
        XCTAssertEqual(aNormalized._mantissa.5, 14050)
        XCTAssertEqual(aNormalized._mantissa.6, 62951)
        XCTAssertEqual(aNormalized._mantissa.7, 0)
        XCTAssertEqual(bNormalized.exponent, -31)
        XCTAssertEqual(bNormalized._mantissa.0, 56467)
        XCTAssertEqual(bNormalized._mantissa.1, 17616)
        XCTAssertEqual(bNormalized._mantissa.2, 59987)
        XCTAssertEqual(bNormalized._mantissa.3, 21635)
        XCTAssertEqual(bNormalized._mantissa.4, 5988)
        XCTAssertEqual(bNormalized._mantissa.5, 63852)
        XCTAssertEqual(bNormalized._mantissa.6, 1066)
        XCTAssertEqual(bNormalized._length, 7)
        XCTAssertEqual(a, aNormalized)
        XCTAssertNotEqual(b, bNormalized)   // b had a loss Of Precision when normalising
    }

    func testAdditionWithNormalization() throws {
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
        XCTAssertTrue(Decimal._compare(lhs: result, rhs: expected) == .orderedSame)
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
        XCTAssertTrue(Decimal._compare(lhs: expected, rhs: result) == .orderedSame)
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
            XCTAssertTrue(Decimal._compare(lhs: expected, rhs: result) == .orderedSame)
        } else {
            XCTAssertTrue(Decimal._compare(lhs: one, rhs: result) == .orderedSame)
        }
        // 40 Digits -- does NOT work, make sure we round
        addend._exponent = -39
        (result, lostPrecision) = try one._add(rhs: addend, roundingMode: .plain)
        XCTAssertTrue(lostPrecision)
        XCTAssertEqual("1", result.description)
        XCTAssertTrue(Decimal._compare(lhs: one, rhs: result) == .orderedSame)
    }

    func testSimpleMultiplication() throws {
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
                XCTAssertTrue(Decimal._compare(lhs: expected, rhs: result) == .orderedSame)
            }
        }
    }

    func testNegativeAndZeroMultiplication() throws {
        let one = Decimal(1)
        let zero = Decimal(0)
        var negativeOne = one
        negativeOne._isNegative = 1

        // 1 * 1
        var result = try one._multiply(by: one, roundingMode: .plain)
        XCTAssertTrue(Decimal._compare(lhs: one, rhs: result) == .orderedSame)
        // 1 * -1
        result = try one._multiply(by: negativeOne, roundingMode: .plain)
        XCTAssertTrue(Decimal._compare(lhs: negativeOne, rhs: result) == .orderedSame)
        // -1 * 1
        result = try negativeOne._multiply(by: one, roundingMode: .plain)
        XCTAssertTrue(Decimal._compare(lhs: negativeOne, rhs: result) == .orderedSame)
        // -1 * -1
        result = try negativeOne._multiply(by: negativeOne, roundingMode: .plain)
        XCTAssertTrue(Decimal._compare(lhs: one, rhs: result) == .orderedSame)
        // 1 * 0
        result = try one._multiply(by: zero, roundingMode: .plain)
        XCTAssertTrue(Decimal._compare(lhs: zero, rhs: result) == .orderedSame)
        // 0 * 1
        result = try zero._multiply(by: negativeOne, roundingMode: .plain)
        XCTAssertTrue(Decimal._compare(lhs: zero, rhs: result) == .orderedSame)
    }

    func testMultiplicationOverflow() throws {
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
        do {
            // 2e127 * max_mantissa
            _ = try multiplicand._multiply(
                by: multiplier, roundingMode: .plain)
            XCTFail("Expected _CalculationError.overflow to be thrown")
        } catch {
            guard let calculationError = error as? Decimal._CalculationError else {
                XCTFail("Wrong error thrown")
                return
            }
            XCTAssertEqual(calculationError, .overflow)
        }

        do {
            // max_mantissa * 2e127
            _ = try multiplier._multiply(
                by: multiplicand, roundingMode: .plain)
            XCTFail("Expected _CalculationError.overflow to be thrown")
        } catch {
            guard let calculationError = error as? Decimal._CalculationError else {
                XCTFail("Wrong error thrown")
                return
            }
            XCTAssertEqual(calculationError, .overflow)
        }
    }

    func testMultiplyByPowerOfTen() throws {
        let a = Decimal(1234)
        var result = try a._multiplyByPowerOfTen(power: 1, roundingMode: .plain)
        XCTAssertEqual(result, Decimal(12340))
        result = try a._multiplyByPowerOfTen(power: 2, roundingMode: .plain)
        XCTAssertEqual(result, Decimal(123400))
        result = try a._multiplyByPowerOfTen(power: 0, roundingMode: .plain)
        XCTAssertEqual(result, Decimal(1234))
        result = try a._multiplyByPowerOfTen(power: -2, roundingMode: .plain)
        XCTAssertEqual(result, Decimal(12.34))

        // Overflow
        do {
            _ = try a._multiplyByPowerOfTen(power: 128, roundingMode: .plain)
            XCTFail("Expected overflow to have been thrown")
        } catch {
            guard let calculationError = error as? Decimal._CalculationError else {
                XCTFail("Wrong error thrown")
                return
            }
            XCTAssertEqual(calculationError, .overflow)
        }

        // Underflow
        do {
            _ = try Decimal(12.34)._multiplyByPowerOfTen(power: -128, roundingMode: .plain)
            XCTFail("Expected underflow to have been thrown")
        } catch {
            guard let calculationError = error as? Decimal._CalculationError else {
                XCTFail("Wrong error thrown")
                return
            }
            XCTAssertEqual(calculationError, .underflow)
        }
    }

    func testRepeatingDivision() throws {
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
        XCTAssertTrue(Decimal._compare(lhs: expected, rhs: result) == .orderedSame)
    }

#if _pointerBitWidth(_64)
    // This test require Int to be Int64
    func testCrashingDivision() throws {
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
        XCTAssertEqual(result, expected)
    }
#endif

    func testPower() throws {
        var a = Decimal(1234)
        var result = try a._power(exponent: 0, roundingMode: .plain)
        XCTAssert(Decimal._compare(lhs: result, rhs: Decimal(1)) == .orderedSame)
        a = Decimal(8)
        result = try a._power(exponent: 2, roundingMode: .plain)
        XCTAssert(Decimal._compare(lhs: result, rhs: Decimal(64)) == .orderedSame)
        a = Decimal(-2)
        result = try a._power(exponent: 3, roundingMode: .plain)
        XCTAssert(Decimal._compare(lhs: result, rhs: Decimal(-8)) == .orderedSame)
        result = try a._power(exponent: 0, roundingMode: .plain)
        XCTAssert(Decimal._compare(lhs: result, rhs: Decimal(1)) == .orderedSame)
        // Positive base
        let six = Decimal(6)
        for exponent in 1 ..< 10 {
            result = try six._power(exponent: exponent, roundingMode: .plain)
            XCTAssertEqual(result.doubleValue, pow(6.0, Double(exponent)))
        }
        // Negative base
        let negativeSix = Decimal(-6)
        for exponent in 1 ..< 10 {
            result = try negativeSix._power(exponent: exponent, roundingMode: .plain)
            XCTAssertEqual(result.doubleValue, pow(-6.0, Double(exponent)))
        }
        for i in -2 ... 10 {
            for j in 0 ... 5 {
                let actual = Decimal(i)
                let result = try actual._power(
                    exponent: j, roundingMode: .plain
                )
                let expected = Decimal(pow(Double(i), Double(j)))
                XCTAssertEqual(expected, result, "\(result) == \(i)^\(j)")
            }
        }
    }

    func testNaNInput() throws {
        let nan = Decimal.nan
        let one = Decimal(1)

        do {
            // NaN + 1
            _ = try nan._add(rhs: one, roundingMode: .plain)
            XCTFail("Expected to throw error")
        } catch {
            guard let calculationError = error as? Decimal._CalculationError else {
                XCTFail("Wrong error thrown")
                return
            }
            XCTAssertEqual(calculationError, .overflow)
        }
        do {
            // 1 + NaN
            _ = try one._add(rhs: nan, roundingMode: .plain)
            XCTFail("Expected to throw error")
        } catch {
            guard let calculationError = error as? Decimal._CalculationError else {
                XCTFail("Wrong error thrown")
                return
            }
            XCTAssertEqual(calculationError, .overflow)
        }

        do {
            // NaN - 1
            _ = try nan._subtract(rhs: one, roundingMode: .plain)
            XCTFail("Expected to throw error")
        } catch {
            guard let calculationError = error as? Decimal._CalculationError else {
                XCTFail("Wrong error thrown")
                return
            }
            XCTAssertEqual(calculationError, .overflow)
        }
        do {
            // 1 - NaN
            _ = try one._subtract(rhs: nan, roundingMode: .plain)
            XCTFail("Expected to throw error")
        } catch {
            guard let calculationError = error as? Decimal._CalculationError else {
                XCTFail("Wrong error thrown")
                return
            }
            XCTAssertEqual(calculationError, .overflow)
        }

        do {
            // NaN * 1
            _ = try nan._multiply(by: one, roundingMode: .plain)
            XCTFail("Expected to throw error")
        } catch {
            guard let calculationError = error as? Decimal._CalculationError else {
                XCTFail("Wrong error thrown")
                return
            }
            XCTAssertEqual(calculationError, .overflow)
        }
        do {
            // 1 * NaN
            _ = try one._multiply(by: nan, roundingMode: .plain)
            XCTFail("Expected to throw error")
        } catch {
            guard let calculationError = error as? Decimal._CalculationError else {
                XCTFail("Wrong error thrown")
                return
            }
            XCTAssertEqual(calculationError, .overflow)
        }

        do {
            // NaN / 1
            _ = try nan._divide(by: one, roundingMode: .plain)
            XCTFail("Expected to throw error")
        } catch {
            guard let calculationError = error as? Decimal._CalculationError else {
                XCTFail("Wrong error thrown")
                return
            }
            XCTAssertEqual(calculationError, .overflow)
        }
        do {
            // 1 / NaN
            _ = try one._divide(by: nan, roundingMode: .plain)
            XCTFail("Expected to throw error")
        } catch {
            guard let calculationError = error as? Decimal._CalculationError else {
                XCTFail("Wrong error thrown")
                return
            }
            XCTAssertEqual(calculationError, .overflow)
        }

        do {
            // NaN ^ 0
            _ = try nan._power(exponent: 0, roundingMode: .plain)
            XCTFail("Expected to throw error")
        } catch {
            guard let calculationError = error as? Decimal._CalculationError else {
                XCTFail("Wrong error thrown")
                return
            }
            XCTAssertEqual(calculationError, .overflow)
        }
        do {
            // NaN ^ 1
            _ = try nan._power(exponent: 1, roundingMode: .plain)
            XCTFail("Expected to throw error")
        } catch {
            guard let calculationError = error as? Decimal._CalculationError else {
                XCTFail("Wrong error thrown")
                return
            }
            XCTAssertEqual(calculationError, .overflow)
        }

        // Overflow doubles
        XCTAssertTrue(Decimal(Double.leastNonzeroMagnitude).isNaN)
        XCTAssertTrue(Decimal(Double.leastNormalMagnitude).isNaN)
        XCTAssertTrue(Decimal(Double.greatestFiniteMagnitude).isNaN)
        XCTAssertTrue(Decimal(Double("1e-129")!).isNaN)
        XCTAssertTrue(Decimal(Double("0.1e-128")!).isNaN)
    }

    func testDecimalRoundBankers() throws {
        let onePointTwo = Decimal(1.2)
        var result = try onePointTwo._round(scale: 1, roundingMode: .bankers)
        XCTAssertEqual(1.2, result.doubleValue, accuracy: 0.0001)

        let onePointTwoOne = Decimal(1.21)
        result = try onePointTwoOne._round(scale: 1, roundingMode: .bankers)
        XCTAssertEqual(1.2, result.doubleValue, accuracy: 0.0001)

        let onePointTwoFive = Decimal(1.25)
        result = try onePointTwoFive._round(scale: 1, roundingMode: .bankers)
        XCTAssertEqual(1.2, result.doubleValue, accuracy: 0.0001)

        let onePointThreeFive = Decimal(1.35)
        result = try onePointThreeFive._round(scale: 1, roundingMode: .bankers)
        XCTAssertEqual(1.4, result.doubleValue, accuracy: 0.0001)

        let onePointTwoSeven = Decimal(1.27)
        result = try onePointTwoSeven._round(scale: 1, roundingMode: .bankers)
        XCTAssertEqual(1.3, result.doubleValue, accuracy: 0.0001)

        let minusEightPointFourFive = Decimal(-8.45)
        result = try minusEightPointFourFive._round(scale: 1, roundingMode: .bankers)
        XCTAssertEqual(-8.4, result.doubleValue, accuracy: 0.0001)

        let minusFourPointNineEightFive = Decimal(-4.985)
        result = try minusFourPointNineEightFive._round(scale: 2, roundingMode: .bankers)
        XCTAssertEqual(-4.98, result.doubleValue, accuracy: 0.0001)
    }

    func test_Round() throws {
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
            XCTAssertEqual(Decimal(expected), actual, "Failed test case: \(testCase)")
        }
    }

    func test_Maths() {
        for i in -2...10 {
            for j in 0...5 {
                XCTAssertEqual(Decimal(i*j), Decimal(i) * Decimal(j), "\(Decimal(i*j)) == \(i) * \(j)")
                XCTAssertEqual(Decimal(i+j), Decimal(i) + Decimal(j), "\(Decimal(i+j)) == \(i)+\(j)")
                XCTAssertEqual(Decimal(i-j), Decimal(i) - Decimal(j), "\(Decimal(i-j)) == \(i)-\(j)")
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
                    XCTAssertFalse(failed, "\(Decimal(i/j)) == \(i)/\(j)")
                }
            }
        }

        XCTAssertEqual(Decimal(186243 * 15673 as Int64), Decimal(186243) * Decimal(15673))

        XCTAssertEqual(Decimal(string: "5538")! + Decimal(string: "2880.4")!, Decimal(string: "8418.4")!)

        XCTAssertEqual(Decimal(string: "5538.0")! - Decimal(string: "2880.4")!, Decimal(string: "2657.6")!)
        XCTAssertEqual(Decimal(string: "2880.4")! - Decimal(5538), Decimal(string: "-2657.6")!)
        XCTAssertEqual(Decimal(0x10000) - Decimal(0x1000), Decimal(0xf000))
#if !os(watchOS)
        XCTAssertEqual(Decimal(0x1_0000_0000) - Decimal(0x1000), Decimal(0xFFFFF000))
        XCTAssertEqual(Decimal(0x1_0000_0000_0000) - Decimal(0x1000), Decimal(0xFFFFFFFFF000))
#endif
        XCTAssertEqual(Decimal(1234_5678_9012_3456_7899 as UInt64) - Decimal(1234_5678_9012_3456_7890 as UInt64), Decimal(9))
        XCTAssertEqual(Decimal(0xffdd_bb00_8866_4422 as UInt64) - Decimal(0x7777_7777), Decimal(0xFFDD_BB00_10EE_CCAB as UInt64))

        let highBit = Decimal(_exponent: 0, _length: 8, _isNegative: 0, _isCompact: 1, _reserved: 0, _mantissa: (0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x8000))
        let otherBits = Decimal(_exponent: 0, _length: 8, _isNegative: 0, _isCompact: 1, _reserved: 0, _mantissa: (0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0x7fff))
        XCTAssertEqual(highBit - otherBits, Decimal(1))
        XCTAssertEqual(otherBits + Decimal(1), highBit)
    }

    func testMisc() throws {
        XCTAssertEqual(Decimal(-5.2).sign, .minus)
        XCTAssertEqual(Decimal(5.2).sign, .plus)
        var d = Decimal(5.2)
        XCTAssertEqual(d.sign, .plus)
        d.negate()
        XCTAssertEqual(d.sign, .minus)
        d.negate()
        XCTAssertEqual(d.sign, .plus)
        var e = Decimal(0)
        e.negate()
        XCTAssertEqual(e, Decimal(0))
        XCTAssertTrue(Decimal(3.5).isEqual(to: Decimal(3.5)))
        XCTAssertTrue(Decimal.nan.isEqual(to: Decimal.nan))
        XCTAssertTrue(Decimal(1.28).isLess(than: Decimal(2.24)))
        XCTAssertFalse(Decimal(2.28).isLess(than: Decimal(2.24)))
        XCTAssertTrue(Decimal(1.28).isTotallyOrdered(belowOrEqualTo: Decimal(2.24)))
        XCTAssertFalse(Decimal(2.28).isTotallyOrdered(belowOrEqualTo: Decimal(2.24)))
        XCTAssertTrue(Decimal(1.2).isTotallyOrdered(belowOrEqualTo: Decimal(1.2)))
        XCTAssertTrue(Decimal.nan.isEqual(to: Decimal.nan))
        XCTAssertTrue(Decimal.nan.isLess(than: Decimal(0)))
        XCTAssertFalse(Decimal.nan.isLess(than: Decimal.nan))
        XCTAssertTrue(Decimal.nan.isLessThanOrEqualTo(Decimal(0)))
        XCTAssertTrue(Decimal.nan.isLessThanOrEqualTo(Decimal.nan))
        XCTAssertFalse(Decimal.nan.isTotallyOrdered(belowOrEqualTo: Decimal.nan))
        XCTAssertFalse(Decimal.nan.isTotallyOrdered(belowOrEqualTo: Decimal(2.3)))
        XCTAssertTrue(Decimal(2) < Decimal(3))
        XCTAssertTrue(Decimal(3) > Decimal(2))
        XCTAssertEqual(Decimal(-9), Decimal(1) - Decimal(10))
        XCTAssertEqual(Decimal(476), Decimal(1024).distance(to: Decimal(1500)))
        XCTAssertEqual(Decimal(68040), Decimal(386).advanced(by: Decimal(67654)))
        XCTAssertEqual(Decimal(1.234), abs(Decimal(1.234)))
        XCTAssertEqual(Decimal(1.234), abs(Decimal(-1.234)))
        XCTAssertTrue(Decimal.nan.magnitude.isNaN)
        XCTAssertEqual(Decimal.leastFiniteMagnitude.magnitude, -Decimal.leastFiniteMagnitude)

        XCTAssertEqual(Decimal(-9), Decimal(1) - Decimal(10))
        XCTAssertEqual(Decimal(1.234), abs(Decimal(1.234)))
        XCTAssertEqual(Decimal(1.234), abs(Decimal(-1.234)))
        XCTAssertEqual((0 as Decimal).magnitude, 0 as Decimal)
        XCTAssertEqual((1 as Decimal).magnitude, 1 as Decimal)
        XCTAssertEqual((1 as Decimal).magnitude, abs(1 as Decimal))
        XCTAssertEqual((1 as Decimal).magnitude, abs(-1 as Decimal))
        XCTAssertEqual((-1 as Decimal).magnitude, abs(-1 as Decimal))
        XCTAssertEqual((-1 as Decimal).magnitude, abs(1 as Decimal))
        XCTAssertEqual(Decimal.greatestFiniteMagnitude.magnitude, Decimal.greatestFiniteMagnitude)

        var a = Decimal(1234)
        var result = try a._multiplyByPowerOfTen(power: 1, roundingMode: .plain)
        XCTAssertEqual(Decimal(12340), result)
        a = Decimal(1234)
        result = try a._multiplyByPowerOfTen(power: 2, roundingMode: .plain)
        XCTAssertEqual(Decimal(123400), result)
        a = result
        do {
            result = try a._multiplyByPowerOfTen(power: 128, roundingMode: .plain)
            XCTFail("Expected to throw _CalcuationError.overflow")
        } catch {
            guard let calculationError = error as? Decimal._CalculationError else {
                XCTFail("Expected Decimal._CalculationError, got \(error)")
                return
            }
            XCTAssertEqual(.overflow, calculationError)
        }
        a = Decimal(1234)
        result = try a._multiplyByPowerOfTen(power: -2, roundingMode: .plain)
        XCTAssertEqual(Decimal(12.34), result)
        a = result
        do {
            result = try a._multiplyByPowerOfTen(power: -128, roundingMode: .plain)
            XCTFail("Expected to throw _CalcuationError.underflow")
        } catch {
            guard let calculationError = error as? Decimal._CalculationError else {
                XCTFail("Expected Decimal._CalculationError, got \(error)")
                return
            }
            XCTAssertEqual(.underflow, calculationError)
        }
        a = Decimal(1234)
        result = try a._power(exponent: 0, roundingMode: .plain)
        XCTAssertEqual(Decimal(1), result)
        a = Decimal(8)
        result = try a._power(exponent: 2, roundingMode: .plain)
        XCTAssertEqual(Decimal(64), result)
        a = Decimal(-2)
        result = try a._power(exponent: 3, roundingMode: .plain)
        XCTAssertEqual(Decimal(-8), result)
        for i in -2...10 {
            for j in 0...5 {
                let power = Decimal(i)
                let actual = try power._power(exponent: j, roundingMode: .plain)
                let expected = Decimal(pow(Double(i), Double(j)))
                XCTAssertEqual(expected, actual, "\(actual) == \(i)^\(j)")
                XCTAssertEqual(expected, try power._power(exponent: j, roundingMode: .plain))
            }
        }

        do {
            // SR-13015
            let a = try XCTUnwrap(Decimal(string: "119.993"))
            let b = try XCTUnwrap(Decimal(string: "4.1565"))
            let c = try XCTUnwrap(Decimal(string: "18.209"))
            let d = try XCTUnwrap(Decimal(string: "258.469"))
            let ab = a * b
            let aDivD = a / d
            let caDivD = c * aDivD
            XCTAssertEqual(ab, try XCTUnwrap(Decimal(string: "498.7509045")))
            XCTAssertEqual(aDivD, try XCTUnwrap(Decimal(string: "0.46424522863476857959755328492004843907")))
            XCTAssertEqual(caDivD, try XCTUnwrap(Decimal(string: "8.453441368210501065891847765109162027")))

            let result = (a * b) + (c * (a / d))
            XCTAssertEqual(result, try XCTUnwrap(Decimal(string: "507.2043458682105010658918477651091")))
        }
    }

    func test_Constants() {
        let smallest = Decimal(_exponent: 127, _length: 8, _isNegative: 1, _isCompact: 1, _reserved: 0, _mantissa: (UInt16.max, UInt16.max, UInt16.max, UInt16.max, UInt16.max, UInt16.max, UInt16.max, UInt16.max))
        XCTAssertEqual(smallest, Decimal.leastFiniteMagnitude)
        let biggest = Decimal(_exponent: 127, _length: 8, _isNegative: 0, _isCompact: 1, _reserved: 0, _mantissa: (UInt16.max, UInt16.max, UInt16.max, UInt16.max, UInt16.max, UInt16.max, UInt16.max, UInt16.max))
        XCTAssertEqual(biggest, Decimal.greatestFiniteMagnitude)
        let leastNormal = Decimal(_exponent: -127, _length: 1, _isNegative: 0, _isCompact: 1, _reserved: 0, _mantissa: (1, 0, 0, 0, 0, 0, 0, 0))
        XCTAssertEqual(leastNormal, Decimal.leastNormalMagnitude)
        let leastNonzero = Decimal(_exponent: -127, _length: 1, _isNegative: 0, _isCompact: 1, _reserved: 0, _mantissa: (1, 0, 0, 0, 0, 0, 0, 0))
        XCTAssertEqual(leastNonzero, Decimal.leastNonzeroMagnitude)
        let pi = Decimal(_exponent: -38, _length: 8, _isNegative: 0, _isCompact: 1, _reserved: 0, _mantissa: (0x6623, 0x7d57, 0x16e7, 0xad0d, 0xaf52, 0x4641, 0xdfa7, 0xec58))
        XCTAssertEqual(pi, Decimal.pi)
        XCTAssertEqual(10, Decimal.radix)
        XCTAssertTrue(Decimal().isCanonical)
        XCTAssertFalse(Decimal().isSignalingNaN)
        XCTAssertFalse(Decimal.nan.isSignalingNaN)
        XCTAssertTrue(Decimal.nan.isNaN)
        XCTAssertEqual(.quietNaN, Decimal.nan.floatingPointClass)
        XCTAssertEqual(.positiveZero, Decimal().floatingPointClass)
        XCTAssertEqual(.negativeNormal, smallest.floatingPointClass)
        XCTAssertEqual(.positiveNormal, biggest.floatingPointClass)
        XCTAssertFalse(Double.nan.isFinite)
        XCTAssertFalse(Double.nan.isInfinite)
    }

    func test_parseDouble() throws {
        XCTAssertEqual(Decimal(Double(0.0)), Decimal(Int.zero))
        XCTAssertEqual(Decimal(Double(-0.0)), Decimal(Int.zero))

        // These values can only be represented as Decimal.nan
        XCTAssertEqual(Decimal(Double.nan), Decimal.nan)
        XCTAssertEqual(Decimal(Double.signalingNaN), Decimal.nan)

        // These values are out out range for Decimal
        XCTAssertEqual(Decimal(-Double.leastNonzeroMagnitude), Decimal.nan)
        XCTAssertEqual(Decimal(Double.leastNonzeroMagnitude), Decimal.nan)
        XCTAssertEqual(Decimal(-Double.leastNormalMagnitude), Decimal.nan)
        XCTAssertEqual(Decimal(Double.leastNormalMagnitude), Decimal.nan)
        XCTAssertEqual(Decimal(-Double.greatestFiniteMagnitude), Decimal.nan)
        XCTAssertEqual(Decimal(Double.greatestFiniteMagnitude), Decimal.nan)

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
            XCTAssertEqual(Decimal(d), Decimal(string: s))
            XCTAssertEqual(Decimal(d).description, try XCTUnwrap(Decimal(string: s)).description)
        }
    }

    func test_initExactly() {
        // This really requires some tests using a BinaryInteger of bitwidth > 128 to test failures.
        let d1 = Decimal(exactly: UInt64.max)
        XCTAssertNotNil(d1)
        XCTAssertEqual(d1?.description, UInt64.max.description)
        XCTAssertEqual(d1?._length, 4)

        let d2 = Decimal(exactly: Int64.min)
        XCTAssertNotNil(d2)
        XCTAssertEqual(d2?.description, Int64.min.description)
        XCTAssertEqual(d2?._length, 4)

        let d3 = Decimal(exactly: Int64.max)
        XCTAssertNotNil(d3)
        XCTAssertEqual(d3?.description, Int64.max.description)
        XCTAssertEqual(d3?._length, 4)

        let d4 = Decimal(exactly: Int32.min)
        XCTAssertNotNil(d4)
        XCTAssertEqual(d4?.description, Int32.min.description)
        XCTAssertEqual(d4?._length, 2)

        let d5 = Decimal(exactly: Int32.max)
        XCTAssertNotNil(d5)
        XCTAssertEqual(d5?.description, Int32.max.description)
        XCTAssertEqual(d5?._length, 2)

        let d6 = Decimal(exactly: 0)
        XCTAssertNotNil(d6)
        XCTAssertEqual(d6, Decimal.zero)
        XCTAssertEqual(d6?.description, "0")
        XCTAssertEqual(d6?._length, 0)

        let d7 = Decimal(exactly: 1)
        XCTAssertNotNil(d7)
        XCTAssertEqual(d7?.description, "1")
        XCTAssertEqual(d7?._length, 1)

        let d8 = Decimal(exactly: -1)
        XCTAssertNotNil(d8)
        XCTAssertEqual(d8?.description, "-1")
        XCTAssertEqual(d8?._length, 1)
    }

    func test_Strideable() {
        let x = 42 as Decimal
        XCTAssertEqual(x.distance(to: 43), 1)
        XCTAssertEqual(x.advanced(by: 1), 43)
        XCTAssertEqual(x.distance(to: 41), -1)
        XCTAssertEqual(x.advanced(by: -1), 41)
    }

    func test_Significand() {
        var x = -42 as Decimal
        XCTAssertEqual(x.significand.sign, .plus)
        var y = Decimal(sign: .plus, exponent: 0, significand: x)
#if FOUNDATION_FRAMEWORK
        if Decimal.compatibility1 {
            XCTAssertEqual(y, 42)
            y = Decimal(sign: .minus, exponent: 0, significand: x)
            XCTAssertEqual(y, -42)
        } else {
            XCTAssertEqual(y, -42)
            y = Decimal(sign: .minus, exponent: 0, significand: x)
            XCTAssertEqual(y, 42)
        }
#else
        XCTAssertEqual(y, -42)
        y = Decimal(sign: .minus, exponent: 0, significand: x)
        XCTAssertEqual(y, 42)
#endif

        x = 42 as Decimal
        XCTAssertEqual(x.significand.sign, .plus)
        y = Decimal(sign: .plus, exponent: 0, significand: x)
        XCTAssertEqual(y, 42)
        y = Decimal(sign: .minus, exponent: 0, significand: x)
        XCTAssertEqual(y, -42)

        let a = Decimal.leastNonzeroMagnitude
        XCTAssertEqual(Decimal(sign: .plus, exponent: -10, significand: a), 0)
        XCTAssertEqual(Decimal(sign: .plus, exponent: .min, significand: a), 0)
        let b = Decimal.greatestFiniteMagnitude
        XCTAssertTrue(Decimal(sign: .plus, exponent: 10, significand: b).isNaN)
        XCTAssertTrue(Decimal(sign: .plus, exponent: .max, significand: b).isNaN)
    }

    func test_ULP() {
        var x = 0.1 as Decimal
        XCTAssertFalse(x.ulp > x)

        x = .nan
        XCTAssertTrue(x.ulp.isNaN)
        XCTAssertTrue(x.nextDown.isNaN)
        XCTAssertTrue(x.nextUp.isNaN)

        x = .greatestFiniteMagnitude
        XCTAssertEqual(x.ulp, Decimal(string: "1e127")!)
        XCTAssertEqual(x.nextDown, x - Decimal(string: "1e127")!)
        XCTAssertTrue(x.nextUp.isNaN)

        // '4' is an important value to test because the max supported
        // significand of this type is not 10 ** 38 - 1 but rather 2 ** 128 - 1,
        // for which reason '4.ulp' is not equal to '1.ulp' despite having the
        // same decimal exponent.
        x = 4
        XCTAssertEqual(x.ulp, Decimal(string: "1e-37")!)
        XCTAssertEqual(x.nextDown, x - Decimal(string: "1e-37")!)
        XCTAssertEqual(x.nextUp, x + Decimal(string: "1e-37")!)
        XCTAssertEqual(x.nextDown.nextUp, x)
        XCTAssertEqual(x.nextUp.nextDown, x)
        XCTAssertNotEqual(x.nextDown, x)
        XCTAssertNotEqual(x.nextUp, x)

        // For similar reasons, '3.40282366920938463463374607431768211455',
        // which has the same significand as 'Decimal.greatestFiniteMagnitude',
        // is an important value to test because the distance to the next
        // representable value is more than 'ulp' and instead requires
        // incrementing '_exponent'.
        x = Decimal(string: "3.40282366920938463463374607431768211455")!
        XCTAssertEqual(x.ulp, Decimal(string: "0.00000000000000000000000000000000000001")!)
        XCTAssertEqual(x.nextUp, Decimal(string: "3.4028236692093846346337460743176821146")!)
        x = Decimal(string: "3.4028236692093846346337460743176821146")!
        XCTAssertEqual(x.ulp, Decimal(string: "0.0000000000000000000000000000000000001")!)
        XCTAssertEqual(x.nextDown, Decimal(string: "3.40282366920938463463374607431768211455")!)

        x = 1
        XCTAssertEqual(x.ulp, Decimal(string: "1e-38")!)
        XCTAssertEqual(x.nextDown, x - Decimal(string: "1e-38")!)
        XCTAssertEqual(x.nextUp, x + Decimal(string: "1e-38")!)
        XCTAssertEqual(x.nextDown.nextUp, x)
        XCTAssertEqual(x.nextUp.nextDown, x)
        XCTAssertNotEqual(x.nextDown, x)
        XCTAssertNotEqual(x.nextUp, x)

        x = 0
        XCTAssertEqual(x.ulp, Decimal(string: "1e-128")!)
        XCTAssertEqual(x.nextDown, -Decimal(string: "1e-128")!)
        XCTAssertEqual(x.nextUp, Decimal(string: "1e-128")!)
        XCTAssertEqual(x.nextDown.nextUp, x)
        XCTAssertEqual(x.nextUp.nextDown, x)
        XCTAssertNotEqual(x.nextDown, x)
        XCTAssertNotEqual(x.nextUp, x)

        x = -1
        XCTAssertEqual(x.ulp, Decimal(string: "1e-38")!)
        XCTAssertEqual(x.nextDown, x - Decimal(string: "1e-38")!)
        XCTAssertEqual(x.nextUp, x + Decimal(string: "1e-38")!)
        let y = x - x.ulp + x.ulp
        XCTAssertEqual(x, y)
        XCTAssertEqual(x.nextDown.nextUp, x)
        XCTAssertEqual(x.nextUp.nextDown, x)
        XCTAssertNotEqual(x.nextDown, x)
        XCTAssertNotEqual(x.nextUp, x)
    }

    #if FOUNDATION_FRAMEWORK
    #else
    func test_toString() {
        let decimal = Decimal(string: "-123456.789")!
        XCTAssertEqual(decimal._toString(withDecimalSeparator: "."), "-123456.789")
        let en = decimal._toString(withDecimalSeparator: Locale(identifier: "en_GB").decimalSeparator!)
        XCTAssertEqual(en, "-123456.789")
        let fr = decimal._toString(withDecimalSeparator: Locale(identifier: "fr_FR").decimalSeparator!)
        XCTAssertEqual(fr, "-123456,789")
    }

    func test_int64Value() {
        XCTAssertEqual(Decimal(-1).int64Value, -1)
        XCTAssertEqual(Decimal(0).int64Value, 0)
        XCTAssertEqual(Decimal(1).int64Value, 1)
        XCTAssertEqual(Decimal.nan.int64Value, 0)
        XCTAssertEqual(Decimal(1e50).int64Value, 0)
        XCTAssertEqual(Decimal(1e-50).int64Value, 0)

        XCTAssertEqual(Decimal(UInt64.max).uint64Value, UInt64.max)
        XCTAssertEqual((Decimal(UInt64.max) + 1).uint64Value, 0)
        XCTAssertEqual(Decimal(Int64.max).int64Value, Int64.max)
        XCTAssertEqual((Decimal(Int64.max) + 1 ).int64Value, Int64.min)
        XCTAssertEqual((Decimal(Int64.max) + 1 ).uint64Value, UInt64(Int64.max) + 1)
        XCTAssertEqual(Decimal(Int64.min).int64Value, Int64.min)

        XCTAssertEqual(Decimal(Int.min).int64Value, Int64(Int.min))

        let div3 = Decimal(10) / 3
        XCTAssertEqual(div3.int64Value, 3)
        let pi = Decimal(Double.pi)
        XCTAssertEqual(pi.int64Value, 3)
    }

    func test_doubleValue() {
        XCTAssertEqual(Decimal(0).doubleValue, 0)
        XCTAssertEqual(Decimal(1).doubleValue, 1)
        XCTAssertEqual(Decimal(-1).doubleValue, -1)
        XCTAssertTrue(Decimal.nan.doubleValue.isNaN)
        XCTAssertEqual(Decimal(UInt64.max).doubleValue, Double(1.8446744073709552e+19))
    }
    
    func test_decimalFromString() {
        let string = "x123x"
        let scanLocation = 1
        
        let start = string.index(string.startIndex, offsetBy: scanLocation, limitedBy: string.endIndex)!
        let substring = string[start..<string.endIndex]
        let view = String(substring).utf8
        let (result, length) = Decimal.decimal(from: view, decimalSeparator: ".".utf8, matchEntireString: false)
        XCTAssertEqual(result, Decimal(123))
        XCTAssertEqual(length, 3)
    }
    #endif

    func testNegativePower() {
        func test(withBase base: Decimal, power: Int) {
            XCTAssertEqual(
                try base._power(exponent: -power, roundingMode: .plain),
                try Decimal(1)/base._power(exponent: power, roundingMode: .plain),
                "Base: \(base), Power: \(power)"
            )
        }
        // Negative Exponent Rule
        // x^-n = 1/(x^n)
        for power in 2 ..< 10 {
            // Positive Integer base
            test(withBase: Decimal(Int.random(in: 1 ..< 10)), power: power)

            // Negative Integer base
            test(withBase: Decimal(Int.random(in: -10 ..< -1)), power: power)

            // Postive Double base
            test(withBase: Decimal(Double.random(in: 0 ..< 1.0)), power: power)

            // Negative Double base
            test(withBase: Decimal(Double.random(in: -1.0 ..< 0.0)), power: power)

            // For zero base: 0^n = 0; 0^(-n) = nan
            XCTAssertEqual(
                try Decimal(0)._power(exponent: power, roundingMode: .plain),
                Decimal(0)
            )
            XCTAssertEqual(
                try Decimal(0)._power(exponent: -power, roundingMode: .plain),
                Decimal.nan
            )
        }

    }
}
