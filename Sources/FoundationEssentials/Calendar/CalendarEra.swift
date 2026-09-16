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

/// One era of a Gregorian-family calendar.
internal struct _CalendarEraEntry: Sendable {
    /// The value `DateComponents.era` carries for this era. These match ICU's numbering.
    let code: Int
    /// The extended Gregorian year holding this era's boundary. A forward era numbers that year 1. A backward era counts down from it.
    let anchorYear: Int
    /// Month and day of the boundary within `anchorYear`.
    let startMonth: Int
    let startDay: Int
    let direction: _CalendarEraDirection

    init(code: Int, anchorYear: Int, startMonth: Int, startDay: Int, direction: _CalendarEraDirection) {
        self.code = code
        self.anchorYear = anchorYear
        self.startMonth = startMonth
        self.startDay = startDay
        self.direction = direction
    }

    /// Whether this era labels the given date, expressed as an extended Gregorian year plus a month and day.
    func labels(extendedYear year: Int, month: Int, day: Int) -> Bool {
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

/// The eras of one Gregorian-family calendar, newest first.
internal struct _CalendarEraTable: Sendable {
    let entries: [_CalendarEraEntry]

    /// The highest era code. Era ranges run from 0 up to this value, because codes 0 and 1 stay reserved for the Gregorian BCE and CE eras a calendar inherits.
    let highestCode: Int

    /// The code to assume when `DateComponents.era` is absent, which is the newest era in the table.
    let defaultCode: Int

    /// The anchor year of the newest era, which limits how high a year number can go once years are era-relative.
    let newestAnchorYear: Int

    /// True when an era can end as well as begin, so one era can cover a single year. The Japanese eras do. The Buddhist and Minguo eras run on without limit.
    let erasCanEnd: Bool

    /// True when this table numbers every date itself, so no date falls back to an inherited Gregorian era.
    ///
    /// Only the Buddhist table does this. It numbers 1000 BCE as year -456, counting back past its own start. Japanese leaves dates before Meiji to the Gregorian era, and Gregorian and ROC have a backward era covering the early side.
    let coversEveryDate: Bool

    init(_ entries: [_CalendarEraEntry], erasCanEnd: Bool = false, coversEveryDate: Bool = false) {
        self.entries = entries
        self.highestCode = entries.map(\.code).max() ?? 0
        self.defaultCode = entries.first?.code ?? 0
        self.newestAnchorYear = entries.first?.anchorYear ?? 0
        self.erasCanEnd = erasCanEnd
        self.coversEveryDate = coversEveryDate
    }

    /// The era labeling the given date, or nil when the date falls before every era and the calendar inherits one instead.
    func entry(extendedYear year: Int, month: Int, day: Int) -> _CalendarEraEntry? {
        if let match = entries.first(where: { $0.labels(extendedYear: year, month: month, day: day) }) {
            return match
        }
        // Older than every era. A table that covers every date has one era, which numbers this date too.
        return coversEveryDate ? entries.last : nil
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

/// The era tables themselves, one per calendar that `_CalendarGregorian` serves.
///
/// These are stored properties, so each table is built once for the process. A function returning a fresh table would allocate on every calendar copy.
extension _CalendarEraTable {

    /// Gregorian and ISO8601. CE counts forward from year 1, and BCE counts backward from it.
    static let gregorian = _CalendarEraTable([
        _CalendarEraEntry(code: 1, anchorYear: 1, startMonth: 1, startDay: 1, direction: .forward),
        _CalendarEraEntry(code: 0, anchorYear: 1, startMonth: 1, startDay: 1, direction: .backward),
    ])

    /// One era, which numbers every date, including those before its own start. 1 CE is 544 BE.
    static let buddhist = _CalendarEraTable([
        _CalendarEraEntry(code: 0, anchorYear: -542, startMonth: 1, startDay: 1, direction: .forward)
    ], coversEveryDate: true)

    /// The five modern eras, newest first, with ICU's numbering (Meiji 232 through Reiwa 236).
    ///
    /// CLDR and ICU dropped the pre-Meiji eras (unicode-org/icu#4019, ICU-23341), so earlier dates keep the Gregorian era and codes 2 through 231 are unused.
    ///
    /// Meiji starts 1868-09-08 to match Apple's runtime ICU, where the CLDR canonical date is 1868-10-23.
    static let japanese = _CalendarEraTable([
        _CalendarEraEntry(code: 236, anchorYear: 2019, startMonth: 5, startDay: 1, direction: .forward),
        _CalendarEraEntry(code: 235, anchorYear: 1989, startMonth: 1, startDay: 8, direction: .forward),
        _CalendarEraEntry(code: 234, anchorYear: 1926, startMonth: 12, startDay: 25, direction: .forward),
        _CalendarEraEntry(code: 233, anchorYear: 1912, startMonth: 7, startDay: 30, direction: .forward),
        _CalendarEraEntry(code: 232, anchorYear: 1868, startMonth: 9, startDay: 8, direction: .forward),
    ], erasCanEnd: true)

    /// Two eras sharing the 1912 boundary, with ICU's numbering from `taiwncal.h` (Before-Minguo 0, Minguo 1).
    static let republicOfChina = _CalendarEraTable([
        _CalendarEraEntry(code: 1, anchorYear: 1912, startMonth: 1, startDay: 1, direction: .forward),
        _CalendarEraEntry(code: 0, anchorYear: 1912, startMonth: 1, startDay: 1, direction: .backward),
    ])

    /// An empty table, used to build a date from a year that is already extended so no era conversion applies.
    static let noRelabeling = _CalendarEraTable([])

    /// The table an identifier labels its eras with. Anything other than the three era-relabeling calendars uses the Gregorian eras.
    static func forCalendar(_ identifier: Calendar.Identifier) -> _CalendarEraTable {
        switch identifier {
        case .buddhist: return .buddhist
        case .japanese: return .japanese
        case .republicOfChina: return .republicOfChina
        default: return .gregorian
        }
    }
}
