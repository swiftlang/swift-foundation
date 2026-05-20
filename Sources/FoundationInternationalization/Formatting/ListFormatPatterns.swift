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

#if FOUNDATION_LIST_FORMAT_NATIVE

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

// MARK: - Types

/// Resolved list-formatting patterns for one (type, width) slot, parameterized by locale.
///
/// CLDR models list formatting as four slots — `start`, `middle`, `end`, and
/// `2` (renamed `pair` here) — interpolated into via the `{0}` and `{1}`
/// placeholders. See `update-list-format-data-impl.swift` for how this struct
/// is populated from CLDR XML.
internal struct ListPatterns: Hashable, Sendable {
    let start: String
    let middle: String
    let end: String
    let pair: String
}

/// A locale-specific contextual rule that may modify the `end`/`pair` pattern
/// based on the surrounding text.
///
/// These rules live in CLDR/ICU code (not data): CLDR's list patterns don't
/// carry the context-dependent variants. The generator computes them from the
/// language at format time so the data tables stay deduped against the actual
/// patterns. The condition implementations here match Apple-ICU's
/// `i18n/listformatter.cpp`.
internal enum ListPatternCondition: Sendable, Hashable {
    /// Spanish: replace " y " with " e " before words starting with the i-sound.
    case spanishYToE
    /// Spanish: replace " o " with " u " before words starting with the o-sound.
    case spanishOToU
    /// Hebrew: insert a dash after ו before non-Hebrew text.
    case hebrewNonHebrewPrefix
    /// Thai (Apple-ICU only): insert spaces around the
    /// connector when it abuts non-Thai text.
    case thaiContextual
}

// MARK: - Locale lookup

/// Resolve `(locale, type, width)` to a `ListPatterns` row by walking the
/// parent chain across the generated sparse indexes. Mirrors the lookup
/// algorithm baked into the generator's correctness check.
///
/// `type` and `width` are raw values from `ListFormatStyle.ListType` and
/// `ListFormatStyle.Width`. `type == 2` (.unit) isn't reachable from the
/// public API today, but the data and lookup support it.
internal func _listPatterns(locale: String, type: Int, width: Int) -> ListPatterns {
    let (rows, index) = _slotTables(type: type, width: width)
    var current = locale
    while true {
        if let i = index[current] {
            return rows[Int(i)]
        }
        guard let parent = _listFormatParent(of: current) else {
            // root must always be in the table; reaching here means the
            // generator emitted incomplete data.
            return rows[Int(index["root"] ?? 0)]
        }
        current = parent
    }
}

private func _slotTables(type: Int, width: Int) -> ([ListPatterns], [String: UInt8]) {
    switch (type, width) {
    case (0, 0): return (_listPatternsAndWide,    _listPatternsAndWideIndex)
    case (0, 1): return (_listPatternsAndShort,   _listPatternsAndShortIndex)
    case (0, 2): return (_listPatternsAndNarrow,  _listPatternsAndNarrowIndex)
    case (1, 0): return (_listPatternsOrWide,     _listPatternsOrWideIndex)
    case (1, 1): return (_listPatternsOrShort,    _listPatternsOrShortIndex)
    case (1, 2): return (_listPatternsOrNarrow,   _listPatternsOrNarrowIndex)
    case (2, 0): return (_listPatternsUnitWide,   _listPatternsUnitWideIndex)
    case (2, 1): return (_listPatternsUnitShort,  _listPatternsUnitShortIndex)
    case (2, 2): return (_listPatternsUnitNarrow, _listPatternsUnitNarrowIndex)
    default:     return (_listPatternsAndWide,    _listPatternsAndWideIndex)
    }
}

/// Mirror of the parent walk in `update-list-format-data-impl.swift`. Must
/// match exactly — the generator self-checks against this algorithm.
internal func _listFormatParent(of locale: String) -> String? {
    if locale == "root" { return nil }
    if let p = _listFormatParentLocales[locale] { return p }
    if let underscore = locale.lastIndex(of: "_") {
        return String(locale[..<underscore])
    }
    return "root"
}

// MARK: - Contextual conditions

/// Returns the contextual rule that applies to a given `(language, type,
/// default-pattern)`, or `nil` if no rule applies. Same logic the generator
/// would have used had we stored the tag in the data; computing at format
/// time keeps the data deduped against patterns alone.
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

/// Apply a contextual rule to a pattern, given the text on either side.
/// `before` is the accumulated prefix (or item 0 for the pair pattern);
/// `after` is the new item being appended (or item 1 for the pair pattern).
/// Spanish/Hebrew rules consult only `after`; Thai consults both.
internal func _applyListPatternCondition(
    _ condition: ListPatternCondition,
    pattern: String,
    isPair: Bool,
    before: String,
    after: String
) -> String {
    switch condition {
    case .spanishYToE:
        // "{0} y {1}" → "{0} e {1}" before i-sound.
        return _spanishYToEFires(on: after) ? "{0} e {1}" : pattern
    case .spanishOToU:
        // "{0} o {1}" → "{0} u {1}" before o-sound.
        return _spanishOToUFires(on: after) ? "{0} u {1}" : pattern
    case .hebrewNonHebrewPrefix:
        // "{0} ו{1}" → "{0} ו-{1}" when {1} starts with non-Hebrew text.
        return _hebrewVavDashFires(on: after) ? "{0} \u{05D5}-{1}" : pattern
    case .thaiContextual:
        return _applyThaiContextual(pattern: pattern, isPair: isPair, before: before, after: after)
    }
}

