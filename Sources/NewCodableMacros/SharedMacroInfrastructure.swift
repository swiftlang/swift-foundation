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

// MARK: - Shared Data Types

/// Represents a detailed stored property with type information and default values
struct DetailedStoredProperty {
    let name: String
    let key: String
    let aliases: [String]
    let typeName: String
    let isOptional: Bool
    let defaultExpr: String?

    var isRequired: Bool {
        !isOptional && defaultExpr == nil
    }
}

/// Represents an associated value of an enum case
struct EnumCaseAssociatedValue {
    /// The original label from the enum case declaration, or `nil` for unlabeled parameters.
    let label: String?
    /// The label if present, or the positional name (_0, _1, etc.)
    let encodedName: String
    let typeName: String
}

/// Represents a parsed enum case with its associated values
struct EnumCaseInfo {
    let name: String
    let key: String
    let aliases: [String]
    let associatedValues: [EnumCaseAssociatedValue]
    
    var hasAssociatedValues: Bool { !associatedValues.isEmpty }
}

enum CodableExpansionType {
    case encodingOnly
    case decodingOnly
    case both
}

/// Represents the kind of coding fields to generate
protocol CodableExpansion: Equatable {
    
    /// Describes which set of protocol(s) we're expanding.
    var type: CodableExpansionType { get }
    
    /// The access level that the macro should use for codable protocol conformances
    var accessLevel: CodableDeclarationAccessLevel { get }

    /// The name of the field protocol, which will differ depending on whether we're adding just encodable, just decodable, or both.
    var fieldProtocolName: String { get }
    
    /// The encodable/decodable/combined protocol names.
    var encodableProtocolName: String { get }
    var decodableProtocolName: String { get }
    var combinedProtocolName: String { get }
    
    /// The decoder parameter type in the decode function signature (without `inout`)
    var decoderType: String { get }
    
    /// The struct decoder type for per-case decode methods (e.g. "some JSONDictionaryDecoder & ~Escapable")
    var structDecoderType: String { get }
    
    /// The encoder parameter type in the encode function signature (without `inout`)
    var encoderType: String { get }
    
    /// Whether the generated field enum should include key lookup functionality
    var fieldTypeIncludesKeyLookup: Bool { get }
    
    /// Whether the generated field enum should include an "unknown" case
    var fieldTypeIncludesUnknownCase: Bool { get }
}

extension CodableExpansion {
    var fieldTypeIncludesKeyLookup: Bool {
        switch self.type {
        case .encodingOnly: false
        default: true
        }
    }
    
    var fieldTypeIncludesUnknownCase: Bool {
        switch self.type {
        case .encodingOnly: false
        default: true
        }
    }
}

// MARK: - Codable Type Declaration

/// Abstracts over struct and enum declarations for codable macro expansion.
/// Validates the declaration, extracts the relevant data, and provides methods
/// to generate the coding field, encodable, and decodable extensions.
enum CodableTypeDeclaration {
    case structDecl(typeName: TokenSyntax, properties: [DetailedStoredProperty])
    case enumDecl(typeName: TokenSyntax, cases: [EnumCaseInfo])

    init?(
        attachedTo declaration: some DeclGroupSyntax,
        for node: AttributeSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        in context: some MacroExpansionContext
    ) {
        let typeName: TokenSyntax
        if let identifierType = type.as(IdentifierTypeSyntax.self) {
            typeName = identifierType.name
        } else {
            typeName = TokenSyntax(.identifier(type.trimmedDescription), presence: .present)
        }
        
        if declaration.is(EnumDeclSyntax.self) {
            guard let cases = extractEnumCases(from: declaration.memberBlock, for: node, in: context) else {
                return nil
            }
            self = .enumDecl(typeName: typeName, cases: cases)
        } else if declaration.is(StructDeclSyntax.self) {
            guard let properties = extractDetailedStoredProperties(from: declaration.memberBlock, for: node, in: context) else {
                return nil
            }
            self = .structDecl(typeName: typeName, properties: properties)
        } else {
            context.diagnose(.init(
                node: node,
                message: SharedMacroDiagnostic.notAStructOrEnum(macroName: node.attributeName.trimmedDescription)
            ))
            return nil
        }
    }

