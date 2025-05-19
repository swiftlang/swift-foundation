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

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#endif

final class ISO8601FormatStyleParsingTests: XCTestCase {

    /// See also the format-only tests in DateISO8601FormatStyleEssentialsTests
    func test_ISO8601Parse() throws {
        let iso8601 = Date.ISO8601FormatStyle()

        // Date is: "2022-01-28 15:35:46"
        XCTAssertEqual(try? iso8601.parse("2022-01-28T15:35:46Z"), Date(timeIntervalSinceReferenceDate: 665076946.0))

        var iso8601Pacific = iso8601
        iso8601Pacific.timeZone = TimeZone(secondsFromGMT: -3600 * 8)!
        XCTAssertEqual(try? iso8601Pacific.timeSeparator(.omitted).parse("2022-01-28T073546-0800"), Date(timeIntervalSinceReferenceDate: 665076946.0))

        // Day-only results: the default time is midnight for parsed date when the time piece is missing
        // Date is: "2022-01-28 00:00:00"
        XCTAssertEqual(try? iso8601.year().month().day().dateSeparator(.dash).parse("2022-01-28"), Date(timeIntervalSinceReferenceDate: 665020800.0))
        // Date is: "2022-01-28 00:00:00"
        XCTAssertEqual(try? iso8601.year().month().day().dateSeparator(.omitted).parse("20220128"), Date(timeIntervalSinceReferenceDate: 665020800.0))

        // Time-only results: we use the default date of the format style, 1970-01-01, to supplement the parsed date without year, month or day
        // Date is: "1970-01-23 00:00:00"
        XCTAssertEqual(try? iso8601.weekOfYear().day().dateSeparator(.dash).parse("W04-05"), Date(timeIntervalSinceReferenceDate: -976406400.0))
        // Date is: "1970-01-28 15:35:46"
        XCTAssertEqual(try? iso8601.day().time(includingFractionalSeconds: false).timeSeparator(.colon).parse("028T15:35:46"), Date(timeIntervalSinceReferenceDate: -975918254.0))
        // Date is: "1970-01-01 15:35:46"
        XCTAssertEqual(try? iso8601.time(includingFractionalSeconds: false).timeSeparator(.colon).parse("15:35:46"), Date(timeIntervalSinceReferenceDate: -978251054.0))
        // Date is: "1970-01-01 15:35:46"
        XCTAssertEqual(try? iso8601.time(includingFractionalSeconds: false).timeZone(separator: .omitted).parse("15:35:46Z"), Date(timeIntervalSinceReferenceDate: -978251054.0))
        // Date is: "1970-01-01 15:35:46"
        XCTAssertEqual(try? iso8601.time(includingFractionalSeconds: false).timeZone(separator: .colon).parse("15:35:46Z"), Date(timeIntervalSinceReferenceDate: -978251054.0))
        // Date is: "1970-01-01 15:35:46"
        XCTAssertEqual(try? iso8601.timeZone(separator: .colon).time(includingFractionalSeconds: false).timeSeparator(.colon).parse("15:35:46Z"), Date(timeIntervalSinceReferenceDate: -978251054.0))
    }
    
    func test_ISO8601ParseComponents_fromString() throws {
        let components = try DateComponents.ISO8601FormatStyle().parse("2022-01-28T15:35:46Z")
        XCTAssertEqual(components, DateComponents(calendar: Calendar(identifier: .iso8601), timeZone: .gmt, year: 2022, month: 1, day: 28, hour: 15, minute: 35, second: 46))
        XCTAssertNotNil(components.date)
    }
    
    func test_ISO8601ParseComponents_missingComponents() throws {
        // Default style requires time
        XCTAssertThrowsError(try DateComponents.ISO8601FormatStyle().parse("2022-01-28"))
    }

