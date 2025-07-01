//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020-2023 Apple Inc. and the Swift project authors
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

@available(FoundationAttributedString 5.5, *)
extension AttributedString {
    internal struct _InternalRun: Sendable {
        // UTF-8 Code Unit Length
        internal var length: Int
        internal var attributes: _AttributeStorage

        init(length: Int, attributes: _AttributeStorage) {
            self.length = length
            self.attributes = attributes
        }
    }
}

@available(FoundationAttributedString 5.5, *)
extension AttributedString._InternalRun: Equatable {
    internal static func == (left: Self, right: Self) -> Bool {
        left.length == right.length && left.attributes == right.attributes
    }
}

@available(FoundationAttributedString 5.5, *)
extension AttributedString._InternalRun: Hashable {
    internal func hash(into hasher: inout Hasher) {
        hasher.combine(length)
        hasher.combine(attributes)
    }
}

@available(FoundationAttributedString 5.5, *)
extension AttributedString._InternalRun: RopeElement {
    typealias Index = Int

    var summary: Summary { Summary(utf8Length: length) }
    var isEmpty: Bool { length == 0 }
    var isUndersized: Bool { false }

    func invariantCheck() {}

    mutating func rebalance(nextNeighbor right: inout Self) -> Bool {
        // We can never be undersized
        fatalError("Unimplemented")
    }

    mutating func rebalance(prevNeighbor left: inout Self) -> Bool {
        // We can never be undersized
        fatalError("Unimplemented")
    }

    mutating func split(at index: Self.Index) -> Self {
        precondition(index >= 0 && index <= length)
        let tail = Self(length: length - index, attributes: attributes)
        length = index
        return tail
    }
}

@available(FoundationAttributedString 5.5, *)
extension AttributedString._InternalRun {
    internal func get<T: AttributedStringKey>(_ k: T.Type) -> T.Value? where T.Value : Sendable {
        attributes[k]
    }
}

@available(FoundationAttributedString 5.5, *)
extension AttributedString._InternalRun {
    struct Summary: Sendable {
        var count: Int
        var utf8Length: Int

        init(utf8Length: Int) {
            self.count = 1
            self.utf8Length = utf8Length
        }

        init(count: Int, utf8Length: Int) {
            self.count = count
            self.utf8Length = utf8Length
        }
    }
}

@available(FoundationAttributedString 5.5, *)
extension AttributedString._InternalRun.Summary: RopeSummary {
    @inline(__always)
    static var maxNodeSize: Int { 15 }

    @inline(__always)
    static var nodeSizeBitWidth: Int { 4 }

    static var zero: Self { Self(count: 0, utf8Length: 0) }

    var isZero: Bool { count == 0 && utf8Length == 0 }

    mutating func add(_ other: Self) {
        count += other.count
        utf8Length += other.utf8Length
    }

    mutating func subtract(_ other: Self) {
        count -= other.count
        utf8Length -= other.utf8Length
    }
}
