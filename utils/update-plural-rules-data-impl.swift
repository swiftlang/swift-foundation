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

// Stage 1 of the plural-rules data pipeline: reads the CLDR plural rules from
// a CLDR XML checkout (common/supplemental/plurals.xml and ordinals.xml) and
// writes:
//   - OUTPUT_JSON: PluralRulesData.json, the input of utils/build-plural-rules-data.
//   - OUTPUT_TESTS: the CLDR samples of every rule, for the unit tests.
//
// Locales with the same rules share one rule set.

import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

// The XML has no rules for `wuu` (Wu Chinese). It gets the cardinal rules of `zh`, so that `wuu`
// keeps the plural forms Foundation gives it today.
let extraCardinalLocales = ["wuu": "zh"]
let extraOrdinalLocales: [String: String] = [:]

enum UpdateError: Error, CustomStringConvertible {
    case missingEnvironment(String)
    case unexpectedXML(String)
    case missingCategory(String)

    var description: String {
        switch self {
        case .missingEnvironment(let name): return "\(name) environment variable not set"
        case .unexpectedXML(let detail): return "unexpected XML: \(detail)"
        case .missingCategory(let detail): return "unknown plural category: \(detail)"
        }
    }
}

/// Splits CLDR rule text such as `i = 1 and v = 0 @integer 1 @decimal 0.0~1.5` into its parts.
func parseRule(category: String, text: String) -> PluralRulesDataSchema.Rule {
    func samples(after keyword: String) -> String {
        guard let start = text.range(of: keyword) else { return "" }
        let rest = text[start.upperBound...]
        let end = rest.firstIndex(of: "@") ?? rest.endIndex
        return rest[..<end].trimmingCharacters(in: .whitespaces)
    }
    let condition = text.prefix { $0 != "@" }.trimmingCharacters(in: .whitespaces)
    return .init(category: category, condition: condition, integerSamples: samples(after: "@integer"), decimalSamples: samples(after: "@decimal"))
}

/// Reads `common/supplemental/<file>` and returns locale → rules in CLDR category order.
func loadRules(cldrURL: URL, file: String, type: String) throws -> [String: [PluralRulesDataSchema.Rule]] {
    let url = cldrURL.appendingPathComponent("common/supplemental").appendingPathComponent(file)
    let document = try XMLDocument(contentsOf: url)
    let groups = try document.nodes(forXPath: "/supplementalData/plurals[@type='\(type)']/pluralRules")
    guard !groups.isEmpty else { throw UpdateError.unexpectedXML("\(file) has no \(type) rules") }
    var result: [String: [PluralRulesDataSchema.Rule]] = [:]
    for case let group as XMLElement in groups {
        guard let locales = group.attribute(forName: "locales")?.stringValue else {
            throw UpdateError.unexpectedXML("\(file) pluralRules without locales")
        }
        var rules: [PluralRulesDataSchema.Rule] = []
        for element in group.elements(forName: "pluralRule") {
            guard let category = element.attribute(forName: "count")?.stringValue else {
                throw UpdateError.unexpectedXML("\(file) \(locales) pluralRule without count")
            }
            guard pluralCategoryNames.contains(category) else { throw UpdateError.missingCategory("\(locales) \(category)") }
            rules.append(parseRule(category: category, text: element.stringValue ?? ""))
        }
        func order(_ rule: PluralRulesDataSchema.Rule) -> Int { pluralCategoryNames.firstIndex(of: rule.category) ?? pluralCategoryNames.count }
        rules.sort { order($0) < order($1) }
        for locale in locales.split(separator: " ") {
            guard result[String(locale)] == nil else { throw UpdateError.unexpectedXML("\(file) lists \(locale) twice") }
            result[String(locale)] = rules
        }
    }
    return result
}

/// The CLDR version, from the `cldrVersion` attribute in `common/dtd/ldml.dtd`.
func detectCLDRVersion(_ cldrURL: URL) throws -> String {
    let dtd = try String(contentsOf: cldrURL.appendingPathComponent("common/dtd/ldml.dtd"), encoding: .utf8)
    guard let range = dtd.range(of: #"cldrVersion CDATA #FIXED "[^"]+""#, options: .regularExpression) else {
        throw UpdateError.unexpectedXML("no cldrVersion in common/dtd/ldml.dtd")
    }
    return String(dtd[range].split(separator: "\"")[1])
}

