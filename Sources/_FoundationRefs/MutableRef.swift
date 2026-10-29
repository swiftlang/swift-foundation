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

// Temporary: the standard library's `MutableRef` requires a newer OS than the package's deployment target on Darwin. Remove once the package can use it.

import Builtin

/// A safe mutable reference allowing in-place mutation of an exclusively accessed value.
public struct MutableRef<Value: ~Copyable>: ~Copyable, ~Escapable {
    @usableFromInline
    let _pointer: UnsafeMutablePointer<Value>

    @_lifetime(&value)
    @_transparent
    @inlinable
    public init(_ value: inout Value) {
        unsafe _pointer = UnsafeMutablePointer<Value>(Builtin.unprotectedAddressOf(&value))
    }

    public var value: Value {
        @_transparent
        @inlinable
        unsafeAddress {
            unsafe UnsafePointer(_pointer)
        }
        @_transparent
        @inlinable
        unsafeMutableAddress {
            unsafe _pointer
        }
    }
}

#endif
