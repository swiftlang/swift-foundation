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

#if !FOUNDATION_FRAMEWORK

public struct FileAttributeType : Hashable, RawRepresentable, Sendable {
    public let rawValue: String
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
    
    public static let typeBlockSpecial: Self = Self("NSFileTypeBlockSpecial")
    public static let typeCharacterSpecial: Self = Self("NSFileTypeCharacterSpecial")
    public static let typeDirectory: Self = Self("NSFileTypeDirectory")
    public static let typeRegular: Self = Self("NSFileTypeRegular")
    public static let typeSocket: Self = Self("NSFileTypeSocket")
    public static let typeSymbolicLink: Self = Self("NSFileTypeSymbolicLink")
    public static let typeUnknown: Self = Self("NSFileTypeUnknown")
}

public struct FileAttributeKey: Hashable, RawRepresentable, Sendable {
    public typealias RawValue = String
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
    
    public static let type = Self(rawValue: "NSFileType")
    public static let size = Self(rawValue: "NSFileSize")
    public static let modificationDate = Self(rawValue: "NSFileModificationDate")
    public static let referenceCount = Self(rawValue: "NSFileCount")
    public static let deviceIdentifier = Self(rawValue: "NSFileDeviceIdentifier")
    public static let ownerAccountName = Self(rawValue: "NSFileOwnerAccountName")
    public static let groupOwnerAccountName = Self(rawValue: "NSFileGroupOwnerAccountName")
    public static let posixPermissions = Self(rawValue: "NSFilePosixPermissions")
    public static let systemNumber = Self(rawValue: "NSFileSystemNumber")
    public static let systemFileNumber = Self(rawValue: "NSFileSystemFileNumber")
    public static let extensionHidden = Self(rawValue: "NSFileExtensionHidden")
    public static let hfsCreatorCode = Self(rawValue: "NSFileHFSCreatorCode")
    public static let hfsTypeCode = Self(rawValue: "NSFileHFSTypeCode")
    public static let immutable = Self(rawValue: "NSFileImmutable")
    public static let appendOnly = Self(rawValue: "NSFileAppendOnly")
    public static let creationDate = Self(rawValue: "NSFileCreationDate")
    public static let ownerAccountID = Self(rawValue: "NSFileOwnerAccountID")
    public static let groupOwnerAccountID = Self(rawValue: "NSFileGroupOwnerAccountID")
    public static let busy = Self(rawValue: "NSFileBusy")
    public static let protectionKey = Self(rawValue: "NSFileProtectionKey")
    public static let systemSize = Self(rawValue: "NSFileSystemSize")
    public static let systemFreeSize = Self(rawValue: "NSFileSystemFreeSize")
    public static let systemNodes = Self(rawValue: "NSFileSystemNodes")
    public static let systemFreeNodes = Self(rawValue: "NSFileSystemFreeNodes")
}

public struct FileProtectionType : RawRepresentable, Sendable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public static let none = Self(rawValue: "NSFileProtectionNone")
    public static let complete = Self(rawValue: "NSFileProtectionComplete")
    public static let completeUnlessOpen = Self(rawValue: "NSFileProtectionCompleteUnlessOpen")
    public static let completeUntilFirstUserAuthentication = Self(rawValue: "NSFileProtectionCompleteUntilFirstUserAuthentication")
    public static let inactive = Self(rawValue: "NSFileProtectionCompleteWhenUserInactive")
}

extension FileManager {
    public struct UnmountOptions : OptionSet, Sendable {
        public let rawValue: UInt
        
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }
        
