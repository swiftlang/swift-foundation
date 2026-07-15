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
internal struct ListFormatPatterns: Hashable, Sendable {
    let start: String
    let middle: String
    let end: String
    let pair: String
}

/// The list type dimension of the data (cumulative vs alternative). The public
/// `ListFormatStyle.ListType` maps onto this; kept as a separate internal type
/// because the data layer is independent of the public API surface.
internal enum ListFormatType: Hashable {
    case and
    case or

    init<Style, Base>(_ listType: ListFormatStyle<Style, Base>.ListType) {
        switch listType {
        case .and: self = .and
        case .or: self = .or
        }
    }
}

/// The list width dimension of the data. The public `ListFormatStyle.Width`
/// maps onto this — note its `.standard` case corresponds to `.wide` here, the
/// name CLDR and the data tables use.
internal enum ListFormatWidth: Hashable {
    case wide
    case short
    case narrow

    init<Style, Base>(_ width: ListFormatStyle<Style, Base>.Width) {
        switch width {
        case .standard: self = .wide
        case .short: self = .short
        case .narrow: self = .narrow
        }
    }
}

// MARK: - Locale lookup

/// Resolve `(locale, type, width)` to a `ListFormatPatterns` row by walking the
/// parent chain across the packed C data tables.
internal func _listFormatPatterns(locale: String, type: ListFormatType, width: ListFormatWidth) -> ListFormatPatterns {
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
    return ListFormatPatterns(start: "{0}, {1}", middle: "{0}, {1}", end: "{0}, {1}", pair: "{0}, {1}")
}

/// Walk the parent chain for `locale`, returning the row index of the first
/// ancestor with an entry in the given slot. Returns nil if the walk reaches
/// root (or beyond) without finding anything — caller falls back to the
/// configured fallback locale.
private func _walkSlot(locale: String, type: ListFormatType, width: ListFormatWidth) -> UInt16? {
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
/// index if present. The switch only selects which table and count to use; the
/// common pointer/search code lives in the local `search` helper.
private func _searchSlot(locale: String, type: ListFormatType, width: ListFormatWidth) -> UInt16? {
    func search<T>(_ table: borrowing T, _ count: UInt16) -> UInt16? {
        withUnsafePointer(to: table) { ptr in
            _bsearchLocale(
                target: locale,
                base: UnsafeRawPointer(ptr).assumingMemoryBound(to: _ListFormatSlotEntry.self),
                count: Int(count),
                key: { $0.locale },
                result: { entry, _ in entry.row }
            )
        }
    }
    switch (type, width) {
    case (.and, .wide):   return search(_ListFormatSlot_AndWide,   _ListFormatSlot_AndWide_Count)
    case (.and, .short):  return search(_ListFormatSlot_AndShort,  _ListFormatSlot_AndShort_Count)
    case (.and, .narrow): return search(_ListFormatSlot_AndNarrow, _ListFormatSlot_AndNarrow_Count)
    case (.or, .wide):    return search(_ListFormatSlot_OrWide,    _ListFormatSlot_OrWide_Count)
    case (.or, .short):   return search(_ListFormatSlot_OrShort,   _ListFormatSlot_OrShort_Count)
    case (.or, .narrow):  return search(_ListFormatSlot_OrNarrow,  _ListFormatSlot_OrNarrow_Count)
    }
}

/// Look up a child locale's parent in the explicit override map.
private func _parentLookup(child: String) -> String? {
    withUnsafePointer(to: _ListFormatParents) { ptr in
        _bsearchLocale(
            target: child,
            base: UnsafeRawPointer(ptr).assumingMemoryBound(to: _ListFormatParentEntry.self),
            count: Int(_ListFormatParentCount),
            key: { $0.child },
            result: { entry, pool in String(cString: pool[Int(entry.parent)]!) }
        )
    }
}

/// Binary search a sorted table of locale-keyed entries, shared by the slot and
/// parent-map lookups. `key` extracts the entry's index into `_ListFormatLocales`
/// (the value compared against `target`); `result` maps a matched entry — plus
/// the locale pool, for entries that point at other pooled strings — to the
/// return value. Comparison is `strcmp` on the pooled C strings: locale
/// identifiers are pure ASCII, so byte-wise order matches Swift's String
/// comparison without per-step allocation.
private func _bsearchLocale<Entry, Result>(
    target: String,
    base: UnsafePointer<Entry>,
    count: Int,
    key: (Entry) -> UInt16,
    result: (Entry, UnsafePointer<UnsafePointer<CChar>?>) -> Result
) -> Result? {
    return target.withCString { cTarget -> Result? in
        withUnsafePointer(to: _ListFormatLocales) { poolPtr in
            let pool = UnsafeRawPointer(poolPtr).assumingMemoryBound(to: UnsafePointer<CChar>?.self)
            var lo = 0
            var hi = count - 1
            while lo <= hi {
                let mid = (lo &+ hi) / 2
                let entry = base[mid]
                let cmp = strcmp(cTarget, pool[Int(key(entry))]!)
                if cmp == 0 { return result(entry, pool) }
                if cmp > 0 { lo = mid &+ 1 } else { hi = mid &- 1 }
            }
            return nil
        }
    }
}

/// Materialize a `ListFormatPatterns` row by indexing into the row table and the
/// pattern pool. Allocates four Swift strings per call; cache the result if
/// you'll use it many times.
private func _row(at index: UInt16) -> ListFormatPatterns {
    let rowData = withUnsafePointer(to: _ListFormatRows) { ptr in
        let base = UnsafeRawPointer(ptr).assumingMemoryBound(to: _ListFormatRow.self)
        return base[Int(index)]
    }
    return ListFormatPatterns(
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

#endif // !FOUNDATION_LIST_FORMAT_ICU
