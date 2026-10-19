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

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

#if FOUNDATION_DATE_FORMAT_SWIFT

#if canImport(_FoundationInternationalizationData)
internal import _FoundationInternationalizationData
#endif

internal import Synchronization

/// Fills in a date pattern such as `"MMM d, y"` in Swift, in place of `ICUDateFormatter`'s formatting.
///
/// The pattern is walked on every call, as ICU's `SimpleDateFormat` does.
final class DatePatternFormatter : Sendable {
    let pattern: String
    let calendar: Calendar
    let locale: DateFormatLocale
    let numbers: DateFormatNumbers
    /// Whether the digits are ASCII 0-9, which `appendNumber` writes directly.
    let asciiDigits: Bool
    let capitalizationContext: FormatStyleCapitalizationContext
    let caseLanguage: CaseLanguage
    /// The calendar components the pattern's fields read.
    let components: Calendar.ComponentSet
    /// The locale's localized GMT format, for patterns with `O` or `Z` fields.
    let localizedGMT: LocalizedGMTFormat?
    /// The whole output for a calendar the data has no names for, such as `japanese_CALENDAR_IS_UNSUPPORTED`.
    let unsupportedCalendar: String?

    init(_ info: ICUDateFormatter.DateFormatInfo) {
        // ISO 8601 uses the Gregorian names.
        let isSupported = info.calendarIdentifier == .gregorian || info.calendarIdentifier == .iso8601
        unsupportedCalendar = isSupported ? nil : "\(info.calendarIdentifier.cldrIdentifier)_CALENDAR_IS_UNSUPPORTED"
        pattern = info.pattern
        let identifier = DataLocaleIdentifier(info.localeIdentifier)
        locale = DateFormatLocale(identifier)
        numbers = locale.numbers(identifier)
        asciiDigits = numbers.hasASCIIDigits
        capitalizationContext = info.capitalizationContext
        caseLanguage = CaseLanguage(identifier: info.localeIdentifier)
        var calendar = Calendar(identifier: info.calendarIdentifier)
        calendar.firstWeekday = info.firstWeekday
        calendar.minimumDaysInFirstWeek = info.minimumDaysInFirstWeek
        calendar.timeZone = TimeZone(identifier: info.timeZoneIdentifier) ?? .gmt
        self.calendar = calendar
        components = Self.components(for: info.pattern)
        localizedGMT = info.pattern.utf8.contains { $0 == UInt8(ascii: "O") || $0 == UInt8(ascii: "Z") } ? LocalizedGMTFormat(locale) : nil
    }

    /// The calendar components that `appendField` reads for the fields in `pattern`.
    private static func components(for pattern: String) -> Calendar.ComponentSet {
        var components: Calendar.ComponentSet = []
        var inQuote = false
        for byte in pattern.utf8 {
            if byte == UInt8(ascii: "'") {
                inQuote.toggle()
                continue
            }
            guard !inQuote else { continue }
            switch byte {
            case UInt8(ascii: "y"), UInt8(ascii: "U"): components.insert(.year)
            case UInt8(ascii: "u"), UInt8(ascii: "r"): components.formUnion([.era, .year])
            case UInt8(ascii: "Y"): components.insert(.yearForWeekOfYear)
            case UInt8(ascii: "G"): components.insert(.era)
            case UInt8(ascii: "M"), UInt8(ascii: "L"), UInt8(ascii: "Q"), UInt8(ascii: "q"): components.insert(.month)
            case UInt8(ascii: "d"): components.insert(.day)
            case UInt8(ascii: "D"): components.insert(.dayOfYear)
            case UInt8(ascii: "F"): components.insert(.weekdayOrdinal)
            case UInt8(ascii: "w"): components.insert(.weekOfYear)
            case UInt8(ascii: "W"): components.insert(.weekOfMonth)
            case UInt8(ascii: "E"), UInt8(ascii: "e"), UInt8(ascii: "c"): components.insert(.weekday)
            case UInt8(ascii: "a"), UInt8(ascii: "H"), UInt8(ascii: "k"), UInt8(ascii: "K"), UInt8(ascii: "h"): components.insert(.hour)
            case UInt8(ascii: "b"): components.formUnion([.hour, .minute, .second])
            case UInt8(ascii: "m"): components.insert(.minute)
            case UInt8(ascii: "s"): components.insert(.second)
            default: break
            }
        }
        return components
    }

    /// Whether `appendField` fills in a run of `count` copies of `letter`, rather than writing it with `_IS_UNSUPPORTED`.
    /// Letters that aren't ICU fields fail in `fill`, as in ICU.
    private static func isSupported(_ letter: UInt8, count: Int) -> Bool {
        switch letter {
        case UInt8(ascii: "z"), UInt8(ascii: "v"), UInt8(ascii: "B"): false
        // Only `VV`, the time zone's identifier.
        case UInt8(ascii: "V"): count == 2
        // `ddd` and longer are day-of-month names such as ordinals, as in Apple's ICU and ICU 79 (ICU-23364). Earlier ICU pads to three digits.
        case UInt8(ascii: "d"): count < 3
        default: true
        }
    }

