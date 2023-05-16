//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK
// FIXME: one day this will be bridged from CoreFoundation and we
// should drop it here. <rdar://problem/14497260> (need support
// for CF bridging)
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public var kCFStringEncodingASCII: CFStringEncoding { return 0x0600 }
#endif // FOUNDATION_FRAMEWORK

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension String {

    public struct Encoding : RawRepresentable, Sendable, Equatable {
        public var rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }

        public static let ascii = Encoding(rawValue: 1)
        public static let nextstep = Encoding(rawValue: 2)
        public static let japaneseEUC = Encoding(rawValue: 3)
        public static let utf8 = Encoding(rawValue: 4)
        public static let isoLatin1 = Encoding(rawValue: 5)
        public static let symbol = Encoding(rawValue: 6)
        public static let nonLossyASCII = Encoding(rawValue: 7)
        public static let shiftJIS = Encoding(rawValue: 8)
        public static let isoLatin2 = Encoding(rawValue: 9)
        public static let unicode = Encoding(rawValue: 10)
        public static let windowsCP1251 = Encoding(rawValue: 11)
        public static let windowsCP1252 = Encoding(rawValue: 12)
        public static let windowsCP1253 = Encoding(rawValue: 13)
        public static let windowsCP1254 = Encoding(rawValue: 14)
        public static let windowsCP1250 = Encoding(rawValue: 15)
        public static let iso2022JP = Encoding(rawValue: 21)
        public static let macOSRoman = Encoding(rawValue: 30)
        public static let utf16 = Encoding.unicode
        public static let utf16BigEndian = Encoding(rawValue: 0x90000100)
        public static let utf16LittleEndian = Encoding(rawValue: 0x94000100)
        public static let utf32 = Encoding(rawValue: 0x8c000100)
        public static let utf32BigEndian = Encoding(rawValue: 0x98000100)
        public static let utf32LittleEndian = Encoding(rawValue: 0x9c000100)
    }

    // This is a workaround for Clang importer's ambiguous lookup issue since
    // - Swift doesn't allow typealias to nested type
    // - Swift doesn't allow typealias to builtin types like String
    // We therefore rename String.Encoding to String._Encoding for package
    // internal use so we can use `String._Encoding` to disambiguate.
    internal typealias _Encoding = Encoding

#if FOUNDATION_FRAMEWORK
    public typealias EncodingConversionOptions = NSString.EncodingConversionOptions
    public typealias EnumerationOptions = NSString.EnumerationOptions
#endif // FOUNDATION_FRAMEWORK
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension String.Encoding : Hashable {
    public var hashValue: Int {
        // Note: This is effectively the same hashValue definition that
        // RawRepresentable provides on its own. We only need to keep this to
        // ensure ABI compatibility with 5.0.
        return rawValue.hashValue
    }

    @_alwaysEmitIntoClient // Introduced in 5.1
    public func hash(into hasher: inout Hasher) {
        // Note: `hash(only:)` is only defined here because we also define
        // `hashValue`.
        //
        // In 5.0, `hash(into:)` was resolved to RawRepresentable's functionally
        // equivalent definition; we added this definition in 5.1 to make it
        // clear this `hash(into:)` isn't synthesized by the compiler.
        // (Otherwise someone may be tempted to define it, possibly breaking the
        // hash encoding and thus the ABI. RawRepresentable's definition is
        // inlinable.)
        hasher.combine(rawValue)
    }

    public static func ==(lhs: String.Encoding, rhs: String.Encoding) -> Bool {
        // Note: This is effectively the same == definition that
        // RawRepresentable provides on its own. We only need to keep this to
        // ensure ABI compatibility with 5.0.
        return lhs.rawValue == rhs.rawValue
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension String.Encoding : CustomStringConvertible {
    public var description: String {
#if FOUNDATION_FRAMEWORK
        return String.localizedName(of: self)
#else
        return "\(self)"
#endif
    }
}
