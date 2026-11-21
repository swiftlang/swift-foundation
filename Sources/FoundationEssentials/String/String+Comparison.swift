//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

package extension UTF8.CodeUnit {
    var _numericValue: Int? {
        if self >= 48 && self <= 57 {
            return Int(self - 48)
        }
        return nil
    }

    // Copied from std; see comment in String.swift _uppercaseASCII() and _lowercaseASCII()
    var _lowercased: Self {
        let _uppercaseTable: UInt64 =
              0b0000_0000_0000_0000_0001_1111_1111_1111 &<< 32
        let isUpper = _uppercaseTable &>> UInt64(((self &- 1) & 0b0111_1111) &>> 1)
        let toAdd = (isUpper & 0x1) &<< 5
        return self &+ UInt8(truncatingIfNeeded: toAdd)
    }

    var _uppercased: Self {
        let _lowercaseTable: UInt64 =
              0b0001_1111_1111_1111_0000_0000_0000_0000 &<< 32
        let isLower = _lowercaseTable &>> UInt64(((self &- 1) & 0b0111_1111) &>> 1)
        let toSubtract = (isLower & 0x1) &<< 5
        return self &- UInt8(truncatingIfNeeded: toSubtract)
    }
}

// MARK: - _StringCompareOptionsIterable Methods
// Internal protocols to share the implementation for iterating BidirectionalCollections of String family and process their elements according to String.CompareOptions.
#if !NO_UNI_CHAR_DATA
internal protocol _StringCompareOptionsConvertible : Comparable & Equatable {
    associatedtype IterableType: _StringCompareOptionsIterable
    func _transform(toHalfWidth: Bool, stripDiacritics: Bool, caseFolding: Bool) -> IterableType
    var intValue: Int? { get }
    var isExtendCharacter: Bool { get }
}

internal protocol _StringCompareOptionsIterable : BidirectionalCollection where Element: _StringCompareOptionsConvertible, Element.IterableType.SubSequence == Self.SubSequence, Element == SubSequence.Element {
    init()
    var first: Element? { get }
    func _consumeExtendCharacters(from i: inout Index)
    func consumeNumbers(from i: inout Index, initialValue: Int) -> Int
}
#else
internal protocol _StringCompareOptionsConvertible : Comparable & Equatable {
    var intValue: Int? { get }
}

internal protocol _StringCompareOptionsIterable : BidirectionalCollection where Element: _StringCompareOptionsConvertible, Element == SubSequence.Element {
    init()
    var first: Element? { get }
    func consumeNumbers(from i: inout Index, initialValue: Int) -> Int
}
#endif

extension _StringCompareOptionsIterable {
    func consumeNumbers(from i: inout Index, initialValue: Int) -> Int {
        guard i < endIndex else {
            return initialValue
        }

        var value = initialValue
        while i < endIndex {
            let c = self[i]
            guard let num = c.intValue else {
                break
            }
            // equivalent to `value = value * 10 + num` but considering overflow
            let multiplied = value.multipliedReportingOverflow(by: 10)
            guard !multiplied.overflow else { break }

            let added = multiplied.partialValue.addingReportingOverflow(num)
            guard !added.overflow else { break }

            value = added.partialValue
            self.formIndex(after: &i)
        }

        return value
    }

#if !NO_UNI_CHAR_DATA
    func _consumeExtendCharacters(from i: inout Index) {
        while i < endIndex, self[i].isExtendCharacter {
            formIndex(after: &i)
        }
    }

