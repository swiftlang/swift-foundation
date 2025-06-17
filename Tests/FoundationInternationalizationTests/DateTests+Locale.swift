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

// TODO: Reenable these tests once DateFormatStyle has been ported
final class DateLocaleTests : XCTestCase {
#if FOUNDATION_FRAMEWORK
    func dateWithString(_ str: String) -> Date {
        let formatter = DateFormatter()
        // Note: Calendar(identifier:) is OSX 10.9+ and iOS 8.0+ whereas the CF version has always been available
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return formatter.date(from: str)! as Date
    }

    func testEquality() {
        let date = dateWithString("2010-05-17 14:49:47 -0700")
        let sameDate = dateWithString("2010-05-17 14:49:47 -0700")
        XCTAssertEqual(date, sameDate)
        XCTAssertEqual(sameDate, date)

        let differentDate = dateWithString("2010-05-17 14:49:46 -0700")
        XCTAssertNotEqual(date, differentDate)
        XCTAssertNotEqual(differentDate, date)

        let sameDateByTimeZone = dateWithString("2010-05-17 13:49:47 -0800")
        XCTAssertEqual(date, sameDateByTimeZone)
        XCTAssertEqual(sameDateByTimeZone, date)

        let differentDateByTimeZone = dateWithString("2010-05-17 14:49:47 -0800")
        XCTAssertNotEqual(date, differentDateByTimeZone)
        XCTAssertNotEqual(differentDateByTimeZone, date)
    }

    func testTimeIntervalSinceDate() {
        let referenceDate = dateWithString("1900-01-01 00:00:00 +0000")
        let sameDate = dateWithString("1900-01-01 00:00:00 +0000")
        let laterDate = dateWithString("2010-05-17 14:49:47 -0700")
        let earlierDate = dateWithString("1810-05-17 14:49:47 -0700")

        let laterSeconds = laterDate.timeIntervalSince(referenceDate)
        XCTAssertEqual(laterSeconds, 3483121787.0)

        let earlierSeconds = earlierDate.timeIntervalSince(referenceDate)
        XCTAssertEqual(earlierSeconds, -2828311813.0)

        let sameSeconds = sameDate.timeIntervalSince(referenceDate)
        XCTAssertEqual(sameSeconds, 0.0)
    }

    func test_DateHashing() {
        let values: [Date] = [
            dateWithString("2010-05-17 14:49:47 -0700"),
            dateWithString("2011-05-17 14:49:47 -0700"),
            dateWithString("2010-06-17 14:49:47 -0700"),
            dateWithString("2010-05-18 14:49:47 -0700"),
            dateWithString("2010-05-17 15:49:47 -0700"),
            dateWithString("2010-05-17 14:50:47 -0700"),
            dateWithString("2010-05-17 14:49:48 -0700"),
        ]
        XCTCheckHashable(values, equalityOracle: { $0 == $1 })
    }

    func test_AnyHashableContainingDate() {
        let values: [Date] = [
            dateWithString("2016-05-17 14:49:47 -0700"),
            dateWithString("2010-05-17 14:49:47 -0700"),
            dateWithString("2010-05-17 14:49:47 -0700"),
        ]
        let anyHashables = values.map(AnyHashable.init)
        expectEqual(Date.self, type(of: anyHashables[0].base))
        expectEqual(Date.self, type(of: anyHashables[1].base))
        expectEqual(Date.self, type(of: anyHashables[2].base))
        XCTAssertNotEqual(anyHashables[0], anyHashables[1])
        XCTAssertEqual(anyHashables[1], anyHashables[2])
    }
#endif
}