    /// See also the format-only tests in DateISO8601FormatStyleEssentialsTests
    func test_ISO8601ParseComponents() throws {
        let iso8601 = DateComponents.ISO8601FormatStyle()

        // Date is: "2022-01-28 15:35:46"
        XCTAssertEqual(try? iso8601.parse("2022-01-28T15:35:46Z"), DateComponents(calendar: Calendar(identifier: .iso8601), timeZone: .gmt, year: 2022, month: 1, day: 28, hour: 15, minute: 35, second: 46))

        var iso8601Pacific = iso8601
        let tz = TimeZone(secondsFromGMT: -3600 * 8)!
        iso8601Pacific.timeZone = tz
        XCTAssertEqual(try? iso8601Pacific.timeSeparator(.omitted).parse("2022-01-28T073546-0800"), DateComponents(calendar: Calendar(identifier: .iso8601), timeZone: tz, year: 2022, month: 1, day: 28, hour: 7, minute: 35, second: 46))

        // Day-only results: the default time is midnight for parsed date when the time piece is missing
        // Date is: "2022-01-28 00:00:00"
        XCTAssertEqual(try? iso8601.year().month().day().dateSeparator(.dash).parse("2022-01-28"), DateComponents(calendar: Calendar(identifier: .iso8601), timeZone: .gmt, year: 2022, month: 1, day: 28))
        // Date is: "2022-01-28 00:00:00"
        XCTAssertEqual(try? iso8601.year().month().day().dateSeparator(.omitted).parse("20220128"), DateComponents(calendar: Calendar(identifier: .iso8601), timeZone: .gmt, year: 2022, month: 1, day: 28))

        // Time-only results: we use the default date of the format style, 1970-01-01, to supplement the parsed date without year, month or day
        // Date is: "1970-01-23 00:00:00"
        // note: weekday as understood by Calendar is not the same integer value as the one in the ISO8601 format
        XCTAssertEqual(try? iso8601.weekOfYear().day().dateSeparator(.dash).parse("W04-05"), DateComponents(calendar: Calendar(identifier: .iso8601), timeZone: .gmt, weekday: 6, weekOfYear: 4))
        // Date is: "1970-01-28 15:35:46"
        var expectedWithDayOfYear = DateComponents(calendar: Calendar(identifier: .iso8601), timeZone: .gmt, hour: 15, minute: 35, second: 46)
        expectedWithDayOfYear.dayOfYear = 28
        XCTAssertEqual(try? iso8601.day().time(includingFractionalSeconds: false).timeSeparator(.colon).parse("028T15:35:46"), expectedWithDayOfYear)
        // Date is: "1970-01-01 15:35:46"
        XCTAssertEqual(try? iso8601.time(includingFractionalSeconds: false).timeSeparator(.colon).parse("15:35:46"), DateComponents(calendar: Calendar(identifier: .iso8601), timeZone: .gmt, hour: 15, minute: 35, second: 46))
        // Date is: "1970-01-01 15:35:46"
        XCTAssertEqual(try? iso8601.time(includingFractionalSeconds: false).timeZone(separator: .omitted).parse("15:35:46Z"), DateComponents(calendar: Calendar(identifier: .iso8601), timeZone: .gmt, hour: 15, minute: 35, second: 46))
        // Date is: "1970-01-01 15:35:46"
        XCTAssertEqual(try? iso8601.time(includingFractionalSeconds: false).timeZone(separator: .colon).parse("15:35:46Z"), DateComponents(calendar: Calendar(identifier: .iso8601), timeZone: .gmt, hour: 15, minute: 35, second: 46))
        // Date is: "1970-01-01 15:35:46"
        XCTAssertEqual(try? iso8601.timeZone(separator: .colon).time(includingFractionalSeconds: false).timeSeparator(.colon).parse("15:35:46Z"), DateComponents(calendar: Calendar(identifier: .iso8601), timeZone: .gmt, hour: 15, minute: 35, second: 46))
    }
        
    func test_ISO8601FractionalSecondsAreOptional() {
        let iso8601 = Date.ISO8601FormatStyle()
        let iso8601WithFraction = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        
        let str = "2022-01-28T15:35:46Z"
        let strWithFraction = "2022-01-28T15:35:46.123Z"
        
        XCTAssertNotNil(try? iso8601.parse(str))
        XCTAssertNotNil(try? iso8601.parse(strWithFraction))

        XCTAssertNotNil(try? iso8601WithFraction.parse(str))
        XCTAssertNotNil(try? iso8601WithFraction.parse(strWithFraction))
    }
    
    func test_weekOfYear() throws {
        let iso8601 = Date.ISO8601FormatStyle()

        // Test some dates around the 2019 - 2020 end of year, and 2026 which has W53
        let dates = [
            ("2019-W52-07", "2019-12-29"),
            ("2020-W01-01", "2019-12-30"),
            ("2020-W01-02", "2019-12-31"),
            ("2020-W01-03", "2020-01-01"),
            ("2026-W53-01", "2026-12-28"),
            ("2026-W53-02", "2026-12-29"),
            ("2026-W53-03", "2026-12-30"),
            ("2026-W53-04", "2026-12-31"),
            ("2026-W53-05", "2027-01-01"),
            ("2026-W53-06", "2027-01-02"),
            ("2026-W53-07", "2027-01-03"),
            ("2027-W01-01", "2027-01-04"),
            ("2027-W01-02", "2027-01-05")
        ]

        for d in dates {
            let parsedWoY = try iso8601.year().weekOfYear().day().parse(d.0)
            let parsedY = try iso8601.year().month().day().parse(d.1)
            XCTAssertEqual(parsedWoY, parsedY)
        }
    }
    
    func test_zeroLeadingDigits() {
        // The parser allows for an arbitrary number of 0 pads in digits, including none.
        let iso8601 = Date.ISO8601FormatStyle()

        // Date is: "2022-01-28 15:35:46"
        XCTAssertEqual(try? iso8601.parse("2022-01-28T15:35:46Z"), Date(timeIntervalSinceReferenceDate: 665076946.0))
        XCTAssertEqual(try? iso8601.parse("002022-01-28T15:35:46Z"), Date(timeIntervalSinceReferenceDate: 665076946.0))
        XCTAssertEqual(try? iso8601.parse("2022-0001-28T15:35:46Z"), Date(timeIntervalSinceReferenceDate: 665076946.0))
        XCTAssertEqual(try? iso8601.parse("2022-01-0028T15:35:46Z"), Date(timeIntervalSinceReferenceDate: 665076946.0))
        XCTAssertEqual(try? iso8601.parse("2022-1-28T15:35:46Z"), Date(timeIntervalSinceReferenceDate: 665076946.0))
        XCTAssertEqual(try? iso8601.parse("2022-01-28T15:35:06Z"), Date(timeIntervalSinceReferenceDate: 665076906.0))
        XCTAssertEqual(try? iso8601.parse("2022-01-28T15:35:6Z"), Date(timeIntervalSinceReferenceDate: 665076906.0))
        XCTAssertEqual(try? iso8601.parse("2022-01-28T15:05:46Z"), Date(timeIntervalSinceReferenceDate: 665075146.0))
        XCTAssertEqual(try? iso8601.parse("2022-01-28T15:5:46Z"), Date(timeIntervalSinceReferenceDate: 665075146.0))
    }
    
