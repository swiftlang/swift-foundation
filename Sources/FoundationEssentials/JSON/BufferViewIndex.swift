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

package struct BufferViewIndex<Element> {
    let _rawValue: UnsafeRawPointer

    @inline(__always)
    internal init(rawValue: UnsafeRawPointer) {
        _rawValue = rawValue
    }

    @inline(__always)
    var isAligned: Bool {
        (Int(bitPattern: _rawValue) & (MemoryLayout<Element>.alignment - 1)) == 0
    }
}

extension BufferViewIndex: Equatable {}

extension BufferViewIndex: Hashable {}

extension BufferViewIndex: Strideable {
    package typealias Stride = Int

    @inline(__always)
    package func distance(to other: BufferViewIndex) -> Int {
        _rawValue.distance(to: other._rawValue) / MemoryLayout<Element>.stride
    }

    @inline(__always)
    package func advanced(by n: Int) -> BufferViewIndex {
        .init(rawValue: _rawValue.advanced(by: n &* MemoryLayout<Element>.stride))
    }
}

extension BufferViewIndex: Comparable {
    @inline(__always)
    package static func < (lhs: BufferViewIndex, rhs: BufferViewIndex) -> Bool {
        lhs._rawValue < rhs._rawValue
    }
}

@available(*, unavailable)
extension BufferViewIndex: Sendable {}
