//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder
import SwiftDiagnostics

// MARK: - Shared Data Types

/// Represents a stored property with its coding configuration
struct StoredProperty {
    let name: String
    let key: String
    let aliases: [String]
}

/// Represents a detailed stored property with type information and default values
struct DetailedStoredProperty {
    let name: String
    let key: String
    let aliases: [String]
    let typeName: String
    let isOptional: Bool
    let defaultExpr: String?

    var isRequired: Bool {
        !isOptional && defaultExpr == nil
    }
}

/// Represents the kind of coding fields to generate
protocol CodingFieldExpansionKind: Equatable {
    static var encodingOnly: Self { get }
    static var decodingOnly: Self { get }
    static var both: Self { get }
    
    /// The protocol name that the generated enum should conform to
    var protocolName: String { get }
    
    /// Whether the generated enum should include key lookup functionality
    var includesKeyLookup: Bool { get }
    
    /// Whether the generated enum should include an "unknown" case
    var includesUnknownCase: Bool { get }
    
    /// Whether this kind supports encoding operations
    var supportsEncoding: Bool { get }
    
    /// Whether this kind supports decoding operations
    var supportsDecoding: Bool { get }
}

extension CodingFieldExpansionKind {
    var includesKeyLookup: Bool {
        supportsDecoding
    }
    
    var includesUnknownCase: Bool {
        supportsDecoding
    }
    
    var supportsEncoding: Bool {
        switch self {
        case .encodingOnly, .both:
            return true
        default:
            return false
        }
    }
    
    var supportsDecoding: Bool {
        switch self {
        case .decodingOnly, .both:
            return true
        default:
            return false
        }
    }
}

// MARK: - Shared Property Extraction

func extractStoredProperties(
    from members: MemberBlockSyntax,
    in context: some MacroExpansionContext
) -> [StoredProperty] {
    var properties: [StoredProperty] = []

    for member in members.members {
        guard let varDecl = member.decl.as(VariableDeclSyntax.self) else {
            continue
        }

        if varDecl.modifiers.contains(where: {
            $0.name.tokenKind == .keyword(.static) || $0.name.tokenKind == .keyword(.lazy)
        }) {
            continue
        }

        let customKey = customCodingKey(from: varDecl.attributes)
        let aliases = decodableAliases(from: varDecl.attributes)
        if (customKey != nil || !aliases.isEmpty) && varDecl.bindings.count > 1 {
            context.diagnose(.init(
                node: Syntax(varDecl),
                message: SharedMacroDiagnostic.codingKeyOnMultipleBindings
            ))
            continue
        }

        for binding in varDecl.bindings {
            if let accessorBlock = binding.accessorBlock {
                switch accessorBlock.accessors {
                case .getter:
                    continue
                case .accessors(let accessors):
                    let hasGetOrSet = accessors.contains {
                        $0.accessorSpecifier.tokenKind == .keyword(.get) ||
                        $0.accessorSpecifier.tokenKind == .keyword(.set)
                    }
                    if hasGetOrSet {
                        continue
                    }
                }
            }

            guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
                continue
            }

            let propertyName = pattern.identifier.trimmedDescription
            let key = customKey ?? propertyName

            properties.append(StoredProperty(name: propertyName, key: key, aliases: aliases))
        }
    }

    return properties
}

