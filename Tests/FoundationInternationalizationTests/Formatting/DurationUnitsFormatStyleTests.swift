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

let week = 604800
let day = 86400
let hour = 3600
let minute = 60

@Suite("Duration.UnitsFormatStyle")
private struct DurationUnitsFormatStyleTests {
    let enUS = Locale(identifier: "en_US")

    @Test func durationUnitsFormatStyleAPI() {
        let d1 = Duration.seconds(2 * 3600 + 43 * 60 + 24) // 2hr 43min 24s
        let d2 = Duration.seconds(43 * 60 + 24) // 43min 24s
        let d3 = Duration(seconds: 24, milliseconds: 490)
        let d4 = Duration.seconds(43 * 60 + 5) // 43min 5s
        let d0 = Duration.seconds(0)

        #expect(d1.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide).locale(enUS)) == "2 hours, 43 minutes, 24 seconds")
        #expect(d2.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide).locale(enUS)) == "43 minutes, 24 seconds")
        #expect(d3.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide).locale(enUS)) == "24 seconds")
        #expect(d0.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide).locale(enUS)) == "0 seconds")

        #expect(d1.formatted(.units(allowed:[.hours, .minutes, .seconds], width: .wide, zeroValueUnits: .show(length: 1)).locale(enUS)) == "2 hours, 43 minutes, 24 seconds")
        #expect(d2.formatted(.units(allowed:[.hours, .minutes, .seconds], width: .wide, zeroValueUnits: .show(length: 1)).locale(enUS)) == "0 hours, 43 minutes, 24 seconds")
        #expect(d3.formatted(.units(allowed:[.hours, .minutes, .seconds], width: .wide, zeroValueUnits: .show(length: 1)).locale(enUS)) == "0 hours, 0 minutes, 24 seconds")
        #expect(d0.formatted(.units(allowed:[.hours, .minutes, .seconds], width: .wide, zeroValueUnits: .show(length: 1)).locale(enUS)) == "0 hours, 0 minutes, 0 seconds")

        #expect(d1.formatted(.units(allowed:[.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 1).locale(enUS)) == "3 hr")
        #expect(d2.formatted(.units(allowed:[.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 1).locale(enUS)) == "43 min")
        #expect(d3.formatted(.units(allowed:[.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 1).locale(enUS)) == "24 sec")
        #expect(d0.formatted(.units(allowed:[.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 1).locale(enUS)) == "0 sec")

        #expect(d1.formatted(.units(allowed:[.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 1, fractionalPart: .show(length: 2)).locale(enUS)) == "2.72 hr")
        #expect(d2.formatted(.units(allowed:[.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 1, fractionalPart: .show(length: 2)).locale(enUS)) == "43.40 min")
        #expect(d3.formatted(.units(allowed:[.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 1, fractionalPart: .show(length: 2)).locale(enUS)) == "24.49 sec")
        #expect(d0.formatted(.units(allowed:[.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 1, fractionalPart: .show(length: 2)).locale(enUS)) == "0.00 sec")

        #expect(d2.formatted(.units(allowed:[.hours, .minutes, .seconds], width: .wide, zeroValueUnits: .show(length: 2)).locale(enUS)) == "00 hours, 43 minutes, 24 seconds")
        #expect(d4.formatted(.units(allowed:[.hours, .minutes, .seconds], width: .wide, zeroValueUnits: .show(length: 2)).locale(enUS)) == "00 hours, 43 minutes, 05 seconds")
        #expect(d0.formatted(.units(allowed:[.hours, .minutes, .seconds], width: .wide, zeroValueUnits: .show(length: 2)).locale(enUS)) == "00 hours, 00 minutes, 00 seconds")

        #expect(d1.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide, valueLength: 2).locale(enUS)) == "02 hours, 43 minutes, 24 seconds")
        #expect(d2.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide, valueLength: 2).locale(enUS)) == "43 minutes, 24 seconds")
        #expect(d3.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide, valueLength: 2).locale(enUS)) == "24 seconds")
        #expect(d4.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide, valueLength: 2).locale(enUS)) == "43 minutes, 05 seconds")
        #expect(d0.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide, valueLength: 2).locale(enUS)) == "00 seconds")

        #expect(d1.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide, valueLength: 2, fractionalPart: .show(length: 2)).locale(enUS)) == "02 hours, 43 minutes, 24.00 seconds")
        #expect(d2.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide, valueLength: 2, fractionalPart: .show(length: 2)).locale(enUS)) == "43 minutes, 24.00 seconds")
        #expect(d3.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide, valueLength: 2, fractionalPart: .show(length: 2)).locale(enUS)) == "24.49 seconds")
        #expect(d4.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide, valueLength: 2, fractionalPart: .show(length: 2)).locale(enUS)) == "43 minutes, 05.00 seconds")
        #expect(d0.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide, valueLength: 2, fractionalPart: .show(length: 2)).locale(enUS)) == "00.00 seconds")
        #expect(Duration(minutes: 43, seconds: 24, milliseconds: 490).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide, valueLength: 2, fractionalPart: .show(length: 2)).locale(enUS)) == "43 minutes, 24.49 seconds")
    }

    func verify(seconds: Int, milliseconds: Int, allowedUnits: Set<Duration._UnitsFormatStyle.Unit>, fractionalSecondsLength: Int = 0, rounding: FloatingPointRoundingRule = .toNearestOrEven, increment: Double? = nil, expected: String, sourceLocation: SourceLocation = #_sourceLocation) {
        let d = Duration(seconds: Int64(seconds), milliseconds: Int64(milliseconds))
        #expect(d.formatted(.units(allowed: allowedUnits, zeroValueUnits: .show(length: 1), fractionalPart: .show(length: fractionalSecondsLength, rounded: rounding, increment: increment)).locale(enUS)) == expected, sourceLocation: sourceLocation)
    }

    @Test func noFractionParts() {

        // [.minutes, .seconds]

        verify(seconds: 0, milliseconds: 499,  allowedUnits: [.minutes, .seconds], expected: "0 min, 0 sec")
        verify(seconds: 0, milliseconds: 500,  allowedUnits: [.minutes, .seconds], expected: "0 min, 0 sec")
        verify(seconds: 0, milliseconds: 501,  allowedUnits: [.minutes, .seconds], expected: "0 min, 1 sec")
        verify(seconds: 0, milliseconds: 999,  allowedUnits: [.minutes, .seconds], expected: "0 min, 1 sec")
        verify(seconds: 1, milliseconds: 005,  allowedUnits: [.minutes, .seconds], expected: "0 min, 1 sec")
        verify(seconds: 1, milliseconds: 499,  allowedUnits: [.minutes, .seconds], expected: "0 min, 1 sec")
        verify(seconds: 1, milliseconds: 501,  allowedUnits: [.minutes, .seconds], expected: "0 min, 2 sec")
        verify(seconds: 59, milliseconds: 499, allowedUnits: [.minutes, .seconds], expected: "0 min, 59 sec")
        verify(seconds: 59, milliseconds: 500, allowedUnits: [.minutes, .seconds], expected: "1 min, 0 sec")
        verify(seconds: 59, milliseconds: 501, allowedUnits: [.minutes, .seconds], expected: "1 min, 0 sec")
        verify(seconds: 60, milliseconds: 499, allowedUnits: [.minutes, .seconds], expected: "1 min, 0 sec")
        verify(seconds: 60, milliseconds: 500, allowedUnits: [.minutes, .seconds], expected: "1 min, 0 sec")
        verify(seconds: 60, milliseconds: 501, allowedUnits: [.minutes, .seconds], expected: "1 min, 1 sec")

        verify(seconds: 1019, milliseconds: 490, allowedUnits: [.minutes, .seconds], expected: "16 min, 59 sec")
        verify(seconds: 1019, milliseconds: 500, allowedUnits: [.minutes, .seconds], expected: "17 min, 0 sec")
        verify(seconds: 1019, milliseconds: 510, allowedUnits: [.minutes, .seconds], expected: "17 min, 0 sec")

        verify(seconds: 3629, milliseconds: 490, allowedUnits: [.minutes, .seconds], expected: "60 min, 29 sec")
        verify(seconds: 3629, milliseconds: 500, allowedUnits: [.minutes, .seconds], expected: "60 min, 30 sec")
        verify(seconds: 3629, milliseconds: 510, allowedUnits: [.minutes, .seconds], expected: "60 min, 30 sec")

        verify(seconds: 3659, milliseconds: 490, allowedUnits: [.minutes, .seconds], expected: "60 min, 59 sec")
        verify(seconds: 3659, milliseconds: 500, allowedUnits: [.minutes, .seconds], expected: "61 min, 0 sec")
        verify(seconds: 3659, milliseconds: 510, allowedUnits: [.minutes, .seconds], expected: "61 min, 0 sec")

        // [hours, minutes, seconds]

        verify(seconds: 0, milliseconds: 499,  allowedUnits: [.hours, .minutes, .seconds], expected: "0 hr, 0 min, 0 sec")
        verify(seconds: 0, milliseconds: 500,  allowedUnits: [.hours, .minutes, .seconds], expected: "0 hr, 0 min, 0 sec")
        verify(seconds: 0, milliseconds: 501,  allowedUnits: [.hours, .minutes, .seconds], expected: "0 hr, 0 min, 1 sec")
        verify(seconds: 0, milliseconds: 999,  allowedUnits: [.hours, .minutes, .seconds], expected: "0 hr, 0 min, 1 sec")
        verify(seconds: 1, milliseconds: 005,  allowedUnits: [.hours, .minutes, .seconds], expected: "0 hr, 0 min, 1 sec")
        verify(seconds: 1, milliseconds: 499,  allowedUnits: [.hours, .minutes, .seconds], expected: "0 hr, 0 min, 1 sec")
        verify(seconds: 1, milliseconds: 501,  allowedUnits: [.hours, .minutes, .seconds], expected: "0 hr, 0 min, 2 sec")
        verify(seconds: 59, milliseconds: 499, allowedUnits: [.hours, .minutes, .seconds], expected: "0 hr, 0 min, 59 sec")
        verify(seconds: 59, milliseconds: 500, allowedUnits: [.hours, .minutes, .seconds], expected: "0 hr, 1 min, 0 sec")
        verify(seconds: 59, milliseconds: 501, allowedUnits: [.hours, .minutes, .seconds], expected: "0 hr, 1 min, 0 sec")

        verify(seconds: 1019, milliseconds: 490, allowedUnits: [.hours, .minutes, .seconds], expected: "0 hr, 16 min, 59 sec")
        verify(seconds: 1019, milliseconds: 500, allowedUnits: [.hours, .minutes, .seconds], expected: "0 hr, 17 min, 0 sec")
        verify(seconds: 1019, milliseconds: 510, allowedUnits: [.hours, .minutes, .seconds], expected: "0 hr, 17 min, 0 sec")

        verify(seconds: 3629, milliseconds: 490, allowedUnits: [.hours, .minutes, .seconds], expected: "1 hr, 0 min, 29 sec")
        verify(seconds: 3629, milliseconds: 500, allowedUnits: [.hours, .minutes, .seconds], expected: "1 hr, 0 min, 30 sec")
        verify(seconds: 3629, milliseconds: 510, allowedUnits: [.hours, .minutes, .seconds], expected: "1 hr, 0 min, 30 sec")

        verify(seconds: 3659, milliseconds: 490, allowedUnits: [.hours, .minutes, .seconds], expected: "1 hr, 0 min, 59 sec")
        verify(seconds: 3659, milliseconds: 500, allowedUnits: [.hours, .minutes, .seconds], expected: "1 hr, 1 min, 0 sec")
        verify(seconds: 3659, milliseconds: 510, allowedUnits: [.hours, .minutes, .seconds], expected: "1 hr, 1 min, 0 sec")

        verify(seconds: 7199, milliseconds: 499, allowedUnits: [.hours, .minutes, .seconds], expected: "1 hr, 59 min, 59 sec")
        verify(seconds: 7199, milliseconds: 500, allowedUnits: [.hours, .minutes, .seconds], expected: "2 hr, 0 min, 0 sec")
        verify(seconds: 7199, milliseconds: 501, allowedUnits: [.hours, .minutes, .seconds], expected: "2 hr, 0 min, 0 sec")

        // [hours, minutes]

        // 59 minutes
        verify(seconds: 3569, milliseconds: 499, allowedUnits: [.hours, .minutes], expected: "0 hr, 59 min")
        verify(seconds: 3569, milliseconds: 500, allowedUnits: [.hours, .minutes], expected: "0 hr, 59 min") // 29.5 seconds is still less than half minutes, so it would be rounded down
        verify(seconds: 3570, milliseconds: 0,  allowedUnits: [.hours, .minutes], expected: "1 hr, 0 min")

        // 1 hour, 0 minutes, x seconds
        verify(seconds: 3629, milliseconds: 400, allowedUnits: [.hours, .minutes], expected: "1 hr, 0 min")
        verify(seconds: 3629, milliseconds: 900, allowedUnits: [.hours, .minutes], expected: "1 hr, 0 min")
        verify(seconds: 3630, milliseconds: 000, allowedUnits: [.hours, .minutes], expected: "1 hr, 0 min")
        verify(seconds: 3630, milliseconds: 100, allowedUnits: [.hours, .minutes], expected: "1 hr, 1 min")
        verify(seconds: 3630, milliseconds: 900, allowedUnits: [.hours, .minutes], expected: "1 hr, 1 min")
        verify(seconds: 3631, milliseconds: 000, allowedUnits: [.hours, .minutes], expected: "1 hr, 1 min")
        verify(seconds: 3659, milliseconds: 400, allowedUnits: [.hours, .minutes], expected: "1 hr, 1 min")
        verify(seconds: 3659, milliseconds: 500, allowedUnits: [.hours, .minutes], expected: "1 hr, 1 min")

        // 1 hour, 29 minutes, x seconds
        verify(seconds: 5369, milliseconds: 400, allowedUnits: [.hours, .minutes], expected: "1 hr, 29 min")
        verify(seconds: 5369, milliseconds: 900, allowedUnits: [.hours, .minutes], expected: "1 hr, 29 min")
        verify(seconds: 5370, milliseconds: 000, allowedUnits: [.hours, .minutes], expected: "1 hr, 30 min")
        verify(seconds: 5370, milliseconds: 100, allowedUnits: [.hours, .minutes], expected: "1 hr, 30 min")
        verify(seconds: 5399, milliseconds: 400, allowedUnits: [.hours, .minutes], expected: "1 hr, 30 min")
        verify(seconds: 5399, milliseconds: 500, allowedUnits: [.hours, .minutes], expected: "1 hr, 30 min")
    }

