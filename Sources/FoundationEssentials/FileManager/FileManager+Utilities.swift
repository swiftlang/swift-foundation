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
@_implementationOnly import XPCPrivate
@_implementationOnly import _ForSwiftFoundation
@_implementationOnly import Foundation_Private.NSFileManager
@_implementationOnly import DarwinPrivate

#if os(macOS)
@_implementationOnly import QuarantinePrivate
#endif
#endif

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
package import _CShims
#endif

extension CocoaError {
#if !FOUNDATION_FRAMEWORK
    static var NSURLErrorKey: String { "NSURL" }
    static var NSFilePathErrorKey: String { "NSFilePath"}
#endif
    
    static func errorWithFilePath(_ code: CocoaError.Code, _ path: String) -> CocoaError {
        CocoaError(code, userInfo: [NSFilePathErrorKey : path])
    }
    
    private static func filePathCocoaCode(from errno: Int32, reading: Bool) -> CocoaError.Code {
        if reading {
            switch errno {
            case EFBIG: .fileReadTooLarge
            case ENOENT: .fileReadNoSuchFile
            case EPERM, EACCES: .fileReadNoPermission
            case ENAMETOOLONG: .fileReadInvalidFileName
            default: .fileReadUnknown
            }
        } else {
            switch errno {
            case ENOENT: .fileNoSuchFile
            case EPERM, EACCES: .fileWriteNoPermission
            case ENAMETOOLONG: .fileWriteInvalidFileName
            case EDQUOT, ENOSPC: .fileWriteOutOfSpace
            case EROFS: .fileWriteVolumeReadOnly
            case EEXIST: .fileWriteFileExists
            default: .fileWriteUnknown
            }
        }
    }
    
    static func errorWithFilePath(_ path: String, errno: Int32, reading: Bool, variant: String? = nil, extra: [String : AnyHashable] = [:]) -> CocoaError {
        guard let code = POSIXError.Code(rawValue: errno) else {
            fatalError("Invalid posix errno \(errno)")
        }
        var userInfo: [String : AnyHashable] = [
            NSUnderlyingErrorKey : POSIXError(code),
            NSFilePathErrorKey : path
        ].merging(extra) { _, new in
            new
        }
        if let variant {
            userInfo["NSUserStringVariant"] = [variant]
        }
        return CocoaError(Self.filePathCocoaCode(from: errno, reading: reading), userInfo: userInfo)
    }
    
    static func errorWithFilePath(_ code: CocoaError.Code, _ url: URL) -> CocoaError {
        CocoaError(code, userInfo: [NSURLErrorKey : url])
    }
    
    static func errorWithFilePath(_ url: URL, errno: Int32, reading: Bool, variant: String? = nil, extra: [String : AnyHashable] = [:]) -> CocoaError {
        var userInfo: [String : AnyHashable] = [
            NSUnderlyingErrorKey : POSIXError(.init(rawValue: errno)!),
            NSURLErrorKey : url
        ].merging(extra) { _, new in
            new
        }
        if let variant {
            userInfo["NSUserStringVariant"] = [variant]
        }
        return CocoaError(Self.filePathCocoaCode(from: errno, reading: reading), userInfo: userInfo)
    }
    
    static func errorWithFilePath(_ path: String? = nil, osStatus: Int, reading: Bool, variant: String? = nil) -> CocoaError {
        // Do more or less what _NSErrorWithFilePathAndErrno() does, except for OSStatus values
        let errorCode: CocoaError.Code = switch (reading, osStatus) {
        case (true, -43 /*fnfErr*/), (true, -120 /*dirNFErr*/): .fileReadNoSuchFile
        case (true, -5000 /*afpAccessDenied*/): .fileReadNoPermission
        case (true, _): .fileReadUnknown
        case (false, -34 /*dskFulErr*/), (false, -1425 /*errFSQuotaExceeded*/): .fileWriteOutOfSpace
        case (false, -45 /*fLckdErr*/), (false, -5000 /*afpAccessDenied*/): .fileWriteNoPermission
        case (false, _): .fileWriteUnknown
        }
        #if FOUNDATION_FRAMEWORK
        var userInfo: [String : AnyHashable] = [
            NSUnderlyingErrorKey : NSError(domain: NSOSStatusErrorDomain, code: osStatus)
        ]
        #else
        var userInfo: [String : AnyHashable] = [:]
        #endif
        if let path {
            userInfo[NSFilePathErrorKey] = path
        }
        if let variant {
            userInfo[NSUserStringVariantErrorKey] = [variant]
        }
        return CocoaError(errorCode, userInfo: userInfo)
    }
}

