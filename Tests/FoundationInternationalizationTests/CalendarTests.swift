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

#if canImport(TestSupport)
import TestSupport
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable import FoundationInternationalization
@testable import FoundationEssentials
#endif // FOUNDATION_FRAMEWORK

extension DateComponents {
    fileprivate static func differenceBetween(_ d1: DateComponents?, _ d2: DateComponents?, compareQuarter: Bool, within nanosecondAccuracy: Int = 5000) -> String? {
        let components: [Calendar.Component] = [.era, .year, .month, .day, .dayOfYear, .hour, .minute, .second, .weekday, .weekdayOrdinal, .weekOfYear, .yearForWeekOfYear, .weekOfMonth, .timeZone, .isLeapMonth, .calendar, .quarter, .nanosecond]
        var diffStr = ""
        var isEqual = true
        for component in components {
            let actualValue = d1?.value(for: component)
            let expectedValue = d2?.value(for: component)
            switch component {
            case .era, .year, .month, .day, .dayOfYear, .hour, .minute, .second, .weekday, .weekdayOrdinal, .weekOfYear, .yearForWeekOfYear, .weekOfMonth, .timeZone, .isLeapMonth, .calendar:
                if actualValue != expectedValue {
                    diffStr += "\ncomponent: \(component), 1st: \(String(describing: actualValue)), 2nd: \(String(describing: expectedValue))"
                    isEqual = false
                }
            case .quarter:
                if compareQuarter && actualValue != expectedValue {
                    diffStr += "\ncomponent: \(component), 1st: \(String(describing: actualValue)), 2nd: \(String(describing: expectedValue))"
                    isEqual = false
                }
            case .nanosecond:
                var nanosecondIsEqual = true
                if let actualValue, let expectedValue, (abs(actualValue - expectedValue) > nanosecondAccuracy) {
                    nanosecondIsEqual = false
                } else if actualValue != expectedValue { // one of them is nil
                    nanosecondIsEqual = false
                }

                if !nanosecondIsEqual {
                    diffStr += "\ncomponent: \(component), 1st: \(String(describing: actualValue)), 2nd: \(String(describing: expectedValue))"
                    isEqual = false
                }
            }
        }

        return isEqual ? nil : diffStr
    }
}

final class CalendarTests : XCTestCase {

    var allCalendars: [Calendar] = [
        Calendar(identifier: .gregorian),
        Calendar(identifier: .buddhist),
        Calendar(identifier: .chinese),
        Calendar(identifier: .coptic),
        Calendar(identifier: .ethiopicAmeteMihret),
        Calendar(identifier: .ethiopicAmeteAlem),
        Calendar(identifier: .hebrew),
        Calendar(identifier: .iso8601),
        Calendar(identifier: .indian),
        Calendar(identifier: .islamic),
        Calendar(identifier: .islamicCivil),
        Calendar(identifier: .japanese),
        Calendar(identifier: .persian),
        Calendar(identifier: .republicOfChina),
        Calendar(identifier: .islamicTabular),
        Calendar(identifier: .islamicUmmAlQura)
    ]

    func test_copyOnWrite() {
        var c = Calendar(identifier: .gregorian)
        let c2 = c
        XCTAssertEqual(c, c2)

        // Change the weekday and check result
        let firstWeekday = c.firstWeekday
        let newFirstWeekday = firstWeekday < 7 ? firstWeekday + 1 : firstWeekday - 1

        c.firstWeekday = newFirstWeekday
        XCTAssertEqual(newFirstWeekday, c.firstWeekday)
        XCTAssertEqual(c2.firstWeekday, firstWeekday)

        XCTAssertNotEqual(c, c2)

        // Change the time zone and check result
        let c3 = c
        XCTAssertEqual(c, c3)

        let tz = c.timeZone
        // Use two different identifiers so we don't fail if the current time zone happens to be the one returned
        let aTimeZoneId = TimeZone.knownTimeZoneIdentifiers[1]
        let anotherTimeZoneId = TimeZone.knownTimeZoneIdentifiers[0]

        let newTz = tz.identifier == aTimeZoneId ? TimeZone(identifier: anotherTimeZoneId)! : TimeZone(identifier: aTimeZoneId)!

        c.timeZone = newTz

        // Do it again! Now it's unique
        c.timeZone = newTz

        XCTAssertNotEqual(c, c3)

    }

    func test_equality() {
        let autoupdating = Calendar.autoupdatingCurrent
        let autoupdating2 = Calendar.autoupdatingCurrent

        XCTAssertEqual(autoupdating, autoupdating2)

        let current = Calendar.current

        XCTAssertNotEqual(autoupdating, current)

        // Make a copy of current
        var current2 = current
        XCTAssertEqual(current, current2)

        // Mutate something (making sure we don't use the current time zone)
        if current2.timeZone.identifier == "America/Los_Angeles" {
            current2.timeZone = TimeZone(identifier: "America/New_York")!
        } else {
            current2.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        }
        XCTAssertNotEqual(current, current2)

        // Mutate something else
        current2 = current
        XCTAssertEqual(current, current2)

        current2.locale = Locale(identifier: "MyMadeUpLocale")
        XCTAssertNotEqual(current, current2)
    }

    func test_hash() {
        let calendars: [Calendar] = [
            Calendar.autoupdatingCurrent,
            Calendar(identifier: .buddhist),
            Calendar(identifier: .gregorian),
            Calendar(identifier: .islamic),
            Calendar(identifier: .iso8601),
        ]
        checkHashable(calendars, equalityOracle: { $0 == $1 })

        // autoupdating calendar isn't equal to the current, even though it's
        // likely to be the same.
        let calendars2: [Calendar] = [
            Calendar.autoupdatingCurrent,
            Calendar.current,
        ]
        checkHashable(calendars2, equalityOracle: { $0 == $1 })
    }

    func test_AnyHashableContainingCalendar() {
        let values: [Calendar] = [
            Calendar(identifier: .gregorian),
            Calendar(identifier: .japanese),
            Calendar(identifier: .japanese)
        ]
        let anyHashables = values.map(AnyHashable.init)
        expectEqual(Calendar.self, type(of: anyHashables[0].base))
        expectEqual(Calendar.self, type(of: anyHashables[1].base))
        expectEqual(Calendar.self, type(of: anyHashables[2].base))
        XCTAssertNotEqual(anyHashables[0], anyHashables[1])
        XCTAssertEqual(anyHashables[1], anyHashables[2])
    }

    func decodeHelper(_ l: Calendar) -> Calendar {
        let je = JSONEncoder()
        let data = try! je.encode(l)
        let jd = JSONDecoder()
        return try! jd.decode(Calendar.self, from: data)
    }

    func test_serializationOfCurrent() {
        let current = Calendar.current
        let decodedCurrent = decodeHelper(current)
        XCTAssertEqual(decodedCurrent, current)

        let autoupdatingCurrent = Calendar.autoupdatingCurrent
        let decodedAutoupdatingCurrent = decodeHelper(autoupdatingCurrent)
        XCTAssertEqual(decodedAutoupdatingCurrent, autoupdatingCurrent)

        XCTAssertNotEqual(decodedCurrent, decodedAutoupdatingCurrent)
        XCTAssertNotEqual(current, autoupdatingCurrent)
        XCTAssertNotEqual(decodedCurrent, autoupdatingCurrent)
        XCTAssertNotEqual(current, decodedAutoupdatingCurrent)

        // Calendar, unlike TimeZone and Locale, has some mutable properties
        var modified = Calendar.autoupdatingCurrent
        modified.firstWeekday = 6
        let decodedModified = decodeHelper(modified)
        XCTAssertNotEqual(decodedModified, autoupdatingCurrent)
        XCTAssertEqual(modified, decodedModified)
    }

    func validateOrdinality(_ expected: Array<Array<Int?>>, calendar: Calendar, date: Date) {
        let units: [Calendar.Component] = [.era, .year, .month, .day, .hour, .minute, .second, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .nanosecond]

        var smallerIndex = 0
        for smaller in units {
            var largerIndex = 0
            for larger in units {
                let ordinality = calendar.ordinality(of: smaller, in: larger, for: date)
                let expected = expected[largerIndex][smallerIndex]
                XCTAssertEqual(ordinality, expected, "Unequal for \(smaller) in \(larger)")
                largerIndex += 1
            }
            smallerIndex += 1
        }
    }

    func validateRange(_ expected: Array<Array<Range<Int>?>>, calendar: Calendar, date: Date) {
        let units: [Calendar.Component] = [.era, .year, .month, .day, .hour, .minute, .second, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .nanosecond]

        var smallerIndex = 0
        for smaller in units {
            var largerIndex = 0
            for larger in units {
                let range = calendar.range(of: smaller, in: larger, for: date)
                let expected = expected[largerIndex][smallerIndex]
                XCTAssertEqual(range, expected, "Unequal for \(smaller) in \(larger)")
                largerIndex += 1
            }
            smallerIndex += 1
        }
    }

    func compareOrdinality(at date: Date, calendar1: Calendar, calendar2: Calendar) {
        let units: [Calendar.Component] = [.era, .year, .month, .day, .hour, .minute, .second, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .nanosecond]

        var smallerIndex = 0
        for smaller in units {
            print("--- \(smaller)")
            var largerIndex = 0
            for larger in units {
                let ordinality1 = calendar1.ordinality(of: smaller, in: larger, for: date)
                let ordinality2 = calendar2.ordinality(of: smaller, in: larger, for: date)
                if ordinality1 != ordinality2 {
                    print("Mismatch for \(smaller) in \(larger): \(String(describing: ordinality1)) \(String(describing: ordinality2))")
                }
                largerIndex += 1
            }
            smallerIndex += 1
        }
    }

