//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

#if os(Windows)

import WinSDK

package var COPY_FILE_FAIL_IF_EXISTS: DWORD {
    DWORD(WinSDK.COPY_FILE_FAIL_IF_EXISTS)
}

package var COPY_FILE_COPY_SYMLINK: DWORD {
    DWORD(WinSDK.COPY_FILE_COPY_SYMLINK)
}

package var COPY_FILE_NO_BUFFERING: DWORD {
    DWORD(WinSDK.COPY_FILE_NO_BUFFERING)
}

package var COPY_FILE_OPEN_AND_COPY_REPARSE_POINT: DWORD {
    DWORD(WinSDK.COPY_FILE_OPEN_AND_COPY_REPARSE_POINT)
}

package var COPY_FILE_DIRECTORY: DWORD {
    DWORD(WinSDK.COPY_FILE_DIRECTORY)
}

package var CREATE_ALWAYS: DWORD {
    DWORD(WinSDK.CREATE_ALWAYS)
}

package var CREATE_NEW: DWORD {
    DWORD(WinSDK.CREATE_NEW)
}

package var ERROR_ACCESS_DENIED: DWORD {
    DWORD(WinSDK.ERROR_ACCESS_DENIED)
}

package var ERROR_ALREADY_EXISTS: DWORD {
    DWORD(WinSDK.ERROR_ALREADY_EXISTS)
}

package var ERROR_BAD_ARGUMENTS: DWORD {
    DWORD(WinSDK.ERROR_BAD_ARGUMENTS)
}

package var ERROR_BAD_PATHNAME: DWORD {
    DWORD(WinSDK.ERROR_BAD_PATHNAME)
}

package var ERROR_DIRECTORY: DWORD {
    DWORD(WinSDK.ERROR_DIRECTORY)
}

package var ERROR_DISK_FULL: DWORD {
    DWORD(WinSDK.ERROR_DISK_FULL)
}

package var ERROR_DISK_RESOURCES_EXHAUSTED: DWORD {
    DWORD(WinSDK.ERROR_DISK_RESOURCES_EXHAUSTED)
}

package var ERROR_FILE_EXISTS: DWORD {
    DWORD(WinSDK.ERROR_FILE_EXISTS)
}

package var ERROR_FILE_NOT_FOUND: DWORD {
    DWORD(WinSDK.ERROR_FILE_NOT_FOUND)
}

package var ERROR_FILENAME_EXCED_RANGE: DWORD {
    DWORD(WinSDK.ERROR_FILENAME_EXCED_RANGE)
}

package var ERROR_INVALID_ACCESS: DWORD {
    DWORD(WinSDK.ERROR_INVALID_ACCESS)
}

package var ERROR_INVALID_DATA: DWORD {
    DWORD(WinSDK.ERROR_INVALID_DATA)
}

package var ERROR_INVALID_DRIVE: DWORD {
    DWORD(WinSDK.ERROR_INVALID_DRIVE)
}

package var ERROR_INVALID_NAME: DWORD {
    DWORD(WinSDK.ERROR_INVALID_NAME)
}

package var ERROR_LABEL_TOO_LONG: DWORD {
    DWORD(WinSDK.ERROR_LABEL_TOO_LONG)
}

package var ERROR_PATH_NOT_FOUND: DWORD {
    DWORD(WinSDK.ERROR_PATH_NOT_FOUND)
}

package var ERROR_SHARING_VIOLATION: DWORD {
    DWORD(WinSDK.ERROR_SHARING_VIOLATION)
}

package var ERROR_SUCCESS: DWORD {
    DWORD(WinSDK.ERROR_SUCCESS)
}

package var ERROR_WRITE_FAULT: DWORD {
    DWORD(WinSDK.ERROR_WRITE_FAULT)
}

package var FILE_ATTRIBUTE_DIRECTORY: DWORD {
    DWORD(WinSDK.FILE_ATTRIBUTE_DIRECTORY)
}

package var FILE_ATTRIBUTE_NORMAL: DWORD {
    DWORD(WinSDK.FILE_ATTRIBUTE_NORMAL)
}

package var FILE_ATTRIBUTE_READONLY: DWORD {
    DWORD(WinSDK.FILE_ATTRIBUTE_READONLY)
}

package var FILE_ATTRIBUTE_REPARSE_POINT: DWORD {
    DWORD(WinSDK.FILE_ATTRIBUTE_REPARSE_POINT)
}

package var FILE_FLAG_BACKUP_SEMANTICS: DWORD {
    DWORD(WinSDK.FILE_FLAG_BACKUP_SEMANTICS)
}

package var FILE_FLAG_OPEN_REPARSE_POINT: DWORD {
    DWORD(WinSDK.FILE_FLAG_OPEN_REPARSE_POINT)
}

package var FILE_MAP_READ: DWORD {
    DWORD(WinSDK.FILE_MAP_READ)
}

