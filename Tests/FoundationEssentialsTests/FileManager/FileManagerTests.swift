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


#if canImport(TestSupport)
import TestSupport
#endif // canImport(TestSupport)

#if canImport(FoundationEssentials)
@testable import FoundationEssentials
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#endif

#if canImport(Android)
import Android
#endif

extension FileManager {
    fileprivate var delegateCaptures: DelegateCaptures {
        (self.delegate as! CapturingFileManagerDelegate).captures
    }
}

private struct DelegateCaptures : Equatable, Sendable {
    struct Operation : Equatable, CustomStringConvertible, Comparable {
        let src: String
        let dst: String?
        
        var description: String {
            if let dst {
                "'\(src)' --> '\(dst)'"
            } else {
                "'\(src)'"
            }
        }

        static func <(lhs: Operation, rhs: Operation) -> Bool {
          lhs.src < rhs.src || lhs.dst == nil || (rhs.dst != nil && lhs.dst! < rhs.dst!)
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

final class FileManagerTests : XCTestCase {
    private func randomData(count: Int = 10000) -> Data {
        Data((0 ..< count).map { _ in UInt8.random(in: .min ..< .max) })
    }
    
    func testContentsAtPath() throws {
        let data = randomData()
        try FileManagerPlayground {
            File("test", contents: data)
        }.test {
            XCTAssertEqual($0.contents(atPath: "test"), data)
        }
    }
    
    func testContentsEqualAtPaths() throws {
        try FileManagerPlayground {
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
            XCTAssertTrue($0.contentsEqual(atPath: "dir1", andPath: "dir1_copy"))
            XCTAssertFalse($0.contentsEqual(atPath: "dir1/dir2", andPath: "dir1/dir3"))
            XCTAssertFalse($0.contentsEqual(atPath: "dir1", andPath: "dir1_diffdata"))
            XCTAssertFalse($0.contentsEqual(atPath: "symlinks/LinkToFoo", andPath: "symlinks/Foo"), "Symbolic link should not be equal to its destination")
            XCTAssertFalse($0.contentsEqual(atPath: "symlinks/LinkToFoo", andPath: "EmptyFile"), "Symbolic link should not be equal to an empty file")
            XCTAssertFalse($0.contentsEqual(atPath: "symlinks/LinkToFoo", andPath: "EmptyDirectory"), "Symbolic link should not be equal to an empty directory")
            XCTAssertFalse($0.contentsEqual(atPath: "symlinks/EmptyDirectory", andPath: "EmptyFile"), "Empty directory should not be equal to empty file")
        }
    }
    
    func testDirectoryContentsAtPath() throws {
        try FileManagerPlayground {
            Directory("dir1") {
                Directory("dir2") {
                    "Foo"
                    "Bar"
                }
                Directory("dir3") {
                    "Baz"
                }
            }
        }.test {
            XCTAssertEqual(try $0.contentsOfDirectory(atPath: "dir1").sorted(), ["dir2", "dir3"])
            XCTAssertEqual(try $0.contentsOfDirectory(atPath: "dir1/dir2").sorted(), ["Bar", "Foo"])
            XCTAssertEqual(try $0.contentsOfDirectory(atPath: "dir1/dir3").sorted(), ["Baz"])
            XCTAssertThrowsError(try $0.contentsOfDirectory(atPath: "does_not_exist")) {
                XCTAssertEqual(($0 as? CocoaError)?.code, .fileReadNoSuchFile)
            }
        }
    }
    
    func testSubpathsOfDirectoryAtPath() throws {
        try FileManagerPlayground {
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
        }.test {
            XCTAssertEqual(try $0.subpathsOfDirectory(atPath: "dir1").sorted(), ["dir2", "dir2/Bar", "dir2/Foo", "dir3", "dir3/Baz"])
            XCTAssertEqual(try $0.subpathsOfDirectory(atPath: "dir1/dir2").sorted(), ["Bar", "Foo"])
            XCTAssertEqual(try $0.subpathsOfDirectory(atPath: "dir1/dir3").sorted(), ["Baz"])
            
            XCTAssertEqual(try $0.subpathsOfDirectory(atPath: "symlinks").sorted(), ["Bar", "Foo", "Parent"])
            
            XCTAssertThrowsError(try $0.subpathsOfDirectory(atPath: "does_not_exist")) {
                XCTAssertEqual(($0 as? CocoaError)?.code, .fileReadNoSuchFile)
            }

            XCTAssertThrowsError(try $0.subpathsOfDirectory(atPath: "")) {
                #if os(Windows)
                XCTAssertEqual(($0 as? CocoaError)?.code, .fileReadInvalidFileName)
                #else
                XCTAssertEqual(($0 as? CocoaError)?.code, .fileReadNoSuchFile)
                #endif
            }
            
            let fullContents = ["dir1", "dir1/dir2", "dir1/dir2/Bar", "dir1/dir2/Foo", "dir1/dir3", "dir1/dir3/Baz", "symlinks", "symlinks/Bar", "symlinks/Foo", "symlinks/Parent"]
            let cwd = $0.currentDirectoryPath
            XCTAssertNotEqual(cwd.last, "/")
            let paths = [cwd, "\(cwd)/", "\(cwd)//", ".", "./", ".//"]
            for path in paths {
                XCTAssertEqual(try $0.subpathsOfDirectory(atPath: path).sorted(), fullContents)
            }
            
        }
    }
    
    func testCreateDirectoryAtPath() throws {
        try FileManagerPlayground {
            "preexisting_file"
        }.test {
            try $0.createDirectory(atPath: "create_dir_test", withIntermediateDirectories: false)
            XCTAssertEqual(try $0.contentsOfDirectory(atPath: ".").sorted(), ["create_dir_test", "preexisting_file"])
            try $0.createDirectory(atPath: "create_dir_test2/nested", withIntermediateDirectories: true)
            XCTAssertEqual(try $0.contentsOfDirectory(atPath: "create_dir_test2"), ["nested"])
            try $0.createDirectory(atPath: "create_dir_test2/nested2", withIntermediateDirectories: true)
            XCTAssertEqual(try $0.contentsOfDirectory(atPath: "create_dir_test2").sorted(), ["nested", "nested2"])
            XCTAssertNoThrow(try $0.createDirectory(atPath: "create_dir_test2/nested2", withIntermediateDirectories: true))
            
            #if os(Windows)
            try $0.createDirectory(atPath: "create_dir_test3\\nested", withIntermediateDirectories: true)
            XCTAssertEqual(try $0.contentsOfDirectory(atPath: "create_dir_test3"), ["nested"])
            #endif
            
            XCTAssertThrowsError(try $0.createDirectory(atPath: "create_dir_test", withIntermediateDirectories: false)) {
                XCTAssertEqual(($0 as? CocoaError)?.code, .fileWriteFileExists)
            }
            XCTAssertThrowsError(try $0.createDirectory(atPath: "create_dir_test4/nested", withIntermediateDirectories: false)) {
                XCTAssertEqual(($0 as? CocoaError)?.code, .fileNoSuchFile)
            }
            XCTAssertThrowsError(try $0.createDirectory(atPath: "preexisting_file", withIntermediateDirectories: false)) {
                XCTAssertEqual(($0 as? CocoaError)?.code, .fileWriteFileExists)
            }
            XCTAssertThrowsError(try $0.createDirectory(atPath: "preexisting_file", withIntermediateDirectories: true)) {
                XCTAssertEqual(($0 as? CocoaError)?.code, .fileWriteFileExists)
            }
        }
    }
    
    func testLinkFileAtPathToPath() throws {
        try FileManagerPlayground {
            "foo"
        }.test(captureDelegateCalls: true) {
            XCTAssertTrue($0.delegateCaptures.isEmpty)
            try $0.linkItem(atPath: "foo", toPath: "bar")
            XCTAssertEqual($0.delegateCaptures.shouldLink, [.init("foo", "bar")])
            #if os(Android) // Hard links are not normally allowed on Android.
            XCTAssertEqual($0.delegateCaptures.shouldProceedAfterLinkError, [.init("foo", "bar", code: .fileWriteNoPermission)])
            XCTAssertFalse($0.fileExists(atPath: "bar"))
            #else
            XCTAssertEqual($0.delegateCaptures.shouldProceedAfterLinkError, [])
            XCTAssertTrue($0.fileExists(atPath: "bar"))
            #endif
        }
        
        try FileManagerPlayground {
            "foo"
            "bar"
        }.test(captureDelegateCalls: true) {
            XCTAssertTrue($0.delegateCaptures.isEmpty)
            try $0.linkItem(atPath: "foo", toPath: "bar")
            XCTAssertEqual($0.delegateCaptures.shouldLink, [.init("foo", "bar")])
            XCTAssertEqual($0.delegateCaptures.shouldProceedAfterLinkError, [.init("foo", "bar", code: .fileWriteFileExists)])
        }
    }
    
    func testCopyFileAtPathToPath() throws {
        try FileManagerPlayground {
            "foo"
        }.test(captureDelegateCalls: true) {
            XCTAssertTrue($0.delegateCaptures.isEmpty)
            try $0.copyItem(atPath: "foo", toPath: "bar")
            XCTAssertEqual($0.delegateCaptures.shouldCopy, [.init("foo", "bar")])
            XCTAssertEqual($0.delegateCaptures.shouldProceedAfterCopyError, [])
            XCTAssertTrue($0.fileExists(atPath: "bar"))
        }
        
        try FileManagerPlayground {
            "foo"
            "bar"
        }.test(captureDelegateCalls: true) {
            XCTAssertTrue($0.delegateCaptures.isEmpty)
            try $0.copyItem(atPath: "foo", toPath: "bar")
            XCTAssertEqual($0.delegateCaptures.shouldCopy, [.init("foo", "bar")])
            XCTAssertEqual($0.delegateCaptures.shouldProceedAfterCopyError, [.init("foo", "bar", code: .fileWriteFileExists)])
        }
        
        try FileManagerPlayground {
            "foo"
            SymbolicLink("bar", destination: "foo")
        }.test(captureDelegateCalls: true) {
            XCTAssertTrue($0.delegateCaptures.isEmpty)
            try $0.copyItem(atPath: "bar", toPath: "copy")
            XCTAssertEqual($0.delegateCaptures.shouldCopy, [.init("bar", "copy")])
            XCTAssertEqual($0.delegateCaptures.shouldProceedAfterCopyError, [])
            let copyDestination = try $0.destinationOfSymbolicLink(atPath: "copy")
            XCTAssertEqual(copyDestination.lastPathComponent, "foo", "Copied symbolic link points at \(copyDestination) instead of foo")
        }

        try FileManagerPlayground {
            Directory("dir") {
                "foo"
            }
            SymbolicLink("link", destination: "dir")
        }.test(captureDelegateCalls: true) {
            XCTAssertTrue($0.delegateCaptures.isEmpty)
            try $0.copyItem(atPath: "link", toPath: "copy")
            XCTAssertEqual($0.delegateCaptures.shouldCopy, [.init("link", "copy")])
            XCTAssertEqual($0.delegateCaptures.shouldProceedAfterCopyError, [])
            let copyDestination = try $0.destinationOfSymbolicLink(atPath: "copy")
            XCTAssertEqual(copyDestination.lastPathComponent, "dir", "Copied symbolic link points at \(copyDestination) instead of foo")
        }
    }
    
    func testCreateSymbolicLinkAtPath() throws {
        try FileManagerPlayground {
            "foo"
            Directory("dir") {}
        }.test {
            try $0.createSymbolicLink(atPath: "bar", withDestinationPath: "foo")
            XCTAssertEqual(try $0.destinationOfSymbolicLink(atPath: "bar"), "foo")

            try $0.createSymbolicLink(atPath: "dir_link", withDestinationPath: "dir")
            XCTAssertEqual(try $0.destinationOfSymbolicLink(atPath: "dir_link"), "dir")
            
            XCTAssertThrowsError(try $0.createSymbolicLink(atPath: "bar", withDestinationPath: "foo")) {
                XCTAssertEqual(($0 as? CocoaError)?.code, .fileWriteFileExists)
            }
            XCTAssertThrowsError(try $0.createSymbolicLink(atPath: "foo", withDestinationPath: "baz")) {
                XCTAssertEqual(($0 as? CocoaError)?.code, .fileWriteFileExists)
            }
            XCTAssertThrowsError(try $0.destinationOfSymbolicLink(atPath: "foo")) {
                XCTAssertEqual(($0 as? CocoaError)?.code, .fileReadUnknown)
            }
        }

        try FileManagerPlayground {
            Directory("dir") {
                Directory("other_dir") {
                    "file"
                }
            }
        }.test {
            // Create a relative symlink to other_dir from within dir (tests windows special dir symlink handling)
            try $0.createSymbolicLink(atPath: "dir/link", withDestinationPath: "other_dir")

            // Ensure it is created successfully
            XCTAssertEqual(try $0.destinationOfSymbolicLink(atPath: "dir/link"), "other_dir")
            XCTAssertEqual(try $0.contentsOfDirectory(atPath: "dir/link"), ["file"])
            
            do {
                // Second symlink creation with an absolute path
                let absolute = URL(filePath: "dir/link2", relativeTo: URL(filePath: $0.currentDirectoryPath, directoryHint: .isDirectory)).path
                try $0.createSymbolicLink(atPath: absolute, withDestinationPath: "other_dir")
                
                // Ensure it is created successfully
                XCTAssertEqual(try $0.destinationOfSymbolicLink(atPath: "dir/link2"), "other_dir")
                XCTAssertEqual(try $0.contentsOfDirectory(atPath: "dir/link2"), ["file"])
            }
            
            do {
                // And lastly a symlink to an absolute path
                let absolute = URL(filePath: "dir/other_dir", relativeTo: URL(filePath: $0.currentDirectoryPath, directoryHint: .isDirectory)).path
                try $0.createSymbolicLink(atPath: "dir/link3", withDestinationPath: absolute)
                
                // Ensure it is created successfully
                XCTAssertEqual(try $0.destinationOfSymbolicLink(atPath: "dir/link3"), absolute.withFileSystemRepresentation { String(cString: $0!) })
                XCTAssertEqual(try $0.contentsOfDirectory(atPath: "dir/link3"), ["file"])
            }
        }
    }
    
    func testMoveItemAtPathToPath() throws {
        let data = randomData()
        try FileManagerPlayground {
            Directory("dir") {
                File("foo", contents: data)
                "bar"
            }
            "other_file"
        }.test(captureDelegateCalls: true) {
            XCTAssertTrue($0.delegateCaptures.isEmpty)
            try $0.moveItem(atPath: "dir", toPath: "dir2")
            XCTAssertEqual(try $0.subpathsOfDirectory(atPath: ".").sorted(), ["dir2", "dir2/bar", "dir2/foo", "other_file"])
            XCTAssertEqual($0.contents(atPath: "dir2/foo"), data)

            let rootDir = URL(fileURLWithPath: $0.currentDirectoryPath).path
            XCTAssertEqual($0.delegateCaptures.shouldMove, [.init("\(rootDir)/dir", "\(rootDir)/dir2")])

            try $0.moveItem(atPath: "does_not_exist", toPath: "dir3")
            XCTAssertEqual($0.delegateCaptures.shouldProceedAfterMoveError, [.init("\(rootDir)/does_not_exist", "\(rootDir)/dir3", code: .fileNoSuchFile)])

            try $0.moveItem(atPath: "dir2", toPath: "other_file")
            XCTAssertTrue($0.delegateCaptures.shouldProceedAfterMoveError.contains(.init("\(rootDir)/dir2", "\(rootDir)/other_file", code: .fileWriteFileExists)))
        }
    }
    
    func testCopyItemAtPathToPath() throws {
        let data = randomData()
        try FileManagerPlayground {
            Directory("dir", attributes: [.posixPermissions : 0o777]) {
                File("foo", contents: data)
                "bar"
            }
            "other_file"
        }.test(captureDelegateCalls: true) {
            XCTAssertTrue($0.delegateCaptures.isEmpty)
            try $0.copyItem(atPath: "dir", toPath: "dir2")
            XCTAssertEqual(try $0.subpathsOfDirectory(atPath: ".").sorted(), ["dir", "dir/bar", "dir/foo", "dir2", "dir2/bar", "dir2/foo", "other_file"])
            XCTAssertEqual($0.contents(atPath: "dir/foo"), data)
            XCTAssertEqual($0.contents(atPath: "dir2/foo"), data)
#if os(Windows)
            XCTAssertEqual($0.delegateCaptures.shouldCopy.sorted(), [.init("dir", "dir2"), .init("dir/bar", "dir2/bar"), .init("dir/foo", "dir2/foo")].sorted())
#else
            XCTAssertEqual($0.delegateCaptures.shouldCopy.sorted(), [.init("dir", "dir2"), .init("dir/foo", "dir2/foo"), .init("dir/bar", "dir2/bar")].sorted())
            
            // Specifically for non-Windows (where copying directory metadata takes a special path) double check that the metadata was copied exactly
            XCTAssertEqual(try $0.attributesOfItem(atPath: "dir2")[.posixPermissions] as? UInt, 0o777)
#endif
            XCTAssertThrowsError(try $0.copyItem(atPath: "does_not_exist", toPath: "dir3")) {
                XCTAssertEqual(($0 as? CocoaError)?.code, .fileReadNoSuchFile)
            }
            
            try $0.copyItem(atPath: "dir", toPath: "other_file")
            XCTAssertTrue($0.delegateCaptures.shouldProceedAfterCopyError.contains(.init("dir", "other_file", code: .fileWriteFileExists)))
        }
    }
    
    func testRemoveItemAtPath() throws {
        try FileManagerPlayground {
            Directory("dir") {
                "foo"
                "bar"
            }
            "other"
        }.test(captureDelegateCalls: true) {
            XCTAssertTrue($0.delegateCaptures.isEmpty)
            try $0.removeItem(atPath: "dir/bar")
            XCTAssertEqual(try $0.subpathsOfDirectory(atPath: ".").sorted(), ["dir", "dir/foo", "other"])
            XCTAssertEqual($0.delegateCaptures.shouldRemove, [.init("dir/bar")])
            XCTAssertEqual($0.delegateCaptures.shouldProceedAfterRemoveError, [])

            let rootDir = URL(fileURLWithPath: $0.currentDirectoryPath).path
            try $0.removeItem(atPath: "dir")
            XCTAssertEqual(try $0.subpathsOfDirectory(atPath: ".").sorted(), ["other"])
            XCTAssertEqual($0.delegateCaptures.shouldRemove, [.init("dir/bar"), .init("\(rootDir)/dir"), .init("\(rootDir)/dir/foo")])
            XCTAssertEqual($0.delegateCaptures.shouldProceedAfterRemoveError, [])
            
            try $0.removeItem(atPath: "other")
            XCTAssertEqual(try $0.subpathsOfDirectory(atPath: ".").sorted(), [])
            XCTAssertEqual($0.delegateCaptures.shouldRemove, [.init("dir/bar"), .init("\(rootDir)/dir"), .init("\(rootDir)/dir/foo"), .init("other")])
            XCTAssertEqual($0.delegateCaptures.shouldProceedAfterRemoveError, [])
            
            try $0.removeItem(atPath: "does_not_exist")
            XCTAssertEqual($0.delegateCaptures.shouldRemove, [.init("dir/bar"), .init("\(rootDir)/dir"), .init("\(rootDir)/dir/foo"), .init("other"), .init("does_not_exist")])
            XCTAssertEqual($0.delegateCaptures.shouldProceedAfterRemoveError, [.init("does_not_exist", code: .fileNoSuchFile)])
        }

        try FileManagerPlayground {
            Directory("dir") {
                Directory("dir2") {
                    "file"
                }
            }
        }.test(captureDelegateCalls: true) {
            let rootDir = URL(fileURLWithPath: $0.currentDirectoryPath).path

            XCTAssertTrue($0.delegateCaptures.isEmpty)
            try $0.removeItem(atPath: "dir")
            XCTAssertEqual(try $0.subpathsOfDirectory(atPath: ".").sorted(), [])
            XCTAssertEqual($0.delegateCaptures.shouldRemove, [.init("\(rootDir)/dir"), .init("\(rootDir)/dir/dir2"), .init("\(rootDir)/dir/dir2/file")])
            XCTAssertEqual($0.delegateCaptures.shouldProceedAfterRemoveError, [])
        }

        #if canImport(Darwin)
        // not supported on linux as the test depends on FileManager.removeItem calling removefile(3)
        // not supported on older versions of Darwin where removefile would return ENOENT instead of ENAMETOOLONG
        if #available(macOS 14.4, iOS 17.0, watchOS 10.0, tvOS 17.0, *) {
            try FileManagerPlayground {
            }.test {
                // Create hierarchy in which the leaf is a long path (length > PATH_MAX)
                let rootDir = $0.currentDirectoryPath
                let aas = Array(repeating: "a", count: Int(NAME_MAX) - 3).joined()
                let bbs = Array(repeating: "b", count: Int(NAME_MAX) - 3).joined()
                let ccs = Array(repeating: "c", count: Int(NAME_MAX) - 3).joined()
                let dds = Array(repeating: "d", count: Int(NAME_MAX) - 3).joined()
                let ees = Array(repeating: "e", count: Int(NAME_MAX) - 3).joined()
                let leaf = "longpath"
                
                try $0.createDirectory(atPath: aas, withIntermediateDirectories: true)
                XCTAssertTrue($0.changeCurrentDirectoryPath(aas))
                try $0.createDirectory(atPath: bbs, withIntermediateDirectories: true)
                XCTAssertTrue($0.changeCurrentDirectoryPath(bbs))
                try $0.createDirectory(atPath: ccs, withIntermediateDirectories: true)
                XCTAssertTrue($0.changeCurrentDirectoryPath(ccs))
                try $0.createDirectory(atPath: dds, withIntermediateDirectories: true)
                XCTAssertTrue($0.changeCurrentDirectoryPath(dds))
                try $0.createDirectory(atPath: ees, withIntermediateDirectories: true)
                XCTAssertTrue($0.changeCurrentDirectoryPath(ees))
                try $0.createDirectory(atPath: leaf, withIntermediateDirectories: true)
                
                XCTAssertTrue($0.changeCurrentDirectoryPath(rootDir))
                let fullPath = "\(aas)/\(bbs)/\(ccs)/\(dds)/\(ees)/\(leaf)"
                XCTAssertThrowsError(try $0.removeItem(atPath: fullPath)) {
                    let underlyingPosixError = ($0 as? CocoaError)?.underlying as? POSIXError
                    XCTAssertEqual(underlyingPosixError?.code, .ENAMETOOLONG, "removeItem didn't fail with ENAMETOOLONG; produced error: \($0)")
                }
                
                // Clean up
                XCTAssertTrue($0.changeCurrentDirectoryPath(aas))
                XCTAssertTrue($0.changeCurrentDirectoryPath(bbs))
                XCTAssertTrue($0.changeCurrentDirectoryPath(ccs))
                XCTAssertTrue($0.changeCurrentDirectoryPath(dds))
                try $0.removeItem(atPath: ees)
                XCTAssertTrue($0.changeCurrentDirectoryPath(".."))
                try $0.removeItem(atPath: dds)
                XCTAssertTrue($0.changeCurrentDirectoryPath(".."))
                try $0.removeItem(atPath: ccs)
                XCTAssertTrue($0.changeCurrentDirectoryPath(".."))
                try $0.removeItem(atPath: bbs)
                XCTAssertTrue($0.changeCurrentDirectoryPath(".."))
                try $0.removeItem(atPath: aas)
            }
        }
        #endif
    }
    
    func testFileExistsAtPath() throws {
        try FileManagerPlayground {
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
            XCTAssertTrue($0.fileExists(atPath: "dir/foo", isDirectory: &isDir))
            XCTAssertFalse(isDirBool())
            XCTAssertTrue($0.fileExists(atPath: "dir/bar", isDirectory: &isDir))
            XCTAssertFalse(isDirBool())
            XCTAssertTrue($0.fileExists(atPath: "dir", isDirectory: &isDir))
            XCTAssertTrue(isDirBool())
            XCTAssertTrue($0.fileExists(atPath: "other", isDirectory: &isDir))
            XCTAssertFalse(isDirBool())
            XCTAssertTrue($0.fileExists(atPath: "link_to_file", isDirectory: &isDir))
            XCTAssertFalse(isDirBool())
            XCTAssertTrue($0.fileExists(atPath: "link_to_dir", isDirectory: &isDir))
            XCTAssertTrue(isDirBool())
            XCTAssertFalse($0.fileExists(atPath: "does_not_exist"))
            XCTAssertFalse($0.fileExists(atPath: "link_to_nonexistent"))
        }
    }

    func testFileAccessAtPath() throws {
        #if !os(Windows)
        guard getuid() != 0 else {
            // Root users can always access anything, so this test will not function when run as root
            throw XCTSkip("This test is not available when running as the root user")
        }
        #endif
        
        try FileManagerPlayground {
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
                XCTAssertEqual($0.isReadableFile(atPath: file), readable.contains(file), "'\(file)' failed readable check")
                XCTAssertEqual($0.isWritableFile(atPath: file), writable.contains(file), "'\(file)' failed writable check")
                XCTAssertEqual($0.isExecutableFile(atPath: file), executable.contains(file), "'\(file)' failed executable check")
                #if os(Windows)
                // Only writable files are deletable on Windows
                XCTAssertEqual($0.isDeletableFile(atPath: file), writable.contains(file), "'\(file)' failed deletable check")
                #else
                XCTAssertTrue($0.isDeletableFile(atPath: file), "'\(file)' failed deletable check")
                #endif
            }
        }
    }

