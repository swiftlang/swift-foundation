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

/// Experimental NewCodable macro API.
///
/// The macro spellings in this file are provisional and may evolve with the
/// macro-based Codable design. The per-property marker macros below are
/// especially likely to change as the feature set is refined.
///
/// Explicit `@CodingKey` attributes on individual members override naming conventions.

// MARK: - JSONEncodable

@attached(extension, conformances: JSONEncodable, names: named(CodingFields), named(JSONCodingFields), named(encode))
public macro JSONEncodable() = #externalMacro(module: "NewCodableMacros", type: "JSONEncodableMacro")

/// Synthesizes `JSONEncodable` with a field naming convention (structs only).
@attached(extension, conformances: JSONEncodable, names: named(CodingFields), named(JSONCodingFields), named(encode))
public macro JSONEncodable(fieldNaming: CodableNaming) = #externalMacro(module: "NewCodableMacros", type: "JSONEncodableMacro")

/// Synthesizes `JSONEncodable` with case/associated-value naming conventions (enums only).
@attached(extension, conformances: JSONEncodable, names: named(CodingFields), named(JSONCodingFields), named(encode))
public macro JSONEncodable(caseNaming: CodableNaming = .default, associatedValueLabelNaming: CodableNaming = .default) = #externalMacro(module: "NewCodableMacros", type: "JSONEncodableMacro")

// MARK: - JSONDecodable

/// Synthesizes `JSONDecodable` conformance.
@attached(extension, conformances: JSONDecodable, names: named(CodingFields), named(JSONCodingFields), named(decode))
public macro JSONDecodable() = #externalMacro(module: "NewCodableMacros", type: "JSONDecodableMacro")

/// Synthesizes `JSONDecodable` with a field naming convention (structs only).
@attached(extension, conformances: JSONDecodable, names: named(CodingFields), named(JSONCodingFields), named(decode))
public macro JSONDecodable(fieldNaming: CodableNaming) = #externalMacro(module: "NewCodableMacros", type: "JSONDecodableMacro")

/// Synthesizes `JSONDecodable` with case/associated-value naming conventions (enums only).
@attached(extension, conformances: JSONDecodable, names: named(CodingFields), named(JSONCodingFields), named(decode))
public macro JSONDecodable(caseNaming: CodableNaming = .default, associatedValueLabelNaming: CodableNaming = .default) = #externalMacro(module: "NewCodableMacros", type: "JSONDecodableMacro")

// MARK: - JSONCodable

/// Synthesizes both `JSONEncodable` and `JSONDecodable`.
@attached(extension, conformances: JSONEncodable, JSONDecodable, names: named(CodingFields), named(JSONCodingFields), named(encode), named(decode))
public macro JSONCodable() = #externalMacro(module: "NewCodableMacros", type: "JSONCodableMacro")

/// Synthesizes both `JSONEncodable` and `JSONDecodable` with a field naming convention (structs only).
@attached(extension, conformances: JSONEncodable, JSONDecodable, names: named(CodingFields), named(JSONCodingFields), named(encode), named(decode))
public macro JSONCodable(fieldNaming: CodableNaming) = #externalMacro(module: "NewCodableMacros", type: "JSONCodableMacro")

/// Synthesizes both `JSONEncodable` and `JSONDecodable` with case/associated-value naming conventions (enums only).
@attached(extension, conformances: JSONEncodable, JSONDecodable, names: named(CodingFields), named(JSONCodingFields), named(encode), named(decode))
public macro JSONCodable(caseNaming: CodableNaming = .default, associatedValueLabelNaming: CodableNaming = .default) = #externalMacro(module: "NewCodableMacros", type: "JSONCodableMacro")

// MARK: - CommonEncodable

/// Synthesizes `CommonEncodable` conformance.
@attached(extension, conformances: CommonEncodable, names: named(CodingFields), named(CommonCodingFields), named(encode))
public macro CommonEncodable() = #externalMacro(module: "NewCodableMacros", type: "CommonEncodableMacro")

