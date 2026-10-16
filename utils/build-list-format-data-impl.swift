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

// Stage 2 of the list-format data pipeline: reads the JSON intermediate
// produced by utils/update-list-format-data and emits the packed Swift data
// that backs the _FoundationInternationalizationData library — a single
// ListFormatData.swift of `static let` constants.
//
// Reads four environment variables (set by the build-list-format-data wrapper):
//   - INPUT        : path to ListFormatData.json
//   - OUTPUT_SWIFT : path where ListFormatData.swift will be written
//   - LOCALES      : comma-separated locale list ("" = include all)
//   - FALLBACK     : locale used when a runtime lookup misses (default: "root")
//
// The fallback locale is auto-included in the kept set, as is "root", the
// runtime's last resort.
//
// The tables are emitted as `static let` constants on a `_ListFormatData` enum.
// `static let` (inside a type, not top-level `let`) lets the compiler bake the
// tables into read-only `__TEXT,__const`, with no load-time initializer and no
// per-access `swift_once` guard in the package build.
//
// The Swift data exposes (all `internal`: the lookup code that reads them lives
// in the same module, in a hand-written companion file, so nothing crosses the
// module boundary — keeping the numeric tables baked in read-only data even in
// the framework's library-evolution build):
//   - A pattern string pool (`patternBytes`, `patternOffsets`): the UTF-8 bytes
//     of every pattern, and where each one starts. Pattern `i` is the bytes from
//     `patternOffsets[i]` up to `patternOffsets[i + 1]`.
//   - A locale string pool (`localeBytes`, `localeOffsets`) in the same form —
//     every locale identifier referenced by a locale or redirect entry lives
//     here exactly once. Entries reference locales by `UInt16` index into it.
//   - A row table (`rows`), each `_ListFormatRow` referencing 4 pattern indexes
//   - A locale table (`locales`), sorted by locale identifier for binary search,
//     mapping each listed locale to its resolved rows in `slotRows`, one row
//     per slot
//   - A sparse redirect map (`redirects`), sorted by source for binary search
//   - A `fallbackLocale` constant holding the configured fallback
//
// The declarations are wrapped in `#if !FOUNDATION_LIST_FORMAT_ICU`.

import Foundation

// MARK: - Options

// The four inputs, read from the environment by `readOptions()`.
struct Options {
    let inputPath: String
    let outputSwiftPath: String
    let requestedLocales: Set<String>? // nil = include all locales
    let fallback: String
}

// MARK: - Packed data

// Everything the emitter needs, after subsetting, transitive pruning, and
// locale pooling. `pack()` produces one of these; `renderSwift` consumes it.
struct PackedData {
    let patterns: [String]
    let rows: [ListFormatDataSchema.Row]
    let localePool: [String]
    let localeID: [String: Int]
    // Each listed locale's index into `slotRows`.
    let localeSlotRows: [String: Int]
    // Each distinct set of resolved rows, one row per slot in `listFormatSlotNames` order.
    let slotRows: [[Int]]
    // Explicit locale redirects consulted during the fallback walk: CLDR
    // <parentLocales> overrides merged with the locale aliases. Both are "when
    // you see this locale, go to that one instead" — an alias fires because the
    // source has no data of its own, a parent-override because CLDR routes the
    // fallback somewhere other than the truncated locale.
    let redirects: [String: String]
    let cldrVersion: String
    let keepAll: Bool
    let keptLocalesSorted: [String] // for the banner; empty when keepAll
    let fallback: String
}

// MARK: - Inputs

func readOptions() -> Options {
    let env = ProcessInfo.processInfo.environment
    guard let inputPath = env["INPUT"], !inputPath.isEmpty else {
        fatalError("INPUT environment variable not set")
    }
    guard let outputSwiftPath = env["OUTPUT_SWIFT"], !outputSwiftPath.isEmpty else {
        fatalError("OUTPUT_SWIFT environment variable not set")
    }
    let localesArg = env["LOCALES"] ?? ""
    let fallback = env["FALLBACK"] ?? "root"
    let requestedLocales: Set<String>? =
        localesArg.isEmpty
        ? nil
        : Set(localesArg.split(separator: ",").map(String.init))
    return Options(
        inputPath: inputPath,
        outputSwiftPath: outputSwiftPath,
        requestedLocales: requestedLocales,
        fallback: fallback
    )
}

