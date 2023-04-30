// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// RUN: %target-run-simple-swift
// REQUIRES: executable_test
// REQUIRES: objc_interop

#if canImport(TestSupport)
import TestSupport
#endif

@available(OSX 12.0, *)
final class DateISO8601FormatStyleTests: XCTestCase {

    func test_ISO8601Format() throws {
        // dateFormatter.date(from: "2022-01-28 15:35:46")!
        let date = Date(timeIntervalSinceReferenceDate: 665076946.0)

        func verify(_ formatStyle: Date.ISO8601FormatStyle, expectedString: String, expectedParsedDate: Date?, file: StaticString = #file, line: UInt = #line) {
            let formatted = formatStyle.format(date)
            XCTAssertEqual(formatted, expectedString, file: file, line: line)
            XCTAssertEqual(try? Date(formatted, strategy: formatStyle), expectedParsedDate, file: file, line: line)
        }

        let iso8601 = Date.ISO8601FormatStyle()

        // dateFormatter.date(from: "2022-01-28 15:35:46")
        verify(iso8601, expectedString: "2022-01-28T15:35:46Z", expectedParsedDate: Date(timeIntervalSinceReferenceDate: 665076946.0))

        // Day-only results: the default time is midnight for parsed date when the time piece is missing
        // dateFormatter.date(from: "2022-01-28 00:00:00")
        verify(iso8601.year().month().day().dateSeparator(.dash), expectedString: "2022-01-28", expectedParsedDate: Date(timeIntervalSinceReferenceDate: 665020800.0))
        // dateFormatter.date(from: "2022-01-28 00:00:00")
        verify(iso8601.year().month().day().dateSeparator(.omitted), expectedString: "20220128", expectedParsedDate: Date(timeIntervalSinceReferenceDate: 665020800.0))

        // Time-only results: we use the default date of the format style, 1970-01-01, to supplement the parsed date without year, month or day
        // dateFormatter.date(from: "1970-01-23 00:00:00")
        verify(iso8601.weekOfYear().day().dateSeparator(.dash), expectedString: "W04-05", expectedParsedDate: Date(timeIntervalSinceReferenceDate: -976406400.0))
        // dateFormatter.date(from: "1970-01-28 15:35:46")
        verify(iso8601.day().time(includingFractionalSeconds: false).timeSeparator(.colon), expectedString: "028T15:35:46", expectedParsedDate: Date(timeIntervalSinceReferenceDate: -975918254.0))
        // dateFormatter.date(from: "1970-01-01 15:35:46")
        verify(iso8601.time(includingFractionalSeconds: false).timeSeparator(.colon), expectedString: "15:35:46", expectedParsedDate: Date(timeIntervalSinceReferenceDate: -978251054.0))
        // dateFormatter.date(from: "1970-01-01 15:35:46")
        verify(iso8601.time(includingFractionalSeconds: false).timeZone(separator: .omitted), expectedString: "15:35:46Z", expectedParsedDate: Date(timeIntervalSinceReferenceDate: -978251054.0))
        // dateFormatter.date(from: "1970-01-01 15:35:46")
        verify(iso8601.time(includingFractionalSeconds: false).timeZone(separator: .colon), expectedString: "15:35:46Z", expectedParsedDate: Date(timeIntervalSinceReferenceDate: -978251054.0))
        // dateFormatter.date(from: "1970-01-01 15:35:46")
        verify(iso8601.timeZone(separator: .colon).time(includingFractionalSeconds: false).timeSeparator(.colon), expectedString: "15:35:46Z", expectedParsedDate: Date(timeIntervalSinceReferenceDate: -978251054.0))
    }

    func test_codable() {
        let iso8601Style = Date.ISO8601FormatStyle().year().month().day()
        let encoder = JSONEncoder()
        let encodedStyle = try! encoder.encode(iso8601Style)
        let decoder = JSONDecoder()
        let decodedStyle = try? decoder.decode(Date.ISO8601FormatStyle.self, from: encodedStyle)
        XCTAssertNotNil(decodedStyle)
    }

    func testLeadingDotSyntax() {
        let _ = Date().formatted(.iso8601)
    }

