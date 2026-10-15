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

#if FOUNDATION_DATE_FORMAT_SWIFT

// Reads the tables in DateFormatData.swift, which stay `internal` to this
// module so they compile into read-only data. The slot orders here match
// utils/update-date-format-data-impl.swift, and the sub-blocks match
// `subBlockSizes` in utils/build-date-format-data-impl.swift.

// MARK: - Strings

/// A string in the tables, as a 4-byte entry. See DateFormatData.swift.
package struct DateFormatDataString : Sendable {
    let entry: UInt32

    package var isEmpty: Bool { entry & 0xFF == 0 }

    package func append(to bytes: inout [UInt8]) {
        let count = Int(entry & 0xFF)
        if count <= 3 {
            for i in 0 ..< count {
                bytes.append(UInt8(truncatingIfNeeded: entry >> (8 * (i + 1))))
            }
        } else {
            let offset = Int(entry >> 8)
            bytes.append(addingCapacity: count) { output in
                for i in offset ..< offset + count {
                    output.append(_DateFormatData.pool[i])
                }
            }
        }
    }

    package var string: String {
        var bytes: [UInt8] = []
        append(to: &bytes)
        return String(decoding: bytes, as: UTF8.self)
    }

    /// Calls `body` with the string's UTF-8 bytes.
    func withUTF8<R>(_ body: (Span<UInt8>) -> R) -> R {
        let count = Int(entry & 0xFF)
        if count <= 3 {
            let inline: InlineArray<3, UInt8> = [UInt8(truncatingIfNeeded: entry >> 8), UInt8(truncatingIfNeeded: entry >> 16), UInt8(truncatingIfNeeded: entry >> 24)]
            return body(inline.span.extracting(0 ..< count))
        }
        // Copy the string, since passing on the pool's span would copy the whole table to the stack.
        let offset = Int(entry >> 8)
        if count <= 16 {
            var bytes: InlineArray<16, UInt8> = .init(repeating: 0)
            for i in 0 ..< count {
                bytes[i] = _DateFormatData.pool[offset + i]
            }
            return body(bytes.span.extracting(0 ..< count))
        }
        var bytes: [UInt8] = []
        append(to: &bytes)
        return body(bytes.span)
    }

    /// Compares with UTF-8 bytes, as `strcmp` orders ASCII identifiers.
    func compare(_ other: Span<UInt8>) -> Int {
        let count = Int(entry & 0xFF)
        let offset = Int(entry >> 8)
        let n = min(count, other.count)
        var i = 0
        while i < n {
            let byte = count <= 3 ? UInt8(truncatingIfNeeded: entry >> (8 * (i + 1))) : _DateFormatData.pool[offset + i]
            if byte != other[i] { return byte < other[i] ? -1 : 1 }
            i &+= 1
        }
        return count == other.count ? 0 : (count < other.count ? -1 : 1)
    }
}

/// Binary search over sorted string entries.
/// Takes the table as a subscript closure because passing a static `InlineArray`'s `.span` to a call that isn't inlined
/// copies the whole table to the stack.
private func _search(_ target: Span<UInt8>, count: Int, _ entry: (Int) -> UInt32) -> Int? {
    var lo = 0
    var hi = count - 1
    while lo <= hi {
        let mid = (lo &+ hi) / 2
        let cmp = DateFormatDataString(entry: entry(mid)).compare(target)
        if cmp == 0 { return mid }
        if cmp < 0 { lo = mid &+ 1 } else { hi = mid &- 1 }
    }
    return nil
}

private func _search(_ target: String, count: Int, _ entry: (Int) -> UInt32) -> Int? {
    var target = target
    target.makeContiguousUTF8()
    return _search(target.utf8Span.span, count: count, entry)
}

// MARK: - Locales

/// Each group's first sub-block in a row. Groups have one sub-block per context and width, in slot order.
package enum DateFormatDataGroup : Int {
    case numbers = 0, months = 1, weekdays = 7, quarters = 15, eras = 21, dayPeriods = 24, gmt = 27, capitalization = 28
}

/// The contextTransforms usages for date fields, in table order.
package enum DateFormatCapitalizationUsage : Int {
    case monthFormat, monthStandalone, monthNarrow, dayFormat, dayStandalone, dayNarrow, eraWide, eraAbbreviated, eraNarrow
    /// Output that starts with fixed text, an Apple addition.
    case dateOtherBeginning
}

