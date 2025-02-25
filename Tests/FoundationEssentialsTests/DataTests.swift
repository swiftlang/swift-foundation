//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(TestSupport)
import TestSupport
#endif

#if canImport(Glibc)
@preconcurrency import Glibc
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable import FoundationEssentials
#endif // FOUNDATION_FRAMEWORK

extension Data {
    func withUnsafeUInt8Bytes<R>(_ c: (UnsafePointer<UInt8>) throws -> R) rethrows -> R {
        return try self.withUnsafeBytes { (ptr) in
            return try ptr.baseAddress!.withMemoryRebound(to: UInt8.self, capacity: ptr.count) {
                return try c($0)
            }
        }
    }

    mutating func withUnsafeMutableUInt8Bytes<R>(_ c: (UnsafeMutablePointer<UInt8>) throws -> R) rethrows -> R {
        return try self.withUnsafeMutableBytes { (ptr) in
            return try ptr.baseAddress!.withMemoryRebound(to: UInt8.self, capacity: ptr.count) {
                return try c($0)
            }
        }
    }
}

class DataTests : XCTestCase {

    var heldData: Data?

    // this holds a reference while applying the function which forces the internal ref type to become non-uniquely referenced
    func holdReference(_ data: Data, apply: () -> Void) {
        heldData = data
        apply()
        heldData = nil
    }

    // MARK: -

    // String of course has its own way to get data, but this way tests our own data struct
    func dataFrom(_ string : String) -> Data {
        // Create a Data out of those bytes
        return string.utf8CString.withUnsafeBufferPointer { (ptr) in
            ptr.baseAddress!.withMemoryRebound(to: UInt8.self, capacity: ptr.count) {
                // Subtract 1 so we don't get the null terminator byte. This matches NSString behavior.
                return Data(bytes: $0, count: ptr.count - 1)
            }
        }
    }

    // MARK: -

    func testBasicConstruction() {

        // Make sure that we were able to create some data
        let hello = dataFrom("hello")
        let helloLength = hello.count
        XCTAssertEqual(hello[0], 0x68, "Unexpected first byte")

        let world = dataFrom(" world")
        var helloWorld = hello
        world.withUnsafeUInt8Bytes {
            helloWorld.append($0, count: world.count)
        }

        XCTAssertEqual(hello[0], 0x68, "First byte should not have changed")
        XCTAssertEqual(hello.count, helloLength, "Length of first data should not have changed")
        XCTAssertEqual(helloWorld.count, hello.count + world.count, "The total length should include both buffers")
    }

    func testInitializationWithArray() {
        let data = Data([1, 2, 3])
        XCTAssertEqual(3, data.count)

        let data2 = Data([1, 2, 3].filter { $0 >= 2 })
        XCTAssertEqual(2, data2.count)

        let data3 = Data([1, 2, 3, 4, 5][1..<3])
        XCTAssertEqual(2, data3.count)
    }

    func testInitializationWithBufferPointer() {
        let nilBuffer = UnsafeBufferPointer<UInt8>(start: nil, count: 0)
        let data = Data(buffer: nilBuffer)
        XCTAssertEqual(data, Data())

        let validPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: 2)
        validPointer[0] = 0xCA
        validPointer[1] = 0xFE
        defer { validPointer.deallocate() }

        let emptyBuffer = UnsafeBufferPointer<UInt8>(start: validPointer, count: 0)
        let data2 = Data(buffer: emptyBuffer)
        XCTAssertEqual(data2, Data())

        let shortBuffer = UnsafeBufferPointer<UInt8>(start: validPointer, count: 1)
        let data3 = Data(buffer: shortBuffer)
        XCTAssertEqual(data3, Data([0xCA]))

        let fullBuffer = UnsafeBufferPointer<UInt8>(start: validPointer, count: 2)
        let data4 = Data(buffer: fullBuffer)
        XCTAssertEqual(data4, Data([0xCA, 0xFE]))