        public static let allPartitionsAndEjectDisk = Self(rawValue: 1 << 0)
        public static let withoutUI = Self(rawValue: 1 << 1)
    }
    
    public struct DirectoryEnumerationOptions : OptionSet, Sendable {
        public let rawValue: UInt
        
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }
        
        public static let skipsSubdirectoryDescendants = Self(rawValue: 1 << 0)
        public static let skipsPackageDescendants = Self(rawValue: 1 << 1)
        public static let skipsHiddenFiles = Self(rawValue: 1 << 2)
        public static let includesDirectoriesPostOrder = Self(rawValue: 1 << 3)
        public static let producesRelativePathURLs = Self(rawValue: 1 << 4)
    }
    
    public enum SearchPathDirectory : UInt, Sendable {
        // The following are Darwin-only and will not produce directories on non-Darwin
        case applicationDirectory = 1
        case demoApplicationDirectory = 2
        case developerApplicationDirectory = 3
        case adminApplicationDirectory = 4
        case libraryDirectory = 5
        case developerDirectory = 6
        case documentationDirectory = 8
        case coreServiceDirectory = 10
        case inputMethodsDirectory = 16
        case preferencePanesDirectory = 22
        case allApplicationsDirectory = 100
        case allLibrariesDirectory = 101
        case itemReplacementDirectory = 99
        case printerDescriptionDirectory = 20
        
        // The following will not produce paths in swift-foundation because it requires the code signing identifier
        case applicationScriptsDirectory = 23
        
        // The following are cross-platform and may produce valid paths on non-Darwin
        case userDirectory = 7
        case documentDirectory = 9
        case autosavedInformationDirectory = 11
        case desktopDirectory = 12
        case cachesDirectory = 13
        case applicationSupportDirectory = 14
        case downloadsDirectory = 15
        case moviesDirectory = 17
        case musicDirectory = 18
        case picturesDirectory = 19
        case sharedPublicDirectory = 21
        case trashDirectory = 102
    }
    
    public struct SearchPathDomainMask : OptionSet, Sendable {
        public let rawValue: UInt
        
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        public static let userDomainMask = Self(rawValue: 1 << 0)
        public static let localDomainMask = Self(rawValue: 1 << 1)
        public static let networkDomainMask = Self(rawValue: 1 << 2)
        public static let systemDomainMask = Self(rawValue: 1 << 3)
        public static let allDomainsMask = Self(rawValue: 0xFFFF)
    }
    
    public enum URLRelationship : Int, Sendable {
        case contains = 0
        case same = 1
        case other = 2
    }
    
    public struct ItemReplacementOptions : OptionSet, Sendable {
        public let rawValue: UInt
        
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }
        
        public static let usingNewMetadataOnly = Self(rawValue: 1 << 0)
        public static let withoutDeletingBackupItem = Self(rawValue: 1 << 1)
    }
}

open class FileManager : @unchecked Sendable {
    // Sendable note: _impl may only be mutated in `init`
    private var _impl: _FileManagerImpl
    private let _lock = LockedState<State>(initialState: .init(delegate: nil))
    
    private static let _default = FileManager()
    open class var `default`: FileManager {
        _default
    }
    
    private struct State {
        weak var delegate: (any FileManagerDelegate)?
    }

    open weak var delegate: (any FileManagerDelegate)? {
        get {
            _lock.withLock { $0.delegate }
        }
        set {
            _lock.withLock { $0.delegate = newValue }
        }
    }
    
    public init() {
        _impl = _FileManagerImpl()
        _impl._manager = self
    }

    open func setAttributes(_ attributes: [FileAttributeKey : Any], ofItemAtPath path: String) throws {
        try _impl.setAttributes(attributes, ofItemAtPath: path)
    }

