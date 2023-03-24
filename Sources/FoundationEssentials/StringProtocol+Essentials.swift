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

#if FOUNDATION_FRAMEWORK
@_implementationOnly import _ForSwiftFoundation
#endif

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension StringProtocol {
    /// A copy of the string with each word changed to its corresponding
    /// capitalized spelling.
    ///
    /// This property performs the canonical (non-localized) mapping. It is
    /// suitable for programming operations that require stable results not
    /// depending on the current locale.
    ///
    /// A capitalized string is a string with the first character in each word
    /// changed to its corresponding uppercase value, and all remaining
    /// characters set to their corresponding lowercase values. A "word" is any
    /// sequence of characters delimited by spaces, tabs, or line terminators.
    /// Some common word delimiting punctuation isn't considered, so this
    /// property may not generally produce the desired results for multiword
    /// strings. See the `getLineStart(_:end:contentsEnd:for:)` method for
    /// additional information.
    ///
    /// Case transformations aren’t guaranteed to be symmetrical or to produce
    /// strings of the same lengths as the originals.
    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public var capitalized: String {
#if FOUNDATION_FRAMEWORK
        if _foundation_essentials_feature_enabled() {
            return String(self)._capitalized()
        }

        return _ns.capitalized
#else
        return String(self)._capitalized()
#endif
    }
}
