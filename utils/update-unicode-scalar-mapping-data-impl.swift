#!/usr/bin/env swift -D PRINT_CODE
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

This is a Swift script that converts CaseFolding.txt and UnicodeData.txt from
the Unicode Character Database (UCD) to Swift source code.
This script generates minimum code and is intended to be executed by other shell
script.

Arguments:
1. The Unicode version.
2. Optional: a directory that contains CaseFolding.txt and UnicodeData.txt.
   Without it, the script downloads both files from unicode.org.

 */

import Foundation

// MARK: - Constants

/// Base scalars at or above this value keep their diacritics.
let diacriticStrippingLimit: UInt32 = 0x0510
let diacriticStrippingBaseBitCount: UInt32 = 11
let halfwidthAndFullwidthForms: Range<UInt32> = 0xFF00 ..< 0xFFEF
let swiftCodeIndent = "    "

/// The bit layout of a case folding entry.
enum CaseFoldingLayout {
    static let firstShift = 43
    static let countShift = 34
    static let countBitCount = 8
    static let strideIsTwoShift = 33
    static let isExpansionShift = 32
    static let maximumCount = 1 << countBitCount - 1
    /// The number of scalars in each expansion, including the zero padding.
    static let expansionLength = 3
}

/// Hangul syllables decompose by formula, not through UnicodeData.txt.
enum Hangul {
    static let syllableBase: UInt32 = 0xAC00
    static let leadingConsonantBase: UInt32 = 0x1100
    static let vowelBase: UInt32 = 0x1161
    static let trailingConsonantBase: UInt32 = 0x11A7
    static let vowelCount: UInt32 = 21
    static let trailingConsonantCount: UInt32 = 28
    static let syllableCount: UInt32 = 11172
}

// MARK: - Implementation

enum CodeGenerationError: Swift.Error {
    case missingUnicodeVersion
    case invalidScalar(String)
    case invalidCombiningClass(String)
    case invalidDecomposition(String)
    case invalidURL(String)
}

func readUCDFile(named name: String, unicodeVersion: String, directory: String?) throws -> String {
    if let directory {
        return try String(contentsOf: URL(fileURLWithPath: directory).appendingPathComponent(name), encoding: .utf8)
    }
    let address = "https://www.unicode.org/Public/\(unicodeVersion)/ucd/\(name)"
    guard let url = URL(string: address) else {
        throw CodeGenerationError.invalidURL(address)
    }
    return try String(contentsOf: url, encoding: .utf8)
}