    @Test func showFractionParts() {
        // [.minutes, .seconds]

        verify(seconds: 0, milliseconds: 499,  allowedUnits: [.minutes, .seconds], fractionalSecondsLength: 2, expected: "0 min, 0.50 sec")
        verify(seconds: 0, milliseconds: 999,  allowedUnits: [.minutes, .seconds], fractionalSecondsLength: 2, expected: "0 min, 1.00 sec")

        verify(seconds: 1, milliseconds: 005,  allowedUnits: [.minutes, .seconds], fractionalSecondsLength: 2, expected: "0 min, 1.00 sec")
        verify(seconds: 1, milliseconds: 499,  allowedUnits: [.minutes, .seconds], fractionalSecondsLength: 2, expected: "0 min, 1.50 sec")
        verify(seconds: 1, milliseconds: 999,  allowedUnits: [.minutes, .seconds], fractionalSecondsLength: 2, expected: "0 min, 2.00 sec")
        verify(seconds: 59, milliseconds: 994, allowedUnits: [.minutes, .seconds], fractionalSecondsLength: 2, expected: "0 min, 59.99 sec")
        verify(seconds: 59, milliseconds: 995, allowedUnits: [.minutes, .seconds], fractionalSecondsLength: 2, expected: "1 min, 0.00 sec")
        verify(seconds: 59, milliseconds: 996, allowedUnits: [.minutes, .seconds], fractionalSecondsLength: 2, expected: "1 min, 0.00 sec")

        verify(seconds: 1019, milliseconds: 994, allowedUnits: [.minutes, .seconds], fractionalSecondsLength: 2, expected: "16 min, 59.99 sec")
        verify(seconds: 1019, milliseconds: 995, allowedUnits: [.minutes, .seconds], fractionalSecondsLength: 2, expected: "17 min, 0.00 sec")
        verify(seconds: 1019, milliseconds: 996, allowedUnits: [.minutes, .seconds], fractionalSecondsLength: 2, expected: "17 min, 0.00 sec")

        verify(seconds: 3629, milliseconds: 994, allowedUnits: [.minutes, .seconds], fractionalSecondsLength: 2, expected: "60 min, 29.99 sec")
        verify(seconds: 3629, milliseconds: 995, allowedUnits: [.minutes, .seconds], fractionalSecondsLength: 2, expected: "60 min, 30.00 sec")
        verify(seconds: 3629, milliseconds: 996, allowedUnits: [.minutes, .seconds], fractionalSecondsLength: 2, expected: "60 min, 30.00 sec")

        verify(seconds: 3659, milliseconds: 994, allowedUnits: [.minutes, .seconds], fractionalSecondsLength: 2, expected: "60 min, 59.99 sec")
        verify(seconds: 3659, milliseconds: 995, allowedUnits: [.minutes, .seconds], fractionalSecondsLength: 2, expected: "61 min, 0.00 sec")
        verify(seconds: 3659, milliseconds: 996, allowedUnits: [.minutes, .seconds], fractionalSecondsLength: 2, expected: "61 min, 0.00 sec")

        // hours, minutes, seconds

        verify(seconds: 0, milliseconds: 499, allowedUnits: [.hours, .minutes, .seconds], fractionalSecondsLength: 2, expected: "0 hr, 0 min, 0.50 sec")
        verify(seconds: 0, milliseconds: 994, allowedUnits: [.hours, .minutes, .seconds], fractionalSecondsLength: 2, expected: "0 hr, 0 min, 0.99 sec")
        verify(seconds: 0, milliseconds: 995, allowedUnits: [.hours, .minutes, .seconds], fractionalSecondsLength: 2, expected: "0 hr, 0 min, 1.00 sec")
        verify(seconds: 0, milliseconds: 996, allowedUnits: [.hours, .minutes, .seconds], fractionalSecondsLength: 2, expected: "0 hr, 0 min, 1.00 sec")

        verify(seconds: 3599, milliseconds: 499, allowedUnits: [.hours, .minutes, .seconds], fractionalSecondsLength: 2, expected: "0 hr, 59 min, 59.50 sec")
        verify(seconds: 3599, milliseconds: 994, allowedUnits: [.hours, .minutes, .seconds], fractionalSecondsLength: 2, expected: "0 hr, 59 min, 59.99 sec")
        verify(seconds: 3599, milliseconds: 995, allowedUnits: [.hours, .minutes, .seconds], fractionalSecondsLength: 2, expected: "1 hr, 0 min, 0.00 sec")
        verify(seconds: 3599, milliseconds: 996, allowedUnits: [.hours, .minutes, .seconds], fractionalSecondsLength: 2, expected: "1 hr, 0 min, 0.00 sec")

        verify(seconds: 3599, milliseconds: 499, allowedUnits: [.hours, .minutes, .seconds], fractionalSecondsLength: 2, rounding: .down, expected: "0 hr, 59 min, 59.49 sec")
        verify(seconds: 3599, milliseconds: 499, allowedUnits: [.hours, .minutes, .seconds], fractionalSecondsLength: 2, rounding: .up,   expected: "0 hr, 59 min, 59.50 sec")
        verify(seconds: 3599, milliseconds: 499, allowedUnits: [.hours, .minutes, .seconds], fractionalSecondsLength: 2, rounding: .down, increment: 1, expected: "0 hr, 59 min, 59.00 sec")
        verify(seconds: 3599, milliseconds: 499, allowedUnits: [.hours, .minutes, .seconds], fractionalSecondsLength: 2, rounding: .up,   increment: 1, expected: "1 hr, 0 min, 0.00 sec")

        verify(seconds: 3599, milliseconds: 994, allowedUnits: [.hours, .minutes, .seconds], fractionalSecondsLength: 2, rounding: .down,  expected: "0 hr, 59 min, 59.99 sec")
        verify(seconds: 3599, milliseconds: 994, allowedUnits: [.hours, .minutes, .seconds], fractionalSecondsLength: 2, rounding: .up,    expected: "1 hr, 0 min, 0.00 sec")
        verify(seconds: 3599, milliseconds: 994, allowedUnits: [.hours, .minutes, .seconds], fractionalSecondsLength: 2, rounding: .down,  increment: 1, expected: "0 hr, 59 min, 59.00 sec")
        verify(seconds: 3599, milliseconds: 994, allowedUnits: [.hours, .minutes, .seconds], fractionalSecondsLength: 2, rounding: .up,    increment: 1, expected: "1 hr, 0 min, 0.00 sec")

        verify(seconds: 7199, milliseconds: 499, allowedUnits: [.hours, .minutes, .seconds], fractionalSecondsLength: 2, expected: "1 hr, 59 min, 59.50 sec")
        verify(seconds: 7199, milliseconds: 994, allowedUnits: [.hours, .minutes, .seconds], fractionalSecondsLength: 2, expected: "1 hr, 59 min, 59.99 sec")
        verify(seconds: 7199, milliseconds: 996, allowedUnits: [.hours, .minutes, .seconds], fractionalSecondsLength: 2, expected: "2 hr, 0 min, 0.00 sec")
        verify(seconds: 7199, milliseconds: 995, allowedUnits: [.hours, .minutes, .seconds], fractionalSecondsLength: 2, expected: "2 hr, 0 min, 0.00 sec")

        // hours, minute

        // 59.99165 min
        verify(seconds: minute * 59 + 59, milliseconds: 499, allowedUnits: [.hours, .minutes], fractionalSecondsLength: 2, rounding: .down, expected: "0 hr, 59.99 min")
        verify(seconds: minute * 59 + 59, milliseconds: 499, allowedUnits: [.hours, .minutes], fractionalSecondsLength: 2, rounding: .up,   expected: "1 hr, 0.00 min")
        verify(seconds: minute * 59 + 59, milliseconds: 499, allowedUnits: [.hours, .minutes], fractionalSecondsLength: 2, rounding: .down, increment: 0.000001, expected: "0 hr, 59.99 min")
        verify(seconds: minute * 59 + 59, milliseconds: 499, allowedUnits: [.hours, .minutes], fractionalSecondsLength: 2, rounding: .up,   increment: 0.000001, expected: "1 hr, 0.00 min")
        verify(seconds: minute * 59 + 59, milliseconds: 499, allowedUnits: [.hours, .minutes], fractionalSecondsLength: 2, rounding: .down, increment: 0.01, expected: "0 hr, 59.99 min")
        verify(seconds: minute * 59 + 59, milliseconds: 499, allowedUnits: [.hours, .minutes], fractionalSecondsLength: 2, rounding: .up,   increment: 0.01, expected: "1 hr, 0.00 min")
        verify(seconds: minute * 59 + 59, milliseconds: 499, allowedUnits: [.hours, .minutes], fractionalSecondsLength: 2, rounding: .down, increment: 0.1, expected: "0 hr, 59.90 min")
        verify(seconds: minute * 59 + 59, milliseconds: 499, allowedUnits: [.hours, .minutes], fractionalSecondsLength: 2, rounding: .up,   increment: 0.1, expected: "1 hr, 0.00 min")
        verify(seconds: minute * 59 + 59, milliseconds: 499, allowedUnits: [.hours, .minutes], fractionalSecondsLength: 2, rounding: .down, increment: 0.5, expected: "0 hr, 59.50 min")
        verify(seconds: minute * 59 + 59, milliseconds: 499, allowedUnits: [.hours, .minutes], fractionalSecondsLength: 2, rounding: .up,   increment: 0.5, expected: "1 hr, 0.00 min")
        verify(seconds: minute * 59 + 59, milliseconds: 499, allowedUnits: [.hours, .minutes], fractionalSecondsLength: 2, rounding: .down, increment: 0.8, expected: "0 hr, 59.20 min")
        verify(seconds: minute * 59 + 59, milliseconds: 499, allowedUnits: [.hours, .minutes], fractionalSecondsLength: 2, rounding: .up,   increment: 0.8, expected: "1 hr, 0.00 min")
        verify(seconds: minute * 59 + 59, milliseconds: 499, allowedUnits: [.hours, .minutes], fractionalSecondsLength: 2, rounding: .down, increment: 1.0, expected: "0 hr, 59.00 min")
        verify(seconds: minute * 59 + 59, milliseconds: 499, allowedUnits: [.hours, .minutes], fractionalSecondsLength: 2, rounding: .up,   increment: 1.0, expected: "1 hr, 0.00 min")

        verify(seconds: minute * 59 + 59, milliseconds: 994, allowedUnits: [.hours, .minutes], fractionalSecondsLength: 2, rounding: .down, expected: "0 hr, 59.99 min")
        verify(seconds: minute * 59 + 59, milliseconds: 994, allowedUnits: [.hours, .minutes], fractionalSecondsLength: 2, rounding: .up,   expected: "1 hr, 0.00 min")

        verify(seconds: minute * 59 + 59, milliseconds: 995, allowedUnits: [.hours, .minutes], fractionalSecondsLength: 2, rounding: .down, expected: "0 hr, 59.99 min")
        verify(seconds: minute * 59 + 59, milliseconds: 995, allowedUnits: [.hours, .minutes], fractionalSecondsLength: 2, rounding: .up,   expected: "1 hr, 0.00 min")

        let w3_d5_h4_m59 = week * 3 + day * 5 + hour * 4 + minute * 59

        // weeks - 3.7439 weeks
        verify(seconds: w3_d5_h4_m59, milliseconds: 0, allowedUnits: [ .weeks ], fractionalSecondsLength: 2, rounding: .up,   expected: "3.75 wks")
        verify(seconds: w3_d5_h4_m59, milliseconds: 0, allowedUnits: [ .weeks ], fractionalSecondsLength: 2, rounding: .down, expected: "3.74 wks")
        verify(seconds: w3_d5_h4_m59, milliseconds: 0, allowedUnits: [ .weeks ], fractionalSecondsLength: 2, rounding: .up,   increment: 0.5, expected: "4.00 wks")
        verify(seconds: w3_d5_h4_m59, milliseconds: 0, allowedUnits: [ .weeks ], fractionalSecondsLength: 2, rounding: .down, increment: 0.5, expected: "3.50 wks")

        // weeks, days - 3 wks, 5.207 days
        verify(seconds: w3_d5_h4_m59, milliseconds: 0, allowedUnits: [ .weeks, .days ], fractionalSecondsLength: 2, rounding: .up,   expected: "3 wks, 5.21 days")
        verify(seconds: w3_d5_h4_m59, milliseconds: 0, allowedUnits: [ .weeks, .days ], fractionalSecondsLength: 2, rounding: .down, expected: "3 wks, 5.20 days")
        verify(seconds: w3_d5_h4_m59, milliseconds: 0, allowedUnits: [ .weeks, .days ], fractionalSecondsLength: 2, rounding: .up,   increment: 0.5, expected: "3 wks, 5.50 days")
        verify(seconds: w3_d5_h4_m59, milliseconds: 0, allowedUnits: [ .weeks, .days ], fractionalSecondsLength: 2, rounding: .down, increment: 0.5, expected: "3 wks, 5.00 days")
        verify(seconds: w3_d5_h4_m59, milliseconds: 0, allowedUnits: [ .weeks, .days ], fractionalSecondsLength: 2, rounding: .up,   increment: 1, expected: "3 wks, 6.00 days")
        verify(seconds: w3_d5_h4_m59, milliseconds: 0, allowedUnits: [ .weeks, .days ], fractionalSecondsLength: 2, rounding: .down, increment: 1, expected: "3 wks, 5.00 days")

        // weeks, days, hours - 3 wks, 5 days, 4.983 hrs
        verify(seconds: w3_d5_h4_m59, milliseconds: 0, allowedUnits: [ .weeks, .days, .hours ], fractionalSecondsLength: 2, rounding: .up,   expected: "3 wks, 5 days, 4.99 hr")
        verify(seconds: w3_d5_h4_m59, milliseconds: 0, allowedUnits: [ .weeks, .days, .hours ], fractionalSecondsLength: 2, rounding: .down, expected: "3 wks, 5 days, 4.98 hr")
        verify(seconds: w3_d5_h4_m59, milliseconds: 0, allowedUnits: [ .weeks, .days, .hours ], fractionalSecondsLength: 2, rounding: .up,   increment: 0.5, expected: "3 wks, 5 days, 5.00 hr")
        verify(seconds: w3_d5_h4_m59, milliseconds: 0, allowedUnits: [ .weeks, .days, .hours ], fractionalSecondsLength: 2, rounding: .down, increment: 0.5, expected: "3 wks, 5 days, 4.50 hr")

        let w3_d6_h23_m59_s30 = week * 3 + day * 6 + hour * 23 + minute * 59 + 30

        // weeks - 3.99995 weeks
        verify(seconds: w3_d6_h23_m59_s30, milliseconds: 0, allowedUnits: [ .weeks ], fractionalSecondsLength: 2, rounding: .up,   expected: "4.00 wks")
        verify(seconds: w3_d6_h23_m59_s30, milliseconds: 0, allowedUnits: [ .weeks ], fractionalSecondsLength: 2, rounding: .down, expected: "3.99 wks")
        verify(seconds: w3_d6_h23_m59_s30, milliseconds: 0, allowedUnits: [ .weeks ], fractionalSecondsLength: 2, rounding: .up,   increment: 0.5, expected: "4.00 wks")
        verify(seconds: w3_d6_h23_m59_s30, milliseconds: 0, allowedUnits: [ .weeks ], fractionalSecondsLength: 2, rounding: .down, increment: 0.5, expected: "3.50 wks")

        // weeks, days - 3 wks, 6.999652 days
        verify(seconds: w3_d6_h23_m59_s30, milliseconds: 0, allowedUnits: [ .weeks, .days ], fractionalSecondsLength: 2, rounding: .up,   expected: "4 wks, 0.00 days")
        verify(seconds: w3_d6_h23_m59_s30, milliseconds: 0, allowedUnits: [ .weeks, .days ], fractionalSecondsLength: 2, rounding: .down, expected: "3 wks, 6.99 days")
        verify(seconds: w3_d6_h23_m59_s30, milliseconds: 0, allowedUnits: [ .weeks, .days ], fractionalSecondsLength: 2, rounding: .up,   increment: 0.5, expected: "4 wks, 0.00 days")
        verify(seconds: w3_d6_h23_m59_s30, milliseconds: 0, allowedUnits: [ .weeks, .days ], fractionalSecondsLength: 2, rounding: .down, increment: 0.5, expected: "3 wks, 6.50 days")
        verify(seconds: w3_d6_h23_m59_s30, milliseconds: 0, allowedUnits: [ .weeks, .days ], fractionalSecondsLength: 2, rounding: .up,   increment: 1, expected: "4 wks, 0.00 days")
        verify(seconds: w3_d6_h23_m59_s30, milliseconds: 0, allowedUnits: [ .weeks, .days ], fractionalSecondsLength: 2, rounding: .down, increment: 1, expected: "3 wks, 6.00 days")

        // weeks, days, hours - 3 wks, 6 days, 23.9916666 hours
        verify(seconds: w3_d6_h23_m59_s30, milliseconds: 0, allowedUnits: [ .weeks, .days, .hours ], fractionalSecondsLength: 2, rounding: .up,   expected: "4 wks, 0 days, 0.00 hr")
        verify(seconds: w3_d6_h23_m59_s30, milliseconds: 0, allowedUnits: [ .weeks, .days, .hours ], fractionalSecondsLength: 2, rounding: .down, expected: "3 wks, 6 days, 23.99 hr")
        verify(seconds: w3_d6_h23_m59_s30, milliseconds: 0, allowedUnits: [ .weeks, .days, .hours ], fractionalSecondsLength: 2, rounding: .up,   increment: 0.5, expected: "4 wks, 0 days, 0.00 hr")
        verify(seconds: w3_d6_h23_m59_s30, milliseconds: 0, allowedUnits: [ .weeks, .days, .hours ], fractionalSecondsLength: 2, rounding: .down, increment: 0.5, expected: "3 wks, 6 days, 23.50 hr")
    }