func swiftStringLiteral(_ string: String) -> String {
    var result = "\""
    for scalar in string.unicodeScalars {
        switch scalar {
        case "\"": result += "\\\""
        case "\\": result += "\\\\"
        default: result.unicodeScalars.append(scalar)
        }
    }
    return result + "\""
}

/// The CLDR samples of every rule set, as Swift source for the unit tests.
func renderTestSamples(_ data: PluralRulesDataSchema) -> String {
    var out = """
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
    // Generated by utils/update-plural-rules-data — do not edit by hand.
    // CLDR version: \(data.cldrVersion)
    //===----------------------------------------------------------------------===//

    #if canImport(_FoundationInternationalizationData) && FOUNDATION_PLURAL_RULES_SWIFT
    import _FoundationInternationalizationData

    // The documented samples of each rule. Each sample must get the category of its rule.
    let pluralRulesSamples: [PluralRulesSampleSet] = [

    """
    for (type, map) in [("cardinal", data.cardinal), ("ordinal", data.ordinal)] {
        var localesBySet: [Int: [String]] = [:]
        for (locale, set) in map { localesBySet[set, default: []].append(locale) }
        for set in localesBySet.keys.sorted() {
            let locales = localesBySet[set, default: []].sorted().map(swiftStringLiteral).joined(separator: ", ")
            out += "    PluralRulesSampleSet(type: .\(type), locales: [\(locales)], rules: [\n"
            for rule in data.ruleSets[set] {
                out += "        (\(swiftStringLiteral(rule.category)), integer: \(swiftStringLiteral(rule.integerSamples)), decimal: \(swiftStringLiteral(rule.decimalSamples))),\n"
            }
            out += "    ]),\n"
        }
    }
    out += "]\n\n#endif\n"
    return out
}

@main
struct UpdatePluralRulesData {
    static func main() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let cldrPath = environment["CLDR_PATH"] else { throw UpdateError.missingEnvironment("CLDR_PATH") }
        guard let outputJSON = environment["OUTPUT_JSON"] else { throw UpdateError.missingEnvironment("OUTPUT_JSON") }
        guard let outputTests = environment["OUTPUT_TESTS"] else { throw UpdateError.missingEnvironment("OUTPUT_TESTS") }

        let cldrURL = URL(fileURLWithPath: cldrPath)
        let cldrVersion = try detectCLDRVersion(cldrURL)
        let cardinalRules = try loadRules(cldrURL: cldrURL, file: "plurals.xml", type: "cardinal")
        let ordinalRules = try loadRules(cldrURL: cldrURL, file: "ordinals.xml", type: "ordinal")

        var ruleSets: [[PluralRulesDataSchema.Rule]] = []
        var ruleSetIndex: [[PluralRulesDataSchema.Rule]: Int] = [:]
        func index(of rules: [PluralRulesDataSchema.Rule]) -> Int {
            if let existing = ruleSetIndex[rules] { return existing }
            ruleSets.append(rules)
            ruleSetIndex[rules] = ruleSets.count - 1
            return ruleSets.count - 1
        }
        func addExtraLocales(_ extra: [String: String], to rules: inout [String: [PluralRulesDataSchema.Rule]]) {
            for (source, target) in extra where rules[source] == nil {
                if let targetRules = rules[target] { rules[source] = targetRules }
            }
        }
        var cardinalWithExtras = cardinalRules
        var ordinalWithExtras = ordinalRules
        addExtraLocales(extraCardinalLocales, to: &cardinalWithExtras)
        addExtraLocales(extraOrdinalLocales, to: &ordinalWithExtras)

        var cardinal: [String: Int] = [:]
        for locale in cardinalWithExtras.keys.sorted() {
            cardinal[locale] = index(of: cardinalWithExtras[locale, default: []])
        }
        var ordinal: [String: Int] = [:]
        for locale in ordinalWithExtras.keys.sorted() {
            ordinal[locale] = index(of: ordinalWithExtras[locale, default: []])
        }

        let data = PluralRulesDataSchema(
            generatedFrom: "CLDR \(cldrVersion)",
            cldrVersion: cldrVersion,
            ruleSets: ruleSets,
            cardinal: cardinal,
            ordinal: ordinal)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var json = try encoder.encode(data)
        json.append(UInt8(ascii: "\n"))
        try json.write(to: URL(fileURLWithPath: outputJSON))
        try renderTestSamples(data).write(toFile: outputTests, atomically: true, encoding: .utf8)
        print("  \(cardinal.count) cardinal and \(ordinal.count) ordinal locales, \(ruleSets.count) rule sets", to: &standardError)
    }
}
