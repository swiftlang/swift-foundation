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

/// A comparison algorithm for a specified type.
///
/// Objects that conform to ``SortComparator`` provide a comparison algorithm and storage for the sort order to use when comparing.
@preconcurrency
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public protocol SortComparator<Compared>: Hashable, Sendable {
    /// A type that the sort comparator can compare.
    associatedtype Compared

    /// Provides the relative ordering of two elements based on the sort order
    /// of the comparator.
    ///
    /// The result of comparisons should be flipped if the current `order`
    /// is `reverse`.
    ///
    /// If `compare(lhs, rhs)` is `.orderedAscending`, then `compare(rhs, lhs)`
    /// must be `.orderedDescending`. If `compare(lhs, rhs)` is
    /// `.orderedDescending`, then `compare(rhs, lhs)` must be
    /// `.orderedAscending`.
    ///
    /// - Parameters:
    ///     - lhs: A value to compare.
    ///     - rhs: A value to compare.
    /// - Returns: The relative ordering of the two values.
    func compare(_ lhs: Compared, _ rhs: Compared) -> ComparisonResult

    /// The sort order that the comparator uses to compare.
    var order: SortOrder { get set }
}

/// The orderings that you can perform sorts with.
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@frozen
public enum SortOrder: Hashable, Codable, Sendable {
    /// The ordering that places the first item before the second when comparing
    /// two items using an ascending order.
    ///
    /// The ordering places the first item before the second when a
    /// ``ComparisonResult`` of two items is
    /// ``ComparisonResult/orderedAscending``.
    case forward
    /// The ordering that places the first item after the second when comparing
    /// two items using an ascending order.
    ///
    /// The ordering places the first item after the second when a
    /// ``ComparisonResult`` of two items is
    /// ``ComparisonResult/orderedAscending``.
    case reverse

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let isForward = try container.decode(Bool.self)
        if isForward {
            self = .forward
        } else {
            self = .reverse
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .forward: try container.encode(true)
        case .reverse: try container.encode(false)
        }
    }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension ComparisonResult {
    package func withOrder(_ order: SortOrder) -> ComparisonResult {
        if order == .reverse {
            if self == .orderedAscending { return .orderedDescending }
            if self == .orderedDescending { return .orderedAscending }
        }
        return self
    }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
package struct AnySortComparator: SortComparator, Sendable {
    var _base: any Hashable & Sendable // internal for testing

    /// Takes `base` and two values to be compared and compares the two values
    /// using `base`.
    private let _compare: @Sendable (Any, Any, Any) -> ComparisonResult

    /// Takes `base` inout, and a new `SortOrder` and changes `base`s `order`
    /// to match the new `SortOrder`.
    private let setOrder: @Sendable (inout any Hashable & Sendable, SortOrder) -> any Hashable & Sendable

    /// Gets the current `order` property of `base`.
    private let getOrder: @Sendable (Any) -> SortOrder

    package init<Comparator: SortComparator>(_ comparator: Comparator) where Comparator : Sendable {
        self._base = comparator
        self._compare = { (base: Any, lhs: Any, rhs: Any) -> ComparisonResult in
            (base as! Comparator).compare(lhs as! Comparator.Compared, rhs as! Comparator.Compared)
        }
        self.setOrder = { (base: inout any Hashable & Sendable, newOrder: SortOrder) -> AnyHashable in
            var typedBase = base as! Comparator
            typedBase.order = newOrder
            base = typedBase
            return AnyHashable(typedBase)
        }
        self.getOrder = { (base: Any) -> SortOrder in
            (base as! Comparator).order
        }
    }

    package var order: SortOrder {
        get {
            return getOrder(_base)
        }
        set {
            _base = setOrder(&_base, newValue)
        }
    }

    package func compare(_ lhs: Any, _ rhs: Any) -> ComparisonResult {
        return _compare(_base, lhs, rhs)
    }

    package func hash(into hasher: inout Hasher) {
        hasher.combine(_base)
    }

    package static func == (lhs: Self, rhs: Self) -> Bool {
        func compare<L : Equatable, R : Equatable>(_ l : L, _ r : R) -> Bool {
            guard let rr = r as? L else {
                return false
            }
            return l == rr
        }
        
        return compare(lhs._base, rhs._base)
    }
}

/// A comparator that compares types according to their conformance to the comparable protocol.
///
/// The comparator uses the relevant type's <doc://com.apple.documentation/documentation/swift/comparable> implementation to compare instances.
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct ComparableComparator<Compared: Comparable>: SortComparator, Sendable {
    /// The sort order that the comparator uses to compare.
    public var order: SortOrder
    
#if FOUNDATION_FRAMEWORK
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    public init(order: SortOrder = .forward) {
        self.order = order
    }
#else
    // No need for availability on this initializer in the package.
    public init(order: SortOrder = .forward) {
        self.order = order
    }
#endif

    private func unorderedCompare(_ lhs: Compared, _ rhs: Compared) -> ComparisonResult {
        if lhs < rhs { return .orderedAscending }
        if lhs > rhs { return .orderedDescending }
        return .orderedSame
    }

    /// Provides the relative ordering of two elements.
    ///
    /// The method returns flipped comparisons if the sort order is ``SortOrder/reverse``.
    ///
    /// - Parameters:
    ///   - lhs: The first element to compare.
    ///   - rhs: The second element to compare.
    /// - Returns: The relative ordering between the two elements.
    public func compare(_ lhs: Compared, _ rhs: Compared) -> ComparisonResult {
        return unorderedCompare(lhs, rhs).withOrder(order)
    }
}

/// A comparator which orders optional values using a comparator which
/// compares the optional's `Wrapped` type. `nil` values are ordered before
/// non-nil values when `order` is `forward`.
package struct OptionalComparator<Base: SortComparator>: SortComparator {
    private var base: Base

    package init(_ base: Base) {
        self.base = base
    }

    package var order: SortOrder {
        get { base.order }
        set { base.order = newValue }
    }

    package func compare(_ lhs: Base.Compared?, _ rhs: Base.Compared?) -> ComparisonResult {
        guard let lhs else {
            if rhs == nil { return .orderedSame }
            return .orderedAscending.withOrder(order)
        }
        guard let rhs else { return .orderedDescending.withOrder(order) }
        return base.compare(lhs, rhs)
    }
}

extension OptionalComparator : Sendable where Base : Sendable { }

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Never: SortComparator {
    public typealias Compared = Never

    public func compare(_ lhs: Never, _ rhs: Never) -> ComparisonResult {}

    public var order: SortOrder {
        get {
            switch self {}
        }
        set {
            switch self {}
        }
    }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Sequence {
    /// Returns the elements of the sequence, sorted using the given comparator
    /// to compare elements.
    ///
    /// - Parameters:
    ///   - comparator: the comparator to use in ordering elements
    /// - Returns: an array of the elements sorted using `comparator`.
    public func sorted<Comparator: SortComparator>(using comparator: Comparator) -> [Element] where Comparator.Compared == Element {
        return self.sorted {
            comparator.compare($0, $1) == .orderedAscending
        }
    }

    /// Returns the elements of the sequence, sorted using the given array of
    /// `SortComparator`s to compare elements.
    ///
    /// - Parameters:
    ///   - comparators: an array of comparators used to compare elements. The
    ///   first comparator specifies the primary comparator to be used in
    ///   sorting the sequence's elements. Any subsequent comparators are used
    ///   to further refine the order of elements with equal values.
    /// - Returns: an array of the elements sorted using `comparators`.
    public func sorted<S: Sequence, Comparator: SortComparator>(using comparators: S) -> [Element] where
        S.Element == Comparator,
        Element == Comparator.Compared
    {
        return self.sorted {
            comparators.compare($0, $1) == .orderedAscending
        }
    }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Sequence {
    /// If `lhs` is ordered before `rhs` in the ordering described by the given
    /// sequence of `SortComparator`s
    ///
    /// The first element of the sequence of comparators specifies the primary
    /// comparator to be used in sorting the sequence's elements. Any subsequent
    /// comparators are used to further refine the order of elements with equal
    /// values.
    public func compare<Comparator: SortComparator>(_ lhs: Comparator.Compared, _ rhs: Comparator.Compared) -> ComparisonResult where Element == Comparator {
        for comparator in self {
            let result = comparator.compare(lhs, rhs)
            if result != .orderedSame { return result }
        }
        return .orderedSame
    }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension MutableCollection where Self: RandomAccessCollection {
    /// Sorts the collection using the given comparator to compare elements.
    /// - Parameters:
    ///     - comparator: the sort comparator used to compare elements.
    public mutating func sort<Comparator: SortComparator>(using comparator: Comparator) where Comparator.Compared == Element {
        self.sort {
            comparator.compare($0, $1) == .orderedAscending
        }
    }

    /// Sorts the collection using the given array of `SortComparator`s to
    /// compare elements.
    ///
    /// - Parameters:
    ///   - comparators: an array of comparators used to compare elements. The
    ///   first comparator specifies the primary comparator to be used in
    ///   sorting the sequence's elements. Any subsequent comparators are used
    ///   to further refine the order of elements with equal values.
    public mutating func sort<S: Sequence, Comparator: SortComparator>(using comparators: S) where S.Element == Comparator, Element == Comparator.Compared {
        self.sort {
            comparators.compare($0, $1) == .orderedAscending
        }
    }
}
