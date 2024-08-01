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
internal import DarwinPrivate.sys.content_protection
#endif

#if canImport(Darwin)
import Darwin
#elseif os(Android)
import Android
import posix_filesystem
#elseif canImport(Glibc)
import Glibc
internal import _FoundationCShims
#elseif os(Windows)
import CRT
import WinSDK
#endif

extension Date {
    fileprivate init(seconds: TimeInterval, nanoSeconds: TimeInterval) {
        self.init(timeIntervalSinceReferenceDate: seconds - Self.timeIntervalBetween1970AndReferenceDate + nanoSeconds / 1_000_000_000.0 )
    }
}

#if !os(Windows)
#if !os(WASI)
private func _nameFor(uid: uid_t) -> String? {
    guard let pwd = getpwuid(uid), let name = pwd.pointee.pw_name else {
        return nil
    }
    return String(cString: name)
}

private func _nameFor(gid: gid_t) -> String? {
    guard let pwd = getgrgid(gid), let name = pwd.pointee.gr_name else {
        return nil
    }
    return String(cString: name)
}
#endif

extension mode_t {
    private var _fileType: FileAttributeType {
        switch self & S_IFMT {
        case S_IFCHR: .typeCharacterSpecial
        case S_IFDIR: .typeDirectory
        case S_IFBLK: .typeBlockSpecial
        case S_IFREG: .typeRegular
        case S_IFLNK: .typeSymbolicLink
        case S_IFSOCK: .typeSocket
        default: .typeUnknown
        }
    }
    
    #if FOUNDATION_FRAMEWORK
    // Since FileAttributeType is an NS_TYPED_ENUM, clients rely on being able to cast values to both String and FileAttributeType
    // Store NSString values in attribute dictionaries to support both of these casting behaviors
    fileprivate var fileType: NSString { _fileType as NSString }
    #else
    // In swift-foundation, use FileAttributeType values instead since NSString doesn't exist
    fileprivate var fileType: FileAttributeType { _fileType }
    #endif
}
#endif

func _readFileAttributePrimitive<T: BinaryInteger>(_ value: Any?, as type: T.Type) -> T? {
    guard let value else { return nil }
    #if FOUNDATION_FRAMEWORK
    if let nsNumber = value as? NSNumber, let result = nsNumber as? T {
        return result
    }
    #endif
    
    if let exact = value as? T {
        return exact
    } else if let binInt = value as? (any BinaryInteger), let result = T(exactly: binInt) {
        return result
    }
    return nil
}

func _readFileAttributePrimitive(_ value: Any?, as type: Bool.Type) -> Bool? {
    guard let value else { return nil }
    #if FOUNDATION_FRAMEWORK
    if let nsNumber = value as? NSNumber, let result = nsNumber as? Bool {
        return result
    }
    #endif
    
    if let boolValue = value as? Bool {
        return boolValue
    } else if let binInt = value as? (any BinaryInteger), let result = Int(exactly: binInt) {
        switch result {
        case 0: return false
        case 1: return true
        default: return nil
        }
    }
    return nil
}

#if !FOUNDATION_FRAMEWORK
@_spi(SwiftCorelibsFoundation)
public protocol _NSNumberInitializer {
    static func initialize(value: Bool) -> Any
    static func initialize(value: some BinaryInteger) -> Any
}

@_spi(SwiftCorelibsFoundation)
dynamic public func _nsNumberInitializer() -> (any _NSNumberInitializer.Type)? {
    // TODO: return nil here after swift-corelibs-foundation begins dynamically replacing this function
    _typeByName("Foundation._FoundationNSNumberInitializer") as? any _NSNumberInitializer.Type
}
#endif

func _writeFileAttributePrimitive<T: BinaryInteger, U: BinaryInteger>(_ value: T, as type: U.Type) -> Any {
    #if FOUNDATION_FRAMEWORK
    if let int = Int64(exactly: value) {
        NSNumber(value: int)
    } else {
        NSNumber(value: UInt64(value))
    }
    #else
    if let ns = _nsNumberInitializer()?.initialize(value: value) {
        return ns
    } else {
        return U(value)
    }
    #endif
}

func _writeFileAttributePrimitive(_ value: Bool) -> Any {
    #if FOUNDATION_FRAMEWORK
    NSNumber(value: value)
    #else
    if let ns = _nsNumberInitializer()?.initialize(value: value) {
        return ns
    } else {
        return value
    }
    #endif
}

#if !os(Windows)
extension stat {
    var modificationDate: Date {
        #if canImport(Darwin)
        Date(seconds: TimeInterval(st_mtimespec.tv_sec), nanoSeconds: TimeInterval(st_mtimespec.tv_nsec))
        #else
        Date(seconds: TimeInterval(st_mtim.tv_sec), nanoSeconds: TimeInterval(st_mtim.tv_nsec))
        #endif
    }
    