        let tuple: (UInt16, UInt16, UInt16, UInt16) = (0xFF, 0xFE, 0xFD, 0xFC)
        withUnsafeBytes(of: tuple) {
            // If necessary, port this to big-endian.
            let tupleBuffer: UnsafeBufferPointer<UInt8> = $0.bindMemory(to: UInt8.self)
            let data5 = Data(buffer: tupleBuffer)
            XCTAssertEqual(data5, Data([0xFF, 0x00, 0xFE, 0x00, 0xFD, 0x00, 0xFC, 0x00]))
        }
    }

    func testInitializationWithMutableBufferPointer() {
        let nilBuffer = UnsafeMutableBufferPointer<UInt8>(start: nil, count: 0)
        let data = Data(buffer: nilBuffer)
        XCTAssertEqual(data, Data())

        let validPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: 2)
        validPointer[0] = 0xCA
        validPointer[1] = 0xFE
        defer { validPointer.deallocate() }

        let emptyBuffer = UnsafeMutableBufferPointer<UInt8>(start: validPointer, count: 0)
        let data2 = Data(buffer: emptyBuffer)
        XCTAssertEqual(data2, Data())

        let shortBuffer = UnsafeMutableBufferPointer<UInt8>(start: validPointer, count: 1)
        let data3 = Data(buffer: shortBuffer)
        XCTAssertEqual(data3, Data([0xCA]))

        let fullBuffer = UnsafeMutableBufferPointer<UInt8>(start: validPointer, count: 2)
        let data4 = Data(buffer: fullBuffer)
        XCTAssertEqual(data4, Data([0xCA, 0xFE]))

        var tuple: (UInt16, UInt16, UInt16, UInt16) = (0xFF, 0xFE, 0xFD, 0xFC)
        withUnsafeMutableBytes(of: &tuple) {
            // If necessary, port this to big-endian.
            let tupleBuffer: UnsafeMutableBufferPointer<UInt8> = $0.bindMemory(to: UInt8.self)
            let data5 = Data(buffer: tupleBuffer)
            XCTAssertEqual(data5, Data([0xFF, 0x00, 0xFE, 0x00, 0xFD, 0x00, 0xFC, 0x00]))
        }
    }

    func testMutableData() {
        let hello = dataFrom("hello")
        let helloLength = hello.count
        XCTAssertEqual(hello[0], 0x68, "Unexpected first byte")

        // Double the length
        var mutatingHello = hello
        mutatingHello.count *= 2

        XCTAssertEqual(hello.count, helloLength, "The length of the initial data should not have changed")
        XCTAssertEqual(mutatingHello.count, helloLength * 2, "The length should have changed")

        // Get the underlying data for hello2
        mutatingHello.withUnsafeMutableUInt8Bytes { (bytes : UnsafeMutablePointer<UInt8>) in
            XCTAssertEqual(bytes.pointee, 0x68, "First byte should be 0x68")

            // Mutate it
            bytes.pointee = 0x67
            XCTAssertEqual(bytes.pointee, 0x67, "First byte should be 0x67")

            // Verify that the first data is still correct
            XCTAssertEqual(hello[0], 0x68, "The first byte should still be 0x68")
        }
    }

    func testEquality() {
        let d1 = dataFrom("hello")
        let d2 = dataFrom("hello")

        // Use == explicitly here to make sure we're calling the right methods
        XCTAssertTrue(d1 == d2, "Data should be equal")
    }

    func testDataInSet() {
        let d1 = dataFrom("Hello")
        let d2 = dataFrom("Hello")
        let d3 = dataFrom("World")

        var s = Set<Data>()
        s.insert(d1)
        s.insert(d2)
        s.insert(d3)

        XCTAssertEqual(s.count, 2, "Expected only two entries in the Set")
    }

    func testReplaceSubrange() {
        var hello = dataFrom("Hello")
        let world = dataFrom("World")

        hello[0] = world[0]
        XCTAssertEqual(hello[0], world[0])

        var goodbyeWorld = dataFrom("Hello World")
        let goodbye = dataFrom("Goodbye")
        let expected = dataFrom("Goodbye World")

        goodbyeWorld.replaceSubrange(0..<5, with: goodbye)
        XCTAssertEqual(goodbyeWorld, expected)
    }

    func testReplaceSubrange3() {
        // The expected result
        let expectedBytes : [UInt8] = [1, 2, 9, 10, 11, 12, 13]
        let expected = expectedBytes.withUnsafeBufferPointer {
            return Data(buffer: $0)
        }

        // The data we'll mutate
        let someBytes : [UInt8] = [1, 2, 3, 4, 5]
        var a = someBytes.withUnsafeBufferPointer {
            return Data(buffer: $0)
        }

        // The bytes we'll insert
        let b : [UInt8] = [9, 10, 11, 12, 13]
        b.withUnsafeBufferPointer {
            a.replaceSubrange(2..<5, with: $0)
        }
        XCTAssertEqual(expected, a)
    }

    func testReplaceSubrange4() {
        let expectedBytes : [UInt8] = [1, 2, 9, 10, 11, 12, 13]
        let expected = Data(expectedBytes)

        // The data we'll mutate
        let someBytes : [UInt8] = [1, 2, 3, 4, 5]
        var a = Data(someBytes)

        // The bytes we'll insert
        let b : [UInt8] = [9, 10, 11, 12, 13]
        a.replaceSubrange(2..<5, with: b)
        XCTAssertEqual(expected, a)
    }

    func testReplaceSubrange5() {
        var d = Data([1, 2, 3])
        d.replaceSubrange(0..<0, with: [4])
        XCTAssertEqual(Data([4, 1, 2, 3]), d)

        d.replaceSubrange(0..<4, with: [9])
        XCTAssertEqual(Data([9]), d)

        d.replaceSubrange(0..<d.count, with: [])
        XCTAssertEqual(Data(), d)

        d.replaceSubrange(0..<0, with: [1, 2, 3, 4])
        XCTAssertEqual(Data([1, 2, 3, 4]), d)

        d.replaceSubrange(1..<3, with: [9, 8])
        XCTAssertEqual(Data([1, 9, 8, 4]), d)

        d.replaceSubrange(d.count..<d.count, with: [5])
        XCTAssertEqual(Data([1, 9, 8, 4, 5]), d)
    }

    func testInsertData() {
        let hello = dataFrom("Hello")
        let world = dataFrom(" World")
        let expected = dataFrom("Hello World")
        var helloWorld = dataFrom("")

        helloWorld.replaceSubrange(0..<0, with: world)
        helloWorld.replaceSubrange(0..<0, with: hello)

        XCTAssertEqual(helloWorld, expected)
    }

    func testLoops() {
        let hello = dataFrom("Hello")
        var count = 0
        for _ in hello {
            count += 1
        }
        XCTAssertEqual(count, 5)
    }

    func testGenericAlgorithms() {
        let hello = dataFrom("Hello World")

        let isCapital = { (byte : UInt8) in byte >= 65 && byte <= 90 }

        let allCaps = hello.filter(isCapital)
        XCTAssertEqual(allCaps.count, 2)

        let capCount = hello.reduce(0) { isCapital($1) ? $0 + 1 : $0 }
        XCTAssertEqual(capCount, 2)

        let allLower = hello.map { isCapital($0) ? $0 + 31 : $0 }
        XCTAssertEqual(allLower.count, hello.count)
    }

    func testCopyBytes() {
        let c = 10
        let underlyingBuffer = malloc(c * MemoryLayout<UInt16>.stride)!
        let u16Ptr = underlyingBuffer.bindMemory(to: UInt16.self, capacity: c)
        let buffer = UnsafeMutableBufferPointer<UInt16>(start: u16Ptr, count: c)

        buffer[0] = 0
        buffer[1] = 0

        var data = Data(capacity: c * MemoryLayout<UInt16>.stride)
        data.resetBytes(in: 0..<c * MemoryLayout<UInt16>.stride)
        data[0] = 0xFF
        data[1] = 0xFF
        let copiedCount = data.copyBytes(to: buffer)
        XCTAssertEqual(copiedCount, c * MemoryLayout<UInt16>.stride)

        XCTAssertEqual(buffer[0], 0xFFFF)
        free(underlyingBuffer)
    }

    func testCopyBytes_undersized() {
        let a : [UInt8] = [1, 2, 3, 4, 5]
        let data = a.withUnsafeBufferPointer {
            return Data(buffer: $0)
        }
        let expectedSize = MemoryLayout<UInt8>.stride * a.count
        XCTAssertEqual(expectedSize, data.count)

        let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: expectedSize - 1, alignment: MemoryLayout<UInt8>.size)
        // We should only copy in enough bytes that can fit in the buffer
        let copiedCount = data.copyBytes(to: buffer)
        XCTAssertEqual(expectedSize - 1, copiedCount)

        var index = 0
        for v in a[0..<expectedSize-1] {
            XCTAssertEqual(v, buffer[index])
            index += 1
        }

        buffer.deallocate()
    }

    func testCopyBytes_oversized() {
        let a : [Int32] = [1, 0, 1, 0, 1]
        let data = a.withUnsafeBufferPointer {
            return Data(buffer: $0)
        }
        let expectedSize = MemoryLayout<Int32>.stride * a.count
        XCTAssertEqual(expectedSize, data.count)

        let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: expectedSize, alignment: MemoryLayout<UInt8>.size)
        let copiedCount = data.copyBytes(to: buffer)
        XCTAssertEqual(expectedSize, copiedCount)

        buffer.deallocate()
    }

    func testCopyBytes_ranges() {

        do {
            // Equal sized buffer, data
            let a : [UInt8] = [1, 2, 3, 4, 5]
            let data = a.withUnsafeBufferPointer {
                return Data(buffer: $0)
            }

            let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: data.count, alignment: MemoryLayout<UInt8>.size)

            var copiedCount : Int

            copiedCount = data.copyBytes(to: buffer, from: 0..<0)
            XCTAssertEqual(0, copiedCount)

            copiedCount = data.copyBytes(to: buffer, from: 1..<1)
            XCTAssertEqual(0, copiedCount)

            copiedCount = data.copyBytes(to: buffer, from: 0..<3)
            XCTAssertEqual((0..<3).count, copiedCount)

            var index = 0
            for v in a[0..<3] {
                XCTAssertEqual(v, buffer[index])
                index += 1
            }
            buffer.deallocate()
        }

        do {
            // Larger buffer than data
            let a : [UInt8] = [1, 2, 3, 4]
            let data = a.withUnsafeBufferPointer {
                return Data(buffer: $0)
            }

            let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 10, alignment: MemoryLayout<UInt8>.size)
            var copiedCount : Int

            copiedCount = data.copyBytes(to: buffer, from: 0..<3)
            XCTAssertEqual((0..<3).count, copiedCount)

            var index = 0
            for v in a[0..<3] {
                XCTAssertEqual(v, buffer[index])
                index += 1
            }
            buffer.deallocate()
        }

        do {
            // Larger data than buffer
            let a : [UInt8] = [1, 2, 3, 4, 5, 6]
            let data = a.withUnsafeBufferPointer {
                return Data(buffer: $0)
            }

            let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 4, alignment: MemoryLayout<UInt8>.size)

            var copiedCount : Int

            copiedCount = data.copyBytes(to: buffer, from: 0..<data.index(before: data.endIndex))
            XCTAssertEqual(4, copiedCount)

            var index = 0
            for v in a[0..<4] {
                XCTAssertEqual(v, buffer[index])
                index += 1
            }
            buffer.deallocate()

        }
    }

    func testCopyBytes_fromSubSequenceToGenericBuffer() {
        let source = Data([1, 3, 5, 7, 9])[1..<3]
        var destination = Array<UInt8>(repeating: 8, count: 4)
        
        destination.withUnsafeMutableBufferPointer {
            let count = source.copyBytes(to: $0)
            XCTAssertEqual(count, 2)
        }
        
        XCTAssertEqual(destination, [3, 5, 8, 8])
    }

    func test_genericBuffers() {
        let a : [Int32] = [1, 0, 1, 0, 1]
        var data = a.withUnsafeBufferPointer {
            return Data(buffer: $0)
        }

        var expectedSize = MemoryLayout<Int32>.stride * a.count
        XCTAssertEqual(expectedSize, data.count)

        [false, true].withUnsafeBufferPointer {
            data.append($0)
        }

        expectedSize += MemoryLayout<Bool>.stride * 2
        XCTAssertEqual(expectedSize, data.count)

        let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: expectedSize, alignment: MemoryLayout<UInt8>.size)
        let copiedCount = data.copyBytes(to: buffer)
        XCTAssertEqual(copiedCount, expectedSize)
        buffer.deallocate()
    }

    // intentionally structured so sizeof() != strideof()
    struct MyStruct {
        var time: UInt64
        let x: UInt32
        let y: UInt32
        let z: UInt32
        init() {
            time = 0
            x = 1
            y = 2
            z = 3
        }
    }

    func test_bufferSizeCalculation() {
        // Make sure that Data is correctly using strideof instead of sizeof.
        // n.b. if sizeof(MyStruct) == strideof(MyStruct), this test is not as useful as it could be

        // init
        let stuff = [MyStruct(), MyStruct(), MyStruct()]
        var data = stuff.withUnsafeBufferPointer {
            return Data(buffer: $0)
        }

        XCTAssertEqual(data.count, MemoryLayout<MyStruct>.stride * 3)


        // append
        stuff.withUnsafeBufferPointer {
            data.append($0)
        }

        XCTAssertEqual(data.count, MemoryLayout<MyStruct>.stride * 6)

        // copyBytes
        do {
            // equal size
            let underlyingBuffer = malloc(6 * MemoryLayout<MyStruct>.stride)!
            defer { free(underlyingBuffer) }

            let ptr = underlyingBuffer.bindMemory(to: MyStruct.self, capacity: 6)
            let buffer = UnsafeMutableBufferPointer<MyStruct>(start: ptr, count: 6)

            let byteCount = data.copyBytes(to: buffer)
            XCTAssertEqual(6 * MemoryLayout<MyStruct>.stride, byteCount)
        }

        do {
            // undersized
            let underlyingBuffer = malloc(3 * MemoryLayout<MyStruct>.stride)!
            defer { free(underlyingBuffer) }

            let ptr = underlyingBuffer.bindMemory(to: MyStruct.self, capacity: 3)
            let buffer = UnsafeMutableBufferPointer<MyStruct>(start: ptr, count: 3)

            let byteCount = data.copyBytes(to: buffer)
            XCTAssertEqual(3 * MemoryLayout<MyStruct>.stride, byteCount)
        }

        do {
            // oversized
            let underlyingBuffer = malloc(12 * MemoryLayout<MyStruct>.stride)!
            defer { free(underlyingBuffer) }

            let ptr = underlyingBuffer.bindMemory(to: MyStruct.self, capacity: 6)
            let buffer = UnsafeMutableBufferPointer<MyStruct>(start: ptr, count: 6)

            let byteCount = data.copyBytes(to: buffer)
            XCTAssertEqual(6 * MemoryLayout<MyStruct>.stride, byteCount)
        }
    }


    // MARK: -

    func test_repeatingValueInitialization() {
        var d = Data(repeating: 0x01, count: 3)
        let elements = repeatElement(UInt8(0x02), count: 3) // ensure we fall into the sequence case
        d.append(contentsOf: elements)

        XCTAssertEqual(d[0], 0x01)
        XCTAssertEqual(d[1], 0x01)
        XCTAssertEqual(d[2], 0x01)

        XCTAssertEqual(d[3], 0x02)
        XCTAssertEqual(d[4], 0x02)
        XCTAssertEqual(d[5], 0x02)
    }

    func test_rangeSlice() {
        let a: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7]
        let d = Data(a)
        for i in 0..<d.count {
            for j in i..<d.count {
                let slice = d[i..<j]
                XCTAssertEqual(slice.count, j - i, "where index range is \(i)..<\(j)")
                XCTAssertEqual(slice.map { $0 }, a[i..<j].map { $0 }, "where index range is \(i)..<\(j)")
                XCTAssertEqual(slice.startIndex, i, "where index range is \(i)..<\(j)")
                XCTAssertEqual(slice.endIndex, j, "where index range is \(i)..<\(j)")
                for n in slice.startIndex..<slice.endIndex {
                    let p = slice[n]
                    let q = a[n]
                    XCTAssertEqual(p, q, "where index range is \(i)..<\(j) at index \(n)")
                }
            }
        }
    }

    func test_rangeZoo() {
        let r1: Range = 0..<1
        let r2: Range = 0..<1
        let r3 = ClosedRange(0..<1)
        let r4 = ClosedRange(0..<1)

        let data = Data([8, 1, 2, 3, 4])
        let slice1: Data = data[r1]
        let slice2: Data = data[r2]
        let slice3: Data = data[r3]
        let slice4: Data = data[r4]
        XCTAssertEqual(slice1[0], 8)
        XCTAssertEqual(slice2[0], 8)
        XCTAssertEqual(slice3[0], 8)
        XCTAssertEqual(slice4[0], 8)
    }

    func test_rangeOfDataProtocol() {
        // https://bugs.swift.org/browse/SR-10689

        let base = Data([0x00, 0x01, 0x02, 0x03, 0x00, 0x01, 0x02, 0x03,
                         0x00, 0x01, 0x02, 0x03, 0x00, 0x01, 0x02, 0x03])
        let subdata = base[10..<13] // [0x02, 0x03, 0x00]
        let oneByte = base[14..<15] // [0x02]

        do { // firstRange(of:in:)
            func assertFirstRange(_ data: Data, _ fragment: Data, range: ClosedRange<Int>? = nil,
                                  expectedStartIndex: Int?,
                                  _ message: @autoclosure () -> String = "",
                                  file: StaticString = #filePath, line: UInt = #line) {
                if let index = expectedStartIndex {
                    let expectedRange: Range<Int> = index..<(index + fragment.count)
                    if let someRange = range {
                        XCTAssertEqual(data.firstRange(of: fragment, in: someRange), expectedRange, message(), file: file, line: line)
                    } else {
                        XCTAssertEqual(data.firstRange(of: fragment), expectedRange, message(), file: file, line: line)
                    }
                } else {
                    if let someRange = range {
                        XCTAssertNil(data.firstRange(of: fragment, in: someRange), message(), file: file, line: line)
                    } else {
                        XCTAssertNil(data.firstRange(of: fragment), message(), file: file, line: line)
                    }
                }
            }

            assertFirstRange(base, base, expectedStartIndex: base.startIndex)
            assertFirstRange(base, subdata, expectedStartIndex: 2)
            assertFirstRange(base, oneByte, expectedStartIndex: 2)

            assertFirstRange(subdata, base, expectedStartIndex: nil)
            assertFirstRange(subdata, subdata, expectedStartIndex: subdata.startIndex)
            assertFirstRange(subdata, oneByte, expectedStartIndex: subdata.startIndex)

            assertFirstRange(oneByte, base, expectedStartIndex: nil)
            assertFirstRange(oneByte, subdata, expectedStartIndex: nil)
            assertFirstRange(oneByte, oneByte, expectedStartIndex: oneByte.startIndex)

            assertFirstRange(base, subdata, range: 1...14, expectedStartIndex: 2)
            assertFirstRange(base, subdata, range: 6...8, expectedStartIndex: 6)
            assertFirstRange(base, subdata, range: 8...10, expectedStartIndex: nil)

            assertFirstRange(base, oneByte, range: 1...14, expectedStartIndex: 2)
            assertFirstRange(base, oneByte, range: 6...6, expectedStartIndex: 6)
            assertFirstRange(base, oneByte, range: 8...9, expectedStartIndex: nil)
        }

        do { // lastRange(of:in:)
            func assertLastRange(_ data: Data, _ fragment: Data, range: ClosedRange<Int>? = nil,
                                 expectedStartIndex: Int?,
                                 _ message: @autoclosure () -> String = "",
                                 file: StaticString = #filePath, line: UInt = #line) {
                if let index = expectedStartIndex {
                    let expectedRange: Range<Int> = index..<(index + fragment.count)
                    if let someRange = range {
                        XCTAssertEqual(data.lastRange(of: fragment, in: someRange), expectedRange, file: file, line: line)
                    } else {
                        XCTAssertEqual(data.lastRange(of: fragment), expectedRange, message(), file: file, line: line)
                    }
                } else {
                    if let someRange = range {
                        XCTAssertNil(data.lastRange(of: fragment, in: someRange), message(), file: file, line: line)
                    } else {
                        XCTAssertNil(data.lastRange(of: fragment), message(), file: file, line: line)
                    }
                }
            }

            assertLastRange(base, base, expectedStartIndex: base.startIndex)
            assertLastRange(base, subdata, expectedStartIndex: 10)
            assertLastRange(base, oneByte, expectedStartIndex: 14)

            assertLastRange(subdata, base, expectedStartIndex: nil)
            assertLastRange(subdata, subdata, expectedStartIndex: subdata.startIndex)
            assertLastRange(subdata, oneByte, expectedStartIndex: subdata.startIndex)

            assertLastRange(oneByte, base, expectedStartIndex: nil)
            assertLastRange(oneByte, subdata, expectedStartIndex: nil)
            assertLastRange(oneByte, oneByte, expectedStartIndex: oneByte.startIndex)

            assertLastRange(base, subdata, range: 1...14, expectedStartIndex: 10)
            assertLastRange(base, subdata, range: 6...8, expectedStartIndex: 6)
            assertLastRange(base, subdata, range: 8...10, expectedStartIndex: nil)

            assertLastRange(base, oneByte, range: 1...14, expectedStartIndex: 14)
            assertLastRange(base, oneByte, range: 6...6, expectedStartIndex: 6)
            assertLastRange(base, oneByte, range: 8...9, expectedStartIndex: nil)
        }
    }

    func test_sliceAppending() {
        // https://bugs.swift.org/browse/SR-4473
        var fooData = Data()
        let barData = Data([0, 1, 2, 3, 4, 5])
        let slice = barData.suffix(from: 3)
        fooData.append(slice)
        XCTAssertEqual(fooData[0], 0x03)
        XCTAssertEqual(fooData[1], 0x04)
        XCTAssertEqual(fooData[2], 0x05)
    }

    func test_sliceWithUnsafeBytes() {
        let base = Data([0, 1, 2, 3, 4, 5])
        let slice = base[2..<4]
        let segment = slice.withUnsafeUInt8Bytes { (ptr: UnsafePointer<UInt8>) -> [UInt8] in
            return [ptr.pointee, ptr.advanced(by: 1).pointee]
        }
        XCTAssertEqual(segment, [UInt8(2), UInt8(3)])
    }

    func test_sliceIteration() {
        let base = Data([0, 1, 2, 3, 4, 5])
        let slice = base[2..<4]
        var found = [UInt8]()
        for byte in slice {
            found.append(byte)
        }
        XCTAssertEqual(found[0], 2)
        XCTAssertEqual(found[1], 3)
    }

    func test_sliceIndexing() {
        let d = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
        let slice = d[5..<10]
        XCTAssertEqual(slice[5], d[5])
    }

    func test_sliceEquality() {
        let d = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
        let slice = d[5..<7]
        let expected = Data([5, 6])
        XCTAssertEqual(expected, slice)
    }

    func test_sliceEquality2() {
        let d = Data([5, 6, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
        let slice1 = d[0..<2]
        let slice2 = d[5..<7]
        XCTAssertEqual(slice1, slice2)
    }

    func test_map() {
        let d1 = Data([81, 0, 0, 0, 14])
        let d2 = d1[1...4]
        XCTAssertEqual(4, d2.count)
        let expected: [UInt8] = [0, 0, 0, 14]
        let actual = d2.map { $0 }
        XCTAssertEqual(expected, actual)
    }

    func test_dropFirst() {
        let data = Data([0, 1, 2, 3, 4, 5])
        let sliced = data.dropFirst()
        XCTAssertEqual(data.count - 1, sliced.count)
        XCTAssertEqual(UInt8(1), sliced[1])
        XCTAssertEqual(UInt8(2), sliced[2])
        XCTAssertEqual(UInt8(3), sliced[3])
        XCTAssertEqual(UInt8(4), sliced[4])
        XCTAssertEqual(UInt8(5), sliced[5])
    }

    func test_dropFirst2() {
        let data = Data([0, 1, 2, 3, 4, 5])
        let sliced = data.dropFirst(2)
        XCTAssertEqual(data.count - 2, sliced.count)
        XCTAssertEqual(UInt8(2), sliced[2])
        XCTAssertEqual(UInt8(3), sliced[3])
        XCTAssertEqual(UInt8(4), sliced[4])
        XCTAssertEqual(UInt8(5), sliced[5])
    }

    func test_copyBytes1() {
        var array: [UInt8] = [0, 1, 2, 3]
        let data = Data(array)

        array.withUnsafeMutableBufferPointer {
            data[1..<3].copyBytes(to: $0.baseAddress!, from: 1..<3)
        }
        XCTAssertEqual([UInt8(1), UInt8(2), UInt8(2), UInt8(3)], array)
    }

    func test_copyBytes2() {
        let array: [UInt8] = [0, 1, 2, 3]
        let data = Data(array)

        let expectedSlice = array[1..<3]

        let start = data.index(after: data.startIndex)
        let end = data.index(before: data.endIndex)
        let slice = data[start..<end]

        XCTAssertEqual(expectedSlice[expectedSlice.startIndex], slice[slice.startIndex])
    }

    func test_sliceOfSliceViaRangeExpression() {
        let data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])

        let slice = data[2..<7]

        let sliceOfSlice1 = slice[..<(slice.startIndex + 2)] // this triggers the range expression
        let sliceOfSlice2 = slice[(slice.startIndex + 2)...] // also triggers range expression

        XCTAssertEqual(Data([2, 3]), sliceOfSlice1)
        XCTAssertEqual(Data([4, 5, 6]), sliceOfSlice2)
    }

    func test_appendingSlices() {
        let d1 = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        let slice = d1[1..<2]
        var d2 = Data()
        d2.append(slice)
        XCTAssertEqual(Data([1]), slice)
    }

    // This test uses `repeatElement` to produce a sequence -- the produced sequence reports its actual count as its `.underestimatedCount`.
    func test_appendingNonContiguousSequence_exactCount() {
        var d = Data()

        // d should go from .empty representation to .inline.
        // Appending a small enough sequence to fit in .inline should actually be copied.
        d.append(contentsOf: 0x00...0x01)
        XCTAssertEqual(Data([0x00, 0x01]), d)

        // Appending another small sequence should similarly still work.
        d.append(contentsOf: 0x02...0x02)
        XCTAssertEqual(Data([0x00, 0x01, 0x02]), d)

        // If we append a sequence of elements larger than a single InlineData, the internal append here should buffer.
        // We want to make sure that buffering in this way does not accidentally drop trailing elements on the floor.
        d.append(contentsOf: 0x03...0x2F)
        XCTAssertEqual(Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
                          0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
                          0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
                          0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F,
                          0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
                          0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F]), d)
    }

    // This test is like test_appendingNonContiguousSequence_exactCount but uses a sequence which reports 0 for its `.underestimatedCount`.
    // This attempts to hit the worst-case scenario of `Data.append<S>(_:)` -- a discontiguous sequence of unknown length.
    func test_appendingNonContiguousSequence_underestimatedCount() {
        var d = Data()

        // d should go from .empty representation to .inline.
        // Appending a small enough sequence to fit in .inline should actually be copied.
        d.append(contentsOf: (0x00...0x01).makeIterator()) // `.makeIterator()` produces a sequence whose `.underestimatedCount` is 0.
        XCTAssertEqual(Data([0x00, 0x01]), d)

        // Appending another small sequence should similarly still work.
        d.append(contentsOf: (0x02...0x02).makeIterator()) // `.makeIterator()` produces a sequence whose `.underestimatedCount` is 0.
        XCTAssertEqual(Data([0x00, 0x01, 0x02]), d)

        // If we append a sequence of elements larger than a single InlineData, the internal append here should buffer.
        // We want to make sure that buffering in this way does not accidentally drop trailing elements on the floor.
        d.append(contentsOf: (0x03...0x2F).makeIterator()) // `.makeIterator()` produces a sequence whose `.underestimatedCount` is 0.
        XCTAssertEqual(Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
                          0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
                          0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
                          0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F,
                          0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
                          0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F]), d)
    }

    func test_sequenceInitializers() {
        let seq = repeatElement(UInt8(0x02), count: 3) // ensure we fall into the sequence case

        let dataFromSeq = Data(seq)
        XCTAssertEqual(3, dataFromSeq.count)
        XCTAssertEqual(UInt8(0x02), dataFromSeq[0])
        XCTAssertEqual(UInt8(0x02), dataFromSeq[1])
        XCTAssertEqual(UInt8(0x02), dataFromSeq[2])

        let array: [UInt8] = [0, 1, 2, 3, 4, 5, 6]

        let dataFromArray = Data(array)
        XCTAssertEqual(array.count, dataFromArray.count)
        XCTAssertEqual(array[0], dataFromArray[0])
        XCTAssertEqual(array[1], dataFromArray[1])
        XCTAssertEqual(array[2], dataFromArray[2])
        XCTAssertEqual(array[3], dataFromArray[3])

        let slice = array[1..<4]

        let dataFromSlice = Data(slice)
        XCTAssertEqual(slice.count, dataFromSlice.count)
        XCTAssertEqual(slice.first, dataFromSlice.first)
        XCTAssertEqual(slice.last, dataFromSlice.last)

        let data = Data([1, 2, 3, 4, 5, 6, 7, 8, 9])

        let dataFromData = Data(data)
        XCTAssertEqual(data, dataFromData)

        let sliceOfData = data[1..<3]

        let dataFromSliceOfData = Data(sliceOfData)
        XCTAssertEqual(sliceOfData, dataFromSliceOfData)
    }

    func test_reversedDataInit() {
        let data = Data([1, 2, 3, 4, 5, 6, 7, 8, 9])
        let reversedData = Data(data.reversed())
        let expected = Data([9, 8, 7, 6, 5, 4, 3, 2, 1])
        XCTAssertEqual(expected, reversedData)
    }

    func test_validateMutation_withUnsafeMutableBytes() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        data.withUnsafeMutableUInt8Bytes { (ptr: UnsafeMutablePointer<UInt8>) in
            ptr.advanced(by: 5).pointee = 0xFF
        }
        XCTAssertEqual(data, Data([0, 1, 2, 3, 4, 0xFF, 6, 7, 8, 9]))
    }

    func test_validateMutation_appendBytes() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        data.append("hello", count: 5)
        XCTAssertEqual(data[data.startIndex.advanced(by: 5)], 0x5)
    }

    func test_validateMutation_appendData() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        let other = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        data.append(other)
        XCTAssertEqual(data[data.startIndex.advanced(by: 9)], 9)
        XCTAssertEqual(data[data.startIndex.advanced(by: 10)], 0)
    }

    func test_validateMutation_appendBuffer() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        let bytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        bytes.withUnsafeBufferPointer { data.append($0) }
        XCTAssertEqual(data[data.startIndex.advanced(by: 9)], 9)
        XCTAssertEqual(data[data.startIndex.advanced(by: 10)], 0)
    }

    func test_validateMutation_appendSequence() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        let seq = repeatElement(UInt8(1), count: 10)
        data.append(contentsOf: seq)
        XCTAssertEqual(data[data.startIndex.advanced(by: 9)], 9)
        XCTAssertEqual(data[data.startIndex.advanced(by: 10)], 1)
    }

    func test_validateMutation_appendContentsOf() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        let bytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        data.append(contentsOf: bytes)
        XCTAssertEqual(data[data.startIndex.advanced(by: 9)], 9)
        XCTAssertEqual(data[data.startIndex.advanced(by: 10)], 0)
    }

    func test_validateMutation_resetBytes() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        data.resetBytes(in: 5..<8)
        XCTAssertEqual(data, Data([0, 1, 2, 3, 4, 0, 0, 0, 8, 9]))
    }

    func test_validateMutation_replaceSubrange() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        let range: Range<Data.Index> = data.startIndex.advanced(by: 4)..<data.startIndex.advanced(by: 9)
        let replacement = Data([0xFF, 0xFF])
        data.replaceSubrange(range, with: replacement)
        XCTAssertEqual(data, Data([0, 1, 2, 3, 0xFF, 0xFF, 9]))
    }

    func test_validateMutation_replaceSubrangeRange() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        let range: Range<Data.Index> = data.startIndex.advanced(by: 4)..<data.startIndex.advanced(by: 9)
        let replacement = Data([0xFF, 0xFF])
        data.replaceSubrange(range, with: replacement)
        XCTAssertEqual(data, Data([0, 1, 2, 3, 0xFF, 0xFF, 9]))
    }

    func test_validateMutation_replaceSubrangeWithBuffer() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        let range: Range<Data.Index> = data.startIndex.advanced(by: 4)..<data.startIndex.advanced(by: 9)
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBufferPointer {
            data.replaceSubrange(range, with: $0)
        }
        XCTAssertEqual(data, Data([0, 1, 2, 3, 0xFF, 0xFF, 9]))
    }

    func test_validateMutation_replaceSubrangeWithCollection() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        let range: Range<Data.Index> = data.startIndex.advanced(by: 4)..<data.startIndex.advanced(by: 9)
        let bytes: [UInt8] = [0xFF, 0xFF]
        data.replaceSubrange(range, with: bytes)
        XCTAssertEqual(data, Data([0, 1, 2, 3, 0xFF, 0xFF, 9]))
    }

    func test_validateMutation_replaceSubrangeWithBytes() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        let range: Range<Data.Index> = data.startIndex.advanced(by: 4)..<data.startIndex.advanced(by: 9)
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBytes {
            data.replaceSubrange(range, with: $0.baseAddress!, count: 2)
        }
        XCTAssertEqual(data, Data([0, 1, 2, 3, 0xFF, 0xFF, 9]))
    }

    func test_validateMutation_setCount_larger() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        data.count = data.count + 1
        XCTAssertEqual(data, Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0]))
        XCTAssertEqual(data.count, 11)
    }

    func test_validateMutation_setCount_smaller() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        data.count = data.count - 1
        XCTAssertEqual(data, Data([0, 1, 2, 3, 4, 5, 6, 7, 8]))
        XCTAssertEqual(data.count, 9)
    }

    func test_validateMutation_setCount_zero() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        data.count = 0
        XCTAssertEqual(data, Data())
        XCTAssertEqual(data.count, 0)
    }

    func test_validateMutation_slice_withUnsafeMutableBytes() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        data.withUnsafeMutableUInt8Bytes { (ptr: UnsafeMutablePointer<UInt8>) in
            ptr.advanced(by: 1).pointee = 0xFF
        }
        XCTAssertEqual(data, Data([4, 0xFF, 6, 7, 8]))
    }

    func test_validateMutation_slice_appendBytes() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBufferPointer { data.append($0.baseAddress!, count: $0.count) }
        XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0xFF, 0xFF]))
    }

    func test_validateMutation_slice_appendData() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        let other = Data([0xFF, 0xFF])
        data.append(other)
        XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0xFF, 0xFF]))
    }

    func test_validateMutation_slice_appendBuffer() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBufferPointer { data.append($0) }
        XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0xFF, 0xFF]))
    }

    func test_validateMutation_slice_appendSequence() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        let seq = repeatElement(UInt8(0xFF), count: 2)
        data.append(contentsOf: seq)
        XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0xFF, 0xFF]))
    }

    func test_validateMutation_slice_appendContentsOf() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        let bytes: [UInt8] = [0xFF, 0xFF]
        data.append(contentsOf: bytes)
        XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0xFF, 0xFF]))
    }

    func test_validateMutation_slice_resetBytes() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        data.resetBytes(in: 5..<8)
        XCTAssertEqual(data, Data([4, 0, 0, 0, 8]))
    }

    func test_validateMutation_slice_replaceSubrange() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        let replacement = Data([0xFF, 0xFF])
        data.replaceSubrange(range, with: replacement)
        XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
    }

    func test_validateMutation_slice_replaceSubrangeRange() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        let replacement = Data([0xFF, 0xFF])
        data.replaceSubrange(range, with: replacement)
        XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
    }

    func test_validateMutation_slice_replaceSubrangeWithBuffer() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBufferPointer {
            data.replaceSubrange(range, with: $0)
        }
        XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
    }

    func test_validateMutation_slice_replaceSubrangeWithCollection() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        let bytes: [UInt8] = [0xFF, 0xFF]
        data.replaceSubrange(range, with: bytes)
        XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
    }

    func test_validateMutation_slice_replaceSubrangeWithBytes() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
        let bytes: [UInt8] = [0xFF, 0xFF]
        bytes.withUnsafeBytes {
            data.replaceSubrange(range, with: $0.baseAddress!, count: 2)
        }
        XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
    }

    func test_validateMutation_slice_setCount_larger() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        data.count = data.count + 1
        XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0]))
        XCTAssertEqual(data.count, 6)
    }

    func test_validateMutation_slice_setCount_smaller() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        data.count = data.count - 1
        XCTAssertEqual(data, Data([4, 5, 6, 7]))
        XCTAssertEqual(data.count, 4)
    }

    func test_validateMutation_slice_setCount_zero() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        data.count = 0
        XCTAssertEqual(data, Data())
        XCTAssertEqual(data.count, 0)
    }

    func test_validateMutation_cow_withUnsafeMutableBytes() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        holdReference(data) {
            data.withUnsafeMutableUInt8Bytes { (ptr: UnsafeMutablePointer<UInt8>) in
                ptr.advanced(by: 5).pointee = 0xFF
            }
            XCTAssertEqual(data, Data([0, 1, 2, 3, 4, 0xFF, 6, 7, 8, 9]))
        }
    }

    func test_validateMutation_cow_appendBytes() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        holdReference(data) {
            data.append("hello", count: 5)
            XCTAssertEqual(data[data.startIndex.advanced(by: 9)], 0x9)
            XCTAssertEqual(data[data.startIndex.advanced(by: 10)], 0x68)
        }
    }

    func test_validateMutation_cow_appendData() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        holdReference(data) {
            let other = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
            data.append(other)
            XCTAssertEqual(data[data.startIndex.advanced(by: 9)], 9)
            XCTAssertEqual(data[data.startIndex.advanced(by: 10)], 0)
        }
    }

    func test_validateMutation_cow_appendBuffer() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        holdReference(data) {
            let bytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
            bytes.withUnsafeBufferPointer { data.append($0) }
            XCTAssertEqual(data[data.startIndex.advanced(by: 9)], 9)
            XCTAssertEqual(data[data.startIndex.advanced(by: 10)], 0)
        }
    }

    func test_validateMutation_cow_appendSequence() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        holdReference(data) {
            let seq = repeatElement(UInt8(1), count: 10)
            data.append(contentsOf: seq)
            XCTAssertEqual(data[data.startIndex.advanced(by: 9)], 9)
            XCTAssertEqual(data[data.startIndex.advanced(by: 10)], 1)
        }
    }

    func test_validateMutation_cow_appendContentsOf() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        holdReference(data) {
            let bytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
            data.append(contentsOf: bytes)
            XCTAssertEqual(data[data.startIndex.advanced(by: 9)], 9)
            XCTAssertEqual(data[data.startIndex.advanced(by: 10)], 0)
        }
    }

    func test_validateMutation_cow_resetBytes() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        holdReference(data) {
            data.resetBytes(in: 5..<8)
            XCTAssertEqual(data, Data([0, 1, 2, 3, 4, 0, 0, 0, 8, 9]))
        }
    }

    func test_validateMutation_cow_replaceSubrange() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 4)..<data.startIndex.advanced(by: 9)
            let replacement = Data([0xFF, 0xFF])
            data.replaceSubrange(range, with: replacement)
            XCTAssertEqual(data, Data([0, 1, 2, 3, 0xFF, 0xFF, 9]))
        }
    }

    func test_validateMutation_cow_replaceSubrangeRange() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 4)..<data.startIndex.advanced(by: 9)
            let replacement = Data([0xFF, 0xFF])
            data.replaceSubrange(range, with: replacement)
            XCTAssertEqual(data, Data([0, 1, 2, 3, 0xFF, 0xFF, 9]))
        }
    }

    func test_validateMutation_cow_replaceSubrangeWithBuffer() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 4)..<data.startIndex.advanced(by: 9)
            let bytes: [UInt8] = [0xFF, 0xFF]
            bytes.withUnsafeBufferPointer {
                data.replaceSubrange(range, with: $0)
            }
            XCTAssertEqual(data, Data([0, 1, 2, 3, 0xFF, 0xFF, 9]))
        }
    }

    func test_validateMutation_cow_replaceSubrangeWithCollection() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 4)..<data.startIndex.advanced(by: 9)
            let bytes: [UInt8] = [0xFF, 0xFF]
            data.replaceSubrange(range, with: bytes)
            XCTAssertEqual(data, Data([0, 1, 2, 3, 0xFF, 0xFF, 9]))
        }
    }

    func test_validateMutation_cow_replaceSubrangeWithBytes() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 4)..<data.startIndex.advanced(by: 9)
            let bytes: [UInt8] = [0xFF, 0xFF]
            bytes.withUnsafeBytes {
                data.replaceSubrange(range, with: $0.baseAddress!, count: 2)
            }
            XCTAssertEqual(data, Data([0, 1, 2, 3, 0xFF, 0xFF, 9]))
        }
    }

    func test_validateMutation_cow_setCount_larger() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        holdReference(data) {
            data.count = data.count + 1
            XCTAssertEqual(data, Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0]))
            XCTAssertEqual(data.count, 11)
        }
    }

    func test_validateMutation_cow_setCount_smaller() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        holdReference(data) {
            data.count = data.count - 1
            XCTAssertEqual(data, Data([0, 1, 2, 3, 4, 5, 6, 7, 8]))
            XCTAssertEqual(data.count, 9)
        }
    }

    func test_validateMutation_cow_setCount_zero() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        holdReference(data) {
            data.count = 0
            XCTAssertEqual(data, Data())
            XCTAssertEqual(data.count, 0)
        }
    }

    func test_validateMutation_slice_cow_withUnsafeMutableBytes() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        holdReference(data) {
            data.withUnsafeMutableUInt8Bytes { (ptr: UnsafeMutablePointer<UInt8>) in
                ptr.advanced(by: 1).pointee = 0xFF
            }
            XCTAssertEqual(data, Data([4, 0xFF, 6, 7, 8]))
        }
    }

    func test_validateMutation_slice_cow_appendBytes() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        holdReference(data) {
            data.append("hello", count: 5)
            XCTAssertEqual(data[data.startIndex.advanced(by: 4)], 0x8)
            XCTAssertEqual(data[data.startIndex.advanced(by: 5)], 0x68)
        }
    }

    func test_validateMutation_slice_cow_appendData() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        holdReference(data) {
            let other = Data([0xFF, 0xFF])
            data.append(other)
            XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0xFF, 0xFF]))
        }
    }

    func test_validateMutation_slice_cow_appendBuffer() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        holdReference(data) {
            let bytes: [UInt8] = [0xFF, 0xFF]
            bytes.withUnsafeBufferPointer { data.append($0) }
            XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0xFF, 0xFF]))
        }
    }

    func test_validateMutation_slice_cow_appendSequence() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        holdReference(data) {
            let seq = repeatElement(UInt8(0xFF), count: 2)
            data.append(contentsOf: seq)
            XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0xFF, 0xFF]))
        }
    }

    func test_validateMutation_slice_cow_appendContentsOf() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        holdReference(data) {
            let bytes: [UInt8] = [0xFF, 0xFF]
            data.append(contentsOf: bytes)
            XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0xFF, 0xFF]))
        }
    }

    func test_validateMutation_slice_cow_resetBytes() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        holdReference(data) {
            data.resetBytes(in: 5..<8)
            XCTAssertEqual(data, Data([4, 0, 0, 0, 8]))
        }
    }

    func test_validateMutation_slice_cow_replaceSubrange() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            let replacement = Data([0xFF, 0xFF])
            data.replaceSubrange(range, with: replacement)
            XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
        }
    }

    func test_validateMutation_slice_cow_replaceSubrangeRange() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            let replacement = Data([0xFF, 0xFF])
            data.replaceSubrange(range, with: replacement)
            XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
        }
    }

    func test_validateMutation_slice_cow_replaceSubrangeWithBuffer() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            let bytes: [UInt8] = [0xFF, 0xFF]
            bytes.withUnsafeBufferPointer {
                data.replaceSubrange(range, with: $0)
            }
            XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
        }
    }

    func test_validateMutation_slice_cow_replaceSubrangeWithCollection() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            let bytes: [UInt8] = [0xFF, 0xFF]
            data.replaceSubrange(range, with: bytes)
            XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
        }
    }

    func test_validateMutation_slice_cow_replaceSubrangeWithBytes() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        holdReference(data) {
            let range: Range<Data.Index> = data.startIndex.advanced(by: 1)..<data.endIndex.advanced(by: -1)
            let bytes: [UInt8] = [0xFF, 0xFF]
            bytes.withUnsafeBytes {
                data.replaceSubrange(range, with: $0.baseAddress!, count: 2)
            }
            XCTAssertEqual(data, Data([4, 0xFF, 0xFF, 8]))
        }
    }

    func test_validateMutation_slice_cow_setCount_larger() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        holdReference(data) {
            data.count = data.count + 1
            XCTAssertEqual(data, Data([4, 5, 6, 7, 8, 0]))
            XCTAssertEqual(data.count, 6)
        }
    }

    func test_validateMutation_slice_cow_setCount_smaller() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        holdReference(data) {
            data.count = data.count - 1
            XCTAssertEqual(data, Data([4, 5, 6, 7]))
            XCTAssertEqual(data.count, 4)
        }
    }

    func test_validateMutation_slice_cow_setCount_zero() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        holdReference(data) {
            data.count = 0
            XCTAssertEqual(data, Data())
            XCTAssertEqual(data.count, 0)
        }
    }

    func test_sliceHash() {
        let base1 = Data([0, 0xFF, 0xFF, 0])
        let base2 = Data([0, 0xFF, 0xFF, 0])
        let base3 = Data([0xFF, 0xFF, 0xFF, 0])
        let sliceEmulation = Data([0xFF, 0xFF])
        XCTAssertEqual(base1.hashValue, base2.hashValue)
        let slice1 = base1[base1.startIndex.advanced(by: 1)..<base1.endIndex.advanced(by: -1)]
        let slice2 = base2[base2.startIndex.advanced(by: 1)..<base2.endIndex.advanced(by: -1)]
        let slice3 = base3[base3.startIndex.advanced(by: 1)..<base3.endIndex.advanced(by: -1)]
        XCTAssertEqual(slice1.hashValue, sliceEmulation.hashValue)
        XCTAssertEqual(slice1.hashValue, slice2.hashValue)
        XCTAssertEqual(slice2.hashValue, slice3.hashValue)
    }

    func test_slice_resize_growth() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<9]
        data.resetBytes(in: data.endIndex.advanced(by: -1)..<data.endIndex.advanced(by: 1))
        XCTAssertEqual(data, Data([4, 5, 6, 7, 0, 0]))
    }

    func test_validateMutation_slice_withUnsafeMutableBytes_lengthLessThanLowerBound() {
        var data = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])[4..<6]
        data.withUnsafeMutableUInt8Bytes { (ptr: UnsafeMutablePointer<UInt8>) in
            ptr.advanced(by: 1).pointee = 0xFF
        }
        XCTAssertEqual(data, Data([4, 0xFF]))
    }

    func test_increaseCount() {
        let initials: [Range<UInt8>] = [
            0..<0,
            0..<2,
            0..<4,
            0..<8,
            0..<16,
            0..<32,
            0..<64
        ]
        let diffs = [0, 1, 2, 4, 8, 16, 32]
        for initial in initials {
            for diff in diffs {
                var data = Data(initial)
                data.count += diff
                XCTAssertEqual(
                    Data(Array(initial) + Array(repeating: 0, count: diff)),
                    data)
            }
        }
    }

    func test_decreaseCount() {
        let initials: [Range<UInt8>] = [
            0..<0,
            0..<2,
            0..<4,
            0..<8,
            0..<16,
            0..<32,
            0..<64
        ]
        let diffs = [0, 1, 2, 4, 8, 16, 32]
        for initial in initials {
            for diff in diffs {
                guard initial.count >= diff else { continue }
                var data = Data(initial)
                data.count -= diff
                XCTAssertEqual(
                    Data(initial.dropLast(diff)),
                    data)
            }
        }
    }

    func test_decrease_increase_count() {
        var data = Data(Array(repeating: 0, count: 8) + [42])
        data.count -= 1
        XCTAssertEqual(Data(Array(repeating: 0, count: 8)), data)
        data.count += 1
        XCTAssertEqual(Data(Array(repeating: 0, count: 9)), data)

        data = Data(Array(repeating: 0, count: 64) + [42])
        data.count -= 1
        XCTAssertEqual(Data(Array(repeating: 0, count: 64)), data)
        data.count += 1
        XCTAssertEqual(Data(Array(repeating: 0, count: 65)), data)
    }

    // This is a (potentially invalid) sequence that produces a configurable number of 42s and has a freely customizable `underestimatedCount`.
    struct TestSequence: Sequence {
        typealias Element = UInt8
        struct Iterator: IteratorProtocol {
            var _remaining: Int
            init(_ count: Int) {
                _remaining = count
            }
            mutating func next() -> UInt8? {
                guard _remaining > 0 else { return nil }
                _remaining -= 1
                return 42
            }
        }
        let underestimatedCount: Int
        let count: Int

        func makeIterator() -> Iterator {
            return Iterator(count)
        }
    }

    func test_init_TestSequence() {
        // Underestimated count
        do {
            let d = Data(TestSequence(underestimatedCount: 0, count: 10))
            XCTAssertEqual(10, d.count)
            XCTAssertEqual(Array(repeating: 42 as UInt8, count: 10), Array(d))
        }

        // Very underestimated count (to exercise realloc path)
        do {
            let d = Data(TestSequence(underestimatedCount: 0, count: 1000))
            XCTAssertEqual(1000, d.count)
            XCTAssertEqual(Array(repeating: 42 as UInt8, count: 1000), Array(d))
        }

        // Exact count
        do {
            let d = Data(TestSequence(underestimatedCount: 10, count: 10))
            XCTAssertEqual(10, d.count)
            XCTAssertEqual(Array(repeating: 42 as UInt8, count: 10), Array(d))
        }

        // Overestimated count. This is an illegal case, so trapping would be fine.
        // However, for compatibility with the implementation in Swift 5, Data
        // handles this case by simply truncating itself to the actual size.
        do {
            let d = Data(TestSequence(underestimatedCount: 20, count: 10))
            XCTAssertEqual(10, d.count)
            XCTAssertEqual(Array(repeating: 42 as UInt8, count: 10), Array(d))
        }
    }

    func test_append_TestSequence() {
        let base = Data(Array(repeating: 23 as UInt8, count: 10))

        // Underestimated count
        do {
            var d = base
            d.append(contentsOf: TestSequence(underestimatedCount: 0, count: 10))
            XCTAssertEqual(20, d.count)
            XCTAssertEqual(Array(base) + Array(repeating: 42 as UInt8, count: 10),
                           Array(d))
        }

        // Very underestimated count (to exercise realloc path)
        do {
            var d = base
            d.append(contentsOf: TestSequence(underestimatedCount: 0, count: 1000))
            XCTAssertEqual(1010, d.count)
            XCTAssertEqual(Array(base) + Array(repeating: 42 as UInt8, count: 1000), Array(d))
        }

        // Exact count
        do {
            var d = base
            d.append(contentsOf: TestSequence(underestimatedCount: 10, count: 10))
            XCTAssertEqual(20, d.count)
            XCTAssertEqual(Array(base) + Array(repeating: 42 as UInt8, count: 10), Array(d))
        }

        // Overestimated count. This is an illegal case, so trapping would be fine.
        // However, for compatibility with the implementation in Swift 5, Data
        // handles this case by simply truncating itself to the actual size.
        do {
            var d = base
            d.append(contentsOf: TestSequence(underestimatedCount: 20, count: 10))
            XCTAssertEqual(20, d.count)
            XCTAssertEqual(Array(base) + Array(repeating: 42 as UInt8, count: 10), Array(d))
        }
    }

    func testAdvancedBy() {
        let source: Data = Data([1, 42, 64, 8])
        XCTAssertEqual(source.advanced(by: 0), Data([1, 42, 64, 8]))
        XCTAssertEqual(source.advanced(by: 2), Data([64, 8]))
        XCTAssertEqual(source.advanced(by: 4), Data())
        // Make sure .advanced creates a new data
        XCTAssert(source.advanced(by: 3).startIndex == 0)
        // Make sure .advanced works on Data whose `startIndex` isn't 0
        let offsetData: Data = Data([1, 42, 64, 8, 90, 80])[1..<5]
        XCTAssertEqual(offsetData.advanced(by: 0), Data([42, 64, 8, 90]))
        XCTAssertEqual(offsetData.advanced(by: 2), Data([8, 90]))
        XCTAssertEqual(offsetData.advanced(by: 4), Data())
        XCTAssert(offsetData.advanced(by: 3).startIndex == 0)

        // FIXME: XCTest doesn't support crash tests yet rdar://20195010&22387653
        // source.advanced(by: -1)
        // source.advanced(by: 5)
    }


    #if false // FIXME: XCTest doesn't support crash tests yet rdar://20195010&22387653
    func test_bounding_failure_subdata() {
        let data = "Hello World".data(using: .utf8)!
        expectCrashLater()
        let c = data.subdata(in: 5..<200)
    }
    #endif

    #if false // FIXME: XCTest doesn't support crash tests yet rdar://20195010&22387653
    func test_bounding_failure_replace() {
        var data = "Hello World".data(using: .utf8)!
        expectCrashLater()
        data.replaceSubrange(5..<200, with: Data())
    }
    #endif

    #if false // FIXME: XCTest doesn't support crash tests yet rdar://20195010&22387653
    func test_bounding_failure_replace2() {
        var data = "a".data(using: .utf8)!
        var bytes : [UInt8] = [1, 2, 3]
        expectCrashLater()
        bytes.withUnsafeBufferPointer {
            // lowerBound ok, upperBound after end of data
            data.replaceSubrange(0..<2, with: $0)
        }
    }
    #endif

    #if false // FIXME: XCTest doesn't support crash tests yet rdar://20195010&22387653
    func test_bounding_failure_replace3() {
        var data = "a".data(using: .utf8)!
        var bytes : [UInt8] = [1, 2, 3]
        expectCrashLater()
        bytes.withUnsafeBufferPointer {
            // lowerBound is > length
            data.replaceSubrange(2..<4, with: $0)
        }
    }
    #endif

    #if false // FIXME: XCTest doesn't support crash tests yet rdar://20195010&22387653
    func test_bounding_failure_replace4() {
        var data = "a".data(using: .utf8)!
        var bytes : [UInt8] = [1, 2, 3]
        expectCrashLater()
        // lowerBound is > length
        data.replaceSubrange(2..<4, with: bytes)
    }
    #endif

    #if false // FIXME: XCTest doesn't support crash tests yet rdar://20195010&22387653
    func test_bounding_failure_reset_range() {
        var data = "Hello World".data(using: .utf8)!
        expectCrashLater()
        data.resetBytes(in: 100..<200)
    }
    #endif

    #if false // FIXME: XCTest doesn't support crash tests yet rdar://20195010&22387653
    func test_bounding_failure_append_bad_length() {
        var data = "Hello World".data(using: .utf8)!
        expectCrashLater()
        data.append("hello", count: -2)
    }
    #endif

    #if false // FIXME: XCTest doesn't support crash tests yet rdar://20195010&22387653
    func test_bounding_failure_append_absurd_length() {
        var data = "Hello World".data(using: .utf8)!
        expectCrashLater()
        data.append("hello", count: Int.min)
    }
    #endif

    #if false // FIXME: XCTest doesn't support crash tests yet rdar://20195010&22387653
    func test_bounding_failure_subscript() {
        var data = "Hello World".data(using: .utf8)!
        expectCrashLater()
        data[100] = 4
    }
    #endif
}

