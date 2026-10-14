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

// Stage 2 of the date-format data pipeline: reads DateFormatData.json and
// writes DateFormatData.swift, the tables DateFormatLookup.swift reads.
//
// Environment (set by the build-date-format-data wrapper):
//   - INPUT        : path to DateFormatData.json
//   - OUTPUT_SWIFT : path to write DateFormatData.swift
//   - LOCALES      : comma-separated locales to include ("" = all)
//   - FALLBACK     : locale used where a language has no data ("" = root)
//
// Strings use "layout E": each is a 4-byte entry, a length byte plus 3 bytes.
// Text of 3 UTF-8 bytes or fewer is stored in those bytes. Longer text is
// stored once in a shared pool, and the 3 bytes hold its offset.
//
// Every included locale is fully resolved: it has one block index per group,
// and identical blocks are stored once. A lookup for an included locale is two
// table reads. An identifier that isn't included walks redirects (aliases,
// parent locales of excluded locales, and ICU's script fallback) and truncation
// until it reaches one.

import Foundation

struct Options {
    let inputPath: String
    let outputSwiftPath: String
    let requestedLocales: Set<String>?
    let fallback: String?
}

func readOptions() -> Options {
    let environment = ProcessInfo.processInfo.environment
    let locales = environment["LOCALES"] ?? ""
    return Options(
        inputPath: environment["INPUT"]!,
        outputSwiftPath: environment["OUTPUT_SWIFT"]!,
        requestedLocales: locales.isEmpty ? nil : Set(locales.split(separator: ",").map { String($0).replacingOccurrences(of: "-", with: "_") }),
        fallback: environment["FALLBACK"].flatMap { $0.isEmpty ? nil : $0 }
    )
}

// MARK: - Layout E

struct StringPool {
    private(set) var bytes: [UInt8] = []
    private var offsets: [String: Int] = [:]

    /// Returns the 4-byte entry for `string`, adding it to the pool if needed.
    mutating func entry(_ string: String?) -> UInt32 {
        guard let string, !string.isEmpty else { return 0 }
        let utf8 = Array(string.utf8)
        precondition(utf8.count <= 255, "string longer than 255 bytes: \(string)")
        if utf8.count <= 3 {
            var entry = UInt32(utf8.count)
            for (i, byte) in utf8.enumerated() {
                entry |= UInt32(byte) << (8 * (i + 1))
            }
            return entry
        }
        let offset = offsets[string] ?? {
            let offset = bytes.count
            bytes += utf8
            offsets[string] = offset
            return offset
        }()
        precondition(offset < 1 << 24, "string pool exceeds 16 MB")
        return UInt32(utf8.count) | UInt32(offset) << 8
    }
}

// MARK: - Subsetting

/// The included locale an identifier resolves to, following `redirects` and truncation, as the runtime does.
/// Where its language has no data, that's the fallback locale, else root.
func resolve(_ locale: String, included: Set<String>, redirects: [String: String], fallback: String?) -> String {
    var current = locale
    while !included.contains(current) {
        if let target = redirects[current] {
            current = target
        } else if let underscore = current.lastIndex(of: "_") {
            current = String(current[..<underscore])
        } else {
            return fallback ?? "root"
        }
    }
    return current
}

// MARK: - Swift output

func hex(_ value: UInt32) -> String {
    String(format: "0x%08X", value)
}

func table(_ name: String, _ type: String, _ values: [String], comment: String, perLine: Int) -> String {
    var out = "    // \(comment)\n    internal static let \(name): InlineArray<\(values.count), \(type)> = [\n"
    for start in stride(from: 0, to: values.count, by: perLine) {
        out += "        " + values[start..<min(start + perLine, values.count)].joined(separator: ", ") + ",\n"
    }
    return out + "    ]\n\n"
}

