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

// Codable schema for LocaleNumberData.json, the intermediate form between CLDR XML (stage 1, utils/update-locale-data) and the Swift tables (stage 2, utils/build-locale-data). Both stages compile this file.

import Foundation


internal struct LocaleNumberDataSchema: Codable {
    /// Provenance, e.g. "CLDR 48".
    let generatedFrom: String
    let cldrVersion: String

    /// Numeric numbering systems: identifier → its ten digits, "0" through "9".
    let numberingSystems: [String: [String]]

    /// Each group's slot names, in table order. A slot's value is resolved through CLDR inheritance for every locale.
    let groupSlots: [String: [String]]

    /// Each group's distinct resolved blocks. A block holds one value per slot, nil where no locale in the chain has one.
    let groupBlocks: [String: [[String?]]]

    /// Locale → group → index into that group's blocks.
    let locales: [String: [String: Int]]

    /// CLDR <parentLocales> (the block without a `component` attribute).
    let parents: [String: String]

    /// Locale aliases, e.g. zh_HK → zh_Hant_HK.
    let aliases: [String: String]

    /// Languages, or languages and regions, whose default script isn't Latin, e.g. sr → Cyrl, az_RU → Cyrl.
    let defaultScripts: [String: String]

    /// Regions that are valid in an `rg` keyword, e.g. US.
    let validRegions: [String]
}

/// The groups, in table order.
internal let localeNumberGroups = ["systems", "symbols"]

/// The "systems" group's slots: the locale's numbering systems.
internal let systemSlots = ["default", "native", "traditional", "finance"]

/// The values in each numbering system's sub-block of the "symbols" group, in table order.
internal let symbolFields = ["minusSign"]

/// The numbering systems with a sub-block in the "symbols" group, in table order, from slot names such as "latn|minusSign".
internal func symbolSystems(_ schema: LocaleNumberDataSchema) -> [String] {
    schema.groupSlots["symbols"]!.compactMap { $0.hasSuffix("|" + symbolFields[0]) ? String($0.prefix { $0 != "|" }) : nil }
}
