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

// Reads CLDR XML and writes the date format JSON to standard output. The JSON has the localized Gregorian names, such as months and weekdays, and the GMT formats. The Swift date pattern formatter reads them. The tool resolves each value through inheritance for every locale.
//
// Resolution:
//   - Only the locales ICU builds are included (see icuLocales).
//   - A locale's parent is its <parentLocales> entry, else the locale with its
//     last subtag removed, else root. A parent that ICU makes an alias is
//     replaced by the alias's target, as ICU loads it.
//   - Values marked draft="unconfirmed" or "provisional" are skipped, as ICU's
//     data build skips them (cldr-to-icu's minimum draft status is
//     "contributed"). So are the ↑↑↑ and ∅∅∅ markers.
//   - `alt` values are skipped. ICU's date formatting reads none of them.
//   - When no locale in the chain has a name, root's width and context aliases
//     apply (e.g. stand-alone abbreviated months use the format ones), and the
//     search starts again from the original locale.
//
// Each group's resolved blocks are deduplicated, so locales with identical
// months, for example, share one block.

import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

// MARK: - Slots

let monthContexts = ["format", "stand-alone"]
let nameWidths = ["abbreviated", "narrow", "wide"]
let weekdayWidths = ["abbreviated", "narrow", "short", "wide"]
let weekdayTypes = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
let eraElements = ["abbreviated": "eraAbbr", "narrow": "eraNarrow", "wide": "eraNames"]
let dayPeriodTypes = ["am", "pm", "noon"]
/// The contextTransforms usages ICU's date formatting reads, in table order.
let capitalizationUsages = ["month-format-except-narrow", "month-standalone-except-narrow", "month-narrow",
                            "day-format-except-narrow", "day-standalone-except-narrow", "day-narrow",
                            "era-name", "era-abbr", "era-narrow", "date-other-beginning"]

/// Slot keys have the form "group|context|width|type".
func nameSlots(_ group: String) -> [String] {
    switch group {
    case "months":
        return monthContexts.flatMap { c in nameWidths.flatMap { w in (1...12).map { "months|\(c)|\(w)|\($0)" } } }
    case "weekdays":
        return monthContexts.flatMap { c in weekdayWidths.flatMap { w in weekdayTypes.map { "days|\(c)|\(w)|\($0)" } } }
    case "quarters":
        return monthContexts.flatMap { c in nameWidths.flatMap { w in (1...4).map { "quarters|\(c)|\(w)|\($0)" } } }
    case "eras":
        return nameWidths.flatMap { w in (0...1).map { "eras|format|\(w)|\($0)" } }
    case "dayPeriods":
        // ICU reads only the format context for AM/PM and noon.
        return nameWidths.flatMap { w in dayPeriodTypes.map { "dayPeriods|format|\(w)|\($0)" } }
    case "gmt":
        return ["gmt|||gmtFormat", "gmt|||hourFormat"]
    case "capitalization":
        return capitalizationUsages
    default:
        fatalError("unknown group \(group)")
    }
}

// MARK: - Parsing

struct LocaleValues {
    /// Slot key → value.
    var names: [String: String] = [:]
    /// "group|context|width" → "context|width" (root only).
    var aliases: [String: String] = [:]
    /// contextTransforms usage → whether to titlecase for UI lists and menus, then for standalone use, as "10".
    /// Nil where the locale has no contextTransforms; an empty table still hides its parent's, as in ICU.
    var contextTransforms: [String: String]?
}