    func testFileSystemAttributesAtPath() throws {
        try FileManagerPlayground {
            "Foo"
        }.test {
            let dict = try $0.attributesOfFileSystem(forPath: "Foo")
            XCTAssertNotNil(dict[.systemSize])
            XCTAssertThrowsError(try $0.attributesOfFileSystem(forPath: "does_not_exist")) {
                XCTAssertEqual(($0 as? CocoaError)?.code, .fileReadNoSuchFile)
            }
        }
    }
    
    func testCurrentWorkingDirectory() throws {
        try FileManagerPlayground {
            Directory("dir") {
                "foo"
            }
            "bar"
        }.test {
            XCTAssertEqual(try $0.subpathsOfDirectory(atPath: ".").sorted(), ["bar", "dir", "dir/foo"])
            XCTAssertTrue($0.changeCurrentDirectoryPath("dir"))
            XCTAssertEqual(try $0.subpathsOfDirectory(atPath: "."), ["foo"])
            XCTAssertFalse($0.changeCurrentDirectoryPath("foo"))
            XCTAssertTrue($0.changeCurrentDirectoryPath(".."))
            XCTAssertEqual(try $0.subpathsOfDirectory(atPath: ".").sorted(), ["bar", "dir", "dir/foo"])
            XCTAssertFalse($0.changeCurrentDirectoryPath("does_not_exist"))
            
            // Test get current directory path when it's parent directory was removed.
            XCTAssertTrue($0.changeCurrentDirectoryPath("dir"))
#if os(Windows)
            // Removing the current working directory fails on Windows because the directory is in use.
            XCTAssertThrowsError(try $0.removeItem(atPath: $0.currentDirectoryPath)) {
                XCTAssertEqual(($0 as? CocoaError)?.code, .fileWriteNoPermission)
            }
#else
            try $0.removeItem(atPath: $0.currentDirectoryPath)
            XCTAssertEqual($0.currentDirectoryPath, "")
#endif
        }
    }
    
