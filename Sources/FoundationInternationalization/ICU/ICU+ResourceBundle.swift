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

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

#if canImport(Synchronization)
internal import Synchronization
#endif

extension ICU {

    // Wrapper for ICU's resource bundle
    internal final class ResourceBundle: Sendable {
        // Safe because it's only mutated at init and deinit
        private let lockedBundle: Mutex<OpaquePointer>

        init(packageName: String?, bundleName: String, direct: Bool) throws(ICUError) {
            let resourceBundle: OpaquePointer?
            var status: UErrorCode = U_ZERO_ERROR

            if direct {
                resourceBundle = ures_openDirect(packageName, bundleName, &status)
            } else {
                resourceBundle = ures_open(packageName, bundleName, &status)
            }
            try status.checkSuccess()

            guard let resourceBundle else {
                throw ICUError(code: status)
            }
            self.lockedBundle = Mutex(resourceBundle)
        }

        private init(existing: sending OpaquePointer) {
            self.lockedBundle = Mutex(existing)
        }

        deinit {
            lockedBundle.withLock{
                ures_close($0)
            }
        }

        func resourceBundle(forKey key: String) throws(ICUError) -> ResourceBundle? {
            let subBundle = try lockedBundle.withLock { bundle throws(ICUError) in
                var status: UErrorCode = U_ZERO_ERROR
                let subBundle = key.withCString { ptr in
                    ures_getByKey(bundle, ptr, nil, &status)
                }
                try status.checkSuccess()
                return subBundle
            }

            guard let subBundle else {
                // We're not throwing error here because it's valid for `subBundle` to be nil
                return nil
            }

            return ResourceBundle(existing: subBundle)
        }

        func resourceBundle(forIndex index: Int32) throws(ICUError) -> ResourceBundle? {
            let subBundle = try lockedBundle.withLock { bundle throws(ICUError) in
                var status: UErrorCode = U_ZERO_ERROR
                let subBundle = ures_getByIndex(bundle, index, nil, &status)

                try status.checkSuccess()
                return subBundle
            }

            guard let subBundle else {
                // We're not throwing error here because it's valid for `subBundle` to be nil
                return nil
            }
            return ResourceBundle(existing: subBundle)
        }

        func withIntegers<R: ~Copyable, E>(_ body: (Span<Int32>) throws(E)-> (R)) throws(E) -> R {
            let (vector, length) =  lockedBundle.withLock { bundle  in
                var length: Int32 = 0
                var status: UErrorCode = U_ZERO_ERROR

                let vector = ures_getIntVector(bundle, &length, &status)

                guard let vector, status.isSuccess else {
                    return (nil as UnsafePointer<Int32>?, 0)

                }
                return (vector, Int(length))
            }

            // Calling `body` from outside of the lock in case it takes a long time to finish
            return try body(UnsafeBufferPointer<Int32>(start: vector, count: length).span)
        }

        func withBinary<R: ~Copyable, E>(_ body: (Span<UInt8>) throws(E) -> (R)) throws(E) -> R {
            let (binary, length) = lockedBundle.withLock { bundle in
                var length: Int32 = 0
                var status: UErrorCode = U_ZERO_ERROR

                let binary = ures_getBinary(bundle, &length, &status)
                guard status.isSuccess else {
                    return (nil as UnsafePointer<UInt8>?, 0)
                }
                return (binary, Int(length))
            }

            // Calling `body` from outside of the lock in case it takes a long time to finish
            return try body(UnsafeBufferPointer<UInt8>(start: binary, count: length).span)
        }

        func asString() throws(ICUError) -> String {
            let (stringPtr, length) = try lockedBundle.withLock { bundle throws(ICUError) in
                var length: Int32 = 0
                var status: UErrorCode = U_ZERO_ERROR

                guard let stringPtr = ures_getString(bundle, &length, &status) else {
                    throw ICUError(code: U_INVALID_FORMAT_ERROR)
                }

                try status.checkSuccess()
                return (stringPtr, length)
            }

            guard let result = String(_utf16: stringPtr, count: Int(length)) else {
                throw ICUError(code: U_INVALID_FORMAT_ERROR)
            }
            return result
        }

        func asInteger() throws(ICUError) -> Int32 {
            try lockedBundle.withLock { bundle throws(ICUError) in
                var status: UErrorCode = U_ZERO_ERROR
                let int = ures_getInt(bundle, &status)
                try status.checkSuccess()
                return int
            }
        }

        var resourceType: UResType {
            lockedBundle.withLock { bundle in
                ures_getType(bundle)
            }
        }

        var size: Int32 {
            lockedBundle.withLock { bundle in
                ures_getSize(bundle)
            }
        }

    }
}