func parseLocale(_ url: URL) throws -> LocaleValues {
    var values = LocaleValues()
    guard let ldml = try loadDocument(url).rootElement() else { return values }

    if let contextTransforms = ldml.child("contextTransforms") {
        var usages: [String: String] = [:]
        for usage in contextTransforms.children("contextTransformUsage") {
            guard let type = usage.attribute("type") else { continue }
            var flags: [Character] = ["0", "0"]
            var found = false
            for transform in usage.children("contextTransform") {
                guard let value = transform.usableValue else { continue }
                let index: Int
                switch transform.attribute("type") {
                case "uiListOrMenu": index = 0
                case "stand-alone": index = 1
                default: continue
                }
                flags[index] = value == "titlecase-firstword" ? "1" : "0"
                found = true
            }
            if found {
                usages[type] = String(flags)
            }
        }
        if !usages.isEmpty {
            values.contextTransforms = usages
        }
    }

    if let timeZoneNames = ldml.child("dates")?.child("timeZoneNames") {
        for element in ["gmtFormat", "hourFormat"] {
            if let value = timeZoneNames.children(element).lazy.compactMap(\.usableValue).first {
                values.names["gmt|||\(element)"] = value
            }
        }
    }

    guard let calendar = ldml.child("dates")?.child("calendars")?.child("calendar", type: "gregorian") else {
        return values
    }
    // group element → (context element, width element, leaf element)
    let groups: [(String, String, String, String)] = [
        ("months", "monthContext", "monthWidth", "month"),
        ("days", "dayContext", "dayWidth", "day"),
        ("quarters", "quarterContext", "quarterWidth", "quarter"),
        ("dayPeriods", "dayPeriodContext", "dayPeriodWidth", "dayPeriod"),
    ]
    for (group, contextTag, widthTag, leafTag) in groups {
        guard let groupElement = calendar.child(group) else { continue }
        for contextElement in groupElement.children(contextTag) {
            let context = contextElement.attribute("type") ?? ""
            for widthElement in contextElement.children(widthTag) {
                let width = widthElement.attribute("type") ?? ""
                if let alias = widthElement.child("alias"), let path = alias.attribute("path") {
                    values.aliases["\(group)|\(context)|\(width)"] = try aliasTarget(path, context: context, contextTag: contextTag, widthTag: widthTag, file: url)
                }
                for leaf in widthElement.children(leafTag) {
                    guard let value = leaf.usableValue, let type = leaf.attribute("type") else { continue }
                    values.names["\(group)|\(context)|\(width)|\(type)"] = value
                }
            }
        }
    }
    if let eras = calendar.child("eras") {
        for (width, tag) in eraElements {
            guard let element = eras.child(tag) else { continue }
            if let alias = element.child("alias"), let path = alias.attribute("path") {
                guard let target = eraElements.first(where: { path == "../\($0.value)" })?.key else {
                    fatalError("unhandled era alias \(path) in \(url.lastPathComponent)")
                }
                values.aliases["eras|format|\(width)"] = "format|\(target)"
            }
            for era in element.children("era") {
                if let value = era.usableValue, let type = era.attribute("type") {
                    values.names["eras|format|\(width)|\(type)"] = value
                }
            }
        }
    }
    return values
}

/// Parses a width alias such as `../monthWidth[@type='wide']` or
/// `../../monthContext[@type='format']/monthWidth[@type='abbreviated']` into "context|width".
func aliasTarget(_ path: String, context: String, contextTag: String, widthTag: String, file: URL) throws -> String {
    func quoted(_ s: Substring) -> String? {
        guard let open = s.range(of: "[@type='"), let close = s.range(of: "']", range: open.upperBound..<s.endIndex) else { return nil }
        return String(s[open.upperBound..<close.lowerBound])
    }
    let parts = path.split(separator: "/")
    if parts.count == 2, parts[0] == "..", parts[1].hasPrefix(widthTag), let width = quoted(parts[1]) {
        return "\(context)|\(width)"
    }
    if parts.count == 4, parts[0] == "..", parts[1] == "..", parts[2].hasPrefix(contextTag), parts[3].hasPrefix(widthTag),
       let targetContext = quoted(parts[2]), let width = quoted(parts[3]) {
        return "\(targetContext)|\(width)"
    }
    fatalError("unhandled alias \(path) in \(file.lastPathComponent)")
}

// MARK: - Day numerals

/// The text for days 1 through 31 in the algorithmic numbering system `id`, from its CLDR spellout rules.
func loadAlgorithmicDays(_ id: String, cldrURL: URL) throws -> [String] {
    let systemsURL = cldrURL.appendingPathComponent("common/supplemental/numberingSystems.xml")
    let systems = try XMLDocument(contentsOf: systemsURL)
    guard let system = try systems.nodes(forXPath: "//numberingSystem[@id='\(id)']").first as? XMLElement,
          let rulesPath = system.attribute("rules") else {
        fatalError("no rules for numbering system \(id)")
    }
    // For example "zh/SpelloutRules/spellout-numbering-days".
    let parts = rulesPath.split(separator: "/").map(String.init)
    precondition(parts.count == 3, "unexpected rules \(rulesPath)")
    let rbnfURL = cldrURL.appendingPathComponent("common/rbnf/\(parts[0]).xml")
    let document: XMLDocument
    do {
        document = try XMLDocument(contentsOf: rbnfURL)
    } catch {
        throw CLDRFileError.xmlParse(rbnfURL, error)
    }
    guard let text = try document.nodes(forXPath: "//rulesetGrouping[@type='\(parts[1])']/rbnfRules").first?.stringValue else {
        fatalError("no \(parts[1]) in \(rbnfURL.lastPathComponent)")
    }
    let rules = SpelloutRules(text)
    return (1...31).map { rules.format($0, ruleSet: "%" + parts[2]) }
}

