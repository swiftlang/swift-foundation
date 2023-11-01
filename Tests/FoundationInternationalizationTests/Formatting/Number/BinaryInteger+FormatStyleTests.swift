// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// RUN: %target-run-simple-swift
// REQUIRES: executable_test

import XCTest

import FoundationEssentials
@testable import FoundationInternationalization

#if canImport(Numberick) // Not included by default as it's a 3rd party library; requires https://github.com/oscbyspro/Numberick.git be added the package dependencies.
import Numberick
#endif

#if canImport(BigInt) // Not included by default as it's a 3rd party library; requires https://github.com/attaswift/BigInt.git be added the package dependencies.  Proved useful in the past for finding bugs that only show up with large numbers.
import BigInt
#endif

final class BinaryIntegerFormatStyleTests: XCTestCase {
    // NSR == numericStringRepresentation
    func checkNSR(value: some BinaryInteger, expected: String) {
        XCTAssertEqual(String(decoding: value.numericStringRepresentation, as: Unicode.ASCII.self), expected)
    }

    func testNumericStringRepresentation_builtinIntegersLimits() throws {
        func check<I: FixedWidthInteger>(type: I.Type = I.self, min: String, max: String) {
            checkNSR(value: I.min, expected: min)
            checkNSR(value: I.max, expected: max)
        }

        check(type: Int8.self, min: "-128", max: "127")
        check(type: Int16.self, min: "-32768", max: "32767")
        check(type: Int32.self, min: "-2147483648", max: "2147483647")
        check(type: Int64.self, min: "-9223372036854775808", max: "9223372036854775807")

        check(type: UInt8.self, min: "0", max: "255")
        check(type: UInt16.self, min: "0", max: "65535")
        check(type: UInt32.self, min: "0", max: "4294967295")
        check(type: UInt64.self, min: "0", max: "18446744073709551615")
    }

    func testNumericStringRepresentation_builtinIntegersAroundDecimalMagnitude() throws {
        func check<I: FixedWidthInteger>(type: I.Type = I.self, magnitude: String, oneLess: String, oneMore: String) {
            var mag = I(1); while !mag.multipliedReportingOverflow(by: 10).overflow { mag *= 10 }
            
            checkNSR(value: mag, expected: magnitude)
            checkNSR(value: mag - 1, expected: oneLess)
            checkNSR(value: mag + 1, expected: oneMore)
        }

        check(type: Int8.self, magnitude: "100", oneLess: "99", oneMore: "101")
        check(type: Int16.self, magnitude: "10000", oneLess: "9999", oneMore: "10001")
        check(type: Int32.self, magnitude: "1000000000", oneLess: "999999999", oneMore: "1000000001")
        check(type: Int64.self, magnitude: "1000000000000000000", oneLess: "999999999999999999", oneMore: "1000000000000000001")

        check(type: UInt8.self, magnitude: "100", oneLess: "99", oneMore: "101")
        check(type: UInt16.self, magnitude: "10000", oneLess: "9999", oneMore: "10001")
        check(type: UInt32.self, magnitude: "1000000000", oneLess: "999999999", oneMore: "1000000001")
        check(type: UInt64.self, magnitude: "10000000000000000000", oneLess: "9999999999999999999", oneMore: "10000000000000000001")
    }

#if canImport(Numberick) || canImport(BigInt)
    // An initialiser has to be passed manually because BinaryInteger doesn't actually provide a way to initialise an instance from a string representation (that's functional for non-builtin integers).
    func check<I: BinaryInteger>(type: I.Type = I.self, initialiser: (String) -> I?) {
        // Just some real basic sanity checks first.
        checkNSR(value: I(0), expected: "0")
        checkNSR(value: I(1), expected: "1")

        if I.isSigned {
            checkNSR(value: I(-1), expected: "-1")
        }

        for valueAsString in ["9223372036854775807", // Int64.max
                              "9223372036854775808", // Int64.max + 1 (and Int64.min when negated).

                              "9999999999999999999", // Test around the magnitude.
                              "10000000000000000000",
                              "10000000000000000001",

                              "18446744073709551615", // UInt64.max
                              "18446744073709551616", // UInt64.max + 1

                              "170141183460469231731687303715884105727", // Int128.max
                              "170141183460469231731687303715884105728", // Int128.max + 1
                              "340282366920938463463374607431768211455", // UInt128.max
                              "340282366920938463463374607431768211456", // UInt128.max + 1

                              // Some arbitrary, *very* large numbers to ensure there's no egregious scaling issues nor fatal inaccuracies in things like sizing of preallocated buffers.
                              "1" + String(repeating: "0", count: 99),
                              "1" + String(repeating: "0", count: 999),
                              "1" + String(repeating: "0", count: 1406), // First power of ten value at which an earlier implementation crashed due to underestimating how many wordStrings would be needed.
                              String(repeating: "1234567890", count: 10),
                              String(repeating: "1234567890", count: 100)] {
            if let value = initialiser(valueAsString) { // The test cases cover a wide range of values, that don't all fit into every type tested (i.e. the fixed-width types from Numberick).
                XCTAssertEqual(value.description, valueAsString) // Sanity check that it initialised from the string correctly.
                checkNSR(value: value, expected: valueAsString)

                if I.isSigned {
                    let negativeValueAsString = "-" + valueAsString
                    let negativeValue = initialiser(negativeValueAsString)!

                    XCTAssertEqual(negativeValue.description, negativeValueAsString) // Sanity check that it initialised from the string correctly.
                    checkNSR(value: negativeValue, expected: negativeValueAsString)
                }
            }
        }
    }

#if canImport(Numberick)
    func testNumericStringRepresentation_largeIntegers() throws {
        check(type: Int128.self, initialiser: { Int128($0) })
        check(type: UInt128.self, initialiser: { UInt128($0) })

        check(type: Int256.self, initialiser: { Int256($0) })
        check(type: UInt256.self, initialiser: { UInt256($0) })
    }
#endif

#if canImport(BigInt)
    func testNumericStringRepresentation_arbitraryPrecisionIntegers() throws {
        check(type: BigInt.self, initialiser: { BigInt($0)! })
        check(type: BigUInt.self, initialiser: { BigUInt($0)! })
    }
#endif
#endif // canImport(Numberick) || canImport(BigInt)
}

