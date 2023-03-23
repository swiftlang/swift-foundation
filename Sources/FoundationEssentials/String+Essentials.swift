//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

extension String {
    func _capitalized() -> String {
        var new = ""
        new.reserveCapacity(utf8.count)

        let uppercaseSet = BuiltInUnicodeScalarSet.uppercaseLetter
        let lowercaseSet = BuiltInUnicodeScalarSet.lowercaseLetter
        let cfcaseIgnorableSet = BuiltInUnicodeScalarSet.caseIgnorable

        var isLastCased = false
        for scalar in unicodeScalars {
            let properties = scalar.properties
            if uppercaseSet.contains(scalar) {
                new += isLastCased ? properties.lowercaseMapping  : String(scalar)
                isLastCased = true
            } else if lowercaseSet.contains(scalar) {
                new += isLastCased ? String(scalar) : properties.titlecaseMapping
                isLastCased = true
            } else if !cfcaseIgnorableSet.contains(scalar) {
                // We only use a subset of case-ignorable characters as defined in CF instead of the full set of characters satisfying `property.isCaseIgnorable` for compatibility reasons
                new += String(scalar)
                isLastCased = false
            } else {
                new += String(scalar)
            }
        }

        return new
    }

}