    func testBooleanFileAttributes() throws {
        #if canImport(Darwin)
        try FileManagerPlayground {
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
                XCTAssertEqual(result[.immutable] as? Bool, test.immutable, "Item at path '\(test.path)' did not provide expected result for immutable key")
                XCTAssertEqual(result[.appendOnly] as? Bool, test.appendOnly, "Item at path '\(test.path)' did not provide expected result for appendOnly key")
                
                XCTAssertNil(result[.busy], "Item at path '\(test.path)' has non-nil value for .busy attribute") // Should only be set when true
                
                // Manually clean up attributes so removal does not fail
                try $0.setAttributes([.immutable: false, .appendOnly: false], ofItemAtPath: test.path)
            }
        }
        #else
        throw XCTSkip("This test is not applicable on this platform")
        #endif
    }
    
    func testMalformedModificationDateAttribute() throws {
        let sentinelDate = Date(timeIntervalSince1970: 100)
        try FileManagerPlayground {
            File("foo", attributes: [.modificationDate: sentinelDate])
        }.test {
            XCTAssertEqual(try $0.attributesOfItem(atPath: "foo")[.modificationDate] as? Date, sentinelDate)
            for value in [Double.infinity, -Double.infinity, Double.nan] {
                // Malformed modification dates should be dropped instead of throwing or crashing
                try $0.setAttributes([.modificationDate : Date(timeIntervalSince1970: value)], ofItemAtPath: "foo")
            }
            XCTAssertEqual(try $0.attributesOfItem(atPath: "foo")[.modificationDate] as? Date, sentinelDate)
        }
    }
    