/// Just enough of RBNF to format small positive integers: `=%set=`, `<<`, `>>`, `<%set<`, `>%set>`, and `[...]`.
struct SpelloutRules {
    /// Rule set name → (base value, rule text), in ascending order of base value.
    var ruleSets: [String: [(base: Int, text: String)]] = [:]

    init(_ text: String) {
        var current: String?
        for line in text.split(whereSeparator: \.isNewline).map({ $0.trimmingCharacters(in: .whitespaces) }) where !line.isEmpty {
            if line.hasPrefix("%") && line.hasSuffix(":") {
                current = String(line.dropLast())
                continue
            }
            guard let current, let colon = line.firstIndex(of: ":"), line.hasSuffix(";") else { continue }
            // Skip rules for negative numbers, fractions, and other special cases.
            guard let base = Int(line[..<colon]) else { continue }
            let body = line[line.index(after: colon)...].dropLast().trimmingCharacters(in: .whitespaces)
            ruleSets[current, default: []].append((base, body))
        }
    }

    func format(_ number: Int, ruleSet: String) -> String {
        guard let rules = ruleSets[ruleSet], let rule = rules.last(where: { $0.base <= number }) else {
            fatalError("no rule in \(ruleSet) for \(number)")
        }
        var divisor = 1
        while divisor * 10 <= rule.base { divisor *= 10 }
        let remainder = number % divisor

        var result = ""
        var text = Substring(rule.text)
        while let c = text.first {
            switch c {
            case "[":
                // Optional text, left out when the remainder is zero.
                guard let close = text.firstIndex(of: "]") else { fatalError("unclosed [ in \(rule.text)") }
                if remainder != 0 {
                    result += format(text: text[text.index(after: text.startIndex)..<close], number: number, divisor: divisor, ruleSet: ruleSet)
                }
                text = text[text.index(after: close)...]
            default:
                let end = text.firstIndex(of: "[") ?? text.endIndex
                result += format(text: text[..<end], number: number, divisor: divisor, ruleSet: ruleSet)
                text = text[end...]
            }
        }
        return result
    }

    private func format(text: Substring, number: Int, divisor: Int, ruleSet: String) -> String {
        var result = ""
        var text = text
        while let c = text.first {
            guard c == "=" || c == "<" || c == ">" else {
                result.append(c)
                text = text.dropFirst()
                continue
            }
            // A substitution: the token, an optional rule set name, and the token again.
            let body = text.dropFirst()
            guard let close = body.firstIndex(of: c) else { fatalError("unclosed \(c) in \(text)") }
            let name = body[..<close]
            precondition(name.isEmpty || name.hasPrefix("%"), "unsupported substitution \(c)\(name)\(c) in \(ruleSet)")
            let target = name.isEmpty ? ruleSet : String(name)
            switch c {
            case "=": result += format(number, ruleSet: target)
            case "<": result += format(number / divisor, ruleSet: target)
            default: result += format(number % divisor, ruleSet: target)
            }
            text = body[body.index(after: close)...]
            precondition(text.first != c, "unsupported \(c)\(c)\(c) in \(ruleSet)")
        }
        return result
    }
}

// MARK: - Resolution

struct Resolver {
    let locales: [String: LocaleValues]
    let chains: [String: [String]]
    let rootAliases: [String: String]

    init(locales: [String: LocaleValues], parents: [String: String]) {
        self.locales = locales
        chains = resolutionChains(locales: Set(locales.keys), parents: parents)
        self.rootAliases = locales["root"]?.aliases ?? [:]
    }

    func name(_ locale: String, _ slot: String) -> String? {
        var slot = slot
        for _ in 0..<8 {
            for l in chains[locale]! {
                if let value = locales[l]!.names[slot] { return value }
            }
            let parts = slot.split(separator: "|", omittingEmptySubsequences: false)
            guard let target = rootAliases["\(parts[0])|\(parts[1])|\(parts[2])"] else { return nil }
            slot = "\(parts[0])|\(target)|\(parts[3])"
        }
        return nil
    }

    /// As ICU reads contextTransforms: the whole table from the nearest locale that has one.
    func capitalization(_ locale: String, _ usage: String) -> String? {
        let table = chains[locale]!.lazy.compactMap { self.locales[$0]!.contextTransforms }.first
        guard let flags = table?[usage], flags != "00" else { return nil }
        return flags
    }

}

// MARK: - Driver

