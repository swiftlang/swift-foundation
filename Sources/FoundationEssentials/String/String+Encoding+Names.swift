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


// MARK: - Private extensions for parsing encoding names

private extension UTF8.CodeUnit {
    func _isASCIICaseInsensitivelyEqual(to other: UTF8.CodeUnit) -> Bool {
        return switch self {
        case other, other._uppercased, other._lowercased: true
        default: false
        }
    }
}

private extension String {
    func _isASCIICaseInsensitivelyEqual(to other: String) -> Bool {
        let (myUTF8, otherUTF8) = (self.utf8, other.utf8)
        var (myIndex, otherIndex) = (myUTF8.startIndex, otherUTF8.startIndex)
        while myIndex < myUTF8.endIndex && otherIndex < otherUTF8.endIndex {
            guard myUTF8[myIndex]._isASCIICaseInsensitivelyEqual(to: otherUTF8[otherIndex]) else {
                return false
            }

            myUTF8.formIndex(after: &myIndex)
            otherUTF8.formIndex(after: &otherIndex)
        }
        return myIndex == myUTF8.endIndex && otherIndex == otherUTF8.endIndex
    }
}


// MARK: - IANA Charset Names

/// Info about IANA Charset.
internal struct IANACharset {
    /// Preferred MIME Name
    let preferredMIMEName: String?

    /// The name of this charset
    let name: String

    /// The aliases of this charset
    let aliases: Array<String>

    var representativeName: String {
        return preferredMIMEName ?? name
    }

    init(preferredMIMEName: String?, name: String, aliases: Array<String>) {
        self.preferredMIMEName = preferredMIMEName
        self.name = name
        self.aliases = aliases
    }

    func matches(_ string: String) -> Bool {
        if let preferredMIMEName = self.preferredMIMEName,
           preferredMIMEName._isASCIICaseInsensitivelyEqual(to: string) {
            return true
        }
        if name._isASCIICaseInsensitivelyEqual(to: string) {
            return true
        }
        for alias in aliases {
            if alias._isASCIICaseInsensitivelyEqual(to: string) {
                return true
            }
        }
        return false
    }
}


// MARK: - `String.Encoding` Names

extension String.Encoding {
    private var _ianaCharset: IANACharset? {
        switch self {
        case .utf8: .utf8
        case .ascii: .usASCII
        case .japaneseEUC: .eucJP
        case .isoLatin1: .iso8859_1
        case .shiftJIS: .shiftJIS
        case .isoLatin2: .iso8859_2
        case .unicode: .utf16
        case .windowsCP1251: .windows1251
        case .windowsCP1252: .windows1252
        case .windowsCP1253: .windows1253
        case .windowsCP1254: .windows1254
        case .windowsCP1250: .windows1250
        case .iso2022JP: .iso2022JP
        case .macOSRoman: .macintosh
        case .utf16BigEndian: .utf16BE
        case .utf16LittleEndian: .utf16LE
        case .utf32: .utf32
        case .utf32BigEndian: .utf32BE
        case .utf32LittleEndian: .utf32LE
        default: nil
        }
    }

    /// The name of this encoding that is compatible with the one of the IANA registry "charset".
    @available(FoundationPreview 6.3, *)
    public var ianaName: String? {
        return _ianaCharset?.representativeName
    }

    /// Creates an instance from the name of the IANA registry "charset".
    ///
    /// - Note: The given name is compared to each IANA "charset" name
    ///         with ASCII case-insensitive collation
    ///         to determine which encoding is suitable.
    @available(FoundationPreview 6.3, *)
    public init?(ianaName charsetName: String) {
        let possibilities: [String.Encoding] = [
            .utf8,
            .ascii,
            .japaneseEUC,
            .isoLatin1,
            .shiftJIS,
            .isoLatin2,
            .unicode, // .utf16
            .windowsCP1251,
            .windowsCP1252,
            .windowsCP1253,
            .windowsCP1254,
            .windowsCP1250,
            .iso2022JP,
            .macOSRoman,
            .utf16BigEndian,
            .utf16LittleEndian,
            .utf32,
            .utf32BigEndian,
            .utf32LittleEndian,
        ]

        func __determineEncoding() -> String.Encoding? {
            for encoding in possibilities {
                guard let ianaCharset = encoding._ianaCharset else {
                    continue
                }
                if ianaCharset.matches(charsetName) {
                    return encoding
                }
            }
            return nil
        }

        guard let encoding = __determineEncoding() else {
            return nil
        }
        self = encoding
    }
}

