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
    localeBenchmarks()
}
#endif

func localeBenchmarks() {
    Benchmark.defaultConfiguration.maxIterations = 1_000
    Benchmark.defaultConfiguration.maxDuration = .seconds(3)
    Benchmark.defaultConfiguration.scalingFactor = .kilo
    Benchmark.defaultConfiguration.metrics = [.cpuTotal, .wallClock, .throughput, .peakMemoryResident, .peakMemoryResidentDelta]

#if FOUNDATION_FRAMEWORK
    let string1 = "aaA" as CFString
    let string2 = "AAà" as CFString
    let range1 = CFRange(location: 0, length: CFStringGetLength(string1))
    let nsLocales = Locale.availableIdentifiers.map {
        NSLocale(localeIdentifier: $0)
    }

    Benchmark("CFStringCompareWithOptionsAndLocale", configuration: .init(scalingFactor: .mega)) { benchmark in
            for nsLocale in nsLocales {
                CFStringCompareWithOptionsAndLocale(string1, string2, range1, .init(rawValue: 0), nsLocale)
            }
    }
#endif

    let identifiers = Locale.availableIdentifiers
    let allComponents = identifiers.map { Locale.Components(identifier: $0) }
    Benchmark("LocaleInitFromComponents") { benchmark in
        for components in allComponents {
            let locale = Locale(components: components)
            let components2 = Locale.Components(locale: locale)
            let locale2 = Locale(components: components2) // cache hit
        }
    }

    Benchmark("LocaleComponentsInitIdentifer") { benchmark in
        for identifier in identifiers {
            let components = Locale.Components(identifier: identifier)
        }
    }
}
