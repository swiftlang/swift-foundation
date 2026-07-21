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

/// Japanese imperial calendar. Same arithmetic as Gregorian; year is reckoned within the current era. Delegates to `_CalendarGregorian`.
internal final class _CalendarJapanese: _CalendarProtocol, @unchecked Sendable {

    private struct EraEntry {
        let index: Int
        let startGregorianYear: Int
        let startMonth: Int
        let startDay: Int

        init(_ index: Int32, _ year: Int16, _ month: Int8, _ day: Int8) {
            self.index = Int(index)
            self.startGregorianYear = Int(year)
            self.startMonth = Int(month)
            self.startDay = Int(day)
        }
    }

    /// 237 Japanese eras (Taika 645 → Reiwa 2019), sorted descending. Index values match ICU's era numbering.
    // Meiji (232) uses 1868-09-08 to match Apple's runtime ICU (CLDR canonical is 1868-10-23).
    private static let eraData: InlineArray<237, (index: Int32, year: Int16, month: Int8, day: Int8)> = [
        (236, 2019, 5, 1),
        (235, 1989, 1, 8),
        (234, 1926, 12, 25),
        (233, 1912, 7, 30),
        (232, 1868, 9, 8),
        (231, 1865, 4, 7),
        (230, 1864, 2, 20),
        (229, 1861, 2, 19),
        (228, 1860, 3, 18),
        (227, 1854, 11, 27),
        (226, 1848, 2, 28),
        (225, 1844, 12, 2),
        (224, 1830, 12, 10),
        (223, 1818, 4, 22),
        (222, 1804, 2, 11),
        (221, 1801, 2, 5),
        (220, 1789, 1, 25),
        (219, 1781, 4, 2),
        (218, 1772, 11, 16),
        (217, 1764, 6, 2),
        (216, 1751, 10, 27),
        (215, 1748, 7, 12),
        (214, 1744, 2, 21),
        (213, 1741, 2, 27),
        (212, 1736, 4, 28),
        (211, 1716, 6, 22),
        (210, 1711, 4, 25),
        (209, 1704, 3, 13),
        (208, 1688, 9, 30),
        (207, 1684, 2, 21),
        (206, 1681, 9, 29),
        (205, 1673, 9, 21),
        (204, 1661, 4, 25),
        (203, 1658, 7, 23),
        (202, 1655, 4, 13),
        (201, 1652, 9, 18),
        (200, 1648, 2, 15),
        (199, 1644, 12, 16),
        (198, 1624, 2, 30),
        (197, 1615, 7, 13),
        (196, 1596, 10, 27),
        (195, 1592, 12, 8),
        (194, 1573, 7, 28),
        (193, 1570, 4, 23),
        (192, 1558, 2, 28),
        (191, 1555, 10, 23),
        (190, 1532, 7, 29),
        (189, 1528, 8, 20),
        (188, 1521, 8, 23),
        (187, 1504, 2, 30),
        (186, 1501, 2, 29),
        (185, 1492, 7, 19),
        (184, 1489, 8, 21),
        (183, 1487, 7, 29),
        (182, 1469, 4, 28),
        (181, 1467, 3, 3),
        (180, 1466, 2, 28),
        (179, 1460, 12, 21),
        (178, 1457, 9, 28),
        (177, 1455, 7, 25),
        (176, 1452, 7, 25),
        (175, 1449, 7, 28),
        (174, 1444, 2, 5),
        (173, 1441, 2, 17),
        (172, 1429, 9, 5),
        (171, 1428, 4, 27),
        (170, 1394, 7, 5),
        (169, 1390, 3, 26),
        (168, 1389, 2, 9),
        (167, 1387, 8, 23),
        (166, 1387, 8, 22),
        (165, 1384, 4, 28),
        (164, 1381, 2, 10),
        (163, 1379, 3, 22),
        (162, 1375, 5, 27),
        (161, 1372, 4, 1),
        (160, 1370, 7, 24),
        (159, 1346, 12, 8),
        (158, 1340, 4, 28),
        (157, 1336, 2, 29),
        (156, 1334, 1, 29),
        (155, 1331, 8, 9),
        (154, 1329, 8, 29),
        (153, 1326, 4, 26),
        (152, 1324, 12, 9),
        (151, 1321, 2, 23),
        (150, 1319, 4, 28),
        (149, 1317, 2, 3),
        (148, 1312, 3, 20),
        (147, 1311, 4, 28),
        (146, 1308, 10, 9),
        (145, 1306, 12, 14),
        (144, 1303, 8, 5),
        (143, 1302, 11, 21),
        (142, 1299, 4, 25),
        (141, 1293, 8, 5),
        (140, 1288, 4, 28),
        (139, 1278, 2, 29),
        (138, 1275, 4, 25),
        (137, 1264, 2, 28),
        (136, 1261, 2, 20),
        (135, 1260, 4, 13),
        (134, 1259, 3, 26),
        (133, 1257, 3, 14),
        (132, 1256, 10, 5),
        (131, 1249, 3, 18),
        (130, 1247, 2, 28),
        (129, 1243, 2, 26),
        (128, 1240, 7, 16),
        (127, 1239, 2, 7),
        (126, 1238, 11, 23),
        (125, 1235, 9, 19),
        (124, 1234, 11, 5),
        (123, 1233, 4, 15),
        (122, 1232, 4, 2),
        (121, 1229, 3, 5),
        (120, 1227, 12, 10),
        (119, 1225, 4, 20),
        (118, 1224, 11, 20),
        (117, 1222, 4, 13),
        (116, 1219, 4, 12),
        (115, 1213, 12, 6),
        (114, 1211, 3, 9),
        (113, 1207, 10, 25),
        (112, 1206, 4, 27),
        (111, 1204, 2, 20),
        (110, 1201, 2, 13),
        (109, 1199, 4, 27),
        (108, 1190, 4, 11),
        (107, 1185, 8, 14),
        (106, 1184, 4, 16),
        (105, 1182, 5, 27),
        (104, 1181, 7, 14),
        (103, 1177, 8, 4),
        (102, 1175, 7, 28),
        (101, 1171, 4, 21),
        (100, 1169, 4, 8),
        (99, 1166, 8, 27),
        (98, 1165, 6, 5),
        (97, 1163, 3, 29),
        (96, 1161, 9, 4),
        (95, 1160, 1, 10),
        (94, 1159, 4, 20),
        (93, 1156, 4, 27),
        (92, 1154, 10, 28),
        (91, 1151, 1, 26),
        (90, 1145, 7, 22),
        (89, 1144, 2, 23),
        (88, 1142, 4, 28),
        (87, 1141, 7, 10),
        (86, 1135, 4, 27),
        (85, 1132, 8, 11),
        (84, 1131, 1, 29),
        (83, 1126, 1, 22),
        (82, 1124, 4, 3),
        (81, 1120, 4, 10),
        (80, 1118, 4, 3),
        (79, 1113, 7, 13),
        (78, 1110, 7, 13),
        (77, 1108, 8, 3),
        (76, 1106, 4, 9),
        (75, 1104, 2, 10),
        (74, 1099, 8, 28),
        (73, 1097, 11, 21),
        (72, 1096, 12, 17),
        (71, 1094, 12, 15),
        (70, 1087, 4, 7),
        (69, 1084, 2, 7),
        (68, 1081, 2, 10),
        (67, 1077, 11, 17),
        (66, 1074, 8, 23),
        (65, 1069, 4, 13),
        (64, 1065, 8, 2),
        (63, 1058, 8, 29),
        (62, 1053, 1, 11),
        (61, 1046, 4, 14),
        (60, 1044, 11, 24),
        (59, 1040, 11, 10),
        (58, 1037, 4, 21),
        (57, 1028, 7, 25),
        (56, 1024, 7, 13),
        (55, 1021, 2, 2),
        (54, 1017, 4, 23),
        (53, 1012, 12, 25),
        (52, 1004, 7, 20),
        (51, 999, 1, 13),
        (50, 995, 2, 22),
        (49, 990, 11, 7),
        (48, 989, 8, 8),
        (47, 987, 4, 5),
        (46, 985, 4, 27),
        (45, 983, 4, 15),
        (44, 978, 11, 29),
        (43, 976, 7, 13),
        (42, 973, 12, 20),
        (41, 970, 3, 25),
        (40, 968, 8, 13),
        (39, 964, 7, 10),
        (38, 961, 2, 16),
        (37, 957, 10, 27),
        (36, 947, 4, 22),
        (35, 938, 5, 22),
        (34, 931, 4, 26),
        (33, 923, 4, 11),
        (32, 901, 7, 15),
        (31, 898, 4, 26),
        (30, 889, 4, 27),
        (29, 885, 2, 21),
        (28, 877, 4, 16),
        (27, 859, 4, 15),
        (26, 857, 2, 21),
        (25, 854, 11, 30),
        (24, 851, 4, 28),
        (23, 848, 6, 13),
        (22, 834, 1, 3),
        (21, 824, 1, 5),
        (20, 810, 9, 19),
        (19, 806, 5, 18),
        (18, 782, 8, 19),
        (17, 781, 1, 1),
        (16, 770, 10, 1),
        (15, 767, 8, 16),
        (14, 765, 1, 7),
        (13, 757, 8, 18),
        (12, 749, 7, 2),
        (11, 749, 4, 14),
        (10, 729, 8, 5),
        (9, 724, 2, 4),
        (8, 717, 11, 17),
        (7, 715, 9, 2),
        (6, 708, 1, 11),
        (5, 704, 5, 10),
        (4, 701, 3, 21),
        (3, 686, 7, 20),
        (2, 672, 1, 1),
        (1, 650, 2, 15),
        (0, 645, 6, 19),
    ]

