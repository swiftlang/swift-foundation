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
#elseif canImport(Glibc)
import Glibc
internal import _CShims
#endif

extension Date {
    fileprivate init(seconds: TimeInterval, nanoSeconds: TimeInterval) {
        self.init(timeIntervalSinceReferenceDate: seconds - Self.timeIntervalBetween1970AndReferenceDate + nanoSeconds / 1_000_000_000.0 )
    }
}

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

extension mode_t {
    fileprivate var fileType: FileAttributeType {
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
}

func _readFileAttributePrimitive<T: BinaryInteger>(_ value: Any?, as type: T.Type) -> T? {
    guard let value else { return nil }
    #if FOUNDATION_FRAMEWORK
    if let nsNumber = value as? NSNumber, let result = nsNumber as? T {
        return result
    }
    #endif
    
    if let binInt = value as? (any BinaryInteger), let result = T(exactly: binInt) {
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

func _writeFileAttributePrimitive<T: BinaryInteger, U: BinaryInteger>(_ value: T, as type: U.Type) -> Any {
    #if FOUNDATION_FRAMEWORK
    if let int = Int64(exactly: value) {
        NSNumber(value: int)
    } else {
        NSNumber(value: UInt64(value))
    }
    #else
    U(value)
    #endif
}

func _writeFileAttributePrimitive(_ value: Bool) -> Any {
    #if FOUNDATION_FRAMEWORK
    NSNumber(value: value)
    #else
    value
    #endif
}

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
        if let userName = _nameFor(uid: st_uid) {
            result[.ownerAccountName] = userName
        }
        if let groupName = _nameFor(gid: st_gid) {
            result[.groupOwnerAccountName] = groupName
        }
        if fileType == .typeBlockSpecial || fileType == .typeCharacterSpecial {
            result[.deviceIdentifier] = _writeFileAttributePrimitive(st_rdev, as: UInt.self)
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
    
    private func _fileAccessibleForMode(_ path: String, _ mode: Int32) -> Bool {
        path.withFileSystemRepresentation { ptr in
            guard let ptr else { return false }
            return access(ptr, mode) == 0
        }
    }
    
    func isReadableFile(atPath path: String) -> Bool {
        _fileAccessibleForMode(path, R_OK)
    }
    
    func isWritableFile(atPath path: String) -> Bool {
        _fileAccessibleForMode(path, W_OK)
    }
    
    func isExecutableFile(atPath path: String) -> Bool {
        _fileAccessibleForMode(path, X_OK)
    }
    
    func isDeletableFile(atPath path: String) -> Bool {
        var parent = path.deletingLastPathComponent()
        if parent.isEmpty {
            parent = fileManager.currentDirectoryPath
        }
        
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
    }
    
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
    
    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey : Any] {
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
            
            if let extendedAttrs = try? _extendedAttributes(at: fsRep, followSymlinks: false) {
                attributes[._extendedAttributes] = extendedAttrs
            }
            
            #if !targetEnvironment(simulator) && FOUNDATION_FRAMEWORK
            if statAtPath.isRegular || statAtPath.isDirectory {
                if let protectionClass = Self._fileProtectionValueForPath(fsRep), let pType = FileProtectionType(intValue: protectionClass) {
                    attributes[.protectionKey] = pType
                } else {
                    attributes[.protectionKey] = nil
                }
            }
            #endif
            return attributes
        }
    }
    
    func attributesOfFileSystem(forPath path: String) throws -> [FileAttributeKey : Any] {
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
    }
    
    func setAttributes(
        _ attributes: [FileAttributeKey : Any],
        ofItemAtPath path: String
    ) throws {
        try fileManager.withFileSystemRepresentation(for: path) { fileSystemRepresentation in
            guard let fileSystemRepresentation else {
                throw CocoaError.errorWithFilePath(.fileWriteUnknown, path)
            }
            
            let mode = _readFileAttributePrimitive(attributes[.posixPermissions], as: UInt.self)
            let immutable = _readFileAttributePrimitive(attributes[.immutable], as: Bool.self)
            let appendOnly = _readFileAttributePrimitive(attributes[.appendOnly], as: Bool.self)
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
                setMode = {
                    if chmod(fileSystemRepresentation, mode_t(mode)) != 0 {
                        throw CocoaError.errorWithFilePath(path, errno: errno, reading: false)
                    }
                }
                
                if mode_t(mode) & S_IWUSR != 0 {
                    try setMode?()
                    setMode = nil
                }
            }
            
            let user = attributes[.ownerAccountName] as? String
            let userID = _readFileAttributePrimitive(attributes[.ownerAccountID], as: UInt.self)
            let group = attributes[.groupOwnerAccountName] as? String
            let groupID = _readFileAttributePrimitive(attributes[.groupOwnerAccountID], as: UInt.self)
            
            if user != nil || userID != nil || group != nil || groupID != nil {
                // Bias toward userID & groupID - try to prevent round trips to getpwnam if possible.
                var leaveUnchanged: UInt32 { UInt32(bitPattern: -1) }
                let rawUserID = userID.flatMap(uid_t.init) ?? user.flatMap(Self._userAccountNameToNumber) ?? leaveUnchanged
                let rawGroupID = groupID.flatMap(gid_t.init) ?? group.flatMap(Self._groupAccountNameToNumber) ?? leaveUnchanged
                if chown(fileSystemRepresentation, rawUserID, rawGroupID) != 0 {
                    throw CocoaError.errorWithFilePath(path, errno: errno, reading: false)
                }
            }
            
            try Self._setCatInfoAttributes(attributes, path: path)
            
            if let extendedAttrs = attributes[.init("NSFileExtendedAttributes")] as? [String : Data] {
                try Self._setAttributes(extendedAttrs, at: fileSystemRepresentation, followSymLinks: false)
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
    }
}
