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

@_spi(Reflection) import Swift

// MARK: AttributedStringKey API

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension AttributedString {
    public enum AttributeRunBoundaries : Hashable, Sendable {
        case paragraph
        case character(Character)
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension AttributedString.AttributeRunBoundaries {
    var _isCharacter: Bool {
        if case .character = self { return true }
        return false
    }

    var _constrainedCharacter: Character? {
        switch self {
        case .character(let char): return char
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
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public protocol AttributedStringKey {
    associatedtype Value : Hashable
    static var name : String { get }
    
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    static var runBoundaries : AttributedString.AttributeRunBoundaries? { get }
    
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    static var inheritedByAddedText : Bool { get }
    
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    static var invalidationConditions : Set<AttributedString.AttributeInvalidationCondition>? { get }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public extension AttributedStringKey {
    var description: String { Self.name }
    
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    static var runBoundaries : AttributedString.AttributeRunBoundaries? { nil }
    
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    static var inheritedByAddedText : Bool { true }
    
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    static var invalidationConditions : Set<AttributedString.AttributeInvalidationCondition>? { nil }
}

extension AttributedStringKey {
    // FIXME: ☠️ Allocating an Array here is not a good idea.
    static var _constraintsInvolved: [AttributedString.AttributeRunBoundaries] {
        guard let rb = runBoundaries else { return [] }
        return [rb]
    }
}

// MARK: Attribute Scopes

// Developers can also add the attributes to pre-defined scopes of attributes, which are used to provide type information to the encoding and decoding of AttributedString values, as well as allow for dynamic member lookup in Runss of AttributedStrings.
// Example, where ForegroundColor is an existing AttributedStringKey:
// struct MyAttributes : AttributeScope {
//     var foregroundColor : ForegroundColor
// }
// An AttributeScope can contain other scopes as well.
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public protocol AttributeScope : DecodingConfigurationProviding, EncodingConfigurationProviding {
    static var decodingConfiguration: AttributeScopeCodableConfiguration { get }
    static var encodingConfiguration: AttributeScopeCodableConfiguration { get }
}

@_nonSendable
@frozen
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public enum AttributeScopes { }

@_nonSendable
@dynamicMemberLookup @frozen
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public enum AttributeDynamicLookup {
    public subscript<T: AttributedStringKey>(_: T.Type) -> T {
        get { fatalError("Called outside of a dynamicMemberLookup subscript overload") }
    }
}

@_nonSendable
@dynamicMemberLookup
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public struct ScopedAttributeContainer<S: AttributeScope> {
    internal var storage : AttributedString._AttributeStorage
    
    // Record the most recently deleted key for use in AttributedString mutation subscripts that use _modify
    // Note: if ScopedAttributeContainer ever adds a mutating function that can mutate multiple attributes, this will need to record multiple removed keys
    internal var removedKey : String?

    public subscript<T: AttributedStringKey>(dynamicMember keyPath: KeyPath<S, T>) -> T.Value? {
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

    internal func equals(_ other: Self) -> Bool {
        var equal = true
        _forEachField(of: S.self, options: [.ignoreUnknown]) { name, offset, type, kind -> Bool in
            switch type {
            case let attribute as any AttributedStringKey.Type:
                if self.storage[attribute.name] != other.storage[attribute.name] {
                    equal = false
                    return false
                }
                break
            default: break // TODO: Nested scopes
            }
            return true
        }
        return equal
    }

    internal var attributes : AttributeContainer {
        var contents = AttributedString._AttributeStorage()
        _forEachField(of: S.self, options: [.ignoreUnknown]) { name, offset, type, kind -> Bool in
            if let attribute = type as? any AttributedStringKey.Type {
                contents[attribute.name] = self.storage[attribute.name]
            }
            return true
        }
        return AttributeContainer(contents)
    }
}


// MARK: Internals

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

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
internal extension AttributeScope {
    static func attributeKeyType(matching key: String) -> (any AttributedStringKey.Type)? {
        var result: (any AttributedStringKey.Type)?
        _forEachField(of: Self.self, options: [.ignoreUnknown]) { name, offset, type, kind -> Bool in
            if let attributeType = type as? any AttributedStringKey.Type, attributeType.name == key {
                result = attributeType
                return false
            }
            
            if let scopeType = type as? any AttributeScope.Type, let found = scopeType.attributeKeyType(matching: key) {
                result = found
                return false
            }
            return true
        }
        
        return result
    }
    
    static func markdownAttributeKeyType(matching key: String) -> (any MarkdownDecodableAttributedStringKey.Type)? {
        var result: (any MarkdownDecodableAttributedStringKey.Type)?
        _forEachField(of: Self.self, options: [.ignoreUnknown]) { name, offset, type, kind -> Bool in
            if let attributeType = type as? any MarkdownDecodableAttributedStringKey.Type, attributeType.markdownName == key {
                result = attributeType
                return false
            }
            
            if let scopeType = type as? any AttributeScope.Type, let found = scopeType.markdownAttributeKeyType(matching: key) {
                result = found
                return false
            }
            return true
        }
        
        return result
    }
}