    func test_ISO8601FormatWithDate() throws {
        // dateFormatter.date(from: "2021-07-01 15:56:32")!
        let date = Date(timeIntervalSinceReferenceDate: 646847792.0) // Thursday
        XCTAssertEqual(date.formatted(.iso8601), "2021-07-01T15:56:32Z")
        XCTAssertEqual(date.formatted(.iso8601.dateSeparator(.omitted)), "20210701T15:56:32Z")
        XCTAssertEqual(date.formatted(.iso8601.dateTimeSeparator(.space)), "2021-07-01 15:56:32Z")
        XCTAssertEqual(date.formatted(.iso8601.timeSeparator(.omitted)), "2021-07-01T155632Z")
        XCTAssertEqual(date.formatted(.iso8601.dateSeparator(.omitted).timeSeparator(.omitted)), "20210701T155632Z")
        XCTAssertEqual(date.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false).timeZone(separator: .omitted)), "2021-07-01T15:56:32Z")
        XCTAssertEqual(date.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: true).timeZone(separator: .omitted).dateSeparator(.dash).dateTimeSeparator(.standard).timeSeparator(.colon)), "2021-07-01T15:56:32.000Z")

        XCTAssertEqual(date.formatted(.iso8601.year()), "2021")
        XCTAssertEqual(date.formatted(.iso8601.year().month()), "2021-07")
        XCTAssertEqual(date.formatted(.iso8601.year().month().day()), "2021-07-01")
        XCTAssertEqual(date.formatted(.iso8601.year().month().day().dateSeparator(.omitted)), "20210701")

        XCTAssertEqual(date.formatted(.iso8601.year().weekOfYear()), "2021-W26")
        XCTAssertEqual(date.formatted(.iso8601.year().weekOfYear().day()), "2021-W26-04") // day() is the weekday number
        XCTAssertEqual(date.formatted(.iso8601.year().day()), "2021-182") // day() is the ordinal day

        XCTAssertEqual(date.formatted(.iso8601.time(includingFractionalSeconds: false)), "15:56:32")
        XCTAssertEqual(date.formatted(.iso8601.time(includingFractionalSeconds: true)), "15:56:32.000")
        XCTAssertEqual(date.formatted(.iso8601.time(includingFractionalSeconds: false).timeZone(separator: .omitted)), "15:56:32Z")
    }

}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
final class DateISO8601FormatStylePatternMatchingTests : XCTestCase {

    func _matchFullRange(_ str: String, formatStyle: Date.ISO8601FormatStyle, expectedUpperBound: String.Index?, expectedDate: Date?, file: StaticString = #file, line: UInt = #line) {
        _matchRange(str, formatStyle: formatStyle, range: nil, expectedUpperBound: expectedUpperBound, expectedDate: expectedDate, file: file, line: line)
    }

    func _matchRange(_ str: String, formatStyle: Date.ISO8601FormatStyle, range: Range<String.Index>?, expectedUpperBound: String.Index?, expectedDate: Date?, file: StaticString = #file, line: UInt = #line) {
        // FIXME: Need tests that starts from somewhere else
        let m = try? formatStyle.consuming(str, startingAt: str.startIndex, in: range ?? str.startIndex..<str.endIndex)
        let upperBound = m?.upperBound
        let match = m?.output

        let upperBoundDescription = upperBound?.utf16Offset(in: str)
        let expectedUpperBoundDescription = expectedUpperBound?.utf16Offset(in: str)
        XCTAssertEqual(upperBound, expectedUpperBound, "found upperBound: \(String(describing: upperBoundDescription)); expected: \(String(describing: expectedUpperBoundDescription))", file: file, line: line)
        XCTAssertEqual(match, expectedDate, file: file, line: line)
    }

    func testMatchDefaultISO8601Style() throws {

        let iso8601FormatStyle = Date.ISO8601FormatStyle()
        func verify(_ str: String, expectedUpperBound: String.Index?, expectedDate: Date?, file: StaticString = #file, line: UInt = #line) {
            _matchFullRange(str, formatStyle: iso8601FormatStyle, expectedUpperBound: expectedUpperBound, expectedDate: expectedDate, file: file, line: line)
        }

        // dateFormatter.date(from: "2021-07-01 15:56:32")!
        let expectedDate = Date(timeIntervalSinceReferenceDate: 646847792.0)

        let str = "2021-07-01T15:56:32Z"
        verify(str, expectedUpperBound: str.endIndex, expectedDate: expectedDate)
        verify("\(str) text", expectedUpperBound: str.endIndex, expectedDate: expectedDate)

        verify("some \(str)", expectedUpperBound: nil, expectedDate: nil) // We can't find a matched date because the matching starts at the first character
        verify("9999-37-40T35:70:99Z", expectedUpperBound: nil, expectedDate: nil) // This is not a valid date
    }

