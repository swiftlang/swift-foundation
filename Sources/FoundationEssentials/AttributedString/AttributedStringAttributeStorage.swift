//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

@available(FoundationAttributedString 5.5, *)
extension AttributedString {
    internal struct _AttributeValue : Hashable, CustomStringConvertible, Sendable {
        private typealias RawValue = any Sendable & Hashable
        private let _rawValue: RawValue

        // FIXME: If these are always tied to keys, then why are we caching these
        // FIXME: on each individual value? Move them to a separate
        // FIXME: dictionary inside each attributed string -- or even a
        // FIXME: global one.
        let runBoundaries: AttributeRunBoundaries?
        let inheritedByAddedText: Bool
        let invalidationConditions: Set<AttributeInvalidationCondition>?
        
        var description: String { String(describing: _rawValue) }
        
        init<K: AttributedStringKey>(_ value: K.Value, for key: K.Type) where K.Value : Sendable {
            _rawValue = value
            runBoundaries = K.runBoundaries
            inheritedByAddedText = K.inheritedByAddedText
            invalidationConditions = K.invalidationConditions
        }
        
        #if FOUNDATION_FRAMEWORK
        @inline(__always)
        private static func _unsafeAssumeSendableRawValue<T>(_ value: T) -> RawValue {
            // Perform this cast in a separate function unaware of the T: Hashable constraint to avoid compiler warnings when performing the Hashable --> Hashable & Sendable cast
            value as! RawValue
        }
        
        fileprivate init<K: AttributedStringKey>(assumingSendable value: K.Value, for key: K.Type) {
            _rawValue = Self._unsafeAssumeSendableRawValue(value)
            runBoundaries = K.runBoundaries
            inheritedByAddedText = K.inheritedByAddedText
            invalidationConditions = K.invalidationConditions
        }
        #endif

        var isInvalidatedOnTextChange: Bool {
            invalidationConditions?.contains(.textChanged) ?? false
        }

        var isInvalidatedOnAttributeChange: Bool {
            invalidationConditions?.contains { $0.isAttribute } ?? false
        }

        func isInvalidatedOnChange(of attributeKey: String) -> Bool {
            let condition: AttributeInvalidationCondition = .attributeChanged(attributeKey)
            return invalidationConditions?.contains { $0 == condition } ?? false
        }

        static func wrapIfPresent<K: AttributedStringKey>(_ value: K.Value?, for key: K.Type) -> Self? where K.Value : Sendable {
            guard let value = value else { return nil }
            return Self(value, for: K.self)
        }
        
        func rawValue<K: AttributedStringKey>(
            as key: K.Type
        ) -> K.Value where K.Value: Sendable {
            // Dynamic cast instead of an identity cast to support bridging between attribute value types like NSColor/UIColor
            guard let value = self._rawValue as? K.Value else {
                preconditionFailure("Unable to read \(K.self) attribute: stored value of type \(type(of: self._rawValue)) is not key's value type (\(K.Value.self))")
            }
            return value
        }
        
        #if FOUNDATION_FRAMEWORK
        fileprivate func rawValueAssumingSendable<K: AttributedStringKey>(
            as key: K.Type
        ) -> K.Value {
            // Dynamic cast instead of an identity cast to support bridging between attribute value types like NSColor/UIColor
            guard let value = self._rawValue as? K.Value else {
                preconditionFailure("Unable to read \(K.self) attribute: stored value of type \(type(of: self._rawValue)) is not key's value type (\(K.Value.self))")
            }
            return value
        }
        #endif
        
        static func ==(left: Self, right: Self) -> Bool {
            func openEquatableLHS<LeftValue: Hashable & Sendable>(_ leftValue: LeftValue) -> Bool {
                func openEquatableRHS<RightValue: Hashable & Sendable>(_ rightValue: RightValue) -> Bool {
                    // Dynamic cast instead of an identity cast to support bridging between attribute value types like NSColor/UIColor
                    guard let rightValueAsLeft = rightValue as? LeftValue else {
                        return false
                    }
                    return rightValueAsLeft == leftValue
                }
                return openEquatableRHS(right._rawValue)
            }
            return openEquatableLHS(left._rawValue)
        }
        
        func hash(into hasher: inout Hasher) {
            _rawValue.hash(into: &hasher)
        }
    }
}

@available(FoundationAttributedString 5.5, *)
internal extension Dictionary where Key == String, Value == AttributedString._AttributeValue {
    var _attrStrDescription : String {
        let keyvals = self.reduce(into: "") { (res, entry) in
            res += "\t\(entry.key) = \(entry.value)\n"
        }
        return "{\n\(keyvals)}"
    }
}

@available(FoundationAttributedString 5.5, *)
extension AttributedString {
    internal struct _AttributeStorage: Hashable, Sendable {
        internal typealias AttributeMergePolicy = AttributedString.AttributeMergePolicy
        internal typealias _AttributeValue = AttributedString._AttributeValue

        private(set) var contents : [String : _AttributeValue]

        /// The set of keys in this container that need to invalidated
        /// when some particular key changes.
        ///
        /// FIXME: We do not need to cache this. Remove it.
        private var invalidatableKeys : Set<String>
        
        init() {
            self.contents = [:]
            self.invalidatableKeys = []
        }
    }
}