    func testImplicitlyConvertibleFileAttributes() throws {
        try FileManagerPlayground {
            File("foo", attributes: [.posixPermissions : UInt16(0o644)])
        }.test {
            let attributes = try $0.attributesOfItem(atPath: "foo")

            // Ensure the unconventional UInt16 was accepted as input
            #if os(Windows)
            XCTAssertEqual(attributes[.posixPermissions] as? UInt, 0o600)
            #else
            XCTAssertEqual(attributes[.posixPermissions] as? UInt, 0o644)
            #endif

            #if FOUNDATION_FRAMEWORK
            // Where we have NSNumber, ensure that we can get the value back as an unconventional Double value
            XCTAssertEqual(attributes[.posixPermissions] as? Double, Double(0o644))
            // Ensure that the file type can be converted to a String when it is an ObjC enum
            XCTAssertEqual(attributes[.type] as? String, FileAttributeType.typeRegular.rawValue)
            #endif

            // Ensure that the file type can be converted to a FileAttributeType when it is an ObjC enum and in swift-foundation
            XCTAssertEqual(attributes[.type] as? FileAttributeType, .typeRegular)
            
        }
    }
    
    func testStandardizingPathAutomount() throws {
        #if canImport(Darwin)
        let tests = [
            "/private/System" : "/private/System",
            "/private/tmp" : "/tmp",
            "/private/System/foo" : "/private/System/foo"
        ]
        for (input, expected) in tests {
            XCTAssertEqual(input.standardizingPath, expected, "Standardizing the path '\(input)' did not produce the expected result")
        }
        #else
        throw XCTSkip("This test is not applicable to this platform")
        #endif
    }
    
