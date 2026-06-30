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

internal import Synchronization

extension OutputSpan where Element == UInt8 {
    /// Append `source`'s bytes onto this output span. Stand-in for a stdlib
    /// `append(copying:)`-style API; previewed as `_append(copying:)` in
    /// swift-collections' `ContainersPreview` module. Remove when the stdlib
    /// gains an equivalent.
    @inline(__always)
    mutating func append(copying source: Span<UInt8>) {
        guard !source.isEmpty else { return }
        self.withUnsafeMutableBufferPointer { dst, dstCount in
            source.withUnsafeBufferPointer { src in
                let dstEnd = dstCount + src.count
                precondition(dstEnd <= dst.count, "OutputSpan capacity overflow")
                _ = dst[dstCount..<dstEnd].initialize(fromContentsOf: src)
                dstCount = dstEnd
            }
        }
    }
}

/// A compiled `<prefix>{0}<connector>{1}<suffix>` pattern — a minimal Swift
/// analogue of ICU's `SimpleFormatter`. The positional placeholders are parsed
/// once (`init?`), then formatting appends into a caller-supplied buffer (ICU's
/// `appendTo` model) so a whole list can be built in a single allocation.
///
/// Internal for now, but shaped to graduate into a shared formatter utility:
/// `Duration+UnitsFormatStyle` open-codes the same `{0}`/`{1}` substitution, and
/// other CLDR-driven formatters will want it too.
internal struct SimpleFormatter: Equatable {
    let prefix: String
    let connector: String
    let suffix: String
    let connectorStartsWithSpace: Bool
    let connectorEndsWithSpace: Bool

    /// Parse `<prefix>{0}<connector>{1}<suffix>`. Returns `nil` when the shape
    /// doesn't match — a defensive guard against malformed data. CLDR list
    /// patterns use exactly the two placeholders `{0}` and `{1}`.
    init?(_ pattern: String) {
        let scalars = pattern.unicodeScalars
        guard let zeroOpen = scalars.firstIndex(of: "{") else { return nil }
        let zeroDigit = scalars.index(after: zeroOpen)
        guard zeroDigit < scalars.endIndex, scalars[zeroDigit] == "0" else { return nil }
        let zeroClose = scalars.index(after: zeroDigit)
        guard zeroClose < scalars.endIndex, scalars[zeroClose] == "}" else { return nil }
        let connectorStart = scalars.index(after: zeroClose)
        guard let oneOpen = scalars[connectorStart...].firstIndex(of: "{") else { return nil }
        let oneDigit = scalars.index(after: oneOpen)
        guard oneDigit < scalars.endIndex, scalars[oneDigit] == "1" else { return nil }
        let oneClose = scalars.index(after: oneDigit)
        guard oneClose < scalars.endIndex, scalars[oneClose] == "}" else { return nil }
        let suffixStart = scalars.index(after: oneClose)

        let connector = String(scalars[connectorStart..<oneOpen])
        self.prefix = String(scalars[..<zeroOpen])
        self.connector = connector
        self.suffix = String(scalars[suffixStart...])
        self.connectorStartsWithSpace = connector.unicodeScalars.first == " "
        self.connectorEndsWithSpace = connector.unicodeScalars.last == " "
    }

    /// UTF-8 byte count of formatting two arguments of the given byte lengths.
    func utf8Count(_ arg0Bytes: Int, _ arg1Bytes: Int) -> Int {
        prefix.utf8.count + arg0Bytes + connector.utf8.count + arg1Bytes + suffix.utf8.count
    }

    /// Append `prefix + s0 + connector + s1 + suffix` into `output`. The caller
    /// is responsible for having reserved enough capacity (see `utf8Count`).
    @inline(__always)
    func format(_ s0: borrowing UTF8Span, _ s1: borrowing UTF8Span,
                into output: inout OutputSpan<UInt8>) {
        output.append(copying: prefix.utf8Span.span)
        output.append(copying: s0.span)
        output.append(copying: connector.utf8Span.span)
        output.append(copying: s1.span)
        output.append(copying: suffix.utf8Span.span)
    }

    /// Format two arguments into a freshly allocated `String`.
    func format(_ s0: String, _ s1: String) -> String {
        let total = utf8Count(s0.utf8.count, s1.utf8.count)
        return String(unsafeUninitializedCapacity: total) { buffer in
            var output = OutputSpan(buffer: buffer, initializedCount: 0)
            format(s0.utf8Span, s1.utf8Span, into: &output)
            return output.finalize(for: buffer)
        }
    }
}

