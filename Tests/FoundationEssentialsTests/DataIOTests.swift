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

#if canImport(Android)
import Android
#endif

#if canImport(Darwin)
import Darwin
#elseif canImport(Bionic)
import Bionic
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif os(WASI)
import WASILibc
#endif

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
    
    private static var isLinux: Bool {
        #if os(Linux)
        true
        #else
        false
        #endif
    }
    
    private static var isAndroid: Bool {
        #if os(Android)
        true
        #else
        false
        #endif
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

    #if !os(Emscripten)
    // Atomic writing is a very different code path
    @Test func readWriteAtomic() throws {
        // Perform an atomic write to a file that does not exist
        try writeAndVerifyTestData(to: url, writeOptions: [.atomic])

        // Perform an atomic write to a file that already exists
        try writeAndVerifyTestData(to: url, writeOptions: [.atomic])
    }
    #endif

#if !os(Windows) && !os(Emscripten)
    // The open-reader check uses POSIX descriptors; atomic writing is unavailable on Emscripten.
    @Test func atomicWriteInDestination() throws {
        try verifyAtomicReplacement { data, destination in
            try data.write(to: destination, options: .atomic)
        }
    }

    @Test func atomicStringPathWrite() throws {
        try verifyAtomicReplacement { data, destination in
            try String(decoding: data, as: UTF8.self).write(toFile: destination.path, atomically: true, encoding: .utf8)
        }
    }

    @Test func atomicStringURLWrite() throws {
        try verifyAtomicReplacement { data, destination in
            try String(decoding: data, as: UTF8.self).write(to: destination, atomically: true, encoding: .utf8)
        }
    }

    @Test func atomicCreateFile() throws {
        try verifyAtomicReplacement { data, destination in
            try #require(FileManager.default.createFile(atPath: destination.path, contents: data))
        }
    }

    private func verifyAtomicReplacement(_ write: (Data, URL) throws -> Void) throws {
        // Only the destination directory needs to be accessible, including in a WASI sandbox.
        let manager = FileManager.default
        let directory = URL(filePath: manager.currentDirectoryPath).appendingPathComponent(UUID().uuidString)
        try manager.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? manager.removeItem(at: directory) }

        let destination = directory.appendingPathComponent("data")
        var initial = Data()
        try write(initial, destination)
        #expect(try Data(contentsOf: destination).isEmpty)

        #if os(WASI)
        // FoundationEssentials also defines this flag for older WASI SDKs.
        let readOnly = WASILibc.O_RDONLY
        #else
        let readOnly = O_RDONLY
        #endif

        // Reading the destination alone cannot distinguish replacement from an in-place overwrite.
        for replacement in [Data("initial 🗽".utf8), Data("a longer replacement 🚉".utf8), Data("short".utf8), Data()] {
            let fd = destination.path.withCString { open($0, readOnly) }
            try #require(fd >= 0)
            defer { close(fd) }

            try write(replacement, destination)
            #expect(try Data(contentsOf: destination) == replacement)
            // The extra byte detects in-place growth, including overwriting an empty file.
            var original = Data(count: initial.count + 1)
            let count = original.withUnsafeMutableBytes { read(fd, $0.baseAddress, $0.count) }
            try #require(count >= 0)
            #expect(count == initial.count)
            #expect(original.prefix(count) == initial)
            #expect(try manager.contentsOfDirectory(atPath: directory.path) == ["data"])
            initial = replacement
        }
    }

#endif

#if !os(Emscripten)
    @Test func atomicWriteFailureCleansUp() throws {
        let manager = FileManager.default
        let directory = URL(filePath: manager.currentDirectoryPath).appendingPathComponent(UUID().uuidString)
        let destination = directory.appendingPathComponent("destination")
        try manager.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: directory) }

        let sentinel = destination.appendingPathComponent("sentinel")
        let initial = Data("keep".utf8)
        try initial.write(to: sentinel)

        // A file cannot replace a nonempty directory; its temporary sibling must be removed.
        #expect(throws: CocoaError.self) {
            try Data("replacement".utf8).write(to: destination, options: .atomic)
        }
        #expect(try Data(contentsOf: sentinel) == initial)
        #expect(try manager.contentsOfDirectory(atPath: directory.path) == ["destination"])
    }
#endif

