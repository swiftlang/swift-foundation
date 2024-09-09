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

struct PredicateMacroLanguageTokenTests {
    @Test func testConditional() {
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object, Object> { inputA, inputB, inputC in
                inputA ? inputB : inputC
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object, Object>({ inputA, inputB, inputC in
                PredicateExpressions.build_Conditional(
                    PredicateExpressions.build_Arg(inputA),
                    PredicateExpressions.build_Arg(inputB),
                    PredicateExpressions.build_Arg(inputC)
                )
            })
            """
        )
    }
    
    @Test func testTypeCheck() {
        AssertPredicateExpansion(
            """
            #Predicate<Object> { input in
                input is Int
            }
            """,
            """
            \(foundationModuleName).Predicate<Object>({ input in
                PredicateExpressions.TypeCheck<_, Int>(
                    PredicateExpressions.build_Arg(input)
                )
            })
            """
        )
    }
    
    @Test func testConditionalCast() {
        AssertPredicateExpansion(
            """
            #Predicate<Object> { input in
                (input as? Bool) == true
            }
            """,
            """
            \(foundationModuleName).Predicate<Object>({ input in
                PredicateExpressions.build_Equal(
                    lhs: PredicateExpressions.ConditionalCast<_, Bool>(
                        PredicateExpressions.build_Arg(input)
                    ),
                    rhs: PredicateExpressions.build_Arg(true)
                )
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object> { input in
                (input as Bool) == true
            }
            """,
            """
            \(foundationModuleName).Predicate<Object>({ input in
                PredicateExpressions.build_Equal(
                    lhs: PredicateExpressions.ForceCast<_, Bool>(
                        PredicateExpressions.build_Arg(input)
                    ),
                    rhs: PredicateExpressions.build_Arg(true)
                )
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object> { input in
                (input as! Bool) == true
            }
            """,
            """
            \(foundationModuleName).Predicate<Object>({ input in
                PredicateExpressions.build_Equal(
                    lhs: PredicateExpressions.ForceCast<_, Bool>(
                        PredicateExpressions.build_Arg(input)
                    ),
                    rhs: PredicateExpressions.build_Arg(true)
                )
            })
            """
        )
    }
    
    @Test func testIfExpressions() {
        AssertPredicateExpansion(
            """
            #Predicate<Object> { input in
                if input {
                    return input
                } else {
                    return input.foo
                }
            }
            """,
            """
            \(foundationModuleName).Predicate<Object>({ input in
                PredicateExpressions.build_Conditional(
                    PredicateExpressions.build_Arg(input),
                    PredicateExpressions.build_Arg(
                        input
                    ),
                    PredicateExpressions.build_KeyPath(
                        root: PredicateExpressions.build_Arg(input),
                        keyPath: \\.foo
                    )
                )
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { input, inputB in
                if input.foo, input.abc && input.xyz {
                    input.bar && input.baz
                } else {
                    inputB.foobar
                }
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ input, inputB in
                PredicateExpressions.build_Conditional(
                    PredicateExpressions.build_Conjunction(
                        lhs: PredicateExpressions.build_KeyPath(
                            root: PredicateExpressions.build_Arg(input),
                            keyPath: \\.foo
                        ),
                        rhs: PredicateExpressions.build_Conjunction(
                            lhs: PredicateExpressions.build_KeyPath(
                                root: PredicateExpressions.build_Arg(input),
                                keyPath: \\.abc
                            ),
                            rhs: PredicateExpressions.build_KeyPath(
                                root: PredicateExpressions.build_Arg(input),
                                keyPath: \\.xyz
                            )
                        )
                    ),
                    PredicateExpressions.build_Conjunction(
                        lhs: PredicateExpressions.build_KeyPath(
                            root: PredicateExpressions.build_Arg(input),
                            keyPath: \\.bar
                        ),
                        rhs: PredicateExpressions.build_KeyPath(
                            root: PredicateExpressions.build_Arg(input),
                            keyPath: \\.baz
                        )
                    ),
                    PredicateExpressions.build_KeyPath(
                        root: PredicateExpressions.build_Arg(inputB),
                        keyPath: \\.foobar
                    )
                )
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object> { input in
                if input.foo {
                    if input.bar {
                        input.baz
                    } else {
                        input.foobar
                    }
                } else {
                    if input.bar {
                        input.foobar
                    } else {
                        input.baz
                    }
                }
            }
            """,
            """
            \(foundationModuleName).Predicate<Object>({ input in
                PredicateExpressions.build_Conditional(
                    PredicateExpressions.build_KeyPath(
                        root: PredicateExpressions.build_Arg(input),
                        keyPath: \\.foo
                    ),
                    PredicateExpressions.build_Conditional(
                        PredicateExpressions.build_KeyPath(
                            root: PredicateExpressions.build_Arg(input),
                            keyPath: \\.bar
                        ),
                        PredicateExpressions.build_KeyPath(
                            root: PredicateExpressions.build_Arg(input),
                            keyPath: \\.baz
                        ),
                        PredicateExpressions.build_KeyPath(
                            root: PredicateExpressions.build_Arg(input),
                            keyPath: \\.foobar
                        )
                    ),
                    PredicateExpressions.build_Conditional(
                        PredicateExpressions.build_KeyPath(
                            root: PredicateExpressions.build_Arg(input),
                            keyPath: \\.bar
                        ),
                        PredicateExpressions.build_KeyPath(
                            root: PredicateExpressions.build_Arg(input),
                            keyPath: \\.foobar
                        ),
                        PredicateExpressions.build_KeyPath(
                            root: PredicateExpressions.build_Arg(input),
                            keyPath: \\.baz
                        )
                    )
                )
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object> { input in
                if #available(macOS 14, *) {
                    input.foo
                } else {
                    input.bar
                }
            }
            """,
            diagnostics: ["2:8: Availability conditions are not supported in this predicate"]
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object?> { input in
                if let nonOpt = input {
                    nonOpt.foo
                } else {
                    true
                }
            }
            """,
            """
            \(foundationModuleName).Predicate<Object?>({ input in
                PredicateExpressions.build_NilCoalesce(
                    lhs: PredicateExpressions.build_flatMap(
                        PredicateExpressions.build_Arg(input)
                    ) { nonOpt in
                        PredicateExpressions.build_KeyPath(
                            root: PredicateExpressions.build_Arg(nonOpt),
                            keyPath: \\.foo
                        )
                    },
                    rhs: PredicateExpressions.build_Arg(
                        true
                    )
                )
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object?> { input in
                if let nonOpt = input, let nonOpt2 = nonOpt.foo {
                    nonOpt2
                } else {
                    true
                }
            }
            """,
            """
            \(foundationModuleName).Predicate<Object?>({ input in
                PredicateExpressions.build_NilCoalesce(
                    lhs: PredicateExpressions.build_flatMap(
                        PredicateExpressions.build_Arg(input)
                    ) { nonOpt in
                        PredicateExpressions.build_flatMap(
                            PredicateExpressions.build_KeyPath(
                                root: PredicateExpressions.build_Arg(nonOpt),
                                keyPath: \\.foo
                            )
                        ) { nonOpt2 in
                            PredicateExpressions.build_Arg(
                                nonOpt2
                            )
                        }
                    },
                    rhs: PredicateExpressions.build_Arg(
                        true
                    )
                )
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object> { input in
                if let nonOpt = input.foo?.bar {
                    nonOpt.baz
                } else {
                    true
                }
            }
            """,
            """
            \(foundationModuleName).Predicate<Object>({ input in
                PredicateExpressions.build_NilCoalesce(
                    lhs: PredicateExpressions.build_flatMap(
                        PredicateExpressions.build_flatMap(
                            PredicateExpressions.build_KeyPath(
                                root: PredicateExpressions.build_Arg(input),
                                keyPath: \\.foo
                            )
                        ) {
                            PredicateExpressions.build_KeyPath(
                                root: PredicateExpressions.build_Arg($0),
                                keyPath: \\.bar
                            )
                        }
                    ) { nonOpt in
                        PredicateExpressions.build_KeyPath(
                            root: PredicateExpressions.build_Arg(nonOpt),
                            keyPath: \\.baz
                        )
                    },
                    rhs: PredicateExpressions.build_Arg(
                        true
                    )
                )
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object?> { input in
                if case .enumcase(let assocval) = input.foo {
                    assocval
                } else {
                    true
                }
            }
            """,
            diagnostics: ["2:8: Matching pattern conditions are not supported in this predicate"]
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object?> { input in
                if let nonOpt = input, nonOpt.foo == 2 {
                    nonOpt.bar
                } else {
                    true
                }
            }
            """,
            diagnostics: ["2:8: Mixing optional bindings with other conditions is not supported in this predicate"]
        )
    }
    
    @Test func testNilLiterals() {
        AssertPredicateExpansion(
            """
            #Predicate<Object?> { input in
                input == nil
            }
            """,
            """
            \(foundationModuleName).Predicate<Object?>({ input in
                PredicateExpressions.build_Equal(
                    lhs: PredicateExpressions.build_Arg(input),
                    rhs: PredicateExpressions.build_NilLiteral()
                )
            })
            """
        )
    }
    
    @Test func testDiagnoseDeclarations() {
        AssertPredicateExpansion(
            """
            #Predicate<Object> { input in
                let foo = input
                return foo
            }
            """,
            diagnostics: ["3:5: Predicate body may only contain one expression"]
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object> { input in
                var foo = input
                return foo
            }
            """,
            diagnostics: ["3:5: Predicate body may only contain one expression"]
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object> { input in
                struct Foo {}
                return true
            }
            """,
            diagnostics: ["3:5: Predicate body may only contain one expression"]
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object> { input in
                class Foo {}
                return true
            }
            """,
            diagnostics: ["3:5: Predicate body may only contain one expression"]
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object> { input in
                protocol Foo {}
                return true
            }
            """,
            diagnostics: ["3:5: Predicate body may only contain one expression"]
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object> { input in
                func bar() {}
                return foo
            }
            """,
            diagnostics: ["3:5: Predicate body may only contain one expression"]
        )
    }
    
    @Test func testDiagnoseMiscellaneousStatements() {
        AssertPredicateExpansion(
            """
            #Predicate<Object> { input in
                for _ in 0 ..< 2 {
                    return true
                }
            }
            """,
            diagnostics: ["2:5: For-in loops are not supported in this predicate"]
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object> { input in
                while true {
                    return true
                }
            }
            """,
            diagnostics: ["2:5: While loops are not supported in this predicate"]
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object> { input in
                repeat {
                    return true
                } while true
            }
            """,
            diagnostics: ["2:5: Repeat-while loops are not supported in this predicate"]
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object> { input in
                do {
                    let foo = "hello"
                    return true
                }
            }
            """,
            diagnostics: ["4:9: Predicate body may only contain one expression"]
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object> { input in
                do {
                    return input
                }
            }
            """,
            """
            \(foundationModuleName).Predicate<Object>({ input in
                return PredicateExpressions.build_Arg(
                    input
                )
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object> { input in
                do {
                    return true
                } while true
            }
            """,
            diagnostics: ["4:7: Predicate body may only contain one expression"]
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object> { input in
                switch input {
                default: return true
                }
            }
            """,
            diagnostics: ["2:5: Switch expressions are not supported in this predicate"]
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object> { input in
                do {
                    return try input.foo
                } catch {
                    return false
                }
            }
            """,
            diagnostics: ["4:7: Catch clauses are not supported in this predicate"]
        )
    }
}
