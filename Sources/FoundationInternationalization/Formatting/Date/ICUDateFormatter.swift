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

#if FOUNDATION_FRAMEWORK
@_implementationOnly import FoundationICU
#else
package import FoundationICU
#endif

typealias UChar = UInt16

enum HourCycleOverride {
    case force12hour
    case force24hour
}

final class ICUDateFormatter {

    var udateFormat: UnsafeMutablePointer<UDateFormat?>
    var lenientParsing: Bool

    private init(localeIdentifier: String, timeZoneIdentifier: String, calendarIdentifier: Calendar.Identifier, firstWeekday: Int, minimumDaysInFirstWeek: Int, capitalizationContext: FormatStyleCapitalizationContext, pattern: String, twoDigitStartDate: Date, lenientParsing: Bool) {
        self.lenientParsing = lenientParsing

        // We failed to construct a locale with the given calendar; fall back to locale's identifier
        let localeIdentifierWithCalendar = Calendar.localeIdentifierWithCalendar(localeIdentifier: localeIdentifier, calendarIdentifier: calendarIdentifier) ?? localeIdentifier

        let tz = Array(timeZoneIdentifier.utf16)
        let pt = Array(pattern.utf16)

        var status = U_ZERO_ERROR
        udateFormat = udat_open(UDAT_PATTERN, UDAT_PATTERN, localeIdentifierWithCalendar, tz, Int32(tz.count), pt, Int32(pt.count), &status)!
        try! status.checkSuccess()

        udat_setContext(udateFormat, capitalizationContext.icuContext, &status)
        try! status.checkSuccess()

        if lenientParsing {
            udat_setLenient(udateFormat, UBool.true)
        } else {
            udat_setLenient(udateFormat, UBool.false)

            udat_setBooleanAttribute(udateFormat, UDAT_PARSE_ALLOW_WHITESPACE, UBool.false, &status)
            try! status.checkSuccess()

            udat_setBooleanAttribute(udateFormat, UDAT_PARSE_ALLOW_NUMERIC, UBool.false, &status)
            try! status.checkSuccess()

            udat_setBooleanAttribute(udateFormat, UDAT_PARSE_PARTIAL_LITERAL_MATCH, UBool.false, &status)
            try! status.checkSuccess()

            udat_setBooleanAttribute(udateFormat, UDAT_PARSE_MULTIPLE_PATTERNS_FOR_MATCH, UBool.false, &status)
            try! status.checkSuccess()
        }

        let udatCalendar = udat_getCalendar(udateFormat)
        let ucal = ucal_clone(udatCalendar, &status)
        defer { ucal_close(ucal) }
        try! status.checkSuccess()

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

    // -- Caching support

    // A Date.VerbatimFormatStyle, Date.FormatStyle and Date.ParseStrategy might be able to share a ICUDateFormatter
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

        func createICUDateFormatter() -> ICUDateFormatter {
            ICUDateFormatter(localeIdentifier: localeIdentifier, timeZoneIdentifier: timeZoneIdentifier, calendarIdentifier: calendarIdentifier, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, capitalizationContext: capitalizationContext, pattern: pattern, twoDigitStartDate: parseTwoDigitStartDate, lenientParsing: parseLenient)
        }

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

    static let formatterCache = FormatterCache<DateFormatInfo, ICUDateFormatter>()
    static var patternCache = LockedState<[Date.FormatStyle : String]>(initialState: [:])

    static func cachedFormatter(for dateFormatInfo: DateFormatInfo) -> ICUDateFormatter {
        return Self.formatterCache.formatter(for: dateFormatInfo, creator: dateFormatInfo.createICUDateFormatter)
    }

    static func cachedFormatter(for format: Date.FormatStyle) -> ICUDateFormatter {
        let hourCycleOption: ICUPatternGenerator.HourCycleOption
        if format.locale.force12Hour {
            hourCycleOption = .force12Hour
        } else if format.locale.force24Hour {
            hourCycleOption = .force24Hour
        } else {
            hourCycleOption = .default
        }
        let localeIdentifier = format.locale.identifier
        let calendarIdentifier = format.calendar.identifier
        let pattern = patternCache.withLock { state in
            if let cachedPattern = state[format] {
                return cachedPattern
            } else {
                var pattern = ICUPatternGenerator.localizedPatternForSkeleton(localeIdentifier: localeIdentifier, calendarIdentifier: calendarIdentifier, skeleton: format.symbols.formatterTemplate, hourCycleOption: hourCycleOption)
                if let dateStyle = format._dateStyle, let datePatternOverride = format.locale.customDateFormat(dateStyle) {
                    // substitue date part from pattern with customDatePattern
                    let datePattern = ICUPatternGenerator.localizedPatternForSkeleton(localeIdentifier: localeIdentifier, calendarIdentifier: calendarIdentifier, skeleton: format.symbols.dateTemplate, hourCycleOption: hourCycleOption)
                    pattern.replace(datePattern, with: datePatternOverride)
                }
                
                state[format] = pattern
                return pattern
            }
        }

        let firstWeekday: Int
        if let forceFirstWeekday = format.locale.forceFirstWeekday(calendarIdentifier) {
            firstWeekday = forceFirstWeekday.icuIndex
        } else {
            firstWeekday = format.calendar.firstWeekday
        }

        let info = DateFormatInfo(localeIdentifier: localeIdentifier, timeZoneIdentifier: format.timeZone.identifier, calendarIdentifier: calendarIdentifier, firstWeekday: firstWeekday, minimumDaysInFirstWeek: format.calendar.minimumDaysInFirstWeek, capitalizationContext: format.capitalizationContext, pattern: pattern, parseLenient: format.parseLenient)

        return cachedFormatter(for: info)
    }

    static func cachedFormatter(for format: Date.VerbatimFormatStyle) -> ICUDateFormatter {
        let info = DateFormatInfo(localeIdentifier: format.locale?.identifier, timeZoneIdentifier: format.timeZone.identifier, calendarIdentifier: format.calendar.identifier, firstWeekday: format.calendar.firstWeekday, minimumDaysInFirstWeek: format.calendar.minimumDaysInFirstWeek, capitalizationContext: .unknown, pattern: format.formatPattern)
        return cachedFormatter(for: info)
    }
}
