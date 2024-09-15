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
#if FOUNDATION_FRAMEWORK && !NO_LOCALIZATION
        return String.localizedName(of: self)
#else
        // swift-corelibs-foundation never returned an actually localized name here, but there does exist some test code which depends on these values.
        switch self {
            case .ascii: return "Western (ASCII)"
            case .nextstep: return "Western (NextStep)"
            case .japaneseEUC: return "Japanese (EUC)"
            case .utf8: return "Unicode (UTF-8)"
            case .isoLatin1: return "Western (ISO Latin 1)"
            case .symbol: return "Symbol (Mac OS)"
            case .nonLossyASCII: return "Non-lossy ASCII"
            case .shiftJIS: return "Japanese (Windows, DOS)"
            case .isoLatin2: return "Central European (ISO Latin 2)"
            case .unicode: return "Unicode (UTF-16)"
            case .windowsCP1251: return "Cyrillic (Windows)"
            case .windowsCP1252: return "Western (Windows Latin 1)"
            case .windowsCP1253: return "Greek (Windows)"
            case .windowsCP1254: return "Turkish (Windows Latin 5)"
            case .windowsCP1250: return "Central European (Windows Latin 2)"
            case .iso2022JP: return "Japanese (ISO 2022-JP)"
            case .macOSRoman: return "Western (Mac OS Roman)"
            case .utf16: return "Unicode (UTF-16)"
            case .utf16BigEndian: return "Unicode (UTF-16BE)"
            case .utf16LittleEndian: return "Unicode (UTF-16LE)"
            case .utf32: return "Unicode (UTF-32)"
            case .utf32BigEndian: return "Unicode (UTF-32BE)"
            case .utf32LittleEndian: return "Unicode (UTF-32LE)"
            default: return "\(self.rawValue)"
        }
#endif
    }
}

