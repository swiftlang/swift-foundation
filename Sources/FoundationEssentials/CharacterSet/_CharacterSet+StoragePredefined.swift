//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 - 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK
extension BuiltInUnicodeScalarSet {
    init(cfpredefined: CFCharacterSetPredefinedSet) {
        let charsetType: SetType
        switch cfpredefined {
        case .control:
            charsetType = .control
        case .whitespace:
            charsetType = .whitespace
        case .whitespaceAndNewline:
            charsetType = .whitespaceAndNewline
        case .decimalDigit:
            charsetType = .decimalDigit
        case .letter:
            charsetType = .letter
        case .lowercaseLetter:
            charsetType = .lowercaseLetter
        case .uppercaseLetter:
            charsetType = .uppercaseLetter
        case .nonBase:
            charsetType = .nonBase
        case .decomposable:
            charsetType = .canonicalDecomposable
        case .alphaNumeric:
            charsetType = .alphanumeric
        case .punctuation:
            charsetType = .punctuation
        case .capitalizedLetter:
            charsetType = .titlecase
        case .symbol:
            charsetType = .symbolAndOperator
        case .newline:
            charsetType = .newline
        case .illegal:
            charsetType = .illegal
        @unknown default:
            fatalError()
        }
        self = .init(type: charsetType)
    }
}
#endif
