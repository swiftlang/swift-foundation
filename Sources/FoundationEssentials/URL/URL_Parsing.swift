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

// Note: we should consolidate the parsing logic in URLParser.swift to call
// into these functions, but keep them separate for now to minimize risk while
// we test the new implementations.
#if FOUNDATION_FRAMEWORK

internal import _ForSwiftFoundation

// MARK: - Encoding types for URL buffers

// URL types percent-encode invalid characters using their UTF8 representation,
// regardless of the original string encoding. If we do need to percent-encode
// characters while parsing the original string, the _URLEncoding protocol
// provides functions for converting the input to UTF8.

internal protocol _URLEncoding {
    associatedtype CodeUnit: UnsignedInteger, FixedWidthInteger
    static var _maxUTF8BytesPerCharacter: Int { get }
    static func _withUTF8<R>(
        input: borrowing Span<Self.CodeUnit>,
        block: (consuming Span<UTF8.CodeUnit>) -> R
    ) -> R

    // ICU's uidna_nameToASCII conversion is fastest with UTF16, so supply
    // UTF16 if we have it (especially for UTF16-backed CF/NSStrings).
    static func _withUTF16<R>(
        input: borrowing Span<Self.CodeUnit>,
        block: (consuming Span<UTF16.CodeUnit>) -> R
    ) -> R
}

// CFURL parsing uses either an 8-bit ASCII or 16-bit UTF16 span from the
// original CFString. The component CFRanges depend on this original encoding
// used for parsing, so when resolving relative and base URLs, both must use
// the same original string encoding to ensure these ranges are valid. See
// URL_C+Spans.swift for more info.

// Swift URL always parses its String using the UTF8 bytes. To consolidate
// specialized implementations, treat an ASCII buffer from CFURL as UTF8, too.

extension UTF8: _URLEncoding {
    internal static let _maxUTF8BytesPerCharacter = 1
    internal static func _withUTF8<R>(
        input: borrowing Span<UTF8.CodeUnit>,
        block: (borrowing Span<UTF8.CodeUnit>) -> R
    ) -> R {
        // No change needed to convert UTF8 to itself
        return block(input)
    }

    internal static func _withUTF16<R>(
        input: borrowing Span<UTF8.CodeUnit>,
        block: (borrowing Span<UTF16.CodeUnit>) -> R
    ) -> R {
        // Max 1 UTF16 character per UTF8 byte
        return withUnsafeTemporaryAllocation(
            of: UTF16.CodeUnit.self,
            capacity: input.count
        ) { utf16Buffer in
            var outputSpan = OutputSpan(buffer: utf16Buffer, initializedCount: 0)
            // Need UnsafeBufferPointer to make the iterator for transcoding
            return input.withUnsafeBufferPointer {
                _ = Swift.transcode(
                    $0.makeIterator(),
                    from: UTF8.self,
                    to: UTF16.self,
                    stoppingOnError: false
                ) { utf16CodeUnit in
                    outputSpan.append(utf16CodeUnit)
                }
                return block(outputSpan.span)
            }
        }
    }
}

extension UTF16: _URLEncoding {
    internal static let _maxUTF8BytesPerCharacter = 3
    internal static func _withUTF8<R>(
        input: borrowing Span<UTF16.CodeUnit>,
        block: (borrowing Span<UTF8.CodeUnit>) -> R
    ) -> R {
        return withUnsafeTemporaryAllocation(
            of: UTF8.CodeUnit.self,
            capacity: _maxUTF8BytesPerCharacter * input.count
        ) { utf8Buffer in
            var outputSpan = OutputSpan(buffer: utf8Buffer, initializedCount: 0)
            // Need UnsafeBufferPointer to make the iterator for transcoding
            return input.withUnsafeBufferPointer {
                _ = Swift.transcode(
                    $0.makeIterator(),
                    from: UTF16.self,
                    to: UTF8.self,
                    stoppingOnError: false
                ) { utf8CodeUnit in
                    outputSpan.append(utf8CodeUnit)
                }
                return block(outputSpan.span)
            }
        }
    }

    internal static func _withUTF16<R>(
        input: borrowing Span<UTF16.CodeUnit>,
        block: (borrowing Span<UTF16.CodeUnit>) -> R
    ) -> R {
        // No change needed to convert UTF16 to itself
        return block(input)
    }
}

// MARK: - URL implementation types

internal typealias _URLFlags = __CFURLFlags

internal protocol _URLParseable {
    static var maxStringLength: Int { get }

    var schemeRange:    Range<Int> { get set }
    var userRange:      Range<Int> { get set }
    var passwordRange:  Range<Int> { get set }
    var hostRange:      Range<Int> { get set }
    var portRange:      Range<Int> { get set }
    var pathRange:      Range<Int> { get set }
    var queryRange:     Range<Int> { get set }
    var fragmentRange:  Range<Int> { get set }