    func test_timeZones() {
        let iso8601 = Date.ISO8601FormatStyle()
        let date = Date(timeIntervalSinceReferenceDate: 665076946.0)
        
        var iso8601Pacific = iso8601
        iso8601Pacific.timeZone = TimeZone(secondsFromGMT: -3600 * 8)!
        
        // Has a seconds component (-28830)
        var iso8601PacificIsh = iso8601
        iso8601PacificIsh.timeZone = TimeZone(secondsFromGMT: -3600 * 8 - 30)!
        
        XCTAssertEqual(try? iso8601Pacific.timeSeparator(.omitted).parse("2022-01-28T073546-0800"), date)
        XCTAssertEqual(try? iso8601Pacific.timeSeparator(.omitted).timeZoneSeparator(.colon).parse("2022-01-28T073546-08:00"), date)

        XCTAssertEqual(try? iso8601PacificIsh.timeSeparator(.omitted).parse("2022-01-28T073516-080030"), date)
        XCTAssertEqual(try? iso8601PacificIsh.timeSeparator(.omitted).timeZoneSeparator(.colon).parse("2022-01-28T073516-08:00:30"), date)
        
        var iso8601gmtP1 = iso8601
        iso8601gmtP1.timeZone = TimeZone(secondsFromGMT: 3600)!
        XCTAssertEqual(try? iso8601gmtP1.timeSeparator(.omitted).parse("2022-01-28T163546+0100"), date)
        XCTAssertEqual(try? iso8601gmtP1.timeSeparator(.omitted).parse("2022-01-28T163546+010000"), date)
        XCTAssertEqual(try? iso8601gmtP1.timeSeparator(.omitted).timeZoneSeparator(.colon).parse("2022-01-28T163546+01:00"), date)
        XCTAssertEqual(try? iso8601gmtP1.timeSeparator(.omitted).timeZoneSeparator(.colon).parse("2022-01-28T163546+01:00:00"), date)

        // Due to a quirk of the original implementation, colons are allowed to be present in the time zone even if the time zone separator is omitted
        XCTAssertEqual(try? iso8601gmtP1.timeSeparator(.omitted).parse("2022-01-28T163546+01:00"), date)
        XCTAssertEqual(try? iso8601gmtP1.timeSeparator(.omitted).parse("2022-01-28T163546+01:00:00"), date)
    }
    
    func test_fractionalSeconds() throws {
        let expectedDate = Date(timeIntervalSinceReferenceDate: 646876592.34567)
        var iso8601 = Date.ISO8601FormatStyle().year().month().day().time(includingFractionalSeconds: true)
        iso8601.timeZone = .gmt

        let parsedWithFraction = try XCTUnwrap(try iso8601.parse("2021-07-01T23:56:32.34567"))
        let parsedWithoutFraction = try XCTUnwrap(try iso8601.parse("2021-07-01T23:56:32"))
        
        let parsedWithFraction1 = try XCTUnwrap(try iso8601.parse("2021-07-01T23:56:32.3"))
        let parsedWithFraction2 = try XCTUnwrap(try iso8601.parse("2021-07-01T23:56:32.34"))
        let parsedWithFraction3 = try XCTUnwrap(try iso8601.parse("2021-07-01T23:56:32.345"))
        let parsedWithFraction4 = try XCTUnwrap(try iso8601.parse("2021-07-01T23:56:32.3456"))

        XCTAssertEqual(parsedWithoutFraction.timeIntervalSinceReferenceDate, expectedDate.timeIntervalSinceReferenceDate, accuracy: 1.0)

        // More accurate due to inclusion of fraction
        XCTAssertEqual(parsedWithFraction.timeIntervalSinceReferenceDate, expectedDate.timeIntervalSinceReferenceDate, accuracy: 0.01)
        XCTAssertEqual(parsedWithFraction1.timeIntervalSinceReferenceDate, expectedDate.timeIntervalSinceReferenceDate, accuracy: 0.1)
        XCTAssertEqual(parsedWithFraction2.timeIntervalSinceReferenceDate, expectedDate.timeIntervalSinceReferenceDate, accuracy: 0.1)
        XCTAssertEqual(parsedWithFraction3.timeIntervalSinceReferenceDate, expectedDate.timeIntervalSinceReferenceDate, accuracy: 0.1)
        XCTAssertEqual(parsedWithFraction4.timeIntervalSinceReferenceDate, expectedDate.timeIntervalSinceReferenceDate, accuracy: 0.1)
    }
    
