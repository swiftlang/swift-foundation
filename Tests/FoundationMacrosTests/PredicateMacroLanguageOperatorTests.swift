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

@Suite("#Predicate Macro Language Operators")
private struct PredicateMacroLanguageOperatorTests {
    @Test func equal() {
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                inputA == inputB
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ inputA, inputB in
                PredicateExpressions.\(foundationModuleName)::build_Equal(
                    lhs: PredicateExpressions.\(foundationModuleName)::build_Arg(inputA),
                    rhs: PredicateExpressions.\(foundationModuleName)::build_Arg(inputB)
                )
            })
            """
        )
    }
    
    @Test func equalExplicitReturn() {
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                return inputA == inputB
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ inputA, inputB in
                return PredicateExpressions.\(foundationModuleName)::build_Equal(
                    lhs: PredicateExpressions.\(foundationModuleName)::build_Arg(inputA),
                    rhs: PredicateExpressions.\(foundationModuleName)::build_Arg(inputB)
                )
            })
            """
        )
    }
    
    @Test func notEqual() {
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                inputA != inputB
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ inputA, inputB in
                PredicateExpressions.\(foundationModuleName)::build_NotEqual(
                    lhs: PredicateExpressions.\(foundationModuleName)::build_Arg(inputA),
                    rhs: PredicateExpressions.\(foundationModuleName)::build_Arg(inputB)
                )
            })
            """
        )
    }
    
    @Test func comparison() {
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                inputA < inputB
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ inputA, inputB in
                PredicateExpressions.\(foundationModuleName)::build_Comparison(
                    lhs: PredicateExpressions.\(foundationModuleName)::build_Arg(inputA),
                    rhs: PredicateExpressions.\(foundationModuleName)::build_Arg(inputB),
                    op: .lessThan
                )
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                inputA <= inputB
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ inputA, inputB in
                PredicateExpressions.\(foundationModuleName)::build_Comparison(
                    lhs: PredicateExpressions.\(foundationModuleName)::build_Arg(inputA),
                    rhs: PredicateExpressions.\(foundationModuleName)::build_Arg(inputB),
                    op: .lessThanOrEqual
                )
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                inputA > inputB
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ inputA, inputB in
                PredicateExpressions.\(foundationModuleName)::build_Comparison(
                    lhs: PredicateExpressions.\(foundationModuleName)::build_Arg(inputA),
                    rhs: PredicateExpressions.\(foundationModuleName)::build_Arg(inputB),
                    op: .greaterThan
                )
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                inputA >= inputB
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ inputA, inputB in
                PredicateExpressions.\(foundationModuleName)::build_Comparison(
                    lhs: PredicateExpressions.\(foundationModuleName)::build_Arg(inputA),
                    rhs: PredicateExpressions.\(foundationModuleName)::build_Arg(inputB),
                    op: .greaterThanOrEqual
                )
            })
            """
        )
    }
    
    @Test func conjunction() {
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                inputA && inputB
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ inputA, inputB in
                PredicateExpressions.\(foundationModuleName)::build_Conjunction(
                    lhs: PredicateExpressions.\(foundationModuleName)::build_Arg(inputA),
                    rhs: PredicateExpressions.\(foundationModuleName)::build_Arg(inputB)
                )
            })
            """
        )
    }
    
    @Test func disjunction() {
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                inputA || inputB
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ inputA, inputB in
                PredicateExpressions.\(foundationModuleName)::build_Disjunction(
                    lhs: PredicateExpressions.\(foundationModuleName)::build_Arg(inputA),
                    rhs: PredicateExpressions.\(foundationModuleName)::build_Arg(inputB)
                )
            })
            """
        )
    }
    
    @Test func arithmetic() {
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                inputA + inputB
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ inputA, inputB in
                PredicateExpressions.\(foundationModuleName)::build_Arithmetic(
                    lhs: PredicateExpressions.\(foundationModuleName)::build_Arg(inputA),
                    rhs: PredicateExpressions.\(foundationModuleName)::build_Arg(inputB),
                    op: .add
                )
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                inputA - inputB
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ inputA, inputB in
                PredicateExpressions.\(foundationModuleName)::build_Arithmetic(
                    lhs: PredicateExpressions.\(foundationModuleName)::build_Arg(inputA),
                    rhs: PredicateExpressions.\(foundationModuleName)::build_Arg(inputB),
                    op: .subtract
                )
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                inputA * inputB
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ inputA, inputB in
                PredicateExpressions.\(foundationModuleName)::build_Arithmetic(
                    lhs: PredicateExpressions.\(foundationModuleName)::build_Arg(inputA),
                    rhs: PredicateExpressions.\(foundationModuleName)::build_Arg(inputB),
                    op: .multiply
                )
            })
            """
        )
    }
    
    @Test func division() {
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                inputA / inputB
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ inputA, inputB in
                PredicateExpressions.\(foundationModuleName)::build_Division(
                    lhs: PredicateExpressions.\(foundationModuleName)::build_Arg(inputA),
                    rhs: PredicateExpressions.\(foundationModuleName)::build_Arg(inputB)
                )
            })
            """
        )
    }
    
    @Test func remainder() {
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                inputA % inputB
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ inputA, inputB in
                PredicateExpressions.\(foundationModuleName)::build_Remainder(
                    lhs: PredicateExpressions.\(foundationModuleName)::build_Arg(inputA),
                    rhs: PredicateExpressions.\(foundationModuleName)::build_Arg(inputB)
                )
            })
            """
        )
    }
    
    @Test func negation() {
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                !inputA
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ inputA, inputB in
                PredicateExpressions.\(foundationModuleName)::build_Negation(
                    PredicateExpressions.\(foundationModuleName)::build_Arg(inputA)
                )
            })
            """
        )
    }
    
    @Test func unaryMinus() {
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                -inputA
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ inputA, inputB in
                PredicateExpressions.\(foundationModuleName)::build_UnaryMinus(
                    PredicateExpressions.\(foundationModuleName)::build_Arg(inputA)
                )
            })
            """
        )
    }
    
    @Test func nilCoalesce() {
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                inputA ?? inputB
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ inputA, inputB in
                PredicateExpressions.\(foundationModuleName)::build_NilCoalesce(
                    lhs: PredicateExpressions.\(foundationModuleName)::build_Arg(inputA),
                    rhs: PredicateExpressions.\(foundationModuleName)::build_Arg(inputB)
                )
            })
            """
        )
    }
    
    @Test func ranges() {
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                inputA ..< inputB
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ inputA, inputB in
                PredicateExpressions.\(foundationModuleName)::build_Range(
                    lower: PredicateExpressions.\(foundationModuleName)::build_Arg(inputA),
                    upper: PredicateExpressions.\(foundationModuleName)::build_Arg(inputB)
                )
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                inputA ... inputB
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ inputA, inputB in
                PredicateExpressions.\(foundationModuleName)::build_ClosedRange(
                    lower: PredicateExpressions.\(foundationModuleName)::build_Arg(inputA),
                    upper: PredicateExpressions.\(foundationModuleName)::build_Arg(inputB)
                )
            })
            """
        )
    }
    
    @Test func optionalChaining() {
        AssertPredicateExpansion(
            """
            #Predicate<Object?> { inputA in
                inputA?.foo
            }
            """,
            """
            \(foundationModuleName).Predicate<Object?>({ inputA in
                PredicateExpressions.\(foundationModuleName)::build_flatMap(
                    PredicateExpressions.\(foundationModuleName)::build_Arg(inputA)
                ) {
                    PredicateExpressions.\(foundationModuleName)::build_KeyPath(
                        root: PredicateExpressions.\(foundationModuleName)::build_Arg($0),
                        keyPath: \\.foo
                    )
                }
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object?> { inputA in
                inputA.flatMap {
                    $0.foo
                }
            }
            """,
            """
            \(foundationModuleName).Predicate<Object?>({ inputA in
                PredicateExpressions.\(foundationModuleName)::build_flatMap(
                    PredicateExpressions.\(foundationModuleName)::build_Arg(inputA)
                ) {
                    PredicateExpressions.\(foundationModuleName)::build_KeyPath(
                        root: PredicateExpressions.\(foundationModuleName)::build_Arg($0),
                        keyPath: \\.foo
                    )
                }
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object> { inputA in
                inputA.foo?.bar
            }
            """,
            """
            \(foundationModuleName).Predicate<Object>({ inputA in
                PredicateExpressions.\(foundationModuleName)::build_flatMap(
                    PredicateExpressions.\(foundationModuleName)::build_KeyPath(
                        root: PredicateExpressions.\(foundationModuleName)::build_Arg(inputA),
                        keyPath: \\.foo
                    )
                ) {
                    PredicateExpressions.\(foundationModuleName)::build_KeyPath(
                        root: PredicateExpressions.\(foundationModuleName)::build_Arg($0),
                        keyPath: \\.bar
                    )
                }
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object?> { inputA in
                inputA?.foo?.bar
            }
            """,
            """
            \(foundationModuleName).Predicate<Object?>({ inputA in
                PredicateExpressions.\(foundationModuleName)::build_flatMap(
                    PredicateExpressions.\(foundationModuleName)::build_flatMap(
                        PredicateExpressions.\(foundationModuleName)::build_Arg(inputA)
                    ) {
                        PredicateExpressions.\(foundationModuleName)::build_KeyPath(
                            root: PredicateExpressions.\(foundationModuleName)::build_Arg($0),
                            keyPath: \\.foo
                        )
                    }
                ) {
                    PredicateExpressions.\(foundationModuleName)::build_KeyPath(
                        root: PredicateExpressions.\(foundationModuleName)::build_Arg($0),
                        keyPath: \\.bar
                    )
                }
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object> { inputA in
                inputA.foo?.contains(0)
            }
            """,
            """
            \(foundationModuleName).Predicate<Object>({ inputA in
                PredicateExpressions.\(foundationModuleName)::build_flatMap(
                    PredicateExpressions.\(foundationModuleName)::build_KeyPath(
                        root: PredicateExpressions.\(foundationModuleName)::build_Arg(inputA),
                        keyPath: \\.foo
                    )
                ) {
                    PredicateExpressions.\(foundationModuleName)::build_contains(
                        PredicateExpressions.\(foundationModuleName)::build_Arg($0),
                        PredicateExpressions.\(foundationModuleName)::build_Arg(0)
                    )
                }
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> {
                $0.foo?.contains($1)
            }
            """,
            diagnostics: ["2:11: Optional chaining is not supported here in this predicate. Use the flatMap(_:) function explicitly instead."]
        )
        
        // Ensure that operators that become nested in a flatMap due to optional chaining are folded correctly
        AssertPredicateExpansion(
            """
            #Predicate<Object?> {
                $0?.contains {
                    $0 == "Test"
                } ?? true
            }
            """,
            """
            \(foundationModuleName).Predicate<Object?>({
                PredicateExpressions.\(foundationModuleName)::build_NilCoalesce(
                    lhs: PredicateExpressions.\(foundationModuleName)::build_flatMap(
                        PredicateExpressions.\(foundationModuleName)::build_Arg($0)
                    ) {
                        PredicateExpressions.\(foundationModuleName)::build_contains(
                            PredicateExpressions.\(foundationModuleName)::build_Arg($0)
                        ) {
                            PredicateExpressions.\(foundationModuleName)::build_Equal(
                                lhs: PredicateExpressions.\(foundationModuleName)::build_Arg($0),
                                rhs: PredicateExpressions.\(foundationModuleName)::build_Arg("Test")
                            )
                        }
                    },
                    rhs: PredicateExpressions.\(foundationModuleName)::build_Arg(true)
                )
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<[Object?]> { objects in
                objects.allSatisfy {
                    $0?.bar == 2
                }
            }
            """,
            """
            \(foundationModuleName).Predicate<[Object?]>({ objects in
                PredicateExpressions.\(foundationModuleName)::build_allSatisfy(
                    PredicateExpressions.\(foundationModuleName)::build_Arg(objects)
                ) {
                    PredicateExpressions.\(foundationModuleName)::build_Equal(
                        lhs: PredicateExpressions.\(foundationModuleName)::build_flatMap(
                            PredicateExpressions.\(foundationModuleName)::build_Arg($0)
                        ) {
                            PredicateExpressions.\(foundationModuleName)::build_KeyPath(
                                root: PredicateExpressions.\(foundationModuleName)::build_Arg($0),
                                keyPath: \\.bar
                            )
                        },
                        rhs: PredicateExpressions.\(foundationModuleName)::build_Arg(2)
                    )
                }
            })
            """
        )
    }
    
    @Test func forceUnwrap() {
        AssertPredicateExpansion(
            """
            #Predicate<Object?> { inputA in
                inputA!.foo
            }
            """,
            """
            \(foundationModuleName).Predicate<Object?>({ inputA in
                PredicateExpressions.\(foundationModuleName)::build_KeyPath(
                    root: PredicateExpressions.\(foundationModuleName)::build_ForcedUnwrap(
                        PredicateExpressions.\(foundationModuleName)::build_Arg(inputA)
                    ),
                    keyPath: \\.foo
                )
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object> { inputA in
                inputA.foo!.bar
            }
            """,
            """
            \(foundationModuleName).Predicate<Object>({ inputA in
                PredicateExpressions.\(foundationModuleName)::build_KeyPath(
                    root: PredicateExpressions.\(foundationModuleName)::build_ForcedUnwrap(
                        PredicateExpressions.\(foundationModuleName)::build_KeyPath(
                            root: PredicateExpressions.\(foundationModuleName)::build_Arg(inputA),
                            keyPath: \\.foo
                        )
                    ),
                    keyPath: \\.bar
                )
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object?> { inputA in
                inputA!.foo!.bar
            }
            """,
            """
            \(foundationModuleName).Predicate<Object?>({ inputA in
                PredicateExpressions.\(foundationModuleName)::build_KeyPath(
                    root: PredicateExpressions.\(foundationModuleName)::build_ForcedUnwrap(
                        PredicateExpressions.\(foundationModuleName)::build_KeyPath(
                            root: PredicateExpressions.\(foundationModuleName)::build_ForcedUnwrap(
                                PredicateExpressions.\(foundationModuleName)::build_Arg(inputA)
                            ),
                            keyPath: \\.foo
                        )
                    ),
                    keyPath: \\.bar
                )
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object> { inputA in
                inputA.foo!.contains(0)
            }
            """,
            """
            \(foundationModuleName).Predicate<Object>({ inputA in
                PredicateExpressions.\(foundationModuleName)::build_contains(
                    PredicateExpressions.\(foundationModuleName)::build_ForcedUnwrap(
                        PredicateExpressions.\(foundationModuleName)::build_KeyPath(
                            root: PredicateExpressions.\(foundationModuleName)::build_Arg(inputA),
                            keyPath: \\.foo
                        )
                    ),
                    PredicateExpressions.\(foundationModuleName)::build_Arg(0)
                )
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object?> { inputA in
                inputA!.foo?.bar
            }
            """,
            """
            \(foundationModuleName).Predicate<Object?>({ inputA in
                PredicateExpressions.\(foundationModuleName)::build_flatMap(
                    PredicateExpressions.\(foundationModuleName)::build_KeyPath(
                        root: PredicateExpressions.\(foundationModuleName)::build_ForcedUnwrap(
                            PredicateExpressions.\(foundationModuleName)::build_Arg(inputA)
                        ),
                        keyPath: \\.foo
                    )
                ) {
                    PredicateExpressions.\(foundationModuleName)::build_KeyPath(
                        root: PredicateExpressions.\(foundationModuleName)::build_Arg($0),
                        keyPath: \\.bar
                    )
                }
            })
            """
        )
        
        AssertPredicateExpansion(
            """
            #Predicate<Object?> { inputA in
                inputA?.foo!.bar
            }
            """,
            """
            \(foundationModuleName).Predicate<Object?>({ inputA in
                PredicateExpressions.\(foundationModuleName)::build_flatMap(
                    PredicateExpressions.\(foundationModuleName)::build_Arg(inputA)
                ) {
                    PredicateExpressions.\(foundationModuleName)::build_KeyPath(
                        root: PredicateExpressions.\(foundationModuleName)::build_ForcedUnwrap(
                            PredicateExpressions.\(foundationModuleName)::build_KeyPath(
                                root: PredicateExpressions.\(foundationModuleName)::build_Arg($0),
                                keyPath: \\.foo
                            )
                        ),
                        keyPath: \\.bar
                    )
                }
            })
            """
        )
    }
    
    @Test func diagnoseUnknownOperator() {
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                inputA & inputB
            }
            """,
            diagnostics: ["2:12: The '&' operator is not supported in this predicate"]
        )
    }
}
