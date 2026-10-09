//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 - 2026 Apple Inc. and the Swift project authors
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

@Suite("RigidBytes")
private struct RigidBytesTests {
    @Test func empty() {
        var d = RigidBytes()
        #expect(d.count == 0)
        #expect(d.capacity == 0)
        #expect(d.bytes.byteCount == 0)
        #expect(d.mutableBytes.byteCount == 0)
        #expect(d.span.count == 0)
        #expect(d.mutableSpan.count == 0)
        #expect(d.freeCapacity == 0)
        #expect(d.isEmpty == true)
        #expect(d.isFull == true)

        d.append(addingCount: 0) { buffer in
            #expect(buffer.capacity == 0)
        }
        d.insert(addingCount: 0, at: 0) { buffer in
            #expect(buffer.capacity == 0)
        }
        d.replaceSubrange(0 ..< 0, addingCount: 0) { buffer in
            #expect(buffer.capacity == 0)
        }
        d.edit { buffer in
            #expect(buffer.capacity == 0)
        }

        d = RigidBytes(capacity: 0)
        #expect(d.count == 0)
        #expect(d.capacity == 0)
        #expect(d.bytes.byteCount == 0)
        #expect(d.mutableBytes.byteCount == 0)
        #expect(d.span.count == 0)
        #expect(d.mutableSpan.count == 0)
        #expect(d.freeCapacity == 0)
        #expect(d.isEmpty == true)
        #expect(d.isFull == true)

        d.append(addingCount: 0) { buffer in
            #expect(buffer.capacity == 0)
        }
        d.insert(addingCount: 0, at: 0) { buffer in
            #expect(buffer.capacity == 0)
        }
        d.replaceSubrange(0 ..< 0, addingCount: 0) { buffer in
            #expect(buffer.capacity == 0)
        }
        d.edit { buffer in
            #expect(buffer.capacity == 0)
        }

        d = RigidBytes(count: 0)
        #expect(d.count == 0)
        #expect(d.capacity == 0)
        #expect(d.bytes.byteCount == 0)
        #expect(d.mutableBytes.byteCount == 0)
        #expect(d.span.count == 0)
        #expect(d.mutableSpan.count == 0)
        #expect(d.freeCapacity == 0)
        #expect(d.isEmpty == true)
        #expect(d.isFull == true)

        d.append(addingCount: 0) { buffer in
            #expect(buffer.capacity == 0)
        }
        d.insert(addingCount: 0, at: 0) { buffer in
            #expect(buffer.capacity == 0)
        }
        d.replaceSubrange(0 ..< 0, addingCount: 0) { buffer in
            #expect(buffer.capacity == 0)
        }
        d.edit { buffer in
            #expect(buffer.capacity == 0)
        }
    }
    
    @Test func initWithCapacity() {
        do {
            let d = RigidBytes(capacity: 10)
            #expect(d.count == 0)
            #expect(d.capacity == 10)
            #expect(d.bytes.byteCount == 0)
            #expect(d.span.count == 0)
            #expect(d.freeCapacity == 10)
            #expect(d.isEmpty == true)
            #expect(d.isFull == false)
        }

        do {
            let d = RigidBytes(capacity: 10) {
                #expect($0.freeCapacity == 10)
                $0.append(1)
                $0.append(2)
            }
            #expect(d.count == 2)
            #expect(d.capacity == 10)
            #expect(d.bytes.byteCount == 2)
            #expect(d.span.count == 2)
            let span = d.span
            #expect(span[0] == 1)
            #expect(span[1] == 2)
            #expect(d.freeCapacity == 8)
            #expect(d.isEmpty == false)
            #expect(d.isFull == false)
        }
    }

#if FOUNDATION_EXIT_TESTS
    @Test func initWithCapacity_preconditions() async {
        await #expect(processExitsWith: .failure) {
            _ = RigidBytes(capacity: -1)
        }
        await #expect(processExitsWith: .failure) {
            _ = RigidBytes(capacity: -1) { _ in

            }
        }
    }
#endif
      
    @Test func initWithCount() {
        let d = RigidBytes(count: 10)
        #expect(d.count == 10)
        #expect(d.capacity == 10)
        #expect(d.bytes.byteCount == 10)
        #expect(d.freeCapacity == 0)
        #expect(d.isEmpty == false)
        #expect(d.isFull == true)
        let span = d.span
        #expect(span.count == 10)
        for i in 0 ..< 10 {
            #expect(span[i] == 0)
        }
    }
        