    func makeCodingFieldsExtension(expansion: some CodableExpansion) -> [ExtensionDeclSyntax] {
        let ext: ExtensionDeclSyntax?
        switch self {
        case .structDecl(let typeName, let properties):
            ext = NewCodableMacros.makeCodingFieldsExtension(for: typeName, from: properties, expansion: expansion)
        case .enumDecl(let typeName, let cases):
            ext = makeEnumCodingFieldsExtension(for: typeName, from: cases, expansion: expansion)
        }
        return [ext].compactMap { $0 }
    }

    func makeEncodableExtension(expansion: some CodableExpansion) -> [ExtensionDeclSyntax] {
        let ext: ExtensionDeclSyntax?
        switch self {
        case .structDecl(let typeName, let properties):
            ext = NewCodableMacros.makeEncodableExtension(for: typeName, with: properties, expansion: expansion)
        case .enumDecl(let typeName, let cases):
            ext = makeEnumEncodableExtension(for: typeName, with: cases, expansion: expansion)
        }
        return [ext].compactMap { $0 }
    }

    func makeDecodableExtension(expansion: some CodableExpansion) -> [ExtensionDeclSyntax] {
        switch self {
        case .structDecl(let typeName, let properties):
            if let ext = NewCodableMacros.makeDecodableExtension(for: typeName, with: properties, expansion: expansion) {
                return [ext]
            }
            return []
        case .enumDecl(let typeName, let cases):
            return makeEnumDecodableExtension(for: typeName, with: cases, expansion: expansion)
        }
    }
}

// MARK: - Shared Property Extraction

func extractDetailedStoredProperties(
    from members: MemberBlockSyntax,
    for node: AttributeSyntax,
    in context: some MacroExpansionContext
) -> [DetailedStoredProperty]? {
    var properties: [DetailedStoredProperty] = []

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
        let defaultExpr = defaultValueExpression(from: varDecl.attributes)
        let aliases = decodableAliases(from: varDecl.attributes)
        if (customKey != nil || defaultExpr != nil || !aliases.isEmpty) && varDecl.bindings.count > 1 {
            context.diagnose(.init(
                node: Syntax(varDecl),
                message: SharedMacroDiagnostic.codingKeyOnMultipleBindings
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
                    message: SharedMacroDiagnostic.missingTypeAnnotation(macroName: node.attributeName.trimmedDescription)
                ))
                return nil
            }

            let propertyName = pattern.identifier.trimmedDescription
            let key = customKey ?? propertyName

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

            properties.append(DetailedStoredProperty(
                name: propertyName,
                key: key,
                aliases: aliases,
                typeName: typeName,
                isOptional: isOptional,
                defaultExpr: defaultExpr
            ))
        }
    }

    return properties
}

// MARK: - Access Level

enum CodableDeclarationAccessLevel {
    case `public`
    case `package`
    case unspecified
    
    var inlineDeclPrefix: String {
        switch self {
        case .public: "public "
        case .package: "package "
        case .unspecified: ""
        }
    }
}

/// Returns the access-level modifier (with trailing space) that should be applied to
/// members generated inside an extension of `declaration`, or `""` when no modifier is needed.
func accessLevel(of declaration: some DeclGroupSyntax) -> CodableDeclarationAccessLevel {
    for modifier in declaration.modifiers {
        switch modifier.name.tokenKind {
        case .keyword(.public), .keyword(.open):
            return .public
        case .keyword(.package):
            return .package
        default:
            continue
        }
    }
    return .unspecified
}

// MARK: - Enum Case Extraction

