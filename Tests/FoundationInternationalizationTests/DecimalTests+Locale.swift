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

import Testing

#if canImport(FoundationInternationalization)
@testable import FoundationEssentials
@testable import FoundationInternationalization
#elseif FOUNDATION_FRAMEWORK
@testable import Foundation
#endif

struct DecimalLocaleTests {
    
    @Test func test_stringWithLocale() {
        
        let en_US = Locale(identifier: "en_US")
        let fr_FR = Locale(identifier: "fr_FR")
        
        #expect(Decimal(string: "1,234.56")! * 1000 == Decimal(1000))
        #expect(Decimal(string: "1,234.56", locale: en_US)! * 1000 == Decimal(1000))
        #expect(Decimal(string: "1,234.56", locale: fr_FR)! * 1000 == Decimal(1234))
        #expect(Decimal(string: "1.234,56", locale: en_US)! * 1000 == Decimal(1234))
        #expect(Decimal(string: "1.234,56", locale: fr_FR)! * 1000 == Decimal(1000))
        
        #expect(Decimal(string: "-1,234.56")! * 1000 == Decimal(-1000))
        #expect(Decimal(string: "+1,234.56")! * 1000 == Decimal(1000))
        #expect(Decimal(string: "+1234.56e3") == Decimal(1234560))
        #expect(Decimal(string: "+1234.56E3") == Decimal(1234560))
        #expect(Decimal(string: "+123456000E-3") == Decimal(123456))
        
        #expect(Decimal(string: "") == nil)
        #expect(Decimal(string: "x") == nil)
        #expect(Decimal(string: "-x") == Decimal.zero)
        #expect(Decimal(string: "+x") == Decimal.zero)
        #expect(Decimal(string: "-") == Decimal.zero)
        #expect(Decimal(string: "+") == Decimal.zero)
        #expect(Decimal(string: "-.") == Decimal.zero)
        #expect(Decimal(string: "+.") == Decimal.zero)
        
        #expect(Decimal(string: "-0") == Decimal.zero)
        #expect(Decimal(string: "+0") == Decimal.zero)
        #expect(Decimal(string: "-0.") == Decimal.zero)
        #expect(Decimal(string: "+0.") == Decimal.zero)
        #expect(Decimal(string: "e1") == Decimal.zero)
        #expect(Decimal(string: "e-5") == Decimal.zero)
        #expect(Decimal(string: ".3e1") == Decimal(3))
        
        #expect(Decimal(string: ".") == Decimal.zero)
        #expect(Decimal(string: ".", locale: en_US) == Decimal.zero)
        #expect(Decimal(string: ".", locale: fr_FR) == nil)
        
        #expect(Decimal(string: ",") == nil)
        #expect(Decimal(string: ",", locale: fr_FR) == Decimal.zero)
        #expect(Decimal(string: ",", locale: en_US) == nil)
        
        let s1 = "1234.5678"
        #expect(Decimal(string: s1, locale: en_US)?.description == s1)
        #expect(Decimal(string: s1, locale: fr_FR)?.description == "1234")
        
        let s2 = "1234,5678"
        #expect(Decimal(string: s2, locale: en_US)?.description == "1234")
        #expect(Decimal(string: s2, locale: fr_FR)?.description == s1)
    }
    
    @Test func test_DescriptionWithLocale() throws {
        let decimal = Decimal(string: "-123456.789")!
        #expect(decimal._toString(withDecimalSeparator: ".") == "-123456.789")
        let en = decimal._toString(withDecimalSeparator: try #require(Locale(identifier: "en_GB").decimalSeparator))
        #expect(en == "-123456.789")
        let fr = decimal._toString(withDecimalSeparator: try #require(Locale(identifier: "fr_FR").decimalSeparator))
        #expect(fr == "-123456,789")
    }
}