    var creationDate: Date {
        #if canImport(Darwin)
        Date(seconds: TimeInterval(st_ctimespec.tv_sec), nanoSeconds: TimeInterval(st_ctimespec.tv_nsec))
        #else
        Date(seconds: TimeInterval(st_ctim.tv_sec), nanoSeconds: TimeInterval(st_ctim.tv_nsec))
        #endif
    }
    
    fileprivate var fileAttributes: [FileAttributeKey : Any] {
        let fileType = st_mode.fileType
        var result: [FileAttributeKey : Any] = [
            .size : _writeFileAttributePrimitive(st_size, as: UInt.self),
            .modificationDate : modificationDate,
            .creationDate : creationDate,
            .posixPermissions : _writeFileAttributePrimitive(st_mode & 0o7777, as: UInt.self),
            .referenceCount : _writeFileAttributePrimitive(st_nlink, as: UInt.self),
            .systemNumber : _writeFileAttributePrimitive(st_dev, as: UInt.self),
            .systemFileNumber : _writeFileAttributePrimitive(st_ino, as: UInt64.self),
            .type : fileType,
            .ownerAccountID : _writeFileAttributePrimitive(st_uid, as: UInt.self),
            .groupOwnerAccountID : _writeFileAttributePrimitive(st_gid, as: UInt.self)
        ]
        #if !os(WASI)
        if let userName = _nameFor(uid: st_uid) {
            result[.ownerAccountName] = userName
        }
        if let groupName = _nameFor(gid: st_gid) {
            result[.groupOwnerAccountName] = groupName
        }
        #endif
        switch fileType as FileAttributeType {
        case .typeBlockSpecial, .typeCharacterSpecial:
            result[.deviceIdentifier] = _writeFileAttributePrimitive(st_rdev, as: UInt.self)
        default:
            // Do nothing
            break
        }
        #if canImport(Darwin)
        let immutable = (st_flags & UInt32(UF_IMMUTABLE)) != 0 || (st_flags & UInt32(SF_IMMUTABLE)) != 0
        result[.immutable] = _writeFileAttributePrimitive(immutable)
        let appendOnly = (st_flags & UInt32(UF_APPEND)) != 0 || (st_flags & UInt32(SF_APPEND)) != 0
        result[.appendOnly] = _writeFileAttributePrimitive(appendOnly)
        #endif
        return result
    }
}

#if FOUNDATION_FRAMEWORK
extension FileProtectionType {
    var intValue: Int32? {
        switch self {
        case .complete: PROTECTION_CLASS_A
        case .init(rawValue: "NSFileProtectionWriteOnly"), .completeUnlessOpen: PROTECTION_CLASS_B
        case .init(rawValue: "NSFileProtectionCompleteUntilUserAuthentication"), .completeUntilFirstUserAuthentication: PROTECTION_CLASS_C
        case .none: PROTECTION_CLASS_D
        #if !os(macOS)
        case .completeWhenUserInactive: PROTECTION_CLASS_CX
        #endif
        default: nil
        }
    }
    
    init?(intValue value: Int32) {
        switch value {
        case PROTECTION_CLASS_A: self = .complete
        case PROTECTION_CLASS_B: self = .completeUnlessOpen
        case PROTECTION_CLASS_C: self = .completeUntilFirstUserAuthentication
        case PROTECTION_CLASS_D: self = .none
        #if !os(macOS)
        case PROTECTION_CLASS_CX: self = .completeWhenUserInactive
        #endif
        default: return nil
        }
    }
}
#endif
#endif

extension FileAttributeKey {
    fileprivate static var _extendedAttributes: Self { Self("NSFileExtendedAttributes") }
}

extension _FileManagerImpl {
    func createFile(
        atPath path: String,
        contents data: Data?,
        attributes attr: [FileAttributeKey : Any]? = nil
    ) -> Bool {
        #if (os(iOS) || os(watchOS) || os(tvOS)) && FOUNDATION_FRAMEWORK
        // Creating a file with a specific file protection class must have that class specified at open() time. Special-case NSFileProtectionKey here so that we can pass it as an NSDataWritingOption instead. 21998573.
        var opts = Data.WritingOptions.atomic
        var attr = attr
        if let protection = attr?[.protectionKey] as? String {
            let option: Data.WritingOptions? = switch FileProtectionType(rawValue: protection) {
            case .none: .noFileProtection
            case .complete: .completeFileProtection
            case .completeUnlessOpen: .completeFileProtectionUnlessOpen
            case .completeUntilFirstUserAuthentication: .completeFileProtectionUntilFirstUserAuthentication
            case .completeWhenUserInactive: .completeFileProtectionWhenUserInactive
            default: nil
            }
            if let option {
                opts.insert(option)
            }
            attr?[.protectionKey] = nil
        }
        #else
        let opts = Data.WritingOptions.atomic
        #endif
        
        do {
            try (data ?? .init()).write(to: URL(fileURLWithPath: path), options: opts)
        } catch {
            return false
        }
        if let attr {
            try? fileManager.setAttributes(attr, ofItemAtPath: path)
        }
        return true
    }
    
