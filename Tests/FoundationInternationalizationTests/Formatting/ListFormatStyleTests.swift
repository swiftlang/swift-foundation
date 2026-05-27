// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing

#if canImport(FoundationInternationalization)
@testable import FoundationEssentials
@testable import FoundationInternationalization
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#endif

@Suite("ListFormatStyle")
private struct ListFormatStyleTests {
    @Test func orList() {
        var style: ListFormatStyle<StringStyle, [String]> = .list(type: .or, width: .standard)
        style.locale = Locale(identifier: "en_US")

        #expect(["one", "two"].formatted(style) == "one or two")
        #expect(["one", "two", "three"].formatted(style) == "one, two, or three")
    }

    @Test func andList() {
        var style: ListFormatStyle<StringStyle, [String]> = .list(type: .and, width: .standard)
        style.locale = Locale(identifier: "en_US")

        #expect(["one", "two"].formatted(style) == "one and two")
        #expect(["one", "two", "three"].formatted(style) == "one, two, and three")
    }

    @Test func narrowList() {
        var style: ListFormatStyle<StringStyle, [String]> = .list(type: .and, width: .narrow)
        style.locale = Locale(identifier: "en_US")

        #expect(["one", "two"].formatted(style) == "one, two")
        #expect(["one", "two", "three"].formatted(style) == "one, two, three")
    }

    @Test func shortList() {
        var style: ListFormatStyle<StringStyle, [String]> = .list(type: .and, width: .short)
        style.locale = Locale(identifier: "en_US")

        #expect(["one", "two"].formatted(style) == "one & two")
        #expect(["one", "two", "three"].formatted(style) == "one, two, & three")
    }

    @Test func leadingDotSyntax() {
        let _ = ["one", "two"].formatted(.list(type: .and))
        let _ = ["one", "two"].formatted()
        let _ = [1, 2].formatted(.list(memberStyle: .number, type: .or, width: .standard))
    }
    
    @Test func autoupdatingCurrentChangesFormatResults() async {
        await usingCurrentInternationalizationPreferences {
            let locale = Locale.autoupdatingCurrent
            let list = ["one", "two", "three", "four"]

            // Get a formatted result from es-ES
            var prefs = LocalePreferences()
            prefs.languages = ["es-ES"]
            prefs.locale = "es_ES"
            LocaleCache.cache.resetCurrent(to: prefs)
            let formattedSpanish = list.formatted(.list(type: .and).locale(locale))

            // Get a formatted result from en-US
            prefs.languages = ["en-US"]
            prefs.locale = "en_US"
            LocaleCache.cache.resetCurrent(to: prefs)
            let formattedEnglish = list.formatted(.list(type: .and).locale(locale))

            // Reset to current preferences before any possibility of failing this test
            LocaleCache.cache.reset()

            // No matter what 'current' was before this test was run, formattedSpanish and formattedEnglish should be different.
            #expect(formattedSpanish != formattedEnglish)
        }
    }

    // MARK: - Locale coverage
    //
    // Ported from ICU's icu4c/source/test/intltest/listformattertest.cpp.
    // Item names "Alice", "Bob", "Charlie", "Delta" and the expected outputs
    // are kept verbatim so failures correspond 1:1 to the upstream tests.

    private typealias Style = ListFormatStyle<StringStyle, [String]>

    private func style(_ locale: String, type: Style.ListType = .and, width: Style.Width = .standard) -> Style {
        var s: Style = .list(type: type, width: width)
        s.locale = Locale(identifier: locale)
        return s
    }

    /// Root locale: comma-only separators, no conjunction. Ported from ICU `TestRoot`.
    @Test func rootLocale() {
        let s = style("")
        #expect(["Alice"].formatted(s) == "Alice")
        #expect(["Alice", "Bob"].formatted(s) == "Alice, Bob")
        #expect(["Alice", "Bob", "Charlie"].formatted(s) == "Alice, Bob, Charlie")
        #expect(["Alice", "Bob", "Charlie", "Delta"].formatted(s) == "Alice, Bob, Charlie, Delta")
    }