@available(FoundationAttributedString 5.5, *)
extension AttributedString._AttributeStorage: CustomStringConvertible {
    var description: String {
        contents._attrStrDescription
    }
}

@available(FoundationAttributedString 5.5, *)
extension AttributedString._AttributeStorage {
    var isEmpty: Bool {
        contents.isEmpty
    }
    
    var keys: Dictionary<String, _AttributeValue>.Keys {
        contents.keys
    }

    func matches(_ other: Self) -> Bool {
        for (key, value) in other.contents {
            if self[key] != value {
                return false
            }
        }
        return true
    }
}

@available(FoundationAttributedString 5.5, *)
extension AttributedString._AttributeStorage {
    internal func isEqual(to other: Self, comparing attributes: [String]) -> Bool {
        assert(!attributes.isEmpty)
        for name in attributes {
            if self[name] != other[name] {
                return false
            }
        }
        return true
    }
}

@available(FoundationAttributedString 5.5, *)
extension AttributedString._AttributeStorage {
    func attributesForAddedText() -> Self {
        var storage = Self()
        storage.contents = contents.filter {
            $0.value.inheritedByAddedText && !$0.value.isInvalidatedOnTextChange
        }
        // FIXME: Why not set `invalidatableKeys` here?
        return storage
    }

    private mutating func _attributeModified(_ key: String, old: _AttributeValue?, new: _AttributeValue?) {
        guard old != nil || new != nil else { return } // Shortcut for nil -> nil modification

        // Update invalidatableKeys list
        if new?.isInvalidatedOnAttributeChange ?? false {
            invalidatableKeys.insert(key)
        } else {
            invalidatableKeys.remove(key)
        }

        // Lazy to ensure we only check if the value changed when we actually need to because we found a dependent attribute
        // Unboxing the attribute value to call its == implementation can be expensive, so for text that doesn't contain dependent attributes avoid it when possible
        lazy var valueChanged = { old != new }()

        for k in invalidatableKeys {
            guard k != key else { continue }
            guard let value = contents[k] else { continue }
            guard value.isInvalidatedOnChange(of: key) else { continue }
            guard valueChanged else { return }
            // FIXME: ☠️ This subscript assignment is recursively calling this same method.
            // FIXME: Collect invalidated keys into a temporary set instead, and progressively
            // FIXME: extend that set until all its keys are gone.
            self[k] = nil
        }
    }

    subscript <T: AttributedStringKey>(_ attribute: T.Type) -> T.Value? where T.Value : Sendable {
        get { self[T.name]?.rawValue(as: T.self) }
        set { self[T.name] = .wrapIfPresent(newValue, for: T.self) }
    }
    
    #if FOUNDATION_FRAMEWORK
    /// Stores & retrieves an attribute value bypassing the T.Value : Sendable constraint
    ///
    /// In general, callers should _always_ use the subscript that contains a T.Value : Sendable constraint
    /// This subscript should only be used in contexts when callers are forced to work around the lack of an AttributedStringKey.Value : Sendable constraint and assume the values are Sendable (ex. during NSAttributedString conversion while iterating scopes)
    subscript <T: AttributedStringKey>(assumingSendable attribute: T.Type) -> T.Value? {
        get {
            self[T.name]?.rawValueAssumingSendable(as: T.self)
        }
        set {
            guard let newValue else {
                self[T.name] = nil
                return
            }
            self[T.name] = _AttributeValue(assumingSendable: newValue, for: T.self)
        }
    }
    #endif

    subscript (_ attributeName: String) -> _AttributeValue? {
        get { self.contents[attributeName] }
        set {
            let oldValue: _AttributeValue?
            if let newValue {
                oldValue = self.contents.updateValue(newValue, forKey: attributeName)
            } else {
                oldValue = self.contents.removeValue(forKey: attributeName)
            }
            _attributeModified(attributeName, old: oldValue, new: newValue)
        }
    }
    
    mutating func removeValue<T: AttributedStringKey>(forKey: T.Type) -> Bool {
        let oldValue = self.contents.removeValue(forKey: T.name)
        _attributeModified(T.name, old: oldValue, new: nil)
        return oldValue != nil
    }

    internal mutating func mergeIn(_ other: Self, mergePolicy: AttributeMergePolicy = .keepNew) {
        for (key, value) in other.contents {
            switch mergePolicy {
            case .keepNew:
                self[key] = value
            case .keepCurrent:
                if !contents.keys.contains(key) {
                    self[key] = value
                }
            }
        }
    }

    internal mutating func mergeIn(_ other: AttributeContainer, mergePolicy: AttributeMergePolicy = .keepNew) {
        self.mergeIn(other.storage, mergePolicy: mergePolicy)
    }

    /// Note: This is intentionally not doing recursive removal of attributes that have a
    /// `attributeChanged` constrained on one of the filtered out keys.
    func filterWithoutInvalidatingDependents(
        _ isIncluded: (Dictionary<String, _AttributeValue>.Element) -> Bool
    ) -> Self {
        var storage = Self()
        storage.contents = self.contents.filter(isIncluded)
        storage.invalidatableKeys = self.invalidatableKeys
        return storage
    }

    func contains(_ attributeName: String) -> Bool {
        contents.keys.contains(attributeName)
    }

    func contains<K: AttributedStringKey>(_ key: K.Type) -> Bool {
        contains(K.name)
    }
}
