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

private extension Unicode.Scalar {
  /// Returns the Boolean value that indicates whether or not `self` is "ASCII whitespace".
  ///
  /// Reference: https://infra.spec.whatwg.org/#ascii-whitespace
  var _isASCIIWhitespace: Bool {
    switch self.value {
    case 0x09, 0x0A, 0x0C, 0x0D, 0x20: true
    default: false
    }
  }
}

private extension String {
    var _trimmed: Substring.UnicodeScalarView {
        let scalars = self.unicodeScalars
        let isNonWhitespace: (Unicode.Scalar) -> Bool = { !$0._isASCIIWhitespace }
        guard let firstIndexOfNonWhitespace = scalars.firstIndex(where: isNonWhitespace),
              let lastIndexOfNonWhitespace = scalars.lastIndex(where: isNonWhitespace) else {
            return Substring.UnicodeScalarView()
        }
        return scalars[firstIndexOfNonWhitespace...lastIndexOfNonWhitespace]
    }
}

/// A type that holds a `Unicode.Scalar` where its value is compared case-insensitively with others'
/// _if the value is within ASCII range_.
private struct ASCIICaseInsensitiveUnicodeScalar: Equatable,
                                                  ExpressibleByUnicodeScalarLiteral {
    typealias UnicodeScalarLiteralType = Unicode.Scalar.UnicodeScalarLiteralType

    let scalar: Unicode.Scalar

    @inlinable
    init(_ scalar: Unicode.Scalar) {
        assert(scalar.isASCII)
        self.scalar = scalar
    }

    init(unicodeScalarLiteral value: Unicode.Scalar.UnicodeScalarLiteralType) {
        self.init(Unicode.Scalar(unicodeScalarLiteral: value))
    }

    @inlinable
    static func ==(
        lhs: ASCIICaseInsensitiveUnicodeScalar,
        rhs: ASCIICaseInsensitiveUnicodeScalar
    ) -> Bool {
        if lhs.scalar == rhs.scalar {
            return true
        } else if ("A"..."Z").contains(lhs.scalar) {
            return lhs.scalar.value + 0x20 == rhs.scalar.value
        } else if ("a"..."z").contains(lhs.scalar) {
            return lhs.scalar.value - 0x20 == rhs.scalar.value
        }
        return false
    }
}

/// A type to tokenize string for `String.Encoding` names.
private protocol StringEncodingNameTokenizer: ~Copyable {
    associatedtype Token: Equatable
    init(name: String)
    mutating func nextToken() throws -> Token?
}

extension StringEncodingNameTokenizer where Self: ~Copyable {
    mutating func hasEqualTokens(with other: consuming Self) throws -> Bool {
        while let myToken = try self.nextToken() {
            guard let otherToken = try other.nextToken(),
                  myToken == otherToken else {
                return false
            }
        }
        return try other.nextToken() == nil
    }
}


/// A parser that tokenizes a string into `ASCIICaseInsensitiveUnicodeScalar`s.
private struct ASCIICaseInsensitiveTokenizer: StringEncodingNameTokenizer, ~Copyable {
    typealias Token = ASCIICaseInsensitiveUnicodeScalar

      enum Error: Swift.Error {
          case nonASCII
      }

    let scalars: Substring.UnicodeScalarView

    var _currentIndex: Substring.UnicodeScalarView.Index

    init(name: String) {
        self.scalars = name._trimmed
        self._currentIndex = scalars.startIndex
    }

    mutating func nextToken() throws -> Token? {
        guard _currentIndex < scalars.endIndex else {
            return nil
        }
        let scalar = scalars[_currentIndex]
        guard scalar.isASCII else { throw Error.nonASCII }
        defer {
            scalars.formIndex(after: &_currentIndex)
        }
        return  ASCIICaseInsensitiveUnicodeScalar(scalar)
    }
}


