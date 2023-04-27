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

/// A type that can parse a representation of a given data type.
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public protocol ParseStrategy: Codable, Hashable {

    /// The type of the representation describing the data.
    associatedtype ParseInput

    /// The type of the data type.
    associatedtype ParseOutput

    /// Creates an instance of the `ParseOutput` type from `value`.
    func parse(_ value: ParseInput) throws -> ParseOutput
}
