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
    /// A capitalized representation of the string that is produced
    /// using the current locale.
    @available(macOS 10.11, iOS 9.0, watchOS 2.0, tvOS 9.0, *)
    public var localizedCapitalized: String {
#if FOUNDATION_FRAMEWORK
        if _foundation_essentials_feature_enabled() {
            return String(self)._capitalized(with: .current)
        } else {
            return _ns.localizedCapitalized
        }
#else
        return String(self)._capitalized(with: .current)
#endif
    }

    /// Returns a capitalized representation of the string
    /// using the specified locale.
    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public func capitalized(with locale: Locale?) -> String {
#if FOUNDATION_FRAMEWORK
        if _foundation_essentials_feature_enabled() {
            return String(self)._capitalized(with: locale)
        } else {
            return _ns.capitalized(with: locale)
        }
#else
        return String(self)._capitalized(with: locale)
#endif
    }
}
