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

public struct JSONCodableMacro { }

extension JSONCodableMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let typeDecl = CodableTypeDeclaration(
            attachedTo: declaration,
            for: node,
            providingExtensionsOf: type,
            in: context) else {
            return []
        }
        
        let expansion = JSONCodableExpanion(type: .both, accessLevel: accessLevel(of: declaration))
        let codingFields = typeDecl.makeCodingFieldsExtension(expansion: expansion)
        let encodingImpl = typeDecl.makeEncodableExtension(expansion: expansion)
        let decodingImpl = typeDecl.makeDecodableExtension(expansion: expansion)
        return codingFields + encodingImpl + decodingImpl
    }
}

struct JSONCodableExpanion: CodableExpansion {
    let type: CodableExpansionType
    let accessLevel: CodableDeclarationAccessLevel
    
    var fieldProtocolName: String {
        switch type {
        case .encodingOnly: "JSONOptimizedEncodingField"
        case .decodingOnly: "JSONOptimizedDecodingField"
        case .both: "JSONOptimizedCodingField"
        }
    }
    
    let fieldTypeName = "JSONCodingFields"
    let encodableProtocolName = "JSONEncodable"
    let decodableProtocolName = "JSONDecodable"
    let combinedProtocolName = "JSONCodable"

    let decoderType = "some JSONDecoderProtocol & ~Escapable"
    let structDecoderType = "some JSONDictionaryDecoder & ~Escapable"
    
    let encoderType = "JSONDirectEncoder"
}
