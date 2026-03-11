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

public struct JSONEncodableMacro { }

private struct StoredProperty {
    let name: String
    let jsonKey: String
}

private func extractStoredProperties(
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
        if customKey != nil && varDecl.bindings.count > 1 {
            context.diagnose(.init(
                node: Syntax(varDecl),
                message: JSONEncodableDiagnostic.codingKeyOnMultipleBindings
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
            let jsonKey = customKey ?? propertyName

            properties.append(StoredProperty(name: propertyName, jsonKey: jsonKey))
        }
    }

    return properties
}

private func customCodingKey(from attributes: AttributeListSyntax) -> String? {
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

extension JSONEncodableMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard declaration.is(StructDeclSyntax.self) else {
            context.diagnose(.init(
                node: node,
                message: JSONEncodableDiagnostic.notAStruct
            ))
            return []
        }

        let properties = extractStoredProperties(from: declaration.memberBlock, in: context)

        if properties.isEmpty {
            return []
        }

        let cases = properties.map { "case \($0.name)" }.joined(separator: "\n        ")

        let switchCases = properties.map {
            "case .\($0.name): \"\($0.jsonKey)\""
        }.joined(separator: "\n            ")

        let fieldForKeyCases = properties.map {
            "case \"\($0.jsonKey)\": .\($0.name)"
        }.joined(separator: "\n            ")

        let enumDecl: DeclSyntax = """
        enum CodingFields: Int, JSONOptimizedCodingField {
            \(raw: cases)

            @_transparent
            var staticString: StaticString {
                switch self {
                \(raw: switchCases)
                }
            }

            static func field(for key: UTF8Span) throws(CodingError.Decoding) -> CodingFields {
                switch UTF8SpanComparator(key) {
                \(raw: fieldForKeyCases)
                default: throw CodingError.unknownKey(key)
                }
            }
        }
        """

        return [enumDecl]
    }
}

extension JSONEncodableMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.is(StructDeclSyntax.self) else {
            return []
        }

        let properties = extractStoredProperties(from: declaration.memberBlock, in: context)

        let extensionDecl: DeclSyntax
        if properties.isEmpty {
            extensionDecl = """
            extension \(type.trimmed): JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: 0) { _ throws(CodingError.Encoding) in }
                }
            }
            """
        } else {
            let encodeStatements = properties.map {
                "try structEncoder.encode(field: CodingFields.\($0.name), value: self.\($0.name))"
            }.joined(separator: "\n            ")

            let fieldCount = properties.count

            extensionDecl = """
            extension \(type.trimmed): JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: \(raw: fieldCount)) { structEncoder throws(CodingError.Encoding) in
                        \(raw: encodeStatements)
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

enum JSONEncodableDiagnostic: String, DiagnosticMessage {
    case notAStruct
    case codingKeyOnMultipleBindings

    var message: String {
        switch self {
        case .notAStruct:
            return "@JSONEncodable can only be applied to structs"
        case .codingKeyOnMultipleBindings:
            return "@CodingKey cannot be applied to a declaration with multiple bindings"
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "NewCodableMacros", id: rawValue)
    }

    var severity: DiagnosticSeverity { .error }
}