    /// Sets the original string in the URL implementation.
    /// - Note: For `CFURL` implementations, this stores a retained `CFString`.
    mutating func setOriginalString(_ string: String)

    /// Sets the encoded string in the URL implementation.
    /// - Note: For `CFURL` implementations, this stores a retained `CFString`.
    mutating func setEncodedString(_ string: String)
}

private extension CFRange {
    @inline(__always)
    func toIntRange() -> Range<Int> {
        return Range(uncheckedBounds: (location, location + length))
    }
}

internal extension __CFURLRange {
    @inline(__always)
    init(_ range: Range<Int>) {
        self = __CFURLRange(
            location: UInt16(truncatingIfNeeded: range.startIndex),
            length: UInt16(truncatingIfNeeded: range.endIndex - range.startIndex)
        )
    }

    @inline(__always)
    func toIntRange() -> Range<Int> {
        return Range(uncheckedBounds: (Int(location), Int(location) + Int(length)))
    }
}

extension __CFSmallURLImpl: _URLParseable {
    static var maxStringLength: Int { Int(UInt16.max) }

    var schemeRange: Range<Int> {
        get { _schemeRange.toIntRange() }
        set { _schemeRange = __CFURLRange(newValue) }
    }

    var userRange: Range<Int> {
        get { _userRange.toIntRange() }
        set { _userRange = __CFURLRange(newValue) }
    }

    var passwordRange: Range<Int> {
        get { _passwordRange.toIntRange() }
        set { _passwordRange = __CFURLRange(newValue) }
    }

    var hostRange: Range<Int> {
        get { _hostRange.toIntRange() }
        set { _hostRange = __CFURLRange(newValue) }
    }

    var portRange: Range<Int> {
        get { _portRange.toIntRange() }
        set { _portRange = __CFURLRange(newValue) }
    }

    var pathRange: Range<Int> {
        get { _pathRange.toIntRange() }
        set { _pathRange = __CFURLRange(newValue) }
    }

    var queryRange: Range<Int> {
        get { _queryRange.toIntRange() }
        set { _queryRange = __CFURLRange(newValue) }
    }

    var fragmentRange: Range<Int> {
        get { _fragmentRange.toIntRange() }
        set { _fragmentRange = __CFURLRange(newValue) }
    }

    mutating func setOriginalString(_ string: String) {
        _header._string = Unmanaged.passRetained(string as CFString)
    }

    mutating func setEncodedString(_ string: String) {
        _header._encodedString = Unmanaged.passRetained(string as CFString)
    }
}

extension __CFBigURLImpl: _URLParseable {
    static var maxStringLength: Int { CFIndex.max }

    var schemeRange: Range<Int> {
        get { _schemeRange.toIntRange() }
        set { _schemeRange = CFRange(location: newValue.startIndex, length: newValue.count) }
    }

    var userRange: Range<Int> {
        get { _userRange.toIntRange() }
        set { _userRange = CFRange(location: newValue.startIndex, length: newValue.count) }
    }

    var passwordRange: Range<Int> {
        get { _passwordRange.toIntRange() }
        set { _passwordRange = CFRange(location: newValue.startIndex, length: newValue.count) }
    }

    var hostRange: Range<Int> {
        get { _hostRange.toIntRange() }
        set { _hostRange = CFRange(location: newValue.startIndex, length: newValue.count) }
    }

    var portRange: Range<Int> {
        get { _portRange.toIntRange() }
        set { _portRange = CFRange(location: newValue.startIndex, length: newValue.count) }
    }

    var pathRange: Range<Int> {
        get { _pathRange.toIntRange() }
        set { _pathRange = CFRange(location: newValue.startIndex, length: newValue.count) }
    }

    var queryRange: Range<Int> {
        get { _queryRange.toIntRange() }
        set { _queryRange = CFRange(location: newValue.startIndex, length: newValue.count) }
    }

    var fragmentRange: Range<Int> {
        get { _fragmentRange.toIntRange() }
        set { _fragmentRange = CFRange(location: newValue.startIndex, length: newValue.count) }
    }

    mutating func setOriginalString(_ string: String) {
        _header._string = Unmanaged.passRetained(string as CFString)
    }

    mutating func setEncodedString(_ string: String) {
        _header._encodedString = Unmanaged.passRetained(string as CFString)
    }
}

// MARK: - Component parsing

