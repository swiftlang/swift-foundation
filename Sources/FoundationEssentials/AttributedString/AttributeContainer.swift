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

/// A container for attribute keys and values.
///
/// ``AttributeContainer`` provides a way to store attributes and their values outside of an attributed string. You
/// use this type to initialize an instance of ``AttributedString`` with preset attributes, and to set, merge, or
/// replace attributes in existing attributed strings.
@dynamicMemberLookup
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public struct AttributeContainer : Sendable {
    internal var storage : AttributedString._AttributeStorage
    
    /// Creates an empty attribute container.
    public init() {
        storage = .init()
    }
    
    internal init(_ storage: AttributedString._AttributeStorage) {
        self.storage = storage
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributeContainer {
    /// Returns the attribute that corresponds to a specified key.
    @preconcurrency
    public subscript<T: AttributedStringKey>(_: T.Type) -> T.Value? where T.Value : Sendable {
        get { storage[T.self] }
        set { storage[T.self] = newValue }
    }

    /// Returns the attribute that corresponds to a specified key path.
    @preconcurrency
    @inlinable // Trivial implementation, allows callers to optimize away the keypath allocation
    public subscript<K: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeDynamicLookup, K>) -> K.Value? where K.Value : Sendable {
        get { self[K.self] }
        set { self[K.self] = newValue }
    }

    /// Returns the attribute container that corresponds to a specified key path.
    ///
    /// Use this subscript when you need to work with an explicit attribute scope. For example,
    /// the SwiftUI `foregroundColor` attribute overrides the attribute in the AppKit and UIKit
    /// scopes with the same name. If you work with both the SwiftUI and UIKit scopes, you can
    /// use the syntax `myAttributeContainer.uiKit.foregroundColor` to disambiguate and explicitly
    /// use the UIKit attribute.
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

    /// Returns a modified attribute container as part of building a chain of attributes, for use as a static method.
    ///
    /// This method returns an ``AttributeContainer/Builder``, which allows you to chain multiple
    /// attributes in a single call, like this:
    ///
    /// ```swift
    /// // An attribute container with the link and backgroundColor attributes.
    /// let myContainer = AttributeContainer.link(myURL).backgroundColor(.yellow)
    /// ```
    public static subscript<K: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeDynamicLookup, K>) -> Builder<K> {
        return Builder(container: AttributeContainer())
    }

    /// Returns a modified attribute container as part of building a chain of attributes.
    ///
    /// This method returns an ``AttributeContainer/Builder``, which allows you to chain multiple
    /// attributes in a single call, like this:
    ///
    /// ```swift
    /// // An attribute container with the link and backgroundColor attributes.
    /// let myContainer = AttributeContainer().link(myURL).backgroundColor(.yellow)
    /// ```
    @_disfavoredOverload
    public subscript<K: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeDynamicLookup, K>) -> Builder<K> {
        return Builder(container: self)
    }

    /// A type that iteratively builds attribute containers by setting attribute values.
    ///
    /// The ``AttributeContainer/Builder`` type lets you build ``AttributeContainer`` instances by chaining together
    /// several attributes in one expression. The following example shows this approach:
    ///
    /// ```swift
    /// // An attribute container with the link and backgroundColor attributes.
    /// let myContainer = AttributeContainer().link(myURL).backgroundColor(.yellow)
    /// ```
    ///
    /// The first part of this expression, `AttributeContainer().link(URL(myURL))`, creates a builder to apply
    /// the `link` attribute to the empty ``AttributeContainer``. The builder's ``Builder/callAsFunction(_:)``
    /// returns a new ``AttributeContainer`` with this attribute set. Then the `backgroundColor(.yellow)` creates
    /// a second builder to modify the just-returned ``AttributeContainer`` by adding the `backgroundColor`
    /// attribute. The result is an ``AttributeContainer`` with both attributes set.
    public struct Builder<T: AttributedStringKey> : Sendable {
        var container : AttributeContainer

        @preconcurrency
        public func callAsFunction(_ value: T.Value) -> AttributeContainer where T.Value : Sendable {
            var new = container
            new[T.self] = value
            return new
        }
    }

    /// Merges the container's attributes with those in another attribute container.
    ///
    /// - Parameters:
    ///   - other: The attribute container with the attributes to merge.
    ///   - mergePolicy: A policy to use when resolving conflicts between this string's attributes and those in `other`.
    public mutating func merge(_ other: AttributeContainer, mergePolicy: AttributedString.AttributeMergePolicy = .keepNew) {
        self.storage.mergeIn(other.storage, mergePolicy: mergePolicy)
    }

    /// Returns an attribute container by merging the container's attributes with those in another attribute container.
    ///
    /// - Parameters:
    ///   - other: The attribute container with the attributes to merge.
    ///   - mergePolicy: A policy to use when resolving conflicts between this string's attributes and those in `other`.
    /// - Returns: An attribute container created by merging the source container's attributes with those in another attribute container.
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

@available(FoundationPreview 6.2, *)
extension AttributeContainer {
    /// Returns a copy of the attribute container with only attributes that specify the provided inheritance behavior.
    /// - Parameter inheritedByAddedText: An `inheritedByAddedText` value to filter. Attributes matching this value are included in the returned container.
    /// - Returns: A copy of the attribute container with only attributes whose `inheritedByAddedText` property matches the provided value.
    public func filter(inheritedByAddedText: Bool) -> AttributeContainer {
        var storage = self.storage
        for (key, value) in storage.contents {
            let inherited = value.inheritedByAddedText && !value.isInvalidatedOnTextChange
            if inherited != inheritedByAddedText {
                storage[key] = nil
            }
        }
        return AttributeContainer(storage)
    }
    
    /// Returns a copy of the attribute container with only attributes that have the provided run boundaries.
    /// - Parameter runBoundaries: The required `runBoundaries` value of the filtered attributes. If `nil` is provided, only attributes not bound to any specific boundary will be returned.
    /// - Returns: A copy of the attribute container with only attributes whose `runBoundaries` property matches the provided value.
    public func filter(runBoundaries: AttributedString.AttributeRunBoundaries?) -> AttributeContainer {
        var storage = self.storage
        for (key, value) in storage.contents {
            if value.runBoundaries != runBoundaries {
                storage[key] = nil
            }
        }
        return AttributeContainer(storage)
    }
}
