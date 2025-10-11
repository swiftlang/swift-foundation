//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

/// A numeric type that uses two Double values as its representation, providing
/// about 106 bits of precision with the same exponent range as Double.
///
/// This type conforms to AdditiveArithmetic, Hashable and Comparable, but does
/// not conform to FloatingPoint or Numeric; it implements only the API surface
/// that is necessary to serve as an internal implementation detail of Date.
internal struct DoubleDouble {
    
    private let storage: (Double, Double)
    
    /// A double-double value constructed by specifying the head and tail.
    ///
    /// This is an unchecked operation because it does not enforce the
    /// invariant that head + tail == head in release builds, which is
    /// necessary for subsequent arithmetic operations to behave correctly.
    @_transparent
    init(uncheckedHead head: Double, tail: Double) {
        assert(!head.isFinite || head + tail == head)
        storage = (head, tail)
    }
    
    /// The high-order Double.
    ///
    /// This property does not have a setter because `head` should pretty much
    /// never be set independently of `tail`, so as to maintain the invariant
    /// that `head + tail == head`. You can use `init(uncheckedHead:tail:)`
    /// to directly construct DoubleDouble values, which will enforce the
    /// invariant in debug builds.
    @_transparent
    var head: Double { storage.0 }
    
    /// The low-order Double.
    ///
    /// This property does not have a setter because `tail` should pretty much
    /// never be set independently of `head`, so as to maintain the invariant
    /// that `head + tail == head`. You can use `init(uncheckedHead:tail:)`
    /// to directly construct DoubleDouble values, which will enforce the
    /// invariant in debug builds.
    @_transparent
    var tail: Double { storage.1 }
    
    /// `a + b` represented as a normalized DoubleDouble.
    ///
    /// Computed via the [2Sum algorithm](https://en.wikipedia.org/wiki/2Sum).
    @inlinable
    static func sum(_ a: Double, _ b: Double) -> DoubleDouble {
        let head = a + b
        let x = head - b
        let y = head - x
        let tail = (a - x) + (b - y)
        return DoubleDouble(uncheckedHead: head, tail: tail)
    }
    
    /// `a + b` represented as a normalized DoubleDouble.
    ///
    /// Computed via the [Fast2Sum algorithm](https://en.wikipedia.org/wiki/2Sum).
    ///
    /// - Precondition:
    /// `large` and `small` must be such that `sum(large:small:)`
    /// produces the same result as `sum(_:_:)` would. A sufficient condition
    /// is that `|large| >= |small|`, but this is not necessary, so we do not
    /// enforce it via an assert. Instead this function asserts that the result
    /// is the same as that produced by `sum(_:_:)` in Debug builds. This is
    /// unchecked in Release.
    @inlinable
    static func sum(large a: Double, small b: Double) -> DoubleDouble {
        let head = a + b
        let tail = a - head + b
        let result = DoubleDouble(uncheckedHead: head, tail: tail)
        assert(!head.isFinite || result == sum(a, b))
        return result
    }
    
    /// `a * b` represented as a normalized DoubleDouble.
    @inlinable
    static func product(_ a: Double, _ b: Double) -> DoubleDouble {
        let head = a * b
        let tail = (-head).addingProduct(a, b)
        return DoubleDouble(uncheckedHead: head, tail: tail)
    }
}

extension DoubleDouble: Comparable {
    @_transparent
    static func ==(a: Self, b: Self) -> Bool {
        a.head == b.head && a.tail == b.tail
    }
    
    @_transparent
    static func <(a: Self, b: Self) -> Bool {
        a.head < b.head || a.head == b.head && a.tail < b.tail
    }
}

extension DoubleDouble: Hashable {
    @_transparent
    func hash(into hasher: inout Hasher) {
        hasher.combine(head)
        hasher.combine(tail)
    }
}

extension DoubleDouble: AdditiveArithmetic {
    @inlinable
    static var zero: DoubleDouble {
        Self(uncheckedHead: 0, tail: 0)
    }
    
    @inlinable
    static func +(a: DoubleDouble, b: DoubleDouble) -> DoubleDouble {
        let heads = sum(a.head, b.head)
        let tails = sum(a.tail, b.tail)
        let first = sum(large: heads.head, small: heads.tail + tails.head)
        return sum(large: first.head, small: first.tail + tails.tail)
    }
    
    /// Equivalent to `a + DoubleDouble(uncheckedHead: b, tail: 0)` but
    /// computed more efficiently.
    @inlinable
    static func +(a: DoubleDouble, b: Double) -> DoubleDouble {
        let heads = sum(a.head, b)
        let first = sum(large: heads.head, small: heads.tail + a.tail)
        return sum(large: first.head, small: first.tail)
    }
    
    @inlinable
    prefix static func -(a: DoubleDouble) -> DoubleDouble {
        DoubleDouble(uncheckedHead: -a.head, tail: -a.tail)
    }
    
    @inlinable
    static func -(a: DoubleDouble, b: DoubleDouble) -> DoubleDouble {
        a + (-b)
    }
    
    /// Equivalent to `a - DoubleDouble(uncheckedHead: b, tail: 0)` but
    /// computed more efficiently.
    @inlinable
    static func -(a: DoubleDouble, b: Double) -> DoubleDouble {
        a + (-b)
    }
}

extension DoubleDouble {
    @inlinable
    static func *(a: DoubleDouble, b: Double) -> DoubleDouble {
        let tmp = product(a.head, b)
        return DoubleDouble(
            uncheckedHead: tmp.head,
            tail: tmp.tail.addingProduct(a.tail, b)
        )
    }
    
    @inlinable
    static func /(a: DoubleDouble, b: Double) -> DoubleDouble {
        let head = a.head/b
        let residual = a.head.addingProduct(-head, b) + a.tail
        return .sum(large: head, small: residual/b)
    }
}

extension DoubleDouble {
    // This value rounded down to an integer.
    @inlinable
    func floor() -> DoubleDouble {
        let approx = head.rounded(.down)
        // If head was already an integer, round tail down and renormalize.
        if approx == head {
            return .sum(large: head, small: tail.rounded(.down))
        }
        // Head was not an integer; we can simply discard tail.
        return DoubleDouble(uncheckedHead: approx, tail: 0)
    }
}
