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

@_exported import XCTest

#if FOUNDATION_FRAMEWORK
@testable import Foundation

public typealias Data = Foundation.Data
public typealias UUID = Foundation.UUID

// XCTest implicitly imports Foundation
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias ListFormatStyle = Foundation.ListFormatStyle

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias StringStyle = Foundation.StringStyle

public typealias Locale = Foundation.Locale

#else

@testable import FoundationEssentials
@testable import FoundationInternationalization
// XCTest implicitly imports Foundation

public typealias Data = FoundationEssentials.Data
public typealias UUID = FoundationEssentials.UUID

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias ListFormatStyle = FoundationInternationalization.ListFormatStyle

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias StringStyle = FoundationInternationalization.StringStyle

public typealias Locale = FoundationInternationalization.Locale

#endif // FOUNDATION_FRAMEWORK
