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

#if !FOUNDATION_LIST_FORMAT_ICU

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

internal import _FoundationInternationalizationData

// MARK: - Types

/// Resolved list-formatting patterns for one (type, width) slot, parameterized by locale.
internal struct ListPatterns: Hashable, Sendable {
    let start: String
    let middle: String
    let end: String
    let pair: String
}

/// A locale-specific contextual rule that may modify the `end`/`pair` pattern
/// based on the surrounding text. Application happens in
/// `NativeListFormatter.apply`; the data tables don't carry the tag because
/// it's determined by `(locale.language, type, default-pattern)` at format time.
internal enum ListPatternCondition: Sendable, Hashable {
    case spanishYToE
    case spanishOToU
    case hebrewNonHebrewPrefix
    case thaiContextual
}

// MARK: - Locale lookup

/// Resolve `(locale, type, width)` to a `ListPatterns` row by walking the
/// parent chain across the packed C data tables. `type` is 0/1/2 for and/or/unit;
/// `width` is 0/1/2 for wide/short/narrow (matching the public enum raw values).
internal func _listPatterns(locale: String, type: Int, width: Int) -> ListPatterns {
    // Walk the parent chain looking for the first ancestor that has data for
    // this slot. If the walk exhausts without a match, retry from the
    // configured fallback locale.
    if let row = _walkSlot(locale: locale, type: type, width: width) {
        return _row(at: row)
    }
    let fallback = String(cString: _ListFormatFallbackLocale)
    if fallback != locale, let row = _walkSlot(locale: fallback, type: type, width: width) {
        return _row(at: row)
    }
    // Genuinely no data — return an empty placeholder. In practice this only
    // happens if root itself is missing from the data set, which is invalid.
    return ListPatterns(start: "{0}, {1}", middle: "{0}, {1}", end: "{0}, {1}", pair: "{0}, {1}")
}

/// Walk the parent chain for `locale`, returning the row index of the first
/// ancestor with an entry in the given slot. Returns nil if the walk reaches
/// root (or beyond) without finding anything — caller falls back to the
/// configured fallback locale.
private func _walkSlot(locale: String, type: Int, width: Int) -> UInt16? {
    var current: String? = locale
    while let l = current {
        if let row = _searchSlot(locale: l, type: type, width: width) {
            return row
        }
        current = _listFormatParent(of: l)
    }
    return nil
}

/// Mirror of the generator's parent walk: explicit parent-map override first,
/// then truncation, then root (with root terminating the walk).
internal func _listFormatParent(of locale: String) -> String? {
    if locale == "root" { return nil }
    if let p = _parentLookup(child: locale) { return p }
    if let underscore = locale.lastIndex(of: "_") {
        return String(locale[..<underscore])
    }
    return "root"
}

// MARK: - Binary search over the C tables