    /// Ported from ICU `TestEnglish`.
    @Test func english() {
        let s = style("en")
        #expect(["Alice"].formatted(s) == "Alice")
        #expect(["Alice", "Bob"].formatted(s) == "Alice and Bob")
        #expect(["Alice", "Bob", "Charlie"].formatted(s) == "Alice, Bob, and Charlie")
        #expect(["Alice", "Bob", "Charlie", "Delta"].formatted(s) == "Alice, Bob, Charlie, and Delta")
    }

    /// Ported from ICU `TestEnglishUS`.
    @Test func englishUS() {
        let s = style("en_US")
        #expect(["Alice"].formatted(s) == "Alice")
        #expect(["Alice", "Bob"].formatted(s) == "Alice and Bob")
        #expect(["Alice", "Bob", "Charlie"].formatted(s) == "Alice, Bob, and Charlie")
        #expect(["Alice", "Bob", "Charlie", "Delta"].formatted(s) == "Alice, Bob, Charlie, and Delta")
    }

    /// en_GB drops the Oxford comma. Ported from ICU `TestEnglishGB`.
    @Test func englishGB() {
        let s = style("en_GB")
        #expect(["Alice"].formatted(s) == "Alice")
        #expect(["Alice", "Bob"].formatted(s) == "Alice and Bob")
        #expect(["Alice", "Bob", "Charlie"].formatted(s) == "Alice, Bob and Charlie")
        #expect(["Alice", "Bob", "Charlie", "Delta"].formatted(s) == "Alice, Bob, Charlie and Delta")
    }

    /// Ported from ICU `TestNynorsk`.
    @Test func nynorsk() {
        let s = style("nn")
        #expect(["Alice"].formatted(s) == "Alice")
        #expect(["Alice", "Bob"].formatted(s) == "Alice og Bob")
        #expect(["Alice", "Bob", "Charlie"].formatted(s) == "Alice, Bob og Charlie")
        #expect(["Alice", "Bob", "Charlie", "Delta"].formatted(s) == "Alice, Bob, Charlie og Delta")
    }

    /// Ported from ICU `TestChineseTradHK`. 及 = 及, 、 = 、
    @Test func chineseTraditionalHK() {
        let s = style("zh_Hant_HK")
        #expect(["Alice"].formatted(s) == "Alice")
        #expect(["Alice", "Bob"].formatted(s) == "Alice\u{53CA}Bob")
        #expect(["Alice", "Bob", "Charlie"].formatted(s) == "Alice\u{3001}Bob\u{53CA}Charlie")
        #expect(["Alice", "Bob", "Charlie", "Delta"].formatted(s) == "Alice\u{3001}Bob\u{3001}Charlie\u{53CA}Delta")
    }

    /// Ported from ICU `TestRussian`. и = и
    @Test func russian() {
        let s = style("ru")
        #expect(["Alice"].formatted(s) == "Alice")
        #expect(["Alice", "Bob"].formatted(s) == "Alice \u{0438} Bob")
        #expect(["Alice", "Bob", "Charlie"].formatted(s) == "Alice, Bob \u{0438} Charlie")
        #expect(["Alice", "Bob", "Charlie", "Delta"].formatted(s) == "Alice, Bob, Charlie \u{0438} Delta")
    }

    /// Ported from ICU `TestMalayalam`. Upstream CLDR/ICU now expect commas-only
    /// output, but `swift-foundation-icu` (used by the ICU bridge) still ships
    /// the older patterns കൂടാതെ / എന്നിവ. Conditioned on the build flag so
    /// both formatters pass; remove the `#else` branch when swift-foundation-icu
    /// picks up the newer CLDR snapshot.
    @Test func malayalam() {
        let s = style("ml")
        #expect(["Alice"].formatted(s) == "Alice")
        #if FOUNDATION_LIST_FORMAT_NATIVE
        #expect(["Alice", "Bob"].formatted(s) == "Alice, Bob")
        #expect(["Alice", "Bob", "Charlie"].formatted(s) == "Alice, Bob, Charlie")
        #expect(["Alice", "Bob", "Charlie", "Delta"].formatted(s) == "Alice, Bob, Charlie, Delta")
        #else
        #expect(["Alice", "Bob"].formatted(s) == "Alice \u{0D15}\u{0D42}\u{0D1F}\u{0D3E}\u{0D24}\u{0D46} Bob")
        #expect(["Alice", "Bob", "Charlie"].formatted(s) == "Alice, Bob, Charlie \u{0D0E}\u{0D28}\u{0D4D}\u{0D28}\u{0D3F}\u{0D35}")
        #expect(["Alice", "Bob", "Charlie", "Delta"].formatted(s) == "Alice, Bob, Charlie, Delta \u{0D0E}\u{0D28}\u{0D4D}\u{0D28}\u{0D3F}\u{0D35}")
        #endif
    }