func extractEnumCases(
    from members: MemberBlockSyntax,
    for node: AttributeSyntax,
    in context: some MacroExpansionContext
) -> [EnumCaseInfo]? {
    var cases: [EnumCaseInfo] = []

    for member in members.members {
        guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else {
            continue
        }

        let customKey = customCodingKey(from: caseDecl.attributes)
        let aliases = decodableAliases(from: caseDecl.attributes)

        for element in caseDecl.elements {
            let caseName = element.name.trimmedDescription
            let key = customKey ?? caseName
            var parameters: [EnumCaseAssociatedValue] = []

            if let paramClause = element.parameterClause {
                for (index, param) in paramClause.parameters.enumerated() {
                    var label = param.firstName?.trimmedDescription
                    if label == "_" { label = nil }
                    let encodedName = label ?? "_\(index)"
                    let typeName = param.type.trimmedDescription
                    parameters.append(EnumCaseAssociatedValue(label: label, encodedName: encodedName, typeName: typeName))
                }
            }

            cases.append(EnumCaseInfo(name: caseName, key: key, aliases: aliases, associatedValues: parameters))
        }
    }

    return cases
}

// MARK: - Attribute Parsing Utilities

func customCodingKey(from attributes: AttributeListSyntax) -> String? {
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

func decodableAliases(from attributes: AttributeListSyntax) -> [String] {
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

func defaultValueExpression(from attributes: AttributeListSyntax) -> String? {
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

// MARK: - Coding Fields Generation

/// Unified function for generating coding fields with any expansion kind
func makeCodingFieldsExtension (
    for typeName: TokenSyntax,
    from properties: [DetailedStoredProperty],
    expansion: some CodableExpansion
) -> ExtensionDeclSyntax? {
    if properties.isEmpty {
        return nil
    }
    
    let casesList = properties.map { "case \($0.name)" } + (expansion.fieldTypeIncludesUnknownCase ? ["case unknown"] : [])
    let cases = casesList.joined(separator: "\n")

    let switchCasesList = properties.map {
        "case .\($0.name): \"\($0.key)\""
    } + (expansion.fieldTypeIncludesUnknownCase ? ["case .unknown: fatalError()"] : [])
    let joinedSwitchCases = switchCasesList.joined(separator: "\n")

    let decl: DeclSyntax
    if expansion.fieldTypeIncludesKeyLookup {
        let fieldForKeyCasesList = properties.flatMap { prop -> [String] in
            var cases = ["case \"\(prop.key)\": .\(prop.name)"]
            for alias in prop.aliases {
                cases.append("case \"\(alias)\": .\(prop.name)")
            }
            return cases
        }
        let fieldForKeyCases = fieldForKeyCasesList.joined(separator: "\n")

        let defaultCase = expansion.fieldTypeIncludesUnknownCase ? ".unknown" : "throw CodingError.unknownKey(key)"

        decl = """
        extension \(typeName) {
            enum CodingFields: \(raw: expansion.fieldProtocolName) {
                \(raw: cases)

                @_transparent
                var staticString: StaticString {
                    switch self {
                    \(raw: joinedSwitchCases)
                    }
                }

                static func field(for key: UTF8Span) throws(CodingError.Decoding) -> CodingFields {
                    switch UTF8SpanComparator(key) {
                    \(raw: fieldForKeyCases)
                    default:
                        \(raw: defaultCase)
                    }
                }
            }
        }
        """
    } else {
        decl = """
        extension \(typeName) {
            enum CodingFields: \(raw: expansion.fieldProtocolName) {
                \(raw: cases)

                @_transparent
                var staticString: StaticString {
                    switch self {
                    \(raw: joinedSwitchCases)
                    }
                }
            }
        }
        """
    }
    return decl.as(ExtensionDeclSyntax.self)
}

// MARK: - Shared Diagnostics

enum SharedMacroDiagnostic: DiagnosticMessage {
    case notAStructOrEnum(macroName: String)
    case codingKeyOnMultipleBindings
    case missingTypeAnnotation(macroName: String)

    var message: String {
        switch self {
        case .notAStructOrEnum(let macroName):
            return "@\(macroName) can only be applied to structs or enums"
        case .codingKeyOnMultipleBindings:
            return "@CodingKey cannot be applied to a declaration with multiple bindings"
        case .missingTypeAnnotation(let macroName):
            return "@\(macroName) requires all stored properties to have explicit type annotations"
        }
    }
    
    var id: String {
        switch self {
        case .notAStructOrEnum: "notAStructOrEnum"
        case .codingKeyOnMultipleBindings: "codingKeyOnMultipleBindings"
        case .missingTypeAnnotation: "missingTypeAnnotation"
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "NewCodableMacros", id: self.id)
    }

    var severity: DiagnosticSeverity { .error }
}

// MARK: - Encodable Extension Generation

func makeEncodableExtension(
    for typeName: TokenSyntax,
    with properties: [DetailedStoredProperty],
    expansion: some CodableExpansion
) -> ExtensionDeclSyntax? {
    let accessLevelPrefix = expansion.accessLevel.inlineDeclPrefix
    let extensionDecl: DeclSyntax
    if properties.isEmpty {
        extensionDecl = """
        extension \(typeName): \(raw: expansion.encodableProtocolName) {
            \(raw: accessLevelPrefix)func encode(to encoder: inout \(raw: expansion.encoderType)) throws(CodingError.Encoding) {
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
        extension \(typeName): \(raw: expansion.encodableProtocolName) {
            \(raw: accessLevelPrefix)func encode(to encoder: inout \(raw: expansion.encoderType)) throws(CodingError.Encoding) {
                try encoder.encodeStructFields(count: \(raw: fieldCount)) { structEncoder throws(CodingError.Encoding) in
                    \(raw: encodeStatements)
                }
            }
        }
        """
    }

    return extensionDecl.as(ExtensionDeclSyntax.self)
}

// MARK: - Decodable Extension Generation

func makeDecodableExtension(
    for typeName: TokenSyntax,
    with properties: [DetailedStoredProperty],
    expansion: some CodableExpansion
) -> ExtensionDeclSyntax? {
    let accessLevelPrefix = expansion.accessLevel.inlineDeclPrefix
    let decl: DeclSyntax
    if properties.isEmpty {
        decl = """
        extension \(typeName): \(raw: expansion.decodableProtocolName) {
            \(raw: accessLevelPrefix)static func decode(from decoder: inout \(raw: expansion.decoderType)) throws(CodingError.Decoding) -> \(typeName) {
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
        extension \(typeName): \(raw: expansion.decodableProtocolName) {
            \(raw: accessLevelPrefix)static func decode(from decoder: inout \(raw: expansion.decoderType)) throws(CodingError.Decoding) -> \(typeName) {
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

// MARK: - Enum Coding Fields Generation

/// Generates the CodingFields enum extension for an enum type's case names,
/// along with per-case field enums for cases with associated values.
func makeEnumCodingFieldsExtension(
    for typeName: TokenSyntax,
    from cases: [EnumCaseInfo],
    expansion: some CodableExpansion,
) -> ExtensionDeclSyntax? {
    if cases.isEmpty {
        return nil
    }

    let casesList = cases.map { "case \($0.name)" }
    let joinedCases = casesList.joined(separator: "\n")

    let switchCasesList = cases.map {
        "case .\($0.name): \"\($0.key)\""
    }
    let joinedSwitchCases = switchCasesList.joined(separator: "\n")

    // Generate per-case field enums for cases with associated values
    let casesWithAssociatedValues = cases.filter { $0.hasAssociatedValues }
    let perCaseFieldEnums = casesWithAssociatedValues.map { enumCase -> String in
        let fieldsEnumName = "\(capitalizedCaseName(enumCase.name))Fields"
        let fieldCases = enumCase.associatedValues.map { "case \($0.encodedName)" }.joined(separator: "\n")
        let fieldSwitchCases = enumCase.associatedValues.map {
            "case .\($0.encodedName): \"\($0.encodedName)\""
        }.joined(separator: "\n")

        let decodeSection: String
        if expansion.type != .encodingOnly {
            let varDeclarations = enumCase.associatedValues.map {
                "var \($0.encodedName): \($0.typeName)?"
            }.joined(separator: "\n        ")

            let decodeSwitchCases = enumCase.associatedValues.map {
                "case .\($0.encodedName): \($0.encodedName) = try valueDecoder.decode(\($0.typeName).self)"
            }.joined(separator: "\n            ")

            let guardLetNames = enumCase.associatedValues.map { "let \($0.encodedName)" }.joined(separator: ", ")

            let args = enumCase.associatedValues.map { param -> String in
                if param.label != nil {
                    return "\(param.encodedName): \(param.encodedName)"
                } else {
                    return "\(param.encodedName)"
                }
            }.joined(separator: ", ")

            decodeSection = """


                static func decode(from decoder: inout \(expansion.structDecoderType)) throws(CodingError.Decoding) -> \(typeName) {
                    \(varDeclarations)
                    var _field: \(fieldsEnumName)?
                    try decoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                        _field = try fieldDecoder.decode(\(fieldsEnumName).self)
                    } andValue: { valueDecoder throws(CodingError.Decoding) in
                        switch _field! {
                        \(decodeSwitchCases)
                        }
                    }
                    guard \(guardLetNames) else {
                        throw CodingError.dataCorrupted(debugDescription: "Missing required fields")
                    }
                    return .\(enumCase.name)(\(args))
                }
            """
        } else {
            decodeSection = ""
        }

        if expansion.fieldTypeIncludesKeyLookup {
            let fieldForKeyCases = enumCase.associatedValues.map {
                "case \"\($0.encodedName)\": .\($0.encodedName)"
            }.joined(separator: "\n")

            return """
            enum \(fieldsEnumName): \(expansion.fieldProtocolName) {
                \(fieldCases)

                @_transparent
                var staticString: StaticString {
                    switch self {
                    \(fieldSwitchCases)
                    }
                }

                static func field(for key: UTF8Span) throws(CodingError.Decoding) -> \(fieldsEnumName) {
                    switch UTF8SpanComparator(key) {
                    \(fieldForKeyCases)
                    default:
                        throw CodingError.unknownKey(key)
                    }
                }\(decodeSection)
            }
            """
        } else {
            return """
            enum \(fieldsEnumName): \(expansion.fieldProtocolName) {
                \(fieldCases)

                @_transparent
                var staticString: StaticString {
                    switch self {
                    \(fieldSwitchCases)
                    }
                }\(decodeSection)
            }
            """
        }
    }.joined(separator: "\n\n")

    let perCaseSection = perCaseFieldEnums.isEmpty ? "" : "\n\n\(perCaseFieldEnums)"

    let decl: DeclSyntax
    if expansion.fieldTypeIncludesKeyLookup {
        let fieldForKeyCasesList = cases.flatMap { c -> [String] in
            var entries = ["case \"\(c.key)\": .\(c.name)"]
            for alias in c.aliases {
                entries.append("case \"\(alias)\": .\(c.name)")
            }
            return entries
        }
        let fieldForKeyCases = fieldForKeyCasesList.joined(separator: "\n")

        decl = """
        extension \(typeName) {
        enum CodingFields: \(raw: expansion.fieldProtocolName) {
        \(raw: joinedCases)

        @_transparent
        var staticString: StaticString {
            switch self {
            \(raw: joinedSwitchCases)
            }
        }

        static func field(for key: UTF8Span) throws(CodingError.Decoding) -> CodingFields {
            switch UTF8SpanComparator(key) {
            \(raw: fieldForKeyCases)
            default:
                throw CodingError.unknownKey(key)
            }
        }\(raw: perCaseSection)
        }
        }
        """
    } else {
        decl = """
        extension \(typeName) {
        enum CodingFields: \(raw: expansion.fieldProtocolName) {
        \(raw: joinedCases)

        @_transparent
        var staticString: StaticString {
            switch self {
            \(raw: joinedSwitchCases)
            }
        }\(raw: perCaseSection)
        }
        }
        """
    }
    return decl.as(ExtensionDeclSyntax.self)
}

// MARK: - Enum Encodable Extension Generation

/// Capitalizes the first character of a string for use as an enum name
private func capitalizedCaseName(_ name: String) -> String {
    guard let first = name.first else { return name }
    return String(first).uppercased() + name.dropFirst()
}

func makeEnumEncodableExtension(
    for typeName: TokenSyntax,
    with cases: [EnumCaseInfo],
    expansion: some CodableExpansion
) -> ExtensionDeclSyntax? {
    let switchCases: String
    if cases.isEmpty {
        // Empty enum - no cases to encode
        switchCases = ""
    } else {
        switchCases = cases.map { enumCase -> String in
            if enumCase.associatedValues.isEmpty {
                return "case .\(enumCase.name):\ntry encoder.encodeEnumCase(CodingFields.\(enumCase.name))"
            } else {
                let bindings = enumCase.associatedValues.map { "let \($0.encodedName)" }.joined(separator: ", ")
                let fieldsEnumName = "CodingFields.\(capitalizedCaseName(enumCase.name))Fields"

                let encodeStatements = enumCase.associatedValues.map {
                    "try valueEncoder.encode(field: \(fieldsEnumName).\($0.encodedName), value: \($0.encodedName))"
                }.joined(separator: "\n")

                return """
                case .\(enumCase.name)(\(bindings)):
                try encoder.encodeEnumCase(CodingFields.\(enumCase.name), associatedValueCount: \(enumCase.associatedValues.count)) { valueEncoder throws(CodingError.Encoding) in
                \(encodeStatements)
                }
                """
            }
        }.joined(separator: "\n")
    }

    let body: String
    if cases.isEmpty {
        body = ""
    } else {
        body = """
        switch self {
        \(switchCases)
        }
        """
    }

    let extensionDecl: DeclSyntax = """
    extension \(typeName): \(raw: expansion.encodableProtocolName) {
        func encode(to encoder: inout \(raw: expansion.encoderType)) throws(CodingError.Encoding) {
            \(raw: body)
        }
    }
    """

    return extensionDecl.as(ExtensionDeclSyntax.self)
}

// MARK: - Enum Decodable Extension Generation

func makeEnumDecodableExtension(
    for typeName: TokenSyntax,
    with cases: [EnumCaseInfo],
    expansion: some CodableExpansion
) -> [ExtensionDeclSyntax] {
    // Generate the main decode method
    let mainDecl: DeclSyntax
    if cases.isEmpty {
        mainDecl = """
        extension \(typeName): \(raw: expansion.decodableProtocolName) {
            static func decode(from decoder: inout \(raw: expansion.decoderType)) throws(CodingError.Decoding) -> \(typeName) {
                throw CodingError.dataCorrupted(debugDescription: "Cannot decode empty enum")
            }
        }
        """
    } else {
        // Cases with associated values delegate to per-case decode methods on nested field enums.
        // Cases without associated values just return the case directly.
        let caseDecodeStatements = cases.map { enumCase -> String in
            if enumCase.hasAssociatedValues {
                let fieldsEnumName = "CodingFields.\(capitalizedCaseName(enumCase.name))Fields"
                return "case .\(enumCase.name): try \(fieldsEnumName).decode(from: &valuesDecoder)"
            } else {
                return "case .\(enumCase.name): .\(enumCase.name)"
            }
        }.joined(separator: "\n")

        mainDecl = """
        extension \(typeName): \(raw: expansion.decodableProtocolName) {
            static func decode(from decoder: inout \(raw: expansion.decoderType)) throws(CodingError.Decoding) -> \(typeName) {
                var _codingField: CodingFields?
                return try decoder.decodeEnumCase { fieldDecoder throws(CodingError.Decoding) in
                    _codingField = try fieldDecoder.decode(CodingFields.self)
                } associatedValues: { valuesDecoder throws(CodingError.Decoding) in
                    return switch _codingField! {
                    \(raw: caseDecodeStatements)
                    }
                }
            }
        }
        """
    }

    if let mainExtDecl = mainDecl.as(ExtensionDeclSyntax.self) {
        return [mainExtDecl]
    }
    return []
}


