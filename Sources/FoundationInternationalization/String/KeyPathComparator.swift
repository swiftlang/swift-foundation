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

/// A comparator that uses another sort comparator to provide the comparison of values at a key path.
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct KeyPathComparator<Compared>: SortComparator {
    /// The key path that the comparator uses to compare properties.
    @preconcurrency
    public let keyPath: PartialKeyPath<Compared> & Sendable

    /// The sort order that the comparator uses to compare properties.
    public var order: SortOrder {
        didSet { comparator.order = order }
    }

    /// A type-erased copy of the underlying comparator, retained only for the cold paths: `==`, `hash(into:)`, and keeping `order` observable. It is never consulted by `compare(_:_:)`.
    var comparator: AnySortComparator

    /// The hot path: a fully-typed comparison of two `Compared` values that extracts the keyed field and compares it *in forward order*, with no `Any` boxing and no dynamic casts. `compare(_:_:)` applies the current `order` on top via `withOrder`.
    private let _compare: @Sendable (Compared, Compared) -> ComparisonResult

    /// Reads the field of type `T` at a known stored-property `offset` within `base`. `T` is passed as an argument rather than a metatype captured by the caller's `@Sendable` closure, which would be non-`Sendable`.
    @inline(always)
    private static func getField<T>(offset: Int, from base: Compared, as type: T.Type) -> T {
        return withUnsafePointer(to: base) { pointer in
            UnsafeRawPointer(pointer)
                .advanced(by: offset)
                .assumingMemoryBound(to: T.self)
                .pointee
        }
    }

    /// Builds the fully-typed forward comparison closure for a field of type `Field` compared by `fieldComparator` (which must be in `.forward` order).
    ///
    /// This is the cast-free hot path: the field is read as its concrete type and `fieldComparator.compare` is invoked directly, so no value is ever boxed into `Any` and no dynamic cast occurs per comparison. When the field is a stored property (`offset != nil`) it is read at its byte offset; otherwise it is accessed through the key path.
    private static func makeCompare<Field, FieldComparator: SortComparator>(
        keyPath: KeyPath<Compared, Field> & Sendable,
        offset: Int?,
        fieldComparator: FieldComparator
    ) -> @Sendable (Compared, Compared) -> ComparisonResult where FieldComparator.Compared == Field {
        if let offset {
            return { lhs, rhs in
                let lhsField = getField(offset: offset, from: lhs, as: Field.self)
                let rhsField = getField(offset: offset, from: rhs, as: Field.self)
                return fieldComparator.compare(lhsField, rhsField)
            }
        }
        return { lhs, rhs in
            fieldComparator.compare(lhs[keyPath: keyPath], rhs[keyPath: keyPath])
        }
    }

    // A temporary workaround to a compiler bug that changes the ABI when adding the & Sendable constraint
    // Should be removed and the related functions should be made public when rdar://131764614 is resolved
    @_alwaysEmitIntoClient
    public init<Value: Comparable>(_ keyPath: KeyPath<Compared, Value> & Sendable, order: SortOrder = .forward) {
        self.init(keyPath as KeyPath<Compared, Value>, order: order)
    }
    
    @_alwaysEmitIntoClient
    public init<Value: Comparable>(_ keyPath: KeyPath<Compared, Value?> & Sendable, order: SortOrder = .forward) {
        self.init(keyPath as KeyPath<Compared, Value?>, order: order)
    }
    
    @_alwaysEmitIntoClient
    public init<Value, Comparator: SortComparator> (_ keyPath: KeyPath<Compared, Value> & Sendable, comparator: Comparator) where Comparator.Compared == Value {
        self.init(keyPath as KeyPath<Compared, Value>, comparator: comparator)
    }
    
    @_alwaysEmitIntoClient
    public init<Value, Comparator: SortComparator> (_ keyPath: KeyPath<Compared, Value?> & Sendable, comparator: Comparator) where Comparator.Compared == Value {
        self.init(keyPath as KeyPath<Compared, Value?>, comparator: comparator)
    }
    
    @_alwaysEmitIntoClient
    public init<Value, Comparator: SortComparator> (_ keyPath: KeyPath<Compared, Value> & Sendable, comparator: Comparator, order: SortOrder) where Comparator.Compared == Value {
        self.init(keyPath as KeyPath<Compared, Value>, comparator: comparator, order: order)
    }
    
    @_alwaysEmitIntoClient
    public init<Value, Comparator: SortComparator> (_ keyPath: KeyPath<Compared, Value?> & Sendable, comparator: Comparator, order: SortOrder) where Comparator.Compared == Value {
        self.init(keyPath as KeyPath<Compared, Value?>, comparator: comparator, order: order)
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
    /*public*/ @usableFromInline init<Value: Comparable>(_ keyPath: KeyPath<Compared, Value>, order: SortOrder = .forward) {
        let sendableKP = keyPath._unsafeAssumeSendable
        self.keyPath = sendableKP
        let cachedOffset = MemoryLayout<Compared>.offset(of: keyPath)
        if Value.self is String.Type {
#if FOUNDATION_FRAMEWORK
            let stringComparator = String.StandardComparator.localizedStandard
#else
            // TODO: Until we support String.compare(_:options:locale:) in FoundationInternationalization, use the lexical default
            // https://github.com/apple/swift-foundation/issues/284
            let stringComparator = String.StandardComparator.lexical
#endif
            self.comparator = AnySortComparator(stringComparator)
            // `Value` is statically opaque but dynamically `String`; retype the key path once here (not per comparison) so the hot path is fully typed and captures no non-Sendable metatype.
            let stringKeyPath = sendableKP as! (KeyPath<Compared, String> & Sendable)
            self._compare = Self.makeCompare(keyPath: stringKeyPath, offset: cachedOffset, fieldComparator: stringComparator)
        } else {
            let fieldComparator = ComparableComparator<Value>()
            self.comparator = AnySortComparator(fieldComparator)
            self._compare = Self.makeCompare(keyPath: sendableKP, offset: cachedOffset, fieldComparator: fieldComparator)
        }
        self.order = order
        self.comparator.order = order
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
    /*public*/ @usableFromInline init<Value: Comparable>(_ keyPath: KeyPath<Compared, Value?>, order: SortOrder = .forward) {
        let sendableKP = keyPath._unsafeAssumeSendable
        self.keyPath = sendableKP
        let cachedOffset = MemoryLayout<Compared>.offset(of: keyPath)
        if Value.self is String.Type {
#if FOUNDATION_FRAMEWORK
            let fieldComparator = OptionalComparator(String.StandardComparator.localizedStandard)
#else
            // TODO: Until we support String.compare(_:options:locale:) in FoundationInternationalization, use the lexical default
            // https://github.com/apple/swift-foundation/issues/284
            let fieldComparator = OptionalComparator(String.StandardComparator.lexical)
#endif
            self.comparator = AnySortComparator(fieldComparator)
            // Retype `KeyPath<Compared, Value?>` -> `KeyPath<Compared, String?>` once here so the hot path is fully typed (see the non-optional case).
            let stringKeyPath = sendableKP as! (KeyPath<Compared, String?> & Sendable)
            self._compare = Self.makeCompare(keyPath: stringKeyPath, offset: cachedOffset, fieldComparator: fieldComparator)
        } else {
            let fieldComparator = OptionalComparator(ComparableComparator<Value>())
            self.comparator = AnySortComparator(fieldComparator)
            self._compare = Self.makeCompare(keyPath: sendableKP, offset: cachedOffset, fieldComparator: fieldComparator)
        }
        self.order = order
        self.comparator.order = order
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
    /*public*/ @usableFromInline init<Value, Comparator: SortComparator> (_ keyPath: KeyPath<Compared, Value>, comparator: Comparator) where Comparator.Compared == Value {
        let sendableKP = keyPath._unsafeAssumeSendable
        self.keyPath = sendableKP
        let cachedOffset = MemoryLayout<Compared>.offset(of: keyPath)
        self.comparator = AnySortComparator(comparator)
        var forwardComparator = comparator
        forwardComparator.order = .forward
        self._compare = Self.makeCompare(keyPath: sendableKP, offset: cachedOffset, fieldComparator: forwardComparator)
        self.order = comparator.order
        self.comparator.order = comparator.order
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
    /*public*/ @usableFromInline init<Value, Comparator: SortComparator> (_ keyPath: KeyPath<Compared, Value?>, comparator: Comparator) where Comparator.Compared == Value {
        let sendableKP = keyPath._unsafeAssumeSendable
        self.keyPath = sendableKP
        let cachedOffset = MemoryLayout<Compared>.offset(of: keyPath)
        self.comparator = AnySortComparator(OptionalComparator(comparator))
        var forwardComparator = comparator
        forwardComparator.order = .forward
        let forwardOptional = OptionalComparator(forwardComparator)
        self._compare = Self.makeCompare(keyPath: sendableKP, offset: cachedOffset, fieldComparator: forwardOptional)
        self.order = comparator.order
        self.comparator.order = comparator.order
    }

    /// Creates a `KeyPathComparator` with the given `keyPath`,
    /// `SortComparator`, and initial order.
    ///
    /// - Parameters:
    ///   - keyPath: The key path to the value used for the comparison.
    ///   - comparator: The `SortComparator` used to order values.
    ///   - order: The initial order to use for comparison.
    /*public*/ @usableFromInline init<Value, Comparator: SortComparator> (_ keyPath: KeyPath<Compared, Value>, comparator: Comparator, order: SortOrder) where Comparator.Compared == Value {
        let sendableKP = keyPath._unsafeAssumeSendable
        self.keyPath = sendableKP
        let cachedOffset = MemoryLayout<Compared>.offset(of: keyPath)
        self.comparator = AnySortComparator(comparator)
        var forwardComparator = comparator
        forwardComparator.order = .forward
        self._compare = Self.makeCompare(keyPath: sendableKP, offset: cachedOffset, fieldComparator: forwardComparator)
        self.order = order
        self.comparator.order = order
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
    /*public*/ @usableFromInline init<Value, Comparator: SortComparator> (_ keyPath: KeyPath<Compared, Value?>, comparator: Comparator, order: SortOrder) where Comparator.Compared == Value {
        let sendableKP = keyPath._unsafeAssumeSendable
        self.keyPath = sendableKP
        let cachedOffset = MemoryLayout<Compared>.offset(of: keyPath)
        self.comparator = AnySortComparator(OptionalComparator(comparator))
        var forwardComparator = comparator
        forwardComparator.order = .forward
        let forwardOptional = OptionalComparator(forwardComparator)
        self._compare = Self.makeCompare(keyPath: sendableKP, offset: cachedOffset, fieldComparator: forwardOptional)
        self.order = order
        self.comparator.order = order
    }

    /// Provides the relative ordering of two items according to the ordering of the properties that the comparator's key path references.
    ///
    /// The method returns flipped comparisons if the sort order is ``SortOrder/reverse``.
    ///
    /// - Parameters:
    ///   - lhs: The first property to compare.
    ///   - rhs: The second property to compare.
    /// - Returns: The relative ordering for the compared properties.
    public func compare(_ lhs: Compared, _ rhs: Compared) -> ComparisonResult {
        return _compare(lhs, rhs).withOrder(order)
    }

    public static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.keyPath == rhs.keyPath && lhs.comparator == rhs.comparator
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(keyPath)
        hasher.combine(comparator)
    }
}
