//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

internal import _FoundationICU

// MARK: Date Extensions

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date {
    /// Converts `self` to its textual representation that contains both the date and time parts. The exact format depends on the user's preferences.
    /// - Parameters:
    ///   - date: The style for describing the date part.
    ///   - time: The style for describing the time part.
    /// - Returns: A `String` describing `self`.
    public func formatted(date: FormatStyle.DateStyle, time: FormatStyle.TimeStyle) -> String {
        let f = FormatStyle(date: date, time: time)
        return f.format(self)
    }

    public func formatted() -> String {
        self.formatted(Date.FormatStyle(date: .numeric, time: .shortened))
    }
}

// MARK: DateFieldCollection

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.FormatStyle {
    internal struct DateFieldCollection : Codable, Hashable {
        var era: Symbol.SymbolType.EraOption?
        var year: Symbol.SymbolType.YearOption?
        var quarter: Symbol.SymbolType.QuarterOption?
        var month: Symbol.SymbolType.MonthOption?
        var week: Symbol.SymbolType.WeekOption?
        var day: Symbol.SymbolType.DayOption?
        var dayOfYear: Symbol.SymbolType.DayOfYearOption?
        var weekday: Symbol.SymbolType.WeekdayOption?
        var dayPeriod: Symbol.SymbolType.DayPeriodOption?
        var hour: Symbol.SymbolType.HourOption?
        var minute: Symbol.SymbolType.MinuteOption?
        var second: Symbol.SymbolType.SecondOption?
        var secondFraction: Symbol.SymbolType.SecondFractionOption?
        var timeZoneSymbol: Symbol.SymbolType.TimeZoneSymbolOption?

        // Swap regular hour for conversational-style hour option if needed
        func preferredHour(withLocale locale: Locale?) -> Symbol.SymbolType.HourOption? {
            guard let hour, let locale else {
                return nil
            }

            var showingDayPeriod: Bool
            switch locale.hourCycle {
            case .zeroToEleven:
                showingDayPeriod = true
            case .oneToTwelve:
                showingDayPeriod = true
            case .zeroToTwentyThree:
                showingDayPeriod = false
            case .oneToTwentyFour:
                showingDayPeriod = false
            }

            // default options (template "J" or "j") may display the hour as
            // 12-hour and 24-hour depending on regional preferences, while
            // conversational options (template "C") always shows 12-hour.
            // Only proceed to override J/j with C if displaying 12-hour.
            guard showingDayPeriod else {
                return hour
            }

            var preferredHour: Symbol.SymbolType.HourOption?

            if locale.language.languageCode == .chinese && locale.region == .taiwan {
                switch hour {
                case .defaultDigitsWithAbbreviatedAMPM:
                    preferredHour = .conversationalDefaultDigitsWithAbbreviatedAMPM
                case .twoDigitsWithAbbreviatedAMPM:
                    preferredHour = .conversationalTwoDigitsWithAbbreviatedAMPM
                case .defaultDigitsWithWideAMPM:
                    preferredHour = .conversationalDefaultDigitsWithWideAMPM
                case .twoDigitsWithWideAMPM:
                    preferredHour = .conversationalTwoDigitsWithWideAMPM
                case .defaultDigitsWithNarrowAMPM:
                    preferredHour = .conversationalDefaultDigitsWithNarrowAMPM
                case .twoDigitsWithNarrowAMPM:
                    preferredHour = .conversationalTwoDigitsWithNarrowAMPM
                case .defaultDigitsNoAMPM, .twoDigitsNoAMPM, .conversationalDefaultDigitsWithAbbreviatedAMPM, .conversationalTwoDigitsWithAbbreviatedAMPM, .conversationalDefaultDigitsWithWideAMPM, .conversationalTwoDigitsWithWideAMPM, .conversationalDefaultDigitsWithNarrowAMPM, .conversationalTwoDigitsWithNarrowAMPM:
                    preferredHour = hour
                }
            } else {
                preferredHour = hour
            }

            return preferredHour
        }

        func formatterTemplate(overridingDayPeriodWithLocale locale: Locale?) -> String {
            var ret = ""
            ret.append(era?.rawValue ?? "")
            ret.append(year?.rawValue ?? "")
            ret.append(quarter?.rawValue ?? "")
            ret.append(month?.rawValue ?? "")
            ret.append(week?.rawValue ?? "")
            ret.append(day?.rawValue ?? "")
            ret.append(dayOfYear?.rawValue ?? "")
            ret.append(weekday?.rawValue ?? "")
            ret.append(dayPeriod?.rawValue ?? "")
            let preferredHour = preferredHour(withLocale: locale)
            ret.append(preferredHour?.rawValue ?? "")
            ret.append(minute?.rawValue ?? "")
            ret.append(second?.rawValue ?? "")
            ret.append(secondFraction?.rawValue ?? "")
            ret.append(timeZoneSymbol?.rawValue ?? "")
            return ret
        }

        // Only contains fields greater or equal than `day`, excluding time parts.
        var dateFields: Self {
            DateFieldCollection(era: era, year: year, quarter: quarter, month: month, week: week, day: day, dayOfYear: dayOfYear, weekday: weekday, dayPeriod: dayPeriod)
        }

        mutating func add(_ rhs: Self) {
            era = rhs.era ?? era
            year = rhs.year ?? year
            quarter = rhs.quarter ?? quarter
            month = rhs.month ?? month
            week = rhs.week ?? week
            day = rhs.day ?? day
            dayOfYear = rhs.dayOfYear ?? dayOfYear
            weekday = rhs.weekday ?? weekday
            dayPeriod = rhs.dayPeriod ?? dayPeriod
            hour = rhs.hour ?? hour
            minute = rhs.minute ?? minute
            second = rhs.second ?? second
            secondFraction = rhs.secondFraction ?? secondFraction
            timeZoneSymbol = rhs.timeZoneSymbol ?? timeZoneSymbol
        }

        var empty: Bool {
            if era == nil &&
                year == nil &&
                quarter == nil &&
                month == nil &&
                week == nil &&
                day == nil &&
                dayOfYear == nil &&
                weekday == nil &&
                dayPeriod == nil &&
                hour == nil &&
                minute == nil &&
                second == nil &&
                secondFraction == nil &&
                timeZoneSymbol == nil {
                return true
            } else {
                return false
            }
        }

        func collection(date len: DateStyle)-> DateFieldCollection {
            var new = self
            if len == .omitted {
                return new
            }

            new.day = .defaultDigits
            new.year = .defaultDigits
            if len == .numeric {
                new.month = .defaultDigits
            } else if len == .abbreviated {
                new.month = .abbreviated
            } else if len == .long {
                new.month = .wide
            } else if len == .complete {
                new.month = .wide
                new.weekday = .wide
            }
            return new
        }

        func collection(time len: TimeStyle) -> DateFieldCollection {
            var new = self
            if len == .omitted {
                return new
            }

            new.hour = .defaultDigitsWithAbbreviatedAMPM
            new.minute = .twoDigits
            if len == .standard {
                new.second = .twoDigits
            } else if len == .complete {
                new.second = .twoDigits
                new.timeZoneSymbol = .shortSpecificName
            }
            return new
        }
    }
}

