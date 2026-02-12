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

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif
#if FOUNDATION_FRAMEWORK
internal import Foundation_Private
#endif

internal import _FoundationICU

#if !FOUNDATION_FRAMEWORK
@_dynamicReplacement(for: _uidnaHook())
private func _uidnaHook_localized() -> UIDNAHook.Type? {
    return UIDNAHookICU.self
}
#endif

struct UIDNAHookICU: UIDNAHook {
    // `Sendable` notes: `UIDNA` from ICU is thread safe.
    struct UIDNAPointer : @unchecked Sendable {
        init(_ ptr: OpaquePointer?) { self.idnaTranscoder = ptr }
        var idnaTranscoder: OpaquePointer?
    }

    private static func U_SUCCESS(_ x: Int32) -> Bool {
        return x <= U_ZERO_ERROR.rawValue
    }

    private static let idnaTranscoder: UIDNAPointer? = {
        var status = U_ZERO_ERROR
        let options = UInt32(
            UIDNA_CHECK_BIDI                    |
            UIDNA_CHECK_CONTEXTJ                |
            UIDNA_NONTRANSITIONAL_TO_UNICODE    |
            UIDNA_NONTRANSITIONAL_TO_ASCII
        )
        let encoder = uidna_openUTS46(options, &status)
        guard U_SUCCESS(status.rawValue) else {
            return nil
        }
        return UIDNAPointer(encoder)
    }()

    private static func shouldAllow(_ errors: UInt32, encodeToASCII: Bool) -> Bool {
        let allowedErrors: UInt32
        if encodeToASCII {
            allowedErrors = 0
        } else {
            allowedErrors = UInt32(
                UIDNA_ERROR_EMPTY_LABEL             |
                UIDNA_ERROR_LABEL_TOO_LONG          |
                UIDNA_ERROR_DOMAIN_NAME_TOO_LONG    |
                UIDNA_ERROR_LEADING_HYPHEN          |
                UIDNA_ERROR_TRAILING_HYPHEN         |
                UIDNA_ERROR_HYPHEN_3_4
            )
        }
        return errors & ~allowedErrors == 0
    }

    /// Type of `uidna_nameToASCII` and `uidna_nameToUnicode` functions
    private typealias TranscodingFunction<T> = (OpaquePointer?, UnsafePointer<T>?, Int32, UnsafeMutablePointer<T>?, Int32, UnsafeMutablePointer<UIDNAInfo>?, UnsafeMutablePointer<UErrorCode>?) -> Int32

    private static func IDNACodedHost<T: FixedWidthInteger>(
        hostBuffer: UnsafeBufferPointer<T>,
        transcode: TranscodingFunction<T>,
        allowErrors: (UInt32) -> Bool,
        createString: (UnsafeMutablePointer<T>, Int) -> String?
    ) -> String? {
        let maxHostBufferLength = 2048
        if hostBuffer.count > maxHostBufferLength {
            return nil
        }

        guard let transcoder = idnaTranscoder else {
            return nil
        }

        let result: String? = withUnsafeTemporaryAllocation(of: T.self, capacity: maxHostBufferLength) { outBuffer in
            var processingDetails = UIDNAInfo(
                size: Int16(MemoryLayout<UIDNAInfo>.size),
                isTransitionalDifferent: 0,
                reservedB3: 0,
                errors: 0,
                reservedI2: 0,
                reservedI3: 0
            )
            var error = U_ZERO_ERROR

            let hostBufferPtr = hostBuffer.baseAddress!
            let outBufferPtr = outBuffer.baseAddress!

            let charsConverted = transcode(
                transcoder.idnaTranscoder,
                hostBufferPtr,
                Int32(hostBuffer.count),
                outBufferPtr,
                Int32(outBuffer.count),
                &processingDetails,
                &error
            )

            if U_SUCCESS(error.rawValue), allowErrors(processingDetails.errors), charsConverted > 0 {
                return createString(outBufferPtr, Int(charsConverted))
            }
            return nil
        }
        return result
    }

    private static func IDNACodedHostUTF8(_ utf8Buffer: UnsafeBufferPointer<UInt8>, encodeToASCII: Bool) -> String? {
        var transcode = uidna_nameToUnicodeUTF8
        if encodeToASCII {
            transcode = uidna_nameToASCII_UTF8
        }
        return utf8Buffer.withMemoryRebound(to: CChar.self) { charBuffer in
            return IDNACodedHost(
                hostBuffer: charBuffer,
                transcode: transcode,
                allowErrors: { errors in
                    shouldAllow(errors, encodeToASCII: encodeToASCII)
                },
                createString: { ptr, count in
                    let outBuffer = UnsafeBufferPointer(start: ptr, count: count).withMemoryRebound(to: UInt8.self) { $0 }
                    var hostsAreEqual = false
                    if outBuffer.count == utf8Buffer.count {
                        hostsAreEqual = true
                        for i in 0..<outBuffer.count {
                            if utf8Buffer[i] == outBuffer[i] {
                                continue
                            }
                            guard utf8Buffer[i]._lowercased == outBuffer[i] else {
                                hostsAreEqual = false
                                break
                            }
                        }
                    }
                    if hostsAreEqual {
                        return String._tryFromUTF8(utf8Buffer)
                    } else {
                        return String._tryFromUTF8(outBuffer)
                    }
                }
            )
        }
    }

