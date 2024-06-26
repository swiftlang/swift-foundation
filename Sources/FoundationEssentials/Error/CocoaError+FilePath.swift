//===----------------------------------------------------------------------===//
 //
 // This source file is part of the Swift.org open source project
 //
 // Copyright (c) 2024 Apple Inc. and the Swift project authors
 // Licensed under Apache License v2.0 with Runtime Library Exception
 //
 // See https://swift.org/LICENSE.txt for license information
 //
 //===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK
internal import _ForSwiftFoundation
#endif

#if canImport(Darwin)
import Darwin
#elseif os(Android)
import Bionic
#elseif canImport(Glibc)
import Glibc
#elseif os(Windows)
import CRT
import WinSDK
#endif

extension CocoaError.Code {
    fileprivate init(fileErrno: Int32, reading: Bool) {
        self = if reading {
            switch fileErrno {
            case EFBIG: .fileReadTooLarge
            case ENOENT: .fileReadNoSuchFile
            case EPERM, EACCES: .fileReadNoPermission
            case ENAMETOOLONG: .fileReadInvalidFileName
            default: .fileReadUnknown
            }
        } else {
            switch fileErrno {
            case ENOENT: .fileNoSuchFile
            case EPERM, EACCES: .fileWriteNoPermission
            case ENAMETOOLONG: .fileWriteInvalidFileName
#if !os(Windows)
            case EDQUOT: .fileWriteOutOfSpace
#endif
            case ENOSPC: .fileWriteOutOfSpace
            case EROFS: .fileWriteVolumeReadOnly
            case EEXIST: .fileWriteFileExists
            default: .fileWriteUnknown
            }
        }
    }
}

extension Dictionary<String, AnyHashable> {
    fileprivate func addingUserInfo(forPath path: String) -> Self {
        var dict = self
        dict[NSFilePathErrorKey] = path
        // Use the failable approach here bcause this could be an Error for a malformed path
        dict[NSURLErrorKey] = URL(_fileManagerFailableFileURLWithPath: path)
        return dict
    }
    
    fileprivate static func userInfo(forPath path: String) -> Self {
        Self().addingUserInfo(forPath: path)
    }
    
    fileprivate func addingUserInfo(forURL url: URL) -> Self {
        assert(url.isFileURL)
        var dict = self
        dict[NSURLErrorKey] = url
        dict[NSFilePathErrorKey] = url.path(percentEncoded: false)
        return dict
    }
    
    fileprivate static func userInfo(forURL url: URL) -> Self {
        Self().addingUserInfo(forURL: url)
    }
}

extension CocoaError {
    // MARK: Error Creation with CocoaError.Code
    
    static func errorWithFilePath(_ code: CocoaError.Code, _ path: String) -> CocoaError {
        CocoaError(code, userInfo: .userInfo(forPath: path))
    }
    
    static func errorWithFilePath(_ code: CocoaError.Code, _ url: URL) -> CocoaError {
        CocoaError(code, userInfo: .userInfo(forURL: url))
    }
    
    // MARK: Error Creation with errno
    
    private static func _errorWithErrno(_ errno: Int32, reading: Bool, variant: String?, userInfo: [String : AnyHashable]) -> CocoaError {
        var userInfo = userInfo
        
        // (130280235) POSIXError.Code does not have a case for EOPNOTSUPP
        if errno != EOPNOTSUPP {
            guard let code = POSIXError.Code(rawValue: errno) else {
                fatalError("Invalid posix errno \(errno)")
            }
            
            userInfo[NSUnderlyingErrorKey] = POSIXError(code)
        }
        if let variant {
            userInfo[NSUserStringVariantErrorKey] = [variant]
        }
        
        return CocoaError(Code(fileErrno: errno, reading: reading), userInfo: userInfo)
    }
    
    static func errorWithFilePath(_ pathOrURL: PathOrURL, errno: Int32, reading: Bool, variant: String? = nil, additionalUserInfo: [String : AnyHashable] = [:]) -> CocoaError {
        switch pathOrURL {
        case .path(let path):
            return Self.errorWithFilePath(path, errno: errno, reading: reading, variant: variant, additionalUserInfo: additionalUserInfo)
        case .url(let url):
            return Self.errorWithFilePath(url, errno: errno, reading: reading, variant: variant, additionalUserInfo: additionalUserInfo)
        }
    }
    
    static func errorWithFilePath(_ path: String, errno: Int32, reading: Bool, variant: String? = nil, additionalUserInfo: [String : AnyHashable] = [:]) -> CocoaError {
        Self._errorWithErrno(
            errno,
            reading: reading,
            variant: variant,
            userInfo: additionalUserInfo.addingUserInfo(forPath: path)
        )
    }
    
