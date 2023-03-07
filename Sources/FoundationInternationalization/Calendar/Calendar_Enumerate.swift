//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

extension ComparisonResult {
    init<T: Comparable>(_ t1: T, _ t2: T) {
        if t1 < t2 {
            self = .orderedAscending
        } else if t1 > t2 {
            self = .orderedDescending
        } else {
            self = .orderedSame
        }
    }
}

extension Range where Bound: Comparable {
    func extended(to other: Range<Bound>) -> Range<Bound> {
        Swift.min(self.lowerBound, other.lowerBound)..<Swift.max(self.upperBound, other.upperBound)
    }
}

extension DateInterval {
    /// In contrast to interval.contains(...), this creates a half-open range that does not contain start+duration.
    internal var range: Range<Date> {
        return start..<end
    }
}

extension Calendar {
    func validRange(for component: Component) -> ClosedRange<Int> {
        if component == .weekdayOrdinal {
            return 1...7
        } else if (component == .year || component == .yearForWeekOfYear) && (identifier == .hebrew || identifier == .indian || identifier == .persian) {
            // Check for Hebrew, Indian, and Persian calendar special cases
            // Min year value of 1 allowed
            let max = maximumRange(of: component) ?? 0..<Int.max
            let min = minimumRange(of: component) ?? 0..<Int.max
            return ClosedRange(min.extended(to: max)).clamped(to: 1...Int.max-1)
        } else if component == .yearForWeekOfYear {
            // Use year instead
            let max = maximumRange(of: .year) ?? 0..<Int.max
            let min = minimumRange(of: .year) ?? 0..<Int.max
            return ClosedRange(min.extended(to: max))
        } else {
            let max = maximumRange(of: component) ?? 0..<Int.max
            let min = minimumRange(of: component) ?? 0..<Int.max
            return ClosedRange(min.extended(to: max))
        }
    }

    func value(_ value: Int, isValidFor component: Component) -> Bool {
        let range = validRange(for: component)
        return range.contains(value)
    }
}

extension DateComponents {
    fileprivate func _validate(for calendar: Calendar) -> Bool {
        var dcValuesAreValid = true
        var hasAtLeastOneFieldSet = false

        if let v = self.era {
            hasAtLeastOneFieldSet = true
            if !calendar.value(v, isValidFor: .era) { dcValuesAreValid = false }
        }

        if let v = self.year {
            hasAtLeastOneFieldSet = true
            if !calendar.value(v, isValidFor: .year) { dcValuesAreValid = false }
        }

        if let v = self.quarter {
            hasAtLeastOneFieldSet = true
            if !calendar.value(v, isValidFor: .quarter) { dcValuesAreValid = false }
        }

        if let v = self.month {
            hasAtLeastOneFieldSet = true
            if !calendar.value(v, isValidFor: .month) { dcValuesAreValid = false }
        }

        if let v = self.day {
            hasAtLeastOneFieldSet = true
            if !calendar.value(v, isValidFor: .day) { dcValuesAreValid = false }
        }

        if let v = self.hour {
            hasAtLeastOneFieldSet = true
            if !calendar.value(v, isValidFor: .hour) { dcValuesAreValid = false }
        }

        if let v = self.minute {
            hasAtLeastOneFieldSet = true
            if !calendar.value(v, isValidFor: .minute) { dcValuesAreValid = false }
        }

        if let v = self.second {
            hasAtLeastOneFieldSet = true
            if !calendar.value(v, isValidFor: .second) { dcValuesAreValid = false }
        }

        if let v = self.weekday {
            hasAtLeastOneFieldSet = true
            if !calendar.value(v, isValidFor: .weekday) { dcValuesAreValid = false }
        }

        if let v = self.weekdayOrdinal {
            hasAtLeastOneFieldSet = true
            if !calendar.value(v, isValidFor: .weekdayOrdinal) { dcValuesAreValid = false }
        }

        if let v = self.weekOfMonth {
            hasAtLeastOneFieldSet = true
            if !calendar.value(v, isValidFor: .weekOfMonth) { dcValuesAreValid = false }
        }

        if let v = self.weekOfYear {
            hasAtLeastOneFieldSet = true
            if !calendar.value(v, isValidFor: .weekOfYear) { dcValuesAreValid = false }
        }

        if let v = self.yearForWeekOfYear {
            hasAtLeastOneFieldSet = true
            if !calendar.value(v, isValidFor: .yearForWeekOfYear) { dcValuesAreValid = false }
        }

        if let v = self.nanosecond {
            hasAtLeastOneFieldSet = true
            if !calendar.value(v, isValidFor: .nanosecond) { dcValuesAreValid = false }
        }

        if !hasAtLeastOneFieldSet && (isLeapMonth ?? false) {
            dcValuesAreValid = false
        }

        return dcValuesAreValid
    }

    var highestSetUnit: Calendar.Component? {
        // A note on performance: this approach is much faster than using key paths, which require a lot more allocations.
        if self.era != nil { return .era }
        if self.year != nil { return .year }
        if self.quarter != nil { return .quarter }
        if self.month != nil { return .month }
        if self.day != nil { return .day }
        if self.hour != nil { return .hour }
        if self.minute != nil { return .minute }
        if self.second != nil { return .second }

        // It may seem a bit odd to check in this order, but it's been a longstanding behavior
        if self.weekday != nil { return .weekday }
        if self.weekdayOrdinal != nil { return .weekdayOrdinal }
        if self.weekOfMonth != nil { return .weekOfMonth }
        if self.weekOfYear != nil { return .weekOfYear }
        if self.yearForWeekOfYear != nil { return .yearForWeekOfYear }
        if self.nanosecond != nil { return .nanosecond }
        return nil
    }

    var lowestSetUnit: Calendar.Component? {
        // A note on performance: this approach is much faster than using key paths, which require a lot more allocations.
        if self.nanosecond != nil { return .nanosecond }

        // It may seem a bit odd to check in this order, but it's been a longstanding behavior
        if self.yearForWeekOfYear != nil { return .yearForWeekOfYear }
        if self.weekOfYear != nil { return .weekOfYear }
        if self.weekOfMonth != nil { return .weekOfMonth }
        if self.weekdayOrdinal != nil { return .weekdayOrdinal }
        if self.weekday != nil { return .weekday }
        if self.second != nil { return .second }
        if self.minute != nil { return .minute }
        if self.hour != nil { return .hour }
        if self.day != nil { return .day }
        if self.month != nil { return .month }
        if self.quarter != nil { return .quarter }
        if self.year != nil { return .year }
        if self.era != nil { return .era }
        return nil
    }

    var setUnits: Calendar.ComponentSet {
        var units = Calendar.ComponentSet()
        if self.era != nil { units.insert(.era) }
        if self.year != nil { units.insert(.year) }
        if self.quarter != nil { units.insert(.quarter) }
        if self.month != nil { units.insert(.month) }
        if self.day != nil { units.insert(.day) }
        if self.hour != nil { units.insert(.hour) }
        if self.minute != nil { units.insert(.minute) }
        if self.second != nil { units.insert(.second) }
        if self.weekday != nil { units.insert(.weekday) }
        if self.weekdayOrdinal != nil { units.insert(.weekdayOrdinal) }
        if self.weekOfMonth != nil { units.insert(.weekOfMonth) }
        if self.weekOfYear != nil { units.insert(.weekOfYear) }
        if self.yearForWeekOfYear != nil { units.insert(.yearForWeekOfYear) }
        if self.nanosecond != nil { units.insert(.nanosecond) }
        return units
    }

    var setUnitCount: Int {
        return setUnits.count
    }

    /// Mismatched units compared to another `DateComponents`, in highest-to-lowest order. Includes `isLeapMonth`, which is the last element if present. An empty array indicates no mismatched units.
    func mismatchedUnits(comparedTo other: DateComponents) -> Calendar.ComponentSet {
        var mismatched = Calendar.ComponentSet()

        if self.era != other.era { mismatched.insert(.era) }
        if self.year != other.year { mismatched.insert(.year) }
        if self.quarter != other.quarter { mismatched.insert(.quarter) }
        if self.month != other.month { mismatched.insert(.month) }
        if self.day != other.day { mismatched.insert(.day) }
        if self.hour != other.hour { mismatched.insert(.hour) }
        if self.minute != other.minute { mismatched.insert(.minute) }
        if self.second != other.second { mismatched.insert(.second) }
        if self.weekday != other.weekday { mismatched.insert(.weekday) }
        if self.weekdayOrdinal != other.weekdayOrdinal { mismatched.insert(.weekdayOrdinal) }
        if self.weekOfMonth != other.weekOfMonth { mismatched.insert(.weekOfMonth) }
        if self.weekOfYear != other.weekOfYear { mismatched.insert(.weekOfYear) }
        if self.yearForWeekOfYear != other.yearForWeekOfYear { mismatched.insert(.yearForWeekOfYear) }
        if self.nanosecond != other.nanosecond { mismatched.insert(.nanosecond) }
        if self.isLeapMonth != other.isLeapMonth { mismatched.insert(.isLeapMonth) }

        return mismatched
    }
}

/* public */
internal struct DateSequence : Sequence {
    typealias Element = Date

    let calendar: Calendar
    let start: Date
    let matchingComponents: DateComponents
    let matchingPolicy: Calendar.MatchingPolicy
    let repeatedTimePolicy: Calendar.RepeatedTimePolicy
    let direction: Calendar.SearchDirection

    struct Iterator: IteratorProtocol {
        var iterations: Int
        var previouslyReturnedMatchDate: Date?
        var searchingDate: Date

        let start: Date
        let calendar: Calendar
        let matchingComponents: DateComponents
        let matchingPolicy: Calendar.MatchingPolicy
        let repeatedTimePolicy: Calendar.RepeatedTimePolicy
        let direction: Calendar.SearchDirection
        let searchLimit: Int = 100

        // Calculated at init, checked on `next`
        let validated: Bool

        init(_ calendar: Calendar, start: Date, matching matchingComponents: DateComponents, matchingPolicy: Calendar.MatchingPolicy, repeatedTimePolicy: Calendar.RepeatedTimePolicy, direction: Calendar.SearchDirection) {
            self.calendar = calendar
            self.start = start
            self.matchingComponents = matchingComponents
            self.matchingPolicy = matchingPolicy
            self.repeatedTimePolicy = repeatedTimePolicy
            self.direction = direction

            self.searchingDate = start
            iterations = -1

            // If this fails we'll short circuit the next `next`
            validated = matchingComponents._validate(for: calendar)
        }

        mutating func next() -> Element? {
            guard validated else { return nil }

            repeat {
                iterations += 1
                let result = calendar._enumerateDatesStep(startingAfter: start, matching: matchingComponents, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy, direction: direction, inSearchingDate: searchingDate, previouslyReturnedMatchDate: previouslyReturnedMatchDate)

                searchingDate = result.newSearchDate

                // Return a value if we have a result. Else, continue on searching unless we've hit our search limit.
                // This version of the implementation ignores the 'exactMatch' result. Nobody cares unless they specify `strict`, and if they do that all results are exact anyway.
                if let (matchDate, _) = result.result {
                    previouslyReturnedMatchDate = matchDate
                    return matchDate
                }

                if (iterations < searchLimit) {
                    // Try again on nil result or not-exact match
                    searchingDate = result.newSearchDate
                    continue
                } else {
                    // Give up
                    return nil
                }
            } while true
        }
    }