    @Test func durationUnitsFormatStyleAPI_largerThanDay() {

        var duration: Duration!
        let allowedUnits: Set<Duration._UnitsFormatStyle.Unit> = [.weeks, .days, .hours]
        func assertZeroValueUnit(_ zeroFormat: Duration._UnitsFormatStyle.ZeroValueUnitsDisplayStrategy, _ expected: String,
                                  sourceLocation: SourceLocation = #_sourceLocation) {
            #expect(duration.formatted(.units(allowed: allowedUnits, width: .wide, zeroValueUnits: zeroFormat).locale(enUS)) == expected, sourceLocation: sourceLocation)
        }

        func assertMaxUnitCount(_ maxUnitCount: Int, fractionalPart: Duration._UnitsFormatStyle.FractionalPartDisplayStrategy, _ expected: String,
                                  sourceLocation: SourceLocation = #_sourceLocation) {
            #expect(duration.formatted(.units(allowed: allowedUnits, width: .wide, maximumUnitCount: maxUnitCount, fractionalPart: fractionalPart).locale(enUS)) == expected, sourceLocation: sourceLocation)
        }


        duration = Duration.seconds(26 * 86400 + 4 * 3600) // 3wk, 5day, 4hr
        assertZeroValueUnit(.hide, "3 weeks, 5 days, 4 hours")
        assertZeroValueUnit(.show(length: 2), "03 weeks, 05 days, 04 hours")

        assertMaxUnitCount(1, fractionalPart: .hide, "4 weeks")
        assertMaxUnitCount(1, fractionalPart: .show(length: 2), "3.74 weeks")
        assertMaxUnitCount(1, fractionalPart: .show(length: 2, rounded: .towardZero), "3.73 weeks")
        assertMaxUnitCount(1, fractionalPart: .show(length: 2, increment: 0.5), "3.50 weeks")

        assertMaxUnitCount(2, fractionalPart: .hide, "3 weeks, 5 days")
        assertMaxUnitCount(2, fractionalPart: .show(length: 2, rounded: .towardZero), "3 weeks, 5.16 days")


        duration = Duration.seconds(21 * 86400 + 13 * 3600) // 3wk, 0day, 13hr
        assertZeroValueUnit(.hide, "3 weeks, 13 hours")
        assertZeroValueUnit(.show(length: 2), "03 weeks, 00 days, 13 hours")

        assertMaxUnitCount(1, fractionalPart: .hide, "3 weeks")
        assertMaxUnitCount(1, fractionalPart: .show(length: 2), "3.08 weeks")
        assertMaxUnitCount(2, fractionalPart: .hide, "3 weeks, 13 hours")


        duration = Duration.seconds(13 * 3600 + 20 * 60) // 13hr 20 min
        assertZeroValueUnit(.hide, "13 hours")
        assertZeroValueUnit(.show(length: 2), "00 weeks, 00 days, 13 hours")

        assertMaxUnitCount(1, fractionalPart: .hide, "13 hours")
        assertMaxUnitCount(1, fractionalPart: .show(length: 2), "13.33 hours")
    }