    func _compare<S: _StringCompareOptionsIterable>(_ other: S, toHalfWidth: Bool, diacriticsInsensitive: Bool, caseFold: Bool, numeric: Bool, forceOrdering: Bool) -> ComparisonResult where S.Element == Element {

        var idx1 = self.startIndex
        var idx2 = other.startIndex

        var compareResult: ComparisonResult = .orderedSame

        var norm1 = _StringCompareOptionsIterableBuffer<Element.IterableType>()
        var norm2 = _StringCompareOptionsIterableBuffer<Element.IterableType>()

        while idx1 < self.endIndex && idx2 < other.endIndex {
            var c1: Element
            var c2: Element
            if norm1.isEmpty {
                c1 = self[idx1]
            } else {
                c1 = norm1.current
                norm1.advance()
            }

            if norm2.isEmpty {
                c2 = other[idx2]
            } else {
                c2 = norm2.current
                norm2.advance()
            }

            if numeric, norm1.isEmpty, norm2.isEmpty, c1.intValue != nil,  c2.intValue != nil {
                let value1 = self.consumeNumbers(from: &idx1, initialValue: 0)
                let value2 = other.consumeNumbers(from: &idx2, initialValue: 0)

                if value1 == value2 {
                    if forceOrdering {
                        let dist1 = self.distance(from: startIndex, to: idx1)
                        let dist2 = other.distance(from: other.startIndex, to: idx2)
                        if dist1 != dist2 {
                            compareResult = ComparisonResult(dist1, dist2)
                        }
                    }
                    continue
                } else {
                    return ComparisonResult(value1, value2)
                }
            }

            if diacriticsInsensitive && idx1 > startIndex {
                var str1Skip = false
                var str2Skip = false
                if norm1.isEmpty && c1.isExtendCharacter {
                    c1 = c2
                    str1Skip = true
                }

                if norm2.isEmpty && c2.isExtendCharacter {
                    c2 = c1
                    str2Skip = true
                }

                if str1Skip != str2Skip {
                    if str1Skip {
                        other.formIndex(before: &idx2)
                    } else {
                        formIndex(before: &idx1)
                    }
                }
            }

            if c1 != c2 {
                if !(toHalfWidth || diacriticsInsensitive || caseFold) {
                    return ComparisonResult(c1, c2)
                }

                if forceOrdering && compareResult == .orderedSame {
                    compareResult = ComparisonResult(c1, c2)
                }

                if norm1.isEmpty {
                    let t1 = c1._transform(toHalfWidth: toHalfWidth, stripDiacritics: diacriticsInsensitive, caseFolding: caseFold)
                    if let first = t1.first {
                        c1 = first
                        norm1 = .init(t1)
                        norm1.advance()
                    }
                }

                if norm1.isEmpty && !norm2.isEmpty {
                    return ComparisonResult(c1, c2)
                }

                if norm2.isEmpty && (norm1.isEmpty || c1 != c2) {
                    let t2 = c2._transform(toHalfWidth: toHalfWidth, stripDiacritics: diacriticsInsensitive, caseFolding: caseFold)
                    if let first = t2.first {
                        c2 = first
                        norm2 = .init(t2)
                        norm2.advance()
                    }

                    if norm2.isEmpty || c1 != c2 {
                        return ComparisonResult(c1, c2)
                    }
                }

                if !norm1.isEmpty && !norm2.isEmpty {
                    while !norm1.isEnd && !norm2.isEnd {
                        if norm1.current != norm2.current {
                            break
                        }
                        norm1.advance()
                        norm2.advance()
                    }

                    if !norm1.isEnd && !norm2.isEnd {
                        return ComparisonResult(norm1.current, norm2.current)
                    }
                }
            }

            if !norm1.isEmpty && norm1.isEnd {
                norm1.clear()
            }

            if !norm2.isEmpty && norm2.isEnd {
                norm2.clear()
            }

            if norm1.isEmpty {
                formIndex(after: &idx1)
            }

            if norm2.isEmpty {
                other.formIndex(after: &idx2)
            }
        }

        // Process the trailing diacritics, if there's any
        if diacriticsInsensitive {
            self._consumeExtendCharacters(from: &idx1)
            other._consumeExtendCharacters(from: &idx2)
        }

        let result = ComparisonResult(stringIndex: idx1, idx2: idx2, endIndex1: endIndex, endIndex2: other.endIndex)
        return result == .orderedSame ? compareResult : result
    }
#endif