/// Look up `locale` in the slot table for `(type, width)`. Returns the row
/// index if present.
private func _searchSlot(locale: String, type: Int, width: Int) -> UInt16? {
    switch (type, width) {
    case (0, 0):
        return withUnsafePointer(to: _ListFormatSlot_AndWide) { ptr in
            _bsearchSlot(target: locale, base: UnsafeRawPointer(ptr).assumingMemoryBound(to: _ListFormatSlotEntry.self),
                         count: Int(_ListFormatSlot_AndWide_Count))
        }
    case (0, 1):
        return withUnsafePointer(to: _ListFormatSlot_AndShort) { ptr in
            _bsearchSlot(target: locale, base: UnsafeRawPointer(ptr).assumingMemoryBound(to: _ListFormatSlotEntry.self),
                         count: Int(_ListFormatSlot_AndShort_Count))
        }
    case (0, 2):
        return withUnsafePointer(to: _ListFormatSlot_AndNarrow) { ptr in
            _bsearchSlot(target: locale, base: UnsafeRawPointer(ptr).assumingMemoryBound(to: _ListFormatSlotEntry.self),
                         count: Int(_ListFormatSlot_AndNarrow_Count))
        }
    case (1, 0):
        return withUnsafePointer(to: _ListFormatSlot_OrWide) { ptr in
            _bsearchSlot(target: locale, base: UnsafeRawPointer(ptr).assumingMemoryBound(to: _ListFormatSlotEntry.self),
                         count: Int(_ListFormatSlot_OrWide_Count))
        }
    case (1, 1):
        return withUnsafePointer(to: _ListFormatSlot_OrShort) { ptr in
            _bsearchSlot(target: locale, base: UnsafeRawPointer(ptr).assumingMemoryBound(to: _ListFormatSlotEntry.self),
                         count: Int(_ListFormatSlot_OrShort_Count))
        }
    case (1, 2):
        return withUnsafePointer(to: _ListFormatSlot_OrNarrow) { ptr in
            _bsearchSlot(target: locale, base: UnsafeRawPointer(ptr).assumingMemoryBound(to: _ListFormatSlotEntry.self),
                         count: Int(_ListFormatSlot_OrNarrow_Count))
        }
    case (2, 0):
        return withUnsafePointer(to: _ListFormatSlot_UnitWide) { ptr in
            _bsearchSlot(target: locale, base: UnsafeRawPointer(ptr).assumingMemoryBound(to: _ListFormatSlotEntry.self),
                         count: Int(_ListFormatSlot_UnitWide_Count))
        }
    case (2, 1):
        return withUnsafePointer(to: _ListFormatSlot_UnitShort) { ptr in
            _bsearchSlot(target: locale, base: UnsafeRawPointer(ptr).assumingMemoryBound(to: _ListFormatSlotEntry.self),
                         count: Int(_ListFormatSlot_UnitShort_Count))
        }
    case (2, 2):
        return withUnsafePointer(to: _ListFormatSlot_UnitNarrow) { ptr in
            _bsearchSlot(target: locale, base: UnsafeRawPointer(ptr).assumingMemoryBound(to: _ListFormatSlotEntry.self),
                         count: Int(_ListFormatSlot_UnitNarrow_Count))
        }
    default:
        return nil
    }
}

/// Binary search over a sorted slot table. Compares via `strcmp` on the C
/// strings — locale identifiers are pure ASCII so byte-wise comparison gives
/// the same order as Swift's String comparison without per-step allocation.
/// Slot entries reference their locale string indirectly through
/// `_ListFormatLocales`.
private func _bsearchSlot(
    target: String,
    base: UnsafePointer<_ListFormatSlotEntry>,
    count: Int
) -> UInt16? {
    return target.withCString { cTarget -> UInt16? in
        withUnsafePointer(to: _ListFormatLocales) { poolPtr in
            let pool = UnsafeRawPointer(poolPtr).assumingMemoryBound(to: UnsafePointer<CChar>?.self)
            var lo = 0
            var hi = count - 1
            while lo <= hi {
                let mid = (lo &+ hi) / 2
                let entry = base[mid]
                let cmp = strcmp(cTarget, pool[Int(entry.locale)]!)
                if cmp == 0 { return entry.row }
                if cmp > 0 { lo = mid &+ 1 } else { hi = mid &- 1 }
            }
            return nil
        }
    }
}

/// Look up a child locale's parent in the explicit override map.
private func _parentLookup(child: String) -> String? {
    return child.withCString { cChild -> String? in
        withUnsafePointer(to: _ListFormatParents) { ptr in
            withUnsafePointer(to: _ListFormatLocales) { poolPtr in
                let base = UnsafeRawPointer(ptr).assumingMemoryBound(to: _ListFormatParentEntry.self)
                let pool = UnsafeRawPointer(poolPtr).assumingMemoryBound(to: UnsafePointer<CChar>?.self)
                var lo = 0
                var hi = Int(_ListFormatParentCount) - 1
                while lo <= hi {
                    let mid = (lo &+ hi) / 2
                    let entry = base[mid]
                    let cmp = strcmp(cChild, pool[Int(entry.child)]!)
                    if cmp == 0 { return String(cString: pool[Int(entry.parent)]!) }
                    if cmp > 0 { lo = mid &+ 1 } else { hi = mid &- 1 }
                }
                return nil
            }
        }
    }
}

