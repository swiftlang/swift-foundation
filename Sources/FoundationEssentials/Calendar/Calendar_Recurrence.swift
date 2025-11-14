//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// Recurrence enumeration
//
// This file implements enumerating occurrences according to a recurrence rule as
// specified in RFC5545 and RFC7529

extension Calendar.RecurrenceRule.Frequency {
    /// The calendar component corresponding to the frequency interval
    var component: Calendar.Component {
        switch self {
        case .minutely: .minute
        case .hourly:   .hour
        case .daily:    .day
        case .weekly:   .weekOfMonth
        case .monthly:  .month
        case .yearly:   .year
        }
    }
}
extension Calendar.RecurrenceRule.Month {
    init?(from comps: DateComponents) {
        guard let month = comps.month else { return nil }
        self.init(month, isLeap: comps.isLeapMonth ?? false) 
    }
}

/// The action of a component of the recurrence rule.
///
/// Each field in the recurrence rule has a different effect on the output which
/// is also different for different frequencies. The effect is documented in the
/// RFC, and copied below for convenience:
///
/// | Component\Freq |.minutely|.hourly |.daily  |.weekly |.monthly|.yearly |
/// |----------------|---------|--------|--------|--------|--------|--------|
/// |months          |.limit   |.limit  |.limit  |.limit  |.limit  |.expand |
/// |weeks           |nil      |nil     |nil     |nil     |nil     |.expand |
/// |daysOfTheYear   |.limit   |.limit  |nil     |nil     |nil     |.expand |
/// |daysOfTheMonth  |.limit   |.limit  |.limit  |nil     |.expand |.expand |
/// |weekdays        |.limit   |.limit  |.limit  |.expand |note 1  |note 2  |
/// |hours           |.limit   |.limit  |.expand |.expand |.expand |.expand |
/// |minutes         |.limit   |.expand |.expand |.expand |.expand |.expand |
/// |setPositions    |.limit   |.limit  |.limit  |.limit  |.limit  |.limit  |
///
/// - Note 1: Limit if `daysOfTheMonth` is present; otherwise expand
/// - Note 2: Limit if `daysOfTheYear` or `daysOfTheMonth` is present; otherwise
///           expand
enum ComponentAction {
    /// Replace each date found so far with a list of dates
    case expand
    /// Remove some of the dates which have been found so far
    case limit
}

extension Calendar {
    /// A `Sequence` of `Date`s produced by a given recurrence rule
    struct DatesByRecurring : Sendable, Sequence {
        typealias Element = Date
        
        /// The starting point for the recurrence rule
        let start: Date
        /// The recurrenece rule
        let recurrence: RecurrenceRule
        /// Range in which the search should occur. If `nil`, return all results
        let range: Range<Date>?
        
        init(start: Date, recurrence: RecurrenceRule, range: Range<Date>?) {
            self.start = start
            self.recurrence = recurrence
            self.range = range
        }
        
        struct Iterator: Sendable, IteratorProtocol {
            /// The starting date for the recurrence
            let start: Date
            /// The recurrence rule that should be used for enumeration
            let recurrence: RecurrenceRule
            /// The range in which the sequence should produce results
            let range: Range<Date>?
            
            /// The lower bound of `range`, adjusted so that date expansions may
            /// still fit in range even if this value is outside the range. This
            /// value is used as a lower bound for ``nextBaseRecurrenceDate()``.
            let rangeLowerBound: Date?
            
            /// The start date's nanoseconds component
            let startDateNanoseconds: TimeInterval
            
            /// How many occurrences have been found so far
            var resultsFound = 0
            
            let monthAction, weekAction, dayOfYearAction, dayOfMonthAction, weekdayAction, hourAction, minuteAction, secondAction: ComponentAction?
           
            /// An iterator for a sequence of dates spaced evenly from the start
            /// date, by the interval specified by the recurrence rule frequency
            /// This does not include the start date itself.
            var baseRecurrence: Calendar.DatesByMatching.Iterator
            
            /// How many elements we have consumed from `baseRecurrence` 
            var iterations: Int = 0
            
            /// Whether we are finished enumerating the sequence, either because
            /// we're past the end of the search range, or because we've had too
            /// many iterations without finding matches
            var finished: Bool = false
            