    func _range<S: BidirectionalCollection>(of strToFind: S, toHalfWidth: Bool, diacriticsInsensitive: Bool, caseFold: Bool, anchored: Bool, backwards: Bool) -> Range<Index>? where S.Index == Index, S.Element == Element {

        if !toHalfWidth && !diacriticsInsensitive && !caseFold {
            return _range(of: strToFind, anchored: anchored, backwards: backwards)
        }

#if !NO_UNI_CHAR_DATA
        // These options may cause the string to change their count
        let lengthVariants = caseFold || diacriticsInsensitive

        var fromLoc: Index
        var toLoc: Index
        if backwards {
            if lengthVariants {
                fromLoc = index(endIndex, offsetBy: -1)
            } else {
                guard let idx = _index(endIndex, backwardsOffsetByCountOf: strToFind) else {
                    return nil
                }
                fromLoc = idx
            }
            toLoc = (anchored && !lengthVariants) ? fromLoc : startIndex
        } else {
            fromLoc = startIndex
            if anchored {
                toLoc = fromLoc
            } else if lengthVariants {
                toLoc = index(endIndex, offsetBy: -1)
            } else {
                guard let idx = _index(endIndex, backwardsOffsetByCountOf: strToFind) else {
                    return nil
                }
                toLoc = idx
            }
        }

        let delta = fromLoc <= toLoc ? 1 : -1
        var result: Range<Index>? = nil

        while true {
            // Outer loop: loops through `self`

            var str1Char: Element
            var str2Char: Element

            var str1Index = fromLoc
            var str2Index = strToFind.startIndex

            var useStrBuf1 = false
            var useStrBuf2 = false

            var strBuf1 = _StringCompareOptionsIterableBuffer<Element.IterableType>()
            var strBuf2 = _StringCompareOptionsIterableBuffer<Element.IterableType>()

            while str2Index < strToFind.endIndex {
                // Inner loop: loops through `strToFind`
                if !useStrBuf1 {
                    if str1Index == endIndex {
                        break
                    }
                    str1Char = self[str1Index]
                } else {
                    str1Char = strBuf1.current
                    strBuf1.advance()
                }

                if !useStrBuf2 {
                    str2Char = strToFind[str2Index]
                } else {
                    str2Char = strBuf2.current
                    strBuf2.advance()
                }

                if str1Char != str2Char {
                    if !useStrBuf1 {
                        let transformed = str1Char._transform(toHalfWidth: toHalfWidth, stripDiacritics: diacriticsInsensitive, caseFolding: caseFold)

                        if let c = transformed.first {
                            str1Char = c
                            strBuf1 = .init(transformed)
                            strBuf1.advance()
                            useStrBuf1 = true
                        }
                    }

                    if !useStrBuf1 && useStrBuf2 { break }

                    if !useStrBuf2 && (!useStrBuf1 || str1Char != str2Char) {
                        let transformed = str2Char._transform(toHalfWidth: toHalfWidth, stripDiacritics: diacriticsInsensitive, caseFolding: caseFold)
                        if let c = transformed.first {
                            str2Char = c
                            strBuf2 = .init(transformed)
                            strBuf2.advance()
                            useStrBuf2 = true
                        }
                    }

                    if str1Char != str2Char {
                        break
                    }
                }

                if useStrBuf1 && useStrBuf2 {
                    while !strBuf1.isEnd && !strBuf2.isEnd {
                        if strBuf1.current != strBuf2.current {
                            break
                        }
                        strBuf1.advance()
                        strBuf2.advance()
                    }

                    if !strBuf1.isEnd && !strBuf2.isEnd {
                        break
                    }

                }

                if useStrBuf1 && strBuf1.isEnd {
                    useStrBuf1 = false
                }

                if useStrBuf2 && strBuf2.isEnd {
                    useStrBuf2 = false
                }

                if !useStrBuf1 {
                    formIndex(after: &str1Index)
                }

                if !useStrBuf2 {
                    strToFind.formIndex(after: &str2Index)
                }
            }

            if str2Index == strToFind.endIndex {
                // If `self` has extended characters following the lastly matched character, consume these
                var match = true
                if useStrBuf1 {
                    // if strToFind matches the string after transformed (strBuf1), try consuming extended characters from the buffer first
                    match = false
                    if diacriticsInsensitive {
                        strBuf1._consumeExtendCharacters()
                    }

                    if strBuf1.isEnd {
                        formIndex(after: &str1Index)
                        match = true
                    }
                }

                // After using up strBuf1, inspect the rest of original strings in `self`
                if match && diacriticsInsensitive && str1Index < endIndex {
                    _consumeExtendCharacters(from: &str1Index)
                }

                if match {
                    if !(anchored && backwards) || str1Index == endIndex {
                        result = fromLoc..<str1Index
                    }
                    break
                }
            }

            if fromLoc == toLoc { break }
            formIndex(&fromLoc, offsetBy: delta)
        }

        return result
#else
        // Without Unicode character data, toHalfWidth, diacriticsInsensitive and caseFold are not supported.
        guard !toHalfWidth && !diacriticsInsensitive && !caseFold else {
            fatalError("Unicode character data is not avaiable")
        }
        return _range(of: strToFind, anchored: anchored, backwards: backwards)
#endif
    }
}

