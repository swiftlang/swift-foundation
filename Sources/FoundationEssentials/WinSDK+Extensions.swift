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

package var KF_FLAG_DEFAULT: DWORD {
    DWORD(WinSDK.KF_FLAG_DEFAULT.rawValue)
}

package var PATHCCH_ALLOW_LONG_PATHS: ULONG {
    ULONG(WinSDK.PATHCCH_ALLOW_LONG_PATHS.rawValue)
}

package var PATHCCH_ENSURE_IS_EXTENDED_LENGTH_PATH: ULONG {
    ULONG(WinSDK.PATHCCH_ENSURE_IS_EXTENDED_LENGTH_PATH.rawValue)
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

/// Calls a Win32 API function that fills a (potentially long path) null-terminated string buffer by continually attempting to allocate more memory up until the true max path is reached.
/// This is especially useful for protecting against race conditions like with GetCurrentDirectoryW where the measured length may no longer be valid on subsequent calls.
/// - parameter initialSize: Initial size of the buffer (including the null terminator) to allocate to hold the returned string.
/// - parameter maxSize: Maximum size of the buffer (including the null terminator) to allocate to hold the returned string.
/// - parameter body: Closure to call the Win32 API function to populate the provided buffer.
///   Should return the number of UTF-16 code units (not including the null terminator) copied, 0 to indicate an error.
///   If the buffer is not of sufficient size, should return a value greater than or equal to the size of the buffer.
internal func FillNullTerminatedWideStringBuffer(initialSize: DWORD, maxSize: DWORD, _ body: (UnsafeMutableBufferPointer<WCHAR>) throws -> DWORD) throws -> String {
    var bufferCount = max(1, min(initialSize, maxSize))
    while bufferCount <= maxSize {
        if let result = try withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: Int(bufferCount), { buffer in
            let count = try body(buffer)
            switch count {
            case 0:
                throw Win32Error(GetLastError())
            case 1..<DWORD(buffer.count):
                let result = String(decodingCString: buffer.baseAddress!, as: UTF16.self)
                assert(result.utf16.count == count, "Parsed UTF-16 count \(result.utf16.count) != reported UTF-16 count \(count)")
                return result
            default:
                bufferCount *= 2
                return nil
            }
        }) {
            return result
        }
    }
    throw Win32Error(ERROR_INSUFFICIENT_BUFFER)
}

#endif
