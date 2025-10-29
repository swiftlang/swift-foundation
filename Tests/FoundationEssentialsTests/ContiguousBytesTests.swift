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

#if compiler(>=6.2)

func acceptContiguousBytes(_ bytes: borrowing some ContiguousBytes & ~Escapable & ~Copyable) { }

@Suite("ContiguousBytesTests")
private struct ContiguousBytesTests {
    @available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *)
    @Test func span() throws {
        if #available(FoundationPreview 6.3, *) {
            var bytes: [UInt8] = [1, 2, 3]
            acceptContiguousBytes(bytes.span)
            acceptContiguousBytes(bytes.mutableSpan)
            acceptContiguousBytes(bytes.span.bytes)

            let ms = bytes.mutableSpan
            acceptContiguousBytes(ms.bytes)
        }
    }
}

#endif
