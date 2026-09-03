//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing

#if canImport(TestSupport)
import TestSupport
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable import FoundationInternationalization
@testable import FoundationEssentials
#endif

@Suite("Calendar ICU", .tags(.calendar))
private struct CalendarICUTests {

    private var icuGregorianGMTCalendar:  _CalendarICU {
        _CalendarICU(
            identifier: .gregorian,
            timeZone: .gmt,
            locale: nil,
            firstWeekday: nil,
            minimumDaysInFirstWeek: nil,
            gregorianStartDate: nil
        )
    }
#if _pointerBitWidth(_64) // These tests require Int to be Int64
    @Test func addingDayBeyondInt32Range() throws {
        let cal = icuGregorianGMTCalendar
        let base = Date(timeIntervalSinceReferenceDate: 0)

        let dc = DateComponents(day: Int(Int32.max) + 1)

        let result = cal.date(byAdding: dc, to: base, wrappingComponents: false)
        let out = try #require(result)

        #expect(out >= base, "adding a positive day amount must not move the date backward")
    }

    @Test func addingSecondsBeyondInt32Range() throws {
        let cal = icuGregorianGMTCalendar
        let base = Date(timeIntervalSinceReferenceDate: 0)

        let dc = DateComponents(second: 1 << 32)
        let result = cal.date(byAdding: dc, to: base, wrappingComponents: false)
        let out = try #require(result)
        #expect(abs(out.timeIntervalSince(base)) > 1.0, "adding 2^32 seconds must not be a no-op: \(out), \(base)")
    }

    @Test func addingSecondsIsMonotonicAcrossInt32Boundary() throws {
        let cal = icuGregorianGMTCalendar
        let base = Date(timeIntervalSinceReferenceDate: 0)

        let small = DateComponents(second: Int(Int32.max))
        let big = DateComponents(second: Int(Int32.max) + 2)
        let resultSmall = cal.date(byAdding: small, to: base, wrappingComponents: false)
        let resultBig = cal.date(byAdding: big, to: base, wrappingComponents: false)
        let outSmall = try #require(resultSmall)
        let outBig = try #require(resultBig)
        #expect(outBig >= outSmall, "adding a larger positive amount must not produce an earlier date")
    }
#endif

    @Test(arguments: [
        (1, Date(timeIntervalSince1970: 1703980800)), // 2023-12-31
        (2, Date(timeIntervalSince1970: 1704585600)), // 2024-01-07
        (3, Date(timeIntervalSince1970: 1705190400)), // 2024-01-14
        (4, Date(timeIntervalSince1970: 1705795200)), // 2024-01-21
        (5, Date(timeIntervalSince1970: 1706400000)), // 2024-01-28
    ])
    func dateFromComponentsWeekOfMonth(weekOfMonth: Int, expected: Date) {
        let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: .gmt, locale: nil, firstWeekday: 1, minimumDaysInFirstWeek: 1, gregorianStartDate: nil)
        #expect(icuCalendar.date(from: DateComponents(year: 2024, month: 1, weekOfMonth: weekOfMonth)) == expected)
    }

    @Test(arguments: 1...5)
    func dateFromComponentsWeekOfMonthMatchesGregorianBackend(weekOfMonth: Int) {
        let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: .gmt, locale: nil, firstWeekday: 1, minimumDaysInFirstWeek: 1, gregorianStartDate: nil)
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: .gmt, locale: nil, firstWeekday: 1, minimumDaysInFirstWeek: 1, gregorianStartDate: nil)
        let components = DateComponents(year: 2024, month: 1, weekOfMonth: weekOfMonth)
        let icuResult = icuCalendar.date(from: components)
        let gregorianResult = gregorianCalendar.date(from: components)

        #expect(icuResult == gregorianResult, "ICU returned \(String(describing: icuResult)), Gregorian returned \(String(describing: gregorianResult))")
    }
}