    private static let cache = Mutex<[ICUDateFormatter.DateFormatInfo: DatePatternFormatter]>([:])

    /// A formatter for `info`, reused across calls as `ICUDateFormatter.cachedFormatter(for:)` reuses ICU formatters.
    static func cachedFormatter(for info: ICUDateFormatter.DateFormatInfo) -> DatePatternFormatter {
        if let existing = cache.withLock({ $0[info] }) {
            return existing
        }
        // Build the formatter outside the lock, as FormatterCache does.
        let formatter = DatePatternFormatter(info)
        return cache.withLock {
            if let existing = $0[info] {
                return existing
            }
            // Patterns vary without limit, so stay bounded as FormatterCache does.
            if $0.count > 100 {
                $0.removeAll()
            }
            $0[info] = formatter
            return formatter
        }
    }

    func format(_ date: Date) -> String? {
        if let unsupportedCalendar {
            return unsupportedCalendar
        }
        var output = Output(recordsFields: false)
        // Empty output counts as a failure, as it does for ICUDateFormatter.
        guard fill(date, into: &output), !output.bytes.isEmpty else {
            return nil
        }
        return String(decoding: output.bytes, as: UTF8.self)
    }

    func attributedFormat(_ date: Date) -> AttributedString? {
        if let unsupportedCalendar {
            return AttributedString(unsupportedCalendar)
        }
        var output = Output(recordsFields: true)
        guard fill(date, into: &output), !output.bytes.isEmpty else {
            return nil
        }
        var runs: [(count: Int, attributes: AttributeContainer)] = []
        var position = 0
        for field in output.fields {
            guard let dateField = AttributeScopes.FoundationAttributes.DateFieldAttribute.Field(patternLetter: field.letter) else {
                continue
            }
            runs.append((field.range.lowerBound - position, AttributeContainer()))
            var attributes = AttributeContainer()
            attributes.dateField = dateField
            runs.append((field.range.count, attributes))
            position = field.range.upperBound
        }
        runs.append((output.bytes.count - position, AttributeContainer()))
        return AttributedString(String(decoding: output.bytes, as: UTF8.self), utf8Runs: runs)
    }

    // MARK: - Pattern walk

    struct Output {
        var bytes: [UInt8] = []
        var fields: [(letter: UInt8, range: Range<Int>)] = []
        let recordsFields: Bool

        init(recordsFields: Bool) {
            self.recordsFields = recordsFields
            // Enough for most formatted dates, so most calls allocate once.
            bytes.reserveCapacity(64)
        }
    }

    /// Returns false where ICU would fail, such as for a letter that isn't a pattern character.
    private func fill(_ date: Date, into output: inout Output) -> Bool {
        // ICU fails for a date that isn't a number.
        guard !date.timeIntervalSinceReferenceDate.isNaN else {
            return false
        }
        var values = FieldValues(date: date, calendar: calendar, components: components)
        // A local, because a span can't borrow from a class property.
        let patternString = pattern
        let pattern = patternString.utf8Span.span
        var i = 0
        var inQuote = false
        var fieldIndex = 0
        // Whether text from the pattern comes before the first field, as Apple's ICU tracks it.
        var textBeforeFirstField = false
        while i < pattern.count {
            let byte = pattern[i]
            if byte == UInt8(ascii: "'") {
                // Two quotes in a row are a literal quote, inside or outside quoted text.
                if i + 1 < pattern.count && pattern[i + 1] == UInt8(ascii: "'") {
                    output.bytes.append(byte)
                    i += 2
                } else {
                    inQuote.toggle()
                    i += 1
                }
            } else if !inQuote && byte.isPatternSyntax {
                var end = i + 1
                while end < pattern.count && pattern[end] == byte {
                    end += 1
                }
                let start = output.bytes.count
                guard let recordsField = appendField(byte, count: end - i, &values, to: &output.bytes) else {
                    return false
                }
                // ICU capitalizes the first field. Apple's ICU skips it when text comes before it.
                if fieldIndex == 0 && !textBeforeFirstField && Self.isSupported(byte, count: end - i) && titlecases(Self.capitalizationUsage(byte, count: end - i)) {
                    titlecaseFirstLetter(&output.bytes, from: start)
                }
                if recordsField && output.recordsFields {
                    output.fields.append((byte, start..<output.bytes.count))
                }
                fieldIndex += 1
                i = end
            } else {
                output.bytes.append(byte)
                if fieldIndex == 0 {
                    textBeforeFirstField = true
                }
                i += 1
            }
        }
        // Apple's ICU capitalizes text before the first field instead.
        if textBeforeFirstField && titlecases(.dateOtherBeginning) {
            let shift = titlecaseFirstLetter(&output.bytes, from: 0)
            if shift != 0 {
                // Keep the field ranges on their fields. Apple's ICU leaves them where they were.
                output.fields = output.fields.map { ($0.letter, $0.range.lowerBound + shift ..< $0.range.upperBound + shift) }
            }
        }
        return true
    }

