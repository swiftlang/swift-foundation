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

// Writes packed Swift tables for the stage 2 tools.

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

/// Returns the locales to include: the requested ones that the data has, root, and the fallback locale.
func includedLocales(allLocales: Set<String>, options: Options) -> Set<String> {
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
    return included
}

/// Sorts by UTF-8 bytes, the order the binary search uses.
func sortedByUTF8(_ strings: some Sequence<String>) -> [String] {
    strings.sorted { Array($0.utf8).lexicographicallyPrecedes(Array($1.utf8)) }
}

// MARK: - Strings

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
        // Text is valid UTF-8, so only substrings on character boundaries can match.
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

// MARK: - Subsetting

/// Returns the included locale that `locale` resolves to, following `redirects` and truncation as the library does. In case that we reach a locale that's not included, return the fallback locale, else root.
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

/// Returns the redirects and how many of them are for script fallback.
///
/// Candidates are every alias, the parent of every excluded locale, and script fallback, such as en_Latn_GB to en_GB. Only keep the redirects that change the data associated with the locale.
func trimmedRedirects<Data: Equatable>(aliases: [String: String], parents: [String: String], defaultScripts: [String: String], included: Set<String>, fallback: String?, data: (String) -> Data) -> (redirects: [String: String], scriptFallbackCount: Int) {
    var candidates = aliases
    for (child, parentLocale) in parents where !included.contains(child) {
        candidates[child] = candidates[child] ?? parentLocale
    }
    var redirects: [String: String] = [:]
    for (source, target) in candidates.sorted(by: { $0.key < $1.key }) {
        var without = candidates
        without[source] = nil
        let wanted = resolve(source, included: included, redirects: candidates, fallback: fallback)
        let plain = resolve(source, included: included, redirects: without, fallback: fallback)
        if data(wanted) != data(plain) {
            redirects[source] = target
        }
    }
    // Dropping a redirect can change another that went through it, so check again with the kept set.
    for source in candidates.keys {
        let expected = data(resolve(source, included: included, redirects: candidates, fallback: fallback))
        let actual = data(resolve(source, included: included, redirects: redirects, fallback: fallback))
        precondition(expected == actual, "trimming redirects changed \(source)")
    }
    let count = redirects.count
    redirects = scriptFallbackRedirects(included: included, icuRedirects: candidates, defaultScripts: defaultScripts, redirects: redirects) { identifier, redirects in
        data(resolve(identifier, included: included, redirects: redirects, fallback: fallback))
    }
    return (redirects, redirects.count - count)
}

func packRows(locales: [String], subBlocks: (String) -> [[String?]]) -> (values: [String?], rows: [[Int]], localeRows: [Int]) {
    var values: [String?] = []
    var subBlockStarts: [[String?]: Int] = [:]
    var rows: [[Int]] = []
    var rowIndexes: [[Int]: Int] = [:]
    var localeRows: [Int] = []
    for locale in locales {
        let row = subBlocks(locale).map { subBlock in
            if let start = subBlockStarts[subBlock] {
                return start
            }
            let start = values.count
            subBlockStarts[subBlock] = start
            values += subBlock
            return start
        }
        if rowIndexes[row] == nil {
            rowIndexes[row] = rows.count
            rows.append(row)
        }
        localeRows.append(rowIndexes[row]!)
    }
    precondition(values.count <= 1 << 16 && rows.count <= 1 << 16, "too many sub-blocks or rows for UInt16 indexes")
    return (values, rows, localeRows)
}

// MARK: - Digits and regions

/// Returns each system's zero entry and the digits that a zero entry can't encode. A zero entry is the zero's scalar value when the system's other digits follow it in Unicode, else 0x80000000 plus the system's index in `irregularDigits`.
func digitTables(_ digitLists: [[String]]) -> (zeros: [UInt32], irregularDigits: [String]) {
    var irregularDigits: [String] = []
    let zeros: [UInt32] = digitLists.map { digits in
        let utf8 = digits.map { Array($0.utf8) }
        if digits.allSatisfy({ $0.unicodeScalars.count == 1 }) && utf8.indices.allSatisfy({ utf8[$0].dropLast() == utf8[0].dropLast() && utf8[$0].last! == utf8[0].last! + UInt8($0) }) {
            return digits[0].unicodeScalars.first!.value
        }
        irregularDigits += digits
        return 0x8000_0000 | UInt32(irregularDigits.count / 10 - 1)
    }
    return (zeros, irregularDigits)
}

