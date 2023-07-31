//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

extension String {
    func _lowercased(with locale: Locale?) -> String {
        guard let casemap = ICU.CaseMap.caseMappingForLocale(locale?.identifier), let lowered = casemap.lowercase(self) else {
            return lowercased()
        }
        return lowered
    }

    func _capitalized(with locale: Locale?) -> String {
        guard let casemap = ICU.CaseMap.caseMappingForLocale(locale?.identifier) else {
            return capitalized
        }
        
        // Theoretically "." is a case-ignorable character, so the character after "." is not uppercased. This results in "D.c." for "D.C".
        // Handle this special case by splitting the string with "." and titlecasing each substring individually.
        var result = ""
        try! self[...]._enumerateComponents(separatedBy: ".", options: []) { substr, isLastComponent in
            result += casemap.titlecase(substr) ?? substr.capitalized
            if !isLastComponent {
                result += "."
            }
        }
        return result
    }

    func _uppercased(with locale: Locale?) -> String {
        guard let casemap = ICU.CaseMap.caseMappingForLocale(locale?.identifier), let uppered = casemap.uppercase(self) else {
            return uppercased()
        }
        return uppered
    }
}
