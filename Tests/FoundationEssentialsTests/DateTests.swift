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
import FoundationEssentials
#elseif FOUNDATION_FRAMEWORK
import Foundation
#endif

@Suite("Date")
private struct DateTests {

    @Test func comparison() {
        let d1 = Date()
        let d2 = d1 + 1

        #expect(d2 > d1)
        #expect(d1 < d2)

        let d3 = Date(timeIntervalSince1970: 12345)
        let d4 = Date(timeIntervalSince1970: 12345)

        #expect(d3 == d4)
        #expect(d3 <= d4)
        #expect(d4 >= d3)
    }

    @Test func mutation() {
        let d0 = Date()
        var d1 = Date()
        d1 = d1 + 1.0
        let d2 = Date(timeIntervalSinceNow: 10)

        #expect(d2 > d1)
        #expect(d1 != d0)

        let d3 = d1
        d1 += 10

        #expect(d1 > d3)
    }

    @Test func distantPast() {
        let distantPast = Date.distantPast
        let currentDate = Date()

        #expect(distantPast < currentDate)
        #expect(currentDate > distantPast)
        #expect(distantPast.timeIntervalSince(currentDate) <
                          3600.0 * 24 * 365 * 100) /* ~1 century in seconds */
    }

    @Test func distantFuture() {
        let distantFuture = Date.distantFuture
        let currentDate = Date()

        #expect(currentDate < distantFuture)
        #expect(distantFuture > currentDate)
        #expect(distantFuture.timeIntervalSince(currentDate) >
                              3600.0 * 24 * 365 * 100) /* ~1 century in seconds */
    }

    @Test func now() {
        let date1 : Date = .now
        let date2 : Date = .now

        #expect(date1 <= date2)
    }

    @Test func descriptionReferenceDate() {
        let date = Date(timeIntervalSinceReferenceDate: TimeInterval(0))

        #expect("2001-01-01 00:00:00 +0000" == date.description)
    }

    @Test func description1970() {
        let date = Date(timeIntervalSince1970: TimeInterval(0))

        #expect("1970-01-01 00:00:00 +0000" == date.description)
    }

    #if os(Windows)
    @Test(.disabled("ucrt does not support distant past"))
    #else
    @Test
    #endif
    func descriptionDistantPast() throws {
#if FOUNDATION_FRAMEWORK
        #expect("0001-01-01 00:00:00 +0000" == Date.distantPast.description)
#else
        #expect("0000-12-30 00:00:00 +0000" == Date.distantPast.description)
#endif
    }

    #if os(Windows)
    @Test(.disabled("ucrt does not support distant past"))
    #else
    @Test
    #endif
    func descriptionDistantFuture() throws {
        #expect("4001-01-01 00:00:00 +0000" == Date.distantFuture.description)
    }

    @Test func descriptionBeyondDistantPast() {
        let date = Date.distantPast.addingTimeInterval(TimeInterval(-1))
#if FOUNDATION_FRAMEWORK
        #expect("0000-12-31 23:59:59 +0000" == date.description)
#else
        #expect("<description unavailable>" == date.description)
#endif
    }

    @Test func descriptionBeyondDistantFuture() {
        let date = Date.distantFuture.addingTimeInterval(TimeInterval(1))
#if FOUNDATION_FRAMEWORK
        #expect("4001-01-01 00:00:01 +0000" == date.description)
#else
        #expect("<description unavailable>" == date.description)
#endif
    }
    
    @Test func nowIsAfterReasonableDate() {
        let date = Date.now
        #expect(date.timeIntervalSinceReferenceDate > 742100000.0) // "2024-07-08T02:53:20Z"
        #expect(date.timeIntervalSinceReferenceDate < 3896300000.0) // "2124-06-21T01:33:20Z"
    }
}

// MARK: - Bridging
#if FOUNDATION_FRAMEWORK
@Suite("Date Bridging")
private struct DateBridgingTests {
    @Test func cast() {
        let d0 = NSDate()
        let d1 = d0 as Date
        #expect(d0.timeIntervalSinceReferenceDate == d1.timeIntervalSinceReferenceDate)
    }

    @Test func anyHashableCreatedFromNSDate() {
        let values: [NSDate] = [
            NSDate(timeIntervalSince1970: 1000000000),
            NSDate(timeIntervalSince1970: 1000000001),
            NSDate(timeIntervalSince1970: 1000000001),
        ]
        let anyHashables = values.map(AnyHashable.init)
        #expect(Date.self == type(of: anyHashables[0].base))
        #expect(Date.self == type(of: anyHashables[1].base))
        #expect(Date.self == type(of: anyHashables[2].base))
        #expect(anyHashables[0] != anyHashables[1])
        #expect(anyHashables[1] == anyHashables[2])
    }

    @Test func anyHashableCreatedFromNSDateComponents() {
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
        #expect(DateComponents.self == type(of: anyHashables[0].base))
        #expect(DateComponents.self == type(of: anyHashables[1].base))
        #expect(DateComponents.self == type(of: anyHashables[2].base))
        #expect(anyHashables[0] != anyHashables[1])
        #expect(anyHashables[1] == anyHashables[2])
    }

    @Test func dateComponents_unconditionallyBridgeFromObjectiveC() {
        #expect(DateComponents() == DateComponents._unconditionallyBridgeFromObjectiveC(nil))
    }
}
#endif // FOUNDATION_FRAMEWORK
