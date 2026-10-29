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
// Text of 3 UTF-8 bytes or fewer is stored in those bytes. Longer text is in a
// shared pool, and the 3 bytes hold its offset. Text that appears inside longer
// text, such as "Sept" in "September", shares its bytes.
//
// Every included locale is fully resolved. Its blocks split into sub-blocks,
// one per context and width (such as abbreviated format months), and identical
// sub-blocks are stored once. Each locale has a row of where its sub-blocks
// start, and identical rows are stored once. Sub-blocks and pooled text are in
// the order locales first use them, so one locale's data sits together. A
// lookup for an included locale is two table reads. An identifier that isn't
// included walks redirects (aliases, parent locales of excluded locales, and
// ICU's script fallback) and truncation until it reaches one.

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
        fallback: environment["FALLBACK"].flatMap { $0.isEmpty ? nil : $0.replacingOccurrences(of: "-", with: "_") }
    )
}

// MARK: - Layout E

struct StringPool {
    private(set) var bytes: [UInt8] = []
    private var offsets: [[UInt8]: Int] = [:]

    /// Pools the strings longer than 3 bytes in the order they first appear. A string inside a longer one reuses its bytes.
    init(_ strings: [String?]) {
        var distinct: [[UInt8]] = []
        var seen: Set<[UInt8]> = []
        for case let string? in strings {
            let utf8 = Array(string.utf8)
            precondition(utf8.count <= 255, "string longer than 255 bytes: \(string)")
            if utf8.count > 3 && seen.insert(utf8).inserted {
                distinct.append(utf8)
            }
        }
        // Longest first, find which stored string contains each string. Text is
        // valid UTF-8, so only substrings on character boundaries can match.
        var containers: [[UInt8]: (stored: [UInt8], offset: Int)] = [:]
        for index in distinct.indices.sorted(by: { (distinct[$0].count, $1) > (distinct[$1].count, $0) }) {
            let utf8 = distinct[index]
            guard containers[utf8] == nil else { continue }
            for start in utf8.indices where !UTF8.isContinuation(utf8[start]) {
                for end in stride(from: start + 4, through: utf8.count, by: 1) where end == utf8.count || !UTF8.isContinuation(utf8[end]) {
                    let substring = Array(utf8[start ..< end])
                    if containers[substring] == nil {
                        containers[substring] = (utf8, start)
                    }
                }
            }
        }
        // Store each containing string where text it holds is first used.
        var starts: [[UInt8]: Int] = [:]
        for utf8 in distinct {
            let (stored, offset) = containers[utf8]!
            if starts[stored] == nil {
                starts[stored] = bytes.count
                bytes += stored
            }
            offsets[utf8] = starts[stored]! + offset
        }
        precondition(bytes.count <= 1 << 24, "string pool exceeds 16 MB")
    }

    /// Returns the 4-byte entry for `string`, which must have been passed to `init`.
    func entry(_ string: String?) -> UInt32 {
        guard let string, !string.isEmpty else { return 0 }
        let utf8 = Array(string.utf8)
        if utf8.count <= 3 {
            var entry = UInt32(utf8.count)
            for (i, byte) in utf8.enumerated() {
                entry |= UInt32(byte) << (8 * (i + 1))
            }
            return entry
        }
        return UInt32(utf8.count) | UInt32(offsets[utf8]!) << 8
    }
}

// MARK: - Sub-blocks

/// The slots in each group's sub-blocks, one sub-block per context and width, in slot order.
/// DateFormatDataGroup in DateFormatLookup.swift numbers the sub-blocks in a row to match.
let subBlockSizes = ["numbers": 7, "months": 12, "weekdays": 7, "quarters": 4, "eras": 2, "dayPeriods": 3, "gmt": 2, "capitalization": 10]

// MARK: - Subsetting