/// Swift list formatter, used in place of `ICUListFormatter` unless the
/// `FOUNDATION_LIST_FORMAT_ICU` build flag is set.
///
/// Reimplements Apple-ICU's `i18n/listformatter.cpp`
/// (`ListFormatter::formatStringsToValue` and its `PatternHandler` family):
/// the CLDR "List Patterns" empty/single/pair/3+ composition, the contextual
/// rules (Spanish y→e / o→u and the Hebrew non-Hebrew prefix), and the Apple
/// extensions (`ThaiHandler`'s contextual joiner and FSI/PDI bidi isolate
/// wrapping, which isolates any item containing a character of the opposite
/// direction to the list, matching `ListFormatter::needsBidiIsolates`).
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
internal final class NativeListFormatter: Sendable {

    struct Signature: Hashable {
        let localeIdentifier: String
        let listType: ListFormatType
        let width: ListFormatWidth
    }

    private static let cache = Mutex<[Signature: NativeListFormatter]>([:])

    private let signature: Signature
    private let patterns: ListPatterns
    private let language: String
    private let listDirection: Locale.LanguageDirection
    /// Whether this formatter's locale + type combination triggers the Thai
    /// contextual joiner rule. Cached to avoid re-deciding per format call.
    private let isThaiAnd: Bool
    /// The contextual substitution rule for this locale, if any (Spanish y→e /
    /// o→u, Hebrew non-Hebrew prefix). `alternativeCondition` tests the item
    /// following the connector; when it fires, `alternativeParsed` is used in
    /// place of the normal end/pair pattern. These rules only affect the end and
    /// pair patterns, which are identical in the affected languages, so a single
    /// condition + pattern covers both positions. `nil` for most locales. Thai
    /// is excluded — its joiner is dynamic spacing, not a static substitution
    /// (see `applyThai`).
    private let alternativeCondition: (@Sendable (String) -> Bool)?
    private let alternativeFormatter: SimpleFormatter?
    private let startFormatter: SimpleFormatter?
    private let middleFormatter: SimpleFormatter?
    private let endFormatter: SimpleFormatter?
    private let pairFormatter: SimpleFormatter?
    /// True when the start, middle, and end patterns parsed cleanly and have
    /// empty prefix/suffix (the `{0}<connector>{1}` shape). When also paired
    /// with no contextual rule, the 3+ item path in `format(strings:)` can
    /// build the result in a single buffer in O(N) instead of producing N
    /// intermediate strings. The pair pattern is independent — its fast path
    /// is the layout-based interpolate, which works for any shape.
    private let canBuildLinearly: Bool

    private init(signature: Signature) {
        self.signature = signature
        let patterns = _listPatterns(locale: signature.localeIdentifier,
                                     type: signature.listType,
                                     width: signature.width)
        self.patterns = patterns
        let language = Self.language(of: signature.localeIdentifier)
        self.language = language
        self.listDirection = Locale.Language(identifier: signature.localeIdentifier).characterDirection
        self.isThaiAnd = (language == "th") && (signature.listType == .and)
        if let rule = Self.alternativeRule(language: language, type: signature.listType,
                                           endPattern: patterns.end) {
            self.alternativeCondition = rule.condition
            self.alternativeFormatter = SimpleFormatter(rule.pattern)
        } else {
            self.alternativeCondition = nil
            self.alternativeFormatter = nil
        }
        let startFormatter = SimpleFormatter(patterns.start)
        let middleFormatter = SimpleFormatter(patterns.middle)
        let endFormatter = SimpleFormatter(patterns.end)
        let pairFormatter = SimpleFormatter(patterns.pair)
        self.startFormatter = startFormatter
        self.middleFormatter = middleFormatter
        self.endFormatter = endFormatter
        self.pairFormatter = pairFormatter
        if let s = startFormatter, let m = middleFormatter, let e = endFormatter,
           s.prefix.isEmpty, s.suffix.isEmpty,
           m.prefix.isEmpty, m.suffix.isEmpty,
           e.prefix.isEmpty, e.suffix.isEmpty {
            self.canBuildLinearly = true
        } else {
            self.canBuildLinearly = false
        }
    }

