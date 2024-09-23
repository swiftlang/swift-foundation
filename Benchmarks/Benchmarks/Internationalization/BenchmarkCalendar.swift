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

let benchmarks = {
    Benchmark.defaultConfiguration.maxIterations = 1_000
    Benchmark.defaultConfiguration.maxDuration = .seconds(3)
    Benchmark.defaultConfiguration.scalingFactor = .kilo
    Benchmark.defaultConfiguration.metrics = [.cpuTotal, .mallocCountTotal, .throughput]
    
    let thanksgivingComponents = DateComponents(month: 11, weekday: 5, weekdayOrdinal: 4)
    let cal = Calendar(identifier: .gregorian)
    let currentCalendar = Calendar.current
    let thanksgivingStart = Date(timeIntervalSinceReferenceDate: 496359355.795410) //2016-09-23T14:35:55-0700
    
    Benchmark("nextThousandThursdaysInTheFourthWeekOfNovember") { benchmark in
        // This benchmark used to be nextThousandThanksgivings, but the name was deceiving since it does not compute the next thousand thanksgivings
        let components = DateComponents(month: 11, weekday: 5, weekOfMonth: 4)
        var count = 1000
        cal.enumerateDates(startingAfter: thanksgivingStart, matching: components, matchingPolicy: .nextTime) { result, exactMatch, stop in
            count -= 1
            if count == 0 {
                stop = true
            }
        }
    }

    Benchmark("nextThousandThanksgivings") { benchmark in
        var count = 1000
        cal.enumerateDates(startingAfter: thanksgivingStart, matching: thanksgivingComponents, matchingPolicy: .nextTime) { result, exactMatch, stop in
            count -= 1
            if count == 0 {
                stop = true
            }
        }
    }

    // Only available in Swift 6 for non-Darwin platforms, macOS 15 for Darwin
    #if swift(>=6.0)
    if #available(macOS 15, *) {
        Benchmark("nextThousandThanksgivingsSequence") { benchmark in
            var count = 1000
            for _ in cal.dates(byMatching: thanksgivingComponents, startingAt: thanksgivingStart, matchingPolicy: .nextTime) {
                count -= 1
                if count == 0 {
                    break
                }
            }
        }

        Benchmark("nextThousandThanksgivingsUsingRecurrenceRule") { benchmark in
            var rule = Calendar.RecurrenceRule(calendar: cal, frequency: .yearly, end: .afterOccurrences(1000))
            rule.months = [11]
            rule.weekdays = [.nth(4, .thursday)]
            rule.matchingPolicy = .nextTime
            var count = 0
            for _ in rule.recurrences(of: thanksgivingStart) {
                count += 1
            }
            assert(count == 1000)
        }
    } // #available(macOS 15, *)
    #endif // swift(>=6.0)

    Benchmark("CurrentDateComponentsFromThanksgivings") { benchmark in
        var count = 1000
        currentCalendar.enumerateDates(startingAfter: thanksgivingStart, matching: thanksgivingComponents, matchingPolicy: .nextTime) { result, exactMatch, stop in
            count -= 1
            _ = currentCalendar.dateComponents([.era, .year, .month, .day, .hour, .minute, .second, .nanosecond, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .calendar, .timeZone], from: result!)
            if count == 0 {
                stop = true
            }
        }
    }

    // MARK: - Allocations

    let reference = Date(timeIntervalSinceReferenceDate: 496359355.795410) //2016-09-23T14:35:55-0700
    
    let allocationsConfiguration = Benchmark.Configuration(
        metrics: [.cpuTotal, .mallocCountTotal, .peakMemoryResident, .throughput],
        timeUnits: .nanoseconds,
        scalingFactor: .mega
    )

    Benchmark("allocationsForFixedCalendars", configuration: allocationsConfiguration) { benchmark in
        for _ in benchmark.scaledIterations {
            // Fixed calendar
            let cal = Calendar(identifier: .gregorian)
            let date = cal.date(byAdding: .day, value: 1, to: reference)
            assert(date != nil)
        }
    }
    
    Benchmark("allocationsForCurrentCalendar", configuration: allocationsConfiguration) { benchmark in
        for _ in benchmark.scaledIterations {
            // Current calendar
            let cal = Calendar.current
            let date = cal.date(byAdding: .day, value: 1, to: reference)
            assert(date != nil)
        }
    }
    
    Benchmark("allocationsForAutoupdatingCurrentCalendar", configuration: allocationsConfiguration) { benchmark in
        for _ in benchmark.scaledIterations {
            // Autoupdating current calendar
            let cal = Calendar.autoupdatingCurrent
            let date = cal.date(byAdding: .day, value: 1, to: reference)
            assert(date != nil)
        }
    }
    
    Benchmark("copyOnWritePerformance", configuration: allocationsConfiguration) { benchmark in
        var cal = Calendar(identifier: .gregorian)
        for i in benchmark.scaledIterations {
            cal.firstWeekday = i % 2
            assert(cal.firstWeekday == i % 2)
        }
    }
    
    Benchmark("copyOnWritePerformanceNoDiff", configuration: allocationsConfiguration) { benchmark in
        var cal = Calendar(identifier: .gregorian)
        let tz = TimeZone(secondsFromGMT: 1800)!
        for _ in benchmark.scaledIterations {
            cal.timeZone = tz
        }
    }
    
    Benchmark("allocationsForFixedLocale", configuration: allocationsConfiguration) { benchmark in
        // Fixed locale
        for _ in benchmark.scaledIterations {
            let loc = Locale(identifier: "en_US")
            let identifier = loc.identifier
            assert(identifier == "en_US")
        }
    }
    
    Benchmark("allocationsForCurrentLocale", configuration: allocationsConfiguration) { benchmark in
        // Current locale
        for _ in benchmark.scaledIterations {
            let loc = Locale.current
            let identifier = loc.identifier
            assert(identifier == "en_US")
        }
    }
    
    Benchmark("allocationsForAutoupdatingCurrentLocale", configuration: allocationsConfiguration) { benchmark in
        // Autoupdating current locale
        for _ in benchmark.scaledIterations {
            let loc = Locale.autoupdatingCurrent
            let identifier = loc.identifier
            assert(identifier == "en_US")
        }
    }

    // MARK: - Identifiers

    Benchmark("identifierFromComponents", configuration: .init(scalingFactor: .mega)) { benchmark in
        let c1 = ["kCFLocaleLanguageCodeKey" : "en"]
        let c2 = ["kCFLocaleLanguageCodeKey" : "zh",
                  "kCFLocaleScriptCodeKey" : "Hans",
                  "kCFLocaleCountryCodeKey" : "TW"]
        let c3 = ["kCFLocaleLanguageCodeKey" : "es",
                  "kCFLocaleScriptCodeKey" : "",
                  "kCFLocaleCountryCodeKey" : "409"]
        
        for _ in benchmark.scaledIterations {
            let id1 = Locale.identifier(fromComponents: c1)
            let id2 = Locale.identifier(fromComponents: c2)
            let id3 = Locale.identifier(fromComponents: c3)
            assert(id1.isEmpty == false)
            assert(id2.isEmpty == false)
            assert(id3.isEmpty == false)
        }
    }
}