    func makeIterator() -> Iterator {
        return Iterator(calendar, start: start, matching: matchingComponents, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy, direction: direction)
    }
}

extension Calendar {
    struct SearchStepResult {
        /// `nil` if there was no result.
        var result: (Date, Bool)?

        /// The input to the next round of iteration on the original search parameters.
        var newSearchDate: Date
    }

    internal func _enumerateDates(startingAfter start: Date,
                                  matching matchingComponents: DateComponents,
                                  matchingPolicy: MatchingPolicy,
                                  repeatedTimePolicy: RepeatedTimePolicy,
                                  direction: SearchDirection,
                                  using block: (_ result: Date?, _ exactMatch: Bool, _ stop: inout Bool) -> Void) {
        if !matchingComponents._validate(for: self) {
            return
        }

        let STOP_EXHAUSTIVE_SEARCH_AFTER_MAX_ITERATIONS = 100

        var searchingDate = start
        var previouslyReturnedMatchDate: Date? = nil
        var iterations = -1

        repeat {
            iterations += 1
            let result = _enumerateDatesStep(startingAfter: start, matching: matchingComponents, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy, direction: direction, inSearchingDate: searchingDate, previouslyReturnedMatchDate: previouslyReturnedMatchDate)

            searchingDate = result.newSearchDate

            if let (matchDate, exactMatch) = result.result {
                var stop = false
                previouslyReturnedMatchDate = matchDate
                block(matchDate, exactMatch, &stop)
                if stop {
                    return
                }
            } else if (iterations < STOP_EXHAUSTIVE_SEARCH_AFTER_MAX_ITERATIONS) {
                // Try again on nil result
                searchingDate = result.newSearchDate
                continue
            } else {
                // Give up
                return
            }
        } while true
    }

    // Returns nil if there was no result. It's up to the caller to decide what to do about that (try again, or cancel).
    fileprivate func _enumerateDatesStep(startingAfter start: Date,
                                         matching matchingComponents: DateComponents,
                                         matchingPolicy: MatchingPolicy,
                                         repeatedTimePolicy: RepeatedTimePolicy,
                                         direction: SearchDirection,
                                         inSearchingDate: Date,
                                         previouslyReturnedMatchDate: Date?) -> SearchStepResult {
        var exactMatch = true
        var isLeapDay = false
        var searchingDate = inSearchingDate

        // NOTE: Several comments reference "isForwardDST" as a way to relate areas in forward DST handling.
        var isForwardDST = false

        // Step A: Call helper method that does the searching

        /* Note: The reasoning behind this is a bit difficult to immediately grok because it's not obvious but what it does is ensure that the algorithm enumerates through each year or month if they are not explicitly set in the DateComponents passed in by the caller.  This only applies to cases where the highest set unit is month or day (at least for now).
         For ex, let's say comps is set the following way:
         { Day: 31 }
         We want to enumerate through all of the months that have a 31st day.  If strict is set, the algorithm automagically skips over the months that don't have a 31st day and we pass the desired results to the caller.  However, if any of the approximation options are set, we can't skip the months that don't have a 31st day - we need to provide the appropriate approximate date for them.  Calling this method allows us to see that day is the highest unit set in comps, and sets the month value in compsToMatch (previously unset in matchingComponents) to whatever the month is of the date we're using to search.

         Ex: searchingDate is '2016-06-10 07:00:00 +0000' so { Day: 31 } becomes { Month: 6, Day: 31 } in compsToMatch

         This way, the algorithm from here on out sees that month is now the highest set unit and we ensure that we search for the day we want in each month and provide an approximation when we can't find it, thus getting the results the caller expects.

         Ex: { Month: 6, Day: 31 } does not exist so if nextTime is set, we pass '2016-07-01 07:00:00 +0000' to the block.
         */
        let compsToMatch = _adjustedComponents(matchingComponents, date: searchingDate, direction: direction)

        guard let unadjustedMatchDate = _matchingDate(after: searchingDate, matching: compsToMatch, direction: direction, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy) else {
            // TODO: Check if returning the same searchingDate has any purpose
            return SearchStepResult(result: nil, newSearchDate: searchingDate)
        }

        // Step B: Couldn't find matching date with a quick and dirty search in the current era, year, etc.  Now try in the near future/past and make adjustments for leap situations and non-existent dates

        // matchDate may be nil, which indicates a need to keep iterating
        // Step C: Validate what we found and then run block. Then prepare the search date for the next round of the loop
        guard let matchDate = _adjustedDateForMismatches(start: start, searchingDate: searchingDate, matchDate: unadjustedMatchDate, matchingComponents: matchingComponents, compsToMatch: compsToMatch, direction: direction, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy, isForwardDST: &isForwardDST, isExactMatch: &exactMatch, isLeapDay: &isLeapDay) else {
            // Try again with a bumped up date
            if let newSearchingDate = bumpedDateUpToNextHigherUnitInComponents(searchingDate, matchingComponents, direction, nil) {
                searchingDate = newSearchingDate
            }

            return SearchStepResult(result: nil, newSearchDate: searchingDate)
        }

        // Check the components to see if they match what was desired
        let (mismatchedUnits, dateMatchesComps) = self.date(matchDate, containsMatchingComponents: matchingComponents)
        if dateMatchesComps && !exactMatch {
            exactMatch = true
        }

        // Bump up the next highest unit
        if let newSearchingDate = bumpedDateUpToNextHigherUnitInComponents(searchingDate, matchingComponents, direction, matchDate) {
            searchingDate = newSearchingDate
        }

        // Nanosecond and quarter mismatches are not considered inexact.
        let notAnExactMatch = !dateMatchesComps && !mismatchedUnits.contains(.nanosecond) && !mismatchedUnits.contains(.quarter)
        if notAnExactMatch {
            exactMatch = false
        }

        let order : ComparisonResult
        if let previouslyReturnedMatchDate {
            order = ComparisonResult(previouslyReturnedMatchDate, matchDate)
        } else {
            order = ComparisonResult(start, matchDate)
        }

        if ((direction == .backward && order == .orderedAscending) || (direction == .forward && order == .orderedDescending)) && !mismatchedUnits.contains(.nanosecond) {
            // We've gone ahead when we should have gone backwards or we went in the past when we were supposed to move forwards.
            // Normally, it's sufficient to set matchDate to nil and move on with the existing searching date. However, the searching date has been bumped forward by the next highest date component, which isn't always correct.
            // Specifically, if we're in a type of transition when the highest date component can repeat between now and the next highest date component, then we need to move forward by less.
            //
            // This can happen during a "fall back" DST transition in which an hour is repeated:
            //
            //   ┌─────1:00 PDT─────┐ ┌─────1:00 PST─────┐
            //   │                  │ │                  │
            //   └───────────▲───▲──┘ └───────────▲──────┘
            //               │   │                │
            //               |   |                valid
            //               │   last match/start
            //               │
            //               matchDate
            //
            // Instead of jumping ahead by a whole day, we can jump ahead by an hour to the next appropriate match. `valid` here would be the result found by searching with matchLast.
            // In this case, before giving up on the current match date, we need to adjust the next search date with this information.
            //
            // Currently, the case we care most about is adjusting for DST, but we might need to expand this to handle repeated months in some calendars.

            if compsToMatch.highestSetUnit == .hour {
                let matchHour = component(.hour, from: matchDate)
                let hourAdjustment = direction == .backward ? -3600.0 : 3600.0
                let potentialNextMatchDate = matchDate + hourAdjustment
                let potentialMatchHour = component(.hour, from: potentialNextMatchDate)

                if matchHour == potentialMatchHour {
                    // We're in a DST transition where the hour repeats. Use this date as the next search date.
                    searchingDate = potentialNextMatchDate
                }
            }

            // In any case, return nil.
            return SearchStepResult(result: nil, newSearchDate: searchingDate)
        }

        // At this point, the date we matched is allowable unless:
        // 1) It's not an exact match AND
        // 2) We require an exact match (strict) OR
        // 3) It's not an exact match but not because we found a DST hour or day that doesn't exist in the month (i.e. it's truly the wrong result)
        let allowInexactMatchingDueToTimeSkips = isForwardDST || isLeapDay
        if !exactMatch && (matchingPolicy == .strict || !allowInexactMatchingDueToTimeSkips) {
            return SearchStepResult(result: nil, newSearchDate: searchingDate)
        }

        // If we get a result that is exactly the same as the start date, skip.
        if order == .orderedSame {
            return SearchStepResult(result: nil, newSearchDate: searchingDate)
        }

        return SearchStepResult(result: (matchDate, exactMatch), newSearchDate: searchingDate)
    }

    // MARK: -

    func _adjustedComponents(_ comps: DateComponents, date: Date, direction: SearchDirection) -> DateComponents {
        // This method ensures that the algorithm enumerates through each year or month if they are not explicitly set in the DateComponents passed into enumerateDates.  This only applies to cases where the highest set unit is month or day (at least for now).  For full in context explanation, see where it gets called in enumerateDates.

        let highestSetUnit = comps.highestSetUnit
        switch highestSetUnit {
        case .some(.month):
            var adjusted = comps
            adjusted.year = component(.year, from: date)
            // TODO: can year ever be nil here?
            if let adjustedDate = self.date(from: adjusted) {
                if direction == .forward && date > adjustedDate {
                    adjusted.year = adjusted.year! + 1
                } else if direction == .backward && date < adjustedDate {
                    adjusted.year = adjusted.year! - 1
                }
            }
            return adjusted
        case .some(.day):
            var adjusted = comps
            if direction == .backward {
                let dateDay = component(.day, from: date)
                // We need to make sure we don't surpass the day we want
                if comps.day ?? Int.max >= dateDay {
                    let tempDate = self.date(byAdding: .month, value: -1, to: date)! // TODO: Check force unwrap here
                    adjusted.month = component(.month, from: tempDate)
                } else {
                    // adjusted is the date components we're trying to match against; dateDay is the current day of the current search date.
                    // See the comment in enumerateDates for the justification for adding the month to the components here.
                    //
                    // However, we can't unconditionally add the current month to these components. If the current search date is on month M and day D, and the components we're trying to match have day D' set, the resultant date components to match against are {day=D', month=M}.
                    // This is only correct sometimes:
                    //
                    //  * If D' > D (e.g. we're on Nov 05, and trying to find the next 15th of the month), then it's okay to try to match Nov 15.
                    //  * However, if D' <= D (e.g. we're on Nov 05, and are trying to find the next 2nd of the month), then it's not okay to try to match Nov 02.
                    //
                    // We can only adjust the month if it won't cause us to search "backwards" in time (causing us to elsewhere end up skipping the first [correct] match we find).
                    // These same changes apply to the backwards case above.
                    let dateDay = component(.month, from: date)
                    adjusted.month = dateDay
                }
            } else {
                let dateDay = component(.day, from: date)
                if comps.day ?? Int.max > dateDay {
                    adjusted.month = component(.month, from: date)
                }
            }
            return adjusted
        default:
            // Nothing to adjust
            return comps
        }
    }

