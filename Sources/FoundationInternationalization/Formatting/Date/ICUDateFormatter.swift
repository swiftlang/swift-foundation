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

#if canImport(Darwin)
import Darwin
#elseif canImport(Bionic)
@preconcurrency import Bionic
#elseif canImport(Glibc)
@preconcurrency import Glibc
#elseif canImport(Musl)
@preconcurrency import Musl
#endif

typealias UChar = UInt16

final class ICUDateFormatter : @unchecked Sendable {

    /// `Sendable` notes: `UDateFormat` is safe to use from multiple threads after initialization. The `UCal` using API clones the calendar before using it.
    var udateFormat: UnsafeMutablePointer<UDateFormat?>
    var lenientParsing: Bool

    private init?(localeIdentifier: String, timeZoneIdentifier: String, calendarIdentifier: Calendar.Identifier, firstWeekday: Int, minimumDaysInFirstWeek: Int, capitalizationContext: FormatStyleCapitalizationContext, pattern: String, twoDigitStartDate: Date, lenientParsing: Bool) {
        self.lenientParsing = lenientParsing

        // We failed to construct a locale with the given calendar; fall back to locale's identifier
        let localeIdentifierWithCalendar = Calendar.localeIdentifierWithCalendar(localeIdentifier: localeIdentifier, calendarIdentifier: calendarIdentifier) ?? localeIdentifier

        let tz = Array(timeZoneIdentifier.utf16)
        let pt = Array(pattern.utf16)

        var status = U_ZERO_ERROR
        let udat = udat_open(UDAT_PATTERN, UDAT_PATTERN, localeIdentifierWithCalendar, tz, Int32(tz.count), pt, Int32(pt.count), &status)

        guard status.checkSuccessAndLogError("udat_open failed."), let udat else {
            if (udat != nil) {
                udat_close(udat)
            }
            return nil
        }

        udateFormat = udat

        udat_setContext(udateFormat, capitalizationContext.icuContext, &status)
        _ = status.checkSuccessAndLogError("udat_setContext failed.")

        if lenientParsing {
            udat_setLenient(udateFormat, UBool.true)
        } else {
            udat_setLenient(udateFormat, UBool.false)

            udat_setBooleanAttribute(udateFormat, UDAT_PARSE_ALLOW_WHITESPACE, UBool.false, &status)
            _ = status.checkSuccessAndLogError("Cannot set UDAT_PARSE_ALLOW_WHITESPACE.")

            udat_setBooleanAttribute(udateFormat, UDAT_PARSE_ALLOW_NUMERIC, UBool.false, &status)
            _ = status.checkSuccessAndLogError("Cannot set UDAT_PARSE_ALLOW_NUMERIC.")

            udat_setBooleanAttribute(udateFormat, UDAT_PARSE_PARTIAL_LITERAL_MATCH, UBool.false, &status)
            _ = status.checkSuccessAndLogError("Cannot set UDAT_PARSE_PARTIAL_LITERAL_MATCH.")

            udat_setBooleanAttribute(udateFormat, UDAT_PARSE_MULTIPLE_PATTERNS_FOR_MATCH, UBool.false, &status)
            _ = status.checkSuccessAndLogError("Cannot set UDAT_PARSE_MULTIPLE_PATTERNS_FOR_MATCH.")
        }

        let udatCalendar = udat_getCalendar(udateFormat)
        let ucal = ucal_clone(udatCalendar, &status)
        defer { ucal_close(ucal) }
        guard status.checkSuccessAndLogError("ucal_clone failed."), let ucal else {
            return
        }

        ucal_clear(ucal)
        ucal_setAttribute(ucal, .firstDayOfWeek, Int32(firstWeekday))
        ucal_setAttribute(ucal, .minimalDaysInFirstWeek, Int32(minimumDaysInFirstWeek))

        // Set the default date when parsing incomplete date fields to Jan 1st midnight at the year of twoDigitStartDate
        ucal_setMillis(ucal, twoDigitStartDate.udate, &status)
        let twoDigitStartYear = ucal_get(ucal, UCAL_YEAR, &status)
        ucal_setDateTime(ucal, twoDigitStartYear, 0, 1, 0, 0, 0, &status);

        let startOfTwoDigitStartYear = ucal_getMillis(ucal, &status)
        udat_set2DigitYearStart(udateFormat, startOfTwoDigitStartYear, &status);

        udat_setCalendar(udateFormat, ucal)
    }