    func removeItem(at url: URL) throws {
        guard url.isFileURL else {
            throw CocoaError.errorWithFilePath(.fileReadUnsupportedScheme, url)
        }
        
        let path = url.path
        guard !path.isEmpty else {
            throw CocoaError.errorWithFilePath(.fileNoSuchFile, url)
        }
        
        try removeItem(atPath: path)
    }
    
    func removeItem(atPath path: String) throws {
        try _FileOperations.removeFile(path, with: fileManager)
    }
    
    func copyItem(
        at srcURL: URL,
        to dstURL: URL,
        options: NSFileManagerCopyOptions
    ) throws {
        guard srcURL.isFileURL else {
            throw CocoaError.errorWithFilePath(.fileReadUnsupportedScheme, srcURL)
        }
        guard dstURL.isFileURL else {
            throw CocoaError.errorWithFilePath(.fileReadUnsupportedScheme, dstURL)
        }
        
        let srcPath = srcURL.path
        guard !srcPath.isEmpty else {
            throw CocoaError.errorWithFilePath(.fileNoSuchFile, srcURL)
        }
        let dstPath = dstURL.path
        guard !dstPath.isEmpty else {
            throw CocoaError.errorWithFilePath(.fileNoSuchFile, dstURL)
        }
        
        try copyItem(atPath: srcPath, toPath: dstPath, options: options)
    }
    
    func copyItem(
        atPath srcPath: String,
        toPath dstPath: String,
        options: NSFileManagerCopyOptions
    ) throws {
        try _FileOperations.copyFile(srcPath, to: dstPath, with: fileManager, options: options)
    }
    
    func moveItem(
        at srcURL: URL,
        to dstURL: URL,
        options: NSFileManagerMoveOptions
    ) throws {
        guard srcURL.isFileURL else {
            throw CocoaError.errorWithFilePath(.fileReadUnsupportedScheme, srcURL)
        }
        guard dstURL.isFileURL else {
            throw CocoaError.errorWithFilePath(.fileReadUnsupportedScheme, dstURL)
        }
        
        let srcPath = srcURL.path
        guard !srcPath.isEmpty else {
            throw CocoaError.errorWithFilePath(.fileNoSuchFile, srcURL)
        }
        let dstPath = dstURL.path
        guard !dstPath.isEmpty else {
            throw CocoaError.errorWithFilePath(.fileNoSuchFile, dstURL)
        }
        
        try moveItem(atPath: srcPath, toPath: dstPath, options: options)
    }
    
    func moveItem(
        atPath srcPath: String,
        toPath dstPath: String,
        options: NSFileManagerMoveOptions
    ) throws {
        try _FileOperations.moveFile(
            URL(fileURLWithPath: srcPath),
            to: URL(fileURLWithPath: dstPath),
            with: fileManager,
            options: options
        )
    }
    
    private func _fileExists(_ path: String) -> (exists: Bool, isDirectory: Bool) {
#if os(Windows)
        guard !path.isEmpty else { return (false, false) }
        return (try? path.withNTPathRepresentation {
            var faAttributes: WIN32_FILE_ATTRIBUTE_DATA = .init()
            guard GetFileAttributesExW($0, GetFileExInfoStandard, &faAttributes) else {
                return (false, false)
            }
            return (true, faAttributes.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY == FILE_ATTRIBUTE_DIRECTORY)
        }) ?? (false, false)
#else
        path.withFileSystemRepresentation { rep -> (Bool, Bool) in
            guard let rep else {
                return (false, false)
            }

            var fileInfo = stat()
            guard stat(rep, &fileInfo) == 0 else {
                return (false, false)
            }
            let isDir = (fileInfo.st_mode & S_IFMT) == S_IFDIR
            return (true, isDir)
        }
#endif
    }
    
    func fileExists(atPath path: String) -> Bool {
        _fileExists(path).exists
    }
    
    func fileExists(
        atPath path: String,
        isDirectory: inout Bool
    ) -> Bool {
        let result = _fileExists(path)
        guard result.exists else { return false }
        isDirectory = result.isDirectory
        return true
    }

#if !os(Windows)
    private func _fileAccessibleForMode(_ path: String, _ mode: Int32) -> Bool {
        path.withFileSystemRepresentation { ptr in
            guard let ptr else { return false }
            return access(ptr, mode) == 0
        }
    }
#endif

    func isReadableFile(atPath path: String) -> Bool {
#if os(Windows)
        return (try? path.withNTPathRepresentation {
            var faAttributes: WIN32_FILE_ATTRIBUTE_DATA = .init()
            return GetFileAttributesExW($0, GetFileExInfoStandard, &faAttributes)
        }) ?? false
#else
        _fileAccessibleForMode(path, R_OK)
#endif
    }
    
