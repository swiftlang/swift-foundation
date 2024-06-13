//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

/// A serializable description of how to sort numeric and `String` types.
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct SortDescriptor<Compared>: SortComparator, Codable, Sendable {    
    /// The set of supported safely serializable comparisons.
    enum AllowedComparison: Hashable, Codable {
        /// Compare `String` by retrieving from key path, using using the given standard string comparator.
        case comparableString(String.StandardComparator, KeyPath<Compared, String>)
        
        /// Compare `String?` by retrieving from key path, using using the given standard string comparator.
        case comparableOptionalString(String.StandardComparator, KeyPath<Compared, String?>)
        
        /// Compares using `Swift.Comparable` implementation.
        case comparable(AnySortComparator, PartialKeyPath<Compared>)
        
#if FOUNDATION_FRAMEWORK
        /// Compares using the `compare` selector on the given type.
        case compare
        
        /// Compares `String`s using the given standard string comparator.
        case compareString(String.StandardComparator)
#endif

        enum CodingKeys: String, CodingKey {
            case rawValue
            case stringComparator
        }

        // This compatibility definition of == and hash are only needed for the swift 5.x compiler, which can't automatically generate it due to the Sendable conformance
#if compiler(<6.0)
        static func ==(lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.comparableString(let lhsComp, let lhsKeypath), .comparableString(let rhsComp, let rhsKeypath)):
                return lhsComp == rhsComp && lhsKeypath == rhsKeypath
            case (.comparableOptionalString(let lhsComp, let lhsKeypath), .comparableOptionalString(let rhsComp, let rhsKeypath)):
                return lhsComp == rhsComp && lhsKeypath == rhsKeypath
            case (.comparable(let lhsComp, let lhsKeypath), .comparable(let rhsComp, let rhsKeypath)):
                return lhsComp == rhsComp && lhsKeypath == rhsKeypath
#if FOUNDATION_FRAMEWORK
            case (.compare, .compare):
                return true
            case (.compareString(let lhsComp), .compareString(let rhsComp)):
                return lhsComp == rhsComp
#endif
            default:
                return false
            }
        }
        
        func hash(into hasher: inout Hasher) {
            switch self {
            case .comparableString(let comp, let kp):
                hasher.combine(comp)
                hasher.combine(kp)
            case .comparableOptionalString(let comp, let kp):
                hasher.combine(comp)
                hasher.combine(kp)
            case .comparable(let comp, let kp):
                hasher.combine(comp)
                hasher.combine(kp)
#if FOUNDATION_FRAMEWORK
            case .compare:
                hasher.combine(1)
            case .compareString(let comp):
                hasher.combine(comp)
#endif
            }
        }
#endif
        
#if FOUNDATION_FRAMEWORK
        fileprivate var selector: Selector {
            switch self {
            case .compare:
                return #selector(NSNumber.compare(_:))
            case let .compareString(comparator):
                return comparator.associatedSelector
            case .comparable, .comparableString, .comparableOptionalString:
                fatalError("Accessing `selector` for `comparable` comparison")
            }
        }
#endif

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let rawValue = try container.decode(UInt.self, forKey: .rawValue)
            switch rawValue {
            case 0: 
#if FOUNDATION_FRAMEWORK
                self = .compare
#else
                throw DecodingError.dataCorruptedError(
                    forKey: .rawValue,
                    in: container,
                    debugDescription: "`compare` is not supported on this platform.")
#endif
            case 1:
#if FOUNDATION_FRAMEWORK
                let comparator = try container.decode(String.StandardComparator.self, forKey: .stringComparator)
                if comparator.equalsIgnoringOrder(.lexical) {
                    throw DecodingError.dataCorruptedError(
                        forKey: .rawValue,
                        in: container,
                        debugDescription: """
                        Attempted to decode `AllowedSelector` in invalid
                        configuration.
                        """)
                }
                self = .compareString(comparator)
#else
                throw DecodingError.dataCorruptedError(
                    forKey: .rawValue,
                    in: container,
                    debugDescription: "`compareString` is not supported on this platform.")
#endif
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .rawValue,
                    in: container,
                    debugDescription: """
                    Attempted to decode `AllowedSelector` in invalid
                    configuration.
                    """)
            }
        }