/// Synthesizes `CommonEncodable` with a field naming convention (structs only).
@attached(extension, conformances: CommonEncodable, names: named(CodingFields), named(CommonCodingFields), named(encode))
public macro CommonEncodable(fieldNaming: CodableNaming) = #externalMacro(module: "NewCodableMacros", type: "CommonEncodableMacro")

/// Synthesizes `CommonEncodable` with case/associated-value naming conventions (enums only).
@attached(extension, conformances: CommonEncodable, names: named(CodingFields), named(CommonCodingFields), named(encode))
public macro CommonEncodable(caseNaming: CodableNaming = .default, associatedValueLabelNaming: CodableNaming = .default) = #externalMacro(module: "NewCodableMacros", type: "CommonEncodableMacro")

// MARK: - CommonDecodable

/// Synthesizes `CommonDecodable` conformance.
@attached(extension, conformances: CommonDecodable, names: named(CodingFields), named(CommonCodingFields), named(decode))
public macro CommonDecodable() = #externalMacro(module: "NewCodableMacros", type: "CommonDecodableMacro")

/// Synthesizes `CommonDecodable` with a field naming convention (structs only).
@attached(extension, conformances: CommonDecodable, names: named(CodingFields), named(CommonCodingFields), named(decode))
public macro CommonDecodable(fieldNaming: CodableNaming) = #externalMacro(module: "NewCodableMacros", type: "CommonDecodableMacro")

/// Synthesizes `CommonDecodable` with case/associated-value naming conventions (enums only).
@attached(extension, conformances: CommonDecodable, names: named(CodingFields), named(CommonCodingFields), named(decode))
public macro CommonDecodable(caseNaming: CodableNaming = .default, associatedValueLabelNaming: CodableNaming = .default) = #externalMacro(module: "NewCodableMacros", type: "CommonDecodableMacro")

// MARK: - CommonCodable

/// Synthesizes both `CommonEncodable` and `CommonDecodable`.
@attached(extension, conformances: CommonEncodable, CommonDecodable, names: named(CodingFields), named(CommonCodingFields), named(encode), named(decode))
public macro CommonCodable() = #externalMacro(module: "NewCodableMacros", type: "CommonCodableMacro")

/// Synthesizes both `CommonEncodable` and `CommonDecodable` with a field naming convention (structs only).
@attached(extension, conformances: CommonEncodable, CommonDecodable, names: named(CodingFields), named(CommonCodingFields), named(encode), named(decode))
public macro CommonCodable(fieldNaming: CodableNaming) = #externalMacro(module: "NewCodableMacros", type: "CommonCodableMacro")

/// Synthesizes both `CommonEncodable` and `CommonDecodable` with case/associated-value naming conventions (enums only).
@attached(extension, conformances: CommonEncodable, CommonDecodable, names: named(CodingFields), named(CommonCodingFields), named(encode), named(decode))
public macro CommonCodable(caseNaming: CodableNaming = .default, associatedValueLabelNaming: CodableNaming = .default) = #externalMacro(module: "NewCodableMacros", type: "CommonCodableMacro")

/// Experimental per-property marker macro for overriding the serialized key.
@attached(peer)
public macro CodingKey(_ name: String) = #externalMacro(module: "NewCodableMacros", type: "CodingKeyMacro")

/// Experimental per-property marker macro for supplying a default decoding value.
@attached(peer)
public macro CodableDefault<T>(_ value: T) = #externalMacro(module: "NewCodableMacros", type: "CodableDefaultMacro")

/// Experimental per-property marker macro for accepting alternate decoding keys.
@attached(peer)
public macro DecodableAlias(_ names: String...) = #externalMacro(module: "NewCodableMacros", type: "DecodableAliasMacro")

