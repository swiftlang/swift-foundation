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
        let count = 1 << 24
        
        let memory = malloc(count)!
        let ptr = memory.bindMemory(to: UInt8.self, capacity: count)
        
        // Set a few bytes so we're sure to not be all zeros
        let buf = UnsafeMutableBufferPointer(start: ptr, count: count)
        for i in 0..<128 {
            buf[i] = UInt8.random(in: 1..<42)
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
        try writeDataToFile(path: .url(url), data: writeData, options: [], attributes: writeAttrs)
        
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

