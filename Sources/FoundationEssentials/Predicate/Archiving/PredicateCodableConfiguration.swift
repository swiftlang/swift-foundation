//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK

#if canImport(ReflectionInternal)
@_implementationOnly
import ReflectionInternal

@available(FoundationPredicate 0.1, *)
public protocol PredicateCodableKeyPathProviding {
    static var predicateCodableKeyPaths : [String : PartialKeyPath<Self>] { get }
}

@available(FoundationPredicate 0.1, *)
public struct PredicateCodableConfiguration: Sendable, CustomDebugStringConvertible {
    enum AllowListType : Equatable, Sendable {
        case concrete(Type)
        case partial(PartialType)
        
        static func concrete(for type: Any.Type) -> Self {
            .concrete(Type(type))
        }
        
        static func partial(for type: Any.Type) -> Self? {
            guard let partial = Type(type).partial else {
                return nil
            }
            return .partial(partial)
        }
        
        var description: String {
            switch self {
            case .concrete(let type):
                return "type '\(_typeName(type.swiftType, qualified: true))'"
            case .partial(let partial):
                return "partial type '\(partial.name)'"
            }
        }
    }
    
    enum AllowListKeyPath : Equatable, Sendable {
        typealias Constructor = @Sendable (GenericArguments) -> AnyKeyPath?
        
        case concrete(AnyKeyPath & Sendable)
        case partial(PartialType, Constructor, String)
        
        var description: String {
            switch self {
            case .concrete(let keyPath):
                return keyPath.debugDescription
            case .partial(let partialType, _, let property):
                return "\\\(partialType.name).\(property)"
            }
        }
        
