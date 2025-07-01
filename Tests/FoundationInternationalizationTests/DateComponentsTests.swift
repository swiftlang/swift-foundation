//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing

#if canImport(FoundationInternationalization)
import FoundationEssentials
import FoundationInternationalization
#elseif FOUNDATION_FRAMEWORK
import Foundation
#endif

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif os(WASI)
import WASILibc
#elseif os(Windows)
import CRT
#endif

@Suite("DateComponents")
private struct DateComponentsTests {

    @Test func isValidDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        
        let dc = DateComponents(year: 2022, month: 11, day: 1)
        #expect(dc.isValidDate(in: calendar))

        let dc2 = DateComponents(year: 2022, month: 11, day: 32)
        #expect(!dc2.isValidDate(in: calendar))
    }

    @Test func leapMonth() {
        var components = DateComponents()
        components.month = 1

        #expect(components.isLeapMonth == nil)

        components.isLeapMonth = true

        #expect(components.month == 1)
        #expect(components.isLeapMonth == true)
    }

    @Test func valueForComponent() {
        let comps = DateComponents(calendar: nil, timeZone: nil, era: 1, year: 2013, month: 4, day: 2, hour: 20, minute: 33, second: 49, nanosecond: 192837465, weekday: 3, weekdayOrdinal: 1, quarter: nil, weekOfMonth: 1, weekOfYear: 14, yearForWeekOfYear: 2013)

        #expect(comps.value(for: .calendar) == nil)
        #expect(comps.value(for: .timeZone) == nil)
        #expect(comps.value(for: .era) == 1)
        #expect(comps.value(for: .year) == 2013)
        #expect(comps.value(for: .month) == 4)
        #expect(comps.value(for: .day) == 2)
        #expect(comps.value(for: .hour) == 20)
        #expect(comps.value(for: .minute) == 33)
        #expect(comps.value(for: .second) == 49)
        #expect(comps.value(for: .nanosecond) == 192837465)
        #expect(comps.value(for: .weekday) == 3)
        #expect(comps.value(for: .weekdayOrdinal) == 1)
        #expect(comps.value(for: .quarter) == nil)
        #expect(comps.value(for: .weekOfMonth) == 1)
        #expect(comps.value(for: .weekOfYear) == 14)
        #expect(comps.value(for: .yearForWeekOfYear) == 2013)
    }

    @Test func nanosecond() throws {
        var comps = DateComponents(nanosecond: 123456789)
        #expect(comps.nanosecond == 123456789)

        comps.year = 2013
        comps.month = 12
        comps.day = 2
        comps.hour = 12
        comps.minute = 30
        comps.second = 45

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = try #require(TimeZone(identifier: "UTC"))

        let dateWithNS = try #require(cal.date(from: comps))
        let newComps = cal.dateComponents([.nanosecond], from: dateWithNS)

        let nano = try #require(newComps.nanosecond)
        #expect(labs(CLong(nano) - 123456789) <= 500)
    }

    @Test func dateComponents() {
        // Make sure the optional init stuff works
        let dc = DateComponents()

        #expect(dc.year == nil)

        let dc2 = DateComponents(year: 1999)

        #expect(dc2.day == nil)
        #expect(1999 == dc2.year)
    }

    @Test func anyHashableContainingDateComponents() {
        let values: [DateComponents] = [
            DateComponents(year: 2016),
            DateComponents(year: 1995),
            DateComponents(year: 1995),
        ]
        let anyHashables = values.map(AnyHashable.init)
        #expect(DateComponents.self == type(of: anyHashables[0].base))
        #expect(DateComponents.self == type(of: anyHashables[1].base))
        #expect(DateComponents.self == type(of: anyHashables[2].base))
        #expect(anyHashables[0] != anyHashables[1])
        #expect(anyHashables[1] == anyHashables[2])
    }

    @Test func weekComponent() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        // date(from: "2010-09-08 07:59:54 +0000")
        let date = Date(timeIntervalSinceReferenceDate: 305625594.0)
        let comps = calendar.dateComponents([.weekOfYear], from: date)
        #expect(comps.weekOfYear == 37)
    }

    @Test func components_fromDate_toDate_options_withEraChange() {
        // date(from: "1900-01-01 01:23:34 +0000")
        let fromDate = Date(timeIntervalSinceReferenceDate: -3187290986.0)
        // date(from: "2010-09-08 07:59:54 +0000")
        let toDate = Date(timeIntervalSinceReferenceDate: 305625594.0)

        var calendar = Calendar(identifier: .japanese)
        calendar.timeZone = .gmt

        let units: Set<Calendar.Component> = [.era, .year, .month, .day, .hour, .minute, .second]

        let comps = calendar.dateComponents(units, from: fromDate, to: toDate)

        #expect(comps.era == 3)
        #expect(comps.year == -10)
        #expect(comps.month == -3)
        #expect(comps.day == -22)
        #expect(comps.hour == -17)
        #expect(comps.minute == -23)
        #expect(comps.second == -40)
    }
}

// MARK: - FoundationPreview disabled utils
#if FOUNDATION_FRAMEWORK
extension DateComponentsTests {
    func date(from string: String, nanoseconds: Int? = nil) -> Date {
        let d = try! Date(string, strategy: Date.ParseStrategy(format: "\(year: .extended(minimumLength: 4))-\(month: .twoDigits)-\(day: .twoDigits) \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\(second: .twoDigits) \(timeZone: .iso8601(.short))", locale: Locale(identifier: "en_US"), timeZone: TimeZone.gmt))
        if nanoseconds != nil {
            let comps = Calendar(identifier: .gregorian).dateComponents([.era, .year, .month, .day, .hour, .minute, .second, .nanosecond, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .timeZone, .calendar], from: d)
            return Calendar(identifier: .gregorian).date(from: comps)!
        }
        return d
    }
}
#endif // FOUNDATION_FRAMEWORK
