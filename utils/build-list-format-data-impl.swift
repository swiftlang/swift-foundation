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
// produced by utils/update-list-format-data and emits the packed C data that
// backs the _FoundationInternationalizationData library — a header of extern
// declarations plus a .c of definitions.
//
// Reads five environment variables (set by the build-list-format-data wrapper):
//   - INPUT    : path to ListFormatData.json
//   - OUTPUT_H : path where ListFormatData.h (declarations) will be written
//   - OUTPUT_C : path where ListFormatData.c (definitions) will be written
//   - LOCALES  : comma-separated locale list ("" = include all)
//   - FALLBACK : locale used when a runtime lookup misses (default: "root")
//
// The fallback locale is auto-included in the kept set, as is "root" — the
// latter is required because the runtime walk always terminates there.
//
// The big arrays are declared `INTERNAL` (see InternationalizationDataMacros.h)
// in the header and defined in the .c so the data is compiled into the library
// once rather than copied into every including translation unit. The small
// scalars (counts, fallback locale) and the struct typedefs stay in the header.
//
// The C data exposes:
//   - A pattern string pool (`_ListFormatPatterns`)
//   - A locale string pool (`_ListFormatLocales`) — every locale identifier
//     referenced by a slot or parent entry lives here exactly once. Slot and
//     parent entries reference locales by `uint16_t` index into this pool.
//     Pooling drops the per-entry overhead from 16 bytes (two/one pointers
//     plus padding) down to 4 bytes.
//   - A row table (`_ListFormatRows`), each row referencing 4 pattern indexes
//   - Nine sparse slot tables (`_ListFormatSlot_<Slot>`), each sorted by
//     locale identifier for binary search
//   - A sparse parent map (`_ListFormatParents`), sorted by child for binary
//     search
//   - A `_ListFormatFallbackLocale` constant holding the configured fallback
//
// The declarations and definitions are wrapped in `#if !FOUNDATION_LIST_FORMAT_ICU`.

import Foundation

// MARK: - Options

// The five inputs, read from the environment by `readOptions()`.
struct Options {
    let inputPath: String
    let outputHeaderPath: String
    let outputSourcePath: String
    let requestedLocales: Set<String>? // nil = include all locales
    let fallback: String
}

// MARK: - Packed data

