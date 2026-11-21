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

// Stage 2 of the plural-rules data pipeline: reads PluralRulesData.json and
// writes PluralRulesData.swift for the _FoundationInternationalizationData
// library. The rule text is parsed here, so the library only evaluates small
// tables and never parses rules at run time.
//
// Reads four environment variables (set by the build-plural-rules-data wrapper):
//   - INPUT        : path to PluralRulesData.json
//   - OUTPUT_SWIFT : path where PluralRulesData.swift is written
//   - LOCALES      : comma-separated locale list ("" = include all)
//   - FALLBACK     : locale whose rules a lookup uses when it finds no data (default: "root")
//
// With LOCALES, the data keeps each listed locale and every locale its lookup
// reaches by removing trailing subtags (en_US keeps en), plus root and the
// fallback.
//
// The tables are `static let` constants on an enum, so the compiler places
// them in read-only data with no initializer at load time. The table entry
// types are in PluralRules.swift.

import Foundation

struct Options {
    let inputPath: String
    let outputSwiftPath: String
    let requestedLocales: [String]? // nil = include all locales
    let fallback: String
}

func readOptions() -> Options {
    let environment = ProcessInfo.processInfo.environment
    guard let inputPath = environment["INPUT"], !inputPath.isEmpty else { fatalError("INPUT environment variable not set") }
    guard let outputSwiftPath = environment["OUTPUT_SWIFT"], !outputSwiftPath.isEmpty else { fatalError("OUTPUT_SWIFT environment variable not set") }
    let locales = environment["LOCALES"] ?? ""
    return Options(
        inputPath: inputPath,
        outputSwiftPath: outputSwiftPath,
        requestedLocales: locales.isEmpty ? nil : locales.split(separator: ",").map { $0.replacingOccurrences(of: "-", with: "_") },
        fallback: environment["FALLBACK"] ?? "root")
}

// MARK: - Rule parsing

/// The operands, as the case names of `PluralOperand` in PluralRules.swift.
let operandCaseNames: [Character: String] = [
    "n": "absoluteValue",
    "i": "integerDigits",
    "v": "fractionDigitCount",
    "w": "fractionDigitCountWithoutTrailingZeros",
    "f": "fractionDigits",
    "t": "fractionDigitsWithoutTrailingZeros",
    "e": "exponent",
    "c": "exponent",
]

struct Relation: Hashable {
    var operand: String
    var modulus: UInt32?
    var isNegated: Bool
    var startsAlternative: Bool
    var ranges: [ClosedRange<UInt32>]
}

struct CompiledRule: Hashable {
    var category: String
    var relations: [Relation]
}

enum RuleError: Error, CustomStringConvertible {
    case syntax(String, String)
    var description: String {
        switch self {
        case .syntax(let condition, let detail): return "can't parse rule \"\(condition)\": \(detail)"
        }
    }
}

// The values that the evaluator handles exactly. It keeps integer digits beyond
// 18 digits modulo 10^18, which is exact for these moduli and values.
let largestExactValue: UInt64 = 1_000_000_000_000_000_000

/// Parses a condition such as `v = 0 and i % 10 = 1 or f % 10 = 2..4`.
func compile(condition: String) throws -> [Relation] {
    var relations: [Relation] = []
    let alternatives = condition.components(separatedBy: " or ")
    for (alternativeIndex, alternative) in alternatives.enumerated() {
        for (relationIndex, text) in alternative.components(separatedBy: " and ").enumerated() {
            let words = text.split(separator: " ").map(String.init)
            var position = 0
            func next() throws -> String {
                guard position < words.count else { throw RuleError.syntax(condition, "unexpected end in \"\(text)\"") }
                defer { position += 1 }
                return words[position]
            }
            let operandWord = try next()
            guard operandWord.count == 1, let operandCharacter = operandWord.first, let operand = operandCaseNames[operandCharacter] else {
                throw RuleError.syntax(condition, "unknown operand \"\(operandWord)\"")
            }
            var modulus: UInt32?
            var word = try next()
            if word == "%" || word == "mod" {
                guard let value = UInt32(try next()), value > 0, largestExactValue % UInt64(value) == 0 else {
                    throw RuleError.syntax(condition, "unsupported modulus in \"\(text)\"")
                }
                modulus = value
                word = try next()
            }
            let isNegated: Bool
            switch word {
            case "=": isNegated = false
            case "!=": isNegated = true
            default: throw RuleError.syntax(condition, "unsupported relation \"\(word)\"")
            }
            var ranges: [ClosedRange<UInt32>] = []
            for item in try next().split(separator: ",") {
                let bounds = item.components(separatedBy: "..")
                guard bounds.count <= 2, let lower = UInt32(bounds[0]), let upper = UInt32(bounds[bounds.count - 1]), lower <= upper else {
                    throw RuleError.syntax(condition, "bad range \"\(item)\"")
                }
                ranges.append(lower ... upper)
            }
            guard position == words.count else { throw RuleError.syntax(condition, "extra words in \"\(text)\"") }
            relations.append(Relation(
                operand: operand,
                modulus: modulus,
                isNegated: isNegated,
                startsAlternative: alternativeIndex > 0 && relationIndex == 0,
                ranges: ranges))
        }
    }
    return relations
}

