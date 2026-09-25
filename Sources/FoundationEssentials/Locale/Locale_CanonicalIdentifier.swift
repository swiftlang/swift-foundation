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

#if FOUNDATION_FRAMEWORK && canImport(_FoundationICU)
internal import _FoundationICU
#endif

extension Locale {

    /// A 2-byte ASCII tag (language/region code, or old-style special-case code like `"sh"`).
    struct TwoLetterSubtag: ExpressibleByStringLiteral, Equatable {
        let byte0: UInt8
        let byte1: UInt8

        init(_ byte0: UInt8, _ byte1: UInt8) {
            self.byte0 = byte0
            self.byte1 = byte1
        }

        init(stringLiteral value: StaticString) {
            precondition(value.utf8CodeUnitCount == 2, "Tag must be exactly 2 bytes")
            let p = value.utf8Start
            byte0 = p[0]
            byte1 = p[1]
        }
    }

    private static let _maxIdentifierLength = 257
    
    /// Same as `canonicalIdentifier` but not deprecated, for internal usage. Also, it handles a nil result (e.g. non-ASCII identifier input) correctly.
    package static func _canonicalLocaleIdentifier(from string: String) -> String {

        let utf8 = string.utf8
        guard utf8.count > 0 else {
            return ""
        }

        guard utf8.count < _maxIdentifierLength, utf8.allSatisfy({ $0 < 0x80 }) else {
            return ""
        }

        let (identifier, keyValueSubstring) = splitString(from: string.utf8Span.span)

        // A. First check if input string matches an old-style Apple string that has a replacement (do this before case normalization)
        if let canonical = Locale.oldAppleLocaleToCanonical(identifier) {
            return updateKeyValues(keyValueSubstring, canonical)
        }

        // B. No match with an old-style string, use input string but update codes, normalize case, etc.

        // The replacement can be a different length than the prefix it replaces (e.g. "art-lojban" -> "jbo"), so precalculate it here.
        let prefixMatch = canonicalizeLanguagePrefix(identifier)
        let sourceLength = identifier.count - (prefixMatch?.keyLength ?? 0) + (prefixMatch?.result.utf8.count ?? 0)

        let capacity = sourceLength * 2

        let baseIdentifier = String(unsafeUninitializedCapacity: capacity) { buffer in

            var sourceOutput = OutputSpan(buffer: buffer[0..<sourceLength], initializedCount: 0)
            if let prefixMatch {
                sourceOutput._append(copying: prefixMatch.result.utf8.span)
                sourceOutput._append(copying: identifier.extracting(prefixMatch.keyLength...))
            } else {
                sourceOutput._append(copying: identifier)
            }

            // C. Now strip defaults that are implied by other fields.
            // 1. If an ISO 3166 region tag matches an ISO 3166 regional language variant subtag, strip the latter.
            var output = OutputSpan(buffer: buffer[sourceLength...], initializedCount: 0)
            let regionTagEndIndex = updateFullLocaleString(sourceOutput.span, into: &output)

            // 2. Strip defaults in input string based on final region tag in locale string
            // (mainly for Chinese, to strip -Hans for _CN/_SG, -Hant for _TW/_HK/_MO)
            if let regionTagEndIndex, regionTagEndIndex == output.span.count, let regionStrip = defaultScriptsForRegion( output.span.extracting((regionTagEndIndex - 3)..<regionTagEndIndex)) {
                removeSubstrings(regionStrip, from: &output)
            }

            // 3. Strip defaults in input string based on initial part of locale string
            // (mainly to strip default script tag for a language)
            if let prefixStrip = defaultScriptsForLanguage(output.span) {
                // The input string begins with a character sequence for which
                // there are default substrings which should be stripped if present
                removeSubstrings(prefixStrip, from: &output)
            }

            let result = output.span
            for i in 0..<result.count {
                buffer[i] = result[i]
            }
            return result.count
        }

        // D. Re-append any key-value strings, now canonical
        return updateKeyValues(keyValueSubstring, baseIdentifier)
    }

    // MARK: - Table lookups