#if FOUNDATION_FRAMEWORK
        fileprivate init?(fromSelector selector: Selector) {
            switch NSStringFromSelector(selector) {
            case "compare:":
                self = .compare
            case "localizedStandardCompare:":
                self = .compareString(.localizedStandard)
            case "localizedCompare:":
                self = .compareString(.localized)
            default:
                return nil
            }
        }
#endif
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
#if FOUNDATION_FRAMEWORK
            case .compare:
                try container.encode(0, forKey: .rawValue)
            case let .compareString(comparator):
                try container.encode(1, forKey: .rawValue)
                try container.encode(comparator, forKey: .stringComparator)
#endif
            case .comparable, .comparableString, .comparableOptionalString:
                throw EncodingError.invalidValue(
                    self,
                    .init(
                        codingPath: [],
                        debugDescription: """
                            Encoding SortDescriptor with values of type \
                            non-NSObject `Compared` is unsupported.
                            """
                    )
                )
            }
        }
    }

    /// The key path to the field for comparison.
    ///
    /// This value is `nil` when `Compared` is not an NSObject
    @available(FoundationPreview 0.1, *)
    public var keyPath: PartialKeyPath<Compared>? {
        switch comparison {
        case .comparable(_, let keyPath):
            return keyPath
        case .comparableString(_, let keyPath):
            return keyPath
        case .comparableOptionalString(_, let keyPath):
            return keyPath
#if FOUNDATION_FRAMEWORK
        case .compare, .compareString(_:):
            return nil
#endif
        }
    }

    /// A `String.StandardComparator` value.
    ///
    /// This property is non-`nil` when the `SortDescriptor` value is created
    /// with one.
    @available(FoundationPreview 0.1, *)
    public var stringComparator: String.StandardComparator? {
        var result: String.StandardComparator?
        switch comparison {
        case .comparableString(let comparator, _):
            result = comparator
        case .comparableOptionalString(let comparator, _):
            result = comparator
#if FOUNDATION_FRAMEWORK
        case .compareString(let comparator):
            result = comparator
#endif
        default:
            result = nil
        }

        result?.order = .forward
        return result
    }

    /// Sort order.
    public var order: SortOrder

    /// The `String` key specifying the property to be compared.
    let keyString: String?

    /// The comparison used to compare specified properties.
    let comparison: AllowedComparison


    // MARK: - Initializers for supported types.

    /// Creates a `SortDescriptor` that orders values based on a `Value`'s
    /// `Comparable` implementation.
    ///
    /// Instances of `SortDescriptor` created with this initializer should not
    /// be used to convert to `NSSortDescriptor`.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    @available(FoundationPreview 0.1, *)
    public init<Value>(_ keyPath: KeyPath<Compared, Value>, order: SortOrder = .forward) where Value: Comparable {
        self.order = order
        self.keyString = nil
        self.comparison = .comparable(
            AnySortComparator(ComparableComparator<Value>(order: order)),
            keyPath
        )
    }

    /// Creates a `SortDescriptor` that orders values based on a `Value`'s
    /// `Comparable` implementation.
    ///
    ///  The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// Instances of `SortDescriptor` created with this initializer should not
    /// be used to convert to `NSSortDescriptor`.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    @available(FoundationPreview 0.1, *)
    public init<Value>(_ keyPath: KeyPath<Compared, Value?>, order: SortOrder = .forward) where Value: Comparable {
        self.order = order
        self.keyString = nil
        self.comparison = .comparable(
            AnySortComparator(OptionalComparator(ComparableComparator<Value>(order: order))),
            keyPath
        )
    }

