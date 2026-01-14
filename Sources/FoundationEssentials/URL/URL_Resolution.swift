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

// MARK: - Path resolution

@_specialize(where T == UInt8)
@_specialize(where T == UInt16)
internal func resolve<T: UnsignedInteger & FixedWidthInteger>(
    relativePath: borrowing Span<T>,
    basePath: borrowing Span<T>,
    into absolutePath: UnsafeMutableBufferPointer<T>
) -> Int {
    // Append the relative path after the last slash in the base path
    var lastSlashIndex = basePath.indices.endIndex - 1
    while lastSlashIndex >= basePath.indices.startIndex && basePath[lastSlashIndex] != T(UInt8(ascii: "/")) {
        lastSlashIndex -= 1
    }
    guard lastSlashIndex >= basePath.indices.startIndex else {
        // No base slash, just use the relative path
        let pathEnd = absolutePath.initialize(fromSpan: relativePath)
        return resolveDotSegmentsInPlace(buffer: absolutePath[..<pathEnd])
    }
    let baseEnd = absolutePath.initialize(fromSpan: basePath.extracting(...lastSlashIndex))
    let pathEnd = absolutePath[baseEnd...].initialize(fromSpan: relativePath)
    return resolveDotSegmentsInPlace(buffer: absolutePath[..<pathEnd])
}

internal func resolve<T: UnsignedInteger & FixedWidthInteger>(
    relativePath: borrowing Span<T>,
    basePath: borrowing Span<T>,
    into absolutePath: Slice<UnsafeMutableBufferPointer<T>>
) -> Int {
    let absolute = UnsafeMutableBufferPointer(rebasing: absolutePath)
    return resolve(relativePath: relativePath, basePath: basePath, into: absolute)
}

// MARK: - Dot segment resolution

private enum RemovingDotState {
    case initial
    case dot
    case dotDot
    case slash
    case slashDot
    case slashDotDot
    case appendUntilSlash
    case skipSlashes
}

@_specialize(where T == UInt8)
@_specialize(where T == UInt16)
internal func resolveDotSegmentsInPlace<T: UnsignedInteger & FixedWidthInteger>(
    buffer: UnsafeMutableBufferPointer<T>
) -> Int {

    // Behavior differences from the old CFURL dot segment resolution:
    // - CFURL would leave all leading "/../" segments alone
    // - CFURL would leave a single leading "/./" segment alone
    // - New behavior prevents relative paths "a/../b" from becoming absolute

    // State machine for remove_dot_segments() from RFC 3986:
    //
    // First, remove all "./" and "../" prefixes by moving through the
    // .initial, .dot, and .dotDot states (without appending).
    //
    // Then, move through the remaining states/components, first checking if
    // the component is special ("/./" or "/../") so that we only append when
    // necessary.
    //
    // Note: There's a slight modification to the RFC algorithm to prevent
    // relative path segments from becoming absolute, which matters for URLs
    // that have both a relative path and relative base path. See note below.

    let dot = T(UInt8(ascii: "."))
    let slash = T(UInt8(ascii: "/"))

    var state = RemovingDotState.initial
    var writeIndex = 0
    for v in buffer {
        switch state {
        case .initial:
            if v == dot {
                state = .dot
            } else if v == slash {
                state = .slash
            } else {
                buffer[writeIndex] = v
                writeIndex += 1
                state = .appendUntilSlash
            }
        case .dot:
            if v == dot {
                state = .dotDot
            } else if v == slash {
                state = .initial
            } else {
                writeIndex = buffer[writeIndex...(writeIndex + 1)].initialize(
                    fromContentsOf: [dot, v]
                )
                state = .appendUntilSlash
            }
        case .dotDot:
            if v == slash {
                state = .initial
            } else {
                writeIndex = buffer[writeIndex...(writeIndex + 2)].initialize(
                    fromContentsOf: [dot, dot, v]
                )
                state = .appendUntilSlash
            }
        case .slash:
            if v == dot {
                state = .slashDot
            } else if v == slash {
                buffer[writeIndex] = slash
                writeIndex += 1
            } else {
                writeIndex = buffer[writeIndex...(writeIndex + 1)].initialize(
                    fromContentsOf: [slash, v]
                )
                state = .appendUntilSlash
            }
        case .slashDot:
            if v == dot {
                state = .slashDotDot
            } else if v == slash {
                state = .slash
            } else {
                writeIndex = buffer[writeIndex...(writeIndex + 2)].initialize(
                    fromContentsOf: [slash, dot, v]
                )
                state = .appendUntilSlash
            }
        case .slashDotDot:
            if v == slash {
                // Note: this diverges slightly from the RFC 3986 algorithm to prevent
                // relative paths from becoming absolute (e.g. "a/../b" -> "/b")
                if writeIndex == 0 {
                    // Replace "/../" with "/"
                    state = .slash
                } else if let lastSlash = buffer[..<writeIndex].lastIndex(of: slash) {
                    // Cheaply remove the previous component by moving writeIndex to its start
                    state = .slash
                    writeIndex = lastSlash
                } else {
                    // Last component is the start of a relative path, e.g. "a/../"
                    // We need to skip all subsequent slashes to make sure "a/..//"
                    // doesn't resolve to "/", then treat the next non-slash
                    // character as the start of a relative path
                    writeIndex = 0
                    state = .skipSlashes
                }
            } else {
                writeIndex = buffer[writeIndex...(writeIndex + 3)].initialize(fromContentsOf: [slash, dot, dot, v])
                state = .appendUntilSlash
            }
        case .appendUntilSlash:
            if v == slash {
                state = .slash
            } else {
                buffer[writeIndex] = v
                writeIndex += 1
            }
        case .skipSlashes:
            if v == slash {
                continue
            } else if v == dot {
                state = .dot
            } else {
                buffer[writeIndex] = v
                writeIndex += 1
                state = .appendUntilSlash
            }
        }
    }

    switch state {
    case .slash: fallthrough
    case .slashDot:
        buffer[writeIndex] = slash
        writeIndex += 1
    case .slashDotDot:
        // Note: "/.." is not yet appended to the buffer
        if writeIndex == 0 {
            // "/.." only, resolve to "/"
            buffer[writeIndex] = slash
            writeIndex += 1
        } else if let previousSlash = buffer[..<writeIndex].lastIndex(of: slash) {
            writeIndex = previousSlash + 1
        } else {
            // Delete the entire string, such as with "aaa/.."
            writeIndex = 0
        }
    default:
        break
    }

    // For compatibility, return "." instead of the empty string
    if writeIndex == 0 && !buffer.isEmpty {
        buffer[0] = dot
        return 1
    }

    return writeIndex
}

