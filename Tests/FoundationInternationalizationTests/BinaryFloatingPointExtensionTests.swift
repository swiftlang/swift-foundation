//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(TestSupport)
import TestSupport
#endif

#if canImport(FoundationInternationalization)
@testable import FoundationInternationalization
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#endif

final class BinaryFloatingPointExtensionTests: XCTestCase {

    func assertApproximatelyEqual(_ test: [Double], expected: [Double], file: StaticString = #file, line: UInt = #line) {
        let precision = 100000.0
        let roundedTests = test.map { Int64(floor($0 * precision)) }
        let roundedExpectations = expected.map { Int64(floor($0 * precision)) }
        XCTAssertEqual(roundedTests, roundedExpectations, file: file, line: line)
    }

    func testRoundingIncrement() {
        func verify(_ test: Double, mode: FloatingPointRoundingRule, expected: [(increment: Double, expectation: Double)], file: StaticString = #file, line: UInt = #line) {

            let accuracy = 0.00001
            for (inc, expectation) in expected {
                let actual = test.rounded(increment: inc, rule: mode)
                XCTAssertEqual(actual, expectation, accuracy: accuracy, "increment: \(inc) failed", file: file, line: line)
            }
        }

        verify(123.5678, mode: .up, expected: [
            (10.0, 130),
            (5.00, 125),
            (1.00, 124),
            (0.50, 124),
            (0.10, 123.6),
            (0.01, 123.57)
        ])

        verify(123.5678, mode: .down, expected: [
            (10.0, 120),
            (5.00, 120),
            (1.00, 123),
            (0.50, 123.5),
            (0.10, 123.5),
            (0.01, 123.56)
        ])

        verify(8.599, mode: .up, expected: [
            (10.0, 10),
            (5.00, 10),
            (1.00, 9),
            (0.50, 9),
            (0.10, 8.6),
            (0.01, 8.6)
        ])

        verify(8.599, mode: .down, expected: [
            (10.0, 0),
            (5.00, 5),
            (1.00, 8),
            (0.50, 8.5),
            (0.10, 8.5),
            (0.01, 8.59)
        ])

        verify(99.799, mode: .up, expected: [
            (10.0, 100),
            (5.00, 100),
            (1.00, 100),
            (0.50, 100),
            (0.10, 99.8),
            (0.01, 99.8)
        ])

        verify(99.799, mode: .down, expected: [
            (10.0, 90),
            (5.00, 95),
            (1.00, 99),
            (0.50, 99.5),
            (0.10, 99.7),
            (0.01, 99.79)
        ])
    }

    func testRoundToPrecision() {
        func verify(_ test: Double, base: Int, mode: FloatingPointRoundingRule, expected: [Int: (Int64, Int64)], file: StaticString = #file, line: UInt = #line) {
            for (digit, expectation) in expected {
                let actual = test.roundedToPrecision(digit, base: base, rule: mode)
                XCTAssertEqual(actual.0, expectation.0, "\(digit) precision does not match", file: file, line: line)
                XCTAssertEqual(actual.1, expectation.1, "\(digit) precision digits does not match", file: file, line: line)
            }
        }

        verify(80, base: 60, mode: .down, expected: [
            00: (60, 0),         // Representing 60 in terms of 60 is "1", which has exactly no fractional digits
            01: (78, 0),         // Representing 78 in terms of 60 is "1.3", which has exactly one fractional digit
            02: (79, 800000000), // Representing 79.8 in terms of 60 is "1.33", which has exactly 2 fractional digits
            03: (79, 980000000)
        ])

        verify(80, base: 60, mode: .up, expected: [
            00: (120, 0),       // Representing 120 in terms of 60 is "2", which has exactly no fractional digits
            01: (84, 0),        // Representing 84 in terms of 60 is "1.4", which has exactly 1 fractional digits
            02: (80, 400000000),
            03: (80, 40000000)
        ])
    }

}
