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
@_implementationOnly @_spi(Unstable) import CollectionsInternal
#else
import _RopeModule
#endif

@dynamicMemberLookup
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public struct AttributeContainer : Sendable {
    internal var storage : AttributedString._AttributeStorage
    
    public init() {
        storage = .init()
    }
    
    internal init(_ storage: AttributedString._AttributeStorage) {
        self.storage = storage
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributeContainer {
    @preconcurrency
    public subscript<T: AttributedStringKey>(_: T.Type) -> T.Value? where T.Value : Sendable {
        get { storage[T.self] }
        set { storage[T.self] = newValue }
    }

    @preconcurrency
    public subscript<K: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeDynamicLookup, K>) -> K.Value? where K.Value : Sendable {
        get { self[K.self] }
        set { self[K.self] = newValue }
    }

    public subscript<S: AttributeScope>(dynamicMember keyPath: KeyPath<AttributeScopes, S.Type>) -> ScopedAttributeContainer<S> {
        get {
            return ScopedAttributeContainer(storage)
        }
        _modify {
            var container = ScopedAttributeContainer<S>()
            defer {
                if let removedKey = container.removedKey {
                    storage[removedKey] = nil
                } else {
                    storage.mergeIn(container.storage)
                }
            }
            yield &container
        }
    }

    public static subscript<K: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeDynamicLookup, K>) -> Builder<K> {
        return Builder(container: AttributeContainer())
    }

    @_disfavoredOverload
    public subscript<K: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeDynamicLookup, K>) -> Builder<K> {
        return Builder(container: self)
    }

    public struct Builder<T: AttributedStringKey> : Sendable {
        var container : AttributeContainer

        @preconcurrency
        public func callAsFunction(_ value: T.Value) -> AttributeContainer where T.Value : Sendable {
            var new = container
            new[T.self] = value
            return new
        }
    }

    public mutating func merge(_ other: AttributeContainer, mergePolicy: AttributedString.AttributeMergePolicy = .keepNew) {
        self.storage.mergeIn(other.storage, mergePolicy: mergePolicy)
    }

    public func merging(_ other: AttributeContainer, mergePolicy:  AttributedString.AttributeMergePolicy = .keepNew) -> AttributeContainer {
        var copy = self
        copy.merge(other, mergePolicy:  mergePolicy)
        return copy
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributeContainer: Equatable {}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension AttributeContainer: Hashable {}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributeContainer: CustomStringConvertible {
    public var description: String {
        storage.description
    }
}

extension AttributeContainer {
    internal var _hasConstrainedAttributes: Bool {
        storage.hasConstrainedAttributes
    }
}
