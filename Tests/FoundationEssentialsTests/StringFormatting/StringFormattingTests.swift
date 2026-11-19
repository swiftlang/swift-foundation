//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing

#if canImport(TestSupport)
import TestSupport
#endif

#if canImport(FoundationEssentials)
@testable import FoundationEssentials
#else
@testable import Foundation
#endif

#if FOUNDATION_FRAMEWORK
private final class ContextEvaluatingObject: NSObject {
    @objc func _dynamicContextEvaluation(_ actualString: NSString, patternString: NSString) -> NSString {
        "ctx[\(actualString)|\(patternString)]" as NSString
    }
}
#endif

private func checkFormat(_ format: String, _ arguments: any CVarArg..., locale: String? = nil, expectation: String, sourceLocation: SourceLocation = #_sourceLocation) {
    withVaList(arguments) {
        let result = String(_format: format, pluralizationNumber: nil, locale: locale.map(Locale.init(identifier:)), args: $0)
        #expect(result == expectation, sourceLocation: sourceLocation)
    }
}

@Suite("String Formatting")
struct StringFormattingTests {
    @Test func literals() {
        checkFormat("", expectation: "")
        checkFormat("abc", expectation: "abc")
        checkFormat("%%", expectation: "%")
        checkFormat("100%%", expectation: "100%")
        checkFormat("a%%b%%c", expectation: "a%b%c")
        checkFormat("%5%", expectation: "5%")
        checkFormat("%k", expectation: "k")
        checkFormat("abc%", expectation: "abc")
        checkFormat("x%ly", expectation: "xly")
    }

    @Test func integers() {
        for format in ["%hhd", "%hhi"] {
            checkFormat(format, Int8(0), expectation: "0")
            checkFormat(format, Int8(42), expectation: "42")
            checkFormat(format, Int8(-42), expectation: "-42")
            checkFormat(format, Int8.max, expectation: Int8.max.description)
            checkFormat(format, Int8.min, expectation: Int8.min.description)
        }
        for format in ["%hd", "%hi"] {
            checkFormat(format, Int16(0), expectation: "0")
            checkFormat(format, Int16(42), expectation: "42")
            checkFormat(format, Int16(-42), expectation: "-42")
            checkFormat(format, Int16.max, expectation: Int16.max.description)
            checkFormat(format, Int16.min, expectation: Int16.min.description)
        }
        for format in ["%d", "%i"] {
            checkFormat(format, Int32(0), expectation: "0")
            checkFormat(format, Int32(42), expectation: "42")
            checkFormat(format, Int32(-42), expectation: "-42")
            checkFormat(format, Int32.max, expectation: Int32.max.description)
            checkFormat(format, Int32.min, expectation: Int32.min.description)
        }
        for format in ["%ld", "%li"] {
            checkFormat(format, Int(0), expectation: "0")
            checkFormat(format, Int(42), expectation: "42")
            checkFormat(format, Int(-42), expectation: "-42")
            checkFormat(format, Int.max, expectation: Int.max.description)
            checkFormat(format, Int.min, expectation: Int.min.description)
        }
        for format in ["%lld", "%lli"] {
            checkFormat(format, Int64(0), expectation: "0")
            checkFormat(format, Int64(42), expectation: "42")
            checkFormat(format, Int64(-42), expectation: "-42")
            checkFormat(format, Int64.max, expectation: Int64.max.description)
            checkFormat(format, Int64.min, expectation: Int64.min.description)
        }
        checkFormat("%zd", Int(-3), expectation: "-3")

        checkFormat("%hhu", UInt8(0), expectation: "0")
        checkFormat("%hhu", UInt8(42), expectation: "42")
        checkFormat("%hhu", UInt8.max, expectation: UInt8.max.description)
        checkFormat("%hu", UInt16(0), expectation: "0")
        checkFormat("%hu", UInt16(42), expectation: "42")
        checkFormat("%hu", UInt16.max, expectation: UInt16.max.description)
        checkFormat("%u", UInt32(0), expectation: "0")
        checkFormat("%u", UInt32(42), expectation: "42")
        checkFormat("%u", UInt32.max, expectation: UInt32.max.description)
        checkFormat("%lu", UInt(0), expectation: "0")
        checkFormat("%lu", UInt(42), expectation: "42")
        checkFormat("%lu", UInt.max, expectation: UInt.max.description)
        checkFormat("%llu", UInt64(0), expectation: "0")
        checkFormat("%llu", UInt64(42), expectation: "42")
        checkFormat("%llu", UInt64.max, expectation: UInt64.max.description)
        checkFormat("%zu", UInt32(3), expectation: "3")

        checkFormat("%x", Int32(255), expectation: "ff")
        checkFormat("%X", Int32(255), expectation: "FF")
        checkFormat("%#x", Int32(255), expectation: "0xff")
        checkFormat("%#X", Int32(255), expectation: "0XFF")
        checkFormat("%#x", Int32(0), expectation: "0")
        checkFormat("%#X", Int32(0), expectation: "0")
        checkFormat("%x", Int32(-1), expectation: "ffffffff")
        checkFormat("%lx", -1, expectation: "ffffffffffffffff")

        checkFormat("%o", Int32(8), expectation: "10")
        checkFormat("%#o", Int32(8), expectation: "010")
    }

