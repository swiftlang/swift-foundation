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

#if canImport(TestSupport)
import TestSupport
#endif

#if canImport(Glibc)
import Glibc
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable import FoundationEssentials
#endif // FOUNDATION_FRAMEWORK

class DataIOTests : XCTestCase {
    
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
        XCTAssertEqual(data, readData)
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
        XCTAssertEqual(data, readData)
    }

    func cleanup(at path: String) {
        _ = unlink(path)
        // Ignore any errors
    }
#endif
    
    
    // MARK: - Tests
    
    func test_basicReadWrite() throws {
        let url = testURL()
        try writeAndVerifyTestData(to: url)
        cleanup(at: url)
    }
    
    func test_slicedReadWrite() throws {
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
        XCTAssertEqual(readData, slice)
        cleanup(at: url)
    }

    // Atomic writing is a very different code path
    func test_readWriteAtomic() throws {
        let url = testURL()
        // Perform an atomic write to a file that does not exist
        try writeAndVerifyTestData(to: url, writeOptions: [.atomic])

        // Perform an atomic write to a file that already exists
        try writeAndVerifyTestData(to: url, writeOptions: [.atomic])

        cleanup(at: url)
    }

    func test_readWriteMapped() throws {
        let url = testURL()
        try writeAndVerifyTestData(to: url, readOptions: [.mappedIfSafe])

        cleanup(at: url)
    }

    func test_writeFailure() throws {
        let url = testURL()

        let data = Data()
        try data.write(to: url)

#if FOUNDATION_FRAMEWORK
        XCTAssertThrowsError(try data.write(to: url, options: [.withoutOverwriting])) { e in
            XCTAssertEqual((e as NSError).code, NSFileWriteFileExistsError)
        }
#else
        XCTAssertThrowsError(try data.write(to: url, options: [.withoutOverwriting]))
#endif
        
        cleanup(at: url)

        // Make sure clearing the error condition allows the write to succeed
        try data.write(to: url, options: [.withoutOverwriting])

        cleanup(at: url)
    }
    
#if FOUNDATION_FRAMEWORK
    // Progress is curently stubbed out for FoundationPreview
    func test_writeWithProgress() throws {
        let url = testURL()
        
        let p = Progress(totalUnitCount: 1)
        p.becomeCurrent(withPendingUnitCount: 1)
        try writeAndVerifyTestData(to: url)
        p.resignCurrent()
        
        XCTAssertEqual(p.completedUnitCount, 1)
        XCTAssertEqual(p.fractionCompleted, 1.0, accuracy: 0.1)
        cleanup(at: url)
    }
#endif
    
#if FOUNDATION_FRAMEWORK
    func test_writeWithAttributes() throws {
        let writeData = generateTestData()
        
        let url = testURL()
        // Data doesn't have a direct API to write with attributes, but our I/O code has it. Use it via @testable interface here.
        
        let writeAttrs: [String : Data] = [FileAttributeKey.hfsCreatorCode.rawValue : "abcd".data(using: .ascii)!]
        try writeToFile(path: .url(url), data: writeData, options: [], attributes: writeAttrs)
        
        // Verify attributes
        var readAttrs: [String : Data] = [:]
        let readData = try readDataFromFile(path: .url(url), reportProgress: false, options: [], attributesToRead: [FileAttributeKey.hfsCreatorCode.rawValue], attributes: &readAttrs)
        
        XCTAssertEqual(writeData, readData)
        XCTAssertEqual(writeAttrs, readAttrs)
        
        cleanup(at: url)
    }
#endif
        
    func test_emptyFile() throws {
        let data = Data()
        let url = testURL()
        try data.write(to: url)
        let read = try Data(contentsOf: url, options: [])
        XCTAssertEqual(data, read)
        
        cleanup(at: url)
    }
    
