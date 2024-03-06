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

// MARK: DiscreteFormatStyle conformance test

@available(FoundationPreview 0.4, *)
final class TestDateAnchoredRelativeDiscreteConformance : XCTestCase {
    let enUSLocale = Locale(identifier: "en_US")
    var calendar = Calendar(identifier: .gregorian)

    override func setUp() {
        calendar.timeZone = TimeZone(abbreviation: "GMT")!
    }

    func date(_ string: String) -> Date {
        try! Date.ISO8601FormatStyle(dateSeparator: .dash, dateTimeSeparator: .space, timeZoneSeparator: .omitted, timeZone: .gmt).locale(enUSLocale).parse(string)
    }

    func testExamples() throws {
        var now = Date.now
        var style = Date.AnchoredRelativeFormatStyle(anchor: now)
            .locale(enUSLocale)

        XCTAssertEqual(style.discreteInput(after: now.addingTimeInterval(1)), now.addingTimeInterval(1.5))
        XCTAssertEqual(style.discreteInput(before: now.addingTimeInterval(1)), now.addingTimeInterval(0.5).nextDown)
        XCTAssertEqual(style.discreteInput(after: now.addingTimeInterval(0.5)), now.addingTimeInterval(1.5))
        XCTAssertEqual(style.discreteInput(before: now.addingTimeInterval(0.5)), now.addingTimeInterval(0.5).nextDown)
        XCTAssertEqual(style.discreteInput(after: now.addingTimeInterval(0)), now.addingTimeInterval(0.5))
        XCTAssertEqual(style.discreteInput(before: now.addingTimeInterval(0)), now.addingTimeInterval(-0.5))
        XCTAssertEqual(style.discreteInput(after: now.addingTimeInterval(-0.5)), now.addingTimeInterval(-0.5).nextUp)
        XCTAssertEqual(style.discreteInput(before: now.addingTimeInterval(-0.5)), now.addingTimeInterval(-1.5))
        XCTAssertEqual(style.discreteInput(after: now.addingTimeInterval(-1)), now.addingTimeInterval(-0.5).nextUp)
        XCTAssertEqual(style.discreteInput(before: now.addingTimeInterval(-1)), now.addingTimeInterval(-1.5))

        now = date("2021-06-10 12:00:00Z")
        style.anchor = now


        XCTAssertEqual(style.discreteInput(before: date("2021-06-10 11:58:30Z").addingTimeInterval(0.5).nextUp), date("2021-06-10 11:58:30Z").addingTimeInterval(0.5))
        XCTAssertEqual(style.discreteInput(after: date("2021-06-10 11:58:30Z").addingTimeInterval(0.5)), date("2021-06-10 11:58:30Z").addingTimeInterval(0.5).nextUp)
        XCTAssertEqual(style.format(date("2021-06-10 11:58:30Z").addingTimeInterval(0.5).nextUp), "in 1 minute")
        XCTAssertEqual(style.format(date("2021-06-10 11:58:30Z").addingTimeInterval(0.5)), "in 2 minutes")

        XCTAssertEqual(style.discreteInput(before: date("2021-06-10 11:57:30Z").addingTimeInterval(0.5).nextUp), date("2021-06-10 11:57:30Z").addingTimeInterval(0.5))
        XCTAssertEqual(style.discreteInput(after: date("2021-06-10 11:57:30Z").addingTimeInterval(0.5)), date("2021-06-10 11:57:30Z").addingTimeInterval(0.5).nextUp)
        XCTAssertEqual(style.format(date("2021-06-10 11:57:30Z").addingTimeInterval(0.5).nextUp), "in 2 minutes")
        XCTAssertEqual(style.format(date("2021-06-10 11:57:30Z").addingTimeInterval(0.5)), "in 3 minutes")

        XCTAssertEqual(style.discreteInput(before: date("2021-06-10 11:56:30Z").addingTimeInterval(0.5).nextUp), date("2021-06-10 11:56:30Z").addingTimeInterval(0.5))
        XCTAssertEqual(style.discreteInput(after: date("2021-06-10 11:56:30Z").addingTimeInterval(0.5)), date("2021-06-10 11:56:30Z").addingTimeInterval(0.5).nextUp)
        XCTAssertEqual(style.format(date("2021-06-10 11:56:30Z").addingTimeInterval(0.5).nextUp), "in 3 minutes")
        XCTAssertEqual(style.format(date("2021-06-10 11:56:30Z").addingTimeInterval(0.5)), "in 4 minutes")



        XCTAssertEqual(style.discreteInput(before: date("2021-06-10 12:01:30Z").addingTimeInterval(-0.5)), date("2021-06-10 12:01:30Z").addingTimeInterval(-0.5).nextDown)
        XCTAssertEqual(style.discreteInput(after: date("2021-06-10 12:01:30Z").addingTimeInterval(-0.5).nextDown), date("2021-06-10 12:01:30Z").addingTimeInterval(-0.5))
        XCTAssertEqual(style.format(date("2021-06-10 12:01:30Z").addingTimeInterval(-0.5).nextDown), "1 minute ago")
        XCTAssertEqual(style.format(date("2021-06-10 12:01:30Z").addingTimeInterval(-0.5)), "2 minutes ago")

        XCTAssertEqual(style.discreteInput(before: date("2021-06-10 12:02:30Z").addingTimeInterval(-0.5)), date("2021-06-10 12:02:30Z").addingTimeInterval(-0.5).nextDown)
        XCTAssertEqual(style.discreteInput(after: date("2021-06-10 12:02:30Z").addingTimeInterval(-0.5).nextDown), date("2021-06-10 12:02:30Z").addingTimeInterval(-0.5))
        XCTAssertEqual(style.format(date("2021-06-10 12:02:30Z").addingTimeInterval(-0.5).nextDown), "2 minutes ago")
        XCTAssertEqual(style.format(date("2021-06-10 12:02:30Z").addingTimeInterval(-0.5)), "3 minutes ago")

        XCTAssertEqual(style.discreteInput(before: date("2021-06-10 12:03:30Z").addingTimeInterval(-0.5)), date("2021-06-10 12:03:30Z").addingTimeInterval(-0.5).nextDown)
        XCTAssertEqual(style.discreteInput(after: date("2021-06-10 12:03:30Z").addingTimeInterval(-0.5).nextDown), date("2021-06-10 12:03:30Z").addingTimeInterval(-0.5))
        XCTAssertEqual(style.format(date("2021-06-10 12:03:30Z").addingTimeInterval(-0.5).nextDown), "3 minutes ago")
        XCTAssertEqual(style.format(date("2021-06-10 12:03:30Z").addingTimeInterval(-0.5)), "4 minutes ago")
    }

