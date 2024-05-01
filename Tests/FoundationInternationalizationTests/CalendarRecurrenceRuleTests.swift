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

#if canImport(TestSupport)
import TestSupport
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable import FoundationInternationalization
@testable import FoundationEssentials
#endif // FOUNDATION_FRAMEWORK

@available(FoundationPreview 0.4, *)
final class CalendarRecurrenceRuleTests: XCTestCase {
    /// A Gregorian calendar with a time zone set to California
    var gregorian: Calendar = {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = .init(identifier: "US/Pacific")!
        return gregorian
    }()
    
    func testYearlyRecurrenceInLunarCalendar() {
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
        
        XCTAssertEqual(results, expectedResults)
    }
    
    func testDaylightSavingsRepeatedTimePolicyFirst() {
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
        XCTAssertEqual(results, expectedResults)
   }
   
   func testDaylightSavingsRepeatedTimePolicyLast() {
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
        XCTAssertEqual(results, expectedResults)
   }
}