    func isWritableFile(atPath path: String) -> Bool {
#if os(Windows)
        return (try? path.withNTPathRepresentation {
            var faAttributes: WIN32_FILE_ATTRIBUTE_DATA = .init()
            guard GetFileAttributesExW($0, GetFileExInfoStandard, &faAttributes) else {
                return false
            }
            return faAttributes.dwFileAttributes & FILE_ATTRIBUTE_READONLY != FILE_ATTRIBUTE_READONLY
        }) ?? false
#else
        _fileAccessibleForMode(path, W_OK)
#endif
    }
    
    func isExecutableFile(atPath path: String) -> Bool {
#if os(Windows)
        return (try? path.withNTPathRepresentation {
            var dwBinaryType: DWORD = 0
            return GetBinaryTypeW($0, &dwBinaryType)
        }) ?? false
#else
        _fileAccessibleForMode(path, X_OK)
#endif
    }
    
    func isDeletableFile(atPath path: String) -> Bool {
        var parent = path.deletingLastPathComponent()
        if parent.isEmpty {
            parent = fileManager.currentDirectoryPath
        }

#if os(Windows)
        return fileManager.isWritableFile(atPath: parent) && fileManager.isWritableFile(atPath: path)
#else
        guard fileManager.isWritableFile(atPath: parent),
              let dirInfo = fileManager._fileStat(parent) else {
            return false
        }
        
        if ((dirInfo.st_mode & S_ISVTX) != 0) && fileManager.fileExists(atPath: path) {
            // its sticky so verify that we own the file
            // otherwise we answer YES on the principle that if
            // we create files we can delete them
            
            guard let fileInfo = fileManager._fileStat(path) else {
                return false
            }
            return fileInfo.st_uid == getuid();
        } else {
            return true
        }
#endif
    }

#if !os(Windows) && !os(WASI)
    private func _extendedAttribute(_ key: UnsafePointer<CChar>, at path: UnsafePointer<CChar>, followSymlinks: Bool) throws -> Data? {
        #if canImport(Darwin)
        var size = getxattr(path, key, nil, 0, 0, followSymlinks ? 0 : XATTR_NOFOLLOW)
        #else
        var size = followSymlinks ? getxattr(path, key, nil, 0) : lgetxattr(path, key, nil, 0)
        #endif
        guard size != -1 else {
            throw CocoaError.errorWithFilePath(String(cString: path), errno: errno, reading: true)
        }
        // Historically we've omitted extended attribute keys with no associated data value
        guard size > 0 else { return nil }
        // Deallocated below in the Data deallocator
        let buffer = malloc(size)!
        #if canImport(Darwin)
        size = getxattr(path, key, buffer, size, 0, followSymlinks ? 0 : XATTR_NOFOLLOW)
        #else
        size = followSymlinks ? getxattr(path, key, buffer, size) : lgetxattr(path, key, buffer, size)
        #endif
        guard size != -1 else {
            free(buffer)
            throw CocoaError.errorWithFilePath(String(cString: path), errno: errno, reading: true)
        }
        // Check size again in case something has changed between the two getxattr calls
        guard size > 0 else {
            free(buffer)
            return nil
        }
        return Data(bytesNoCopy: buffer, count: size, deallocator: .free)
    }
    