    @Test func flagsWidthAndPrecision() {
        checkFormat("%5d", Int32(42), expectation: "   42")
        checkFormat("%-5d", Int32(42), expectation: "42   ")
        checkFormat("%05d", Int32(42), expectation: "00042")
        checkFormat("%05d", Int32(-42), expectation: "-0042")
        checkFormat("%+d", Int32(42), expectation: "+42")
        checkFormat("% d", Int32(42), expectation: " 42")
        checkFormat("%+ d", Int32(42), expectation: "+42")
        checkFormat("%-05d", Int32(42), expectation: "42   ")
        checkFormat("%.3d", Int32(7), expectation: "007")
        checkFormat("%8.3d", Int32(7), expectation: "     007")
        checkFormat("%-8.3d", Int32(-7), expectation: "-007    ")
        checkFormat("%.0d", Int32(0), expectation: "")
        checkFormat("%08.3d", Int32(7), expectation: "     007")
        checkFormat("%#08x", Int32(255), expectation: "0x0000ff")
        checkFormat("%*d", Int32(5), Int32(42), expectation: "   42")
        checkFormat("%-*d", Int32(5), Int32(42), expectation: "42   ")
        checkFormat("%*d", Int32(-5), Int32(42), expectation: "42   ")
        checkFormat("%.*d", Int32(3), Int32(7), expectation: "007")
        checkFormat("%.*d", Int32(-1), Int32(7), expectation: "7")
        checkFormat("%*.*d", Int32(6), Int32(3), Int32(7), expectation: "   007")
    }

    @Test func positionalArguments() {
        checkFormat("%2$d %1$d", Int32(1), Int32(2), expectation: "2 1")
        checkFormat("%1$d %1$d", Int32(5), expectation: "5 5")
        checkFormat("%2$@ %1$d", Int32(1), CVarArgString("x"), expectation: "x 1")
        checkFormat("%1$*2$d", Int32(42), Int32(6), expectation: "    42")
        checkFormat("%3$.*2$f %1$d", Int32(9), Int32(2), 3.14159, expectation: "3.14 9")
        checkFormat("%1$@ %@", CVarArgString("a"), CVarArgString("b"), expectation: "a a")
    }

    @Test func floatingPoint() {
        checkFormat("%f", 3.14159, expectation: "3.141590")
        checkFormat("%f", 0.0, expectation: "0.000000")
        checkFormat("%f", -0.0, expectation: "-0.000000")
        checkFormat("%.2f", 2.675, expectation: "2.67")
        checkFormat("%.0f", 2.5, expectation: "2")
        checkFormat("%.0f", 3.5, expectation: "4")
        checkFormat("%#.0f", 2.0, expectation: "2.")
        checkFormat("%10.3f", 3.14159, expectation: "     3.142")
        checkFormat("%-10.3f", 3.14159, expectation: "3.142     ")
        checkFormat("%010.3f", -3.14159, expectation: "-00003.142")
        checkFormat("%+f", 2.5, expectation: "+2.500000")
        checkFormat("% f", 2.5, expectation: " 2.500000")
        checkFormat("%F", 1.5, expectation: "1.500000")
        checkFormat("%.20f", 0.1, expectation: "0.10000000000000000555")
        checkFormat("%f", 1e20, expectation: "100000000000000000000.000000")
        checkFormat("%e", 12345.678, expectation: "1.234568e+04")
        checkFormat("%E", 12345.678, expectation: "1.234568E+04")
        checkFormat("%.2e", 0.000123, expectation: "1.23e-04")
        checkFormat("%e", 0.0, expectation: "0.000000e+00")
        checkFormat("%g", 0.0001, expectation: "0.0001")
        checkFormat("%g", 0.00001, expectation: "1e-05")
        checkFormat("%g", 123456.0, expectation: "123456")
        checkFormat("%g", 1234567.0, expectation: "1.23457e+06")
        checkFormat("%G", 1e-10, expectation: "1E-10")
        checkFormat("%#g", 1.0, expectation: "1.00000")
        checkFormat("%.3g", 3.14159, expectation: "3.14")
        checkFormat("%a", 1.0, expectation: "0x1p+0")
        checkFormat("%A", -0.75, expectation: "-0X1.8P-1")
        checkFormat("%.2a", 1.0 / 3.0, expectation: "0x1.55p-2")
        checkFormat("%f", Double.nan, expectation: "nan")
        checkFormat("%F", Double.nan, expectation: "NAN")
        checkFormat("%f", Double.infinity, expectation: "inf")
        checkFormat("%e", -Double.infinity, expectation: "-inf")
        checkFormat("%+f", Double.infinity, expectation: "+inf")
        checkFormat("%5f", Double.nan, expectation: "  nan")
    }

