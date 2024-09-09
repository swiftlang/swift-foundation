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

struct PredicateMacroFunctionCallTests {
    @Test func testSubscript() {
        AssertPredicateExpansion(
            """
            #Predicate<Object> { input in
                input[1]
            }
            """,
            """
            \(foundationModuleName).Predicate<Object>({ input in
                PredicateExpressions.build_subscript(
                    PredicateExpressions.build_Arg(input),
                    PredicateExpressions.build_Arg(1)
                )
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object> { input in
                input[1, default: "Hello"]
            }
            """,
            """
            \(foundationModuleName).Predicate<Object>({ input in
                PredicateExpressions.build_subscript(
                    PredicateExpressions.build_Arg(input),
                    PredicateExpressions.build_Arg(1),
                    default: PredicateExpressions.build_Arg("Hello")
                )
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object> { input, input2, input3 in
                input.dictionary[input2 + 1, default: input3 == input2] == false
            }
            """,
            """
            \(foundationModuleName).Predicate<Object>({ input, input2, input3 in
                PredicateExpressions.build_Equal(
                    lhs: PredicateExpressions.build_subscript(
                        PredicateExpressions.build_KeyPath(
                            root: PredicateExpressions.build_Arg(input),
                            keyPath: \\.dictionary
                        ),
                        PredicateExpressions.build_Arithmetic(
                            lhs: PredicateExpressions.build_Arg(input2),
                            rhs: PredicateExpressions.build_Arg(1),
                            op: .add
                        ),
                        default: PredicateExpressions.build_Equal(
                            lhs: PredicateExpressions.build_Arg(input3),
                            rhs: PredicateExpressions.build_Arg(input2)
                        )
                    ),
                    rhs: PredicateExpressions.build_Arg(false)
                )
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object> { input in
                input[index: 1]
            }
            """,
            diagnostics: ["2:10: The subscript(index:) function is not supported in this predicate"]
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object> { input in
                input[1, index: 2, 3, other: 4]
            }
            """,
            diagnostics: ["2:10: The subscript(_:index:_:other:) function is not supported in this predicate"]
        )
    }
    
    @Test func testContains() {
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                inputA.contains(inputB)
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ inputA, inputB in
                PredicateExpressions.build_contains(
                    PredicateExpressions.build_Arg(inputA),
                    PredicateExpressions.build_Arg(inputB)
                )
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<String> { input in
                input.contains("foo")
            }
            """,
            """
            \(foundationModuleName).Predicate<String>({ input in
                PredicateExpressions.build_contains(
                    PredicateExpressions.build_Arg(input),
                    PredicateExpressions.build_Arg("foo")
                )
            })
            """
        )
    }
    
    @Test func testContainsWhere() {
        AssertPredicateExpansion(
            """
            #Predicate<Object> { inputA in
                inputA.contains(where: {
                    $0
                })
            }
            """,
            """
            \(foundationModuleName).Predicate<Object>({ inputA in
                PredicateExpressions.build_contains(
                    PredicateExpressions.build_Arg(inputA),
                    where: {
                        PredicateExpressions.build_Arg(
                            $0
                        )
                    }
                )
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object> { inputA in
                inputA.contains {
                    $0
                }
            }
            """,
            """
            \(foundationModuleName).Predicate<Object>({ inputA in
                PredicateExpressions.build_contains(
                    PredicateExpressions.build_Arg(inputA)
                ) {
                    PredicateExpressions.build_Arg(
                        $0
                    )
                }
            })
            """
        )
    }
    
    @Test func testAllSatisfy() {
        AssertPredicateExpansion(
            """
            #Predicate<Object> { inputA in
                inputA.allSatisfy({
                    $0
                })
            }
            """,
            """
            \(foundationModuleName).Predicate<Object>({ inputA in
                PredicateExpressions.build_allSatisfy(
                    PredicateExpressions.build_Arg(inputA),
                    {
                        PredicateExpressions.build_Arg(
                            $0
                        )
                    }
                )
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object> { inputA in
                inputA.allSatisfy {
                    $0
                }
            }
            """,
            """
            \(foundationModuleName).Predicate<Object>({ inputA in
                PredicateExpressions.build_allSatisfy(
                    PredicateExpressions.build_Arg(inputA)
                ) {
                    PredicateExpressions.build_Arg(
                        $0
                    )
                }
            })
            """
        )
    }
    
