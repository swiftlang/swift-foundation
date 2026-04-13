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

extension JSONDecodableMacro: ExtensionMacro {
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
        
        let codingFields = makeCodingFieldsExtension(for: typeName, from: properties, kind: JSONCodingFieldKind.decodingOnly)
        let impl = generateExtension(for: typeName, with: properties)
        return [codingFields, impl].compactMap { $0 }
    }
    
    static func generateExtension(for typeName: TokenSyntax, with properties: [DetailedStoredProperty]) -> ExtensionDeclSyntax? {
        let decl: DeclSyntax
        if properties.isEmpty {
            decl = """
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
        return decl.as(ExtensionDeclSyntax.self)
    }
}
