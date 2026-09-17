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

/// One era of a Gregorian-family calendar.
internal struct _GregorianFamilyCalendarEra: Sendable {

    /// The direction an era counts its years.
    enum Direction: Sendable {
        /// Years count up from the anchor year, like every Japanese era and the Buddhist and Minguo eras.
        case forward
        /// Years count down from the anchor year, like ROC's Before-Minguo era.
        case backward
    }

    /// The value `DateComponents.era` carries for this era. CLDR assigns these numbers, so Meiji is 232 rather than a count from the start of this table.
    let eraNumber: Int
    /// The extended Gregorian year holding this era's boundary. A forward era numbers that year 1. A backward era counts down from it.
    let anchorYear: Int
    /// Month and day of the boundary within `anchorYear`.
    let startMonth: Int
    let startDay: Int
    let direction: Direction

    init(eraNumber: Int, anchorYear: Int, startMonth: Int, startDay: Int, direction: Direction) {
        self.eraNumber = eraNumber
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
internal struct _GregorianFamilyCalendarEras: Sendable {
    let entries: [_GregorianFamilyCalendarEra]

    /// The highest era number. Era ranges run from 0 up to this value, because 0 and 1 stay reserved for the Gregorian BCE and CE eras a calendar inherits.
    let maxEraNumber: Int

    /// The era number to assume when `DateComponents.era` is absent, which is the newest era in the table.
    let defaultEraNumber: Int

    /// The anchor year of the newest era, which limits how high a year number can go once years are era-relative.
    let newestAnchorYear: Int

    /// True when an era can end as well as begin, so one era can cover a single year. The Japanese eras do. The Buddhist and Minguo eras run on without limit.
    let erasCanEnd: Bool

    /// True when this table numbers every date itself, so no date falls back to an inherited Gregorian era.
    ///
    /// Only the Buddhist table does this. It numbers 1000 BCE as year -456, counting back past its own start.
    ///
    /// Japanese leaves dates before Meiji to the Gregorian era. Gregorian and ROC have a backward era covering the early side.
    let coversEveryDate: Bool

    /// The number of the era that counts its years backward, when the table has one. Gregorian BCE and ROC Before-Minguo are the only ones.
    ///
    /// Read from `entries` rather than declared, because it is a plain fact about the data and cannot disagree with it.
    let backwardEraNumber: Int?

    /// Whether era number 0 comes from the inherited Gregorian eras rather than from this table. When it does, a caller asking for era 0 means BCE, which is how Japanese reads a pre-Meiji date.
    let eraNumberZeroIsInherited: Bool

    /// Every era indexed by its number, offset by `lowestEraNumber`, so a lookup by number is one array read rather than a search.
    ///
    /// CLDR numbers a calendar's eras consecutively, so this stays small. Japanese holds five slots and the rest hold one or two.
    private let erasByNumber: [_GregorianFamilyCalendarEra?]

    /// The offset applied to an era number before indexing `erasByNumber`.
    private let lowestEraNumber: Int

    init(_ entries: [_GregorianFamilyCalendarEra], erasCanEnd: Bool = false, coversEveryDate: Bool = false) {
        self.entries = entries
        self.maxEraNumber = entries.map(\.eraNumber).max() ?? 0
        self.defaultEraNumber = entries.first?.eraNumber ?? 0
        self.newestAnchorYear = entries.first?.anchorYear ?? 0
        self.erasCanEnd = erasCanEnd
        self.coversEveryDate = coversEveryDate
        self.backwardEraNumber = entries.first { $0.direction == .backward }?.eraNumber
        self.eraNumberZeroIsInherited = !entries.contains { $0.eraNumber == 0 }

        let lowest = entries.map(\.eraNumber).min() ?? 0
        self.lowestEraNumber = lowest
        if let highest = entries.map(\.eraNumber).max() {
            var slots = [_GregorianFamilyCalendarEra?](repeating: nil, count: highest - lowest + 1)
            for era in entries {
                slots[era.eraNumber - lowest] = era
            }
            self.erasByNumber = slots
        } else {
            self.erasByNumber = []
        }
    }

    /// The era labeling the given date, or nil when the date falls before every era and the calendar inherits one instead.
    func entry(extendedYear year: Int, month: Int, day: Int) -> _GregorianFamilyCalendarEra? {
        if let match = entries.first(where: { $0.labels(extendedYear: year, month: month, day: day) }) {
            return match
        }
        // Older than every era. A table that covers every date has one era, which numbers this date too.
        return coversEveryDate ? entries.last : nil
    }

    /// The era with the given number, or nil when this table does not define it.
    func entry(eraNumber: Int) -> _GregorianFamilyCalendarEra? {
        let index = eraNumber - lowestEraNumber
        guard erasByNumber.indices.contains(index) else { return nil }
        return erasByNumber[index]
    }
}

/// The era tables themselves, one per calendar that `_CalendarGregorian` serves.
///
/// These are stored properties, so each table is built once for the process. A function returning a fresh table would allocate on every calendar copy.
extension _GregorianFamilyCalendarEras {

    /// Gregorian and ISO8601. CE counts forward from year 1, and BCE counts backward from it.
    static let gregorian = _GregorianFamilyCalendarEras([
        _GregorianFamilyCalendarEra(eraNumber: 1, anchorYear: 1, startMonth: 1, startDay: 1, direction: .forward),
        _GregorianFamilyCalendarEra(eraNumber: 0, anchorYear: 1, startMonth: 1, startDay: 1, direction: .backward),
    ])

    /// One era, which numbers every date, including those before its own start. 1 CE is 544 BE.
    static let buddhist = _GregorianFamilyCalendarEras([
        _GregorianFamilyCalendarEra(eraNumber: 0, anchorYear: -542, startMonth: 1, startDay: 1, direction: .forward)
    ], coversEveryDate: true)

    /// The five modern eras, newest first, with ICU's numbering (Meiji 232 through Reiwa 236).
    ///
    /// CLDR and ICU dropped the pre-Meiji eras (unicode-org/icu#4019, ICU-23341), so earlier dates keep the Gregorian era and numbers 2 through 231 are unused.
    ///
    /// Meiji starts 1868-09-08 to match Apple's runtime ICU, where the CLDR canonical date is 1868-10-23.
    static let japanese = _GregorianFamilyCalendarEras([
        _GregorianFamilyCalendarEra(eraNumber: 236, anchorYear: 2019, startMonth: 5, startDay: 1, direction: .forward),
        _GregorianFamilyCalendarEra(eraNumber: 235, anchorYear: 1989, startMonth: 1, startDay: 8, direction: .forward),
        _GregorianFamilyCalendarEra(eraNumber: 234, anchorYear: 1926, startMonth: 12, startDay: 25, direction: .forward),
        _GregorianFamilyCalendarEra(eraNumber: 233, anchorYear: 1912, startMonth: 7, startDay: 30, direction: .forward),
        _GregorianFamilyCalendarEra(eraNumber: 232, anchorYear: 1868, startMonth: 9, startDay: 8, direction: .forward),
    ], erasCanEnd: true)

    /// Two eras sharing the 1912 boundary, with ICU's numbering from `taiwncal.h` (Before-Minguo 0, Minguo 1).
    static let republicOfChina = _GregorianFamilyCalendarEras([
        _GregorianFamilyCalendarEra(eraNumber: 1, anchorYear: 1912, startMonth: 1, startDay: 1, direction: .forward),
        _GregorianFamilyCalendarEra(eraNumber: 0, anchorYear: 1912, startMonth: 1, startDay: 1, direction: .backward),
    ])

    /// An empty table, used to build a date from a year that is already extended so no era conversion applies.
    static let noRelabeling = _GregorianFamilyCalendarEras([])

    /// The table an identifier labels its eras with. Anything other than the three era-relabeling calendars uses the Gregorian eras.
    static func forCalendar(_ identifier: Calendar.Identifier) -> _GregorianFamilyCalendarEras {
        switch identifier {
        case .buddhist: return .buddhist
        case .japanese: return .japanese
        case .republicOfChina: return .republicOfChina
        default: return .gregorian
        }
    }
}
