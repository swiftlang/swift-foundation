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

import Testing

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable import FoundationEssentials
#endif

private let threeBytes: [UInt8] = [1, 2, 3]

@Suite("Bytes to Data Conversion")
private struct DataBytesTests {
    @Test func empty() {
        #expect(Data(consuming: Bytes()) == Data())
        #expect(Data(consuming: RigidBytes()) == Data())
        #expect(Data(consuming: Bytes(capacity: 100)) == Data())
        #expect(Data(consuming: RigidBytes(capacity: 100)) == Data())
    }

    @Test func contents() {
        #expect(Data(consuming: Bytes(copying: threeBytes.span.bytes)) == Data(threeBytes))
        #expect(Data(consuming: RigidBytes(copying: threeBytes.span.bytes)) == Data(threeBytes))

        for count in [1, 14, 15, 64, 4096, 1 << 20] {
            let expected = Data((0 ..< count).map { UInt8(truncatingIfNeeded: $0) })
            var bytes = Bytes()
            for i in 0 ..< count {
                bytes.append(UInt8(truncatingIfNeeded: i))
            }
            #expect(Data(consuming: bytes) == expected, "count: \(count)")
        }
    }

    @Test func adoptsStorageWithoutCopying() {
        func address(of bytes: borrowing Bytes) -> UInt {
            bytes.span.withUnsafeBufferPointer { UInt(bitPattern: $0.baseAddress) }
        }

        let bytes = Bytes(repeating: 7, count: 1024)
        let original = address(of: bytes)
        let data = Data(consuming: bytes)
        let adopted = data.withUnsafeBytes { UInt(bitPattern: $0.baseAddress) }
        #expect(original == adopted)
        #expect(data == Data(repeating: 7, count: 1024))
    }

    @Test func growingAfterAdoption() {
        var bytes = Bytes(repeating: 0xFF, count: 64)
        bytes.removeLast(32)
        #expect(bytes.capacity == 64)

        var data = Data(consuming: bytes)
        data.count += 16
        #expect(data == Data(repeating: 0xFF, count: 32) + Data(count: 16))

        data.append(contentsOf: threeBytes)
        data.append(Data(repeating: 9, count: 100_000))
        #expect(data == Data(repeating: 0xFF, count: 32) + Data(count: 16) + Data(threeBytes) + Data(repeating: 9, count: 100_000))
    }

    @Test func copyOnWriteAfterAdoption() {
        let data = Data(consuming: Bytes(repeating: 1, count: 100))
        var copy = data
        copy[0] = 2
        #expect(data == Data(repeating: 1, count: 100))
        #expect(copy.first == 2)
    }

    @Test func geometricGrowth() {
        var bytes = Bytes()
        bytes.append(1)
        #expect(bytes.capacity == Bytes._minimumGrowthCapacity)

        var reallocations = 0
        var capacity = bytes.capacity
        for i in 0 ..< 1_000_000 {
            bytes.append(UInt8(truncatingIfNeeded: i))
            if bytes.capacity != capacity {
                #expect(bytes.capacity >= capacity + capacity / 2)
                capacity = bytes.capacity
                reallocations += 1
            }
        }
        #expect(bytes.count == 1_000_001)
        #expect(reallocations < 40)

        var exact = Bytes(capacity: 10)
        exact.append(copying: Bytes(count: 100).bytes)
        #expect(exact.capacity == 100)
    }
}
