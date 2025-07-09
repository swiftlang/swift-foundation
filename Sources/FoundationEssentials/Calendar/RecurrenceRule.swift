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

extension Calendar {
    /// A rule which specifies how often an event should repeat in the future
    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    public struct RecurrenceRule: Sendable, Equatable {
        /// The calendar in which the recurrence occurs
        public var calendar: Calendar
        /// What to do when a recurrence is not a valid date
        ///
        /// An occurrence may not be a valid date if it falls on a leap day or a
        /// leap hour when there is not one. When that happens, we can choose to
        /// ignore the occurrence (`.strict`), choose a later time which has the
        /// same components (`.nextTimePreservingSmallerComponents`), or find an
        /// earlier time (`.previousTimePreservingSmallerComponents`).
        ///
        /// For example, consider an event happening every year, starting on the
        /// 29th of February 2020. When the matching policy is set to `.strict`,
        /// it yields the following recurrences:
        /// - 2020-02-29
        /// - 2024-02-29
        /// - 2028-02-29
        /// - ...
        ///
        /// With `matchingPolicy` of `.previousTimePreservingSmallerComponents`,
        /// we get a result for each year:
        /// - 2020-02-29
        /// - 2021-02-28
        /// - 2022-02-28
        /// - 2023-02-28
        /// - 2024-02-29
        ///
        /// Lastly, a `matchingPolicy` of `.nextTimePreservingSmallerComponents`
        /// moves invalid occurrences to the day after February 29:
        /// - 2020-02-29
        /// - 2021-03-01
        /// - 2022-03-01
        /// - 2023-03-01
        /// - 2024-02-29
        ///
        /// The same logic applies for missing leap hours during daylight saving
        /// time switches. For example, consider an event repeating daily, which
        /// starts at March 9 2024, 01:30 PST. With a `.strict` matching policy,
        /// the event repeats on the following dates, and skips a day:
        /// - 2024-03-09 01:30 PST (09:30 UTC)
        ///   (on 2024-03-10, there is a missing hour between 1am and 2am)
        /// - 2024-03-11 01:30 PDT (08:30 UTC)
        /// - 2024-03-12 01:30 PDT (08:30 UTC)
        /// With `matchingPolicy` of `.previousTimePreservingSmallerComponents`,
        /// we get a result for each day:
        /// - 2024-03-09 01:30 PST (09:30 UTC)
        /// - 2024-03-10 02:30 PST (10:30 UTC)
        ///   (on 2024-03-10, there is a missing hour between 1am and 2am)
        /// - 2024-03-11 01:30 PDT (08:30 UTC)
        /// - 2024-03-12 01:30 PDT (08:30 UTC)
        /// Lastly, a `matchingPolicy` of `.nextTimePreservingSmallerComponents`
        /// moves invalid occurrences an hour forward:
        /// - 2024-03-09 01:30 PST (09:30 UTC)
        /// - 2024-03-10 00:30 PST (08:30 UTC)
        ///   (on 2024-03-10, there is a missing hour between 1am and 2am)
        /// - 2024-03-11 01:30 PDT (08:30 UTC)
        /// - 2024-03-12 01:30 PDT (08:30 UTC)
        ///
        /// Default value is `.nextTimePreservingSmallerComponents`
        public var matchingPolicy: Calendar.MatchingPolicy
        /// What to do when there are multiple recurrences occurring at the same
        /// time of the day but in different time zones due to a daylight saving
        /// transition.
        ///
        /// For example, an event with daily recurrence rule that starts at 1 am
        /// on November 2 in PDT will repeat on:
        ///
        /// - 2024-11-02 01:00 PDT (08:00 UTC)
        /// - 2024-11-03 01:00 PDT (08:00 UTC), if `repeatedTimePolicy = .first`
        ///   (Time zone switches from PST to PDT - clock jumps back one hour at
        ///    02:00 PDT)
        /// - 2024-11-03 01:00 PST (09:00 UTC), if `repeatedTimePolicy = .last`
        /// - 2024-11-04 01:00 PST (09:00 UTC)
        ///
        /// Due to the time zone switch on November 3, there are different times
        /// when the event might repeat.
        ///
        /// Default value is `.first`
        public var repeatedTimePolicy: Calendar.RepeatedTimePolicy
        /// How often a recurring event repeats
        public enum Frequency: Int, Sendable, Codable, Equatable {
            case minutely = 1
            case hourly = 2
            case daily = 3
            case weekly = 4
            case monthly = 5
            case yearly = 6
        }
        /// How often the event repeats
        public var frequency: Frequency
        /// At what interval to repeat
        ///
        /// Default value is `1`
        public var interval: Int
        /// When a recurring event stops recurring
        public struct End: Sendable, Equatable {
            private enum _End: Equatable, Hashable {
                case never
                case afterDate(Date)
                case afterOccurrences(Int)
            }
            private var _guts: _End
            private init(_guts: _End) {
                self._guts = _guts
            }
            /// The event stops repeating after a given number of times
            /// - Parameter count: how many times to repeat the event, including
            ///                    the first occurrence. `count` must be greater
            ///                    than `0`
            public static func afterOccurrences(_ count: Int) -> Self {
                .init(_guts: .afterOccurrences(count))
            }
            /// The event stops repeating after a given date
            /// - Parameter date: the date on which the event may last occur. No
            ///                   further occurrences will be found after that
            public static func afterDate(_ date: Date) -> Self {
                .init(_guts: .afterDate(date))
            }
            /// The event repeats indefinitely
            public static var never: Self {
                .init(_guts: .never)
            }

            /// At most many times the event may occur
            /// This value is set when the struct was initialized with `.afterOccurrences()`
            @available(FoundationPreview 6.0.2, *)
            public var occurrences: Int? {
                switch _guts {
                    case let .afterOccurrences(count): count
                    default: nil
                }
            }

            /// The latest date when the event may occur
            /// This value is set when the struct was initialized with `.afterDate()`
            @available(FoundationPreview 6.0.2, *)
            public var date: Date? {
                switch _guts {
                    case let .afterDate(date): date
                    default: nil
                }
            }
        }
        /// For how long the event repeats
        ///
        /// Default value is `.never`
        public var end: End
        
        public enum Weekday: Sendable, Equatable {
            /// Repeat on every weekday
            case every(Locale.Weekday)
            /// Repeat on the n-th instance of the specified weekday in a month,
            /// if the recurrence has a monthly frequency. If the recurrence has
            /// a yearly frequency, repeat on the n-th week of the year.
            ///
            /// If n is negative, repeat on the n-to-last of the given weekday.
            case nth(Int, Locale.Weekday)
        }
        
        /// Uniquely identifies a month in any calendar system
        public struct Month: Sendable, ExpressibleByIntegerLiteral, Equatable {
            public typealias IntegerLiteralType = Int
            
            public var index: Int
            public var isLeap: Bool
            
            public init(_ index: Int, isLeap: Bool = false) {
                self.index = index
                self.isLeap = isLeap
            }
            
            public init(integerLiteral value: Int) {
                self.index = value
                self.isLeap = false
            }
        }
        
        /// On which seconds of the minute the event should repeat. Valid values
        /// between 0 and 60
        public var seconds: [Int]
        /// On which minutes of the hour the event should repeat. Accepts values
        /// between 0 and 59
        public var minutes: [Int]
        /// On which hours of a 24-hour day the event should repeat.
        public var hours: [Int]
        /// On which days of the week the event should occur
        public var weekdays: [Weekday]
        /// On which days in the month the event should occur
        /// - 1 signifies the first day of the month.
        /// - Negative values point to a day counted backwards from the last day
        ///   of the month
        /// This field is unused when `frequency` is `.weekly`.
        public var daysOfTheMonth: [Int]
        /// On which days of the year the event may occur.
        /// - 1 signifies the first day of the year.
        /// - Negative values point to a day counted backwards from the last day
        ///   of the year
        /// This field is unused when `frequency` is any of `.daily`, `.weekly`,
        /// or `.monthly`.
        public var daysOfTheYear: [Int]
        /// On which months the event should occur.
        /// - 1 is the first month of the year (January in Gregorian calendars)
        public var months: [Month]
        /// On which weeks of the year the event should occur.
        /// - 1 is the first week of the year. `calendar.minimumDaysInFirstWeek`
        ///   defines which week is considered first.
        /// - Negative values refer to weeks if counting backwards from the last
        ///   week of the year. -1 is the last week of the year.
        /// This field is unused when `frequency` is other than `.yearly`.
        public var weeks: [Int]
        /// Which occurrences within every interval should be returned
        public var setPositions: [Int]
        
        public init(calendar: Calendar,
                    frequency: Frequency,
                    interval: Int = 1,
                    end: End = .never,
                    matchingPolicy: Calendar.MatchingPolicy = .nextTimePreservingSmallerComponents,
                    repeatedTimePolicy: Calendar.RepeatedTimePolicy = .first,
                    months: [Month] = [],
                    daysOfTheYear: [Int] = [],
                    daysOfTheMonth: [Int] = [],
                    weeks: [Int] = [],
                    weekdays: [Weekday] = [],
                    hours: [Int] = [],
                    minutes: [Int] = [],
                    seconds: [Int] = [],
                    setPositions: [Int] = []) {
            self.calendar = calendar
            self.frequency = frequency
            self.interval = interval
            self.end = end
            self.matchingPolicy = matchingPolicy
            self.repeatedTimePolicy = repeatedTimePolicy
            self.months = months
            self.daysOfTheYear = daysOfTheYear
            self.daysOfTheMonth = daysOfTheMonth
            self.weeks = weeks
            self.weekdays = weekdays
            self.hours = hours
            self.minutes = minutes
            self.seconds = seconds
            self.setPositions = setPositions
        }
        
        
        /// Find recurrences of the given date
        ///
        /// The calculations are implemented according to RFC-5545 and RFC-7529.
        ///
        /// - Parameter start: the date which defines the starting point for the
        ///   recurrence rule.
        /// - Parameter range: a range of dates which to search for recurrences.
        ///   If `nil`, return all recurrences of the event.
        /// - Returns: a sequence of dates conforming to the recurrence rule, in
        ///   the given `range`. An empty sequence if the rule doesn't match any
        ///   dates.
        /// A recurrence that repeats every `interval` minutes
        public func recurrences(of start: Date,
                                in range: Range<Date>? = nil
        ) -> some (Sequence<Date> & Sendable) {
            DatesByRecurring(start: start, recurrence: self, range: range)
        }
        
        /// A recurrence that repeats every `interval` minutes
        public static func minutely(calendar: Calendar, interval: Int = 1, end: End = .never, matchingPolicy: Calendar.MatchingPolicy = .nextTimePreservingSmallerComponents, repeatedTimePolicy: Calendar.RepeatedTimePolicy = .first, months: [Month] = [], daysOfTheYear: [Int] = [], daysOfTheMonth: [Int] = [], weekdays: [Weekday] = [], hours: [Int] = [], minutes: [Int] = [], seconds: [Int] = [], setPositions: [Int] = []) -> Self {
            .init(calendar: calendar, frequency: .minutely, interval: interval, end: end, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy, months: months, daysOfTheYear: daysOfTheYear, daysOfTheMonth: daysOfTheMonth, weekdays: weekdays, hours: hours, minutes: minutes, seconds: seconds, setPositions: setPositions)
        }
        /// A recurrence that repeats every `interval` hours
        public static func hourly(calendar: Calendar, interval: Int = 1, end: End = .never, matchingPolicy: Calendar.MatchingPolicy = .nextTimePreservingSmallerComponents, repeatedTimePolicy: Calendar.RepeatedTimePolicy = .first, months: [Month] = [], daysOfTheYear: [Int] = [], daysOfTheMonth: [Int] = [], weekdays: [Weekday] = [], hours: [Int] = [], minutes: [Int] = [], seconds: [Int] = [], setPositions: [Int] = []) -> Self {
            .init(calendar: calendar, frequency: .hourly, interval: interval, end: end, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy, months: months, daysOfTheYear: daysOfTheYear, daysOfTheMonth: daysOfTheMonth, weekdays: weekdays, hours: hours, minutes: minutes, seconds: seconds, setPositions: setPositions)
        }
        /// A recurrence that repeats every `interval` days
        public static func daily(calendar: Calendar, interval: Int = 1, end: End = .never, matchingPolicy: Calendar.MatchingPolicy = .nextTimePreservingSmallerComponents, repeatedTimePolicy: Calendar.RepeatedTimePolicy = .first, months: [Month] = [], daysOfTheMonth: [Int] = [], weekdays: [Weekday] = [], hours: [Int] = [], minutes: [Int] = [], seconds: [Int] = [], setPositions: [Int] = []) -> Self {
            .init(calendar: calendar, frequency: .daily, interval: interval, end: end, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy, months: months, daysOfTheMonth: daysOfTheMonth, weekdays: weekdays, hours: hours, minutes: minutes, seconds: seconds, setPositions: setPositions)
        }
        /// A recurrence that repeats every `interval` weeks
        public static func weekly(calendar: Calendar, interval: Int = 1, end: End = .never, matchingPolicy: Calendar.MatchingPolicy = .nextTimePreservingSmallerComponents, repeatedTimePolicy: Calendar.RepeatedTimePolicy = .first, months: [Month] = [], weekdays: [Weekday] = [], hours: [Int] = [], minutes: [Int] = [], seconds: [Int] = [], setPositions: [Int] = []) -> Self {
            .init(calendar: calendar, frequency: .weekly, interval: interval, end: end, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy, months: months, weekdays: weekdays, hours: hours, minutes: minutes, seconds: seconds, setPositions: setPositions)
        }
        /// A recurrence that repeats every `interval` months
        public static func monthly(calendar: Calendar, interval: Int = 1, end: End = .never, matchingPolicy: Calendar.MatchingPolicy = .nextTimePreservingSmallerComponents, repeatedTimePolicy: Calendar.RepeatedTimePolicy = .first, months: [Month] = [], daysOfTheMonth: [Int] = [], weekdays: [Weekday] = [], hours: [Int] = [], minutes: [Int] = [], seconds: [Int] = [], setPositions: [Int] = []) -> Self {
            .init(calendar: calendar, frequency: .monthly, interval: interval, end: end, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy, months: months, daysOfTheMonth: daysOfTheMonth, weekdays: weekdays, hours: hours, minutes: minutes, seconds: seconds, setPositions: setPositions)
        }
        /// A recurrence that repeats every `interval` years
        public static func yearly(calendar: Calendar, interval: Int = 1, end: End = .never, matchingPolicy: Calendar.MatchingPolicy = .nextTimePreservingSmallerComponents, repeatedTimePolicy: Calendar.RepeatedTimePolicy = .first, months: [Month] = [], daysOfTheYear: [Int] = [], daysOfTheMonth: [Int] = [], weeks: [Int] = [], weekdays: [Weekday] = [], hours: [Int] = [], minutes: [Int] = [], seconds: [Int] = [], setPositions: [Int] = []) -> Self{
            .init(calendar: calendar, frequency: .yearly, interval: interval, end: end, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy, months: months, daysOfTheYear: daysOfTheYear, daysOfTheMonth: daysOfTheMonth, weeks: weeks, weekdays: weekdays, hours: hours, minutes: minutes, seconds: seconds, setPositions: setPositions)
        }
    }
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
extension Calendar.RecurrenceRule.End: Codable {
    enum CodingKeys: String, CodingKey {
        case count
        case until
    }
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let date = try container.decodeIfPresent(Date.self, forKey: .until) {
            self._guts = .afterDate(date) 
        } else if let count = try container.decodeIfPresent(Int.self,forKey: .count) {
            self._guts = .afterOccurrences(count) 
        } else {
            self._guts = .never
        }
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self._guts {
            case let .afterDate(date):
            try container.encode(date, forKey: .until)
            case let .afterOccurrences(count):
            try container.encode(count, forKey: .count)
            case .never:
            () // An empty object implies .never
        }
    }
}
@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
extension Calendar.RecurrenceRule.Weekday: Codable {
    enum CodingKeys: String, CodingKey {
        case weekday
        case n
    }
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let weekday = try container.decode(Locale.Weekday.self,forKey: .weekday)
        if let n = try container.decodeIfPresent(Int.self,forKey: .n) {
            self = .nth(n, weekday)
        } else {
            self = .every(weekday)
        }
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
            case let .nth(n, weekday):
            try container.encode(n, forKey: .n)
            try container.encode(weekday, forKey: .weekday)
            case let .every(weekday):
            try container.encode(weekday, forKey: .weekday)
        }
    }
}
@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
extension Calendar.RecurrenceRule.Month: Codable {
    enum CodingKeys: String, CodingKey {
        case month
        case leap
    }
    public init(from decoder: any Decoder) throws {
        // Most months are not leap months, so we can save some space if we only
        // serialize the month number when it's not a leap month
        if let month = try? decoder.singleValueContainer().decode(Int.self) {
            self.index = month
            self.isLeap = false
        } else {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.index = try container.decode(Int.self, forKey: .month)
            self.isLeap = try container.decode(Bool.self, forKey: .leap)
        }
    }
    public func encode(to encoder: Encoder) throws {
        if isLeap {
            var container = encoder.container(keyedBy: CodingKeys.self) 
            try container.encode(self.index, forKey: .month)
            try container.encode(self.isLeap, forKey: .leap)
        } else {
            var container = encoder.singleValueContainer()
            try container.encode(self.index)
        }
    }
}
@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
extension Calendar.RecurrenceRule: Codable {
    enum CodingKeys: String, CodingKey {
        case calendar
        case frequency
        case interval
        case end
        case matchingPolicy
        case repeatedTimePolicy
        case months
        case daysOfTheYear
        case daysOfTheMonth
        case weeks
        case weekdays
        case hours
        case minutes
        case seconds
        case setPositions
    }
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.calendar = try container.decode(Calendar.self, forKey: .calendar) 
        self.frequency = try container.decode(Frequency.self, forKey: .frequency) 
        self.interval = try container.decode(Int.self, forKey: .interval) 
        self.end = try container.decode(End.self, forKey: .end) 
        self.matchingPolicy = try container.decode(Calendar.MatchingPolicy.self, forKey: .matchingPolicy) 
        self.repeatedTimePolicy = try container.decode(Calendar.RepeatedTimePolicy.self, forKey: .repeatedTimePolicy) 
        
