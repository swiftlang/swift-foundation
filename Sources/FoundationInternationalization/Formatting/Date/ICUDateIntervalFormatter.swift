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

#if ICU
internal import _FoundationICU

final class ICUDateIntervalFormatter : @unchecked Sendable {
    struct Signature : Hashable {
        /// Never the autoupdating locale: that one is equal only to itself, but formats differently when the system settings change.
        let locale: Locale
        let calendarIdentifier: Calendar.Identifier
        let timeZoneIdentifier: String
        let dateTemplate: String
        let minimization: Date.IntervalFormatStyle.Minimization
    }
    
    internal static let cache = FormatterCache<Signature, ICUDateIntervalFormatter?>()

    /// `Sendable` notes: After initialization, we only use the ICU `udtitvfmt_format` function, which does not mutate the underlying formatter and is thread-safe.
    let uformatter: OpaquePointer // UDateIntervalFormat

    private init?(signature: Signature) {
        // The locale's preferences (such as hour cycle) are captured in the components, so they are part of the formatter.
        var comps = Locale.Components(locale: signature.locale)
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

        let minimize: UDateIntervalFormatAttributeValue = switch signature.minimization {
        case .none: UDTITVFMT_MINIMIZE_NONE
        case .adjacentDays: UDTITVFMT_MINIMIZE_ADJACENT_DAYS
        case .adjacentMonths: UDTITVFMT_MINIMIZE_ADJACENT_MONTHS
        }
        udtitvfmt_setAttribute(uformatter, UDTITVFMT_MINIMIZE_TYPE, minimize, &status)
        _ = status.checkSuccessAndLogError("udtitvfmt_setAttribute failed.")
    }

    deinit {
        udtitvfmt_close(uformatter)
    }

    func string(from: Range<Date>) -> String? {
        string(from: from.lowerBound, to: from.upperBound)
    }

    /// `from` may be later than `to`.
    func string(from: Date, to: Date) -> String? {
        let fromUDate = from.udate
        let toUDate = to.udate

        // Test cases show that 256 covers all known format outputs. If one is larger, though, we will correctly resize.
        return _withResizingUCharBuffer(initialSize: 256) { buffer, size, status in
            udtitvfmt_format(uformatter, fromUDate, toUDate, buffer, size, nil /* position */, &status)
        }
    }

    internal static func formatter(for style: Date.IntervalFormatStyle) -> ICUDateIntervalFormatter? {
        var template: String
        if let override = style.templateOverride {
            template = override
        } else {
            template = style.symbols.formatterTemplate(overridingDayPeriodWithLocale: style.locale)

            if template.isEmpty {
                let defaultSymbols = Date.FormatStyle.DateFieldCollection()
                    .collection(date: .numeric)
                    .collection(time: .shortened)
                template = defaultSymbols.formatterTemplate(overridingDayPeriodWithLocale: style.locale)
            }
        }

        // Key on the locale itself (its identifier and special preferences) so that the components are only built when the formatter is created. An autoupdating locale is replaced by what it currently stands for.
        var locale = style.locale
        if locale == .autoupdatingCurrent {
            locale = .current
        }
        let signature = Signature(locale: locale, calendarIdentifier: style.calendar.identifier, timeZoneIdentifier: style.timeZone.identifier, dateTemplate: template, minimization: style.minimization)
        
        return Self.cache.formatter(for: signature) {
            ICUDateIntervalFormatter(signature: signature)
        }
    }
}

#endif // ICU
