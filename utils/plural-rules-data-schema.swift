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

// Codable schema for PluralRulesData.json, the intermediate form between the
// CLDR plural rules (read by utils/update-plural-rules-data) and the Swift
// tables (written by utils/build-plural-rules-data). Both tools compile this
// file with their own impl.

import Foundation

/// A `TextOutputStream` over standard error, so the tools can use `print(_:to:)` for diagnostics.
internal struct StandardError: TextOutputStream {
    mutating func write(_ string: String) {
        FileHandle.standardError.write(Data(string.utf8))
    }
}
internal var standardError = StandardError()

internal struct PluralRulesDataSchema: Codable {
    /// Where the data came from, such as "CLDR 48".
    let generatedFrom: String

    /// The CLDR version of the data.
    let cldrVersion: String

    /// Every distinct list of rules. Locales refer to these by index.
    let ruleSets: [[Rule]]

    /// Locale identifier (with `_` separators) to an index into `ruleSets`, for cardinal numbers.
    let cardinal: [String: Int]

    /// Locale identifier (with `_` separators) to an index into `ruleSets`, for ordinal numbers.
    let ordinal: [String: Int]

    /// One rule of a rule set, in CLDR order. The `other` rule has an empty condition.
    internal struct Rule: Codable, Hashable {
        let category: String
        let condition: String
        let integerSamples: String
        let decimalSamples: String
    }
}

/// The plural categories in the order CLDR lists them.
internal let pluralCategoryNames = ["zero", "one", "two", "few", "many", "other"]
