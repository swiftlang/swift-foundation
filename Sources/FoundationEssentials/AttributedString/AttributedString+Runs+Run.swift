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
#else
internal import _RopeModule
#endif

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Runs {
    @dynamicMemberLookup
    public struct Run: Sendable {
        internal typealias _AttributeStorage = AttributedString._AttributeStorage

        internal let _attributes: _AttributeStorage
        internal let _range: Range<BigString.Index>

        // FIXME: Remove this and update description to only print attribute values
        internal let _guts: AttributedString.Guts
        
        internal init(
            _attributes attributes: _AttributeStorage,
            _ range: Range<BigString.Index>,
            _ guts: AttributedString.Guts
        ) {
            self._attributes = attributes
            self._range = range
            self._guts = guts
        }
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Runs.Run: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs._range._utf8OffsetRange.count == rhs._range._utf8OffsetRange.count
        && lhs._attributes == rhs._attributes
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Runs.Run: CustomStringConvertible {
    public var description: String {
        AttributedSubstring(_guts, in: _range).description
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Runs.Run {
    public var range: Range<AttributedString.Index> {
        let lower = AttributedString.Index(_range.lowerBound)
        let upper = AttributedString.Index(_range.upperBound)
        return Range(uncheckedBounds: (lower, upper))
    }

    internal var _utf8Count: Int {
        _range._utf8OffsetRange.count
    }

    internal func clamped(to range: Range<BigString.Index>) -> Self {
        Self(_attributes: self._attributes, _range.clamped(to: range), _guts)
    }

    public var attributes: AttributeContainer {
        AttributeContainer(self._attributes)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Runs.Run {
    @preconcurrency
    public subscript<K: AttributedStringKey>(
        dynamicMember keyPath: KeyPath<AttributeDynamicLookup, K>
    ) -> K.Value?
    where K.Value: Sendable {
        get { self[K.self] }
    }

    @preconcurrency
    public subscript<K: AttributedStringKey>(_: K.Type) -> K.Value? where K.Value: Sendable {
        get { _attributes[K.self] }
    }

    public subscript<S: AttributeScope>(
        dynamicMember keyPath: KeyPath<AttributeScopes, S.Type>
    ) -> ScopedAttributeContainer<S> {
        get { ScopedAttributeContainer(_attributes) }
    }

    internal subscript<S: AttributeScope>(_ scope: S.Type) -> ScopedAttributeContainer<S> {
        get { ScopedAttributeContainer(_attributes) }
    }
}
