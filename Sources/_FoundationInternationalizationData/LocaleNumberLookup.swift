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

extension _LocaleNumberData : LocaleDataTable {}

/// Everything related to numbers in a locale
package struct LocaleNumbers : Sendable {
    private enum NumberingSystem : Sendable {
        case entry(DataString<_LocaleNumberData>)
        case keyword(String)

        func withUTF8<R>(_ body: (Span<UInt8>) -> R) -> R {
            switch self {
            case .entry(let entry): entry.withUTF8(body)
            case .keyword(let keyword): body(keyword.utf8Span.span)
            }
        }
    }

    private let row: Int
    private let symbolsSubBlock: Int
    package let digits: Digits

    /// The minus sign for the numbering system, such as "-" for `latn` in `en`.
    package var minusSign: DataString<_LocaleNumberData> {
        Self.string(row: row, subBlock: symbolsSubBlock, slot: _LocaleNumberData.SymbolSlot.minusSign.rawValue)
    }

    /// Resolves a locale identifier to the nearest locale in the tables.
    ///
    /// Uses the table's fallback locale if it has one if there is no associated data, else root.
    package init(_ identifier: DataLocaleIdentifier) {
        self.init(identifier, localeIndex: _LocaleIDData.localeIndex(forBaseName: identifier.baseName))
    }

    /// `localeIndex` comes from `_LocaleIDData.localeIndex(forBaseName:)`.
    package init(_ identifier: DataLocaleIdentifier, localeIndex: Int) {
        row = Self.row(localeIndex: localeIndex)
        let system = Self.numberingSystem(identifier, row: row)
        symbolsSubBlock = system.withUTF8 { Self.symbolsSubBlock(forNumberingSystem: $0) }
        let systemIndex = system.withUTF8 { _LocaleNumberData.search($0, count: _LocaleNumberData.numberingSystemIDs.count, { _LocaleNumberData.numberingSystemIDs[$0] }) }
        if let systemIndex {
            digits = Digits(zero: _LocaleNumberData.numberingSystemZeros[systemIndex])
        } else {
            // Use Latin digits for algorithmic numbering systems, such as roman numerals, and for unknown ones. The table has no digits for them.
            digits = Digits(zero: 0x30)
        }
    }

    /// Returns the start of the locale's row in `rows`.
    private static func row(localeIndex: Int) -> Int {
        Int(_LocaleNumberData.localeRows[localeIndex]) * _LocaleNumberData.rowWidth
    }

    private static func string(row: Int, subBlock: Int, slot: Int) -> DataString<_LocaleNumberData> {
        DataString(entry: _LocaleNumberData.values[Int(_LocaleNumberData.rows[row + subBlock]) + slot])
    }

    private static func numberingSystem(_ identifier: DataLocaleIdentifier, row: Int) -> NumberingSystem {
        let keywords = Keywords(identifier)
        let slot: _LocaleNumberData.SystemSlot
        switch keywords.numbers {
        // `numbers=hanidays` applies only to the date formatter's day field, so other numbers get the default digits.
        case nil, "default", "hanidays": slot = .default
        case "native": slot = .native
        case "traditional": slot = .traditional
        case "finance": slot = .finance
        case let keyword?: return .keyword(keyword)
        }
        // Take the numbering system from the language, script, and region (from `rg`, else the identifier), without other subtags.
        // The symbols come from the full locale.
        let systemRow = keywords.regionalBaseName(identifier.baseName).map { Self.row(localeIndex: _LocaleIDData.localeIndex(forBaseName: $0)) } ?? row
        return .entry(string(row: systemRow, subBlock: _LocaleNumberData.systemsSubBlock, slot: slot.rawValue))
    }

    private static func symbolsSubBlock(forNumberingSystem system: Span<UInt8>) -> Int {
        for i in 0 ..< _LocaleNumberData.symbolSystems.count where DataString<_LocaleNumberData>(entry: _LocaleNumberData.symbolSystems[i]).compare(system) == 0 {
            return _LocaleNumberData.firstSymbolsSubBlock + i
        }
        // Fallback to Latin values if a system doesn't have its own sub block
        return _LocaleNumberData.firstSymbolsSubBlock
    }
}

