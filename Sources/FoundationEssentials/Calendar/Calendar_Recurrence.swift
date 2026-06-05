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
// This file implements enumerating occurences according to a recurrence rule as
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
        /// The lower end of the search range. If `nil`, the search is unbounded
        /// in the past.
        let lowerBound: Date?
        /// The upper end of the search range. If `nil`, the search is unbounded
        /// in the future. If `inclusive` is true, `bound` is a valid result
        let upperBound: (bound: Date, inclusive: Bool)?
        
        init(start: Date, recurrence: RecurrenceRule, range: Range<Date>?) {
            self.start = start
            self.recurrence = recurrence
            if let range {
                self.lowerBound = range.lowerBound
                self.upperBound = (range.upperBound, false)
            } else {
                self.lowerBound = nil
                self.upperBound = nil
            }
        }

        init(start: Date, recurrence: RecurrenceRule, range: ClosedRange<Date>) {
            self.start = start
            self.recurrence = recurrence
            self.lowerBound = range.lowerBound
            self.upperBound = (range.upperBound, true)
        }

        init(start: Date, recurrence: RecurrenceRule, range: PartialRangeFrom<Date>) {
            self.start = start
            self.recurrence = recurrence
            self.lowerBound = range.lowerBound
            self.upperBound = nil
        }

        init(start: Date, recurrence: RecurrenceRule, range: PartialRangeThrough<Date>) {
            self.start = start
            self.recurrence = recurrence
            self.lowerBound = nil
            self.upperBound = (range.upperBound, true)
        }

        init(start: Date, recurrence: RecurrenceRule, range: PartialRangeUpTo<Date>) {
            self.start = start
            self.recurrence = recurrence
            self.lowerBound = nil
            self.upperBound = (range.upperBound, false)
        }
        
        struct Iterator: Sendable, IteratorProtocol {
            /// The starting date for the recurrence
            let start: Date
            /// The recurrence rule that should be used for enumeration
            let recurrence: RecurrenceRule

            /// The lower bound for iteration results, inclusive
            let lowerBound: Date?
            /// The upper bound for iteration results and whether it's inclusive
            let upperBound: (bound: Date, inclusive: Bool)?
            
            /// The start date's nanoseconds component
            let startDateNanoseconds: TimeInterval
            
            /// How many occurrences have been found so far
            var resultsFound = 0
            
            let monthAction, weekAction, dayOfYearAction, dayOfMonthAction, weekdayAction, hourAction, minuteAction, secondAction: ComponentAction?
           
            /// An iterator for a sequence of dates spaced evenly from the start
            /// date, by the interval specified by the recurrence rule frequency
            /// This does not include the start date itself.
            var baseRecurrence: Calendar.DatesByMatching.Iterator
            /// The lower bound for `baseRecurrence`. Note that this date can be
            /// lower than `lowerBound`
            let baseRecurrenceLowerBound: Date?
            
            
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
                          lowerBound: Date?,
                          upperBound: (bound: Date, inclusive: Bool)?) {
                // Copy the calendar if it's autoupdating
                var recurrence = recurrence
                if recurrence.calendar == .autoupdatingCurrent {
                    recurrence.calendar = .current
                }
                self.recurrence = recurrence
                
                self.start = start
                
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
                
                self.lowerBound = lowerBound
                self.upperBound = upperBound
                if let lowerBound {
                    baseRecurrenceLowerBound = recurrence.calendar.dateInterval(of: frequency.component, for: lowerBound)?.start
                } else {
                    baseRecurrenceLowerBound = nil
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
                    if let baseRecurrenceLowerBound, nextDate < baseRecurrenceLowerBound {
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
                        if let upperBound = self.upperBound {
                            let outOfRange = switch upperBound.inclusive {
                                case true:  date > upperBound.bound
                                case false: date >= upperBound.bound
                            }
                            if outOfRange {
                                finished = true
                                return nil
                            }
                        }
                        if let lowerBound = self.lowerBound {
                            if date < lowerBound {
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
            return Iterator(start: start, matching: recurrence, lowerBound: lowerBound, upperBound: upperBound)
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

    /// Whether the combinations contain any `.nth(N, day)` with `N < 0`.
    fileprivate func _unadjustedDatesHasNegativeOrdinal(_ c: _DateComponentCombinations) -> Bool {
        guard let weekdays = c.weekdays else { return false }
        for w in weekdays {
            if case .nth(let n, _) = w, n < 0 { return true }
        }
        return false
    }

    /// Expand `_DateComponentCombinations` into a flat array of single-valued
    /// `DateComponents`. Negative ordinals are translated to `{month, weekday,
    /// weekOfMonth}` using `anchor`'s month structure. Returns nil if the
    /// pattern can't be expanded (too many combinations, `.every()` weekday, etc).
    fileprivate func _expandedDateComponents(
        _ c: _DateComponentCombinations,
        anchor: Date? = nil,
        maxCombinations: Int = 64
    ) -> [DateComponents]? {
        var hasNegativeOrdinal = false
        if let weekdays = c.weekdays {
            for w in weekdays {
                switch w {
                case .every:
                    return nil
                case .nth(let n, _):
                    if n == 0 { return nil }
                    if n < 0 {
                        guard anchor != nil else { return nil }
                        hasNegativeOrdinal = true
                    }
                }
            }
        }

        let monthsCount = c.months?.count ?? 1
        let weekdaysCount = c.weekdays?.count ?? 1
        let daysOfMonthCount = c.daysOfMonth?.count ?? 1
        let daysOfYearCount = c.daysOfYear?.count ?? 1
        let weeksOfYearCount = c.weeksOfYear?.count ?? 1
        let hoursCount = c.hours?.count ?? 1
        let minutesCount = c.minutes?.count ?? 1
        let secondsCount = c.seconds?.count ?? 1

        let total = monthsCount * weekdaysCount * daysOfMonthCount
                  * daysOfYearCount * weeksOfYearCount
                  * hoursCount * minutesCount * secondsCount
        if total <= 0 { return nil }
        if total > maxCombinations { return nil }
        if total <= 1 { return nil }

        // Precompute target month structure for negative-ordinal translation.
        struct MonthInfo {
            let month: Int
            let isLeapMonth: Bool
            let day1Weekday: Int   // 1..7 (Sunday=1)
            let daysInMonth: Int
            let firstWeekday: Int  // calendar's
            let minDays: Int       // calendar's
        }
        var monthInfo: MonthInfo? = nil
        if hasNegativeOrdinal, let anchor = anchor {
            let targetMonth: Int
            let targetIsLeap: Bool
            let targetYear: Int
            if let ms = c.months, ms.count == 1 {
                targetMonth = ms[0].index
                targetIsLeap = ms[0].isLeap
                targetYear = self.component(.year, from: anchor)
            } else if c.months == nil || c.months!.isEmpty {
                targetMonth = self.component(.month, from: anchor)
                targetIsLeap = false
                targetYear = self.component(.year, from: anchor)
            } else {
                return nil
            }

            var monthStartComps = DateComponents()
            monthStartComps.year = targetYear
            monthStartComps.month = targetMonth
            monthStartComps.day = 1
            if targetIsLeap { monthStartComps.isLeapMonth = true }

            guard let monthStart = self.date(from: monthStartComps),
                  let dayRange = self.range(of: .day, in: .month, for: monthStart) else {
                return nil
            }
            let daysInMonth = dayRange.upperBound - 1
            let day1Weekday = self.component(.weekday, from: monthStart)

            monthInfo = MonthInfo(
                month: targetMonth,
                isLeapMonth: targetIsLeap,
                day1Weekday: day1Weekday,
                daysInMonth: daysInMonth,
                firstWeekday: self.firstWeekday,
                minDays: self.minimumDaysInFirstWeek
            )
        }

        // Translate a `.nth(N, day)` entry to DC fields. Returns false if out of range.
        func translateWeekday(_ entry: RecurrenceRule.Weekday, into dc: inout DateComponents) -> Bool {
            guard case .nth(let n, let dayOfWeek) = entry else { return false }
            let wdIdx = dayOfWeek.icuIndex
            if n > 0 {
                dc.weekdayOrdinal = n
                dc.weekday = wdIdx
                return true
            }
            // Negative ordinal → {month, weekday, weekOfMonth}.
            guard let info = monthInfo else { return false }
            let firstOcc = 1 + ((wdIdx - info.day1Weekday + 7) % 7)   // 1..7
            let totalOcc = (info.daysInMonth - firstOcc) / 7 + 1
            let kthFromLast = -n
            let dayOfMonth = firstOcc + (totalOcc - kthFromLast) * 7
            guard dayOfMonth >= 1, dayOfMonth <= info.daysInMonth else { return false }
            let periodStart = ((info.day1Weekday - info.firstWeekday) % 7 + 7) % 7
            let correction = (7 - periodStart) >= info.minDays ? 1 : 0
            let weekOfMonth = (dayOfMonth + periodStart - 1) / 7 + correction
            dc.month = info.month
            dc.isLeapMonth = info.isLeapMonth
            dc.weekday = wdIdx
            dc.weekOfMonth = weekOfMonth
            return true
        }

        func make(monthIdx: Int, weekdayIdx: Int,
                  daysOfMonthIdx: Int, daysOfYearIdx: Int, weeksOfYearIdx: Int,
                  hoursIdx: Int, minutesIdx: Int, secondsIdx: Int) -> DateComponents? {
            var dc = DateComponents()
            if let ms = c.months {
                dc.month = ms[monthIdx].index
                dc.isLeapMonth = ms[monthIdx].isLeap
            }
            if let woy = c.weeksOfYear { dc.weekOfYear = woy[weeksOfYearIdx] }
            if let doy = c.daysOfYear { dc.dayOfYear = doy[daysOfYearIdx] }
            if let dom = c.daysOfMonth { dc.day = dom[daysOfMonthIdx] }
            if let wds = c.weekdays {
                guard translateWeekday(wds[weekdayIdx], into: &dc) else { return nil }
            }
            if let hs = c.hours { dc.hour = hs[hoursIdx] }
            if let mins = c.minutes { dc.minute = mins[minutesIdx] }
            if let secs = c.seconds { dc.second = secs[secondsIdx] }
            return dc
        }

        var result: [DateComponents] = []
        result.reserveCapacity(total)
        for mIdx in 0..<monthsCount {
            for wIdx in 0..<weekdaysCount {
                for domIdx in 0..<daysOfMonthCount {
                    for doyIdx in 0..<daysOfYearCount {
                        for woyIdx in 0..<weeksOfYearCount {
                            for hIdx in 0..<hoursCount {
                                for miIdx in 0..<minutesCount {
                                    for sIdx in 0..<secondsCount {
                                        guard let dc = make(
                                            monthIdx: mIdx, weekdayIdx: wIdx,
                                            daysOfMonthIdx: domIdx,
                                            daysOfYearIdx: doyIdx,
                                            weeksOfYearIdx: woyIdx,
                                            hoursIdx: hIdx, minutesIdx: miIdx,
                                            secondsIdx: sIdx) else { return nil }
                                        result.append(dc)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        return result
    }

    /// Single-valued `DateComponents` from combinations, or nil if expansion is needed.
    fileprivate func _singleCombinationDateComponents(
        _ c: _DateComponentCombinations
    ) -> DateComponents? {
        if let count = c.weeksOfYear?.count, count > 1 { return nil }
        if let count = c.daysOfYear?.count, count > 1 { return nil }
        if let count = c.months?.count, count > 1 { return nil }
        if let count = c.daysOfMonth?.count, count > 1 { return nil }
        if let count = c.weekdays?.count, count > 1 { return nil }
        if let count = c.hours?.count, count > 1 { return nil }
        if let count = c.minutes?.count, count > 1 { return nil }
        if let count = c.seconds?.count, count > 1 { return nil }

        var dc = DateComponents()
        if let m = c.months?.first {
            dc.month = m.index
            dc.isLeapMonth = m.isLeap
        }
        if let woy = c.weeksOfYear?.first { dc.weekOfYear = woy }
        if let doy = c.daysOfYear?.first { dc.dayOfYear = doy }
        if let dom = c.daysOfMonth?.first { dc.day = dom }
        if let weekday = c.weekdays?.first {
            switch weekday {
            case .every:
                return nil
            case .nth(let n, let day):
                guard n >= 1 else { return nil }   // negative ordinals not in our fast path
                dc.weekdayOrdinal = n
                dc.weekday = day.icuIndex
            }
        }
        if let h = c.hours?.first { dc.hour = h }
        if let mi = c.minutes?.first { dc.minute = mi }
        if let s = c.seconds?.first { dc.second = s }

        return dc
    }
    

    /// Find date components which can be used to filter or enumerate each given
    /// weekday in a range
    /// - Parameters:
    ///   - weekdays: an array of weekdays we want to find or filter
    ///   - parent: .year if the frequency is yearly, otherwise .month
    ///   - anchor: a date around which to perform the expansion
    /// - Returns: array of `DateComponents`, which can be used to enumerate all
    ///   weekdays of intereset, or to filter a list of dates
    func _weekdayComponents(for weekdays: [Calendar.RecurrenceRule.Weekday],
                            in parent: Calendar.Component,
                            anchor: Date) -> [DateComponents]? {
        /// Map of weekdays to which occurences of the weekday we are interested
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
        /// a particular occurence of a weekday
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
        let calendarFirstWeekday = self.firstWeekday

        /// Convert an absolute weekday (Sun=1...Sat=7) to an index within the calendar's week, which can start on an arbitrary weekday.
        func positionInWeek(_ weekday: Int) -> Int {
            (weekday - calendarFirstWeekday + 7) % 7
        }

        for (weekday, occurences) in map {
            let weekdayIdx = weekday.icuIndex
            if occurences == [] {
                var components = DateComponents()
                components.setValue(nil, for: weekComponent)
                components.weekday = weekdayIdx
                result.append(components)
            } else {
                lazy var firstWeek = weekRange.lowerBound + (positionInWeek(weekdayIdx) < positionInWeek(firstWeekday) ? 1 : 0)
                lazy var lastWeek  = weekRange.upperBound - (positionInWeek(weekdayIdx) > positionInWeek(lastWeekday)  ? 1 : 0)
                for occurence in occurences {
                    var components = DateComponents()
                    if occurence > 0 {
                        components.setValue(firstWeek - 1 + occurence, for: weekComponent)
                    } else {
                        components.setValue(lastWeek + occurence, for: weekComponent)
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

        // Fast-path short-circuits. The protocol default for _calendarNextDate is nil,
        // so non-Hebrew calendars fall through to the existing path unchanged.

        // (1) Single-combination: one value per field → single _calendarNextDate call.
        if matchingPolicy == .nextTime && repeatedTimePolicy == .first,
           let dc = _singleCombinationDateComponents(combinationComponents),
           let fast = _calendarNextDate(after: startDate, matching: dc, direction: .forward) {
            return [(fast, dc)]
        }

        // (2) Multi-combination (positive ordinals): cartesian product → probe each.
        if matchingPolicy == .nextTime && repeatedTimePolicy == .first,
           let allDCs = _expandedDateComponents(combinationComponents) {
            var results: [(Date, DateComponents)] = []
            results.reserveCapacity(allDCs.count)
            var allFastPathed = true
            for dc in allDCs {
                guard let fast = _calendarNextDate(after: startDate, matching: dc, direction: .forward) else {
                    allFastPathed = false
                    break
                }
                results.append((fast, dc))
            }
            if allFastPathed && !results.isEmpty {
                results.sort { $0.0 < $1.0 }
                return results
            }
        }

        // (3) Multi-combination with negative-ordinal translation.
        if matchingPolicy == .nextTime && repeatedTimePolicy == .first,
           _unadjustedDatesHasNegativeOrdinal(combinationComponents) {
            var sentinel = DateComponents()
            sentinel.weekday = 1
            if _calendarNextDate(after: startDate, matching: sentinel, direction: .forward) != nil,
               let allDCs = _expandedDateComponents(combinationComponents, anchor: startDate) {
                var results: [(Date, DateComponents)] = []
                results.reserveCapacity(allDCs.count)
                var allFastPathed = true
                for dc in allDCs {
                    guard let fast = _calendarNextDate(after: startDate, matching: dc, direction: .forward) else {
                        allFastPathed = false
                        break
                    }
                    results.append((fast, dc))
                }
                if allFastPathed && !results.isEmpty {
                    results.sort { $0.0 < $1.0 }
                    return results
                }
            }
        }

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