            /// How many times `nextGroup()` can be executed without any results
            /// before we abort the sequence
            let searchLimit: Int
            /// How many times `nextGroup()` has been called without returning a
            /// result
            var iterationsSinceLastResult: Int = 0
            
            internal init(start: Date, 
                          matching recurrence: RecurrenceRule,
                          range: Range<Date>?) {
                // Copy the calendar if it's autoupdating
                var recurrence = recurrence
                if recurrence.calendar == .autoupdatingCurrent {
                    recurrence.calendar = .current
                }
                self.recurrence = recurrence
                
                self.start = start
                self.range = range
                
                let frequency = recurrence.frequency
                
                // Find the appropriate action for every field - expand or limit
                if recurrence.months.isEmpty {
                    monthAction = nil
                } else {
                    monthAction = switch frequency {
                    case .yearly: .expand
                    default: .limit
                    }
                }
                
                if recurrence.weeks.isEmpty { 
                    weekAction = nil
                } else {
                    weekAction = switch frequency {
                    case .yearly: .expand
                    default: nil
                    }
                }
                
                if recurrence.daysOfTheYear.isEmpty { 
                    dayOfYearAction = nil
                } else {
                    dayOfYearAction = switch frequency {
                    case .yearly: .expand
                    case .minutely, .hourly: .limit
                    default: nil
                    }
                }
                
                if recurrence.daysOfTheMonth.isEmpty { 
                    dayOfMonthAction = nil
                } else {
                    dayOfMonthAction = switch frequency {
                    case .yearly, .monthly: .expand
                    case .minutely, .hourly, .daily: .limit
                    default: nil
                    }
                }
                
                if recurrence.weekdays.isEmpty { 
                    weekdayAction = nil
                } else {
                    weekdayAction = switch frequency {
                    case .minutely, .hourly, .daily: .limit
                    case .weekly: .expand
                    case .monthly: 
                        if recurrence.daysOfTheMonth.isEmpty { 
                            .expand
                        } else {
                            .limit
                        }
                    case .yearly: if (!recurrence.daysOfTheMonth.isEmpty || !recurrence.daysOfTheYear.isEmpty || !recurrence.weeks.isEmpty) { .limit } else { .expand }
                    }
                }
                
                if recurrence.hours.isEmpty { 
                    hourAction = nil
                } else {
                    hourAction = switch frequency {
                    case .minutely, .hourly: .limit
                    case .yearly, .monthly, .weekly, .daily: .expand
                    }
                }
                
                if recurrence.minutes.isEmpty { 
                    minuteAction = nil
                } else {
                    minuteAction = switch frequency {
                    case .minutely: .limit
                    case .yearly, .monthly, .weekly, .daily, .hourly: .expand
                    }
                }
                
                if recurrence.seconds.isEmpty { 
                    secondAction = nil
                } else {
                    secondAction = .expand
                }
                
                if let range {
                    rangeLowerBound = recurrence.calendar.dateInterval(of: frequency.component, for: range.lowerBound)?.start
                } else {
                    rangeLowerBound = nil
                }
                
                // Create date components that enumerate recurrences without any
                // rules applied. Retrieve the date components of the start date
                // but leave the field for the recurrence frequency empty, so it
                // is the only component that increases
                let components: Calendar.ComponentSet = switch recurrence.frequency {
                    case .minutely: [.second]
                    case .hourly:   [.second, .minute]
                    case .daily:    [.second, .minute, .hour]
                    case .weekly:   [.second, .minute, .hour, .weekday]
                    case .monthly:  [.second, .minute, .hour, .day]
                    case .yearly:   [.second, .minute, .hour, .day, .month, .isLeapMonth]
                }
                var componentsForEnumerating = recurrence.calendar._dateComponents(components, from: start) 
                
                startDateNanoseconds = start.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1)
                
                let expansionChangesDay = dayOfYearAction == .expand || dayOfMonthAction == .expand || weekAction == .expand || weekdayAction == .expand
                let expansionChangesMonth = dayOfYearAction == .expand || monthAction == .expand || weekAction == .expand

