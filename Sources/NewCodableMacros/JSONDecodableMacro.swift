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

public struct JSONDecodableMacro { }

private struct DecodableStoredProperty {
    let name: String
    let jsonKey: String
    let aliases: [String]
    let typeName: String
    let isOptional: Bool
    let defaultExpr: String?

    var isRequired: Bool {
        !isOptional && defaultExpr == nil
    }
}

private func extractDecodableStoredProperties(
    from members: MemberBlockSyntax,
    in context: some MacroExpansionContext
) -> [DecodableStoredProperty]? {
    var properties: [DecodableStoredProperty] = []

    for member in members.members {
        guard let varDecl = member.decl.as(VariableDeclSyntax.self) else {
            continue
        }

        if varDecl.modifiers.contains(where: {
            $0.name.tokenKind == .keyword(.static) || $0.name.tokenKind == .keyword(.lazy)
        }) {
            continue
        }

        let customKey = decodableCustomCodingKey(from: varDecl.attributes)
        let defaultExpr = decodableDefaultExpression(from: varDecl.attributes)
        let aliases = decodableAliases(from: varDecl.attributes)
        if (customKey != nil || defaultExpr != nil || !aliases.isEmpty) && varDecl.bindings.count > 1 {
            context.diagnose(.init(
                node: Syntax(varDecl),
                message: JSONDecodableDiagnostic.codingKeyOnMultipleBindings
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
                    message: JSONDecodableDiagnostic.missingTypeAnnotation
                ))
                return nil
            }

            let propertyName = pattern.identifier.trimmedDescription
            let jsonKey = customKey ?? propertyName

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

            properties.append(DecodableStoredProperty(
                name: propertyName,
                jsonKey: jsonKey,
                aliases: aliases,
                typeName: typeName,
                isOptional: isOptional,
                defaultExpr: defaultExpr
            ))
        }
    }

    return properties
}

private func decodableDefaultExpression(from attributes: AttributeListSyntax) -> String? {
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

private func decodableCustomCodingKey(from attributes: AttributeListSyntax) -> String? {
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

private func decodableAliases(from attributes: AttributeListSyntax) -> [String] {
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

extension JSONDecodableMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard declaration.is(StructDeclSyntax.self) else {
            context.diagnose(.init(
                node: node,
                message: JSONDecodableDiagnostic.notAStruct
            ))
            return []
        }

        guard let properties = extractDecodableStoredProperties(from: declaration.memberBlock, in: context) else {
            return []
        }

        if properties.isEmpty {
            return []
        }

        let codingFields = properties.map {
            StoredProperty(name: $0.name, jsonKey: $0.jsonKey, aliases: $0.aliases)
        }
        return [makeCodingFieldsDecl(from: codingFields, kind: .decodingOnly)]
    }
}

extension JSONDecodableMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.is(StructDeclSyntax.self) else {
            context.diagnose(.init(
                node: node,
                message: JSONDecodableDiagnostic.notAStruct
            ))
            return []
        }

        guard let properties = extractDecodableStoredProperties(from: declaration.memberBlock, in: context) else {
            return []
        }

        let typeName = type.trimmed

        let extensionDecl: DeclSyntax
        if properties.isEmpty {
            extensionDecl = """
            extension \(typeName): JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> \(typeName) {
                    try decoder.decodeStruct { _ throws(CodingError.Decoding) in
                        \(typeName)()
                    }
                }
            }
            """
        } else {
            let varDeclarations = properties.map {
                "var \($0.name): \($0.typeName)?"
            }.joined(separator: "\n            ")

            let switchCases = properties.map { prop in
                if prop.isOptional {
                    return "case .\(prop.name): \(prop.name) = try valueDecoder.decode(\(prop.typeName)?.self)"
                } else {
                    return "case .\(prop.name): \(prop.name) = try valueDecoder.decode(\(prop.typeName).self)"
                }
            }.joined(separator: "\n                            ")

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
                                throw CodingError.dataCorrupted(debugDescription: "Missing required field '\($0.jsonKey)'")
                            }
                    """
                }.joined(separator: "\n                        ")
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

            extensionDecl = """
            extension \(typeName): JSONDecodable {
                static func decode(from decoder: inout some JSONDecoderProtocol & ~Escapable) throws(CodingError.Decoding) -> \(typeName) {
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

        guard let ext = extensionDecl.as(ExtensionDeclSyntax.self) else {
            return []
        }

        return [ext]
    }
}

enum JSONDecodableDiagnostic: String, DiagnosticMessage {
    case notAStruct
    case codingKeyOnMultipleBindings
    case missingTypeAnnotation

    var message: String {
        switch self {
        case .notAStruct:
            return "@JSONDecodable can only be applied to structs"
        case .codingKeyOnMultipleBindings:
            return "@CodingKey cannot be applied to a declaration with multiple bindings"
        case .missingTypeAnnotation:
            return "@JSONDecodable requires all stored properties to have explicit type annotations"
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "NewCodableMacros", id: rawValue)
    }

    var severity: DiagnosticSeverity { .error }
}