/// The fields of each line that has data, without comments.
func dataLines(_ text: String) -> [[String]] {
    text.split(separator: "\n").compactMap { line in
        let data = line.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0].trimmingCharacters(in: .whitespaces)
        guard !data.isEmpty else {
            return nil
        }
        return data.split(separator: ";", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

func scalar(_ hexadecimal: some StringProtocol) throws -> UInt32 {
    guard let value = UInt32(hexadecimal, radix: 16) else {
        throw CodeGenerationError.invalidScalar(String(hexadecimal))
    }
    return value
}

func scalars(_ hexadecimals: some StringProtocol) throws -> [UInt32] {
    try hexadecimals.split(separator: " ").map(scalar)
}

/// Full case folding: the mappings with status C and F.
func parseCaseFolding(_ text: String) throws -> [UInt32: [UInt32]] {
    var folding: [UInt32: [UInt32]] = [:]
    for fields in dataLines(text) where fields[1] == "C" || fields[1] == "F" {
        folding[try scalar(fields[0])] = try scalars(fields[2])
    }
    return folding
}

struct UnicodeData {
    var combiningClasses: [UInt32: Int] = [:]
    var canonicalDecompositions: [UInt32: [UInt32]] = [:]
    var compatibilityDecompositions: [UInt32: [UInt32]] = [:]

    init(_ text: String) throws {
        for fields in dataLines(text) {
            let value = try scalar(fields[0])
            guard let combiningClass = Int(fields[3]) else {
                throw CodeGenerationError.invalidCombiningClass(fields[3])
            }
            combiningClasses[value] = combiningClass
            let decomposition = fields[5]
            if decomposition.isEmpty {
                continue
            }
            if decomposition.hasPrefix("<") {
                guard let tagEnd = decomposition.firstIndex(of: ">") else {
                    throw CodeGenerationError.invalidDecomposition(String(decomposition))
                }
                compatibilityDecompositions[value] = try scalars(decomposition[decomposition.index(after: tagEnd)...])
            } else {
                canonicalDecompositions[value] = try scalars(decomposition)
            }
        }
    }

    func combiningClass(of value: UInt32) -> Int {
        combiningClasses[value] ?? 0
    }

    /// The full decomposition of `value`, using the first of `mappings` that contains each scalar.
    func decompose(_ value: UInt32, with mappings: [[UInt32: [UInt32]]]) -> [UInt32] {
        let syllableIndex = Int64(value) - Int64(Hangul.syllableBase)
        if syllableIndex >= 0 && syllableIndex < Int64(Hangul.syllableCount) {
            let index = UInt32(syllableIndex)
            let vowelAndTrailingCount = Hangul.vowelCount * Hangul.trailingConsonantCount
            var result = [
                Hangul.leadingConsonantBase + index / vowelAndTrailingCount,
                Hangul.vowelBase + (index % vowelAndTrailingCount) / Hangul.trailingConsonantCount,
            ]
            if index % Hangul.trailingConsonantCount != 0 {
                result.append(Hangul.trailingConsonantBase + index % Hangul.trailingConsonantCount)
            }
            return result
        }
        for mapping in mappings {
            if let decomposition = mapping[value] {
                return decomposition.flatMap { decompose($0, with: mappings) }
            }
        }
        return [value]
    }

    /// Sorts each run of non-starters by combining class, keeping the order of equal classes.
    func canonicallyOrdered(_ values: [UInt32]) -> [UInt32] {
        var result = values
        var start = 0
        while start < result.count {
            if combiningClass(of: result[start]) == 0 {
                start += 1
                continue
            }
            var end = start
            while end < result.count && combiningClass(of: result[end]) != 0 {
                end += 1
            }
            let run = result[start ..< end].enumerated().sorted {
                (combiningClass(of: $0.element), $0.offset) < (combiningClass(of: $1.element), $1.offset)
            }
            result.replaceSubrange(start ..< end, with: run.map(\.element))
            start = end
        }
        return result
    }
}

/// A run of `count` scalars, `stride` apart, starting at `first`.
/// The payload is the distance to the folded scalar, or an index into the expansions.
struct CaseFoldingEntry {
    var first: UInt32
    var count: Int
    var stride: UInt32
    var isExpansion: Bool
    var payload: Int64

    var rawValue: UInt64 {
        precondition(UInt64(first) < 1 << (UInt64.bitWidth - CaseFoldingLayout.firstShift))
        precondition(count >= 1 && count <= CaseFoldingLayout.maximumCount && (stride == 1 || stride == 2))
        precondition(payload >= Int64(Int32.min) && payload <= Int64(Int32.max))
        return UInt64(first) << CaseFoldingLayout.firstShift
            | UInt64(count) << CaseFoldingLayout.countShift
            | UInt64(stride - 1) << CaseFoldingLayout.strideIsTwoShift
            | (isExpansion ? 1 : 0) << CaseFoldingLayout.isExpansionShift
            | UInt64(UInt32(truncatingIfNeeded: payload))
    }
}

/// Groups single-scalar mappings into runs with the same distance and a stride of one or two.
func caseFoldingEntries(_ folding: [UInt32: [UInt32]]) -> (entries: [CaseFoldingEntry], expansions: [UInt32]) {
    let keys = folding.keys.sorted()
    var entries: [CaseFoldingEntry] = []
    var expansions: [UInt32] = []
    var i = 0
    while i < keys.count {
        let first = keys[i]
        guard let mapping = folding[first] else {
            preconditionFailure("Every key has a mapping")
        }
        if mapping.count > 1 {
            precondition(mapping.count <= CaseFoldingLayout.expansionLength)
            entries.append(CaseFoldingEntry(first: first, count: 1, stride: 1, isExpansion: true, payload: Int64(expansions.count / CaseFoldingLayout.expansionLength)))
            expansions += mapping + Array(repeating: 0, count: CaseFoldingLayout.expansionLength - mapping.count)
            i += 1
            continue
        }
        let distance = Int64(mapping[0]) - Int64(first)
        var bestCount = 1
        var bestStride: UInt32 = 1
        for stride: UInt32 in [1, 2] {
            var count = 1
            while i + count < keys.count && count < CaseFoldingLayout.maximumCount,
                  keys[i + count] == first + UInt32(count) * stride,
                  let next = folding[keys[i + count]], next.count == 1,
                  Int64(next[0]) - Int64(keys[i + count]) == distance {
                count += 1
            }
            if count > bestCount {
                bestCount = count
                bestStride = stride
            }
        }
        entries.append(CaseFoldingEntry(first: first, count: bestCount, stride: bestStride, isExpansion: false, payload: distance))
        i += bestCount
    }
    return (entries, expansions)
}

func hexadecimal(_ value: some BinaryInteger, digits: Int) -> String {
    let text = String(value, radix: 16, uppercase: true)
    return String(repeating: "0", count: max(0, digits - text.count)) + text
}

/// A span accessor for `UnicodeScalarMappingData` and a private global that holds the values.
struct Table {
    let name: String
    let elementType: String
    let values: [UInt64]
    let digits: Int
    let comment: String

    var accessorLines: [String] {
        [
            "/// \(comment)",
            "static var \(name): Span<\(elementType)> {",
            "\(swiftCodeIndent)@_lifetime(immortal) get { \(name)Table.span }",
            "}",
        ]
    }

    var tableLines: [String] {
        var lines = ["private let \(name)Table: InlineArray<_, \(elementType)> = ["]
        let valuesPerLine = max(1, 72 / (digits + 4))
        for start in Swift.stride(from: 0, to: values.count, by: valuesPerLine) {
            let chunk = values[start ..< min(start + valuesPerLine, values.count)]
            lines.append(swiftCodeIndent + chunk.map { "0x\(hexadecimal($0, digits: digits))," }.joined(separator: " "))
        }
        lines.append("]")
        return lines
    }
}

func generateSwiftCode() throws -> String {
    let arguments = CommandLine.arguments.dropFirst()
    guard let unicodeVersion = arguments.first else {
        throw CodeGenerationError.missingUnicodeVersion
    }
    let directory = arguments.dropFirst().first.flatMap { $0.isEmpty ? nil : $0 }

    let folding = try parseCaseFolding(readUCDFile(named: "CaseFolding.txt", unicodeVersion: unicodeVersion, directory: directory))
    let unicodeData = try UnicodeData(readUCDFile(named: "UnicodeData.txt", unicodeVersion: unicodeVersion, directory: directory))

    let (entries, expansions) = caseFoldingEntries(folding)

    var diacriticStripping: [UInt64] = []
    let hangulSyllables = Hangul.syllableBase ..< Hangul.syllableBase + Hangul.syllableCount
    for value in Set(unicodeData.canonicalDecompositions.keys).union(hangulSyllables).sorted() {
        let base = unicodeData.canonicallyOrdered(unicodeData.decompose(value, with: [unicodeData.canonicalDecompositions]))[0]
        if base < diacriticStrippingLimit {
            diacriticStripping.append(UInt64(value << diacriticStrippingBaseBitCount | base))
        }
    }

    var halfwidth: [UInt64] = []
    for value in halfwidthAndFullwidthForms {
        let decomposition = unicodeData.canonicallyOrdered(unicodeData.decompose(value, with: [unicodeData.canonicalDecompositions, unicodeData.compatibilityDecompositions]))
        halfwidth.append(UInt64(decomposition.count == 1 ? decomposition[0] : value))
    }
    precondition(halfwidth.allSatisfy { $0 < 0x10000 && !(0xD800 ..< 0xE000).contains($0) })

    let limit = hexadecimal(diacriticStrippingLimit, digits: 4)
    let tables = [
        Table(
            name: "caseFolding", elementType: "UInt64", values: entries.map(\.rawValue), digits: 16,
            comment: "Full case folding, sorted. Each entry maps `count` scalars, `stride` apart, starting at `first`. "
                + "Bits: `first` (\(UInt64.bitWidth - 1)...\(CaseFoldingLayout.firstShift)), "
                + "`count` (\(CaseFoldingLayout.countShift + CaseFoldingLayout.countBitCount - 1)...\(CaseFoldingLayout.countShift)), "
                + "`stride` is 2 (\(CaseFoldingLayout.strideIsTwoShift)), "
                + "the payload is an index into `caseFoldingExpansions` (\(CaseFoldingLayout.isExpansionShift)), "
                + "payload (31...0): the distance to the folded scalar, or the index."),
        Table(
            name: "caseFoldingExpansions", elementType: "UInt32", values: expansions.map(UInt64.init), digits: 5,
            comment: "Case foldings with more than one scalar, three scalars each, padded with zero."),
        Table(
            name: "diacriticStripping", elementType: "UInt32", values: diacriticStripping, digits: 8,
            comment: "Scalars whose canonical decomposition starts with a base scalar below U+\(limit), sorted. "
                + "Bits: scalar (31...\(diacriticStrippingBaseBitCount)), base scalar (\(diacriticStrippingBaseBitCount - 1)...0)."),
        Table(
            name: "halfwidthAndFullwidthForms", elementType: "UInt16", values: halfwidth, digits: 4,
            comment: "The compatibility decomposition of each scalar from U+\(hexadecimal(halfwidthAndFullwidthForms.lowerBound, digits: 4)) "
                + "to U+\(hexadecimal(halfwidthAndFullwidthForms.upperBound - 1, digits: 4)), or the scalar itself when the decomposition has more than one scalar."),
    ]

    let accessors = tables.map { $0.accessorLines.map { swiftCodeIndent + $0 }.joined(separator: "\n") }.joined(separator: "\n\n")
    let globals = tables.map { $0.tableLines.joined(separator: "\n") }.joined(separator: "\n\n")
    return """
        #if !FOUNDATION_FRAMEWORK
        enum UnicodeScalarMappingData {
            static let halfwidthAndFullwidthFormsStart: UInt32 = 0x\(hexadecimal(halfwidthAndFullwidthForms.lowerBound, digits: 4))

            static let diacriticStrippingBaseBitCount: UInt32 = \(diacriticStrippingBaseBitCount)

            static let caseFoldingFirstShift: UInt64 = \(CaseFoldingLayout.firstShift)
            static let caseFoldingCountShift: UInt64 = \(CaseFoldingLayout.countShift)
            static let caseFoldingCountMask: UInt64 = 0x\(hexadecimal(CaseFoldingLayout.maximumCount, digits: 2))
            static let caseFoldingStrideIsTwoBit: UInt64 = 1 << \(CaseFoldingLayout.strideIsTwoShift)
            static let caseFoldingIsExpansionBit: UInt64 = 1 << \(CaseFoldingLayout.isExpansionShift)

            /// The number of scalars in each `caseFoldingExpansions` entry, including the zero padding.
            static let caseFoldingExpansionLength = \(CaseFoldingLayout.expansionLength)

        \(accessors)
        }

        \(globals)
        #endif // !FOUNDATION_FRAMEWORK
        """
}

#if PRINT_CODE
print(try generateSwiftCode())
#endif