    private func _extendedAttributes(at path: UnsafePointer<CChar>, followSymlinks: Bool) throws -> [String : Data]? {
        #if canImport(Darwin)
        var size = listxattr(path, nil, 0, 0)
        #else
        var size = listxattr(path, nil, 0)
        #endif
        guard size > 0 else { return nil }
        let keyList = UnsafeMutableBufferPointer<CChar>.allocate(capacity: size)
        defer { keyList.deallocate() }
        #if canImport(Darwin)
        size = listxattr(path, keyList.baseAddress!, size, 0)
        #else
        size = listxattr(path, keyList.baseAddress!, size)
        #endif
        guard size > 0 else { return nil }
        
        var extendedAttrs: [String : Data] = [:]
        var current = keyList.baseAddress!
        let end = keyList.baseAddress!.advanced(by: keyList.count)
        while current < end {
            let currentKey = String(cString: current)
            defer { current = current.advanced(by: currentKey.utf8.count) + 1 /* pass null byte */ }
            
            #if canImport(Darwin)
            if currentKey == XATTR_RESOURCEFORK_NAME || currentKey == XATTR_FINDERINFO_NAME || currentKey == "system.Security" {
                continue
            }
            #endif
            
            if let value = try _extendedAttribute(current, at: path, followSymlinks: false) {
                extendedAttrs[currentKey] = value
            }
        }
        return extendedAttrs
    }
#endif

    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey : Any] {
#if os(Windows)
        return try path.withNTPathRepresentation { pwszPath in
            let hFile = CreateFileW(pwszPath, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nil, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT, nil)
            if hFile == INVALID_HANDLE_VALUE {
                throw CocoaError.errorWithFilePath(path, win32: GetLastError(), reading: true)
            }
            defer { CloseHandle(hFile) }

            var info: BY_HANDLE_FILE_INFORMATION = BY_HANDLE_FILE_INFORMATION()
            guard GetFileInformationByHandle(hFile, &info) else {
              throw CocoaError.errorWithFilePath(path, win32: GetLastError(), reading: true)
            }

            let dwFileType = GetFileType(hFile)
            var fatType: FileAttributeType = switch (dwFileType) {
                case FILE_TYPE_CHAR: FileAttributeType.typeCharacterSpecial
                case FILE_TYPE_DISK:
                    info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY == FILE_ATTRIBUTE_DIRECTORY
                            ? FileAttributeType.typeDirectory
                            : FileAttributeType.typeRegular
                case FILE_TYPE_PIPE: FileAttributeType.typeSocket
                case FILE_TYPE_UNKNOWN: FileAttributeType.typeUnknown
                default: FileAttributeType.typeUnknown
            }

            if info.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT == FILE_ATTRIBUTE_REPARSE_POINT {
                // This could by a symlink, check if that's the case and update fatType if necessary
                var tagInfo = FILE_ATTRIBUTE_TAG_INFO()
                if GetFileInformationByHandleEx(hFile, FileAttributeTagInfo, &tagInfo, DWORD(MemoryLayout<FILE_ATTRIBUTE_TAG_INFO>.size)) {
                    if tagInfo.ReparseTag == IO_REPARSE_TAG_SYMLINK {
                        fatType = .typeSymbolicLink
                    }
                }
            }

            let systemNumber = UInt64(info.dwVolumeSerialNumber)
            let systemFileNumber = UInt64(info.nFileIndexHigh << 32) | UInt64(info.nFileIndexLow)
            let referenceCount = UInt64(info.nNumberOfLinks)

            let isReadOnly = info.dwFileAttributes & FILE_ATTRIBUTE_READONLY != 0
            // Directories are always considered executable, but we check for other types
            let isExecutable = fatType == .typeDirectory || SaferiIsExecutableFileType(pwszPath, 0)
            var posixPermissions = UInt16(_S_IREAD)
            if !isReadOnly {
                posixPermissions |= UInt16(_S_IWRITE)
            }
            if isExecutable {
                posixPermissions |= UInt16(_S_IEXEC)
            }

            let size: UInt64 = (UInt64(info.nFileSizeHigh) << 32) | UInt64(info.nFileSizeLow)
            let creation: Date = Date(timeIntervalSince1970: info.ftCreationTime.timeIntervalSince1970)
            let modification: Date = Date(timeIntervalSince1970: info.ftLastWriteTime.timeIntervalSince1970)
            return [
                .size: _writeFileAttributePrimitive(size, as: UInt.self),
                .modificationDate: modification,
                .creationDate: creation,
                .type: fatType,
                .systemNumber: _writeFileAttributePrimitive(systemNumber, as: UInt.self),
                .systemFileNumber: _writeFileAttributePrimitive(systemFileNumber, as: UInt.self),
                .posixPermissions: _writeFileAttributePrimitive(posixPermissions, as: UInt.self),
                .referenceCount: _writeFileAttributePrimitive(referenceCount, as: UInt.self),

                // Uid is always 0 on Windows systems
                .ownerAccountID: _writeFileAttributePrimitive(0, as: UInt.self),

                // Group id is always 0 on Windows
                .groupOwnerAccountID: _writeFileAttributePrimitive(0, as: UInt.self)

                // TODO: Support .deviceIdentifier
            ]
        }
#else
        try fileManager.withFileSystemRepresentation(for: path) { fsRep in
            guard let fsRep else {
                throw CocoaError.errorWithFilePath(.fileReadUnknown, path)
            }
            
            var statAtPath = stat()
            guard lstat(fsRep, &statAtPath) == 0 else {
                throw CocoaError.errorWithFilePath(path, errno: errno, reading: true)
            }
            
            var attributes = statAtPath.fileAttributes
            try? Self._catInfo(for: URL(filePath: path, directoryHint: .isDirectory), statInfo: statAtPath, into: &attributes)
            #if !os(WASI) // WASI does not support extended attributes
            if let extendedAttrs = try? _extendedAttributes(at: fsRep, followSymlinks: false) {
                attributes[._extendedAttributes] = extendedAttrs
            }
            #endif
            
            #if !targetEnvironment(simulator) && FOUNDATION_FRAMEWORK
            if statAtPath.isRegular || statAtPath.isDirectory {
                if let protectionClass = Self._fileProtectionValueForPath(fsRep), let pType = FileProtectionType(intValue: protectionClass) {
                    // Cast to NSString here so that clients can cast this value to both String and FileProtectionType
                    attributes[.protectionKey] = pType as NSString
                } else {
                    attributes[.protectionKey] = nil
                }
            }
            #endif
            return attributes
        }
#endif
    }
    
    func attributesOfFileSystem(forPath path: String) throws -> [FileAttributeKey : Any] {
#if os(Windows)
        return try path.withNTPathRepresentation { pwszPath in
            var faAttributes: WIN32_FILE_ATTRIBUTE_DATA = .init()
            guard GetFileAttributesExW(pwszPath, GetFileExInfoStandard, &faAttributes) else {
                throw CocoaError.errorWithFilePath(path, win32: GetLastError(), reading: true)
            }

            let dwLength: DWORD = GetFullPathNameW(pwszPath, 0, nil, nil)
            guard dwLength > 0 else {
                throw CocoaError.errorWithFilePath(path, win32: GetLastError(), reading: true)
            }

            return try withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: Int(dwLength)) { szVolumeName in
                guard GetVolumePathNameW(pwszPath, szVolumeName.baseAddress, dwLength) else {
                    throw CocoaError.errorWithFilePath(path, win32: GetLastError(), reading: true)
                }

                var liTotal: ULARGE_INTEGER = .init()
                var liFree: ULARGE_INTEGER = .init()
                guard GetDiskFreeSpaceExW(szVolumeName.baseAddress, nil, &liTotal, &liFree) else {
                    throw CocoaError.errorWithFilePath(path, win32: GetLastError(), reading: true)
                }

                let hr: HRESULT = PathCchStripToRoot(szVolumeName.baseAddress, szVolumeName.count)
                guard hr == S_OK || hr == S_FALSE else {
                    throw CocoaError.errorWithFilePath(path, win32: DWORD(hr & 0xffff), reading: true)
                }

                var dwVolumeSerialNumber: DWORD = 0
                guard GetVolumeInformationW(szVolumeName.baseAddress, nil, 0, &dwVolumeSerialNumber, nil, nil, nil, 0) else {
                    throw CocoaError.errorWithFilePath(path, win32: GetLastError(), reading: true)
                }

                return [
                    .systemSize: _writeFileAttributePrimitive(liTotal.QuadPart, as: UInt64.self),
                    .systemFreeSize: _writeFileAttributePrimitive(liFree.QuadPart, as: UInt64.self),
                    .systemNumber: _writeFileAttributePrimitive(dwVolumeSerialNumber, as: UInt.self),

                    // TODO(compnerd) support these attributes, remapping the Windows semantics...
                    // .systemNodes: ...,
                    // .systemFreeNodes: ...,
                ]
            }
        }
