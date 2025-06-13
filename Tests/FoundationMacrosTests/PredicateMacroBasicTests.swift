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

@Suite("#Predicate Macro Basics")
private struct PredicateMacroBasicTests {
    @Test func simple() {
        AssertPredicateExpansion(
            """
            #Predicate<Object> { input in
                return true
            }
            """,
            """
            \(foundationModuleName).Predicate<Object>({ input in
                return PredicateExpressions.build_Arg(
                    true
                )
            })
            """
        )
    }
    
    @Test func implicitReturn() {
        AssertPredicateExpansion(
            """
            #Predicate<Object> { input in
                true
            }
            """,
            """
            \(foundationModuleName).Predicate<Object>({ input in
                PredicateExpressions.build_Arg(
                    true
                )
            })
            """
        )
    }
    
    @Test func inferredGenerics() {
        AssertPredicateExpansion(
            """
            #Predicate { input in
                true
            }
            """,
            """
            \(foundationModuleName).Predicate({ input in
                PredicateExpressions.build_Arg(
                    true
                )
            })
            """
        )
    }
    
    @Test func shorthandArgumentNames() {
        AssertPredicateExpansion(
            """
            #Predicate<Object> {
                $0
            }
            """,
            """
            \(foundationModuleName).Predicate<Object>({
                PredicateExpressions.build_Arg(
                    $0
                )
            })
            """
        )
    }
    
    @Test func explicitClosureArgumentTypes() {
        AssertPredicateExpansion(
            """
            #Predicate<Int, String> { (a: Int, b: String) -> Bool in
                true
            }
            """,
            """
            \(foundationModuleName).Predicate<Int, String>({ (a: PredicateExpressions.Variable<Int>, b: PredicateExpressions.Variable<String>) in
                PredicateExpressions.build_Arg(
                    true
                )
            })
            """
        )
    }
    
    @Test func diagnoseMissingTrailingClosure() {
        AssertPredicateExpansion(
            """
            #Predicate
            """,
            diagnostics: ["1:1: #Predicate macro expansion requires a trailing closure"]
        )
        AssertPredicateExpansion(
            """
            #Predicate<Object>
            """,
            diagnostics: ["1:1: #Predicate macro expansion requires a trailing closure"]
        )
        AssertPredicateExpansion(
            """
            #Predicate<Object>(myClosure)
            """,
            diagnostics: ["1:1: #Predicate macro expansion requires a trailing closure"]
        )
        AssertPredicateExpansion(
            """
            #Predicate<Object>({
                return true
            })
            """,
            diagnostics: [
                DiagnosticTest(
                    "1:1: #Predicate macro expansion requires a trailing closure",
                    fixIts: [
                        DiagnosticTest.FixItTest(
                            "Use a trailing closure instead of a function parameter",
                            result: """
                                    #Predicate<Object> {
                                        return true
                                    }
                                    """
                        )
                    ]
                )
            ]
        )
    }
    
    @Test func keyPath() {
        AssertPredicateExpansion(
            """
            #Predicate<Object> {
                $0.foo
            }
            """,
            """
            \(foundationModuleName).Predicate<Object>({
                PredicateExpressions.build_KeyPath(
                    root: PredicateExpressions.build_Arg($0),
                    keyPath: \\.foo
                )
            })
            """
        )
        AssertPredicateExpansion(
            """
            #Predicate<Object> { input in
                input.foo
            }
            """,
            """
            \(foundationModuleName).Predicate<Object>({ input in
                PredicateExpressions.build_KeyPath(
                    root: PredicateExpressions.build_Arg(input),
                    keyPath: \\.foo
                )
            })
            """
        )
        AssertPredicateExpansion(
            """
            #Predicate<Object> {
                $0.foo.bar
            }
            """,
            """
            \(foundationModuleName).Predicate<Object>({
                PredicateExpressions.build_KeyPath(
                    root: PredicateExpressions.build_KeyPath(
                        root: PredicateExpressions.build_Arg($0),
                        keyPath: \\.foo
                    ),
                    keyPath: \\.bar
                )
            })
            """
        )
    }
    
    @Test func comments() {
        AssertPredicateExpansion(
            """
            // comment
            #Predicate<Object> { input in // comment
                return true // comment
            } // comment
            """,
            """
            // comment
            \(foundationModuleName).Predicate<Object>({ input in
                return PredicateExpressions.build_Arg(
                    true // comment
                )
            }) // comment
            """
        )
    }
}