extension LocaleNumbers {
    /// A numbering system's digits, which numbers and numeric date fields use.
    package struct Digits : Sendable {
        /// The UTF-8 bytes of the system's digit zero, with the first byte in the lowest 8 bits. For example, Arabic-Indic zero is U+0660, which is `D9 A0` in UTF-8, so `zero` is `0xA0D9`.
        ///
        /// If `digitLength` is 0, the system's digits are text in `irregularDigits`, and `zero` holds the system's index there instead.
        let zero: UInt32
        /// The number of UTF-8 bytes in each digit, such as 1 for `latn` and 2 for `arab`. A value of 0 means that the digits are text in `irregularDigits`.
        let digitLength: Int

        /// `zero` is an entry in `numberingSystemZeros`.
        init(zero: UInt32) {
            if zero & 0x8000_0000 != 0 {
                self.zero = zero & 0x7FFF_FFFF
                digitLength = 0
            } else {
                var utf8: UInt32 = 0
                var length = 0
                UTF8.encode(Unicode.Scalar(zero)!) {
                    utf8 |= UInt32($0) << (8 * length)
                    length += 1
                }
                self.zero = utf8
                digitLength = length
            }
        }

        /// `digit` is 0 through 9.
        package func appendDigit(_ digit: Int, to bytes: inout [UInt8]) {
            guard digitLength != 0 else {
                DataString<_LocaleNumberData>(entry: _LocaleNumberData.irregularDigits[Int(zero) * 10 + digit]).append(to: &bytes)
                return
            }
            // Unroll the loop and use wrapping arithmetic, because a loop with overflow checks is slower.
            let utf8 = zero &+ UInt32(truncatingIfNeeded: digit) &<< (UInt32(truncatingIfNeeded: digitLength &- 1) &* 8)
            bytes.append(UInt8(truncatingIfNeeded: utf8))
            if digitLength > 1 { bytes.append(UInt8(truncatingIfNeeded: utf8 &>> 8)) }
            if digitLength > 2 { bytes.append(UInt8(truncatingIfNeeded: utf8 &>> 16)) }
            if digitLength > 3 { bytes.append(UInt8(truncatingIfNeeded: utf8 &>> 24)) }
        }

        package var hasASCIIDigits: Bool {
            digitLength == 1 && zero == 0x30
        }
    }
}

/// The `numbers` and `rg` keywords of a locale identifier.
struct Keywords {
    var numbers: String?
    var region: String?

    init(_ identifier: DataLocaleIdentifier) {
        numbers = identifier.numbers
        // Only the first two letters of a subdivision such as "sazzzz" or "usca" matter
        guard let value = identifier.regionOverride?.utf8, value.count >= 3 else { return }
        let first = value[value.startIndex] & ~0x20
        let second = value[value.index(after: value.startIndex)] & ~0x20
        let letters = UInt8(ascii: "A") ... UInt8(ascii: "Z")
        guard letters.contains(first) && letters.contains(second) else { return }
        let bit = Int(first - UInt8(ascii: "A")) * 26 + Int(second - UInt8(ascii: "A"))
        if _LocaleNumberData.validRegions[bit / 32] & (1 << (bit % 32)) != 0 {
            region = String(decoding: [first, second], as: UTF8.self)
        }
    }

    /// Returns the language and script of `baseName`, with the `rg` region if there is one, else the identifier's own region.
    /// Returns nil when the result equals `baseName`.
    func regionalBaseName(_ baseName: String) -> String? {
        let utf8 = baseName.utf8
        var end = utf8.firstIndex(of: UInt8(ascii: "_")) ?? utf8.endIndex
        if end < utf8.endIndex {
            let start = utf8.index(after: end)
            let subtagEnd = utf8[start...].firstIndex(of: UInt8(ascii: "_")) ?? utf8.endIndex
            if utf8.distance(from: start, to: subtagEnd) == 4 {
                end = subtagEnd
            }
            if end < utf8.endIndex {
                let start = utf8.index(after: end)
                let subtagEnd = utf8[start...].firstIndex(of: UInt8(ascii: "_")) ?? utf8.endIndex
                let count = utf8.distance(from: start, to: subtagEnd)
                if region == nil, count == 2 || count == 3, utf8[start ..< subtagEnd].allSatisfy({ ($0 >= UInt8(ascii: "A") && $0 <= UInt8(ascii: "Z")) || ($0 >= UInt8(ascii: "0") && $0 <= UInt8(ascii: "9")) }) {
                    end = subtagEnd
                }
            }
        }
        if let region {
            var result = String(baseName[..<end])
            result += "_"
            result += region
            return result == baseName ? nil : result
        }
        return end == utf8.endIndex ? nil : String(baseName[..<end])
    }
}
