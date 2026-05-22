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

/*

 Stage 2 of the list-format data pipeline: reads the JSON intermediate
 produced by utils/update-list-format-data and emits a packed C header.

 Reads four environment variables (set by the build-list-format-data wrapper):
   - INPUT    : path to ListFormatData.json
   - OUTPUT   : path where ListFormatData.h will be written
   - LOCALES  : comma-separated locale list ("" = include all)
   - FALLBACK : locale used when a runtime lookup misses (default: "root")

 The fallback locale is auto-included in the kept set, as is "root" — the
 latter is required because the runtime walk always terminates there.

 The C header exposes:
   - A pattern string pool (`_ListFormatPatterns`)
   - A locale string pool (`_ListFormatLocales`) — every locale identifier
     referenced by a slot or parent entry lives here exactly once. Slot and
     parent entries reference locales by `uint16_t` index into this pool.
     Pooling drops the per-entry overhead from 16 bytes (two/one pointers
     plus padding) down to 4 bytes.
   - A row table (`_ListFormatRows`), each row referencing 4 pattern indexes
   - Nine sparse slot tables (`_ListFormatSlot_<Slot>`), each sorted by
     locale identifier for binary search
   - A sparse parent map (`_ListFormatParents`), sorted by child for binary
     search
   - A `_ListFormatFallbackLocale` constant holding the configured fallback

 The whole header is wrapped in `#if FOUNDATION_LIST_FORMAT_NATIVE`.

 */

import Foundation

// MARK: - Inputs

let env = ProcessInfo.processInfo.environment
guard let inputPath = env["INPUT"], !inputPath.isEmpty else {
    fatalError("INPUT environment variable not set")
}
guard let outputPath = env["OUTPUT"], !outputPath.isEmpty else {
    fatalError("OUTPUT environment variable not set")
}
let localesArg = env["LOCALES"] ?? ""
let fallback = env["FALLBACK"] ?? "root"

let requestedLocales: Set<String>? = localesArg.isEmpty
    ? nil
    : Set(localesArg.split(separator: ",").map(String.init))

// MARK: - Load JSON

let bytes: Data
do {
    bytes = try Data(contentsOf: URL(fileURLWithPath: inputPath))
} catch {
    FileHandle.standardError.write("error: failed to read \(inputPath): \(error)\n".data(using: .utf8)!)
    exit(1)
}

let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase
let data: ListFormatDataSchema
do {
    data = try decoder.decode(ListFormatDataSchema.self, from: bytes)
} catch {
    FileHandle.standardError.write("error: failed to decode \(inputPath): \(error)\n".data(using: .utf8)!)
    exit(1)
}

// MARK: - Subset

