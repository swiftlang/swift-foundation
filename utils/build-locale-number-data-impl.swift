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

// Reads the locale number JSON and writes the locale number Swift table. This tool is stage 2 of the locale number data pipeline.
//
// Environment:
//   - INPUT        : path to the locale number JSON
//   - OUTPUT_SWIFT : path to write the Swift table
//   - LOCALES      : comma-separated locales to include ("" = all)
//   - FALLBACK     : locale used where a language has no data ("" = root)
//
// The JSON already contains each locale's values with inheritance applied, so the runtime doesn't fall back to a parent locale for a missing value.

import Foundation

@main
struct BuildLocaleNumberData {
    static func main() throws {
        let options = readOptions()
        let schema = try JSONDecoder().decode(LocaleNumberDataSchema.self, from: Data(contentsOf: URL(fileURLWithPath: options.inputPath)))

        let included = includedLocales(allLocales: Set(schema.locales.keys), options: options)
        let sortedLocales = sortedByUTF8(included)
        func blocks(_ locale: String) -> [String: Int] { schema.locales[locale]! }

        let systemsWithSymbols = symbolSystems(schema)
        precondition(systemsWithSymbols.first == "latn", "the first symbols sub-block must be latn")
        // The generated file records these positions, so that the lookup doesn't hardcode them.
        let systemsSubBlock = 0
        let firstSymbolsSubBlock = 1
        let (values, rows, localeRows) = packRows(locales: sortedLocales) { locale in
            let systems = schema.groupBlocks["systems"]![blocks(locale)["systems"]!]
            let symbols = schema.groupBlocks["symbols"]![blocks(locale)["symbols"]!]
            return [systems] + stride(from: 0, to: symbols.count, by: symbolFields.count).map { Array(symbols[$0 ..< $0 + symbolFields.count]) }
        }
        let rowWidth = firstSymbolsSubBlock + systemsWithSymbols.count

        let systems = sortedByUTF8(schema.numberingSystems.keys)
        let (systemZeros, irregularDigits) = digitTables(systems.map { schema.numberingSystems[$0]! })
        let pool = StringPool(values + systems + irregularDigits + systemsWithSymbols)
        let validRegions = regionBitmap(schema.validRegions)

        // MARK: Render
        var out = fileHeader(tool: "build-locale-data", cldrVersion: schema.cldrVersion, options: options, localeCount: sortedLocales.count)
        out += "package enum _LocaleNumberData {\n"
        out += "    // Sub-blocks in a row.\n"
        out += "    internal static let rowWidth = \(rowWidth)\n\n"
        out += "    // Holds the position of the numbering systems sub-block in each row.\n"
        out += "    internal static let systemsSubBlock = \(systemsSubBlock)\n\n"
        out += "    // Holds the position of the sub-block in each row that has the symbols of `symbolSystems[0]`. The symbols of `symbolSystems[i]` are in sub-block `firstSymbolsSubBlock + i`.\n"
        out += "    internal static let firstSymbolsSubBlock = \(firstSymbolsSubBlock)\n\n"
        out += slotEnum("SystemSlot", systemSlots, comment: "Lists the values in the systems sub-block, in order. A case's raw value is its position in the sub-block.")
        out += slotEnum("SymbolSlot", symbolFields, comment: "Lists the values in each symbols sub-block, in order. A case's raw value is its position in the sub-block.")
        out += table("symbolSystems", "UInt32", systemsWithSymbols.map(pool.entry).map(hex), comment: "Holds the numbering systems that have a symbols sub-block, in row order. Other systems use the symbols of `symbolSystems[0]`.", perLine: 8)
        out += table("values", "UInt32", values.map(pool.entry).map(hex), comment: "Holds every sub-block, with one entry for each slot. A systems sub-block holds: \(systemSlots.joined(separator: ", ")). A symbols sub-block holds: \(symbolFields.joined(separator: ", ")).", perLine: 8)
        // A row contains where each of a locale's sub-blocks starts in `values`: first the numbering systems, then the symbols for each numbering system in `symbolSystems`.
        // If two locales have the same values for every sub-block, they use the same row. For example, `en`, `en_US`, `en_GB`, `fr`, and `de` all use Latin digits and "-", so they all use row 0.
        // If two locales have the same values for a sub-block, their rows point to the same place in `values`. For example, `ar` and `ar_EG` have different numbering systems but the same symbols, so their rows share the symbols sub-blocks but not the numbering systems sub-block.
        // The tool stores sub-blocks and pooled text in the order that the locales first use them, so most of a locale's sub-blocks are next to each other.
        out += table("rows", "UInt16", rows.flatMap { $0.map(String.init) }, comment: "Holds the position in `values` where each sub-block of each row starts.", perLine: rowWidth)

        out += table("localeRows", "UInt16", localeRows.map(String.init), comment: "Holds the row in `rows` for each locale in `_LocaleIDData.localeIDs`.", perLine: 16)
        out += table("numberingSystemIDs", "UInt32", systems.map(pool.entry).map(hex), comment: "Holds the numeric numbering systems, sorted by UTF-8 bytes.", perLine: 8)
        out += table("numberingSystemZeros", "UInt32", systemZeros.map(hex), comment: "Holds the zero digit of each numbering system. The UTF-8 of each other digit differs from the zero only in the last byte. For a system in `irregularDigits`, the entry is 0x80000000 plus the system's index there.", perLine: 8)
        out += table("irregularDigits", "UInt32", irregularDigits.map(pool.entry).map(hex), comment: "Holds digits 0 through 9 of each system whose digits don't follow its zero in Unicode.", perLine: 10)
        out += table("validRegions", "UInt32", validRegions.map(hex), comment: "Holds the regions that are valid in an rg keyword, with one bit for each code. The bit for a code is (first letter - A) * 26 + (second letter - A).", perLine: 8)
        out += staticString("pool", pool.bytes, comment: "Text longer than 3 UTF-8 bytes, stored once.", columns: 100)
        out += "}\n"

        try out.write(toFile: options.outputSwiftPath, atomically: true, encoding: .utf8)
        print("  locales: \(sortedLocales.count), values: \(values.count), rows: \(rows.count), pool: \(pool.bytes.count) B", to: &standardError)
        let size = systemsWithSymbols.count * 4 + values.count * 4 + rows.count * rowWidth * 2 + sortedLocales.count * 2 + systems.count * 8 + irregularDigits.count * 4 + validRegions.count * 4 + pool.bytes.count
        print("  table bytes: \(size)", to: &standardError)
    }
}
