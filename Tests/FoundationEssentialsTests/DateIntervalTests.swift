// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing

#if canImport(TestSupport)
import TestSupport
#endif

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif FOUNDATION_FRAMEWORK
import Foundation
#endif

struct DateIntervalTests {

    @Test func test_compareDateIntervals() {
        // dateWithString("2010-05-17 14:49:47 -0700")
        let start = Date(timeIntervalSinceReferenceDate: 295825787.0)
        let duration: TimeInterval = 10000000.0
        let testInterval1 = DateInterval(start: start, duration: duration)
        let testInterval2 = DateInterval(start: start, duration: duration)
        #expect(testInterval1 == testInterval2)
        #expect(testInterval2 == testInterval1)
        #expect(testInterval1.compare(testInterval2) == .orderedSame)

        let testInterval3 = DateInterval(start: start, duration: 10000000000.0)
        #expect(testInterval1 < testInterval3)
        #expect(testInterval3 > testInterval1)

        // dateWithString("2009-05-17 14:49:47 -0700")
        let earlierStart = Date(timeIntervalSinceReferenceDate: 264289787.0)
        let testInterval4 = DateInterval(start: earlierStart, duration: duration)

        #expect(testInterval4 < testInterval1)
        #expect(testInterval1 > testInterval4)
    }

    @Test func test_isEqualToDateInterval() {
        // dateWithString("2010-05-17 14:49:47 -0700")
        let start = Date(timeIntervalSinceReferenceDate: 295825787.0)
        let duration = 10000000.0
        let testInterval1 = DateInterval(start: start, duration: duration)
        let testInterval2 = DateInterval(start: start, duration: duration)

        #expect(testInterval1 == testInterval2)

        let testInterval3 = DateInterval(start: start, duration: 100.0)
        #expect(testInterval1 != testInterval3)
    }

    @Test func test_hashing() {
        // dateWithString("2019-04-04 17:09:23 -0700")
        let start1a = Date(timeIntervalSinceReferenceDate: 576115763.0)
        let start1b = Date(timeIntervalSinceReferenceDate: 576115763.0)
        let start2a = Date(timeIntervalSinceReferenceDate: start1a.timeIntervalSinceReferenceDate.nextUp)
        let start2b = Date(timeIntervalSinceReferenceDate: start1a.timeIntervalSinceReferenceDate.nextUp)
        let duration1 = 1800.0
        let duration2 = duration1.nextUp
        let intervals: [[DateInterval]] = [
            [
                DateInterval(start: start1a, duration: duration1),
                DateInterval(start: start1b, duration: duration1),
            ],
            [
                DateInterval(start: start1a, duration: duration2),
                DateInterval(start: start1b, duration: duration2),
            ],
            [
                DateInterval(start: start2a, duration: duration1),
                DateInterval(start: start2b, duration: duration1),
            ],
            [
                DateInterval(start: start2a, duration: duration2),
                DateInterval(start: start2b, duration: duration2),
            ],
        ]
        checkHashableGroups(intervals)
    }

    @Test func test_checkIntersection() {
        // dateWithString("2010-05-17 14:49:47 -0700")
        let start1 = Date(timeIntervalSinceReferenceDate: 295825787.0)
        // dateWithString("2010-08-17 14:49:47 -0700")
        let end1 = Date(timeIntervalSinceReferenceDate: 303774587.0)

        let testInterval1 = DateInterval(start: start1, end: end1)

        // dateWithString("2010-02-17 14:49:47 -0700")
        let start2 = Date(timeIntervalSinceReferenceDate: 288136187.0)
        // dateWithString("2010-07-17 14:49:47 -0700")
        let end2 = Date(timeIntervalSinceReferenceDate: 301096187.0)

        let testInterval2 = DateInterval(start: start2, end: end2)

        #expect(testInterval1.intersects(testInterval2))

        // dateWithString("2010-10-17 14:49:47 -0700")
        let start3 = Date(timeIntervalSinceReferenceDate: 309044987.0)
        // dateWithString("2010-11-17 14:49:47 -0700")
        let end3 = Date(timeIntervalSinceReferenceDate: 311723387.0)

        let testInterval3 = DateInterval(start: start3, end: end3)

        #expect(!testInterval1.intersects(testInterval3))
    }

