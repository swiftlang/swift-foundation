//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable import FoundationEssentials
#endif // FOUNDATION_FRAMEWORK

struct DataIOTests {

    // MARK: - Helpers
    
#if FOUNDATION_FRAMEWORK
    func testURL() -> URL {
        // Generate a random file name
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("testfile-\(UUID().uuidString)")
    }
#else
    /// Temporary helper until we port `URL` to swift-foundation.
    func testURL() -> String {
        // Generate a random file name
        String.temporaryDirectoryPath.appendingPathComponent("testfile-\(UUID().uuidString)")
    }
#endif
    
    func generateTestData() -> Data {
        // 16 MB file, big enough to trigger things like chunking
        let count = 16_777_216

        let memory = malloc(count)!
        let ptr = memory.bindMemory(to: UInt8.self, capacity: count)
        
        // Set a few bytes so we're sure to not be all zeros
        let buf = UnsafeMutableBufferPointer(start: ptr, count: count)
        for i in 0..<15 {
            for j in 0..<128 {
                buf[j * 1024 + i] = UInt8.random(in: 1..<42)
            }
        }

        return Data(bytesNoCopy: ptr, count: count, deallocator: .free)
    }

#if FOUNDATION_FRAMEWORK
    func writeAndVerifyTestData(to url: URL, writeOptions: Data.WritingOptions = [], readOptions: Data.ReadingOptions = []) throws {
        let data = generateTestData()
        try data.write(to: url, options: writeOptions)
        let readData = try Data(contentsOf: url, options: readOptions)
        #expect(data == readData)
    }

    func cleanup(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            // Ignore
        }
    }
#else
    func writeAndVerifyTestData(to path: String, writeOptions: Data.WritingOptions = [], readOptions: Data.ReadingOptions = []) throws {
        let data = generateTestData()
        try data.write(to: path, options: writeOptions)
        let readData = try Data(contentsOf: path, options: readOptions)
        #expect(data == readData)
    }

    func cleanup(at path: String) {
        _ = unlink(path)
        // Ignore any errors
    }
#endif

    // MARK: - Tests

    @Test func test_basicReadWrite() throws {
        let url = testURL()
        try writeAndVerifyTestData(to: url)
        cleanup(at: url)
    }
    
    @Test func test_slicedReadWrite() throws {
        // Be sure to use progress reporting so we get tests of the chunking
        let url = testURL()
        let data = generateTestData()
        let slice = data[data.startIndex.advanced(by: 1 * 1024 * 1024)..<data.startIndex.advanced(by: 8 * 1024 * 1024)]

#if FOUNDATION_FRAMEWORK
        let p = Progress(totalUnitCount: 1)
        p.becomeCurrent(withPendingUnitCount: 1)
#endif
        try slice.write(to: url, options: [])
#if FOUNDATION_FRAMEWORK
        p.resignCurrent()
#endif
        let readData = try Data(contentsOf: url, options: [])
        #expect(readData == slice)
        cleanup(at: url)
    }

    // Atomic writing is a very different code path
    @Test func test_readWriteAtomic() throws {
        let url = testURL()
        // Perform an atomic write to a file that does not exist
        try writeAndVerifyTestData(to: url, writeOptions: [.atomic])

        // Perform an atomic write to a file that already exists
        try writeAndVerifyTestData(to: url, writeOptions: [.atomic])

        cleanup(at: url)
    }

    @Test func test_readWriteMapped() throws {
        let url = testURL()
        try writeAndVerifyTestData(to: url, readOptions: [.mappedIfSafe])

        cleanup(at: url)
    }

    @Test func test_writeFailure() throws {
        let url = testURL()

        let data = Data()
        try data.write(to: url)

#if FOUNDATION_FRAMEWORK
        #expect {
            try data.write(to: url, options: [.withoutOverwriting])
        } throws: { error in
            #expect((error as NSError).code == NSFileWriteFileExistsError)
            return true
        }
#else
        #expect(throws: (any Error).self) {
            try data.write(to: url, options: [.withoutOverwriting])
        }
#endif

        cleanup(at: url)

        // Make sure clearing the error condition allows the write to succeed
        try data.write(to: url, options: [.withoutOverwriting])

        cleanup(at: url)
    }

#if FOUNDATION_FRAMEWORK
    // Progress is curently stubbed out for FoundationPreview
    @Test func test_writeWithProgress() throws {
        let url = testURL()
        
        let p = Progress(totalUnitCount: 1)
        p.becomeCurrent(withPendingUnitCount: 1)
        try writeAndVerifyTestData(to: url)
        p.resignCurrent()
        
        #expect(p.completedUnitCount == 1)
        #expect(abs(p.fractionCompleted - 1.0) <= 0.1)
        cleanup(at: url)
    }
#endif