    func testResolveSymlinksViaGetAttrList() throws {
        #if !canImport(Darwin)
        throw XCTSkip("This test is not applicable on this platform")
        #else
        try FileManagerPlayground {
            "destination"
        }.test {
            try $0.createSymbolicLink(atPath: "link", withDestinationPath: "destination")
            let absolutePath = $0.currentDirectoryPath.appendingPathComponent("link")
            let resolved = absolutePath._resolvingSymlinksInPath() // Call internal function to avoid path standardization
            XCTAssertEqual(resolved, $0.currentDirectoryPath.appendingPathComponent("destination").withFileSystemRepresentation { String(cString: $0!) })
        }
        #endif
    }
    
    #if os(macOS) && FOUNDATION_FRAMEWORK
    func testSpecialTrashDirectoryTruncation() throws {
        try FileManagerPlayground {}.test {
            if let trashURL = try? $0.url(for: .trashDirectory, in: .allDomainsMask, appropriateFor: nil, create: false) {
                XCTAssertEqual(trashURL.pathComponents.last, ".Trash")
            }
        }
    }
    
    func testSpecialTrashDirectoryDuplication() throws {
        try FileManagerPlayground {}.test { fileManager in
            let trashURLs = fileManager.urls(for: .trashDirectory, in: .userDomainMask)
            XCTAssertEqual(trashURLs.count, 1, "There should only be one trash directory for the user domain, found \(trashURLs)")
        }
    }
    #endif
    
