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

extension FileManager {
    fileprivate var delegateCaptures: DelegateCaptures {
        (self.delegate as! CapturingFileManagerDelegate).captures
    }
}

private struct DelegateCaptures : Equatable {
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
class CapturingFileManagerDelegate : NSObject, FileManagerDelegate {
    fileprivate var captures = DelegateCaptures()
    
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
class CapturingFileManagerDelegate : FileManagerDelegate {
    fileprivate var captures = DelegateCaptures()
    
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
        }.test {
            XCTAssertTrue($0.contentsEqual(atPath: "dir1", andPath: "dir1_copy"))
            XCTAssertFalse($0.contentsEqual(atPath: "dir1/dir2", andPath: "dir1/dir3"))
            XCTAssertFalse($0.contentsEqual(atPath: "dir1", andPath: "dir1_diffdata"))
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
        }.test {
            XCTAssertEqual(try $0.subpathsOfDirectory(atPath: "dir1").sorted(), ["dir2", "dir2/Bar", "dir2/Foo", "dir3", "dir3/Baz"])
            XCTAssertEqual(try $0.subpathsOfDirectory(atPath: "dir1/dir2").sorted(), ["Bar", "Foo"])
            XCTAssertEqual(try $0.subpathsOfDirectory(atPath: "dir1/dir3").sorted(), ["Baz"])
            XCTAssertThrowsError(try $0.subpathsOfDirectory(atPath: "does_not_exist")) {
                XCTAssertEqual(($0 as? CocoaError)?.code, .fileReadNoSuchFile)
            }
            
            let fullContents = ["dir1", "dir1/dir2", "dir1/dir2/Bar", "dir1/dir2/Foo", "dir1/dir3", "dir1/dir3/Baz"]
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
            XCTAssertThrowsError(try $0.createDirectory(atPath: "create_dir_test", withIntermediateDirectories: false)) {
                XCTAssertEqual(($0 as? CocoaError)?.code, .fileWriteFileExists)
            }
            XCTAssertThrowsError(try $0.createDirectory(atPath: "create_dir_test3/nested", withIntermediateDirectories: false)) {
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
            XCTAssertEqual($0.delegateCaptures.shouldProceedAfterLinkError, [])
            XCTAssertTrue($0.fileExists(atPath: "bar"))
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
    }
    
    func testCreateSymbolicLinkAtPath() throws {
        try FileManagerPlayground {
            "foo"
        }.test {
            try $0.createSymbolicLink(atPath: "bar", withDestinationPath: "foo")
            XCTAssertEqual(try $0.destinationOfSymbolicLink(atPath: "bar"), "foo")
            
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
            #if FOUNDATION_FRAMEWORK
            // Behavior differs here due to usage of URL(filePath:)
            let rootDir = $0.currentDirectoryPath
            XCTAssertEqual($0.delegateCaptures.shouldMove, [.init("\(rootDir)/dir", "\(rootDir)/dir2")])
            #else
            XCTAssertEqual($0.delegateCaptures.shouldMove, [.init("dir", "dir2")])
            #endif
            
            try $0.moveItem(atPath: "does_not_exist", toPath: "dir3")
            XCTAssertEqual($0.delegateCaptures.shouldProceedAfterCopyError, [])

            try $0.moveItem(atPath: "dir2", toPath: "other_file")
            #if FOUNDATION_FRAMEWORK
            XCTAssertTrue($0.delegateCaptures.shouldProceedAfterMoveError.contains(.init("\(rootDir)/dir2", "\(rootDir)/other_file", code: .fileWriteFileExists)))
            #else
            XCTAssertTrue($0.delegateCaptures.shouldProceedAfterMoveError.contains(.init("dir2", "other_file", code: .fileWriteFileExists)))
            #endif
        }
    }
    
    func testCopyItemAtPathToPath() throws {
        let data = randomData()
        try FileManagerPlayground {
            Directory("dir") {
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
            XCTAssertEqual($0.delegateCaptures.shouldCopy, [.init("dir", "dir2"), .init("dir/foo", "dir2/foo"), .init("dir/bar", "dir2/bar")])
            
            try $0.copyItem(atPath: "does_not_exist", toPath: "dir3")
            XCTAssertEqual($0.delegateCaptures.shouldProceedAfterCopyError.last, .init("does_not_exist", "dir3", code: .fileNoSuchFile))
            
            #if canImport(Darwin)
            // Not supported on linux because it ends up trying to set attributes that are currently unimplemented
            try $0.copyItem(atPath: "dir", toPath: "other_file")
            XCTAssertTrue($0.delegateCaptures.shouldProceedAfterCopyError.contains(.init("dir", "other_file", code: .fileWriteFileExists)))
            #endif
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
            
            let rootDir = $0.currentDirectoryPath
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
    }
    
    func testFileExistsAtPath() throws {
        try FileManagerPlayground {
            Directory("dir") {
                "foo"
                "bar"
            }
            "other"
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
            XCTAssertFalse($0.fileExists(atPath: "does_not_exist"))
        }
    }
    
    func testFileAccessAtPath() throws {
        guard getuid() != 0 else {
            // Root users can always access anything, so this test will not function when run as root
            throw XCTSkip("This test is not available when running as the root user")
        }
        
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
            let readable = ["444", "555", "666", "777"]
            let writable = ["222", "333", "666", "777"]
            let executable = ["111", "333", "555", "777"]
            for number in 0...7 {
                let file = "\(number)\(number)\(number)"
                XCTAssertEqual($0.isReadableFile(atPath: file), readable.contains(file), "'\(file)' failed readable check")
                XCTAssertEqual($0.isWritableFile(atPath: file), writable.contains(file), "'\(file)' failed writable check")
                XCTAssertEqual($0.isExecutableFile(atPath: file), executable.contains(file), "'\(file)' failed executable check")
                XCTAssertTrue($0.isDeletableFile(atPath: file), "'\(file)' failed deletable check")
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
        }
    }
    
    func testImplicitlyConvertibleFileAttributes() throws {
        try FileManagerPlayground {
            File("foo", attributes: [.posixPermissions : UInt16(0o644)])
        }.test {
            let attributes = try $0.attributesOfItem(atPath: "foo")
            // Ensure the unconventional UInt16 was accepted as input
            XCTAssertEqual(attributes[.posixPermissions] as? UInt, 0o644)
            #if FOUNDATION_FRAMEWORK
            // Where we have NSNumber, ensure that we can get the value back as an unconventional Double value
            XCTAssertEqual(attributes[.posixPermissions] as? Double, Double(0o644))
            #endif
        }
    }
}
