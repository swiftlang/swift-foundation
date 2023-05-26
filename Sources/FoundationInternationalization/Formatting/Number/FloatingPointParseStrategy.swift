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
public struct FloatingPointParseStrategy<Format> : Codable, Hashable where Format : FormatStyle, Format.FormatInput : BinaryFloatingPoint {
    public var formatStyle: Format
    public var lenient: Bool
    var numberFormatType: ICULegacyNumberFormatter.NumberFormatType
    var locale: Locale
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension FloatingPointParseStrategy : Sendable where Format : Sendable {}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension FloatingPointParseStrategy: ParseStrategy {
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public func parse(_ value: String) throws -> Format.FormatInput {
        let parser = ICULegacyNumberFormatter.numberFormatterCreateIfNeeded(type: numberFormatType, locale: locale, lenient: lenient)
        if let v = parser.parseAsDouble(value._trimmingWhitespace()) {
            return Format.FormatInput(v)
        } else {
            let exampleString = formatStyle.format(3.14)
#if FOUNDATION_FRAMEWORK // TODO: Move `CocoaError`
            throw CocoaError(CocoaError.formatting, userInfo: [
                NSDebugDescriptionErrorKey: "Cannot parse \(value). String should adhere to the specified format, such as \(exampleString)" ])
#else
            throw CocoaError(
                .formatting,
                description: "Cannot parse \(value). String should adhere to the specified format, such as \(exampleString)")
#endif // FOUNDATION_FRAMEWORK
        }
    }

    // Regex component utility
    internal func parse(_ value: String, startingAt index: String.Index, in range: Range<String.Index>) -> (String.Index, Format.FormatInput)? {
        guard index < range.upperBound else {
            return nil
        }

        let parser = ICULegacyNumberFormatter.numberFormatterCreateIfNeeded(type: numberFormatType, locale: locale, lenient: lenient)
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
        self.locale = format.locale
        self.numberFormatType = .number(format.collection)
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FloatingPointParseStrategy {
    init<Value>(format: Format, lenient: Bool = true) where Format == FloatingPointFormatStyle<Value>.Currency {
        self.formatStyle = format
        self.lenient = lenient
        self.locale = format.locale
        self.numberFormatType = .currency(format.collection)
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FloatingPointParseStrategy {
    init<Value>(format: Format, lenient: Bool = true) where Format == FloatingPointFormatStyle<Value>.Percent {
        self.formatStyle = format
        self.lenient = lenient
        self.locale = format.locale
        self.numberFormatType = .percent(format.collection)
    }
}
