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

// CLDR locale fallback shared by the data generators: parent locales and
// locale aliases. Each generator compiles this file alongside its own impl.

import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

enum CLDRFileError: Error, CustomStringConvertible {
    case xmlParse(URL, Error)

    var description: String {
        switch self {
        case .xmlParse(let url, let error): return "failed to parse \(url.lastPathComponent): \(error)"
        }
    }
}

// MARK: - Draft status

// Values CLDR marks with these draft statuses aren't in ICU's data, since
// cldr-to-icu's minimum draft status is "contributed".
let excludedDrafts: Set<String> = ["unconfirmed", "provisional"]

// MARK: - Locale aliases

// The list of locale aliases below is hand-maintained.
// It's used to handle deprecated identifiers such as `iw` → `he` and minimized
// identifiers such as `zh_HK` → `zh_Hant_HK`, so that we are able to retrieve
// the correct data.
// For example, with these aliases list formatting correctly resolves
// `zh_HK` → `zh_Hant_HK` → `及`, instead of the incorrect `zh_HK` → `zh` → `和`.
// This list was originally based on the `%%ALIAS` entries in Apple ICU's
// `icu/icu4c/source/data/locales/*.txt`, which were in turn derived from a
// hard-coded list in `icu/tools/cldr/cldr-to-icu/config.xml`.
let localeAliases: [String: String] = [
    "ars": "ar_SA",
    "az_AZ": "az_Latn_AZ",
    "bs_BA": "bs_Latn_BA",
    "en_NH": "en_VU",
    "en_RH": "en_ZW",
    "ff_CM": "ff_Latn_CM",
    "ff_GN": "ff_Latn_GN",
    "ff_MR": "ff_Latn_MR",
    "ff_SN": "ff_Latn_SN",
    "in": "id",
    "in_ID": "id_ID",
    "iw": "he",
    "iw_IL": "he_IL",
    "ks_Aran": "ks_Arab",
    "ks_IN": "ks_Aran_IN",
    "ku_SY": "ku_Latn_SY",
    "kxv_IN": "kxv_Latn_IN",
    "mni_IN": "mni_Beng_IN",
    "mo": "ro",
    "no_NO": "no",
    "no_NO_NY": "nn_NO",
    "pa_Aran": "pa_Arab",
    "pa_IN": "pa_Guru_IN",
    "pa_PK": "pa_Aran_PK",
    "sat_IN": "sat_Olck_IN",
    "sd_IN": "sd_Deva_IN",
    "sd_PK": "sd_Arab_PK",
    "sh": "sr_Latn",
    "sh_BA": "sr_Latn_BA",
    "sh_CS": "sr_Latn_RS",
    "sh_YU": "sr_Latn_RS",
    "shi_MA": "shi_Tfng_MA",
    "sr_BA": "sr_Cyrl_BA",
    "sr_CS": "sr_RS",
    "sr_Cyrl_CS": "sr_Cyrl_RS",
    "sr_Cyrl_YU": "sr_Cyrl_RS",
    "sr_Latn_CS": "sr_Latn_RS",
    "sr_Latn_YU": "sr_Latn_RS",
    "sr_ME": "sr_Latn_ME",
    "sr_RS": "sr_Cyrl_RS",
    "sr_XK": "sr_Cyrl_XK",
    "sr_YU": "sr_RS",
    "su_ID": "su_Latn_ID",
    "tl": "fil",
    "tl_PH": "fil_PH",
    "ur_Aran": "ur_Arab",
    "ur_Aran_IN": "ur_Arab_IN",
    "ur_IN": "ur_Aran_IN",
    "ur_PK": "ur_Aran_PK",
    "uz_AF": "uz_Arab_AF",
    "uz_UZ": "uz_Latn_UZ",
    "vai_LR": "vai_Vaii_LR",
    "wuu": "zh",
    "yue_CN": "yue_Hans_CN",
    "yue_HK": "yue_Hant_HK",
    "zh_CN": "zh_Hans_CN",
    "zh_HK": "zh_Hant_HK",
    "zh_JP": "zh_Hans_JP",
    "zh_MO": "zh_Hant_MO",
    "zh_SG": "zh_Hans_SG",
    "zh_TW": "zh_Hant_TW",
]

