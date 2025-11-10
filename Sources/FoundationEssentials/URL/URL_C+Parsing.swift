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

extension __CFURLFlags {
    init(type: __CFURLImplType) {
        self.init(rawValue: type.rawValue)
    }
}

// MARK: - NSURL extensions for CF/NSURL creation

@objc
extension NSURL {
    static func __swiftParseSmall(_ string: Unmanaged<CFString>, into impl: UnsafeMutablePointer<__CFSmallURLImpl>, allowEncoding: Bool) -> Bool {
        var flags = __CFURLFlags(type: .small)
        let string = string.takeUnretainedValue()
        guard _withURLSpan(
            string: string,
            blockIfASCII: { parse(UTF8.self, span: $0, flags: &flags, into: impl, allowEncoding: allowEncoding) },
            blockIfUTF16: { parse(UTF16.self, span: $0, flags: &flags, into: impl, allowEncoding: allowEncoding) }
        ) else {
            return false
        }
        impl.pointee._header._flags = flags
        impl.pointee._header._string = Unmanaged<CFString>.passRetained(
            CFStringCreateCopy(kCFAllocatorDefault, string)
        )
        return true
    }

    static func __swiftParseBig(_ string: Unmanaged<CFString>, into impl: UnsafeMutablePointer<__CFBigURLImpl>, allowEncoding: Bool) -> Bool {
        var flags = __CFURLFlags(type: .big)
        let string = string.takeUnretainedValue()
        guard _withURLSpan(
            string: string,
            blockIfASCII: { parse(UTF8.self, span: $0, flags: &flags, into: impl, allowEncoding: allowEncoding) },
            blockIfUTF16: { parse(UTF16.self, span: $0, flags: &flags, into: impl, allowEncoding: allowEncoding) }
        ) else {
            return false
        }
        impl.pointee._header._flags = flags
        impl.pointee._header._string = Unmanaged<CFString>.passRetained(
            CFStringCreateCopy(kCFAllocatorDefault, string)
        )
        return true
    }

    static func __swiftParseSmallNSURL(_ string: Unmanaged<CFString>, into impl: UnsafeMutablePointer<__CFSmallURLImpl>) -> Bool {
        var flags = __CFURLFlags(type: .small)
        let string = string.takeUnretainedValue()
        guard _withURLSpan(
            string: string,
            blockIfASCII: { parse(UTF8.self, span: $0, flags: &flags, into: impl, allowEncoding: true, replacingOriginalString: true) },
            blockIfUTF16: { parse(UTF16.self, span: $0, flags: &flags, into: impl, allowEncoding: true, replacingOriginalString: true) }
        ) else {
            return false
        }
        impl.pointee._header._flags = flags
        return true
    }

    static func __swiftParseBigNSURL(_ string: Unmanaged<CFString>, into impl: UnsafeMutablePointer<__CFBigURLImpl>) -> Bool {
        var flags = __CFURLFlags(type: .big)
        let string = string.takeUnretainedValue()
        guard _withURLSpan(
            string: string,
            blockIfASCII: { parse(UTF8.self, span: $0, flags: &flags, into: impl, allowEncoding: true, replacingOriginalString: true) },
            blockIfUTF16: { parse(UTF16.self, span: $0, flags: &flags, into: impl, allowEncoding: true, replacingOriginalString: true) }
        ) else {
            return false
        }
        impl.pointee._header._flags = flags
        return true
    }
}

#endif
