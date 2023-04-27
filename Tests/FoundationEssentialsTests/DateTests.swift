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

final class DateTests: XCTestCase {

    func testDateComparison() {
        let d1 = Date()
        let d2 = d1 + 1

        XCTAssertTrue(d2 > d1)
        XCTAssertTrue(d1 < d2)

        let d3 = Date(timeIntervalSince1970: 12345)
        let d4 = Date(timeIntervalSince1970: 12345)

        XCTAssertTrue(d3 == d4)
        XCTAssertTrue(d3 <= d4)
        XCTAssertTrue(d4 >= d3)
    }

    func testDateMutation() {
        let d0 = Date()
        var d1 = Date()
        d1 = d1 + 1.0
        let d2 = Date(timeIntervalSinceNow: 10)

        XCTAssertTrue(d2 > d1)
        XCTAssertTrue(d1 != d0)

        let d3 = d1
        d1 += 10
        XCTAssertTrue(d1 > d3)
    }

    func testDistantPast() {
        let distantPast = Date.distantPast
        let currentDate = Date()
        XCTAssertTrue(distantPast < currentDate)
        XCTAssertTrue(currentDate > distantPast)
        XCTAssertTrue(distantPast.timeIntervalSince(currentDate) < 3600.0*24*365*100) /* ~1 century in seconds */
    }

    func testDistantFuture() {
        let distantFuture = Date.distantFuture
        let currentDate = Date()
        XCTAssertTrue(currentDate < distantFuture)
        XCTAssertTrue(distantFuture > currentDate)
        XCTAssertTrue(distantFuture.timeIntervalSince(currentDate) > 3600.0*24*365*100) /* ~1 century in seconds */
    }

    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    func test_now() {
        let date1: Date = .now
        let date2: Date = .now
        XCTAssertLessThanOrEqual(date1, date2)
    }
}

// MARK: - Bridging
#if FOUNDATION_FRAMEWORK
final class DateBridgingTests: XCTestCase {
    func testCast() {
        let d0 = NSDate()
        let d1 = d0 as Date
        XCTAssertEqual(d0.timeIntervalSinceReferenceDate, d1.timeIntervalSinceReferenceDate)
    }

    func test_AnyHashableCreatedFromNSDate() {
        let values: [NSDate] = [
            NSDate(timeIntervalSince1970: 1000000000),
            NSDate(timeIntervalSince1970: 1000000001),
            NSDate(timeIntervalSince1970: 1000000001)
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
            makeNSDateComponents(year: 1995)
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
