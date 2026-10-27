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

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

extension Locale {

    /// Returns the canonical form of `string`, like the deprecated `canonicalIdentifier(from:)`. Returns "" for an empty, too long or non-ASCII identifier.
    package static func _canonicalLocaleIdentifier(from string: String) -> String {
        CanonicalizedIdentifier(canonicalizing: string).identifier
    }

    /// A canonical identifier and the byte ranges of its language, script, region, variant, keys and values.
    package struct CanonicalizedIdentifier: Sendable {
        /// The byte ranges of the language, script, region and variant.
        typealias ComponentRanges = (language: Range<Int>?, script: Range<Int>?, region: Range<Int>?, variant: Range<Int>?)
        /// The byte ranges of each key and its value.
        typealias KeywordRanges = [(key: Range<Int>, value: Range<Int>)]

        /// The canonical identifier, for example `en_US@calendar=chinese`.
        package let identifier: String
        /// The byte ranges of the language, script, region and variant in `identifier`.
        let componentRanges: ComponentRanges
        /// The byte ranges of the keys and values in `identifier`.
        let keywordRanges: KeywordRanges
        /// The range of the region in `identifier`. It is the region code of the "rg" keyword if there is one.
        let regionOverrideRange: Range<Int>?

        init(identifier: String, componentRanges: ComponentRanges, keywordRanges: KeywordRanges) {
            self.identifier = identifier
            self.componentRanges = componentRanges
            self.keywordRanges = keywordRanges

            // The "rg" value is a region code and a subdivision code, for example "gbzzzz". Use only the region code.
            // Ignore an "rg" value of 2 or fewer characters.
            var regionOverrideRange = componentRanges.region
            for (keyRange, valueRange) in keywordRanges where valueRange.count > 2 {
                if case "rg" = RawByteSpanComparator(identifier.utf8Span.span.extracting(keyRange)) {
                    regionOverrideRange = valueRange.lowerBound..<(valueRange.lowerBound + 2)
                    break
                }
            }
            self.regionOverrideRange = regionOverrideRange
        }

        /// Creates a canonical identifier from `baseIdentifier`, a canonical identifier without key-value strings, followed by the key-value pairs in `keywords`.
        /// `componentRanges` are the ranges of the language, script, region and variant in `baseIdentifier`.
        /// If a key appears more than once, this initializer writes only its first value. It sorts the pairs by key.
        init(baseIdentifier: Span<UInt8>, componentRanges: ComponentRanges, keywords: borrowing KeywordList) {
            var keywordRanges: KeywordRanges = []
            let identifier = String(_capacity: baseIdentifier.count + keywords.ranges.reduce(0) { $0 + $1.key.count + $1.value.count + 2 }) { output in
                output._append(copying: baseIdentifier)
                keywordRanges = keywords.write(into: &output)
            }
            self.init(identifier: identifier, componentRanges: componentRanges, keywordRanges: keywordRanges)
        }

        init(components: Locale.Components) {
            let languageCode = components.languageComponents.languageCode?._normalizedIdentifier ?? ""
            let script = components.languageComponents.script?._normalizedIdentifier ?? ""
            let region = components.languageComponents.region?._normalizedIdentifier ?? ""
            var base = Bytes(capacity: languageCode.utf8.count + script.utf8.count + region.utf8.count + 2)
            var componentRanges: ComponentRanges = (nil, nil, nil, nil)
            if !languageCode.isEmpty {
                base.append(copying: languageCode.utf8Span.span.bytes)
                componentRanges.language = 0..<base.count
            }
            if !script.isEmpty {
                base.append(._minus)
                let start = base.count
                base.append(copying: script.utf8Span.span.bytes)
                componentRanges.script = start..<base.count
            }
            if !region.isEmpty {
                base.append(._underscore)
                let start = base.count
                base.append(copying: region.utf8Span.span.bytes)
                componentRanges.region = start..<base.count
            }

            let keywords = KeywordList(components: components)
            self.init(baseIdentifier: base.span, componentRanges: componentRanges, keywords: keywords)
        }

        /// Creates the canonical form of `identifier`, an ICU identifier or a BCP 47 language tag, with the byte ranges of its parts.
        /// A language tag with an extension or a private use has the ICU form. For example, `en-US-u-ca-chinese` becomes `en_US@calendar=chinese`.
        init(identifier: String) {
            self = Self(languageTag: identifier) ?? Self(canonicalizing: identifier)
        }

        /// Creates the canonical form of `string`, with the byte ranges of its parts. The identifier is "" if `string` is empty, too long, or not ASCII.
        package init(canonicalizing source: String) {
            let utf8 = source.utf8
            guard utf8.count > 0, utf8.count < Self._maxIdentifierLength, (source.utf8Span.isKnownASCII || utf8.allSatisfy({ $0 < 0x80 })) else {
                self = Self(identifier: "", componentRanges: (nil, nil, nil, nil), keywordRanges: [])
                return
            }
            // Split at the first "@", where the key-value section starts
            let span = source.utf8Span.span
            let atIndex = span.firstIndex(of: ._at) ?? span.count
            self.init(baseIdentifier: span.extracting(0..<atIndex), keywords: KeywordList(normalizing: span.extracting(atIndex...)))
        }

        /// Creates the canonical form of `base`, followed by `keywords`, with the byte ranges of its parts.
        /// `base` should contain no key-value strings. `keywords` are the normalized key-value pairs.
        init(baseIdentifier base: Span<UInt8>, keywords: borrowing KeywordList) {
            // A. First check if input string matches an old-style Apple string that has a replacement (do this before case normalization)
            if let canonical = Locale.oldAppleLocaleToCanonical(base) {
                // D. Append any key-value strings, now canonical
                // TODO: Make `oldAppleLocaleToCanonical` return bytes, so that `canonical` does not need a `String`.
                self.init(baseIdentifier: canonical.utf8.span, componentRanges: Self.componentRanges(of: canonical.utf8.span), keywords: keywords)
                return
            }

            // B. No match with an old-style string, use input string but update codes, normalize case, etc.

            // The replacement can be a different length than the prefix it replaces (e.g. "art-lojban" -> "jbo").
            if let prefixMatch = Self.canonicalizeLanguagePrefix(base) {
                let replacement = prefixMatch.result
                var source = Bytes(capacity: base.count - prefixMatch.keyLength + replacement.utf8.count)
                source.append(copying: replacement.utf8Span.span.bytes)
                source.append(copying: base.extracting(prefixMatch.keyLength...).bytes)
                self.init(updatingCodesIn: source.span, keywords: keywords)
            } else {
                self.init(updatingCodesIn: base, keywords: keywords)
            }
        }

        /// Creates the canonical form of `source`, followed by `keywords`. `source` is an identifier without key-value strings, with its language prefix already replaced.
        private init(updatingCodesIn source: Span<UInt8>, keywords: borrowing KeywordList) {
            // Write the canonical identifier into a temporary buffer. Then add the key-value strings to it.
            self = withTemporaryAllocation(of: UInt8.self, capacity: source.count) { output in
                // C. Now strip defaults that are implied by other fields.
                // 1. If an ISO 3166 region tag matches an ISO 3166 regional language variant subtag, strip the latter.
                let regionTagEndIndex = Self.updateFullLocaleString(source, into: &output)

                // 2. Strip defaults in input string based on final region tag in locale string
                // (mainly for Chinese, to strip -Hans for _CN/_SG, -Hant for _TW/_HK/_MO)
                if let regionTagEndIndex, regionTagEndIndex == output.span.count, let regionStrip = Self.defaultScriptsForRegion( output.span.extracting((regionTagEndIndex - 3)..<regionTagEndIndex)) {
                    Self.removeSubstrings(regionStrip, from: &output)
                }

                // 3. Strip defaults in input string based on initial part of locale string
                // (mainly to strip default script tag for a language)
                if let prefixStrip = Self.defaultScriptsForLanguage(output.span) {
                    // The input string begins with a character sequence for which
                    // there are default substrings which should be stripped if present
                    Self.removeSubstrings(prefixStrip, from: &output)
                }

                // D. Re-append any key-value strings, now canonical
                return Self(baseIdentifier: output.span, componentRanges: Self.componentRanges(of: output.span), keywords: keywords)
            }
        }

        /// Creates the canonical form of a BCP 47 language tag (which may have an extension or private use).
        /// For example, `en-US-u-ca-chinese` becomes `en_US@calendar=chinese`.
        /// Returns `nil` if there is nothing to convert or if it does not follow BCP 47 form.
        // TODO: Replace a legacy or redundant tag with its preferred tag.
        init?(languageTag string: String) {
            let source = string.utf8Span.span
            guard source.count < Self._maxIdentifierLength else {
                return nil
            }

            // Read the tag only if a subtag before a separator has 1 character: the singleton of an extension or the private use.
            // `init(canonicalizing:)` reads the other identifiers.
            var hasOneCharacterSubtag = false
            var subtagLength = 0
            for i in 0..<source.count {
                if source[i] == ._at || source[i] >= 0x80 {
                    return nil
                }
                if source[i] == ._minus || source[i] == ._underscore {
                    if subtagLength == 1 {
                        hasOneCharacterSubtag = true
                    }
                    subtagLength = 0
                } else {
                    subtagLength += 1
                }
            }
            guard hasOneCharacterSubtag else {
                return nil
            }
            
            var lowercased = Bytes(capacity: source.count) // the language tag as bytes in lowercase using "-" as the separator
            for i in 0..<source.count {
                let isSeparator = source[i] == ._minus || source[i] == ._underscore
                lowercased.append(isSeparator ? ._minus : source[i]._lowercased)
            }

            // Parse the subtags of the base in order: language, extended language, script, region and variants.
            // Stop at the first subtag that is not one of these, such as the singleton of an extension.
            //
            // For "zh-cmn-hant-tw-u-ca-chinese":
            var languageRange: Range<Int>?         // "zh"
            var extendedLanguageRange: Range<Int>? // "cmn"
            var nonLanguageStart: Int?             // "h" for "hant", the start of the script, region and variants
            var hasVariant = false
            var baseEnd = 0                        // "w" for "tw"

            var nextPart = Part.language
            var subtagStart = 0
            while subtagStart <= lowercased.count {
                let (end, letterCount, digitCount) = Self.scanSegment(lowercased.span, fromIndex: subtagStart)
                let length = end - subtagStart
                let startsWithDigit = length > 0 && lowercased.span[subtagStart].isDigit

                if nextPart == .language {
                    // A language has 2 to 8 letters. Only a language of 2 or 3 letters can have extended languages.
                    guard length >= 2, length <= 8, letterCount == length else { break }
                    languageRange = subtagStart..<end
                    nextPart = length <= 3 ? .extendedLanguage : .script
                } else if nextPart == .extendedLanguage, length == 3, letterCount == 3 {
                    // An extended language has 3 letters, and replaces the language. For example, "zh-cmn" becomes "cmn".
                    extendedLanguageRange = subtagStart..<end
                    nextPart = .script
                } else if nextPart <= .script, length == 4, letterCount == 4 {
                    // A script has 4 letters
                    nextPart = .region
                } else if nextPart <= .region, (length == 2 && letterCount == 2) || (length == 3 && digitCount == 3) {
                    // A region has 2 letters or 3 digits.
                    nextPart = .variant
                } else if letterCount + digitCount == length, (length >= 5 && length <= 8) || (length == 4 && startsWithDigit) {
                    // A variant has 5 to 8 letters and digits, or 4 that start with a digit.
                    hasVariant = true
                    nextPart = .variant
                } else {
                    break
                }
                if nextPart >= .region, nonLanguageStart == nil {
                    nonLanguageStart = subtagStart
                }
                baseEnd = end
                subtagStart = end + 1
            }

            let startsWithPrivateUse = Self.isSingleton(lowercased.span, at: 0) && lowercased.span[0] == Self.privateUseSingleton
            guard languageRange != nil || startsWithPrivateUse else {
                // A valid tag either starts with a language ("en-US-u-ca-chinese") or "x" ("x-foo")
                return nil
            }

            // Now handle everything after the base identifier as keywords
            var keywords = KeywordList(languageTagExtensions: lowercased.span.extracting(subtagStart...))

            // Build the base identifier from the language or the last extended language, followed by the other parts.
            var result = Bytes(capacity: source.count)
            var hasLanguage = false
            if let languageRange = extendedLanguageRange ?? languageRange {
                let isUndetermined = lowercased.span.extracting(languageRange).elementsEqual("und".utf8Span.span)
                if !isUndetermined || (nonLanguageStart == nil && keywords.hasExtension) {
                    // For "und" language code, only include it if the whole base identifier is empty AND there are extensions.
                    // For example, "und-US" -> "_US", but "und-u-ca-gregory" -> "und@calendar=gregorian"
                    result.append(copying: lowercased.span.extracting(languageRange).bytes)
                    hasLanguage = true
                }
            }

            if let nonLanguageStart {
                result.append(hasLanguage ? ._minus : ._underscore)
                result.append(copying: lowercased.span.extracting(nonLanguageStart..<baseEnd).bytes)
            }

            // Convert "va-posix" to the variant "POSIX" if there is no other variant
            if !hasVariant, keywords.removePairs(key: "va".utf8Span.span, value: "posix".utf8Span.span) {
                result.append(copying: "_POSIX".utf8Span.span.bytes)
            }

            // If the result is empty, there is nothing to convert, so return `nil`.
            if result.isEmpty && keywords.ranges.isEmpty {
                return nil
            }

            self.init(baseIdentifier: result.span, keywords: keywords)
        }

        /// The language code, for example "en".
        var languageCode: String? {
            componentRanges.language.map { Self.string(from: identifier.utf8Span.span.extracting($0)) }
        }

        /// The script code, for example "Hant".
        var scriptCode: String? {
            componentRanges.script.map { Self.string(from: identifier.utf8Span.span.extracting($0)) }
        }

        /// The region code, for example "US".
        var regionCode: String? {
            componentRanges.region.map { Self.string(from: identifier.utf8Span.span.extracting($0)) }
        }

        /// The variant code in uppercase, with "_" between its subtags, for example "POSIX".
        var variantCode: String? {
            componentRanges.variant.map { Self.string(from: identifier.utf8Span.span.extracting($0), uppercased: true, hyphenToUnderscore: true) }
        }

        /// The region code in uppercase. Uses the region code of the "rg" keyword if there is one.
        var regionOverride: String? {
            regionOverrideRange.map { Self.string(from: identifier.utf8Span.span.extracting($0), uppercased: true) }
        }

        /// Returns the value of `key`, or `nil` if there is no such key.
        func keywordValue(_ key: String) -> String? {
            keywordValueRange(key).map { Self.string(from: identifier.utf8Span.span.extracting($0)) }
        }

        /// Returns the range in `identifier` of the value of `key`, or `nil` if there is no such key.
        func keywordValueRange(_ key: String) -> Range<Int>? {
            let identifier = identifier.utf8Span.span
            let key = key.utf8Span.span
            for (keyRange, valueRange) in keywordRanges where identifier.extracting(keyRange).elementsEqual(key) {
                return valueRange
            }
            return nil
        }

        /// The ICU identifier in the form of `language_Script_REGION_VARIANT@key=value;...`.
        // FIXME: Replace deprecated language, script, region, variant and subdivision codes with their current codes. For example, replace the region "DD" with "DE".
        var icuIdentifier: String {
            // The output has the subtags and keywords of the identifier, plus one "_" for a missing region before a variant.
            let capacity = identifier.utf8.count + 1

            return String(_capacity: capacity) { output in
                let identifier = identifier.utf8.span

                // Find the subtags of the variant, and sort them in uppercase byte order.
                var variantSubtags: [Range<Int>] = []
                if let variant = componentRanges.variant {
                    var start = variant.lowerBound
                    for i in variant.lowerBound...variant.upperBound {
                        let byte = i < variant.upperBound ? identifier[i] : ._underscore
                        guard byte == ._underscore || byte == ._minus else { continue }
                        if i > start { variantSubtags.append(start..<i) }
                        start = i + 1
                    }
                    // There are only a few subtags, so an insertion sort is enough.
                    for a in variantSubtags.indices.dropFirst() {
                        var b = a
                        while b > 0, Self.precedesInUppercase(identifier.extracting(variantSubtags[b]), identifier.extracting(variantSubtags[b - 1])) {
                            variantSubtags.swapAt(b, b - 1)
                            b -= 1
                        }
                    }
                }

                if let language = componentRanges.language {
                    output._append(copying: identifier.extracting(language))
                }
                if let script = componentRanges.script {
                    output.append(._underscore)
                    output._append(copying: identifier.extracting(script))
                }
                if let region = componentRanges.region {
                    output.append(._underscore)
                    output._append(copying: identifier.extracting(region))
                } else if componentRanges.variant != nil {
                    output.append(._underscore)
                }
                for subtag in variantSubtags {
                    output.append(._underscore)
                    for i in subtag {
                        output.append(identifier[i]._uppercased)
                    }
                }
                // Copy the "@key=value;..." section, which starts with the "@" before the first key.
                if let first = keywordRanges.first, let last = keywordRanges.last {
                    output.append(copying: identifier.extracting((first.key.lowerBound - 1)..<last.value.upperBound))
                }
            }
        }

        // MARK: - Canonicalization steps

        /// Returns the bytes of `subtag` as a String, in one allocation. `uppercased` uppercases ASCII letters. `hyphenToUnderscore` writes "-" as "_".
        static func string(from subtag: Span<UInt8>, uppercased: Bool = false, hyphenToUnderscore: Bool = false) -> String {
            String(_capacity: subtag.count) { output in
                for i in 0..<subtag.count {
                    var byte = subtag[i]
                    if uppercased { byte = byte._uppercased }
                    output.append(hyphenToUnderscore && byte == ._minus ? ._underscore : byte)
                }
            }
        }

        /// Splits an identifier without key-value strings on `"-"` and `"_"` in the following order
        /// - Language: if it has 1 to 11 bytes, including "i-" and "x-"
        /// - Script: 4 ASCII letters
        /// - Region: 2 or 3 bytes
        /// - The rest is the variant
        static func componentRanges(of s: Span<UInt8>) -> ComponentRanges {
            var result: ComponentRanges = (nil, nil, nil, nil)

            // A leading "i-" or "x-" is part of the language.
            let hasPrefix = s.count >= 2 && (s[0]._lowercased == UInt8(ascii: "i") || s[0]._lowercased == UInt8(ascii: "x")) && (s[1] == ._minus || s[1] == ._underscore)

            var nextPart = Part.language
            var segmentStart = 0
            while segmentStart <= s.count {
                let (end, letterCount, _) = Self.scanSegment(s, fromIndex: segmentStart == 0 && hasPrefix ? 2 : segmentStart)
                let length = end - segmentStart

                if nextPart == .language {
                    // The first segment is always the language position, even if it is empty.
                    if length >= 1 && length <= 11 {
                        result.language = segmentStart..<end
                    }
                    nextPart = .script
                } else if nextPart == .script, length == 4, letterCount == 4 {
                    result.script = segmentStart..<end
                    nextPart = .region
                } else if nextPart <= .region, length == 2 || length == 3 {
                    result.region = segmentStart..<end
                    nextPart = .variant
                } else if length > 0 {
                    // The rest, including any separators, is the variant.
                    result.variant = segmentStart..<s.count
                    break
                } else {
                    // Skip an empty segment. After it, only the variant can follow.
                    nextPart = .variant
                }
                segmentStart = end + 1
            }
            return result
        }

        // MARK: - Table lookups

        /// Looks up the default script of a region code, given the 3-byte delimiter + code span (e.g. `"_CN"`).
        private static func defaultScriptsForRegion(_ code: Span<UInt8>) -> String? {
            guard code[0] == ._underscore else { return nil }
            return Locale.localeStringRegionToDefaults(forRegion: (code[1], code[2]))
        }

        // MARK: - `specialCases`

        /// Given a locale string that uses standard codes (not a special old-style Apple string), update all the language codes and region codes to latest versions, map 3-letter language codes to 2-letter codes if possible, and normalize casing.
        /// If a language-region variant subtag duplicates the region tag, the former is stripped here.
        /// Returns the end offset (one past the 2-letter code) of the region tag in `buffer`, if present.
        private static func updateFullLocaleString(_ source: Span<UInt8>, into buffer: inout OutputSpan<UInt8>) -> Int? {
            // 257 == _maxIdentifierLength
            var subtagStorage = InlineArray<257, UInt8>(repeating: 0)
            var subtagLength = 0

            var langRegSubtagStartIndex: Int? = nil
            var regionTagStartIndex: Int? = nil

            var hadRegion = false
            var subtagHasDigits = false

            var primaryLanguage: TwoLetterSubtag? = nil
            var hasDelimiter = false

            var i = 0
            while true {
                if i < source.count, source[i].isLetter {
                    subtagStorage[subtagLength] = hadRegion ? source[i]._uppercased : source[i]._lowercased
                    subtagLength += 1
                } else if i < source.count, source[i].isDigit {
                    subtagHasDigits = true
                    subtagStorage[subtagLength] = source[i]
                    subtagLength += 1
                } else {
                    // A delimiter ('-' or '_'), or the end of the string.
                    if subtagLength == 0 || (subtagStorage[0] != ._minus && subtagStorage[0] != ._underscore) {
                        if subtagHasDigits {
                            for j in 0..<subtagLength { buffer.append(subtagStorage[j]) }
                            break
                        }
                        if subtagLength == 2 {
                            primaryLanguage = TwoLetterSubtag(subtagStorage[0], subtagStorage[1])
                        }
                    } else if !hadRegion {
                        // `subtagLength` includes the leading delimiter
                        if subtagLength == 3, !subtagHasDigits {
                            if subtagStorage[0] == ._underscore {
                                regionTagStartIndex = buffer.count
                                hadRegion = true
                                subtagStorage[1] = subtagStorage[1]._uppercased
                                subtagStorage[2] = subtagStorage[2]._uppercased
                            } else if langRegSubtagStartIndex == nil {
                                langRegSubtagStartIndex = buffer.count
                                subtagStorage[1] = subtagStorage[1]._uppercased
                                subtagStorage[2] = subtagStorage[2]._uppercased
                            }
                        } else if subtagLength == 4, subtagHasDigits {
                            if subtagStorage[0] == ._underscore {
                                regionTagStartIndex = buffer.count
                                hadRegion = true
                            } else if langRegSubtagStartIndex == nil {
                                langRegSubtagStartIndex = buffer.count
                            }
                        } else if subtagLength == 5, !subtagHasDigits {
                            subtagStorage[1] = subtagStorage[1]._uppercased
                        } else if subtagLength == 1, subtagStorage[0] == ._underscore {
                            hadRegion = true
                        }

                        if !hadRegion {
                            subtagStorage[0] = ._minus
                        }
                    }

                    // Once `hadRegion` is true, any further subtag is a variant tag
                    buffer._append(copying: subtagStorage.span.extracting(0..<subtagLength))
                    subtagLength = 0

                    if i < source.count, source[i] == ._minus || source[i] == ._underscore {
                        hasDelimiter = true
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
                // This is to match CoreFoundation's behavior to support malformed input, where the unscanned tail may contain a '-'
                hasDelimiter = true
            }

            // 4. Handle special cases of updating region codes, or updating language codes based on region code.
            if hasDelimiter {
                updateRegionCode(&buffer, regionTagStartIndex: regionTagStartIndex, from: "UK", to: "GB")
                updateRegionCode(&buffer, regionTagStartIndex: regionTagStartIndex, from: "TP", to: "TL")
                switch primaryLanguage {
                case "cs":
                    updateRegionCode(&buffer, regionTagStartIndex: regionTagStartIndex, from: "CS", to: "CZ")
                case "sk":
                    updateRegionCode(&buffer, regionTagStartIndex: regionTagStartIndex, from: "CS", to: "SK")
                default:
                    break
                }
                updateRegionCode(&buffer, regionTagStartIndex: regionTagStartIndex, from: "CS", to: "RS")
                updateRegionCode(&buffer, regionTagStartIndex: regionTagStartIndex, from: "YU", to: "RS")

                if primaryLanguage == "sh" && !updateRegionCode(&buffer, regionTagStartIndex: regionTagStartIndex, from: "HR", to: "hr", replacingLanguage: true) {
                    updateRegionCode(&buffer, regionTagStartIndex: regionTagStartIndex, from: "RS", to: "sr", replacingLanguage: true)
                }
            }

            // 5. If an ISO 3166 region tag matches an ISO 3166 regional language variant subtag, strip the latter.
            if let langRegSubtagStartIndex, let regionTagStartIndex {
                let langRegion = TwoLetterSubtag(buffer.span.extracting((langRegSubtagStartIndex + 1)...))
                let region = TwoLetterSubtag(buffer.span.extracting((regionTagStartIndex + 1)...))

                if langRegion == region {
                    buffer.removeSubrange(langRegSubtagStartIndex..<(langRegSubtagStartIndex + 3))
                }
            }

            // Only the end index of the 2-byte code is returned, because every external consumer
            // only ever looks at those 2 bytes, or checks this offset against the end of the string.
            return regionTagStartIndex.map { $0 + 3 }
        }

        /// Rewrites `from` to `to` where it is the first `-XX` in `buffer` or the region tag. With `replacingLanguage`, overwrites the language instead. Returns whether `from` was found.
        @discardableResult
        private static func updateRegionCode(_ buffer: inout OutputSpan<UInt8>, regionTagStartIndex: Int?, from: TwoLetterSubtag, to: TwoLetterSubtag, replacingLanguage: Bool = false) -> Bool {
            var found = false
            // Only the first `-XX` counts, and not if a letter or digit follows it.
            // It can be anywhere, e.g. "en_US-UK". This is to match CoreFoundation's behavior.
            var hyphenIndex: Int? = nil
            if buffer.count >= 3 {
                for i in 0...(buffer.count - 3) where buffer[i] == ._minus && buffer[i + 1] == from.byte0 && buffer[i + 2] == from.byte1 {
                    if i + 3 == buffer.count || !buffer[i + 3].isAlphanumeric {
                        hyphenIndex = i
                    }
                    break
                }
            }
            if let hyphenIndex {
                found = true
                overwrite(&buffer, at: replacingLanguage ? 0 : hyphenIndex + 1, with: to)
            }

            guard let regionTagStartIndex else {
                return found
            }

            let regionTag = TwoLetterSubtag(buffer.span.extracting((regionTagStartIndex + 1)...))
            if from == regionTag {
                found = true
                overwrite(&buffer, at: replacingLanguage ? 0 : regionTagStartIndex + 1, with: to)
            }
            return found
        }

        private static func overwrite(_ main: inout OutputSpan<UInt8>, at position: Int, with replacement: TwoLetterSubtag) {
            main[position] = replacement.byte0
            main[position + 1] = replacement.byte1
        }

        // MARK: - Prefix matching

        // Case-insensitive prefix match to map 3-letter & obsolete ISO 639 codes, plus obsolete RFC 3066 codes, to canonical prefix.
        private static func canonicalizeLanguagePrefix(_ main: Span<UInt8>) -> (keyLength: Int, result: String)? {

            guard main.count > 0 else { return nil }
            // no need to match beyond the known longest key
            let limit = min(Locale._maxLocaleStringPrefixToCanonicalKeyLength, main.count)

            // 10 == _maxLocaleStringPrefixToCanonicalKeyLength
            var lowered = InlineArray<10, UInt8>(repeating: 0)
            for i in 0..<limit {
                lowered[i] = main[i]._lowercased
            }

            // Try to match the longest if entries share the same prefix ("no" and "no-bok")
            for length in stride(from: limit, through: 1, by: -1) {
                if length < main.count, main[length].isAlphanumeric {
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
        private static func defaultScriptsForLanguage(_ main: Span<UInt8>) -> String? {
            var end = 0
            while end < main.count, main[end].isLetter {
                end += 1
            }
            guard end == 2 || end == 3, end < main.count, main[end] == ._minus else {
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
                guard list[start] != ._space else {
                    start += 1
                    continue
                }
                var end = start
                while end < list.count, list[end] != ._space {
                    end += 1
                }
                let needle = list.extracting(start..<end)
                start = end

                guard let found = main.span.firstRange(of: needle) else { continue }

                main.removeSubrange(found)
            }
        }

        // MARK: - BCP 47 language tags

        /// Returns whether the subtag at `index` in `tag` is a singleton
        /// For example, "u" in "u-ca-chinese" and "x" in "x-foo"
        static func isSingleton(_ tag: Span<UInt8>, at index: Int) -> Bool {
            tag[index].isAlphanumeric && (index + 1 == tag.count || tag[index + 1] == ._minus)
        }

        /// Returns `endIndex`, the index of the next "-" or "_" from `start`, or the end of `s`, and the number of letters and digits from `start` to `endIndex`.
        static func scanSegment(_ s: Span<UInt8>, fromIndex start: Int) -> (endIndex: Int, letterCount: Int, digitCount: Int) {
            var end = start
            var letterCount = 0
            var digitCount = 0
            while end < s.count, s[end] != ._minus, s[end] != ._underscore {
                if s[end].isLetter {
                    letterCount += 1
                } else if s[end].isDigit {
                    digitCount += 1
                }
                end += 1
            }
            return (end, letterCount, digitCount)
        }

        /// The parts of a base identifier, in their order.
        private enum Part: Int, Comparable {
            case language, extendedLanguage, script, region, variant
            static func < (lhs: Part, rhs: Part) -> Bool { lhs.rawValue < rhs.rawValue }
        }

        static let privateUseSingleton = UInt8(ascii: "x")

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

            init(_ span: Span<UInt8>) {
                precondition(span.count >= 2)
                self.byte0 = span[0]
                self.byte1 = span[1]
            }
        }

        private static let _maxIdentifierLength = 257

        // MARK: - ASCII helpers

        /// Returns whether `lhs` comes before `rhs` in byte order, comparing ASCII letters in uppercase.
        private static func precedesInUppercase(_ lhs: Span<UInt8>, _ rhs: Span<UInt8>) -> Bool {
            for i in 0..<min(lhs.count, rhs.count) where lhs[i]._uppercased != rhs[i]._uppercased {
                return lhs[i]._uppercased < rhs[i]._uppercased
            }
            return lhs.count < rhs.count
        }
    }
}