    open func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey : Any]? = nil) throws {
        try _impl.createDirectory(at: url, withIntermediateDirectories: createIntermediates, attributes: attributes)
    }

    open func createDirectory(atPath path: String, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey : Any]? = nil) throws {
        try _impl.createDirectory(atPath: path, withIntermediateDirectories: createIntermediates, attributes: attributes)
    }

    open func contentsOfDirectory(atPath path: String) throws -> [String] {
        try _impl.contentsOfDirectory(atPath: path)
    }

    open func subpathsOfDirectory(atPath path: String) throws -> [String] {
        try _impl.subpathsOfDirectory(atPath: path)
    }
    
    open func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL] {
        _impl.urls(for: directory, in: domainMask)
    }
    
    open func url(for directory: FileManager.SearchPathDirectory, in domain: FileManager.SearchPathDomainMask, appropriateFor url: URL?, create shouldCreate: Bool) throws -> URL {
        try _impl.url(for: directory, in: domain, appropriateFor: url, create: shouldCreate)
    }

    open func attributesOfItem(atPath path: String) throws -> [FileAttributeKey : Any] {
        try _impl.attributesOfItem(atPath: path)
    }

    open func attributesOfFileSystem(forPath path: String) throws -> [FileAttributeKey : Any] {
        try _impl.attributesOfFileSystem(forPath: path)
    }

    open func createSymbolicLink(atPath path: String, withDestinationPath destPath: String) throws {
        try _impl.createSymbolicLink(atPath: path, withDestinationPath: destPath)
    }
    
    open func createSymbolicLink(at url: URL, withDestinationURL destURL: URL) throws {
        try _impl.createSymbolicLink(at: url, withDestinationURL: destURL)
    }

    open func destinationOfSymbolicLink(atPath path: String) throws -> String {
        try _impl.destinationOfSymbolicLink(atPath: path)
    }

    open func copyItem(atPath srcPath: String, toPath dstPath: String) throws {
        try _impl.copyItem(atPath: srcPath, toPath: dstPath, options: [])
    }

    open func moveItem(atPath srcPath: String, toPath dstPath: String) throws {
        try _impl.moveItem(atPath: srcPath, toPath: dstPath, options: [])
    }

    open func linkItem(atPath srcPath: String, toPath dstPath: String) throws {
        try _impl.linkItem(atPath: srcPath, toPath: dstPath)
    }

    open func removeItem(atPath path: String) throws {
        try _impl.removeItem(atPath: path)
    }

    open func copyItem(at srcURL: URL, to dstURL: URL) throws {
        try _impl.copyItem(at: srcURL, to: dstURL, options: [])
    }

    open func moveItem(at srcURL: URL, to dstURL: URL) throws {
        try _impl.moveItem(at: srcURL, to: dstURL, options: [])
    }

    open func linkItem(at srcURL: URL, to dstURL: URL) throws {
        try _impl.linkItem(at: srcURL, to: dstURL)
    }

    open func removeItem(at URL: URL) throws {
        try _impl.removeItem(at: URL)
    }

    open var currentDirectoryPath: String {
        _impl.currentDirectoryPath ?? ""
    }

    open func changeCurrentDirectoryPath(_ path: String) -> Bool {
        _impl.changeCurrentDirectoryPath(path)
    }

    open func fileExists(atPath path: String) -> Bool {
        _impl.fileExists(atPath: path)
    }

    open func fileExists(atPath path: String, isDirectory: inout Bool) -> Bool {
        _impl.fileExists(atPath: path, isDirectory: &isDirectory)
    }

    open func isReadableFile(atPath path: String) -> Bool {
        _impl.isReadableFile(atPath: path)
    }

    open func isWritableFile(atPath path: String) -> Bool {
        _impl.isWritableFile(atPath: path)
    }

    open func isExecutableFile(atPath path: String) -> Bool {
        _impl.isExecutableFile(atPath: path)
    }

    open func isDeletableFile(atPath path: String) -> Bool {
        _impl.isDeletableFile(atPath: path)
    }

    open func contentsEqual(atPath path1: String, andPath path2: String) -> Bool {
        _impl.contentsEqual(atPath: path1, andPath: path2)
    }
    
    open func contents(atPath path: String) -> Data? {
        _impl.contents(atPath: path)
    }

    open func createFile(atPath path: String, contents data: Data?, attributes attr: [FileAttributeKey : Any]? = nil) -> Bool {
        _impl.createFile(atPath: path, contents: data, attributes: attr)
    }

    open func string(withFileSystemRepresentation str: UnsafePointer<CChar>, length len: Int) -> String {
        _impl.string(withFileSystemRepresentation: str, length: len)
    }
    
    open func withFileSystemRepresentation<R>(for path: String, _ body: (UnsafePointer<CChar>?) throws -> R) rethrows -> R {
        try path.withFileSystemRepresentation(body)
    }

    open var temporaryDirectory: URL {
        _impl.temporaryDirectory
    }
    
    @available(iOS, unavailable)
    @available(watchOS, unavailable)
    @available(tvOS, unavailable)
    open var homeDirectoryForCurrentUser: URL {
        _impl.homeDirectoryForCurrentUser
    }

    @available(iOS, unavailable)
    @available(watchOS, unavailable)
    @available(tvOS, unavailable)
    open func homeDirectory(forUser userName: String) -> URL? {
        _impl.homeDirectory(forUser: userName)
    }
}

#endif