#if FOUNDATION_EXIT_TESTS
    @Test func initWithCount_preconditions() async {
        await #expect(processExitsWith: .failure) {
            _ = RigidBytes(count: -1)
        }
    }
#endif
    
    @Test func initRepeating() {
        var d = RigidBytes(repeating: 2, count: 5)
        #expect(d.count == 5)
        #expect(d.capacity == 5)
        do {
            let span = d.span
            for i in 0 ..< 5 {
                #expect(span[i] == 2)
            }
        }

        d = RigidBytes(repeating: 2, count: 0)
        #expect(d.count == 0)
        #expect(d.capacity == 0)
    }

#if FOUNDATION_EXIT_TESTS
    @Test func initRepeating() async {
        await #expect(processExitsWith: .failure) {
            _ = RigidBytes(repeating: 2, count: -1)
        }
    }
#endif
        
    @Test func initWithSpan() {
        var d = RigidBytes(copying: threeBytes.span.bytes)
        #expect(d.count == 3)
        #expect(d.capacity == 3)
        do {
            let span = d.span
            #expect(span[0] == 1)
            #expect(span[1] == 2)
            #expect(span[2] == 3)
        }

        d = RigidBytes(copying: RigidBytes().bytes)
        #expect(d.count == 0)
        #expect(d.capacity == 0)
    }
        
    @Test func initWithNonRigid() {
        var nonRigid = Bytes(capacity: 5)
        nonRigid.append(2)
        let rigid = RigidBytes(consuming: nonRigid)
        #expect(rigid.capacity == 5)
        #expect(rigid.count == 1)
        #expect(rigid.span[0] == 2)
    }
    
    @Test func deconstruction() {
        var d = RigidBytes(capacity: 5)
        d.append(copying: threeBytes.span.bytes)
        let (buffer, count) = unsafe d.deconstruct()
        #expect(count == 3)
        #expect(buffer.count == 5)
        #expect(unsafe buffer[0] == 1)
        #expect(unsafe buffer[1] == 2)
        #expect(unsafe buffer[2] == 3)
        unsafe RigidBytes._deallocate(buffer.baseAddress!)
    }
    
    @Test func cloning() {
        let d = RigidBytes(repeating: 2, count: 5)
        let clone = d.clone()
        #expect(clone.count == 5)
        #expect(clone.capacity == 5)
        let span = d.span
        for i in 0 ..< 5 {
            #expect(span[i] == 2)
        }
        
        let d2 = RigidBytes(capacity: 3)
        let clone2 = d2.clone()
        #expect(clone2.count == 0)
        #expect(clone2.capacity == 0)

        let clone3 = d2.clone(capacity: 5)
        #expect(clone3.count == 0)
        #expect(clone3.capacity == 5)
    }
    
    @Test func spans() {
        var d = RigidBytes(repeating: 2, count: 5)
        d.reserveCapacity(10) // Add some extra, uninitialized space
        do {
            let rawSpan = d.bytes
            #expect(rawSpan.byteCount == 5)
            let span = d.span
            #expect(span.count == 5)
            for i in 0 ..< 5 {
                #expect(span[i] == 2)
            }
        }

        do {
            let mutableRawSpan = d.mutableBytes
            #expect(mutableRawSpan.byteCount == 5)
            var mutableSpan = d.mutableSpan
            #expect(mutableSpan.count == 5)
            for i in 0 ..< 5 {
                #expect(mutableSpan[i] == 2)
            }
            mutableSpan[2] = 9

            let span = d.span
            #expect(span[0] == 2)
            #expect(span[2] == 9)
        }
    }
    
    @Test func reallocation() {
        var d = RigidBytes(capacity: 3)
        d.append(8)
        d.append(9)
        #expect(d.capacity == 3)
        #expect(d.count == 2)
        d.reallocate(capacity: 3)
        #expect(d.capacity == 3)
        #expect(d.count == 2)
        do {
            let span = d.span
            #expect(span[0] == 8)
            #expect(span[1] == 9)
        }
        d.reallocate(capacity: 5)
        #expect(d.capacity == 5)
        #expect(d.count == 2)
        do {
            let span = d.span
            #expect(span[0] == 8)
            #expect(span[1] == 9)
        }

        d = RigidBytes(capacity: 10)
        d.reallocate(capacity: 0)
        #expect(d.capacity == 0)
        #expect(d.count == 0)
        #expect(d.bytes.byteCount == 0)
        d.reallocate(capacity: 10)
        #expect(d.capacity == 10)
        d.append(2)
        #expect(d.count == 1)
        #expect(d.span[0] == 2)

        d.reserveCapacity(5)
        #expect(d.capacity == 10)
        
        d.reserveCapacity(15)
        #expect(d.capacity == 15)
    }
    
