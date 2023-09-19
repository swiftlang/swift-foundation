//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

/// A type that can convert a given data type into a representation.
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public protocol FormatStyle : Codable, Hashable {

    /// The type of data to format.
    associatedtype FormatInput

    /// The type of the formatted data.
    associatedtype FormatOutput

    /// Creates a `FormatOutput` instance from `value`.
    func format(_ value: FormatInput) -> FormatOutput

    /// If the format allows selecting a locale, returns a copy of this format with the new locale set. Default implementation returns an unmodified self.
    func locale(_ locale: Locale) -> Self
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension FormatStyle {
    public func locale(_ locale: Locale) -> Self {
        return self
    }
}
