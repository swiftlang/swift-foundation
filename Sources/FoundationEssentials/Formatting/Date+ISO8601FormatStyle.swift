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

        public enum DateSeparator : String, Codable, Sendable {
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
        public private(set) var dateSeparator: DateSeparator  {
            get {
                componentsFormatStyle.dateSeparator
            }
            set {
                componentsFormatStyle.dateSeparator = newValue
            }
        }
        
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
    public func year() -> Self {
        .init(componentsFormatStyle.year())
    }

    public func weekOfYear() -> Self {
        .init(componentsFormatStyle.weekOfYear())
    }

    public func month() -> Self {
        .init(componentsFormatStyle.month())
    }

    public func day() -> Self {
        .init(componentsFormatStyle.day())
    }

    public func time(includingFractionalSeconds: Bool) -> Self {
        .init(componentsFormatStyle.time(includingFractionalSeconds: includingFractionalSeconds))
    }

    public func timeZone(separator: TimeZoneSeparator) -> Self {
        .init(componentsFormatStyle.timeZone(separator: separator))
    }

    public func dateSeparator(_ separator: DateSeparator) -> Self {
        .init(componentsFormatStyle.dateSeparator(separator))
    }

    public func dateTimeSeparator(_ separator: DateTimeSeparator) -> Self {
        .init(componentsFormatStyle.dateTimeSeparator(separator))
    }

    public func timeSeparator(_ separator: TimeSeparator) -> Self {
        .init(componentsFormatStyle.timeSeparator(separator))
    }

    public func timeZoneSeparator(_ separator: TimeZoneSeparator) -> Self {
        .init(componentsFormatStyle.timeZoneSeparator(separator))
    }    
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.ISO8601FormatStyle : FormatStyle {

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
    @_disfavoredOverload
    static var iso8601: Self { .init() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.ISO8601FormatStyle : ParseStrategy {
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
    public var parseStrategy: Self {
        return self
    }
}

// MARK: - Regex

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension Date.ISO8601FormatStyle : CustomConsumingRegexComponent {
    public typealias RegexOutput = Date
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
