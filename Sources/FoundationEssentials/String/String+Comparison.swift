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

// MARK: - Exported Types
extension String {
#if FOUNDATION_FRAMEWORK
    public typealias CompareOptions = NSString.CompareOptions
#else
    /// These options apply to the various search/find and comparison methods (except where noted).
    public struct CompareOptions : OptionSet, Sendable {
        public let rawValue: UInt

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        static let caseInsensitive = CompareOptions(rawValue: 1)
        /// Exact character-by-character equivalence
        static let literal = CompareOptions(rawValue: 2)
        /// Search from end of source string
        static let backwards = CompareOptions(rawValue: 4)
        /// Search is limited to start (or end, if `.backwards`) of source string
        static let anchored  = CompareOptions(rawValue: 8)
        /// Numbers within strings are compared using numeric value, that is,
        /// Foo2.txt < Foo7.txt < Foo25.txt;
        /// only applies to compare methods, not find
        static let numeric   = CompareOptions(rawValue: 64)
        /// If specified, ignores diacritics (o-umlaut == o)
        static let diacriticInsensitive = CompareOptions(rawValue: 128)
        /// If specified, ignores width differences ('a' == UFF41)
        static let widthInsensitive = CompareOptions(rawValue: 256)
        /// If specified, comparisons are forced to return either `.orderedAscending`
        /// or `.orderedDescending` if the strings are equivalent but not strictly equal,
        /// for stability when sorting (e.g. "aaa" > "AAA" with `.caseInsensitive` specified)
        static let forcedOrdering = CompareOptions(rawValue: 512)
        /// The search string is treated as an ICU-compatible regular expression;
        /// if set, no other options can apply except `.caseInsensitive` and `.anchored`
        static let regularExpression = CompareOptions(rawValue: 1024)
    }
#endif // FOUNDATION_FRAMEWORK
}

extension UTF8.CodeUnit {
    static let newline: Self = 0x0A
    static let carriageReturn: Self = 0x0D

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

extension _StringCompareOptionsIterable {
    func consumeNumbers(from i: inout Index, initialValue: Int) -> Int {
        guard i < endIndex else {
            return initialValue
        }

        var value = initialValue
        while i < endIndex {
            let c = self[i]
            guard let num = c.intValue else  {
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

            if c1 != c2  {
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

    func _range<S: BidirectionalCollection>(of strToFind: S, toHalfWidth: Bool, diacriticsInsensitive: Bool, caseFold: Bool, anchored: Bool, backwards: Bool) -> Range<Index>? where S.Index == Index, S.Element == Element {

        if !toHalfWidth && !diacriticsInsensitive && !caseFold {
            return _range(of: strToFind, anchored: anchored, backwards: backwards)
        }

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

                        if str1Char != transformed.first {
                            break
                        }
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

    var intValue: Int? {
        return wholeNumberValue
    }

    var isExtendCharacter: Bool {
        guard !self.isASCII else {
            return false
        }

        return unicodeScalars.allSatisfy { $0._isGraphemeExtend }
    }

}

extension UnicodeScalar : _StringCompareOptionsConvertible {
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

    var intValue: Int? {
        guard let v = properties.numericValue else {
            return nil
        }
        return Int(v)
    }

    var isExtendCharacter: Bool {
        return _isGraphemeExtend
    }
}

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

// MARK: Comparison Implementations
extension Substring {
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

#if FOUNDATION_FRAMEWORK
    func _rangeOfCharacter(from set: CharacterSet, options: String.CompareOptions) -> Range<Index>? {
        guard !isEmpty else { return nil }

        return unicodeScalars._rangeOfCharacter(anchored: options.contains(.anchored), backwards: options.contains(.backwards), matchingPredicate: set.contains)
    }
#endif

    func _rangeOfCharacter(from set: BuiltInUnicodeScalarSet, options: String.CompareOptions) -> Range<Index>? {
        guard !isEmpty else { return nil }

        return unicodeScalars._rangeOfCharacter(anchored: options.contains(.anchored), backwards: options.contains(.backwards), matchingPredicate: set.contains)
    }

    func _range(of strToFind: Substring, options: String.CompareOptions) throws -> Range<Index>? {
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

        guard !isEmpty, !strToFind.isEmpty else {
            return nil
        }

        let toHalfWidth = options.contains(.widthInsensitive)
        let diacriticsInsensitive = options.contains(.diacriticInsensitive)
        let caseFold = options.contains(.caseInsensitive)
        let anchored = options.contains(.anchored)
        let backwards = options.contains(.backwards)

        let result: Range<Index>?
        if options.contains(.literal) {
            result = unicodeScalars._range(of: strToFind.unicodeScalars, toHalfWidth: toHalfWidth, diacriticsInsensitive: diacriticsInsensitive, caseFold: caseFold, anchored: anchored, backwards: backwards)
        } else if !toHalfWidth && !diacriticsInsensitive && !caseFold {
            // Fast path: iterate through UTF8 view when we don't need to transform string content
            guard let utf8Result = utf8._range(of: strToFind.utf8, anchored: anchored, backwards: backwards) else {
                 return nil
            }

            // Adjust the index to that of the original slice since we called `makeContiguousUTF8` before
            guard let lower = String.Index(utf8Result.lowerBound, within: self), let upper = String.Index(utf8Result.upperBound, within: self) else {
                return nil
            }
            result = lower..<upper

        } else if _isASCII && strToFind._isASCII {
            // Fast path: Iterate utf8 without having to decode as unicode scalars. In this case only case folding matters.

            guard let utf8Result = utf8._range(of: strToFind.utf8, toHalfWidth: false, diacriticsInsensitive: false, caseFold: caseFold, anchored: anchored, backwards: backwards) else {
                return nil
            }

            // Adjust the index to that of the original slice since we called `makeContiguousUTF8` before
            guard let lower = String.Index(utf8Result.lowerBound, within: self), let upper = String.Index(utf8Result.upperBound, within: self) else {
                return nil
            }
            result = lower..<upper

        } else {
            result = _range(of: strToFind, toHalfWidth: toHalfWidth, diacriticsInsensitive: diacriticsInsensitive, caseFold: caseFold, anchored: anchored, backwards: backwards)
        }

        return result
    }

    var _isASCII: Bool {
        var mutated = self
        return mutated.withUTF8 {
            _allASCII($0)
        }
    }

    func _components(separatedBy separator: Substring, options: String.CompareOptions = []) throws -> [String] {
        var result = [String]()
        var searchStart = startIndex
        while searchStart < endIndex {
            let r = try self[searchStart...]._range(of: separator, options: options)
            guard let r, !r.isEmpty else {
                break
            }

            result.append(String(self[searchStart ..< r.lowerBound]))
            searchStart = r.upperBound
        }

        result.append(String(self[searchStart..<endIndex]))

        return result
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

    init<T: Comparable>(_ t1: T, _ t2: T) {
        if t1 < t2 {
            self = .orderedAscending
        } else if t1 > t2 {
            self = .orderedDescending
        } else {
            self = .orderedSame
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