#if FOUNDATION_FRAMEWORK
    // String(contentsOf:) is not available outside the framework yet
    func test_emptyFileString() {
        let data = Data()
        let url = testURL()
        
        do {
            try data.write(to: url)
            let readString = try String(contentsOf: url)
            XCTAssertEqual(readString, "")
            
            let readStringWithEncoding = try String(contentsOf: url, encoding: String._Encoding.utf8)
            XCTAssertEqual(readStringWithEncoding, "")
            
            cleanup(at: url)
        } catch {
            XCTFail("Could not read file: \(error)")
        }
    }
#endif
    
    func test_largeFile() throws {
#if !os(watchOS)
        // More than 2 GB
        let size = 0x80010000
        let url = testURL()

        let data = Data(count: size)
        
        try data.write(to: url)
        
        cleanup(at: url)
#endif
    }
    
    func test_writeToSpecialFile() throws {
        #if !os(Linux) && !os(Windows)
        throw XCTSkip("This test is only supported on Linux and Windows")
        #else
        #if os(Windows)
        let path = "CON"
        #else
        let path = "/dev/stdout"
        #endif
        XCTAssertNoThrow(try Data("Output to STDOUT\n".utf8).write(to: path))
        #endif
    }

    // MARK: - String Path Tests
    func testStringDeletingLastPathComponent() {
        XCTAssertEqual("/a/b/c".deletingLastPathComponent(), "/a/b")
        XCTAssertEqual("".deletingLastPathComponent(), "")
        XCTAssertEqual("/".deletingLastPathComponent(), "/")
        XCTAssertEqual("q".deletingLastPathComponent(), "")
        XCTAssertEqual("/aaa".deletingLastPathComponent(), "/")
        XCTAssertEqual("/a/b/c/".deletingLastPathComponent(), "/a/b")
        XCTAssertEqual("hello".deletingLastPathComponent(), "")
        XCTAssertEqual("hello/".deletingLastPathComponent(), "")
    }
    
    func testAppendingPathComponent() {
        let comp = "test"
        XCTAssertEqual("/a/b/c".appendingPathComponent(comp), "/a/b/c/test")
        XCTAssertEqual("".appendingPathComponent(comp), "test")
        XCTAssertEqual("/".appendingPathComponent(comp), "/test")
        XCTAssertEqual("q".appendingPathComponent(comp), "q/test")
        XCTAssertEqual("/aaa".appendingPathComponent(comp), "/aaa/test")
        XCTAssertEqual("/a/b/c/".appendingPathComponent(comp), "/a/b/c/test")
        XCTAssertEqual("hello".appendingPathComponent(comp), "hello/test")
        XCTAssertEqual("hello/".appendingPathComponent(comp), "hello/test")
        
        XCTAssertEqual("hello/".appendingPathComponent("/test"), "hello/test")
        XCTAssertEqual("hello".appendingPathComponent("/test"), "hello/test")
        XCTAssertEqual("hello///".appendingPathComponent("///test"), "hello/test")
        XCTAssertEqual("hello".appendingPathComponent("test/"), "hello/test")
        XCTAssertEqual("hello".appendingPathComponent("test/test2"), "hello/test/test2")
        XCTAssertEqual("hello".appendingPathComponent("test/test2/"), "hello/test/test2")
        XCTAssertEqual("hello".appendingPathComponent("test///test2/"), "hello/test/test2")
        XCTAssertEqual("hello".appendingPathComponent("/"), "hello")
        XCTAssertEqual("//".appendingPathComponent("/"), "/")
        XCTAssertEqual("".appendingPathComponent(""), "")
    }
    
    func testStringLastPathComponent() {
        XCTAssertEqual("/a/b/c".lastPathComponent, "c")
        XCTAssertEqual("".lastPathComponent, "")
        XCTAssertEqual("/".lastPathComponent, "/")
        XCTAssertEqual("q".lastPathComponent, "q")
        XCTAssertEqual("/aaa".lastPathComponent, "aaa")
        XCTAssertEqual("/a/b/c/".lastPathComponent, "c")
        XCTAssertEqual("hello".lastPathComponent, "hello")
        XCTAssertEqual("hello/".lastPathComponent, "hello")
    }
}

