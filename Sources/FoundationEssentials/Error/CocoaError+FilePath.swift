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
#elseif canImport(Bionic)
import Bionic
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif os(Windows)
import CRT
import WinSDK
#elseif os(WASI)
import WASILibc
#endif

// MARK: - Error Creation with CocoaError.Code

extension CocoaError {
    static func errorWithFilePath(_ code: CocoaError.Code, _ path: String, variant: String? = nil, source: String? = nil, destination: String? = nil) -> CocoaError {
        CocoaError(code, path: path, variant: variant, source: source, destination: destination)
    }
    
    static func errorWithFilePath(_ code: CocoaError.Code, _ url: URL, variant: String? = nil, source: String? = nil, destination: String? = nil) -> CocoaError {
        CocoaError(code, url: url, variant: variant, source: source, destination: destination)
    }
}

// MARK: - POSIX Errors

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

extension POSIXError {
    fileprivate init?(errno: Int32) {
        // (130280235) POSIXError.Code does not have a case for EOPNOTSUPP
        guard errno != EOPNOTSUPP else { return nil }
        guard let code = POSIXError.Code(rawValue: errno) else {
            fatalError("Invalid posix errno \(errno)")
        }
        self.init(code)
    }
}

extension CocoaError {
    static func errorWithFilePath(_ pathOrURL: PathOrURL, errno: Int32, reading: Bool, variant: String? = nil, source: String? = nil, destination: String? = nil) -> CocoaError {
        switch pathOrURL {
        case .path(let path):
            return Self.errorWithFilePath(path, errno: errno, reading: reading, variant: variant, source: source, destination: destination)
        case .url(let url):
            return Self.errorWithFilePath(url, errno: errno, reading: reading, variant: variant, source: source, destination: destination)
        }
    }
    
    static func errorWithFilePath(_ path: String, errno: Int32, reading: Bool, variant: String? = nil, source: String? = nil, destination: String? = nil) -> CocoaError {
        CocoaError(Code(fileErrno: errno, reading: reading), path: path, underlying: POSIXError(errno: errno), variant: variant, source: source, destination: destination)
    }
    
    static func errorWithFilePath(_ url: URL, errno: Int32, reading: Bool, variant: String? = nil, source: String? = nil, destination: String? = nil) -> CocoaError {
        CocoaError(Code(fileErrno: errno, reading: reading), url: url, underlying: POSIXError(errno: errno), variant: variant, source: source, destination: destination)
    }
}

// MARK: - Windows Errors

#if os(Windows)
extension CocoaError.Code {
    fileprivate init(win32: DWORD, reading: Bool, emptyPath: Bool? = nil) {
        self = switch (reading, win32) {
        case (true, ERROR_FILE_NOT_FOUND), (true, ERROR_PATH_NOT_FOUND):
            // Windows will return ERROR_FILE_NOT_FOUND or ERROR_PATH_NOT_FOUND
            // for empty paths.
            (emptyPath ?? false) ? .fileReadInvalidFileName : .fileReadNoSuchFile
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
            (emptyPath ?? false) ? .fileWriteInvalidFileName : .fileNoSuchFile
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
    }
}

extension CocoaError {
    static func errorWithFilePath(_ path: PathOrURL, win32 dwError: DWORD, reading: Bool) -> CocoaError {
        switch path {
        case let .path(path):
            return CocoaError(.init(win32: dwError, reading: reading, emptyPath: path.isEmpty), path: path, underlying: Win32Error(dwError))
        case let .url(url):
            let pathStr = url.withUnsafeFileSystemRepresentation { String(cString: $0!) }
            return CocoaError(.init(win32: dwError, reading: reading, emptyPath: pathStr.isEmpty), path: pathStr, url: url, underlying: Win32Error(dwError))
        }
    }
    
    static func errorWithFilePath(_ path: String? = nil, win32 dwError: DWORD, reading: Bool, variant: String? = nil, source: String? = nil, destination: String? = nil) -> CocoaError {
        return CocoaError(.init(win32: dwError, reading: reading, emptyPath: path?.isEmpty), path: path, underlying: Win32Error(dwError), variant: variant, source: source, destination: destination)
    }
}
#endif

// MARK: - OSStatus Errors

extension CocoaError {
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
        return CocoaError(errorCode, path: path, underlying: NSError(domain: NSOSStatusErrorDomain, code: osStatus), variant: variant)
        #else
        return CocoaError(errorCode, path: path, variant: variant)
        #endif
    }
}
    
// MARK: - Error creation funnel points

extension CocoaError {
    fileprivate init(
        _ code: CocoaError.Code,
        path: String? = nil,
        underlying: (some Error)? = Optional<CocoaError>.none,
        variant: String? = nil,
        source: String? = nil,
        destination: String? = nil
    ) {
        self.init(
            code,
            path: path,
            url: path.flatMap(URL.init(_fileManagerFailableFileURLWithPath:)),
            underlying: underlying,
            variant: variant,
            source: source,
            destination: destination
        )
    }
    
    fileprivate init(
        _ code: CocoaError.Code,
        url: URL,
        underlying: (some Error)? = Optional<CocoaError>.none,
        variant: String? = nil,
        source: String? = nil,
        destination: String? = nil
    ) {
        self.init(
            code,
            path: url.path,
            url: url,
            underlying: underlying,
            variant: variant,
            source: source,
            destination: destination
        )
    }
    
    fileprivate init(
        _ code: CocoaError.Code,
        path: String?,
        url: URL?,
        underlying: (some Error)? = Optional<CocoaError>.none,
        variant: String? = nil,
        source: String? = nil,
        destination: String? = nil
    ) {
        #if FOUNDATION_FRAMEWORK
        self.init(_uncheckedNSError: NSError._cocoaError(withCode: code.rawValue, path: path, url: url, underlying: underlying, variant: variant, source: source, destination: destination) as NSError)
        #else
        var userInfo: [String : Any] = [:]
        if let path {
            userInfo[NSFilePathErrorKey] = path
        }
        if let url {
            userInfo[NSURLErrorKey] = url
        }
        if let underlying {
            userInfo[NSUnderlyingErrorKey] = underlying
        }
        if let source {
            userInfo[NSSourceFilePathErrorKey] = source
        }
        if let destination {
            userInfo[NSDestinationFilePathErrorKey] = destination
        }
        if let variant {
            userInfo[NSUserStringVariantErrorKey] = [variant]
        }
        
        self.init(code, userInfo: userInfo)
        #endif
    }
}
