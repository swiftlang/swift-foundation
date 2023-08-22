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

import XCTest

final class PredicateMacroLanguageOperatorTests: XCTestCase {
    func testEqual() {
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                inputA == inputB
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ inputA, inputB in
                PredicateExpressions.build_Equal(
                    lhs: PredicateExpressions.build_Arg(inputA),
                    rhs: PredicateExpressions.build_Arg(inputB)
                )
            })
            """
        )
    }
    
    func testEqualExplicitReturn() {
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                return inputA == inputB
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ inputA, inputB in
                return PredicateExpressions.build_Equal(
                    lhs: PredicateExpressions.build_Arg(inputA),
                    rhs: PredicateExpressions.build_Arg(inputB)
                )
            })
            """
        )
    }
    
    func testNotEqual() {
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                inputA != inputB
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ inputA, inputB in
                PredicateExpressions.build_NotEqual(
                    lhs: PredicateExpressions.build_Arg(inputA),
                    rhs: PredicateExpressions.build_Arg(inputB)
                )
            })
            """
        )
    }
    
    func testComparison() {
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                inputA < inputB
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ inputA, inputB in
                PredicateExpressions.build_Comparison(
                    lhs: PredicateExpressions.build_Arg(inputA),
                    rhs: PredicateExpressions.build_Arg(inputB),
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
                PredicateExpressions.build_Comparison(
                    lhs: PredicateExpressions.build_Arg(inputA),
                    rhs: PredicateExpressions.build_Arg(inputB),
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
                PredicateExpressions.build_Comparison(
                    lhs: PredicateExpressions.build_Arg(inputA),
                    rhs: PredicateExpressions.build_Arg(inputB),
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
                PredicateExpressions.build_Comparison(
                    lhs: PredicateExpressions.build_Arg(inputA),
                    rhs: PredicateExpressions.build_Arg(inputB),
                    op: .greaterThanOrEqual
                )
            })
            """
        )
    }
    
    func testConjunction() {
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                inputA && inputB
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ inputA, inputB in
                PredicateExpressions.build_Conjunction(
                    lhs: PredicateExpressions.build_Arg(inputA),
                    rhs: PredicateExpressions.build_Arg(inputB)
                )
            })
            """
        )
    }
    
    func testDisjunction() {
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                inputA || inputB
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ inputA, inputB in
                PredicateExpressions.build_Disjunction(
                    lhs: PredicateExpressions.build_Arg(inputA),
                    rhs: PredicateExpressions.build_Arg(inputB)
                )
            })
            """
        )
    }
    
    func testArithmetic() {
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                inputA + inputB
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ inputA, inputB in
                PredicateExpressions.build_Arithmetic(
                    lhs: PredicateExpressions.build_Arg(inputA),
                    rhs: PredicateExpressions.build_Arg(inputB),
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
                PredicateExpressions.build_Arithmetic(
                    lhs: PredicateExpressions.build_Arg(inputA),
                    rhs: PredicateExpressions.build_Arg(inputB),
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
                PredicateExpressions.build_Arithmetic(
                    lhs: PredicateExpressions.build_Arg(inputA),
                    rhs: PredicateExpressions.build_Arg(inputB),
                    op: .multiply
                )
            })
            """
        )
    }
    
    func testDivision() {
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                inputA / inputB
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ inputA, inputB in
                PredicateExpressions.build_Division(
                    lhs: PredicateExpressions.build_Arg(inputA),
                    rhs: PredicateExpressions.build_Arg(inputB)
                )
            })
            """
        )
    }
    
    func testRemainder() {
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                inputA % inputB
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ inputA, inputB in
                PredicateExpressions.build_Remainder(
                    lhs: PredicateExpressions.build_Arg(inputA),
                    rhs: PredicateExpressions.build_Arg(inputB)
                )
            })
            """
        )
    }
    
    func testNegation() {
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                !inputA
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ inputA, inputB in
                PredicateExpressions.build_Negation(
                    PredicateExpressions.build_Arg(inputA)
                )
            })
            """
        )
    }
    
    func testUnaryMinus() {
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                -inputA
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ inputA, inputB in
                PredicateExpressions.build_UnaryMinus(
                    PredicateExpressions.build_Arg(inputA)
                )
            })
            """
        )
    }
    
    func testNilCoalesce() {
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                inputA ?? inputB
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ inputA, inputB in
                PredicateExpressions.build_NilCoalesce(
                    lhs: PredicateExpressions.build_Arg(inputA),
                    rhs: PredicateExpressions.build_Arg(inputB)
                )
            })
            """
        )
    }
    
    func testRanges() {
        AssertPredicateExpansion(
            """
            #Predicate<Object, Object> { inputA, inputB in
                inputA ..< inputB
            }
            """,
            """
            \(foundationModuleName).Predicate<Object, Object>({ inputA, inputB in
                PredicateExpressions.build_Range(
                    lower: PredicateExpressions.build_Arg(inputA),
                    upper: PredicateExpressions.build_Arg(inputB)
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
                PredicateExpressions.build_ClosedRange(
                    lower: PredicateExpressions.build_Arg(inputA),
                    upper: PredicateExpressions.build_Arg(inputB)
                )
            })
            """
        )
    }
    
    func testOptionalChaining() {
        AssertPredicateExpansion(
            """
            #Predicate<Object?> { inputA in
                inputA?.foo
            }
            """,
            """
            \(foundationModuleName).Predicate<Object?>({ inputA in
                PredicateExpressions.build_flatMap(
                    PredicateExpressions.build_Arg(inputA)
                ) {
                    PredicateExpressions.build_KeyPath(
                        root: PredicateExpressions.build_Arg($0),
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
                PredicateExpressions.build_flatMap(
                    PredicateExpressions.build_Arg(inputA)
                ) {
                    PredicateExpressions.build_KeyPath(
                        root: PredicateExpressions.build_Arg($0),
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
                PredicateExpressions.build_flatMap(
                    PredicateExpressions.build_KeyPath(
                        root: PredicateExpressions.build_Arg(inputA),
                        keyPath: \\.foo
                    )
                ) {
                    PredicateExpressions.build_KeyPath(
                        root: PredicateExpressions.build_Arg($0),
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
                PredicateExpressions.build_flatMap(
                    PredicateExpressions.build_flatMap(
                        PredicateExpressions.build_Arg(inputA)
                    ) {
                        PredicateExpressions.build_KeyPath(
                            root: PredicateExpressions.build_Arg($0),
                            keyPath: \\.foo
                        )
                    }
                ) {
                    PredicateExpressions.build_KeyPath(
                        root: PredicateExpressions.build_Arg($0),
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
                PredicateExpressions.build_flatMap(
                    PredicateExpressions.build_KeyPath(
                        root: PredicateExpressions.build_Arg(inputA),
                        keyPath: \\.foo
                    )
                ) {
                    PredicateExpressions.build_contains(
                        PredicateExpressions.build_Arg($0),
                        PredicateExpressions.build_Arg(0)
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
                PredicateExpressions.build_NilCoalesce(
                    lhs: PredicateExpressions.build_flatMap(
                        PredicateExpressions.build_Arg($0)
                    ) {
                        PredicateExpressions.build_contains(
                            PredicateExpressions.build_Arg($0)
                        ) {
                            PredicateExpressions.build_Equal(
                                lhs: PredicateExpressions.build_Arg($0),
                                rhs: PredicateExpressions.build_Arg("Test")
                            )
                        }
                    },
                    rhs: PredicateExpressions.build_Arg(true)
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
                PredicateExpressions.build_allSatisfy(
                    PredicateExpressions.build_Arg(objects)
                ) {
                    PredicateExpressions.build_Equal(
                        lhs: PredicateExpressions.build_flatMap(
                            PredicateExpressions.build_Arg($0)
                        ) {
                            PredicateExpressions.build_KeyPath(
                                root: PredicateExpressions.build_Arg($0),
                                keyPath: \\.bar
                            )
                        },
                        rhs: PredicateExpressions.build_Arg(2)
                    )
                }
            })
            """
        )
    }
    
    func testForceUnwrap() {
        AssertPredicateExpansion(
            """
            #Predicate<Object?> { inputA in
                inputA!.foo
            }
            """,
            """
            \(foundationModuleName).Predicate<Object?>({ inputA in
                PredicateExpressions.build_KeyPath(
                    root: PredicateExpressions.build_ForcedUnwrap(
                        PredicateExpressions.build_Arg(inputA)
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
                PredicateExpressions.build_KeyPath(
                    root: PredicateExpressions.build_ForcedUnwrap(
                        PredicateExpressions.build_KeyPath(
                            root: PredicateExpressions.build_Arg(inputA),
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
                PredicateExpressions.build_KeyPath(
                    root: PredicateExpressions.build_ForcedUnwrap(
                        PredicateExpressions.build_KeyPath(
                            root: PredicateExpressions.build_ForcedUnwrap(
                                PredicateExpressions.build_Arg(inputA)
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
                PredicateExpressions.build_contains(
                    PredicateExpressions.build_ForcedUnwrap(
                        PredicateExpressions.build_KeyPath(
                            root: PredicateExpressions.build_Arg(inputA),
                            keyPath: \\.foo
                        )
                    ),
                    PredicateExpressions.build_Arg(0)
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
                PredicateExpressions.build_flatMap(
                    PredicateExpressions.build_KeyPath(
                        root: PredicateExpressions.build_ForcedUnwrap(
                            PredicateExpressions.build_Arg(inputA)
                        ),
                        keyPath: \\.foo
                    )
                ) {
                    PredicateExpressions.build_KeyPath(
                        root: PredicateExpressions.build_Arg($0),
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
                PredicateExpressions.build_flatMap(
                    PredicateExpressions.build_Arg(inputA)
                ) {
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
            })
            """
        )
    }
    
    func testDiagnoseUnknownOperator() {
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