    func test_specialTimeZonesAndSpaces() {
        let reference = try! Date("2020-03-05T12:00:00+00:00", strategy: .iso8601)

        let tests : [(String, Date.ISO8601FormatStyle)] = [
            ("2020-03-05T12:00:00+00:00", Date.ISO8601FormatStyle()),
            ("2020-03-05T12:00:00+0000", Date.ISO8601FormatStyle()),
            ("2020-03-05T12:00:00GMT", Date.ISO8601FormatStyle()),
            ("2020-03-05T12:00:00UTC", Date.ISO8601FormatStyle()),
            ("2020-03-05T11:00:00-01:00", Date.ISO8601FormatStyle().year().month().day().time(includingFractionalSeconds: false).timeSeparator(.colon).timeZone(separator: .colon)),
            ("2020-03-05T12:00:00Z", Date.ISO8601FormatStyle().year().month().day().time(includingFractionalSeconds: false).timeSeparator(.colon).timeZone(separator: .colon)), // allow Z
            ("2020-03-05T12:00:00z", Date.ISO8601FormatStyle().year().month().day().time(includingFractionalSeconds: false).timeSeparator(.colon).timeZone(separator: .colon)), // allow z
            ("2020-03-05T12:00:00UTC", Date.ISO8601FormatStyle().year().month().day().time(includingFractionalSeconds: false).timeSeparator(.colon).timeZone(separator: .colon)), // allow UTC
            ("2020-03-05T12:00:00GMT", Date.ISO8601FormatStyle().year().month().day().time(includingFractionalSeconds: false).timeSeparator(.colon).timeZone(separator: .colon)), // allow GMT
            ("2020-03-05T13:00:00UTC+1:00", Date.ISO8601FormatStyle().year().month().day().time(includingFractionalSeconds: false).timeSeparator(.colon).timeZone(separator: .colon)), // allow UTC offsets
            ("2020-03-05T13:00:00UTC+01", Date.ISO8601FormatStyle().year().month().day().time(includingFractionalSeconds: false).timeSeparator(.colon).timeZone(separator: .colon)), // allow hours-only (2 digit)
            ("2020-03-05T11:00:00GMT-1:00", Date.ISO8601FormatStyle().year().month().day().time(includingFractionalSeconds: false).timeSeparator(.colon).timeZone(separator: .colon)), // allow GMT offsets
            ("2020-03-05 12:00:00+0000", Date.ISO8601FormatStyle().year().month().day().dateTimeSeparator(.space).time(includingFractionalSeconds: false).timeZone(separator: .omitted)),
            ("2020-03-05 11:00:00-0100", Date.ISO8601FormatStyle().year().month().day().dateTimeSeparator(.space).time(includingFractionalSeconds: false).timeZone(separator: .omitted)),
            ("2020-03-05   11:00:00-0100", Date.ISO8601FormatStyle().year().month().day().dateTimeSeparator(.space).time(includingFractionalSeconds: false).timeZone(separator: .omitted)), // spaces allowed between date/time and time
            ("2020-03-05   11:00:00 -0100", Date.ISO8601FormatStyle().year().month().day().dateTimeSeparator(.space).time(includingFractionalSeconds: false).timeZone(separator: .omitted)), // spaces allowed between date/time and time/timeZone
            ("2020-03-05   11:00:00    -0100", Date.ISO8601FormatStyle().year().month().day().dateTimeSeparator(.space).time(includingFractionalSeconds: false).timeZone(separator: .omitted)), // spaces allowed between date/time and time/timeZone
            ("2020-03-05   10:30:00    -0130", Date.ISO8601FormatStyle().year().month().day().dateTimeSeparator(.space).time(includingFractionalSeconds: false).timeZone(separator: .omitted)), // spaces allowed between date/time and time/timeZone - half hour offset
            ("2020-03-05   10:30:00    -0130", Date.ISO8601FormatStyle().year().month().day().dateTimeSeparator(.space).time(includingFractionalSeconds: false).timeZone(separator: .colon)), // separator can be colon, or missing
            ("2020-03-05   12:00:00    GMT", Date.ISO8601FormatStyle().year().month().day().dateTimeSeparator(.space).time(includingFractionalSeconds: false).timeZone(separator: .colon)), // spaces between time zone and GMT
            ("2020-03-05   11:00:00    GMT-0100", Date.ISO8601FormatStyle().year().month().day().dateTimeSeparator(.space).time(includingFractionalSeconds: false).timeZone(separator: .colon)), // spaces between time zone and GMT, GMT has offset
            ("2020-03-05   11:00:00    gMt-0100", Date.ISO8601FormatStyle().year().month().day().dateTimeSeparator(.space).time(includingFractionalSeconds: false).timeZone(separator: .colon)), // spaces between time zone and GMT, GMT has offset, GMT has different capitalization
            ("2020-03-05   12:00:00    GMT -0100", Date.ISO8601FormatStyle().year().month().day().dateTimeSeparator(.space).time(includingFractionalSeconds: false).timeZone(separator: .colon)), // spaces after GMT cause rest of time to be ignored (note here time of 12:00:00 instead of 11:00:00)
            ("2020-03-05   12:00:00    GMT +0100", Date.ISO8601FormatStyle().year().month().day().dateTimeSeparator(.space).time(includingFractionalSeconds: false).timeZone(separator: .colon)), // spaces after GMT cause rest of time to be ignored (note here time of 12:00:00 instead of 11:00:00)
            ("2020-03-05   12:00:00    Z +0100", Date.ISO8601FormatStyle().year().month().day().dateTimeSeparator(.space).time(includingFractionalSeconds: false).timeZone(separator: .colon)), // values after Z are ignored, spaces
            ("2020-03-05   12:00:00    Z+0100", Date.ISO8601FormatStyle().year().month().day().dateTimeSeparator(.space).time(includingFractionalSeconds: false).timeZone(separator: .colon)), // values after Z are ignored, no spaces
        ]

        for (parseMe, style) in tests {
            let parsed = try? style.parse(parseMe)
            XCTAssertEqual(parsed, reference, """

parsing : \(parseMe)
expected: \(reference) \(reference.timeIntervalSinceReferenceDate)
result  : \(parsed != nil ? parsed!.debugDescription : "nil") \(parsed != nil ? parsed!.timeIntervalSinceReferenceDate : 0)
""")
        }
    }
        
#if canImport(FoundationInternationalization) || FOUNDATION_FRAMEWORK
    func test_chileTimeZone() {
        var iso8601Chile = Date.ISO8601FormatStyle().year().month().day()
        iso8601Chile.timeZone = TimeZone(name: "America/Santiago")!
        
        let date = try? iso8601Chile.parse("2023-09-03")
        XCTAssertNotNil(date)
    }
#endif
}