    @Test func test_validIntersections() {
        // dateWithString("2010-05-17 14:49:47 -0700")
        let start1 = Date(timeIntervalSinceReferenceDate: 295825787.0)
        // dateWithString("2010-08-17 14:49:47 -0700")
        let end1 = Date(timeIntervalSinceReferenceDate: 303774587.0)

        let testInterval1 = DateInterval(start: start1, end: end1)

        // dateWithString("2010-02-17 14:49:47 -0700")
        let start2 = Date(timeIntervalSinceReferenceDate: 288136187.0)
        // dateWithString("2010-07-17 14:49:47 -0700")
        let end2 = Date(timeIntervalSinceReferenceDate: 301096187.0)

        let testInterval2 = DateInterval(start: start2, end: end2)

        // dateWithString("2010-05-17 14:49:47 -0700")
        let start3 = Date(timeIntervalSinceReferenceDate: 295825787.0)
        // dateWithString("2010-07-17 14:49:47 -0700")
        let end3 = Date(timeIntervalSinceReferenceDate: 301096187.0)

        let testInterval3 = DateInterval(start: start3, end: end3)

        let intersection1 = testInterval2.intersection(with: testInterval1)
        #expect(testInterval3 == intersection1)

        let intersection2 = testInterval1.intersection(with: testInterval2)
        #expect(intersection1 == intersection2)
    }

    @Test func test_containsDate() {
        // dateWithString("2010-05-17 14:49:47 -0700")
        let start = Date(timeIntervalSinceReferenceDate: 295825787.0)
        let duration = 10000000.0

        let testInterval = DateInterval(start: start, duration: duration)
        // dateWithString("2010-05-17 20:49:47 -0700")
        let containedDate = Date(timeIntervalSinceReferenceDate: 295847387.0)

        #expect(testInterval.contains(containedDate))

        // dateWithString("2009-05-17 14:49:47 -0700")
        let earlierStart = Date(timeIntervalSinceReferenceDate: 264289787.0)
        #expect(!testInterval.contains(earlierStart))
    }

    @Test func test_AnyHashableContainingDateInterval() {
        // dateWithString("2010-05-17 14:49:47 -0700")
        let start = Date(timeIntervalSinceReferenceDate: 295825787.0)
        let duration = 10000000.0
        let values: [DateInterval] = [
            DateInterval(start: start, duration: duration),
            DateInterval(start: start, duration: duration / 2),
            DateInterval(start: start, duration: duration / 2),
        ]
        let anyHashables = values.map(AnyHashable.init)
        #expect(DateInterval.self == type(of: anyHashables[0].base))
        #expect(DateInterval.self == type(of: anyHashables[1].base))
        #expect(DateInterval.self == type(of: anyHashables[2].base))
        #expect(anyHashables[0] != anyHashables[1])
        #expect(anyHashables[1] == anyHashables[2])
    }
}

// MARK: - Bridging Tests
#if FOUNDATION_FRAMEWORK
extension DateIntervalTests {
    @Test func test_AnyHashableCreatedFromNSDateInterval() {
        // dateWithString("2010-05-17 14:49:47 -0700")
        let start = Date(timeIntervalSinceReferenceDate: 295825787.0)
        let duration = 10000000.0
        let values: [NSDateInterval] = [
            NSDateInterval(start: start, duration: duration),
            NSDateInterval(start: start, duration: duration / 2),
            NSDateInterval(start: start, duration: duration / 2),
        ]
        let anyHashables = values.map(AnyHashable.init)
        #expect(DateInterval.self == type(of: anyHashables[0].base))
        #expect(DateInterval.self == type(of: anyHashables[1].base))
        #expect(DateInterval.self == type(of: anyHashables[2].base))
        #expect(anyHashables[0] != anyHashables[1])
        #expect(anyHashables[1] == anyHashables[2])
    }
}
#endif