private func parse<T: _URLEncoding, Impl: _URLParseable>(
    _ type: T.Type,
    buffer: UnsafeBufferPointer<T.CodeUnit>,
    into impl: UnsafeMutablePointer<Impl>,
    flags: inout _URLFlags
) {
    // Path always exists, even if empty.
    guard !buffer.isEmpty else {
        // An empty relative path is technically decomposable.
        flags.insert(.isDecomposable)
        impl.pointee.pathRange = 0..<0
        return
    }

    let endIndex = buffer.count
    var currentIndex = 0

    // MARK: Scheme

    // Even in compatibility mode, non-empty scheme must start with ALPHA.
    let first = buffer[0]
    if first < 128 && UInt8(truncatingIfNeeded: first).isAlpha {
        currentIndex += 1
        while currentIndex != endIndex {
            let v = buffer[currentIndex]
            if v == UInt8(ascii: ":") {
                flags.insert(.hasScheme)
                impl.pointee.schemeRange = 0..<currentIndex
                currentIndex += 1
                break
            } else if !URLComponentAllowedSet.scheme.contains(v) {
                // For compatibility, now treat this as a relative-ref.
                break
            }
            currentIndex += 1
        }
    } else if first == UInt8(ascii: ":") {
        // Scheme can be empty for compatibility.
        flags.insert(.hasScheme)
        impl.pointee.schemeRange = 0..<0
        currentIndex += 1
    }

    // Now, either:
    // 1) we have a scheme and currentIndex is after the colon, or
    // 2) currentIndex == 0 and buffer[0] was non-ALPHA, or
    // 3) currentIndex > 0 and we are currently parsing a relative path.

    let hasScheme = flags.contains(.hasScheme)
    if hasScheme {
        // Note: currentIndex is after the ":"
        let schemeLength = currentIndex - 1
        switch schemeLength {
        case 2:
            if ((buffer[0] | 0x20) == UInt8(ascii: "w") &&
                (buffer[1] | 0x20) == UInt8(ascii: "s")) {
                flags.insert(.hasSpecialScheme)
            }
        case 3:
            if ((buffer[0] | 0x20) == UInt8(ascii: "w") &&
                (buffer[1] | 0x20) == UInt8(ascii: "s") &&
                (buffer[2] | 0x20) == UInt8(ascii: "s")) {
                flags.insert(.hasSpecialScheme)
            } else if ((buffer[0] | 0x20) == UInt8(ascii: "f") &&
                       (buffer[1] | 0x20) == UInt8(ascii: "t") &&
                       (buffer[2] | 0x20) == UInt8(ascii: "p")) {
                flags.insert(.hasSpecialScheme)
            }
        case 4:
            if ((buffer[0] | 0x20) == UInt8(ascii: "h") &&
                (buffer[1] | 0x20) == UInt8(ascii: "t") &&
                (buffer[2] | 0x20) == UInt8(ascii: "t") &&
                (buffer[3] | 0x20) == UInt8(ascii: "p")) {
                flags.insert(.hasSpecialScheme)
            } else if ((buffer[0] | 0x20) == UInt8(ascii: "f") &&
                       (buffer[1] | 0x20) == UInt8(ascii: "i") &&
                       (buffer[2] | 0x20) == UInt8(ascii: "l") &&
                       (buffer[3] | 0x20) == UInt8(ascii: "e")) {
                flags.insert([.isFileURL, .hasSpecialScheme])
            }
        case 5:
            if ((buffer[0] | 0x20) == UInt8(ascii: "h") &&
                (buffer[1] | 0x20) == UInt8(ascii: "t") &&
                (buffer[2] | 0x20) == UInt8(ascii: "t") &&
                (buffer[3] | 0x20) == UInt8(ascii: "p") &&
                (buffer[4] | 0x20) == UInt8(ascii: "s")) {
                flags.insert(.hasSpecialScheme)
            }
        default:
            break
        }
    }

    if currentIndex == endIndex {
        if hasScheme {
            // The string only contained a scheme, but the path always exists.
            // Note: we are not decomposable in this "scheme:" case.
            impl.pointee.pathRange = endIndex..<endIndex
            return
        }
        // We searched the whole string and did not find a scheme.
        // But, all the characters that are allowed in the scheme
        // are also allowed in a path, and we found no delimiters
        // in the scheme, so this must be a relative path.
        flags.insert([.isDecomposable, .hasOldPath])
        impl.pointee.pathRange = 0..<endIndex
        return
    }

    if !hasScheme || buffer[currentIndex] == UInt8(ascii: "/") {
        flags.insert(.isDecomposable)
    }

    let isRelativePath = (!hasScheme && currentIndex > 0)

    // MARK: Authority

    let hasAuthority = (
        !isRelativePath &&
        currentIndex + 1 < endIndex &&
        buffer[currentIndex] == UInt8(ascii: "/") &&
        buffer[currentIndex + 1] == UInt8(ascii: "/")
    )

    if hasAuthority {
        currentIndex += 2
        parseAuthority()
    }

    @inline(__always)
    func parseAuthority() {
        let authorityStart = currentIndex
        while currentIndex != endIndex {
            let v = buffer[currentIndex]
            if v == UInt8(ascii: "/") || v == UInt8(ascii: "?") || v == UInt8(ascii: "#") {
                break
            }
            currentIndex += 1
        }
        let authorityEnd = currentIndex

        if authorityStart == authorityEnd {
            // RFC 3986 host exists, but is empty.
            // Other authority components do not exist.
            flags.insert(.hasHost)
            impl.pointee.hostRange = currentIndex..<currentIndex
            return
        }

        // CFURL only considers a host to exist if authority is non-empty.
        // CFURL always considers a path to exist if there's a host.
        flags.insert([.hasHost, .hasOldNetLocation, .hasOldPath])

        // Parse the user, password, host, and port
        var hostStart = authorityStart

        // MARK: User and password

        // Note: The old CFURL parser used the first index of "@", but WHATWG
        // and other RFC 3986 parsers use the last index, so we should align
        // with those.

        // Find last index of "@"
        if let atIndex = buffer[authorityStart..<authorityEnd].lastIndex(of: T.CodeUnit(UInt8(ascii: "@"))) {
            // Found "@", so user exists
            hostStart = atIndex + 1
            if let colonIndex = buffer[authorityStart..<atIndex].lastIndex(of: T.CodeUnit(UInt8(ascii: ":"))) {
                // Found ":", so password exists
                flags.insert([.hasUser, .hasPassword])
                impl.pointee.userRange = authorityStart..<colonIndex
                impl.pointee.passwordRange = (colonIndex + 1)..<atIndex
            } else {
                // Did not find ":", so password does not exist
                flags.insert(.hasUser)
                impl.pointee.userRange = authorityStart..<atIndex
            }
        }

        // MARK: Host and port

        if hostStart == authorityEnd {
            // Empty host, no port
            impl.pointee.hostRange = hostStart..<hostStart
            return
        }

        // Find the end of the host/start of the port
        var hostEnd = hostStart

        // For an IP literal, the first index of "]" denotes the end
        if buffer[hostStart] == UInt8(ascii: "["), let endBracketIndex = buffer[(hostStart + 1)..<authorityEnd].firstIndex(of: T.CodeUnit(UInt8(ascii: "]"))) {

            hostEnd = endBracketIndex + 1
            if hostEnd == authorityEnd {
                // IP literal host, no port
                flags.insert(.isIPLiteral)
                impl.pointee.hostRange = hostStart..<hostEnd
                return
            }

            if buffer[hostEnd] == UInt8(ascii: ":") {
                // IP literal host with port
                flags.insert([.hasPort, .isIPLiteral])
                impl.pointee.hostRange = hostStart..<hostEnd
                impl.pointee.portRange = (hostEnd + 1)..<authorityEnd
                return
            }

            // There's an invalid character after "]",
            // so don't treat this as an IP literal.
            // Find the next ":" to delimit the port,
            // which is similar to how CFURL behaved.

            // Fallthrough to regular host parsing to find the port.
            hostEnd += 1
        }

        // Non-empty, regular host. Find the first index of ":"
        if let colonIndex = buffer[hostEnd..<authorityEnd].firstIndex(of: T.CodeUnit(UInt8(ascii: ":"))) {
            // Found ":", so port exists
            flags.insert(.hasPort)
            impl.pointee.hostRange = hostStart..<colonIndex
            impl.pointee.portRange = (colonIndex + 1)..<authorityEnd
            return
        }

        // Did not find ":", so port does not exist
        impl.pointee.hostRange = hostStart..<authorityEnd
        return

    } // End of parseAuthority()

    // MARK: Path

    let pathStart = isRelativePath ? 0 : currentIndex
    while currentIndex != endIndex {
        let v = buffer[currentIndex]
        if v == UInt8(ascii: "%") {
            flags.insert(.hasEncodedPath)
        } else if v == UInt8(ascii: "?") || v == UInt8(ascii: "#") {
            break
        }
        currentIndex += 1
    }
    let pathEnd = currentIndex
    let pathLength = pathEnd - pathStart

    if pathLength > 0 {
        if flags.contains(.isDecomposable) {
            flags.insert(.hasOldPath)
        }
        let isFileReferenceURL = (
            flags.contains(.isFileURL) &&
            pathLength >= 10 &&
            buffer[pathStart] == UInt8(ascii: "/") &&
            buffer[pathStart + 1] == UInt8(ascii: ".") &&
            buffer[pathStart + 2] == UInt8(ascii: "f") &&
            buffer[pathStart + 3] == UInt8(ascii: "i") &&
            buffer[pathStart + 4] == UInt8(ascii: "l") &&
            buffer[pathStart + 5] == UInt8(ascii: "e") &&
            buffer[pathStart + 6] == UInt8(ascii: "/") &&
            buffer[pathStart + 7] == UInt8(ascii: "i") &&
            buffer[pathStart + 8] == UInt8(ascii: "d") &&
            buffer[pathStart + 9] == UInt8(ascii: "=")
        )
        if isFileReferenceURL {
            flags.insert(.isFileReferenceURL)
        }
        // Could make this a tiny bit faster by branching better
        let hasDirectoryPath = (
            buffer[pathEnd - 1] == UInt8(ascii: "/")
            || (pathLength == 1 &&
                buffer[pathEnd - 1] == UInt8(ascii: "."))
            || (pathLength == 2 &&
                buffer[pathEnd - 2] == UInt8(ascii: ".") &&
                buffer[pathEnd - 1] == UInt8(ascii: "."))
            || (pathLength >= 2 &&
                buffer[pathEnd - 2] == UInt8(ascii: "/") &&
                buffer[pathEnd - 1] == UInt8(ascii: "."))
            || (pathLength >= 3 &&
                buffer[pathEnd - 3] == UInt8(ascii: "/") &&
                buffer[pathEnd - 2] == UInt8(ascii: ".") &&
                buffer[pathEnd - 1] == UInt8(ascii: "."))
        )
        if hasDirectoryPath {
            flags.insert(.hasDirectoryPath)
        }
    }

    impl.pointee.pathRange = pathStart..<pathEnd
    if pathEnd == endIndex {
        return
    }

    // MARK: Query and fragment

    if buffer[currentIndex] == UInt8(ascii: "?") {
        currentIndex += 1
        let queryStart = currentIndex
        while currentIndex != endIndex {
            if buffer[currentIndex] == UInt8(ascii: "#") {
                flags.insert([.hasQuery, .hasFragment])
                impl.pointee.queryRange = queryStart..<currentIndex
                impl.pointee.fragmentRange = (currentIndex + 1)..<endIndex
                return
            }
            currentIndex += 1
        }
        // Did not find a fragment
        flags.insert(.hasQuery)
        impl.pointee.queryRange = queryStart..<endIndex
    } else {
        assert(buffer[currentIndex] == UInt8(ascii: "#"))
        flags.insert(.hasFragment)
        impl.pointee.fragmentRange = (currentIndex + 1)..<endIndex
    }
}

