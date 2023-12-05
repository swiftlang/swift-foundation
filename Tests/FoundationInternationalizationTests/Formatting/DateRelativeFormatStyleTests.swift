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
// REQUIRES: objc_intero

#if canImport(TestSupport)
import TestSupport
#endif

#if canImport(FoundationInternationalization)
@testable import FoundationEssentials
@testable import FoundationInternationalization
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#endif

final class DateRelativeFormatStyleTests: XCTestCase {

    let oneHour: TimeInterval = 60 * 60
    let oneDay: TimeInterval = 60 * 60 * 24
    let enUSLocale = Locale(identifier: "en_US")
    var calendar = Calendar(identifier: .gregorian)


    override func setUp() {
        calendar.timeZone = TimeZone(abbreviation: "GMT")!
    }

    func testDefaultStyle() throws {
        let style = Date.RelativeFormatStyle(locale: enUSLocale, calendar: calendar)
        XCTAssertEqual(style.format(Date()), "in 0 seconds")
        XCTAssertEqual(style.format(Date(timeIntervalSinceNow: oneHour)), "in 1 hour")
        XCTAssertEqual(style.format(Date(timeIntervalSinceNow: oneHour * 2)), "in 2 hours")
        XCTAssertEqual(style.format(Date(timeIntervalSinceNow: oneDay)), "in 1 day")
        XCTAssertEqual(style.format(Date(timeIntervalSinceNow: oneDay * 2)), "in 2 days")

        XCTAssertEqual(style.format(Date(timeIntervalSinceNow: -oneHour)), "1 hour ago")
        XCTAssertEqual(style.format(Date(timeIntervalSinceNow: -oneHour * 2)), "2 hours ago")

        XCTAssertEqual(style.format(Date(timeIntervalSinceNow: -oneHour * 1.5)), "2 hours ago")
        XCTAssertEqual(style.format(Date(timeIntervalSinceNow: oneHour * 1.5)), "in 2 hours")
    }

