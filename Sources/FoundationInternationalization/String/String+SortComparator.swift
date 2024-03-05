//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension String {
    /// Compares `String`s using one of a fixed set of standard comparison
    /// algorithms.
    public struct StandardComparator: SortComparator, Codable, Sendable {
        public typealias Compared = String
#if FOUNDATION_FRAMEWORK
        // https://github.com/apple/swift-foundation/issues/284
        
        /// Compares `String`s as compared by the Finder.
        ///
        /// Uses a localized, numeric comparison in the current locale.
        ///
        /// The default `SortComparator` used in `String` comparisons.
        public static let localizedStandard = StandardComparator(
            options: [
                .numeric,
                .caseInsensitive,
                .widthInsensitive,
                .forcedOrdering
            ],
            localized: true
        )

        /// Compares `String`s using a localized comparison in the current
        /// locale.
        public static let localized = StandardComparator(options: [], localized: true)
#endif

        /// Compares `String`s lexically.
        public static let lexical = StandardComparator(options: [], localized: false)

#if FOUNDATION_FRAMEWORK
        private static let validAlgorithms: [StandardComparator: Selector] = [
            .localizedStandard:
                #selector(NSString.localizedStandardCompare(_:)),
            .localizedStandard.flipped:
                #selector(NSString.localizedStandardCompare(_:)),
            .localized: #selector(NSString.localizedCompare(_:)),
            .localized.flipped: #selector(NSString.localizedCompare(_:)),
            .lexical: #selector(NSString.compare(_:)),
            .lexical.flipped: #selector(NSString.compare(_:)),
        ]
#else
        // https://github.com/apple/swift-foundation/issues/284
        private static let validAlgorithms: [StandardComparator: Bool] = [
            .lexical: true,
            .lexical.flipped: true,
        ]
#endif
        
        private var flipped: StandardComparator {
            var result = self
            result.order = self.order == .forward ? .reverse : .forward
            return result
        }

#if FOUNDATION_FRAMEWORK
        var associatedSelector: Selector {
            guard let selector = Self.validAlgorithms[self] else {
                fatalError("""
                Attempted to retreive selector from a \
                String.StandardSortComparator with an invalid configuration.
                """)
            }
            return selector
        }
#endif

        func equalsIgnoringOrder(_ other: Self) -> Bool {
            return options == other.options && isLocalized == other.isLocalized
        }

        enum CodingKeys: String, CodingKey {
            case options
            case isLocalized
            case order
        }

        /// The `String.CompareOptions` used in the
        /// `String.compare(_:,options:)`invocation that performs an
        /// equivalent comparison.
        fileprivate let options: String.CompareOptions

        /// If the comparator is localized.
        private let isLocalized: Bool

        public var order: SortOrder

        private init(options: String.CompareOptions, localized: Bool) {
            self.options = options
            self.isLocalized = localized
            self.order = .forward
        }

        /// Create a `StandardComparator` from the given `StandardComparator`
        /// with the given new `order`.
        ///
        /// - Parameters:
        ///     - base: The standard comparator to modify the order of.
        ///     - order: The initial order of the new `StandardComparator`.
        public init(_ base: StandardComparator, order: SortOrder = .forward) {
            self = base
            self.order = order
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let rawOptions = try container.decode(
                UInt.self, forKey: .options)
            options = String.CompareOptions(rawValue: rawOptions)
            isLocalized = try container.decode(Bool.self, forKey: .isLocalized)
            order = try container.decode(SortOrder.self, forKey: .order)
            // Check if the decoded value is one of the valid cases.
            // If in future, more flexibility is afforded to standard
            // string comparators, this restriction can be removed.
            if Self.validAlgorithms[self] == nil {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: container.codingPath,
                        debugDescription: """
                        Attempted to decode \
                        \(String(describing: Self.self)) in invalid \
                        configuration.
                        """))
            }
        }

        public func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
#if FOUNDATION_FRAMEWORK
            // https://github.com/apple/swift-foundation/issues/284
            
            if isLocalized {
                return lhs.compare(rhs, options: options, locale: Locale.current).withOrder(order)
            } else {
                return lhs.compare(rhs, options: options).withOrder(order)
            }
