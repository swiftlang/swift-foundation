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

internal struct GregorianFamilyCalendarEra: Sendable {

    /// The value `DateComponents.era` carries. These are assigned numbers rather than positions in a table, so Meiji is 232.
    let eraNumber: Int

    /// The extended Gregorian year holding this era's boundary. A forward era numbers that year 1, and a backward era counts down from it.
    let anchorYear: Int

    let startMonth: Int
    let startDay: Int
    let direction: Calendar.SearchDirection

    init(eraNumber: Int, anchorYear: Int, startMonth: Int, startDay: Int, direction: Calendar.SearchDirection) {
        self.eraNumber = eraNumber
        self.anchorYear = anchorYear
        self.startMonth = startMonth
        self.startDay = startDay
        self.direction = direction
    }

    func labels(extendedYear year: Int, month: Int, day: Int) -> Bool {
        let isAtOrAfterBoundary = (year, month, day) >= (anchorYear, startMonth, startDay)
        return direction == .forward ? isAtOrAfterBoundary : !isAtOrAfterBoundary
    }

    func eraYear(fromExtendedYear year: Int) -> Int {
        switch direction {
        case .forward: return year - anchorYear + 1
        case .backward: return anchorYear - year
        }
    }

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

    /// Era ranges run from 0 up to this value, because 0 and 1 stay reserved for the Gregorian eras a calendar inherits.
    let maxEraNumber: Int

    /// Used when `DateComponents.era` is absent.
    let defaultEraNumber: Int

    /// Limits how high a year number can go once years are counted inside an era.
    let newestAnchorYear: Int

    /// True when an era can end as well as begin, so year numbers restart. The Japanese eras do, and the Buddhist and Minguo eras run on without limit.
    let erasCanEnd: Bool

    /// True when this table numbers every date itself, so nothing falls back to an inherited Gregorian era. Only Buddhist does, numbering 1000 BCE as year -456.
    let coversEveryDate: Bool

    /// Era numbers run consecutively, so this holds five slots for Japanese and one or two for the rest.
    private let erasByNumber: [GregorianFamilyCalendarEra?]

    private let lowestEraNumber: Int

    init(_ entries: [GregorianFamilyCalendarEra], erasCanEnd: Bool = false, coversEveryDate: Bool = false) {
        self.entries = entries
        self.maxEraNumber = entries.map(\.eraNumber).max() ?? 0
        self.defaultEraNumber = entries.first?.eraNumber ?? 0
        self.newestAnchorYear = entries.first?.anchorYear ?? 0
        self.erasCanEnd = erasCanEnd
        self.coversEveryDate = coversEveryDate

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

    func entry(extendedYear year: Int, month: Int, day: Int) -> GregorianFamilyCalendarEra? {
        if let match = entries.first(where: { $0.labels(extendedYear: year, month: month, day: day) }) {
            return match
        }
        // Older than every era, so only a table covering every date has one to offer.
        return coversEveryDate ? entries.last : nil
    }

    func entry(eraNumber: Int) -> GregorianFamilyCalendarEra? {
        // `DateComponents.era` is public, so a caller can pass any Int and plain subtraction would crash near Int.min.
        let index = eraNumber.subtractingReportingOverflow(lowestEraNumber)
        guard !index.overflow, erasByNumber.indices.contains(index.partialValue) else { return nil }
        return erasByNumber[index.partialValue]
    }
}

extension GregorianFamilyCalendarEras {

    /// The era a `DateComponents.era` value refers to, which may be one this table lists or one of the Gregorian eras it inherits.
    enum ResolvedEra: Sendable {
        case listed(GregorianFamilyCalendarEra)
        /// A number this table does not list. 0 is BCE and anything else is CE.
        case inheritedGregorian(isBCE: Bool)
        case absent

        /// Adding or wrapping a year has to move opposite the requested amount when this is true.
        var countsBackward: Bool {
            switch self {
            case .listed(let era): return era.direction == .backward
            case .inheritedGregorian(let isBCE): return isBCE
            case .absent: return false
            }
        }
    }

    func era(numbered eraNumber: Int?) -> ResolvedEra {
        guard let eraNumber else { return .absent }
        if let listed = entry(eraNumber: eraNumber) { return .listed(listed) }
        return .inheritedGregorian(isBCE: eraNumber == 0)
    }
}

/// One table per calendar that `_CalendarGregorian` serves. Stored properties, so each is built once rather than on every calendar copy.
extension GregorianFamilyCalendarEras {

    /// Gregorian and ISO8601.
    static let gregorian = GregorianFamilyCalendarEras([
        GregorianFamilyCalendarEra(eraNumber: 1, anchorYear: 1, startMonth: 1, startDay: 1, direction: .forward),
        GregorianFamilyCalendarEra(eraNumber: 0, anchorYear: 1, startMonth: 1, startDay: 1, direction: .backward),
    ])

    /// One era covering every date. 1 CE is 544 BE.
    static let buddhist = GregorianFamilyCalendarEras([
        GregorianFamilyCalendarEra(eraNumber: 0, anchorYear: -542, startMonth: 1, startDay: 1, direction: .forward)
    ], coversEveryDate: true)

    /// The five modern eras. Earlier ones are not listed, so a date before Meiji reports the inherited Gregorian era and numbers 2 through 231 are unused.
    ///
    /// Meiji starts 1868-09-08. Some sources date it to 1868-10-23 instead, so the tests pin this boundary.
    static let japanese = GregorianFamilyCalendarEras([
        GregorianFamilyCalendarEra(eraNumber: 236, anchorYear: 2019, startMonth: 5, startDay: 1, direction: .forward),
        GregorianFamilyCalendarEra(eraNumber: 235, anchorYear: 1989, startMonth: 1, startDay: 8, direction: .forward),
        GregorianFamilyCalendarEra(eraNumber: 234, anchorYear: 1926, startMonth: 12, startDay: 25, direction: .forward),
        GregorianFamilyCalendarEra(eraNumber: 233, anchorYear: 1912, startMonth: 7, startDay: 30, direction: .forward),
        GregorianFamilyCalendarEra(eraNumber: 232, anchorYear: 1868, startMonth: 9, startDay: 8, direction: .forward),
    ], erasCanEnd: true)

    /// Before-Minguo and Minguo, sharing the 1912 boundary.
    static let republicOfChina = GregorianFamilyCalendarEras([
        GregorianFamilyCalendarEra(eraNumber: 1, anchorYear: 1912, startMonth: 1, startDay: 1, direction: .forward),
        GregorianFamilyCalendarEra(eraNumber: 0, anchorYear: 1912, startMonth: 1, startDay: 1, direction: .backward),
    ])

    /// Builds a date from a year that is already extended, so no era conversion applies.
    static let noRelabeling = GregorianFamilyCalendarEras([])

    static func forCalendar(_ identifier: Calendar.Identifier) -> GregorianFamilyCalendarEras {
        switch identifier {
        case .buddhist: return .buddhist
        case .japanese: return .japanese
        case .republicOfChina: return .republicOfChina
        default: return .gregorian
        }
    }
}
