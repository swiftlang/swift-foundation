//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK
import Foundation
import XCTest

final class TestCalendarPerformance: XCTestCase {

    var metrics: [XCTMetric] {
        // XCTMemoryMetric is randomly reporting 0kb for memory usage.
        [/*XCTMemoryMetric(),*/ XCTCPUMetric()]
    }

    var options: XCTMeasureOptions {
        let opts = XCTMeasureOptions.default
        opts.iterationCount = 10
        return opts
    }

    func test_nextThousandThanksgivings() {
        measure(metrics: metrics, options: self.options) {
            let dc = DateComponents(month: 11, weekday: 5, weekOfMonth: 4)
            let cal = Calendar(identifier: .gregorian)
            let start = Date(timeIntervalSinceReferenceDate: 496359355.795410) //2016-09-23T14:35:55-0700

            var count = 1000
            cal.enumerateDates(startingAfter: start, matching: dc, matchingPolicy: .nextTime) { result, exactMatch, stop in
                count -= 1
                if count == 0 {
                    stop = true
                }
            }
        }
    }

    func test_allocationsForFixedCalendars() {
        let reference = Date(timeIntervalSinceReferenceDate: 496359355.795410) //2016-09-23T14:35:55-0700
        measure(metrics: metrics, options: self.options) {
            // Fixed calendar
            for _ in 0..<10000 {
                let cal = Calendar(identifier: .gregorian)
                let date = cal.date(byAdding: .day, value: 1, to: reference)
                XCTAssertTrue(date != nil)
            }
        }
    }

    func test_allocationsForCurrentCalendar() {
        let reference = Date(timeIntervalSinceReferenceDate: 496359355.795410) //2016-09-23T14:35:55-0700
        measure(metrics: metrics, options: self.options) {
            for _ in 0..<10000 {
                let cal = Calendar.current
                let date = cal.date(byAdding: .day, value: 1, to: reference)
                XCTAssertTrue(date != nil)
            }
        }
    }

    func test_allocationsForAutoupdatingCurrentCalendar() {
        let reference = Date(timeIntervalSinceReferenceDate: 496359355.795410) //2016-09-23T14:35:55-0700
        measure(metrics: metrics, options: self.options) {
            for _ in 0..<10000 {
                let cal = Calendar.autoupdatingCurrent
                let date = cal.date(byAdding: .day, value: 1, to: reference)
                XCTAssertTrue(date != nil)
            }
        }
    }

    func test_copyOnWritePerformance() {
        let reference = Date(timeIntervalSinceReferenceDate: 496359355.795410) //2016-09-23T14:35:55-0700
        measure(metrics: metrics, options: self.options) {
            var cal = Calendar(identifier: .gregorian)
            for i in 0..<10000 {
                cal.firstWeekday = i % 2
                let date = cal.date(byAdding: .day, value: 1, to: reference)
                XCTAssertNotNil(date)
            }
        }
    }
}
#endif
