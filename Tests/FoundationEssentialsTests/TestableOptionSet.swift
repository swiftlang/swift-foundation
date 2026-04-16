//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing

/// A protocol for OptionSet types that have non-standard SetAlgebra semantics (e.g. because they
/// encode an enum in some of their bits rather than using all bits as independent flags) and want
/// to validate their SetAlgebra conformance in tests.
public protocol TestableOptionSet: OptionSet where Element == Self {
    /// A human-readable description of the value, used in test failure messages.
    var _description: String { get }

    /// Whether this type can satisfy the invariant:
    ///   x.contains(e) && y.contains(e) if and only if x.intersection(y).contains(e)
    ///
    /// Types whose enum-in-bits encoding makes this invariant impossible to satisfy should
    /// override this to return `false`.
    static var supportsIntersectionContainsInvariant: Bool { get }
}

extension TestableOptionSet {
    public static var supportsIntersectionContainsInvariant: Bool { true }

    public static func validateConformance(elements: [Self], groupings: [Self], sourceLocation: SourceLocation = #_sourceLocation) {
        let empty: Self = []

        // S() == []
        #expect(Self() == empty, "Invariant not held: S() == []", sourceLocation: sourceLocation)

        for x in groupings + elements {
            // x.intersection(x) == x
            #expect(x.intersection(x) == x, "Invariant not held: x.intersection(x) == x for x = \(x._description)", sourceLocation: sourceLocation)

            // x.intersection([]) == []
            #expect(x.intersection(empty) == empty, "Invariant not held: x.intersection([]) == [] for x = \(x._description)", sourceLocation: sourceLocation)

            // x.union(x) == x
            #expect(x.union(x) == x, "Invariant not held: x.union(x) == x for x = \(x._description)", sourceLocation: sourceLocation)

            // x.union([]) == x
            #expect(x.union(empty) == x, "Invariant not held: x.union([]) == x for x = \(x._description)", sourceLocation: sourceLocation)

            for y in groupings + elements {
                for e in elements {
                    // x.contains(e) implies x.union(y).contains(e)
                    if x.contains(e) {
                        #expect(x.union(y).contains(e), "Invariant not held: x.contains(e) implies x.union(y).contains(e) for x = \(x._description), y = \(y._description), e = \(e._description)", sourceLocation: sourceLocation)
                    }

                    // x.union(y).contains(e) implies x.contains(e) || y.contains(e)
                    if x.union(y).contains(e) {
                        #expect(x.contains(e) || y.contains(e), "Invariant not held: x.union(y).contains(e) implies x.contains(e) || y.contains(e) for x = \(x._description), y = \(y._description), e = \(e._description)", sourceLocation: sourceLocation)
                    }

                    // x.contains(e) && y.contains(e) if and only if x.intersection(y).contains(e)
                    if Self.supportsIntersectionContainsInvariant {
                        #expect((x.contains(e) && y.contains(e)) == x.intersection(y).contains(e), "Invariant not held: x.contains(e) && y.contains(e) if and only if x.intersection(y).contains(e) for x = \(x._description), y = \(y._description), e = \(e._description)", sourceLocation: sourceLocation)
                    }
                }

                // x.isSubset(of: y) implies x.union(y) == y
                if x.isSubset(of: y) {
                    #expect(x.union(y) == y, "Invariant not held: x.isSubset(of: y) implies x.union(y) == y for x = \(x._description), y = \(y._description)", sourceLocation: sourceLocation)
                }

                // x.isSuperset(of: y) implies x.union(y) == x
                if x.isSuperset(of: y) {
                    #expect(x.union(y) == x, "Invariant not held: x.isSuperset(of: y) implies x.union(y) == x for x = \(x._description), y = \(y._description)", sourceLocation: sourceLocation)
                }

                // x.isSubset(of: y) if and only if y.isSuperset(of: x)
                #expect(x.isSubset(of: y) == y.isSuperset(of: x), "Invariant not held: x.isSubset(of: y) if and only if y.isSuperset(of: x) for x = \(x._description), y = \(y._description)", sourceLocation: sourceLocation)

                // x.isStrictSuperset(of: y) if and only if x.isSuperset(of: y) && x != y
                #expect(x.isStrictSuperset(of: y) == (x.isSuperset(of: y) && x != y), "Invariant not held: x.isStrictSuperset(of: y) if and only if x.isSuperset(of: y) && x != y for x = \(x._description), y = \(y._description)", sourceLocation: sourceLocation)

                // x.isStrictSubset(of: y) if and only if x.isSubset(of: y) && x != y
                #expect(x.isStrictSubset(of: y) == (x.isSubset(of: y) && x != y), "Invariant not held: x.isStrictSubset(of: y) if and only if x.isSubset(of: y) && x != y for x = \(x._description), y = \(y._description)", sourceLocation: sourceLocation)
            }
        }
    }
}
