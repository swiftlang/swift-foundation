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

    public struct StringInterpolation : StringInterpolationProtocol, Sendable {
        public typealias StringLiteralType = String
        fileprivate var format: String = ""
        public init(literalCapacity: Int, interpolationCount: Int) {}

        mutating public func appendLiteral(_ literal: String) {
            format += literal.asDateFormatLiteral()
        }

        mutating public func appendInterpolation(era: Date.FormatStyle.Symbol.Era) {
            format.append(era.option.rawValue)
        }

        mutating public func appendInterpolation(year: Date.FormatStyle.Symbol.Year) {
            format.append(year.option.rawValue)
        }

        mutating public func appendInterpolation(yearForWeekOfYear: Date.FormatStyle.Symbol.YearForWeekOfYear) {
            format.append(yearForWeekOfYear.option.rawValue)
        }

        mutating public func appendInterpolation(cyclicYear: Date.FormatStyle.Symbol.CyclicYear) {
            format.append(cyclicYear.option.rawValue)
        }

        mutating public func appendInterpolation(quarter: Date.FormatStyle.Symbol.Quarter) {
            format.append(quarter.option.rawValue)
        }

        mutating public func appendInterpolation(standaloneQuarter: Date.FormatStyle.Symbol.StandaloneQuarter) {
            format.append(standaloneQuarter.option.rawValue)
        }

        mutating public func appendInterpolation(month: Date.FormatStyle.Symbol.Month) {
            format.append(month.option.rawValue)
        }

        mutating public func appendInterpolation(standaloneMonth: Date.FormatStyle.Symbol.StandaloneMonth) {
            format.append(standaloneMonth.option.rawValue)
        }

        mutating public func appendInterpolation(week: Date.FormatStyle.Symbol.Week) {
            format.append(week.option.rawValue)
        }

        mutating public func appendInterpolation(day: Date.FormatStyle.Symbol.Day) {
            format.append(day.option.rawValue)
        }

        mutating public func appendInterpolation(dayOfYear: Date.FormatStyle.Symbol.DayOfYear) {
            format.append(dayOfYear.option.rawValue)
        }

        mutating public func appendInterpolation(weekday: Date.FormatStyle.Symbol.Weekday) {
            format.append(weekday.option.rawValue)
        }

        mutating public func appendInterpolation(standaloneWeekday: Date.FormatStyle.Symbol.StandaloneWeekday) {
            format.append(standaloneWeekday.option.rawValue)
        }

        mutating public func appendInterpolation(dayPeriod: Date.FormatStyle.Symbol.DayPeriod) {
            format.append(dayPeriod.option.rawValue)
        }

        mutating public func appendInterpolation(hour: Date.FormatStyle.Symbol.VerbatimHour) {
            format.append(hour.option.rawValue)
        }

        mutating public func appendInterpolation(minute: Date.FormatStyle.Symbol.Minute) {
            format.append(minute.option.rawValue)
        }

        mutating public func appendInterpolation(second: Date.FormatStyle.Symbol.Second) {
            format.append(second.option.rawValue)
        }

        mutating public func appendInterpolation(secondFraction: Date.FormatStyle.Symbol.SecondFraction) {
            format.append(secondFraction.option.rawValue)
        }

        mutating public func appendInterpolation(timeZone: Date.FormatStyle.Symbol.TimeZone) {
            format.append(timeZone.option.rawValue)
        }
    }
}