    // This function checks the input (assuming we've detected a mismatch hour), for a DST transition. If we find one, then it returns a new date. Otherwise it returns nil.
    func _adjustedDateForMismatchedHour(matchDate: Date, // the currently proposed match
                                        compsToMatch:DateComponents,
                                        matchingPolicy: MatchingPolicy,
                                        repeatedTimePolicy: RepeatedTimePolicy,
                                        isExactMatch: inout Bool) -> Date? {
        // It's possible this is a DST time. Let's check.
        guard let found = dateInterval(of: .hour, for: matchDate) else {
            // Not DST
            return nil
        }

        // matchDate may not match because of a forward DST transition (e.g. spring forward, hour is lost).
        // matchDate may be before or after this lost hour, so look in both directions.
        let currentHour = component(.hour, from: found.start)

        var isForwardDST = false
        var beforeTransition = true

        let next = found.start + found.duration
        let nextHour = component(.hour, from: next)
        if (nextHour - currentHour) > 1 || (currentHour == 23 && nextHour > 0) {
            // We're just before a forward DST transition, e.g., for America/Sao_Paulo:
            //
            //            2018-11-03                      2018-11-04
            //    ┌─────11:00 PM (GMT-3)─────┐ │ ┌ ─ ─ 12:00 AM (GMT-3)─ ─ ─┐ ┌─────1:00 AM (GMT-2) ─────┐
            //    │                          │ │ |                          │ │                          │
            //    └──────▲───────────────────┘ │ └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┘ └──────────────────────────┘
            //           └── Here                        Nonexistent
            //
            isForwardDST = true
        } else {
            // We might be just after such a transition.
            let previous = found.start - 1
            let previousHour = component(.hour, from: previous)

            if ((currentHour - previousHour) > 1 || (previousHour == 23 && currentHour > 0)) {
                // We're just after a forward DST transition, e.g., for America/Sao_Paulo:
                //
                //            2018-11-03                      2018-11-04
                //    ┌─────11:00 PM (GMT-3)─────┐ │ ┌ ─ ─ 12:00 AM (GMT-3)─ ─ ─┐ ┌─────1:00 AM (GMT-2) ─────┐
                //    │                          │ │ |                          │ │                          │
                //    └──────────────────────────┘ │ └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┘ └──▲───────────────────────┘
                //                                            Nonexistent            └── Here
                //
                isForwardDST = true
                beforeTransition = false
            }
        }

        // we can only adjust when matches need not be strict
        if !(isForwardDST && matchingPolicy != .strict) {
            return nil
        }

        // We can adjust the time as necessary to make this match close enough.
        // Since we aren't trying to strictly match and are now going to make a best guess approximation, we set exactMatch to false.
        isExactMatch = false

        if beforeTransition {
            if matchingPolicy == .nextTimePreservingSmallerComponents {
                return date(byAdding: .hour, value: 1, to: matchDate)
            } else if matchingPolicy == .nextTime {
                return next
            } else {
                // No need to check `previousTimePreservingSmallerUnits` or `strict`:
                // * If we're matching the previous time, `matchDate` is already correct because we're pre-transition
                // * If we're matching strictly, we shouldn't be here (should be guarded by the if-statement condition): we can't adjust a strict match
                return matchDate
            }
        } else {
            if matchingPolicy == .nextTime {
                // `startOfHour` is the start of the hour containing `matchDate` (i.e. take `matchDate` but wipe the minute and second)
                return found.start
            } else if matchingPolicy == .previousTimePreservingSmallerComponents {
                // We've arrived here after a mismatch due to a forward DST transition, and specifically, one which produced a candidate matchDate which was _after_ the transition.
                // At the time of writing this (2018-07-11), the only way to hit this case is under the following circumstances:
                //
                //   * DST transition in a time zone which transitions at `hour = 0` (i.e. 11:59:59 -> 01:00:00)
                //   * Components request `hour = 0`
                //   * Components contain a date component higher than hour which advanced us to the start of the day from a prior day
                //
                // If the DST transition is not at midnight, the components request any other hour, or there is no higher date component, we will have fallen into the usual hour-rolling loop.
                // That loop right now takes care to stop looping _before_ the transition.
                //
                // This means that right now, if we attempt to match the previous time while preserving smaller components (i.e. rewinding by an hour), we will no longer match the higher date component which had been requested.
                // For instance, if searching for `weekday = 1` (Sunday) got us here, rewinding by an hour brings us back to Saturday. Similarly, if asking for `month = x` got us here, rewinding by an hour would bring us to `month = x - 1`.
                // These mismatches are not proper candidates and should not be accepted.
                //
                // However, if the conditions of the hour-rolling loop ever change, I am including the code which would be correct to use here: attempt to roll back by an hour, and check whether we've introduced a new mismatch.

                // We don't actually have a match. Claim it's not DST too, to avoid accepting matchDate as-is anyway further on (which is what isForwardDST = true allows for).
                return nil
            } else {
                // No need to check `nextTimePreservingSmallerUnits` or `strict`:
                // * If we're matching the next time, `matchDate` is already correct because we're post-transition
                // * If we're matching strictly, we shouldn't be here (should be guarded by the if-statement condition): we can't adjust a strict match
                return matchDate
            }
        }
    }

    // For calendars other than Chinese
    func _adjustedDateForMismatchedLeapMonthOrDay(start: Date,
                                                  searchingDate: Date,
                                                  matchDate: Date,
                                                  matchingComponents: DateComponents,
                                                  compsToMatch: DateComponents,
                                                  nextHighestUnit: Calendar.Component,
                                                  direction: SearchDirection,
                                                  matchingPolicy: MatchingPolicy,
                                                  repeatedTimePolicy: RepeatedTimePolicy,
                                                  isExactMatch: inout Bool,
                                                  isLeapDay: inout Bool) -> Date? {
        let searchDateComps = _dateComponents(.init(.year, .month, .day), from: searchingDate)

        let searchDateDay = searchDateComps.day
        let searchDateMonth = searchDateComps.month
        let searchDateYear = searchDateComps.year
        let desiredMonth = compsToMatch.month
        let desiredDay = compsToMatch.day

        // if comps aren't equal, it means we jumped to a day that doesn't exist in that year (non-leap year) i.e. we've detected a leap year situation
        let detectedLeapYearSituation = ((desiredDay != nil) && (searchDateDay != desiredDay)) || ((desiredMonth != nil) && (searchDateMonth != desiredMonth))
        if !detectedLeapYearSituation {
            // Nothing to do here
            return nil
        }

        // Previous code appears to have assumed these were non-nil after this point
        guard let searchDateYear, let searchDateMonth, let desiredDay, let desiredMonth else {
            return nil
        }

        var foundGregLeapMatchesComps = false

        var result: Date? = matchDate

        // TODO: We had a bug fix here in another place in CFCalendar where we need to look at more identifiers than just gregorian
        if identifier == .gregorian {
            // We've identified a leap year in the Gregorian calendar OR we've identified a day that doesn't exist in a different month
            // We check the original matchingComponents to check the caller's *intent*. If they're looking for February, then they are indeed looking for a leap year. If they didn't ask for February explicitly and we added it to compsToMatch ourselves, then don't force us to the next leap year.
            if desiredMonth == 2 && matchingComponents.month == 2 {
                // Check for gregorian leap year
                var amountToAdd: Int
                if direction == .backward {
                    amountToAdd = (searchDateYear % 4) * -1

                    // It's possible that we're in a leap year but before 2/29.  Since we're going backwards, we need to go to the previous leap year.
                    if amountToAdd == 0 && searchDateMonth >= desiredMonth {
                        amountToAdd = amountToAdd - 4
                    }
                } else {
                    amountToAdd = 4 - (searchDateYear % 4)
                }

                let searchDateInLeapYear = date(byAdding: .year, value: amountToAdd, to: searchingDate)
                if let searchDateInLeapYear, let leapYearDateInterval = dateInterval(of: .year, for: searchDateInLeapYear) {
                    guard let inner = _matchingDate(after: leapYearDateInterval.start, matching: compsToMatch, direction: .forward, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy) else {
                        return nil
                    }

                    (_, foundGregLeapMatchesComps) = date(inner, containsMatchingComponents: compsToMatch)
                    result = inner
                }
            }
        }

        if !foundGregLeapMatchesComps {
            if matchingPolicy == .strict {
                if identifier == .gregorian {
                    // We couldn't find what we needed but we found sumthin. Step C will decide whether or not to nil the date out.
                    isExactMatch = false
                } else {
                    // For other calendars (besides Chinese which is already being handled), go to the top of the next period for the next highest unit of the one that bailed.
                    result = _matchingDate(after: searchingDate, matching: matchingComponents, inNextHighestUnit: nextHighestUnit, direction: direction, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy)
                }
            } else {
                // Figure out best approximation to give.  The "correct" approximations for these cases depend on the calendar.
                // Note that this also works for the Hebrew calendar - since the preceding month is not numbered the same as the leap month (like in the Chinese calendar) we can treat the non-existent day in the same way that we handle Feb 29 in the Gregorian calendar.
                var compsCopy = compsToMatch
                var tempComps = DateComponents()
                tempComps.year = searchDateYear
                tempComps.month = desiredMonth
                tempComps.day = 1

                if matchingPolicy == .nextTime {
                    if let compsToMatchYear = compsToMatch.year {
                        // If we explicitly set the year to match we should use that year instead and not searchDateYear.
                        compsCopy.year = compsToMatchYear > searchDateYear ? compsToMatchYear : searchDateYear
                    } else {
                        compsCopy.year = searchDateYear
                    }

                    guard let tempDate = date(from: tempComps) else {
                        return nil
                    }

                    guard let followingMonthDate = date(byAdding: .month, value: 1, to: tempDate) else {
                        return nil
                    }

                    compsCopy.month = component(.month, from: followingMonthDate)
                    compsCopy.day = 1

                    guard let inner = _matchingDate(after: start, matching: compsCopy, direction: direction, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy) else {
                        return nil
                    }
                    let (_, dateMatchesComps) = date(inner, containsMatchingComponents: compsCopy)
                    if dateMatchesComps {
                        if let foundRange = dateInterval(of: .day, for: inner) {
                            result = foundRange.start
                        } else {
                            result = inner
                        }
                    } else {
                        result = nil
                    }
                } else {
                    preserveSmallerUnits(start, compsToMatch: compsToMatch, compsToModify: &compsCopy)
                    if matchingPolicy == .nextTimePreservingSmallerComponents {
                        if let compsToMatchYear = compsToMatch.year {
                            // If we explicitly set the year to match we should use that year instead and not searchDateYear.
                            compsCopy.year = compsToMatchYear > searchDateYear ? compsToMatchYear : searchDateYear
                        } else {
                            compsCopy.year = searchDateYear
                        }

                        tempComps.year = compsCopy.year
                        guard let tempDate = date(from: tempComps) else {
                            return nil
                        }

                        guard let followingMonthDate = date(byAdding: .month, value: 1, to: tempDate) else {
                            return nil
                        }

                        compsCopy.month = component(.month, from: followingMonthDate)
                        // We want the beginning of the next month.
                        compsCopy.day = 1
                    } else {
                        // match previous preserving smaller units
                        guard let tempDate = date(from: tempComps) else {
                            return nil
                        }

                        guard let range = range(of: .day, in: .month, for: tempDate) else {
                            return nil
                        }

                        let lastDayOfTheMonth = range.count
                        if desiredDay >= lastDayOfTheMonth {
                            compsCopy.day = lastDayOfTheMonth
                        } else {
                            // Go to the prior day before the desired month
                            compsCopy.day = desiredDay - 1
                        }
                    }

                    guard let inner = _matchingDate(after: searchingDate, matching: compsCopy, direction: direction, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy) else {
                        return nil
                    }
                    let (_, dateMatchesComps) = date(inner, containsMatchingComponents: compsCopy)
                    if !dateMatchesComps {
                        // Bail if we couldn't even find an approximate match.
                        result = nil
                    } else {
                        result = inner
                    }
                }

                isExactMatch = false
                isLeapDay = true
            }
        }

        return result
    }

