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

public struct JSONCodableMacro { }

extension JSONCodableMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        try JSONEncodableMacro.expansion(
            of: node,
            providingMembersOf: declaration,
            conformingTo: protocols,
            in: context
        )
    }
}

extension JSONCodableMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let encodableExtensions = try JSONEncodableMacro.expansion(
            of: node,
            attachedTo: declaration,
            providingExtensionsOf: type,
            conformingTo: protocols,
            in: context
        )
        let decodableExtensions = try JSONDecodableMacro.expansion(
            of: node,
            attachedTo: declaration,
            providingExtensionsOf: type,
            conformingTo: protocols,
            in: context
        )
        return encodableExtensions + decodableExtensions
    }
}