        static func ==(lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.concrete(let lhsKP), .concrete(let rhsKP)):
                return lhsKP == rhsKP
            case (.partial(let lhsPartial, _, let lhsName), .partial(let rhsPartial, _, let rhsName)):
                return lhsPartial == rhsPartial && lhsName == rhsName
            default:
                return false
            }
        }
    }
    
    private var allowedKeyPaths: [String : AllowListKeyPath] = [:]
    private var allowedTypes: [String : AllowListType] = [:]
    internal var shouldAddInputTypes = true
    
    public init() {}
    
    public var debugDescription: String {
        let types = allowedTypes.map {
            "\($0.value.description) (\($0.key))"
        }.joined(separator: ", ")
        let keypaths = allowedKeyPaths.map {
            "\($0.value.description) (\($0.key))"
        }.joined(separator: ", ")
        return "PredicateCodableConfiguration(allowedTypes: [\(types)], allowedKeyPaths: [\(keypaths)])"
    }
    
    public mutating func allowType(_ type: Any.Type, identifier: String? = nil) {
        _allowType(type, identifier: identifier, preferNewIdentifier: true)
    }
    
    private mutating func _allowType(_ type: Any.Type, identifier: String? = nil, preferNewIdentifier: Bool) {
        let identifier = identifier ?? _typeName(type, qualified: true)
        for (id, value) in allowedTypes {
            if id == identifier {
                if case let .concrete(concreteType) = value, concreteType.swiftType != type {
                    fatalError("Cannot assign both '\(_typeName(concreteType.swiftType, qualified: true))' and '\(_typeName(type, qualified: true))' the same identifier '\(identifier)'")
                } else if case let .partial(partialType) = value {
                    fatalError("Cannot assign both partial type '\(partialType.name)' and type '\(_typeName(type, qualified: true))' the same identifier '\(identifier)'")
                } else {
                    return // The type is already allowed with this identifier
                }
            }
            
            if case let .concrete(concreteType) = value, concreteType.swiftType == type {
                if preferNewIdentifier {
                    // This type was previously allowed with a different identifier, remove the older entry
                    allowedTypes[id] = nil
                } else {
                    return
                }
            }
        }
        
        allowedTypes[identifier] = .concrete(for: type)
    }
    
    public mutating func disallowType(_ type: Any.Type) {
        allowedTypes = allowedTypes.filter {
            switch $0.value {
            case .concrete(let value):
                return value.swiftType != type
            case .partial(let value):
                return Type(type).partial != value
            }
        }
    }
    
    public mutating func allowPartialType(_ type: Any.Type, identifier: String) {
        guard let newPartialType = Type(type).partial else { return }
        _allowPartialType(newPartialType, identifier: identifier)
    }
    
    private mutating func _allowPartialType(_ type: PartialType, identifier: String) {
        for (id, existingType) in allowedTypes {
            if id == identifier {
                if case let .partial(partialType) = existingType, type != partialType {
                    fatalError("Cannot assign both partial type '\(partialType.name)' and partial type '\(type.name)' the same identifier '\(identifier)'")
                } else if case let .concrete(concreteType) = existingType {
                    fatalError("Cannot assign both type '\(_typeName(concreteType.swiftType, qualified: true))' and partial type '\(type.name)' the same identifier '\(identifier)'")
                } else {
                    return // The type is already allowed with this identifier
                }
            }
            
            if case let .partial(partialType) = existingType, type == partialType {
                // This type was previously allowed with a different identifier, remove the older entry
                allowedTypes[id] = nil
            }
        }
        allowedTypes[identifier] = .partial(type)
    }
    
    public mutating func disallowPartialType(_ type: Any.Type) {
        guard let partial = Type(type).partial else { return }
        allowedTypes = allowedTypes.filter {
            switch $0.value {
            case .concrete(let value):
                return Type(value).partial != partial
            case .partial(let value):
                return value != partial
            }
        }
    }
    
    public mutating func allowKeyPath(_ keyPath: AnyKeyPath, identifier: String) {
        keyPath._validateForPredicateUsage()
        for (id, existingKeyPath) in allowedKeyPaths {
            if id == identifier {
                if case let .concrete(concreteKeyPath) = existingKeyPath, concreteKeyPath != keyPath {
                    fatalError("Cannot assign both '\(concreteKeyPath.debugDescription)' and '\(keyPath.debugDescription)' the same identifier '\(identifier)'")
                } else if case .partial(_, _, _) = existingKeyPath {
                    fatalError("Cannot assign both '\(existingKeyPath.description)' and '\(keyPath.debugDescription)' the same identifier '\(identifier)'")
                } else {
                    return // The keypath is already allowed with this identifier
                }
            }
            
            if case let .concrete(concreteKeyPath) = existingKeyPath, concreteKeyPath == keyPath {
                // This keypath was previously allowed with a different identifier, remove the older entry
                allowedKeyPaths[id] = nil
            }
        }
        allowedKeyPaths[identifier] = .concrete(keyPath)
        _allowType(type(of: keyPath).rootType, preferNewIdentifier: false)
        _allowType(type(of: keyPath).valueType, preferNewIdentifier: false)
    }
    
    public mutating func disallowKeyPath(_ keyPath: AnyKeyPath) {
        keyPath._validateForPredicateUsage()
        allowedKeyPaths = allowedKeyPaths.filter {
            $0.value != .concrete(keyPath)
        }
    }
    
    internal mutating func _allowPartialKeyPath(_ root: PartialType, identifier: String, name: String, constructor: @escaping AllowListKeyPath.Constructor) {
        let newValue = AllowListKeyPath.partial(root, constructor, name)
        for (id, existingKeyPath) in allowedKeyPaths {
            if id == identifier {
                if case let .concrete(concreteKeyPath) = existingKeyPath {
                    fatalError("Cannot assign both '\(concreteKeyPath.debugDescription)' and '\(newValue.description)' the same identifier '\(identifier)'")
                } else if case let .partial(existingPartial, _, existingName) = existingKeyPath, (existingPartial != root || existingName != name) {
                    fatalError("Cannot assign both '\(existingKeyPath.description)' and '\(newValue.description)' the same identifier '\(identifier)'")
                } else {
                    return // The keypath is already allowed with this identifier
                }
            }
            
            if case let .partial(existingPartial, _, existingName) = existingKeyPath, existingPartial == root, existingName == name {
                // This keypath was previously allowed with a different identifier, remove the older entry
                allowedKeyPaths[id] = nil
            }
        }
        allowedKeyPaths[identifier] = newValue
    }
    
    public mutating func allowKeyPathsForPropertiesProvided<T: PredicateCodableKeyPathProviding>(by type: T.Type, recursive: Bool = false) {
        for (identifier, keyPath) in type.predicateCodableKeyPaths {
            allowKeyPath(keyPath, identifier: identifier)
            if recursive, let valueType = Swift.type(of: keyPath).valueType as? any PredicateCodableKeyPathProviding.Type {
                allowKeyPathsForPropertiesProvided(by: valueType, recursive: true)
            }
        }
    }
    
    public mutating func disallowKeyPathsForPropertiesProvided<T: PredicateCodableKeyPathProviding>(by type: T.Type, recursive: Bool = false) {
        for (_, keyPath) in type.predicateCodableKeyPaths {
            disallowKeyPath(keyPath)
            if recursive, let valueType = Swift.type(of: keyPath).valueType as? any PredicateCodableKeyPathProviding.Type {
                disallowKeyPathsForPropertiesProvided(by: valueType, recursive: true)
            }
        }
    }
    
    public mutating func allow(_ other: Self) {
        for (identifier, type) in other.allowedTypes {
            switch type {
            case .concrete(let concrete):
                allowType(concrete.swiftType, identifier: identifier)
            case .partial(let partial):
                _allowPartialType(partial, identifier: identifier)
            }
        }
        for (identifier, value) in other.allowedKeyPaths {
            switch value {
            case .concrete(let keyPath):
                allowKeyPath(keyPath, identifier: identifier)
            case .partial(let partialType, let constructor, let name):
                _allowPartialKeyPath(partialType, identifier: identifier, name: name, constructor: constructor)
            }
        }
    }
}