    @Test func zeroValueUnits() {
        var duration: Duration
        var allowedUnits: Set<Duration._UnitsFormatStyle.Unit>
        func test(_ zeroFormat: Duration._UnitsFormatStyle.ZeroValueUnitsDisplayStrategy, _ expected: String, sourceLocation: SourceLocation = #_sourceLocation) {
            #expect(duration.formatted(.units(allowed: allowedUnits, width: .wide, zeroValueUnits: zeroFormat).locale(enUS)) == expected, sourceLocation: sourceLocation)
        }

        do {
            duration = Duration.milliseconds(999)
            allowedUnits =  [.seconds, .milliseconds]

            test(.hide, "999 milliseconds")
            test(.show(length: 0), "999 milliseconds")
            test(.show(length: 1), "0 seconds, 999 milliseconds")
            test(.show(length: 2), "00 seconds, 999 milliseconds")
            test(.show(length: 3), "000 seconds, 999 milliseconds")
            test(.show(length: 4), "0,000 seconds, 0,999 milliseconds")
            test(.show(length: -1), "999 milliseconds") // negative value is treated as `hide`


            allowedUnits =  [.seconds, .milliseconds, .microseconds]

            test(.hide, "999 milliseconds")
            test(.show(length: 0), "999 milliseconds")
            test(.show(length: 1), "0 seconds, 999 milliseconds, 0 microseconds")
            test(.show(length: 2), "00 seconds, 999 milliseconds, 00 microseconds")
            test(.show(length: 3), "000 seconds, 999 milliseconds, 000 microseconds")
            test(.show(length: 4), "0,000 seconds, 0,999 milliseconds, 0,000 microseconds")

            allowedUnits =  [.minutes, .seconds]

            test(.hide, "1 second")
            test(.show(length: 0), "1 second")
            test(.show(length: 1), "0 minutes, 1 second")
            test(.show(length: 2), "00 minutes, 01 second")
            test(.show(length: 3), "000 minutes, 001 second")
            test(.show(length: 4), "0,000 minutes, 0,001 second")
        }

        do {
            duration = Duration.nanoseconds(999)
            allowedUnits =  [.seconds, .milliseconds ]

            test(.hide, "0 milliseconds")
            test(.show(length: 0), "0 milliseconds")
            test(.show(length: 1), "0 seconds, 0 milliseconds")
            test(.show(length: 2), "00 seconds, 00 milliseconds")
            test(.show(length: 3), "000 seconds, 000 milliseconds")
            test(.show(length: 4), "0,000 seconds, 0,000 milliseconds")

            allowedUnits =  [.seconds, .milliseconds, .microseconds ]

            test(.hide, "1 microsecond")
            test(.show(length: 0), "1 microsecond")
            test(.show(length: 1), "0 seconds, 0 milliseconds, 1 microsecond")
            test(.show(length: 2), "00 seconds, 00 milliseconds, 01 microsecond")
            test(.show(length: 3), "000 seconds, 000 milliseconds, 001 microsecond")
            test(.show(length: 4), "0,000 seconds, 0,000 milliseconds, 0,001 microsecond")

            allowedUnits =  [.seconds, .milliseconds, .microseconds, .nanoseconds ]

            test(.hide, "999 nanoseconds")
            test(.show(length: 0), "999 nanoseconds")
            test(.show(length: 1), "0 seconds, 0 milliseconds, 0 microseconds, 999 nanoseconds")
            test(.show(length: 2), "00 seconds, 00 milliseconds, 00 microseconds, 999 nanoseconds")
            test(.show(length: 3), "000 seconds, 000 milliseconds, 000 microseconds, 999 nanoseconds")
            test(.show(length: 4), "0,000 seconds, 0,000 milliseconds, 0,000 microseconds, 0,999 nanoseconds")
        }

        do {
            duration = Duration.microseconds(99) + Duration.nanoseconds(999)
            allowedUnits =  [.seconds, .milliseconds ]

            test(.hide, "0 milliseconds")
            test(.show(length: 0), "0 milliseconds")
            test(.show(length: 1), "0 seconds, 0 milliseconds")
            test(.show(length: 2), "00 seconds, 00 milliseconds")
            test(.show(length: 3), "000 seconds, 000 milliseconds")
            test(.show(length: 4), "0,000 seconds, 0,000 milliseconds")

            allowedUnits =  [.seconds, .milliseconds, .microseconds ]

            test(.hide, "100 microseconds")
            test(.show(length: 0), "100 microseconds")
            test(.show(length: 1), "0 seconds, 0 milliseconds, 100 microseconds")
            test(.show(length: 2), "00 seconds, 00 milliseconds, 100 microseconds")
            test(.show(length: 3), "000 seconds, 000 milliseconds, 100 microseconds")
            test(.show(length: 4), "0,000 seconds, 0,000 milliseconds, 0,100 microseconds")

            allowedUnits =  [.seconds, .milliseconds, .microseconds, .nanoseconds ]

            test(.hide, "99 microseconds, 999 nanoseconds")
            test(.show(length: 0), "99 microseconds, 999 nanoseconds")
            test(.show(length: 1), "0 seconds, 0 milliseconds, 99 microseconds, 999 nanoseconds")
            test(.show(length: 2), "00 seconds, 00 milliseconds, 99 microseconds, 999 nanoseconds")
            test(.show(length: 3), "000 seconds, 000 milliseconds, 099 microseconds, 999 nanoseconds")
            test(.show(length: 4), "0,000 seconds, 0,000 milliseconds, 0,099 microseconds, 0,999 nanoseconds")
        }
    }

    func assertEqual(_ duration: Duration,
                     allowedUnits: Set<Duration._UnitsFormatStyle.Unit>, maximumUnitCount: Int? = nil, roundSmallerParts: FloatingPointRoundingRule = .toNearestOrEven, trailingFractionalPartLength: Int = Int.max, roundingIncrement: Double? = nil, dropZeroUnits: Bool = false,
                     expected: (units: [Duration._UnitsFormatStyle.Unit], values: [Double]),
                     sourceLocation: SourceLocation = #_sourceLocation) {

        let (units, values) = Duration._UnitsFormatStyle.unitsToUse(duration: duration, allowedUnits: allowedUnits, maximumUnitCount: maximumUnitCount, roundSmallerParts: roundSmallerParts, trailingFractionalPartLength: trailingFractionalPartLength, roundingIncrement: roundingIncrement, dropZeroUnits: dropZeroUnits)
        guard values.count == expected.values.count else {
            Issue.record("\(values) is not equal to \(expected.values)", sourceLocation: sourceLocation)
            return
        }

        #expect(units == expected.units, sourceLocation: sourceLocation)
        for (idx, value) in values.enumerated() {
            #expect(abs(value - expected.values[idx]) <= 0.001, sourceLocation: sourceLocation)
        }
    }

    @Test func maximumUnitCounts() {
        let duration = Duration.seconds(2 * 3600 + 43 * 60 + 24) // 2hr 43min 24s
        assertEqual(duration, allowedUnits: [.hours, .minutes, .seconds] , maximumUnitCount: nil, expected: ([.hours, .minutes, .seconds], [2, 43, 24]))
        assertEqual(duration, allowedUnits: [.hours, .minutes], maximumUnitCount: nil, expected: ([.hours, .minutes], [2, 43.4]))
        assertEqual(duration, allowedUnits: [.hours], maximumUnitCount: nil, expected: ([.hours], [2.723]))

        assertEqual(duration, allowedUnits: [.hours, .minutes, .seconds], maximumUnitCount: 1, expected: ([.hours], [2.723]))
        assertEqual(duration, allowedUnits: [.hours, .minutes, .seconds], maximumUnitCount: 2, expected: ([.hours, .minutes], [2, 43.4]))
    }

    @Test func rounding() {
        let duration = Duration.seconds(2 * 3600 + 43 * 60 + 24) // 2hr 43min 24s
        assertEqual(duration, allowedUnits: [.hours, .minutes, .seconds] , roundSmallerParts: .down, expected: ([.hours, .minutes, .seconds], [2, 43, 24]))

        assertEqual(duration, allowedUnits: [.hours, .minutes] , roundSmallerParts: .up, trailingFractionalPartLength: 1, expected: ([.hours, .minutes], [2, 43.4]))
        assertEqual(duration, allowedUnits: [.hours, .minutes] , roundSmallerParts: .down, trailingFractionalPartLength: 0, expected: ([.hours, .minutes], [2, 43]))
        assertEqual(duration, allowedUnits: [.hours, .minutes] , roundSmallerParts: .up, trailingFractionalPartLength: 0, expected: ([.hours, .minutes], [2, 44]))

        assertEqual(duration, allowedUnits: [.hours] , roundSmallerParts: .up,   trailingFractionalPartLength: 3, expected: ([.hours], [2.724]))
        assertEqual(duration, allowedUnits: [.hours] , roundSmallerParts: .down, trailingFractionalPartLength: 3, expected: ([.hours], [2.723]))

        assertEqual(duration, allowedUnits: [.hours] , roundSmallerParts: .up,   trailingFractionalPartLength: 0, expected: ([.hours], [3]))
        assertEqual(duration, allowedUnits: [.hours] , roundSmallerParts: .down, trailingFractionalPartLength: 0, expected: ([.hours], [2]))
    }