/// The included locale an identifier resolves to, following `redirects` and truncation, as the runtime does.
/// Where that reaches no included locale, that's the fallback locale, else root.
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
            guard allLocales.contains(fallback) else {
                print("error: --fallback=\(fallback) isn't a locale in the data", to: &standardError)
                exit(1)
            }
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

        // Store each sub-block the included locales use once, and each distinct row of sub-block starts once.
        let subBlocks = dateFormatGroups.flatMap { group in
            let size = subBlockSizes[group]!
            precondition(schema.groupSlots[group]!.count % size == 0, "\(group) doesn't split into sub-blocks of \(size)")
            return stride(from: 0, to: schema.groupSlots[group]!.count, by: size).map { (group: group, slots: $0 ..< $0 + size) }
        }
        var names: [String?] = []
        var subBlockStarts: [[String?]: Int] = [:]
        var rows: [[Int]] = []
        var rowIndexes: [[Int]: Int] = [:]
        var localeRows: [Int] = []
        for locale in sortedLocales {
            let row = subBlocks.map { subBlock in
                let values = Array(schema.groupBlocks[subBlock.group]![blocks(locale)[subBlock.group]!][subBlock.slots])
                if let start = subBlockStarts[values] {
                    return start
                }
                let start = names.count
                subBlockStarts[values] = start
                names += values
                return start
            }
            if rowIndexes[row] == nil {
                rowIndexes[row] = rows.count
                rows.append(row)
            }
            localeRows.append(rowIndexes[row]!)
        }
        precondition(names.count <= 1 << 16 && rows.count <= 1 << 16, "too many sub-blocks or rows for UInt16 indexes")

        let redirectSources = redirects.keys.sorted { Array($0.utf8).lexicographicallyPrecedes(Array($1.utf8)) }
        // Targets are identifiers, since a target may itself be excluded and redirect again.
        let redirectTargetIDs = redirectSources.map { redirects[$0]! }
        let systems = schema.numberingSystems.keys.sorted { Array($0.utf8).lexicographicallyPrecedes(Array($1.utf8)) }
        // Most systems' digits follow their zero in Unicode, so their UTF-8 differs from zero's only in the last byte.
        // The others' digits are stored as text.
        var irregularDigits: [String] = []
        let systemZeros: [UInt32] = systems.map { system in
            let digits = schema.numberingSystems[system]!
            let utf8 = digits.map { Array($0.utf8) }
            if digits.allSatisfy({ $0.unicodeScalars.count == 1 }) && utf8.indices.allSatisfy({ utf8[$0].dropLast() == utf8[0].dropLast() && utf8[$0].last! == utf8[0].last! + UInt8($0) }) {
                return digits[0].unicodeScalars.first!.value
            }
            irregularDigits += digits
            return 0x8000_0000 | UInt32(irregularDigits.count / 10 - 1)
        }
        let minusNames = schema.groupSlots["numbers"]!.dropFirst(4).map { $0.replacingOccurrences(of: "minus.", with: "") }
        let pool = StringPool(names + sortedLocales + redirectSources + redirectTargetIDs + systems + irregularDigits + schema.hanidaysDays + minusNames)
        let nameEntries = names.map(pool.entry)
        let localeIDs = sortedLocales.map(pool.entry)
        let redirectFrom = redirectSources.map(pool.entry)
        let redirectTargets = redirectTargetIDs.map(pool.entry)
        let systemIDs = systems.map(pool.entry)
        let irregularDigitEntries = irregularDigits.map(pool.entry)
        let hanidaysDays = schema.hanidaysDays.map(pool.entry)
        let minusSystems = minusNames.map(pool.entry)
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

        // Strings are 4-byte entries: the low byte is the UTF-8 length. Text of up
        // to 3 bytes follows in the next bytes; longer text is at the offset in the
        // upper 3 bytes, in `pool`. 0 means no value.
        internal enum _DateFormatData {

        """
        out += "    // Locale used where a language has no data. Empty means root.\n"
        out += "    internal static let fallbackLocale: StaticString = \"\(options.fallback ?? "")\"\n\n"
        out += "    // Sub-blocks in a row.\n"
        out += "    internal static let rowWidth = \(subBlocks.count)\n\n"
        out += table("minusSignSystems", "UInt32", minusSystems.map(hex), comment: "Numbers slots: default, native, traditional, finance, then minus signs for \(schema.groupSlots["numbers"]!.dropFirst(4).map { $0.replacingOccurrences(of: "minus.", with: "") }.joined(separator: ", ")).", perLine: 8)
        out += table("names", "UInt32", nameEntries.map(hex), comment: "Every sub-block, one entry per slot.", perLine: 8)
        out += table("rows", "UInt16", rows.flatMap { $0.map(String.init) }, comment: "Where each row's sub-blocks start in `names`, in DateFormatDataGroup order.", perLine: subBlocks.count)
        out += table("localeIDs", "UInt32", localeIDs.map(hex), comment: "Included locales, sorted by UTF-8 bytes.", perLine: 8)
        out += table("localeRows", "UInt16", localeRows.map(String.init), comment: "Each locale's row in `rows`.", perLine: 16)
        out += table("redirectFrom", "UInt32", redirectFrom.map(hex), comment: "Identifiers that redirect to another locale, sorted by UTF-8 bytes.", perLine: 8)
        out += table("redirectTo", "UInt32", redirectTargets.map(hex), comment: "Where each identifier in `redirectFrom` goes.", perLine: 8)
        out += table("numberingSystemIDs", "UInt32", systemIDs.map(hex), comment: "Numeric numbering systems, sorted by UTF-8 bytes.", perLine: 8)
        out += table("numberingSystemZeros", "UInt32", systemZeros.map(hex), comment: "Each numbering system's zero, whose UTF-8 differs from its other digits' only in the last byte, or 0x80000000 plus the system's index in `irregularDigits`.", perLine: 8)
        out += table("irregularDigits", "UInt32", irregularDigitEntries.map(hex), comment: "Digits 0 through 9 of the systems whose digits don't follow their zero.", perLine: 10)
        out += table("hanidaysDays", "UInt32", hanidaysDays.map(hex), comment: "Days 1 through 31 for numbers=hanidays.", perLine: 8)
        out += table("validRegions", "UInt32", validRegions.map(hex), comment: "Regions an rg keyword can name, one bit per code: (first letter - A) * 26 + (second letter - A).", perLine: 8)

        out += table("pool", "UInt8", pool.bytes.map { String(format: "0x%02X", $0) }, comment: "Text longer than 3 UTF-8 bytes, stored once.", perLine: 16)
        out += "}\n"

        try out.write(toFile: options.outputSwiftPath, atomically: true, encoding: .utf8)
        print("  locales: \(sortedLocales.count), redirects: \(redirects.count) (\(scriptRedirects) for script fallback), names: \(names.count), rows: \(rows.count), pool: \(pool.bytes.count) B", to: &standardError)
        let size = names.count * 4 + rows.count * subBlocks.count * 2 + localeIDs.count * 6 + redirectFrom.count * 8 + systemIDs.count * 4 + systemZeros.count * 4 + irregularDigitEntries.count * 4 + hanidaysDays.count * 4 + validRegions.count * 4 + pool.bytes.count
        print("  table bytes: \(size)", to: &standardError)
    }
}
