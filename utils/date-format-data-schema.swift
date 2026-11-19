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

// Codable schema for DateFormatData.json, the intermediate form between CLDR
// XML (stage 1, utils/update-date-format-data) and the Swift tables (stage 2,
// utils/build-date-format-data). Both stages compile this file.

import Foundation

/// A `TextOutputStream` over standard error, for progress and diagnostics.
internal struct StandardError: TextOutputStream {
    mutating func write(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        FileHandle.standardError.write(data)
    }
}
internal var standardError = StandardError()

internal struct DateFormatDataSchema: Codable {
    /// Provenance, e.g. "CLDR 48.0".
    let generatedFrom: String
    let cldrVersion: String

    /// Numeric numbering systems: identifier → its ten digits, "0" through "9".
    let numberingSystems: [String: [String]]

    /// Days 1 through 31 in the `hanidays` numbering system, which Apple's ICU uses for the day field under `numbers=hanidays`.
    let hanidaysDays: [String]

    /// Each group's slot names, in table order. A slot's value is resolved
    /// through CLDR inheritance for every locale.
    let groupSlots: [String: [String]]

    /// Each group's distinct resolved blocks. A block holds one value per slot,
    /// nil where no locale in the chain has one.
    let groupBlocks: [String: [[String?]]]

    /// Locale → group → index into that group's blocks.
    let locales: [String: [String: Int]]

    /// CLDR <parentLocales> (the block without a `component` attribute).
    let parents: [String: String]

    /// Locale aliases, e.g. zh_HK → zh_Hant_HK.
    let aliases: [String: String]

    /// Languages, or languages and regions, whose default script isn't Latin, e.g. sr → Cyrl, az_RU → Cyrl.
    let defaultScripts: [String: String]

    /// Regions ICU accepts in an `rg` keyword, e.g. US.
    let validRegions: [String]
}

/// The groups, in table order.
internal let dateFormatGroups = ["numbers", "months", "weekdays", "quarters", "eras", "dayPeriods", "gmt", "capitalization"]
