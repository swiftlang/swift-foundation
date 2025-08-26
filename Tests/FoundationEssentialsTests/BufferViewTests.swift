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

import Testing

#if canImport(FoundationEssentials)
@testable import FoundationEssentials
#else
@testable import Foundation
#endif

@Suite("BufferView")
private struct BufferViewTests {

    @Test func optionalStorage() {
        #expect(
            MemoryLayout<BufferView<UInt8>>.size == MemoryLayout<BufferView<UInt8>?>.size
        )
        #expect(
            MemoryLayout<BufferView<UInt8>>.stride == MemoryLayout<BufferView<UInt8>?>.stride
        )
        #expect(
            MemoryLayout<BufferView<UInt8>>.alignment == MemoryLayout<BufferView<UInt8>?>.alignment
        )
    }

    @Test func initBufferViewOrdinaryElement() {
        let capacity = 4
        let s = (0..<capacity).map({ "\(#file)+\(#function)--\($0)" })
        s.withUnsafeBufferPointer {
            let b = BufferView(unsafeBufferPointer: $0)
            _ = b
        }
    }

    @Test func initBitwiseCopyableElement() {
        let capacity = 4
        let a = Array(0..<capacity)
        a.withUnsafeBufferPointer {
            let b = BufferView(unsafeBufferPointer: $0)!
            #expect(b.count == capacity)
        }

        let e = UnsafeBufferPointer<Int>(start: nil, count: 0)
        _ = BufferView(unsafeBufferPointer: e)

        a.withUnsafeBytes {
            let b = BufferView<UInt>(unsafeRawBufferPointer: $0)!
            #expect(b.count == capacity)

            let r = BufferView<Int8>(unsafeRawBufferPointer: $0)!
            #expect(r.count == capacity * MemoryLayout<Int>.stride)
        }

        let v = UnsafeRawBufferPointer(start: nil, count: 0)
        _ = BufferView<UInt8>(unsafeRawBufferPointer: v)
    }

    @Test func index() {
        let count = 4
        let strings = (1...count).map({ "This String is not BitwiseCopyable (\($0))." })
        strings.withUnsafeBufferPointer {
            let buffer = BufferView(unsafeBufferPointer: $0)!

            let first = buffer.startIndex
            let second = first.advanced(by: 1)
            #expect(first < second)
            #expect(1 == first.distance(to: second))
        }
    }

    @Test func iteratorOrdinaryElement() {
        let capacity = 4
        let s = (0..<capacity).map({ "\(#file)+\(#function)--\($0)" })
        s.withUnsafeBufferPointer {
            let view = BufferView(unsafeBufferPointer: $0)!

            var iterator = view.makeIterator()
            var buffered = 0
            while let value = iterator.next() {
                #expect(!value.isEmpty)
                buffered += 1
            }
            #expect(buffered == $0.count)
        }
    }

    @Test func iteratorBitwiseCopyable() {
        let count = 4
        let offset = 1
        let bytes = count * MemoryLayout<UInt64>.stride + offset
        var a = Array(repeating: UInt8.zero, count: bytes)
        #expect(offset < MemoryLayout<UInt64>.stride)

        a.withUnsafeMutableBytes {
            for i in 0..<$0.count where i % 8 == offset {
                $0.storeBytes(of: 1, toByteOffset: i, as: UInt8.self)
            }

            let orig = $0.loadUnaligned(as: Int64.self)
            #expect(orig != 1)

            // BufferView doesn't need to be aligned for accessing `BitwiseCopyable` types.
            let buffer = BufferView<Int64>(
              unsafeBaseAddress: $0.baseAddress!.advanced(by: offset),
              count: count
            )

            var iterator = buffer.makeIterator()
            var buffered = 0
            while let value = iterator.next() {
                #expect(value == 1)
                buffered += 1
            }
            #expect(buffered == count)
        }
    }

    @Test func bufferViewSequence() {
        let capacity = 4
        let a = Array(0..<capacity)

        a.withUnsafeBufferPointer {
            let view = BufferView(unsafeBufferPointer: $0)!

            var i = view.makeIterator()
            var o = $0.startIndex
            while let v = i.next() {
                #expect(v == $0[o])
                $0.formIndex(after: &o)
            }
            #expect(i.next() == nil)

            let r = view.withContiguousStorageIfAvailable { $0.reduce(0, +) }
            #expect(r == capacity * (capacity - 1) / 2)
        }

        let s = a.map(String.init)
        s.withUnsafeBufferPointer {
            let view = BufferView(unsafeBufferPointer: $0)!

            var i = view.makeIterator()
            var o = $0.startIndex
            while let v = i.next() {
                #expect(v == String($0[o]))
                $0.formIndex(after: &o)
            }
            #expect(i.next() == nil)
        }
    }

    @Test func bufferViewIndices() {
        let capacity = 4
        let a = Array(0..<capacity)
        a.withUnsafeBufferPointer {
            let view = BufferView(unsafeBufferPointer: $0)!
            #expect(view.count == view.indices.count)
        }
    }

    @Test func elementsEqual() {
        let capacity = 4
        let a = Array(0..<capacity)
        a.withUnsafeBufferPointer {
            let v1 = BufferView(unsafeBufferPointer: $0)!

            #expect(!v1.elementsEqual(v1.prefix(1)))
            #expect(v1.prefix(0).elementsEqual(v1.suffix(0)))
            #expect(v1.elementsEqual(v1))
            #expect(!v1.prefix(3).elementsEqual(v1.suffix(3)))

            let b = Array(v1)
            b.withUnsafeBufferPointer {
                let v2 = BufferView(unsafeBufferPointer: $0)!
                #expect(v1.elementsEqual(v2))
            }
        }
    }

    @Test func indexManipulation() {
        let capacity = 4
        let a = Array(0..<capacity)
        a.withUnsafeBufferPointer {
            let v = BufferView(unsafeBufferPointer: $0)!
            let indices = Array(v.indices)

            var i = v.startIndex
            #expect(i == indices[0])
            v.formIndex(after: &i)
            #expect(i == indices[1])
            i = v.endIndex
            v.formIndex(before: &i)
            #expect(i == indices.last)
            v.formIndex(&i, offsetBy: -3)
            #expect(i == indices.first)

            #expect(v.distance(from: v.startIndex, to: v.endIndex) == v.count)
        }
    }

    @Test func indexingSubscript() {
        let capacity = 4
        let a = Array(0..<capacity)
        a.withUnsafeBufferPointer {
            let v = BufferView(unsafeBufferPointer: $0)!
            #expect(v[v.startIndex] == 0)
        }

        let b = a.map(String.init)
        b.withUnsafeBufferPointer {
            let v = BufferView(unsafeBufferPointer: $0)!
            let f = v.startIndex
            #expect(v[f] == b.first)
        }
    }

    @Test func rangeOfIndicesSubscript() {
        let capacity = 4
        let a = (0..<capacity).map(String.init)
        a.withUnsafeBufferPointer {
            let v = BufferView(unsafeBufferPointer: $0)!
            #expect(v.elementsEqual(v[v.startIndex..<v.endIndex]))
            #expect(v.elementsEqual(v[v.startIndex...]))
            #expect(v.elementsEqual(v[unchecked: ..<v.endIndex]))
            #expect(v.elementsEqual(v[...]))
        }
    }

    @Test func load() {
        let capacity = 4
        let s = (0..<capacity).map({ "\(#file)+\(#function) #\($0)" })
        s.withUnsafeBytes {
            let view = BufferView<Int16>(unsafeRawBufferPointer: $0)!
            let stride = MemoryLayout<String>.stride

            let s0 = view.load(as: String.self)
            #expect(s0.contains("0"))
            let i1 = view.startIndex.advanced(by: stride / 2)
            let s1 = view.load(from: i1, as: String.self)
            #expect(s1.contains("1"))
            let s2 = view.load(fromByteOffset: 2 * stride, as: String.self)
            #expect(s2.contains("2"))
        }
    }

    @Test func loadUnaligned() {
        let capacity = 64
        let a = Array(0..<UInt8(capacity))
        a.withUnsafeBytes {
            let view = BufferView<UInt16>(unsafeRawBufferPointer: $0)!

            let u0 = view.dropFirst(1).loadUnaligned(as: UInt64.self)
            #expect(u0 & 0xff == 2)
            #expect(u0.byteSwapped & 0xff == 9)
            let i1 = view.startIndex.advanced(by: 3)
            let u1 = view.loadUnaligned(from: i1, as: UInt64.self)
            #expect(u1 & 0xff == 6)
            let u3 = view.loadUnaligned(fromByteOffset: 7, as: UInt32.self)
            #expect(u3 & 0xff == 7)
        }
    }

    @Test func offsetSubscript() {
        let capacity = 4
        let a = Array(0..<capacity)
        a.withUnsafeBufferPointer {
            let view = BufferView(unsafeBufferPointer: $0)!
            #expect(view[offset: 3] == 3)
        }
    }

    @Test func firstAndLast() {
        let r = Int.random(in: 0..<1000)
        let a = [r]
        a.withUnsafeBufferPointer {
            let view = BufferView(unsafeBufferPointer: $0)!
            #expect(view.first == r)
            #expect(view.last == r)

            let emptyView = view[view.startIndex..<view.startIndex]
            #expect(emptyView.first == nil)
            #expect(emptyView.last == nil)
        }
    }

    @Test func prefix() {
        let capacity = 4
        let a = Array(0..<capacity)
        a.withUnsafeBufferPointer {
            let view = BufferView(unsafeBufferPointer: $0)!
            #expect(view.count == capacity)
            #expect(view.prefix(1).last == 0)
            #expect(view.prefix(capacity).last == capacity - 1)
            #expect(view.dropLast(capacity).last == nil)
            #expect(view.dropLast(1).last == capacity - 2)

            #expect(view.prefix(upTo: view.startIndex).isEmpty)
            #expect(view.prefix(upTo: view.endIndex).elementsEqual(view))
        }
    }

    @Test func suffix() {
        let capacity = 4
        let a = Array(0..<capacity)
        a.withUnsafeBufferPointer {
            let view = BufferView(unsafeBufferPointer: $0)!
            #expect(view.count == capacity)
            #expect(view.suffix(1).first == capacity - 1)
            #expect(view.suffix(capacity).first == 0)
            #expect(view.dropFirst(capacity).first == nil)
            #expect(view.dropFirst(1).first == 1)

            #expect(view.suffix(from: view.startIndex).elementsEqual(a))
            #expect(view.suffix(from: view.endIndex).isEmpty)
        }
    }

    @Test func withUnsafePointer() {
        let capacity: UInt8 = 64
        let a = Array(0..<capacity)
        a.withUnsafeBufferPointer {
            ub in
            let view = BufferView(unsafeBufferPointer: ub)!

            view.withUnsafeRawPointer {
                let i = Int.random(in: 0..<$1)
                #expect($0.load(fromByteOffset: i, as: UInt8.self) == ub[i])
            }

            view.withUnsafePointer {
                let i = Int.random(in: 0..<$1)
                #expect($0[i] == ub[i])
            }
        }
    }

    @Test func withUnsafeBuffer() {
        let capacity: UInt8 = 64
        let a = Array(0..<capacity)
        a.withUnsafeBufferPointer {
            ub in
            let view = BufferView(unsafeBufferPointer: ub)!

            view.withUnsafeBytes {
                let i = Int.random(in: 0..<$0.count)
                #expect($0[i] == ub[i])
            }

            view.withUnsafeBufferPointer {
                let i = Int.random(in: 0..<$0.count)
                #expect($0[i] == ub[i])
            }
        }
    }
}
