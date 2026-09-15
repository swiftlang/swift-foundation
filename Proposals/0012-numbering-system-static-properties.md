# Feature name

* Proposal: [SF-0012](0012-numbering-system-static-properties.md)
* Authors: [Gleb Fandeev](https://github.com/glebfann)
* Review Manager: TBD
* Status: **Awaiting review**
* Implementation: [apple/swift-foundation#1055](https://github.com/swiftlang/swift-foundation/pull/1055)
* Review: ([pitch](https://forums.swift.org/t/pitch-add-static-properties-for-locale-numberingsystem/76203))

## Introduction

This proposal adds static properties to `Locale.NumberingSystem` for all standard numbering systems defined in [Unicode CLDR](https://github.com/unicode-org/cldr/blob/latest/common/bcp47/number.xml), making it easier to work with different numbering systems in Swift.

## Motivation

Currently, to use a specific numbering system, developers need to create instances using string identifiers:
```swift
let arabic = Locale.NumberingSystem("arab")
```
This approach has several drawbacks:
- Lack of Discoverability: Developers may not be aware of all available numbering systems or their corresponding identifiers.
- Error-Prone: Manually typing string identifiers increases the risk of typos and mistakes.
- Reduced Readability: String literals provide less context compared to well-named constants.
- Inconsistency: Other Locale components like `Locale.LanguageCode`, `Locale.Region`, and `Locale.Script` already provide static properties for common identifiers, but `Locale.NumberingSystem` does not.

By introducing predefined static properties for each numbering system, we can improve code safety, discoverability, readability, and maintain consistency across the Locale API.

## Proposed solution

Extend `Locale.NumberingSystem` to include static properties for each numbering system defined in the Unicode CLDR.

Example usage:
```swift
let numberingSystem = Locale.NumberingSystem.arabicIndic
```
This allows developers to:

- Use autocomplete features to discover available numbering systems.
- Reduce typos and mistakes by avoiding manually typed strings: `let numberingSystem = Locale.NumberingSystem("arabic") // Incorrect identifier`
- Improve code clarity with descriptive property names. For example, `Locale.NumberingSystem.simplifiedChinese` instead of `Locale.NumberingSystem("hans")`

## Detailed design

Add an extension to `Locale.NumberingSystem` containing static properties for each numbering system. The identifiers are sourced from the Unicode CLDR's numbering systems registry.

```swift
@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension Locale.NumberingSystem {
    /// Adlam digits.
    /// - Identifier: `"adlm"`.
    @_alwaysEmitIntoClient
    public static var adlam: Locale.NumberingSystem { Locale.NumberingSystem("adlm") }

    /// Ahom digits.
    /// - Identifier: `"ahom"`.
    @_alwaysEmitIntoClient
    public static var ahom: Locale.NumberingSystem { Locale.NumberingSystem("ahom") }

    /// Arabic-Indic digits.
    /// - Identifier: `"arab"`.
    @_alwaysEmitIntoClient
    public static var arabicIndic: Locale.NumberingSystem { Locale.NumberingSystem("arab") }

    /// Extended Arabic-Indic digits.
    /// - Identifier: `"arabext"`.
    @_alwaysEmitIntoClient
    public static var arabicIndicExtended: Locale.NumberingSystem { Locale.NumberingSystem("arabext") }

    /// Armenian upper case numerals — algorithmic.
    /// - Identifier: `"armn"`.
    @_alwaysEmitIntoClient
    public static var armenianUppercase: Locale.NumberingSystem { Locale.NumberingSystem("armn") }

    /// Armenian lower case numerals — algorithmic.
    /// - Identifier: `"armnlow"`.
    @_alwaysEmitIntoClient
    public static var armenianLowercase: Locale.NumberingSystem { Locale.NumberingSystem("armnlow") }

    /// Balinese digits.
    /// - Identifier: `"bali"`.
    @_alwaysEmitIntoClient
    public static var balinese: Locale.NumberingSystem { Locale.NumberingSystem("bali") }

    /// Bengali digits.
    /// - Identifier: `"beng"`.
    @_alwaysEmitIntoClient
    public static var bengali: Locale.NumberingSystem { Locale.NumberingSystem("beng") }

    /// Bhaiksuki digits.
    /// - Identifier: `"bhks"`.
    @_alwaysEmitIntoClient
    public static var bhaiksuki: Locale.NumberingSystem { Locale.NumberingSystem("bhks") }

    /// Brahmi digits.
    /// - Identifier: `"brah"`.
    @_alwaysEmitIntoClient
    public static var brahmi: Locale.NumberingSystem { Locale.NumberingSystem("brah") }

    /// Chakma digits.
    /// - Identifier: `"cakm"`.
    @_alwaysEmitIntoClient
    public static var chakma: Locale.NumberingSystem { Locale.NumberingSystem("cakm") }

    /// Cham digits.
    /// - Identifier: `"cham"`.
    @_alwaysEmitIntoClient
    public static var cham: Locale.NumberingSystem { Locale.NumberingSystem("cham") }

    /// Cyrillic numerals — algorithmic.
    /// - Identifier: `"cyrl"`.
    @_alwaysEmitIntoClient
    public static var cyrillic: Locale.NumberingSystem { Locale.NumberingSystem("cyrl") }

    /// Devanagari digits.
    /// - Identifier: `"deva"`.
    @_alwaysEmitIntoClient
    public static var devanagari: Locale.NumberingSystem { Locale.NumberingSystem("deva") }

    /// Dives Akuru digits.
    /// - Identifier: `"diak"`.
    @_alwaysEmitIntoClient
    public static var divesAkuru: Locale.NumberingSystem { Locale.NumberingSystem("diak") }

    /// Ethiopic numerals — algorithmic.
    /// - Identifier: `"ethi"`.
    @_alwaysEmitIntoClient
    public static var ethiopic: Locale.NumberingSystem { Locale.NumberingSystem("ethi") }

    /// Financial numerals specific to the current locale — may be algorithmic.
    /// - Identifier: `"finance"`.
    public static var localeFinancial: Locale.NumberingSystem { Locale.NumberingSystem("finance") }

    /// Full width digits.
    /// - Identifier: `"fullwide"`.
    @_alwaysEmitIntoClient
    public static var fullWidth: Locale.NumberingSystem { Locale.NumberingSystem("fullwide") }

    /// Georgian numerals — algorithmic.
    /// - Identifier: `"geor"`.
    @_alwaysEmitIntoClient
    public static var georgian: Locale.NumberingSystem { Locale.NumberingSystem("geor") }

    /// Gunjala Gondi digits.
    /// - Identifier: `"gong"`.
    @_alwaysEmitIntoClient
    public static var gunjalaGondi: Locale.NumberingSystem { Locale.NumberingSystem("gong") }

    /// Masaram Gondi digits.
    /// - Identifier: `"gonm"`.
    @_alwaysEmitIntoClient
    public static var masaramGondi: Locale.NumberingSystem { Locale.NumberingSystem("gonm") }

    /// Greek upper case numerals — algorithmic.
    /// - Identifier: `"grek"`.
    @_alwaysEmitIntoClient
    public static var greekUppercase: Locale.NumberingSystem { Locale.NumberingSystem("grek") }

    /// Greek lower case numerals — algorithmic.
    /// - Identifier: `"greklow"`.
    @_alwaysEmitIntoClient
    public static var greekLowercase: Locale.NumberingSystem { Locale.NumberingSystem("greklow") }

    /// Gujarati digits.
    /// - Identifier: `"gujr"`.
    @_alwaysEmitIntoClient
    public static var gujarati: Locale.NumberingSystem { Locale.NumberingSystem("gujr") }

    /// Gurmukhi digits.
    /// - Identifier: `"guru"`.
    @_alwaysEmitIntoClient
    public static var gurmukhi: Locale.NumberingSystem { Locale.NumberingSystem("guru") }

    /// Han-character day-of-month numbering for lunar/other traditional calendars.
    /// - Identifier: `"hanidays"`.
    @_alwaysEmitIntoClient
    public static var hanDayOfMonth: Locale.NumberingSystem { Locale.NumberingSystem("hanidays") }

    /// Positional decimal system using Chinese number ideographs as digits.
    /// - Identifier: `"hanidec"`.
    @_alwaysEmitIntoClient
    public static var hanDecimal: Locale.NumberingSystem { Locale.NumberingSystem("hanidec") }

    /// Simplified Chinese numerals — algorithmic.
    /// - Identifier: `"hans"`.
    @_alwaysEmitIntoClient
    public static var simplifiedChinese: Locale.NumberingSystem { Locale.NumberingSystem("hans") }

    /// Simplified Chinese financial numerals — algorithmic.
    /// - Identifier: `"hansfin"`.
    @_alwaysEmitIntoClient
    public static var simplifiedChineseFinancial: Locale.NumberingSystem { Locale.NumberingSystem("hansfin") }

    /// Traditional Chinese numerals — algorithmic.
    /// - Identifier: `"hant"`.
    @_alwaysEmitIntoClient
    public static var traditionalChinese: Locale.NumberingSystem { Locale.NumberingSystem("hant") }

    /// Traditional Chinese financial numerals — algorithmic.
    /// - Identifier: `"hantfin"`.
    @_alwaysEmitIntoClient
    public static var traditionalChineseFinancial: Locale.NumberingSystem { Locale.NumberingSystem("hantfin") }

    /// Hebrew numerals — algorithmic.
    /// - Identifier: `"hebr"`.
    @_alwaysEmitIntoClient
    public static var hebrew: Locale.NumberingSystem { Locale.NumberingSystem("hebr") }

    /// Pahawh Hmong digits.
    /// - Identifier: `"hmng"`.
    @_alwaysEmitIntoClient
    public static var pahawhHmong: Locale.NumberingSystem { Locale.NumberingSystem("hmng") }

    /// Nyiakeng Puachue Hmong digits.
    /// - Identifier: `"hmnp"`.
    @_alwaysEmitIntoClient
    public static var nyiakengPuachueHmong: Locale.NumberingSystem { Locale.NumberingSystem("hmnp") }

    /// Javanese digits.
    /// - Identifier: `"java"`.
    @_alwaysEmitIntoClient
    public static var javanese: Locale.NumberingSystem { Locale.NumberingSystem("java") }

    /// Japanese numerals — algorithmic.
    /// - Identifier: `"jpan"`.
    @_alwaysEmitIntoClient
    public static var japanese: Locale.NumberingSystem { Locale.NumberingSystem("jpan") }

    /// Japanese financial numerals — algorithmic.
    /// - Identifier: `"jpanfin"`.
    @_alwaysEmitIntoClient
    public static var japaneseFinancial: Locale.NumberingSystem { Locale.NumberingSystem("jpanfin") }

    /// Japanese first-year Gannen numbering for Japanese calendar.
    /// - Identifier: `"jpanyear"`.
    @_alwaysEmitIntoClient
    public static var japaneseGannen: Locale.NumberingSystem { Locale.NumberingSystem("jpanyear") }

    /// Kayah Li digits.
    /// - Identifier: `"kali"`.
    @_alwaysEmitIntoClient
    public static var kayahLi: Locale.NumberingSystem { Locale.NumberingSystem("kali") }

    /// Khmer digits.
    /// - Identifier: `"khmr"`.
    @_alwaysEmitIntoClient
    public static var khmer: Locale.NumberingSystem { Locale.NumberingSystem("khmr") }

    /// Kannada digits.
    /// - Identifier: `"knda"`.
    @_alwaysEmitIntoClient
    public static var kannada: Locale.NumberingSystem { Locale.NumberingSystem("knda") }

    /// Tai Tham Hora (secular) digits.
    /// - Identifier: `"lana"`.
    @_alwaysEmitIntoClient
    public static var taiThamHora: Locale.NumberingSystem { Locale.NumberingSystem("lana") }

    /// Tai Tham Tham (ecclesiastical) digits.
    /// - Identifier: `"lanatham"`.
    @_alwaysEmitIntoClient
    public static var taiThamTham: Locale.NumberingSystem { Locale.NumberingSystem("lanatham") }

    /// Lao digits.
    /// - Identifier: `"laoo"`.
    @_alwaysEmitIntoClient
    public static var lao: Locale.NumberingSystem { Locale.NumberingSystem("laoo") }

    /// Latin digits.
    /// - Identifier: `"latn"`.
    @_alwaysEmitIntoClient
    public static var latin: Locale.NumberingSystem { Locale.NumberingSystem("latn") }

    /// Lepcha digits.
    /// - Identifier: `"lepc"`.
    @_alwaysEmitIntoClient
    public static var lepcha: Locale.NumberingSystem { Locale.NumberingSystem("lepc") }

    /// Limbu digits.
    /// - Identifier: `"limb"`.
    @_alwaysEmitIntoClient
    public static var limbu: Locale.NumberingSystem { Locale.NumberingSystem("limb") }

    /// Mathematical bold digits.
    /// - Identifier: `"mathbold"`.
    @_alwaysEmitIntoClient
    public static var mathBold: Locale.NumberingSystem { Locale.NumberingSystem("mathbold") }

    /// Mathematical double-struck digits.
    /// - Identifier: `"mathdbl"`.
    @_alwaysEmitIntoClient
    public static var mathDoubleStruck: Locale.NumberingSystem { Locale.NumberingSystem("mathdbl") }

    /// Mathematical monospace digits.
    /// - Identifier: `"mathmono"`.
    @_alwaysEmitIntoClient
    public static var mathMonospace: Locale.NumberingSystem { Locale.NumberingSystem("mathmono") }

    /// Mathematical sans-serif bold digits.
    /// - Identifier: `"mathsanb"`.
    @_alwaysEmitIntoClient
    public static var mathSansSerifBold: Locale.NumberingSystem { Locale.NumberingSystem("mathsanb") }

    /// Mathematical sans-serif digits.
    /// - Identifier: `"mathsans"`.
    @_alwaysEmitIntoClient
    public static var mathSansSerif: Locale.NumberingSystem { Locale.NumberingSystem("mathsans") }

    /// Malayalam digits.
    /// - Identifier: `"mlym"`.
    @_alwaysEmitIntoClient
    public static var malayalam: Locale.NumberingSystem { Locale.NumberingSystem("mlym") }

    /// Modi digits.
    /// - Identifier: `"modi"`.
    @_alwaysEmitIntoClient
    public static var modi: Locale.NumberingSystem { Locale.NumberingSystem("modi") }

    /// Mongolian digits.
    /// - Identifier: `"mong"`.
    @_alwaysEmitIntoClient
    public static var mongolian: Locale.NumberingSystem { Locale.NumberingSystem("mong") }

    /// Mro digits.
    /// - Identifier: `"mroo"`.
    @_alwaysEmitIntoClient
    public static var mro: Locale.NumberingSystem { Locale.NumberingSystem("mroo") }

    /// Meetei Mayek digits.
    /// - Identifier: `"mtei"`.
    @_alwaysEmitIntoClient
    public static var meeteiMayek: Locale.NumberingSystem { Locale.NumberingSystem("mtei") }

    /// Myanmar digits.
    /// - Identifier: `"mymr"`.
    @_alwaysEmitIntoClient
    public static var myanmar: Locale.NumberingSystem { Locale.NumberingSystem("mymr") }

    /// Myanmar Shan digits.
    /// - Identifier: `"mymrshan"`.
    @_alwaysEmitIntoClient
    public static var myanmarShan: Locale.NumberingSystem { Locale.NumberingSystem("mymrshan") }

    /// Myanmar Tai Laing digits.
    /// - Identifier: `"mymrtlng"`.
    @_alwaysEmitIntoClient
    public static var myanmarTaiLaing: Locale.NumberingSystem { Locale.NumberingSystem("mymrtlng") }

    /// Native digits specific to the current locale.
    /// - Identifier: `"native"`.
    public static var localeNative: Locale.NumberingSystem { Locale.NumberingSystem("native") }

    /// Newa digits.
    /// - Identifier: `"newa"`.
    @_alwaysEmitIntoClient
    public static var newa: Locale.NumberingSystem { Locale.NumberingSystem("newa") }

    /// N'Ko digits.
    /// - Identifier: `"nkoo"`.
    @_alwaysEmitIntoClient
    public static var nKo: Locale.NumberingSystem { Locale.NumberingSystem("nkoo") }

    /// Ol Chiki digits.
    /// - Identifier: `"olck"`.
    @_alwaysEmitIntoClient
    public static var olChiki: Locale.NumberingSystem { Locale.NumberingSystem("olck") }

    /// Oriya digits.
    /// - Identifier: `"orya"`.
    @_alwaysEmitIntoClient
    public static var oriya: Locale.NumberingSystem { Locale.NumberingSystem("orya") }

    /// Osmanya digits.
    /// - Identifier: `"osma"`.
    @_alwaysEmitIntoClient
    public static var osmanya: Locale.NumberingSystem { Locale.NumberingSystem("osma") }

    /// Hanifi Rohingya digits.
    /// - Identifier: `"rohg"`.
    @_alwaysEmitIntoClient
    public static var hanifiRohingya: Locale.NumberingSystem { Locale.NumberingSystem("rohg") }

    /// Roman upper case numerals — algorithmic.
    /// - Identifier: `"roman"`.
    @_alwaysEmitIntoClient
    public static var romanUppercase: Locale.NumberingSystem { Locale.NumberingSystem("roman") }

    /// Roman lowercase numerals — algorithmic.
    /// - Identifier: `"romanlow"`.
    @_alwaysEmitIntoClient
    public static var romanLowercase: Locale.NumberingSystem { Locale.NumberingSystem("romanlow") }

    /// Saurashtra digits.
    /// - Identifier: `"saur"`.
    @_alwaysEmitIntoClient
    public static var saurashtra: Locale.NumberingSystem { Locale.NumberingSystem("saur") }

    /// Sharada digits.
    /// - Identifier: `"shrd"`.
    @_alwaysEmitIntoClient
    public static var sharada: Locale.NumberingSystem { Locale.NumberingSystem("shrd") }

    /// Khudawadi digits.
    /// - Identifier: `"sind"`.
    @_alwaysEmitIntoClient
    public static var khudawadi: Locale.NumberingSystem { Locale.NumberingSystem("sind") }

    /// Sinhala Lith digits.
    /// - Identifier: `"sinh"`.
    @_alwaysEmitIntoClient
    public static var sinhalaLith: Locale.NumberingSystem { Locale.NumberingSystem("sinh") }

    /// Sora Sompeng digits.
    /// - Identifier: `"sora"`.
    @_alwaysEmitIntoClient
    public static var soraSompeng: Locale.NumberingSystem { Locale.NumberingSystem("sora") }

    /// Sundanese digits.
    /// - Identifier: `"sund"`.
    @_alwaysEmitIntoClient
    public static var sundanese: Locale.NumberingSystem { Locale.NumberingSystem("sund") }

    /// Takri digits.
    /// - Identifier: `"takr"`.
    @_alwaysEmitIntoClient
    public static var takri: Locale.NumberingSystem { Locale.NumberingSystem("takr") }

    /// New Tai Lue digits.
    /// - Identifier: `"talu"`.
    @_alwaysEmitIntoClient
    public static var newTaiLue: Locale.NumberingSystem { Locale.NumberingSystem("talu") }

    /// Tamil numerals — algorithmic.
    /// - Identifier: `"taml"`.
    @_alwaysEmitIntoClient
    public static var tamil: Locale.NumberingSystem { Locale.NumberingSystem("taml") }

    /// Modern Tamil decimal digits.
    /// - Identifier: `"tamldec"`.
    @_alwaysEmitIntoClient
    public static var tamilDecimal: Locale.NumberingSystem { Locale.NumberingSystem("tamldec") }

    /// Telugu digits.
    /// - Identifier: `"telu"`.
    @_alwaysEmitIntoClient
    public static var telugu: Locale.NumberingSystem { Locale.NumberingSystem("telu") }

    /// Thai digits.
    /// - Identifier: `"thai"`.
    @_alwaysEmitIntoClient
    public static var thai: Locale.NumberingSystem { Locale.NumberingSystem("thai") }

    /// Tirhuta digits.
    /// - Identifier: `"tirh"`.
    @_alwaysEmitIntoClient
    public static var tirhuta: Locale.NumberingSystem { Locale.NumberingSystem("tirh") }

    /// Tibetan digits.
    /// - Identifier: `"tibt"`.
    @_alwaysEmitIntoClient
    public static var tibetan: Locale.NumberingSystem { Locale.NumberingSystem("tibt") }

    /// Traditional numerals specific to the current locale — may be algorithmic.
    /// - Identifier: `"traditio"`.
    public static var localeTraditional: Locale.NumberingSystem { Locale.NumberingSystem("traditio") }

    /// Vai digits.
    /// - Identifier: `"vaii"`.
    @_alwaysEmitIntoClient
    public static var vai: Locale.NumberingSystem { Locale.NumberingSystem("vaii") }

    /// Warang Citi digits.
    /// - Identifier: `"wara"`.
    @_alwaysEmitIntoClient
    public static var warangCiti: Locale.NumberingSystem { Locale.NumberingSystem("wara") }

    /// Wancho digits.
    /// - Identifier: `"wcho"`.
    @_alwaysEmitIntoClient
    public static var wancho: Locale.NumberingSystem { Locale.NumberingSystem("wcho") }
}
```

Variable names are assigned based on the descriptions provided in the [Unicode CLDR](https://github.com/unicode-org/cldr/blob/latest/common/bcp47/number.xml).

## Source compatibility

These changes are additive only and are not expected to have an impact on source compatibility.

## Implications on adoption

This feature can be freely adopted and un-adopted in source code with no deployment constraints and without affecting source compatibility.

## Acknowledgments

Thanks to [Alobaili](https://forums.swift.org/u/alobaili/summary) for highlighting this issue in their [comment](https://forums.swift.org/t/fou-locale-components-language-and-language-components/54084/17) on the Swift forums, which inspired this proposal.
