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

import XCTest

#if FOUNDATION_FRAMEWORK
import Foundation
#else
import FoundationEssentials
#endif

extension Optional {
    @available(*, unavailable, message: "Use XCTUnwrap() instead")
    func unwrapped(_ fn: String = #function, file: StaticString = #file, line: UInt = #line) throws -> Wrapped {
        return try XCTUnwrap(self, file: file, line: line)
    }
}

func expectThrows<Error: Swift.Error & Equatable>(_ expectedError: Error, _ test: () throws -> Void, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    var caught = false
    do {
        try test()
    } catch let error as Error {
        caught = true
        XCTAssertEqual(error, expectedError, message(), file: file, line: line)
    } catch {
        caught = true
        XCTFail("Incorrect error thrown: \(error) -- \(message())", file: file, line: line)
    }
    XCTAssert(caught, "No error thrown -- \(message())", file: file, line: line)
}

func expectDoesNotThrow(_ test: () throws -> Void, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    XCTAssertNoThrow(try test(), message(), file: file, line: line)
}

func expectTrue(_ actual: Bool, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    XCTAssertTrue(actual, message(), file: file, line: line)
}

func expectFalse(_ actual: Bool, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    XCTAssertFalse(actual, message(), file: file, line: line)
}

public func expectEqual<T: Equatable>(_ expected: T, _ actual: T, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    XCTAssertEqual(expected, actual, message(), file: file, line: line)
}

public func expectNotEqual<T: Equatable>(_ expected: T, _ actual: T, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    XCTAssertNotEqual(expected, actual, message(), file: file, line: line)
}

public func expectEqual<T: FloatingPoint>(_ expected: T, _ actual: T, within: T, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    XCTAssertEqual(expected, actual, accuracy: within, message(), file: file, line: line)
}

public func expectEqual<T: FloatingPoint>(_ expected: T?, _ actual: T, within: T, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    XCTAssertNotNil(expected, message(), file: file, line: line)
    if let expected = expected {
        XCTAssertEqual(expected, actual, accuracy: within, message(), file: file, line: line)
    }
}

public func expectEqual(
    _ expected: Any.Type,
    _ actual: Any.Type,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #file,
    line: UInt = #line
) {
    XCTAssertTrue(expected == actual, message(), file: file, line: line)
}

public func expectEqualSequence< Expected: Sequence, Actual: Sequence>(
    _ expected: Expected, _ actual: Actual,
    _ message: @autoclosure () -> String = "",
    file: String = #file, line: UInt = #line,
    sameValue: (Expected.Element, Expected.Element) -> Bool
) where Expected.Element == Actual.Element {
    if !expected.elementsEqual(actual, by: sameValue) {
      XCTFail("expected elements: \"\(expected)\"\n"
              + "actual: \"\(actual)\" (of type \(String(reflecting: type(of: actual)))), \(message())")
    }
}

public func expectEqualSequence< Expected: Sequence, Actual: Sequence>(
    _ expected: Expected, _ actual: Actual,
    _ message: @autoclosure () -> String = "",
    file: String = #file, line: UInt = #line
) where Expected.Element == Actual.Element, Expected.Element: Equatable {
    expectEqualSequence(expected, actual, message()) {
        $0 == $1
    }
}

func expectChanges<T: BinaryInteger>(_ check: @autoclosure () -> T, by difference: T? = nil, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line, _ expression: () throws -> ()) rethrows {
    let valueBefore = check()
    try expression()
    let valueAfter = check()
    if let difference = difference {
        XCTAssertEqual(valueAfter, valueBefore + difference, message(), file: file, line: line)
    } else {
        XCTAssertNotEqual(valueAfter, valueBefore, message(), file: file, line: line)
    }
}

func expectNoChanges<T: BinaryInteger>(_ check: @autoclosure () -> T, by difference: T? = nil, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line, _ expression: () throws -> ()) rethrows {
    let valueBefore = check()
    try expression()
    let valueAfter = check()
    if let difference = difference {
        XCTAssertNotEqual(valueAfter, valueBefore + difference, message(), file: file, line: line)
    } else {
        XCTAssertEqual(valueAfter, valueBefore, message(), file: file, line: line)
    }
}