    @Test func zeroUnitsDisplay() {
        let duration = Duration.seconds(2 * 3600 + 24) // 2hr 0min 24s
        assertEqual(duration, allowedUnits: [.hours, .minutes, .seconds] , dropZeroUnits: false, expected: ([.hours, .minutes, .seconds], [2, 0, 24]))
        assertEqual(duration, allowedUnits: [.hours, .minutes, .seconds] , dropZeroUnits: true, expected: ([.hours, .seconds], [2, 24]))

        assertEqual(duration, allowedUnits: [.hours, .minutes] , dropZeroUnits: false, expected: ([.hours, .minutes], [2, 0.4]))
        assertEqual(duration, allowedUnits: [.hours, .minutes] , dropZeroUnits: true, expected: ([.hours, .minutes], [2, 0.4]))

        let duration0 = Duration.seconds(0)
        assertEqual(duration0, allowedUnits: [.hours, .minutes, .seconds] , dropZeroUnits: false, expected: ([.hours, .minutes, .seconds], [0, 0, 0]))
        assertEqual(duration0, allowedUnits: [.hours, .minutes, .seconds] , dropZeroUnits: true, expected: ([], []))

        assertEqual(duration0, allowedUnits: [.hours, .minutes] , dropZeroUnits: false, expected: ([.hours, .minutes], [0, 0]))
        assertEqual(duration0, allowedUnits: [.hours, .minutes] , dropZeroUnits: true, expected: ([], []))
    }

