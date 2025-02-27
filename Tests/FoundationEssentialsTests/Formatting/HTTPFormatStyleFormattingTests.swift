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

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#endif

final class HTTPFormatStyleFormattingTests: XCTestCase {
    
    func test_HTTPFormat() throws {
        let date = Date.now
        
        let formatted = date.formatted(.http) // e.g.  "Fri, 17 Jan 2025 19:03:05 GMT"
        let parsed = try? Date(formatted, strategy: .http)
        
        let result = try XCTUnwrap(parsed)
        XCTAssertEqual(date.timeIntervalSinceReferenceDate, result.timeIntervalSinceReferenceDate, accuracy: 1.0)
    }
    
    func test_HTTPFormat_components() throws {
        let date = Date.now
        let formatted = date.formatted(.http) // e.g.  "Fri, 17 Jan 2025 19:03:05 GMT"
        
        let parsed = try? DateComponents(formatted, strategy: .http)
        
        let result = try XCTUnwrap(parsed)
        
        let resultDate = Calendar(identifier: .gregorian).date(from: result)
        let resultDateUnwrapped = try XCTUnwrap(resultDate)
        
        XCTAssertEqual(date.timeIntervalSinceReferenceDate, resultDateUnwrapped.timeIntervalSinceReferenceDate, accuracy: 1.0)
    }
    
    func test_HTTPFormat_variousInputs() throws {
        let tests = [
            "Mon, 20 Jan 2025 01:02:03 GMT",
            "Tue, 20 Jan 2025 10:02:03 GMT",
            "Wed, 20 Jan 2025 23:02:03 GMT",
            "Thu, 20 Jan 2025 01:10:03 GMT",
            "Fri, 20 Jan 2025 01:50:59 GMT",
            "Sat, 20 Jan 2025 01:50:60 GMT", // 60 is valid, treated as 0
            "Sun, 20 Jan 2025 01:03:03 GMT",
            "20 Jan 2025 01:02:03 GMT", // Missing weekdays is ok
            "20 Jan 2025 10:02:03 GMT",
            "20 Jan 2025 23:02:03 GMT",
            "20 Jan 2025 01:10:03 GMT",
            "20 Jan 2025 01:50:59 GMT",
            "20 Jan 2025 01:50:60 GMT",
            "20 Jan 2025 01:03:03 GMT",
            "Mon, 20 Jan 2025 01:03:03 GMT",
            "Mon, 03 Feb 2025 01:03:03 GMT",
            "Mon, 03 Mar 2025 01:03:03 GMT",
            "Mon, 14 Apr 2025 01:03:03 GMT",
            "Mon, 05 May 2025 01:03:03 GMT",
            "Mon, 21 Jul 2025 01:03:03 GMT",
            "Mon, 04 Aug 2025 01:03:03 GMT",
            "Mon, 22 Sep 2025 01:03:03 GMT",
            "Mon, 30 Oct 2025 01:03:03 GMT",
            "Mon, 24 Nov 2025 01:03:03 GMT",
            "Mon, 22 Dec 2025 01:03:03 GMT",
            "Tue, 29 Feb 2028 01:03:03 GMT", // leap day
        ]
        
        for good in tests {
            XCTAssertNotNil(try? Date(good, strategy: .http), "Input \(good) was nil")
            XCTAssertNotNil(try? DateComponents(good, strategy: .http), "Input \(good) was nil")
        }
    }
    
    func test_HTTPFormat_badInputs() throws {
        let tests = [
            "Xri, 17 Jan 2025 19:03:05 GMT",
            "Fri, 17 Janu 2025 19:03:05 GMT",
            "Fri, 17Jan 2025 19:03:05 GMT",
            "Fri, 17 Xrz 2025 19:03:05 GMT",
            "Fri, 17 Jan 2025 19:03:05", // missing GMT
            "Fri, 1 Jan 2025 19:03:05 GMT",
            "Fri, 17 Jan 2025 1:03:05 GMT",
            "Fri, 17 Jan 2025 19:3:05 GMT",
            "Fri, 17 Jan 2025 19:03:5 GMT",
            "Fri, 17 Jan 2025 19:03:05 GmT",
            "Fri, 17 Jan 20252 19:03:05 GMT",
            "Fri, 17 Jan 252 19:03:05 GMT",
            "fri, 17 Jan 2025 19:03:05 GMT", // miscapitalized
            "Fri, 17 jan 2025 19:03:05 GMT",
            "Fri, 16 Jan 2025 25:03:05 GMT", // nonsense date
            "Fri, 30 Feb 2025 25:03:05 GMT", // nonsense date
        ]
        
        for bad in tests {
            XCTAssertNil(try? Date(bad, strategy: .http), "Input \(bad) was not nil")
            XCTAssertNil(try? DateComponents(bad, strategy: .http), "Input \(bad) was not nil")
        }
    }
    
    func test_HTTPComponentsFormat() throws {
        let input = "Fri, 17 Jan 2025 19:03:05 GMT"
        let parsed = try? DateComponents(input, strategy: .http)
        
        XCTAssertEqual(parsed?.weekday, 6)
        XCTAssertEqual(parsed?.day, 17)
        XCTAssertEqual(parsed?.month, 1)
        XCTAssertEqual(parsed?.year, 2025)
        XCTAssertEqual(parsed?.hour, 19)
        XCTAssertEqual(parsed?.minute, 3)
        XCTAssertEqual(parsed?.second, 5)
        XCTAssertEqual(parsed?.timeZone, TimeZone.gmt)
    }
    
    func test_validatingResultOfParseVsString() throws {
        // This date will parse correctly, but of course the value of 99 does not correspond to the actual day.
        let strangeDate = "Mon, 99 Jan 2025 19:03:05 GMT"
        let date = try XCTUnwrap(Date(strangeDate, strategy: .http))
        let components = try XCTUnwrap(DateComponents(strangeDate, strategy: .http))
        
        let actualDay = Calendar(identifier: .gregorian).component(.day, from: date)
        let componentDay = try XCTUnwrap(components.day)
        XCTAssertNotEqual(actualDay, componentDay)
    }
}