// MARK: - ICU locales

// The locales ICU builds, as listed in Apple ICU's
// `icu/tools/cldr/cldr-to-icu/config.xml` `<localeIds>`. This list is
// hand-maintained. `icuLocales` expands it as cldr-to-icu does.
let icuLocaleIDs: [String] = [
    "acf", "af", "agq", "ain", "ak", "am", "apw", "ar", "arn", "ars", "as", "asa", "ast", "az", "az_AZ", "az_Cyrl",
    "ba", "bas", "be", "bem", "ber", "ber_Latn", "bez", "bg", "bgc", "bho", "bla", "blo", "bm", "bn", "bo", "br",
    "brx", "bs", "bs_BA", "bs_Cyrl", "bua", "byn",
    "ca", "ccp", "ce", "ceb", "cgg", "cho", "chr", "cic", "ckb", "co", "com", "cr", "crj", "crk", "crl", "crm", "cs",
    "cst", "csw", "cv", "cwd", "cy",
    "da", "dav", "de", "dje", "doi", "dsb", "dua", "dv", "dyo", "dz",
    "ebu", "ee", "el", "en", "en_NH", "en_RH", "eo", "es", "et", "eu", "ewo",
    "fa", "ff", "ff_Adlm", "ff_CM", "ff_GN", "ff_MR", "ff_SN", "fi", "fil", "fla", "fo", "fr", "fur", "fy",
    "ga", "gaa", "gcf", "gd", "gl", "gn", "gsw", "gu", "guz", "gv",
    "ha", "haw", "hch", "he", "hi", "hi_Latn", "hmn", "hr", "hsb", "ht", "hu", "hy",
    "ia", "id", "ie", "ig", "ii", "in", "in_ID", "inh", "io", "is", "isc", "it", "iu", "iw", "iw_IL",
    "ja", "jbo", "jgo", "jmc", "jv",
    "ka", "kab", "kaj", "kam", "kcg", "kde", "kea", "kgp", "khq", "ki", "kio", "kk", "kk_Arab", "kkj", "kl", "kln",
    "km", "kn", "ko", "kok", "kok_Latn", "kpe", "ks", "ks_Arab", "ks_Deva", "ks_IN", "ksb", "ksf", "ksh", "ku",
    "ku_SY", "kw", "kxv", "kxv_Deva", "kxv_IN", "kxv_Orya", "kxv_Telu", "ky",
    "lag", "lb", "lg", "lij", "lkt", "lmo", "ln", "lo", "lrc", "lt", "lu", "luo", "lut", "luy", "lv",
    "mai", "mas", "mer", "mfe", "mg", "mgh", "mgo", "mi", "mic", "mid", "mk", "ml", "mn", "mni", "mni_IN", "mni_Mtei",
    "mo", "moh", "mr", "ms", "ms_Arab", "mt", "mua", "mus", "my", "myv", "mzn",
    "naq", "nb", "nd", "nds", "ne", "nez", "nl", "nmg", "nn", "nnh", "nnp", "no", "no_NO", "no_NO_NY", "nqo", "nr",
    "nso", "nus", "nv", "ny", "nyn",
    "oc", "om", "or", "os", "osa",
    "pa", "pa_Arab", "pa_Aran", "pa_IN", "pa_PK", "pcm", "pl", "pms", "pqm", "prg", "ps", "pt",
    "qu",
    "raj", "rej", "rej_Rjng", "rhg", "rm", "rn", "ro", "rof", "ru", "rw", "rwk",
    "sa", "sah", "saq", "sat", "sat_Deva", "sat_IN", "sbp", "sc", "scn", "sd", "sd_Deva", "sd_IN", "sd_PK", "se",
    "seh", "ses", "sg", "sh", "sh_BA", "sh_CS", "sh_YU", "shi", "shi_Latn", "shi_MA", "shn", "shp", "si", "sjd", "sje",
    "sju", "sk", "sl", "sm", "smn", "sn", "so", "sq", "sr", "sr_BA", "sr_CS", "sr_Cyrl_CS", "sr_Cyrl_YU", "sr_Latn",
    "sr_Latn_CS", "sr_Latn_YU", "sr_ME", "sr_RS", "sr_XK", "sr_YU", "srs", "ss", "st", "su", "su_ID", "sv", "sw",
    "syr", "szl",
    "ta", "te", "teo", "tg", "th", "ti", "tig", "tk", "tl", "tl_PH", "tn", "to", "tok", "tr", "trv", "ts", "tt", "twq",
    "tyv", "tzm",
    "ug", "uk", "ur", "ur_Arab", "ur_IN", "ur_PK", "uz", "uz_AF", "uz_Arab", "uz_Cyrl", "uz_UZ",
    "vai", "vai_LR", "vai_Latn", "ve", "vec", "vi", "vmw", "vun",
    "wa", "wae", "wal", "wo", "wuu",
    "xh", "xnr", "xog",
    "yav", "yi", "yo", "yrl", "yue", "yue_CN", "yue_HK", "yue_Hans",
    "za", "zgh", "zh", "zh_CN", "zh_HK", "zh_Hant", "zh_JP", "zh_MO", "zh_SG", "zh_TW", "zu",
]