                if expansionChangesDay, componentsForEnumerating.day != nil {
                    // If we expand either the day of the month or weekday, then
                    // the day of month is likely to not match that of the start
                    // date. Reset it to 1 in the base recurrence as to not skip
                    // "invalid" anchors, such as February 30
                    componentsForEnumerating.day = 1
                }
                if expansionChangesMonth, componentsForEnumerating.month != nil {
                    // Likewise, if we will be changing the month, reset it to 1 
                    // in case the start date falls on a leap month
                    componentsForEnumerating.month = 1
                    componentsForEnumerating.isLeapMonth = nil
                }
                if expansionChangesDay || expansionChangesMonth, weekAction == .expand, weekdayAction != .expand {
                    // If we are expanding weeks, all expansions in a given year
                    // will have the same weekday. Above we have reset the month
                    // or the day of the month, so we also changed that weekday.

                    // To specify a yearly recurrence which starts from the same
                    // weekday, and which doesn't start from a leap day / month,
                    // simply use `dayOfYear` of the start date
                    componentsForEnumerating.day = nil
                    componentsForEnumerating.month = nil
                    componentsForEnumerating.isLeapMonth = nil
                    let daysInWeek = recurrence.calendar.maximumRange(of: .weekday)!.count
                    componentsForEnumerating.dayOfYear = recurrence.calendar.component(.dayOfYear, from: start) % daysInWeek // mod 7 to get the same weekday in the beginning of the year, so it's guaranteed to always exist
                }

                baseRecurrence = Calendar.DatesByMatching(calendar: recurrence.calendar,
                                                          start: start,
                                                          range: nil,
                                                          matchingComponents: componentsForEnumerating,
                                                          matchingPolicy: recurrence.matchingPolicy,
                                                          repeatedTimePolicy: recurrence.repeatedTimePolicy,
                                                          direction: .forward).makeIterator()
                                                          
                searchLimit = switch recurrence.frequency {
                    // We want to find a search limit that will stop an infinite
                    // loop, but that also enumerates through results that users
                    // might be looking for. Assume that the recurrence requests
                    // that a date falls on a leap day that occurs on a specific
                    // weekday, that would yield a result at least once every 40
                    // years.
                    case .yearly:   40
                    case .monthly:  40 * 12
                    case .weekly:   40 * 53
                    case .daily:    40 * 366
                    case .hourly:   40 * 366 * 24
                    case .minutely: 40 * 366 * 24 * 60
                }
            }
            
            /// A group of dates within the interval specified by the recurrence
            /// frequency, sorted so the earliest date is last.
            /// 
            /// The result of the sequence consists of dates that are popped off
            /// `currentGroup`. Once the array is empty, `nextGroup()` is called
            /// to recompute the array with new dates.
            /// 
            /// For example, consider a recurrence with a monthly frequency, and
            /// `weekdays = [.every(.tuesday)]`. If the initial date is March 1,
            /// `currentGroup` initially contains all Tuesdays in March. When it
            /// becomes empty, it's recomputed to contain all Tuesdays in April,
            /// and so on.
            var currentGroup: [Date] = []
            