    func testCounting() {
        func assertEvaluation(of style: Date.AnchoredRelativeFormatStyle,
                              in range: ClosedRange<Date>,
                              includes expectedExcerpts: [String]...,
                              file: StaticString = #filePath,
                              line: UInt = #line) {
            var style = style
                .locale(enUSLocale)
            style.calendar = calendar

            verify(
                sequence: style.evaluate(from: range.lowerBound, to: range.upperBound).lazy.map(\.output),
                contains: expectedExcerpts,
                "(lowerbound to upperbound)",
                file: file,
                line: line)

            verify(
                sequence: style.evaluate(from: range.upperBound, to: range.lowerBound).lazy.map(\.output),
                contains: expectedExcerpts
                    .reversed()
                    .map { $0.reversed() },
                "(upperbound to lowerbound)",
                file: file,
                line: line)
        }

        var now = date("2021-06-10 12:00:00Z")

        assertEvaluation(
            of: .init(anchor: now, presentation: .numeric, unitsStyle: .abbreviated),
            in: now.addingTimeInterval(-3)...now.addingTimeInterval(3),
            includes: [
                "in 3 sec.",
                "in 2 sec.",
                "in 1 sec.",
                "in 0 sec.",
                "1 sec. ago",
                "2 sec. ago",
                "3 sec. ago",
            ])

        assertEvaluation(
            of: .init(anchor: now, allowedFields: [.minute], presentation: .numeric, unitsStyle: .abbreviated),
            in: now.addingTimeInterval(-180)...now.addingTimeInterval(180),
            includes: [
                "in 3 min.",
                "in 2 min.",
                "in 1 min.",
                "in 0 min.",
                "1 min. ago",
                "2 min. ago",
                "3 min. ago",
            ])

        assertEvaluation(
            of: .init(anchor: now, allowedFields: [.minute, .second], presentation: .numeric, unitsStyle: .abbreviated),
            in: now.addingTimeInterval(-120)...now.addingTimeInterval(120),
            includes: [
                "in 2 min.",
                "in 1 min.",
                "in 59 sec.",
                "in 58 sec.",
                "in 57 sec.",
                "in 56 sec.",
                "in 55 sec.",
            ],
            [
                "in 2 sec.",
                "in 1 sec.",
                "in 0 sec.",
                "1 sec. ago",
                "2 sec. ago",
            ],
            [
                "55 sec. ago",
                "56 sec. ago",
                "57 sec. ago",
                "58 sec. ago",
                "59 sec. ago",
                "1 min. ago",
                "2 min. ago",
            ])

        assertEvaluation(
            of: .init(anchor: now, allowedFields: [.month], presentation: .numeric, unitsStyle: .abbreviated),
            in: now.addingTimeInterval(-8 * 31 * 24 * 3600)...now.addingTimeInterval(8 * 31 * 24 * 3600),
            includes: [
                "in 8 mo.",
                "in 7 mo.",
                "in 6 mo.",
                "in 5 mo.",
                "in 4 mo.",
                "in 3 mo.",
                "in 2 mo.",
                "in 1 mo.",
                "in 0 mo.",
                "1 mo. ago",
                "2 mo. ago",
                "3 mo. ago",
                "4 mo. ago",
                "5 mo. ago",
                "6 mo. ago",
                "7 mo. ago",
                "8 mo. ago",
            ])

        now = date("2023-05-15 08:47:20Z")

        assertEvaluation(
            of: .init(anchor: now, allowedFields: [.month, .week], presentation: .numeric, unitsStyle: .abbreviated),
            in: now.addingTimeInterval(-8 * 31 * 24 * 3600)...now.addingTimeInterval(8 * 31 * 24 * 3600),
            includes: [
                "in 8 mo.",
                "in 7 mo.",
                "in 6 mo.",
                "in 5 mo.",
                "in 4 mo.",
                "in 3 mo.",
                "in 2 mo.",
                "in 1 mo.",
                "in 4 wk.",
                "in 3 wk.",
                "in 2 wk.",
                "in 1 wk.",
                "in 0 wk.",
                "1 wk. ago",
                "2 wk. ago",
                "3 wk. ago",
                "1 mo. ago",
                "2 mo. ago",
                "3 mo. ago",
                "4 mo. ago",
                "5 mo. ago",
                "6 mo. ago",
                "7 mo. ago",
                "8 mo. ago",
            ])

        assertEvaluation(
            of: .init(anchor: now, allowedFields: [.month, .week, .day, .hour], presentation: .numeric, unitsStyle: .abbreviated),
            in: now.addingTimeInterval(-8 * 31 * 24 * 3600)...now.addingTimeInterval(8 * 31 * 24 * 3600),
            includes: [
                "in 8 mo.",
                "in 7 mo.",
                "in 6 mo.",
                "in 5 mo.",
                "in 4 mo.",
                "in 3 mo.",
                "in 2 mo.",
                "in 1 mo.",
                "in 4 wk.",
                "in 3 wk.",
                "in 2 wk.",
                "in 1 wk.",
                "in 6 days",
                "in 5 days",
                "in 4 days",
                "in 3 days",
                "in 2 days",
                "in 1 day",
                "in 23 hr.",
                "in 22 hr.",
                "in 21 hr.",
                "in 20 hr.",
                "in 19 hr.",
                "in 18 hr.",
                "in 17 hr.",
                "in 16 hr.",
                "in 15 hr.",
                "in 14 hr.",
                "in 13 hr.",
                "in 12 hr.",
                "in 11 hr.",
                "in 10 hr.",
                "in 9 hr.",
                "in 8 hr.",
                "in 7 hr.",
                "in 6 hr.",
                "in 5 hr.",
                "in 4 hr.",
                "in 3 hr.",
                "in 2 hr.",
                "in 1 hr.",
                "in 0 hr.",
                "1 hr. ago",
                "2 hr. ago",
                "3 hr. ago",
                "4 hr. ago",
                "5 hr. ago",
                "6 hr. ago",
                "7 hr. ago",
                "8 hr. ago",
                "9 hr. ago",
                "10 hr. ago",
                "11 hr. ago",
                "12 hr. ago",
                "13 hr. ago",
                "14 hr. ago",
                "15 hr. ago",
                "16 hr. ago",
                "17 hr. ago",
                "18 hr. ago",
                "19 hr. ago",
                "20 hr. ago",
                "21 hr. ago",
                "22 hr. ago",
                "23 hr. ago",
                "1 day ago",
                "2 days ago",
                "3 days ago",
                "4 days ago",
                "5 days ago",
                "6 days ago",
                "1 wk. ago",
                "2 wk. ago",
                "3 wk. ago",
                "1 mo. ago",
                "2 mo. ago",
                "3 mo. ago",
                "4 mo. ago",
                "5 mo. ago",
                "6 mo. ago",
                "7 mo. ago",
                "8 mo. ago",
            ])

        now = date("2019-06-03 09:41:00Z")

        assertEvaluation(
            of: .init(anchor: now, allowedFields: [.year, .month, .day, .hour, .minute], presentation: .named, unitsStyle: .wide),
            in: now.addingTimeInterval(-2 * 24 * 3600)...now.addingTimeInterval(2 * 24 * 3600),
            includes: [
                "in 2 days",
                "tomorrow",
                "in 23 hours",
                "in 22 hours",
                "in 21 hours",
                "in 20 hours",
                "in 19 hours",
                "in 18 hours",
                "in 17 hours",
                "in 16 hours",
                "in 15 hours",
                "in 14 hours",
                "in 13 hours",
                "in 12 hours",
                "in 11 hours",
                "in 10 hours",
                "in 9 hours",
                "in 8 hours",
                "in 7 hours",
                "in 6 hours",
                "in 5 hours",
                "in 4 hours",
                "in 3 hours",
                "in 2 hours",
                "in 1 hour",
                "in 59 minutes",
                "in 58 minutes",
                "in 57 minutes",
                "in 56 minutes",
                "in 55 minutes",
                "in 54 minutes",
                "in 53 minutes",
                "in 52 minutes",
                "in 51 minutes",
                "in 50 minutes",
                "in 49 minutes",
                "in 48 minutes",
                "in 47 minutes",
                "in 46 minutes",
                "in 45 minutes",
                "in 44 minutes",
                "in 43 minutes",
                "in 42 minutes",
                "in 41 minutes",
                "in 40 minutes",
                "in 39 minutes",
                "in 38 minutes",
                "in 37 minutes",
                "in 36 minutes",
                "in 35 minutes",
                "in 34 minutes",
                "in 33 minutes",
                "in 32 minutes",
                "in 31 minutes",
                "in 30 minutes",
                "in 29 minutes",
                "in 28 minutes",
                "in 27 minutes",
                "in 26 minutes",
                "in 25 minutes",
                "in 24 minutes",
                "in 23 minutes",
                "in 22 minutes",
                "in 21 minutes",
                "in 20 minutes",
                "in 19 minutes",
                "in 18 minutes",
                "in 17 minutes",
                "in 16 minutes",
                "in 15 minutes",
                "in 14 minutes",
                "in 13 minutes",
                "in 12 minutes",
                "in 11 minutes",
                "in 10 minutes",
                "in 9 minutes",
                "in 8 minutes",
                "in 7 minutes",
                "in 6 minutes",
                "in 5 minutes",
                "in 4 minutes",
                "in 3 minutes",
                "in 2 minutes",
                "in 1 minute",
                "this minute",
                "1 minute ago",
                "2 minutes ago",
                "3 minutes ago",
                "4 minutes ago",
                "5 minutes ago",
                "6 minutes ago",
                "7 minutes ago",
                "8 minutes ago",
                "9 minutes ago",
                "10 minutes ago",
                "11 minutes ago",
                "12 minutes ago",
                "13 minutes ago",
                "14 minutes ago",
                "15 minutes ago",
                "16 minutes ago",
                "17 minutes ago",
                "18 minutes ago",
                "19 minutes ago",
                "20 minutes ago",
                "21 minutes ago",
                "22 minutes ago",
                "23 minutes ago",
                "24 minutes ago",
                "25 minutes ago",
                "26 minutes ago",
                "27 minutes ago",
                "28 minutes ago",
                "29 minutes ago",
                "30 minutes ago",
                "31 minutes ago",
                "32 minutes ago",
                "33 minutes ago",
                "34 minutes ago",
                "35 minutes ago",
                "36 minutes ago",
                "37 minutes ago",
                "38 minutes ago",
                "39 minutes ago",
                "40 minutes ago",
                "41 minutes ago",
                "42 minutes ago",
                "43 minutes ago",
                "44 minutes ago",
                "45 minutes ago",
                "46 minutes ago",
                "47 minutes ago",
                "48 minutes ago",
                "49 minutes ago",
                "50 minutes ago",
                "51 minutes ago",
                "52 minutes ago",
                "53 minutes ago",
                "54 minutes ago",
                "55 minutes ago",
                "56 minutes ago",
                "57 minutes ago",
                "58 minutes ago",
                "59 minutes ago",
                "1 hour ago",
                "2 hours ago",
                "3 hours ago",
                "4 hours ago",
                "5 hours ago",
                "6 hours ago",
                "7 hours ago",
                "8 hours ago",
                "9 hours ago",
                "10 hours ago",
                "11 hours ago",
                "12 hours ago",
                "13 hours ago",
                "14 hours ago",
                "15 hours ago",
                "16 hours ago",
                "17 hours ago",
                "18 hours ago",
                "19 hours ago",
                "20 hours ago",
                "21 hours ago",
                "22 hours ago",
                "23 hours ago",
                "yesterday",
                "2 days ago",
            ])
    }

