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

private func validatedFormat(_ format: String, validFormatSpecifiers: String, locale: Locale? = nil, arguments: [any CVarArg]) throws -> String {
    try withVaList(arguments) { args in
        Result {
            try String(_format: format, validFormatSpecifiers: validFormatSpecifiers, pluralizationNumber: nil, locale: locale, args: args)
        }
    }.get()
}

private func checkValidFormat(_ format: String, validFormatSpecifiers: String, _ arguments: any CVarArg..., locale: String? = nil, expectation: String, sourceLocation: SourceLocation = #_sourceLocation) {
    do {
        let result = try validatedFormat(format, validFormatSpecifiers: validFormatSpecifiers, locale: locale.map(Locale.init(identifier:)), arguments: arguments)
        #expect(result == expectation, sourceLocation: sourceLocation)
    } catch {
        Issue.record(error, sourceLocation: sourceLocation)
    }
}

private func checkInvalidFormat(_ format: String, validFormatSpecifiers: String, _ arguments: any CVarArg..., locale: String? = nil, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(throws: CocoaError.self, sourceLocation: sourceLocation) {
        try validatedFormat(format, validFormatSpecifiers: validFormatSpecifiers, locale: locale.map(Locale.init(identifier:)), arguments: arguments)
    }
}

@Suite("Format Validation")
struct FormatValidationTests {
    @Test func validFormats() {
        checkValidFormat("Hello", validFormatSpecifiers: "", expectation: "Hello")
        checkValidFormat("%%", validFormatSpecifiers: "", expectation: "%")
        checkValidFormat("%d", validFormatSpecifiers: "%d", Int32(5), expectation: "5")
        checkValidFormat("%d%%", validFormatSpecifiers: "%d", Int32(50), expectation: "50%")
        checkValidFormat("%1$d %2$@", validFormatSpecifiers: "%d %@", Int32(1), CVarArgString("x"), expectation: "1 x")
        checkValidFormat("%2$@ %1$d", validFormatSpecifiers: "%d %@", Int32(1), CVarArgString("x"), expectation: "x 1")
        checkValidFormat("%1$d %1$d", validFormatSpecifiers: "%d", Int32(3), expectation: "3 3")
        checkValidFormat("%ld", validFormatSpecifiers: "%d", 5, expectation: "5")
        checkValidFormat("%u", validFormatSpecifiers: "%d", Int32(5), expectation: "5")
        checkValidFormat("%x", validFormatSpecifiers: "%lld", 255, expectation: "ff")
        checkValidFormat("%C", validFormatSpecifiers: "%d", Int32(65), expectation: "A")
        checkValidFormat("%.*f", validFormatSpecifiers: "%d %f", Int32(2), 3.14159, expectation: "3.14")
        checkValidFormat("%*d", validFormatSpecifiers: "%d %d", Int32(4), Int32(7), expectation: "   7")
    }

    @Test func invalidFormats() {
        checkInvalidFormat("%d %d", validFormatSpecifiers: "%d", Int32(1), Int32(2))
        checkInvalidFormat("%@", validFormatSpecifiers: "%d", Int32(1))
        checkInvalidFormat("%f", validFormatSpecifiers: "%d", Int32(1))
        checkInvalidFormat("%d", validFormatSpecifiers: "%f", 1.5)
        checkInvalidFormat("%d", validFormatSpecifiers: "%@", CVarArgString("x"))
        checkInvalidFormat("%s", validFormatSpecifiers: "%d", Int32(1))
        checkInvalidFormat("%Lf", validFormatSpecifiers: "%f", 1.5)
        checkInvalidFormat("%5$d", validFormatSpecifiers: "%d", Int32(1))
        checkInvalidFormat("%2$d", validFormatSpecifiers: "%d %@", Int32(1), CVarArgString("x"))
        checkInvalidFormat("%*d", validFormatSpecifiers: "%d", Int32(1))
    }

    @Test func pointersMatchObjects() throws {
        #expect(throws: Never.self) {
            try validatedFormat("%p", validFormatSpecifiers: "%@", arguments: [CVarArgString("x")])
        }
    }

    @Test func incompleteSpecifier() {
        checkValidFormat("abc %", validFormatSpecifiers: "", expectation: "abc ")
    }

    @Test func errorDescribesTheMismatch() {
        #expect {
            try validatedFormat("Count: %@", validFormatSpecifiers: "Count: %d", arguments: [Int32(1)])
        } throws: { error in
            let cocoa = try #require(error as? CocoaError)
            return cocoa.code == .formatting && String(describing: cocoa).contains("Format specifier '%@' in format string 'Count: %@' has a kind that is incompatible with 'Count: %d'")
        }
    }

    @Test func overflowingWidthThrows() {
        checkInvalidFormat("%2147483648d", validFormatSpecifiers: "%d", Int32(1))
    }

    @Test func minimumWidthArgumentThrows() {
        checkInvalidFormat("a%*db", validFormatSpecifiers: "%d%d", Int32.min, Int32(42))
    }

    @Test func implicitArgumentLimit() throws {
        let maximum = String(repeating: "%d", count: 126)
        #expect(try validatedFormat(maximum, validFormatSpecifiers: maximum, arguments: Array(repeating: Int32(1), count: 126)) == String(repeating: "1", count: 126))

        let tooMany = String(repeating: "%d", count: 127)
        #expect(throws: CocoaError.self) {
            try validatedFormat(tooMany, validFormatSpecifiers: tooMany, arguments: Array(repeating: Int32(1), count: 127))
        }
    }
}
