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
    // Reconcile the runtime identifier with the underscore-keyed CLDR data
    // before walking the parent chain (see `_lookupLocale`).
    let locale = _lookupLocale(from: locale)
    // Walk the parent chain looking for the first ancestor that has data for
    // this slot. If the walk exhausts without a match, retry from the
    // configured fallback locale.
    if let row = _walkSlot(locale: locale, type: type, width: width) {
        return _row(at: row)
    }
    let fallback = _ListFormatData.fallbackLocale.description
    if fallback != locale, let row = _walkSlot(locale: fallback, type: type, width: width) {
        return _row(at: row)
    }
    // Genuinely no data — return an empty placeholder. In practice this only
    // happens if root itself is missing from the data set, which is invalid.
    return ListFormatPatterns(start: "{0}, {1}", middle: "{0}, {1}", end: "{0}, {1}", pair: "{0}, {1}")
}

/// Normalize the incoming `Locale.identifier` to the underscore separators the
/// data tables are keyed on. On the `FOUNDATION_FRAMEWORK` build,
/// `Locale.identifier` canonicalization (CoreFoundation) writes a script subtag
/// with a `-` separator while a region keeps `_` (so `sr_Latn` arrives as
/// `sr-Latn`), whereas the CLDR-derived tables use `_` throughout.
private func _lookupLocale(from locale: String) -> String {
    guard locale.utf8.contains(UInt8(ascii: "-")) else { return locale }
    let bytes = locale.utf8.map { $0 == UInt8(ascii: "-") ? UInt8(ascii: "_") : $0 }
    return String(decoding: bytes, as: UTF8.self)
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

/// The next locale to consult in the fallback walk: an explicit redirect (a
/// CLDR <parentLocales> override or a locale alias) if one exists, else the
/// truncation parent (strip the trailing subtag), else root — with root
/// terminating the walk.
///
/// Aliases ride the same path as parent-overrides: an aliased identifier (e.g.
/// zh_HK) has no slot data of its own, so its own-locale lookup always misses
/// and the redirect fires, sending the walk to the canonical target
/// (zh_HK → zh_Hant_HK → zh_Hant). Chained aliases (sr_CS → sr_RS → sr_Cyrl_RS)
/// resolve one hop per step.
package func _listFormatParent(of locale: String) -> String? {
    if locale == "root" { return nil }
    if let redirect = _redirectLookup(locale) { return redirect }
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
    locale.makeContiguousUTF8()
    let target = locale.utf8Span.span
    switch (type, width) {
    case (.and, .wide):   return _searchLocaleTable(target, count: _ListFormatData.slotAndWide.count, { _ListFormatData.slotAndWide[$0] },     key: { $0.locale }, value: { $0.row })
    case (.and, .short):  return _searchLocaleTable(target, count: _ListFormatData.slotAndShort.count, { _ListFormatData.slotAndShort[$0] },   key: { $0.locale }, value: { $0.row })
    case (.and, .narrow): return _searchLocaleTable(target, count: _ListFormatData.slotAndNarrow.count, { _ListFormatData.slotAndNarrow[$0] }, key: { $0.locale }, value: { $0.row })
    case (.or, .wide):    return _searchLocaleTable(target, count: _ListFormatData.slotOrWide.count, { _ListFormatData.slotOrWide[$0] },       key: { $0.locale }, value: { $0.row })
    case (.or, .short):   return _searchLocaleTable(target, count: _ListFormatData.slotOrShort.count, { _ListFormatData.slotOrShort[$0] },     key: { $0.locale }, value: { $0.row })
    case (.or, .narrow):  return _searchLocaleTable(target, count: _ListFormatData.slotOrNarrow.count, { _ListFormatData.slotOrNarrow[$0] },   key: { $0.locale }, value: { $0.row })
    }
}

/// Look up a locale's explicit redirect (a CLDR parent-override or a locale
/// alias) in the redirect map. Returns the target locale, or nil if there's no
/// entry for `locale`.
private func _redirectLookup(_ locale: String) -> String? {
    var locale = locale
    locale.makeContiguousUTF8()
    guard let targetIndex = _searchLocaleTable(locale.utf8Span.span, count: _ListFormatData.redirects.count, { _ListFormatData.redirects[$0] }, key: { $0.from }, value: { $0.to }) else { return nil }
    return _locale(at: targetIndex)
}

/// Binary search a sorted table of locale-keyed entries, shared by the slot and
/// parent-map lookups. `key` extracts the entry's index into `_ListFormatData.locales`
/// (the value compared against `target`); `value` maps a matched entry to the
/// return value. Comparison is byte-wise on the pooled UTF-8: locale identifiers
/// are pure ASCII, so byte order matches Swift's String comparison without
/// per-step allocation. Takes the table as a subscript closure because passing
/// a static `InlineArray`'s `.span` to a call that isn't inlined copies the
/// whole table to the stack.
private func _searchLocaleTable<Entry>(
    _ target: Span<UInt8>,
    count: Int,
    _ table: (Int) -> Entry,
    key: (Entry) -> UInt16,
    value: (Entry) -> UInt16
) -> UInt16? {
    var lo = 0
    var hi = count - 1
    while lo <= hi {
        let mid = (lo &+ hi) / 2
        let entry = table(mid)
        let cmp = _compareLocale(target, Int(key(entry)))
        if cmp == 0 { return value(entry) }
        if cmp > 0 { lo = mid &+ 1 } else { hi = mid &- 1 }
    }
    return nil
}

/// Lexicographic byte comparison of `target` with pooled locale `index`:
/// negative if `target` sorts first, zero if equal, positive if it sorts after.
/// Matches `strcmp` ordering on the ASCII locale identifiers. Reads the pool by
/// subscript, since passing a static `InlineArray`'s `.span` to a call that
/// isn't inlined copies the whole table to the stack.
private func _compareLocale(_ target: Span<UInt8>, _ index: Int) -> Int {
    let start = Int(_ListFormatData.localeOffsets[index])
    let count = Int(_ListFormatData.localeOffsets[index &+ 1]) &- start
    let n = min(target.count, count)
    var i = 0
    while i < n {
        let byte = _ListFormatData.localeBytes[start &+ i]
        if target[i] != byte { return target[i] < byte ? -1 : 1 }
        i &+= 1
    }
    if target.count == count { return 0 }
    return target.count < count ? -1 : 1
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
    _poolString(Int(index), offsets: { _ListFormatData.patternOffsets[$0] }, bytes: { _ListFormatData.patternBytes[$0] })
}

private func _locale(at index: UInt16) -> String {
    _poolString(Int(index), offsets: { _ListFormatData.localeOffsets[$0] }, bytes: { _ListFormatData.localeBytes[$0] })
}

/// String `index` of a pool of UTF-8 bytes and offsets.
private func _poolString(_ index: Int, offsets: (Int) -> UInt16, bytes: (Int) -> UInt8) -> String {
    let start = Int(offsets(index))
    let end = Int(offsets(index &+ 1))
    var utf8: [UInt8] = []
    utf8.reserveCapacity(end &- start)
    for i in start ..< end {
        utf8.append(bytes(i))
    }
    return String(decoding: utf8, as: UTF8.self)
}

#endif // !FOUNDATION_LIST_FORMAT_ICU
