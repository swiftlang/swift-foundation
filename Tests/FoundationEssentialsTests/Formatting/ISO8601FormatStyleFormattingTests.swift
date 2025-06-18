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

import Testing

#if canImport(FoundationEssentials)
@testable import FoundationEssentials
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#endif

@Suite("ISO8601FormatStyle Formatting")
private struct ISO8601FormatStyleFormattingTests {

    @Test func iso8601Format() throws {
        let date = Date(timeIntervalSinceReferenceDate: 665076946.0)
        let fractionalSecondsDate = Date(timeIntervalSinceReferenceDate: 665076946.011)
        let iso8601 = Date.ISO8601FormatStyle()

        // Date is: "2022-01-28 15:35:46"
        #expect(iso8601.format(date) == "2022-01-28T15:35:46Z")

        #expect(iso8601.time(includingFractionalSeconds: true).format(fractionalSecondsDate) == "15:35:46.011")

        #expect(iso8601.year().month().day().time(includingFractionalSeconds: true).format(fractionalSecondsDate) == "2022-01-28T15:35:46.011")

        // Day-only results: the default time is midnight for parsed date when the time piece is missing
        // Date is: "2022-01-28 00:00:00"
        #expect(iso8601.year().month().day().dateSeparator(.dash).format(date) == "2022-01-28")
        
        // Date is: "2022-01-28 00:00:00"
        #expect(iso8601.year().month().day().dateSeparator(.omitted).format(date) == "20220128")

        // Time-only results: we use the default date of the format style, 1970-01-01, to supplement the parsed date without year, month or day
        // Date is: "1970-01-23 00:00:00"
        #expect(iso8601.weekOfYear().day().dateSeparator(.dash).format(date) == "W04-05")

        // Date is: "1970-01-28 15:35:46"
        #expect(iso8601.day().time(includingFractionalSeconds: false).timeSeparator(.colon).format(date) == "028T15:35:46")
        // Date is: "1970-01-01 15:35:46"
        #expect(iso8601.time(includingFractionalSeconds: false).timeSeparator(.colon).format(date) == "15:35:46")
        // Date is: "1970-01-01 15:35:46"
        #expect(iso8601.time(includingFractionalSeconds: false).timeZone(separator: .omitted).format(date) == "15:35:46Z")
        // Date is: "1970-01-01 15:35:46"
        #expect(iso8601.time(includingFractionalSeconds: false).timeZone(separator: .colon).format(date) == "15:35:46Z")
        // Date is: "1970-01-01 15:35:46"
        #expect(iso8601.timeZone(separator: .colon).time(includingFractionalSeconds: false).timeSeparator(.colon).format(date) == "15:35:46Z")
                
        // Time zones
        
        var iso8601Pacific = iso8601
        iso8601Pacific.timeZone = TimeZone(secondsFromGMT: -3600 * 8)!
        
        // Has a seconds component (-28830)
        var iso8601PacificIsh = iso8601
        iso8601PacificIsh.timeZone = TimeZone(secondsFromGMT: -3600 * 8 - 30)!
        
        #expect(iso8601Pacific.timeSeparator(.omitted).format(date) == "2022-01-28T073546-0800")
        #expect(iso8601Pacific.timeSeparator(.omitted).timeZoneSeparator(.colon).format(date) == "2022-01-28T073546-08:00")

        #expect(iso8601PacificIsh.timeSeparator(.omitted).format(date) == "2022-01-28T073516-080030")
        #expect(iso8601PacificIsh.timeSeparator(.omitted).timeZoneSeparator(.colon).format(date) == "2022-01-28T073516-08:00:30")
        
        var iso8601gmtP1 = iso8601
        iso8601gmtP1.timeZone = TimeZone(secondsFromGMT: 3600)!
        #expect(iso8601gmtP1.timeSeparator(.omitted).format(date) == "2022-01-28T163546+0100")
        #expect(iso8601gmtP1.timeSeparator(.omitted).timeZoneSeparator(.colon).format(date) == "2022-01-28T163546+01:00")
        
    }

    @Test func iso8601ComponentsFormatMissingPieces() throws {
        // Example code from the proposal
        let components = DateComponents(year: 1999, month: 12, day: 31)
        let formatted = components.formatted(.iso8601)
        #expect(formatted == "1999-12-31T00:00:00Z")


        let emptyComponents = DateComponents()
        let emptyFormatted = emptyComponents.formatted(.iso8601)
        #expect(emptyFormatted == "1970-01-01T00:00:00Z")
    }
    
