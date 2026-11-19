//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing

#if canImport(FoundationEssentials)
@testable import FoundationEssentials
#else
@testable import Foundation
#endif

@Suite("Rules-based TimeZone")
private struct RulesBasedTimeZoneTests {
    // Offsets are (raw, dst) pairs; the zone is UTC-8 standard time with 1h DST between two transitions.
    // 2024-03-10 10:00:00 UTC -> DST starts, 2024-11-03 09:00:00 UTC -> DST ends
    static let start: Int64 = 1710064800
    static let end: Int64 = 1730624400

    func makeZone() -> _TimeZoneRulesBased {
        let rules = _TimeZoneRules(identifier: "Test/Zone", transitions: [Self.start, Self.end], typeOffsets: [-28800, 0, -28800, 3600], typeMap: [1, 0])
        return _TimeZoneRulesBased(rules: rules)
    }

    @Test func offsets() {
        let tz = makeZone()
        let before = Date(timeIntervalSince1970: TimeInterval(Self.start - 1))
        let during = Date(timeIntervalSince1970: TimeInterval(Self.start + 1))
        let after = Date(timeIntervalSince1970: TimeInterval(Self.end + 1))

        #expect(tz.identifier == "Test/Zone")
        #expect(tz.secondsFromGMT(for: before) == -28800)
        #expect(tz.secondsFromGMT(for: during) == -25200)
        #expect(tz.secondsFromGMT(for: after) == -28800)
        #expect(!tz.isDaylightSavingTime(for: before))
        #expect(tz.isDaylightSavingTime(for: during))
        #expect(tz.daylightSavingTimeOffset(for: during) == 3600)
    }

    @Test func nextTransition() {
        let tz = makeZone()
        #expect(tz.nextDaylightSavingTimeTransition(after: Date(timeIntervalSince1970: 0)) == Date(timeIntervalSince1970: TimeInterval(Self.start)))
        #expect(tz.nextDaylightSavingTimeTransition(after: Date(timeIntervalSince1970: TimeInterval(Self.start))) == Date(timeIntervalSince1970: TimeInterval(Self.end)))
        #expect(tz.nextDaylightSavingTimeTransition(after: Date(timeIntervalSince1970: TimeInterval(Self.end))) == nil)
    }
}
