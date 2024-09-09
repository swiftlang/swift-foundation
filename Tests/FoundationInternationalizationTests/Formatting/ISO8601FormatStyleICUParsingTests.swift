//
//  ISO8601FormatStyleICUParsingTests.swift
//  swift-foundation
//
//  Created by Jeremy Schonfeld on 8/26/24.
//

import Testing

#if canImport(FoundationInternationalization)
import FoundationInternationalization
import FoundationEssentials
#elseif FOUNDATION_FRAMEWORK
import Foundation
#endif

struct ISO8601FormatStyleICUParsingTests {
    @Test func test_chileTimeZone() throws {
        var iso8601Chile = Date.ISO8601FormatStyle().year().month().day()
        iso8601Chile.timeZone = try #require(TimeZone(identifier: "America/Santiago"))
        
        #expect(throws: Never.self) {
            try iso8601Chile.parse("2023-09-03")
        }
    }
}

