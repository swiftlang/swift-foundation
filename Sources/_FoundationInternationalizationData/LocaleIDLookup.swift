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

extension _LocaleIDData : LocaleDataTable {
    /// Returns the index in `localeIDs` of the nearest locale to `baseName`. Each table's `localeRows` maps this index to the locale's row.
    ///
    /// Where the language of `baseName` has no data, this uses the fallback locale if there is one, else root.
    package static func localeIndex(forBaseName baseName: String) -> Int {
        if let index = index(for: baseName) {
            return index
        }
        let fallback = fallbackLocale.description
        return index(for: fallback.isEmpty ? "root" : fallback)!
    }

    /// Returns the index of the nearest locale in `localeIDs`, or nil where the identifier's language has no data.
    ///
    /// A redirect sends the lookup for an identifier to another locale. For example, `zh_TW` redirects to `zh_Hant_TW`: `redirectFrom` holds `zh_TW`, and `redirectTo` holds `zh_Hant_TW` at the same index.
    private static func index(for identifier: String) -> Int? {
        var current = identifier
        while true {
            if let index = search(current, count: localeIDs.count, { localeIDs[$0] }) {
                return index
            }
            if let redirect = search(current, count: redirectFrom.count, { redirectFrom[$0] }) {
                current = DataString<Self>(entry: redirectTo[redirect]).string
            } else if let underscore = current.utf8.lastIndex(of: UInt8(ascii: "_")) {
                current = String(current[..<underscore])
            } else {
                return nil
            }
        }
    }
}
