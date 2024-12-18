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
public struct FloatingPointParseStrategy<Format> : Codable, Hashable where Format : FormatStyle, Format.FormatInput : BinaryFloatingPoint {
    public var formatStyle: Format
    public var lenient: Bool
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension FloatingPointParseStrategy : Sendable where Format : Sendable {}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension FloatingPointParseStrategy: ParseStrategy {
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public func parse(_ value: String) throws -> Format.FormatInput {
        let trimmedString = value._trimmingWhitespace()
        guard let result = try parse(trimmedString, startingAt: trimmedString.startIndex, in: trimmedString.startIndex..<trimmedString.endIndex) else {
            let exampleString = formatStyle.format(3.14)
            throw CocoaError(CocoaError.formatting, userInfo: [
                NSDebugDescriptionErrorKey: "Cannot parse \(value). String should adhere to the specified format, such as \(exampleString)" ])
        }
        return result.1
    }

    // Regex component utility
    internal func parse(_ value: String, startingAt index: String.Index, in range: Range<String.Index>) throws -> (String.Index, Format.FormatInput)? {
        guard index < range.upperBound else {
            return nil
        }

        let numberFormatType: ICULegacyNumberFormatter.NumberFormatType
        let locale: Locale

        if let format = formatStyle as? FloatingPointFormatStyle<Format.FormatInput> {
            numberFormatType = .number(format.collection)
            locale = format.locale
        } else if let format = formatStyle as? FloatingPointFormatStyle<Format.FormatInput>.Percent {
            numberFormatType = .percent(format.collection)
            locale = format.locale
        } else if let format = formatStyle as? FloatingPointFormatStyle<Format.FormatInput>.Currency {
            numberFormatType = .currency(format.collection, format.currencyCode)
            locale = format.locale
        } else {
            // For some reason we've managed to accept a format style of a type that we don't own, which shouldn't happen. Fallback to the default decimal style and try anyways.
            numberFormatType = .number(.init())
            locale = .autoupdatingCurrent
        }

        guard let parser = ICULegacyNumberFormatter.formatter(for: numberFormatType, locale: locale, lenient: lenient) else {
            throw CocoaError(CocoaError.formatting, userInfo: [
                NSDebugDescriptionErrorKey: "Cannot parse \(value), unable to create formatter" ])
        }
        let substr = value[index..<range.upperBound]
        var upperBound = 0
        if let value = parser.parseAsDouble(substr, upperBound: &upperBound) {
            let upperBoundInSubstr = String.Index(utf16Offset: upperBound, in: substr)
            return (upperBoundInSubstr, Format.FormatInput(value))
        } else {
            return nil
        }
    }

}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FloatingPointParseStrategy {
    init<Value>(format: Format, lenient: Bool = true) where Format == FloatingPointFormatStyle<Value> {
        self.formatStyle = format
        self.lenient = lenient
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FloatingPointParseStrategy {
    init<Value>(format: Format, lenient: Bool = true) where Format == FloatingPointFormatStyle<Value>.Currency {
        self.formatStyle = format
        self.lenient = lenient
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FloatingPointParseStrategy {
    init<Value>(format: Format, lenient: Bool = true) where Format == FloatingPointFormatStyle<Value>.Percent {
        self.formatStyle = format
        self.lenient = lenient
    }
}
