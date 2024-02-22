//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK
@_implementationOnly
import Synchronization
#endif

@available(FoundationPredicate 0.1, *)
public protocol PredicateExpression<Output> {
    associatedtype Output
    
    func evaluate(_ bindings: PredicateBindings) throws -> Output
}

// Only Foundation should add conformances to this protocol
@available(FoundationPredicate 0.1, *)
public protocol StandardPredicateExpression<Output> : PredicateExpression, Codable, Sendable {}

@available(FoundationPredicate 0.1, *)
public struct PredicateError: Error, Hashable, CustomDebugStringConvertible {
    internal enum _Error: Hashable, Sendable {
        case undefinedVariable
        case forceUnwrapFailure(String?)
        case forceCastFailure(String?)
        case invalidInput(String?)
    }
    
    private let _error: _Error
    
    internal init(_ error: _Error) {
        _error = error
    }
    
    public var debugDescription: String {
        switch _error {
        case .undefinedVariable:
            return "Encountered an undefined variable"
        case .forceUnwrapFailure(let string):
            return string ?? "Attempted to force unwrap a nil value"
        case .forceCastFailure(let string):
            return string ?? "Failed to cast a value to the desired type"
        case .invalidInput(let string):
            return string ?? "The inputs to this expression are invalid"
        }
    }
    
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        switch lhs._error {
        case .undefinedVariable:
            return rhs == .undefinedVariable
        case .forceCastFailure(_):
            if case .forceCastFailure(_) = rhs._error {
                return true
            }
            return false
        case .forceUnwrapFailure(_):
            if case .forceUnwrapFailure(_) = rhs._error {
                return true
            }
            return false
        case .invalidInput(_):
            if case .invalidInput(_) = rhs._error {
                return true
            }
            return false
        }
    }
    
    public static let undefinedVariable = Self(.undefinedVariable)
    public static let forceUnwrapFailure = Self(.forceUnwrapFailure(nil))
    public static let forceCastFailure = Self(.forceCastFailure(nil))
    public static let invalidInput = Self(.invalidInput(nil))
}

@available(FoundationPredicate 0.1, *)
extension PredicateExpressions {
    public struct VariableID: Hashable, Codable, Sendable {
        let id: UInt
        #if FOUNDATION_FRAMEWORK
        private static let nextID = Atomic<UInt>(0)
        #else
        private static let nextID = LockedState(initialState: UInt(0))
        #endif
        
        init() {
            #if FOUNDATION_FRAMEWORK
            self.id = Self.nextID.wrappingAdd(1, ordering: .relaxed).oldValue
            #else
            self.id = Self.nextID.withLock { value in
                defer {
                    (value, _) = value.addingReportingOverflow(1)
                }
                return value
            }
            #endif
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(id)
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let decodedID = try container.decode(UInt.self)
#if FOUNDATION_FRAMEWORK
            if let newVariable = _ThreadLocal[.predicateArchivingState]?.createVariable(for: decodedID) {
                self = newVariable
                return
            }
#endif // FOUNDATION_FRAMEWORK
            self.id = decodedID
        }
    }
    
    public struct Variable<Output> : StandardPredicateExpression {
        public let key: VariableID
        
        public init() {
            self.key = VariableID()
        }
        
        public func evaluate(_ bindings: PredicateBindings) throws -> Output {
            if let value = bindings[self] {
                return value
            }
            throw PredicateError.undefinedVariable
        }
    }
    
    public struct KeyPath<Root : PredicateExpression, Output> : PredicateExpression {
        public let root: Root
        public let keyPath: Swift.KeyPath<Root.Output, Output> & Sendable
        
        public init(root: Root, keyPath: Swift.KeyPath<Root.Output, Output> & Sendable) {
            keyPath._validateForPredicateUsage()
            self.root = root
            self.keyPath = keyPath
        }
        
        public func evaluate(_ bindings: PredicateBindings) throws -> Output {
            return try root.evaluate(bindings)[keyPath: keyPath as Swift.KeyPath<Root.Output, Output>]
        }
    }

    public struct Value<Output> : PredicateExpression {
        public let value: Output
        
        public init(_ value: Output) {
            self.value = value
        }
        
        public func evaluate(_ bindings: PredicateBindings) -> Output {
            return self.value
        }
    }
    
    public static func build_Arg<T>(_ arg: T) -> Value<T> {
        Value(arg)
    }
    
    public static func build_Arg<T: PredicateExpression>(_ arg: T) -> T {
        arg
    }
    
    public static func build_KeyPath<Root, Value>(root: Root, keyPath: Swift.KeyPath<Root.Output, Value>) -> PredicateExpressions.KeyPath<Root, Value> {
        KeyPath(root: root, keyPath: keyPath)
    }

}

@available(FoundationPredicate 0.1, *)
extension PredicateExpressions.KeyPath : Codable where Root : Codable {
    private enum CodingKeys : CodingKey {
        case root
        case identifier
    }
    