    func testDateRelativeFormatConvenience() throws {
        let now = Date()
        let tomorrow = Date(timeInterval: oneDay + oneHour * 2, since: now)
        let future = Date(timeInterval: oneDay * 14 + oneHour * 3, since: now)
        let past = Date(timeInterval: -(oneDay * 14 + oneHour * 2), since: now)

        XCTAssertEqual(past.formatted(.relative(presentation: .named)), Date.RelativeFormatStyle(presentation: .named, unitsStyle: .wide).format(past))
        XCTAssertEqual(tomorrow.formatted(.relative(presentation: .numeric)), Date.RelativeFormatStyle(presentation: .numeric, unitsStyle: .wide).format(tomorrow))
        XCTAssertEqual(tomorrow.formatted(Date.RelativeFormatStyle(presentation: .named)), Date.RelativeFormatStyle(presentation: .named).format(tomorrow))

        XCTAssertEqual(past.formatted(Date.RelativeFormatStyle(unitsStyle: .spellOut, capitalizationContext: .beginningOfSentence)), Date.RelativeFormatStyle(unitsStyle: .spellOut, capitalizationContext: .beginningOfSentence).format(past))
        XCTAssertEqual(future.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated)), Date.RelativeFormatStyle(unitsStyle: .abbreviated).format(future))
    }

    func testNamedStyleRounding() throws {
        let named = Date.RelativeFormatStyle(presentation: .named, locale: enUSLocale, calendar: calendar)

        func _verifyStyle(_ dateValue: TimeInterval, relativeTo: TimeInterval, expected: String, file: StaticString = #file, line: UInt = #line) {
            let date = Date(timeIntervalSinceReferenceDate: dateValue)
            let refDate = Date(timeIntervalSinceReferenceDate: relativeTo)
            let formatted = named._format(date, refDate: refDate)
            XCTAssertEqual(formatted, expected, file: file, line: line)
        }

        // Within a day

        // "2021-06-10 12:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(645019200.0, relativeTo: 645019200.0, expected: "now")
        // "2021-06-10 11:59:30" -> "2021-06-10 12:00:00"
        _verifyStyle(645019170.0, relativeTo: 645019200.0, expected: "30 seconds ago")
        // "2021-06-10 11:59:00" -> "2021-06-10 12:00:00"
        _verifyStyle(645019140.0, relativeTo: 645019200.0, expected: "1 minute ago")
        // "2021-06-10 11:50:00" -> "2021-06-10 12:00:00"
        _verifyStyle(645018600.0, relativeTo: 645019200.0, expected: "10 minutes ago")
        // "2021-06-10 11:49:30" -> "2021-06-10 12:00:00"
        _verifyStyle(645018570.0, relativeTo: 645019200.0, expected: "11 minutes ago") // 10 minutes and 30 seconds ago; rounded to 11 minutes

        // "2021-06-10 11:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(645015600.0, relativeTo: 645019200.0, expected: "1 hour ago")
        // "2021-06-10 10:40:00" -> "2021-06-10 12:00:00"
        _verifyStyle(645014400.0, relativeTo: 645019200.0, expected: "1 hour ago")
        // "2021-06-10 10:30:00" -> "2021-06-10 12:00:00"
        _verifyStyle(645013800.0, relativeTo: 645019200.0, expected: "2 hours ago") // exact 1.5 hours ago; rounded to 2 hours

        // "2021-06-10 13:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(645022800.0, relativeTo: 645019200.0, expected: "in 1 hour")
        // "2021-06-10 13:20:00" -> "2021-06-10 12:00:00"
        _verifyStyle(645024000.0, relativeTo: 645019200.0, expected: "in 1 hour")
        // "2021-06-10 13:30:00" -> "2021-06-10 12:00:00"
        _verifyStyle(645024600.0, relativeTo: 645019200.0, expected: "in 2 hours")
        // "2021-06-10 13:50:00" -> "2021-06-10 12:00:00"
        _verifyStyle(645025800.0, relativeTo: 645019200.0, expected: "in 2 hours")

        // More than one days

        // "2019-01-10 00:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(568771200.0, relativeTo: 645019200.0, expected: "2 years ago")
        // "2019-12-31 23:59:59" -> "2021-06-10 12:00:00"
        _verifyStyle(599529599.0, relativeTo: 645019200.0, expected: "2 years ago")

        // "2020-01-01 00:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(599529600.0, relativeTo: 645019200.0, expected: "last year")
        // "2020-06-10 12:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(613483200.0, relativeTo: 645019200.0, expected: "last year") // exact one year
        // "2020-12-06 12:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(628948800.0, relativeTo: 645019200.0, expected: "6 months ago") // last year, but less than 12 months apart, so formatted with month

        // "2021-01-01 00:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(631152000.0, relativeTo: 645019200.0, expected: "5 months ago")
        // "2021-02-01 00:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(633830400.0, relativeTo: 645019200.0, expected: "4 months ago")
        // "2021-03-01 00:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(636249600.0, relativeTo: 645019200.0, expected: "3 months ago")
        // "2021-04-01 00:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(638928000.0, relativeTo: 645019200.0, expected: "2 months ago")
        // "2021-04-10 12:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(639748800.0, relativeTo: 645019200.0, expected: "2 months ago")
        // "2021-04-30 23:59:59" -> "2021-06-10 12:00:00"
        _verifyStyle(641519999.0, relativeTo: 645019200.0, expected: "2 months ago")
        // "2021-05-01 00:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(641520000.0, relativeTo: 645019200.0, expected: "last month")  // first moment of the previous month
        // "2021-05-30 23:59:59" -> "2021-06-10 12:00:00"
        _verifyStyle(644111999.0, relativeTo: 645019200.0, expected: "last week")   // first moment of the previous week, different month

        // "2021-06-01 00:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(644198400.0, relativeTo: 645019200.0, expected: "last week")   // first moment of the previous week, same month
        // "2021-06-05 23:59:59" -> "2021-06-10 12:00:00"
        _verifyStyle(644630399.0, relativeTo: 645019200.0, expected: "5 days ago")  // last moment of the previous week, but less than 7 days apart, so formatted with day
        // "2021-06-06 00:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(644630400.0, relativeTo: 645019200.0, expected: "4 days ago")  // first moment of this week
        // "2021-06-08 10:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(644839200.0, relativeTo: 645019200.0, expected: "2 days ago")  // the day before yesterday, but more than 48 hours apart
        // "2021-06-08 13:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(644850000.0, relativeTo: 645019200.0, expected: "2 days ago")  // the day before yesterday, but less than 48 hours apart
        // "2021-06-09 11:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(644929200.0, relativeTo: 645019200.0, expected: "yesterday")   // yesterday, but more than 24 hours apart
        // "2021-06-09 13:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(644936400.0, relativeTo: 645019200.0, expected: "23 hours ago") // yesterday, but less than 24 hours apart
        // "2021-06-11 07:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(645087600.0, relativeTo: 645019200.0, expected: "in 19 hours")  // tomorrow, but less than 24 hours apart
        // "2021-06-11 23:00:59" -> "2021-06-10 12:00:00"
        _verifyStyle(645145259.0, relativeTo: 645019200.0, expected: "tomorrow")    // tomorrow, but more than 24 hours apart
        // "2021-06-12 11:00:59" -> "2021-06-10 12:00:00"
        _verifyStyle(645188459.0, relativeTo: 645019200.0, expected: "in 2 days")   // the day after tomorrow, but less than 48 hours apart
        // "2021-06-12 23:59:59" -> "2021-06-10 12:00:00"
        _verifyStyle(645235199.0, relativeTo: 645019200.0, expected: "in 2 days")   //  the day after tomorrow, but more than 48 hours apart
        // "2021-06-13 00:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(645235200.0, relativeTo: 645019200.0, expected: "in 3 days")   // the first moment of the next week, but less than 7 days apart, so formatted with day
        // "2021-06-19 23:59:59" -> "2021-06-10 12:00:00"
        _verifyStyle(645839999.0, relativeTo: 645019200.0, expected: "next week")   // the last moment of the next week
        // "2021-06-20 00:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(645840000.0, relativeTo: 645019200.0, expected: "in 2 weeks")
        // "2021-06-26 23:59:59" -> "2021-06-10 12:00:00"
        _verifyStyle(646444799.0, relativeTo: 645019200.0, expected: "in 2 weeks")
        // "2021-06-30 23:59:59" -> "2021-06-10 12:00:00"
        _verifyStyle(646790399.0, relativeTo: 645019200.0, expected: "in 3 weeks")  // last moment of in the same month
        // "2021-07-01 00:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(646790400.0, relativeTo: 645019200.0, expected: "in 3 weeks")  // first moment of the next month, but than 4 weeks apart, so it's formatted with week
        // "2021-07-31 23:59:59" -> "2021-06-10 12:00:00"
        _verifyStyle(649468799.0, relativeTo: 645019200.0, expected: "next month")  // last moment of the next month
        // "2021-08-01 00:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(649468800.0, relativeTo: 645019200.0, expected: "in 2 months")
        // "2021-08-31 23:59:59" -> "2021-06-10 12:00:00"
        _verifyStyle(652147199.0, relativeTo: 645019200.0, expected: "in 2 months")
        // "2022-01-01 00:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(662688000.0, relativeTo: 645019200.0, expected: "in 7 months") // next year, but less than 12 months apart, so formatted with month
        // "2022-06-10 12:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(676555200.0, relativeTo: 645019200.0, expected: "next year") // exact one year
        // "2022-12-31 23:59:59" -> "2021-06-10 12:00:00"
        _verifyStyle(694223999.0, relativeTo: 645019200.0, expected: "next year")
        // "2023-01-01 00:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(694224000.0, relativeTo: 645019200.0, expected: "in 2 years")
        // "2023-12-31 23:59:59" -> "2021-06-10 12:00:00"
        _verifyStyle(725759999.0, relativeTo: 645019200.0, expected: "in 2 years")
    }

    func testNumericStyleRounding() throws {
        let numeric = Date.RelativeFormatStyle(presentation: .numeric, locale: enUSLocale, calendar: calendar)

        func _verifyStyle(_ dateValue: TimeInterval, relativeTo: TimeInterval, expected: String, file: StaticString = #file, line: UInt = #line) {
            let date = Date(timeIntervalSinceReferenceDate: dateValue)
            let refDate = Date(timeIntervalSinceReferenceDate: relativeTo)
            let formatted = numeric._format(date, refDate: refDate)
            XCTAssertEqual(formatted, expected, file: file, line: line)
        }

        // Within a day

        // "2021-06-10 12:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(645019200.0, relativeTo: 645019200.0, expected: "in 0 seconds")
        // "2021-06-10 11:59:30" -> "2021-06-10 12:00:00"
        _verifyStyle(645019170.0, relativeTo: 645019200.0, expected: "30 seconds ago")
        // "2021-06-10 11:59:00" -> "2021-06-10 12:00:00"
        _verifyStyle(645019140.0, relativeTo: 645019200.0, expected: "1 minute ago")
        // "2021-06-10 11:50:00" -> "2021-06-10 12:00:00"
        _verifyStyle(645018600.0, relativeTo: 645019200.0, expected: "10 minutes ago")
        // "2021-06-10 11:49:30" -> "2021-06-10 12:00:00"
        _verifyStyle(645018570.0, relativeTo: 645019200.0, expected: "11 minutes ago") // 10 minutes and 30 seconds ago; rounded to 11 minutes
        // "2021-06-10 11:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(645015600.0, relativeTo: 645019200.0, expected: "1 hour ago")
        // "2021-06-10 10:40:00" -> "2021-06-10 12:00:00"
        _verifyStyle(645014400.0, relativeTo: 645019200.0, expected: "1 hour ago")
        // "2021-06-10 10:30:00" -> "2021-06-10 12:00:00"
        _verifyStyle(645013800.0, relativeTo: 645019200.0, expected: "2 hours ago") // exact 1.5 hours ago; rounded to 2 hours
        // "2021-06-10 13:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(645022800.0, relativeTo: 645019200.0, expected: "in 1 hour")
        // "2021-06-10 13:20:00" -> "2021-06-10 12:00:00"
        _verifyStyle(645024000.0, relativeTo: 645019200.0, expected: "in 1 hour")
        // "2021-06-10 13:30:00" -> "2021-06-10 12:00:00"
        _verifyStyle(645024600.0, relativeTo: 645019200.0, expected: "in 2 hours")
        // "2021-06-10 13:50:00" -> "2021-06-10 12:00:00"
        _verifyStyle(645025800.0, relativeTo: 645019200.0, expected: "in 2 hours")

        // More than one day

        // "2019-01-10 00:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(568771200.0, relativeTo: 645019200.0, expected: "2 years ago")
        // "2019-12-31 23:59:59" -> "2021-06-10 12:00:00"
        _verifyStyle(599529599.0, relativeTo: 645019200.0, expected: "2 years ago")
        // "2020-01-01 00:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(599529600.0, relativeTo: 645019200.0, expected: "1 year ago")
        // "2020-06-10 12:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(613483200.0, relativeTo: 645019200.0, expected: "1 year ago")   // exact one year
        // "2020-12-06 12:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(628948800.0, relativeTo: 645019200.0, expected: "6 months ago") // last year, but less than 12 months apart, so formatted with month
        // "2021-01-01 00:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(631152000.0, relativeTo: 645019200.0, expected: "5 months ago")
        // "2021-02-01 00:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(633830400.0, relativeTo: 645019200.0, expected: "4 months ago")
        // "2021-03-01 00:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(636249600.0, relativeTo: 645019200.0, expected: "3 months ago")
        // "2021-04-01 00:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(638928000.0, relativeTo: 645019200.0, expected: "2 months ago")
        // "2021-04-10 12:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(639748800.0, relativeTo: 645019200.0, expected: "2 months ago")
        // "2021-04-30 23:59:59" -> "2021-06-10 12:00:00"
        _verifyStyle(641519999.0, relativeTo: 645019200.0, expected: "2 months ago")
        // "2021-05-01 00:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(641520000.0, relativeTo: 645019200.0, expected: "1 month ago")  // first moment of the previous month
        // "2021-05-30 23:59:59" -> "2021-06-10 12:00:00"
        _verifyStyle(644111999.0, relativeTo: 645019200.0, expected: "1 week ago")   // first moment of the previous week, different month
        // "2021-06-01 00:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(644198400.0, relativeTo: 645019200.0, expected: "1 week ago")   // first moment of the previous week, same month
        // "2021-06-05 23:59:59" -> "2021-06-10 12:00:00"
        _verifyStyle(644630399.0, relativeTo: 645019200.0, expected: "5 days ago")  // last moment of the previous week, but less than 7 days apart, so formatted with day
        // "2021-06-06 00:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(644630400.0, relativeTo: 645019200.0, expected: "4 days ago")  // first moment of this week
        // "2021-06-08 10:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(644839200.0, relativeTo: 645019200.0, expected: "2 days ago")  // the day before yesterday, but more than 48 hours apart
        // "2021-06-08 13:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(644850000.0, relativeTo: 645019200.0, expected: "2 days ago")  // the day before yesterday, but less than 48 hours apart
        // "2021-06-09 11:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(644929200.0, relativeTo: 645019200.0, expected: "1 day ago")   // yesterday, but more than 24 hours apart
        // "2021-06-09 13:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(644936400.0, relativeTo: 645019200.0, expected: "23 hours ago") // yesterday, but less than 24 hours apart
        // "2021-06-11 07:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(645087600.0, relativeTo: 645019200.0, expected: "in 19 hours")  // tomorrow, but less than 24 hours apart
        // "2021-06-11 23:00:59" -> "2021-06-10 12:00:00"
        _verifyStyle(645145259.0, relativeTo: 645019200.0, expected: "in 1 day")    // tomorrow, but more than 24 hours apart
        // "2021-06-12 11:00:59" -> "2021-06-10 12:00:00"
        _verifyStyle(645188459.0, relativeTo: 645019200.0, expected: "in 2 days")   // the day after tomorrow, but less than 48 hours apart
        // "2021-06-12 23:59:59" -> "2021-06-10 12:00:00"
        _verifyStyle(645235199.0, relativeTo: 645019200.0, expected: "in 2 days")   // the day after tomorrow, but more than 48 hours apart
        // "2021-06-13 00:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(645235200.0, relativeTo: 645019200.0, expected: "in 3 days")   // the first moment of the next week, but less than 7 days apart, so formatted with day
        // "2021-06-19 23:59:59" -> "2021-06-10 12:00:00"
        _verifyStyle(645839999.0, relativeTo: 645019200.0, expected: "in 1 week")   // the last moment of the next week
        // "2021-06-20 00:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(645840000.0, relativeTo: 645019200.0, expected: "in 2 weeks")
        // "2021-06-26 23:59:59" -> "2021-06-10 12:00:00"
        _verifyStyle(646444799.0, relativeTo: 645019200.0, expected: "in 2 weeks")
        // "2021-06-30 23:59:59" -> "2021-06-10 12:00:00"
        _verifyStyle(646790399.0, relativeTo: 645019200.0, expected: "in 3 weeks")  // last moment of in the same month
        // "2021-07-01 00:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(646790400.0, relativeTo: 645019200.0, expected: "in 3 weeks")  // first moment of the next month, but than 4 weeks apart, so it's formatted with week
        // "2021-07-31 23:59:59" -> "2021-06-10 12:00:00"
        _verifyStyle(649468799.0, relativeTo: 645019200.0, expected: "in 1 month")  // last moment of the next month
        // "2021-08-01 00:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(649468800.0, relativeTo: 645019200.0, expected: "in 2 months")
        // "2021-08-31 23:59:59" -> "2021-06-10 12:00:00"
        _verifyStyle(652147199.0, relativeTo: 645019200.0, expected: "in 2 months")
        // "2022-01-01 00:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(662688000.0, relativeTo: 645019200.0, expected: "in 7 months") // next year, but less than 12 months apart, so formatted with month
        // "2022-06-10 12:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(676555200.0, relativeTo: 645019200.0, expected: "in 1 year")   // exact one year
        // "2022-12-31 23:59:59" -> "2021-06-10 12:00:00"
        _verifyStyle(694223999.0, relativeTo: 645019200.0, expected: "in 1 year")
        // "2023-01-01 00:00:00" -> "2021-06-10 12:00:00"
        _verifyStyle(694224000.0, relativeTo: 645019200.0, expected: "in 2 years")
        // "2023-12-31 23:59:59" -> "2021-06-10 12:00:00"
        _verifyStyle(725759999.0, relativeTo: 645019200.0, expected: "in 2 years")

    }
    
    func testAutoupdatingCurrentChangesFormatResults() {
        let locale = Locale.autoupdatingCurrent
        let date = Date.now + 3600

        // Get a formatted result from es-ES
        var prefs = LocalePreferences()
        prefs.languages = ["es-ES"]
        prefs.locale = "es_ES"
        LocaleCache.cache.resetCurrent(to: prefs)
        let formattedSpanish = date.formatted(.relative(presentation: .named).locale(locale))

        // Get a formatted result from en-US
        prefs.languages = ["en-US"]
        prefs.locale = "en_US"
        LocaleCache.cache.resetCurrent(to: prefs)
        let formattedEnglish = date.formatted(.relative(presentation: .named).locale(locale))

        // Reset to current preferences before any possibility of failing this test
        LocaleCache.cache.reset()

        // No matter what 'current' was before this test was run, formattedSpanish and formattedEnglish should be different.
        XCTAssertNotEqual(formattedSpanish, formattedEnglish)
    }

    @available(FoundationPreview 0.4, *)
    func testAllowedFieldsNamed() throws {
        var named = Date.RelativeFormatStyle(presentation: .named, locale: enUSLocale, calendar: calendar)

        func _verifyStyle(_ dateStr: String, relativeTo: String, expected: String, file: StaticString = #file, line: UInt = #line) {
            let date = try! Date.ISO8601FormatStyle().parse(dateStr)
            let refDate = try! Date.ISO8601FormatStyle().parse(relativeTo)
            let formatted = named._format(date, refDate: refDate)
            XCTAssertEqual(formatted, expected, file: file, line: line)
        }

        named.allowedFields = [.year]
        _verifyStyle("2021-06-10T12:00:00Z", relativeTo: "2021-06-10T12:00:00Z", expected: "this year")
        _verifyStyle("2020-12-06T12:00:00Z", relativeTo: "2021-01-10T12:00:00Z", expected: "last year")
        named.allowedFields = [.year, .hour]
        _verifyStyle("2021-06-11T12:00:00Z", relativeTo: "2021-06-01T12:00:00Z", expected: "in 240 hours")
        _verifyStyle("2020-12-06T12:00:00Z", relativeTo: "2021-01-10T12:00:00Z", expected: "840 hours ago")
        _verifyStyle("2020-01-10T12:00:00Z", relativeTo: "2021-01-10T12:00:00Z", expected: "last year")
        named.allowedFields = [.minute]
        _verifyStyle("2021-06-10T11:59:31Z", relativeTo: "2021-06-10T12:00:00Z", expected: "this minute")
        _verifyStyle("2021-06-10T11:59:30Z", relativeTo: "2021-06-10T12:00:00Z", expected: "1 minute ago")
        _verifyStyle("2021-06-10T11:59:00Z", relativeTo: "2021-06-10T12:00:00Z", expected: "1 minute ago")
        named.allowedFields = [.hour]
        _verifyStyle("2021-06-10T11:50:00Z", relativeTo: "2021-06-10T12:00:00Z", expected: "this hour")
        named.allowedFields = [.hour, .minute]
        _verifyStyle("2021-06-10T11:49:30Z", relativeTo: "2021-06-10T12:00:00Z", expected: "11 minutes ago")
        named.allowedFields = [.day]
        _verifyStyle("2021-06-08T13:00:00Z", relativeTo: "2021-06-10T12:00:00Z", expected: "2 days ago")
        _verifyStyle("2021-06-09T11:00:00Z", relativeTo: "2021-06-10T12:00:00Z", expected: "yesterday")

        _verifyStyle("2021-06-09T13:00:00Z", relativeTo: "2021-06-10T12:00:00Z", expected: "yesterday")
        _verifyStyle("2021-06-11T07:00:00Z", relativeTo: "2021-06-10T12:00:00Z", expected: "tomorrow")
    }

    @available(FoundationPreview 0.4, *)
    func testAllowedFieldsNumeric() throws {
        var named = Date.RelativeFormatStyle(presentation: .numeric, locale: enUSLocale, calendar: calendar)

        func _verifyStyle(_ dateStr: String, relativeTo: String, expected: String, file: StaticString = #file, line: UInt = #line) {
            let date = try! Date.ISO8601FormatStyle().parse(dateStr)
            let refDate = try! Date.ISO8601FormatStyle().parse(relativeTo)
            let formatted = named._format(date, refDate: refDate)
            XCTAssertEqual(formatted, expected, file: file, line: line)
        }

        named.allowedFields = [.year]
        _verifyStyle("2021-06-10T12:00:00Z", relativeTo: "2021-06-10T12:00:00Z", expected: "in 0 years")
        _verifyStyle("2020-12-06T12:00:00Z", relativeTo: "2021-01-10T12:00:00Z", expected: "1 year ago")
        named.allowedFields = [.minute]
        _verifyStyle("2021-06-10T11:59:31Z", relativeTo: "2021-06-10T12:00:00Z", expected: "in 0 minutes")
        _verifyStyle("2021-06-10T11:59:30Z", relativeTo: "2021-06-10T12:00:00Z", expected: "1 minute ago")
        _verifyStyle("2021-06-10T11:59:00Z", relativeTo: "2021-06-10T12:00:00Z", expected: "1 minute ago")
        named.allowedFields = [.hour]
        _verifyStyle("2021-06-10T11:50:00Z", relativeTo: "2021-06-10T12:00:00Z", expected: "in 0 hours")
        named.allowedFields = [.hour, .minute]
        _verifyStyle("2021-06-10T11:49:30Z", relativeTo: "2021-06-10T12:00:00Z", expected: "11 minutes ago")
        named.allowedFields = [.day]
        _verifyStyle("2021-06-08T13:00:00Z", relativeTo: "2021-06-10T12:00:00Z", expected: "2 days ago")
        _verifyStyle("2021-06-09T11:00:00Z", relativeTo: "2021-06-10T12:00:00Z", expected: "1 day ago")

        _verifyStyle("2021-06-09T13:00:00Z", relativeTo: "2021-06-10T12:00:00Z", expected: "1 day ago")
        _verifyStyle("2021-06-11T07:00:00Z", relativeTo: "2021-06-10T12:00:00Z", expected: "in 1 day")
    }
}
