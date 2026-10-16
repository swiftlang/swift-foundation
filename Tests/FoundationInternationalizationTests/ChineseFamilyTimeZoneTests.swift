//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
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
#endif

/// Tests of the Chinese, Dangi and Vietnamese calendars that need a named time zone or the locale data, which the FoundationEssentials tests cannot load.
@Suite("Chinese Family Time Zones")
private struct ChineseFamilyTimeZoneTests {

    // Rolling the day back into a repeated hour gives the later time.
    @Test(arguments: [("America/New_York", 562_998_600.0, 562_912_200.0), ("America/New_York", 531_639_000.0, 531_549_000.0)])
    func rollDayBackInChineseAcrossOffsetChange(_ zone: String, _ start: Double, _ expected: Double) throws {
        let timeZone = try #require(TimeZone(identifier: zone))
        let calendar = Calendar(inner: _CalendarChinese(identifier: .chinese, timeZone: timeZone, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil))
        let result = calendar.date(byAdding: DateComponents(day: -1), to: Date(timeIntervalSinceReferenceDate: start), wrappingComponents: true)
        #expect(result == Date(timeIntervalSinceReferenceDate: expected), "\(zone)")
    }

    // Setting the first weekday and setting it back gives a calendar that equals one that never set it, and the two have the same hash.
    @Test(arguments: [Calendar.Identifier.chinese, .dangi, .vietnamese])
    func settingTheFirstWeekdayBackKeepsTheHash(_ identifier: Calendar.Identifier) {
        var changed = Calendar(inner: _CalendarChinese(identifier: identifier, timeZone: .gmt, locale: Locale(identifier: "en_US"), firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil))
        let untouched = changed
        changed.firstWeekday = 2
        changed.firstWeekday = 1
        #expect(changed == untouched)
        #expect(changed.hashValue == untouched.hashValue)
    }
}
