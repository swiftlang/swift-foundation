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

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date {
    /// Options for parsing string representations of dates to create a `Date` instance.
    public struct ParseStrategy : Hashable, Sendable {

        /// Indicates whether to use heuristics when parsing the representation.
        public var isLenient: Bool

        /// The earliest date that can be denoted by a two-digit year specifier.
        public var twoDigitStartDate: Date

        /// The locale to use when parsing date strings with the specified format.
        /// Use system locale if unspecified.
        public var locale: Locale?

        /// The time zone to use for creating the date.
        public var timeZone: TimeZone

        /// The calendar to use when parsing date strings and creating the date.
        public var calendar: Calendar

        /// The string representation of the fixed format conforming to Unicode Technical Standard #35.
        public private(set) var format: String

        /// Creates a new `ParseStrategy` with the given configurations.
        /// - Parameters:
        ///   - format: A fixed format representing the pattern of the date string.
        ///   - locale: The locale of the fixed format.
        ///   - timeZone: The time zone to use for creating the date.
        ///   - isLenient: Whether to use heuristics when parsing the representation.
        ///   - twoDigitStartDate: The earliest date that can be denoted by a two-digit year specifier.
        public init(format: FormatString, locale: Locale? = nil, timeZone: TimeZone, calendar: Calendar = Calendar(identifier: .gregorian), isLenient: Bool = true, twoDigitStartDate: Date = Date(timeIntervalSince1970: 0)) {
            self.init(format: format.rawFormat, locale: locale, timeZone: timeZone, calendar: calendar, isLenient: isLenient, twoDigitStartDate: twoDigitStartDate)
        }

        init(format: String, locale: Locale?, timeZone: TimeZone, calendar: Calendar, isLenient: Bool, twoDigitStartDate: Date) {
            self.locale = locale
            self.timeZone = timeZone
            self.format = format
            self.calendar = calendar
            self.isLenient = isLenient
            self.twoDigitStartDate = twoDigitStartDate
        }

        private var formatter: ICUDateFormatter {
            let dateFormatInfo = ICUDateFormatter.DateFormatInfo(localeIdentifier: locale?.identifier, timeZoneIdentifier: timeZone.identifier, calendarIdentifier: calendar.identifier, firstWeekday: calendar.firstWeekday, minimumDaysInFirstWeek: calendar.minimumDaysInFirstWeek, capitalizationContext: .unknown, pattern: format, parseLenient: isLenient, parseTwoDigitStartDate: twoDigitStartDate)
            return ICUDateFormatter.cachedFormatter(for: dateFormatInfo)
        }

        internal init(formatStyle: Date.FormatStyle, lenient: Bool, twoDigitStartDate: Date = Date(timeIntervalSince1970: 0)) {
            let pattern = ICUPatternGenerator.localizedPatternForSkeleton(localeIdentifier: formatStyle.locale.identifier, calendarIdentifier: formatStyle.calendar.identifier, skeleton: formatStyle.symbols.formatterTemplate, hourCycleOption: .default)
            self.init(format: pattern, locale: formatStyle.locale, timeZone: formatStyle.timeZone, calendar: formatStyle.calendar, isLenient: lenient, twoDigitStartDate: twoDigitStartDate)
        }
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.ParseStrategy : ParseStrategy {
    /// Returns a `Date` of a given string interpreted using the current settings.
    /// - Parameter value: A string representation of a date.
    /// - Throws: Throws `NSFormattingError` if the string cannot be parsed.
    /// - Returns: A `Date` represented by `value`.
    public func parse(_ value: String) throws -> Date {
        guard let date = formatter.parse(value) else {
            throw parseError(value, exampleFormattedString: formatter.format(Date.now))
        }

        return date
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension ParseStrategy {
    static func fixed(format: Date.FormatString, timeZone: TimeZone, locale: Locale? = nil) -> Self where Self == Date.ParseStrategy {
        Date.ParseStrategy(format: format, locale: locale, timeZone: timeZone)
    }
}

// MARK: Regex

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension Date.ParseStrategy : CustomConsumingRegexComponent {
    public typealias RegexOutput = Date
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Date)?  {
        guard index < bounds.upperBound else {
            return nil
        }
        return formatter.parse(input, in: index..<bounds.upperBound)
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension RegexComponent where Self == Date.ParseStrategy {

    public typealias DateStyle = Date.FormatStyle.DateStyle
    public typealias TimeStyle = Date.FormatStyle.TimeStyle

    /// Creates a regex component to match a localized date string following the specified format and capture the string as a `Date`.
    /// - Parameters:
    ///   - format: The date format that describes the localized date string. For example, `"\(month: .twoDigits)_\(day: .twoDigits)_\(year: .twoDigits)"` matches "05_04_22" as May 4th, 2022 in the Gregorian calendar.
    ///   - locale: The locale of the date string to be matched.
    ///   - timeZone: The time zone to create the matched date with.
    ///   - calendar: The calendar with which to interpret the date string. If nil, the default calendar of the specified `locale` is used.
    /// - Returns: A `RegexComponent` to match a localized date string.
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public static func date(format: Date.FormatString, locale: Locale, timeZone: TimeZone, calendar: Calendar? = nil, twoDigitStartDate: Date = Date(timeIntervalSince1970: 0) ) -> Self {
        Date.ParseStrategy(format: format.rawFormat, locale: locale, timeZone: timeZone, calendar: calendar ?? locale.calendar, isLenient: false, twoDigitStartDate: twoDigitStartDate)
    }

    /// Creates a regex component to match a localized date and time string and capture the string as a `Date`. The date string is expected to follow the format of what `Date.FormatStyle(date:time:locale:calendar:)` produces.
    /// - Parameters:
    ///   - date: The style that describes the date part of the string. For example, `.numeric` matches "10/21/2015", and `.abbreviated` matches "Oct 21, 2015" as October 21, 2015 in the `en_US` locale.
    ///   - time: The style that describes the time part of the string.
    ///   - locale: The locale of the string to be matched.
    ///   - timeZone: The time zone to create the matched date with. Ignored if the string contains a time zone and matches the specified style.
    ///   - calendar: The calendar with which to interpret the date string. If set to nil, the default calendar of the specified `locale` is used.
    /// - Returns: A `RegexComponent` to match a localized date string.
    ///
    /// - Note:
    /// If the string contains a time zone and matches the specified style, then the `timeZone` argument is ignored. For example, "Oct 21, 2015 4:29:24 PM PDT" matches `.dateTime(date: .abbreviated, time: .complete, ...)` and is captured as `October 13, 2022, 20:29:24 PDT` regardless of the `timeZone` value.
    public static func dateTime(date: Date.FormatStyle.DateStyle, time: Date.FormatStyle.TimeStyle, locale: Locale, timeZone: TimeZone, calendar: Calendar? = nil) -> Date.ParseStrategy {
        let df = Date.FormatStyle(date: date, time: time, locale: locale, calendar: calendar ?? locale.calendar, timeZone: timeZone)
        return Date.ParseStrategy(formatStyle: df, lenient: false)
    }

    /// Creates a regex component to match a localized date string and capture the string as a `Date`. The string is expected to follow the format of what `Date.FormatStyle(date:locale:calendar:)` produces. `Date` created by this regex component would be at 00:00:00 in the specified time zone.
    /// - Parameters:
    ///   - style: The style that describes the date string. For example, `.numeric` matches "10/21/2015", and `.abbreviated` matches "Oct 21, 2015" as October 21, 2015 in the `en_US` locale. `.omitted` is invalid.
    ///   - locale: The locale of the string to be matched. Generally speaking, the language of the locale is used to parse the date parts if the string contains localized numbers or words, and the region of the locale specifies the order of the date parts. For example, "3/5/2015" represents March 5th, 2015 in `en_US`, but represents May 3rd, 2015 in `en_GB`.
    ///   - timeZone: The time zone to create the matched date with. For example, parsing "Oct 21, 2015" with the PDT time zone returns a date representing October 21, 2015 at 00:00:00 PDT.
    ///   - calendar: The calendar with which to interpret the date string. If nil, the default calendar of the specified `locale` is used.
    /// - Returns: A `RegexComponent` to match a localized date string.
    public static func date(_ style: Date.FormatStyle.DateStyle, locale: Locale, timeZone: TimeZone, calendar: Calendar? = nil) -> Date.ParseStrategy {
        let df = Date.FormatStyle(date: style, locale: locale, calendar: calendar ?? locale.calendar, timeZone: timeZone)
        return Date.ParseStrategy(formatStyle: df, lenient: false)
    }


}