// MARK: - Packing

struct PackedData {
    var ranges: [ClosedRange<UInt32>] = []
    var relations: [(relation: Relation, rangeStart: Int, rangeEnd: Int)] = []
    var rules: [(category: String, relationStart: Int, relationEnd: Int)] = []
    var ruleSets: [(ruleStart: Int, ruleEnd: Int)] = []
    var localePool: [String] = []
    var cardinal: [(locale: Int, ruleSet: Int)] = []
    var ordinal: [(locale: Int, ruleSet: Int)] = []
    var cardinalFallback = 0
    var ordinalFallback = 0
}

/// The locale a lookup finds for `identifier`, as the run-time lookup does it.
func resolve(_ identifier: String, in map: [String: Int]) -> String? {
    var current = Substring(identifier)
    while true {
        if map[String(current)] != nil { return String(current) }
        guard let underscore = current.lastIndex(of: "_") else { return nil }
        current = current[..<underscore]
    }
}

func pack(_ data: PluralRulesDataSchema, options: Options) throws -> (PackedData, keptLocales: [String]) {
    // Keep what a lookup of a requested locale reaches, plus root and the fallback.
    var kept = Set<String>()
    if let requested = options.requestedLocales {
        for locale in requested + ["root", options.fallback] {
            for map in [data.cardinal, data.ordinal] {
                if let found = resolve(locale, in: map) { kept.insert(found) }
            }
        }
    } else {
        kept = Set(data.cardinal.keys).union(data.ordinal.keys)
    }
    let cardinal = data.cardinal.filter { kept.contains($0.key) }
    let ordinal = data.ordinal.filter { kept.contains($0.key) }

    // Compile the rule sets these locales use, sharing equal rule sets.
    var packed = PackedData()
    var compiledIndex: [[CompiledRule]: Int] = [:]
    var ruleSetIndex: [Int: Int] = [:]
    func packRuleSet(_ compiled: [CompiledRule]) -> Int {
        if let existing = compiledIndex[compiled] { return existing }
        let ruleStart = packed.rules.count
        for rule in compiled {
            let relationStart = packed.relations.count
            for relation in rule.relations {
                let rangeStart = packed.ranges.count
                packed.ranges += relation.ranges
                packed.relations.append((relation, rangeStart, packed.ranges.count))
            }
            packed.rules.append((rule.category, relationStart, packed.relations.count))
        }
        packed.ruleSets.append((ruleStart, packed.rules.count))
        compiledIndex[compiled] = packed.ruleSets.count - 1
        return packed.ruleSets.count - 1
    }
    func packedRuleSet(_ jsonIndex: Int) throws -> Int {
        if let existing = ruleSetIndex[jsonIndex] { return existing }
        var compiled: [CompiledRule] = []
        for rule in data.ruleSets[jsonIndex] where rule.category != "other" {
            compiled.append(CompiledRule(category: rule.category, relations: try compile(condition: rule.condition)))
        }
        let index = packRuleSet(compiled)
        ruleSetIndex[jsonIndex] = index
        return index
    }

    // The fallback rules. With no data for the fallback, every number is `other`, as in root.
    let rootRuleSet = packRuleSet([])
    packed.cardinalFallback = try resolve(options.fallback, in: cardinal).flatMap { cardinal[$0] }.map(packedRuleSet) ?? rootRuleSet
    packed.ordinalFallback = try resolve(options.fallback, in: ordinal).flatMap { ordinal[$0] }.map(packedRuleSet) ?? rootRuleSet

    // The locale pool, sorted by UTF-8 bytes like the run-time binary search.
    packed.localePool = Set(cardinal.keys).union(ordinal.keys).sorted { Array($0.utf8).lexicographicallyPrecedes(Array($1.utf8)) }
    let localeIndex = Dictionary(uniqueKeysWithValues: packed.localePool.enumerated().map { ($1, $0) })
    for locale in packed.localePool {
        guard let poolIndex = localeIndex[locale] else { continue }
        if let set = cardinal[locale] { packed.cardinal.append((poolIndex, try packedRuleSet(set))) }
        if let set = ordinal[locale] { packed.ordinal.append((poolIndex, try packedRuleSet(set))) }
    }
    precondition(packed.ranges.count <= Int(UInt16.max) && packed.relations.count <= Int(UInt16.max), "tables too large for UInt16 indexes")
    return (packed, options.requestedLocales == nil ? [] : kept.sorted())
}