    func format(strings: [String]) -> String {
        switch strings.count {
        case 0: return ""
        case 1: return wrapBidi(strings[0])
        case 2:
            let a = wrapBidi(strings[0]), b = wrapBidi(strings[1])
            if isThaiAnd, let f = pairFormatter {
                return applyThai(f, isPair: true, before: a, after: b)
            }
            // Spanish/Hebrew: if the contextual rule fires for the second item,
            // use the alternative pattern; otherwise the normal pair pattern.
            if let alt = firedAlternative(forNextItem: strings[1]) {
                return alt.format(a, b)
            }
            if let f = pairFormatter { return f.format(a, b) }
            return interpolate(patterns.pair, a, b)
        default:
            // Fast path: simple patterns, not Thai. Build the result in one
            // buffer in a single pass (O(N) total work) rather than producing N
            // intermediate strings. `wrapBidi` is inlined so we don't allocate an
            // intermediate `[String]` for the wrapped items. A contextual rule
            // (Spanish/Hebrew) only changes which connector the final join uses,
            // so it stays on this path.
            if canBuildLinearly, !isThaiAnd,
               let startF = startFormatter, let middleF = middleFormatter, let endF = endFormatter {
                let lastJoin = firedAlternative(forNextItem: strings[strings.count - 1]) ?? endF
                return buildLinear(items: strings, start: startF, middle: middleF, end: lastJoin)
            }
            let wrapped = strings.map(wrapBidi)
            if isThaiAnd,
               let startF = startFormatter,
               let middleF = middleFormatter,
               let endF = endFormatter {
                var result = applyThai(startF, isPair: false,
                                       before: wrapped[0], after: wrapped[1])
                for i in 2..<(wrapped.count - 1) {
                    result = applyThai(middleF, isPair: false,
                                       before: result, after: wrapped[i])
                }
                return applyThai(endF, isPair: false,
                                 before: result, after: wrapped[wrapped.count - 1])
            }
            // Fallback for non-simple patterns (non-empty prefix/suffix — not
            // present in real CLDR data). Start and middle joins never carry a
            // contextual rule, so only the end join consults the alternative.
            var result = interpolate(startFormatter, patterns.start, wrapped[0], wrapped[1])
            for i in 2..<(wrapped.count - 1) {
                result = interpolate(middleFormatter, patterns.middle, result, wrapped[i])
            }
            let last = wrapped.count - 1
            if let alt = firedAlternative(forNextItem: strings[last]) {
                return alt.format(result, wrapped[last])
            }
            return interpolate(endFormatter, patterns.end, result, wrapped[last])
        }
    }

    /// The formatter for the end/pair join when this formatter's contextual
    /// substitution rule fires for `nextItem` (the item that follows the
    /// connector); `nil` if there's no rule or it doesn't fire.
    private func firedAlternative(forNextItem nextItem: String) -> SimpleFormatter? {
        guard let condition = alternativeCondition, let formatter = alternativeFormatter,
              condition(nextItem) else {
            return nil
        }
        return formatter
    }

    /// Linear single-buffer build for 3+ item lists with simple patterns.
    /// Concatenates items and connectors directly:
    ///
    ///     items[0] <start.connector> items[1] <middle.connector> items[2]
    ///         <middle.connector> ... <middle.connector> items[N-2]
    ///         <end.connector> items[N-1]
    ///
    /// `end` is the chosen final-join formatter — normally the end pattern, but
    /// the contextual alternative (Spanish/Hebrew) when its rule fires, since
    /// those patterns are also simple. Pre-classifies bidi conflicts in a sizing
    /// pass (using a stack-allocated `Bool` buffer via
    /// `withUnsafeTemporaryAllocation`), then writes UTF-8 bytes directly into a
    /// `String(unsafeUninitializedCapacity:)` buffer wrapped in an `OutputSpan`.
    /// Skips the per-`+=` UTF-8 validity checks and copy-on-write uniqueness
    /// checks `String +=` paid on every append.
    private func buildLinear(items: [String],
                             start: SimpleFormatter,
                             middle: SimpleFormatter,
                             end: SimpleFormatter) -> String {
        // TODO: use withTemporaryAllocation once swift-tools-version is 6.4 or higher
        return withUnsafeTemporaryAllocation(of: Bool.self, capacity: items.count) { conflicts in
            var total = 0
            for i in items.indices {
                let wrap = shouldWrapBidi(items[i])
                conflicts.initializeElement(at: i, to: wrap)
                total += items[i].utf8.count + (wrap ? 6 : 0)
            }
            total += start.connector.utf8.count
                + middle.connector.utf8.count * (items.count - 3)
                + end.connector.utf8.count

            return String(unsafeUninitializedCapacity: total) { buffer in
                var output = OutputSpan(buffer: buffer, initializedCount: 0)
                Self.writeItem(items[0].utf8Span, wrapped: conflicts[0], into: &output)
                output.append(copying: start.connector.utf8Span.span)
                Self.writeItem(items[1].utf8Span, wrapped: conflicts[1], into: &output)
                for i in 2..<(items.count - 1) {
                    output.append(copying: middle.connector.utf8Span.span)
                    Self.writeItem(items[i].utf8Span, wrapped: conflicts[i], into: &output)
                }
                output.append(copying: end.connector.utf8Span.span)
                let lastIdx = items.count - 1
                Self.writeItem(items[lastIdx].utf8Span, wrapped: conflicts[lastIdx], into: &output)
                return output.finalize(for: buffer)
            }
        }
    }

