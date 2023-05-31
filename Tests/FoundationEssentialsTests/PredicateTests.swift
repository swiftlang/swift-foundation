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

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
final class PredicateTests: XCTestCase {
    
    struct Object {
        var a: Int
        var b: String
        var c: Double
        var d: Int
        var e: Character
        var f: Bool
        var g: [Int]
    }
    
    struct Object2 {
        var a: Bool
    }
    
    func testBasic() throws {
        let compareTo = 2
        let predicate = Predicate<Object> {
            // $0.a == compareTo
            PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_Arg(
                    PredicateExpressions.build_KeyPath(
                        root: $0,
                        keyPath: \.a
                    )
                ),
                rhs: PredicateExpressions.build_Arg(compareTo)
            )
        }
        try XCTAssertFalse(predicate.evaluate(Object(a: 1, b: "", c: 0, d: 0, e: "c", f: true, g: [])))
        try XCTAssertTrue(predicate.evaluate(Object(a: 2, b: "", c: 0, d: 0, e: "c", f: true, g: [])))
    }
    
    #if false // TODO: Re-enable with Variadic Generics
    func testVariable() throws {
        let variable = PredicateExpressions.Variable<Int>()
        let predicate = Predicate<Object> {
            // $0.a == variable + 1
            PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_Arg(
                    PredicateExpressions.build_KeyPath(
                        root: $0,
                        keyPath: \.a
                    )
                ),
                rhs: PredicateExpressions.build_Arg(
                    PredicateExpressions.build_Arithmetic(
                        lhs: PredicateExpressions.build_Arg(variable),
                        rhs: PredicateExpressions.build_Arg(1),
                        op: .add
                    )
                )
            )
        }
        XCTAssert(try predicate.evaluate(Object(a: 3, b: "", c: 0, d: 0, e: "c", f: true, g: []), bindings: PredicateBindings().binding(variable, to: 2)))
    }
    #endif
    
    func testArithmetic() throws {
        let predicate = Predicate<Object> {
            // $0.a + 2 == 4
            PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_Arg(
                    PredicateExpressions.build_Arithmetic(
                        lhs: PredicateExpressions.build_Arg(
                            PredicateExpressions.build_KeyPath(
                                root: $0,
                                keyPath: \.a
                            )
                        ),
                        rhs: PredicateExpressions.build_Arg(2),
                        op: .add
                    )
                ),
                rhs: PredicateExpressions.build_Arg(4)
            )
        }
        XCTAssert(try predicate.evaluate(Object(a: 2, b: "", c: 0, d: 0, e: "c", f: true, g: [])))
    }
    
    func testDivision() throws {
        let predicate = Predicate<Object> {
            // $0.a / 2 == 3
            PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_Arg(
                    PredicateExpressions.build_Division(
                        lhs: PredicateExpressions.build_Arg(
                            PredicateExpressions.build_KeyPath(
                                root: $0,
                                keyPath: \.a
                            )
                        ),
                        rhs: PredicateExpressions.build_Arg(2)
                    )
                ),
                rhs: PredicateExpressions.build_Arg(3)
            )
        }
        let predicate2 = Predicate<Object> {
            // $0.c / 2.1 <= 3.0
            PredicateExpressions.build_Comparison(
                lhs: PredicateExpressions.build_Arg(
                    PredicateExpressions.build_Division(
                        lhs: PredicateExpressions.build_Arg(
                            PredicateExpressions.build_KeyPath(
                                root: $0,
                                keyPath: \.c
                            )
                        ),
                        rhs: PredicateExpressions.build_Arg(2.1)
                    )
                ),
                rhs: PredicateExpressions.build_Arg(3.0),
                op: .lessThanOrEqual
            )
        }
        XCTAssert(try predicate.evaluate(Object(a: 6, b: "", c: 0, d: 0, e: "c", f: true, g: [])))
        XCTAssert(try predicate2.evaluate(Object(a: 2, b: "", c: 6.0, d: 0, e: "c", f: true, g: [])))
    }
    
    func testBuildDivision() throws {
        let predicate = Predicate<Object> {
            PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_Arg(
                    PredicateExpressions.build_Division(
                        lhs: PredicateExpressions.build_Arg(
                            PredicateExpressions.build_KeyPath(
                                root: $0,
                                keyPath: \.a
                            )
                        ),
                        rhs: PredicateExpressions.build_Arg(2)
                    )
                ),
                rhs: PredicateExpressions.build_Arg(3))
        }
        XCTAssert(try predicate.evaluate(Object(a: 6, b: "", c: 0, d: 0, e: "c", f: true, g: [])))
    }
    
    func testUnaryMinus() throws {
        let predicate = Predicate<Object> {
            // -$0.a == 17
            PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_Arg(
                    PredicateExpressions.build_UnaryMinus(
                        PredicateExpressions.build_Arg(
                            PredicateExpressions.build_KeyPath(
                                root: $0,
                                keyPath: \.a
                            )
                        )
                    )
                ),
                rhs: PredicateExpressions.build_Arg(17)
            )
        }
        XCTAssert(try predicate.evaluate(Object(a: -17, b: "", c: 0, d: 0, e: "c", f: true, g: [])))
    }
    
    func testCount() throws {
        let predicate = Predicate<Object> {
            // $0.g.count == 5
            PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_Arg(
                    PredicateExpressions.build_KeyPath(
                        root: PredicateExpressions.build_KeyPath(
                            root: $0,
                            keyPath: \.g
                        ),
                        keyPath: \.count
                    )
                ),
                rhs: PredicateExpressions.build_Arg(5)
            )
        }
        XCTAssert(try predicate.evaluate(Object(a: 0, b: "", c: 0, d: 0, e: "c", f: true, g: [2, 3, 5, 7, 11])))
    }
    
    func testFilter() throws {
        let predicate = Predicate<Object> { object in
            /*object.g.filter {
                $0 == object.d
            }.count > 0*/
            
            PredicateExpressions.build_Comparison(
                lhs: PredicateExpressions.build_Arg(
                    PredicateExpressions.build_KeyPath(
                        root: PredicateExpressions.build_filter(
                            PredicateExpressions.build_Arg(
                                PredicateExpressions.build_KeyPath(
                                    root: object,
                                    keyPath: \.g
                                )
                            ),
                            {
                                PredicateExpressions.build_Equal(
                                    lhs: PredicateExpressions.build_Arg($0),
                                    rhs: PredicateExpressions.build_Arg(
                                        PredicateExpressions.build_KeyPath(
                                            root: object,
                                            keyPath: \.d
                                        )
                                    )
                                )
                            }
                        ),
                        keyPath: \.count
                    )
                ),
                rhs: PredicateExpressions.build_Arg(0),
                op: .greaterThan
            )
        }
        XCTAssert(try predicate.evaluate(Object(a: 0, b: "", c: 0.0, d: 17, e: "c", f: true, g: [3, 5, 7, 11, 13, 17, 19])))
    }
    
    func testContains() throws {
        let predicate = Predicate<Object> {
            // $0.g.contains($0.a)
            PredicateExpressions.build_contains(
                PredicateExpressions.build_Arg(
                    PredicateExpressions.build_KeyPath(
                        root: $0,
                        keyPath: \.g
                    )
                ),
                PredicateExpressions.build_Arg(
                    PredicateExpressions.build_KeyPath(
                        root: $0,
                        keyPath: \.a
                    )
                )
            )
        }
        XCTAssert(try predicate.evaluate(Object(a: 13, b: "", c: 0.0, d: 0, e: "c", f: true, g: [2, 3, 5, 11, 13, 17])))
    }
    
    func testContainsWhere() throws {
        let predicate = Predicate<Object> { object in
            // object.g.contains { $0 % object.a == 0 }
            PredicateExpressions.build_contains(
                PredicateExpressions.build_Arg(
                    PredicateExpressions.build_KeyPath(
                        root: object,
                        keyPath: \.g
                    )
                ),
                where: {
                    PredicateExpressions.build_Equal(
                        lhs: PredicateExpressions.build_Arg(
                            PredicateExpressions.build_Remainder(
                                lhs: PredicateExpressions.build_Arg($0),
                                rhs: PredicateExpressions.build_Arg(
                                    PredicateExpressions.build_KeyPath(
                                        root: object,
                                        keyPath: \.a
                                    )
                                )
                            )
                        ),
                        rhs: PredicateExpressions.build_Arg(0)
                    )
                }
            )
        }
        XCTAssert(try predicate.evaluate(Object(a: 2, b: "", c: 0.0, d: 0, e: "c", f: true, g: [3, 5, 7, 2, 11, 13])))
    }
    
    func testAllSatisfy() throws {
        let predicate = Predicate<Object> { object in
            // object.g.allSatisfy { $0 % object.d != 0 }
            PredicateExpressions.build_allSatisfy(
                PredicateExpressions.build_Arg(
                    PredicateExpressions.build_KeyPath(
                        root: object,
                        keyPath: \.g
                    )
                ),
                {
                    PredicateExpressions.build_NotEqual(
                        lhs: PredicateExpressions.build_Arg(
                            PredicateExpressions.build_Remainder(
                                lhs: PredicateExpressions.build_Arg($0),
                                rhs: PredicateExpressions.build_Arg(
                                    PredicateExpressions.build_KeyPath(
                                        root: object,
                                        keyPath: \.d
                                    )
                                )
                            )
                        ),
                        rhs: PredicateExpressions.build_Arg(0)
                    )
                }
            )
        }
        XCTAssert(try predicate.evaluate(Object(a: 0, b: "", c: 0.0, d: 2, e: "c", f: true, g: [3, 5, 7, 11, 13, 17, 19])))
    }
    
    func testOptional() throws {
        struct Wrapper<T> {
            let wrapped: T?
        }
        let predicate = Predicate<Wrapper<Int>> {
//            ($0.wrapped.flatMap { $0 + 1 } ?? 7) % 2 == 1
            PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_Arg(
                    PredicateExpressions.build_Remainder(
                        lhs: PredicateExpressions.build_Arg(
                            PredicateExpressions.build_NilCoalesce(
                                lhs: PredicateExpressions.build_Arg(
                                    PredicateExpressions.build_flatMap(
                                        PredicateExpressions.build_Arg(
                                            PredicateExpressions.build_KeyPath(
                                                root: $0,
                                                keyPath: \.wrapped
                                            )
                                        ),
                                        {
                                            PredicateExpressions.build_Arithmetic(
                                                lhs: PredicateExpressions.build_Arg($0),
                                                rhs: PredicateExpressions.build_Arg(1),
                                                op: .add
                                            )
                                        }
                                    )
                                ),
                                rhs: PredicateExpressions.build_Arg(7)
                            )
                        ),
                        rhs: PredicateExpressions.build_Arg(2)
                    )
                ),
                rhs: PredicateExpressions.build_Arg(1))
        }
        let predicate2 = Predicate<Wrapper<Int>> {
//          $0.wrapped! == 19
            PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_Arg(
                    PredicateExpressions.build_ForcedUnwrap(
                        lhs: PredicateExpressions.build_KeyPath(
                            root: $0,
                            keyPath: \.wrapped
                        )
                    )
                ),
                rhs: PredicateExpressions.build_Arg(
                    19
                )
            )
        }
        XCTAssert(try predicate.evaluate(Wrapper<Int>(wrapped: 4)))
        XCTAssert(try predicate.evaluate(Wrapper<Int>(wrapped: nil)))
        XCTAssert(try predicate2.evaluate(Wrapper<Int>(wrapped: 19)))
        XCTAssertThrowsError(try predicate2.evaluate(Wrapper<Int>(wrapped: nil)))
        
    }
    
    #if false // TODO: Re-enable with Variadic Generics
    func testConditional() throws {
        let v1 = PredicateExpressions.Variable<String>()
        let v2 = PredicateExpressions.Variable<String>()
        let predicate = Predicate<Bool> {
            // ($0 ? v1 : v2) == "if branch"
            PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_Arg(
                    PredicateExpressions.build_Conditional(
                        $0,
                        PredicateExpressions.build_Arg(v1),
                        PredicateExpressions.build_Arg(v2)
                    )
                ),
                rhs: PredicateExpressions.build_Arg("if branch")
            )
        }
        XCTAssert(try predicate.evaluate(true, bindings: PredicateBindings().binding(v1, to: "if branch").binding(v2, to: "else branch")))
    }
    #endif
    
    func testClosedRange() throws {
        let predicate = Predicate<Object> {
            // (3...5).contains($0.a)
            PredicateExpressions.build_contains(
                PredicateExpressions.build_Arg(
                    PredicateExpressions.build_ClosedRange(
                        lower: PredicateExpressions.build_Arg(3),
                        upper: PredicateExpressions.build_Arg(5)
                    )
                ),
                PredicateExpressions.build_Arg(
                    PredicateExpressions.build_KeyPath(
                        root: $0,
                        keyPath: \.a
                    )
                )
            )
        }
        let predicate2 = Predicate<Object> {
            // ($0.a...$0.d).contains(4)
            PredicateExpressions.build_contains(
                PredicateExpressions.build_Arg(
                    PredicateExpressions.build_ClosedRange(
                        lower: PredicateExpressions.build_Arg(
                            PredicateExpressions.build_KeyPath(
                                root: $0,
                                keyPath: \.a
                            )
                        ),
                        upper: PredicateExpressions.build_Arg(
                            PredicateExpressions.build_KeyPath(
                                root: $0,
                                keyPath: \.d
                            )
                        )
                    )
                ),
                PredicateExpressions.build_Arg(4)
            )
        }
        XCTAssert(try predicate.evaluate(Object(a: 4, b: "", c: 0.0, d: 0, e: "c", f: true, g: [])))
        XCTAssert(try predicate2.evaluate(Object(a: 3, b: "", c: 0.0, d: 5, e: "c", f: true, g: [])))
    }
    
    func testRange() throws {
        let predicate = Predicate<Object> {
            // (3..<5).contains($0.a)
            PredicateExpressions.build_contains(
                PredicateExpressions.build_Arg(
                    PredicateExpressions.build_Range(
                        lower: PredicateExpressions.build_Arg(3),
                        upper: PredicateExpressions.build_Arg(5)
                    )
                ),
                PredicateExpressions.build_Arg(
                    PredicateExpressions.build_KeyPath(
                        root: $0,
                        keyPath: \.a
                    )
                )
            )
        }
        let toMatch = 4
        let predicate2 = Predicate<Object> {
            // ($0.a..<$0.d).contains(toMatch)
            PredicateExpressions.build_contains(
                PredicateExpressions.build_Arg(
                    PredicateExpressions.build_Range(
                        lower: PredicateExpressions.build_Arg(
                            PredicateExpressions.build_KeyPath(
                                root: $0,
                                keyPath: \.a
                            )
                        ),
                        upper: PredicateExpressions.build_Arg(
                            PredicateExpressions.build_KeyPath(
                                root: $0,
                                keyPath: \.d
                            )
                        )
                    )
                ),
                PredicateExpressions.build_Arg(toMatch)
            )
        }
        XCTAssert(try predicate.evaluate(Object(a: 4, b: "", c: 0.0, d: 0, e: "c", f: true, g: [])))
        XCTAssert(try predicate2.evaluate(Object(a: 3, b: "", c: 0.0, d: 5, e: "c", f: true, g: [])))
    }
    
    func testTypes() throws {
        let predicate = Predicate<Object> {
            // ($0.a as? Int).flatMap { $0 == 3 } ?? false
            PredicateExpressions.build_NilCoalesce(
                lhs: PredicateExpressions.build_Arg(
                    PredicateExpressions.build_flatMap(
                        PredicateExpressions.build_Arg(
                            PredicateExpressions.ConditionalCast<_, Int>(
                                PredicateExpressions.build_Arg(
                                    PredicateExpressions.build_KeyPath(
                                        root: $0,
                                        keyPath: \.a
                                    )
                                )
                            )
                        ),
                        {
                            PredicateExpressions.build_Equal(
                                lhs: PredicateExpressions.build_Arg($0),
                                rhs: PredicateExpressions.build_Arg(3)
                            )
                        }
                    )
                ),
                rhs: PredicateExpressions.build_Arg(false)
            )
        }
        let predicate2 = Predicate<Object> {
            // $0.a is BinaryInteger
            PredicateExpressions.TypeCheck<_, BinaryInteger>(
                PredicateExpressions.build_Arg(
                    PredicateExpressions.build_KeyPath(
                        root: $0,
                        keyPath: \.a
                    )
                )
            )
        }
        XCTAssert(try predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [])))
        XCTAssert(try predicate2.evaluate(Object(a: 3, b: "", c: 0.0, d: 5, e: "c", f: true, g: [])))
    }
    
    func testSubscripts() throws {
        var predicate = Predicate<Object> {
            // $0.g[0] == 0
            PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_subscript(
                    PredicateExpressions.build_KeyPath(
                        root: PredicateExpressions.build_Arg($0),
                        keyPath: \.g
                    ),
                    PredicateExpressions.build_Arg(0)
                ),
                rhs: PredicateExpressions.build_Arg(0)
            )
        }
        
        XCTAssertTrue(try predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [0])))
        XCTAssertFalse(try predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [1])))
        XCTAssertThrowsError(try predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [])))
        
        predicate = Predicate<Object> {
            // $0.g[0 ..< 2].isEmpty
            PredicateExpressions.build_KeyPath(
                root: PredicateExpressions.build_subscript(
                    PredicateExpressions.build_KeyPath(
                        root: PredicateExpressions.build_Arg($0),
                        keyPath: \.g
                    ),
                    PredicateExpressions.build_Range(
                        lower: PredicateExpressions.build_Arg(0),
                        upper: PredicateExpressions.build_Arg(2))
                ),
                keyPath: \.isEmpty
            )
        }
        
        XCTAssertFalse(try predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [0, 1, 2])))
        XCTAssertFalse(try predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [0, 1])))
        XCTAssertThrowsError(try predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [0])))
        XCTAssertThrowsError(try predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [])))
    }
    
    func testStaticValues() throws {
        func assertPredicate<T>(_ pred: Predicate<T>, value: T, expected: Bool) throws {
            XCTAssertEqual(try pred.evaluate(value), expected)
        }
        
        try assertPredicate(.true, value: "Hello", expected: true)
        try assertPredicate(.false, value: "Hello", expected: false)
    }
}