    @Test func characters() {
        checkFormat("%c", Int32(65), expectation: "A")
        checkFormat("%c", Int32(233), expectation: "é")
        checkFormat("%c%c", Int32(0xC3), Int32(0xA9), expectation: "Ã©")
        checkFormat("%3c", Int32(65), expectation: "  A")
        checkFormat("%c", Int32(0), expectation: "\0")
        checkFormat("%lc", Int32(0x5D0), expectation: "")
        checkFormat("%C", Int32(0x5D0), expectation: "א")
        checkFormat("%C%C", Int32(0xD83D), Int32(0xDE00), expectation: "😀")
        checkFormat("%C", Int32(0x1F600), expectation: "\u{F600}")
    }

    @Test func objects() {
        checkFormat("%@", CVarArgString("hello"), expectation: "hello")
        checkFormat("%@", CVarArgString(""), expectation: "")
        checkFormat("%@", CVarArgString("日本語"), expectation: "日本語")
        #if FOUNDATION_FRAMEWORK
        checkFormat("%@", NSNumber(value: 42), expectation: "42")
        checkFormat("%@", NSNumber(value: 1.5), expectation: "1.5")
        checkFormat("[%@, %@]", CVarArgString("a"), NSNumber(value: 1), expectation: "[a, 1]")
        #endif
        checkFormat("%10@", CVarArgString("abc"), expectation: "abc")
        checkFormat("%-10@", CVarArgString("abc"), expectation: "abc")
        checkFormat("%.2@", CVarArgString("abcdef"), expectation: "abcdef")
        checkFormat("%@%%", CVarArgString("100"), expectation: "100%")
    }

    @Test func cStrings() {
        "hello".withCString { string in
            checkFormat("%s", string, expectation: "hello")
            checkFormat("%.3s", string, expectation: "hel")
            checkFormat("%10s|", string, expectation: "     hello|")
            checkFormat("%-10s", string, expectation: "hello     ")
        }

        withTemporaryAllocation(of: UInt8.self, capacity: 10) { buffer in
            buffer._append(copying: "ABCDEFGHIJ".utf8.span)

            buffer.span.withUnsafeBufferPointer {
                // It is valid for the c string to be non-null terminated when an explicit precision is specified
                checkFormat("%.10s", $0.baseAddress!, expectation: "ABCDEFGHIJ")
            }
        }
    }

    @Test(.enabled(if: String.Encoding.system == .macOSRoman))
    func cStringsUseTheSystemEncoding() {
        "héllo".withCString { string in
            checkFormat("%s", string, expectation: "h√©llo")
        }
    }

    @Test func unicharStrings() {
        let characters = Array("héllo".utf16) + [0]
        characters.withUnsafeBufferPointer { buffer in
            checkFormat("%S", buffer.baseAddress!, expectation: "héllo")
            checkFormat("%.2S", buffer.baseAddress!, expectation: "hé")
        }

        withTemporaryAllocation(of: UInt16.self, capacity: 3) { buffer in
            buffer.append(UInt16(UInt8(ascii: "A")))
            buffer.append(UInt16(UInt8(ascii: "B")))
            buffer.append(UInt16(UInt8(ascii: "C")))

            buffer.span.withUnsafeBufferPointer {
                // It is valid for the unichar string to be non-null terminated when an explicit precision is specified
                checkFormat("%.3S", $0.baseAddress!, expectation: "ABC")
            }
        }
    }

    @Test func pointers() {
        let pointer = OpaquePointer(bitPattern: 0x1234)!
        checkFormat("%p", pointer, expectation: "0x1234")
        checkFormat("%10p", pointer, expectation: "    0x1234")
    }

    #if FOUNDATION_FRAMEWORK
    @Test func contextEvaluation() {
        checkFormat("Hello %@!", ContextEvaluatingObject(), expectation: "Hello ctx[Hello %@NSCONTEXT!|%@NSCONTEXT]!")
        checkFormat("%@ and %@", ContextEvaluatingObject(), CVarArgString("plain"), expectation: "ctx[%@NSCONTEXT and plain|%@NSCONTEXT] and plain")
    }
    #endif
}
