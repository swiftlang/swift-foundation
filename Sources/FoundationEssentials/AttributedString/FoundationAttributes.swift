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
internal import Foundation_Private.NSAttributedString
#endif

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributeScopes {
    public var foundation: FoundationAttributes.Type { FoundationAttributes.self }
    
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

        /// The base writing direction of a paragraph.
        @available(FoundationPreview 6.2, *)
        public let writingDirection: WritingDirectionAttribute

#if FOUNDATION_FRAMEWORK
        @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
        public let agreementConcept: AgreementConceptAttribute
        @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
        public let agreementArgument: AgreementArgumentAttribute
        @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
        public let referentConcept: ReferentConceptAttribute
        @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
        public let localizedNumberFormat: LocalizedNumberFormatAttribute
        
        // TODO: Support AttributedString markdown in FoundationPreview: https://github.com/apple/swift-foundation/issues/44
        public let inlinePresentationIntent: InlinePresentationIntentAttribute
        public let presentationIntent: PresentationIntentAttribute
        @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
        public let markdownSourcePosition: MarkdownSourcePositionAttribute
        @available(FoundationPreview 6.2, *)
        public let listItemDelimiter: ListItemDelimiterAttribute
        
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


@available(macOS, unavailable, introduced: 12.0)
@available(iOS, unavailable, introduced: 15.0)
@available(tvOS, unavailable, introduced: 15.0)
@available(watchOS, unavailable, introduced: 8.0)
@available(*, unavailable)
extension AttributeScopes.FoundationAttributes : Sendable {}

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
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public enum LinkAttribute : CodableAttributedStringKey {
        public typealias Value = URL
        
        public static var name: String {
            // Used to be: public static var name = "NSLink", but changed for Sendability and ABI compatibility
            get { "NSLink" }
            set { }
        }
    }
    
#if FOUNDATION_FRAMEWORK
    
    @frozen
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    public enum ReferentConceptAttribute : CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
        public typealias Value = Int
        public static let name = NSAttributedString.Key.referentConcept.rawValue
        public static let markdownName = "referentConcept"
    }

    @frozen
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    public enum AgreementConceptAttribute : CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
        public typealias Value = Int
        public static let name = NSAttributedString.Key.agreeWithConcept.rawValue
        public static let markdownName = "agreeWithConcept"
    }
    
    @frozen
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    public enum AgreementArgumentAttribute : CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
        public typealias Value = Int
        public static let name = NSAttributedString.Key.agreeWithArgument.rawValue
        public static let markdownName = "agreeWithArgument"
    }
    
    @frozen
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public enum MorphologyAttribute : CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
        public typealias Value = Morphology
        public static let name = NSAttributedString.Key.morphology.rawValue
        public static let markdownName = "morphology"
    }
    
    @frozen
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public enum InflectionRuleAttribute : CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
        public typealias Value = InflectionRule
        public static let name = NSAttributedString.Key.inflectionRule.rawValue
        public static let markdownName = "inflect"
    }
    
    @frozen
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    @_spi(AutomaticGrammaticalAgreement)
    public enum AssumedFallbackInflectionAttribute : CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
        public typealias Value = Morphology
        public static let name = NSAttributedString.Key._assumedFallbackInflection.rawValue
        public static let markdownName = "assumedFallbackInflection"
    }
    
    @frozen
    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    public enum LocalizedNumberFormatAttribute : CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
        public struct Value: Equatable, Hashable, Codable, Sendable {
            enum Format {
                case automatic
            }
            var format: Format
            internal init(format: Format) {
                self.format = format
            }
            public static var automatic: Self { .init(format: .automatic) }
            public init(from decoder: any Decoder) throws {
                let container = try decoder.singleValueContainer()
                let format = try container.decode(Bool.self)
                if format == true {
                    self.format = .automatic
                } else {
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid value for formatNumber attribute. Accepted values: `true`")
                }
            }
            public func encode(to encoder: any Encoder) throws {
                switch self.format {
                    case .automatic:
                        try true.encode(to: encoder)
                }
            } 
        }
        public static let name = NSAttributedString.Key.localizedNumberFormat.rawValue
        public static let markdownName = "formatNumber"
    }

