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
    /// A type that represents a fixed date format string using string interpolation.
    ///
    /// Use `Date.FormatString` with ``Date/VerbatimFormatStyle`` or ``Date/ParseStrategy``
    /// to create fixed-pattern format strings for dates. You build format strings using
    /// string interpolation with date field symbols:
    ///
    /// ```swift
    /// let format: Date.FormatString = "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)"
    /// ```
    public struct FormatString : Hashable, Sendable {
        internal var rawFormat: String = ""
    }
}

extension String {
    fileprivate func asDateFormatLiteral() -> String {
        guard !self.isEmpty else { return self }

        // CLDR uses two adjacent single vertical quotes to represent a literal
        // single quote in the template. For the rest of the cases, surround the
        // text between single quotes as literal text.
        guard self.contains(where: { $0 != "'" }) else {
            return String(repeating: "'", count: 2 * count)
        }

        return "'\(self.replacing("'", with: "''"))'"
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.FormatString : ExpressibleByStringInterpolation {
    public init(stringInterpolation: StringInterpolation) {
        rawFormat = stringInterpolation.format
    }

    public init(stringLiteral value: String) {
        rawFormat = value.asDateFormatLiteral()
    }

    /// The string interpolation type for building date format strings.
    public struct StringInterpolation : StringInterpolationProtocol, Sendable {
        public typealias StringLiteralType = String
        fileprivate var format: String = ""

        /// Creates a new string interpolation with the given capacities.
        public init(literalCapacity: Int, interpolationCount: Int) {}

        /// Appends a literal string segment to the format string.
        mutating public func appendLiteral(_ literal: String) {
            format += literal.asDateFormatLiteral()
        }

        /// Appends an era symbol to the format string.
        mutating public func appendInterpolation(era: Date.FormatStyle.Symbol.Era) {
            guard let option = era.option else {
                return
            }
            format.append(option.rawValue)
        }

        /// Appends a year symbol to the format string.
        mutating public func appendInterpolation(year: Date.FormatStyle.Symbol.Year) {
            guard let option = year.option else {
                return
            }
            format.append(option.rawValue)
        }

        /// Appends a year-for-week-of-year symbol to the format string.
        mutating public func appendInterpolation(yearForWeekOfYear: Date.FormatStyle.Symbol.YearForWeekOfYear) {
            guard let option = yearForWeekOfYear.option else {
                return
            }
            format.append(option.rawValue)
        }

        /// Appends a cyclic year symbol to the format string.
        mutating public func appendInterpolation(cyclicYear: Date.FormatStyle.Symbol.CyclicYear) {
            guard let option = cyclicYear.option else {
                return
            }
            format.append(option.rawValue)
        }

        /// Appends a quarter symbol to the format string.
        mutating public func appendInterpolation(quarter: Date.FormatStyle.Symbol.Quarter) {
            guard let option = quarter.option else {
                return
            }
            format.append(option.rawValue)
        }

        /// Appends a standalone quarter symbol to the format string.
        mutating public func appendInterpolation(standaloneQuarter: Date.FormatStyle.Symbol.StandaloneQuarter) {
            format.append(standaloneQuarter.option.rawValue)
        }

        /// Appends a month symbol to the format string.
        mutating public func appendInterpolation(month: Date.FormatStyle.Symbol.Month) {
            guard let option = month.option else {
                return
            }
            format.append(option.rawValue)
        }

        /// Appends a standalone month symbol to the format string.
        mutating public func appendInterpolation(standaloneMonth: Date.FormatStyle.Symbol.StandaloneMonth) {
            format.append(standaloneMonth.option.rawValue)
        }

        /// Appends a week symbol to the format string.
        mutating public func appendInterpolation(week: Date.FormatStyle.Symbol.Week) {
            guard let option = week.option else {
                return
            }
            format.append(option.rawValue)
        }

        /// Appends a day symbol to the format string.
        mutating public func appendInterpolation(day: Date.FormatStyle.Symbol.Day) {
            guard let option = day.option else {
                return
            }
            format.append(option.rawValue)
        }

        /// Appends a day-of-year symbol to the format string.
        mutating public func appendInterpolation(dayOfYear: Date.FormatStyle.Symbol.DayOfYear) {
            guard let option = dayOfYear.option else {
                return
            }
            format.append(option.rawValue)
        }

        /// Appends a weekday symbol to the format string.
        mutating public func appendInterpolation(weekday: Date.FormatStyle.Symbol.Weekday) {
            guard let option = weekday.option else {
                return
            }
            format.append(option.rawValue)
        }

        /// Appends a standalone weekday symbol to the format string.
        mutating public func appendInterpolation(standaloneWeekday: Date.FormatStyle.Symbol.StandaloneWeekday) {
            format.append(standaloneWeekday.option.rawValue)
        }

        /// Appends a day period symbol to the format string.
        mutating public func appendInterpolation(dayPeriod: Date.FormatStyle.Symbol.DayPeriod) {
            guard let option = dayPeriod.option else {
                return
            }
            format.append(option.rawValue)
        }

        /// Appends a verbatim hour symbol to the format string.
        mutating public func appendInterpolation(hour: Date.FormatStyle.Symbol.VerbatimHour) {
            format.append(hour.option.rawValue)
        }

        /// Appends a minute symbol to the format string.
        mutating public func appendInterpolation(minute: Date.FormatStyle.Symbol.Minute) {
            guard let option = minute.option else {
                return
            }
            format.append(option.rawValue)
        }

        mutating public func appendInterpolation(second: Date.FormatStyle.Symbol.Second) {
            guard let option = second.option else {
                return
            }
            format.append(option.rawValue)
        }

        mutating public func appendInterpolation(secondFraction: Date.FormatStyle.Symbol.SecondFraction) {
            guard let option = secondFraction.option else {
                return
            }
            format.append(option.rawValue)
        }

        mutating public func appendInterpolation(timeZone: Date.FormatStyle.Symbol.TimeZone) {
            guard let option = timeZone.option else {
                return
            }
            format.append(option.rawValue)
        }
    }
}
