//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing

/// Test that the elements of `instances` satisfy the semantic
/// requirements of `Equatable`, using `oracle` to generate equality
/// expectations from pairs of positions in `instances`.
///
/// - Note: `oracle` is also checked for conformance to the
///   laws.
func checkEquatable<Instances : Collection>(
    _ instances: Instances,
    oracle: (Instances.Index, Instances.Index) -> Bool,
    allowBrokenTransitivity: Bool = false,
    _ message: @autoclosure () -> String = "",
    sourceLocation: SourceLocation = #_sourceLocation
) where Instances.Element: Equatable {
    let indices = Array(instances.indices)
    _checkEquatable(
        instances,
        oracle: { oracle(indices[$0], indices[$1]) },
        allowBrokenTransitivity: allowBrokenTransitivity,
        message(),
        sourceLocation: sourceLocation
    )
}

func _checkEquatable<Instances : Collection>(
    _ _instances: Instances,
    oracle: (Int, Int) -> Bool,
    allowBrokenTransitivity: Bool = false,
    _ message: @autoclosure () -> String = "",
    sourceLocation: SourceLocation = #_sourceLocation
) where Instances.Element: Equatable {
    let instances = Array(_instances)
    
    // For each index (which corresponds to an instance being tested) track the
    // set of equal instances.
    var transitivityScoreboard: [Box<Set<Int>>] =
    instances.indices.map { _ in Box([]) }
    
    for i in instances.indices {
        let x = instances[i]
        #expect(oracle(i, i), "bad oracle: broken reflexivity at index \(i)")
        
        for j in instances.indices {
            let y = instances[j]
            
            let predictedXY = oracle(i, j)
            #expect(
                predictedXY == oracle(j, i),
                "bad oracle: broken symmetry between indices \(i), \(j)",
                sourceLocation: sourceLocation
            )
            
            let isEqualXY = x == y
            #expect(
                predictedXY == isEqualXY,
                """
                \((predictedXY
                ? "expected equal, found not equal"
                : "expected not equal, found equal"))
                lhs (at index \(i)): \(String(reflecting: x))
                rhs (at index \(j)): \(String(reflecting: y))
                """,
                sourceLocation: sourceLocation
            )
            
            // Not-equal is an inverse of equal.
            #expect(
                isEqualXY != (x != y),
                """
                lhs (at index \(i)): \(String(reflecting: x))
                rhs (at index \(j)): \(String(reflecting: y))
                """,
                sourceLocation: sourceLocation
            )
            
            if !allowBrokenTransitivity {
                // Check transitivity of the predicate represented by the oracle.
                // If we are adding the instance `j` into an equivalence set, check that
                // it is equal to every other instance in the set.
                if predictedXY && i < j && transitivityScoreboard[i].value.insert(j).inserted {
                    if transitivityScoreboard[i].value.count == 1 {
                        transitivityScoreboard[i].value.insert(i)
                    }
                    for k in transitivityScoreboard[i].value {
                        #expect(
                            oracle(j, k),
                            "bad oracle: broken transitivity at indices \(i), \(j), \(k)",
                            sourceLocation: sourceLocation
                        )
                        // No need to check equality between actual values, we will check
                        // them with the checks above.
                    }
                    precondition(transitivityScoreboard[j].value.isEmpty)
                    transitivityScoreboard[j] = transitivityScoreboard[i]
                }
            }
        }
    }
}

public func checkHashable<Instances: Collection>(
    _ instances: Instances,
    equalityOracle: (Instances.Index, Instances.Index) -> Bool,
    allowIncompleteHashing: Bool = false,
    _ message: @autoclosure () -> String = "",
    sourceLocation: SourceLocation = #_sourceLocation
) where Instances.Element: Hashable {
    checkHashable(
        instances,
        equalityOracle: equalityOracle,
        hashEqualityOracle: equalityOracle,
        allowIncompleteHashing: allowIncompleteHashing,
        message(),
        sourceLocation: sourceLocation)
}

func checkHashable<Instances: Collection>(
    _ instances: Instances,
    equalityOracle: (Instances.Index, Instances.Index) -> Bool,
    hashEqualityOracle: (Instances.Index, Instances.Index) -> Bool,
    allowIncompleteHashing: Bool = false,
    _ message: @autoclosure () -> String = "",
    sourceLocation: SourceLocation = #_sourceLocation
) where Instances.Element: Hashable {
    checkEquatable(
        instances,
        oracle: equalityOracle,
        message(),
        sourceLocation: sourceLocation
    )
    
    for i in instances.indices {
        let x = instances[i]
        for j in instances.indices {
            let y = instances[j]
            let predicted = hashEqualityOracle(i, j)
            #expect(
                predicted == hashEqualityOracle(j, i),
                "bad hash oracle: broken symmetry between indices \(i), \(j)",
                sourceLocation: sourceLocation
            )
            if x == y {
                #expect(
                    predicted,
                    """
                    bad hash oracle: equality must imply hash equality
                    lhs (at index \(i)): \(x)
                    rhs (at index \(j)): \(y)
                    """,
                    sourceLocation: sourceLocation
                )
            }
            if predicted {
                #expect(
                    hash(x) == hash(y),
                    """
                    hash(into:) expected to match, found to differ
                    lhs (at index \(i)): \(x)
                    rhs (at index \(j)): \(y)
                    """,
                    sourceLocation: sourceLocation
                )
                #expect(
                    x.hashValue == y.hashValue,
                    """
                    hashValue expected to match, found to differ
                    lhs (at index \(i)): \(x)
                    rhs (at index \(j)): \(y)
                    """,
                    sourceLocation: sourceLocation
                )
                #expect(
                    x._rawHashValue(seed: 0) == y._rawHashValue(seed: 0),
                    """
                    _rawHashValue(seed:) expected to match, found to differ
                    lhs (at index \(i)): \(x)
                    rhs (at index \(j)): \(y)
                    """,
                    sourceLocation: sourceLocation
                )
            } else if !allowIncompleteHashing {
                // Try a few different seeds; at least one of them should discriminate
                // between the hashes. It is extremely unlikely this check will fail
                // all ten attempts, unless the type's hash encoding is not unique,
                // or unless the hash equality oracle is wrong.
                #expect(
                    (0..<10).contains { hash(x, salt: $0) != hash(y, salt: $0) },
                    """
                    hash(into:) expected to differ, found to match
                    lhs (at index \(i)): \(x)
                    rhs (at index \(j)): \(y)
                    """,
                    sourceLocation: sourceLocation
                )
                #expect(
                    (0..<10).contains { i in
                        x._rawHashValue(seed: i) != y._rawHashValue(seed: i)
                    },
                    """
                    _rawHashValue(seed:) expected to differ, found to match
                    lhs (at index \(i)): \(x)
                    rhs (at index \(j)): \(y)
                    """,
                    sourceLocation: sourceLocation
                )
            }
        }
    }
}