    private static let eraCount = 237

    private static func era(at i: Int) -> EraEntry {
        let raw = eraData[i]
        return EraEntry(raw.index, raw.year, raw.month, raw.day)
    }

    private let gregorian: _CalendarGregorian

    init(identifier: Calendar.Identifier, timeZone: TimeZone?, locale: Locale?, firstWeekday: Int?, minimumDaysInFirstWeek: Int?, gregorianStartDate: Date?) {
        assert(identifier == .japanese, "_CalendarJapanese only handles .japanese")
        self.gregorian = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: locale, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: gregorianStartDate)
    }

    let identifier: Calendar.Identifier = .japanese

    var locale: Locale? {
        get { gregorian.locale }
        set { gregorian.locale = newValue }
    }

    var timeZone: TimeZone {
        get { gregorian.timeZone }
        set { gregorian.timeZone = newValue }
    }

    var firstWeekday: Int {
        get { gregorian.firstWeekday }
        set { gregorian.firstWeekday = newValue }
    }

    var minimumDaysInFirstWeek: Int {
        get { gregorian.minimumDaysInFirstWeek }
        set { gregorian.minimumDaysInFirstWeek = newValue }
    }

    func copy(changingLocale: Locale?, changingTimeZone: TimeZone?, changingFirstWeekday: Int?, changingMinimumDaysInFirstWeek: Int?) -> any _CalendarProtocol {
        let args = _CalendarUtility.resolvedCopyArgs(
            currentTimeZone: gregorian.timeZone, changingTimeZone: changingTimeZone,
            currentLocale: gregorian.locale, changingLocale: changingLocale,
            currentFirstWeekday: gregorian._firstWeekday, changingFirstWeekday: changingFirstWeekday,
            currentMinimumDaysInFirstWeek: gregorian._minimumDaysInFirstWeek, changingMinimumDaysInFirstWeek: changingMinimumDaysInFirstWeek
        )
        return _CalendarJapanese(identifier: identifier, timeZone: args.timeZone, locale: args.locale, firstWeekday: args.firstWeekday, minimumDaysInFirstWeek: args.minimumDaysInFirstWeek, gregorianStartDate: nil)
    }

    func supportsNextDateFastPath(for components: Calendar.ComponentSet) -> Bool { gregorian.supportsNextDateFastPath(for: components) }

    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
        hasher.combine(timeZone)
        hasher.combine(firstWeekday)
        hasher.combine(minimumDaysInFirstWeek)
        hasher.combine(localeIdentifier)
        hasher.combine(preferredFirstWeekday)
        hasher.combine(preferredMinimumDaysInFirstweek)
    }

    // MARK: - Range

    func minimumRange(of component: Calendar.Component) -> Range<Int>? {
        if component == .era { return 0..<(Self.era(at: Self.eraCount - 1).index + Self.eraCount) }
        if component == .year { return 1..<2 }
        return gregorian.minimumRange(of: component)
    }

    func maximumRange(of component: Calendar.Component) -> Range<Int>? {
        if component == .era { return 0..<(Self.era(at: 0).index + 1) }
        return gregorian.maximumRange(of: component)
    }

    func range(of smaller: Calendar.Component, in larger: Calendar.Component, for date: Date) -> Range<Int>? {
        gregorian.range(of: smaller, in: larger, for: date)
    }

    func ordinality(of smaller: Calendar.Component, in larger: Calendar.Component, for date: Date) -> Int? {
        gregorian.ordinality(of: smaller, in: larger, for: date)
    }

    func dateInterval(of component: Calendar.Component, for date: Date) -> DateInterval? {
        if component == .era {
            return eraInterval(containing: date)
        }
        return gregorian.dateInterval(of: component, for: date)
    }

    func isDateInWeekend(_ date: Date) -> Bool {
        gregorian.isDateInWeekend(date)
    }

    // MARK: - Date / DateComponents conversion

    func date(from components: DateComponents) -> Date? {
        gregorian.date(from: convertedToGregorian(components))
    }

    func dateComponents(_ components: Calendar.ComponentSet, from date: Date, in timeZone: TimeZone) -> DateComponents {
        var dc = gregorian.dateComponents(components, from: date, in: timeZone)
        adjustToJapanese(&dc, date: date, requested: components)
        return dc
    }

    func dateComponents(_ components: Calendar.ComponentSet, from date: Date) -> DateComponents {
        var dc = gregorian.dateComponents(components, from: date)
        adjustToJapanese(&dc, date: date, requested: components)
        return dc
    }

    func date(byAdding components: DateComponents, to date: Date, wrappingComponents: Bool) -> Date? {
        gregorian.date(byAdding: components, to: date, wrappingComponents: wrappingComponents)
    }

    func dateComponents(_ components: Calendar.ComponentSet, from start: Date, to end: Date) -> DateComponents {
        gregorian.dateComponents(components, from: start, to: end)
    }

    func nextDate(after date: Date, matching components: DateComponents, direction: Calendar.SearchDirection) -> Date? {
        gregorian.nextDate(after: date, matching: convertedToGregorian(components), direction: direction)
    }

    // MARK: - Era helpers

    private func eraEntry(forGregorianYear y: Int, month m: Int, day d: Int) -> EraEntry? {
        for i in 0..<Self.eraCount {
            let era = Self.era(at: i)
            if (y, m, d) >= (era.startGregorianYear, era.startMonth, era.startDay) {
                return era
            }
        }
        return nil
    }

    private func eraEntry(byIndex index: Int) -> EraEntry? {
        for i in 0..<Self.eraCount {
            if Self.era(at: i).index == index { return Self.era(at: i) }
        }
        return nil
    }

    private func eraInterval(containing date: Date) -> DateInterval? {
        let comps = gregorian.dateComponents([.year, .month, .day], from: date)
        guard let y = comps.year, let m = comps.month, let d = comps.day else { return nil }
        guard let era = eraEntry(forGregorianYear: y, month: m, day: d) else {
            return gregorian.dateInterval(of: .era, for: date)
        }
        let startDC = DateComponents(year: era.startGregorianYear, month: era.startMonth, day: era.startDay, hour: 0, minute: 0, second: 0)
        guard let start = gregorian.date(from: startDC) else { return nil }
        let endDate: Date
        var nextEra: EraEntry? = nil
        for i in 0..<Self.eraCount {
            if Self.era(at: i).index == era.index && i > 0 {
                nextEra = Self.era(at: i - 1)
                break
            }
        }
        if let next = nextEra {
            let endDC = DateComponents(year: next.startGregorianYear, month: next.startMonth, day: next.startDay, hour: 0, minute: 0, second: 0)
            guard let e = gregorian.date(from: endDC) else { return nil }
            endDate = e
        } else {
            endDate = start.addingTimeInterval(Calendar._maxDateIntervalDuration)
        }
        return DateInterval(start: start, end: endDate)
    }

    // MARK: - Components conversion

    private func convertedToGregorian(_ components: DateComponents) -> DateComponents {
        var dc = components
        if let year = dc.year {
            // Default to latest era when era is missing (matches ICU).
            let eraIndex = dc.era ?? Self.era(at: 0).index
            if let eraEntry = eraEntry(byIndex: eraIndex) {
                dc.year = year + eraEntry.startGregorianYear - 1
            }
        }
        dc.era = nil
        return dc
    }

    private func adjustToJapanese(_ dc: inout DateComponents, date: Date, requested: Calendar.ComponentSet) {
        guard requested.contains(.era) || requested.contains(.year) else { return }
        let probe = gregorian.dateComponents([.era, .year, .month, .day], from: date)
        guard let y = probe.year, let m = probe.month, let d = probe.day else { return }
        let extendedYear = probe.era == 0 ? 1 - y : y
        if let era = eraEntry(forGregorianYear: extendedYear, month: m, day: d) {
            if requested.contains(.era) { dc.era = era.index }
            if requested.contains(.year) { dc.year = extendedYear - era.startGregorianYear + 1 }
        } else {
            // Pre-Taika: ICU clamps to the first era.
            let first = Self.era(at: Self.eraCount - 1)
            if requested.contains(.era) { dc.era = first.index }
            if requested.contains(.year) { dc.year = extendedYear - first.startGregorianYear + 1 }
        }
    }

#if FOUNDATION_FRAMEWORK
    func bridgeToNSCalendar() -> NSCalendar {
        _NSSwiftCalendar(calendar: Calendar(inner: self))
    }
#endif
}