#if FOUNDATION_FRAMEWORK
    // TODO: On Darwin, the following initializers use `.localizedStandard` as the default value. Without String.compare(_:options:locale:), we have to leave the default un-set for other platforms. Once we have it, we can re-unify the behavior again.
    // https://github.com/apple/swift-foundation/issues/284
    
    /// Creates a `SortDescriptor` that orders optional values using the given
    /// standard string comparator.
    ///
    /// `comparator.order` is used for the initial `order` of the
    /// created `SortDescriptor`.
    ///
    ///  The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// Instances of `SortDescriptor` created with this initializer should not
    /// be used to convert to `NSSortDescriptor`.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for comparison.
    ///   - comparator: The standard string comparator to use for comparison.
    @available(FoundationPreview 0.1, *)
    public init(_ keyPath: KeyPath<Compared, String>, comparator: String.StandardComparator = .localizedStandard) {
        self.order = comparator.order
        self.keyString = nil
        self.comparison = .comparableString(comparator, keyPath)
    }

    /// Creates a `SortDescriptor` that orders optional values using the given
    /// standard string comparator.
    ///
    /// `comparator.order` is used for the initial `order` of the
    /// created `SortDescriptor`.
    ///
    ///  The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for comparison.
    ///   - comparator: The standard string comparator to use for comparison.
    @available(FoundationPreview 0.1, *)
    public init(_ keyPath: KeyPath<Compared, String?>, comparator: String.StandardComparator = .localizedStandard) {
        self.order = comparator.order
        self.keyString = nil
        self.comparison = .comparableOptionalString(comparator, keyPath)
    }

    /// Creates a `SortDescriptor` that orders optional values using the given
    /// standard string comparator.
    ///
    ///  The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// Instances of `SortDescriptor` created with this initializer should not
    /// be used to convert to `NSSortDescriptor`.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for comparison.
    ///   - comparator: The standard string comparator to use for comparison.
    ///   - order: The initial order to use for comparison.
    @available(FoundationPreview 0.1, *)
    public init(_ keyPath: KeyPath<Compared, String>, comparator: String.StandardComparator = .localizedStandard, order: SortOrder) {
        self.order = order
        self.keyString = nil
        var comparator = comparator
        comparator.order = order
        self.comparison = .comparableString(comparator, keyPath)
    }

    /// Creates a `SortDescriptor` that orders optional values using the given
    /// standard string comparator.
    ///
    /// `comparator.order` is used for the initial `order` of the
    /// created `SortDescriptor`.
    ///
    ///  The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for comparison.
    ///   - comparator: The standard string comparator to use for comparison.
    ///   - order: The initial order to use for comparison.
    @available(FoundationPreview 0.1, *)
    public init(_ keyPath: KeyPath<Compared, String?>, comparator: String.StandardComparator = .localizedStandard, order: SortOrder) {
        self.order = order
        self.keyString = nil
        var comparator = comparator
        comparator.order = order
        self.comparison = .comparableOptionalString(comparator, keyPath)
    }
#else
    /// Temporarily available as a replacement for `init(_:comparator:)` with a default argument.
    public init(_ keyPath: KeyPath<Compared, String>, comparator: String.StandardComparator) {
        self.order = comparator.order
        self.keyString = nil
        self.comparison = .comparableString(comparator, keyPath)
    }

    /// Temporarily available as a replacement for `init(_:comparator:)` with a default argument.
    public init(_ keyPath: KeyPath<Compared, String?>, comparator: String.StandardComparator) {
        self.order = comparator.order
        self.keyString = nil
        self.comparison = .comparableOptionalString(comparator, keyPath)
    }

    /// Temporarily available as a replacement for `init(_:comparator:)` with a default argument.
    public init(_ keyPath: KeyPath<Compared, String>, comparator: String.StandardComparator, order: SortOrder) {
        self.order = order
        self.keyString = nil
        var comparator = comparator
        comparator.order = order
        self.comparison = .comparableString(comparator, keyPath)
    }

    /// Temporarily available as a replacement for `init(_:comparator:)` with a default argument.
    public init(_ keyPath: KeyPath<Compared, String?>, comparator: String.StandardComparator, order: SortOrder) {
        self.order = order
        self.keyString = nil
        var comparator = comparator
        comparator.order = order
        self.comparison = .comparableOptionalString(comparator, keyPath)
    }
#endif

