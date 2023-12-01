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
}