    // MARK: - Capitalization

    /// The contextTransforms usage for a field, as ICU's `SimpleDateFormat::subFormat` picks it, or nil for fields without one.
    private static func capitalizationUsage(_ letter: UInt8, count: Int) -> DateFormatCapitalizationUsage? {
        switch letter {
        case UInt8(ascii: "G"):
            return count == 5 ? .eraNarrow : count == 4 ? .eraWide : .eraAbbreviated
        case UInt8(ascii: "M"), UInt8(ascii: "L"):
            switch count {
            case 3, 4: return letter == UInt8(ascii: "M") ? .monthFormat : .monthStandalone
            case 5: return .monthNarrow
            default: return nil
            }
        case UInt8(ascii: "E"), UInt8(ascii: "e"), UInt8(ascii: "c"):
            if count < 3 && letter != UInt8(ascii: "E") {
                return nil
            }
            return count == 5 ? .dayNarrow : letter == UInt8(ascii: "c") ? .dayStandalone : .dayFormat
        default:
            return nil
        }
    }

    /// Whether the capitalization context calls for titlecasing text with this usage.
    private func titlecases(_ usage: DateFormatCapitalizationUsage?) -> Bool {
        switch capitalizationContext.option {
        case .beginningOfSentence: return true
        case .listItem: return usage.map { locale.capitalizes($0, forListItem: true) } ?? false
        case .standalone: return usage.map { locale.capitalizes($0, forListItem: false) } ?? false
        case .unknown, .middleOfSentence: return false
        }
    }

    /// Titlecases the letter at `start` if it's lowercase, leaving the rest unchanged, as ICU's `toTitle` does with
    /// `U_TITLECASE_NO_LOWERCASE | U_TITLECASE_NO_BREAK_ADJUSTMENT`. Returns the change in length.
    @discardableResult
    private func titlecaseFirstLetter(_ bytes: inout [UInt8], from start: Int) -> Int {
        guard start < bytes.count else { return 0 }
        var scalars = String(decoding: bytes[start...], as: UTF8.self).unicodeScalars[...]
        guard let first = scalars.first, first.properties.generalCategory == .lowercaseLetter else { return 0 }
        scalars = scalars.dropFirst()
        var title: String
        switch (caseLanguage, first) {
        case (.turkic, "i"): title = "\u{130}"
        case (.armenian, "\u{587}"): title = "\u{535}\u{57E}"
        default: title = first.properties.titlecaseMapping
        }
        if caseLanguage == .dutch, let (ij, rest) = Self.dutchIJ(after: title, scalars) {
            title += ij
            scalars = rest
        }
        var replacement = Array(title.utf8)
        replacement += String(scalars).utf8
        let shift = replacement.count - (bytes.count - start)
        bytes.replaceSubrange(start..., with: replacement)
        return shift
    }

    /// The rest of a Dutch "IJ" after its titlecased "I" or "Í", as ICU's `maybeTitleDutchIJ` writes it, and the text after it.
    /// Returns nil where the text doesn't continue an "ij".
    private static func dutchIJ(after title: String, _ scalars: Substring.UnicodeScalarView) -> (String, Substring.UnicodeScalarView)? {
        let acute: Unicode.Scalar = "\u{301}"
        var rest = scalars
        var text = ""
        var withAcute = title == "\u{CD}"
        if title == "I" && rest.first == acute {
            withAcute = true
            text.unicodeScalars.append(acute)
            rest = rest.dropFirst()
        }
        guard let j = rest.first, j == "j" || j == "J" else { return nil }
        text += "J"
        rest = rest.dropFirst()
        // An accented i needs an accented j.
        if withAcute {
            guard rest.first == acute else { return nil }
            text.unicodeScalars.append(acute)
            rest = rest.dropFirst()
        }
        if let next = rest.first, [.nonspacingMark, .spacingMark, .enclosingMark].contains(next.properties.generalCategory) {
            return nil
        }
        return (text, rest)
    }

    /// The languages whose titlecasing differs from the default, as ICU's `ucase_getCaseLocale` finds them.
    enum CaseLanguage {
        case `default`, turkic, dutch, armenian

        init(identifier: String) {
            // The language subtag, lowercased, packed into an integer to compare without allocating.
            var language: UInt32 = 0
            for byte in identifier.utf8.prefix(4) {
                guard (byte | 0x20) >= UInt8(ascii: "a") && (byte | 0x20) <= UInt8(ascii: "z") else { break }
                language = language << 8 | UInt32(byte | 0x20)
            }
            switch language {
            case 0x7472, 0x747572, 0x617A, 0x617A65: self = .turkic // tr, tur, az, aze
            case 0x6E6C, 0x6E6C64: self = .dutch // nl, nld
            case 0x6879, 0x687965: self = .armenian // hy, hye
            default: self = .default
            }
        }
    }

