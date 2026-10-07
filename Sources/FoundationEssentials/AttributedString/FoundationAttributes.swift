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
        // Attributes that are only available in the Foundation framework
        internal let _frameworkAttributes: _FrameworkAttributes
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
    /// When you use the `AttributedString.FormattingOptions.applyReplacementIndexAttribute`
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
    /// ``Locale/LanguageDirection-swift.enum/leftToRight`` for its
    /// `characterDirection`, as defined by the FoundationInternationalization module) is usually aligned
    /// to the left, but may be centered or aligned to the right for special
    /// effect, or to be visually more appealing in a user interface.
    ///
    /// For bidirectional text to be perceived as laid out correctly, make sure
    /// that the writing direction is set to the value equivalent to the
    /// `characterDirection`of the primary
    /// language in the text. E.g. an English sentence that contains some
    /// Arabic (a language with
    /// ``Locale/LanguageDirection-swift.enum/rightToLeft`` value for
    /// `characterDirection`) words, should use
    /// a ``leftToRight`` writing direction. An Arabic sentence that contains
    /// some English words, should use a ``rightToLeft`` writing direction.
    ///
    /// Writing direction is always orthogonoal to the line layout direction
    /// chosen to display a certain text. The line layout direction is the
    /// direction in which a sequence of lines is placed in. E.g. English text
    /// is usually displayed with a line layout direction of
    /// ``Locale/LanguageDirection-swift.enum/topToBottom``. While languages do
    /// have an associated line language direction (see
    /// `lineLayoutDirection` in FoundationInternationalization), not all displays
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
