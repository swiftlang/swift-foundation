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

/// A time zone that answers all queries from a `_TimeZoneRules` (transitions, offsets and a final DST rule). It does not use ICU.
package final class _TimeZoneRulesBased: _TimeZoneProtocol, Sendable {
    let rules: _TimeZoneRules

    package init(rules: _TimeZoneRules) {
        self.rules = rules
    }

    /// Creates a time zone from the built-in data. Returns nil if there is no data for `identifier`.
    required package init?(identifier: String) {
#if FOUNDATION_FRAMEWORK
        guard let rules = _timeZoneRules(forIdentifier: identifier) else {
            return nil
        }
        self.rules = rules
#else
        // There is no built-in data outside of Foundation.framework
        return nil
#endif
    }

    // Offset-only time zones are `_TimeZoneGMT`'s job
    required package init?(secondsFromGMT: Int) { nil }

    package var identifier: String {
        rules.identifier
    }

    package func secondsFromGMT(for date: Date) -> Int {
        rules.secondsFromGMT(for: date)
    }

    package func rawAndDaylightSavingTimeOffset(for date: Date, repeatedTimePolicy: TimeZone.DaylightSavingTimePolicy, skippedTimePolicy: TimeZone.DaylightSavingTimePolicy) -> (rawOffset: Int, daylightSavingOffset: TimeInterval) {
        let offsets = rules.rawAndDSTOffset(for: date, nonExistingTimePolicy: skippedTimePolicy, duplicatedTimePolicy: repeatedTimePolicy)
        return (offsets.0, TimeInterval(offsets.1))
    }

    package func abbreviation(for date: Date) -> String? {
        // No abbreviation data is kept; fall back to the GMT offset form
        _TimeZoneGMT.abbreviation(for: secondsFromGMT(for: date))
    }

    package func isDaylightSavingTime(for date: Date) -> Bool {
        rules.isDaylightSavingTime(for: date)
    }

    package func daylightSavingTimeOffset(for date: Date) -> TimeInterval {
        rules.daylightSavingTimeOffset(for: date)
    }

    package func nextDaylightSavingTimeTransition(after date: Date) -> Date? {
        rules.nextTransition(after: date)
    }

    package func localizedName(for style: TimeZone.NameStyle, locale: Locale?) -> String? {
        nil
    }
}
