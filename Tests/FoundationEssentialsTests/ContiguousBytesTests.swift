//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing

#if canImport(FoundationEssentials)
@testable import FoundationEssentials
#else
@testable import Foundation
#endif

func acceptContiguousBytes<T: ContiguousBytes & ~Escapable & ~Copyable>(_ bytes: borrowing T) { }

@Suite("ContiguousBytesTests")
private struct ContiguousBytesTests {
    @Test func span() throws {
        if #available(FoundationPreview 6.3, *) {
            var bytes: [UInt8] = [1, 2, 3]
            bytes.withUnsafeMutableBufferPointer { unsafeBytes in
                acceptContiguousBytes(unsafeBytes.span)
                acceptContiguousBytes(unsafeBytes.mutableSpan)
                acceptContiguousBytes(unsafeBytes.span.bytes)

                var ms = unsafeBytes.mutableSpan
                acceptContiguousBytes(ms.bytes)
                acceptContiguousBytes(ms.mutableBytes)
            }
        }
    }
}
