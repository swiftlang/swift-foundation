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
public protocol ParseableFormatStyle: FormatStyle {
    associatedtype Strategy: ParseStrategy where Strategy.ParseInput == FormatOutput, Strategy.ParseOutput == FormatInput

    /// A `ParseStrategy` that can be used to parse this `FormatStyle`'s output
    var parseStrategy: Strategy { get }
}