    // This function adjusts a mismatched data in the case where it is the chinese calendar and we have detected a leap month mismatch.
    // It will return nil in the case where we could not find an appropriate adjustment. In that case, the algorithm should keep iterating.
    func _adjustedDateForMismatchedChineseLeapMonth(start: Date,
                                                    searchingDate: Date,
                                                    matchDate: Date,
                                                    matchingComponents: DateComponents,
                                                    compsToMatch: DateComponents,
                                                    direction: SearchDirection,
                                                    matchingPolicy: MatchingPolicy,
                                                    repeatedTimePolicy: RepeatedTimePolicy,
                                                    isExactMatch: inout Bool,
                                                    isLeapDay: inout Bool) -> Date? {
        // We are now going to look for the month that precedes the leap month we're looking for.
        let matchDateComps = _dateComponents(.init(.era, .year, .month, .day), from: matchDate)
        let isMatchLeapMonthSet = matchDateComps.isLeapMonth != nil
        let isMatchLeapMonth = matchDateComps.isLeapMonth ?? false
        let isDesiredLeapMonthSet = matchingComponents.isLeapMonth != nil
        let isDesiredLeapMonth = matchingComponents.isLeapMonth ?? false
        if !(isMatchLeapMonthSet && !isMatchLeapMonth && isDesiredLeapMonthSet && isDesiredLeapMonth) {
            // Not one of the things we adjust for
            return matchDate
        }

        // Not an exact match after this point
        isExactMatch = false
        var result: Date? = matchDate
        var compsCopy = compsToMatch
        compsCopy.isLeapMonth = false

        // See if matchDate is already the preceding non-leap month.
        var (_, dateMatchesComps) = date(matchDate, containsMatchingComponents: compsCopy)
        if !dateMatchesComps {
            // matchDate was not the preceding non-leap month so now we try to find it.
            guard let nonLeapStart = _matchingDate(after: searchingDate, matching: compsCopy, direction: direction, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy) else {
                return nil
            }
            (_, dateMatchesComps) = date(nonLeapStart, containsMatchingComponents: compsCopy)
            if !dateMatchesComps {
                // Bail if we can't even find the preceding month.  Returning nil allows the alg to keep iterating until we either eventually find another match and caller says stop or we hit our max number of iterations and give up.
                result = nil
            } else {
                result = nonLeapStart
            }
        }

        if !dateMatchesComps {
            return result
        }

        if result == nil {
            return nil
        }

        // We have the non-leap month so now we check to see if the month following is a leap month.
        guard let foundRange = dateInterval(of: .month, for: result!) else {
            return result
        }

        compsCopy.isLeapMonth = true
        let beginMonthAfterNonLeap = foundRange.start + foundRange.duration

        // Now we see if we find the date we want in what we hope is the leap month.
        if let possibleLeapDateMatch = _matchingDate(after: beginMonthAfterNonLeap, matching: compsCopy, direction: direction, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy) {
            (_, dateMatchesComps) = date(possibleLeapDateMatch, containsMatchingComponents: compsCopy)

            if dateMatchesComps {
                // Hooray! It was a leap month and we found the date we wanted!
                return possibleLeapDateMatch
            }
        }

        // Either the month wasn't a leap month OR we couldn't find the date we wanted (e.g. the requested date is a bogus nonexistent one).
        if matchingPolicy == .strict {
            // We give up, we couldn't find what we needed.
            return nil
        }

        // We approximate.
        /*
         Two things we need to test for here. Either
         (a) beginMonthAfterNonLeap is a leap month but the date we're looking for doesn't exist (e.g. looking for the 30th day in a 29-day month) OR
         (b) beginMonthAfterNonLeap is not a leap month OR

         The reason we need to test for each separately is because they get handled differently.
         For (a): beginMonthAfterNonLeap IS a leap month BUT we can't find the date we want
         PreviousTime - Last day of this month (beginMonthAfterNonLeap) preserving smaller units
         NextTimePreserving - First day of following month (month after beginMonthAfterNonLeap) preserving smaller units
         NextTime - First day of following month (month after beginMonthAfterNonLeap) at the beginning of the day

         For (b): beginMonthAfterNonLeap is NOT a leap month
         PreviousTime - The day we want in the previous month (nonLeapMonthBegin) preserving smaller units
         NextTimePreserving - First day of this month (beginMonthAfterNonLeap) preserving smaller units
         NextTime - First day of this month (beginMonthAfterNonLeap)
         */
        let isLeapMonth = _dateComponents(.month, from: beginMonthAfterNonLeap).isLeapMonth ?? false
        if isLeapMonth { // (a)
            if matchingPolicy == .nextTime {
                // We want the beginning of the next month
                if let nonLeapFoundRange = dateInterval(of: .month, for: beginMonthAfterNonLeap) {
                    result = nonLeapFoundRange.start + nonLeapFoundRange.duration
                }
            } else {
                var dateToUse: Date?
                preserveSmallerUnits(start, compsToMatch: compsToMatch, compsToModify: &compsCopy)
                if matchingPolicy == .nextTimePreservingSmallerComponents {
                    compsCopy.isLeapMonth = false
                    compsCopy.day = 1
                    if let nonLeapFoundRange = dateInterval(of: .day, for: beginMonthAfterNonLeap) {
                        let nextDay = nonLeapFoundRange.start + nonLeapFoundRange.duration
                        dateToUse = _matchingDate(after: nextDay, matching: compsCopy, direction: .forward, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy)
                    }
                } else {
                    // match previous preserving smaller units
                    if let nonLeapFoundRange = dateInterval(of: .month, for: beginMonthAfterNonLeap) {
                        let lastDayEnd = nonLeapFoundRange.start + nonLeapFoundRange.duration - 1
                        let monthDayComps = _dateComponents(.init(.month, .day), from: lastDayEnd)
                        compsCopy.month = monthDayComps.month
                        compsCopy.day = monthDayComps.day
                        compsCopy.isLeapMonth = true
                        dateToUse = _matchingDate(after: lastDayEnd, matching: compsCopy, direction: .backward, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy)
                    }
                }

                if dateToUse != nil {
                    // We have to give a date since we don't want to return nil. So, whatever we get back, we go with. Hopefully it's what we want.
                    result = dateToUse
                }

            }

        } else { // (b)
            if matchingPolicy == .nextTime {
                // We need first day of this month and we don't care about preserving the smaller units.
                result = beginMonthAfterNonLeap
            } else {
                compsCopy.isLeapMonth = false
                preserveSmallerUnits(start, compsToMatch: compsToMatch, compsToModify: &compsCopy)
                var dateToUse: Date?
                if matchingPolicy == .nextTimePreservingSmallerComponents {
                    // We need first day of this month but we need to preserve the smaller units.
                    compsCopy.month = component(.month, from: beginMonthAfterNonLeap)
                    dateToUse = _matchingDate(after: beginMonthAfterNonLeap, matching: compsCopy, direction: .forward, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy)
                } else {
                    // match previous preserving smaller units
                    // compsCopy is already set to what we're looking for, which is the date we want in the previous non-leap month. This also preserves the smaller units.
                    dateToUse = _matchingDate(after: foundRange.start, matching: compsCopy, direction: .forward, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy)
                }

                if dateToUse != nil {
                    // TODO: Check below comment
                    // We have to give a date since we can't return nil so whatever we get back, we go with. Hopefully it's what we want.
                    // tempMatchDate was already set to matchDate so it shouldn't be nil here anyway.
                    result = dateToUse
                }
            }
        }

        // Even though we have an approximate date here, we still count it as a substitute for the leap date we were hoping to find.
        isLeapDay = true

        return result
    }

    func _adjustedDateForMismatches(start: Date, // the original search date
                                    searchingDate: Date, // the date that is adjusted as we loop
                                    matchDate: Date, // the currently proposed match
                                    matchingComponents: DateComponents, // aka searchingComponents
                                    compsToMatch: DateComponents,
                                    direction: SearchDirection,
                                    matchingPolicy: MatchingPolicy,
                                    repeatedTimePolicy: RepeatedTimePolicy,
                                    isForwardDST: inout Bool,
                                    isExactMatch: inout Bool,
                                    isLeapDay: inout Bool) -> Date? {

        // Set up some default answers for the out args
        isForwardDST = false
        isExactMatch = true
        isLeapDay = false

        // use this to find the units that don't match and then those units become the bailedUnit
        let (mismatchedUnits, dateMatchesComps) = date(matchDate, containsMatchingComponents: compsToMatch)

        // Skip trying to correct nanoseconds or quarters. We don't want differences in these two (partially unsupported) fields to cause mismatched dates. <rdar://problem/30229247> / <rdar://problem/30229506>
        let nanoSecondsMismatch = mismatchedUnits.contains(.nanosecond)
        let quarterMismatch = mismatchedUnits.contains(.quarter)
        if !(!nanoSecondsMismatch && !quarterMismatch) {
            // Everything else is fine. Just return this date.
            return matchDate
        }

        // Check if *only* the hour is mismatched
        if mismatchedUnits.count == 1 && mismatchedUnits.contains(.hour) {
            if let resultAdjustedForDST = _adjustedDateForMismatchedHour(matchDate: matchDate, compsToMatch: compsToMatch, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy, isExactMatch: &isExactMatch) {
                isForwardDST = true
                // Skip the next set of adjustments too
                return resultAdjustedForDST
            }
        }

        if dateMatchesComps {
            // Everything is already fine. Just return the value.
            return matchDate
        }

        guard let bailedUnit = mismatchedUnits.highestSetUnit else {
            // There was no real mismatch, apparently. Return the matchDate
            return matchDate
        }

        let leapMonthMismatch = mismatchedUnits.contains(.isLeapMonth)

        var nextHighestUnit = bailedUnit.nextHigherUnit

        if nextHighestUnit == nil && !leapMonthMismatch {
            // Just return the original date in this case
            return matchDate
        }

        // corrective measures
        if bailedUnit == .era {
            nextHighestUnit = .year
        } else if bailedUnit == .year || bailedUnit == .yearForWeekOfYear {
            nextHighestUnit = bailedUnit
        }

        // We need to check for leap* situations
        let isGregorianCalendar = identifier == .gregorian
        let isChineseCalendar = identifier == .chinese

        if nextHighestUnit == .year || leapMonthMismatch {
            let desiredMonth = compsToMatch.month
            let desiredDay = compsToMatch.day

            if !((desiredMonth != nil) && (desiredDay != nil)) {
                // Just return the original date in this case
                return matchDate
            }

            if isChineseCalendar {
                if leapMonthMismatch {
                    return _adjustedDateForMismatchedChineseLeapMonth(start: start, searchingDate: searchingDate, matchDate: matchDate, matchingComponents: matchingComponents, compsToMatch: compsToMatch, direction: direction, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy, isExactMatch: &isExactMatch, isLeapDay: &isLeapDay)
                } else {
                    // Just return the original date in this case
                    return matchDate
                }
            }

            // Here is where we handle the other leap* situations (e.g. leap years in Gregorian calendar, leap months in Hebrew calendar)
            let monthMismatched = mismatchedUnits.contains(.month)
            let dayMismatched = mismatchedUnits.contains(.day)
            if monthMismatched || dayMismatched {
                // Force unwrap nextHighestUnit because it must be set here (or we should have gone down the leapMonthMismatch path)
                return _adjustedDateForMismatchedLeapMonthOrDay(start: start, searchingDate: searchingDate, matchDate: matchDate, matchingComponents: matchingComponents, compsToMatch: compsToMatch, nextHighestUnit: nextHighestUnit!, direction: direction, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy, isExactMatch: &isExactMatch, isLeapDay: &isLeapDay)
            }

            // Last opportunity here is just to return the original match date
            return matchDate
        } else if nextHighestUnit == .month && isGregorianCalendar && component(.month, from: matchDate) == 2 {
            // We've landed here because we couldn't find the date we wanted in February, because it doesn't exist (e.g. Feb 31st or 30th, or 29th on a non-leap-year).
            // matchDate is the end of February, so we need to advance to the beginning of March.
            if let february = dateInterval(of: .month, for: matchDate) {
                var adjustedDate = february.start + february.duration
                if matchingPolicy == .nextTimePreservingSmallerComponents {
                    // Advancing has caused us to lose all smaller units, so if we're looking to preserve them we need to add them back.
                    let smallerUnits = _dateComponents(.init(.hour, .minute, .second), from: start)
                    if let tempSearchDate = date(byAdding: smallerUnits, to: adjustedDate) {
                        adjustedDate = tempSearchDate
                    } else {
                        // TODO: Assert?
                        return nil
                    }
                }

                // This isn't strictly a leap day, just a day that doesn't exist.
                isLeapDay = true
                isExactMatch = false
                return adjustedDate
            }

            return matchDate
        } else {
            // Go to the top of the next period for the next highest unit of the one that bailed.
            // Force unwrap nextHighestUnit because it must be set here (or we should have gone down the leapMonthMismatch path)
            return _matchingDate(after: searchingDate, matching: matchingComponents, inNextHighestUnit: nextHighestUnit!, direction: direction, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy)
        }
    }

