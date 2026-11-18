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

        /// Creates the key-value pairs given a "@key=value;..." section of a locale identifier, sorted by key. Keys are lowercased.
        init(normalizing keyValueString: Span<UInt8>) {
            self.init(capacity: keyValueString.count)
            guard var i = keyValueString.firstIndex(from: 1, where: { $0 != ._space }) else { // after the "@"
                return
            }
            while true {
                if keyValueString[i] == UInt8(ascii: ";") {
                    guard let next = keyValueString.firstIndex(from: i + 1, where: { $0 != ._space }) else {
                        return
                    }
                    i = next
                    continue
                }

                let keyStart = bytes.count
                while i < keyValueString.count, keyValueString[i].isAlphanumeric {
                    bytes.append(keyValueString[i]._lowercased)
                    i += 1
                }
                guard bytes.count > keyStart,
                      let equalsIndex = keyValueString.firstIndex(from: i, where: { $0 != ._space }), keyValueString[equalsIndex] == UInt8(ascii: "="),
                      let valueIndex = keyValueString.firstIndex(from: equalsIndex + 1, where: { $0 != ._space }) else {
                    self = Self(capacity: 0)
                    return
                }

                let valueStart = bytes.count
                i = valueIndex
                while i < keyValueString.count {
                    let byte = keyValueString[i]
                    guard byte.isAlphanumeric || byte == ._minus || byte == ._underscore || byte == UInt8(ascii: "+") || byte == UInt8(ascii: "/") else {
                        break
                    }
                    bytes.append(byte)
                    i += 1
                }
                guard bytes.count > valueStart else {
                    self = Self(capacity: 0)
                    return
                }
                createPair(keyStart: keyStart, valueStart: valueStart)

                guard let pairEnd = keyValueString.firstIndex(from: i, where: { $0 != ._space }) else {
                    return
                }
                guard keyValueString[pairEnd] == UInt8(ascii: ";") else {
                    self = Self(capacity: 0)
                    return
                }
                i = pairEnd
            }
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
            var index = 0 // the start of the next singleton
            while index < source.count, Locale.CanonicalizedIdentifier.isSingleton(source, at: index) {
                let singleton = source[index]
                let subtagsStart = index + 2
                if singleton == Locale.CanonicalizedIdentifier.privateUseSingleton {
                    // The private use, "x", is the last part of the tag. Everything after this are the subtag.
                    if subtagsStart < source.count {
                        append(key: source.extracting(index..<(index + 1)), value: source.extracting(subtagsStart...))
                    }
                    return
                }

                // Find the next singleton
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

                if singleton == Locale.CanonicalizedIdentifier.unicodeExtensionSingleton {
                    appendUExtension(from: source.extracting(subtagsStart..<subtagsEnd))
                } else {
                    append(key: source.extracting(index..<(index + 1)), value: source.extracting(subtagsStart..<subtagsEnd))
                }
                index = nextIndex
            }
        }

        /// Splits a whole "u" extension into key-value lists and appends each of them.
        mutating func appendUExtension(from source: Span<UInt8>) {
            // Keeps track of the range of the key and the values, such as "ca-islamic-umalqura".
            var keywordRange: Range<Int>? = nil
            var index = 0
            while index < source.count {
                let end = Locale.CanonicalizedIdentifier.scanSegment(source, fromIndex: index).endIndex
                let length = end - index
                if length == 2 && source[index].isAlphanumeric && source[index + 1].isLetter { // it's a Unicode Extension key
                    if let keywordRange {
                        appendUExtensionKeyword(source.extracting(keywordRange))
                    }
                    keywordRange = index..<end
                } else if let currentKeyword = keywordRange {
                    keywordRange = currentKeyword.lowerBound..<end
                }
                index = end + 1
            }
            if let keywordRange {
                appendUExtensionKeyword(source.extracting(keywordRange))
            }
        }

        /// Appends a pair of key and values of a "u" extension
        private mutating func appendUExtensionKeyword(_ keyword: Span<UInt8>) {
            let key = keyword.extracting(0..<2)
            let type = keyword.count > 2 ? keyword.extracting(3...) : keyword.extracting(2...)

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

        /// Writes the key-value pairs into `output` as "@key=value;...", and returns the ranges in `output`.
        /// Skips a pair whose key is the same as the key before
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

        /// Records the bytes from `keyStart..<valueStart` as the key, and the bytes after as the value.
        mutating func createPair(keyStart: Int, valueStart: Int) {
            var index = ranges.count
            while index > 0, bytes.span.extracting(keyStart..<valueStart).lexicographicallyPrecedes(key(at: index - 1)) {
                index -= 1
            }
            ranges.insert((keyStart..<valueStart, valueStart..<bytes.count), at: index)
        }
    }
}
