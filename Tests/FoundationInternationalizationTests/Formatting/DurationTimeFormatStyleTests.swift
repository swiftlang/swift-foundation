//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing

#if canImport(FoundationInternationalization)
@testable import FoundationEssentials
@testable import FoundationInternationalization
#elseif FOUNDATION_FRAMEWORK
@testable import Foundation
#endif



extension Duration {
    init(weeks: Int64 = 0, days: Int64 = 0, hours: Int64 = 0, minutes: Int64 = 0, seconds: Int64 = 0, milliseconds: Int64 = 0, microseconds: Int64 = 0) {
        self = .init(secondsComponent: Int64(weeks * 604800 + days * 86400 + hours * 3600 + minutes * 60 + seconds),
                     attosecondsComponent: Int64(milliseconds * 1_000_000_000_000_000 + microseconds * 1_000_000_000_000))
    }
}

struct DurationToMeasurementAdditionTests {
    typealias Unit = Duration._UnitsFormatStyle.Unit
    func assertEqualDurationUnitValues(_ duration: Duration, units: [Unit], rounding: FloatingPointRoundingRule = .toNearestOrEven, trailingFractionalLength: Int = .max, roundingIncrement: Double? = nil, expectation values: [Double], sourceLocation: SourceLocation = #_sourceLocation) {
        let result = duration.valuesForUnits(units, trailingFractionalLength: trailingFractionalLength, smallestUnitRounding: rounding, roundingIncrement: roundingIncrement)
        #expect(result == values, sourceLocation: sourceLocation)
    }

    @Test func testDurationToMeasurements() {
        let hmsn : [Unit] = [ .hours, .minutes, .seconds, .nanoseconds]
        assertEqualDurationUnitValues(.seconds(0), units: hmsn, expectation: [0, 0, 0, 0])
        assertEqualDurationUnitValues(.seconds(35), units: hmsn, expectation: [0, 0, 35, 0])
        assertEqualDurationUnitValues(.seconds(60), units: hmsn, expectation: [0, 1, 0, 0])
        assertEqualDurationUnitValues(.seconds(120), units: hmsn, expectation: [0, 2, 0, 0])
        assertEqualDurationUnitValues(.seconds(3600), units: hmsn, expectation: [1, 0, 0, 0])
        assertEqualDurationUnitValues(.seconds(3600 + 60 + 35), units: hmsn, expectation: [1, 1, 35, 0])
        assertEqualDurationUnitValues(.init(seconds: 3600 + 60 + 35, milliseconds: 5), units: hmsn, expectation: [1, 1, 35, 5_000_000 ])
        assertEqualDurationUnitValues(.init(seconds: 3600 + 60 + 35, milliseconds: 5), units: hmsn, trailingFractionalLength: 0 ,roundingIncrement: 1e6, expectation: [1, 1, 35, 5_000_000 ])


        let hms : [Unit] = [ .hours, .minutes, .seconds]
        assertEqualDurationUnitValues(.seconds(0), units: hms, expectation: [0, 0, 0 ])
        assertEqualDurationUnitValues(.seconds(35), units: hms, expectation: [0, 0, 35])
        assertEqualDurationUnitValues(.seconds(60), units: hms, expectation: [0, 1, 0])
        assertEqualDurationUnitValues(.seconds(120), units: hms, expectation: [0, 2, 0])
        assertEqualDurationUnitValues(.seconds(3600), units: hms, expectation: [1, 0, 0])
        assertEqualDurationUnitValues(.seconds(3600 + 60 + 35), units: hms, expectation: [1, 1, 35])
        assertEqualDurationUnitValues(.init(seconds: 3600 + 60 + 35, milliseconds: 500), units: hms, expectation: [1, 1, 35.5])
        assertEqualDurationUnitValues(.init(seconds: 3600 + 60 + 35, milliseconds: 500), units: hms, trailingFractionalLength: 1, expectation: [1, 1, 35.5 ])

        let hm : [Unit] = [ .hours, .minutes ]
        assertEqualDurationUnitValues(.seconds(3600 + 60 + 24), units: hm, trailingFractionalLength: 1, expectation: [1, 1.4])
        assertEqualDurationUnitValues(.seconds(3600 + 60 + 30), units: hm, trailingFractionalLength: 1, expectation: [1, 1.5])
    }

