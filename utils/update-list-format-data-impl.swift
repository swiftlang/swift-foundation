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

// Swift script that reads CLDR XML and emits a JSON file containing
// list-formatting pattern tables for ListFormatStyle. Invoked by the
// update-list-format-data shell wrapper, which sets up CLDR_PATH and prepends
// the license/auto-generated header.
//
// Pipeline:
//   1. Parse common/supplemental/supplementalData.xml into a parent-locale map.
//   2. Walk common/main, extracting <listPatterns> for each locale .xml file.
//   3. Resolve in-file <alias source="locale" .../> redirects (transitive).
//   4. For each (locale, type, width) slot, resolve missing parts and ↑↑↑
//      markers by walking the parent chain to root.
//   5. Dedupe per-slot — many locales share resolved patterns.
//   6. Emit only the (locale, slot) entries whose resolved row differs from
//      the locale's parent's row; runtime recovers the rest by walking the
//      parent chain. The explicit parent map ships with the data.
//   7. Self-check: simulate the runtime lookup against the sparse output and
//      assert every (locale, slot) still resolves to the original row.
//   8. Globally intern pattern strings and (start, middle, end, pair) row
//      tuples across all slots (further dedup). Emit as JSON via the schema
//      defined in list-format-data-schema.swift.
//
// Contextual rules (Spanish y→e, o→u; Hebrew ו prefix; Thai joiner) are NOT
// tagged in the data. They're a function of (locale.language, type, pattern),
// so the formatter computes them at format time. This keeps the data deduped
// against the actual patterns and avoids splitting the rule definition across
// the generator and the runtime predicates.

import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

// MARK: - Constants

let indent = "    "
let inheritMarker = "\u{2191}\u{2191}\u{2191}"
let partNames = ["start", "middle", "end", "2"]

// (CLDR <listPattern type="..."> attribute, our type name, our width name)
// A missing type attribute in CLDR means "standard".
// Note: CLDR also defines "unit" list patterns (for lists of measurement
// units), but they aren't reachable through the public ListFormatStyle API
// (ListType is only .and/.or), so we don't extract them — keeping the shipped
// data smaller.
let slots: [(cldrType: String, type: String, width: String)] = [
    ("standard",        "and",  "wide"),
    ("standard-short",  "and",  "short"),
    ("standard-narrow", "and",  "narrow"),
    ("or",              "or",   "wide"),
    ("or-short",        "or",   "short"),
    ("or-narrow",       "or",   "narrow"),
]

// Locale aliases: deprecated or under-specified identifiers → the canonical
// identifier whose list patterns they should resolve to. This mirrors the
// per-locale %%ALIAS redirects ICU ships in icu4c/source/data/locales/*.txt so
// the runtime resolves the same patterns ICU would. It matters because the
// requested Locale.identifier can arrive minimized (e.g. zh_Hant_HK canonicalizes
// to zh_HK) or as a deprecated code (iw, in, sh), which the plain parent-chain
// walk would otherwise fall back to the wrong data for (zh_HK → zh → "和" instead
// of zh_Hant → "及").
//
// This is a curated snapshot rather than a value computed from the CLDR XML: the
// set of aliased identifiers is ICU's, not CLDR's. ICU derives it in
// tools/cldr-to-icu LdmlConverter.getAliasMap(config.getTargetLocaleIds(dir)),
// which enumerates the curated <localeIds> list in cldr-to-icu/config.xml and,
// per id, emits an alias when either:
//   1. replaceDeprecatedTags changes the id (deprecated language/territory
//      subtags from common/supplemental/supplementalMetadata.xml, e.g. iw→he,
//      sh→sr_Latn, CS→RS), or
//   2. the id has no data of its own and maximize adds a likely script
//      (common/supplemental/likelySubtags.xml, e.g. az_AZ→az_Latn_AZ,
//      zh_HK→zh_Hant_HK).
// Three entries below (ars, no_NO, no_NO_NY) are ICU <forcedAlias> config
// entries with no CLDR derivation. These mappings have been stable across CLDR
// releases; the <localeIds> list grows by only a handful of ids per release.
//
// To refresh at a CLDR/ICU upgrade: re-extract the %%ALIAS values from a matching
// icu4c/source/data/locales/*.txt checkout (each aliased locale's .txt file is a
// single line `xx{ "%%ALIAS"{"yy"} }`), or re-run ICU's LdmlConverter over the
// config's <localeIds>. Only the sources reachable through the public
// ListFormatStyle surface (list patterns) need to appear here.
//
// This is the full curated record. The generator emits only the subset that the
// current CLDR data doesn't already resolve correctly by plain truncation (see
// trimRedundantAliases), so the shipped JSON is smaller.
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
    "ks_IN": "ks_Arab_IN",
    "ku_SY": "ku_Latn_SY",
    "kxv_IN": "kxv_Latn_IN",
    "mni_IN": "mni_Beng_IN",
    "mo": "ro",
    "no_NO": "no",
    "no_NO_NY": "nn_NO",
    "pa_IN": "pa_Guru_IN",
    "pa_PK": "pa_Arab_PK",
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
    "uz_AF": "uz_Arab_AF",
    "uz_UZ": "uz_Latn_UZ",
    "vai_LR": "vai_Vaii_LR",
    "yue_CN": "yue_Hans_CN",
    "yue_HK": "yue_Hant_HK",
    "zh_CN": "zh_Hans_CN",
    "zh_HK": "zh_Hant_HK",
    "zh_MO": "zh_Hant_MO",
    "zh_SG": "zh_Hans_SG",
    "zh_TW": "zh_Hant_TW",
]