@main
struct BuildDateFormatData {
    static func main() throws {
        let options = readOptions()
        let schema = try JSONDecoder().decode(DateFormatDataSchema.self, from: Data(contentsOf: URL(fileURLWithPath: options.inputPath)))

        let allLocales = Set(schema.locales.keys)
        var included = options.requestedLocales.map { $0.intersection(allLocales) } ?? allLocales
        if let requested = options.requestedLocales {
            for locale in requested.subtracting(allLocales).sorted() {
                print("  warning: \(locale) isn't a CLDR locale; skipping", to: &standardError)
            }
        }
        included.insert("root")
        if let fallback = options.fallback {
            included.insert(fallback)
        }
        let sortedLocales = included.sorted { Array($0.utf8).lexicographicallyPrecedes(Array($1.utf8)) }

        // Redirects: every alias, and the parent of every excluded locale, then
        // keep only those that change which blocks an identifier gets.
        var candidates = schema.aliases
        for (child, parentLocale) in schema.parents where !included.contains(child) {
            candidates[child] = candidates[child] ?? parentLocale
        }
        func blocks(_ locale: String) -> [String: Int] { schema.locales[locale]! }
        var redirects: [String: String] = [:]
        for (source, target) in candidates.sorted(by: { $0.key < $1.key }) {
            // What this identifier gets with every redirect, versus without this one.
            let full = candidates
            var without = candidates
            without[source] = nil
            let wanted = resolve(source, included: included, redirects: full, fallback: options.fallback)
            let plain = resolve(source, included: included, redirects: without, fallback: options.fallback)
            if blocks(wanted) != blocks(plain) {
                redirects[source] = target
            }
        }
        // Dropping a redirect can change another that went through it, so check again with the kept set.
        for source in candidates.keys {
            let expected = blocks(resolve(source, included: included, redirects: candidates, fallback: options.fallback))
            let actual = blocks(resolve(source, included: included, redirects: redirects, fallback: options.fallback))
            precondition(expected == actual, "trimming redirects changed \(source)")
        }

        // Redirects for ICU's script fallback, such as en_Latn_GB to en_GB.
        let redirectCount = redirects.count
        redirects = scriptFallbackRedirects(included: included, icuRedirects: candidates, defaultScripts: schema.defaultScripts, redirects: redirects) { identifier, redirects in
            blocks(resolve(identifier, included: included, redirects: redirects, fallback: options.fallback))
        }
        let scriptRedirects = redirects.count - redirectCount

        // Keep only the blocks the included locales use, and renumber them.
        var pool = StringPool()
        var groupBases: [Int] = []
        var entries: [UInt32] = []
        var remap: [String: [Int: Int]] = [:]
        for group in dateFormatGroups {
            let used = Set(sortedLocales.map { blocks($0)[group]! }).sorted()
            groupBases.append(entries.count)
            for (newIndex, oldIndex) in used.enumerated() {
                remap[group, default: [:]][oldIndex] = newIndex
                entries += schema.groupBlocks[group]![oldIndex].map { pool.entry($0) }
            }
            precondition(used.count < 65536)
        }
        let localeIDs = sortedLocales.map { pool.entry($0) }
        let localeBlocks = sortedLocales.flatMap { locale in dateFormatGroups.map { remap[$0]![blocks(locale)[$0]!]! } }
        let redirectSources = redirects.keys.sorted { Array($0.utf8).lexicographicallyPrecedes(Array($1.utf8)) }
        let redirectFrom = redirectSources.map { pool.entry($0) }
        // Targets are identifiers, since a target may itself be excluded and redirect again.
        let redirectTargets = redirectSources.map { pool.entry(redirects[$0]!) }
        let systems = schema.numberingSystems.keys.sorted { Array($0.utf8).lexicographicallyPrecedes(Array($1.utf8)) }
        let systemIDs = systems.map { pool.entry($0) }
        let systemDigits = systems.flatMap { schema.numberingSystems[$0]!.map { pool.entry($0) } }
        let hanidaysDays = schema.hanidaysDays.map { pool.entry($0) }
        let minusSystems = schema.groupSlots["numbers"]!.dropFirst(4).map { pool.entry($0.replacingOccurrences(of: "minus.", with: "")) }
        // One bit per two-letter code, AA through ZZ, as ICU's gValidRegionMap.
        var validRegions = [UInt32](repeating: 0, count: (26 * 26 + 31) / 32)
        for region in schema.validRegions {
            let letters = Array(region.utf8)
            precondition(letters.count == 2 && letters.allSatisfy { $0 >= UInt8(ascii: "A") && $0 <= UInt8(ascii: "Z") }, "bad region \(region)")
            let bit = Int(letters[0] - UInt8(ascii: "A")) * 26 + Int(letters[1] - UInt8(ascii: "A"))
            validRegions[bit / 32] |= 1 << (bit % 32)
        }

        // MARK: Render
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
        // Generated by utils/build-date-format-data — do not edit by hand.
        // CLDR version: \(schema.cldrVersion)
        // Locales: \(options.requestedLocales == nil ? "all" : "\(sortedLocales.count)")
        // Fallback: \(options.fallback ?? "root")
        //===----------------------------------------------------------------------===//

        #if FOUNDATION_DATE_FORMAT_SWIFT

        // Strings are 4-byte entries: the low byte is the UTF-8 length. Text of up
        // to 3 bytes follows in the next bytes; longer text is at the offset in the
        // upper 3 bytes, in `pool`. 0 means no value.
        internal enum _DateFormatData {

        """
        out += "    // Locale used where a language has no data. Empty means root.\n"
        out += "    internal static let fallbackLocale: StaticString = \"\(options.fallback ?? "")\"\n\n"
        out += "    // Each group's first entry in `entries`, in DateFormatDataGroup order.\n"
        out += "    internal static let groupBases: InlineArray<\(groupBases.count), Int> = [\(groupBases.map(String.init).joined(separator: ", "))]\n\n"
        out += "    // Slots per block, in DateFormatDataGroup order.\n"
        out += "    internal static let groupSlotCounts: InlineArray<\(dateFormatGroups.count), Int> = [\(dateFormatGroups.map { String(schema.groupSlots[$0]!.count) }.joined(separator: ", "))]\n\n"
        out += table("minusSignSystems", "UInt32", minusSystems.map(hex), comment: "Numbers slots: default, native, traditional, finance, then minus signs for \(schema.groupSlots["numbers"]!.dropFirst(4).map { $0.replacingOccurrences(of: "minus.", with: "") }.joined(separator: ", ")).", perLine: 8)
        out += table("entries", "UInt32", entries.map(hex), comment: "Every group's blocks, one entry per slot.", perLine: 8)
        out += table("localeIDs", "UInt32", localeIDs.map(hex), comment: "Included locales, sorted by UTF-8 bytes.", perLine: 8)
        out += table("localeBlocks", "UInt16", localeBlocks.map(String.init), comment: "Each locale's block index for each group, \(dateFormatGroups.count) per locale.", perLine: dateFormatGroups.count * 2)
        out += table("redirectFrom", "UInt32", redirectFrom.map(hex), comment: "Identifiers that redirect to another locale, sorted by UTF-8 bytes.", perLine: 8)
        out += table("redirectTo", "UInt32", redirectTargets.map(hex), comment: "Where each identifier in `redirectFrom` goes.", perLine: 8)
        out += table("numberingSystemIDs", "UInt32", systemIDs.map(hex), comment: "Numeric numbering systems, sorted by UTF-8 bytes.", perLine: 8)
        out += table("numberingSystemDigits", "UInt32", systemDigits.map(hex), comment: "Each numbering system's digits 0 through 9.", perLine: 10)
        out += table("hanidaysDays", "UInt32", hanidaysDays.map(hex), comment: "Days 1 through 31 for numbers=hanidays.", perLine: 8)
        out += table("validRegions", "UInt32", validRegions.map(hex), comment: "Regions an rg keyword can name, one bit per code: (first letter - A) * 26 + (second letter - A).", perLine: 8)

        out += table("pool", "UInt8", pool.bytes.map { String(format: "0x%02X", $0) }, comment: "Text longer than 3 UTF-8 bytes, stored once.", perLine: 16)
        out += "}\n\n#endif // FOUNDATION_DATE_FORMAT_SWIFT\n"

        try out.write(toFile: options.outputSwiftPath, atomically: true, encoding: .utf8)
        print("  locales: \(sortedLocales.count), redirects: \(redirects.count) (\(scriptRedirects) for script fallback), entries: \(entries.count), pool: \(pool.bytes.count) B", to: &standardError)
        let size = entries.count * 4 + localeIDs.count * 4 + localeBlocks.count * 2 + redirectFrom.count * 8 + systemIDs.count * 4 + systemDigits.count * 4 + hanidaysDays.count * 4 + validRegions.count * 4 + pool.bytes.count
        print("  table bytes: \(size)", to: &standardError)
    }
}