internal func resolveDotSegmentsInPlace<T: UnsignedInteger & FixedWidthInteger>(
    buffer: Slice<UnsafeMutableBufferPointer<T>>
) -> Int {
    let rebased = UnsafeMutableBufferPointer(rebasing: buffer)
    return resolveDotSegmentsInPlace(buffer: rebased)
}

// MARK: - URL header types for resolution

internal protocol _URLHeader {
    var schemeRange:    Range<Int> { get }
    var userRange:      Range<Int> { get }
    var passwordRange:  Range<Int> { get }
    var hostRange:      Range<Int> { get }
    var portRange:      Range<Int> { get }
    var pathRange:      Range<Int> { get }
    var queryRange:     Range<Int> { get }
    var fragmentRange:  Range<Int> { get }

    var hasScheme:      Bool { get }
    var hasUser:        Bool { get }
    var hasPassword:    Bool { get }
    var hasHost:        Bool { get }
    var hasPort:        Bool { get }
    var hasPath:        Bool { get }
    var hasQuery:       Bool { get }
    var hasFragment:    Bool { get }
}

private extension CFRange {
    @inline(__always)
    func toIntRange() -> Range<Int> {
        return Range(uncheckedBounds: (location, location + length))
    }
}

extension UnsafePointer<__CFURLHeader>: _URLHeader {
    var schemeRange:    Range<Int> { __getSchemeRangeUnchecked(self).toIntRange() }
    var userRange:      Range<Int> { __getUserRangeUnchecked(self).toIntRange() }
    var passwordRange:  Range<Int> { __getPasswordRangeUnchecked(self).toIntRange() }
    var hostRange:      Range<Int> { __getHostRangeUnchecked(self).toIntRange() }
    var portRange:      Range<Int> { __getPortRangeUnchecked(self).toIntRange() }
    var pathRange:      Range<Int> { __getPathRange(self).toIntRange() }
    var queryRange:     Range<Int> { __getQueryRangeUnchecked(self).toIntRange() }
    var fragmentRange:  Range<Int> { __getFragmentRangeUnchecked(self).toIntRange() }

    var hasScheme:      Bool { pointee._flags.contains(.hasScheme) }
    var hasUser:        Bool { pointee._flags.contains(.hasUser) }
    var hasPassword:    Bool { pointee._flags.contains(.hasPassword) }
    var hasHost:        Bool { pointee._flags.contains(.hasHost) }
    var hasPort:        Bool { pointee._flags.contains(.hasPort) }
    var hasPath:        Bool { true } // Path always exists
    var hasQuery:       Bool { pointee._flags.contains(.hasQuery) }
    var hasFragment:    Bool { pointee._flags.contains(.hasFragment) }
}

