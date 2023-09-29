// Copyright (c) 2023 Wade Tregaskis
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

    func testNumericStringRepresentation_buildinIntegersAroundDecimalMagnitude() throws {
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

    func check<I: BinaryInteger>(type: I.Type = I.self, digits: Int, magnitude: UInt) {
        let actual = I.decimalDigitsAndMagnitudePerWord()

        XCTAssertEqual(actual.digits, digits)
        XCTAssertEqual(actual.magnitude, I(exactly: magnitude))
    }

    func testDecimalDigitsAndMagnitudePerWord_builtinIntegers() throws {
        check(type: Int8.self, digits: 3, magnitude: 100)
        check(type: Int16.self, digits: 5, magnitude: 10_000)
        check(type: Int32.self, digits: 10, magnitude: 1_000_000_000)
        check(type: Int64.self, digits: 19, magnitude: 1_000_000_000_000_000_000)

        check(type: UInt8.self, digits: 3, magnitude: 100)
        check(type: UInt16.self, digits: 5, magnitude: 10_000)
        check(type: UInt32.self, digits: 10, magnitude: 1_000_000_000)
        check(type: UInt64.self, digits: 20, magnitude: 10_000_000_000_000_000_000)

    }
}
