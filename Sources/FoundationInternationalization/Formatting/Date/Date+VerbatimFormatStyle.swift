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

// MARK: VerbatimFormatStyle Definition

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

        /// Returns a type erased attributed variant of this style.
        @available(macOS, deprecated: 15, introduced: 12, message: "Use attributedStyle instead")
        @available(iOS, deprecated: 18, introduced: 15, message: "Use attributedStyle instead")
        @available(tvOS, deprecated: 18, introduced: 15, message: "Use attributedStyle instead")
        @available(watchOS, deprecated: 11, introduced: 8, message: "Use attributedStyle instead")
        public var attributed: AttributedStyle {
            .init(style: .verbatimFormatStyle(self))
        }

        public func format(_ value: Date) -> String {
            return ICUDateFormatter.cachedFormatter(for: self).format(value) ?? value.description
        }

        public func locale(_ locale: Locale) -> Date.VerbatimFormatStyle {
            var new = self
            new.locale = locale
            return new
        }
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.VerbatimFormatStyle : FormatStyle {}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension FormatStyle where Self == Date.VerbatimFormatStyle {
    public static func verbatim(_ format: Date.FormatString, locale: Locale? = nil, timeZone: TimeZone, calendar: Calendar) -> Date.VerbatimFormatStyle { .init(format: format, locale: locale, timeZone: timeZone, calendar: calendar) }
}

// MARK: ParseableFormatStyle Conformance

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.VerbatimFormatStyle: ParseableFormatStyle {
    public var parseStrategy: Date.ParseStrategy {
            .init(format: formatPattern, locale: locale, timeZone: timeZone, calendar: calendar, isLenient: false, twoDigitStartDate: Date(timeIntervalSince1970: 0))
    }
}

// MARK: Typed Attributed Style

@available(FoundationPreview 0.4, *)
extension Date.VerbatimFormatStyle {
    /// The type preserving attributed variant of this style.
    ///
    /// This style attributes the formatted date with the `AttributeScopes.FoundationAttributes.DateFormatFieldAttribute`.
    @dynamicMemberLookup
    public struct Attributed : FormatStyle, Sendable {
        var base: Date.VerbatimFormatStyle

        public subscript<T>(dynamicMember key: KeyPath<Date.VerbatimFormatStyle, T>) -> T {
            base[keyPath: key]
        }

        public subscript<T>(dynamicMember key: WritableKeyPath<Date.VerbatimFormatStyle, T>) -> T {
            get {
                base[keyPath: key]
            }
            set {
                base[keyPath: key] = newValue
            }
        }

        init(style: Date.VerbatimFormatStyle) {
            self.base = style
        }

        public func format(_ value: Date) -> AttributedString {
            let fm = ICUDateFormatter.cachedFormatter(for: base)

            var result: AttributedString
            if let (str, attributes) = fm.attributedFormat(value) {
                result = str._attributedStringFromPositions(attributes)
            } else {
                result = AttributedString(value.description)
            }

            return result
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

// MARK: MatchingCollectionConsumer

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension Date.VerbatimFormatStyle : CustomConsumingRegexComponent {
    public typealias RegexOutput = Date
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Date)? {
        try parseStrategy.consuming(input, startingAt: index, in: bounds)
    }
}