// MARK: - Load JSON

func loadData(_ path: String) -> ListFormatDataSchema {
    let bytes: Data
    do {
        bytes = try Data(contentsOf: URL(fileURLWithPath: path))
    } catch {
        print("error: failed to read \(path): \(error)", to: &standardError)
        exit(1)
    }

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    do {
        return try decoder.decode(ListFormatDataSchema.self, from: bytes)
    } catch {
        print("error: failed to decode \(path): \(error)", to: &standardError)
        exit(1)
    }
}

// MARK: - Pack

// Subset to the requested locales, transitively prune the row and pattern pools
// to what those locales still reach, and pool the locale strings. Progress
// counts go to stderr as the work proceeds.
func pack(_ data: ListFormatDataSchema, options: Options) -> PackedData {
    // Build the set of locales to list. `root` is always listed (the runtime's
    // last resort); the fallback locale is auto-included so callers don't have
    // to remember to list it.
    let keepAll = options.requestedLocales == nil
    var kept: Set<String> = options.requestedLocales ?? []
    if !keepAll {
        kept.insert(options.fallback)
        kept.insert("root")
    }

    // Every redirect the data has: parent-overrides, aliases, and script fallback. They share the same shape
    // and are consulted at the same point in the fallback walk. A key can't legitimately be two of them, so a
    // clash means the inputs disagree.
    var candidates = data.parents
    for (source, target) in data.aliases {
        if let existing = candidates[source], existing != target {
            fatalError("redirect conflict for \(source): parent \(existing) vs alias \(target)")
        }
        candidates[source] = target
    }
    for (source, target) in data.scriptRedirects {
        precondition(candidates[source] == nil, "redirect conflict for \(source)")
        candidates[source] = target
    }

    // A locale's row in each slot, in `listFormatSlotNames` order: the nearest locale in its chain with data for
    // that slot, over all the data.
    func resolvedRows(_ locale: String) -> [Int] {
        listFormatSlotNames.map { name in
            var current = locale
            while true {
                if let row = data.slots[name]?[current] { return row }
                precondition(current != "root", "root has no \(name) data")
                current = candidates[current] ?? current.lastIndex(of: "_").map { String(current[..<$0]) } ?? "root"
            }
        }
    }

    // Each listed locale stores its resolved rows, so it needs nothing from its parents. With all locales, list
    // those with data of their own. Any other identifier resolves to the first listed locale in its chain, which
    // has the same rows.
    var listed = kept
    if keepAll {
        listed = Set(data.slots.values.flatMap { $0.keys })
        listed.insert("root")
    }
    let fallback = options.fallback
    // The listed locale an identifier resolves to, as the runtime does, or the fallback locale.
    func resolve(_ locale: String, _ redirects: [String: String]) -> String {
        var current = locale
        while !listed.contains(current) {
            if let target = redirects[current] {
                current = target
            } else if let underscore = current.lastIndex(of: "_") {
                current = String(current[..<underscore])
            } else {
                return fallback
            }
        }
        return current
    }
    // A language ICU builds uses root's rows where it has none of its own, so with a fallback locale, list it.
    if keepAll && fallback != "root" {
        for language in data.languages where resolve(language, candidates) == fallback && language != fallback {
            listed.insert(language)
        }
    }
    // Keep only the redirects that change the rows an identifier gets.
    let redirects = candidates.filter { source, _ in
        var without = candidates
        without[source] = nil
        return resolvedRows(resolve(source, candidates)) != resolvedRows(resolve(source, without))
    }
    // Dropping a redirect can change another that went through it.
    for source in candidates.keys {
        precondition(resolvedRows(resolve(source, redirects)) == resolvedRows(resolve(source, candidates)), "trimming redirects changed \(source)")
    }
    if keepAll {
        // Every identifier of a language ICU builds must get the rows the sparse walk gives it.
        let languages = Set(data.languages).union(["root"])
        for locale in Set(candidates.keys).union(candidates.values).union(data.slots.values.flatMap { $0.keys }).union(data.languages) where languages.contains(String(locale.prefix { $0 != "_" })) {
            precondition(resolvedRows(resolve(locale, redirects)) == resolvedRows(locale), "listing changed \(locale)")
        }
    }

    // Store each distinct set of resolved rows once.
    var slotRows: [[Int]] = []
    var slotRowIndexes: [[Int]: Int] = [:]
    var localeSlotRows: [String: Int] = [:]
    for locale in listed.sorted() {
        let rows = resolvedRows(locale)
        if slotRowIndexes[rows] == nil {
            slotRowIndexes[rows] = slotRows.count
            slotRows.append(rows)
        }
        localeSlotRows[locale] = slotRowIndexes[rows]!
    }

    print("  patterns: \(data.patterns.count), rows: \(data.rows.count)", to: &standardError)
    print("  locales listed: \(listed.count), distinct slot rows: \(slotRows.count)", to: &standardError)
    print("  redirect entries: \(redirects.count)", to: &standardError)

    // Find which rows the listed locales reach, then which patterns those rows
    // reference. Drop the rest and renumber what's left.
    let keptRowOldIDs = Set(slotRows.joined()).sorted()

    var patternSet = Set<Int>()
    for oldID in keptRowOldIDs {
        let r = data.rows[oldID]
        patternSet.insert(r.start)
        patternSet.insert(r.middle)
        patternSet.insert(r.end)
        patternSet.insert(r.pair)
    }
    let keptPatternOldIDs = patternSet.sorted()

    let rowOldToNew = Dictionary(uniqueKeysWithValues: keptRowOldIDs.enumerated().map { ($1, $0) })
    let patternOldToNew = Dictionary(uniqueKeysWithValues: keptPatternOldIDs.enumerated().map { ($1, $0) })

    let filteredPatterns = keptPatternOldIDs.map { data.patterns[$0] }
    let filteredRows = keptRowOldIDs.map { oldID -> ListFormatDataSchema.Row in
        let r = data.rows[oldID]
        return ListFormatDataSchema.Row(
            start: patternOldToNew[r.start]!,
            middle: patternOldToNew[r.middle]!,
            end: patternOldToNew[r.end]!,
            pair: patternOldToNew[r.pair]!
        )
    }
    let renumberedSlotRows = slotRows.map { $0.map { rowOldToNew[$0]! } }

    print("  patterns reachable: \(filteredPatterns.count)", to: &standardError)
    print("  rows reachable: \(filteredRows.count)", to: &standardError)

    // Every locale string referenced by a locale or redirect entry lives in a
    // single pool; entries reference it by index. The pool is sorted
    // alphabetically so it's easy to diff across builds.
    var localeSet = listed
    for (from, to) in redirects {
        localeSet.insert(from)
        localeSet.insert(to)
    }
    let localePool = localeSet.sorted()
    let localeID: [String: Int] = Dictionary(uniqueKeysWithValues: localePool.enumerated().map { ($1, $0) })

    print("  unique locale strings: \(localePool.count)", to: &standardError)

    return PackedData(
        patterns: filteredPatterns,
        rows: filteredRows,
        localePool: localePool,
        localeID: localeID,
        localeSlotRows: localeSlotRows,
        slotRows: renumberedSlotRows,
        redirects: redirects,
        cldrVersion: data.cldrVersion,
        keepAll: keepAll,
        keptLocalesSorted: keepAll ? [] : kept.sorted(),
        fallback: options.fallback
    )
}

