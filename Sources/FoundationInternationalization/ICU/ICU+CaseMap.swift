//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

@_implementationOnly import FoundationICU
package import FoundationInternals

extension ICU {
    final class CaseMap : @unchecked Sendable {
        let casemap: OpaquePointer
        
        let lock: LockedState<Void>
        
        // Empty locale ("") means root locale
        init(localeID: String) throws {
            var status = U_ZERO_ERROR
            casemap = ucasemap_open(localeID, UInt32(), &status)
            try status.checkSuccess()
            
            lock = LockedState()
        }

        deinit {
            ucasemap_close(casemap)
        }

        private static let _cache: LockedState<[String : CaseMap]> = LockedState(initialState: [:])
        
        // Create and cache a new case mapping object for the specified locale
        internal static func caseMappingForLocale(_ localeID: String?) -> CaseMap? {
            let localeID = localeID ?? ""
            
            if let cached = _cache.withLock({ cache in cache[localeID] }) {
                return cached
            }
            
            guard let new = try? CaseMap(localeID: localeID) else {
                return nil
            }
            
            _cache.withLock { cache in
                cache[localeID] = new
            }
            
            return new
        }

        func lowercase(_ s: String) -> String? {
            s.utf8CString.withUnsafeBufferPointer { srcBuf in
                _withResizingCharBuffer { destBuf, destSize, status in
                    ucasemap_utf8ToLower(casemap, destBuf, destSize, srcBuf.baseAddress!, Int32(srcBuf.count), &status)
                }
            }
        }

        func uppercase(_ s: String) -> String? {
            s.utf8CString.withUnsafeBufferPointer { srcBuf in
                _withResizingCharBuffer { destBuf, destSize, status in
                    ucasemap_utf8ToUpper(casemap, destBuf, destSize, srcBuf.baseAddress!, Int32(srcBuf.count), &status)
                }
            }
        }

        func titlecase(_ s: String) -> String? {
            // `ucasemap_utf8ToTitle` isn't thread-safe
            lock.withLock {
                s.utf8CString.withUnsafeBufferPointer { srcBuf in
                    _withResizingCharBuffer { destBuf, destSize, status in
                        ucasemap_utf8ToTitle(casemap, destBuf, destSize, srcBuf.baseAddress!, Int32(srcBuf.count), &status)
                    }
                }
            }
        }

        func foldcase(_ s: String) -> String? {
            s.utf8CString.withUnsafeBufferPointer { srcBuf in
                _withResizingCharBuffer { destBuf, destSize, status in
                    ucasemap_utf8FoldCase(casemap, destBuf, destSize, srcBuf.baseAddress!, Int32(srcBuf.count), &status)
                }
            }
        }
    }
}
