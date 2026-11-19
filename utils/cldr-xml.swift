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

// Reads CLDR XML for the stage 1 tools.

import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// Holds the values that the generators read as no value: ↑↑↑, which inherits from the parent, and ∅∅∅.
let markers: Set<String> = ["\u{2191}\u{2191}\u{2191}", "\u{2205}\u{2205}\u{2205}"]

extension XMLElement {
    func children(_ name: String) -> [XMLElement] {
        elements(forName: name)
    }

    func child(_ name: String, type: String? = nil) -> XMLElement? {
        children(name).first { type == nil || $0.attribute(forName: "type")?.stringValue == type }
    }

    func attribute(_ name: String) -> String? {
        attribute(forName: name)?.stringValue
    }

    /// Returns the element's text, unless the text is a marker, or the element is an `alt` value or has a draft status that the generators skip.
    var usableValue: String? {
        guard attribute("alt") == nil, !excludedDrafts.contains(attribute("draft") ?? ""), let text = stringValue, !markers.contains(text) else {
            return nil
        }
        return text
    }
}

func loadDocument(_ url: URL) throws -> XMLDocument {
    do {
        return try XMLDocument(contentsOf: url)
    } catch {
        throw CLDRFileError.xmlParse(url, error)
    }
}

func detectCLDRVersion(_ cldrURL: URL) -> String {
    let dtd = (try? String(contentsOf: cldrURL.appendingPathComponent("common/dtd/ldml.dtd"), encoding: .utf8)) ?? ""
    guard let range = dtd.range(of: #"cldrVersion CDATA #FIXED "[^"]+""#, options: .regularExpression) else {
        return "unknown"
    }
    return String(dtd[range].split(separator: "\"")[1])
}

/// Returns each locale's resolution chain: the locale and its parents. Where a parent is an alias, the chain has the alias's target instead. The chain leaves out locales without data.
func resolutionChains(locales: Set<String>, parents: [String: String]) -> [String: [String]] {
    var chains: [String: [String]] = [:]
    for locale in locales {
        var chain: [String] = []
        var current: String? = locale
        while let l = current {
            if let target = localeAliases[l] {
                current = target
                continue
            }
            if locales.contains(l) { chain.append(l) }
            current = parent(of: l, explicit: parents)
        }
        chains[locale] = chain
    }
    return chains
}

/// Returns the CLDR locale files to build, and the locales to write without data, such as alias targets that have no CLDR file.
func loadICULocaleFiles(cldrURL: URL, parents: [String: String], likelySubtags: [String: String]) throws -> (files: [String: URL], localesWithoutData: Set<String>) {
    let mainURL = cldrURL.appendingPathComponent("common/main", isDirectory: true)
    let urls = try FileManager.default.contentsOfDirectory(at: mainURL, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "xml" }
    let available = Set(urls.map { $0.deletingPathExtension().lastPathComponent })
    let included = icuLocales(available: available, parents: parents, likelySubtags: likelySubtags)
    print("  \(included.count) of \(available.count) CLDR locales are ICU locales", to: &standardError)
    var files: [String: URL] = [:]
    for url in urls where included.contains(url.deletingPathExtension().lastPathComponent) {
        files[url.deletingPathExtension().lastPathComponent] = url
    }
    return (files, included.subtracting(available))
}

/// Writes `value` as sorted, pretty-printed JSON to standard output.
func writeJSON<T: Encodable>(_ value: T) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
    FileHandle.standardOutput.write(try encoder.encode(value))
    FileHandle.standardOutput.write(Data("\n".utf8))
}

/// Deduplicates each locale's block of values, so locales with identical values share one block.
struct BlockTable {
    private(set) var blocks: [[String?]] = []
    private var indexes: [[String?]: Int] = [:]

    mutating func index(of block: [String?]) -> Int {
        if let index = indexes[block] {
            return index
        }
        blocks.append(block)
        indexes[block] = blocks.count - 1
        return blocks.count - 1
    }
}
