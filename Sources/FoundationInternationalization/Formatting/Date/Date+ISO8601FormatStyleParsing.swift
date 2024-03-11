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
extension Date.ISO8601FormatStyle {
    private var format: String {
        let fields = formatFields

        var result = ""
        var needsSeparator = false
        if fields.contains(.year) {
            result += fields.contains(.weekOfYear) ? "YYYY" : "yyyy"
            
            needsSeparator = true
        }

        if fields.contains(.month) {
            if needsSeparator && dateSeparator == .dash {
                result += DateSeparator.dash.rawValue
            }
            result += "MM"
            
            needsSeparator = true
        }

        if fields.contains(.weekOfYear) {
            if needsSeparator && dateSeparator == .dash {
                result += DateSeparator.dash.rawValue
            }
            result += "'W'ww"
            
            needsSeparator = true
        }

        if fields.contains(.day) {
            if needsSeparator && dateSeparator == .dash {
                result += DateSeparator.dash.rawValue
            }
            
            if fields.contains(.weekOfYear) {
                result += "ee"
            } else if fields.contains(.month) {
                result += "dd"
            } else {
                result += "DDD"
            }
            
            needsSeparator = true
        }

        if fields.contains(.time) {
            if needsSeparator {
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
            
            needsSeparator = true
        }

        if fields.contains(.timeZone) {
            switch timeZoneSeparator {
            case .colon:
                result += "XXXXX"
            case .omitted:
                result += "XXXX"
            }
        }
        
        return result
    }

    private var formatter: ICUDateFormatter {
        let dateFormatInfo = ICUDateFormatter.DateFormatInfo(localeIdentifier: "en_US_POSIX", timeZoneIdentifier: timeZone.identifier, calendarIdentifier: .gregorian, firstWeekday: 2, minimumDaysInFirstWeek: 4, capitalizationContext: .unknown, pattern: format, parseLenient: false)

        return ICUDateFormatter.cachedFormatter(for: dateFormatInfo)
    }

    public func parse(_ value: String) throws -> Date {
        let formatter = formatter

        guard let date = formatter.parse(value) else {
            throw parseError(value, exampleFormattedString: formatter.format(Date.now))
        }

        return date
    }
}

#if FOUNDATION_FRAMEWORK || compiler(<5.10)
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.ISO8601FormatStyle : ParseStrategy {}
#else
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.ISO8601FormatStyle : @retroactive ParseStrategy {}
#endif

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.ISO8601FormatStyle {
    public var parseStrategy: Self {
        return self
    }
}

#if FOUNDATION_FRAMEWORK || compiler(<5.10)
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.ISO8601FormatStyle : ParseableFormatStyle {}
#else
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.ISO8601FormatStyle : @retroactive ParseableFormatStyle {}
#endif

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

// MARK: Regex

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension Date.ISO8601FormatStyle {
    public typealias RegexOutput = Date
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Date)? {
        guard index < bounds.upperBound else {
            return nil
        }
        return formatter.parse(input, in: index..<bounds.upperBound)
    }
}

#if FOUNDATION_FRAMEWORK || compiler(<5.10)
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension Date.ISO8601FormatStyle : CustomConsumingRegexComponent {}
#else
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension Date.ISO8601FormatStyle : @retroactive CustomConsumingRegexComponent {}
#endif

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