    @Test func lengthRangeExpression() {

        var duration: Duration
        var allowedUnits: Set<Duration._UnitsFormatStyle.Unit>

        func verify<R: RangeExpression, R2: RangeExpression>(intLimits: R, fracLimits: R2, _ expected: String, sourceLocation: SourceLocation = #_sourceLocation) where R.Bound == Int, R2.Bound == Int {
            let style = Duration._UnitsFormatStyle(allowedUnits: allowedUnits, width: .abbreviated, valueLengthLimits: intLimits, fractionalPart: .init(lengthLimits: fracLimits)).locale(enUS)
            let formatted = style.format(duration)
            #expect(formatted == expected, sourceLocation: sourceLocation)
        }
        let oneThousandWithMaxPadding = "000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,001,000"

        let padding996 = "000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000"

        // There are 998 "0"s, the maximum allowed length
        let maxFractionalTrailing = String(repeating: "0", count: 998)
        let trailing979 = String(repeating: "0", count: 979)
        let trailing983 = String(repeating: "0", count: 983)

        // Fractional limits: Fixed length
        do {

            duration = Duration.seconds(1_000)

            allowedUnits = [.weeks]
            verify(intLimits: Int.min...,   fracLimits: Int.min...Int.min, "0 wks")
            verify(intLimits: 5...,         fracLimits: Int.min...Int.min, "00,000 wks")
            // Total integer length is 999, the maximum allowed by us and ICU
            verify(intLimits: Int.max...,   fracLimits: Int.min...Int.min, "\(padding996),000 wks")

            verify(intLimits: Int.min...,   fracLimits: 5...5, ".00165 wks")
            verify(intLimits: 5...,         fracLimits: 5...5, "00,000.00165 wks")
            verify(intLimits: Int.max...,   fracLimits: 5...5, "\(padding996),000.00165 wks")

            // Total fractional digit length is 998, the maximum allowed by us and ICU
            verify(intLimits: Int.min...,   fracLimits: Int.max...Int.max, ".0016534391534391533\(trailing979) wks")
            verify(intLimits: 5...,         fracLimits: Int.max...Int.max, "00,000.0016534391534391533\(trailing979) wks")
            verify(intLimits: Int.max...,   fracLimits: Int.max...Int.max, "\(padding996),000.0016534391534391533\(trailing979) wks")

            allowedUnits = [.minutes]
            verify(intLimits: Int.min...,   fracLimits: Int.min...Int.min, "17 min")
            verify(intLimits: 5...,         fracLimits: Int.min...Int.min, "00,017 min")
            verify(intLimits: Int.max...,   fracLimits: Int.min...Int.min, "\(padding996),017 min")

            verify(intLimits: Int.min...,   fracLimits: 5...5, "16.66667 min")
            verify(intLimits: 5...,         fracLimits: 5...5, "00,016.66667 min")
            verify(intLimits: Int.max...,   fracLimits: 5...5, "\(padding996),016.66667 min")

            verify(intLimits: Int.min...,   fracLimits: Int.max...Int.max, "16.666666666666668\(trailing983) min")
            verify(intLimits: 5...,         fracLimits: Int.max...Int.max, "00,016.666666666666668\(trailing983) min")
            verify(intLimits: Int.max...,   fracLimits: Int.max...Int.max, "\(padding996),016.666666666666668\(trailing983) min")

            allowedUnits = [.seconds]
            verify(intLimits: Int.min...,   fracLimits: Int.min...Int.min, "1,000 sec")
            verify(intLimits: 5...,         fracLimits: Int.min...Int.min, "01,000 sec")
            verify(intLimits: Int.max...,   fracLimits: Int.min...Int.min, "\(oneThousandWithMaxPadding) sec")

            verify(intLimits: Int.min...,   fracLimits: 5...5, "1,000.00000 sec")
            verify(intLimits: 5...,         fracLimits: 5...5, "01,000.00000 sec")
            verify(intLimits: Int.max...,   fracLimits: 5...5, "\(oneThousandWithMaxPadding).00000 sec")

            verify(intLimits: Int.min...,   fracLimits: Int.max...Int.max, "1,000.\(maxFractionalTrailing) sec")
            verify(intLimits: 5...,         fracLimits: Int.max...Int.max, "01,000.\(maxFractionalTrailing) sec")
            verify(intLimits: Int.max...,   fracLimits: Int.max...Int.max, "\(oneThousandWithMaxPadding).\(maxFractionalTrailing) sec")
        }

        // Fractional limits: PartialRangeFrom
        do {
            duration = Duration.seconds(1_000)
            allowedUnits = [.weeks]

            verify(intLimits: Int.min...,   fracLimits: Int.min...,   ".0016534391534391533 wks")
            verify(intLimits: 5...,         fracLimits: Int.min...,   "00,000.0016534391534391533 wks")
            verify(intLimits: Int.max...,   fracLimits: Int.min...,   "\(padding996),000.0016534391534391533 wks")

            verify(intLimits: Int.min...,   fracLimits: 2...,   ".0016534391534391533 wks")
            verify(intLimits: 5...,         fracLimits: 2...,   "00,000.0016534391534391533 wks")
            verify(intLimits: Int.max...,   fracLimits: 2...,   "\(padding996),000.0016534391534391533 wks")

            verify(intLimits: Int.min...,   fracLimits: Int.max...,   ".0016534391534391533\(trailing979) wks")
            verify(intLimits: 5...,         fracLimits: Int.max...,   "00,000.0016534391534391533\(trailing979) wks")
            verify(intLimits: Int.max...,   fracLimits: Int.max...,   "\(padding996),000.0016534391534391533\(trailing979) wks")

            allowedUnits = [.minutes] // 1000 sec ~= 16.666666666666 mins

            verify(intLimits: Int.min...,   fracLimits: Int.min...,   "16.666666666666668 min")
            verify(intLimits: 5...,         fracLimits: Int.min...,   "00,016.666666666666668 min")
            verify(intLimits: Int.max...,   fracLimits: Int.min...,   "\(padding996),016.666666666666668 min")

            verify(intLimits: Int.min...,   fracLimits: 2...,   "16.666666666666668 min")
            verify(intLimits: 5...,         fracLimits: 2...,   "00,016.666666666666668 min")
            verify(intLimits: Int.max...,   fracLimits: 2...,   "\(padding996),016.666666666666668 min")

            verify(intLimits: Int.min...,   fracLimits: Int.max...,   "16.666666666666668\(trailing983) min")
            verify(intLimits: 5...,         fracLimits: Int.max...,   "00,016.666666666666668\(trailing983) min")
            verify(intLimits: Int.max...,   fracLimits: Int.max...,   "\(padding996),016.666666666666668\(trailing983) min")

            allowedUnits = [.seconds]

            verify(intLimits: Int.min...,   fracLimits: Int.min...,   "1,000 sec")
            verify(intLimits: 5...,         fracLimits: Int.min...,   "01,000 sec")
            verify(intLimits: Int.max...,   fracLimits: Int.min...,   "\(oneThousandWithMaxPadding) sec")

            verify(intLimits: Int.min...,   fracLimits: 2...,   "1,000.00 sec")
            verify(intLimits: 5...,         fracLimits: 2...,   "01,000.00 sec")
            verify(intLimits: Int.max...,   fracLimits: 2...,   "\(oneThousandWithMaxPadding).00 sec")

            verify(intLimits: Int.min...,   fracLimits: Int.max...,   "1,000.\(maxFractionalTrailing) sec")
            verify(intLimits: 5...,         fracLimits: Int.max...,   "01,000.\(maxFractionalTrailing) sec")
            verify(intLimits: Int.max...,   fracLimits: Int.max...,   "\(oneThousandWithMaxPadding).\(maxFractionalTrailing) sec")
        }

        // Fractional limits: PartialRangeThrough
        do {
            duration = Duration.seconds(1_000)

            allowedUnits = [.weeks]
            verify(intLimits: Int.min...,   fracLimits: ...Int.min,   "0 wks")
            verify(intLimits: 5...,         fracLimits: ...Int.min,   "00,000 wks")
            verify(intLimits: Int.max...,   fracLimits: ...Int.min,   "\(padding996),000 wks")

            verify(intLimits: Int.min...,   fracLimits: ...5,   ".00165 wks")
            verify(intLimits: 5...,         fracLimits: ...5,   "00,000.00165 wks")
            verify(intLimits: Int.max...,   fracLimits: ...5,   "\(padding996),000.00165 wks")

            verify(intLimits: Int.min...,   fracLimits: ...Int.max,   ".0016534391534391533 wks")
            verify(intLimits: 5...,         fracLimits: ...Int.max,   "00,000.0016534391534391533 wks")
            verify(intLimits: Int.max...,   fracLimits: ...Int.max,   "\(padding996),000.0016534391534391533 wks")

            allowedUnits = [.minutes]
            verify(intLimits: Int.min...,   fracLimits: ...Int.min,   "17 min")
            verify(intLimits: 5...,         fracLimits: ...Int.min,   "00,017 min")
            verify(intLimits: Int.max...,   fracLimits: ...Int.min,   "\(padding996),017 min")

            verify(intLimits: Int.min...,   fracLimits: ...5,   "16.66667 min")
            verify(intLimits: 5...,         fracLimits: ...5,   "00,016.66667 min")
            verify(intLimits: Int.max...,   fracLimits: ...5,   "\(padding996),016.66667 min")

            verify(intLimits: Int.min...,   fracLimits: ...Int.max, "16.666666666666668 min")
            verify(intLimits: 5...,         fracLimits: ...Int.max, "00,016.666666666666668 min")
            verify(intLimits: Int.max...,   fracLimits: ...Int.max, "\(padding996),016.666666666666668 min")

            allowedUnits = [.seconds]

            verify(intLimits: Int.min...,   fracLimits: ...Int.min,   "1,000 sec")
            verify(intLimits: 5...,         fracLimits: ...Int.min,   "01,000 sec")
            verify(intLimits: Int.max...,   fracLimits: ...Int.min,   "\(oneThousandWithMaxPadding) sec")

            verify(intLimits: Int.min...,   fracLimits: ...5,   "1,000 sec")
            verify(intLimits: 5...,         fracLimits: ...5,   "01,000 sec")
            verify(intLimits: Int.max...,   fracLimits: ...5,   "\(oneThousandWithMaxPadding) sec")

            verify(intLimits: Int.min...,   fracLimits: ...Int.max,   "1,000 sec")
            verify(intLimits: 5...,         fracLimits: ...Int.max,   "01,000 sec")
            verify(intLimits: Int.max...,   fracLimits: ...Int.max,   "\(oneThousandWithMaxPadding) sec")
        }

        // Fractional limits: PartialRangeUpTo
        do {
            duration = Duration.seconds(1_000)

            allowedUnits = [ .weeks ]
            verify(intLimits: 5...,         fracLimits: ..<Int.min, "00,000 wks")
            verify(intLimits: 5...,         fracLimits: ..<0,       "00,000 wks")
            verify(intLimits: 5...,         fracLimits: ..<Int.max, "00,000.0016534391534391533 wks")

            allowedUnits = [ .minutes ]
            verify(intLimits: Int.min...,   fracLimits: ..<Int.min,   "17 min")
            verify(intLimits: 5...,         fracLimits: ..<Int.min,   "00,017 min")
            verify(intLimits: Int.max...,   fracLimits: ..<Int.min,   "\(padding996),017 min")

            verify(intLimits: Int.min...,   fracLimits: ..<(Int.min + 1),   "17 min")
            verify(intLimits: 5...,         fracLimits: ..<(Int.min + 1),   "00,017 min")
            verify(intLimits: Int.max...,   fracLimits: ..<(Int.min + 1),   "\(padding996),017 min")

            verify(intLimits: Int.min...,   fracLimits: ..<5,   "16.6667 min")
            verify(intLimits: 5...,         fracLimits: ..<5,   "00,016.6667 min")
            verify(intLimits: Int.max...,   fracLimits: ..<5,   "\(padding996),016.6667 min")

            verify(intLimits: Int.min...,   fracLimits: ..<Int.max,   "16.666666666666668 min")
            verify(intLimits: 5...,         fracLimits: ..<Int.max,   "00,016.666666666666668 min")
            verify(intLimits: Int.max...,   fracLimits: ..<Int.max,   "\(padding996),016.666666666666668 min")
        }

        // Fractional limits: PartialRangeThrough
        do {
            duration = Duration.seconds(1_000)

            allowedUnits = [ .weeks ]

            verify(intLimits: Int.min...,   fracLimits: ...Int.min,   "0 wks")
            verify(intLimits: 5...,         fracLimits: ...Int.min,   "00,000 wks")
            // The total length of a formatted unit, including zero paddings, would be 999.
            verify(intLimits: Int.max...,   fracLimits: ...Int.min,   "\(padding996),000 wks")

            verify(intLimits: Int.min...,   fracLimits: ...(Int.min + 1),   "0 wks")
            verify(intLimits: 5...,         fracLimits: ...(Int.min + 1),   "00,000 wks")
            verify(intLimits: Int.max...,   fracLimits: ...(Int.min + 1),   "\(padding996),000 wks")

            verify(intLimits: Int.min...,   fracLimits: ...Int.max,   ".0016534391534391533 wks")
            verify(intLimits: 5...,         fracLimits: ...Int.max,   "00,000.0016534391534391533 wks")
            verify(intLimits: Int.max...,   fracLimits: ...Int.max,   "\(padding996),000.0016534391534391533 wks")

            allowedUnits = [ .minutes ]

            verify(intLimits: Int.min...,   fracLimits: ...Int.min,   "17 min")
            verify(intLimits: 5...,         fracLimits: ...Int.min,   "00,017 min")
            // The total length of a formatted unit, including zero paddings, would be 999.
            verify(intLimits: Int.max...,   fracLimits: ...Int.min,   "\(padding996),017 min")

            verify(intLimits: Int.min...,   fracLimits: ...(Int.min + 1),   "17 min")
            verify(intLimits: 5...,         fracLimits: ...(Int.min + 1),   "00,017 min")
            verify(intLimits: Int.max...,   fracLimits: ...(Int.min + 1),   "\(padding996),017 min")

            verify(intLimits: Int.min...,   fracLimits: ...Int.max,   "16.666666666666668 min")
            verify(intLimits: 5...,         fracLimits: ...Int.max,   "00,016.666666666666668 min")
            verify(intLimits: Int.max...,   fracLimits: ...Int.max,   "\(padding996),016.666666666666668 min")
        }

        // Fractional limits: ClosedRange
        do {
            duration = Duration.seconds(1_000)
            allowedUnits = [ .weeks ]

            verify(intLimits: Int.min...,   fracLimits: Int.min...Int.max, ".0016534391534391533 wks")
            verify(intLimits: 5...,         fracLimits: Int.min...Int.max, "00,000.0016534391534391533 wks")
            verify(intLimits: Int.max...,   fracLimits: Int.min...Int.max, "\(padding996),000.0016534391534391533 wks")

            verify(intLimits: Int.min...,   fracLimits: Int.min...(-1),   "0 wks")
            verify(intLimits: 5...,         fracLimits: Int.min...(-1),   "00,000 wks")
            verify(intLimits: Int.max...,   fracLimits: Int.min...(-1),   "\(padding996),000 wks")

            verify(intLimits: Int.min...,   fracLimits: 5...Int.max,   ".0016534391534391533 wks")
            verify(intLimits: 5...,         fracLimits: 5...Int.max,   "00,000.0016534391534391533 wks")
            verify(intLimits: Int.max...,   fracLimits: 5...Int.max,   "\(padding996),000.0016534391534391533 wks")

            verify(intLimits: Int.min...,   fracLimits: 5...10, ".0016534392 wks")
            verify(intLimits: 5...,         fracLimits: 5...10, "00,000.0016534392 wks")
            verify(intLimits: Int.max...,   fracLimits: 5...10, "\(padding996),000.0016534392 wks")

            allowedUnits = [ .minutes ]

            verify(intLimits: Int.min...,   fracLimits: Int.min...Int.max, "16.666666666666668 min")
            verify(intLimits: 5...,         fracLimits: Int.min...Int.max, "00,016.666666666666668 min")
            verify(intLimits: Int.max...,   fracLimits: Int.min...Int.max, "\(padding996),016.666666666666668 min")

            verify(intLimits: Int.min...,   fracLimits: Int.min...(-1),   "17 min")
            verify(intLimits: 5...,         fracLimits: Int.min...(-1),   "00,017 min")
            verify(intLimits: Int.max...,   fracLimits: Int.min...(-1),   "\(padding996),017 min")

            verify(intLimits: Int.min...,   fracLimits: 5...Int.max,   "16.666666666666668 min")
            verify(intLimits: 5...,         fracLimits: 5...Int.max,   "00,016.666666666666668 min")
            verify(intLimits: Int.max...,   fracLimits: 5...Int.max,   "\(padding996),016.666666666666668 min")

            verify(intLimits: Int.min...,   fracLimits: 5...10, "16.6666666667 min")
            verify(intLimits: 5...,         fracLimits: 5...10, "00,016.6666666667 min")
            verify(intLimits: Int.max...,   fracLimits: 5...10, "\(padding996),016.6666666667 min")
        }

        // Fractional limits: PartialRangeFrom
        do {
            duration = Duration.seconds(1_000)
            allowedUnits = [.minutes, .seconds]

            verify(intLimits: Int.min...,   fracLimits: 2...,   "16 min, 40.00 sec")
            verify(intLimits: 0...,         fracLimits: 2...,   "16 min, 40.00 sec")
            verify(intLimits: 1...,         fracLimits: 2...,   "16 min, 40.00 sec")
            verify(intLimits: 5...,         fracLimits: 2...,   "00,016 min, 00,040.00 sec")
            // The total length of a formatted unit, including zero paddings, would be 999.
            verify(intLimits: Int.max...,      fracLimits: 2...,   "\(padding996),016 min, \(padding996),040.00 sec")
        }

        // Int limits: PartialRangeFrom
        do {
            duration = Duration.seconds(1_000)

            allowedUnits = [.weeks]
            verify(intLimits: Int.min...,   fracLimits: 10...10,   ".0016534392 wks")
            verify(intLimits: 5...,         fracLimits: 10...10,   "00,000.0016534392 wks")
            verify(intLimits: Int.max...,   fracLimits: 10...10,   "\(padding996),000.0016534392 wks")

            allowedUnits = [.minutes]
            verify(intLimits: Int.min...,   fracLimits: 2...2,   "16.67 min")
            verify(intLimits: 5...,         fracLimits: 2...2,   "00,016.67 min")
            verify(intLimits: Int.max...,   fracLimits: 2...2,   "\(padding996),016.67 min")

            allowedUnits = [.seconds]
            verify(intLimits: Int.min...,   fracLimits: 2...2,   "1,000.00 sec")
            verify(intLimits: 5...,         fracLimits: 2...2,   "01,000.00 sec")
            verify(intLimits: Int.max...,   fracLimits: 2...2,   "\(oneThousandWithMaxPadding).00 sec")

        }

        // Int limits: Range
        do {
            duration = Duration.seconds(1_000)

            allowedUnits = [.weeks]
            verify(intLimits: Int.min..<Int.max,    fracLimits: 10...10,   ".0016534392 wks")
            verify(intLimits: Int.min..<0,          fracLimits: 10...10,   ".0016534392 wks")
            verify(intLimits: Int.min..<3,          fracLimits: 10...10,   ".0016534392 wks")
            verify(intLimits: 5..<Int.max,          fracLimits: 10...10,   "00,000.0016534392 wks")

            allowedUnits = [.minutes]
            verify(intLimits: Int.min..<Int.max,    fracLimits: 2...2,   "16.67 min")
            verify(intLimits: Int.min..<0,          fracLimits: 2...2,   "16.67 min")
            verify(intLimits: Int.min..<3,          fracLimits: 2...2,   "16.67 min")
            verify(intLimits: 5..<Int.max,          fracLimits: 2...2,   "00,016.67 min")

            allowedUnits = [.seconds]
            verify(intLimits: Int.min..<Int.max,    fracLimits: 2...2,   "1,000.00 sec")
            verify(intLimits: Int.min..<0,          fracLimits: 2...2,   "1,000.00 sec")
            verify(intLimits: Int.min..<3,          fracLimits: 2...2,   ".00 sec") // This is not wrong, albeit confusing: we can't fit one thousand into three digits
            verify(intLimits: 5..<Int.max,          fracLimits: 2...2,   "01,000.00 sec")
        }

        // Int limits: ClosedRange
        do {
            duration = Duration.seconds(1_000)

            allowedUnits = [.weeks]
            verify(intLimits: Int.min...Int.max,    fracLimits: 10...10,   ".0016534392 wks")
            verify(intLimits: Int.min...(-1),       fracLimits: 10...10,   ".0016534392 wks")
            verify(intLimits: Int.min...3,          fracLimits: 10...10,   ".0016534392 wks")
            verify(intLimits: 5...Int.max,          fracLimits: 10...10,   "00,000.0016534392 wks")

            allowedUnits = [.minutes]
            verify(intLimits: Int.min...Int.max,    fracLimits: 2...2,   "16.67 min")
            verify(intLimits: Int.min...(-1),       fracLimits: 2...2,   "16.67 min")
            verify(intLimits: Int.min...3,          fracLimits: 2...2,   "16.67 min")
            verify(intLimits: 5...Int.max,          fracLimits: 2...2,   "00,016.67 min")

            allowedUnits = [.seconds]
            verify(intLimits: Int.min...Int.max,    fracLimits: 2...2,   "1,000.00 sec")
            verify(intLimits: Int.min...(-1),       fracLimits: 2...2,   "1,000.00 sec")
            verify(intLimits: Int.min...3,          fracLimits: 2...2,   ".00 sec")
            verify(intLimits: 5...Int.max,          fracLimits: 2...2,   "01,000.00 sec")
        }

        // Int limits: PartialRangeThrough
        do {
            duration = Duration.seconds(1_000)

            allowedUnits = [.weeks]
            verify(intLimits: ...Int.min,   fracLimits: 10...10,    ".0016534392 wks")
            verify(intLimits: ...3,         fracLimits: 10...10,    ".0016534392 wks")
            verify(intLimits: ...Int.max,   fracLimits: 10...10,    ".0016534392 wks")

            allowedUnits = [.minutes]
            verify(intLimits: ...Int.min,   fracLimits: 2...2,   "16.67 min")
            verify(intLimits: ...3,         fracLimits: 2...2,   "16.67 min")
            verify(intLimits: ...Int.max,   fracLimits: 2...2,   "16.67 min")

            allowedUnits = [.seconds]
            verify(intLimits: ...Int.min,   fracLimits: 2...2,   "1,000.00 sec")
            verify(intLimits: ...3,         fracLimits: 2...2,   ".00 sec")
            verify(intLimits: ...Int.max,   fracLimits: 2...2,   "1,000.00 sec")
        }

        // Int limits: PartialRangeUpTo
        do {
            duration = Duration.seconds(1_000)

            allowedUnits = [.weeks]
            verify(intLimits: ..<Int.min,   fracLimits: 10...10,   ".0016534392 wks")
            verify(intLimits: ..<0,         fracLimits: 10...10,   ".0016534392 wks")
            verify(intLimits: ..<3,         fracLimits: 10...10,   ".0016534392 wks")
            verify(intLimits: ..<Int.max,   fracLimits: 10...10,   ".0016534392 wks")

            allowedUnits = [.minutes]
            verify(intLimits: ..<Int.min,   fracLimits: 2...2,   "16.67 min")
            verify(intLimits: ..<0,         fracLimits: 2...2,   "16.67 min")
            verify(intLimits: ..<3,         fracLimits: 2...2,   "16.67 min")
            verify(intLimits: ..<Int.max,   fracLimits: 2...2,   "16.67 min")

            allowedUnits = [.seconds]
            verify(intLimits: ..<Int.min,   fracLimits: 2...2,   "1,000.00 sec")
            verify(intLimits: ..<0,         fracLimits: 2...2,   "1,000.00 sec")
            verify(intLimits: ..<3,         fracLimits: 2...2,   ".00 sec")
            verify(intLimits: ..<Int.max,   fracLimits: 2...2,   "1,000.00 sec")
        }
    }


