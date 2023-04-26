// Copyright (c) 2014 - 2022 Apple Inc. and the Swift project authors
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

import RegexBuilder

#if canImport(TestSupport)
import TestSupport
#endif

final class ParseStrategyMatchTests: XCTestCase {

    let enUS = Locale(identifier: "en_US")
    let enGB = Locale(identifier: "en_GB")
    let gmt = TimeZone(secondsFromGMT: 0)!
    let pst = TimeZone(secondsFromGMT: -3600*8)!

    func testDate() {
        let regex = Regex {
            OneOrMore {
                Capture { Date.ISO8601FormatStyle() }
            }
        }

        guard let res = "💁🏽🏳️‍🌈2021-07-01T15:56:32Z".firstMatch(of: regex) else {
            XCTFail()
            return
        }

        XCTAssertEqual(res.output.0, "2021-07-01T15:56:32Z")
        // dateFormatter.date(from: "2021-07-01 15:56:32.000")!
        XCTAssertEqual(res.output.1, Date(timeIntervalSinceReferenceDate: 646847792.0))
    }

    func testAPIHTTPHeader() {

        let header = """
        HTTP/1.1 301 Redirect
        Date: Wed, 16 Feb 2022 23:53:19 GMT
        Connection: close
        Location: https://www.apple.com/
        Content-Type: text/html
        Content-Language: en
        """

        let regex = Regex {
            Capture {
                .date(format: "\(day: .twoDigits) \(month: .abbreviated) \(year: .padded(4))", locale: Locale(identifier: "en_US"), timeZone: TimeZone(identifier: "GMT")!)
            }
        }

        guard let res = header.firstMatch(of: regex) else {
            XCTFail()
            return
        }

        // dateFormatter.date(from: "2022-02-16 00:00:00.000")!
        let expectedDate = Date(timeIntervalSinceReferenceDate: 666662400.0)
        XCTAssertEqual(res.output.0, "16 Feb 2022")
        XCTAssertEqual(res.output.1, expectedDate)
    }

// https://github.com/apple/swift-foundation/issues/60
#if false
    func testAPIStatement() {

        let statement = """
CREDIT    04/06/2020    Paypal transfer        $4.99
DSLIP    04/06/2020    REMOTE ONLINE DEPOSIT  $3,020.85
CREDIT    04/03/2020    PAYROLL                $69.73
DEBIT    04/02/2020    ACH TRNSFR             ($38.25)
DEBIT    03/31/2020    Payment to BoA card    ($27.44)
DEBIT    03/24/2020    IRX tax payment        ($52,249.98)
"""

        let expectedDateStrings :[Substring] = ["04/06/2020", "04/06/2020", "04/03/2020", "04/02/2020", "03/31/2020", "03/24/2020"]
        let expectedDates = [
            Date(timeIntervalSinceReferenceDate: 607824000.0), // "2020-04-06 00:00:00.000"
            Date(timeIntervalSinceReferenceDate: 607824000.0), // "2020-04-06 00:00:00.000"
            Date(timeIntervalSinceReferenceDate: 607564800.0), // "2020-04-03 00:00:00.000"
            Date(timeIntervalSinceReferenceDate: 607478400.0), // "2020-04-02 00:00:00.000"
            Date(timeIntervalSinceReferenceDate: 607305600.0), // "2020-03-31 00:00:00.000"
            Date(timeIntervalSinceReferenceDate: 606700800.0), // "2020-03-24 00:00:00.000"
        ]
        let expectedAmounts = [Decimal(string:"4.99")!, Decimal(string:"3020.85")!, Decimal(string:"69.73")!, Decimal(string:"-38.25")!, Decimal(string:"-27.44")!, Decimal(string:"-52249.98")!]

        let regex = Regex {
            Capture {
                .localizedCurrency(code: "USD", locale: enUS).sign(strategy: .accounting)
            }
        }


        let money = statement.matches(of: regex)
        XCTAssertEqual(money.map(\.output.0), ["$4.99", "$3,020.85", "$69.73", "($38.25)", "($27.44)", "($52,249.98)"])
        XCTAssertEqual(money.map(\.output.1), expectedAmounts)

        let dateRegex = Regex {
            Capture {
                .date(format:"\(month: .twoDigits)/\(day: .twoDigits)/\(year: .defaultDigits)", locale: enUS, timeZone: gmt)
            }
        }
        let dateMatches = statement.matches(of: dateRegex)
        XCTAssertEqual(dateMatches.map(\.output.0), expectedDateStrings)
        XCTAssertEqual(dateMatches.map(\.output.1), expectedDates)

        let dot = try! Regex(#"."#)
        let dateCurrencyRegex = Regex {
            Capture {
                .date(format:"\(month: .twoDigits)/\(day: .twoDigits)/\(year: .defaultDigits)", locale: enUS, timeZone: gmt)
            }
            "    "
            OneOrMore(dot)
            "  "
            Capture {
                .localizedCurrency(code: "USD", locale: enUS).sign(strategy: .accounting)
            }
        }

        let matches = statement.matches(of: dateCurrencyRegex)
        XCTAssertEqual(matches.map(\.output.0), [
            "04/06/2020    Paypal transfer        $4.99",
            "04/06/2020    REMOTE ONLINE DEPOSIT  $3,020.85",
            "04/03/2020    PAYROLL                $69.73",
            "04/02/2020    ACH TRNSFR             ($38.25)",
            "03/31/2020    Payment to BoA card    ($27.44)",
            "03/24/2020    IRX tax payment        ($52,249.98)",
        ])
        XCTAssertEqual(matches.map(\.output.1), expectedDates)
        XCTAssertEqual(matches.map(\.output.2), expectedAmounts)


        let numericMatches = statement.matches(of: Regex {
            Capture(.date(.numeric, locale: enUS, timeZone: gmt))
        })
        XCTAssertEqual(numericMatches.map(\.output.0), expectedDateStrings)
        XCTAssertEqual(numericMatches.map(\.output.1), expectedDates)
    }

    func testAPIStatements2() {
        // Test dates and numbers appearing in unexpeted places
        let statement = """
CREDIT   Apr 06/20    Zombie 5.29lb@$3.99/lb       USD 21.11
DSLIP    Apr 06/20    GMT gain                     USD 3,020.85
CREDIT   Apr 03/20    PAYROLL 03/29/20-04/02/20    USD 69.73
DEBIT    Apr 02/20    ACH TRNSFR Apr 02/20         -USD 38.25
DEBIT    Mar 31/20    March Payment to BoA         -USD 52,249.98
"""

        let dot = try! Regex(#"."#)
        let dateCurrencyRegex = Regex {
            Capture {
                .date(format:"\(month: .abbreviated) \(day: .twoDigits)/\(year: .twoDigits)", locale: enUS, timeZone: gmt)
            }
            "    "
            Capture(OneOrMore(dot))
            "  "
            Capture {
                .localizedCurrency(code: "USD", locale: enUS).presentation(.isoCode)
            }
        }

        let expectedDates = [
            Date(timeIntervalSinceReferenceDate: 607824000.0), // "2020-04-06 00:00:00.000"
            Date(timeIntervalSinceReferenceDate: 607824000.0), // "2020-04-06 00:00:00.000"
            Date(timeIntervalSinceReferenceDate: 607564800.0), // "2020-04-03 00:00:00.000"
            Date(timeIntervalSinceReferenceDate: 607478400.0), // "2020-04-02 00:00:00.000"
            Date(timeIntervalSinceReferenceDate: 607305600.0), // "2020-03-31 00:00:00.000"
        ]
        let expectedAmounts = [Decimal(string:"21.11")!, Decimal(string:"3020.85")!, Decimal(string:"69.73")!, Decimal(string:"-38.25")!, Decimal(string:"-52249.98")!]

        let matches = statement.matches(of: dateCurrencyRegex)
        XCTAssertEqual(matches.map(\.output.0), [
            "Apr 06/20    Zombie 5.29lb@$3.99/lb       USD 21.11",
            "Apr 06/20    GMT gain                     USD 3,020.85",
            "Apr 03/20    PAYROLL 03/29/20-04/02/20    USD 69.73",
            "Apr 02/20    ACH TRNSFR Apr 02/20         -USD 38.25",
            "Mar 31/20    March Payment to BoA         -USD 52,249.98",
        ])
        XCTAssertEqual(matches.map(\.output.1), expectedDates)
        XCTAssertEqual(matches.map(\.output.3), expectedAmounts)
    }

    func testAPITestSuites() {
        let input = "Test Suite 'MergeableSetTests' started at 2021-07-08 10:19:35.418"

        let testSuiteLog = Regex {
            "Test Suite '"
            Capture(OneOrMore(.any, .reluctant)) // name
            "' "
            TryCapture {
                ChoiceOf {    // status
                    "started"
                    "passed"
                    "failed"
                }
            } transform: {
                String($0)
            }
            " at "
            Capture(.iso8601(timeZone: gmt,
                             includingFractionalSeconds: true,
                             dateTimeSeparator: .space)) // date
            Optionally(".")
        }


        guard let match = input.wholeMatch(of: testSuiteLog) else {
            XCTFail()
            return
        }

        XCTAssertEqual(match.output.0, "Test Suite 'MergeableSetTests' started at 2021-07-08 10:19:35.418")
        XCTAssertEqual(match.output.1, "MergeableSetTests")
        XCTAssertEqual(match.output.2, "started")
        // dateFormatter.date(from: "2021-07-08 10:19:35.418")!
        XCTAssertEqual(match.output.3, Date(timeIntervalSinceReferenceDate: 647432375.418))
    }
#endif

    func testVariousDatesAndTimes() {
        func verify(_ str: String, _ strategy: Date.ParseStrategy, _ expected: String?, file: StaticString = #file, line: UInt = #line) {
            let match = str.wholeMatch(of: strategy) // Regex<Date>.Match?
            if let expected {
                guard let match else {
                    XCTFail("<\(str)> did not match, but it should", file: file, line: line)
                    do {
                        _ = try strategy.parse(str)
                    } catch {
                        print(error)
                    }

                    return
                }
                let expectedDate = try! Date(expected, strategy: .iso8601)
                XCTAssertEqual(match.0, expectedDate, file: file, line: line)
            } else {
                XCTAssertNil(match, "<\(str)> should not match, but it did", file: file, line: line)
            }
        }

        verify("03/05/2020", .date(.numeric, locale: enUS, timeZone: gmt), "2020-03-05T00:00:00+00:00")
        verify("03/05/2020", .date(.numeric, locale: enGB, timeZone: gmt), "2020-05-03T00:00:00+00:00")
#if FIXED_106570987
        verify("03/05/2020, 4:29:24\u{202f}PM", .dateTime(date: .numeric, time: .standard, locale: enUS, timeZone: pst), "2020-03-05T16:29:24-08:00")
#endif
        verify("03/05/2020, 16:29:24", .dateTime(date: .numeric, time: .standard, locale: enGB, timeZone: gmt), "2020-05-03T16:29:24+00:00")
        verify("03/05/2020, 4:29:24 PM", .dateTime(date: .numeric, time: .standard, locale: enGB, timeZone: pst), nil) // en_GB uses 24-hour time, therefore it does not parse "PM"
#if FIXED_106570987
        // Passing in time zone does nothing when the string contains the time zone and matches the style
        verify("03/05/2020, 4:29:24\u{202f}PM PDT", .dateTime(date: .numeric, time: .complete, locale: enUS, timeZone: pst), "2020-03-05T16:29:24-07:00")
#endif
        verify("03/05/2020, 16:29:24 GMT-7", .dateTime(date: .numeric, time: .complete, locale: enGB, timeZone: gmt), "2020-05-03T16:29:24-07:00")

        verify("03_05_2020", .date(format: "\(month: .twoDigits)_\(day: .twoDigits)_\(year: .defaultDigits)", locale: enUS, timeZone: gmt), "2020-03-05T00:00:00+00:00")
        verify("03_05_89", .date(format: "\(month: .twoDigits)_\(day: .twoDigits)_\(year: .twoDigits)", locale: enUS, timeZone: gmt), "1989-03-05T00:00:00+00:00")
        verify("03_05_69", .date(format: "\(month: .twoDigits)_\(day: .twoDigits)_\(year: .twoDigits)", locale: enUS, timeZone: gmt), "2069-03-05T00:00:00+00:00")

        verify("03_05_89", .date(format: "\(month: .twoDigits)_\(day: .twoDigits)_\(year: .twoDigits)", locale: enUS, timeZone: pst), "1989-03-05T00:00:00-08:00")
        // Default two-digit start date is Jan 1st, 1970, 00:00:00 in GMT time zone, which is Dec 31st 1969, so year "69" is 1969 given pst time zone
        verify("03_05", .date(format: "\(month: .twoDigits)_\(day: .twoDigits)", locale: enUS, timeZone: pst), "1969-03-05T00:00:00-08:00")
        verify("03_05_69", .date(format: "\(month: .twoDigits)_\(day: .twoDigits)_\(year: .twoDigits)", locale: enUS, timeZone: pst), "1969-03-05T00:00:00-08:00")

        verify("03/05/2020", .date(.numeric, locale: enUS, timeZone: pst), "2020-03-05T08:00:00+00:00")
        verify("03/05/2020", .date(.numeric, locale: enGB, timeZone: pst), "2020-05-03T00:00:00-08:00")
    }

    func testMatchISO8601String() {
        func verify(_ str: String, _ strategy: Date.ISO8601FormatStyle, _ expected: String?, file: StaticString = #file, line: UInt = #line) {

            let match = str.wholeMatch(of: strategy) // Regex<Date>.Match?
            if let expected {
                guard let match else {
                    var message = ""
                    do {
                        let result = try strategy.consuming(str, startingAt: str.startIndex, in: str.startIndex ..< str.endIndex)
                        if let result {
                            message = "upperBound: \(result.0.utf16Offset(in: str)), output: \(result.1)"
                        } else {
                            message = "no matched result"
                        }
                    } catch {
                        message += "error: \(error)"
                    }

                    XCTFail("<\(str)> did not match, but it should. Information: \(message)", file: file, line: line)
                    return
                }
                let expectedDate = try! Date(expected, strategy: .iso8601)
                XCTAssertEqual(match.0, expectedDate, file: file, line: line)
            } else {
                XCTAssertNil(match, "<\(str)> should not match, but it did", file: file, line: line)
            }
        }

        verify("2020-03-05T16:29:24-08:00", .iso8601, "2020-03-05T16:29:24-08:00")
        verify("2020-03-05T16:29:24Z", .iso8601, "2020-03-05T16:29:24+00:00")
        verify("2020-03-05T16:29:24", .iso8601(timeZone: gmt), "2020-03-05T16:29:24+00:00")
        verify("2020-03-05T16:29:24", .iso8601(timeZone: pst), "2020-03-05T16:29:24-08:00")

        // this function assumes the time zone is missing from the string,
        // therefore it does not fully match a string with time zone
        verify("2020-03-05T16:29:24-08:00", .iso8601(timeZone: gmt), nil)
        verify("2020-03-05T16:29:24", .iso8601(timeZone: pst), "2020-03-05T16:29:24-08:00") // matches when current == pst

        verify("2020-03-05T16:29:24", .iso8601WithTimeZone(), nil) // This function requires time zone to be present in the string, so it doesn't match
        verify("2020-03-05T16:29:24-08:00", .iso8601WithTimeZone(), "2020-03-05T16:29:24-08:00")

        verify("20200305T16:29:24-08:00",   .iso8601WithTimeZone(dateSeparator: .omitted), "2020-03-05T16:29:24-08:00")
        verify("2020-03-05T16:29:24-08:00", .iso8601WithTimeZone(dateSeparator: .omitted), nil) // Does not match "-" in "2020-03-05"

        verify("2020-03-05 16:29:24-08:00", .iso8601WithTimeZone(dateTimeSeparator: .space),    "2020-03-05T16:29:24-08:00")
        verify("2020-03-05T16:29:24-08:00", .iso8601WithTimeZone(dateTimeSeparator: .space),    nil) // Does not match "T"
        verify("2020-03-05 16:29:24-08:00", .iso8601WithTimeZone(dateTimeSeparator: .standard), nil) // Does not match " "

        verify("2020-03-05T162924-08:00",   .iso8601WithTimeZone(timeSeparator: .omitted), "2020-03-05T16:29:24-08:00")
        verify("2020-03-05T16:29:24-08:00", .iso8601WithTimeZone(timeSeparator: .omitted), nil) // Does not match ":" in "16:29:24"
        verify("2020-03-05T162924-08:00",   .iso8601WithTimeZone(timeSeparator: .colon),   nil) // Does not match "162924"

        // FIXME 94663783: This passes but shouldn't since the time zone separator doesn't match
        verify("2020-03-05T16:29:24-08:00", .iso8601WithTimeZone(timeZoneSeparator: .omitted), "2020-03-05T16:29:24-08:00")

        verify("2020-03-05",          .iso8601Date(timeZone: gmt), "2020-03-05T00:00:00+00:00")
        verify("2020-03-05T16:29:24", .iso8601Date(timeZone: pst), nil) // Does not match the time part fully

        verify("2020-03-05", .iso8601Date(timeZone: pst), "2020-03-05T00:00:00-08:00")
    }

}
