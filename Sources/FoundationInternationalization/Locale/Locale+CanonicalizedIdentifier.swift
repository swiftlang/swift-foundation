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
        let regionRange: Range<Int>?

        init(identifier: String, componentRanges: ComponentRanges, keywordRanges: KeywordRanges) {
            self.identifier = identifier
            self.componentRanges = componentRanges
            self.keywordRanges = keywordRanges

            // The "rg" value is a region code and a subdivision code, for example "gbzzzz". Use only the region code.
            // Ignore an "rg" value of 2 or fewer characters.
            var regionRange = componentRanges.region
            for (keyRange, valueRange) in keywordRanges where valueRange.count > 2 {
                if case "rg" = RawByteSpanComparator(identifier.utf8Span.span.extracting(keyRange)) {
                    regionRange = valueRange.lowerBound..<(valueRange.lowerBound + 2)
                    break
                }
            }
            self.regionRange = regionRange
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
            // First check if input string matches an old-style Apple string that has a replacement (do this before case normalization)
            if let canonical = Locale.oldAppleLocaleToCanonical(base) {
                // Append any key-value strings, now canonical
                // TODO: Make `oldAppleLocaleToCanonical` return bytes, so that `canonical` does not need a `String`.
                self.init(baseIdentifier: canonical.utf8.span, componentRanges: Self.componentRanges(of: canonical.utf8.span), keywords: keywords)
                return
            }

            // No match with an old-style string, use input string but update codes, normalize case, etc.:

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
            self = withTemporaryAllocation(of: UInt8.self, capacity: source.count) { output in
                let underscoreRegionRange = Self.normalizeCodes(source, into: &output)

                // Strip the default script of the region, for example "-Hans" from "zh-Hans_CN", assuming the region is at the end of the identifier.
                if let underscoreRegionRange, underscoreRegionRange.upperBound == output.span.count, let script = Self.defaultScriptToRemove(forRegion: output.span.extracting(underscoreRegionRange)) {
                    Self.removeFirst(script, from: &output)
                }

                // Strip the default codes of the language, for example "-Latn" from "en-Latn_US" as implied by "en".
                if let codes = Self.defaultCodesToRemove(forLanguageOf: output.span) {
                    Self.removeFirst(codes.first, from: &output)
                    if let second = codes.second {
                        Self.removeFirst(second, from: &output)
                    }
                }

                // Re-append any key-value strings, now canonical
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
        var region: String? {
            regionRange.map { Self.string(from: identifier.utf8Span.span.extracting($0), uppercased: true) }
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
                    output._append(copying: identifier.extracting((first.key.lowerBound - 1)..<last.value.upperBound))
                }
            }
        }

        // MARK: - Canonicalization steps

        /// Returns the bytes of `subtag` as a String.
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

        /// Returns the default script to remove given a region, for example, "-Hans" for "_CN".
        private static func defaultScriptToRemove(forRegion region: Span<UInt8>) -> String? {
            guard region.count == 3, region[0] == ._underscore else { return nil }
            return Locale.defaultScript(forRegion: TwoLetterCode(region[1], region[2]))
        }

        // MARK: - Updating codes

        /// Writes `source` into `buffer` with normalized codes: normalizes the case and the delimiters, replaces obsolete codes, and removes a repeated region code. For example, "EN-uk_GB" becomes "en_GB".
        /// Returns the range of the region. Returns `nil` if there is no region.
        private static func normalizeCodes(_ source: Span<UInt8>, into buffer: inout OutputSpan<UInt8>) -> Range<Int>? {
            let positions = normalizeCaseAndDelimiters(source, into: &buffer)
            if positions.hasDelimiter {
                updateObsoleteCodes(in: &buffer, primaryLanguage: positions.primaryLanguage, underscoreRegionStartIndex: positions.underscoreRegionRange?.lowerBound)
            }
            if let hyphenRegionStartIndex = positions.hyphenRegionStartIndex, let underscoreRegionRange = positions.underscoreRegionRange {
                removeRepeatedRegionCode(in: &buffer, hyphenRegionStartIndex: hyphenRegionStartIndex, underscoreRegionStartIndex: underscoreRegionRange.lowerBound)
            }
            return positions.underscoreRegionRange
        }

        /// Writes `source` into `buffer` code by code, and normalizes the case and the delimiter of each code. For example, "EN_latn_us_posix" becomes "en-Latn_US_POSIX".
        /// Returns these positions in `buffer`
        /// - `hyphenRegionStartIndex`: the index of the "-" before a region code written after the language.
        /// - `underscoreRegionRange`: the range of the region, from its "_" to the end of the region code.
        /// - `primaryLanguage`: the first subtag, if it has 2 letters. For example, "sh" in "sh_HR".
        /// - `hasDelimiter`: whether the identifier has a "-" or "_"
        private static func normalizeCaseAndDelimiters(_ source: Span<UInt8>, into buffer: inout OutputSpan<UInt8>) -> (hyphenRegionStartIndex: Int?, underscoreRegionRange: Range<Int>?, primaryLanguage: TwoLetterCode?, hasDelimiter: Bool) {
            var hyphenRegionStartIndex: Int? = nil
            var underscoreRegionRange: Range<Int>? = nil
            var primaryLanguage: TwoLetterCode? = nil
            var hasDelimiter = false

            // 257 == _maxIdentifierLength
            var subtagStorage = InlineArray<257, UInt8>(repeating: 0)
            var subtagLength = 0
            var subtagHasDigits = false
            var hadRegion = false

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
                    // The end of the subtag
                    if subtagLength == 0 || (subtagStorage[0] != ._minus && subtagStorage[0] != ._underscore) {
                        // The first subtag. Stop reading if it has a digit.
                        if subtagHasDigits {
                            for j in 0..<subtagLength { buffer.append(subtagStorage[j]) }
                            break
                        }
                        if subtagLength == 2 {
                            primaryLanguage = TwoLetterCode(subtagStorage[0], subtagStorage[1])
                        }
                    } else if !hadRegion {
                        // `subtagLength` includes the delimiter.
                        if subtagLength == 3, !subtagHasDigits {
                            // A region code of 2 letters: the region code after "_" ("_US"), or the first region code after "-" ("en-GB"). Uppercase it.
                            if subtagStorage[0] == ._underscore {
                                underscoreRegionRange = buffer.count..<(buffer.count + subtagLength)
                                hadRegion = true
                                subtagStorage[1] = subtagStorage[1]._uppercased
                                subtagStorage[2] = subtagStorage[2]._uppercased
                            } else if hyphenRegionStartIndex == nil {
                                hyphenRegionStartIndex = buffer.count
                                subtagStorage[1] = subtagStorage[1]._uppercased
                                subtagStorage[2] = subtagStorage[2]._uppercased
                            }
                        } else if subtagLength == 4, subtagHasDigits {
                            // A region code of 3 digits, such as "_419" or "es-419".
                            if subtagStorage[0] == ._underscore {
                                underscoreRegionRange = buffer.count..<(buffer.count + subtagLength)
                                hadRegion = true
                            } else if hyphenRegionStartIndex == nil {
                                hyphenRegionStartIndex = buffer.count
                            }
                        } else if subtagLength == 5, !subtagHasDigits {
                            // A script of 4 letters. Uppercase its first letter: "-latn" becomes "-Latn".
                            subtagStorage[1] = subtagStorage[1]._uppercased
                        } else if subtagLength == 1, subtagStorage[0] == ._underscore {
                            // An empty region, as in "en__POSIX". The subtags after it are uppercase.
                            hadRegion = true
                        }

                        if !hadRegion {
                            subtagStorage[0] = ._minus
                        }
                    }

                    // Write everything else after the region as part of the variant.
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

            // Copy the rest that we didn't change above
            if i < source.count {
                buffer._append(copying: source.extracting(i...))
                hasDelimiter = true
            }
            return (hyphenRegionStartIndex, underscoreRegionRange, primaryLanguage, hasDelimiter)
        }

        /// Replaces obsolete region and language codes.
        private static func updateObsoleteCodes(in buffer: inout OutputSpan<UInt8>, primaryLanguage: TwoLetterCode?, underscoreRegionStartIndex: Int?) {
            var language = primaryLanguage
            let updates = Locale.obsoleteCodeUpdates
            for i in updates.indices where updates[i].language == nil || updates[i].language == language {
                let update = updates[i]
                if !update.replacesLanguage {
                    replaceRegionCode(update.regionCode, with: update.to, in: &buffer, underscoreRegionStartIndex: underscoreRegionStartIndex)
                } else if hasRegionCode(update.regionCode, in: buffer.span, underscoreRegionStartIndex: underscoreRegionStartIndex) {
                    overwrite(&buffer, at: 0, with: update.to)
                    language = update.to
                }
            }
        }

        /// Removes the region code after the language if it is the same as the region code in the end.
        /// For example, "en-GB_GB" becomes "en_GB".
        // TODO: Consider removing support for en-GB_GB as it is not a valid form
        private static func removeRepeatedRegionCode(in buffer: inout OutputSpan<UInt8>, hyphenRegionStartIndex: Int, underscoreRegionStartIndex: Int) {
            let languageRegion = TwoLetterCode(buffer.span.extracting((hyphenRegionStartIndex + 1)...))
            let region = TwoLetterCode(buffer.span.extracting((underscoreRegionStartIndex + 1)...))
            if languageRegion == region {
                buffer.removeSubrange(hyphenRegionStartIndex..<(hyphenRegionStartIndex + 3))
            }
        }

        /// Replaces the region code `old` with `new` in the region
        private static func replaceRegionCode(_ old: TwoLetterCode, with new: TwoLetterCode, in buffer: inout OutputSpan<UInt8>, underscoreRegionStartIndex: Int?) {
            if let hyphenIndex = firstHyphenIndex(before: old, in: buffer.span) {
                overwrite(&buffer, at: hyphenIndex + 1, with: new)
            }
            if let underscoreRegionStartIndex, TwoLetterCode(buffer.span.extracting((underscoreRegionStartIndex + 1)...)) == old {
                overwrite(&buffer, at: underscoreRegionStartIndex + 1, with: new)
            }
        }

        /// Returns whether `code` is in the region
        private static func hasRegionCode(_ code: TwoLetterCode, in buffer: Span<UInt8>, underscoreRegionStartIndex: Int?) -> Bool {
            if firstHyphenIndex(before: code, in: buffer) != nil {
                return true
            }
            guard let underscoreRegionStartIndex else { return false }
            return TwoLetterCode(buffer.extracting((underscoreRegionStartIndex + 1)...)) == code
        }

        /// Returns the index of the first "-" followed by `code` in `buffer`. The match can be anywhere, as in "en_US-UK".
        /// Returns `nil` if a letter or digit follows the first match, and does not look for a later match. This matches CoreFoundation.
        private static func firstHyphenIndex(before code: TwoLetterCode, in buffer: Span<UInt8>) -> Int? {
            guard buffer.count >= 3 else { return nil }
            for i in 0...(buffer.count - 3) where buffer[i] == ._minus && buffer[i + 1] == code.byte0 && buffer[i + 2] == code.byte1 {
                return i + 3 == buffer.count || !buffer[i + 3].isAlphanumeric ? i : nil
            }
            return nil
        }

        private static func overwrite(_ main: inout OutputSpan<UInt8>, at position: Int, with replacement: TwoLetterCode) {
            main[position] = replacement.byte0
            main[position + 1] = replacement.byte1
        }

        // MARK: - Prefix matching

        // Case-insensitive prefix match to map 3-letter & obsolete ISO 639 codes, plus obsolete RFC 3066 codes, to canonical prefix.
        private static func canonicalizeLanguagePrefix(_ source: Span<UInt8>) -> (keyLength: Int, result: String)? {
            guard source.count > 0 else { return nil }

            // no need to match beyond the known longest key
            var limit = min(Locale._maxLocaleStringPrefixToCanonicalKeyLength, source.count)
            for i in 0..<limit where source[i] == ._underscore {
                limit = i
                break
            }

            // 10 == _maxLocaleStringPrefixToCanonicalKeyLength
            var lowered = InlineArray<10, UInt8>(repeating: 0)
            for i in 0..<limit {
                lowered[i] = source[i]._lowercased
            }

            // Try the longest prefix first
            for length in stride(from: limit, through: 1, by: -1) {
                if length < source.count, source[length].isAlphanumeric {
                    continue
                }
                let candidate = lowered.span.extracting(0..<length)
                if let result = Locale.localeStringPrefixToCanonical(candidate) {
                    return (length, result)
                }
            }
            return nil
        }

        /// Returns the default codes of the language of `identifier`, for example "-Latn" for "en-Latn_US".
        /// Returns `nil` if we can't find the language tag
        static func defaultCodesToRemove(forLanguageOf identifier: Span<UInt8>) -> (first: String, second: String?)? {
            var end = 0
            while end < identifier.count, identifier[end].isLetter {
                end += 1
            }
            guard end == 2 || end == 3, end < identifier.count, identifier[end] == ._minus else {
                return nil
            }
            let language = identifier.extracting(0..<end)
            guard let first = Locale.defaultScript(forLanguage: language) else {
                return nil
            }
            return (first, Locale.secondDefaultCode(forLanguage: language))
        }

        /// Removes the first occurrence of `substring` from `main`, if there is one.
        static func removeFirst(_ substring: String, from main: inout OutputSpan<UInt8>) {
            if let found = main.span.firstRange(of: substring.utf8Span.span) {
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
        static let unicodeExtensionSingleton = UInt8(ascii: "u")

        /// A language or region code of 2 ASCII bytes, such as "sh" or "US".
        struct TwoLetterCode: ExpressibleByStringLiteral, Equatable {
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
