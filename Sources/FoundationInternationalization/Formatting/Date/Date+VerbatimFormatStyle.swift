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
    /// Formats a `Date` using the given format.
    public struct VerbatimFormatStyle : Sendable {
        public var timeZone: TimeZone
        public var calendar: Calendar

        /// Use system locale if nil or unspecified.
        public var locale: Locale?

        var formatPattern: String
        public init(format: FormatString, locale: Locale? = nil, timeZone: TimeZone, calendar: Calendar) {
            self.formatPattern = format.rawFormat
            self.calendar = calendar
            self.locale = locale
            self.timeZone = timeZone
        }

        /// Returns the corresponding `AttributedStyle` which formats the date with  `AttributeScopes.FoundationAttributes.DateFormatFieldAttribute`
        public var attributed: AttributedStyle {
            .init(style: .verbatimFormatStyle(self))
        }

        public func format(_ value: Date) -> String {
            return NSICUDateFormatter.cachedFormatter(for: self).format(value) ?? value.description
        }

        public func locale(_ locale: Locale) -> Date.VerbatimFormatStyle {
            var new = self
            new.locale = locale
            return new
        }
    }
}

extension Date.VerbatimFormatStyle : FormatStyle {}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension FormatStyle where Self == Date.VerbatimFormatStyle {
    public static func verbatim(_ format: Date.FormatString, locale: Locale? = nil, timeZone: TimeZone, calendar: Calendar) -> Date.VerbatimFormatStyle { .init(format: format, locale: locale, timeZone: timeZone, calendar: calendar) }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.VerbatimFormatStyle: ParseableFormatStyle {
    public var parseStrategy: Date.ParseStrategy {
            .init(format: formatPattern, locale: locale, timeZone: timeZone, calendar: calendar, isLenient: false, twoDigitStartDate: Date(timeIntervalSince1970: 0))
    }
}

// MARK: MatchingCollectionConsumer

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension Date.VerbatimFormatStyle : CustomConsumingRegexComponent {
    public typealias RegexOutput = Date
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Date)? {
        try parseStrategy.consuming(input, startingAt: index, in: bounds)
    }
}
