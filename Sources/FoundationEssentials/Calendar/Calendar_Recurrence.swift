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
@available(FoundationPreview 0.4, *)
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
            
            /// How many occurrences have been found so far
            var resultsFound = 0
            
            let monthAction, weekAction, dayOfYearAction, dayOfMonthAction, weekdayAction, hourAction, minuteAction, secondAction: ComponentAction?
           
            /// An iterator for a sequence of dates spaced evenly from the start
            /// date, by the interval specified by the recurrence rule frequency
            /// This does not include the start date itself.
            var baseRecurrence: Calendar.DatesByMatching.Iterator
            
            var componentsForEnumerating: DateComponents
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
                    case .yearly:   [.second, .minute, .hour, .day, .month]
                }
                componentsForEnumerating = recurrence.calendar._dateComponents(components, from: start) 
                
                let rangeForBaseRecurrence: Range<Date>? = nil
                baseRecurrence = Calendar.DatesByMatching(calendar: recurrence.calendar,
                                                          start: start,
                                                          range: rangeForBaseRecurrence,
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

                var componentCombinations = Calendar._DateComponentsCombinations()
                
                if recurrence.frequency == .yearly || recurrence.frequency == .monthly {
                    if recurrence.daysOfTheYear.isEmpty {
                        componentCombinations.months = if recurrence.months.isEmpty { [RecurrenceRule.Month(from: components)!] } else { recurrence.months }
                        componentCombinations.daysOfMonth = if recurrence.daysOfTheMonth.isEmpty { [components.day!] } else { recurrence.daysOfTheMonth}
                        componentCombinations.daysOfYear = nil
                    } else {
                        componentCombinations.months = nil
                        componentCombinations.daysOfMonth = nil
                        componentCombinations.daysOfYear = if recurrence.daysOfTheYear.isEmpty { [components.day!] } else { recurrence.daysOfTheYear}
                    }
                } else {
                    componentCombinations.months = nil
                    componentCombinations.daysOfMonth = nil
                    componentCombinations.daysOfYear = nil
                }
                let searchInterval = calendar.dateInterval(of: recurrence.frequency.component, for: anchor)!
                let searchRange = searchInterval.start..<searchInterval.end
                let searchStart = searchInterval.start
                if weekdayAction == .expand {
                    componentCombinations.weekdays = recurrence.weekdays
                    componentCombinations.daysOfYear = nil
                    componentCombinations.daysOfMonth = nil
                } else if recurrence.frequency == .weekly || !recurrence.weeks.isEmpty {
                   if let weekdayIdx = components.weekday, let weekday = Locale.Weekday(weekdayIdx) {
                       componentCombinations.weekdays = [.every(weekday)]
                       componentCombinations.daysOfYear = nil
                       componentCombinations.daysOfMonth = nil
                    }
                }
                if recurrence.frequency != .hourly, recurrence.frequency != .minutely {
                    componentCombinations.hours   = if hourAction   == .expand { recurrence.hours   } else { components.hour.map { [$0] } }
                }
                if recurrence.frequency != .minutely {
                    componentCombinations.minutes = if minuteAction == .expand { recurrence.minutes } else { components.minute.map { [$0] } }
                }
                componentCombinations.seconds = if secondAction == .expand { recurrence.seconds } else { components.second.map { [$0] } }
                
                dates = calendar._enumerateDates(startingAfter: searchStart, matching: componentCombinations, in: searchRange, matchingPolicy: recurrence.matchingPolicy, repeatedTimePolicy: recurrence.repeatedTimePolicy)
                 
                // First expand the set of dates, and then filter it. The order
                // of expansions is fixed, and must stay exactly as it is so we
                // conform to RFC5545
                for action in [ComponentAction.limit] {
                    if monthAction == action {
                        recurrence._expandOrLimitMonths(dates: &dates, anchor: anchor, action: action)
                    }
                    if weekAction == action, action == .expand {
                        recurrence._expandWeeks(dates: &dates, anchor: anchor) 
                    }
                    if dayOfYearAction == action {
                        recurrence._expandOrLimitDaysOfTheYear(dates: &dates, anchor: anchor, action: action)
                    }
                    if dayOfMonthAction == action {
                        recurrence._expandOrLimitDaysOfTheMonth(dates: &dates, anchor: anchor, action: action)
                    }
                    if weekdayAction == action {
                        recurrence._expandOrLimitWeekdays(dates: &dates, anchor: anchor, action: action)
                    }
                    if hourAction == action {
                        recurrence._expandOrLimitTimeComponent(.hour, dates: &dates, anchor: anchor, action: action)
                    }
                    if minuteAction == action {
                        recurrence._expandOrLimitTimeComponent(.minute, dates: &dates, anchor: anchor, action: action)
                    }
                    if secondAction == action {
                        recurrence._expandOrLimitTimeComponent(.second, dates: &dates, anchor: anchor, action: action)
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
                            if date > range.upperBound {
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
    /// Move each date to the given weeks of the year
    internal func _expandWeeks(dates: inout [Date], anchor: Date) {
        guard
          let yearInterval = calendar.dateInterval(of: .year, for: anchor),
          let weekRange = calendar.range(of: .weekOfYear, in: .year, for: anchor)
          else {
            return
        }
        
        /// The weekday on which the first day of the year falls
        let firstWeekdayOfYear = calendar.component(.weekday, from: yearInterval.start)
        /// The weekday on which the last day of the year falls. We remove a few
        /// seconds from the end of the range, since it falls on January 1 00:00
        /// the following year.
        let lastWeekayOfYear = calendar.component(.weekday, from: yearInterval.end.addingTimeInterval(-0.01))
        
        let minimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
        let firstWeekday = calendar.firstWeekday
        
        /// How many days of the first week are within the year
        let daysInFirstWeek = 7 - firstWeekdayOfYear + firstWeekday
        /// How many days of the last week are within the year
        let daysLeftInLastWeek = 7 - lastWeekayOfYear + firstWeekday
        
        
        let firstWeekIdx = if daysInFirstWeek >= minimumDaysInFirstWeek {
            weekRange.lowerBound
        } else {
            weekRange.lowerBound + 1
        }
        
        let lastWeekIdx = if daysLeftInLastWeek >= minimumDaysInFirstWeek {
            weekRange.upperBound - 2
        } else {
            weekRange.upperBound - 1
        }
        
        let weeks = weeks.map { weekIdx in
           if weekIdx > 0 {
               weekIdx - 1 + firstWeekIdx
           } else {
               lastWeekIdx + (weekIdx + 1)
           }
        }
        
        dates = dates.flatMap { date in
            let week = calendar.component(.weekOfYear, from: date)
            return weeks.compactMap { weekIdx in
                let offset = weekIdx - week
                return calendar.date(byAdding: .weekOfYear, value: offset, to: date)
            }
        }
    }
    
    internal func _expandOrLimitMonths(dates: inout [Date], anchor: Date, action: ComponentAction) {
        lazy var monthRange = calendar.range(of: .month, in: .year, for: anchor)!
        let months = months.map { month in
            if month.index > 0 {
                return month
            } else {
                let newIndex = monthRange.upperBound + month.index
                // The upper bound is the last month plus one. Subtracting 1 we get the last month
                return Calendar.RecurrenceRule.Month(newIndex, isLeap: month.isLeap)
            }
        }
        
        if action == .limit {
            dates = dates.filter {
                let idx = calendar.component(.month, from: $0)
                let isLeap = calendar._dateComponents([.month], from: $0).isLeapMonth
                return months.contains {
                    $0.index == idx && $0.isLeap == isLeap
                }
            }
        } else {
            let componentSet: Calendar.ComponentSet = [ .month, .isLeapMonth, .day, .hour, .minute, .second ]
            
            let anchorComponents = calendar._dateComponents(componentSet, from: anchor)
            let daysInYear = calendar.dateInterval(of: .year, for: anchor)!
            // This is always the first expansion, so we can overwrite `dates`
            dates = months.compactMap { month in
                var components = anchorComponents
                components.month = month.index
                components.isLeapMonth = month.isLeap
                return calendar.nextDate(after: daysInYear.start, matching: components, matchingPolicy: matchingPolicy)
            }
        }
    }
    internal func _expandOrLimitDaysOfTheMonth(dates: inout [Date], anchor: Date, action: ComponentAction) {
        if action == .limit {
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
        } else {
            let components: Calendar.ComponentSet = [.day, .hour, .minute, .second]
            let anchorComponents = calendar._dateComponents(components, from: anchor)
            
            var componentsForEnumerating: [DateComponents] = []
            
            if frequency == .yearly {
                let monthRange = calendar.range(of: .month, in: .year, for: anchor)!
                let enumerationDateInterval = calendar.dateInterval(of: frequency.component, for: anchor)!
                let firstDayOfYear = enumerationDateInterval.start
                lazy var monthsToDaysInMonth = monthRange.reduce(into: [Int: Int]()) {
                    dict, month in
                    let dayInMonth = calendar.date(bySetting: .month, value: month, of: firstDayOfYear)!
                    let numberOfDaysInMonth = calendar.range(of: .day, in: .month, for: dayInMonth)!
                    dict[month] = numberOfDaysInMonth.upperBound - 1
                }
                for day in daysOfTheMonth {
                    if day > 0 {
                        var components = anchorComponents
                        components.day = day
                        componentsForEnumerating.append(components)
                    } else {
                        for (month, daysInMonth) in monthsToDaysInMonth {
                            var components = anchorComponents
                            components.day = daysInMonth + 1 + day
                            components.month = month
                            componentsForEnumerating.append(components)
                        }
                    }
                }
            } else {
                for day in daysOfTheMonth {
                    let daysInMonth = calendar.range(of: .day, in: .month, for: anchor)!.upperBound - 1
                    var components = anchorComponents
                    if day > 0 {
                        components.day = day
                    } else {
                        components.day = daysInMonth + 1 + day
                    }
                    componentsForEnumerating.append(components)
                }
            }
            dates = dates.flatMap { date in
                let enumerationDateInterval = calendar.dateInterval(of: .month, for: date)!
                var expandedDates: [Date] = []
                for components in componentsForEnumerating {
                    if calendar.date(enumerationDateInterval.start, matchesComponents: components) {
                        expandedDates.append(enumerationDateInterval.start)

                    }
                    for date in calendar.dates(byMatching: components,
                                               startingAt: enumerationDateInterval.start,
                                               in: enumerationDateInterval.start..<enumerationDateInterval.end,
                                               matchingPolicy: matchingPolicy,
                                               repeatedTimePolicy: repeatedTimePolicy) {
                        expandedDates.append(date)
                    }
                }
                return expandedDates
            }
        }
    }
    
    internal func _expandOrLimitDaysOfTheYear(dates: inout [Date], anchor: Date, action: ComponentAction) {
        if action == .limit {
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
        } else {
            let components: Calendar.ComponentSet = [.hour, .minute, .second]
            let anchorComponents = calendar._dateComponents(components, from: anchor)
            
            var componentsForEnumerating: [DateComponents] = []
            let enumerationDateInterval = calendar.dateInterval(of: frequency.component, for: anchor)!
            
            lazy var daysInYear = calendar.range(of: .dayOfYear, in: .year, for: anchor)!.upperBound - 1
            for day in daysOfTheYear {
                if day > 0 {
                    var components = anchorComponents
                    components.dayOfYear = day
                    componentsForEnumerating.append(components)
                } else {
                    var components = anchorComponents
                    components.dayOfYear = daysInYear + 1 + day
                    componentsForEnumerating.append(components)
                }
            }
            dates = dates.flatMap { date in
                var expandedDates: [Date] = []
                for components in componentsForEnumerating {
                    for date in calendar.dates(byMatching: components,
                                               startingAt: enumerationDateInterval.start,
                                               in: enumerationDateInterval.start..<enumerationDateInterval.end,
                                               matchingPolicy: matchingPolicy,
                                               repeatedTimePolicy: repeatedTimePolicy) {
                        expandedDates.append(date)
                    }
                }
                return expandedDates
            }
        }
    }
    internal func _expandOrLimitTimeComponent(_ component: Calendar.Component, dates: inout [Date], anchor: Date, action: ComponentAction) {
        let values: [Int]
        let parent: Calendar.Component
        switch component {
            case .hour:
            values = hours
            parent = .day
            case .minute:
            values = minutes
            parent = .hour
            case .second:
            values = seconds
            parent = .minute
            default:
            return
        }
        if action == .limit {
            dates = dates.filter { date in
                let value = calendar.component(component, from: date)
                return values.contains(value)
            }
        } else {
            let components: Calendar.ComponentSet = [.minute, .second]
            var anchorComponents = calendar._dateComponents(components, from: anchor)
            if component == .minute {
                anchorComponents.hour = nil
            } else if component == .second {
                anchorComponents.hour = nil
                anchorComponents.minute = nil
            }
            let componentsForEnumerating: [DateComponents] = values.map {
                var components = anchorComponents
                components.setValue($0, for: component)
                return components
            }
            
            
            dates = dates.flatMap { date in
                let enumerationDateInterval = calendar.dateInterval(of: parent, for: date)!
                var expandedDates: [Date] = []
                for components in componentsForEnumerating {
                    if calendar.date(date, matchesComponents: components) {
                        expandedDates.append(date)
                    }
                    for date in calendar.dates(byMatching: components,
                                               startingAt: enumerationDateInterval.start,
                                               in: enumerationDateInterval.start..<enumerationDateInterval.end,
                                               matchingPolicy: matchingPolicy,
                                               repeatedTimePolicy: repeatedTimePolicy) {
                        expandedDates.append(date)
                    }
                }
                return expandedDates
            }
        }
    }    
    internal func _expandOrLimitWeekdays(dates: inout [Date], anchor: Date, action: ComponentAction) {
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

        if action == .limit {
            let weekdayComponents = _weekdayComponents(for: weekdays,
                                                       in: parentComponent,
                                                       anchor: anchor)
            dates = dates.filter { date in
                weekdayComponents?.contains(where: { components in
                    calendar.date(date, matchesComponents: components)
                }) ?? false
            }
        } else {
            // Expand
            let componentForRange: Calendar.Component = switch frequency {
            case .yearly, .monthly: parentComponent
            default: frequency.component
            }
            dates = dates.flatMap { anchor in
                var dates: [Date] = []
                let weekdayComponents = _weekdayComponents(for: weekdays,
                                                           in: parentComponent,
                                                           anchor: anchor)!
                let range = calendar.dateInterval(of: componentForRange, for: anchor)!
                let start = range.start
                for dc in weekdayComponents {
                    var dc = dc
                    if frequency.component == .weekOfMonth {
                        dc.month = nil
                        dc.isLeapMonth = nil
                        dc.era = nil
                        dc.year = nil
                    }
                    dates += Array(calendar.dates(byMatching: dc, startingAt: start, in: range.start..<range.end, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy ))
                }
                return dates
            }
        }
    }
    
    func _weekdayComponents(for weekdays: [Calendar.RecurrenceRule.Weekday],
                            in parent: Calendar.Component,
                            anchor: Date,
                            anchorComponents: DateComponents? = nil) -> [DateComponents]? {
        Calendar.RecurrenceRule._weekdayComponents(calendar: self.calendar, for: weekdays, in: parent, anchor: anchor, anchorComponents: anchorComponents) 
    }
    /// Find date components which can be used to filter or enumerate each given
    /// weekday in a range
    /// - Parameters:
    ///   - weekdays: an array of weekdays we want to find or filter
    ///   - parent: .year if the frequency is yearly, otherwise .month
    ///   - anchor: a date around which to perform the expansion
    /// - Returns: array of `DateComponents`, which can be used to enumerate all
    ///   weekdays of intereset, or to filter a list of dates
    static func _weekdayComponents(calendar: Calendar, for weekdays: [Calendar.RecurrenceRule.Weekday],
                            in parent: Calendar.Component,
                            anchor: Date,
                            anchorComponents: DateComponents? = nil) -> [DateComponents]? {
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
        /// The components we return for matching and enumeration
        let componentSet: Calendar.ComponentSet = [.weekday, .hour, .minute, .second]
        
                
        guard
            let interval = calendar.dateInterval(of: parent, for: anchor)
        else { return nil }
        
        lazy var weekRange = calendar.range(of: weekComponent, in: parent, for: anchor)!
        
        var result: [DateComponents] = []
        let anchorComponents = anchorComponents ?? calendar._dateComponents(componentSet, from: anchor)
        
        lazy var firstWeekday = calendar.component(.weekday, from: interval.start)
        // The end of the interval would always be midnight on the day after, so
        // it falls on the day after the last day in the interval. Subtracting a
        // few seconds can give us the last day in the interval
        lazy var lastWeekday  = calendar.component(.weekday, from: interval.end.addingTimeInterval(-0.1))
        
        for (weekday, occurences) in map {
            let weekdayIdx = weekday.icuIndex
            if occurences == [] {
                var components = anchorComponents
                components.setValue(nil, for: weekComponent)
                components.weekday = weekdayIdx
                result.append(components)
            } else {
                lazy var firstWeek = weekRange.lowerBound + (weekdayIdx < firstWeekday ? 1 : 0)
                lazy var lastWeek  = weekRange.upperBound - (weekdayIdx > lastWeekday  ? 1 : 0)
                for occurence in occurences {
                    var components = anchorComponents
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
}

extension Calendar {
    struct _DateComponentsCombinations {
        var daysOfMonth: [Int]? = nil
        var daysOfYear: [Int]? = nil
        var weeksOfYear: [Int]? = nil
        var months: [RecurrenceRule.Month]? = nil
        var weekdays: [RecurrenceRule.Weekday]? = nil
        var hours: [Int]? = nil
        var minutes: [Int]? = nil
        var seconds: [Int]? = nil
    }
    
    internal func _normalizeMonths(_ months: [Calendar.RecurrenceRule.Month], for anchor: Date) -> [Calendar.RecurrenceRule.Month] {
        lazy var monthRange = self.range(of: .month, in: .year, for: anchor)
        return months.map { month in
            if month.index > 0 {
                return month
            } else {
                let newIndex = monthRange!.upperBound + month.index
                // The upper bound is the last month plus one. Subtracting 1 we get the last month
                return Calendar.RecurrenceRule.Month(newIndex, isLeap: month.isLeap)
            }
        }
    }
    
    internal func _normalizeDaysOfMonth(_ days: [Int], for anchor: Date) -> [Int] {
        lazy var dayRange = self.range(of: .day, in: .month, for: anchor)
        return days.map { day in
            if day > 0 {
                day
            } else {
                dayRange!.upperBound + day
            }
        }
    }
    
    internal func _normalizeDaysOfYear(_ days: [Int], for anchor: Date) -> [Int] {
        lazy var dayRange = self.range(of: .day, in: .year, for: anchor)
        return days.map { day in
            if day > 0 {
                day
            } else {
                dayRange!.upperBound + day
            }
        }
    }
    
    fileprivate func _matchingDates(after startDate: Date,
                        matching combinationComponents: _DateComponentsCombinations,
                        direction: SearchDirection,
                        matchingPolicy: MatchingPolicy,
                        repeatedTimePolicy: RepeatedTimePolicy) throws -> [(Date, DateComponents)]? {

        let isStrictMatching = matchingPolicy == .strict

        var dates = [(date: startDate, components: DateComponents())]
        var lastMatchedComponent: Calendar.Component? = nil

        if let weeks = combinationComponents.weeksOfYear {
            dates = try dates.flatMap { date, comps in
                try weeks.map { week in
                    var comps = comps
                    comps.weekOfYear = week
                    var date = date
                    if let result = try dateAfterMatchingYearForWeekOfYear(startingAt: date, components: comps, direction: direction) {
                        date = result
                    }

                    if let result = try dateAfterMatchingWeekOfYear(startingAt: date, components: comps, direction: direction) {
                        date = result
                    }
                    return (date, comps)
                }
            }
        }

        if let daysOfYear = combinationComponents.daysOfYear {
            dates = try dates.flatMap { date, comps in
                try _normalizeDaysOfYear(daysOfYear, for: date).map { day in
                    var comps = comps
                    comps.dayOfYear = day
                    return try dateAfterMatchingDayOfYear(startingAt: date, components: comps, direction: direction).map { ($0, comps) } ?? (date, comps)
                }
            }
            lastMatchedComponent = .dayOfYear
        }

        if let months = combinationComponents.months {
            dates = try dates.flatMap { date, comps in
                try _normalizeMonths(months, for: date).map { month in
                    var comps = comps
                    comps.month = month.index
                    comps.isLeapMonth = month.isLeap
                    return try dateAfterMatchingMonth(startingAt: date, components: comps, direction: direction, strictMatching: isStrictMatching).map { ($0, comps) } ?? (date, comps)
                }
            }
            lastMatchedComponent = .month
        }

        if let weekdays = combinationComponents.weekdays {
            dates = try dates.flatMap { date, comps in
                let parentComponent: Calendar.Component = .month
                let weekdayComponents = Calendar.RecurrenceRule._weekdayComponents(calendar: self, for: weekdays, in: parentComponent, anchor: date, anchorComponents: comps)
                let dates = try weekdayComponents!.map { comps in 
                    var date = date
                    if let result = try dateAfterMatchingWeekOfYear(startingAt: date, components: comps, direction: direction) {
                        date = result
                    }
                    if let result = try dateAfterMatchingWeekOfMonth(startingAt: date, components: comps, direction: direction) {
                        date = result
                    }
                    if let result = try dateAfterMatchingWeekdayOrdinal(startingAt: date, components: comps, direction: direction) {
                        date = result
                    }
                    if let result = try dateAfterMatchingWeekday(startingAt: date, components: comps, direction: direction) {
                        date = result
                    }
                    return (date, comps)
                }
                return dates
            }
        }

        if let daysOfMonth = combinationComponents.daysOfMonth {
            dates = try dates.flatMap { date, comps in
                try _normalizeDaysOfMonth(daysOfMonth, for: date).map { day in
                    var comps = comps
                    comps.day = day
                    print("Matching day with components: \(comps)")
                    return try dateAfterMatchingDay(startingAt: date, originalStartDate: startDate, components: comps, direction: direction).map { ($0, comps) } ?? (date, comps)
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
                    return try dateAfterMatchingHour(startingAt: searchStart, originalStartDate: startDate, components: comps, direction: direction, findLastMatch: repeatedTimePolicy == .last, isStrictMatching: isStrictMatching, matchingPolicy: matchingPolicy).map { ($0, comps) } ?? (date, comps)
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
                    return try dateAfterMatchingMinute(startingAt: searchStart, components: comps, direction: direction).map { ($0, comps) } ?? (date, comps)
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
                    return try dateAfterMatchingSecond(startingAt: searchStart, originalStartDate: startDate, components: comps, direction: direction).map { ($0, comps) } ?? (date, comps)
                }
            }
        }

        return dates
    }
    // Returns nil if there was no result. It's up to the caller to decide what to do about that (try again, or cancel).
    fileprivate func _enumerateDatesStep(startingAfter start: Date,
                                         matching combinationComponents: _DateComponentsCombinations,
                                         matchingPolicy: MatchingPolicy,
                                         repeatedTimePolicy: RepeatedTimePolicy,
                                         direction: SearchDirection,
                                         inSearchingDate searchingDate: Date,
                                         previouslyReturnedMatchDate: Date?) throws -> [(SearchStepResult, DateComponents)] {

        guard let unadjustedMatchDates = try _matchingDates(after: searchingDate, matching: combinationComponents, direction: direction, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy) else {
            return []
        }
        
        return try unadjustedMatchDates.map { date, components in
            (try _adjustedDate(date, startingAfter: searchingDate, allowStartDate: true, matching: components, adjustedMatchingComponents: components , matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy, direction: direction, inSearchingDate: searchingDate, previouslyReturnedMatchDate: previouslyReturnedMatchDate), components)
        }
    }
    internal func _enumerateDates(startingAfter start: Date,
                                  matching matchingComponents: _DateComponentsCombinations,
                                  in range: Range<Date>,
                                  matchingPolicy: MatchingPolicy,
                                  repeatedTimePolicy: RepeatedTimePolicy) -> [Date] {
        // TODO: A lazy sequence might be more optimized
      
        guard start.isValidForEnumeration else { return [] }


        var foundDates: [Date] = []
        
        var searchingDate = start
        var previouslyReturnedMatchDate: Date? = nil

        var results: [(Calendar.SearchStepResult, DateComponents)]
        do {
            results = try _enumerateDatesStep(startingAfter: start, matching: matchingComponents, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy, direction: .forward, inSearchingDate: searchingDate, previouslyReturnedMatchDate: previouslyReturnedMatchDate)
        } catch (let e as CalendarEnumerationError) {
            //_handleCalendarError(e, date: start, calendar: self, comps: matchingComponents, direction: direction, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy)
            return []
        } catch {
            fatalError("Unexpected Calendar enumeration error type")
        }
            
        for (result, components) in results {
            searchingDate = result.newSearchDate
            
            if let (matchDate, exactMatch) = result.result {
                var stop = false
                previouslyReturnedMatchDate = matchDate
                if range.contains(matchDate) {
                    foundDates.append(matchDate)
                }
            }
            
            
        }
        return foundDates
    }
}