    @Test func testFilter() {
        AssertPredicateExpansion(
            """
            #Predicate<Object> { inputA in
                inputA.filter({
                    $0
                })
            }
            """,
            """
            \(foundationModuleName).Predicate<Object>({ inputA in
                PredicateExpressions.build_filter(
                    PredicateExpressions.build_Arg(inputA),
                    {
                        PredicateExpressions.build_Arg(
                            $0
                        )
                    }
                )
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object> { inputA in
                inputA.filter {
                    $0
                }
            }
            """,
            """
            \(foundationModuleName).Predicate<Object>({ inputA in
                PredicateExpressions.build_filter(
                    PredicateExpressions.build_Arg(inputA)
                ) {
                    PredicateExpressions.build_Arg(
                        $0
                    )
                }
            })
            """
        )
        
        // Ensure that keypath literals are correctly translated into closure arguments
        AssertPredicateExpansion(
            """
            #Predicate<Object> { inputA in
                inputA.filter(\\Element.foo.bar)
            }
            """,
            """
            \(foundationModuleName).Predicate<Object>({ inputA in
                PredicateExpressions.build_filter(
                    PredicateExpressions.build_Arg(inputA),
                    {
                        PredicateExpressions.build_KeyPath(
                            root: PredicateExpressions.build_KeyPath(
                                root: PredicateExpressions.build_Arg($0),
                                keyPath: \\.foo
                            ),
                            keyPath: \\.bar
                        )
                    }
                )
            })
            """
        )
        
        // Ensure keypath literal to closure transformation only occurs when argument is a closure type
        // Note: starts(with:) explicitly does not take a closure as its argument
        AssertPredicateExpansion(
            """
            #Predicate<Object> { inputA in
                inputA.starts(with: \\Element.foo.bar)
            }
            """,
            """
            \(foundationModuleName).Predicate<Object>({ inputA in
                PredicateExpressions.build_starts(
                    PredicateExpressions.build_Arg(inputA),
                    with: PredicateExpressions.build_Arg(\\Element.foo.bar)
                )
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<[Object]> { inputA in
                inputA.filter(\\.foo!.bar).isEmpty
            }
            """,
            """
            \(foundationModuleName).Predicate<[Object]>({ inputA in
                PredicateExpressions.build_KeyPath(
                    root: PredicateExpressions.build_filter(
                        PredicateExpressions.build_Arg(inputA),
                        {
                            PredicateExpressions.build_KeyPath(
                                root: PredicateExpressions.build_ForcedUnwrap(
                                    PredicateExpressions.build_KeyPath(
                                        root: PredicateExpressions.build_Arg($0),
                                        keyPath: \\.foo
                                    )
                                ),
                                keyPath: \\.bar
                            )
                        }
                    ),
                    keyPath: \\.isEmpty
                )
            })
            """
        )
        
        // Key paths with anonymous closure arguments cannot be rewritten into nested closures automatically
        AssertPredicateExpansion(
            """
            #Predicate<[Object]> { inputA in
                inputA.filter(\\.foo[$0]).isEmpty
            }
            """,
            diagnostics: ["2:19: This key path is not supported here in this predicate. Use an explicit closure instead."]
        )
    }
    
    @Test func testStartsWith() {
        AssertPredicateExpansion(
            """
            #Predicate<Object> { inputA in
                inputA.starts(with: "foo")
            }
            """,
            """
            \(foundationModuleName).Predicate<Object>({ inputA in
                PredicateExpressions.build_starts(
                    PredicateExpressions.build_Arg(inputA),
                    with: PredicateExpressions.build_Arg("foo")
                )
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object> { inputA in
                inputA.hasPrefix("foo")
            }
            """,
            diagnostics: [
                DiagnosticTest(
                    "2:12: The hasPrefix(_:) function is not supported in this predicate",
                    fixIts: [
                        DiagnosticTest.FixItTest(
                            "Use starts(with:)",
                            result: """
                                    inputA.starts(with: "foo")
                                    """
                        )
                    ]
                )
            ]
        )
    }
    
    @Test func testMin() {
        AssertPredicateExpansion(
            """
            #Predicate<[Int]> { inputA in
                inputA.min() == 0
            }
            """,
            """
            \(foundationModuleName).Predicate<[Int]>({ inputA in
                PredicateExpressions.build_Equal(
                    lhs: PredicateExpressions.build_min(
                        PredicateExpressions.build_Arg(inputA)
                    ),
                    rhs: PredicateExpressions.build_Arg(0)
                )
            })
            """
        )
    }
    
    @Test func testMax() {
        AssertPredicateExpansion(
            """
            #Predicate<[Int]> { inputA in
                inputA.max() == 0
            }
            """,
            """
            \(foundationModuleName).Predicate<[Int]>({ inputA in
                PredicateExpressions.build_Equal(
                    lhs: PredicateExpressions.build_max(
                        PredicateExpressions.build_Arg(inputA)
                    ),
                    rhs: PredicateExpressions.build_Arg(0)
                )
            })
            """
        )
    }
    
