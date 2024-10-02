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

#if canImport(RegexBuilder)
import RegexBuilder
#endif

#if !FOUNDATION_FRAMEWORK
// Resolve ambiguity between Foundation.#Predicate and FoundationEssentials.#Predicate
@freestanding(expression)
@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
macro Predicate<each Input>(_ body: (repeat each Input) -> Bool) -> Predicate<repeat each Input> = #externalMacro(module: "FoundationMacros", type: "PredicateMacro")
#endif

// Work around an issue issue on older Swift compilers
#if compiler(>=6.0)

final class PredicateTests: XCTestCase {
    
    override func setUp() async throws {
        guard #available(macOS 14, iOS 17, tvOS 17, watchOS 10, *) else {
            throw XCTSkip("This test is not available on this OS version")
        }
    }
    
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
    func testBasic() throws {
        let compareTo = 2
        let predicate = #Predicate<Object> {
            $0.a == compareTo
        }
        try XCTAssertFalse(predicate.evaluate(Object(a: 1, b: "", c: 0, d: 0, e: "c", f: true, g: [])))
        try XCTAssertTrue(predicate.evaluate(Object(a: 2, b: "", c: 0, d: 0, e: "c", f: true, g: [])))
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    func testVariadic() throws {
        let predicate = #Predicate<Object, Int> {
            $0.a == $1 + 1
        }
        XCTAssert(try predicate.evaluate(Object(a: 3, b: "", c: 0, d: 0, e: "c", f: true, g: []), 2))
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    func testArithmetic() throws {
        let predicate = #Predicate<Object> {
            $0.a + 2 == 4
        }
        XCTAssert(try predicate.evaluate(Object(a: 2, b: "", c: 0, d: 0, e: "c", f: true, g: [])))
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    func testDivision() throws {
        let predicate = #Predicate<Object> {
            $0.a / 2 == 3
        }
        let predicate2 = #Predicate<Object> {
            $0.c / 2.1 <= 3.0
        }
        XCTAssert(try predicate.evaluate(Object(a: 6, b: "", c: 0, d: 0, e: "c", f: true, g: [])))
        XCTAssert(try predicate2.evaluate(Object(a: 2, b: "", c: 6.0, d: 0, e: "c", f: true, g: [])))
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    func testBuildDivision() throws {
        let predicate = #Predicate<Object> {
            $0.a / 2 == 3
        }
        XCTAssert(try predicate.evaluate(Object(a: 6, b: "", c: 0, d: 0, e: "c", f: true, g: [])))
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    func testUnaryMinus() throws {
        let predicate = #Predicate<Object> {
            -$0.a == 17
        }
        XCTAssert(try predicate.evaluate(Object(a: -17, b: "", c: 0, d: 0, e: "c", f: true, g: [])))
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    func testCount() throws {
        let predicate = #Predicate<Object> {
            $0.g.count == 5
        }
        XCTAssert(try predicate.evaluate(Object(a: 0, b: "", c: 0, d: 0, e: "c", f: true, g: [2, 3, 5, 7, 11])))
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    func testFilter() throws {
        let predicate = #Predicate<Object> { object in
            !object.g.filter {
                $0 == object.d
            }.isEmpty
        }
        XCTAssert(try predicate.evaluate(Object(a: 0, b: "", c: 0.0, d: 17, e: "c", f: true, g: [3, 5, 7, 11, 13, 17, 19])))
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    func testContains() throws {
        let predicate = #Predicate<Object> {
            $0.g.contains($0.a)
        }
        XCTAssert(try predicate.evaluate(Object(a: 13, b: "", c: 0.0, d: 0, e: "c", f: true, g: [2, 3, 5, 11, 13, 17])))
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    func testContainsWhere() throws {
        let predicate = #Predicate<Object> { object in
            object.g.contains {
                $0 % object.a == 0
            }
        }
        XCTAssert(try predicate.evaluate(Object(a: 2, b: "", c: 0.0, d: 0, e: "c", f: true, g: [3, 5, 7, 2, 11, 13])))
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    func testAllSatisfy() throws {
        let predicate = #Predicate<Object> { object in
            object.g.allSatisfy {
                $0 % object.d != 0
            }
        }
        XCTAssert(try predicate.evaluate(Object(a: 0, b: "", c: 0.0, d: 2, e: "c", f: true, g: [3, 5, 7, 11, 13, 17, 19])))
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    func testOptional() throws {
        struct Wrapper<T> {
            let wrapped: T?
        }
        let predicate = #Predicate<Wrapper<Int>> {
            ($0.wrapped.flatMap { $0 + 1 } ?? 7) % 2 == 1
        }
        let predicate2 = #Predicate<Wrapper<Int>> {
            $0.wrapped! == 19
        }
        XCTAssert(try predicate.evaluate(Wrapper<Int>(wrapped: 4)))
        XCTAssert(try predicate.evaluate(Wrapper<Int>(wrapped: nil)))
        XCTAssert(try predicate2.evaluate(Wrapper<Int>(wrapped: 19)))
        XCTAssertThrowsError(try predicate2.evaluate(Wrapper<Int>(wrapped: nil)))
        
        struct _NonCodableType : Equatable {}
        let predicate3 = #Predicate<Wrapper<_NonCodableType>> {
            $0.wrapped == nil
        }
        XCTAssertFalse(try predicate3.evaluate(Wrapper(wrapped: _NonCodableType())))
        XCTAssertTrue(try predicate3.evaluate(Wrapper(wrapped: nil)))
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    func testConditional() throws {
        let predicate = #Predicate<Bool, String, String> {
            ($0 ? $1 : $2) == "if branch"
        }
        XCTAssert(try predicate.evaluate(true, "if branch", "else branch"))
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    func testClosedRange() throws {
        let predicate = #Predicate<Object> {
            (3...5).contains($0.a)
        }
        let predicate2 = #Predicate<Object> {
            ($0.a ... $0.d).contains(4)
        }
        XCTAssert(try predicate.evaluate(Object(a: 4, b: "", c: 0.0, d: 0, e: "c", f: true, g: [])))
        XCTAssert(try predicate2.evaluate(Object(a: 3, b: "", c: 0.0, d: 5, e: "c", f: true, g: [])))
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    func testRange() throws {
        let predicate = #Predicate<Object> {
            (3 ..< 5).contains($0.a)
        }
        let toMatch = 4
        let predicate2 = #Predicate<Object> {
            ($0.a ..< $0.d).contains(toMatch)
        }
        XCTAssert(try predicate.evaluate(Object(a: 4, b: "", c: 0.0, d: 0, e: "c", f: true, g: [])))
        XCTAssert(try predicate2.evaluate(Object(a: 3, b: "", c: 0.0, d: 5, e: "c", f: true, g: [])))
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    func testRangeContains() throws {
        let date = Date.distantPast
        let predicate = #Predicate<Object> {
            (date ..< date).contains($0.h)
        }
        
        XCTAssertFalse(try predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 5, e: "c", f: true, g: [])))
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    func testTypes() throws {
        let predicate = #Predicate<Object> {
            ($0.i as? Int).flatMap { $0 == 3 } ?? false
        }
        let predicate2 = #Predicate<Object> {
            $0.i is Int
        }
        XCTAssert(try predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [])))
        XCTAssert(try predicate2.evaluate(Object(a: 3, b: "", c: 0.0, d: 5, e: "c", f: true, g: [])))
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    func testSubscripts() throws {
        var predicate = #Predicate<Object> {
            $0.g[0] == 0
        }
        
        XCTAssertTrue(try predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [0])))
        XCTAssertFalse(try predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [1])))
        XCTAssertThrowsError(try predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [])))
        
        predicate = #Predicate<Object> {
            $0.g[0 ..< 2].isEmpty
        }
        
        XCTAssertFalse(try predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [0, 1, 2])))
        XCTAssertFalse(try predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [0, 1])))
        XCTAssertThrowsError(try predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [0])))
        XCTAssertThrowsError(try predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [])))
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    func testLazyDefaultValueSubscript() throws {
        struct Foo : Codable, Sendable {
            var property: Int {
                fatalError("This property should not have been accessed")
            }
        }
        
        let foo = Foo()
        let predicate = #Predicate<[String : Int]> {
            $0["key", default: foo.property] == 1
        }
        XCTAssertFalse(try predicate.evaluate(["key" : 2]))
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    func testStaticValues() throws {
        func assertPredicate<T>(_ pred: Predicate<T>, value: T, expected: Bool) throws {
            XCTAssertEqual(try pred.evaluate(value), expected)
        }
        
        try assertPredicate(.true, value: "Hello", expected: true)
        try assertPredicate(.false, value: "Hello", expected: false)
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    func testMaxMin() throws {
        var predicate = #Predicate<Object> {
            $0.g.max() == 2
        }
        XCTAssertFalse(try predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [1, 3])))
        XCTAssertTrue(try predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [1, 2])))
        
        predicate = #Predicate<Object> {
            $0.g.min() == 2
        }
        XCTAssertFalse(try predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [1, 3])))
        XCTAssertTrue(try predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [2, 3])))
    }
    
    #if FOUNDATION_FRAMEWORK
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    func testCaseInsensitiveCompare() throws {
        let equal = ComparisonResult.orderedSame
        let predicate = #Predicate<Object> {
            $0.b.caseInsensitiveCompare("ABC") == equal
        }
        XCTAssertTrue(try predicate.evaluate(Object(a: 3, b: "abc", c: 0.0, d: 0, e: "c", f: true, g: [1, 3])))
        XCTAssertFalse(try predicate.evaluate(Object(a: 3, b: "def", c: 0.0, d: 0, e: "c", f: true, g: [1, 3])))
    }
    
    #endif
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    func testBuildDynamically() throws {
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
        
        XCTAssertTrue(try _build(true).evaluate(1))
        XCTAssertFalse(try _build(false).evaluate(1))
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    func testResilientKeyPaths() {
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
    func testRegex() throws {
        guard #available(FoundationPredicateRegex 0.4, *) else {
            throw XCTSkip("This test is not available on this OS version")
        }
        
        let literalRegex = #/[AB0-9]\/?[^\n]+/#
        var predicate = #Predicate<Object> {
            $0.b.contains(literalRegex)
        }
        XCTAssertTrue(try predicate.evaluate(Object(a: 0, b: "_0/bc", c: 0, d: 0, e: " ", f: true, g: [])))
        XCTAssertFalse(try predicate.evaluate(Object(a: 0, b: "_C/bc", c: 0, d: 0, e: " ", f: true, g: [])))
        predicate = #Predicate<Object> {
            $0.b.contains(#/[AB0-9]\/?[^\n]+/#)
        }
        XCTAssertTrue(try predicate.evaluate(Object(a: 0, b: "_0/bc", c: 0, d: 0, e: " ", f: true, g: [])))
        XCTAssertFalse(try predicate.evaluate(Object(a: 0, b: "_C/bc", c: 0, d: 0, e: " ", f: true, g: [])))
    }
    
    func testRegex_RegexBuilder() throws {
        #if !canImport(RegexBuilder)
        throw XCTSkip("RegexBuilder is unavavailable on this platform")
        #elseif !os(Linux) && !os(Android) && !FOUNDATION_FRAMEWORK
        // Disable this test in swift-foundation macOS CI because of incorrect availability annotations in the StringProcessing module
        throw XCTSkip("This test is currently disabled on this platform")
        #else
        guard #available(FoundationPredicateRegex 0.4, *) else {
            throw XCTSkip("This test is not available on this OS version")
        }
        
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
        XCTAssertTrue(try predicate.evaluate(Object(a: 0, b: "_0/bc", c: 0, d: 0, e: " ", f: true, g: [])))
        XCTAssertFalse(try predicate.evaluate(Object(a: 0, b: "_C/bc", c: 0, d: 0, e: " ", f: true, g: [])))
        #endif
    }
    #endif
    
    func testDebugDescription() throws {
        guard #available(FoundationPredicate 0.3, *) else {
            throw XCTSkip("This test is not available on this OS version")
        }
        
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
        XCTAssertEqual(
            predicate.description,
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
        XCTAssertEqual(
            debugDescription,
            "\(moduleName).Predicate<Pack{\(testModuleName).PredicateTests.Object}>(variable: (Variable(#)), expression: NilCoalesce(lhs: OptionalFlatMap(wrapped: ConditionalCast(input: KeyPath(root: Variable(#), keyPath: \\Object.i), desiredType: Swift.Int), variable: Variable(#), transform: Equal(lhs: Variable(#), rhs: Value<Swift.Int>(3))), rhs: Equal(lhs: KeyPath(root: Variable(#), keyPath: \\Object.h), rhs: Value<\(moduleName).Date>(\(date.debugDescription)))))"
        )
    }

    #if FOUNDATION_FRAMEWORK
    func testNested() throws {
        guard #available(FoundationPredicate 0.3, *) else {
            throw XCTSkip("This test is not available on this OS version")
        }

        let predicateA = #Predicate<Object> {
            $0.a == 3
        }

        let predicateB = #Predicate<Object> {
            predicateA.evaluate($0) && $0.a > 2
        }

        XCTAssertTrue(try predicateA.evaluate(Object(a: 3, b: "abc", c: 0.0, d: 0, e: "c", f: true, g: [1, 3])))
        XCTAssertFalse(try predicateA.evaluate(Object(a: 2, b: "abc", c: 0.0, d: 0, e: "c", f: true, g: [1, 3])))
        XCTAssertTrue(try predicateB.evaluate(Object(a: 3, b: "abc", c: 0.0, d: 0, e: "c", f: true, g: [1, 3])))
        XCTAssertFalse(try predicateB.evaluate(Object(a: 2, b: "abc", c: 0.0, d: 0, e: "c", f: true, g: [1, 3])))
        XCTAssertFalse(try predicateB.evaluate(Object(a: 4, b: "abc", c: 0.0, d: 0, e: "c", f: true, g: [1, 3])))
    }
    #endif
    
    func testExpression() throws {
        guard #available(FoundationPredicate 0.4, *) else {
            throw XCTSkip("This test is not available on this OS version")
        }
        
        let expression = #Expression<Int, Int> {
            $0 + 1
        }
        for i in 0 ..< 10 {
            XCTAssertEqual(try expression.evaluate(i), i + 1)
        }
    }
}

#endif // compiler(>=6.0)