@available(FoundationPredicate 0.1, *)
extension PredicateCodableConfiguration {
    func _identifier(for keyPath: AnyKeyPath) -> String? {
        let concreteIdentifier = allowedKeyPaths.first {
            $0.value == .concrete(keyPath)
        }?.key
        
        if let concreteIdentifier {
            return concreteIdentifier
        }
        
        let inputRoot =  Type(type(of: keyPath).rootType)
        if let inputPartialRoot = inputRoot.partial {
            let partialIdentifier = allowedKeyPaths.first {
                if case let .partial(root, constructor, _) = $0.value, root == inputPartialRoot, let constructed = constructor(inputRoot.genericArguments) {
                    return constructed == keyPath
                } else {
                    return false
                }
            }?.key
            
            if let partialIdentifier {
                return partialIdentifier
            }
        }
        
        return nil
    }
    
    func _keyPath(for identifier: String, rootType: Any.Type) -> AnyKeyPath? {
        guard let value = allowedKeyPaths[identifier] else {
            return nil
        }
        
        switch value {
        case .concrete(let keyPath):
            return keyPath
        case .partial(let root, let constructor, _):
            let rootReflectionType = Type(rootType)
            guard root == rootReflectionType.partial, let constructed = constructor(rootReflectionType.genericArguments) else {
                return nil
            }
            constructed._validateForPredicateUsage(restrictArguments: false)
            return constructed
        }
    }
    
    func _identifier(for type: Type) -> (identifier: String, isConcrete: Bool)? {
        let concreteIdentifier = allowedTypes.first {
            $0.value == .concrete(type)
        }?.key
        
        if let concreteIdentifier {
            return (concreteIdentifier, true)
        }
        
        if let partial = type.partial {
            let partialIdentifier = allowedTypes.first {
                $0.value == .partial(partial)
            }?.key
            
            if let partialIdentifier {
                return (partialIdentifier, false)
            }
        }
        
        return nil
    }
    
    func _type(for identifier: String) -> AllowListType? {
        return allowedTypes[identifier]
    }
}