extension String : _StringCompareOptionsIterable {}
extension Substring: _StringCompareOptionsIterable {}
extension String.UnicodeScalarView: _StringCompareOptionsIterable {}
extension Substring.UnicodeScalarView: _StringCompareOptionsIterable {}
extension String.UTF8View: _StringCompareOptionsIterable {
    init() {
        self = String().utf8
    }
}
extension Substring.UTF8View: _StringCompareOptionsIterable {
    init() {
        self = Substring().utf8
    }
}

extension Unicode.UTF8.CodeUnit : _StringCompareOptionsConvertible {
    func _transform(toHalfWidth: Bool, stripDiacritics: Bool, caseFolding: Bool) -> String.UTF8View {
        String(unsafeUninitializedCapacity: 1) {
            $0[0] = caseFolding ? self._lowercased : self
            return 1
        }.utf8
    }

    var intValue: Int? {
        return (self >= 48 || self <= 57) ? Int(self - 48) : nil
    }

    var isExtendCharacter: Bool {
        // This won't really get called and will be removed in a future PR
        return false
    }
}

extension Character : _StringCompareOptionsConvertible {

#if !NO_UNI_CHAR_DATA
    func _transform(toHalfWidth: Bool, stripDiacritics: Bool, caseFolding: Bool) -> String {
        if isASCII {
            // we only need to handle case folding, in which case is just lower case
            return caseFolding ? lowercased() : String(self)
        }

        var new = ""
        for scalar in unicodeScalars {
            var tmp = scalar
            if toHalfWidth {
                tmp = scalar._toHalfWidth()
            }

            if stripDiacritics {
                if scalar._isGraphemeExtend {
                    // skip this
                    continue
                } else {
                    tmp = tmp._stripDiacritics()
                }
            }

            if caseFolding {
                new += tmp._caseFoldMapping
            } else {
                new += String(tmp)
            }
        }

        return String(new)
    }
#endif

    var intValue: Int? {
        return wholeNumberValue
    }

#if !NO_UNI_CHAR_DATA
    var isExtendCharacter: Bool {
        guard !self.isASCII else {
            return false
        }

        return unicodeScalars.allSatisfy { $0._isGraphemeExtend }
    }
#endif

}

extension UnicodeScalar : _StringCompareOptionsConvertible {
#if !NO_UNI_CHAR_DATA
    func _transform(toHalfWidth: Bool, stripDiacritics: Bool, caseFolding: Bool) -> String.UnicodeScalarView {

        var new = self
        if toHalfWidth {
            new = new._toHalfWidth()
        }

        if stripDiacritics {
            if new._isGraphemeExtend {
                return String.UnicodeScalarView()
            } else {
                new = new._stripDiacritics()
            }
        }

        if caseFolding {
            return new._caseFoldMapping.unicodeScalars
        } else {
            return String(new).unicodeScalars
        }
    }
#endif