extension stat {
    var isDirectory: Bool {
        (self.st_mode & S_IFMT) == S_IFDIR
    }
    
    var isRegular: Bool {
        (self.st_mode & S_IFMT) == S_IFREG
    }
    
    var isSymbolicLink: Bool {
        (self.st_mode & S_IFMT) == S_IFLNK
    }
    
    var isSpecial: Bool {
        let type = self.st_mode & S_IFMT
        return type == S_IFBLK || type == S_IFCHR
    }
}

#if FOUNDATION_FRAMEWORK && os(macOS)
extension URLResourceKey {
    static var _finderInfoKey: Self { URLResourceKey("_NSURLFinderInfoKey") }
}
#endif

extension _FileManagerImpl {
    #if os(macOS) && FOUNDATION_FRAMEWORK
    private struct _HFSFinderInfo {
        var fileInfo: FndrFileInfo
        var extendedFileInfo: FndrExtendedFileInfo
    }
    #endif
    
    static func _catInfo(for url: URL, statInfo: stat, into attributes: inout [FileAttributeKey : Any]) throws {
        #if FOUNDATION_FRAMEWORK
        // Get the info we care about for the file (creatorCode, fileTypeCode, extensionHidden, creationDate, fileBusy) and set validFields for each of them.
        #if os(macOS)
        let keys: Set<URLResourceKey> = [.hasHiddenExtensionKey, .creationDateKey, ._finderInfoKey]
        #else
        let keys: Set<URLResourceKey> = [.hasHiddenExtensionKey, .creationDateKey]
        #endif
        let values = try url.resourceValues(forKeys: keys)
        #if os(macOS)
        if let finderInfoData = values.allValues[._finderInfoKey] as? Data {
            let finderInfo = finderInfoData.withUnsafeBytes({ $0.load(as: _HFSFinderInfo.self) })
            // Record the creator and file type of a file.
            if statInfo.isRegular {
                attributes[.hfsCreatorCode] = _writeFileAttributePrimitive(finderInfo.fileInfo.fdCreator, as: UInt.self)
                attributes[.hfsTypeCode] = _writeFileAttributePrimitive(finderInfo.fileInfo.fdType, as: UInt.self)
            } else if statInfo.isSymbolicLink {
                attributes[.hfsCreatorCode] = _writeFileAttributePrimitive(kSymLinkCreator, as: UInt.self)
                attributes[.hfsTypeCode] = _writeFileAttributePrimitive(kSymLinkFileType, as: UInt.self)
            }
            attributes[.busy] = _writeFileAttributePrimitive((finderInfo.extendedFileInfo.extended_flags & 0x80 /*kExtendedFlagObjectIsBusy*/) != 0)
        }
        #endif
        
        // Record whether or not the file or directory's name extension is hidden.
        if let value = values.hasHiddenExtension {
            attributes[.extensionHidden] = _writeFileAttributePrimitive(value)
        }

        // Record the creation date of the object.
        attributes[.creationDate] = values.creationDate
        #else
        return // TODO: implement fetching cat info attributes in swift-foundation
        #endif
    }
    
