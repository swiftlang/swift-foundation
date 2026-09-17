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
internal struct GregorianFamilyCalendarEra: Sendable {

    /// The value `DateComponents.era` carries for this era. These are assigned numbers rather than positions in this table, so Meiji is 232.
    let eraNumber: Int
    /// The extended Gregorian year holding this era's boundary. A forward era numbers that year 1. A backward era counts down from it.
    let anchorYear: Int
    /// Month and day of the boundary within `anchorYear`.
    let startMonth: Int
    let startDay: Int
    /// Whether years count up from the anchor year, as every Japanese era and the Buddhist and Minguo eras do, or down from it, as ROC's Before-Minguo era does.
    let direction: Calendar.SearchDirection

    init(eraNumber: Int, anchorYear: Int, startMonth: Int, startDay: Int, direction: Calendar.SearchDirection) {
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
internal struct GregorianFamilyCalendarEras: Sendable {
    let entries: [GregorianFamilyCalendarEra]

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
    /// Only Buddhist does this. It numbers 1000 BCE as year -456, counting back past its own start.
    let coversEveryDate: Bool

    /// The number of the era that counts its years backward, when the table has one. Gregorian BCE and ROC Before-Minguo are the only ones.
    let backwardEraNumber: Int?

    /// Whether era number 0 comes from the inherited Gregorian eras rather than from this table. A caller asking for era 0 then means BCE.
    let eraNumberZeroIsInherited: Bool

    /// Every era indexed by its number, offset by `lowestEraNumber`, so a lookup by number is one array read.
    ///
    /// Era numbers run consecutively, so this holds five slots for Japanese and one or two for the rest.
    private let erasByNumber: [GregorianFamilyCalendarEra?]

    /// The offset applied to an era number before indexing `erasByNumber`.
    private let lowestEraNumber: Int

    init(_ entries: [GregorianFamilyCalendarEra], erasCanEnd: Bool = false, coversEveryDate: Bool = false) {
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
            var slots = [GregorianFamilyCalendarEra?](repeating: nil, count: highest - lowest + 1)
            for era in entries {
                slots[era.eraNumber - lowest] = era
            }
            self.erasByNumber = slots
        } else {
            self.erasByNumber = []
        }
    }

    /// The era labeling the given date, or nil when the date falls before every era and the calendar inherits one instead.
    func entry(extendedYear year: Int, month: Int, day: Int) -> GregorianFamilyCalendarEra? {
        if let match = entries.first(where: { $0.labels(extendedYear: year, month: month, day: day) }) {
            return match
        }
        // Older than every era. A table that covers every date has one era, which numbers this date too.
        return coversEveryDate ? entries.last : nil
    }

    /// The era with the given number, or nil when this table does not define it.
    func entry(eraNumber: Int) -> GregorianFamilyCalendarEra? {
        let index = eraNumber - lowestEraNumber
        guard erasByNumber.indices.contains(index) else { return nil }
        return erasByNumber[index]
    }
}

/// The era tables, one per calendar that `_CalendarGregorian` serves. Stored properties, so each is built once rather than on every calendar copy.
extension GregorianFamilyCalendarEras {

    /// Gregorian and ISO8601. CE counts forward from year 1, and BCE counts backward from it.
    static let gregorian = GregorianFamilyCalendarEras([
        GregorianFamilyCalendarEra(eraNumber: 1, anchorYear: 1, startMonth: 1, startDay: 1, direction: .forward),
        GregorianFamilyCalendarEra(eraNumber: 0, anchorYear: 1, startMonth: 1, startDay: 1, direction: .backward),
    ])

    /// One era, which numbers every date, including those before its own start. 1 CE is 544 BE.
    static let buddhist = GregorianFamilyCalendarEras([
        GregorianFamilyCalendarEra(eraNumber: 0, anchorYear: -542, startMonth: 1, startDay: 1, direction: .forward)
    ], coversEveryDate: true)

    /// The five modern eras, newest first, numbered Meiji 232 through Reiwa 236.
    ///
    /// Earlier eras are not listed, so a date before Meiji reports the inherited Gregorian era. Numbers 2 through 231 are unused.
    ///
    /// Meiji starts 1868-09-08. Some sources date it to 1868-10-23 instead, so the tests pin this boundary.
    static let japanese = GregorianFamilyCalendarEras([
        GregorianFamilyCalendarEra(eraNumber: 236, anchorYear: 2019, startMonth: 5, startDay: 1, direction: .forward),
        GregorianFamilyCalendarEra(eraNumber: 235, anchorYear: 1989, startMonth: 1, startDay: 8, direction: .forward),
        GregorianFamilyCalendarEra(eraNumber: 234, anchorYear: 1926, startMonth: 12, startDay: 25, direction: .forward),
        GregorianFamilyCalendarEra(eraNumber: 233, anchorYear: 1912, startMonth: 7, startDay: 30, direction: .forward),
        GregorianFamilyCalendarEra(eraNumber: 232, anchorYear: 1868, startMonth: 9, startDay: 8, direction: .forward),
    ], erasCanEnd: true)

    /// Two eras sharing the 1912 boundary, numbered Before-Minguo 0 and Minguo 1.
    static let republicOfChina = GregorianFamilyCalendarEras([
        GregorianFamilyCalendarEra(eraNumber: 1, anchorYear: 1912, startMonth: 1, startDay: 1, direction: .forward),
        GregorianFamilyCalendarEra(eraNumber: 0, anchorYear: 1912, startMonth: 1, startDay: 1, direction: .backward),
    ])

    /// An empty table, used to build a date from a year that is already extended so no era conversion applies.
    static let noRelabeling = GregorianFamilyCalendarEras([])

    /// The table an identifier labels its eras with. Anything other than the three era-relabeling calendars uses the Gregorian eras.
    static func forCalendar(_ identifier: Calendar.Identifier) -> GregorianFamilyCalendarEras {
        switch identifier {
        case .buddhist: return .buddhist
        case .japanese: return .japanese
        case .republicOfChina: return .republicOfChina
        default: return .gregorian
        }
    }
}