// MARK: Date.FormatStyle Definition

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date {
    /// Strategies for formatting a `Date`.
    public struct FormatStyle : Sendable {

        var _symbols: DateFieldCollection?
        var symbols: DateFieldCollection {
            if let _symbols {
                return _symbols
            }

            return DateFieldCollection().collection(date: .numeric).collection(time: .shortened)
        }

        var _dateStyle: DateStyle? // For accessing locale pref's custom date format

        /// The locale to use when formatting date and time values.
        public var locale: Locale

        /// The time zone with which to specify date and time values.
        public var timeZone: TimeZone

        /// The calendar to use for date values.
        public var calendar: Calendar

        /// The capitalization formatting context used when formatting date and time values.
        public var capitalizationContext: FormatStyleCapitalizationContext

        /// Returns a type erased attributed variant of this style.
        @available(macOS, deprecated: 15, introduced: 12, message: "Use attributedStyle instead")
        @available(iOS, deprecated: 18, introduced: 15, message: "Use attributedStyle instead")
        @available(tvOS, deprecated: 18, introduced: 15, message: "Use attributedStyle instead")
        @available(watchOS, deprecated: 11, introduced: 8, message: "Use attributedStyle instead")
        public var attributed: AttributedStyle {
            .init(style: .formatStyle(self))
        }

        var parseLenient: Bool = true

        /// Creates a new `FormatStyle` with the given configurations.
        /// - Parameters:
        ///   - date:  The date style for formatting the date.
        ///   - time:  The time style for formatting the date.
        ///   - locale: The locale to use when formatting date and time values.
        ///   - calendar: The calendar to use for date values.
        ///   - timeZone: The time zone with which to specify date and time values.
        ///   - capitalizationContext: The capitalization formatting context used when formatting date and time values.
        /// - Note: Always specify the date style, time style, or the date components to be included in the formatted string with the symbol modifiers. Otherwise, an empty string will be returned when you use the instance to format a `Date`.
        public init(date: DateStyle? = nil, time: TimeStyle? = nil, locale: Locale = .autoupdatingCurrent, calendar: Calendar = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent, capitalizationContext: FormatStyleCapitalizationContext = .unknown) {
            if let dateStyle = date, dateStyle != .omitted {
                _dateStyle = dateStyle
                _symbols = (_symbols ?? .init()).collection(date: dateStyle)
            }

            if let timeStyle = time, timeStyle != .omitted {
                _symbols = (_symbols ?? .init()).collection(time: timeStyle)
            }

            self.locale = locale
            self.calendar = calendar
            self.timeZone = timeZone
            self.capitalizationContext = capitalizationContext
        }

        private init(symbols: DateFieldCollection, dateStyle: DateStyle?, locale: Locale, timeZone: TimeZone, calendar: Calendar, capitalizationContext: FormatStyleCapitalizationContext) {
            self._symbols = symbols
            self._dateStyle = dateStyle
            self.locale = locale
            self.timeZone = timeZone
            self.calendar = calendar
            self.capitalizationContext = capitalizationContext
        }
    }

    // MARK: Type-Erased AttributedStyle

    @available(macOS, deprecated: 15, introduced: 12, message: "Use Date.FormatStyle.Attributed or Date.VerbatimFormatStyle.Attributed instead")
    @available(iOS, deprecated: 18, introduced: 15, message: "Use Date.FormatStyle.Attributed or Date.VerbatimFormatStyle.Attributed instead")
    @available(tvOS, deprecated: 18, introduced: 15, message: "Use Date.FormatStyle.Attributed or Date.VerbatimFormatStyle.Attributed instead")
    @available(watchOS, deprecated: 11, introduced: 8, message: "Use Date.FormatStyle.Attributed or Date.VerbatimFormatStyle.Attributed instead")
    public struct AttributedStyle : Sendable {

        enum InnerStyle: Codable, Hashable {
            case formatStyle(Date.FormatStyle)
            case verbatimFormatStyle(VerbatimFormatStyle)
            
            private typealias FormatStyleCodingKeys = DefaultAssociatedValueCodingKeys1
            private typealias VerbatimFormatStyleCodingKeys = DefaultAssociatedValueCodingKeys1
        }
        
        var innerStyle: InnerStyle

        init(style: InnerStyle) {
            self.innerStyle = style
        }

        /// Returns an attributed string with `AttributeScopes.FoundationAttributes.DateFieldAttribute`
        public func format(_ value: Date) -> AttributedString {
            let fm: ICUDateFormatter?
            switch innerStyle {
            case .formatStyle(let formatStyle):
                fm = ICUDateFormatter.cachedFormatter(for: formatStyle)
            case .verbatimFormatStyle(let verbatimFormatStyle):
                fm = ICUDateFormatter.cachedFormatter(for: verbatimFormatStyle)
            }

            guard let fm, let (str, attributes) = fm.attributedFormat(value) else {
                return AttributedString("")
            }
            
            return str._attributedStringFromPositions(attributes)
        }

        public func locale(_ locale: Locale) -> Self {
            var newInnerStyle: InnerStyle

            switch innerStyle {
            case .formatStyle(let style):
                newInnerStyle = .formatStyle(style.locale(locale))
            case .verbatimFormatStyle(let style):
                newInnerStyle = .verbatimFormatStyle(style.locale(locale))
            }

            var new = self
            new.innerStyle = newInnerStyle
            return new
        }
    }
}