/// The name contexts CLDR stores.
package enum DateFormatNameContext : Int {
    case format, standalone
}

/// Name widths, in table order. Weekdays also have `short`.
package enum DateFormatNameWidth : Int {
    case abbreviated, narrow, wide, short
}

/// A locale's date-format data.
package struct DateFormatLocale : Sendable {
    /// The locale's row's first index in `rows`.
    let row: Int

    /// Resolves a locale identifier, ignoring keywords, to the nearest locale in the tables.
    ///
    /// Where the identifier's language has no data, this uses the tables' built-in fallback locale if they have one,
    /// else root.
    package init(identifier: String) {
        let index = Self.index(for: Self.baseName(identifier)) ?? Self.fallbackIndex()
        row = Int(_DateFormatData.localeRows[index]) * _DateFormatData.rowWidth
    }

    /// The identifier without keywords, with `_` separators. An empty identifier is root.
    static func baseName(_ identifier: String) -> String {
        var base = identifier
        if let at = base.utf8.firstIndex(of: UInt8(ascii: "@")) {
            base = String(base[..<at])
        }
        if base.utf8.contains(UInt8(ascii: "-")) {
            base = String(decoding: base.utf8.map { $0 == UInt8(ascii: "-") ? UInt8(ascii: "_") : $0 }, as: UTF8.self)
        }
        return base.isEmpty ? "root" : base
    }

    /// Follows redirects, else drops the last subtag. The generator builds aliases, CLDR parent locales,
    /// and ICU's script fallback (such as en_Latn_GB to en_GB) into the redirects.
    /// Returns nil where the identifier's language has no data.
    static func index(for identifier: String) -> Int? {
        var current = identifier
        while true {
            if let index = _search(current, count: _DateFormatData.localeIDs.count, { _DateFormatData.localeIDs[$0] }) {
                return index
            }
            if let redirect = _search(current, count: _DateFormatData.redirectFrom.count, { _DateFormatData.redirectFrom[$0] }) {
                current = DateFormatDataString(entry: _DateFormatData.redirectTo[redirect]).string
            } else if let underscore = current.utf8.lastIndex(of: UInt8(ascii: "_")) {
                current = String(current[..<underscore])
            } else {
                return nil
            }
        }
    }

    static func fallbackIndex() -> Int {
        let fallback = _DateFormatData.fallbackLocale.description
        if !fallback.isEmpty {
            return index(for: fallback)!
        }
        return index(for: "root")!
    }

    /// The string in `slot` of the locale's `subBlock`th sub-block for `group`.
    package func string(_ group: DateFormatDataGroup, _ subBlock: Int, _ slot: Int) -> DateFormatDataString {
        let start = Int(_DateFormatData.rows[row + group.rawValue + subBlock])
        return DateFormatDataString(entry: _DateFormatData.names[start + slot])
    }

    // MARK: Names

    /// `month` is 1-based.
    package func month(_ month: Int, context: DateFormatNameContext, width: DateFormatNameWidth) -> DateFormatDataString {
        string(.months, context.rawValue * 3 + width.rawValue, month - 1)
    }

    /// `weekday` is 1-based, Sunday first.
    package func weekday(_ weekday: Int, context: DateFormatNameContext, width: DateFormatNameWidth) -> DateFormatDataString {
        // The table orders weekday widths abbreviated, narrow, short, wide.
        let widthSlot = switch width {
        case .abbreviated: 0
        case .narrow: 1
        case .short: 2
        case .wide: 3
        }
        return string(.weekdays, context.rawValue * 4 + widthSlot, weekday - 1)
    }

    /// `quarter` is 1-based.
    package func quarter(_ quarter: Int, context: DateFormatNameContext, width: DateFormatNameWidth) -> DateFormatDataString {
        string(.quarters, context.rawValue * 3 + width.rawValue, quarter - 1)
    }

    package func era(_ era: Int, width: DateFormatNameWidth) -> DateFormatDataString {
        string(.eras, width.rawValue, era)
    }

    /// `period` is 0 for AM, 1 for PM, 2 for noon.
    package func dayPeriod(_ period: Int, width: DateFormatNameWidth) -> DateFormatDataString {
        string(.dayPeriods, width.rawValue, period)
    }

    /// The localized GMT pattern, such as `GMT{0}`.
    package var gmtFormat: DateFormatDataString { string(.gmt, 0, 0) }

    /// The positive and negative offset patterns, such as `+HH:mm;-HH:mm`.
    package var hourFormat: DateFormatDataString { string(.gmt, 0, 1) }

    /// Whether to titlecase a field with this usage at the start of a UI list item or menu item, or when it stands alone.
    package func capitalizes(_ usage: DateFormatCapitalizationUsage, forListItem: Bool) -> Bool {
        // Two flags, for list items then standalone use, as "0" or "1".
        let flags = string(.capitalization, 0, usage.rawValue)
        guard !flags.isEmpty else { return false }
        return UInt8(truncatingIfNeeded: flags.entry >> (forListItem ? 8 : 16)) == UInt8(ascii: "1")
    }

    // MARK: Numbers

    /// The digits and minus sign for `identifier`, following its `numbers` and `rg` keywords as Apple's ICU does.
    /// This locale is the one `identifier` resolves to.
    package func numbers(identifier: String) -> DateFormatNumbers {
        let keywords = Keywords(identifier)
        let keyword = keywords.numbers
        // Apple's ICU drops numbers=hanidays and uses it only for the day field, so other fields get the default digits.
        let usesHanidays = keyword == "hanidays"
        let systemIndex: Int?
        let minusSlot: Int
        if keyword == nil || keyword == "default" || keyword == "native" || keyword == "traditional" || keyword == "finance" || usesHanidays {
            // Apple's ICU picks the numbering system from the language, script, and
            // region (from `rg`, else the identifier), without other subtags.
            // The minus sign for negative fields such as `u` still comes from the full locale, as ICU's DecimalFormatSymbols does.
            let regional = keywords.regionalBaseName(Self.baseName(identifier)).map { DateFormatLocale(identifier: $0) } ?? self
            let slot = switch keyword {
            case "native": 1
            case "traditional": 2
            case "finance": 3
            default: 0
            }
            let system = regional.string(.numbers, 0, slot)
            systemIndex = system.withUTF8 { _search($0, count: _DateFormatData.numberingSystemIDs.count, { _DateFormatData.numberingSystemIDs[$0] }) }
            minusSlot = system.withUTF8 { Self.minusSlot(forSystem: $0) }
        } else {
            var system = keyword!
            system.makeContiguousUTF8()
            systemIndex = _search(system.utf8Span.span, count: _DateFormatData.numberingSystemIDs.count, { _DateFormatData.numberingSystemIDs[$0] })
            minusSlot = Self.minusSlot(forSystem: system.utf8Span.span)
        }
        guard let systemIndex else {
            // Algorithmic numbering systems use Latin digits, where ICU formats them with RBNF rules (e.g. roman numerals). So do unknown ones.
            return DateFormatNumbers(zero: 0x30, minusSign: string(.numbers, 0, 4), usesHanidays: false)
        }
        return DateFormatNumbers(zero: _DateFormatData.numberingSystemZeros[systemIndex], minusSign: string(.numbers, 0, minusSlot), usesHanidays: usesHanidays)
    }

    /// The numbers slot for a numbering system's minus sign: its own if it has one, else the Latin one.
    private static func minusSlot(forSystem system: Span<UInt8>) -> Int {
        for i in 0 ..< _DateFormatData.minusSignSystems.count {
            if DateFormatDataString(entry: _DateFormatData.minusSignSystems[i]).compare(system) == 0 {
                return 4 + i
            }
        }
        return 4
    }
}