    @Test func iso8601ComponentsFormat() throws {
        let date = Date(timeIntervalSinceReferenceDate: 665076946.0)
        // Be sure to use the ISO8601 calendar here to decompose to the right week of year components (the starting day is not the same as gregorian)
        let componentsInGMT = Calendar(identifier: .iso8601).dateComponents(in: .gmt, from: date)
        let fractionalSecondsDate = Date(timeIntervalSinceReferenceDate: 665076946.011)
        let fractionalSecondsComponents = Calendar(identifier: .iso8601).dateComponents(in: .gmt, from: fractionalSecondsDate)
        let iso8601 = DateComponents.ISO8601FormatStyle()

        // Date is: "2022-01-28 15:35:46"
        #expect(iso8601.format(componentsInGMT) == "2022-01-28T15:35:46Z")

        #expect(iso8601.time(includingFractionalSeconds: true).format(fractionalSecondsComponents) == "15:35:46.011")

        #expect(iso8601.year().month().day().time(includingFractionalSeconds: true).format(fractionalSecondsComponents) == "2022-01-28T15:35:46.011")

        // Day-only results: the default time is midnight for parsed date when the time piece is missing
        // Date is: "2022-01-28 00:00:00"
        #expect(iso8601.year().month().day().dateSeparator(.dash).format(componentsInGMT) == "2022-01-28")
        
        // Date is: "2022-01-28 00:00:00"
        #expect(iso8601.year().month().day().dateSeparator(.omitted).format(componentsInGMT) == "20220128")

        // Time-only results: we use the default date of the format style, 1970-01-01, to supplement the parsed date without year, month or day
        // Date is: "1970-01-23 00:00:00"
        #expect(iso8601.weekOfYear().day().dateSeparator(.dash).format(componentsInGMT) == "W04-05")

        // Date is: "1970-01-28 15:35:46"
        #expect(iso8601.day().time(includingFractionalSeconds: false).timeSeparator(.colon).format(componentsInGMT) == "028T15:35:46")
        // Date is: "1970-01-01 15:35:46"
        #expect(iso8601.time(includingFractionalSeconds: false).timeSeparator(.colon).format(componentsInGMT) == "15:35:46")
        // Date is: "1970-01-01 15:35:46"
        #expect(iso8601.time(includingFractionalSeconds: false).timeZone(separator: .omitted).format(componentsInGMT) == "15:35:46Z")
        // Date is: "1970-01-01 15:35:46"
        #expect(iso8601.time(includingFractionalSeconds: false).timeZone(separator: .colon).format(componentsInGMT) == "15:35:46Z")
        // Date is: "1970-01-01 15:35:46"
        #expect(iso8601.timeZone(separator: .colon).time(includingFractionalSeconds: false).timeSeparator(.colon).format(componentsInGMT) == "15:35:46Z")
                
        // Time zones
        
        var iso8601Pacific = iso8601
        let pacificTimeZone = TimeZone(secondsFromGMT: -3600 * 8)!
        iso8601Pacific.timeZone = pacificTimeZone
        let componentsInPacific = Calendar(identifier: .iso8601).dateComponents(in: pacificTimeZone, from: date)

        #expect(iso8601Pacific.timeSeparator(.omitted).format(componentsInPacific) == "2022-01-28T073546-0800")
        #expect(iso8601Pacific.timeSeparator(.omitted).timeZoneSeparator(.colon).format(componentsInPacific) == "2022-01-28T073546-08:00")

        // Has a seconds component (-28830)
        var iso8601PacificIsh = iso8601
        let pacificIshTimeZone = TimeZone(secondsFromGMT: -3600 * 8 - 30)!
        iso8601PacificIsh.timeZone = pacificIshTimeZone
        let componentsInPacificIsh = Calendar(identifier: .iso8601).dateComponents(in: pacificIshTimeZone, from: date)

        #expect(iso8601PacificIsh.timeSeparator(.omitted).format(componentsInPacificIsh) == "2022-01-28T073516-080030")
        #expect(iso8601PacificIsh.timeSeparator(.omitted).timeZoneSeparator(.colon).format(componentsInPacificIsh) == "2022-01-28T073516-08:00:30")
        
        var iso8601gmtP1 = iso8601
        let gmtP1TimeZone = TimeZone(secondsFromGMT: 3600)!
        iso8601gmtP1.timeZone = gmtP1TimeZone
        let componentsInGMTP1 = Calendar(identifier: .iso8601).dateComponents(in: gmtP1TimeZone, from: date)
        #expect(iso8601gmtP1.timeSeparator(.omitted).format(componentsInGMTP1) == "2022-01-28T163546+0100")
        #expect(iso8601gmtP1.timeSeparator(.omitted).timeZoneSeparator(.colon).format(componentsInGMTP1) == "2022-01-28T163546+01:00")
    }
    
