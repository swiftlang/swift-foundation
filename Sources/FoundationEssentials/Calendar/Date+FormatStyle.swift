//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

// MARK: Date Extensions

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date {
    /// Generates a locale-aware string representation of a date using the specified date format style.
    ///
    /// For full customization of the string representation of a date, use the `formatted(_:)` instance method of `Date` and provide a ``Date/FormatStyle`` object.
    ///
    /// You can achieve any customization of date and time representation your app requires by applying a series of convenience modifiers to your format style. This example applies a series of modifiers to the format style to precisely define the formatting of the year, month, day, hour, minute, and timezone components of the resulting string.
    ///
    /// ```swift
    /// let birthday = Date()
    ///
    /// birthday.formatted(
    ///     Date.FormatStyle()
    ///         .year(.defaultDigits)
    ///         .month(.abbreviated)
    ///         .day(.twoDigits)
    ///         .hour(.defaultDigits(amPM: .abbreviated))
    ///         .minute(.twoDigits)
    ///         .timeZone(.identifier(.long))
    ///         .era(.wide)
    ///         .dayOfYear(.defaultDigits)
    ///         .weekday(.abbreviated)
    ///         .week(.defaultDigits)
    /// )
    /// // Sun, Jan 17, 2021 Anno Domini (week: 4), 11:18 AM America/Chicago
    /// ```
    ///
    /// For the default date formatting, use the ``Date/formatted()`` method. For basic customization of the formatted date string, use the ``Date/formatted(date:time:)`` and include a date and time style.
    ///
    /// For more information about formatting dates, see ``Date/FormatStyle``.
    ///
    /// - Parameter format: The format for formatting `self`.
    /// - Returns: A representation of `self` using the given `format`. The type of the representation is specified by `FormatStyle.FormatOutput`.
#if FOUNDATION_FRAMEWORK
    public func formatted<F: Foundation.FormatStyle>(_ format: F) -> F.FormatOutput where F.FormatInput == Date {
        format.format(self)
    }
#else
    public func formatted<F: FoundationEssentials.FormatStyle>(_ format: F) -> F.FormatOutput where F.FormatInput == Date {
        format.format(self)
    }
#endif // FOUNDATION_FRAMEWORK
    
    // Parsing
    /// Creates a new `Date` by parsing the given representation.
    /// - Parameter value: A representation of a date. The type of the representation is specified by `ParseStrategy.ParseInput`.
    /// - Parameters:
    ///   - value: A representation of a date. The type of the representation is specified by `ParseStrategy.ParseInput`.
    ///   - strategy: The parse strategy to parse `value` whose `ParseOutput` is `Date`.
#if FOUNDATION_FRAMEWORK
    public init<T: Foundation.ParseStrategy>(_ value: T.ParseInput, strategy: T) throws where T.ParseOutput == Self {
        self = try strategy.parse(value)
    }
#else
    public init<T: FoundationEssentials.ParseStrategy>(_ value: T.ParseInput, strategy: T) throws where T.ParseOutput == Self {
        self = try strategy.parse(value)
    }
#endif // FOUNDATION_FRAMEWORK
    /// Creates a new `Date` by parsing the given string representation.
#if FOUNDATION_FRAMEWORK
    @_disfavoredOverload
    public init<T: Foundation.ParseStrategy, Value: StringProtocol>(_ value: Value, strategy: T) throws where T.ParseOutput == Self, T.ParseInput == String {
        self = try strategy.parse(String(value))
    }
#else
    @_disfavoredOverload
    public init<T: FoundationEssentials.ParseStrategy, Value: StringProtocol>(_ value: Value, strategy: T) throws where T.ParseOutput == Self, T.ParseInput == String {
        self = try strategy.parse(String(value))
    }
#endif // FOUNDATION_FRAMEWORK
}

@available(FoundationPreview 6.2, *)
extension DateComponents {
    /// Converts `self` to its textual representation.
    /// - Parameter format: The format for formatting `self`.
    /// - Returns: A representation of `self` using the given `format`. The type of the representation is specified by `FormatStyle.FormatOutput`.
    public func formatted<F: FormatStyle>(_ format: F) -> F.FormatOutput where F.FormatInput == DateComponents {
        format.format(self)
    }
    
    // Parsing
    /// Creates a new `DateComponents` by parsing the given representation.
    /// - Parameters:
    ///   - value: A representation of a date. The type of the representation is specified by `ParseStrategy.ParseInput`.
    ///   - strategy: The parse strategy to parse `value` whose `ParseOutput` is `DateComponents`.
    public init<T: ParseStrategy>(_ value: T.ParseInput, strategy: T) throws where T.ParseOutput == Self {
        self = try strategy.parse(value)
    }

    /// Creates a new `DateComponents` by parsing the given string representation.
    @_disfavoredOverload
    public init<T: ParseStrategy, Value: StringProtocol>(_ value: Value, strategy: T) throws where T.ParseOutput == Self, T.ParseInput == String {
        self = try strategy.parse(String(value))
    }
}