            /// Compute `currentGroup` by advancing by a frequency interval from
            /// the most recent group
            mutating func nextGroup() {
                precondition(finished == false)
                var anchor: Date? = nil
                func next() -> Date? {
                    let nextDate: Date?
                    if iterations == 0 {
                        // `baseRecurrence` does not include its start date
                        nextDate = self.start
                    } else {
                        nextDate = self.baseRecurrence.next()
                    }
                    iterations += 1
                    return nextDate
                }
                /// Calculate the next recurrence without any rules applied
                while let nextDate = next() {
                    // Skip every few iterations when an interval has been given
                    if (iterations - 1) % recurrence.interval != 0 {
                        continue
                    }
                    // If a range has been specified, we should skip a few extra 
                    // occurrences until we reach the start date
                    if let rangeLowerBound, nextDate < rangeLowerBound {
                        continue
                    }
                    anchor = nextDate
                    break
                }
            
                guard let anchor else {
                    finished = true
                    return
                }
                
                let calendar = recurrence.calendar
                                
                var dates: [Date] = [anchor]
                     
                let components = calendar._dateComponents([.second, .minute, .hour, .day, .month, .isLeapMonth, .dayOfYear, .weekday], from: anchor) 

                var componentCombinations = Calendar._DateComponentCombinations()
                
                if recurrence.frequency == .yearly || recurrence.frequency == .monthly {
                    if dayOfYearAction == .expand {
                        componentCombinations.months = nil
                        componentCombinations.daysOfMonth = nil
                        componentCombinations.daysOfYear = recurrence.daysOfTheYear
                    } else {
                        componentCombinations.months = if recurrence.months.isEmpty { [RecurrenceRule.Month(from: components)!] } else { recurrence.months }
                        componentCombinations.daysOfMonth = if recurrence.daysOfTheMonth.isEmpty { [components.day!] } else { recurrence.daysOfTheMonth}
                        componentCombinations.daysOfYear = nil
                    }
                } else {
                    componentCombinations.months = nil
                    componentCombinations.daysOfMonth = nil
                    componentCombinations.daysOfYear = nil
                }

                if weekdayAction == .expand {
                    componentCombinations.weekdays = recurrence.weekdays
                    componentCombinations.daysOfYear = nil
                    componentCombinations.daysOfMonth = nil
                    if recurrence.frequency == .yearly, monthAction != .expand {
                        componentCombinations.months = nil
                    }
                } else if recurrence.frequency == .weekly || weekAction == .expand {
                   if let weekdayIdx = components.weekday, let weekday = Locale.Weekday(weekdayIdx) {
                       // In a weekly recurrence (or one that expands weeks of year), we want results to fall on the same weekday as the initial date
                       componentCombinations.weekdays = [.every(weekday)]
                       componentCombinations.daysOfYear = nil
                       componentCombinations.daysOfMonth = nil
                    }
                }
                if weekAction == .expand {
                    // In a yearly recurrence with weeks specified, results do not land on any specific month
                    componentCombinations.weeksOfYear = recurrence.weeks
                    componentCombinations.months = nil
                }
                if recurrence.frequency != .hourly, recurrence.frequency != .minutely {
                    componentCombinations.hours = if hourAction == .expand { recurrence.hours } else { components.hour.map { [$0] } }
                }
                if recurrence.frequency != .minutely {
                    componentCombinations.minutes = if minuteAction == .expand { recurrence.minutes } else { components.minute.map { [$0] } }
                }
                componentCombinations.seconds = if secondAction == .expand { recurrence.seconds } else { components.second.map { [$0] } }
                

                let searchInterval = calendar.dateInterval(of: recurrence.frequency.component, for: anchor)!
                let searchRange = searchInterval.start..<searchInterval.end
                let searchStart = searchInterval.start
                
                // First expand the set of dates, and then filter it. The order
                // of expansions is fixed, and must stay exactly as it is so we
                // conform to RFC5545

                dates = try! calendar._dates(startingAfter: searchStart, matching: componentCombinations, in: searchRange, matchingPolicy: recurrence.matchingPolicy, repeatedTimePolicy: recurrence.repeatedTimePolicy)
                 
                if monthAction == .limit {
                    recurrence._limitMonths(dates: &dates, anchor: anchor)
                }
                if dayOfYearAction == .limit {
                    recurrence._limitDaysOfTheYear(dates: &dates, anchor: anchor)
                }
                if dayOfMonthAction == .limit {
                    recurrence._limitDaysOfTheMonth(dates: &dates, anchor: anchor)
                }
                if weekdayAction == .limit {
                    recurrence._limitWeekdays(dates: &dates, anchor: anchor)
                }
                if hourAction == .limit {
                    recurrence._limitTimeComponent(.hour, dates: &dates, anchor: anchor)
                }
                if minuteAction == .limit {
                    recurrence._limitTimeComponent(.minute, dates: &dates, anchor: anchor)
                }
                if secondAction == .limit {
                    recurrence._limitTimeComponent(.second, dates: &dates, anchor: anchor)
                }
                
                if startDateNanoseconds > 0 {
                    // `_dates(startingAfter:)` above returns whole-second dates,
                    // so we need to restore the nanoseconds value present in the original start date.
                    for idx in dates.indices {
                        dates[idx] += startDateNanoseconds
                    }
                }
                dates = dates.filter { $0 >= self.start }
                
                if let limit = recurrence.end.date {
                    let hadDates = !dates.isEmpty
                    dates = dates.filter { $0 <= limit }
                    if hadDates && dates.isEmpty {
                        // In the case that the filter removed all dates, we are
                        // certain that it'll do the same for future iterations.
                        // End iteration.
                        finished = true
                        return
                    }
                }
                dates.sort()
                if !recurrence.setPositions.isEmpty {
                    dates = recurrence.setPositions.map { pos in
                        if pos < 0 {
                            dates.count + pos
                        } else {
                            pos - 1
                        }
                    }
                    .filter(dates.indices.contains)
                    .map { dates[$0] }
                }
                currentGroup = dates.reversed()
            }
            
