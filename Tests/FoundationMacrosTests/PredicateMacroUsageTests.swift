//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK

import Testing
import Foundation

// MARK: - Stubs

@inline(never)
fileprivate func _blackHole<T>(_ t: T) {}

@inline(never)
@available(macOS 14, iOS 17, watchOS 10, tvOS 17, *)
fileprivate func _blackHoleExplicitInput(_ predicate: Predicate<Int>) {}

// MARK: - Tests

struct PredicateMacroUsageTests {
    @available(macOS 14, iOS 17, watchOS 10, tvOS 17, *)
    @Test func testUsage() {
        _blackHole(#Predicate<Bool> {
            return $0
        })
        _blackHole(#Predicate<Bool> { input in
            return true
        })
        _blackHole(#Predicate<Bool> { input in
            return input
        })
        _blackHole(#Predicate<Bool> { input in
            return input && input
        })
        _blackHoleExplicitInput(#Predicate { input in
            return true
        })
    }
}

#endif
