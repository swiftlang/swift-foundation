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

// Reads CLDR XML and writes the locale number JSON to standard output. The JSON has each locale's numbering systems and each numbering system's minus sign. The tool resolves each value through inheritance for every locale.
//
// Resolution:
//   - Include only the locales that icuLocales returns.
//   - Take a locale's parent from its <parentLocales> entry, else remove the last subtag, else use root. Where the parent is an alias, use the alias's target.
//   - Skip values marked draft="unconfirmed" or "provisional", the ↑↑↑ and ∅∅∅ markers, and `alt` values.
//   - Resolve numbers=traditional to the native system where the locale has no traditional system. Resolve native and finance to the default system where the locale has none.
//   - For a numbering system's symbol, take the value from the nearest locale that has one. Use the Latin value where no locale has one, or where a nearer locale makes the system's symbols an alias to the Latin ones.
//
// Each numbering system whose values differ from the Latin ones for some locale gets its own sub-block. The other systems use the Latin values for every locale, so they share the Latin sub-block.

import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

let otherNumberingSystemTypes = ["native", "traditional", "finance"]

/// The value of each symbol where no locale in the chain has one. Without a value, the runtime writes nothing, such as no sign before a negative number.
let symbolDefaults = ["minusSign": "-"]

// MARK: - Parsing

struct LocaleValues {
    var defaultNumberingSystem: String?
    var otherNumberingSystems: [String: String] = [:]
    /// Maps numbering system → symbol element → value, such as "latn" → "minusSign" → "-".
    var symbols: [String: [String: String]] = [:]
    var latinSymbolAliases: Set<String> = []
}

func parseLocale(_ url: URL) throws -> LocaleValues {
    var values = LocaleValues()
    guard let numbers = try loadDocument(url).rootElement()?.child("numbers") else { return values }
    values.defaultNumberingSystem = numbers.children("defaultNumberingSystem").lazy.compactMap(\.usableValue).first
    if let others = numbers.child("otherNumberingSystems") {
        for type in otherNumberingSystemTypes {
            if let value = others.children(type).lazy.compactMap(\.usableValue).first {
                values.otherNumberingSystems[type] = value
            }
        }
    }
    for symbols in numbers.children("symbols") where symbols.attribute("alt") == nil {
        let system = symbols.attribute("numberSystem") ?? "latn"
        if let alias = symbols.child("alias") {
            guard alias.attribute("path") == "../symbols[@numberSystem='latn']" else {
                fatalError("unhandled symbols alias \(alias.attribute("path") ?? "") in \(url.lastPathComponent)")
            }
            values.latinSymbolAliases.insert(system)
        }
        for element in symbolFields {
            if let value = symbols.children(element).lazy.compactMap(\.usableValue).first {
                values.symbols[system, default: [:]][element] = value
            }
        }
    }
    return values
}

func loadNumberingSystems(_ url: URL) throws -> [String: [String]] {
    var systems: [String: [String]] = [:]
    for case let element as XMLElement in try loadDocument(url).nodes(forXPath: "//numberingSystems/numberingSystem[@type='numeric']") {
        guard let id = element.attribute("id"), let digits = element.attribute("digits") else { continue }
        let scalars = digits.unicodeScalars.map { String($0) }
        precondition(scalars.count == 10, "numbering system \(id) doesn't have 10 digits")
        systems[id] = scalars
    }
    return systems
}

/// Returns the regions that are valid in an `rg` keyword: the first two letters of each whole-region subdivision, such as uszzzz.
func loadValidRegions(_ url: URL) throws -> [String] {
    guard let element = try loadDocument(url).nodes(forXPath: "//idValidity/id[@type='subdivision'][@idStatus='unknown']").first else {
        fatalError("no unknown subdivisions in \(url.path)")
    }
    // Read only the text nodes, because `stringValue` includes the item-count comment.
    let ids = (element.children ?? []).filter { $0.kind == .text }.compactMap(\.stringValue).joined(separator: " ")
    return Set(ids.split(whereSeparator: \.isWhitespace).map { $0.prefix(2).uppercased() }).sorted()
}

// MARK: - Resolution

struct Resolver {
    let locales: [String: LocaleValues]
    let chains: [String: [String]]

    init(locales: [String: LocaleValues], parents: [String: String]) {
        self.locales = locales
        chains = resolutionChains(locales: Set(locales.keys), parents: parents)
    }

    func defaultNumberingSystem(_ locale: String) -> String {
        chains[locale]!.lazy.compactMap { locales[$0]!.defaultNumberingSystem }.first ?? "latn"
    }

    /// Returns the system for numbers=native, traditional, or finance. Traditional falls back to native, and the others fall back to the default system.
    func otherNumberingSystem(_ locale: String, _ type: String) -> String {
        if let value = chains[locale]!.lazy.compactMap({ self.locales[$0]!.otherNumberingSystems[type] }).first {
            return value
        }
        return type == "traditional" ? otherNumberingSystem(locale, "native") : defaultNumberingSystem(locale)
    }

