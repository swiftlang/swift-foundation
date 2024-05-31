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

internal import _FoundationICU

final class ICUDateIntervalFormatter {
    struct Signature : Hashable {
        let localeComponents: Locale.Components
        let calendarIdentifier: Calendar.Identifier
        let timeZoneIdentifier: String
        let dateTemplate: String
    }
    
    internal static let cache = FormatterCache<Signature, ICUDateIntervalFormatter?>()

    let uformatter: OpaquePointer // UDateIntervalFormat

    private init?(signature: Signature) {
        var comps = signature.localeComponents
        comps.calendar = signature.calendarIdentifier
        let id = comps.icuIdentifier

        let tz16 = Array(signature.timeZoneIdentifier.utf16)
        let dateTemplate16 = Array(signature.dateTemplate.utf16)

        var status = U_ZERO_ERROR
        let formatter = tz16.withUnsafeBufferPointer { tz in
            dateTemplate16.withUnsafeBufferPointer { template in
                udtitvfmt_open(id, template.baseAddress, Int32(template.count), tz.baseAddress, Int32(tz.count), &status)
            }
        }

        guard status.checkSuccessAndLogError("udtitvfmt_open failed."), let formatter else {
            if (formatter != nil) {
                udtitvfmt_close(formatter)
            }
            return nil
        }

        uformatter = formatter

        udtitvfmt_setAttribute(uformatter, UDTITVFMT_MINIMIZE_TYPE, UDTITVFMT_MINIMIZE_NONE, &status)
        _ = status.checkSuccessAndLogError("udtitvfmt_setAttribute failed.")
    }

    deinit {
        udtitvfmt_close(uformatter)
    }

    func string(from: Range<Date>) -> String? {
        let fromUDate = from.lowerBound.udate
        let toUDate = from.upperBound.udate

        return _withResizingUCharBuffer { buffer, size, status in
            udtitvfmt_format(uformatter, fromUDate, toUDate, buffer, size, nil /* position */, &status)
        }
    }

    internal static func formatter(for style: Date.IntervalFormatStyle) -> ICUDateIntervalFormatter? {
        var template = style.symbols.formatterTemplate(overridingDayPeriodWithLocale: style.locale)

        if template.isEmpty {
            let defaultSymbols = Date.FormatStyle.DateFieldCollection()
                .collection(date: .numeric)
                .collection(time: .shortened)
            template = defaultSymbols.formatterTemplate(overridingDayPeriodWithLocale: style.locale)
        }

        // This captures all of the special preferences that may be set on the locale
        let comps = Locale.Components(locale: style.locale)
        let signature = Signature(localeComponents: comps, calendarIdentifier: style.calendar.identifier, timeZoneIdentifier: style.timeZone.identifier, dateTemplate: template)
        
        return Self.cache.formatter(for: signature) {
            ICUDateIntervalFormatter(signature: signature)
        }
    }
}