    /// Ported from ICU `TestZulu`.
    @Test func zulu() {
        let s = style("zu")
        #expect(["Alice"].formatted(s) == "Alice")
        #expect(["Alice", "Bob"].formatted(s) == "Alice ne-Bob")
        #expect(["Alice", "Bob", "Charlie"].formatted(s) == "Alice, Bob, ne-Charlie")
        #expect(["Alice", "Bob", "Charlie", "Delta"].formatted(s) == "Alice, Bob, Charlie, ne-Delta")
    }

    // MARK: - Type / width matrix

    /// Ported from ICU `TestDifferentStyles` (skipping ULISTFMT_TYPE_UNITS — Swift only exposes .and/.or).
    @Test func differentStylesFrench() {
        let input = ["rouge", "jaune", "bleu", "vert"]
        #expect(input.formatted(style("fr", type: .and, width: .standard)) == "rouge, jaune, bleu et vert")
        #expect(input.formatted(style("fr", type: .or, width: .standard)) == "rouge, jaune, bleu ou vert")
    }

    private static let createStyledCases: [(String, Style.ListType, Style.Width, String, String)] = [
        ("pt", .and, .standard, "A, B e C",   "A e B"),
        ("pt", .and, .short,    "A, B e C",   "A e B"),
        ("pt", .and, .narrow,   "A, B, C",    "A, B"),
        ("pt", .or,  .standard, "A, B ou C",  "A ou B"),
        ("pt", .or,  .short,    "A, B ou C",  "A ou B"),
        ("pt", .or,  .narrow,   "A, B ou C",  "A ou B"),
        ("en", .and, .standard, "A, B, and C", "A and B"),
        ("en", .and, .short,    "A, B, & C",  "A & B"),
        ("en", .and, .narrow,   "A, B, C",    "A, B"),
        ("en", .or,  .standard, "A, B, or C", "A or B"),
        ("en", .or,  .short,    "A, B, or C", "A or B"),
        ("en", .or,  .narrow,   "A, B, or C", "A or B"),
    ]

    /// Cross-product of type × width for pt/en. Ported from ICU `TestCreateStyled` (skipping UNITS and NARROW_ALGORITHMIC).
    @Test(arguments: createStyledCases)
    private func createStyled(locale: String, type: Style.ListType, width: Style.Width, expected3: String, expected2: String) {
        let s = style(locale, type: type, width: width)
        #expect(["A", "B", "C"].formatted(s) == expected3)
        #expect(["A", "B"].formatted(s) == expected2)
        #expect(["A"].formatted(s) == "A")
    }

    // MARK: - Contextual conjunction
    //
    // Ported from ICU `TestContextual`. The upstream test asserts that the
    // result is invariant across widths (.standard/.short/.narrow), so we
    // iterate widths inside each case.

    private static let widths: [Style.Width] = [.standard, .short, .narrow]

    /// Spanish "y" → "e" before items starting with i-/hi- (ICU `TestContextual`, es).
    @Test(arguments: [
        ("fascinante",                     "increíblemente",     "fascinante e increíblemente"),
        ("Comunicaciones Industriales",    "IIoT",               "Comunicaciones Industriales e IIoT"),
        ("España",                         "Italia",             "España e Italia"),
        ("hijas intrépidas",               "hijos solidarios",   "hijas intrépidas e hijos solidarios"),
        ("a un hombre",                    "hirieron a otro",    "a un hombre e hirieron a otro"),
        ("hija",                           "hijo",               "hija e hijo"),
        // exceptions: still "y" before hie-/hia-/hue-
        ("oro",                            "hierro",             "oro y hierro"),
        ("agua",                           "hielo",              "agua y hielo"),
        ("colágeno",                       "hialurónico",        "colágeno y hialurónico"),
    ])
    func contextualSpanishAnd(first: String, second: String, expected: String) {
        for width in Self.widths {
            #expect([first, second].formatted(style("es", type: .and, width: width)) == expected, "width=\(width)")
        }
    }

