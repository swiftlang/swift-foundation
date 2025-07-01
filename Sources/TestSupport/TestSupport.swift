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

// See this issue for more info on this file: https://github.com/apple/swift-foundation/issues/40

#if FOUNDATION_FRAMEWORK
@testable import Foundation

public typealias Calendar = Foundation.Calendar
public typealias TimeZone = Foundation.TimeZone
public typealias Locale = Foundation.Locale
public typealias Data = Foundation.Data
public typealias UUID = Foundation.UUID
public typealias Date = Foundation.Date
public typealias DateInterval = Foundation.DateInterval
public typealias DateComponents = Foundation.DateComponents
public typealias Decimal = Foundation.Decimal
public typealias TimeInterval = Foundation.TimeInterval
public typealias JSONEncoder = Foundation.JSONEncoder
public typealias JSONDecoder = Foundation.JSONDecoder
public typealias PropertyListEncoder = Foundation.PropertyListEncoder
public typealias PropertyListDecoder = Foundation.PropertyListDecoder
public typealias ProcessInfo = Foundation.ProcessInfo
public typealias IndexPath = Foundation.IndexPath

// XCTest implicitly imports Foundation
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias FormatStyle = Foundation.FormatStyle
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias ByteCountFormatStyle = Foundation.ByteCountFormatStyle
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias ListFormatStyle = Foundation.ListFormatStyle
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias IntegerFormatStyle = Foundation.IntegerFormatStyle
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias FloatingPointFormatStyle = Foundation.FloatingPointFormatStyle
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias NumberFormatStyleConfiguration = Foundation.NumberFormatStyleConfiguration
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias CurrencyFormatStyleConfiguration = Foundation.CurrencyFormatStyleConfiguration
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias IntegerParseStrategy = Foundation.IntegerParseStrategy

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
public typealias DiscreteFormatStyle = Foundation.DiscreteFormatStyle

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias StringStyle = Foundation.StringStyle

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias AttributedString = Foundation.AttributedString
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias AttributeScope = Foundation.AttributeScope
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias AttributeContainer = Foundation.AttributeContainer
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias AttributeDynamicLookup = Foundation.AttributeDynamicLookup
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias AttributeScopes = Foundation.AttributeScopes
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias AttributedStringAttributeMutation = Foundation.AttributedStringAttributeMutation
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias AttributedStringKey = Foundation.AttributedStringKey
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias AttributedStringProtocol = Foundation.AttributedStringProtocol
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias AttributedSubstring = Foundation.AttributedSubstring
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias ScopedAttributeContainer = Foundation.ScopedAttributeContainer
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias CodableAttributedStringKey = Foundation.CodableAttributedStringKey
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias EncodableAttributedStringKey = Foundation.EncodableAttributedStringKey
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias DecodableAttributedStringKey = Foundation.DecodableAttributedStringKey

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias CodableWithConfiguration = Foundation.CodableWithConfiguration
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias EncodableWithConfiguration = Foundation.EncodableWithConfiguration
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias DecodableWithConfiguration = Foundation.DecodableWithConfiguration
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias EncodingConfigurationProviding = Foundation.EncodingConfigurationProviding
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias DecodingConfigurationProviding = Foundation.DecodingConfigurationProviding

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
public typealias Predicate = Foundation.Predicate
@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
public typealias PredicateBindings = Foundation.PredicateBindings
@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
public typealias PredicateExpression = Foundation.PredicateExpression
@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
public typealias PredicateExpressions = Foundation.PredicateExpressions
@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
public typealias StandardPredicateExpression = Foundation.StandardPredicateExpression
@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
public typealias PredicateError = Foundation.PredicateError
@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
public typealias PredicateCodableConfiguration = Foundation.PredicateCodableConfiguration
@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
public typealias Expression = Foundation.Expression
#else

#if DEBUG
@_exported @testable import FoundationEssentials
@_exported @testable import FoundationInternationalization
// XCTest implicitly imports Foundation
#else
@_exported import FoundationEssentials
@_exported import FoundationInternationalization
// XCTest implicitly imports Foundation
#endif

public typealias Data = FoundationEssentials.Data
public typealias UUID = FoundationEssentials.UUID
public typealias Date = FoundationEssentials.Date
public typealias DateInterval = FoundationEssentials.DateInterval
public typealias Decimal = FoundationEssentials.Decimal
public typealias TimeInterval = FoundationEssentials.TimeInterval
public typealias JSONEncoder = FoundationEssentials.JSONEncoder
public typealias JSONDecoder = FoundationEssentials.JSONDecoder
public typealias PropertyListEncoder = FoundationEssentials.PropertyListEncoder
public typealias PropertyListDecoder = FoundationEssentials.PropertyListDecoder

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias FormatStyle = FoundationEssentials.FormatStyle
@available(FoundationAttributedString 5.5, *)
public typealias ByteCountFormatStyle = FoundationInternationalization.ByteCountFormatStyle
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias ListFormatStyle = FoundationInternationalization.ListFormatStyle
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias IntegerFormatStyle = FoundationInternationalization.IntegerFormatStyle
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias FloatingPointFormatStyle = FoundationInternationalization.FloatingPointFormatStyle
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias NumberFormatStyleConfiguration = FoundationInternationalization.NumberFormatStyleConfiguration
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias CurrencyFormatStyleConfiguration = FoundationInternationalization.CurrencyFormatStyleConfiguration
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias IntegerParseStrategy = FoundationInternationalization.IntegerParseStrategy

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
public typealias DiscreteFormatStyle = FoundationEssentials.DiscreteFormatStyle

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias StringStyle = FoundationInternationalization.StringStyle

