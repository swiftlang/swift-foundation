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

// MARK: - Exported Types
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension String {
#if FOUNDATION_FRAMEWORK
    public typealias CompareOptions = NSString.CompareOptions
#else
    /// These options apply to the various search/find and comparison methods (except where noted).
    public struct CompareOptions : OptionSet, Sendable {
        public let rawValue: UInt

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        public static let caseInsensitive = CompareOptions(rawValue: 1)
        /// Exact character-by-character equivalence
        public static let literal = CompareOptions(rawValue: 2)
        /// Search from end of source string
        public static let backwards = CompareOptions(rawValue: 4)
        /// Search is limited to start (or end, if `.backwards`) of source string
        public static let anchored  = CompareOptions(rawValue: 8)
        /// Numbers within strings are compared using numeric value, that is,
        /// Foo2.txt < Foo7.txt < Foo25.txt;
        /// only applies to compare methods, not find
        public static let numeric   = CompareOptions(rawValue: 64)
        /// If specified, ignores diacritics (o-umlaut == o)
        public static let diacriticInsensitive = CompareOptions(rawValue: 128)
        /// If specified, ignores width differences ('a' == UFF41)
        public static let widthInsensitive = CompareOptions(rawValue: 256)
        /// If specified, comparisons are forced to return either `.orderedAscending`
        /// or `.orderedDescending` if the strings are equivalent but not strictly equal,
        /// for stability when sorting (e.g. "aaa" > "AAA" with `.caseInsensitive` specified)
        public static let forcedOrdering = CompareOptions(rawValue: 512)
        /// The search string is treated as an ICU-compatible regular expression;
        /// if set, no other options can apply except `.caseInsensitive` and `.anchored`
        public static let regularExpression = CompareOptions(rawValue: 1024)
    }
#endif // FOUNDATION_FRAMEWORK
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension String {
    func _capitalized() -> String {
        var new = ""
        new.reserveCapacity(utf8.count)

        let uppercaseSet = BuiltInUnicodeScalarSet.uppercaseLetters
        let lowercaseSet = BuiltInUnicodeScalarSet.lowercaseLetters
        let cfcaseIgnorableSet = BuiltInUnicodeScalarSet.caseIgnorables

        var isLastCased = false
        for scalar in unicodeScalars {
            let properties = scalar.properties
            if uppercaseSet.contains(scalar) {
                new += isLastCased ? properties.lowercaseMapping : String(scalar)
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