    @Test func negativeValues() {
        verify(seconds: 0, milliseconds: -499, allowedUnits: [.hours, .minutes, .seconds], expected: "0 hr, 0 min, 0 sec")
        verify(seconds: 0, milliseconds: -500, allowedUnits: [.hours, .minutes, .seconds], expected: "0 hr, 0 min, 0 sec")
        verify(seconds: 0, milliseconds: -501, allowedUnits: [.hours, .minutes, .seconds], expected: "-0 hr, 0 min, 1 sec")

        verify(seconds: 0, milliseconds: -499, allowedUnits: [.minutes, .seconds], expected: "0 min, 0 sec")
        verify(seconds: 0, milliseconds: -500, allowedUnits: [.minutes, .seconds], expected: "0 min, 0 sec")
        verify(seconds: 0, milliseconds: -501, allowedUnits: [.minutes, .seconds], expected: "-0 min, 1 sec")

        verify(seconds: -59 * 60 - 59, milliseconds: -499, allowedUnits: [.hours, .minutes, .seconds], expected: "-0 hr, 59 min, 59 sec")
        verify(seconds: -59 * 60 - 59, milliseconds: -500, allowedUnits: [.hours, .minutes, .seconds], expected: "-1 hr, 0 min, 0 sec")
        verify(seconds: -59 * 60 - 59, milliseconds: -501, allowedUnits: [.hours, .minutes, .seconds], expected: "-1 hr, 0 min, 0 sec")

        verify(seconds: -3600 - 59 * 60 - 59, milliseconds: -499, allowedUnits: [.hours, .minutes, .seconds], expected: "-1 hr, 59 min, 59 sec")
        verify(seconds: -3600 - 59 * 60 - 59, milliseconds: -500, allowedUnits: [.hours, .minutes, .seconds], expected: "-2 hr, 0 min, 0 sec")
        verify(seconds: -3600 - 59 * 60 - 59, milliseconds: -501, allowedUnits: [.hours, .minutes, .seconds], expected: "-2 hr, 0 min, 0 sec")

        verify(seconds: -59 * 60 - 59, milliseconds: -499, allowedUnits: [.hours, .minutes, .seconds], fractionalSecondsLength: 2, expected: "-0 hr, 59 min, 59.50 sec")
        verify(seconds: -59 * 60 - 59, milliseconds: -994, allowedUnits: [.hours, .minutes, .seconds], fractionalSecondsLength: 2, expected: "-0 hr, 59 min, 59.99 sec")
        verify(seconds: -59 * 60 - 59, milliseconds: -995, allowedUnits: [.hours, .minutes, .seconds], fractionalSecondsLength: 2, expected: "-1 hr, 0 min, 0.00 sec")
        verify(seconds: -59 * 60 - 59, milliseconds: -996, allowedUnits: [.hours, .minutes, .seconds], fractionalSecondsLength: 2, expected: "-1 hr, 0 min, 0.00 sec")

        verify(seconds: -59, milliseconds: -499, allowedUnits: [.seconds], fractionalSecondsLength: 2, expected: "-59.50 sec")
        verify(seconds: -59, milliseconds: -994, allowedUnits: [.seconds], fractionalSecondsLength: 2, expected: "-59.99 sec")
        verify(seconds: -59, milliseconds: -995, allowedUnits: [.seconds], fractionalSecondsLength: 2, expected: "-60.00 sec")
        verify(seconds: -59, milliseconds: -996, allowedUnits: [.seconds], fractionalSecondsLength: 2, expected: "-60.00 sec")
    }
}

// MARK: - Attributed string test

@available(FoundationAttributedString 5.5, *)
extension Sequence where Element == DurationUnitAttributedFormatStyleTests.Segment {
    var attributedString: AttributedString {
        self.map { tuple in
            var attrs = AttributeContainer()
            if let field = tuple.1 {
                attrs = attrs.durationField(field)
            }
            if let measureComponent = tuple.2 {
                attrs = attrs.measurement(measureComponent)
            }

            return AttributedString(tuple.0, attributes: attrs)
        }.reduce(AttributedString(), +)
    }
}

@Suite("Duration.UnitsFormatStyle.Attributed")
private struct DurationUnitAttributedFormatStyleTests {
    @available(FoundationAttributedString 5.5, *)
    typealias Segment = (String, AttributeScopes.FoundationAttributes.DurationFieldAttribute.Field?, AttributeScopes.FoundationAttributes.MeasurementAttribute.Component?)
    
    let enUS = Locale(identifier: "en_US")
    let frFR = Locale(identifier: "fr_FR")

    @available(FoundationAttributedString 5.5, *)
    @Test func attributedStyle_enUS() {
        let d1 = Duration.seconds(2 * 3600 + 43 * 60 + 24) // 2hr 43min 24s
        let d2 = Duration.seconds(43 * 60 + 24) // 43min 24s
        let d3 = Duration.seconds(24.490) // 24s 490ms
        let d0 = Duration.seconds(0)

        let d4 = Duration.seconds(21 * 86400 + 13 * 3600) // 3wk, 0day, 13hr
        let d5 = Duration.seconds(26 * 86400 + 4 * 3600) // 3wk, 5day, 4hr

        // Default configuration -- hide the field when its value is 0

        #expect(d1.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide).locale(enUS).attributed) ==
                       [("2", .hours, .value),
                        (" ", .hours, nil),
                        ("hours", .hours, .unit),
                        (", ", nil, nil),
                        ("43", .minutes, .value),
                        (" ", .minutes, nil),
                        ("minutes", .minutes, .unit),
                        (", ", nil, nil),
                        ("24", .seconds, .value),
                        (" ", .seconds, nil),
                        ("seconds", .seconds, .unit),
                       ].attributedString)

