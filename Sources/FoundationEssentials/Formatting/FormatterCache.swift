//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

package struct FormatterCache<Format : Hashable & Sendable, FormattingType: Sendable>: Sendable {

    let countLimit = 100

    private let _lock: LockedState<[Format: FormattingType]>
    package func formatter(for config: Format, creator: () -> FormattingType) -> FormattingType {
        let existed = _lock.withLock { cache in
            return cache [config]
        }

        if let existed {
            return existed
        }

        // Call `creator()` outside of the cache's lock to avoid blocking
        let df = creator()

        _lock.withLockExtendingLifetimeOfState { cache in
            if cache.count > countLimit {
                cache.removeAll()
            }
            cache[config] = df
        }

        return df
    }

    package func removeAllObjects() {
        _lock.withLockExtendingLifetimeOfState { cache in
            cache.removeAll()
        }
    }

    package subscript(key: Format) -> FormattingType? {
        _lock.withLock {
            $0[key]
        }
    }

    package init() {
        _lock = LockedState(initialState: [Format: FormattingType]())
    }
}