    @Test func testDurationRounding() {
        func test(_ duration: Duration, units: [Unit], trailingFractionalLength: Int = 0, _ tests: (rounding: FloatingPointRoundingRule, expected: [Double])..., sourceLocation: SourceLocation = #_sourceLocation) {
            for (i, (rounding, expected)) in tests.enumerated() {
                var loc = sourceLocation
                loc.line += i + 1
                assertEqualDurationUnitValues(duration, units: units, rounding: rounding, trailingFractionalLength: trailingFractionalLength, expectation: expected, sourceLocation: loc)

                let equivalentRoundingForNegativeValue: FloatingPointRoundingRule
                switch rounding {
                case .down:
                    equivalentRoundingForNegativeValue = .up
                case .up:
                    equivalentRoundingForNegativeValue = .down
                default:
                    equivalentRoundingForNegativeValue = rounding
                }

                assertEqualDurationUnitValues(.zero - duration, units: units, rounding: equivalentRoundingForNegativeValue, trailingFractionalLength: trailingFractionalLength, expectation: expected.map { -$0 }, sourceLocation: loc)
            }
        }
        // [.nanoseconds]
        test(.seconds(Int64.max), units: [.nanoseconds],
             (.down, [Double(Int64.max) * 1e9])
        )

        // [.seconds]
        test(.init(milliseconds: 499), units: [.seconds],
             (.toNearestOrAwayFromZero, [0]),
             (.down, [0]),
             (.up, [1])
        )

        test(.init(milliseconds: 499), units: [.seconds], trailingFractionalLength: 1,
             (.toNearestOrAwayFromZero, [0.5]),
             (.down, [0.4]),
             (.up, [0.5])
        )

        test(.init(milliseconds: 500), units: [.seconds],
             (.toNearestOrAwayFromZero, [1]),
             (.down, [0]),
             (.up, [1])
        )

        test(.init(milliseconds: 999), units: [.seconds],
             (.toNearestOrAwayFromZero, [1]),
             (.down, [0]),
             (.up, [1])
        )

        test(.init(milliseconds: 999, microseconds: 500), units: [.seconds],
             (.toNearestOrAwayFromZero, [1]),
             (.down, [0]),
             (.up, [1])
        )

        test(.init(seconds: 59, milliseconds: 999), units: [.seconds],
             (.toNearestOrAwayFromZero, [60]),
             (.down, [59]),
             (.up, [60])
        )

        // [ .minutes, .seconds ]

        test(.init(milliseconds: 499), units: [ .minutes, .seconds ],
             (.toNearestOrAwayFromZero, [0, 0]),
             (.down, [0, 0]),
             (.up, [0, 1])
        )

        test(.init(milliseconds: 500), units: [ .minutes, .seconds ],
             (.toNearestOrAwayFromZero, [0, 1]),
             (.down, [0, 0]),
             (.up, [0, 1])
        )

        test(.init(seconds: 59, milliseconds: 400), units: [ .minutes, .seconds ],
             (.toNearestOrAwayFromZero, [0, 59]),
             (.down, [0, 59]),
             (.up, [1, 0])
        )

        test(.init(seconds: 59, milliseconds: 500), units: [ .minutes, .seconds ],
             (.toNearestOrAwayFromZero, [1, 0]),
             (.down, [0, 59]),
             (.up, [1, 0])
        )

        test(.init(seconds: 59, milliseconds: 999), units: [ .minutes, .seconds ],
             (.toNearestOrAwayFromZero, [1, 0]),
             (.down, [0, 59]),
             (.up, [1, 0])
        )

        test(.init(minutes: 16, milliseconds: 499), units: [ .minutes, .seconds ],
             (.toNearestOrAwayFromZero, [16, 0]),
             (.down, [16, 0]),
             (.up, [16, 1])
        )

        test(.init(minutes: 16, milliseconds: 500), units: [ .minutes, .seconds ],
             (.toNearestOrAwayFromZero, [16, 1]),
             (.down, [16, 0]),
             (.up, [16, 1])
        )

        test(.init(minutes: 16, seconds: 59, milliseconds: 499), units: [ .minutes, .seconds ],
             (.toNearestOrAwayFromZero, [16, 59]),
             (.down, [16, 59]),
             (.up, [17, 0])
        )

        test(.init(minutes: 16, seconds: 59, milliseconds: 500), units: [ .minutes, .seconds ],
             (.toNearestOrAwayFromZero, [17, 0]),
             (.down, [16, 59]),
             (.up, [17, 0])
        )

        test(.init(minutes: 59, seconds: 59, milliseconds: 499), units: [ .minutes, .seconds ],
             (.toNearestOrAwayFromZero, [59, 59]),
             (.down, [59, 59]),
             (.up, [60, 0])
        )

        test(.init(minutes: 59, seconds: 59, milliseconds: 500), units: [ .minutes, .seconds ],
             (.toNearestOrAwayFromZero, [60, 0]),
             (.down, [59, 59]),
             (.up, [60, 0])
        )

        // [ .hours, .minutes, .seconds ]

        test(.init(milliseconds: 499), units: [ .hours, .minutes, .seconds ],
             (.toNearestOrAwayFromZero, [0, 0, 0]),
             (.down,  [0, 0, 0]),
             (.up,  [0, 0, 1])
        )

        test(.init(milliseconds: 500), units: [ .hours, .minutes, .seconds ],
             (.toNearestOrAwayFromZero, [0, 0, 1]),
             (.down,  [0, 0, 0]),
             (.up,  [0, 0, 1])
        )

        test(.init(minutes: 59, seconds: 59, milliseconds: 499), units: [ .hours, .minutes, .seconds ],
             (.toNearestOrAwayFromZero, [0, 59, 59]),
             (.down,  [0, 59, 59]),
             (.up,  [1, 0, 0])
        )

        test(.init(minutes: 59, seconds: 59, milliseconds: 500), units: [ .hours, .minutes, .seconds ],
             (.toNearestOrAwayFromZero, [1, 0, 0]),
             (.down,  [0, 59, 59]),
             (.up,  [1, 0, 0])
        )

        // [ .hours, .minutes ]

        test(.init(minutes: 59, seconds: 29, milliseconds: 999), units: [ .hours, .minutes ],
             (.toNearestOrAwayFromZero, [0, 59]),
             (.down, [0, 59]),
             (.up, [1, 0])
        )

        test(.init(minutes: 59, seconds: 30), units: [ .hours, .minutes ],
             (.toNearestOrAwayFromZero, [1, 0]),
             (.down, [0, 59]),
             (.up, [1, 0])
        )

        // [ .minutes, .seconds, .milliseconds ]

        test(.init(minutes: 16, seconds: 59, milliseconds: 500), units: [ .minutes, .seconds, .milliseconds ],
             (.toNearestOrAwayFromZero, [16, 59, 500]),
             (.down, [16, 59, 500]),
             (.up, [16, 59, 500])
        )

        test(.init(minutes: 16, seconds: 59, milliseconds: 999, microseconds: 499), units: [ .minutes, .seconds, .milliseconds ],
             (.toNearestOrAwayFromZero, [16, 59, 999]),
             (.down, [16, 59, 999]),
             (.up, [17, 0, 0])
        )

        test(.init(minutes: 16, seconds: 59, milliseconds: 999, microseconds: 500), units: [ .minutes, .seconds, .milliseconds ],
             (.toNearestOrAwayFromZero, [17, 0, 0]),
             (.down, [16, 59, 999]),
             (.up, [17, 0, 0])
        )

        // [ .milliseconds ]

        test(.init(milliseconds: 999, microseconds: 499), units: [ .milliseconds ],
             (.toNearestOrAwayFromZero, [999]),
             (.down, [999]),
             (.up, [1000])
        )

        test(.init(milliseconds: 999, microseconds: 500), units: [ .milliseconds ],
             (.toNearestOrAwayFromZero, [1000]),
             (.down, [999]),
             (.up, [1000])
        )

        test(.init(seconds: 1, milliseconds: 999, microseconds: 499), units: [ .milliseconds ],
             (.toNearestOrAwayFromZero, [1999]),
             (.down, [1999]),
             (.up, [2000])
        )

        test(.init(seconds: 1, milliseconds: 999, microseconds: 500), units: [ .milliseconds ],
             (.toNearestOrAwayFromZero, [2000]),
             (.down, [1999]),
             (.up, [2000])
        )

        // [.milliseconds, .microseconds]
        test(.init(milliseconds: 999, microseconds: 499), units: [ .milliseconds, .microseconds ],
             (.toNearestOrAwayFromZero, [999, 499]),
             (.down, [999, 499]),
             (.up, [999, 499])
        )

        test(.init(milliseconds: 999, microseconds: 499), units: [ .milliseconds, .microseconds ],
             (.toNearestOrAwayFromZero, [999, 499]),
             (.down, [999, 499]),
             (.up, [999, 499])
        )
    }
}

