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

// Reads the date format JSON and writes the date format Swift table. This tool is stage 2 of the date format data pipeline.
//
// Environment:
//   - INPUT        : path to the date format JSON
//   - OUTPUT_SWIFT : path to write the Swift table
//   - LOCALES      : comma-separated locales to include ("" = all)
//   - FALLBACK     : locale used where a language has no data ("" = root)
//
// The JSON already contains each locale's values with inheritance applied, so the runtime doesn't fall back to a parent locale for a missing value.

import Foundation

/// The slots in each group's sub-blocks, one sub-block per context and width, in slot order.
/// The raw values of `DateFormatDataGroup` must match the sub-block positions specified by these sizes.
let subBlockSizes = ["months": 12, "weekdays": 7, "quarters": 4, "eras": 2, "dayPeriods": 3, "gmt": 2, "capitalization": 10]

@main
struct BuildDateFormatData {
    static func main() throws {
        let options = readOptions()
        let schema = try JSONDecoder().decode(DateFormatDataSchema.self, from: Data(contentsOf: URL(fileURLWithPath: options.inputPath)))

        let included = includedLocales(allLocales: Set(schema.locales.keys), options: options)
        let sortedLocales = sortedByUTF8(included)
        func blocks(_ locale: String) -> [String: Int] { schema.locales[locale]! }

        let subBlocks = dateFormatGroups.flatMap { group in
            let size = subBlockSizes[group]!
            precondition(schema.groupSlots[group]!.count % size == 0, "\(group) doesn't split into sub-blocks of \(size)")
            return stride(from: 0, to: schema.groupSlots[group]!.count, by: size).map { (group: group, slots: $0 ..< $0 + size) }
        }
        let (names, rows, localeRows) = packRows(locales: sortedLocales) { locale in
            subBlocks.map { Array(schema.groupBlocks[$0.group]![blocks(locale)[$0.group]!][$0.slots]) }
        }

        let pool = StringPool(names + schema.hanidaysDays)

        // MARK: Render
        var out = fileHeader(tool: "build-locale-data", cldrVersion: schema.cldrVersion, options: options, localeCount: sortedLocales.count)
        out += "package enum _DateFormatData {\n"
        out += "    // Sub-blocks in a row.\n"
        out += "    internal static let rowWidth = \(subBlocks.count)\n\n"

        // Split each locale's names into sub-blocks: one sub-block for each group, context, and width. For example, the 12 abbreviated format month names are one sub-block.
        out += table("names", "UInt32", names.map(pool.entry).map(hex), comment: "Every sub-block, one entry per slot.", perLine: 8)

        // A row contains where each of a locale's sub-blocks starts in `names`.
        // If two locales have the same values for every sub-block, they use the same row. For example, `ar`, `ar_EG`, and `ar_SA` all use row 5.
        // If two locales have the same values for a sub-block, their rows point to the same place in `names`. For example, the rows of `en` and `en_GB` point to the same place for 26 of their 28 sub-blocks. They differ only in the day periods.
        // The tool stores sub-blocks and pooled text in the order that the locales first use them, so most of a locale's sub-blocks are next to each other.
        out += table("rows", "UInt16", rows.flatMap { $0.map(String.init) }, comment: "Where each row's sub-blocks start in `names`, in DateFormatDataGroup order.", perLine: subBlocks.count)

        out += table("localeRows", "UInt16", localeRows.map(String.init), comment: "Holds the row in `rows` for each locale in `_LocaleIDData.localeIDs`.", perLine: 16)
        out += table("hanidaysDays", "UInt32", schema.hanidaysDays.map(pool.entry).map(hex), comment: "Days 1 through 31 for numbers=hanidays.", perLine: 8)
        out += staticString("pool", pool.bytes, comment: "Text longer than 3 UTF-8 bytes, stored once.", columns: 100)
        out += "}\n"

        try out.write(toFile: options.outputSwiftPath, atomically: true, encoding: .utf8)
        print("  locales: \(sortedLocales.count), names: \(names.count), rows: \(rows.count), pool: \(pool.bytes.count) B", to: &standardError)
        let size = names.count * 4 + rows.count * subBlocks.count * 2 + sortedLocales.count * 2 + schema.hanidaysDays.count * 4 + pool.bytes.count
        print("  table bytes: \(size)", to: &standardError)
    }
}