    var intValue: Int? {
        guard let v = properties.numericValue else {
            return nil
        }
        return Int(v)
    }

#if !NO_UNI_CHAR_DATA
    var isExtendCharacter: Bool {
        return _isGraphemeExtend
    }
#endif
}

#if !NO_UNI_CHAR_DATA
// MARK: - _StringCompareOptionsIterableBuffer
internal struct _StringCompareOptionsIterableBuffer<StorageType: _StringCompareOptionsIterable> {
    var _buf: StorageType
    var _index: StorageType.Index

    init() {
        _buf = StorageType()
        _index = _buf.startIndex
    }

    init(_ content: StorageType) {
        _buf = content
        _index = _buf.startIndex
    }

    var current: StorageType.Element {
        return _buf[_index]
    }

    mutating func advance() {
        _buf.formIndex(after: &_index)
    }

    var isEnd: Bool {
        return _index == _buf.endIndex
    }

    var isEmpty: Bool {
        return _buf.isEmpty
    }

    mutating func _consumeExtendCharacters() {
        _buf._consumeExtendCharacters(from: &_index)
    }

    mutating func clear() {
        self = .init()
    }
}
#endif

// MARK: Comparison Implementations
extension Substring {
#if !NO_UNI_CHAR_DATA
    func _unlocalizedCompare(other: Substring, options: String.CompareOptions) -> ComparisonResult {
        if options.isEmpty {
            return ComparisonResult(self, other)
        }

        let diacriticInsensitive = options.contains(.diacriticInsensitive)
        let toHalfWidth = options.contains(.widthInsensitive)
        let caseFold = options.contains(.caseInsensitive)
        let numeric = options.contains(.numeric)
        let forceOrdering = options.contains(.forcedOrdering)

        var result: ComparisonResult
        if options.contains(.literal) {
            // Per documentation, literal means "Performs a byte-for-byte comparison. Differing literal sequences (such as composed character sequences) that would otherwise be considered equivalent are considered not to match." Therefore we're comparing the scalars rather than characters
            result = unicodeScalars._compare(other.unicodeScalars, toHalfWidth: toHalfWidth, diacriticsInsensitive: diacriticInsensitive, caseFold: caseFold, numeric: numeric, forceOrdering: forceOrdering)
        } else {
            result = _compare(other, toHalfWidth: toHalfWidth, diacriticsInsensitive: diacriticInsensitive, caseFold: caseFold, numeric: numeric, forceOrdering: forceOrdering)
        }

        if result == .orderedSame && forceOrdering {
            result = unicodeScalars._compare(other.unicodeScalars)
        }

        return result
    }
#endif

    func _rangeOfCharacter(from set: CharacterSet, options: String.CompareOptions) -> Range<Index>? {
        guard !isEmpty else { return nil }

        return unicodeScalars._rangeOfCharacter(anchored: options.contains(.anchored), backwards: options.contains(.backwards), matchingPredicate: set.contains)
    }

    func _components(separatedBy characterSet: CharacterSet) -> [String] {
        var result = [String]()
        var searchStart = startIndex
        while searchStart < endIndex {
            let r = self[searchStart...]._rangeOfCharacter(from: characterSet, options: [])
            guard let r, !r.isEmpty else {
                break
            }

            result.append(String(self[searchStart ..< r.lowerBound]))
            searchStart = r.upperBound
        }

        result.append(String(self[searchStart..<endIndex]))

        return result
    }

#if !NO_UNI_CHAR_DATA
    func _rangeOfCharacter(from set: BuiltInUnicodeScalarSet, options: String.CompareOptions) -> Range<Index>? {
        guard !isEmpty else { return nil }

        return unicodeScalars._rangeOfCharacter(anchored: options.contains(.anchored), backwards: options.contains(.backwards), matchingPredicate: set.contains)
    }
#endif