final class BinaryIntegerFormatStyleTestsUsingBinaryIntegerWords: XCTestCase {
    
    // MARK: Tests
    
    func testMinMax32() {
        check(integer:  Int32.min,       expectation: "-2147483648")
        check(integer:  Int32.max,       expectation:  "2147483647")
        check(integer: UInt32.min,       expectation:           "0")
        check(integer: UInt32.max/2,     expectation:  "2147483647")
        check(integer: UInt32.max/2 + 1, expectation:  "2147483648")
        check(integer: UInt32.max,       expectation:  "4294967295")
    }
    
    /// Tests the highest and lowest slice of a byte sequence that goes from 0x00 through 0xff.
    func testTopBot32() {
        check(integer:  Int32(bitPattern: 0xfffefdfc), expectation:     "-66052")
        check(integer:  Int32(bitPattern: 0x03020100), expectation:   "50462976")
        check(integer: UInt32(            0xfffefdfc), expectation: "4294901244")
        check(integer: UInt32(            0x03020100), expectation:   "50462976")
    }
    
    func testMinMax64() {
        check(integer:  Int64.min,       expectation: "-9223372036854775808")
        check(integer:  Int64.max,       expectation:  "9223372036854775807")
        check(integer: UInt64.min,       expectation:                    "0")
        check(integer: UInt64.max/2,     expectation:  "9223372036854775807")
        check(integer: UInt64.max/2 + 1, expectation:  "9223372036854775808")
        check(integer: UInt64.max,       expectation: "18446744073709551615")
    }
    
    /// Tests the highest and lowest slice of a byte sequence that goes from 0x00 through 0xff.
    func testTopBot64() {
        check(integer:  Int64(bitPattern: 0xfffefdfcfbfaf9f8), expectation:     "-283686952306184")
        check(integer:  Int64(bitPattern: 0x0706050403020100), expectation:   "506097522914230528")
        check(integer: UInt64(            0xfffefdfcfbfaf9f8), expectation: "18446460386757245432")
        check(integer: UInt64(            0x0706050403020100), expectation:   "506097522914230528")
    }
    