/// Digits and a minus sign for formatting numeric fields.
package struct DateFormatNumbers : Sendable {
    /// Zero's UTF-8, first byte lowest, or the system's index in `irregularDigits`.
    let zero: UInt32
    /// Each digit's UTF-8 length, or 0 for a system in `irregularDigits`.
    let digitLength: Int
    package let minusSign: DateFormatDataString
    /// Whether the day field uses Chinese day numerals, as Apple's ICU does for `numbers=hanidays`.
    package let usesHanidays: Bool

    /// `zero` is an entry in `numberingSystemZeros`.
    init(zero: UInt32, minusSign: DateFormatDataString, usesHanidays: Bool) {
        if zero & 0x8000_0000 != 0 {
            self.zero = zero & 0x7FFF_FFFF
            digitLength = 0
        } else {
            var utf8: UInt32 = 0
            var length = 0
            UTF8.encode(Unicode.Scalar(zero)!) {
                utf8 |= UInt32($0) << (8 * length)
                length += 1
            }
            self.zero = utf8
            digitLength = length
        }
        self.minusSign = minusSign
        self.usesHanidays = usesHanidays
    }

    /// `digit` is 0 through 9.
    package func appendDigit(_ digit: Int, to bytes: inout [UInt8]) {
        guard digitLength != 0 else {
            DateFormatDataString(entry: _DateFormatData.irregularDigits[Int(zero) * 10 + digit]).append(to: &bytes)
            return
        }
        // The digit adds to zero's last byte. Unrolled with wrapping arithmetic, since a loop with overflow checks is slower.
        let utf8 = zero &+ UInt32(truncatingIfNeeded: digit) &<< (UInt32(truncatingIfNeeded: digitLength &- 1) &* 8)
        bytes.append(UInt8(truncatingIfNeeded: utf8))
        if digitLength > 1 { bytes.append(UInt8(truncatingIfNeeded: utf8 &>> 8)) }
        if digitLength > 2 { bytes.append(UInt8(truncatingIfNeeded: utf8 &>> 16)) }
        if digitLength > 3 { bytes.append(UInt8(truncatingIfNeeded: utf8 &>> 24)) }
    }

    /// Whether the digits are ASCII 0-9.
    package var hasASCIIDigits: Bool {
        digitLength == 1 && zero == 0x30
    }

    /// The Chinese day numeral for `day`, 1 through 31.
    package static func hanidaysDay(_ day: Int) -> DateFormatDataString {
        DateFormatDataString(entry: _DateFormatData.hanidaysDays[day - 1])
    }
}