final class DateISO8601FormatStylePatternMatchingTests : XCTestCase {

    func _matchFullRange(_ str: String, formatStyle: Date.ISO8601FormatStyle, expectedUpperBound: String.Index?, expectedDate: Date?, file: StaticString = #filePath, line: UInt = #line) {
        _matchRange(str, formatStyle: formatStyle, range: nil, expectedUpperBound: expectedUpperBound, expectedDate: expectedDate, file: file, line: line)
    }

    func _matchFullRange(_ str: String, formatStyle: DateComponents.ISO8601FormatStyle, expectedUpperBound: String.Index?, expectedDateComponents: DateComponents?, file: StaticString = #filePath, line: UInt = #line) {
        _matchRange(str, formatStyle: formatStyle, range: nil, expectedUpperBound: expectedUpperBound, expectedDateComponents: expectedDateComponents, file: file, line: line)
    }

    func _matchRange(_ str: String, formatStyle: Date.ISO8601FormatStyle, range: Range<String.Index>?, expectedUpperBound: String.Index?, expectedDate: Date?, file: StaticString = #filePath, line: UInt = #line) {
        // FIXME: Need tests that starts from somewhere else
        let m = try? formatStyle.consuming(str, startingAt: str.startIndex, in: range ?? str.startIndex..<str.endIndex)
        let upperBound = m?.upperBound
        let match = m?.output

        let upperBoundDescription = upperBound?.utf16Offset(in: str)
        let expectedUpperBoundDescription = expectedUpperBound?.utf16Offset(in: str)
        XCTAssertEqual(upperBound, expectedUpperBound, "found upperBound: \(String(describing: upperBoundDescription)); expected: \(String(describing: expectedUpperBoundDescription))", file: file, line: line)
        if let match, let expectedDate {
            XCTAssertEqual(
                match.timeIntervalSinceReferenceDate,
                expectedDate.timeIntervalSinceReferenceDate,
                accuracy: 0.001,
                file: file,
                line: line
            )
        }
    }

    func _matchRange(_ str: String, formatStyle: DateComponents.ISO8601FormatStyle, range: Range<String.Index>?, expectedUpperBound: String.Index?, expectedDateComponents: DateComponents?, file: StaticString = #filePath, line: UInt = #line) {
        // FIXME: Need tests that starts from somewhere else
        let m = try? formatStyle.consuming(str, startingAt: str.startIndex, in: range ?? str.startIndex..<str.endIndex)
        let upperBound = m?.upperBound
        let match = m?.output

        let upperBoundDescription = upperBound?.utf16Offset(in: str)
        let expectedUpperBoundDescription = expectedUpperBound?.utf16Offset(in: str)
        XCTAssertEqual(upperBound, expectedUpperBound, "found upperBound: \(String(describing: upperBoundDescription)); expected: \(String(describing: expectedUpperBoundDescription))", file: file, line: line)
        if let match, let expectedDateComponents {
            // Only verify the components that are set in the expected. Skip them if they are nil. We don't provide a way to verify the output is nil in this function.
            let comps : [Calendar.Component] = [.era, .year, .month, .day, .hour, .minute, .second, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .nanosecond, .dayOfYear]
            for c in comps {
                if let expected = expectedDateComponents.value(for: c) {
                    XCTAssertEqual(
                        match.value(for: c),
                        expected,
                        file: file,
                        line: line)
                }
            }
            
            if let tz = expectedDateComponents.timeZone {
                XCTAssertEqual(match.timeZone, tz, file: file, line: line)
            }
        }
        
        if match != nil, expectedDateComponents == nil {
            XCTFail("Expected no result, but got one anyway", file: file, line: line)
        }
    }