// Build the set of locales to retain. `root` is always kept (terminating the
// runtime walk); the fallback locale is auto-included so callers don't have
// to remember to list it.
let keepAll = requestedLocales == nil
var kept: Set<String> = requestedLocales ?? []
if !keepAll {
    kept.insert(fallback)
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

FileHandle.standardError.write("  patterns: \(data.patterns.count), rows: \(data.rows.count)\n".data(using: .utf8)!)
FileHandle.standardError.write("  slot entries kept: \(filteredSlots.values.reduce(0) { $0 + $1.count })\n".data(using: .utf8)!)
FileHandle.standardError.write("  parent entries kept: \(filteredParents.count)\n".data(using: .utf8)!)

// MARK: - Transitive row + pattern filter

// Walk the kept slot entries to find which rows are actually reachable, then
// walk those rows to find which patterns are actually referenced. Drop the
// rest and renumber what's left. When --locales is given, this is where the
// big wins come from: the all-locales pattern pool (352) and row table (335)
// can collapse to a few dozen entries when only a handful of locales remain.
var keptRowOldIDs: [Int] = []
var keptPatternOldIDs: [Int] = []
let rowOldToNew: [Int: Int]
let patternOldToNew: [Int: Int]
let filteredRows: [ListFormatDataSchema.Row]
let filteredPatterns: [String]
do {
    var rowSet = Set<Int>()
    for (_, map) in filteredSlots {
        for rowID in map.values { rowSet.insert(rowID) }
    }
    keptRowOldIDs = rowSet.sorted()

    var patternSet = Set<Int>()
    for oldID in keptRowOldIDs {
        let r = data.rows[oldID]
        patternSet.insert(r.start)
        patternSet.insert(r.middle)
        patternSet.insert(r.end)
        patternSet.insert(r.pair)
    }
    keptPatternOldIDs = patternSet.sorted()

    rowOldToNew = Dictionary(uniqueKeysWithValues: keptRowOldIDs.enumerated().map { ($1, $0) })
    patternOldToNew = Dictionary(uniqueKeysWithValues: keptPatternOldIDs.enumerated().map { ($1, $0) })

    filteredPatterns = keptPatternOldIDs.map { data.patterns[$0] }
    filteredRows = keptRowOldIDs.map { oldID in
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
}

FileHandle.standardError.write("  patterns reachable: \(filteredPatterns.count)\n".data(using: .utf8)!)
FileHandle.standardError.write("  rows reachable: \(filteredRows.count)\n".data(using: .utf8)!)

// MARK: - Locale pool

// Every locale string referenced by a slot or parent entry lives in a single
// pool; slot/parent rows reference it by index. The pool is sorted
// alphabetically so it's easy to diff across builds.
var localePool: [String] = []
do {
    var set = Set<String>()
    for (_, map) in filteredSlots {
        for locale in map.keys { set.insert(locale) }
    }
    for (child, parent) in filteredParents {
        set.insert(child)
        set.insert(parent)
    }
    localePool = set.sorted()
}
let localeID: [String: Int] = Dictionary(uniqueKeysWithValues: localePool.enumerated().map { ($1, $0) })

FileHandle.standardError.write("  unique locale strings: \(localePool.count)\n".data(using: .utf8)!)

// MARK: - Emit C header

var out = ""
out += "//===----------------------------------------------------------------------===//\n"
out += "// Generated by utils/build-list-format-data — do not edit by hand.\n"
out += "// CLDR version: \(data.cldrVersion)\n"
if keepAll {
    out += "// Locales: all\n"
} else {
    out += "// Locales: \(kept.sorted().joined(separator: ", "))\n"
}
out += "// Fallback: \(fallback)\n"
out += "//===----------------------------------------------------------------------===//\n\n"

out += "#if FOUNDATION_LIST_FORMAT_NATIVE\n\n"
out += "#include <stdint.h>\n\n"

// Pattern pool — every unique pattern string lives here exactly once.
out += "// Pattern string pool. Rows reference these by index.\n"
out += "static const char * const _ListFormatPatterns[] = {\n"
for p in filteredPatterns {
    out += "    \(cStringLiteral(p)),\n"
}
out += "};\n"
out += "static const uint16_t _ListFormatPatternCount = \(filteredPatterns.count);\n\n"

// Row table — every unique (start, middle, end, pair) combination lives here once.
out += "// Row table. Each row is four indexes into _ListFormatPatterns.\n"
out += "typedef struct { uint16_t start; uint16_t middle; uint16_t end; uint16_t pair; } _ListFormatRow;\n\n"
out += "static const _ListFormatRow _ListFormatRows[] = {\n"
for r in filteredRows {
    out += "    { \(r.start), \(r.middle), \(r.end), \(r.pair) },\n"
}
out += "};\n"
out += "static const uint16_t _ListFormatRowCount = \(filteredRows.count);\n\n"

// Locale string pool — every locale identifier referenced by a slot or
// parent entry lives here exactly once. Sorted alphabetically (so the
// locale IDs assigned below also follow alphabetical order, which keeps
// the slot tables sortable by ID without changing their lookup order).
out += "// Locale string pool. Slot and parent entries reference these by index.\n"
out += "static const char * const _ListFormatLocales[] = {\n"
for locale in localePool {
    out += "    \(cStringLiteral(locale)),\n"
}
out += "};\n"
out += "static const uint16_t _ListFormatLocaleCount = \(localePool.count);\n\n"

// Per-slot sparse tables. Sorted by locale ID (which mirrors alphabetical
// order of the pooled strings) so binary search can compare via
// `strcmp(target, _ListFormatLocales[entry.locale])`.
out += "// Sparse slot tables. Each entry maps a locale (by index into\n"
out += "// _ListFormatLocales) to a row index; entries are sorted by locale\n"
out += "// for binary search.\n"
out += "typedef struct { uint16_t locale; uint16_t row; } _ListFormatSlotEntry;\n\n"

for slotName in listFormatSlotNames {
    let map = filteredSlots[slotName] ?? [:]
    let cName = "_ListFormatSlot_\(slotName.split(separator: "_").map { $0.capitalized }.joined())"
    out += "static const _ListFormatSlotEntry \(cName)[] = {\n"
    for locale in map.keys.sorted() {
        out += "    { \(localeID[locale]!), \(map[locale]!) },\n"
    }
    out += "};\n"
    out += "static const uint16_t \(cName)_Count = \(map.count);\n\n"
}

// Parent map — sorted by child for binary search. Both child and parent
// pull their string from `_ListFormatLocales`.
out += "// Parent-locale map (explicit overrides from CLDR <parentLocales>).\n"
out += "// Truncation parents (e.g. en_AU -> en) are computed at runtime.\n"
out += "typedef struct { uint16_t child; uint16_t parent; } _ListFormatParentEntry;\n\n"
out += "static const _ListFormatParentEntry _ListFormatParents[] = {\n"
for child in filteredParents.keys.sorted() {
    out += "    { \(localeID[child]!), \(localeID[filteredParents[child]!]!) },\n"
}
out += "};\n"
out += "static const uint16_t _ListFormatParentCount = \(filteredParents.count);\n\n"

// Fallback — runtime walks the parent chain; if it exhausts without a match,
// it retries the lookup from this locale.
out += "// Fallback locale: used when a runtime walk exhausts the parent chain\n"
out += "// without matching anything else in the compiled-in data set.\n"
out += "static const char * const _ListFormatFallbackLocale = \(cStringLiteral(fallback));\n\n"

out += "#endif // FOUNDATION_LIST_FORMAT_NATIVE\n"

do {
    try out.write(to: URL(fileURLWithPath: outputPath), atomically: true, encoding: .utf8)
} catch {
    FileHandle.standardError.write("error: failed to write \(outputPath): \(error)\n".data(using: .utf8)!)
    exit(1)
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
