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

@preconcurrency internal import ReflectionInternal

@available(FoundationPredicate 0.1, *)
enum PredicateCodableError : Error, CustomStringConvertible {
    case disallowedType(typeName: String, path: String)
    case disallowedIdentifier(String, path: String)
    case reconstructionFailure(PartialType, [GenericArgument])
    case variadicType(typeName: String, path: String)
    
    var description: String {
        switch self {
        case .disallowedType(let typeName, let path): return "The '\(typeName)' type is not in the provided allowlist (required by \(path))"
        case .disallowedIdentifier(let id, let path): return "The '\(id)' identifier is not in the provided allowlist (required by \(path))"
        case .reconstructionFailure(let partial, let args):
            let types = args.map {
                switch $0 {
                case .type(let type): _typeName(type.swiftType)
                case .pack(let types): "Pack{\(types.map({ _typeName($0.swiftType) }).joined(separator: ", "))}"
                }
            }
            return "Reconstruction of '\(partial.name)' with the arguments [\(types.joined(separator: ", "))] failed"
        case .variadicType(let typeName, let path): return "The '\(typeName)' type is not allowed because it contains type pack parameters (required by \(path))"
        }
    }
}

@available(FoundationPredicate 0.1, *)
private struct ExpressionStructure : Codable {
    private enum Argument : Codable {
        case scalar(ExpressionStructure)
        case pack([ExpressionStructure])
        
        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let scalarArg = try? container.decode(ExpressionStructure.self) {
                self = .scalar(scalarArg)
            } else {
                self = .pack(try container.decode([ExpressionStructure].self))
            }
        }
        
        func encode(to encoder: any Encoder) throws {
            switch self {
            case let .scalar(arg):
                var container = encoder.singleValueContainer()
                try container.encode(arg)
            case let .pack(args):
                var container = encoder.singleValueContainer()
                try container.encode(args)
            }
        }
    }
    private let identifier: String
    private let args: [Argument]
    
    private enum CodingKeys: CodingKey {
        case identifier
        case args
    }
    
    func encode(to encoder: Encoder) throws {
        if args.isEmpty {
            var container = encoder.singleValueContainer()
            try container.encode(identifier)
        } else {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(identifier, forKey: .identifier)
            try container.encode(args, forKey: .args)
        }
    }
    
    init(from decoder: Decoder) throws {
        if let keyedContainer = try? decoder.container(keyedBy: CodingKeys.self) {
            identifier = try keyedContainer.decode(String.self, forKey: .identifier)
            args = try keyedContainer.decode([Argument].self, forKey: .args)
            return
        }
        
        identifier = try decoder.singleValueContainer().decode(String.self)
        args = []
    }
    
    init(_ type: Type, with configuration: PredicateCodableConfiguration, path: [String] = []) throws {
        guard let result = configuration._identifier(for: type) else {
            throw PredicateCodableError.disallowedType(typeName: _typeName(type.swiftType), path: "/\(path.joined(separator: "/"))")
        }
        
        self.identifier = result.identifier
        
        if !result.isConcrete {
            self.args = try type.genericArguments2.map {
                switch $0 {
                case .type(let type):
                    .scalar(try .init(type, with: configuration, path: path + [result.identifier]))
                case .pack(let types):
                    .pack(try types.map { try .init($0, with: configuration, path: path + [result.identifier]) })
                }
            }
        } else {
            self.args = []
        }
    }
    
    func reconstruct(with configuration: PredicateCodableConfiguration, path: [String] = []) throws -> Type {
        guard let result = configuration._type(for: identifier) else {
            throw PredicateCodableError.disallowedIdentifier(identifier, path: "/\(path.joined(separator: "/"))")
        }
        
        let partial: PartialType
        switch result {
        case .concrete(let type):
            return type
        case .partial(let partialType):
            partial = partialType
        }
        
        let argTypes: [GenericArgument] = try args.map {
            switch $0 {
            case let .scalar(arg):
                .type(try arg.reconstruct(with: configuration, path: path + [identifier]))
            case let .pack(args):
                .pack(try args.map { try $0.reconstruct(with: configuration, path: path + [identifier]) })
            }
        }
        
        guard let created = partial.create2(with: argTypes) else {
            throw PredicateCodableError.reconstructionFailure(partial, argTypes)
        }
        return created
    }
}

