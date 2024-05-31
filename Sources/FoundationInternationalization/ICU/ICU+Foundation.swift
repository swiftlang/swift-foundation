//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

internal import _FoundationICU

#if canImport(os)
internal import os
#endif

enum ICU { }

internal struct ICUError: Error, CustomDebugStringConvertible {
    var code: UErrorCode
    init(code: UErrorCode) {
        self.code = code
    }

    var debugDescription: String {
        String(validatingUTF8: u_errorName(code)) ?? "Unknown ICU error \(code.rawValue)"
    }

#if canImport(os)
    internal static let logger: Logger = {
        Logger(subsystem: "com.apple.foundation", category: "icu")
    }()
#endif
}

extension UErrorCode {
    func checkSuccess() throws {
        if !isSuccess {
            throw ICUError(code: self)
        }
    }

    var isSuccess: Bool {
        self.rawValue <= U_ZERO_ERROR.rawValue
    }

    func checkSuccessAndLogError(_ message: @escaping @autoclosure () -> String) -> Bool {
#if canImport(os)
        if !isSuccess {
            ICUError.logger.error("\(message()). Error: \(ICUError(code: self).debugDescription)")
        }
#endif
        return isSuccess
    }
}

/// Allocate a buffer with `size` `UChar`s and execute the given block.
/// The closure should return the actual length of the string, or nil if there is an error in the ICU call or the result is zero length.
internal func _withResizingUCharBuffer(initialSize: Int32 = 32, _ body: (UnsafeMutablePointer<UChar>, Int32, inout UErrorCode) -> Int32?) -> String? {
    withUnsafeTemporaryAllocation(of: UChar.self, capacity: Int(initialSize)) {
        buffer in
        var status = U_ZERO_ERROR
        if let len = body(buffer.baseAddress!, initialSize, &status) {
            if status == U_BUFFER_OVERFLOW_ERROR {
                // Retry, once
                return withUnsafeTemporaryAllocation(of: UChar.self, capacity: Int(len + 1)) { innerBuffer in
                    var innerStatus = U_ZERO_ERROR
                    if let innerLen = body(innerBuffer.baseAddress!, len + 1, &innerStatus) {
                        if innerStatus.isSuccess && innerLen > 0 {
                            return String(_utf16: innerBuffer, count: Int(innerLen))
                        }
                    }
                    
                    // At this point the retry has also failed
                    return nil
                }
            } else if status.isSuccess && len > 0 {
                return String(_utf16: buffer, count: Int(len))
            }
        }
        
        return nil
    }
}

/// Allocate a buffer with `size` `UChar`s and execute the given block.
/// The closure should return the actual length of the string, or nil if there is an error in the ICU call or the result is zero length. If `defaultIsError` is set to `true`, then `U_USING_DEFAULT_WARNING` is treated as an error instead of a warning.
internal func _withFixedUCharBuffer(size: Int32 = ULOC_FULLNAME_CAPACITY + ULOC_KEYWORD_AND_VALUES_CAPACITY, defaultIsError: Bool = false, _ body: (UnsafeMutablePointer<UChar>, Int32, inout UErrorCode) -> Int32?) -> String? {
    withUnsafeTemporaryAllocation(of: UChar.self, capacity: Int(size)) {
        buffer in
        var status = U_ZERO_ERROR
        if let len = body(buffer.baseAddress!, size, &status) {
            if status.isSuccess && !(defaultIsError && status == U_USING_DEFAULT_WARNING) && len <= size && len > 0 {
                return String(_utf16: buffer, count: Int(len))
            }
        }
        
        return nil
    }
}

/// Allocate a buffer with `size` `CChar`s and execute the given block.
/// The closure should return the actual length of the string, or nil if there is an error in the ICU call or the result is zero length.
internal func _withResizingCharBuffer(initialSize: Int32 = 32, _ body: (UnsafeMutablePointer<CChar>, Int32, inout UErrorCode) -> Int32?) -> String? {
    withUnsafeTemporaryAllocation(of: CChar.self, capacity: Int(initialSize)) {
        buffer in
        var status = U_ZERO_ERROR
        if let len = body(buffer.baseAddress!, initialSize, &status) {
            if status == U_BUFFER_OVERFLOW_ERROR {
                // Retry, once
                return withUnsafeTemporaryAllocation(of: CChar.self, capacity: Int(len + 1)) { innerBuffer in
                    var innerStatus = U_ZERO_ERROR
                    if let innerLen = body(innerBuffer.baseAddress!, len + 1, &innerStatus) {
                        if innerStatus.isSuccess && innerLen > 0 {
                            return String(validatingUTF8: innerBuffer.baseAddress!)
                        }
                    }

                    // At this point the retry has also failed
                    return nil
                }
            } else if status.isSuccess && len > 0 {
                return String(validatingUTF8: buffer.baseAddress!)
            }
        }

        return nil
    }
}

/// Allocate a buffer with `size` `CChar`s and execute the given block. The result is always null-terminated.
/// The closure should return the actual length of the string, or nil if there is an error in the ICU call or the result is zero length.
internal func _withFixedCharBuffer(size: Int32 = ULOC_FULLNAME_CAPACITY + ULOC_KEYWORD_AND_VALUES_CAPACITY, _ body: (UnsafeMutablePointer<CChar>, Int32, inout UErrorCode) -> Int32?) -> String? {
    withUnsafeTemporaryAllocation(of: CChar.self, capacity: Int(size + 1)) { buffer in
        var status = U_ZERO_ERROR
        if let len = body(buffer.baseAddress!, size, &status) {
            if status.isSuccess && len > 0 {
                buffer[Int(len + 1)] = 0
                return String(validatingUTF8: buffer.baseAddress!)
            }
        }
        
        return nil
    }
}

/// Use this function for ICU API which takes a C string and returns a C string. ICU may choose to return the original pointer, making the usual pattern of simply calling `String(cString: result)` use deallocated memory.
/// See also: rdar://104711456 and rdar://104710940
internal func _withStringAsCString(_ input: String, _ body: (UnsafePointer<CChar>) -> UnsafePointer<CChar>?) -> String? {
    return input.utf8CString.withUnsafeBufferPointer { buffer -> String? in
        // Intentional force unwrap
        let base = buffer.baseAddress!
        guard let result = body(base) else {
            return nil
        }
        
        guard result != base else {
            // ICU has returned the same pointer to us, without a copy. In order to avoid using deallocated memory (the buffer that Swift inserted to wrap the String), avoid accessing the returned pointer.
            return input
        }
        
        return String(cString: result)
    }
}