// MARK: - Emit

func banner(_ p: PackedData) -> String {
    var s = ""
    s += "//===----------------------------------------------------------------------===//\n"
    s += "//\n"
    s += "// This source file is part of the Swift.org open source project\n"
    s += "//\n"
    s += "// Copyright (c) 2026 Apple Inc. and the Swift project authors\n"
    s += "// Licensed under Apache License v2.0 with Runtime Library Exception\n"
    s += "//\n"
    s += "// See https://swift.org/LICENSE.txt for license information\n"
    s += "// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors\n"
    s += "//\n"
    s += "//===----------------------------------------------------------------------===//\n"
    s += "// Generated by utils/build-list-format-data — do not edit by hand.\n"
    s += "// CLDR version: \(p.cldrVersion)\n"
    if p.keepAll {
        s += "// Locales: all\n"
    } else {
        s += "// Locales: \(p.keptLocalesSorted.joined(separator: ", "))\n"
    }
    s += "// Fallback: \(p.fallback)\n"
    s += "//===----------------------------------------------------------------------===//\n\n"
    return s
}

// Swift source — struct definitions and the `static let` constant tables.
func renderSwift(_ p: PackedData) -> String {
    var out = banner(p)
    out += "#if !FOUNDATION_LIST_FORMAT_ICU\n\n"

    // Entry struct definitions. `Sendable` so the `static let` tables are usable
    // from any isolation. The unlabeled initializers keep the
    // generated table literals compact.
    out += "// Row table entry. Each row is four indexes into the pattern pool.\n"
    out += "internal struct _ListFormatRow: Sendable {\n"
    out += "    internal let start: UInt16\n"
    out += "    internal let middle: UInt16\n"
    out += "    internal let end: UInt16\n"
    out += "    internal let pair: UInt16\n"
    out += "    internal init(_ start: UInt16, _ middle: UInt16, _ end: UInt16, _ pair: UInt16) {\n"
    out += "        self.start = start\n"
    out += "        self.middle = middle\n"
    out += "        self.end = end\n"
    out += "        self.pair = pair\n"
    out += "    }\n"
    out += "}\n\n"

    out += "// Locale table entry: maps a locale (by index into the locale pool)\n"
    out += "// to its resolved rows' index in `slotRows`. Sorted by locale for binary search.\n"
    out += "internal struct _ListFormatLocaleEntry: Sendable {\n"
    out += "    internal let locale: UInt16\n"
    out += "    internal let slotRows: UInt16\n"
    out += "    internal init(_ locale: UInt16, _ slotRows: UInt16) {\n"
    out += "        self.locale = locale\n"
    out += "        self.slotRows = slotRows\n"
    out += "    }\n"
    out += "}\n\n"

    out += "// A directed pair of locales, both indexes into the locale pool. Backs\n"
    out += "// the `redirects` table: a parent-locale override (child → CLDR parent) or\n"
    out += "// an alias (deprecated/under-specified id → canonical target). Sorted by\n"
    out += "// `from` for binary search.\n"
    out += "internal struct _ListFormatLocalePair: Sendable {\n"
    out += "    internal let from: UInt16\n"
    out += "    internal let to: UInt16\n"
    out += "    internal init(_ from: UInt16, _ to: UInt16) {\n"
    out += "        self.from = from\n"
    out += "        self.to = to\n"
    out += "    }\n"
    out += "}\n\n"

    // The data itself. `static let` on an enum (rather than top-level `let`) lets
    // the compiler bake the tables into read-only `__TEXT,__const`, with no
    // load-time initializer and no per-access `swift_once` guard in the package build.
    out += "internal enum _ListFormatData {\n"
    out += "    // Locale used when a runtime lookup misses.\n"
    out += "    internal static let fallbackLocale: StaticString = \(swiftStringLiteral(p.fallback))\n\n"

    // Pattern pool — every unique pattern string lives here exactly once.
    out += stringPool(p.patterns, name: "pattern", comment: "Pattern string pool. Rows reference these by index.")

    // Row table — every unique (start, middle, end, pair) combination lives here once.
    out += "    // Row table. Each row is four indexes into the pattern pool.\n"
    out += "    internal static let rows: InlineArray<\(p.rows.count), _ListFormatRow> = [\n"
    for r in p.rows {
        out += "        _ListFormatRow(\(r.start), \(r.middle), \(r.end), \(r.pair)),\n"
    }
    out += "    ]\n\n"

    // Locale string pool — sorted alphabetically so the locale IDs assigned below
    // follow alphabetical order, keeping the slot tables sortable by ID without
    // changing their lookup order.
    out += stringPool(p.localePool, name: "locale", comment: "Locale string pool. Locale and redirect entries reference these by index.")

    out += "    // Listed locales, sorted by locale.\n"
    out += "    internal static let locales: InlineArray<\(p.localeSlotRows.count), _ListFormatLocaleEntry> = [\n"
    for locale in p.localeSlotRows.keys.sorted() {
        out += "        _ListFormatLocaleEntry(\(p.localeID[locale]!), \(p.localeSlotRows[locale]!)),\n"
    }
    out += "    ]\n\n"

    out += "    // Each distinct set of resolved rows: and wide, short, narrow, then or wide, short, narrow.\n"
    out += "    internal static let slotRows: InlineArray<\(p.slotRows.count * listFormatSlotNames.count), UInt16> = [\n"
    for rows in p.slotRows {
        out += "        " + rows.map { "\($0)," }.joined(separator: " ") + "\n"
    }
    out += "    ]\n\n"

    // Redirect map — sorted by source locale for binary search. Both ends pull
    // their string from the locale pool. Holds CLDR <parentLocales> overrides and
    // locale aliases; the runtime treats them uniformly (consult before
    // truncating in the fallback walk).
    out += "    // Locale redirect map (CLDR <parentLocales> overrides + aliases), sorted by source.\n"
    out += "    internal static let redirects: InlineArray<\(p.redirects.count), _ListFormatLocalePair> = [\n"
    for from in p.redirects.keys.sorted() {
        out += "        _ListFormatLocalePair(\(p.localeID[from]!), \(p.localeID[p.redirects[from]!]!)),\n"
    }
    out += "    ]\n"

    out += "}\n\n"
    out += "#endif // !FOUNDATION_LIST_FORMAT_ICU\n"
    return out
}