struct TestDurationTimeFormatStyle {
    let enUS = Locale(identifier: "en_US")

    func assertFormattedWithPattern(seconds: Int, milliseconds: Int = 0, pattern: Duration._TimeFormatStyle.Pattern, grouping: NumberFormatStyleConfiguration.Grouping? = nil, expected: String, sourceLocation: SourceLocation = #_sourceLocation) {
        var style = Duration._TimeFormatStyle(pattern: pattern).locale(enUS)
        if let grouping {
            style.grouping = grouping
        }
        #expect(Duration(seconds: Int64(seconds), milliseconds: Int64(milliseconds)).formatted(style) == expected, sourceLocation: sourceLocation)
    }

    @Test func testDurationPatternStyle() {
        assertFormattedWithPattern(seconds: 3695, pattern: .hourMinute, expected: "1:02")
        assertFormattedWithPattern(seconds: 3695, pattern: .hourMinute(padHourToLength: 1, roundSeconds: .down), expected: "1:01")
        assertFormattedWithPattern(seconds: 3695, pattern: .hourMinuteSecond, expected: "1:01:35")
        assertFormattedWithPattern(seconds: 3695, milliseconds: 510, pattern: .hourMinuteSecond(padHourToLength: 1, roundFractionalSeconds: .up), expected: "1:01:36")

        assertFormattedWithPattern(seconds: 3695, pattern: .minuteSecond, expected: "61:35")
        assertFormattedWithPattern(seconds: 3695, pattern: .minuteSecond(padMinuteToLength: 2), expected: "61:35")
        assertFormattedWithPattern(seconds: 3695, pattern: .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 2), expected: "61:35.00")
        assertFormattedWithPattern(seconds: 3695, milliseconds: 350, pattern: .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 2), expected: "61:35.35")
    }

    @Test func testDurationPatternPadding() {
        assertFormattedWithPattern(seconds: 3695, pattern: .hourMinute(padHourToLength: 2), expected: "01:02")
        assertFormattedWithPattern(seconds: 3695, pattern: .hourMinuteSecond(padHourToLength: 2), expected: "01:01:35")
        assertFormattedWithPattern(seconds: 3695, pattern: .hourMinuteSecond(padHourToLength: 2, fractionalSecondsLength: 2), expected: "01:01:35.00")
        assertFormattedWithPattern(seconds: 3695, milliseconds: 500, pattern: .hourMinuteSecond(padHourToLength: 2, fractionalSecondsLength: 2), expected: "01:01:35.50")
    }

    @Test func testDurationPatternGrouping() {
        assertFormattedWithPattern(seconds: 36950000, pattern: .hourMinute(padHourToLength: 2), grouping: nil, expected: "10,263:53")
        assertFormattedWithPattern(seconds: 36950000, pattern: .hourMinute(padHourToLength: 2), grouping: .automatic, expected: "10,263:53")
        assertFormattedWithPattern(seconds: 36950000, pattern: .hourMinute(padHourToLength: 2), grouping: .never, expected: "10263:53")
    }

    @Test func testNoFractionParts() {

        // minutes, seconds

        assertFormattedWithPattern(seconds: 0, milliseconds: 499, pattern: .minuteSecond, expected: "0:00")
        assertFormattedWithPattern(seconds: 0, milliseconds: 500, pattern: .minuteSecond, expected: "0:00")
        assertFormattedWithPattern(seconds: 0, milliseconds: 501, pattern: .minuteSecond, expected: "0:01")
        assertFormattedWithPattern(seconds: 0, milliseconds: 999, pattern: .minuteSecond, expected: "0:01")
        assertFormattedWithPattern(seconds: 1, milliseconds: 005, pattern: .minuteSecond, expected: "0:01")
        assertFormattedWithPattern(seconds: 1, milliseconds: 499, pattern: .minuteSecond, expected: "0:01")
        assertFormattedWithPattern(seconds: 1, milliseconds: 501, pattern: .minuteSecond, expected: "0:02")
        assertFormattedWithPattern(seconds: 59, milliseconds: 499, pattern: .minuteSecond, expected: "0:59")
        assertFormattedWithPattern(seconds: 59, milliseconds: 500, pattern: .minuteSecond, expected: "1:00")
        assertFormattedWithPattern(seconds: 59, milliseconds: 501, pattern: .minuteSecond, expected: "1:00")
        assertFormattedWithPattern(seconds: 60, milliseconds: 499, pattern: .minuteSecond, expected: "1:00")
        assertFormattedWithPattern(seconds: 60, milliseconds: 500, pattern: .minuteSecond, expected: "1:00")
        assertFormattedWithPattern(seconds: 60, milliseconds: 501, pattern: .minuteSecond, expected: "1:01")

        assertFormattedWithPattern(seconds: 1019, milliseconds: 490, pattern: .minuteSecond, expected: "16:59")
        assertFormattedWithPattern(seconds: 1019, milliseconds: 500, pattern: .minuteSecond, expected: "17:00")
        assertFormattedWithPattern(seconds: 1019, milliseconds: 510, pattern: .minuteSecond, expected: "17:00")

        assertFormattedWithPattern(seconds: 3629, milliseconds: 490, pattern: .minuteSecond, expected: "60:29")
        assertFormattedWithPattern(seconds: 3629, milliseconds: 500, pattern: .minuteSecond, expected: "60:30")
        assertFormattedWithPattern(seconds: 3629, milliseconds: 510, pattern: .minuteSecond, expected: "60:30")

        assertFormattedWithPattern(seconds: 3659, milliseconds: 490, pattern: .minuteSecond, expected: "60:59")
        assertFormattedWithPattern(seconds: 3659, milliseconds: 500, pattern: .minuteSecond, expected: "61:00")
        assertFormattedWithPattern(seconds: 3659, milliseconds: 510, pattern: .minuteSecond, expected: "61:00")

        // hours, minutes, seconds

        assertFormattedWithPattern(seconds: 0, milliseconds: 499, pattern: .hourMinuteSecond, expected: "0:00:00")
        assertFormattedWithPattern(seconds: 0, milliseconds: 500, pattern: .hourMinuteSecond, expected: "0:00:00")
        assertFormattedWithPattern(seconds: 0, milliseconds: 501, pattern: .hourMinuteSecond, expected: "0:00:01")

        assertFormattedWithPattern(seconds: 3599, milliseconds: 499, pattern: .hourMinuteSecond, expected: "0:59:59")
        assertFormattedWithPattern(seconds: 3599, milliseconds: 500, pattern: .hourMinuteSecond, expected: "1:00:00")
        assertFormattedWithPattern(seconds: 3599, milliseconds: 501, pattern: .hourMinuteSecond, expected: "1:00:00")

        assertFormattedWithPattern(seconds: 7199, milliseconds: 499, pattern: .hourMinuteSecond, expected: "1:59:59")
        assertFormattedWithPattern(seconds: 7199, milliseconds: 500, pattern: .hourMinuteSecond, expected: "2:00:00")
        assertFormattedWithPattern(seconds: 7199, milliseconds: 501, pattern: .hourMinuteSecond, expected: "2:00:00")

        // hours, minutes

        // 59 minutes
        assertFormattedWithPattern(seconds: 3569, milliseconds: 499, pattern: .hourMinute, expected: "0:59")
        assertFormattedWithPattern(seconds: 3569, milliseconds: 500, pattern: .hourMinute, expected: "0:59") // 29.5 seconds is still less than half minutes, so it would be rounded down
        assertFormattedWithPattern(seconds: 3570, pattern: .hourMinute, expected: "1:00")

        // 1 hour, 0 minutes, x seconds
        assertFormattedWithPattern(seconds: 3629, milliseconds: 400, pattern: .hourMinute, expected: "1:00")
        assertFormattedWithPattern(seconds: 3629, milliseconds: 900, pattern: .hourMinute, expected: "1:00")
        assertFormattedWithPattern(seconds: 3630, milliseconds: 000, pattern: .hourMinute, expected: "1:00")
        assertFormattedWithPattern(seconds: 3630, milliseconds: 100, pattern: .hourMinute, expected: "1:01")
        assertFormattedWithPattern(seconds: 3630, milliseconds: 900, pattern: .hourMinute, expected: "1:01")
        assertFormattedWithPattern(seconds: 3631, milliseconds: 000, pattern: .hourMinute, expected: "1:01")
        assertFormattedWithPattern(seconds: 3659, milliseconds: 400, pattern: .hourMinute, expected: "1:01")
        assertFormattedWithPattern(seconds: 3659, milliseconds: 500, pattern: .hourMinute, expected: "1:01")

        // 1 hour, 29 minutes, x seconds
        assertFormattedWithPattern(seconds: 5369, milliseconds: 400, pattern: .hourMinute, expected: "1:29")
        assertFormattedWithPattern(seconds: 5369, milliseconds: 900, pattern: .hourMinute, expected: "1:29")
        assertFormattedWithPattern(seconds: 5370, milliseconds: 000, pattern: .hourMinute, expected: "1:30")
        assertFormattedWithPattern(seconds: 5370, milliseconds: 100, pattern: .hourMinute, expected: "1:30")
        assertFormattedWithPattern(seconds: 5399, milliseconds: 400, pattern: .hourMinute, expected: "1:30")
        assertFormattedWithPattern(seconds: 5399, milliseconds: 500, pattern: .hourMinute, expected: "1:30")
    }

    @Test func testShowFractionalSeconds() {

        // minutes, seconds

        assertFormattedWithPattern(seconds: 0, milliseconds: 499, pattern: .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 2), expected: "00:00.50")
        assertFormattedWithPattern(seconds: 0, milliseconds: 999, pattern: .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 2), expected: "00:01.00")

        assertFormattedWithPattern(seconds: 1, milliseconds: 005, pattern: .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 2), expected: "00:01.00")
        assertFormattedWithPattern(seconds: 1, milliseconds: 499, pattern: .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 2), expected: "00:01.50")
        assertFormattedWithPattern(seconds: 1, milliseconds: 999, pattern: .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 2), expected: "00:02.00")
        assertFormattedWithPattern(seconds: 59, milliseconds: 994, pattern: .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 2), expected: "00:59.99")
        assertFormattedWithPattern(seconds: 59, milliseconds: 995, pattern: .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 2), expected: "01:00.00")
        assertFormattedWithPattern(seconds: 59, milliseconds: 996, pattern: .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 2), expected: "01:00.00")

        assertFormattedWithPattern(seconds: 1019, milliseconds: 994, pattern: .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 2), expected: "16:59.99")
        assertFormattedWithPattern(seconds: 1019, milliseconds: 995, pattern: .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 2), expected: "17:00.00")
        assertFormattedWithPattern(seconds: 1019, milliseconds: 996, pattern: .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 2), expected: "17:00.00")

        assertFormattedWithPattern(seconds: 3629, milliseconds: 994, pattern: .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 2), expected: "60:29.99")
        assertFormattedWithPattern(seconds: 3629, milliseconds: 995, pattern: .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 2), expected: "60:30.00")
        assertFormattedWithPattern(seconds: 3629, milliseconds: 996, pattern: .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 2), expected: "60:30.00")

        assertFormattedWithPattern(seconds: 3659, milliseconds: 994, pattern: .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 2), expected: "60:59.99")
        assertFormattedWithPattern(seconds: 3659, milliseconds: 995, pattern: .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 2), expected: "61:00.00")
        assertFormattedWithPattern(seconds: 3659, milliseconds: 996, pattern: .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 2), expected: "61:00.00")

        // hours, minutes, seconds

        assertFormattedWithPattern(seconds: 0, milliseconds: 499, pattern: .hourMinuteSecond(padHourToLength: 2, fractionalSecondsLength: 2), expected: "00:00:00.50")
        assertFormattedWithPattern(seconds: 0, milliseconds: 994, pattern: .hourMinuteSecond(padHourToLength: 2, fractionalSecondsLength: 2), expected: "00:00:00.99")
        assertFormattedWithPattern(seconds: 0, milliseconds: 995, pattern: .hourMinuteSecond(padHourToLength: 2, fractionalSecondsLength: 2), expected: "00:00:01.00")
        assertFormattedWithPattern(seconds: 0, milliseconds: 996, pattern: .hourMinuteSecond(padHourToLength: 2, fractionalSecondsLength: 2), expected: "00:00:01.00")

        assertFormattedWithPattern(seconds: 3599, milliseconds: 499, pattern: .hourMinuteSecond(padHourToLength: 2, fractionalSecondsLength: 2), expected: "00:59:59.50")
        assertFormattedWithPattern(seconds: 3599, milliseconds: 994, pattern: .hourMinuteSecond(padHourToLength: 2, fractionalSecondsLength: 2), expected: "00:59:59.99")
        assertFormattedWithPattern(seconds: 3599, milliseconds: 995, pattern: .hourMinuteSecond(padHourToLength: 2, fractionalSecondsLength: 2), expected: "01:00:00.00")
        assertFormattedWithPattern(seconds: 3599, milliseconds: 996, pattern: .hourMinuteSecond(padHourToLength: 2, fractionalSecondsLength: 2), expected: "01:00:00.00")

        assertFormattedWithPattern(seconds: 7199, milliseconds: 499, pattern: .hourMinuteSecond(padHourToLength: 2, fractionalSecondsLength: 2), expected: "01:59:59.50")
        assertFormattedWithPattern(seconds: 7199, milliseconds: 994, pattern: .hourMinuteSecond(padHourToLength: 2, fractionalSecondsLength: 2), expected: "01:59:59.99")
        assertFormattedWithPattern(seconds: 7199, milliseconds: 996, pattern: .hourMinuteSecond(padHourToLength: 2, fractionalSecondsLength: 2), expected: "02:00:00.00")
        assertFormattedWithPattern(seconds: 7199, milliseconds: 995, pattern: .hourMinuteSecond(padHourToLength: 2, fractionalSecondsLength: 2), expected: "02:00:00.00")
    }

    @Test func testNegativeValues() {
        assertFormattedWithPattern(seconds: 0, milliseconds: -499, pattern: .hourMinuteSecond, expected: "0:00:00")
        assertFormattedWithPattern(seconds: 0, milliseconds: -500, pattern: .hourMinuteSecond, expected: "0:00:00")
        assertFormattedWithPattern(seconds: 0, milliseconds: -501, pattern: .hourMinuteSecond, expected: "-0:00:01")

        assertFormattedWithPattern(seconds: 0, milliseconds: -499, pattern: .minuteSecond, expected: "0:00")
        assertFormattedWithPattern(seconds: 0, milliseconds: -500, pattern: .minuteSecond, expected: "0:00")
        assertFormattedWithPattern(seconds: 0, milliseconds: -501, pattern: .minuteSecond, expected: "-0:01")

        assertFormattedWithPattern(seconds: -59 * 60 - 59, milliseconds: -499, pattern: .hourMinuteSecond, expected: "-0:59:59")
        assertFormattedWithPattern(seconds: -59 * 60 - 59, milliseconds: -500, pattern: .hourMinuteSecond, expected: "-1:00:00")
        assertFormattedWithPattern(seconds: -59 * 60 - 59, milliseconds: -501, pattern: .hourMinuteSecond, expected: "-1:00:00")

        assertFormattedWithPattern(seconds: -3600 - 59 * 60 - 59, milliseconds: -499, pattern: .hourMinuteSecond, expected: "-1:59:59")
        assertFormattedWithPattern(seconds: -3600 - 59 * 60 - 59, milliseconds: -500, pattern: .hourMinuteSecond, expected: "-2:00:00")
        assertFormattedWithPattern(seconds: -3600 - 59 * 60 - 59, milliseconds: -501, pattern: .hourMinuteSecond, expected: "-2:00:00")

        assertFormattedWithPattern(seconds: -59 * 60 - 59, milliseconds: -499, pattern: .hourMinuteSecond(padHourToLength: 2, fractionalSecondsLength: 2), expected: "-00:59:59.50")
        assertFormattedWithPattern(seconds: -59 * 60 - 59, milliseconds: -994, pattern: .hourMinuteSecond(padHourToLength: 2, fractionalSecondsLength: 2), expected: "-00:59:59.99")
        assertFormattedWithPattern(seconds: -59 * 60 - 59, milliseconds: -995, pattern: .hourMinuteSecond(padHourToLength: 2, fractionalSecondsLength: 2), expected: "-01:00:00.00")
        assertFormattedWithPattern(seconds: -59 * 60 - 59, milliseconds: -996, pattern: .hourMinuteSecond(padHourToLength: 2, fractionalSecondsLength: 2), expected: "-01:00:00.00")
    }
}

