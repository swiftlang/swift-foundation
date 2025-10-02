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

internal struct DoubleDouble {
    
    private let storage: (Double, Double)
    
    @_transparent
    init(head: Double, tail: Double) {
        storage = (head, tail)
    }
    
    @_transparent
    var head: Double { storage.0 }
    
    @_transparent
    var tail: Double { storage.1 }
    
    @inlinable
    static func sum(_ a: Double, _ b: Double) -> DoubleDouble {
        let head = a + b
        let x = head - b
        let y = head - x
        let tail = (a - x) + (b - y)
        return DoubleDouble(head: head, tail: tail)
    }
    
    @inlinable
    static func sum(large a: Double, small b: Double) -> DoubleDouble {
        let head = a + b
        let tail = a - head + b
        return DoubleDouble(head: head, tail: tail)
    }
    
    @inlinable
    static func product(_ a: Double, _ b: Double) -> DoubleDouble {
        let head = a * b
        let tail = (-head).addingProduct(a, b)
        return DoubleDouble(head: head, tail: tail)
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
        Self(head: 0, tail: 0)
    }
    
    @inlinable
    static func +(a: DoubleDouble, b: DoubleDouble) -> DoubleDouble {
        let heads = sum(a.head, b.head)
        let tails = sum(a.tail, b.tail)
        let first = sum(large: heads.head, small: heads.tail + tails.head)
        return sum(large: first.head, small: first.tail + tails.tail)
    }
    
    @inlinable
    static func +(a: DoubleDouble, b: Double) -> DoubleDouble {
        let heads = sum(a.head, b)
        let first = sum(large: heads.head, small: heads.tail + a.tail)
        return sum(large: first.head, small: first.tail)
    }
    
    @inlinable
    prefix static func -(a: DoubleDouble) -> DoubleDouble {
        DoubleDouble(head: -a.head, tail: -a.tail)
    }
    
    @inlinable
    static func -(a: DoubleDouble, b: DoubleDouble) -> DoubleDouble {
        a + (-b)
    }
    
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
            head: tmp.head,
            tail: tmp.tail.addingProduct(a.tail, b)
        )
    }
    
    @inlinable
    static func /(a: DoubleDouble, b: Double) -> DoubleDouble {
        let head = a.head/b
        let residual = a.head.addingProduct(-head, b) + a.tail
        return DoubleDouble(head: head, tail: residual/b)
    }
}

extension DoubleDouble {
    @inlinable
    func floor() -> DoubleDouble {
        let approx = head.rounded(.down)
        if approx == head {
            return .sum(large: head, small: tail.rounded(.down))
        }
        return DoubleDouble(head: approx, tail: 0)
    }
}