    deinit {
        udat_close(udateFormat)
    }

    // MARK: -

    func format(_ date: Date) -> String? {
        return _withResizingUCharBuffer { buffer, size, status in
            udat_formatForFields(udateFormat, date.udate, buffer, Int32(size), nil, &status)
        }
    }

    func parse(_ string: String) -> Date? {
        guard let parsed = try? _parse(string, fromIndex: string.startIndex) else {
            return nil
        }

        return parsed.date
    }

    func _parse(_ string: some StringProtocol, fromIndex: String.Index) throws -> (date: Date, upperBound: Int)? {
        let ucal = udat_getCalendar(udateFormat)

        // TODO: handle ambiguous years on `newCal` for Chinese and Japanese calendar
        var status = U_ZERO_ERROR
        let newCal = ucal_clone(ucal, &status)
        try status.checkSuccess()
        defer {
            ucal_close(newCal)
        }

        let ucharText = Array(string.utf16)
        let utf16Index = fromIndex.utf16Offset(in: string)
        var pos = Int32(utf16Index)

        udat_parseCalendar(udateFormat, newCal, ucharText, Int32(ucharText.count), &pos, &status)
        try status.checkSuccess()

        if pos == utf16Index {
            // The end position after parsing is the same as that before parsing, so we fail
            return nil
        }

        let udate = ucal_getMillis(newCal, &status)
        try status.checkSuccess()

        return (Date(udate: udate), Int(pos))
    }

    func parse(_ string: some StringProtocol, in range: Range<String.Index>) -> (String.Index, Date)? {
        let substr = string[range]

        guard !substr.isEmpty else {
            return nil
        }

        if !lenientParsing {
            if let start = substr.first, start.isWhitespace {
                // no need to continue parsing if it starts with a whitespace under strict parsing
                return nil
            }
        }

        let substrStr = String(substr)
        guard let (date, upperBoundInSubstr) = try? _parse(substrStr, fromIndex: substrStr.startIndex) else {
            return nil
        }
        let endIndexInSubstr = String.Index(utf16Offset: upperBoundInSubstr, in: substr)

        return (endIndexInSubstr, date)
    }

    // Search the presence of a date string that matches the specified format by advancing repeatedly until we find a match
    func search(_ string: String, in range: Range<String.Index>) -> (Range<String.Index>, Date)? {
        var idx = range.lowerBound
        let end = range.upperBound
        while idx < end {
            if let (newUpper, match) = parse(string, in: idx..<end) {
                return (idx..<newUpper, match)
            } else {
                string.formIndex(after: &idx)
            }
        }
        return nil
    }

    struct AttributePosition {
        let field: UDateFormatField
        let begin: Int
        let end: Int
    }

    func attributedFormat(_ date: Date) -> (String, [AttributePosition])? {
        guard let positer = try? ICU.FieldPositer() else {
            return nil
        }

        let result = _withResizingUCharBuffer { buffer, size, status in
            udat_formatForFields(udateFormat, date.udate, buffer, Int32(size), positer.positer, &status)
        }

        guard let result else {
            return nil
        }

        return (result, positer.fields.map { field -> AttributePosition in
            return AttributePosition(field: UDateFormatField(CInt(field.field)), begin: field.begin, end: field.end)
        })
    }

    // MARK: - Getting symbols

    func symbols(for key: UDateFormatSymbolType) -> [String] {
        let symbolCount = udat_countSymbols(udateFormat, key)
        var result = [String]()
        for i in 0 ..< symbolCount {
            let s = _withResizingUCharBuffer { buffer, size, status in
                udat_getSymbols(udateFormat, key, i, buffer, size, &status)
            }

            if let s {
                result.append(s)
            }
        }

        return result
    }

    // -- Caching support

    // A Date.VerbatimFormatStyle, Date.FormatStyle and Date.ParseStrategy might be able to share an ICUDateFormatter
    struct DateFormatInfo: Hashable {
        // Use the bare identifier for locale, time zone and calendar instead of instances of their type so that `.current` and `.autoupdatingCurrent` special instances behaves the same as normal "fixed" ones.
        var localeIdentifier: String
        var timeZoneIdentifier: String
        var calendarIdentifier: Calendar.Identifier
        var firstWeekday: Int
        var minimumDaysInFirstWeek: Int
        var capitalizationContext: FormatStyleCapitalizationContext
        var pattern: String // a fixed date format including literals, such as "yyyy-MM-dd". It's different from "skeleton", which is used as a hint to fetch the localized pattern