    func testSearchPaths() throws {
        func assertSearchPaths(_ directories: [FileManager.SearchPathDirectory], exists: Bool, file: StaticString = #filePath, line: UInt = #line) {
            for directory in directories {
                let paths = FileManager.default.urls(for: directory, in: .allDomainsMask)
                XCTAssertEqual(!paths.isEmpty, exists, "Directory \(directory) produced an unexpected number of paths (expected to exist: \(exists), produced: \(paths))", file: file, line: line)
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
    
    func testSearchPaths_XDGEnvironmentVariables() throws {
        #if canImport(Darwin) || os(Windows)
        throw XCTSkip("This test is not applicable on this platform")
        #else
        if let key = ProcessInfo.processInfo.environment.keys.first(where: { $0.starts(with: "XDG") }) {
            throw XCTSkip("Skipping due to presence of '\(key)' environment variable which may affect this test")
        }
        
        try FileManagerPlayground {
            Directory("TestPath") {}
        }.test { fileManager in
            func validate(_ key: String, suffix: String? = nil, directory: FileManager.SearchPathDirectory, domain: FileManager.SearchPathDomainMask, file: StaticString = #filePath, line: UInt = #line) {
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
                XCTAssertTrue(results.contains(knownURL), "Results \(results.map(\.path)) did not contain known directory \(knownURL.path) for \(directory)/\(domain) while setting the \(key) environment variable", file: file, line: line)
            }

            validate("XDG_DATA_HOME", suffix: "Autosave Information", directory: .autosavedInformationDirectory, domain: .userDomainMask)
            validate("HOME", suffix: ".local/share/Autosave Information", directory: .autosavedInformationDirectory, domain: .userDomainMask)

            validate("XDG_CACHE_HOME", directory: .cachesDirectory, domain: .userDomainMask)
            validate("HOME", suffix: ".cache", directory: .cachesDirectory, domain: .userDomainMask)
            
            validate("XDG_DATA_HOME", directory: .applicationSupportDirectory, domain: .userDomainMask)
            validate("HOME", suffix: ".local/share", directory: .applicationSupportDirectory, domain: .userDomainMask)
            
            validate("HOME", directory: .userDirectory, domain: .localDomainMask)
        }
        #endif
    }
    
    func testGetSetAttributes() throws {
        try FileManagerPlayground {
            File("foo", contents: randomData())
        }.test {
            let attrs = try $0.attributesOfItem(atPath: "foo")
            try $0.setAttributes(attrs, ofItemAtPath: "foo")
        }
    }

    func testCurrentUserHomeDirectory() throws {
        #if canImport(Darwin) && !os(macOS)
        throw XCTSkip("This test is not applicable on this platform")
        #else
        let userName = ProcessInfo.processInfo.userName
        XCTAssertEqual(FileManager.default.homeDirectory(forUser: userName), FileManager.default.homeDirectoryForCurrentUser)
        #endif
    }
    
    func testAttributesOfItemAtPath() throws {
        try FileManagerPlayground {
            "file"
            File("fileWithContents", contents: randomData())
            Directory("directory") {
                "file"
            }
        }.test {
            do {
                let attrs = try $0.attributesOfItem(atPath: "file")
                XCTAssertEqual(attrs[.size] as? UInt, 0)
                XCTAssertEqual(attrs[.type] as? FileAttributeType, FileAttributeType.typeRegular)
            }
            
            do {
                let attrs = try $0.attributesOfItem(atPath: "fileWithContents")
                XCTAssertGreaterThan(try XCTUnwrap(attrs[.size] as? UInt), 0)
                XCTAssertEqual(attrs[.type] as? FileAttributeType, FileAttributeType.typeRegular)
            }
            
            do {
                let attrs = try $0.attributesOfItem(atPath: "directory")
                XCTAssertEqual(attrs[.type] as? FileAttributeType, FileAttributeType.typeDirectory)
            }
            
            do {
                try $0.createSymbolicLink(atPath: "symlink", withDestinationPath: "file")
                let attrs = try $0.attributesOfItem(atPath: "symlink")
                XCTAssertEqual(attrs[.type] as? FileAttributeType, FileAttributeType.typeSymbolicLink)
            }
        }
    }
    
    func testHomeDirectoryForNonExistantUser() throws {
        #if canImport(Darwin) && !os(macOS)
        throw XCTSkip("This test is not applicable on this platform")
        #else
        XCTAssertNil(FileManager.default.homeDirectory(forUser: ""))
        XCTAssertNil(FileManager.default.homeDirectory(forUser: UUID().uuidString))
        #endif
    }
    
    func testSearchPathsWithoutExpandingTilde() throws {
        #if !canImport(Darwin)
        throw XCTSkip("This test is not applicable for this platform")
        #else
        for path in _DarwinSearchPaths(for: .libraryDirectory, in: .userDomainMask, expandTilde: false) {
            XCTAssertTrue(path.starts(with: "~/"), "Path '\(path)' did not start with ~/ as expected")
        }
        #endif
    }

    func testWindowsDirectoryCreationCrash() throws {
        try FileManagerPlayground {
            Directory("a\u{301}") {

            }
        }.test {
            XCTAssertTrue($0.fileExists(atPath: "a\u{301}"))
            let data = randomData()
            XCTAssertTrue($0.createFile(atPath: "a\u{301}/test", contents: data))
            XCTAssertTrue($0.fileExists(atPath: "a\u{301}/test"))
            XCTAssertEqual($0.contents(atPath: "a\u{301}/test"), data)
        }
    }
}
