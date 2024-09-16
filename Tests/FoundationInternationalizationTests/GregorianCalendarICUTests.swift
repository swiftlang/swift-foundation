//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
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

// Gregorian calendar tests that rely on FoundationInternationalization functionality
struct GregorianCalendarICUTests {
    @Test func testCopy() {
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: nil, locale: nil, firstWeekday: 5, minimumDaysInFirstWeek: 3, gregorianStartDate: nil)
        
        let newLocale = Locale(identifier: "new locale")
        let tz = TimeZone(identifier: "America/Los_Angeles")!
        let copied = gregorianCalendar.copy(changingLocale: newLocale, changingTimeZone: tz, changingFirstWeekday: nil, changingMinimumDaysInFirstWeek: nil)
        // newly set values
        #expect(copied.locale == newLocale)
        #expect(copied.timeZone == tz)
        // unset values stay the same
        #expect(copied.firstWeekday == 5)
        #expect(copied.minimumDaysInFirstWeek == 3)
        
        let copied2 = gregorianCalendar.copy(changingLocale: nil, changingTimeZone: nil, changingFirstWeekday: 1, changingMinimumDaysInFirstWeek: 1)
        
        // unset values stay the same
        #expect(copied2.locale == gregorianCalendar.locale)
        #expect(copied2.timeZone == gregorianCalendar.timeZone)
        
