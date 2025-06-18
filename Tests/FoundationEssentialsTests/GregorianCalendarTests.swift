//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing

#if canImport(FoundationEssentials)
@testable import FoundationEssentials
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#endif

@Suite("Gregorian Calendar")
private struct GregorianCalendarTests {

    // MARK: Basic
    @Test func testNumberOfDaysInMonth() {
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: .gmt, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
        #expect(gregorianCalendar.numberOfDaysInMonth(2, year: 2023) == 28) // not leap year
        #expect(gregorianCalendar.numberOfDaysInMonth(0, year: 2023) == 31) // equivalent to month: 12, year: 2022
        #expect(gregorianCalendar.numberOfDaysInMonth(14, year: 2023) == 29) // equivalent to month: 2, year: 2024

        #expect(gregorianCalendar.numberOfDaysInMonth(2, year: 2024) == 29) // leap year
        #expect(gregorianCalendar.numberOfDaysInMonth(-10, year: 2024) == 28) //  equivalent to month: 2, year: 2023, not leap
        #expect(gregorianCalendar.numberOfDaysInMonth(14, year: 2024) == 28) //  equivalent to month: 2, year: 2025, not leap

        #expect(gregorianCalendar.numberOfDaysInMonth(50, year: 2024) == 29) //  equivalent to month: 2, year: 2028, leap
    }

    @Test func testRemoteJulianDayCrash() {
        // Accessing the integer julianDay of a remote date should not crash
        let d = Date(julianDate: 9223372036854775808) // Int64.max + 1
        _ = d.julianDay
    }

    // MARK: Date from components

    @Test func testDateFromComponents() {
        // The expected dates were generated using ICU Calendar
        let tz = TimeZone.gmt
        let cal = _CalendarGregorian(identifier: .gregorian, timeZone: tz, locale: nil, firstWeekday: 1, minimumDaysInFirstWeek: 4, gregorianStartDate: nil)
        func test(_ dateComponents: DateComponents, expected: Date, sourceLocation: SourceLocation = #_sourceLocation) {
            let date = cal.date(from: dateComponents)
            #expect(date == expected, "date components: \(dateComponents)", sourceLocation: sourceLocation)
        }

        test(.init(year: 1582, month: -7, weekday: 5, weekdayOrdinal: 0), expected: Date(timeIntervalSince1970: -12264739200.0))
        test(.init(year: 1582, month: -3, weekday: 0, weekdayOrdinal: -5), expected: Date(timeIntervalSince1970: -12253680000.0))
        test(.init(year: 1582, month: 5, weekday: -2, weekdayOrdinal: 3), expected: Date(timeIntervalSince1970: -12231475200.0))
        test(.init(year: 1582, month: 5, weekday: 4, weekdayOrdinal: 6), expected: Date(timeIntervalSince1970: -12229747200.0))
        test(.init(year: 2014, month: -4, weekday: -1, weekdayOrdinal: 4), expected: Date(timeIntervalSince1970: 1377216000.0))
        test(.init(year: 2446, month: -1, weekday: -1, weekdayOrdinal: -1), expected: Date(timeIntervalSince1970: 15017875200.0))
        test(.init(year: 2878, month: -9, weekday: -9, weekdayOrdinal: 1), expected: Date(timeIntervalSince1970: 28627603200.0))
        test(.init(year: 2878, month: -5, weekday: 1, weekdayOrdinal: -6), expected: Date(timeIntervalSince1970: 28636934400.0))
        test(.init(year: 2878, month: 7, weekday: -7, weekdayOrdinal: 8), expected: Date(timeIntervalSince1970: 28673740800.0))
        test(.init(year: 2878, month: 11, weekday: -1, weekdayOrdinal: 4), expected: Date(timeIntervalSince1970: 28682121600.0))

        test(.init(year: 1582, month: -7, day: 2), expected: Date(timeIntervalSince1970: -12264307200.0))
        test(.init(year: 1582, month: 1, day: -1), expected: Date(timeIntervalSince1970: -12243398400.0))
        test(.init(year: 1705, month: 6, day: -6), expected: Date(timeIntervalSince1970: -8350128000.0))
        test(.init(year: 1705, month: 6, day: 3), expected: Date(timeIntervalSince1970: -8349350400.0))
        test(.init(year: 1828, month: -9, day: -3), expected: Date(timeIntervalSince1970: -4507920000.0))
        test(.init(year: 1828, month: 3, day: 0), expected: Date(timeIntervalSince1970: -4476038400.0))
        test(.init(year: 1828, month: 7, day: 5), expected: Date(timeIntervalSince1970: -4465065600.0))
        test(.init(year: 2074, month: -4, day: 2), expected: Date(timeIntervalSince1970: 3268857600.0))
        test(.init(year: 2197, month: 5, day: -2), expected: Date(timeIntervalSince1970: 7173619200.0))
        test(.init(year: 2197, month: 5, day: 1), expected: Date(timeIntervalSince1970: 7173878400.0))
        test(.init(year: 2320, month: -2, day: -2), expected: Date(timeIntervalSince1970: 11036649600.0))
        test(.init(year: 2320, month: 6, day: -3), expected: Date(timeIntervalSince1970: 11057644800.0))
        test(.init(year: 2443, month: 7, day: 5), expected: Date(timeIntervalSince1970: 14942448000.0))
        test(.init(year: 2812, month: 5, day: 4), expected: Date(timeIntervalSince1970: 26581651200.0))
        test(.init(year: 2935, month: 6, day: -3), expected: Date(timeIntervalSince1970: 30465158400.0))
        test(.init(year: 2935, month: 6, day: 3), expected: Date(timeIntervalSince1970: 30465676800.0))

        test(.init(year: 1582, month: 5, weekOfMonth: -2), expected: Date(timeIntervalSince1970: -12232857600.0))
        test(.init(year: 1582, month: 5, weekOfMonth: 4), expected: Date(timeIntervalSince1970: -12232857600.0))
        test(.init(year: 1705, month: 2, weekOfMonth: 1), expected: Date(timeIntervalSince1970: -8359891200.0))
        test(.init(year: 1705, month: 6, weekOfMonth: -3), expected: Date(timeIntervalSince1970: -8349523200.0))
        test(.init(year: 1828, month: 7, weekOfMonth: 2), expected: Date(timeIntervalSince1970: -4465411200.0))
        test(.init(year: 1828, month: 7, weekOfMonth: 5), expected: Date(timeIntervalSince1970: -4465411200.0))
        test(.init(year: 1828, month: 11, weekOfMonth: 0), expected: Date(timeIntervalSince1970: -4454784000.0))
        test(.init(year: 2197, month: 5, weekOfMonth: -2), expected: Date(timeIntervalSince1970: 7173878400.0))
        test(.init(year: 2197, month: 5, weekOfMonth: 1), expected: Date(timeIntervalSince1970: 7173878400.0))
        test(.init(year: 2320, month: 2, weekOfMonth: 1), expected: Date(timeIntervalSince1970: 11047536000.0))
        test(.init(year: 2320, month: 6, weekOfMonth: -3), expected: Date(timeIntervalSince1970: 11057990400.0))
        test(.init(year: 2443, month: -5, weekOfMonth: 4), expected: Date(timeIntervalSince1970: 14910566400.0))
        test(.init(year: 2443, month: -1, weekOfMonth: -1), expected: Date(timeIntervalSince1970: 14921193600.0))
        test(.init(year: 2443, month: 7, weekOfMonth: -1), expected: Date(timeIntervalSince1970: 14942102400.0))
        test(.init(year: 2443, month: 7, weekOfMonth: 2), expected: Date(timeIntervalSince1970: 14942102400.0))
        test(.init(year: 2812, month: -3, weekOfMonth: -3), expected: Date(timeIntervalSince1970: 26560396800.0))
        test(.init(year: 2812, month: 5, weekOfMonth: 1), expected: Date(timeIntervalSince1970: 26581392000.0))
        test(.init(year: 2812, month: 5, weekOfMonth: 4), expected: Date(timeIntervalSince1970: 26581392000.0))
        test(.init(year: 2935, month: 6, weekOfMonth: 0), expected: Date(timeIntervalSince1970: 30465504000.0))

        test(.init(weekOfYear: 20, yearForWeekOfYear: 1582), expected: Date(timeIntervalSince1970: -12231820800.0))
        test(.init(weekOfYear: -25, yearForWeekOfYear: 1705), expected: Date(timeIntervalSince1970: -8378035200.0))
        test(.init(weekOfYear: -4, yearForWeekOfYear: 1705), expected: Date(timeIntervalSince1970: -8365334400.0))
        test(.init(weekOfYear: 3, yearForWeekOfYear: 1705), expected: Date(timeIntervalSince1970: -8361100800.0))
        test(.init(weekOfYear: 0, yearForWeekOfYear: 1828), expected: Date(timeIntervalSince1970: -4481913600.0))
        test(.init(weekOfYear: 25, yearForWeekOfYear: 1951), expected: Date(timeIntervalSince1970: -585187200.0))
        test(.init(weekOfYear: -34, yearForWeekOfYear: 2074), expected: Date(timeIntervalSince1970: 3260736000.0))
        test(.init(weekOfYear: 1, yearForWeekOfYear: 2074), expected: Date(timeIntervalSince1970: 3281904000.0))
        test(.init(weekOfYear: 8, yearForWeekOfYear: 2074), expected: Date(timeIntervalSince1970: 3286137600.0))
        test(.init(weekOfYear: -1, yearForWeekOfYear: 2443), expected: Date(timeIntervalSince1970: 14925513600.0))
        test(.init(weekOfYear: 3, yearForWeekOfYear: 2566), expected: Date(timeIntervalSince1970: 18808934400.0))
        test(.init(weekOfYear: 0, yearForWeekOfYear: 2689), expected: Date(timeIntervalSince1970: 22688726400.0))
        test(.init(weekOfYear: -52, yearForWeekOfYear: 2812), expected: Date(timeIntervalSince1970: 26538883200.0))
        test(.init(weekOfYear: 1, yearForWeekOfYear: 2935), expected: Date(timeIntervalSince1970: 30452544000.0))
        test(.init(weekOfYear: 43, yearForWeekOfYear: 2935), expected: Date(timeIntervalSince1970: 30477945600.0))
    }