#else
            // TODO: Until compare(_:options:locale:) is ported to FoundationInternationalization, only support unlocalized
            return lhs.compare(rhs, options: options).withOrder(order)
#endif
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(options.rawValue)
            hasher.combine(isLocalized)
            hasher.combine(order)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(options.rawValue, forKey: .options)
            try container.encode(isLocalized, forKey: .isLocalized)
            try container.encode(order, forKey: .order)
        }
    }

    /// A `String` comparison performed using the given comparison options
    /// and locale.
    public struct Comparator: SortComparator, Codable, Sendable {
        enum CodingKeys: String, CodingKey {
            case options
            case locale
            case order
        }

        /// The options to use for comparison.
        public let options: String.CompareOptions

        /// The locale to use for comparison if the comparator is localized,
        /// otherwise nil.
        public let locale: Locale?

        public var order: SortOrder

#if FOUNDATION_FRAMEWORK
        // https://github.com/apple/swift-foundation/issues/284
        
        /// Creates a `String.Comparator` with the given `CompareOptions` and
        /// `Locale`.
        ///
        /// - Parameters:
        ///     - options: The options to use for comparison.
        ///     - locale: The locale to use for comparison. If `nil`, the
        ///       comparison is unlocalized.
        ///     - order: The initial order to use for ordered comparison.
        public init(options: String.CompareOptions, locale: Locale? = Locale.current, order: SortOrder = .forward) {
            self.options = options
            self.locale = locale
            self.order = order
        }
#else
        // TODO: Until we support String.compare(_:options:locale:) in FoundationInternationalization, only support unlocalized comparisons
        public init(options: String.CompareOptions, order: SortOrder = .forward) {
            self.options = options
            self.locale = nil
            self.order = order
        }
#endif

        /// Creates a `String.Comparator` that represents the same comparison
        /// as the given `String.StandardComparator`.
        ///
        /// - Parameters:
        ///    - standardComparison: The `String.StandardComparator` to convert.
        public init(_ standardComparison: StandardComparator) {
            self.order = standardComparison.order
            self.options = standardComparison.options
#if FOUNDATION_FRAMEWORK
            self.locale = Locale.current
#else
            // TODO: Until we support String.compare(_:options:locale:) in FoundationInternationalization, only support unlocalized comparisons
            // https://github.com/apple/swift-foundation/issues/284
            self.locale = nil
#endif
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let rawOptions = try container.decode(UInt.self, forKey: .options)
            options = String.CompareOptions(rawValue: rawOptions)
            locale = try container.decode(Locale?.self, forKey: .locale)
            order = try container.decode(SortOrder.self, forKey: .order)
        }

        public func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
#if FOUNDATION_FRAMEWORK
            return lhs.compare(rhs, options: options, locale: locale).withOrder(order)
#else
            // TODO: Until we support String.compare(_:options:locale:) in FoundationInternationalization, only support unlocalized comparisons
            // https://github.com/apple/swift-foundation/issues/284
            return lhs.compare(rhs, options: options).withOrder(order)
#endif
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(options.rawValue)
            hasher.combine(locale)
            hasher.combine(order)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(options.rawValue, forKey: .options)
            try container.encode(locale, forKey: .locale)
            try container.encode(order, forKey: .order)
        }
    }
}

// Provide access to standard string comparators via leading dot syntax
// in the generic case.
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension SortComparator where Self == String.Comparator {
#if FOUNDATION_FRAMEWORK
    // https://github.com/apple/swift-foundation/issues/284
    
    /// Compares `String`s as compared by the Finder.
    ///
    /// Uses a localized, numeric comparison in the current locale.
    ///
    /// The default `String.Comparator` used in `String` comparisons.
    public static var localizedStandard: String.Comparator {
        String.Comparator(.localizedStandard)
    }

    /// Compares `String`s using a localized comparison in the current
    /// locale.
    public static var localized: String.Comparator {
        String.Comparator(.localized)
    }
#endif

    /// Compares `String`s lexically.
    static var lexical: String.Comparator {
        String.Comparator(.lexical)
    }
}