    func testMatchDefaultISO8601Style() throws {
        func verify(_ str: String, expectedUpperBound: String.Index?, expectedDate: Date?, file: StaticString = #filePath, line: UInt = #line) {
            let iso8601FormatStyle = Date.ISO8601FormatStyle()
            _matchFullRange(str, formatStyle: iso8601FormatStyle, expectedUpperBound: expectedUpperBound, expectedDate: expectedDate, file: file, line: line)
        }
        
        func verify(_ str: String, expectedUpperBound: String.Index?, expectedDateComponents: DateComponents?, file: StaticString = #filePath, line: UInt = #line) {
            let iso8601ComponentsFormatStyle = DateComponents.ISO8601FormatStyle()
            _matchFullRange(str, formatStyle: iso8601ComponentsFormatStyle, expectedUpperBound: expectedUpperBound, expectedDateComponents: expectedDateComponents, file: file, line: line)
        }

        // dateFormatter.date(from: "2021-07-01 15:56:32")!
        let expectedDate = Date(timeIntervalSinceReferenceDate: 646847792.0)
        let expectedDateComponents = DateComponents(year: 2021, month: 7, day: 1, hour: 15, minute: 56, second: 32)
        
        let str = "2021-07-01T15:56:32Z"
        verify(str, expectedUpperBound: str.endIndex, expectedDate: expectedDate)
        verify(str, expectedUpperBound: str.endIndex, expectedDateComponents: expectedDateComponents)
        verify("\(str) text", expectedUpperBound: str.endIndex, expectedDate: expectedDate)
        verify("\(str) text", expectedUpperBound: str.endIndex, expectedDateComponents: expectedDateComponents)

        verify("some \(str)", expectedUpperBound: nil, expectedDate: nil) // We can't find a matched date because the matching starts at the first character
        verify("some \(str)", expectedUpperBound: nil, expectedDateComponents: nil) // We can't find a matched date because the matching starts at the first character
        verify("9999-37-40T35:70:99Z", expectedUpperBound: nil, expectedDate: nil) // This is not a valid date
        verify("9999-37-40T35:70:99Z", expectedUpperBound: nil, expectedDateComponents: nil) // This is not a valid date
    }

