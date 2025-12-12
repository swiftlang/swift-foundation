//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Benchmark
import func Benchmark.blackHole

#if os(macOS) && USE_PACKAGE
import FoundationEssentials
import FoundationInternationalization
#else
import Foundation
#endif

#if FOUNDATION_FRAMEWORK
// FOUNDATION_FRAMEWORK has a scheme per benchmark file, so only include one benchmark here.
let benchmarks = {
    timeZoneBenchmarks()
}
#endif

let testDates = {
    var now = Date.now
    var dates: [Date] = []
    for i in 0...10000 {
        dates.append(Date(timeInterval: Double(i * 3600), since: now))
    }
    return dates
}()

func timeZoneBenchmarks() {

    Benchmark.defaultConfiguration.maxIterations = 1_000
    Benchmark.defaultConfiguration.maxDuration = .seconds(3)
    Benchmark.defaultConfiguration.scalingFactor = .kilo
    Benchmark.defaultConfiguration.metrics = [.cpuTotal, .mallocCountTotal, .throughput, .peakMemoryResident]

    guard let t = TimeZone(identifier: "America/Los_Angeles") else {
        fatalError("unexpected failure when creating time zone")
    }

    Benchmark("secondsFromGMT", configuration: .init(scalingFactor: .mega)) { benchmark in
        for d in testDates {
            let s = t.secondsFromGMT(for: d)
            blackHole(s)
        }
    }

    Benchmark("creatingTimeZones", configuration: .init(scalingFactor: .mega)) { benchmark in
        for name in NSTimeZone.knownTimeZoneNames {
            let t = TimeZone(identifier: name)
            blackHole(t)
        }
    }

    Benchmark("secondsFromGMT_manyTimeZones", configuration: .init(scalingFactor: .mega)) { benchmark in
        for name in NSTimeZone.knownTimeZoneNames {
            let t = TimeZone(identifier: name)!
            for d in testDates {
                let s = t.secondsFromGMT(for: d)
                blackHole(s)
            }
            blackHole(t)
        }
    }

    guard let gmtPlus8 = TimeZone(identifier: "GMT+8") else {
        fatalError("unexpected failure when creating time zone")
    }

    let locale = Locale(identifier: "jp_JP")

    Benchmark("GMTOffsetTimeZoneAPI", configuration: .init(scalingFactor: .mega)) { benchmark in
        for d in testDates {
            let secondsFromGMT = gmtPlus8.secondsFromGMT(for: d)
            blackHole(secondsFromGMT)

            let abbreviation = gmtPlus8.abbreviation(for: d)
            blackHole(abbreviation)

            let isDST = gmtPlus8.isDaylightSavingTime(for: d)
            blackHole(isDST)

            let nextDST = gmtPlus8.nextDaylightSavingTimeTransition(after: d)
            blackHole(nextDST)
        }
    }

    Benchmark("GMTOffsetTimeZone-localizedNames", configuration: .init(scalingFactor: .mega)) { benchmark in
        for style in [TimeZone.NameStyle.generic, .standard, .shortGeneric, .shortStandard, .daylightSaving, .shortDaylightSaving] {
            let localizedName = gmtPlus8.localizedName(for: style, locale: locale)
            blackHole(localizedName)
        }
    }

}