@available(FoundationPredicate 0.1, *)
extension PredicateCodableConfiguration {
    public static let standardConfiguration: Self = {
        var configuration = Self()
        
        // Basic types
        configuration.allowType(Int.self)
        configuration.allowType(Bool.self)
        configuration.allowType(Double.self)
        configuration.allowType(String.self)
        configuration.allowType(Substring.self)
        configuration.allowType(Character.self)
        configuration.allowPartialType(Array<Int>.self, identifier: "Swift.Array")
        configuration.allowPartialType(Dictionary<Int, Int>.self, identifier: "Swift.Dictionary")
        configuration.allowPartialType(Set<Int>.self, identifier: "Swift.Set")
        configuration.allowPartialType(Optional<Int>.self, identifier: "Swift.Optional")
        configuration.allowPartialType(Slice<String>.self, identifier: "Swift.Slice")
        configuration.allowPartialType(Predicate<Int>.self, identifier: "Foundation.Predicate")
        
        // Foundation-defined operator helper types
        configuration.allowType(PredicateExpressions.PredicateRegex.self)
        
        // Foundation-defined PredicateExpression types
        configuration.allowPartialType(PredicateExpressions.Arithmetic<PredicateExpressions.Value<Int>, PredicateExpressions.Value<Int>>.self, identifier: "PredicateExpressions.Arithmetic")
        configuration.allowPartialType(PredicateExpressions.ClosedRange<PredicateExpressions.Value<Int>, PredicateExpressions.Value<Int>>.self, identifier: "PredicateExpressions.ClosedRange")
        configuration.allowPartialType(PredicateExpressions.RangeExpressionContains<PredicateExpressions.Value<Range<Int>>, PredicateExpressions.Value<Int>>.self, identifier: "PredicateExpressions.RangeExpressionContains")
        configuration.allowPartialType(PredicateExpressions.CollectionContainsCollection<PredicateExpressions.Value<[Int]>, PredicateExpressions.Value<[Int]>>.self, identifier: "PredicateExpressions.CollectionContainsCollection")
        configuration.allowPartialType(PredicateExpressions.CollectionIndexSubscript<PredicateExpressions.Value<[Int]>, PredicateExpressions.Value<Int>>.self, identifier: "PredicateExpressions.CollectionIndexSubscript")
        configuration.allowPartialType(PredicateExpressions.CollectionRangeSubscript<PredicateExpressions.Value<[Int]>, PredicateExpressions.Value<Range<Int>>>.self, identifier: "PredicateExpressions.CollectionRangeSubscript")
        configuration.allowPartialType(PredicateExpressions.Comparison<PredicateExpressions.Value<Int>, PredicateExpressions.Value<Int>>.self, identifier: "PredicateExpressions.Comparison")
        configuration.allowPartialType(PredicateExpressions.Conditional<PredicateExpressions.Value<Bool>, PredicateExpressions.Value<Int>, PredicateExpressions.Value<Int>>.self, identifier: "PredicateExpressions.Conditional")
        configuration.allowPartialType(PredicateExpressions.Conjunction<PredicateExpressions.Value<Bool>, PredicateExpressions.Value<Bool>>.self, identifier: "PredicateExpressions.Conjunction")
        configuration.allowPartialType(PredicateExpressions.DictionaryKeyDefaultValueSubscript<PredicateExpressions.Value<[Int:Int]>, PredicateExpressions.Value<Int>, PredicateExpressions.Value<Int>>.self, identifier: "PredicateExpressions.DictionaryKeyDefaultValueSubscript")
        configuration.allowPartialType(PredicateExpressions.DictionaryKeySubscript<PredicateExpressions.Value<[Int:Int]>, PredicateExpressions.Value<Int>, Int>.self, identifier: "PredicateExpressions.DictionaryKeySubscript")
        configuration.allowPartialType(PredicateExpressions.Disjunction<PredicateExpressions.Value<Bool>, PredicateExpressions.Value<Bool>>.self, identifier: "PredicateExpressions.Disjunction")
        configuration.allowPartialType(PredicateExpressions.IntDivision<PredicateExpressions.Value<Int>, PredicateExpressions.Value<Int>>.self, identifier: "PredicateExpressions.IntDivision")
        configuration.allowPartialType(PredicateExpressions.IntRemainder<PredicateExpressions.Value<Int>, PredicateExpressions.Value<Int>>.self, identifier: "PredicateExpressions.IntRemainder")
        configuration.allowPartialType(PredicateExpressions.FloatDivision<PredicateExpressions.Value<Float>, PredicateExpressions.Value<Float>>.self, identifier: "PredicateExpressions.FloatDivision")
        configuration.allowPartialType(PredicateExpressions.Equal<PredicateExpressions.Value<Int>, PredicateExpressions.Value<Int>>.self, identifier: "PredicateExpressions.Equal")
        configuration.allowPartialType(PredicateExpressions.Filter<PredicateExpressions.Value<[Int]>, PredicateExpressions.Value<Bool>>.self, identifier: "PredicateExpressions.Filter")
        configuration.allowPartialType(PredicateExpressions.NotEqual<PredicateExpressions.Value<Int>, PredicateExpressions.Value<Int>>.self, identifier: "PredicateExpressions.NotEqual")
        configuration.allowPartialType(PredicateExpressions.Negation<PredicateExpressions.Value<Bool>>.self, identifier: "PredicateExpressions.Negation")
        configuration.allowPartialType(PredicateExpressions.OptionalFlatMap<PredicateExpressions.Value<Bool?>, Bool, PredicateExpressions.Value<Bool>, Bool>.self, identifier: "PredicateExpressions.OptionalFlatMap")
        configuration.allowPartialType(PredicateExpressions.NilCoalesce<PredicateExpressions.Value<Bool?>, PredicateExpressions.Value<Bool>>.self, identifier: "PredicateExpressions.NilCoalesce")
        configuration.allowPartialType(PredicateExpressions.ForcedUnwrap<PredicateExpressions.Value<Bool?>, Bool>.self, identifier: "PredicateExpressions.ForcedUnwrap")
        configuration.allowPartialType(PredicateExpressions.Range<PredicateExpressions.Value<Int>, PredicateExpressions.Value<Int>>.self, identifier: "PredicateExpressions.Range")
        configuration.allowPartialType(PredicateExpressions.SequenceContains<PredicateExpressions.Value<[Int]>, PredicateExpressions.Value<Int>>.self, identifier: "PredicateExpressions.SequenceContains")
        configuration.allowPartialType(PredicateExpressions.SequenceContainsWhere<PredicateExpressions.Value<[Int]>, PredicateExpressions.Value<Bool>>.self, identifier: "PredicateExpressions.SequenceContainsWhere")
        configuration.allowPartialType(PredicateExpressions.SequenceContainsWhere<PredicateExpressions.Value<[Int]>, PredicateExpressions.Value<Bool>>.self, identifier: "PredicateExpressions.SequenceAllSatisfy")
        configuration.allowPartialType(PredicateExpressions.SequenceStartsWith<PredicateExpressions.Value<[Int]>, PredicateExpressions.Value<[Int]>>.self, identifier: "PredicateExpressions.SequenceStartsWith")
        configuration.allowPartialType(PredicateExpressions.SequenceMaximum<PredicateExpressions.Value<[Int]>>.self, identifier: "PredicateExpressions.SequenceMaximum")
        configuration.allowPartialType(PredicateExpressions.SequenceMinimum<PredicateExpressions.Value<[Int]>>.self, identifier: "PredicateExpressions.SequenceMinimum")
        configuration.allowPartialType(PredicateExpressions.ConditionalCast<PredicateExpressions.Value<Int>, Int>.self, identifier: "PredicateExpressions.ConditionalCast")
        configuration.allowPartialType(PredicateExpressions.ForceCast<PredicateExpressions.Value<Int>, Int>.self, identifier: "PredicateExpressions.ForceCast")
        configuration.allowPartialType(PredicateExpressions.TypeCheck<PredicateExpressions.Value<Int>, Int>.self, identifier: "PredicateExpressions.TypeCheck")
        configuration.allowPartialType(PredicateExpressions.UnaryMinus<PredicateExpressions.Value<Int>>.self, identifier: "PredicateExpressions.UnaryMinus")
        configuration.allowPartialType(PredicateExpressions.NilLiteral<Int>.self, identifier: "PredicateExpressions.NilLiteral")
        configuration.allowPartialType(PredicateExpressions.PredicateEvaluate<PredicateExpressions.Value<Predicate<Int>>, PredicateExpressions.Value<Int>>.self, identifier: "PredicateExpressions.PredicateEvaluate")
        configuration.allowPartialType(PredicateExpressions.StringContainsRegex<PredicateExpressions.Value<String>, PredicateExpressions.Value<PredicateExpressions.PredicateRegex>>.self, identifier: "PredicateExpressions.StringContainsRegex")
        
        #if FOUNDATION_FRAMEWORK
        configuration.allowPartialType(PredicateExpressions.StringCaseInsensitiveCompare<PredicateExpressions.Value<String>, PredicateExpressions.Value<String>>.self, identifier: "PredicateExpressions.StringCaseInsensitiveCompare")
        configuration.allowPartialType(PredicateExpressions.StringLocalizedCompare<PredicateExpressions.Value<String>, PredicateExpressions.Value<String>>.self, identifier: "PredicateExpressions.StringLocalizedCompare")
        configuration.allowPartialType(PredicateExpressions.StringLocalizedStandardContains<PredicateExpressions.Value<String>, PredicateExpressions.Value<String>>.self, identifier: "PredicateExpressions.StringLocalizedStandardContains")
        #endif
        
        configuration.allowPartialType(PredicateExpressions.KeyPath<PredicateExpressions.Value<Int>, Int>.self, identifier: "PredicateExpressions.KeyPath")
        configuration.allowPartialType(PredicateExpressions.Variable<Int>.self, identifier: "PredicateExpressions.Variable")
        configuration.allowPartialType(PredicateExpressions.Value<Int>.self, identifier: "PredicateExpressions.Value")
        
        // Basic keypaths
        configuration.allowKeyPath(\String.count, identifier: "Swift.String.count")
        configuration.allowKeyPath(\Substring.count, identifier: "Swift.Substring.count")
        configuration.allowKeyPath(\String.isEmpty, identifier: "Swift.String.isEmpty")
        configuration.allowKeyPath(\Substring.isEmpty, identifier: "Swift.Substring.isEmpty")
        configuration.allowKeyPath(\String.first, identifier: "Swift.String.first")
        configuration.allowKeyPath(\Substring.first, identifier: "Swift.Substring.first")
        configuration.allowKeyPath(\String.last, identifier: "Swift.String.last")
        configuration.allowKeyPath(\Substring.last, identifier: "Swift.Substring.last")
        
        // Basic Array keypaths
        configuration._allowPartialKeyPath(Type(Array<Int>.self).partial!, identifier: "Swift.Array.count", name: "count") { genericArgs in
            guard let elementType = genericArgs.first else {
                return nil
            }
            
            func project<E>(_: E.Type) -> AnyKeyPath {
                \Array<E>.count
            }
            return _openExistential(elementType.swiftType, do: project)
        }
        configuration._allowPartialKeyPath(Type(Array<Int>.self).partial!, identifier: "Swift.Array.isEmpty", name: "isEmpty") { genericArgs in
            guard let elementType = genericArgs.first else {
                return nil
            }
            
            func project<E>(_: E.Type) -> AnyKeyPath {
                \Array<E>.isEmpty
            }
            return _openExistential(elementType.swiftType, do: project)
        }
        configuration._allowPartialKeyPath(Type(Array<Int>.self).partial!, identifier: "Swift.Array.first", name: "first") { genericArgs in
            guard let elementType = genericArgs.first else {
                return nil
            }
            
            func project<E>(_: E.Type) -> AnyKeyPath {
                \Array<E>.first
            }
            return _openExistential(elementType.swiftType, do: project)
        }
        configuration._allowPartialKeyPath(Type(Array<Int>.self).partial!, identifier: "Swift.Array.last", name: "last") { genericArgs in
            guard let elementType = genericArgs.first else {
                return nil
            }
            
            func project<E>(_: E.Type) -> AnyKeyPath {
                \Array<E>.last
            }
            return _openExistential(elementType.swiftType, do: project)
        }
        
        // Basic Set keypaths
        configuration._allowPartialKeyPath(Type(Set<Int>.self).partial!, identifier: "Swift.Set.count", name: "count") { genericArgs in
            guard let elementType = genericArgs.first?.swiftType as? any Hashable.Type else {
                return nil
            }
            
            func project<E: Hashable>(_: E.Type) -> AnyKeyPath {
                \Set<E>.count
            }
            return project(elementType)
        }
        configuration._allowPartialKeyPath(Type(Set<Int>.self).partial!, identifier: "Swift.Set.isEmpty", name: "isEmpty") { genericArgs in
            guard let elementType = genericArgs.first?.swiftType as? any Hashable.Type else {
                return nil
            }
            
            func project<E: Hashable>(_: E.Type) -> AnyKeyPath {
                \Set<E>.isEmpty
            }
            return project(elementType)
        }
        
        // Basic Dictionary keypaths
        configuration._allowPartialKeyPath(Type(Dictionary<Int, Int>.self).partial!, identifier: "Swift.Dictionary.count", name: "count") { genericArgs in
            guard genericArgs.count == 2, let keyType = genericArgs[0].swiftType as? any Hashable.Type else {
                return nil
            }
            
            func project<K: Hashable>(_: K.Type) -> AnyKeyPath {
                func project2<V>(_: V.Type) -> AnyKeyPath {
                    \Dictionary<K, V>.count
                }
                return _openExistential(genericArgs[1].swiftType, do: project2)
            }
            return project(keyType)
        }
        configuration._allowPartialKeyPath(Type(Dictionary<Int, Int>.self).partial!, identifier: "Swift.Dictionary.isEmpty", name: "isEmpty") { genericArgs in
            guard genericArgs.count == 2, let keyType = genericArgs[0].swiftType as? any Hashable.Type else {
                return nil
            }
            
            func project<K: Hashable>(_: K.Type) -> AnyKeyPath {
                func project2<V>(_: V.Type) -> AnyKeyPath {
                    \Dictionary<K, V>.isEmpty
                }
                return _openExistential(genericArgs[1].swiftType, do: project2)
            }
            return project(keyType)
        }
        
        return configuration
    }()
}

#endif // canImport(ReflectionInternal)
#endif // FOUNDATION_FRAMEWORK