#if FOUNDATION_FRAMEWORK // FIXME: Re-enable test after String.data(using:) is implemented
extension DataTests {
    func test_splittingHttp() {
        func split(_ data: Data, on delimiter: String) -> [Data] {
            let dataDelimiter = delimiter.data(using: .utf8)!
            var found = [Data]()
            let start = data.startIndex
            let end = data.endIndex.advanced(by: -dataDelimiter.count)
            guard end >= start else { return [data] }
            var index = start
            var previousIndex = index
            while index < end {
                let slice = data[index..<index.advanced(by: dataDelimiter.count)]

                if slice == dataDelimiter {
                    found.append(data[previousIndex..<index])
                    previousIndex = index + dataDelimiter.count
                }

                index = index.advanced(by: 1)
            }
            if index < data.endIndex { found.append(data[index..<index]) }
            return found
        }
        let data = "GET /index.html HTTP/1.1\r\nHost: www.example.com\r\n\r\n".data(using: .ascii)!
        let fields = split(data, on: "\r\n")
        let splitFields = fields.map { String(data:$0, encoding: .utf8)! }
        XCTAssertEqual([
            "GET /index.html HTTP/1.1",
            "Host: www.example.com",
            ""
        ], splitFields)
    }

    func test_doubleDeallocation() {
        let data = "12345679".data(using: .utf8)!
        let len = data.withUnsafeUInt8Bytes { (bytes: UnsafePointer<UInt8>) -> Int in
            let slice = Data(bytesNoCopy: UnsafeMutablePointer(mutating: bytes), count: 1, deallocator: .none)
            return slice.count
        }
        XCTAssertEqual(len, 1)
    }