#elseif os(WASI)
        // WASI does not support file system attributes
        return [:]
#else
        try fileManager.withFileSystemRepresentation(for: path) { rep in
            guard let rep else {
                throw CocoaError.errorWithFilePath(.fileReadUnknown, path)
            }
            
            #if canImport(Darwin)
            var result = statfs()
            let statfsReturnValue = statfs(rep, &result)
            #else
            var result = statvfs()
            let statfsReturnValue = statvfs(rep, &result)
            #endif
            guard statfsReturnValue == 0 else {
                throw CocoaError.errorWithFilePath(path, errno: errno, reading: true)
            }
            
            #if canImport(Darwin)
            let fsNumber = result.f_fsid.val.0
            let blockSize = UInt64(result.f_bsize)
            #else
            let fsNumber = result.f_fsid
            let blockSize = UInt(result.f_frsize)
            #endif
            var totalSizeBytes = result.f_blocks * blockSize
            var availSizeBytes = result.f_bavail * blockSize
            var totalFiles = result.f_files
            var availFiles = result.f_ffree
            
            
            #if canImport(Darwin)
            func QCMD(_ cmd: Int32, _ type: Int32) -> Int32 {
                (cmd << SUBCMDSHIFT) | (type & SUBCMDMASK)
            }
            
            func _quotactl<T>(_ path: UnsafePointer<CChar>, _ cmd: Int32, _ type: Int32, _ uid: uid_t, init: T) -> T? {
                var res = `init`
                let success = withUnsafeMutableBytes(of: &res) { buffer in
                    quotactl(path, QCMD(cmd, type), Int32(uid), buffer.baseAddress!) == 0
                }
                return success ? res : nil
            }
            
            withUnsafeBytes(of: &result.f_mntonname) { mntonnameBuffer in
                let mntonname = mntonnameBuffer.baseAddress!.assumingMemoryBound(to: CChar.self)
                // If a quota is enabled, get quota info
                let userID = geteuid()
                if let isQuotaOn = _quotactl(mntonname, Q_QUOTASTAT, USRQUOTA, userID, init: 0),
                   isQuotaOn != 0,
                   let quotaInfo = _quotactl(mntonname, Q_GETQUOTA, USRQUOTA, userID, init: dqblk()) {
                    // For each value (total/available bytes, total/available files) report the smaller of the quota hard limit and the statfs value.
                    if quotaInfo.dqb_bhardlimit > 0 {
                        totalSizeBytes = min(quotaInfo.dqb_bhardlimit, totalSizeBytes)
                        availSizeBytes = min(quotaInfo.dqb_bhardlimit - quotaInfo.dqb_curbytes, availSizeBytes)
                    }
                    if (quotaInfo.dqb_ihardlimit > 0) {
                        totalFiles = min(UInt64(quotaInfo.dqb_ihardlimit), totalFiles)
                        availFiles = min(UInt64(quotaInfo.dqb_ihardlimit - quotaInfo.dqb_curinodes), availFiles)
                    }
                }
            }
            #endif
            
            return [
                .systemSize : _writeFileAttributePrimitive(totalSizeBytes, as: UInt64.self),
                .systemFreeSize : _writeFileAttributePrimitive(availSizeBytes, as: UInt64.self),
                .systemNodes : _writeFileAttributePrimitive(totalFiles, as: UInt64.self),
                .systemFreeNodes : _writeFileAttributePrimitive(availFiles, as: UInt64.self),
                .systemNumber : _writeFileAttributePrimitive(fsNumber, as: UInt.self)
            ]
        }