    // This test requires 64-bit integers
    #if arch(x86_64) || arch(arm64)
    func test_ordinality() {
        let expected: Array<Array<Int?>> = [
            /* [era, year, month, day, hour, minute, second, weekday, weekdayOrdinal, quarter, weekOfMonth, weekOfYear, yearForWeekOfYear, nanosecond] */
            /* era */ [nil, 2022, 24260, 738389, 17721328, 1063279623, 63796777359, 105484, 105484, 8087, 105485, 105485, 2022, nil],
            /* year */ [nil, nil, 8, 234, 5608, 336423, 20185359, 34, 34, 3, nil, 35, nil, 20185358712306977],
            /* month */ [nil, nil, nil, 22, 520, 31143, 1868559, 4, 4, nil, 4, nil, nil, 1868558712306977],
            /* day */ [nil, nil, nil, nil, 16, 903, 54159, nil, nil, nil, nil, nil, nil, 54158712306977],
            /* hour */ [nil, nil, nil, nil, nil, 3, 159, nil, nil, nil, nil, nil, nil, 158712306977],
            /* minute */ [nil, nil, nil, nil, nil, nil, 39, nil, nil, nil, nil, nil, nil, 38712306977],
            /* second */ [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 712306977],
            /* weekday */ [nil, nil, nil, nil, 16, 903, 54159, nil, nil, nil, nil, nil, nil, 54158712306977],
            /* weekdayOrdinal */ [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil],
            /* quarter */ [nil, nil, 2, 53, 1264, 75783, 4546959, 8, 8, nil, 9, 9, nil, 4546958712306977],
            /* weekOfMonth */ [nil, nil, nil, 2, 40, 2343, 140559, 2, nil, nil, nil, nil, nil, 140558712306977],
            /* weekOfYear */ [nil, nil, nil, 2, 40, 2343, 140559, 2, nil, nil, nil, nil, nil, 140558712306977],
            /* yearForWeekOfYear */ [nil, nil, nil, 240, 5737, 344161, 20649601, 35, 35, nil, nil, 35, nil, 20649600712306977],
            /* nanosecond */ [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
        ]

        // An arbitrary date, for which we know the answers
        // August 22, 2022 at 3:02:38 PM PDT
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        validateOrdinality(expected, calendar: calendar, date: Date(timeIntervalSinceReferenceDate: 682898558.712307))
    }

    func test_ordinality_dst() {
        let expected: Array<Array<Int?>> = [
            /* [era, year, month, day, hour, minute, second, weekday, weekdayOrdinal, quarter, weekOfMonth, weekOfYear, yearForWeekOfYear, nanosecond] */
            /* era */ [nil, 2022, 24255, 738227, 17717428, 1063045623, 63782737329, 105461, 105461, 8085, 105461, 105461, 2022, nil],
            /* year */ [nil, nil, 3, 72, 1708, 102423, 6145329, 11, 11, 1, nil, 12, nil, 6145328712000013],
            /* month */ [nil, nil, nil, 13, 292, 17463, 1047729, 2, 2, nil, 3, nil, nil, 1047728712000013],
            /* day */ [nil, nil, nil, nil, 4, 183, 10929, nil, nil, nil, nil, nil, nil, 10928712000013],
            /* hour */ [nil, nil, nil, nil, nil, 3, 129, nil, nil, nil, nil, nil, nil, 128712000013],
            /* minute */ [nil, nil, nil, nil, nil, nil, 9, nil, nil, nil, nil, nil, nil, 8712000013],
            /* second */ [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 712000013],
            /* weekday */ [nil, nil, nil, nil, 4, 183, 10929, nil, nil, nil, nil, nil, nil, 10928712000013],
            /* weekdayOrdinal */ [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil],
            /* quarter */ [nil, nil, 3, 72, 1708, 102423, 6145329, 11, 11, nil, 12, 12, nil, 6145328712000013],
            /* weekOfMonth */ [nil, nil, nil, 1, 4, 183, 10929, 1, nil, nil, nil, nil, nil, 10928712000013],
            /* weekOfYear */ [nil, nil, nil, 1, 4, 183, 10929, 1, nil, nil, nil, nil, nil, 10928712000013],
            /* yearForWeekOfYear */ [nil, nil, nil, 78, 1849, 110881, 6652801, 12, 12, nil, nil, 12, nil, 6652800712000013],
            /* nanosecond */ [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
        ]

        // A date which corresponds to a DST transition in Pacific Time
        // let d = try! Date("2022-03-13T03:02:08.712-07:00", strategy: .iso8601)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        validateOrdinality(expected, calendar: calendar, date: Date(timeIntervalSinceReferenceDate: 668858528.712))
    }
    #endif // arch(x86_64) || arch(arm64)
    
    // This test requires 64-bit integers
    #if (arch(x86_64) || arch(arm64)) && FOUNDATION_FRAMEWORK
    func test_multithreadedCalendarAccess() {
        let expected: Array<Array<Int?>> = [
            /* [era, year, month, day, hour, minute, second, weekday, weekdayOrdinal, quarter, weekOfMonth, weekOfYear, yearForWeekOfYear, nanosecond] */
            /* era */ [nil, 2022, 24260, 738389, 17721328, 1063279623, 63796777359, 105484, 105484, 8087, 105485, 105485, 2022, nil],
            /* year */ [nil, nil, 8, 234, 5608, 336423, 20185359, 34, 34, 3, nil, 35, nil, 20185358712306977],
            /* month */ [nil, nil, nil, 22, 520, 31143, 1868559, 4, 4, nil, 4, nil, nil, 1868558712306977],
            /* day */ [nil, nil, nil, nil, 16, 903, 54159, nil, nil, nil, nil, nil, nil, 54158712306977],
            /* hour */ [nil, nil, nil, nil, nil, 3, 159, nil, nil, nil, nil, nil, nil, 158712306977],
            /* minute */ [nil, nil, nil, nil, nil, nil, 39, nil, nil, nil, nil, nil, nil, 38712306977],
            /* second */ [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 712306977],
            /* weekday */ [nil, nil, nil, nil, 16, 903, 54159, nil, nil, nil, nil, nil, nil, 54158712306977],
            /* weekdayOrdinal */ [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil],
            /* quarter */ [nil, nil, 2, 53, 1264, 75783, 4546959, 8, 8, nil, 9, 9, nil, 4546958712306977],
            /* weekOfMonth */ [nil, nil, nil, 2, 40, 2343, 140559, 2, nil, nil, nil, nil, nil, 140558712306977],
            /* weekOfYear */ [nil, nil, nil, 2, 40, 2343, 140559, 2, nil, nil, nil, nil, nil, 140558712306977],
            /* yearForWeekOfYear */ [nil, nil, nil, 240, 5737, 344161, 20649601, 35, 35, nil, nil, 35, nil, 20649600712306977],
            /* nanosecond */ [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
        ]

        // An arbitrary date, for which we know the answers
        // August 22, 2022 at 3:02:38 PM PDT
        let date = Date(timeIntervalSinceReferenceDate: 682898558.712307)

        // Explicitly shared amongst all the below threads
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!

        let group = DispatchGroup()
        let queue = DispatchQueue(label: "calendar test", qos: .default, attributes: .concurrent, autoreleaseFrequency: .workItem)
        for _ in 1..<10 {
            queue.async(group: group) {
                self.validateOrdinality(expected, calendar: calendar, date: date)
            }
        }
        XCTAssertEqual(.success, group.wait(timeout: .now().advanced(by: .seconds(3))))
    }
    #endif // (arch(x86_64) || arch(arm64)) && FOUNDATION_FRAMEWORK

    func test_range() {
        let expected : [[Range<Int>?]] =
            [[nil, 1..<144684, 1..<13, 1..<32, 0..<24, 0..<60, 0..<60, 1..<8, 1..<6, 1..<5, 1..<7, 1..<54, nil, 0..<1_000_000_000],
            [nil, nil, 1..<13, 1..<366, 0..<24, 0..<60, 0..<60, 1..<8, 1..<60, 1..<5, 1..<64, 1..<54, nil, 0..<1_000_000_000],
            [nil, nil, nil, 1..<32, 0..<24, 0..<60, 0..<60, 1..<8, 1..<6, nil, 1..<6, 32..<37, nil, 0..<1_000_000_000],
            [nil, nil, nil, nil, 0..<24, 0..<60, 0..<60, nil, nil, nil, nil, nil, nil, 0..<1_000_000_000],
            [nil, nil, nil, nil, nil, 0..<60, 0..<60, nil, nil, nil, nil, nil, nil, 0..<1_000_000_000],
            [nil, nil, nil, nil, nil, nil, 0..<60, nil, nil, nil, nil, nil, nil, 0..<1_000_000_000],
            [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 0..<1_000_000_000],
            [nil, nil, nil, nil, 0..<24, 0..<60, 0..<60, nil, nil, nil, nil, nil, nil, 0..<1_000_000_000],
            [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil],
            [nil, nil, 7..<10, 1..<93, 0..<24, 0..<60, 0..<60, 1..<8, 1..<16, nil, 1..<17, 27..<41, nil, 0..<1_000_000_000],
            [nil, nil, nil, 21..<28, 0..<24, 0..<60, 0..<60, 1..<8, nil, nil, nil, nil, nil, 0..<1_000_000_000],
            [nil, nil, nil, nil, 0..<24, 0..<60, 0..<60, 1..<8, nil, nil, nil, nil, nil, 0..<1_000_000_000],
            [nil, nil, nil, 1..<397, 0..<24, 0..<60, 0..<60, 1..<8, 1..<65, nil, nil, 1..<54, nil, 0..<1_000_000_000],
            [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]]

        // An arbitrary date, for which we know the answers
        // August 22, 2022 at 3:02:38 PM PDT
        let date = Date(timeIntervalSinceReferenceDate: 682898558.712307)
        let calendar = Calendar(identifier: .gregorian)

        validateRange(expected, calendar: calendar, date: date)
    }

    func test_range_dst() {
        let expected : [[Range<Int>?]] =
            [[nil, 1..<144684, 1..<13, 1..<32, 0..<24, 0..<60, 0..<60, 1..<8, 1..<6, 1..<5, 1..<7, 1..<54, nil, 0..<1_000_000_000],
            [nil, nil, 1..<13, 1..<366, 0..<24, 0..<60, 0..<60, 1..<8, 1..<60, 1..<5, 1..<64, 1..<54, nil, 0..<1_000_000_000],
            [nil, nil, nil, 1..<32, 0..<24, 0..<60, 0..<60, 1..<8, 1..<6, nil, 1..<6, 10..<15, nil, 0..<1_000_000_000],
            [nil, nil, nil, nil, 0..<24, 0..<60, 0..<60, nil, nil, nil, nil, nil, nil, 0..<1_000_000_000],
            [nil, nil, nil, nil, nil, 0..<60, 0..<60, nil, nil, nil, nil, nil, nil, 0..<1_000_000_000],
            [nil, nil, nil, nil, nil, nil, 0..<60, nil, nil, nil, nil, nil, nil, 0..<1_000_000_000],
            [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 0..<1_000_000_000],
            [nil, nil, nil, nil, 0..<24, 0..<60, 0..<60, nil, nil, nil, nil, nil, nil, 0..<1_000_000_000],
            [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil],
            [nil, nil, 1..<4, 1..<91, 0..<24, 0..<60, 0..<60, 1..<8, 1..<15, nil, 1..<17, 1..<15, nil, 0..<1_000_000_000],
            [nil, nil, nil, 13..<20, 0..<24, 0..<60, 0..<60, 1..<8, nil, nil, nil, nil, nil, 0..<1_000_000_000],
            [nil, nil, nil, nil, 0..<24, 0..<60, 0..<60, 1..<8, nil, nil, nil, nil, nil, 0..<1_000_000_000],
            [nil, nil, nil, 1..<397, 0..<24, 0..<60, 0..<60, 1..<8, 1..<65, nil, nil, 1..<54, nil, 0..<1_000_000_000],
             [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]]

        // A date which corresponds to a DST transition in Pacific Time
        // let d = try! Date("2022-03-13T03:02:08.712-07:00", strategy: .iso8601)
        validateRange(expected, calendar: Calendar(identifier: .gregorian), date: Date(timeIntervalSinceReferenceDate: 668858528.712))
    }

    // This test requires 64-bit integers
    #if arch(x86_64) || arch(arm64)
    func test_addingLargeValues() {
        let dc = DateComponents(month: 3, day: Int(Int32.max) + 10)
        let date = Date.now
        let result = Calendar(identifier: .gregorian).date(byAdding: dc, to: date)
        XCTAssertNotNil(result)
    }
    #endif // arch(x86_64) || arch(arm64)

    func test_chineseYearlessBirthdays() {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: "UTC")!
        let threshold = gregorian.date(from: DateComponents(era: 1, year: 1605, month: 1, day: 1, hour: 0, minute: 0, second: 0, nanosecond: 0))!

        var calendar = Calendar(identifier: .chinese)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var components = DateComponents(calendar: calendar, month: 9, day: 1)
        components.isLeapMonth = true
        // TimeZone.default points to GTC on Linux
        components.timeZone = TimeZone(identifier: "America/Los_Angeles")
        components.era = nil

        var foundDate: Date?
        var count = 0
        var loopedForever = false
        components.calendar!.enumerateDates(startingAfter: threshold, matching: components, matchingPolicy: .strict, direction: .backward) { result, exactMatch, stop in
            count += 1
            if exactMatch {
                foundDate = result
                stop = true
            } else if count > 5 {
                loopedForever = true
                stop = true
            }
        }

        XCTAssertFalse(loopedForever)
        XCTAssertNotNil(foundDate)
        // Expected 1126-10-18 07:52:58 +0000
        XCTAssertEqual(foundDate!.timeIntervalSinceReferenceDate, -27586714022)
    }

    func test_dateFromComponentsNearDSTTransition() {
        let comps = DateComponents(year: 2021, month: 11, day: 7, hour: 1, minute: 45)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(abbreviation: "PDT")!
        let result = cal.date(from: comps)
        XCTAssertEqual(result?.timeIntervalSinceReferenceDate, 657967500)
    }

    func test_dayInWeekOfMonth() {
        let cal = Calendar(identifier: .chinese)
        // A very specific date for which we know a call into ICU produces an unusual result
        let date = Date(timeIntervalSinceReferenceDate: 1790212894.000224)
        let result = cal.range(of: .day, in: .weekOfMonth, for: date)
        XCTAssertNotNil(result)
    }

    func test_dateBySettingNearDSTTransition() {
        let cal = Calendar(identifier: .gregorian)
        let midnightDate = Date(timeIntervalSinceReferenceDate: 689673600.0) // 2022-11-09 08:00:00 +0000
        // A compatibility behavior of `DateComponents` interop with `NSDateComponents` is that it must accept `Int.max` (NSNotFound) the same as `nil`.
        let result = cal.date(bySettingHour: 15, minute: 6, second: Int.max, of: midnightDate)
        XCTAssertNotNil(result)
    }

    func test_properties() {
        var c = Calendar(identifier: .gregorian)
        // Use english localization
        c.locale = Locale(identifier: "en_US")
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!

        // The idea behind these tests is not to test calendrical math, but to simply verify that we are getting some kind of result from calling through to the underlying Foundation and ICU logic. If we move that logic into this struct in the future, then we will need to expand the test cases.

        // This is a very special Date in my life: the exact moment when I wrote these test cases and therefore knew all of the answers.
        let d = Date(timeIntervalSince1970: 1468705593.2533731)
        let earlierD = c.date(byAdding: DateComponents(day: -10), to: d)!

        XCTAssertEqual(1..<29, c.minimumRange(of: .day))
        XCTAssertEqual(1..<54, c.maximumRange(of: .weekOfYear))
        XCTAssertEqual(0..<60, c.range(of: .second, in: .minute, for: d))

        var d1 = Date()
        var ti : TimeInterval = 0

        XCTAssertTrue(c.dateInterval(of: .day, start: &d1, interval: &ti, for: d))
        XCTAssertEqual(Date(timeIntervalSince1970: 1468652400.0), d1)
        XCTAssertEqual(86400, ti)

        let dateInterval = c.dateInterval(of: .day, for: d)
        XCTAssertEqual(DateInterval(start: d1, duration: ti), dateInterval)

        XCTAssertEqual(15, c.ordinality(of: .hour, in: .day, for: d))

        XCTAssertEqual(Date(timeIntervalSince1970: 1468791993.2533731), c.date(byAdding: .day, value: 1, to: d))
        XCTAssertEqual(Date(timeIntervalSince1970: 1468791993.2533731), c.date(byAdding: DateComponents(day: 1),  to: d))

        XCTAssertEqual(Date(timeIntervalSince1970: 946627200.0), c.date(from: DateComponents(year: 1999, month: 12, day: 31)))

        let comps = c.dateComponents([.year, .month, .day], from: Date(timeIntervalSince1970: 946627200.0))
        XCTAssertEqual(1999, comps.year)
        XCTAssertEqual(12, comps.month)
        XCTAssertEqual(31, comps.day)

        XCTAssertEqual(10, c.dateComponents([.day], from: d, to: c.date(byAdding: DateComponents(day: 10), to: d)!).day)

        XCTAssertEqual(30, c.dateComponents([.day], from: DateComponents(year: 1999, month: 12, day: 1), to: DateComponents(year: 1999, month: 12, day: 31)).day)

        XCTAssertEqual(2016, c.component(.year, from: d))

        XCTAssertEqual(Date(timeIntervalSince1970: 1468652400.0), c.startOfDay(for: d))

        // Mac OS X 10.9 and iOS 7 had a bug in NSCalendar for hour, minute, and second granularities.
        XCTAssertEqual(.orderedSame, c.compare(d, to: d + 10, toGranularity: .minute))

        XCTAssertFalse(c.isDate(d, equalTo: d + 10, toGranularity: .second))
        XCTAssertTrue(c.isDate(d, equalTo: d + 10, toGranularity: .day))

        XCTAssertFalse(c.isDate(earlierD, inSameDayAs: d))
        XCTAssertTrue(c.isDate(d, inSameDayAs: d))

        XCTAssertFalse(c.isDateInToday(earlierD))
        XCTAssertFalse(c.isDateInYesterday(earlierD))
        XCTAssertFalse(c.isDateInTomorrow(earlierD))

        XCTAssertTrue(c.isDateInWeekend(d)) // 😢

        XCTAssertTrue(c.dateIntervalOfWeekend(containing: d, start: &d1, interval: &ti))

        let thisWeekend = DateInterval(start: Date(timeIntervalSince1970: 1468652400.0), duration: 172800.0)

        XCTAssertEqual(thisWeekend, DateInterval(start: d1, duration: ti))
        XCTAssertEqual(thisWeekend, c.dateIntervalOfWeekend(containing: d))

        XCTAssertTrue(c.nextWeekend(startingAfter: d, start: &d1, interval: &ti))

        let nextWeekend = DateInterval(start: Date(timeIntervalSince1970: 1469257200.0), duration: 172800.0)

        XCTAssertEqual(nextWeekend, DateInterval(start: d1, duration: ti))
        XCTAssertEqual(nextWeekend, c.nextWeekend(startingAfter: d))

        // Enumeration

        var count = 0
        var exactCount = 0

        // Find the days numbered '31' after 'd', allowing the algorithm to move to the next day if required
        c.enumerateDates(startingAfter: d, matching: DateComponents(day: 31), matchingPolicy: .nextTime) { result, exact, stop in
            // Just stop some arbitrary time in the future
            if result! > d + 86400*365 { stop = true }
            count += 1
            if exact { exactCount += 1 }
        }

        /*
         Optional(2016-07-31 07:00:00 +0000)
         Optional(2016-08-31 07:00:00 +0000)
         Optional(2016-10-01 07:00:00 +0000)
         Optional(2016-10-31 07:00:00 +0000)
         Optional(2016-12-01 08:00:00 +0000)
         Optional(2016-12-31 08:00:00 +0000)
         Optional(2017-01-31 08:00:00 +0000)
         Optional(2017-03-01 08:00:00 +0000)
         Optional(2017-03-31 07:00:00 +0000)
         Optional(2017-05-01 07:00:00 +0000)
         Optional(2017-05-31 07:00:00 +0000)
         Optional(2017-07-01 07:00:00 +0000)
         Optional(2017-07-31 07:00:00 +0000)
         */

        XCTAssertEqual(count, 13)
        XCTAssertEqual(exactCount, 8)


        XCTAssertEqual(Date(timeIntervalSince1970: 1469948400.0), c.nextDate(after: d, matching: DateComponents(day: 31), matchingPolicy: .nextTime))


        XCTAssertEqual(Date(timeIntervalSince1970: 1468742400.0),  c.date(bySetting: .hour, value: 1, of: d))

        XCTAssertEqual(Date(timeIntervalSince1970: 1468656123.0), c.date(bySettingHour: 1, minute: 2, second: 3, of: d, matchingPolicy: .nextTime))

        XCTAssertTrue(c.date(d, matchesComponents: DateComponents(month: 7)))
        XCTAssertFalse(c.date(d, matchesComponents: DateComponents(month: 7, day: 31)))
    }
    
    func test_leapMonthProperty() throws {
        let c = Calendar(identifier: .chinese)
        /// 2023-02-20 08:00:00 +0000 -- non-leap month in the Chinese calendar
        let d1 = Date(timeIntervalSinceReferenceDate: 698572800.0)
        /// 2023-03-22 07:00:00 +0000 -- leap month in the Chinese calendar
        let d2 = Date(timeIntervalSinceReferenceDate: 701161200.0)
        
        var components = DateComponents()
        components.isLeapMonth = true
        XCTAssertFalse(c.date(d1, matchesComponents: components))
        XCTAssertTrue(c.date(d2, matchesComponents: components))
        components.isLeapMonth = false
        XCTAssertTrue(c.date(d1, matchesComponents: components))
        XCTAssertFalse(c.date(d2, matchesComponents: components))
        components.day = 1
        components.isLeapMonth = true
        XCTAssertFalse(c.date(d1, matchesComponents: components))
        XCTAssertTrue(c.date(d2, matchesComponents: components))
    }

    func test_addingDeprecatedWeek() throws {
        let date = try Date("2024-02-24 01:00:00 UTC", strategy: .iso8601.dateTimeSeparator(.space))
        var dc = DateComponents()
        dc.week = 1

        let calendar = Calendar(identifier: .gregorian)
        let oneWeekAfter = calendar.date(byAdding: dc, to: date)

        let expected = date.addingTimeInterval(86400*7)
        XCTAssertEqual(oneWeekAfter, expected)
    }

    func test_symbols() {
        var c = Calendar(identifier: .gregorian)
        // Use english localization
        c.locale = Locale(identifier: "en_US")
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!

        XCTAssertEqual("AM", c.amSymbol)
        XCTAssertEqual("PM", c.pmSymbol)
        XCTAssertEqual(["1st quarter", "2nd quarter", "3rd quarter", "4th quarter"], c.quarterSymbols)
        XCTAssertEqual(["1st quarter", "2nd quarter", "3rd quarter", "4th quarter"], c.standaloneQuarterSymbols)
        XCTAssertEqual(["BC", "AD"], c.eraSymbols)
        XCTAssertEqual(["Before Christ", "Anno Domini"], c.longEraSymbols)
        XCTAssertEqual(["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"], c.veryShortMonthSymbols)
        XCTAssertEqual(["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"], c.veryShortStandaloneMonthSymbols)
        XCTAssertEqual(["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"], c.shortMonthSymbols)
        XCTAssertEqual(["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"], c.shortStandaloneMonthSymbols)
        XCTAssertEqual(["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], c.monthSymbols)
        XCTAssertEqual(["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], c.standaloneMonthSymbols)
        XCTAssertEqual(["Q1", "Q2", "Q3", "Q4"], c.shortQuarterSymbols)
        XCTAssertEqual(["Q1", "Q2", "Q3", "Q4"], c.shortStandaloneQuarterSymbols)
        XCTAssertEqual(["S", "M", "T", "W", "T", "F", "S"], c.veryShortStandaloneWeekdaySymbols)
        XCTAssertEqual(["S", "M", "T", "W", "T", "F", "S"], c.veryShortWeekdaySymbols)
        XCTAssertEqual(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], c.shortStandaloneWeekdaySymbols)
        XCTAssertEqual(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], c.shortWeekdaySymbols)
        XCTAssertEqual(["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"], c.standaloneWeekdaySymbols)
        XCTAssertEqual(["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"], c.weekdaySymbols)
    }

    func test_symbols_not_gregorian() {
        var c = Calendar(identifier: .hebrew)
        c.locale = Locale(identifier: "en_US")
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!

        XCTAssertEqual("AM", c.amSymbol)
        XCTAssertEqual("PM", c.pmSymbol)
        XCTAssertEqual( [ "1st quarter", "2nd quarter", "3rd quarter", "4th quarter" ], c.quarterSymbols)
        XCTAssertEqual( [ "1st quarter", "2nd quarter", "3rd quarter", "4th quarter" ], c.standaloneQuarterSymbols)
        XCTAssertEqual( [ "AM" ], c.eraSymbols)
        XCTAssertEqual( [ "AM" ], c.longEraSymbols)
        XCTAssertEqual( [ "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "7" ], c.veryShortMonthSymbols)
        XCTAssertEqual( [ "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "7" ], c.veryShortStandaloneMonthSymbols)
        XCTAssertEqual( [ "Tishri", "Heshvan", "Kislev", "Tevet", "Shevat", "Adar I", "Adar", "Nisan", "Iyar", "Sivan", "Tamuz", "Av", "Elul", "Adar II" ], c.shortMonthSymbols)
        XCTAssertEqual( [ "Tishri", "Heshvan", "Kislev", "Tevet", "Shevat", "Adar I", "Adar", "Nisan", "Iyar", "Sivan", "Tamuz", "Av", "Elul", "Adar II" ], c.shortStandaloneMonthSymbols)
        XCTAssertEqual( [ "Tishri", "Heshvan", "Kislev", "Tevet", "Shevat", "Adar I", "Adar", "Nisan", "Iyar", "Sivan", "Tamuz", "Av", "Elul", "Adar II"  ], c.monthSymbols)
        XCTAssertEqual( [ "Tishri", "Heshvan", "Kislev", "Tevet", "Shevat", "Adar I", "Adar", "Nisan", "Iyar", "Sivan", "Tamuz", "Av", "Elul", "Adar II"  ], c.standaloneMonthSymbols)
        XCTAssertEqual( [ "Q1", "Q2", "Q3", "Q4" ], c.shortQuarterSymbols)
        XCTAssertEqual( [ "Q1", "Q2", "Q3", "Q4" ], c.shortStandaloneQuarterSymbols)
        XCTAssertEqual( [ "S", "M", "T", "W", "T", "F", "S" ], c.veryShortStandaloneWeekdaySymbols)
        XCTAssertEqual( [ "S", "M", "T", "W", "T", "F", "S" ], c.veryShortWeekdaySymbols)
        XCTAssertEqual( [ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" ], c.shortStandaloneWeekdaySymbols)
        XCTAssertEqual( [ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" ], c.shortWeekdaySymbols)
        XCTAssertEqual( [ "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" ], c.standaloneWeekdaySymbols)
        XCTAssertEqual( [ "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" ], c.weekdaySymbols)

        c.locale = Locale(identifier: "es_ES")
        XCTAssertEqual("a.\u{202f}m.", c.amSymbol)
        XCTAssertEqual("p.\u{202f}m.", c.pmSymbol)
        XCTAssertEqual( [ "1.er trimestre", "2.\u{00ba} trimestre", "3.er trimestre", "4.\u{00ba} trimestre" ], c.quarterSymbols)
        XCTAssertEqual( [ "1.er trimestre", "2.\u{00ba} trimestre", "3.er trimestre", "4.\u{00ba} trimestre" ], c.standaloneQuarterSymbols)
        XCTAssertEqual( [ "AM" ], c.eraSymbols)
        XCTAssertEqual( [ "AM" ], c.longEraSymbols)
        XCTAssertEqual( [ "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "7" ], c.veryShortMonthSymbols)
        XCTAssertEqual( [ "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "7" ], c.veryShortStandaloneMonthSymbols)
        XCTAssertEqual( [ "tishri", "heshvan", "kislev", "tevet", "shevat", "adar I", "adar", "nisan", "iyar", "sivan", "tamuz", "av", "elul", "adar II" ], c.shortMonthSymbols)
        XCTAssertEqual( [ "tishri", "heshvan", "kislev", "tevet", "shevat", "adar I", "adar", "nisan", "iyar", "sivan", "tamuz", "av", "elul", "adar II" ], c.shortStandaloneMonthSymbols)
        XCTAssertEqual( [ "tishri", "heshvan", "kislev", "tevet", "shevat", "adar I", "adar", "nisan", "iyar", "sivan", "tamuz", "av", "elul", "adar II" ], c.monthSymbols)
        XCTAssertEqual( [ "tishri", "heshvan", "kislev", "tevet", "shevat", "adar I", "adar", "nisan", "iyar", "sivan", "tamuz", "av", "elul", "adar II" ], c.standaloneMonthSymbols)
        XCTAssertEqual( [ "T1", "T2", "T3", "T4" ], c.shortQuarterSymbols)
        XCTAssertEqual( [ "T1", "T2", "T3", "T4" ], c.shortStandaloneQuarterSymbols)
        XCTAssertEqual( [ "D", "L", "M", "X", "J", "V", "S" ], c.veryShortStandaloneWeekdaySymbols)
        XCTAssertEqual( [ "D", "L", "M", "X", "J", "V", "S" ], c.veryShortWeekdaySymbols)
        XCTAssertEqual( [ "dom", "lun", "mar", "mi\u{00e9}", "jue", "vie", "s\u{00e1}b" ], c.shortStandaloneWeekdaySymbols)
        XCTAssertEqual( [ "dom", "lun", "mar", "mi\u{00e9}", "jue", "vie", "s\u{00e1}b" ], c.shortWeekdaySymbols)
        XCTAssertEqual( [ "domingo", "lunes", "martes", "mi\u{00e9}rcoles", "jueves", "viernes", "s\u{00e1}bado" ], c.standaloneWeekdaySymbols)
        XCTAssertEqual( [ "domingo", "lunes", "martes", "mi\u{00e9}rcoles", "jueves", "viernes", "s\u{00e1}bado" ], c.weekdaySymbols)
    }
    
    func test_weekOfMonthLoop() {
        // This test simply needs to not hang or crash
        let date = Date(timeIntervalSinceReferenceDate: 2.4499581972890255e+18)
        let calendar = Calendar(identifier: .gregorian)
        let components = DateComponents(weekOfMonth: 3)
        _ = calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTime)
        _ = calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTimePreservingSmallerComponents)
        _ = calendar.nextDate(after: date, matching: components, matchingPolicy: .previousTimePreservingSmallerComponents)
    }

    func test_weekendRangeNilLocale() {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "en_001")

        var c_nilLocale = Calendar(identifier: .gregorian)
        c_nilLocale.locale = nil

        let date = Date(timeIntervalSince1970: 0)
        let weekend = c.nextWeekend(startingAfter: date)
        let weekendForNilLocale = c_nilLocale.nextWeekend(startingAfter: date)
        XCTAssertNotNil(weekend)
        XCTAssertEqual(weekend, weekendForNilLocale)
    }
    
    @available(FoundationPreview 0.4, *)
    func test_datesAdding_range() {
        let startDate = Date(timeIntervalSinceReferenceDate: 689292158.712307) // 2022-11-04 22:02:38 UTC
        let endDate = startDate + (86400 * 3) + (3600 * 2) // 3 days + 2 hours later - cross a DST boundary which adds a day with an additional hour in it
        var cal = Calendar(identifier: .gregorian)
        let tz = TimeZone(name: "America/Los_Angeles")!
        cal.timeZone = tz
        
        // Purpose of this test is not to test the addition itself (we have others for that), but to smoke test the wrapping API
        let numberOfDays = Array(cal.dates(byAdding: .day, startingAt: startDate, in: startDate..<endDate)).count
        XCTAssertEqual(numberOfDays, 3)
    }
    
    @available(FoundationPreview 0.4, *)
    func test_datesAdding_year() {
        // Verify that adding 12 months once is the same as adding 1 month 12 times
        let startDate = Date(timeIntervalSinceReferenceDate: 688946558.712307) // 2022-10-31 22:02:38 UTC
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.gmt
        
        let oneYearOnce = cal.date(byAdding: .month, value: 12, to: startDate)
        let oneYearTwelve = Array(cal.dates(byAdding: .month, value: 1, startingAt: startDate).prefix(12)).last!
        
        XCTAssertEqual(oneYearOnce, oneYearTwelve)
    }
    
    @available(FoundationPreview 0.4, *)
    func test_datesMatching_simpleExample() {
        let cal = Calendar(identifier: .gregorian)
        // August 22, 2022 at 3:02:38 PM PDT
        let date = Date(timeIntervalSinceReferenceDate: 682898558.712307)
        let next3Minutes = [
            Date(timeIntervalSinceReferenceDate: 682898580.0),
            Date(timeIntervalSinceReferenceDate: 682898640.0),
            Date(timeIntervalSinceReferenceDate: 682898700.0),
        ]

        let dates = cal.dates(byMatching: DateComponents(second: 0), startingAt: date, matchingPolicy: .nextTime)

        let result = zip(next3Minutes, dates)
        for i in result {
            XCTAssertEqual(i.0, i.1)
        }
    }

    @available(FoundationPreview 0.4, *)
    func test_datesMatching() {
        let startDate = Date(timeIntervalSinceReferenceDate: 682898558.712307) // 2022-08-22 22:02:38 UTC
        let endDate = startDate + (86400 * 3)
        var cal = Calendar(identifier: .gregorian)
        let tz = TimeZone.gmt
        cal.timeZone = tz

        var dc = DateComponents()
        dc.hour = 22

        // There should be 3 "hour 23"s in this range.
        let numberOfMatchesForward = Array(cal.dates(byMatching: dc, startingAt: startDate, in: startDate..<endDate)).count
        XCTAssertEqual(numberOfMatchesForward, 3)
        
        let numberOfMatchesBackward = Array(cal.dates(byMatching: dc, startingAt: endDate, in: startDate..<endDate, direction: .backward)).count
        XCTAssertEqual(numberOfMatchesBackward, 3)
        
        let unboundedForward = Array(cal.dates(byMatching: dc, startingAt: startDate).prefix(10))
        XCTAssertEqual(unboundedForward.count, 10)
        
        // sanity check of results
        XCTAssertTrue(unboundedForward.first! < unboundedForward.last!)
        
        let unboundedBackward = Array(cal.dates(byMatching: dc, startingAt: startDate, direction: .backward).prefix(10))
        XCTAssertEqual(unboundedForward.count, 10)
        
        // sanity check of results
        XCTAssertTrue(unboundedBackward.first! > unboundedBackward.last!)
    }
    
    @available(FoundationPreview 0.4, *)
    func test_dayOfYear_bounds() {
        let date = Date(timeIntervalSinceReferenceDate: 682898558.712307) // 2022-08-22 22:02:38 UTC, day 234
        var cal = Calendar(identifier: .gregorian)
        let tz = TimeZone.gmt
        cal.timeZone = tz
        
        // Test some invalid day of years
        var dayOfYearComps = DateComponents()
        dayOfYearComps.dayOfYear = 0
        let zeroDay = cal.nextDate(after: date, matching: dayOfYearComps, matchingPolicy: .previousTimePreservingSmallerComponents)
        XCTAssertNil(zeroDay)
        
        dayOfYearComps.dayOfYear = 400
        let futureDay = cal.nextDate(after: date, matching: dayOfYearComps, matchingPolicy: .nextTime)
        XCTAssertNil(futureDay)
        
        // Test subtraction over a year boundary
        dayOfYearComps.dayOfYear = 1
        let firstDay = cal.nextDate(after: date, matching: dayOfYearComps, matchingPolicy: .nextTime, direction: .backward)
        XCTAssertNotNil(firstDay)
        let firstDayComps = cal.dateComponents([.year], from: firstDay!)
        let expectationComps = DateComponents(year: 2022)
        XCTAssertEqual(firstDayComps, expectationComps)
        
        var subtractMe = DateComponents()
        subtractMe.dayOfYear = -1
        let previousDay = cal.date(byAdding: subtractMe, to: firstDay!)
        XCTAssertNotNil(previousDay)
        let previousDayComps = cal.dateComponents([.year, .dayOfYear], from: previousDay!)
        var previousDayExpectationComps = DateComponents()
        previousDayExpectationComps.year = 2021
        previousDayExpectationComps.dayOfYear = 365
        XCTAssertEqual(previousDayComps, previousDayExpectationComps)
    }
    
    @available(FoundationPreview 0.4, *)
    func test_dayOfYear() {
        // An arbitrary date, for which we know the answers
        let date = Date(timeIntervalSinceReferenceDate: 682898558.712307) // 2022-08-22 22:02:38 UTC, day 234
        let leapYearDate = Date(timeIntervalSinceReferenceDate: 745891200) // 2024-08-21 00:00:00 UTC, day 234
        var cal = Calendar(identifier: .gregorian)
        let tz = TimeZone.gmt
        cal.timeZone = tz
        
        // Ordinality
        XCTAssertEqual(cal.ordinality(of: .dayOfYear, in: .year, for: date), 234)
        XCTAssertEqual(cal.ordinality(of: .hour, in: .dayOfYear, for: date), 23)
        XCTAssertEqual(cal.ordinality(of: .minute, in: .dayOfYear, for: date), 1323)
        XCTAssertEqual(cal.ordinality(of: .second, in: .dayOfYear, for: date), 79359)

        // Nonsense ordinalities. Since day of year is already relative, we don't count the Nth day of year in an era.
        XCTAssertEqual(cal.ordinality(of: .dayOfYear, in: .era, for: date), nil)
        XCTAssertEqual(cal.ordinality(of: .year, in: .dayOfYear, for: date), nil)

        // Interval
        let interval = cal.dateInterval(of: .dayOfYear, for: date)
        XCTAssertEqual(interval, DateInterval(start: Date(timeIntervalSinceReferenceDate: 682819200), duration: 86400))
        
        // Specific component values
        XCTAssertEqual(cal.dateComponents(in: .gmt, from: date).dayOfYear, 234)
        XCTAssertEqual(cal.component(.dayOfYear, from: date), 234)
        
        // Enumeration
        let beforeDate = date - (86400 * 3)
        let afterDate = date + (86400 * 3)
        let startOfDate = cal.startOfDay(for: date)
        
        var matchingComps = DateComponents(); matchingComps.dayOfYear = 234
        var foundDate = cal.nextDate(after: beforeDate, matching: matchingComps, matchingPolicy: .nextTime)
        XCTAssertEqual(foundDate, startOfDate)
        
        foundDate = cal.nextDate(after: afterDate, matching: matchingComps, matchingPolicy: .nextTime, direction: .backward)
        XCTAssertEqual(foundDate, startOfDate)
        
        // Go over a leap year
        let nextFive = Array(cal.dates(byMatching: matchingComps, startingAt: beforeDate).prefix(5))
        let expected = [
            Date(timeIntervalSinceReferenceDate: 682819200), // 2022-08-22 00:00:00 +0000
            Date(timeIntervalSinceReferenceDate: 714355200), // 2023-08-22 00:00:00 +0000
            Date(timeIntervalSinceReferenceDate: 745891200), // 2024-08-21 00:00:00 +0000
            Date(timeIntervalSinceReferenceDate: 777513600), // 2025-08-22 00:00:00 +0000
            Date(timeIntervalSinceReferenceDate: 809049600), // 2026-08-22 00:00:00 +0000
        ]
        XCTAssertEqual(nextFive, expected)
        
        // Ranges
        let min = cal.minimumRange(of: .dayOfYear)
        let max = cal.maximumRange(of: .dayOfYear)
        XCTAssertEqual(min, 1..<366) // hard coded for gregorian
        XCTAssertEqual(max, 1..<367)
        
        XCTAssertEqual(cal.range(of: .dayOfYear, in: .year, for: date), 1..<366)
        XCTAssertEqual(cal.range(of: .dayOfYear, in: .year, for: leapYearDate), 1..<367)
        
        // Addition
        let d1 = cal.date(byAdding: .dayOfYear, value: 1, to: date)
        XCTAssertEqual(d1, date + 86400)
        
        // Using setting to go to Jan 1
        let jan1 = cal.date(bySetting: .dayOfYear, value: 1, of: date)!
        let jan1Comps = cal.dateComponents([.year, .month, .day], from: jan1)
        XCTAssertEqual(jan1Comps.year, 2023)
        XCTAssertEqual(jan1Comps.day, 1)
        XCTAssertEqual(jan1Comps.month, 1)
        
        // Using setting to go to Jan 1
        let whatDay = cal.date(bySetting: .dayOfYear, value: 100, of: Date.now)!
        let _ = cal.component(.weekday, from: whatDay)
        let _ = Calendar.current.component(.weekday, from: Date.now - (86400 * 5))

        
        // Comparison
        XCTAssertEqual(cal.compare(date, to: beforeDate, toGranularity: .dayOfYear), .orderedDescending)
        XCTAssertEqual(cal.compare(date, to: afterDate, toGranularity: .dayOfYear), .orderedAscending)
        XCTAssertEqual(cal.compare(date + 10, to: date, toGranularity: .dayOfYear), .orderedSame)
        
        // Nonsense day-of-year
        var nonsenseDayOfYear = DateComponents()
        nonsenseDayOfYear.dayOfYear = 500
        let shouldBeEmpty = Array(cal.dates(byMatching: nonsenseDayOfYear, startingAt: beforeDate))
        XCTAssertTrue(shouldBeEmpty.isEmpty)
    }

    func test_dateComponentsFromFarDateCrash() {
        // Calling dateComponents(:from:) on a remote date should not crash
        let c = Calendar(identifier: .gregorian)
        _ = c.dateComponents([.month], from: Date(timeIntervalSinceReferenceDate: 7.968993439840418e+23))
    }

    func test_dateBySettingDay() {
        func firstDayOfMonth(_ calendar: Calendar, for date: Date) -> Date? {
            var startOfCurrentMonthComponents = calendar.dateComponents(in: calendar.timeZone, from: date)
            startOfCurrentMonthComponents.day = 1

            return calendar.date(from: startOfCurrentMonthComponents)
        }

        var iso8601calendar = Calendar(identifier: .iso8601)
        iso8601calendar.timeZone = .gmt

        var gregorianCalendar = Calendar(identifier: .gregorian)
        gregorianCalendar.timeZone = .gmt

        let date = Date(timeIntervalSince1970: 1609459199) // 2020-12-31T23:59:59Z
        XCTAssertEqual(firstDayOfMonth(iso8601calendar, for: date), Date(timeIntervalSinceReferenceDate: 628559999.0)) // 2020-12-01T23:59:59Z
        XCTAssertEqual(firstDayOfMonth(gregorianCalendar, for: date), Date(timeIntervalSinceReferenceDate: 628559999.0)) // 2020-12-01T23:59:59Z

        let date2 = Date(timeIntervalSinceReferenceDate: 730860719) // 2024-02-29T00:51:59Z
        XCTAssertEqual(firstDayOfMonth(iso8601calendar, for: date2), Date(timeIntervalSinceReferenceDate: 728441519)) // 2024-02-01T00:51:59Z
        XCTAssertEqual(firstDayOfMonth(gregorianCalendar, for: date2), Date(timeIntervalSinceReferenceDate: 728441519.0)) // 2024-02-01T00:51:59Z
    }

    func test_firstWeekday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        XCTAssertEqual(calendar.firstWeekday, 1)

        calendar.locale = Locale(identifier: "en_GB")
        XCTAssertEqual(calendar.firstWeekday, 2)

        var calendarWithCustomLocale = Calendar(identifier: .gregorian)
        calendarWithCustomLocale.locale = Locale(identifier: "en_US", preferences: .init(firstWeekday: [.gregorian: 3]))
        XCTAssertEqual(calendarWithCustomLocale.firstWeekday, 3)

        calendarWithCustomLocale.firstWeekday = 5
        XCTAssertEqual(calendarWithCustomLocale.firstWeekday, 5) // Returns the one set directly on Calendar

        var calendarWithCustomLocaleAndCustomWeekday = Calendar(identifier: .gregorian)
        calendarWithCustomLocaleAndCustomWeekday.firstWeekday = 2
        calendarWithCustomLocaleAndCustomWeekday.locale = Locale(identifier: "en_US", preferences: .init(firstWeekday: [.gregorian: 3]))
        XCTAssertEqual(calendarWithCustomLocaleAndCustomWeekday.firstWeekday, 2) // Returns the one set directly on Calendar even if `.locale` is set later
    }

    func test_minDaysInFirstWeek() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_GB")
        XCTAssertEqual(calendar.minimumDaysInFirstWeek, 4)

        calendar.minimumDaysInFirstWeek = 5
        XCTAssertEqual(calendar.minimumDaysInFirstWeek, 5)

        var calendarWithCustomLocale = Calendar(identifier: .gregorian)
        calendarWithCustomLocale.locale = Locale(identifier: "en_US", preferences: .init(minDaysInFirstWeek: [.gregorian: 6]))
        XCTAssertEqual(calendarWithCustomLocale.minimumDaysInFirstWeek, 6)

        var calendarWithCustomLocaleAndCustomMinDays = Calendar(identifier: .gregorian)
        calendarWithCustomLocaleAndCustomMinDays.minimumDaysInFirstWeek = 2
        calendarWithCustomLocaleAndCustomMinDays.locale = Locale(identifier: "en_US", preferences: .init(minDaysInFirstWeek: [.gregorian: 6]))
        XCTAssertEqual(calendarWithCustomLocaleAndCustomMinDays.minimumDaysInFirstWeek, 2)

    }

    func test_addingZeroComponents() {
        var calendar = Calendar(identifier: .gregorian)
        let timeZone = TimeZone(identifier: "America/Los_Angeles")!
        calendar.timeZone = timeZone

        // 2021-11-07 08:30:00 GMT, which is 2021-11-07 01:30:00 PDT. Daylight saving time ends 30 minutes after this.
        let date = Date(timeIntervalSinceReferenceDate: 657966600)
        let dateComponents = DateComponents(era: 0, year: 0, month: 0, day: 0, hour: 0, minute: 0, second: 0)
        let result = calendar.date(byAdding: dateComponents, to: date)
        XCTAssertEqual(date, result)

        let allComponents : [Calendar.Component] = [.era, .year, .month, .day, .hour, .minute, .second]
        for component in allComponents {
            let res = calendar.date(byAdding: component, value: 0, to: date)
            XCTAssertEqual(res, date, "component: \(component)")
        }
    }
    
}

// MARK: - Bridging Tests
#if FOUNDATION_FRAMEWORK
final class CalendarBridgingTests : XCTestCase {
    func test_AnyHashableCreatedFromNSCalendar() {
        let values: [NSCalendar] = [
            NSCalendar(identifier: .gregorian)!,
            NSCalendar(identifier: .japanese)!,
            NSCalendar(identifier: .japanese)!,
        ]
        let anyHashables = values.map(AnyHashable.init)
        expectEqual(Calendar.self, type(of: anyHashables[0].base))
        expectEqual(Calendar.self, type(of: anyHashables[1].base))
        expectEqual(Calendar.self, type(of: anyHashables[2].base))
        XCTAssertNotEqual(anyHashables[0], anyHashables[1])
        XCTAssertEqual(anyHashables[1], anyHashables[2])
    }
}
#endif


// This test validates the results against FoundationInternationalization's calendar implementation temporarily until we completely ported the calendar
final class GregorianCalendarCompatibilityTests: XCTestCase {

    func testDateFromComponentsCompatibility() {
        let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: .gmt, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: .gmt, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)

        func test(_ dateComponents: DateComponents, file: StaticString = #file, line: UInt = #line) {
            let date_new = gregorianCalendar.date(from: dateComponents)!
            let date_old = icuCalendar.date(from: dateComponents)!
            expectEqual(date_new, date_old)
        }

        test(.init(year: 1996, month: 3))
        test(.init(year: 1996, month: 3, day: 1))
        test(.init(year: 1996, month: 3, day: 1, hour: 1))
        test(.init(year: 1996, month: 3, day: 1, hour: 1, minute: 30))

        test(.init(year: 1996, month: 3, day: 1, hour: 1, minute: 30, second: 49))
        test(.init(year: 1996, month: 3, day: 1, hour: 1, minute: 30, second: 49, nanosecond: 1234567))

        // weekday
        test(.init(year: 1996, month: 3, weekday: 3))
        test(.init(year: 1996, month: 3, weekday: 3, weekdayOrdinal: 2))

        // week of month
        test(.init(year: 1996, month: 3, weekOfMonth: 2))
        test(.init(year: 1996, month: 3, weekday: 3, weekOfMonth: 2))
        test(.init(year: 1996, month: 3, day: 1, weekOfMonth: 2))

        // overflow
        test(.init(year: 1996, month: 1, day: 1, hour: 25))

        // Gregorian cut off
        test(.init(year: 1582, month: 10, day: 14, hour: 23, minute: 59, second: 59))
        test(.init(year: 1582, month: 10, day: 15, hour: 0))
        test(.init(year: 1582, month: 10, day: 15, hour: 12))

        // no year -- default to year 1 --> needed to use Julian
        test(.init())
        test(.init(month: 1, day: 1))
        test(.init(month: 1, day: 1, hour: 1))
    }


    func testDateFromComponentsCompatibilityCustom() {

        self.continueAfterFailure = false
        func test(_ dateComponents: DateComponents, icuCalendar: _CalendarICU, gregorianCalendar: _CalendarGregorian, file: StaticString = #file, line: UInt = #line) {
            let date_new = gregorianCalendar.date(from: dateComponents)!
            let date_old = icuCalendar.date(from: dateComponents)!
            expectEqual(date_new, date_old, "dateComponents: \(dateComponents), first weekday: \(gregorianCalendar.firstWeekday), minimumDaysInFirstWeek: \(gregorianCalendar.minimumDaysInFirstWeek)")
        }

        // first weekday, min days in first week
        do {
            for weekday in [0, 1, 4, 8] {
                for daysInFirstWeek in [0, 1, 4, 8] {
                    let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: .gmt, locale: nil, firstWeekday: weekday, minimumDaysInFirstWeek: daysInFirstWeek, gregorianStartDate: nil)
                    let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: .gmt, locale: nil, firstWeekday: weekday, minimumDaysInFirstWeek: daysInFirstWeek, gregorianStartDate: nil)

                    for y in stride(from: 1582, to: 3000, by: 48) {
                        for m in stride(from: -30, to: 30, by: 4) {
                            for d in stride(from: -10, to: 10, by: 3) {
                                for wd in stride(from: -10, to: 30, by: 5) {
                                    test(.init(year: y, month: m, weekday: d, weekdayOrdinal: wd), icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)
                                }
                            }

                            for d in stride(from: -30, to: 30, by: 5) {
                                test(.init(year: y, month: m, day: d), icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)
                            }

                            for w in stride(from: -8, to: 8, by: 3) {
                                test(.init(year: y, month: m, weekOfMonth: w), icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)
                            }
                        }

                        for wy in stride(from: 0, to: 60, by: 3) {
                            test(.init(weekOfYear: wy, yearForWeekOfYear: y), icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)
                        }
                    }
                }
            }
        }

        // time zone
        do {
            let tz = TimeZone(secondsFromGMT: 23400)! // UTC+0630
            let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: tz, locale: nil, firstWeekday: 1, minimumDaysInFirstWeek: 4, gregorianStartDate: nil)
            let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: tz, locale: nil, firstWeekday: 1, minimumDaysInFirstWeek: 4, gregorianStartDate: nil)
            for m in [-13, -12, -10, -1, 0, 1, 2, 12, 13] {
                for d in [-31, -30, -29, -1, 0, 1, 29, 30, 31] {
                    for h in [-25, -24, -1, 0, 1, 23, 24, 25] {
                        for mm in stride(from: -120, to: 121, by: 7) {
                            for ss in stride(from: -120, to: 121, by: 7) {
                                test(.init(year: 1996, month: m, day: d, hour: h, minute: mm, second: ss), icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)
                                test(.init(year: 1997, month: m, day: d, hour: h, minute: mm, second: ss), icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)
                                test(.init(year: 2000, month: m, day: d, hour: h, minute: mm, second: ss), icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)
                            }
                        }
                    }
                }
            }
        }
    }

    func testDateFromComponentsCompatibility_DaylightSavingTimeZone() {

        let tz = TimeZone(identifier: "America/Los_Angeles")!
        let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: tz, locale: nil, firstWeekday: 1, minimumDaysInFirstWeek: 4, gregorianStartDate: nil)
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: tz, locale: nil, firstWeekday: 1, minimumDaysInFirstWeek: 4, gregorianStartDate: nil)

        func test(_ dateComponents: DateComponents, file: StaticString = #file, line: UInt = #line) {
            let date_new = gregorianCalendar.date(from: dateComponents)!
            let date_old = icuCalendar.date(from: dateComponents)!
            expectEqual(date_new, date_old, "dateComponents: \(dateComponents)")
            let roundtrip_new = gregorianCalendar.dateComponents([.hour], from: date_new)
            let roundtrip_old = icuCalendar.dateComponents([.hour], from: date_new)
            XCTAssertEqual(roundtrip_new.hour, roundtrip_old.hour, "dateComponents: \(dateComponents)")
        }

         // In daylight saving time
        test(.init(year: 2023, month: 10, day: 16))
        test(.init(year: 2023, month: 10, day: 16, hour: 1, minute: 34, second: 52))
        
        // Not in daylight saving time
        test(.init(year: 2023, month: 11, day: 6))

        // Before daylight saving time starts
        test(.init(year: 2023, month: 3, day: 12))
        test(.init(year: 2023, month: 3, day: 12, hour: 1, minute: 34, second: 52))
        test(.init(year: 2023, month: 3, day: 12, hour: 2, minute: 34, second: 52)) // this time does not exist

        // After daylight saving time starts
        test(.init(year: 2023, month: 3, day: 12, hour: 3, minute: 34, second: 52))
        test(.init(year: 2023, month: 3, day: 13, hour: 00))

        // Before daylight saving time ends
        test(.init(year: 2023, month: 11, day: 5))
        test(.init(year: 2023, month: 11, day: 5, hour: 1, minute: 34, second: 52)) // this time happens twice

        // After daylight saving time ends
        test(.init(year: 2023, month: 11, day: 5, hour: 2, minute: 34, second: 52))
        test(.init(year: 2023, month: 11, day: 5, hour: 3, minute: 34, second: 52))
    }

    func testDateFromComponents_componentsTimeZone() {
        let timeZone = TimeZone.gmt
        let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)


        func test(_ dateComponents: DateComponents, file: StaticString = #file, line: UInt = #line) {
            let date_new = gregorianCalendar.date(from: dateComponents)!
            let date_old = icuCalendar.date(from: dateComponents)!
            expectEqual(date_new, date_old, "dateComponents: \(dateComponents)")
        }

        let dcCalendar = Calendar(identifier: .japanese, locale: Locale(identifier: ""), timeZone: .init(secondsFromGMT: -25200), firstWeekday: 1, minimumDaysInFirstWeek: 1, gregorianStartDate: nil)
        let dc = DateComponents(calendar: nil, timeZone: nil, era: 1, year: 2022, month: 7, day: 9, hour: 10, minute: 2, second: 55, nanosecond: 891000032, weekday: 7, weekdayOrdinal: 2, quarter: 0, weekOfMonth: 2, weekOfYear: 28, yearForWeekOfYear: 2022)
        var dc_customCalendarAndTimeZone = dc
        dc_customCalendarAndTimeZone.calendar = dcCalendar
        dc_customCalendarAndTimeZone.timeZone = .init(secondsFromGMT: 28800)
        test(dc_customCalendarAndTimeZone) // calendar.timeZone = .gmt, dc.calendar.timeZone = UTC-7, dc.timeZone = UTC+8

        var dc_customCalendar = dc
        dc_customCalendar.calendar = dcCalendar
        dc_customCalendar.timeZone = nil
        test(dc_customCalendar) // calendar.timeZone = .gmt, dc.calendar.timeZone = UTC-7, dc.timeZone = nil

        var dc_customTimeZone = dc_customCalendarAndTimeZone
        dc_customTimeZone.calendar = nil
        dc_customTimeZone.timeZone = .init(secondsFromGMT: 28800)
        test(dc_customTimeZone) // calendar.timeZone = .gmt, dc.calendar = nil, dc.timeZone = UTC+8

        let dcCalendar_noTimeZone = Calendar(identifier: .japanese, locale: Locale(identifier: ""), timeZone: nil, firstWeekday: 1, minimumDaysInFirstWeek: 1, gregorianStartDate: nil)
        var dc_customCalendarNoTimeZone_customTimeZone = dc
        dc_customCalendarNoTimeZone_customTimeZone.calendar = dcCalendar_noTimeZone
        dc_customCalendarNoTimeZone_customTimeZone.timeZone = .init(secondsFromGMT: 28800)
        test(dc_customCalendarNoTimeZone_customTimeZone) // calendar.timeZone = .gmt, dc.calendar.timeZone = nil, dc.timeZone = UTC+8
    }

    func testDateFromComponentsCompatibility_RemoveDates() {

        let tz = TimeZone(identifier: "America/Los_Angeles")!
        let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: tz, locale: nil, firstWeekday: 1, minimumDaysInFirstWeek: 1, gregorianStartDate: nil)
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: tz, locale: nil, firstWeekday: 1, minimumDaysInFirstWeek: 1, gregorianStartDate: nil)

        func test(_ dateComponents: DateComponents, file: StaticString = #file, line: UInt = #line) {
            let date_new = gregorianCalendar.date(from: dateComponents)!
            let date_old = icuCalendar.date(from: dateComponents)!
            expectEqual(date_new, date_old, "dateComponents: \(dateComponents)")
            let roundtrip_new = gregorianCalendar.dateComponents([.hour], from: date_new)
            let roundtrip_old = icuCalendar.dateComponents([.hour], from: date_new)
            XCTAssertEqual(roundtrip_new.hour, roundtrip_old.hour, "dateComponents: \(dateComponents)")
        }

        test(.init(year: 4713, month: 1, day: 1, hour: 0, minute: 0, second: 0, nanosecond: 0, weekday: 2))
        test(.init(year: 4713, month: 1, day: 1, hour: 0, minute: 0, second: 0, nanosecond: 0))
    }

    func testDateComponentsFromDateCompatibility() {
        let componentSet = Calendar.ComponentSet([.era, .year, .month, .day, .hour, .minute, .second, .nanosecond, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .calendar])

        let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: nil, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: nil, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)

        func test(_ date: Date, icuCalendar: _CalendarICU, gregorianCalendar: _CalendarGregorian, timeZone: TimeZone = .gmt, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
            let gregResult = gregorianCalendar.dateComponents(componentSet, from: date, in: timeZone)
            let icuResult = icuCalendar.dateComponents(componentSet, from: date, in: timeZone)
            // The original implementation does not set quarter
            expectEqual(gregResult, icuResult, expectQuarter: false, expectCalendar: false, message().appending("\ndate: \(date.timeIntervalSinceReferenceDate), \(date.formatted(.iso8601))\nnew:\n\(gregResult)\nold:\n\(icuResult)"), file: file, line: line)
        }

        self.continueAfterFailure = false
        let testStrides = stride(from: -864000, to: 864000, by: 100)
        let gmtPlusOne = TimeZone(secondsFromGMT: 3600)!

        for timeZoneOffset in stride(from: 0, to: 3600, by: 1800) {
            for ti in testStrides {
                let date = Date(timeIntervalSince1970: TimeInterval(ti))
                if let timeZone = TimeZone(secondsFromGMT: timeZoneOffset) {
                    test(date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, timeZone: timeZone)
                }
            }

        }

        // test near gregorian start date
        do {
            let ref = Date(timeIntervalSinceReferenceDate: -13197085200) // 1582-10-20 23:00:00 UTC

            for ti in testStrides {
                let date = Date(timeInterval: TimeInterval(ti), since: ref)
                test(date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, timeZone: gmtPlusOne)
            }
        }

        // test day light saving time
        do {
            let tz = TimeZone(identifier: "America/Los_Angeles")!
            XCTAssert(tz.nextDaylightSavingTimeTransition(after: Date(timeIntervalSinceReferenceDate: 0)) != nil)

            let intervalsAroundDSTTransition = [41418000.0, 41425200.0, 25689600.0, 73476000.0, 89197200.0, 57747600.0, 57744000.0, 9972000.0, 25693200.0, 9975600.0, 57751200.0, 25696800.0, 89193600.0, 41421600.0, 73479600.0, 89200800.0, 73472400.0, 9968400.0]
            for ti in intervalsAroundDSTTransition {
                let date = Date(timeIntervalSince1970: TimeInterval(ti))
                test(date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, timeZone: tz)
            }
        }

        // test first weekday
        do {
            for firstWeekday in [0, 1, 3, 10] {
                let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: nil, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
                let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: nil, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)

                for ti in testStrides {
                    let date = Date(timeIntervalSince1970: TimeInterval(ti))
                    test(date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, timeZone: gmtPlusOne, "firstweekday: \(firstWeekday)")
                    test(date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, timeZone: gmtPlusOne)
                    test(date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, timeZone: gmtPlusOne)
                    test(date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, timeZone: gmtPlusOne)
                    test(date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, timeZone: gmtPlusOne)
                    test(date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, timeZone: gmtPlusOne)
                }
            }
        }