// MARK: - Attributed string test

extension Sequence where Element == DurationTimeAttributedStyleTests.Segment {
    var attributedString: AttributedString {
        self.map { tuple in
            var attrs = AttributeContainer()
            if let field = tuple.1 {
                attrs = attrs.durationField(field)
            }

            return AttributedString(tuple.0, attributes: attrs)
        }.reduce(AttributedString(), +)
    }
}

struct DurationTimeAttributedStyleTests {

    typealias Segment = (String, AttributeScopes.FoundationAttributes.DurationFieldAttribute.Field?)
    let enUS = Locale(identifier: "en_US")

    func assertWithPattern(seconds: Int, milliseconds: Int = 0, pattern: Duration._TimeFormatStyle.Pattern, expected: [Segment], locale: Locale = Locale(identifier: "en_US"), sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(Duration(seconds: Int64(seconds), milliseconds: Int64(milliseconds)).formatted(.time(pattern: pattern).locale(locale).attributed) == expected.attributedString, sourceLocation: sourceLocation)
    }

    @Test func testAttributedStyle_enUS() {
        assertWithPattern(seconds: 3695, pattern: .hourMinute, expected: [
            ("1", .hours),
            (":", nil),
            ("02", .minutes)])
        assertWithPattern(seconds: 3695, pattern: .hourMinute(padHourToLength: 1, roundSeconds: .down), expected: [
            ("1", .hours),
            (":", nil),
            ("01", .minutes)])
        assertWithPattern(seconds: 3695, pattern: .hourMinuteSecond, expected: [
            ("1", .hours),
            (":", nil),
            ("01", .minutes),
            (":", nil),
            ("35", .seconds)])
        assertWithPattern(seconds: 3695, milliseconds: 500, pattern: .hourMinuteSecond(padHourToLength: 1, roundFractionalSeconds: .up), expected: [
            ("1", .hours),
            (":", nil),
            ("01", .minutes),
            (":", nil),
            ("36", .seconds)])
        assertWithPattern(seconds: 3695, pattern: .minuteSecond, expected: [
            ("61", .minutes),
            (":", nil),
            ("35", .seconds)])
        assertWithPattern(seconds: 3695, pattern: .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 2), expected: [
            ("61", .minutes),
            (":", nil),
            ("35.00", .seconds)])
        assertWithPattern(seconds: 3695, milliseconds: 350, pattern: .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 2), expected: [
            ("61", .minutes),
            (":", nil),
            ("35.35", .seconds)])

        // Padding
        assertWithPattern(seconds: 3695, pattern: .hourMinute(padHourToLength: 2), expected: [
            ("01", .hours),
            (":", nil),
            ("02", .minutes)])
        assertWithPattern(seconds: 3695, pattern: .hourMinuteSecond(padHourToLength: 2), expected: [
            ("01", .hours),
            (":", nil),
            ("01", .minutes),
            (":", nil),
            ("35", .seconds)])
        assertWithPattern(seconds: 3695, pattern: .hourMinuteSecond(padHourToLength: 2, fractionalSecondsLength: 2), expected: [
            ("01", .hours),
            (":", nil),
            ("01", .minutes),
            (":", nil),
            ("35.00", .seconds)])
        assertWithPattern(seconds: 3695, milliseconds: 500, pattern: .hourMinuteSecond(padHourToLength: 2, fractionalSecondsLength: 2), expected: [
            ("01", .hours),
            (":", nil),
            ("01", .minutes),
            (":", nil),
            ("35.50", .seconds)])
    }
}

