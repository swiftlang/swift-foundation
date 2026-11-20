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

// Reads DateFormatData.json and LocaleNumberData.json and writes the locale ID Swift table. The table holds the locale IDs and redirects that the date and number tables share, so an identifier resolves once for both tables.
//
// Environment:
//   - INPUT        : the directory that holds DateFormatData.json and LocaleNumberData.json
//   - OUTPUT_SWIFT : path to write the Swift table
//   - LOCALES      : comma-separated locales to include ("" = all)
//   - FALLBACK     : locale used where a language has no data ("" = root)
//
// The tool keeps a redirect only where it changes the data of either table. The date and number builders write `localeRows` in the same locale order, because they compute the included locales the same way.

import Foundation


struct LocaleResolutionData: Decodable {
    let cldrVersion: String
    /// Maps locale → group → index into that group's blocks.
    let locales: [String: [String: Int]]
    let parents: [String: String]
    let aliases: [String: String]
    let defaultScripts: [String: String]
}

@main
struct BuildLocaleIDData {
    static func main() throws {
        let options = readOptions()
        let directory = URL(fileURLWithPath: options.inputPath, isDirectory: true)
        let date = try JSONDecoder().decode(LocaleResolutionData.self, from: Data(contentsOf: directory.appendingPathComponent("DateFormatData.json")))
        let number = try JSONDecoder().decode(LocaleResolutionData.self, from: Data(contentsOf: directory.appendingPathComponent("LocaleNumberData.json")))
        precondition(Set(date.locales.keys) == Set(number.locales.keys), "DateFormatData.json and LocaleNumberData.json have different locales")
        precondition(date.parents == number.parents && date.aliases == number.aliases && date.defaultScripts == number.defaultScripts, "DateFormatData.json and LocaleNumberData.json resolve locales differently")
        precondition(date.cldrVersion == number.cldrVersion, "DateFormatData.json and LocaleNumberData.json come from different CLDR versions")

        let included = includedLocales(allLocales: Set(date.locales.keys), options: options)
        let sortedLocales = sortedByUTF8(included)
        func data(_ locale: String) -> [[String: Int]] { [date.locales[locale]!, number.locales[locale]!] }
        let (redirects, scriptRedirects) = trimmedRedirects(aliases: date.aliases, parents: date.parents, defaultScripts: date.defaultScripts, included: included, fallback: options.fallback, data: data)

        let redirectSources = sortedByUTF8(redirects.keys)
        // Store targets as identifiers, because a target can be a locale that the table doesn't include, which redirects again.
        let redirectTargets = redirectSources.map { redirects[$0]! }
        let pool = StringPool(sortedLocales + redirectSources + redirectTargets)

        // MARK: Render
        var out = fileHeader(tool: "build-locale-data", cldrVersion: date.cldrVersion, options: options, localeCount: sortedLocales.count)
        out += "package enum _LocaleIDData {\n"
        out += "    // Holds the locale to use where a language has no data. An empty value means root.\n"
        out += "    internal static let fallbackLocale: StaticString = \"\(options.fallback ?? "")\"\n\n"
        out += table("localeIDs", "UInt32", sortedLocales.map(pool.entry).map(hex), comment: "Holds the included locales, sorted by UTF-8 bytes. Each table's `localeRows` follows this order.", perLine: 8)
        out += table("redirectFrom", "UInt32", redirectSources.map(pool.entry).map(hex), comment: "Holds the identifiers that redirect to another locale, sorted by UTF-8 bytes.", perLine: 8)
        out += table("redirectTo", "UInt32", redirectTargets.map(pool.entry).map(hex), comment: "Holds the locale that each identifier in `redirectFrom` redirects to.", perLine: 8)
        out += staticString("pool", pool.bytes, comment: "Text longer than 3 UTF-8 bytes, stored once.", columns: 100)
        out += "}\n"

        try out.write(toFile: options.outputSwiftPath, atomically: true, encoding: .utf8)
        print("  locales: \(sortedLocales.count), redirects: \(redirects.count) (\(scriptRedirects) for script fallback), pool: \(pool.bytes.count) B", to: &standardError)
        print("  table bytes: \(sortedLocales.count * 4 + redirectSources.count * 8 + pool.bytes.count)", to: &standardError)
    }
}
