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

@_spi(Experimental) import Testing

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

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

// `FileManagerTests` has global states (directories created etc)
// therefore they must run in serial.
@Suite(.serial)
struct FileManagerTests {
    private func randomData(count: Int = 10000) -> Data {
        Data((0 ..< count).map { _ in UInt8.random(in: .min ..< .max) })
    }
    
    @Test func testContentsAtPath() throws {
        let data = randomData()
        try FileManagerPlayground {
            File("test", contents: data)
        }.test {
            #expect($0.contents(atPath: "test") == data)
        }
    }
    
    @Test func testContentsEqualAtPaths() throws {
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
            #expect($0.contentsEqual(atPath: "dir1", andPath: "dir1_copy"))
            #expect($0.contentsEqual(atPath: "dir1/dir2", andPath: "dir1/dir3") == false)
            #expect($0.contentsEqual(atPath: "dir1", andPath: "dir1_diffdata") == false)
        }
    }
    
    @Test func testDirectoryContentsAtPath() throws {
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
        }.test { (fileManager) throws in
            var results = try fileManager.contentsOfDirectory(atPath: "dir1").sorted()
            #expect(results == ["dir2", "dir3"])
            results = try fileManager.contentsOfDirectory(atPath: "dir1/dir2").sorted()
            #expect(results == ["Bar", "Foo"])
            results = try fileManager.contentsOfDirectory(atPath: "dir1/dir3").sorted()
            #expect(results == ["Baz"])
            #expect {
                try fileManager.contentsOfDirectory(atPath: "does_not_exist")
            } throws: { error in
                guard let cocoaError = error as? CocoaError else {
                    return false
                }
                #expect(cocoaError.code == .fileReadNoSuchFile)
                return true
            }
        }
    }
    
    @Test func testSubpathsOfDirectoryAtPath() throws {
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
        }.test { (fileManager) throws in
            var results = try fileManager.subpathsOfDirectory(atPath: "dir1").sorted()
            #expect(results == ["dir2", "dir2/Bar", "dir2/Foo", "dir3", "dir3/Baz"])
            results = try fileManager.subpathsOfDirectory(atPath: "dir1/dir2").sorted()
            #expect(results == ["Bar", "Foo"])
            results = try fileManager.subpathsOfDirectory(atPath: "dir1/dir3").sorted()
            #expect(results == ["Baz"])
            #expect {
                try fileManager.subpathsOfDirectory(atPath: "does_not_exist")
            } throws: { error in
                guard let cocoaError = error as? CocoaError else {
                    return false
                }
                #expect(cocoaError.code == .fileReadNoSuchFile)
                return true
            }
            
            let fullContents = ["dir1", "dir1/dir2", "dir1/dir2/Bar", "dir1/dir2/Foo", "dir1/dir3", "dir1/dir3/Baz"]
            let cwd = fileManager.currentDirectoryPath
            #expect(cwd.last != "/")
            let paths = [cwd, "\(cwd)/", "\(cwd)//", ".", "./", ".//"]
            for path in paths {
                let results = try fileManager.subpathsOfDirectory(atPath: path).sorted()
                #expect(results == fullContents)
            }
        }
    }
    
    @Test func testCreateDirectoryAtPath() throws {
        try FileManagerPlayground {
            "preexisting_file"
        }.test { fileManager in
            try fileManager.createDirectory(atPath: "create_dir_test", withIntermediateDirectories: false)
            var result = try fileManager.contentsOfDirectory(atPath: ".").sorted()
            #expect(result == ["create_dir_test", "preexisting_file"])
            try fileManager.createDirectory(atPath: "create_dir_test2/nested", withIntermediateDirectories: true)
            result = try fileManager.contentsOfDirectory(atPath: "create_dir_test2")
            #expect(result == ["nested"])
            try fileManager.createDirectory(atPath: "create_dir_test2/nested2", withIntermediateDirectories: true)
            result = try fileManager.contentsOfDirectory(atPath: "create_dir_test2").sorted()
            #expect(result == ["nested", "nested2"])
            #expect(throws: Never.self) {
                try fileManager.createDirectory(atPath: "create_dir_test2/nested2", withIntermediateDirectories: true)
            }
            #expect {
                try fileManager.createDirectory(atPath: "create_dir_test", withIntermediateDirectories: false)
            } throws: { error in
                guard let cocoaError = error as? CocoaError else {
                    return false
                }
                #expect(cocoaError.code == .fileWriteFileExists)
                return true
            }
            #expect {
                try fileManager.createDirectory(atPath: "create_dir_test3/nested", withIntermediateDirectories: false)
            } throws: { error in
                guard let cocoaError = error as? CocoaError else {
                    return false
                }
                #expect(cocoaError.code == .fileNoSuchFile)
                return true
            }
            #expect {
                try fileManager.createDirectory(atPath: "preexisting_file", withIntermediateDirectories: false)
            } throws: { error in
                guard let cocoaError = error as? CocoaError else {
                    return false
                }
                #expect(cocoaError.code == .fileWriteFileExists)
                return true
            }
            #expect {
                try fileManager.createDirectory(atPath: "preexisting_file", withIntermediateDirectories: true)
            } throws: { error in
                guard let cocoaError = error as? CocoaError else {
                    return false
                }
                #expect(cocoaError.code == .fileWriteFileExists)
                return true
            }
        }
    }
    
    @Test func testLinkFileAtPathToPath() throws {
        try FileManagerPlayground {
            "foo"
        }.test(captureDelegateCalls: true) {
            #expect($0.delegateCaptures.isEmpty)
            try $0.linkItem(atPath: "foo", toPath: "bar")
            #expect($0.delegateCaptures.shouldLink == [.init("foo", "bar")])
            #expect($0.delegateCaptures.shouldProceedAfterLinkError == [])
            #expect($0.fileExists(atPath: "bar"))
        }
        
        try FileManagerPlayground {
            "foo"
            "bar"
        }.test(captureDelegateCalls: true) {
            #expect($0.delegateCaptures.isEmpty)
            try $0.linkItem(atPath: "foo", toPath: "bar")
            #expect($0.delegateCaptures.shouldLink == [.init("foo", "bar")])
            #expect($0.delegateCaptures.shouldProceedAfterLinkError == [.init("foo", "bar", code: .fileWriteFileExists)])
        }
    }
    
    @Test func testCopyFileAtPathToPath() throws {
        try FileManagerPlayground {
            "foo"
        }.test(captureDelegateCalls: true) {
            #expect($0.delegateCaptures.isEmpty)
            try $0.copyItem(atPath: "foo", toPath: "bar")
            #expect($0.delegateCaptures.shouldCopy == [.init("foo", "bar")])
            #expect($0.delegateCaptures.shouldProceedAfterCopyError == [])
            #expect($0.fileExists(atPath: "bar"))
        }
        
        try FileManagerPlayground {
            "foo"
            "bar"
        }.test(captureDelegateCalls: true) {
            #expect($0.delegateCaptures.isEmpty)
            try $0.copyItem(atPath: "foo", toPath: "bar")
            #expect($0.delegateCaptures.shouldCopy == [.init("foo", "bar")])
            #expect($0.delegateCaptures.shouldProceedAfterCopyError == [.init("foo", "bar", code: .fileWriteFileExists)])
        }
    }
    
    @Test func testCreateSymbolicLinkAtPath() throws {
        try FileManagerPlayground {
            "foo"
        }.test { fileManager in
            try fileManager.createSymbolicLink(atPath: "bar", withDestinationPath: "foo")
            let results = try fileManager.destinationOfSymbolicLink(atPath: "bar")
            #expect(results == "foo")
            #expect {
                try fileManager.createSymbolicLink(atPath: "bar", withDestinationPath: "foo")
            } throws: { error in
                guard let cocoaError = error as? CocoaError else {
                    return false
                }
                #expect(cocoaError.code == .fileWriteFileExists)
                return true
            }
            #expect {
                try fileManager.createSymbolicLink(atPath: "foo", withDestinationPath: "baz")
            } throws: { error in
                guard let cocoaError = error as? CocoaError else {
                    return false
                }
                #expect(cocoaError.code == .fileWriteFileExists)
                return true
            }
            #expect {
                try fileManager.destinationOfSymbolicLink(atPath: "foo")
            } throws: { error in
                guard let cocoaError = error as? CocoaError else {
                    return false
                }
                #expect(cocoaError.code == .fileReadUnknown)
                return true
            }
        }
    }
    
    @Test func testMoveItemAtPathToPath() throws {
        let data = randomData()
        try FileManagerPlayground {
            Directory("dir") {
                File("foo", contents: data)
                "bar"
            }
            "other_file"
        }.test(captureDelegateCalls: true) {
            #expect($0.delegateCaptures.isEmpty)
            try $0.moveItem(atPath: "dir", toPath: "dir2")
            let results = try $0.subpathsOfDirectory(atPath: ".").sorted()
            #expect(results == ["dir2", "dir2/bar", "dir2/foo", "other_file"])
            #expect($0.contents(atPath: "dir2/foo") == data)
            #if FOUNDATION_FRAMEWORK
            // Behavior differs here due to usage of URL(filePath:)
            let rootDir = $0.currentDirectoryPath
            #expect($0.delegateCaptures.shouldMove == [.init("\(rootDir)/dir", "\(rootDir)/dir2")])
            #else
            #expect($0.delegateCaptures.shouldMove == [.init("dir", "dir2")])
            #endif
            
            try $0.moveItem(atPath: "does_not_exist", toPath: "dir3")
            #expect($0.delegateCaptures.shouldProceedAfterCopyError == [])

            try $0.moveItem(atPath: "dir2", toPath: "other_file")
            #if FOUNDATION_FRAMEWORK
            #expect($0.delegateCaptures.shouldProceedAfterMoveError.contains(.init("\(rootDir)/dir2", "\(rootDir)/other_file", code: .fileWriteFileExists)))
            #else
            #expect($0.delegateCaptures.shouldProceedAfterMoveError.contains(.init("dir2", "other_file", code: .fileWriteFileExists)))
            #endif
        }
    }
    
    @Test func testCopyItemAtPathToPath() throws {
        let data = randomData()
        try FileManagerPlayground {
            Directory("dir") {
                File("foo", contents: data)
                "bar"
            }
            "other_file"
        }.test(captureDelegateCalls: true) {
            #expect($0.delegateCaptures.isEmpty)
            try $0.copyItem(atPath: "dir", toPath: "dir2")
            let results = try $0.subpathsOfDirectory(atPath: ".").sorted()
            #expect(results == ["dir", "dir/bar", "dir/foo", "dir2", "dir2/bar", "dir2/foo", "other_file"])
            #expect($0.contents(atPath: "dir/foo") == data)
            #expect($0.contents(atPath: "dir2/foo") == data)
            #expect($0.delegateCaptures.shouldCopy == [.init("dir", "dir2"), .init("dir/foo", "dir2/foo"), .init("dir/bar", "dir2/bar")])

            try $0.copyItem(atPath: "does_not_exist", toPath: "dir3")
            #expect($0.delegateCaptures.shouldProceedAfterCopyError.last == .init("does_not_exist", "dir3", code: .fileNoSuchFile))

            #if canImport(Darwin)
            // Not supported on linux because it ends up trying to set attributes that are currently unimplemented
            try $0.copyItem(atPath: "dir", toPath: "other_file")
            #expect($0.delegateCaptures.shouldProceedAfterCopyError.contains(.init("dir", "other_file", code: .fileWriteFileExists)))
            #endif
        }
    }
    
    @Test func testRemoveItemAtPath() throws {
        try FileManagerPlayground {
            Directory("dir") {
                "foo"
                "bar"
            }
            "other"
        }.test(captureDelegateCalls: true) {
            #expect($0.delegateCaptures.isEmpty)
            try $0.removeItem(atPath: "dir/bar")
            var results = try $0.subpathsOfDirectory(atPath: ".").sorted()
            #expect(results == ["dir", "dir/foo", "other"])
            #expect($0.delegateCaptures.shouldRemove == [.init("dir/bar")])
            #expect($0.delegateCaptures.shouldProceedAfterRemoveError == [])

            let rootDir = $0.currentDirectoryPath
            try $0.removeItem(atPath: "dir")
            results = try $0.subpathsOfDirectory(atPath: ".").sorted()
            #expect(results == ["other"])
            #expect($0.delegateCaptures.shouldRemove == [.init("dir/bar"), .init("\(rootDir)/dir"), .init("\(rootDir)/dir/foo")])
            #expect($0.delegateCaptures.shouldProceedAfterRemoveError == [])

            try $0.removeItem(atPath: "other")
            results = try $0.subpathsOfDirectory(atPath: ".").sorted()
            #expect(results == [])
            #expect($0.delegateCaptures.shouldRemove == [.init("dir/bar"), .init("\(rootDir)/dir"), .init("\(rootDir)/dir/foo"), .init("other")])
            #expect($0.delegateCaptures.shouldProceedAfterRemoveError == [])

            try $0.removeItem(atPath: "does_not_exist")
            #expect($0.delegateCaptures.shouldRemove == [.init("dir/bar"), .init("\(rootDir)/dir"), .init("\(rootDir)/dir/foo"), .init("other"), .init("does_not_exist")])
            #expect($0.delegateCaptures.shouldProceedAfterRemoveError == [.init("does_not_exist", code: .fileNoSuchFile)])
        }

        #if canImport(Darwin)
        // not supported on linux as the test depends on FileManager.removeItem calling removefile(3)
        // not supported on older versions of Darwin where removefile would return ENOENT instead of ENAMETOOLONG
        if #available(macOS 14.4, iOS 17.0, watchOS 10.0, tvOS 17.0, *) {
            try FileManagerPlayground {
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
                } throws: { error in
                    guard let cocoaError = error as? CocoaError,
                          let posixError = cocoaError.underlying as? POSIXError else {
                        return false
                    }
                    #expect(posixError.code == .ENAMETOOLONG, "removeItem didn't fail with ENAMETOOLONG; produced error: \(error)")
                    return true
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
            #expect($0.fileExists(atPath: "dir/foo", isDirectory: &isDir))
            #expect(isDirBool() == false)
            #expect($0.fileExists(atPath: "dir/bar", isDirectory: &isDir))
            #expect(isDirBool() == false)
            #expect($0.fileExists(atPath: "dir", isDirectory: &isDir))
            #expect(isDirBool())
            #expect($0.fileExists(atPath: "other", isDirectory: &isDir))
            #expect(isDirBool() == false)
            #expect($0.fileExists(atPath: "does_not_exist") == false)
        }
    }

    @Test(.enabled(
        if: getuid() != 0,
        "Root users can always access anything, so this test will not function when run as root")
    )
    func testFileAccessAtPath() throws {
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
                #expect($0.isReadableFile(atPath: file) == readable.contains(file), "'\(file)' failed readable check")
                #expect($0.isWritableFile(atPath: file) == writable.contains(file), "'\(file)' failed writable check")
                #expect($0.isExecutableFile(atPath: file) == executable.contains(file), "'\(file)' failed executable check")
                #expect($0.isDeletableFile(atPath: file), "'\(file)' failed deletable check")
            }
        }
    }
    
    @Test func testFileSystemAttributesAtPath() throws {
        try FileManagerPlayground {
            "Foo"
        }.test { fileManager in
            let dict = try fileManager.attributesOfFileSystem(forPath: "Foo")
            #expect(dict[.systemSize] != nil)
            #expect {
                try fileManager.attributesOfFileSystem(forPath: "does_not_exist")
            } throws: { error in
                guard let cocoaError = error as? CocoaError else {
                    return false
                }
                #expect(cocoaError.code == .fileReadNoSuchFile)
                return true
            }
        }
    }
    
    @Test func testCurrentWorkingDirectory() throws {
        try FileManagerPlayground {
            Directory("dir") {
                "foo"
            }
            "bar"
        }.test { (fileManager) throws in
            var results = try fileManager.subpathsOfDirectory(atPath: ".").sorted()
            #expect(results == ["bar", "dir", "dir/foo"])
            #expect(fileManager.changeCurrentDirectoryPath("dir"))
            results = try fileManager.subpathsOfDirectory(atPath: ".")
            #expect(results == ["foo"])
            #expect(fileManager.changeCurrentDirectoryPath("foo") == false)
            #expect(fileManager.changeCurrentDirectoryPath(".."))
            results = try fileManager.subpathsOfDirectory(atPath: ".").sorted()
            #expect(results == ["bar", "dir", "dir/foo"])
            #expect(fileManager.changeCurrentDirectoryPath("does_not_exist") == false)
        }
    }
    
