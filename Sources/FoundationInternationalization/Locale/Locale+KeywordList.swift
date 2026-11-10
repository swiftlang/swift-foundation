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

extension Locale.CanonicalizedIdentifier {
    /// Key-value pairs, sorted by key.
    struct KeywordList: ~Copyable {
        /// The bytes of all keys and values, in the order they were added.
        var bytes: Bytes
        /// The range in `bytes` of each key and value, sorted by key in byte order. Pairs with equal keys are in the order they were added.
        var ranges: [(key: Range<Int>, value: Range<Int>)] = []

        /// Whether the language tag has an extension other than the private use.
        var hasExtension = false

        init(capacity: Int) {
            bytes = Bytes(capacity: capacity)
        }

        /// Creates the key-value pairs of the "@key=value;..." section of a locale identifier, sorted by key. A key is lowercase.
        /// Removes the spaces around each key and value, and skips an empty pair. If a pair is not valid, the section has no pairs.
        /// A valid pair has a key of letters and digits, "=", and a value of letters, digits, "-", "_", "+" and "/".
        init(normalizing keyValueString: Span<UInt8>) {
            self.init(capacity: keyValueString.count)
            var start = 1 // after the "@"
            while start < keyValueString.count {
                var end = start
                while end < keyValueString.count, keyValueString[end] != UInt8(ascii: ";") {
                    end += 1
                }
                defer { start = end + 1 }
                let pair = Self.trimmingSpaces(start..<end, in: keyValueString)
                if pair.isEmpty {
                    continue
                }

                var isValid = false
                var key = pair
                var value = pair
                if let equalsOffset = keyValueString.extracting(pair).firstIndex(of: UInt8(ascii: "=")) {
                    key = Self.trimmingSpaces(pair.lowerBound..<(pair.lowerBound + equalsOffset), in: keyValueString)
                    value = Self.trimmingSpaces((pair.lowerBound + equalsOffset + 1)..<pair.upperBound, in: keyValueString)
                    isValid = !key.isEmpty && !value.isEmpty
                }
                for i in key where !keyValueString[i].isAlphanumeric {
                    isValid = false
                }
                for i in value where !Self.isKeptInValue(keyValueString[i]) {
                    isValid = false
                }
                guard isValid else {
                    self = Self(capacity: 0)
                    return
                }

                let keyStart = bytes.count
                for i in key {
                    bytes.append(keyValueString[i]._lowercased)
                }
                let valueStart = bytes.count
                bytes.append(copying: keyValueString.extracting(value).bytes)
                createPair(keyStart: keyStart, valueStart: valueStart)
            }
        }

        /// Returns `range` in `source` without the spaces at its start and end.
        private static func trimmingSpaces(_ range: Range<Int>, in source: Span<UInt8>) -> Range<Int> {
            var lowerBound = range.lowerBound
            var upperBound = range.upperBound
            while lowerBound < upperBound, source[lowerBound] == ._space {
                lowerBound += 1
            }
            while upperBound > lowerBound, source[upperBound - 1] == ._space {
                upperBound -= 1
            }
            return lowerBound..<upperBound
        }

        /// Returns whether `byte` is kept in a value of the "@key=value;..." section: a letter, a digit, "-", "_", "+" or "/".
        private static func isKeptInValue(_ byte: UInt8) -> Bool {
            byte.isAlphanumeric || byte == UInt8._minus || byte == UInt8._underscore || byte == UInt8(ascii: "+") || byte == UInt8(ascii: "/")
        }

        /// Creates the key-value pairs of the keywords in `components`, with their ICU names.
        init(components: Locale.Components) {
            self.init(capacity: 0)
            components.forEachICUKeyword { key, value in
                append(key: key.key.utf8Span.span, value: value.utf8Span.span)
            }
        }

        /// Creates the key-value pairs of the extensions and the private use at the end of a lowercase BCP 47 language tag, sorted by key.
        /// For example, "u-ca-chinese-t-fr-x-foo" has the pairs "(calendar, chinese)", "(t, fr)" and "(x, foo)".
        init(languageTagExtensions source: Span<UInt8>) {
            // Guess the size
            self.init(capacity: source.count * 2)

            // Read each extension: a singleton, then its subtags until the next singleton.
            // The private use, "x", is the last part of the tag, so its subtags are the rest of the tag.
            var index = 0 // the start of the next singleton
            while index < source.count, Locale.CanonicalizedIdentifier.isSingleton(source, at: index) {
                let singleton = source[index]
                let subtagsStart = index + 2
                if singleton == Locale.CanonicalizedIdentifier.privateUseSingleton {
                    if subtagsStart < source.count {
                        append(key: source.extracting(index..<(index + 1)), value: source.extracting(subtagsStart...))
                    }
                    return
                }

                // Find the next singleton. The subtags end before its "-", or at the end of the tag.
                var nextIndex = subtagsStart
                while nextIndex < source.count, !Locale.CanonicalizedIdentifier.isSingleton(source, at: nextIndex) {
                    nextIndex = Locale.CanonicalizedIdentifier.scanSegment(source, fromIndex: nextIndex).endIndex + 1
                }
                let subtagsEnd = min(nextIndex - 1, source.count)
                // Stop at an extension without subtags.
                guard subtagsStart < subtagsEnd else {
                    return
                }
                hasExtension = true

                if singleton == UInt8(ascii: "u") {
                    appendUExtensionSubtags(source: source.extracting(subtagsStart..<subtagsEnd))
                } else {
                    append(key: source.extracting(index..<(index + 1)), value: source.extracting(subtagsStart..<subtagsEnd))
                }
                index = nextIndex
            }
        }

