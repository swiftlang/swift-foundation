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
import SwiftDiagnostics

public struct CommonCodableMacro { }

extension CommonCodableMacro: ExtensionMacro {
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
        let codingFields = makeCodingFieldsExtension(for: typeName, from: properties, kind: CommonCodingFieldExpansionKind.both)
        let encodingImpl = makeEncodableExtension(for: typeName, with: properties, kind: CommonEncodableExpansionKind(), accessLevel: access)
        let decodingImpl = makeDecodableExtension(for: typeName, with: properties, kind: CommonDecodableExpansionKind(), accessLevel: access)
        return [codingFields, encodingImpl, decodingImpl].compactMap { $0 }
    }
}

enum CommonCodingFieldExpansionKind: CodingFieldExpansionKind {
    case encodingOnly
    case decodingOnly
    case both

    var protocolName: String {
        switch self {
        case .encodingOnly:
            return "StaticStringEncodingField"
        case .decodingOnly:
            return "StaticStringDecodingField"
        case .both:
            return "StaticStringCodingField"
        }
    }
}
