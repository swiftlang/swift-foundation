//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationEssentials)
@testable import FoundationEssentials
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#endif

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

import Testing

extension FileManager {
    fileprivate var delegateCaptures: DelegateCaptures {
        (self.delegate as! CapturingFileManagerDelegate).captures
    }
}

private struct DelegateCaptures : Equatable, Sendable {
    struct Operation : Equatable, CustomStringConvertible {
        let src: String
        let dst: String?
        
        var description: String {
            if let dst {
                "'\(src)' --> '\(dst)'"
            } else {
                "'\(src)'"
            }
        }
        
        init(_ src: String, _ dst: String? = nil) {
            self.src = src
            self.dst = dst
        }
    }
    
    struct ErrorOperation : Equatable, CustomStringConvertible {
        let op: Operation
        let code: CocoaError.Code?
        
        init(_ src: String, _ dst: String? = nil, code: CocoaError.Code?) {
            self.op = Operation(src, dst)
            self.code = code
        }
        
        var description: String {
            if let code {
                "\(op.description) {\(code.rawValue)}"
            } else {
                "\(op.description) {non-CocoaError}"
            }
        }
    }
    var shouldCopy: [Operation] = []
    var shouldProceedAfterCopyError: [ErrorOperation] = []
    var shouldMove: [Operation] = []
    var shouldProceedAfterMoveError: [ErrorOperation] = []
    var shouldLink: [Operation] = []
    var shouldProceedAfterLinkError: [ErrorOperation] = []
    var shouldRemove: [Operation] = []
    var shouldProceedAfterRemoveError: [ErrorOperation] = []
    
    var isEmpty: Bool {
        self == DelegateCaptures()
    }
}

#if FOUNDATION_FRAMEWORK
class CapturingFileManagerDelegate : NSObject, FileManagerDelegate, @unchecked Sendable {
    // Sendable note: This is only used on one thread during testing
    fileprivate nonisolated(unsafe) var captures = DelegateCaptures()
    
    func fileManager(_ fileManager: FileManager, shouldCopyItemAtPath srcPath: String, toPath dstPath: String) -> Bool {
        captures.shouldCopy.append(.init(srcPath, dstPath))
        return true
    }
    
    func fileManager(_ fileManager: FileManager, shouldProceedAfterError error: any Error, copyingItemAtPath srcPath: String, toPath dstPath: String) -> Bool {
        captures.shouldProceedAfterCopyError.append(.init(srcPath, dstPath, code: (error as? CocoaError)?.code))
        return true
    }
    
    func fileManager(_ fileManager: FileManager, shouldMoveItemAtPath srcPath: String, toPath dstPath: String) -> Bool {
        captures.shouldMove.append(.init(srcPath, dstPath))
        return true
    }
    
    func fileManager(_ fileManager: FileManager, shouldProceedAfterError error: any Error, movingItemAtPath srcPath: String, toPath dstPath: String) -> Bool {
        captures.shouldProceedAfterMoveError.append(.init(srcPath, dstPath, code: (error as? CocoaError)?.code))
        return true
    }
    
    func fileManager(_ fileManager: FileManager, shouldLinkItemAtPath srcPath: String, toPath dstPath: String) -> Bool {
        captures.shouldLink.append(.init(srcPath, dstPath))
        return true
    }
    
    func fileManager(_ fileManager: FileManager, shouldProceedAfterError error: any Error, linkingItemAtPath srcPath: String, toPath dstPath: String) -> Bool {
        captures.shouldProceedAfterLinkError.append(.init(srcPath, dstPath, code: (error as? CocoaError)?.code))
        return true
    }
    
    func fileManager(_ fileManager: FileManager, shouldRemoveItemAtPath path: String) -> Bool {
        captures.shouldRemove.append(.init(path))
        return true
    }
    
    func fileManager(_ fileManager: FileManager, shouldProceedAfterError error: any Error, removingItemAtPath path: String) -> Bool {
        captures.shouldProceedAfterRemoveError.append(DelegateCaptures.ErrorOperation(path, code: (error as? CocoaError)?.code))
        return true
    }
}
#else
final class CapturingFileManagerDelegate : FileManagerDelegate, Sendable {
    // Sendable note: This is only used on one thread during testing
    fileprivate nonisolated(unsafe) var captures = DelegateCaptures()
    
    func fileManager(_ fileManager: FileManager, shouldCopyItemAtPath srcPath: String, toPath dstPath: String) -> Bool {
        captures.shouldCopy.append(.init(srcPath, dstPath))
        return true
    }
    
    func fileManager(_ fileManager: FileManager, shouldProceedAfterError error: any Error, copyingItemAtPath srcPath: String, toPath dstPath: String) -> Bool {
        captures.shouldProceedAfterCopyError.append(.init(srcPath, dstPath, code: (error as? CocoaError)?.code))
        return true
    }
    
    func fileManager(_ fileManager: FileManager, shouldMoveItemAtPath srcPath: String, toPath dstPath: String) -> Bool {
        captures.shouldMove.append(.init(srcPath, dstPath))
        return true
    }
    
    func fileManager(_ fileManager: FileManager, shouldProceedAfterError error: any Error, movingItemAtPath srcPath: String, toPath dstPath: String) -> Bool {
        captures.shouldProceedAfterMoveError.append(.init(srcPath, dstPath, code: (error as? CocoaError)?.code))
        return true
    }
    
    func fileManager(_ fileManager: FileManager, shouldLinkItemAtPath srcPath: String, toPath dstPath: String) -> Bool {
        captures.shouldLink.append(.init(srcPath, dstPath))
        return true
    }
    
