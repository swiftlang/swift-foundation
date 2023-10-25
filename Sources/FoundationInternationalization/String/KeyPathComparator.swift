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

/// Compares elements using a `KeyPath`, and a `SortComparator` which compares
/// elements of the `KeyPath`s `Value` type.
@_nonSendable
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct KeyPathComparator<Compared>: SortComparator {
    /// The key path to the property to be used for comparisons.
    public let keyPath: PartialKeyPath<Compared>

    public var order: SortOrder {
        get {
            comparator.order
        }
        set {
            comparator.order = newValue
        }
    }

    var comparator: AnySortComparator

    private let extractField: (Compared) -> Any

    /// Get the field at `cachedOffset` if there is one, otherwise
    /// access the field directly through the keypath.
    private static func getField<T>(ofType fieldType: T.Type, offset maybeOffset: Int?, from base: Compared, fallback keyPath: KeyPath<Compared, T>) -> T {
        guard let offset = maybeOffset else {
            return base[keyPath: keyPath]
        }
        return withUnsafePointer(to: base) { pointer in
            let rawPointer = UnsafeRawPointer(pointer)
            return rawPointer
                .advanced(by: offset)
                .assumingMemoryBound(to: fieldType)
                .pointee
        }
    }

    /// Creates a `KeyPathComparator` that orders values based on a property
    /// that conforms to the `Comparable` protocol.
    ///
    /// The underlying field comparison uses `ComparableComparator<Value>()`
    /// unless the keyPath points to a `String` in which case the default string
    /// comparator, `String.StandardComparator.localizedStandard`, will be used.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init<Value: Comparable>(_ keyPath: KeyPath<Compared, Value>, order: SortOrder = .forward) {
        self.keyPath = keyPath
        if Value.self is String.Type {
#if FOUNDATION_FRAMEWORK
            self.comparator = AnySortComparator(String.StandardComparator.localizedStandard)
#else
            // TODO: Until we support String.compare(_:options:locale:) in FoundationInternationalization, use the lexical default
            // https://github.com/apple/swift-foundation/issues/284
            self.comparator = AnySortComparator(String.StandardComparator.lexical)
#endif
        } else {
            self.comparator = AnySortComparator(ComparableComparator<Value>())
        }
        let cachedOffset = MemoryLayout<Compared>.offset(of: keyPath)
        self.extractField = {
            Self.getField(
                ofType: Value.self,
                offset: cachedOffset,
                from: $0,
                fallback: keyPath)
        }
        self.order = order
    }

    /// Creates a `KeyPathComparator` that orders values based on an optional
    /// property whose wrapped value conforms to the `Comparable` protocol.
    ///
    /// The resulting `KeyPathComparator` orders `nil` values first when in
    /// `forward` order.
    ///
    /// The underlying field comparison uses `ComparableComparator<Value>()`
    /// unless the keyPath points to a `String` in which case the default string
    /// comparator, `String.StandardComparator.localizedStandard`, will be used.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the field to use for the comparison.
    ///   - order: The initial order to use for comparison.
    public init<Value: Comparable>(_ keyPath: KeyPath<Compared, Value?>, order: SortOrder = .forward) {
        self.keyPath = keyPath
        if Value.self is String.Type {
#if FOUNDATION_FRAMEWORK
            self.comparator = AnySortComparator(OptionalComparator(String.StandardComparator.localizedStandard))
#else
            // TODO: Until we support String.compare(_:options:locale:) in FoundationInternationalization, use the lexical default
            // https://github.com/apple/swift-foundation/issues/284
            self.comparator = AnySortComparator(OptionalComparator(String.StandardComparator.lexical))
#endif
        } else {
            self.comparator = AnySortComparator(OptionalComparator(ComparableComparator<Value>()))
        }
        let cachedOffset = MemoryLayout<Compared>.offset(of: keyPath)
        self.extractField = {
            Self.getField(
                ofType: Value?.self,
                offset: cachedOffset,
                from: $0,
                fallback: keyPath) as Any
        }
        self.order = order
    }

    /// Creates a `KeyPathComparator` with the given `keyPath` and
    /// `SortComparator`.
    ///
    /// `comparator.order` is used for the initial `order` of the created
    /// `KeyPathComparator`.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the value used for the comparison.
    ///   - comparator: The `SortComparator` used to order values.
    public init<Value, Comparator: SortComparator> (_ keyPath: KeyPath<Compared, Value>, comparator: Comparator) where Comparator.Compared == Value {
        self.keyPath = keyPath
        self.comparator = AnySortComparator(comparator)
        let cachedOffset = MemoryLayout<Compared>.offset(of: keyPath)
        self.extractField = {
            Self.getField(
                ofType: Value.self,
                offset: cachedOffset,
                from: $0,
                fallback: keyPath)
        }
    }

    /// Creates a `KeyPathComparator` with the given `keyPath` to an optional
    /// value and `SortComparator`.
    ///
    /// The resulting `KeyPathComparator` orders `nil` values first when in
    /// `forward` order.
    ///
    /// `comparator.order` is used for the initial `order` of the created
    /// `KeyPathComparator`.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the value used for the comparison.
    ///   - comparator: The `SortComparator` used to order values.
    public init<Value, Comparator: SortComparator> (_ keyPath: KeyPath<Compared, Value?>, comparator: Comparator) where Comparator.Compared == Value {
        self.keyPath = keyPath
        self.comparator = AnySortComparator(OptionalComparator(comparator))
        let cachedOffset = MemoryLayout<Compared>.offset(of: keyPath)
        self.extractField = {
            Self.getField(
                ofType: Value?.self,
                offset: cachedOffset,
                from: $0,
                fallback: keyPath) as Any
        }
    }

    /// Creates a `KeyPathComparator` with the given `keyPath`,
    /// `SortComparator`, and initial order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the value used for the comparison.
    ///   - comparator: The `SortComparator` used to order values.
    ///   - order: The initial order to use for comparison.
    public init<Value, Comparator: SortComparator> (_ keyPath: KeyPath<Compared, Value>, comparator: Comparator, order: SortOrder) where Comparator.Compared == Value {
        self.keyPath = keyPath
        self.comparator = AnySortComparator(comparator)
        let cachedOffset = MemoryLayout<Compared>.offset(of: keyPath)
        self.extractField = {
            Self.getField(
                ofType: Value.self,
                offset: cachedOffset,
                from: $0,
                fallback: keyPath)
        }
        self.order = order
    }

    /// Creates a `KeyPathComparator` with the given `keyPath`,
    /// `SortComparator`, and initial order.
    ///
    ///  The resulting `KeyPathComparator` orders `nil` values first when in
    /// `forward` order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the value used for the comparison.
    ///   - comparator: The `SortComparator` used to order values.
    ///   - order: The initial order to use for comparison.
    public init<Value, Comparator: SortComparator> (_ keyPath: KeyPath<Compared, Value?>, comparator: Comparator, order: SortOrder) where Comparator.Compared == Value {
        self.keyPath = keyPath
        self.comparator = AnySortComparator(OptionalComparator(comparator))
        let cachedOffset = MemoryLayout<Compared>.offset(of: keyPath)
        self.extractField = {
            Self.getField(
                ofType: Value?.self,
                offset: cachedOffset,
                from: $0,
                fallback: keyPath) as Any
        }
        self.order = order
    }

    public func compare(_ lhs: Compared, _ rhs: Compared) -> ComparisonResult {
        let lhsField = extractField(lhs)
        let rhsField = extractField(rhs)
        return self.comparator.compare(lhsField, rhsField)
    }

    public static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.keyPath == rhs.keyPath && lhs.comparator == rhs.comparator
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(keyPath)
        hasher.combine(comparator)
    }
}