#if FOUNDATION_FRAMEWORK
    
    // We provide individual initializers for all supported types to ensure that we don't allow creation with custom types that conform to standard library numeric protocols.
    // These types are all NSObject-based, so only valid in the framework.

    /// Creates a `SortDescriptor` that orders values based on a `Bool`
    /// property.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Bool>, order: SortOrder = .forward) where Compared: NSObject {
        self.init(uncheckedCompareBasedKeyPath: keyPath, order: order)
    }

    /// Creates a `SortDescriptor` that orders values based on a `Bool?`
    /// property.
    ///
    /// The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Bool?>, order: SortOrder = .forward) where Compared: NSObject {
        self.init(uncheckedCompareBasedKeyPath: keyPath, order: order)
    }

    /// Creates a `SortDescriptor` that orders values based on a `Double`
    /// property.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Double>, order: SortOrder = .forward) where Compared: NSObject {
        self.init(uncheckedCompareBasedKeyPath: keyPath, order: order)
    }

    /// Creates a `SortDescriptor` that orders values based on a `Double?`
    /// property.
    ///
    /// The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Double?>, order: SortOrder = .forward) where Compared: NSObject {
        self.init(uncheckedCompareBasedKeyPath: keyPath, order: order)
    }

    /// Creates a `SortDescriptor` that orders values based on a `Float`
    /// property.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Float>, order: SortOrder = .forward) where Compared: NSObject {
        self.init(uncheckedCompareBasedKeyPath: keyPath, order: order)
    }

    /// Creates a `SortDescriptor` that orders values based on a `Float?`
    /// property.
    ///
    /// The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Float?>, order: SortOrder = .forward) where Compared: NSObject {
        self.init(uncheckedCompareBasedKeyPath: keyPath, order: order)
    }

    /// Creates a `SortDescriptor` that orders values based on a `Int8`
    /// property.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Int8>, order: SortOrder = .forward) where Compared: NSObject {
        self.init(uncheckedCompareBasedKeyPath: keyPath, order: order)
    }

    /// Creates a `SortDescriptor` that orders values based on a `Int8?`
    /// property.
    ///
    /// The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Int8?>, order: SortOrder = .forward) where Compared: NSObject {
        self.init(uncheckedCompareBasedKeyPath: keyPath, order: order)
    }


    /// Creates a `SortDescriptor` that orders values based on a `Int16`
    /// property.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Int16>, order: SortOrder = .forward) where Compared: NSObject {
        self.init(uncheckedCompareBasedKeyPath: keyPath, order: order)
    }

    /// Creates a `SortDescriptor` that orders values based on a `Int16?`
    /// property.
    ///
    /// The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Int16?>, order: SortOrder = .forward) where Compared: NSObject {
        self.init(uncheckedCompareBasedKeyPath: keyPath, order: order)
    }

    /// Creates a `SortDescriptor` that orders values based on a `Int32`
    /// property
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Int32>, order: SortOrder = .forward) where Compared: NSObject {
        self.init(uncheckedCompareBasedKeyPath: keyPath, order: order)
    }

    /// Creates a `SortDescriptor` that orders values based on a `Int32?`
    /// property.
    ///
    /// The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Int32?>, order: SortOrder = .forward) where Compared: NSObject {
        self.init(uncheckedCompareBasedKeyPath: keyPath, order: order)
    }

    /// Creates a `SortDescriptor` that orders values based on a `Int64`
    /// property.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Int64>, order: SortOrder = .forward) where Compared: NSObject {
        self.init(uncheckedCompareBasedKeyPath: keyPath, order: order)
    }

    /// Creates a `SortDescriptor` that orders values based on a `Int64?`
    /// property.
    ///
    /// The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Int64?>, order: SortOrder = .forward) where Compared: NSObject {
        self.init(uncheckedCompareBasedKeyPath: keyPath, order: order)
    }

    /// Creates a `SortDescriptor` that orders values based on a `Int`
    /// property.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Int>, order: SortOrder = .forward) where Compared: NSObject {
        self.init(uncheckedCompareBasedKeyPath: keyPath, order: order)
    }

    /// Creates a `SortDescriptor` that orders values based on a `Int?`
    /// property.
    ///
    /// The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Int?>, order: SortOrder = .forward) where Compared: NSObject {
        self.init(uncheckedCompareBasedKeyPath: keyPath, order: order)
    }

    /// Creates a `SortDescriptor` that orders values based on a `UInt8`
    /// property.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, UInt8>, order: SortOrder = .forward) where Compared: NSObject {
        self.init(uncheckedCompareBasedKeyPath: keyPath, order: order)
    }

    /// Creates a `SortDescriptor` that orders values based on a `UInt8?`
    /// property.
    ///
    /// The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, UInt8?>, order: SortOrder = .forward) where Compared: NSObject {
        self.init(uncheckedCompareBasedKeyPath: keyPath, order: order)
    }

    /// Creates a `SortDescriptor` that orders values based on a `UInt16`
    /// property.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, UInt16>, order: SortOrder = .forward) where Compared: NSObject {
        self.init(uncheckedCompareBasedKeyPath: keyPath, order: order)
    }

    /// Creates a `SortDescriptor` that orders values based on a `UInt16?`
    /// property.
    ///
    /// The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, UInt16?>, order: SortOrder = .forward) where Compared: NSObject {
        self.init(uncheckedCompareBasedKeyPath: keyPath, order: order)
    }

    /// Creates a `SortDescriptor` that orders values based on a `UInt32`
    /// property.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, UInt32>, order: SortOrder = .forward) where Compared: NSObject {
        self.init(uncheckedCompareBasedKeyPath: keyPath, order: order)
    }

    /// Creates a `SortDescriptor` that orders values based on a `UInt32?`
    /// property.
    ///
    /// The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, UInt32?>, order: SortOrder = .forward) where Compared: NSObject {
        self.init(uncheckedCompareBasedKeyPath: keyPath, order: order)
    }

    /// Creates a `SortDescriptor` that orders values based on a `UInt64`
    /// property.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, UInt64>, order: SortOrder = .forward) where Compared: NSObject {
        self.init(uncheckedCompareBasedKeyPath: keyPath, order: order)
    }

    /// Creates a `SortDescriptor` that orders values based on a `UInt64?`
    /// property.
    ///
    /// The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, UInt64?>, order: SortOrder = .forward) where Compared: NSObject {
        self.init(uncheckedCompareBasedKeyPath: keyPath, order: order)
    }

    /// Creates a `SortDescriptor` that orders values based on a `UInt`
    /// property.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, UInt>, order: SortOrder = .forward) where Compared: NSObject {
        self.init(uncheckedCompareBasedKeyPath: keyPath, order: order)
    }

    /// Creates a `SortDescriptor` that orders values based on a `UInt?`
    /// property.
    ///
    /// The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, UInt?>, order: SortOrder = .forward) where Compared: NSObject {
        self.init(uncheckedCompareBasedKeyPath: keyPath, order: order)
    }

    /// Creates a `SortDescriptor` that orders values based on a `Date`
    /// property.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Date>, order: SortOrder = .forward) where Compared: NSObject {
        self.init(uncheckedCompareBasedKeyPath: keyPath, order: order)
    }

    /// Creates a `SortDescriptor` that orders values based on a `Date?`
    /// property.
    ///
    /// The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, Date?>, order: SortOrder = .forward) where Compared: NSObject {
        self.init(uncheckedCompareBasedKeyPath: keyPath, order: order)
    }

    /// Creates a `SortDescriptor` that orders values based on a `UUID`
    /// property.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, UUID>, order: SortOrder = .forward) where Compared: NSObject {
        self.init(uncheckedCompareBasedKeyPath: keyPath, order: order)
    }

    /// Creates a `SortDescriptor` that orders values based on a `UUID?`
    /// property.
    ///
    /// The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, UUID?>, order: SortOrder = .forward) where Compared: NSObject {
        self.init(uncheckedCompareBasedKeyPath: keyPath, order: order)
    }

    /// Creates a `SortDescriptor` that orders values using the given
    /// standard string comparator.
    ///
    /// `comparator.order` is used for the initial `order` of the
    /// created `SortDescriptor`.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for comparison.
    ///   - comparator: The standard string comparator to use for comparison.
    public init(_ keyPath: KeyPath<Compared, String>, comparator: String.StandardComparator = .localizedStandard) where Compared: NSObject {
        self.init(
            keyPath,
            comparator: comparator,
            order: comparator.order
        )
    }

    /// Creates a `SortDescriptor` that orders optional values using the given
    /// standard string comparator.
    ///
    /// `comparator.order` is used for the initial `order` of the
    /// created `SortDescriptor`.
    ///
    ///  The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for comparison.
    ///   - comparator: The standard string comparator to use for comparison.
    public init(_ keyPath: KeyPath<Compared, String?>, comparator: String.StandardComparator = .localizedStandard) where Compared: NSObject {
        self.init(
            keyPath,
            comparator: comparator,
            order: comparator.order
        )
    }

    /// Creates a `SortDescriptor` that orders values using the given
    /// standard string comparator with the given initial order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for comparison.
    ///   - comparator: The standard string comparator to use for comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, String>, comparator: String.StandardComparator = .localizedStandard, order: SortOrder) where Compared: NSObject {
        guard let keyString = keyPath._kvcKeyPathString else {
            fatalError("""
            \(String(describing: Compared.self)) must be introspectable by \
            the objective-c runtime in order to use it as the base type of \
            a `SortDescriptor`.
            """)
        }
        self.keyString = keyString
        self.order = order
        // `SortDescriptor` stores its own order, so set the passed comparator's
        // order to forward, and ignore it from this point on.
        var alwaysForwardComparator = comparator
        alwaysForwardComparator.order = .forward
        if comparator == .lexical {
            self.comparison = .compare
        } else {
            self.comparison = .compareString(alwaysForwardComparator)
        }
    }

    /// Creates a `SortDescriptor` that orders optional values using the given
    /// standard string comparator with the given initial order.
    ///
    /// The resulting `SortDescriptor` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for comparison.
    ///   - comparator: The standard string comparator to use for comparison.
    ///   - order: The initial order to use for comparison.
    public init(_ keyPath: KeyPath<Compared, String?>, comparator: String.StandardComparator = .localizedStandard, order: SortOrder) where Compared: NSObject {
        guard let keyString = keyPath._kvcKeyPathString else {
            fatalError("""
            \(String(describing: Compared.self)) must be introspectable by \
            the objective-c runtime in order to use it as the base type of \
            a `SortDescriptor`.
            """)
        }
        self.keyString = keyString
        self.order = order
        // `SortDescriptor` stores its own order, so set the passed comparator's
        // order to forward, and ignore it from this point on.
        var alwaysForwardComparator = comparator
        alwaysForwardComparator.order = .forward
        if comparator == .lexical {
            self.comparison = .compare
        } else {
            self.comparison = .compareString(alwaysForwardComparator)
        }
    }

    private init<Key>(uncheckedCompareBasedKeyPath keyPath: KeyPath<Compared, Key>, order: SortOrder) where Compared: NSObject {
        guard let keyString = keyPath._kvcKeyPathString else {
            fatalError("""
            \(String(describing: Compared.self)) must be introspectable by \
            the objective-c runtime in order to use it as the base type of \
            a `SortDescriptor`.
            """)
        }
        self.keyString = keyString
        self.order = order
        self.comparison = .compare
    }
    
