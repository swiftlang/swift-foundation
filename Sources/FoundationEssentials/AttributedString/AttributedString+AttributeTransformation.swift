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
package import _RopeModule
#endif

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString {
    @preconcurrency
    public struct SingleAttributeTransformer<T: AttributedStringKey> : Sendable where T.Value : Sendable {
        public var range: Range<Index>

        internal var attrName = T.name
        internal var attr : _AttributeValue?

        public var value: T.Value? {
            get { attr?.rawValue(as: T.self) }
            set { attr = .wrapIfPresent(newValue, for: T.self) }
        }

        @preconcurrency
        public mutating func replace<U: AttributedStringKey>(with key: U.Type, value: U.Value) where U.Value : Sendable {
            attrName = key.name
            attr = .init(value, for: U.self)
        }

        @preconcurrency
        public mutating func replace<U: AttributedStringKey>(with keyPath: KeyPath<AttributeDynamicLookup, U>, value: U.Value) where U.Value : Sendable {
            self.replace(with: U.self, value: value)
        }
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString {
    internal func applyRemovals<K>(
        withOriginal orig: AttributedString.SingleAttributeTransformer<K>,
        andChanged changed: AttributedString.SingleAttributeTransformer<K>,
        to attrStr: inout AttributedString,
        key: K.Type
    ) {
        if orig.range != changed.range || orig.attrName != changed.attrName {
            attrStr._guts.removeAttributeValue(forKey: K.self, in: orig.range._bstringRange) // If the range changed, we need to remove from the old range first.
        }
    }

    internal func applyChanges<K>(
        withOriginal orig: AttributedString.SingleAttributeTransformer<K>,
        andChanged changed: AttributedString.SingleAttributeTransformer<K>,
        to attrStr: inout AttributedString,
        key: K.Type
    ) {
        if orig.range != changed.range || orig.attrName != changed.attrName || orig.attr != changed.attr {
            if let newVal = changed.attr { // Then if there's a new value, we add it in.
                // Unfortunately, we can't use the attrStr[range].set() provided by the AttributedStringProtocol, because we *don't know* the new type statically!
                attrStr._guts.setAttributeValue(
                    newVal, forKey: changed.attrName, in: changed.range._bstringRange)
            } else {
                attrStr._guts.removeAttributeValue(forKey: K.self, in: changed.range._bstringRange) // ???: Is this right? Does changing the range of an attribute==nil run remove it from the new range?
            }
        }
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString {
    public func transformingAttributes<K>(
        _ k:  K.Type,
        _ c: (inout AttributedString.SingleAttributeTransformer<K>) -> Void
    ) -> AttributedString {
        let orig = AttributedString(_guts)
        var copy = orig
        copy.ensureUniqueReference() // ???: Is this best practice? We're going behind the back of the AttributedString mutation API surface, so it doesn't happen anywhere else. It's also aggressively speculative.
        for (attr, range) in orig.runs[k] {
            let origAttr1 = AttributedString.SingleAttributeTransformer<K>(range: range, attr: .wrapIfPresent(attr, for: K.self))
            var changedAttr1 = origAttr1
            c(&changedAttr1)
            applyRemovals(withOriginal: origAttr1, andChanged: changedAttr1, to: &copy, key: k)
            applyChanges(withOriginal: origAttr1, andChanged: changedAttr1, to: &copy, key: k)
        }
        return copy
    }

    public func transformingAttributes<K1, K2>(
        _ k:  K1.Type,
        _ k2: K2.Type,
        _ c: (inout AttributedString.SingleAttributeTransformer<K1>,
              inout AttributedString.SingleAttributeTransformer<K2>) -> Void
    ) -> AttributedString {
        let orig = AttributedString(_guts)
        var copy = orig
        copy.ensureUniqueReference() // ???: Is this best practice? We're going behind the back of the AttributedString mutation API surface, so it doesn't happen anywhere else. It's also aggressively speculative.
        for (attr, attr2, range) in orig.runs[k, k2] {
            let origAttr1 = AttributedString.SingleAttributeTransformer<K1>(range: range, attr: .wrapIfPresent(attr, for: K1.self))
            let origAttr2 = AttributedString.SingleAttributeTransformer<K2>(range: range, attr: .wrapIfPresent(attr2, for: K2.self))
            var changedAttr1 = origAttr1
            var changedAttr2 = origAttr2
            c(&changedAttr1, &changedAttr2)
            applyRemovals(withOriginal: origAttr1, andChanged: changedAttr1, to: &copy, key: k)
            applyRemovals(withOriginal: origAttr2, andChanged: changedAttr2, to: &copy, key: k2)
            applyChanges(withOriginal: origAttr1, andChanged: changedAttr1, to: &copy, key: k)
            applyChanges(withOriginal: origAttr2, andChanged: changedAttr2, to: &copy, key: k2)
        }
        return copy
    }

    public func transformingAttributes<K1, K2, K3>(
        _ k:  K1.Type,
        _ k2: K2.Type,
        _ k3: K3.Type,
        _ c: (inout AttributedString.SingleAttributeTransformer<K1>,
              inout AttributedString.SingleAttributeTransformer<K2>,
              inout AttributedString.SingleAttributeTransformer<K3>) -> Void
    ) -> AttributedString {
        let orig = AttributedString(_guts)
        var copy = orig
        copy.ensureUniqueReference() // ???: Is this best practice? We're going behind the back of the AttributedString mutation API surface, so it doesn't happen anywhere else. It's also aggressively speculative.
        for (attr, attr2, attr3, range) in orig.runs[k, k2, k3] {
            let origAttr1 = AttributedString.SingleAttributeTransformer<K1>(range: range, attr: .wrapIfPresent(attr, for: K1.self))
            let origAttr2 = AttributedString.SingleAttributeTransformer<K2>(range: range, attr: .wrapIfPresent(attr2, for: K2.self))
            let origAttr3 = AttributedString.SingleAttributeTransformer<K3>(range: range, attr: .wrapIfPresent(attr3, for: K3.self))
            var changedAttr1 = origAttr1
            var changedAttr2 = origAttr2
            var changedAttr3 = origAttr3
            c(&changedAttr1, &changedAttr2, &changedAttr3)
            applyRemovals(withOriginal: origAttr1, andChanged: changedAttr1, to: &copy, key: k)
            applyRemovals(withOriginal: origAttr2, andChanged: changedAttr2, to: &copy, key: k2)
            applyRemovals(withOriginal: origAttr3, andChanged: changedAttr3, to: &copy, key: k3)
            applyChanges(withOriginal: origAttr1, andChanged: changedAttr1, to: &copy, key: k)
            applyChanges(withOriginal: origAttr2, andChanged: changedAttr2, to: &copy, key: k2)
            applyChanges(withOriginal: origAttr3, andChanged: changedAttr3, to: &copy, key: k3)
        }
        return copy
    }

    public func transformingAttributes<K1, K2, K3, K4>(
        _ k:  K1.Type,
        _ k2: K2.Type,
        _ k3: K3.Type,
        _ k4: K4.Type,
        _ c: (inout AttributedString.SingleAttributeTransformer<K1>,
              inout AttributedString.SingleAttributeTransformer<K2>,
              inout AttributedString.SingleAttributeTransformer<K3>,
              inout AttributedString.SingleAttributeTransformer<K4>) -> Void
    ) -> AttributedString {
        let orig = AttributedString(_guts)
        var copy = orig
        copy.ensureUniqueReference() // ???: Is this best practice? We're going behind the back of the AttributedString mutation API surface, so it doesn't happen anywhere else. It's also aggressively speculative.
        for (attr, attr2, attr3, attr4, range) in orig.runs[k, k2, k3, k4] {
            let origAttr1 = AttributedString.SingleAttributeTransformer<K1>(range: range, attr: .wrapIfPresent(attr, for: K1.self))
            let origAttr2 = AttributedString.SingleAttributeTransformer<K2>(range: range, attr: .wrapIfPresent(attr2, for: K2.self))
            let origAttr3 = AttributedString.SingleAttributeTransformer<K3>(range: range, attr: .wrapIfPresent(attr3, for: K3.self))
            let origAttr4 = AttributedString.SingleAttributeTransformer<K4>(range: range, attr: .wrapIfPresent(attr4, for: K4.self))
            var changedAttr1 = origAttr1
            var changedAttr2 = origAttr2
            var changedAttr3 = origAttr3
            var changedAttr4 = origAttr4
            c(&changedAttr1, &changedAttr2, &changedAttr3, &changedAttr4)
            applyRemovals(withOriginal: origAttr1, andChanged: changedAttr1, to: &copy, key: k)
            applyRemovals(withOriginal: origAttr2, andChanged: changedAttr2, to: &copy, key: k2)
            applyRemovals(withOriginal: origAttr3, andChanged: changedAttr3, to: &copy, key: k3)
            applyRemovals(withOriginal: origAttr4, andChanged: changedAttr4, to: &copy, key: k4)
            applyChanges(withOriginal: origAttr1, andChanged: changedAttr1, to: &copy, key: k)
            applyChanges(withOriginal: origAttr2, andChanged: changedAttr2, to: &copy, key: k2)
            applyChanges(withOriginal: origAttr3, andChanged: changedAttr3, to: &copy, key: k3)
            applyChanges(withOriginal: origAttr4, andChanged: changedAttr4, to: &copy, key: k4)
        }
        return copy
    }

    public func transformingAttributes<K1, K2, K3, K4, K5>(
        _ k:  K1.Type,
        _ k2: K2.Type,
        _ k3: K3.Type,
        _ k4: K4.Type,
        _ k5: K5.Type,
        _ c: (inout AttributedString.SingleAttributeTransformer<K1>,
              inout AttributedString.SingleAttributeTransformer<K2>,
              inout AttributedString.SingleAttributeTransformer<K3>,
              inout AttributedString.SingleAttributeTransformer<K4>,
              inout AttributedString.SingleAttributeTransformer<K5>) -> Void
    ) -> AttributedString {
        let orig = AttributedString(_guts)
        var copy = orig
        copy.ensureUniqueReference() // ???: Is this best practice? We're going behind the back of the AttributedString mutation API surface, so it doesn't happen anywhere else. It's also aggressively speculative.
        for (attr, attr2, attr3, attr4, attr5, range) in orig.runs[k, k2, k3, k4, k5] {
            let origAttr1 = AttributedString.SingleAttributeTransformer<K1>(range: range, attr: .wrapIfPresent(attr, for: K1.self))
            let origAttr2 = AttributedString.SingleAttributeTransformer<K2>(range: range, attr: .wrapIfPresent(attr2, for: K2.self))
            let origAttr3 = AttributedString.SingleAttributeTransformer<K3>(range: range, attr: .wrapIfPresent(attr3, for: K3.self))
            let origAttr4 = AttributedString.SingleAttributeTransformer<K4>(range: range, attr: .wrapIfPresent(attr4, for: K4.self))
            let origAttr5 = AttributedString.SingleAttributeTransformer<K5>(range: range, attr: .wrapIfPresent(attr5, for: K5.self))
            var changedAttr1 = origAttr1
            var changedAttr2 = origAttr2
            var changedAttr3 = origAttr3
            var changedAttr4 = origAttr4
            var changedAttr5 = origAttr5
            c(&changedAttr1, &changedAttr2, &changedAttr3, &changedAttr4, &changedAttr5)
            applyRemovals(withOriginal: origAttr1, andChanged: changedAttr1, to: &copy, key: k)
            applyRemovals(withOriginal: origAttr2, andChanged: changedAttr2, to: &copy, key: k2)
            applyRemovals(withOriginal: origAttr3, andChanged: changedAttr3, to: &copy, key: k3)
            applyRemovals(withOriginal: origAttr4, andChanged: changedAttr4, to: &copy, key: k4)
            applyRemovals(withOriginal: origAttr5, andChanged: changedAttr5, to: &copy, key: k5)
            applyChanges(withOriginal: origAttr1, andChanged: changedAttr1, to: &copy, key: k)
            applyChanges(withOriginal: origAttr2, andChanged: changedAttr2, to: &copy, key: k2)
            applyChanges(withOriginal: origAttr3, andChanged: changedAttr3, to: &copy, key: k3)
            applyChanges(withOriginal: origAttr4, andChanged: changedAttr4, to: &copy, key: k4)
            applyChanges(withOriginal: origAttr5, andChanged: changedAttr5, to: &copy, key: k5)
        }
        return copy
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString {
    public func transformingAttributes<K>(
        _ k: KeyPath<AttributeDynamicLookup, K>,
        _ c: (inout AttributedString.SingleAttributeTransformer<K>) -> Void
    ) -> AttributedString {
        self.transformingAttributes(K.self, c)
    }

    public func transformingAttributes<K1, K2>(
        _ k:  KeyPath<AttributeDynamicLookup, K1>,
        _ k2: KeyPath<AttributeDynamicLookup, K2>,
        _ c: (inout AttributedString.SingleAttributeTransformer<K1>,
              inout AttributedString.SingleAttributeTransformer<K2>) -> Void
    ) -> AttributedString {
        self.transformingAttributes(K1.self, K2.self, c)
    }

    public func transformingAttributes<K1, K2, K3>(
        _ k:  KeyPath<AttributeDynamicLookup, K1>,
        _ k2: KeyPath<AttributeDynamicLookup, K2>,
        _ k3: KeyPath<AttributeDynamicLookup, K3>,
        _ c: (inout AttributedString.SingleAttributeTransformer<K1>,
              inout AttributedString.SingleAttributeTransformer<K2>,
              inout AttributedString.SingleAttributeTransformer<K3>) -> Void
    ) -> AttributedString {
        self.transformingAttributes(K1.self, K2.self, K3.self, c)
    }

    public func transformingAttributes<K1, K2, K3, K4>(
        _ k:  KeyPath<AttributeDynamicLookup, K1>,
        _ k2: KeyPath<AttributeDynamicLookup, K2>,
        _ k3: KeyPath<AttributeDynamicLookup, K3>,
        _ k4: KeyPath<AttributeDynamicLookup, K4>,
        _ c: (inout AttributedString.SingleAttributeTransformer<K1>,
              inout AttributedString.SingleAttributeTransformer<K2>,
              inout AttributedString.SingleAttributeTransformer<K3>,
              inout AttributedString.SingleAttributeTransformer<K4>) -> Void
    ) -> AttributedString {
        self.transformingAttributes(K1.self, K2.self, K3.self, K4.self, c)
    }

    public func transformingAttributes<K1, K2, K3, K4, K5>(
        _ k:  KeyPath<AttributeDynamicLookup, K1>,
        _ k2: KeyPath<AttributeDynamicLookup, K2>,
        _ k3: KeyPath<AttributeDynamicLookup, K3>,
        _ k4: KeyPath<AttributeDynamicLookup, K4>,
        _ k5: KeyPath<AttributeDynamicLookup, K5>,
        _ c: (inout AttributedString.SingleAttributeTransformer<K1>,
              inout AttributedString.SingleAttributeTransformer<K2>,
              inout AttributedString.SingleAttributeTransformer<K3>,
              inout AttributedString.SingleAttributeTransformer<K4>,
              inout AttributedString.SingleAttributeTransformer<K5>) -> Void
    ) -> AttributedString {
        self.transformingAttributes(K1.self, K2.self, K3.self, K4.self, K5.self, c)
    }
}