    func _range(of strToFind: Substring, options: String.CompareOptions) throws -> Range<Index>? {
        #if !NO_REGEX && !hasFeature(Embedded)
        if options.contains(.regularExpression) {
            guard let regex = try RegexPatternCache.cache.regex(for: String(strToFind), caseInsensitive: options.contains(.caseInsensitive)) else {
                return nil
            }

            if options.contains(.anchored) {
                guard let match = prefixMatch(of: regex) else { return nil }
                return match.range
            } else {
                guard let match = firstMatch(of: regex) else { return nil }
                return match.range
            }
        }
        #endif
        
        guard !isEmpty, !strToFind.isEmpty else {
            return nil
        }

        let toHalfWidth = options.contains(.widthInsensitive)
        let diacriticsInsensitive = options.contains(.diacriticInsensitive)
        let caseFold = options.contains(.caseInsensitive)
        let anchored = options.contains(.anchored)
        let backwards = options.contains(.backwards)

        let literal = options.contains(.literal)
        if isContiguousUTF8, strToFind.isContiguousUTF8, (literal && !(toHalfWidth || diacriticsInsensitive || caseFold)) || strToFind.utf8Span.isKnownASCII || strToFind.utf8.allSatisfy({ $0 < 0x80 }) {
            return utf8Range(of: strToFind, options: options)
        }

        if literal {
            return unicodeScalars._range(of: strToFind.unicodeScalars, toHalfWidth: toHalfWidth, diacriticsInsensitive: diacriticsInsensitive, caseFold: caseFold, anchored: anchored, backwards: backwards)
        } else {
            return _range(of: strToFind, toHalfWidth: toHalfWidth, diacriticsInsensitive: diacriticsInsensitive, caseFold: caseFold, anchored: anchored, backwards: backwards)
        }
    }

    func _components(separatedBy separator: Substring, options: String.CompareOptions = []) throws -> [String] {
        var result = [String]()
        try _enumerateComponents(separatedBy: separator, options: options) { substr, _ in
            result.append(String(substr))
        }
        return result
    }

    // Only throws when using `.regularExpression` option
    package func _enumerateComponents(separatedBy separator: Substring, options: String.CompareOptions, withBlock block: (_ component: Substring, _ isLastComponent: Bool) -> ()) throws {
        var searchStart = startIndex
        while searchStart < endIndex {
            let r = try self[searchStart...]._range(of: separator, options: options)
            guard let r, !r.isEmpty else {
                break
            }

            block(self[searchStart ..< r.lowerBound], false)
            searchStart = r.upperBound
        }

        block(self[searchStart..<endIndex], true)
    }
}

extension Substring.UnicodeScalarView {
    func _compare(_ other: Substring.UnicodeScalarView) -> ComparisonResult {
        var idx1 = startIndex
        var idx2 = other.startIndex

        var scalar1: Unicode.Scalar
        var scalar2: Unicode.Scalar
        while idx1 < endIndex && idx2 < other.endIndex {
            scalar1 = self[idx1]
            scalar2 = other[idx2]

            if scalar1 == scalar2 {
                self.formIndex(after: &idx1)
                other.formIndex(after: &idx2)
                continue
            } else {
                return ComparisonResult(scalar1, scalar2)
            }
        }

        return ComparisonResult(stringIndex: idx1, idx2: idx2, endIndex1: endIndex, endIndex2: other.endIndex)
    }

    func _rangeOfCharacter(anchored: Bool, backwards: Bool, matchingPredicate predicate: (Unicode.Scalar) -> Bool) -> Range<Index>? {
        guard !isEmpty else { return nil }

        let fromLoc: String.Index
        let toLoc: String.Index
        let step: Int
        if backwards {
            fromLoc = index(before: endIndex)
            toLoc = anchored ? fromLoc : startIndex
            step = -1
        } else {
            fromLoc = startIndex
            toLoc = anchored ? fromLoc : index(before: endIndex)
            step = 1
        }

        var done = false
        var found = false

        var idx = fromLoc
        while !done {
            let ch = self[idx]
            if predicate(ch) {
                done = true
                found = true
            } else if idx == toLoc {
                done = true
            } else {
                formIndex(&idx, offsetBy: step)
            }
        }

        guard found else { return nil }
        return idx..<index(after: idx)
    }
}