        var parseLenient: Bool
        var parseTwoDigitStartDate: Date

        init(localeIdentifier: String?, timeZoneIdentifier: String, calendarIdentifier: Calendar.Identifier, firstWeekday: Int, minimumDaysInFirstWeek: Int, capitalizationContext: FormatStyleCapitalizationContext, pattern: String, parseLenient: Bool = true, parseTwoDigitStartDate: Date = Date(timeIntervalSince1970: 0)) {
            if let localeIdentifier {
                self.localeIdentifier = localeIdentifier
            } else {
                self.localeIdentifier = ""
            }
            self.timeZoneIdentifier = timeZoneIdentifier
            self.calendarIdentifier = calendarIdentifier
            self.firstWeekday = firstWeekday
            self.minimumDaysInFirstWeek = minimumDaysInFirstWeek
            self.capitalizationContext = capitalizationContext
            self.pattern = pattern

            // Always set a default value even though this is only relevant for parsing -- We might be able to reuse an existing ICUDateFormatter when parsing
            self.parseLenient = parseLenient
            self.parseTwoDigitStartDate = parseTwoDigitStartDate
        }
    }

    static let formatterCache = FormatterCache<DateFormatInfo, ICUDateFormatter?>()
    static let patternCache = LockedState<[PatternCacheKey : String]>(initialState: [:])

    static func cachedFormatter(for dateFormatInfo: DateFormatInfo) -> ICUDateFormatter? {
        return Self.formatterCache.formatter(for: dateFormatInfo) {
            ICUDateFormatter(localeIdentifier: dateFormatInfo.localeIdentifier, timeZoneIdentifier: dateFormatInfo.timeZoneIdentifier, calendarIdentifier: dateFormatInfo.calendarIdentifier, firstWeekday: dateFormatInfo.firstWeekday, minimumDaysInFirstWeek: dateFormatInfo.minimumDaysInFirstWeek, capitalizationContext: dateFormatInfo.capitalizationContext, pattern: dateFormatInfo.pattern, twoDigitStartDate: dateFormatInfo.parseTwoDigitStartDate, lenientParsing: dateFormatInfo.parseLenient)
        }
    }

    struct PatternCacheKey : Hashable {
        var localeIdentifier: String
        var calendarIdentifier: Calendar.Identifier
        var symbols: Date.FormatStyle.DateFieldCollection
        var datePatternOverride: String?
    }

    static func cachedFormatter(for format: Date.FormatStyle) -> ICUDateFormatter? {
        cachedFormatter(for: .init(format))
    }

    static func cachedFormatter(for format: Date.VerbatimFormatStyle) -> ICUDateFormatter? {
        cachedFormatter(for: .init(format))
    }

    // Returns a formatter to retrieve localized calendar symbols
    static func cachedFormatter(for calendar: Calendar) -> ICUDateFormatter? {
        cachedFormatter(for: .init(calendar))
    }
}

extension ICUDateFormatter.DateFormatInfo {
    init(_ format: Date.FormatStyle) {
        let calendarIdentifier = format.calendar.identifier
        let datePatternOverride: String?
#if FOUNDATION_FRAMEWORK
        if let dateStyle = format._dateStyle {
            datePatternOverride = format.locale.customDateFormat(dateStyle)
        } else {
            datePatternOverride = nil
        }
#else
        datePatternOverride = nil
#endif

        let key = ICUDateFormatter.PatternCacheKey(localeIdentifier: format.locale.identifierCapturingPreferences, calendarIdentifier: format.calendar.identifier, symbols: format.symbols, datePatternOverride: datePatternOverride)
        let pattern = ICUDateFormatter.patternCache.withLock { state in
            if let cachedPattern = state[key] {
                return cachedPattern
            } else {
                var pattern = ICUPatternGenerator.localizedPattern(symbols: format.symbols, locale: format.locale, calendar: format.calendar)
                if let datePatternOverride {
                    // substitute date part from pattern with customDatePattern
                    let datePattern = ICUPatternGenerator.localizedPattern(symbols: format.symbols.dateFields, locale: format.locale, calendar: format.calendar)
                    pattern.replace(datePattern, with: datePatternOverride)
                }
                
                state[key] = pattern
                return pattern
            }
        }

        let firstWeekday: Int
        if let forceFirstWeekday = format.locale.forceFirstWeekday(calendarIdentifier) {
            firstWeekday = forceFirstWeekday.icuIndex
        } else {
            firstWeekday = format.calendar.firstWeekday
        }

        self.init(localeIdentifier: format.locale.identifier, timeZoneIdentifier: format.timeZone.identifier, calendarIdentifier: calendarIdentifier, firstWeekday: firstWeekday, minimumDaysInFirstWeek: format.calendar.minimumDaysInFirstWeek, capitalizationContext: format.capitalizationContext, pattern: pattern, parseLenient: format.parseLenient)
    }

