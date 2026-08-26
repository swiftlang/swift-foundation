//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

/// The direction an era counts its years.
internal enum _CalendarEraDirection: Sendable {
    /// Years count up from the anchor year, like every Japanese era and the Buddhist and Minguo eras.
    case forward
    /// Years count down from the anchor year, like ROC's Before-Minguo era.
    case backward
}

/// One era of a Gregorian-backed calendar.
internal struct _CalendarEraEntry: Sendable {
    /// The value `DateComponents.era` carries for this era. These match ICU's numbering.
    let code: Int
    /// The extended Gregorian year holding this era's boundary. A forward era numbers that year 1; a backward era counts down from it.
    let anchorYear: Int
    /// Month and day of the boundary within `anchorYear`.
    let startMonth: Int
    let startDay: Int
    let direction: _CalendarEraDirection
    /// True when the era labels dates before its boundary too. ICU's Buddhist era does this: 1000 BCE gets a Buddhist year but no era interval.
    let labelsEveryDate: Bool

    init(code: Int, anchorYear: Int, startMonth: Int, startDay: Int, direction: _CalendarEraDirection, labelsEveryDate: Bool = false) {
        self.code = code
        self.anchorYear = anchorYear
        self.startMonth = startMonth
        self.startDay = startDay
        self.direction = direction
        self.labelsEveryDate = labelsEveryDate
    }

    /// Whether this era labels the given date, expressed as an extended Gregorian year plus a month and day.
    func labels(extendedYear year: Int, month: Int, day: Int) -> Bool {
        if labelsEveryDate { return true }
        let isAtOrAfterBoundary = (year, month, day) >= (anchorYear, startMonth, startDay)
        return direction == .forward ? isAtOrAfterBoundary : !isAtOrAfterBoundary
    }

    /// This era's year number for a date in the given extended Gregorian year.
    func eraYear(fromExtendedYear year: Int) -> Int {
        switch direction {
        case .forward: return year - anchorYear + 1
        case .backward: return anchorYear - year
        }
    }

    /// The extended Gregorian year for a year number in this era.
    func extendedYear(fromEraYear year: Int) -> Int {
        switch direction {
        case .forward: return year + anchorYear - 1
        case .backward: return anchorYear - year
        }
    }
}

/// The eras of one Gregorian-backed calendar, newest first.
internal struct _CalendarEraTable: Sendable {
    let entries: [_CalendarEraEntry]

    /// The highest era code. Era ranges run from 0 up to this value, because codes 0 and 1 stay reserved for the Gregorian BCE and CE eras a calendar inherits.
    let highestCode: Int

    /// The code to assume when `DateComponents.era` is absent. ICU defaults to the newest era.
    let defaultCode: Int

    /// The anchor year of the newest era, which limits how high a year number can go once years are era-relative.
    let newestAnchorYear: Int

    /// True when an era can end as well as begin, so one era can cover a single year. The Japanese eras do; the Buddhist and Minguo eras run on without limit.
    let erasCanEnd: Bool

    init(_ entries: [_CalendarEraEntry]) {
        self.entries = entries
        self.highestCode = entries.map(\.code).max() ?? 0
        self.defaultCode = entries.first?.code ?? 0
        self.newestAnchorYear = entries.first?.anchorYear ?? 0
        self.erasCanEnd = entries.filter { $0.direction == .forward && !$0.labelsEveryDate }.count > 1
    }

    /// The era labeling the given date, or nil when the date falls before every era in the table.
    func entry(extendedYear year: Int, month: Int, day: Int) -> _CalendarEraEntry? {
        entries.first { $0.labels(extendedYear: year, month: month, day: day) }
    }

    func entry(code: Int) -> _CalendarEraEntry? {
        entries.first { $0.code == code }
    }

    /// The era that follows `entry`, or nil when `entry` is the newest one.
    func eraAfter(_ entry: _CalendarEraEntry) -> _CalendarEraEntry? {
        guard let index = entries.firstIndex(where: { $0.code == entry.code }), index > 0 else { return nil }
        return entries[index - 1]
    }
}