@available(FoundationAttributedString 5.5, *)
public typealias AttributedString = FoundationEssentials.AttributedString
@available(FoundationAttributedString 5.5, *)
public typealias AttributeScope = FoundationEssentials.AttributeScope
@available(FoundationAttributedString 5.5, *)
public typealias AttributeContainer = FoundationEssentials.AttributeContainer
@available(FoundationAttributedString 5.5, *)
public typealias AttributeDynamicLookup = FoundationEssentials.AttributeDynamicLookup
@available(FoundationAttributedString 5.5, *)
public typealias AttributeScopes = FoundationEssentials.AttributeScopes
@available(FoundationAttributedString 5.5, *)
public typealias AttributedStringAttributeMutation = FoundationEssentials.AttributedStringAttributeMutation
@available(FoundationAttributedString 5.5, *)
public typealias AttributedStringKey = FoundationEssentials.AttributedStringKey
@available(FoundationAttributedString 5.5, *)
public typealias AttributedStringProtocol = FoundationEssentials.AttributedStringProtocol
@available(FoundationAttributedString 5.5, *)
public typealias AttributedSubstring = FoundationEssentials.AttributedSubstring
@available(FoundationAttributedString 5.5, *)
public typealias ScopedAttributeContainer = FoundationEssentials.ScopedAttributeContainer
@available(FoundationAttributedString 5.5, *)
public typealias CodableAttributedStringKey = FoundationEssentials.CodableAttributedStringKey
@available(FoundationAttributedString 5.5, *)
public typealias EncodableAttributedStringKey = FoundationEssentials.EncodableAttributedStringKey
@available(FoundationAttributedString 5.5, *)
public typealias DecodableAttributedStringKey = FoundationEssentials.DecodableAttributedStringKey

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias CodableWithConfiguration = FoundationEssentials.CodableWithConfiguration
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias EncodableWithConfiguration = FoundationEssentials.EncodableWithConfiguration
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias DecodableWithConfiguration = FoundationEssentials.DecodableWithConfiguration
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias EncodingConfigurationProviding = FoundationEssentials.EncodingConfigurationProviding
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias DecodingConfigurationProviding = FoundationEssentials.DecodingConfigurationProviding

public typealias Calendar = FoundationEssentials.Calendar
public typealias TimeZone = FoundationEssentials.TimeZone
public typealias Locale = FoundationEssentials.Locale
public typealias DateComponents = FoundationEssentials.DateComponents

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
public typealias Predicate = FoundationEssentials.Predicate
@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
public typealias PredicateBindings = FoundationEssentials.PredicateBindings
@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
public typealias PredicateExpression = FoundationEssentials.PredicateExpression
@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
public typealias PredicateExpressions = FoundationEssentials.PredicateExpressions
@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
public typealias StandardPredicateExpression = FoundationEssentials.StandardPredicateExpression
@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
public typealias PredicateError = FoundationEssentials.PredicateError
@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
public typealias Expression = FoundationEssentials.Expression

public typealias SortDescriptor = FoundationInternationalization.SortDescriptor
public typealias SortComparator = FoundationEssentials.SortComparator
public typealias ComparableComparator = FoundationEssentials.ComparableComparator
public typealias ComparisonResult = FoundationEssentials.ComparisonResult

public typealias FileManager = FoundationEssentials.FileManager
public typealias FileAttributeKey = FoundationEssentials.FileAttributeKey
public typealias FileAttributeType = FoundationEssentials.FileAttributeType
public typealias CocoaError = FoundationEssentials.CocoaError
public typealias POSIXError = FoundationEssentials.POSIXError
public typealias FileManagerDelegate = FoundationEssentials.FileManagerDelegate
public typealias ProcessInfo = FoundationEssentials.ProcessInfo
public typealias OperatingSystemVersion = FoundationEssentials.OperatingSystemVersion
public typealias IndexPath = FoundationEssentials.IndexPath
public typealias URL = FoundationEssentials.URL
public typealias URLComponents = FoundationEssentials.URLComponents
public typealias URLQueryItem = FoundationEssentials.URLQueryItem

#endif // FOUNDATION_FRAMEWORK