    @Test func codable() throws {
        let iso8601Style = Date.ISO8601FormatStyle().year().month().day()
        let encoder = JSONEncoder()
        let encodedStyle = try encoder.encode(iso8601Style)
        let decoder = JSONDecoder()
        #expect(throws: Never.self) {
            _ = try decoder.decode(Date.ISO8601FormatStyle.self, from: encodedStyle)
        }
    }

    @Test func leadingDotSyntax() {
        let _ = Date().formatted(.iso8601)
    }

    @Test func iso8601FormatWithDate() throws {
        // dateFormatter.date(from: "2021-07-01 15:56:32")!
        let date = Date(timeIntervalSinceReferenceDate: 646847792.0) // Thursday
        #expect(date.formatted(.iso8601) == "2021-07-01T15:56:32Z")
        #expect(date.formatted(.iso8601.dateSeparator(.omitted)) == "20210701T15:56:32Z")
        #expect(date.formatted(.iso8601.dateTimeSeparator(.space)) == "2021-07-01 15:56:32Z")
        #expect(date.formatted(.iso8601.timeSeparator(.omitted)) == "2021-07-01T155632Z")
        #expect(date.formatted(.iso8601.dateSeparator(.omitted).timeSeparator(.omitted)) == "20210701T155632Z")
        #expect(date.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false).timeZone(separator: .omitted)) == "2021-07-01T15:56:32Z")
        #expect(date.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: true).timeZone(separator: .omitted).dateSeparator(.dash).dateTimeSeparator(.standard).timeSeparator(.colon)) == "2021-07-01T15:56:32.000Z")

        #expect(date.formatted(.iso8601.year()) == "2021")
        #expect(date.formatted(.iso8601.year().month()) == "2021-07")
        #expect(date.formatted(.iso8601.year().month().day()) == "2021-07-01")
        #expect(date.formatted(.iso8601.year().month().day().dateSeparator(.omitted)) == "20210701")

        #expect(date.formatted(.iso8601.year().weekOfYear()) == "2021-W26")
        #expect(date.formatted(.iso8601.year().weekOfYear().day()) == "2021-W26-04") // day() is the weekday number
        #expect(date.formatted(.iso8601.year().day()) == "2021-182") // day() is the ordinal day

        #expect(date.formatted(.iso8601.time(includingFractionalSeconds: false)) == "15:56:32")
        #expect(date.formatted(.iso8601.time(includingFractionalSeconds: true)) == "15:56:32.000")
        #expect(date.formatted(.iso8601.time(includingFractionalSeconds: false).timeZone(separator: .omitted)) == "15:56:32Z")
    }

    @Test func remoteDate() throws {
        let date = Date(timeIntervalSince1970: 999999999999.0) // Remote date
        #expect(date.formatted(.iso8601) == "33658-09-27T01:46:39Z")
        #expect(date.formatted(.iso8601.year().weekOfYear().day()) == "33658-W39-05") // day() is the weekday number
    }

    @Test func internal_formatDateComponents() throws {
        let dc = DateComponents(year: -2025, month: 1, day: 20, hour: 0, minute: 0, second: 0)
        let str = Date.ISO8601FormatStyle().format(dc, appendingTimeZoneOffset: 0)
        #expect(str == "-2025-01-20T00:00:00Z")
    }
    
    @Test func rounding() {
        // Date is: "1970-01-01 15:35:45.9999"
        let date = Date(timeIntervalSinceReferenceDate: -978251054.0 - 0.0001)
        let str = Date.ISO8601FormatStyle().timeZone(separator: .colon).time(includingFractionalSeconds: true).timeSeparator(.colon).format(date)
        #expect(str == "15:35:45.999Z")
    }
}
