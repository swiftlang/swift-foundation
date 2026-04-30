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
    
    /// Whether the generated field enum should include key lookup functionality
    var requiresCodingFieldLookup: Bool {
        switch self {
        case .encodingOnly: false
        default: true
        }
    }

    /// Whether the generated field enum should include an "unknown" case by default
    var defaultCodingFieldIncludesUnknownCase: Bool {
        switch self {
        case .encodingOnly: false
        default: true
        }
    }
}

/// Represents the kind of coding fields to generate
protocol CodableExpansion: Equatable {

    /// Describes which set of protocol(s) we're expanding.
    var type: CodableExpansionType { get }

    /// The access level that the macro should use for codable protocol conformances
    var accessLevel: CodableDeclarationAccessLevel { get }

    /// The encodable/decodable/combined protocol names.
    var encodableProtocolName: String { get }
    var decodableProtocolName: String { get }
    var combinedProtocolName: String { get }
    
    /// The protocol names to use for CodingFields
    var encodableFieldProtocolName: String { get }
    var decodableFieldProtocolName: String { get }
    var combinedFieldProtocolName: String { get }

    /// The name of the generated CodingFields type used in encode/decode references.
    var fieldTypeName: String { get }

    /// Whether the generated field enum should include an "unknown" case
    func fieldTypeIncludesUnknownCase(withExpansionTypeOverride: CodableExpansionType?) -> Bool

    /// The decoder parameter type in the decode function signature (without `inout`)
    var decoderType: String { get }

    /// The struct decoder type for per-case decode methods (e.g. "some JSONDictionaryDecoder & ~Escapable")
    var structDecoderType: String { get }

    /// The encoder parameter type in the encode function signature (without `inout`)
    var encoderType: String { get }
}

extension CodableExpansion {
    var ownMacroNames: Set<String> {
        [combinedProtocolName, encodableProtocolName, decodableProtocolName]
    }
    
    func protocolName(for type: CodableExpansionType) -> String {
        switch type {
        case .both: combinedProtocolName
        case .encodingOnly: encodableProtocolName
        case .decodingOnly: decodableProtocolName
        }
    }
    
    var currentProtocolName: String {
        protocolName(for: self.type)
    }
    
    func combinesIntoBidirectionalCodable(with otherProtocolName: String) -> Bool {
        if type == .both || otherProtocolName == combinedProtocolName {
            return true
        }
        return switch (currentProtocolName, otherProtocolName) {
        case (encodableProtocolName, decodableProtocolName), (decodableProtocolName, encodableProtocolName): true
        default: false
        }
    }
    
    func fieldTypeProtocolName(forExpansionType expansionType: CodableExpansionType) -> String {
        switch expansionType {
        case .encodingOnly: encodableFieldProtocolName
        case .decodingOnly: decodableFieldProtocolName
        case .both: combinedFieldProtocolName
        }
    }
    func fieldTypeIncludesUnknownCase() -> Bool {
        self.fieldTypeIncludesUnknownCase(withExpansionTypeOverride: nil)
    }
    
    func fieldTypeIncludesUnknownCase(withExpansionTypeOverride override: CodableExpansionType?) -> Bool {
        (override ?? self.type).defaultCodingFieldIncludesUnknownCase
    }
}

// MARK: - Peer Macro Detection

/// Returns true if the given attribute name looks like a codable macro
/// (ends in "Codable", "Encodable", or "Decodable").
private func isCodableMacroName(_ name: String) -> Bool {
    name.hasSuffix("Codable") || name.hasSuffix("Encodable") || name.hasSuffix("Decodable")
}

/// Encapsulates the results of peer macro detection for a codable macro expansion.
struct PeerMacroInfo {
    /// Whether a codable macro from a DIFFERENT format is present (e.g. @CommonCodable on a @JSONCodable type).
    let multiFormat: Bool
    /// Whether this macro is the first codable macro attribute lexically on the declaration.
    let isFirst: Bool
    /// When there are matched peer macros (e.g. @JSONDecodable alongside @JSONEncodable), this overrides the default expansion for the field types to .both
    let codingFieldsExpansionOverride: CodableExpansionType?
}