#if FOUNDATION_FRAMEWORK
    @Test func test_writeWithAttributes() throws {
        let writeData = generateTestData()
        
        let url = testURL()
        // Data doesn't have a direct API to write with attributes, but our I/O code has it. Use it via @testable interface here.
        
        let writeAttrs: [String : Data] = [FileAttributeKey.hfsCreatorCode.rawValue : "abcd".data(using: .ascii)!]
        try writeToFile(path: .url(url), data: writeData, options: [], attributes: writeAttrs)
        
        // Verify attributes
        var readAttrs: [String : Data] = [:]
        let readData = try readDataFromFile(path: .url(url), reportProgress: false, options: [], attributesToRead: [FileAttributeKey.hfsCreatorCode.rawValue], attributes: &readAttrs)
        
        #expect(writeData == readData)
        #expect(writeAttrs == readAttrs)

        cleanup(at: url)
    }
#endif

    @Test func test_emptyFile() throws {
        let data = Data()
        let url = testURL()
        try data.write(to: url)
        let read = try Data(contentsOf: url, options: [])
        #expect(data == read)

        cleanup(at: url)
    }

#if FOUNDATION_FRAMEWORK
    // String(contentsOf:) is not available outside the framework yet
    @Test func test_emptyFileString() {
        let data = Data()
        let url = testURL()
        
        do {
            try data.write(to: url)
            let readString = try String(contentsOf: url)
            #expect(readString == "")

            let readStringWithEncoding = try String(contentsOf: url, encoding: String._Encoding.utf8)
            #expect(readStringWithEncoding == "")

            cleanup(at: url)
        } catch {
            Issue.record("Could not read file: \(error)")
        }
    }
#endif

    @Test func test_largeFile() throws {
#if !os(watchOS)
        // More than 2 GB
        let size = 0x80010000
        let url = testURL()

        let data = Data(count: size)
        
        try data.write(to: url)
        
        cleanup(at: url)
#endif
    }
    
#if os(Linux) || os(Windows)
    func test_writeToSpecialFile() throws {
        #if os(Windows)
        let path = "CON"
        #else
        let path = "/dev/stdout"
        #endif
        #expect(throws: Never.self) {
            try Data("Output to STDOUT\n".utf8).write(to: path)
        }
    }
#endif // os(Linux) || os(Windows)

    // MARK: - String Path Tests
    @Test func testStringDeletingLastPathComponent() {
        #expect("/a/b/c".deletingLastPathComponent() == "/a/b")
        #expect("".deletingLastPathComponent() == "")
        #expect("/".deletingLastPathComponent() == "/")
        #expect("q".deletingLastPathComponent() == "")
        #expect("/aaa".deletingLastPathComponent() == "/")
        #expect("/a/b/c/".deletingLastPathComponent() == "/a/b")
        #expect("hello".deletingLastPathComponent() == "")
        #expect("hello/".deletingLastPathComponent() == "")
    }

    @Test func testAppendingPathComponent() {
        let comp = "test"
        #expect("/a/b/c".appendingPathComponent(comp) == "/a/b/c/test")
        #expect("".appendingPathComponent(comp) == "test")
        #expect("/".appendingPathComponent(comp) == "/test")
        #expect("q".appendingPathComponent(comp) == "q/test")
        #expect("/aaa".appendingPathComponent(comp) == "/aaa/test")
        #expect("/a/b/c/".appendingPathComponent(comp) == "/a/b/c/test")
        #expect("hello".appendingPathComponent(comp) == "hello/test")
        #expect("hello/".appendingPathComponent(comp) == "hello/test")

        #expect("hello/".appendingPathComponent("/test") == "hello/test")
        #expect("hello".appendingPathComponent("/test") == "hello/test")
        #expect("hello///".appendingPathComponent("///test") == "hello/test")
        #expect("hello".appendingPathComponent("test/") == "hello/test")
        #expect("hello".appendingPathComponent("test/test2") == "hello/test/test2")
        #expect("hello".appendingPathComponent("test/test2/") == "hello/test/test2")
        #expect("hello".appendingPathComponent("test///test2/") == "hello/test/test2")
        #expect("hello".appendingPathComponent("/") == "hello")
        #expect("//".appendingPathComponent("/") == "/")
        #expect("".appendingPathComponent("") == "")
    }

    @Test func testStringLastPathComponent() {
        #expect("/a/b/c".lastPathComponent == "c")
        #expect("".lastPathComponent == "")
        #expect("/".lastPathComponent == "/")
        #expect("q".lastPathComponent == "q")
        #expect("/aaa".lastPathComponent == "aaa")
        #expect("/a/b/c/".lastPathComponent == "c")
        #expect("hello".lastPathComponent == "hello")
        #expect("hello/".lastPathComponent == "hello")
    }
}