/// The locales ICU builds: each language or language and script in `icuLocaleIDs` with every CLDR locale under it
/// in the same language, plus the listed locales and their parents. Alias sources are left out, since ICU makes
/// them aliases even where CLDR has data. Alias targets without CLDR data, and their parents, are included, as ICU
/// writes an empty locale for each.
func icuLocales(available: Set<String>, parents: [String: String], likelySubtags: [String: String]) -> Set<String> {
    func language(_ locale: String) -> Substring { locale.prefix { $0 != "_" } }
    // A language and its default script count as the language.
    var wildcards = Set<String>()
    for id in icuLocaleIDs where available.contains(id) && id.wholeMatch(of: #/[a-z]{2,3}(_[A-Z][a-z]{3})?/#) != nil {
        let lang = String(language(id))
        wildcards.insert(id != lang && likelySubtags[lang]?.hasPrefix(id) == true ? lang : id)
    }
    func underWildcard(_ locale: String) -> Bool {
        guard let p = parent(of: locale, explicit: parents), p != "root", language(p) == language(locale) else { return false }
        return wildcards.contains(p) || underWildcard(p)
    }
    var result = Set(available.filter(underWildcard))
    for id in icuLocaleIDs {
        var current: String? = id
        while let l = current, l != "root", result.insert(l).inserted {
            current = parent(of: l, explicit: parents)
        }
    }
    // cldr-to-icu skips these until ICU-20997 is fixed or for low coverage.
    result = result.filter { available.contains($0) && localeAliases[$0] == nil && !["VALENCIA", "TARASK", "POLYTON"].contains(where: $0.contains) }
    for target in localeAliases.values {
        var current: String? = target
        while let l = current, l != "root", localeAliases[l] == nil, result.insert(l).inserted {
            current = parent(of: l, explicit: parents)
        }
    }
    result.insert("root")
    return result
}

// MARK: - Likely subtags

/// CLDR's likely subtags, such as `sr` → `sr_Cyrl_RS`.
func loadLikelySubtags(supplementalURL: URL) throws -> [String: String] {
    let doc: XMLDocument
    do {
        doc = try XMLDocument(contentsOf: supplementalURL)
    } catch {
        throw CLDRFileError.xmlParse(supplementalURL, error)
    }
    var map: [String: String] = [:]
    for case let elt as XMLElement in try doc.nodes(forXPath: "//likelySubtag") {
        if let from = elt.attribute(forName: "from")?.stringValue, let to = elt.attribute(forName: "to")?.stringValue {
            map[from] = to
        }
    }
    return map
}