/// Test that the elements of `instances` satisfy the semantic
/// requirements of `Equatable`, using `oracle` to generate equality
/// expectations from pairs of positions in `instances`.
///
/// - Note: `oracle` is also checked for conformance to the
///   laws.
public func checkEquatable<Instances: Collection>(
    _ instances: Instances,
    oracle: (Instances.Index, Instances.Index) -> Bool,
    allowBrokenTransitivity: Bool = false,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #file,
    line: UInt = #line
) where Instances.Element: Equatable {
    let indices = Array(instances.indices)
    _checkEquatableImpl(
        Array(instances),
        oracle: { oracle(indices[$0], indices[$1]) },
        allowBrokenTransitivity: allowBrokenTransitivity,
        message(),
        file: file,
        line: line)
}

private class Box<T> {
    var value: T

    init(_ value: T) {
        self.value = value
    }
}

internal func _checkEquatableImpl<Instance : Equatable>(
    _ instances: [Instance],
    oracle: (Int, Int) -> Bool,
    allowBrokenTransitivity: Bool = false,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #file,
    line: UInt = #line
) {
    // For each index (which corresponds to an instance being tested) track the
    // set of equal instances.
    var transitivityScoreboard: [Box<Set<Int>>] =
        instances.indices.map { _ in Box([]) }

    for i in instances.indices {
        let x = instances[i]
        expectTrue(oracle(i, i), "bad oracle: broken reflexivity at index \(i)")

        for j in instances.indices {
            let y = instances[j]

            let predictedXY = oracle(i, j)
            expectEqual(
                predictedXY, oracle(j, i),
                "bad oracle: broken symmetry between indices \(i), \(j)",
                file: file,
                line: line)

            let isEqualXY = x == y
            expectEqual(
                predictedXY, isEqualXY,
                """
                \((predictedXY
                ? "expected equal, found not equal"
                : "expected not equal, found equal"))
                lhs (at index \(i)): \(String(reflecting: x))
                rhs (at index \(j)): \(String(reflecting: y))
                """,
                file: file,
                line: line)

            // Not-equal is an inverse of equal.
            expectNotEqual(
                isEqualXY, x != y,
                """
                lhs (at index \(i)): \(String(reflecting: x))
                rhs (at index \(j)): \(String(reflecting: y))
                """,
                file: file,
                line: line)

            if !allowBrokenTransitivity {
                // Check transitivity of the predicate represented by the oracle.
                // If we are adding the instance `j` into an equivalence set, check that
                // it is equal to every other instance in the set.
                if predictedXY && i < j && transitivityScoreboard[i].value.insert(j).inserted {
                    if transitivityScoreboard[i].value.count == 1 {
                        transitivityScoreboard[i].value.insert(i)
                    }
                    for k in transitivityScoreboard[i].value {
                        expectTrue(
                            oracle(j, k),
                            "bad oracle: broken transitivity at indices \(i), \(j), \(k)",
                            file: file,
                            line: line)
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

func hash<H: Hashable>(_ value: H, salt: Int? = nil) -> Int {
    var hasher = Hasher()
    if let salt = salt {
        hasher.combine(salt)
    }
    hasher.combine(value)
    return hasher.finalize()
}

public func checkHashable<Instances: Collection>(
    _ instances: Instances,
    equalityOracle: (Instances.Index, Instances.Index) -> Bool,
    allowIncompleteHashing: Bool = false,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #file, line: UInt = #line
) where Instances.Element: Hashable {
    checkHashable(
        instances,
        equalityOracle: equalityOracle,
        hashEqualityOracle: equalityOracle,
        allowIncompleteHashing: allowIncompleteHashing,
        message(),
        file: file,
        line: line)
}


public func checkHashable<Instances: Collection>(
    _ instances: Instances,
    equalityOracle: (Instances.Index, Instances.Index) -> Bool,
    hashEqualityOracle: (Instances.Index, Instances.Index) -> Bool,
    allowIncompleteHashing: Bool = false,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #file, line: UInt = #line
) where Instances.Element: Hashable {

    checkEquatable(
        instances,
        oracle: equalityOracle,
        message(),
        file: file,
        line: line)

    for i in instances.indices {
        let x = instances[i]
        for j in instances.indices {
            let y = instances[j]
            let predicted = hashEqualityOracle(i, j)
            XCTAssertEqual(
                predicted,
                hashEqualityOracle(j, i),
                "bad hash oracle: broken symmetry between indices \(i), \(j)",
                file: file, line: line)
            if x == y {
                XCTAssertTrue(
                    predicted,
                    """
                    bad hash oracle: equality must imply hash equality
                    lhs (at index \(i)): \(x)
                    rhs (at index \(j)): \(y)
                    """,
                    file: file, line: line)
            }
            if predicted {
                XCTAssertEqual(
                    hash(x), hash(y),
                    """
                    hash(into:) expected to match, found to differ
                    lhs (at index \(i)): \(x)
                    rhs (at index \(j)): \(y)
                    """,
                    file: file, line: line)
                XCTAssertEqual(
                    x.hashValue, y.hashValue,
                    """
                    hashValue expected to match, found to differ
                    lhs (at index \(i)): \(x)
                    rhs (at index \(j)): \(y)
                    """,
                    file: file, line: line)
                XCTAssertEqual(
                    x._rawHashValue(seed: 0), y._rawHashValue(seed: 0),
                    """
                    _rawHashValue(seed:) expected to match, found to differ
                    lhs (at index \(i)): \(x)
                    rhs (at index \(j)): \(y)
                    """,
                    file: file, line: line)
            } else if !allowIncompleteHashing {
                // Try a few different seeds; at least one of them should discriminate
                // between the hashes. It is extremely unlikely this check will fail
                // all ten attempts, unless the type's hash encoding is not unique,
                // or unless the hash equality oracle is wrong.
                XCTAssertTrue(
                    (0..<10).contains { hash(x, salt: $0) != hash(y, salt: $0) },
                    """
                    hash(into:) expected to differ, found to match
                    lhs (at index \(i)): \(x)
                    rhs (at index \(j)): \(y)
                    """,
                    file: file, line: line)
                XCTAssertTrue(
                    (0..<10).contains { i in
                        x._rawHashValue(seed: i) != y._rawHashValue(seed: i)
                    },
                    """
                    _rawHashValue(seed:) expected to differ, found to match
                    lhs (at index \(i)): \(x)
                    rhs (at index \(j)): \(y)
                    """,
                    file: file, line: line)
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
    file: StaticString = #file,
    line: UInt = #line
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
        file: file,
        line: line)
}

private var shouldRunXFailTests: Bool {
    // FIXME: Reenable after ProcessInfo is migrated
//    return ProcessInfo.processInfo.environment["NS_FOUNDATION_ATTEMPT_XFAIL_TESTS"] == "YES"
    return false
}

func shouldAttemptXFailTests(_ reason: String) -> Bool {
    if shouldRunXFailTests {
        return true
    } else {
        print("warning: Skipping test expected to fail with reason '\(reason)'\n")
        return false
    }
}

func shouldAttemptWindowsXFailTests(_ reason: String) -> Bool {
    #if os(Windows)
    return shouldAttemptXFailTests(reason)
    #else
    return true
    #endif
}

func shouldAttemptAndroidXFailTests(_ reason: String) -> Bool {
    #if os(Android)
    return shouldAttemptXFailTests(reason)
    #else
    return true
    #endif
}

func shouldAttemptOpenBSDXFailTests(_ reason: String) -> Bool {
    #if os(OpenBSD)
    return shouldAttemptXFailTests(reason)
    #else
    return true
    #endif
}

func testExpectedToFail<T>(_ test:  @escaping (T) -> () throws -> Void, _ reason: String) -> (T) -> () throws -> Void {
    testExpectedToFailWithCheck(check: shouldAttemptXFailTests(_:), test, reason)
}

func testExpectedToFailOnWindows<T>(_ test:  @escaping (T) -> () throws -> Void, _ reason: String) -> (T) -> () throws -> Void {
    testExpectedToFailWithCheck(check: shouldAttemptWindowsXFailTests(_:), test, reason)
}

func testExpectedToFailOnAndroid<T>(_ test: @escaping (T) -> () throws -> Void, _ reason: String) -> (T) -> () throws -> Void {
    testExpectedToFailWithCheck(check: shouldAttemptAndroidXFailTests(_:), test, reason)
}

func testExpectedToFailOnOpenBSD<T>(_ test: @escaping (T) -> () throws -> Void, _ reason: String) -> (T) -> () throws -> Void {
    testExpectedToFailWithCheck(check: shouldAttemptOpenBSDXFailTests(_:), test, reason)
}

func testExpectedToFailWithCheck<T>(check: (String) -> Bool, _ test:  @escaping (T) -> () throws -> Void, _ reason: String) -> (T) -> () throws -> Void {
    if check(reason) {
        return test
    } else {
        return { _ in return { } }
    }
}