            mutating func next() -> Element? {
                guard !finished else { return nil }
                if let limit = recurrence.end.occurrences, resultsFound >= limit {
                    finished = true
                    return nil
                }
                
                while !finished {
                    if let date = currentGroup.popLast() {
                        resultsFound += 1
                        if let limit = recurrence.end.date, date > limit {
                            finished = true
                            return nil
                        }
                        if let range = self.range {
                            if date >= range.upperBound {
                                finished = true
                                return nil
                            } else if date < range.lowerBound {
                                continue
                            }
                        }
                        return date
                    } else {
                        nextGroup()
                        if currentGroup.isEmpty {
                            iterationsSinceLastResult += 1
                            if iterationsSinceLastResult > searchLimit {
                                finished = true
                                return nil
                            }
                        } else {
                            iterationsSinceLastResult = 0
                        }
                    }
                }
                return nil
            }
        }
        
        public func makeIterator() -> Iterator {
            return Iterator(start: start, matching: recurrence, range: range)
        }
    }
}

extension Calendar.RecurrenceRule {
    internal func _limitMonths(dates: inout [Date], anchor: Date) {
        let months = calendar._normalizedMonths(months, for: anchor) 
        
        dates = dates.filter {
            let idx = calendar.component(.month, from: $0)
            let isLeap = calendar._dateComponents([.month], from: $0).isLeapMonth
            return months.contains {
                $0.index == idx && $0.isLeap == isLeap
            }
        }
    }
    internal func _limitDaysOfTheMonth(dates: inout [Date], anchor: Date) {
        dates = dates.filter { date in
            let day = calendar.component(.day, from: date)
            var dayRange: Range<Int>? = nil
            for dayOfMonth in daysOfTheMonth {
                if dayOfMonth > 0 {
                    if dayOfMonth == day { return true }
                } else {
                    if dayRange == nil {
                        dayRange = calendar.range(of: .day, in: .month, for: date)
                    }
                    if let dayRange, dayRange.upperBound + dayOfMonth == day { return true }
                }
            }
            return false
        }
    }
    
    internal func _limitDaysOfTheYear(dates: inout [Date], anchor: Date) {
        dates = dates.filter { date in
            let day = calendar.component(.dayOfYear, from: date)
            var dayRange: Range<Int>?
            for dayOfTheYear in daysOfTheYear {
                if dayOfTheYear > 0 {
                    if dayOfTheYear == day { return true }
                } else {
                    if dayRange == nil {
                        dayRange = calendar.range(of: .dayOfYear, in: .year, for: date)
                    }
                    if let dayRange, dayRange.upperBound + dayOfTheYear == day { return true }
                }
            }
            return false
        }
    }
    internal func _limitTimeComponent(_ component: Calendar.Component, dates: inout [Date], anchor: Date) {
        let values: [Int]
        switch component {
            case .hour:
            values = hours
            case .minute:
            values = minutes
            case .second:
            values = seconds
            default:
            return
        }
        dates = dates.filter { date in
            let value = calendar.component(component, from: date)
            return values.contains(value)
        }
    }    
    internal func _limitWeekdays(dates: inout [Date], anchor: Date) {
        let parentComponent: Calendar.Component
        switch frequency {
        case .yearly:
            if months.isEmpty {
                parentComponent = .year
            } else {
                parentComponent = .month
            }
        default:
            parentComponent = .month
        }

        let weekdayComponents = self.calendar._weekdayComponents(for: weekdays,
                                                   in: parentComponent,
                                                   anchor: anchor)
        dates = dates.filter { date in
            weekdayComponents?.contains(where: { components in
                calendar.date(date, matchesComponents: components)
            }) ?? false
        }
    }
    

}

