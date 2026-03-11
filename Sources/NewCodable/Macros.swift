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
@attached(member, names: named(CodingFields))
@attached(extension, conformances: JSONEncodable, names: named(encode))
public macro JSONEncodable() = #externalMacro(module: "NewCodableMacros", type: "JSONEncodableMacro")

/// Experimental macro that synthesizes `JSONDecodable` conformance.
@attached(member, names: named(CodingFields))
@attached(extension, conformances: JSONDecodable, names: named(decode))
public macro JSONDecodable() = #externalMacro(module: "NewCodableMacros", type: "JSONDecodableMacro")

/// Experimental macro that synthesizes both `JSONEncodable` and `JSONDecodable`.
@attached(member, names: named(CodingFields))
@attached(extension, conformances: JSONEncodable, JSONDecodable, names: named(encode), named(decode))
public macro JSONCodable() = #externalMacro(module: "NewCodableMacros", type: "JSONCodableMacro")

/// Experimental per-property marker macro for overriding the serialized key.
@attached(peer)
public macro CodingKey(_ name: String) = #externalMacro(module: "NewCodableMacros", type: "CodingKeyMacro")

/// Experimental per-property marker macro for supplying a default decoding value.
@attached(peer)
public macro CodableDefault<T>(_ value: T) = #externalMacro(module: "NewCodableMacros", type: "CodableDefaultMacro")

/// Experimental per-property marker macro for accepting alternate decoding keys.
@attached(peer)
public macro CodableAlias(_ names: String...) = #externalMacro(module: "NewCodableMacros", type: "CodableAliasMacro")