/// Each language, or language and region, whose likely script isn't Latin, with that script, as ICU's
/// resource fallback reads them.
func defaultScripts(likelySubtags: [String: String]) -> [String: String] {
    var result: [String: String] = [:]
    for (from, to) in likelySubtags {
        let fromParts = from.split(separator: "_")
        let toParts = to.split(separator: "_")
        // Skip und entries, and entries that already name a script.
        guard fromParts[0] != "und", fromParts.count < 3, toParts.count == 3 else { continue }
        if fromParts.count == 2 && fromParts[1].count > 3 { continue }
        if toParts[1] != "Latn" {
            result[from] = String(toParts[1])
        }
    }
    return result
}

// MARK: - Script fallback

/// The language, script, and region of a locale identifier, and whether it has no other subtags, such as a variant.
func subtags(_ locale: String) -> (language: Substring, script: Substring?, region: Substring?, isComplete: Bool) {
    let parts = locale.split(separator: "_", omittingEmptySubsequences: false)
    var i = 1
    var script: Substring?
    var region: Substring?
    if i < parts.count, parts[i].count == 4, parts[i].allSatisfy(\.isASCII), parts[i].allSatisfy(\.isLetter) {
        script = parts[i]
        i += 1
    }
    if i < parts.count, (parts[i].count == 2 && parts[i].allSatisfy { $0.isASCII && $0.isLetter }) || (parts[i].count == 3 && parts[i].allSatisfy { $0.isASCII && $0.isNumber }) {
        region = parts[i]
        i += 1
    }
    return (parts[0], script, region, i == parts.count)
}

/// The locale ICU tries after `locale`, which has no data, as ICU's `getParentLocaleID` does.
/// `original` is the identifier the search started from. Nil means ICU stops and uses its default.
func icuParent(of locale: String, original: String, defaultScripts: [String: String]) -> String? {
    let (language, script, region, isComplete) = subtags(locale)
    guard isComplete else {
        return locale.lastIndex(of: "_").map { String(locale[..<$0]) }
    }
    func defaultScript(_ region: Substring?) -> String {
        region.flatMap { defaultScripts["\(language)_\($0)"] } ?? defaultScripts[String(language)] ?? "Latn"
    }
    switch (script, region) {
    case let (script?, region?):
        return defaultScript(region) == script ? "\(language)_\(region)" : "\(language)_\(script)"
    case let (nil, region?):
        return "\(language)_\(subtags(original).script.map(String.init) ?? defaultScript(region))"
    case let (script?, nil):
        return defaultScript(nil) == script ? String(language) : nil
    case (nil, nil):
        return nil
    }
}

/// The locale in `included` that ICU resolves an identifier to, following `redirects` (its aliases and parent
/// locales) and its resource fallback. Nil where ICU uses its default locale.
func icuResolve(_ locale: String, included: Set<String>, redirects: [String: String], defaultScripts: [String: String]) -> String? {
    var current = locale
    var seen: Set<String> = []
    while !included.contains(current) {
        precondition(seen.insert(current).inserted, "ICU's fallback cycles for \(locale)")
        guard let next = redirects[current] ?? icuParent(of: current, original: locale, defaultScripts: defaultScripts) else {
            return nil
        }
        if seen.contains(next) {
            // In a subset, an alias and the script fallback can lead back and forth between excluded locales
            // (az_AZ is an alias of az_Latn_AZ, whose parent is az_AZ). Continue from the one with a script,
            // without its region, so every identifier in the cycle resolves the same way.
            let withScript = subtags(next).script != nil ? next : current
            guard let underscore = withScript.lastIndex(of: "_") else { return nil }
            current = String(withScript[..<underscore])
        } else {
            current = next
        }
    }
    return current
}