// Additional encodings that derive from `CFStringEncodings`.
extension String.Encoding {
    public static let dosJapanese = String.Encoding.shiftJIS
    public static let windowsCyrillic = String.Encoding.windowsCP1251
    public static let windowsLatin1 = String.Encoding.windowsCP1252
    public static let windowsGreek = String.Encoding.windowsCP1253
    public static let windowsLatin5 = String.Encoding.windowsCP1254
    public static let windowsLatin2 = String.Encoding.windowsCP1250
    public static let macOSJapanese = String.Encoding(rawValue: 0x80000001)
    public static let macOSChineseTrad = String.Encoding(rawValue: 0x80000002)
    public static let macOSKorean = String.Encoding(rawValue: 0x80000003)
    public static let macOSArabic = String.Encoding(rawValue: 0x80000004)
    public static let macOSHebrew = String.Encoding(rawValue: 0x80000005)
    public static let macOSGreek = String.Encoding(rawValue: 0x80000006)
    public static let macOSCyrillic = String.Encoding(rawValue: 0x80000007)
    public static let macOSDevanagari = String.Encoding(rawValue: 0x80000009)
    public static let macOSGurmukhi = String.Encoding(rawValue: 0x8000000a)
    public static let macOSGujarati = String.Encoding(rawValue: 0x8000000b)
    public static let macOSOriya = String.Encoding(rawValue: 0x8000000c)
    public static let macOSBengali = String.Encoding(rawValue: 0x8000000d)
    public static let macOSTamil = String.Encoding(rawValue: 0x8000000e)
    public static let macOSTelugu = String.Encoding(rawValue: 0x8000000f)
    public static let macOSKannada = String.Encoding(rawValue: 0x80000010)
    public static let macOSMalayalam = String.Encoding(rawValue: 0x80000011)
    public static let macOSSinhalese = String.Encoding(rawValue: 0x80000012)
    public static let macOSBurmese = String.Encoding(rawValue: 0x80000013)
    public static let macOSKhmer = String.Encoding(rawValue: 0x80000014)
    public static let macOSThai = String.Encoding(rawValue: 0x80000015)
    public static let macOSLaotian = String.Encoding(rawValue: 0x80000016)
    public static let macOSGeorgian = String.Encoding(rawValue: 0x80000017)
    public static let macOSArmenian = String.Encoding(rawValue: 0x80000018)
    public static let macOSChineseSimp = String.Encoding(rawValue: 0x80000019)
    public static let macOSTibetan = String.Encoding(rawValue: 0x8000001a)
    public static let macOSMongolian = String.Encoding(rawValue: 0x8000001b)
    public static let macOSEthiopic = String.Encoding(rawValue: 0x8000001c)
    public static let macOSCentralEurRoman = String.Encoding(rawValue: 0x8000001d)
    public static let macOSVietnamese = String.Encoding(rawValue: 0x8000001e)
    public static let macOSExtArabic = String.Encoding(rawValue: 0x8000001f)
    public static let macOSDingbats = String.Encoding(rawValue: 0x80000022)
    public static let macOSTurkish = String.Encoding(rawValue: 0x80000023)
    public static let macOSCroatian = String.Encoding(rawValue: 0x80000024)
    public static let macOSIcelandic = String.Encoding(rawValue: 0x80000025)
    public static let macOSRomanian = String.Encoding(rawValue: 0x80000026)
    public static let macOSCeltic = String.Encoding(rawValue: 0x80000027)
    public static let macOSGaelic = String.Encoding(rawValue: 0x80000028)
    public static let macOSFarsi = String.Encoding(rawValue: 0x8000008c)
    public static let macOSUkrainian = String.Encoding(rawValue: 0x80000098)
    public static let macOSInuit = String.Encoding(rawValue: 0x800000ec)
    public static let macOSVT100 = String.Encoding(rawValue: 0x800000fc)
    public static let macOSHFS = String.Encoding(rawValue: 0x800000ff)
    public static let isoLatin3 = String.Encoding(rawValue: 0x80000203)
    public static let isoLatin4 = String.Encoding(rawValue: 0x80000204)
    public static let isoLatinCyrillic = String.Encoding(rawValue: 0x80000205)
    public static let isoLatinArabic = String.Encoding(rawValue: 0x80000206)
    public static let isoLatinGreek = String.Encoding(rawValue: 0x80000207)
    public static let isoLatinHebrew = String.Encoding(rawValue: 0x80000208)
    public static let isoLatin5 = String.Encoding(rawValue: 0x80000209)
    public static let isoLatin6 = String.Encoding(rawValue: 0x8000020a)
    public static let isoLatinThai = String.Encoding(rawValue: 0x8000020b)
    public static let isoLatin7 = String.Encoding(rawValue: 0x8000020d)
    public static let isoLatin8 = String.Encoding(rawValue: 0x8000020e)
    public static let isoLatin9 = String.Encoding(rawValue: 0x8000020f)
    public static let isoLatin10 = String.Encoding(rawValue: 0x80000210)
    public static let dosLatinUS = String.Encoding(rawValue: 0x80000400)
    public static let dosGreek = String.Encoding(rawValue: 0x80000405)
    public static let dosBalticRim = String.Encoding(rawValue: 0x80000406)
    public static let dosLatin1 = String.Encoding(rawValue: 0x80000410)
    public static let dosGreek1 = String.Encoding(rawValue: 0x80000411)
    public static let dosLatin2 = String.Encoding(rawValue: 0x80000412)
    public static let dosCyrillic = String.Encoding(rawValue: 0x80000413)
    public static let dosTurkish = String.Encoding(rawValue: 0x80000414)
    public static let dosPortuguese = String.Encoding(rawValue: 0x80000415)
    public static let dosIcelandic = String.Encoding(rawValue: 0x80000416)
    public static let dosHebrew = String.Encoding(rawValue: 0x80000417)
    public static let dosCanadianFrench = String.Encoding(rawValue: 0x80000418)
    public static let dosArabic = String.Encoding(rawValue: 0x80000419)
    public static let dosNordic = String.Encoding(rawValue: 0x8000041a)
    public static let dosRussian = String.Encoding(rawValue: 0x8000041b)
    public static let dosGreek2 = String.Encoding(rawValue: 0x8000041c)
    public static let dosThai = String.Encoding(rawValue: 0x8000041d)
    public static let dosSimplifiedChinese = String.Encoding(rawValue: 0x80000421)
    public static let dosKorean = String.Encoding(rawValue: 0x80000422)
    public static let dosTraditionalChinese = String.Encoding(rawValue: 0x80000423)
    public static let windowsCP1255 = String.Encoding(rawValue: 0x80000505)
    public static let windowsHebrew = String.Encoding.windowsCP1255
    public static let windowsCP1256 = String.Encoding(rawValue: 0x80000506)
    public static let windowsArabic = String.Encoding.windowsCP1256
    public static let windowsCP1257 = String.Encoding(rawValue: 0x80000507)
    public static let windowsBalticRim = String.Encoding.windowsCP1257
    public static let windowsCP1258 = String.Encoding(rawValue: 0x80000508)
    public static let windowsVietnamese = String.Encoding.windowsCP1258
    public static let windowsCP1361 = String.Encoding(rawValue: 0x80000510)
    public static let windowsKoreanJohab = String.Encoding.windowsCP1361
    public static let ansel = String.Encoding(rawValue: 0x80000601)
    public static let jisX0201_76 = String.Encoding(rawValue: 0x80000620)
    public static let jisX0208_83 = String.Encoding(rawValue: 0x80000621)
    public static let jisX0208_90 = String.Encoding(rawValue: 0x80000622)
    public static let jisX0212_90 = String.Encoding(rawValue: 0x80000623)
    public static let jisC6226_78 = String.Encoding(rawValue: 0x80000624)
    public static let shiftJISX0213 = String.Encoding(rawValue: 0x80000628)
    public static let shiftJISX0213_00 = String.Encoding.shiftJISX0213
    public static let shiftJISX0213MenKuTen = String.Encoding(rawValue: 0x80000629)
    public static let gb2312_80 = String.Encoding(rawValue: 0x80000630)
    public static let gbk95 = String.Encoding(rawValue: 0x80000631)
    public static let gb18030_2000 = String.Encoding(rawValue: 0x80000632)
    public static let ksc5601_87 = String.Encoding(rawValue: 0x80000640)
    public static let ksc5601_92Johab = String.Encoding(rawValue: 0x80000641)
    public static let cns11643_92P1 = String.Encoding(rawValue: 0x80000651)
    public static let cns11643_92P2 = String.Encoding(rawValue: 0x80000652)
    public static let cns11643_92P3 = String.Encoding(rawValue: 0x80000653)
    public static let iso2022JP2 = String.Encoding(rawValue: 0x80000821)
    public static let iso2022JP1 = String.Encoding(rawValue: 0x80000822)
    public static let iso2022JP3 = String.Encoding(rawValue: 0x80000823)
    public static let iso2022CN = String.Encoding(rawValue: 0x80000830)
    public static let iso2022CN_EXT = String.Encoding(rawValue: 0x80000831)
    public static let iso2022KR = String.Encoding(rawValue: 0x80000840)
    public static let simplifiedChineseEUC = String.Encoding(rawValue: 0x80000930)
    public static let traditionalChineseEUC = String.Encoding(rawValue: 0x80000931)
    public static let koreanEUC = String.Encoding(rawValue: 0x80000940)
    public static let plainShiftJIS = String.Encoding(rawValue: 0x80000a01)
    public static let koi8R = String.Encoding(rawValue: 0x80000a02)
    public static let big5 = String.Encoding(rawValue: 0x80000a03)
    public static let macOSRomanLatin1 = String.Encoding(rawValue: 0x80000a04)
    public static let hzGB2312 = String.Encoding(rawValue: 0x80000a05)
    public static let big5HKSCS1999 = String.Encoding(rawValue: 0x80000a06)
    public static let viscii = String.Encoding(rawValue: 0x80000a07)
    public static let koi8U = String.Encoding(rawValue: 0x80000a08)
    public static let big5E = String.Encoding(rawValue: 0x80000a09)
    public static let utf7IMAP = String.Encoding(rawValue: 0x80000a10)
    public static let nextstepJapanese = String.Encoding(rawValue: 0x80000b02)
    public static let ebcdicUS = String.Encoding(rawValue: 0x80000c01)
    public static let ebcdicCP037 = String.Encoding(rawValue: 0x80000c02)
    public static let utf7 = String.Encoding(rawValue: 0x84000100)
}