    // MARK: - Fields

    /// Appends one field, a run of `count` copies of `letter`.
    ///
    /// Returns whether the field gets a position, or nil where ICU would fail.
    private func appendField(_ letter: UInt8, count: Int, _ values: inout FieldValues, to bytes: inout [UInt8]) -> Bool? {
        guard Self.isSupported(letter, count: count) else {
            bytes.append(contentsOf: repeatElement(letter, count: count))
            bytes.append(contentsOf: "_IS_UNSUPPORTED".utf8)
            return true
        }
        switch letter {
        case UInt8(ascii: "y"), UInt8(ascii: "U"):
            // Gregorian has no cyclic year names, so `U` is the year.
            appendYear(values.components.year, count: count, to: &bytes)
        case UInt8(ascii: "Y"):
            appendYear(values.components.yearForWeekOfYear, count: count, to: &bytes)
        case UInt8(ascii: "u"), UInt8(ascii: "r"):
            appendNumber(values.extendedYear, minimumDigits: count, to: &bytes)
        case UInt8(ascii: "G"):
            locale.era(values.components.era, width: count == 5 ? .narrow : count == 4 ? .wide : .abbreviated).append(to: &bytes)
        case UInt8(ascii: "M"), UInt8(ascii: "L"):
            let context: DateFormatNameContext = letter == UInt8(ascii: "M") ? .format : .standalone
            switch count {
            case 3: locale.month(values.components.month, context: context, width: .abbreviated).append(to: &bytes)
            case 4: locale.month(values.components.month, context: context, width: .wide).append(to: &bytes)
            case 5: locale.month(values.components.month, context: context, width: .narrow).append(to: &bytes)
            default: appendNumber(values.components.month, minimumDigits: count, to: &bytes)
            }
        case UInt8(ascii: "d"):
            if numbers.usesHanidays {
                // Apple's ICU spells out the day, without padding.
                DateFormatNumbers.hanidaysDay(values.components.day).append(to: &bytes)
            } else {
                appendNumber(values.components.day, minimumDigits: count, to: &bytes)
            }
        case UInt8(ascii: "D"):
            appendNumber(values.components.dayOfYear, minimumDigits: count, to: &bytes)
        case UInt8(ascii: "F"):
            appendNumber(values.components.weekdayOrdinal, minimumDigits: count, to: &bytes)
        case UInt8(ascii: "w"):
            appendNumber(values.components.weekOfYear, minimumDigits: count, to: &bytes)
        case UInt8(ascii: "W"):
            appendNumber(values.components.weekOfMonth, minimumDigits: count, to: &bytes)
        case UInt8(ascii: "E"), UInt8(ascii: "e"), UInt8(ascii: "c"):
            if count < 3 && letter != UInt8(ascii: "E") {
                // ICU doesn't pad `cc`.
                appendNumber(values.localWeekday(firstWeekday: calendar.firstWeekday), minimumDigits: letter == UInt8(ascii: "c") ? 1 : count, to: &bytes)
            } else {
                let width: DateFormatNameWidth = switch count {
                case 4: .wide
                case 5: .narrow
                case 6: .short
                default: .abbreviated
                }
                locale.weekday(values.components.weekday, context: letter == UInt8(ascii: "c") ? .standalone : .format, width: width).append(to: &bytes)
            }
        case UInt8(ascii: "Q"), UInt8(ascii: "q"):
            let quarter = (values.components.month - 1) / 3 + 1
            let context: DateFormatNameContext = letter == UInt8(ascii: "Q") ? .format : .standalone
            switch count {
            case 1, 2: appendNumber(quarter, minimumDigits: count, to: &bytes)
            case 3: locale.quarter(quarter, context: context, width: .abbreviated).append(to: &bytes)
            case 4: locale.quarter(quarter, context: context, width: .wide).append(to: &bytes)
            default: locale.quarter(quarter, context: context, width: .narrow).append(to: &bytes)
            }
        case UInt8(ascii: "a"):
            let width: DateFormatNameWidth = count == 4 ? .wide : count == 5 ? .narrow : .abbreviated
            locale.dayPeriod(values.components.hour < 12 ? 0 : 1, width: width).append(to: &bytes)
        case UInt8(ascii: "b"):
            // Noon only when it's exactly noon as displayed. ICU never prints midnight.
            let components = values.components
            if components.hour == 12 && (components.minute == 0 || !patternShows(UInt8(ascii: "m"))) && (components.second == 0 || !patternShows(UInt8(ascii: "s"))) {
                let noon = locale.dayPeriod(2, width: count == 5 ? .narrow : count == 4 || count > 5 ? .wide : .abbreviated)
                if !noon.isEmpty {
                    noon.append(to: &bytes)
                    return true
                }
            }
            return appendField(UInt8(ascii: "a"), count: count, &values, to: &bytes)
        case UInt8(ascii: "H"):
            appendNumber(values.components.hour, minimumDigits: count, to: &bytes)
        case UInt8(ascii: "k"):
            let hour = values.components.hour
            appendNumber(hour == 0 ? 24 : hour, minimumDigits: count, to: &bytes)
        case UInt8(ascii: "K"):
            appendNumber(values.components.hour % 12, minimumDigits: count, to: &bytes)
        case UInt8(ascii: "h"):
            let hour = values.components.hour % 12
            appendNumber(hour == 0 ? 12 : hour, minimumDigits: count, to: &bytes)
        case UInt8(ascii: "m"):
            appendNumber(values.components.minute, minimumDigits: count, to: &bytes)
        case UInt8(ascii: "s"):
            appendNumber(values.components.second, minimumDigits: count, to: &bytes)
        case UInt8(ascii: "S"):
            // Fractional seconds are whole milliseconds, left-justified.
            var milliseconds = values.millisecond
            if count == 1 {
                milliseconds /= 100
            } else if count == 2 {
                milliseconds /= 10
            }
            appendNumber(milliseconds, minimumDigits: min(count, 3), to: &bytes)
            if count > 3 {
                appendNumber(0, minimumDigits: count - 3, to: &bytes)
            }
        case UInt8(ascii: "A"):
            appendNumber(values.millisecondsInDay, minimumDigits: count, to: &bytes)
        case UInt8(ascii: "g"):
            appendNumber(values.julianDay, minimumDigits: count, to: &bytes)
        case UInt8(ascii: "Z"):
            switch count {
            case 1...3:
                return appendISOOffset(values.offset, basic: true, utcIndicator: false, short: false, ignoresSeconds: false, to: &bytes)
            case 5:
                return appendISOOffset(values.offset, basic: false, utcIndicator: true, short: false, ignoresSeconds: false, to: &bytes)
            default:
                return appendLocalizedGMT(values.offset, short: false, to: &bytes)
            }
        case UInt8(ascii: "O"):
            switch count {
            case 1: return appendLocalizedGMT(values.offset, short: true, to: &bytes)
            case 4: return appendLocalizedGMT(values.offset, short: false, to: &bytes)
            default:
                // ICU writes nothing, but still reports the field.
                return true
            }
        case UInt8(ascii: "X"), UInt8(ascii: "x"):
            let utcIndicator = letter == UInt8(ascii: "X")
            switch count {
            case 1:
                return appendISOOffset(values.offset, basic: true, utcIndicator: utcIndicator, short: true, ignoresSeconds: true, to: &bytes)
            case 2:
                return appendISOOffset(values.offset, basic: true, utcIndicator: utcIndicator, short: false, ignoresSeconds: true, to: &bytes)
            case 3:
                return appendISOOffset(values.offset, basic: false, utcIndicator: utcIndicator, short: false, ignoresSeconds: true, to: &bytes)
            case 4:
                return appendISOOffset(values.offset, basic: true, utcIndicator: utcIndicator, short: false, ignoresSeconds: false, to: &bytes)
            case 5:
                return appendISOOffset(values.offset, basic: false, utcIndicator: utcIndicator, short: false, ignoresSeconds: false, to: &bytes)
            default:
                // ICU writes nothing, but still reports the field.
                return true
            }
        case UInt8(ascii: "V"):
            // `VV`, as `isSupported` allows.
            appendZoneID(to: &bytes)
        case UInt8(ascii: "l"):
            // ICU ignores `l`, and reports no field for it.
            return false
        default:
            return nil
        }
        return true
    }