// MARK: - ComparisonResult Extension
extension ComparisonResult {
    init<Index: Equatable>(stringIndex idx1: Index, idx2: Index, endIndex1: Index, endIndex2: Index) {
        if idx1 == endIndex1 && idx2 == endIndex2 {
            self = .orderedSame
        } else if idx1 == endIndex1 {
            self = .orderedAscending
        } else {
            self = .orderedDescending
        }
    }
}

// Borrowed from stdlib
internal func _allASCII(_ input: UnsafeBufferPointer<UInt8>) -> Bool {
    if input.isEmpty { return true }
    let ptr = input.baseAddress.unsafelyUnwrapped
    var i = 0

    let count = input.count
    let stride = MemoryLayout<UInt>.stride
    let address = Int(bitPattern: ptr)

    let wordASCIIMask = UInt(truncatingIfNeeded: 0x8080_8080_8080_8080 as UInt64)
    let byteASCIIMask = UInt8(truncatingIfNeeded: wordASCIIMask)

    while (address &+ i) % stride != 0 && i < count {
        guard ptr[i] & byteASCIIMask == 0 else { return false }
        i &+= 1
    }

    while (i &+ stride) <= count {
        let word: UInt = UnsafePointer(bitPattern: address &+ i).unsafelyUnwrapped.pointee
        guard word & wordASCIIMask == 0 else { return false }
        i &+= stride
    }

    while i < count {
        guard ptr[i] & byteASCIIMask == 0 else { return false }
        i &+= 1
    }
    return true
}

// MARK: - UTF-8 search

extension Substring {
    private enum UTF8Comparison {
        case match(end: Int)
        case noMatch
        /// Non-ASCII text at this position can change the result, so the characters must be compared.
        case compareCharacters
    }

    /// Finds the same range as the character search when the string to find is ASCII, or when the search is `.literal` without other options. It tries the same start positions in the same order, but compares UTF-8 code units, and compares characters only next to non-ASCII text.
    private func utf8Range(of strToFind: Substring, options: String.CompareOptions) -> Range<Index>? {
        guard let startOffsets = startOffsets(of: strToFind, options: options) else {
            return nil
        }
        let haystack = utf8Span.span
        let needle = strToFind.utf8Span.span
        let backwards = options.contains(.backwards)
        let caseFold = options.contains(.caseInsensitive)
        let firstByte = caseFold ? needle[0]._lowercased : needle[0]
        for offset in stride(from: startOffsets.first, through: startOffsets.last, by: backwards ? -1 : 1) {
            // Most positions do not match on the first code unit. An ASCII code unit that differs from the first one of the string to find cannot start a match.
            let byte = haystack[offset]
            if byte < 0x80 && (caseFold ? byte._lowercased : byte) != firstByte {
                continue
            }
            let range: Range<Index>
            switch Self.compareCodeUnits(haystack, at: offset, with: needle, options: options) {
            case .noMatch:
                continue
            case .match(let end):
                range = utf8Index(offset) ..< utf8Index(end)
            case .compareCharacters:
                guard let characterRange = characterRange(of: strToFind, at: utf8Index(offset), options: options) else {
                    continue
                }
                range = characterRange
            }
            // Like the character search, an anchored backwards search stops at the first match from the end, and finds nothing if that match does not reach the end.
            return options.contains(.anchored) && backwards && range.upperBound != endIndex ? nil : range
        }
        return nil
    }

    /// The UTF-8 offsets of the first and the last start position that the character search tries.
    private func startOffsets(of strToFind: Substring, options: String.CompareOptions) -> (first: Int, last: Int)? {
        let anchored = options.contains(.anchored)
        let backwards = options.contains(.backwards)
        if anchored && !backwards {
            return (0, 0)
        }
        // The character search tries every start position when the options can change the length of a match. Otherwise it skips the positions too close to the end.
        let lengthVariants = options.contains(.caseInsensitive) || options.contains(.diacriticInsensitive)
        let literal = options.contains(.literal)
        let lastStart: Index?
        if lengthVariants {
            lastStart = literal ? unicodeScalars.index(before: endIndex) : index(before: endIndex)
        } else {
            lastStart = literal ? unicodeScalars._index(endIndex, backwardsOffsetByCountOf: strToFind.unicodeScalars) : _index(endIndex, backwardsOffsetByCountOf: strToFind)
        }
        guard let lastStart else {
            return nil
        }
        let lastOffset = utf8.distance(from: startIndex, to: lastStart)
        if !backwards {
            return (0, lastOffset)
        }
        return (lastOffset, anchored && !lengthVariants ? lastOffset : 0)
    }

