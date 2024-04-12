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

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable import FoundationEssentials
#endif

#if canImport(RegexBuilder)
import RegexBuilder
#endif

#if FOUNDATION_FRAMEWORK
@_spi(Expression) import Foundation
#endif

#if !FOUNDATION_FRAMEWORK
// Resolve ambiguity between Foundation.#Predicate and FoundationEssentials.#Predicate
@freestanding(expression)
@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
macro Predicate<each Input>(_ body: (repeat each Input) -> Bool) -> Predicate<repeat each Input> = #externalMacro(module: "FoundationMacros", type: "PredicateMacro")
#endif

func predicateTestsAvailable() -> Bool {
    if #available(macOS 14, iOS 17, tvOS 17, watchOS 10, *) {
        return true
    }
    return false
}

@Suite(.enabled(if: predicateTestsAvailable(), "PredicateTests is not available on this OS version"))
struct PredicateTests {

    struct Object {
        var a: Int
        var b: String
        var c: Double
        var d: Int
        var e: Character
        var f: Bool
        var g: [Int]
        var h: Date = .now
        var i: Any = 3
    }
    
    struct Object2 {
        var a: Bool
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    @Test func testBasic() throws {
        let compareTo = 2
        let predicate = #Predicate<Object> {
            $0.a == compareTo
        }
        var result = try predicate.evaluate(Object(a: 1, b: "", c: 0, d: 0, e: "c", f: true, g: []))
        #expect(result == false)
        result = try predicate.evaluate(Object(a: 2, b: "", c: 0, d: 0, e: "c", f: true, g: []))
        #expect(result == true)
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    @Test func testVariadic() throws {
        let predicate = #Predicate<Object, Int> {
            $0.a == $1 + 1
        }
        let result = try predicate.evaluate(Object(a: 3, b: "", c: 0, d: 0, e: "c", f: true, g: []), 2)
        #expect(result == true)
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    @Test func testArithmetic() throws {
        let predicate = #Predicate<Object> {
            $0.a + 2 == 4
        }
        let results = try predicate.evaluate(Object(a: 2, b: "", c: 0, d: 0, e: "c", f: true, g: []))
        #expect(results)
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    @Test func testDivision() throws {
        let predicate = #Predicate<Object> {
            $0.a / 2 == 3
        }
        let predicate2 = #Predicate<Object> {
            $0.c / 2.1 <= 3.0
        }
        var results = try predicate.evaluate(Object(a: 6, b: "", c: 0, d: 0, e: "c", f: true, g: []))
        #expect(results)
        results = try predicate2.evaluate(Object(a: 2, b: "", c: 6.0, d: 0, e: "c", f: true, g: []))
        #expect(results)
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    @Test func testBuildDivision() throws {
        let predicate = #Predicate<Object> {
            $0.a / 2 == 3
        }
        let results = try predicate.evaluate(Object(a: 6, b: "", c: 0, d: 0, e: "c", f: true, g: []))
        #expect(results)
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    @Test func testUnaryMinus() throws {
        let predicate = #Predicate<Object> {
            -$0.a == 17
        }
        let results = try predicate
            .evaluate(Object(a: -17, b: "", c: 0, d: 0, e: "c", f: true, g: []))
        #expect(results)
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    @Test func testCount() throws {
        let predicate = #Predicate<Object> {
            $0.g.count == 5
        }
        let results = try predicate
            .evaluate(Object(a: 0, b: "", c: 0, d: 0, e: "c", f: true, g: [2, 3, 5, 7, 11]))
        #expect(results)
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    @Test func testFilter() throws {
        let predicate = #Predicate<Object> { object in
            !object.g.filter {
                $0 == object.d
            }.isEmpty
        }
        let results = try predicate
            .evaluate(Object(a: 0, b: "", c: 0.0, d: 17, e: "c", f: true, g: [3, 5, 7, 11, 13, 17, 19]))
        #expect(results)
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    @Test func testContains() throws {
        let predicate = #Predicate<Object> {
            $0.g.contains($0.a)
        }
        let results = try predicate
            .evaluate(Object(a: 13, b: "", c: 0.0, d: 0, e: "c", f: true, g: [2, 3, 5, 11, 13, 17]))
        #expect(results)
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    @Test func testContainsWhere() throws {
        let predicate = #Predicate<Object> { object in
            object.g.contains {
                $0 % object.a == 0
            }
        }
        let results = try predicate
            .evaluate(Object(a: 2, b: "", c: 0.0, d: 0, e: "c", f: true, g: [3, 5, 7, 2, 11, 13]))
        #expect(results)
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    @Test func testAllSatisfy() throws {
        let predicate = #Predicate<Object> { object in
            object.g.allSatisfy {
                $0 % object.d != 0
            }
        }
        let results = try predicate
            .evaluate(Object(a: 0, b: "", c: 0.0, d: 2, e: "c", f: true, g: [3, 5, 7, 11, 13, 17, 19]))
        #expect(results)
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
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
        var results = try predicate.evaluate(Wrapper<Int>(wrapped: 4))
        #expect(results)
        results = try predicate.evaluate(Wrapper<Int>(wrapped: nil))
        #expect(results)
        results = try predicate2.evaluate(Wrapper<Int>(wrapped: 19))
        #expect(results)
        #expect(throws: (any Error).self) {
            try predicate2.evaluate(Wrapper<Int>(wrapped: nil))
        }

        struct _NonCodableType : Equatable {}
        let predicate3 = #Predicate<Wrapper<_NonCodableType>> {
            $0.wrapped == nil
        }
        results = try predicate3.evaluate(Wrapper(wrapped: _NonCodableType()))
        #expect(results == false)
        results = try predicate3.evaluate(Wrapper(wrapped: nil))
        #expect(results)
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    @Test func testConditional() throws {
        let predicate = #Predicate<Bool, String, String> {
            ($0 ? $1 : $2) == "if branch"
        }
        let results = try predicate.evaluate(true, "if branch", "else branch")
        #expect(results)
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    @Test func testClosedRange() throws {
        let predicate = #Predicate<Object> {
            (3...5).contains($0.a)
        }
        let predicate2 = #Predicate<Object> {
            ($0.a ... $0.d).contains(4)
        }
        var results = try predicate
            .evaluate(Object(a: 4, b: "", c: 0.0, d: 0, e: "c", f: true, g: []))
        #expect(results == true)
        results = try predicate2.evaluate(Object(a: 3, b: "", c: 0.0, d: 5, e: "c", f: true, g: []))
        #expect(results == true)
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    @Test func testRange() throws {
        let predicate = #Predicate<Object> {
            (3 ..< 5).contains($0.a)
        }
        let toMatch = 4
        let predicate2 = #Predicate<Object> {
            ($0.a ..< $0.d).contains(toMatch)
        }
        var results = try predicate
            .evaluate(Object(a: 4, b: "", c: 0.0, d: 0, e: "c", f: true, g: []))
        #expect(results == true)
        results = try predicate2
            .evaluate(Object(a: 3, b: "", c: 0.0, d: 5, e: "c", f: true, g: []))
        #expect(results == true)
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    @Test func testRangeContains() throws {
        let date = Date.distantPast
        let predicate = #Predicate<Object> {
            (date ..< date).contains($0.h)
        }
        let results = try predicate
            .evaluate(Object(a: 3, b: "", c: 0.0, d: 5, e: "c", f: true, g: []))
        #expect(results == false)
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    @Test func testTypes() throws {
        let predicate = #Predicate<Object> {
            ($0.i as? Int).flatMap { $0 == 3 } ?? false
        }
        let predicate2 = #Predicate<Object> {
            $0.i is Int
        }
        var results = try predicate
            .evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: []))
        #expect(results == true)
        results = try predicate2.evaluate(Object(a: 3, b: "", c: 0.0, d: 5, e: "c", f: true, g: []))
        #expect(results == true)
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    @Test func testSubscripts() throws {
        var predicate = #Predicate<Object> {
            $0.g[0] == 0
        }
        var results = try predicate
            .evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [0]))
        #expect(results == true)
        results = try predicate
            .evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [1]))
        #expect(results == false)
        #expect(throws: (any Error).self) {
            try predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: []))
        }

        predicate = #Predicate<Object> {
            $0.g[0 ..< 2].isEmpty
        }

        results = try predicate
            .evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [0, 1, 2]))
        #expect(results == false)
        results = try predicate
            .evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [0, 1]))
        #expect(results == false)
        #expect(throws: (any Error).self) {
            try predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [0]))
        }
        #expect(throws: (any Error).self) {
            try predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: []))
        }
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    @Test func testLazyDefaultValueSubscript() throws {
        struct Foo : Codable, Sendable {
            static var num = 1
            
            var property: Int {
                defer { Foo.num += 1 }
                return Foo.num
            }
        }
        
        let foo = Foo()
        let predicate = #Predicate<[String : Int]> {
            $0["key", default: foo.property] == 1
        }
        let results = try predicate.evaluate(["key" : 2])
        #expect(results == false)
        #expect(Foo.num == 1)
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    @Test func testStaticValues() throws {
        func assertPredicate<T>(_ pred: Predicate<T>, value: T, expected: Bool) throws {
            let results = try pred.evaluate(value)
            #expect(results == expected)
        }
        
        try assertPredicate(.true, value: "Hello", expected: true)
        try assertPredicate(.false, value: "Hello", expected: false)
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    @Test func testMaxMin() throws {
        var predicate = #Predicate<Object> {
            $0.g.max() == 2
        }
        var results = try predicate
            .evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [1, 3]))
        #expect(results == false)
        results = try predicate
            .evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [1, 2]))
        #expect(results == true)

        predicate = #Predicate<Object> {
            $0.g.min() == 2
        }
        results = try predicate
            .evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [1, 3]))
        #expect(results == false)
        results = try predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [2, 3]))
        #expect(results == true)
    }
    
    #if FOUNDATION_FRAMEWORK
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    @Test func testCaseInsensitiveCompare() throws {
        let equal = ComparisonResult.orderedSame
        let predicate = #Predicate<Object> {
            $0.b.caseInsensitiveCompare("ABC") == equal
        }
        var results = try predicate.evaluate(Object(a: 3, b: "abc", c: 0.0, d: 0, e: "c", f: true, g: [1, 3]))
        #expect(results == true)
        results = try predicate.evaluate(Object(a: 3, b: "def", c: 0.0, d: 0, e: "c", f: true, g: [1, 3]))
        #expect(results == false)
    }
    
    #endif
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
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
        var results = try _build(true).evaluate(1)
        #expect(results == true)
        results = try _build(false).evaluate(1)
        #expect(results == false)
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
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

