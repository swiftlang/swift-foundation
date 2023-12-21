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
extension BinaryFloatingPoint {

    /// Format `self` with `FloatingPointFormatStyle()`.
    public func formatted() -> String {
        FloatingPointFormatStyle().format(self)
    }

    /// Format `self` with the given format.
    public func formatted<S>(_ format: S) -> S.FormatOutput where Self == S.FormatInput, S : FormatStyle {
        format.format(self)
    }

    /// Format `self` with the given format. `self` is first converted to `S.FormatInput` type, then format with the given format.
    public func formatted<S>(_ format: S) -> S.FormatOutput where S : FormatStyle, S.FormatInput : BinaryFloatingPoint {
        format.format(S.FormatInput(self))
    }
}

// MARK: - BinaryFloatingPoint + Parsing

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension BinaryFloatingPoint {
    /// Initialize an instance by parsing `value` with the given `strategy`.
    public init<S: ParseStrategy>(_ value: S.ParseInput, strategy: S) throws where S.ParseOutput : BinaryFloatingPoint {
        let parsed = try strategy.parse(value)
        self = Self(parsed)
    }

    public init<S: ParseStrategy>(_ value: S.ParseInput, strategy: S) throws where S.ParseOutput == Self {
        self = try strategy.parse(value)
    }

    /// Initialize an instance by parsing `value` with a `ParseStrategy` created with the given `format` and the `lenient` argument.
    public init(_ value: String, format: FloatingPointFormatStyle<Self>, lenient: Bool = true) throws {
        let parsed = try FloatingPointParseStrategy(format: format, lenient: lenient).parse(value)
        self = Self(parsed)
    }

    public init(_ value: String, format: FloatingPointFormatStyle<Self>.Percent, lenient: Bool = true) throws {
        let parsed = try FloatingPointParseStrategy(format: format, lenient: lenient).parse(value)
        self = Self(parsed)
    }

    public init(_ value: String, format: FloatingPointFormatStyle<Self>.Currency, lenient: Bool = true) throws {
        let parsed = try FloatingPointParseStrategy(format: format, lenient: lenient).parse(value)
        self = Self(parsed)
    }
}