        // overriding existing values
        #expect(copied2.firstWeekday == 1)
        #expect(copied2.minimumDaysInFirstWeek == 1)
    }
    
    @Test func testDateFromComponents_DST() {
        // The expected dates were generated using ICU Calendar
        
        let tz = TimeZone(identifier: "America/Los_Angeles")!
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: tz, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
        func test(_ dateComponents: DateComponents, expected: Date, sourceLocation: SourceLocation = #_sourceLocation) {
            let date = gregorianCalendar.date(from: dateComponents)!
            #expect(date == expected, "DateComponents: \(dateComponents)", sourceLocation: sourceLocation)
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
            #expect(dc.weekOfMonth == weekOfMonth, "weekOfMonth should be equal",  sourceLocation: sourceLocation)
            #expect(dc.weekOfYear == weekOfYear, "weekOfYear should be equal",  sourceLocation: sourceLocation)
            #expect(dc.yearForWeekOfYear == yearForWeekOfYear, "yearForWeekOfYear should be equal",  sourceLocation: sourceLocation)
            #expect(dc.quarter == quarter, "quarter should be equal",  sourceLocation: sourceLocation)
            #expect(dc.nanosecond == nanosecond, "nanosecond should be equal",  sourceLocation: sourceLocation)
            #expect(dc.isLeapMonth == isLeapMonth, "isLeapMonth should be equal",  sourceLocation: sourceLocation)
            #expect(dc.timeZone == calendar.timeZone, "timeZone should be equal",  sourceLocation: sourceLocation)
        }
        
        let calendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(identifier: "America/Los_Angeles")!, locale: nil, firstWeekday: 1, minimumDaysInFirstWeek: 1, gregorianStartDate: nil)
        
        test(Date(timeIntervalSince1970: -62135769600.0), expectedEra: 0, year: 1, month: 12, day: 31, hour: 16, minute: 7, second: 2, nanosecond: 0, weekday: 6, weekdayOrdinal: 5, quarter: 4, weekOfMonth: 5, weekOfYear: 1, yearForWeekOfYear: 1, isLeapMonth: false)
        test(Date(timeIntervalSince1970: 64092211200.0), expectedEra: 1, year: 4000, month: 12, day: 31, hour: 16, minute: 0, second: 0, nanosecond: 0, weekday: 1, weekdayOrdinal: 5, quarter: 4, weekOfMonth: 6, weekOfYear: 1, yearForWeekOfYear: 4001, isLeapMonth: false)
        test(Date(timeIntervalSince1970: -210866760000.0), expectedEra: 0, year: 4713, month: 1, day: 1, hour: 4, minute: 7, second: 2, nanosecond: 0, weekday: 2, weekdayOrdinal: 1, quarter: 1, weekOfMonth: 1, weekOfYear: 1, yearForWeekOfYear: -4712, isLeapMonth: false)
        test(Date(timeIntervalSince1970: 4140226800.0), expectedEra: 1, year: 2101, month: 3, day: 14, hour: 0, minute: 0, second: 0, nanosecond: 0, weekday: 2, weekdayOrdinal: 2, quarter: 1, weekOfMonth: 3, weekOfYear: 12, yearForWeekOfYear: 2101, isLeapMonth: false)
    }
    
    @Test func testAddDateComponents() {
        let s = Date.ISO8601FormatStyle(timeZone: TimeZone(secondsFromGMT: 3600)!)
        var gregorianCalendar: _CalendarGregorian
        func testAdding(_ comp: DateComponents, to date: Date, wrap: Bool, expected: Date, sourceLocation: SourceLocation = #_sourceLocation) {
            let result = gregorianCalendar.date(byAdding: comp, to: date, wrappingComponents: wrap)!
            #expect(result == expected, "actual = \(result.timeIntervalSince1970), \(s.format(result))", sourceLocation: sourceLocation)
        }
        
        do {
            let firstWeekday = 1
            let minimumDaysInFirstWeek = 1
            let timeZone = TimeZone(identifier: "America/Edmonton")!
            gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: nil)
            
            testAdding(.init(weekday: -1), to: Date(timeIntervalSinceReferenceDate: -2976971168), wrap: false, expected: Date(timeIntervalSinceReferenceDate: -2977055536.0))
            
            testAdding(.init(day: 1), to: Date(timeIntervalSinceReferenceDate: -2977057568.0), wrap: false, expected: Date(timeIntervalSinceReferenceDate: -2976971168.0))
        }
        
        do {
            let timeZone = TimeZone(identifier: "Europe/Rome")!
            gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
            
            // Expected
            //    1978-10-01 23:00 +0100
            //    1978-10-01 00:00 +0200 (start of 10-01)
            //    1978-10-01 01:00 +0200
            // -> 1978-10-01 00:00 +0100 (DST, rewinds back to the start of the day in the same time zone)
            let date = Date(timeIntervalSinceReferenceDate:  -702180000) // 1978-10-01T23:00:00+0100
            testAdding(.init(hour: 1), to: date, wrap: true, expected: Date(timeIntervalSinceReferenceDate: -702266400.0))
        }
    }
    
    @Test func testAddDateComponents_DST() {
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(identifier: "America/Los_Angeles")!, locale: nil, firstWeekday: 2, minimumDaysInFirstWeek: 4, gregorianStartDate: nil)
        
        func testAdding(_ comp: DateComponents, to date: Date, wrap: Bool, expected: Date, sourceLocation: SourceLocation = #_sourceLocation) {
            let result = gregorianCalendar.date(byAdding: comp, to: date, wrappingComponents: wrap)!
            #expect(result == expected, "result = \(result.timeIntervalSince1970)" , sourceLocation: sourceLocation)
        }
        
        // 1996-03-01 23:35:00 UTC, 1996-03-01T15:35:00-0800
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
        testAdding(.init(day: -7, weekOfYear: 1), to: march1_1996, wrap: true, expected: march1_1996)
        testAdding(.init(day: -7, weekOfMonth: 1), to: march1_1996, wrap: true, expected: march1_1996)
        
        testAdding(.init(day: -7, weekOfYear: 2), to: march1_1996, wrap: true, expected: Date(timeIntervalSince1970: 826328100.0)) // Expect: 1996-03-08 23:35:00 +0000
        testAdding(.init(day: -7, weekOfMonth: 2), to: march1_1996, wrap: true, expected: Date(timeIntervalSince1970: 826328100.0)) // Expect: 1996-03-08 23:35:00 +0000
    }
    
    @Test func testAddDateComponents_DSTBoundaries() {
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(identifier: "America/Los_Angeles")!, locale: nil, firstWeekday: 3, minimumDaysInFirstWeek: 5, gregorianStartDate: nil)
        
        let fmt = Date.ISO8601FormatStyle(timeZone: gregorianCalendar.timeZone)
        func testAdding(_ comp: DateComponents, to date: Date, expected: Date, sourceLocation: SourceLocation = #_sourceLocation) {
            let result = gregorianCalendar.date(byAdding: comp, to: date, wrappingComponents: false)!
            #expect(result == expected, "result: \(fmt.format(result)); expected: \(fmt.format(expected))", sourceLocation: sourceLocation)
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
    
    @Test func testAddDateComponents_Wrapping_DSTBoundaries() {
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(identifier: "America/Los_Angeles")!, locale: nil, firstWeekday: 3, minimumDaysInFirstWeek: 5, gregorianStartDate: nil)
        
        let fmt = Date.ISO8601FormatStyle(timeZone: gregorianCalendar.timeZone)
        func testAdding(_ comp: DateComponents, to date: Date, expected: Date, sourceLocation: SourceLocation = #_sourceLocation) {
            let result = gregorianCalendar.date(byAdding: comp, to: date, wrappingComponents: true)!
            #expect(result == expected, "result: \(fmt.format(result)); expected: \(fmt.format(expected))", sourceLocation: sourceLocation)
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
    
    @Test func testAdd_DST() {
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(identifier: "America/Los_Angeles")!, locale: nil, firstWeekday: 3, minimumDaysInFirstWeek: 5, gregorianStartDate: nil)
        
        let fmt = Date.ISO8601FormatStyle(timeZone: gregorianCalendar.timeZone)
        func test(addField field: Calendar.Component, value: Int, to addingToDate: Date, expectedDate: Date, sourceLocation: SourceLocation = #_sourceLocation) {
            let components = DateComponents(component: field, value: value)!
            let result = gregorianCalendar.date(byAdding: components, to: addingToDate, wrappingComponents: false)!
            let actualDiff = result.timeIntervalSince(addingToDate)
            let expectedDiff = expectedDate.timeIntervalSince(addingToDate)
            
            #expect(result == expectedDate, "actual diff: \(actualDiff), expected: \(expectedDiff), actual ti = \(result.timeIntervalSince1970), expected ti = \(expectedDate.timeIntervalSince1970), actual = \(fmt.format(result)), expected = \(fmt.format(expectedDate))", sourceLocation: sourceLocation)
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
    
    @Test func testAdd_Wrap_DST() {
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(identifier: "America/Los_Angeles")!, locale: nil, firstWeekday: 3, minimumDaysInFirstWeek: 5, gregorianStartDate: nil)
        
        let fmt = Date.ISO8601FormatStyle(timeZone: gregorianCalendar.timeZone)
        func test(addField field: Calendar.Component, value: Int, to addingToDate: Date, expectedDate: Date, sourceLocation: SourceLocation = #_sourceLocation) {
            let components = DateComponents(component: field, value: value)!
            let result = gregorianCalendar.date(byAdding: components, to: addingToDate, wrappingComponents: true)!
            let msg: Comment = "actual = \(fmt.format(result)), expected = \(fmt.format(expectedDate))"
            #expect(result == expectedDate, msg, sourceLocation: sourceLocation)
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
    
    @Test func testOrdinality_DST() {
        let cal = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(identifier: "America/Los_Angeles")!, locale: nil, firstWeekday: 5, minimumDaysInFirstWeek: 4, gregorianStartDate: nil)
        
        func test(_ small: Calendar.Component, in large: Calendar.Component, for date: Date, expected: Int?, sourceLocation: SourceLocation = #_sourceLocation) {
            let result = cal.ordinality(of: small, in: large, for: date)
            #expect(result == expected,  "small: \(small), large: \(large)", sourceLocation: sourceLocation)
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
    
    
    // This test requires 64-bit integers
#if arch(x86_64) || arch(arm64)
    @Test func testOrdinality_DST2() {
        let calendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(identifier: "America/Los_Angeles")!, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
        let date = Date(timeIntervalSinceReferenceDate: 682898558.712307)
        #expect(calendar.ordinality(of: .era, in: .era, for: date) == nil)
        #expect(calendar.ordinality(of: .era, in: .year, for: date) == nil)
        #expect(calendar.ordinality(of: .era, in: .month, for: date) == nil)
        #expect(calendar.ordinality(of: .era, in: .day, for: date) == nil)
        #expect(calendar.ordinality(of: .era, in: .hour, for: date) == nil)
        #expect(calendar.ordinality(of: .era, in: .minute, for: date) == nil)
        #expect(calendar.ordinality(of: .era, in: .second, for: date) == nil)
        #expect(calendar.ordinality(of: .era, in: .weekday, for: date) == nil)
        #expect(calendar.ordinality(of: .era, in: .weekdayOrdinal, for: date) == nil)
        #expect(calendar.ordinality(of: .era, in: .quarter, for: date) == nil)
        #expect(calendar.ordinality(of: .era, in: .weekOfMonth, for: date) == nil)
        #expect(calendar.ordinality(of: .era, in: .weekOfYear, for: date) == nil)
        #expect(calendar.ordinality(of: .era, in: .yearForWeekOfYear, for: date) == nil)
        #expect(calendar.ordinality(of: .era, in: .nanosecond, for: date) == nil)
        
        #expect(calendar.ordinality(of: .year, in: .era, for: date) == 2022)
        #expect(calendar.ordinality(of: .year, in: .year, for: date) == nil)
        #expect(calendar.ordinality(of: .year, in: .month, for: date) == nil)
        #expect(calendar.ordinality(of: .year, in: .day, for: date) == nil)
        #expect(calendar.ordinality(of: .year, in: .hour, for: date) == nil)
        #expect(calendar.ordinality(of: .year, in: .minute, for: date) == nil)
        #expect(calendar.ordinality(of: .year, in: .second, for: date) == nil)
        #expect(calendar.ordinality(of: .year, in: .weekday, for: date) == nil)
        #expect(calendar.ordinality(of: .year, in: .weekdayOrdinal, for: date) == nil)
        #expect(calendar.ordinality(of: .year, in: .quarter, for: date) == nil)
        #expect(calendar.ordinality(of: .year, in: .weekOfMonth, for: date) == nil)
        #expect(calendar.ordinality(of: .year, in: .weekOfYear, for: date) == nil)
        #expect(calendar.ordinality(of: .year, in: .yearForWeekOfYear, for: date) == nil)
        #expect(calendar.ordinality(of: .year, in: .nanosecond, for: date) == nil)
        
        #expect(calendar.ordinality(of: .month, in: .era, for: date) == 24260)
        #expect(calendar.ordinality(of: .month, in: .year, for: date) == 8)
        #expect(calendar.ordinality(of: .month, in: .month, for: date) == nil)
        #expect(calendar.ordinality(of: .month, in: .day, for: date) == nil)
        #expect(calendar.ordinality(of: .month, in: .hour, for: date) == nil)
        #expect(calendar.ordinality(of: .month, in: .minute, for: date) == nil)
        #expect(calendar.ordinality(of: .month, in: .second, for: date) == nil)
        #expect(calendar.ordinality(of: .month, in: .weekday, for: date) == nil)
        #expect(calendar.ordinality(of: .month, in: .weekdayOrdinal, for: date) == nil)
        #expect(calendar.ordinality(of: .month, in: .quarter, for: date) == 2)
        #expect(calendar.ordinality(of: .month, in: .weekOfMonth, for: date) == nil)
        #expect(calendar.ordinality(of: .month, in: .weekOfYear, for: date) == nil)
        #expect(calendar.ordinality(of: .month, in: .yearForWeekOfYear, for: date) == nil)
        #expect(calendar.ordinality(of: .month, in: .nanosecond, for: date) == nil)
        
        #expect(calendar.ordinality(of: .day, in: .era, for: date) == 738389)
        #expect(calendar.ordinality(of: .day, in: .year, for: date) == 234)
        #expect(calendar.ordinality(of: .day, in: .month, for: date) == 22)
        #expect(calendar.ordinality(of: .day, in: .day, for: date) == nil)
        #expect(calendar.ordinality(of: .day, in: .hour, for: date) == nil)
        #expect(calendar.ordinality(of: .day, in: .minute, for: date) == nil)
        #expect(calendar.ordinality(of: .day, in: .second, for: date) == nil)
        #expect(calendar.ordinality(of: .day, in: .weekday, for: date) == nil)
        #expect(calendar.ordinality(of: .day, in: .weekdayOrdinal, for: date) == nil)
        #expect(calendar.ordinality(of: .day, in: .quarter, for: date) == 53)
        #expect(calendar.ordinality(of: .day, in: .weekOfMonth, for: date) == 2)
        #expect(calendar.ordinality(of: .day, in: .weekOfYear, for: date) == 2)
        #expect(calendar.ordinality(of: .day, in: .yearForWeekOfYear, for: date) == 240)
        #expect(calendar.ordinality(of: .day, in: .nanosecond, for: date) == nil)
        
        #expect(calendar.ordinality(of: .hour, in: .era, for: date) == 17721328)
        #expect(calendar.ordinality(of: .hour, in: .year, for: date) == 5608)
        #expect(calendar.ordinality(of: .hour, in: .month, for: date) == 520)
        #expect(calendar.ordinality(of: .hour, in: .day, for: date) == 16)
        #expect(calendar.ordinality(of: .hour, in: .hour, for: date) == nil)
        #expect(calendar.ordinality(of: .hour, in: .minute, for: date) == nil)
        #expect(calendar.ordinality(of: .hour, in: .second, for: date) == nil)
        #expect(calendar.ordinality(of: .hour, in: .weekday, for: date) == 16)
        #expect(calendar.ordinality(of: .hour, in: .weekdayOrdinal, for: date) == nil)
        #expect(calendar.ordinality(of: .hour, in: .quarter, for: date) == 1264)
        #expect(calendar.ordinality(of: .hour, in: .weekOfMonth, for: date) == 40)
        #expect(calendar.ordinality(of: .hour, in: .weekOfYear, for: date) == 40)
        #expect(calendar.ordinality(of: .hour, in: .yearForWeekOfYear, for: date) == 5737)
        #expect(calendar.ordinality(of: .hour, in: .nanosecond, for: date) == nil)
        
        #expect(calendar.ordinality(of: .minute, in: .era, for: date) == 1063279623)
        #expect(calendar.ordinality(of: .minute, in: .year, for: date) == 336423)
        #expect(calendar.ordinality(of: .minute, in: .month, for: date) == 31143)
        #expect(calendar.ordinality(of: .minute, in: .day, for: date) == 903)
        #expect(calendar.ordinality(of: .minute, in: .hour, for: date) == 3)
        #expect(calendar.ordinality(of: .minute, in: .minute, for: date) == nil)
        #expect(calendar.ordinality(of: .minute, in: .second, for: date) == nil)
        #expect(calendar.ordinality(of: .minute, in: .weekday, for: date) == 903)
        #expect(calendar.ordinality(of: .minute, in: .weekdayOrdinal, for: date) == nil)
        #expect(calendar.ordinality(of: .minute, in: .quarter, for: date) == 75783)
        #expect(calendar.ordinality(of: .minute, in: .weekOfMonth, for: date) == 2343)
        #expect(calendar.ordinality(of: .minute, in: .weekOfYear, for: date) == 2343)
        
        #expect(calendar.ordinality(of: .minute, in: .yearForWeekOfYear, for: date) == 344161)
        #expect(calendar.ordinality(of: .minute, in: .nanosecond, for: date) == nil)
        #expect(calendar.ordinality(of: .second, in: .era, for: date) == 63796777359)
        #expect(calendar.ordinality(of: .second, in: .year, for: date) == 20185359)
        #expect(calendar.ordinality(of: .second, in: .month, for: date) == 1868559)
        #expect(calendar.ordinality(of: .second, in: .day, for: date) == 54159)
        #expect(calendar.ordinality(of: .second, in: .hour, for: date) == 159)
        #expect(calendar.ordinality(of: .second, in: .minute, for: date) == 39)
        #expect(calendar.ordinality(of: .second, in: .second, for: date) == nil)
        #expect(calendar.ordinality(of: .second, in: .weekday, for: date) == 54159)
        #expect(calendar.ordinality(of: .second, in: .weekdayOrdinal, for: date) == nil)
        
        #expect(calendar.ordinality(of: .second, in: .quarter, for: date) == 4546959)
        #expect(calendar.ordinality(of: .second, in: .weekOfMonth, for: date) == 140559)
        #expect(calendar.ordinality(of: .second, in: .weekOfYear, for: date) == 140559)
        #expect(calendar.ordinality(of: .second, in: .yearForWeekOfYear, for: date) == 20649601)
        #expect(calendar.ordinality(of: .second, in: .nanosecond, for: date) == nil)
        
        #expect(calendar.ordinality(of: .weekday, in: .era, for: date) == 105484)
        #expect(calendar.ordinality(of: .weekday, in: .year, for: date) == 34)
        #expect(calendar.ordinality(of: .weekday, in: .month, for: date) == 4)
        #expect(calendar.ordinality(of: .weekday, in: .day, for: date) == nil)
        #expect(calendar.ordinality(of: .weekday, in: .hour, for: date) == nil)
        #expect(calendar.ordinality(of: .weekday, in: .minute, for: date) == nil)
        #expect(calendar.ordinality(of: .weekday, in: .second, for: date) == nil)
        #expect(calendar.ordinality(of: .weekday, in: .weekday, for: date) == nil)
        #expect(calendar.ordinality(of: .weekday, in: .weekdayOrdinal, for: date) == nil)
        #expect(calendar.ordinality(of: .weekday, in: .quarter, for: date) == 8)
        #expect(calendar.ordinality(of: .weekday, in: .weekOfMonth, for: date) == 2)
        #expect(calendar.ordinality(of: .weekday, in: .weekOfYear, for: date) == 2)
        #expect(calendar.ordinality(of: .weekday, in: .yearForWeekOfYear, for: date) == 35)
        #expect(calendar.ordinality(of: .weekday, in: .nanosecond, for: date) == nil)
        
        #expect(calendar.ordinality(of: .weekdayOrdinal, in: .era, for: date) == 105484)
        #expect(calendar.ordinality(of: .weekdayOrdinal, in: .year, for: date) == 34)
        #expect(calendar.ordinality(of: .weekdayOrdinal, in: .month, for: date) == 4)
        #expect(calendar.ordinality(of: .weekdayOrdinal, in: .day, for: date) == nil)
        #expect(calendar.ordinality(of: .weekdayOrdinal, in: .hour, for: date) == nil)
        #expect(calendar.ordinality(of: .weekdayOrdinal, in: .minute, for: date) == nil)
        #expect(calendar.ordinality(of: .weekdayOrdinal, in: .second, for: date) == nil)
        #expect(calendar.ordinality(of: .weekdayOrdinal, in: .weekday, for: date) == nil)
        #expect(calendar.ordinality(of: .weekdayOrdinal, in: .weekdayOrdinal, for: date) == nil)
        #expect(calendar.ordinality(of: .weekdayOrdinal, in: .quarter, for: date) == 8)
        #expect(calendar.ordinality(of: .weekdayOrdinal, in: .weekOfMonth, for: date) == nil)
        #expect(calendar.ordinality(of: .weekdayOrdinal, in: .weekOfYear, for: date) == nil)
        #expect(calendar.ordinality(of: .weekdayOrdinal, in: .yearForWeekOfYear, for: date) == 35)
        #expect(calendar.ordinality(of: .weekdayOrdinal, in: .nanosecond, for: date) == nil)
        
        #expect(calendar.ordinality(of: .quarter, in: .era, for: date) == 8087)
        #expect(calendar.ordinality(of: .quarter, in: .year, for: date) == 3)
        #expect(calendar.ordinality(of: .quarter, in: .month, for: date) == nil)
        #expect(calendar.ordinality(of: .quarter, in: .day, for: date) == nil)
        #expect(calendar.ordinality(of: .quarter, in: .hour, for: date) == nil)
        #expect(calendar.ordinality(of: .quarter, in: .minute, for: date) == nil)
        #expect(calendar.ordinality(of: .quarter, in: .second, for: date) == nil)
        #expect(calendar.ordinality(of: .quarter, in: .weekday, for: date) == nil)
        #expect(calendar.ordinality(of: .quarter, in: .weekdayOrdinal, for: date) == nil)
        #expect(calendar.ordinality(of: .quarter, in: .quarter, for: date) == nil)
        #expect(calendar.ordinality(of: .quarter, in: .weekOfMonth, for: date) == nil)
        #expect(calendar.ordinality(of: .quarter, in: .weekOfYear, for: date) == nil)
        #expect(calendar.ordinality(of: .quarter, in: .yearForWeekOfYear, for: date) == nil)
        #expect(calendar.ordinality(of: .quarter, in: .nanosecond, for: date) == nil)
        
        #expect(calendar.ordinality(of: .weekOfMonth, in: .era, for: date) == 105485)
        #expect(calendar.ordinality(of: .weekOfMonth, in: .year, for: date) == nil)
        #expect(calendar.ordinality(of: .weekOfMonth, in: .month, for: date) == 4)
        #expect(calendar.ordinality(of: .weekOfMonth, in: .day, for: date) == nil)
        #expect(calendar.ordinality(of: .weekOfMonth, in: .hour, for: date) == nil)
        #expect(calendar.ordinality(of: .weekOfMonth, in: .minute, for: date) == nil)
        #expect(calendar.ordinality(of: .weekOfMonth, in: .second, for: date) == nil)
        #expect(calendar.ordinality(of: .weekOfMonth, in: .weekday, for: date) == nil)
        #expect(calendar.ordinality(of: .weekOfMonth, in: .weekdayOrdinal, for: date) == nil)
        #expect(calendar.ordinality(of: .weekOfMonth, in: .quarter, for: date) == 9)
        #expect(calendar.ordinality(of: .weekOfMonth, in: .weekOfMonth, for: date) == nil)
        #expect(calendar.ordinality(of: .weekOfMonth, in: .weekOfYear, for: date) == nil)
        #expect(calendar.ordinality(of: .weekOfMonth, in: .yearForWeekOfYear, for: date) == nil)
        #expect(calendar.ordinality(of: .weekOfMonth, in: .nanosecond, for: date) == nil)
        #expect(calendar.ordinality(of: .weekOfYear, in: .era, for: date) == 105485)
        #expect(calendar.ordinality(of: .weekOfYear, in: .year, for: date) == 35)
        #expect(calendar.ordinality(of: .weekOfYear, in: .month, for: date) == nil)
        #expect(calendar.ordinality(of: .weekOfYear, in: .day, for: date) == nil)
        #expect(calendar.ordinality(of: .weekOfYear, in: .hour, for: date) == nil)
        #expect(calendar.ordinality(of: .weekOfYear, in: .minute, for: date) == nil)
        #expect(calendar.ordinality(of: .weekOfYear, in: .second, for: date) == nil)
        #expect(calendar.ordinality(of: .weekOfYear, in: .weekday, for: date) == nil)
        #expect(calendar.ordinality(of: .weekOfYear, in: .weekdayOrdinal, for: date) == nil)
        
        #expect(calendar.ordinality(of: .weekOfYear, in: .quarter, for: date) == 9)
        #expect(calendar.ordinality(of: .weekOfYear, in: .weekOfMonth, for: date) == nil)
        #expect(calendar.ordinality(of: .weekOfYear, in: .weekOfYear, for: date) == nil)
        #expect(calendar.ordinality(of: .weekOfYear, in: .yearForWeekOfYear, for: date) == 35)
        #expect(calendar.ordinality(of: .weekOfYear, in: .nanosecond, for: date) == nil)
        
        #expect(calendar.ordinality(of: .yearForWeekOfYear, in: .era, for: date) == 2022)
        #expect(calendar.ordinality(of: .yearForWeekOfYear, in: .year, for: date) == nil)
        #expect(calendar.ordinality(of: .yearForWeekOfYear, in: .month, for: date) == nil)
        #expect(calendar.ordinality(of: .yearForWeekOfYear, in: .day, for: date) == nil)
        #expect(calendar.ordinality(of: .yearForWeekOfYear, in: .hour, for: date) == nil)
        #expect(calendar.ordinality(of: .yearForWeekOfYear, in: .minute, for: date) == nil)
        #expect(calendar.ordinality(of: .yearForWeekOfYear, in: .second, for: date) == nil)
        #expect(calendar.ordinality(of: .yearForWeekOfYear, in: .weekday, for: date) == nil)
        #expect(calendar.ordinality(of: .yearForWeekOfYear, in: .weekdayOrdinal, for: date) == nil)
        #expect(calendar.ordinality(of: .yearForWeekOfYear, in: .quarter, for: date) == nil)
        #expect(calendar.ordinality(of: .yearForWeekOfYear, in: .weekOfMonth, for: date) == nil)
        #expect(calendar.ordinality(of: .yearForWeekOfYear, in: .weekOfYear, for: date) == nil)
        #expect(calendar.ordinality(of: .yearForWeekOfYear, in: .yearForWeekOfYear, for: date) == nil)
        #expect(calendar.ordinality(of: .yearForWeekOfYear, in: .nanosecond, for: date) == nil)
        
        #expect(calendar.ordinality(of: .nanosecond, in: .era, for: date) == nil)
        #expect(calendar.ordinality(of: .nanosecond, in: .year, for: date) == 20185358712306977)
        #expect(calendar.ordinality(of: .nanosecond, in: .month, for: date) == 1868558712306977)
        #expect(calendar.ordinality(of: .nanosecond, in: .day, for: date) == 54158712306977)
        #expect(calendar.ordinality(of: .nanosecond, in: .hour, for: date) == 158712306977)
        #expect(calendar.ordinality(of: .nanosecond, in: .minute, for: date) == 38712306977)
        #expect(calendar.ordinality(of: .nanosecond, in: .second, for: date) == 712306977)
        #expect(calendar.ordinality(of: .nanosecond, in: .weekday, for: date) == 54158712306977)
        #expect(calendar.ordinality(of: .nanosecond, in: .weekdayOrdinal, for: date) == nil)
        
        #expect(calendar.ordinality(of: .nanosecond, in: .quarter, for: date) == 4546958712306977)
        #expect(calendar.ordinality(of: .nanosecond, in: .weekOfMonth, for: date) == 140558712306977)
        #expect(calendar.ordinality(of: .nanosecond, in: .weekOfYear, for: date) == 140558712306977)
        
        let actual = calendar.ordinality(of: .nanosecond, in: .yearForWeekOfYear, for: date)
        #expect(actual == 20649600712306977)
        #expect(calendar.ordinality(of: .nanosecond, in: .nanosecond, for: date) == nil)
    }
#endif
    
    @Test func testDateInterval_DST() {
        let calendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(identifier: "America/Los_Angeles")!, locale: nil, firstWeekday: 3, minimumDaysInFirstWeek: 5, gregorianStartDate: nil)
        func test(_ c: Calendar.Component, _ date: Date, expectedStart start: Date, end: Date, sourceLocation: SourceLocation = #_sourceLocation) {
            let new = calendar.dateInterval(of: c, for: date)!
            let new_start = new.start
            let new_end = new.end
            let delta = 0.005
            #expect(abs(Double(new_start.timeIntervalSinceReferenceDate) - Double(start.timeIntervalSinceReferenceDate)) < delta, sourceLocation: sourceLocation)
            #expect(abs(Double(new_end.timeIntervalSinceReferenceDate) - Double(end.timeIntervalSinceReferenceDate)) < delta, sourceLocation: sourceLocation)
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
    
    @Test func testStartOf_DST() {
        let firstWeekday = 2
        let minimumDaysInFirstWeek = 4
        let timeZone = TimeZone(identifier: "America/Los_Angeles")!
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
    
    @Test func testDateFromComponents_componentsTimeZone() {
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: .gmt, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
        
        let dcCalendar = Calendar(identifier: .japanese, locale: Locale(identifier: ""), timeZone: .init(secondsFromGMT: -25200), firstWeekday: 1, minimumDaysInFirstWeek: 1, gregorianStartDate: nil)
        let dc = DateComponents(calendar: nil, timeZone: nil, era: 1, year: 2022, month: 7, day: 9, hour: 10, minute: 2, second: 55, nanosecond: 891000032, weekday: 7, weekdayOrdinal: 2, quarter: 0, weekOfMonth: 2, weekOfYear: 28, yearForWeekOfYear: 2022)
        
        var dc_customCalendarAndTimeZone = dc
        dc_customCalendarAndTimeZone.calendar = dcCalendar
        dc_customCalendarAndTimeZone.timeZone = .init(secondsFromGMT: 28800)
        // calendar.timeZone = UTC+0, dc.calendar.timeZone = UTC-7, dc.timeZone = UTC+8
        // expect local time in dc.timeZone (UTC+8)
        #expect(gregorianCalendar.date(from: dc_customCalendarAndTimeZone)! == Date(timeIntervalSinceReferenceDate: 679024975.891)) // 2022-07-09T02:02:55Z
        
        var dc_customCalendar = dc
        dc_customCalendar.calendar = dcCalendar
        dc_customCalendar.timeZone = nil
        // calendar.timeZone = UTC+0, dc.calendar.timeZone = UTC-7, dc.timeZone = nil
        // expect local time in calendar.timeZone (UTC+0)
        #expect(gregorianCalendar.date(from: dc_customCalendar)! == Date(timeIntervalSinceReferenceDate: 679053775.891)) // 2022-07-09T10:02:55Z
        
        var dc_customTimeZone = dc_customCalendarAndTimeZone
        dc_customTimeZone.calendar = nil
        dc_customTimeZone.timeZone = .init(secondsFromGMT: 28800)
        // calendar.timeZone = UTC+0, dc.calendar = nil, dc.timeZone = UTC+8
        // expect local time in dc.timeZone (UTC+8)
        #expect(gregorianCalendar.date(from: dc_customTimeZone)! == Date(timeIntervalSinceReferenceDate: 679024975.891)) // 2022-07-09T02:02:55Z
        
        let dcCalendar_noTimeZone = Calendar(identifier: .japanese, locale: Locale(identifier: ""), timeZone: nil, firstWeekday: 1, minimumDaysInFirstWeek: 1, gregorianStartDate: nil)
        var dc_customCalendarNoTimeZone_customTimeZone = dc
        dc_customCalendarNoTimeZone_customTimeZone.calendar = dcCalendar_noTimeZone
        dc_customCalendarNoTimeZone_customTimeZone.timeZone = .init(secondsFromGMT: 28800)
        // calendar.timeZone = UTC+0, dc.calendar.timeZone = nil, dc.timeZone = UTC+8
        // expect local time in dc.timeZone (UTC+8)
        #expect(gregorianCalendar.date(from: dc_customCalendarNoTimeZone_customTimeZone)! == Date(timeIntervalSinceReferenceDate: 679024975.891)) // 2022-07-09T02:02:55Z
    }
    
    @Test func testDateFromComponents_componentsTimeZoneConversion() {
        let timeZone = TimeZone.gmt
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
        
        // January 1, 2020 12:00:00 AM (GMT)
        let startOfYearGMT = Date(timeIntervalSince1970: 1577836800)
        let est = TimeZone(abbreviation: "EST")!
        
        var components = gregorianCalendar.dateComponents([.era, .year, .month, .day, .hour, .minute, .second, .nanosecond, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .dayOfYear, .calendar, .timeZone], from: startOfYearGMT)
        components.timeZone = est
        let startOfYearEST_greg = gregorianCalendar.date(from: components)
        
        let expected = startOfYearGMT + 3600*5 // January 1, 2020 12:00:00 AM (GMT)
        #expect(startOfYearEST_greg == expected)
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
}