    /// Compares the string to find with the code units at `offset`. For an ASCII string to find, the code units decide only when the match and its neighbors are ASCII. The caller has already checked that an ASCII code unit at `offset` matches the first code unit of the string to find.
    private static func compareCodeUnits(_ haystack: Span<UInt8>, at offset: Int, with needle: Span<UInt8>, options: String.CompareOptions) -> UTF8Comparison {
        let literal = options.contains(.literal)
        let caseFold = options.contains(.caseInsensitive)
        let hasTransforms = caseFold || options.contains(.diacriticInsensitive) || options.contains(.widthInsensitive)
        let end = offset + needle.count
        if literal && !hasTransforms {
            // Equal scalars have equal code units.
            guard end <= haystack.count else {
                return .noMatch
            }
            for i in needle.indices where haystack[offset + i] != needle[i] {
                return .noMatch
            }
            return .match(end: end)
        }

        let byte = haystack[offset]
        if byte >= 0x80 {
            // A non-ASCII character can match an ASCII one when an option transforms it, or when it is canonically equivalent to it. Only three scalars are: U+037E, U+1FEF and U+212A, whose canonical decompositions are ";", "`" and "K".
            let canMatch = hasTransforms || (!literal && (needle[0] == ._semicolon || needle[0] == UInt8(ascii: "`") || needle[0] == UInt8(ascii: "K")))
            let startsScalar = byte & 0xC0 != 0x80
            return canMatch && startsScalar ? .compareCharacters : .noMatch
        }
        // The only two ASCII scalars that form one character are "\r\n". A non-ASCII scalar can join an ASCII one into a larger character.
        if !literal && offset > 0 {
            if haystack[offset - 1] >= 0x80 {
                return .compareCharacters
            }
            if haystack[offset - 1] == ._return && byte == ._newline {
                return .noMatch
            }
        }
        for i in needle.indices {
            guard offset + i < haystack.count else {
                return .noMatch
            }
            let byte = haystack[offset + i]
            if byte >= 0x80 {
                return .compareCharacters
            }
            if byte != needle[i] && !(caseFold && byte._lowercased == needle[i]._lowercased) {
                return .noMatch
            }
        }
        if end < haystack.count {
            if haystack[end] >= 0x80 {
                return .compareCharacters
            }
            if !literal && haystack[end - 1] == ._return && haystack[end] == ._newline {
                return .noMatch
            }
        }
        return .match(end: end)
    }

    /// Compares the characters, or the scalars for `.literal`, at one start position, the way the character search does.
    private func characterRange(of strToFind: Substring, at position: Index, options: String.CompareOptions) -> Range<Index>? {
        let toHalfWidth = options.contains(.widthInsensitive)
        let diacriticsInsensitive = options.contains(.diacriticInsensitive)
        let caseFold = options.contains(.caseInsensitive)
        if options.contains(.literal) {
            return self[position...].unicodeScalars._range(of: strToFind.unicodeScalars, toHalfWidth: toHalfWidth, diacriticsInsensitive: diacriticsInsensitive, caseFold: caseFold, anchored: true, backwards: false)
        }
        // A position inside a character is not a start position.
        guard _index(roundingDown: position) == position else {
            return nil
        }
        return self[position...]._range(of: strToFind, toHalfWidth: toHalfWidth, diacriticsInsensitive: diacriticsInsensitive, caseFold: caseFold, anchored: true, backwards: false)
    }

    private func utf8Index(_ offset: Int) -> Index {
        utf8.index(startIndex, offsetBy: offset)
    }
}