// MARK: - Parsing, validation, and encoding (main entry point)

internal func parse<T: _URLEncoding, Impl: _URLParseable>(
    _ type: T.Type,
    span: borrowing Span<T.CodeUnit>,
    flags: inout __CFURLFlags,
    into impl: UnsafeMutablePointer<Impl>,
    allowEncoding: Bool,
    replacingOriginalString: Bool = false
) -> Bool {

    // MARK: Parsing

    span.withUnsafeBufferPointer { buffer in
        parse(T.self, buffer: buffer, into: impl, flags: &flags)
    }

    // MARK: Validation

    var shouldEncode = false

    // Scheme is already validated during parsing, start with user
    if flags.contains(.hasUser) && !validate(span: span.extracting(impl.pointee.userRange), component: .user) {
        guard allowEncoding else { return false }
        flags.insert(.shouldEncodeUser)
        shouldEncode = true
    }

    if flags.contains(.hasPassword) && !validate(span: span.extracting(impl.pointee.passwordRange), component: .password) {
        guard allowEncoding else { return false }
        flags.insert(.shouldEncodePassword)
        shouldEncode = true
    }

    if flags.contains(.hasHost) {
        let hostRange = impl.pointee.hostRange
        if flags.contains(.isIPLiteral) {
            // Ignore the leading and trailing brackets
            var i = hostRange.startIndex + 1
            let endBracketIndex = hostRange.endIndex - 1
            while i < endBracketIndex && URLComponentAllowedSet.hostIPvFuture.contains(span[i]) {
                i += 1
            }
            if i < endBracketIndex {
                // We found a character that's not allowed in .hostIPvFuture
                // Only a zone ID (starting at "%") can be percent-encoded
                guard span[i] == UInt8(ascii: "%") else {
                    // The IP portion contained an invalid character that was
                    // not the start of a zone ID, so return false.
                    return false
                }
                // "%25" is the correctly-encoded zone ID delimiter for a URL
                let isValidZoneID = (
                    i + 2 < endBracketIndex
                    && span[i + 1] == UInt8(ascii: "2")
                    && span[i + 2] == UInt8(ascii: "5")
                    && validate(
                        span: span.extracting((i + 3)..<endBracketIndex),
                        component: .hostZoneID
                    )
                )
                if !isValidZoneID {
                    // We have an invalid zone ID, but we can encode it
                    guard allowEncoding else { return false }
                    flags.insert(.shouldEncodeHost)
                    shouldEncode = true
                }
            }
        } else if !validate(span: span.extracting(hostRange), component: .host) {
            guard allowEncoding else { return false }
            guard span[hostRange.startIndex] != UInt8(ascii: "[") else { return false }
            flags.insert(.shouldEncodeHost)
            shouldEncode = true
        }
    }

    // Allow any valid URL character in the port for compatibility
    if flags.contains(.hasPort) && !validate(span: span.extracting(impl.pointee.portRange), component: .anyValid) {
        guard allowEncoding else { return false }
        shouldEncode = true
    }

    // Path always exists
    if !validate(span: span.extracting(impl.pointee.pathRange), component: .path) {
        guard allowEncoding else { return false }
        flags.insert(.shouldEncodePath)
        shouldEncode = true
    }

    if flags.contains(.hasQuery) && !validate(span: span.extracting(impl.pointee.queryRange), component: .query) {
        guard allowEncoding else { return false }
        flags.insert(.shouldEncodeQuery)
        shouldEncode = true
    }

    if flags.contains(.hasFragment) && !validate(span: span.extracting(impl.pointee.fragmentRange), component: .fragment) {
        guard allowEncoding else { return false }
        flags.insert(.shouldEncodeFragment)
        shouldEncode = true
    }

    // MARK: Encoding (if needed)

    if shouldEncode {
        if replacingOriginalString {
            guard let encodedString = encode(T.self, span: span, flags: &flags, updating: impl) else {
                return false
            }
            // Note: encodedString is ASCII, so utf8.count is correct.
            if encodedString.utf8.count > Impl.maxStringLength {
                // Encoded string can't fit in this implementation, we may
                // need to retry with a larger implementation struct.
                return false
            }
            impl.pointee.setOriginalString(encodedString)
        } else if let encodedString = encode(T.self, span: span, flags: flags, for: impl) {
            impl.pointee.setEncodedString(encodedString)
        }
    }
    return true
}

