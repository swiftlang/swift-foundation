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
}
