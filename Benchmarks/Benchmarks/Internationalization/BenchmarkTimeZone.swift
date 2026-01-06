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
    let seeds: [Date] = [
        Date(timeIntervalSince1970: -2827137600), // 1880-05-30T12:00:00
        Date(timeIntervalSince1970: 0),
        Date.now,
        Date(timeIntervalSince1970: 26205249600) // 2800-05-30
    ]
    var dates: [Date] = []
    for seed in seeds {
        for i in 0...2000 {
            dates.append(Date(timeInterval: Double(i * 3600), since: seed))
        }
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
    let gmtOffsetTimeZoneConfiguration = Benchmark.Configuration(scalingFactor: .mega)

    var gmtOffsetTimeZoneNames = (0...14).map { "GMT+\($0)" }
    gmtOffsetTimeZoneNames.append(contentsOf: (0...12).map{ "GMT-\($0)" })

    Benchmark("GMTOffsetTimeZone-creation", configuration: gmtOffsetTimeZoneConfiguration) { benchmark in
        for name in gmtOffsetTimeZoneNames {
            guard let gmtPlus = TimeZone(identifier: name) else {
                fatalError("unexpected failure when creating time zone: \(name)")
            }
            blackHole(gmtPlus)
        }
    }

    Benchmark("GMTOffsetTimeZone-secondsFromGMT", configuration: gmtOffsetTimeZoneConfiguration) { benchmark in
        for d in testDates {
            let secondsFromGMT = gmtPlus8.secondsFromGMT(for: d)
            blackHole(secondsFromGMT)
        }
    }

    Benchmark("GMTOffsetTimeZone-abbreviation", configuration: gmtOffsetTimeZoneConfiguration) { benchmark in
        for d in testDates {
            let abbreviation = gmtPlus8.abbreviation(for: d)
            blackHole(abbreviation)
        }
    }

    Benchmark("GMTOffsetTimeZone-nextDaylightSavingTimeTransition", configuration: gmtOffsetTimeZoneConfiguration) { benchmark in
        for d in testDates {
            let nextDST = gmtPlus8.nextDaylightSavingTimeTransition(after: d)
            blackHole(nextDST)
        }
    }

    Benchmark("GMTOffsetTimeZone-daylightSavingTimeOffsets", configuration: gmtOffsetTimeZoneConfiguration) { benchmark in
        for d in testDates {
            let dstOffset = gmtPlus8.daylightSavingTimeOffset(for: d)
            blackHole(dstOffset)
        }
    }

    Benchmark("GMTOffsetTimeZone-isDaylightSavingTime", configuration: gmtOffsetTimeZoneConfiguration) { benchmark in
        for d in testDates {
            let isDST = gmtPlus8.isDaylightSavingTime(for: d)
            blackHole(isDST)
        }
    }

    Benchmark("GMTOffsetTimeZone-localizedNames", configuration: gmtOffsetTimeZoneConfiguration) { benchmark in
        for style in [TimeZone.NameStyle.generic, .standard, .shortGeneric, .shortStandard, .daylightSaving, .shortDaylightSaving] {
            let localizedName = gmtPlus8.localizedName(for: style, locale: locale)
            blackHole(localizedName)
        }
    }

}


