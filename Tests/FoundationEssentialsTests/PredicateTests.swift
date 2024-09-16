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

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif FOUNDATION_FRAMEWORK
import Foundation
#endif

#if canImport(RegexBuilder)
import RegexBuilder
#endif

struct PredicateTests {
    struct Object {
        var a: Int = 1
        var b: String = ""
        var c: Double = 0.0
        var d: Int = 0
        var e: Character = "c"
        var f: Bool = true
        var g: [Int] = []
        var h: Date = .now
        var i: Any = 3
    }
    
    struct Object2 {
        var a: Bool = true
    }
    
    @available(FoundationPredicate 0.1, *)
    @Test func testBasic() throws {
        let compareTo = 2
        let predicate = #Predicate<Object> {
            $0.a == compareTo
        }
        #expect(try !predicate.evaluate(Object()))
        #expect(try predicate.evaluate(Object(a: 2)))
    }
    
    @available(FoundationPredicate 0.1, *)
    @Test func testVariadic() throws {
        let predicate = #Predicate<Object, Int> {
            $0.a == $1 + 1
        }
        #expect(try !predicate.evaluate(Object(), 2))
        #expect(try predicate.evaluate(Object(a: 3), 2))
    }
    
    @available(FoundationPredicate 0.1, *)
    @Test func testArithmetic() throws {
        let predicate = #Predicate<Object> {
            $0.a + 2 == 4
        }
        #expect(try predicate.evaluate(Object(a: 2)))
        #expect(try !predicate.evaluate(Object(a: 5)))
    }
    
    @available(FoundationPredicate 0.1, *)
    @Test func testDivision() throws {
        let predicate = #Predicate<Object> {
            $0.a / 2 == 3
        }
        let predicate2 = #Predicate<Object> {
            $0.c / 2.1 <= 3.0
        }
        #expect(try predicate.evaluate(Object(a: 6)))
        #expect(try !predicate.evaluate(Object(a: 8)))
        #expect(try predicate2.evaluate(Object(c: 6.0)))
    }
    
    @available(FoundationPredicate 0.1, *)
    @Test func testUnaryMinus() throws {
        let predicate = #Predicate<Object> {
            -$0.a == 17
        }
        #expect(try predicate.evaluate(Object(a: -17)))
        #expect(try !predicate.evaluate(Object(a: 17)))
    }
    
    @available(FoundationPredicate 0.1, *)
    @Test func testCount() throws {
        let predicate = #Predicate<Object> {
            $0.g.count == 5
        }
        #expect(try predicate.evaluate(Object(g: [2, 3, 5, 7, 11])))
        #expect(try !predicate.evaluate(Object(g: [2])))
    }
    
    @available(FoundationPredicate 0.1, *)
    @Test func testFilter() throws {
        let predicate = #Predicate<Object> { object in
            !object.g.filter {
                $0 == object.d
            }.isEmpty
        }
        #expect(try predicate.evaluate(Object(d: 17, g: [3, 5, 7, 11, 13, 17, 19])))
        #expect(try !predicate.evaluate(Object(d: 17, g: [3, 5, 7, 11, 13, 19])))
    }
    
    @available(FoundationPredicate 0.1, *)
    @Test func testContains() throws {
        let predicate = #Predicate<Object> {
            $0.g.contains($0.a)
        }
        #expect(try predicate.evaluate(Object(a: 13, g: [2, 3, 5, 11, 13, 17])))
        #expect(try !predicate.evaluate(Object(a: 12, g: [2, 3, 5, 11, 13, 17])))
    }
    
    @available(FoundationPredicate 0.1, *)
    @Test func testContainsWhere() throws {
        let predicate = #Predicate<Object> { object in
            object.g.contains {
                $0 % object.a == 0
            }
        }
        #expect(try predicate.evaluate(Object(a: 2, g: [3, 5, 7, 2, 11, 13])))
        #expect(try !predicate.evaluate(Object(a: 2, g: [3, 5, 7, 15, 11, 13])))
    }
    
    @available(FoundationPredicate 0.1, *)
    @Test func testAllSatisfy() throws {
        let predicate = #Predicate<Object> { object in
            object.g.allSatisfy {
                $0 % object.d != 0
            }
        }
        #expect(try predicate.evaluate(Object(d: 2, g: [3, 5, 7, 11, 13, 17, 19])))
        #expect(try !predicate.evaluate(Object(d: 5, g: [3, 5, 7, 11, 13, 17, 19])))
    }
    
    @available(FoundationPredicate 0.1, *)
    @Test func testOptional() throws {
        struct Wrapper<T> {
            let wrapped: T?
        }
        let predicate = #Predicate<Wrapper<Int>> {
            ($0.wrapped.flatMap { $0 + 1 } ?? 7) % 2 == 1
        }
        let predicate2 = #Predicate<Wrapper<Int>> {
            $0.wrapped! == 19
        }
        #expect(try predicate.evaluate(Wrapper<Int>(wrapped: 4)))
        #expect(try predicate.evaluate(Wrapper<Int>(wrapped: nil)))
        #expect(try predicate2.evaluate(Wrapper<Int>(wrapped: 19)))
        #expect(throws: PredicateError.forceUnwrapFailure) {
            try predicate2.evaluate(Wrapper<Int>(wrapped: nil))
        }
        
        struct _NonCodableType : Equatable {}
        let predicate3 = #Predicate<Wrapper<_NonCodableType>> {
            $0.wrapped == nil
        }
        #expect(try !predicate3.evaluate(Wrapper(wrapped: _NonCodableType())))
        #expect(try predicate3.evaluate(Wrapper(wrapped: nil)))
    }
    
    @available(FoundationPredicate 0.1, *)
    @Test func testConditional() throws {
        let predicate = #Predicate<Bool, String, String> {
            ($0 ? $1 : $2) == "if branch"
        }
        #expect(try predicate.evaluate(true, "if branch", "else branch"))
        #expect(try !predicate.evaluate(false, "if branch", "else branch"))
    }
    
    @available(FoundationPredicate 0.1, *)
    @Test func testClosedRange() throws {
        let predicate = #Predicate<Object> {
            (3...5).contains($0.a)
        }
        let predicate2 = #Predicate<Object> {
            ($0.a ... $0.d).contains(4)
        }
        #expect(try predicate.evaluate(Object(a: 4)))
        #expect(try !predicate.evaluate(Object(a: 7)))
        #expect(try predicate2.evaluate(Object(a: 3, d: 5)))
        #expect(try !predicate2.evaluate(Object(a: 1, d: 2)))
    }
    
    @available(FoundationPredicate 0.1, *)
    @Test func testRange() throws {
        let predicate = #Predicate<Object> {
            (3 ..< 5).contains($0.a)
        }
        let toMatch = 4
        let predicate2 = #Predicate<Object> {
            ($0.a ..< $0.d).contains(toMatch)
        }
        #expect(try predicate.evaluate(Object(a: 4)))
        #expect(try !predicate.evaluate(Object(a: 7)))
        #expect(try predicate2.evaluate(Object(a: 3, d: 5)))
        #expect(try !predicate2.evaluate(Object(a: 1, d: 2)))
    }
    
    @available(FoundationPredicate 0.1, *)
    @Test func testRangeContains() throws {
        let date = Date.distantPast
        let nextDate = Date(timeIntervalSince1970: date.timeIntervalSince1970 + 1)
        let predicate = #Predicate<Object> {
            (date ..< nextDate).contains($0.h)
        }
        
        #expect(try !predicate.evaluate(Object()))
        #expect(try predicate.evaluate(Object(h: date)))
    }
    
    @available(FoundationPredicate 0.1, *)
    @Test func testTypes() throws {
        let predicate = #Predicate<Object> {
            ($0.i as? Int).flatMap { $0 == 3 } ?? false
        }
        let predicate2 = #Predicate<Object> {
            $0.i is Int
        }
        #expect(try predicate.evaluate(Object()))
        #expect(try predicate2.evaluate(Object()))
    }
    
    @available(FoundationPredicate 0.1, *)
    @Test func testSubscripts() throws {
        var predicate = #Predicate<Object> {
            $0.g[0] == 0
        }
        
        #expect(try predicate.evaluate(Object(g: [0])))
        #expect(try !predicate.evaluate(Object(g: [1])))
        #expect(throws: PredicateError.invalidInput) {
            try predicate.evaluate(Object(g: []))
        }
        
        predicate = #Predicate<Object> {
            $0.g[0 ..< 2].isEmpty
        }
        
        #expect(try !predicate.evaluate(Object(g: [0, 1, 2])))
        #expect(try !predicate.evaluate(Object(g: [0, 1])))
        #expect(throws: PredicateError.invalidInput) {
            try predicate.evaluate(Object(g: [0]))
        }
        #expect(throws: PredicateError.invalidInput) {
            try predicate.evaluate(Object(g: []))
        }
    }
    
    @available(FoundationPredicate 0.1, *)
    @Test func testLazyDefaultValueSubscript() throws {
        struct Foo : Codable, Sendable {
            var property: Int {
                Issue.record("Foo.property should not be accessed")
                return 3
            }
        }
        
        let foo = Foo()
        let predicate = #Predicate<[String : Int]> {
            $0["key", default: foo.property] == 1
        }
        #expect(try !predicate.evaluate(["key" : 2]))
        #expect(try predicate.evaluate(["key" : 1]))
    }
    
    @available(FoundationPredicate 0.1, *)
    @Test func testStaticValues() throws {
        func assertPredicate<T>(_ pred: Predicate<T>, value: T, expected: Bool, sourceLocation: SourceLocation = #_sourceLocation) throws {
            #expect(try pred.evaluate(value) == expected, sourceLocation: sourceLocation)
        }
        
        try assertPredicate(.true, value: "Hello", expected: true)
        try assertPredicate(.false, value: "Hello", expected: false)
    }
    
    @available(FoundationPredicate 0.1, *)
    @Test func testMaxMin() throws {
        var predicate = #Predicate<Object> {
            $0.g.max() == 2
        }
        #expect(try !predicate.evaluate(Object(g: [1, 3])))
        #expect(try predicate.evaluate(Object(g: [1, 2])))
        
        predicate = #Predicate<Object> {
            $0.g.min() == 2
        }
        #expect(try !predicate.evaluate(Object(g: [1, 3])))
        #expect(try predicate.evaluate(Object(g: [2, 3])))
    }
    
    #if FOUNDATION_FRAMEWORK
    
    @available(FoundationPredicate 0.1, *)
    @Test func testCaseInsensitiveCompare() throws {
        let equal = ComparisonResult.orderedSame
        let predicate = #Predicate<Object> {
            $0.b.caseInsensitiveCompare("ABC") == equal
        }
        #expect(try predicate.evaluate(Object(b: "abc")))
        #expect(try !predicate.evaluate(Object(b: "def")))
    }
    
    #endif
    
    @available(FoundationPredicate 0.1, *)
    @Test func testBuildDynamically() throws {
        func _build(_ equal: Bool) -> Predicate<Int> {
            Predicate<Int> {
                if equal {
                    PredicateExpressions.Equal(
                        lhs: $0,
                        rhs: PredicateExpressions.Value(1)
                    )
                } else {
                    PredicateExpressions.NotEqual(
                        lhs: $0,
                        rhs: PredicateExpressions.Value(1)
                    )
                }
            }
        }
        
        #expect(try _build(true).evaluate(1))
        #expect(try !_build(false).evaluate(1))
    }
    
    @available(FoundationPredicate 0.1, *)
    @Test func testResilientKeyPaths() {
        // Local, non-resilient type
        struct Foo {
            let a: String   // Non-resilient
            let b: Date     // Resilient (in Foundation)
            let c: String   // Non-resilient
        }
        
        let now = Date.now
        let _ = #Predicate<Foo> {
            $0.a == $0.c && $0.b == now
        }
    }

    @available(FoundationPredicateRegex 0.4, *)
    @Test func testRegex() throws {
        let literalRegex = #/[AB0-9]\/?[^\n]+/#
        var predicate = #Predicate<Object> {
            $0.b.contains(literalRegex)
        }
        #expect(try predicate.evaluate(Object(b: "_0/bc")))
        #expect(try !predicate.evaluate(Object(b: "_C/bc")))
        predicate = #Predicate<Object> {
            $0.b.contains(#/[AB0-9]\/?[^\n]+/#)
        }
        #expect(try predicate.evaluate(Object(b: "_0/bc")))
        #expect(try !predicate.evaluate(Object(b: "_C/bc")))
    }
    
    #if canImport(RegexBuilder)
    @available(FoundationPredicateRegex 0.4, *)
    @Test func testRegex_RegexBuilder() throws {
        let builtRegex = Regex {
            ChoiceOf {
                "A"
                "B"
                CharacterClass.digit
            }
            Optionally("/")
            OneOrMore(.anyNonNewline)
        }
        let predicate = #Predicate<Object> {
            $0.b.contains(builtRegex)
        }
        #expect(try predicate.evaluate(Object(b: "_0/bc")))
        #expect(try !predicate.evaluate(Object(b: "_C/bc")))
    }
    #endif
    
    @available(FoundationPredicate 0.3, *)
    @Test func testDebugDescription() throws {
        let date = Date.now
        let predicate = #Predicate<Object> {
            if let num = $0.i as? Int {
                num == 3
            } else {
                $0.h == date
            }
        }