    init(_ format: Date.VerbatimFormatStyle) {
        self.init(localeIdentifier: format.locale?.identifier, timeZoneIdentifier: format.timeZone.identifier, calendarIdentifier: format.calendar.identifier, firstWeekday: format.calendar.firstWeekday, minimumDaysInFirstWeek: format.calendar.minimumDaysInFirstWeek, capitalizationContext: .unknown, pattern: format.formatPattern)
    }

    // Returns the info for as formatter to retrieve localized calendar symbols
    init(_ calendar: Calendar) {
        // Currently this always uses `.unknown` for capitalization. We should
        // consider allowing customization with rdar://71815286
        self.init(localeIdentifier: calendar.locale?.identifier, timeZoneIdentifier: calendar.timeZone.identifier, calendarIdentifier: calendar.identifier, firstWeekday: calendar.firstWeekday, minimumDaysInFirstWeek: calendar.minimumDaysInFirstWeek, capitalizationContext: .unknown, pattern: "")
    }
}

extension ICUDateFormatter.DateFormatInfo {
    enum UpdateSchedule {
        /// Update every `10^magnitude` nanoseconds starting from zero.
        case nanoseconds(magnitude: Int)
        /// Update at the bounds of all components in the set.
        case components(Calendar.ComponentSet)

        /// The empty update schedule, which requires no updates at all.
        init() {
            self = .components(.init())
        }

        /// Combine another schedule with this one.
        ///
        /// Merge schedules in a way that the minimal amount of `updateIntervals` are generated.
        mutating func reduce(with other: Self) {
            switch (self, other) {
            case let (.nanoseconds(magnitude: a), .nanoseconds(magnitude: b)):
                self = .nanoseconds(magnitude: min(a, b))
            case (.nanoseconds, _):
                break
            case (_, .nanoseconds):
                self = other
            case let (.components(a), .components(b)):
                let combination = a.union(b)

                guard !combination.contains(.nanosecond) else {
                    self = .nanoseconds(magnitude: 0)
                    return
                }

                if combination.contains(.second) {
                    self = .components(.second)
                    return
                }

                // For larger components the bounds generally don't align so we have to
                // collect multiple and try which produces the closest bound for a
                // given combination of date and calendar. Firstly, eras start and end
                // pretty much arbitrarily. We assume they are always aligned to full
                // seconds, mostly for better performance.
                var result = Calendar.ComponentSet()

                if combination.contains(.era) {
                    result.insert(.era)
                }

                // Everything from minute to day should have aligned bounds.
                if combination.contains(.minute) {
                    result.insert(.minute)
                    self = .components(result)
                    return
                }
                if combination.contains(.hour) {
                    result.insert(.hour)
                    self = .components(result)
                    return
                }
                if combination.contains(.hour) {
                    result.insert(.hour)
                    self = .components(result)
                    return
                }
                if combination.contains(.weekday) {
                    result.insert(.weekday)
                    self = .components(result)
                    return
                }
                if combination.contains(.day) {
                    result.insert(.day)
                    self = .components(result)
                    return
                }
                if combination.contains(.day) {
                    result.insert(.day)
                    self = .components(result)
                    return
                }

                // Bounds might not be aligned for the following components. E.g. the
                // end of the month can come before the end of the week.
                result.formUnion(combination.intersection([.weekOfMonth, .weekOfYear, .month, .quarter, .year, .yearForWeekOfYear]))

                self = .components(result)
            }
        }

        /// The intervals at which updates need to be scheduled.
        ///
        /// E.g. the value `[(.month, 1), (.weekOfYear, 1)]` means to update at bounds of
        /// months and weeks. A value of `[(.nanosecond, 100_000_000)]` demands updates
        /// every tenth of a second, aligned to full seconds.
        var updateIntervals: [(component: Calendar.Component, multitude: Int)] {
            switch self {
            case let .nanoseconds(magnitude: magnitude):
                return [(.nanosecond, Int(pow(10, Double(magnitude)).nextUp))]
            case let .components(components):
                return components.set.map { ($0, 1) }
            }
        }
    }

