//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable import FoundationInternationalization
@testable import FoundationEssentials
#endif // FOUNDATION_FRAMEWORK

@Suite("Calendar RecurrenceRule")
private struct CalendarRecurrenceRuleTests {
    /// A Gregorian calendar with a time zone set to California
    var gregorian: Calendar = {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = .init(identifier: "US/Pacific")!
        return gregorian
    }()
    
    @Test func roundtripEncoding() async throws {
        // This test does not directly use the current Calendar, however encoding any Calendar will check if it is equivalent to the current Calendar
        // If equivalent, it will serialize a sentinel value and deserialize as the current Calendar regardless of the actual serialized identifier
        // This test will fail if calendar == Calendar.current at encode time and the current calendar changes to a different value before decode time (making the encoded calendar and the decoded calendar not equivalent
        try await usingCurrentInternationalizationPreferences {
            // These are not necessarily valid recurrence rule, they are constructed
            // in a way to test all encoding paths
            var calendar = Calendar(identifier: .gregorian)
            calendar.locale = .init(identifier: "en_001")
            calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
            
            var recurrenceRule1 = Calendar.RecurrenceRule(calendar: calendar, frequency: .daily)
            recurrenceRule1.interval = 2
            recurrenceRule1.months = [1, 2, Calendar.RecurrenceRule.Month(4, isLeap: true)]
            recurrenceRule1.weeks = [2, 3]
            recurrenceRule1.weekdays = [.every(.monday), .nth(1, .wednesday)]
            recurrenceRule1.end = .afterOccurrences(5)
            
            var recurrenceRule2 = Calendar.RecurrenceRule(calendar: calendar, frequency: .daily)
            recurrenceRule2.months = [2, 10]
            recurrenceRule2.weeks = [1, -1]
            recurrenceRule2.setPositions = [1]
            recurrenceRule2.hours = [14]
            recurrenceRule2.minutes = [30]
            recurrenceRule2.seconds = [0]
            recurrenceRule2.daysOfTheYear = [1]
            recurrenceRule2.daysOfTheMonth = [4]
            recurrenceRule2.weekdays = [.every(.monday), .nth(1, .wednesday)]
            recurrenceRule2.end = .afterDate(.distantFuture)
            
            let recurrenceRule1JSON = try JSONEncoder().encode(recurrenceRule1)
            let recurrenceRule2JSON = try JSONEncoder().encode(recurrenceRule2)
            let decoded1 = try JSONDecoder().decode(Calendar.RecurrenceRule.self, from: recurrenceRule1JSON)
            let decoded2 = try JSONDecoder().decode(Calendar.RecurrenceRule.self, from: recurrenceRule2JSON)
            
            #expect(recurrenceRule1 == decoded1)
            #expect(recurrenceRule2 == decoded2)
            #expect(recurrenceRule1 != recurrenceRule2)
        }
    }
    
    @Test func yearlyRecurrenceInLunarCalendar() {
        // Find the first day of the lunar new year
        let start = Date(timeIntervalSince1970: 1726876800.0) // 2024-09-21T00:00:00-0000
        let end   = Date(timeIntervalSince1970: 1855699200.0) // 2028-10-21T00:00:00-0000
        
        var lunarCalendar = Calendar(identifier: .chinese)
        lunarCalendar.timeZone = .gmt
        
        var rule = Calendar.RecurrenceRule(calendar: lunarCalendar, frequency: .yearly)
        rule.daysOfTheYear = [1]
        
        let eventStart = Date(timeIntervalSince1970: 1285077600.0) // 2010-09-21T14:00:00-0000
        let results = Array(rule.recurrences(of: eventStart, in: start..<end))
        
        let expectedResults: [Date] = [
            Date(timeIntervalSince1970: 1738159200.0), // 2025-01-29T14:00:00-0000
            Date(timeIntervalSince1970: 1771336800.0), // 2026-02-17T14:00:00-0000
            Date(timeIntervalSince1970: 1801922400.0), // 2027-02-06T14:00:00-0000
            Date(timeIntervalSince1970: 1832508000.0), // 2028-01-26T14:00:00-0000
        ]
        
        #expect(results == expectedResults)
    }
    
    @Test func expandToLeapMonths() {
        var lunarCalendar = Calendar(identifier: .chinese)
        lunarCalendar.timeZone = .gmt
        
        let start = Date(timeIntervalSince1970: 1729641600.0) // 2024-10-23T00:00:00-0000
        
        var rule = Calendar.RecurrenceRule(calendar: lunarCalendar, frequency: .yearly)
        rule.months = [Calendar.RecurrenceRule.Month(6, isLeap: true)]
        rule.daysOfTheMonth = [1]
        var sequence = rule.recurrences(of: start).makeIterator()
        
        #expect(sequence.next() == Date(timeIntervalSince1970: 1753401600.0)) // 2025-07-25T00:00:00-0000 (Sixth leap month)
        #expect(sequence.next() == Date(timeIntervalSince1970: 1786579200.0)) // 2026-08-13T00:00:00-0000 (Seventh month)
        #expect(sequence.next() == Date(timeIntervalSince1970: 1817164800.0)) // 2027-08-02T00:00:00-0000 (Seventh month)
        #expect(sequence.next() == Date(timeIntervalSince1970: 1850342400.0)) // 2028-08-20T00:00:00-0000 (Seventh month)
        #expect(sequence.next() == Date(timeIntervalSince1970: 1881014400.0)) // 2029-08-10T00:00:00-0000 (Seventh month)
    }
    
