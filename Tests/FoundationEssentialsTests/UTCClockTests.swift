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

@available(FoundationPreview 6.2, *)
final class UTCClockTests : XCTestCase {
    
    func testAdvancingDate() {
        let date = Date(timeIntervalSince1970: 1000000000)
        
        // Test advancing by a positive duration
        let duration = Duration.seconds(3600)
        let advancedDate = date.advanced(by: duration)
        XCTAssertEqual(advancedDate.timeIntervalSince1970, 1000003600)
        
        // Test advancing by a negative duration
        let negativeDuration = Duration.seconds(-3600)
        let reverseAdvancedDate = date.advanced(by: negativeDuration)
        XCTAssertEqual(reverseAdvancedDate.timeIntervalSince1970, 999996400)
        
        // Test advancing with fractional seconds
        let fractionalDuration = Duration.seconds(1.5)
        let fractionalAdvancedDate = date.advanced(by: fractionalDuration)
        XCTAssertEqual(fractionalAdvancedDate.timeIntervalSince1970, 1000000001.5)
    }
    
    func testDateDurationTo() {
        let start = Date(timeIntervalSince1970: 1000000000)
        let end = Date(timeIntervalSince1970: 1000003600)
        
        // Test positive duration
        let duration = start.duration(to: end)
        XCTAssertEqual(Duration.seconds(3600), duration)
        
        // Test negative duration
        let reverseDuration = end.duration(to: start)
        XCTAssertEqual(Duration.seconds(-3600), reverseDuration)
        
        // Test with fractional seconds
        let fractionalEnd = Date(timeIntervalSince1970: 1000000001.5)
        let fractionalDuration = start.duration(to: fractionalEnd)
        XCTAssertEqual(Duration.seconds(1.5), fractionalDuration)
    }
    
    func testLeapSeconds() {
        // Test a period from 1971 to 2017 that includes 27 leap seconds
        let start = Calendar(identifier: .gregorian).date(from: DateComponents(timeZone: .gmt, year: 1971, month: 1, day: 1))!
        let end = Calendar(identifier: .gregorian).date(from: DateComponents(timeZone: .gmt, year: 2017, month: 1, day: 1))!
        
        let leapSeconds = Date.leapSeconds(from: start, to: end)
        XCTAssertEqual(leapSeconds, .seconds(27))
        
        // Test that leap seconds in the reverse direction have the opposite sign
        let reverseLeapSeconds = Date.leapSeconds(from: end, to: start)
        XCTAssertEqual(reverseLeapSeconds, .seconds(-27))
        
        // Test a period with no leap seconds
        let noLeapStart = Calendar(identifier: .gregorian).date(from: DateComponents(timeZone: .gmt, year: 2020, month: 1, day: 1))!
        let noLeapEnd = Calendar(identifier: .gregorian).date(from: DateComponents(timeZone: .gmt, year: 2023, month: 1, day: 1))!
        
        let noLeapSeconds = Date.leapSeconds(from: noLeapStart, to: noLeapEnd)
        XCTAssertEqual(noLeapSeconds, .seconds(0))
    }
    
    func testUTCClock() {
        let clock = UTCClock()
        
        // Test that now returns the current date
        let now = clock.now
        let currentDate = Date()
        XCTAssertEqual(now.timeIntervalSince(currentDate).magnitude < 1, true)
        
        // Test epoch is January 1, 2001
        XCTAssertEqual(UTCClock.systemEpoch, Date(timeIntervalSinceReferenceDate: 0))
        
        // Test minimum resolution
        XCTAssertEqual(clock.minimumResolution, .nanoseconds(1))
    }
}
