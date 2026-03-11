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

@attached(member, names: named(CodingFields))
@attached(extension, conformances: JSONEncodable, names: named(encode))
public macro JSONEncodable() = #externalMacro(module: "NewCodableMacros", type: "JSONEncodableMacro")

@attached(extension, conformances: JSONDecodable, names: named(decode))
public macro JSONDecodable() = #externalMacro(module: "NewCodableMacros", type: "JSONDecodableMacro")

@attached(member, names: named(CodingFields))
@attached(extension, conformances: JSONEncodable, JSONDecodable, names: named(encode), named(decode))
public macro JSONCodable() = #externalMacro(module: "NewCodableMacros", type: "JSONCodableMacro")

@attached(peer)
public macro CodingKey(_ name: String) = #externalMacro(module: "NewCodableMacros", type: "CodingKeyMacro")