    /// Looks up the default script of a region code, given the 3-byte delimiter + code span (e.g. `"_CN"`).
    static func defaultScriptsForRegion(_ code: Span<UInt8>) -> String? {
        guard code[0] == _underscore else { return nil }
        return Locale.localeStringRegionToDefaults(forRegion: (code[1], code[2]))
    }

    /// Given a locale string that uses standard codes (not a special old-style Apple string), update all the language codes and region codes to latest versions, map 3-letter language codes to 2-letter codes if possible, and normalize casing.
    /// If a language-region variant subtag duplicates the region tag, the former is stripped here.
    /// Returns the end offset (one past the 2-letter code) of the region tag in `buffer`, if present and if it was not made redundant by that strip.
    static func updateFullLocaleString(_ source: Span<UInt8>, into buffer: inout OutputSpan<UInt8>) -> Int? {
        // 257 == _maxIdentifierLength
        var subtagStorage = InlineArray<257, UInt8>(repeating: 0)
        var subtagLength = 0

        var langRegSubtagStartIndex: Int? = nil
        var regionTagStartIndex: Int? = nil

        var subtagStart = 0
        var hadRegion = false
        var pastPrimarySubtag = false
        var subtagHasDigits = false

        var i = 0
        while true {
            if i < source.count, isAlphabet(source[i]) {
                subtagStorage[subtagLength] = hadRegion ? asciiUppercase(source[i]) : asciiLowercase(source[i])
                subtagLength += 1
            } else if i < source.count, isDigit(source[i]) {
                subtagHasDigits = true
                subtagStorage[subtagLength] = source[i]
                subtagLength += 1
            } else {
                // A delimiter ('-' or '_'), or the end of the string.
                if !pastPrimarySubtag {
                    if subtagHasDigits {
                        for j in 0..<subtagLength { buffer.append(subtagStorage[j]) }
                        break
                    }
                    pastPrimarySubtag = true
                } else if !hadRegion {
                    // `subtagLength` includes the leading delimiter
                    if subtagLength == 3, !subtagHasDigits {
                        if subtagStorage[0] == _underscore {
                            regionTagStartIndex = subtagStart
                            hadRegion = true
                            subtagStorage[1] = asciiUppercase(subtagStorage[1])
                            subtagStorage[2] = asciiUppercase(subtagStorage[2])
                        } else if langRegSubtagStartIndex == nil {
                            langRegSubtagStartIndex = subtagStart
                            subtagStorage[1] = asciiUppercase(subtagStorage[1])
                            subtagStorage[2] = asciiUppercase(subtagStorage[2])
                        }
                    } else if subtagLength == 4, subtagHasDigits {
                        if subtagStorage[0] == _underscore {
                            regionTagStartIndex = subtagStart
                            hadRegion = true
                        } else if langRegSubtagStartIndex == nil {
                            langRegSubtagStartIndex = subtagStart
                        }
                    } else if subtagLength == 5, !subtagHasDigits {
                        subtagStorage[1] = asciiUppercase(subtagStorage[1])
                    } else if subtagLength == 1, subtagStorage[0] == _underscore {
                        hadRegion = true
                    }

                    if !hadRegion {
                        subtagStorage[0] = _hyphen
                    }
                }

                // Once `hadRegion` is true, any further subtag is a variant tag
                buffer._append(copying: subtagStorage.span.extracting(0..<subtagLength))
                subtagLength = 0

                if i < source.count, source[i] == _hyphen || source[i] == _underscore {
                    // Record where this subtag starts in `buffer`, not in `source`, so the offsets stay valid even if the two ever stop being the same length.
                    subtagStart = buffer.count
                    subtagStorage[0] = source[i]
                    subtagLength = 1
                    subtagHasDigits = false
                } else {
                    break
                }
            }
            i += 1
        }

        if i < source.count {
            buffer._append(copying: source.extracting(i...))
        }

        let langRegionCode = langRegSubtagStartIndex.map { TwoLetterSubtag(buffer.span[$0 + 1], buffer.span[$0 + 2]) }
        let regionCode = regionTagStartIndex.map { TwoLetterSubtag(buffer.span[$0 + 1], buffer.span[$0 + 2]) }

        // 4. Handle special cases of updating region codes, or updating language codes based on region code.
        if let langRegSubtagStartIndex, let langRegionCode, let canonical = canonicalRegionCode(langRegionCode, in: buffer.span) {
            overwrite(&buffer, at: langRegSubtagStartIndex + 1, with: canonical)
        }

        if let regionTagStartIndex, let regionCode, let canonical = canonicalRegionCode(regionCode, in: buffer.span) {
            overwrite(&buffer, at: regionTagStartIndex + 1, with: canonical)
        }

        // If language is old 'sh' (SerboCroatian), change it to 'hr' (Croatian) if we find HR (Croatia) in either slot, or to 'sr' (Serbian) if we find RS (Serbia) in either slot.
        if startsWithSubtag(buffer.span, subtag: "sh") {
            if langRegionCode == "HR" || regionCode == "HR" {
                overwrite(&buffer, at: 0, with: "hr")
            } else if langRegionCode == "RS" || regionCode == "RS" {
                overwrite(&buffer, at: 0, with: "sr")
            }
        }

        // 5. If an ISO 3166 region tag matches an ISO 3166 regional language variant subtag, strip the latter.
        if let langRegSubtagStartIndex, let langRegionCode, let regionCode, langRegionCode == regionCode {
            buffer.removeSubrange(langRegSubtagStartIndex..<(langRegSubtagStartIndex + 3))
            return nil
        }

        // Only the end index of the 2-byte code is returned, because every external consumer
        // only ever looks at those 2 bytes, or checks this offset against the end of the string.
        return regionTagStartIndex.map { $0 + 3 }
    }