// MARK: - Predicate implementations

// Mirrors `shouldChangeToE` in Apple-ICU's listformatter.cpp.
// Fires for items starting with "i", "I", "hi"/"hI"/"Hi"/"HI" — but NOT
// "hia"/"hie" (case-insensitive).
private func _spanishYToEFires(on text: String) -> Bool {
    var iter = text.unicodeScalars.makeIterator()
    guard let c0 = iter.next() else { return false }
    if c0 == "i" || c0 == "I" { return true }
    if c0 != "h" && c0 != "H" { return false }
    guard let c1 = iter.next() else { return false }
    if c1 != "i" && c1 != "I" { return false }
    guard let c2 = iter.next() else { return true }   // exactly "hi"
    return c2 != "a" && c2 != "A" && c2 != "e" && c2 != "E"
}

// Mirrors `shouldChangeToU` in Apple-ICU's listformatter.cpp.
// Fires for items starting with "o"/"O"/"8", or "ho"/"hO"/"Ho"/"HO", or
// the literal "11" (alone or followed by a space — NOT "11.000" / "11000").
private func _spanishOToUFires(on text: String) -> Bool {
    var iter = text.unicodeScalars.makeIterator()
    guard let c0 = iter.next() else { return false }
    if c0 == "o" || c0 == "O" || c0 == "8" { return true }
    if c0 == "h" || c0 == "H" {
        if let c1 = iter.next(), c1 == "o" || c1 == "O" { return true }
        return false
    }
    if c0 == "1" {
        guard let c1 = iter.next(), c1 == "1" else { return false }
        guard let c2 = iter.next() else { return true }   // exactly "11"
        return c2 == " "
    }
    return false
}

// Mirrors `shouldChangeToVavDash` in Apple-ICU's listformatter.cpp:
// fires when the first scalar's script is not Hebrew. Swift stdlib doesn't
// expose Unicode.Scalar.Properties.script, so we test against the Hebrew
// Unicode blocks directly: U+0590..U+05FF (Hebrew) and U+FB1D..U+FB4F
// (Hebrew Presentation Forms).
private func _hebrewVavDashFires(on text: String) -> Bool {
    guard let scalar = text.unicodeScalars.first else { return false }
    let v = scalar.value
    let isHebrewBlock = (0x0590...0x05FF).contains(v) || (0xFB1D...0xFB4F).contains(v)
    return !isHebrewBlock
}

// Mirrors Apple-ICU's `ThaiHandler` (listformatter.cpp). For the pair pattern
// (twoPattern), checks both the trailing scalar of `before` and the leading
// scalar of `after`; for the end pattern, checks only `after`. Inserts a
// space adjacent to the connector when it abuts non-Thai text.
private func _applyThaiContextual(pattern: String, isPair: Bool, before: String, after: String) -> String {
    let spaceBefore = isPair && _thaiNeedsSpace(adjacentScalar: before.unicodeScalars.last)
    let spaceAfter = _thaiNeedsSpace(adjacentScalar: after.unicodeScalars.first)
    if !spaceBefore && !spaceAfter { return pattern }

    // Find the connector text (everything between `{0}` and `{1}`) and pad it
    // with optional spaces. CLDR's Thai patterns are the only inputs we'll see
    // here; they reliably contain exactly one `{0}` followed by exactly one
    // `{1}` with literal text between them.
    let scalars = Array(pattern.unicodeScalars)
    guard let zeroEnd = _indexAfterPlaceholder("0", in: scalars),
          let oneStart = _indexBeforePlaceholder("1", in: scalars, from: zeroEnd),
          zeroEnd <= oneStart else {
        return pattern
    }
    let connectorScalars = scalars[zeroEnd..<oneStart]
    let connector = String(String.UnicodeScalarView(connectorScalars))
    var rebuilt = "{0}"
    if spaceBefore && !connector.hasPrefix(" ") { rebuilt += " " }
    rebuilt += connector
    if spaceAfter && !connector.hasSuffix(" ") { rebuilt += " " }
    rebuilt += "{1}"
    return rebuilt
}

// Index of the scalar one past `{<digit>}`. Returns nil if not found.
private func _indexAfterPlaceholder(_ digit: Unicode.Scalar, in scalars: [Unicode.Scalar]) -> Int? {
    var i = 0
    while i + 2 < scalars.count {
        if scalars[i] == "{" && scalars[i+1] == digit && scalars[i+2] == "}" {
            return i + 3
        }
        i += 1
    }
    return nil
}

// Index of `{` in `{<digit>}`, scanning from `start`.
private func _indexBeforePlaceholder(_ digit: Unicode.Scalar, in scalars: [Unicode.Scalar], from start: Int) -> Int? {
    var i = start
    while i + 2 < scalars.count {
        if scalars[i] == "{" && scalars[i+1] == digit && scalars[i+2] == "}" {
            return i
        }
        i += 1
    }
    return nil
}

// True if the scalar exists and isn't in the Thai block (U+0E00..U+0E7F).
// `nil` means "no adjacent text" — no contextual change needed.
private func _thaiNeedsSpace(adjacentScalar: Unicode.Scalar?) -> Bool {
    guard let s = adjacentScalar else { return false }
    return !(0x0E00...0x0E7F).contains(s.value)
}

#endif // FOUNDATION_LIST_FORMAT_NATIVE