    @Test func testLocalizedStandardContains() {
        AssertPredicateExpansion(
            """
            #Predicate<String> { inputA in
                inputA.localizedStandardContains("foo")
            }
            """,
            """
            \(foundationModuleName).Predicate<String>({ inputA in
                PredicateExpressions.build_localizedStandardContains(
                    PredicateExpressions.build_Arg(inputA),
                    PredicateExpressions.build_Arg("foo")
                )
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<String> { inputA in
                inputA.localizedCaseInsensitiveContains("foo")
            }
            """,
            diagnostics: [
                DiagnosticTest(
                    "2:12: The localizedCaseInsensitiveContains(_:) function is not supported in this predicate",
                    fixIts: [
                        DiagnosticTest.FixItTest(
                            "Use localizedStandardContains(_:)",
                            result: "inputA.localizedStandardContains(\"foo\")"
                        )
                    ])
            ]
        )
    }
    
    @Test func testLocalizedStandardCompare() {
        AssertPredicateExpansion(
            """
            #Predicate<String> { inputA in
                inputA.localizedCompare("foo")
            }
            """,
            """
            \(foundationModuleName).Predicate<String>({ inputA in
                PredicateExpressions.build_localizedCompare(
                    PredicateExpressions.build_Arg(inputA),
                    PredicateExpressions.build_Arg("foo")
                )
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<String> { inputA in
                inputA.localizedCaseInsensitiveCompare("foo")
            }
            """,
            diagnostics: [
                DiagnosticTest(
                    "2:12: The localizedCaseInsensitiveCompare(_:) function is not supported in this predicate",
                    fixIts: [
                        DiagnosticTest.FixItTest(
                            "Use localizedCompare(_:)",
                            result: "inputA.localizedCompare(\"foo\")"
                        )
                    ])
            ]
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<String> { inputA in
                inputA.localizedStandardCompare("foo")
            }
            """,
            diagnostics: [
                DiagnosticTest(
                    "2:12: The localizedStandardCompare(_:) function is not supported in this predicate",
                    fixIts: [
                        DiagnosticTest.FixItTest(
                            "Use localizedCompare(_:)",
                            result: "inputA.localizedCompare(\"foo\")"
                        )
                    ])
            ]
        )
    }
    
    @Test func testCaseInsensitiveCompare() {
        AssertPredicateExpansion(
            """
            #Predicate<String> { inputA in
                inputA.caseInsensitiveCompare("foo")
            }
            """,
            """
            \(foundationModuleName).Predicate<String>({ inputA in
                PredicateExpressions.build_caseInsensitiveCompare(
                    PredicateExpressions.build_Arg(inputA),
                    PredicateExpressions.build_Arg("foo")
                )
            })
            """
        )
    }
    
    #if FOUNDATION_FRAMEWORK
    @Test func testEvaluate() {
        AssertPredicateExpansion(
            """
            #Predicate<String> { input in
                other.evaluate()
            }
            """,
            """
            \(foundationModuleName).Predicate<String>({ input in
                PredicateExpressions.build_evaluate(
                    PredicateExpressions.build_Arg(other)
                )
            })
            """
        )
        AssertPredicateExpansion(
            """
            #Predicate<String> { input in
                other.evaluate(input)
            }
            """,
            """
            \(foundationModuleName).Predicate<String>({ input in
                PredicateExpressions.build_evaluate(
                    PredicateExpressions.build_Arg(other),
                    PredicateExpressions.build_Arg(input)
                )
            })
            """
        )
        AssertPredicateExpansion(
            """
            #Predicate<String> { input in
                other.evaluate(input, input)
            }
            """,
            """
            \(foundationModuleName).Predicate<String>({ input in
                PredicateExpressions.build_evaluate(
                    PredicateExpressions.build_Arg(other),
                    PredicateExpressions.build_Arg(input),
                    PredicateExpressions.build_Arg(input)
                )
            })
            """
        )
    }
    #endif
    
    @Test func testDiagnoseUnsupportedFunction() {
        AssertPredicateExpansion(
            """
            #Predicate<Object> { inputA in
               globalFunction(inputA)
            }
            """,
            diagnostics: ["2:4: Global functions are not supported in this predicate"]
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
               inputA.unsupportedFunction(inputB)
            }
            """,
            diagnostics: ["2:11: The unsupportedFunction(_:) function is not supported in this predicate"]
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
               inputA.unsupportedFunction(label: inputB)
            }
            """,
            diagnostics: ["2:11: The unsupportedFunction(label:) function is not supported in this predicate"]
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
               inputA.unsupportedFunction { $0 }
            }
            """,
            diagnostics: ["2:11: The unsupportedFunction() function is not supported in this predicate"]
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
               inputA.unsupportedFunction(inputB) { $0 }
            }
            """,
            diagnostics: ["2:11: The unsupportedFunction(_:) function is not supported in this predicate"]
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
               inputA.unsupportedFunction(label: inputB) { $0 }
            }
            """,
            diagnostics: ["2:11: The unsupportedFunction(label:) function is not supported in this predicate"]
        )
    }
}
