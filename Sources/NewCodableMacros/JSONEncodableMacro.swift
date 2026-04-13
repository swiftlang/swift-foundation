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

extension JSONEncodableMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard validate(declaration: declaration, for: node, in: context) else {
            return []
        }

        guard let (typeName, properties) = extractTypeNameAndStoredProperties(
            attachedTo: declaration,
            for: node,
            providingExtensionsOf: type,
            in: context) else {
            return []
        }
        
        let codingFields = makeCodingFieldsExtension(for: typeName, from: properties, kind: JSONCodingFieldKind.encodingOnly)
        let impl = self.generateExtension(for: typeName, with: properties)
        return [codingFields, impl].compactMap { $0 }
    }
    
    static func generateExtension(for typeName: TokenSyntax, with properties: [DetailedStoredProperty]) -> ExtensionDeclSyntax? {
        let extensionDecl: DeclSyntax
        if properties.isEmpty {
            extensionDecl = """
            extension \(typeName): JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
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
            extension \(typeName): JSONEncodable {
                func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                    try encoder.encodeStructFields(count: \(raw: fieldCount)) { structEncoder throws(CodingError.Encoding) in
                        \(raw: encodeStatements)
                    }
                }
            }
            """
        }

        return extensionDecl.as(ExtensionDeclSyntax.self)
    }
}

enum JSONEncodableDiagnostic: String, DiagnosticMessage {
    case notAStruct

    var message: String {
        switch self {
        case .notAStruct:
            return "@JSONEncodable can only be applied to structs"
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "NewCodableMacros", id: rawValue)
    }

    var severity: DiagnosticSeverity { .error }
}