#if canImport(Darwin)
    @Test func testBooleanFileAttributes() throws {
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
                #expect(result[.immutable] as? Bool == test.immutable, "Item at path '\(test.path)' did not provide expected result for immutable key")
                #expect(result[.appendOnly] as? Bool == test.appendOnly, "Item at path '\(test.path)' did not provide expected result for appendOnly key")

                // Manually clean up attributes so removal does not fail
                try $0.setAttributes([.immutable: false, .appendOnly: false], ofItemAtPath: test.path)
            }
        }
    }
#endif

    @Test func testMalformedModificationDateAttribute() throws {
        let sentinelDate = Date(timeIntervalSince1970: 100)
        try FileManagerPlayground {
            File("foo", attributes: [.modificationDate: sentinelDate])
        }.test {
            var results = try $0.attributesOfItem(atPath: "foo")[.modificationDate] as? Date
            #expect(results == sentinelDate)
            for value in [Double.infinity, -Double.infinity, Double.nan] {
                // Malformed modification dates should be dropped instead of throwing or crashing
                try $0.setAttributes([.modificationDate : Date(timeIntervalSince1970: value)], ofItemAtPath: "foo")
            }
            results = try $0.attributesOfItem(atPath: "foo")[.modificationDate] as? Date
            #expect(results == sentinelDate)
        }
    }
    
    @Test func testImplicitlyConvertibleFileAttributes() throws {
        try FileManagerPlayground {
            File("foo", attributes: [.posixPermissions : UInt16(0o644)])
        }.test {
            let attributes = try $0.attributesOfItem(atPath: "foo")
            // Ensure the unconventional UInt16 was accepted as input
            #expect(attributes[.posixPermissions] as? UInt == 0o644)
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
    
#if canImport(Darwin)
    @Test func testStandardizingPathAutomount() throws {
        let tests = [
            "/private/System" : "/private/System",
            "/private/tmp" : "/tmp",
            "/private/System/foo" : "/private/System/foo"
        ]
        for (input, expected) in tests {
            #expect(input.standardizingPath == expected, "Standardizing the path '\(input)' did not produce the expected result")
        }
    }
#endif

    @Test func testResolveSymlinksViaGetAttrList() throws {
        try FileManagerPlayground {
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
        try FileManagerPlayground {}.test {
            if let trashURL = try? $0.url(for: .trashDirectory, in: .allDomainsMask, appropriateFor: nil, create: false) {
                #expect(trashURL.pathComponents.last == ".Trash")
            }
        }
    }
    #endif
}