    // MARK: -

    func _matchingDate(after startDate: Date,
                       matching comps: DateComponents,
                       inNextHighestUnit: Component,
                       direction: SearchDirection,
                       matchingPolicy: MatchingPolicy,
                       repeatedTimePolicy: RepeatedTimePolicy) -> Date? {

        guard let foundRange = dateInterval(of: inNextHighestUnit, for: startDate) else {
            return nil
        }

        var nextSearchDate: Date?
        var innerDirection = direction

        if innerDirection == .backward {
            if inNextHighestUnit == .day {
                /*
                 If nextHighestUnit is day, it's a safe assumption that the highest actual set unit is the hour.
                 There are cases where we're looking for a minute and/or second within the first hour of the day. If we start just at the top of the day and go backwards, we could end up missing the minute/second we're looking for.
                 E.g.
                 We're looking for { hour: 0, minute: 30, second: 0 } in the day before the start date 2017-05-26 07:19:50 UTC. At this point, foundRange.start would be 2017-05-26 07:00:00 UTC.
                 In this case, the algorithm would do the following:
                     start at 2017-05-26 07:00:00 UTC, see that the hour is already set to what we want, jump to minute.
                     when checking for minute, it will cycle forward to 2017-05-26 07:30:00 +0000 but then compare to the start and see that that date is incorrect because it's in the future. Then it will cycle the date back to 2017-05-26 06:30:00 +0000.
                     the matchingDate call below will exit with 2017-05-26 06:30:00 UTC and the algorithm will see that date is incorrect and reset the new search date go back a day to 2017-05-25 07:19:50 UTC. Then we get back here to this method and move the start to 2017-05-25 07:00:00 UTC and the call to matchingDate below will return 2017-05-25 06:30:00 UTC, which skips what we want (2017-05-25 07:30:00 UTC) and the algorithm eventually keeps moving further and further into the past until it exhausts itself and returns nil.
                 To adjust for this scenario, we add this line below that sets nextSearchDate to the last minute of the previous day (using the above example, 2017-05-26 06:59:59 UTC), which causes the algorithm to not skip the minutes/seconds within the first hour of the previous day. (<rdar://problem/32609242>)
                 */
                nextSearchDate = foundRange.start - 1

                // One caveat: if we are looking for a date within the first hour of the day (i.e. between 12 and 1 am), we want to ensure we go forwards in time to hit the exact minute and/or second we're looking for since nextSearchDate is now in the previous day. (<rdar://problem/33944890>)
                if comps.hour == 0 {
                    innerDirection = .forward
                }
            } else {
                nextSearchDate = foundRange.start
            }
        } else {
            nextSearchDate = foundRange.start + foundRange.duration
        }

        return _matchingDate(after: nextSearchDate!, matching: comps, direction: innerDirection, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy)
    }

    func _matchingDate(after startDate: Date,
                       matching comps: DateComponents,
                       direction: SearchDirection,
                       matchingPolicy: MatchingPolicy,
                       repeatedTimePolicy: RepeatedTimePolicy) -> Date? {

        let isStrictMatching = matchingPolicy == .strict

        var matchedEra = true
        var searchStartDate = startDate

        if let result = dateAfterMatchingEra(startingAt: searchStartDate, components: comps, direction: direction, matchedEra: &matchedEra) {
            searchStartDate = result
        }

        // If era doesn't match we can just bail here instead of continuing on. A date from another era can't match. It's up to the caller to decide how to handle this mismatch.
        if !matchedEra {
            return nil
        }

        if let result = dateAfterMatchingYear(startingAt: searchStartDate, components: comps, direction: direction) {
            searchStartDate = result
        }

        if let result = dateAfterMatchingYearForWeekOfYear(startingAt: searchStartDate, components: comps, direction: direction) {
            searchStartDate = result
        }

        if let result = dateAfterMatchingQuarter(startingAt: searchStartDate, components: comps, direction: direction) {
            searchStartDate = result
        }

        if let result = dateAfterMatchingWeekOfYear(startingAt: searchStartDate, components: comps, direction: direction) {
            searchStartDate = result
        }

        if let result = dateAfterMatchingMonth(startingAt: searchStartDate, components: comps, direction: direction, strictMatching: isStrictMatching) {
            searchStartDate = result
        }

        if let result = dateAfterMatchingWeekOfMonth(startingAt: searchStartDate, components: comps, direction: direction) {
            searchStartDate = result
        }

        if let result = dateAfterMatchingWeekdayOrdinal(startingAt: searchStartDate, components: comps, direction: direction) {
            searchStartDate = result
        }

        if let result = dateAfterMatchingWeekday(startingAt: searchStartDate, components: comps, direction: direction) {
            searchStartDate = result
        }

        if let result = dateAfterMatchingDay(startingAt: searchStartDate, originalStartDate: startDate, components: comps, direction: direction) {
            searchStartDate = result
        }

        if let result = dateAfterMatchingHour(startingAt: searchStartDate, originalStartDate: startDate, components: comps, direction: direction, findLastMatch: repeatedTimePolicy == .last, isStrictMatching: isStrictMatching, matchingPolicy: matchingPolicy) {
            searchStartDate = result
        }

        if let result = dateAfterMatchingMinute(startingAt: searchStartDate, components: comps, direction: direction) {
            searchStartDate = result
        }

        if let result = dateAfterMatchingSecond(startingAt: searchStartDate, originalStartDate: startDate, components: comps, direction: direction) {
            searchStartDate = result
        }

        if let result = dateAfterMatchingNanosecond(startingAt: searchStartDate, components: comps, direction: direction) {
            searchStartDate = result
        }

        return searchStartDate
    }

    // MARK: Create Next Helpers -

    private func dateAfterMatchingEra(startingAt startDate: Date, components: DateComponents, direction: SearchDirection, matchedEra: inout Bool) -> Date? {
        guard let era = components.era else { return nil }
        let dateEra = component(.era, from: startDate)

        guard era != dateEra else {
            // Nothing to do
            return nil
        }

        if (direction == .backward && era <= dateEra) || (direction == .forward && era >= dateEra) {
            var dateComp = DateComponents()
            dateComp.era = era
            dateComp.year = 1
            dateComp.month = 1
            dateComp.day = 1
            dateComp.hour = 0
            dateComp.minute = 0
            dateComp.second = 0
            dateComp.nanosecond = 0
            if let result = self.date(from: dateComp) {
                let dateCompEra = component(.era, from: result)
                if (dateCompEra != era) {
                    matchedEra = false
                }
                return result
            } else {
                matchedEra = false
                return nil
            }
        } else {
            matchedEra = false
            return nil
        }
    }

    private func dateAfterMatchingYear(startingAt: Date, components: DateComponents, direction: SearchDirection) -> Date? {
        guard let year = components.year else { return nil }

        let dateComp = _dateComponents(.init(.era, .year), from: startingAt)
        guard let dcYear = dateComp.year else { return nil }

        if year == dcYear {
            // Nothing to do
            return nil
        }

        guard let yearBegin = dateIfEraHasYear(era: dateComp.era ?? Int.max, year: year) else { return nil }

        // We set searchStartDate to the end of the year ONLY if we know we will be trying to match anything else beyond just the year and it'll be a backwards search; otherwise, we set searchStartDate to the start of the year.
        let totalSetUnits = components.setUnitCount
        if direction == .backward && totalSetUnits > 1 {
            guard let foundRange = dateInterval(of: .year, for: yearBegin) else { return nil }

            return yearBegin + (foundRange.duration - 1)
        } else {
            return yearBegin
        }
    }

    private func dateAfterMatchingYearForWeekOfYear(startingAt: Date, components: DateComponents, direction: SearchDirection) -> Date? {
        guard let yearForWeekOfYear = components.yearForWeekOfYear else { return nil }

        let dateComp = _dateComponents(.init(.era, .yearForWeekOfYear), from: startingAt)
        guard dateComp.yearForWeekOfYear ?? Int.max != yearForWeekOfYear else { return nil }

        guard let yearBegin = dateIfEraHasYearForWeekOfYear(era: dateComp.era ?? Int.max, yearForWeekOfYear: yearForWeekOfYear) else { return nil }

        if direction == .backward {
            // We need to set searchStartDate to the end of the year
            guard let foundRange = dateInterval(of: .yearForWeekOfYear, for: yearBegin) else { return nil }
            return yearBegin + (foundRange.duration - 1)
        } else {
            return yearBegin
        }
    }

    private func dateAfterMatchingQuarter(startingAt: Date, components: DateComponents, direction: SearchDirection) -> Date? {
        guard let quarter = components.quarter else { return nil }

        // Get the beginning of the year we need
        guard let foundRange = dateInterval(of: .year, for: startingAt) else { return nil }

        if direction == .backward {
            var quarterBegin = foundRange.start + (foundRange.duration - 1)
            var count = 4
            while count != quarter && count > 0 {
                guard let quarterRange = dateInterval(of: .quarter, for: quarterBegin) else { return nil }
                quarterBegin = quarterRange.start - quarterRange.duration
                count -= 1
            }

            return quarterBegin
        } else {
            var count = 1
            var quarterBegin = foundRange.start
            while count != quarter && count < 5 {
                guard let quarterRange = dateInterval(of: .quarter, for: quarterBegin) else { return nil }
                // Move past this quarter. The is the first instant of the next quarter.
                quarterBegin = quarterRange.start + quarterRange.duration
                count += 1
            }

            return quarterBegin
        }
    }

