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

extension ICU {

    // Wrapper for ICU's resource bundle
    internal final class ResourceBundle: Sendable {
        // Safe because it's only mutated at init and deinit
        nonisolated(unsafe) private let lockedBundle: LockedState<OpaquePointer>

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
            self.lockedBundle = LockedState(initialState: resourceBundle)
        }

        private init(existing: OpaquePointer) {
            self.lockedBundle = LockedState(initialState: existing)
        }

        deinit {
            lockedBundle.withLock{
                ures_close($0)
            }
        }

        func resourceBundle(forKey key: String) throws(ICUError) -> ResourceBundle? {
            let subBundle = try lockedBundle.withLock { bundle throws(ICUError) in
                var status: UErrorCode = U_ZERO_ERROR
                let subBundle = ures_getByKey(bundle, key, nil, &status)
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

        func asIntegers() throws(ICUError) -> [Int32] {
            let (vector, length) = try lockedBundle.withLock { bundle throws(ICUError) in
                var length: Int32 = 0
                var status: UErrorCode = U_ZERO_ERROR

                let vector = ures_getIntVector(bundle, &length, &status)
                try status.checkSuccess()

                guard let vector else {
                    throw ICUError(code: U_INVALID_FORMAT_ERROR)
                }
                return (vector, length)
            }

            // FIXME: return Span if possible
            return Array(UnsafeBufferPointer(start: vector, count: Int(length)))
        }

        func getBinary() throws(ICUError) -> [UInt8] {
            let (binary, length) = try lockedBundle.withLock { bundle throws(ICUError) in
                var length: Int32 = 0
                var status: UErrorCode = U_ZERO_ERROR

                let binary = ures_getBinary(bundle, &length, &status)
                try status.checkSuccess()
                return (binary, length)
            }
            // FIXME: return Span if possible
            return Array(UnsafeBufferPointer(start: binary, count: Int(length)))
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