#if os(Linux) && FOUNDATION_EXIT_TESTS
    @Test(.enabled(if: geteuid() != 0, "Root bypasses directory search permissions"))
    func atomicWriteWithUnsearchableCWD() async {
        // Isolate the working directory change from other tests in this process.
        await #expect(processExitsWith: .success) {
            let manager = FileManager.default
            let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let current = directory.appendingPathComponent("current")
            let destination = directory.appendingPathComponent("destination")
            try manager.createDirectory(at: current, withIntermediateDirectories: true)
            defer {
                try? manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: current.path)
                _ = manager.changeCurrentDirectoryPath("/")
                try? manager.removeItem(at: directory)
            }

            try #require(manager.changeCurrentDirectoryPath(current.path))
            try manager.setAttributes([.posixPermissions: 0o000], ofItemAtPath: current.path)

            try Data("initial".utf8).write(to: destination, options: .atomic)
            #expect(try Data(contentsOf: destination) == Data("initial".utf8))
            try Data("replacement".utf8).write(to: destination, options: .atomic)
            #expect(try Data(contentsOf: destination) == Data("replacement".utf8))
        }
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
        try writeToFile(path: url, buffer: writeData.bytes, options: [], attributes: writeAttrs)
        
        // Verify attributes
        var readAttrs: [String : Data] = [:]
        let readData = try readDataFromFile(path: url, reportProgress: false, options: [], attributesToRead: [FileAttributeKey.hfsCreatorCode.rawValue], attributes: &readAttrs)
        
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

    @Test(.enabled(if: isLinux || isAndroid, "This test is not applicable on this platform"))
    func zeroSizeFileReadsEntireContents() throws {
        // /proc/self/maps reports a size of 0, and read(2) can return fewer bytes than were asked for before reaching the end. The mappings are listed by ascending address and the main thread's stack sits at the top of the address space, so a read that stopped early does not reach it.
        let path = "/proc/self/maps"
        let reads = [
            ("Data(contentsOf:)", String(decoding: try Data(contentsOf: URL(fileURLWithPath: path)), as: UTF8.self)),
            ("String(contentsOfFile:)", try String(contentsOfFile: path, encoding: .utf8)),
            ("FileManager.contents(atPath:)", String(decoding: try #require(FileManager.default.contents(atPath: path)), as: UTF8.self)),
        ]
        for (api, maps) in reads {
            #expect(maps.contains("[stack]"), "\(api) stopped before the end of \(path)")
            #expect(maps.hasSuffix("\n"), "\(api) stopped before the end of \(path)")
        }
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

#if !os(WASI) && !os(Emscripten)
    // WASI and Emscripten do not support POSIX permissions.
    // Atomic writes must succeed when the destination is read-only.
    // On POSIX this is the behavior of rename(2). On Windows, SetFileInformationByHandle with FileRenameInfoEx returns ERROR_ACCESS_DENIED for a FILE_ATTRIBUTE_READONLY destination even with FILE_RENAME_FLAG_POSIX_SEMANTICS | FILE_RENAME_FLAG_REPLACE_IF_EXISTS. So the read-only attribute is cleared and the rename is retried.
    // The resulting file retains the read-only attribute. (Not yet on Windows).
    @Test
    func atomicWriteReplacesReadOnlyDestination() throws {
        let initial = Data("initial".utf8)
        let next = Data("next".utf8)

        try initial.write(to: url)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o400], // Read-only for owner
            ofItemAtPath: url.path
        )

        try next.write(to: url, options: [.atomic])

        let read = try Data(contentsOf: url)
        #expect(read == next)

#if !os(Windows)
        // Check mode bits directly. Testing by expecting `try later.write(to: url)` to throw would fail for root (e.g. in Linux CI containers), since root bypasses permission checks even on a read-only file.
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let mode = attributes[.posixPermissions] as? UInt ?? 0
        #expect(mode == 0o400)
#endif
    }
#endif
}

extension LargeDataTests {
    // This test is placed in the LargeDataTests suite since it allocates an extremely large amount of memory for some devices
    @Test func readLargeFile() throws {
        let url = URL.temporaryDirectory.appendingPathComponent("testfile-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: url) }
        // More than 2 GB, if not 32-bit
        #if _pointerBitWidth(_32)
        let size = 0x7FFFFFFF
        #else
        let size = 0x80010000
        #endif
        
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
}

