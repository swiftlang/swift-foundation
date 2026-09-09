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
// The fallback locale is auto-included in the kept set, as is "root" — the
// latter is required because the runtime walk always terminates there.
//
// The tables are emitted as `static let` constants on a `_ListFormatData` enum.
// `static let` (inside a type, not top-level `let`) lets the compiler bake the
// numeric tables into read-only `__TEXT,__const` and the `StaticString` pools
// into `__DATA_CONST`, with no load-time initializer and no per-access
// `swift_once` guard in the package build. `StaticString` gives compile-time
// UTF-8 bytes the runtime wraps into a `Span<UInt8>` with no allocation.
//
// The Swift data exposes (all `internal`: the lookup code that reads them lives
// in the same module, in a hand-written companion file, so nothing crosses the
// module boundary — keeping the numeric tables baked in read-only data even in
// the framework's library-evolution build):
//   - A pattern string pool (`patterns`) as `InlineArray<N, StaticString>`
//   - A locale string pool (`locales`) — every locale identifier referenced by
//     a slot or parent entry lives here exactly once. Slot and parent entries
//     reference locales by `UInt16` index into this pool. Pooling keeps the
//     per-entry overhead down to 4 bytes.
//   - A row table (`rows`), each `_ListFormatRow` referencing 4 pattern indexes
//   - Six sparse slot tables (`slot<Slot>`), each sorted by locale identifier
//     for binary search
//   - A sparse parent map (`parents`), sorted by child for binary search
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
    let slots: [(swiftName: String, map: [String: Int])]
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
    // Build the set of locales to retain. `root` is always kept (terminating the
    // runtime walk); the fallback locale is auto-included so callers don't have
    // to remember to list it.
    let keepAll = options.requestedLocales == nil
    var kept: Set<String> = options.requestedLocales ?? []
    if !keepAll {
        kept.insert(options.fallback)
        kept.insert("root")
    }
    func isKept(_ locale: String) -> Bool { keepAll || kept.contains(locale) }

    // Locale aliases redirect a requested identifier to a canonical one
    // (zh_HK → zh_Hant_HK). Keep an alias when its source survives the subset,
    // and pull the target into the kept set so the redirect lands on a locale
    // whose slot data is retained. Under keepAll both are already present, so
    // this only matters on the --locales subset path.
    var keptAliases: [String: String] = [:]
    for (source, target) in data.aliases where isKept(source) {
        keptAliases[source] = target
        kept.insert(target)
    }

    var filteredSlots: [String: [String: Int]] = [:]
    for (name, map) in data.slots {
        var filtered: [String: Int] = [:]
        for (locale, rowId) in map where isKept(locale) {
            filtered[locale] = rowId
        }
        filteredSlots[name] = filtered
    }

    var filteredParents: [String: String] = [:]
    for (child, parent) in data.parents where isKept(child) {
        filteredParents[child] = parent
    }

    // Merge parent-overrides and aliases into one redirect map: they share the
    // same shape and are consulted at the same point in the fallback walk. A key
    // can't legitimately be both (an alias has no data, a parent-override is a
    // real fallback node), so a clash means the inputs disagree.
    var redirects = filteredParents
    for (source, target) in keptAliases {
        if let existing = redirects[source], existing != target {
            fatalError("redirect conflict for \(source): parent \(existing) vs alias \(target)")
        }
        redirects[source] = target
    }

    print("  patterns: \(data.patterns.count), rows: \(data.rows.count)", to: &standardError)
    print("  slot entries kept: \(filteredSlots.values.reduce(0) { $0 + $1.count })", to: &standardError)
    print("  parent overrides kept: \(filteredParents.count), aliases kept: \(keptAliases.count)", to: &standardError)
    print("  redirect entries: \(redirects.count)", to: &standardError)

    // Walk the kept slot entries to find which rows are actually reachable, then
    // walk those rows to find which patterns are actually referenced. Drop the
    // rest and renumber what's left. When --locales is given, this is where the
    // big wins come from: the all-locales pattern pool (352) and row table (335)
    // can collapse to a few dozen entries when only a handful of locales remain.
    var rowSet = Set<Int>()
    for (_, map) in filteredSlots {
        for rowID in map.values { rowSet.insert(rowID) }
    }
    let keptRowOldIDs = rowSet.sorted()

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

    // Rewrite slot entries to reference the renumbered rows.
    for (name, map) in filteredSlots {
        var rewritten: [String: Int] = [:]
        for (locale, oldRowID) in map {
            rewritten[locale] = rowOldToNew[oldRowID]!
        }
        filteredSlots[name] = rewritten
    }

    print("  patterns reachable: \(filteredPatterns.count)", to: &standardError)
    print("  rows reachable: \(filteredRows.count)", to: &standardError)

    // Every locale string referenced by a slot or redirect entry lives in a
    // single pool; entries reference it by index. The pool is sorted
    // alphabetically so it's easy to diff across builds. Both ends of every
    // redirect go in, including alias sources (which have no slot data of their
    // own but are still indexed by a redirect entry).
    var localeSet = Set<String>()
    for (_, map) in filteredSlots {
        for locale in map.keys { localeSet.insert(locale) }
    }
    for (from, to) in redirects {
        localeSet.insert(from)
        localeSet.insert(to)
    }
    let localePool = localeSet.sorted()
    let localeID: [String: Int] = Dictionary(uniqueKeysWithValues: localePool.enumerated().map { ($1, $0) })

    print("  unique locale strings: \(localePool.count)", to: &standardError)

    // Slot Swift identifiers, paired with their entry maps, in the canonical order.
    let slots: [(swiftName: String, map: [String: Int])] = listFormatSlotNames.map { slotName in
        let swiftName = "slot" + slotName.split(separator: "_").map { $0.capitalized }.joined()
        return (swiftName, filteredSlots[slotName] ?? [:])
    }

    return PackedData(
        patterns: filteredPatterns,
        rows: filteredRows,
        localePool: localePool,
        localeID: localeID,
        slots: slots,
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

    // Entry struct definitions. `package` so FoundationInternationalization can
    // reach them across the module boundary; `Sendable` so the `static let`
    // tables are usable from any isolation. The unlabeled initializers keep the
    // generated table literals compact.
    out += "// Row table entry. Each row is four indexes into the `patterns` pool.\n"
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

    out += "// Sparse slot entry: maps a locale (by index into the `locales` pool)\n"
    out += "// to a row index. Entries are sorted by locale for binary search.\n"
    out += "internal struct _ListFormatSlotEntry: Sendable {\n"
    out += "    internal let locale: UInt16\n"
    out += "    internal let row: UInt16\n"
    out += "    internal init(_ locale: UInt16, _ row: UInt16) {\n"
    out += "        self.locale = locale\n"
    out += "        self.row = row\n"
    out += "    }\n"
    out += "}\n\n"

    out += "// A directed pair of locales, both indexes into the `locales` pool. Backs\n"
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
    // the compiler bake the numeric tables into read-only `__TEXT,__const` and the
    // `StaticString` pools into `__DATA_CONST`, with no load-time initializer and
    // no per-access `swift_once` guard in the package build.
    out += "internal enum _ListFormatData {\n"
    out += "    // Locale used when a runtime lookup misses.\n"
    out += "    internal static let fallbackLocale: StaticString = \(swiftStringLiteral(p.fallback))\n\n"

    // Pattern pool — every unique pattern string lives here exactly once.
    out += "    // Pattern string pool. Rows reference these by index.\n"
    out += "    internal static let patterns: InlineArray<\(p.patterns.count), StaticString> = [\n"
    for pattern in p.patterns {
        out += "        \(swiftStringLiteral(pattern)),\n"
    }
    out += "    ]\n\n"

    // Row table — every unique (start, middle, end, pair) combination lives here once.
    out += "    // Row table. Each row is four indexes into `patterns`.\n"
    out += "    internal static let rows: InlineArray<\(p.rows.count), _ListFormatRow> = [\n"
    for r in p.rows {
        out += "        _ListFormatRow(\(r.start), \(r.middle), \(r.end), \(r.pair)),\n"
    }
    out += "    ]\n\n"

    // Locale string pool — sorted alphabetically so the locale IDs assigned below
    // follow alphabetical order, keeping the slot tables sortable by ID without
    // changing their lookup order.
    out += "    // Locale string pool. Slot and parent entries reference these by index.\n"
    out += "    internal static let locales: InlineArray<\(p.localePool.count), StaticString> = [\n"
    for locale in p.localePool {
        out += "        \(swiftStringLiteral(locale)),\n"
    }
    out += "    ]\n\n"

    // Per-slot sparse tables. Sorted by locale ID (mirroring alphabetical order of
    // the pooled strings) so binary search can compare the target against
    // `locales[entry.locale]` byte-wise.
    out += "    // Sparse slot tables, one per (type, width), sorted by locale.\n"
    for (swiftName, map) in p.slots {
        out += "    internal static let \(swiftName): InlineArray<\(map.count), _ListFormatSlotEntry> = [\n"
        for locale in map.keys.sorted() {
            out += "        _ListFormatSlotEntry(\(p.localeID[locale]!), \(map[locale]!)),\n"
        }
        out += "    ]\n\n"
    }

    // Redirect map — sorted by source locale for binary search. Both ends pull
    // their string from `locales`. Holds CLDR <parentLocales> overrides and
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
