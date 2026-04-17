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
    /// A property for accessing the attribute scopes that Foundation defines.
    public var foundation: FoundationAttributes.Type { FoundationAttributes.self }
    
    /// Attribute scopes that Foundation defines.
    public struct FoundationAttributes : AttributeScope {
        /// A property for accessing the link attribute.
        public let link: LinkAttribute
        /// A property for accessing a language identifier attribute.
        public let languageIdentifier: LanguageIdentifierAttribute
        /// A property for accessing a person name component attribute.
        public let personNameComponent: PersonNameComponentAttribute
        /// A property for accessing a number format attribute.
        public let numberFormat: NumberFormatAttributes
        /// A property for accessing a date field attribute.
        public let dateField: DateFieldAttribute
        /// A property for accessing an alternative presentation attribute.
        public let alternateDescription: AlternateDescriptionAttribute
        /// A property for accessing an image URL attribute.
        public let imageURL: ImageURLAttribute
        /// A property for accessing a replacement index attribute.
        public let replacementIndex : ReplacementIndexAttribute
        public let measurement: MeasurementAttribute
        public let byteCount: ByteCountAttribute

        @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
        public let durationField: DurationFieldAttribute

        /// The base writing direction of a paragraph.
        @available(FoundationPreview 6.2, *)
        public let writingDirection: WritingDirectionAttribute

#if FOUNDATION_FRAMEWORK
        /// A scope for accessing an agreement concept attribute.
        @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
        public let agreementConcept: AgreementConceptAttribute
        /// A scope for accessing an agreement argument attribute.
        @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
        public let agreementArgument: AgreementArgumentAttribute
        /// A scope for accessing a referent concept attribute.
        @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
        public let referentConcept: ReferentConceptAttribute
        @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
        public let localizedNumberFormat: LocalizedNumberFormatAttribute

        // TODO: Support AttributedString markdown in FoundationPreview: https://github.com/apple/swift-foundation/issues/44
        /// A property for accessing an inline presentation intent attribute.
        public let inlinePresentationIntent: InlinePresentationIntentAttribute
        /// A property for accessing a presentation intent attribute.
        public let presentationIntent: PresentationIntentAttribute
        /// A property for accessing a Markdown source position attribute.
        ///
        /// This attribute indicates the position in the Markdown source where a run
        /// of attributed text begins and ends, omitting markup characters in the source.
        /// For example, after parsing the source string `"This is *emphasized*."`, the
        /// text `emphasized` has a Markdown source position that starts at column `10`.
        /// This index is the `"e"` character, not the `"*"` formatting character.
        ///
        /// > Tip: ``AttributedString/MarkdownSourcePosition`` uses `1`-based counting for
        /// > its row and column properties. For columns, the value represents a UTF-8 index.
        /// > With multi-byte characters, the column is therefore the first byte of the character.
        ///
        /// An attributed string parsed from Markdown text includes this attribute only if
        /// the ``AttributedString/MarkdownParsingOptions/appliesSourcePositionAttributes``
        /// value in the ``AttributedString/MarkdownParsingOptions`` provided to the
        /// ``AttributedString`` initializer is `true`.
        @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
        public let markdownSourcePosition: MarkdownSourcePositionAttribute
        @available(FoundationPreview 6.2, *)
        public let listItemDelimiter: ListItemDelimiterAttribute

        /// A property for accessing a localized string argument attribute.
        @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
        public let localizedStringArgumentAttributes: LocalizedStringArgumentAttributes

        /// A scope for accessing an inflection alternative attribute.
        public let inflectionAlternative: InflectionAlternativeAttribute
        /// A scope for accessing a morphology attribute.
        public let morphology: MorphologyAttribute
        /// A scope for accessing an inflection rule attribute.
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
    /// Returns the attributed string key for a specified Foundation key path.
    public subscript<T: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeScopes.FoundationAttributes, T>) -> T {
        return self[T.self]
    }

    /// Returns the attributed string key for a specified Foundation number
    /// format key path.
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
    /// A type for using a link as an attribute.
    @frozen
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public enum LinkAttribute : CodableAttributedStringKey {
        /// The type of the link attribute's value.
        public typealias Value = URL
        
        /// The name of the link attribute.
        public static var name: String {
            // Used to be: public static var name = "NSLink", but changed for Sendability and ABI compatibility
            get { "NSLink" }
            set { }
        }
    }
    