    func testPartialMatchISO8601() throws {
        var expectedDate: Date?
        var expectedLength: Int?
        func verify(_ str: String, _ style: Date.ISO8601FormatStyle,  file: StaticString = #file, line: UInt = #line) {
            let expectedUpperBoundStrIndx = (expectedLength != nil) ? str.index(str.startIndex, offsetBy: expectedLength!) : nil
            _matchFullRange(str, formatStyle: style, expectedUpperBound: expectedUpperBoundStrIndx, expectedDate: expectedDate, file: file, line: line)
        }

        let gmt = TimeZone(secondsFromGMT: 0)!
        let pst = TimeZone(secondsFromGMT: -3600*8)!

        // dateFormatter.date(from: "2021-07-01 23:56:32")!
        expectedDate = Date(timeIntervalSinceReferenceDate: 646876592.0)
        expectedLength = "2021-07-01T23:56:32Z".count

        // This format requires a time zone
        do {
            expectedDate = nil
            expectedLength = nil
            verify("2021-07-01T23:56:32",  .iso8601WithTimeZone())
            verify("2021-07-01T235632",    .iso8601WithTimeZone())
            verify("2021-07-01 23:56:32Z", .iso8601WithTimeZone())
        }
        // This format matches up before the time zone, and creates the date using the specified time zone
        do {
            // dateFormatter.date(from: "2021-07-01 23:56:32")!
            expectedDate = Date(timeIntervalSinceReferenceDate: 646876592.0)
            expectedLength = "2021-07-01T23:56:32".count
            verify("2021-07-01T23:56:32",       .iso8601(timeZone: gmt))
            verify("2021-07-01T23:56:32Z",      .iso8601(timeZone: gmt))
            verify("2021-07-01T15:56:32Z",      .iso8601(timeZone: pst))
            verify("2021-07-01T15:56:32+0000",  .iso8601(timeZone: pst))
            verify("2021-07-01T15:56:32+00:00", .iso8601(timeZone: pst))
        }

        do {
            expectedLength = "2021-07-01T23:56:32.34567".count
            // fractionalDateFormatter.date(from: "2021-07-01 23:56:32.34567")!
            expectedDate = Date(timeIntervalSinceReferenceDate: 646876592.345)
            verify("2021-07-01T23:56:32.34567", .iso8601(timeZone: gmt, includingFractionalSeconds: true))
            verify("2021-07-01T23:56:32.34567Z", .iso8601(timeZone: gmt, includingFractionalSeconds: true))
        }

        do {
            expectedLength = "20210701T235632".count
            // dateFormatter.date(from: "2021-07-01 23:56:32")!
            expectedDate = Date(timeIntervalSinceReferenceDate: 646876592.0)
            verify("20210701T235632", .iso8601(timeZone: gmt, dateSeparator: .omitted, timeSeparator: .omitted))
            verify("20210701 235632", .iso8601(timeZone: gmt, dateSeparator: .omitted, dateTimeSeparator: .space, timeSeparator: .omitted))
        }

        // This format matches the date part only, and creates the date using the specified time zone
        do {
            // dateFormatter.date(from: "2021-07-01 00:00:00")!
            expectedDate = Date(timeIntervalSinceReferenceDate: 646790400.0)
            expectedLength = "2021-07-01".count
            verify("2021-07-01",                .iso8601Date(timeZone: gmt))
            verify("2021-07-01T15:56:32+08:00", .iso8601Date(timeZone: gmt))
            verify("2021-07-01 15:56:32+08:00", .iso8601Date(timeZone: gmt))
            verify("2021-07-01 i love summer",  .iso8601Date(timeZone: gmt))
        }

        do {
            // dateFormatter.date(from: "2021-07-01 00:00:00")!
            expectedDate = Date(timeIntervalSinceReferenceDate: 646790400.0)
            expectedLength = "20210701".count
            verify("20210701",             .iso8601Date(timeZone: gmt, dateSeparator: .omitted))
            verify("20210701T155632+0800", .iso8601Date(timeZone: gmt, dateSeparator: .omitted))
            verify("20210701 155632+0800", .iso8601Date(timeZone: gmt, dateSeparator: .omitted))
        }
    }

    func testFullMatch() {

        var expectedDate: Date
        func verify(_ str: String, _ style: Date.ISO8601FormatStyle, file: StaticString = #file, line: UInt = #line) {
            _matchFullRange(str, formatStyle: style, expectedUpperBound: str.endIndex, expectedDate: expectedDate, file: file, line: line)
        }

        do {
            // dateFormatter.date(from: "2021-07-01 23:56:32")!
            expectedDate = Date(timeIntervalSinceReferenceDate: 646876592.0)
            verify("2021-07-01T23:56:32Z", .iso8601WithTimeZone())
            verify("20210701 23:56:32Z", .iso8601WithTimeZone(dateSeparator: .omitted, dateTimeSeparator: .space))
            verify("2021-07-01 15:56:32-0800", .iso8601WithTimeZone(dateTimeSeparator: .space))
            verify("2021-07-01T15:56:32-08:00", .iso8601WithTimeZone())
        }

        do {
            // fractionalDateFormatter.date(from: "2021-07-01 23:56:32.314")!
            expectedDate = Date(timeIntervalSinceReferenceDate: 646876592.3139999)
            verify("2021-07-01T23:56:32.314Z", .iso8601WithTimeZone(includingFractionalSeconds: true))
            verify("2021-07-01T235632.314Z", .iso8601WithTimeZone(includingFractionalSeconds: true, timeSeparator: .omitted))
            verify("2021-07-01T23:56:32.314000Z", .iso8601WithTimeZone(includingFractionalSeconds: true))
        }
    }
}