@available(macOS, deprecated: 15, introduced: 12, message: "Use Date.FormatStyle.Attributed or Date.VerbatimFormatStyle.Attributed instead")
@available(iOS, deprecated: 18, introduced: 15, message: "Use Date.FormatStyle.Attributed or Date.VerbatimFormatStyle.Attributed instead")
@available(tvOS, deprecated: 18, introduced: 15, message: "Use Date.FormatStyle.Attributed or Date.VerbatimFormatStyle.Attributed instead")
@available(watchOS, deprecated: 11, introduced: 8, message: "Use Date.FormatStyle.Attributed or Date.VerbatimFormatStyle.Attributed instead")
extension Date.AttributedStyle : FormatStyle {}

// MARK: Typed Attributed Style

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
extension Date.FormatStyle {
    /// The type preserving attributed variant of this style.
    ///
    /// This style attributes the formatted date with the `AttributeScopes.FoundationAttributes.DateFormatFieldAttribute`.
    @dynamicMemberLookup
    public struct Attributed : FormatStyle, Sendable {
        var base: Date.FormatStyle

        public subscript<T>(dynamicMember key: KeyPath<Date.FormatStyle, T>) -> T {
            base[keyPath: key]
        }

        public subscript<T>(dynamicMember key: WritableKeyPath<Date.FormatStyle, T>) -> T {
            get {
                base[keyPath: key]
            }
            set {
                base[keyPath: key] = newValue
            }
        }

