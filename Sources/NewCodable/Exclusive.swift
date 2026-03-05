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


import Builtin

@frozen
public struct Exclusive<T: ~Copyable>: ~Copyable {
    @usableFromInline
    let value: T

  @_alwaysEmitIntoClient
  @_transparent
  public init(_ value: consuming T) {
      self.value = consume value
  }
}

extension Exclusive where T: ~Copyable {
    // TODO: Tried @_transparent, but it crashes the compiler?
    @_alwaysEmitIntoClient
    public consuming func take() -> T {
        value
    }
}

extension Exclusive where T: Copyable {
    @_alwaysEmitIntoClient
    @_transparent
    public borrowing func copy() -> T {
        value
    }
}

extension Optional where Wrapped: ~Copyable {
    @_alwaysEmitIntoClient
    public consuming func exclusive() -> Exclusive<Wrapped>? {
        _consumingMap { Exclusive($0) }
    }
}