    static func _setCatInfoAttributes(_ attributes: [FileAttributeKey : Any], path: String) throws {
        #if !FOUNDATION_FRAMEWORK
        let usedKeys: [FileAttributeKey] = [.hfsCreatorCode, .hfsTypeCode, .busy, .extensionHidden, .creationDate]
        guard !attributes.keys.contains(where: { usedKeys.contains($0) }) else {
            // TODO: Implement CAT info attributes for swift-foundation
            throw CocoaError.errorWithFilePath(.featureUnsupported, path)
        }
        #else
        // -setAttributes:ofItemAtPath:error: follows symlinks (<rdar://5815920>), but the NSURL resource value API doesn't, so we have to manually resolve the symlink.
        // We lie to fileURLWithPath:isDirectory: to avoid the extra stat. Since this URL isn't used as a base URL for another URL, it shouldn't make any difference.
        var url = URL(fileURLWithPath: path.resolvingSymlinksInPath, isDirectory: false)
        var urlAttributes: [URLResourceKey : Any] = [:]
        #if os(macOS)
        let creatorCode = _readFileAttributePrimitive(attributes[.hfsCreatorCode], as: UInt32.self)
        let fileTypeCode = _readFileAttributePrimitive(attributes[.hfsTypeCode], as: UInt32.self)
        let fileBusy = _readFileAttributePrimitive(attributes[.busy], as: Bool.self)
        if creatorCode != nil || fileTypeCode != nil || fileBusy != nil {
            let finderInfoData = try url.resourceValues(forKeys: [._finderInfoKey]).allValues[._finderInfoKey] as? Data
            if var finderInfo = finderInfoData?.withUnsafeBytes({ $0.load(as: _HFSFinderInfo.self) }) {
                if let creatorCode {
                    finderInfo.fileInfo.fdCreator = creatorCode
                }
                if let fileTypeCode {
                    finderInfo.fileInfo.fdType = fileTypeCode
                }
                if let fileBusy {
                    if fileBusy {
                        finderInfo.extendedFileInfo.extended_flags |= 0x0080 // kExtendedFlagObjectIsBusy
                    } else {
                        finderInfo.extendedFileInfo.extended_flags &= ~0x0080 // kExtendedFlagObjectIsBusy
                    }
                }
                withUnsafeBytes(of: &finderInfo) { buffer in
                    urlAttributes[._finderInfoKey] = Data(buffer)
                }
            }
        }
        #endif
        
        if let extensionHidden = attributes[.extensionHidden] {
            urlAttributes[.hasHiddenExtensionKey] = extensionHidden
        }
        if let creationDate = attributes[.creationDate] {
            urlAttributes[.creationDateKey] = creationDate
        }
        try url.setResourceValues(URLResourceValues(values: urlAttributes))
        #endif
    }
    
    static func _setAttribute(_ key: UnsafePointer<CChar>, value: Data, at path: UnsafePointer<CChar>, followSymLinks: Bool) throws {
        try value.withUnsafeBytes { buffer in
            #if canImport(Darwin)
            let result = setxattr(path, key, buffer.baseAddress!, buffer.count, 0, followSymLinks ? 0 : XATTR_NOFOLLOW)
            #else
            var result: Int32
            if followSymLinks {
                result = lsetxattr(path, key, buffer.baseAddress!, buffer.count, 0)
            } else {
                result = setxattr(path, key, buffer.baseAddress!, buffer.count, 0)
            }
            #endif
            #if os(macOS) && FOUNDATION_FRAMEWORK
            // if setxaddr failed and its a permission error for a sandbox app trying to set quaratine attribute, ignore it since its not
            // permitted, the attribute will be put on the file by the quaratine MAC hook
            if result == -1 && errno == EPERM && _xpc_runtime_is_app_sandboxed() && strcmp(key, "com.apple.quarantine") == 0 {
                return
            }
            #endif
            if result == -1 {
                throw CocoaError.errorWithFilePath(String(cString: path), errno: errno, reading: false)
            }
        }
    }
    
