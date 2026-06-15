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

/// Swift list formatter, used in place of `ICUListFormatter` when the
/// `FOUNDATION_LIST_FORMAT_NATIVE` build flag is on.
///
/// Reimplements Apple-ICU's `i18n/listformatter.cpp`
/// (`ListFormatter::formatStringsToValue` and its `PatternHandler` family):
/// the CLDR "List Patterns" empty/single/pair/3+ composition, the contextual
/// rules (Spanish y→e / o→u and the Hebrew non-Hebrew prefix), and the Apple
/// extensions (`ThaiHandler`'s contextual joiner and FSI/PDI bidi isolate
/// wrapping, which isolates any item containing a character of the opposite
/// direction to the list, matching `ListFormatter::needsBidiIsolates`).
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
internal final class NativeListFormatter: @unchecked Sendable {

    struct Signature: Hashable {
        let localeIdentifier: String
        let listType: Int
        let width: Int
    }

    /// A list pattern of the form `<prefix>{0}<connector>{1}<suffix>` parsed
    /// once at formatter-construction time. The Thai fast path uses this to
    /// avoid re-scanning the pattern on every format call. Slices are
    /// materialized into concrete `String`s so format-time concatenation can
    /// take the fast byte-copy path rather than scalar-by-scalar append.
    internal struct ParsedPattern: Equatable {
        let prefix: String
        let connector: String
        let suffix: String
        let connectorStartsWithSpace: Bool
        let connectorEndsWithSpace: Bool
    }

    internal static let cache = FormatterCache<Signature, NativeListFormatter>()

