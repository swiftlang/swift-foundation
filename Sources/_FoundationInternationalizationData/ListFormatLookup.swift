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

// The list-format lookup, kept in the same module as the generated data so it
// can read the `internal` tables in `ListFormatData.swift` without exposing
// them across the module boundary. `FoundationInternationalization` reaches
// this layer through the `package` types and `_listFormatPatterns` entry point;
// it maps its public `ListFormatStyle` enums onto `ListFormatType`/`ListFormatWidth`
// via extensions on its side (those bridges depend on the public API, which this
// module cannot see).

// MARK: - Types

/// Resolved list-formatting patterns for one (type, width) slot, parameterized by locale.
package struct ListFormatPatterns: Hashable, Sendable {
    package let start: String
    package let middle: String
    package let end: String
    package let pair: String

    package init(start: String, middle: String, end: String, pair: String) {
        self.start = start
        self.middle = middle
        self.end = end
        self.pair = pair
    }
}

/// The list type dimension of the data (cumulative vs alternative). The public
/// `ListFormatStyle.ListType` maps onto this; kept as a separate type because
/// the data layer is independent of the public API surface.
package enum ListFormatType: Hashable {
    case and
    case or
}

/// The list width dimension of the data. The public `ListFormatStyle.Width`
/// maps onto this — note its `.standard` case corresponds to `.wide` here, the
/// name CLDR and the data tables use.
package enum ListFormatWidth: Hashable {
    case wide
    case short
    case narrow
}

// MARK: - Locale lookup

/// Resolve `(locale, type, width)` to a `ListFormatPatterns` row by walking the
/// parent chain across the packed Swift data tables.
package func _listFormatPatterns(locale: String, type: ListFormatType, width: ListFormatWidth) -> ListFormatPatterns {
    // Walk the parent chain looking for the first ancestor that has data for
    // this slot. If the walk exhausts without a match, retry from the
    // configured fallback locale.
    if let row = _walkSlot(locale: locale, type: type, width: width) {
        return _row(at: row)
    }
    let fallback = _staticStringToString(_ListFormatData.fallbackLocale)
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
package func _listFormatParent(of locale: String) -> String? {
    if locale == "root" { return nil }
    if let p = _parentLookup(child: locale) { return p }
    if let underscore = locale.lastIndex(of: "_") {
        return String(locale[..<underscore])
    }
    return "root"
}

// MARK: - Binary search over the Swift tables

/// Look up `locale` in the slot table for `(type, width)`. Returns the row
/// index if present. The switch only selects which table to search; the common
/// search code lives in `_searchLocaleTable`.
private func _searchSlot(locale: String, type: ListFormatType, width: ListFormatWidth) -> UInt16? {
    var locale = locale
    return locale.withUTF8 { target -> UInt16? in
        switch (type, width) {
        case (.and, .wide):   return _searchLocaleTable(target, _ListFormatData.slotAndWide.span,   key: { $0.locale }, value: { $0.row })
        case (.and, .short):  return _searchLocaleTable(target, _ListFormatData.slotAndShort.span,  key: { $0.locale }, value: { $0.row })
        case (.and, .narrow): return _searchLocaleTable(target, _ListFormatData.slotAndNarrow.span, key: { $0.locale }, value: { $0.row })
        case (.or, .wide):    return _searchLocaleTable(target, _ListFormatData.slotOrWide.span,    key: { $0.locale }, value: { $0.row })
        case (.or, .short):   return _searchLocaleTable(target, _ListFormatData.slotOrShort.span,   key: { $0.locale }, value: { $0.row })
        case (.or, .narrow):  return _searchLocaleTable(target, _ListFormatData.slotOrNarrow.span,  key: { $0.locale }, value: { $0.row })
        }
    }
}

/// Look up a child locale's parent in the explicit override map.
private func _parentLookup(child: String) -> String? {
    var child = child
    let parentIndex: UInt16? = child.withUTF8 { target in
        _searchLocaleTable(target, _ListFormatData.parents.span, key: { $0.child }, value: { $0.parent })
    }
    guard let parentIndex else { return nil }
    return _locale(at: parentIndex)
}

/// Binary search a sorted table of locale-keyed entries, shared by the slot and
/// parent-map lookups. `key` extracts the entry's index into `_ListFormatData.locales`
/// (the value compared against `target`); `value` maps a matched entry to the
/// return value. Comparison is byte-wise on the pooled UTF-8: locale identifiers
/// are pure ASCII, so byte order matches Swift's String comparison without
/// per-step allocation.
private func _searchLocaleTable<Entry>(
    _ target: UnsafeBufferPointer<UInt8>,
    _ table: Span<Entry>,
    key: (Entry) -> UInt16,
    value: (Entry) -> UInt16
) -> UInt16? {
    var lo = 0
    var hi = table.count - 1
    while lo <= hi {
        let mid = (lo &+ hi) / 2
        let entry = table[mid]
        let cmp = _ListFormatData.locales[Int(key(entry))].withUTF8Buffer { pool in
            _compareUTF8(target, pool)
        }
        if cmp == 0 { return value(entry) }
        if cmp > 0 { lo = mid &+ 1 } else { hi = mid &- 1 }
    }
    return nil
}

/// Lexicographic byte comparison of two UTF-8 buffers: negative if `a < b`,
/// zero if equal, positive if `a > b`. Matches `strcmp` ordering on the ASCII
/// locale identifiers.
private func _compareUTF8(_ a: UnsafeBufferPointer<UInt8>, _ b: UnsafeBufferPointer<UInt8>) -> Int {
    let n = min(a.count, b.count)
    var i = 0
    while i < n {
        if a[i] != b[i] { return a[i] < b[i] ? -1 : 1 }
        i &+= 1
    }
    if a.count == b.count { return 0 }
    return a.count < b.count ? -1 : 1
}

/// Materialize a `ListFormatPatterns` row by indexing into the row table and the
/// pattern pool. Allocates four Swift strings per call; cache the result if
/// you'll use it many times.
private func _row(at index: UInt16) -> ListFormatPatterns {
    let rowData = _ListFormatData.rows[Int(index)]
    return ListFormatPatterns(
        start: _pattern(at: rowData.start),
        middle: _pattern(at: rowData.middle),
        end: _pattern(at: rowData.end),
        pair: _pattern(at: rowData.pair)
    )
}

private func _pattern(at index: UInt16) -> String {
    _staticStringToString(_ListFormatData.patterns[Int(index)])
}

private func _locale(at index: UInt16) -> String {
    _staticStringToString(_ListFormatData.locales[Int(index)])
}

/// Decode a `StaticString` from the pool into a `String`. The pooled strings are
/// always stored as UTF-8 (never single scalars), so read the UTF-8 buffer
/// directly.
private func _staticStringToString(_ s: StaticString) -> String {
    s.withUTF8Buffer { String(decoding: $0, as: UTF8.self) }
}

#endif // !FOUNDATION_LIST_FORMAT_ICU
