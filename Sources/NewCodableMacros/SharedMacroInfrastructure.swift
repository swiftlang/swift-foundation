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

func extractDetailedStoredProperties(
    from members: MemberBlockSyntax,
    for node: AttributeSyntax,
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
                    message: SharedMacroDiagnostic.missingTypeAnnotation(macroName: node.attributeName.trimmedDescription)
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

// MARK: - Access Level

/// Returns the access-level modifier (with trailing space) that should be applied to
/// members generated inside an extension of `declaration`, or `""` when no modifier is needed.
///
/// Mirrors Swift's synthesized Codable behavior: when the attached type is `public` or `open`,
/// generated members must be `public` to satisfy protocol requirements; `package` types
/// need `package`; `internal`/`fileprivate`/`private` can use the default (empty string).
func accessLevel(of declaration: some DeclGroupSyntax) -> String {
    for modifier in declaration.modifiers {
        switch modifier.name.tokenKind {
        case .keyword(.public), .keyword(.open):
            return "public "
        case .keyword(.package):
            return "package "
        default:
            continue
        }
    }
    return ""
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

/// Unified function for generating coding fields with any expansion kind.
func makeCodingFieldsExtension<T: CodingFieldExpansionKind>(
    for typeName: TokenSyntax,
    from properties: [DetailedStoredProperty],
    kind: T
) -> ExtensionDeclSyntax? {
    if properties.isEmpty {
        return nil
    }
    
    let casesList = properties.map { "case \($0.name)" } + (kind.includesUnknownCase ? ["case unknown"] : [])
    let cases = casesList.joined(separator: "\n")

    let switchCasesList = properties.map {
        "case .\($0.name): \"\($0.key)\""
    } + (kind.includesUnknownCase ? ["case .unknown: fatalError()"] : [])
    let joinedSwitchCases = switchCasesList.joined(separator: "\n")

    let decl: DeclSyntax
    if kind.includesKeyLookup {
        let fieldForKeyCasesList = properties.flatMap { prop -> [String] in
            var cases = ["case \"\(prop.key)\": .\(prop.name)"]
            for alias in prop.aliases {
                cases.append("case \"\(alias)\": .\(prop.name)")
            }
            return cases
        }
        let fieldForKeyCases = fieldForKeyCasesList.joined(separator: "\n")

        let defaultCase = kind.includesUnknownCase ? ".unknown" : "throw CodingError.unknownKey(key)"

        decl = """
        extension \(typeName) {
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
        }
        """
    } else {
        decl = """
        extension \(typeName) {
            enum CodingFields: \(raw: kind.protocolName) {
                \(raw: cases)

                @_transparent
                var staticString: StaticString {
                    switch self {
                    \(raw: joinedSwitchCases)
                    }
                }
            }
        }
        """
    }
    return decl.as(ExtensionDeclSyntax.self)
}

// MARK: - Shared Diagnostics

func validate(declaration: some DeclGroupSyntax, for node: AttributeSyntax, in context: some MacroExpansionContext) -> Bool {
    guard declaration.is(StructDeclSyntax.self) else {
        context.diagnose(.init(
            node: node,
            message: SharedMacroDiagnostic.notAStruct(macroName: node.attributeName.trimmedDescription)
        ))
        return false
    }
    return true
}

enum SharedMacroDiagnostic: DiagnosticMessage {
    case notAStruct(macroName: String)
    case codingKeyOnMultipleBindings
    case missingTypeAnnotation(macroName: String)

    var message: String {
        switch self {
        case .notAStruct(let macroName):
            return "@\(macroName) can only be applied to structs"
        case .codingKeyOnMultipleBindings:
            return "@CodingKey cannot be applied to a declaration with multiple bindings"
        case .missingTypeAnnotation(let macroName):
            return "@\(macroName) requires all stored properties to have explicit type annotations"
        }
    }
    
    var id: String {
        switch self {
        case .notAStruct: "notAStruct"
        case .codingKeyOnMultipleBindings: "codingKeyOnMultipleBindings"
        case .missingTypeAnnotation: "missingTypeAnnotation"
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "NewCodableMacros", id: self.id)
    }

    var severity: DiagnosticSeverity { .error }
}

// MARK: - Encodable Extension Generation

/// Abstracts over the differences between Common and JSON encodable macro expansions
protocol EncodableExpansionKind {
    /// The protocol the generated extension conforms to (e.g. "CommonEncodable", "JSONEncodable")
    var protocolName: String { get }
    
    /// The encoder parameter type in the encode function signature
    var encoderType: String { get }
}

func makeEncodableExtension(
    for typeName: TokenSyntax,
    with properties: [DetailedStoredProperty],
    kind: some EncodableExpansionKind,
    accessLevel: String = ""
) -> ExtensionDeclSyntax? {
    let extensionDecl: DeclSyntax
    if properties.isEmpty {
        extensionDecl = """
        extension \(typeName): \(raw: kind.protocolName) {
            \(raw: accessLevel)func encode(to encoder: \(raw: kind.encoderType)) throws(CodingError.Encoding) {
                try encoder.encodeStructFields(count: 0) { _ throws(CodingError.Encoding) in
                }
            }
        }
        """
    } else {
        let encodeStatements = properties.map {
            "try structEncoder.encode(field: CodingFields.\($0.name), value: self.\($0.name))"
        }.joined(separator: "\n")

        let fieldCount = properties.count

        extensionDecl = """
        extension \(typeName): \(raw: kind.protocolName) {
            \(raw: accessLevel)func encode(to encoder: \(raw: kind.encoderType)) throws(CodingError.Encoding) {
                try encoder.encodeStructFields(count: \(raw: fieldCount)) { structEncoder throws(CodingError.Encoding) in
                    \(raw: encodeStatements)
                }
            }
        }
        """
    }

    return extensionDecl.as(ExtensionDeclSyntax.self)
}

// MARK: - Decodable Extension Generation

/// Abstracts over the differences between Common and JSON decodable macro expansions
protocol DecodableExpansionKind {
    /// The protocol the generated extension conforms to (e.g. "CommonDecodable", "JSONDecodable")
    var protocolName: String { get }
    
    /// The decoder parameter type in the decode function signature
    var decoderType: String { get }
}

func makeDecodableExtension(
    for typeName: TokenSyntax,
    with properties: [DetailedStoredProperty],
    kind: some DecodableExpansionKind,
    accessLevel: String = ""
) -> ExtensionDeclSyntax? {
    let decl: DeclSyntax
    if properties.isEmpty {
        decl = """
        extension \(typeName): \(raw: kind.protocolName) {
            \(raw: accessLevel)static func decode(from decoder: \(raw: kind.decoderType)) throws(CodingError.Decoding) -> \(typeName) {
                try decoder.decodeStruct { _ throws(CodingError.Decoding) in
                    \(typeName)()
                }
            }
        }
        """
    } else {
        let varDeclarations = properties.map {
            "var \($0.name): \($0.typeName)?"
        }.joined(separator: "\n")

        let switchCases = properties.map { prop in
            if prop.isOptional {
                return "case .\(prop.name): \(prop.name) = try valueDecoder.decode(\(prop.typeName)?.self)"
            } else {
                return "case .\(prop.name): \(prop.name) = try valueDecoder.decode(\(prop.typeName).self)"
            }
        }.joined(separator: "\n")

        let requiredProperties = properties.filter { $0.isRequired }

        let guardAndReturn: String
        if requiredProperties.isEmpty {
            let args = properties.map { prop -> String in
                if let defaultExpr = prop.defaultExpr {
                    return "\(prop.name): \(prop.name) ?? \(defaultExpr)"
                }
                return "\(prop.name): \(prop.name)"
            }.joined(separator: ", ")
            guardAndReturn = "return \(typeName)(\(args))"
        } else {
            let requiredFieldGuards = requiredProperties.map {
                """
                guard let \($0.name) else {
                throw CodingError.dataCorrupted(debugDescription: "Missing required field '\($0.key)'")
                }
                """
            }.joined(separator: "\n")
            let args = properties.map { prop -> String in
                if let defaultExpr = prop.defaultExpr {
                    return "\(prop.name): \(prop.name) ?? \(defaultExpr)"
                }
                return "\(prop.name): \(prop.name)"
            }.joined(separator: ", ")
            guardAndReturn = """
            \(requiredFieldGuards)
            return \(typeName)(\(args))
            """
        }

        decl = """
        extension \(typeName): \(raw: kind.protocolName) {
            \(raw: accessLevel)static func decode(from decoder: \(raw: kind.decoderType)) throws(CodingError.Decoding) -> \(typeName) {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    \(raw: varDeclarations)
                    var _codingField: CodingFields?
                    try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                        _codingField = try fieldDecoder.decode(CodingFields.self)
                    } andValue: { valueDecoder throws(CodingError.Decoding) in
                        switch _codingField! {
                        \(raw: switchCases)
                        case .unknown: break
                        }
                    }
                    \(raw: guardAndReturn)
                }
            }
        }
        """
    }

    return decl.as(ExtensionDeclSyntax.self)
}

// MARK: - Shared Macro Implementation Patterns

func extractTypeNameAndStoredProperties(
    attachedTo declaration: some DeclGroupSyntax,
    for node: AttributeSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    in context: some MacroExpansionContext,
) -> (TokenSyntax, [DetailedStoredProperty])? {
    guard let properties = extractDetailedStoredProperties(from: declaration.memberBlock, for: node, in: context) else {
        return nil
    }

    // Extract the type name as a TokenSyntax
    let typeName: TokenSyntax
    if let identifierType = type.as(IdentifierTypeSyntax.self) {
        typeName = identifierType.name
    } else {
        // For complex types, we'll use the trimmed description as the identifier
        typeName = TokenSyntax(.identifier(type.trimmedDescription), presence: .present)
    }
    return (typeName, properties)
}
