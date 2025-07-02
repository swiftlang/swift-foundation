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
        #if FOUNDATION_FRAMEWORK
        @available(macOS, deprecated: 15, introduced: 12, message: "Use attributedStyle instead")
        @available(iOS, deprecated: 18, introduced: 15, message: "Use attributedStyle instead")
        @available(tvOS, deprecated: 18, introduced: 15, message: "Use attributedStyle instead")
        @available(watchOS, deprecated: 11, introduced: 8, message: "Use attributedStyle instead")
        #else
        @available(macOS, deprecated: 26, introduced: 26, message: "Use attributedStyle instead")
        @available(iOS, deprecated: 26, introduced: 26, message: "Use attributedStyle instead")
        @available(tvOS, deprecated: 26, introduced: 26, message: "Use attributedStyle instead")
        @available(watchOS, deprecated: 26, introduced: 26, message: "Use attributedStyle instead")
        #endif
        public var attributed: AttributedStyle {
            .init(style: .verbatimFormatStyle(self))
        }

        public func format(_ value: Date) -> String {
            guard let fm = ICUDateFormatter.cachedFormatter(for: self), let result = fm.format(value) else {
                return value.description
            }

            return result
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

@available(FoundationAttributedString 6.0, *)
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
            guard let fm = ICUDateFormatter.cachedFormatter(for: base), let (str, attributes) = fm.attributedFormat(value) else {
                return AttributedString(value.description)
            }

            return str._attributedStringFromPositions(attributes)
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

// MARK: DiscreteFormatStyle Conformance

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
extension Date.VerbatimFormatStyle : DiscreteFormatStyle {
    public func discreteInput(before input: Date) -> Date? {
        guard let (bound, isIncluded) = bound(for: input, isLower: true) else {
            return nil
        }

        return isIncluded ? bound.nextDown : bound
    }

    public func discreteInput(after input: Date) -> Date? {
        guard let (bound, isIncluded) = bound(for: input, isLower: false) else {
            return nil
        }

        return isIncluded ? bound.nextUp : bound
    }

    public func input(before input: Date) -> Date? {
        let result = Calendar.nextAccuracyStep(for: input, direction: .backward)

        return result < input ? result : nil
    }

    public func input(after input: Date) -> Date? {
        let result = Calendar.nextAccuracyStep(for: input, direction: .forward)

        return result > input ? result : nil
    }

    func bound(for input: Date, isLower: Bool) -> (bound: Date, includedInRangeOfInput: Bool)? {
        var calendar = calendar
        calendar.timeZone = timeZone
        return calendar.bound(for: input, isLower: isLower, updateSchedule: ICUDateFormatter.DateFormatInfo.cachedUpdateSchedule(for: self))
    }
}

@available(FoundationAttributedString 6.0, *)
extension Date.VerbatimFormatStyle.Attributed : DiscreteFormatStyle {
    public func discreteInput(before input: Date) -> Date? {
        base.discreteInput(before: input)
    }

    public func discreteInput(after input: Date) -> Date? {
        base.discreteInput(after: input)
    }

    public func input(before input: Date) -> Date? {
        base.input(before: input)
    }

    public func input(after input: Date) -> Date? {
        base.input(after: input)
    }
}
