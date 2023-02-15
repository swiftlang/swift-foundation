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

@available(Future, *)
public typealias Predicate = Foundation.Predicate
@available(Future, *)
public typealias PredicateBindings = Foundation.PredicateBindings
@available(Future, *)
public typealias PredicateExpression = Foundation.PredicateExpression
@available(Future, *)
public typealias PredicateExpressions = Foundation.PredicateExpressions
@available(Future, *)
public typealias StandardPredicateExpression = Foundation.StandardPredicateExpression
@available(Future, *)
public typealias PredicateError = Foundation.PredicateError

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

@available(Future, *)
public typealias Predicate = FoundationEssentials.Predicate
@available(Future, *)
public typealias PredicateBindings = FoundationEssentials.PredicateBindings
@available(Future, *)
public typealias PredicateExpression = FoundationEssentials.PredicateExpression
@available(Future, *)
public typealias PredicateExpressions = FoundationEssentials.PredicateExpressions
@available(Future, *)
public typealias StandardPredicateExpression = FoundationEssentials.StandardPredicateExpression
@available(Future, *)
public typealias PredicateError = FoundationEssentials.PredicateError

#endif // FOUNDATION_FRAMEWORK