    static let updateScheduleCache = LockedState<[Self: UpdateSchedule]>(initialState: [:])

    static func cachedUpdateSchedule(for format: Date.VerbatimFormatStyle) -> UpdateSchedule {
        return Self.updateScheduleCache.withLock { state in
            let info = Self(format)
            if let schedule = state[info] {
                return schedule
            } else {
                let schedule = format.formatPattern.updateSchedule

                state[info] = schedule
                return schedule
            }
        }
    }

    static func cachedUpdateSchedule(for format: Date.FormatStyle) -> UpdateSchedule {
        return Self.updateScheduleCache.withLock { state in
            let info = Self(format)
            if let schedule = state[info] {
                return schedule
            } else {
                let schedule = format.symbols.updateSchedule

                state[info] = schedule
                return schedule
            }
        }
    }
}

extension Date.FormatStyle.DateFieldCollection {
    var updateSchedule: ICUDateFormatter.DateFormatInfo.UpdateSchedule {
        if let magnitude = secondFraction.map({
            switch $0 {
            case let .fractional(length):
                return 9 - length
            case .milliseconds:
                return 0
            }}) {
            return .nanoseconds(magnitude: magnitude)
        }
        if second != nil {
            return .components(.second)
        }

        var schedule = ICUDateFormatter.DateFormatInfo.UpdateSchedule()

        if era != nil {
            schedule.reduce(with: .components(.era))
        }
        if year != nil {
            schedule.reduce(with: .components(.year))
        }
        if quarter != nil {
            schedule.reduce(with: .components(.quarter))
        }
        if month != nil {
            schedule.reduce(with: .components(.month))
        }
        if let week {
            if week == .weekOfMonth {
                schedule.reduce(with: .components(.weekOfMonth))
            } else {
                schedule.reduce(with: .components(.weekOfYear))
            }
        }
        if day != nil {
            schedule.reduce(with: .components(.day))
        }
        if dayOfYear != nil {
            schedule.reduce(with: .components(.dayOfYear))
        }
        if weekday != nil {
            schedule.reduce(with: .components(.weekday))
        }
        if dayPeriod != nil || hour != nil {
            schedule.reduce(with: .components(.hour))
        }
        if minute != nil {
            schedule.reduce(with: .components(.minute))
        }
        if timeZoneSymbol != nil {
            schedule.reduce(with: .components(.timeZone))
        }

        return schedule
    }
}

extension String {
    /// Calculate the update schedule for an ICU date format pattern string.
    fileprivate var updateSchedule: ICUDateFormatter.DateFormatInfo.UpdateSchedule {
        // udat_toCalendarDateField may fail if the date format field doesn't
        // have a calendar equivalent, but there is explicitly no stable error
        // code, so we have to check at runtime what value corresponds to `nil`
        let failureField = udat_toCalendarDateField(.init(CInt.max))

        return self
            .purgingStringLiterals()
            .utf16
            .map { udat_patternCharToDateFormatField($0) }
            // chunked by equality
            .reduce(into: [[UDateFormatField]]()) { result, next in
                if var last = result.last, last.first == next {
                    last.append(next)
                    result[result.count - 1] = last
                } else {
                    result.append([next])
                }
            }
            .reduce(into: ICUDateFormatter.DateFormatInfo.UpdateSchedule()) { schedule, fields in
                guard let field = fields.first else {
                    return
                }

                if field == .fractionalSecond {
                    schedule.reduce(with: .nanoseconds(magnitude: 9 - fields.count))
                } else {
                    let calendarField = udat_toCalendarDateField(field)

                    if calendarField != failureField,
                       let component = Calendar.Component(calendarField) {
                        schedule.reduce(with: .components(.init(single: component)))
                    }
                }
            }
    }

    /// Remove sections marked with `'` from the string as required to purge string literals from
    /// `Date/FormatString/rawFormat`.
    ///
    /// E.g.: `"'hello, it''s 'hh':'mm"` is turned into `"hhmm"`.
    fileprivate func purgingStringLiterals() -> String {
        self.split(separator: "'", omittingEmptySubsequences: false)
            .enumerated()
            .filter { offset, _ in offset.isMultiple(of: 2) }
            .map(\.element)
            .joined()
    }
}
