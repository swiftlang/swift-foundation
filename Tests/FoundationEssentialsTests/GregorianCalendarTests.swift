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

#if canImport(TestSupport)
import TestSupport
#endif

#if canImport(FoundationEssentials)
@testable import FoundationEssentials
#endif


// Tests for _GregorianCalendar
final class GregorianCalendarTests : XCTestCase {

    func testCopy() {
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: nil, locale: nil, firstWeekday: 5, minimumDaysInFirstWeek: 3, gregorianStartDate: nil)

        let newLocale = Locale(identifier: "new locale")
        let tz = TimeZone(identifier: "America/Los_Angeles")!
        let copied = gregorianCalendar.copy(changingLocale: newLocale, changingTimeZone: tz, changingFirstWeekday: nil, changingMinimumDaysInFirstWeek: nil)
        // newly set values
        XCTAssertEqual(copied.locale, newLocale)
        XCTAssertEqual(copied.timeZone, tz)
        // unset values stay the same
        XCTAssertEqual(copied.firstWeekday, 5)
        XCTAssertEqual(copied.minimumDaysInFirstWeek, 3)

        let copied2 = gregorianCalendar.copy(changingLocale: nil, changingTimeZone: nil, changingFirstWeekday: 1, changingMinimumDaysInFirstWeek: 1)

        // unset values stay the same
        XCTAssertEqual(copied2.locale, gregorianCalendar.locale)
        XCTAssertEqual(copied2.timeZone, gregorianCalendar.timeZone)

