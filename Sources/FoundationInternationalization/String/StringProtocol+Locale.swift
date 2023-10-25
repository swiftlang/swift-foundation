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
#if canImport(FoundationICU)
        if _foundation_essentials_feature_enabled() {
            return String(self)._capitalized(with: .current)
        }
#endif
        return _ns.localizedCapitalized
#else
        return String(self)._capitalized(with: .current)
#endif
    }

    /// Returns a capitalized representation of the string
    /// using the specified locale.
    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public func capitalized(with locale: Locale?) -> String {
#if FOUNDATION_FRAMEWORK
#if canImport(FoundationICU)
        if _foundation_essentials_feature_enabled() {
            return String(self)._capitalized(with: locale)
        }
#endif
        return _ns.capitalized(with: locale)
#else
        return String(self)._capitalized(with: locale)
#endif
    }

    /// A lowercase version of the string that is produced using the current
    /// locale.
    @available(macOS 10.11, iOS 9.0, watchOS 2.0, tvOS 9.0, *)
    public var localizedLowercase: String {
#if FOUNDATION_FRAMEWORK
#if canImport(FoundationICU)
        if _foundation_essentials_feature_enabled() {
            return String(self)._lowercased(with: .current)
        }
#endif

        return _ns.localizedLowercase
#else
        return String(self)._lowercased(with: .current)
#endif
    }


    /// Returns a version of the string with all letters
    /// converted to lowercase, taking into account the specified
    /// locale.
    @available(macOS 10.11, iOS 9.0, watchOS 2.0, tvOS 9.0, *)
    public func lowercased(with locale: Locale?) -> String {
#if FOUNDATION_FRAMEWORK
#if canImport(FoundationICU)
        if _foundation_essentials_feature_enabled() {
            return String(self)._lowercased(with: locale)
        }
#endif
        return _ns.lowercased(with: locale)
#else
        return String(self)._lowercased(with: locale)
#endif
    }

    /// An uppercase version of the string that is produced using the current
    /// locale.
    @available(macOS 10.11, iOS 9.0, watchOS 2.0, tvOS 9.0, *)
    public var localizedUppercase: String {
#if FOUNDATION_FRAMEWORK
#if canImport(FoundationICU)
        if _foundation_essentials_feature_enabled() {
            return String(self)._uppercased(with: .current)
        }
#endif

        return _ns.localizedUppercase
#else
        return String(self)._uppercased(with: .current)
#endif
    }

    /// Returns a version of the string with all letters
    /// converted to uppercase, taking into account the specified
    /// locale.
    @available(macOS 10.11, iOS 9.0, watchOS 2.0, tvOS 9.0, *)
    public func uppercased(with locale: Locale?) -> String {
#if FOUNDATION_FRAMEWORK
#if canImport(FoundationICU)
        if _foundation_essentials_feature_enabled() {
            return String(self)._uppercased(with: locale)
        }
#endif

        return _ns.uppercased(with: locale)
#else
        return String(self)._uppercased(with: locale)
#endif
    }
}
