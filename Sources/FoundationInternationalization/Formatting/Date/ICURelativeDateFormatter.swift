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

internal import FoundationICU

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
internal final class ICURelativeDateFormatter {
    struct Signature : Hashable {
        let localeIdentifier: String
        let numberFormatStyle: UNumberFormatStyle.RawValue?
        let relativeDateStyle: UDateRelativeDateTimeFormatterStyle.RawValue
        let context: UDisplayContext.RawValue
    }
    
    static let sortedAllowedComponents : [Calendar.Component] = [ .year, .month, .weekOfMonth, .day, .hour, .minute, .second ]

    static let componentsToURelativeDateUnit : [Calendar.Component: URelativeDateTimeUnit] = [
        .year: .year,
        .month: .month,
        .weekOfMonth: .week,
        .day: .day,
        .hour: .hour,
        .minute: .minute,
        .second: .second
    ]

    let uformatter: OpaquePointer

    internal static let cache = FormatterCache<Signature, ICURelativeDateFormatter?>()

    private init?(signature: Signature) {
        var status = U_ZERO_ERROR
        let numberFormat: UnsafeMutablePointer<UNumberFormat?>?
        if let numberFormatStyle = signature.numberFormatStyle {
            // The uformatter takes ownership of this after we pass it to the open call below
            numberFormat = unum_open(UNumberFormatStyle(rawValue: numberFormatStyle), nil, 0, signature.localeIdentifier, nil, &status)
            // If status is not a success, simply use nil
        } else {
            numberFormat = nil
        }

        let result = ureldatefmt_open(signature.localeIdentifier, numberFormat, UDateRelativeDateTimeFormatterStyle(rawValue: signature.relativeDateStyle), UDisplayContext(rawValue: signature.context), &status)
        guard let result, status.isSuccess else { return nil }
        uformatter = result
    }

    deinit {
        ureldatefmt_close(uformatter)
    }

    func format(value: Int, component: Calendar.Component, presentation: Date.RelativeFormatStyle.Presentation) -> String? {
        guard let urelUnit = Self.componentsToURelativeDateUnit[component] else { return nil }
        switch presentation.option {
        case .named:
            return _withResizingUCharBuffer { buffer, size, status in
                ureldatefmt_format(uformatter, Double(value), urelUnit, buffer, size, &status)
            }
        case .numeric:
            return _withResizingUCharBuffer { buffer, size, status in
                ureldatefmt_formatNumeric(uformatter, Double(value), urelUnit, buffer, size, &status)
            }
        }
    }

    internal static func formatter(for style: Date.RelativeFormatStyle) -> ICURelativeDateFormatter {
        let signature = Signature(localeIdentifier: style.locale.identifier, numberFormatStyle: style.unitsStyle.icuNumberFormatStyle?.rawValue, relativeDateStyle: style.unitsStyle.icuRelativeDateStyle.rawValue, context: style.capitalizationContext.icuContext.rawValue)
        let formatter = Self.cache.formatter(for: signature) {
            ICURelativeDateFormatter(signature: signature)
        }

        return formatter!
    }

}