    /// Append `item` onto `output`, optionally bracketed by FSI (U+2068) and
    /// PDI (U+2069) for bidi isolation. The caller has already decided whether
    /// wrapping is needed.
    @inline(__always)
    private static func writeItem(_ item: borrowing UTF8Span, wrapped: Bool,
                                  into output: inout OutputSpan<UInt8>) {
        if wrapped {
            // U+2068 FIRST STRONG ISOLATE (FSI) = E2 81 A8
            output.append(0xE2)
            output.append(0x81)
            output.append(0xA8)
        }
        output.append(copying: item.span)
        if wrapped {
            // U+2069 POP DIRECTIONAL ISOLATE (PDI) = E2 81 A9
            output.append(0xE2)
            output.append(0x81)
            output.append(0xA9)
        }
    }

    /// Format with the compiled formatter, or fall back to scanning the raw
    /// pattern when parsing failed (malformed data).
    private func interpolate(_ formatter: SimpleFormatter?, _ pattern: String,
                             _ s0: String, _ s1: String) -> String {
        if let formatter {
            return formatter.format(s0, s1)
        }
        return interpolate(pattern, s0, s1)
    }

    /// Single-pass Thai formatter: emit the final string directly using the
    /// pre-parsed pattern decomposition, with any contextually-required spaces
    /// adjacent to the connector inserted.
    private func applyThai(_ formatter: SimpleFormatter, isPair: Bool,
                           before: String, after: String) -> String {
        let spaceBefore = isPair && _thaiNeedsSpace(adjacentScalar: before.unicodeScalars.last)
        let spaceAfter = _thaiNeedsSpace(adjacentScalar: after.unicodeScalars.first)
        let needsLeading = spaceBefore && !formatter.connectorStartsWithSpace
        let needsTrailing = spaceAfter && !formatter.connectorEndsWithSpace
        let extra = (needsLeading ? 1 : 0) + (needsTrailing ? 1 : 0)
        let total = formatter.prefix.utf8.count + before.utf8.count + formatter.connector.utf8.count
            + after.utf8.count + formatter.suffix.utf8.count + extra
        return String(unsafeUninitializedCapacity: total) { buffer in
            var output = OutputSpan(buffer: buffer, initializedCount: 0)
            output.append(copying: formatter.prefix.utf8Span.span)
            output.append(copying: before.utf8Span.span)
            if needsLeading {
                output.append(0x20) // ASCII space
            }
            output.append(copying: formatter.connector.utf8Span.span)
            if needsTrailing {
                output.append(0x20)
            }
            output.append(copying: after.utf8Span.span)
            output.append(copying: formatter.suffix.utf8Span.span)
            return output.finalize(for: buffer)
        }
    }

    /// Substitute `{0}` and `{1}` in `pattern`. Other braces are emitted
    /// literally (CLDR list patterns use exactly the two placeholders, but
    /// items themselves may contain literal braces — see the
    /// `literalBracePlaceholders` test).
    private func interpolate(_ pattern: String, _ s0: String, _ s1: String) -> String {
        var result = ""
        result.reserveCapacity(pattern.count + s0.count + s1.count)
        let scalars = pattern.unicodeScalars
        var i = scalars.startIndex
        while i < scalars.endIndex {
            let c = scalars[i]
            if c == "{" {
                let n1 = scalars.index(after: i)
                let n2 = n1 < scalars.endIndex ? scalars.index(after: n1) : scalars.endIndex
                if n2 < scalars.endIndex,
                   (scalars[n1] == "0" || scalars[n1] == "1"),
                   scalars[n2] == "}" {
                    result += (scalars[n1] == "0") ? s0 : s1
                    i = scalars.index(after: n2)
                    continue
                }
            }
            result.unicodeScalars.append(c)
            i = scalars.index(after: i)
        }
        return result
    }

