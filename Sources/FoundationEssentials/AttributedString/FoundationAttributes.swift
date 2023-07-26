//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

// MARK: Attribute Scope

#if FOUNDATION_FRAMEWORK
@_implementationOnly import Foundation_Private.NSAttributedString
@_implementationOnly @_spi(Unstable) import CollectionsInternal
#else
package import _RopeModule
#endif

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributeScopes {
    public var foundation: FoundationAttributes.Type { FoundationAttributes.self }
    
    @_nonSendable
    public struct FoundationAttributes : AttributeScope {
        public let link: LinkAttribute
        public let languageIdentifier: LanguageIdentifierAttribute
        public let personNameComponent: PersonNameComponentAttribute
        public let numberFormat: NumberFormatAttributes
        public let dateField: DateFieldAttribute
        public let alternateDescription: AlternateDescriptionAttribute
        public let imageURL: ImageURLAttribute
        public let replacementIndex : ReplacementIndexAttribute
        public let measurement: MeasurementAttribute
        public let byteCount: ByteCountAttribute
        
        @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
        public let durationField: DurationFieldAttribute
        
#if FOUNDATION_FRAMEWORK
        @available(Future, *)
        public let agreementConcept: AgreementConceptAttribute
        @available(Future, *)
        public let agreementArgument: AgreementArgumentAttribute
        @available(Future, *)
        public let referentConcept: ReferentConceptAttribute
        
        // TODO: Support AttributedString markdown in FoundationPreview: https://github.com/apple/swift-foundation/issues/44
        public let inlinePresentationIntent: InlinePresentationIntentAttribute
        public let presentationIntent: PresentationIntentAttribute
        @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
        public let markdownSourcePosition: MarkdownSourcePositionAttribute
        
        @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
        public let localizedStringArgumentAttributes: LocalizedStringArgumentAttributes
        
        public let inflectionAlternative: InflectionAlternativeAttribute
        public let morphology: MorphologyAttribute
        public let inflect: InflectionRuleAttribute
        @_spi(AutomaticGrammaticalAgreement)
        @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
        public let assumedFallbackInflection: AssumedFallbackInflectionAttribute
#endif // FOUNDATION_FRAMEWORK
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributeDynamicLookup {
    public subscript<T: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeScopes.FoundationAttributes, T>) -> T {
        return self[T.self]
    }

    public subscript<T: AttributedStringKey>(
        dynamicMember keyPath: KeyPath<AttributeScopes.FoundationAttributes.NumberFormatAttributes, T>
    ) -> T {
        self[T.self]
    }

#if FOUNDATION_FRAMEWORK
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public subscript<T: AttributedStringKey>(
        dynamicMember keyPath: KeyPath<AttributeScopes.FoundationAttributes.LocalizedStringArgumentAttributes, T>
    ) -> T {
        self[T.self]
    }
#endif // FOUNDATION_FRAMEWORK
}

// MARK: Attribute Definitions

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributeScopes.FoundationAttributes {
    @frozen
    @_nonSendable
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public enum LinkAttribute : CodableAttributedStringKey {
        public typealias Value = URL
        public static var name = "NSLink"
    }
    
#if FOUNDATION_FRAMEWORK
    
    @frozen @_nonSendable
    @available(Future, *)
    public enum ReferentConceptAttribute : CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
        public typealias Value = Int
        public static let name = NSAttributedString.Key.referentConcept.rawValue
        public static let markdownName = "referentConcept"
    }

    @frozen @_nonSendable
    @available(Future, *)
    public enum AgreementConceptAttribute : CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
        public typealias Value = Int
        public static let name = NSAttributedString.Key.agreeWithConcept.rawValue
        public static let markdownName = "agreeWithConcept"
    }
    
    @frozen @_nonSendable
    @available(Future, *)
    public enum AgreementArgumentAttribute : CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
        public typealias Value = Int
        public static let name = NSAttributedString.Key.agreeWithArgument.rawValue
        public static let markdownName = "agreeWithArgument"
    }
    
    @frozen
    @_nonSendable
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public enum MorphologyAttribute : CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
        public typealias Value = Morphology
        public static let name = NSAttributedString.Key.morphology.rawValue
        public static let markdownName = "morphology"
    }
    
    @frozen
    @_nonSendable
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public enum InflectionRuleAttribute : CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
        public typealias Value = InflectionRule
        public static let name = NSAttributedString.Key.inflectionRule.rawValue
        public static let markdownName = "inflect"
    }
    
    @frozen
    @_nonSendable
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    @_spi(AutomaticGrammaticalAgreement)
    public enum AssumedFallbackInflectionAttribute : CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
        public typealias Value = Morphology
        public static let name = NSAttributedString.Key._assumedFallbackInflection.rawValue
        public static let markdownName = "assumedFallbackInflection"
    }
    