/// The `numbers` and `rg` keywords of a locale identifier.
struct Keywords {
    var numbers: String?
    var region: String?

    init(_ identifier: String) {
        guard let at = identifier.firstIndex(of: "@") else { return }
        for keyword in identifier[identifier.index(after: at)...].split(separator: ";") {
            let parts = keyword.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            switch parts[0].lowercased() {
            case "numbers": numbers = parts[1].lowercased()
            case "rg":
                // A subdivision such as "sazzzz" or "usca" names its first two letters' region, if that's valid.
                // Foundation rewrites any value longer than that as the whole region's subdivision before ICU sees it.
                let value = Array(parts[1].utf8.prefix(3))
                guard value.count == 3 else { continue }
                let letters = value.prefix(2).map { $0 & ~0x20 }
                guard letters.allSatisfy({ $0 >= UInt8(ascii: "A") && $0 <= UInt8(ascii: "Z") }) else { continue }
                let bit = Int(letters[0] - UInt8(ascii: "A")) * 26 + Int(letters[1] - UInt8(ascii: "A"))
                if _DateFormatData.validRegions[bit / 32] & (1 << (bit % 32)) != 0 {
                    region = String(decoding: letters, as: UTF8.self)
                }
            default: break
            }
        }
    }

    /// The language and script of `baseName`, with the `rg` region if there is one, else the identifier's own region.
    /// Returns nil where that's `baseName` itself.
    func regionalBaseName(_ baseName: String) -> String? {
        let utf8 = baseName.utf8
        // The language, an optional four-letter script, then an optional region of two letters or three digits.
        var end = utf8.firstIndex(of: UInt8(ascii: "_")) ?? utf8.endIndex
        if end < utf8.endIndex {
            let start = utf8.index(after: end)
            let subtagEnd = utf8[start...].firstIndex(of: UInt8(ascii: "_")) ?? utf8.endIndex
            if utf8.distance(from: start, to: subtagEnd) == 4 {
                end = subtagEnd
            }
            if end < utf8.endIndex {
                let start = utf8.index(after: end)
                let subtagEnd = utf8[start...].firstIndex(of: UInt8(ascii: "_")) ?? utf8.endIndex
                let count = utf8.distance(from: start, to: subtagEnd)
                if region == nil, count == 2 || count == 3, utf8[start ..< subtagEnd].allSatisfy({ ($0 >= UInt8(ascii: "A") && $0 <= UInt8(ascii: "Z")) || ($0 >= UInt8(ascii: "0") && $0 <= UInt8(ascii: "9")) }) {
                    end = subtagEnd
                }
            }
        }
        if let region {
            let result = String(baseName[..<end]) + "_" + region
            return result == baseName ? nil : result
        }
        return end == utf8.endIndex ? nil : String(baseName[..<end])
    }
}

#endif // FOUNDATION_DATE_FORMAT_SWIFT