    func testPartialMatchISO8601() throws {
        func verify(_ str: String, _ style: Date.ISO8601FormatStyle, expectedDate: Date?, expectedLength: Int?, file: StaticString = #filePath, line: UInt = #line) {
            let expectedUpperBoundStrIndx = (expectedLength != nil) ? str.index(str.startIndex, offsetBy: expectedLength!) : nil
            _matchFullRange(str, formatStyle: style, expectedUpperBound: expectedUpperBoundStrIndx, expectedDate: expectedDate, file: file, line: line)
        }

        func verify(_ str: String, _ style: DateComponents.ISO8601FormatStyle, expectedDateComponents: DateComponents?, expectedLength: Int?, file: StaticString = #filePath, line: UInt = #line) {
            let expectedUpperBoundStrIndx = (expectedLength != nil) ? str.index(str.startIndex, offsetBy: expectedLength!) : nil
            _matchFullRange(str, formatStyle: style, expectedUpperBound: expectedUpperBoundStrIndx, expectedDateComponents: expectedDateComponents, file: file, line: line)
        }

        let gmt = TimeZone(secondsFromGMT: 0)!
        let pst = TimeZone(secondsFromGMT: -3600*8)!

        // This format requires a time zone
        do {
            let expectedDate : Date? = nil
            let expectedLength : Int? = nil
            verify("2021-07-01T23:56:32",  .iso8601WithTimeZone(), expectedDate: expectedDate, expectedLength: expectedLength)
            verify("2021-07-01T235632",    .iso8601WithTimeZone(), expectedDate: expectedDate, expectedLength: expectedLength)
            verify("2021-07-01 23:56:32Z", .iso8601WithTimeZone(), expectedDate: expectedDate, expectedLength: expectedLength)
            
            let expectedDateComponents : DateComponents? = nil
            verify("2021-07-01T23:56:32",  .iso8601ComponentsWithTimeZone(), expectedDateComponents: expectedDateComponents, expectedLength: expectedLength)
            verify("2021-07-01T235632",    .iso8601ComponentsWithTimeZone(), expectedDateComponents: expectedDateComponents, expectedLength: expectedLength)
            verify("2021-07-01 23:56:32Z", .iso8601ComponentsWithTimeZone(), expectedDateComponents: expectedDateComponents, expectedLength: expectedLength)
        }
        // This format matches up before the time zone, and creates the date using the specified time zone
        do {
            // dateFormatter.date(from: "2021-07-01 23:56:32")!
            let expectedDate = Date(timeIntervalSinceReferenceDate: 646876592.0)
            let expectedLength = "2021-07-01T23:56:32".count
            verify("2021-07-01T23:56:32",       .iso8601(timeZone: gmt), expectedDate: expectedDate, expectedLength: expectedLength)
            verify("2021-07-01T23:56:32Z",      .iso8601(timeZone: gmt), expectedDate: expectedDate, expectedLength: expectedLength)
            verify("2021-07-01T15:56:32Z",      .iso8601(timeZone: pst), expectedDate: expectedDate, expectedLength: expectedLength)
            verify("2021-07-01T15:56:32+00",    .iso8601(timeZone: pst), expectedDate: expectedDate, expectedLength: expectedLength)
            verify("2021-07-01T15:56:32+0000",  .iso8601(timeZone: pst), expectedDate: expectedDate, expectedLength: expectedLength)
            verify("2021-07-01T15:56:32+00:00", .iso8601(timeZone: pst), expectedDate: expectedDate, expectedLength: expectedLength)
            
            let expectedDateComponentsGMT = DateComponents(timeZone: gmt, year: 2021, month: 7, day: 1, hour: 23, minute: 56, second: 32)
            verify("2021-07-01T23:56:32",       .iso8601Components(timeZone: gmt), expectedDateComponents: expectedDateComponentsGMT, expectedLength: expectedLength)
            verify("2021-07-01T23:56:32Z",      .iso8601Components(timeZone: gmt), expectedDateComponents: expectedDateComponentsGMT, expectedLength: expectedLength)
            
            let expectedDateComponentsPST = DateComponents(timeZone: pst, year: 2021, month: 7, day: 1, hour: 15, minute: 56, second: 32)
            verify("2021-07-01T15:56:32Z",      .iso8601Components(timeZone: pst), expectedDateComponents: expectedDateComponentsPST, expectedLength: expectedLength)
            verify("2021-07-01T15:56:32+00",    .iso8601Components(timeZone: pst), expectedDateComponents: expectedDateComponentsPST, expectedLength: expectedLength)
            verify("2021-07-01T15:56:32+0000",  .iso8601Components(timeZone: pst), expectedDateComponents: expectedDateComponentsPST, expectedLength: expectedLength)
            verify("2021-07-01T15:56:32+00:00", .iso8601Components(timeZone: pst), expectedDateComponents: expectedDateComponentsPST, expectedLength: expectedLength)
        }

        do {
            let expectedLength = "2021-07-01T23:56:32.34567".count
            // fractionalDateFormatter.date(from: "2021-07-01 23:56:32.34567")!
            let expectedDate = Date(timeIntervalSinceReferenceDate: 646876592.345)
            verify("2021-07-01T23:56:32.34567", .iso8601(timeZone: gmt, includingFractionalSeconds: true), expectedDate: expectedDate, expectedLength: expectedLength)
            verify("2021-07-01T23:56:32.34567Z", .iso8601(timeZone: gmt, includingFractionalSeconds: true), expectedDate: expectedDate, expectedLength: expectedLength)
            
            let expectedDateComponents = DateComponents(timeZone: gmt, year: 2021, month: 7, day: 1, hour: 23, minute: 56, second: 32)
            verify("2021-07-01T23:56:32.34567", .iso8601Components(timeZone: gmt, includingFractionalSeconds: true), expectedDateComponents: expectedDateComponents, expectedLength: expectedLength)
            verify("2021-07-01T23:56:32.34567Z", .iso8601Components(timeZone: gmt, includingFractionalSeconds: true), expectedDateComponents: expectedDateComponents, expectedLength: expectedLength)
        }

        do {
            let expectedLength = "20210701T235632".count
            // dateFormatter.date(from: "2021-07-01 23:56:32")!
            let expectedDate = Date(timeIntervalSinceReferenceDate: 646876592.0)
            verify("20210701T235632", .iso8601(timeZone: gmt, dateSeparator: .omitted, timeSeparator: .omitted), expectedDate: expectedDate, expectedLength: expectedLength)
            verify("20210701 235632", .iso8601(timeZone: gmt, dateSeparator: .omitted, dateTimeSeparator: .space, timeSeparator: .omitted), expectedDate: expectedDate, expectedLength: expectedLength)
            
            let expectedDateComponents = DateComponents(timeZone: gmt, year: 2021, month: 7, day: 1, hour: 23, minute: 56, second: 32)
            verify("20210701T235632", .iso8601Components(timeZone: gmt, dateSeparator: .omitted, timeSeparator: .omitted), expectedDateComponents: expectedDateComponents, expectedLength: expectedLength)
            verify("20210701 235632", .iso8601Components(timeZone: gmt, dateSeparator: .omitted, dateTimeSeparator: .space, timeSeparator: .omitted), expectedDateComponents: expectedDateComponents, expectedLength: expectedLength)
        }

        // This format matches the date part only, and creates the date using the specified time zone
        do {
            // dateFormatter.date(from: "2021-07-01 00:00:00")!
            let expectedDate = Date(timeIntervalSinceReferenceDate: 646790400.0)
            let expectedLength = "2021-07-01".count
            let expectedDateComponents = DateComponents(timeZone: gmt, year: 2021, month: 7, day: 1)

            verify("2021-07-01",                .iso8601Date(timeZone: gmt), expectedDate: expectedDate, expectedLength: expectedLength)
            verify("2021-07-01T15:56:32+08:00", .iso8601Date(timeZone: gmt), expectedDate: expectedDate, expectedLength: expectedLength)
            verify("2021-07-01 15:56:32+08:00", .iso8601Date(timeZone: gmt), expectedDate: expectedDate, expectedLength: expectedLength)
            verify("2021-07-01 i love summer",  .iso8601Date(timeZone: gmt), expectedDate: expectedDate, expectedLength: expectedLength)
            
            verify("2021-07-01",                .iso8601DateComponents(timeZone: gmt), expectedDateComponents: expectedDateComponents, expectedLength: expectedLength)
            verify("2021-07-01T15:56:32+08:00", .iso8601DateComponents(timeZone: gmt), expectedDateComponents: expectedDateComponents, expectedLength: expectedLength)
            verify("2021-07-01 15:56:32+08:00", .iso8601DateComponents(timeZone: gmt), expectedDateComponents: expectedDateComponents, expectedLength: expectedLength)
            verify("2021-07-01 i love summer",  .iso8601DateComponents(timeZone: gmt), expectedDateComponents: expectedDateComponents, expectedLength: expectedLength)
        }

        do {
            // dateFormatter.date(from: "2021-07-01 00:00:00")!
            let expectedDate = Date(timeIntervalSinceReferenceDate: 646790400.0)
            let expectedLength = "20210701".count
            let expectedDateComponents = DateComponents(timeZone: gmt, year: 2021, month: 7, day: 1)
            verify("20210701",             .iso8601Date(timeZone: gmt, dateSeparator: .omitted), expectedDate: expectedDate, expectedLength: expectedLength)
            verify("20210701T155632+0800", .iso8601Date(timeZone: gmt, dateSeparator: .omitted), expectedDate: expectedDate, expectedLength: expectedLength)
            verify("20210701 155632+0800", .iso8601Date(timeZone: gmt, dateSeparator: .omitted), expectedDate: expectedDate, expectedLength: expectedLength)
            
            verify("20210701",             .iso8601DateComponents(timeZone: gmt, dateSeparator: .omitted), expectedDateComponents: expectedDateComponents, expectedLength: expectedLength)
            verify("20210701T155632+0800", .iso8601DateComponents(timeZone: gmt, dateSeparator: .omitted), expectedDateComponents: expectedDateComponents, expectedLength: expectedLength)
            verify("20210701 155632+0800", .iso8601DateComponents(timeZone: gmt, dateSeparator: .omitted), expectedDateComponents: expectedDateComponents, expectedLength: expectedLength)
        }
    }

