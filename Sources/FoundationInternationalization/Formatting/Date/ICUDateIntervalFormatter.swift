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

final class ICUDateIntervalFormatter : Hashable {
    let locale: Locale
    let calendar: Calendar
    let timeZone: TimeZone
    let dateTemplate: String

    let uformatter: OpaquePointer // UDateIntervalFormat

    init(locale: Locale, calendar: Calendar, timeZone: TimeZone, dateTemplate: String) {
        self.locale = locale
        self.calendar = calendar
        self.timeZone = timeZone
        self.dateTemplate = dateTemplate

        var comps = Locale.Components(locale: locale)
        comps.calendar = calendar.identifier
        let id = comps.identifier

        let tz16 = Array(timeZone.identifier.utf16)
        let dateTemplate16 = Array(dateTemplate.utf16)

        var status = U_ZERO_ERROR
        uformatter = tz16.withUnsafeBufferPointer { tz in
            dateTemplate16.withUnsafeBufferPointer { template in
                udtitvfmt_open(id, template.baseAddress, Int32(template.count), tz.baseAddress, Int32(tz.count), &status)
            }
        }

        try! status.checkSuccess()

        udtitvfmt_setAttribute(uformatter, UDTITVFMT_MINIMIZE_TYPE, UDTITVFMT_MINIMIZE_NONE, &status)

        try! status.checkSuccess()
    }

    deinit {
        udtitvfmt_close(uformatter)
    }

    func string(from: Range<Date>) -> String {
        let fromUDate = from.lowerBound.udate
        let toUDate = from.upperBound.udate

        let result = _withResizingUCharBuffer { buffer, size, status in
            udtitvfmt_format(uformatter, fromUDate, toUDate, buffer, size, nil /* position */, &status)
        }

        if let result { return result }
        return ""
    }

    static func == (lhs: ICUDateIntervalFormatter, rhs: ICUDateIntervalFormatter) -> Bool {
        lhs.locale == rhs.locale && lhs.calendar == rhs.calendar && lhs.timeZone == rhs.timeZone && lhs.dateTemplate == rhs.dateTemplate
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(locale)
        hasher.combine(calendar)
        hasher.combine(timeZone)
        hasher.combine(dateTemplate)
    }
}