#endif // FOUNDATION_FRAMEWORK
    
    @frozen
    @_nonSendable
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public enum LanguageIdentifierAttribute : CodableAttributedStringKey {
        public typealias Value = String
        public static let name = "NSLanguage"
    }
    
    @frozen
    @_nonSendable
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public enum PersonNameComponentAttribute : CodableAttributedStringKey {
        public typealias Value = Component
        public static let name = "NSPersonNameComponentKey"

        public enum Component: String, Codable, Sendable {
            case givenName, familyName, middleName, namePrefix, nameSuffix, nickname, delimiter
        }
    }
    
    @_nonSendable
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public struct NumberFormatAttributes: AttributeScope {
        public let numberSymbol: SymbolAttribute
        public let numberPart: NumberPartAttribute
        
        @frozen
        @_nonSendable
        public enum NumberPartAttribute : CodableAttributedStringKey {
            public enum NumberPart : Int, Codable, Sendable {
                case integer
                case fraction
            }

            public static let name = "Foundation.NumberFormatPart"
            public typealias Value = NumberPart
        }
        
        @frozen
        @_nonSendable
        public enum SymbolAttribute : CodableAttributedStringKey {
            public enum Symbol : Int, Codable, Sendable {
                case groupingSeparator
                case sign
                case decimalSeparator
                case currency
                case percent
            }

            public static let name = "Foundation.NumberFormatSymbol"
            public typealias Value = Symbol
        }
    }
    
    @frozen
    @_nonSendable
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public enum DateFieldAttribute : CodableAttributedStringKey {
        public enum Field : Hashable, Codable, Sendable {
            case era
            case year
            /// For non-Gregorian calendars, this corresponds to the extended Gregorian year in which the calendar’s year begins.
            case relatedGregorianYear
            case quarter
            case month
            case weekOfYear
            case weekOfMonth
            case weekday
            /// The ordinal position of the weekday unit within the month unit. For example, `2` in "2nd Wednesday in July"
            case weekdayOrdinal
            case day
            case dayOfYear
            case amPM
            case hour
            case minute
            case second
            case secondFraction
            case timeZone

            var rawValue: String {
                switch self {
                case .era:
                    return "G"
                case .year:
                    return "y"
                case .relatedGregorianYear:
                    return "r"
                case .quarter:
                    return "Q"
                case .month:
                    return "M"
                case .weekOfYear:
                    return "w"
                case .weekOfMonth:
                    return "W"
                case .weekday:
                    return "E"
                case .weekdayOrdinal:
                    return "F"
                case .day:
                    return "d"
                case .dayOfYear:
                    return "D"
                case .amPM:
                    return "a"
                case .hour:
                    return "h"
                case .minute:
                    return "m"
                case .second:
                    return "s"
                case .secondFraction:
                    return "S"
                case .timeZone:
                    return "z"
                }
            }

            init?(rawValue: String) {
                let mappings: [String: Self] = [
                    "G": .era,
                    "y": .year,
                    "Y": .year,
                    "u": .year,
                    "U": .year,
                    "r": .relatedGregorianYear,
                    "Q": .quarter,
                    "q": .quarter,
                    "M": .month,
                    "L": .month,
                    "w": .weekOfYear,
                    "W": .weekOfMonth,
                    "e": .weekday,
                    "c": .weekday,
                    "E": .weekday,
                    "F": .weekdayOrdinal,
                    "d": .day,
                    "g": .day,
                    "D": .dayOfYear,
                    "a": .amPM,
                    "b": .amPM,
                    "B": .amPM,
                    "h": .hour,
                    "H": .hour,
                    "k": .hour,
                    "K": .hour,
                    "m": .minute,
                    "s": .second,
                    "A": .second,
                    "S": .secondFraction,
                    "v": .timeZone,
                    "z": .timeZone,
                    "Z": .timeZone,
                    "O": .timeZone,
                    "V": .timeZone,
                    "X": .timeZone,
                    "x": .timeZone,
                ]

                guard let field = mappings[rawValue] else {
                    return nil
                }
                self = field
            }

            // Codable
            public init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                let rawValue = try container.decode(String.self)
                guard let field = Field(rawValue: rawValue) else {
                    throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid Field pattern <\(rawValue)>."))
                }
                self = field
            }

            public func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(rawValue)
            }
        }

        public static let name = "Foundation.DateFormatField"
        public typealias Value = Field
    }
    