#if FOUNDATION_EXIT_TESTS
    @Test func reallocation_preconditions() async {
        await #expect(processExitsWith: .failure) {
            var d = RigidBytes(count: 2)
            d.reallocate(capacity: 1)
        }
        await #expect(processExitsWith: .failure) {
            var d = RigidBytes(count: 0)
            d.reallocate(capacity: -1)
        }
    }
#endif
    
    @Test func append() {
        var d = RigidBytes(capacity: 10)
        #expect(d.count == 0)
        d.append(2)
        #expect(d.count == 1)
        #expect(d.span[0] == 2)
        d.append(copying: threeBytes.span.bytes)
        #expect(d.count == 4)
        do {
            let span = d.span
            #expect(span[0] == 2)
            #expect(span[1] == 1)
            #expect(span[2] == 2)
            #expect(span[3] == 3)
        }

        d.append(addingCount: 1) { output in
            #expect(output.freeCapacity == 1)
            output.append(5)
        }
        #expect(d.count == 5)
        do {
            let span = d.span
            #expect(span[0] == 2)
            #expect(span[1] == 1)
            #expect(span[2] == 2)
            #expect(span[3] == 3)
            #expect(span[4] == 5)
        }
    }

#if FOUNDATION_EXIT_TESTS
    @Test func append_preconditions() async {
        await #expect(processExitsWith: .failure) {
            var d = RigidBytes(capacity: 0)
            d.append(2)
        }
        await #expect(processExitsWith: .failure) {
            var d = RigidBytes(count: 5)
            d.append(2)
        }
        await #expect(processExitsWith: .failure) {
            var d = RigidBytes(capacity: 2)
            d.append(copying: threeBytes.span.bytes)
        }
        await #expect(processExitsWith: .failure) {
            var d = RigidBytes(count: 3)
            d.append(addingCount: 1) { output in
                _ = Issue.record("Should not reach this code")
            }
        }
    }
#endif

    @Test func insert() {
        var d = RigidBytes(capacity: 10)
        d.insert(1, at: 0)
        d.insert(2, at: 1)
        d.insert(3, at: 2)
        #expect(d.count == 3)
        d.insert(5, at: 1)
        #expect(d.count == 4)
        do {
            let span = d.span
            #expect(span[0] == 1)
            #expect(span[1] == 5)
            #expect(span[2] == 2)
            #expect(span[3] == 3)
        }
        d.insert(copying: threeBytes.span.bytes, at: 0)
        #expect(d.count == 7)
        do {
            let span = d.span
            #expect(span[0] == 1)
            #expect(span[1] == 2)
            #expect(span[2] == 3)
            #expect(span[3] == 1)
            #expect(span[4] == 5)
            #expect(span[5] == 2)
            #expect(span[6] == 3)
        }

        d.insert(addingCount: 1, at: 4) { output in
            #expect(output.freeCapacity == 1)
            output.append(9)
        }
        #expect(d.count == 8)
        do {
            let span = d.span
            #expect(span[0] == 1)
            #expect(span[1] == 2)
            #expect(span[2] == 3)
            #expect(span[3] == 1)
            #expect(span[4] == 9)
            #expect(span[5] == 5)
            #expect(span[6] == 2)
            #expect(span[7] == 3)
        }
    }
    
