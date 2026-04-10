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

public struct CommonEncodableMacro { }

extension CommonEncodableMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        return memberMacroExpansion(
            of: node,
            providingMembersOf: declaration,
            conformingTo: protocols,
            in: context,
            generateCodingFields: makeCodingFieldsDecl,
            kind: CommonCodingFieldExpansionKind.encodingOnly
        )
    }
}

extension CommonEncodableMacro: ExtensionMacro {
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
            extension \(type.trimmed): CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
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
            extension \(type.trimmed): CommonEncodable {
                func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
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
