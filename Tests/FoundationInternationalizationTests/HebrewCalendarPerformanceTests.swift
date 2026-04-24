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
@testable import FoundationInternationalization
@testable import FoundationEssentials
#endif

// Reference date matches Apple's Gregorian CalendarPerformanceTests:
// 2016-09-23T14:35:55-0700
private let referenceDate = Date(timeIntervalSinceReferenceDate: 496359355.795410)

private let warmupIterations = 100
private let timedRuns = 5

// Runs `body` `timedRuns` times and returns the min/max elapsed seconds.
// Debug-mode run-to-run variance is high; reporting min isolates the measurement
// from transient system noise (background activity, page faults, etc.).
private func repeatedTimed(_ body: () -> Void) -> (minElapsed: Double, maxElapsed: Double) {
    var minT = Double.infinity
    var maxT = 0.0
    for _ in 0..<timedRuns {
        let t0 = ProcessInfo.processInfo.systemUptime
        body()
        let elapsed = ProcessInfo.processInfo.systemUptime - t0
        minT = min(minT, elapsed)
        maxT = max(maxT, elapsed)
    }
    return (minT, maxT)
}

private func report(
    _ label: String,
    iterations: Int,
    unit: String,
    scale: Double,      // e.g. 1e9 for ns, 1e6 for µs
    minT: Double,
    maxT: Double
) {
    let minTotalMs = Int(minT * 1000)
    let maxTotalMs = Int(maxT * 1000)
    let minPer = Int(minT * scale / Double(iterations))
    let maxPer = Int(maxT * scale / Double(iterations))
    print("Hebrew perf — \(label): min total \(minTotalMs) ms (max \(maxTotalMs)), min \(minPer) \(unit) (max \(maxPer)) — best of \(timedRuns) runs × \(iterations) iters")
}

@Suite("Hebrew Calendar Performance")
private struct HebrewCalendarPerformanceTests {

    // Hebrew-equivalent of Apple's `test_nextThousandThanksgivings`.
    // Hanukkah begins on 25 Kislev. In Foundation's Hebrew calendar
    // (civil month ordering, Tishrei = month 1), Kislev is month 3.
    @Test func bench_nextThousandHanukkahs() {
        let dc = DateComponents(month: 3, day: 25)
        let cal = Calendar(identifier: .hebrew)
        var checksum: Int64 = 0

        // Warmup: 10 enumerations
        var warmCount = 10
        cal.enumerateDates(startingAfter: referenceDate, matching: dc, matchingPolicy: .nextTime) { result, _, stop in
            checksum &+= Int64(result?.timeIntervalSinceReferenceDate ?? 0)
            warmCount -= 1
            if warmCount == 0 { stop = true }
        }

        let (minT, maxT) = repeatedTimed {
            var count = 1000
            cal.enumerateDates(startingAfter: referenceDate, matching: dc, matchingPolicy: .nextTime) { result, _, stop in
                checksum &+= Int64(result?.timeIntervalSinceReferenceDate ?? 0)
                count -= 1
                if count == 0 { stop = true }
            }
        }

        #expect(checksum != 0)
        report("nextThousandHanukkahs", iterations: 1000, unit: "µs/match", scale: 1e6, minT: minT, maxT: maxT)
    }

    // Hebrew-equivalent of Apple's `test_allocationsForFixedCalendars`.
    @Test func bench_allocationsForFixedHebrewCalendar() {
        var checksum: Int64 = 0

        // Warmup
        for _ in 0..<warmupIterations {
            let cal = Calendar(identifier: .hebrew)
            if let d = cal.date(byAdding: .day, value: 1, to: referenceDate) {
                checksum &+= Int64(d.timeIntervalSinceReferenceDate)
            }
        }

        let iterations = 10_000
        let (minT, maxT) = repeatedTimed {
            for _ in 0..<iterations {
                let cal = Calendar(identifier: .hebrew)
                if let d = cal.date(byAdding: .day, value: 1, to: referenceDate) {
                    checksum &+= Int64(d.timeIntervalSinceReferenceDate)
                }
            }
        }

        #expect(checksum != 0)
        report("allocationsForFixedHebrewCalendar", iterations: iterations, unit: "ns/iter", scale: 1e9, minT: minT, maxT: maxT)
    }