#endif // FOUNDATION_FRAMEWORK
    
    @frozen
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public enum LanguageIdentifierAttribute : CodableAttributedStringKey {
        public typealias Value = String
        public static let name = "NSLanguage"
    }
    
    @frozen
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public enum PersonNameComponentAttribute : CodableAttributedStringKey {
        public typealias Value = Component
        public static let name = "NSPersonNameComponentKey"

        public enum Component: String, Codable, Sendable {
            case givenName, familyName, middleName, namePrefix, nameSuffix, nickname, delimiter
        }
    }
    
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public struct NumberFormatAttributes: AttributeScope {
        public let numberSymbol: SymbolAttribute
        public let numberPart: NumberPartAttribute
        
        @frozen
        public enum NumberPartAttribute : CodableAttributedStringKey {
            public enum NumberPart : Int, Codable, Sendable {
                case integer
                case fraction
            }

            public static let name = "Foundation.NumberFormatPart"
            public typealias Value = NumberPart
        }
        
        @frozen
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
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public enum PresentationIntentAttribute : CodableAttributedStringKey {
        public typealias Value = PresentationIntent
        public static let name = NSAttributedString.Key.presentationIntentAttributeName.rawValue
    }
    
    @frozen
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public enum MarkdownSourcePositionAttribute: CodableAttributedStringKey {
        public static let name = NSAttributedString.Key.markdownSourcePosition.rawValue
        public typealias Value = AttributedString.MarkdownSourcePosition
    }
    
    @frozen
    @available(FoundationPreview 6.2, *)
    public enum ListItemDelimiterAttribute : CodableAttributedStringKey, ObjectiveCConvertibleAttributedStringKey {
        public typealias Value = Character
        public typealias ObjectiveCValue = NSString
        
        public static let name = NSAttributedString.Key.listItemDelimiter.rawValue
        
        public static func objectiveCValue(for value: Character) throws -> NSString {
            String(value) as NSString
        }
        
        public static func value(for object: NSString) throws -> Character {
            let stringValue = object as String
            guard stringValue.count == 1 else {
                throw CocoaError(.coderInvalidValue)
            }
            return stringValue[stringValue.startIndex]
        }
        
        public static func encode(_ value: Character, to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(String(value))
        }
        
        public static func decode(from decoder: any Decoder) throws -> Character {
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard text.count == 1 else {
                throw DecodingError.dataCorrupted(DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "List item delimeter encoded value must contain only one character / grapheme cluster"
                ))
            }
            return text[text.startIndex]
        }
    }
    
#endif // FOUNDATION_FRAMEWORK
    
    @frozen
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public enum AlternateDescriptionAttribute : CodableAttributedStringKey {
        public typealias Value = String
        public static let name = "NSAlternateDescription"
    }
    
    @frozen
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public enum ImageURLAttribute : CodableAttributedStringKey {
        public typealias Value = URL
        public static let name = "NSImageURL"
    }
    
    @frozen
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public enum ReplacementIndexAttribute : CodableAttributedStringKey {
        public typealias Value = Int
        public static let name = "NSReplacementIndex"
    }
    
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

    /// The attribute key for the base writing direction of a paragraph.
    @available(FoundationPreview 6.2, *)
    @frozen
    public enum WritingDirectionAttribute: CodableAttributedStringKey {
        public typealias Value = AttributedString.WritingDirection
        public static let name: String = "Foundation.WritingDirectionAttribute"

        public static let runBoundaries: AttributedString.AttributeRunBoundaries? = .paragraph
        public static let inheritedByAddedText = false
    }

