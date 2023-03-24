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
    internal func compare<T : StringProtocol>(_ aString: T, options mask: String.CompareOptions = [], range: Range<Index>? = nil) -> ComparisonResult {
        // TODO: This method is modified from `public func compare<T : StringProtocol>(_ aString: T, options mask: String.CompareOptions = [], range: Range<Index>? = nil, locale: Locale? = nil) -> ComparisonResult`. Move that method here once `Locale` can be staged in `FoundationEssentials`.
        var substr = Substring(self)
        if let range {
            substr = substr[range]
        }
        return substr._unlocalizedCompare(other: Substring(aString), options: mask)
    }
}

#endif // !FOUNDATION_FRAMEWORK
