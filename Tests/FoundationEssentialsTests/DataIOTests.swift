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

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable import FoundationEssentials
#endif // FOUNDATION_FRAMEWORK

private func generateTestData(count: Int = 16_777_216) -> Data {
    // Set a few bytes so we're sure to not be all zeros
    let buf = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: count)
    for i in 0..<15 {
        for j in 0..<128 {
            buf[j * 1024 + i] = UInt8.random(in: 1..<42)
        }
    }
    
    return Data(bytesNoCopy: buf.baseAddress!, count: count, deallocator: .custom({ ptr, _ in
        ptr.deallocate()
    }))
}

@Suite("Data I/O")
private final class DataIOTests {
    
    // MARK: - Helpers
    
    let url: URL
    
    init() {
        // Generate a random file name
        url = URL.temporaryDirectory.appendingPathComponent("testfile-\(UUID().uuidString)")
    }
            
    func writeAndVerifyTestData(to url: URL, writeOptions: Data.WritingOptions = [], readOptions: Data.ReadingOptions = [], sourceLocation: SourceLocation = #_sourceLocation) throws {
        let data = generateTestData()
        try data.write(to: url, options: writeOptions)
        let readData = try Data(contentsOf: url, options: readOptions)
        #expect(data == readData, sourceLocation: sourceLocation)
    }
    
    deinit {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            // Ignore
        }
    }
    
    // MARK: - Tests
    
    @Test func basicReadWrite() throws {
        try writeAndVerifyTestData(to: url)
    }
    
    @Test func slicedReadWrite() throws {
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

    #if !os(WASI)
    // Atomic writing is a very different code path
    @Test func readWriteAtomic() throws {
        // Perform an atomic write to a file that does not exist
        try writeAndVerifyTestData(to: url, writeOptions: [.atomic])

        // Perform an atomic write to a file that already exists
        try writeAndVerifyTestData(to: url, writeOptions: [.atomic])
    }
    #endif

    @Test func readWriteMapped() throws {
        try writeAndVerifyTestData(to: url, readOptions: [.mappedIfSafe])
    }

    @Test func writeFailure() throws {
        let data = Data()
        try data.write(to: url)
        
        #expect {
            try data.write(to: url, options: [.withoutOverwriting])
        } throws: {
            ($0 as? CocoaError)?.code == .fileWriteFileExists
        }
        
        try FileManager.default.removeItem(at: url)

        // Make sure clearing the error condition allows the write to succeed
        try data.write(to: url, options: [.withoutOverwriting])
    }
    
#if FOUNDATION_FRAMEWORK
    // Progress is currently stubbed out for FoundationPreview
    @Test func writeWithProgress() throws {
        let p = Progress(totalUnitCount: 1)
        p.becomeCurrent(withPendingUnitCount: 1)
        try writeAndVerifyTestData(to: url)
        p.resignCurrent()
        
        #expect(p.completedUnitCount == 1)
        #expect(abs(p.fractionCompleted - 1.0) <= 0.1)
    }
#endif
    
#if FOUNDATION_FRAMEWORK
    @Test func writeWithAttributes() throws {
        let writeData = generateTestData()
        
        // Data doesn't have a direct API to write with attributes, but our I/O code has it. Use it via @testable interface here.
        
        let writeAttrs: [String : Data] = [FileAttributeKey.hfsCreatorCode.rawValue : "abcd".data(using: .ascii)!]
        try writeToFile(path: .url(url), buffer: writeData.bytes, options: [], attributes: writeAttrs)
        
        // Verify attributes
        var readAttrs: [String : Data] = [:]
        let readData = try readDataFromFile(path: .url(url), reportProgress: false, options: [], attributesToRead: [FileAttributeKey.hfsCreatorCode.rawValue], attributes: &readAttrs)
        
        #expect(writeData == readData)
        #expect(writeAttrs == readAttrs)
    }
#endif
        
    @Test func emptyFile() throws {
        let data = Data()
        try data.write(to: url)
        let read = try Data(contentsOf: url, options: [])
        #expect(data == read)
    }
    
#if FOUNDATION_FRAMEWORK
    // String(contentsOf:) is not available outside the framework yet
    @available(*, deprecated)
    @Test func emptyFileString() throws {
        let data = Data()
        
        try data.write(to: url)
        let readString = try String(contentsOf: url)
        #expect(readString == "")
        
        let readStringWithEncoding = try String(contentsOf: url, encoding: .utf8)
        #expect(readStringWithEncoding == "")
    }
#endif
    
    #if os(Linux) || os(Windows)
    @Test
    #else
    @Test(.disabled("This test is not applicable on this platform"))
    #endif
    func writeToSpecialFile() throws {
        #if os(Windows)
        let path = URL(filePath: "CON", directoryHint: .notDirectory)
        #else
        let path = URL(filePath: "/dev/stdout", directoryHint: .notDirectory)
        #endif
        #expect(throws: Never.self) {
            try Data("Output to STDOUT\n".utf8).write(to: path)
        }
    }
    
    #if os(Linux) || os(Android)
    @Test
    #else
    @Test(.disabled("This test is not applicable on this platform"))
    #endif
    func zeroSizeFile() throws {
        // Some files in /proc report a file size of 0 bytes via a stat call
        // Ensure that these files can still be read despite appearing to be empty
        let maps = try String(contentsOfFile: "/proc/self/maps", encoding: .utf8)
        #expect(!maps.isEmpty)
    }

    @Test
    func atomicWrite() async throws {
        let data = generateTestData()

        await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 8 {
                group.addTask { [url] in
                    #expect(throws: Never.self) {
                        try data.write(to: url, options: [.atomic])
                    }
                }
            }
        }

        let readData = try Data(contentsOf: url, options: [])
        #expect(readData == data)
    }
}

extension LargeDataTests {
    // This test is placed in the LargeDataTests suite since it allocates an extremely large amount of memory for some devices
#if !os(watchOS)
    @Test func readLargeFile() throws {
        let url = URL.temporaryDirectory.appendingPathComponent("testfile-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: url) }
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
    }
#endif
}

