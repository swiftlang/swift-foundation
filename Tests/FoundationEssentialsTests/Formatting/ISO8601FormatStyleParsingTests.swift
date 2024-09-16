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
#elseif FOUNDATION_FRAMEWORK
@testable import Foundation
#endif

struct ISO8601FormatStyleParsingTests {

    /// See also the format-only tests in DateISO8601FormatStyleEssentialsTests
    @Test func test_ISO8601Parse() throws {
        let iso8601 = Date.ISO8601FormatStyle()

        // Date is: "2022-01-28 15:35:46"
        #expect(try iso8601.parse("2022-01-28T15:35:46Z") == Date(timeIntervalSinceReferenceDate: 665076946.0))

        var iso8601Pacific = iso8601
        iso8601Pacific.timeZone = TimeZone(secondsFromGMT: -3600 * 8)!
        #expect(try iso8601Pacific.timeSeparator(.omitted).parse("2022-01-28T073546-0800") == Date(timeIntervalSinceReferenceDate: 665076946.0))

        // Day-only results: the default time is midnight for parsed date when the time piece is missing
        // Date is: "2022-01-28 00:00:00"
        #expect(try iso8601.year().month().day().dateSeparator(.dash).parse("2022-01-28") == Date(timeIntervalSinceReferenceDate: 665020800.0))
        // Date is: "2022-01-28 00:00:00"
        #expect(try iso8601.year().month().day().dateSeparator(.omitted).parse("20220128") == Date(timeIntervalSinceReferenceDate: 665020800.0))

        // Time-only results: we use the default date of the format style, 1970-01-01, to supplement the parsed date without year, month or day
        // Date is: "1970-01-23 00:00:00"
        #expect(try iso8601.weekOfYear().day().dateSeparator(.dash).parse("W04-05") == Date(timeIntervalSinceReferenceDate: -976406400.0))
        // Date is: "1970-01-28 15:35:46"
        #expect(try iso8601.day().time(includingFractionalSeconds: false).timeSeparator(.colon).parse("028T15:35:46") == Date(timeIntervalSinceReferenceDate: -975918254.0))
        // Date is: "1970-01-01 15:35:46"
        #expect(try iso8601.time(includingFractionalSeconds: false).timeSeparator(.colon).parse("15:35:46") == Date(timeIntervalSinceReferenceDate: -978251054.0))
        // Date is: "1970-01-01 15:35:46"
        #expect(try iso8601.time(includingFractionalSeconds: false).timeZone(separator: .omitted).parse("15:35:46Z") == Date(timeIntervalSinceReferenceDate: -978251054.0))
        // Date is: "1970-01-01 15:35:46"
        #expect(try iso8601.time(includingFractionalSeconds: false).timeZone(separator: .colon).parse("15:35:46Z") == Date(timeIntervalSinceReferenceDate: -978251054.0))
        // Date is: "1970-01-01 15:35:46"
        #expect(try iso8601.timeZone(separator: .colon).time(includingFractionalSeconds: false).timeSeparator(.colon).parse("15:35:46Z") == Date(timeIntervalSinceReferenceDate: -978251054.0))
    }
    