        self.months         = try container.decode([Month].self, forKey: .months)
        self.daysOfTheYear  = try container.decode([Int].self, forKey: .daysOfTheYear)
        self.daysOfTheMonth = try container.decode([Int].self, forKey: .daysOfTheMonth)
        self.weeks          = try container.decode([Int].self, forKey: .weeks)
        self.weekdays       = try container.decode([Weekday].self, forKey: .weekdays)
        
        self.seconds = try container.decode([Int].self, forKey: .seconds)
        self.minutes = try container.decode([Int].self, forKey: .minutes)
        self.hours   = try container.decode([Int].self, forKey: .hours)
        self.setPositions = try container.decode([Int].self, forKey: .setPositions)
    } 
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(calendar, forKey: .calendar)
        try container.encode(frequency, forKey: .frequency)
        try container.encode(interval, forKey: .interval)
        try container.encode(end, forKey: .end)
        try container.encode(matchingPolicy, forKey: .matchingPolicy)
        try container.encode(repeatedTimePolicy, forKey: .repeatedTimePolicy)
        try container.encode(months, forKey: .months)
        try container.encode(daysOfTheYear, forKey: .daysOfTheYear)
        try container.encode(daysOfTheMonth, forKey: .daysOfTheMonth)
        try container.encode(weeks, forKey: .weeks)
        try container.encode(weekdays, forKey: .weekdays)
        try container.encode(hours, forKey: .hours)
        try container.encode(minutes, forKey: .minutes)
        try container.encode(seconds, forKey: .seconds)
        try container.encode(setPositions, forKey: .setPositions)
    }
}

@available(FoundationPreview 6.0.2, *)
extension Calendar.RecurrenceRule.End: CustomStringConvertible, Hashable {
    public var description: String {
        switch self._guts {
            case .never: "Never"
            case .afterDate(let date): "After \(date)"
            case .afterOccurrences(let n): "After \(n) occurrence(s)"
        }
    }
}
@available(FoundationPreview 6.0.2, *)
extension Calendar.RecurrenceRule.Month: Hashable { }
@available(FoundationPreview 6.0.2, *)
extension Calendar.RecurrenceRule.Weekday: Hashable { }
@available(FoundationPreview 6.0.2, *)
extension Calendar.RecurrenceRule: Hashable { }
