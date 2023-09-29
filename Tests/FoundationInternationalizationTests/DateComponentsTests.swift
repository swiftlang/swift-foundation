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

final class DateComponentsTests : XCTestCase {

    func test_isValidDate() {
        let dc = DateComponents(year: 2022, month: 11, day: 1)
        XCTAssertTrue(dc.isValidDate(in: Calendar(identifier: .gregorian)))

        let dc2 = DateComponents(year: 2022, month: 11, day: 32)
        XCTAssertFalse(dc2.isValidDate(in: Calendar(identifier: .gregorian)))
    }

    func test_leapMonth() {
        var components = DateComponents()
        components.month = 1

        XCTAssertFalse(components.isLeapMonth ?? true == false)

        components.isLeapMonth = true

        XCTAssertEqual(components.month, 1)
        XCTAssertTrue(components.isLeapMonth ?? false == true)
    }

    func test_valueForComponent() {
        let comps = DateComponents(calendar: nil, timeZone: nil, era: 1, year: 2013, month: 4, day: 2, hour: 20, minute: 33, second: 49, nanosecond: 192837465, weekday: 3, weekdayOrdinal: 1, quarter: nil, weekOfMonth: 1, weekOfYear: 14, yearForWeekOfYear: 2013)

        XCTAssertEqual(comps.value(for: .calendar), nil)
        XCTAssertEqual(comps.value(for: .timeZone), nil)
        XCTAssertEqual(comps.value(for: .era), 1)
        XCTAssertEqual(comps.value(for: .year), 2013)
        XCTAssertEqual(comps.value(for: .month), 4)
        XCTAssertEqual(comps.value(for: .day), 2)
        XCTAssertEqual(comps.value(for: .hour), 20)
        XCTAssertEqual(comps.value(for: .minute), 33)
        XCTAssertEqual(comps.value(for: .second), 49)
        XCTAssertEqual(comps.value(for: .nanosecond), 192837465)
        XCTAssertEqual(comps.value(for: .weekday), 3)
        XCTAssertEqual(comps.value(for: .weekdayOrdinal), 1)
        XCTAssertEqual(comps.value(for: .quarter), nil)
        XCTAssertEqual(comps.value(for: .weekOfMonth), 1)
        XCTAssertEqual(comps.value(for: .weekOfYear), 14)
        XCTAssertEqual(comps.value(for: .yearForWeekOfYear), 2013)
    }

    func test_nanosecond() {
        var comps = DateComponents(nanosecond: 123456789)
        XCTAssertEqual(comps.nanosecond, 123456789)

        comps.year = 2013
        comps.month = 12
        comps.day = 2
        comps.hour = 12
        comps.minute = 30
        comps.second = 45

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!

        let dateWithNS = cal.date(from: comps)!
        let newComps = cal.dateComponents([.nanosecond], from: dateWithNS)

        let nanosecondsApproximatelyEqual = labs(CLong(newComps.nanosecond!) - 123456789) <= 500
        XCTAssertTrue(nanosecondsApproximatelyEqual)
    }

    func testDateComponents() {
        // Make sure the optional init stuff works
        let dc = DateComponents()

        XCTAssertNil(dc.year)

        let dc2 = DateComponents(year: 1999)

        XCTAssertNil(dc2.day)
        XCTAssertEqual(1999, dc2.year)
    }

    func test_AnyHashableContainingDateComponents() {
        let values: [DateComponents] = [
            DateComponents(year: 2016),
            DateComponents(year: 1995),
            DateComponents(year: 1995),
        ]
        let anyHashables = values.map(AnyHashable.init)
        expectEqual(DateComponents.self, type(of: anyHashables[0].base))
        expectEqual(DateComponents.self, type(of: anyHashables[1].base))
        expectEqual(DateComponents.self, type(of: anyHashables[2].base))
        XCTAssertNotEqual(anyHashables[0], anyHashables[1])
        XCTAssertEqual(anyHashables[1], anyHashables[2])
    }

    func test_weekComponent() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        // date(from: "2010-09-08 07:59:54 +0000")
        let date = Date(timeIntervalSinceReferenceDate: 305625594.0)
        let comps = calendar.dateComponents([.weekOfYear], from: date)
        XCTAssertEqual(comps.weekOfYear, 37)
    }

    func test_components_fromDate_toDate_options_withEraChange() {
        // date(from: "1900-01-01 01:23:34 +0000")
        let fromDate = Date(timeIntervalSinceReferenceDate: -3187290986.0)
        // date(from: "2010-09-08 07:59:54 +0000")
        let toDate = Date(timeIntervalSinceReferenceDate: 305625594.0)

        var calendar = Calendar(identifier: .japanese)
        calendar.timeZone = .gmt

        let units: Set<Calendar.Component> = [.era, .year, .month, .day, .hour, .minute, .second]

        let comps = calendar.dateComponents(units, from: fromDate, to: toDate)

        XCTAssertEqual(comps.era, 3)
        XCTAssertEqual(comps.year, -10)
        XCTAssertEqual(comps.month, -3)
        XCTAssertEqual(comps.day, -22)
        XCTAssertEqual(comps.hour, -17)
        XCTAssertEqual(comps.minute, -23)
        XCTAssertEqual(comps.second, -40)
    }
}

// MARK: - FoundationPreview disabled utils
#if FOUNDATION_FRAMEWORK
extension DateComponentsTests {
    func date(from string: String, nanoseconds: Int? = nil) -> Date {
        let d = try! Date(string, strategy: Date.ParseStrategy(format: "\(year: .extended(minimumLength: 4))-\(month: .twoDigits)-\(day: .twoDigits) \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\(second: .twoDigits) \(timeZone: .iso8601(.short))", locale: Locale(identifier: "en_US"), timeZone: TimeZone.gmt))
        if let nanoseconds {
            var comps = Calendar(identifier: .gregorian).dateComponents([.era, .year, .month, .day, .hour, .minute, .second, .nanosecond, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .timeZone, .calendar], from: d)
            return Calendar(identifier: .gregorian).date(from: comps)!
        }
        return d
    }
}
#endif // FOUNDATION_FRAMEWORK