        #expect(d2.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide).locale(enUS).attributed) ==
                       [("43", .minutes, .value),
                        (" ", .minutes, nil),
                        ("minutes", .minutes, .unit),
                        (", ", nil, nil),
                        ("24", .seconds, .value),
                        (" ", .seconds, nil),
                        ("seconds", .seconds, .unit),
                       ].attributedString)

        #expect(d3.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide).locale(enUS).attributed) ==
                       [("24", .seconds, .value),
                        (" ", .seconds, nil),
                        ("seconds", .seconds, .unit),
                       ].attributedString)

        #expect(d0.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide).locale(enUS).attributed) ==
                       [("0", .seconds, .value),
                        (" ", .seconds, nil),
                        ("seconds", .seconds, .unit),
                       ].attributedString)

        #expect(d4.formatted(.units(allowed: [.weeks, .days, .hours], width: .wide).locale(enUS).attributed) ==
                       [("3", .weeks, .value),
                        (" ", .weeks, nil),
                        ("weeks", .weeks, .unit),
                        (", ", nil, nil),
                        ("13", .hours, .value),
                        (" ", .hours, nil),
                        ("hours", .hours, .unit),
                       ].attributedString)

        #expect(d5.formatted(.units(allowed: [.weeks, .days, .hours], width: .wide).locale(enUS).attributed) ==
                       [("3", .weeks, .value),
                        (" ", .weeks, nil),
                        ("weeks", .weeks, .unit),
                        (", ", nil, nil),
                        ("5", .days, .value),
                        (" ", .days, nil),
                        ("days", .days, .unit),
                        (", ", nil, nil),
                        ("4", .hours, .value),
                        (" ", .hours, nil),
                        ("hours", .hours, .unit),
                       ].attributedString)

        // Always show zero value units

        #expect(d2.formatted(.units(allowed:[.hours, .minutes, .seconds], width: .wide, zeroValueUnits: .show(length: 1)).locale(enUS).attributed) ==
                       [("0", .hours, .value),
                        (" ", .hours, nil),
                        ("hours", .hours, .unit),
                        (", ", nil, nil),
                        ("43", .minutes, .value),
                        (" ", .minutes, nil),
                        ("minutes", .minutes, .unit),
                        (", ", nil, nil),
                        ("24", .seconds, .value),
                        (" ", .seconds, nil),
                        ("seconds", .seconds, .unit),
                       ].attributedString)

        #expect(d3.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide, zeroValueUnits: .show(length: 1)).locale(enUS).attributed) ==
                       [("0", .hours, .value),
                        (" ", .hours, nil),
                        ("hours", .hours, .unit),
                        (", ", nil, nil),
                        ("0", .minutes, .value),
                        (" ", .minutes, nil),
                        ("minutes", .minutes, .unit),
                        (", ", nil, nil),
                        ("24", .seconds, .value),
                        (" ", .seconds, nil),
                        ("seconds", .seconds, .unit),
                       ].attributedString)

        #expect(d0.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide, zeroValueUnits: .show(length: 1)).locale(enUS).attributed) ==
                       [("0", .hours, .value),
                        (" ", .hours, nil),
                        ("hours", .hours, .unit),
                        (", ", nil, nil),
                        ("0", .minutes, .value),
                        (" ", .minutes, nil),
                        ("minutes", .minutes, .unit),
                        (", ", nil, nil),
                        ("0", .seconds, .value),
                        (" ", .seconds, nil),
                        ("seconds", .seconds, .unit),
                       ].attributedString)

        #expect(d4.formatted(.units(allowed: [.weeks, .days, .hours], width: .wide, zeroValueUnits: .show(length: 1)).locale(enUS).attributed) ==
                       [("3", .weeks, .value),
                        (" ", .weeks, nil),
                        ("weeks", .weeks, .unit),
                        (", ", nil, nil),
                        ("0", .days, .value),
                        (" ", .days, nil),
                        ("days", .days, .unit),
                        (", ", nil, nil),
                        ("13", .hours, .value),
                        (" ", .hours, nil),
                        ("hours", .hours, .unit),
                       ].attributedString)


        // Always show zero value units padded

        #expect(d0.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide, zeroValueUnits: .show(length: 2)).locale(enUS).attributed) ==
                       [("00", .hours, .value),
                        (" ", .hours, nil),
                        ("hours", .hours, .unit),
                        (", ", nil, nil),
                        ("00", .minutes, .value),
                        (" ", .minutes, nil),
                        ("minutes", .minutes, .unit),
                        (", ", nil, nil),
                        ("00", .seconds, .value),
                        (" ", .seconds, nil),
                        ("seconds", .seconds, .unit),
                       ].attributedString)

        // Test fractional parts

        #expect(d1.formatted(.units(allowed:[.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 1, fractionalPart: .show(length: 2)).attributed.locale(enUS)) ==
                       [("2.72", .hours, .value),
                        (" ", .hours, nil),
                        ("hr", .hours, .unit),
                       ].attributedString)

        #expect(d0.formatted(.units(allowed:[.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 1, fractionalPart: .show(length: 2)).attributed.locale(enUS)) ==
                       [("0.00", .seconds, .value),
                        (" ", .seconds, nil),
                        ("sec", .seconds, .unit),
                       ].attributedString)

        #expect(d4.formatted(.units(allowed: [.weeks, .days, .hours], width: .wide, maximumUnitCount: 1, fractionalPart: .show(length: 2)).locale(enUS).attributed) ==
                       [("3.08", .weeks, .value),
                        (" ", .weeks, nil),
                        ("weeks", .weeks, .unit),
                       ].attributedString)
    }

    @available(FoundationAttributedString 5.5, *)
    @Test func testAttributedStyle_frFR() {
        let d1 = Duration.seconds(2 * 3600 + 43 * 60 + 24) // 2hr 43min 24s
        let d0 = Duration.seconds(0)
        let nbsp = " "

        #expect(d1.formatted(.units(allowed: [.seconds], width: .wide).locale(frFR).attributed) ==
                       [("9 804", .seconds, .value),
                        (nbsp, .seconds, nil),
                        ("secondes", .seconds, .unit),
                       ].attributedString)

        #expect(d0.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide).locale(frFR).attributed) ==
                       [("0", .seconds, .value),
                        (nbsp, .seconds, nil),
                        ("seconde", .seconds, .unit),
                       ].attributedString)

    }
}

// MARK: DiscreteFormatStyle conformance test

@Suite("Duration.UnitsFormatStyle Discrete Conformance")
private struct TestDurationUnitsDiscreteConformance {
    @Test func basics() throws {
        var style: Duration.UnitsFormatStyle
        style = .units(fractionalPart: .hide(rounded: .down)).locale(Locale(identifier: "en_US"))

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


        style.fractionalPartDisplay.roundingRule = .up

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

        style.fractionalPartDisplay.roundingRule = .towardZero

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

        style.fractionalPartDisplay.roundingRule = .awayFromZero

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

        style.fractionalPartDisplay.roundingRule = .toNearestOrAwayFromZero

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

        style.fractionalPartDisplay.roundingRule = .toNearestOrEven

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

    @Test func evaluation() {
        func assertEvaluation(of style: Duration._UnitsFormatStyle,
                              rounding roundingRules: [FloatingPointRoundingRule] = [.up, .down, .towardZero, .awayFromZero, .toNearestOrAwayFromZero, .toNearestOrEven],
                              in range: ClosedRange<Duration>,
                              includes expectedExcerpts: [String]...,
                              sourceLocation: SourceLocation = #_sourceLocation) {

            for rule in roundingRules {
                var style = style.locale(Locale(identifier: "en_US"))
                style.fractionalPartDisplay.roundingRule = rule
                verify(
                    sequence: style.evaluate(from: range.lowerBound, to: range.upperBound).map(\.output),
                    contains: expectedExcerpts,
                    "lowerbound to upperbound, rounding \(rule)",
                    sourceLocation: sourceLocation)
                
                verify(
                    sequence: style.evaluate(from: range.upperBound, to: range.lowerBound).map(\.output),
                    contains: expectedExcerpts
                        .reversed()
                        .map { $0.reversed() },
                    "upperbound to lowerbound, rounding \(rule)",
                    sourceLocation: sourceLocation)
            }
        }
        
        
        assertEvaluation(
            of: .init(allowedUnits: [.minutes, .seconds], width: .narrow, zeroValueUnits: .show(length: 1), fractionalPart: .hide),
            in: Duration.seconds(61).symmetricRange,
            includes: [
                "-1m 1s",
                "-1m 0s",
                "-0m 59s",
                "-0m 58s",
                "-0m 57s",
                "-0m 56s",
                "-0m 55s",
            ],
            [
                "-0m 2s",
                "-0m 1s",
                "0m 0s",
                "0m 1s",
                "0m 2s",
            ],
            [
                "0m 55s",
                "0m 56s",
                "0m 57s",
                "0m 58s",
                "0m 59s",
                "1m 0s",
                "1m 1s",
            ])
        
        assertEvaluation(
            of: .init(allowedUnits: [.minutes, .seconds], width: .narrow, maximumUnitCount: 1, zeroValueUnits: .hide, fractionalPart: .hide),
            in: Duration.seconds(120).symmetricRange,
            includes: [
                "-2m",
                "-1m",
                "-59s",
                "-58s",
                "-57s",
                "-56s",
                "-55s",
            ],
            [
                "-2s",
                "-1s",
                "0s",
                "1s",
                "2s",
            ],
            [
                "55s",
                "56s",
                "57s",
                "58s",
                "59s",
                "1m",
                "2m",
            ])
        
        assertEvaluation(
            of: .init(allowedUnits: [.hours], width: .narrow, zeroValueUnits: .show(length: 1), fractionalPart: .hide),
            in: Duration.seconds(3 * 3600).symmetricRange,
            includes: [
                "-3h",
                "-2h",
                "-1h",
                "0h",
                "1h",
                "2h",
                "3h",
            ])
        
        assertEvaluation(
            of: .init(allowedUnits: [.minutes, .seconds], width: .narrow, maximumUnitCount: 1, zeroValueUnits: .hide, fractionalPart: .show(length: 1)),
            in: Duration.seconds(120).symmetricRange,
            includes: [
                "-2.0m",
                "-1.9m",
                "-1.8m",
                "-1.7m",
                "-1.6m",
                "-1.5m",
                "-1.4m",
                "-1.3m",
                "-1.2m",
                "-1.1m",
                "-1.0m",
                "-59.9s",
                "-59.8s",
                "-59.7s",
                "-59.6s",
                "-59.5s",
                "-59.4s",
                "-59.3s",
                "-59.2s",
                "-59.1s",
                "-59.0s",
                "-58.9s",
            ],
            [
                "-1.1s",
                "-1.0s",
                "-0.9s",
                "-0.8s",
                "-0.7s",
                "-0.6s",
                "-0.5s",
                "-0.4s",
                "-0.3s",
                "-0.2s",
                "-0.1s",
                "0.0s",
                "0.1s",
                "0.2s",
                "0.3s",
                "0.4s",
                "0.5s",
                "0.6s",
                "0.7s",
                "0.8s",
                "0.9s",
                "1.0s",
                "1.1s",
            ],
            [
                "58.9s",
                "59.0s",
                "59.1s",
                "59.2s",
                "59.3s",
                "59.4s",
                "59.5s",
                "59.6s",
                "59.7s",
                "59.8s",
                "59.9s",
                "1.0m",
                "1.1m",
                "1.2m",
                "1.3m",
                "1.4m",
                "1.5m",
                "1.6m",
                "1.7m",
                "1.8m",
                "1.9m",
                "2.0m",
            ])
    }
    
    @Test func regressions() throws {
        var style: Duration._UnitsFormatStyle
        
        style = .init(allowedUnits: [.minutes, .seconds], width: .narrow, maximumUnitCount: 1, zeroValueUnits: .hide, fractionalPart: .show(length: 1, rounded: .toNearestOrAwayFromZero))
        
        #expect(try #require(style.discreteInput(after: Duration(secondsComponent: -75, attosecondsComponent: -535173016509531840))) <= Duration(secondsComponent: -73, attosecondsComponent: -122099659011723263))
        
        style = .init(allowedUnits: [.minutes, .seconds], width: .narrow, maximumUnitCount: 1, zeroValueUnits: .hide, fractionalPart: .show(length: 1))
        
        #expect(try #require(style.discreteInput(after: Duration(secondsComponent: -63, attosecondsComponent: -0))) <= Duration(secondsComponent: -59, attosecondsComponent: -900000000000000000))
    }
    
    @Test func randomSamples() throws {
        let styles: [Duration._UnitsFormatStyle] = [
            .init(allowedUnits: [.minutes, .seconds], width: .narrow, zeroValueUnits: .show(length: 1), fractionalPart: .hide),
            .init(allowedUnits: [.minutes, .seconds], width: .narrow, maximumUnitCount: 1, zeroValueUnits: .hide, fractionalPart: .hide),
            .init(allowedUnits: [.hours], width: .narrow, zeroValueUnits: .show(length: 1), fractionalPart: .hide),
        ] + [FloatingPointRoundingRule.up, .down, .towardZero, .awayFromZero, .toNearestOrAwayFromZero, .toNearestOrEven].flatMap { roundingRule in
            [
                .init(allowedUnits: [.minutes, .seconds], width: .narrow, maximumUnitCount: 1, zeroValueUnits: .hide, fractionalPart: .show(length: 1, rounded: roundingRule)),
            ]
        }
        
        
        for style in styles {
            try verifyDiscreteFormatStyleConformance(style.locale(Locale(identifier: "en_US")), samples: 100, "\(style)")
        }
    }
    
}

extension Duration {
    var symmetricRange: ClosedRange<Duration> {
        (.zero - abs(self))...abs(self)
    }
}
