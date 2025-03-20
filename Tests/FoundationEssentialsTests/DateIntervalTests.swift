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
// REQUIRES: objc_interop

#if canImport(TestSupport)
import TestSupport
#endif

final class DateIntervalTests : XCTestCase {

    func test_compareDateIntervals() {
        // dateWithString("2010-05-17 14:49:47 -0700")
        let start = Date(timeIntervalSinceReferenceDate: 295825787.0)
        let duration: TimeInterval = 10000000.0
        let testInterval1 = DateInterval(start: start, duration: duration)
        let testInterval2 = DateInterval(start: start, duration: duration)
        XCTAssertEqual(testInterval1, testInterval2)
        XCTAssertEqual(testInterval2, testInterval1)
        XCTAssertEqual(testInterval1.compare(testInterval2), ComparisonResult.orderedSame)

        let testInterval3 = DateInterval(start: start, duration: 10000000000.0)
        XCTAssertTrue(testInterval1 < testInterval3)
        XCTAssertTrue(testInterval3 > testInterval1)

        // dateWithString("2009-05-17 14:49:47 -0700")
        let earlierStart = Date(timeIntervalSinceReferenceDate: 264289787.0)
        let testInterval4 = DateInterval(start: earlierStart, duration: duration)

        XCTAssertTrue(testInterval4 < testInterval1)
        XCTAssertTrue(testInterval1 > testInterval4)
    }

    func test_isEqualToDateInterval() {
        // dateWithString("2010-05-17 14:49:47 -0700")
        let start = Date(timeIntervalSinceReferenceDate: 295825787.0)
        let duration = 10000000.0
        let testInterval1 = DateInterval(start: start, duration: duration)
        let testInterval2 = DateInterval(start: start, duration: duration)

        XCTAssertEqual(testInterval1, testInterval2)

        let testInterval3 = DateInterval(start: start, duration: 100.0)
        XCTAssertNotEqual(testInterval1, testInterval3)
    }
    
    func test_intervalsBetweenDateIntervalAndDate() {
        let earlier = Date(timeIntervalSince1970: 0)
        let middle = Date(timeIntervalSince1970: 5)
        let later = Date(timeIntervalSince1970: 10)

        let start = Date(timeIntervalSince1970: 1)
        let duration: TimeInterval = 8
        let end = start.addingTimeInterval(duration) // 9
        let testInterval1 = DateInterval(start: start, duration: duration)

        // * --- |testInterval1|
        let t1 = testInterval1.timeIntervalSince(earlier)
        let d1 = testInterval1.dateIntervalSince(earlier)
        XCTAssertEqual(t1, 1)
        XCTAssertEqual(d1, DateInterval(start: earlier, end: start))

        // |testInterval1| --- *
        let t2 = testInterval1.timeIntervalSince(later)
        let d2 = testInterval1.dateIntervalSince(later)
        XCTAssertEqual(t2, -1)
        XCTAssertEqual(d2, DateInterval(start: end, end: later))

        // |  testInterval1 *  |
        let t3 = testInterval1.timeIntervalSince(middle)
        let d3 = testInterval1.dateIntervalSince(middle)
        XCTAssertEqual(t3, nil)
        XCTAssertEqual(d3, nil)

        // equal to start/end
        XCTAssertEqual(testInterval1.timeIntervalSince(start), 0)
        XCTAssertEqual(testInterval1.dateIntervalSince(start), DateInterval(start: start, duration: 0))
        XCTAssertEqual(testInterval1.timeIntervalSince(end), 0)
        XCTAssertEqual(testInterval1.dateIntervalSince(end), DateInterval(start: end, duration: 0))
    }
    
    func test_intervalsBetweenDateIntervals() {
        // Tests for intervals of zero or more duration between subjects.
        // |testInterval1|testInterval2|
        let testInterval1 = DateInterval(start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSinceReferenceDate: 0))
        let testInterval2 = DateInterval(start: Date(timeIntervalSinceReferenceDate: 0), end: Date(timeIntervalSinceReferenceDate: 100))
        let t1 = testInterval1.timeIntervalSince(testInterval2)
        XCTAssertEqual(t1, 0)
        