    @Test func contextualSpanishAndThree() {
        for width in Self.widths {
            #expect(["esposa", "hija", "hijo"].formatted(style("es", type: .and, width: width)) == "esposa, hija e hijo", "width=\(width)")
        }
    }

    /// Spanish "o" → "u" before items starting with o-/ho-/8/11 (ICU `TestContextual`, es).
    @Test(arguments: [
        ("desierto", "oasis",  "desierto u oasis"),
        ("7",        "8",      "7 u 8"),
        ("7",        "80",     "7 u 80"),
        ("7",        "800",    "7 u 800"),
        ("10",       "11",     "10 u 11"),
        // exceptions: still "o" before 111, 11.2 (ones-place isn't "8" or "11")
        ("10",       "111",    "10 o 111"),
        ("10",       "11.2",   "10 o 11.2"),
    ])
    func contextualSpanishOr(first: String, second: String, expected: String) {
        for width in Self.widths {
            #expect([first, second].formatted(style("es", type: .or, width: width)) == expected, "width=\(width)")
        }
    }

    @Test(arguments: [
        (["oasis", "desierto", "océano"],  "oasis, desierto u océano"),
        (["6", "7", "8"],                  "6, 7 u 8"),
        (["9", "10", "11"],                "9, 10 u 11"),
    ])
    func contextualSpanishOrThree(items: [String], expected: String) {
        for width in Self.widths {
            #expect(items.formatted(style("es", type: .or, width: width)) == expected, "width=\(width)")
        }
    }

    /// Hebrew "ו" prefix attached to the final item. Ported from ICU `TestContextual` (he, Apple-ICU expectations
    /// with FSI/PDI bidi isolates around the ASCII items "a", "b", "c").
    @Test func contextualHebrew() {
        for width in Self.widths {
            let s = style("he", type: .and, width: width)
            #expect(["a", "b"].formatted(s) == "\u{2068}a\u{2069} ו-\u{2068}b\u{2069}", "width=\(width)")
            #expect(["a", "b", "c"].formatted(s) == "\u{2068}a\u{2069}, \u{2068}b\u{2069} ו-\u{2068}c\u{2069}", "width=\(width)")
            #expect(["1", "2"].formatted(s) == "1 ו-2", "width=\(width)")
            #expect(["1", "2", "3"].formatted(s) == "1, 2 ו-3", "width=\(width)")
            #expect(["אהבה", "מקווה"].formatted(s) == "אהבה ומקווה", "width=\(width)")
            #expect(["אהבה", "מקווה", "אמונה"].formatted(s) == "אהבה, מקווה ואמונה", "width=\(width)")
        }
    }

    /// Thai contextual conjunction (Apple-ICU). Ported from ICU `TestContextual` (th).
    @Test func contextualThaiAnd() {
        for width in Self.widths {
            let s = style("th", type: .and, width: width)
            #expect(["ข้อความธรรมดา", "1 ภาพ"].formatted(s) == "ข้อความธรรมดาและ 1 ภาพ", "width=\(width)")
            #expect(["ข้อความธรรมดา", "ข้อความธรรมดา"].formatted(s) == "ข้อความธรรมดาและข้อความธรรมดา", "width=\(width)")
            #expect(["0", "1 ภาพ"].formatted(s) == "0 และ 1 ภาพ", "width=\(width)")
            #expect(["0", "ข้อความธรรมดา"].formatted(s) == "0 และข้อความธรรมดา", "width=\(width)")
            #expect(["ข้อความธรรมดา", "ข้อความธรรมดา", "ข้อความธรรมดา"].formatted(s) == "ข้อความธรรมดา ข้อความธรรมดา และข้อความธรรมดา", "width=\(width)")
            #expect(["ข้อความธรรมดา", "ข้อความธรรมดา", "1 ภาพ"].formatted(s) == "ข้อความธรรมดา ข้อความธรรมดา และ 1 ภาพ", "width=\(width)")
        }
    }