func extractDetailedStoredProperties(
    from members: MemberBlockSyntax,
    in context: some MacroExpansionContext
) -> [DetailedStoredProperty]? {
    var properties: [DetailedStoredProperty] = []

    for member in members.members {
        guard let varDecl = member.decl.as(VariableDeclSyntax.self) else {
            continue
        }

        if varDecl.modifiers.contains(where: {
            $0.name.tokenKind == .keyword(.static) || $0.name.tokenKind == .keyword(.lazy)
        }) {
            continue
        }

        let customKey = customCodingKey(from: varDecl.attributes)
        let defaultExpr = defaultValueExpression(from: varDecl.attributes)
        let aliases = decodableAliases(from: varDecl.attributes)
        if (customKey != nil || defaultExpr != nil || !aliases.isEmpty) && varDecl.bindings.count > 1 {
            context.diagnose(.init(
                node: Syntax(varDecl),
                message: SharedMacroDiagnostic.codingKeyOnMultipleBindings
            ))
            continue
        }

        for binding in varDecl.bindings {
            if let accessorBlock = binding.accessorBlock {
                switch accessorBlock.accessors {
                case .getter:
                    continue
                case .accessors(let accessors):
                    let hasGetOrSet = accessors.contains {
                        $0.accessorSpecifier.tokenKind == .keyword(.get) ||
                        $0.accessorSpecifier.tokenKind == .keyword(.set)
                    }
                    if hasGetOrSet {
                        continue
                    }
                }
            }

            guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
                continue
            }

            guard let typeAnnotation = binding.typeAnnotation else {
                context.diagnose(.init(
                    node: Syntax(binding),
                    message: SharedMacroDiagnostic.missingTypeAnnotation
                ))
                return nil
            }

            let propertyName = pattern.identifier.trimmedDescription
            let key = customKey ?? propertyName

            let type = typeAnnotation.type
            let isOptional: Bool
            let typeName: String

            if let optionalType = type.as(OptionalTypeSyntax.self) {
                isOptional = true
                typeName = optionalType.wrappedType.trimmedDescription
            } else if let iuoType = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
                isOptional = true
                typeName = iuoType.wrappedType.trimmedDescription
            } else {
                isOptional = false
                typeName = type.trimmedDescription
            }

            properties.append(DetailedStoredProperty(
                name: propertyName,
                key: key,
                aliases: aliases,
                typeName: typeName,
                isOptional: isOptional,
                defaultExpr: defaultExpr
            ))
        }
    }

    return properties
}

// MARK: - Attribute Parsing Utilities

func customCodingKey(from attributes: AttributeListSyntax) -> String? {
    for attribute in attributes {
        guard let attr = attribute.as(AttributeSyntax.self),
              let identifierType = attr.attributeName.as(IdentifierTypeSyntax.self),
              identifierType.name.trimmedDescription == "CodingKey",
              let arguments = attr.arguments?.as(LabeledExprListSyntax.self),
              let firstArg = arguments.first,
              let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
              let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) else {
            continue
        }
        return segment.content.text
    }
    return nil
}

func decodableAliases(from attributes: AttributeListSyntax) -> [String] {
    var aliases: [String] = []
    for attribute in attributes {
        guard let attr = attribute.as(AttributeSyntax.self),
              let identifierType = attr.attributeName.as(IdentifierTypeSyntax.self),
              identifierType.name.trimmedDescription == "DecodableAlias",
              let arguments = attr.arguments?.as(LabeledExprListSyntax.self) else {
            continue
        }
        for arg in arguments {
            if let stringLiteral = arg.expression.as(StringLiteralExprSyntax.self),
               let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
                aliases.append(segment.content.text)
            }
        }
    }
    return aliases
}

func defaultValueExpression(from attributes: AttributeListSyntax) -> String? {
    for attribute in attributes {
        guard let attr = attribute.as(AttributeSyntax.self),
              let identifierType = attr.attributeName.as(IdentifierTypeSyntax.self),
              identifierType.name.trimmedDescription == "CodableDefault",
              let arguments = attr.arguments?.as(LabeledExprListSyntax.self),
              let firstArg = arguments.first else {
            continue
        }
        return firstArg.expression.trimmedDescription
    }
    return nil
}

// MARK: - Coding Fields Generation

