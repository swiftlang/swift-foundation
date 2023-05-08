//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(TestSupport)
import TestSupport
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#elseif canImport(FoundationInternationalization)
@testable import FoundationInternationalization
#endif // FOUNDATION_FRAMEWORK

final class LockedStateTests : XCTestCase {
    final class TestObject {}
    struct TestError: Error {}

    func testWithLockDoesNotExtendLifetimeOfState() {
        weak var state: TestObject?
        let lockedState: LockedState<TestObject>

        (state, lockedState) = {
            let state = TestObject()
            return (state, LockedState(initialState: state))
        }()

        lockedState.withLock { state in
            weak var oldState = state
            state = TestObject()
            XCTAssertNil(oldState, "State object lifetime was extended after reassignment within body")
        }

        XCTAssertNil(state, "State object lifetime was extended beyond end of call")
    }

    func testWithLockExtendingLifespanDoesExtendLifetimeOfState() {
        weak var state: TestObject?
        let lockedState: LockedState<TestObject>

        (state, lockedState) = {
            let state = TestObject()
            return (state, LockedState(initialState: state))
        }()

        lockedState.withLockExtendingLifetimeOfState { state in
            weak var oldState = state
            state = TestObject()
            XCTAssertNotNil(oldState, "State object lifetime was not extended after reassignment within body")
        }

        XCTAssertNil(state, "State object lifetime was extended beyond end of call")
    }

    func testWithLockExtendingLifespanReleasesLockWhenBodyThrows() {
        let lockedState = LockedState(initialState: TestObject())

        XCTAssertThrowsError(
            try lockedState.withLockExtendingLifetimeOfState { _ in
                throw TestError()
            },
            "The body was expected to throw an error, but it did not."
        )

        // ⚠️ This test fails by crashing. If the lock was not properly released by the
        // `withLockExtendingLifetimeOfState()` call above, the following `withLock()`
        // call will abort the program.

        lockedState.withLock { _ in
            // PASS
        }
    }
}