        init(style: Date.FormatStyle) {
            self.base = style
        }

        public func format(_ value: Date) -> AttributedString {
            guard let fm = ICUDateFormatter.cachedFormatter(for: base), let (str, attributes) = fm.attributedFormat(value) else {
                return AttributedString("")
            }
            return str._attributedStringFromPositions(attributes)
        }

        public func locale(_ locale: Locale) -> Self {
            var new = self
            new.base = base.locale(locale)
            return new
        }
    }

    /// Return the type preserving attributed variant of this style.
    ///
    /// This style attributes the formatted date with the `AttributeScopes.FoundationAttributes.DateFormatFieldAttribute`.
    public var attributedStyle: Attributed {
        .init(style: self)
    }
}

// MARK: Symbol Modifiers

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.FormatStyle {
    /// Change the representation of the era in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func era(_ format: Symbol.Era = .abbreviated) -> Self {
        var new = self
        if new._symbols == nil {
            new._symbols = format.option == nil ? new.symbols : .init()
        }
        new._symbols?.era = format.option
        return new
    }

    /// Change the representation of the year in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func year(_ format: Symbol.Year = .defaultDigits) -> Self {
        var new = self
        if new._symbols == nil {
            new._symbols = format.option == nil ? new.symbols : .init()
        }
        new._symbols?.year = format.option
        return new
    }

    /// Change the representation of the quarter in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func quarter(_ format: Symbol.Quarter = .abbreviated) -> Self {
        var new = self
        if new._symbols == nil {
            new._symbols = format.option == nil ? new.symbols : .init()
        }
        new._symbols?.quarter = format.option
        return new
    }

    /// Change the representation of the month in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func month(_ format: Symbol.Month = .abbreviated) -> Self {
        var new = self
        if new._symbols == nil {
            new._symbols = format.option == nil ? new.symbols : .init()
        }
        new._symbols?.month = format.option
        return new
    }

    /// Change the representation of the week in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func week(_ format: Symbol.Week = .defaultDigits) -> Self {
        var new = self
        if new._symbols == nil {
            new._symbols = format.option == nil ? new.symbols : .init()
        }
        new._symbols?.week = format.option
        return new
    }

    /// Change the representation of the day of the month in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func day(_ format: Symbol.Day = .defaultDigits) -> Self {
        var new = self
        if new._symbols == nil {
            new._symbols = format.option == nil ? new.symbols : .init()
        }
        new._symbols?.day = format.option
        return new
    }

    /// Change the representation of the day of the year in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func dayOfYear(_ format: Symbol.DayOfYear = .defaultDigits) -> Self {
        var new = self
        if new._symbols == nil {
            new._symbols = format.option == nil ? new.symbols : .init()
        }
        new._symbols?.dayOfYear = format.option
        return new
    }

    /// Change the representation of the weekday in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func weekday(_ format: Symbol.Weekday = .abbreviated) -> Self {
        var new = self
        if new._symbols == nil {
            new._symbols = format.option == nil ? new.symbols : .init()
        }
        new._symbols?.weekday = format.option
        return new
    }

    /// Change the representation of the hour in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func hour(_ format: Symbol.Hour = .defaultDigits(amPM: .abbreviated)) -> Self {
        var new = self
        if new._symbols == nil {
            new._symbols = format.option == nil ? new.symbols : .init()
        }
        new._symbols?.hour = format.option
        return new
    }

    /// Change the representation of the minute in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func minute(_ format: Symbol.Minute = .defaultDigits) -> Self {
        var new = self
        if new._symbols == nil {
            new._symbols = format.option == nil ? new.symbols : .init()
        }
        new._symbols?.minute = format.option
        return new
    }

    /// Change the representation of the second in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func second(_ format: Symbol.Second = .defaultDigits) -> Self {
        var new = self
        if new._symbols == nil {
            new._symbols = format.option == nil ? new.symbols : .init()
        }
        new._symbols?.second = format.option
        return new
    }

    /// Change the representation of the second fraction in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func secondFraction(_ format: Symbol.SecondFraction) -> Self {
        var new = self
        if new._symbols == nil {
            new._symbols = format.option == nil ? new.symbols : .init()
        }
        new._symbols?.secondFraction = format.option
        return new
    }

    /// Change the representation of the time zone in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func timeZone(_ format: Symbol.TimeZone = .specificName(.short)) -> Self {
        var new = self
        if new._symbols == nil {
            new._symbols = format.option == nil ? new.symbols : .init()
        }
        new._symbols?.timeZoneSymbol = format.option
        return new
    }
}

