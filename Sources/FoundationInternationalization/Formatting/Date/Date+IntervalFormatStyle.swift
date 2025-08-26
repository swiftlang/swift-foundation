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

extension Date {

    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public struct IntervalFormatStyle : Codable, Hashable, Sendable {

        public typealias DateStyle = Date.FormatStyle.DateStyle
        public typealias TimeStyle = Date.FormatStyle.TimeStyle

        public var locale: Locale
        public var timeZone: TimeZone
        public var calendar: Calendar

        // Internal
        internal var symbols =  Date.FormatStyle.DateFieldCollection()

        /// Creates a new `FormatStyle` with the given configurations.
        /// - Parameters:
        ///   - date: The style for formatting the date part of the given date pairs. Note that if `.omitted` is specified, but the date interval spans more than one day, a locale-specific fallback will be used.
        ///   - time: The style for formatting the time part of the given date pairs.
        ///   - locale: The locale to use when formatting date and time values.
        ///   - calendar: The calendar to use for date values.
        ///   - timeZone: The time zone with which to specify date and time values.
        /// - Important: Always specify the date length, time length, or the date components to be included in the formatted string with the symbol modifiers. Otherwise, an empty string will be returned when you use the instance to format an object.
        /// - Note: If specifying the date fields, and the `DateInterval` range is larger than the specified units, a locale-specific fallback will be used.
        ///     - Example: for the range 2010-03-04 07:56 - 2010-03-08 16:11 (4 days, 8 hours, 15 minutes), specifying `.hour().minute()` will produce
        ///         - for en_US, "3/4/2010 7:56 AM - 3/8/2010 4:11 PM"
        ///         - for en_GB, "4/3/2010 7:56 - 8/3/2010 16:11"
        public init(date: DateStyle? = nil, time: TimeStyle? = nil, locale: Locale = .autoupdatingCurrent, calendar: Calendar = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent) {
            self.locale = locale
            self.calendar = calendar
            self.timeZone = timeZone
            if let dateStyle = date {
                self.symbols = self.symbols.collection(date: dateStyle)
            }
            if let timeStyle = time {
                self.symbols = self.symbols.collection(time: timeStyle)
            }
        }

        // MARK: - FormatStyle conformance

        public func format(_ v: Range<Date>) -> String {
            guard let formatter = ICUDateIntervalFormatter.formatter(for: self), let result = formatter.string(from: v) else {
                return "\(v.lowerBound.description) - \(v.upperBound.description)"
            }
            return result
        }

        public func locale(_ locale: Locale) -> Self {
            var new = self
            new.locale = locale
            return new
        }
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.IntervalFormatStyle : FormatStyle {}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.IntervalFormatStyle {

    public typealias Symbol = Date.FormatStyle.Symbol

    public func year() -> Self {
        var new = self
        new.symbols.year = .defaultDigits
        return new
    }

    public func month(_ format: Symbol.Month = .abbreviated) -> Self {
        var new = self
        new.symbols.month = format.option
        return new
    }

    public func day() -> Self {
        var new = self
        new.symbols.day = .defaultDigits
        return new
    }

    public func weekday(_ format: Symbol.Weekday = .abbreviated) -> Self {
        var new = self
        new.symbols.weekday = format.option
        return new
    }

    public func hour(_ format: Symbol.Hour = .defaultDigits(amPM: .abbreviated)) -> Self {
        var new = self
        new.symbols.hour = format.option
        return new
    }

    public func minute() -> Self {
        var new = self
        new.symbols.minute = .defaultDigits
        return new
    }

    public func second() -> Self {
        var new = self
        new.symbols.second = .defaultDigits
        return new
    }

    public func timeZone(_ format: Symbol.TimeZone = .genericName(.short)) -> Self {
        var new = self
        new.symbols.timeZoneSymbol = format.option
        return new
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == Date.IntervalFormatStyle {
    static var interval: Self {
        return Date.IntervalFormatStyle()
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Range where Bound == Date {
    
    /// Formats the date range as an interval.
    public func formatted() -> String {
        Date.IntervalFormatStyle().format(self)
    }
    
    /// Formats the date range using the specified date and time format styles.
    public func formatted(date: Date.IntervalFormatStyle.DateStyle, time: Date.IntervalFormatStyle.TimeStyle) -> String {
        Date.IntervalFormatStyle(date: date, time: time).format(self)
    }
    
    /// Formats the date range using the specified style.
    public func formatted<S>(_ style: S) -> S.FormatOutput where S : FormatStyle, S.FormatInput == Range<Date> {
        style.format(self)
    }
    
}