    func test_discontiguousEnumerateBytes() {
        let dataToEncode = "Hello World".data(using: .utf8)!

        let subdata1 = dataToEncode.withUnsafeBytes { bytes in
            return DispatchData(bytes: bytes)
        }
        let subdata2 = dataToEncode.withUnsafeBytes { bytes in
            return DispatchData(bytes: bytes)
        }
        var data = subdata1
        data.append(subdata2)

        var numChunks = 0
        var offsets = [Int]()
        data.enumerateBytes() { buffer, offset, stop in
            numChunks += 1
            offsets.append(offset)
        }

        XCTAssertEqual(2, numChunks, "composing two dispatch_data should enumerate as structural data as 2 chunks")
        XCTAssertEqual(0, offsets[0], "composing two dispatch_data should enumerate as structural data with the first offset as the location of the region")
        XCTAssertEqual(dataToEncode.count, offsets[1], "composing two dispatch_data should enumerate as structural data with the first offset as the location of the region")
    }

    func test_rangeOfSlice() {
        let data = "FooBar".data(using: .ascii)!
        let slice = data[3...] // Bar

        let range = slice.range(of: "a".data(using: .ascii)!)
        XCTAssertEqual(range, 4..<5 as Range<Data.Index>)
    }
}
#endif

// MARK: - Base64 Encode/Decode Tests

