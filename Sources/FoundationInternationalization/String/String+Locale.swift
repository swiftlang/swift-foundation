//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Collections open source project
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

    func _capitalized(with  locale: Locale?) -> String {
        guard let casemap = ICU.CaseMap.caseMappingForLocale(locale?.identifier), let titled = casemap.titlecase(self) else {
            return capitalized
        }
        return titled
    }

    func _uppercased(with locale: Locale?) -> String {
        guard let casemap = ICU.CaseMap.caseMappingForLocale(locale?.identifier), let uppered = casemap.uppercase(self) else {
            return uppercased()
        }
        return uppered
    }
}