#endif // FOUNDATION_FRAMEWORK
    

#if FOUNDATION_FRAMEWORK
    /// Creates a `SortDescriptor` describing the same sort as the
    /// `NSSortDescriptor` over the given `Compared` type.
    ///
    /// Returns `nil` if there is no `SortDescriptor` equivalent to the given
    /// `NSSortDescriptor`, or if the `NSSortDescriptor`s selector is not one of
    /// the standard string comparison algorithms, or `compare(_:)`.
    ///
    /// The comparison for the created `SortDescriptor` uses the
    /// `NSSortDescriptor`s associated selector directly, so in cases where
    /// using the `NSSortDescriptor`s comparison would crash, the
    /// `SortDescriptor`s comparison will as well.
    ///
    /// - Parameters:
    ///     - descriptor: The `NSSortDescriptor` to convert.
    ///     - comparedType: The type the resulting `SortDescriptor` compares.
    public init?(_ descriptor: NSSortDescriptor, comparing comparedType: Compared.Type) where Compared: NSObject {
        guard let keyString = descriptor.key else { return nil }
        guard let selector = descriptor.selector else { return nil }
        guard let comparison = AllowedComparison(
            fromSelector: selector) else { return nil }
        self.keyString = keyString
        self.order = descriptor.ascending ? .forward : .reverse
        self.comparison = comparison
    }