extension Calendar {
    /// A struct similar to DateComponents that accepts multiple values for each
    /// component. The cross product of all component values in this struct is a
    /// a set of DateComponents that can be used for enumeration.
    ///
    /// Components here can be negative integers to indicate backwards search.
    struct _DateComponentCombinations {
        var daysOfMonth: [Int]? = nil
        var daysOfYear: [Int]? = nil
        var weeksOfYear: [Int]? = nil
        var months: [RecurrenceRule.Month]? = nil
        var weekdays: [RecurrenceRule.Weekday]? = nil
        var hours: [Int]? = nil
        var minutes: [Int]? = nil
        var seconds: [Int]? = nil
    }
    

    /// Find date components which can be used to filter or enumerate each given
    /// weekday in a range
    /// - Parameters:
    ///   - weekdays: an array of weekdays we want to find or filter
    ///   - parent: .year if the frequency is yearly, otherwise .month
    ///   - anchor: a date around which to perform the expansion
    /// - Returns: array of `DateComponents`, which can be used to enumerate all
    ///   weekdays of interest, or to filter a list of dates
    func _weekdayComponents(for weekdays: [Calendar.RecurrenceRule.Weekday],
                            in parent: Calendar.Component,
                            anchor: Date) -> [DateComponents]? {
        /// Map of weekdays to which occurrences of the weekday we are interested
        /// in. `1` is the first such weekday in the interval, `-1` is the last.
        /// An empty array indicates that any weekday is valid
        var map: [Locale.Weekday: [Int]] = [:]
        for weekday in weekdays {
            switch weekday {
            case .every(let day):
                map[day] = []
            case .nth(let n, let day):
                if let existing = map[day] {
                    if existing != [] {
                        map[day] = existing + [n]
                    }
                } else {
                    map[day] = [n]
                }
            }
        }
        // Now, let's convert indices in the map into indices of the weeks where
        // the given weekday occurs. The first given weekday of a month does not
        // necessarily occur in the first week of the month.
        
        /// The component where we set the week number, if we are targeting only
        /// a particular occurrence of a weekday
        let weekComponent: Calendar.Component = if parent == .month {
            .weekOfMonth
        } else {
            .weekOfYear
        }
                
        guard
            let interval = dateInterval(of: parent, for: anchor)
        else { return nil }
        
        lazy var weekRange = range(of: weekComponent, in: parent, for: anchor)!
        
        var result: [DateComponents] = []
        
        lazy var firstWeekday = component(.weekday, from: interval.start)
        // The end of the interval would always be midnight on the day after, so
        // it falls on the day after the last day in the interval. Subtracting a
        // few seconds can give us the last day in the interval
        lazy var lastWeekday = component(.weekday, from: interval.end.addingTimeInterval(-0.1))
        
        for (weekday, occurrences) in map {
            let weekdayIdx = weekday.icuIndex
            if occurrences == [] {
                var components = DateComponents()
                components.setValue(nil, for: weekComponent)
                components.weekday = weekdayIdx
                result.append(components)
            } else {
                lazy var firstWeek = weekRange.lowerBound + (weekdayIdx < firstWeekday ? 1 : 0)
                lazy var lastWeek  = weekRange.upperBound - (weekdayIdx > lastWeekday  ? 1 : 0)
                for occurrence in occurrences {
                    var components = DateComponents()
                    if occurrence > 0 {
                        components.setValue(firstWeek - 1 + occurrence, for: weekComponent)
                    } else {
                        components.setValue(lastWeek + occurrence, for: weekComponent)
                    }
                    components.weekday = weekdayIdx
                    result.append(components)
                    
                }
            }
        }
        return result
    }

    /// Normalized months so that all months are positive
    func _normalizedMonths(_ months: [Calendar.RecurrenceRule.Month], for anchor: Date) -> [Calendar.RecurrenceRule.Month] {
        lazy var monthRange = self.range(of: .month, in: .year, for: anchor)
        return months.compactMap { month in
            if month.index > 0 {
                return month
            } else if month.index > -monthRange!.upperBound {
                let newIndex = monthRange!.upperBound + month.index
                // The upper bound is the last month plus one. Subtracting 1 we get the last month
                return Calendar.RecurrenceRule.Month(newIndex, isLeap: month.isLeap)
            } else {
                return nil
            }
        }
    }
    