// MARK: DiscreteFormatStyle conformance test

struct TestDurationTimeDiscreteConformance {
    @Test func testBasics() throws {
        var style: Duration._TimeFormatStyle
        style = .init(pattern: .minuteSecond(padMinuteToLength: 0, roundFractionalSeconds: .down)).locale(Locale(identifier: "en_US"))

        #expect(style.discreteInput(after: .seconds(1)) == .seconds(2))
        #expect(style.discreteInput(before: .seconds(1)) == .seconds(1).nextDown)
        #expect(style.discreteInput(after: .milliseconds(500)) == .seconds(1))
        #expect(style.discreteInput(before: .milliseconds(500)) == .zero.nextDown)
        #expect(style.discreteInput(after: .milliseconds(0)) == .seconds(1))
        #expect(style.discreteInput(before: .milliseconds(0)) == .zero.nextDown)
        #expect(style.discreteInput(after: .milliseconds(-500)) == .zero)
        #expect(style.discreteInput(before: .milliseconds(-500)) == .seconds(-1).nextDown)
        #expect(style.discreteInput(after: .seconds(-1)) == .zero)
        #expect(style.discreteInput(before: .seconds(-1)) == .seconds(-1).nextDown)


        style = .init(pattern: .minuteSecond(padMinuteToLength: 0, roundFractionalSeconds: .up))

        #expect(style.discreteInput(after: .seconds(1)) == .seconds(1).nextUp)
        #expect(style.discreteInput(before: .seconds(1)) == .seconds(0))
        #expect(style.discreteInput(after: .milliseconds(500)) == .seconds(1).nextUp)
        #expect(style.discreteInput(before: .milliseconds(500)) == .zero)
        #expect(style.discreteInput(after: .milliseconds(0)) == .zero.nextUp)
        #expect(style.discreteInput(before: .milliseconds(0)) == .seconds(-1))
        #expect(style.discreteInput(after: .milliseconds(-500)) == .zero.nextUp)
        #expect(style.discreteInput(before: .milliseconds(-500)) == .seconds(-1))
        #expect(style.discreteInput(after: .seconds(-1)) == .seconds(-1).nextUp)
        #expect(style.discreteInput(before: .seconds(-1)) == .seconds(-2))


        style = .init(pattern: .minuteSecond(padMinuteToLength: 0, roundFractionalSeconds: .towardZero))

        #expect(style.discreteInput(after: .seconds(1)) == .seconds(2))
        #expect(style.discreteInput(before: .seconds(1)) == .seconds(1).nextDown)
        #expect(style.discreteInput(after: .milliseconds(500)) == .seconds(1))
        #expect(style.discreteInput(before: .milliseconds(500)) == .seconds(-1))
        #expect(style.discreteInput(after: .milliseconds(0)) == .seconds(1))
        #expect(style.discreteInput(before: .milliseconds(0)) == .seconds(-1))
        #expect(style.discreteInput(after: .milliseconds(-500)) == .seconds(1))
        #expect(style.discreteInput(before: .milliseconds(-500)) == .seconds(-1))
        #expect(style.discreteInput(after: .seconds(-1)) == .seconds(-1).nextUp)
        #expect(style.discreteInput(before: .seconds(-1)) == .seconds(-2))

        style = .init(pattern: .minuteSecond(padMinuteToLength: 0, roundFractionalSeconds: .awayFromZero))

        #expect(style.discreteInput(after: .seconds(1)) == .seconds(1).nextUp)
        #expect(style.discreteInput(before: .seconds(1)) == .seconds(0))
        #expect(style.discreteInput(after: .milliseconds(500)) == .seconds(1).nextUp)
        #expect(style.discreteInput(before: .milliseconds(500)) == .zero)
        #expect(style.discreteInput(after: .milliseconds(0)) == .zero.nextUp)
        #expect(style.discreteInput(before: .milliseconds(0)) == .zero.nextDown)
        #expect(style.discreteInput(after: .milliseconds(-500)) == .zero)
        #expect(style.discreteInput(before: .milliseconds(-500)) == .seconds(-1).nextDown)
        #expect(style.discreteInput(after: .seconds(-1)) == .zero)
        #expect(style.discreteInput(before: .seconds(-1)) == .seconds(-1).nextDown)


        style = .init(pattern: .minuteSecond(padMinuteToLength: 0, roundFractionalSeconds: .toNearestOrAwayFromZero))

        #expect(style.discreteInput(after: .seconds(1)) == .milliseconds(1500))
        #expect(style.discreteInput(before: .seconds(1)) == .milliseconds(500).nextDown)
        #expect(style.discreteInput(after: .milliseconds(500)) == .milliseconds(1500))
        #expect(style.discreteInput(before: .milliseconds(500)) == .milliseconds(500).nextDown)
        #expect(style.discreteInput(after: .milliseconds(0)) == .milliseconds(500))
        #expect(style.discreteInput(before: .milliseconds(0)) == .milliseconds(-500))
        #expect(style.discreteInput(after: .milliseconds(-500)) == .milliseconds(-500).nextUp)
        #expect(style.discreteInput(before: .milliseconds(-500)) == .milliseconds(-1500))
        #expect(style.discreteInput(after: .seconds(-1)) == .milliseconds(-500).nextUp)
        #expect(style.discreteInput(before: .seconds(-1)) == .milliseconds(-1500))

        style = .init(pattern: .minuteSecond(padMinuteToLength: 0, roundFractionalSeconds: .toNearestOrEven))

        #expect(style.discreteInput(after: .seconds(1)) == .milliseconds(1500))
        #expect(style.discreteInput(before: .seconds(1)) == .milliseconds(500))
        #expect(style.discreteInput(after: .milliseconds(500)) == .milliseconds(500).nextUp)
        #expect(style.discreteInput(before: .milliseconds(500)) == .milliseconds(-500).nextDown)
        #expect(style.discreteInput(after: .milliseconds(0)) == .milliseconds(500).nextUp)
        #expect(style.discreteInput(before: .milliseconds(0)) == .milliseconds(-500).nextDown)
        #expect(style.discreteInput(after: .milliseconds(-500)) == .milliseconds(500).nextUp)
        #expect(style.discreteInput(before: .milliseconds(-500)) == .milliseconds(-500).nextDown)
        #expect(style.discreteInput(after: .seconds(-1)) == .milliseconds(-500))
        #expect(style.discreteInput(before: .seconds(-1)) == .milliseconds(-1500))
    }