        // overriding existing values
        XCTAssertEqual(copied2.firstWeekday, 1)
        XCTAssertEqual(copied2.minimumDaysInFirstWeek, 1)
    }

    // MARK: Date from components
    func testDateFromComponents_DST() {
        // The expected dates were generated using ICU Calendar

        let tz = TimeZone(identifier: "America/Los_Angeles")!
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: tz, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
        func test(_ dateComponents: DateComponents, expected: Date, file: StaticString = #file, line: UInt = #line) {
            let date = gregorianCalendar.date(from: dateComponents)!
            XCTAssertEqual(date, expected, "DateComponents: \(dateComponents)", file: file, line: line)
        }

        test(.init(year: 2023, month: 10, day: 16), expected: Date(timeIntervalSince1970: 1697439600.0))
        test(.init(year: 2023, month: 10, day: 16, hour: 1, minute: 34, second: 52), expected: Date(timeIntervalSince1970: 1697445292.0))
        test(.init(year: 2023, month: 11, day: 6), expected: Date(timeIntervalSince1970: 1699257600.0))
        test(.init(year: 2023, month: 3, day: 12), expected: Date(timeIntervalSince1970: 1678608000.0))
        test(.init(year: 2023, month: 3, day: 12, hour: 1, minute: 34, second: 52), expected: Date(timeIntervalSince1970: 1678613692.0))
        test(.init(year: 2023, month: 3, day: 12, hour: 2, minute: 34, second: 52), expected: Date(timeIntervalSince1970: 1678617292.0))
        test(.init(year: 2023, month: 3, day: 12, hour: 3, minute: 34, second: 52), expected: Date(timeIntervalSince1970: 1678617292.0))
        test(.init(year: 2023, month: 3, day: 13, hour: 0, minute: 0, second: 0), expected: Date(timeIntervalSince1970: 1678690800.0))
        test(.init(year: 2023, month: 11, day: 5), expected: Date(timeIntervalSince1970: 1699167600.0))
        test(.init(year: 2023, month: 11, day: 5, hour: 1, minute: 34, second: 52), expected: Date(timeIntervalSince1970: 1699173292.0))
        test(.init(year: 2023, month: 11, day: 5, hour: 2, minute: 34, second: 52), expected: Date(timeIntervalSince1970: 1699180492.0))
        test(.init(year: 2023, month: 11, day: 5, hour: 3, minute: 34, second: 52), expected: Date(timeIntervalSince1970: 1699184092.0))
    }

    func testDateFromComponents() {
        // The expected dates were generated using ICU Calendar
        let tz = TimeZone.gmt
        let cal = _CalendarGregorian(identifier: .gregorian, timeZone: tz, locale: nil, firstWeekday: 1, minimumDaysInFirstWeek: 4, gregorianStartDate: nil)
        func test(_ dateComponents: DateComponents, expected: Date, file: StaticString = #file, line: UInt = #line) {
            let date = cal.date(from: dateComponents)
            XCTAssertEqual(date, expected, "date components: \(dateComponents)", file: file, line: line)
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
    func testDateComponentsFromDate() {
        let calendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(secondsFromGMT: 0)!, locale: nil, firstWeekday: 1, minimumDaysInFirstWeek: 5, gregorianStartDate: nil)
        func test(_ date: Date, _ timeZone: TimeZone, expectedEra era: Int, year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int, nanosecond: Int, weekday: Int, weekdayOrdinal: Int, quarter: Int, weekOfMonth: Int, weekOfYear: Int, yearForWeekOfYear: Int, isLeapMonth: Bool, file: StaticString = #file, line: UInt = #line) {
            let dc = calendar.dateComponents([.era, .year, .month, .day, .hour, .minute, .second, .nanosecond, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .calendar, .timeZone], from: date)
            XCTAssertEqual(dc.era, era, file: file, line: line)
            XCTAssertEqual(dc.year, year, file: file, line: line)
            XCTAssertEqual(dc.month, month, file: file, line: line)
            XCTAssertEqual(dc.day, day, file: file, line: line)
            XCTAssertEqual(dc.hour, hour, file: file, line: line)
            XCTAssertEqual(dc.minute, minute, file: file, line: line)
            XCTAssertEqual(dc.second, second, file: file, line: line)
            XCTAssertEqual(dc.weekday, weekday, file: file, line: line)
            XCTAssertEqual(dc.weekdayOrdinal, weekdayOrdinal, file: file, line: line)
            XCTAssertEqual(dc.weekOfMonth, weekOfMonth, file: file, line: line)
            XCTAssertEqual(dc.weekOfYear, weekOfYear, file: file, line: line)
            XCTAssertEqual(dc.yearForWeekOfYear, yearForWeekOfYear, file: file, line: line)
            XCTAssertEqual(dc.quarter, quarter, file: file, line: line)
            XCTAssertEqual(dc.nanosecond, nanosecond, file: file, line: line)
            XCTAssertEqual(dc.isLeapMonth, isLeapMonth, file: file, line: line)
            XCTAssertEqual(dc.timeZone, timeZone, file: file, line: line)
        }
        test(Date(timeIntervalSince1970: 852045787.0), .gmt, expectedEra: 1, year: 1996, month: 12, day: 31, hour: 15, minute: 23, second: 7, nanosecond: 0, weekday: 3, weekdayOrdinal: 5, quarter: 4, weekOfMonth: 5, weekOfYear: 53, yearForWeekOfYear: 1996, isLeapMonth: false) // 1996-12-31T15:23:07Z
        test(Date(timeIntervalSince1970: 825607387.0), .gmt, expectedEra: 1, year: 1996, month: 2, day: 29, hour: 15, minute: 23, second: 7, nanosecond: 0, weekday: 5, weekdayOrdinal: 5, quarter: 1, weekOfMonth: 4, weekOfYear: 9, yearForWeekOfYear: 1996, isLeapMonth: false) // 1996-02-29T15:23:07Z
        test(Date(timeIntervalSince1970: 828838987.0), .gmt, expectedEra: 1, year: 1996, month: 4, day: 7, hour: 1, minute: 3, second: 7, nanosecond: 0, weekday: 1, weekdayOrdinal: 1, quarter: 2, weekOfMonth: 2, weekOfYear: 15, yearForWeekOfYear: 1996, isLeapMonth: false) // 1996-04-07T01:03:07Z
        test(Date(timeIntervalSince1970: -62135765813.0), .gmt, expectedEra: 1, year: 1, month: 1, day: 1, hour: 1, minute: 3, second: 7, nanosecond: 0, weekday: 7, weekdayOrdinal: 1, quarter: 1, weekOfMonth: 0, weekOfYear: 52, yearForWeekOfYear: 0, isLeapMonth: false) // 0001-01-01T01:03:07Z
        test(Date(timeIntervalSince1970: -62135852213.0), .gmt, expectedEra: 0, year: 1, month: 12, day: 31, hour: 1, minute: 3, second: 7, nanosecond: 0, weekday: 6, weekdayOrdinal: 5, quarter: 4, weekOfMonth: 4, weekOfYear: 52, yearForWeekOfYear: 0, isLeapMonth: false) // 0000-12-31T01:03:07Z
    }

    // MARK: - Add

    func testAdd() {
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(secondsFromGMT: 3600)!, locale: nil, firstWeekday: 3, minimumDaysInFirstWeek: 4, gregorianStartDate: nil)
        var date: Date
        func test(addField field: Calendar.Component, value: Int, to addingToDate: Date, wrap: Bool, expectedDate: Date, _ file: StaticString = #file, _ line: UInt = #line) {
            let components = DateComponents(component: field, value: value)!
            let result = gregorianCalendar.date(byAdding: components, to: addingToDate, wrappingComponents: wrap)!
            XCTAssertEqual(result, expectedDate, file: file, line: line)
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
    }

    func testAdd_boundaries() {
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(secondsFromGMT: 3600)!, locale: nil, firstWeekday: 3, minimumDaysInFirstWeek: 4, gregorianStartDate: nil)
        var date: Date
        func test(addField field: Calendar.Component, value: Int, to addingToDate: Date, wrap: Bool, expectedDate: Date, _ file: StaticString = #file, _ line: UInt = #line) {
            let components = DateComponents(component: field, value: value)!
            let result = gregorianCalendar.date(byAdding: components, to: addingToDate, wrappingComponents: wrap)!
            XCTAssertEqual(result, expectedDate, file: file, line: line)
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

    func testAddDateComponents() {
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(secondsFromGMT: 3600)!, locale: nil, firstWeekday: 3, minimumDaysInFirstWeek: 7, gregorianStartDate: nil)

        func testAdding(_ comp: DateComponents, to date: Date, wrap: Bool, expected: Date, _ file: StaticString = #file, _ line: UInt = #line) {
            let result = gregorianCalendar.date(byAdding: comp, to: date, wrappingComponents: wrap)!
            XCTAssertEqual(result, expected, file: file, line: line)
        }

        let march1_1996 = Date(timeIntervalSince1970: 825723300)
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
        testAdding(.init(day: -1, weekday: 1 ), to: march1_1996, wrap: true, expected: Date(timeIntervalSince1970:825723300.0))
        testAdding(.init(day: -7, weekOfYear: 1 ), to: march1_1996, wrap: true, expected: Date(timeIntervalSince1970:828401700.0))
        testAdding(.init(day: -7, weekOfMonth: 1 ), to: march1_1996, wrap: true, expected: Date(timeIntervalSince1970:825982500.0))
        testAdding(.init(day: -7, weekOfMonth: 1, weekOfYear: 1 ), to: march1_1996, wrap: true, expected: Date(timeIntervalSince1970:829006500.0))

        let oct14_1582 = Date(timeIntervalSince1970: -12218515200.0)
        testAdding(.init(day: -1, hour: 1), to: oct14_1582, wrap: false, expected: Date(timeIntervalSince1970:-12218598000.0))
        testAdding(.init(month: -1, hour: 1), to: oct14_1582, wrap: false, expected: Date(timeIntervalSince1970:-12220239600.0))
        testAdding(.init(month: -1, day: 30), to: oct14_1582, wrap: false, expected: Date(timeIntervalSince1970:-12217651200.0))
        testAdding(.init(year: 4, day: -1), to: oct14_1582, wrap: false, expected: Date(timeIntervalSince1970:-12092371200.0))
        testAdding(.init(day: -1, hour: 24), to: oct14_1582, wrap: false, expected: Date(timeIntervalSince1970:-12218515200.0))
        testAdding(.init(day: -1, weekday: 1), to: oct14_1582, wrap: false, expected: Date(timeIntervalSince1970:-12218515200.0))
        testAdding(.init(day: -7, weekOfYear: 1), to: oct14_1582, wrap: false, expected: Date(timeIntervalSince1970:-12218515200.0))
        testAdding(.init(day: -7, weekOfMonth: 1), to: oct14_1582, wrap: false, expected: Date(timeIntervalSince1970:-12218515200.0))
        testAdding(.init(day: -7, weekOfMonth: 1, weekOfYear: 1), to: oct14_1582, wrap: false, expected: Date(timeIntervalSince1970:-12217910400.0))

        testAdding(.init(day: -1, hour: 1), to: oct14_1582, wrap: true, expected: Date(timeIntervalSince1970:-12218598000.0))
        testAdding(.init(month: -1, hour: 1), to: oct14_1582, wrap: true, expected: Date(timeIntervalSince1970:-12220239600.0))
        testAdding(.init(month: -1, day: 30), to: oct14_1582, wrap: true, expected: Date(timeIntervalSince1970:-12220243200.0))
        testAdding(.init(year: 4, day: -1), to: oct14_1582, wrap: true, expected: Date(timeIntervalSince1970:-12092371200.0))
        testAdding(.init(day: -1, hour: 24), to: oct14_1582, wrap: true, expected: Date(timeIntervalSince1970:-12218601600.0))
        testAdding(.init(day: -1, weekday: 1), to: oct14_1582, wrap: true, expected: Date(timeIntervalSince1970:-12218515200.0))
        testAdding(.init(day: -7, weekOfYear: 1), to: oct14_1582, wrap: true, expected: Date(timeIntervalSince1970:-12218515200.0))
        testAdding(.init(day: -7, weekOfMonth: 1), to: oct14_1582, wrap: true, expected: Date(timeIntervalSince1970:-12218515200.0))
        testAdding(.init(day: -7, weekOfMonth: 1, weekOfYear: 1), to: oct14_1582, wrap: true, expected: Date(timeIntervalSince1970:-12217910400.0))
    }

    func testAddDateComponents_DST() {
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(identifier: "America/Los_Angeles")!, locale: nil, firstWeekday: 2, minimumDaysInFirstWeek: 4, gregorianStartDate: nil)

        func testAdding(_ comp: DateComponents, to date: Date, wrap: Bool, expected: Date, _ file: StaticString = #file, _ line: UInt = #line) {
            let result = gregorianCalendar.date(byAdding: comp, to: date, wrappingComponents: wrap)!
            XCTAssertEqual(result, expected, file: file, line: line)
        }

        let march1_1996 = Date(timeIntervalSince1970: 825723300)
        testAdding(.init(day: -1, hour: 1), to: march1_1996, wrap: false, expected: Date(timeIntervalSince1970: 825640500.0))
        testAdding(.init(month: -1, hour: 1), to: march1_1996, wrap: false, expected: Date(timeIntervalSince1970: 823221300.0))
        testAdding(.init(month: -1, day: 30), to: march1_1996, wrap: false, expected: Date(timeIntervalSince1970: 825809700.0))
        testAdding(.init(year: 4, day: -1), to: march1_1996, wrap: false, expected: Date(timeIntervalSince1970: 951867300.0))
        testAdding(.init(day: -1, hour: 24), to: march1_1996, wrap: false, expected: Date(timeIntervalSince1970: 825723300.0))
        testAdding(.init(day: -1, weekday: 1), to: march1_1996, wrap: false, expected: Date(timeIntervalSince1970: 825723300.0))
        testAdding(.init(day: -7, weekOfYear: 1), to: march1_1996, wrap: false, expected: Date(timeIntervalSince1970: 825723300.0))
        testAdding(.init(day: -7, weekOfMonth: 1), to: march1_1996, wrap: false, expected: Date(timeIntervalSince1970: 825723300.0))
        testAdding(.init(day: -7, weekOfMonth: 1, weekOfYear: 1), to: march1_1996, wrap: false, expected: Date(timeIntervalSince1970: 826328100.0))
        
        testAdding(.init(day: -1, hour: 1), to: march1_1996, wrap: true, expected: Date(timeIntervalSince1970: 828318900.0))
        testAdding(.init(month: -1, hour: 1), to: march1_1996, wrap: true, expected: Date(timeIntervalSince1970: 823221300.0))
        testAdding(.init(month: -1, day: 30), to: march1_1996, wrap: true, expected: Date(timeIntervalSince1970: 823304100.0))
        testAdding(.init(year: 4, day: -1), to: march1_1996, wrap: true, expected: Date(timeIntervalSince1970: 954545700.0))
        testAdding(.init(day: -1, hour: 24), to: march1_1996, wrap: true, expected: Date(timeIntervalSince1970: 828315300.0))
        testAdding(.init(day: -1, weekday: 1), to: march1_1996, wrap: true, expected: Date(timeIntervalSince1970: 827796900.0))
        testAdding(.init(day: -7, weekOfYear: 1), to: march1_1996, wrap: true, expected: Date(timeIntervalSince1970: 828401700.0))
        testAdding(.init(day: -7, weekOfMonth: 1), to: march1_1996, wrap: true, expected: Date(timeIntervalSince1970: 825982500.0))
        testAdding(.init(day: -7, weekOfMonth: 1, weekOfYear: 1), to: march1_1996, wrap: true, expected: Date(timeIntervalSince1970: 829002900.0))
    }

    func testAddDateComponents_DSTBoundaries() {
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(identifier: "America/Los_Angeles")!, locale: nil, firstWeekday: 3, minimumDaysInFirstWeek: 5, gregorianStartDate: nil)

        let fmt = Date.ISO8601FormatStyle(timeZone: gregorianCalendar.timeZone)
        func testAdding(_ comp: DateComponents, to date: Date, expected: Date, _ file: StaticString = #file, _ line: UInt = #line) {
            let result = gregorianCalendar.date(byAdding: comp, to: date, wrappingComponents: false)!
            XCTAssertEqual(result, expected, "result: \(fmt.format(result)); expected: \(fmt.format(expected))", file: file, line: line)
        }

        var date: Date
        date = Date(timeIntervalSince1970: 814950000.0) // 1995-10-29T00:00:00-0700

        // second equivalent
        testAdding(.init(second: 1), to: date, expected: Date(timeIntervalSince1970: 814950001.0))
        testAdding(.init(minute: 60, second: -59), to: date, expected: Date(timeIntervalSince1970: 814953541.0))
        testAdding(.init(hour: 1, second: -59), to: date, expected: Date(timeIntervalSince1970: 814953541.0))
        testAdding(.init(hour: 2, minute: -59, second: -59), to: date, expected: Date(timeIntervalSince1970: 814953601.0))
        testAdding(.init(second: -1), to: date, expected: Date(timeIntervalSince1970: 814949999.0))
        testAdding(.init(minute: -60, second: 59), to: date, expected: Date(timeIntervalSince1970: 814946459.0))
        testAdding(.init(hour: -1, second: 59), to: date, expected: Date(timeIntervalSince1970: 814946459.0))
        testAdding(.init(hour: -2, minute: 59, second: 59), to: date, expected: Date(timeIntervalSince1970: 814946399.0))

        // minute equivalent
        testAdding(.init(minute: 1), to: date, expected: Date(timeIntervalSince1970: 814950060.0))
        testAdding(.init(second: 60), to: date, expected: Date(timeIntervalSince1970: 814950060.0))
        testAdding(.init(hour: 1, minute: -59), to: date, expected: Date(timeIntervalSince1970: 814950060.0))
        testAdding(.init(day: 1, hour: -23, minute: -59), to: date, expected: Date(timeIntervalSince1970: 814953660.0))
        testAdding(.init(minute: -1), to: date, expected: Date(timeIntervalSince1970: 814949940.0))
        testAdding(.init(second: -60), to: date, expected: Date(timeIntervalSince1970: 814949940.0))
        testAdding(.init(hour: -1, minute: 59), to: date, expected: Date(timeIntervalSince1970: 814949940.0))
        testAdding(.init(day: -1, hour: 23, minute: 59), to: date, expected: Date(timeIntervalSince1970: 814949940.0))

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 815558400.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 815558400.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 815558400.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 819187200.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 815558400.0))

        date = Date(timeIntervalSince1970: 814953540.0) // 1995-10-29T00:59:00-0700

        // second equivalent
        testAdding(.init(second: 1), to: date, expected: Date(timeIntervalSince1970: 814953541.0))
        testAdding(.init(minute: 60, second: -59), to: date, expected: Date(timeIntervalSince1970: 814957081.0))
        testAdding(.init(hour: 1, second: -59), to: date, expected: Date(timeIntervalSince1970: 814957081.0))
        testAdding(.init(hour: 2, minute: -59, second: -59), to: date, expected: Date(timeIntervalSince1970: 814957141.0))
        testAdding(.init(second: -1), to: date, expected: Date(timeIntervalSince1970: 814953539.0))
        testAdding(.init(minute: -60, second: 59), to: date, expected: Date(timeIntervalSince1970: 814949999.0))
        testAdding(.init(hour: -1, second: 59), to: date, expected: Date(timeIntervalSince1970: 814949999.0))
        testAdding(.init(hour: -2, minute: 59, second: 59), to: date, expected: Date(timeIntervalSince1970: 814949939.0))

        // minute equivalent
        testAdding(.init(minute: 1), to: date, expected: Date(timeIntervalSince1970: 814953600.0))
        testAdding(.init(second: 60), to: date, expected: Date(timeIntervalSince1970: 814953600.0))
        testAdding(.init(hour: 1, minute: -59), to: date, expected: Date(timeIntervalSince1970: 814953600.0))
        testAdding(.init(day: 1, hour: -23, minute: -59), to: date, expected: Date(timeIntervalSince1970: 814957200.0))
        testAdding(.init(minute: -1), to: date, expected: Date(timeIntervalSince1970: 814953480.0))
        testAdding(.init(second: -60), to: date, expected: Date(timeIntervalSince1970: 814953480.0))
        testAdding(.init(hour: -1, minute: 59), to: date, expected: Date(timeIntervalSince1970: 814953480.0))
        testAdding(.init(day: -1, hour: 23, minute: 59), to: date, expected: Date(timeIntervalSince1970: 814953480.0))

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 815561940.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 815561940.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 815561940.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 819190740.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 815561940.0))

        date = Date(timeIntervalSince1970: 814953599.0) // 1995-10-29T00:59:59-0700

        // second equivalent
        testAdding(.init(second: 1), to: date, expected: Date(timeIntervalSince1970: 814953600.0))
        testAdding(.init(minute: 60, second: -59), to: date, expected: Date(timeIntervalSince1970: 814957140.0))
        testAdding(.init(hour: 1, second: -59), to: date, expected: Date(timeIntervalSince1970: 814957140.0))
        testAdding(.init(hour: 2, minute: -59, second: -59), to: date, expected: Date(timeIntervalSince1970: 814957200.0))
        testAdding(.init(second: -1), to: date, expected: Date(timeIntervalSince1970: 814953598.0))
        testAdding(.init(minute: -60, second: 59), to: date, expected: Date(timeIntervalSince1970: 814950058.0))
        testAdding(.init(hour: -1, second: 59), to: date, expected: Date(timeIntervalSince1970: 814950058.0))
        testAdding(.init(hour: -2, minute: 59, second: 59), to: date, expected: Date(timeIntervalSince1970: 814949998.0))

        // minute equivalent
        testAdding(.init(minute: 1), to: date, expected: Date(timeIntervalSince1970: 814953659.0))
        testAdding(.init(second: 60), to: date, expected: Date(timeIntervalSince1970: 814953659.0))
        testAdding(.init(hour: 1, minute: -59), to: date, expected: Date(timeIntervalSince1970: 814953659.0))
        testAdding(.init(day: 1, hour: -23, minute: -59), to: date, expected: Date(timeIntervalSince1970: 814957259.0))
        testAdding(.init(minute: -1), to: date, expected: Date(timeIntervalSince1970: 814953539.0))
        testAdding(.init(second: -60), to: date, expected: Date(timeIntervalSince1970: 814953539.0))
        testAdding(.init(hour: -1, minute: 59), to: date, expected: Date(timeIntervalSince1970: 814953539.0))
        testAdding(.init(day: -1, hour: 23, minute: 59), to: date, expected: Date(timeIntervalSince1970: 814953539.0))

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 815561999.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 815561999.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 815561999.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 819190799.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 815561999.0))

        date = Date(timeIntervalSince1970: 814953600.0) // 1995-10-29T01:00:00-0700

        // second equivalent
        testAdding(.init(second: 1), to: date, expected: Date(timeIntervalSince1970: 814953601.0))
        testAdding(.init(minute: 60, second: -59), to: date, expected: Date(timeIntervalSince1970: 814957141.0))
        testAdding(.init(hour: 1, second: -59), to: date, expected: Date(timeIntervalSince1970: 814957141.0))
        testAdding(.init(hour: 2, minute: -59, second: -59), to: date, expected: Date(timeIntervalSince1970: 814957201.0))
        testAdding(.init(second: -1), to: date, expected: Date(timeIntervalSince1970: 814953599.0))
        testAdding(.init(minute: -60, second: 59), to: date, expected: Date(timeIntervalSince1970: 814950059.0))
        testAdding(.init(hour: -1, second: 59), to: date, expected: Date(timeIntervalSince1970: 814950059.0))
        testAdding(.init(hour: -2, minute: 59, second: 59), to: date, expected: Date(timeIntervalSince1970: 814949999.0))

        // minute equivalent
        testAdding(.init(minute: 1), to: date, expected: Date(timeIntervalSince1970: 814953660.0))
        testAdding(.init(second: 60), to: date, expected: Date(timeIntervalSince1970: 814953660.0))
        testAdding(.init(hour: 1, minute: -59), to: date, expected: Date(timeIntervalSince1970: 814953660.0))
        testAdding(.init(day: 1, hour: -23, minute: -59), to: date, expected: Date(timeIntervalSince1970: 814957260.0))
        testAdding(.init(minute: -1), to: date, expected: Date(timeIntervalSince1970: 814953540.0))
        testAdding(.init(second: -60), to: date, expected: Date(timeIntervalSince1970: 814953540.0))
        testAdding(.init(hour: -1, minute: 59), to: date, expected: Date(timeIntervalSince1970: 814953540.0))
        testAdding(.init(day: -1, hour: 23, minute: 59), to: date, expected: Date(timeIntervalSince1970: 814953540.0))

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 815562000.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 815562000.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 815562000.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 819190800.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 815562000.0))

        date = Date(timeIntervalSince1970: 814953660.0) // 1995-10-29T01:01:00-0700

        // second equivalent
        testAdding(.init(second: 1), to: date, expected: Date(timeIntervalSince1970: 814953661.0))
        testAdding(.init(minute: 60, second: -59), to: date, expected: Date(timeIntervalSince1970: 814957201.0))
        testAdding(.init(hour: 1, second: -59), to: date, expected: Date(timeIntervalSince1970: 814957201.0))
        testAdding(.init(hour: 2, minute: -59, second: -59), to: date, expected: Date(timeIntervalSince1970: 814957261.0))
        testAdding(.init(second: -1), to: date, expected: Date(timeIntervalSince1970: 814953659.0))
        testAdding(.init(minute: -60, second: 59), to: date, expected: Date(timeIntervalSince1970: 814950119.0))
        testAdding(.init(hour: -1, second: 59), to: date, expected: Date(timeIntervalSince1970: 814950119.0))
        testAdding(.init(hour: -2, minute: 59, second: 59), to: date, expected: Date(timeIntervalSince1970: 814950059.0))

        // minute equivalent
        testAdding(.init(minute: 1), to: date, expected: Date(timeIntervalSince1970: 814953720.0))
        testAdding(.init(second: 60), to: date, expected: Date(timeIntervalSince1970: 814953720.0))
        testAdding(.init(hour: 1, minute: -59), to: date, expected: Date(timeIntervalSince1970: 814953720.0))
        testAdding(.init(day: 1, hour: -23, minute: -59), to: date, expected: Date(timeIntervalSince1970: 814957320.0))
        testAdding(.init(minute: -1), to: date, expected: Date(timeIntervalSince1970: 814953600.0))
        testAdding(.init(second: -60), to: date, expected: Date(timeIntervalSince1970: 814953600.0))
        testAdding(.init(hour: -1, minute: 59), to: date, expected: Date(timeIntervalSince1970: 814953600.0))
        testAdding(.init(day: -1, hour: 23, minute: 59), to: date, expected: Date(timeIntervalSince1970: 814953600.0))

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 815562060.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 815562060.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 815562060.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 819190860.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 815562060.0))

        date = Date(timeIntervalSince1970: 814953660.0) // 1995-10-29T01:01:00-0700

        // hour equivalent
        testAdding(.init(hour: 1), to: date, expected: Date(timeIntervalSince1970: 814957260.0))
        testAdding(.init(minute: 60), to: date, expected: Date(timeIntervalSince1970: 814957260.0))
        testAdding(.init(second: 3600), to: date, expected: Date(timeIntervalSince1970: 814957260.0))
        testAdding(.init(hour: 2, minute: -60), to: date, expected: Date(timeIntervalSince1970: 814957260.0))
        testAdding(.init(day: 1, hour: -23), to: date, expected: Date(timeIntervalSince1970: 814960860.0))
        testAdding(.init(day: 1, hour: -22, minute: -60), to: date, expected: Date(timeIntervalSince1970: 814960860.0))
        testAdding(.init(hour: -1), to: date, expected: Date(timeIntervalSince1970: 814950060.0))
        testAdding(.init(minute: -60), to: date, expected: Date(timeIntervalSince1970: 814950060.0))
        testAdding(.init(second: -3600), to: date, expected: Date(timeIntervalSince1970: 814950060.0))
        testAdding(.init(hour: -2, minute: 60), to: date, expected: Date(timeIntervalSince1970: 814950060.0))
        testAdding(.init(day: -1, hour: 23), to: date, expected: Date(timeIntervalSince1970: 814950060.0))
        testAdding(.init(day: -1, hour: 22, minute: 60), to: date, expected: Date(timeIntervalSince1970: 814950060.0))

        // day equivalent
        testAdding(.init(minute: 86400), to: date, expected: Date(timeIntervalSince1970: 820137660.0))
        testAdding(.init(hour: 24), to: date, expected: Date(timeIntervalSince1970: 815040060.0))
        testAdding(.init(day: 1), to: date, expected: Date(timeIntervalSince1970: 815043660.0))
        testAdding(.init(month: 1, day: -30), to: date, expected: Date(timeIntervalSince1970: 815043660.0))
        testAdding(.init(year: 1, month: -11, day: -30), to: date, expected: Date(timeIntervalSince1970: 815043660.0))
        testAdding(.init(weekday: 1), to: date, expected: Date(timeIntervalSince1970: 815043660.0))
        testAdding(.init(day: -1, weekday: 2), to: date, expected: Date(timeIntervalSince1970: 815043660.0))

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 815562060.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 815562060.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 815562060.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 819190860.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 815562060.0))
        testAdding(.init(yearForWeekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 846403260.0))
        testAdding(.init(weekOfYear: 52), to: date, expected: Date(timeIntervalSince1970: 846403260.0))
        testAdding(.init(weekOfYear: 53), to: date, expected: Date(timeIntervalSince1970: 847011660.0))
        testAdding(.init(yearForWeekOfYear: -1), to: date, expected: Date(timeIntervalSince1970: 783507660.0))
        testAdding(.init(weekOfYear: -52), to: date, expected: Date(timeIntervalSince1970: 783504060.0))
        testAdding(.init(weekOfYear: -53), to: date, expected: Date(timeIntervalSince1970: 782899260.0))

        date = Date(timeIntervalSince1970: 814957387.0) // 1995-10-29T01:03:07-0800

        // hour equivalent
        testAdding(.init(hour: 1), to: date, expected: Date(timeIntervalSince1970: 814960987.0))
        testAdding(.init(minute: 60), to: date, expected: Date(timeIntervalSince1970: 814960987.0))
        testAdding(.init(second: 3600), to: date, expected: Date(timeIntervalSince1970: 814960987.0))
        testAdding(.init(hour: 2, minute: -60), to: date, expected: Date(timeIntervalSince1970: 814960987.0))
        testAdding(.init(day: 1, hour: -23), to: date, expected: Date(timeIntervalSince1970: 814960987.0))
        testAdding(.init(day: 1, hour: -22, minute: -60), to: date, expected: Date(timeIntervalSince1970: 814960987.0))
        testAdding(.init(hour: -1), to: date, expected: Date(timeIntervalSince1970: 814953787.0))
        testAdding(.init(minute: -60), to: date, expected: Date(timeIntervalSince1970: 814953787.0))
        testAdding(.init(second: -3600), to: date, expected: Date(timeIntervalSince1970: 814953787.0))
        testAdding(.init(hour: -2, minute: 60), to: date, expected: Date(timeIntervalSince1970: 814953787.0))
        testAdding(.init(day: -1, hour: 23), to: date, expected: Date(timeIntervalSince1970: 814950187.0))
        testAdding(.init(day: -1, hour: 22, minute: 60), to: date, expected: Date(timeIntervalSince1970: 814950187.0))

        // day equivalent
        testAdding(.init(minute: 86400), to: date, expected: Date(timeIntervalSince1970: 820141387.0))
        testAdding(.init(hour: 24), to: date, expected: Date(timeIntervalSince1970: 815043787.0))
        testAdding(.init(day: 1), to: date, expected: Date(timeIntervalSince1970: 815043787.0))
        testAdding(.init(month: 1, day: -30), to: date, expected: Date(timeIntervalSince1970: 815043787.0))
        testAdding(.init(year: 1, month: -11, day: -30), to: date, expected: Date(timeIntervalSince1970: 815043787.0))
        testAdding(.init(weekday: 1), to: date, expected: Date(timeIntervalSince1970: 815043787.0))
        testAdding(.init(day: -1, weekday: 2), to: date, expected: Date(timeIntervalSince1970: 815043787.0))

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 815562187.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 815562187.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 815562187.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 819190987.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 815562187.0))
        testAdding(.init(yearForWeekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 846403387.0))
        // Current result:      1996-10-27T01:03:07-0800
        // Calendar_ICU result: 1996-10-27T01:03:07-0700
        testAdding(.init(weekOfYear: 52), to: date, expected: Date(timeIntervalSince1970: 846403387.0))
        testAdding(.init(weekOfYear: 53), to: date, expected: Date(timeIntervalSince1970: 847011787.0))
        testAdding(.init(yearForWeekOfYear: -1), to: date, expected: Date(timeIntervalSince1970: 783507787.0))
        testAdding(.init(weekOfYear: -52), to: date, expected: Date(timeIntervalSince1970: 783507787.0))
        testAdding(.init(weekOfYear: -53), to: date, expected: Date(timeIntervalSince1970: 782899387.0))

        date = Date(timeIntervalSince1970: 814960987.0) // 1995-10-29T02:03:07-0800

        // hour equivalent
        testAdding(.init(hour: 1), to: date, expected: Date(timeIntervalSince1970: 814964587.0))
        testAdding(.init(minute: 60), to: date, expected: Date(timeIntervalSince1970: 814964587.0))
        testAdding(.init(second: 3600), to: date, expected: Date(timeIntervalSince1970: 814964587.0))
        testAdding(.init(hour: 2, minute: -60), to: date, expected: Date(timeIntervalSince1970: 814964587.0))
        testAdding(.init(day: 1, hour: -23), to: date, expected: Date(timeIntervalSince1970: 814964587.0))
        testAdding(.init(day: 1, hour: -22, minute: -60), to: date, expected: Date(timeIntervalSince1970: 814964587.0))
        testAdding(.init(hour: -1), to: date, expected: Date(timeIntervalSince1970: 814957387.0))
        testAdding(.init(minute: -60), to: date, expected: Date(timeIntervalSince1970: 814957387.0))
        testAdding(.init(second: -3600), to: date, expected: Date(timeIntervalSince1970: 814957387.0))
        testAdding(.init(hour: -2, minute: 60), to: date, expected: Date(timeIntervalSince1970: 814957387.0))
        testAdding(.init(day: -1, hour: 23), to: date, expected: Date(timeIntervalSince1970: 814953787.0))
        testAdding(.init(day: -1, hour: 22, minute: 60), to: date, expected: Date(timeIntervalSince1970: 814953787.0))

        // day equivalent
        testAdding(.init(minute: 86400), to: date, expected: Date(timeIntervalSince1970: 820144987.0))
        testAdding(.init(hour: 24), to: date, expected: Date(timeIntervalSince1970: 815047387.0))
        testAdding(.init(day: 1), to: date, expected: Date(timeIntervalSince1970: 815047387.0))
        testAdding(.init(month: 1, day: -30), to: date, expected: Date(timeIntervalSince1970: 815047387.0))
        testAdding(.init(year: 1, month: -11, day: -30), to: date, expected: Date(timeIntervalSince1970: 815047387.0))
        testAdding(.init(weekday: 1), to: date, expected: Date(timeIntervalSince1970: 815047387.0))
        testAdding(.init(day: -1, weekday: 2), to: date, expected: Date(timeIntervalSince1970: 815047387.0))

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 815565787.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 815565787.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 815565787.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 819194587.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 815565787.0))
        testAdding(.init(yearForWeekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 846410587.0))
        testAdding(.init(weekOfYear: 52), to: date, expected: Date(timeIntervalSince1970: 846410587.0))
        testAdding(.init(weekOfYear: 53), to: date, expected: Date(timeIntervalSince1970: 847015387.0))
        testAdding(.init(yearForWeekOfYear: -1), to: date, expected: Date(timeIntervalSince1970: 783511387.0))
        testAdding(.init(weekOfYear: -52), to: date, expected: Date(timeIntervalSince1970: 783511387.0))
        testAdding(.init(weekOfYear: -53), to: date, expected: Date(timeIntervalSince1970: 782902987.0))

        date = Date(timeIntervalSince1970: 814964587.0) // 1995-10-29T03:03:07-0800

        // hour equivalent
        testAdding(.init(hour: 1), to: date, expected: Date(timeIntervalSince1970: 814968187.0))
        testAdding(.init(minute: 60), to: date, expected: Date(timeIntervalSince1970: 814968187.0))
        testAdding(.init(second: 3600), to: date, expected: Date(timeIntervalSince1970: 814968187.0))
        testAdding(.init(hour: 2, minute: -60), to: date, expected: Date(timeIntervalSince1970: 814968187.0))
        testAdding(.init(day: 1, hour: -23), to: date, expected: Date(timeIntervalSince1970: 814968187.0))
        testAdding(.init(day: 1, hour: -22, minute: -60), to: date, expected: Date(timeIntervalSince1970: 814968187.0))
        testAdding(.init(hour: -1), to: date, expected: Date(timeIntervalSince1970: 814960987.0))
        testAdding(.init(minute: -60), to: date, expected: Date(timeIntervalSince1970: 814960987.0))
        testAdding(.init(second: -3600), to: date, expected: Date(timeIntervalSince1970: 814960987.0))
        testAdding(.init(hour: -2, minute: 60), to: date, expected: Date(timeIntervalSince1970: 814960987.0))
        testAdding(.init(day: -1, hour: 23), to: date, expected: Date(timeIntervalSince1970: 814957387.0))
        testAdding(.init(day: -1, hour: 22, minute: 60), to: date, expected: Date(timeIntervalSince1970: 814957387.0))

        // day equivalent
        testAdding(.init(minute: 86400), to: date, expected: Date(timeIntervalSince1970: 820148587.0))
        testAdding(.init(hour: 24), to: date, expected: Date(timeIntervalSince1970: 815050987.0))
        testAdding(.init(day: 1), to: date, expected: Date(timeIntervalSince1970: 815050987.0))
        testAdding(.init(month: 1, day: -30), to: date, expected: Date(timeIntervalSince1970: 815050987.0))
        testAdding(.init(year: 1, month: -11, day: -30), to: date, expected: Date(timeIntervalSince1970: 815050987.0))
        testAdding(.init(weekday: 1), to: date, expected: Date(timeIntervalSince1970: 815050987.0))
        testAdding(.init(day: -1, weekday: 2), to: date, expected: Date(timeIntervalSince1970: 815050987.0))

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 815569387.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 815569387.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 815569387.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 819198187.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 815569387.0))
        testAdding(.init(yearForWeekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 846414187.0))
        testAdding(.init(weekOfYear: 52), to: date, expected: Date(timeIntervalSince1970: 846414187.0))
        testAdding(.init(weekOfYear: 53), to: date, expected: Date(timeIntervalSince1970: 847018987.0))
        testAdding(.init(yearForWeekOfYear: -1), to: date, expected: Date(timeIntervalSince1970: 783514987.0))
        testAdding(.init(weekOfYear: -52), to: date, expected: Date(timeIntervalSince1970: 783514987.0))
        testAdding(.init(weekOfYear: -53), to: date, expected: Date(timeIntervalSince1970: 782906587.0))

        date = Date(timeIntervalSince1970: 814780860.0) // 1995-10-27T01:01:00-0700

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 815389260.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 815389260.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 815389260.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 819018060.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 815389260.0))
        testAdding(.init(year: 1), to: date, expected: Date(timeIntervalSince1970: 846403260.0))
        testAdding(.init(month: 12), to: date, expected: Date(timeIntervalSince1970: 846403260.0))
        testAdding(.init(day: 364), to: date, expected: Date(timeIntervalSince1970: 846230460.0))
        testAdding(.init(day: 365), to: date, expected: Date(timeIntervalSince1970: 846316860.0))
        testAdding(.init(day: 366), to: date, expected: Date(timeIntervalSince1970: 846403260.0))
        testAdding(.init(year: -1), to: date, expected: Date(timeIntervalSince1970: 783244860.0))
        testAdding(.init(month: -12), to: date, expected: Date(timeIntervalSince1970: 783244860.0))
        testAdding(.init(day: -364), to: date, expected: Date(timeIntervalSince1970: 783331260.0))
        testAdding(.init(day: -365), to: date, expected: Date(timeIntervalSince1970: 783244860.0))
        testAdding(.init(day: -366), to: date, expected: Date(timeIntervalSince1970: 783158460.0))

        date = Date(timeIntervalSince1970: 814784587.0) // 1995-10-27T02:03:07-0700

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 815392987.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 815392987.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 815392987.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 819021787.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 815392987.0))
        testAdding(.init(year: 1), to: date, expected: Date(timeIntervalSince1970: 846410587.0))
        testAdding(.init(month: 12), to: date, expected: Date(timeIntervalSince1970: 846410587.0))
        testAdding(.init(day: 364), to: date, expected: Date(timeIntervalSince1970: 846234187.0))
        testAdding(.init(day: 365), to: date, expected: Date(timeIntervalSince1970: 846320587.0))
        testAdding(.init(day: 366), to: date, expected: Date(timeIntervalSince1970: 846410587.0))
        testAdding(.init(year: -1), to: date, expected: Date(timeIntervalSince1970: 783248587.0))
        testAdding(.init(month: -12), to: date, expected: Date(timeIntervalSince1970: 783248587.0))
        testAdding(.init(day: -364), to: date, expected: Date(timeIntervalSince1970: 783334987.0))
        testAdding(.init(day: -365), to: date, expected: Date(timeIntervalSince1970: 783248587.0))
        testAdding(.init(day: -366), to: date, expected: Date(timeIntervalSince1970: 783162187.0))

        date = Date(timeIntervalSince1970: 814788187.0) // 1995-10-27T03:03:07-0700

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 815396587.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 815396587.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 815396587.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 819025387.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 815396587.0))
        testAdding(.init(year: 1), to: date, expected: Date(timeIntervalSince1970: 846414187.0))
        testAdding(.init(month: 12), to: date, expected: Date(timeIntervalSince1970: 846414187.0))
        testAdding(.init(day: 364), to: date, expected: Date(timeIntervalSince1970: 846237787.0))
        testAdding(.init(day: 365), to: date, expected: Date(timeIntervalSince1970: 846324187.0))
        testAdding(.init(day: 366), to: date, expected: Date(timeIntervalSince1970: 846414187.0))
        testAdding(.init(year: -1), to: date, expected: Date(timeIntervalSince1970: 783252187.0))
        testAdding(.init(month: -12), to: date, expected: Date(timeIntervalSince1970: 783252187.0))
        testAdding(.init(day: -364), to: date, expected: Date(timeIntervalSince1970: 783338587.0))
        testAdding(.init(day: -365), to: date, expected: Date(timeIntervalSince1970: 783252187.0))
        testAdding(.init(day: -366), to: date, expected: Date(timeIntervalSince1970: 783165787.0))

        date = Date(timeIntervalSince1970: 814791787.0) // 1995-10-27T04:03:07-0700

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 815400187.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 815400187.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 815400187.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 819028987.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 815400187.0))
        testAdding(.init(year: 1), to: date, expected: Date(timeIntervalSince1970: 846417787.0))
        testAdding(.init(month: 12), to: date, expected: Date(timeIntervalSince1970: 846417787.0))
        testAdding(.init(day: 364), to: date, expected: Date(timeIntervalSince1970: 846241387.0))
        testAdding(.init(day: 365), to: date, expected: Date(timeIntervalSince1970: 846327787.0))
        testAdding(.init(day: 366), to: date, expected: Date(timeIntervalSince1970: 846417787.0))
        testAdding(.init(year: -1), to: date, expected: Date(timeIntervalSince1970: 783255787.0))
        testAdding(.init(month: -12), to: date, expected: Date(timeIntervalSince1970: 783255787.0))
        testAdding(.init(day: -364), to: date, expected: Date(timeIntervalSince1970: 783342187.0))
        testAdding(.init(day: -365), to: date, expected: Date(timeIntervalSince1970: 783255787.0))
        testAdding(.init(day: -366), to: date, expected: Date(timeIntervalSince1970: 783169387.0))

        date = Date(timeIntervalSince1970: 812358000.0) // 1995-09-29T00:00:00-0700

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 812962800.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 812962800.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 812962800.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 816595200.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 812962800.0))

        // month equivalent
        testAdding(.init(month: 1), to: date, expected: Date(timeIntervalSince1970: 814950000.0))
        testAdding(.init(day: 30), to: date, expected: Date(timeIntervalSince1970: 814950000.0))
        testAdding(.init(day: 31), to: date, expected: Date(timeIntervalSince1970: 815040000.0))
        testAdding(.init(weekOfMonth: 4), to: date, expected: Date(timeIntervalSince1970: 814777200.0))
        testAdding(.init(weekOfMonth: 5), to: date, expected: Date(timeIntervalSince1970: 815385600.0))
        testAdding(.init(weekOfYear: 4), to: date, expected: Date(timeIntervalSince1970: 814777200.0))
        testAdding(.init(weekOfYear: 5), to: date, expected: Date(timeIntervalSince1970: 815385600.0))
        testAdding(.init(month: -1), to: date, expected: Date(timeIntervalSince1970: 809679600.0))
        testAdding(.init(day: -30), to: date, expected: Date(timeIntervalSince1970: 809766000.0))
        testAdding(.init(day: -31), to: date, expected: Date(timeIntervalSince1970: 809679600.0))
        testAdding(.init(weekOfMonth: -4), to: date, expected: Date(timeIntervalSince1970: 809938800.0))
        testAdding(.init(weekOfMonth: -5), to: date, expected: Date(timeIntervalSince1970: 809334000.0))
        testAdding(.init(weekOfYear: -4), to: date, expected: Date(timeIntervalSince1970: 809938800.0))
        testAdding(.init(weekOfYear: -5), to: date, expected: Date(timeIntervalSince1970: 809334000.0))

        date = Date(timeIntervalSince1970: 812361600.0) // 1995-09-29T01:00:00-0700

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 812966400.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 812966400.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 812966400.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 816598800.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 812966400.0))

        // month equivalent
        testAdding(.init(month: 1), to: date, expected: Date(timeIntervalSince1970: 814953600.0))
        testAdding(.init(day: 30), to: date, expected: Date(timeIntervalSince1970: 814953600.0))
        testAdding(.init(day: 31), to: date, expected: Date(timeIntervalSince1970: 815043600.0))
        testAdding(.init(weekOfMonth: 4), to: date, expected: Date(timeIntervalSince1970: 814780800.0))
        testAdding(.init(weekOfMonth: 5), to: date, expected: Date(timeIntervalSince1970: 815389200.0))
        testAdding(.init(weekOfYear: 4), to: date, expected: Date(timeIntervalSince1970: 814780800.0))
        testAdding(.init(weekOfYear: 5), to: date, expected: Date(timeIntervalSince1970: 815389200.0))
        testAdding(.init(month: -1), to: date, expected: Date(timeIntervalSince1970: 809683200.0))
        testAdding(.init(day: -30), to: date, expected: Date(timeIntervalSince1970: 809769600.0))
        testAdding(.init(day: -31), to: date, expected: Date(timeIntervalSince1970: 809683200.0))
        testAdding(.init(weekOfMonth: -4), to: date, expected: Date(timeIntervalSince1970: 809942400.0))
        testAdding(.init(weekOfMonth: -5), to: date, expected: Date(timeIntervalSince1970: 809337600.0))
        testAdding(.init(weekOfYear: -4), to: date, expected: Date(timeIntervalSince1970: 809942400.0))
        testAdding(.init(weekOfYear: -5), to: date, expected: Date(timeIntervalSince1970: 809337600.0))

        date = Date(timeIntervalSince1970: 812365387.0) // 1995-09-29T02:03:07-0700

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 812970187.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 812970187.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 812970187.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 816602587.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 812970187.0))

        // month equivalent
        testAdding(.init(month: 1), to: date, expected: Date(timeIntervalSince1970: 814960987.0))
        testAdding(.init(day: 30), to: date, expected: Date(timeIntervalSince1970: 814960987.0))
        testAdding(.init(day: 31), to: date, expected: Date(timeIntervalSince1970: 815047387.0))
        testAdding(.init(weekOfMonth: 4), to: date, expected: Date(timeIntervalSince1970: 814784587.0))
        testAdding(.init(weekOfMonth: 5), to: date, expected: Date(timeIntervalSince1970: 815392987.0))
        testAdding(.init(weekOfYear: 4), to: date, expected: Date(timeIntervalSince1970: 814784587.0))
        testAdding(.init(weekOfYear: 5), to: date, expected: Date(timeIntervalSince1970: 815392987.0))
        testAdding(.init(month: -1), to: date, expected: Date(timeIntervalSince1970: 809686987.0))
        testAdding(.init(day: -30), to: date, expected: Date(timeIntervalSince1970: 809773387.0))
        testAdding(.init(day: -31), to: date, expected: Date(timeIntervalSince1970: 809686987.0))
        testAdding(.init(weekOfMonth: -4), to: date, expected: Date(timeIntervalSince1970: 809946187.0))
        testAdding(.init(weekOfMonth: -5), to: date, expected: Date(timeIntervalSince1970: 809341387.0))
        testAdding(.init(weekOfYear: -4), to: date, expected: Date(timeIntervalSince1970: 809946187.0))
        testAdding(.init(weekOfYear: -5), to: date, expected: Date(timeIntervalSince1970: 809341387.0))

        date = Date(timeIntervalSince1970: 812368987.0) // 1995-09-29T03:03:07-0700

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 812973787.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 812973787.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 812973787.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 816606187.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 812973787.0))

        // month equivalent
        testAdding(.init(month: 1), to: date, expected: Date(timeIntervalSince1970: 814964587.0))
        testAdding(.init(day: 30), to: date, expected: Date(timeIntervalSince1970: 814964587.0))
        testAdding(.init(day: 31), to: date, expected: Date(timeIntervalSince1970: 815050987.0))
        testAdding(.init(weekOfMonth: 4), to: date, expected: Date(timeIntervalSince1970: 814788187.0))
        testAdding(.init(weekOfMonth: 5), to: date, expected: Date(timeIntervalSince1970: 815396587.0))
        testAdding(.init(weekOfYear: 4), to: date, expected: Date(timeIntervalSince1970: 814788187.0))
        testAdding(.init(weekOfYear: 5), to: date, expected: Date(timeIntervalSince1970: 815396587.0))
        testAdding(.init(month: -1), to: date, expected: Date(timeIntervalSince1970: 809690587.0))
        testAdding(.init(day: -30), to: date, expected: Date(timeIntervalSince1970: 809776987.0))
        testAdding(.init(day: -31), to: date, expected: Date(timeIntervalSince1970: 809690587.0))
        testAdding(.init(weekOfMonth: -4), to: date, expected: Date(timeIntervalSince1970: 809949787.0))
        testAdding(.init(weekOfMonth: -5), to: date, expected: Date(timeIntervalSince1970: 809344987.0))
        testAdding(.init(weekOfYear: -4), to: date, expected: Date(timeIntervalSince1970: 809949787.0))
        testAdding(.init(weekOfYear: -5), to: date, expected: Date(timeIntervalSince1970: 809344987.0))

        date = Date(timeIntervalSince1970: 812372587.0) // 1995-09-29T04:03:07-0700

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 812977387.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 812977387.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 812977387.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 816609787.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 812977387.0))

        // month equivalent
        testAdding(.init(month: 1), to: date, expected: Date(timeIntervalSince1970: 814968187.0))
        testAdding(.init(day: 30), to: date, expected: Date(timeIntervalSince1970: 814968187.0))
        testAdding(.init(day: 31), to: date, expected: Date(timeIntervalSince1970: 815054587.0))
        testAdding(.init(weekOfMonth: 4), to: date, expected: Date(timeIntervalSince1970: 814791787.0))
        testAdding(.init(weekOfMonth: 5), to: date, expected: Date(timeIntervalSince1970: 815400187.0))
        testAdding(.init(weekOfYear: 4), to: date, expected: Date(timeIntervalSince1970: 814791787.0))
        testAdding(.init(weekOfYear: 5), to: date, expected: Date(timeIntervalSince1970: 815400187.0))
        testAdding(.init(month: -1), to: date, expected: Date(timeIntervalSince1970: 809694187.0))
        testAdding(.init(day: -30), to: date, expected: Date(timeIntervalSince1970: 809780587.0))
        testAdding(.init(day: -31), to: date, expected: Date(timeIntervalSince1970: 809694187.0))
        testAdding(.init(weekOfMonth: -4), to: date, expected: Date(timeIntervalSince1970: 809953387.0))
        testAdding(.init(weekOfMonth: -5), to: date, expected: Date(timeIntervalSince1970: 809348587.0))
        testAdding(.init(weekOfYear: -4), to: date, expected: Date(timeIntervalSince1970: 809953387.0))
        testAdding(.init(weekOfYear: -5), to: date, expected: Date(timeIntervalSince1970: 809348587.0))

        date = Date(timeIntervalSince1970: 812530800.0) // 1995-10-01T00:00:00-0700

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 813135600.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 813135600.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 813135600.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 816768000.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 813135600.0))

        date = Date(timeIntervalSince1970: 812534400.0) // 1995-10-01T01:00:00-0700

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 813139200.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 813139200.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 813139200.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 816771600.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 813139200.0))

        date = Date(timeIntervalSince1970: 812538187.0) // 1995-10-01T02:03:07-0700

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 813142987.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 813142987.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 813142987.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 816775387.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 813142987.0))

        date = Date(timeIntervalSince1970: 812541787.0) // 1995-10-01T03:03:07-0700

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 813146587.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 813146587.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 813146587.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 816778987.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 813146587.0))

        date = Date(timeIntervalSince1970: 812545387.0) // 1995-10-01T04:03:07-0700

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 813150187.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 813150187.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 813150187.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 816782587.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 813150187.0))

        date = Date(timeIntervalSince1970: 812530800.0) // 1995-10-01T00:00:00-0700

        // month equivalent
        testAdding(.init(month: 1), to: date, expected: Date(timeIntervalSince1970: 815212800.0))
        testAdding(.init(day: 30), to: date, expected: Date(timeIntervalSince1970: 815126400.0))
        testAdding(.init(day: 31), to: date, expected: Date(timeIntervalSince1970: 815212800.0))
        testAdding(.init(weekOfMonth: 4), to: date, expected: Date(timeIntervalSince1970: 814950000.0))
        testAdding(.init(weekOfMonth: 5), to: date, expected: Date(timeIntervalSince1970: 815558400.0))
        testAdding(.init(weekOfYear: 4), to: date, expected: Date(timeIntervalSince1970: 814950000.0))
        testAdding(.init(weekOfYear: 5), to: date, expected: Date(timeIntervalSince1970: 815558400.0))
        testAdding(.init(month: -1), to: date, expected: Date(timeIntervalSince1970: 809938800.0))
        testAdding(.init(day: -30), to: date, expected: Date(timeIntervalSince1970: 809938800.0))
        testAdding(.init(day: -31), to: date, expected: Date(timeIntervalSince1970: 809852400.0))
        testAdding(.init(weekOfMonth: -4), to: date, expected: Date(timeIntervalSince1970: 810111600.0))
        testAdding(.init(weekOfMonth: -5), to: date, expected: Date(timeIntervalSince1970: 809506800.0))
        testAdding(.init(weekOfYear: -4), to: date, expected: Date(timeIntervalSince1970: 810111600.0))
        testAdding(.init(weekOfYear: -5), to: date, expected: Date(timeIntervalSince1970: 809506800.0))

        date = Date(timeIntervalSince1970: 812534400.0) // 1995-10-01T01:00:00-0700

        // month equivalent
        testAdding(.init(month: 1), to: date, expected: Date(timeIntervalSince1970: 815216400.0))
        testAdding(.init(day: 30), to: date, expected: Date(timeIntervalSince1970: 815130000.0))
        testAdding(.init(day: 31), to: date, expected: Date(timeIntervalSince1970: 815216400.0))
        testAdding(.init(weekOfMonth: 4), to: date, expected: Date(timeIntervalSince1970: 814953600.0))
        testAdding(.init(weekOfMonth: 5), to: date, expected: Date(timeIntervalSince1970: 815562000.0))
        testAdding(.init(weekOfYear: 4), to: date, expected: Date(timeIntervalSince1970: 814953600.0))
        testAdding(.init(weekOfYear: 5), to: date, expected: Date(timeIntervalSince1970: 815562000.0))
        testAdding(.init(month: -1), to: date, expected: Date(timeIntervalSince1970: 809942400.0))
        testAdding(.init(day: -30), to: date, expected: Date(timeIntervalSince1970: 809942400.0))
        testAdding(.init(day: -31), to: date, expected: Date(timeIntervalSince1970: 809856000.0))
        testAdding(.init(weekOfMonth: -4), to: date, expected: Date(timeIntervalSince1970: 810115200.0))
        testAdding(.init(weekOfMonth: -5), to: date, expected: Date(timeIntervalSince1970: 809510400.0))
        testAdding(.init(weekOfYear: -4), to: date, expected: Date(timeIntervalSince1970: 810115200.0))
        testAdding(.init(weekOfYear: -5), to: date, expected: Date(timeIntervalSince1970: 809510400.0))

        date = Date(timeIntervalSince1970: 812538187.0) // 1995-10-01T02:03:07-0700

        // month equivalent
        testAdding(.init(month: 1), to: date, expected: Date(timeIntervalSince1970: 815220187.0))
        testAdding(.init(day: 30), to: date, expected: Date(timeIntervalSince1970: 815133787.0))
        testAdding(.init(day: 31), to: date, expected: Date(timeIntervalSince1970: 815220187.0))
        testAdding(.init(weekOfMonth: 4), to: date, expected: Date(timeIntervalSince1970: 814960987.0))
        testAdding(.init(weekOfMonth: 5), to: date, expected: Date(timeIntervalSince1970: 815565787.0))
        testAdding(.init(weekOfYear: 4), to: date, expected: Date(timeIntervalSince1970: 814960987.0))
        testAdding(.init(weekOfYear: 5), to: date, expected: Date(timeIntervalSince1970: 815565787.0))
        testAdding(.init(month: -1), to: date, expected: Date(timeIntervalSince1970: 809946187.0))
        testAdding(.init(day: -30), to: date, expected: Date(timeIntervalSince1970: 809946187.0))
        testAdding(.init(day: -31), to: date, expected: Date(timeIntervalSince1970: 809859787.0))
        testAdding(.init(weekOfMonth: -4), to: date, expected: Date(timeIntervalSince1970: 810118987.0))
        testAdding(.init(weekOfMonth: -5), to: date, expected: Date(timeIntervalSince1970: 809514187.0))
        testAdding(.init(weekOfYear: -4), to: date, expected: Date(timeIntervalSince1970: 810118987.0))
        testAdding(.init(weekOfYear: -5), to: date, expected: Date(timeIntervalSince1970: 809514187.0))

        date = Date(timeIntervalSince1970: 812541787.0) // 1995-10-01T03:03:07-0700

        // month equivalent
        testAdding(.init(month: 1), to: date, expected: Date(timeIntervalSince1970: 815223787.0))
        testAdding(.init(day: 30), to: date, expected: Date(timeIntervalSince1970: 815137387.0))
        testAdding(.init(day: 31), to: date, expected: Date(timeIntervalSince1970: 815223787.0))
        testAdding(.init(weekOfMonth: 4), to: date, expected: Date(timeIntervalSince1970: 814964587.0))
        testAdding(.init(weekOfMonth: 5), to: date, expected: Date(timeIntervalSince1970: 815569387.0))
        testAdding(.init(weekOfYear: 4), to: date, expected: Date(timeIntervalSince1970: 814964587.0))
        testAdding(.init(weekOfYear: 5), to: date, expected: Date(timeIntervalSince1970: 815569387.0))
        testAdding(.init(month: -1), to: date, expected: Date(timeIntervalSince1970: 809949787.0))
        testAdding(.init(day: -30), to: date, expected: Date(timeIntervalSince1970: 809949787.0))
        testAdding(.init(day: -31), to: date, expected: Date(timeIntervalSince1970: 809863387.0))
        testAdding(.init(weekOfMonth: -4), to: date, expected: Date(timeIntervalSince1970: 810122587.0))
        testAdding(.init(weekOfMonth: -5), to: date, expected: Date(timeIntervalSince1970: 809517787.0))
        testAdding(.init(weekOfYear: -4), to: date, expected: Date(timeIntervalSince1970: 810122587.0))
        testAdding(.init(weekOfYear: -5), to: date, expected: Date(timeIntervalSince1970: 809517787.0))

        date = Date(timeIntervalSince1970: 812545387.0) // 1995-10-01T04:03:07-0700

        // month equivalent
        testAdding(.init(month: 1), to: date, expected: Date(timeIntervalSince1970: 815227387.0))
        testAdding(.init(day: 30), to: date, expected: Date(timeIntervalSince1970: 815140987.0))
        testAdding(.init(day: 31), to: date, expected: Date(timeIntervalSince1970: 815227387.0))
        testAdding(.init(weekOfMonth: 4), to: date, expected: Date(timeIntervalSince1970: 814968187.0))
        testAdding(.init(weekOfMonth: 5), to: date, expected: Date(timeIntervalSince1970: 815572987.0))
        testAdding(.init(weekOfYear: 4), to: date, expected: Date(timeIntervalSince1970: 814968187.0))
        testAdding(.init(weekOfYear: 5), to: date, expected: Date(timeIntervalSince1970: 815572987.0))
        testAdding(.init(month: -1), to: date, expected: Date(timeIntervalSince1970: 809953387.0))
        testAdding(.init(day: -30), to: date, expected: Date(timeIntervalSince1970: 809953387.0))
        testAdding(.init(day: -31), to: date, expected: Date(timeIntervalSince1970: 809866987.0))
        testAdding(.init(weekOfMonth: -4), to: date, expected: Date(timeIntervalSince1970: 810126187.0))
        testAdding(.init(weekOfMonth: -5), to: date, expected: Date(timeIntervalSince1970: 809521387.0))
        testAdding(.init(weekOfYear: -4), to: date, expected: Date(timeIntervalSince1970: 810126187.0))
        testAdding(.init(weekOfYear: -5), to: date, expected: Date(timeIntervalSince1970: 809521387.0))

        date = Date(timeIntervalSince1970: 814345200.0) // 1995-10-22T00:00:00-0700

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 814950000.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 814950000.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 814950000.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 818582400.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 814950000.0))

        date = Date(timeIntervalSince1970: 814348800.0) // 1995-10-22T01:00:00-0700

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 814953600.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 814953600.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 814953600.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 818586000.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 814953600.0))

        date = Date(timeIntervalSince1970: 814352587.0) // 1995-10-22T02:03:07-0700

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 814960987.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 814960987.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 814960987.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 818589787.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 814960987.0))

        date = Date(timeIntervalSince1970: 814356187.0) // 1995-10-22T03:03:07-0700

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 814964587.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 814964587.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 814964587.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 818593387.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 814964587.0))

        date = Date(timeIntervalSince1970: 814359787.0) // 1995-10-22T04:03:07-0700

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 814968187.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 814968187.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 814968187.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 818596987.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 814968187.0))
    }

    func testAddDateComponents_Wrapping_DSTBoundaries() {
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(identifier: "America/Los_Angeles")!, locale: nil, firstWeekday: 3, minimumDaysInFirstWeek: 5, gregorianStartDate: nil)

        let fmt = Date.ISO8601FormatStyle(timeZone: gregorianCalendar.timeZone)
        func testAdding(_ comp: DateComponents, to date: Date, expected: Date, _ file: StaticString = #file, _ line: UInt = #line) {
            let result = gregorianCalendar.date(byAdding: comp, to: date, wrappingComponents: true)!
            XCTAssertEqual(result, expected, "result: \(fmt.format(result)); expected: \(fmt.format(expected))", file: file, line: line)
        }

        var date: Date
        date = Date(timeIntervalSince1970: 814950000.0) // 1995-10-29T00:00:00-0700

        // minute equivalent
        testAdding(.init(minute: 1), to: date, expected: Date(timeIntervalSince1970: 814950060.0))
        testAdding(.init(second: 60), to: date, expected: Date(timeIntervalSince1970: 814950000.0))
        testAdding(.init(hour: 1, minute: -59), to: date, expected: Date(timeIntervalSince1970: 814953660.0))
        testAdding(.init(day: 1, hour: -23, minute: -59), to: date, expected: Date(timeIntervalSince1970: 815043660.0))
        testAdding(.init(minute: -1), to: date, expected: Date(timeIntervalSince1970: 814953540.0))
        testAdding(.init(second: -60), to: date, expected: Date(timeIntervalSince1970: 814950000.0))
        testAdding(.init(hour: -1, minute: 59), to: date, expected: Date(timeIntervalSince1970: 815036340.0))
        testAdding(.init(day: -1, hour: 23, minute: 59), to: date, expected: Date(timeIntervalSince1970: 814949940.0))

        date = Date(timeIntervalSince1970: 814953599.0) // 1995-10-29T00:59:59-0700

        // second equivalent
        testAdding(.init(second: 1), to: date, expected: Date(timeIntervalSince1970: 814953540.0))
        testAdding(.init(minute: 60, second: -59), to: date, expected: Date(timeIntervalSince1970: 814953540.0))
        testAdding(.init(hour: 1, second: -59), to: date, expected: Date(timeIntervalSince1970: 814957140.0))
        testAdding(.init(hour: 2, minute: -59, second: -59), to: date, expected: Date(timeIntervalSince1970: 814957200.0))
        testAdding(.init(second: -1), to: date, expected: Date(timeIntervalSince1970: 814953598.0))
        testAdding(.init(minute: -60, second: 59), to: date, expected: Date(timeIntervalSince1970: 814953598.0))
        testAdding(.init(hour: -1, second: 59), to: date, expected: Date(timeIntervalSince1970: 815036398.0))
        testAdding(.init(hour: -2, minute: 59, second: 59), to: date, expected: Date(timeIntervalSince1970: 815032738.0))

        // minute equivalent
        testAdding(.init(minute: 1), to: date, expected: Date(timeIntervalSince1970: 814950059.0))
        testAdding(.init(second: 60), to: date, expected: Date(timeIntervalSince1970: 814953599.0))
        testAdding(.init(hour: 1, minute: -59), to: date, expected: Date(timeIntervalSince1970: 814953659.0))
        testAdding(.init(day: 1, hour: -23, minute: -59), to: date, expected: Date(timeIntervalSince1970: 815043659.0))
        testAdding(.init(minute: -1), to: date, expected: Date(timeIntervalSince1970: 814953539.0))
        testAdding(.init(second: -60), to: date, expected: Date(timeIntervalSince1970: 814953599.0))
        testAdding(.init(hour: -1, minute: 59), to: date, expected: Date(timeIntervalSince1970: 815036339.0))
        testAdding(.init(day: -1, hour: 23, minute: 59), to: date, expected: Date(timeIntervalSince1970: 814949939.0))

        date = Date(timeIntervalSince1970: 814953600.0) // 1995-10-29T01:00:00-0700

        // minute equivalent
        testAdding(.init(minute: 1), to: date, expected: Date(timeIntervalSince1970: 814953660.0))
        testAdding(.init(second: 60), to: date, expected: Date(timeIntervalSince1970: 814953600.0))
        testAdding(.init(hour: 1, minute: -59), to: date, expected: Date(timeIntervalSince1970: 814957260.0))
        testAdding(.init(day: 1, hour: -23, minute: -59), to: date, expected: Date(timeIntervalSince1970: 815047260.0))
        testAdding(.init(minute: -1), to: date, expected: Date(timeIntervalSince1970: 814957140.0))
        testAdding(.init(second: -60), to: date, expected: Date(timeIntervalSince1970: 814953600.0))
        testAdding(.init(hour: -1, minute: 59), to: date, expected: Date(timeIntervalSince1970: 814953540.0))
        testAdding(.init(day: -1, hour: 23, minute: 59), to: date, expected: Date(timeIntervalSince1970: 814867140.0))

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 815130000.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 812880000.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 814953600.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 813139200.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 815562000.0))

        date = Date(timeIntervalSince1970: 814953660.0) // 1995-10-29T01:01:00-0700

        // second equivalent
        testAdding(.init(second: 1), to: date, expected: Date(timeIntervalSince1970: 814953661.0))
        testAdding(.init(minute: 60, second: -59), to: date, expected: Date(timeIntervalSince1970: 814953661.0))
        testAdding(.init(hour: 1, second: -59), to: date, expected: Date(timeIntervalSince1970: 814957261.0))
        testAdding(.init(hour: 2, minute: -59, second: -59), to: date, expected: Date(timeIntervalSince1970: 814960921.0))
        testAdding(.init(second: -1), to: date, expected: Date(timeIntervalSince1970: 814953719.0))
        testAdding(.init(minute: -60, second: 59), to: date, expected: Date(timeIntervalSince1970: 814953719.0))
        testAdding(.init(hour: -1, second: 59), to: date, expected: Date(timeIntervalSince1970: 814950119.0))
        testAdding(.init(hour: -2, minute: 59, second: 59), to: date, expected: Date(timeIntervalSince1970: 815032859.0))

        // minute equivalent
        testAdding(.init(minute: 1), to: date, expected: Date(timeIntervalSince1970: 814953720.0))
        testAdding(.init(second: 60), to: date, expected: Date(timeIntervalSince1970: 814953660.0))
        testAdding(.init(hour: 1, minute: -59), to: date, expected: Date(timeIntervalSince1970: 814957320.0))
        testAdding(.init(day: 1, hour: -23, minute: -59), to: date, expected: Date(timeIntervalSince1970: 815047320.0))
        testAdding(.init(minute: -1), to: date, expected: Date(timeIntervalSince1970: 814953600.0))
        testAdding(.init(second: -60), to: date, expected: Date(timeIntervalSince1970: 814953660.0))
        testAdding(.init(hour: -1, minute: 59), to: date, expected: Date(timeIntervalSince1970: 814950000.0))
        testAdding(.init(day: -1, hour: 23, minute: 59), to: date, expected: Date(timeIntervalSince1970: 814863600.0))

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 815130060.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 812880060.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 814953660.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 813139260.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 815562060.0))

        date = Date(timeIntervalSince1970: 814953660.0) // 1995-10-29T01:01:00-0700

        // hour equivalent
        testAdding(.init(hour: 1), to: date, expected: Date(timeIntervalSince1970: 814957260.0))
        testAdding(.init(minute: 60), to: date, expected: Date(timeIntervalSince1970: 814953660.0))
        testAdding(.init(second: 3600), to: date, expected: Date(timeIntervalSince1970: 814953660.0))
        testAdding(.init(hour: 2, minute: -60), to: date, expected: Date(timeIntervalSince1970: 814960860.0))
        testAdding(.init(day: 1, hour: -23), to: date, expected: Date(timeIntervalSince1970: 815047260.0))
        testAdding(.init(day: 1, hour: -22, minute: -60), to: date, expected: Date(timeIntervalSince1970: 815050860.0))
        testAdding(.init(hour: -1), to: date, expected: Date(timeIntervalSince1970: 814950060.0))
        testAdding(.init(minute: -60), to: date, expected: Date(timeIntervalSince1970: 814953660.0))
        testAdding(.init(second: -3600), to: date, expected: Date(timeIntervalSince1970: 814953660.0))
        testAdding(.init(hour: -2, minute: 60), to: date, expected: Date(timeIntervalSince1970: 815032860.0))
        testAdding(.init(day: -1, hour: 23), to: date, expected: Date(timeIntervalSince1970: 814863660.0))
        testAdding(.init(day: -1, hour: 22, minute: 60), to: date, expected: Date(timeIntervalSince1970: 814946460.0))

        // day equivalent
        testAdding(.init(minute: 86400), to: date, expected: Date(timeIntervalSince1970: 814953660.0))
        testAdding(.init(hour: 24), to: date, expected: Date(timeIntervalSince1970: 814953660.0))
        testAdding(.init(day: 1), to: date, expected: Date(timeIntervalSince1970: 815043660.0))
        testAdding(.init(month: 1, day: -30), to: date, expected: Date(timeIntervalSince1970: 817635660.0))
        testAdding(.init(year: 1, month: -11, day: -30), to: date, expected: Date(timeIntervalSince1970: 849258060.0))
        testAdding(.init(weekday: 1), to: date, expected: Date(timeIntervalSince1970: 815040060.0))
        testAdding(.init(day: -1, weekday: 2), to: date, expected: Date(timeIntervalSince1970: 815040060.0))

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 815130060.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 812880060.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 814953660.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 813139260.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 815562060.0))
        testAdding(.init(yearForWeekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 846403260.0))
        testAdding(.init(weekOfYear: 52), to: date, expected: Date(timeIntervalSince1970: 814953660.0))
        testAdding(.init(weekOfYear: 53), to: date, expected: Date(timeIntervalSince1970: 815562060.0))
        testAdding(.init(yearForWeekOfYear: -1), to: date, expected: Date(timeIntervalSince1970: 783507660.0))
        // New:  1995-10-29T01:01:00-0700
        // Old:  1995-10-29T01:01:00-0800
        testAdding(.init(weekOfYear: -52), to: date, expected: Date(timeIntervalSince1970: 814957260.0))
        testAdding(.init(weekOfYear: -53), to: date, expected: Date(timeIntervalSince1970: 814348860.0))

        date = Date(timeIntervalSince1970: 814957387.0) // 1995-10-29T01:03:07-0800

        // hour equivalent
        testAdding(.init(hour: 1), to: date, expected: Date(timeIntervalSince1970: 814960987.0))
        testAdding(.init(minute: 60), to: date, expected: Date(timeIntervalSince1970: 814957387.0))
        testAdding(.init(second: 3600), to: date, expected: Date(timeIntervalSince1970: 814957387.0))
        testAdding(.init(hour: 2, minute: -60), to: date, expected: Date(timeIntervalSince1970: 814964587.0))
        testAdding(.init(day: 1, hour: -23), to: date, expected: Date(timeIntervalSince1970: 815047387.0))
        testAdding(.init(day: 1, hour: -22, minute: -60), to: date, expected: Date(timeIntervalSince1970: 815050987.0))
        testAdding(.init(hour: -1), to: date, expected: Date(timeIntervalSince1970: 814953787.0))
        testAdding(.init(minute: -60), to: date, expected: Date(timeIntervalSince1970: 814957387.0))
        testAdding(.init(second: -3600), to: date, expected: Date(timeIntervalSince1970: 814957387.0))
        testAdding(.init(hour: -2, minute: 60), to: date, expected: Date(timeIntervalSince1970: 815036587.0))
        testAdding(.init(day: -1, hour: 23), to: date, expected: Date(timeIntervalSince1970: 814863787.0))
        testAdding(.init(day: -1, hour: 22, minute: 60), to: date, expected: Date(timeIntervalSince1970: 814946587.0))

        // day equivalent
        testAdding(.init(minute: 86400), to: date, expected: Date(timeIntervalSince1970: 814957387.0))
        testAdding(.init(hour: 24), to: date, expected: Date(timeIntervalSince1970: 814957387.0))
        testAdding(.init(day: 1), to: date, expected: Date(timeIntervalSince1970: 815043787.0))
        testAdding(.init(month: 1, day: -30), to: date, expected: Date(timeIntervalSince1970: 817635787.0))
        testAdding(.init(year: 1, month: -11, day: -30), to: date, expected: Date(timeIntervalSince1970: 849258187.0))
        testAdding(.init(weekday: 1), to: date, expected: Date(timeIntervalSince1970: 815043787.0))
        testAdding(.init(day: -1, weekday: 2), to: date, expected: Date(timeIntervalSince1970: 815040187.0))

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 815130187.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 812880187.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 814953787.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 813142987.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 815562187.0))
        testAdding(.init(yearForWeekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 846403387.0))
        testAdding(.init(weekOfYear: 52), to: date, expected: Date(timeIntervalSince1970: 814953787.0))
        testAdding(.init(weekOfYear: 53), to: date, expected: Date(timeIntervalSince1970: 815562187.0))
        testAdding(.init(yearForWeekOfYear: -1), to: date, expected: Date(timeIntervalSince1970: 783507787.0))
        testAdding(.init(weekOfYear: -52), to: date, expected: Date(timeIntervalSince1970: 814957387.0))
        testAdding(.init(weekOfYear: -53), to: date, expected: Date(timeIntervalSince1970: 814348987.0))

        date = Date(timeIntervalSince1970: 814960987.0) // 1995-10-29T02:03:07-0800

        // hour equivalent
        testAdding(.init(hour: 1), to: date, expected: Date(timeIntervalSince1970: 814964587.0))
        testAdding(.init(minute: 60), to: date, expected: Date(timeIntervalSince1970: 814960987.0))
        testAdding(.init(second: 3600), to: date, expected: Date(timeIntervalSince1970: 814960987.0))
        testAdding(.init(hour: 2, minute: -60), to: date, expected: Date(timeIntervalSince1970: 814968187.0))
        testAdding(.init(day: 1, hour: -23), to: date, expected: Date(timeIntervalSince1970: 815050987.0))
        testAdding(.init(day: 1, hour: -22, minute: -60), to: date, expected: Date(timeIntervalSince1970: 815054587.0))
        testAdding(.init(hour: -1), to: date, expected: Date(timeIntervalSince1970: 814957387.0))
        testAdding(.init(minute: -60), to: date, expected: Date(timeIntervalSince1970: 814960987.0))
        testAdding(.init(second: -3600), to: date, expected: Date(timeIntervalSince1970: 814960987.0))
        testAdding(.init(hour: -2, minute: 60), to: date, expected: Date(timeIntervalSince1970: 814953787.0))
        testAdding(.init(day: -1, hour: 23), to: date, expected: Date(timeIntervalSince1970: 814867387.0))
        testAdding(.init(day: -1, hour: 22, minute: 60), to: date, expected: Date(timeIntervalSince1970: 814863787.0))

        // day equivalent
        testAdding(.init(minute: 86400), to: date, expected: Date(timeIntervalSince1970: 814960987.0))
        testAdding(.init(hour: 24), to: date, expected: Date(timeIntervalSince1970: 814960987.0))
        testAdding(.init(day: 1), to: date, expected: Date(timeIntervalSince1970: 815047387.0))
        testAdding(.init(month: 1, day: -30), to: date, expected: Date(timeIntervalSince1970: 817639387.0))
        testAdding(.init(year: 1, month: -11, day: -30), to: date, expected: Date(timeIntervalSince1970: 849261787.0))
        testAdding(.init(weekday: 1), to: date, expected: Date(timeIntervalSince1970: 815047387.0))
        testAdding(.init(day: -1, weekday: 2), to: date, expected: Date(timeIntervalSince1970: 815043787.0))

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 815133787.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 812883787.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 814960987.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 813146587.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 815565787.0))
        testAdding(.init(yearForWeekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 846410587.0))
        testAdding(.init(weekOfYear: 52), to: date, expected: Date(timeIntervalSince1970: 814960987.0))
        testAdding(.init(weekOfYear: 53), to: date, expected: Date(timeIntervalSince1970: 815565787.0))
        testAdding(.init(yearForWeekOfYear: -1), to: date, expected: Date(timeIntervalSince1970: 783511387.0))
        testAdding(.init(weekOfYear: -52), to: date, expected: Date(timeIntervalSince1970: 814960987.0))
        testAdding(.init(weekOfYear: -53), to: date, expected: Date(timeIntervalSince1970: 814352587.0))

        date = Date(timeIntervalSince1970: 814964587.0) // 1995-10-29T03:03:07-0800

        // hour equivalent
        testAdding(.init(hour: 1), to: date, expected: Date(timeIntervalSince1970: 814968187.0))
        testAdding(.init(minute: 60), to: date, expected: Date(timeIntervalSince1970: 814964587.0))
        testAdding(.init(second: 3600), to: date, expected: Date(timeIntervalSince1970: 814964587.0))
        testAdding(.init(hour: 2, minute: -60), to: date, expected: Date(timeIntervalSince1970: 814971787.0))
        testAdding(.init(day: 1, hour: -23), to: date, expected: Date(timeIntervalSince1970: 815054587.0))
        testAdding(.init(day: 1, hour: -22, minute: -60), to: date, expected: Date(timeIntervalSince1970: 815058187.0))
        testAdding(.init(hour: -1), to: date, expected: Date(timeIntervalSince1970: 814960987.0))
        testAdding(.init(minute: -60), to: date, expected: Date(timeIntervalSince1970: 814964587.0))
        testAdding(.init(second: -3600), to: date, expected: Date(timeIntervalSince1970: 814964587.0))
        testAdding(.init(hour: -2, minute: 60), to: date, expected: Date(timeIntervalSince1970: 814957387.0))
        testAdding(.init(day: -1, hour: 23), to: date, expected: Date(timeIntervalSince1970: 814870987.0))
        testAdding(.init(day: -1, hour: 22, minute: 60), to: date, expected: Date(timeIntervalSince1970: 814867387.0))

        // day equivalent
        testAdding(.init(minute: 86400), to: date, expected: Date(timeIntervalSince1970: 814964587.0))
        testAdding(.init(hour: 24), to: date, expected: Date(timeIntervalSince1970: 814964587.0))
        testAdding(.init(day: 1), to: date, expected: Date(timeIntervalSince1970: 815050987.0))
        testAdding(.init(month: 1, day: -30), to: date, expected: Date(timeIntervalSince1970: 817642987.0))
        testAdding(.init(year: 1, month: -11, day: -30), to: date, expected: Date(timeIntervalSince1970: 849265387.0))
        testAdding(.init(weekday: 1), to: date, expected: Date(timeIntervalSince1970: 815050987.0))
        testAdding(.init(day: -1, weekday: 2), to: date, expected: Date(timeIntervalSince1970: 815047387.0))

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 815137387.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 812887387.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 814964587.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 813150187.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 815569387.0))
        testAdding(.init(yearForWeekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 846414187.0))
        testAdding(.init(weekOfYear: 52), to: date, expected: Date(timeIntervalSince1970: 814964587.0))
        testAdding(.init(weekOfYear: 53), to: date, expected: Date(timeIntervalSince1970: 815569387.0))
        testAdding(.init(yearForWeekOfYear: -1), to: date, expected: Date(timeIntervalSince1970: 783514987.0))
        testAdding(.init(weekOfYear: -52), to: date, expected: Date(timeIntervalSince1970: 814964587.0))
        testAdding(.init(weekOfYear: -53), to: date, expected: Date(timeIntervalSince1970: 814356187.0))

        date = Date(timeIntervalSince1970: 814780860.0) // 1995-10-27T01:01:00-0700

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 815130060.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 812707260.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 814780860.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 814176060.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 815389260.0))
        testAdding(.init(year: 1), to: date, expected: Date(timeIntervalSince1970: 846403260.0))
        testAdding(.init(month: 12), to: date, expected: Date(timeIntervalSince1970: 814780860.0))
        testAdding(.init(day: 364), to: date, expected: Date(timeIntervalSince1970: 814089660.0))
        testAdding(.init(day: 365), to: date, expected: Date(timeIntervalSince1970: 814176060.0))
        testAdding(.init(day: 366), to: date, expected: Date(timeIntervalSince1970: 814262460.0))
        testAdding(.init(year: -1), to: date, expected: Date(timeIntervalSince1970: 783244860.0))
        testAdding(.init(month: -12), to: date, expected: Date(timeIntervalSince1970: 814780860.0))
        testAdding(.init(day: -364), to: date, expected: Date(timeIntervalSince1970: 812793660.0))
        testAdding(.init(day: -365), to: date, expected: Date(timeIntervalSince1970: 812707260.0))
        testAdding(.init(day: -366), to: date, expected: Date(timeIntervalSince1970: 812620860.0))

        date = Date(timeIntervalSince1970: 814784587.0) // 1995-10-27T02:03:07-0700

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 815133787.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 812710987.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 814784587.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 814179787.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 815392987.0))
        testAdding(.init(year: 1), to: date, expected: Date(timeIntervalSince1970: 846410587.0))
        testAdding(.init(month: 12), to: date, expected: Date(timeIntervalSince1970: 814784587.0))
        testAdding(.init(day: 364), to: date, expected: Date(timeIntervalSince1970: 814093387.0))
        testAdding(.init(day: 365), to: date, expected: Date(timeIntervalSince1970: 814179787.0))
        testAdding(.init(day: 366), to: date, expected: Date(timeIntervalSince1970: 814266187.0))
        testAdding(.init(year: -1), to: date, expected: Date(timeIntervalSince1970: 783248587.0))
        testAdding(.init(month: -12), to: date, expected: Date(timeIntervalSince1970: 814784587.0))
        testAdding(.init(day: -364), to: date, expected: Date(timeIntervalSince1970: 812797387.0))
        testAdding(.init(day: -365), to: date, expected: Date(timeIntervalSince1970: 812710987.0))
        testAdding(.init(day: -366), to: date, expected: Date(timeIntervalSince1970: 812624587.0))

        date = Date(timeIntervalSince1970: 814788187.0) // 1995-10-27T03:03:07-0700

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 815137387.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 812714587.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 814788187.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 814183387.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 815396587.0))
        testAdding(.init(year: 1), to: date, expected: Date(timeIntervalSince1970: 846414187.0))
        testAdding(.init(month: 12), to: date, expected: Date(timeIntervalSince1970: 814788187.0))
        testAdding(.init(day: 364), to: date, expected: Date(timeIntervalSince1970: 814096987.0))
        testAdding(.init(day: 365), to: date, expected: Date(timeIntervalSince1970: 814183387.0))
        testAdding(.init(day: 366), to: date, expected: Date(timeIntervalSince1970: 814269787.0))
        testAdding(.init(year: -1), to: date, expected: Date(timeIntervalSince1970: 783252187.0))
        testAdding(.init(month: -12), to: date, expected: Date(timeIntervalSince1970: 814788187.0))
        testAdding(.init(day: -364), to: date, expected: Date(timeIntervalSince1970: 812800987.0))
        testAdding(.init(day: -365), to: date, expected: Date(timeIntervalSince1970: 812714587.0))
        testAdding(.init(day: -366), to: date, expected: Date(timeIntervalSince1970: 812628187.0))

        date = Date(timeIntervalSince1970: 814791787.0) // 1995-10-27T04:03:07-0700

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 815140987.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 812718187.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 814791787.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 814186987.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 815400187.0))
        testAdding(.init(year: 1), to: date, expected: Date(timeIntervalSince1970: 846417787.0))
        testAdding(.init(month: 12), to: date, expected: Date(timeIntervalSince1970: 814791787.0))
        testAdding(.init(day: 364), to: date, expected: Date(timeIntervalSince1970: 814100587.0))
        testAdding(.init(day: 365), to: date, expected: Date(timeIntervalSince1970: 814186987.0))
        testAdding(.init(day: 366), to: date, expected: Date(timeIntervalSince1970: 814273387.0))
        testAdding(.init(year: -1), to: date, expected: Date(timeIntervalSince1970: 783255787.0))
        testAdding(.init(month: -12), to: date, expected: Date(timeIntervalSince1970: 814791787.0))
        testAdding(.init(day: -364), to: date, expected: Date(timeIntervalSince1970: 812804587.0))
        testAdding(.init(day: -365), to: date, expected: Date(timeIntervalSince1970: 812718187.0))
        testAdding(.init(day: -366), to: date, expected: Date(timeIntervalSince1970: 812631787.0))

        date = Date(timeIntervalSince1970: 812358000.0) // 1995-09-29T00:00:00-0700

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 810543600.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 810370800.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 812358000.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 810543600.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 812962800.0))

        // month equivalent
        testAdding(.init(month: 1), to: date, expected: Date(timeIntervalSince1970: 814950000.0))
        testAdding(.init(day: 30), to: date, expected: Date(timeIntervalSince1970: 812358000.0))
        testAdding(.init(day: 31), to: date, expected: Date(timeIntervalSince1970: 812444400.0))
        testAdding(.init(weekOfMonth: 4), to: date, expected: Date(timeIntervalSince1970: 812358000.0))
        testAdding(.init(weekOfMonth: 5), to: date, expected: Date(timeIntervalSince1970: 810543600.0))
        testAdding(.init(weekOfYear: 4), to: date, expected: Date(timeIntervalSince1970: 814777200.0))
        testAdding(.init(weekOfYear: 5), to: date, expected: Date(timeIntervalSince1970: 815385600.0))
        testAdding(.init(month: -1), to: date, expected: Date(timeIntervalSince1970: 809679600.0))
        testAdding(.init(day: -30), to: date, expected: Date(timeIntervalSince1970: 812358000.0))
        testAdding(.init(day: -31), to: date, expected: Date(timeIntervalSince1970: 812271600.0))
        testAdding(.init(weekOfMonth: -4), to: date, expected: Date(timeIntervalSince1970: 812358000.0))
        testAdding(.init(weekOfMonth: -5), to: date, expected: Date(timeIntervalSince1970: 811753200.0))
        testAdding(.init(weekOfYear: -4), to: date, expected: Date(timeIntervalSince1970: 809938800.0))
        testAdding(.init(weekOfYear: -5), to: date, expected: Date(timeIntervalSince1970: 809334000.0))

        date = Date(timeIntervalSince1970: 812361600.0) // 1995-09-29T01:00:00-0700

        // month equivalent
        testAdding(.init(month: 1), to: date, expected: Date(timeIntervalSince1970: 814953600.0))
        testAdding(.init(day: 30), to: date, expected: Date(timeIntervalSince1970: 812361600.0))
        testAdding(.init(day: 31), to: date, expected: Date(timeIntervalSince1970: 812448000.0))
        testAdding(.init(weekOfMonth: 4), to: date, expected: Date(timeIntervalSince1970: 812361600.0))
        testAdding(.init(weekOfMonth: 5), to: date, expected: Date(timeIntervalSince1970: 810547200.0))
        testAdding(.init(weekOfYear: 4), to: date, expected: Date(timeIntervalSince1970: 814780800.0))
        testAdding(.init(weekOfYear: 5), to: date, expected: Date(timeIntervalSince1970: 815389200.0))
        testAdding(.init(month: -1), to: date, expected: Date(timeIntervalSince1970: 809683200.0))
        testAdding(.init(day: -30), to: date, expected: Date(timeIntervalSince1970: 812361600.0))
        testAdding(.init(day: -31), to: date, expected: Date(timeIntervalSince1970: 812275200.0))
        testAdding(.init(weekOfMonth: -4), to: date, expected: Date(timeIntervalSince1970: 812361600.0))
        testAdding(.init(weekOfMonth: -5), to: date, expected: Date(timeIntervalSince1970: 811756800.0))
        testAdding(.init(weekOfYear: -4), to: date, expected: Date(timeIntervalSince1970: 809942400.0))
        testAdding(.init(weekOfYear: -5), to: date, expected: Date(timeIntervalSince1970: 809337600.0))

        date = Date(timeIntervalSince1970: 812365387.0) // 1995-09-29T02:03:07-0700

        // month equivalent
        testAdding(.init(month: 1), to: date, expected: Date(timeIntervalSince1970: 814960987.0))
        testAdding(.init(day: 30), to: date, expected: Date(timeIntervalSince1970: 812365387.0))
        testAdding(.init(day: 31), to: date, expected: Date(timeIntervalSince1970: 812451787.0))
        testAdding(.init(weekOfMonth: 4), to: date, expected: Date(timeIntervalSince1970: 812365387.0))
        testAdding(.init(weekOfMonth: 5), to: date, expected: Date(timeIntervalSince1970: 810550987.0))
        testAdding(.init(weekOfYear: 4), to: date, expected: Date(timeIntervalSince1970: 814784587.0))
        testAdding(.init(weekOfYear: 5), to: date, expected: Date(timeIntervalSince1970: 815392987.0))
        testAdding(.init(month: -1), to: date, expected: Date(timeIntervalSince1970: 809686987.0))
        testAdding(.init(day: -30), to: date, expected: Date(timeIntervalSince1970: 812365387.0))
        testAdding(.init(day: -31), to: date, expected: Date(timeIntervalSince1970: 812278987.0))
        testAdding(.init(weekOfMonth: -4), to: date, expected: Date(timeIntervalSince1970: 812365387.0))
        testAdding(.init(weekOfMonth: -5), to: date, expected: Date(timeIntervalSince1970: 811760587.0))
        testAdding(.init(weekOfYear: -4), to: date, expected: Date(timeIntervalSince1970: 809946187.0))
        testAdding(.init(weekOfYear: -5), to: date, expected: Date(timeIntervalSince1970: 809341387.0))

        date = Date(timeIntervalSince1970: 812368987.0) // 1995-09-29T03:03:07-0700

        // month equivalent
        testAdding(.init(month: 1), to: date, expected: Date(timeIntervalSince1970: 814964587.0))
        testAdding(.init(day: 30), to: date, expected: Date(timeIntervalSince1970: 812368987.0))
        testAdding(.init(day: 31), to: date, expected: Date(timeIntervalSince1970: 812455387.0))
        testAdding(.init(weekOfMonth: 4), to: date, expected: Date(timeIntervalSince1970: 812368987.0))
        testAdding(.init(weekOfMonth: 5), to: date, expected: Date(timeIntervalSince1970: 810554587.0))
        testAdding(.init(weekOfYear: 4), to: date, expected: Date(timeIntervalSince1970: 814788187.0))
        testAdding(.init(weekOfYear: 5), to: date, expected: Date(timeIntervalSince1970: 815396587.0))
        testAdding(.init(month: -1), to: date, expected: Date(timeIntervalSince1970: 809690587.0))
        testAdding(.init(day: -30), to: date, expected: Date(timeIntervalSince1970: 812368987.0))
        testAdding(.init(day: -31), to: date, expected: Date(timeIntervalSince1970: 812282587.0))
        testAdding(.init(weekOfMonth: -4), to: date, expected: Date(timeIntervalSince1970: 812368987.0))
        testAdding(.init(weekOfMonth: -5), to: date, expected: Date(timeIntervalSince1970: 811764187.0))
        testAdding(.init(weekOfYear: -4), to: date, expected: Date(timeIntervalSince1970: 809949787.0))
        testAdding(.init(weekOfYear: -5), to: date, expected: Date(timeIntervalSince1970: 809344987.0))

        date = Date(timeIntervalSince1970: 812372587.0) // 1995-09-29T04:03:07-0700

        // month equivalent
        testAdding(.init(month: 1), to: date, expected: Date(timeIntervalSince1970: 814968187.0))
        testAdding(.init(day: 30), to: date, expected: Date(timeIntervalSince1970: 812372587.0))
        testAdding(.init(day: 31), to: date, expected: Date(timeIntervalSince1970: 812458987.0))
        testAdding(.init(weekOfMonth: 4), to: date, expected: Date(timeIntervalSince1970: 812372587.0))
        testAdding(.init(weekOfMonth: 5), to: date, expected: Date(timeIntervalSince1970: 810558187.0))
        testAdding(.init(weekOfYear: 4), to: date, expected: Date(timeIntervalSince1970: 814791787.0))
        testAdding(.init(weekOfYear: 5), to: date, expected: Date(timeIntervalSince1970: 815400187.0))
        testAdding(.init(month: -1), to: date, expected: Date(timeIntervalSince1970: 809694187.0))
        testAdding(.init(day: -30), to: date, expected: Date(timeIntervalSince1970: 812372587.0))
        testAdding(.init(day: -31), to: date, expected: Date(timeIntervalSince1970: 812286187.0))
        testAdding(.init(weekOfMonth: -4), to: date, expected: Date(timeIntervalSince1970: 812372587.0))
        testAdding(.init(weekOfMonth: -5), to: date, expected: Date(timeIntervalSince1970: 811767787.0))
        testAdding(.init(weekOfYear: -4), to: date, expected: Date(timeIntervalSince1970: 809953387.0))
        testAdding(.init(weekOfYear: -5), to: date, expected: Date(timeIntervalSince1970: 809348587.0))

        date = Date(timeIntervalSince1970: 812534400.0) // 1995-10-01T01:00:00-0700

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 813139200.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 813139200.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 812534400.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 813744000.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 813139200.0))

        date = Date(timeIntervalSince1970: 812530800.0) // 1995-10-01T00:00:00-0700

        // month equivalent
        testAdding(.init(month: 1), to: date, expected: Date(timeIntervalSince1970: 815212800.0))
        testAdding(.init(day: 30), to: date, expected: Date(timeIntervalSince1970: 815126400.0))
        testAdding(.init(day: 31), to: date, expected: Date(timeIntervalSince1970: 812530800.0))
        testAdding(.init(weekOfMonth: 4), to: date, expected: Date(timeIntervalSince1970: 814950000.0))
        testAdding(.init(weekOfMonth: 5), to: date, expected: Date(timeIntervalSince1970: 815126400.0))
        testAdding(.init(weekOfYear: 4), to: date, expected: Date(timeIntervalSince1970: 814950000.0))
        testAdding(.init(weekOfYear: 5), to: date, expected: Date(timeIntervalSince1970: 815558400.0))
        testAdding(.init(month: -1), to: date, expected: Date(timeIntervalSince1970: 809938800.0))
        testAdding(.init(day: -30), to: date, expected: Date(timeIntervalSince1970: 812617200.0))
        testAdding(.init(day: -31), to: date, expected: Date(timeIntervalSince1970: 812530800.0))
        testAdding(.init(weekOfMonth: -4), to: date, expected: Date(timeIntervalSince1970: 813135600.0))
        testAdding(.init(weekOfMonth: -5), to: date, expected: Date(timeIntervalSince1970: 815126400.0))
        testAdding(.init(weekOfYear: -4), to: date, expected: Date(timeIntervalSince1970: 810111600.0))
        testAdding(.init(weekOfYear: -5), to: date, expected: Date(timeIntervalSince1970: 809506800.0))

        date = Date(timeIntervalSince1970: 812534400.0) // 1995-10-01T01:00:00-0700

        // month equivalent
        testAdding(.init(month: 1), to: date, expected: Date(timeIntervalSince1970: 815216400.0))
        testAdding(.init(day: 30), to: date, expected: Date(timeIntervalSince1970: 815130000.0))
        testAdding(.init(day: 31), to: date, expected: Date(timeIntervalSince1970: 812534400.0))
        testAdding(.init(weekOfMonth: 4), to: date, expected: Date(timeIntervalSince1970: 814953600.0))
        testAdding(.init(weekOfMonth: 5), to: date, expected: Date(timeIntervalSince1970: 815130000.0))
        testAdding(.init(weekOfYear: 4), to: date, expected: Date(timeIntervalSince1970: 814953600.0))
        testAdding(.init(weekOfYear: 5), to: date, expected: Date(timeIntervalSince1970: 815562000.0))
        testAdding(.init(month: -1), to: date, expected: Date(timeIntervalSince1970: 809942400.0))
        testAdding(.init(day: -30), to: date, expected: Date(timeIntervalSince1970: 812620800.0))
        testAdding(.init(day: -31), to: date, expected: Date(timeIntervalSince1970: 812534400.0))
        testAdding(.init(weekOfMonth: -4), to: date, expected: Date(timeIntervalSince1970: 813139200.0))
        testAdding(.init(weekOfMonth: -5), to: date, expected: Date(timeIntervalSince1970: 815130000.0))
        testAdding(.init(weekOfYear: -4), to: date, expected: Date(timeIntervalSince1970: 810115200.0))
        testAdding(.init(weekOfYear: -5), to: date, expected: Date(timeIntervalSince1970: 809510400.0))

        date = Date(timeIntervalSince1970: 812538187.0) // 1995-10-01T02:03:07-0700

        // month equivalent
        testAdding(.init(month: 1), to: date, expected: Date(timeIntervalSince1970: 815220187.0))
        testAdding(.init(day: 30), to: date, expected: Date(timeIntervalSince1970: 815133787.0))
        testAdding(.init(day: 31), to: date, expected: Date(timeIntervalSince1970: 812538187.0))
        testAdding(.init(weekOfMonth: 4), to: date, expected: Date(timeIntervalSince1970: 814960987.0))
        testAdding(.init(weekOfMonth: 5), to: date, expected: Date(timeIntervalSince1970: 815133787.0))
        testAdding(.init(weekOfYear: 4), to: date, expected: Date(timeIntervalSince1970: 814960987.0))
        testAdding(.init(weekOfYear: 5), to: date, expected: Date(timeIntervalSince1970: 815565787.0))
        testAdding(.init(month: -1), to: date, expected: Date(timeIntervalSince1970: 809946187.0))
        testAdding(.init(day: -30), to: date, expected: Date(timeIntervalSince1970: 812624587.0))
        testAdding(.init(day: -31), to: date, expected: Date(timeIntervalSince1970: 812538187.0))
        testAdding(.init(weekOfMonth: -4), to: date, expected: Date(timeIntervalSince1970: 813142987.0))
        testAdding(.init(weekOfMonth: -5), to: date, expected: Date(timeIntervalSince1970: 815133787.0))
        testAdding(.init(weekOfYear: -4), to: date, expected: Date(timeIntervalSince1970: 810118987.0))
        testAdding(.init(weekOfYear: -5), to: date, expected: Date(timeIntervalSince1970: 809514187.0))

        date = Date(timeIntervalSince1970: 812541787.0) // 1995-10-01T03:03:07-0700

        // month equivalent
        testAdding(.init(month: 1), to: date, expected: Date(timeIntervalSince1970: 815223787.0))
        testAdding(.init(day: 30), to: date, expected: Date(timeIntervalSince1970: 815137387.0))
        testAdding(.init(day: 31), to: date, expected: Date(timeIntervalSince1970: 812541787.0))
        testAdding(.init(weekOfMonth: 4), to: date, expected: Date(timeIntervalSince1970: 814964587.0))
        testAdding(.init(weekOfMonth: 5), to: date, expected: Date(timeIntervalSince1970: 815137387.0))
        testAdding(.init(weekOfYear: 4), to: date, expected: Date(timeIntervalSince1970: 814964587.0))
        testAdding(.init(weekOfYear: 5), to: date, expected: Date(timeIntervalSince1970: 815569387.0))
        testAdding(.init(month: -1), to: date, expected: Date(timeIntervalSince1970: 809949787.0))
        testAdding(.init(day: -30), to: date, expected: Date(timeIntervalSince1970: 812628187.0))
        testAdding(.init(day: -31), to: date, expected: Date(timeIntervalSince1970: 812541787.0))
        testAdding(.init(weekOfMonth: -4), to: date, expected: Date(timeIntervalSince1970: 813146587.0))
        testAdding(.init(weekOfMonth: -5), to: date, expected: Date(timeIntervalSince1970: 815137387.0))
        testAdding(.init(weekOfYear: -4), to: date, expected: Date(timeIntervalSince1970: 810122587.0))
        testAdding(.init(weekOfYear: -5), to: date, expected: Date(timeIntervalSince1970: 809517787.0))

        date = Date(timeIntervalSince1970: 812545387.0) // 1995-10-01T04:03:07-0700

        // month equivalent
        testAdding(.init(month: 1), to: date, expected: Date(timeIntervalSince1970: 815227387.0))
        testAdding(.init(day: 30), to: date, expected: Date(timeIntervalSince1970: 815140987.0))
        testAdding(.init(day: 31), to: date, expected: Date(timeIntervalSince1970: 812545387.0))
        testAdding(.init(weekOfMonth: 4), to: date, expected: Date(timeIntervalSince1970: 814968187.0))
        testAdding(.init(weekOfMonth: 5), to: date, expected: Date(timeIntervalSince1970: 815140987.0))
        testAdding(.init(weekOfYear: 4), to: date, expected: Date(timeIntervalSince1970: 814968187.0))
        testAdding(.init(weekOfYear: 5), to: date, expected: Date(timeIntervalSince1970: 815572987.0))
        testAdding(.init(month: -1), to: date, expected: Date(timeIntervalSince1970: 809953387.0))
        testAdding(.init(day: -30), to: date, expected: Date(timeIntervalSince1970: 812631787.0))
        testAdding(.init(day: -31), to: date, expected: Date(timeIntervalSince1970: 812545387.0))
        testAdding(.init(weekOfMonth: -4), to: date, expected: Date(timeIntervalSince1970: 813150187.0))
        testAdding(.init(weekOfMonth: -5), to: date, expected: Date(timeIntervalSince1970: 815140987.0))
        testAdding(.init(weekOfYear: -4), to: date, expected: Date(timeIntervalSince1970: 810126187.0))
        testAdding(.init(weekOfYear: -5), to: date, expected: Date(timeIntervalSince1970: 809521387.0))

        date = Date(timeIntervalSince1970: 814345200.0) // 1995-10-22T00:00:00-0700

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 814950000.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 814950000.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 814345200.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 812530800.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 814950000.0))

        date = Date(timeIntervalSince1970: 814348800.0) // 1995-10-22T01:00:00-0700

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 814953600.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 814953600.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 814348800.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 812534400.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 814953600.0))

        date = Date(timeIntervalSince1970: 814352587.0) // 1995-10-22T02:03:07-0700

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 814960987.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 814960987.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 814352587.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 812538187.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 814960987.0))

        date = Date(timeIntervalSince1970: 814356187.0) // 1995-10-22T03:03:07-0700

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 814964587.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 814964587.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 814356187.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 812541787.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 814964587.0))

        date = Date(timeIntervalSince1970: 814359787.0) // 1995-10-22T04:03:07-0700

        // week equivalent
        testAdding(.init(weekOfMonth: 1), to: date, expected: Date(timeIntervalSince1970: 814968187.0))
        testAdding(.init(day: 7), to: date, expected: Date(timeIntervalSince1970: 814968187.0))
        testAdding(.init(weekday: 7), to: date, expected: Date(timeIntervalSince1970: 814359787.0))
        testAdding(.init(weekdayOrdinal: 7), to: date, expected: Date(timeIntervalSince1970: 812545387.0))
        testAdding(.init(weekOfYear: 1), to: date, expected: Date(timeIntervalSince1970: 814968187.0))
    }

    func testAdd_DST() {
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(identifier: "America/Los_Angeles")!, locale: nil, firstWeekday: 3, minimumDaysInFirstWeek: 5, gregorianStartDate: nil)

        let fmt = Date.ISO8601FormatStyle(timeZone: gregorianCalendar.timeZone)
        func test(addField field: Calendar.Component, value: Int, to addingToDate: Date, expectedDate: Date, _ file: StaticString = #file, _ line: UInt = #line) {
            let components = DateComponents(component: field, value: value)!
            let result = gregorianCalendar.date(byAdding: components, to: addingToDate, wrappingComponents: false)!
            let actualDiff = result.timeIntervalSince(addingToDate)
            let expectedDiff = expectedDate.timeIntervalSince(addingToDate)

            let msg = "actual diff: \(actualDiff), expected: \(expectedDiff), actual ti = \(result.timeIntervalSince1970), expected ti = \(expectedDate.timeIntervalSince1970), actual = \(fmt.format(result)), expected = \(fmt.format(expectedDate))"
            XCTAssertEqual(result, expectedDate, msg, file: file, line: line)
        }

        var date: Date

        date = Date(timeIntervalSince1970: 828867787.0) // 1996-04-07T01:03:07-0800
        test(addField: .era, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828867787.0))
        test(addField: .era, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828867787.0))
        test(addField: .year, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 860400187.0))
        test(addField: .year, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 797241787.0))
        test(addField: .yearForWeekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 860317387.0))
        test(addField: .yearForWeekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 797414587.0))
        test(addField: .month, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 831456187.0))
        test(addField: .month, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 826189387.0))
        test(addField: .day, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828950587.0))
        test(addField: .day, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828781387.0))
        test(addField: .hour, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828871387.0))
        test(addField: .hour, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828864187.0))
        test(addField: .minute, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828867847.0))
        test(addField: .minute, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828867727.0))
        test(addField: .second, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828867788.0))
        test(addField: .second, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828867786.0))
        test(addField: .weekday, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828950587.0))
        test(addField: .weekday, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828781387.0))
        test(addField: .weekdayOrdinal, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 829468987.0))
        test(addField: .weekdayOrdinal, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828262987.0))
        test(addField: .weekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 829468987.0))
        test(addField: .weekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828262987.0))
        test(addField: .weekOfMonth, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 829468987.0))
        test(addField: .weekOfMonth, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828262987.0))
        test(addField: .nanosecond, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828867787.0))
        test(addField: .nanosecond, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828867787.0))

        date = Date(timeIntervalSince1970: 828871387.0) // 1996-04-07T03:03:07-0700
        test(addField: .era, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828871387.0))
        test(addField: .era, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828871387.0))
        test(addField: .year, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 860407387.0))
        test(addField: .year, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 797248987.0))
        test(addField: .yearForWeekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 860320987.0))
        test(addField: .yearForWeekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 797421787.0))
        test(addField: .month, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 831463387.0))
        test(addField: .month, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 826196587.0))
        test(addField: .day, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828957787.0))
        test(addField: .day, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828788587.0))
        test(addField: .hour, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828874987.0))
        test(addField: .hour, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828867787.0))
        test(addField: .minute, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828871447.0))
        test(addField: .minute, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828871327.0))
        test(addField: .second, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828871388.0))
        test(addField: .second, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828871386.0))
        test(addField: .weekday, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828957787.0))
        test(addField: .weekday, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828788587.0))
        test(addField: .weekdayOrdinal, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 829476187.0))
        test(addField: .weekdayOrdinal, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828270187.0))
        test(addField: .weekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 829476187.0))
        test(addField: .weekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828270187.0))
        test(addField: .weekOfMonth, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 829476187.0))
        test(addField: .weekOfMonth, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828270187.0))
        test(addField: .nanosecond, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828871387.0))
        test(addField: .nanosecond, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828871387.0))

        date = Date(timeIntervalSince1970: 828874987.0) // 1996-04-07T04:03:07-0700
        test(addField: .era, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828874987.0))
        test(addField: .era, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828874987.0))
        test(addField: .year, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 860410987.0))
        test(addField: .year, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 797252587.0))
        test(addField: .yearForWeekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 860324587.0))
        test(addField: .yearForWeekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 797425387.0))
        test(addField: .month, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 831466987.0))
        test(addField: .month, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 826200187.0))
        test(addField: .day, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828961387.0))
        test(addField: .day, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828792187.0))
        test(addField: .hour, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828878587.0))
        test(addField: .hour, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828871387.0))
        test(addField: .minute, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828875047.0))
        test(addField: .minute, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828874927.0))
        test(addField: .second, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828874988.0))
        test(addField: .second, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828874986.0))
        test(addField: .weekday, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828961387.0))
        test(addField: .weekday, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828792187.0))
        test(addField: .weekdayOrdinal, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 829479787.0))
        test(addField: .weekdayOrdinal, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828273787.0))
        test(addField: .weekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 829479787.0))
        test(addField: .weekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828273787.0))
        test(addField: .weekOfMonth, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 829479787.0))
        test(addField: .weekOfMonth, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828273787.0))
        test(addField: .nanosecond, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828874987.0))
        test(addField: .nanosecond, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828874987.0))

        date = Date(timeIntervalSince1970: 846403387.0) // 1996-10-27T01:03:07-0700
        test(addField: .era, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846403387.0))
        // Previously this returns 1996-10-27T01:03:07-0800
        // New behavior just returns the date unchanged, like other non-DST transition dates
        test(addField: .era, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846403387.0))
        test(addField: .year, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 877942987.0))
        test(addField: .year, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814780987.0))
        test(addField: .yearForWeekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 877852987.0))
        test(addField: .yearForWeekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814957387.0))
        test(addField: .month, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 849085387.0))
        test(addField: .month, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 843811387.0))
        test(addField: .day, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846493387.0))
        test(addField: .day, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846316987.0))
        test(addField: .hour, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846406987.0))
        test(addField: .hour, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846399787.0))
        test(addField: .minute, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846403447.0))
        test(addField: .minute, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846403327.0))
        test(addField: .second, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846403388.0))
        test(addField: .second, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846403386.0))
        test(addField: .weekday, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846493387.0))
        test(addField: .weekday, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846316987.0))
        test(addField: .weekdayOrdinal, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 847011787.0))
        test(addField: .weekdayOrdinal, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 845798587.0))
        test(addField: .weekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 847011787.0))
        test(addField: .weekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 845798587.0))
        test(addField: .weekOfMonth, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 847011787.0))
        test(addField: .weekOfMonth, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 845798587.0))
        test(addField: .nanosecond, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846403387.0))
        test(addField: .nanosecond, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846403387.0))

        date = Date(timeIntervalSince1970: 846406987.0) // 1996-10-27T01:03:07-0800
        // Previously this returns 1996-10-27T01:03:07-0700
        // Now it returns date unchanged, as other non-DST transition dates.
        test(addField: .era, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846406987.0))
        test(addField: .era, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846406987.0))
        test(addField: .year, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 877942987.0))
        test(addField: .year, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814780987.0))
        test(addField: .yearForWeekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 877852987.0))
        test(addField: .yearForWeekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814957387.0)) // 1995-10-29T01:03:07-0800

        test(addField: .month, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 849085387.0))
        test(addField: .month, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 843811387.0))
        test(addField: .day, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846493387.0))
        test(addField: .day, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846316987.0))
        test(addField: .hour, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846410587.0))
        test(addField: .hour, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846403387.0))
        test(addField: .minute, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846407047.0))
        test(addField: .minute, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846406927.0))
        test(addField: .second, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846406988.0))
        test(addField: .second, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846406986.0))
        test(addField: .weekday, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846493387.0))
        test(addField: .weekday, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846316987.0))
        test(addField: .weekdayOrdinal, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 847011787.0))
        test(addField: .weekdayOrdinal, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 845798587.0))
        test(addField: .weekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 847011787.0))
        test(addField: .weekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 845798587.0))
        test(addField: .weekOfMonth, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 847011787.0))
        test(addField: .weekOfMonth, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 845798587.0))
        test(addField: .nanosecond, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846406987.0))
        test(addField: .nanosecond, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846406987.0))

        date = Date(timeIntervalSince1970: 846410587.0) // 1996-10-27T02:03:07-0800
        test(addField: .era, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846410587.0))
        test(addField: .era, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846410587.0))
        test(addField: .year, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 877946587.0))
        test(addField: .year, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814784587.0))
        test(addField: .yearForWeekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 877860187.0))
        test(addField: .yearForWeekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814960987.0))
        test(addField: .month, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 849088987.0))
        test(addField: .month, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 843814987.0))
        test(addField: .day, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846496987.0))
        test(addField: .day, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846320587.0))
        test(addField: .hour, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846414187.0))
        test(addField: .hour, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846406987.0))
        test(addField: .minute, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846410647.0))
        test(addField: .minute, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846410527.0))
        test(addField: .second, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846410588.0))
        test(addField: .second, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846410586.0))
        test(addField: .weekday, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846496987.0))
        test(addField: .weekday, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846320587.0))
        test(addField: .weekdayOrdinal, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 847015387.0))
        test(addField: .weekdayOrdinal, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 845802187.0))
        test(addField: .weekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 847015387.0))
        test(addField: .weekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 845802187.0))
        test(addField: .weekOfMonth, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 847015387.0))
        test(addField: .weekOfMonth, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 845802187.0))
        test(addField: .nanosecond, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846410587.0))
        test(addField: .nanosecond, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846410587.0))

        date = Date(timeIntervalSince1970: 846414187.0) // 1996-10-27T03:03:07-0800
        test(addField: .era, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846414187.0))
        test(addField: .era, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846414187.0))
        test(addField: .year, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 877950187.0))
        test(addField: .year, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814788187.0))
        test(addField: .yearForWeekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 877863787.0))
        test(addField: .yearForWeekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814964587.0))
        test(addField: .month, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 849092587.0))
        test(addField: .month, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 843818587.0))
        test(addField: .day, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846500587.0))
        test(addField: .day, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846324187.0))
        test(addField: .hour, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846417787.0))
        test(addField: .hour, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846410587.0))
        test(addField: .minute, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846414247.0))
        test(addField: .minute, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846414127.0))
        test(addField: .second, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846414188.0))
        test(addField: .second, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846414186.0))
        test(addField: .weekday, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846500587.0))
        test(addField: .weekday, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846324187.0))
        test(addField: .weekdayOrdinal, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 847018987.0))
        test(addField: .weekdayOrdinal, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 845805787.0))
        test(addField: .weekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 847018987.0))
        test(addField: .weekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 845805787.0))
        test(addField: .weekOfMonth, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 847018987.0))
        test(addField: .weekOfMonth, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 845805787.0))
        test(addField: .nanosecond, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846414187.0))
        test(addField: .nanosecond, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846414187.0))

        date = Date(timeIntervalSince1970: 814953787.0) // 1995-10-29T01:03:07-0700
        test(addField: .era, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 814953787.0))
        // Previously this returns 1995-10-29T01:03:07-0800
        // New behavior just returns the date unchanged, like other non-DST transition dates
        test(addField: .era, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814953787.0))
        test(addField: .year, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846579787.0))
        test(addField: .year, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 783417787.0))
        test(addField: .yearForWeekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846403387.0))
        test(addField: .yearForWeekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 783507787.0))
        test(addField: .month, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 817635787.0))
        test(addField: .month, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 812361787.0))
        test(addField: .day, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 815043787.0))
        test(addField: .day, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814867387.0))
        test(addField: .hour, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 814957387.0))
        test(addField: .hour, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814950187.0))
        test(addField: .minute, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 814953847.0))
        test(addField: .minute, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814953727.0))
        test(addField: .second, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 814953788.0))
        test(addField: .second, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814953786.0))
        test(addField: .weekday, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 815043787.0))
        test(addField: .weekday, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814867387.0))
        test(addField: .weekdayOrdinal, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 815562187.0))
        test(addField: .weekdayOrdinal, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814348987.0))
        test(addField: .weekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 815562187.0))
        test(addField: .weekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814348987.0))
        test(addField: .weekOfMonth, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 815562187.0))
        test(addField: .weekOfMonth, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814348987.0))
        test(addField: .nanosecond, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 814953787.0))
        test(addField: .nanosecond, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814953787.0))

        date = Date(timeIntervalSince1970: 814957387.0) // 1995-10-29T01:03:07-0800
        test(addField: .era, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 814957387.0))
        test(addField: .era, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814957387.0))
        test(addField: .year, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846579787.0))
        test(addField: .year, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 783417787.0))
        test(addField: .yearForWeekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846403387.0))
        test(addField: .yearForWeekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 783507787.0))
        test(addField: .month, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 817635787.0))
        test(addField: .month, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 812361787.0))
        test(addField: .day, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 815043787.0))
        test(addField: .day, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814867387.0))
        test(addField: .hour, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 814960987.0))
        test(addField: .hour, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814953787.0))
        test(addField: .minute, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 814957447.0))
        test(addField: .minute, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814957327.0))
        test(addField: .second, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 814957388.0))
        test(addField: .second, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814957386.0))
        test(addField: .weekday, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 815043787.0))
        test(addField: .weekday, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814867387.0))
        test(addField: .weekdayOrdinal, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 815562187.0))
        test(addField: .weekdayOrdinal, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814348987.0))
        test(addField: .weekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 815562187.0))
        test(addField: .weekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814348987.0))
        test(addField: .weekOfMonth, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 815562187.0))
        test(addField: .weekOfMonth, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814348987.0))
        test(addField: .nanosecond, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 814957387.0))
        test(addField: .nanosecond, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814957387.0))

        date = Date(timeIntervalSince1970: 814960987.0) // 1995-10-29T02:03:07-0800
        test(addField: .era, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 814960987.0))
        test(addField: .era, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814960987.0))
        test(addField: .year, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846583387.0))
        test(addField: .year, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 783421387.0))
        test(addField: .yearForWeekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846410587.0))
        test(addField: .yearForWeekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 783511387.0))
        test(addField: .month, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 817639387.0))
        test(addField: .month, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 812365387.0))
        test(addField: .day, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 815047387.0))
        test(addField: .day, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814870987.0))
        test(addField: .hour, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 814964587.0))
        test(addField: .hour, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814957387.0))
        test(addField: .minute, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 814961047.0))
        test(addField: .minute, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814960927.0))
        test(addField: .second, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 814960988.0))
        test(addField: .second, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814960986.0))
        test(addField: .weekday, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 815047387.0))
        test(addField: .weekday, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814870987.0))
        test(addField: .weekdayOrdinal, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 815565787.0))
        test(addField: .weekdayOrdinal, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814352587.0))
        test(addField: .weekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 815565787.0))
        test(addField: .weekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814352587.0))
        test(addField: .weekOfMonth, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 815565787.0))
        test(addField: .weekOfMonth, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814352587.0))
        test(addField: .nanosecond, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 814960987.0))
        test(addField: .nanosecond, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814960987.0))

        date = Date(timeIntervalSince1970: 814964587.0) // 1995-10-29T03:03:07-0800
        test(addField: .era, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 814964587.0))
        test(addField: .era, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814964587.0))
        test(addField: .year, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846586987.0))
        test(addField: .year, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 783424987.0))
        test(addField: .yearForWeekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846414187.0))
        test(addField: .yearForWeekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 783514987.0))
        test(addField: .month, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 817642987.0))
        test(addField: .month, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 812368987.0))
        test(addField: .day, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 815050987.0))
        test(addField: .day, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814874587.0))
        test(addField: .hour, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 814968187.0))
        test(addField: .hour, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814960987.0))
        test(addField: .minute, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 814964647.0))
        test(addField: .minute, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814964527.0))
        test(addField: .second, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 814964588.0))
        test(addField: .second, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814964586.0))
        test(addField: .weekday, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 815050987.0))
        test(addField: .weekday, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814874587.0))
        test(addField: .weekdayOrdinal, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 815569387.0))
        test(addField: .weekdayOrdinal, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814356187.0))
        test(addField: .weekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 815569387.0))
        test(addField: .weekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814356187.0))
        test(addField: .weekOfMonth, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 815569387.0))
        test(addField: .weekOfMonth, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814356187.0))
        test(addField: .nanosecond, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 814964587.0))
        test(addField: .nanosecond, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814964587.0))
    }

    func testAdd_Wrap_DST() {
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(identifier: "America/Los_Angeles")!, locale: nil, firstWeekday: 3, minimumDaysInFirstWeek: 5, gregorianStartDate: nil)

        let fmt = Date.ISO8601FormatStyle(timeZone: gregorianCalendar.timeZone)
        func test(addField field: Calendar.Component, value: Int, to addingToDate: Date, expectedDate: Date, _ file: StaticString = #file, _ line: UInt = #line) {
            let components = DateComponents(component: field, value: value)!
            let result = gregorianCalendar.date(byAdding: components, to: addingToDate, wrappingComponents: true)!
            let msg = "actual = \(fmt.format(result)), expected = \(fmt.format(expectedDate))"
            XCTAssertEqual(result, expectedDate, msg, file: file, line: line)
        }

        var date: Date
        date = Date(timeIntervalSince1970: 828867787.0) // 1996-04-07T01:03:07-0800
        test(addField: .era, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828867787.0))
        test(addField: .era, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828867787.0))
        test(addField: .year, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 860400187.0))
        test(addField: .year, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 797241787.0))
        test(addField: .yearForWeekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 860317387.0))
        test(addField: .yearForWeekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 797414587.0))
        test(addField: .month, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 831456187.0))
        test(addField: .month, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 826189387.0))
        test(addField: .day, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828950587.0))
        test(addField: .day, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828781387.0))
        test(addField: .hour, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828871387.0))
        test(addField: .hour, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828864187.0))
        test(addField: .minute, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828867847.0))
        test(addField: .minute, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828867727.0))
        test(addField: .second, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828867788.0))
        test(addField: .second, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828867786.0))
        test(addField: .weekday, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828954187.0))
        test(addField: .weekday, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828781387.0))
        test(addField: .weekdayOrdinal, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 829472587.0))
        test(addField: .weekdayOrdinal, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 830682187.0))
        test(addField: .weekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 829468987.0))
        test(addField: .weekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828262987.0))
        test(addField: .weekOfMonth, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 829468987.0))
        test(addField: .weekOfMonth, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 830851387.0))
        test(addField: .nanosecond, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828867787.0))
        test(addField: .nanosecond, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828867787.0))

        date = Date(timeIntervalSince1970: 828871387.0) // 1996-04-07T03:03:07-0700
        test(addField: .era, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828871387.0))
        test(addField: .era, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828871387.0))
        test(addField: .year, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 860407387.0))
        test(addField: .year, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 797248987.0))
        test(addField: .yearForWeekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 860320987.0))
        test(addField: .yearForWeekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 797421787.0))
        test(addField: .month, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 831463387.0))
        test(addField: .month, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 826196587.0))
        test(addField: .day, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828957787.0))
        test(addField: .day, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828788587.0))
        test(addField: .hour, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828874987.0))
        test(addField: .hour, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828867787.0))
        test(addField: .minute, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828871447.0))
        test(addField: .minute, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828871327.0))
        test(addField: .second, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828871388.0))
        test(addField: .second, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828871386.0))
        test(addField: .weekday, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828957787.0))
        test(addField: .weekday, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828784987.0))
        test(addField: .weekdayOrdinal, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 829476187.0))
        test(addField: .weekdayOrdinal, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 830685787.0))
        test(addField: .weekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 829476187.0))
        test(addField: .weekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828270187.0))
        test(addField: .weekOfMonth, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 829476187.0))
        test(addField: .weekOfMonth, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 830858587.0))
        test(addField: .nanosecond, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828871387.0))
        test(addField: .nanosecond, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828871387.0))

        date = Date(timeIntervalSince1970: 828874987.0) // 1996-04-07T04:03:07-0700
        test(addField: .era, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828874987.0))
        test(addField: .era, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828874987.0))
        test(addField: .year, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 860410987.0))
        test(addField: .year, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 797252587.0))
        test(addField: .yearForWeekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 860324587.0))
        test(addField: .yearForWeekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 797425387.0))
        test(addField: .month, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 831466987.0))
        test(addField: .month, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 826200187.0))
        test(addField: .day, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828961387.0))
        test(addField: .day, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828792187.0))
        test(addField: .hour, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828878587.0))
        test(addField: .hour, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828871387.0))
        test(addField: .minute, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828875047.0))
        test(addField: .minute, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828874927.0))
        test(addField: .second, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828874988.0))
        test(addField: .second, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828874986.0))
        test(addField: .weekday, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828961387.0))
        test(addField: .weekday, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828788587.0))
        test(addField: .weekdayOrdinal, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 829479787.0))
        test(addField: .weekdayOrdinal, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 830689387.0))
        test(addField: .weekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 829479787.0))
        test(addField: .weekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828273787.0))
        test(addField: .weekOfMonth, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 829479787.0))
        test(addField: .weekOfMonth, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 830862187.0))
        test(addField: .nanosecond, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 828874987.0))
        test(addField: .nanosecond, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 828874987.0))

        date = Date(timeIntervalSince1970: 846406987.0) // 1996-10-27T01:03:07-0800
        test(addField: .era, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846406987.0))
        test(addField: .era, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846406987.0))
        test(addField: .year, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 877942987.0))
        test(addField: .year, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814780987.0))
        test(addField: .yearForWeekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 877852987.0))
        test(addField: .yearForWeekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814957387.0))
        test(addField: .month, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 849085387.0))
        test(addField: .month, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 843811387.0))
        test(addField: .day, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846493387.0))
        test(addField: .day, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846316987.0))
        test(addField: .hour, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846410587.0))
        test(addField: .hour, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846403387.0))
        test(addField: .minute, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846407047.0))
        test(addField: .minute, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846406927.0))
        test(addField: .second, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846406988.0))
        test(addField: .second, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846406986.0))
        test(addField: .weekday, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846493387.0))
        test(addField: .weekday, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846320587.0))
        test(addField: .weekdayOrdinal, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 844592587.0))
        test(addField: .weekdayOrdinal, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 845802187.0))
        test(addField: .weekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 847011787.0))
        test(addField: .weekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 845798587.0))
        test(addField: .weekOfMonth, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846752587.0))
        test(addField: .weekOfMonth, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 845798587.0))
        test(addField: .nanosecond, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846406987.0))
        test(addField: .nanosecond, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846406987.0))

        date = Date(timeIntervalSince1970: 846410587.0) // 1996-10-27T02:03:07-0800
        test(addField: .era, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846410587.0))
        test(addField: .era, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846410587.0))
        test(addField: .year, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 877946587.0))
        test(addField: .year, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814784587.0))
        test(addField: .yearForWeekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 877860187.0))
        test(addField: .yearForWeekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814960987.0))
        test(addField: .month, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 849088987.0))
        test(addField: .month, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 843814987.0))
        test(addField: .day, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846496987.0))
        test(addField: .day, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846320587.0))
        test(addField: .hour, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846414187.0))
        test(addField: .hour, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846406987.0))
        test(addField: .minute, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846410647.0))
        test(addField: .minute, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846410527.0))
        test(addField: .second, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846410588.0))
        test(addField: .second, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846410586.0))
        test(addField: .weekday, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846496987.0))
        test(addField: .weekday, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846324187.0))
        test(addField: .weekdayOrdinal, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 844596187.0))
        test(addField: .weekdayOrdinal, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 845805787.0))
        test(addField: .weekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 847015387.0))
        test(addField: .weekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 845802187.0))
        test(addField: .weekOfMonth, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846756187.0))
        test(addField: .weekOfMonth, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 845802187.0))
        test(addField: .nanosecond, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846410587.0))
        test(addField: .nanosecond, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846410587.0))

        date = Date(timeIntervalSince1970: 846414187.0) // 1996-10-27T03:03:07-0800
        test(addField: .era, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846414187.0))
        test(addField: .era, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846414187.0))
        test(addField: .year, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 877950187.0))
        test(addField: .year, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814788187.0))
        test(addField: .yearForWeekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 877863787.0))
        test(addField: .yearForWeekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 814964587.0))
        test(addField: .month, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 849092587.0))
        test(addField: .month, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 843818587.0))
        test(addField: .day, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846500587.0))
        test(addField: .day, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846324187.0))
        test(addField: .hour, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846417787.0))
        test(addField: .hour, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846410587.0))
        test(addField: .minute, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846414247.0))
        test(addField: .minute, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846414127.0))
        test(addField: .second, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846414188.0))
        test(addField: .second, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846414186.0))
        test(addField: .weekday, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846500587.0))
        test(addField: .weekday, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846327787.0))
        test(addField: .weekdayOrdinal, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 844599787.0))
        test(addField: .weekdayOrdinal, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 845809387.0))
        test(addField: .weekOfYear, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 847018987.0))
        test(addField: .weekOfYear, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 845805787.0))
        test(addField: .weekOfMonth, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846759787.0))
        test(addField: .weekOfMonth, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 845805787.0))
        test(addField: .nanosecond, value: 1, to: date, expectedDate: Date(timeIntervalSince1970: 846414187.0))
        test(addField: .nanosecond, value: -1, to: date, expectedDate: Date(timeIntervalSince1970: 846414187.0))
    }

    // MARK: - Ordinality

    func testOrdinality() {
        let cal = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(secondsFromGMT: 3600)!, locale: nil, firstWeekday: 5, minimumDaysInFirstWeek: 4, gregorianStartDate: nil)

        func test(_ small: Calendar.Component, in large: Calendar.Component, for date: Date, expected: Int?, file: StaticString = #file, line: UInt = #line) {
            let result = cal.ordinality(of: small, in: large, for: date)
            XCTAssertEqual(result, expected,  "small: \(small), large: \(large)", file: file, line: line)
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

    func testOrdinality_DST() {
        let cal = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(identifier: "America/Los_Angeles")!, locale: nil, firstWeekday: 5, minimumDaysInFirstWeek: 4, gregorianStartDate: nil)

        func test(_ small: Calendar.Component, in large: Calendar.Component, for date: Date, expected: Int?, file: StaticString = #file, line: UInt = #line) {
            let result = cal.ordinality(of: small, in: large, for: date)
            XCTAssertEqual(result, expected,  "small: \(small), large: \(large)", file: file, line: line)
        }

        var date: Date

        date = Date(timeIntervalSince1970: 851990400.0) // 1996-12-30T16:00:00-0800 (1996-12-31T00:00:00Z)
        test(.hour, in: .month, for: date, expected: 713)
        test(.minute, in: .month, for: date, expected: 42721)
        test(.hour, in: .day, for: date, expected: 17)
        test(.minute, in: .day, for: date, expected: 961)
        test(.minute, in: .hour, for: date, expected: 1)

        date = Date(timeIntervalSince1970: 820483200.0) // 1996-01-01T00:00:00-0800 (1996-01-01T08:00:00Z)
        test(.hour, in: .month, for: date, expected: 1)
        test(.minute, in: .month, for: date, expected: 1)
        test(.hour, in: .day, for: date, expected: 1)
        test(.minute, in: .day, for: date, expected: 1)
        test(.minute, in: .hour, for: date, expected: 1)

        date = Date(timeIntervalSince1970: 828867787.0) // 1996-04-07T01:03:07-0800 (1996-04-07T09:03:07Z)
        test(.hour, in: .month, for: date, expected: 146)
        test(.minute, in: .month, for: date, expected: 8704)
        test(.hour, in: .day, for: date, expected: 2)
        test(.minute, in: .day, for: date, expected: 64)
        test(.minute, in: .hour, for: date, expected: 4)

        date = Date(timeIntervalSince1970: 828871387.0) // 1996-04-07T03:03:07-0700 (1996-04-07T10:03:07Z)
        test(.hour, in: .month, for: date, expected: 148)
        test(.minute, in: .month, for: date, expected: 8824)
        test(.hour, in: .day, for: date, expected: 4)
        test(.minute, in: .day, for: date, expected: 184)
        test(.minute, in: .hour, for: date, expected: 4)

        date = Date(timeIntervalSince1970: 828874987.0) // 1996-04-07T04:03:07-0700 (1996-04-07T11:03:07Z)
        test(.hour, in: .month, for: date, expected: 149)
        test(.minute, in: .month, for: date, expected: 8884)
        test(.hour, in: .day, for: date, expected: 5)
        test(.minute, in: .day, for: date, expected: 244)
        test(.minute, in: .hour, for: date, expected: 4)

        date = Date(timeIntervalSince1970: 846414187.0) // 1996-10-27T03:03:07-0800 (1996-10-27T11:03:07Z)
        test(.hour, in: .day, for: date, expected: 4)
        test(.minute, in: .day, for: date, expected: 184)
        test(.hour, in: .month, for: date, expected: 628)
        test(.minute, in: .month, for: date, expected: 37624)
        test(.minute, in: .hour, for: date, expected: 4)

        date = Date(timeIntervalSince1970: 845121787.0) // 1996-10-12T05:03:07-0700 (1996-10-12T12:03:07Z)
        test(.hour, in: .day, for: date, expected: 6)
        test(.minute, in: .day, for: date, expected: 304)
        test(.hour, in: .month, for: date, expected: 270)
        test(.minute, in: .month, for: date, expected: 16144)
        test(.minute, in: .hour, for: date, expected: 4)
    }

    func testStartOf() {
        let firstWeekday = 2
        let minimumDaysInFirstWeek = 4
        let timeZone = TimeZone(secondsFromGMT: -3600 * 8)!
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: nil)
        func test(_ unit: Calendar.Component, at date: Date, expected: Date, file: StaticString = #file, line: UInt = #line) {
            let new = gregorianCalendar.start(of: unit, at: date)!
            XCTAssertEqual(new, expected, file: file, line: line)
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

    func testStartOf_DST() {
        let firstWeekday = 2
        let minimumDaysInFirstWeek = 4
        let timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: nil)
        func test(_ unit: Calendar.Component, at date: Date, expected: Date, file: StaticString = #file, line: UInt = #line) {
            let new = gregorianCalendar.start(of: unit, at: date)!
            XCTAssertEqual(new, expected, file: file, line: line)
        }

        var date: Date
        date = Date(timeIntervalSince1970: 820483200.0) // 1996-01-01T00:00:00-0800 (1996-01-01T08:00:00Z)
        test(.hour, at: date, expected: date)
        test(.day, at: date, expected: date)
        test(.month, at: date, expected: date)
        test(.year, at: date, expected: date)
        test(.yearForWeekOfYear, at: date, expected: date)
        test(.weekOfYear, at: date, expected: date)

        date = Date(timeIntervalSince1970: 828867787.0) // 1996-04-07 09:03:07 +0000
        test(.second, at: date, expected: Date(timeIntervalSince1970: 828867787.0)) // expect: 1996-04-07 09:03:07 +0000
        test(.minute, at: date, expected: Date(timeIntervalSince1970: 828867780.0)) // expect: 1996-04-07 09:03:00 +0000
        test(.hour, at: date, expected: Date(timeIntervalSince1970: 828867600.0)) // expect: 1996-04-07 09:00:00 +0000
        test(.day, at: date, expected: Date(timeIntervalSince1970: 828864000.0)) // expect: 1996-04-07 08:00:00 +0000
        test(.month, at: date, expected: Date(timeIntervalSince1970: 828345600.0)) // expect: 1996-04-01 08:00:00 +0000
        test(.year, at: date, expected: Date(timeIntervalSince1970: 820483200.0)) // expect: 1996-01-01 08:00:00 +0000
        test(.yearForWeekOfYear, at: date, expected: Date(timeIntervalSince1970: 820483200.0)) // expect: 1996-01-01 08:00:00 +0000
        test(.weekOfYear, at: date, expected: Date(timeIntervalSince1970: 828345600.0)) // expect: 1996-04-01 08:00:00 +0000
        test(.weekOfMonth, at: date, expected: Date(timeIntervalSince1970: 828345600.0)) // expect: 1996-04-01 08:00:00 +0000
        test(.weekday, at: date, expected: Date(timeIntervalSince1970: 828864000.0)) // expect: 1996-04-07 08:00:00 +0000
        test(.quarter, at: date, expected: Date(timeIntervalSince1970: 828345600.0)) // expect: 1996-04-01 08:00:00 +0000

        date = Date(timeIntervalSince1970: 828871387.0) // 1996-04-07 10:03:07 +0000
        test(.second, at: date, expected: Date(timeIntervalSince1970: 828871387.0)) // expect: 1996-04-07 10:03:07 +0000
        test(.minute, at: date, expected: Date(timeIntervalSince1970: 828871380.0)) // expect: 1996-04-07 10:03:00 +0000
        test(.hour, at: date, expected: Date(timeIntervalSince1970: 828871200.0)) // expect: 1996-04-07 10:00:00 +0000
        test(.day, at: date, expected: Date(timeIntervalSince1970: 828864000.0)) // expect: 1996-04-07 08:00:00 +0000
        test(.month, at: date, expected: Date(timeIntervalSince1970: 828345600.0)) // expect: 1996-04-01 08:00:00 +0000
        test(.year, at: date, expected: Date(timeIntervalSince1970: 820483200.0)) // expect: 1996-01-01 08:00:00 +0000
        test(.yearForWeekOfYear, at: date, expected: Date(timeIntervalSince1970: 820483200.0)) // expect: 1996-01-01 08:00:00 +0000
        test(.weekOfYear, at: date, expected: Date(timeIntervalSince1970: 828345600.0)) // expect: 1996-04-01 08:00:00 +0000
        test(.weekOfMonth, at: date, expected: Date(timeIntervalSince1970: 828345600.0)) // expect: 1996-04-01 08:00:00 +0000
        test(.weekday, at: date, expected: Date(timeIntervalSince1970: 828864000.0)) // expect: 1996-04-07 08:00:00 +0000
        test(.quarter, at: date, expected: Date(timeIntervalSince1970: 828345600.0)) // expect: 1996-04-01 08:00:00 +0000

        date = Date(timeIntervalSince1970: 828874987.0) // 1996-04-07 11:03:07 +0000
        test(.second, at: date, expected: Date(timeIntervalSince1970: 828874987.0)) // expect: 1996-04-07 11:03:07 +0000
        test(.minute, at: date, expected: Date(timeIntervalSince1970: 828874980.0)) // expect: 1996-04-07 11:03:00 +0000
        test(.hour, at: date, expected: Date(timeIntervalSince1970: 828874800.0)) // expect: 1996-04-07 11:00:00 +0000
        test(.day, at: date, expected: Date(timeIntervalSince1970: 828864000.0)) // expect: 1996-04-07 08:00:00 +0000
        test(.month, at: date, expected: Date(timeIntervalSince1970: 828345600.0)) // expect: 1996-04-01 08:00:00 +0000
        test(.year, at: date, expected: Date(timeIntervalSince1970: 820483200.0)) // expect: 1996-01-01 08:00:00 +0000
        test(.yearForWeekOfYear, at: date, expected: Date(timeIntervalSince1970: 820483200.0)) // expect: 1996-01-01 08:00:00 +0000
        test(.weekOfYear, at: date, expected: Date(timeIntervalSince1970: 828345600.0)) // expect: 1996-04-01 08:00:00 +0000
        test(.weekOfMonth, at: date, expected: Date(timeIntervalSince1970: 828345600.0)) // expect: 1996-04-01 08:00:00 +0000
        test(.weekday, at: date, expected: Date(timeIntervalSince1970: 828864000.0)) // expect: 1996-04-07 08:00:00 +0000
        test(.quarter, at: date, expected: Date(timeIntervalSince1970: 828345600.0)) // expect: 1996-04-01 08:00:00 +0000

        date = Date(timeIntervalSince1970: 846414187.0) // 1996-10-27 11:03:07 +0000
        test(.second, at: date, expected: Date(timeIntervalSince1970: 846414187.0)) // expect: 1996-10-27 11:03:07 +0000
        test(.minute, at: date, expected: Date(timeIntervalSince1970: 846414180.0)) // expect: 1996-10-27 11:03:00 +0000
        test(.hour, at: date, expected: Date(timeIntervalSince1970: 846414000.0)) // expect: 1996-10-27 11:00:00 +0000
        test(.day, at: date, expected: Date(timeIntervalSince1970: 846399600.0)) // expect: 1996-10-27 07:00:00 +0000
        test(.month, at: date, expected: Date(timeIntervalSince1970: 844153200.0)) // expect: 1996-10-01 07:00:00 +0000
        test(.year, at: date, expected: Date(timeIntervalSince1970: 820483200.0)) // expect: 1996-01-01 08:00:00 +0000
        test(.yearForWeekOfYear, at: date, expected: Date(timeIntervalSince1970: 820483200.0)) // expect: 1996-01-01 08:00:00 +0000
        test(.weekOfYear, at: date, expected: Date(timeIntervalSince1970: 845881200.0)) // expect: 1996-10-21 07:00:00 +0000
        test(.weekOfMonth, at: date, expected: Date(timeIntervalSince1970: 845881200.0)) // expect: 1996-10-21 07:00:00 +0000
        test(.weekday, at: date, expected: Date(timeIntervalSince1970: 846399600.0)) // expect: 1996-10-27 07:00:00 +0000
        test(.quarter, at: date, expected: Date(timeIntervalSince1970: 844153200.0)) // expect: 1996-10-01 07:00:00 +0000

        date = Date(timeIntervalSince1970: 846410587.0) // 1996-10-27 10:03:07 +0000
        test(.second, at: date, expected: Date(timeIntervalSince1970: 846410587.0)) // expect: 1996-10-27 10:03:07 +0000
        test(.minute, at: date, expected: Date(timeIntervalSince1970: 846410580.0)) // expect: 1996-10-27 10:03:00 +0000
        test(.hour, at: date, expected: Date(timeIntervalSince1970: 846410400.0)) // expect: 1996-10-27 10:00:00 +0000
        test(.day, at: date, expected: Date(timeIntervalSince1970: 846399600.0)) // expect: 1996-10-27 07:00:00 +0000
        test(.month, at: date, expected: Date(timeIntervalSince1970: 844153200.0)) // expect: 1996-10-01 07:00:00 +0000
        test(.year, at: date, expected: Date(timeIntervalSince1970: 820483200.0)) // expect: 1996-01-01 08:00:00 +0000
        test(.yearForWeekOfYear, at: date, expected: Date(timeIntervalSince1970: 820483200.0)) // expect: 1996-01-01 08:00:00 +0000
        test(.weekOfYear, at: date, expected: Date(timeIntervalSince1970: 845881200.0)) // expect: 1996-10-21 07:00:00 +0000
        test(.weekOfMonth, at: date, expected: Date(timeIntervalSince1970: 845881200.0)) // expect: 1996-10-21 07:00:00 +0000
        test(.weekday, at: date, expected: Date(timeIntervalSince1970: 846399600.0)) // expect: 1996-10-27 07:00:00 +0000
        test(.quarter, at: date, expected: Date(timeIntervalSince1970: 844153200.0)) // expect: 1996-10-01 07:00:00 +0000

        date = Date(timeIntervalSince1970: 846406987.0) // 1996-10-27 09:03:07 +0000
        test(.second, at: date, expected: Date(timeIntervalSince1970: 846406987.0)) // expect: 1996-10-27 09:03:07 +0000
        test(.minute, at: date, expected: Date(timeIntervalSince1970: 846406980.0)) // expect: 1996-10-27 09:03:00 +0000
        test(.hour, at: date, expected: Date(timeIntervalSince1970: 846406800.0)) // expect: 1996-10-27 09:00:00 +0000
        test(.day, at: date, expected: Date(timeIntervalSince1970: 846399600.0)) // expect: 1996-10-27 07:00:00 +0000
        test(.month, at: date, expected: Date(timeIntervalSince1970: 844153200.0)) // expect: 1996-10-01 07:00:00 +0000
        test(.year, at: date, expected: Date(timeIntervalSince1970: 820483200.0)) // expect: 1996-01-01 08:00:00 +0000
        test(.yearForWeekOfYear, at: date, expected: Date(timeIntervalSince1970: 820483200.0)) // expect: 1996-01-01 08:00:00 +0000
        test(.weekOfYear, at: date, expected: Date(timeIntervalSince1970: 845881200.0)) // expect: 1996-10-21 07:00:00 +0000
        test(.weekOfMonth, at: date, expected: Date(timeIntervalSince1970: 845881200.0)) // expect: 1996-10-21 07:00:00 +0000
        test(.weekday, at: date, expected: Date(timeIntervalSince1970: 846399600.0)) // expect: 1996-10-27 07:00:00 +0000
        test(.quarter, at: date, expected: Date(timeIntervalSince1970: 844153200.0)) // expect: 1996-10-01 07:00:00 +0000
    }

    // MARK: - Weekend

    func testIsDateInWeekend() {
        let c = _CalendarGregorian(identifier: .gregorian, timeZone: .gmt, locale: nil, firstWeekday: 1, minimumDaysInFirstWeek: 1, gregorianStartDate: nil)

        let sat0000_mon0000 = WeekendRange(onsetTime: 0, ceaseTime: 0, start: 7, end: 2) // Sat 00:00:00 ..< Mon 00:00:00
        let sat1200_sun1200 = WeekendRange(onsetTime: 43200, ceaseTime: 43200, start: 7, end: 1) // Sat 12:00:00 ..< Sun 12:00:00
        let sat_sun = WeekendRange(onsetTime: 0, ceaseTime: 86400, start: 7, end: 1) // Sat 00:00:00 ... Sun 23:59:59
        let mon = WeekendRange(onsetTime: 0, ceaseTime: 86400, start: 2, end: 2)
        let sunPM = WeekendRange(onsetTime: 43200, ceaseTime: 86400, start: 1, end: 1) // Sun 12:00:00 ... Sun 23:59:59
        let mon_tue = WeekendRange(onsetTime: 0, ceaseTime: 86400, start: 2, end: 3) // Mon 00:00:00 ... Tue 23:59:59

        var date = Date(timeIntervalSince1970: 846320587) // 1996-10-26, Sat 09:03:07
        XCTAssertTrue(c.isDateInWeekend(date, weekendRange: sat0000_mon0000))
        XCTAssertFalse(c.isDateInWeekend(date, weekendRange: sat1200_sun1200))
        XCTAssertTrue(c.isDateInWeekend(date, weekendRange: sat_sun))

        date = Date(timeIntervalSince1970: 846406987.0) // 1996-10-27, Sun 09:03:07
        XCTAssertTrue(c.isDateInWeekend(date, weekendRange: sat0000_mon0000))
        XCTAssertTrue(c.isDateInWeekend(date, weekendRange: sat1200_sun1200))
        XCTAssertTrue(c.isDateInWeekend(date, weekendRange: sat_sun))
        XCTAssertFalse(c.isDateInWeekend(date, weekendRange: sunPM))
        XCTAssertFalse(c.isDateInWeekend(date, weekendRange: mon))
        XCTAssertFalse(c.isDateInWeekend(date, weekendRange: mon_tue))

        date = Date(timeIntervalSince1970: 846450187) // 1996-10-27, Sun 19:03:07
        XCTAssertTrue(c.isDateInWeekend(date, weekendRange: sat0000_mon0000))
        XCTAssertFalse(c.isDateInWeekend(date, weekendRange: sat1200_sun1200))
        XCTAssertTrue(c.isDateInWeekend(date, weekendRange: sat_sun))        
        XCTAssertTrue(c.isDateInWeekend(date, weekendRange: sunPM))
        XCTAssertFalse(c.isDateInWeekend(date, weekendRange: mon))
        XCTAssertFalse(c.isDateInWeekend(date, weekendRange: mon_tue))

        date = Date(timeIntervalSince1970: 846536587) // 1996-10-28, Mon 19:03:07
        XCTAssertFalse(c.isDateInWeekend(date, weekendRange: sat0000_mon0000))
        XCTAssertFalse(c.isDateInWeekend(date, weekendRange: sat1200_sun1200))
        XCTAssertFalse(c.isDateInWeekend(date, weekendRange: sat_sun))
        XCTAssertFalse(c.isDateInWeekend(date, weekendRange: sunPM))
        XCTAssertTrue(c.isDateInWeekend(date, weekendRange: mon))
        XCTAssertTrue(c.isDateInWeekend(date, weekendRange: mon_tue))
    }

    func testIsDateInWeekend_wholeDays() {
        let c = _CalendarGregorian(identifier: .gregorian, timeZone: .gmt, locale: nil, firstWeekday: 1, minimumDaysInFirstWeek: 1, gregorianStartDate: nil)

        let sat_mon = WeekendRange(start: 7, end: 2)
        let sat_sun = WeekendRange(start: 7, end: 1)
        let mon = WeekendRange(start: 2, end: 2)
        let sun = WeekendRange(start: 1, end: 1)
        let mon_tue = WeekendRange(start: 2, end: 3)

        var date = Date(timeIntervalSince1970: 846320587) // 1996-10-26, Sat 09:03:07
        XCTAssertTrue(c.isDateInWeekend(date, weekendRange: sat_mon))
        XCTAssertTrue(c.isDateInWeekend(date, weekendRange: sat_sun))
        XCTAssertFalse(c.isDateInWeekend(date, weekendRange: sun))

        date = Date(timeIntervalSince1970: 846406987.0) // 1996-10-27, Sun 09:03:07
        XCTAssertTrue(c.isDateInWeekend(date, weekendRange: sat_mon))
        XCTAssertTrue(c.isDateInWeekend(date, weekendRange: sat_sun))
        XCTAssertTrue(c.isDateInWeekend(date, weekendRange: sun))
        XCTAssertFalse(c.isDateInWeekend(date, weekendRange: mon))
        XCTAssertFalse(c.isDateInWeekend(date, weekendRange: mon_tue))

        date = Date(timeIntervalSince1970: 846450187) // 1996-10-27, Sun 19:03:07
        XCTAssertTrue(c.isDateInWeekend(date, weekendRange: sat_mon))
        XCTAssertTrue(c.isDateInWeekend(date, weekendRange: sat_sun))
        XCTAssertTrue(c.isDateInWeekend(date, weekendRange: sun))
        XCTAssertFalse(c.isDateInWeekend(date, weekendRange: mon))
        XCTAssertFalse(c.isDateInWeekend(date, weekendRange: mon_tue))

        date = Date(timeIntervalSince1970: 846536587) // 1996-10-28, Mon 19:03:07
        XCTAssertTrue(c.isDateInWeekend(date, weekendRange: sat_mon))
        XCTAssertFalse(c.isDateInWeekend(date, weekendRange: sat_sun))
        XCTAssertFalse(c.isDateInWeekend(date, weekendRange: sun))
        XCTAssertTrue(c.isDateInWeekend(date, weekendRange: mon))
        XCTAssertTrue(c.isDateInWeekend(date, weekendRange: mon_tue))
    }

    // MARK: - DateInterval

    func testDateInterval() {
        let calendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(secondsFromGMT: -28800)!, locale: nil, firstWeekday: 3, minimumDaysInFirstWeek: 5, gregorianStartDate: nil)

        func test(_ c: Calendar.Component, _ date: Date, expectedStart start: Date?, end: Date?, file: StaticString = #file, line: UInt = #line) {
            let new = calendar.dateInterval(of: c, for: date)
            let new_start = new?.start
            let new_end = new?.end

            XCTAssertEqual(new_start, start, "interval start did not match", file: file, line: line)
            XCTAssertEqual(new_end, end, "interval end did not match", file: file, line: line)
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

    func testDateInterval_DST() {
        let calendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(identifier: "America/Los_Angeles")!, locale: nil, firstWeekday: 3, minimumDaysInFirstWeek: 5, gregorianStartDate: nil)
        func test(_ c: Calendar.Component, _ date: Date, expectedStart start: Date, end: Date, file: StaticString = #file, line: UInt = #line) {
            let new = calendar.dateInterval(of: c, for: date)!
            let new_start = new.start
            let new_end = new.end
            let delta = 0.005
            XCTAssertEqual(Double(new_start.timeIntervalSinceReferenceDate), Double(start.timeIntervalSinceReferenceDate), accuracy: delta, file: file, line: line)
            XCTAssertEqual(Double(new_end.timeIntervalSinceReferenceDate), Double(end.timeIntervalSinceReferenceDate), accuracy: delta, file: file, line: line)
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

    // MARK: - Range of

    func testRangeOf() {
        let calendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(secondsFromGMT: -28800)!, locale: nil, firstWeekday: 1, minimumDaysInFirstWeek: 4, gregorianStartDate: nil)

        func test(_ small: Calendar.Component, in large: Calendar.Component, for date: Date, expected: Range<Int>?, file: StaticString = #file, line: UInt = #line) {
            let new = calendar.range(of: small, in: large, for: date)
            XCTAssertEqual(new, expected, file: file, line: line)
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

    func testDateComponentsFromStartToEnd() {
        let calendar = _CalendarGregorian(identifier: .gregorian, timeZone: .gmt, locale: nil, firstWeekday: 1, minimumDaysInFirstWeek: 4, gregorianStartDate: nil)
        var start: Date!
        var end: Date!
        func test(_ components: Calendar.ComponentSet, expected: DateComponents, file: StaticString = #file, line: UInt = #line) {
            let actual = calendar.dateComponents(components, from: start, to: end)
            XCTAssertEqual(actual, expected, file: file, line: line)
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
    }

    func testDifference() {
        let calendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(secondsFromGMT: -28800)!, locale: nil, firstWeekday: 1, minimumDaysInFirstWeek: 4, gregorianStartDate: nil)
        var start: Date!
        var end: Date!
        func test(_ component: Calendar.Component, expected: Int, file: StaticString = #file, line: UInt = #line) {
            let (actualDiff, _) = try! calendar.difference(inComponent: component, from: start, to: end)
            XCTAssertEqual(actualDiff, expected, file: file, line: line)
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
        test(.nanosecond, expected: 0)

        start = Date(timeIntervalSince1970: 852105540.0) // 1996-12-31 23:59:00
        end = Date(timeIntervalSince1970: 857203205.0) // 1997-03-01 00:00:05
        test(.hour, expected: 1416)
        test(.minute, expected: 84961)
        test(.second, expected: 5097665)
        test(.nanosecond, expected: 0)

        start = Date(timeIntervalSince1970: 825580720.0) // 1996-02-28 23:58:40
        end = Date(timeIntervalSince1970: 825580805.0) // 1996-02-29 00:00:05
        test(.hour, expected: 0)
        test(.minute, expected: 1)
        test(.second, expected: 85)
        test(.nanosecond, expected: 0)

        start = Date(timeIntervalSince1970: 825580720.0) // 1996-02-28 23:58:40
        end = Date(timeIntervalSince1970: 825667205.0) // 1996-03-01 00:00:05
        test(.hour, expected: 24)
        test(.minute, expected: 1441)
        test(.second, expected: 86485)
        test(.nanosecond, expected: 0)

        start = Date(timeIntervalSince1970: 794044710.0) // 1995-02-28 23:58:30
        end = Date(timeIntervalSince1970: 794044805.0) // 1995-03-01 00:00:05
        test(.hour, expected: 0)
        test(.minute, expected: 1)
        test(.second, expected: 95)
        test(.nanosecond, expected: 0)

        start = Date(timeIntervalSince1970: 857203205.0) // 1997-03-01 00:00:05
        end = Date(timeIntervalSince1970: 852105520.0) // 1996-12-31 23:58:40
        test(.hour, expected: -1416)
        test(.minute, expected: -84961)
        test(.second, expected: -5097685)
        test(.nanosecond, expected: 0)

        start = Date(timeIntervalSince1970: 825667205.0) // 1996-03-01 00:00:05
        end = Date(timeIntervalSince1970: 820483120.0) // 1995-12-31 23:58:40
        test(.hour, expected: -1440)
        test(.minute, expected: -86401)
        test(.second, expected: -5184085)
        test(.nanosecond, expected: 0)

        start = Date(timeIntervalSince1970: 825667205.0) // 1996-03-01 00:00:05
        end = Date(timeIntervalSince1970: 825580720.0) // 1996-02-28 23:58:40
        test(.hour, expected: -24)
        test(.minute, expected: -1441)
        test(.second, expected: -86485)
        test(.nanosecond, expected: 0)

        start = Date(timeIntervalSince1970: 825580805.0) // 1996-02-29 00:00:05
        end = Date(timeIntervalSince1970: 825580720.0) // 1996-02-28 23:58:40
        test(.hour, expected: 0)
        test(.minute, expected: -1)
        test(.second, expected: -85)
        test(.nanosecond, expected: 0)

        start = Date(timeIntervalSince1970: 825580805.0) // 1996-02-29 00:00:05
        end = Date(timeIntervalSince1970: 820569520.0) // 1996-01-01 23:58:40
        test(.hour, expected: -1392)
        test(.minute, expected: -83521)
        test(.second, expected: -5011285)
        test(.nanosecond, expected: 0)

        start = Date(timeIntervalSince1970: 794044805.0) // 1995-03-01 00:00:05
        end = Date(timeIntervalSince1970: 794044710.0) // 1995-02-28 23:58:30
        test(.hour, expected: 0)
        test(.minute, expected: -1)
        test(.second, expected: -95)
        test(.nanosecond, expected: 0)
    }

    func testDifference_DST() {
        let calendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(identifier: "America/Los_Angeles")!, locale: nil, firstWeekday: 1, minimumDaysInFirstWeek: 4, gregorianStartDate: nil)

        var start: Date!
        var end: Date!
        func test(_ component: Calendar.Component, expected: Int, file: StaticString = #file, line: UInt = #line) {
            let (actualDiff, _) = try! calendar.difference(inComponent: component, from: start, to: end)
            XCTAssertEqual(actualDiff, expected, file: file, line: line)
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
}