#if FOUNDATION_FRAMEWORK
    
    @frozen
    @_nonSendable
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public enum InflectionAlternativeAttribute : CodableAttributedStringKey, MarkdownDecodableAttributedStringKey, ObjectiveCConvertibleAttributedStringKey {
        public typealias Value = AttributedString
        public typealias ObjectiveCValue = NSObject
        public static let name = NSAttributedString.Key.inflectionAlternative.rawValue
        public static let markdownName = "inflectionAlternative"
        
        public static func decodeMarkdown(from decoder: Decoder) throws -> AttributedString {
            let container = try decoder.singleValueContainer()
            let stringContent = try container.decode(String.self)
            return try AttributedString(markdown: stringContent, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
        }
        
        public static func objectiveCValue(for value: AttributedString) throws -> NSObject {
            try NSAttributedString(value, including: \.foundation)
        }
        
        public static func value(for object: NSObject) throws -> AttributedString {
            if let attrString = object as? NSAttributedString {
                return try AttributedString(attrString, including: \.foundation)
            } else {
                throw CocoaError(.coderInvalidValue)
            }
        }
    }
    
	@frozen
    @_nonSendable
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public enum InlinePresentationIntentAttribute : CodableAttributedStringKey, ObjectiveCConvertibleAttributedStringKey {
        public typealias Value = InlinePresentationIntent
        public typealias ObjectiveCValue = NSNumber
        public static let name = NSAttributedString.Key.inlinePresentationIntent.rawValue
        
        public static func objectiveCValue(for value: InlinePresentationIntent) throws -> NSNumber {
            NSNumber(value: value.rawValue)
        }
        
        public static func value(for object: NSNumber) throws -> InlinePresentationIntent {
            InlinePresentationIntent(rawValue: object.uintValue)
        }
    }
    
    @frozen
    @_nonSendable
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public enum PresentationIntentAttribute : CodableAttributedStringKey {
        public typealias Value = PresentationIntent
        public static let name = NSAttributedString.Key.presentationIntentAttributeName.rawValue
    }
    
    @frozen
    @_nonSendable
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public enum MarkdownSourcePositionAttribute: CodableAttributedStringKey {
        public static let name = NSAttributedString.Key.markdownSourcePosition.rawValue
        public typealias Value = AttributedString.MarkdownSourcePosition
    }
    
#endif // FOUNDATION_FRAMEWORK
    
    @frozen
    @_nonSendable
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public enum AlternateDescriptionAttribute : CodableAttributedStringKey {
        public typealias Value = String
        public static let name = "NSAlternateDescription"
    }
    
    @frozen
    @_nonSendable
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public enum ImageURLAttribute : CodableAttributedStringKey {
        public typealias Value = URL
        public static let name = "NSImageURL"
    }
    
    @frozen
    @_nonSendable
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public enum ReplacementIndexAttribute : CodableAttributedStringKey {
        public typealias Value = Int
        public static let name = "NSReplacementIndex"
    }
    
    @_nonSendable
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public struct MeasurementAttribute : CodableAttributedStringKey {
        public typealias Value = Component
        public static let name = "Foundation.MeasurementAttribute"
        public enum Component: Int, Codable, Sendable {
            case value
            case unit
        }
    }
    
    @frozen
    @_nonSendable
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public enum ByteCountAttribute : CodableAttributedStringKey {
        public typealias Value = Component
        public static let name = "Foundation.ByteCountAttribute"
        public enum Component: Codable, Hashable, Sendable {
            case value
            case spelledOutValue
            case unit(Unit)
            case actualByteCount
        }
        
        public enum Unit: Codable, Sendable {
            case byte
            case kb
            case mb
            case gb
            case tb
            case pb
            case eb
            case zb
            case yb
        }
    }

    @frozen
    @_nonSendable
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public enum DurationFieldAttribute : CodableAttributedStringKey {
        public typealias Value = Field
        public static let name = "Foundation.DurationFieldAttribute"
        public enum Field: Int, Codable, Sendable {
            case weeks
            case days
            case hours
            case minutes
            case seconds
            case microseconds
            case milliseconds
            case nanoseconds
        }
    }
    
#if FOUNDATION_FRAMEWORK
    @_nonSendable
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public struct LocalizedStringArgumentAttributes {
    
        // Represents all numeric arguments (i.e. those that use format specifiers such as %d, %f, etc.)
        public let localizedNumericArgument: LocalizedNumericArgumentAttribute
        
        public let localizedDateArgument: LocalizedDateArgumentAttribute
        public let localizedDateIntervalArgument: LocalizedDateIntervalArgumentAttribute
        public let localizedURLArgument: LocalizedURLArgumentAttribute
        
        @frozen
        @_nonSendable
        @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
        public enum LocalizedNumericArgumentAttribute : CodableAttributedStringKey {
            public static let name = "Foundation.LocalizedNumericArgumentAttribute"
            public enum Value : Hashable, Codable, Sendable {
                case uint(UInt64)
                case int(Int64)
                case double(Double)
                case decimal(Decimal)
            }
        }
        
        @frozen
        @_nonSendable
        @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
        public enum LocalizedDateArgumentAttribute : CodableAttributedStringKey {
            public typealias Value = Date
            public static let name = "Foundation.LocalizedDateArgumentAttribute"
        }
        
        @frozen
        @_nonSendable
        @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
        public enum LocalizedDateIntervalArgumentAttribute : CodableAttributedStringKey {
            public typealias Value = Range<Date>
            public static let name = "Foundation.LocalizedDateIntervalArgumentAttribute"
        }
        
        @frozen
        @_nonSendable
        @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
        public enum LocalizedURLArgumentAttribute : CodableAttributedStringKey {
            public typealias Value = URL
            public static let name = "Foundation.LocalizedURLArgumentAttribute"
        }
    }
#endif // FOUNDATION_FRAMEWORK
}

#if FOUNDATION_FRAMEWORK

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributeScopes.FoundationAttributes.LinkAttribute : ObjectiveCConvertibleAttributedStringKey {
    public typealias ObjectiveCValue = NSObject // NSURL or NSString
    
    public static func objectiveCValue(for value: URL) throws -> NSObject {
        value as NSURL
    }
    
    public static func value(for object: NSObject) throws -> URL {
        if let object = object as? NSURL {
            return object as URL
        } else if let object = object as? NSString {
            // TODO: Do we need to call up to [NSTextView _URLForString:] on macOS here?
            if let result = URL(string: object as String) {
                return result
            }
        }
        throw CocoaError(.coderInvalidValue)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributeScopes.FoundationAttributes.LanguageIdentifierAttribute : MarkdownDecodableAttributedStringKey {
    public static let markdownName = "languageIdentifier"
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributeScopes.FoundationAttributes.PersonNameComponentAttribute : ObjectiveCConvertibleAttributedStringKey {
    public typealias ObjectiveCValue = NSString
}

#endif // FOUNDATION_FRAMEWORK