        // test min days in first week
        do {
            for minDaysInFirstWeek in [0, 1, 3, 10] {
                let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: nil, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: minDaysInFirstWeek, gregorianStartDate: nil)
                let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: nil, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: minDaysInFirstWeek, gregorianStartDate: nil)
                for ti in testStrides {
                    let date = Date(timeIntervalSince1970: TimeInterval(ti))
                    test(date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, timeZone: gmtPlusOne)
                    test(date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, timeZone: gmtPlusOne)
                    test(date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, timeZone: gmtPlusOne)
                    test(date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, timeZone: gmtPlusOne)
                    test(date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, timeZone: gmtPlusOne)
                    test(date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, timeZone: gmtPlusOne)
                }
            }
        }
    }

    func testDateComponentsFromDateCompatibility_DST() {
        let componentSet = Calendar.ComponentSet([.era, .year, .month, .day, .hour, .minute, .second, .nanosecond, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .calendar])

        let tz = TimeZone(identifier: "America/Los_Angeles")!
        let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: tz, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: tz, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)

        func test(_ date: Date, icuCalendar: _CalendarICU, gregorianCalendar: _CalendarGregorian, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
            let gregResult = gregorianCalendar.dateComponents(componentSet, from: date, in: tz)
            let icuResult = icuCalendar.dateComponents(componentSet, from: date, in: tz)
            // The original implementation does not set quarter
            expectEqual(gregResult, icuResult, expectQuarter: false, expectCalendar: false, message().appending("\ndate: \(date.timeIntervalSinceReferenceDate), \(date.formatted(.iso8601))\nnew:\n\(gregResult)\nold:\n\(icuResult)"), file: file, line: line)
        }

        let testStrides = stride(from: -864000, to: 864000, by: 100)

        for ti in testStrides {
            let date = Date(timeIntervalSince1970: TimeInterval(ti))
                test(date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)
        }

        // test near gregorian start date
        do {
            let ref = Date(timeIntervalSinceReferenceDate: -13197085200) // 1582-10-20 23:00:00 UTC

            for ti in testStrides {
                let date = Date(timeInterval: TimeInterval(ti), since: ref)
                test(date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)
            }
        }

        // test day light saving time
        do {
            let intervalsAroundDSTTransition = [41418000.0, 41425200.0, 25689600.0, 73476000.0, 89197200.0, 57747600.0, 57744000.0, 9972000.0, 25693200.0, 9975600.0, 57751200.0, 25696800.0, 89193600.0, 41421600.0, 73479600.0, 89200800.0, 73472400.0, 9968400.0]
            for ti in intervalsAroundDSTTransition {
                let date = Date(timeIntervalSince1970: TimeInterval(ti))
                test(date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)
            }
        }

        // test first weekday
        do {
            for firstWeekday in [0, 1, 3, 10] {
                let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: tz, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
                let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: tz, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)

                for ti in testStrides {
                    let date = Date(timeIntervalSince1970: TimeInterval(ti))
                    test(date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, "firstweekday: \(firstWeekday)")
                    test(date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)
                    test(date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)
                    test(date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)
                    test(date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)
                    test(date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)
                }
            }
        }

        // test min days in first week
        do {
            for minDaysInFirstWeek in [0, 1, 3, 10] {
                let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: tz, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: minDaysInFirstWeek, gregorianStartDate: nil)
                let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: tz, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: minDaysInFirstWeek, gregorianStartDate: nil)
                for ti in testStrides {
                    let date = Date(timeIntervalSince1970: TimeInterval(ti))
                    test(date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)
                    test(date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)
                    test(date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)
                    test(date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)
                    test(date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)
                    test(date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)
                }
            }
        }
    }


    func testDateComponentsFromDate_distantDates() {

        let componentSet = Calendar.ComponentSet([.era, .year, .month, .day, .hour, .minute, .second, .nanosecond, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .calendar])
        func test(_ date: Date, icuCalendar: _CalendarICU, gregorianCalendar: _CalendarGregorian, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
            let gregResult = gregorianCalendar.dateComponents(componentSet, from: date, in: gregorianCalendar.timeZone)
            let icuResult = icuCalendar.dateComponents(componentSet, from: date, in: icuCalendar.timeZone)
            // The original implementation does not set quarter
            expectEqual(gregResult, icuResult, expectQuarter: false, expectCalendar: false, message().appending("\ndate: \(date.timeIntervalSince1970), \(date.formatted(Date.ISO8601FormatStyle(timeZone: gregorianCalendar.timeZone)))\nnew:\n\(gregResult)\nold:\n\(icuResult)\ndiff:\n\(DateComponents.differenceBetween(gregResult, icuResult, compareQuarter: false) ?? "nil")"), file: file, line: line)
        }

        do {
            let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: .gmt, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
            let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: .gmt, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
            test(.distantPast, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)
            test(.distantFuture, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)
            test(Date(timeIntervalSinceReferenceDate: -211845067200.0), icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)

        }

        do {
            let tz = TimeZone(identifier: "America/Los_Angeles")!
            let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: tz, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
            let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: tz, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
            test(.distantPast, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)
            test(.distantFuture, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)
            test(Date(timeIntervalSince1970: -210866774822).capped, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)
            test(Date(timeIntervalSinceReferenceDate: 3161919600), icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)

        }
    }


    func testDateComponentsFromDate() {
        let componentSet = Calendar.ComponentSet([.era, .year, .month, .day, .hour, .minute, .second, .nanosecond, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .calendar])
        func test(_ date: Date, icuCalendar: _CalendarICU, gregorianCalendar: _CalendarGregorian, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
            let gregResult = gregorianCalendar.dateComponents(componentSet, from: date, in: gregorianCalendar.timeZone)
            let icuResult = icuCalendar.dateComponents(componentSet, from: date, in: icuCalendar.timeZone)
            // The original implementation does not set quarter

            expectEqual(gregResult, icuResult, expectQuarter: false, expectCalendar: false, message().appending("\ndate: \(date.timeIntervalSince1970), \(date.formatted(Date.ISO8601FormatStyle(timeZone: gregorianCalendar.timeZone)))\nnew:\n\(gregResult)\nold:\n\(icuResult)\ndiff:\n\(DateComponents.differenceBetween(gregResult, icuResult, compareQuarter: false) ?? "")"), file: file, line: line)
        }

        do {
            let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: .gmt, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
            let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: .gmt, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
            // Properly `floor`ed, the value below is -1 second from reference date

            var date: Date

            date = Date(timeIntervalSinceReferenceDate: -1) // 2001-01-01 00:00:00 +0000
            test(date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)
            
            date = Date(timeIntervalSinceReferenceDate: -1.0012654182354326e-43) // 2001-01-01 00:00:00 +0000
            test(date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)
        }

    }
    // MARK: - adding
    func verifyAdding(_ components: DateComponents, to date: Date, icuCalendar: _CalendarICU, gregorianCalendar: _CalendarGregorian, wrap: Bool = false, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
        let added_icu = icuCalendar.date(byAdding: components, to: date, wrappingComponents: wrap)
        let added_greg = gregorianCalendar.date(byAdding: components, to: date, wrappingComponents: wrap)
        guard let added_icu, let added_greg else {
            XCTFail("\(message())", file: file, line: line)
            return
        }
        let tz = icuCalendar.timeZone
        assert(icuCalendar.timeZone == gregorianCalendar.timeZone)

        let dsc_greg = added_greg.formatted(Date.ISO8601FormatStyle(timeZone: tz))
        let dsc_icu = added_icu.formatted(Date.ISO8601FormatStyle(timeZone: tz))
        expectEqual(added_greg, added_icu, message().appending("components:\(components), greg: \(dsc_greg), icu: \(dsc_icu)"), file: file, line: line)
    }

    func testAddComponentsCompatibility_singleField() {

        self.continueAfterFailure = false
        func verify(_ date: Date, wrap: Bool, icuCalendar: _CalendarICU, gregorianCalendar: _CalendarGregorian, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
            for v in stride(from: -100, through: 100, by: 3) {
                verifyAdding(DateComponents(component: .era, value: v)!, to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: wrap, message(), file: file, line: line)
                verifyAdding(DateComponents(component: .year, value: v)!, to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: wrap, message(), file: file, line: line)
                verifyAdding(DateComponents(component: .month, value: v)!, to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: wrap, message(), file: file, line: line)
                verifyAdding(DateComponents(component: .day, value: v)!, to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: wrap, message(), file: file, line: line)
                verifyAdding(DateComponents(component: .hour, value: v)!, to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: wrap, message(), file: file, line: line)
                verifyAdding(DateComponents(component: .minute, value: v)!, to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: wrap, message(), file: file, line: line)
                verifyAdding(DateComponents(component: .second, value: v)!, to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: wrap, message(), file: file, line: line)
                verifyAdding(DateComponents(component: .weekday, value: v)!, to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: wrap, message(), file: file, line: line)
                verifyAdding(DateComponents(component: .weekdayOrdinal, value: v)!, to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: wrap, message(), file: file, line: line)
                verifyAdding(DateComponents(component: .weekOfYear, value: v)!, to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: wrap, message(), file: file, line: line)
                verifyAdding(DateComponents(component: .weekOfMonth, value: v)!, to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: wrap, message(), file: file, line: line)
                verifyAdding(DateComponents(component: .yearForWeekOfYear, value: v)!, to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: wrap, message(), file: file, line: line)
                verifyAdding(DateComponents(component: .nanosecond, value: v)!, to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: wrap, message(), file: file, line: line)
            }
        }

        let firstWeekday = 1
        let minimumDaysInFirstWeek = 1
        let timeZone = TimeZone.gmt
        let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: nil)
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: nil)

        // Wrap
        verify(Date(timeIntervalSince1970: 825638400), wrap: true, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)  // 1996 Mar 1, Fri 00:00
        verify(Date(timeIntervalSince1970: 825721200), wrap: true, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)  // 1996 Mar 1, Fri 23:00
        verify(Date(timeIntervalSince1970: 825723300), wrap: true, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)  // 1996 Mar 1, Fri 23:35
        verify(Date(timeIntervalSince1970: 825638400), wrap: true, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)  // 1996 Mar 5, Tue
        verify(Date(timeIntervalSince1970: 826588800), wrap: true, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)  // 1996 Mar 12, Tue

        // Dates close to Gregorian cutover
        verify(Date(timeIntervalSince1970: -12219638400), wrap: true, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar) // 1582 Oct 1
        verify(Date(timeIntervalSince1970: -12218515200), wrap: true, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar) // 1582 Oct 14
        verify(Date(timeIntervalSince1970: -12219292800), wrap: true, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar) // 1582 Oct 15
        verify(Date(timeIntervalSince1970: -12219206400), wrap: true, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar) // 1582 Oct 16
        verify(Date(timeIntervalSince1970: -62130067200), wrap: true, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar) // long time ago

        // No wrap
        verify(Date(timeIntervalSince1970: 825638400), wrap: false, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)  // 1996 Mar 1, Fri 00:00
        verify(Date(timeIntervalSince1970: 825721200), wrap: false, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)  // 1996 Mar 1, Fri 23:00
        verify(Date(timeIntervalSince1970: 825723300), wrap: false, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)  // 1996 Mar 1, Fri 23:35
        verify(Date(timeIntervalSince1970: 825638400), wrap: false, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)  // 1996 Mar 5, Tue
        verify(Date(timeIntervalSince1970: 826588800), wrap: false, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar)  // 1996 Mar 12, Tue

        // Dates close to Gregorian cutover
        verify(Date(timeIntervalSince1970: -12219638400), wrap: false, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar) // 1582 Oct 1
        verify(Date(timeIntervalSince1970: -12218515200), wrap: false, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar) // 1582 Oct 14
        verify(Date(timeIntervalSince1970: -12219292800), wrap: false, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar) // 1582 Oct 15
        verify(Date(timeIntervalSince1970: -12219206400), wrap: false, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar) // 1582 Oct 16
        verify(Date(timeIntervalSince1970: -62130067200), wrap: false, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar) // long time ago
    }

    func testAddComponentsCompatibility_singleField_custom() {

        self.continueAfterFailure = false
        func verify(_ date: Date, wrap: Bool, icuCalendar: _CalendarICU, gregorianCalendar: _CalendarGregorian, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
            for v in stride(from: -100, through: 100, by: 23) {
                verifyAdding(DateComponents(component: .era, value: v)!, to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: wrap, message(), file: file, line: line)
                verifyAdding(DateComponents(component: .year, value: v)!, to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: wrap, message(), file: file, line: line)
                verifyAdding(DateComponents(component: .month, value: v)!, to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: wrap, message(), file: file, line: line)
                verifyAdding(DateComponents(component: .day, value: v)!, to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: wrap, message(), file: file, line: line)
                verifyAdding(DateComponents(component: .hour, value: v)!, to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: wrap, message(), file: file, line: line)
                verifyAdding(DateComponents(component: .minute, value: v)!, to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: wrap, message(), file: file, line: line)
                verifyAdding(DateComponents(component: .second, value: v)!, to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: wrap, message(), file: file, line: line)
                verifyAdding(DateComponents(component: .weekday, value: v)!, to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: wrap, message(), file: file, line: line)
                verifyAdding(DateComponents(component: .weekdayOrdinal, value: v)!, to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: wrap, message(), file: file, line: line)
                verifyAdding(DateComponents(component: .weekOfYear, value: v)!, to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: wrap, message(), file: file, line: line)
                verifyAdding(DateComponents(component: .weekOfMonth, value: v)!, to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: wrap, message(), file: file, line: line)
                verifyAdding(DateComponents(component: .yearForWeekOfYear, value: v)!, to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: wrap, message(), file: file, line: line)
                verifyAdding(DateComponents(component: .nanosecond, value: v)!, to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: wrap, message(), file: file, line: line)
            }
        }

        for firstWeekday in [0, 1, 7] {
            for minimumDaysInFirstWeek in [0, 1, 4, 7] {
                for tzOffset in [ 3600, 7200] {
                    let timeZone = TimeZone(secondsFromGMT: tzOffset)!
                    let msg = "firstweekday: \(firstWeekday), minimumDaysInFirstWeek: \(minimumDaysInFirstWeek), timeZone: \(timeZone)"
                    let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: nil)
                    let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: nil)
                    // Wrap
                    verify(Date(timeIntervalSince1970: 825723300), wrap: true, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, msg)  // 1996 Mar 1, Fri 23:35
                    verify(Date(timeIntervalSince1970: 826588800), wrap: true, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, msg)  // 1996 Mar 12, Tue

                    // Dates close to Gregorian cutover
                    verify(Date(timeIntervalSince1970: -12219638400), wrap: true, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, msg) // 1582 Oct 1
                    verify(Date(timeIntervalSince1970: -12218515200), wrap: true, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, msg) // 1582 Oct 14
                    verify(Date(timeIntervalSince1970: -12219206400), wrap: true, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, msg) // 1582 Oct 16

                    // Far dates
                    // FIXME: This is failing
                    // verify(Date.distantPast, wrap: true, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, msg)
                    // verify(Date.distantFuture, wrap: true, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, msg)

                    // No Wrap
                    verify(Date(timeIntervalSince1970: 825723300), wrap: false, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, msg)  // 1996 Mar 1, Fri 23:35
                    verify(Date(timeIntervalSince1970: 826588800), wrap: false, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, msg)  // 1996 Mar 12, Tue

                    // Dates close to Gregorian cutover
                    verify(Date(timeIntervalSince1970: -12219638400), wrap: false, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, msg) // 1582 Oct 1
                    verify(Date(timeIntervalSince1970: -12218515200), wrap: false, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, msg) // 1582 Oct 14
                    verify(Date(timeIntervalSince1970: -12219206400), wrap: false, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, msg) // 1582 Oct 16

                    // Far dates
                    // verify(Date.distantPast, wrap: false, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, msg)
                    // verify(Date.distantFuture, wrap: false, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, msg)
                }
            }
        }
    }

    func testAddComponentsCompatibility() {
        let firstWeekday = 2
        let minimumDaysInFirstWeek = 4
        let timeZone = TimeZone(secondsFromGMT: -3600 * 8)!
        let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: nil)
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: nil)

        let march1_1996 = Date(timeIntervalSince1970: 825723300) // 1996 Mar 1, Fri 23:35

        verifyAdding(.init(day: -1, hour: 1),   to: march1_1996, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)
        verifyAdding(.init(month: -1, hour: 1), to: march1_1996, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)
        verifyAdding(.init(month: -1, day: 30), to: march1_1996, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)
        verifyAdding(.init(year: 4, day: -1),   to: march1_1996, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)
        verifyAdding(.init(day: -1, hour: 24),  to: march1_1996, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)
        verifyAdding(.init(day: -1, weekday: 1),                     to: march1_1996, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)
        verifyAdding(.init(day: -7, weekOfYear: 1),                  to: march1_1996, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)
        verifyAdding(.init(day: -7, weekOfMonth: 1),                 to: march1_1996, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)
        verifyAdding(.init(day: -7, weekOfMonth: 1, weekOfYear: 1),  to: march1_1996, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)

        verifyAdding(.init(day: -1, hour: 1),   to: march1_1996, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
        verifyAdding(.init(month: -1, hour: 1), to: march1_1996, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
        verifyAdding(.init(month: -1, day: 30), to: march1_1996, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
        verifyAdding(.init(year: 4, day: -1),   to: march1_1996, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
        verifyAdding(.init(day: -1, hour: 24),  to: march1_1996, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
        verifyAdding(.init(day: -1, weekday: 1),                     to: march1_1996, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
        verifyAdding(.init(day: -7, weekOfYear: 1),                  to: march1_1996, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
        verifyAdding(.init(day: -7, weekOfMonth: 1),                 to: march1_1996, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
        verifyAdding(.init(day: -7, weekOfMonth: 1, weekOfYear: 1),  to: march1_1996, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
    }

    func testAddComponentsCompatibility_DST() {


        let firstWeekday = 3
        let minimumDaysInFirstWeek = 5
        let timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: nil)
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: nil)

        var date = Date(timeIntervalSince1970: 846403387.0) // 1996-10-27T01:03:07-0700

        verifyAdding(.init(day: -1, hour: 1),   to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)
        verifyAdding(.init(month: -1, hour: 1), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)
        verifyAdding(.init(month: -1, day: 30), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)
        verifyAdding(.init(year: 4, day: -1),   to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)
        verifyAdding(.init(day: -1, hour: 24),  to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)
        verifyAdding(.init(day: -1, weekday: 1),                     to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)
        verifyAdding(.init(day: -7, weekOfYear: 1),                  to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)
        verifyAdding(.init(day: -7, weekOfMonth: 1),                 to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)
        verifyAdding(.init(day: -7, weekOfMonth: 1, weekOfYear: 1),  to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)
        verifyAdding(.init(hour: 1, yearForWeekOfYear: 1),  to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)
        verifyAdding(.init(hour: -1, yearForWeekOfYear: 1),  to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)
        verifyAdding(.init(hour: 1, yearForWeekOfYear: -1),  to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)
        verifyAdding(.init(hour: -1, yearForWeekOfYear: -1),  to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)
        verifyAdding(.init(year: -1, day: 2), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false) // result is also DST transition day
        verifyAdding(.init(weekOfMonth: 1), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)
        verifyAdding(.init(weekOfYear: 1), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)
        verifyAdding(.init(month: 1), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)
        verifyAdding(.init(month: -12, day: 2), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)

        verifyAdding(.init(day: -1, hour: 1),   to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
        verifyAdding(.init(month: -1, hour: 1), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
        verifyAdding(.init(month: -1, day: 30), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
        verifyAdding(.init(year: 4, day: -1),   to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
        verifyAdding(.init(year: -1, day: 2), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true) // result is also DST transition day
        verifyAdding(.init(day: -1, hour: 24),  to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
        verifyAdding(.init(day: -1, weekday: 1),                     to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
        verifyAdding(.init(day: -7, weekOfYear: 1),                  to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
        verifyAdding(.init(day: -7, weekOfMonth: 1),                 to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
        verifyAdding(.init(day: -7, weekOfMonth: 1, weekOfYear: 1),  to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
        verifyAdding(.init(hour: 1, yearForWeekOfYear: 1),  to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
        verifyAdding(.init(hour: -1, yearForWeekOfYear: 1),  to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
        verifyAdding(.init(hour: 1, yearForWeekOfYear: -1),  to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
        verifyAdding(.init(hour: -1, yearForWeekOfYear: -1),  to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
        verifyAdding(.init(weekOfMonth: 1), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
        verifyAdding(.init(weekOfYear: 1), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
        verifyAdding(.init(month: 1), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
        verifyAdding(.init(month: -12, day: 2), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true) // Also DST

        date = Date(timeIntervalSince1970: 814953787.0) // 1995-10-29T01:03:07-0700
        verifyAdding(.init(year: 1, day: -2), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false) // result is also DST transition day
        verifyAdding(.init(hour: 1, yearForWeekOfYear: 1),  to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)
        verifyAdding(.init(hour: -1, yearForWeekOfYear: 1),  to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)
        verifyAdding(.init(weekOfYear: 43),  to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)
        verifyAdding(.init(month: 12, day: -2), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false) // Also DST

        verifyAdding(.init(year: 1, day: -2), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true) // result is also DST transition day
        verifyAdding(.init(hour: 1, yearForWeekOfYear: 1),  to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
        verifyAdding(.init(hour: -1, yearForWeekOfYear: 1),  to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
        verifyAdding(.init(weekOfYear: 43),  to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
        verifyAdding(.init(month: 12, day: -2), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true) // Also DST

        date = Date(timeIntervalSince1970: 846406987.0) // 1996-10-27T01:03:07-0800
        verifyAdding(.init(year: -1, day: 2), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false) // result is also DST transition day
        verifyAdding(.init(weekOfMonth: 1), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)
        verifyAdding(.init(weekOfYear: 1), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)
        verifyAdding(.init(month: 1), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)
        verifyAdding(.init(month: 12, day: -2), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false) // Also DST

        verifyAdding(.init(year: -1, day: 2), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true) // result is also DST transition day
        verifyAdding(.init(weekOfMonth: 1), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
        verifyAdding(.init(weekOfYear: 1), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
        verifyAdding(.init(month: 1), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
        verifyAdding(.init(month: 12, day: -2), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true) // Also DST
    }

    func testAddComponents() {
        let firstWeekday = 1
        let minimumDaysInFirstWeek = 1
        let timeZone = TimeZone(identifier: "America/Edmonton")!
        let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: nil)
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: nil)

        var date = Date(timeIntervalSinceReferenceDate:  -2976971168) // Some remote dates
        verifyAdding(.init(weekday: -1), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)

        date = Date(timeIntervalSinceReferenceDate: -2977057568.0)
        verifyAdding(.init(day: 1), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: false)
    }

    func testAddComponentsWrap() {
        let timeZone = TimeZone(identifier: "Europe/Rome")!
        let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)

        let date = Date(timeIntervalSinceReferenceDate:  -702180000) // 1978-10-01T23:00:00+0100
        verifyAdding(.init(hour: 1), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)

        // Expected
        //    10-01 23:00 +0100
        //    10-01 00:00 +0200 (start of 10-01)
        //    10-01 01:00 +0200
        // -> 10-01 00:00 +0100 (DST, rewinds back)
    }

    func testAddComponentsWrap2() {
        let timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)

        var date = Date(timeIntervalSince1970: 814950000.0) // 1995-10-29T00:00:00-0700
        verifyAdding(.init(minute: -1), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
        verifyAdding(.init(second: 60), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)

        date = Date(timeIntervalSince1970: 814953599.0) // 1995-10-29T00:59:59-0700
        verifyAdding(.init(minute: 1), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
    }

    func testAddComponentsWrap3_GMT() {
        let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: .gmt, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: .gmt, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)

        let date = Date(timeIntervalSinceReferenceDate: 2557249259.5) // 2082-1-13 19:00:59.5 +0000
        verifyAdding(.init(day: 1), to: date, icuCalendar: icuCalendar, gregorianCalendar: gregorianCalendar, wrap: true)
    }



    // MARK: DateInterval

    func testDateIntervalCompatibility() {
        let firstWeekday = 2
        let minimumDaysInFirstWeek = 4
        let timeZone = TimeZone(secondsFromGMT: -3600 * 8)!
        let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: nil)
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: nil)

        let units: [Calendar.Component] = [.era, .year, .month, .day, .hour, .minute, .second, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .nanosecond]
        let dates: [Date] = [
            Date(timeIntervalSince1970: 851990400.0), // 1996-12-30T16:00:00-0800 (1996-12-31T00:00:00Z),
            Date(timeIntervalSince1970: 820483200.0), // 1996-01-01T00:00:00-0800 (1996-01-01T08:00:00Z),
            Date(timeIntervalSince1970: 828838987.0), // 1996-04-07T01:03:07Z
            Date(timeIntervalSince1970: -62135765813.0), // 0001-01-01T01:03:07Z
            Date(timeIntervalSince1970: 825723300), // 1996-03-01
            Date(timeIntervalSince1970: -12218515200.0),  // 1582-10-14
        ]

        self.continueAfterFailure = false
        for date in dates {
            for unit in units {
                let old = icuCalendar.dateInterval(of: unit, for: date)
                let new = gregorianCalendar.dateInterval(of: unit, for: date)
                let msg = "unit: \(unit), date: \(date)"
                XCTAssertEqual(old?.start, new?.start, msg)
                XCTAssertEqual(old?.end, new?.end, msg)
            }
        }
    }

    func testDateIntervalCompatibility_DST() {
        let firstWeekday = 2
        let minimumDaysInFirstWeek = 4
        let timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: nil)
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: nil)

        let units: [Calendar.Component] = [.era, .year, .month, .day, .hour, .minute, .second, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .nanosecond]
        let dates: [Date] = [
            Date(timeIntervalSince1970: 828867787.0), // 1996-04-07T01:03:07-0800
            Date(timeIntervalSince1970: 828871387.0), // 1996-04-07T03:03:07-0700
            Date(timeIntervalSince1970: 828874987.0), // 1996-04-07T04:03:07-0700
            Date(timeIntervalSince1970: 846403387.0), // 1996-10-27T01:03:07-0700
            Date(timeIntervalSince1970: 846406987.0), // 1996-10-27T01:03:07-0800
            Date(timeIntervalSince1970: 846410587.0), // 1996-10-27T02:03:07-0800
        ]

        self.continueAfterFailure = false
        for date in dates {
            for unit in units {
                let old = icuCalendar.dateInterval(of: unit, for: date)
                let new = gregorianCalendar.dateInterval(of: unit, for: date)
                let msg = "unit: \(unit), date: \(date)"
                XCTAssertEqual(old?.start, new?.start, msg)
                XCTAssertEqual(old?.end, new?.end, msg)
            }
        }
    }

    func testDateInterval() {
        let firstWeekday = 1
        let minimumDaysInFirstWeek = 1
        let timeZone = TimeZone(identifier: "America/Edmonton")!
        let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: nil)
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: nil)

        let unit: Calendar.Component = .weekday
        let date = Date(timeIntervalSinceReferenceDate: -2976971169.0)
        let old = icuCalendar.dateInterval(of: unit, for: date)
        let new = gregorianCalendar.dateInterval(of: unit, for: date)
        let msg = "unit: \(unit), date: \(date)"
        XCTAssertEqual(old?.start, new?.start, msg)
        XCTAssertEqual(old?.end, new?.end, msg)
    }

    func testDateIntervalRemoteDates() {
        let firstWeekday = 2
        let minimumDaysInFirstWeek = 4
        let timeZone = TimeZone.gmt
        let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: nil)
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: nil)

        let allComponents : [Calendar.Component] = [.era, .year, .month, .day, .hour, .minute, .second, .nanosecond, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .dayOfYear, .calendar, .timeZone]

        let dates: [Date] = [
            Date(timeIntervalSinceReferenceDate: -211845067200.0), // 4713-01-01T12:00:00Z
            Date(timeIntervalSinceReferenceDate: 200000000000000.0),
            Date(timeIntervalSinceReferenceDate: 15927175497600.0),
        ]
        for (i, date) in dates.enumerated() {
            let dc1 = icuCalendar.dateComponents([.era, .year, .month, .day, .hour, .minute, .second, .nanosecond, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .dayOfYear, .calendar, .timeZone], from: date)
            let dc2 = gregorianCalendar.dateComponents([.era, .year, .month, .day, .hour, .minute, .second, .nanosecond, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .dayOfYear, .calendar, .timeZone], from: date)
            expectEqual(dc1, dc2, expectQuarter: false, expectCalendar: false, "failure: \(i)")
            for component in allComponents {
                let c1 = icuCalendar.dateInterval(of: component, for: date)
                let c2 = gregorianCalendar.dateInterval(of: component, for: date)
                guard let c1, let c2 else {
                    if c1 != c2 {
                        XCTFail("c1: \(String(describing: c1)), c2: \(String(describing: c2)), component: \(component)")
                    }
                    return
                }
                XCTAssertEqual(c1.start, c2.start, "\(component), start diff c1: \(c1.start.timeIntervalSince(date)), c2: \(c2.start.timeIntervalSince(date))")
                XCTAssertEqual(c1.end, c2.end, "\(component), end diff c1: \(c1.end.timeIntervalSince(date)) c2: \(c2.end.timeIntervalSince(date))")
            }
        }
    }


    func testDateInterval_cappedDate_nonGMT() {
        let firstWeekday = 2
        let minimumDaysInFirstWeek = 4
        let timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: nil)
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: nil)

        let allComponents : [Calendar.Component] = [.era, .year, .month, .day, .hour, .minute, .second, .nanosecond, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .dayOfYear, .calendar, .timeZone]

        let dates: [Date] = [
            Date(timeIntervalSinceReferenceDate: -185185037675833.0).capped,
            Date(timeIntervalSinceReferenceDate: -211845067200.0).capped,
            Date(timeIntervalSinceReferenceDate: 200000000000000.0).capped,
            Date(timeIntervalSinceReferenceDate: 15927175497600.0).capped,

        ]
        for (i, date) in dates.enumerated() {
            for component in allComponents {
                let c1 = icuCalendar.dateInterval(of: component, for: date)
                let c2 = gregorianCalendar.dateInterval(of: component, for: date)
                XCTAssertEqual(c1, c2, "\(i)")
            }
        }
    }

    // MARK: - First instant

    func testFirstInstant() {
        let firstWeekday = 1
        let minimumDaysInFirstWeek = 1
        let timeZone = TimeZone.gmt
        let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: nil)
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: nil)

        let allComponents: [Calendar.Component] = [.day]
        let dates: [Date] = [
            Date(timeIntervalSinceReferenceDate: 15927175497600.0),
        ]
        for date in dates {
            for component in allComponents {
                let c1 = icuCalendar.firstInstant(of: component, at: date)
                let c2 = gregorianCalendar.firstInstant(of: component, at: date)
                guard let c2 else {
                    XCTFail("unexpected nil first instant")
                    continue
                }
                XCTAssertEqual(c1, c2, "c1: \(c1.timeIntervalSinceReferenceDate), c2: \(c2.timeIntervalSinceReferenceDate), \(date.timeIntervalSinceReferenceDate)")
            }
        }
    }

    func testFirstInstantDST() {
        let timeZone = TimeZone(identifier: "Europe/Rome")!
        let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)

        let allComponents : [Calendar.Component] = [.era, .year, .month, .day, .hour, .minute, .second, .nanosecond, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .dayOfYear, .calendar, .timeZone]
        let date = Date(timeIntervalSinceReferenceDate: -702180000.0) // 1978-10-01T23:00:00+0100 DST date, rewinding back one hour, so 25 hour in this day
        for component in allComponents {
            let c1 = icuCalendar.firstInstant(of: component, at: date)
            let c2 = gregorianCalendar.firstInstant(of: component, at: date)
            XCTAssertEqual(c1, c2, "\(date.timeIntervalSinceReferenceDate)")
        }
    }

    func testDateComponentsFromTo() {
        let timeZone = TimeZone(secondsFromGMT: -8*3600)
        let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
        let allComponents : Calendar.ComponentSet = [.era, .year, .month, .day, .hour, .minute, .second, .nanosecond, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .dayOfYear, .calendar, .timeZone]
        let d1 = Date(timeIntervalSinceReferenceDate: 0)         // 2000-12-31 16:00:00 PT
        let d2 = Date(timeIntervalSinceReferenceDate: 5458822.0) // 2001-03-04 20:20:22 PT
        let a = icuCalendar.dateComponents(allComponents, from: d1, to: d2)
        let b = gregorianCalendar.dateComponents(allComponents, from: d1, to: d2)
        expectEqual(a, b)
    }

    func testDifference() throws {
        let timeZone = TimeZone(secondsFromGMT: -8*3600)
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
        let d1 = Date(timeIntervalSinceReferenceDate: 0)         // 2000-12-31 16:00:00 PT
        let d2 = Date(timeIntervalSinceReferenceDate: 5458822.0) // 2001-03-04 20:20:22 PT
        let (_, newStart) = try gregorianCalendar.difference(inComponent: .month, from: d1, to: d2)
        XCTAssertEqual(newStart.timeIntervalSince1970, 983404800) // 2001-03-01 00:00:00 UTC
    }

    func testAdd() {
        let timeZone = TimeZone(secondsFromGMT: -8*3600)!
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
        let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)

        let dc = DateComponents(year: 2000, month: 14, day: 28, hour: 16, minute: 0, second: 0)
        let old = icuCalendar.date(from: dc)!
        let new = gregorianCalendar.date(from: dc)!
        XCTAssertEqual(old, new)
        XCTAssertEqual(old.timeIntervalSince1970, 983404800)

        let d1 = Date(timeIntervalSinceReferenceDate: 0)         // 2000-12-31 16:00:00 PT
        let added = gregorianCalendar.add(.month, to: d1, amount: 2, inTimeZone: timeZone)
        let gregResult = gregorianCalendar.date(byAdding: .init(month: 2), to: d1, wrappingComponents: false)!
        let icuResult = icuCalendar.date(byAdding: .init(month: 2), to: d1, wrappingComponents: false)!
        XCTAssertEqual(gregResult, icuResult)
        XCTAssertEqual(added, icuResult)
        XCTAssertEqual(icuResult.timeIntervalSince1970, 983404800) // 2001-03-01 00:00:00 UTC, 2001-02-28 16:00:00 PT
    }
    func testAdd_precision() {
        let timeZone = TimeZone.gmt
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
        let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)


        let d1 = Date(timeIntervalSinceReferenceDate: 729900523.547439)
        let added = gregorianCalendar.add(.month, to: d1, amount: -277, inTimeZone: timeZone)
        var gregResult: Date
        var icuResult: Date

        gregResult = gregorianCalendar.date(byAdding: .init(month: -277), to: d1, wrappingComponents: false)!
        icuResult = icuCalendar.date(byAdding: .init(month: -277), to: d1, wrappingComponents: false)!
        XCTAssertEqual(gregResult, icuResult, "greg: \(gregResult.timeIntervalSinceReferenceDate), icu: \(icuResult.timeIntervalSinceReferenceDate)")
        XCTAssertEqual(added, icuResult)

        let d2 = Date(timeIntervalSinceReferenceDate: -0.4525610214656613)
        gregResult = gregorianCalendar.date(byAdding: .init(nanosecond: 500000000), to: d2, wrappingComponents: false)!
        icuResult = icuCalendar.date(byAdding: .init(nanosecond: 500000000), to: d2, wrappingComponents: false)!
        XCTAssertEqual(gregResult, icuResult, "greg: \(gregResult.timeIntervalSinceReferenceDate), icu: \(icuResult.timeIntervalSinceReferenceDate)")

        let d3 = Date(timeIntervalSinceReferenceDate: 729900523.547439)
        gregResult = gregorianCalendar.date(byAdding: .init(year: -60), to: d3, wrappingComponents: false)!
        icuResult = icuCalendar.date(byAdding: .init(year: -60), to: d3, wrappingComponents: false)!
        XCTAssertEqual(gregResult, icuResult, "greg: \(gregResult.timeIntervalSinceReferenceDate), icu: \(icuResult.timeIntervalSinceReferenceDate)")
    }

    func testDateComponentsFromTo_precision() {
        let timeZone = TimeZone.gmt
        let gregorianCalendar = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
        let icuCalendar = _CalendarICU(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)

        let allComponents : Calendar.ComponentSet = [.era, .year, .month, .day, .hour, .minute, .second, .nanosecond, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .dayOfYear, .calendar, .timeZone]
        let tests: [(Double, Double)] = [ /*start, finish*/
            (0, 1.005),
            (0, 1.0005),
            (0, 1.4),
            (0, 1.5),
            (0, 1.6),
            (1.005, 0),
        ]

        var a: DateComponents
        var b: DateComponents
        for (i, (ti1, ti2)) in tests.enumerated() {
            let d1 = Date(timeIntervalSinceReferenceDate: ti1)
            let d2 = Date(timeIntervalSinceReferenceDate: ti2)
            a = icuCalendar.dateComponents(allComponents, from: d1, to: d2)
            b = gregorianCalendar.dateComponents(allComponents, from: d1, to: d2)
            XCTAssertEqual(a, b, "test: \(i)")

            expectEqual(a, b, "test: \(i)")
        }

        for (i, (ti1, ti2)) in tests.enumerated() {
            let d1 = Date(timeIntervalSinceReferenceDate: ti1)
            let d2 = Date(timeIntervalSinceReferenceDate: ti2)
            a = icuCalendar.dateComponents([.nanosecond], from: d1, to: d2)
            b = gregorianCalendar.dateComponents([.nanosecond], from: d1, to: d2)
            XCTAssertEqual(a, b, "test: \(i)")
            if ti1 < ti2 {
                XCTAssertGreaterThanOrEqual(b.nanosecond!, 0, "test: \(i)")
            } else {
                XCTAssertLessThanOrEqual(b.nanosecond!, 0, "test: \(i)")
            }
            expectEqual(a, b, "test: \(i)")
        }

    }

}
