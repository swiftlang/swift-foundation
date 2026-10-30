//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025-2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif
internal import _FoundationICU
internal import Synchronization
#if FOUNDATION_FRAMEWORK
import CoreFoundation
#endif

extension ICU {
    final class StringConverter: @unchecked Sendable {
        private let _converter: Mutex<OpaquePointer> // UConverter*

        let encoding: String.Encoding

        init?(encoding: String.Encoding) {
#if FOUNDATION_FRAMEWORK
            // `ianaName` has names only for the encodings that have a `String.Encoding` constant. CF has the names of the others, such as EUC-KR and GB18030. Fallback to that using CF if available.
            let name = encoding.ianaName ?? (CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(encoding.rawValue)) as String?)
#else
            let name = encoding.ianaName
#endif
            guard let convName = name else {
                return nil
            }
            var status: UErrorCode = U_ZERO_ERROR
            guard let converter = ucnv_open(convName, &status), status.isSuccess else {
                return nil
            }
            self._converter = Mutex(converter)
            self.encoding = encoding
        }

        deinit {
            _converter.withLock { ucnv_close($0) }
        }
    }
}

extension ICU.StringConverter {
    func decode(data: Data) -> String? {
        return _converter.withLock { converter in
            defer {
                ucnv_resetToUnicode(converter)
            }

            let srcLength = CInt(data.count)
            let initCapacity = srcLength * CInt(ucnv_getMinCharSize(converter)) + 1
            return _withResizingUCharBuffer(initialSize: initCapacity) { (dest, capacity, status) in
                return data.withUnsafeBytes { src in
                    ucnv_toUChars(
                        converter,
                        dest,
                        capacity,
                        src.baseAddress?.assumingMemoryBound(to: CChar.self),
                        srcLength,
                        &status
                    )
                }
            }
        }
    }
    
    private final class LossyDecodeState {
        let substitution: [UChar]
        let maxInvalidByteCount: Int
        var invalidByteCount = 0

        init(substitution: [UChar], maxInvalidByteCount: Int) {
            self.substitution = substitution
            self.maxInvalidByteCount = maxInvalidByteCount
        }
    }

    /// Decodes the data, and puts `substitution` in place of each byte that is not valid or has no mapping in the encoding. Returns the string and the number of bad bytes, or nil if the conversion fails.
    /// If there are more than `maxInvalidByteCount` bad bytes, the conversion stops there and the result is nil. Use this when a result with more bad bytes is not useful, so that a large input does not make a large string that is not used.
    func lossyDecode(bytes: RawSpan, substitution: String, maxInvalidByteCount: Int = .max) -> (string: String, invalidByteCount: Int)? {
        return _converter.withLock { converter in
            let state = LossyDecodeState(substitution: Array(substitution.utf16), maxInvalidByteCount: maxInvalidByteCount)
            let callback: UConverterToUCallback = { context, args, _, length, reason, err in
                guard reason == UCNV_UNASSIGNED || reason == UCNV_ILLEGAL || reason == UCNV_IRREGULAR, let context, let err else { return }
                let state = Unmanaged<LossyDecodeState>.fromOpaque(context).takeUnretainedValue()
                state.invalidByteCount += Int(length)
                guard state.invalidByteCount <= state.maxInvalidByteCount else {
                    // Leave a failure status, so that ucnv_toUnicode stops.
                    err.pointee = U_ILLEGAL_CHAR_FOUND
                    return
                }
                err.pointee = U_ZERO_ERROR
                guard !state.substitution.isEmpty else { return }
                // One substitution for each bad byte. ICU can report more than one byte at a time.
                state.substitution.withUnsafeBufferPointer { substitution in
                    for _ in 0..<length where err.pointee.isSuccess {
                        ucnv_cbToUWriteUChars(args, substitution.baseAddress, Int32(substitution.count), 0, err)
                    }
                }
            }

            // The converter is shared, so put back its callback when done. Otherwise the next conversion would use this callback after `state` is gone.
            var oldAction: UConverterToUCallback?
            var oldContext: UnsafeRawPointer?
            var status = U_ZERO_ERROR
            ucnv_setToUCallBack(converter, callback, Unmanaged.passUnretained(state).toOpaque(), &oldAction, &oldContext, &status)
            guard status.isSuccess else {
                return nil
            }
            defer {
                var status = U_ZERO_ERROR
                ucnv_setToUCallBack(converter, oldAction, oldContext, nil, nil, &status)
                ucnv_resetToUnicode(converter)
            }

            // Keep `state` alive while the callback can get its pointer.
            return withExtendedLifetime(state) { () -> (string: String, invalidByteCount: Int)? in
                bytes.withUnsafeBytes { src -> (string: String, invalidByteCount: Int)? in
                    guard let sourceStart = src.baseAddress?.assumingMemoryBound(to: CChar.self) else {
                        return ("", 0)
                    }
                    // ucnv_toUnicode moves `source` forward as it converts, so each chunk continues where the last one stopped.
                    var source: UnsafePointer<CChar>? = sourceStart
                    let sourceLimit = sourceStart + src.count

                    let string = _withPerpetuallyResizingUCharBuffer { outputSpan, status in
                        outputSpan.withUnsafeMutableBufferPointer { buffer, initializedCount in
                            let targetStart = buffer.baseAddress! + initializedCount
                            var target: UnsafeMutablePointer<UChar>? = targetStart
                            ucnv_toUnicode(converter, &target, buffer.baseAddress! + buffer.count, &source, sourceLimit, nil, .true, &status)
                            initializedCount += target! - targetStart
                        }
                    }
                    
                    guard let string else {
                        return nil
                    }
                    
                    return (string, state.invalidByteCount)
                }
            }
        }
    }