/// Returns a bitmap with one bit for each two-letter region code, AA through ZZ, set for each code in `regions`. The bit for a code is (first letter - A) * 26 + (second letter - A).
func regionBitmap(_ regions: [String]) -> [UInt32] {
    var bitmap = [UInt32](repeating: 0, count: (26 * 26 + 31) / 32)
    for region in regions {
        let letters = Array(region.utf8)
        precondition(letters.count == 2 && letters.allSatisfy { $0 >= UInt8(ascii: "A") && $0 <= UInt8(ascii: "Z") }, "bad region \(region)")
        let bit = Int(letters[0] - UInt8(ascii: "A")) * 26 + Int(letters[1] - UInt8(ascii: "A"))
        bitmap[bit / 32] |= 1 << (bit % 32)
    }
    return bitmap
}

// MARK: - Swift output

func hex(_ value: UInt32) -> String {
    String(format: "0x%08X", value)
}

func table(_ property: String, _ type: String, _ values: [String], comment: String, perLine: Int) -> String {
    var out = "    // \(comment)\n    internal static let \(property): InlineArray<\(values.count), \(type)> = [\n"
    for start in stride(from: 0, to: values.count, by: perLine) {
        out += "        " + values[start..<min(start + perLine, values.count)].joined(separator: ", ") + ",\n"
    }
    return out + "    ]\n\n"
}

/// Returns the declaration of an enum whose cases name `slots`, in order, so that each case's raw value is its slot.
func slotEnum(_ name: String, _ slots: [String], comment: String) -> String {
    let keywords: Set<String> = ["default", "case", "class", "enum", "func", "init", "let", "return", "self", "struct", "var"]
    let cases = slots.map { keywords.contains($0) ? "`\($0)`" : $0 }
    return "    // \(comment)\n    internal enum \(name) : Int {\n        case \(cases.joined(separator: ", "))\n    }\n\n"
}

/// Returns the declaration of a multiline `StaticString` of `bytes`, with everything outside printable ASCII escaped.
/// The declaration is `package` because `LocaleDataTable` requires `pool`.
func staticString(_ property: String, _ bytes: [UInt8], comment: String, columns: Int) -> String {
    let text = String(decoding: bytes, as: UTF8.self)
    precondition(Array(text.utf8) == bytes, "\(property) isn't valid UTF-8")
    let out = "    // \(comment)\n    package static let \(property): StaticString = \"\"\"\n"
    var lines = [""]
    for scalar in text.unicodeScalars {
        if lines[lines.count - 1].utf8.count >= columns {
            lines.append("")
        }
        switch scalar {
        case "\\": lines[lines.count - 1] += "\\\\"
        case "\"": lines[lines.count - 1] += "\\\""
        case " " ... "~": lines[lines.count - 1].unicodeScalars.append(scalar)
        default: lines[lines.count - 1] += "\\u{\(String(scalar.value, radix: 16, uppercase: true))}"
        }
    }
    // End each line but the last with a backslash so the line breaks aren't part of the string.
    return out + "        " + lines.joined(separator: "\\\n        ") + "\n        \"\"\"\n\n"
}

func fileHeader(tool: String, cldrVersion: String, options: Options, localeCount: Int) -> String {
    """
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
    // Generated by utils/\(tool). Do not edit by hand.
    // CLDR version: \(cldrVersion)
    // Locales: \(options.requestedLocales == nil ? "all" : "\(localeCount)")
    // Fallback: \(options.fallback ?? "root")
    //===----------------------------------------------------------------------===//

    // Each string is a 4-byte entry. The lowest byte holds the string's length in UTF-8 bytes.
    // - If the length is in 1...3, the string content is in the other bytes, starting with the second-lowest byte.
    // - For a longer string, the other 3 bytes hold its offset in `pool`.
    // - An entry of 0 means that the slot has no value.
    //
    // Example:
    // 0x00002D01
    //       │ └─ 01: length 1
    //       └─── 2D: the text, "-"
    //
    // 0x00000F04
    //   │     └─ 04: length 4
    //   └─────── 00000F: offset 15 in `pool`


    """
}