    @Test func test_weekOfYear() throws {
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
            #expect(parsedWoY == parsedY)
        }
    }
    
    @Test func test_zeroLeadingDigits() throws {
        // The parser allows for an arbitrary number of 0 pads in digits, including none.
        let iso8601 = Date.ISO8601FormatStyle()

        // Date is: "2022-01-28 15:35:46"
        #expect(try iso8601.parse("2022-01-28T15:35:46Z") == Date(timeIntervalSinceReferenceDate: 665076946.0))
        #expect(try iso8601.parse("002022-01-28T15:35:46Z") == Date(timeIntervalSinceReferenceDate: 665076946.0))
        #expect(try iso8601.parse("2022-0001-28T15:35:46Z") == Date(timeIntervalSinceReferenceDate: 665076946.0))
        #expect(try iso8601.parse("2022-01-0028T15:35:46Z") == Date(timeIntervalSinceReferenceDate: 665076946.0))
        #expect(try iso8601.parse("2022-1-28T15:35:46Z") == Date(timeIntervalSinceReferenceDate: 665076946.0))
        #expect(try iso8601.parse("2022-01-28T15:35:06Z") == Date(timeIntervalSinceReferenceDate: 665076906.0))
        #expect(try iso8601.parse("2022-01-28T15:35:6Z") == Date(timeIntervalSinceReferenceDate: 665076906.0))
        #expect(try iso8601.parse("2022-01-28T15:05:46Z") == Date(timeIntervalSinceReferenceDate: 665075146.0))
        #expect(try iso8601.parse("2022-01-28T15:5:46Z") == Date(timeIntervalSinceReferenceDate: 665075146.0))
    }
    
    @Test func test_timeZones() throws {
        let iso8601 = Date.ISO8601FormatStyle()
        let date = Date(timeIntervalSinceReferenceDate: 665076946.0)
        
        var iso8601Pacific = iso8601
        iso8601Pacific.timeZone = TimeZone(secondsFromGMT: -3600 * 8)!
        
        // Has a seconds component (-28830)
        var iso8601PacificIsh = iso8601
        iso8601PacificIsh.timeZone = TimeZone(secondsFromGMT: -3600 * 8 - 30)!
        
        #expect(try iso8601Pacific.timeSeparator(.omitted).parse("2022-01-28T073546-0800") == date)
        #expect(try iso8601Pacific.timeSeparator(.omitted).timeZoneSeparator(.colon).parse("2022-01-28T073546-08:00") == date)

        #expect(try iso8601PacificIsh.timeSeparator(.omitted).parse("2022-01-28T073516-080030") == date)
        #expect(try iso8601PacificIsh.timeSeparator(.omitted).timeZoneSeparator(.colon).parse("2022-01-28T073516-08:00:30") == date)
        
        var iso8601gmtP1 = iso8601
        iso8601gmtP1.timeZone = TimeZone(secondsFromGMT: 3600)!
        #expect(try iso8601gmtP1.timeSeparator(.omitted).parse("2022-01-28T163546+0100") == date)
        #expect(try iso8601gmtP1.timeSeparator(.omitted).parse("2022-01-28T163546+010000") == date)
        #expect(try iso8601gmtP1.timeSeparator(.omitted).timeZoneSeparator(.colon).parse("2022-01-28T163546+01:00") == date)
        #expect(try iso8601gmtP1.timeSeparator(.omitted).timeZoneSeparator(.colon).parse("2022-01-28T163546+01:00:00") == date)

        // Due to a quirk of the original implementation, colons are allowed to be present in the time zone even if the time zone separator is omitted
        #expect(try iso8601gmtP1.timeSeparator(.omitted).parse("2022-01-28T163546+01:00") == date)
        #expect(try iso8601gmtP1.timeSeparator(.omitted).parse("2022-01-28T163546+01:00:00") == date)
    }
    
    @Test func test_fractionalSeconds() throws {
        let expectedDate = Date(timeIntervalSinceReferenceDate: 646876592.34567)
        var iso8601 = Date.ISO8601FormatStyle().year().month().day().time(includingFractionalSeconds: true)
        iso8601.timeZone = .gmt

        #expect(try iso8601.parse("2021-07-01T23:56:32.34567") == expectedDate)
    }
    
    @Test func test_specialTimeZonesAndSpaces() throws {
        let reference = try Date("2020-03-05T12:00:00+00:00", strategy: .iso8601)

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
            let parsed = try style.parse(parseMe)
            #expect(parsed == reference, """

parsing : \(parseMe)
expected: \(reference) \(reference.timeIntervalSinceReferenceDate)
result  : \(parsed.debugDescription) \(parsed.timeIntervalSinceReferenceDate)
""")
        }
    }
}

struct DateISO8601FormatStylePatternMatchingTests {

    func _matchFullRange(_ str: String, formatStyle: Date.ISO8601FormatStyle, expectedUpperBound: String.Index?, expectedDate: Date?, sourceLocation: SourceLocation = #_sourceLocation) {
        _matchRange(str, formatStyle: formatStyle, range: nil, expectedUpperBound: expectedUpperBound, expectedDate: expectedDate, sourceLocation: sourceLocation)
    }

    func _matchRange(_ str: String, formatStyle: Date.ISO8601FormatStyle, range: Range<String.Index>?, expectedUpperBound: String.Index?, expectedDate: Date?, sourceLocation: SourceLocation = #_sourceLocation) {
        // FIXME: Need tests that starts from somewhere else
        let m = try? formatStyle.consuming(str, startingAt: str.startIndex, in: range ?? str.startIndex..<str.endIndex)
        let upperBound = m?.upperBound
        let match = m?.output

        let upperBoundDescription = upperBound?.utf16Offset(in: str)
        let expectedUpperBoundDescription = expectedUpperBound?.utf16Offset(in: str)
        #expect(upperBound == expectedUpperBound, "found upperBound: \(String(describing: upperBoundDescription)); expected: \(String(describing: expectedUpperBoundDescription))", sourceLocation: sourceLocation)
        if let match, let expectedDate {
            #expect(
                abs(match.timeIntervalSinceReferenceDate - expectedDate.timeIntervalSinceReferenceDate) <= 0.001,
                sourceLocation: sourceLocation
            )
        }
    }

    @Test func testMatchDefaultISO8601Style() throws {

        let iso8601FormatStyle = Date.ISO8601FormatStyle()
        func verify(_ str: String, expectedUpperBound: String.Index?, expectedDate: Date?, sourceLocation: SourceLocation = #_sourceLocation) {
            _matchFullRange(str, formatStyle: iso8601FormatStyle, expectedUpperBound: expectedUpperBound, expectedDate: expectedDate, sourceLocation: sourceLocation)
        }

        // dateFormatter.date(from: "2021-07-01 15:56:32")!
        let expectedDate = Date(timeIntervalSinceReferenceDate: 646847792.0)

        let str = "2021-07-01T15:56:32Z"
        verify(str, expectedUpperBound: str.endIndex, expectedDate: expectedDate)
        verify("\(str) text", expectedUpperBound: str.endIndex, expectedDate: expectedDate)

        verify("some \(str)", expectedUpperBound: nil, expectedDate: nil) // We can't find a matched date because the matching starts at the first character
        verify("9999-37-40T35:70:99Z", expectedUpperBound: nil, expectedDate: nil) // This is not a valid date
    }

    @Test func testPartialMatchISO8601() throws {
        var expectedDate: Date?
        var expectedLength: Int?
        func verify(_ str: String, _ style: Date.ISO8601FormatStyle, sourceLocation: SourceLocation = #_sourceLocation) {
            let expectedUpperBoundStrIndx = (expectedLength != nil) ? str.index(str.startIndex, offsetBy: expectedLength!) : nil
            _matchFullRange(str, formatStyle: style, expectedUpperBound: expectedUpperBoundStrIndx, expectedDate: expectedDate, sourceLocation: sourceLocation)
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

    @Test func testFullMatch() {

        var expectedDate: Date
        func verify(_ str: String, _ style: Date.ISO8601FormatStyle, sourceLocation: SourceLocation = #_sourceLocation) {
            _matchFullRange(str, formatStyle: style, expectedUpperBound: str.endIndex, expectedDate: expectedDate, sourceLocation: sourceLocation)
        }

        do {
            // dateFormatter.date(from: "2021-07-01 23:56:32")!
            expectedDate = Date(timeIntervalSinceReferenceDate: 646876592.0)
            verify("2021-07-01T23:56:32Z", .iso8601WithTimeZone())
            verify("20210701 23:56:32Z", .iso8601WithTimeZone(dateSeparator: .omitted, dateTimeSeparator: .space))
            verify("2021-07-01 15:56:32-0800", .iso8601WithTimeZone(dateTimeSeparator: .space))
            verify("2021-07-01T15:56:32-08:00", .iso8601WithTimeZone(timeZoneSeparator: .colon))
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
