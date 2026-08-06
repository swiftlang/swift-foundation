//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing

#if canImport(FoundationInternationalization)
import FoundationEssentials
import FoundationInternationalization
#else
import Foundation
#endif

@Suite("ISO8601FormatStyle Parsing (Internationalization)")
private struct ISO8601FormatStyleInternationalizationParsingTests {
    @Test func chileTimeZone() throws {
        var iso8601Chile = Date.ISO8601FormatStyle().year().month().day()
        iso8601Chile.timeZone = try #require(TimeZone(identifier: "America/Santiago"))
        
        #expect(throws: Never.self) {
            try iso8601Chile.parse("2023-09-03")
        }
    }
}
