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

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#endif

final class ISO8601FormatStyleFormattingTests: XCTestCase {

    func test_ISO8601Format() throws {
        let date = Date(timeIntervalSinceReferenceDate: 665076946.0)
        let fractionalSecondsDate = Date(timeIntervalSinceReferenceDate: 665076946.011)
        let iso8601 = Date.ISO8601FormatStyle()

        // Date is: "2022-01-28 15:35:46"
        XCTAssertEqual(iso8601.format(date), "2022-01-28T15:35:46Z")

        XCTAssertEqual(iso8601.time(includingFractionalSeconds: true).format(fractionalSecondsDate), "15:35:46.011")

        XCTAssertEqual(iso8601.year().month().day().time(includingFractionalSeconds: true).format(fractionalSecondsDate), "2022-01-28T15:35:46.011")

        // Day-only results: the default time is midnight for parsed date when the time piece is missing
        // Date is: "2022-01-28 00:00:00"
        XCTAssertEqual(iso8601.year().month().day().dateSeparator(.dash).format(date), "2022-01-28")
        
        // Date is: "2022-01-28 00:00:00"
        XCTAssertEqual(iso8601.year().month().day().dateSeparator(.omitted).format(date), "20220128")

        // Time-only results: we use the default date of the format style, 1970-01-01, to supplement the parsed date without year, month or day
        // Date is: "1970-01-23 00:00:00"
        XCTAssertEqual(iso8601.weekOfYear().day().dateSeparator(.dash).format(date), "W04-05")

        // Date is: "1970-01-28 15:35:46"
        XCTAssertEqual(iso8601.day().time(includingFractionalSeconds: false).timeSeparator(.colon).format(date), "028T15:35:46")
        // Date is: "1970-01-01 15:35:46"
        XCTAssertEqual(iso8601.time(includingFractionalSeconds: false).timeSeparator(.colon).format(date), "15:35:46")
        // Date is: "1970-01-01 15:35:46"
        XCTAssertEqual(iso8601.time(includingFractionalSeconds: false).timeZone(separator: .omitted).format(date), "15:35:46Z")
        // Date is: "1970-01-01 15:35:46"
        XCTAssertEqual(iso8601.time(includingFractionalSeconds: false).timeZone(separator: .colon).format(date), "15:35:46Z")
        // Date is: "1970-01-01 15:35:46"
        XCTAssertEqual(iso8601.timeZone(separator: .colon).time(includingFractionalSeconds: false).timeSeparator(.colon).format(date), "15:35:46Z")
                
        // Time zones
        
        var iso8601Pacific = iso8601
        iso8601Pacific.timeZone = TimeZone(secondsFromGMT: -3600 * 8)!
        
        // Has a seconds component (-28830)
        var iso8601PacificIsh = iso8601
        iso8601PacificIsh.timeZone = TimeZone(secondsFromGMT: -3600 * 8 - 30)!
        
        XCTAssertEqual(iso8601Pacific.timeSeparator(.omitted).format(date), "2022-01-28T073546-0800")
        XCTAssertEqual(iso8601Pacific.timeSeparator(.omitted).timeZoneSeparator(.colon).format(date), "2022-01-28T073546-08:00")

        XCTAssertEqual(iso8601PacificIsh.timeSeparator(.omitted).format(date), "2022-01-28T073516-080030")
        XCTAssertEqual(iso8601PacificIsh.timeSeparator(.omitted).timeZoneSeparator(.colon).format(date), "2022-01-28T073516-08:00:30")
        
        var iso8601gmtP1 = iso8601
        iso8601gmtP1.timeZone = TimeZone(secondsFromGMT: 3600)!
        XCTAssertEqual(iso8601gmtP1.timeSeparator(.omitted).format(date), "2022-01-28T163546+0100")
        XCTAssertEqual(iso8601gmtP1.timeSeparator(.omitted).timeZoneSeparator(.colon).format(date), "2022-01-28T163546+01:00")
        
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

    func test_remoteDate() throws {
        let date = Date(timeIntervalSince1970: 999999999999.0) // Remote date
        XCTAssertEqual(date.formatted(.iso8601), "33658-09-27T01:46:39Z")
        XCTAssertEqual(date.formatted(.iso8601.year().weekOfYear().day()), "33658-W39-05") // day() is the weekday number
    }

    func test_internal_formatDateComponents() throws {
        let dc = DateComponents(year: -2025, month: 1, day: 20, hour: 0, minute: 0, second: 0)
        let str = Date.ISO8601FormatStyle().format(dc, appendingTimeZoneOffset: 0)
        XCTAssertEqual(str, "-2025-01-20T00:00:00Z")
    }
    
    func test_rounding() {
        // Date is: "1970-01-01 15:35:45.9999"
        let date = Date(timeIntervalSinceReferenceDate: -978251054.0 - 0.0001)
        let str = Date.ISO8601FormatStyle().timeZone(separator: .colon).time(includingFractionalSeconds: true).timeSeparator(.colon).format(date)
        XCTAssertEqual(str, "15:35:45.999Z")
    }
}
