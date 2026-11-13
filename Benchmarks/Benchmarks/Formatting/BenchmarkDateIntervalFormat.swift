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

func dateIntervalFormatBenchmarks() {
    let scaling = Benchmark.Configuration(scalingFactor: .kilo)
    let utc = TimeZone(identifier: "UTC")!
    let gregorian = Calendar(identifier: .gregorian)
    let enUS = Locale(identifier: "en_US")

    // The same 64 start dates every run. Each range has a fixed length, so every run formats the same mix of same-day, adjacent-day, and multi-month intervals.
    let start = 1_700_000_000.0
    func ranges(length: TimeInterval) -> [Range<Date>] {
        (0..<64).map {
            let from = Date(timeIntervalSince1970: start + Double($0) * 987_654.321)
            return from ..< from.addingTimeInterval(length)
        }
    }
    let sameDay = ranges(length: 3 * 3600)
    let nextDay = ranges(length: 20 * 3600)
    let sameMonth = ranges(length: 5 * 86400)
    let multiMonth = ranges(length: 75 * 86400)

    func style(date: Date.IntervalFormatStyle.DateStyle? = nil, time: Date.IntervalFormatStyle.TimeStyle? = nil, locale: Locale = enUS) -> Date.IntervalFormatStyle {
        Date.IntervalFormatStyle(date: date, time: time, locale: locale, calendar: gregorian, timeZone: utc)
    }

    // MARK: Pre-built styles (formatter cache warm)

    let dateTimeStyle = style(date: .abbreviated, time: .shortened)
    let dateOnlyStyle = style(date: .long)
    let timeOnlyStyle = style(time: .shortened)
    let fieldsStyle = style().year().month(.wide).day().weekday(.wide).hour().minute()

    let multiLocaleStyles = ["en_US", "fr", "de", "ja", "ar_EG", "zh_Hant_TW", "hi", "ru", "he", "th"].map {
        style(date: .abbreviated, time: .shortened, locale: Locale(identifier: $0))
    }

    // MARK: Interval shapes

    Benchmark("date-interval-format-same-day", configuration: scaling) { benchmark in
        for i in benchmark.scaledIterations {
            blackHole(sameDay[i % sameDay.count].formatted(dateTimeStyle))
        }
    }

    Benchmark("date-interval-format-next-day", configuration: scaling) { benchmark in
        for i in benchmark.scaledIterations {
            blackHole(nextDay[i % nextDay.count].formatted(dateTimeStyle))
        }
    }

    Benchmark("date-interval-format-same-month", configuration: scaling) { benchmark in
        for i in benchmark.scaledIterations {
            blackHole(sameMonth[i % sameMonth.count].formatted(dateTimeStyle))
        }
    }

    Benchmark("date-interval-format-multi-month", configuration: scaling) { benchmark in
        for i in benchmark.scaledIterations {
            blackHole(multiMonth[i % multiMonth.count].formatted(dateTimeStyle))
        }
    }

    // MARK: Style configurations

    Benchmark("date-interval-format-date-only", configuration: scaling) { benchmark in
        for i in benchmark.scaledIterations {
            blackHole(sameMonth[i % sameMonth.count].formatted(dateOnlyStyle))
        }
    }

    Benchmark("date-interval-format-time-only", configuration: scaling) { benchmark in
        for i in benchmark.scaledIterations {
            blackHole(sameDay[i % sameDay.count].formatted(timeOnlyStyle))
        }
    }

    Benchmark("date-interval-format-fields", configuration: scaling) { benchmark in
        for i in benchmark.scaledIterations {
            blackHole(sameMonth[i % sameMonth.count].formatted(fieldsStyle))
        }
    }

    Benchmark("date-interval-format-multi-locale", configuration: scaling) { benchmark in
        for i in benchmark.scaledIterations {
            for style in multiLocaleStyles {
                blackHole(sameMonth[i % sameMonth.count].formatted(style))
            }
        }
    }

    // MARK: Style construction overhead
    //
    // Constructs a fresh style each iteration. The formatter cache key matches
    // the warm case, so this measures the style init and cache lookup on top of
    // the format itself.

    Benchmark("date-interval-format-fresh-style", configuration: scaling) { benchmark in
        for i in benchmark.scaledIterations {
            let fresh = style(date: .abbreviated, time: .shortened)
            blackHole(sameMonth[i % sameMonth.count].formatted(fresh))
        }
    }
}