    func testRegressions() throws {
        var style: Date.AnchoredRelativeFormatStyle
        var now: Date

        now = Date(timeIntervalSinceReferenceDate: 724685580.417914)
        style = .init(anchor: now, allowedFields: [.minute], presentation: .numeric, unitsStyle: .abbreviated)
        style.calendar = self.calendar
        XCTAssertGreaterThan(try XCTUnwrap(style.discreteInput(after: Date(timeIntervalSinceReferenceDate: 12176601839.415668))), Date(timeIntervalSinceReferenceDate: 12176601839.415668))


        now = Date(timeIntervalSinceReferenceDate: 724686086.706003)
        style = .init(anchor: now, allowedFields: [.minute], presentation: .numeric, unitsStyle: .abbreviated)
        style.calendar = self.calendar
        XCTAssertLessThan(try XCTUnwrap(style.discreteInput(before: Date(timeIntervalSinceReferenceDate: -24141834543.08099))), Date(timeIntervalSinceReferenceDate: -24141834543.08099))

        now = Date(timeIntervalSinceReferenceDate: 724688507.315708)
        style = .init(anchor: now, allowedFields: [.minute, .second], presentation: .numeric, unitsStyle: .abbreviated)
        style.calendar = self.calendar
        XCTAssertGreaterThan(try XCTUnwrap(style.discreteInput(after: Date(timeIntervalSinceReferenceDate: 6013270816.926929))), Date(timeIntervalSinceReferenceDate: 6013270816.926929))

        now = Date(timeIntervalSinceReferenceDate: 724689590.234374)
        style = .init(anchor: now, allowedFields: [.month, .week], presentation: .numeric, unitsStyle: .abbreviated)
        style.calendar = self.calendar
        print(style.format(Date(timeIntervalSinceReferenceDate: 722325435.4645464)))
        XCTAssertGreaterThan(try XCTUnwrap(style.discreteInput(after: Date(timeIntervalSinceReferenceDate: 722325435.4645464))), Date(timeIntervalSinceReferenceDate: 722325435.4645464))

        now = Date(timeIntervalSinceReferenceDate: 724701229.591328)
        style = .init(anchor: now, presentation: .numeric, unitsStyle: .abbreviated)
        style.calendar = self.calendar
        /// style.discreteInput(before: Date(timeIntervalSinceReferenceDate: -7256167.2374657225)) returned Date(timeIntervalSinceReferenceDate: -31622400.5), but
        /// Date(timeIntervalSinceReferenceDate: -31622400.49), which is a valid input, because style.input(after: Date(timeIntervalSinceReferenceDate: -31622400.5)) = Date(timeIntervalSinceReferenceDate: -31622400.49),
        /// already produces a different formatted output 'in 24 yr' compared to style.format(Date(timeIntervalSinceReferenceDate: -7256167.2374657225)), which is 'in 23 yr'
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(style.discreteInput(before: Date(timeIntervalSinceReferenceDate: -7256167.2374657225))), Date(timeIntervalSinceReferenceDate: -31622400.49))