// MARK: - Errors

enum GenerationError: Error, CustomStringConvertible {
    case missingEnvVar(String)
    case missingDirectory(URL)
    case xmlParse(URL, Error)

    var description: String {
        switch self {
        case .missingEnvVar(let name): return "missing environment variable \(name)"
        case .missingDirectory(let url): return "missing directory \(url.path)"
        case .xmlParse(let url, let error): return "failed to parse \(url.lastPathComponent): \(error)"
        }
    }
}

// MARK: - Parent map

func loadParentMap(supplementalURL: URL) throws -> [String: String] {
    let doc: XMLDocument
    do {
        doc = try XMLDocument(contentsOf: supplementalURL)
    } catch {
        throw GenerationError.xmlParse(supplementalURL, error)
    }
    // Only the unnamed <parentLocales> block (no `component` attribute) applies
    // to general data, including list patterns. Other blocks scope to
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

// MARK: - Per-locale extraction

// In-file representation: for each CLDR pattern type, either the four parts
// (some possibly nil = inherit) or an alias-to-another-type.
struct LocaleData {
    var parts: [String: [String: String]] = [:]   // cldrType -> partName -> text (non-inherit)
    var inherits: [String: Set<String>] = [:]     // cldrType -> set of partNames that inherit
    var aliases: [String: String] = [:]           // cldrType -> alias target cldrType
}

// Parse an alias path like "../listPattern" or "../listPattern[@type='or-short']".
// Returns the target type name ("standard" if no [@type=...] predicate).
func aliasTarget(path: String) -> String? {
    guard path.hasPrefix("../listPattern") else { return nil }
    let suffix = path.dropFirst("../listPattern".count)
    if suffix.isEmpty { return "standard" }
    // Expect "[@type='X']"
    let prefix = "[@type='"
    let postfix = "']"
    guard suffix.hasPrefix(prefix), suffix.hasSuffix(postfix) else { return nil }
    return String(suffix.dropFirst(prefix.count).dropLast(postfix.count))
}

func parseLocaleFile(at url: URL) throws -> LocaleData {
    let doc: XMLDocument
    do {
        doc = try XMLDocument(contentsOf: url)
    } catch {
        throw GenerationError.xmlParse(url, error)
    }
    var data = LocaleData()
    let patterns = try doc.nodes(forXPath: "//ldml/listPatterns/listPattern")
    for case let p as XMLElement in patterns {
        let cldrType = p.attribute(forName: "type")?.stringValue ?? "standard"

        if let alias = p.elements(forName: "alias").first,
            let path = alias.attribute(forName: "path")?.stringValue,
            let target = aliasTarget(path: path)
        {
            data.aliases[cldrType] = target
            continue
        }

        var present: [String: String] = [:]
        var inherits = Set<String>()
        for partName in partNames {
            // CLDR ensures listPatternPart type values are unique within a parent,
            // so we don't need to disambiguate further.
            let part = p.elements(forName: "listPatternPart").first {
                $0.attribute(forName: "type")?.stringValue == partName
            }
            guard let text = part?.stringValue else {
                inherits.insert(partName)
                continue
            }
            if text == inheritMarker {
                inherits.insert(partName)
            } else {
                present[partName] = text
            }
        }
        data.parts[cldrType] = present
        data.inherits[cldrType] = inherits
    }
    return data
}

// MARK: - Inheritance walk

// Resolve a single (locale, cldrType, part). Walks the locale chain looking
// for the type; when a locale defines the type as an alias to another type,
// switches to that target type and restarts the walk from `locale` — matching
// ICU's `loadListFormatInternal` algorithm in icu4c/source/i18n/listformatter.cpp.
//
// This interleaving of alias resolution and locale fallback is what makes
// `es or-narrow` resolve to `es::or` ("{0} o {1}") rather than `root::or`
// ("{0}, or {1}"): or-narrow → or-short → or aliases redirect the lookup,
// and locale fallback for the final type "or" finds es first.
func resolve(
    part partName: String,
    in cldrType: String,
    for locale: String,
    data: [String: LocaleData],
    parentMap: [String: String]
) -> String? {
    var currentType = cldrType
    var seen = Set<String>()
    while !seen.contains(currentType) {
        seen.insert(currentType)
        var current: String? = locale
        var foundAlias: String? = nil
        while let l = current {
            if let text = data[l]?.parts[currentType]?[partName] {
                return text
            }
            if let target = data[l]?.aliases[currentType] {
                foundAlias = target
                break
            }
            current = parent(of: l, explicit: parentMap)
        }
        guard let target = foundAlias else { return nil }
        currentType = target
    }
    return nil
}

// MARK: - Resolved row

struct Row: Hashable {
    let start: String
    let middle: String
    let end: String
    let pair: String
}

// MARK: - Driver

func generate() throws -> String {
    guard let cldrPath = ProcessInfo.processInfo.environment["CLDR_PATH"] else {
        throw GenerationError.missingEnvVar("CLDR_PATH")
    }
    let cldrURL = URL(fileURLWithPath: cldrPath, isDirectory: true)
    let mainURL = cldrURL.appendingPathComponent("common/main", isDirectory: true)
    let supplementalURL = cldrURL.appendingPathComponent("common/supplemental/supplementalData.xml")

    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: mainURL.path, isDirectory: &isDir), isDir.boolValue else {
        throw GenerationError.missingDirectory(mainURL)
    }

    print("  loading parent map…", to: &standardError)
    let parentMap = try loadParentMap(supplementalURL: supplementalURL)

    print("  scanning locale files…", to: &standardError)
    let xmlFiles = try FileManager.default.contentsOfDirectory(
        at: mainURL,
        includingPropertiesForKeys: nil
    )
    .filter { $0.pathExtension == "xml" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

    var allLocales: [String] = []
    var data: [String: LocaleData] = [:]
    for file in xmlFiles {
        let locale = file.deletingPathExtension().lastPathComponent
        allLocales.append(locale)
        // Cheap pre-filter: most files have no <listPatterns> block.
        // Parsing every CLDR file via XMLDocument is slow; skip when possible.
        guard let s = try? String(contentsOf: file, encoding: .utf8),
            s.contains("<listPatterns>")
        else {
            data[locale] = LocaleData()
            continue
        }
        let ld = try parseLocaleFile(at: file)
        data[locale] = ld
    }

    print("  resolving \(allLocales.count) locales × \(slots.count) slots…", to: &standardError)

    // For each slot, build [locale: Row].
    var slotTables: [(type: String, width: String, table: [String: Row])] = []
    for slot in slots {
        var table: [String: Row] = [:]
        for locale in allLocales {
            guard
                let start  = resolve(part: "start",  in: slot.cldrType, for: locale, data: data, parentMap: parentMap),
                let middle = resolve(part: "middle", in: slot.cldrType, for: locale, data: data, parentMap: parentMap),
                let end    = resolve(part: "end",    in: slot.cldrType, for: locale, data: data, parentMap: parentMap),
                let pair   = resolve(part: "2",      in: slot.cldrType, for: locale, data: data, parentMap: parentMap)
            else {
                // root must define every slot. If we ever hit this, root's data is
                // incomplete for this CLDR type and we should know.
                print("  warning: \(locale) \(slot.cldrType) unresolved", to: &standardError)
                continue
            }
            table[locale] = Row(start: start, middle: middle, end: end, pair: pair)
        }
        slotTables.append((slot.type, slot.width, table))
    }

    print("  emitting JSON…", to: &standardError)
    var simplifiedParentMap = parentMap
    simplifyParentMap(&simplifiedParentMap, slotTables: slotTables)
    let neededAliases = trimRedundantAliases(localeAliases, slotTables: slotTables, parentMap: simplifiedParentMap)
    print("  aliases: \(localeAliases.count) → \(neededAliases.count) entries (dropped redundant)", to: &standardError)
    return emit(
        slotTables: slotTables,
        parentMap: simplifiedParentMap,
        aliases: neededAliases,
        cldrVersion: detectCLDRVersion(cldrURL: cldrURL)
    )
}

// Best-effort CLDR version sniff. Tries supplementalData.xml first (the
// canonical place for tagged releases) and falls back to pom.xml's <version>
// element (used by working trees where supplementalData.xml carries
// "$Revision$" placeholders).
func detectCLDRVersion(cldrURL: URL) -> String {
    let supplementalURL = cldrURL.appendingPathComponent("common/supplemental/supplementalData.xml")
    if let doc = try? XMLDocument(contentsOf: supplementalURL),
        let nodes = try? doc.nodes(forXPath: "//supplementalData/version")
    {
        for case let elt as XMLElement in nodes {
            if let v = elt.attribute(forName: "cldrVersion")?.stringValue, !v.contains("$") {
                return v
            }
            if let v = elt.attribute(forName: "number")?.stringValue, !v.contains("$") {
                return v
            }
        }
    }
    let pomURL = cldrURL.appendingPathComponent("pom.xml")
    if let doc = try? XMLDocument(contentsOf: pomURL) {
        // pom uses default namespace; raw element lookup avoids namespace dance.
        if let root = doc.rootElement(),
            let version = root.elements(forName: "version").first?.stringValue,
            !version.isEmpty
        {
            return version
        }
    }
    return "unknown"
}

// MARK: - Emission

func swiftStringLiteral(_ s: String) -> String {
    var out = "\""
    for scalar in s.unicodeScalars {
        switch scalar {
        case "\\": out += "\\\\"
        case "\"": out += "\\\""
        case "\n": out += "\\n"
        case "\r": out += "\\r"
        case "\t": out += "\\t"
        default:
            if shouldEscape(scalar) {
                out += String(format: "\\u{%X}", scalar.value)
            } else {
                out += String(scalar)
            }
        }
    }
    out += "\""
    return out
}

// Escape characters that don't render as visible glyphs in source — control
// codes, bidi/format marks, zero-width characters, and non-ASCII whitespace.
// Without this, CLDR's invisible chars (NBSP, RLM, ZWSP, etc.) would land in
// the generated file looking like normal spaces or nothing at all, which
// makes the data unreviewable.
private func shouldEscape(_ scalar: Unicode.Scalar) -> Bool {
    if scalar.value < 0x20 || scalar.value == 0x7F { return true }
    switch scalar.properties.generalCategory {
    case .control, .format, .surrogate, .privateUse, .unassigned:
        return true
    case .lineSeparator, .paragraphSeparator:
        return true
    case .spaceSeparator:
        return scalar.value != 0x20 // ASCII space is fine; NBSP/narrow-NBSP/etc. are not
    default:
        return false
    }
}

// Mirror of the runtime fallback walk. Must match the algorithm in
// ListFormatPatterns.swift exactly, or sparse data lookups will diverge.
func lookup(_ locale: String, in index: [String: UInt8], parentMap: [String: String]) -> UInt8? {
    var current: String? = locale
    while let l = current {
        if let v = index[l] { return v }
        current = parent(of: l, explicit: parentMap)
    }
    return nil
}

// Per-slot output used by both the parent-map simplifier and the emitter.
struct SlotEmission {
    let type: String
    let width: String
    let uniqueRows: [Row]
    let rowIndex: [Row: Int]
    let sparseIndex: [String: Int] // omits entries equal to the parent's row
}

func buildSlotEmissions(
    _ slotTables: [(type: String, width: String, table: [String: Row])],
    parentMap: [String: String]
) -> [SlotEmission] {
    var result: [SlotEmission] = []
    for slot in slotTables {
        // Dedupe rows, sorted by content so output is byte-identical across runs.
        let uniqueRows = Array(Set(slot.table.values)).sorted { a, b in
            let ka = "\(a.start)\u{1}\(a.middle)\u{1}\(a.end)\u{1}\(a.pair)"
            let kb = "\(b.start)\u{1}\(b.middle)\u{1}\(b.end)\u{1}\(b.pair)"
            return ka < kb
        }
        var rowIndex: [Row: Int] = [:]
        for (i, row) in uniqueRows.enumerated() { rowIndex[row] = i }

        // For each locale, emit only if its resolved row differs from what the
        // runtime walk through `parentMap` would find. Root is always emitted
        // (it's the bottom of the fallback chain).
        var sparseIndex: [String: Int] = [:]
        for (locale, row) in slot.table {
            if locale == "root" {
                sparseIndex[locale] = rowIndex[row]!
                continue
            }
            var ancestorRow: Row? = nil
            var current = parent(of: locale, explicit: parentMap)
            while let p = current {
                if let r = slot.table[p] { ancestorRow = r; break }
                current = parent(of: p, explicit: parentMap)
            }
            if ancestorRow != row {
                sparseIndex[locale] = rowIndex[row]!
            }
        }
        result.append(
            SlotEmission(
                type: slot.type,
                width: slot.width,
                uniqueRows: uniqueRows,
                rowIndex: rowIndex,
                sparseIndex: sparseIndex
            )
        )
    }
    return result
}

// Greedily remove parent-map entries that don't grow the total emitted size.
// Each removal may enable later removals, so we iterate to a fixed point.
// Most candidates fall in the first pass; a second pass typically clears a few.
// The sparse-index construction guarantees lookup correctness by design, so
// we only need to compare sizes.
func simplifyParentMap(
    _ parentMap: inout [String: String],
    slotTables: [(type: String, width: String, table: [String: Row])]
) {
    func totalSize(_ emissions: [SlotEmission], _ map: [String: String]) -> Int {
        emissions.reduce(0) { $0 + $1.sparseIndex.count } + map.count
    }
    var emissions = buildSlotEmissions(slotTables, parentMap: parentMap)
    var currentSize = totalSize(emissions, parentMap)
    let originalParentCount = parentMap.count
    var passes = 0
    var changed = true
    while changed {
        changed = false
        passes += 1
        for c in parentMap.keys.sorted() {
            guard let original = parentMap[c] else { continue }
            parentMap[c] = nil
            let trial = buildSlotEmissions(slotTables, parentMap: parentMap)
            let trialSize = totalSize(trial, parentMap)
            if trialSize <= currentSize {
                emissions = trial
                currentSize = trialSize
                changed = true
            } else {
                parentMap[c] = original
            }
        }
    }
    print(
        "  parent map: \(originalParentCount) → \(parentMap.count) entries (\(passes) pass(es))",
        to: &standardError
    )
    _ = emissions // silenced; emit() recomputes from the simplified parentMap
}

// Drop aliases that the plain fallback walk (truncation only, no alias redirect)
// already resolves to the same patterns the alias would. Such an alias is
// redundant *for list formatting*: e.g. zh_TW → zh_Hant_TW changes nothing,
// because zh_Hant's list patterns match zh's (only zh_HK/zh_MO carry a distinct
// connector), and az_AZ → az_Latn_AZ changes nothing because Latin is az's
// default script.
//
// Redundancy is a property of the current CLDR data, so this is recomputed on
// every regeneration: if a future CLDR gives an aliased script its own list
// patterns, the alias stops being redundant and is kept automatically. Dropping
// a redundant alias is safe for alias chains too — by definition it doesn't
// change its own source's resolution, so it can't change any alias that
// redirects through it.
func trimRedundantAliases(
    _ aliases: [String: String],
    slotTables: [(type: String, width: String, table: [String: Row])],
    parentMap: [String: String]
) -> [String: String] {
    // Resolve a locale to its row in one slot table by walking the fallback
    // chain (explicit redirect first, then truncation, then root), mirroring the
    // runtime. root is present in every table, so this always terminates in a row.
    func resolveRow(_ locale: String, _ table: [String: Row], _ explicit: [String: String]) -> Row? {
        var current: String? = locale
        while let l = current {
            if let r = table[l] { return r }
            current = parent(of: l, explicit: explicit)
        }
        return nil
    }
    let withAliases = parentMap.merging(aliases) { _, alias in alias }
    var needed: [String: String] = [:]
    for (source, target) in aliases {
        for slot in slotTables {
            let aliased = resolveRow(source, slot.table, withAliases)
            let plain = resolveRow(source, slot.table, parentMap)
            if aliased != plain {
                needed[source] = target
                break
            }
        }
    }
    return needed
}

func emit(
    slotTables: [(type: String, width: String, table: [String: Row])],
    parentMap: [String: String],
    aliases: [String: String],
    cldrVersion: String
) -> String {
    let emissions = buildSlotEmissions(slotTables, parentMap: parentMap)

    // Self-check: simulate the runtime parent-walk against the sparse output
    // and confirm every (locale, slot) still resolves to the original row.
    // Sparse construction guarantees this by design; the assertion catches any
    // future generator bug that violates the invariant.
    for (i, slot) in slotTables.enumerated() {
        let emission = emissions[i]
        let runtimeIndex = emission.sparseIndex.mapValues { UInt8($0) }
        for (locale, expectedRow) in slot.table {
            guard let idx = lookup(locale, in: runtimeIndex, parentMap: parentMap),
                emission.uniqueRows[Int(idx)] == expectedRow
            else {
                fatalError("sparse-lookup mismatch for \(locale) in \(slot.type)/\(slot.width)")
            }
        }
    }

    // Global pattern interning: each unique pattern string lives in the pool
    // once, regardless of how many rows reference it.
    var patternIndex: [String: Int] = [:]
    var patterns: [String] = []
    func internPattern(_ s: String) -> Int {
        if let i = patternIndex[s] { return i }
        let i = patterns.count
        patternIndex[s] = i
        patterns.append(s)
        return i
    }

    // Global row interning: a (start, middle, end, pair) tuple of pattern
    // indexes lives in the pool once, regardless of how many slots reference it.
    var rowIndex: [ListFormatDataSchema.Row: Int] = [:]
    var rowTable: [ListFormatDataSchema.Row] = []
    func internRow(_ r: Row) -> Int {
        let packed = ListFormatDataSchema.Row(
            start: internPattern(r.start),
            middle: internPattern(r.middle),
            end: internPattern(r.end),
            pair: internPattern(r.pair)
        )
        if let i = rowIndex[packed] { return i }
        let i = rowTable.count
        rowIndex[packed] = i
        rowTable.append(packed)
        return i
    }

    // Build slot maps using global row indexes. Iterate locales in sorted order
    // so pattern/row interning (and thus the pool ordering) is stable across
    // runs — dictionary iteration order is otherwise randomized per process.
    var slots: [String: [String: Int]] = [:]
    for (i, slot) in slotTables.enumerated() {
        let emission = emissions[i]
        var map: [String: Int] = [:]
        for locale in emission.sparseIndex.keys.sorted() {
            let localRowIdx = emission.sparseIndex[locale]!
            let row = emission.uniqueRows[localRowIdx]
            map[locale] = internRow(row)
        }
        slots["\(slot.type)_\(slot.width)"] = map
    }

    let payload = ListFormatDataSchema(
        generatedFrom: "CLDR \(cldrVersion)",
        cldrVersion: cldrVersion,
        patterns: patterns,
        rows: rowTable,
        slots: slots,
        parents: parentMap,
        aliases: aliases
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.keyEncodingStrategy = .convertToSnakeCase
    let bytes = try! encoder.encode(payload)
    return String(data: bytes, encoding: .utf8)!
}

// MARK: - Entry

@main
struct GenerateListFormatData {
    static func main() {
        do {
            let code = try generate()
            print(code, terminator: "")
        } catch {
            print("error: \(error)", to: &standardError)
            exit(1)
        }
    }
}