    // Hebrew-equivalent of Apple's `test_copyOnWritePerformance`.
    @Test func bench_copyOnWriteHebrew() {
        var checksum: Int64 = 0
        var cal = Calendar(identifier: .hebrew)

        // Warmup
        for i in 0..<warmupIterations {
            cal.firstWeekday = (i % 2) + 1   // 1 or 2 (Sunday or Monday)
            if let d = cal.date(byAdding: .day, value: 1, to: referenceDate) {
                checksum &+= Int64(d.timeIntervalSinceReferenceDate)
            }
        }

        let iterations = 10_000
        let (minT, maxT) = repeatedTimed {
            for i in 0..<iterations {
                cal.firstWeekday = (i % 2) + 1
                if let d = cal.date(byAdding: .day, value: 1, to: referenceDate) {
                    checksum &+= Int64(d.timeIntervalSinceReferenceDate)
                }
            }
        }

        #expect(checksum != 0)
        report("copyOnWriteHebrew", iterations: iterations, unit: "ns/iter", scale: 1e9, minT: minT, maxT: maxT)
    }

    // Hebrew-specific tight-loop test: Date → (year, month, day) → Date round-trip.
    // This is the core work `_CalendarHebrew` will accelerate most directly.
    @Test func bench_hebrewRoundTripDateComponents() {
        let cal = Calendar(identifier: .hebrew)
        let components: Set<Calendar.Component> = [.year, .month, .day]
        var checksum: Int64 = 0

        // Warmup: spread across ~100 days so we hit different Hebrew months/years
        for i in 0..<warmupIterations {
            let d = referenceDate.addingTimeInterval(Double(i) * 86400)
            let comps = cal.dateComponents(components, from: d)
            if let rt = cal.date(from: comps) {
                checksum &+= Int64(rt.timeIntervalSinceReferenceDate)
            }
        }

        let iterations = 10_000
        let (minT, maxT) = repeatedTimed {
            for i in 0..<iterations {
                let d = referenceDate.addingTimeInterval(Double(i) * 86400)
                let comps = cal.dateComponents(components, from: d)
                if let rt = cal.date(from: comps) {
                    checksum &+= Int64(rt.timeIntervalSinceReferenceDate)
                }
            }
        }

        #expect(checksum != 0)
        report("roundTripDateComponents", iterations: iterations, unit: "ns/round-trip", scale: 1e9, minT: minT, maxT: maxT)
    }
}

// Baseline (ICU-backed `.hebrew`) vs post-port (`_CalendarHebrew`), debug mode,
// 2026-04-24, Intel iMac 2019, macOS 15.7.3, Swift 6.3.1.
// Methodology: best of 5 runs (isolates min from system noise).
//
//                                          BASELINE      POST-PORT   SPEEDUP
//   allocationsForFixedHebrewCalendar:     21,321 ns     4,315 ns    4.9×
//   roundTripDateComponents:               20,346 ns     5,793 ns    3.5×
//   copyOnWriteHebrew:                     69,590 ns     3,428 ns    20×
//   nextThousandHanukkahs:                    776 µs         6 µs    129×
//
// (Earlier checkpoint w/ unpack-based date(byAdding: .day): alloc 12,490 ns / CoW
// 12,875 ns. The offset-delta optimization in task #10 recovered the bulk of the
// expected algorithm win while preserving DST correctness across both spring-forward
// and fall-back transitions. The 2-probe `rawAndDaylightSavingTimeOffset` cost now
// dominates the day-add path; further speedup would require eliminating one probe
// for fixed-offset timezones — deferred.)
//
// `nextThousandHanukkahs` is where the algorithm win is most visible: enumerateDates
// calls into our calendar dozens of times per match, compounding every nanosecond saved.
// The same logic at the algorithm level would compound in release mode too.
//
// Release-mode numbers unavailable on this machine: `swiftpm-testing-helper` crashes
// with SIGBUS on Intel x86_64 + Swift 6.3.1 before our tests can produce output.
// Debug-mode ratios (before-port vs after-port) remain meaningful because both runs
// pay the same debug-overhead tax.
