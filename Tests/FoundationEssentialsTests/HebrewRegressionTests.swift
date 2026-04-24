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

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable import FoundationEssentials
#endif

/// Full-range Hebrew regression test against the [Hebcal](https://www.hebcal.com/) reference
/// JS library. The CSV lists the Hebrew civil date (year, month-name, day) for every ISO day
/// from 1900-01-01 through 2100-12-31 — 73,414 rows.
///
/// **Month-numbering conventions differ between Hebcal and Foundation.** Hebcal uses DENSE
/// civil ordering (Adar = 6 in common years; Adar I = 6 / Adar II = 7 in leap years; Elul = 12
/// in common / 13 in leap). Foundation uses STABLE (ICU-style) ordering with Adar always = 7
/// in common, Adar I = 6 / Adar II = 7 in leap, and Elul always = 13. The mapping below
/// translates Hebcal month names to Foundation's stable civil ordinals.
///
/// The CSV currently lives outside this repo (in the private `icu4swift` workspace). The test
/// skips itself with a diagnostic message if the file isn't available on the host. When the
/// final PR is prepared, the CSV should move into Foundation's test bundle.
@Suite("Hebrew Calendar Regression", .disabled(if: !FileManager.default.fileExists(
    atPath: "/Users/draganbesevic/Projects/claude/CalendarAPI/icu4swift/Tests/CalendarComplexTests/hebrew_1900_2100_hebcal.csv"
)))
private struct HebrewCalendarRegressionTests {

    private static let csvPath = "/Users/draganbesevic/Projects/claude/CalendarAPI/icu4swift/Tests/CalendarComplexTests/hebrew_1900_2100_hebcal.csv"

    /// Maps a Hebcal month name to Foundation's civil ordinal (stable numbering).
    /// Returns nil if the name is not valid for the given year's leap status.
    private static func foundationCivilOrdinal(hebcalName: String, isLeap: Bool) -> Int? {
        switch hebcalName {
        case "Tishrei":  return 1
        case "Cheshvan": return 2
        case "Kislev":   return 3
        case "Tevet":    return 4
        case "Sh'vat":   return 5
        case "Adar":     return isLeap ? nil : 7   // Adar only valid in common year
        case "Adar I":   return isLeap ? 6 : nil   // Adar I only valid in leap year
        case "Adar II":  return isLeap ? 7 : nil   // Adar II only valid in leap year
        case "Nisan":    return 8
        case "Iyyar":    return 9
        case "Sivan":    return 10
        case "Tamuz":    return 11
        case "Av":       return 12
        case "Elul":     return 13
        default:         return nil
        }
    }

    @Test("Hebrew daily round-trip 1900-2100 vs Hebcal (73,414 days)")
    func hebrewDailyRegression() throws {
        let csvURL = URL(fileURLWithPath: Self.csvPath)
        let content = try String(contentsOf: csvURL, encoding: .utf8)
        // FoundationEssentials doesn't expose Foundation's `components(separatedBy:)`; use split.
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)

        // Set up calendars once. Both on UTC so we avoid DST shifting the civil-day boundary.
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = .gmt
        var hebrew = Calendar(identifier: .hebrew)
        hebrew.timeZone = .gmt

        var checked = 0
        var failures: [String] = []
        let maxReportedFailures = 20

        for i in 1..<lines.count {   // skip header
            let line = lines[i]
            if line.isEmpty { continue }
            let parts = line.split(separator: ",", omittingEmptySubsequences: false)
            guard parts.count == 6,
                  let gy = Int(parts[0]),
                  let gm = Int(parts[1]),
                  let gd = Int(parts[2]),
                  let hy = Int(parts[3]),
                  let hd = Int(parts[5])
            else { continue }
            let monthName = String(parts[4])

            // Construct a Gregorian date for this row, at noon UTC (avoids all boundary issues).
            var gc = DateComponents()
            gc.year = gy
            gc.month = gm
            gc.day = gd
            gc.hour = 12
            gc.timeZone = .gmt
            guard let date = gregorian.date(from: gc) else {
                failures.append("\(gy)-\(gm)-\(gd): Gregorian.date(from:) returned nil")
                continue
            }

            // Get Hebrew components from Foundation's .hebrew calendar (= our _CalendarHebrew).
            let hc = hebrew.dateComponents([.year, .month, .day], from: date)
            guard let gotYear = hc.year, let gotMonth = hc.month, let gotDay = hc.day else {
                failures.append("\(gy)-\(gm)-\(gd): Hebrew dateComponents returned incomplete result")
                continue
            }

            checked += 1

            // Derive Hebcal's leap status from the year itself (Metonic cycle), then translate
            // the month name into Foundation's stable civil ordinal.
            let isLeap = HebrewArithmetic.isLeapYear(Int32(hy))
            guard let expectedMonth = Self.foundationCivilOrdinal(hebcalName: monthName, isLeap: isLeap) else {
                failures.append("\(gy)-\(gm)-\(gd): bad Hebcal month name '\(monthName)' (heb \(hy), leap=\(isLeap))")
                continue
            }

            if gotYear != hy || gotMonth != expectedMonth || gotDay != hd {
                if failures.count < maxReportedFailures {
                    failures.append("\(gy)-\(gm)-\(gd): got heb \(gotYear)/\(gotMonth)/\(gotDay), expected \(hy)/\(expectedMonth)/\(hd) (\(monthName))")
                } else if failures.count == maxReportedFailures {
                    failures.append("… (truncating at \(maxReportedFailures) failures)")
                }
            }
        }

        print("Hebrew regression: checked \(checked) days, \(failures.count) failures")
        if !failures.isEmpty {
            for f in failures {
                print("  \(f)")
            }
        }
        #expect(failures.isEmpty, "\(failures.count) divergences from Hebcal over \(checked) days")
    }
}