    /// Whether `letter` appears outside quoted text anywhere in the pattern.
    private func patternShows(_ letter: UInt8) -> Bool {
        var inQuote = false
        for byte in pattern.utf8 {
            if byte == UInt8(ascii: "'") {
                inQuote.toggle()
            } else if byte == letter && !inQuote {
                return true
            }
        }
        return false
    }

    /// Appends the time zone's identifier, writing an offset zone such as "GMT+0530" as ICU does, "GMT+05:30".
    private func appendZoneID(to bytes: inout [UInt8]) {
        let identifier = calendar.timeZone.identifier.utf8
        let isOffset = identifier.count == 8 && identifier.starts(with: "GMT".utf8)
            && (identifier.dropFirst(3).first == UInt8(ascii: "+") || identifier.dropFirst(3).first == UInt8(ascii: "-"))
            && identifier.dropFirst(4).allSatisfy { $0 >= UInt8(ascii: "0") && $0 <= UInt8(ascii: "9") }
        if isOffset {
            bytes.append(contentsOf: identifier.prefix(6))
            bytes.append(UInt8(ascii: ":"))
            bytes.append(contentsOf: identifier.dropFirst(6))
        } else {
            bytes.append(contentsOf: identifier)
        }
    }

    private func appendYear(_ year: Int, count: Int, to bytes: inout [UInt8]) {
        if count == 2 {
            appendNumber(year, minimumDigits: 2, maximumDigits: 2, to: &bytes)
        } else {
            appendNumber(year, minimumDigits: count, to: &bytes)
        }
    }

