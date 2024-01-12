//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK
// For Logger
@_implementationOnly import os
@_implementationOnly import _ForSwiftFoundation
@_implementationOnly import _CShims
#else
package import _CShims
#endif

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

internal func fileReadingOrWritingError(posixErrno: Int32, path: PathOrURL?, reading: Bool, variant: String? = nil, extraUserInfo: [String: AnyHashable] = [:]) -> Error {
    let code: CocoaError.Code
    if reading {
        switch posixErrno {
        case EFBIG:
            code = .fileReadTooLarge
        case ENOENT:
            code = .fileReadNoSuchFile
        case EPERM, EACCES:
            code = .fileReadNoPermission
        case ENAMETOOLONG:
            code = .fileReadInvalidFileName
        default:
            code = .fileReadUnknown
        }
    } else {
        switch posixErrno {
        case ENOENT:
            code = .fileNoSuchFile
        case EPERM, EACCES:
            code = .fileWriteNoPermission
        case ENAMETOOLONG:
            code = .fileWriteInvalidFileName
        case EDQUOT, ENOSPC:
            code = .fileWriteOutOfSpace
        case EROFS:
            code = .fileWriteVolumeReadOnly
        case EEXIST:
            code = .fileWriteFileExists
        default:
            code = .fileWriteUnknown
        }
    }
    
    var userInfo : [String : AnyHashable] = [:]
    if let posixError = POSIXErrorCode(rawValue: posixErrno) {
        userInfo[NSUnderlyingErrorKey] = POSIXError(posixError)
    }
    
    if let variant {
        userInfo[NSUserStringVariantErrorKey] = [variant]
    }
    
    if let path {
        switch path {
        case .path(let path):
            userInfo[NSFilePathErrorKey] = path
        case .url(let url):
            userInfo[NSURLErrorKey] = url
        }
    }
    
    if !extraUserInfo.isEmpty {
        for (k, v) in extraUserInfo {
            userInfo[k] = v
        }
    }
    
    return CocoaError(code, userInfo: userInfo)
}

internal func logFileIOErrno(_ err: Int32, at place: String) {
#if FOUNDATION_FRAMEWORK && !os(bridgeOS)
    let errnoDesc = String(cString: strerror(err))
    Logger(_NSOSLog()).error("Encountered \(place) failure \(err) \(errnoDesc)")
#endif
}
