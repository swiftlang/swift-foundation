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

// MARK: AttributedStringKey API

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension AttributedString {
    public enum AttributeRunBoundaries : Hashable, Sendable {
        case paragraph

        // FIXME: This is semantically wrong. We do not ever want to constrain attributes on
        // characters (i.e., grapheme clusters) -- they are way too vague, and way
        // too eager to accidentally merge with neighboring string data. (And they're also way
        // too slow for this use case.)
        //
        // The entire point of this feature is to anchor attributes that describe attachments like
        // custom views that should be embedded in the text. We do not _ever_ want the anchor text
        // to accidentally compose with a subsequent combining character, losing the attachment.
        //
        // This needs to be deprecated and replaced by `case unicodeScalar(UnicodeScalar)`.
        //
        // The current implementation already works like that -- it ignores all but the first scalar
        // of the specified `Character`, and does not engage in normalization or grapheme breaking.
        case character(Character)
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension AttributedString.AttributeRunBoundaries {
    var _isScalarConstrained: Bool {
        if case .character = self { return true }
        return false
    }

    var _constrainedScalar: Unicode.Scalar? {
        switch self {
        case .character(let char): return char.unicodeScalars.first
        default: return nil
        }
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension AttributedString {
    public struct AttributeInvalidationCondition : Hashable, Sendable {
        private enum _Storage : Hashable {
            case textChanged
            case attributeChanged(String)
        }
        
        private let storage: _Storage
        
        private init(_ storage: _Storage) {
            self.storage = storage
        }

        var isAttribute: Bool {
            guard case .attributeChanged = storage else { return false }
            return true
        }

        var attributeKey: String? {
            switch storage {
            case .textChanged:
                return nil
            case .attributeChanged(let string):
                return string
            }
        }
        
        public static let textChanged = Self(.textChanged)

        public static func attributeChanged<T: AttributedStringKey>(_ key: T.Type) -> Self {
            Self(.attributeChanged(key.name))
        }

        public static func attributeChanged<T: AttributedStringKey>(_ key: KeyPath<AttributeDynamicLookup, T>) -> Self {
            Self(.attributeChanged(T.name))
        }
        
        static func attributeChanged(_ name: String) -> Self {
            Self(.attributeChanged(name))
        }
    }
}

// Developers define new attributes by implementing AttributeKey.
/// A type that defines an attribute's name and type.
///
/// You don't instantiate types that conform to this protocol. Rather, dynamic member lookup uses this type as the basis for looking up key paths on ``AttributedString`` subtypes when using an ``AttributeScope`` type parameter. When it also conforms to ``CodableAttributedStringKey``, (or ``DecodableAttributedStringKey``/``EncodableAttributedStringKey`` if the type isn't fully codable), the ``AttributedStringKey`` describes which attributes of an ``AttributedString`` support encoding or decoding.
///
/// Attribute owners — typically frameworks — declare a key like the following:
///
/// ```swift
/// enum OutlineColorAttribute : AttributedStringKey {
/// typealias Value = Color
/// static let name = "OutlineColor"
/// }
/// ```
///
///
/// Callers can use these types to get attribute values from attributed strings, but typically you want to reference them by name. Attribute owners enable this by creating one or more structures that conform to ``AttributeScope``, in which they provide short names for their attributes that map to the ``AttributedStringKey`` type. The following example shows how to do this:
///
/// ```swift
/// struct MyTextStyleAttributes : AttributeScope {
/// let outlineColor : OutlineColorAttribute // OutlineColorAttribute.Value == Color
/// let shadowColor : ShadowColorAttribute // ShadowColorAttribute.Value == Color
/// // etc.
/// }
/// ```
///
///
/// After you extend ``AttributeScope`` like this, extend ``AttributeDynamicLookup`` to allow callers to use dynamic member lookup syntax, like `myAttributedString.outlineColor = .red`.
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public protocol AttributedStringKey : SendableMetatype {
    /// The type of the key's value.
    associatedtype Value : Hashable
    /// The name of the key.
    static var name : String { get }
    
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    static var runBoundaries : AttributedString.AttributeRunBoundaries? { get }
    
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    static var inheritedByAddedText : Bool { get }
    
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    static var invalidationConditions : Set<AttributedString.AttributeInvalidationCondition>? { get }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedStringKey {
    public var description: String { Self.name }

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public static var runBoundaries : AttributedString.AttributeRunBoundaries? { nil }

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public static var inheritedByAddedText : Bool { true }

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public static var invalidationConditions : Set<AttributedString.AttributeInvalidationCondition>? { nil }
}

// MARK: Attribute Scopes

/// A type to support dynamic member lookup of attributes and containers.
///
/// This type allows attribute owners to add extensions that enable dynamic member lookup access to attributes. Supporting types — including ``AttributedString``, ``AttributedSubstring``, and ``AttributeContainer`` — gain dynamic lookup support by extending this type.
///
/// You can enable dynamic member lookup for your own ``AttributedStringKey`` attributes by defining them as implementations, collecting them into an ``AttributeScope`` and extending ``AttributeDynamicLookup``, like in the following example:
///
/// ```swift
/// public extension AttributeDynamicLookup {
/// subscript<T: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeScopes.MyFrameworkAttributes, T>) -> T {
/// return self[T.self]
/// }
/// }
/// ```
@dynamicMemberLookup @frozen
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public enum AttributeDynamicLookup {
    /// Returns an attributed string key that corresponds to a specified type.
    public subscript<T: AttributedStringKey>(_: T.Type) -> T {
        get { fatalError("Called outside of a dynamicMemberLookup subscript overload") }
    }
}

@available(macOS, unavailable, introduced: 12.0)
@available(iOS, unavailable, introduced: 15.0)
@available(tvOS, unavailable, introduced: 15.0)
@available(watchOS, unavailable, introduced: 8.0)
@available(*, unavailable)
extension AttributeDynamicLookup : Sendable {}

/// An attribute container that allows dynamic member lookup of its contents within the specified attribute scope.
///
/// Use a ``ScopedAttributeContainer`` when you need to disambiguate between attributes that exist in several attribute scopes that your app uses.
@dynamicMemberLookup
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public struct ScopedAttributeContainer<S: AttributeScope> : Sendable {
    internal var storage : AttributedString._AttributeStorage
    
    // Record the most recently deleted key for use in AttributedString mutation subscripts that use _modify
    // Note: if ScopedAttributeContainer ever adds a mutating function that can mutate multiple attributes, this will need to record multiple removed keys
    internal var removedKey : String?

    /// Returns the value of the attribute that the specified key path indicates.
    @preconcurrency
    public subscript<T: AttributedStringKey>(dynamicMember keyPath: KeyPath<S, T>) -> T.Value? where T.Value : Sendable {
        get { storage[T.self] }
        set {
            storage[T.self] = newValue
            if newValue == nil {
                removedKey = T.name
            }
        }
    }

    internal init(_ storage : AttributedString._AttributeStorage = .init()) {
        self.storage = storage
    }
    
#if FOUNDATION_FRAMEWORK
    // TODO: Support scope-specific equality/attributes in FoundationPreview
    internal func equals(_ other: Self) -> Bool {
        for (name, _) in S.attributeKeyTypes() {
            if self.storage[name] != other.storage[name] {
                return false
            }
        }
        return true
    }

    internal var attributes : AttributeContainer {
        var contents = AttributedString._AttributeStorage()
        for (name, _) in S.attributeKeyTypes() {
            contents[name] = self.storage[name]
        }
        return AttributeContainer(contents)
    }
    
#endif // FOUNDATION_FRAMEWORK
}


// MARK: Internals

#if FOUNDATION_FRAMEWORK

internal extension AttributedStringKey {
    static func _convertToObjectiveCValue(_ value: Value) throws -> AnyObject {
        if let convertibleType = Self.self as? any ObjectiveCConvertibleAttributedStringKey.Type {
            func project<K: ObjectiveCConvertibleAttributedStringKey>(_: K.Type) throws -> AnyObject {
                try K.objectiveCValue(for: value as! K.Value)
            }
            return try project(convertibleType)
        } else {
            return value as AnyObject
        }
    }
    
    static func _convertFromObjectiveCValue(_ value: AnyObject) throws -> Value {
        if let convertibleType = Self.self as? any ObjectiveCConvertibleAttributedStringKey.Type {
            func project<K: ObjectiveCConvertibleAttributedStringKey>(_: K.Type) throws -> Value {
                guard let objcValue = value as? K.ObjectiveCValue else {
                    throw CocoaError(.coderInvalidValue)
                }
                return try K.value(for: objcValue) as! Value
            }
            return try project(convertibleType)
        } else if let trueValue = value as? Value {
            return trueValue
        } else {
            throw CocoaError(.coderInvalidValue)
        }
    }
}
#endif // FOUNDATION_FRAMEWORK