/// Test that the elements of `groups` consist of instances that satisfy the
/// semantic requirements of `Hashable`, with each group defining a distinct
/// equivalence class under `==`.
public func checkHashableGroups<Groups: Collection>(
    _ groups: Groups,
    _ message: @autoclosure () -> String = "",
    allowIncompleteHashing: Bool = false,
    sourceLocation: SourceLocation = #_sourceLocation
) where Groups.Element: Collection, Groups.Element.Element: Hashable {
    let instances = groups.flatMap { $0 }
    // groupIndices[i] is the index of the element in groups that contains
    // instances[i].
    let groupIndices =
    zip(0..., groups).flatMap { i, group in group.map { _ in i } }
    func equalityOracle(_ lhs: Int, _ rhs: Int) -> Bool {
        return groupIndices[lhs] == groupIndices[rhs]
    }
    checkHashable(
        instances,
        equalityOracle: equalityOracle,
        hashEqualityOracle: equalityOracle,
        allowIncompleteHashing: allowIncompleteHashing,
        sourceLocation: sourceLocation)
}

public enum DecodingErrorValidator {

    /// Returns the underlying error of the decoding error, if any.
    public typealias Validator = (DecodingError) -> (any Error)?

    public static func typeMismatch<ExpectedType>(
        expectedType _: ExpectedType.Type,
        codingPath: [String],
        debugDescription: String,
        sourceLocation: SourceLocation = #_sourceLocation,
    ) -> Validator {
        { error in
            switch error {
            case .typeMismatch(let type, let context):
                #expect(type == ExpectedType.self, sourceLocation: sourceLocation)
                #expect(context.codingPath.map(\.stringValue) == codingPath, sourceLocation: sourceLocation)
                #expect(context.debugDescription == debugDescription, sourceLocation: sourceLocation)
                return context.underlyingError
            default:
                Issue.record(error, "Unexpected error case", sourceLocation: sourceLocation)
                return nil
            }
        }
    }

    public static func valueNotFound<ExpectedType>(
        expectedType _: ExpectedType.Type,
        codingPath: [String],
        debugDescription: String,
        sourceLocation: SourceLocation = #_sourceLocation,
    ) -> Validator {
        { error in
            switch error {
            case .valueNotFound(let type, let context):
                #expect(type == ExpectedType.self, sourceLocation: sourceLocation)
                #expect(context.codingPath.map(\.stringValue) == codingPath, sourceLocation: sourceLocation)
                #expect(context.debugDescription == debugDescription, sourceLocation: sourceLocation)
                return context.underlyingError
            default:
                Issue.record(error, "Unexpected error case", sourceLocation: sourceLocation)
                return nil
            }
        }
    }

    public static func keyNotFound(
        keyStringValue: String,
        codingPath: [String],
        debugDescription: String,
        sourceLocation: SourceLocation = #_sourceLocation,
    ) -> Validator {
        { error in
            switch error {
            case .keyNotFound(let key, let context):
                #expect(key.stringValue == keyStringValue, sourceLocation: sourceLocation)
                #expect(context.codingPath.map(\.stringValue) == codingPath, sourceLocation: sourceLocation)
                #expect(context.debugDescription == debugDescription, sourceLocation: sourceLocation)
                return context.underlyingError
            default:
                Issue.record(error, "Unexpected error case", sourceLocation: sourceLocation)
                return nil
            }
        }
    }

    public static func dataCorrupted(
        codingPath: [String],
        debugDescription: String,
        sourceLocation: SourceLocation = #_sourceLocation,
    ) -> Validator {
        { error in
            switch error {
            case .dataCorrupted(let context):
                #expect(context.codingPath.map(\.stringValue) == codingPath, sourceLocation: sourceLocation)
                #expect(context.debugDescription == debugDescription, sourceLocation: sourceLocation)
                return context.underlyingError
            default:
                Issue.record(error, "Unexpected error case", sourceLocation: sourceLocation)
                return nil
            }
        }
    }
}

// MARK: - Private Types

private class Box<T> {
    var value: T
    
    init(_ value: T) {
        self.value = value
    }
}

private func hash<H: Hashable>(_ value: H, salt: Int? = nil) -> Int {
    var hasher = Hasher()
    if let salt = salt {
        hasher.combine(salt)
    }
    hasher.combine(value)
    return hasher.finalize()
}
