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

final class DateTests : XCTestCase {

    func testDateComparison() {
        let d1 = Date()
        let d2 = d1 + 1

        XCTAssertGreaterThan(d2, d1)
        XCTAssertLessThan(d1, d2)

        let d3 = Date(timeIntervalSince1970: 12345)
        let d4 = Date(timeIntervalSince1970: 12345)

        XCTAssertEqual(d3, d4)
        XCTAssertLessThanOrEqual(d3, d4)
        XCTAssertGreaterThanOrEqual(d4, d3)
    }

    func testDateMutation() {
        let d0 = Date()
        var d1 = Date()
        d1 = d1 + 1.0
        let d2 = Date(timeIntervalSinceNow: 10)

        XCTAssertGreaterThan(d2, d1)
        XCTAssertNotEqual(d1, d0)

        let d3 = d1
        d1 += 10

        XCTAssertGreaterThan(d1, d3)
    }

    func testDistantPast() {
        let distantPast = Date.distantPast
        let currentDate = Date()

        XCTAssertLessThan(distantPast, currentDate)
        XCTAssertGreaterThan(currentDate, distantPast)
        XCTAssertLessThan(distantPast.timeIntervalSince(currentDate),
                          3600.0 * 24 * 365 * 100) /* ~1 century in seconds */
    }

    func testDistantFuture() {
        let distantFuture = Date.distantFuture
        let currentDate = Date()

        XCTAssertLessThan(currentDate, distantFuture)
        XCTAssertGreaterThan(distantFuture, currentDate)
        XCTAssertGreaterThan(distantFuture.timeIntervalSince(currentDate),
                              3600.0 * 24 * 365 * 100) /* ~1 century in seconds */
    }

    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    func test_now() {
        let date1 : Date = .now
        let date2 : Date = .now

        XCTAssertLessThanOrEqual(date1, date2)
    }

    func testDescriptionReferenceDate() {
        let date = Date(timeIntervalSinceReferenceDate: TimeInterval(0))

        XCTAssertEqual("2001-01-01 00:00:00 +0000", date.description)
    }

    func testDescription1970() {
        let date = Date(timeIntervalSince1970: TimeInterval(0))

        XCTAssertEqual("1970-01-01 00:00:00 +0000", date.description)
    }

    func testDescriptionDistantPast() {
#if FOUNDATION_FRAMEWORK
        XCTAssertEqual("0001-01-01 00:00:00 +0000", Date.distantPast.description)
#else
        XCTAssertEqual("0000-12-30 00:00:00 +0000", Date.distantPast.description)
#endif
    }

    func testDescriptionDistantFuture() {
        XCTAssertEqual("4001-01-01 00:00:00 +0000", Date.distantFuture.description)
    }

    func testDescriptionBeyondDistantPast() {
        let date = Date.distantPast.addingTimeInterval(TimeInterval(-1))
#if FOUNDATION_FRAMEWORK
        XCTAssertEqual("0000-12-31 23:59:59 +0000", date.description)
#else
        XCTAssertEqual("<description unavailable>", date.description)
#endif
    }

    func testDescriptionBeyondDistantFuture() {
        let date = Date.distantFuture.addingTimeInterval(TimeInterval(1))
#if FOUNDATION_FRAMEWORK
        XCTAssertEqual("4001-01-01 00:00:01 +0000", date.description)
#else
        XCTAssertEqual("<description unavailable>", date.description)
#endif
    }
}

// MARK: - Bridging
#if FOUNDATION_FRAMEWORK
final class DateBridgingTests : XCTestCase {
    func testCast() {
        let d0 = NSDate()
        let d1 = d0 as Date
        XCTAssertEqual(d0.timeIntervalSinceReferenceDate, d1.timeIntervalSinceReferenceDate)
    }

    func test_AnyHashableCreatedFromNSDate() {
        let values: [NSDate] = [
            NSDate(timeIntervalSince1970: 1000000000),
            NSDate(timeIntervalSince1970: 1000000001),
            NSDate(timeIntervalSince1970: 1000000001),
        ]
        let anyHashables = values.map(AnyHashable.init)
        expectEqual(Date.self, type(of: anyHashables[0].base))
        expectEqual(Date.self, type(of: anyHashables[1].base))
        expectEqual(Date.self, type(of: anyHashables[2].base))
        XCTAssertNotEqual(anyHashables[0], anyHashables[1])
        XCTAssertEqual(anyHashables[1], anyHashables[2])
    }

    func test_AnyHashableCreatedFromNSDateComponents() {
        func makeNSDateComponents(year: Int) -> NSDateComponents {
            let result = NSDateComponents()
            result.year = year
            return result
        }
        let values: [NSDateComponents] = [
            makeNSDateComponents(year: 2016),
            makeNSDateComponents(year: 1995),
            makeNSDateComponents(year: 1995),
        ]
        let anyHashables = values.map(AnyHashable.init)
        expectEqual(DateComponents.self, type(of: anyHashables[0].base))
        expectEqual(DateComponents.self, type(of: anyHashables[1].base))
        expectEqual(DateComponents.self, type(of: anyHashables[2].base))
        XCTAssertNotEqual(anyHashables[0], anyHashables[1])
        XCTAssertEqual(anyHashables[1], anyHashables[2])
    }

    func test_dateComponents_unconditionallyBridgeFromObjectiveC() {
        XCTAssertEqual(DateComponents(), DateComponents._unconditionallyBridgeFromObjectiveC(nil))
    }
}
#endif // FOUNDATION_FRAMEWORK
