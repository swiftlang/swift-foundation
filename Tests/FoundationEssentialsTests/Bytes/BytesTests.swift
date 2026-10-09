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

@Suite("Bytes")
private struct BytesTests {
    @Test func repro() async {
        do {
            let d = Bytes(capacity: 10)
            #expect(d.count == 0)   // the capture creates the box
        }                           // the box is destroyed before the suspension
        await Task.yield()          // the copied debug_value lands after the destroy
    }
    
    @Test func empty() {
        var d = Bytes()
        #expect(d.count == 0)
        #expect(d.bytes.byteCount == 0)
        #expect(d.mutableBytes.byteCount == 0)
        #expect(d.span.count == 0)
        #expect(d.mutableSpan.count == 0)
        #expect(d.isEmpty == true)
        
        d = Bytes(capacity: 0)
        #expect(d.count == 0)
        #expect(d.bytes.byteCount == 0)
        #expect(d.mutableBytes.byteCount == 0)
        #expect(d.span.count == 0)
        #expect(d.mutableSpan.count == 0)
        #expect(d.isEmpty == true)
        
        d = Bytes(count: 0)
        #expect(d.count == 0)
        #expect(d.bytes.byteCount == 0)
        #expect(d.mutableBytes.byteCount == 0)
        #expect(d.span.count == 0)
        #expect(d.mutableSpan.count == 0)
        #expect(d.isEmpty == true)
    }
    
    @Test func initWithCapacity() {
        let d = Bytes(capacity: 10)
        #expect(d.count == 0)
        #expect(d.bytes.byteCount == 0)
        #expect(d.isEmpty == true)

        do {
            let d = Bytes(capacity: 10) {
                #expect($0.freeCapacity == 10)
                $0.append(1)
                $0.append(2)
            }
            #expect(d.count == 2)
            #expect(d.bytes.byteCount == 2)
            #expect(d.span.count == 2)
            let span = d.span
            #expect(span[0] == 1)
            #expect(span[1] == 2)
            #expect(d.isEmpty == false)
        }

    }
      
    @Test func initWithCount() {
        let d = Bytes(count: 10)
        #expect(d.count == 10)
        #expect(d.bytes.byteCount == 10)
        #expect(d.isEmpty == false)
        let span = d.span
        for i in 0 ..< 9 {
                #expect(span[i] == 0)
        }
        
    }
    
    @Test func initRepeating() {
        do {
            let d = Bytes(repeating: 2, count: 5)
            #expect(d.count == 5)
            let span = d.span
            for i in 0 ..< 5 {
                #expect(span[i] == 2)
            }
        }

        do {
            let d = Bytes(repeating: 2, count: 0)
            #expect(d.count == 0)
        }

    }
        
    @Test func initWithSpan() {
        do {
            let d = Bytes(copying: threeBytes.span.bytes)
            #expect(d.count == 3)
            let span = d.span
            #expect(span[0] == 1)
            #expect(span[1] == 2)
            #expect(span[2] == 3)
        }

        do {
            let d = Bytes(copying: Bytes().bytes)
            #expect(d.count == 0)
        }
    }
    
    @Test func initWithRigid() {
        var rigid = RigidBytes(capacity: 5)
        rigid.append(2)
        var nonRigid = Bytes(consuming: rigid)
        #expect(nonRigid.count == 1)
        #expect(nonRigid.span[0] == 2)
        nonRigid.append(copying: threeBytes.span.bytes)
        nonRigid.append(copying: threeBytes.span.bytes)
        #expect(nonRigid.count == 7)
    }
    
    @Test func deconstruction() {
        var d = Bytes(capacity: 5)
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
        let d = Bytes(repeating: 2, count: 5)
        let clone = d.clone()
        #expect(clone.count == 5)
        let span = d.span
        for i in 0 ..< 5 {
            #expect(span[i] == 2)
        }
        
        let d2 = Bytes(capacity: 3)
        let clone2 = d2.clone()
        #expect(clone2.count == 0)

        let clone3 = d2.clone(capacity: 5)
        #expect(clone3.count == 0)
    }
    
