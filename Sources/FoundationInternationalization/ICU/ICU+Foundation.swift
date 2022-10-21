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

@_implementationOnly import FoundationICU

enum ICU { }

internal struct ICUError: Error, CustomDebugStringConvertible {
    var code: UErrorCode
    init(code: UErrorCode) {
        self.code = code
    }

    var debugDescription: String {
        String(utf8String: u_errorName(code)) ?? "Unknown ICU error \(code.rawValue)"
    }
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
}

/// Allocate a buffer with `initialSize` UChars and execute the given block.
/// If a larger buffer is needed, the closure may return `retry: true` alongside with the size for a larger buffer, and the block will be executed one more time.
internal func _withUCharBuffer(initialSize: Int32 = 32, _ body: (UnsafeMutablePointer<UChar>, _ size: Int32) -> (retry: Bool, newCapacity: Int32?)) {
    var retry = false
    var capacity: Int32?

    withUnsafeTemporaryAllocation(of: UChar.self, capacity: Int(initialSize)) {
        buffer in
        (retry, capacity) = body(buffer.baseAddress!, initialSize)
    }

    if retry, let capacity = capacity {
        withUnsafeTemporaryAllocation(of: UChar.self, capacity: Int(capacity)) {
            buffer in
            buffer.assign(repeating: 0)
            if let baseAddress = buffer.baseAddress {
                _ = body(baseAddress, capacity)
            }
        }
    }
}

/// Allocate a buffer with `size` UChars and execute the given block.
/// The closure should return the actual length of the string, or nil if
internal func _withFixedUCharBuffer(size: Int32 = ULOC_FULLNAME_CAPACITY + ULOC_KEYWORD_AND_VALUES_CAPACITY, _ body: (UnsafeMutablePointer<UChar>, Int32, inout UErrorCode) -> Int32?) -> String? {
    withUnsafeTemporaryAllocation(of: UChar.self, capacity: Int(size)) {
        buffer in
        var status = U_ZERO_ERROR
        if let len = body(buffer.baseAddress!, size, &status) {
            if status.isSuccess && len > 0 {
                return String(utf16CodeUnits: buffer.baseAddress!, count: Int(len))
            }
        }
        
        return nil
    }
}

internal func _withFixedCharBuffer(size: Int32 = ULOC_FULLNAME_CAPACITY + ULOC_KEYWORD_AND_VALUES_CAPACITY, _ body: (UnsafeMutablePointer<CChar>, Int32, inout UErrorCode) -> Int32?) -> String? {
    withUnsafeTemporaryAllocation(of: CChar.self, capacity: Int(size + 1)) { buffer in
        var status = U_ZERO_ERROR
        if let len = body(buffer.baseAddress!, size, &status) {
            if status.isSuccess && len > 0 {
                buffer[Int(len + 1)] = 0
                return String(utf8String: buffer.baseAddress!)
            }
        }
        
        return nil
    }
}