// MARK: Symbol Modifiers Attributed Style

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
extension Date.FormatStyle.Attributed {
    /// Change the representation of the era in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func era(_ format: Date.FormatStyle.Symbol.Era = .abbreviated) -> Self {
        var new = self
        new.base = base.era(format)
        return new
    }

    /// Change the representation of the year in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func year(_ format: Date.FormatStyle.Symbol.Year = .defaultDigits) -> Self {
        var new = self
        new.base = base.year(format)
        return new
    }

    /// Change the representation of the quarter in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func quarter(_ format: Date.FormatStyle.Symbol.Quarter = .abbreviated) -> Self {
        var new = self
        new.base = base.quarter(format)
        return new
    }

    /// Change the representation of the month in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func month(_ format: Date.FormatStyle.Symbol.Month = .abbreviated) -> Self {
        var new = self
        new.base = base.month(format)
        return new
    }

    /// Change the representation of the week in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func week(_ format: Date.FormatStyle.Symbol.Week = .defaultDigits) -> Self {
        var new = self
        new.base = base.week(format)
        return new
    }

    /// Change the representation of the day of the month in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func day(_ format: Date.FormatStyle.Symbol.Day = .defaultDigits) -> Self {
        var new = self
        new.base = base.day(format)
        return new
    }

    /// Change the representation of the day of the year in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func dayOfYear(_ format: Date.FormatStyle.Symbol.DayOfYear = .defaultDigits) -> Self {
        var new = self
        new.base = base.dayOfYear(format)
        return new
    }

    /// Change the representation of the weekday in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func weekday(_ format: Date.FormatStyle.Symbol.Weekday = .abbreviated) -> Self {
        var new = self
        new.base = base.weekday(format)
        return new
    }

    /// Change the representation of the hour in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func hour(_ format: Date.FormatStyle.Symbol.Hour = .defaultDigits(amPM: .abbreviated)) -> Self {
        var new = self
        new.base = base.hour(format)
        return new
    }

    /// Change the representation of the minute in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func minute(_ format: Date.FormatStyle.Symbol.Minute = .defaultDigits) -> Self {
        var new = self
        new.base = base.minute(format)
        return new
    }

    /// Change the representation of the second in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func second(_ format: Date.FormatStyle.Symbol.Second = .defaultDigits) -> Self {
        var new = self
        new.base = base.second(format)
        return new
    }

    /// Change the representation of the second fraction in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func secondFraction(_ format: Date.FormatStyle.Symbol.SecondFraction) -> Self {
        var new = self
        new.base = base.secondFraction(format)
        return new
    }

    /// Change the representation of the time zone in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func timeZone(_ format: Date.FormatStyle.Symbol.TimeZone = .specificName(.short)) -> Self {
        var new = self
        new.base = base.timeZone(format)
        return new
    }
}

// MARK: FormatStyle Conformance

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.FormatStyle : FormatStyle {
    public func format(_ value: Date) -> String {
        guard let fm = ICUDateFormatter.cachedFormatter(for: self), let result = fm.format(value) else {
            return ""
        }
        return result
    }

    public func locale(_ locale: Locale) -> Self {
        var new = self
        new.locale = locale
        return new
    }
}

