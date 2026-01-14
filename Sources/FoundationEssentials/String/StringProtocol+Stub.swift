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

#if !FOUNDATION_FRAMEWORK
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension StringProtocol {
    /// Compares the string using the specified options and
    /// returns the lexical ordering for the range.
    public func compare<T : StringProtocol>(_ aString: T, options mask: String.CompareOptions = [], range: Range<Index>? = nil, locale: Locale? = nil) -> ComparisonResult {
        var substr = Substring(self)
        if let range {
            substr = substr[range]
        }

        if let locale = locale {
            return _localizedCompare_platform(substr, other: Substring(aString), options: mask, locale: locale)
        }

        return substr._unlocalizedCompare(other: Substring(aString), options: mask)
    }
}

dynamic package func _localizedCompare_platform(_ string: Substring, other: Substring, options: String.CompareOptions, locale: Locale) -> ComparisonResult {
    return string._unlocalizedCompare(other: other, options: options)
}

#endif // !FOUNDATION_FRAMEWORK