    @Test func testRegressions() throws {
        var style: Duration._TimeFormatStyle

        style = .init(pattern: .hourMinute(padHourToLength: 0, roundSeconds: .toNearestOrAwayFromZero))

        #expect(try #require(style.discreteInput(after: Duration(secondsComponent: -8, attosecondsComponent: -531546586433266880))) <= Duration(secondsComponent: 30, attosecondsComponent: 0))
    }

    @Test(arguments: [FloatingPointRoundingRule.up, .down, .towardZero, .awayFromZero, .toNearestOrAwayFromZero, .toNearestOrEven])
    func testRandomSamples(roundingRule: FloatingPointRoundingRule) throws {
        let styles: [Duration._TimeFormatStyle] = [
            .init(pattern: .minuteSecond(padMinuteToLength: 0, roundFractionalSeconds: roundingRule), locale: .init(identifier: "en_US")),
            .init(pattern: .minuteSecond(padMinuteToLength: 0, fractionalSecondsLength: 2, roundFractionalSeconds: roundingRule), locale: .init(identifier: "en_US")),
            .init(pattern: .hourMinute(padHourToLength: 0, roundSeconds: roundingRule), locale: .init(identifier: "en_US"))
        ]

        for style in styles {
            try verifyDiscreteFormatStyleConformance(style, samples: 100, "\(style)")
        }
    }
}