// MARK: - Encoding

private func encode<T: _URLEncoding, Impl: _URLParseable>(
    _ type: T.Type,
    span: borrowing Span<T.CodeUnit>,
    flags: inout __CFURLFlags,
    updating impl: UnsafeMutablePointer<Impl>
) -> String? {
    let result = encode(T.self, span: span, flags: flags, for: impl, updateRanges: true)
    flags.remove([
        .shouldEncodeUser, .shouldEncodePassword, .shouldEncodeHost,
        .shouldEncodePath, .shouldEncodeQuery, .shouldEncodeFragment
    ])
    return result
}

private func encode<T: _URLEncoding, Impl: _URLParseable>(
    _ type: T.Type,
    span: borrowing Span<T.CodeUnit>,
    flags: _URLFlags,
    for impl: UnsafeMutablePointer<Impl>
) -> String? {
    return encode(T.self, span: span, flags: flags, for: impl, updateRanges: false)
}

private func encode<T: _URLEncoding, Impl: _URLParseable>(
    _ type: T.Type,
    span: borrowing Span<T.CodeUnit>,
    flags: _URLFlags,
    for impl: UnsafeMutablePointer<Impl>,
    updateRanges: Bool
) -> String? {

    // Note: If we made it here, we are performing CFURL byte encoding.
    // CFURL percent-encoding leaves already percent-encoded characters
    // alone, e.g. "%20 %20" becomes "%20%20%20".

    // Always use UTF8 for encoding regardless of original CFString encoding.
    // Allocate UInt8 since we're guaranteed to produce an ASCII string.

    // An ASCII UInt8 buffer may need up to 3 * buffer.count to encode.
    // - 1 UTF8 byte per ASCII byte * 3 bytes to percent-encode
    // A UTF16 UniChar buffer may need up to 9 * buffer.count to encode.
    // - max 3 UTF8 bytes per UTF16 UniChar * 3 bytes to percent-encode

    // The maximum 9 * buffer.count is way overkill in the vast majority of
    // cases, since usually very few characters need encoding, or we're ASCII,
    // so start with 2 * buffer.count and re-allocate if needed.

    assert(!span.isEmpty)
    let encoded: String? = withUnsafeTemporaryAllocation(of: UInt8.self, capacity: 2 * span.count) {
        var os = OutputSpan(buffer: $0, initializedCount: 0)
        guard encode(into: &os) else { return nil }
        let outputLength = os.finalize(for: $0)
        return String(decoding: $0[..<outputLength], as: UTF8.self)
    }
    if let encoded {
        return encoded
    }
    return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: 3 * T._maxUTF8BytesPerCharacter * span.count) {
        var os = OutputSpan(buffer: $0, initializedCount: 0)
        guard encode(into: &os) else { return nil }
        let outputLength = os.finalize(for: $0)
        return String(decoding: $0[..<outputLength], as: UTF8.self)
    }

    @inline(__always)
    func encode(into outputSpan: inout OutputSpan<UInt8>) -> Bool {
        var copyStart = 0
        var copyEnd = 0
        var extraBytesAdded = 0 // Additional length added from encoding

        // Advance the copyEnd index until we reach a component that needs
        // encoding. Then, copy the current chunk from the buffer, encode
        // the new component in place, and update the indices.

        // If updatedRanges is true, we track the number of extraBytesAdded so
        // that we can update the ranges in place to account for any encoded
        // components. This is a huge performance win for NSURL and URL, which
        // only store the fully-encoded string, since it means we don't need
        // to re-parse the encoded string.

        // Returns false if there's not enough room in the output buffer.
        @inline(__always)
        func flush() -> Bool {
            // Note: copied portion is ASCII, does not update copy indices.
            guard outputSpan.freeCapacity >= copyEnd - copyStart else {
                return false
            }
            for i in copyStart..<copyEnd {
                outputSpan.append(UInt8(truncatingIfNeeded: span[unchecked: i]))
            }
            return true
        }

        // Returns false if there's not enough room in the output buffer.
        @inline(__always)
        func encode(range: Range<Int>, component: URLComponentAllowedMask) -> Bool {
            guard !range.isEmpty else { return true }
            guard flush() else { return false }
            let success = T._withUTF8(input: span.extracting(range)) { utf8Span in
                return URLEncoder.addPercentEscapes(
                    input: utf8Span,
                    output: &outputSpan,
                    component: component
                )
            }
            guard success else { return false }
            // Update the length we've added due to percent-encoding
            extraBytesAdded = outputSpan.count - range.endIndex
            // Update the indices for copying
            copyStart = range.endIndex
            copyEnd = range.endIndex
            return true
        }

        // Returns false if there's not enough room in the output buffer.
        @inline(__always)
        func idnaEncodeHost(range: Range<Int>) -> Bool {
            guard !range.isEmpty else { return true }
            guard flush() else { return false }
            guard let uidnaHook = _uidnaHook() else { return false }
            let success = T._withUTF16(input: span.extracting(range)) { utf16Span in
                return uidnaHook.nameToASCII(
                    input: utf16Span,
                    output: &outputSpan,
                )
            }
            guard success else { return false }
            // Update the length we've added due to encoding
            extraBytesAdded = outputSpan.count - range.endIndex
            // Update the indices for copying
            copyStart = range.endIndex
            copyEnd = range.endIndex
            return true
        }

        // Returns false if there's not enough room in the output buffer.
        @inline(__always)
        func encodeZoneID(range: Range<Int>) -> Bool {
            assert(!range.isEmpty)
            guard flush() else { return false }
            let success = T._withUTF8(input: span.extracting(range)) { utf8Span in
                return URLEncoder.percentEncode(
                    input: utf8Span,
                    output: &outputSpan,
                    component: .hostZoneID
                )
            }
            guard success else { return false }
            // Update the length we've added due to percent-encoding
            extraBytesAdded = outputSpan.count - range.endIndex
            // Update the indices for copying
            copyStart = range.endIndex
            copyEnd = range.endIndex
            return true
        }

        @inline(__always)
        func updateUserRange(_ start: Int, _ end: Int) {
            guard updateRanges && extraBytesAdded > 0 else { return }
            impl.pointee.userRange = start..<end
        }

        @inline(__always)
        func updatePasswordRange(_ start: Int, _ end: Int) {
            guard updateRanges && extraBytesAdded > 0 else { return }
            impl.pointee.passwordRange = start..<end
        }

        @inline(__always)
        func updateHostRange(_ start: Int, _ end: Int) {
            guard updateRanges && extraBytesAdded > 0 else { return }
            impl.pointee.hostRange = start..<end
        }

        @inline(__always)
        func updatePortRange(_ start: Int, _ end: Int) {
            guard updateRanges && extraBytesAdded > 0 else { return }
            impl.pointee.portRange = start..<end
        }

        @inline(__always)
        func updatePathRange(_ start: Int, _ end: Int) {
            guard updateRanges && extraBytesAdded > 0 else { return }
            impl.pointee.pathRange = start..<end
        }

        @inline(__always)
        func updateQueryRange(_ start: Int, _ end: Int) {
            guard updateRanges && extraBytesAdded > 0 else { return }
            impl.pointee.queryRange = start..<end
        }

        @inline(__always)
        func updateFragmentRange(_ start: Int, _ end: Int) {
            guard updateRanges && extraBytesAdded > 0 else { return }
            impl.pointee.queryRange = start..<end
        }

        if flags.contains(.hasScheme) {
            let schemeEnd = impl.pointee.schemeRange.endIndex
            copyEnd = schemeEnd + 1 // Include trailing ":"
        }

        if flags.contains(.hasHost) {
            copyEnd += 2 // Include "//" from the authority
        }

        if flags.contains(.hasUser) {
            // Note: user start will never change since scheme can't be encoded
            let userRange = impl.pointee.userRange
            if flags.contains(.shouldEncodeUser) {
                guard encode(range: userRange, component: .user) else { return false }
                updateUserRange(userRange.startIndex, userRange.endIndex + extraBytesAdded)
            } else {
                copyEnd = userRange.endIndex
            }

            if flags.contains(.hasPassword) {
                let passwordRange = impl.pointee.passwordRange
                let newPasswordStart = passwordRange.startIndex + extraBytesAdded
                if flags.contains(.shouldEncodePassword) {
                    copyEnd += 1 // Include ":" after the user
                    guard encode(range: passwordRange, component: .password) else { return false }
                } else {
                    copyEnd = passwordRange.endIndex
                }
                updatePasswordRange(newPasswordStart, passwordRange.endIndex + extraBytesAdded)
            }

            copyEnd += 1 // Include trailing "@"
        }

        if flags.contains(.hasHost) {
            let hostRange = impl.pointee.hostRange
            let newHostStart = hostRange.startIndex + extraBytesAdded
            if flags.contains(.shouldEncodeHost) {
                if flags.contains(.isIPLiteral) {
                    // We can only be encoding a zone ID, find the start
                    while copyEnd < hostRange.endIndex - 1 && span[copyEnd] != UInt8(ascii: "%") {
                        copyEnd += 1
                    }
                    guard encodeZoneID(range: copyEnd..<(hostRange.endIndex - 1)) else { return false }
                    copyEnd += 1 // Include trailing "]"
                } else if updateRanges && flags.contains(.hasSpecialScheme) && _uidnaHook() != nil {
                    // Support IDNA-encoding for NSURL (updateRanges: true)
                    guard idnaEncodeHost(range: hostRange) else { return false }
                } else {
                    // Always percent-encode for CFURL compatibility
                    guard encode(range: hostRange, component: .host) else { return false }
                }
            } else {
                copyEnd = hostRange.endIndex
            }
            updateHostRange(newHostStart, hostRange.endIndex + extraBytesAdded)
        }

        // For compatibility, append the port *string*, which may not be
        // numeric. Allow any valid URL character to appear in the string.
        if flags.contains(.hasPort) {
            copyEnd += 1 // Include leading ":"
            let portRange = impl.pointee.portRange
            let newPortStart = portRange.startIndex + extraBytesAdded
            // Always encode since we don't know if the port was valid
            guard encode(range: portRange, component: .anyValid) else { return false }
            updatePortRange(newPortStart, portRange.endIndex + extraBytesAdded)
        }

        let pathRange = impl.pointee.pathRange
        let newPathStart = pathRange.startIndex + extraBytesAdded
        if flags.contains(.shouldEncodePath) {
            guard encode(range: pathRange, component: .path) else { return false }
        } else {
            copyEnd = pathRange.endIndex
        }
        updatePathRange(newPathStart, pathRange.endIndex + extraBytesAdded)

        if flags.contains(.hasQuery) {
            copyEnd += 1 // Include leading "?"
            let queryRange = impl.pointee.queryRange
            let newQueryStart = queryRange.startIndex + extraBytesAdded
            if flags.contains(.shouldEncodeQuery) {
                guard encode(range: queryRange, component: .query) else { return false }
            } else {
                copyEnd = queryRange.endIndex
            }
            updateQueryRange(newQueryStart, queryRange.endIndex + extraBytesAdded)
        }

        if flags.contains(.hasFragment) {
            copyEnd += 1 // Include leading "#"
            let fragmentRange = impl.pointee.fragmentRange
            let newFragmentStart = fragmentRange.startIndex + extraBytesAdded
            if flags.contains(.shouldEncodeFragment) {
                guard encode(range: fragmentRange, component: .fragment) else { return false }
            } else {
                copyEnd = fragmentRange.endIndex
            }
            updateFragmentRange(newFragmentStart, fragmentRange.endIndex + extraBytesAdded)
        }

        // Copy remaining bytes from the original string
        guard flush() else { return false }
        return true
    }
}

#endif // FOUNDATION_FRAMEWORK