#if FOUNDATION_FRAMEWORK
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public struct LocalizedStringArgumentAttributes {
    
        // Represents all numeric arguments (i.e. those that use format specifiers such as %d, %f, etc.)
        public let localizedNumericArgument: LocalizedNumericArgumentAttribute
        
        public let localizedDateArgument: LocalizedDateArgumentAttribute
        public let localizedDateIntervalArgument: LocalizedDateIntervalArgumentAttribute
        public let localizedURLArgument: LocalizedURLArgumentAttribute
        
        @frozen
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
        @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
        public enum LocalizedDateArgumentAttribute : CodableAttributedStringKey {
            public typealias Value = Date
            public static let name = "Foundation.LocalizedDateArgumentAttribute"
        }
        
        @frozen
        @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
        public enum LocalizedDateIntervalArgumentAttribute : CodableAttributedStringKey {
            public typealias Value = Range<Date>
            public static let name = "Foundation.LocalizedDateIntervalArgumentAttribute"
        }
        
        @frozen
        @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
        public enum LocalizedURLArgumentAttribute : CodableAttributedStringKey {
            public typealias Value = URL
            public static let name = "Foundation.LocalizedURLArgumentAttribute"
        }
    }
#endif // FOUNDATION_FRAMEWORK
}


@available(macOS, unavailable, introduced: 12.0)
@available(iOS, unavailable, introduced: 15.0)
@available(tvOS, unavailable, introduced: 15.0)
@available(watchOS, unavailable, introduced: 8.0)
@available(*, unavailable)
extension AttributeScopes.FoundationAttributes.LinkAttribute : Sendable {}

@available(macOS, unavailable, introduced: 12.0)
@available(iOS, unavailable, introduced: 15.0)
@available(tvOS, unavailable, introduced: 15.0)
@available(watchOS, unavailable, introduced: 8.0)
@available(*, unavailable)
extension AttributeScopes.FoundationAttributes.LanguageIdentifierAttribute : Sendable {}

@available(macOS, unavailable, introduced: 12.0)
@available(iOS, unavailable, introduced: 15.0)
@available(tvOS, unavailable, introduced: 15.0)
@available(watchOS, unavailable, introduced: 8.0)
@available(*, unavailable)
extension AttributeScopes.FoundationAttributes.PersonNameComponentAttribute : Sendable {}

@available(macOS, unavailable, introduced: 12.0)
@available(iOS, unavailable, introduced: 15.0)
@available(tvOS, unavailable, introduced: 15.0)
@available(watchOS, unavailable, introduced: 8.0)
@available(*, unavailable)
extension AttributeScopes.FoundationAttributes.NumberFormatAttributes : Sendable {}

@available(macOS, unavailable, introduced: 12.0)
@available(iOS, unavailable, introduced: 15.0)
@available(tvOS, unavailable, introduced: 15.0)
@available(watchOS, unavailable, introduced: 8.0)
@available(*, unavailable)
extension AttributeScopes.FoundationAttributes.NumberFormatAttributes.NumberPartAttribute : Sendable {}

@available(macOS, unavailable, introduced: 12.0)
@available(iOS, unavailable, introduced: 15.0)
@available(tvOS, unavailable, introduced: 15.0)
@available(watchOS, unavailable, introduced: 8.0)
@available(*, unavailable)
extension AttributeScopes.FoundationAttributes.NumberFormatAttributes.SymbolAttribute : Sendable {}

@available(macOS, unavailable, introduced: 12.0)
@available(iOS, unavailable, introduced: 15.0)
@available(tvOS, unavailable, introduced: 15.0)
@available(watchOS, unavailable, introduced: 8.0)
@available(*, unavailable)
extension AttributeScopes.FoundationAttributes.DateFieldAttribute : Sendable {}

@available(macOS, unavailable, introduced: 12.0)
@available(iOS, unavailable, introduced: 15.0)
@available(tvOS, unavailable, introduced: 15.0)
@available(watchOS, unavailable, introduced: 8.0)
@available(*, unavailable)
extension AttributeScopes.FoundationAttributes.AlternateDescriptionAttribute : Sendable {}

@available(macOS, unavailable, introduced: 12.0)
@available(iOS, unavailable, introduced: 15.0)
@available(tvOS, unavailable, introduced: 15.0)
@available(watchOS, unavailable, introduced: 8.0)
@available(*, unavailable)
extension AttributeScopes.FoundationAttributes.ImageURLAttribute : Sendable {}