@available(FoundationPredicate 0.1, *)
class PredicateArchivingState {
    var configuration: PredicateCodableConfiguration
    
    private var variableMap: [UInt : PredicateExpressions.VariableID]
    
    init(configuration: PredicateCodableConfiguration) {
        self.configuration = configuration
        variableMap = [:]
    }
    
    func createVariable(for key: UInt) -> PredicateExpressions.VariableID {
        guard let existing = variableMap[key] else {
            let new = PredicateExpressions.VariableID()
            variableMap[key] = new
            return new
        }
        return existing
    }
}

@available(FoundationPredicate 0.1, *)
extension _ThreadLocal.Key<PredicateArchivingState> {
    static let predicateArchivingState = Self<PredicateArchivingState>()
}

enum PredicateExpressionCodingKeys : CodingKey {
    case variable
    case expression
    case structure
}

@available(FoundationPredicate 0.1, *)
fileprivate extension PredicateCodableConfiguration {
    mutating func allowInputs<each Input>(_ input: repeat (each Input).Type) {
        guard self.shouldAddInputTypes else { return }
        var inputTypes = [Any.Type]()
        repeat inputTypes.append((each Input).self)
        for (index, type) in inputTypes.enumerated() {
            allowType(type, identifier: "Foundation.Predicate.Input.\(index)")
        }
    }
}

private func _withPredicateArchivingState<R>(_ configuration: PredicateCodableConfiguration, _ block: () throws -> R) rethrows -> R {
    if let currentState = _ThreadLocal[.predicateArchivingState] {
        // Store the new configuration and reset it after encoding the subtree
        let oldConfiguration = currentState.configuration
        defer { currentState.configuration = oldConfiguration }
        
        currentState.configuration = configuration
        return try block()
    } else {
        var state = PredicateArchivingState(configuration: configuration)
        return try _ThreadLocal.withValue(&state, for: .predicateArchivingState, block)
    }
}

@available(FoundationPredicate 0.1, *)
extension KeyedEncodingContainer where Key == PredicateExpressionCodingKeys {
    mutating func _encode<T: PredicateExpression & Encodable, each Input>(_ expression: T, variable: repeat PredicateExpressions.Variable<each Input>, predicateConfiguration: PredicateCodableConfiguration) throws where T.Output == Bool {
        var predicateConfiguration = predicateConfiguration
        predicateConfiguration.allowInputs(repeat (each Input).self)
        let structure = try ExpressionStructure(Type(expression), with: predicateConfiguration)
        var variableContainer = self.nestedUnkeyedContainer(forKey: .variable)
        repeat try variableContainer.encode(each variable)
        try _withPredicateArchivingState(predicateConfiguration) {
            try self.encode(structure, forKey: .structure)
            try self.encode(expression, forKey: .expression)
        }
    }
}

@available(FoundationPredicate 0.1, *)
extension KeyedDecodingContainer where Key == PredicateExpressionCodingKeys {
    mutating func _decode<each Input>(input: repeat (each Input).Type, predicateConfiguration: PredicateCodableConfiguration) throws -> (expression: any PredicateExpression<Bool>, variable: (repeat PredicateExpressions.Variable<each Input>)) {
        var predicateConfiguration = predicateConfiguration
        predicateConfiguration.allowInputs(repeat (each Input).self)
        let structure = try self.decode(ExpressionStructure.self, forKey: .structure)

        func decode<E: Decodable & PredicateExpression>(_: E.Type) throws -> any PredicateExpression<Bool> where E.Output == Bool {
            try self.decode(E.self, forKey: .expression)
        }

        guard let exprType = try structure.reconstruct(with: predicateConfiguration).swiftType as? any (Decodable & PredicateExpression<Bool>).Type else {
            throw DecodingError.dataCorruptedError(forKey: .structure, in: self, debugDescription: "This expression is unsupported by this predicate")
        }
        var container = try self.nestedUnkeyedContainer(forKey: .variable)
        return try _withPredicateArchivingState(predicateConfiguration) {
            let variable = (repeat try container.decode(PredicateExpressions.Variable<each Input>.self))
            return (try decode(exprType), variable)
        }
    }
}

#endif // FOUNDATION_FRAMEWORK
