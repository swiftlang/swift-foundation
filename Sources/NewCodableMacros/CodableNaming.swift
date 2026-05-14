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
import SwiftDiagnostics

/// Mirror of the user-facing `CodableNaming` enum, used within the macro plugin
/// to apply name transformations at compile time.
enum CodableNamingConvention: String {
    case `default`
    case camelCase
    case PascalCase
    case snake_case
    case SCREAMING_SNAKE_CASE
    case kebab_case
    case SCREAMING_KEBAB_CASE
    case lowercase
    case UPPERCASE
}

/// Holds the naming conventions parsed from a codable macro attribute.
struct NamingConventions {
    /// Naming for struct fields (only applicable to structs).
    var fieldNaming: CodableNamingConvention = .default
    /// Naming for enum case names (only applicable to enums).
    var caseNaming: CodableNamingConvention = .default
    /// Naming for enum associated value labels (only applicable to enums).
    var associatedValueLabelNaming: CodableNamingConvention = .default
}

/// Parses naming convention arguments from a codable macro attribute.
///
/// Recognizes `fieldNaming:`, `caseNaming:`, and `associatedValueLabelNaming:` labeled arguments
/// whose values are member access expressions (e.g., `.snake_case`).
func parseNamingConventions(from node: AttributeSyntax) -> NamingConventions {
    var conventions = NamingConventions()
    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
        return conventions
    }

    for argument in arguments {
        guard let label = argument.label?.text,
              let memberAccess = argument.expression.as(MemberAccessExprSyntax.self),
              memberAccess.base == nil else {
            continue
        }
        let conventionName = memberAccess.declName.baseName.text
        guard let convention = CodableNamingConvention(rawValue: conventionName) else {
            continue
        }

        switch label {
        case "fieldNaming":
            conventions.fieldNaming = convention
        case "caseNaming":
            conventions.caseNaming = convention
        case "associatedValueLabelNaming":
            conventions.associatedValueLabelNaming = convention
        default:
            continue
        }
    }

    return conventions
}

// MARK: - Name Transformation

/// Splits a camelCase, PascalCase, or sanke case identifier into its constituent words.
///
/// Handles transitions like:
/// - lowercase → uppercase: `myProperty` → `["my", "Property"]`
/// - uppercase → uppercase+lowercase (acronyms): `parseHTTPResponse` → `["parse", "HTTP", "Response"]`
/// - underscore separators: `my_property` → `["my", "property"]`
internal func splitIntoWords(_ name: String) -> [String] {
    var words: [String] = []
    var currentWord = ""

    let chars = Array(name)
    for i in chars.indices {
        let char = chars[i]

        if char == "_" {
            // Separator: flush current word and skip
            if !currentWord.isEmpty {
                words.append(currentWord)
                currentWord = ""
            }
            continue
        }

        if char.isUppercase {
            if !currentWord.isEmpty {
                let prevIsUpper = currentWord.last?.isUppercase ?? false
                if prevIsUpper {
                    // We're in an acronym run. Check if the next character is lowercase,
                    // which means this uppercase letter starts a new word.
                    let nextIsLower = (i + 1 < chars.count) && chars[i + 1].isLowercase
                    if nextIsLower {
                        words.append(currentWord)
                        currentWord = String(char)
                    } else {
                        currentWord.append(char)
                    }
                } else {
                    // Transition from lowercase to uppercase: start new word
                    words.append(currentWord)
                    currentWord = String(char)
                }
            } else {
                currentWord.append(char)
            }
        } else {
            currentWord.append(char)
        }
    }

    if !currentWord.isEmpty {
        words.append(currentWord)
    }

    return words
}

/// Capitalizes the first character of a word and lowercases the rest.
private func capitalizeWord(_ word: String) -> String {
    guard let first = word.first else { return word }
    return first.uppercased() + word.dropFirst().lowercased()
}

/// Applies a naming convention to a Swift identifier.
///
/// Leading and trailing underscores are preserved in the output (e.g., `_myField` with
/// `.snake_case` becomes `_my_field`). This matches the behavior of Foundation's
/// `JSONDecoder.KeyDecodingStrategy.convertFromSnakeCase`.
///
/// - Parameters:
///   - name: The original Swift identifier name.
///   - convention: The target naming convention.
/// - Returns: The transformed name, or the original name if convention is `.default`.
func applyNamingConvention(_ name: String, convention: CodableNamingConvention) -> String {
    guard convention != .default else { return name }

    // Preserve leading and trailing underscores.
    let leadingUnderscores = String(name.prefix(while: { $0 == "_" }))
    let trailingCount = name.reversed().prefix(while: { $0 == "_" }).count
    let trailingUnderscores = String(repeating: "_", count: trailingCount)

    let stripped: String
    if leadingUnderscores.count + trailingUnderscores.count >= name.count {
        // The entire string is underscores — nothing to transform.
        return name
    } else {
        let start = name.index(name.startIndex, offsetBy: leadingUnderscores.count)
        let end = name.index(name.endIndex, offsetBy: -trailingUnderscores.count)
        stripped = String(name[start..<end])
    }

    let words = splitIntoWords(stripped)
    guard !words.isEmpty else { return name }

    let transformed: String
    switch convention {
    case .default:
        return name

    case .camelCase:
        transformed = words.enumerated().map { index, word in
            index == 0 ? word.lowercased() : capitalizeWord(word)
        }.joined()

    case .PascalCase:
        transformed = words.map { capitalizeWord($0) }.joined()

    case .snake_case:
        transformed = words.map { $0.lowercased() }.joined(separator: "_")

    case .SCREAMING_SNAKE_CASE:
        transformed = words.map { $0.uppercased() }.joined(separator: "_")

    case .kebab_case:
        transformed = words.map { $0.lowercased() }.joined(separator: "-")

    case .SCREAMING_KEBAB_CASE:
        transformed = words.map { $0.uppercased() }.joined(separator: "-")

    case .lowercase:
        transformed = words.map { $0.lowercased() }.joined()

    case .UPPERCASE:
        transformed = words.map { $0.uppercased() }.joined()
    }

    return leadingUnderscores + transformed + trailingUnderscores
}