@available(macOS, unavailable, introduced: 12.0)
@available(iOS, unavailable, introduced: 15.0)
@available(tvOS, unavailable, introduced: 15.0)
@available(watchOS, unavailable, introduced: 8.0)
@available(*, unavailable)
extension AttributeScopes.FoundationAttributes.ReplacementIndexAttribute : Sendable {}

@available(macOS, unavailable, introduced: 12.0)
@available(iOS, unavailable, introduced: 15.0)
@available(tvOS, unavailable, introduced: 15.0)
@available(watchOS, unavailable, introduced: 8.0)
@available(*, unavailable)
extension AttributeScopes.FoundationAttributes.MeasurementAttribute : Sendable {}

@available(macOS, unavailable, introduced: 12.0)
@available(iOS, unavailable, introduced: 15.0)
@available(tvOS, unavailable, introduced: 15.0)
@available(watchOS, unavailable, introduced: 8.0)
@available(*, unavailable)
extension AttributeScopes.FoundationAttributes.ByteCountAttribute : Sendable {}

@available(macOS, unavailable, introduced: 13.0)
@available(iOS, unavailable, introduced: 16.0)
@available(tvOS, unavailable, introduced: 16.0)
@available(watchOS, unavailable, introduced: 9.0)
@available(*, unavailable)
extension AttributeScopes.FoundationAttributes.DurationFieldAttribute : Sendable {}

@available(*, unavailable)
extension AttributeScopes.FoundationAttributes.WritingDirectionAttribute: Sendable {}

#if FOUNDATION_FRAMEWORK

@available(macOS, unavailable, introduced: 14.0)
@available(iOS, unavailable, introduced: 17.0)
@available(tvOS, unavailable, introduced: 17.0)
@available(watchOS, unavailable, introduced: 10.0)
@available(*, unavailable)
extension AttributeScopes.FoundationAttributes.ReferentConceptAttribute : Sendable {}

@available(macOS, unavailable, introduced: 14.0)
@available(iOS, unavailable, introduced: 17.0)
@available(tvOS, unavailable, introduced: 17.0)
@available(watchOS, unavailable, introduced: 10.0)
@available(*, unavailable)
extension AttributeScopes.FoundationAttributes.AgreementConceptAttribute : Sendable {}

@available(macOS, unavailable, introduced: 14.0)
@available(iOS, unavailable, introduced: 17.0)
@available(tvOS, unavailable, introduced: 17.0)
@available(watchOS, unavailable, introduced: 10.0)
@available(*, unavailable)
extension AttributeScopes.FoundationAttributes.AgreementArgumentAttribute : Sendable {}

@available(macOS, unavailable, introduced: 12.0)
@available(iOS, unavailable, introduced: 15.0)
@available(tvOS, unavailable, introduced: 15.0)
@available(watchOS, unavailable, introduced: 8.0)
@available(*, unavailable)
extension AttributeScopes.FoundationAttributes.MorphologyAttribute : Sendable {}

@available(macOS, unavailable, introduced: 12.0)
@available(iOS, unavailable, introduced: 15.0)
@available(tvOS, unavailable, introduced: 15.0)
@available(watchOS, unavailable, introduced: 8.0)
@available(*, unavailable)
extension AttributeScopes.FoundationAttributes.InflectionRuleAttribute : Sendable {}

@available(macOS, unavailable, introduced: 13.0)
@available(iOS, unavailable, introduced: 16.0)
@available(tvOS, unavailable, introduced: 16.0)
@available(watchOS, unavailable, introduced: 9.0)
@available(*, unavailable)
extension AttributeScopes.FoundationAttributes.AssumedFallbackInflectionAttribute : Sendable {}

@available(macOS, unavailable, introduced: 15.0)
@available(iOS, unavailable, introduced: 18.0)
@available(tvOS, unavailable, introduced: 18.0)
@available(watchOS, unavailable, introduced: 11.0)
@available(visionOS, unavailable, introduced: 2.0)
@available(*, unavailable)
extension AttributeScopes.FoundationAttributes.LocalizedNumberFormatAttribute : Sendable {}

