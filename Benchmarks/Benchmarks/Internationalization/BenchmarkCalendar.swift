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
    calendarBenchmarks()
}
#endif

func calendarBenchmarks() {

    Benchmark.defaultConfiguration.maxIterations = 1_000
    Benchmark.defaultConfiguration.maxDuration = .seconds(3)
    Benchmark.defaultConfiguration.scalingFactor = .kilo
    Benchmark.defaultConfiguration.metrics = [.cpuTotal, .mallocCountTotal, .throughput]
    let thanksgivingComponents = DateComponents(month: 11, weekday: 5, weekdayOrdinal: 4)
    let cal = Calendar(identifier: .gregorian)
    let currentCalendar = Calendar.current
    let thanksgivingStart = Date(timeIntervalSince1970: 1474666555.0) //2016-09-23T14:35:55-0700

    // MARK: Enumeration
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
    #if compiler(>=6.0)
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

        Benchmark("RecurrenceRuleThanksgivings") { benchmark in
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
        Benchmark("RecurrenceRuleThanksgivingMeals") { benchmark in
            var rule = Calendar.RecurrenceRule(calendar: cal, frequency: .yearly, end: .afterOccurrences(1000))
            rule.months = [11]
            rule.weekdays = [.nth(4, .thursday)]
            rule.hours = [14, 18]
            rule.matchingPolicy = .nextTime
            for date in rule.recurrences(of: thanksgivingStart) {
                Benchmark.blackHole(date)
            }
        }
        Benchmark("RecurrenceRuleLaborDay") { benchmark in
            var rule = Calendar.RecurrenceRule(calendar: cal, frequency: .yearly, end: .afterOccurrences(1000))
            rule.months = [9]
            rule.weekdays = [.nth(1, .monday)]
            rule.matchingPolicy = .nextTime
            for date in rule.recurrences(of: thanksgivingStart) {
                Benchmark.blackHole(date)
            }
        }
        Benchmark("RecurrenceRuleBikeParties") { benchmark in
            var rule = Calendar.RecurrenceRule(calendar: cal, frequency: .monthly, end: .afterOccurrences(1000))
            rule.weekdays = [.nth(1, .friday), .nth(-1, .friday)]
            rule.matchingPolicy = .nextTime
            for date in rule.recurrences(of: thanksgivingStart) {
                Benchmark.blackHole(date)
            }
        }
        Benchmark("RecurrenceRuleDailyWithTimes") { benchmark in
            var rule = Calendar.RecurrenceRule(calendar: cal, frequency: .daily, end: .afterOccurrences(1000))
            rule.hours = [9, 10]
            rule.minutes = [0, 30]
            rule.weekdays = [.every(.monday), .every(.tuesday), .every(.wednesday)]
            rule.matchingPolicy = .nextTime
            for date in rule.recurrences(of: thanksgivingStart) {
                Benchmark.blackHole(date)
            }
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
    let testDates = {
        let date = Date(timeIntervalSince1970: 0)
        var dates = [Date]()
        dates.reserveCapacity(10000)
        for i in 0...10000 {
            dates.append(Date(timeInterval: Double(i * 3600), since: date))
        }
        return dates
    }()

    let testDatePairs = {
        let date = Date(timeIntervalSince1970: 0)
        var dates = [(Date, Date)]()
        dates.reserveCapacity(10000)
        for i in 0...10000 {
            let d1 = Date(timeInterval: Double(i * 3600), since: date)
            let d2 = Date(timeInterval: Double(i * -3657), since: d1)
            dates.append((d1, d2))
        }
        return dates
    }()

    Benchmark("NextDatesMatchingOnHour") { _ in
        for d in testDates {
            let t = currentCalendar.nextDate(after: d, matching: DateComponents(minute: 0, second: 0), matchingPolicy: .nextTime)
            blackHole(t)
        }
    }

    // MARK: - Allocations
    let reference = Date(timeIntervalSince1970: 1474666555.0) //2016-09-23T14:35:55-0700
    
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

    // MARK: - GregorianCalendar

    var gmtCalendr = Calendar(identifier: .gregorian)
    guard let gmtTimeZone = TimeZone(secondsFromGMT: 0) else {
        preconditionFailure("Unexpected nil TimeZone")
    }
    gmtCalendr.timeZone = gmtTimeZone // use gmt-based time zone so the result doesn't get overshadowed by TimeZone API

    Benchmark("GregorianCalendar-dateComponents-yearMonthBasedComponents", configuration: .init(scalingFactor: .mega)) { benchmark in
        for date in testDates {
            let dc = gmtCalendr.dateComponents([.era, .year, .month, .day, .hour, .minute, .second, .nanosecond], from: date)
            blackHole(dc)
        }
    }

    Benchmark("GregorianCalendar-dateComponents-calendarDayComparison", configuration: .init(scalingFactor: .mega)) { benchmark in
        for date in testDates {
            let dc = gmtCalendr.dateComponents([.year, .month, .day], from: date)
            blackHole(dc)
        }
    }

    Benchmark("GregorianCalendar-dateComponents-timestamps", configuration: .init(scalingFactor: .mega)) { benchmark in
        for date in testDates {
            let dc = gmtCalendr.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            blackHole(dc)
        }
    }

    Benchmark("GregorianCalendar-dateComponents-timeValidation", configuration: .init(scalingFactor: .mega)) { benchmark in
        for date in testDates {
            let dc = gmtCalendr.dateComponents([.hour, .minute, .second], from: date)
            blackHole(dc)
        }
    }

    Benchmark("GregorianCalendar-dateComponents-anniversary", configuration: .init(scalingFactor: .mega)) { benchmark in
        for date in testDates {
            let dc = gmtCalendr.dateComponents([.month, .day], from: date)
            blackHole(dc)
        }
    }

    Benchmark("GregorianCalendar-dateComponents-year", configuration: .init(scalingFactor: .mega)) { benchmark in
        for date in testDates {
            let dc = gmtCalendr.dateComponents([.year], from: date)
            blackHole(dc)
        }
    }

    Benchmark("GregorianCalendar-dateComponents-week-based", configuration: .init(scalingFactor: .mega)) { benchmark in
        for date in testDates {
            let dc = gmtCalendr.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            blackHole(dc)
        }
    }

    // MARK: - Current calendar

    let testDateComponents_ymd = {
        var results = [DateComponents]()
        for y in stride(from: 1650, to: 2080, by: 42) {
            for m in 1...12 {
                for d in stride(from: 1, to: 28, by: 6) {
                    let dc = DateComponents(year: y, month: m, day: d)
                    results.append(dc)
                }
            }
        }
        return results
    }()

    let testDateComponents_ymdhhmmss = {
        var results = [DateComponents]()
        for y in stride(from: 1650, to: 2080, by: 79) {
            for m in stride(from: 1, to: 12, by: 3) {
                for d in stride(from: 1, to: 28, by: 6) {
                    for hh in stride(from: 0, to: 23, by: 7) {
                        for mm in stride(from: 0, to: 60, by: 13) {
                            for ss in stride(from: 0, to: 60, by: 18) {
                                let dc = DateComponents(year: y, month: m, day: d, hour: hh, minute:mm, second: ss )
                                results.append(dc)
                            }
                        }
                    }
                }
            }
        }
        return results
    }()

    Benchmark("CurrentCalendar-date-from-DateComponents-ymd") { benchmark in
        for components in testDateComponents_ymd {
            let date = currentCalendar.date(from: components)
            blackHole(date)
        }
    }

    Benchmark("CurrentCalendar-date-from-DateComponents-ymdhhmmss") { benchmark in
        for components in testDateComponents_ymdhhmmss {
            let date = currentCalendar.date(from: components)
            blackHole(date)
        }
    }

    Benchmark("CurrentCalendar-dateComponents-yearMonthBasedComponents") { benchmark in
        for date in testDates {
            let dc = currentCalendar.dateComponents([.era, .year, .month, .day, .hour, .minute, .second, .nanosecond], from: date)
            blackHole(dc)
        }
    }

    Benchmark("CurrentCalendar-dateComponents-calendarDayComparison") { benchmark in
        for date in testDates {
            let dc = currentCalendar.dateComponents([.year, .month, .day], from: date)
            blackHole(dc)
        }
    }

    Benchmark("CurrentCalendar-dateComponents-timestamps") { benchmark in
        for date in testDates {
            let dc = currentCalendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            blackHole(dc)
        }
    }

    Benchmark("CurrentCalendar-dateComponents-timeValidation") { benchmark in
        for date in testDates {
            let dc = currentCalendar.dateComponents([.hour, .minute, .second], from: date)
            blackHole(dc)
        }
    }

    Benchmark("CurrentCalendar-dateComponents-anniversary") { benchmark in
        for date in testDates {
            let dc = currentCalendar.dateComponents([.month, .day], from: date)
            blackHole(dc)
        }
    }

    Benchmark("CurrentCalendar-dateComponents-year") { benchmark in
        for date in testDates {
            let dc = currentCalendar.dateComponents([.year], from: date)
            blackHole(dc)
        }
    }

    Benchmark("CurrentCalendar-dateComponents-week-based") { benchmark in
        for date in testDates {
            let dc = currentCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            blackHole(dc)
        }
    }

    Benchmark("CurrentCalendar-date-byAdding-day") { benchmark in
        for date in testDates {
            let nextDay = currentCalendar.date(byAdding: .day, value: 1, to: date)
            blackHole(nextDay)
            let previousDay = currentCalendar.date(byAdding: .day, value: 1, to: date)
            blackHole(previousDay)
        }
    }

    Benchmark("CurrentCalendar-date-byAdding-time") { benchmark in
        for date in testDates {
            let nextHour = currentCalendar.date(byAdding: .hour, value: 1, to: date)
            blackHole(nextHour)

            let nextHalfHour = currentCalendar.date(byAdding: .minute, value: 30, to: date)
            blackHole(nextHalfHour)
        }
    }

    Benchmark("CurrentCalendar-startOfDay") { benchmark in
        for date in testDates {
            let startOfDay = currentCalendar.startOfDay(for: date)
            blackHole(startOfDay)
        }
    }

    Benchmark("CurrentCalendar-isDateInToday") { benchmark in
        for testDate in testDates {
            let isInToday = currentCalendar.isDateInToday(testDate)
            blackHole(isInToday)
        }
    }

    Benchmark("CurrentCalendar-dateComponents-from-to-day") { benchmark in
        for (startDate, endDate) in testDatePairs {
            let difference = currentCalendar.dateComponents([.day], from: startDate, to: endDate)
            blackHole(difference)
        }
    }

    Benchmark("CurrentCalendar-dateComponents-from-to-time") { benchmark in
        for (from, to) in testDatePairs {
            let difference = currentCalendar.dateComponents([.hour, .minute], from: from, to: to)
            blackHole(difference)
        }
    }

    Benchmark("CurrentCalendar-dateComponents-from-to-datetime") { benchmark in
        for (from, to) in testDatePairs {
            let difference = currentCalendar.dateComponents([.year, .month, .day, .hour, .minute], from: from, to: to)
            blackHole(difference)
        }
    }

    Benchmark("CurrentCalendar-dateComponents-from-to-weekly") { benchmark in
        for (from, to) in testDatePairs {
            let difference = currentCalendar.dateComponents([.weekday, .hour, .minute, .second], from: from, to: to)
            blackHole(difference)
        }
    }

    Benchmark("CurrentCalendar-isDate-inSameDayAs-sameDay") { benchmark in
        for (i, date) in testDates[0..<testDates.count - 1].enumerated() {
            let nextDate = testDates[i]
            let sameDayCheck = currentCalendar.isDate(date, inSameDayAs: nextDate)
            blackHole(sameDayCheck)
        }
    }

    Benchmark("CurrentCalendar-isDate-inSameDayAs-notSameDay") { benchmark in
        for (date1, date2) in testDatePairs {
            let sameDayCheck = currentCalendar.isDate(date1, inSameDayAs: date2)
            blackHole(sameDayCheck)
        }
    }

    Benchmark("CurrentCalendar-compare-to-toGranularity-day-sameDay") { benchmark in
        for (i, date) in testDates[0..<testDates.count - 1].enumerated() {
            let nextDate = testDates[i + 1]
            let sameDayComparison = currentCalendar.compare(date, to: nextDate, toGranularity: .day)
            blackHole(sameDayComparison)
        }
    }

    Benchmark("CurrentCalendar-compare-to-toGranularity-day-notSameDay") { benchmark in
        for (date1, date2) in testDatePairs {
            let sameDayComparison = currentCalendar.compare(date1, to: date2, toGranularity: .day)
            blackHole(sameDayComparison)
        }
    }

    Benchmark("CurrentCalendar-compare-to-toGranularity-month") { benchmark in
        for (i, date) in testDates[0..<testDates.count - 1].enumerated() {
            let nextDate = testDates[i + 1]
            let sameDayComparison = currentCalendar.compare(date, to: nextDate, toGranularity: .month)
            blackHole(sameDayComparison)
        }
    }
}

