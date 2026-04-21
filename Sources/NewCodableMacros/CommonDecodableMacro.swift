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

public struct CommonDecodableMacro { }

extension CommonDecodableMacro: ExtensionMacro {
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
        
        let access = accessLevel(of: declaration)
        let codingFields = makeCodingFieldsExtension(for: typeName, from: properties, kind: CommonCodingFieldExpansionKind.decodingOnly)
        let impl = makeDecodableExtension(for: typeName, with: properties, kind: CommonDecodableExpansionKind(), accessLevel: access)
        return [codingFields, impl].compactMap { $0 }
    }
}

struct CommonDecodableExpansionKind: DecodableExpansionKind {
    var protocolName: String { "CommonDecodable" }
    var decoderType: String { "inout some CommonDecoder & ~Escapable" }
}
