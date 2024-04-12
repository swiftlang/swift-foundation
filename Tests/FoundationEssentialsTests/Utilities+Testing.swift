//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
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
    _ _instances: Instances,
    oracle _oracle: @escaping (Instances.Index, Instances.Index) -> Bool,
    allowBrokenTransitivity: Bool = false,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #file,
    line: UInt = #line
) where Instances.Element: Equatable {
    let instances = Array(_instances)
    let indices = Array(_instances.indices)
    let oracle: (Int, Int) -> Bool = {
        _oracle(indices[$0], indices[$1])
    }

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
                sourceLocation: .init(
                    filePath: String(describing: file),
                    line: Int(line)
                )
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
                sourceLocation: .init(
                    filePath: String(describing: file),
                    line: Int(line)
                )
            )

            // Not-equal is an inverse of equal.
            #expect(
                isEqualXY != (x != y),
                """
                lhs (at index \(i)): \(String(reflecting: x))
                rhs (at index \(j)): \(String(reflecting: y))
                """,
                sourceLocation: .init(
                    filePath: String(describing: file),
                    line: Int(line)
                )
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
                            sourceLocation: .init(
                                filePath: String(describing: file),
                                line: Int(line)
                            )
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

func checkHashable<Instances: Collection>(
    _ instances: Instances,
    equalityOracle: @escaping (Instances.Index, Instances.Index) -> Bool,
    allowIncompleteHashing: Bool = false,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #file, line: UInt = #line
) where Instances.Element: Hashable {
    checkEquatable(
        instances,
        oracle: equalityOracle,
        message(),
        file: file, line: line
    )

    for i in instances.indices {
        let x = instances[i]
        for j in instances.indices {
            let y = instances[j]
            let predicted = equalityOracle(i, j)
            #expect(
                predicted == equalityOracle(j, i),
                "bad hash oracle: broken symmetry between indices \(i), \(j)",
                sourceLocation: .init(
                    filePath: String(describing: file),
                    line: Int(line)
                )
            )
            if x == y {
                #expect(
                    predicted,
                    """
                    bad hash oracle: equality must imply hash equality
                    lhs (at index \(i)): \(x)
                    rhs (at index \(j)): \(y)
                    """,
                    sourceLocation: .init(
                        filePath: String(describing: file),
                        line: Int(line)
                    )
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
                    sourceLocation: .init(
                        filePath: String(describing: file),
                        line: Int(line)
                    )
                )
                #expect(
                    x.hashValue == y.hashValue,
                    """
                    hashValue expected to match, found to differ
                    lhs (at index \(i)): \(x)
                    rhs (at index \(j)): \(y)
                    """,
                    sourceLocation: .init(
                        filePath: String(describing: file),
                        line: Int(line)
                    )
                )
                #expect(
                    x._rawHashValue(seed: 0) == y._rawHashValue(seed: 0),
                    """
                    _rawHashValue(seed:) expected to match, found to differ
                    lhs (at index \(i)): \(x)
                    rhs (at index \(j)): \(y)
                    """,
                    sourceLocation: .init(
                        filePath: String(describing: file),
                        line: Int(line)
                    )
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
                    sourceLocation: .init(
                        filePath: String(describing: file),
                        line: Int(line)
                    )
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
                    sourceLocation: .init(
                        filePath: String(describing: file),
                        line: Int(line)
                    )
                )
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

#if !FOUNDATION_FRAMEWORK
private func hash<H: Hashable>(_ value: H, salt: Int? = nil) -> Int {
    var hasher = Hasher()
    if let salt = salt {
        hasher.combine(salt)
    }
    hasher.combine(value)
    return hasher.finalize()
}
#endif