// MARK: - Rendering

func renderSwift(_ packed: PackedData, data: PluralRulesDataSchema, keptLocales: [String], fallback: String) -> String {
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
    // Generated by utils/build-plural-rules-data — do not edit by hand.
    // CLDR version: \(data.cldrVersion)
    // Locales: \(keptLocales.isEmpty ? "all" : keptLocales.joined(separator: ","))
    // Fallback: \(fallback)
    //===----------------------------------------------------------------------===//

    internal enum PluralRulesData {
        // The rule set a lookup uses when it finds no data for a locale.
        internal static let cardinalFallback: UInt16 = \(packed.cardinalFallback)
        internal static let ordinalFallback: UInt16 = \(packed.ordinalFallback)


    """
    out += "    internal static let ranges: InlineArray<\(packed.ranges.count), PluralRange> = [\n"
    for range in packed.ranges {
        out += "        PluralRange(\(range.lowerBound), \(range.upperBound)),\n"
    }
    out += "    ]\n\n"

    out += "    internal static let relations: InlineArray<\(packed.relations.count), PluralRelation> = [\n"
    for (relation, rangeStart, rangeEnd) in packed.relations {
        let modulus = relation.modulus.map(String.init) ?? "nil"
        out += "        PluralRelation(.\(relation.operand), modulus: \(modulus), isNegated: \(relation.isNegated), startsAlternative: \(relation.startsAlternative), ranges: \(rangeStart), \(rangeEnd)),\n"
    }
    out += "    ]\n\n"

    out += "    internal static let rules: InlineArray<\(packed.rules.count), PluralRule> = [\n"
    for (category, relationStart, relationEnd) in packed.rules {
        out += "        PluralRule(.\(category), relations: \(relationStart), \(relationEnd)),\n"
    }
    out += "    ]\n\n"

    out += "    // The rules of each set, without `other`, which is the result when no rule matches.\n"
    out += "    internal static let ruleSets: InlineArray<\(packed.ruleSets.count), PluralRuleSet> = [\n"
    for (ruleStart, ruleEnd) in packed.ruleSets {
        out += "        PluralRuleSet(rules: \(ruleStart), \(ruleEnd)),\n"
    }
    out += "    ]\n\n"

    var bytes: [UInt8] = []
    var offsets: [Int] = [0]
    for locale in packed.localePool {
        bytes += Array(locale.utf8)
        offsets.append(bytes.count)
    }
    out += "    // Locale identifier pool. Locale `i` is the UTF-8 bytes from `localeOffsets[i]` up to `localeOffsets[i + 1]`.\n"
    out += "    internal static let localeBytes: InlineArray<\(bytes.count), UInt8> = [\n"
    for chunk in stride(from: 0, to: bytes.count, by: 16) {
        out += "        " + bytes[chunk ..< min(chunk + 16, bytes.count)].map { String($0) + "," }.joined(separator: " ") + "\n"
    }
    out += "    ]\n\n"
    out += "    internal static let localeOffsets: InlineArray<\(offsets.count), UInt16> = [\n"
    for chunk in stride(from: 0, to: offsets.count, by: 16) {
        out += "        " + offsets[chunk ..< min(chunk + 16, offsets.count)].map { String($0) + "," }.joined(separator: " ") + "\n"
    }
    out += "    ]\n\n"

    for (name, entries) in [("cardinalLocales", packed.cardinal), ("ordinalLocales", packed.ordinal)] {
        out += "    // Sorted by locale identifier for binary search.\n"
        out += "    internal static let \(name): InlineArray<\(entries.count), PluralLocaleEntry> = [\n"
        for (locale, ruleSet) in entries {
            out += "        PluralLocaleEntry(\(locale), \(ruleSet)), // \(packed.localePool[locale])\n"
        }
        out += "    ]\n\n"
    }
    out.removeLast()
    out += "}\n"
    return out
}

@main
struct BuildPluralRulesData {
    static func main() throws {
        let options = readOptions()
        let data = try JSONDecoder().decode(PluralRulesDataSchema.self, from: Data(contentsOf: URL(fileURLWithPath: options.inputPath)))
        let (packed, keptLocales) = try pack(data, options: options)
        try renderSwift(packed, data: data, keptLocales: keptLocales, fallback: options.fallback)
            .write(toFile: options.outputSwiftPath, atomically: true, encoding: .utf8)
        print("  \(packed.cardinal.count) cardinal and \(packed.ordinal.count) ordinal locales, \(packed.ruleSets.count) rule sets, \(packed.rules.count) rules, \(packed.relations.count) relations, \(packed.ranges.count) ranges", to: &standardError)
    }
}
