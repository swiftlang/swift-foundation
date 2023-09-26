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

#if canImport(TestSupport)
import TestSupport
#endif

// Predicate does not back-deploy to older Darwin versions
#if FOUNDATION_FRAMEWORK || os(Linux) || os(Windows)

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
final class PredicateInternationalizationTests: XCTestCase {
    
    struct Object {
        var string: String = ""
    }
    
    #if FOUNDATION_FRAMEWORK
    
    func testLocalizedCompare() throws {
        let predicate = Predicate<String, String, ComparisonResult> {
            // $0.localizedCompare($1) == $2
            PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_localizedCompare(
                    PredicateExpressions.build_Arg($0),
                    PredicateExpressions.build_Arg($1)
                ),
                rhs: PredicateExpressions.build_Arg($2)
            )
        }
        let tests: [(String, String, ComparisonResult)] = [
            ("ABC", "ABC", .orderedSame),
            ("ABC", "abc", .orderedDescending),
            ("abc", "ABC", .orderedAscending),
            ("ABC", "ÁḄÇ", .orderedAscending)
        ]
        
        for test in tests {
            XCTAssertTrue(try predicate.evaluate(test.0, test.1, test.2), "Comparison failed for inputs '\(test.0)', '\(test.1)' - expected \(test.2.rawValue)")
        }
    }
    
    func testLocalizedStandardContains() throws {
        let predicate = Predicate<Object> {
            // $0.string.localizedStandardContains("ABC")
            PredicateExpressions.build_localizedStandardContains(
                PredicateExpressions.build_KeyPath(
                    root: PredicateExpressions.build_Arg($0),
                    keyPath: \.string
                ),
                PredicateExpressions.build_Arg("ABC")
            )
        }
        XCTAssertTrue(try predicate.evaluate(Object(string: "ABCDEF")))
        XCTAssertTrue(try predicate.evaluate(Object(string: "abcdef")))
        XCTAssertTrue(try predicate.evaluate(Object(string: "ÁḄÇDEF")))
    }
    
    #endif
    
}

#endif
