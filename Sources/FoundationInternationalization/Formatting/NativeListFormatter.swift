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

/// Pure-Swift list formatter, used in place of `ICUListFormatter` when the
/// `FOUNDATION_LIST_FORMAT_NATIVE` build flag is on.
///
/// Mirrors the algorithm from ICU4X's `list_formatter.rs` and the Apple-ICU
/// extensions for FSI/PDI bidi isolates and the Thai contextual joiner.
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
internal final class NativeListFormatter: @unchecked Sendable {

    struct Signature: Hashable {
        let localeIdentifier: String
        let listType: Int
        let width: Int
    }

    internal static let cache = FormatterCache<Signature, NativeListFormatter>()

    private let signature: Signature
    private let patterns: ListPatterns
    private let language: String
    private let listDirection: Locale.LanguageDirection

    private init(signature: Signature) {
        self.signature = signature
        self.patterns = _listPatterns(locale: signature.localeIdentifier,
                                      type: signature.listType,
                                      width: signature.width)
        self.language = Self.language(of: signature.localeIdentifier)
        self.listDirection = Locale.Language(identifier: signature.localeIdentifier).characterDirection
    }

    func format(strings: [String]) -> String {
        switch strings.count {
        case 0: return ""
        case 1: return wrapBidi(strings[0])
        case 2:
            let a = wrapBidi(strings[0]), b = wrapBidi(strings[1])
            return apply(patterns.pair, isPair: true, before: a, after: b)
        default:
            let wrapped = strings.map(wrapBidi)
            var result = apply(patterns.start, isPair: false, before: wrapped[0], after: wrapped[1])
            for i in 2..<(wrapped.count - 1) {
                result = apply(patterns.middle, isPair: false, before: result, after: wrapped[i])
            }
            return apply(patterns.end, isPair: false, before: result, after: wrapped[wrapped.count - 1])
        }
    }

    /// Apply a contextual rule (if any) to `pattern`, then interpolate.
    /// `before` substitutes for `{0}`; `after` for `{1}`.
    private func apply(_ pattern: String, isPair: Bool, before: String, after: String) -> String {
        var p = pattern
        if let cond = _listPatternCondition(language: language,
                                            type: signature.listType,
                                            defaultPattern: pattern) {
            p = _applyListPatternCondition(cond, pattern: pattern, isPair: isPair,
                                           before: before, after: after)
        }
        return interpolate(p, before, after)
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

    /// Wrap an item in FSI/PDI isolates when its dominant direction conflicts
    /// with the list's overall direction. Items with no strong-directional
    /// scalar (digits, punctuation only) inherit the list direction and are
    /// left alone — matches the `["1", "2"]` Hebrew case.
    private func wrapBidi(_ item: String) -> String {
        guard let itemDir = direction(of: item) else { return item }
        let conflict: Bool
        switch (listDirection, itemDir) {
        case (.leftToRight, .rightToLeft), (.rightToLeft, .leftToRight): conflict = true
        default: conflict = false
        }
        return conflict ? "\u{2068}\(item)\u{2069}" : item
    }

    /// First-strong-directional detection (UAX #9 P2-style). Strong-RTL is the
    /// `BuiltInUnicodeScalarSet(.strongRightToLeft)` bitmap; strong-LTR is
    /// approximated as "letter that isn't strong-RTL", which suffices for
    /// the list-formatting cases pinned by `TestBidi`.
    private func direction(of item: String) -> Locale.LanguageDirection? {
        for scalar in item.unicodeScalars {
            if scalar._isStrongRTL { return .rightToLeft }
            switch scalar.properties.generalCategory {
            case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter,
                 .modifierLetter, .otherLetter:
                return .leftToRight
            default:
                continue
            }
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
                                  listType: style.listType.rawValue,
                                  width: style.width.rawValue)
        return cache.formatter(for: signature) {
            NativeListFormatter(signature: signature)
        }
    }
}

#endif // FOUNDATION_LIST_FORMAT_NATIVE