#endif
    }
    
    func setAttributes(
        _ attributes: [FileAttributeKey : Any],
        ofItemAtPath path: String
    ) throws {
        let mode = _readFileAttributePrimitive(attributes[.posixPermissions], as: UInt.self)
        let immutable = _readFileAttributePrimitive(attributes[.immutable], as: Bool.self)
        let appendOnly = _readFileAttributePrimitive(attributes[.appendOnly], as: Bool.self)

#if os(Windows)
        try path.withNTPathRepresentation {
            if immutable != nil || appendOnly != nil {
                // Setting these flags is not supported on this platform
                throw CocoaError.errorWithFilePath(.featureUnsupported, path)
            }

            var attributesToSet: DWORD?
            if let mode {
                let existingAttributes = GetFileAttributesW($0)
                guard existingAttributes != INVALID_FILE_ATTRIBUTES else {
                    throw CocoaError.errorWithFilePath(path, win32: GetLastError(), reading: true)
                }
                let isReadOnly = (existingAttributes & FILE_ATTRIBUTE_READONLY) != 0
                let requestedReadOnly = (mode & UInt(_S_IWRITE)) == 0
                if isReadOnly && !requestedReadOnly {
                    guard SetFileAttributesW($0, existingAttributes & ~FILE_ATTRIBUTE_READONLY) else {
                        throw CocoaError.errorWithFilePath(path, win32: GetLastError(), reading: false)
                    }
                } else if !isReadOnly && requestedReadOnly {
                    // Make the file read-only later after setting other attributes
                    attributesToSet = existingAttributes | FILE_ATTRIBUTE_READONLY
                }
            }

            if let modification = attributes[.modificationDate] as? Date {
                let seconds = modification.timeIntervalSince1601

                var uiTime: ULARGE_INTEGER = .init()
                guard let converted = UInt64(exactly: seconds * 10000000.0) else {
                    return
                }
                uiTime.QuadPart = converted

                var ftTime: FILETIME = .init()
                ftTime.dwLowDateTime = uiTime.LowPart
                ftTime.dwHighDateTime = uiTime.HighPart

                let hFile: HANDLE = CreateFileW($0, GENERIC_WRITE, FILE_SHARE_WRITE, nil, OPEN_EXISTING, 0, nil)
                if hFile == INVALID_HANDLE_VALUE {
                    throw CocoaError.errorWithFilePath(path, win32: GetLastError(), reading: true)
                }
                defer { CloseHandle(hFile) }

                guard SetFileTime(hFile, nil, nil, &ftTime) else {
                    throw CocoaError.errorWithFilePath(path, win32: GetLastError(), reading: false)
                }
            }

            // Finally, make the file read-only if requested
            if let attributesToSet {
                guard SetFileAttributesW($0, attributesToSet) else {
                    throw CocoaError.errorWithFilePath(path, win32: GetLastError(), reading: false)
                }
            }
        }
#else
        try fileManager.withFileSystemRepresentation(for: path) { fileSystemRepresentation in
            guard let fileSystemRepresentation else {
                throw CocoaError.errorWithFilePath(.fileWriteUnknown, path)
            }
            
            // Use Result instead of throwing var to avoid compiler hang (rdar://119035093)
            lazy var statAtPath: Result<stat, CocoaError> = {
                var result = stat()
                if lstat(fileSystemRepresentation, &result) != 0 {
                    return .failure(CocoaError.errorWithFilePath(path, errno: errno, reading: false))
                }
                return .success(result)
            }()
            
            // Set the flags first if we could be clearing the immutable bit. Set them last if we could be setting the immutable bit.
            var setFlags: (() throws -> Void)?
            if (immutable != nil || appendOnly != nil) {
                #if canImport(Darwin)
                setFlags = {
                    var flags = try statAtPath.get().st_flags
                    if let appendOnly {
                        if appendOnly {
                            flags |= UInt32(UF_APPEND)
                        } else {
                            flags &= ~UInt32(UF_APPEND)
                        }
                    }
                    if let immutable {
                        if immutable {
                            flags |= UInt32(UF_IMMUTABLE)
                        } else {
                            flags &= ~UInt32(UF_IMMUTABLE)
                        }
                    }
                    
                    if chflags(fileSystemRepresentation, flags) != 0 {
                        throw CocoaError.errorWithFilePath(path, errno: errno, reading: false)
                    }
                }
                
                if !(immutable ?? false) {
                    try setFlags?()
                    setFlags = nil
                }
                #else
                // Setting these flags is not supported on this platform
                throw CocoaError.errorWithFilePath(.featureUnsupported, path)
                #endif
            }
            
            // Like the immutable flag, if write permissions are being set, do it first. If they are being unset, do it last.
            var setMode: (() throws -> Void)?
            if let mode {
                #if os(WASI)
                // WASI does not have the concept of permissions
                throw CocoaError.errorWithFilePath(.featureUnsupported, path)
                #else
                setMode = {
                    if chmod(fileSystemRepresentation, mode_t(mode)) != 0 {
                        throw CocoaError.errorWithFilePath(path, errno: errno, reading: false)
                    }
                }
                
                if mode_t(mode) & S_IWUSR != 0 {
                    try setMode?()
                    setMode = nil
                }
                #endif
            }
            
            let user = attributes[.ownerAccountName] as? String
            let userID = _readFileAttributePrimitive(attributes[.ownerAccountID], as: UInt.self)
            let group = attributes[.groupOwnerAccountName] as? String
            let groupID = _readFileAttributePrimitive(attributes[.groupOwnerAccountID], as: UInt.self)
            
            if user != nil || userID != nil || group != nil || groupID != nil {
                #if os(WASI)
                // WASI does not have the concept of users or groups
                throw CocoaError.errorWithFilePath(.featureUnsupported, path)
                #else
                // Bias toward userID & groupID - try to prevent round trips to getpwnam if possible.
                var leaveUnchanged: UInt32 { UInt32(bitPattern: -1) }
                let rawUserID = userID.flatMap(uid_t.init) ?? user.flatMap(Self._userAccountNameToNumber) ?? leaveUnchanged
                let rawGroupID = groupID.flatMap(gid_t.init) ?? group.flatMap(Self._groupAccountNameToNumber) ?? leaveUnchanged
                if chown(fileSystemRepresentation, rawUserID, rawGroupID) != 0 {
                    throw CocoaError.errorWithFilePath(path, errno: errno, reading: false)
                }
                #endif
            }
            
            try Self._setCatInfoAttributes(attributes, path: path)
            
            if let extendedAttrs = attributes[.init("NSFileExtendedAttributes")] as? [String : Data] {
                #if os(WASI)
                // WASI does not support extended attributes
                throw CocoaError.errorWithFilePath(.featureUnsupported, path)
                #else
                try Self._setAttributes(extendedAttrs, at: fileSystemRepresentation, followSymLinks: false)
                #endif
            }
            
            if let date = attributes[.modificationDate] as? Date {
                let (isecs, fsecs) = modf(date.timeIntervalSince1970)
                if let tv_sec = time_t(exactly: isecs),
                   let tv_usec = suseconds_t(exactly: round(fsecs * 1000000.0)) {
                    var timevals = (timeval(), timeval())
                    timevals.0.tv_sec = tv_sec
                    timevals.0.tv_usec = tv_usec
                    timevals.1 = timevals.0
                    try withUnsafePointer(to: timevals) {
                        try $0.withMemoryRebound(to: timeval.self, capacity: 2) {
                            if utimes(fileSystemRepresentation, $0) != 0 {
                                throw CocoaError.errorWithFilePath(path, errno: errno, reading: false)
                            }
                        }
                    }
                }
            }
            
            // Remove write permissions if it has been requested. This must be done before setting the immutable bit.
            try setMode?()
            
            // Set flags now, if we postponed it until now.
            try setFlags?()
            
            #if !targetEnvironment(simulator) && FOUNDATION_FRAMEWORK
            // Set per-file protection class on embedded.
            let fileProtection = attributes[.protectionKey] as? FileProtectionType
            if let fileProtection, let fileProtectionClass = fileProtection.intValue {
                // Only set protection class on regular files and directories.
                if try statAtPath.get().isRegular || statAtPath.get().isDirectory {
                    // Finally, set the class.
                    try Self._setFileProtectionValueForPath(path, fileSystemRepresentation, newValue: fileProtectionClass)
                }
            }
            #endif
        }
#endif
    }
}