/// Computes all peer macro detection info for the given node, declaration, and expansion.
func detectPeerMacros(
    node: AttributeSyntax,
    declaration: some DeclGroupSyntax,
    expansion: some CodableExpansion
) -> PeerMacroInfo {
    let nodeId = node.attributeName.as(IdentifierTypeSyntax.self)
    let nodeName = nodeId?.name.text

    var multiFormat = false
    var isFirst = true
    var hasSameFormatPeer = false
    var foundFirstCodable = false

    for element in declaration.attributes {
        guard let attr = element.as(AttributeSyntax.self),
              let id = attr.attributeName.as(IdentifierTypeSyntax.self) else { continue }
        let name = id.name.text

        guard isCodableMacroName(name) else { continue }

        // Different-format peer detection
        if !expansion.ownMacroNames.contains(name) {
            multiFormat = true
        }

        // isFirst: is our node the first codable macro?
        if !foundFirstCodable {
            foundFirstCodable = true
            if name != nodeName {
                isFirst = false
            }
        }

        // Same-format peer detection (only relevant for non-.both expansions)
        if expansion.type != .both && expansion.combinesIntoBidirectionalCodable(with: name) {
            hasSameFormatPeer = true
        }
    }

    return PeerMacroInfo(
        multiFormat: multiFormat,
        isFirst: isFirst,
        codingFieldsExpansionOverride: hasSameFormatPeer ? .both : nil
    )
}

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

    func makeCodingFieldsExtension(expansion: some CodableExpansion, peers: PeerMacroInfo) -> [ExtensionDeclSyntax] {
        switch self {
        case .structDecl(let typeName, let properties):
            return NewCodableMacros.makeCodingFieldsExtension(for: typeName, from: properties, expansion: expansion, peers: peers)
        case .enumDecl(let typeName, let cases):
            return makeEnumCodingFieldsExtension(for: typeName, from: cases, expansion: expansion, peers: peers)
        }
    }

    func makeEncodableExtension(expansion: some CodableExpansion, peers: PeerMacroInfo) -> [ExtensionDeclSyntax] {
        let ext: ExtensionDeclSyntax?
        switch self {
        case .structDecl(let typeName, let properties):
            ext = NewCodableMacros.makeEncodableExtension(for: typeName, with: properties, expansion: expansion, hasPeer: peers.multiFormat)
        case .enumDecl(let typeName, let cases):
            ext = makeEnumEncodableExtension(for: typeName, with: cases, expansion: expansion, hasPeer: peers.multiFormat)
        }
        return [ext].compactMap { $0 }
    }

    func makeDecodableExtension(expansion: some CodableExpansion, peers: PeerMacroInfo) -> [ExtensionDeclSyntax] {
        switch self {
        case .structDecl(let typeName, let properties):
            if let ext = NewCodableMacros.makeDecodableExtension(for: typeName, with: properties, expansion: expansion, hasPeer: peers.multiFormat) {
                return [ext]
            }
            return []
        case .enumDecl(let typeName, let cases):
            return makeEnumDecodableExtension(for: typeName, with: cases, expansion: expansion, hasPeer: peers.multiFormat)
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

/// Unified function for generating coding fields with any expansion kind.
/// When `peers.multiFormat` is true and `peers.isFirst` is true, generates a base CodingFields enum + wrapper struct.
/// When `peers.multiFormat` is true and `peers.isFirst` is false, generates only the wrapper struct.
/// When `peers.multiFormat` is false, generates the current format-specific enum directly.
func makeCodingFieldsExtension(
    for typeName: TokenSyntax,
    from properties: [DetailedStoredProperty],
    expansion: some CodableExpansion,
    peers: PeerMacroInfo
) -> [ExtensionDeclSyntax] {
    if properties.isEmpty {
        return []
    }

    if !peers.multiFormat {
        // Single macro (or same-format pair): only the first generates fields.
        if !peers.isFirst {
            return []
        }
        // Generate format-specific enum directly.
        if let ext = makeSingleFormatCodingFieldsEnum(for: typeName, from: properties, expansion: expansion, codingFieldsExpansionOverride: peers.codingFieldsExpansionOverride) {
            return [ext]
        }
        return []
    }

    // Dual macro (different format): generate base + wrapper
    var results: [ExtensionDeclSyntax] = []

    if peers.isFirst {
        if let base = makeBaseCodingFieldsEnum(for: typeName, from: properties, expansion: expansion) {
            results.append(base)
        }
    }

    if let wrapper = makeWrapperFieldsStruct(for: typeName, from: properties, expansion: expansion) {
        results.append(wrapper)
    }

    return results
}

/// Generates the original format-specific enum (used when no peer macro is present).
/// When `codingFieldsExpansionOverride` is `.both`, generates as if this were a bidirectional expansion
/// (includes unknown case, key lookup, and combined protocol conformance).
/// This handles the case where @JSONEncodable + @JSONDecodable are used together.
private func makeSingleFormatCodingFieldsEnum(
    for typeName: TokenSyntax,
    from properties: [DetailedStoredProperty],
    expansion: some CodableExpansion,
    codingFieldsExpansionOverride: CodableExpansionType? = nil
) -> ExtensionDeclSyntax? {
    let includesUnknown = expansion.fieldTypeIncludesUnknownCase(withExpansionTypeOverride: codingFieldsExpansionOverride)
    let effectiveFieldExpansionType = codingFieldsExpansionOverride ?? expansion.type
    let includesKeyLookup = effectiveFieldExpansionType.requiresCodingFieldLookup
    let protocolName = expansion.fieldTypeProtocolName(forExpansionType: effectiveFieldExpansionType)

    let casesList = properties.map { "case \($0.name)" } + (includesUnknown ? ["case unknown"] : [])
    let cases = casesList.joined(separator: "\n")

    let switchCasesList = properties.map {
        "case .\($0.name): \"\($0.key)\""
    } + (includesUnknown ? ["case .unknown: fatalError()"] : [])
    let joinedSwitchCases = switchCasesList.joined(separator: "\n")

    let decl: DeclSyntax
    if includesKeyLookup {
        let fieldForKeyCasesList = properties.flatMap { prop -> [String] in
            var cases = ["case \"\(prop.key)\": .\(prop.name)"]
            for alias in prop.aliases {
                cases.append("case \"\(alias)\": .\(prop.name)")
            }
            return cases
        }
        let fieldForKeyCases = fieldForKeyCasesList.joined(separator: "\n")

        let defaultCase = includesUnknown ? ".unknown" : "throw CodingError.unknownKey(key)"

        decl = """
        extension \(typeName) {
            enum \(raw: expansion.fieldTypeName): \(raw: protocolName) {
                \(raw: cases)

                @_transparent
                var staticString: StaticString {
                    switch self {
                    \(raw: joinedSwitchCases)
                    }
                }

                static func field(for key: UTF8Span) throws(CodingError.Decoding) -> \(raw: expansion.fieldTypeName) {
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
            enum \(raw: expansion.fieldTypeName): \(raw: protocolName) {
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

/// Generates the shared base CodingFields enum (cases + staticString + field(for:comparator:)).
/// The base always includes the `unknown` case and `field(for:comparator:)` since the peer macro may need decoding.
private func makeBaseCodingFieldsEnum(
    for typeName: TokenSyntax,
    from properties: [DetailedStoredProperty],
    expansion: some CodableExpansion
) -> ExtensionDeclSyntax? {
    // Base always includes unknown and key lookup since the peer macro may need them.
    let casesList = properties.map { "case \($0.name)" } + ["case unknown"]
    let cases = casesList.joined(separator: "\n")

    let switchCasesList = properties.map {
        "case .\($0.name): \"\($0.key)\""
    } + ["case .unknown: fatalError()"]
    let joinedSwitchCases = switchCasesList.joined(separator: "\n")

    let fieldForKeyCasesList = properties.flatMap { prop -> [String] in
        var cases = ["case \"\(prop.key)\": .\(prop.name)"]
        for alias in prop.aliases {
            cases.append("case \"\(alias)\": .\(prop.name)")
        }
        return cases
    }
    let fieldForKeyCases = fieldForKeyCasesList.joined(separator: "\n")

    let decl: DeclSyntax = """
    extension \(typeName) {
        enum CodingFields {
            \(raw: cases)

            @_transparent
            var staticString: StaticString {
                switch self {
                \(raw: joinedSwitchCases)
                }
            }

            @inline(__always)
            static func field(for key: UTF8Span, comparator: some DecodingFieldUTF8SpanComparator & ~Escapable) throws(CodingError.Decoding) -> CodingFields {
                switch comparator {
                \(raw: fieldForKeyCases)
                default:
                    .unknown
                }
            }
        }
    }
    """
    return decl.as(ExtensionDeclSyntax.self)
}

/// Generates a format-specific wrapper struct that delegates to the base CodingFields enum.
private func makeWrapperFieldsStruct(
    for typeName: TokenSyntax,
    from properties: [DetailedStoredProperty],
    expansion: some CodableExpansion
) -> ExtensionDeclSyntax? {
    let fieldTypeProtocolName = expansion.fieldTypeProtocolName(forExpansionType: expansion.type)
    let decl: DeclSyntax
    if expansion.type.requiresCodingFieldLookup {
        decl = """
        extension \(typeName) {
            struct \(raw: expansion.fieldTypeName): \(raw: fieldTypeProtocolName) {
                var base: CodingFields
                init(_ base: CodingFields) { self.base = base }

                @_transparent
                var staticString: StaticString {
                    base.staticString
                }

                @inline(__always)
                static func field(for key: UTF8Span) throws(CodingError.Decoding) -> \(raw: expansion.fieldTypeName) {
                    .init(try CodingFields.field(for: key, comparator: UTF8SpanComparator(key)))
                }
            }
        }
        """
    } else {
        decl = """
        extension \(typeName) {
            struct \(raw: expansion.fieldTypeName): \(raw: fieldTypeProtocolName) {
                var base: CodingFields
                init(_ base: CodingFields) { self.base = base }

                @_transparent
                var staticString: StaticString {
                    base.staticString
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
    expansion: some CodableExpansion,
    hasPeer: Bool
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
        let fieldType = expansion.fieldTypeName
        let encodeStatements: String
        if hasPeer {
            encodeStatements = properties.map {
                "try structEncoder.encode(field: \(fieldType)(.\($0.name)), value: self.\($0.name))"
            }.joined(separator: "\n")
        } else {
            encodeStatements = properties.map {
                "try structEncoder.encode(field: \(fieldType).\($0.name), value: self.\($0.name))"
            }.joined(separator: "\n")
        }

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
    expansion: some CodableExpansion,
    hasPeer: Bool
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

        let switchExpr = hasPeer ? "_codingField!.base" : "_codingField!"

        decl = """
        extension \(typeName): \(raw: expansion.decodableProtocolName) {
            \(raw: accessLevelPrefix)static func decode(from decoder: inout \(raw: expansion.decoderType)) throws(CodingError.Decoding) -> \(typeName) {
                try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    \(raw: varDeclarations)
                    var _codingField: \(raw: expansion.fieldTypeName)?
                    try structDecoder.decodeEachField { fieldDecoder throws(CodingError.Decoding) in
                        _codingField = try fieldDecoder.decode(\(raw: expansion.fieldTypeName).self)
                    } andValue: { valueDecoder throws(CodingError.Decoding) in
                        switch \(raw: switchExpr) {
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

/// Generates the CodingFields extension(s) for an enum type's case names,
/// along with per-case field enums for cases with associated values.
func makeEnumCodingFieldsExtension(
    for typeName: TokenSyntax,
    from cases: [EnumCaseInfo],
    expansion: some CodableExpansion,
    peers: PeerMacroInfo
) -> [ExtensionDeclSyntax] {
    if cases.isEmpty {
        return []
    }

    if !peers.multiFormat {
        // Single macro (or same-format pair): only the first generates fields.
        if !peers.isFirst {
            return []
        }
        // Generate format-specific enum directly.
        if let ext = makeSingleFormatEnumCodingFields(for: typeName, from: cases, expansion: expansion, codingFieldsExpansionOverride: peers.codingFieldsExpansionOverride) {
            return [ext]
        }
        return []
    }

    // Dual macro (different format): generate base + wrapper
    var results: [ExtensionDeclSyntax] = []

    if peers.isFirst {
        if let base = makeBaseEnumCodingFields(for: typeName, from: cases, expansion: expansion) {
            results.append(base)
        }
    }

    if let wrapper = makeEnumWrapperFieldsStruct(for: typeName, from: cases, expansion: expansion) {
        results.append(wrapper)
    }

    return results
}

/// Generates the original format-specific enum CodingFields for an enum type (single macro case).
/// When `codingFieldsExpansionOverride` is `.both`, generates as if this were a bidirectional expansion.
private func makeSingleFormatEnumCodingFields(
    for typeName: TokenSyntax,
    from cases: [EnumCaseInfo],
    expansion: some CodableExpansion,
    codingFieldsExpansionOverride: CodableExpansionType? = nil
) -> ExtensionDeclSyntax? {
    let effectiveFieldExpansionType = codingFieldsExpansionOverride ?? expansion.type
    let includesKeyLookup = (codingFieldsExpansionOverride ?? expansion.type).defaultCodingFieldIncludesUnknownCase
    let protocolName = expansion.fieldTypeProtocolName(forExpansionType: effectiveFieldExpansionType)

    let casesList = cases.map { "case \($0.name)" }
    let joinedCases = casesList.joined(separator: "\n")

    let switchCasesList = cases.map {
        "case .\($0.name): \"\($0.key)\""
    }
    let joinedSwitchCases = switchCasesList.joined(separator: "\n")

    // Generate per-case field enums for cases with associated values
    let perCaseFieldEnums = generatePerCaseFieldEnums(for: typeName, from: cases, expansion: expansion, codingFieldsExpansionOverride: codingFieldsExpansionOverride)
    let perCaseSection = perCaseFieldEnums.isEmpty ? "" : "\n\n\(perCaseFieldEnums)"

    let decl: DeclSyntax
    if includesKeyLookup {
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
        enum \(raw: expansion.fieldTypeName): \(raw: protocolName) {
        \(raw: joinedCases)

        @_transparent
        var staticString: StaticString {
            switch self {
            \(raw: joinedSwitchCases)
            }
        }

        static func field(for key: UTF8Span) throws(CodingError.Decoding) -> \(raw: expansion.fieldTypeName) {
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
        enum \(raw: expansion.fieldTypeName): \(raw: protocolName) {
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

/// Generates the shared base CodingFields enum for an enum type (with per-case field enums).
/// The base always includes `field(for:comparator:)` since the peer macro may need decoding.
private func makeBaseEnumCodingFields(
    for typeName: TokenSyntax,
    from cases: [EnumCaseInfo],
    expansion: some CodableExpansion
) -> ExtensionDeclSyntax? {
    let casesList = cases.map { "case \($0.name)" }
    let joinedCases = casesList.joined(separator: "\n")

    let switchCasesList = cases.map {
        "case .\($0.name): \"\($0.key)\""
    }
    let joinedSwitchCases = switchCasesList.joined(separator: "\n")

    let fieldForKeyCasesList = cases.flatMap { c -> [String] in
        var entries = ["case \"\(c.key)\": .\(c.name)"]
        for alias in c.aliases {
            entries.append("case \"\(alias)\": .\(c.name)")
        }
        return entries
    }
    let fieldForKeyCases = fieldForKeyCasesList.joined(separator: "\n")

    // Generate base per-case field enums for cases with associated values
    let basePerCaseFieldEnums = generateBasePerCaseFieldEnums(for: typeName, from: cases)
    let perCaseSection = basePerCaseFieldEnums.isEmpty ? "" : "\n\n\(basePerCaseFieldEnums)"

    let decl: DeclSyntax = """
    extension \(typeName) {
    enum CodingFields {
    \(raw: joinedCases)

    @_transparent
    var staticString: StaticString {
        switch self {
        \(raw: joinedSwitchCases)
        }
    }

    @inline(__always)
    static func field(for key: UTF8Span, comparator: some DecodingFieldUTF8SpanComparator & ~Escapable) throws(CodingError.Decoding) -> CodingFields {
        switch comparator {
        \(raw: fieldForKeyCases)
        default:
            throw CodingError.unknownKey(key)
        }
    }\(raw: perCaseSection)
    }
    }
    """
    return decl.as(ExtensionDeclSyntax.self)
}

/// Generates base per-case field enums for enum cases with associated values.
/// These live inside the shared `CodingFields` enum and contain cases, `staticString`,
/// and a generic `field(for:comparator:)` method.
private func generateBasePerCaseFieldEnums(
    for typeName: TokenSyntax,
    from cases: [EnumCaseInfo]
) -> String {
    let casesWithAssociatedValues = cases.filter { $0.hasAssociatedValues }
    if casesWithAssociatedValues.isEmpty { return "" }

    let perCaseFieldEnums = casesWithAssociatedValues.map { enumCase -> String in
        let fieldsEnumName = "\(capitalizedCaseName(enumCase.name))Fields"
        let fieldCases = enumCase.associatedValues.map { "case \($0.encodedName)" }.joined(separator: "\n")
        let fieldSwitchCases = enumCase.associatedValues.map {
            "case .\($0.encodedName): \"\($0.encodedName)\""
        }.joined(separator: "\n")

        let fieldForKeyCases = enumCase.associatedValues.map {
            "case \"\($0.encodedName)\": .\($0.encodedName)"
        }.joined(separator: "\n")

        return """
        enum \(fieldsEnumName) {
        \(fieldCases)

        @_transparent
        var staticString: StaticString {
            switch self {
            \(fieldSwitchCases)
            }
        }

        @inline(__always)
        static func field(for key: UTF8Span, comparator: some DecodingFieldUTF8SpanComparator & ~Escapable) throws(CodingError.Decoding) -> \(fieldsEnumName) {
            switch comparator {
            \(fieldForKeyCases)
            default:
                throw CodingError.unknownKey(key)
            }
        }
        }
        """
    }.joined(separator: "\n\n")
    return perCaseFieldEnums
}

/// Generates a format-specific wrapper struct for an enum type (with per-case wrapper structs).
private func makeEnumWrapperFieldsStruct(
    for typeName: TokenSyntax,
    from cases: [EnumCaseInfo],
    expansion: some CodableExpansion
) -> ExtensionDeclSyntax? {
    // Generate per-case field wrapper structs that live inside the wrapper struct
    let fieldProtocolName = expansion.fieldTypeProtocolName(forExpansionType: expansion.type)
    let perCaseFieldWrappers = generatePerCaseFieldWrapperStructs(for: typeName, from: cases, expansion: expansion)
    let perCaseSection = perCaseFieldWrappers.isEmpty ? "" : "\n\n\(perCaseFieldWrappers)"

    let decl: DeclSyntax
    if expansion.type.requiresCodingFieldLookup {
        decl = """
        extension \(typeName) {
        struct \(raw: expansion.fieldTypeName): \(raw: fieldProtocolName) {
        var base: CodingFields
        init(_ base: CodingFields) { self.base = base }

        @_transparent
        var staticString: StaticString {
            base.staticString
        }

        @inline(__always)
        static func field(for key: UTF8Span) throws(CodingError.Decoding) -> \(raw: expansion.fieldTypeName) {
            .init(try CodingFields.field(for: key, comparator: UTF8SpanComparator(key)))
        }\(raw: perCaseSection)
        }
        }
        """
    } else {
        decl = """
        extension \(typeName) {
        struct \(raw: expansion.fieldTypeName): \(raw: fieldProtocolName) {
        var base: CodingFields
        init(_ base: CodingFields) { self.base = base }

        @_transparent
        var staticString: StaticString {
            base.staticString
        }\(raw: perCaseSection)
        }
        }
        """
    }
    return decl.as(ExtensionDeclSyntax.self)
}

/// Generates per-case nested field enums for enum cases with associated values.
/// Returns content with minimal indentation (suitable for insertion into a DeclSyntax literal
/// where the enum is at 0-relative indentation). The caller can add extra indentation if needed.
private func generatePerCaseFieldEnums(
    for typeName: TokenSyntax,
    from cases: [EnumCaseInfo],
    expansion: some CodableExpansion,
    codingFieldsExpansionOverride: CodableExpansionType? = nil
) -> String {
    let casesWithAssociatedValues = cases.filter { $0.hasAssociatedValues }
    let effectiveFieldExpansionType = codingFieldsExpansionOverride ?? expansion.type
    let includesKeyLookup = effectiveFieldExpansionType.requiresCodingFieldLookup
    let includesDecode = effectiveFieldExpansionType != .encodingOnly
    let protocolName = expansion.fieldTypeProtocolName(forExpansionType: effectiveFieldExpansionType)
    let perCaseFieldEnums = casesWithAssociatedValues.map { enumCase -> String in
        let fieldsEnumName = "\(capitalizedCaseName(enumCase.name))Fields"
        let fieldCases = enumCase.associatedValues.map { "case \($0.encodedName)" }.joined(separator: "\n")
        let fieldSwitchCases = enumCase.associatedValues.map {
            "case .\($0.encodedName): \"\($0.encodedName)\""
        }.joined(separator: "\n")

        let decodeSection: String
        if includesDecode {
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

        if includesKeyLookup {
            let fieldForKeyCases = enumCase.associatedValues.map {
                "case \"\($0.encodedName)\": .\($0.encodedName)"
            }.joined(separator: "\n")

            return """
            enum \(fieldsEnumName): \(protocolName) {
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
            enum \(fieldsEnumName): \(protocolName) {
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
    return perCaseFieldEnums
}

/// Generates per-case wrapper structs for enum cases with associated values (multi-format case).
/// These wrap the base `CodingFields.XxxFields` enum and add format-specific `decode(from:)`.
private func generatePerCaseFieldWrapperStructs(
    for typeName: TokenSyntax,
    from cases: [EnumCaseInfo],
    expansion: some CodableExpansion
) -> String {
    let casesWithAssociatedValues = cases.filter { $0.hasAssociatedValues }
    if casesWithAssociatedValues.isEmpty { return "" }

    let includesDecode = expansion.type != .encodingOnly
    let protocolName = expansion.fieldTypeProtocolName(forExpansionType: expansion.type)

    let perCaseFieldWrappers = casesWithAssociatedValues.map { enumCase -> String in
        let fieldsEnumName = "\(capitalizedCaseName(enumCase.name))Fields"

        let decodeSection: String
        if includesDecode {
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
                        switch _field!.base {
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

        if expansion.type.requiresCodingFieldLookup {
            return """
            struct \(fieldsEnumName): \(protocolName) {
                var base: CodingFields.\(fieldsEnumName)
                init(_ base: CodingFields.\(fieldsEnumName)) { self.base = base }

                @_transparent
                var staticString: StaticString {
                    base.staticString
                }

                @inline(__always)
                static func field(for key: UTF8Span) throws(CodingError.Decoding) -> \(fieldsEnumName) {
                    .init(try CodingFields.\(fieldsEnumName).field(for: key, comparator: UTF8SpanComparator(key)))
                }\(decodeSection)
            }
            """
        } else {
            return """
            struct \(fieldsEnumName): \(protocolName) {
                var base: CodingFields.\(fieldsEnumName)
                init(_ base: CodingFields.\(fieldsEnumName)) { self.base = base }

                @_transparent
                var staticString: StaticString {
                    base.staticString
                }\(decodeSection)
            }
            """
        }
    }.joined(separator: "\n\n")
    return perCaseFieldWrappers
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
    expansion: some CodableExpansion,
    hasPeer: Bool
) -> ExtensionDeclSyntax? {
    let switchCases: String
    if cases.isEmpty {
        // Empty enum - no cases to encode
        switchCases = ""
    } else {
        switchCases = cases.map { enumCase -> String in
            if enumCase.associatedValues.isEmpty {
                let fieldRef = hasPeer
                    ? "\(expansion.fieldTypeName)(.\(enumCase.name))"
                    : "\(expansion.fieldTypeName).\(enumCase.name)"
                return """
                case .\(enumCase.name):
                    try encoder.encodeEnumCase(\(fieldRef))
                """
            } else {
                let bindings = enumCase.associatedValues.map { "let \($0.encodedName)" }.joined(separator: ", ")
                let fieldsEnumName = "\(expansion.fieldTypeName).\(capitalizedCaseName(enumCase.name))Fields"
                let fieldRef = hasPeer
                    ? "\(expansion.fieldTypeName)(.\(enumCase.name))"
                    : "\(expansion.fieldTypeName).\(enumCase.name)"

                let encodeStatements = enumCase.associatedValues.map {
                    if hasPeer {
                        return "try valueEncoder.encode(field: \(fieldsEnumName)(.\($0.encodedName)), value: \($0.encodedName))"
                    } else {
                        return "try valueEncoder.encode(field: \(fieldsEnumName).\($0.encodedName), value: \($0.encodedName))"
                    }
                }.joined(separator: "\n")

                return """
                case .\(enumCase.name)(\(bindings)):
                try encoder.encodeEnumCase(\(fieldRef), associatedValueCount: \(enumCase.associatedValues.count)) { valueEncoder throws(CodingError.Encoding) in
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
    expansion: some CodableExpansion,
    hasPeer: Bool
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
        let switchExpr = hasPeer ? "_codingField!.base" : "_codingField!"

        // Cases with associated values delegate to per-case decode methods on nested field enums.
        // Cases without associated values just return the case directly.
        let caseDecodeStatements = cases.map { enumCase -> String in
            if enumCase.hasAssociatedValues {
                let fieldsEnumName = "\(expansion.fieldTypeName).\(capitalizedCaseName(enumCase.name))Fields"
                return "case .\(enumCase.name): try \(fieldsEnumName).decode(from: &valuesDecoder)"
            } else {
                return "case .\(enumCase.name): .\(enumCase.name)"
            }
        }.joined(separator: "\n")

        mainDecl = """
        extension \(typeName): \(raw: expansion.decodableProtocolName) {
            static func decode(from decoder: inout \(raw: expansion.decoderType)) throws(CodingError.Decoding) -> \(typeName) {
                var _codingField: \(raw: expansion.fieldTypeName)?
                return try decoder.decodeEnumCase { fieldDecoder throws(CodingError.Decoding) in
                    _codingField = try fieldDecoder.decode(\(raw: expansion.fieldTypeName).self)
                } associatedValues: { valuesDecoder throws(CodingError.Decoding) in
                    return switch \(raw: switchExpr) {
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