    func symbols(_ locale: String, _ system: String) -> [String?] {
        symbolFields.map { element in
            guard let fallback = symbolDefaults[element] else { preconditionFailure("symbolDefaults has no value for \(element)") }
            return value(locale, system, aliases: \.latinSymbolAliases) { $0.symbols[$1]?[element] } ?? fallback
        }
    }

    private func value(_ locale: String, _ system: String, aliases: KeyPath<LocaleValues, Set<String>>, _ read: (LocaleValues, String) -> String?) -> String? {
        if system != "latn" {
            for l in chains[locale]! {
                if locales[l]![keyPath: aliases].contains(system) { break }
                if let value = read(locales[l]!, system) { return value }
            }
        }
        for l in chains[locale]! {
            if let value = read(locales[l]!, "latn") { return value }
        }
        return nil
    }
}

// MARK: - Driver

@main
struct GenerateLocaleNumberData {
    static func main() throws {
        guard let cldrPath = ProcessInfo.processInfo.environment["CLDR_PATH"] else {
            print("error: CLDR_PATH is not set", to: &standardError)
            exit(1)
        }
        let cldrURL = URL(fileURLWithPath: cldrPath, isDirectory: true)
        let supplementalURL = cldrURL.appendingPathComponent("common/supplemental", isDirectory: true)

        print("  loading supplemental data…", to: &standardError)
        let parents = try loadParentMap(supplementalURL: supplementalURL.appendingPathComponent("supplementalData.xml"))
        let numberingSystems = try loadNumberingSystems(supplementalURL.appendingPathComponent("numberingSystems.xml"))
        let likelySubtags = try loadLikelySubtags(supplementalURL: supplementalURL.appendingPathComponent("likelySubtags.xml"))
        let validRegions = try loadValidRegions(cldrURL.appendingPathComponent("common/validity/subdivision.xml"))
        precondition(validRegions.contains("US") && validRegions.contains("XK") && !validRegions.contains("XX") && !validRegions.contains("EU"), "unexpected valid regions")

        print("  parsing locale files…", to: &standardError)
        let (files, localesWithoutData) = try loadICULocaleFiles(cldrURL: cldrURL, parents: parents, likelySubtags: likelySubtags)
        var locales: [String: LocaleValues] = [:]
        for (locale, url) in files {
            locales[locale] = try parseLocale(url)
        }
        for locale in localesWithoutData {
            locales[locale] = LocaleValues()
        }

        print("  resolving \(locales.count) locales…", to: &standardError)
        let resolver = Resolver(locales: locales, parents: parents)
        let sortedLocales = locales.keys.sorted()

        var ownSystems = Set<String>()
        for locale in sortedLocales {
            let latin = resolver.symbols(locale, "latn")
            for system in numberingSystems.keys where system != "latn" && resolver.symbols(locale, system) != latin {
                ownSystems.insert(system)
            }
        }
        let symbolSystems = ["latn"] + ownSystems.sorted()

        let slots = [
            "systems": systemSlots,
            "symbols": symbolSystems.flatMap { system in symbolFields.map { "\(system)|\($0)" } },
        ]
        var groupBlocks: [String: [[String?]]] = [:]
        var localeBlocks: [String: [String: Int]] = [:]
        for group in localeNumberGroups {
            var table = BlockTable()
            for locale in sortedLocales {
                let block: [String?] = switch group {
                case "systems":
                    [resolver.defaultNumberingSystem(locale)] + otherNumberingSystemTypes.map { resolver.otherNumberingSystem(locale, $0) }
                default:
                    symbolSystems.flatMap { resolver.symbols(locale, $0) }
                }
                localeBlocks[locale, default: [:]][group] = table.index(of: block)
            }
            groupBlocks[group] = table.blocks
            print("  \(group): \(slots[group]!.count) slots, \(table.blocks.count) distinct blocks", to: &standardError)
        }

        // Check known values, to catch a resolver that reads the data wrongly.
        func check(_ locale: String, _ group: String, _ slot: String, _ expected: String?) {
            let block = groupBlocks[group]![localeBlocks[locale]![group]!]
            let actual = block[slots[group]!.firstIndex(of: slot)!]
            precondition(actual == expected, "\(locale) \(slot): expected \(expected ?? "nil"), got \(actual ?? "nil")")
        }
        check("fa", "systems", "default", "arabext")
        check("ar_EG", "systems", "default", "arab")
        check("ar", "systems", "default", "latn")
        check("ta", "systems", "native", "tamldec")
        check("fa", "symbols", "arabext|minusSign", "\u{200E}\u{2212}")
        check("sv", "symbols", "latn|minusSign", "\u{2212}")

        let schema = LocaleNumberDataSchema(
            generatedFrom: "CLDR \(detectCLDRVersion(cldrURL))",
            cldrVersion: detectCLDRVersion(cldrURL),
            numberingSystems: numberingSystems,
            groupSlots: slots,
            groupBlocks: groupBlocks,
            locales: localeBlocks,
            parents: parents,
            aliases: localeAliases,
            defaultScripts: defaultScripts(likelySubtags: likelySubtags),
            validRegions: validRegions
        )
        try writeJSON(schema)
    }
}
