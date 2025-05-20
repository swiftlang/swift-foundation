//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
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

private extension String.Encoding {
    var _icuConverterName: String? {
        // TODO: Replace this with forthcoming(?) public property such as https://github.com/swiftlang/swift-foundation/pull/1243
        // Note: UTF-* and US-ASCII are omitted here because they are supposed to be converted upstream.
        switch self {
        case .japaneseEUC: "EUC-JP"
        case .isoLatin1: "ISO-8859-1"
        case .shiftJIS: "Shift_JIS"
        case .isoLatin2: "ISO-8859-2"
        case .windowsCP1251: "windows-1251"
        case .windowsCP1252: "windows-1252"
        case .windowsCP1253: "windows-1253"
        case .windowsCP1254: "windows-1254"
        case .windowsCP1250: "windows-1250"
        case .iso2022JP: "ISO-2022-JP"
        case .macOSRoman: "macintosh"
        default: nil
        }
    }
}

extension ICU {
    final class StringConverter: @unchecked Sendable {
        private let _converter: LockedState<OpaquePointer> // UConverter*

        let encoding: String.Encoding

        init?(encoding: String.Encoding) {
            guard let convName = encoding._icuConverterName else {
                return nil
            }
            var status: UErrorCode = U_ZERO_ERROR
            guard let converter = ucnv_open(convName, &status), status.isSuccess else {
                return nil
            }
            self._converter = LockedState(initialState: converter)
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
                        src.baseAddress,
                        srcLength,
                        &status
                    )
                }
            }
        }
    }

    func encode(string: String, allowLossyConversion lossy: Bool) -> Data?  {
        return _converter.withLock { (converter) -> Data? in
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
                    UCNV_FROM_U_CALLBACK_SUBSTITUTE,
                    nil, // newContext
                    nil, // oldAction
                    nil, // oldContext
                    &status
                )
                guard status.isSuccess else { return nil }
            } else {
                ucnv_setFromUCallBack(
                    converter,
                    UCNV_FROM_U_CALLBACK_STOP,
                    nil, // newContext
                    nil, // oldAction
                    nil, // oldContext
                    &status
                )
                guard status.isSuccess else { return nil }
            }

            let actualLength = ucnv_fromUChars(
                converter,
                dest,
                CInt(capacity),
                uchars.baseAddress,
                CInt(srcLength),
                &status
            )
            guard status.isSuccess else { return nil }
            return Data(
                bytesNoCopy: dest,
                count: Int(actualLength),
                deallocator: .custom({ pointer, _ in pointer.deallocate() })
            )
        }
    }
}

extension ICU.StringConverter {
    nonisolated(unsafe) static private var _converters: LockedState<[String.Encoding: ICU.StringConverter]> = .init(initialState: [:])

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


@_dynamicReplacement(for: _icuMakeStringFromBytes(_:encoding:))
func _icuMakeStringFromBytes_impl(_ bytes: UnsafeBufferPointer<UInt8>, encoding: String.Encoding) -> String? {
    guard let converter = ICU.StringConverter.converter(for: encoding),
          let pointer = bytes.baseAddress else {
        return nil
    }
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
