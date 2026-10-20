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

import Benchmark
import func Benchmark.blackHole

#if os(macOS) && USE_PACKAGE
import FoundationEssentials
import FoundationInternationalization
#else
import Foundation
#endif

func dateFormatBenchmarks() {
    let scaling = Benchmark.Configuration(scalingFactor: .kilo)
    // The same 64 dates every run, covering AM and PM, one- and two-digit days, and every month and weekday.
    let dates = (0..<64).map { Date(timeIntervalSince1970: 1_700_000_000 + Double($0) * 987_654.321) }
    let utc = TimeZone(identifier: "UTC")!
    let gregorian = Calendar(identifier: .gregorian)

    func verbatim(_ format: Date.FormatString, locale: String, timeZone: TimeZone = utc) -> Date.VerbatimFormatStyle {
        Date.VerbatimFormatStyle(format: format, locale: Locale(identifier: locale), timeZone: timeZone, calendar: gregorian)
    }

    // MARK: Pre-built styles (formatter cache warm)

    let isoStyle = verbatim("\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)T\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\(second: .twoDigits).\(secondFraction: .fractional(3))\(timeZone: .iso8601(.long))",
                            locale: "en_US", timeZone: TimeZone(identifier: "America/Los_Angeles")!)
    let shortStyle = verbatim("\(month: .abbreviated) \(day: .defaultDigits), \(year: .defaultDigits)", locale: "en_US")
    let longStyle = verbatim("\(weekday: .wide), \(month: .wide) \(day: .defaultDigits), \(year: .defaultDigits) at \(hour: .defaultDigits(clock: .twelveHour, hourCycle: .oneBased)):\(minute: .twoDigits) \(dayPeriod: .standard(.abbreviated))",
                             locale: "en_US")
    let dayStyle = verbatim("\(day: .defaultDigits)", locale: "en_US")
    let timeStyle = verbatim("\(hour: .defaultDigits(clock: .twelveHour, hourCycle: .oneBased)):\(minute: .twoDigits) \(dayPeriod: .standard(.abbreviated))", locale: "en_US")
    let gmtStyle = verbatim("\(hour: .defaultDigits(clock: .twelveHour, hourCycle: .oneBased)):\(minute: .twoDigits) \(timeZone: .localizedGMT(.long))",
                            locale: "en_US", timeZone: TimeZone(identifier: "America/Los_Angeles")!)

    // Names and digits from a variety of locales.
    let multiLocaleStyles = ["en_US", "fr", "de", "ja", "ar_EG", "zh_Hant_TW", "hi", "ru", "he", "th"].map {
        verbatim("\(weekday: .wide) \(day: .defaultDigits) \(month: .wide) \(year: .defaultDigits) \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)", locale: $0)
    }

    // MARK: Verbatim patterns

    Benchmark("date-format-verbatim-iso", configuration: scaling) { benchmark in
        for i in benchmark.scaledIterations {
            blackHole(isoStyle.format(dates[i % dates.count]))
        }
    }

    Benchmark("date-format-verbatim-short", configuration: scaling) { benchmark in
        for i in benchmark.scaledIterations {
            blackHole(shortStyle.format(dates[i % dates.count]))
        }
    }

    Benchmark("date-format-verbatim-long", configuration: scaling) { benchmark in
        for i in benchmark.scaledIterations {
            blackHole(longStyle.format(dates[i % dates.count]))
        }
    }

    Benchmark("date-format-verbatim-day", configuration: scaling) { benchmark in
        for i in benchmark.scaledIterations {
            blackHole(dayStyle.format(dates[i % dates.count]))
        }
    }

    Benchmark("date-format-verbatim-time", configuration: scaling) { benchmark in
        for i in benchmark.scaledIterations {
            blackHole(timeStyle.format(dates[i % dates.count]))
        }
    }

    Benchmark("date-format-verbatim-gmt", configuration: scaling) { benchmark in
        for i in benchmark.scaledIterations {
            blackHole(gmtStyle.format(dates[i % dates.count]))
        }
    }

    Benchmark("date-format-verbatim-multi-locale", configuration: scaling) { benchmark in
        for i in benchmark.scaledIterations {
            for style in multiLocaleStyles {
                blackHole(style.format(dates[i % dates.count]))
            }
        }
    }

    // MARK: Attributed output

    let longAttributedStyle = longStyle.attributedStyle

    Benchmark("date-format-verbatim-attributed", configuration: scaling) { benchmark in
        for i in benchmark.scaledIterations {
            blackHole(longAttributedStyle.format(dates[i % dates.count]))
        }
    }

    // MARK: Date.FormatStyle, which picks its pattern with ICU

    let dateTimeStyle = Date.FormatStyle(locale: Locale(identifier: "en_US"), calendar: gregorian, timeZone: utc)
        .year().month(.abbreviated).day().hour().minute()

    Benchmark("date-format-style", configuration: scaling) { benchmark in
        for i in benchmark.scaledIterations {
            blackHole(dateTimeStyle.format(dates[i % dates.count]))
        }
    }

    // MARK: Style construction overhead
    //
    // Constructs a fresh style each iteration. The formatter cache key matches
    // the warm case, so this measures the style init and cache lookup on top of
    // the format itself.

    Benchmark("date-format-fresh-style", configuration: scaling) { benchmark in
        for i in benchmark.scaledIterations {
            let style = verbatim("\(month: .abbreviated) \(day: .defaultDigits), \(year: .defaultDigits)", locale: "en_US")
            blackHole(style.format(dates[i % dates.count]))
        }
    }
}
