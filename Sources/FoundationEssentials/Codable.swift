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

//===----------------------------------------------------------------------===//
// Errors
//===----------------------------------------------------------------------===//

// Both of these error types bridge to NSError, and through the entry points they use, no further work is needed to make them localized.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension EncodingError : LocalizedError {}
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension DecodingError : LocalizedError {}

//===----------------------------------------------------------------------===//
// Error Utilities
//===----------------------------------------------------------------------===//

internal protocol DecodingErrorValueTypeDebugStringConvertible {
    /// Returns a description of the type of `self` appropriate for an error message.
    var debugDataTypeDescription: String { get }
}

extension DecodingError {
    /// Returns a `.typeMismatch` error describing the expected type.
    ///
    /// - parameter path: The path of `CodingKey`s taken to decode a value of this type.
    /// - parameter expectation: The type expected to be encountered.
    /// - parameter reality: The value that was encountered instead of the expected type.
    /// - returns: A `DecodingError` with the appropriate path and debug description.
    internal static func _typeMismatch(at path: [CodingKey], expectation: Any.Type, reality: some DecodingErrorValueTypeDebugStringConvertible) -> DecodingError {
        let description = "Expected to decode \(expectation) but found \(reality.debugDataTypeDescription) instead."
        return .typeMismatch(expectation, Context(codingPath: path, debugDescription: description))
    }

    internal static func _typeMismatch(at path: [CodingKey], expectation: Any.Type, reality: Any) -> DecodingError {
        let description = "Expected to decode \(expectation) but found \(_typeDescription(of: reality)) instead."
        return .typeMismatch(expectation, Context(codingPath: path, debugDescription: description))
    }

    /// Returns a description of the type of `value` appropriate for an error message.
    ///
    /// - parameter value: The value whose type to describe.
    /// - returns: A string describing `value`.
    /// - precondition: `value` is one of the types below.
    private static func _typeDescription(of value: Any) -> String {
        if case Optional<Any>.none = value {
            return "a null value"
        } else if value is any FixedWidthInteger || value is any BinaryFloatingPoint {
            return "a number"
        } else if value is String {
            return "a string/data"
        } else if value is [Any] {
            return "an array"
        } else if value is [String : Any] {
            return "a dictionary"
        } else {
            return "\(type(of: value))"
        }
    }
}

#if canImport(Combine)
// Only support 64bit

import Combine

//===----------------------------------------------------------------------===//
// Generic Decoding
//===----------------------------------------------------------------------===//

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension JSONEncoder: TopLevelEncoder { }

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension PropertyListEncoder: TopLevelEncoder { }

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension JSONDecoder: TopLevelDecoder { }

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension PropertyListDecoder: TopLevelDecoder { }

#endif