#if compiler(>=5.11)
    @available(FoundationPredicateRegex 0.4, *)
    @Test func testRegex() throws {
        let literalRegex = #/[AB0-9]\/?[^\n]+/#
        var predicate = #Predicate<Object> {
            $0.b.contains(literalRegex)
        }
        var result = try predicate
            .evaluate(Object(a: 0, b: "_0/bc", c: 0, d: 0, e: " ", f: true, g: []))
        #expect(result)
        result = try predicate.evaluate(Object(a: 0, b: "_C/bc", c: 0, d: 0, e: " ", f: true, g: [])) == false
        #expect(result)
        predicate = #Predicate<Object> {
            $0.b.contains(#/[AB0-9]\/?[^\n]+/#)
        }
        result = try predicate.evaluate(Object(a: 0, b: "_0/bc", c: 0, d: 0, e: " ", f: true, g: []))
        #expect(result)
        result = try predicate.evaluate(Object(a: 0, b: "_C/bc", c: 0, d: 0, e: " ", f: true, g: [])) == false
        #expect(result)
    }
    
#if canImport(RegexBuilder) && (os(Linux) || FOUNDATION_FRAMEWORK)
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
        var results = try predicate
            .evaluate(Object(a: 0, b: "_0/bc", c: 0, d: 0, e: " ", f: true, g: []))
        #expect(results == true)
        results = try predicate
            .evaluate(Object(a: 0, b: "_C/bc", c: 0, d: 0, e: " ", f: true, g: []))
        #expect(results == false)
    }