extension DataTests {

    func test_base64Encode_emptyData() {
        XCTAssertEqual(Data().base64EncodedString(), "")
        XCTAssertEqual(Data().base64EncodedData(), Data())
    }

    func test_base64Encode_arrayOfNulls() {
        let input = Data(repeating: 0, count: 10)
        XCTAssertEqual(input.base64EncodedString(), "AAAAAAAAAAAAAA==")
        XCTAssertEqual(input.base64EncodedData(), Data("AAAAAAAAAAAAAA==".utf8))
    }

    func test_base64Encode_differentPaddingNeeds() {
        XCTAssertEqual(Data([1, 2, 3, 4]).base64EncodedString(), "AQIDBA==")
        XCTAssertEqual(Data([1, 2, 3, 4, 5]).base64EncodedString(), "AQIDBAU=")
        XCTAssertEqual(Data([1, 2, 3, 4, 5, 6]).base64EncodedString(), "AQIDBAUG")

        XCTAssertEqual(Data([1, 2, 3, 4]).base64EncodedString(options: [.lineLength64Characters]), "AQIDBA==")
        XCTAssertEqual(Data([1, 2, 3, 4, 5]).base64EncodedString(options: [.lineLength64Characters]), "AQIDBAU=")
        XCTAssertEqual(Data([1, 2, 3, 4, 5, 6]).base64EncodedString(options: [.lineLength64Characters]), "AQIDBAUG")
    }