    /// Appends `value` in the locale's digits, zero-padded to `minimumDigits`, keeping at most the low `maximumDigits` digits, as ICU's `zeroPaddingNumber` does.
    /// The default is ICU's `maxIntCount`, which `subFormat` passes for every numeric field but `yy`.
    private func appendNumber(_ value: Int, minimumDigits: Int, maximumDigits: Int = 10, to bytes: inout [UInt8]) {
        if value < 0 {
            numbers.minusSign.append(to: &bytes)
        }
        // Keep the low `maximumDigits` digits, writing the most significant first.
        let magnitude = value.magnitude
        var count = 1
        var divisor: UInt = 1
        while count < maximumDigits && magnitude / divisor >= 10 {
            divisor *= 10
            count += 1
        }
        for _ in 0 ..< max(min(minimumDigits, maximumDigits) - count, 0) {
            appendDigit(0, to: &bytes)
        }
        while divisor > 0 {
            appendDigit(Int(magnitude / divisor % 10), to: &bytes)
            divisor /= 10
        }
    }

    private func appendDigit(_ digit: Int, to bytes: inout [UInt8]) {
        if asciiDigits {
            bytes.append(UInt8(ascii: "0") + UInt8(digit))
        } else {
            numbers.appendDigit(digit, to: &bytes)
        }
    }

    /// Appends an ISO 8601 offset, as ICU's `TimeZoneFormat::formatOffsetISO8601` does. Returns nil for offsets of a day or more, which ICU rejects.
    private func appendISOOffset(_ offset: Int, basic: Bool, utcIndicator: Bool, short: Bool, ignoresSeconds: Bool, to bytes: inout [UInt8]) -> Bool? {
        let magnitude = offset.magnitude
        if utcIndicator && (magnitude == 0 || (ignoresSeconds && magnitude < 60)) {
            bytes.append(UInt8(ascii: "Z"))
            return true
        }
        guard magnitude < 86_400 else {
            return nil
        }
        let fields = [Int(magnitude / 3600), Int(magnitude % 3600 / 60), Int(magnitude % 60)]
        var last = ignoresSeconds ? 1 : 2
        let first = short ? 0 : 1
        while last > first && fields[last] == 0 {
            last -= 1
        }
        // A negative offset that rounds to all zeros gets a plus sign.
        let isNegative = offset < 0 && fields[0...last].contains { $0 != 0 }
        bytes.append(isNegative ? UInt8(ascii: "-") : UInt8(ascii: "+"))
        for index in 0 ... last {
            if !basic && index != 0 {
                bytes.append(UInt8(ascii: ":"))
            }
            bytes.append(UInt8(ascii: "0") + UInt8(fields[index] / 10))
            bytes.append(UInt8(ascii: "0") + UInt8(fields[index] % 10))
        }
        return true
    }

    /// Appends a localized GMT offset such as "GMT-07:00", as ICU's `TimeZoneFormat::formatOffsetLocalizedGMT` does. Returns nil for offsets of a day or more, which ICU rejects.
    ///
    /// The short form drops zero minutes and pads hours to one digit, not two.
    private func appendLocalizedGMT(_ offset: Int, short: Bool, to bytes: inout [UInt8]) -> Bool? {
        // A zero offset is written like any other, as ICU 78 does (ICU-23157). ICU 76 writes the locale's zero format, such as "GMT".
        let magnitude = offset.magnitude
        guard magnitude < 86_400, let localizedGMT, let patterns = offset < 0 ? localizedGMT.negative : localizedGMT.positive else {
            return nil
        }
        let hours = Int(magnitude / 3600), minutes = Int(magnitude % 3600 / 60), seconds = Int(magnitude % 60)
        let patternString: String? = if seconds != 0 {
            patterns.hoursMinutesSeconds
        } else if minutes == 0 && short {
            patterns.hours
        } else {
            patterns.hoursMinutes
        }
        guard let patternString else {
            return nil
        }
        let pattern = patternString.utf8Span.span

        bytes.append(contentsOf: localizedGMT.prefix.utf8)
        var inQuote = false
        var i = 0
        while i < pattern.count {
            let byte = pattern[i]
            if byte == UInt8(ascii: "'") {
                if i + 1 < pattern.count && pattern[i + 1] == UInt8(ascii: "'") {
                    bytes.append(byte)
                    i += 2
                } else {
                    inQuote.toggle()
                    i += 1
                }
                continue
            }
            if !inQuote && (byte == UInt8(ascii: "H") || byte == UInt8(ascii: "m") || byte == UInt8(ascii: "s")) {
                // ICU ignores the letter count: hours get one or two digits, minutes and seconds two.
                switch byte {
                case UInt8(ascii: "H"): appendNumber(hours, minimumDigits: short ? 1 : 2, to: &bytes)
                case UInt8(ascii: "m"): appendNumber(minutes, minimumDigits: 2, to: &bytes)
                default: appendNumber(seconds, minimumDigits: 2, to: &bytes)
                }
                while i < pattern.count && pattern[i] == byte {
                    i += 1
                }
                continue
            }
            bytes.append(byte)
            i += 1
        }
        bytes.append(contentsOf: localizedGMT.suffix.utf8)
        return true
    }

