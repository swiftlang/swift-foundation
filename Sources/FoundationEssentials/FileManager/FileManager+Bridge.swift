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

#if FOUNDATION_FRAMEWORK

internal import Foundation_Private.NSFileManager

@objc(_NSFileManagerBridge)
@objcMembers
final class _NSFileManagerBridge : NSObject {
    private let _impl: _FileManagerImpl
    
    @objc(initWithFileManager:)
    init(implementing manager: FileManager) {
        var impl = _FileManagerImpl()
        impl._manager = manager
        self._impl = impl
        super.init()
    }
    
    func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL] {
        _impl.urls(for: directory, in: domainMask)
    }

    func url(for directory: FileManager.SearchPathDirectory, in domain: FileManager.SearchPathDomainMask, appropriateFor url: URL?, create shouldCreate: Bool) throws -> URL {
        try _impl.url(for: directory, in: domain, appropriateFor: url, create: shouldCreate)
    }
    
    func getRelationship(_ outRelationship: UnsafeMutablePointer<FileManager.URLRelationship>, ofDirectoryAt directoryURL: URL, toItemAt otherURL: URL) throws {
        try _impl.getRelationship(outRelationship, ofDirectoryAt: directoryURL, toItemAt: otherURL)
    }

    func getRelationship(_ outRelationship: UnsafeMutablePointer<FileManager.URLRelationship>, of directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask, toItemAt url: URL) throws {
        try _impl.getRelationship(outRelationship, of: directory, in: domainMask, toItemAt: url)
    }

    func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey : Any]? = nil) throws {
        try _impl.createDirectory(at: url, withIntermediateDirectories: createIntermediates, attributes: attributes)
    }

    func createSymbolicLink(at url: URL, withDestinationURL destURL: URL) throws {
        try _impl.createSymbolicLink(at: url, withDestinationURL: destURL)
    }

    func setAttributes(_ attributes: [FileAttributeKey : Any], ofItemAtPath path: String) throws {
        try _impl.setAttributes(attributes, ofItemAtPath: path)
    }

    func createDirectory(atPath path: String, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey : Any]? = nil) throws {
        try _impl.createDirectory(atPath: path, withIntermediateDirectories: createIntermediates, attributes: attributes)
    }

    func contentsOfDirectory(atPath path: String) throws -> [String] {
        try _impl.contentsOfDirectory(atPath: path)
    }

    func subpathsOfDirectory(atPath path: String) throws -> [String] {
        try _impl.subpathsOfDirectory(atPath: path)
    }

    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey : Any] {
        try _impl.attributesOfItem(atPath: path)
    }

    func attributesOfFileSystem(forPath path: String) throws -> [FileAttributeKey : Any] {
        try _impl.attributesOfFileSystem(forPath: path)
    }

    func createSymbolicLink(atPath path: String, withDestinationPath destPath: String) throws {
        try _impl.createSymbolicLink(atPath: path, withDestinationPath: destPath)
    }

    func destinationOfSymbolicLink(atPath path: String) throws -> String {
        try _impl.destinationOfSymbolicLink(atPath: path)
    }

    func copyItem(atPath srcPath: String, toPath dstPath: String, options: NSFileManagerCopyOptions) throws {
        try _impl.copyItem(atPath: srcPath, toPath: dstPath, options: options)
    }

    func moveItem(atPath srcPath: String, toPath dstPath: String, options: NSFileManagerMoveOptions) throws {
        try _impl.moveItem(atPath: srcPath, toPath: dstPath, options: options)
    }

    func linkItem(atPath srcPath: String, toPath dstPath: String) throws {
        try _impl.linkItem(atPath: srcPath, toPath: dstPath)
    }

    func removeItem(atPath path: String) throws {
        try _impl.removeItem(atPath: path)
    }

    func copyItem(at srcURL: URL, to dstURL: URL, options: NSFileManagerCopyOptions) throws {
        try _impl.copyItem(at: srcURL, to: dstURL, options: options)
    }

    func moveItem(at srcURL: URL, to dstURL: URL, options: NSFileManagerMoveOptions) throws {
        try _impl.moveItem(at: srcURL, to: dstURL, options: options)
    }

    func linkItem(at srcURL: URL, to dstURL: URL) throws {
        try _impl.linkItem(at: srcURL, to: dstURL)
    }

    func removeItem(at URL: URL) throws {
        try _impl.removeItem(at: URL)
    }

    var currentDirectoryPath: String? {
        _impl.currentDirectoryPath
    }

    func changeCurrentDirectoryPath(_ path: String) -> Bool {
        _impl.changeCurrentDirectoryPath(path)
    }

    func fileExists(atPath path: String) -> Bool {
        _impl.fileExists(atPath: path)
    }

    func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
        var dir = false
        guard _impl.fileExists(atPath: path, isDirectory: &dir) else {
            return false
        }
        if let isDirectory {
            isDirectory.pointee = ObjCBool(dir)
        }
        return true
    }

    func isReadableFile(atPath path: String) -> Bool {
        _impl.isReadableFile(atPath: path)
    }

    func isWritableFile(atPath path: String) -> Bool {
        _impl.isWritableFile(atPath: path)
    }

    func isExecutableFile(atPath path: String) -> Bool {
        _impl.isExecutableFile(atPath: path)
    }

    func isDeletableFile(atPath path: String) -> Bool {
        _impl.isDeletableFile(atPath: path)
    }

    func contentsEqual(atPath path1: String, andPath path2: String) -> Bool {
        _impl.contentsEqual(atPath: path1, andPath: path2)
    }

    func displayName(atPath path: String) -> String {
        _impl.displayName(atPath: path)
    }
    
    func contents(atPath path: String) -> Data? {
        _impl.contents(atPath: path)
    }

    func createFile(atPath path: String, contents data: Data?, attributes attr: [FileAttributeKey : Any]? = nil) -> Bool {
        _impl.createFile(atPath: path, contents: data, attributes: attr)
    }

    func string(withFileSystemRepresentation str: UnsafePointer<CChar>, length len: Int) -> String {
        _impl.string(withFileSystemRepresentation: str, length: len)
    }
    
    func withFileSystemRepresentation<R>(for path: String, _ body: (UnsafePointer<CChar>?) throws -> R) rethrows -> R {
        try path.withFileSystemRepresentation(body)
    }

    var homeDirectoryForCurrentUser: URL {
        _impl.homeDirectoryForCurrentUser
    }

    var temporaryDirectory: URL {
        _impl.temporaryDirectory
    }
    
    func homeDirectory(forUser userName: String?) -> URL? {
        _impl.homeDirectory(forUser: userName)
    }
}

#endif
