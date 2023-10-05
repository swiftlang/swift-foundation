// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// RUN: %target-run-simple-swift
// REQUIRES: executable_test

import XCTest

import FoundationEssentials
@testable import FoundationInternationalization

#if canImport(BigInt) // Not included by default as it's a 3rd party library; requires https://github.com/attaswift/BigInt.git be added the package dependencies.  Proved useful in the past for finding bugs that only show up with large numbers.
import BigInt
#endif

final class BinaryIntegerFormatStyleTests: XCTestCase {
    // NSR == numericStringRepresentation
    func checkNSR(value: some BinaryInteger, expected: String) {
        XCTAssertEqual(String(decoding: value.numericStringRepresentation, as: Unicode.ASCII.self), expected)
    }

    func testNumericStringRepresentation_builtinIntegersLimits() throws {
        func check<I: FixedWidthInteger>(type: I.Type = I.self, min: String, max: String) {
            checkNSR(value: I.min, expected: min)
            checkNSR(value: I.max, expected: max)
        }

        check(type: Int8.self, min: "-128", max: "127")
        check(type: Int16.self, min: "-32768", max: "32767")
        check(type: Int32.self, min: "-2147483648", max: "2147483647")
        check(type: Int64.self, min: "-9223372036854775808", max: "9223372036854775807")

        check(type: UInt8.self, min: "0", max: "255")
        check(type: UInt16.self, min: "0", max: "65535")
        check(type: UInt32.self, min: "0", max: "4294967295")
        check(type: UInt64.self, min: "0", max: "18446744073709551615")
    }

    func testNumericStringRepresentation_builtinIntegersAroundDecimalMagnitude() throws {
        func check<I: FixedWidthInteger>(type: I.Type = I.self, magnitude: String, oneLess: String, oneMore: String) {
            let mag = I.decimalDigitsAndMagnitudePerWord().magnitude

            checkNSR(value: mag, expected: magnitude)
            checkNSR(value: mag - 1, expected: oneLess)
            checkNSR(value: mag + 1, expected: oneMore)
        }

        check(type: Int8.self, magnitude: "100", oneLess: "99", oneMore: "101")
        check(type: Int16.self, magnitude: "10000", oneLess: "9999", oneMore: "10001")
        check(type: Int32.self, magnitude: "1000000000", oneLess: "999999999", oneMore: "1000000001")
        check(type: Int64.self, magnitude: "1000000000000000000", oneLess: "999999999999999999", oneMore: "1000000000000000001")

        check(type: UInt8.self, magnitude: "100", oneLess: "99", oneMore: "101")
        check(type: UInt16.self, magnitude: "10000", oneLess: "9999", oneMore: "10001")
        check(type: UInt32.self, magnitude: "1000000000", oneLess: "999999999", oneMore: "1000000001")
        check(type: UInt64.self, magnitude: "10000000000000000000", oneLess: "9999999999999999999", oneMore: "10000000000000000001")
    }

#if canImport(BigInt)
    func testNumericStringRepresentation_arbitraryPrecisionIntegers() throws {
        // An initialiser has to be passed manually because BinaryInteger doesn't actually provide a way to initialise an instance from a string representation (that's functional for non-builtin integers).
        func check<I: BinaryInteger>(type: I.Type = I.self, initialiser: (String) -> I) {
            // Just some real basic sanity checks first.
            checkNSR(value: I(0), expected: "0")
            checkNSR(value: I(1), expected: "1")

            if I.isSigned {
                checkNSR(value: I(-1), expected: "-1")
            }

            for valueAsString in ["9223372036854775807", // Int64.max
                                  "9223372036854775808", // Int64.max + 1 (and Int64.min when negated).

                                  "9999999999999999999", // Test around the magnitude.
                                  "10000000000000000000",
                                  "10000000000000000001",


                                  "18446744073709551615", // UInt64.max
                                  "18446744073709551616", // UInt64.max + 1

                                  "170141183460469231731687303715884105727", // Int128.max
                                  "170141183460469231731687303715884105728", // Int128.max + 1
                                  "340282366920938463463374607431768211455", // UInt128.max
                                  "340282366920938463463374607431768211456", // UInt128.max + 1

                                  // Some arbitrary, *very* large numbers to ensure there's no egregious scaling issues nor fatal inaccuracies in things like sizing of preallocated buffers.
                                  "1" + String(repeating: "0", count: 99),
                                  "1" + String(repeating: "0", count: 999),
                                  "1" + String(repeating: "0", count: 1406), // First power of ten value at which an earlier implementation crashed due to underestimating how many wordStrings would be needed.
                                  String(repeating: "1234567890", count: 10),
                                  String(repeating: "1234567890", count: 100)] {
                let value = initialiser(valueAsString)

                XCTAssertEqual(value.description, valueAsString) // Sanity check that it initialised from the string correctly.
                checkNSR(value: value, expected: valueAsString)

                if I.isSigned {
                    let negativeValueAsString = "-" + valueAsString
                    let negativeValue = initialiser(negativeValueAsString)

                    XCTAssertEqual(negativeValue.description, negativeValueAsString) // Sanity check that it initialised from the string correctly.
                    checkNSR(value: negativeValue, expected: negativeValueAsString)
                }
            }
        }

        check(type: BigInt.self, initialiser: { BigInt($0)! })
        check(type: BigUInt.self, initialiser: { BigUInt($0)! })
    }
#endif

    func check<I: BinaryInteger>(type: I.Type = I.self, digits: Int, magnitude: UInt) {
        let actual = I.decimalDigitsAndMagnitudePerWord()

        let maxDigits = [32: 9, 64: 19][UInt.bitWidth]!
        let maxMagnitude: UInt = [32: 1_000_000_000, 64: 10_000_000_000_000_000_000][UInt.bitWidth]!

        XCTAssertEqual(actual.digits, min(digits, maxDigits))
        XCTAssertEqual(actual.magnitude, I(exactly: min(magnitude, maxMagnitude)))
    }

    func testDecimalDigitsAndMagnitudePerWord_builtinIntegers() throws {
        check(type: Int8.self, digits: 2, magnitude: 100)
        check(type: Int16.self, digits: 4, magnitude: 10_000)
        check(type: Int32.self, digits: 9, magnitude: 1_000_000_000)
        check(type: Int64.self, digits: 18, magnitude: 1_000_000_000_000_000_000)

        check(type: UInt8.self, digits: 2, magnitude: 100)
        check(type: UInt16.self, digits: 4, magnitude: 10_000)
        check(type: UInt32.self, digits: 9, magnitude: 1_000_000_000)
        check(type: UInt64.self, digits: 19, magnitude: 10_000_000_000_000_000_000)
    }

#if canImport(BigInt)
    func testDecimalDigitsAndMagnitudePerWord_arbitraryPrecisionIntegers() throws {
        check(type: BigInt.self, digits: 19, magnitude: 10_000_000_000_000_000_000)
        check(type: BigUInt.self, digits: 19, magnitude: 10_000_000_000_000_000_000)
    }
#endif
}