    /// A locale's localized GMT format, parsed once from its `gmtFormat` and `hourFormat`, as ICU's `TimeZoneFormat` does when it's created.
    struct LocalizedGMTFormat : Sendable {
        /// The offset patterns for one sign.
        struct Patterns : Sendable {
            let hoursMinutes: String
            /// Nil where ICU can't make an hours-only pattern.
            let hours: String?
            let hoursMinutesSeconds: String
        }

        /// The text around the offset, unquoted.
        let prefix: String, suffix: String
        /// Nil where the pattern for that sign has no minutes field, which ICU rejects.
        let positive: Patterns?, negative: Patterns?

        init?(_ locale: DateFormatLocale) {
            var gmtFormat: [UInt8] = []
            locale.gmtFormat.append(to: &gmtFormat)
            var hourFormat: [UInt8] = []
            locale.hourFormat.append(to: &hourFormat)
            // The hour format is the positive pattern, a semicolon, and the negative pattern.
            guard let argument = gmtFormat[...].firstRange(of: Array("{0}".utf8)), let semicolon = hourFormat.firstIndex(of: UInt8(ascii: ";")) else {
                return nil
            }
            var prefix: [UInt8] = [], suffix: [UInt8] = []
            DatePatternFormatter.appendUnquoted(gmtFormat[..<argument.lowerBound], to: &prefix)
            DatePatternFormatter.appendUnquoted(gmtFormat[argument.upperBound...], to: &suffix)
            self.prefix = String(decoding: prefix, as: UTF8.self)
            self.suffix = String(decoding: suffix, as: UTF8.self)
            positive = Self.patterns(hourFormat[..<semicolon])
            negative = Self.patterns(hourFormat[(semicolon + 1)...])
        }

        /// Makes the hours-only and hours-minutes-seconds patterns from the hours-minutes one, as ICU does.
        private static func patterns(_ pattern: ArraySlice<UInt8>) -> Patterns? {
            guard let minuteField = pattern.firstRange(of: Array("mm".utf8)) else {
                return nil
            }
            let separatorStart = pattern[..<minuteField.lowerBound].lastIndex(of: UInt8(ascii: "H")).map { $0 + 1 } ?? minuteField.lowerBound
            var withSeconds = Array(pattern[..<minuteField.upperBound])
            withSeconds += pattern[separatorStart ..< minuteField.lowerBound]
            withSeconds += "ss".utf8
            withSeconds += pattern[minuteField.upperBound...]
            let beforeMinutes = pattern[..<minuteField.lowerBound]
            let hourEnd = beforeMinutes.lastRange(of: Array("HH".utf8))?.upperBound ?? beforeMinutes.lastIndex(of: UInt8(ascii: "H")).map { $0 + 1 }
            return Patterns(hoursMinutes: String(decoding: pattern, as: UTF8.self), hours: hourEnd.map { String(decoding: pattern[..<$0], as: UTF8.self) }, hoursMinutesSeconds: String(decoding: withSeconds, as: UTF8.self))
        }
    }

    /// Appends text with ICU pattern quoting removed.
    private static func appendUnquoted(_ text: ArraySlice<UInt8>, to bytes: inout [UInt8]) {
        var previousWasQuote = false
        for byte in text {
            if byte == UInt8(ascii: "'") {
                if previousWasQuote {
                    bytes.append(byte)
                }
                previousWasQuote.toggle()
            } else {
                previousWasQuote = false
                bytes.append(byte)
            }
        }
    }
}

// MARK: - Field values

/// The values a pattern's fields read, computed on first use.
private struct FieldValues {
    /// Calendar components as plain integers, which are cheaper to pass around than `DateComponents`.
    /// Components the pattern doesn't read are 0.
    struct Components {
        var era = 0, year = 0, month = 0, day = 0, hour = 0, minute = 0, second = 0, weekday = 0
        var weekdayOrdinal = 0, dayOfYear = 0, weekOfYear = 0, weekOfMonth = 0, yearForWeekOfYear = 0
    }

    let date: Date
    let calendar: Calendar
    let componentSet: Calendar.ComponentSet
    private var _components: Components?

    init(date: Date, calendar: Calendar, components: Calendar.ComponentSet) {
        self.date = date
        self.calendar = calendar
        componentSet = components
    }