#if FOUNDATION_EXIT_TESTS
    @Test func insert_preconditions() async {
        await #expect(processExitsWith: .failure) {
            var d = RigidBytes(capacity: 0)
            d.insert(2, at: 0)
        }
        await #expect(processExitsWith: .failure) {
            var d = RigidBytes(count: 5)
            d.insert(copying: threeBytes.span.bytes, at: 1)
        }
        await #expect(processExitsWith: .failure) {
            var d = RigidBytes(capacity: 2)
            d.insert(copying: threeBytes.span.bytes, at: 0)
        }
        await #expect(processExitsWith: .failure) {
            var d = RigidBytes(count: 3)
            d.insert(addingCount: 1, at: 1) { output in
                _ = Issue.record("Should not reach this code")
            }
        }
        await #expect(processExitsWith: .failure) {
            var d = RigidBytes(capacity: 3)
            d.insert(addingCount: 1, at: 0) { output in
                // Intentionally do not append promised byte
            }
        }
    }
#endif

    @Test func remove() {
        var d = RigidBytes(capacity: 10)
        d.append(copying: threeBytes.span.bytes)
        d.append(copying: threeBytes.span.bytes)
        d.append(copying: threeBytes.span.bytes)

        #expect(d.removeLast() == 3)
        #expect(d.count == 8)
        #expect(d.capacity == 10)

        d.removeLast(2)
        #expect(d.count == 6)
        #expect(d.capacity == 10)

        #expect(d.remove(at: 1) == 2)
        #expect(d.span[1] == 3)
        #expect(d.count == 5)
        #expect(d.capacity == 10)

        d.removeAll()
        #expect(d.count == 0)
        #expect(d.capacity == 10)

        d = RigidBytes(copying: threeBytes.span.bytes)
        d.removeSubrange(...2)
        #expect(d.count == 0)
        #expect(d.capacity == 3)
    }

#if FOUNDATION_EXIT_TESTS
    @Test func remove_preconditions() async {
        await #expect(processExitsWith: .failure) {
            var d = RigidBytes(capacity: 2)
            d.removeLast()
        }
        await #expect(processExitsWith: .failure) {
            var d = RigidBytes(count: 2)
            d.removeLast(3)
        }
        await #expect(processExitsWith: .failure) {
            var d = RigidBytes(count: 2)
            d.remove(at: -1)
        }
        await #expect(processExitsWith: .failure) {
            var d = RigidBytes(count: 2)
            d.remove(at: 3)
        }
        await #expect(processExitsWith: .failure) {
            var d = RigidBytes(count: 2)
            d.removeSubrange(-1 ..< 1)
        }
        await #expect(processExitsWith: .failure) {
            var d = RigidBytes(count: 2)
            d.removeSubrange(0 ..< 5)
        }
    }
#endif

    @Test func resetBytes() {
        var d = RigidBytes(repeating: 3, count: 10)
        d.resetBytes(in: 3 ..< 6)
        do {
            let span = d.span
            for i in 0 ..< 10 {
                if (3 ..< 6).contains(i) {
                    #expect(span[i] == 0)
                } else {
                    #expect(span[i] == 3)
                }
            }
        }

        d.resetBytes(in: 1 ..< 1)
        do {
            let span = d.span
            #expect(span[0] == 3)
            #expect(span[1] == 3)
            #expect(span[2] == 3)
        }
    }

#if FOUNDATION_EXIT_TESTS
    @Test func resetBytes_preconditions() async {
        await #expect(processExitsWith: .failure) {
            var d = RigidBytes(capacity: 10)
            d.resetBytes(in: 0 ..< 3)
        }
        await #expect(processExitsWith: .failure) {
            var d = RigidBytes(capacity: 10)
            d.resetBytes(in: -2 ..< 0)
        }
        await #expect(processExitsWith: .failure) {
            var d = RigidBytes(count: 10)
            d.resetBytes(in: 11 ..< 13)
        }
        await #expect(processExitsWith: .failure) {
            var d = RigidBytes(count: 10)
            d.resetBytes(in: -3 ..< -2)
        }
    }