// MARK: - Absolute URL resolution

extension UnsafeMutableBufferPointer where Element: UnsignedInteger & FixedWidthInteger {
    func initialize(fromSpan span: borrowing Span<Element>) -> Self.Index {
        return span.withUnsafeBufferPointer { buffer in
            return self.initialize(fromContentsOf: buffer)
        }
    }
}

extension Slice {
    func initialize<T>(fromSpan span: borrowing Span<T>) -> Base.Index where Base == UnsafeMutableBufferPointer<T> {
        return span.withUnsafeBufferPointer { buffer in
            return self.initialize(fromContentsOf: buffer)
        }
    }
}

@_specialize(where T == UInt8,  Header == UnsafePointer<__CFURLHeader>)
@_specialize(where T == UInt16, Header == UnsafePointer<__CFURLHeader>)
internal func resolveURLBuffers<
    T: UnsignedInteger & FixedWidthInteger, Header: _URLHeader
>(
    relativeSpan: borrowing Span<T>,
    relativeHeader: Header,
    baseSpan: borrowing Span<T>,
    baseHeader: Header,
    into absoluteBuffer: UnsafeMutableBufferPointer<T>
) -> Int {
    // We should not have a scheme if we have a base URL
    assert(!relativeHeader.hasScheme)
    var writeIndex = 0
    if baseHeader.hasScheme {
        let baseSchemeEnd = baseHeader.schemeRange.endIndex
        writeIndex = absoluteBuffer.initialize(
            fromSpan: baseSpan.extracting(...baseSchemeEnd) // Include the ":"
        )
    }

    if relativeHeader.hasHost {
        return absoluteBuffer[writeIndex...].initialize(fromSpan: relativeSpan)
    }

    // Copy the base authority (everything up to its path)
    let basePathRange = baseHeader.pathRange
    writeIndex = absoluteBuffer[writeIndex...].initialize(
        fromSpan: baseSpan.extracting(writeIndex..<basePathRange.startIndex)
    )

    let relativePathRange = relativeHeader.pathRange
    if relativePathRange.isEmpty {
        // Copy the base path
        writeIndex = absoluteBuffer[writeIndex...].initialize(
            fromSpan: baseSpan.extracting(basePathRange)
        )
        if relativeHeader.hasQuery {
            // Copy everything after the relative path
            writeIndex = absoluteBuffer[writeIndex...].initialize(
                fromSpan: relativeSpan.extracting(relativePathRange.endIndex...)
            )
        } else if baseHeader.hasQuery {
            // No relative query, copy the base query including the leading "?"
            let baseQueryRange = baseHeader.queryRange
            writeIndex = absoluteBuffer[writeIndex...].initialize(
                fromSpan: baseSpan.extracting((baseQueryRange.startIndex - 1)..<baseQueryRange.endIndex)
            )
            // Copy the relative fragment, if present
            writeIndex = absoluteBuffer[writeIndex...].initialize(
                fromSpan: relativeSpan.extracting(relativePathRange.endIndex...)
            )
        }
        return writeIndex
    }

    // Resolve the relative and base paths
    let absolutePathStart = writeIndex
    if relativeSpan[relativePathRange.startIndex] == UInt8(ascii: "/") {
        // Relative path is absolute, don't use the base path
        writeIndex = absoluteBuffer[writeIndex...].initialize(
            fromSpan: relativeSpan.extracting(relativePathRange)
        )
    } else if basePathRange.isEmpty {
        // Relative path does not start with "/", and we have no base path.
        // If the base has a host, we need to make sure to prepend a "/".
        if baseHeader.hasHost {
            absoluteBuffer[writeIndex] = T(UInt8(ascii: "/"))
            writeIndex += 1
        }
        writeIndex = absoluteBuffer[writeIndex...].initialize(
            fromSpan: relativeSpan.extracting(relativePathRange)
        )
    } else {
        // Append the relative path after the last slash in the base path
        writeIndex += resolve(
            relativePath: relativeSpan.extracting(relativePathRange),
            basePath: baseSpan.extracting(basePathRange),
            into: absoluteBuffer[writeIndex...]
        )
    }

    // Resolve dot segments in the absolute path
    let absolutePathBuffer = UnsafeMutableBufferPointer(
        rebasing: absoluteBuffer[absolutePathStart..<writeIndex]
    )
    let absolutePathLength = resolveDotSegmentsInPlace(buffer: absolutePathBuffer)
    writeIndex = absolutePathStart + absolutePathLength

    // Copy the relative query and fragment if present and return the end index
    return absoluteBuffer[writeIndex...].initialize(
        fromSpan: relativeSpan.extracting(relativePathRange.endIndex...)
    )
}

#endif // FOUNDATION_FRAMEWORK