        /// Appends the keywords of the subtags of a "u" extension.
        mutating func appendUExtensionSubtags(source: Span<UInt8>) {
            // The current keyword: a key and the subtags of its type, such as "ca-islamic-umalqura".
            var keywordRange: Range<Int>? = nil
            var index = 0
            while index < source.count {
                let end = Locale.CanonicalizedIdentifier.scanSegment(source, fromIndex: index).endIndex
                let length = end - index
                if length == 2 && source[index].isAlphanumeric && source[index + 1].isLetter { // it's a Unicode Extension key
                    if let keywordRange {
                        appendUExtension(keyword: source.extracting(keywordRange))
                    }
                    keywordRange = index..<end
                } else if let currentKeyword = keywordRange {
                    // The subtag is part of the type of the current key. Skip it if there is no key yet, because it is an attribute.
                    keywordRange = currentKeyword.lowerBound..<end
                }
                index = end + 1
            }
            if let keywordRange {
                appendUExtension(keyword: source.extracting(keywordRange))
            }
        }

        /// Appends a "u" extension keyword: a key of 2 characters, then "-" and its type if it has one. For example, "ca-islamic-umalqura" or "kn".
        private mutating func appendUExtension(keyword: Span<UInt8>) {
            let key = keyword.extracting(0..<2)
            let type = keyword.count > 2 ? keyword.extracting(3...) : keyword.extracting(2...)
            // Use the key as written if it has no legacy name. For example, "va" stays "va".
            let legacyKeyName = Locale.legacyKey(forLowercased: key) ?? ""
            let legacyKey = legacyKeyName.isEmpty ? key : legacyKeyName.utf8Span.span

            guard !type.isEmpty else {
                // An empty type defaults to true, whose legacy value is "yes"
                append(key: legacyKey, value: "yes".utf8.span)
                return
            }

            if let legacyValue = Locale.legacyValue(forLowercased: type, key: legacyKey) {
                append(key: legacyKey, value: legacyValue.utf8.span)
            } else {
                append(key: legacyKey, value: type)
            }
        }

        mutating func append(key: Span<UInt8>, value: Span<UInt8>) {
            let keyStart = bytes.count
            bytes.append(copying: key.bytes)

            let valueStart = bytes.count
            bytes.append(copying: value.bytes)

            createPair(keyStart: keyStart, valueStart: valueStart)
        }

        /// Writes the pairs into `output` as "@key=value;...", and returns the ranges of their keys and values in `output`.
        /// Skips a pair whose key is the same as the key before it, so that a repeated key keeps its first value.
        func write(into output: inout OutputSpan<UInt8>) -> Locale.CanonicalizedIdentifier.KeywordRanges {
            var outputRanges: Locale.CanonicalizedIdentifier.KeywordRanges = []
            outputRanges.reserveCapacity(ranges.count)

            for index in ranges.indices {
                if index > 0, key(at: index).elementsEqual(key(at: index - 1)) {
                    continue
                }
                output.append(outputRanges.isEmpty ? ._at : UInt8(ascii: ";"))

                let keyStart = output.count
                output._append(copying: key(at: index))

                let keyEnd = output.count
                output.append(UInt8(ascii: "="))

                let valueStart = output.count
                output._append(copying: value(at: index))

                outputRanges.append((keyStart..<keyEnd, valueStart..<output.count))
            }
            return outputRanges
        }

        /// Returns the key of the pair at `index`.
        @_lifetime(borrow self)
        func key(at index: Int) -> Span<UInt8> {
            bytes.span.extracting(ranges[index].key)
        }

        /// Returns the value of the pair at `index`.
        @_lifetime(borrow self)
        func value(at index: Int) -> Span<UInt8> {
            bytes.span.extracting(ranges[index].value)
        }

        /// Removes each pair with the key `key` and the value `value`. Returns whether it removed a pair.
        mutating func removePairs(key: Span<UInt8>, value: Span<UInt8>) -> Bool {
            var removed = false
            for i in ranges.indices.reversed() where self.key(at: i).elementsEqual(key) && self.value(at: i).elementsEqual(value) {
                ranges.remove(at: i)
                removed = true
            }
            return removed
        }

        /// Records the bytes from `keyStart` to `valueStart` as a key, and the bytes after them as its value.
        /// Inserts the pair after the pairs with a smaller or equal key, so that `ranges` stays sorted and a repeated key keeps its first value first.
        mutating func createPair(keyStart: Int, valueStart: Int) {
            var index = ranges.count
            while index > 0, bytes.span.extracting(keyStart..<valueStart).lexicographicallyPrecedes(key(at: index - 1)) {
                index -= 1
            }
            ranges.insert((keyStart..<valueStart, valueStart..<bytes.count), at: index)
        }
    }
}
