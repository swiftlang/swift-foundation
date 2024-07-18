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

#if canImport(TestSupport)
import TestSupport
#endif

// TODO: Reenable these tests once DateFormatStyle has been ported
final class DecimalLocaleTests : XCTestCase {
    func test_stringWithLocale() {
        let en_US = Locale(identifier: "en_US")
        let fr_FR = Locale(identifier: "fr_FR")
        
        XCTAssertEqual(Decimal(string: "1,234.56")! * 1000, Decimal(1000))
        XCTAssertEqual(Decimal(string: "1,234.56", locale: en_US)! * 1000, Decimal(1000))
        XCTAssertEqual(Decimal(string: "1,234.56", locale: fr_FR)! * 1000, Decimal(1234))
        XCTAssertEqual(Decimal(string: "1.234,56", locale: en_US)! * 1000, Decimal(1234))
        XCTAssertEqual(Decimal(string: "1.234,56", locale: fr_FR)! * 1000, Decimal(1000))
        
        XCTAssertEqual(Decimal(string: "-1,234.56")! * 1000, Decimal(-1000))
        XCTAssertEqual(Decimal(string: "+1,234.56")! * 1000, Decimal(1000))
        XCTAssertEqual(Decimal(string: "+1234.56e3"), Decimal(1234560))
        XCTAssertEqual(Decimal(string: "+1234.56E3"), Decimal(1234560))
        XCTAssertEqual(Decimal(string: "+123456000E-3"), Decimal(123456))
        
        XCTAssertNil(Decimal(string: ""))
        XCTAssertNil(Decimal(string: "x"))
        XCTAssertEqual(Decimal(string: "-x"), Decimal.zero)
        XCTAssertEqual(Decimal(string: "+x"), Decimal.zero)
        XCTAssertEqual(Decimal(string: "-"), Decimal.zero)
        XCTAssertEqual(Decimal(string: "+"), Decimal.zero)
        XCTAssertEqual(Decimal(string: "-."), Decimal.zero)
        XCTAssertEqual(Decimal(string: "+."), Decimal.zero)
        
        XCTAssertEqual(Decimal(string: "-0"), Decimal.zero)
        XCTAssertEqual(Decimal(string: "+0"), Decimal.zero)
        XCTAssertEqual(Decimal(string: "-0."), Decimal.zero)
        XCTAssertEqual(Decimal(string: "+0."), Decimal.zero)
        XCTAssertEqual(Decimal(string: "e1"), Decimal.zero)
        XCTAssertEqual(Decimal(string: "e-5"), Decimal.zero)
        XCTAssertEqual(Decimal(string: ".3e1"), Decimal(3))
        
        XCTAssertEqual(Decimal(string: "."), Decimal.zero)
        XCTAssertEqual(Decimal(string: ".", locale: en_US), Decimal.zero)
        XCTAssertNil(Decimal(string: ".", locale: fr_FR))
        
        XCTAssertNil(Decimal(string: ","))
        XCTAssertEqual(Decimal(string: ",", locale: fr_FR), Decimal.zero)
        XCTAssertNil(Decimal(string: ",", locale: en_US))
        
        let s1 = "1234.5678"
        XCTAssertEqual(Decimal(string: s1, locale: en_US)?.description, s1)
        XCTAssertEqual(Decimal(string: s1, locale: fr_FR)?.description, "1234")
        
        let s2 = "1234,5678"
        XCTAssertEqual(Decimal(string: s2, locale: en_US)?.description, "1234")
        XCTAssertEqual(Decimal(string: s2, locale: fr_FR)?.description, s1)
    }
}