    func testMinMax128() {
        check(x64:[ 0, ~0/2 + 1] as [UInt64], isSigned: true,  expectation: "-170141183460469231731687303715884105728") //  Int128.min
        check(x64:[~0, ~0/2    ] as [UInt64], isSigned: true,  expectation:  "170141183460469231731687303715884105727") //  Int128.max
        check(x64:[ 0,  0      ] as [UInt64], isSigned: false, expectation:                                        "0") // UInt128.min
        check(x64:[~0, ~0/2    ] as [UInt64], isSigned: false, expectation:  "170141183460469231731687303715884105727") // UInt128.max/2
        check(x64:[ 0, ~0/2 + 1] as [UInt64], isSigned: false, expectation:  "170141183460469231731687303715884105728") // UInt128.max/2 + 1
        check(x64:[~0, ~0      ] as [UInt64], isSigned: false, expectation:  "340282366920938463463374607431768211455") // UInt128.max
    }
    
    /// Tests the highest and lowest slice of a byte sequence that goes from 0x00 through 0xff.
    func testTopBot128() {
        check(x64:[0xf7f6f5f4f3f2f1f0, 0xfffefdfcfbfaf9f8] as [UInt64], isSigned: true,  expectation:     "-5233100606242806050955395731361296")
        check(x64:[0x0706050403020100, 0x0f0e0d0c0b0a0908] as [UInt64], isSigned: true,  expectation:  "20011376718272490338853433276725592320")
        check(x64:[0xf7f6f5f4f3f2f1f0, 0xfffefdfcfbfaf9f8] as [UInt64], isSigned: false, expectation: "340277133820332220657323652036036850160")
        check(x64:[0x0706050403020100, 0x0f0e0d0c0b0a0908] as [UInt64], isSigned: false, expectation:  "20011376718272490338853433276725592320")
    }
    
    func testWordsIsEmptyResultsInZero() {
        check(words:[  ] as [UInt], isSigned: true,  expectation: "0")
        check(words:[  ] as [UInt], isSigned: false, expectation: "0")
    }
    
    func testSignExtendingDoesNotChangeTheResult() {
        check(words:[ 0            ] as [UInt], isSigned: true,  expectation:  "0")
        check(words:[ 0,  0        ] as [UInt], isSigned: true,  expectation:  "0")
        check(words:[ 0,  0,  0    ] as [UInt], isSigned: true,  expectation:  "0")
        check(words:[ 0,  0,  0,  0] as [UInt], isSigned: true,  expectation:  "0")
        
        check(words:[~0            ] as [UInt], isSigned: true,  expectation: "-1")
        check(words:[~0, ~0        ] as [UInt], isSigned: true,  expectation: "-1")
        check(words:[~0, ~0, ~0    ] as [UInt], isSigned: true,  expectation: "-1")
        check(words:[~0, ~0, ~0, ~0] as [UInt], isSigned: true,  expectation: "-1")
        
        check(words:[ 0            ] as [UInt], isSigned: false, expectation:  "0")
        check(words:[ 0,  0        ] as [UInt], isSigned: false, expectation:  "0")
        check(words:[ 0,  0,  0    ] as [UInt], isSigned: false, expectation:  "0")
        check(words:[ 0,  0,  0,  0] as [UInt], isSigned: false, expectation:  "0")
    }
    
    // MARK: Assertions
     
    func check(integer: some BinaryInteger, expectation: String, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(integer.description, expectation,  file:  file, line: line)
        check(ascii: integer.numericStringRepresentation, expectation: expectation, file: file, line: line)
        check(words: Array(integer.words), isSigned: type(of: integer).isSigned, expectation: expectation, file: file, line: line)
    }
    
    func check(x64: [UInt64], isSigned: Bool, expectation: String, file: StaticString = #file, line: UInt = #line) {
        check(words: x64.flatMap(\.words), isSigned: isSigned, expectation: expectation, file: file, line: line)
    }
    
    func check(words: [UInt], isSigned: Bool, expectation: String, file: StaticString = #file, line: UInt = #line) {
        let ascii = numericStringRepresentationForBinaryInteger(words: words, isSigned: isSigned)
        check(ascii: ascii, expectation: expectation, file: file, line: line)
    }
    
    func check(ascii: some Collection<UInt8>, expectation: String, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(String(decoding: ascii, as: Unicode.ASCII.self), expectation, file: file, line: line)
    }
}
