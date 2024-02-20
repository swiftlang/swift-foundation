//
//  CalendarRecurrenceRuleTests.swift
//  Unit
//
//  Copyright (c) 2024, Apple Inc.
//  All rights reserved.
//

#if canImport(TestSupport)
import TestSupport
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable import FoundationInternationalization
@testable import FoundationEssentials
#endif // FOUNDATION_FRAMEWORK

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
final class CalendarRecurrenceRuleTests: XCTestCase {

    func testRoundtripEncoding() throws {
        // These are not necessarily valid recurrence rule, they are constructed
        // in a way to test all encoding paths
        var recurrenceRule1 = Calendar.RecurrenceRule(calendar: .current, frequency: .daily)
        recurrenceRule1.interval = 2
        recurrenceRule1.months = [1, 2, Calendar.RecurrenceRule.Month(4, isLeap: true)]
        recurrenceRule1.weeks = [2, 3]
        recurrenceRule1.weekdays = [.every(.monday), .nth(1, .wednesday)]
        recurrenceRule1.end = .afterOccurrences(5)
        
        var recurrenceRule2 = Calendar.RecurrenceRule(calendar: .init(identifier: .gregorian), frequency: .daily)
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
        
        XCTAssertEqual(recurrenceRule1, decoded1)
        XCTAssertEqual(recurrenceRule2, decoded2)
        XCTAssertNotEqual(recurrenceRule1, recurrenceRule2)
    }
}