        now = Date(timeIntervalSinceReferenceDate: 724707086.436074)
        style = .init(anchor: now, presentation: .numeric, unitsStyle: .abbreviated)
        style.calendar = self.calendar
        /// style.discreteInput(after: Date(timeIntervalSinceReferenceDate: -728.7911686889214)) returned Date(timeIntervalSinceReferenceDate: 0.9360740142747098), but
        /// Date(timeIntervalSinceReferenceDate: 0.9260740142747098), which is a valid input, because style.input(before: Date(timeIntervalSinceReferenceDate: 0.9360740142747098)) = Date(timeIntervalSinceReferenceDate: 0.9260740142747098),
        /// already produces a different formatted output 'in 22 yr' compared to style.format(Date(timeIntervalSinceReferenceDate: -728.7911686889214)), which is 'in 23 yr'
       XCTAssertLessThanOrEqual(try XCTUnwrap(style.discreteInput(after: Date(timeIntervalSinceReferenceDate: -728.7911686889214))), Date(timeIntervalSinceReferenceDate: 0.9260740142747098))


        now = Date(timeIntervalSinceReferenceDate: 724707983.332096)
        style = .init(anchor: now, allowedFields: [.year, .month, .day, .hour, .minute], presentation: .named, unitsStyle: .wide)
        style.calendar = self.calendar
        XCTAssertGreaterThan(try XCTUnwrap(style.discreteInput(after: Date(timeIntervalSinceReferenceDate: 722086631.228182))), Date(timeIntervalSinceReferenceDate: 722086631.228182))