#endif
    
    public func compare(_ lhs: Compared, _ rhs: Compared) -> ComparisonResult {
        switch comparison {
        case .comparable(let comparator, let keyPath):
            // The following line is not needed for Swift 6 mode, but is here for temporary compatibility with the Swift 5.x compiler
#if compiler(<6.0)
            let kp = keyPath as PartialKeyPath<Compared>
#else
            let kp = keyPath
#endif
            return comparator.compare(
                lhs[keyPath: kp],
                rhs[keyPath: kp]
            )
        case .comparableString(let comparator, let keyPath):
#if compiler(<6.0)
            let kp = keyPath as KeyPath<Compared, String>
#else
            let kp = keyPath
#endif
            return comparator.compare(
                lhs[keyPath: kp],
                rhs[keyPath: kp]
            )
        case .comparableOptionalString(let comparator, let keyPath):
#if compiler(<6.0)
            let kp = keyPath as KeyPath<Compared, String?>
#else
            let kp = keyPath
#endif
            return switch (lhs[keyPath: kp], rhs[keyPath: kp]) {
            case (nil, nil):
                .orderedSame
            case (nil, _):
                order == .forward ? .orderedAscending : .orderedDescending
            case (_, nil):
                order == .forward ? .orderedDescending : .orderedAscending
            case let (lhsString?, rhsString?):
                comparator.compare(lhsString, rhsString)
            }
#if FOUNDATION_FRAMEWORK
        case .compare, .compareString(_):
            let bridged = NSSortDescriptor(_sortDescriptor: self)
            return bridged.compare(lhs, to: rhs)
#endif
        }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(keyString)
        hasher.combine(order)
        hasher.combine(comparison)
    }
}