    func test_base64Encode_addingLinebreaks() {
        let input = """
            Lorem ipsum dolor sit amet, consectetur adipiscing elit. Ut at tincidunt arcu. Suspendisse nec sodales erat, sit amet imperdiet ipsum. Etiam sed ornare felis.
            """

        // using .endLineWithLineFeed
        XCTAssertEqual(
            Data(input.utf8).base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed]),
            """
            TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQsIGNvbnNlY3RldHVyIGFkaXBpc2Np\n\
            bmcgZWxpdC4gVXQgYXQgdGluY2lkdW50IGFyY3UuIFN1c3BlbmRpc3NlIG5lYyBz\n\
            b2RhbGVzIGVyYXQsIHNpdCBhbWV0IGltcGVyZGlldCBpcHN1bS4gRXRpYW0gc2Vk\n\
            IG9ybmFyZSBmZWxpcy4=
            """
        )
        XCTAssertEqual(
            Data(input.utf8).base64EncodedString(options: [.lineLength76Characters, .endLineWithLineFeed]),
            """
            TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQsIGNvbnNlY3RldHVyIGFkaXBpc2NpbmcgZWxpdC4g\n\
            VXQgYXQgdGluY2lkdW50IGFyY3UuIFN1c3BlbmRpc3NlIG5lYyBzb2RhbGVzIGVyYXQsIHNpdCBh\n\
            bWV0IGltcGVyZGlldCBpcHN1bS4gRXRpYW0gc2VkIG9ybmFyZSBmZWxpcy4=
            """
        )

        // using .endLineWithCarriageReturn
        XCTAssertEqual(
            Data(input.utf8).base64EncodedString(options: [.lineLength64Characters, .endLineWithCarriageReturn]),
            """
            TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQsIGNvbnNlY3RldHVyIGFkaXBpc2Np\r\
            bmcgZWxpdC4gVXQgYXQgdGluY2lkdW50IGFyY3UuIFN1c3BlbmRpc3NlIG5lYyBz\r\
            b2RhbGVzIGVyYXQsIHNpdCBhbWV0IGltcGVyZGlldCBpcHN1bS4gRXRpYW0gc2Vk\r\
            IG9ybmFyZSBmZWxpcy4=
            """
        )
        XCTAssertEqual(
            Data(input.utf8).base64EncodedString(options: [.lineLength76Characters, .endLineWithCarriageReturn]),
            """
            TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQsIGNvbnNlY3RldHVyIGFkaXBpc2NpbmcgZWxpdC4g\r\
            VXQgYXQgdGluY2lkdW50IGFyY3UuIFN1c3BlbmRpc3NlIG5lYyBzb2RhbGVzIGVyYXQsIHNpdCBh\r\
            bWV0IGltcGVyZGlldCBpcHN1bS4gRXRpYW0gc2VkIG9ybmFyZSBmZWxpcy4=
            """
        )

        // using .endLineWithLineFeed, .endLineWithCarriageReturn
        XCTAssertEqual(
            Data(input.utf8).base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed, .endLineWithCarriageReturn]),
            """
            TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQsIGNvbnNlY3RldHVyIGFkaXBpc2Np\r\n\
            bmcgZWxpdC4gVXQgYXQgdGluY2lkdW50IGFyY3UuIFN1c3BlbmRpc3NlIG5lYyBz\r\n\
            b2RhbGVzIGVyYXQsIHNpdCBhbWV0IGltcGVyZGlldCBpcHN1bS4gRXRpYW0gc2Vk\r\n\
            IG9ybmFyZSBmZWxpcy4=
            """
        )
        XCTAssertEqual(
            Data(input.utf8).base64EncodedString(options: [.lineLength76Characters, .endLineWithLineFeed, .endLineWithCarriageReturn]),
            """
            TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQsIGNvbnNlY3RldHVyIGFkaXBpc2NpbmcgZWxpdC4g\r\n\
            VXQgYXQgdGluY2lkdW50IGFyY3UuIFN1c3BlbmRpc3NlIG5lYyBzb2RhbGVzIGVyYXQsIHNpdCBh\r\n\
            bWV0IGltcGVyZGlldCBpcHN1bS4gRXRpYW0gc2VkIG9ybmFyZSBmZWxpcy4=
            """
        )

        // using no explicit endLine option
        XCTAssertEqual(
            Data(input.utf8).base64EncodedString(options: [.lineLength64Characters]),
            """
            TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQsIGNvbnNlY3RldHVyIGFkaXBpc2Np\r\n\
            bmcgZWxpdC4gVXQgYXQgdGluY2lkdW50IGFyY3UuIFN1c3BlbmRpc3NlIG5lYyBz\r\n\
            b2RhbGVzIGVyYXQsIHNpdCBhbWV0IGltcGVyZGlldCBpcHN1bS4gRXRpYW0gc2Vk\r\n\
            IG9ybmFyZSBmZWxpcy4=
            """
        )
        XCTAssertEqual(
            Data(input.utf8).base64EncodedString(options: [.lineLength76Characters]),
            """
            TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQsIGNvbnNlY3RldHVyIGFkaXBpc2NpbmcgZWxpdC4g\r\n\
            VXQgYXQgdGluY2lkdW50IGFyY3UuIFN1c3BlbmRpc3NlIG5lYyBzb2RhbGVzIGVyYXQsIHNpdCBh\r\n\
            bWV0IGltcGVyZGlldCBpcHN1bS4gRXRpYW0gc2VkIG9ybmFyZSBmZWxpcy4=
            """
        )
    }

    func test_base64Encode_DoesNotAddLineSeparatorsInLastLineWhenStringFitsInLine() {
         XCTAssertEqual(
             Data(repeating: 0, count: 48).base64EncodedString(options: .lineLength64Characters),
            "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
        )

         XCTAssertEqual(
             Data(repeating: 0, count: 96).base64EncodedString(options: .lineLength64Characters),
             """
             AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\n\
             AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
             """
        )
        print([UInt8](Data(repeating: 0, count: 96).base64EncodedString(options: .lineLength64Characters).utf8))

        XCTAssertEqual(
            Data(repeating: 0, count: 57).base64EncodedString(options: .lineLength76Characters),
            "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
        )

        XCTAssertEqual(
            Data(repeating: 0, count: 114).base64EncodedString(options: .lineLength76Characters),
            """
            AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\n\
            AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
            """
        )

    }

    func test_base64Decode_emptyString() {
        XCTAssertEqual(Data(), Data(base64Encoded: ""))
    }

    func test_base64Decode_emptyData() {
        XCTAssertEqual(Data(), Data(base64Encoded: Data()))
    }

    func test_base64Decode_arrayOfNulls() {
        XCTAssertEqual(Data(repeating: 0, count: 10), Data(base64Encoded: "AAAAAAAAAAAAAA=="))
    }

    func test_base64Decode_AllTheBytesSequentially() {
        let base64 = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0+P0BBQkNERUZHSElKS0xNTk9QUVJTVFVWV1hZWltcXV5fYGFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6e3x9fn+AgYKDhIWGh4iJiouMjY6PkJGSk5SVlpeYmZqbnJ2en6ChoqOkpaanqKmqq6ytrq+wsbKztLW2t7i5uru8vb6/wMHCw8TFxsfIycrLzM3Oz9DR0tPU1dbX2Nna29zd3t/g4eLj5OXm5+jp6uvs7e7v8PHy8/T19vf4+fr7/P3+/w=="

        XCTAssertEqual(Data(UInt8(0) ... UInt8(255)), Data(base64Encoded: base64))
    }

    func test_base64Decode_ignoringLineBreaks() {
        let base64 = """
            TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQsIGNvbnNlY3RldHVyIGFkaXBpc2Np\r\n\
            bmcgZWxpdC4gVXQgYXQgdGluY2lkdW50IGFyY3UuIFN1c3BlbmRpc3NlIG5lYyBz\r\n\
            b2RhbGVzIGVyYXQsIHNpdCBhbWV0IGltcGVyZGlldCBpcHN1bS4gRXRpYW0gc2Vk\r\n\
            IG9ybmFyZSBmZWxpcy4=
            """
        let expected = """
            Lorem ipsum dolor sit amet, consectetur adipiscing elit. Ut at tincidunt arcu. Suspendisse nec sodales erat, sit amet imperdiet ipsum. Etiam sed ornare felis.
            """

        XCTAssertEqual(Data(expected.utf8), Data(base64Encoded: base64, options: .ignoreUnknownCharacters))
    }

    func test_base64Decode_invalidLength() {
        XCTAssertNil(Data(base64Encoded: "AAAAA"))
        XCTAssertNil(Data(base64Encoded: "AAAAA", options: .ignoreUnknownCharacters))
    }

    func test_base64Decode_variousPaddingNeeds() {
        XCTAssertEqual(Data([1, 2, 3, 4]), Data(base64Encoded: "AQIDBA=="))
        XCTAssertEqual(Data([1, 2, 3, 4, 5]), Data(base64Encoded: "AQIDBAU="))
        XCTAssertEqual(Data([1, 2, 3, 4, 5, 6]), Data(base64Encoded: "AQIDBAUG"))
    }

    func test_base64Decode_ignoreWhitespaceAtVariousPlaces() {
        XCTAssertEqual(Data([1, 2, 3, 4]), Data(base64Encoded: " AQIDBA==", options: .ignoreUnknownCharacters))
        XCTAssertEqual(Data([1, 2, 3, 4]), Data(base64Encoded: "A QIDBA==", options: .ignoreUnknownCharacters))
        XCTAssertEqual(Data([1, 2, 3, 4]), Data(base64Encoded: "AQ IDBA==", options: .ignoreUnknownCharacters))
        XCTAssertEqual(Data([1, 2, 3, 4]), Data(base64Encoded: "AQI DBA==", options: .ignoreUnknownCharacters))
        XCTAssertEqual(Data([1, 2, 3, 4]), Data(base64Encoded: "AQID BA==", options: .ignoreUnknownCharacters))
        XCTAssertEqual(Data([1, 2, 3, 4]), Data(base64Encoded: "AQIDB A==", options: .ignoreUnknownCharacters))
        XCTAssertEqual(Data([1, 2, 3, 4]), Data(base64Encoded: "AQIDBA ==", options: .ignoreUnknownCharacters))
        XCTAssertEqual(Data([1, 2, 3, 4]), Data(base64Encoded: "AQIDBA= =", options: .ignoreUnknownCharacters))
        XCTAssertEqual(Data([1, 2, 3, 4]), Data(base64Encoded: "AQIDBA== ", options: .ignoreUnknownCharacters))

        XCTAssertEqual(Data([1, 2, 3, 4, 5]), Data(base64Encoded: " AQIDBAU=", options: .ignoreUnknownCharacters))
        XCTAssertEqual(Data([1, 2, 3, 4, 5]), Data(base64Encoded: "A QIDBAU=", options: .ignoreUnknownCharacters))
        XCTAssertEqual(Data([1, 2, 3, 4, 5]), Data(base64Encoded: "AQ IDBAU=", options: .ignoreUnknownCharacters))
        XCTAssertEqual(Data([1, 2, 3, 4, 5]), Data(base64Encoded: "AQI DBAU=", options: .ignoreUnknownCharacters))
        XCTAssertEqual(Data([1, 2, 3, 4, 5]), Data(base64Encoded: "AQID BAU=", options: .ignoreUnknownCharacters))
        XCTAssertEqual(Data([1, 2, 3, 4, 5]), Data(base64Encoded: "AQIDB AU=", options: .ignoreUnknownCharacters))
        XCTAssertEqual(Data([1, 2, 3, 4, 5]), Data(base64Encoded: "AQIDBA U=", options: .ignoreUnknownCharacters))
        XCTAssertEqual(Data([1, 2, 3, 4, 5]), Data(base64Encoded: "AQIDBAU =", options: .ignoreUnknownCharacters))
        XCTAssertEqual(Data([1, 2, 3, 4, 5]), Data(base64Encoded: "AQIDBAU= ", options: .ignoreUnknownCharacters))

        XCTAssertEqual(Data([1, 2, 3, 4, 5, 6]), Data(base64Encoded: " AQIDBAUG", options: .ignoreUnknownCharacters))
        XCTAssertEqual(Data([1, 2, 3, 4, 5, 6]), Data(base64Encoded: "A QIDBAUG", options: .ignoreUnknownCharacters))
        XCTAssertEqual(Data([1, 2, 3, 4, 5, 6]), Data(base64Encoded: "AQ IDBAUG", options: .ignoreUnknownCharacters))
        XCTAssertEqual(Data([1, 2, 3, 4, 5, 6]), Data(base64Encoded: "AQI DBAUG", options: .ignoreUnknownCharacters))
        XCTAssertEqual(Data([1, 2, 3, 4, 5, 6]), Data(base64Encoded: "AQID BAUG", options: .ignoreUnknownCharacters))
        XCTAssertEqual(Data([1, 2, 3, 4, 5, 6]), Data(base64Encoded: "AQIDB AUG", options: .ignoreUnknownCharacters))
        XCTAssertEqual(Data([1, 2, 3, 4, 5, 6]), Data(base64Encoded: "AQIDBA UG", options: .ignoreUnknownCharacters))
        XCTAssertEqual(Data([1, 2, 3, 4, 5, 6]), Data(base64Encoded: "AQIDBAU G", options: .ignoreUnknownCharacters))
        XCTAssertEqual(Data([1, 2, 3, 4, 5, 6]), Data(base64Encoded: "AQIDBAUG ", options: .ignoreUnknownCharacters))
    }

    func test_base64Decode_test1MBDataGoing0to255OverAndOver() {
        let oneMBTestData = createTestData(count: 1000 * 1024)
        func createTestData(count: Int) -> Data {
            var data = Data(count: count)
            for index in data.indices {
                data[index] = UInt8(index % Int(UInt8.max))
            }
            return data
        }

        let base64DataString = oneMBTestData.base64EncodedString(options: .lineLength64Characters)
        XCTAssertEqual(oneMBTestData, Data(base64Encoded: base64DataString, options: .ignoreUnknownCharacters))
    }

    func test_base64Data_small() {
        let data = Data("Hello World".utf8)
        let base64 = data.base64EncodedString()
        XCTAssertEqual("SGVsbG8gV29ybGQ=", base64, "trivial base64 conversion should work")
    }

    func test_base64Data_bad() {
        XCTAssertNil(Data(base64Encoded: "signature-not-base64-encoded"))
    }
    
    func test_base64Data_medium() {
        let data = Data("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Ut at tincidunt arcu. Suspendisse nec sodales erat, sit amet imperdiet ipsum. Etiam sed ornare felis. Nunc mauris turpis, bibendum non lectus quis, malesuada placerat turpis. Nam adipiscing non massa et semper. Nulla convallis semper bibendum. Aliquam dictum nulla cursus mi ultricies, at tincidunt mi sagittis. Nulla faucibus at dui quis sodales. Morbi rutrum, dui id ultrices venenatis, arcu urna egestas felis, vel suscipit mauris arcu quis risus. Nunc venenatis ligula at orci tristique, et mattis purus pulvinar. Etiam ultricies est odio. Nunc eleifend malesuada justo, nec euismod sem ultrices quis. Etiam nec nibh sit amet lorem faucibus dapibus quis nec leo. Praesent sit amet mauris vel lacus hendrerit porta mollis consectetur mi. Donec eget tortor dui. Morbi imperdiet, arcu sit amet elementum interdum, quam nisl tempor quam, vitae feugiat augue purus sed lacus. In ac urna adipiscing purus venenatis volutpat vel et metus. Nullam nec auctor quam. Phasellus porttitor felis ac nibh gravida suscipit tempus at ante. Nunc pellentesque iaculis sapien a mattis. Aenean eleifend dolor non nunc laoreet, non dictum massa aliquam. Aenean quis turpis augue. Praesent augue lectus, mollis nec elementum eu, dignissim at velit. Ut congue neque id ullamcorper pellentesque. Maecenas euismod in elit eu vehicula. Nullam tristique dui nulla, nec convallis metus suscipit eget. Cras semper augue nec cursus blandit. Nulla rhoncus et odio quis blandit. Praesent lobortis dignissim velit ut pulvinar. Duis interdum quam adipiscing dolor semper semper. Nunc bibendum convallis dui, eget mollis magna hendrerit et. Morbi facilisis, augue eu fringilla convallis, mauris est cursus dolor, eu posuere odio nunc quis orci. Ut eu justo sem. Phasellus ut erat rhoncus, faucibus arcu vitae, vulputate erat. Aliquam nec magna viverra, interdum est vitae, rhoncus sapien. Duis tincidunt tempor ipsum ut dapibus. Nullam commodo varius metus, sed sollicitudin eros. Etiam nec odio et dui tempor blandit posuere.".utf8)
        let base64 = data.base64EncodedString()
        XCTAssertEqual("TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQsIGNvbnNlY3RldHVyIGFkaXBpc2NpbmcgZWxpdC4gVXQgYXQgdGluY2lkdW50IGFyY3UuIFN1c3BlbmRpc3NlIG5lYyBzb2RhbGVzIGVyYXQsIHNpdCBhbWV0IGltcGVyZGlldCBpcHN1bS4gRXRpYW0gc2VkIG9ybmFyZSBmZWxpcy4gTnVuYyBtYXVyaXMgdHVycGlzLCBiaWJlbmR1bSBub24gbGVjdHVzIHF1aXMsIG1hbGVzdWFkYSBwbGFjZXJhdCB0dXJwaXMuIE5hbSBhZGlwaXNjaW5nIG5vbiBtYXNzYSBldCBzZW1wZXIuIE51bGxhIGNvbnZhbGxpcyBzZW1wZXIgYmliZW5kdW0uIEFsaXF1YW0gZGljdHVtIG51bGxhIGN1cnN1cyBtaSB1bHRyaWNpZXMsIGF0IHRpbmNpZHVudCBtaSBzYWdpdHRpcy4gTnVsbGEgZmF1Y2lidXMgYXQgZHVpIHF1aXMgc29kYWxlcy4gTW9yYmkgcnV0cnVtLCBkdWkgaWQgdWx0cmljZXMgdmVuZW5hdGlzLCBhcmN1IHVybmEgZWdlc3RhcyBmZWxpcywgdmVsIHN1c2NpcGl0IG1hdXJpcyBhcmN1IHF1aXMgcmlzdXMuIE51bmMgdmVuZW5hdGlzIGxpZ3VsYSBhdCBvcmNpIHRyaXN0aXF1ZSwgZXQgbWF0dGlzIHB1cnVzIHB1bHZpbmFyLiBFdGlhbSB1bHRyaWNpZXMgZXN0IG9kaW8uIE51bmMgZWxlaWZlbmQgbWFsZXN1YWRhIGp1c3RvLCBuZWMgZXVpc21vZCBzZW0gdWx0cmljZXMgcXVpcy4gRXRpYW0gbmVjIG5pYmggc2l0IGFtZXQgbG9yZW0gZmF1Y2lidXMgZGFwaWJ1cyBxdWlzIG5lYyBsZW8uIFByYWVzZW50IHNpdCBhbWV0IG1hdXJpcyB2ZWwgbGFjdXMgaGVuZHJlcml0IHBvcnRhIG1vbGxpcyBjb25zZWN0ZXR1ciBtaS4gRG9uZWMgZWdldCB0b3J0b3IgZHVpLiBNb3JiaSBpbXBlcmRpZXQsIGFyY3Ugc2l0IGFtZXQgZWxlbWVudHVtIGludGVyZHVtLCBxdWFtIG5pc2wgdGVtcG9yIHF1YW0sIHZpdGFlIGZldWdpYXQgYXVndWUgcHVydXMgc2VkIGxhY3VzLiBJbiBhYyB1cm5hIGFkaXBpc2NpbmcgcHVydXMgdmVuZW5hdGlzIHZvbHV0cGF0IHZlbCBldCBtZXR1cy4gTnVsbGFtIG5lYyBhdWN0b3IgcXVhbS4gUGhhc2VsbHVzIHBvcnR0aXRvciBmZWxpcyBhYyBuaWJoIGdyYXZpZGEgc3VzY2lwaXQgdGVtcHVzIGF0IGFudGUuIE51bmMgcGVsbGVudGVzcXVlIGlhY3VsaXMgc2FwaWVuIGEgbWF0dGlzLiBBZW5lYW4gZWxlaWZlbmQgZG9sb3Igbm9uIG51bmMgbGFvcmVldCwgbm9uIGRpY3R1bSBtYXNzYSBhbGlxdWFtLiBBZW5lYW4gcXVpcyB0dXJwaXMgYXVndWUuIFByYWVzZW50IGF1Z3VlIGxlY3R1cywgbW9sbGlzIG5lYyBlbGVtZW50dW0gZXUsIGRpZ25pc3NpbSBhdCB2ZWxpdC4gVXQgY29uZ3VlIG5lcXVlIGlkIHVsbGFtY29ycGVyIHBlbGxlbnRlc3F1ZS4gTWFlY2VuYXMgZXVpc21vZCBpbiBlbGl0IGV1IHZlaGljdWxhLiBOdWxsYW0gdHJpc3RpcXVlIGR1aSBudWxsYSwgbmVjIGNvbnZhbGxpcyBtZXR1cyBzdXNjaXBpdCBlZ2V0LiBDcmFzIHNlbXBlciBhdWd1ZSBuZWMgY3Vyc3VzIGJsYW5kaXQuIE51bGxhIHJob25jdXMgZXQgb2RpbyBxdWlzIGJsYW5kaXQuIFByYWVzZW50IGxvYm9ydGlzIGRpZ25pc3NpbSB2ZWxpdCB1dCBwdWx2aW5hci4gRHVpcyBpbnRlcmR1bSBxdWFtIGFkaXBpc2NpbmcgZG9sb3Igc2VtcGVyIHNlbXBlci4gTnVuYyBiaWJlbmR1bSBjb252YWxsaXMgZHVpLCBlZ2V0IG1vbGxpcyBtYWduYSBoZW5kcmVyaXQgZXQuIE1vcmJpIGZhY2lsaXNpcywgYXVndWUgZXUgZnJpbmdpbGxhIGNvbnZhbGxpcywgbWF1cmlzIGVzdCBjdXJzdXMgZG9sb3IsIGV1IHBvc3VlcmUgb2RpbyBudW5jIHF1aXMgb3JjaS4gVXQgZXUganVzdG8gc2VtLiBQaGFzZWxsdXMgdXQgZXJhdCByaG9uY3VzLCBmYXVjaWJ1cyBhcmN1IHZpdGFlLCB2dWxwdXRhdGUgZXJhdC4gQWxpcXVhbSBuZWMgbWFnbmEgdml2ZXJyYSwgaW50ZXJkdW0gZXN0IHZpdGFlLCByaG9uY3VzIHNhcGllbi4gRHVpcyB0aW5jaWR1bnQgdGVtcG9yIGlwc3VtIHV0IGRhcGlidXMuIE51bGxhbSBjb21tb2RvIHZhcml1cyBtZXR1cywgc2VkIHNvbGxpY2l0dWRpbiBlcm9zLiBFdGlhbSBuZWMgb2RpbyBldCBkdWkgdGVtcG9yIGJsYW5kaXQgcG9zdWVyZS4=", base64, "medium base64 conversion should work")
    }

    func test_AnyHashableContainingData() {
        let values: [Data] = [
            Data(base64Encoded: "AAAA")!,
            Data(base64Encoded: "AAAB")!,
            Data(base64Encoded: "AAAB")!,
        ]
        let anyHashables = values.map(AnyHashable.init)
        expectEqual(Data.self, type(of: anyHashables[0].base))
        expectEqual(Data.self, type(of: anyHashables[1].base))
        expectEqual(Data.self, type(of: anyHashables[2].base))
        XCTAssertNotEqual(anyHashables[0], anyHashables[1])
        XCTAssertEqual(anyHashables[1], anyHashables[2])
    }

    func test_replaceSubrange() {
        // https://bugs.swift.org/browse/SR-4462
        let data = Data([0x01, 0x02])
        var dataII = Data(base64Encoded: data.base64EncodedString())!
        dataII.replaceSubrange(0..<1, with: Data())
        XCTAssertEqual(dataII[0], 0x02)
    }
    
    func testEOPNOTSUPP() throws {
        #if !canImport(Darwin) && !os(Linux) && !os(Android)
        throw XCTSkip("POSIXError.Code is not supported on this platform")
        #else
        // Opening a socket via open(2) on Darwin can result in the EOPNOTSUPP error code
        // Validate that this does not crash despite missing a case in POSIXError.Code
        let error = CocoaError.errorWithFilePath("/foo/bar", errno: EOPNOTSUPP, reading: true)
        XCTAssertEqual(error.filePath, "/foo/bar")
        #endif
    }
}