    // MARK: - `specialCases`

    // UK -> GB, TP -> TL, CS -> CZ/SK/RS (depending on language), YU -> RS.
    static func canonicalRegionCode(_ code: TwoLetterSubtag, in main: Span<UInt8>) -> TwoLetterSubtag? {
        switch code {
        case "UK":
            return "GB"
        case "TP":
            return "TL"
        case "CS":
            if startsWithSubtag(main, subtag: "cs") {
                return "CZ"
            } else if startsWithSubtag(main, subtag: "sk") {
                return "SK"
            } else {
                return "RS"
            }
        case "YU":
            return "RS"
        default:
            return nil
        }
    }

    static func overwrite(_ main: inout OutputSpan<UInt8>, at position: Int, with replacement: TwoLetterSubtag) {
        main[position] = replacement.byte0
        main[position + 1] = replacement.byte1
    }

    static func startsWithSubtag(_ main: Span<UInt8>, subtag: TwoLetterSubtag) -> Bool {
        guard main.count >= 2, TwoLetterSubtag(main[0], main[1]) == subtag else {
            return false
        }

        return main.count == 2 || !isAlphabetOrDigit(main[2])
    }


    // MARK: - Prefix matching

    // Case-insensitive prefix match to map 3-letter & obsolete ISO 639 codes, plus obsolete RFC 3066 codes, to canonical prefix.
    static func canonicalizeLanguagePrefix(_ main: Span<UInt8>) -> (keyLength: Int, result: String)? {

        guard main.count > 0 else { return nil }
        // no need to match beyond the known longest key
        let limit = min(Locale._maxLocaleStringPrefixToCanonicalKeyLength, main.count)

        // 10 == _maxLocaleStringPrefixToCanonicalKeyLength
        var lowered = InlineArray<10, UInt8>(repeating: 0)
        for i in 0..<limit {
            lowered[i] = asciiLowercase(main[i])
        }

        // Try to match the longest if entries share the same prefix ("no" and "no-bok")
        for length in stride(from: limit, through: 1, by: -1) {
            if length < main.count, isAlphabetOrDigit(main[length]) {
                continue
            }
            let candidate = lowered.span.extracting(0..<length)
            if let result = Locale.localeStringPrefixToCanonical(candidate) {
                return (length, result)
            }
        }
        return nil
    }

