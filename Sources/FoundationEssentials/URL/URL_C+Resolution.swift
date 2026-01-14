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

#if FOUNDATION_FRAMEWORK

internal import _ForSwiftFoundation

// MARK: - NSURL extensions for path and absolute URL resolution

@objc
extension NSURL {
    static func __copySwiftAbsoluteString(_ relativeHeader: UnsafePointer<__CFURLHeader>, baseHeader: UnsafePointer<__CFURLHeader>) -> Unmanaged<CFString>? {
        let relativeString = relativeHeader.pointee._string.takeUnretainedValue()
        let baseString = baseHeader.pointee._string.takeUnretainedValue()
        // +1 because we might need to prepend a slash to a relative path
        let maxLength = CFStringGetLength(relativeString) + CFStringGetLength(baseString) + 1
        return _withURLSpans(
            string1: relativeString,
            string2: baseString,
            blockIfASCII: { relativeSpan, baseSpan in
                return _createCFStringFromASCIIBuffer(capacity: maxLength) { absoluteBuffer in
                    return resolveURLBuffers(
                        relativeSpan: relativeSpan,
                        relativeHeader: relativeHeader,
                        baseSpan: baseSpan,
                        baseHeader: baseHeader,
                        into: absoluteBuffer
                    )
                }
            },
            blockIfUTF16: { relativeSpan, baseSpan in
                return _createCFStringFromCharacterBuffer(capacity: maxLength) { absoluteBuffer in
                    return resolveURLBuffers(
                        relativeSpan: relativeSpan,
                        relativeHeader: relativeHeader,
                        baseSpan: baseSpan,
                        baseHeader: baseHeader,
                        into: absoluteBuffer
                    )
                }
            }
        )
    }

    static func __copySwiftURLStringByResolvingPath(_ header: UnsafePointer<__CFURLHeader>) -> Unmanaged<CFString> {
        let string = header.pointee._string.takeUnretainedValue()
        let pathRange = header.pathRange
        guard !pathRange.isEmpty else {
            return Unmanaged<CFString>.passRetained(string)
        }
        return _withURLSpan(
            string: string,
            blockIfASCII: { span in
                return _createCFStringFromASCIIBuffer(capacity: span.count) { outputBuffer in
                    _ = outputBuffer.initialize(fromSpan: span.extracting(..<pathRange.endIndex))
                    let writeIndex = pathRange.startIndex + resolveDotSegmentsInPlace(buffer: outputBuffer[pathRange])
                    return outputBuffer[writeIndex...].initialize(
                        fromSpan: span.extracting(pathRange.endIndex...)
                    )
                }
            },
            blockIfUTF16: { span in
                return _createCFStringFromCharacterBuffer(capacity: span.count) { outputBuffer in
                    _ = outputBuffer.initialize(fromSpan: span.extracting(..<pathRange.endIndex))
                    let writeIndex = pathRange.startIndex + resolveDotSegmentsInPlace(buffer: outputBuffer[pathRange])
                    return outputBuffer[writeIndex...].initialize(
                        fromSpan: span.extracting(pathRange.endIndex...)
                    )
                }
            }
        ) ?? Unmanaged<CFString>.passRetained(string)
    }

    static func __copySwiftResolvedPath(_ relativePath: Unmanaged<CFString>, basePath: Unmanaged<CFString>) -> Unmanaged<CFString> {
        let relative = relativePath.takeUnretainedValue()
        let base = basePath.takeUnretainedValue()
        let maxLength = CFStringGetLength(relative) + CFStringGetLength(base)
        return _withURLSpans(
            string1: relative,
            string2: base,
            blockIfASCII: { relativeSpan, baseSpan in
                return _createCFStringFromASCIIBuffer(capacity: maxLength) { outputBuffer in
                    return resolve(relativePath: relativeSpan, basePath: baseSpan, into: outputBuffer)
                }
            },
            blockIfUTF16: { relativeSpan, baseSpan in
                return _createCFStringFromCharacterBuffer(capacity: maxLength) { outputBuffer in
                    return resolve(relativePath: relativeSpan, basePath: baseSpan, into: outputBuffer)
                }
            }
        ) ?? Unmanaged<CFString>.passRetained(base)
    }
}

#endif
