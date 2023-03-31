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

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Runs {
    @dynamicMemberLookup
    public struct Run : Sendable {
        internal typealias _AttributeStorage = AttributedString._AttributeStorage
        internal typealias _InternalRun = AttributedString._InternalRun

        internal let _internal: _InternalRun
        internal let _range: Range<AttributedString.Index>
        internal let _guts: AttributedString.Guts
        
        internal init(
            _internal run: _InternalRun,
            _ range: Range<AttributedString.Index>,
            _ guts: AttributedString.Guts
        ) {
            self._internal = run
            self._range = range
            self._guts = guts
        }
        
        internal init(_ other: Self) {
            self._internal = other._internal
            self._range = other._range
            self._guts = other._guts
        }
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Runs.Run: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs._internal == rhs._internal
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Runs.Run: CustomStringConvertible {
    public var description: String {
        AttributedSubstring(_guts, range).description
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Runs.Run {
    public var range: Range<AttributedString.Index> { _range }

    internal var startIndex: AttributedString.Index { _range.lowerBound }

    internal var _attributes: _AttributeStorage {
        return _internal.attributes
    }
    
    internal func run(clampedTo range: Range<AttributedString.Index>) -> Self {
        var newInternal = _internal
        let newRange = _range.clamped(to: range)
        newInternal.length = _guts.utf8Distance(from: newRange.lowerBound, to: newRange.upperBound)
        return Self(_internal: newInternal, newRange, _guts)
    }

    public var attributes: AttributeContainer {
        AttributeContainer(self._attributes)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Runs.Run {
    @preconcurrency
    public subscript<K: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeDynamicLookup, K>) -> K.Value? where K.Value : Sendable {
        get { self[K.self] }
    }

    @preconcurrency
    public subscript<K : AttributedStringKey>(_: K.Type) -> K.Value? where K.Value : Sendable {
        get { _internal.attributes[K.self] }
    }

    public subscript<S: AttributeScope>(dynamicMember keyPath: KeyPath<AttributeScopes, S.Type>) -> ScopedAttributeContainer<S> {
        get { ScopedAttributeContainer(_internal.attributes) }
    }

    internal subscript<S: AttributeScope>(_ scope: S.Type) -> ScopedAttributeContainer<S> {
        get { ScopedAttributeContainer(_internal.attributes) }
    }
}