#endif // canImport(RegexBuilder) && (os(Linux) || FOUNDATION_FRAMEWORK)
#endif // compiler(>=5.11)

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
        var results = try predicateA
            .evaluate(Object(a: 3, b: "abc", c: 0.0, d: 0, e: "c", f: true, g: [1, 3]))
        #expect(results == true)
        results = try predicateA
            .evaluate(Object(a: 2, b: "abc", c: 0.0, d: 0, e: "c", f: true, g: [1, 3]))
        #expect(results == false)
        results = try predicateB
            .evaluate(Object(a: 3, b: "abc", c: 0.0, d: 0, e: "c", f: true, g: [1, 3]))
        #expect(results == true)
        results = try predicateB.evaluate(Object(a: 2, b: "abc", c: 0.0, d: 0, e: "c", f: true, g: [1, 3]))
        #expect(results == false)
        results = try predicateB.evaluate(Object(a: 4, b: "abc", c: 0.0, d: 0, e: "c", f: true, g: [1, 3]))
        #expect(results == false)
    }
    
    @available(FoundationPredicate 0.4, *)
    @Test func testExpression() throws {
        
        let expression = Expression<Int, Int>() {
            PredicateExpressions.build_Arithmetic(
                lhs: PredicateExpressions.build_Arg($0),
                rhs: PredicateExpressions.build_Arg(1),
                op: .add
            )
        }
        for i in 0 ..< 10 {
            let result = try expression.evaluate(i)
            #expect(result == i + 1)
        }
    }
    #endif
}