// MARK: - Write

func writeFile(_ contents: String, to path: String) {
    do {
        try contents.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
    } catch {
        print("error: failed to write output: \(error)", to: &standardError)
        exit(1)
    }
}

// MARK: - Helpers

// A string pool as two tables: `<name>Bytes`, the UTF-8 bytes of every string,
// one string per line with the string in a comment, and `<name>Offsets`, where
// each string starts, plus the end.
func stringPool(_ strings: [String], name: String, comment: String) -> String {
    var bytes = ""
    var offsets = [0]
    for string in strings {
        let utf8 = Array(string.utf8)
        bytes += "        " + utf8.map { String(format: "0x%02X,", $0) }.joined(separator: " ") + " // \(swiftStringLiteral(string))\n"
        offsets.append(offsets.last! + utf8.count)
    }
    precondition(offsets.last! <= Int(UInt16.max), "\(name) pool exceeds UInt16 offsets")
    var out = "    // \(comment)\n"
    out += "    internal static let \(name)Bytes: InlineArray<\(offsets.last!), UInt8> = [\n" + bytes + "    ]\n\n"
    out += "    // Where each string in `\(name)Bytes` starts, then where the last one ends.\n"
    out += "    internal static let \(name)Offsets: InlineArray<\(offsets.count), UInt16> = [\n"
    for start in stride(from: 0, to: offsets.count, by: 16) {
        out += "        " + offsets[start..<min(start + 16, offsets.count)].map { "\($0)," }.joined(separator: " ") + "\n"
    }
    return out + "    ]\n\n"
}

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
            // Swift string literals accept UTF-8 content directly; escape only
            // control characters (so the source stays reviewable).
            if scalar.value < 0x20 || scalar.value == 0x7F {
                out += String(format: "\\u{%02x}", scalar.value)
            } else {
                out += String(scalar)
            }
        }
    }
    out += "\""
    return out
}

// MARK: - Driver

func build() {
    let options = readOptions()
    let data = loadData(options.inputPath)
    let packed = pack(data, options: options)
    writeFile(renderSwift(packed), to: options.outputSwiftPath)
}

// MARK: - Entry

@main
struct BuildListFormatData {
    static func main() {
        build()
    }
}