@available(macOS, unavailable, introduced: 12.0)
@available(iOS, unavailable, introduced: 15.0)
@available(tvOS, unavailable, introduced: 15.0)
@available(watchOS, unavailable, introduced: 8.0)
@available(*, unavailable)
extension AttributeScopes.FoundationAttributes.InflectionAlternativeAttribute : Sendable {}

@available(macOS, unavailable, introduced: 12.0)
@available(iOS, unavailable, introduced: 15.0)
@available(tvOS, unavailable, introduced: 15.0)
@available(watchOS, unavailable, introduced: 8.0)
@available(*, unavailable)
extension AttributeScopes.FoundationAttributes.InlinePresentationIntentAttribute : Sendable {}

@available(macOS, unavailable, introduced: 12.0)
@available(iOS, unavailable, introduced: 15.0)
@available(tvOS, unavailable, introduced: 15.0)
@available(watchOS, unavailable, introduced: 8.0)
@available(*, unavailable)
extension AttributeScopes.FoundationAttributes.PresentationIntentAttribute : Sendable {}

@available(macOS, unavailable, introduced: 13.0)
@available(iOS, unavailable, introduced: 16.0)
@available(tvOS, unavailable, introduced: 16.0)
@available(watchOS, unavailable, introduced: 9.0)
@available(*, unavailable)
extension AttributeScopes.FoundationAttributes.MarkdownSourcePositionAttribute : Sendable {}

@available(macOS, unavailable, introduced: 13.0)
@available(iOS, unavailable, introduced: 16.0)
@available(tvOS, unavailable, introduced: 16.0)
@available(watchOS, unavailable, introduced: 9.0)
@available(*, unavailable)
extension AttributeScopes.FoundationAttributes.LocalizedStringArgumentAttributes : Sendable {}

@available(macOS, unavailable, introduced: 13.0)
@available(iOS, unavailable, introduced: 16.0)
@available(tvOS, unavailable, introduced: 16.0)
@available(watchOS, unavailable, introduced: 9.0)
@available(*, unavailable)
extension AttributeScopes.FoundationAttributes.LocalizedStringArgumentAttributes.LocalizedNumericArgumentAttribute : Sendable {}

@available(macOS, unavailable, introduced: 13.0)
@available(iOS, unavailable, introduced: 16.0)
@available(tvOS, unavailable, introduced: 16.0)
@available(watchOS, unavailable, introduced: 9.0)
@available(*, unavailable)
extension AttributeScopes.FoundationAttributes.LocalizedStringArgumentAttributes.LocalizedURLArgumentAttribute : Sendable {}

@available(macOS, unavailable, introduced: 13.0)
@available(iOS, unavailable, introduced: 16.0)
@available(tvOS, unavailable, introduced: 16.0)
@available(watchOS, unavailable, introduced: 9.0)
@available(*, unavailable)
extension AttributeScopes.FoundationAttributes.LocalizedStringArgumentAttributes.LocalizedDateArgumentAttribute : Sendable {}

@available(macOS, unavailable, introduced: 13.0)
@available(iOS, unavailable, introduced: 16.0)
@available(tvOS, unavailable, introduced: 16.0)
@available(watchOS, unavailable, introduced: 9.0)
@available(*, unavailable)
extension AttributeScopes.FoundationAttributes.LocalizedStringArgumentAttributes.LocalizedDateIntervalArgumentAttribute : Sendable {}

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

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
extension AttributeScopes.FoundationAttributes.LocalizedNumberFormatAttribute.Value: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> __NSLocalizedNumberFormatRule {
        switch self.format {
        case .automatic:
            __NSLocalizedNumberFormatRule.automatic()
        }
    }
    
    public static func _forceBridgeFromObjectiveC(_ source: __NSLocalizedNumberFormatRule, result: inout AttributeScopes.FoundationAttributes.LocalizedNumberFormatAttribute.Value?) {
        result = .automatic
    }
    
    public static func _conditionallyBridgeFromObjectiveC(_ source: __NSLocalizedNumberFormatRule, result: inout AttributeScopes.FoundationAttributes.LocalizedNumberFormatAttribute.Value?) -> Bool {
        result = .automatic
        return true
    }
    
    public static func _unconditionallyBridgeFromObjectiveC(_ source: __NSLocalizedNumberFormatRule?) -> AttributeScopes.FoundationAttributes.LocalizedNumberFormatAttribute.Value {
        .automatic
    }
    
    public typealias _ObjectiveCType = __NSLocalizedNumberFormatRule
}