    /// Wrap an item in FSI/PDI isolates when it contains directional content
    /// opposite the list's overall direction. Items with no strong-directional
    /// scalar (digits, punctuation only) inherit the list direction and are
    /// left alone — matches the `["1", "2"]` Hebrew case.
    private func wrapBidi(_ item: String) -> String {
        return shouldWrapBidi(item) ? "\u{2068}\(item)\u{2069}" : item
    }

    /// Whether `item` needs FSI/PDI isolation: true when it carries directional
    /// content that could disturb the surrounding list. Mirrors Apple-ICU's
    /// `ListFormatter::needsBidiIsolates`, including its asymmetry: in an LTR
    /// list an item is isolated if it contains any strong-RTL character (`R`/`AL`)
    /// or Arabic number (weak RTL, `AN`); in an RTL list, if it contains any
    /// strong-LTR character (`L`). Scanning the whole item (rather than only its
    /// leading direction) catches a same-leading item with a trailing opposite
    /// run, e.g. "David \u{05DB}\u{05D4}\u{05DF}" in an English list. Factored out so
    /// `buildLinear` can pre-classify items (sizing the output buffer exactly)
    /// without materializing the wrapped strings.
    @inline(__always)
    private func shouldWrapBidi(_ item: String) -> Bool {
        if listDirection == .rightToLeft {
            for scalar in item.unicodeScalars where isStrongLTR(scalar) {
                return true
            }
        } else {
            for scalar in item.unicodeScalars {
                // ASCII is never strong-RTL and never an Arabic number, so skip
                // the bitmap/range checks for it (the common case) — calling
                // `_isStrongRTL` per ASCII scalar would pay a full bitmap lookup.
                if scalar.value < 0x80 { continue }
                if scalar._isStrongRTL || isArabicNumber(scalar) { return true }
            }
        }
        return false
    }

    /// Whether `scalar` is a strong left-to-right character (UAX #9 class `L`),
    /// approximated as "a letter that isn't strong-RTL". Strong-RTL is the
    /// `BuiltInUnicodeScalarSet(.strongRightToLeft)` bitmap.
    @inline(__always)
    private func isStrongLTR(_ scalar: Unicode.Scalar) -> Bool {
        let v = scalar.value
        // ASCII fast path: ASCII letters are strong LTR; nothing else in the
        // ASCII range is strong-directional.
        if v < 0x80 {
            return (v >= 0x41 && v <= 0x5A) || (v >= 0x61 && v <= 0x7A)
        }
        if scalar._isStrongRTL { return false }
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter,
             .modifierLetter, .otherLetter:
            return true
        default:
            return false
        }
    }

    /// Whether `scalar` is Bidi_Class `AN` (Arabic Number) — Arabic-Indic digits
    /// plus the associated Arabic number signs and separators.
    ///
    /// These are isolated in an LTR list because, for neutral resolution (UAX #9
    /// rule N1), Arabic numbers "act as if they were R": an unwrapped `AN` item
    /// would pull the list's neutral separators (", ") to RTL and misorder them.
    /// European numbers (ASCII digits, and Persian "extended Arabic-Indic" digits
    /// U+06F0–06F9, which Unicode classes as `EN`) are deliberately *excluded*:
    /// rule W7 turns an `EN` preceded by strong-LTR context into `L`, so they
    /// behave as ordinary LTR and don't disturb the separators. This matches
    /// Apple-ICU's `needsBidiIsolates` (which triggers on `AN` but not `EN`).
    ///
    /// TODO: Replace these hand-coded ranges with a real Bidi_Class lookup once
    /// swift-foundation exposes one without depending on ICU. The bundled
    /// CFUniChar bitmaps cover the strong-RTL set used by `_isStrongRTL` but
    /// carry no Arabic-number / bidi-class data, so the ranges are maintained by
    /// hand for now (and don't cover the SMP `AN` ranges, e.g. Rumi numerals).
    @inline(__always)
    private func isArabicNumber(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x0600...0x0605,  // Arabic number signs
             0x0660...0x0669,  // Arabic-Indic digits
             0x066B...0x066C,  // Arabic decimal / thousands separators
             0x06DD,           // Arabic end of ayah
             0x0890...0x0891,  // Arabic pound / piastre marks
             0x08E2:           // Arabic disputed end of ayah
            return true
        default:
            return false
        }
    }

    /// The contextual substitution rule for a `(language, type)`, if any: a
    /// predicate on the item following the connector, plus the replacement
    /// pattern to use when it fires. Covers Spanish y→e / o→u and the Hebrew
    /// non-Hebrew prefix — all of which only affect the end/pair patterns
    /// (identical in these languages). Guarded on the end pattern so a locale
    /// that overrode it doesn't pick up the wrong rule. Thai is intentionally
    /// excluded: its joiner is a dynamic spacing rule, not a static pattern
    /// substitution (see `applyThai`).
    private static func alternativeRule(
        language: String, type: ListFormatType, endPattern: String
    ) -> (condition: @Sendable (String) -> Bool, pattern: String)? {
        if language == "es" {
            if type == .and, endPattern == "{0} y {1}" {
                return (_spanishYToEFires, "{0} e {1}")
            }
            if type == .or, endPattern == "{0} o {1}" {
                return (_spanishOToUFires, "{0} u {1}")
            }
        }
        if language == "he" || language == "iw", endPattern == "{0} \u{05D5}{1}" {
            return (_hebrewVavDashFires, "{0} \u{05D5}-{1}")
        }
        return nil
    }

    private static func language(of locale: String) -> String {
        if let u = locale.firstIndex(of: "_") { return String(locale[..<u]) }
        if let u = locale.firstIndex(of: "-") { return String(locale[..<u]) }
        return locale
    }

    internal static func formatter<Style, Base>(for style: ListFormatStyle<Style, Base>) -> NativeListFormatter {
        let signature = Signature(localeIdentifier: style.locale.identifier,
                                  listType: ListFormatType(style.listType),
                                  width: ListFormatWidth(style.width))
        if let existing = cache.withLock({ $0[signature] }) {
            return existing
        }
        // Build the formatter outside the lock so a slow construction doesn't
        // block lookups for other signatures.
        let formatter = NativeListFormatter(signature: signature)
        return cache.withLock {
            if let existing = $0[signature] {
                // Another thread beat us to it; use the existing instance.
                return existing
            }
            $0[signature] = formatter
            return formatter
        }
    }
}

