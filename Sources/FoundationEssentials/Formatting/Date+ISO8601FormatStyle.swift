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

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date {
    /// Generates a locale-aware string representation of a date using the ISO 8601 date format.
    ///
    /// Calling this method is equivalent to passing a ``Date/ISO8601FormatStyle`` to a date's ``Date/formatted()`` method.
    ///
    /// - Parameter style: A customized ``Date/ISO8601FormatStyle`` to apply. By default, the method applies an unmodified ISO 8601 format style.
    /// - Returns: A string, formatted according to the specified style.
    public func ISO8601Format(_ style: ISO8601FormatStyle = .init()) -> String {
        return style.format(self)
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date {
    /// A type that converts between dates and their ISO-8601 string representations.
    ///
    /// The ``Date/ISO8601FormatStyle`` type generates and parses string representations of dates following the [ISO-8601](https://www.iso.org/iso-8601-date-and-time-format.html) standard, like `2024-04-01T12:34:56.789Z`. Use this type to create ISO-8601 representations of dates and create dates from text strings in ISO 8601 format. For other formatting conventions, like human-readable, localized date formats, use ``Date/FormatStyle``.
    ///
    /// Instance modifier methods applied to an ISO-8601 format style customize the formatted output, as the following example illustrates.
    ///
    /// ```swift
    /// let now = Date()
    /// print(now.formatted(Date.ISO8601FormatStyle().dateSeparator(.dash)))
    /// // 2021-06-21T211015Z
    /// ```
    ///
    ///
    /// Use the static factory property ``FormatStyle/iso8601`` to create an instance of ``Date/ISO8601FormatStyle``. Then apply instance modifier methods to customize the format, as in the example below.
    ///
    /// ```swift
    /// let meetNow = Date()
    /// let formatted = meetNow.formatted(.iso8601
    /// .year()
    /// .month()
    /// .day()
    /// .timeZone(separator: .omitted)
    /// .time(includingFractionalSeconds: true)
    /// .timeSeparator(.colon)
    /// ) // "2022-06-10T12:34:56.789Z"
    ///
    /// ```
    public struct ISO8601FormatStyle : Sendable {
        /// A type describing the character separating the time and time zone of a date in an ISO 8601 date format.
        public enum TimeZoneSeparator : String, Codable, Sendable {
            /// Use a colon (`:`) to separate the time zone components.
            case colon = ":"
            /// Omit the time zone separator.
            case omitted = ""
        }

        /// A type describing the character separating year, month, and day components of a date in an ISO 8601 date format.
        public enum DateSeparator : String, Codable, Sendable {
            /// Use a dash (`-`) to separate date components.
            case dash = "-"
            /// Omit the date separator.
            case omitted = ""
        }

        /// Type describing the character separating the time components of a date in an ISO 8601 date format.
        public enum TimeSeparator : String, Codable, Sendable {
            /// Use a colon (`:`) to separate time components.
            case colon = ":"
            /// Omit the time separator.
            case omitted = ""
        }

        /// Type describing the character separating the date and time components of a date in an ISO 8601 date format.
        public enum DateTimeSeparator : String, Codable, Sendable {
            /// Use a space to separate the date and time components.
            case space = " "
            /// Use the standard `T` separator between date and time components.
            case standard = "'T'"
        }
        
        public private(set) var timeSeparator: TimeSeparator {
            get {
                componentsFormatStyle.timeSeparator
            }
            set {
                componentsFormatStyle.timeSeparator = newValue
            }
        }
        
        /// If set, the style includes fractional seconds when formatting.
        /// Before Swift 6.2, if true when parsing, fractional seconds must be present. If false when parsing, fractional seconds must not be present.
        /// After Swift 6.2, fractional seconds may be present in the String regardless of the setting of this property.
        public private(set) var includingFractionalSeconds: Bool {
            get {
                componentsFormatStyle.includingFractionalSeconds
            }
            set {
                componentsFormatStyle.includingFractionalSeconds = newValue
            }
        }
                
        public private(set) var timeZoneSeparator: TimeZoneSeparator {
            get {
                componentsFormatStyle.timeZoneSeparator
            }
            set {
                componentsFormatStyle.timeZoneSeparator = newValue
            }
        }
        /// The character used to separate the components of a date.
        public private(set) var dateSeparator: DateSeparator  {
            get {
                componentsFormatStyle.dateSeparator
            }
            set {
                componentsFormatStyle.dateSeparator = newValue
            }
        }
        
        /// The character used to separate the date and time components of an ISO 8601 string representation of a date.
        public private(set) var dateTimeSeparator: DateTimeSeparator {
            get {
                componentsFormatStyle.dateTimeSeparator
            }
            set {
                componentsFormatStyle.dateTimeSeparator = newValue
            }
        }
        
        /// The time zone to use to create and parse date representations.
        public var timeZone: TimeZone {
            get {
                componentsFormatStyle.timeZone
            }
            set {
                componentsFormatStyle.timeZone = newValue
            }
        }

        // MARK: -
        
        /// All parsing and formatting is done with the `DateComponents` style.
        private var componentsFormatStyle: DateComponents.ISO8601FormatStyle
        
        // Convenience init to stash a components style inside this one
        internal init(_ componentsStyle: DateComponents.ISO8601FormatStyle) {
            componentsFormatStyle = componentsStyle
        }
        
        // MARK: - Encoding
        
        public init(from decoder: any Decoder) throws {
            // Delegate to the DateComponents.ISO8601FormatStyle type
            componentsFormatStyle = try DateComponents.ISO8601FormatStyle(from: decoder)
        }
        
        public func encode(to encoder: any Encoder) throws {
            // Delegate to the DateComponents.ISO8601FormatStyle type
            try componentsFormatStyle.encode(to: encoder)
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(componentsFormatStyle)
        }
        
        public static func ==(lhs: ISO8601FormatStyle, rhs: ISO8601FormatStyle) -> Bool {
            lhs.componentsFormatStyle == rhs.componentsFormatStyle
        }
        
        // MARK: -

        /// Creates an instance using the provided date separator, date and time components separator, and time zone.
        ///
        /// Possible values of `dateSeparator` are `dash` and `omitted`.
        /// Possible values of `dateTimeSeparator` are `space` and `standard`.
        ///
        /// ```swift
        /// let aDate = Date()
        /// print(aDate.formatted(Date.ISO8601FormatStyle(dateSeparator: .omitted, dateTimeSeparator: .standard)))
        /// // 20210622T172132Z
        ///
        /// if let centralStandardTimeZone = TimeZone(identifier: "CST") {
        ///    print(aDate.formatted(Date.ISO8601FormatStyle(dateSeparator: .dash, dateTimeSeparator: .space, timeZone: centralStandardTimeZone)))
        /// }
        /// // 2021-06-22 122132-0500
        /// ```
        ///
        /// - Parameters:
        ///   - dateSeparator: The separator character used between the year, month, and day.
        ///   - dateTimeSeparator: The separator character used between the date and time components.
        ///   - timeZone: The time zone used to create the string representation of the date.
        @_disfavoredOverload
        public init(dateSeparator: DateSeparator = .dash, dateTimeSeparator: DateTimeSeparator = .standard, timeZone: TimeZone = TimeZone(secondsFromGMT: 0)!) {
            componentsFormatStyle = DateComponents.ISO8601FormatStyle(dateSeparator: dateSeparator, dateTimeSeparator: dateTimeSeparator, timeZone: timeZone)
        }

        // The default is the format of RFC 3339 with no fractional seconds: "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"
        public init(dateSeparator: DateSeparator = .dash, dateTimeSeparator: DateTimeSeparator = .standard, timeSeparator: TimeSeparator = .colon, timeZoneSeparator: TimeZoneSeparator = .omitted, includingFractionalSeconds: Bool = false, timeZone: TimeZone = TimeZone(secondsFromGMT: 0)!) {
            componentsFormatStyle = DateComponents.ISO8601FormatStyle(dateSeparator: dateSeparator, dateTimeSeparator: dateTimeSeparator, timeSeparator: timeSeparator, timeZoneSeparator: timeZoneSeparator, includingFractionalSeconds: includingFractionalSeconds, timeZone: timeZone)
        }
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.ISO8601FormatStyle {
    /// Modifies the ISO 8601 date format style to include the year in the formatted output.
    ///
    /// The default ``Date/ISO8601FormatStyle`` includes the year.
    ///
    /// - Returns: An ISO 8601 date format style modified to include the year.
    public func year() -> Self {
        .init(componentsFormatStyle.year())
    }

    /// Modifies the ISO 8601 date format style to include the week of the year in the formatted output.
    ///
    /// When the format style includes the week of year, the output represents the day
    /// as the ordinal day of the week.
    ///
    /// - Returns: An ISO 8601 date format style modified to include the week of the year.
    public func weekOfYear() -> Self {
        .init(componentsFormatStyle.weekOfYear())
    }

    /// Modifies the ISO 8601 date format style to include the month in the formatted output.
    ///
    /// If `month()` isn't included in the format but `day()` is, the format represents
    /// the day as the ordinal date. The default ``Date/ISO8601FormatStyle`` includes the month.
    ///
    /// - Returns: An ISO 8601 date format style modified to include the month.
    public func month() -> Self {
        .init(componentsFormatStyle.month())
    }

    /// Modifies the ISO 8601 date format style to include the day in the formatted output.
    ///
    /// If `month()` isn't included in the format and `day()` is, the format represents
    /// the day as the ordinal date. The default ``Date/ISO8601FormatStyle`` includes the day.
    ///
    /// - Returns: An ISO 8601 date format style modified to include the day.
    public func day() -> Self {
        .init(componentsFormatStyle.day())
    }

    /// Modifies the ISO 8601 date format style to include the time in the formatted output.
    ///
    /// The default ``Date/ISO8601FormatStyle`` includes the time but not the fractional seconds.
    ///
    /// - Parameter includingFractionalSeconds: Specifies whether the format style includes the fractional component of the seconds.
    /// - Returns: An ISO 8601 date format style modified to include the time.
    public func time(includingFractionalSeconds: Bool) -> Self {
        .init(componentsFormatStyle.time(includingFractionalSeconds: includingFractionalSeconds))
    }

    /// Modifies the ISO 8601 date format style to include the time zone in the formatted output.
    ///
    /// The default ``Date/ISO8601FormatStyle`` doesn't include the time zone.
    ///
    /// - Parameter separator: The character used to separate the time and time zone in a date.
    /// - Returns: An ISO 8601 date format style modified to include the time zone.
    public func timeZone(separator: TimeZoneSeparator) -> Self {
        .init(componentsFormatStyle.timeZone(separator: separator))
    }

    /// Modifies the ISO 8601 date format style to use the specified date separator.
    ///
    /// Possible values are ``DateSeparator/dash`` and ``DateSeparator/omitted``.
    /// The default is ``DateSeparator/omitted``.
    ///
    /// - Parameter separator: The character used to separate the year, month, and day in a date.
    /// - Returns: An ISO 8601 date format style modified to include the specified date separator style.
    public func dateSeparator(_ separator: DateSeparator) -> Self {
        .init(componentsFormatStyle.dateSeparator(separator))
    }

    /// Sets the character that separates the date and time components.
    ///
    /// Possible values are ``DateTimeSeparator/space`` and ``DateTimeSeparator/standard``.
    /// The default is ``DateTimeSeparator/standard``.
    ///
    /// - Parameter separator: The character used to separate the date and time components.
    /// - Returns: An ISO 8601 date format style with the provided date and time component separator.
    public func dateTimeSeparator(_ separator: DateTimeSeparator) -> Self {
        .init(componentsFormatStyle.dateTimeSeparator(separator))
    }

    /// Modifies the ISO 8601 date format style to use the specified time separator.
    ///
    /// Possible values are ``TimeSeparator/colon`` and ``TimeSeparator/omitted``.
    /// The default is ``TimeSeparator/omitted``.
    ///
    /// - Parameter separator: The character used to separate the hour and minute in a date.
    /// - Returns: An ISO 8601 date format style modified to include the specified time separator style.
    public func timeSeparator(_ separator: TimeSeparator) -> Self {
        .init(componentsFormatStyle.timeSeparator(separator))
    }

    /// Modifies the ISO 8601 date format style to use the specified time zone separator.
    ///
    /// Possible values are ``TimeZoneSeparator/colon`` and ``TimeZoneSeparator/omitted``.
    ///
    /// - Parameter separator: The character used to separate the time and time zone in a date.
    /// - Returns: An ISO 8601 date format style modified to include the specified time zone separator style.
    public func timeZoneSeparator(_ separator: TimeZoneSeparator) -> Self {
        .init(componentsFormatStyle.timeZoneSeparator(separator))
    }    
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.ISO8601FormatStyle : FormatStyle {

    /// Creates a locale-aware ISO 8601 string representation from a date value.
    ///
    /// Once you create a style, you can use it to format dates multiple times.
    ///
    /// - Parameter value: The date to format.
    /// - Returns: A string ISO 8601 representation of the date.
    public func format(_ value: Date) -> String {
        var whichComponents = Calendar.ComponentSet()
        let fields = componentsFormatStyle.formatFields

        // If we use week of year, don't bother with year
        if fields.contains(.year) && !fields.contains(.weekOfYear) {
            whichComponents.insert(.era)
            whichComponents.insert(.year)
        }

        if fields.contains(.month) {
            whichComponents.insert(.month)
        }

        if fields.contains(.weekOfYear) {
            whichComponents.insert([.weekOfYear, .yearForWeekOfYear])
        }

        if fields.contains(.day) {
            if fields.contains(.weekOfYear) {
                whichComponents.insert(.weekday)
            } else if fields.contains(.month) {
                whichComponents.insert(.day)
            } else {
                whichComponents.insert(.dayOfYear)
            }
        }

        if fields.contains(.time) {
            whichComponents.insert([.hour, .minute, .second])
            if includingFractionalSeconds {
                whichComponents.insert(.nanosecond)
            }
        }

        let secondsFromGMT: Int?
        let components = componentsFormatStyle._calendar._dateComponents(whichComponents, from: value)
        if fields.contains(.timeZone) {
            secondsFromGMT = timeZone.secondsFromGMT(for: value)
        } else {
            secondsFromGMT = nil
        }
        return format(components, appendingTimeZoneOffset: secondsFromGMT)
    }

    func format(_ components: DateComponents, appendingTimeZoneOffset timeZoneOffset: Int?) -> String {
        componentsFormatStyle.format(components, appendingTimeZoneOffset: timeZoneOffset)
    }
}

// MARK: `FormatStyle` protocol membership

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == Date.ISO8601FormatStyle {
    static var iso8601: Self {
        return Date.ISO8601FormatStyle()
    }
}

// MARK: - Parsing

// MARK: `FormatStyle` protocol membership

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension ParseableFormatStyle where Self == Date.ISO8601FormatStyle {
    static var iso8601: Self { .init() }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension ParseStrategy where Self == Date.ISO8601FormatStyle {
    /// A style for formatting a date in accordance with the ISO-8601 standard.
    ///
    /// Use the dot-notation form of this type property when the call point allows the use of
    /// ``Date/ISO8601FormatStyle``; in other words, when the value type is `Date`. Typically, you
    /// use this with the ``Date/formatted(_:)`` method of `Date`.
    @_disfavoredOverload
    static var iso8601: Self { .init() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.ISO8601FormatStyle : ParseStrategy {
    /// Parses a string into a date.
    ///
    /// This method attempts to parse a provided string into an instance of
    /// date using the source date format style. The function throws an error
    /// if it can't parse the input string into a date instance.
    ///
    /// ```swift
    /// let birthdayFormatStyle = Date.ISO8601FormatStyle()
    ///     .dateSeparator(.dash)
    ///     .timeSeparator(.colon)
    ///     .year()
    ///     .month()
    ///     .day()
    ///     .time(includingFractionalSeconds: false)
    ///
    /// let yourBirthdayString = "2021-02-17T14:33:25"
    /// let yourBirthday = try? birthdayFormatStyle.parse(yourBirthdayString)
    /// // Feb 17, 2021 at 8:33 AM
    /// ```
    ///
    /// - Parameter value: The string to parse.
    /// - Returns: An instance of `Date` parsed from the input string.
    public func parse(_ value: String) throws -> Date {
        guard let (_, date) = parse(value, in: value.startIndex..<value.endIndex) else {
            throw parseError(value, exampleFormattedString: self.format(Date.now))
        }
        return date
    }
    
    package func parse(_ value: String, in range: Range<String.Index>) -> (String.Index, Date)? {
        let v = value[range]
        guard !v.isEmpty else {
            return nil
        }
        
        // Date parsing needs missing units filled out, so that we can calculate a date. Instead of filling them here, we do it inside the parse because it calculates which ones are truly needed.
        guard let (idx, comps) = componentsFormatStyle.parse(value, fillMissingUnits: true, in: range) else {
            return nil
        }
        
        guard let date = componentsFormatStyle._calendar.date(from: comps) else {
            return nil
        }
            
        return (idx, date)
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.ISO8601FormatStyle: ParseableFormatStyle {
    /// The strategy used to parse a string into a date.
    public var parseStrategy: Self {
        return self
    }
}

// MARK: - Regex

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension Date.ISO8601FormatStyle : CustomConsumingRegexComponent {
    /// The type returned when capturing matching substrings with this strategy.
    public typealias RegexOutput = Date
    /// Processes the input string within the specified bounds, beginning at the given index, and returns the end position of the match and the produced output.
    ///
    /// Don't call this method directly. Regular expression matching and capture
    /// calls it automatically when matching substrings.
    ///
    /// - Parameters:
    ///   - input: An input string to match against.
    ///   - index: The index within `input` at which to begin searching.
    ///   - bounds: The bounds within `input` in which to search.
    /// - Returns: The upper bound where the match terminates and a matched instance, or `nil` if there isn't a match.
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Date)? {
        guard index < bounds.upperBound else {
            return nil
        }
        // It's important to return nil from parse in case of a failure, not throw. That allows things like the firstMatch regex to work.
        return self.parse(input, in: index..<bounds.upperBound)
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
    /// - Returns:  A `RegexComponent` to match an ISO 8601 date string, not any time zone that may be in the string.
    public static func iso8601Date(timeZone: TimeZone, dateSeparator: Self.DateSeparator = .dash) -> Self {
        return Date.ISO8601FormatStyle(dateSeparator: dateSeparator, timeZone: timeZone).year().month().day()
    }
}