#endif
    
    @Test func replaceSubrange() {
        do {
            var d = RigidBytes(repeating: 4, count: 10)
            d.replaceSubrange(3 ..< 6, copying: threeBytes.span.bytes)
            #expect(d.count == 10)
            do {
                let span = d.span
                for i in 0 ..< 3 {
                    #expect(span[i] == 4)
                }
                #expect(span[3] == 1)
                #expect(span[4] == 2)
                #expect(span[5] == 3)
                for i in 6 ..< 10 {
                    #expect(span[i] == 4)
                }
            }

            d.replaceSubrange(0 ..< 9, copying: threeBytes.span.bytes)
            #expect(d.count == 4)
            #expect(d.capacity == 10)
            do {
                let span = d.span
                #expect(span[0] == 1)
                #expect(span[1] == 2)
                #expect(span[2] == 3)
                #expect(span[3] == 4)
            }

            d.replaceSubrange(0 ..< 1, copying: threeBytes.span.bytes)
            #expect(d.count == 6)
            #expect(d.capacity == 10)
            do {
                let span = d.span
                #expect(span[0] == 1)
                #expect(span[1] == 2)
                #expect(span[2] == 3)
                #expect(span[3] == 2)
                #expect(span[4] == 3)
                #expect(span[5] == 4)
            }
        }

        do {
            var d = RigidBytes(repeating: 4, count: 10)
            d.replaceSubrange(3 ..< 6, addingCount: 2) { buffer in
                #expect(buffer.isEmpty == true)
                #expect(buffer.freeCapacity == 2)
                buffer.append(1)
                buffer.append(2)
            }
            #expect(d.count == 9)
            do {
                let span = d.span
                for i in 0 ..< 3 {
                    #expect(span[i] == 4)
                }
                #expect(span[3] == 1)
                #expect(span[4] == 2)
                for i in 6 ..< 9 {
                    #expect(span[i] == 4)
                }
            }

            d.replaceSubrange(1 ..< 4, addingCount: 4) { buffer in
                #expect(buffer.isEmpty == true)
                #expect(buffer.capacity == 4)
            }
            #expect(d.count == 6)
            #expect(d.capacity == 10)
        }
    }
        
#if FOUNDATION_EXIT_TESTS
    @Test func replaceSubrange_preconditions() async {
        await #expect(processExitsWith: .failure) {
            var d = RigidBytes(capacity: 10)
            d.replaceSubrange(0 ..< 3, copying: threeBytes.span.bytes)
        }
        await #expect(processExitsWith: .failure) {
            var d = RigidBytes(capacity: 10)
            d.replaceSubrange(-2 ..< 0, copying: threeBytes.span.bytes)
        }
        await #expect(processExitsWith: .failure) {
            var d = RigidBytes(count: 10)
            d.replaceSubrange(11 ..< 13, copying: threeBytes.span.bytes)
        }
        await #expect(processExitsWith: .failure) {
            var d = RigidBytes(count: 10)
            d.replaceSubrange(-3 ..< -2, copying: threeBytes.span.bytes)
        }
        await #expect(processExitsWith: .failure) {
            var d = RigidBytes(count: 10)
            d.replaceSubrange(1 ..< 2, copying: threeBytes.span.bytes)
        }
        await #expect(processExitsWith: .failure) {
            var d = RigidBytes(capacity: 10)
            d.replaceSubrange(1 ..< 2, addingCount: 5) { buffer in

            }
        }
        await #expect(processExitsWith: .failure) {
            var d = RigidBytes(capacity: 10)
            d.replaceSubrange(-2 ..< 0, addingCount: 1) { buffer in

            }
        }
        await #expect(processExitsWith: .failure) {
            var d = RigidBytes(count: 10)
            d.replaceSubrange(11 ..< 13, addingCount: 1) { buffer in

            }
        }
        await #expect(processExitsWith: .failure) {
            var d = RigidBytes(count: 10)
            d.replaceSubrange(-3 ..< -2, addingCount: 1) { buffer in

            }
        }
    }
#endif

    @Test func edit() {
        var d = RigidBytes(capacity: 10)
        d.append(copying: threeBytes.span.bytes)
        d.edit { buffer in
            #expect(buffer.byteCount == 3)
            #expect(buffer.capacity == 10)
            #expect(unsafe buffer.bytes.unsafeLoad(as: UInt8.self) == 1)
        }
    }

    @Test func asUInt64s() {
        var bytes = RigidBytes(count: MemoryLayout<UInt64>.size * 3)
        var mutableBytes = bytes.mutableBytes
        var span64 = unsafe mutableBytes._unsafeMutableView(as: UInt64.self)
        span64[0] = 1
        span64[1] = 1
        span64[2] = 1

        let span8 = bytes.span
        var count = 0
        for i in span8.indices {
            if span8[i] != 0 {
                count += 1
            }
        }
        #expect(count == 3)
    }
}