    private func dateAfterMatchingWeekOfYear(startingAt: Date, components: DateComponents, direction: SearchDirection) -> Date? {
        guard let weekOfYear = components.weekOfYear else { return nil }
        var dateWeekOfYear = component(.weekOfYear, from: startingAt)

        guard weekOfYear != dateWeekOfYear else {
            // Already matches
            return nil
        }

        // After this point, the result is at least the start date
        var result = startingAt
        repeat {
            guard let foundRange = dateInterval(of: .weekOfYear, for: result) else { return nil }

            if direction == .backward {
                let searchDate = foundRange.start - foundRange.duration
                dateWeekOfYear = component(.weekOfYear, from: searchDate)
                result = searchDate
            } else {
                let searchDate = foundRange.start + foundRange.duration
                dateWeekOfYear = component(.weekOfYear, from: searchDate)
                result = searchDate
            }

        } while weekOfYear != dateWeekOfYear

        return result
    }

    private func dateAfterMatchingMonth(startingAt startDate: Date, components: DateComponents, direction: SearchDirection, strictMatching: Bool) -> Date? {
        guard let month = components.month else { return nil }

        let isChineseCalendar = self.identifier == .chinese
        let isLeapMonthDesired = isChineseCalendar && (components.isLeapMonth ?? false)

        // After this point, result is at least startDate
        var result = startDate
        var dateMonth = component(.month, from: result)
        if month != dateMonth {
            var iterations = 20
            repeat {
                guard let foundRange = dateInterval(of: .month, for: result) else { return nil }
                var duration = foundRange.duration

                // Ensure we do not loop forever if we end up in a situation where month does not change
                iterations -= 1
                guard iterations > 0 else { return nil }

                if direction == .backward {
                    let numMonth = component(.month, from: foundRange.start)
                    if numMonth == 3 && (self.identifier == .gregorian || self.identifier == .buddhist || self.identifier == .japanese || self.identifier == .iso8601 || self.identifier == .republicOfChina) {
                        // Take it back 3 days so we land in february.  That is, March has 31 days, and Feb can have 28 or 29, so to ensure we get to either Feb 1 or 2, we need to take it back 3 days.
                        duration -= 86400 * 3
                    } else {
                        // Take it back a day
                        duration -= 86400
                    }

                    // So we can go backwards in time
                    duration *= -1
                }

                let searchDate = foundRange.start + duration
                dateMonth = component(.month, from: searchDate)
                result = searchDate
            } while month != dateMonth
        }

        // As far as we know, this is only relevant for the Chinese calendar.  In that calendar, the leap month has the same month number as the preceding month.
        // If we're searching forwards in time looking for a leap month, we need to skip the first occurrence we found of that month number because the first occurrence would not be the leap month; however, we only do this is if we are matching strictly. If we don't care about strict matching, we can skip this and let the caller handle it so it can deal with the approximations if necessary.
        if isLeapMonthDesired && strictMatching {
            // Check to see if we are already at a leap month
            let isLeapMonth = _dateComponents(.month, from: result).isLeapMonth ?? false
            if !isLeapMonth {
                var searchDate = result
                var iterations = 0
                repeat {
                    guard let leapMonthInterval = dateInterval(of: .month, for: searchDate) else { return nil }
                    var duration = leapMonthInterval.duration
                    if direction == .backward {
                        // Months in the Chinese calendar can be either 29 days ("short month") or 30 days ("long month").  We need to account for this when moving backwards in time so we don't end up accidentally skipping months.  If leapMonthBegin is 30 days long, we need to subtract from that 30 so we don't potentially skip over the previous short month.
                        // Also note that some days aren't exactly 24hrs long, so we can end up with lengthOfMonth being something like 29.958333333332, for example.  This is a (albeit hacky) way of getting around that.
                        let lengthOfMonth = duration / 86400
                        if lengthOfMonth > 30 {
                            duration -= 86400 * 2
                        } else if lengthOfMonth > 28 {
                            duration -= 86400
                        }

                        duration *= -1
                    }

                    let possibleLeapMonth = leapMonthInterval.start + duration
                    // Note: setting month also tells Calendar to set leapMonth at the same time
                    let monthComps = _dateComponents(.month, from: possibleLeapMonth)
                    let dateMonth = monthComps.month ?? Int.max
                    if dateMonth == month && monthComps.isLeapMonth ?? false {
                        result = possibleLeapMonth
                        break
                    } else {
                        searchDate = possibleLeapMonth
                    }

                    iterations += 1
                    if iterations > 10_000 {
                        // Safety escape hatch for an otherwise infinite loop
                        return nil
                    }
                } while true
            }
        }

        return result
    }

    private func dateAfterMatchingWeekOfMonth(startingAt: Date, components: DateComponents, direction: SearchDirection) -> Date? {
        guard let weekOfMonth = components.weekOfMonth else { return nil }

        var dateWeekOfMonth = component(.weekOfMonth, from: startingAt)
        guard weekOfMonth != dateWeekOfMonth else {
            // Already matches
            return nil
        }

        // After this point, result is at least startDate
        var result = startingAt

        repeat {
            guard let foundRange = dateInterval(of: .weekOfMonth, for: result) else { return nil }
            // We need to advance or rewind to the next week.
            // This is simple when we can jump by a whole week interval, but there are complications around WoM == 1 because it can start on any day of the week. Jumping forward/backward by a whole week can miss it.
            //
            // A week 1 which starts on any day but Sunday contains days from week 5 of the previous month, e.g.
            //
            //        June 2018
            //   Su Mo Tu We Th Fr Sa
            //                   1  2
            //    3  4  5  6  7  8  9
            //   10 11 12 13 14 15 16
            //   17 18 19 20 21 22 23
            //   24 25 26 27 28 29 30
            //
            // Week 1 of June 2018 starts on Friday; any day before that is week 5 of May.
            // We can jump by a week interval if we're not looking for WoM == 2 or we're not close.
            var advanceDaily = weekOfMonth == 1 // we're looking for WoM == 1
            if direction == .backward {
                // Last week/earlier this week is week 1.
                advanceDaily = advanceDaily && dateWeekOfMonth <= 2
            } else {
                // We need to be careful if it's the last week of the month. We can't assume what number week that would be, so figure it out.
                let range = range(of: .weekOfMonth, in: .month, for: result) ?? 0..<Int.max
                advanceDaily = advanceDaily && dateWeekOfMonth == (range.endIndex - range.startIndex)
            }

            // TODO: This should be set to something in all paths before being used below. It would be nice to refactor this to avoid the force unwrap
            var tempSearchDate: Date!
            if !advanceDaily {
                // We can jump directly to next/last week. There's just one further wrinkle here when doing so backwards: due to DST, it's possible that this week is longer/shorter than last week.
                // That means that if we rewind by womInv (the length of this week), we could completely skip last week, or end up not at its first instant.
                //
                // We can avoid this by not rewinding by womInv, but by going directly to the start.
                if direction == .backward {
                    // Any instant before foundRange.start is last week
                    let lateLastWeek = foundRange.start - 1
                    if let interval = dateInterval(of: .weekOfMonth, for: lateLastWeek) {
                        tempSearchDate = interval.start
                    } else {
                        // Fall back to below case
                        advanceDaily = true
                    }
                } else {
                    // Skipping forward doesn't have these DST concerns, since foundRange already represents the length of this week.
                    tempSearchDate = foundRange.start + foundRange.duration
                }
            }

            // This is a separate condition because it represents a "possible" fallthrough from above.
            if advanceDaily {
                var today = foundRange.start
                while component(.day, from: today) != 1 {
                    if let next = date(byAdding: .day, value: direction == .backward ? -1 : 1, to: today) {
                        today = next
                    } else {
                        break
                    }
                }

                tempSearchDate = today
            }

            dateWeekOfMonth = component(.weekOfMonth, from: tempSearchDate)
            result = tempSearchDate
        } while weekOfMonth != dateWeekOfMonth

        return result
    }

    private func dateAfterMatchingWeekdayOrdinal(startingAt: Date, components: DateComponents, direction: SearchDirection) -> Date? {
        guard let weekdayOrdinal = components.weekdayOrdinal else { return nil }

        var dateWeekdayOrdinal = component(.weekdayOrdinal, from: startingAt)
        guard weekdayOrdinal != dateWeekdayOrdinal else { return nil }

        // After this point, result is at least startDate
        var result = startingAt

        repeat {
            // Future improvement: Consider jumping ahead by week here instead of day
            guard let foundRange = dateInterval(of: .weekdayOrdinal, for: result) else { return nil }

            if direction == .backward {
                let searchDate = foundRange.start - foundRange.duration
                dateWeekdayOrdinal = component(.weekdayOrdinal, from: searchDate)
                result = searchDate
            } else {
                let searchDate = foundRange.start + foundRange.duration
                dateWeekdayOrdinal = component(.weekdayOrdinal, from: searchDate)
                result = searchDate
            }
        } while weekdayOrdinal != dateWeekdayOrdinal

        // NOTE: In order for an ordinal weekday to not be ambiguous, it needs both
        //  - the ordinality (e.g. 1st)
        //  - the weekday (e.g. Tuesday)
        // If the weekday is not set, we assume the client just wants the first time in a month where the number of occurrences of a day matches the weekdayOrdinal value (e.g. for weekdayOrdinal = 4, this means the first time a weekday is the 4th of that month. So if the start date is 2017-06-01, then the first time we hit a day that is the 4th occurrence of a weekday would be 2017-06-22. I recommend looking at the month in its entirety on a calendar to see what I'm talking about.).  This is an odd request, but we will return that result to the client while silently judging them.
        // For a non-ambiguous ordinal weekday (i.e. the ordinality and the weekday have both been set), we need to ensure that we get the exact ordinal day that we are looking for. Hence the below weekday check.
        guard let weekday = components.weekday else {
            // Skip weekday
            return result
        }

        // Once we're here, it means we found a day with the correct ordinality, but it may not be the specific weekday we're also looking for (e.g. we found the 2nd Thursday of the month when we're looking for the 2nd Friday).
        var dateWeekday = component(.weekday, from: result)
        if weekday == dateWeekday {
            // Already matches
            return result
        }

        // Start result over (it is reset in all paths below)

        if dateWeekday > weekday {
            // We're past the weekday we want. Go to the beginning of the week
            // We use startDate again here, not result

            if let foundRange = dateInterval(of: .weekdayOrdinal, for: startingAt) {
                result = foundRange.start
                let startingDayWeekdayComps = _dateComponents(.init(.weekday, .weekdayOrdinal), from: result)

                guard let wd = startingDayWeekdayComps.weekday, let wdO = startingDayWeekdayComps.weekdayOrdinal else {
                    // This should not be possible
                    return nil
                }
                dateWeekday = wd
                dateWeekdayOrdinal = wdO
            } else {
                // We need to have a value here - use the start date
                result = startingAt
            }
        } else {
            result = startingAt
        }

        while (weekday != dateWeekday) || (weekdayOrdinal != dateWeekdayOrdinal) {
            // Now iterate through each day of the week until we find the specific weekday we're looking for.

            if let foundRange = dateInterval(of: .day, for: result) {
                let nextDay = foundRange.start + foundRange.duration
                let nextDayComponents = _dateComponents(.init(.weekday, .weekdayOrdinal), from: nextDay)

                guard let wd = nextDayComponents.weekday, let wdO = nextDayComponents.weekdayOrdinal else {
                    // This should not be possible
                    return nil
                }

                dateWeekday = wd
                dateWeekdayOrdinal = wdO
                result = nextDay
            } else {
                return result
            }
        }

        return result
    }