#if FOUNDATION_FRAMEWORK
    
    /// An attribute that specifies a grammatical agreement concept for substituting pronouns in localized text.
    ///
    /// Use the ``AttributeScopes/FoundationAttributes/referentConcept`` formatting
    /// attribute for cases where you need to refer to a person using their preferred
    /// pronoun in a string.
    ///
    /// For an example of how to use a `referentConcept`, see ``TermOfAddress``.
    @frozen
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    public enum ReferentConceptAttribute : CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
        public typealias Value = Int
        public static let name = NSAttributedString.Key.referentConcept.rawValue
        public static let markdownName = "referentConcept"
    }

    /// An attribute that represents grammatical agreement for objects that aren't part of the inflected text.
    ///
    /// Use this formatting attribute for cases where you need to inflect text based
    /// on a term of address or phrase that isn't part of the inflected text. For
    /// example, you can use an ``InflectionConcept/termsOfAddress(_:)`` concept to
    /// make a word agree with a person's preferred term of address, or a
    /// ``InflectionConcept/localizedPhrase(_:)`` concept to agree with a noun that
    /// doesn't appear in the sentence.
    @frozen
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    public enum AgreementConceptAttribute : CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
        public typealias Value = Int
        public static let name = NSAttributedString.Key.agreeWithConcept.rawValue
        public static let markdownName = "agreeWithConcept"
    }
    
    /// An attribute that represents grammatical agreement with an argument in a localized string.
    ///
    /// Many languages require grammatical agreement in their sentences. In Spanish,
    /// for example, adjectives and verbs need to agree with the gender of the subject
    /// they refer to. Use the `agreeWithArgument` attribute to make a word at one
    /// position in a sentence inflect to agree with a word at another position,
    /// eliminating the need to include multiple gendered forms in localization files.
    ///
    /// In a localization file, wrap the word needing inflection in an
    /// `agreeWithArgument` attribute and point it to the replacement index of the
    /// word it needs to agree with:
    ///
    /// ```
    /// // In the Spanish localization file:
    /// "Your %1@ %2@ is ready." = "Tu ^[%2$@ %1$@](inflect: true) está ^[listo](agreeWithArgument: 2)."
    /// ```
    @frozen
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    public enum AgreementArgumentAttribute : CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
        public typealias Value = Int
        public static let name = NSAttributedString.Key.agreeWithArgument.rawValue
        public static let markdownName = "agreeWithArgument"
    }
    
    /// A type for using a morphology as an attribute.
    @frozen
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public enum MorphologyAttribute : CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
        public typealias Value = Morphology
        public static let name = NSAttributedString.Key.morphology.rawValue
        public static let markdownName = "morphology"
    }
    
    /// A rule that affects how an attributed string performs automatic grammatical agreement.
    ///
    /// Most apps can rely on loading localized strings to perform automatic grammar agreement. Typically, strings in your app's strings files use the Markdown extension syntax to indicate portions of the string that may require inflection to agree grammatically. This transformation occurs when you load the attributed string with methods like `init(localized:options:table:bundle:locale:comment:)`.
    ///
    /// However, if the system lacks information about the words in the string, you may need to apply an inflection rule programmatically. For example, a social networking app may have gender information about other users that you want to apply at runtime. When performing manual inflection at runtime, you use an inflection rule to indicate to the system what portions of a string should be automatically edited, and what to match. Apply the ``AttributeScopes/FoundationAttributes/inflect`` attribute to set an ``InflectionRule`` on an ``AttributedString``, then call ``AttributedString/inflected()`` to perform the grammar agreement and produce an edited string.
    ///
    /// ```swift
    /// var string = AttributedString(localized: "They liked your post.")
    /// // The user who liked the post uses feminine pronouns.
    /// var morphology = Morphology()
    /// morphology.grammaticalGender = .feminine
    /// string.inflect = InflectionRule(morphology: morphology)
    /// let result = string.inflected()
    /// // result == "She liked your post."
    /// ```
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
    
    /// A type for using a language identifier as an attribute.
    @frozen
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public enum LanguageIdentifierAttribute : CodableAttributedStringKey {
        public typealias Value = String
        public static let name = "NSLanguage"
    }
    
    /// A type for using a person name component as an attribute.
    @frozen
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public enum PersonNameComponentAttribute : CodableAttributedStringKey {
        public typealias Value = Component
        public static let name = "NSPersonNameComponentKey"

        public enum Component: String, Codable, Sendable {
            case givenName, familyName, middleName, namePrefix, nameSuffix, nickname, delimiter
        }
    }
    
    /// A type for using a number format as an attribute.
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
    
    /// A type for using a date field as an attribute.
    ///
    /// A date field indicates a portion of a formatted date, such as its year,
    /// month, day, hour, or minute.
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
    
    /// An attribute that provides an alternative inflection phrase when the system can't achieve grammatical agreement.
    ///
    /// Use this attribute to provide an alternative phrase for cases where the system
    /// can't achieve unambiguous grammatical agreement. For example, when inflecting
    /// a gendered word without knowing the person's preferred terms of address, you
    /// can set an `inflectionAlternative` to supply a gender-neutral fallback:
    ///
    /// ```swift
    /// let resource = LocalizedStringResource(
    ///     "^[Bienvenido](inflect: true, inflectionAlternative: 'Te damos la bienvenida').")
    /// let result = AttributedString(localized: resource)
    /// // result == "Te damos la bienvenida."
    /// ```
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
    
    /// A type for using an inline presentation intent as an attribute.
    ///
    /// An inline presentation intent applies to a run of characters inside a larger
    /// block, and covers traits like emphasis, strikethrough, and code voice.
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
    
    /// A type for using a presentation intent as an attribute.
    ///
    /// A presentation intent applies to a block of characters, and covers traits
    /// like list, block quote, or table presentation.
    @frozen
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public enum PresentationIntentAttribute : CodableAttributedStringKey {
        public typealias Value = PresentationIntent
        public static let name = NSAttributedString.Key.presentationIntentAttributeName.rawValue
    }
    
    /// A type for using a markdown source position as an attribute.
    @frozen
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public enum MarkdownSourcePositionAttribute: CodableAttributedStringKey {
        /// The name of the attribute, for use in encoding and decoding.
        public static let name = NSAttributedString.Key.markdownSourcePosition.rawValue
        /// The value type of a Markdown source position attribute.
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
                    debugDescription: "List item delimiter encoded value must contain only one character / grapheme cluster"
                ))
            }
            return text[text.startIndex]
        }
    }
    
