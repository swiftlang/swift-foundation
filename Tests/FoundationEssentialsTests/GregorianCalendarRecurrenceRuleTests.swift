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
@testable import FoundationEssentials
#endif // FOUNDATION_FRAMEWORK

struct GregorianCalendarRecurrenceRuleTests {
    /// A Gregorian calendar in GMT with no time zone changes
    var gregorian: Calendar = {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = .gmt
        return gregorian
    }()
  
    @Test func testRoundtripEncoding() throws {
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
    
    @Test func testSimpleDailyRecurrence() {
        let start = Date(timeIntervalSince1970: 1285027200.0) // 2010-09-21T00:00:00-0000
        let end   = Date(timeIntervalSince1970: 1287619200.0) // 2010-10-21T00:00:00-0000
        
        let rule = Calendar.RecurrenceRule(calendar: gregorian, frequency: .daily, end: .never)
        
        let eventStart = Date(timeIntervalSince1970: 1285077600.0) // 2010-09-21T14:00:00-0000
        let results = Array(rule.recurrences(of: eventStart, in: start..<end))
        
        let expectedResults: [Date] = [
            Date(timeIntervalSince1970: 1285077600.0), // 2010-09-21T14:00:00-0000
            Date(timeIntervalSince1970: 1285164000.0), // 2010-09-22T14:00:00-0000
            Date(timeIntervalSince1970: 1285250400.0), // 2010-09-23T14:00:00-0000
            Date(timeIntervalSince1970: 1285336800.0), // 2010-09-24T14:00:00-0000
            Date(timeIntervalSince1970: 1285423200.0), // 2010-09-25T14:00:00-0000
            Date(timeIntervalSince1970: 1285509600.0), // 2010-09-26T14:00:00-0000
            Date(timeIntervalSince1970: 1285596000.0), // 2010-09-27T14:00:00-0000
            Date(timeIntervalSince1970: 1285682400.0), // 2010-09-28T14:00:00-0000
            Date(timeIntervalSince1970: 1285768800.0), // 2010-09-29T14:00:00-0000
            Date(timeIntervalSince1970: 1285855200.0), // 2010-09-30T14:00:00-0000
            Date(timeIntervalSince1970: 1285941600.0), // 2010-10-01T14:00:00-0000
            Date(timeIntervalSince1970: 1286028000.0), // 2010-10-02T14:00:00-0000
            Date(timeIntervalSince1970: 1286114400.0), // 2010-10-03T14:00:00-0000
            Date(timeIntervalSince1970: 1286200800.0), // 2010-10-04T14:00:00-0000
            Date(timeIntervalSince1970: 1286287200.0), // 2010-10-05T14:00:00-0000
            Date(timeIntervalSince1970: 1286373600.0), // 2010-10-06T14:00:00-0000
            Date(timeIntervalSince1970: 1286460000.0), // 2010-10-07T14:00:00-0000
            Date(timeIntervalSince1970: 1286546400.0), // 2010-10-08T14:00:00-0000
            Date(timeIntervalSince1970: 1286632800.0), // 2010-10-09T14:00:00-0000
            Date(timeIntervalSince1970: 1286719200.0), // 2010-10-10T14:00:00-0000
            Date(timeIntervalSince1970: 1286805600.0), // 2010-10-11T14:00:00-0000
            Date(timeIntervalSince1970: 1286892000.0), // 2010-10-12T14:00:00-0000
            Date(timeIntervalSince1970: 1286978400.0), // 2010-10-13T14:00:00-0000
            Date(timeIntervalSince1970: 1287064800.0), // 2010-10-14T14:00:00-0000
            Date(timeIntervalSince1970: 1287151200.0), // 2010-10-15T14:00:00-0000
            Date(timeIntervalSince1970: 1287237600.0), // 2010-10-16T14:00:00-0000
            Date(timeIntervalSince1970: 1287324000.0), // 2010-10-17T14:00:00-0000
            Date(timeIntervalSince1970: 1287410400.0), // 2010-10-18T14:00:00-0000
            Date(timeIntervalSince1970: 1287496800.0), // 2010-10-19T14:00:00-0000
            Date(timeIntervalSince1970: 1287583200.0), // 2010-10-20T14:00:00-0000
        ]
        
        #expect(results == expectedResults)
    }
    
    @Test func testSimpleDailyRecurrenceWithCount() {
        let start = Date(timeIntervalSince1970: 1285027200.0) // 2010-09-21T00:00:00-0000
        let end   = Date(timeIntervalSince1970: 1287619200.0) // 2010-10-21T00:00:00-0000
        
        let rule = Calendar.RecurrenceRule(calendar: gregorian, frequency: .daily, end: .afterOccurrences(4))
        
        let eventStart = Date(timeIntervalSince1970: 1285077600.0) // 2010-09-21T14:00:00-0000
        let results = Array(rule.recurrences(of: eventStart, in: start..<end))
        
        let expectedResults: [Date] = [
            Date(timeIntervalSince1970: 1285077600.0), // 2010-09-21T14:00:00-0000
            Date(timeIntervalSince1970: 1285164000.0), // 2010-09-22T14:00:00-0000
            Date(timeIntervalSince1970: 1285250400.0), // 2010-09-23T14:00:00-0000
            Date(timeIntervalSince1970: 1285336800.0), // 2010-09-24T14:00:00-0000
        ]
        
        #expect(results == expectedResults)
    }
    
    @Test func testDailyRecurrenceWithDaysOfTheWeek() {
        let start = Date(timeIntervalSince1970: 1285027200.0) // 2010-09-21T00:00:00-0000
        let end   = Date(timeIntervalSince1970: 1287619200.0) // 2010-10-21T00:00:00-0000
        
        var rule = Calendar.RecurrenceRule(calendar: gregorian, frequency: .daily)
        rule.weekdays = [.every(.monday), .every(.friday)]
        
        let eventStart = Date(timeIntervalSince1970: 1285077600.0) // 2010-09-21T14:00:00-0000
        let results = Array(rule.recurrences(of: eventStart, in: start..<end))
        
        let expectedResults: [Date] = [
            Date(timeIntervalSince1970: 1285336800.0), // 2010-09-24T14:00:00-0000
            Date(timeIntervalSince1970: 1285596000.0), // 2010-09-27T14:00:00-0000
            Date(timeIntervalSince1970: 1285941600.0), // 2010-10-01T14:00:00-0000
            Date(timeIntervalSince1970: 1286200800.0), // 2010-10-04T14:00:00-0000
            Date(timeIntervalSince1970: 1286546400.0), // 2010-10-08T14:00:00-0000
            Date(timeIntervalSince1970: 1286805600.0), // 2010-10-11T14:00:00-0000
            Date(timeIntervalSince1970: 1287151200.0), // 2010-10-15T14:00:00-0000
            Date(timeIntervalSince1970: 1287410400.0), // 2010-10-18T14:00:00-0000
        ]
        
        #expect(results == expectedResults)
    }
    
    @Test func testDailyRecurrenceWithDaysOfTheWeekAndMonth() {
        let start = Date(timeIntervalSince1970: 1285027200.0) // 2010-09-21T00:00:00-0000
        let end   = Date(timeIntervalSince1970: 1287619200.0) // 2010-10-21T00:00:00-0000
        
        var rule = Calendar.RecurrenceRule(calendar: gregorian, frequency: .daily)
        rule.weekdays = [.every(.monday), .every(.friday)]
        rule.months = [9]
        
        let eventStart = Date(timeIntervalSince1970: 1285077600.0) // 2010-09-21T14:00:00-0000
        let results = Array(rule.recurrences(of: eventStart, in: start..<end))
        
        let expectedResults: [Date] = [
            Date(timeIntervalSince1970: 1285336800.0), // 2010-09-24T14:00:00-0000
            Date(timeIntervalSince1970: 1285596000.0), // 2010-09-27T14:00:00-0000
        ]
        
        #expect(results == expectedResults)
    }
    
    @Test func testDailyRecurrenceWithMonth() {
        let start = Date(timeIntervalSince1970: 1285027200.0) // 2010-09-21T00:00:00-0000
        let end   = Date(timeIntervalSince1970: 1287619200.0) // 2010-10-21T00:00:00-0000
        
        var rule = Calendar.RecurrenceRule(calendar: gregorian, frequency: .daily)
        rule.months = [9]
        
        let eventStart = Date(timeIntervalSince1970: 1285077600.0) // 2010-09-21T14:00:00-0000
        let results = Array(rule.recurrences(of: eventStart, in: start..<end))
        
        let expectedResults: [Date] = [
            Date(timeIntervalSince1970: 1285077600.0), // 2010-09-21T14:00:00-0000
            Date(timeIntervalSince1970: 1285164000.0), // 2010-09-22T14:00:00-0000
            Date(timeIntervalSince1970: 1285250400.0), // 2010-09-23T14:00:00-0000
            Date(timeIntervalSince1970: 1285336800.0), // 2010-09-24T14:00:00-0000
            Date(timeIntervalSince1970: 1285423200.0), // 2010-09-25T14:00:00-0000
            Date(timeIntervalSince1970: 1285509600.0), // 2010-09-26T14:00:00-0000
            Date(timeIntervalSince1970: 1285596000.0), // 2010-09-27T14:00:00-0000
            Date(timeIntervalSince1970: 1285682400.0), // 2010-09-28T14:00:00-0000
            Date(timeIntervalSince1970: 1285768800.0), // 2010-09-29T14:00:00-0000
            Date(timeIntervalSince1970: 1285855200.0), // 2010-09-30T14:00:00-0000
        ]
        
        #expect(results == expectedResults)
    }
    
    @Test func testDailyRecurrenceEveryThreeDays() {
        let start = Date(timeIntervalSince1970: 1285027200.0) // 2010-09-21T00:00:00-0000
        let end   = Date(timeIntervalSince1970: 1287619200.0) // 2010-10-21T00:00:00-0000
        
        var rule = Calendar.RecurrenceRule(calendar: gregorian, frequency: .daily)
        rule.interval = 3
        
        let eventStart = Date(timeIntervalSince1970: 1285077600.0) // 2010-09-21T14:00:00-0000
        let results = Array(rule.recurrences(of: eventStart, in: start..<end))
        
        let expectedResults: [Date] = [
            Date(timeIntervalSince1970: 1285077600.0), // 2010-09-21T14:00:00-0000
            Date(timeIntervalSince1970: 1285336800.0), // 2010-09-24T14:00:00-0000
            Date(timeIntervalSince1970: 1285596000.0), // 2010-09-27T14:00:00-0000
            Date(timeIntervalSince1970: 1285855200.0), // 2010-09-30T14:00:00-0000
            Date(timeIntervalSince1970: 1286114400.0), // 2010-10-03T14:00:00-0000
            Date(timeIntervalSince1970: 1286373600.0), // 2010-10-06T14:00:00-0000
            Date(timeIntervalSince1970: 1286632800.0), // 2010-10-09T14:00:00-0000
            Date(timeIntervalSince1970: 1286892000.0), // 2010-10-12T14:00:00-0000
            Date(timeIntervalSince1970: 1287151200.0), // 2010-10-15T14:00:00-0000
            Date(timeIntervalSince1970: 1287410400.0), // 2010-10-18T14:00:00-0000
        ]
        
        #expect(results == expectedResults)
        
    }
    
    @Test func testSimpleWeeklyRecurrence() {
        let start = Date(timeIntervalSince1970: 1285027200.0) // 2010-09-21T00:00:00-0000
        let end   = Date(timeIntervalSince1970: 1287619200.0) // 2010-10-21T00:00:00-0000
        
        let rule = Calendar.RecurrenceRule(calendar: gregorian, frequency: .weekly)
        
        let eventStart = Date(timeIntervalSince1970: 1285077600.0) // 2010-09-21T14:00:00-0000
        let results = Array(rule.recurrences(of: eventStart, in: start..<end))
        
        let expectedResults: [Date] = [
            Date(timeIntervalSince1970: 1285077600.0), // 2010-09-21T14:00:00-0000
            Date(timeIntervalSince1970: 1285682400.0), // 2010-09-28T14:00:00-0000
            Date(timeIntervalSince1970: 1286287200.0), // 2010-10-05T14:00:00-0000
            Date(timeIntervalSince1970: 1286892000.0), // 2010-10-12T14:00:00-0000
            Date(timeIntervalSince1970: 1287496800.0), // 2010-10-19T14:00:00-0000
        ]
        
        #expect(results == expectedResults)
    }
    
    @Test func testWeeklyRecurrenceEveryOtherWeek() {
        let start = Date(timeIntervalSince1970: 1285027200.0) // 2010-09-21T00:00:00-0000
        let end   = Date(timeIntervalSince1970: 1287619200.0) // 2010-10-21T00:00:00-0000
        
        var rule = Calendar.RecurrenceRule(calendar: gregorian, frequency: .weekly)
        rule.interval = 2
        
        let eventStart = Date(timeIntervalSince1970: 1285077600.0) // 2010-09-21T14:00:00-0000
        let results = Array(rule.recurrences(of: eventStart, in: start..<end))
        
        let expectedResults: [Date] = [
            Date(timeIntervalSince1970: 1285077600.0), // 2010-09-21T14:00:00-0000
            Date(timeIntervalSince1970: 1286287200.0), // 2010-10-05T14:00:00-0000
            Date(timeIntervalSince1970: 1287496800.0), // 2010-10-19T14:00:00-0000
        ]
        
        #expect(results == expectedResults)
    }
    
    @Test func testWeeklyRecurrenceWithDaysOfWeek() {
        let start = Date(timeIntervalSince1970: 1285027200.0) // 2010-09-21T00:00:00-0000
        let end   = Date(timeIntervalSince1970: 1287619200.0) // 2010-10-21T00:00:00-0000
        
        var rule = Calendar.RecurrenceRule(calendar: gregorian, frequency: .weekly)
        rule.weekdays = [.every(.monday), .every(.friday)]
        
        let eventStart = Date(timeIntervalSince1970: 1285077600.0) // 2010-09-21T14:00:00-0000
        let results = Array(rule.recurrences(of: eventStart, in: start..<end))
        
        let expectedResults: [Date] = [
            Date(timeIntervalSince1970: 1285336800.0), // 2010-09-24T14:00:00-0000
            Date(timeIntervalSince1970: 1285596000.0), // 2010-09-27T14:00:00-0000
            Date(timeIntervalSince1970: 1285941600.0), // 2010-10-01T14:00:00-0000
            Date(timeIntervalSince1970: 1286200800.0), // 2010-10-04T14:00:00-0000
            Date(timeIntervalSince1970: 1286546400.0), // 2010-10-08T14:00:00-0000
            Date(timeIntervalSince1970: 1286805600.0), // 2010-10-11T14:00:00-0000
            Date(timeIntervalSince1970: 1287151200.0), // 2010-10-15T14:00:00-0000
            Date(timeIntervalSince1970: 1287410400.0), // 2010-10-18T14:00:00-0000
        ]
        
        #expect(results == expectedResults)
    }
    
    @Test func testWeeklyRecurrenceWithDaysOfWeekAndMonth() {
        let start = Date(timeIntervalSince1970: 1285027200.0) // 2010-09-21T00:00:00-0000
        let end   = Date(timeIntervalSince1970: 1287619200.0) // 2010-10-21T00:00:00-0000
        
        var rule = Calendar.RecurrenceRule(calendar: gregorian, frequency: .weekly)
        rule.months = [9]
        rule.weekdays = [.every(.monday), .every(.friday)]
        
        let eventStart = Date(timeIntervalSince1970: 1285077600.0) // 2010-09-21T14:00:00-0000
        let results = Array(rule.recurrences(of: eventStart, in: start..<end))
        
        let expectedResults: [Date] = [
            Date(timeIntervalSince1970: 1285336800.0), // 2010-09-24T14:00:00-0000
            Date(timeIntervalSince1970: 1285596000.0), // 2010-09-27T14:00:00-0000
        ]
        
        #expect(results == expectedResults)
    }
    @Test func testWeeklyRecurrenceWithDaysOfWeekAndSetPositions() {
        let start = Date(timeIntervalSince1970: 1285027200.0) // 2010-09-21T00:00:00-0000
        let end   = Date(timeIntervalSince1970: 1287619200.0) // 2010-10-21T00:00:00-0000
        
        var rule = Calendar.RecurrenceRule(calendar: gregorian, frequency: .weekly)
        rule.setPositions = [-1]
        rule.weekdays = [.every(.monday), .every(.friday)]
        
        let eventStart = Date(timeIntervalSince1970: 1285077600.0) // 2010-09-21T14:00:00-0000
        let results = Array(rule.recurrences(of: eventStart, in: start..<end))
        
        let expectedResults: [Date] = [
            Date(timeIntervalSince1970: 1285336800.0), // 2010-09-24T14:00:00-0000
            Date(timeIntervalSince1970: 1285941600.0), // 2010-10-01T14:00:00-0000
            Date(timeIntervalSince1970: 1286546400.0), // 2010-10-08T14:00:00-0000
            Date(timeIntervalSince1970: 1287151200.0), // 2010-10-15T14:00:00-0000
        ]
        
        #expect(results == expectedResults)
    }
    
    @Test func testMonthlyRecurrenceWithWeekdays() {
        // Find the first monday and last friday of each month for a given range
        let start = Date(timeIntervalSince1970: 1641045600.0) // 2022-01-01T14:00:00-0000
        let end   = Date(timeIntervalSince1970: 1677679200.0) // 2023-03-01T14:00:00-0000
        
        var rule = Calendar.RecurrenceRule(calendar: gregorian, frequency: .monthly)
        rule.end = .afterDate(end)
        rule.weekdays = [.nth(1, .monday), .nth(-1, .friday)]
        
        let results = Array(rule.recurrences(of: start))
        
        let expectedResults: [Date] = [
            Date(timeIntervalSince1970: 1641218400.0), // 2022-01-03T14:00:00-0000
            Date(timeIntervalSince1970: 1643378400.0), // 2022-01-28T14:00:00-0000
            Date(timeIntervalSince1970: 1644242400.0), // 2022-02-07T14:00:00-0000
            Date(timeIntervalSince1970: 1645797600.0), // 2022-02-25T14:00:00-0000
            Date(timeIntervalSince1970: 1646661600.0), // 2022-03-07T14:00:00-0000
            Date(timeIntervalSince1970: 1648216800.0), // 2022-03-25T14:00:00-0000
            Date(timeIntervalSince1970: 1649080800.0), // 2022-04-04T14:00:00-0000
            Date(timeIntervalSince1970: 1651240800.0), // 2022-04-29T14:00:00-0000
            Date(timeIntervalSince1970: 1651500000.0), // 2022-05-02T14:00:00-0000
            Date(timeIntervalSince1970: 1653660000.0), // 2022-05-27T14:00:00-0000
            Date(timeIntervalSince1970: 1654524000.0), // 2022-06-06T14:00:00-0000
            Date(timeIntervalSince1970: 1656079200.0), // 2022-06-24T14:00:00-0000
            Date(timeIntervalSince1970: 1656943200.0), // 2022-07-04T14:00:00-0000
            Date(timeIntervalSince1970: 1659103200.0), // 2022-07-29T14:00:00-0000
            Date(timeIntervalSince1970: 1659362400.0), // 2022-08-01T14:00:00-0000
            Date(timeIntervalSince1970: 1661522400.0), // 2022-08-26T14:00:00-0000
            Date(timeIntervalSince1970: 1662386400.0), // 2022-09-05T14:00:00-0000
            Date(timeIntervalSince1970: 1664546400.0), // 2022-09-30T14:00:00-0000
            Date(timeIntervalSince1970: 1664805600.0), // 2022-10-03T14:00:00-0000
            Date(timeIntervalSince1970: 1666965600.0), // 2022-10-28T14:00:00-0000
            Date(timeIntervalSince1970: 1667829600.0), // 2022-11-07T14:00:00-0000
            Date(timeIntervalSince1970: 1669384800.0), // 2022-11-25T14:00:00-0000
            Date(timeIntervalSince1970: 1670248800.0), // 2022-12-05T14:00:00-0000
            Date(timeIntervalSince1970: 1672408800.0), // 2022-12-30T14:00:00-0000
            Date(timeIntervalSince1970: 1672668000.0), // 2023-01-02T14:00:00-0000
            Date(timeIntervalSince1970: 1674828000.0), // 2023-01-27T14:00:00-0000
            Date(timeIntervalSince1970: 1675692000.0), // 2023-02-06T14:00:00-0000
            Date(timeIntervalSince1970: 1677247200.0), // 2023-02-24T14:00:00-0000
        ]
        
        #expect(results == expectedResults)
    }
    
    @Test func testYearlyRecurrenceOnLeapDay() {
        let start   = Date(timeIntervalSince1970: 1704067200.0) // 2024-01-01T00:00:00-0000
        let end     = Date(timeIntervalSince1970: 1956528000.0) // 2032-01-01T00:00:00-0000
        let leapDay = Date(timeIntervalSince1970: 1709200800.0) // 2024-02-29T10:00:00-0000
        
        var rule = Calendar.RecurrenceRule(calendar: gregorian, frequency: .yearly)
        var results, expectedResults: [Date]
        
        rule.matchingPolicy = .nextTimePreservingSmallerComponents
        results = Array(rule.recurrences(of: leapDay, in: start..<end))
        expectedResults = [
            Date(timeIntervalSince1970: 1709200800.0), // 2024-02-29T10:00:00-0000
            Date(timeIntervalSince1970: 1740823200.0), // 2025-03-01T10:00:00-0000
            Date(timeIntervalSince1970: 1772359200.0), // 2026-03-01T10:00:00-0000
            Date(timeIntervalSince1970: 1803895200.0), // 2027-03-01T10:00:00-0000
            Date(timeIntervalSince1970: 1835431200.0), // 2028-02-29T10:00:00-0000
            Date(timeIntervalSince1970: 1867053600.0), // 2029-03-01T10:00:00-0000
            Date(timeIntervalSince1970: 1898589600.0), // 2030-03-01T10:00:00-0000
            Date(timeIntervalSince1970: 1930125600.0), // 2031-03-01T10:00:00-0000
        ]
        #expect(results == expectedResults)
        
        rule.matchingPolicy = .nextTime
        results = Array(rule.recurrences(of: leapDay, in: start..<end))
        expectedResults = [
            Date(timeIntervalSince1970: 1709200800.0), // 2024-02-29T10:00:00-0000
            Date(timeIntervalSince1970: 1740787200.0), // 2025-03-01T00:00:00-0000
            Date(timeIntervalSince1970: 1772323200.0), // 2026-03-01T00:00:00-0000
            Date(timeIntervalSince1970: 1803859200.0), // 2027-03-01T00:00:00-0000
            Date(timeIntervalSince1970: 1835431200.0), // 2028-02-29T10:00:00-0000
            Date(timeIntervalSince1970: 1867017600.0), // 2029-03-01T00:00:00-0000
            Date(timeIntervalSince1970: 1898553600.0), // 2030-03-01T00:00:00-0000
            Date(timeIntervalSince1970: 1930089600.0), // 2031-03-01T00:00:00-0000
        ]
        #expect(results == expectedResults)
        
        rule.matchingPolicy = .previousTimePreservingSmallerComponents
        results = Array(rule.recurrences(of: leapDay, in: start..<end))
        expectedResults = [
            Date(timeIntervalSince1970: 1709200800.0), // 2024-02-29T10:00:00-0000
            Date(timeIntervalSince1970: 1740736800.0), // 2025-02-28T10:00:00-0000
            Date(timeIntervalSince1970: 1772272800.0), // 2026-02-28T10:00:00-0000
            Date(timeIntervalSince1970: 1803808800.0), // 2027-02-28T10:00:00-0000
            Date(timeIntervalSince1970: 1835431200.0), // 2028-02-29T10:00:00-0000
            Date(timeIntervalSince1970: 1866967200.0), // 2029-02-28T10:00:00-0000
            Date(timeIntervalSince1970: 1898503200.0), // 2030-02-28T10:00:00-0000
            Date(timeIntervalSince1970: 1930039200.0), // 2031-02-28T10:00:00-0000
        ]
        #expect(results == expectedResults)
        
        rule.matchingPolicy = .strict
        results = Array(rule.recurrences(of: leapDay, in: start..<end))
        expectedResults = [
            Date(timeIntervalSince1970: 1709200800.0), // 2024-02-29T10:00:00-0000
            Date(timeIntervalSince1970: 1835431200.0), // 2028-02-29T10:00:00-0000
        ]
        #expect(results == expectedResults)
    }
    
    @Test func testYearlyRecurrenceWithMonthExpansion() {
        let start = Date(timeIntervalSince1970: 1285027200.0) // 2010-09-21T00:00:00-0000
        let end   = Date(timeIntervalSince1970: 1350777600.0) // 2012-10-21T00:00:00-0000
        
        var rule = Calendar.RecurrenceRule(calendar: gregorian, frequency: .yearly)
        rule.months = [1, 5]
        
        let eventStart = Date(timeIntervalSince1970: 1285077600.0) // 2010-09-21T14:00:00-0000
        let results = Array(rule.recurrences(of: eventStart, in: start..<end))
        
        let expectedResults: [Date] = [
            Date(timeIntervalSince1970: 1295618400.0), // 2011-01-21T14:00:00-0000
            Date(timeIntervalSince1970: 1305986400.0), // 2011-05-21T14:00:00-0000
            Date(timeIntervalSince1970: 1327154400.0), // 2012-01-21T14:00:00-0000
            Date(timeIntervalSince1970: 1337608800.0), // 2012-05-21T14:00:00-0000
        ]
        
        #expect(results == expectedResults)
    }
    @Test func testYearlyRecurrenceWithDayOfMonthExpansion() {
        let start = Date(timeIntervalSince1970: 1695304800.0) // 2023-09-21T14:00:00-0000
        let end   = Date(timeIntervalSince1970: 1729519200.0) // 2024-10-21T14:00:00-0000
        
        var rule = Calendar.RecurrenceRule(calendar: gregorian, frequency: .yearly)
        rule.daysOfTheMonth = [1, -1]
        
        let eventStart = Date(timeIntervalSince1970: 1285077600.0) // 2010-09-21T14:00:00-0000
        let results = Array(rule.recurrences(of: eventStart, in: start..<end))
        
        let expectedResults: [Date] = [
            Date(timeIntervalSince1970: 1696082400.0), // 2023-09-30T14:00:00-0000
            Date(timeIntervalSince1970: 1725199200.0), // 2024-09-01T14:00:00-0000
            Date(timeIntervalSince1970: 1727704800.0), // 2024-09-30T14:00:00-0000
        ]
        
        #expect(results == expectedResults)
    }
    
    @Test func testYearlyRecurrenceWithMonthAndDayOfMonthExpansion() {
        let start = Date(timeIntervalSince1970: 1285027200.0) // 2010-09-21T00:00:00-0000
        let end   = Date(timeIntervalSince1970: 1350777600.0) // 2012-10-21T00:00:00-0000
        
        var rule = Calendar.RecurrenceRule(calendar: gregorian, frequency: .yearly)
        rule.months = [1, 5]
        rule.daysOfTheMonth = [3, 10]
        
        let eventStart = Date(timeIntervalSince1970: 1285077600.0) // 2010-09-21T14:00:00-0000
        let results = Array(rule.recurrences(of: eventStart, in: start..<end))
        
        let expectedResults: [Date] = [
            Date(timeIntervalSince1970: 1294063200.0), // 2011-01-03T14:00:00-0000
            Date(timeIntervalSince1970: 1294668000.0), // 2011-01-10T14:00:00-0000
            Date(timeIntervalSince1970: 1304431200.0), // 2011-05-03T14:00:00-0000
            Date(timeIntervalSince1970: 1305036000.0), // 2011-05-10T14:00:00-0000
            Date(timeIntervalSince1970: 1325599200.0), // 2012-01-03T14:00:00-0000
            Date(timeIntervalSince1970: 1326204000.0), // 2012-01-10T14:00:00-0000
            Date(timeIntervalSince1970: 1336053600.0), // 2012-05-03T14:00:00-0000
            Date(timeIntervalSince1970: 1336658400.0), // 2012-05-10T14:00:00-0000
        ]
        
        #expect(results == expectedResults)
    }    
    @Test func testYearlyRecurrenceWithMonthAndWeekdayExpansion() {
        let start = Date(timeIntervalSince1970: 1704117600.0) // 2024-01-01T14:00:00-0000
        let end   = Date(timeIntervalSince1970: 1767225600.0) // 2026-01-01T00:00:00-0000
        
        var rule = Calendar.RecurrenceRule(calendar: gregorian, frequency: .yearly)
        rule.months = [5, 9]
        rule.weekdays = [.nth(1, .monday), .nth(-1, .friday)]
        
        let results = Array(rule.recurrences(of: start, in: start..<end))
        
        let expectedResults: [Date] = [
            Date(timeIntervalSince1970: 1715004000.0), // 2024-05-06T14:00:00-0000
            Date(timeIntervalSince1970: 1717164000.0), // 2024-05-31T14:00:00-0000
            Date(timeIntervalSince1970: 1725285600.0), // 2024-09-02T14:00:00-0000
            Date(timeIntervalSince1970: 1727445600.0), // 2024-09-27T14:00:00-0000
            Date(timeIntervalSince1970: 1746453600.0), // 2025-05-05T14:00:00-0000
            Date(timeIntervalSince1970: 1748613600.0), // 2025-05-30T14:00:00-0000
            Date(timeIntervalSince1970: 1756735200.0), // 2025-09-01T14:00:00-0000
            Date(timeIntervalSince1970: 1758895200.0), // 2025-09-26T14:00:00-0000
        ]
        
        #expect(results == expectedResults)
    }
    
    @Test func testYearlyRecurrenceWithWeekNumberExpansion() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // Week starts on Monday
        
        let start = Date(timeIntervalSince1970: 1704117600.0) // 2024-01-01T14:00:00-0000
        let end   = Date(timeIntervalSince1970: 1767225600.0) // 2026-01-01T00:00:00-0000
        
        var rule = Calendar.RecurrenceRule(calendar: gregorian, frequency: .yearly)
        rule.weeks = [1, -1]
        
        let results = Array(rule.recurrences(of: start, in: start..<end))
        
        let expectedResults: [Date] = [
            Date(timeIntervalSince1970: 1704117600.0), // 2024-01-01T14:00:00-0000
            Date(timeIntervalSince1970: 1734962400.0), // 2024-12-23T14:00:00-0000
            Date(timeIntervalSince1970: 1735740000.0), // 2025-01-01T14:00:00-0000
            Date(timeIntervalSince1970: 1766584800.0), // 2025-12-24T14:00:00-0000
        ]
        
        #expect(results == expectedResults)
    }
    