    private static func IDNACodedHostUTF16(_ utf16Buffer: UnsafeBufferPointer<UInt16>, encodeToASCII: Bool) -> String? {
        var transcode = uidna_nameToUnicode
        if encodeToASCII {
            transcode = uidna_nameToASCII
        }
        return IDNACodedHost(
            hostBuffer: utf16Buffer,
            transcode: transcode,
            allowErrors: { errors in
                shouldAllow(errors, encodeToASCII: encodeToASCII)
            },
            createString: { ptr, count in
                let outBuffer = UnsafeBufferPointer(start: ptr, count: count)
                var hostsAreEqual = false
                if outBuffer.count == utf16Buffer.count {
                    hostsAreEqual = true
                    for i in 0..<outBuffer.count {
                        if utf16Buffer[i] == outBuffer[i] {
                            continue
                        }
                        guard utf16Buffer[i] < 128,
                              UInt8(utf16Buffer[i])._lowercased == outBuffer[i] else {
                            hostsAreEqual = false
                            break
                        }
                    }
                }
                if hostsAreEqual {
                    return String(_utf16: utf16Buffer)
                } else {
                    return String(_utf16: outBuffer)
                }
            }
        )
    }

    private static func IDNACodedHost(_ host: some StringProtocol, encodeToASCII: Bool) -> String? {
        let fastResult = host.utf8.withContiguousStorageIfAvailable {
            IDNACodedHostUTF8($0, encodeToASCII: encodeToASCII)
        }
        if let fastResult {
            return fastResult
        }
        #if FOUNDATION_FRAMEWORK
        if let fastCharacters = host._ns._fastCharacterContents() {
            let charsBuffer = UnsafeBufferPointer(start: fastCharacters, count: host._ns.length)
            return IDNACodedHostUTF16(charsBuffer, encodeToASCII: encodeToASCII)
        }
        #endif
        var hostString = String(host)
        return hostString.withUTF8 {
            IDNACodedHostUTF8($0, encodeToASCII: encodeToASCII)
        }
    }

    static func encode(_ host: some StringProtocol) -> String? {
        return IDNACodedHost(host, encodeToASCII: true)
    }

    static func decode(_ host: some StringProtocol) -> String? {
        return IDNACodedHost(host, encodeToASCII: false)
    }

    /// IDNA-encodes UTF16 characters from `input`, writing the ASCII result to `output`.
    ///
    /// - Note: This function checks the remaining capacity of `output` to ensure there's enough space to write.
    /// - Returns: `true` on success, `false` on failure or if `output` was too small.
    @_lifetime(output: copy output)
    static func nameToASCII(
        input: borrowing Span<UTF16.CodeUnit>,
        output: inout OutputSpan<Unicode.ASCII.CodeUnit>
    ) -> Bool {
        let maxHostBufferLength = 2048
        guard !input.isEmpty && input.count <= maxHostBufferLength else {
            return false
        }
        guard !output.isFull else {
            // No room to encode the non-empty input
            return false
        }
        guard let transcoder = idnaTranscoder else {
            return false
        }

        return input.withUnsafeBufferPointer { inBuffer in
            return withUnsafeTemporaryAllocation(of: UInt16.self, capacity: maxHostBufferLength) { outBuffer in
                var processingDetails = UIDNAInfo(
                    size: Int16(MemoryLayout<UIDNAInfo>.size),
                    isTransitionalDifferent: 0,
                    reservedB3: 0,
                    errors: 0,
                    reservedI2: 0,
                    reservedI3: 0
                )
                var error = U_ZERO_ERROR

                guard let inBufferPtr = inBuffer.baseAddress,
                      let outBufferPtr = outBuffer.baseAddress else {
                    return false
                }

                let convertedLength = uidna_nameToASCII(
                    transcoder.idnaTranscoder,
                    inBufferPtr,
                    Int32(inBuffer.count),
                    outBufferPtr,
                    Int32(outBuffer.count),
                    &processingDetails,
                    &error
                )

                guard U_SUCCESS(error.rawValue) && shouldAllow(processingDetails.errors, encodeToASCII: true) && convertedLength > 0 else {
                    return false
                }

                // Conversion succeeded and the result is ASCII
                guard convertedLength <= output.freeCapacity else {
                    return false
                }
                for v in outBuffer[..<Int(convertedLength)] {
                    output.append(UInt8(truncatingIfNeeded: v))
                }
                return true
            }
        }
    }
}
