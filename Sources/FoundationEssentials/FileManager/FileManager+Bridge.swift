//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if !hasFeature(Embedded)

#if FOUNDATION_FRAMEWORK

internal import Foundation_Private.NSFileManager

@objc(_NSFileManagerBridge)
@objcMembers
final class _NSFileManagerBridge : NSObject {
    private weak var _manager: FileManager?
    
    private var fileManager: FileManager {
        guard let _manager else {
            fatalError("_NSFileManagerBridge called without a valid reference to a FileManager")
        }
        return _manager
    }
    
    @objc(initWithFileManager:)
    init(implementing manager: FileManager) {
        self._manager = manager
        super.init()
    }
    
    func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL] {
        _FileManagerImpl.urls(fileManager, for: directory, in: domainMask)
    }

    func url(for directory: FileManager.SearchPathDirectory, in domain: FileManager.SearchPathDomainMask, appropriateFor url: URL?, create shouldCreate: Bool) throws -> URL {
        try _FileManagerImpl.url(fileManager, for: directory, in: domain, appropriateFor: url, create: shouldCreate)
    }
    
    func getRelationship(_ outRelationship: UnsafeMutablePointer<FileManager.URLRelationship>, ofDirectoryAt directoryURL: URL, toItemAt otherURL: URL) throws {
        try _FileManagerImpl.getRelationship(fileManager, outRelationship, ofDirectoryAt: directoryURL, toItemAt: otherURL)
    }

    func getRelationship(_ outRelationship: UnsafeMutablePointer<FileManager.URLRelationship>, of directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask, toItemAt url: URL) throws {
        try _FileManagerImpl.getRelationship(fileManager, outRelationship, of: directory, in: domainMask, toItemAt: url)
    }

    func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey : Any]? = nil) throws {
        try _FileManagerImpl.createDirectory(fileManager, at: url, withIntermediateDirectories: createIntermediates, attributes: attributes)
    }

    func createSymbolicLink(at url: URL, withDestinationURL destURL: URL) throws {
        try _FileManagerImpl.createSymbolicLink(fileManager, at: url, withDestinationURL: destURL)
    }

    func setAttributes(_ attributes: [FileAttributeKey : Any], ofItemAtPath path: String) throws {
        try _FileManagerImpl.setAttributes(fileManager, attributes, ofItemAtPath: path)
    }

    func createDirectory(atPath path: String, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey : Any]? = nil) throws {
        try _FileManagerImpl.createDirectory(fileManager, atPath: path, withIntermediateDirectories: createIntermediates, attributes: attributes)
    }

    func contentsOfDirectory(atPath path: String) throws -> [String] {
        try _FileManagerImpl.contentsOfDirectory(fileManager, atPath: path)
    }

    func subpathsOfDirectory(atPath path: String) throws -> [String] {
        try _FileManagerImpl.subpathsOfDirectory(fileManager, atPath: path)
    }

    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey : Any] {
        try _FileManagerImpl.attributesOfItem(fileManager, atPath: path)
    }

    func attributesOfFileSystem(forPath path: String) throws -> [FileAttributeKey : Any] {
        try _FileManagerImpl.attributesOfFileSystem(fileManager, forPath: path)
    }

    func createSymbolicLink(atPath path: String, withDestinationPath destPath: String) throws {
        try _FileManagerImpl.createSymbolicLink(fileManager, atPath: path, withDestinationPath: destPath)
    }

    func destinationOfSymbolicLink(atPath path: String) throws -> String {
        try _FileManagerImpl.destinationOfSymbolicLink(fileManager, atPath: path)
    }

    func copyItem(atPath srcPath: String, toPath dstPath: String, options: NSFileManagerCopyOptions) throws {
        try _FileManagerImpl.copyItem(fileManager, atPath: srcPath, toPath: dstPath, options: options)
    }

    func moveItem(atPath srcPath: String, toPath dstPath: String, options: NSFileManagerMoveOptions) throws {
        try _FileManagerImpl.moveItem(fileManager, atPath: srcPath, toPath: dstPath, options: options)
    }

    func linkItem(atPath srcPath: String, toPath dstPath: String) throws {
        try _FileManagerImpl.linkItem(fileManager, atPath: srcPath, toPath: dstPath)
    }

    func removeItem(atPath path: String) throws {
        try _FileManagerImpl.removeItem(fileManager, atPath: path)
    }

    func copyItem(at srcURL: URL, to dstURL: URL, options: NSFileManagerCopyOptions) throws {
        try _FileManagerImpl.copyItem(fileManager, at: srcURL, to: dstURL, options: options)
    }

    func moveItem(at srcURL: URL, to dstURL: URL, options: NSFileManagerMoveOptions) throws {
        try _FileManagerImpl.moveItem(fileManager, at: srcURL, to: dstURL, options: options)
    }

    func linkItem(at srcURL: URL, to dstURL: URL) throws {
        try _FileManagerImpl.linkItem(fileManager, at: srcURL, to: dstURL)
    }

    func removeItem(at URL: URL) throws {
        try _FileManagerImpl.removeItem(fileManager, at: URL)
    }

    var currentDirectoryPath: String? {
        _FileManagerImpl.currentDirectoryPath(fileManager)
    }

    func changeCurrentDirectoryPath(_ path: String) -> Bool {
        _FileManagerImpl.changeCurrentDirectoryPath(fileManager, path)
    }

    func fileExists(atPath path: String) -> Bool {
        _FileManagerImpl.fileExists(fileManager, atPath: path)
    }

    func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
        var dir = false
        guard _FileManagerImpl.fileExists(fileManager, atPath: path, isDirectory: &dir) else {
            return false
        }
        if let isDirectory {
            isDirectory.pointee = ObjCBool(dir)
        }
        return true
    }

    func isReadableFile(atPath path: String) -> Bool {
        _FileManagerImpl.isReadableFile(fileManager, atPath: path)
    }

    func isWritableFile(atPath path: String) -> Bool {
        _FileManagerImpl.isWritableFile(fileManager, atPath: path)
    }

    func isExecutableFile(atPath path: String) -> Bool {
        _FileManagerImpl.isExecutableFile(fileManager, atPath: path)
    }

    func isDeletableFile(atPath path: String) -> Bool {
        _FileManagerImpl.isDeletableFile(fileManager, atPath: path)
    }

    func contentsEqual(atPath path1: String, andPath path2: String) -> Bool {
        _FileManagerImpl.contentsEqual(fileManager, atPath: path1, andPath: path2)
    }

    func displayName(atPath path: String) -> String {
        _FileManagerImpl.displayName(fileManager, atPath: path)
    }
    
    func contents(atPath path: String) -> Data? {
        _FileManagerImpl.contents(fileManager, atPath: path)
    }

    func createFile(atPath path: String, contents data: Data?, attributes attr: [FileAttributeKey : Any]? = nil) -> Bool {
        _FileManagerImpl.createFile(fileManager, atPath: path, contents: data, attributes: attr)
    }

    func string(withFileSystemRepresentation str: UnsafePointer<CChar>, length len: Int) -> String {
        _FileManagerImpl.string(fileManager, withFileSystemRepresentation: str, length: len)
    }
    
    func withFileSystemRepresentation<R>(for path: String, _ body: (UnsafePointer<CChar>?) throws -> R) rethrows -> R {
        try path.withFileSystemRepresentation(body)
    }

    var homeDirectoryForCurrentUser: URL {
        _FileManagerImpl.homeDirectoryForCurrentUser(fileManager)
    }

    var temporaryDirectory: URL {
        _FileManagerImpl.temporaryDirectory(fileManager)
    }
    
    func homeDirectory(forUser userName: String?) -> URL? {
        _FileManagerImpl.homeDirectory(fileManager, forUser: userName)
    }
}

#endif

#endif // !hasFeature(Embedded)
