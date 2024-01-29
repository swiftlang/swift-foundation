//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
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

/// The majority of the tests for this are in the FoundationInternationalizationTests suite, but we have a small number here to verify that ISO8601 formatting is functional without ICU present. No parsing is present in the essentials library (yet?).
@available(OSX 12.0, *)
final class DateISO8601FormatStyleEssentialsTests: XCTestCase {

    func test_ISO8601Format() throws {
        let date = Date(timeIntervalSinceReferenceDate: 665076946.0)

        func verify(_ formatStyle: Date.ISO8601FormatStyle, expectedString: String, expectedParsedDate: Date?, file: StaticString = #file, line: UInt = #line) {
            let formatted = formatStyle.format(date)
            XCTAssertEqual(formatted, expectedString, file: file, line: line)
        }

        let iso8601 = Date.ISO8601FormatStyle()

        // Date is: "2022-01-28 15:35:46"
        verify(iso8601, expectedString: "2022-01-28T15:35:46Z", expectedParsedDate: Date(timeIntervalSinceReferenceDate: 665076946.0))

        // Day-only results: the default time is midnight for parsed date when the time piece is missing
        // Date is: "2022-01-28 00:00:00"
        verify(iso8601.year().month().day().dateSeparator(.dash), expectedString: "2022-01-28", expectedParsedDate: Date(timeIntervalSinceReferenceDate: 665020800.0))
        // Date is: "2022-01-28 00:00:00"
        verify(iso8601.year().month().day().dateSeparator(.omitted), expectedString: "20220128", expectedParsedDate: Date(timeIntervalSinceReferenceDate: 665020800.0))

        // Time-only results: we use the default date of the format style, 1970-01-01, to supplement the parsed date without year, month or day
        // Date is: "1970-01-23 00:00:00"
        verify(iso8601.weekOfYear().day().dateSeparator(.dash), expectedString: "W04-05", expectedParsedDate: Date(timeIntervalSinceReferenceDate: -976406400.0))
        // Date is: "1970-01-28 15:35:46"
        verify(iso8601.day().time(includingFractionalSeconds: false).timeSeparator(.colon), expectedString: "028T15:35:46", expectedParsedDate: Date(timeIntervalSinceReferenceDate: -975918254.0))
        // Date is: "1970-01-01 15:35:46"
        verify(iso8601.time(includingFractionalSeconds: false).timeSeparator(.colon), expectedString: "15:35:46", expectedParsedDate: Date(timeIntervalSinceReferenceDate: -978251054.0))
        // Date is: "1970-01-01 15:35:46"
        verify(iso8601.time(includingFractionalSeconds: false).timeZone(separator: .omitted), expectedString: "15:35:46Z", expectedParsedDate: Date(timeIntervalSinceReferenceDate: -978251054.0))
        // Date is: "1970-01-01 15:35:46"
        verify(iso8601.time(includingFractionalSeconds: false).timeZone(separator: .colon), expectedString: "15:35:46Z", expectedParsedDate: Date(timeIntervalSinceReferenceDate: -978251054.0))
        // Date is: "1970-01-01 15:35:46"
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