// MARK: - Contextual-rule predicates
//
// The runtime checks for the locale-specific contextual rules. Spanish/Hebrew
// drive `alternativeRule`; Thai drives `applyThai`. Translated from Apple-ICU's
// `i18n/listformatter.cpp` (`shouldChangeToE`/`shouldChangeToU`, the Hebrew
// prefix handler, and `ThaiHandler`).

/// Whether the Spanish "y" → "e" change applies before `text` (the item that
/// follows the connector): true when it begins with an /i/ sound — an "i"/"hi"
/// not continuing into "hia"/"hie".
private func _spanishYToEFires(on text: String) -> Bool {
    var iter = text.unicodeScalars.makeIterator()
    guard let c0 = iter.next() else { return false }
    if c0 == "i" || c0 == "I" { return true }
    if c0 != "h" && c0 != "H" { return false }
    guard let c1 = iter.next() else { return false }
    if c1 != "i" && c1 != "I" { return false }
    guard let c2 = iter.next() else { return true }
    return c2 != "a" && c2 != "A" && c2 != "e" && c2 != "E"
}

/// Whether the Spanish "o" → "u" change applies before `text`: true when it
/// begins with an /o/ sound ("o", "ho", "8", or "11" as a standalone token).
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
        guard let c2 = iter.next() else { return true }
        return c2 == " "
    }
    return false
}

/// Whether the Hebrew non-Hebrew prefix change applies before `text`: true when
/// its first scalar is outside the Hebrew blocks (so the vav prefix gains a
/// hyphen).
private func _hebrewVavDashFires(on text: String) -> Bool {
    guard let scalar = text.unicodeScalars.first else { return false }
    let v = scalar.value
    let isHebrewBlock = (0x0590...0x05FF).contains(v) || (0xFB1D...0xFB4F).contains(v)
    return !isHebrewBlock
}

/// Whether the Thai contextual joiner needs a space next to the connector: true
/// when the adjacent scalar is non-Thai (outside the Thai block).
private func _thaiNeedsSpace(adjacentScalar: Unicode.Scalar?) -> Bool {
    guard let s = adjacentScalar else { return false }
    return !(0x0E00...0x0E7F).contains(s.value)
}

#endif // !FOUNDATION_LIST_FORMAT_ICU