    private func dateAfterMatchingWeekday(startingAt: Date, components: DateComponents, direction: SearchDirection) -> Date? {
        // NOTE: This differs from the weekday check in weekdayOrdinal because weekday is meant to be ambiguous and can be set without setting the ordinality.
        // e.g. inquiries like "find the next tuesday after 2017-06-01" or "find every wednesday before 2012-12-25"

        guard let weekday = components.weekday else { return nil }
        var dateWeekday = component(.weekday, from: startingAt)
        guard weekday != dateWeekday else {
            // Already matches
            return nil
        }

        // After this point, result is at least startDate
        var result = startingAt
        repeat {
            guard let foundRange = dateInterval(of: .weekday, for: result) else { return nil }

            // We need to either advance or rewind by a day.
            // * Advancing to tomorrow is relatively simple: get the start of today and get the length of that day — then, advance by that length
            // * Rewinding to the start of yesterday is more complicated: the length of today is not necessarily the length of yesterday if DST transitions are involved:
            //   * Today can have 25 hours: if we rewind 25 hours from the start of today, we'll skip yesterday altogether
            //   * Today can have 24 hours: if we rewind 24 hours from the start of today, we might skip yesterday if it had 23 hours, or end up at the wrong time if it had 25
            //   * Today can have 23 hours: if we rewind 23 hours from the start of today, we'll end up at the wrong time yesterday
            //
            // We need to account for DST by ensuring we rewind to exactly the time we want.
            let tempSearchDate: Date
            if direction == .backward {
                let lateYesterday = foundRange.start - 1

                if let anotherFoundRange = dateInterval(of: .day, for: lateYesterday) {
                    tempSearchDate = anotherFoundRange.start
                } else {
                    // This fallback is only really correct when today and yesterday have the same length.
                    // Again, it shouldn't be possible to hit this case.
                    tempSearchDate = foundRange.start - foundRange.duration
                }

            } else {
                // This is always correct to do since we are using today's length on today — there can't be a mismatch.
                tempSearchDate = foundRange.start + foundRange.duration
            }

            dateWeekday = component(.weekday, from: tempSearchDate)
            result = tempSearchDate
        } while (weekday != dateWeekday)

        return result
    }

    private func dateAfterMatchingDay(startingAt startDate: Date, originalStartDate: Date, components comps: DateComponents, direction: SearchDirection) -> Date? {
        guard let day = comps.day else { return nil }

        var result = startDate
        var dateDay = component(.day, from: result)
        let month = comps.month

        if month != nil && direction == .backward {
            // Are we in the right month already?  If we are and backwards is set, we should move to the beginning of the last day of the month and work backwards.
            if let foundRange = dateInterval(of: .month, for: result) {
                let tempSearchDate = foundRange.start + foundRange.duration - 1
                // Check the order to make sure we didn't jump ahead of the start date
                if tempSearchDate > originalStartDate {
                    // We went too far ahead.  Just go back to using the start date as our upper bound.
                    result = originalStartDate
                } else {
                    if let anotherFoundRange = dateInterval(of: .day, for: tempSearchDate) {
                        result = anotherFoundRange.start
                        dateDay = component(.day, from: result)
                    }
                }
            }
        }

        if day != dateDay {
            // The condition below keeps us from blowing past a month day by day to find a day which does not exist.
            // e.g. trying to find the 30th of February starting in January would go to March 30th if we don't stop here
            let originalMonth = component(.month, from: result)
            var advancedPastWholeMonth = false
            var lastFoundDuration: TimeInterval = 0.0

            repeat {
                guard let foundRange = dateInterval(of: .day, for: result) else {
                    return nil
                }

                // Used to track if we went past end of month below
                lastFoundDuration = foundRange.duration

                // We need to either advance or rewind by a day.
                // * Advancing to tomorrow is relatively simple: get the start of today and get the length of that day — then, advance by that length
                // * Rewinding to the start of yesterday is more complicated: the length of today is not necessarily the length of yesterday if DST transitions are involved:
                //   * Today can have 25 hours: if we rewind 25 hours from the start of today, we'll skip yesterday altogether
                //   * Today can have 24 hours: if we rewind 24 hours from the start of today, we might skip yesterday if it had 23 hours, or end up at the wrong time if it had 25
                //   * Today can have 23 hours: if we rewind 23 hours from the start of today, we'll end up at the wrong time yesterday
                //
                // We need to account for DST by ensuring we rewind to exactly the time we want.

                let tempSearchDate: Date

                if direction == .backward {
                    // Any time prior to dayBegin is yesterday. Since we want to rewind to the start of yesterday, do that directly.
                    let lateYesterday = foundRange.start - 1

                    // Now we can get the exact moment that yesterday began on.
                    // It shouldn't be possible to fail to find this interval, but if that somehow happens, we can try to fall back to the simple but wrong method.
                    if let yesterdayRange = dateInterval(of: .day, for: lateYesterday) {
                        tempSearchDate = yesterdayRange.start
                    } else {
                        // This fallback is only really correct when today and yesterday have the same length.
                        // Again, it shouldn't be possible to hit this case.
                        tempSearchDate = foundRange.start - foundRange.duration
                    }
                } else {
                    // This is always correct to do since we are using today's length on today -- there can't be a mismatch.
                    tempSearchDate = foundRange.start + foundRange.duration
                 }

                dateDay = component(.day, from: tempSearchDate)
                let dateMonth = component(.month, from: tempSearchDate)
                result = tempSearchDate

                if abs(dateMonth - originalMonth) >= 2 {
                    advancedPastWholeMonth = true
                    break
                }
            } while day != dateDay

            // If we blew past a month in its entirety, roll back by a day to the very end of the month.
            if (advancedPastWholeMonth) {
                let tempSearchDate = result
                result = tempSearchDate - lastFoundDuration
            }

        } else {
            // When the search date matches the day we're looking for, we still need to clear the lower components in case they are not part of the components we're looking for.
            if let foundRange = dateInterval(of: .day, for: result) {
                result = foundRange.start
            }
        }

        return result
    }

    private func dateAfterMatchingHour(startingAt startDate: Date, originalStartDate: Date, components: DateComponents, direction: SearchDirection, findLastMatch: Bool, isStrictMatching: Bool, matchingPolicy: MatchingPolicy) -> Date? {
        guard let hour = components.hour else { return nil }

        var result = startDate
        var adjustedSearchStartDate = false

        var dateHour = component(.hour, from: result)

        // The loop below here takes care of advancing forward in the case of an hour mismatch, taking DST into account.
        // However, it does not take into account a unique circumstance: searching for hour 0 of a day on a day that has no hour 0 due to DST.
        //
        // America/Sao_Paulo, for instance, is a time zone which has DST at midnight -- an instant after 11:59:59 PM can become 1:00 AM, which is the start of the new day:
        //
        //            2018-11-03                      2018-11-04
        //    ┌─────11:00 PM (GMT-3)─────┐ │ ┌ ─ ─ 12:00 AM (GMT-3)─ ─ ─┐ ┌─────1:00 AM (GMT-2) ─────┐
        //    │                          │ │ |                          │ │                          │
        //    └──────────────────────────┘ │ └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┘ └▲─────────────────────────┘
        //                                            Nonexistent          └── Start of Day
        //
        // The issue with this specifically is that parts of the rewinding algorithm that handle overshooting rewind to the start of the day to search again (or alternatively, adjusting higher components tends to send us to the start of the day).
        // This doesn't work when the day starts past the time we're looking for if we're looking for hour 0.
        //
        // If we're not matching strictly, we need to check whether we're already a non-strict match and not an overshoot.
        if hour == 0 /* searching for hour 0 */ && !isStrictMatching {
            if let foundRange = dateInterval(of: .day, for: result) {
                let dayBegin = foundRange.start
                let firstHourOfTheDay = component(.hour, from: dayBegin)
                if firstHourOfTheDay != 0 && dateHour == firstHourOfTheDay {
                    // We're at the start of the day; it's just not hour 0.
                    // We have a candidate match. We can modify that match based on the actual options we need to set.

                    if matchingPolicy == .nextTime {
                        // We don't need to preserve the smallest components. We can wipe them out.
                        // Note that we rewind to the start of the hour by rewinding to the start of the day -- normally we'd want to rewind to the start of _this_ hour in case there were a difference in a first/last scenario (repeated hour DST transition), but we can't both be missing hour 0 _and_ be the second hour in a repeated transition.
                        result = dayBegin
                    } else if matchingPolicy == .nextTimePreservingSmallerComponents || matchingPolicy == .previousTimePreservingSmallerComponents {
                        // We want to preserve any currently set smaller units (hour and minute), so don't do anything.
                        // If we need to match the previous time (i.e. go back an hour), that adjustment will be made elsewhere, in the generalized isForwardDST adjustment in the main loop.
                    }

                    // Avoid making any further adjustments again.
                    adjustedSearchStartDate = true
                }
            }
        }

        // This is a real mismatch and not due to hour 0 being missing.
        // NOTE: The behavior of generalized isForwardDST checking depends on the behavior of this loop!
        //       Right now, in the general case, this loop stops iteration _before_ a forward DST transition. If that changes, please take a look at the isForwardDST code for when `beforeTransition = false` and adjust as necessary.
        if hour != dateHour && !adjustedSearchStartDate {
            repeat {
                guard let foundRange = dateInterval(of: .hour, for: result) else { return nil }

                let prevDateHour = dateHour
                let tempSearchDate = foundRange.start + foundRange.duration

                dateHour = component(.hour, from: tempSearchDate)

                // Sometimes we can get into a position where the next hour is also equal to hour (as in we hit a backwards DST change). In this case, we could be at the first time this hour occurs. If we want the next time the hour is technically the same (as in we need to go to the second time this hour occurs), we check to see if we hit a backwards DST change.
                let possibleBackwardDSTDate = foundRange.start + (foundRange.duration * 2)
                let secondDateHour = component(.hour, from: possibleBackwardDSTDate)

                if ((dateHour - prevDateHour) == 2) || (prevDateHour == 23 && dateHour == 1) {
                    // We've hit a forward DST transition.
                    dateHour = dateHour - 1
                    result = foundRange.start
                } else if (secondDateHour == dateHour) && findLastMatch {
                    // If we're not trying to find the last match, just pass on the match we already found.
                    // We've hit a backwards DST transition.
                    result = possibleBackwardDSTDate
                } else {
                    result = tempSearchDate
                }

                adjustedSearchStartDate = true
            } while hour != dateHour

            if direction == .backward && originalStartDate < result {
                // We've gone into the future when we were supposed to go into the past.  We're ahead by a day.
                result = date(byAdding: .day, value: -1, to: result)!

                // Check hours again to see if they match (they may not because of DST change already being handled implicitly by dateByAddingUnit:)
                dateHour = component(.hour, from: result)
                if (dateHour - hour) == 1 {
                    // Detecting a DST transition
                    // We have moved an hour ahead of where we want to be so we go back 1 hour to readjust.
                    result = date(byAdding: .hour, value: -1, to: result)!
                } else if (hour - dateHour) == 1 {
                    // <rdar://problem/31051045>
                    // This is a weird special edge case that only gets hit when you're searching backwards and move past a forward (skip an hour) DST transition.
                    // We're not at a DST transition but the hour of our date got moved because the previous day had a DST transition.
                    // So we're an hour before where we want to be. We move an hour ahead to correct and get back to where we need to be.
                    result = date(byAdding: .hour, value: 1, to: result)!
                }
            }
        }

        if findLastMatch {
            if let foundRange = dateInterval(of: .hour, for: result) {
                // Rewind forward/back hour-by-hour until we get to a different hour. A loop here is necessary because not all DST transitions are only an hour long.
                var next = foundRange.start
                var nextHour = hour
                while nextHour == hour {
                    result = next
                    next = date(byAdding: .hour, value: direction == .backward ? -1 : 1, to: next)!
                    nextHour = component(.hour, from: next)
                }
            }
        }

        if !adjustedSearchStartDate {
            // This applies if we didn't hit the above cases to adjust the search start date, i.e. the hour already matches the start hour and either:
            // 1) We're not looking to match the "last" (repeated) hour in a DST transition (regardless of whether we're in a DST transition), or
            // 2) We are looking to match that hour, but we're not in that DST transition.
            //
            // In either case, we need to clear the lower components in case they are not part of the components we're looking for.
            if let foundRange = dateInterval(of: .hour, for: result) {
                result = foundRange.start
                adjustedSearchStartDate = true
            }
        }

        return result
    }