#endif // FOUNDATION_FRAMEWORK
    
    /// A type for using an alternative description as an attribute.
    @frozen
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public enum AlternateDescriptionAttribute : CodableAttributedStringKey {
        public typealias Value = String
        public static let name = "NSAlternateDescription"
    }
    
    /// A type for using an image URL as an attribute.
    @frozen
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public enum ImageURLAttribute : CodableAttributedStringKey {
        /// The type of the image URL attribute.
        public typealias Value = URL
        /// The name of the image URL attribute.
        public static let name = "NSImageURL"
    }
    
    /// A type for using a replacement index as an attribute.
    ///
    /// When you use the ``AttributedString/FormattingOptions/applyReplacementIndexAttribute``
    /// formatting option, the resulting formatted string uses this attribute to mark
    /// the location of replacement strings. This allows you to relate ranges to
    /// replacements even if localizers change the word order in format strings.
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
            
            private typealias ValueCodingKeys = EmptyCodingKeys
            private typealias SpelledOutValueCodingKeys = EmptyCodingKeys
            private typealias UnitCodingKeys = DefaultAssociatedValueCodingKeys1
            private typealias ActualByteCountCodingKeys = EmptyCodingKeys
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
            
            private typealias ByteCodingKeys = EmptyCodingKeys
            private typealias KbCodingKeys = EmptyCodingKeys
            private typealias MbCodingKeys = EmptyCodingKeys
            private typealias GbCodingKeys = EmptyCodingKeys
            private typealias TbCodingKeys = EmptyCodingKeys
            private typealias PbCodingKeys = EmptyCodingKeys
            private typealias EbCodingKeys = EmptyCodingKeys
            private typealias ZbCodingKeys = EmptyCodingKeys
            private typealias YbCodingKeys = EmptyCodingKeys
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
    /// A type for using a localized string argument as an attribute.
    ///
    /// You use the this scope's attributes when creating an attributed string from a ``LocalizedStringResource``. The process creating the attributed string may not have access to the original arguments passed to the interpolation. Instead, the attributed string marks formatted runs with this type, allowing you to retrieve the original values.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public struct LocalizedStringArgumentAttributes {

        /// The value of a numeric argument used to format the run with this attribute.
        public let localizedNumericArgument: LocalizedNumericArgumentAttribute

        /// The date value used to format the run with this attribute.
        public let localizedDateArgument: LocalizedDateArgumentAttribute
        /// The date interval value used to format the run with this attribute.
        public let localizedDateIntervalArgument: LocalizedDateIntervalArgumentAttribute
        /// The URL value used to format the run with this attribute.
        public let localizedURLArgument: LocalizedURLArgumentAttribute
        
        /// A type for a numeric argument used to format the run with this attribute.
        @frozen
        @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
        public enum LocalizedNumericArgumentAttribute : CodableAttributedStringKey {
            /// The name of the attribute.
            public static let name = "Foundation.LocalizedNumericArgumentAttribute"
            /// The value type represented by this attribute.
            ///
            /// Each case of this enumeration provides the value type and the value itself, as an associated value.
            public enum Value : Hashable, Codable, Sendable {
                /// An unsigned integer value.
                ///
                /// - Parameter uint: The attribute value, as a `UInt64`.
                case uint(UInt64)
                /// A signed integer value.
                ///
                /// - Parameter int: The attribute value, as an `Int64`.
                case int(Int64)
                /// A double-precision floating point value.
                ///
                /// - Parameter double: The attribute value, as a `Double`.
                case double(Double)
                /// A decimal value.
                ///
                /// - Parameter decimal: The attribute value, as a `Decimal`.
                case decimal(Decimal)
                
                private typealias UintCodingKeys = DefaultAssociatedValueCodingKeys1
                private typealias IntCodingKeys = DefaultAssociatedValueCodingKeys1
                private typealias DoubleCodingKeys = DefaultAssociatedValueCodingKeys1
                private typealias DecimalCodingKeys = DefaultAssociatedValueCodingKeys1
            }
        }
        
        /// A type for a date argument used to format the run with this attribute.
        @frozen
        @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
        public enum LocalizedDateArgumentAttribute : CodableAttributedStringKey {
            public typealias Value = Date
            /// The name of the attribute.
            public static let name = "Foundation.LocalizedDateArgumentAttribute"
        }
        
        /// A type for a date interval argument used to format the run with this attribute.
        @frozen
        @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
        public enum LocalizedDateIntervalArgumentAttribute : CodableAttributedStringKey {
            public typealias Value = Range<Date>
            /// The name of the attribute.
            public static let name = "Foundation.LocalizedDateIntervalArgumentAttribute"
        }
        
        /// A type for a URL argument used to format the run with this attribute.
        @frozen
        @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
        public enum LocalizedURLArgumentAttribute : CodableAttributedStringKey {
            public typealias Value = URL
            /// The name of the attribute.
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
    /// The type of the link attribute's value when calling it from Objective-C.
    public typealias ObjectiveCValue = NSObject // NSURL or NSString
    
    /// Returns an object for a specified URL value.
    ///
    /// - Parameter value: A URL to produce an `NSObject` from.
    /// - Returns: The object for the specified URL.
    public static func objectiveCValue(for value: URL) throws -> NSObject {
        value as NSURL
    }

    /// Returns the URL value of the specified object.
    ///
    /// - Parameter object: An `NSObject` to retrieve a URL value from.
    /// - Returns: A URL value.
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
    /// lays out its directional runs. A directional run is a contiguous sequence
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
        
        private typealias LeftToRightCodingKeys = EmptyCodingKeys
        private typealias RightToLeftCodingKeys = EmptyCodingKeys
    }
}