    /// Thai "or" — only `.standard` is asserted; ICU's own test skips short/narrow because Thai's "or" patterns
    /// behave differently across widths than other locales.
    @Test func contextualThaiOr() {
        let s = style("th", type: .or, width: .standard)
        #expect(["ข้อความธรรมดา", "1 ภาพ"].formatted(s) == "ข้อความธรรมดา หรือ 1 ภาพ")
        #expect(["ข้อความธรรมดา", "ข้อความธรรมดา"].formatted(s) == "ข้อความธรรมดา หรือ ข้อความธรรมดา")
        #expect(["ข้อความธรรมดา", "ข้อความธรรมดา", "1 ภาพ"].formatted(s) == "ข้อความธรรมดา, ข้อความธรรมดา หรือ 1 ภาพ")
    }

    // MARK: - Edge cases

    /// Items containing literal `{0}` placeholders must be passed through verbatim. Ported from ICU `Test9946`.
    @Test func literalBracePlaceholders() {
        let s = style("en")
        #expect(["{0}", "{1}", "{2}"].formatted(s) == "{0}, {1}, and {2}")
    }

    /// Empty-string items don't crash and produce sensibly-shaped output. Ported from ICU `Test21871`
    /// (Swift API can't observe field positions, so we assert the formatted string).
    @Test func emptyStringItems() {
        let s = style("en")
        #expect(["A", ""].formatted(s) == "A and ")
        #expect(["", "B"].formatted(s) == " and B")
    }

    // MARK: - Bidirectional handling
    //
    // Ported from Apple ICU's `TestBidi`. When list items don't share the overall
    // string's directionality, each wrong-direction item is wrapped with FSI (U+2068) / PDI (U+2069).

    private static let arabicOne = "\u{628}\u{628}\u{628}"     // ببب
    private static let arabicTwo = "\u{644}\u{644}\u{644}"     // للل
    private static let arabicThree = "\u{62D}\u{62D}\u{62D}"   // ححح
    private static let arabicFour = "\u{645}\u{645}\u{645}"    // ممم

    /// Same-directionality lists format normally, no isolates.
    @Test func bidiSameDirectionEnglish() {
        let s = style("en")
        #expect(["Alice"].formatted(s) == "Alice")
        #expect(["Alice", "Bob"].formatted(s) == "Alice and Bob")
        #expect(["Alice", "Bob", "Charlie"].formatted(s) == "Alice, Bob, and Charlie")
        #expect(["Alice", "Bob", "Charlie", "Delta"].formatted(s) == "Alice, Bob, Charlie, and Delta")
    }

    @Test func bidiSameDirectionArabic() {
        let s = style("ar")
        let one = Self.arabicOne
        let two = Self.arabicTwo
        let three = Self.arabicThree
        let four = Self.arabicFour
        #expect([one].formatted(s) == one)
        #expect([one, two].formatted(s) == "\(one) \u{648}\(two)")
        #expect([one, two, three].formatted(s) == "\(one) \u{648}\(two) \u{648}\(three)")
        #expect([one, two, three, four].formatted(s) == "\(one) \u{648}\(two) \u{648}\(three) \u{648}\(four)")
    }

    /// English (LTR) items inside an Arabic (RTL) list — every item gets FSI/PDI.
    @Test func bidiEnglishInArabic() {
        let s = style("ar")
        let isolate: (String) -> String = { "\u{2068}\($0)\u{2069}" }
        let a = isolate("Alice"), b = isolate("Bob"), c = isolate("Charlie"), d = isolate("Delta")
        #expect(["Alice"].formatted(s) == a)
        #expect(["Alice", "Bob"].formatted(s) == "\(a) \u{648}\(b)")
        #expect(["Alice", "Bob", "Charlie"].formatted(s) == "\(a) \u{648}\(b) \u{648}\(c)")
        #expect(["Alice", "Bob", "Charlie", "Delta"].formatted(s) == "\(a) \u{648}\(b) \u{648}\(c) \u{648}\(d)")
    }