    private func dateAfterMatchingMinute(startingAt: Date, components: DateComponents, direction: SearchDirection) -> Date? {
        guard let minute = components.minute else { return nil }

        var result = startingAt
        var dateMinute = component(.minute, from: result)
        if minute != dateMinute {
            repeat {
                guard let foundRange = dateInterval(of: .minute, for: result) else {
                    return nil
                }

                let tempSearchDate = foundRange.start + foundRange.duration
                dateMinute = component(.minute, from: tempSearchDate)
                result = tempSearchDate
            } while minute != dateMinute
        } else {
            // When the search date matches the minute we're looking for, we need to clear the lower components in case they are not part of the components we're looking for.
            if let foundRange = dateInterval(of: .minute, for: result) {
                result = foundRange.start
            }
        }

        return result
    }

    private func dateAfterMatchingSecond(startingAt startDate: Date, originalStartDate: Date, components: DateComponents, direction: SearchDirection) -> Date? {
        guard let second = components.second else { return nil }

        // After this point, result is at least startDate
        var result = startDate

        var dateSecond = component(.second, from: result)
        if second != dateSecond {
            repeat {
                guard let foundRange = dateInterval(of: .second, for: result) else { return nil }

                let tempSearchDate = foundRange.start + foundRange.duration
                dateSecond = component(.second, from: tempSearchDate)
                result = tempSearchDate
            } while second != dateSecond

            if originalStartDate < result {
                if direction == .backward {
                    // We've gone into the future when we were supposed to go into the past.
                    // There are multiple times a day where the seconds repeat.  Need to take that into account.
                    let originalStartSecond = component(.second, from: originalStartDate)
                    if dateSecond > originalStartSecond {
                        guard let new = date(byAdding: .minute, value: -1, to: result) else {
                            return nil
                        }
                        result = new
                    }
                } else {
                    // This handles the case where dateSecond started ahead of second, so doing the above landed us in the next minute.  If minute is not set, we are fine.  But if minute is set, then we are now in the wrong minute and we have to readjust. <rdar://problem/31098131>
                    var searchStartMin = component(.minute, from: result)
                    if let minute = components.minute {
                        if searchStartMin > minute {
                            // We've gone ahead of where we needed to be
                            repeat {
                                // Reset to beginning of minute
                                if let foundRange = dateInterval(of: .minute, for: result) {
                                    let tempSearchDate = foundRange.start - foundRange.duration
                                    searchStartMin = component(.minute, from: tempSearchDate)
                                    result = tempSearchDate
                                }
                            } while searchStartMin > minute
                        }
                    }
                }
            }
        } else {
            // When the search date matches the second we're looking for, we need to clear the lower components in case they are not part of the components we're looking for.
            if let anotherFoundRange = dateInterval(of: .second, for: result) {
                result = anotherFoundRange.start
                // Now searchStartDate <= startDate
            }
        }

        return result
    }

    private func dateAfterMatchingNanosecond(startingAt: Date, components: DateComponents, direction: SearchDirection) -> Date? {
        guard let nanosecond = components.nanosecond else { return nil }

        // This taken directly from the old algorithm.  We don't have great support for nanoseconds in general and trying to treat them like seconds causes a hang. :-/
        // <rdar://problem/30229247>
        var dateComp = _dateComponents(.init(.era, .year, .month, .day, .hour, .minute, .second), from: startingAt)
        dateComp.nanosecond = nanosecond
        return date(from: dateComp)
    }

    // MARK: -
    private func dateIfEraHasYear(era: Int, year: Int) -> Date? {
        guard var date = date(from: DateComponents(era: era, year: year)) else { return nil }
        var comp = _dateComponents(.init(.era, .year), from: date)
        if year == 1 {
            let addingComp = DateComponents(day: 1)

            // this is needed for Japanese calendar (and maybe other calendars with more than a few eras too)
            while comp.era ?? Int.max < era {
                guard let newDate = self.date(byAdding: addingComp, to: date) else { return nil }
                date = newDate
                comp = _dateComponents(.era, from: date)
            }

            comp = _dateComponents(.init(.era, .year), from: date) // because comp may have changed in the loop
        }

        if comp.era ?? Int.max == era && comp.year ?? Int.max == year {
            // For Gregorian calendar at least, era and year should always match up so date should always be assigned to result.
            return date
        }

        return nil
    }

    private func dateIfEraHasYearForWeekOfYear(era: Int, yearForWeekOfYear: Int) -> Date? {
        guard let yearBegin = dateIfEraHasYear(era: era, year: yearForWeekOfYear) else { return nil }
        return dateInterval(of: .yearForWeekOfYear, for: yearBegin)?.start
    }

    // MARK: -

    private func date(_ date: Date, containsMatchingComponents compsToMatch: DateComponents) -> (mismatchedUnits: Calendar.ComponentSet, contains: Bool) {
        var dateMatchesComps = true
        var compsFromDate = _dateComponents(compsToMatch.setUnits, from: date)

        if compsToMatch.calendar != nil {
            compsFromDate.calendar = compsToMatch.calendar
        }
        if compsToMatch.timeZone != nil {
            compsFromDate.timeZone = compsToMatch.timeZone
        }

        if compsFromDate != compsToMatch {
            dateMatchesComps = false
            var mismatchedUnitsOut = compsFromDate.mismatchedUnits(comparedTo: compsToMatch)

            // We only care about mismatched leapMonth if it was set on the compsToMatch input. Otherwise we ignore it, even if it's set on compsFromDate.
            if compsToMatch.isLeapMonth == nil {
                // Remove if it's present
                mismatchedUnitsOut.remove(.isLeapMonth)
            }

            return (mismatchedUnitsOut, dateMatchesComps)
        } else {
            return ([], dateMatchesComps)
        }
    }

    // MARK: -

    private func bumpedDateUpToNextHigherUnitInComponents(_ searchingDate: Date, _ comps: DateComponents, _ direction: SearchDirection, _ matchDate: Date?) -> Date? {
        guard let highestSetUnit = comps.highestSetUnit else {
            // Empty components?
            return nil
        }

        let nextUnitAboveHighestSet: Component

        if highestSetUnit == .era {
            nextUnitAboveHighestSet = .year
        } else if highestSetUnit == .year || highestSetUnit == .yearForWeekOfYear {
            nextUnitAboveHighestSet = highestSetUnit
        } else {
            guard let next = highestSetUnit.nextHigherUnit else {
                return nil
            }
            nextUnitAboveHighestSet = next
        }

        // Advance to the start or end of the next highest unit. Old code here used to add `±1 nextUnitAboveHighestSet` to searchingDate and manually adjust afterwards, but this is incorrect in many cases.
        // For instance, this is wrong when searching forward looking for a specific Week of Month. Take for example, searching for WoM == 1:
        //
        //           January 2018           February 2018
        //       Su Mo Tu We Th Fr Sa    Su Mo Tu We Th Fr Sa
        //  W1       1  2  3  4  5  6                 1  2  3
        //  W2    7  8  9 10 11 12 13     4  5  6  7  8  9 10
        //  W3   14 15 16 17 18 19 20    11 12 13 14 15 16 17
        //  W4   21 22 23 24 25 26 27    18 19 20 21 22 23 24
        //  W5   28 29 30 31             25 26 27 28
        //
        // Consider searching for `WoM == 1` when searchingDate is *in* W1 of January. Because we're looking to advance to next month, we could simply add a month, right?
        // Adding a month from Monday, January 1st lands us on Thursday, February 1st; from Tuesday, January 2nd we get Friday, February 2nd, etc. Note though that for January 4th, 5th, and 6th, adding a month lands us in **W2** of February!
        // This means that if we continue searching forward from there, we'll have completely skipped W1 of February as a candidate week, and search forward until we hit W1 of March. This is incorrect.
        //
        // What we really want is to skip to the _start_ of February and search from there -- if we undershoot, we can always keep looking.
        // Searching backwards is similar: we can overshoot if we were subtracting a month, so instead we want to jump back to the very end of the previous month.
        // In general, this translates to jumping to the very beginning of the next period of the next highest unit when searching forward, or jumping to the very end of the last period when searching backward.

        guard let foundRange = dateInterval(of: nextUnitAboveHighestSet, for: searchingDate) else {
            return nil
        }

        var result = foundRange.start + (direction == .backward ? -1 : foundRange.duration)

        if let matchDate {
            let ordering = ComparisonResult(matchDate, result)
            if (ordering != .orderedAscending && direction == .forward) || (ordering != .orderedDescending && direction == .backward) {
                // We need to advance searchingDate so that it starts just after matchDate
                // We already guarded against an empty components above, so force unwrap here
                let lowestSetUnit = comps.lowestSetUnit!
                guard let date = date(byAdding: lowestSetUnit, value: direction == .backward ? -1 : 1, to: matchDate) else {
                    return nil
                }
                result = date
            }
        }

        return result
    }

    // MARK: -

    private func preserveSmallerUnits(_ date: Date, compsToMatch: DateComponents, compsToModify: inout DateComponents) {
        let smallerUnits = _dateComponents(.init(.hour, .minute, .second), from: date)

        // Either preserve the units we're trying to match if they are explicitly defined or preserve the hour/min/sec in the date.
        compsToModify.hour = compsToMatch.hour ?? smallerUnits.hour
        compsToModify.minute = compsToMatch.minute ?? smallerUnits.minute
        compsToModify.second = compsToMatch.second ?? smallerUnits.second
    }
}

extension Calendar.Component {
    var nextHigherUnit: Self? {
        switch self {
        case .timeZone, .calendar:
            return nil // not really components
        case .era:
            return nil
        case .year, .yearForWeekOfYear:
            return .era
        case .weekOfYear:
            return .yearForWeekOfYear
        case .quarter, .isLeapMonth, .month:
            return .year
        case .day, .weekOfMonth, .weekdayOrdinal:
            return .month
        case .weekday:
            return .weekOfMonth
        case .hour:
            return .day
        case .minute:
            return .hour
        case .second:
            return .minute
        case .nanosecond:
            return .second
        }
    }
}
