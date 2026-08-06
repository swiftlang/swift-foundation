//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK
@_spi(Unstable) internal import CollectionsInternal
#elseif canImport(_RopeModule)
internal import _RopeModule
#elseif canImport(_FoundationCollections)
internal import _FoundationCollections
#endif

@available(FoundationPreview 6.2, *)
extension AttributedString {
    /// A view of an attributed string’s contents as a collection of UTF-8 code units.
    public struct UTF8View: Sendable {
        internal var _guts: Guts
        internal var _range: Range<BigString.Index>
        internal var _identity: Int = 0

        internal init(_ guts: AttributedString.Guts) {
            self.init(guts, in: guts.stringBounds)
        }

        internal init(_ guts: Guts, in range: Range<BigString.Index>) {
            _guts = guts
            _range = range
        }
    }
    
    /// A view of the attributed string’s contents as a collection of UTF-8 code units.
    public var utf8: UTF8View {
        UTF8View(_guts)
    }
}

@available(FoundationPreview 6.2, *)
extension AttributedSubstring {
    /// A view of the attributed substring's contents as a collection of UTF-8 code units.
    public var utf8: AttributedString.UTF8View {
        AttributedString.UTF8View(_guts, in: _range)
    }
}

@available(FoundationPreview 6.2, *)
extension AttributedString.UTF8View {
    var _utf8: BigSubstring.UTF8View {
        BigSubstring.UTF8View(_unchecked: _guts.string, in: _range)
    }
}

@available(FoundationPreview 6.2, *)
extension AttributedString.UTF8View: BidirectionalCollection {
    public typealias Element = UTF8.CodeUnit
    public typealias Index = AttributedString.Index
    public typealias Subsequence = Self

    public var startIndex: AttributedString.Index {
        .init(_range.lowerBound, version: _guts.version)
    }

    public var endIndex: AttributedString.Index {
        .init(_range.upperBound, version: _guts.version)
    }

    public var count: Int {
        _utf8.count
    }

    public func index(before i: AttributedString.Index) -> AttributedString.Index {
        precondition(i > startIndex && i <= endIndex, "AttributedString index out of bounds")
        let j = Index(_guts.string.utf8.index(before: i._value), version: _guts.version)
        precondition(j >= startIndex, "Can't advance AttributedString index before start index")
        return j
    }

    public func index(after i: AttributedString.Index) -> AttributedString.Index {
        precondition(i >= startIndex && i < endIndex, "AttributedString index out of bounds")
        let j = Index(_guts.string.utf8.index(after: i._value), version: _guts.version)
        precondition(j <= endIndex, "Can't advance AttributedString index after end index")
        return j
    }

    public func index(_ i: AttributedString.Index, offsetBy distance: Int) -> AttributedString.Index {
        precondition(i >= startIndex && i <= endIndex, "AttributedString index out of bounds")
        let j = Index(_guts.string.utf8.index(i._value, offsetBy: distance), version: _guts.version)
        precondition(j >= startIndex && j <= endIndex, "AttributedString index out of bounds")
        return j
    }

    public func index(
        _ i: AttributedString.Index,
        offsetBy distance: Int,
        limitedBy limit: AttributedString.Index
    ) -> AttributedString.Index? {
        precondition(i >= startIndex && i <= endIndex, "AttributedString index out of bounds")
        precondition(limit >= startIndex && limit <= endIndex, "AttributedString index out of bounds")
        guard let j = _guts.string.utf8.index(
            i._value, offsetBy: distance, limitedBy: limit._value
        ) else {
            return nil
        }
        precondition(j >= startIndex._value && j <= endIndex._value,
                     "AttributedString index out of bounds")
        return Index(j, version: _guts.version)
    }

    public func distance(
        from start: AttributedString.Index,
        to end: AttributedString.Index
    ) -> Int {
        precondition(start >= startIndex && start <= endIndex, "AttributedString index out of bounds")
        precondition(end >= startIndex && end <= endIndex, "AttributedString index out of bounds")
        return _guts.string.utf8.distance(from: start._value, to: end._value)
    }
    
    public subscript(index: AttributedString.Index) -> UTF8.CodeUnit {
        precondition(index >= startIndex && index < endIndex, "AttributedString index out of bounds")
        return _guts.string.utf8[index._value]
    }
    
    public subscript(bounds: Range<AttributedString.Index>) -> Self {
        let bounds = bounds._bstringRange
        precondition(
            bounds.lowerBound >= _range.lowerBound && bounds.lowerBound <= _range.upperBound &&
            bounds.upperBound >= _range.lowerBound && bounds.upperBound <= _range.upperBound,
            "AttributedString index range out of bounds")
        return Self(_guts, in: bounds)
    }
}