#if FOUNDATION_FRAMEWORK
        let moduleName = "Foundation"
        let testModuleName = "Unit"
#else
        let moduleName = "FoundationEssentials"
        let testModuleName = "FoundationEssentialsTests"
#endif
        #expect(
            predicate.description ==
            """
            capture1 (Swift.Int): 3
            capture2 (\(moduleName).Date): <Date \(date.timeIntervalSince1970)>
            Predicate<\(testModuleName).PredicateTests.Object> { input1 in
                (input1.i as? Swift.Int).flatMap({ variable1 in
                    variable1 == capture1
                }) ?? (input1.h == capture2)
            }
            """
        )
        
        let debugDescription = predicate.debugDescription.replacing(#/Variable\([0-9]+\)/#, with: "Variable(#)")
        #expect(
            debugDescription ==
            "\(moduleName).Predicate<Pack{\(testModuleName).PredicateTests.Object}>(variable: (Variable(#)), expression: NilCoalesce(lhs: OptionalFlatMap(wrapped: ConditionalCast(input: KeyPath(root: Variable(#), keyPath: \\Object.i), desiredType: Swift.Int), variable: Variable(#), transform: Equal(lhs: Variable(#), rhs: Value<Swift.Int>(3))), rhs: Equal(lhs: KeyPath(root: Variable(#), keyPath: \\Object.h), rhs: Value<\(moduleName).Date>(\(date.debugDescription)))))"
        )
    }

    #if FOUNDATION_FRAMEWORK
    @available(FoundationPredicate 0.3, *)
    @Test func testNested() throws {
        let predicateA = #Predicate<Object> {
            $0.a == 3
        }

        let predicateB = #Predicate<Object> {
            predicateA.evaluate($0) && $0.a > 2
        }

        #expect(try predicateA.evaluate(Object(a: 3)))
        #expect(try !predicateA.evaluate(Object(a: 2)))
        #expect(try predicateB.evaluate(Object(a: 3)))
        #expect(try !predicateB.evaluate(Object(a: 2)))
        #expect(try !predicateB.evaluate(Object(a: 4)))
    }
    #endif
    
    @available(FoundationPredicate 0.4, *)
    @Test func testExpression() throws {
        let expression = #Expression<Int, Int> {
            $0 + 1
        }
        for i in 0 ..< 10 {
            #expect(try expression.evaluate(i) == i + 1)
        }
    }
}