/// Naming convention for serialized keys.
///
/// When applied to a codable macro, transforms Swift property or case names
/// into serialized key strings according to the selected convention.
/// Explicit `@CodingKey` attributes on individual properties or enum cases
/// override the naming convention.
///
/// ## Algorithm
///
/// The transformation has two phases:
///
/// **1. Word splitting.** The Swift identifier is decomposed into words using
/// the following rules (applied left-to-right):
///
/// - Interior underscores are treated as explicit word separators and are
///   consumed (not included in any word).
/// - A transition from a lowercase or digit character to an uppercase
///   character starts a new word.
///   Example: `myProperty` → `["my", "Property"]`
/// - A run of multiple uppercase characters followed by a lowercase character
///   splits before the last uppercase character (preserving the acronym as
///   its own word).
///   Example: `parseHTTPResponse` → `["parse", "HTTP", "Response"]`
/// - Digits do **not** trigger a word boundary on their own; they remain
///   attached to the preceding letters.
///   Example: `version4Thing` → `["version4", "Thing"]`
///
/// **2. Reassembly.** The words are joined according to the target convention:
///
/// | Convention              | Join rule                                         | Example output        |
/// |-------------------------|---------------------------------------------------|-----------------------|
/// | `.camelCase`            | First word lowercased, rest capitalized, no separator | `parseHttpResponse` |
/// | `.PascalCase`           | Each word capitalized, no separator               | `ParseHttpResponse`   |
/// | `.snake_case`           | Each word lowercased, joined with `_`             | `parse_http_response` |
/// | `.SCREAMING_SNAKE_CASE` | Each word uppercased, joined with `_`             | `PARSE_HTTP_RESPONSE` |
/// | `.kebab_case`           | Each word lowercased, joined with `-`             | `parse-http-response` |
/// | `.SCREAMING_KEBAB_CASE` | Each word uppercased, joined with `-`             | `PARSE-HTTP-RESPONSE` |
/// | `.lowercase`            | Each word lowercased, no separator                | `parsehttpresponse`   |
/// | `.UPPERCASE`            | Each word uppercased, no separator                | `PARSEHTTPRESPONSE`   |
///
/// "Capitalized" means the first character is uppercased and the remaining
/// characters are lowercased — acronyms like `HTTP` become `Http` in
/// camelCase/PascalCase output.
///
/// ## Compile-Time Key Generation
///
/// This transformation is applied at compile time during macro expansion. The
/// macro embeds the resulting string as a literal in the generated
/// `CodingFields` enum, and that literal is the **only** serialized key that
/// will match the property during both encoding and decoding. (Additional
/// aliases can be declared with `@DecodableAlias` to accept alternative keys
/// during decoding.)
///
/// This design eliminates the round-tripping problems inherent in runtime key
/// conversion strategies such as `JSONDecoder.KeyDecodingStrategy.convertFromSnakeCase`.
/// With the runtime approach, encoding and decoding apply independent
/// transformations that are not always inverses of each other — for example,
/// `imageURL` encodes to `image_url`, but decoding `image_url` back produces
/// `imageUrl`, which no longer matches the original property name. Because
/// `CodableNaming` generates a single deterministic key at compile time, this
/// class of mismatch cannot occur.
public enum CodableNaming: Sendable {
    /// Use the Swift name unchanged (default).
    case `default`
    /// `camelCase` — first letter lowercased, subsequent word-initial letters uppercased (Swift's native convention).
    case camelCase
    /// `PascalCase` — each word starts with an uppercase letter, no separators.
    case PascalCase
    /// `snake_case` — lowercase words separated by underscores.
    case snake_case
    /// `SCREAMING_SNAKE_CASE` — uppercase words separated by underscores.
    case SCREAMING_SNAKE_CASE
    /// `kebab-case` — lowercase words separated by hyphens.
    case kebab_case
    /// `SCREAMING-KEBAB-CASE` — uppercase words separated by hyphens.
    case SCREAMING_KEBAB_CASE
    /// `lowercase` — all lowercase, no separators.
    case lowercase
    /// `UPPERCASE` — all uppercase, no separators.
    case UPPERCASE
}