    @Test func spans() {
        var d = Bytes(repeating: 2, count: 5)
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

            #expect(mutableSpan[0] == 2)
            #expect(mutableSpan[2] == 9)
        }
    }
    
    @Test func append() {
        var d = Bytes(capacity: 10)
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

        d = Bytes(capacity: 0)
        d.append(2)
        #expect(d.count == 1)
        #expect(d.span[0] == 2)

        
        d = Bytes(count: 5)
        d.append(copying: threeBytes.span.bytes)
        #expect(d.count == 8)
        do {
            let span = d.span
            #expect(span[4] == 0)
            #expect(span[5] == 1)
        }

        d = Bytes(count: 5)
        d.append(addingCount: 1) {
            #expect($0.freeCapacity == 1)
            $0.append(3)
        }
        #expect(d.count == 6)
        do {
            let span = d.span
            #expect(span[4] == 0)
            #expect(span[5] == 3)
        }
    }

    @Test func insert() {
        var d = Bytes(capacity: 10)
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

        d = Bytes(capacity: 0)
        d.insert(2, at: 0)
        #expect(d.count == 1)
        #expect(d.span[0] == 2)

        d = Bytes(count: 5)
        d.insert(copying: threeBytes.span.bytes, at: 1)
        #expect(d.count == 8)
        #expect(d.span[0] == 0)
        #expect(d.span[1] == 1)

        d = Bytes(capacity: 2)
        d.insert(copying: threeBytes.span.bytes, at: 0)
        #expect(d.count == 3)

        d = Bytes(count: 3)
        d.insert(addingCount: 1, at: 1) { output in
            #expect(output.freeCapacity == 1)
            output.append(2)
        }
        #expect(d.count == 4)

    }

    @Test func remove() {
        var d = Bytes(capacity: 10)
        d.append(copying: threeBytes.span.bytes)
        d.append(copying: threeBytes.span.bytes)
        d.append(copying: threeBytes.span.bytes)

        #expect(d.removeLast() == 3)
        #expect(d.count == 8)

        d.removeLast(2)
        #expect(d.count == 6)

        #expect(d.remove(at: 1) == 2)
        #expect(d.span[1] == 3)
        #expect(d.count == 5)

        d.removeAll()
        #expect(d.count == 0)

        d = Bytes(copying: threeBytes.span.bytes)
        d.removeSubrange(...2)
        #expect(d.count == 0)

    }

    @Test func resetBytes() {
        var d = Bytes(repeating: 3, count: 10)
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

    @Test func replaceSubrange() {
        do {
            var d = Bytes(repeating: 4, count: 10)
            d.replaceSubrange(3 ..< 6, copying: threeBytes.span.bytes)
            do {
                let span = d.span
                #expect(d.count == 10)
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
            do {
                let span = d.span
                #expect(span[0] == 1)
                #expect(span[1] == 2)
                #expect(span[2] == 3)
                #expect(span[3] == 4)
            }

            d.replaceSubrange(0 ..< 1, copying: threeBytes.span.bytes)
            do {
                let span = d.span
                #expect(d.count == 6)
                #expect(span[0] == 1)
                #expect(span[1] == 2)
                #expect(span[2] == 3)
                #expect(span[3] == 2)
                #expect(span[4] == 3)
                #expect(span[5] == 4)
            }
        }
        
        do {
            var d = Bytes(count: 10)
            d.replaceSubrange(1 ..< 3, copying: threeBytes.span.bytes)
            #expect(d.count == 11)
        }

    }

    @Test func edit() {
        var d = Bytes(capacity: 10)
        d.append(copying: threeBytes.span.bytes)
        d.edit { buffer in
            #expect(buffer.byteCount == 3)
            #expect(buffer.capacity == 10)
            #expect(unsafe buffer.bytes.unsafeLoad(as: UInt8.self) == 1)
        }
    }
}