        let t2 = testInterval2.timeIntervalSince(testInterval1)
        XCTAssertEqual(t2, 0)
        
        let d1 = testInterval1.dateIntervalSince(testInterval2)
        XCTAssertEqual(d1?.start, testInterval1.end)
        XCTAssertEqual(d1?.duration, 0)
        
        let d2 = testInterval2.dateIntervalSince(testInterval1)
        XCTAssertEqual(d2?.start, testInterval1.end)
        XCTAssertEqual(d2?.duration, 0)
        
        XCTAssertEqual(d1, d2)
        
        // |testInterval3|-----|testInterval4|
        let testInterval3 = DateInterval(start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSinceReferenceDate: 0))
        let testInterval4 = DateInterval(start: Date(timeIntervalSinceReferenceDate: 1), end: Date(timeIntervalSinceReferenceDate: 100))
        let t3 = testInterval3.timeIntervalSince(testInterval4)
        XCTAssertEqual(t3, -1)
        
        let t4 = testInterval4.timeIntervalSince(testInterval3)
        XCTAssertEqual(t4, 1)
        
        let d3 = testInterval3.dateIntervalSince(testInterval4)
        let d4 = testInterval4.dateIntervalSince(testInterval3)
        XCTAssertEqual(d3?.duration, 1)
        XCTAssertEqual(d3?.start, testInterval3.end)
        XCTAssertEqual(d4?.duration, 1)
        XCTAssertEqual(d4?.start, testInterval3.end)
        
        // Tests for non-existing intervals between subjects.
        // |testInterval5|
        //      |testInterval6|
        //
        // As a single timeline: |555|565656|666|
        let testInterval5 = DateInterval(start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSinceReferenceDate: 0))
        let testInterval6 = DateInterval(start: Date(timeIntervalSinceReferenceDate: -1), end: Date(timeIntervalSinceReferenceDate: 100))
        let t5 = testInterval5.timeIntervalSince(testInterval6)
        XCTAssertEqual(t5, nil)
        
        let t6 = testInterval6.timeIntervalSince(testInterval5)
        XCTAssertEqual(t6, nil)
        
        let d5 = testInterval5.dateIntervalSince(testInterval6)
        XCTAssertEqual(d5, nil)
        
        let d6 = testInterval6.dateIntervalSince(testInterval5)
        XCTAssertEqual(d6, nil)
        
        // |---testInterval7---|
        //    |testInterval8|
        //
        // As a single timeline: |777|787878|777|
        let testInterval7 = DateInterval(start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSinceReferenceDate: 0))
        let testInterval8 = DateInterval(start: Date(timeIntervalSince1970: 10), end: Date(timeIntervalSince1970: 20))
        let t7 = testInterval7.timeIntervalSince(testInterval8)
        XCTAssertEqual(t7, nil)
        
        let t8 = testInterval8.timeIntervalSince(testInterval7)
        XCTAssertEqual(t8, nil)
        
        let d7 = testInterval7.dateIntervalSince(testInterval8)
        XCTAssertEqual(d7, nil)
        
        let d8 = testInterval8.dateIntervalSince(testInterval7)
        XCTAssertEqual(d8, nil)
        
        // |testInterval9|
        // |testInterval10---|
        let testInterval9 = DateInterval(start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSinceReferenceDate: 0))
        let testInterval10 = DateInterval(start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSinceReferenceDate: 100))
        let t9 = testInterval9.timeIntervalSince(testInterval10)
        XCTAssertEqual(t9, nil)
        
        let t10 = testInterval10.timeIntervalSince(testInterval9)
        XCTAssertEqual(t10, nil)
        
        let d9 = testInterval9.dateIntervalSince(testInterval10)
        XCTAssertEqual(d9, nil)
        
        let d10 = testInterval10.dateIntervalSince(testInterval9)
        XCTAssertEqual(d10, nil)
        
        // |testInterval11| on itself
        let testInterval11 = DateInterval(start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSinceReferenceDate: 0))
        let t11 = testInterval11.timeIntervalSince(testInterval11)
        XCTAssertEqual(t11, nil)
        
        let d11 = testInterval11.dateIntervalSince(testInterval11)
        XCTAssertEqual(d11, nil)
    }

    func test_hashing() {
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

    func test_checkIntersection() {
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

        XCTAssertTrue(testInterval1.intersects(testInterval2))

        // dateWithString("2010-10-17 14:49:47 -0700")
        let start3 = Date(timeIntervalSinceReferenceDate: 309044987.0)
        // dateWithString("2010-11-17 14:49:47 -0700")
        let end3 = Date(timeIntervalSinceReferenceDate: 311723387.0)

        let testInterval3 = DateInterval(start: start3, end: end3)

        XCTAssertFalse(testInterval1.intersects(testInterval3))
    }

    func test_validIntersections() {
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
        XCTAssertNotNil(intersection1)
        XCTAssertEqual(testInterval3, intersection1)

        let intersection2 = testInterval1.intersection(with: testInterval2)
        XCTAssertNotNil(intersection2)
        XCTAssertEqual(intersection1, intersection2)
    }

    func test_containsDate() {
        // dateWithString("2010-05-17 14:49:47 -0700")
        let start = Date(timeIntervalSinceReferenceDate: 295825787.0)
        let duration = 10000000.0

        let testInterval = DateInterval(start: start, duration: duration)
        // dateWithString("2010-05-17 20:49:47 -0700")
        let containedDate = Date(timeIntervalSinceReferenceDate: 295847387.0)

        XCTAssertTrue(testInterval.contains(containedDate))

        // dateWithString("2009-05-17 14:49:47 -0700")
        let earlierStart = Date(timeIntervalSinceReferenceDate: 264289787.0)
        XCTAssertFalse(testInterval.contains(earlierStart))
    }

    func test_AnyHashableContainingDateInterval() {
        // dateWithString("2010-05-17 14:49:47 -0700")
        let start = Date(timeIntervalSinceReferenceDate: 295825787.0)
        let duration = 10000000.0
        let values: [DateInterval] = [
            DateInterval(start: start, duration: duration),
            DateInterval(start: start, duration: duration / 2),
            DateInterval(start: start, duration: duration / 2),
        ]
        let anyHashables = values.map(AnyHashable.init)
        expectEqual(DateInterval.self, type(of: anyHashables[0].base))
        expectEqual(DateInterval.self, type(of: anyHashables[1].base))
        expectEqual(DateInterval.self, type(of: anyHashables[2].base))
        XCTAssertNotEqual(anyHashables[0], anyHashables[1])
        XCTAssertEqual(anyHashables[1], anyHashables[2])
    }
}

// MARK: - Bridging Tests
#if FOUNDATION_FRAMEWORK
extension DateIntervalTests {
    func test_AnyHashableCreatedFromNSDateInterval() {
        // dateWithString("2010-05-17 14:49:47 -0700")
        let start = Date(timeIntervalSinceReferenceDate: 295825787.0)
        let duration = 10000000.0
        let values: [NSDateInterval] = [
            NSDateInterval(start: start, duration: duration),
            NSDateInterval(start: start, duration: duration / 2),
            NSDateInterval(start: start, duration: duration / 2),
        ]
        let anyHashables = values.map(AnyHashable.init)
        expectEqual(DateInterval.self, type(of: anyHashables[0].base))
        expectEqual(DateInterval.self, type(of: anyHashables[1].base))
        expectEqual(DateInterval.self, type(of: anyHashables[2].base))
        XCTAssertNotEqual(anyHashables[0], anyHashables[1])
        XCTAssertEqual(anyHashables[1], anyHashables[2])
    }
}
#endif