    public func encode(to encoder: Encoder) throws {
#if FOUNDATION_FRAMEWORK
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(root, forKey: .root)
        guard let identifier = _ThreadLocal[.predicateArchivingState]?.configuration._identifier(for: keyPath) else {
            throw EncodingError.invalidValue(keyPath, .init(codingPath: container.codingPath, debugDescription: "The '\(keyPath.debugDescription)' keypath is not in the provided allowlist"))
        }
        try container.encode(identifier, forKey: .identifier)
#else
        throw EncodingError.invalidValue(self, .init(codingPath: encoder.codingPath, debugDescription: "Encoding PredicateExpressions.KeyPath is not supported"))
#endif // FOUNDATION_FRAMEWORK
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
#if FOUNDATION_FRAMEWORK
        root = try container.decode(Root.self, forKey: .root)
        let identifier = try container.decode(String.self, forKey: .identifier)
        guard let anykp = _ThreadLocal[.predicateArchivingState]?.configuration._keyPath(for: identifier, rootType: Root.Output.self) else {
            throw DecodingError.dataCorruptedError(forKey: .identifier, in: container, debugDescription: "A keypath for the '\(identifier)' identifier is not in the provided allowlist")
        }
        guard let kp = anykp as? Swift.KeyPath<Root.Output, Output> else {
            throw DecodingError.dataCorruptedError(forKey: .identifier, in: container, debugDescription: "Key path '\(anykp.debugDescription)' (KeyPath<\(_typeName(type(of: anykp).rootType)), \(_typeName(type(of: anykp).valueType))>) for identifier '\(identifier)' did not match the expression's requirement for KeyPath<\(_typeName(Root.Output.self)), \(_typeName(Output.self))>")
        }
        self.keyPath = kp
#else
        throw DecodingError.dataCorruptedError(forKey: .identifier, in: container, debugDescription: "Decoding PredicateExpressions.KeyPath is not supported")
#endif // FOUNDATION_FRAMEWORK
    }
}
@available(FoundationPredicate 0.1, *)
extension PredicateExpressions.KeyPath : Sendable where Root : Sendable {}

@available(FoundationPredicate 0.1, *)
extension PredicateExpressions.KeyPath : StandardPredicateExpression where Root : StandardPredicateExpression {}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.KeyPath : CustomStringConvertible {
    public var description: String {
        "KeyPath(root: \(root), keyPath: \(keyPath.debugDescription))"
    }
}

@available(FoundationPredicate 0.1, *)
extension PredicateExpressions.Value : Codable where Output : Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(Output.self)
    }
}

@available(FoundationPredicate 0.1, *)
extension PredicateExpressions.Value : Sendable where Output : Sendable {}

@available(FoundationPredicate 0.1, *)
extension PredicateExpressions.Value : StandardPredicateExpression where Output : Codable /*, Output : Sendable*/ {}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.Value : CustomStringConvertible {
    public var description: String {
        var result = "Value<\(_typeName(Output.self))>("
        debugPrint(value, separator: "", terminator: "", to: &result)
        return result + ")"
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.Variable : CustomStringConvertible {
    public var description: String {
        "Variable(\(key.id))"
    }
}

@available(FoundationPredicate 0.1, *)
extension PredicateExpressions.KeyPath {
    public enum CommonKeyPathKind : Hashable, Sendable {
        case collectionCount
        case collectionIsEmpty
        case collectionFirst
        case bidirectionalCollectionLast
    }
    
    public var kind: CommonKeyPathKind? {
        guard let collectionType = Root.Output.self as? any Collection.Type else {
            return nil
        }
        return Self.kind(keyPath, collectionType: collectionType)
    }
    
    private static func kind<C: Collection>(_ anyKP: AnyKeyPath, collectionType: C.Type) -> CommonKeyPathKind? {
        let kp = anyKP as! PartialKeyPath<C>
        switch kp {
        case \String.count, \Substring.count, \Array<C.Element>.count:
            return .collectionCount
        case \String.isEmpty, \Substring.isEmpty, \Array<C.Element>.isEmpty:
            return .collectionIsEmpty
        case \Array<C.Element>.first:
            return .collectionFirst
        case \Array<C.Element>.last:
            return .bidirectionalCollectionLast
        default:
            if let hashableElem = C.Element.self as? any Hashable.Type {
                return Self.kind(kp, hashableElementType: hashableElem)
            }
            return nil
        }
    }
    
    private static func kind<C: Collection, Element: Hashable>(_ kp: PartialKeyPath<C>, hashableElementType: Element.Type) -> CommonKeyPathKind? {
        switch kp {
        case \Set<Element>.count:
            return .collectionCount
        case \Set<Element>.isEmpty:
            return .collectionIsEmpty
        default:
            return nil
        }
    }
}