    /// Normalized days in a month so that all days are positive
    internal func _normalizedDaysOfMonth(_ days: [Int], for anchor: Date) -> [Int] {
        lazy var dayRange = self.range(of: .day, in: .month, for: anchor)
        return days.compactMap { day in
            if day > 0 {
                day
            } else if day > -dayRange!.upperBound {
                dayRange!.upperBound + day
            } else {
                nil
            }
        }
    }
    
    /// Normalized days in a year so that all days are positive
    internal func _normalizedDaysOfYear(_ days: [Int], for anchor: Date) -> [Int] {
        lazy var dayRange = self.range(of: .day, in: .year, for: anchor)
        return days.compactMap { day in
            if day > 0 {
                day
            } else if day > -dayRange!.upperBound {
                dayRange!.upperBound + day
            } else {
                nil
            }
        }
    }

    /// Normalized weeks of year so that all weeks are positive
    fileprivate func _normalizedWeeksOfYear(_ weeksOfYear: [Int], anchor: Date) -> [Int] {
        // Positive week indices can be treated as a date component the way they
        // are. Negative indices mean that we count backwards from the last week
        // of the year that contains the anchor weekday
        lazy var weekRange = self.range(of: .weekOfYear, in: .year, for: anchor)!
        lazy var lastDayOfYear = dateInterval(of: .year, for: anchor)!.end.addingTimeInterval(-0.01)
        lazy var lastWeekayOfYear = component(.weekday, from: lastDayOfYear)
        lazy var daysLeftInLastWeek = 7 - lastWeekayOfYear + firstWeekday

        lazy var lastWeekIdx = if daysLeftInLastWeek >= minimumDaysInFirstWeek {
            weekRange.upperBound - 1
        } else {
            weekRange.upperBound
        }
     
        return weeksOfYear.compactMap { weekIdx in
           if weekIdx > 0 {
               weekIdx
           } else if weekIdx > -lastWeekIdx {
               lastWeekIdx + weekIdx
           } else {
               nil
           }
        }
    }
    
