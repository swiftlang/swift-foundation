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
        guard let typeDecl = CodableTypeDeclaration(
            attachedTo: declaration,
            for: node,
            providingExtensionsOf: type,
            in: context) else {
            return []
        }
        
        let expansion = CommonCodableExpansion(type: .both, accessLevel: accessLevel(of: declaration))
        let codingFields = typeDecl.makeCodingFieldsExtension(expansion: expansion)
        let encodingImpl = typeDecl.makeEncodableExtension(expansion: expansion)
        let decodingImpl = typeDecl.makeDecodableExtension(expansion: expansion)
        return codingFields + encodingImpl + decodingImpl
    }
}

struct CommonCodableExpansion: CodableExpansion {
    let type: CodableExpansionType
    let accessLevel: CodableDeclarationAccessLevel
    
    var fieldProtocolName: String {
        switch type {
        case .encodingOnly: "StaticStringEncodingField"
        case .decodingOnly: "StaticStringDecodingField"
        case .both: "StaticStringCodingField"
        }
    }
    
    let fieldTypeName = "CommonCodingFields"
    let encodableProtocolName = "CommonEncodable"
    let decodableProtocolName = "CommonDecodable"
    let combinedProtocolName = "CommonCodable"
    
    let decoderType = "some CommonDecoder & ~Escapable"
    let structDecoderType = "some CommonStructDecoder & ~Escapable"
    
    let encoderType = "some CommonEncoder & ~Copyable & ~Escapable"
}