    private let signature: Signature
    private let patterns: ListPatterns
    private let language: String
    private let listDirection: Locale.LanguageDirection
    /// Whether this formatter's locale + type combination triggers the Thai
    /// contextual joiner rule. Cached to avoid re-deciding per format call.
    private let isThaiAnd: Bool
    /// Cached condition decisions per slot so format calls don't re-classify
    /// the rule per call. `nil` means no contextual rule applies for this slot.
    private let startCondition: ListPatternCondition?
    private let middleCondition: ListPatternCondition?
    private let endCondition: ListPatternCondition?
    private let pairCondition: ListPatternCondition?
    private let startParsed: ParsedPattern?
    private let middleParsed: ParsedPattern?
    private let endParsed: ParsedPattern?
    private let pairParsed: ParsedPattern?
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
        self.isThaiAnd = (language == "th") && (signature.listType == 0)
        let type = signature.listType
        self.startCondition = _listPatternCondition(language: language, type: type, defaultPattern: patterns.start)
        self.middleCondition = _listPatternCondition(language: language, type: type, defaultPattern: patterns.middle)
        self.endCondition = _listPatternCondition(language: language, type: type, defaultPattern: patterns.end)
        self.pairCondition = _listPatternCondition(language: language, type: type, defaultPattern: patterns.pair)
        let startParsed = Self.parse(patterns.start)
        let middleParsed = Self.parse(patterns.middle)
        let endParsed = Self.parse(patterns.end)
        let pairParsed = Self.parse(patterns.pair)
        self.startParsed = startParsed
        self.middleParsed = middleParsed
        self.endParsed = endParsed
        self.pairParsed = pairParsed
        if let s = startParsed, let m = middleParsed, let e = endParsed,
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
            if isThaiAnd, let parsed = pairParsed {
                return applyThai(parsed: parsed, isPair: true, before: a, after: b)
            }
            if pairCondition == nil, let parsed = pairParsed {
                return interpolate(layout: parsed, a, b)
            }
            return apply(patterns.pair, condition: pairCondition, parsed: pairParsed,
                         isPair: true, before: a, after: b)
        default:
            // Fast path: simple patterns + no contextual rule. Build the
            // result in one buffer in a single pass (O(N) total work) rather
            // than producing N intermediate strings. `wrapBidi` is inlined
            // so we don't allocate an intermediate `[String]` for the wrapped
            // items.
            if canBuildLinearly,
               startCondition == nil, middleCondition == nil, endCondition == nil,
               let startP = startParsed, let middleP = middleParsed, let endP = endParsed {
                return buildLinear(items: strings, start: startP, middle: middleP, end: endP)
            }
            let wrapped = strings.map(wrapBidi)
            // Thai or contextual or non-simple-pattern locale: per-call apply.
            if isThaiAnd,
               let startP = startParsed,
               let middleP = middleParsed,
               let endP = endParsed {
                var result = applyThai(parsed: startP, isPair: false,
                                       before: wrapped[0], after: wrapped[1])
                for i in 2..<(wrapped.count - 1) {
                    result = applyThai(parsed: middleP, isPair: false,
                                       before: result, after: wrapped[i])
                }
                return applyThai(parsed: endP, isPair: false,
                                 before: result, after: wrapped[wrapped.count - 1])
            }
            var result = apply(patterns.start, condition: startCondition, parsed: startParsed,
                               isPair: false, before: wrapped[0], after: wrapped[1])
            for i in 2..<(wrapped.count - 1) {
                result = apply(patterns.middle, condition: middleCondition, parsed: middleParsed,
                               isPair: false, before: result, after: wrapped[i])
            }
            return apply(patterns.end, condition: endCondition, parsed: endParsed,
                         isPair: false, before: result, after: wrapped[wrapped.count - 1])
        }
    }

    /// Linear single-buffer build for 3+ item lists with simple patterns and no
    /// contextual rule. Concatenates items and connectors directly:
    ///
    ///     items[0] <start.connector> items[1] <middle.connector> items[2]
    ///         <middle.connector> ... <middle.connector> items[N-2]
    ///         <end.connector> items[N-1]
    ///
    /// Pre-classifies bidi conflicts in a sizing pass (using a stack-allocated
    /// `Bool` buffer via `withUnsafeTemporaryAllocation`), then writes UTF-8
    /// bytes directly into a `String(unsafeUninitializedCapacity:)` buffer
    /// wrapped in an `OutputSpan`. Skips the per-`+=` UTF-8 validity checks
    /// and copy-on-write uniqueness checks `String +=` paid on every append.
    private func buildLinear(items: [String],
                             start: ParsedPattern,
                             middle: ParsedPattern,
                             end: ParsedPattern) -> String {
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

    /// Apply a contextual rule (if any) to `pattern`, then interpolate.
    /// `before` substitutes for `{0}`; `after` for `{1}`. Top-level fast paths
    /// in `format(strings:)` cover the no-condition case for simple patterns
    /// and the Thai case; this path handles Spanish/Hebrew, plus the
    /// no-condition case for non-simple patterns (those with a non-empty
    /// prefix/suffix), plus a fallback for malformed data.
    private func apply(_ pattern: String, condition: ListPatternCondition?,
                       parsed: ParsedPattern?, isPair: Bool,
                       before: String, after: String) -> String {
        guard let cond = condition else {
            if let parsed = parsed { return interpolate(layout: parsed, before, after) }
            return interpolate(pattern, before, after)
        }
        switch cond {
        case .spanishYToE:
            if _spanishYToEFires(on: after) {
                return concat3(before, " e ", after)
            }
            if let parsed = parsed { return interpolate(layout: parsed, before, after) }
            return interpolate(pattern, before, after)
        case .spanishOToU:
            if _spanishOToUFires(on: after) {
                return concat3(before, " u ", after)
            }
            if let parsed = parsed { return interpolate(layout: parsed, before, after) }
            return interpolate(pattern, before, after)
        case .hebrewNonHebrewPrefix:
            if _hebrewVavDashFires(on: after) {
                return concat3(before, " \u{05D5}-", after)
            }
            if let parsed = parsed { return interpolate(layout: parsed, before, after) }
            return interpolate(pattern, before, after)
        case .thaiContextual:
            // Reached only when the parsed-pattern fast path was bypassed
            // (malformed pattern); fall back to interpolating as written.
            return interpolate(pattern, before, after)
        }
    }

    /// Concatenate three strings into a single freshly-allocated `String`.
    /// Used by the Spanish/Hebrew contextual rules when they fire and the
    /// rewritten pattern is a known `{0}<connector>{1}` constant — emitting
    /// the result directly is cheaper than going through `interpolate`.
    private func concat3(_ a: String, _ b: String, _ c: String) -> String {
        let total = a.utf8.count + b.utf8.count + c.utf8.count
        return String(unsafeUninitializedCapacity: total) { buffer in
            var output = OutputSpan(buffer: buffer, initializedCount: 0)
            output.append(copying: a.utf8Span.span)
            output.append(copying: b.utf8Span.span)
            output.append(copying: c.utf8Span.span)
            return output.finalize(for: buffer)
        }
    }

    /// Fast interpolation using the cached parsed layout. Skips the per-call
    /// placeholder scan that `interpolate(_:_:_:)` does.
    private func interpolate(layout p: ParsedPattern, _ s0: String, _ s1: String) -> String {
        let total = p.prefix.utf8.count + s0.utf8.count + p.connector.utf8.count
            + s1.utf8.count + p.suffix.utf8.count
        return String(unsafeUninitializedCapacity: total) { buffer in
            var output = OutputSpan(buffer: buffer, initializedCount: 0)
            output.append(copying: p.prefix.utf8Span.span)
            output.append(copying: s0.utf8Span.span)
            output.append(copying: p.connector.utf8Span.span)
            output.append(copying: s1.utf8Span.span)
            output.append(copying: p.suffix.utf8Span.span)
            return output.finalize(for: buffer)
        }
    }

    /// Single-pass Thai formatter: emit the final string directly using the
    /// pre-parsed pattern decomposition, with any contextually-required spaces
    /// adjacent to the connector inserted.
    private func applyThai(parsed: ParsedPattern, isPair: Bool,
                           before: String, after: String) -> String {
        let spaceBefore = isPair && _thaiNeedsSpace(adjacentScalar: before.unicodeScalars.last)
        let spaceAfter = _thaiNeedsSpace(adjacentScalar: after.unicodeScalars.first)
        let needsLeading = spaceBefore && !parsed.connectorStartsWithSpace
        let needsTrailing = spaceAfter && !parsed.connectorEndsWithSpace
        let extra = (needsLeading ? 1 : 0) + (needsTrailing ? 1 : 0)
        let total = parsed.prefix.utf8.count + before.utf8.count + parsed.connector.utf8.count
            + after.utf8.count + parsed.suffix.utf8.count + extra
        return String(unsafeUninitializedCapacity: total) { buffer in
            var output = OutputSpan(buffer: buffer, initializedCount: 0)
            output.append(copying: parsed.prefix.utf8Span.span)
            output.append(copying: before.utf8Span.span)
            if needsLeading {
                output.append(0x20) // ASCII space
            }
            output.append(copying: parsed.connector.utf8Span.span)
            if needsTrailing {
                output.append(0x20)
            }
            output.append(copying: after.utf8Span.span)
            output.append(copying: parsed.suffix.utf8Span.span)
            return output.finalize(for: buffer)
        }
    }

    /// Parse a `<prefix>{0}<connector>{1}<suffix>` pattern. Returns `nil` when
    /// the shape doesn't match — a defensive fallback for malformed data.
    internal static func parse(_ pattern: String) -> ParsedPattern? {
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
        return ParsedPattern(
            prefix: String(scalars[..<zeroOpen]),
            connector: connector,
            suffix: String(scalars[suffixStart...]),
            connectorStartsWithSpace: connector.unicodeScalars.first == " ",
            connectorEndsWithSpace: connector.unicodeScalars.last == " "
        )
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

    private static func language(of locale: String) -> String {
        if let u = locale.firstIndex(of: "_") { return String(locale[..<u]) }
        if let u = locale.firstIndex(of: "-") { return String(locale[..<u]) }
        return locale
    }

    internal static func formatter<Style, Base>(for style: ListFormatStyle<Style, Base>) -> NativeListFormatter {
        let signature = Signature(localeIdentifier: style.locale.identifier,
                                  listType: style.listType.rawValue,
                                  width: style.width.rawValue)
        return cache.formatter(for: signature) {
            NativeListFormatter(signature: signature)
        }
    }
}

#endif // FOUNDATION_LIST_FORMAT_NATIVE
