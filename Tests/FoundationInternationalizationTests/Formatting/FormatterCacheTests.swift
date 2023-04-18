// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// RUN: %target-run-simple-swift
// REQUIRES: executable_test
// REQUIRES: objc_interop

#if canImport(TestSupport)
import TestSupport
#endif

#if canImport(FoundationInternationalization)
@testable import FoundationInternationalization
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#endif

final class FormatterCacheTests: XCTestCase {

    class TestCacheItem: Equatable {
        static func == (lhs: FormatterCacheTests.TestCacheItem, rhs: FormatterCacheTests.TestCacheItem) -> Bool {
            return lhs.value == rhs.value
        }

        let value: Int
        let deinitBlock: () -> Void
        init(value: Int, deinitBlock: @escaping () -> Void) {
            self.value = value
            self.deinitBlock = deinitBlock
        }

        deinit {
            deinitBlock()
        }
    }


    func testCreateItem() {
        let cache = FormatterCache<Int, Int>()

        var initializerBlockInvocationCount = 0

        // Fill up the cache until its `countLimit`
        for i in 0...cache.countLimit {
            let item = cache.formatter(for: i) {
                initializerBlockInvocationCount += 1
                return -i
            }
            XCTAssertEqual(item, -i)
        }

        // `creator` block has been called 101 times
        XCTAssertEqual(initializerBlockInvocationCount, cache.countLimit + 1)

        // `creator` block does not get executed when the key exists
        for i in 0..<initializerBlockInvocationCount {
            let item = cache.formatter(for: i) {
                XCTFail()
                return Int.max
            }

            XCTAssertEqual(item, -i)
        }

        // Fill one more to exceed cache's limit
        let item = cache.formatter(for: 1000) {
            initializerBlockInvocationCount += 1
            return -1000
        }

        // cache has been cleared out; only the one we just filled in is present
        for i in 0..<cache.countLimit {
            XCTAssertNil(cache[i])
        }
        XCTAssertEqual(cache[1000], item)
    }

#if FOUNDATION_FRAMEWORK
    func testSynchronouslyClearingCache() {
        let cache = FormatterCache<Int, TestCacheItem>()
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "formatter cache test", qos: .default, attributes: .concurrent)


        for i in 0 ..< 5 {
            queue.async(group: group) {
                let cached = cache.formatter(for: i) {
                    return .init(value: -i, deinitBlock: {
                        // Test that `removeAllObjects` beneath does not trigger `deinit` of the removed objects in the locked scope.
                        // If it does cause the deinitialization of this instance where this block is run, we would deadlock here because the subscript getter is performed in the same locked scope as the enclosing `formatter(for:creator:)`.
                        _ = cache[i]
                    })
                }
                XCTAssertEqual(cached.value, -i)
            }

            queue.async(group: group) {
                cache.removeAllObjects()
            }
        }

        XCTAssertEqual(group.wait(timeout: .now().advanced(by: .seconds(3))), .success)
    }
#endif
}


