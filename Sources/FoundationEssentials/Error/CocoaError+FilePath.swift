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
#elseif canImport(Glibc)
import Glibc
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
            case EDQUOT, ENOSPC: .fileWriteOutOfSpace
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
        dict[NSURLErrorKey] = URL(fileURLWithPath: path)
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
        guard let code = POSIXError.Code(rawValue: errno) else {
            fatalError("Invalid posix errno \(errno)")
        }
        
        var userInfo = userInfo
        userInfo[NSUnderlyingErrorKey] = POSIXError(code)
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