    func encode(string: String, allowLossyConversion lossy: Bool) -> Data?  {
        return self._converter.withLock { (converter) -> Data? in
            defer {
                ucnv_resetFromUnicode(converter)
            }

            let utf16Rep = string.utf16
            let uchars = UnsafeMutableBufferPointer<UChar>.allocate(capacity: utf16Rep.count)
            _ = uchars.initialize(fromContentsOf: utf16Rep)
            defer {
                uchars.deallocate()
            }

            let srcLength = uchars.count
            let capacity = srcLength * Int(ucnv_getMaxCharSize(converter)) + 1
            let dest = UnsafeMutableRawPointer.allocate(
                byteCount: capacity,
                alignment: MemoryLayout<CChar>.alignment
            )
            var shouldFreeDest = true
            defer {
                if shouldFreeDest {
                    dest.deallocate()
                }
            }

            var status: UErrorCode = U_ZERO_ERROR
            if lossy {
                var lossyChar: UChar = encoding == .ascii ? 0xFF : 0x3F
                ucnv_setSubstString(
                    converter,
                    &lossyChar,
                    1,
                    &status
                )
                guard status.isSuccess else { return nil }

                ucnv_setFromUCallBack(
                    converter,
                    { UCNV_FROM_U_CALLBACK_SUBSTITUTE($0, $1, $2, $3, $4, $5, $6) },
                    nil, // newContext
                    nil, // oldAction
                    nil, // oldContext
                    &status
                )
                guard status.isSuccess else { return nil }
            } else {
                ucnv_setFromUCallBack(
                    converter,
                    { UCNV_FROM_U_CALLBACK_STOP($0, $1, $2, $3, $4, $5, $6) },
                    nil, // newContext
                    nil, // oldAction
                    nil, // oldContext
                    &status
                )
                guard status.isSuccess else { return nil }
            }

            let actualLength = ucnv_fromUChars(
                converter,
                dest.assumingMemoryBound(to: CChar.self),
                CInt(capacity),
                uchars.baseAddress,
                CInt(srcLength),
                &status
            )
            guard status.isSuccess else { return nil }

            shouldFreeDest = false
            return Data(
                bytesNoCopy: dest,
                count: Int(actualLength),
                deallocator: .custom({ pointer, _ in pointer.deallocate() })
            )
        }
    }
}

extension ICU.StringConverter {
    private static let _converters: Mutex<[String.Encoding: ICU.StringConverter]> = .init([:])

    static func converter(for encoding: String.Encoding) -> ICU.StringConverter? {
        return _converters.withLock {
            if let converter = $0[encoding] {
                return converter
            }
            if let converter = ICU.StringConverter(encoding: encoding) {
                $0[encoding] = converter
                return converter
            }
            return nil
        }
    }
}


#if !FOUNDATION_FRAMEWORK
@_dynamicReplacement(for: _icuMakeStringFromBytes(_:encoding:))
func _icuMakeStringFromBytes_impl(_ bytes: UnsafeBufferPointer<UInt8>, encoding: String.Encoding) -> String? {
    guard let converter = ICU.StringConverter.converter(for: encoding),
          let pointer = bytes.baseAddress else {
        return nil
    }

    // Since we want to avoid unnecessary copy here,
    // `bytes` is converted to `UnsafeMutableRawPointer`
    // because `Data(bytesNoCopy:count:deallocator:)` accepts only that type.
    // This operation is still safe,
    // as the pointer is just borrowed (not escaped, not mutated)
    // in `ICU.StringConverter.decode(data:) -> String?`.
    // In addition to that, `Data` is useful here
    // because it is `Sendable` (and has CoW behavior).
    let data =  Data(
        bytesNoCopy: UnsafeMutableRawPointer(mutating: pointer),
        count: bytes.count,
        deallocator: .none
    )
    return converter.decode(data: data)
}

@_dynamicReplacement(for: _icuStringEncodingConvert(string:using:allowLossyConversion:))
func _icuStringEncodingConvert_impl(string: String, using encoding: String.Encoding, allowLossyConversion: Bool) -> Data? {
    guard let converter = ICU.StringConverter.converter(for: encoding) else {
        return nil
    }
    return converter.encode(string: string, allowLossyConversion: allowLossyConversion)
}
#endif
