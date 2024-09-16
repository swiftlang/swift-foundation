//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing

#if canImport(FoundationInternationalization)
import FoundationEssentials
import FoundationInternationalization
#elseif FOUNDATION_FRAMEWORK
import Foundation
#endif

struct PredicateInternationalizationTests {
    
    struct Object {
        var string: String = ""
    }
    
    #if FOUNDATION_FRAMEWORK
    
    @Test(arguments: [
        ("ABC", "ABC", ComparisonResult.orderedSame),
        ("ABC", "abc", .orderedDescending),
        ("abc", "ABC", .orderedAscending),
        ("ABC", "ÁḄÇ", .orderedAscending)
    ])
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    func testLocalizedCompare(input: (String, String, ComparisonResult)) throws {
        let predicate = #Predicate<String, String, ComparisonResult> {
            $0.localizedCompare($1) == $2
        }
        
        #expect(try predicate.evaluate(input.0, input.1, input.2), "Comparison failed for inputs '\(input.0)', '\(input.1)' - expected \(input.2.rawValue)")
    }
    
    @Test(arguments: ["ABCDEF", "abcdef", "ÁḄÇDEF"])
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    func testLocalizedStandardContains(value: String) throws {
        let predicate = #Predicate<Object> {
            $0.string.localizedStandardContains("ABC")
        }
        #expect(try predicate.evaluate(Object(string: value)))
    }
    
    #endif
    
}