    var components: Components {
        mutating get {
            if let _components {
                return _components
            }
            let values = calendar._dateComponents(componentSet, from: date)
            let components = Components(era: values.era ?? 0, year: values.year ?? 0, month: values.month ?? 0, day: values.day ?? 0,
                                        hour: values.hour ?? 0, minute: values.minute ?? 0, second: values.second ?? 0, weekday: values.weekday ?? 0,
                                        weekdayOrdinal: values.weekdayOrdinal ?? 0, dayOfYear: values.dayOfYear ?? 0, weekOfYear: values.weekOfYear ?? 0,
                                        weekOfMonth: values.weekOfMonth ?? 0, yearForWeekOfYear: values.yearForWeekOfYear ?? 0)
            _components = components
            return components
        }
    }

    /// The Julian day of 1970-01-01, ICU's `kEpochStartAsJulianDay`.
    static let epochStartAsJulianDay: Int64 = 2_440_588

    /// Milliseconds since 1970, rounded down and clamped to Julian day ±0x7F000000, as ICU's calendar reads them.
    var udateMilliseconds: Int64 {
        let maxMilliseconds = Double((0x7F00_0000 - Self.epochStartAsJulianDay) * 86_400_000)
        let minMilliseconds = Double((-0x7F00_0000 - Self.epochStartAsJulianDay) * 86_400_000)
        return Int64(min(max((date.timeIntervalSince1970 * 1000).rounded(.down), minMilliseconds), maxMilliseconds))
    }

    var millisecond: Int {
        let remainder = Int(udateMilliseconds % 1000)
        return remainder < 0 ? remainder + 1000 : remainder
    }

    /// The offset from GMT in seconds.
    var offset: Int {
        calendar.timeZone.secondsFromGMT(for: date)
    }

    var localMilliseconds: Int64 {
        udateMilliseconds + Int64(offset) * 1000
    }

    var millisecondsInDay: Int {
        let remainder = Int(localMilliseconds % 86_400_000)
        return remainder < 0 ? remainder + 86_400_000 : remainder
    }

    var julianDay: Int {
        let milliseconds = localMilliseconds
        let days = milliseconds >= 0 ? milliseconds / 86_400_000 : (milliseconds + 1) / 86_400_000 - 1
        return Int(days + Self.epochStartAsJulianDay)
    }

    /// The year counted without eras: 1 BC is 0, 2 BC is -1.
    var extendedYear: Int {
        mutating get {
            let components = components
            return components.era == 0 ? 1 - components.year : components.year
        }
    }

    /// The weekday counted from the calendar's first weekday, starting at 1.
    mutating func localWeekday(firstWeekday: Int) -> Int {
        (components.weekday - firstWeekday + 7) % 7 + 1
    }
}

extension UInt8 {
    /// Whether ICU treats this byte as a pattern letter rather than literal text.
    fileprivate var isPatternSyntax: Bool {
        (self >= UInt8(ascii: "A") && self <= UInt8(ascii: "Z")) || (self >= UInt8(ascii: "a") && self <= UInt8(ascii: "z"))
    }
}

extension AttributeScopes.FoundationAttributes.DateFieldAttribute.Field {
    /// The attribute for a pattern letter, matching `init(udateFormatField:)`.
    init?(patternLetter: UInt8) {
        switch patternLetter {
        case UInt8(ascii: "G"): self = .era
        case UInt8(ascii: "y"), UInt8(ascii: "Y"), UInt8(ascii: "u"), UInt8(ascii: "U"): self = .year
        case UInt8(ascii: "M"), UInt8(ascii: "L"): self = .month
        case UInt8(ascii: "d"), UInt8(ascii: "g"): self = .day
        case UInt8(ascii: "D"): self = .dayOfYear
        case UInt8(ascii: "F"): self = .weekdayOrdinal
        case UInt8(ascii: "w"): self = .weekOfYear
        case UInt8(ascii: "W"): self = .weekOfMonth
        case UInt8(ascii: "E"), UInt8(ascii: "e"), UInt8(ascii: "c"): self = .weekday
        case UInt8(ascii: "Q"), UInt8(ascii: "q"): self = .quarter
        case UInt8(ascii: "a"), UInt8(ascii: "b"), UInt8(ascii: "B"): self = .amPM
        case UInt8(ascii: "h"), UInt8(ascii: "H"), UInt8(ascii: "k"), UInt8(ascii: "K"): self = .hour
        case UInt8(ascii: "m"): self = .minute
        case UInt8(ascii: "s"), UInt8(ascii: "A"): self = .second
        case UInt8(ascii: "S"): self = .secondFraction
        case UInt8(ascii: "z"), UInt8(ascii: "Z"), UInt8(ascii: "v"), UInt8(ascii: "V"), UInt8(ascii: "O"), UInt8(ascii: "X"), UInt8(ascii: "x"): self = .timeZone
        default:
            // `init(udateFormatField:)` has no attribute for `r` (related year).
            return nil
        }
    }
}

#endif // FOUNDATION_DATE_FORMAT_SWIFT
