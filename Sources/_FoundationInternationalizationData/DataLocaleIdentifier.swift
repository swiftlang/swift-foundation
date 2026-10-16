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

#if FOUNDATION_DATE_FORMAT_SWIFT || !FOUNDATION_LIST_FORMAT_ICU

/// The parts of a locale identifier that the data tables use, read from either the `@key=value` or the BCP 47 `-u-` form.
/// `Locale` keeps an identifier as the caller wrote it, so this also gives each subtag the case the tables use.
package struct DataLocaleIdentifier {
    /// The language, script, region, and variants, with `_` separators, such as `zh_Hant_TW`. An empty identifier is root.
    package var baseName: String
    /// The `numbers` keyword, or the BCP 47 `nu` key, in lowercase.
    package var numbers: String?
    /// The `rg` keyword, or the BCP 47 `rg` key, in lowercase.
    package var regionOverride: String?

    package init(_ identifier: String) {
        self.init(identifier, readsKeywords: true)
    }

    /// The base name of `identifier`, without reading its keywords.
    package static func baseName(of identifier: String) -> String {
        Self(identifier, readsKeywords: false).baseName
    }

    private init(_ identifier: String, readsKeywords: Bool) {
        var identifier = identifier
        identifier.makeContiguousUTF8()
        let utf8 = identifier.utf8Span.span
        // One pass finds the keywords and checks whether the base name already has `_` separators, each subtag in the
        // case the tables use, and no extensions.
        var baseEnd = utf8.count
        var isCanonical = true
        var subtagIndex = 0
        var subtagStart = 0
        var position = 0
        while position <= utf8.count {
            let byte = position < utf8.count ? utf8[position] : UInt8(ascii: "@")
            if byte == UInt8(ascii: "_") || byte == UInt8(ascii: "@") {
                if isCanonical {
                    isCanonical = Self.isCanonicalSubtag(utf8.extracting(subtagStart ..< position), index: subtagIndex)
                }
                if byte == UInt8(ascii: "@") {
                    baseEnd = position
                    break
                }
                subtagIndex &+= 1
                subtagStart = position &+ 1
            } else if byte == UInt8(ascii: "-") {
                isCanonical = false
            }
            position &+= 1
        }
        var numbers: String?
        var regionOverride: String?
        if baseEnd == 0 {
            baseName = "root"
        } else if isCanonical {
            baseName = baseEnd == utf8.count ? identifier : String(identifier[..<identifier.utf8.index(identifier.utf8.startIndex, offsetBy: baseEnd)])
        } else {
            baseName = Self.parseBaseName(utf8.extracting(0 ..< baseEnd), numbers: &numbers, regionOverride: &regionOverride)
        }
        if readsKeywords {
            Self.readKeywords(utf8.extracting(min(baseEnd &+ 1, utf8.count)...), numbers: &numbers, regionOverride: &regionOverride)
        }
        self.numbers = numbers
        self.regionOverride = regionOverride
    }

    /// Reads the `numbers` and `rg` values from keywords written as `key=value` separated by `;`.
    private static func readKeywords(_ utf8: Span<UInt8>, numbers: inout String?, regionOverride: inout String?) {
        var keywordStart = 0
        while keywordStart < utf8.count {
            var keywordEnd = keywordStart
            var equals: Int?
            while keywordEnd < utf8.count && utf8[keywordEnd] != UInt8(ascii: ";") {
                if equals == nil && utf8[keywordEnd] == UInt8(ascii: "=") { equals = keywordEnd }
                keywordEnd &+= 1
            }
            if let equals {
                let key = utf8.extracting(keywordStart ..< equals)
                let value = utf8.extracting(equals &+ 1 ..< keywordEnd)
                if equalsIgnoringCase(key, "numbers") {
                    numbers = lowercasedString(value)
                } else if equalsIgnoringCase(key, "rg") {
                    regionOverride = lowercasedString(value)
                }
            }
            keywordStart = keywordEnd &+ 1
        }
    }

    private static func equalsIgnoringCase(_ bytes: Span<UInt8>, _ lowercase: String) -> Bool {
        guard bytes.count == lowercase.utf8.count else { return false }
        var i = 0
        for byte in lowercase.utf8 {
            if lowercased(bytes[i]) != byte { return false }
            i &+= 1
        }
        return true
    }

    private static func lowercasedString(_ bytes: Span<UInt8>) -> String {
        String(decoding: (0 ..< bytes.count).map { lowercased(bytes[$0]) }, as: UTF8.self)
    }

    /// Whether the `index`th subtag is in the case the tables use. A singleton starts an extension, so it isn't.
    private static func isCanonicalSubtag(_ subtag: Span<UInt8>, index: Int) -> Bool {
        var uppercase = 0
        var letters = 0
        for i in 0 ..< subtag.count {
            if isLetter(subtag[i]) { letters &+= 1 }
            if isUppercase(subtag[i]) { uppercase &+= 1 }
        }
        if index == 0 { return uppercase == 0 }
        if index == 1 && subtag.count == 4 && letters == 4 { return uppercase == 1 && isUppercase(subtag[0]) }
        return subtag.count != 1 && uppercase == letters
    }

    /// The base name of `utf8`, an identifier without `@` keywords, with `_` separators and each subtag in the case
    /// the tables use. Also reads the keywords from its Unicode extension.
    private static func parseBaseName(_ utf8: Span<UInt8>, numbers: inout String?, regionOverride: inout String?) -> String {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(utf8.count)
        var index = 0
        // The singleton of the extension being read, such as `u`, in lowercase, and the key whose value comes next.
        var extensionType: UInt8?
        var extensionKey: Range<Int>?
        var subtagStart = 0
        for position in 0 ... utf8.count {
            guard position == utf8.count || utf8[position] == UInt8(ascii: "_") || utf8[position] == UInt8(ascii: "-") else { continue }
            let subtag = utf8.extracting(subtagStart ..< position)
            defer {
                index &+= 1
                subtagStart = position &+ 1
            }
            if index > 0 && subtag.count == 1 {
                // A singleton starts an extension, and `x` starts private use, which runs to the end.
                let singleton = lowercased(subtag[0])
                if singleton == UInt8(ascii: "x") { break }
                extensionType = singleton
                extensionKey = nil
            } else if let extensionType {
                // Only the Unicode extension has keys the tables use.
                guard extensionType == UInt8(ascii: "u") else { continue }
                if subtag.count == 2 {
                    extensionKey = subtagStart ..< position
                } else if let key = extensionKey {
                    if equalsIgnoringCase(utf8.extracting(key), "nu") {
                        numbers = lowercasedString(subtag)
                    } else if equalsIgnoringCase(utf8.extracting(key), "rg") {
                        regionOverride = lowercasedString(subtag)
                    }
                    // Only a key's first value counts.
                    extensionKey = nil
                }
            } else {
                if index > 0 {
                    bytes.append(UInt8(ascii: "_"))
                }
                // The language is lowercase, a script such as Hant is titlecase, and a region or variant such as TW or
                // POSIX is uppercase.
                let isScript = index == 1 && subtag.count == 4 && isAllLetters(subtag)
                for i in 0 ..< subtag.count {
                    bytes.append(index == 0 || (isScript && i > 0) ? lowercased(subtag[i]) : uppercased(subtag[i]))
                }
            }
        }
        return bytes.isEmpty ? "root" : String(decoding: bytes, as: UTF8.self)
    }

    private static func isAllLetters(_ bytes: Span<UInt8>) -> Bool {
        for i in 0 ..< bytes.count where !isLetter(bytes[i]) { return false }
        return true
    }

    private static func isLetter(_ byte: UInt8) -> Bool {
        (byte | 0x20) >= UInt8(ascii: "a") && (byte | 0x20) <= UInt8(ascii: "z")
    }

    private static func isUppercase(_ byte: UInt8) -> Bool {
        byte >= UInt8(ascii: "A") && byte <= UInt8(ascii: "Z")
    }

    private static func lowercased(_ byte: UInt8) -> UInt8 {
        isLetter(byte) ? byte | 0x20 : byte
    }

    private static func uppercased(_ byte: UInt8) -> UInt8 {
        isLetter(byte) ? byte & ~0x20 : byte
    }
}

#endif // FOUNDATION_DATE_FORMAT_SWIFT || !FOUNDATION_LIST_FORMAT_ICU
