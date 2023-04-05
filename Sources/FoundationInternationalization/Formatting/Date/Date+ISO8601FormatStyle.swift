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
    public func ISO8601Format(_ style: ISO8601FormatStyle = .init()) -> String {
        return style.format(self)
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date {

    /// Options for generating and parsing string representations of dates following the ISO 8601 standard.
    public struct ISO8601FormatStyle : Sendable {

        public enum TimeZoneSeparator : String, Codable, Sendable {
            case colon = ":"
            case omitted = ""
        }

        public enum DateSeparator : String, Codable, Sendable  {
            case dash = "-"
            case omitted = ""
        }

        public enum TimeSeparator : String, Codable, Sendable {
            case colon = ":"
            case omitted = ""
        }

        public enum DateTimeSeparator : String, Codable, Sendable {
            case space = " "
            case standard = "'T'"
        }

        enum Field : Int, Codable, Hashable, Comparable {
            case year
            case month
            case weekOfYear
            case day
            case time
            case timeZone

            static func < (lhs: Self, rhs: Self) -> Bool {
                return lhs.rawValue < rhs.rawValue
            }
        }
        public private(set) var timeSeparator: TimeSeparator
        public private(set) var includingFractionalSeconds: Bool
        public private(set) var timeZoneSeparator: TimeZoneSeparator

        public private(set) var dateSeparator: DateSeparator
        public private(set) var dateTimeSeparator: DateTimeSeparator

        private var _formatFields: Set<Field> = []
        var formatFields: Set<Field> {
            if _formatFields.isEmpty {
                return [ .year, .month, .day, .time, .timeZone]
            } else {
                return _formatFields
            }
        }
        /// The time zone to use to create and parse date representations.
        public var timeZone: TimeZone = TimeZone(secondsFromGMT: 0)!

        private var format: String {
            let fields = formatFields

            var result = ""
            for (idx, field) in fields.sorted().enumerated() {
                switch field {
                case .year:
                    result += fields.contains(.weekOfYear) ? "YYYY" : "yyyy"

                case .month:
                    if idx > 0, dateSeparator == .dash {
                        result += DateSeparator.dash.rawValue
                    }
                    result += "MM"

                case .weekOfYear:
                    if idx > 0, dateSeparator == .dash {
                        result += DateSeparator.dash.rawValue
                    }
                    result += "'W'ww"

                case .day:
                    if idx > 0, dateSeparator == .dash {
                        result += DateSeparator.dash.rawValue
                    }

                    if fields.contains(.weekOfYear) {
                        result += "ee"
                    } else if fields.contains(.month) {
                        result += "dd"
                    } else {
                        result += "DDD"
                    }

                case .time:
                    if idx > 0 {
                        result += dateTimeSeparator.rawValue
                    }

                    switch timeSeparator {
                    case .colon:
                        result += "HH:mm:ss"
                    case .omitted:
                        result += "HHmmss"
                    }

                    if includingFractionalSeconds {
                        result += ".SSS"
                    }

                case .timeZone:
                    switch timeZoneSeparator {
                    case .colon:
                        result += "XXXXX"
                    case .omitted:
                        result += "XXXX"
                    }
                }
            }

            return result
        }

        private var formatter: ICUDateFormatter {
            let dateFormatInfo = ICUDateFormatter.DateFormatInfo(localeIdentifier: "en_US_POSIX", timeZoneIdentifier: timeZone.identifier, calendarIdentifier: .gregorian, firstWeekday: 2, minimumDaysInFirstWeek: 4, capitalizationContext: .unknown, pattern: format, parseLenient: false)

            return ICUDateFormatter.cachedFormatter(for: dateFormatInfo)
        }

        // MARK: -


        @_disfavoredOverload
        public init(dateSeparator: DateSeparator = .dash, dateTimeSeparator: DateTimeSeparator = .standard, timeZone: TimeZone = TimeZone(secondsFromGMT: 0)!)  {
            self.dateSeparator = dateSeparator
            self.dateTimeSeparator = dateTimeSeparator
            self.timeZone = timeZone
            self.timeSeparator = .colon
            self.timeZoneSeparator = .omitted
            self.includingFractionalSeconds = false
        }

        // The default is the format of RFC 3339 with no fractional seconds: "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"
        public init(dateSeparator: DateSeparator = .dash, dateTimeSeparator: DateTimeSeparator = .standard, timeSeparator: TimeSeparator = .colon, timeZoneSeparator: TimeZoneSeparator = .omitted, includingFractionalSeconds: Bool = false, timeZone: TimeZone = TimeZone(secondsFromGMT: 0)!) {
            self.dateSeparator = dateSeparator
            self.dateTimeSeparator = dateTimeSeparator
            self.timeZone = timeZone
            self.timeSeparator = timeSeparator
            self.timeZoneSeparator = timeZoneSeparator
            self.includingFractionalSeconds = includingFractionalSeconds
        }
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.ISO8601FormatStyle {
    public func year() -> Self {
        var new = self
        new._formatFields.insert(.year)
        return new
    }

    public func weekOfYear() -> Self {
        var new = self
        new._formatFields.insert(.weekOfYear)
        return new
    }

    public func month() -> Self {
        var new = self
        new._formatFields.insert(.month)
        return new
    }

    public func day() -> Self {
        var new = self
        new._formatFields.insert(.day)
        return new
    }

    public func time(includingFractionalSeconds: Bool) -> Self {
        var new = self
        new._formatFields.insert(.time)
        new.includingFractionalSeconds = includingFractionalSeconds
        return new
    }

    public func timeZone(separator: TimeZoneSeparator) -> Self {
        var new = self
        new._formatFields.insert(.timeZone)
        new.timeZoneSeparator = separator
        return new
    }

    public func dateSeparator(_ separator: DateSeparator) -> Self {
        var new = self
        new.dateSeparator = separator
        return new
    }

    public func dateTimeSeparator(_ separator: DateTimeSeparator) -> Self {
        var new = self
        new.dateTimeSeparator = separator
        return new
    }

    public func timeSeparator(_ separator: TimeSeparator) -> Self {
        var new = self
        new.timeSeparator = separator
        return new
    }

    public func timeZoneSeparator(_ separator: TimeZoneSeparator) -> Self {
        var new = self
        new.timeZoneSeparator = separator
        return new
    }
}

#if FOUNDATION_FRAMEWORK
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension ISO8601DateFormatter.Options : Hashable {}
#endif // FOUNDATION_FRAMEWORK

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.ISO8601FormatStyle : FormatStyle {
    public func format(_ value: Date) -> String {
        return formatter.format(value) ?? value.description
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.ISO8601FormatStyle : ParseStrategy {
    public func parse(_ value: String) throws -> Date {
        let formatter = formatter

        guard let date = formatter.parse(value) else {
            throw parseError(value, exampleFormattedString: formatter.format(Date.now))
        }

        return date
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.ISO8601FormatStyle: ParseableFormatStyle {
    public var parseStrategy: Self {
        return self
    }
}

// MARK: `FormatStyle` protocol membership

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == Date.ISO8601FormatStyle {
    static var iso8601: Self {
        return Date.ISO8601FormatStyle()
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension ParseableFormatStyle where Self == Date.ISO8601FormatStyle {
    static var iso8601: Self { .init() }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension ParseStrategy where Self == Date.ISO8601FormatStyle {
    @_disfavoredOverload
    static var iso8601: Self { .init() }
}

// MARK: Regex

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension Date.ISO8601FormatStyle : CustomConsumingRegexComponent {
    public typealias RegexOutput = Date
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Date)? {
        guard index < bounds.upperBound else {
            return nil
        }
        return formatter.parse(input, in: index..<bounds.upperBound)
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension RegexComponent where Self == Date.ISO8601FormatStyle {
    /// Creates a regex component to match an ISO 8601 date and time, such as "2015-11-14'T'15:05:03'Z'", and capture the string as a `Date` using the time zone as specified in the string.
    @_disfavoredOverload
    public static var iso8601: Date.ISO8601FormatStyle {
        return Date.ISO8601FormatStyle()
    }

    /// Creates a regex component to match an ISO 8601 date and time string, including time zone, and capture the string as a `Date` using the time zone as specified in the string.
    /// - Parameters:
    ///   - includingFractionalSeconds: Specifies if the string contains fractional seconds.
    ///   - dateSeparator: The separator between date components.
    ///   - dateTimeSeparator: The separator between date and time parts.
    ///   - timeSeparator: The separator between time components.
    ///   - timeZoneSeparator: The separator between time parts in the time zone.
    /// - Returns: A `RegexComponent` to match an ISO 8601 string, including time zone.
    public static func iso8601WithTimeZone(includingFractionalSeconds: Bool = false, dateSeparator: Self.DateSeparator = .dash, dateTimeSeparator: Self.DateTimeSeparator = .standard, timeSeparator: Self.TimeSeparator = .colon, timeZoneSeparator: Self.TimeZoneSeparator = .omitted) -> Self {
        return Date.ISO8601FormatStyle(dateSeparator: dateSeparator, dateTimeSeparator: dateTimeSeparator, timeSeparator: timeSeparator, timeZoneSeparator: timeZoneSeparator, includingFractionalSeconds: includingFractionalSeconds)
    }

    /// Creates a regex component to match an ISO 8601 date and time string without time zone, and capture the string as a `Date` using the specified `timeZone`. If the string contains time zone designators, matches up until the start of time zone designators.
    /// - Parameters:
    ///   - timeZone: The time zone to create the captured `Date` with.
    ///   - includingFractionalSeconds: Specifies if the string contains fractional seconds.
    ///   - dateSeparator: The separator between date components.
    ///   - dateTimeSeparator: The separator between date and time parts.
    ///   - timeSeparator: The separator between time components.
    /// - Returns: A `RegexComponent` to match an ISO 8601 string.
    public static func iso8601(timeZone: TimeZone, includingFractionalSeconds: Bool = false, dateSeparator: Self.DateSeparator = .dash, dateTimeSeparator: Self.DateTimeSeparator = .standard, timeSeparator: Self.TimeSeparator = .colon) -> Self {
        return Date.ISO8601FormatStyle(timeZone: timeZone).year().month().day().time(includingFractionalSeconds: includingFractionalSeconds).timeSeparator(timeSeparator).dateSeparator(dateSeparator).dateTimeSeparator(dateTimeSeparator)
    }

    /// Creates a regex component to match an ISO 8601 date string, such as "2015-11-14", and capture the string as a `Date`. The captured `Date` would be at midnight in the specified `timeZone`.
    /// - Parameters:
    ///   - timeZone: The time zone to create the captured `Date` with.
    ///   - dateSeparator: The separator between date components.
    /// - Returns:  A `RegexComponent` to match an ISO 8601 date string, including time zone.
    public static func iso8601Date(timeZone: TimeZone, dateSeparator: Self.DateSeparator = .dash) -> Self {
        return Date.ISO8601FormatStyle(dateSeparator: dateSeparator, timeZone: timeZone).year().month().day()
    }
}
