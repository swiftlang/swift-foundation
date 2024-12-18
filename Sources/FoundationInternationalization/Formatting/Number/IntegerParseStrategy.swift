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
public struct IntegerParseStrategy<Format> : Codable, Hashable where Format : FormatStyle, Format.FormatInput : BinaryInteger {
    public var formatStyle: Format
    public var lenient: Bool
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension IntegerParseStrategy : Sendable where Format : Sendable {}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension IntegerParseStrategy: ParseStrategy {
    public func parse(_ value: String) throws -> Format.FormatInput {
        let trimmedString = value._trimmingWhitespace()
        guard let result = try parse(trimmedString, startingAt: trimmedString.startIndex, in: trimmedString.startIndex..<trimmedString.endIndex) else {
            let exampleString = formatStyle.format(123)
            throw CocoaError(CocoaError.formatting, userInfo: [
                NSDebugDescriptionErrorKey: "Cannot parse \(value). String should adhere to the specified format, such as \(exampleString)" ])
        }
        return result.1
    }

    internal func parse(_ value: String, startingAt index: String.Index, in range: Range<String.Index>) throws -> (String.Index, Format.FormatInput)? {
        guard index < range.upperBound else {
            return nil
        }

        let numberFormatType: ICULegacyNumberFormatter.NumberFormatType
        let locale: Locale

        if let format = formatStyle as? IntegerFormatStyle<Format.FormatInput> {
            numberFormatType = .number(format.collection)
            locale = format.locale
        } else if let format = formatStyle as? IntegerFormatStyle<Format.FormatInput>.Percent {
            numberFormatType = .percent(format.collection)
            locale = format.locale
        } else if let format = formatStyle as? IntegerFormatStyle<Format.FormatInput>.Currency {
            numberFormatType = .currency(format.collection, currencyCode: format.currencyCode)
            locale = format.locale
        } else {
            // For some reason we've managed to accept a format style of a type that we don't own, which shouldn't happen. Fallback to the default decimal style and try anyways.
            numberFormatType = .number(.init())
            locale = .autoupdatingCurrent
        }

        guard let parser = ICULegacyNumberFormatter.formatter(for: numberFormatType, locale: locale, lenient: lenient) else {
            return nil
        }
        let substr = value[index..<range.upperBound]
        var upperBound = 0
        if let value = parser.parseAsInt(substr, upperBound: &upperBound) {
            guard let exact = Format.FormatInput(exactly: value) else {
                throw CocoaError(CocoaError.formatting, userInfo: [
                    NSDebugDescriptionErrorKey: "Cannot parse \(value). The number does not fall within the valid bounds of the specified output type" ])
            }
            let upperBoundInSubstr = String.Index(utf16Offset: upperBound, in: substr)
            return (upperBoundInSubstr, exact)
        } else if let value = parser.parseAsDouble(substr, upperBound: &upperBound) {
            guard value.magnitude < Double(sign: .plus, exponent: Double.significandBitCount + 1, significand: 1) else {
                throw CocoaError(CocoaError.formatting, userInfo: [
                    NSDebugDescriptionErrorKey: "Cannot parse \(value). The number does not fall within the lossless floating-point range" ])
            }
            guard let exact = Format.FormatInput(exactly: value) else {
                throw CocoaError(CocoaError.formatting, userInfo: [
                    NSDebugDescriptionErrorKey: "Cannot parse \(value). The number does not fall within the valid bounds of the specified output type" ])
            }
            let upperBoundInSubstr = String.Index(utf16Offset: upperBound, in: substr)
            return (upperBoundInSubstr, exact)
        }

        return nil
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension IntegerParseStrategy {
    init<Value>(format: Format, lenient: Bool = true) where Format == IntegerFormatStyle<Value> {
        self.formatStyle = format
        self.lenient = lenient
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension IntegerParseStrategy {
    init<Value>(format: Format, lenient: Bool = true) where Format == IntegerFormatStyle<Value>.Percent {
        self.formatStyle = format
        self.lenient = lenient
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension IntegerParseStrategy {
    init<Value>(format: Format, lenient: Bool = true) where Format == IntegerFormatStyle<Value>.Currency {
        self.formatStyle = format
        self.lenient = lenient
    }
}