    static func errorWithFilePath(_ url: URL, errno: Int32, reading: Bool, variant: String? = nil, additionalUserInfo: [String : AnyHashable] = [:]) -> CocoaError {
        Self._errorWithErrno(
            errno,
            reading: reading,
            variant: variant,
            userInfo: additionalUserInfo.addingUserInfo(forURL: url)
        )
    }

    static func errorWithFilePath(_ code: CocoaError.Code, _ path: String, variant: String? = nil, userInfo: [String : AnyHashable] = [:]) -> CocoaError {
        var info: [String:AnyHashable] = userInfo.addingUserInfo(forPath: path)
        if let variant {
            info[NSUserStringVariantErrorKey] = [variant]
        }
        return CocoaError(code, userInfo: info)
    }

#if os(Windows)
    static func errorWithFilePath(_ path: PathOrURL, win32 dwError: DWORD, reading: Bool, variant: String? = nil, userInfo: [String : AnyHashable] = [:]) -> CocoaError {
        switch path {
        case let .path(path):
            return Self.errorWithFilePath(path, win32: dwError, reading: reading, variant: variant, userInfo: userInfo.addingUserInfo(forPath: path))
        case let .url(url):
            return Self.errorWithFilePath(url.withUnsafeFileSystemRepresentation { String(cString: $0!) }, win32: dwError, reading: reading, variant: variant, userInfo: userInfo.addingUserInfo(forURL: url))
        }
    }

    static func errorWithFilePath(_ path: String? = nil, win32 dwError: DWORD, reading: Bool, variant: String? = nil, userInfo: [String : AnyHashable] = [:]) -> CocoaError {
        let code: CocoaError.Code = switch (reading, dwError) {
            case (true, ERROR_FILE_NOT_FOUND), (true, ERROR_PATH_NOT_FOUND):
                // Windows will return ERROR_FILE_NOT_FOUND or ERROR_PATH_NOT_FOUND
                // for empty paths.
                (path?.isEmpty ?? false) ? .fileReadInvalidFileName : .fileReadNoSuchFile
            case (true, ERROR_ACCESS_DENIED): .fileReadNoPermission
            case (true, ERROR_INVALID_ACCESS): .fileReadNoPermission
            case (true, ERROR_INVALID_DRIVE): .fileReadNoSuchFile
            case (true, ERROR_SHARING_VIOLATION): .fileReadNoPermission
            case (true, ERROR_INVALID_NAME): .fileReadInvalidFileName
            case (true, ERROR_LABEL_TOO_LONG): .fileReadInvalidFileName
            case (true, ERROR_BAD_PATHNAME): .fileReadInvalidFileName
            case (true, ERROR_FILENAME_EXCED_RANGE): .fileReadInvalidFileName
            case (true, ERROR_DIRECTORY): .fileReadInvalidFileName
            case (true, _): .fileReadUnknown

            case (false, ERROR_FILE_NOT_FOUND), (false, ERROR_PATH_NOT_FOUND):
                // Windows will return ERROR_FILE_NOT_FOUND or ERROR_PATH_NOT_FOUND
                // for empty paths.
                (path?.isEmpty ?? false) ? .fileWriteInvalidFileName : .fileNoSuchFile
            case (false, ERROR_ACCESS_DENIED): .fileWriteNoPermission
            case (false, ERROR_INVALID_ACCESS): .fileWriteNoPermission
            case (false, ERROR_INVALID_DRIVE): .fileNoSuchFile
            case (false, ERROR_WRITE_FAULT): .fileWriteVolumeReadOnly
            case (false, ERROR_SHARING_VIOLATION): .fileWriteNoPermission
            case (false, ERROR_FILE_EXISTS): .fileWriteFileExists
            case (false, ERROR_DISK_FULL): .fileWriteOutOfSpace
            case (false, ERROR_INVALID_NAME): .fileWriteInvalidFileName
            case (false, ERROR_LABEL_TOO_LONG): .fileWriteInvalidFileName
            case (false, ERROR_BAD_PATHNAME): .fileWriteInvalidFileName
            case (false, ERROR_ALREADY_EXISTS): .fileWriteFileExists
            case (false, ERROR_FILENAME_EXCED_RANGE): .fileWriteInvalidFileName
            case (false, ERROR_DIRECTORY): .fileWriteInvalidFileName
            case (false, ERROR_DISK_RESOURCES_EXHAUSTED): .fileWriteOutOfSpace
            case (false, _): .fileWriteUnknown
        }

        var info: [String : AnyHashable] = userInfo
        info[NSUnderlyingErrorKey] = Win32Error(dwError)
        if let path, info[NSFilePathErrorKey] == nil {
            info[NSFilePathErrorKey] = path
        }
        if let variant {
            info[NSUserStringVariantErrorKey] = [variant]
        }

        return CocoaError(code, userInfo: info)
    }
#endif

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