#if FOUNDATION_FRAMEWORK

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension NSSortDescriptor {
    /// Creates an `NSSortDescriptor` representing the same sort as the given
    /// `SortDescriptor`.
    ///
    /// - Parameters:
    ///     - sortDescriptor: The `SortDescriptor` to convert.
    @backDeployed(before: iOS 17, macOS 14, tvOS 17, watchOS 10)
    public convenience init<Compared>(_ sortDescriptor: SortDescriptor<Compared>) where Compared: NSObject {
        self.init(_sortDescriptor: sortDescriptor)
    }

    @_alwaysEmitIntoClient
    public convenience init<Compared>(_sortDescriptor: SortDescriptor<Compared>) {
        self.init(_sortDescriptor)
    }

    @available(macOS, deprecated: 14,
               message: """
               Use `init(_:) where Compared: NSObject` instead. Attempt to \
               convert SortDescriptor with Compared being non-NSObject will \
               result in a fatalError at runtime.
               """)
    @available(iOS, deprecated: 17,
               message: """
               Use `init(_:) where Compared: NSObject` instead. Attempt to \
               convert SortDescriptor with Compared being non-NSObject will \
               result in a fatalError at runtime.
               """)
    @available(tvOS, deprecated: 17,
               message: """
               Use `init(_:) where Compared: NSObject` instead. Attempt to \
               convert SortDescriptor with Compared being non-NSObject will \
               result in a fatalError at runtime.
               """)
    @available(watchOS, deprecated: 10,
               message: """
               Use `init(_:) where Compared: NSObject` instead. Attempt to \
               convert SortDescriptor with Compared being non-NSObject will \
               result in a fatalError at runtime.
               """)
    @_disfavoredOverload
    public convenience init<Compared>(_ sortDescriptor: SortDescriptor<Compared>) {
        // This `init` used to unconditionally accept all `SortDescriptor`s,
        // which were guaranteed to have a valid `keyString` property because
        // the `Compared` value is an `NSObject`. This `init` was deprecated
        // because we introduced ways to create `SortDescriptor` values that do
        // not have such valid properties. At the deprecation, we introduced an
        // replacement `init` that requires `Compared: NSObject`, providing the
        // same level of always-valid-conversion to existing users.
        //
        // Under certain circumstances (new code linking against old,
        // third-party binary that make calls to this `init`, for example),
        // a `SortDescriptor` whose `Compared` isn't `NSObject` can get passed
        // here. Instead of silently creating an invalid `NSSortDescriptor`,
        // we'll fatalError to prevent the `NSSortDescriptor` from propagating
        // further into user's program, which may result in data loss.
        guard let keyString = sortDescriptor.keyString else {
            fatalError("""
                Attempt to convert SortDescriptor with Compared being \
                non-NSObject
                """)
        }

        self.init(
            key: keyString,
            ascending: sortDescriptor.order == .forward,
            selector: sortDescriptor.comparison.selector)
    }

}

#endif