    /// Arabic (RTL) items inside an English (LTR) list — every item gets FSI/PDI.
    @Test func bidiArabicInEnglish() {
        let s = style("en")
        let isolate: (String) -> String = { "\u{2068}\($0)\u{2069}" }
        let a = isolate(Self.arabicOne), b = isolate(Self.arabicTwo), c = isolate(Self.arabicThree), d = isolate(Self.arabicFour)
        #expect([Self.arabicOne].formatted(s) == a)
        #expect([Self.arabicOne, Self.arabicTwo].formatted(s) == "\(a) and \(b)")
        #expect([Self.arabicOne, Self.arabicTwo, Self.arabicThree].formatted(s) == "\(a), \(b), and \(c)")
        #expect([Self.arabicOne, Self.arabicTwo, Self.arabicThree, Self.arabicFour].formatted(s) == "\(a), \(b), \(c), and \(d)")
    }

    /// Mixed-direction items in an Arabic list — only the wrong-direction (English) items get FSI/PDI.
    @Test func bidiMixedInArabic() {
        let s = style("ar")
        let isolate: (String) -> String = { "\u{2068}\($0)\u{2069}" }
        let a = isolate("Alice"), c = isolate("Charlie")
        let two = Self.arabicTwo, four = Self.arabicFour
        #expect(["Alice"].formatted(s) == a)
        #expect(["Alice", two].formatted(s) == "\(a) \u{648}\(two)")
        #expect(["Alice", two, "Charlie"].formatted(s) == "\(a) \u{648}\(two) \u{648}\(c)")
        #expect(["Alice", two, "Charlie", four].formatted(s) == "\(a) \u{648}\(two) \u{648}\(c) \u{648}\(four)")
    }

    /// Mixed-direction items in an English list — only the wrong-direction (Arabic) items get FSI/PDI.
    @Test func bidiMixedInEnglish() {
        let s = style("en")
        let isolate: (String) -> String = { "\u{2068}\($0)\u{2069}" }
        let one = isolate(Self.arabicOne), three = isolate(Self.arabicThree)
        let bob = "Bob", delta = "Delta"
        #expect([Self.arabicOne].formatted(s) == one)
        #expect([Self.arabicOne, bob].formatted(s) == "\(one) and \(bob)")
        #expect([Self.arabicOne, bob, Self.arabicThree].formatted(s) == "\(one), \(bob), and \(three)")
        #expect([Self.arabicOne, bob, Self.arabicThree, delta].formatted(s) == "\(one), \(bob), \(three), and \(delta)")
    }

    // MARK: - Internal pattern parser

    #if FOUNDATION_LIST_FORMAT_NATIVE
    /// `NativeListFormatter.parse(_:)` decomposes patterns into prefix /
    /// connector / suffix at formatter init. The format tests cover this
    /// indirectly; these cases pin the parser's contract directly.
    @Test func parseCanonicalPattern() {
        let p = NativeListFormatter.parse("{0}, {1}")
        #expect(p?.prefix == "")
        #expect(p?.connector == ", ")
        #expect(p?.suffix == "")
        #expect(p?.connectorStartsWithSpace == false)
        #expect(p?.connectorEndsWithSpace == true)
    }

    @Test func parseSpanishPattern() {
        let p = NativeListFormatter.parse("{0} y {1}")
        #expect(p?.connector == " y ")
        #expect(p?.connectorStartsWithSpace == true)
        #expect(p?.connectorEndsWithSpace == true)
    }

    @Test func parseWithPrefixAndSuffix() {
        let p = NativeListFormatter.parse("foo{0}…{1}bar")
        #expect(p?.prefix == "foo")
        #expect(p?.connector == "…")
        #expect(p?.suffix == "bar")
        #expect(p?.connectorStartsWithSpace == false)
        #expect(p?.connectorEndsWithSpace == false)
    }

    @Test func parseRejectsMalformed() {
        #expect(NativeListFormatter.parse("garbage") == nil)
        #expect(NativeListFormatter.parse("{0}") == nil)            // missing {1}
        #expect(NativeListFormatter.parse("{1}, {0}") == nil)       // wrong order
        #expect(NativeListFormatter.parse("{0, {1}") == nil)        // unclosed brace
        #expect(NativeListFormatter.parse("") == nil)
    }
    #endif
}