    static func _setAttributes(_ attributes: [String : Data], at path: UnsafePointer<CChar>, followSymLinks: Bool) throws {
        for (key, value) in attributes {
            try key.withCString {
                try Self._setAttribute($0, value: value, at: path, followSymLinks: followSymLinks)
            }
        }
    }
    
    #if FOUNDATION_FRAMEWORK
    static func _fileProtectionValueForPath(_ fileSystemRepresentation: UnsafePointer<CChar>) -> Int32? {
        var attrList = attrlist()
        attrList.bitmapcount = u_short(ATTR_BIT_MAP_COUNT)
        attrList.commonattr = attrgroup_t(ATTR_CMN_DATA_PROTECT_FLAGS)
        typealias Buffer = (length: UInt32, class: Int32)
        var attributesBuffer: Buffer = (0, 0)
        let result = withUnsafeMutableBytes(of: &attributesBuffer) { buffer in
            getattrlist(fileSystemRepresentation, &attrList, buffer.baseAddress!, buffer.count, .init(FSOPT_NOFOLLOW))
        }
        guard result == 0 else {
            return nil
        }
        return attributesBuffer.class
    }
    
    static func _setFileProtectionValueForPath(_ path: String, _ fileSystemRepresentation: UnsafePointer<CChar>, newValue: Int32) throws {
        // It's probably better to do a single getattrlist than and open()/fcntl()/close(), so skip the work in case the value is already set correctly.
        guard Self._fileProtectionValueForPath(fileSystemRepresentation) != newValue else {
            return
        }
        
        var fd = open(fileSystemRepresentation, O_WRONLY)
        var dir: UnsafeMutablePointer<DIR>?
        defer {
            // For opendir(), the DIR structure owns the fd. Don't attempt to close it ourselves. 14323986.
            if let dir {
                closedir(dir)
            } else if fd >= 0 {
                close(fd)
            }
        }
        
        // If open() failed because the file is a directory, try again using opendir/dirfd.
        if fd < 0 && errno == EISDIR {
            dir = opendir(fileSystemRepresentation)
            if let dir {
                fd = dirfd(dir)
            }
        }
        
        if fd >= 0 {
            if fcntl(fd, F_SETPROTECTIONCLASS, newValue) != 0 {
                guard errno == ENOTSUP else {
                    throw CocoaError.errorWithFilePath(path, errno: errno, reading: true)
                }
                
                // If we fail with ENOTSUP because the volume doesn't support file protection, then no-op.
                var s = statfs()
                guard fstatfs(fd, &s) != 0 || s.f_flags & UInt32(MNT_CPROTECT) == 0 else {
                    throw CocoaError.errorWithFilePath(path, errno: ENOTSUP, reading: true)
                }
            }
        } else if errno == EACCES {
            // We don't have any alternative API for setting the protection class, so we must open() for fnctl(). If we don't have write permissions, the open() will fail with EACCES. None of the other NSFileManager attributes fail in this case, so it is unreasonable (and binary incompatible) to cause the NSFileManager methods to fail when this happens. <rdar://7796261>
            // This results in silent failures, but we simply don't have any other alternatives. <rdar://7837261> was a request for a path-based API with similar semantics to chmod, etc., but the OS team decided not to fix it.
            return
        } else {
            throw CocoaError.errorWithFilePath(path, errno: errno, reading: true)
        }
    }
    #endif
    
    static func _userAccountNameToNumber(_ name: String) -> uid_t? {
        name.withCString { ptr in
            getpwnam(ptr)?.pointee.pw_uid
        }
    }
    
    static func _groupAccountNameToNumber(_ name: String) -> gid_t? {
        name.withCString { ptr in
            getgrnam(ptr)?.pointee.gr_gid
        }
    }
}

extension FileManager {
    @nonobjc
    var safeDelegate: FileManagerDelegate? {
#if FOUNDATION_FRAMEWORK
        self._safeDelegate() as? FileManagerDelegate
#else
        self.delegate
#endif
    }
}