// MARK: ParseStrategy Conformance

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.FormatStyle : ParseStrategy {
    public func parse(_ value: String) throws -> Date {
        guard let fm = ICUDateFormatter.cachedFormatter(for: self) else {
            throw CocoaError(CocoaError.formatting, userInfo: [ NSDebugDescriptionErrorKey: "Error creating icu date formatter" ])
        }

        guard let date = fm.parse(value) else {
            throw parseError(value, exampleFormattedString: fm.format(Date.now))
        }

        return date
    }
}

// MARK: Codable+Hashable Conformance

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.FormatStyle : Codable, Hashable {

    enum CodingKeys: CodingKey {
        case symbols
        case locale
        case timeZone
        case calendar
        case capitalizationContext
        case dateStyle
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.symbols, forKey: .symbols)
        try container.encode(self.locale, forKey: .locale)
        try container.encode(self.timeZone, forKey: .timeZone)
        try container.encode(self.calendar, forKey: .calendar)
        try container.encode(self.capitalizationContext, forKey: .capitalizationContext)
        try container.encodeIfPresent(self._dateStyle, forKey: .dateStyle)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let symbols = try container.decode(DateFieldCollection.self, forKey: .symbols)
        let locale = try container.decode(Locale.self, forKey: .locale)
        let timeZone = try container.decode(TimeZone.self, forKey: .timeZone)
        let calendar = try container.decode(Calendar.self, forKey: .calendar)
        let context = try container.decode(FormatStyleCapitalizationContext.self, forKey: .capitalizationContext)
        let dateStyle = try container.decodeIfPresent(DateStyle.self, forKey: .dateStyle)
        self.init(symbols: symbols, dateStyle: dateStyle, locale: locale, timeZone: timeZone, calendar: calendar, capitalizationContext: context)
    }
}