// Everything the emitters need, after subsetting, transitive pruning, and
// locale pooling. `pack()` produces one of these; `renderHeader`/`renderSource`
// consume it.
struct PackedData {
    let patterns: [String]
    let rows: [ListFormatDataSchema.Row]
    let localePool: [String]
    let localeID: [String: Int]
    let slots: [(cName: String, map: [String: Int])]
    let parents: [String: String]
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
    guard let outputHeaderPath = env["OUTPUT_H"], !outputHeaderPath.isEmpty else {
        fatalError("OUTPUT_H environment variable not set")
    }
    guard let outputSourcePath = env["OUTPUT_C"], !outputSourcePath.isEmpty else {
        fatalError("OUTPUT_C environment variable not set")
    }
    let localesArg = env["LOCALES"] ?? ""
    let fallback = env["FALLBACK"] ?? "root"
    let requestedLocales: Set<String>? =
        localesArg.isEmpty
        ? nil
        : Set(localesArg.split(separator: ",").map(String.init))
    return Options(
        inputPath: inputPath,
        outputHeaderPath: outputHeaderPath,
        outputSourcePath: outputSourcePath,
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

    print("  patterns: \(data.patterns.count), rows: \(data.rows.count)", to: &standardError)
    print("  slot entries kept: \(filteredSlots.values.reduce(0) { $0 + $1.count })", to: &standardError)
    print("  parent entries kept: \(filteredParents.count)", to: &standardError)

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

    // Every locale string referenced by a slot or parent entry lives in a single
    // pool; slot/parent rows reference it by index. The pool is sorted
    // alphabetically so it's easy to diff across builds.
    var localeSet = Set<String>()
    for (_, map) in filteredSlots {
        for locale in map.keys { localeSet.insert(locale) }
    }
    for (child, parent) in filteredParents {
        localeSet.insert(child)
        localeSet.insert(parent)
    }
    let localePool = localeSet.sorted()
    let localeID: [String: Int] = Dictionary(uniqueKeysWithValues: localePool.enumerated().map { ($1, $0) })

    print("  unique locale strings: \(localePool.count)", to: &standardError)

    // Slot C identifiers, paired with their entry maps, in the canonical order.
    let slots: [(cName: String, map: [String: Int])] = listFormatSlotNames.map { slotName in
        let cName = "_ListFormatSlot_\(slotName.split(separator: "_").map { $0.capitalized }.joined())"
        return (cName, filteredSlots[slotName] ?? [:])
    }

    return PackedData(
        patterns: filteredPatterns,
        rows: filteredRows,
        localePool: localePool,
        localeID: localeID,
        slots: slots,
        parents: filteredParents,
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

// Header — typedefs, counts, and extern declarations.
func renderHeader(_ p: PackedData) -> String {
    var header = banner(p)
    header += "#include \"InternationalizationDataMacros.h\"\n\n"
    header += "#if !FOUNDATION_LIST_FORMAT_ICU\n\n"
    header += "#include <stdint.h>\n\n"

    // Struct typedefs (shared by the .c definitions and the Swift importer).
    header += "// Row table. Each row is four indexes into _ListFormatPatterns.\n"
    header += "typedef struct { uint16_t start; uint16_t middle; uint16_t end; uint16_t pair; } _ListFormatRow;\n\n"
    header += "// Sparse slot entry: maps a locale (by index into _ListFormatLocales)\n"
    header += "// to a row index. Entries are sorted by locale for binary search.\n"
    header += "typedef struct { uint16_t locale; uint16_t row; } _ListFormatSlotEntry;\n\n"
    header += "// Parent-locale entry: child and parent are indexes into _ListFormatLocales.\n"
    header += "typedef struct { uint16_t child; uint16_t parent; } _ListFormatParentEntry;\n\n"

    // Element counts and the fallback locale stay in the header as small scalars
    // so the Swift side reads them as plain constants (no link-time symbol).
    header += "static const uint16_t _ListFormatPatternCount = \(p.patterns.count);\n"
    header += "static const uint16_t _ListFormatRowCount = \(p.rows.count);\n"
    header += "static const uint16_t _ListFormatLocaleCount = \(p.localePool.count);\n"
    for (cName, map) in p.slots {
        header += "static const uint16_t \(cName)_Count = \(map.count);\n"
    }
    header += "static const uint16_t _ListFormatParentCount = \(p.parents.count);\n"
    header += "static const char * const _ListFormatFallbackLocale = \(cStringLiteral(p.fallback));\n\n"

    // Extern declarations of the large arrays. The bounds matter: the Swift
    // importer maps a bounded C array to a fixed-size tuple, which the runtime
    // lookup takes the address of. The definitions live in ListFormatData.c.
    header += "// Pattern string pool. Rows reference these by index.\n"
    header += "INTERNAL const char * const _ListFormatPatterns[\(p.patterns.count)];\n\n"
    header += "// Row table. Each row is four indexes into _ListFormatPatterns.\n"
    header += "INTERNAL const _ListFormatRow _ListFormatRows[\(p.rows.count)];\n\n"
    header += "// Locale string pool. Slot and parent entries reference these by index.\n"
    header += "INTERNAL const char * const _ListFormatLocales[\(p.localePool.count)];\n\n"
    header += "// Sparse slot tables, one per (type, width), sorted by locale.\n"
    for (cName, map) in p.slots {
        header += "INTERNAL const _ListFormatSlotEntry \(cName)[\(map.count)];\n"
    }
    header += "\n"
    header += "// Parent-locale map (explicit CLDR <parentLocales> overrides), sorted by child.\n"
    header += "INTERNAL const _ListFormatParentEntry _ListFormatParents[\(p.parents.count)];\n\n"

    header += "#endif // !FOUNDATION_LIST_FORMAT_ICU\n"
    return header
}

// Source — array definitions.
func renderSource(_ p: PackedData) -> String {
    var source = banner(p)
    source += "#include \"ListFormatData.h\"\n\n"
    source += "#if !FOUNDATION_LIST_FORMAT_ICU\n\n"

    // Pattern pool — every unique pattern string lives here exactly once.
    source += "const char * const _ListFormatPatterns[\(p.patterns.count)] = {\n"
    for pattern in p.patterns {
        source += "    \(cStringLiteral(pattern)),\n"
    }
    source += "};\n\n"

    // Row table — every unique (start, middle, end, pair) combination lives here once.
    source += "const _ListFormatRow _ListFormatRows[\(p.rows.count)] = {\n"
    for r in p.rows {
        source += "    { \(r.start), \(r.middle), \(r.end), \(r.pair) },\n"
    }
    source += "};\n\n"

    // Locale string pool — sorted alphabetically so the locale IDs assigned below
    // follow alphabetical order, keeping the slot tables sortable by ID without
    // changing their lookup order.
    source += "const char * const _ListFormatLocales[\(p.localePool.count)] = {\n"
    for locale in p.localePool {
        source += "    \(cStringLiteral(locale)),\n"
    }
    source += "};\n\n"

    // Per-slot sparse tables. Sorted by locale ID (mirroring alphabetical order of
    // the pooled strings) so binary search can compare via
    // `strcmp(target, _ListFormatLocales[entry.locale])`.
    for (cName, map) in p.slots {
        source += "const _ListFormatSlotEntry \(cName)[\(map.count)] = {\n"
        for locale in map.keys.sorted() {
            source += "    { \(p.localeID[locale]!), \(map[locale]!) },\n"
        }
        source += "};\n\n"
    }

    // Parent map — sorted by child for binary search. Both child and parent pull
    // their string from _ListFormatLocales.
    source += "const _ListFormatParentEntry _ListFormatParents[\(p.parents.count)] = {\n"
    for child in p.parents.keys.sorted() {
        source += "    { \(p.localeID[child]!), \(p.localeID[p.parents[child]!]!) },\n"
    }
    source += "};\n\n"

    source += "#endif // !FOUNDATION_LIST_FORMAT_ICU\n"
    return source
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

func cStringLiteral(_ s: String) -> String {
    var out = "\""
    for scalar in s.unicodeScalars {
        switch scalar {
        case "\\": out += "\\\\"
        case "\"": out += "\\\""
        case "\n": out += "\\n"
        case "\r": out += "\\r"
        case "\t": out += "\\t"
        default:
            // C strings accept UTF-8 bytes directly; escape only control
            // characters (so the source stays reviewable).
            if scalar.value < 0x20 || scalar.value == 0x7F {
                out += String(format: "\\x%02x", scalar.value)
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
    writeFile(renderHeader(packed), to: options.outputHeaderPath)
    writeFile(renderSource(packed), to: options.outputSourcePath)
}

// MARK: - Entry

@main
struct BuildListFormatData {
    static func main() {
        build()
    }
}
