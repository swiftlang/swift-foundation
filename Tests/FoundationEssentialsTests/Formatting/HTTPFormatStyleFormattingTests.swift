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
#else
import Foundation
#endif

@Suite("HTTPFormatStyle Formatting")
private struct HTTPFormatStyleFormattingTests {
    
    @Test func basics() throws {
        let date = Date.now
        
        let formatted = date.formatted(.http) // e.g.  "Fri, 17 Jan 2025 19:03:05 GMT"
        let parsed = try Date(formatted, strategy: .http)
        
        #expect(abs(date.timeIntervalSinceReferenceDate - parsed.timeIntervalSinceReferenceDate) <= 1.0)
    }
    
    @Test func components() throws {
        let date = Date.now
        let formatted = date.formatted(.http) // e.g.  "Fri, 17 Jan 2025 19:03:05 GMT"
        
        let parsed = try DateComponents(formatted, strategy: .http)
        
        let resultDate = Calendar(identifier: .gregorian).date(from: parsed)
        let resultDateUnwrapped = try #require(resultDate)
        
        #expect(abs(date.timeIntervalSinceReferenceDate - resultDateUnwrapped.timeIntervalSinceReferenceDate) <= 1.0)
    }
    
    @Test(arguments: [
        "Mon, 20 Jan 2025 01:02:03 GMT",
        "Tue, 20 Jan 2025 10:02:03 GMT",
        "Wed, 20 Jan 2025 23:02:03 GMT",
        "Thu, 20 Jan 2025 01:10:03 GMT",
        "Fri, 20 Jan 2025 01:50:59 GMT",
        "Sat, 20 Jan 2025 01:50:60 GMT", // 60 is valid, adjusted to 59
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
        "Mon, 01 Jan 1900 00:00:00 GMT", // the earliest year allowed by the spec
    ])
    func variousInputs(good: String) {
        #expect(throws: Never.self) {
            try Date(good, strategy: .http)
        }
        #expect(throws: Never.self) {
            try DateComponents(good, strategy: .http)
        }
    }
    
    @Test(arguments: [
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
        "Mon, 00 Jan 2025 19:03:05 GMT", // out of bounds days
        "Mon, 32 Jan 2025 19:03:05 GMT", // out of bounds days
        "Mon, 99 Jan 2025 19:03:05 GMT", // out of bounds days
        "Mon, 01 Jan 1899 19:03:05 GMT", // out of bounds year, the spec allows 1900 or later
        "Mon, 01 Jan 0000 19:03:05 GMT", // out of bounds year
        "Mon, 01 Jan 2025 24:03:05 GMT", // out of bounds hours
        "Mon, 01 Jan 2025 25:03:05 GMT", // out of bounds hours
        "Mon, 02 Jan 2025 19:60:05 GMT", // out of bounds mins
        "Mon, 02 Jan 2025 19:62:05 GMT", // out of bounds mins
        "Mon, 03 Jan 2025 19:03:61 GMT", // out of bounds secs, 60 is allowed for leap seconds
        "Mon, 03 Jan 2025 19:03:70 GMT", // out of bounds secs
    ])
    func badInputs(bad: String) {
        #expect(throws: (any Error).self) {
            try Date(bad, strategy: .http)
        }
        #expect(throws: (any Error).self) {
            try DateComponents(bad, strategy: .http)
        }
    }
    
    @Test func componentsFormat() throws {
        let input = "Fri, 17 Jan 2025 19:03:05 GMT"
        let parsed = try DateComponents(input, strategy: .http)
        
        #expect(parsed.weekday == 6)
        #expect(parsed.day == 17)
        #expect(parsed.month == 1)
        #expect(parsed.year == 2025)
        #expect(parsed.hour == 19)
        #expect(parsed.minute == 3)
        #expect(parsed.second == 5)
        #expect(parsed.timeZone == TimeZone.gmt)
    }

    @Test func leapSecond() throws {
        // Foundation does not support leap seconds, so a second of 60 is adjusted to 59
        let parsed = try DateComponents("Sat, 20 Jan 2025 01:50:60 GMT", strategy: .http)
        #expect(parsed.second == 59)
        #expect(try Date("Sat, 20 Jan 2025 01:50:60 GMT", strategy: .http) == Date("Sat, 20 Jan 2025 01:50:59 GMT", strategy: .http))
    }
}