        now = Date(timeIntervalSinceReferenceDate: 725887340.112405)
        style = .init(anchor: now, allowedFields: [.month, .week, .day, .hour], presentation: .numeric, unitsStyle: .abbreviated)
        style.calendar = self.calendar
        /// style.discreteInput(before: Date(timeIntervalSinceReferenceDate: 728224511.9413433)) returned Date(timeIntervalSinceReferenceDate: 727487999.6124048), but
        /// Date(timeIntervalSinceReferenceDate: 727487999.6224048), which is a valid input, because style.input(after: Date(timeIntervalSinceReferenceDate: 727487999.6124048)) = Date(timeIntervalSinceReferenceDate: 727487999.6224048),
        /// already produces a different formatted output '3 wk ago' compared to style.format(Date(timeIntervalSinceReferenceDate: 728224511.9413433)), which is '1 mo ago'
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(style.discreteInput(before: Date(timeIntervalSinceReferenceDate: 728224511.9413433))), Date(timeIntervalSinceReferenceDate: 727487999.6224048))

        now = Date(timeIntervalSinceReferenceDate: 725895690.016681)
        style = .init(anchor: now, presentation: .numeric, unitsStyle: .abbreviated)
        style.calendar = self.calendar
        /// style.discreteInput(before: Date(timeIntervalSinceReferenceDate: 726561180.513301)) returned Date(timeIntervalSinceReferenceDate: 726364799.5166808), but
        /// Date(timeIntervalSinceReferenceDate: 726364799.5266808), which is a valid input, because style.input(after: Date(timeIntervalSinceReferenceDate: 726364799.5166808)) = Date(timeIntervalSinceReferenceDate: 726364799.5266808),
        /// already produces a different formatted output '6 days ago' compared to style.format(Date(timeIntervalSinceReferenceDate: 726561180.513301)), which is '1 wk ago'
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(style.discreteInput(before: Date(timeIntervalSinceReferenceDate: 726561180.513301))), Date(timeIntervalSinceReferenceDate: 726364799.5266808))

        now = Date(timeIntervalSinceReferenceDate: 725903036.660503)
        style = .init(anchor: now, presentation: .numeric, unitsStyle: .abbreviated)
        style.calendar = self.calendar
        /// style.discreteInput(after: Date(timeIntervalSinceReferenceDate: 725318223.6599436)) returned Date(timeIntervalSinceReferenceDate: 725414400.1605031), but
        /// Date(timeIntervalSinceReferenceDate: 725398549.919868), which is a valid input, because style.input(before: Date(timeIntervalSinceReferenceDate: 725414400.1605031)) = Date(timeIntervalSinceReferenceDate: 725414400.1505032),
        /// already produces a different formatted output 'in 6 days' compared to style.format(Date(timeIntervalSinceReferenceDate: 725318223.6599436)), which is 'in 1 wk'
        XCTAssertLessThanOrEqual(try XCTUnwrap(style.discreteInput(after: Date(timeIntervalSinceReferenceDate: 725318223.6599436))), Date(timeIntervalSinceReferenceDate: 725398549.919868))
    }