private extension String {
    func isEqual<T>(
        to other: String,
        tokenizedBy tokenizer: T.Type
    ) -> Bool where T: StringEncodingNameTokenizer, T: ~Copyable {
        do {
            var myTokenizer = T(name: self)
            let otherTokenizer = T(name: other)
            return try myTokenizer.hasEqualTokens(with: otherTokenizer)
        } catch {
            // Any errors imply that `self` or `other` contains invalid characters.
            return false
        }
    }
}


// MARK: - IANA Charset Names

/// Info about IANA Charset.
private struct IANACharset {
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

    func matches<T>(
        _ string: String,
        tokenizedBy tokenizer: T.Type
    ) -> Bool where T: StringEncodingNameTokenizer, T: ~Copyable {
        if let preferredMIMEName = self.preferredMIMEName,
           preferredMIMEName.isEqual(to: string, tokenizedBy: tokenizer) {
            return true
        }
        if name.isEqual(to: string, tokenizedBy: tokenizer) {
            return true
        }
        for alias in aliases {
            if alias.isEqual(to: string, tokenizedBy: tokenizer) {
                return true
            }
        }
        return false
    }
}

// Extracted only necessary charsets from https://www.iana.org/assignments/character-sets/character-sets.xhtml
extension IANACharset {
    /// IANA Characater Set `US-ASCII`
    static let usASCII = IANACharset(
        preferredMIMEName: "US-ASCII",
        name: "US-ASCII",
        aliases: [
            "iso-ir-6",
            "ANSI_X3.4-1968",
            "ANSI_X3.4-1986",
            "ISO_646.irv:1991",
            "ISO646-US",
            "US-ASCII",
            "us",
            "IBM367",
            "cp367",
            "csASCII",
        ]
    )

    /// IANA Characater Set `ISO-8859-1`
    static let iso8859_1 = IANACharset(
        preferredMIMEName: "ISO-8859-1",
        name: "ISO_8859-1:1987",
        aliases: [
            "iso-ir-100",
            "ISO_8859-1",
            "ISO-8859-1",
            "latin1",
            "l1",
            "IBM819",
            "CP819",
            "csISOLatin1",
        ]
    )

    /// IANA Characater Set `ISO-8859-2`
    static let iso8859_2 = IANACharset(
        preferredMIMEName: "ISO-8859-2",
        name: "ISO_8859-2:1987",
        aliases: [
            "iso-ir-101",
            "ISO_8859-2",
            "ISO-8859-2",
            "latin2",
            "l2",
            "csISOLatin2",
        ]
    )

    /// IANA Characater Set `Shift_JIS`
    static let shiftJIS = IANACharset(
        preferredMIMEName: "Shift_JIS",
        name: "Shift_JIS",
        aliases: [
            "MS_Kanji",
            "csShiftJIS",
        ]
    )

    /// IANA Characater Set `EUC-JP`
    static let eucJP = IANACharset(
        preferredMIMEName: "EUC-JP",
        name: "Extended_UNIX_Code_Packed_Format_for_Japanese",
        aliases: [
            "csEUCPkdFmtJapanese",
            "EUC-JP",
        ]
    )

    /// IANA Characater Set `ISO-2022-JP`
    static let iso2022JP = IANACharset(
        preferredMIMEName: "ISO-2022-JP",
        name: "ISO-2022-JP",
        aliases: [
            "csISO2022JP",
        ]
    )

    /// IANA Characater Set `UTF-8`
    static let utf8 = IANACharset(
        preferredMIMEName: nil,
        name: "UTF-8",
        aliases: [
            "csUTF8",
        ]
    )

    /// IANA Characater Set `UTF-16BE`
    static let utf16BE = IANACharset(
        preferredMIMEName: nil,
        name: "UTF-16BE",
        aliases: [
            "csUTF16BE",
        ]
    )

    /// IANA Characater Set `UTF-16LE`
    static let utf16LE = IANACharset(
        preferredMIMEName: nil,
        name: "UTF-16LE",
        aliases: [
            "csUTF16LE",
        ]
    )

    /// IANA Characater Set `UTF-16`
    static let utf16 = IANACharset(
        preferredMIMEName: nil,
        name: "UTF-16",
        aliases: [
            "csUTF16",
        ]
    )