    func testFullMatch() {

        func verify(_ str: String, _ style: Date.ISO8601FormatStyle, expectedDate: Date, file: StaticString = #filePath, line: UInt = #line) {
            _matchFullRange(str, formatStyle: style, expectedUpperBound: str.endIndex, expectedDate: expectedDate, file: file, line: line)
        }

        func verify(_ str: String, _ style: DateComponents.ISO8601FormatStyle, expectedDateComponents: DateComponents, file: StaticString = #filePath, line: UInt = #line) {
            _matchFullRange(str, formatStyle: style, expectedUpperBound: str.endIndex, expectedDateComponents: expectedDateComponents, file: file, line: line)
        }

        do {
            // dateFormatter.date(from: "2021-07-01 23:56:32")!
            let expectedDate = Date(timeIntervalSinceReferenceDate: 646876592.0)
            let expectedDateComponentsGMT = DateComponents(timeZone: .gmt, year: 2021, month: 7, day: 1, hour: 23, minute: 56, second: 32)
            verify("2021-07-01T23:56:32Z", .iso8601WithTimeZone(), expectedDate: expectedDate)
            verify("20210701 23:56:32Z", .iso8601WithTimeZone(dateSeparator: .omitted, dateTimeSeparator: .space), expectedDate: expectedDate)
            verify("2021-07-01 15:56:32-0800", .iso8601WithTimeZone(dateTimeSeparator: .space), expectedDate: expectedDate)
            verify("2021-07-01T15:56:32-08:00", .iso8601WithTimeZone(timeZoneSeparator: .colon), expectedDate: expectedDate)
            
            verify("2021-07-01T23:56:32Z", .iso8601ComponentsWithTimeZone(), expectedDateComponents: expectedDateComponentsGMT)
            verify("20210701 23:56:32Z", .iso8601ComponentsWithTimeZone(dateSeparator: .omitted, dateTimeSeparator: .space), expectedDateComponents: expectedDateComponentsGMT)
            
            let expectedDateComponentsPST = DateComponents(timeZone: TimeZone(secondsFromGMT: -3600*8)!, year: 2021, month: 7, day: 1, hour: 15, minute: 56, second: 32)

            verify("2021-07-01 15:56:32-0800", .iso8601ComponentsWithTimeZone(dateTimeSeparator: .space), expectedDateComponents: expectedDateComponentsPST)
            verify("2021-07-01T15:56:32-08:00", .iso8601ComponentsWithTimeZone(timeZoneSeparator: .colon), expectedDateComponents: expectedDateComponentsPST)

        }

        do {
            // fractionalDateFormatter.date(from: "2021-07-01 23:56:32.314")!
            let expectedDate = Date(timeIntervalSinceReferenceDate: 646876592.3139999)
            let expectedDateComponents = DateComponents(timeZone: .gmt, year: 2021, month: 7, day: 1, hour: 23, minute: 56, second: 32, nanosecond: 314000000)

            verify("2021-07-01T23:56:32.314Z", .iso8601WithTimeZone(includingFractionalSeconds: true), expectedDate: expectedDate)
            verify("2021-07-01T235632.314Z", .iso8601WithTimeZone(includingFractionalSeconds: true, timeSeparator: .omitted), expectedDate: expectedDate)
            verify("2021-07-01T23:56:32.314000Z", .iso8601WithTimeZone(includingFractionalSeconds: true), expectedDate: expectedDate)
            
            verify("2021-07-01T23:56:32.314Z", .iso8601ComponentsWithTimeZone(includingFractionalSeconds: true), expectedDateComponents: expectedDateComponents)
            verify("2021-07-01T235632.314Z", .iso8601ComponentsWithTimeZone(includingFractionalSeconds: true, timeSeparator: .omitted), expectedDateComponents: expectedDateComponents)
            verify("2021-07-01T23:56:32.314000Z", .iso8601ComponentsWithTimeZone(includingFractionalSeconds: true), expectedDateComponents: expectedDateComponents)
        }
    }
}