@main
struct GenerateDateFormatData {
    static func main() throws {
        guard let cldrPath = ProcessInfo.processInfo.environment["CLDR_PATH"] else {
            print("error: CLDR_PATH is not set", to: &standardError)
            exit(1)
        }
        let cldrURL = URL(fileURLWithPath: cldrPath, isDirectory: true)
        let supplementalURL = cldrURL.appendingPathComponent("common/supplemental", isDirectory: true)

        print("  loading supplemental data…", to: &standardError)
        let parents = try loadParentMap(supplementalURL: supplementalURL.appendingPathComponent("supplementalData.xml"))
        let likelySubtags = try loadLikelySubtags(supplementalURL: supplementalURL.appendingPathComponent("likelySubtags.xml"))

        print("  parsing locale files…", to: &standardError)
        let (files, localesWithoutData) = try loadICULocaleFiles(cldrURL: cldrURL, parents: parents, likelySubtags: likelySubtags)
        var locales: [String: LocaleValues] = [:]
        for (locale, url) in files {
            locales[locale] = try parseLocale(url)
        }
        for locale in localesWithoutData {
            locales[locale] = LocaleValues()
        }
        for (locale, values) in locales where locale != "root" && !values.aliases.isEmpty {
            fatalError("unexpected Gregorian alias in \(locale)")
        }

        print("  resolving \(locales.count) locales…", to: &standardError)
        let resolver = Resolver(locales: locales, parents: parents)
        let sortedLocales = locales.keys.sorted()

        var groupSlots: [String: [String]] = [:]
        var groupBlocks: [String: [[String?]]] = [:]
        var localeBlocks: [String: [String: Int]] = [:]
        for group in dateFormatGroups {
            let slots = nameSlots(group)
            groupSlots[group] = slots
            var table = BlockTable()
            for locale in sortedLocales {
                let block: [String?]
                if group == "capitalization" {
                    block = slots.map { resolver.capitalization(locale, $0) }
                } else {
                    block = slots.map { resolver.name(locale, $0) }
                }
                localeBlocks[locale, default: [:]][group] = table.index(of: block)
            }
            groupBlocks[group] = table.blocks
            print("  \(group): \(slots.count) slots, \(table.blocks.count) distinct blocks", to: &standardError)
        }

        // Known values, to catch a resolver that reads the data wrongly.
        func check(_ locale: String, _ group: String, _ slot: String, _ expected: String?) {
            let block = groupBlocks[group]![localeBlocks[locale]![group]!]
            let actual = block[groupSlots[group]!.firstIndex(of: slot)!]
            precondition(actual == expected, "\(locale) \(slot): expected \(expected ?? "nil"), got \(actual ?? "nil")")
        }
        check("en", "months", "months|format|abbreviated|9", "Sep")
        check("en", "months", "months|stand-alone|narrow|9", "S")
        check("de", "weekdays", "days|format|abbreviated|thu", "Do.")
        check("de_AT", "months", "months|format|wide|1", "Jänner")
        check("cs", "capitalization", "month-standalone-except-narrow", "10")
        check("fr", "capitalization", "month-format-except-narrow", "01")
        check("pt", "capitalization", "day-format-except-narrow", "11")
        // Only some CLDR sources have this usage, so expect it where the source has it.
        let vi = (try? String(contentsOf: cldrURL.appendingPathComponent("common/main/vi.xml"), encoding: .utf8)) ?? ""
        check("vi", "capitalization", "date-other-beginning", vi.contains(#"<contextTransformUsage type="date-other-beginning">"#) ? "11" : nil)
        precondition(groupBlocks["capitalization"]![localeBlocks["pt_PT"]!["capitalization"]!].allSatisfy { $0 == nil }, "pt_PT should hide pt's contextTransforms")

        let hanidays = try loadAlgorithmicDays("hanidays", cldrURL: cldrURL)
        for (day, expected) in [1: "初一", 10: "初十", 15: "十五", 20: "二十", 21: "廿一", 30: "三十", 31: "丗一"] {
            precondition(hanidays[day - 1] == expected, "hanidays \(day): expected \(expected), got \(hanidays[day - 1])")
        }

        let schema = DateFormatDataSchema(
            generatedFrom: "CLDR \(detectCLDRVersion(cldrURL))",
            cldrVersion: detectCLDRVersion(cldrURL),
            hanidaysDays: hanidays,
            groupSlots: groupSlots,
            groupBlocks: groupBlocks,
            locales: localeBlocks,
            parents: parents,
            aliases: localeAliases,
            defaultScripts: defaultScripts(likelySubtags: likelySubtags)
        )
        try writeJSON(schema)
    }
}