    /// IANA Characater Set `UTF-32`
    static let utf32 = IANACharset(
        preferredMIMEName: nil,
        name: "UTF-32",
        aliases: [
            "csUTF32",
        ]
    )

    /// IANA Characater Set `UTF-32BE`
    static let utf32BE = IANACharset(
        preferredMIMEName: nil,
        name: "UTF-32BE",
        aliases: [
            "csUTF32BE",
        ]
    )

    /// IANA Characater Set `UTF-32LE`
    static let utf32LE = IANACharset(
        preferredMIMEName: nil,
        name: "UTF-32LE",
        aliases: [
            "csUTF32LE",
        ]
    )

    /// IANA Characater Set `macintosh`
    static let macintosh = IANACharset(
        preferredMIMEName: nil,
        name: "macintosh",
        aliases: [
            "mac",
            "csMacintosh",
        ]
    )

    /// IANA Characater Set `windows-1250`
    static let windows1250 = IANACharset(
        preferredMIMEName: nil,
        name: "windows-1250",
        aliases: [
            "cswindows1250",
        ]
    )

    /// IANA Characater Set `windows-1251`
    static let windows1251 = IANACharset(
        preferredMIMEName: nil,
        name: "windows-1251",
        aliases: [
            "cswindows1251",
        ]
    )

    /// IANA Characater Set `windows-1252`
    static let windows1252 = IANACharset(
        preferredMIMEName: nil,
        name: "windows-1252",
        aliases: [
            "cswindows1252",
        ]
    )

    /// IANA Characater Set `windows-1253`
    static let windows1253 = IANACharset(
        preferredMIMEName: nil,
        name: "windows-1253",
        aliases: [
            "cswindows1253",
        ]
    )

    /// IANA Characater Set `windows-1254`
    static let windows1254 = IANACharset(
        preferredMIMEName: nil,
        name: "windows-1254",
        aliases: [
            "cswindows1254",
        ]
    )
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
    @available(FoundationPreview 6.2, *)
    public var ianaName: String? {
        return _ianaCharset?.representativeName
    }

    /// Creates an instance from the name of the IANA registry "charset".
    @available(FoundationPreview 6.2, *)
    public init?(ianaName charsetName: String) {
        func __determineEncoding() -> String.Encoding? {
            func __matches(_ charsets: IANACharset...) -> Bool {
                assert(!charsets.isEmpty)
                return charsets.contains {
                    $0.matches(
                        charsetName,
                        tokenizedBy: ASCIICaseInsensitiveTokenizer.self
                    )
                }
            }

            return if __matches(.utf8) {
                .utf8
            } else if __matches(.usASCII) {
                .ascii
            } else if __matches(.eucJP) {
                .japaneseEUC
            } else if __matches(.iso8859_1) {
                .isoLatin1
            } else if __matches(.shiftJIS) {
                .shiftJIS
            } else if __matches(.iso8859_2) {
                .isoLatin2
            } else if __matches(.utf16) {
                .utf16
            } else if __matches(.windows1251) {
                .windowsCP1251
            } else if __matches(.windows1252) {
                .windowsCP1252
            } else if __matches(.windows1253) {
                .windowsCP1253
            } else if __matches(.windows1254) {
                .windowsCP1254
            } else if __matches(.windows1250) {
                .windowsCP1250
            } else if __matches(.iso2022JP) {
                .iso2022JP
            } else if __matches(.macintosh) {
                .macOSRoman
            } else if __matches(.utf16BE) {
                .utf16BigEndian
            } else if __matches(.utf16LE) {
                .utf16LittleEndian
            } else if __matches(.utf32) {
                .utf32
            } else if __matches(.utf32BE) {
                .utf32BigEndian
            } else if __matches(.utf32LE) {
                .utf32LittleEndian
            } else {
                nil
            }
        }

        guard let encoding = __determineEncoding() else {
            return nil
        }
        self = encoding
    }
}