/// Unified function for generating coding fields with any expansion kind
func makeCodingFieldsDecl<T: CodingFieldExpansionKind>(
    from properties: [StoredProperty], 
    kind: T
) -> DeclSyntax {
    let cases = (properties.map { "case \($0.name)" } + (kind.includesUnknownCase ? ["case unknown"] : []))
        .joined(separator: "\n        ")

    let switchCases = properties.map {
        "case .\($0.name): \"\($0.key)\""
    } + (kind.includesUnknownCase ? ["case .unknown: fatalError()"] : [])
    let joinedSwitchCases = switchCases.joined(separator: "\n            ")

    if kind.includesKeyLookup {
        let fieldForKeyCases = properties.flatMap { prop -> [String] in
            var cases = ["case \"\(prop.key)\": .\(prop.name)"]
            for alias in prop.aliases {
                cases.append("case \"\(alias)\": .\(prop.name)")
            }
            return cases
        }.joined(separator: "\n            ")

        let defaultCase = kind.includesUnknownCase ? ".unknown" : "throw CodingError.unknownKey(key)"

        return """
        enum CodingFields: \(raw: kind.protocolName) {
            \(raw: cases)

            @_transparent
            var staticString: StaticString {
                switch self {
                \(raw: joinedSwitchCases)
                }
            }

            static func field(for key: UTF8Span) throws(CodingError.Decoding) -> CodingFields {
                switch UTF8SpanComparator(key) {
                \(raw: fieldForKeyCases)
                default: \(raw: defaultCase)
                }
            }
        }
        """
    } else {
        return """
        enum CodingFields: \(raw: kind.protocolName) {
            \(raw: cases)
        
            @_transparent
            var staticString: StaticString {
                switch self {
                \(raw: joinedSwitchCases)
                }
            }
        }
        """
    }
}

// MARK: - Shared Diagnostics

enum SharedMacroDiagnostic: String, DiagnosticMessage {
    case notAStruct
    case codingKeyOnMultipleBindings
    case missingTypeAnnotation

    var message: String {
        switch self {
        case .notAStruct:
            return "This macro can only be applied to structs"
        case .codingKeyOnMultipleBindings:
            return "@CodingKey cannot be applied to a declaration with multiple bindings"
        case .missingTypeAnnotation:
            return "All stored properties must have explicit type annotations"
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "NewCodableMacros", id: rawValue)
    }

    var severity: DiagnosticSeverity { .error }
}

// MARK: - Shared Macro Implementation Patterns

/// Generic implementation for MemberMacro that generates coding fields
func memberMacroExpansion<Field: CodingFieldExpansionKind>(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext,
    generateCodingFields: ([StoredProperty], Field) -> DeclSyntax,
    kind: Field
) -> [DeclSyntax] {
    guard declaration.is(StructDeclSyntax.self) else {
        context.diagnose(.init(
            node: node,
            message: SharedMacroDiagnostic.notAStruct
        ))
        return []
    }

    guard let properties = extractDetailedStoredProperties(from: declaration.memberBlock, in: context) else {
        return []
    }

    if properties.isEmpty {
        return []
    }

    let codingFields = properties.map {
        StoredProperty(name: $0.name, key: $0.key, aliases: $0.aliases)
    }
    return [generateCodingFields(codingFields, kind)]
}

/// Generic implementation for ExtensionMacro that generates decodable extensions
func extensionMacroExpansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext,
    generateExtension: (TokenSyntax, [DetailedStoredProperty]) -> DeclSyntax
) -> [ExtensionDeclSyntax] {
    guard declaration.is(StructDeclSyntax.self) else {
        context.diagnose(.init(
            node: node,
            message: SharedMacroDiagnostic.notAStruct
        ))
        return []
    }

    guard let properties = extractDetailedStoredProperties(from: declaration.memberBlock, in: context) else {
        return []
    }

    // Extract the type name as a TokenSyntax
    let typeName: TokenSyntax
    if let identifierType = type.as(IdentifierTypeSyntax.self) {
        typeName = identifierType.name
    } else {
        // For complex types, we'll use the trimmed description as the identifier
        typeName = TokenSyntax(.identifier(type.trimmedDescription), presence: .present)
    }
    let extensionDecl = generateExtension(typeName, properties)

    guard let ext = extensionDecl.as(ExtensionDeclSyntax.self) else {
        return []
    }

    return [ext]
}
