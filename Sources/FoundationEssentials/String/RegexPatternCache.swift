//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationInternals)
package import FoundationInternals
#endif

struct RegexPatternCache: @unchecked Sendable {
    private struct Key : Sendable, Hashable {
        var pattern: String
        var caseInsensitive: Bool
    }

    private let _lock: LockedState<[Key: Regex<AnyRegexOutput>]>

    static let cache = RegexPatternCache()

    fileprivate init() {
        _lock = LockedState(initialState: .init())
    }

    func regex(for pattern: String, caseInsensitive: Bool) throws -> Regex<AnyRegexOutput>? {

        let key = Key(pattern: pattern, caseInsensitive: caseInsensitive)

        return try _lock.withLock { cache in

            if let cached = cache[key] {
                return cached
            }

            var r = try Regex(pattern)
            if caseInsensitive {
                r = r.ignoresCase()
            }
            cache[key] = r
            return r
        }
    }
}