/// Materialize a `ListPatterns` row by indexing into the row table and the
/// pattern pool. Allocates four Swift strings per call; cache the result if
/// you'll use it many times.
private func _row(at index: UInt16) -> ListPatterns {
    let rowData = withUnsafePointer(to: _ListFormatRows) { ptr in
        let base = UnsafeRawPointer(ptr).assumingMemoryBound(to: _ListFormatRow.self)
        return base[Int(index)]
    }
    return ListPatterns(
        start: _pattern(at: rowData.start),
        middle: _pattern(at: rowData.middle),
        end: _pattern(at: rowData.end),
        pair: _pattern(at: rowData.pair)
    )
}

private func _pattern(at index: UInt16) -> String {
    return withUnsafePointer(to: _ListFormatPatterns) { ptr in
        let base = UnsafeRawPointer(ptr).assumingMemoryBound(to: UnsafePointer<CChar>?.self)
        return String(cString: base[Int(index)]!)
    }
}

// MARK: - Contextual conditions

/// Returns the contextual rule that applies to a given `(language, type,
/// default-pattern)`, or `nil` if no rule applies.
internal func _listPatternCondition(language: String, type: Int, defaultPattern: String) -> ListPatternCondition? {
    if language == "es" {
        if (type == 0 || type == 2) && defaultPattern == "{0} y {1}" {
            return .spanishYToE
        }
        if type == 1 && defaultPattern == "{0} o {1}" {
            return .spanishOToU
        }
    }
    if language == "he" || language == "iw", defaultPattern == "{0} \u{05D5}{1}" {
        return .hebrewNonHebrewPrefix
    }
    if language == "th", type == 0 {
        return .thaiContextual
    }
    return nil
}

// MARK: - Predicate implementations

internal func _spanishYToEFires(on text: String) -> Bool {
    var iter = text.unicodeScalars.makeIterator()
    guard let c0 = iter.next() else { return false }
    if c0 == "i" || c0 == "I" { return true }
    if c0 != "h" && c0 != "H" { return false }
    guard let c1 = iter.next() else { return false }
    if c1 != "i" && c1 != "I" { return false }
    guard let c2 = iter.next() else { return true }
    return c2 != "a" && c2 != "A" && c2 != "e" && c2 != "E"
}

internal func _spanishOToUFires(on text: String) -> Bool {
    var iter = text.unicodeScalars.makeIterator()
    guard let c0 = iter.next() else { return false }
    if c0 == "o" || c0 == "O" || c0 == "8" { return true }
    if c0 == "h" || c0 == "H" {
        if let c1 = iter.next(), c1 == "o" || c1 == "O" { return true }
        return false
    }
    if c0 == "1" {
        guard let c1 = iter.next(), c1 == "1" else { return false }
        guard let c2 = iter.next() else { return true }
        return c2 == " "
    }
    return false
}

internal func _hebrewVavDashFires(on text: String) -> Bool {
    guard let scalar = text.unicodeScalars.first else { return false }
    let v = scalar.value
    let isHebrewBlock = (0x0590...0x05FF).contains(v) || (0xFB1D...0xFB4F).contains(v)
    return !isHebrewBlock
}

internal func _thaiNeedsSpace(adjacentScalar: Unicode.Scalar?) -> Bool {
    guard let s = adjacentScalar else { return false }
    return !(0x0E00...0x0E7F).contains(s.value)
}

#endif // !FOUNDATION_LIST_FORMAT_ICU