    func fileManager(_ fileManager: FileManager, shouldProceedAfterError error: any Error, linkingItemAtPath srcPath: String, toPath dstPath: String) -> Bool {
        captures.shouldProceedAfterLinkError.append(.init(srcPath, dstPath, code: (error as? CocoaError)?.code))
        return true
    }
    
    func fileManager(_ fileManager: FileManager, shouldRemoveItemAtPath path: String) -> Bool {
        captures.shouldRemove.append(.init(path))
        return true
    }
    
    func fileManager(_ fileManager: FileManager, shouldProceedAfterError error: any Error, removingItemAtPath path: String) -> Bool {
        captures.shouldProceedAfterRemoveError.append(DelegateCaptures.ErrorOperation(path, code: (error as? CocoaError)?.code))
        return true
    }
}
#endif

extension FilePlaygroundTests {
    struct FileManagerTests {
        private func randomData(count: Int = 10000) -> Data {
            Data((0 ..< count).map { _ in UInt8.random(in: .min ..< .max) })
        }
        
        @Test func testContentsAtPath() throws {
            let data = randomData()
            try playground {
                File("test", contents: data)
            }.test {
                #expect($0.contents(atPath: "test") == data)
            }
        }
        
        @Test func testContentsEqualAtPaths() throws {
            try playground {
                Directory("dir1") {
                    Directory("dir2") {
                        "Foo"
                        "Bar"
                    }
                    Directory("dir3") {
                        "Baz"
                    }
                }
                Directory("dir1_copy") {
                    Directory("dir2") {
                        "Foo"
                        "Bar"
                    }
                    Directory("dir3") {
                        "Baz"
                    }
                }
                Directory("dir1_diffdata") {
                    Directory("dir2") {
                        "Foo"
                        "Bar"
                    }
                    Directory("dir3") {
                        File("Baz", contents: randomData())
                    }
                }
                Directory("symlinks") {
                    File("Foo", contents: randomData())
                    SymbolicLink("LinkToFoo", destination: "Foo")
                }
                Directory("EmptyDirectory") {}
                "EmptyFile"
            }.test {
                #expect($0.contentsEqual(atPath: "dir1", andPath: "dir1_copy"))
                #expect(!$0.contentsEqual(atPath: "dir1/dir2", andPath: "dir1/dir3"))
                #expect(!$0.contentsEqual(atPath: "dir1", andPath: "dir1_diffdata"))
                #expect(!$0.contentsEqual(atPath: "symlinks/LinkToFoo", andPath: "symlinks/Foo"), "Symbolic link should not be equal to its destination")
                #expect(!$0.contentsEqual(atPath: "symlinks/LinkToFoo", andPath: "EmptyFile"), "Symbolic link should not be equal to an empty file")
                #expect(!$0.contentsEqual(atPath: "symlinks/LinkToFoo", andPath: "EmptyDirectory"), "Symbolic link should not be equal to an empty directory")
                #expect(!$0.contentsEqual(atPath: "symlinks/EmptyDirectory", andPath: "EmptyFile"), "Empty directory should not be equal to empty file")
            }
        }
        
        @Test func testDirectoryContentsAtPath() throws {
            try playground {
                Directory("dir1") {
                    Directory("dir2") {
                        "Foo"
                        "Bar"
                    }
                    Directory("dir3") {
                        "Baz"
                    }
                }
            }.test { fileManager in
                var contents = try fileManager.contentsOfDirectory(atPath: "dir1").sorted()
                #expect(contents == ["dir2", "dir3"])
                contents = try fileManager.contentsOfDirectory(atPath: "dir1/dir2").sorted()
                #expect(contents == ["Bar", "Foo"])
                contents = try fileManager.contentsOfDirectory(atPath: "dir1/dir3").sorted()
                #expect(contents == ["Baz"])
                #expect {
                    try fileManager.contentsOfDirectory(atPath: "does_not_exist")
                } throws: {
                    ($0 as? CocoaError)?.code == .fileReadNoSuchFile
                }
            }
        }
        
        @Test func testSubpathsOfDirectoryAtPath() throws {
            try playground {
                Directory("dir1") {
                    Directory("dir2") {
                        "Foo"
                        "Bar"
                    }
                    Directory("dir3") {
                        "Baz"
                    }
                }
                Directory("symlinks") {
                    "Foo"
                    SymbolicLink("Bar", destination: "Foo")
                    SymbolicLink("Parent", destination: "..")
                }
            }.test { fileManager in
                var subpaths = try fileManager.subpathsOfDirectory(atPath: "dir1").sorted()
                #expect(subpaths == ["dir2", "dir2/Bar", "dir2/Foo", "dir3", "dir3/Baz"])
                subpaths = try fileManager.subpathsOfDirectory(atPath: "dir1/dir2").sorted()
                #expect(subpaths == ["Bar", "Foo"])
                subpaths = try fileManager.subpathsOfDirectory(atPath: "dir1/dir3").sorted()
                #expect(subpaths == ["Baz"])
                
                subpaths = try fileManager.subpathsOfDirectory(atPath: "symlinks").sorted()
                #expect(subpaths == ["Bar", "Foo", "Parent"])
                
                #expect {
                    try fileManager.subpathsOfDirectory(atPath: "does_not_exist")
                } throws: {
                    ($0 as? CocoaError)?.code == .fileReadNoSuchFile
                }

                #expect {
                    try fileManager.subpathsOfDirectory(atPath: "")
                } throws: {
                    #if os(Windows)
                    ($0 as? CocoaError)?.code == .fileReadInvalidFileName
                    #else
                    ($0 as? CocoaError)?.code == .fileReadNoSuchFile
                    #endif
                }
                