    /// Extracts the leading language subtag. Returns the default scripts.
    static func defaultScriptsForLanguage(_ main: Span<UInt8>) -> String? {
        var end = 0
        while end < main.count, isAlphabet(main[end]) {
            end += 1
        }
        guard end == 2 || end == 3, end < main.count, main[end] == _hyphen else {
            return nil
        }
        return Locale.localeStringPrefixToDefaults(forLanguage: main.extracting(0..<end))
    }

    // MARK: - `_RemoveSubstringsIfPresent`

    /// Deletes each substring of the space-separated `substringList` from `main`
    private static func removeSubstrings(_ substringList: String, from main: inout OutputSpan<UInt8>) {
        let list = substringList.utf8Span.span
        var start = 0
        while start < list.count {
            // Skip the separating spaces, then take the next substring.
            guard list[start] != _space else {
                start += 1
                continue
            }
            var end = start
            while end < list.count, list[end] != _space {
                end += 1
            }
            let needle = list.extracting(start..<end)
            start = end

            guard let found = main.span.firstRange(of: needle) else { continue }

            main.removeSubrange(found)
        }
    }

    // MARK: - `_GetKeyValueString` / `_AppendKeyValueString`

    /// Splits `main` at the first `@`, returning the portion before it (`identifier`) and the portion from `@` onward with trailing spaces trimmed (`keyValueString`).
    /// Returned `keyValueString` contains "@"
    @_lifetime(copy main)
    static func splitString(from main: Span<UInt8>) -> (identifier: Span<UInt8>, keyValueString: Span<UInt8>) {
        guard let atIndex = main.firstIndex(of: _at) else {
            return (identifier: main, keyValueString: main.extracting(main.count...))
        }

        var end = main.count
        while end > atIndex, main[end - 1] == _space {
            end -= 1
        }

        return (identifier: main.extracting(0..<atIndex), keyValueString: main.extracting(atIndex..<end))
    }

    /// Precondition: `keyValueBytes` already has "@", i.e. "@key=value;..."
    static func updateKeyValues(_ keyValueBytes: Span<UInt8>, _ main: String) -> String {
        guard keyValueBytes.count > 1, keyValueBytes.first == _at else {
            // invalid keyword values
            return main
        }

        let keyValueString = String(copying: UTF8Span(unchecked: keyValueBytes, isKnownASCII: true))

#if FOUNDATION_FRAMEWORK && canImport(_FoundationICU) // TODO: implement this once we are done implementing uloc_ in FoundationEssentials
        var status = U_ZERO_ERROR
        let uenum = uloc_openKeywords(keyValueString, &status)
        guard let uenum, status.isSuccess else {
            return main
        }
        let enumerator = ICU.Enumerator(enumerator: uenum)

        let keyValues = enumerator.elements.compactMap { keyword -> (key: ICULegacyKey, value: String)? in
            guard let value = Locale.keywordValue(identifier: keyValueString, key: keyword) else {
                return nil
            }
            return (ICULegacyKey(keyword), value)
        }

        guard !keyValues.isEmpty else {
            return main
        }

        return Locale.identifierWithKeywordValues(main, keyValues: keyValues)
#else
        // TODO: implement the key value canonicalization once we are done implementing uloc_ in FoundationEssentials
        return main + keyValueString
#endif
    }

    // MARK: - ASCII helpers

    static let _hyphen = UInt8(ascii: "-")
    static let _underscore = UInt8(ascii: "_")
    static let _space = UInt8(ascii: " ")
    static let _at = UInt8(ascii: "@")

    static func isAlphabet(_ byte: UInt8) -> Bool {
        return _allLettersUpper.contains(byte) || _allLettersLower.contains(byte)
    }

    static func isDigit(_ byte: UInt8) -> Bool {
        byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9")
    }

    static func isAlphabetOrDigit(_ byte: UInt8) -> Bool {
        isAlphabet(byte) || isDigit(byte)
    }

    static func asciiUppercase(_ byte: UInt8) -> UInt8 {
        (byte >= UInt8(ascii: "a") && byte <= UInt8(ascii: "z")) ? byte - 32 : byte
    }

    static func asciiLowercase(_ byte: UInt8) -> UInt8 {
        (byte >= UInt8(ascii: "A") && byte <= UInt8(ascii: "Z")) ? byte + 32 : byte
    }
}