#if FOUNDATION_FRAMEWORK // FIXME: Re-enable tests once range(of:) is implemented
extension DataTests {
    func testRange() {
        let helloWorld = dataFrom("Hello World")
        let goodbye = dataFrom("Goodbye")
        let hello = dataFrom("Hello")

        do {
            let found = helloWorld.range(of: goodbye)
            XCTAssertNil(found)
        }

        do {
            let found = helloWorld.range(of: goodbye, options: .anchored)
            XCTAssertNil(found)
        }

        do {
            let found = helloWorld.range(of: hello, in: 7..<helloWorld.count)
            XCTAssertNil(found)
        }
    }

    func testReplaceSubrange2() {
        let hello = dataFrom("Hello")
        let world = dataFrom(" World")
        let goodbye = dataFrom("Goodbye")
        let expected = dataFrom("Goodbye World")

        var mutateMe = hello
        mutateMe.append(world)

        if let found = mutateMe.range(of: hello) {
            mutateMe.replaceSubrange(found, with: goodbye)
        }
        XCTAssertEqual(mutateMe, expected)
    }
}
#endif // FOUNDATION_FRAMEWORK

#if FOUNDATION_FRAMEWORK // Bridging is not available in the FoundationPreview package
extension DataTests {
    func test_noCustomDealloc_bridge() {
        let bytes = UnsafeMutableRawBufferPointer.allocate(byteCount: 1024, alignment: MemoryLayout<AnyObject>.alignment)
        
        let data: Data = Data(bytesNoCopy: bytes.baseAddress!, count: bytes.count, deallocator: .free)
        let copy = data._bridgeToObjectiveC().copy() as! NSData
        data.withUnsafeBytes { buffer in
            XCTAssertEqual(buffer.baseAddress, copy.bytes)
        }
    }
    
    func test_noCopy_uaf_bridge() {
        // this can only really be tested (modulo ASAN) via comparison of the pointer address of the storage.
        let bytes = UnsafeMutableRawBufferPointer.allocate(byteCount: 1024, alignment: MemoryLayout<AnyObject>.alignment)
        
        let data: Data = Data(bytesNoCopy: bytes.baseAddress!, count: bytes.count, deallocator: .none)
        let copy = data._bridgeToObjectiveC().copy() as! NSData
        data.withUnsafeBytes { buffer in
            XCTAssertNotEqual(buffer.baseAddress, copy.bytes)
        }
        bytes.deallocate()
    }
}
#endif