// MARK: Date/Time Style

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.FormatStyle {
    /// Predefined date styles varied in lengths or the components included. The exact format depends on the locale.
    public struct DateStyle : Codable, Hashable, Sendable {

        /// Excludes the date part.
        public static let omitted: DateStyle = DateStyle(rawValue: 0)

        /// Shows date components in their numeric form. For example, "10/21/2015".
        public static let numeric: DateStyle = DateStyle(rawValue: 1)

        /// Shows date components in their abbreviated form if possible. For example, "Oct 21, 2015".
        public static let abbreviated: DateStyle = DateStyle(rawValue: 2)

        /// Shows date components in their long form if possible. For example, "October 21, 2015".
        public static let long: DateStyle = DateStyle(rawValue: 3)

        /// Shows the complete day. For example, "Wednesday, October 21, 2015".
        public static let complete: DateStyle = DateStyle(rawValue: 4)

        let rawValue : UInt
    }

    /// Predefined time styles varied in lengths or the components included. The exact format depends on the locale.
    public struct TimeStyle : Codable, Hashable, Sendable {

        /// Excludes the time part.
        public static let omitted: TimeStyle = TimeStyle(rawValue: 0)

        /// For example, `04:29 PM`, `16:29`.
        public static let shortened: TimeStyle = TimeStyle(rawValue: 1)

        /// For example, `4:29:24 PM`, `16:29:24`.
        public static let standard: TimeStyle = TimeStyle(rawValue: 2)

        /// For example, `4:29:24 PM PDT`, `16:29:24 GMT`.
        public static let complete: TimeStyle = TimeStyle(rawValue: 3)

        let rawValue : UInt
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.FormatStyle: ParseableFormatStyle {
    public var parseStrategy: Date.FormatStyle {
        return self
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == Date.FormatStyle {
    static var dateTime: Self { .init() }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension ParseableFormatStyle where Self == Date.FormatStyle {
    static var dateTime: Self { .init() }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension ParseStrategy where Self == Date.FormatStyle {
    @_disfavoredOverload
    static var dateTime: Self { .init() }
}

// MARK: DiscreteFormatStyle Conformance

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
extension Date.FormatStyle : DiscreteFormatStyle {
    public func discreteInput(before input: Date) -> Date? {
        guard let (bound, isIncluded) = bound(for: input, isLower: true) else {
            return nil
        }

        return isIncluded ? bound.nextDown : bound
    }

    public func discreteInput(after input: Date) -> Date? {
        guard let (bound, isIncluded) = bound(for: input, isLower: false) else {
            return nil
        }

        return isIncluded ? bound.nextUp : bound
    }

    func bound(for input: Date, isLower: Bool) -> (bound: Date, includedInRangeOfInput: Bool)? {
        var calendar = calendar
        calendar.timeZone = timeZone
        return calendar.bound(for: input, isLower: isLower, updateSchedule: ICUDateFormatter.DateFormatInfo.cachedUpdateSchedule(for: self))
    }

    public func input(before input: Date) -> Date? {
        let result = Calendar.nextAccuracyStep(for: input, direction: .backward)

        return result < input ? result : nil
    }

    public func input(after input: Date) -> Date? {
        let result = Calendar.nextAccuracyStep(for: input, direction: .forward)

        return result > input ? result : nil
    }
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
extension Date.FormatStyle.Attributed : DiscreteFormatStyle {
    public func discreteInput(before input: Date) -> Date? {
        base.discreteInput(before: input)
    }

    public func discreteInput(after input: Date) -> Date? {
        base.discreteInput(after: input)
    }

    public func input(before input: Date) -> Date? {
        base.input(before: input)
    }

    public func input(after input: Date) -> Date? {
        base.input(after: input)
    }
}

extension Calendar {
    /// Gives an approximation for how inaccurate `date` might be in either `direction` if it was produced
    /// by `bound(for:isLower:updateSchedule)`.
    static func nextAccuracyStep(for date: Date, direction: Calendar.SearchDirection) -> Date {
        let conversionLoss = abs(date.timeIntervalSince(date.nextDown)) + abs(date.timeIntervalSince(Date(udate: date.udate.nextDown)))
        // 9 was determined by experimentation, but seems to be the maximum
        // number of conversions between `Date` and `Udate` that can happen when
        // calling `bound(for:isLower:updateSchedule)`
        let inaccuracy = 9 * conversionLoss
        return direction == .backward ? date - inaccuracy : date + inaccuracy
    }

    func bound(for input: Date, isLower: Bool, updateSchedule: ICUDateFormatter.DateFormatInfo.UpdateSchedule) -> (bound: Date, includedInRangeOfInput: Bool)? {
        let zeroDate = self.date(from: .init()) ?? Date(timeIntervalSince1970: 0)

        let towardZero = isLower ? input > zeroDate : input < zeroDate

        var bound: Date?

        for (component, multitude) in updateSchedule.updateIntervals {
            if let next = self.advance(input, isLower ? .backward : .forward, by: multitude, component) {
                if let prev = bound {
                    bound = isLower ? max(next, prev) : min(next, prev)
                } else {
                    bound = next
                }
            }
        }

        guard let bound else {
            return nil
        }

        return (bound, bound == input || towardZero)
    }

    private func advance(_ date: Date, _ direction: Calendar.SearchDirection, by value: Int, _ component: Component) -> Date? {
        guard component != .nanosecond else {
            // We work with the UDate here because we have to mimic the floating
            // point rounding behavior of the ICU calendar, which is used by the
            // ICU formatting logic. _Calendar_ICU has a special case for
            // implementation for `.nanosecond` in which it does not actually
            // use ICU to calculate the value, but does manual math on `Date`
            // instead. We explicitly opt out of that special case handling and
            // implement our own version of what ICU's calendar would do.
            let udate = date.udate

            let increment = 1e-6 * Double(value)

            let floored = min((udate / increment).rounded(.down) * increment, udate)

            switch direction {
            case .forward:
                return max(Date(udate: floored + increment), date)
            case .backward:
                return min(Date(udate: floored), date)
            }
        }

        // Calendar.date(byAdding:value:to:) doesn't work with .era, so we just
        // use nextDate, even though that often yields inprecise results when
        // doing big jumps.
        guard component != .era else {
            guard let era = self.dateComponents([.era], from: date).era else {
                return nil
            }

            return self.nextDate(
                after: date,
                matching: .init(era: direction == .backward ? era - value : era + value),
                matchingPolicy: .nextTime,
                direction: direction)
        }

        if direction == .backward {
            // If we're searching for an earlier date, we first skip one whole
            // component into the past, so we can then search for the start of
            // the next component, which is the start of the original component,
            // i.e. exactly what we want.
            // `Calendar.nextDate(after:matching)` does have a `direction` option,
            // but putting that to `.backward` would give us the _start_ of the
            // previous component, not the _end_.
            guard let shiftedDate = self.date(byAdding: component, value: -value, to: date) else {
                return nil
            }

            var dateComponents = DateComponents()
            dateComponents.setValue(self.dateComponents([component], from: date).value(for: component), for: component)

            guard let prevDate = self.nextDate(after: shiftedDate, matching: dateComponents, matchingPolicy: .nextTime) else {
                return nil
            }

            return prevDate
        } else {
            // If we're searching for a later date, `Calendar.nextDate(after:matching)`
            // gives us exactly what we want, we just have to make sure we pass
            // a valid target value. E.g. we cannot pass a target of 60 seconds,
            // but have to manually calculate the modulo based on
            // `Calendar.range(of:in:for:)`.
            let currentValue = self.component(component, from: date)
            let additiveValue = currentValue + value

            let targetValue: Int

            if let higherComponent = component.nextHigherUnit,
               let validRange = self.range(of: component, in: higherComponent, for: date), !validRange.isEmpty {

                if additiveValue >= validRange.upperBound {
                    targetValue = validRange.lowerBound + (additiveValue % validRange.upperBound)
                } else {
                    targetValue = additiveValue
                }
            } else {
                targetValue = additiveValue
            }

            var components = DateComponents()
            components.setValue(targetValue, for: component)

            return self.nextDate(after: date, matching: components, matchingPolicy: .nextTime)
        }
    }
}

// MARK: Utils

extension AttributeScopes.FoundationAttributes.DateFieldAttribute.Field {
    init?(udateFormatField: UDateFormatField) {
        switch udateFormatField {
        case .era:
            self = .era
        case .year:
            self = .year
        case .month:
            self = .month
        case .date:
            self = .day
        case .hourOfDay1:
            self = .hour // "k"
        case .hourOfDay0:
            self = .hour // "H"
        case .minute:
            self = .minute
        case .second:
            self = .second
        case .fractionalSecond:
            self = .secondFraction
        case .dayOfWeek:
            self = .weekday // "E"
        case .dayOfYear:
            self = .dayOfYear // "D"
        case .dayOfWeekInMonth:
            self = .weekdayOrdinal // "F"
        case .weekOfYear:
            self = .weekOfYear
        case .weekOfMonth:
            self = .weekOfMonth
        case .amPm:
            self = .amPM
        case .hour1:
            self = .hour
        case .hour0:
            self = .hour
        case .timezone:
            self = .timeZone
        case .yearWoy:
            self = .year
        case .dowLocal:
            self = .weekday // "e"
        case .extendedYear:
            self = .year
        case .julianDay:
            self = .day
        case .millisecondsInDay:
            self = .second
        case .timezoneRfc:
            self = .timeZone
        case .timezoneGeneric:
            self = .timeZone
        case .standaloneDay:
            self = .weekday // "c": day of week number/name
        case .standaloneMonth:
            self = .month
        case .standaloneQuarter:
            self = .quarter
        case .quarter:
            self = .quarter
        case .timezoneSpecial:
            self = .timeZone
        case .yearName:
            self = .year
        case .timezoneLocalizedGmtOffset:
            self = .timeZone
        case .timezoneIso:
            self = .timeZone
        case .timezoneIsoLocal:
            self = .timeZone
        case .amPmMidnightNoon:
            self = .amPM
        case .flexibleDayPeriod:
            self = .amPM
        default:
            return nil
        }
    }
}


@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension Date.FormatStyle : CustomConsumingRegexComponent {
    public typealias RegexOutput = Date
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Date)? {
        guard index < bounds.upperBound else {
            return nil
        }
        guard let fmt = ICUDateFormatter.cachedFormatter(for: self) else {
            return nil
        }
        return fmt.parse(input, in: index..<bounds.upperBound)
    }
}

extension String {
    func _attributedStringFromPositions(_ positions: [ICUDateFormatter.AttributePosition]) -> AttributedString {
        typealias DateFieldAttribute = AttributeScopes.FoundationAttributes.DateFieldAttribute.Field

        var attrstr = AttributedString(self)
        for attr in positions {
            let strRange = String.Index(utf16Offset: attr.begin, in: self) ..<
                String.Index(utf16Offset: attr.end, in: self)
            let range = Range<AttributedString.Index>(strRange, in: attrstr)!

            let field = attr.field
            var container = AttributeContainer()
            if let dateField = DateFieldAttribute(udateFormatField: field) {
                container.dateField = dateField
            }
            attrstr[range].mergeAttributes(container)
        }

        return attrstr
    }
}
