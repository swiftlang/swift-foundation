#!/usr/bin/env swift -D PRINT_CODE
//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

/*

This is a Swift script that converts an XML file containing the list of IANA
"Character Sets" to Swift source code.
This script generates minimum code and is intended to be executed by other shell
script.

 */

import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

// MARK: - Constants

let requiredCharsetNames = [
    "UTF-8",
    "US-ASCII",
    "EUC-JP",
    "ISO-8859-1",
    "Shift_JIS",
    "ISO-8859-2",
    "UTF-16",
    "windows-1251",
    "windows-1252",
    "windows-1253",
    "windows-1254",
    "windows-1250",
    "ISO-2022-JP",
    "macintosh",
    "UTF-16BE",
    "UTF-16LE",
    "UTF-32",
    "UTF-32BE",
    "UTF-32LE",
]
let charsetsXMLURL = URL(
    string: "https://www.iana.org/assignments/character-sets/character-sets.xml"
)!
let charsetsXMLNamespace = "http://www.iana.org/assignments"
let swiftCodeIndent = "    "


// MARK: - Implementation

enum CodeGenerationError: Swift.Error {
    case missingName
    case missingAliasValue
    case noRootElement
}

/// Representation of <record> element in 'character-sets.xml'
///
/// The structure of <record> element is as blow:
/// ```xml
/// <record>
///     <name>US-ASCII</name>
///     <xref type="rfc" data="rfc2046"/>
///     <value>3</value>
///     <description>ANSI X3.4-1986</description>
///     <alias>iso-ir-6</alias>
///     <alias>ANSI_X3.4-1968</alias>
///     <alias>ANSI_X3.4-1986</alias>
///     <alias>ISO_646.irv:1991</alias>
///     <alias>ISO646-US</alias>
///     <alias>US-ASCII</alias>
///     <alias>us</alias>
///     <alias>IBM367</alias>
///     <alias>cp367</alias>
///     <alias>csASCII</alias>
///     <preferred_alias>US-ASCII</preferred_alias>
/// </record>
/// ```
struct IANACharsetNameRecord {
    /// Preferred MIME Name
    let preferredMIMEName: String?

    /// The name of this charset
    let name: String

    /// The aliases of this charset
    let aliases: Array<String>

    var representativeName: String {
        return preferredMIMEName ?? name
    }

    var swiftCodeLines: [String] {
        var lines: [String] = []
        lines.append("/// IANA Charset `\(representativeName)`.")
        lines.append("static let \(representativeName._camelcased()) = IANACharset(")
        lines.append("\(swiftCodeIndent)preferredMIMEName: \(preferredMIMEName.map { #""\#($0)""# } ?? "nil"),")
        lines.append("\(swiftCodeIndent)name: \"\(name)\",")
        lines.append("\(swiftCodeIndent)aliases: [")
        for alias in aliases {
            lines.append("\(swiftCodeIndent)\(swiftCodeIndent)\"\(alias)\",")
        }
        lines.append("\(swiftCodeIndent)]")
        lines.append(")")
        return lines
    }

    init(_ node: XMLNode) throws {
        guard let name = try node.nodes(forXPath: "./name").first?.stringValue else {
            throw CodeGenerationError.missingName
        }
        self.name = name
        self.preferredMIMEName = try node.nodes(forXPath: "./preferred_alias").first?.stringValue
        self.aliases = try node.nodes(forXPath: "./alias").map {
            guard let alias = $0.stringValue else {
                throw CodeGenerationError.missingAliasValue
            }
            return alias
        }
    }
}

func generateSwiftCode() throws -> String {
    let charsetsXMLDocument = try XMLDocument(contentsOf: charsetsXMLURL)
    guard let charsetsXMLRoot = charsetsXMLDocument.rootElement() else {
        throw CodeGenerationError.noRootElement
    }
    let charsetsXMLRecordElements = try charsetsXMLRoot.nodes(forXPath: "./registry/record")

    var result = "extension IANACharset {"

    for record in try charsetsXMLRecordElements.map({
        try IANACharsetNameRecord($0)
    }) where requiredCharsetNames.contains(record.representativeName) {
        result += "\n"
        result += record.swiftCodeLines.map({ swiftCodeIndent + $0 }).joined(separator: "\n")
        result += "\n"
    }

    result += "}\n"
    return result
}

#if PRINT_CODE
print(try generateSwiftCode())
#endif

// MARK: - Extensions

extension UTF8.CodeUnit {
    var _isASCIINumeric: Bool { (0x30...0x39).contains(self) }
    var _isASCIIUppercase: Bool { (0x41...0x5A).contains(self) }
    var _isASCIILowercase: Bool { (0x61...0x7A).contains(self) }
}

extension String {
    func _camelcased() -> String {
        var result = ""
        var previousWord: Substring.UTF8View? = nil
        for wordUTF8 in self.utf8.split(whereSeparator: {
            !$0._isASCIINumeric &&
            !$0._isASCIIUppercase &&
            !$0._isASCIILowercase
        }) {
            defer {
                previousWord = wordUTF8
            }
            let word = String(Substring(wordUTF8))
            guard let previousWord else {
                result += word.lowercased()
                continue
            }
            if previousWord.last!._isASCIINumeric && wordUTF8.first!._isASCIINumeric {
                result += "_"
            }
            if let firstNonNumericIndex = wordUTF8.firstIndex(where: { !$0._isASCIINumeric }),
               wordUTF8[firstNonNumericIndex...].allSatisfy({ $0._isASCIIUppercase }) {
                result += word
            } else {
                result += word.capitalized(with: nil)
            }

        }
        return result
    }
}