package var FILE_NAME_NORMALIZED: DWORD {
    DWORD(WinSDK.FILE_NAME_NORMALIZED)
}

package var FILE_SHARE_DELETE: DWORD {
    DWORD(WinSDK.FILE_SHARE_DELETE)
}

package var FILE_SHARE_READ: DWORD {
    DWORD(WinSDK.FILE_SHARE_READ)
}

package var FILE_SHARE_WRITE: DWORD {
    DWORD(WinSDK.FILE_SHARE_WRITE)
}

package var FILE_TYPE_CHAR: DWORD {
    DWORD(WinSDK.FILE_TYPE_CHAR)
}

package var FILE_TYPE_DISK: DWORD {
    DWORD(WinSDK.FILE_TYPE_DISK)
}

package var FILE_TYPE_PIPE: DWORD {
    DWORD(WinSDK.FILE_TYPE_PIPE)
}

package var FILE_TYPE_UNKNOWN: DWORD {
    DWORD(WinSDK.FILE_TYPE_UNKNOWN)
}

package var FIND_FIRST_EX_LARGE_FETCH: DWORD {
    DWORD(WinSDK.FIND_FIRST_EX_LARGE_FETCH)
}

package var FIND_FIRST_EX_ON_DISK_ENTRIES_ONLY: DWORD {
    DWORD(WinSDK.FIND_FIRST_EX_ON_DISK_ENTRIES_ONLY)
}

package var GENERIC_READ: DWORD {
    DWORD(WinSDK.GENERIC_READ)
}

package var GENERIC_WRITE: DWORD {
    DWORD(WinSDK.GENERIC_WRITE)
}

package var KF_FLAG_DEFAULT: DWORD {
    DWORD(WinSDK.KF_FLAG_DEFAULT.rawValue)
}

package var MOVEFILE_COPY_ALLOWED: DWORD {
    DWORD(WinSDK.MOVEFILE_COPY_ALLOWED)
}

package var MOVEFILE_REPLACE_EXISTING: DWORD {
    DWORD(WinSDK.MOVEFILE_REPLACE_EXISTING)
}

package var MOVEFILE_WRITE_THROUGH: DWORD {
    DWORD(WinSDK.MOVEFILE_WRITE_THROUGH)
}

package var OPEN_ALWAYS: DWORD {
    DWORD(WinSDK.OPEN_ALWAYS)
}

package var OPEN_EXISTING: DWORD {
    DWORD(WinSDK.OPEN_EXISTING)
}

package var PAGE_READONLY: DWORD {
    DWORD(WinSDK.PAGE_READONLY)
}

package var PATHCCH_ALLOW_LONG_PATHS: ULONG {
    ULONG(WinSDK.PATHCCH_ALLOW_LONG_PATHS.rawValue)
}

package var RRF_RT_REG_SZ: DWORD {
    DWORD(WinSDK.RRF_RT_REG_SZ)
}

package var SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE: DWORD {
    DWORD(WinSDK.SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE)
}

package var SYMBOLIC_LINK_FLAG_DIRECTORY: DWORD {
    DWORD(WinSDK.SYMBOLIC_LINK_FLAG_DIRECTORY)
}

package var TOKEN_QUERY: DWORD {
    DWORD(WinSDK.TOKEN_QUERY)
}

package var VOLUME_NAME_DOS: DWORD {
    DWORD(WinSDK.VOLUME_NAME_DOS)
}

package func PathAllocCombine(_ pszPathIn: String, _ pszMore: String, _ dwFlags: ULONG, _ ppszPathOut: UnsafeMutablePointer<PWSTR?>?) -> HRESULT {
    pszPathIn.withCString(encodedAs: UTF16.self) { pszPathIn in
        pszMore.withCString(encodedAs: UTF16.self) { pszMore in
            WinSDK.PathAllocCombine(pszPathIn, pszMore, dwFlags, ppszPathOut)
        }
    }
}

@inline(__always)
package func FAILED(_ hr: HRESULT) -> Bool {
    hr < 0
}

@inline(__always)
package func HRESULT_CODE(_ hr: HRESULT) -> DWORD {
    DWORD(hr) & 0xffff
}

@inline(__always)
package func HRESULT_FACILITY(_ hr: HRESULT) -> DWORD {
    DWORD(hr << 16) & 0x1fff
}

@inline(__always)
package func SUCCEEDED(_ hr: HRESULT) -> Bool {
    hr >= 0
}

// This is a non-standard extension to the Windows SDK that allows us to convert
// an HRESULT to a Win32 error code.
@inline(__always)
internal func WIN32_FROM_HRESULT(_ hr: HRESULT) -> DWORD {
    if SUCCEEDED(hr) { return ERROR_SUCCESS }
    if HRESULT_FACILITY(hr) == FACILITY_WIN32 {
        return HRESULT_CODE(hr)
    }
    return DWORD(hr)
}

#endif
