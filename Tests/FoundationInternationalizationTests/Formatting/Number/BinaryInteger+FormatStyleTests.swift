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
    func check(value: some BinaryInteger, expected: String) {
        XCTAssertEqual(String(decoding: value.numericStringRepresentation, as: Unicode.ASCII.self), expected)
    }

    func testNumericStringRepresentation_fixedWidthLimits() throws {
        func test<I: FixedWidthInteger>(type: I.Type = I.self, min: String, max: String) {
            check(value: I.min, expected: min)
            check(value: I.max, expected: max)
        }

        test(type: Int8.self, min: "-128", max: "127")
        test(type: Int16.self, min: "-32768", max: "32767")
        test(type: Int32.self, min: "-2147483648", max: "2147483647")
        test(type: Int64.self, min: "-9223372036854775808", max: "9223372036854775807")

        test(type: UInt8.self, min: "0", max: "255")
        test(type: UInt16.self, min: "0", max: "65535")
        test(type: UInt32.self, min: "0", max: "4294967295")
        test(type: UInt64.self, min: "0", max: "18446744073709551615")
    }

    func testNumericStringRepresentation_fixedWidthAroundDecimalMagnitude() throws {
        func test<I: FixedWidthInteger>(type: I.Type = I.self, magnitude: String, oneLess: String, oneMore: String) {
            let mag = I.decimalDigitsAndMagnitudePerWord().magnitude

            check(value: mag, expected: magnitude)
            check(value: mag - 1, expected: oneLess)
            check(value: mag + 1, expected: oneMore)
        }

        test(type: Int8.self, magnitude: "100", oneLess: "99", oneMore: "101")
        test(type: Int16.self, magnitude: "10000", oneLess: "9999", oneMore: "10001")
        test(type: Int32.self, magnitude: "1000000000", oneLess: "999999999", oneMore: "1000000001")
        test(type: Int64.self, magnitude: "1000000000000000000", oneLess: "999999999999999999", oneMore: "1000000000000000001")

        test(type: UInt8.self, magnitude: "100", oneLess: "99", oneMore: "101")
        test(type: UInt16.self, magnitude: "10000", oneLess: "9999", oneMore: "10001")
        test(type: UInt32.self, magnitude: "1000000000", oneLess: "999999999", oneMore: "1000000001")
        test(type: UInt64.self, magnitude: "10000000000000000000", oneLess: "9999999999999999999", oneMore: "10000000000000000001")
    }

    func testDecimalDigitsAndMagnitudePerWord() throws {
        func test<I: FixedWidthInteger>(type: I.Type = I.self, digits: Int, magnitude: I) {
            let actual = I.decimalDigitsAndMagnitudePerWord()

            XCTAssertEqual(actual.digits, digits)
            XCTAssertEqual(actual.magnitude, magnitude)
        }

        test(type: Int8.self, digits: 3, magnitude: 100)
        test(type: Int16.self, digits: 5, magnitude: 10_000)
        test(type: Int32.self, digits: 10, magnitude: 1_000_000_000)
        test(type: Int64.self, digits: 19, magnitude: 1_000_000_000_000_000_000)

        test(type: UInt8.self, digits: 3, magnitude: 100)
        test(type: UInt16.self, digits: 5, magnitude: 10_000)
        test(type: UInt32.self, digits: 10, magnitude: 1_000_000_000)
        test(type: UInt64.self, digits: 20, magnitude: 10_000_000_000_000_000_000)
    }
}