    // MARK: - DateComponents from date
    @Test func testDateComponentsFromDate() {
        let calendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(secondsFromGMT: 0)!, locale: nil, firstWeekday: 1, minimumDaysInFirstWeek: 5, gregorianStartDate: nil)
        func test(_ date: Date, _ timeZone: TimeZone, expectedEra era: Int, year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int, nanosecond: Int, weekday: Int, weekdayOrdinal: Int, quarter: Int, weekOfMonth: Int, weekOfYear: Int, yearForWeekOfYear: Int, isLeapMonth: Bool, sourceLocation: SourceLocation = #_sourceLocation) {
            let dc = calendar.dateComponents([.era, .year, .month, .day, .hour, .minute, .second, .nanosecond, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .calendar, .timeZone], from: date)
            #expect(dc.era == era, sourceLocation: sourceLocation)
            #expect(dc.year == year, sourceLocation: sourceLocation)
            #expect(dc.month == month, sourceLocation: sourceLocation)
            #expect(dc.day == day, sourceLocation: sourceLocation)
            #expect(dc.hour == hour, sourceLocation: sourceLocation)
            #expect(dc.minute == minute, sourceLocation: sourceLocation)
            #expect(dc.second == second, sourceLocation: sourceLocation)
            #expect(dc.weekday == weekday, sourceLocation: sourceLocation)
            #expect(dc.weekdayOrdinal == weekdayOrdinal, sourceLocation: sourceLocation)
            #expect(dc.weekOfMonth == weekOfMonth, sourceLocation: sourceLocation)
            #expect(dc.weekOfYear == weekOfYear, sourceLocation: sourceLocation)
            #expect(dc.yearForWeekOfYear == yearForWeekOfYear, sourceLocation: sourceLocation)
            #expect(dc.quarter == quarter, sourceLocation: sourceLocation)
            #expect(dc.nanosecond == nanosecond, sourceLocation: sourceLocation)
            #expect(dc.isLeapMonth == isLeapMonth, sourceLocation: sourceLocation)
            #expect(dc.timeZone == timeZone, sourceLocation: sourceLocation)
        }
        test(Date(timeIntervalSince1970: 852045787.0), .gmt, expectedEra: 1, year: 1996, month: 12, day: 31, hour: 15, minute: 23, second: 7, nanosecond: 0, weekday: 3, weekdayOrdinal: 5, quarter: 4, weekOfMonth: 5, weekOfYear: 53, yearForWeekOfYear: 1996, isLeapMonth: false) // 1996-12-31T15:23:07Z
        test(Date(timeIntervalSince1970: 825607387.0), .gmt, expectedEra: 1, year: 1996, month: 2, day: 29, hour: 15, minute: 23, second: 7, nanosecond: 0, weekday: 5, weekdayOrdinal: 5, quarter: 1, weekOfMonth: 4, weekOfYear: 9, yearForWeekOfYear: 1996, isLeapMonth: false) // 1996-02-29T15:23:07Z
        test(Date(timeIntervalSince1970: 828838987.0), .gmt, expectedEra: 1, year: 1996, month: 4, day: 7, hour: 1, minute: 3, second: 7, nanosecond: 0, weekday: 1, weekdayOrdinal: 1, quarter: 2, weekOfMonth: 2, weekOfYear: 15, yearForWeekOfYear: 1996, isLeapMonth: false) // 1996-04-07T01:03:07Z
        test(Date(timeIntervalSince1970: -62135765813.0), .gmt, expectedEra: 1, year: 1, month: 1, day: 1, hour: 1, minute: 3, second: 7, nanosecond: 0, weekday: 7, weekdayOrdinal: 1, quarter: 1, weekOfMonth: 0, weekOfYear: 52, yearForWeekOfYear: 0, isLeapMonth: false) // 0001-01-01T01:03:07Z
        test(Date(timeIntervalSince1970: -62135852213.0), .gmt, expectedEra: 0, year: 1, month: 12, day: 31, hour: 1, minute: 3, second: 7, nanosecond: 0, weekday: 6, weekdayOrdinal: 5, quarter: 4, weekOfMonth: 4, weekOfYear: 52, yearForWeekOfYear: 0, isLeapMonth: false) // 0000-12-31T01:03:07Z
    }

    @Test func testDateComponentsFromDate_DST() {

        func test(_ date: Date, expectedEra era: Int, year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int, nanosecond: Int, weekday: Int, weekdayOrdinal: Int, quarter: Int, weekOfMonth: Int, weekOfYear: Int, yearForWeekOfYear: Int, isLeapMonth: Bool, sourceLocation: SourceLocation = #_sourceLocation) {
            let dc = calendar.dateComponents([.era, .year, .month, .day, .hour, .minute, .second, .nanosecond, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .calendar, .timeZone], from: date)
            #expect(dc.era == era, "era should be equal", sourceLocation: sourceLocation)
            #expect(dc.year == year, "era should be equal", sourceLocation: sourceLocation)
            #expect(dc.month == month, "month should be equal", sourceLocation: sourceLocation)
            #expect(dc.day == day, "day should be equal", sourceLocation: sourceLocation)
            #expect(dc.hour == hour, "hour should be equal", sourceLocation: sourceLocation)
            #expect(dc.minute == minute, "minute should be equal", sourceLocation: sourceLocation)
            #expect(dc.second == second, "second should be equal", sourceLocation: sourceLocation)
            #expect(dc.weekday == weekday, "weekday should be equal", sourceLocation: sourceLocation)
            #expect(dc.weekdayOrdinal == weekdayOrdinal, "weekdayOrdinal should be equal", sourceLocation: sourceLocation)
            #expect(dc.weekOfMonth == weekOfMonth, "weekOfMonth should be equal", sourceLocation: sourceLocation)
            #expect(dc.weekOfYear == weekOfYear, "weekOfYear should be equal", sourceLocation: sourceLocation)
            #expect(dc.yearForWeekOfYear == yearForWeekOfYear, "yearForWeekOfYear should be equal", sourceLocation: sourceLocation)
            #expect(dc.quarter == quarter, "quarter should be equal", sourceLocation: sourceLocation)
            #expect(dc.nanosecond == nanosecond, "nanosecond should be equal", sourceLocation: sourceLocation)
            #expect(dc.isLeapMonth == isLeapMonth, "isLeapMonth should be equal", sourceLocation: sourceLocation)
            #expect(dc.timeZone == calendar.timeZone, "timeZone should be equal", sourceLocation: sourceLocation)
        }

        let calendar = _CalendarGregorian(identifier: .gregorian, timeZone: .gmt, locale: nil, firstWeekday: 1, minimumDaysInFirstWeek: 1, gregorianStartDate: nil)
        test(Date(timeIntervalSince1970: -62135769600.0), expectedEra: 1, year: 1, month: 1, day: 1, hour: 0, minute: 0, second: 0, nanosecond: 0, weekday: 7, weekdayOrdinal: 1, quarter: 1, weekOfMonth: 1, weekOfYear: 1, yearForWeekOfYear: 1, isLeapMonth: false) // 0001-01-01T00:00:00Z
        test(Date(timeIntervalSince1970: 64092211200.0), expectedEra: 1, year: 4001, month: 1, day: 1, hour: 0, minute: 0, second: 0, nanosecond: 0, weekday: 2, weekdayOrdinal: 1, quarter: 1, weekOfMonth: 1, weekOfYear: 1, yearForWeekOfYear: 4001, isLeapMonth: false)
        test(Date(timeIntervalSince1970: -210866760000.0), expectedEra: 0, year: 4713, month: 1, day: 1, hour: 12, minute: 0, second: 0, nanosecond: 0, weekday: 2, weekdayOrdinal: 1, quarter: 1, weekOfMonth: 1, weekOfYear: 1, yearForWeekOfYear: -4712, isLeapMonth: false)
    }

    // MARK: - Add

    @Test func testAdd() {
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(secondsFromGMT: 3600)!, locale: nil, firstWeekday: 3, minimumDaysInFirstWeek: 4, gregorianStartDate: nil)
        var date: Date
        func test(addField field: Calendar.Component, value: Int, to addingToDate: Date, wrap: Bool, expectedDate: Date, sourceLocation: SourceLocation = #_sourceLocation) {
            let components = DateComponents(component: field, value: value)!
            let result = gregorianCalendar.date(byAdding: components, to: addingToDate, wrappingComponents: wrap)!
            #expect(result == expectedDate, sourceLocation: sourceLocation)
        }

        date = Date(timeIntervalSince1970: 825723300.0)
        test(addField: .era, value: 4, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 825723300.0))
        test(addField: .era, value: -6, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 825723300.0))
        test(addField: .year, value: 1274, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 41029284900.0))
        test(addField: .year, value: -1403, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -43448487900.0))
        test(addField: .yearForWeekOfYear, value: 183, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 6600353700.0))
        test(addField: .yearForWeekOfYear, value: -1336, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -41334279900.0))
        test(addField: .month, value: 11, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 823217700.0))
        test(addField: .month, value: -1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 823217700.0))
        test(addField: .day, value: 73, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 826673700.0))
        test(addField: .day, value: -302, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 826414500.0))
        test(addField: .hour, value: 179, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 825762900.0))
        test(addField: .hour, value: -133, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 825762900.0))
        test(addField: .minute, value: 235, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 825723000.0))
        test(addField: .minute, value: -1195, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 825723600.0))
        test(addField: .second, value: 1208, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 825723308.0))
        test(addField: .second, value: -4362, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 825723318.0))
        test(addField: .weekday, value: 7, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 825723300.0))
        test(addField: .weekday, value: -21, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 825723300.0))
        test(addField: .weekdayOrdinal, value: 17, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 826932900.0))
        test(addField: .weekdayOrdinal, value: -30, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 825723300.0))
        test(addField: .weekOfYear, value: 13, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 833585700.0))
        test(addField: .weekOfYear, value: -49, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 826932900.0))
        test(addField: .weekOfMonth, value: 40, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 825723300.0))
        test(addField: .weekOfMonth, value: -62, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 827537700.0))

        date = Date(timeIntervalSince1970: -12218515200.0)
        test(addField: .era, value: 6, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -12218515200.0))
        test(addField: .era, value: -10, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -12218515200.0))
        test(addField: .year, value: 1957, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 49538390400.0))
        test(addField: .year, value: -1120, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -47562163200.0))
        test(addField: .yearForWeekOfYear, value: 1212, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 26027827200.0))
        test(addField: .yearForWeekOfYear, value: -114, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -15816470400.0))
        test(addField: .month, value: 23, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -12220243200.0))
        test(addField: .month, value: -21, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -12241238400.0))
        test(addField: .day, value: 213, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -12218256000.0))
        test(addField: .day, value: -618, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -12219292800.0))
        test(addField: .hour, value: 279, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -12218461200.0))
        test(addField: .hour, value: -316, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -12218443200.0))
        test(addField: .minute, value: 945, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -12218512500.0))
        test(addField: .minute, value: -1314, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -12218514840.0))
        test(addField: .second, value: 6371, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -12218515189.0))
        test(addField: .second, value: -259, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -12218515159.0))
        test(addField: .weekday, value: 9, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -12218947200.0))
        test(addField: .weekday, value: -14, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -12218515200.0))
        test(addField: .weekdayOrdinal, value: 4, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -12219120000.0))
        test(addField: .weekdayOrdinal, value: -26, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -12219120000.0))
        test(addField: .weekOfYear, value: 53, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -12217910400.0))
        test(addField: .weekOfYear, value: -51, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -12217910400.0))
        test(addField: .weekOfMonth, value: 44, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -12219120000.0))
        test(addField: .weekOfMonth, value: -64, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -12219120000.0))
        test(addField: .nanosecond, value: 278337903, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -12218515199.721663))
        test(addField: .nanosecond, value: -996490757, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -12218515200.99649))

        date = Date(timeIntervalSince1970: 825723300.0)
        test(addField: .era, value: 10, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 825723300.0))
        test(addField: .era, value: -4, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 825723300.0))
        test(addField: .year, value: 1044, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 33771166500.0))
        test(addField: .year, value: -1575, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -48876395100.0))
        test(addField: .yearForWeekOfYear, value: 686, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 22473934500.0))
        test(addField: .yearForWeekOfYear, value: -586, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -17666036700.0))
        test(addField: .month, value: 10, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 852161700.0))
        test(addField: .month, value: -24, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 762564900.0))
        test(addField: .day, value: 464, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 865812900.0))
        test(addField: .day, value: -576, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 775956900.0))
        test(addField: .hour, value: 208, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 826472100.0))
        test(addField: .hour, value: -351, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 824459700.0))
        test(addField: .minute, value: 1541, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 825815760.0))
        test(addField: .minute, value: -6383, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 825340320.0))
        test(addField: .second, value: 4025, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 825727325.0))
        test(addField: .second, value: -4753, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 825718547.0))
        test(addField: .weekday, value: 9, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 826500900.0))
        test(addField: .weekday, value: -17, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 824254500.0))
        test(addField: .weekdayOrdinal, value: 11, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 832376100.0))
        test(addField: .weekdayOrdinal, value: -27, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 809393700.0))
        test(addField: .weekOfYear, value: 65, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 865035300.0))
        test(addField: .weekOfYear, value: -5, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 822699300.0))
        test(addField: .weekOfMonth, value: 39, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 849310500.0))
        test(addField: .weekOfMonth, value: -34, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 805160100.0))

        date = Date(timeIntervalSince1970: -12218515200.0)
        test(addField: .era, value: 5, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -12218515200.0))
        test(addField: .era, value: -7, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -12218515200.0))
        test(addField: .year, value: 531, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 4538246400.0))
        test(addField: .year, value: -428, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -25724304000.0))
        test(addField: .yearForWeekOfYear, value: 583, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 6178291200.0))
        test(addField: .yearForWeekOfYear, value: -1678, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -65172384000.0))
        test(addField: .month, value: 7, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -12200198400.0))
        test(addField: .month, value: 0, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -12218515200.0))
        test(addField: .day, value: 410, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -12183091200.0))
        test(addField: .day, value: -645, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -12274243200.0))
        test(addField: .hour, value: 228, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -12217694400.0))
        test(addField: .hour, value: -263, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -12219462000.0))
        test(addField: .minute, value: 3913, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -12218280420.0))
        test(addField: .minute, value: -2412, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -12218659920.0))
        test(addField: .second, value: 6483, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -12218508717.0))
        test(addField: .second, value: -1469, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -12218516669.0))
        test(addField: .weekday, value: 16, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -12217132800.0))
        test(addField: .weekday, value: -11, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -12219465600.0))
        test(addField: .weekdayOrdinal, value: 9, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -12213072000.0))
        test(addField: .weekdayOrdinal, value: -3, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -12220329600.0))
        test(addField: .weekOfYear, value: 41, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -12193718400.0))
        test(addField: .weekOfYear, value: -21, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -12231216000.0))
        test(addField: .weekOfMonth, value: 64, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -12179808000.0))
        test(addField: .weekOfMonth, value: -7, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -12222748800.0))
        test(addField: .nanosecond, value: 720667058, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -12218515199.279333))
        test(addField: .nanosecond, value: -812249727, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -12218515200.81225))

        // some distant date
        date = Date(timeIntervalSince1970: -210866774822)
        test(addField: .second, value: -1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -210866774823))
    }

    @Test func testAdd_boundaries() {
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(secondsFromGMT: 3600)!, locale: nil, firstWeekday: 3, minimumDaysInFirstWeek: 4, gregorianStartDate: nil)
        var date: Date
        func test(addField field: Calendar.Component, value: Int, to addingToDate: Date, wrap: Bool, expectedDate: Date, sourceLocation: SourceLocation = #_sourceLocation) {
            let components = DateComponents(component: field, value: value)!
            let result = gregorianCalendar.date(byAdding: components, to: addingToDate, wrappingComponents: wrap)!
            #expect(result == expectedDate, sourceLocation: sourceLocation)
        }

        date = Date(timeIntervalSince1970: 62135596800.0) // 3939-01-01
        test(addField: .era, value: 1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 62135596800.0))
        test(addField: .era, value: -1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 62135596800.0))
        test(addField: .year, value: 1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 62167132800.0))
        test(addField: .year, value: -1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 62104060800.0))
        test(addField: .yearForWeekOfYear, value: 1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 62167046400.0))
        test(addField: .yearForWeekOfYear, value: -1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 62103542400.0))
        test(addField: .month, value: 1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 62138275200.0))
        test(addField: .month, value: -1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 62164454400.0))
        test(addField: .day, value: 1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 62135683200.0))
        test(addField: .day, value: -1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 62138188800.0))
        test(addField: .hour, value: 1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 62135600400.0))
        test(addField: .hour, value: -1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 62135593200.0))
        test(addField: .minute, value: 1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 62135596860.0))
        test(addField: .minute, value: -1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 62135600340.0))
        test(addField: .second, value: 1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 62135596801.0))
        test(addField: .second, value: -1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 62135596859.0))
        test(addField: .weekday, value: 1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 62135683200.0))
        test(addField: .weekday, value: -1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 62135510400.0))
        test(addField: .weekdayOrdinal, value: 1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 62136201600.0))
        test(addField: .weekdayOrdinal, value: -1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 62138016000.0))
        test(addField: .weekOfYear, value: 1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 62136201600.0))
        test(addField: .weekOfYear, value: -1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 62134992000.0))
        test(addField: .weekOfMonth, value: 1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 62136201600.0))
        test(addField: .weekOfMonth, value: -1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 62138016000.0))
        test(addField: .nanosecond, value: 1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 62135596800.0))
        test(addField: .nanosecond, value: -1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: 62135596800.0))

        test(addField: .era, value: 1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 62135596800.0))
        test(addField: .era, value: -1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 62135596800.0))
        test(addField: .year, value: 1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 62167132800.0))
        test(addField: .year, value: -1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 62104060800.0))
        test(addField: .yearForWeekOfYear, value: 1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 62167046400.0))
        test(addField: .yearForWeekOfYear, value: -1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 62103542400.0))
        test(addField: .month, value: 1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 62138275200.0))
        test(addField: .month, value: -1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 62132918400.0))
        test(addField: .day, value: 1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 62135683200.0))
        test(addField: .day, value: -1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 62135510400.0))
        test(addField: .hour, value: 1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 62135600400.0))
        test(addField: .hour, value: -1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 62135593200.0))
        test(addField: .minute, value: 1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 62135596860.0))
        test(addField: .minute, value: -1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 62135596740.0))
        test(addField: .second, value: 1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 62135596801.0))
        test(addField: .second, value: -1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 62135596799.0))
        test(addField: .weekday, value: 1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 62135683200.0))
        test(addField: .weekday, value: -1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 62135510400.0))
        test(addField: .weekdayOrdinal, value: 1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 62136201600.0))
        test(addField: .weekdayOrdinal, value: -1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 62134992000.0))
        test(addField: .weekOfYear, value: 1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 62136201600.0))
        test(addField: .weekOfYear, value: -1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 62134992000.0))
        test(addField: .weekOfMonth, value: 1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 62136201600.0))
        test(addField: .weekOfMonth, value: -1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 62134992000.0))
        test(addField: .nanosecond, value: 1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 62135596800.0))
        test(addField: .nanosecond, value: -1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: 62135596800.0))

        date = Date(timeIntervalSince1970: -62135769600.0) // 0001-01-01
        test(addField: .era, value: 1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -62135769600.0))
        test(addField: .era, value: -1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -62135769600.0))
        test(addField: .year, value: 1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -62104233600.0))
        test(addField: .year, value: -1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -62135769600.0))
        test(addField: .yearForWeekOfYear, value: 1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -62103715200.0))
        test(addField: .yearForWeekOfYear, value: -1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -62103715200.0))
        test(addField: .month, value: 1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -62133091200.0))
        test(addField: .month, value: -1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -62106912000.0))
        test(addField: .day, value: 1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -62135683200.0))
        test(addField: .day, value: -1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -62133177600.0))
        test(addField: .hour, value: 1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -62135766000.0))
        test(addField: .hour, value: -1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -62135773200.0))
        test(addField: .minute, value: 1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -62135769540.0))
        test(addField: .minute, value: -1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -62135766060.0))
        test(addField: .second, value: 1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -62135769599.0))
        test(addField: .second, value: -1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -62135769541.0))
        test(addField: .weekday, value: 1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -62135683200.0))
        test(addField: .weekday, value: -1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -62135856000.0))
        test(addField: .weekdayOrdinal, value: 1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -62135164800.0))
        test(addField: .weekdayOrdinal, value: -1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -62133350400.0))
        test(addField: .weekOfYear, value: 1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -62167219200.0))
        test(addField: .weekOfYear, value: -1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -62136374400.0))
        test(addField: .weekOfMonth, value: 1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -62135164800.0))
        test(addField: .weekOfMonth, value: -1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -62133955200.0))
        test(addField: .nanosecond, value: 1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -62135769600.0))
        test(addField: .nanosecond, value: -1, to: date, wrap: true, expectedDate: Date(timeIntervalSince1970: -62135769600.0))

        test(addField: .era, value: 1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -62135769600.0))
        test(addField: .era, value: -1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -62135769600.0))
        test(addField: .year, value: 1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -62104233600.0))
        test(addField: .year, value: -1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -62167392000.0))
        test(addField: .yearForWeekOfYear, value: 1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -62103715200.0))
        test(addField: .yearForWeekOfYear, value: -1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -62167219200.0))
        test(addField: .month, value: 1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -62133091200.0))
        test(addField: .month, value: -1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -62138448000.0))
        test(addField: .day, value: 1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -62135683200.0))
        test(addField: .day, value: -1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -62135856000.0))
        test(addField: .hour, value: 1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -62135766000.0))
        test(addField: .hour, value: -1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -62135773200.0))
        test(addField: .minute, value: 1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -62135769540.0))
        test(addField: .minute, value: -1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -62135769660.0))
        test(addField: .second, value: 1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -62135769599.0))
        test(addField: .second, value: -1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -62135769601.0))
        test(addField: .weekday, value: 1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -62135683200.0))
        test(addField: .weekday, value: -1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -62135856000.0))
        test(addField: .weekdayOrdinal, value: 1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -62135164800.0))
        test(addField: .weekdayOrdinal, value: -1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -62136374400.0))
        test(addField: .weekOfYear, value: 1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -62135164800.0))
        test(addField: .weekOfYear, value: -1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -62136374400.0))
        test(addField: .weekOfMonth, value: 1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -62135164800.0))
        test(addField: .weekOfMonth, value: -1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -62136374400.0))
        test(addField: .nanosecond, value: 1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -62135769600.0))
        test(addField: .nanosecond, value: -1, to: date, wrap: false, expectedDate: Date(timeIntervalSince1970: -62135769600.0))
    }

    @Test func testAddDateComponents() {

        let s = Date.ISO8601FormatStyle(timeZone: TimeZone(secondsFromGMT: 3600)!)
        func testAdding(_ comp: DateComponents, to date: Date, wrap: Bool, expected: Date, sourceLocation: SourceLocation = #_sourceLocation) {
            let result = gregorianCalendar.date(byAdding: comp, to: date, wrappingComponents: wrap)!
            #expect(result == expected, "actual = \(result.timeIntervalSince1970), \(s.format(result))", sourceLocation: sourceLocation)
        }

        var gregorianCalendar: _CalendarGregorian
        gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(secondsFromGMT: 3600)!, locale: nil, firstWeekday: 3, minimumDaysInFirstWeek: 7, gregorianStartDate: nil)

        let march1_1996 = Date(timeIntervalSince1970: 825723300) // 1996-03-01 23:35:00 +0000
        testAdding(.init(day: -1, hour: 1 ), to: march1_1996, wrap: false, expected: Date(timeIntervalSince1970:825640500.0))
        testAdding(.init(month: -1, hour: 1 ), to: march1_1996, wrap: false, expected: Date(timeIntervalSince1970:823221300.0))
        testAdding(.init(month: -1, day: 30 ), to: march1_1996, wrap: false, expected: Date(timeIntervalSince1970:825809700.0))
        testAdding(.init(year: 4, day: -1 ), to: march1_1996, wrap: false, expected: Date(timeIntervalSince1970:951867300.0))
        testAdding(.init(day: -1, hour: 24 ), to: march1_1996, wrap: false, expected: Date(timeIntervalSince1970:825723300.0))
        testAdding(.init(day: -1, weekday: 1 ), to: march1_1996, wrap: false, expected: Date(timeIntervalSince1970:825723300.0))
        testAdding(.init(day: -7, weekOfYear: 1 ), to: march1_1996, wrap: false, expected: Date(timeIntervalSince1970:825723300.0))
        testAdding(.init(day: -7, weekOfMonth: 1 ), to: march1_1996, wrap: false, expected: Date(timeIntervalSince1970:825723300.0))
        testAdding(.init(day: -7, weekOfMonth: 1, weekOfYear: 1 ), to: march1_1996, wrap: false, expected: Date(timeIntervalSince1970:826328100.0))

        testAdding(.init(day: -1, hour: 1 ), to: march1_1996, wrap: true, expected: Date(timeIntervalSince1970:825640500.0))
        testAdding(.init(month: -1, hour: 1 ), to: march1_1996, wrap: true, expected: Date(timeIntervalSince1970:823221300.0))
        testAdding(.init(month: -1, day: 30 ), to: march1_1996, wrap: true, expected: Date(timeIntervalSince1970:823304100.0))
        testAdding(.init(year: 4, day: -1 ), to: march1_1996, wrap: true, expected: Date(timeIntervalSince1970:951867300.0))
        testAdding(.init(day: -1, hour: 24 ), to: march1_1996, wrap: true, expected: Date(timeIntervalSince1970:825636900.0))
        testAdding(.init(day: -1, weekday: 1), to: march1_1996, wrap: true, expected: march1_1996)
        testAdding(.init(day: -7, weekOfYear: 1), to: march1_1996, wrap: true, expected: march1_1996)
        testAdding(.init(day: -7, weekOfMonth: 1), to: march1_1996, wrap: true, expected: march1_1996)
        testAdding(.init(day: -7, weekOfMonth: 1, weekOfYear: 1 ), to: march1_1996, wrap: true, expected: Date(timeIntervalSince1970:826328100.0))

        let oct24_1582 = Date(timeIntervalSince1970: -12218515200.0) // Expect: 1582-10-24T00:00:00Z
        testAdding(.init(day: -1, hour: 1), to: oct24_1582, wrap: false, expected: Date(timeIntervalSince1970:-12218598000.0))
        testAdding(.init(month: -1, hour: 1), to: oct24_1582, wrap: false, expected: Date(timeIntervalSince1970:-12220239600.0))
        testAdding(.init(month: -1, day: 30), to: oct24_1582, wrap: false, expected: Date(timeIntervalSince1970:-12217651200.0))
        testAdding(.init(year: 4, day: -1), to: oct24_1582, wrap: false, expected: Date(timeIntervalSince1970:-12092371200.0))
        testAdding(.init(day: -1, hour: 24), to: oct24_1582, wrap: false, expected: Date(timeIntervalSince1970:-12218515200.0))
        testAdding(.init(day: -1, weekday: 1), to: oct24_1582, wrap: false, expected: Date(timeIntervalSince1970:-12218515200.0))
        testAdding(.init(day: -7, weekOfYear: 1), to: oct24_1582, wrap: false, expected: Date(timeIntervalSince1970:-12218515200.0))
        testAdding(.init(day: -7, weekOfMonth: 1), to: oct24_1582, wrap: false, expected: Date(timeIntervalSince1970:-12218515200.0))
        testAdding(.init(day: -7, weekOfMonth: 2), to: oct24_1582, wrap: false, expected: Date(timeIntervalSince1970:-12217910400.0))
        testAdding(.init(day: -7, weekOfYear: 2), to: oct24_1582, wrap: false, expected: Date(timeIntervalSince1970:-12217910400.0))

        testAdding(.init(day: -1, hour: 1), to: oct24_1582, wrap: true, expected: Date(timeIntervalSince1970:-12218598000.0))
        testAdding(.init(month: -1, hour: 1), to: oct24_1582, wrap: true, expected: Date(timeIntervalSince1970:-12220239600.0))
        testAdding(.init(month: -1, day: 30), to: oct24_1582, wrap: true, expected: Date(timeIntervalSince1970:-12220243200.0))
        testAdding(.init(year: 4, day: -1), to: oct24_1582, wrap: true, expected: Date(timeIntervalSince1970:-12092371200.0))
        testAdding(.init(day: -1, hour: 24), to: oct24_1582, wrap: true, expected: Date(timeIntervalSince1970:-12218601600.0))
        testAdding(.init(day: -1, weekday: 1), to: oct24_1582, wrap: true, expected: Date(timeIntervalSince1970:-12218515200.0))
        testAdding(.init(day: -7, weekOfYear: 1), to: oct24_1582, wrap: true, expected: Date(timeIntervalSince1970:-12218515200.0))
        testAdding(.init(day: -7, weekOfMonth: 1), to: oct24_1582, wrap: true, expected: Date(timeIntervalSince1970:-12218515200.0))

        testAdding(.init(weekOfMonth: 1), to: oct24_1582, wrap: true, expected: Date(timeIntervalSince1970:-12217910400.0)) // Expect: 1582-10-31 00:00:00Z
        testAdding(.init(weekOfYear: 1), to: oct24_1582, wrap: true, expected: Date(timeIntervalSince1970:-12217910400.0))
        testAdding(.init(weekOfYear: 2), to: oct24_1582, wrap: true, expected: Date(timeIntervalSince1970:-12217305600.0)) // Expect: 1582-11-07 00:00:00
        testAdding(.init(day: -7, weekOfMonth: 2), to: oct24_1582, wrap: true, expected: Date(timeIntervalSince1970:-12217910400.0)) // Expect: 1582-10-31 00:00:00 +0000

        testAdding(.init(day: -7, weekOfYear: 2), to: oct24_1582, wrap: true, expected: Date(timeIntervalSince1970:-12215318400.0)) // expect: 1582-11-30 00:00:00 - adding 2 weeks is 1582-11-07, adding -7 days wraps around to 1582-11-30

        do {
            gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: .gmt, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)

            let date = Date(timeIntervalSinceReferenceDate: 2557249259.5) // 2082-1-13 19:00:59.5 +0000
            testAdding(.init(day: 1), to: date, wrap: true, expected: Date(timeIntervalSinceReferenceDate: 2557335659.5))

            let date2 = Date(timeIntervalSinceReferenceDate: 0)         // 2000-12-31 16:00:00 PT
            testAdding(.init(month: 2), to: date2, wrap: false, expected: Date(timeIntervalSince1970: 983404800)) // 2001-03-01 00:00:00 UTC, 2001-02-28 16:00:00 PT
        }
    }

    // MARK: - Ordinality

    // This test requires 64-bit integers
    #if _pointerBitWidth(_64)
    @Test func testOrdinality() {
        let cal = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(secondsFromGMT: 3600)!, locale: nil, firstWeekday: 5, minimumDaysInFirstWeek: 4, gregorianStartDate: nil)

        func test(_ small: Calendar.Component, in large: Calendar.Component, for date: Date, expected: Int?, sourceLocation: SourceLocation = #_sourceLocation) {
            let result = cal.ordinality(of: small, in: large, for: date)
            #expect(result == expected,  "small: \(small), large: \(large)", sourceLocation: sourceLocation)
        }

        var date: Date
        date = Date(timeIntervalSince1970: 852045787.0) // 1996-12-31T15:23:07Z
        test(.year, in: .era, for: date, expected: 1996)
        test(.month, in: .era, for: date, expected: 23952)
        test(.day, in: .era, for: date, expected: 729024)
        test(.weekday, in: .era, for: date, expected: 104147)
        test(.weekdayOrdinal, in: .era, for: date, expected: 104147)
        test(.quarter, in: .era, for: date, expected: 7984)
        test(.weekOfMonth, in: .era, for: date, expected: 104146)
        test(.month, in: .year, for: date, expected: 12)
        test(.day, in: .year, for: date, expected: 366)
        test(.weekday, in: .year, for: date, expected: 53)
        test(.weekdayOrdinal, in: .year, for: date, expected: 53)
        test(.quarter, in: .year, for: date, expected: 4)
        test(.weekOfYear, in: .year, for: date, expected: 52)
        test(.day, in: .month, for: date, expected: 31)
        test(.weekday, in: .month, for: date, expected: 5)
        test(.weekdayOrdinal, in: .month, for: date, expected: 5)
        test(.weekOfMonth, in: .month, for: date, expected: 5)
        test(.day, in: .weekOfMonth, for: date, expected: 6)
        test(.weekday, in: .weekOfMonth, for: date, expected: 6)
        test(.month, in: .quarter, for: date, expected: 3)
        test(.day, in: .quarter, for: date, expected: 92)
        test(.weekday, in: .quarter, for: date, expected: 14)
        test(.weekdayOrdinal, in: .quarter, for: date, expected: 14)
        test(.weekOfMonth, in: .quarter, for: date, expected: 13)
        test(.weekOfYear, in: .quarter, for: date, expected: 13)
        test(.day, in: .weekOfYear, for: date, expected: 6)
        test(.weekday, in: .weekOfYear, for: date, expected: 6)
        test(.minute, in: .hour, for: date, expected: 24)
        test(.second, in: .hour, for: date, expected: 1388)
        test(.nanosecond, in: .hour, for: date, expected: 1387000000001)
        test(.second, in: .minute, for: date, expected: 8)
        test(.nanosecond, in: .minute, for: date, expected: 7000000001)
        test(.nanosecond, in: .second, for: date, expected: 1)

        date = Date(timeIntervalSince1970: 828838987.0) // 1996-04-07T01:03:07Z
        test(.day, in: .weekOfMonth, for: date, expected: 4)
        test(.weekday, in: .weekOfMonth, for: date, expected: 4)
        test(.day, in: .weekOfYear, for: date, expected: 4)
        test(.weekday, in: .weekOfYear, for: date, expected: 4)
        test(.year, in: .era, for: date, expected: 1996)
        test(.month, in: .era, for: date, expected: 23944)
        test(.day, in: .era, for: date, expected: 728756)
        test(.weekday, in: .era, for: date, expected: 104108)
        test(.weekdayOrdinal, in: .era, for: date, expected: 104108)
        test(.quarter, in: .era, for: date, expected: 7982)
        test(.month, in: .year, for: date, expected: 4)
        test(.day, in: .year, for: date, expected: 98)
        test(.weekday, in: .year, for: date, expected: 14)
        test(.weekdayOrdinal, in: .year, for: date, expected: 14)
        test(.quarter, in: .year, for: date, expected: 2)
        test(.weekOfYear, in: .year, for: date, expected: 14)
        test(.day, in: .month, for: date, expected: 7)
        test(.weekday, in: .month, for: date, expected: 1)
        test(.weekdayOrdinal, in: .month, for: date, expected: 1)
        test(.weekOfMonth, in: .month, for: date, expected: 1)
        test(.month, in: .quarter, for: date, expected: 1)
        test(.day, in: .quarter, for: date, expected: 7)
        test(.weekday, in: .quarter, for: date, expected: 1)
        test(.weekdayOrdinal, in: .quarter, for: date, expected: 1)
        test(.weekOfMonth, in: .quarter, for: date, expected: 1)
        test(.weekOfYear, in: .quarter, for: date, expected: 1)
        test(.minute, in: .hour, for: date, expected: 4)
        test(.second, in: .hour, for: date, expected: 188)
        test(.nanosecond, in: .hour, for: date, expected: 187000000001)
        test(.second, in: .minute, for: date, expected: 8)
        test(.nanosecond, in: .minute, for: date, expected: 7000000001)
        test(.nanosecond, in: .second, for: date, expected: 1)


        date = Date(timeIntervalSince1970: -62135765813.0) // 0001-01-01T01:03:07Z
        test(.month, in: .year, for: date, expected: 1)
        test(.day, in: .year, for: date, expected: 1)
        test(.weekday, in: .year, for: date, expected: 1)
        test(.weekdayOrdinal, in: .year, for: date, expected: 1)
        test(.quarter, in: .year, for: date, expected: 1)
        test(.weekOfYear, in: .year, for: date, expected: 1)
        test(.day, in: .weekOfMonth, for: date, expected: 3)
        test(.weekday, in: .weekOfMonth, for: date, expected: 3)
        test(.day, in: .month, for: date, expected: 1)
        test(.weekday, in: .month, for: date, expected: 1)
        test(.weekdayOrdinal, in: .month, for: date, expected: 1)
        test(.weekOfMonth, in: .month, for: date, expected: 1)
        test(.day, in: .weekOfYear, for: date, expected: 3)
        test(.weekday, in: .weekOfYear, for: date, expected: 3)
        test(.month, in: .quarter, for: date, expected: 1)
        test(.day, in: .quarter, for: date, expected: 1)
        test(.weekday, in: .quarter, for: date, expected: 1)
        test(.weekdayOrdinal, in: .quarter, for: date, expected: 1)
        test(.weekOfMonth, in: .quarter, for: date, expected: 1)
        test(.weekOfYear, in: .quarter, for: date, expected: 1)
        test(.year, in: .era, for: date, expected: 1)
        test(.month, in: .era, for: date, expected: 1672389)
        test(.day, in: .era, for: date, expected: 50903315)
        test(.weekday, in: .era, for: date, expected: 7271902)
        test(.weekdayOrdinal, in: .era, for: date, expected: 7271902)
        test(.quarter, in: .era, for: date, expected: 1)
        test(.weekOfMonth, in: .era, for: date, expected: 7271903)
        test(.minute, in: .hour, for: date, expected: 4)
        test(.second, in: .hour, for: date, expected: 188)
        test(.nanosecond, in: .hour, for: date, expected: 187000000001)
        test(.second, in: .minute, for: date, expected: 8)
        test(.nanosecond, in: .minute, for: date, expected: 7000000001)
        test(.nanosecond, in: .second, for: date, expected: 1)
    }
    #endif

    @Test func testStartOf() {
        let firstWeekday = 2
        let minimumDaysInFirstWeek = 4
        let timeZone = TimeZone(secondsFromGMT: -3600 * 8)!
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: nil)
        func test(_ unit: Calendar.Component, at date: Date, expected: Date, sourceLocation: SourceLocation = #_sourceLocation) {
            let new = gregorianCalendar.start(of: unit, at: date)!
            #expect(new == expected, sourceLocation: sourceLocation)
        }

        var date: Date
        date = Date(timeIntervalSince1970: 820483200.0) // 1996-01-01T00:00:00-0800 (1996-01-01T08:00:00Z)
        test(.hour, at: date, expected: date)
        test(.day, at: date, expected: date)
        test(.month, at: date, expected: date)
        test(.year, at: date, expected: date)
        test(.yearForWeekOfYear, at: date, expected: date)
        test(.weekOfYear, at: date, expected: date)

        date = Date(timeIntervalSince1970: 845121787.0) // 1996-10-12T05:03:07-0700 (1996-10-12T12:03:07Z)
        test(.second, at: date, expected: Date(timeIntervalSince1970: 845121787.0)) // expect: 1996-10-12 12:03:07 +0000
        test(.minute, at: date, expected: Date(timeIntervalSince1970: 845121780.0)) // expect: 1996-10-12 12:03:00 +0000
        test(.hour, at: date, expected: Date(timeIntervalSince1970: 845121600.0)) // expect: 1996-10-12 12:00:00 +0000
        test(.day, at: date, expected: Date(timeIntervalSince1970: 845107200.0)) // expect: 1996-10-12 08:00:00 +0000
        test(.month, at: date, expected: Date(timeIntervalSince1970: 844156800.0)) // expect: 1996-10-01 08:00:00 +0000
        test(.year, at: date, expected: Date(timeIntervalSince1970: 820483200.0)) // expect: 1996-01-01 08:00:00 +0000
        test(.yearForWeekOfYear, at: date, expected: Date(timeIntervalSince1970: 820483200.0)) // expect: 1996-01-01 08:00:00 +0000
        test(.weekOfYear, at: date, expected: Date(timeIntervalSince1970: 844675200.0)) // expect: 1996-10-07 08:00:00 +0000
        test(.weekOfMonth, at: date, expected: Date(timeIntervalSince1970: 844675200.0)) // expect: 1996-10-07 08:00:00 +0000
        test(.weekday, at: date, expected: Date(timeIntervalSince1970: 845107200.0)) // expect: 1996-10-12 08:00:00 +0000
        test(.quarter, at: date, expected: Date(timeIntervalSince1970: 844156800.0)) // expect: 1996-10-01 08:00:00 +0000
    }

    // MARK: - Weekend

    @Test func testIsDateInWeekend() {
        let c = _CalendarGregorian(identifier: .gregorian, timeZone: .gmt, locale: nil, firstWeekday: 1, minimumDaysInFirstWeek: 1, gregorianStartDate: nil)

        let sat0000_mon0000 = WeekendRange(onsetTime: 0, ceaseTime: 0, start: 7, end: 2) // Sat 00:00:00 ..< Mon 00:00:00
        let sat1200_sun1200 = WeekendRange(onsetTime: 43200, ceaseTime: 43200, start: 7, end: 1) // Sat 12:00:00 ..< Sun 12:00:00
        let sat_sun = WeekendRange(onsetTime: 0, ceaseTime: 86400, start: 7, end: 1) // Sat 00:00:00 ... Sun 23:59:59
        let mon = WeekendRange(onsetTime: 0, ceaseTime: 86400, start: 2, end: 2)
        let sunPM = WeekendRange(onsetTime: 43200, ceaseTime: 86400, start: 1, end: 1) // Sun 12:00:00 ... Sun 23:59:59
        let mon_tue = WeekendRange(onsetTime: 0, ceaseTime: 86400, start: 2, end: 3) // Mon 00:00:00 ... Tue 23:59:59

        var date = Date(timeIntervalSince1970: 846320587) // 1996-10-26, Sat 09:03:07
        #expect(c.isDateInWeekend(date, weekendRange: sat0000_mon0000))
        #expect(!c.isDateInWeekend(date, weekendRange: sat1200_sun1200))
        #expect(c.isDateInWeekend(date, weekendRange: sat_sun))

        date = Date(timeIntervalSince1970: 846406987.0) // 1996-10-27, Sun 09:03:07
        #expect(c.isDateInWeekend(date, weekendRange: sat0000_mon0000))
        #expect(c.isDateInWeekend(date, weekendRange: sat1200_sun1200))
        #expect(c.isDateInWeekend(date, weekendRange: sat_sun))
        #expect(!c.isDateInWeekend(date, weekendRange: sunPM))
        #expect(!c.isDateInWeekend(date, weekendRange: mon))
        #expect(!c.isDateInWeekend(date, weekendRange: mon_tue))

        date = Date(timeIntervalSince1970: 846450187) // 1996-10-27, Sun 19:03:07
        #expect(c.isDateInWeekend(date, weekendRange: sat0000_mon0000))
        #expect(!c.isDateInWeekend(date, weekendRange: sat1200_sun1200))
        #expect(c.isDateInWeekend(date, weekendRange: sat_sun))
        #expect(c.isDateInWeekend(date, weekendRange: sunPM))
        #expect(!c.isDateInWeekend(date, weekendRange: mon))
        #expect(!c.isDateInWeekend(date, weekendRange: mon_tue))

        date = Date(timeIntervalSince1970: 846536587) // 1996-10-28, Mon 19:03:07
        #expect(!c.isDateInWeekend(date, weekendRange: sat0000_mon0000))
        #expect(!c.isDateInWeekend(date, weekendRange: sat1200_sun1200))
        #expect(!c.isDateInWeekend(date, weekendRange: sat_sun))
        #expect(!c.isDateInWeekend(date, weekendRange: sunPM))
        #expect(c.isDateInWeekend(date, weekendRange: mon))
        #expect(c.isDateInWeekend(date, weekendRange: mon_tue))
    }

    @Test func testIsDateInWeekend_wholeDays() {
        let c = _CalendarGregorian(identifier: .gregorian, timeZone: .gmt, locale: nil, firstWeekday: 1, minimumDaysInFirstWeek: 1, gregorianStartDate: nil)

        let sat_mon = WeekendRange(start: 7, end: 2)
        let sat_sun = WeekendRange(start: 7, end: 1)
        let mon = WeekendRange(start: 2, end: 2)
        let sun = WeekendRange(start: 1, end: 1)
        let mon_tue = WeekendRange(start: 2, end: 3)

        var date = Date(timeIntervalSince1970: 846320587) // 1996-10-26, Sat 09:03:07
        #expect(c.isDateInWeekend(date, weekendRange: sat_mon))
        #expect(c.isDateInWeekend(date, weekendRange: sat_sun))
        #expect(!c.isDateInWeekend(date, weekendRange: sun))

        date = Date(timeIntervalSince1970: 846406987.0) // 1996-10-27, Sun 09:03:07
        #expect(c.isDateInWeekend(date, weekendRange: sat_mon))
        #expect(c.isDateInWeekend(date, weekendRange: sat_sun))
        #expect(c.isDateInWeekend(date, weekendRange: sun))
        #expect(!c.isDateInWeekend(date, weekendRange: mon))
        #expect(!c.isDateInWeekend(date, weekendRange: mon_tue))

        date = Date(timeIntervalSince1970: 846450187) // 1996-10-27, Sun 19:03:07
        #expect(c.isDateInWeekend(date, weekendRange: sat_mon))
        #expect(c.isDateInWeekend(date, weekendRange: sat_sun))
        #expect(c.isDateInWeekend(date, weekendRange: sun))
        #expect(!c.isDateInWeekend(date, weekendRange: mon))
        #expect(!c.isDateInWeekend(date, weekendRange: mon_tue))

        date = Date(timeIntervalSince1970: 846536587) // 1996-10-28, Mon 19:03:07
        #expect(c.isDateInWeekend(date, weekendRange: sat_mon))
        #expect(!c.isDateInWeekend(date, weekendRange: sat_sun))
        #expect(!c.isDateInWeekend(date, weekendRange: sun))
        #expect(c.isDateInWeekend(date, weekendRange: mon))
        #expect(c.isDateInWeekend(date, weekendRange: mon_tue))
    }

    // MARK: - DateInterval

    @Test func testDateInterval() {
        let calendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(secondsFromGMT: -28800)!, locale: nil, firstWeekday: 3, minimumDaysInFirstWeek: 5, gregorianStartDate: nil)

        func test(_ c: Calendar.Component, _ date: Date, expectedStart start: Date?, end: Date?, sourceLocation: SourceLocation = #_sourceLocation) {
            let new = calendar.dateInterval(of: c, for: date)
            let new_start = new?.start
            let new_end = new?.end

            #expect(new_start == start, "interval start did not match", sourceLocation: sourceLocation)
            #expect(new_end == end, "interval end did not match", sourceLocation: sourceLocation)
        }

        var date: Date
        date = Date(timeIntervalSince1970: 820454400.0) // 1995-12-31T16:00:00-0800 (1996-01-01T00:00:00Z)
        test(.era, date, expectedStart: Date(timeIntervalSince1970: -62135596800.0), end: Date(timeIntervalSince1970: 4335910914304.0))
        test(.year, date, expectedStart: Date(timeIntervalSince1970: 788947200.0), end: Date(timeIntervalSince1970: 820483200.0))
        test(.month, date, expectedStart: Date(timeIntervalSince1970: 817804800.0), end: Date(timeIntervalSince1970: 820483200.0))
        test(.day, date, expectedStart: Date(timeIntervalSince1970: 820396800.0), end: Date(timeIntervalSince1970: 820483200.0))
        test(.hour, date, expectedStart: Date(timeIntervalSince1970: 820454400.0), end: Date(timeIntervalSince1970: 820458000.0))
        test(.minute, date, expectedStart: Date(timeIntervalSince1970: 820454400.0), end: Date(timeIntervalSince1970: 820454460.0))
        test(.second, date, expectedStart: Date(timeIntervalSince1970: 820454400.0), end: Date(timeIntervalSince1970: 820454401.0))
        test(.nanosecond, date, expectedStart: Date(timeIntervalSince1970: 820454400.0), end: Date(timeIntervalSince1970: 820454400.0))
        test(.weekday, date, expectedStart: Date(timeIntervalSince1970: 820396800.0), end: Date(timeIntervalSince1970: 820483200.0))
        test(.weekdayOrdinal, date, expectedStart: Date(timeIntervalSince1970: 820396800.0), end: Date(timeIntervalSince1970: 820483200.0))
        test(.quarter, date, expectedStart: Date(timeIntervalSince1970: 812534400.0), end: Date(timeIntervalSince1970: 820483200.0))
        test(.weekOfMonth, date, expectedStart: Date(timeIntervalSince1970: 819964800.0), end: Date(timeIntervalSince1970: 820569600.0))
        test(.weekOfYear, date, expectedStart: Date(timeIntervalSince1970: 819964800.0), end: Date(timeIntervalSince1970: 820569600.0))
        test(.yearForWeekOfYear, date, expectedStart: Date(timeIntervalSince1970: 789120000.0), end: Date(timeIntervalSince1970: 820569600.0))

        date = Date(timeIntervalSince1970: 857174400.0) // 1997-02-28T16:00:00-0800 (1997-03-01T00:00:00Z)
        test(.era, date, expectedStart: Date(timeIntervalSince1970: -62135596800.0), end: Date(timeIntervalSince1970: 4335910914304.0))
        test(.year, date, expectedStart: Date(timeIntervalSince1970: 852105600.0), end: Date(timeIntervalSince1970: 883641600.0))
        test(.month, date, expectedStart: Date(timeIntervalSince1970: 854784000.0), end: Date(timeIntervalSince1970: 857203200.0))
        test(.day, date, expectedStart: Date(timeIntervalSince1970: 857116800.0), end: Date(timeIntervalSince1970: 857203200.0))
        test(.hour, date, expectedStart: Date(timeIntervalSince1970: 857174400.0), end: Date(timeIntervalSince1970: 857178000.0))
        test(.minute, date, expectedStart: Date(timeIntervalSince1970: 857174400.0), end: Date(timeIntervalSince1970: 857174460.0))
        test(.second, date, expectedStart: Date(timeIntervalSince1970: 857174400.0), end: Date(timeIntervalSince1970: 857174401.0))
        test(.weekday, date, expectedStart: Date(timeIntervalSince1970: 857116800.0), end: Date(timeIntervalSince1970: 857203200.0))
        test(.weekdayOrdinal, date, expectedStart: Date(timeIntervalSince1970: 857116800.0), end: Date(timeIntervalSince1970: 857203200.0))
        test(.quarter, date, expectedStart: Date(timeIntervalSince1970: 852105600.0), end: Date(timeIntervalSince1970: 859881600.0))
        test(.weekOfMonth, date, expectedStart: Date(timeIntervalSince1970: 856857600.0), end: Date(timeIntervalSince1970: 857462400.0))
        test(.weekOfYear, date, expectedStart: Date(timeIntervalSince1970: 856857600.0), end: Date(timeIntervalSince1970: 857462400.0))
        test(.yearForWeekOfYear, date, expectedStart: Date(timeIntervalSince1970: 852019200.0), end: Date(timeIntervalSince1970: 883468800.0))

        date = Date(timeIntervalSince1970: -62135769600.0) // 0001-12-31T16:00:00-0800 (0001-01-01T00:00:00Z)
        test(.era, date, expectedStart: Date(timeIntervalSince1970: -4460182107904.0), end: Date(timeIntervalSince1970: -62135596800.0))
        test(.year, date, expectedStart: Date(timeIntervalSince1970: -62167363200.0), end: Date(timeIntervalSince1970: -62135740800.0))
        test(.month, date, expectedStart: Date(timeIntervalSince1970: -62138419200.0), end: Date(timeIntervalSince1970: -62135740800.0))
        test(.day, date, expectedStart: Date(timeIntervalSince1970: -62135827200.0), end: Date(timeIntervalSince1970: -62135740800.0))
        test(.hour, date, expectedStart: Date(timeIntervalSince1970: -62135769600.0), end: Date(timeIntervalSince1970: -62135766000.0))
        test(.minute, date, expectedStart: Date(timeIntervalSince1970: -62135769600.0), end: Date(timeIntervalSince1970: -62135769540.0))
        test(.second, date, expectedStart: Date(timeIntervalSince1970: -62135769600.0), end: Date(timeIntervalSince1970: -62135769599.0))
        test(.nanosecond, date, expectedStart: Date(timeIntervalSince1970: -62135769600.00001), end: Date(timeIntervalSince1970: -62135769600.00001))
        test(.weekday, date, expectedStart: Date(timeIntervalSince1970: -62135827200.0), end: Date(timeIntervalSince1970: -62135740800.0))
        test(.weekdayOrdinal, date, expectedStart: Date(timeIntervalSince1970: -62135827200.0), end: Date(timeIntervalSince1970: -62135740800.0))
        test(.quarter, date, expectedStart: Date(timeIntervalSince1970: -62143689600.0), end: Date(timeIntervalSince1970: -62135740800.0))
        test(.weekOfMonth, date, expectedStart: Date(timeIntervalSince1970: -62136086400.0), end: Date(timeIntervalSince1970: -62135481600.0))
        test(.weekOfYear, date, expectedStart: Date(timeIntervalSince1970: -62136086400.0), end: Date(timeIntervalSince1970: -62135481600.0))
        test(.yearForWeekOfYear, date, expectedStart: nil, end: nil)
    }

    @Test func testDateInterval_DST() {
        let calendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(identifier: "America/Los_Angeles")!, locale: nil, firstWeekday: 3, minimumDaysInFirstWeek: 5, gregorianStartDate: nil)
        func test(_ c: Calendar.Component, _ date: Date, expectedStart start: Date, end: Date, sourceLocation: SourceLocation = #_sourceLocation) {
            let new = calendar.dateInterval(of: c, for: date)!
            let new_start = new.start
            let new_end = new.end
            let delta = 0.005
            #expect(abs(new_start.timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate) <= delta, sourceLocation: sourceLocation)
            #expect(abs(new_end.timeIntervalSinceReferenceDate - end.timeIntervalSinceReferenceDate) <= delta, sourceLocation: sourceLocation)
        }
        var date: Date
        date = Date(timeIntervalSince1970: 828867787.0) // 1996-04-07T01:03:07-0800 (1996-04-07T09:03:07Z)
        test(.era, date, expectedStart: Date(timeIntervalSince1970: -62135596800.0), end: Date(timeIntervalSince1970: 4335910914304.0))
        test(.year, date, expectedStart: Date(timeIntervalSince1970: 820483200.0), end: Date(timeIntervalSince1970: 852105600.0))
        test(.month, date, expectedStart: Date(timeIntervalSince1970: 828345600.0), end: Date(timeIntervalSince1970: 830934000.0))
        test(.day, date, expectedStart: Date(timeIntervalSince1970: 828864000.0), end: Date(timeIntervalSince1970: 828946800.0))
        test(.hour, date, expectedStart: Date(timeIntervalSince1970: 828867600.0), end: Date(timeIntervalSince1970: 828871200.0))
        test(.minute, date, expectedStart: Date(timeIntervalSince1970: 828867780.0), end: Date(timeIntervalSince1970: 828867840.0))
        test(.second, date, expectedStart: Date(timeIntervalSince1970: 828867787.0), end: Date(timeIntervalSince1970: 828867788.0))
        test(.nanosecond, date, expectedStart: Date(timeIntervalSince1970: 828867787.0), end: Date(timeIntervalSince1970: 828867787.0))
        test(.weekday, date, expectedStart: Date(timeIntervalSince1970: 828864000.0), end: Date(timeIntervalSince1970: 828946800.0))
        test(.weekdayOrdinal, date, expectedStart: Date(timeIntervalSince1970: 828864000.0), end: Date(timeIntervalSince1970: 828946800.0))
        test(.quarter, date, expectedStart: Date(timeIntervalSince1970: 828345600.0), end: Date(timeIntervalSince1970: 836204400.0))
        test(.weekOfMonth, date, expectedStart: Date(timeIntervalSince1970: 828432000.0), end: Date(timeIntervalSince1970: 829033200.0))
        test(.weekOfYear, date, expectedStart: Date(timeIntervalSince1970: 828432000.0), end: Date(timeIntervalSince1970: 829033200.0))
        test(.yearForWeekOfYear, date, expectedStart: Date(timeIntervalSince1970: 820569600.0), end: Date(timeIntervalSince1970: 852019200.0))

        date = Date(timeIntervalSince1970: 828871387.0) // 1996-04-07T03:03:07-0700 (1996-04-07T10:03:07Z)
        test(.era, date, expectedStart: Date(timeIntervalSince1970: -62135596800.0), end: Date(timeIntervalSince1970: 4335910914304.0))
        test(.year, date, expectedStart: Date(timeIntervalSince1970: 820483200.0), end: Date(timeIntervalSince1970: 852105600.0))
        test(.month, date, expectedStart: Date(timeIntervalSince1970: 828345600.0), end: Date(timeIntervalSince1970: 830934000.0))
        test(.day, date, expectedStart: Date(timeIntervalSince1970: 828864000.0), end: Date(timeIntervalSince1970: 828946800.0))
        test(.hour, date, expectedStart: Date(timeIntervalSince1970: 828871200.0), end: Date(timeIntervalSince1970: 828874800.0))
        test(.minute, date, expectedStart: Date(timeIntervalSince1970: 828871380.0), end: Date(timeIntervalSince1970: 828871440.0))
        test(.second, date, expectedStart: Date(timeIntervalSince1970: 828871387.0), end: Date(timeIntervalSince1970: 828871388.0))
        test(.nanosecond, date, expectedStart: Date(timeIntervalSince1970: 828871387.0), end: Date(timeIntervalSince1970: 828871387.0))
        test(.weekday, date, expectedStart: Date(timeIntervalSince1970: 828864000.0), end: Date(timeIntervalSince1970: 828946800.0))
        test(.weekdayOrdinal, date, expectedStart: Date(timeIntervalSince1970: 828864000.0), end: Date(timeIntervalSince1970: 828946800.0))
        test(.quarter, date, expectedStart: Date(timeIntervalSince1970: 828345600.0), end: Date(timeIntervalSince1970: 836204400.0))
        test(.weekOfMonth, date, expectedStart: Date(timeIntervalSince1970: 828432000.0), end: Date(timeIntervalSince1970: 829033200.0))
        test(.weekOfYear, date, expectedStart: Date(timeIntervalSince1970: 828432000.0), end: Date(timeIntervalSince1970: 829033200.0))
        test(.yearForWeekOfYear, date, expectedStart: Date(timeIntervalSince1970: 820569600.0), end: Date(timeIntervalSince1970: 852019200.0))

        date = Date(timeIntervalSince1970: 828874987.0) // 1996-04-07T04:03:07-0700 (1996-04-07T11:03:07Z)
        test(.era, date, expectedStart: Date(timeIntervalSince1970: -62135596800.0), end: Date(timeIntervalSince1970: 4335910914304.0))
        test(.year, date, expectedStart: Date(timeIntervalSince1970: 820483200.0), end: Date(timeIntervalSince1970: 852105600.0))
        test(.month, date, expectedStart: Date(timeIntervalSince1970: 828345600.0), end: Date(timeIntervalSince1970: 830934000.0))
        test(.day, date, expectedStart: Date(timeIntervalSince1970: 828864000.0), end: Date(timeIntervalSince1970: 828946800.0))
        test(.hour, date, expectedStart: Date(timeIntervalSince1970: 828874800.0), end: Date(timeIntervalSince1970: 828878400.0))
        test(.minute, date, expectedStart: Date(timeIntervalSince1970: 828874980.0), end: Date(timeIntervalSince1970: 828875040.0))
        test(.second, date, expectedStart: Date(timeIntervalSince1970: 828874987.0), end: Date(timeIntervalSince1970: 828874988.0))
        test(.nanosecond, date, expectedStart: Date(timeIntervalSince1970: 828874987.0), end: Date(timeIntervalSince1970: 828874987.0))
        test(.weekday, date, expectedStart: Date(timeIntervalSince1970: 828864000.0), end: Date(timeIntervalSince1970: 828946800.0))
        test(.weekdayOrdinal, date, expectedStart: Date(timeIntervalSince1970: 828864000.0), end: Date(timeIntervalSince1970: 828946800.0))
        test(.quarter, date, expectedStart: Date(timeIntervalSince1970: 828345600.0), end: Date(timeIntervalSince1970: 836204400.0))
        test(.weekOfMonth, date, expectedStart: Date(timeIntervalSince1970: 828432000.0), end: Date(timeIntervalSince1970: 829033200.0))
        test(.weekOfYear, date, expectedStart: Date(timeIntervalSince1970: 828432000.0), end: Date(timeIntervalSince1970: 829033200.0))
        test(.yearForWeekOfYear, date, expectedStart: Date(timeIntervalSince1970: 820569600.0), end: Date(timeIntervalSince1970: 852019200.0))

        date = Date(timeIntervalSince1970: 846406987.0) // 1996-10-27T01:03:07-0800 (1996-10-27T09:03:07Z)
        test(.era, date, expectedStart: Date(timeIntervalSince1970: -62135596800.0), end: Date(timeIntervalSince1970: 4335910914304.0))
        test(.year, date, expectedStart: Date(timeIntervalSince1970: 820483200.0), end: Date(timeIntervalSince1970: 852105600.0))
        test(.month, date, expectedStart: Date(timeIntervalSince1970: 844153200.0), end: Date(timeIntervalSince1970: 846835200.0))
        test(.day, date, expectedStart: Date(timeIntervalSince1970: 846399600.0), end: Date(timeIntervalSince1970: 846489600.0))
        test(.hour, date, expectedStart: Date(timeIntervalSince1970: 846406800.0), end: Date(timeIntervalSince1970: 846410400.0))
        test(.minute, date, expectedStart: Date(timeIntervalSince1970: 846406980.0), end: Date(timeIntervalSince1970: 846407040.0))
        test(.second, date, expectedStart: Date(timeIntervalSince1970: 846406987.0), end: Date(timeIntervalSince1970: 846406988.0))
        test(.nanosecond, date, expectedStart: Date(timeIntervalSince1970: 846406987.0), end: Date(timeIntervalSince1970: 846406987.0))
        test(.weekday, date, expectedStart: Date(timeIntervalSince1970: 846399600.0), end: Date(timeIntervalSince1970: 846489600.0))
        test(.weekdayOrdinal, date, expectedStart: Date(timeIntervalSince1970: 846399600.0), end: Date(timeIntervalSince1970: 846489600.0))
        test(.quarter, date, expectedStart: Date(timeIntervalSince1970: 844153200.0), end: Date(timeIntervalSince1970: 852105600.0))
        test(.weekOfMonth, date, expectedStart: Date(timeIntervalSince1970: 845967600.0), end: Date(timeIntervalSince1970: 846576000.0))
        test(.weekOfYear, date, expectedStart: Date(timeIntervalSince1970: 845967600.0), end: Date(timeIntervalSince1970: 846576000.0))
        test(.yearForWeekOfYear, date, expectedStart: Date(timeIntervalSince1970: 820569600.0), end: Date(timeIntervalSince1970: 852019200.0))

        date = Date(timeIntervalSince1970: 846410587.0) // 1996-10-27T02:03:07-0800 (1996-10-27T10:03:07Z)
        test(.era, date, expectedStart: Date(timeIntervalSince1970: -62135596800.0), end: Date(timeIntervalSince1970: 4335910914304.0))
        test(.year, date, expectedStart: Date(timeIntervalSince1970: 820483200.0), end: Date(timeIntervalSince1970: 852105600.0))
        test(.month, date, expectedStart: Date(timeIntervalSince1970: 844153200.0), end: Date(timeIntervalSince1970: 846835200.0))
        test(.day, date, expectedStart: Date(timeIntervalSince1970: 846399600.0), end: Date(timeIntervalSince1970: 846489600.0))
        test(.hour, date, expectedStart: Date(timeIntervalSince1970: 846410400.0), end: Date(timeIntervalSince1970: 846414000.0))
        test(.minute, date, expectedStart: Date(timeIntervalSince1970: 846410580.0), end: Date(timeIntervalSince1970: 846410640.0))
        test(.second, date, expectedStart: Date(timeIntervalSince1970: 846410587.0), end: Date(timeIntervalSince1970: 846410588.0))
        test(.nanosecond, date, expectedStart: Date(timeIntervalSince1970: 846410587.0), end: Date(timeIntervalSince1970: 846410587.0))
        test(.weekday, date, expectedStart: Date(timeIntervalSince1970: 846399600.0), end: Date(timeIntervalSince1970: 846489600.0))
        test(.weekdayOrdinal, date, expectedStart: Date(timeIntervalSince1970: 846399600.0), end: Date(timeIntervalSince1970: 846489600.0))
        test(.quarter, date, expectedStart: Date(timeIntervalSince1970: 844153200.0), end: Date(timeIntervalSince1970: 852105600.0))
        test(.weekOfMonth, date, expectedStart: Date(timeIntervalSince1970: 845967600.0), end: Date(timeIntervalSince1970: 846576000.0))
        test(.weekOfYear, date, expectedStart: Date(timeIntervalSince1970: 845967600.0), end: Date(timeIntervalSince1970: 846576000.0))
        test(.yearForWeekOfYear, date, expectedStart: Date(timeIntervalSince1970: 820569600.0), end: Date(timeIntervalSince1970: 852019200.0))

        date = Date(timeIntervalSince1970: 846414187.0) // 1996-10-27T03:03:07-0800 (1996-10-27T11:03:07Z)
        test(.era, date, expectedStart: Date(timeIntervalSince1970: -62135596800.0), end: Date(timeIntervalSince1970: 4335910914304.0))
        test(.year, date, expectedStart: Date(timeIntervalSince1970: 820483200.0), end: Date(timeIntervalSince1970: 852105600.0))
        test(.month, date, expectedStart: Date(timeIntervalSince1970: 844153200.0), end: Date(timeIntervalSince1970: 846835200.0))
        test(.day, date, expectedStart: Date(timeIntervalSince1970: 846399600.0), end: Date(timeIntervalSince1970: 846489600.0))
        test(.hour, date, expectedStart: Date(timeIntervalSince1970: 846414000.0), end: Date(timeIntervalSince1970: 846417600.0))
        test(.minute, date, expectedStart: Date(timeIntervalSince1970: 846414180.0), end: Date(timeIntervalSince1970: 846414240.0))
        test(.second, date, expectedStart: Date(timeIntervalSince1970: 846414187.0), end: Date(timeIntervalSince1970: 846414188.0))
        test(.nanosecond, date, expectedStart: Date(timeIntervalSince1970: 846414187.0), end: Date(timeIntervalSince1970: 846414187.0))
        test(.weekday, date, expectedStart: Date(timeIntervalSince1970: 846399600.0), end: Date(timeIntervalSince1970: 846489600.0))
        test(.weekdayOrdinal, date, expectedStart: Date(timeIntervalSince1970: 846399600.0), end: Date(timeIntervalSince1970: 846489600.0))
        test(.quarter, date, expectedStart: Date(timeIntervalSince1970: 844153200.0), end: Date(timeIntervalSince1970: 852105600.0))
        test(.weekOfMonth, date, expectedStart: Date(timeIntervalSince1970: 845967600.0), end: Date(timeIntervalSince1970: 846576000.0))
        test(.weekOfYear, date, expectedStart: Date(timeIntervalSince1970: 845967600.0), end: Date(timeIntervalSince1970: 846576000.0))
        test(.yearForWeekOfYear, date, expectedStart: Date(timeIntervalSince1970: 820569600.0), end: Date(timeIntervalSince1970: 852019200.0))

        date = Date(timeIntervalSince1970: 845121787.0) // 1996-10-12T05:03:07-0700 (1996-10-12T12:03:07Z)
        test(.era, date, expectedStart: Date(timeIntervalSince1970: -62135596800.0), end: Date(timeIntervalSince1970: 4335910914304.0))
        test(.year, date, expectedStart: Date(timeIntervalSince1970: 820483200.0), end: Date(timeIntervalSince1970: 852105600.0))
        test(.month, date, expectedStart: Date(timeIntervalSince1970: 844153200.0), end: Date(timeIntervalSince1970: 846835200.0))
        test(.day, date, expectedStart: Date(timeIntervalSince1970: 845103600.0), end: Date(timeIntervalSince1970: 845190000.0))
        test(.hour, date, expectedStart: Date(timeIntervalSince1970: 845121600.0), end: Date(timeIntervalSince1970: 845125200.0))
        test(.minute, date, expectedStart: Date(timeIntervalSince1970: 845121780.0), end: Date(timeIntervalSince1970: 845121840.0))
        test(.second, date, expectedStart: Date(timeIntervalSince1970: 845121787.0), end: Date(timeIntervalSince1970: 845121788.0))
        test(.nanosecond, date, expectedStart: Date(timeIntervalSince1970: 845121787.0), end: Date(timeIntervalSince1970: 845121787.0))
        test(.weekday, date, expectedStart: Date(timeIntervalSince1970: 845103600.0), end: Date(timeIntervalSince1970: 845190000.0))
        test(.weekdayOrdinal, date, expectedStart: Date(timeIntervalSince1970: 845103600.0), end: Date(timeIntervalSince1970: 845190000.0))
        test(.quarter, date, expectedStart: Date(timeIntervalSince1970: 844153200.0), end: Date(timeIntervalSince1970: 852105600.0))
        test(.weekOfMonth, date, expectedStart: Date(timeIntervalSince1970: 844758000.0), end: Date(timeIntervalSince1970: 845362800.0))
        test(.weekOfYear, date, expectedStart: Date(timeIntervalSince1970: 844758000.0), end: Date(timeIntervalSince1970: 845362800.0))
        test(.yearForWeekOfYear, date, expectedStart: Date(timeIntervalSince1970: 820569600.0), end: Date(timeIntervalSince1970: 852019200.0))
    }

    // MARK: - Day Of Year
    @Test func test_dayOfYear() throws {
        // An arbitrary date, for which we know the answers
        let date = Date(timeIntervalSinceReferenceDate: 682898558) // 2022-08-22 22:02:38 UTC, day 234
        let leapYearDate = Date(timeIntervalSinceReferenceDate: 745891200) // 2024-08-21 00:00:00 UTC, day 234
        let cal = _CalendarGregorian(identifier: .gregorian, timeZone: .gmt, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)

        // Ordinality
        #expect(cal.ordinality(of: .dayOfYear, in: .year, for: date) == 234)
        #expect(cal.ordinality(of: .hour, in: .dayOfYear, for: date) == 23)
        #expect(cal.ordinality(of: .minute, in: .dayOfYear, for: date) == 1323)
        #expect(cal.ordinality(of: .second, in: .dayOfYear, for: date) == 79359)

        // Nonsense ordinalities. Since day of year is already relative, we don't count the Nth day of year in an era.
        #expect(cal.ordinality(of: .dayOfYear, in: .era, for: date) == nil)
        #expect(cal.ordinality(of: .year, in: .dayOfYear, for: date) == nil)

        // Interval
        let interval = cal.dateInterval(of: .dayOfYear, for: date)
        #expect(interval == DateInterval(start: Date(timeIntervalSinceReferenceDate: 682819200), duration: 86400))

        // Specific component values
        #expect(cal.dateComponent(.dayOfYear, from: date) == 234)


        // Ranges
        let min = cal.minimumRange(of: .dayOfYear)
        let max = cal.maximumRange(of: .dayOfYear)
        #expect(min == 1..<366) // hard coded for gregorian
        #expect(max == 1..<367)

        #expect(cal.range(of: .dayOfYear, in: .year, for: date) == 1..<366)
        #expect(cal.range(of: .dayOfYear, in: .year, for: leapYearDate) == 1..<367)

        // Addition
        let d1 = try cal.add(.dayOfYear, to: date, amount: 1, inTimeZone: .gmt)
        #expect(d1 == date + 86400)

        let d2 = try cal.addAndWrap(.dayOfYear, to: date, amount: 365, inTimeZone: .gmt)
        #expect(d2 == date)

        // Conversion from DateComponents
        var dc = DateComponents(year: 2022, hour: 22, minute: 2, second: 38)
        dc.dayOfYear = 234
        let d = cal.date(from: dc)
        #expect(d == date)

        var subtractMe = DateComponents()
        subtractMe.dayOfYear = -1
        let firstDay = Date(timeIntervalSinceReferenceDate: 662688000)
        let previousDay = try #require(cal.date(byAdding: subtractMe, to:firstDay, wrappingComponents: false))
        let previousDayComps = cal.dateComponents([.year, .dayOfYear], from: previousDay)
        var previousDayExpectationComps = DateComponents()
        previousDayExpectationComps.year = 2021
        previousDayExpectationComps.dayOfYear = 365
        #expect(previousDayComps == previousDayExpectationComps)
    }

    // MARK: - Range of

    @Test func testRangeOf() {
        let calendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(secondsFromGMT: -28800)!, locale: nil, firstWeekday: 1, minimumDaysInFirstWeek: 4, gregorianStartDate: nil)

        func test(_ small: Calendar.Component, in large: Calendar.Component, for date: Date, expected: Range<Int>?, sourceLocation: SourceLocation = #_sourceLocation) {
            let new = calendar.range(of: small, in: large, for: date)
            #expect(new == expected, sourceLocation: sourceLocation)
        }

        var date: Date
        date = Date(timeIntervalSince1970: 820454400.0) // 1995-12-31T16:00:00-0800 (1996-01-01T00:00:00Z)
        test(.month, in: .quarter, for: date, expected: 10..<13)
        test(.day, in: .quarter, for: date, expected: 1..<93)
        test(.weekday, in: .quarter, for: date, expected: 1..<8)
        test(.weekdayOrdinal, in: .quarter, for: date, expected: 1..<16)
        test(.weekOfMonth, in: .quarter, for: date, expected: 0..<15)
        test(.weekOfYear, in: .quarter, for: date, expected: 40..<54)
        test(.day, in: .weekOfYear, for: date, expected: nil)
        test(.month, in: .yearForWeekOfYear, for: date, expected: nil)
        test(.quarter, in: .yearForWeekOfYear, for: date, expected: nil)
        test(.weekOfYear, in: .yearForWeekOfYear, for: date, expected: 1..<53)
        test(.weekOfMonth, in: .yearForWeekOfYear, for: date, expected: nil)
        test(.weekdayOrdinal, in: .yearForWeekOfYear, for: date, expected: 1..<66)
        test(.day, in: .yearForWeekOfYear, for: date, expected: 1..<398)
        test(.day, in: .year, for: date, expected: 1..<366)
        test(.weekday, in: .year, for: date, expected: 1..<8)
        test(.weekdayOrdinal, in: .year, for: date, expected: 1..<60)
        test(.quarter, in: .year, for: date, expected: 1..<5)
        test(.weekOfYear, in: .year, for: date, expected: 1..<54)
        test(.weekOfMonth, in: .year, for: date, expected: 0..<58)
        test(.day, in: .month, for: date, expected: 1..<32)
        test(.weekdayOrdinal, in: .month, for: date, expected: 1..<6)
        test(.weekOfMonth, in: .month, for: date, expected: 0..<6)
        test(.weekOfYear, in: .month, for: date, expected: 48..<54)
        test(.day, in: .weekOfMonth, for: date, expected: 31..<32)

        date = Date(timeIntervalSince1970: 823132800.0) // 1996-01-31T16:00:00-0800 (1996-02-01T00:00:00Z)
        test(.month, in: .quarter, for: date, expected: 1..<4)
        test(.day, in: .quarter, for: date, expected: 1..<92)
        test(.weekday, in: .quarter, for: date, expected: 1..<8)
        test(.weekdayOrdinal, in: .quarter, for: date, expected: 1..<16)
        test(.weekOfMonth, in: .quarter, for: date, expected: 0..<14)
        test(.weekOfYear, in: .quarter, for: date, expected: 1..<15)
        test(.day, in: .weekOfYear, for: date, expected: nil)
        test(.month, in: .yearForWeekOfYear, for: date, expected: nil)
        test(.quarter, in: .yearForWeekOfYear, for: date, expected: nil)
        test(.weekOfYear, in: .yearForWeekOfYear, for: date, expected: 1..<53)
        test(.weekOfMonth, in: .yearForWeekOfYear, for: date, expected: nil)
        test(.weekdayOrdinal, in: .yearForWeekOfYear, for: date, expected: 1..<66)
        test(.day, in: .yearForWeekOfYear, for: date, expected: 1..<398)
        test(.day, in: .year, for: date, expected: 1..<367)
        test(.weekday, in: .year, for: date, expected: 1..<8)
        test(.weekdayOrdinal, in: .year, for: date, expected: 1..<61)
        test(.quarter, in: .year, for: date, expected: 1..<5)
        test(.weekOfYear, in: .year, for: date, expected: 1..<54)
        test(.weekOfMonth, in: .year, for: date, expected: 0..<57)
        test(.day, in: .month, for: date, expected: 1..<32)
        test(.weekdayOrdinal, in: .month, for: date, expected: 1..<6)
        test(.weekOfMonth, in: .month, for: date, expected: 1..<6)
        test(.weekOfYear, in: .month, for: date, expected: 1..<6)
        test(.day, in: .weekOfMonth, for: date, expected: 28..<32)

        date = Date(timeIntervalSince1970: 825638400.0) // 1996-02-29T16:00:00-0800 (1996-03-01T00:00:00Z)
        test(.month, in: .quarter, for: date, expected: 1..<4)
        test(.day, in: .quarter, for: date, expected: 1..<92)
        test(.weekday, in: .quarter, for: date, expected: 1..<8)
        test(.weekdayOrdinal, in: .quarter, for: date, expected: 1..<16)
        test(.weekOfMonth, in: .quarter, for: date, expected: 0..<14)
        test(.weekOfYear, in: .quarter, for: date, expected: 1..<15)
        test(.day, in: .weekOfYear, for: date, expected: nil)
        test(.month, in: .yearForWeekOfYear, for: date, expected: nil)
        test(.quarter, in: .yearForWeekOfYear, for: date, expected: nil)
        test(.weekOfYear, in: .yearForWeekOfYear, for: date, expected: 1..<53)
        test(.weekOfMonth, in: .yearForWeekOfYear, for: date, expected: nil)
        test(.weekdayOrdinal, in: .yearForWeekOfYear, for: date, expected: 1..<66)
        test(.day, in: .yearForWeekOfYear, for: date, expected: 1..<398)
        test(.day, in: .year, for: date, expected: 1..<367)
        test(.weekday, in: .year, for: date, expected: 1..<8)
        test(.weekdayOrdinal, in: .year, for: date, expected: 1..<61)
        test(.quarter, in: .year, for: date, expected: 1..<5)
        test(.weekOfYear, in: .year, for: date, expected: 1..<54)
        test(.weekOfMonth, in: .year, for: date, expected: 0..<57)
        test(.day, in: .month, for: date, expected: 1..<30)
        test(.weekdayOrdinal, in: .month, for: date, expected: 1..<6)
        test(.weekOfMonth, in: .month, for: date, expected: 0..<5)
        test(.weekOfYear, in: .month, for: date, expected: 5..<10)
        test(.day, in: .weekOfMonth, for: date, expected: 25..<30)

        date = Date(timeIntervalSince1970: 851990400.0) // 1996-12-30T16:00:00-0800 (1996-12-31T00:00:00Z)
        test(.month, in: .quarter, for: date, expected: 10..<13)
        test(.day, in: .quarter, for: date, expected: 1..<93)
        test(.weekday, in: .quarter, for: date, expected: 1..<8)
        test(.weekdayOrdinal, in: .quarter, for: date, expected: 1..<16)
        test(.weekOfMonth, in: .quarter, for: date, expected: 0..<14)
        test(.weekOfYear, in: .quarter, for: date, expected: 40..<54)
        test(.day, in: .weekOfYear, for: date, expected: nil)
        test(.month, in: .yearForWeekOfYear, for: date, expected: nil)
        test(.quarter, in: .yearForWeekOfYear, for: date, expected: nil)
        test(.weekOfYear, in: .yearForWeekOfYear, for: date, expected: 1..<54)
        test(.weekOfMonth, in: .yearForWeekOfYear, for: date, expected: nil)
        test(.weekdayOrdinal, in: .yearForWeekOfYear, for: date, expected: 1..<70)
        test(.day, in: .yearForWeekOfYear, for: date, expected: 1..<428)
        test(.day, in: .year, for: date, expected: 1..<367)
        test(.weekday, in: .year, for: date, expected: 1..<8)
        test(.weekdayOrdinal, in: .year, for: date, expected: 1..<61)
        test(.quarter, in: .year, for: date, expected: 1..<5)
        test(.weekOfYear, in: .year, for: date, expected: 1..<54)
        test(.weekOfMonth, in: .year, for: date, expected: 0..<57)
        test(.day, in: .month, for: date, expected: 1..<32)
        test(.weekdayOrdinal, in: .month, for: date, expected: 1..<6)
        test(.weekOfMonth, in: .month, for: date, expected: 1..<6)
        test(.weekOfYear, in: .month, for: date, expected: 49..<54)
        test(.day, in: .weekOfMonth, for: date, expected: 29..<32)

        date = Date(timeIntervalSince1970: 857174400.0) // 1997-02-28T16:00:00-0800 (1997-03-01T00:00:00Z)
        test(.month, in: .quarter, for: date, expected: 1..<4)
        test(.day, in: .quarter, for: date, expected: 1..<91)
        test(.weekday, in: .quarter, for: date, expected: 1..<8)
        test(.weekdayOrdinal, in: .quarter, for: date, expected: 1..<15)
        test(.weekOfMonth, in: .quarter, for: date, expected: 0..<14)
        test(.weekOfYear, in: .quarter, for: date, expected: 1..<15)
        test(.day, in: .weekOfYear, for: date, expected: nil)
        test(.month, in: .yearForWeekOfYear, for: date, expected: nil)
        test(.quarter, in: .yearForWeekOfYear, for: date, expected: nil)
        test(.weekOfYear, in: .yearForWeekOfYear, for: date, expected: 1..<54)
        test(.weekOfMonth, in: .yearForWeekOfYear, for: date, expected: nil)
        test(.weekdayOrdinal, in: .yearForWeekOfYear, for: date, expected: 1..<70)
        test(.day, in: .yearForWeekOfYear, for: date, expected: 1..<428)
        test(.day, in: .year, for: date, expected: 1..<366)
        test(.weekday, in: .year, for: date, expected: 1..<8)
        test(.weekdayOrdinal, in: .year, for: date, expected: 1..<60)
        test(.quarter, in: .year, for: date, expected: 1..<5)
        test(.weekOfYear, in: .year, for: date, expected: 1..<54)
        test(.weekOfMonth, in: .year, for: date, expected: 0..<58)
        test(.day, in: .month, for: date, expected: 1..<29)
        test(.weekdayOrdinal, in: .month, for: date, expected: 1..<5)
        test(.weekOfMonth, in: .month, for: date, expected: 0..<5)
        test(.weekOfYear, in: .month, for: date, expected: 5..<10)
        test(.day, in: .weekOfMonth, for: date, expected: 23..<29)

        date = Date(timeIntervalSince1970: 820483200.0) // 1996-01-01T00:00:00-0800 (1996-01-01T08:00:00Z)
        test(.month, in: .quarter, for: date, expected: 1..<4)
        test(.day, in: .quarter, for: date, expected: 1..<92)
        test(.weekday, in: .quarter, for: date, expected: 1..<8)
        test(.weekdayOrdinal, in: .quarter, for: date, expected: 1..<16)
        test(.weekOfMonth, in: .quarter, for: date, expected: 0..<14)
        test(.weekOfYear, in: .quarter, for: date, expected: 1..<15)
        test(.day, in: .weekOfYear, for: date, expected: nil)
        test(.month, in: .yearForWeekOfYear, for: date, expected: nil)
        test(.quarter, in: .yearForWeekOfYear, for: date, expected: nil)
        test(.weekOfYear, in: .yearForWeekOfYear, for: date, expected: 1..<53)
        test(.weekOfMonth, in: .yearForWeekOfYear, for: date, expected: nil)
        test(.weekdayOrdinal, in: .yearForWeekOfYear, for: date, expected: 1..<66)
        test(.day, in: .yearForWeekOfYear, for: date, expected: 1..<398)
        test(.day, in: .year, for: date, expected: 1..<367)
        test(.weekday, in: .year, for: date, expected: 1..<8)
        test(.weekdayOrdinal, in: .year, for: date, expected: 1..<61)
        test(.quarter, in: .year, for: date, expected: 1..<5)
        test(.weekOfYear, in: .year, for: date, expected: 1..<54)
        test(.weekOfMonth, in: .year, for: date, expected: 0..<57)
        test(.day, in: .month, for: date, expected: 1..<32)
        test(.weekdayOrdinal, in: .month, for: date, expected: 1..<6)
        test(.weekOfMonth, in: .month, for: date, expected: 1..<6)
        test(.weekOfYear, in: .month, for: date, expected: 1..<6)
        test(.day, in: .weekOfMonth, for: date, expected: 1..<7)
    }

    // MARK: - Difference

    @Test func testDateComponentsFromStartToEnd() {
        var calendar = _CalendarGregorian(identifier: .gregorian, timeZone: .gmt, locale: nil, firstWeekday: 1, minimumDaysInFirstWeek: 4, gregorianStartDate: nil)
        var start: Date!
        var end: Date!
        func test(_ components: Calendar.ComponentSet, expected: DateComponents, sourceLocation: SourceLocation = #_sourceLocation) {
            let actual = calendar.dateComponents(components, from: start, to: end)
            #expect(actual == expected, sourceLocation: sourceLocation)
        }

        // non leap to leap
        start = Date(timeIntervalSince1970: 788918400.0) // 1995-01-01
        end = Date(timeIntervalSince1970: 825638400.0) // 1996-03-01
        test([.year, .day, .month], expected: .init(year: 1, month: 2, day: 0))
        test([.weekday, .year, .month, .weekOfMonth], expected: .init(year: 1, month: 2, weekday: 0, weekOfMonth: 0))
        test([.yearForWeekOfYear, .weekOfYear], expected: .init(weekOfYear: 8, yearForWeekOfYear: 1))
        test([.weekday, .year, .month, .weekdayOrdinal], expected: .init(year: 1, month: 2, weekday: 0, weekdayOrdinal: 0))

        // leap to non leap
        // positive year, negative month
        start = Date(timeIntervalSince1970: 823132800.0) // 1996-02-01
        end = Date(timeIntervalSince1970: 852076800.0) // 1997-01-01
        test([.year, .day, .month], expected: .init(year: 0, month: 11, day: 0))
        test([.weekday, .year, .month, .weekOfMonth], expected: .init(year: 0, month: 11, weekday: 0, weekOfMonth: 0))
        test([.yearForWeekOfYear, .weekOfYear], expected: .init(weekOfYear: 47, yearForWeekOfYear: 0))
        test([.weekday, .year, .month, .weekdayOrdinal], expected: .init(year: 0, month: 11, weekday: 0, weekdayOrdinal: 0))

        // within leap
        // positive month, positive day
        start = Date(timeIntervalSince1970: 822960000.0) // 1996-01-30
        end = Date(timeIntervalSince1970: 825552000.0) // 1996-02-29
        test([.year, .day, .month], expected: .init(year: 0, month: 1, day: 0))
        test([.weekday, .year, .month, .weekOfMonth], expected: .init(year: 0, month: 1, weekday: 0, weekOfMonth: 0))
        test([.yearForWeekOfYear, .weekOfYear], expected: .init(weekOfYear: 4, yearForWeekOfYear: 0))
        test([.weekday, .year, .month, .weekdayOrdinal], expected: .init(year: 0, month: 1, weekday: 0, weekdayOrdinal: 0))

        // positive month, negative day
        start = Date(timeIntervalSince1970: 823046400.0) // 1996-01-31
        end = Date(timeIntervalSince1970: 825638400.0) // 1996-03-01
        test([.year, .day, .month], expected: .init(year: 0, month: 1, day: 1))
        test([.weekday, .year, .month, .weekOfMonth], expected: .init(year: 0, month: 1, weekday: 1, weekOfMonth: 0))
        test([.yearForWeekOfYear, .weekOfYear], expected: .init(weekOfYear: 4, yearForWeekOfYear: 0))
        test([.weekday, .year, .month, .weekdayOrdinal], expected: .init(year: 0, month: 1, weekday: 1, weekdayOrdinal: 0))

        // within non leap
        // positive month, positive day
        start = Date(timeIntervalSince1970: 788918400.0) // 1995-01-01
        end = Date(timeIntervalSince1970: 794361600.0) // 1995-03-05
        test([.year, .day, .month], expected: .init(year: 0, month: 2, day: 4))
        test([.weekday, .year, .month, .weekOfMonth], expected: .init(year: 0, month: 2, weekday: 4, weekOfMonth: 0))
        test([.yearForWeekOfYear, .weekOfYear], expected: .init(weekOfYear: 9, yearForWeekOfYear: 0))
        test([.weekday, .year, .month, .weekdayOrdinal], expected: .init(year: 0, month: 2, weekday: 4, weekdayOrdinal: 0))

        // positive month, negative day
        start = Date(timeIntervalSince1970: 791510400.0) // 1995-01-31
        end = Date(timeIntervalSince1970: 794361600.0) // 1995-03-05
        test([.year, .day, .month], expected: .init(year: 0, month: 1, day: 5))
        test([.weekday, .year, .month, .weekOfMonth], expected: .init(year: 0, month: 1, weekday: 5, weekOfMonth: 0))
        test([.yearForWeekOfYear, .weekOfYear], expected: .init(weekOfYear: 4, yearForWeekOfYear: 0))
        test([.weekday, .year, .month, .weekdayOrdinal], expected: .init(year: 0, month: 1, weekday: 5, weekdayOrdinal: 0))

        // ---------
        // Backwards
        start = Date(timeIntervalSince1970: 852076800.0) // 1997-01-01
        end = Date(timeIntervalSince1970: 851817600.0) // 1996-12-29
        test([.year, .day, .month], expected: .init(year: 0, month: 0, day: -3))
        test([.weekday, .year, .month, .weekOfMonth], expected: .init(year: 0, month: 0, weekday: -3, weekOfMonth: 0))
        test([.yearForWeekOfYear, .weekOfYear], expected: .init(weekOfYear: 0, yearForWeekOfYear: 0))
        test([.weekday, .year, .month, .weekdayOrdinal], expected: .init(year: 0, month: 0, weekday: -3, weekdayOrdinal: 0))

        // leap to non leap
        // negative year, positive month
        start = Date(timeIntervalSince1970: 825638400.0) // 1996-03-01
        end = Date(timeIntervalSince1970: 817776000.0) // 1995-12-01
        test([.year, .day, .month], expected: .init(year: 0, month: -3, day: 0))
        test([.weekday, .year, .month, .weekOfMonth], expected: .init(year: 0, month: -3, weekday: 0, weekOfMonth: 0))
        test([.yearForWeekOfYear, .weekOfYear], expected: .init(weekOfYear: -13, yearForWeekOfYear: 0))
        test([.weekday, .year, .month, .weekdayOrdinal], expected: .init(year: 0, month: -3, weekday: 0, weekdayOrdinal: 0))

        // within leap
        // negative month, negative day
        start = Date(timeIntervalSince1970: 825984000.0) // 1996-03-05
        end = Date(timeIntervalSince1970: 820454400.0) // 1996-01-01
        test([.year, .day, .month], expected: .init(year: 0, month: -2, day: -4))
        test([.weekday, .year, .month, .weekOfMonth], expected: .init(year: 0, month: -2, weekday: -4, weekOfMonth: 0))
        test([.yearForWeekOfYear, .weekOfYear], expected: .init(weekOfYear: -9, yearForWeekOfYear: 0))
        test([.weekday, .year, .month, .weekdayOrdinal], expected: .init(year: 0, month: -2, weekday: -4, weekdayOrdinal: 0))

        // negative month, positive day
        start = Date(timeIntervalSince1970: 825552000.0) // 1996-02-29
        end = Date(timeIntervalSince1970: 823046400.0) // 1996-01-31
        test([.year, .day, .month], expected: .init(year: 0, month: 0, day: -29))
        test([.weekday, .year, .month, .weekOfMonth], expected: .init(year: 0, month: 0, weekday: -1, weekOfMonth: -4))
        test([.yearForWeekOfYear, .weekOfYear], expected: .init(weekOfYear: -4, yearForWeekOfYear: 0))
        test([.weekday, .year, .month, .weekdayOrdinal], expected: .init(year: 0, month: 0, weekday: -29, weekdayOrdinal: 0))

        // within non leap
        // negative month, negative day
        start = Date(timeIntervalSince1970: 794361600.0) // 1995-03-05
        end = Date(timeIntervalSince1970: 788918400.0) // 1995-01-01
        test([.year, .day, .month], expected: .init(year: 0, month: -2, day: -4))
        test([.weekday, .year, .month, .weekOfMonth], expected: .init(year: 0, month: -2, weekday: -4, weekOfMonth: 0))
        test([.yearForWeekOfYear, .weekOfYear], expected: .init(weekOfYear: -9, yearForWeekOfYear: 0))
        test([.weekday, .year, .month, .weekdayOrdinal], expected: .init(year: 0, month: -2, weekday: -4, weekdayOrdinal: 0))

        // negative month, positive day
        start = Date(timeIntervalSince1970: 793929600.0) // 1995-02-28
        end = Date(timeIntervalSince1970: 791510400.0) // 1995-01-31
        test([.year, .day, .month], expected: .init(year: 0, month: 0, day: -28))
        test([.weekday, .year, .month, .weekOfMonth], expected: .init(year: 0, month: 0, weekday: 0, weekOfMonth: -4))
        test([.yearForWeekOfYear, .weekOfYear], expected: .init(weekOfYear: -4, yearForWeekOfYear: 0))
        test([.weekday, .year, .month, .weekdayOrdinal], expected: .init(year: 0, month: 0, weekday: -28, weekdayOrdinal: 0))

        calendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(secondsFromGMT: -8*3600), locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
        start = Date(timeIntervalSinceReferenceDate: 0)         // 2000-12-31 16:00:00 PT
        end = Date(timeIntervalSinceReferenceDate: 5458822.0) // 2001-03-04 20:20:22 PT
        var expected = DateComponents(era: 0, year: 0, month: 2, day: 4, hour: 4, minute: 20, second: 22, nanosecond: 0, weekday: 0, weekdayOrdinal: 0, quarter: 0 , weekOfMonth: 0, weekOfYear: 0,  yearForWeekOfYear: 0)
        // FIXME 123202377: This is wrong, but it's the same as Calendar_ICU's current behavior
        expected.dayOfYear = 0
        test([.era, .year, .month, .day, .hour, .minute, .second, .nanosecond, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .dayOfYear, .calendar, .timeZone], expected: expected)
    }

    @Test func testDifference() {
        var calendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(secondsFromGMT: -28800)!, locale: nil, firstWeekday: 1, minimumDaysInFirstWeek: 4, gregorianStartDate: nil)
        var start: Date!
        var end: Date!
        func test(_ component: Calendar.Component, expected: Int, sourceLocation: SourceLocation = #_sourceLocation) {
            let (actualDiff, _) = try! calendar.difference(inComponent: component, from: start, to: end)
            #expect(actualDiff == expected, sourceLocation: sourceLocation)
        }

        // non leap to leap
        start = Date(timeIntervalSince1970: 788947200.0) // 1995-01-01
        end = Date(timeIntervalSince1970: 825667200.0) // 1996-03-01
        test(.era, expected: 0)
        test(.year, expected: 1)
        test(.month, expected: 14)
        test(.day, expected: 425)
        test(.hour, expected: 10200)
        test(.weekday, expected: 425)
        test(.weekdayOrdinal, expected: 60)
        test(.weekOfMonth, expected: 60)
        test(.weekOfYear, expected: 60)
        test(.yearForWeekOfYear, expected: 1)
        test(.dayOfYear, expected: 425)

        // leap to non leap
        start = Date(timeIntervalSince1970: 820483200.0) // 1996-01-01
        end = Date(timeIntervalSince1970: 852105600.0) // 1997-01-01
        test(.era, expected: 0)
        test(.year, expected: 1)
        test(.month, expected: 12)
        test(.day, expected: 366)
        test(.hour, expected: 8784)
        test(.weekday, expected: 366)
        test(.weekdayOrdinal, expected: 52)
        test(.weekOfMonth, expected: 52)
        test(.weekOfYear, expected: 52)
        test(.yearForWeekOfYear, expected: 1)
        test(.dayOfYear, expected: 366)

        // within leap
        start = Date(timeIntervalSince1970: 820483200.0) // 1996-01-01
        end = Date(timeIntervalSince1970: 825580800.0) // 1996-02-29
        test(.era, expected: 0)
        test(.year, expected: 0)
        test(.month, expected: 1)
        test(.day, expected: 59)
        test(.hour, expected: 1416)
        test(.weekday, expected: 59)
        test(.weekdayOrdinal, expected: 8)
        test(.weekOfMonth, expected: 8)
        test(.weekOfYear, expected: 8)
        test(.yearForWeekOfYear, expected: 0)
        test(.dayOfYear, expected: 59)

        start = Date(timeIntervalSince1970: 820483200.0) // 1996-01-01
        end = Date(timeIntervalSince1970: 825667200.0) // 1996-03-01
        test(.era, expected: 0)
        test(.year, expected: 0)
        test(.month, expected: 2)
        test(.day, expected: 60)
        test(.hour, expected: 1440)
        test(.weekday, expected: 60)
        test(.weekdayOrdinal, expected: 8)
        test(.weekOfMonth, expected: 8)
        test(.weekOfYear, expected: 8)
        test(.yearForWeekOfYear, expected: 0)
        test(.dayOfYear, expected: 60)

        // within non leap
        start = Date(timeIntervalSince1970: 788947200.0) // 1995-01-01
        end = Date(timeIntervalSince1970: 794044800.0) // 1995-03-01
        test(.era, expected: 0)
        test(.year, expected: 0)
        test(.month, expected: 2)
        test(.day, expected: 59)
        test(.hour, expected: 1416)
        test(.weekday, expected: 59)
        test(.weekdayOrdinal, expected: 8)
        test(.weekOfMonth, expected: 8)
        test(.weekOfYear, expected: 8)
        test(.yearForWeekOfYear, expected: 0)
        test(.dayOfYear, expected: 59)

        // Backwards
        // non leap to leap
        start = Date(timeIntervalSince1970: 825667200.0) // 1996-03-01
        end = Date(timeIntervalSince1970: 788947200.0) // 1995-01-01
        test(.era, expected: 0)
        test(.year, expected: -1)
        test(.month, expected: -14)
        test(.day, expected: -425)
        test(.hour, expected: -10200)
        test(.weekday, expected: -425)
        test(.weekdayOrdinal, expected: -60)
        test(.weekOfMonth, expected: -60)
        test(.weekOfYear, expected: -60)
        test(.yearForWeekOfYear, expected: -1)
        test(.dayOfYear, expected: -425)

        // leap to non leap
        start = Date(timeIntervalSince1970: 820483200.0) // 1996-01-01
        end = Date(timeIntervalSince1970: 788947200.0) // 1995-01-01
        test(.era, expected: 0)
        test(.year, expected: -1)
        test(.month, expected: -12)
        test(.day, expected: -365)
        test(.hour, expected: -8760)
        test(.weekday, expected: -365)
        test(.weekdayOrdinal, expected: -52)
        test(.weekOfMonth, expected: -52)
        test(.weekOfYear, expected: -52)
        test(.yearForWeekOfYear, expected: -1)
        test(.dayOfYear, expected: -365)

        // within leap
        start = Date(timeIntervalSince1970: 825667200.0) // 1996-03-01
        end = Date(timeIntervalSince1970: 820483200.0) // 1996-01-01
        test(.era, expected: 0)
        test(.year, expected: 0)
        test(.month, expected: -2)
        test(.day, expected: -60)
        test(.hour, expected: -1440)
        test(.weekday, expected: -60)
        test(.weekdayOrdinal, expected: -8)
        test(.weekOfMonth, expected: -8)
        test(.weekOfYear, expected: -8)
        test(.yearForWeekOfYear, expected: 0)
        test(.dayOfYear, expected: -60)

        start = Date(timeIntervalSince1970: 825580800.0) // 1996-02-29
        end = Date(timeIntervalSince1970: 820483200.0) // 1996-01-01
        test(.era, expected: 0)
        test(.year, expected: 0)
        test(.month, expected: -1)
        test(.day, expected: -59)
        test(.hour, expected: -1416)
        test(.weekday, expected: -59)
        test(.weekdayOrdinal, expected: -8)
        test(.weekOfMonth, expected: -8)
        test(.weekOfYear, expected: -8)
        test(.yearForWeekOfYear, expected: 0)
        test(.dayOfYear, expected: -59)

        // within non leap
        start = Date(timeIntervalSince1970: 794044800.0) // 1995-03-01
        end = Date(timeIntervalSince1970: 788947200.0) // 1995-01-01
        test(.era, expected: 0)
        test(.year, expected: 0)
        test(.month, expected: -2)
        test(.day, expected: -59)
        test(.hour, expected: -1416)
        test(.weekday, expected: -59)
        test(.weekdayOrdinal, expected: -8)
        test(.weekOfMonth, expected: -8)
        test(.weekOfYear, expected: -8)
        test(.yearForWeekOfYear, expected: 0)
        test(.dayOfYear, expected: -59)

        // Time

        start = Date(timeIntervalSince1970: 820479600.0) // 1995-12-31 23:00:00
        end = Date(timeIntervalSince1970: 825667200.0) // 1996-03-01 00:00:00
        test(.hour, expected: 1441)
        test(.minute, expected: 86460)
        test(.second, expected: 5187600)
        test(.nanosecond, expected: Int(Int32.max))

        start = Date(timeIntervalSince1970: 852105540.0) // 1996-12-31 23:59:00
        end = Date(timeIntervalSince1970: 857203205.0) // 1997-03-01 00:00:05
        test(.hour, expected: 1416)
        test(.minute, expected: 84961)
        test(.second, expected: 5097665)
        test(.nanosecond, expected: Int(Int32.max))

        start = Date(timeIntervalSince1970: 825580720.0) // 1996-02-28 23:58:40
        end = Date(timeIntervalSince1970: 825580805.0) // 1996-02-29 00:00:05
        test(.hour, expected: 0)
        test(.minute, expected: 1)
        test(.second, expected: 85)
        test(.nanosecond, expected: Int(Int32.max))

        start = Date(timeIntervalSince1970: 825580720.0) // 1996-02-28 23:58:40
        end = Date(timeIntervalSince1970: 825667205.0) // 1996-03-01 00:00:05
        test(.hour, expected: 24)
        test(.minute, expected: 1441)
        test(.second, expected: 86485)
        test(.nanosecond, expected: Int(Int32.max))

        start = Date(timeIntervalSince1970: 794044710.0) // 1995-02-28 23:58:30
        end = Date(timeIntervalSince1970: 794044805.0) // 1995-03-01 00:00:05
        test(.hour, expected: 0)
        test(.minute, expected: 1)
        test(.second, expected: 95)
        test(.nanosecond, expected: Int(Int32.max))

        start = Date(timeIntervalSince1970: 857203205.0) // 1997-03-01 00:00:05
        end = Date(timeIntervalSince1970: 852105520.0) // 1996-12-31 23:58:40
        test(.hour, expected: -1416)
        test(.minute, expected: -84961)
        test(.second, expected: -5097685)
        test(.nanosecond, expected: Int(Int32.min))

        start = Date(timeIntervalSince1970: 825667205.0) // 1996-03-01 00:00:05
        end = Date(timeIntervalSince1970: 820483120.0) // 1995-12-31 23:58:40
        test(.hour, expected: -1440)
        test(.minute, expected: -86401)
        test(.second, expected: -5184085)
        test(.nanosecond, expected: Int(Int32.min))

        start = Date(timeIntervalSince1970: 825667205.0) // 1996-03-01 00:00:05
        end = Date(timeIntervalSince1970: 825580720.0) // 1996-02-28 23:58:40
        test(.hour, expected: -24)
        test(.minute, expected: -1441)
        test(.second, expected: -86485)
        test(.nanosecond, expected: Int(Int32.min))

        start = Date(timeIntervalSince1970: 825580805.0) // 1996-02-29 00:00:05
        end = Date(timeIntervalSince1970: 825580720.0) // 1996-02-28 23:58:40
        test(.hour, expected: 0)
        test(.minute, expected: -1)
        test(.second, expected: -85)
        test(.nanosecond, expected: Int(Int32.min))

        start = Date(timeIntervalSince1970: 825580805.0) // 1996-02-29 00:00:05
        end = Date(timeIntervalSince1970: 820569520.0) // 1996-01-01 23:58:40
        test(.hour, expected: -1392)
        test(.minute, expected: -83521)
        test(.second, expected: -5011285)
        test(.nanosecond, expected: Int(Int32.min))

        start = Date(timeIntervalSince1970: 794044805.0) // 1995-03-01 00:00:05
        end = Date(timeIntervalSince1970: 794044710.0) // 1995-02-28 23:58:30
        test(.hour, expected: 0)
        test(.minute, expected: -1)
        test(.second, expected: -95)
        test(.nanosecond, expected: Int(Int32.min))

        calendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(secondsFromGMT: -8*3600), locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
        start = Date(timeIntervalSinceReferenceDate: 0)         // 2000-12-31 16:00:00 PT
        end = Date(timeIntervalSinceReferenceDate: 5458822.0) // 2001-03-04 20:20:22 PT
        test(.month, expected: 2)
        test(.dayOfYear, expected: 63)
    }

    @Test func testDifference_DST() {
        let calendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(identifier: "America/Los_Angeles")!, locale: nil, firstWeekday: 1, minimumDaysInFirstWeek: 4, gregorianStartDate: nil)

        var start: Date!
        var end: Date!
        func test(_ component: Calendar.Component, expected: Int, sourceLocation: SourceLocation = #_sourceLocation) {
            let (actualDiff, _) = try! calendar.difference(inComponent: component, from: start, to: end)
            #expect(actualDiff == expected, sourceLocation: sourceLocation)
        }

        start = Date(timeIntervalSince1970: 828867787.0) // 1996-04-07T01:03:07-0800
        end = Date(timeIntervalSince1970: 828871387.0) // 1996-04-07T03:03:07-0700
        test(.hour, expected: 1)
        test(.minute, expected: 60)
        test(.second, expected: 3600)

        start = Date(timeIntervalSince1970: 828867787.0) // 1996-04-07T01:03:07-0800
        end = Date(timeIntervalSince1970: 828874987.0) // 1996-04-07T04:03:07-0700
        test(.hour, expected: 2)
        test(.minute, expected: 120)
        test(.second, expected: 7200)

        start = Date(timeIntervalSince1970: 846403387.0) // 1996-10-27T01:03:07-0700
        end = Date(timeIntervalSince1970: 846406987.0) // 1996-10-27T01:03:07-0800
        test(.hour, expected: 1)
        test(.minute, expected: 60)
        test(.second, expected: 3600)

        start = Date(timeIntervalSince1970: 846403387.0) // 1996-10-27T01:03:07-0700
        end = Date(timeIntervalSince1970: 846410587.0) // 1996-10-27T02:03:07-0800
        test(.hour, expected: 2)
        test(.minute, expected: 120)
        test(.second, expected: 7200)

        // backwards

        start = Date(timeIntervalSince1970: 828871387.0) // 1996-04-07T03:03:07-0700
        end = Date(timeIntervalSince1970: 828867787.0) // 1996-04-07T01:03:07-0800
        test(.hour, expected: -1)
        test(.minute, expected: -60)
        test(.second, expected: -3600)

        start = Date(timeIntervalSince1970: 828874987.0) // 1996-04-07T04:03:07-0700
        end = Date(timeIntervalSince1970: 828867787.0) // 1996-04-07T01:03:07-0800
        test(.hour, expected: -2)
        test(.minute, expected: -120)
        test(.second, expected: -7200)

        start = Date(timeIntervalSince1970: 846406987.0) // 1996-10-27T01:03:07-0800
        end = Date(timeIntervalSince1970: 846403387.0) // 1996-10-27T01:03:07-0700
        test(.hour, expected: -1)
        test(.minute, expected: -60)
        test(.second, expected: -3600)

        start = Date(timeIntervalSince1970: 846410587.0) // 1996-10-27T02:03:07-0800
        end = Date(timeIntervalSince1970: 846403387.0) // 1996-10-27T01:03:07-0700
        test(.hour, expected: -2)
        test(.minute, expected: -120)
        test(.second, expected: -7200)
    }
    
    // MARK: ISO8601
    
    @Test func test_iso8601Gregorian() {
        var calendar1 = Calendar(identifier: .iso8601)
        calendar1.timeZone = .gmt
        var calendar2 = Calendar(identifier: .iso8601)
        calendar2.timeZone = .gmt
        #expect(calendar1 == calendar2)
        
        #expect(calendar1.firstWeekday == 2)
        #expect(calendar1.minimumDaysInFirstWeek == 4)
        #expect(calendar1.locale == .unlocalized)
        
        // Verify that the properties are still mutable
        let tz = TimeZone(secondsFromGMT: -3600)!
        calendar1.timeZone = tz
        #expect(calendar1 != calendar2)
        
        #expect(calendar1.timeZone == tz)
    }
}