    fileprivate func _unadjustedDates(after startDate: Date,
                                      matching combinationComponents: _DateComponentCombinations,
                                      matchingPolicy: MatchingPolicy,
                                      repeatedTimePolicy: RepeatedTimePolicy) throws -> [(Date, DateComponents)]? {

        let isStrictMatching = matchingPolicy == .strict

        var dates = [(date: startDate, components: DateComponents())]
        var lastMatchedComponent: Calendar.Component? = nil

        if let weeks = combinationComponents.weeksOfYear {
            dates = try dates.flatMap { date, comps in
                try _normalizedWeeksOfYear(weeks, anchor: date).map { week in
                    var comps = comps
                    comps.weekOfYear = week
                    var date = date
                    if let result = try dateAfterMatchingYearForWeekOfYear(startingAt: date, components: comps, direction: .forward) {
                        date = result
                    }

                    if let result = try dateAfterMatchingWeekOfYear(startingAt: date, components: comps, direction: .forward) {
                        date = result
                    }
                    return (date, comps)
                }
            }
        }

        if let daysOfYear = combinationComponents.daysOfYear {
            dates = try dates.flatMap { date, comps in
                try _normalizedDaysOfYear(daysOfYear, for: date).map { day in
                    var comps = comps
                    comps.dayOfYear = day
                    return try dateAfterMatchingDayOfYear(startingAt: date, components: comps, direction: .forward).map { ($0, comps) } ?? (date, comps)
                }
            }
            lastMatchedComponent = .dayOfYear
        }

        if let months = combinationComponents.months {
            dates = try dates.flatMap { date, comps in
                try _normalizedMonths(months, for: date).map { month in
                    var comps = comps
                    comps.month = month.index
                    comps.isLeapMonth = month.isLeap
                    return try dateAfterMatchingMonth(startingAt: date, components: comps, direction: .forward, strictMatching: isStrictMatching).map { ($0, comps) } ?? (date, comps)
                }
            }
            lastMatchedComponent = .month
        }

        if let weekdays = combinationComponents.weekdays {
            dates = try dates.flatMap { date, comps in
                let parentComponent: Calendar.Component = .month
                let weekdayComponents = _weekdayComponents(for: weekdays, in: parentComponent, anchor: date)
                let dates = try weekdayComponents!.map { comps in 
                    var date = date
                    if let result = try dateAfterMatchingWeekOfYear(startingAt: date, components: comps, direction: .forward) {
                        date = result
                    }
                    if let result = try dateAfterMatchingWeekOfMonth(startingAt: date, components: comps, direction: .forward) {
                        date = result
                    }
                    if let result = try dateAfterMatchingWeekdayOrdinal(startingAt: date, components: comps, direction: .forward) {
                        date = result
                    }
                    if let result = try dateAfterMatchingWeekday(startingAt: date, components: comps, direction: .forward) {
                        date = result
                    }
                    return (date, comps)
                }
                return dates
            }
        }

        if let daysOfMonth = combinationComponents.daysOfMonth {
            dates = try dates.flatMap { date, comps in
                try _normalizedDaysOfMonth(daysOfMonth, for: date).map { day in
                    var comps = comps
                    comps.day = day
                    return try dateAfterMatchingDay(startingAt: date, originalStartDate: startDate, components: comps, direction: .forward).map { ($0, comps) } ?? (date, comps)
                }
            }
            lastMatchedComponent = .day
        }

        if let hours = combinationComponents.hours {
            dates = try dates.flatMap { date, comps in
                let searchStart: Date
                if lastMatchedComponent == .day || lastMatchedComponent == .dayOfYear {
                    searchStart = date
                } else {
                    searchStart = self.dateInterval(of: .day, for: date)!.start
                }
                return try hours.map { hour in
                    var comps = comps
                    comps.hour = hour
                    return try dateAfterMatchingHour(startingAt: searchStart, originalStartDate: startDate, components: comps, direction: .forward, findLastMatch: repeatedTimePolicy == .last, isStrictMatching: isStrictMatching, matchingPolicy: matchingPolicy).map { ($0, comps) } ?? (date, comps)
                }
            }
            lastMatchedComponent = .hour
        }

        if let minutes = combinationComponents.minutes {
            dates = try dates.flatMap { date, comps in
                let searchStart: Date
                if lastMatchedComponent == .hour {
                    searchStart = date
                } else {
                    searchStart = self.dateInterval(of: .hour, for: date)!.start
                }
                return try minutes.map { minute in
                    var comps = comps
                    comps.minute = minute
                    return try dateAfterMatchingMinute(startingAt: searchStart, components: comps, direction: .forward).map { ($0, comps) } ?? (date, comps)
                }
            }
            lastMatchedComponent = .minute
        }

        if let seconds = combinationComponents.seconds {
            dates = try dates.flatMap { date, comps in
                let searchStart: Date
                if lastMatchedComponent == .minute {
                    searchStart = date
                } else {
                    searchStart = self.dateInterval(of: .minute, for: date)!.start
                }
                return try seconds.map { second in
                    var comps = comps
                    comps.second = second
                    return try dateAfterMatchingSecond(startingAt: searchStart, originalStartDate: startDate, components: comps, direction: .forward).map { ($0, comps) } ?? (date, comps)
                }
            }
        }

        return dates
    }

    /// All dates that match a combination of date components
    internal func _dates(startingAfter start: Date,
                         matching matchingComponents: _DateComponentCombinations,
                         in range: Range<Date>,
                         matchingPolicy: MatchingPolicy,
                         repeatedTimePolicy: RepeatedTimePolicy) throws -> [Date] {
      
        guard start.isValidForEnumeration else { return [] }

        guard let unadjustedMatchDates = try _unadjustedDates(after: start, matching: matchingComponents, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy) else {
            return []
        }
        
        let results =  try unadjustedMatchDates.map { date, components in
            let adjustedComponents = _adjustedComponents(components, date: start, direction: .forward)
            return (try _adjustedDate(date, startingAfter: start, allowStartDate: true, matching: components, adjustedMatchingComponents: adjustedComponents, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy, direction: .forward, inSearchingDate: start, previouslyReturnedMatchDate: nil), components)
        }
            
        var foundDates: [Date] = []
        for (result, _) in results {
            if let (matchDate, _) = result.result {
                if range.contains(matchDate) {
                    foundDates.append(matchDate)
                }
            }
        }
        return foundDates
    }
}
