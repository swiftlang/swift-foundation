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

final class DurationExtensionTests : XCTestCase {

    func testRoundingMode() {

        func verify(_ tests: [Int64], increment: Int64, expected: [FloatingPointRoundingRule: [Int64]], file: StaticString = #file, line: UInt = #line) {
            let modes: [FloatingPointRoundingRule] = [.down, .up, .towardZero, .awayFromZero, .toNearestOrEven, .toNearestOrAwayFromZero]
            for mode in modes {
                var actual: [Duration] = []
                for test in tests {
                    actual.append(Duration.seconds(test).rounded(increment: Duration.seconds(increment), rule: mode))
                }
                XCTAssertEqual(actual, expected[mode]?.map { Duration.seconds($0) }, "\(mode) does not match", file: file, line: line)
            }
        }

        verify([9223372036854775018, 18, 15, 12, 8, 5, 2, 0], increment: 10, expected: [
            .down :         [9223372036854775010, 10, 10, 10, 0, 0, 0, 0],
            .up   :         [9223372036854775020, 20, 20, 20, 10, 10, 10, 0],
            .towardZero:    [9223372036854775010, 10, 10, 10, 0, 0, 0, 0],
            .awayFromZero:              [9223372036854775020, 20, 20, 20, 10, 10, 10, 0],
            .toNearestOrEven:           [9223372036854775020, 20, 20, 10, 10, 0, 0, 0],
            .toNearestOrAwayFromZero:   [9223372036854775020, 20, 20, 10, 10, 10, 0, 0]
        ])

        verify([ -2, -5, -8, -12, -15, -18, -9223372036854775018 ], increment: 10, expected: [
            .down :         [-10, -10, -10, -20, -20, -20, -9223372036854775020],
            .up   :         [  0,   0,   0, -10, -10, -10, -9223372036854775010],
            .towardZero:    [  0,   0,   0, -10, -10, -10, -9223372036854775010],
            .awayFromZero:              [-10, -10, -10, -20, -20, -20, -9223372036854775020],
            .toNearestOrEven:           [  0,   0, -10, -10, -20, -20, -9223372036854775020],
            .toNearestOrAwayFromZero:   [  0, -10, -10, -10, -20, -20, -9223372036854775020]
        ])

        verify([9223372036854775018, 18, 15, 12, 8, 5, 2, 0], increment: 5, expected: [
            .down :         [9223372036854775015, 15, 15, 10, 5, 5, 0, 0],
            .up   :         [9223372036854775020, 20, 15, 15, 10, 5, 5, 0],
            .towardZero:    [9223372036854775015, 15, 15, 10, 5, 5, 0, 0],
            .awayFromZero:              [9223372036854775020, 20, 15, 15, 10, 5, 5, 0],
            .toNearestOrEven:           [9223372036854775020, 20, 15, 10, 10, 5, 0, 0],
            .toNearestOrAwayFromZero:   [9223372036854775020, 20, 15, 10, 10, 5, 0, 0]
        ])

        verify([ -2, -5, -8, -12, -15, -18, -9223372036854775018 ], increment: 5, expected: [
            .down :         [ -5, -5, -10, -15, -15, -20, -9223372036854775020],
            .up   :         [  0, -5,  -5, -10, -15, -15, -9223372036854775015],
            .towardZero:    [  0, -5,  -5, -10, -15, -15, -9223372036854775015],
            .awayFromZero:              [ -5, -5, -10, -15, -15, -20,  -9223372036854775020],
            .toNearestOrEven:           [  0, -5, -10, -10, -15, -20,  -9223372036854775020],
            .toNearestOrAwayFromZero:   [  0, -5, -10, -10, -15, -20,  -9223372036854775020]
        ])

        verify([9223372036854775018, 18, 15, 12, 8, 5, 2, 0], increment: -10, expected: [
            .down :         [9223372036854775010, 10, 10, 10, 0, 0, 0, 0],
            .up   :         [9223372036854775020, 20, 20, 20, 10, 10, 10, 0],
            .towardZero:    [9223372036854775010, 10, 10, 10, 0, 0, 0, 0],
            .awayFromZero:              [9223372036854775020, 20, 20, 20, 10, 10, 10, 0],
            .toNearestOrEven:           [9223372036854775020, 20, 20, 10, 10, 0, 0, 0],
            .toNearestOrAwayFromZero:   [9223372036854775020, 20, 20, 10, 10, 10, 0, 0]
        ])

        verify([ -2, -5, -8, -12, -15, -18, -9223372036854775018 ], increment: -10, expected: [
            .down :         [-10, -10, -10, -20, -20, -20, -9223372036854775020],
            .up   :         [  0,   0,   0, -10, -10, -10, -9223372036854775010],
            .towardZero:    [  0,   0,   0, -10, -10, -10, -9223372036854775010],
            .awayFromZero:              [-10, -10, -10, -20, -20, -20, -9223372036854775020],
            .toNearestOrEven:           [  0,   0, -10, -10, -20, -20, -9223372036854775020],
            .toNearestOrAwayFromZero:   [  0, -10, -10, -10, -20, -20, -9223372036854775020]
        ])

        verify([9223372036854775018, 18, 15, 12, 8, 5, 2, 0], increment: 9223372036854775807, expected: [
            .down :         [0, 0, 0, 0, 0, 0, 0, 0],
            .up   :         [9223372036854775807, 9223372036854775807, 9223372036854775807, 9223372036854775807, 9223372036854775807, 9223372036854775807, 9223372036854775807, 0],
            .towardZero:    [0, 0, 0, 0, 0, 0, 0, 0],
            .awayFromZero:              [9223372036854775807, 9223372036854775807, 9223372036854775807, 9223372036854775807, 9223372036854775807, 9223372036854775807, 9223372036854775807, 0],
            .toNearestOrEven:           [9223372036854775807, 0, 0, 0, 0, 0, 0, 0],
            .toNearestOrAwayFromZero:   [9223372036854775807, 0, 0, 0, 0, 0, 0, 0]
        ])
    }
}
