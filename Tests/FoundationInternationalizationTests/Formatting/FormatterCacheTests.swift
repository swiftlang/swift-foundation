// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing

#if canImport(FoundationInternationalization)
@testable import FoundationEssentials
@testable import FoundationInternationalization
#elseif FOUNDATION_FRAMEWORK
@testable import Foundation
#endif

struct FormatterCacheTests {

    final class TestCacheItem: Equatable, Sendable {
        static func == (lhs: FormatterCacheTests.TestCacheItem, rhs: FormatterCacheTests.TestCacheItem) -> Bool {
            return lhs.value == rhs.value
        }

        let value: Int
        let deinitBlock: @Sendable () -> Void
        init(value: Int, deinitBlock: @Sendable @escaping () -> Void) {
            self.value = value
            self.deinitBlock = deinitBlock
        }

        deinit {
            deinitBlock()
        }
    }


    @Test func testCreateItem() {
        let cache = FormatterCache<Int, Int>()

        var initializerBlockInvocationCount = 0

        // Fill up the cache until its `countLimit`
        for i in 0...cache.countLimit {
            let item = cache.formatter(for: i) {
                initializerBlockInvocationCount += 1
                return -i
            }
            #expect(item == -i)
        }

        // `creator` block has been called 101 times
        #expect(initializerBlockInvocationCount == cache.countLimit + 1)

        // `creator` block does not get executed when the key exists
        for i in 0..<initializerBlockInvocationCount {
            let item = cache.formatter(for: i) {
                Issue.record("Creator block should not be executed when key exists in cache")
                return Int.max
            }

            #expect(item == -i)
        }

        // Fill one more to exceed cache's limit
        let item = cache.formatter(for: 1000) {
            initializerBlockInvocationCount += 1
            return -1000
        }

        // cache has been cleared out; only the one we just filled in is present
        for i in 0..<cache.countLimit {
            #expect(cache[i] == nil)
        }
        #expect(cache[1000] == item)
    }

    @Test(.timeLimit(.minutes(1)))
    @available(macOS 14, iOS 17, watchOS 10, tvOS 18, *)
    func testSynchronouslyClearingCache() async {
        let cache = FormatterCache<Int, TestCacheItem>()

        await withDiscardingTaskGroup { group in
            for i in 0 ..< 5 {
                group.addTask {
                    let cached = cache.formatter(for: i) {
                        return .init(value: -i, deinitBlock: {
                            // Test that `removeAllObjects` beneath does not trigger `deinit` of the removed objects in the locked scope.
                            // If it does cause the deinitialization of this instance where this block is run, we would deadlock here because the subscript getter is performed in the same locked scope as the enclosing `formatter(for:creator:)`.
                            _ = cache[i]
                        })
                    }
                    #expect(cached.value == -i)
                }
                
                group.addTask {
                    cache.removeAllObjects()
                }
            }
        }
    }
}