#if FIXME_RANDOMIZED_SAMPLES_123465054
    func testRandomSamples() throws {
        var style: Date.AnchoredRelativeFormatStyle
        let now = Date.now

        lazy var message = "now = Date(timeIntervalSinceReferenceDate: \(now.timeIntervalSinceReferenceDate))"

        style = .init(anchor: now, presentation: .numeric, unitsStyle: .abbreviated)
        style.calendar = self.calendar
        try verifyDiscreteFormatStyleConformance(style, samples: 100, message)

        style = .init(anchor: now, allowedFields: [.minute], presentation: .numeric, unitsStyle: .abbreviated)
        style.calendar = self.calendar
        try verifyDiscreteFormatStyleConformance(style, samples: 100, message)

        style = .init(anchor: now, allowedFields: [.minute, .second], presentation: .numeric, unitsStyle: .abbreviated)
        style.calendar = self.calendar
        try verifyDiscreteFormatStyleConformance(style, samples: 100, message)

        style = .init(anchor: now, allowedFields: [.month], presentation: .numeric, unitsStyle: .abbreviated)
        style.calendar = self.calendar
        try verifyDiscreteFormatStyleConformance(style, samples: 100, message)

        style = .init(anchor: now, allowedFields: [.month, .week], presentation: .numeric, unitsStyle: .abbreviated)
        style.calendar = self.calendar
        try verifyDiscreteFormatStyleConformance(style, samples: 100, message)

        style = .init(anchor: now, allowedFields: [.month, .week, .day, .hour], presentation: .numeric, unitsStyle: .abbreviated)
        style.calendar = self.calendar
        try verifyDiscreteFormatStyleConformance(style, samples: 100, message)

        style = .init(anchor: now, allowedFields: [.year, .month, .day, .hour, .minute], presentation: .named, unitsStyle: .wide)
        style.calendar = self.calendar
        try verifyDiscreteFormatStyleConformance(style, samples: 100, message)
    }
#endif
}