/// `redirects` plus redirects for ICU's script fallback, such as en_Latn_GB to en_GB and az_RU to az_Cyrl, where
/// the runtime's truncation would give other data. `data` gives what the runtime finds for an identifier with the
/// given redirects. ICU's results and truncation can only differ for a language combined with scripts and regions it
/// has in the data or the default scripts. Where ICU uses its default locale (en_Cyrl), the runtime keeps the language.
func scriptFallbackRedirects<Data: Equatable>(
    included: Set<String>,
    icuRedirects: [String: String],
    defaultScripts: [String: String],
    redirects: [String: String],
    data: (String, [String: String]) -> Data
) -> [String: String] {
    var scripts: [Substring: Set<Substring>] = [:]
    var regions: [Substring: Set<Substring>] = [:]
    for id in included.union(icuRedirects.keys).union(icuRedirects.values).union(defaultScripts.keys) {
        let (language, script, region, _) = subtags(id)
        scripts[language, default: []].formUnion([script, defaultScripts[id].map { Substring($0) }].compactMap { $0 })
        if let region { regions[language, default: []].insert(region) }
    }
    var probes: [String] = []
    for language in Set(included.union(icuRedirects.keys).map { subtags($0).language }) {
        let languageScripts = scripts[language, default: []].union(["Latn"])
        // AA, a private-use region, stands for every region without data, which no redirect could cover.
        let languageRegions = regions[language, default: []].union(["AA"])
        probes += languageScripts.map { "\(language)_\($0)" } + languageRegions.map { "\(language)_\($0)" }
        probes += languageScripts.flatMap { script in languageRegions.map { "\(language)_\(script)_\($0)" } }
    }
    probes.sort { ($0.count(where: { $0 == "_" }), $0) < ($1.count(where: { $0 == "_" }), $1) }
    var result = redirects
    for probe in probes where !included.contains(probe) && result[probe] == nil {
        guard let icu = icuResolve(probe, included: included, redirects: icuRedirects, defaultScripts: defaultScripts) else { continue }
        if data(icu, result) != data(probe, result) {
            precondition(!probe.hasSuffix("_AA"), "\(probe) needs a redirect for every region")
            result[probe] = icu
        }
    }
    for probe in probes {
        guard let icu = icuResolve(probe, included: included, redirects: icuRedirects, defaultScripts: defaultScripts) else { continue }
        precondition(data(icu, result) == data(probe, result), "\(probe) differs from ICU")
    }
    return result
}


// MARK: - Parent map

func loadParentMap(supplementalURL: URL) throws -> [String: String] {
    let doc: XMLDocument
    do {
        doc = try XMLDocument(contentsOf: supplementalURL)
    } catch {
        throw CLDRFileError.xmlParse(supplementalURL, error)
    }
    // Only the unnamed <parentLocales> block (no `component` attribute) applies
    // to general data, including list and date patterns. Other blocks scope to
    // collations / plurals / etc.
    let nodes = try doc.nodes(forXPath: "//parentLocales[not(@component)]/parentLocale")
    var map: [String: String] = [:]
    for case let elt as XMLElement in nodes {
        guard let parent = elt.attribute(forName: "parent")?.stringValue,
            let locales = elt.attribute(forName: "locales")?.stringValue
        else { continue }
        for child in locales.split(separator: " ") {
            map[String(child)] = parent
        }
    }
    return map
}

// Walk up the locale chain. Explicit parents win; otherwise strip the trailing
// subtag (en_AU → en, zh_Hant_HK → zh_Hant); single-tag locales other than
// root fall back to root.
func parent(of locale: String, explicit: [String: String]) -> String? {
    if locale == "root" { return nil }
    if let p = explicit[locale] { return p }
    if let u = locale.lastIndex(of: "_") {
        return String(locale[..<u])
    }
    return "root"
}