                let fullContents = ["dir1", "dir1/dir2", "dir1/dir2/Bar", "dir1/dir2/Foo", "dir1/dir3", "dir1/dir3/Baz", "symlinks", "symlinks/Bar", "symlinks/Foo", "symlinks/Parent"]
                let cwd = fileManager.currentDirectoryPath
                #expect(cwd.last != "/")
                let paths = [cwd, "\(cwd)/", "\(cwd)//", ".", "./", ".//"]
                for path in paths {
                    #expect(try fileManager.subpathsOfDirectory(atPath: path).sorted() == fullContents)
                }
                
            }
        }
        
        @Test func testCreateDirectoryAtPath() throws {
            try playground {
                "preexisting_file"
            }.test { fileManager in
                try fileManager.createDirectory(atPath: "create_dir_test", withIntermediateDirectories: false)
                #expect(try fileManager.contentsOfDirectory(atPath: ".").sorted() == ["create_dir_test", "preexisting_file"])
                try fileManager.createDirectory(atPath: "create_dir_test2/nested", withIntermediateDirectories: true)
                #expect(try fileManager.contentsOfDirectory(atPath: "create_dir_test2") == ["nested"])
                try fileManager.createDirectory(atPath: "create_dir_test2/nested2", withIntermediateDirectories: true)
                #expect(try fileManager.contentsOfDirectory(atPath: "create_dir_test2").sorted() == ["nested", "nested2"])
                #expect(throws: Never.self) {
                    try fileManager.createDirectory(atPath: "create_dir_test2/nested2", withIntermediateDirectories: true)
                }
                
                #if os(Windows)
                try fileManager.createDirectory(atPath: "create_dir_test3\\nested", withIntermediateDirectories: true)
                #expect(try fileManager.contentsOfDirectory(atPath: "create_dir_test3") == ["nested"])
                #endif
                
                #expect {
                    try fileManager.createDirectory(atPath: "create_dir_test", withIntermediateDirectories: false)
                } throws: {
                    ($0 as? CocoaError)?.code == .fileWriteFileExists
                }
                #expect {
                    try fileManager.createDirectory(atPath: "create_dir_test4/nested", withIntermediateDirectories: false)
                } throws: {
                    ($0 as? CocoaError)?.code == .fileNoSuchFile
                }
                #expect {
                    try fileManager.createDirectory(atPath: "preexisting_file", withIntermediateDirectories: false)
                } throws: {
                    ($0 as? CocoaError)?.code == .fileWriteFileExists
                }
                #expect {
                    try fileManager.createDirectory(atPath: "preexisting_file", withIntermediateDirectories: true)
                } throws: {
                    ($0 as? CocoaError)?.code == .fileWriteFileExists
                }
            }
        }
        
        @Test func testLinkFileAtPathToPath() throws {
            try playground {
                "foo"
            }.test(captureDelegateCalls: true) {
                try #require($0.delegateCaptures.isEmpty)
                try $0.linkItem(atPath: "foo", toPath: "bar")
                #expect($0.delegateCaptures.shouldLink == [.init("foo", "bar")])
                #expect($0.delegateCaptures.shouldProceedAfterLinkError.isEmpty)
                #expect($0.fileExists(atPath: "bar"))
            }
            
            try playground {
                "foo"
                "bar"
            }.test(captureDelegateCalls: true) {
                try #require($0.delegateCaptures.isEmpty)
                try $0.linkItem(atPath: "foo", toPath: "bar")
                #expect($0.delegateCaptures.shouldLink == [.init("foo", "bar")])
                #expect($0.delegateCaptures.shouldProceedAfterLinkError == [.init("foo", "bar", code: .fileWriteFileExists)])
            }
        }
        
        @Test func testCopyFileAtPathToPath() throws {
            try playground {
                "foo"
            }.test(captureDelegateCalls: true) {
                try #require($0.delegateCaptures.isEmpty)
                try $0.copyItem(atPath: "foo", toPath: "bar")
                #expect($0.delegateCaptures.shouldCopy == [.init("foo", "bar")])
                #expect($0.delegateCaptures.shouldProceedAfterCopyError.isEmpty)
                #expect($0.fileExists(atPath: "bar"))
            }
            
            try playground {
                "foo"
                "bar"
            }.test(captureDelegateCalls: true) {
                try #require($0.delegateCaptures.isEmpty)
                try $0.copyItem(atPath: "foo", toPath: "bar")
                #expect($0.delegateCaptures.shouldCopy == [.init("foo", "bar")])
                #expect($0.delegateCaptures.shouldProceedAfterCopyError == [.init("foo", "bar", code: .fileWriteFileExists)])
            }
            
            try playground {
                "foo"
                SymbolicLink("bar", destination: "foo")
            }.test(captureDelegateCalls: true) {
                try #require($0.delegateCaptures.isEmpty)
                try $0.copyItem(atPath: "bar", toPath: "copy")
                #expect($0.delegateCaptures.shouldCopy == [.init("bar", "copy")])
                #expect($0.delegateCaptures.shouldProceedAfterCopyError.isEmpty)
                let copyDestination = try $0.destinationOfSymbolicLink(atPath: "copy")
                #expect(copyDestination.lastPathComponent == "foo", "Copied symbolic link points at \(copyDestination) instead of foo")
            }

            try playground {
                Directory("dir") {
                    "foo"
                }
                SymbolicLink("link", destination: "dir")
            }.test(captureDelegateCalls: true) {
                try #require($0.delegateCaptures.isEmpty)
                try $0.copyItem(atPath: "link", toPath: "copy")
                #expect($0.delegateCaptures.shouldCopy == [.init("link", "copy")])
                #expect($0.delegateCaptures.shouldProceedAfterCopyError.isEmpty)
                let copyDestination = try $0.destinationOfSymbolicLink(atPath: "copy")
                #expect(copyDestination.lastPathComponent == "dir", "Copied symbolic link points at \(copyDestination) instead of foo")
            }
        }
        
        @Test func testCreateSymbolicLinkAtPath() throws {
            try playground {
                "foo"
            }.test { fileManager in
                try fileManager.createSymbolicLink(atPath: "bar", withDestinationPath: "foo")
                #expect(try fileManager.destinationOfSymbolicLink(atPath: "bar") == "foo")
                
                #expect {
                    try fileManager.createSymbolicLink(atPath: "bar", withDestinationPath: "foo")
                } throws: {
                    ($0 as? CocoaError)?.code == .fileWriteFileExists
                }
                #expect {
                    try fileManager.createSymbolicLink(atPath: "foo", withDestinationPath: "baz")
                } throws: {
                    ($0 as? CocoaError)?.code == .fileWriteFileExists
                }
                #expect {
                    try fileManager.destinationOfSymbolicLink(atPath: "foo")
                } throws: {
                    ($0 as? CocoaError)?.code == .fileReadUnknown
                }
            }
        }
        
        @Test func testMoveItemAtPathToPath() throws {
            let data = randomData()
            try playground {
                Directory("dir") {
                    File("foo", contents: data)
                    "bar"
                }
                "other_file"
            }.test(captureDelegateCalls: true) {
                try #require($0.delegateCaptures.isEmpty)
                try $0.moveItem(atPath: "dir", toPath: "dir2")
                #expect(try $0.subpathsOfDirectory(atPath: ".").sorted() == ["dir2", "dir2/bar", "dir2/foo", "other_file"])
                #expect($0.contents(atPath: "dir2/foo") == data)

                let rootDir = URL(fileURLWithPath: $0.currentDirectoryPath).path
                #expect($0.delegateCaptures.shouldMove == [.init("\(rootDir)/dir", "\(rootDir)/dir2")])

                try $0.moveItem(atPath: "does_not_exist", toPath: "dir3")
                #expect($0.delegateCaptures.shouldProceedAfterMoveError == [.init("\(rootDir)/does_not_exist", "\(rootDir)/dir3", code: .fileNoSuchFile)])

                try $0.moveItem(atPath: "dir2", toPath: "other_file")
                #expect($0.delegateCaptures.shouldProceedAfterMoveError.contains(.init("\(rootDir)/dir2", "\(rootDir)/other_file", code: .fileWriteFileExists)))
            }
        }
        
        @Test func testCopyItemAtPathToPath() throws {
            let data = randomData()
            try playground {
                Directory("dir") {
                    File("foo", contents: data)
                    "bar"
                }
                "other_file"
            }.test(captureDelegateCalls: true) { fileManager in
                try #require(fileManager.delegateCaptures.isEmpty)
                try fileManager.copyItem(atPath: "dir", toPath: "dir2")
                #expect(try fileManager.subpathsOfDirectory(atPath: ".").sorted() == ["dir", "dir/bar", "dir/foo", "dir2", "dir2/bar", "dir2/foo", "other_file"])
                #expect(fileManager.contents(atPath: "dir/foo") == data)
                #expect(fileManager.contents(atPath: "dir2/foo") == data)
    #if os(Windows)
                #expect(fileManager.delegateCaptures.shouldCopy == [.init("dir", "dir2"), .init("dir/bar", "dir2/bar"), .init("dir/foo", "dir2/foo")])
    #else
                #expect(fileManager.delegateCaptures.shouldCopy == [.init("dir", "dir2"), .init("dir/foo", "dir2/foo"), .init("dir/bar", "dir2/bar")])
    #endif

                #expect {
                    try fileManager.copyItem(atPath: "does_not_exist", toPath: "dir3")
                } throws: {
                    ($0 as? CocoaError)?.code == .fileReadNoSuchFile
                }
                
                try fileManager.copyItem(atPath: "dir", toPath: "other_file")
                #expect(fileManager.delegateCaptures.shouldProceedAfterCopyError.contains(.init("dir", "other_file", code: .fileWriteFileExists)))
            }
        }
        
        @Test func testRemoveItemAtPath() throws {
            try playground {
                Directory("dir") {
                    "foo"
                    "bar"
                }
                "other"
            }.test(captureDelegateCalls: true) {
                try #require($0.delegateCaptures.isEmpty)
                try $0.removeItem(atPath: "dir/bar")
                #expect(try $0.subpathsOfDirectory(atPath: ".").sorted() == ["dir", "dir/foo", "other"])
                #expect($0.delegateCaptures.shouldRemove == [.init("dir/bar")])
                #expect($0.delegateCaptures.shouldProceedAfterRemoveError.isEmpty)

                let rootDir = URL(fileURLWithPath: $0.currentDirectoryPath).path
                try $0.removeItem(atPath: "dir")
                #expect(try $0.subpathsOfDirectory(atPath: ".").sorted() == ["other"])
                #expect($0.delegateCaptures.shouldRemove == [.init("dir/bar"), .init("\(rootDir)/dir"), .init("\(rootDir)/dir/foo")])
                #expect($0.delegateCaptures.shouldProceedAfterRemoveError.isEmpty)
                
                try $0.removeItem(atPath: "other")
                #expect(try $0.subpathsOfDirectory(atPath: ".").sorted() == [])
                #expect($0.delegateCaptures.shouldRemove == [.init("dir/bar"), .init("\(rootDir)/dir"), .init("\(rootDir)/dir/foo"), .init("other")])
                #expect($0.delegateCaptures.shouldProceedAfterRemoveError.isEmpty)
                
                try $0.removeItem(atPath: "does_not_exist")
                #expect($0.delegateCaptures.shouldRemove == [.init("dir/bar"), .init("\(rootDir)/dir"), .init("\(rootDir)/dir/foo"), .init("other"), .init("does_not_exist")])
                #expect($0.delegateCaptures.shouldProceedAfterRemoveError == [.init("does_not_exist", code: .fileNoSuchFile)])
            }

            try playground {
                Directory("dir") {
                    Directory("dir2") {
                        "file"
                    }
                }
            }.test(captureDelegateCalls: true) {
                let rootDir = URL(fileURLWithPath: $0.currentDirectoryPath).path

                try #require($0.delegateCaptures.isEmpty)
                try $0.removeItem(atPath: "dir")
                #expect(try $0.subpathsOfDirectory(atPath: ".").isEmpty)
                #expect($0.delegateCaptures.shouldRemove == [.init("\(rootDir)/dir"), .init("\(rootDir)/dir/dir2"), .init("\(rootDir)/dir/dir2/file")])
                #expect($0.delegateCaptures.shouldProceedAfterRemoveError.isEmpty)
            }

            #if canImport(Darwin)
            // not supported on linux as the test depends on FileManager.removeItem calling removefile(3)
            // not supported on older versions of Darwin where removefile would return ENOENT instead of ENAMETOOLONG
            if #available(macOS 14.4, iOS 17.0, watchOS 10.0, tvOS 17.0, *) {
                try playground {
                }.test { fileManager in
                    // Create hierarchy in which the leaf is a long path (length > PATH_MAX)
                    let rootDir = fileManager.currentDirectoryPath
                    let aas = Array(repeating: "a", count: Int(NAME_MAX) - 3).joined()
                    let bbs = Array(repeating: "b", count: Int(NAME_MAX) - 3).joined()
                    let ccs = Array(repeating: "c", count: Int(NAME_MAX) - 3).joined()
                    let dds = Array(repeating: "d", count: Int(NAME_MAX) - 3).joined()
                    let ees = Array(repeating: "e", count: Int(NAME_MAX) - 3).joined()
                    let leaf = "longpath"
                    
                    try fileManager.createDirectory(atPath: aas, withIntermediateDirectories: true)
                    #expect(fileManager.changeCurrentDirectoryPath(aas))
                    try fileManager.createDirectory(atPath: bbs, withIntermediateDirectories: true)
                    #expect(fileManager.changeCurrentDirectoryPath(bbs))
                    try fileManager.createDirectory(atPath: ccs, withIntermediateDirectories: true)
                    #expect(fileManager.changeCurrentDirectoryPath(ccs))
                    try fileManager.createDirectory(atPath: dds, withIntermediateDirectories: true)
                    #expect(fileManager.changeCurrentDirectoryPath(dds))
                    try fileManager.createDirectory(atPath: ees, withIntermediateDirectories: true)
                    #expect(fileManager.changeCurrentDirectoryPath(ees))
                    try fileManager.createDirectory(atPath: leaf, withIntermediateDirectories: true)
                    
                    #expect(fileManager.changeCurrentDirectoryPath(rootDir))
                    let fullPath = "\(aas)/\(bbs)/\(ccs)/\(dds)/\(ees)/\(leaf)"
                    #expect {
                        try fileManager.removeItem(atPath: fullPath)
                    } throws: {
                        let underlyingPosixError = ($0 as? CocoaError)?.underlying as? POSIXError
                        return underlyingPosixError?.code == .ENAMETOOLONG
                    }
                    
                    // Clean up
                    #expect(fileManager.changeCurrentDirectoryPath(aas))
                    #expect(fileManager.changeCurrentDirectoryPath(bbs))
                    #expect(fileManager.changeCurrentDirectoryPath(ccs))
                    #expect(fileManager.changeCurrentDirectoryPath(dds))
                    try fileManager.removeItem(atPath: ees)
                    #expect(fileManager.changeCurrentDirectoryPath(".."))
                    try fileManager.removeItem(atPath: dds)
                    #expect(fileManager.changeCurrentDirectoryPath(".."))
                    try fileManager.removeItem(atPath: ccs)
                    #expect(fileManager.changeCurrentDirectoryPath(".."))
                    try fileManager.removeItem(atPath: bbs)
                    #expect(fileManager.changeCurrentDirectoryPath(".."))
                    try fileManager.removeItem(atPath: aas)
                }
            }
            #endif
        }
        
        @Test func testFileExistsAtPath() throws {
            try playground {
                Directory("dir") {
                    "foo"
                    "bar"
                }
                "other"
                SymbolicLink("link_to_file", destination: "other")
                SymbolicLink("link_to_dir", destination: "dir")
                SymbolicLink("link_to_nonexistent", destination: "does_not_exist")
            }.test {
                #if FOUNDATION_FRAMEWORK
                var isDir: ObjCBool = false
                func isDirBool() -> Bool {
                    isDir.boolValue
                }
                #else
                var isDir: Bool = false
                func isDirBool() -> Bool {
                    isDir
                }
                #endif
                #expect($0.fileExists(atPath: "dir/foo", isDirectory: &isDir))
                #expect(!isDirBool())
                #expect($0.fileExists(atPath: "dir/bar", isDirectory: &isDir))
                #expect(!isDirBool())
                #expect($0.fileExists(atPath: "dir", isDirectory: &isDir))
                #expect(isDirBool())
                #expect($0.fileExists(atPath: "other", isDirectory: &isDir))
                #expect(!isDirBool())
                #expect($0.fileExists(atPath: "link_to_file", isDirectory: &isDir))
                #expect(!isDirBool())
                #expect($0.fileExists(atPath: "link_to_dir", isDirectory: &isDir))
                #expect(isDirBool())
                #expect(!$0.fileExists(atPath: "does_not_exist"))
                #expect(!$0.fileExists(atPath: "link_to_nonexistent"))
            }
        }
        
        static var isPOSIXRoot: Bool {
            #if os(Windows)
            return false
            #else
            return getuid() == 0
            #endif
        }
        
        
        // Root users can always access anything, so this test will not function when run as root
        @Test(.disabled(if: isPOSIXRoot, "This test is not available when running as the root user"))
        func testFileAccessAtPath() throws {
            try playground {
                File("000", attributes: [.posixPermissions: 0o000])
                File("111", attributes: [.posixPermissions: 0o111])
                File("222", attributes: [.posixPermissions: 0o222])
                File("333", attributes: [.posixPermissions: 0o333])
                File("444", attributes: [.posixPermissions: 0o444])
                File("555", attributes: [.posixPermissions: 0o555])
                File("666", attributes: [.posixPermissions: 0o666])
                File("777", attributes: [.posixPermissions: 0o777])
            }.test {
                #if os(Windows)
                // All files are readable on Windows
                let readable = ["000", "111", "222", "333", "444", "555", "666", "777"]
                // None of these files are executable on Windows
                let executable: [String] = []
                #else
                let readable = ["444", "555", "666", "777"]
                let executable = ["111", "333", "555", "777"]
                #endif
                let writable = ["222", "333", "666", "777"]
                for number in 0...7 {
                    let file = "\(number)\(number)\(number)"
                    #expect($0.isReadableFile(atPath: file) == readable.contains(file), "'\(file)' failed readable check")
                    #expect($0.isWritableFile(atPath: file) == writable.contains(file), "'\(file)' failed writable check")
                    #expect($0.isExecutableFile(atPath: file) == executable.contains(file), "'\(file)' failed executable check")
                    #if os(Windows)
                    // Only writable files are deletable on Windows
                    #expect($0.isDeletableFile(atPath: file) == writable.contains(file), "'\(file)' failed deletable check")
                    #else
                    #expect($0.isDeletableFile(atPath: file), "'\(file)' failed deletable check")
                    #endif
                }
            }
        }

        @Test func testFileSystemAttributesAtPath() throws {
            try playground {
                "Foo"
            }.test { fileManager in
                let dict = try fileManager.attributesOfFileSystem(forPath: "Foo")
                #expect(dict[.systemSize] != nil)
                #expect {
                    try fileManager.attributesOfFileSystem(forPath: "does_not_exist")
                } throws: {
                    ($0 as? CocoaError)?.code == .fileReadNoSuchFile
                }
            }
        }
        
        @Test func testCurrentWorkingDirectory() throws {
            try playground {
                Directory("dir") {
                    "foo"
                }
                "bar"
            }.test {
                var subpaths = try $0.subpathsOfDirectory(atPath: ".").sorted()
                #expect(subpaths == ["bar", "dir", "dir/foo"])
                #expect($0.changeCurrentDirectoryPath("dir"))
                subpaths = try $0.subpathsOfDirectory(atPath: ".").sorted()
                #expect(subpaths == ["foo"])
                #expect(!$0.changeCurrentDirectoryPath("foo"))
                #expect($0.changeCurrentDirectoryPath(".."))
                subpaths = try $0.subpathsOfDirectory(atPath: ".").sorted()
                #expect(subpaths == ["bar", "dir", "dir/foo"])
                #expect(!$0.changeCurrentDirectoryPath("does_not_exist"))
            }
        }
        
        static var hasImmutableAppendOnlyAttributes: Bool {
            #if canImport(Darwin)
            true
            #else
            false
            #endif
        }
        
        @Test(.disabled(if: !hasImmutableAppendOnlyAttributes, "This test is only applicable on platforms that support the .immutable & .appendOnly attributes"))
        func testBooleanFileAttributes() throws {
            try playground {
                "none"
                File("immutable", attributes: [.immutable: true])
                File("appendOnly", attributes: [.appendOnly: true])
                File("immutable_appendOnly", attributes: [.immutable: true, .appendOnly: true])
            }.test {
                let tests: [(path: String, immutable: Bool, appendOnly: Bool)] = [
                    ("none", false, false),
                    ("immutable", true, false),
                    ("appendOnly", false, true),
                    ("immutable_appendOnly", true, true)
                ]
                
                for test in tests {
                    let result = try $0.attributesOfItem(atPath: test.path)
                    #expect(result[.immutable] as? Bool == test.immutable, "Item at path '\(test.path)' did not provide expected result for immutable key")
                    #expect(result[.appendOnly] as? Bool == test.appendOnly, "Item at path '\(test.path)' did not provide expected result for appendOnly key")
                    
                    #expect(result[.busy] == nil, "Item at path '\(test.path)' has non-nil value for .busy attribute") // Should only be set when true
                    
                    // Manually clean up attributes so removal does not fail
                    try $0.setAttributes([.immutable: false, .appendOnly: false], ofItemAtPath: test.path)
                }
            }
        }
        
        @Test func testMalformedModificationDateAttribute() throws {
            let sentinelDate = Date(timeIntervalSince1970: 100)
            try playground {
                File("foo", attributes: [.modificationDate: sentinelDate])
            }.test {
                #expect(try $0.attributesOfItem(atPath: "foo")[.modificationDate] as? Date == sentinelDate)
                for value in [Double.infinity, -Double.infinity, Double.nan] {
                    // Malformed modification dates should be dropped instead of throwing or crashing
                    try $0.setAttributes([.modificationDate : Date(timeIntervalSince1970: value)], ofItemAtPath: "foo")
                }
                #expect(try $0.attributesOfItem(atPath: "foo")[.modificationDate] as? Date == sentinelDate)
            }
        }
        
        @Test func testImplicitlyConvertibleFileAttributes() throws {
            try playground {
                File("foo", attributes: [.posixPermissions : UInt16(0o644)])
            }.test {
                let attributes = try $0.attributesOfItem(atPath: "foo")

                // Ensure the unconventional UInt16 was accepted as input
                #if os(Windows)
                #expect(attributes[.posixPermissions] as? UInt == 0o600)
                #else
                #expect(attributes[.posixPermissions] as? UInt == 0o644)
                #endif

                #if FOUNDATION_FRAMEWORK
                // Where we have NSNumber, ensure that we can get the value back as an unconventional Double value
                #expect(attributes[.posixPermissions] as? Double == Double(0o644))
                // Ensure that the file type can be converted to a String when it is an ObjC enum
                #expect(attributes[.type] as? String == FileAttributeType.typeRegular.rawValue)
                #endif

                // Ensure that the file type can be converted to a FileAttributeType when it is an ObjC enum and in swift-foundation
                #expect(attributes[.type] as? FileAttributeType == .typeRegular)
                
            }
        }
        
        #if !canImport(Darwin)
        @Test(.disabled("This test is only applicable on Darwin platforms"))
        #else
        @Test
        #endif
        func testStandardizingPathAutomount() throws {
            let tests = [
                "/private/System" : "/private/System",
                "/private/tmp" : "/tmp",
                "/private/System/foo" : "/private/System/foo"
            ]
            for (input, expected) in tests {
                #expect(input.standardizingPath == expected)
            }
        }
        
        #if !canImport(Darwin)
        @Test(.disabled("This test is only applicable on Darwin platforms"))
        #else
        @Test
        #endif
        func testResolveSymlinksViaGetAttrList() throws {
            try playground {
                "destination"
            }.test {
                try $0.createSymbolicLink(atPath: "link", withDestinationPath: "destination")
                let absolutePath = $0.currentDirectoryPath.appendingPathComponent("link")
                let resolved = absolutePath._resolvingSymlinksInPath() // Call internal function to avoid path standardization
                #expect(resolved == $0.currentDirectoryPath.appendingPathComponent("destination"))
            }
        }
        
        #if os(macOS) && FOUNDATION_FRAMEWORK
        @Test func testSpecialTrashDirectoryTruncation() throws {
            try playground {}.test {
                if let trashURL = try? $0.url(for: .trashDirectory, in: .allDomainsMask, appropriateFor: nil, create: false) {
                    #expect(trashURL.pathComponents.last == ".Trash")
                }
            }
        }
        #endif
        
        @Test func testSearchPaths() throws {
            func assertSearchPaths(_ directories: [FileManager.SearchPathDirectory], exists: Bool, sourceLocation: SourceLocation = #_sourceLocation) {
                for directory in directories {
                    let paths = FileManager.default.urls(for: directory, in: .allDomainsMask)
                    #expect(!paths.isEmpty == exists, "Directory \(directory) produced an unexpected number of paths", sourceLocation: sourceLocation)
                }
            }
            
            // Cross platform paths that always exist
            assertSearchPaths([
                .userDirectory,
                .documentDirectory,
                .autosavedInformationDirectory,
                .autosavedInformationDirectory,
                .desktopDirectory,
                .cachesDirectory,
                .applicationSupportDirectory,
                .downloadsDirectory,
                .moviesDirectory,
                .musicDirectory,
                .sharedPublicDirectory
            ], exists: true)
            
            #if canImport(Darwin)
            let isDarwin = true
            #else
            let isDarwin = false
            #endif
            
            // Darwin-only paths
            assertSearchPaths([
                .applicationDirectory,
                .demoApplicationDirectory,
                .developerApplicationDirectory,
                .adminApplicationDirectory,
                .libraryDirectory,
                .developerDirectory,
                .documentationDirectory,
                .coreServiceDirectory,
                .inputMethodsDirectory,
                .preferencePanesDirectory,
                .allApplicationsDirectory,
                .allLibrariesDirectory,
                .printerDescriptionDirectory
            ], exists: isDarwin)
            
            #if os(macOS)
            let isMacOS = true
            #else
            let isMacOS = false
            #endif
            
            #if FOUNDATION_FRAMEWORK
            let isFramework = true
            #else
            let isFramework = false
            #endif

            #if os(Windows)
            let isWindows = true
            #else
            let isWindows = false
            #endif
            
            // .trashDirectory is unavailable on watchOS/tvOS and only produces paths on macOS (the framework build) + non-Darwin
            #if !os(watchOS) && !os(tvOS)
            assertSearchPaths([.trashDirectory], exists: (isMacOS && isFramework) || (!isDarwin && !isWindows))
            #endif

            // .picturesDirectory does not exist in CI, though it does exist in user
            // desktop scenarios.
            #if !os(Windows)
            assertSearchPaths([.picturesDirectory], exists: true)
            #endif
            
            // .applicationScriptsDirectory is only available on macOS and only produces paths in the framework build
            #if os(macOS)
            assertSearchPaths([.applicationScriptsDirectory], exists: isFramework)
            #endif
            
            // .itemReplacementDirectory never exists
            assertSearchPaths([.itemReplacementDirectory], exists: false)
        }
        
        #if !canImport(Darwin) && !os(Windows)
        static var environmentHasXDGVariable: Bool {
            ProcessInfo.processInfo.environment.keys.contains { $0.starts(with: "XDG")
            }
        }
        
        @Test(.disabled(if: environmentHasXDGVariable, "Skipping due to presence of XDG environment variable which may affect this test"))
        func testSearchPaths_XDGEnvironmentVariables() throws {
            try playground {
                Directory("TestPath") {}
            }.test { fileManager in
                func validate(_ key: String, suffix: String? = nil, directory: FileManager.SearchPathDirectory, domain: FileManager.SearchPathDomainMask, sourceLocation: SourceLocation = #_sourceLocation) {
                    let oldValue = ProcessInfo.processInfo.environment[key] ?? ""
                    var knownPath = fileManager.currentDirectoryPath.appendingPathComponent("TestPath")
                    setenv(key, knownPath, 1)
                    defer { setenv(key, oldValue, 1) }
                    if let suffix {
                        // The suffix is not stored in the environment variable, it is just applied to the expectation
                        knownPath = knownPath.appendingPathComponent(suffix)
                    }
                    let knownURL = URL(filePath: knownPath, directoryHint: .isDirectory)
                    let results = fileManager.urls(for: directory, in: domain)
                    #expect(results.contains(knownURL), "Results \(results.map(\.path)) did not contain known directory \(knownURL.path) for \(directory)/\(domain) while setting the \(key) environment variable", sourceLocation: sourceLocation)
                }

                validate("XDG_DATA_HOME", suffix: "Autosave Information", directory: .autosavedInformationDirectory, domain: .userDomainMask)
                validate("HOME", suffix: ".local/share/Autosave Information", directory: .autosavedInformationDirectory, domain: .userDomainMask)

                validate("XDG_CACHE_HOME", directory: .cachesDirectory, domain: .userDomainMask)
                validate("HOME", suffix: ".cache", directory: .cachesDirectory, domain: .userDomainMask)
                
                validate("XDG_DATA_HOME", directory: .applicationSupportDirectory, domain: .userDomainMask)
                validate("HOME", suffix: ".local/share", directory: .applicationSupportDirectory, domain: .userDomainMask)
                
                validate("HOME", directory: .userDirectory, domain: .localDomainMask)
            }
        }
        #endif
        
        @Test func testGetSetAttributes() throws {
            try playground {
                File("foo", contents: randomData())
            }.test { fileManager in
                #expect(throws: Never.self) {
                    let attrs = try fileManager.attributesOfItem(atPath: "foo")
                    try fileManager.setAttributes(attrs, ofItemAtPath: "foo")
                }
            }
        }

        #if !canImport(Darwin) || os(macOS)
        @Test func testCurrentUserHomeDirectory() throws {
            let userName = ProcessInfo.processInfo.userName
            #expect(FileManager.default.homeDirectory(forUser: userName) == FileManager.default.homeDirectoryForCurrentUser)
        }
        #endif
        
        @Test func testAttributesOfItemAtPath() throws {
            try playground {
                "file"
                File("fileWithContents", contents: randomData())
                Directory("directory") {
                    "file"
                }
            }.test {
                do {
                    let attrs = try $0.attributesOfItem(atPath: "file")
                    #expect(attrs[.size] as? UInt == 0)
                    #expect(attrs[.type] as? FileAttributeType == .typeRegular)
                }
                
                do {
                    let attrs = try $0.attributesOfItem(atPath: "fileWithContents")
                    #expect(try #require(attrs[.size] as? UInt) > 0)
                    #expect(attrs[.type] as? FileAttributeType == .typeRegular)
                }
                
                do {
                    let attrs = try $0.attributesOfItem(atPath: "directory")
                    #expect(attrs[.type] as? FileAttributeType == .typeDirectory)
                }
                
                do {
                    try $0.createSymbolicLink(atPath: "symlink", withDestinationPath: "file")
                    let attrs = try $0.attributesOfItem(atPath: "symlink")
                    #expect(attrs[.type] as? FileAttributeType == .typeSymbolicLink)
                }
            }
        }
        
        #if !canImport(Darwin) || os(macOS)
        @Test func testHomeDirectoryForNonExistantUser() throws {
            #if os(Windows)
            let fallbackPath = URL(filePath: try #require(ProcessInfo.processInfo.environment["ALLUSERSPROFILE"]), directoryHint: .isDirectory)
            #else
            let fallbackPath = URL(filePath: "/var/empty", directoryHint: .isDirectory)
            #endif
            
            #expect(FileManager.default.homeDirectory(forUser: "") == fallbackPath)
            #expect(FileManager.default.homeDirectory(forUser: UUID().uuidString) == fallbackPath)
        }
    #endif
    }
}
