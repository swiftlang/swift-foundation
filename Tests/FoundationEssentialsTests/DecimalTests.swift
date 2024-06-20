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
@testable import Foundation
#else
@testable import FoundationEssentials
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
        XCTAssertEqual(8, NSDecimalMaxSize)
        XCTAssertEqual(32767, NSDecimalNoScale)
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

        let ulp = explicit.ulp
        XCTAssertEqual(0x7f, ulp.exponent)
        XCTAssertEqual(8, ulp._length)
        XCTAssertEqual(0, ulp._isNegative)
        XCTAssertEqual(1, ulp._isCompact)
        XCTAssertEqual(0, ulp._reserved)
        XCTAssertEqual(1, ulp._mantissa.0)
        XCTAssertEqual(0, ulp._mantissa.1)
        XCTAssertEqual(0, ulp._mantissa.2)
        XCTAssertEqual(0, ulp._mantissa.3)
        XCTAssertEqual(0, ulp._mantissa.4)
        XCTAssertEqual(0, ulp._mantissa.5)
        XCTAssertEqual(0, ulp._mantissa.6)
        XCTAssertEqual(0, ulp._mantissa.7)
    }

    func test_ScanDecimal() {
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
            let (expected, string, expectedString) = testCase
            let decimal = Decimal(string:string)!
#if FOUNDATION_FRAMEWORK
            let aboutOne = Decimal(expected) / decimal
            let approximatelyRight = aboutOne >= Decimal(0.99999) && aboutOne <= Decimal(1.00001)
            XCTAssertTrue(approximatelyRight, "\(expected) ~= \(decimal) : \(aboutOne) \(aboutOne >= Decimal(0.99999)) \(aboutOne <= Decimal(1.00001))" )
#else
            // No calculation implemented yet
            XCTAssertEqual(decimal.description, expectedString)
#endif
        }
        guard let answer = Decimal(string:"12345679012345679012345679012345679012.3") else {
            XCTFail("Unable to parse Decimal(string:'12345679012345679012345679012345679012.3')")
            return
        }
#if FOUNDATION_FRAMEWORK
        guard let ones = Decimal(string:"111111111111111111111111111111111111111") else {
            XCTFail("Unable to parse Decimal(string:'111111111111111111111111111111111111111')")
            return
        }
        let num = ones / Decimal(9)
        XCTAssertEqual(answer,num,"\(ones) / 9 = \(answer) \(num)")
#else
        // No calculation implemented yet
        XCTAssertEqual(answer.description, "12345679012345679012345679012345679012.3")
#endif
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
}
