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

@_implementationOnly import FoundationICU

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
internal final class ICURelativeDateFormatter {

    static let sortedAllowedComponents: [Calendar.Component] = [ .year, .month, .weekOfMonth, .day, .hour, .minute, .second ]

    static let componentsToURelativeDateUnit: [Calendar.Component: URelativeDateTimeUnit] = [
        .year: .year,
        .month: .month,
        .weekOfMonth: .week,
        .day: .day,
        .hour: .hour,
        .minute: .minute,
        .second: .second
    ]

    let uformatter: OpaquePointer

    internal static let cache = FormatterCache<AnyHashable, ICURelativeDateFormatter?>()

    private init?(uNumberFormatStyle: UNumberFormatStyle?, uRelDateStyle: UDateRelativeDateTimeFormatterStyle, locale: Locale, context: UDisplayContext) {
        var status = U_ZERO_ERROR
        let numberFormat: UnsafeMutablePointer<UNumberFormat?>?
        if let uNumberFormatStyle {
            // The uformatter takes ownership of this after we pass it to the open call below
            numberFormat = unum_open(uNumberFormatStyle, nil, 0, locale.identifier, nil, &status)
            // If status is not a success, simply use nil
        } else {
            numberFormat = nil
        }

        let result = ureldatefmt_open(locale.identifier, numberFormat, uRelDateStyle, context, &status)
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

    internal static func formatterCreateIfNeeded(format: Date.RelativeFormatStyle) -> ICURelativeDateFormatter {
        let formatter = Self.cache.formatter(for: format) {
            ICURelativeDateFormatter(uNumberFormatStyle: format.unitsStyle.icuNumberFormatStyle, uRelDateStyle: format.unitsStyle.icuRelativeDateStyle, locale: format.locale, context: format.capitalizationContext.icuContext)
        }

        return formatter!
    }

}