    @Test func startFromLeapMonth() {
        var lunarCalendar = Calendar(identifier: .chinese)
        lunarCalendar.timeZone = .gmt
        
        // Find recurrences of an event that happens on a leap month
        let start = Date(timeIntervalSince1970: 1753401600.0) // 2025-07-25T00:00:00-0000 (Leap month)
        
        // A non-strict recurrence would match the month where the leap month would have been
        let rule = Calendar.RecurrenceRule(calendar: lunarCalendar, frequency: .yearly, matchingPolicy: .nextTimePreservingSmallerComponents)
        var sequence = rule.recurrences(of: start).makeIterator()
        
        #expect(sequence.next() == Date(timeIntervalSince1970: 1753401600.0)) // 2025-07-25T00:00:00-0000 (Sixth leap month)
        #expect(sequence.next() == Date(timeIntervalSince1970: 1786579200.0)) // 2026-08-13T00:00:00-0000 (Seventh month)
        #expect(sequence.next() == Date(timeIntervalSince1970: 1817164800.0)) // 2027-08-02T00:00:00-0000 (Seventh month)
        #expect(sequence.next() == Date(timeIntervalSince1970: 1850342400.0)) // 2028-08-20T00:00:00-0000 (Seventh month)
        #expect(sequence.next() == Date(timeIntervalSince1970: 1881014400.0)) // 2029-08-10T00:00:00-0000 (Seventh month)
        #expect(sequence.next() == Date(timeIntervalSince1970: 1911600000.0)) // 2030-07-30T00:00:00-0000 (Seventh month)
        #expect(sequence.next() == Date(timeIntervalSince1970: 1944777600.0)) // 2031-08-18T00:00:00-0000 (Seventh month)
        #expect(sequence.next() == Date(timeIntervalSince1970: 1975363200.0)) // 2032-08-06T00:00:00-0000 (Seventh month)
        #expect(sequence.next() == Date(timeIntervalSince1970: 2005948800.0)) // 2033-07-26T00:00:00-0000 (Seventh month)
        #expect(sequence.next() == Date(timeIntervalSince1970: 2039126400.0)) // 2034-08-14T00:00:00-0000 (Seventh month)
        #expect(sequence.next() == Date(timeIntervalSince1970: 2069798400.0)) // 2035-08-04T00:00:00-0000 (Seventh month)
        #expect(sequence.next() == Date(timeIntervalSince1970: 2100384000.0)) // 2036-07-23T00:00:00-0000 (Sixth leap month)
        #expect(sequence.next() == Date(timeIntervalSince1970: 2133561600.0)) // 2037-08-11T00:00:00-0000 (Seventh month)
        #expect(sequence.next() == Date(timeIntervalSince1970: 2164233600.0)) // 2038-08-01T00:00:00-0000 (Seventh month)
        
        // A strict recurrence only matches in years with leap months
        let strictRule = Calendar.RecurrenceRule(calendar: lunarCalendar, frequency: .yearly, matchingPolicy: .strict)
        var strictSequence = strictRule.recurrences(of: start).makeIterator()
        #expect(strictSequence.next() == Date(timeIntervalSince1970: 1753401600.0)) // 2025-07-25T00:00:00-0000 (Sixth leap month)
        #expect(strictSequence.next() == Date(timeIntervalSince1970: 2100384000.0)) // 2036-07-23T00:00:00-0000 (Sixth leap month)
    }
    
    @Test func daylightSavingsRepeatedTimePolicyFirst() {
        let start = Date(timeIntervalSince1970: 1730535600.0) // 2024-11-02T01:20:00-0700
        var rule = Calendar.RecurrenceRule(calendar: gregorian, frequency: .daily)
        rule.repeatedTimePolicy = .first
        rule.end = .afterOccurrences(3)
        let results = Array(rule.recurrences(of: start))
        let expectedResults: [Date] = [
            Date(timeIntervalSince1970: 1730535600.0), // 2024-11-02T01:20:00-0700
            Date(timeIntervalSince1970: 1730622000.0), // 2024-11-03T01:20:00-0700
            ///   (Time zone switches from PST to PDT - clock jumps back one hour at
            ///    02:00 PDT)
            Date(timeIntervalSince1970: 1730712000.0), // 2024-11-04T01:20:00-0800
        ]
        #expect(results == expectedResults)
    }
    
    @Test func daylightSavingsRepeatedTimePolicyLast() {
        let start = Date(timeIntervalSince1970: 1730535600.0) // 2024-11-02T01:20:00-0700
        var rule = Calendar.RecurrenceRule(calendar: gregorian, frequency: .daily)
        rule.repeatedTimePolicy = .last
        rule.end = .afterOccurrences(3)
        let results = Array(rule.recurrences(of: start))
        let expectedResults: [Date] = [
            Date(timeIntervalSince1970: 1730535600.0), // 2024-11-02T01:20:00-0700
            ///   (Time zone switches from PST to PDT - clock jumps back one hour at
            ///    02:00 PDT)
            Date(timeIntervalSince1970: 1730625600.0), // 2024-11-03T01:20:00-0800
            Date(timeIntervalSince1970: 1730712000.0), // 2024-11-04T01:20:00-0800
        ]
        #expect(results == expectedResults)
    }
}