extension String.Encoding {
    /// Returns the name of the IANA registry "charset" that is the closest mapping to this
    /// string encoding.
    public var ianaCharacterSetName: String? {
        switch self {
        case .ascii: return "us-ascii"
        case .nextstep: return "x-nextstep"
        case .japaneseEUC: return "euc-jp"
        case .utf8: return "utf-8"
        case .isoLatin1: return "iso-8859-1"
        case .symbol: return "x-mac-symbol"
        case .shiftJIS: return "cp932"
        case .isoLatin2: return "iso-8859-2"
        case .unicode: return "utf-16"
        case .windowsCP1251: return "windows-1251"
        case .windowsCP1252: return "windows-1252"
        case .windowsCP1253: return "windows-1253"
        case .windowsCP1254: return "windows-1254"
        case .windowsCP1250: return "windows-1250"
        case .iso2022JP: return "iso-2022-jp"
        case .macOSRoman: return "macintosh"
        case .macOSJapanese: return "x-mac-japanese"
        case .macOSChineseTrad: return "x-mac-trad-chinese"
        case .macOSKorean: return "x-mac-korean"
        case .macOSArabic: return "x-mac-arabic"
        case .macOSHebrew: return "x-mac-hebrew"
        case .macOSGreek: return "x-mac-greek"
        case .macOSCyrillic: return "x-mac-cyrillic"
        case .macOSDevanagari: return "x-mac-devanagari"
        case .macOSGurmukhi: return "x-mac-gurmukhi"
        case .macOSGujarati: return "x-mac-gujarati"
        case .macOSOriya: return "x-mac-oriya"
        case .macOSBengali: return "x-mac-bengali"
        case .macOSTamil: return "x-mac-tamil"
        case .macOSTelugu: return "x-mac-telugu"
        case .macOSKannada: return "x-mac-kannada"
        case .macOSMalayalam: return "x-mac-malayalam"
        case .macOSSinhalese: return "x-mac-sinhalese"
        case .macOSBurmese: return "x-mac-burmese"
        case .macOSKhmer: return "x-mac-khmer"
        case .macOSThai: return "x-mac-thai"
        case .macOSLaotian: return "x-mac-laotian"
        case .macOSGeorgian: return "x-mac-georgian"
        case .macOSArmenian: return "x-mac-armenian"
        case .macOSChineseSimp: return "x-mac-simp-chinese"
        case .macOSTibetan: return "x-mac-tibetan"
        case .macOSMongolian: return "x-mac-mongolian"
        case .macOSEthiopic: return "x-mac-ethiopic"
        case .macOSCentralEurRoman: return "x-mac-centraleurroman"
        case .macOSVietnamese: return "x-mac-vietnamese"
        case .macOSExtArabic: return "X-MAC-EXTARABIC"
        case .macOSDingbats: return "x-mac-dingbats"
        case .macOSTurkish: return "x-mac-turkish"
        case .macOSCroatian: return "x-mac-croatian"
        case .macOSIcelandic: return "x-mac-icelandic"
        case .macOSRomanian: return "x-mac-romanian"
        case .macOSCeltic: return "x-mac-celtic"
        case .macOSGaelic: return "x-mac-gaelic"
        case .macOSFarsi: return "x-mac-farsi"
        case .macOSUkrainian: return "x-mac-ukrainian"
        case .macOSInuit: return "x-mac-inuit"
        case .macOSHFS: return "macintosh"
        case .isoLatin3: return "iso-8859-3"
        case .isoLatin4: return "iso-8859-4"
        case .isoLatinCyrillic: return "iso-8859-5"
        case .isoLatinArabic: return "iso-8859-6"
        case .isoLatinGreek: return "iso-8859-7"
        case .isoLatinHebrew: return "iso-8859-8"
        case .isoLatin5: return "iso-8859-9"
        case .isoLatin6: return "iso-8859-10"
        case .isoLatinThai: return "iso-8859-11"
        case .isoLatin7: return "iso-8859-13"
        case .isoLatin8: return "iso-8859-14"
        case .isoLatin9: return "iso-8859-15"
        case .isoLatin10: return "iso-8859-16"
        case .dosLatinUS: return "cp437"
        case .dosGreek: return "cp737"
        case .dosBalticRim: return "cp775"
        case .dosLatin1: return "cp850"
        case .dosGreek1: return "cp851"
        case .dosLatin2: return "cp852"
        case .dosCyrillic: return "cp855"
        case .dosTurkish: return "cp857"
        case .dosPortuguese: return "cp860"
        case .dosIcelandic: return "cp861"
        case .dosHebrew: return "cp862"
        case .dosCanadianFrench: return "cp863"
        case .dosArabic: return "cp864"
        case .dosNordic: return "cp865"
        case .dosRussian: return "cp866"
        case .dosGreek2: return "cp869"
        case .dosThai: return "cp874"
        case .dosSimplifiedChinese: return "cp936"
        case .dosKorean: return "cp949"
        case .dosTraditionalChinese: return "cp950"
        case .windowsCP1255: return "windows-1255"
        case .windowsCP1256: return "windows-1256"
        case .windowsCP1257: return "windows-1257"
        case .windowsCP1258: return "windows-1258"
        case .windowsCP1361: return "windows-1361"
        case .jisX0201_76: return "JIS_X0201"
        case .jisX0208_90: return "JIS_X0208-1983"
        case .jisX0212_90: return "JIS_X0212-1990"
        case .jisC6226_78: return "JIS_C6226-1978"
        case .shiftJISX0213: return "Shift_JIS"
        case .gb2312_80: return "GB_2312-80"
        case .gbk95: return "GBK"
        case .gb18030_2000: return "gb18030"
        case .ksc5601_87: return "KS_C_5601-1987"
        case .iso2022JP2: return "iso-2022-jp-2"
        case .iso2022JP1: return "iso-2022-jp-1"
        case .iso2022JP3: return "iso-2022-jp-3"
        case .iso2022CN: return "iso-2022-cn"
        case .iso2022CN_EXT: return "iso-2022-cn-ext"
        case .iso2022KR: return "iso-2022-kr"
        case .simplifiedChineseEUC: return "gb2312"
        case .traditionalChineseEUC: return "euc-tw"
        case .koreanEUC: return "euc-kr"
        case .plainShiftJIS: return "shift_jis"
        case .koi8R: return "koi8-r"
        case .big5: return "big5"
        case .macOSRomanLatin1: return "x-mac-roman-latin1"
        case .hzGB2312: return "hz-gb-2312"
        case .big5HKSCS1999: return "big5-hkscs"
        case .viscii: return "viscii"
        case .koi8U: return "koi8-u"
        case .utf7IMAP: return "utf7-imap"
        case .ebcdicCP037: return "ibm037"
        case .utf7: return "utf-7"
        case .utf32: return "utf-32"
        case .utf16BigEndian: return "utf-16be"
        case .utf16LittleEndian: return "utf-16le"
        case .utf32BigEndian: return "utf-32be"
        case .utf32LittleEndian: return "utf-32le"
        default: return nil
        }
    }
}