    @Test func testYearlyRecurrenceWithDayOfYearExpansion() {
        let start = Date(timeIntervalSince1970: 1695254400.0) // 2023-09-21T00:00:00-0000
        let end   = Date(timeIntervalSince1970: 1729468800.0) // 2024-10-21T00:00:00-0000
        
        var rule = Calendar.RecurrenceRule(calendar: gregorian, frequency: .yearly)
        rule.daysOfTheYear = [1, -1]
        
        let eventStart = Date(timeIntervalSince1970: 1285077600.0) // 2010-09-21T14:00:00-0000
        let results = Array(rule.recurrences(of: eventStart, in: start..<end))
        
        let expectedResults: [Date] = [
            Date(timeIntervalSince1970: 1704031200.0), // 2023-12-31T14:00:00-0000
            Date(timeIntervalSince1970: 1704117600.0), // 2024-01-01T14:00:00-0000
        ]
        
        #expect(results == expectedResults)
    }
    
    @Test func testHourlyRecurrenceWithWeekdayFilter() {
        // Repeat hourly, but filter to Sundays
        let start = Date(timeIntervalSince1970: 1590314400.0) // 2020-05-24T10:00:00-0000
        var rule = Calendar.RecurrenceRule(calendar: gregorian, frequency: .hourly)
        rule.weekdays = [.every(.sunday)]
        rule.end = .afterOccurrences(16) 
        let results = Array(rule.recurrences(of: start))
        let expectedResults: [Date] = [
            Date(timeIntervalSince1970: 1590314400.0), // 2020-05-24T10:00:00-0000
            Date(timeIntervalSince1970: 1590318000.0), // 2020-05-24T11:00:00-0000
            Date(timeIntervalSince1970: 1590321600.0), // 2020-05-24T12:00:00-0000
            Date(timeIntervalSince1970: 1590325200.0), // 2020-05-24T13:00:00-0000
            Date(timeIntervalSince1970: 1590328800.0), // 2020-05-24T14:00:00-0000
            Date(timeIntervalSince1970: 1590332400.0), // 2020-05-24T15:00:00-0000
            Date(timeIntervalSince1970: 1590336000.0), // 2020-05-24T16:00:00-0000
            Date(timeIntervalSince1970: 1590339600.0), // 2020-05-24T17:00:00-0000
            Date(timeIntervalSince1970: 1590343200.0), // 2020-05-24T18:00:00-0000
            Date(timeIntervalSince1970: 1590346800.0), // 2020-05-24T19:00:00-0000
            Date(timeIntervalSince1970: 1590350400.0), // 2020-05-24T20:00:00-0000
            Date(timeIntervalSince1970: 1590354000.0), // 2020-05-24T21:00:00-0000
            Date(timeIntervalSince1970: 1590357600.0), // 2020-05-24T22:00:00-0000
            Date(timeIntervalSince1970: 1590361200.0), // 2020-05-24T23:00:00-0000
            Date(timeIntervalSince1970: 1590883200.0), // 2020-05-31T00:00:00-0000
            Date(timeIntervalSince1970: 1590886800.0), // 2020-05-31T01:00:00-0000
        ]

        #expect(results == expectedResults)
    }
    @Test func testHourlyRecurrenceWithHourAndWeekdayFilter() {
        // Repeat hourly, filter to 10am on the last Sunday of the month
        let start = Date(timeIntervalSince1970: 1590314400.0) // 2020-05-24T10:00:00-0000
        var rule = Calendar.RecurrenceRule(calendar: gregorian, frequency: .hourly)
        rule.weekdays = [.nth(-1, .sunday)]
        rule.hours = [11]
        rule.end = .afterOccurrences(4) 
        let results = Array(rule.recurrences(of: start))
        let expectedResults: [Date] = [
            Date(timeIntervalSince1970: 1590922800.0), // 2020-05-31T11:00:00-0000
            Date(timeIntervalSince1970: 1593342000.0), // 2020-06-28T11:00:00-0000
            Date(timeIntervalSince1970: 1595761200.0), // 2020-07-26T11:00:00-0000
            Date(timeIntervalSince1970: 1598785200.0), // 2020-08-30T11:00:00-0000
        ]

        #expect(results == expectedResults)
    }
    @Test func testDailyRecurrenceWithHourlyExpansions() {
        // Repeat hourly, filter to 10am on the last Sunday of the month
        let start = Date(timeIntervalSince1970: 1590307200.0) // 2020-05-24T08:00:00-0000
        var rule = Calendar.RecurrenceRule(calendar: gregorian, frequency: .daily)
        rule.hours = [9, 10]
        rule.minutes = [0, 30]
        rule.seconds = [0, 30]
        rule.end = .afterOccurrences(10)
        let results = Array(rule.recurrences(of: start))
        let expectedResults: [Date] = [
            Date(timeIntervalSince1970: 1590310800.0), // 2020-05-24T09:00:00-0000
            Date(timeIntervalSince1970: 1590310830.0), // 2020-05-24T09:00:30-0000
            Date(timeIntervalSince1970: 1590312600.0), // 2020-05-24T09:30:00-0000
            Date(timeIntervalSince1970: 1590312630.0), // 2020-05-24T09:30:30-0000
            Date(timeIntervalSince1970: 1590314400.0), // 2020-05-24T10:00:00-0000
            Date(timeIntervalSince1970: 1590314430.0), // 2020-05-24T10:00:30-0000
            Date(timeIntervalSince1970: 1590316200.0), // 2020-05-24T10:30:00-0000
            Date(timeIntervalSince1970: 1590316230.0), // 2020-05-24T10:30:30-0000
            Date(timeIntervalSince1970: 1590397200.0), // 2020-05-25T09:00:00-0000
            Date(timeIntervalSince1970: 1590397230.0), // 2020-05-25T09:00:30-0000
        ]
        #expect(results == expectedResults)
   }
   
    
   @Test func testEmptySequence() {
        // Construct a recurrence rule which requests matches on the 32nd of May
        let start = Date(timeIntervalSince1970: 1704067200.0) // 2024-01-01T00:00:00-0000
        var rule = Calendar.RecurrenceRule(calendar: gregorian, frequency: .yearly)
        rule.months = [5]
        rule.daysOfTheMonth = [32]
        rule.matchingPolicy = .strict

        for _ in rule.recurrences(of: start) {
            Issue.record("Recurrence rule is not expected to produce results")
        }
        // If we get here, there isn't an infinite loop
   }
}