#endif // FOUNDATION_FRAMEWORK

extension AttributedString {
    /// The writing direction of a piece of text.
    ///
    /// Writing direction defines the base direction in which bidirectional text
    /// lays out its directional runs. A directional run is a contigous sequence
    /// of characters that all have the same effective directionality, which can
    /// be determined using the Unicode BiDi algorithm. The ``leftToRight``
    /// writing direction puts the directional run that is placed first in the
    /// storage leftmost, and places subsequent directional runs towards the
    /// right. The ``rightToLeft`` writing direction puts the directional run
    /// that is placed first in the storage rightmost, and places subsequent
    /// directional runs towards the left.
    ///
    /// Note that writing direction is a property separate from a text's
    /// alignment, its line layout direction, or its character direction.
    /// However, it is often used to determine the default alignment of a
    /// paragraph. E.g. English (a language with
    /// ``Locale/LanguageDirection-swift.enum/leftToRight``
    /// ``Locale/Language-swift.struct/characterDirection``) is usually aligned
    /// to the left, but may be centered or aligned to the right for special
    /// effect, or to be visually more appealing in a user interface.
    ///
    /// For bidirectional text to be perceived as laid out correctly, make sure
    /// that the writing direction is set to the value equivalent to the
    /// ``Locale/Language-swift.struct/characterDirection`` of the primary
    /// language in the text. E.g. an English sentence that contains some
    /// Arabic (a language with
    /// ``Locale/LanguageDirection-swift.enum/rightToLeft``
    /// ``Locale/Language-swift.struct/characterDirection``) words, should use
    /// a ``leftToRight`` writing direction. An Arabic sentence that contains
    /// some English words, should use a ``rightToLeft`` writing direction.
    ///
    /// Writing direction is always orthogonoal to the line layout direction
    /// chosen to display a certain text. The line layout direction is the
    /// direction in which a sequence of lines is placed in. E.g. English text
    /// is usually displayed with a line layout direction of
    /// ``Locale/LanguageDirection-swift.enum/topToBottom``. While languages do
    /// have an associated line language direction (see
    /// ``Locale/Language-swift.struct/lineLayoutDirection``), not all displays
    /// of text follow the line layout direction of the text's primary language.
    ///
    /// Horizontal script is script with a line layout direction of either
    /// ``Locale/LanguageDirection-swift.enum/topToBottom`` or
    /// ``Locale/LanguageDirection-swift.enum/bottomToTop``. Vertical script
    /// has a ``Locale/LanguageDirection-swift.enum/leftToRight`` or
    /// ``Locale/LanguageDirection-swift.enum/rightToLeft`` line layout
    /// direction. In vertical scripts, a writing direction of ``leftToRight``
    /// is interpreted as top-to-bottom and a writing direction of
    /// ``rightToLeft`` is interpreted as bottom-to-top.
    @available(FoundationPreview 6.2, *)
    @frozen
    public enum WritingDirection: Codable, Hashable, CaseIterable, Sendable {
        /// A left-to-right writing direction in horizontal script.
        ///
        /// - Note: In vertical scripts, this equivalent to a top-to-bottom
        /// writing direction.
        case leftToRight

        /// A right-to-left writing direction in horizontal script.
        ///
        /// - Note: In vertical scripts, this equivalent to a bottom-to-top
        /// writing direction.
        case rightToLeft
    }
}
