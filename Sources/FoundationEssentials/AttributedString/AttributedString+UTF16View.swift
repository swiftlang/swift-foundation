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
    public struct UTF16View: Sendable {
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

    public var utf16: UTF16View {
        UTF16View(_guts)
    }
}

@available(FoundationPreview 6.2, *)
extension AttributedSubstring {
    public var utf16: AttributedString.UTF16View {
        AttributedString.UTF16View(_guts, in: _range)
    }
}

@available(FoundationPreview 6.2, *)
extension AttributedString.UTF16View {
    var _utf16: BigSubstring.UTF16View {
        BigSubstring.UTF16View(_unchecked: _guts.string, in: _range)
    }
}

@available(FoundationPreview 6.2, *)
extension AttributedString.UTF16View: BidirectionalCollection {
    public typealias Element = UTF16.CodeUnit
    public typealias Index = AttributedString.Index
    public typealias Subsequence = Self

    public var startIndex: AttributedString.Index {
        .init(_range.lowerBound)
    }

    public var endIndex: AttributedString.Index {
        .init(_range.upperBound)
    }

    public var count: Int {
        _utf16.count
    }

    public func index(before i: AttributedString.Index) -> AttributedString.Index {
        precondition(i > startIndex && i <= endIndex, "AttributedString index out of bounds")
        let j = Index(_guts.string.utf16.index(before: i._value))
        precondition(j >= startIndex, "Can't advance AttributedString index before start index")
        return j
    }

    public func index(after i: AttributedString.Index) -> AttributedString.Index {
        precondition(i >= startIndex && i < endIndex, "AttributedString index out of bounds")
        let j = Index(_guts.string.utf16.index(after: i._value))
        precondition(j <= endIndex, "Can't advance AttributedString index after end index")
        return j
    }

    public func index(_ i: AttributedString.Index, offsetBy distance: Int) -> AttributedString.Index {
        precondition(i >= startIndex && i <= endIndex, "AttributedString index out of bounds")
        let j = Index(_guts.string.utf16.index(i._value, offsetBy: distance))
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
        guard let j = _guts.string.utf16.index(
            i._value, offsetBy: distance, limitedBy: limit._value
        ) else {
            return nil
        }
        precondition(j >= startIndex._value && j <= endIndex._value,
                     "AttributedString index out of bounds")
        return Index(j)
    }

    public func distance(
        from start: AttributedString.Index,
        to end: AttributedString.Index
    ) -> Int {
        precondition(start >= startIndex && start <= endIndex, "AttributedString index out of bounds")
        precondition(end >= startIndex && end <= endIndex, "AttributedString index out of bounds")
        return _guts.string.utf16.distance(from: start._value, to: end._value)
    }
    
    public subscript(index: AttributedString.Index) -> UTF16.CodeUnit {
        precondition(index >= startIndex && index < endIndex, "AttributedString index out of bounds")
        return _guts.string.utf16[index._value]
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
