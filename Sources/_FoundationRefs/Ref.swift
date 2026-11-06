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

#if canImport(Darwin)

// Temporary: the standard library's `Ref` requires a newer OS than the package's deployment target on Darwin. This lives in its own module because some compiler builds assert when compiling it with strict concurrency checking enabled. Remove once the package can use the standard library's.

import Builtin

/// A safe reference allowing in-place reads to a shared value.
public struct Ref<Value: ~Copyable>: Copyable, ~Escapable {
    @usableFromInline
    let _builtin: Builtin.Borrow<Value>

    @_lifetime(borrow value)
    @_transparent
    @inlinable
    public init(_ value: borrowing Value) {
        _builtin = Builtin.makeBorrow(value)
    }

    public var value: Value {
        @_transparent
        @inlinable
        borrow {
            Builtin.dereferenceBorrow(_builtin)
        }
    }
}

#endif
