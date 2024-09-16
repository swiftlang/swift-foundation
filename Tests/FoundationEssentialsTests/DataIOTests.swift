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
#elseif canImport(Musl)
import Musl
#elseif os(WASI)
import WASILibc
#elseif os(Windows)
import CRT
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable import FoundationEssentials
#endif // FOUNDATION_FRAMEWORK

final class DataIOTests {
    
    // MARK: - Helpers
    
    let url: URL
    
    init() {
        // Generate a random file name
        url = URL.temporaryDirectory.appendingPathComponent("testfile-\(UUID().uuidString)")
    }
    
    func generateTestData(count: Int = 16_777_216) -> Data {
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
            
    func writeAndVerifyTestData(to url: URL, writeOptions: Data.WritingOptions = [], readOptions: Data.ReadingOptions = []) throws {
        let data = generateTestData()
        try data.write(to: url, options: writeOptions)
        let readData = try Data(contentsOf: url, options: readOptions)
        #expect(data == readData)
    }
    
    deinit {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            // Ignore
        }
    }
    
    // MARK: - Tests
    
    @Test func test_basicReadWrite() throws {
        try writeAndVerifyTestData(to: url)
    }
    
    @Test func test_slicedReadWrite() throws {
        // Be sure to use progress reporting so we get tests of the chunking
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
    }

    // Atomic writing is a very different code path
    @Test func test_readWriteAtomic() throws {
        // Perform an atomic write to a file that does not exist
        try writeAndVerifyTestData(to: url, writeOptions: [.atomic])

        // Perform an atomic write to a file that already exists
        try writeAndVerifyTestData(to: url, writeOptions: [.atomic])
    }

    @Test func test_readWriteMapped() throws {
        try writeAndVerifyTestData(to: url, readOptions: [.mappedIfSafe])
    }

    @Test func test_writeFailure() throws {

        let data = Data()
        try data.write(to: url)
        
        #expect {
            try data.write(to: url, options: [.withoutOverwriting])
        } throws: {
            ($0 as? CocoaError)?.code == .fileWriteFileExists
        }
        
        // Make sure clearing the error condition allows the write to succeed
        try FileManager.default.removeItem(at: url)
        try data.write(to: url, options: [.withoutOverwriting])
    }
    
#if FOUNDATION_FRAMEWORK
    // Progress is currently stubbed out for FoundationPreview
    @Test func test_writeWithProgress() throws {
        
        let p = Progress(totalUnitCount: 1)
        p.becomeCurrent(withPendingUnitCount: 1)
        try writeAndVerifyTestData(to: url)
        p.resignCurrent()
        
        #expect(p.completedUnitCount == 1)
        #expect((0.9 ..< 1.1).contains(p.fractionCompleted))
    }
#endif
    
#if FOUNDATION_FRAMEWORK
    @Test func test_writeWithAttributes() throws {
        let writeData = generateTestData()
        
        // Data doesn't have a direct API to write with attributes, but our I/O code has it. Use it via @testable interface here.
        
        let writeAttrs: [String : Data] = [FileAttributeKey.hfsCreatorCode.rawValue : "abcd".data(using: .ascii)!]
        try writeToFile(path: .url(url), data: writeData, options: [], attributes: writeAttrs)
        
        // Verify attributes
        var readAttrs: [String : Data] = [:]
        let readData = try readDataFromFile(path: .url(url), reportProgress: false, options: [], attributesToRead: [FileAttributeKey.hfsCreatorCode.rawValue], attributes: &readAttrs)
        
        #expect(writeData == readData)
        #expect(writeAttrs == readAttrs)
        
    }
#endif
        
    @Test func test_emptyFile() throws {
        let data = Data()
        try data.write(to: url)
        let read = try Data(contentsOf: url, options: [])
        #expect(data == read)
    }
    
    @Test func test_emptyFileString() throws {
        let data = Data()
        try data.write(to: url)
        let readStringWithEncoding = try String(contentsOf: url, encoding: String.Encoding.utf8)
        #expect(readStringWithEncoding.isEmpty)
    }
    
    @Test func test_largeFile() throws {
#if !os(watchOS)
        // More than 2 GB
        let size = 0x80010000

        let data = generateTestData(count: size)
        
        try data.write(to: url)
        let read = try Data(contentsOf: url, options: .mappedIfSafe)

        // No need to compare the contents, but do compare the size
        #expect(data.count == read.count)
        
#if FOUNDATION_FRAMEWORK
        // Try the NSData path
        let readNS = try NSData(contentsOf: url, options: .mappedIfSafe) as Data
        #expect(data.count == readNS.count)
#endif

#endif // !os(watchOS)
    }
    
#if os(Linux) || os(Windows)
    @Test func test_writeToSpecialFile() {
#if os(Windows)
        let path = URL(filePath: "CON", directoryHint: .notDirectory)
#else
        let path = URL(filePath: "/dev/stdout", directoryHint: .notDirectory)
#endif
        #expect(throws: Never.self) {
            try Data("Output to STDOUT\n".utf8).write(to: path)
        }
    }
#endif
    
#if os(Linux)
    @Test func test_zeroSizeFile() throws {
        // Some files in /proc report a file size of 0 bytes via a stat call
        // Ensure that these files can still be read despite appearing to be empty
        let maps = try String(contentsOfFile: "/proc/self/maps", encoding: String.Encoding.utf8)
        #expect(!maps.isEmpty)
    }
#endif

    // MARK: - String Path Tests
    @Test func testStringDeletingLastPathComponent() {
        #expect("/a/b/c".deletingLastPathComponent() == "/a/b")
        #expect("".deletingLastPathComponent() == "")
        #expect("/".deletingLastPathComponent() == "/")
        #expect("q".deletingLastPathComponent() == "")
        #expect("/aaa".deletingLastPathComponent() == "/")
        #expect("/aaa/".deletingLastPathComponent() == "/")
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

