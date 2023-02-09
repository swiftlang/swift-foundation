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
public typealias Date = Foundation.Date
public typealias TimeInterval = Foundation.TimeInterval

// XCTest implicitly imports Foundation
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias ListFormatStyle = Foundation.ListFormatStyle

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias StringStyle = Foundation.StringStyle

public typealias Locale = Foundation.Locale

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
public typealias Predicate = Foundation.Predicate
@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
public typealias PredicateBindings = Foundation.PredicateBindings
@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
public typealias PredicateExpression = Foundation.PredicateExpression
@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
public typealias PredicateExpressions = Foundation.PredicateExpressions
@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
public typealias StandardPredicateExpression = Foundation.StandardPredicateExpression
@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
public typealias PredicateError = Foundation.PredicateError

#else

@testable import FoundationEssentials
@testable import FoundationInternationalization
// XCTest implicitly imports Foundation

public typealias Data = FoundationEssentials.Data
public typealias UUID = FoundationEssentials.UUID
public typealias Date = FoundationEssentials.Date
public typealias TimeInterval = FoundationEssentials.TimeInterval

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias ListFormatStyle = FoundationInternationalization.ListFormatStyle

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias StringStyle = FoundationInternationalization.StringStyle

public typealias Locale = FoundationInternationalization.Locale

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
public typealias Predicate = FoundationEssentials.Predicate
@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
public typealias PredicateBindings = FoundationEssentials.PredicateBindings
@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
public typealias PredicateExpression = FoundationEssentials.PredicateExpression
@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
public typealias PredicateExpressions = FoundationEssentials.PredicateExpressions
@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
public typealias StandardPredicateExpression = FoundationEssentials.StandardPredicateExpression
@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
public typealias PredicateError = FoundationEssentials.PredicateError

#endif // FOUNDATION_FRAMEWORK
