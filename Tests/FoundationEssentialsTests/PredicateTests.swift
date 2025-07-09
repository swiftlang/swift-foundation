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
#else
import Foundation
#endif

#if canImport(RegexBuilder)
import RegexBuilder
#endif

// These types are non-private and in the global scope to ensure a consistent string type name for the debugDescription() test
struct PredicateTestObject {
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

struct PredicateTestObject2 {
    var a: Bool
}

@Suite("Predicate")
private struct PredicateTests {
    typealias Object = PredicateTestObject
    typealias Object2 = PredicateTestObject2
    
    @Test func basic() throws {
        let compareTo = 2
        let predicate = #Predicate<Object> {
            $0.a == compareTo
        }
        #expect(try !predicate.evaluate(Object(a: 1, b: "", c: 0, d: 0, e: "c", f: true, g: [])))
        #expect(try predicate.evaluate(Object(a: 2, b: "", c: 0, d: 0, e: "c", f: true, g: [])))
    }
    
    @Test func variadic() throws {
        let predicate = #Predicate<Object, Int> {
            $0.a == $1 + 1
        }
        #expect(try predicate.evaluate(Object(a: 3, b: "", c: 0, d: 0, e: "c", f: true, g: []), 2))
    }
    
    @Test func arithmetic() throws {
        let predicate = #Predicate<Object> {
            $0.a + 2 == 4
        }
        #expect(try predicate.evaluate(Object(a: 2, b: "", c: 0, d: 0, e: "c", f: true, g: [])))
    }
    
    @Test func division() throws {
        let predicate = #Predicate<Object> {
            $0.a / 2 == 3
        }
        let predicate2 = #Predicate<Object> {
            $0.c / 2.1 <= 3.0
        }
        #expect(try predicate.evaluate(Object(a: 6, b: "", c: 0, d: 0, e: "c", f: true, g: [])))
        #expect(try predicate2.evaluate(Object(a: 2, b: "", c: 6.0, d: 0, e: "c", f: true, g: [])))
    }
    
    @Test func unaryMinus() throws {
        let predicate = #Predicate<Object> {
            -$0.a == 17
        }
        #expect(try predicate.evaluate(Object(a: -17, b: "", c: 0, d: 0, e: "c", f: true, g: [])))
    }
    
    @Test func count() throws {
        let predicate = #Predicate<Object> {
            $0.g.count == 5
        }
        #expect(try predicate.evaluate(Object(a: 0, b: "", c: 0, d: 0, e: "c", f: true, g: [2, 3, 5, 7, 11])))
    }
    
    @Test func filter() throws {
        let predicate = #Predicate<Object> { object in
            !object.g.filter {
                $0 == object.d
            }.isEmpty
        }
        #expect(try predicate.evaluate(Object(a: 0, b: "", c: 0.0, d: 17, e: "c", f: true, g: [3, 5, 7, 11, 13, 17, 19])))
    }
    
    @Test func contains() throws {
        let predicate = #Predicate<Object> {
            $0.g.contains($0.a)
        }
        #expect(try predicate.evaluate(Object(a: 13, b: "", c: 0.0, d: 0, e: "c", f: true, g: [2, 3, 5, 11, 13, 17])))
    }
    
    @Test func containsWhere() throws {
        let predicate = #Predicate<Object> { object in
            object.g.contains {
                $0 % object.a == 0
            }
        }
        #expect(try predicate.evaluate(Object(a: 2, b: "", c: 0.0, d: 0, e: "c", f: true, g: [3, 5, 7, 2, 11, 13])))
    }
    
    @Test func allSatisfy() throws {
        let predicate = #Predicate<Object> { object in
            object.g.allSatisfy {
                $0 % object.d != 0
            }
        }
        #expect(try predicate.evaluate(Object(a: 0, b: "", c: 0.0, d: 2, e: "c", f: true, g: [3, 5, 7, 11, 13, 17, 19])))
    }
    
    @Test func optional() throws {
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
        #expect(throws: (any Error).self) {
            try predicate2.evaluate(Wrapper<Int>(wrapped: nil))
        }
        
        struct _NonCodableType : Equatable {}
        let predicate3 = #Predicate<Wrapper<_NonCodableType>> {
            $0.wrapped == nil
        }
        #expect(try !predicate3.evaluate(Wrapper(wrapped: _NonCodableType())))
        #expect(try predicate3.evaluate(Wrapper(wrapped: nil)))
    }
    
    @Test func conditional() throws {
        let predicate = #Predicate<Bool, String, String> {
            ($0 ? $1 : $2) == "if branch"
        }
        #expect(try predicate.evaluate(true, "if branch", "else branch"))
    }
    
    @Test func closedRange() throws {
        let predicate = #Predicate<Object> {
            (3...5).contains($0.a)
        }
        let predicate2 = #Predicate<Object> {
            ($0.a ... $0.d).contains(4)
        }
        #expect(try predicate.evaluate(Object(a: 4, b: "", c: 0.0, d: 0, e: "c", f: true, g: [])))
        #expect(try predicate2.evaluate(Object(a: 3, b: "", c: 0.0, d: 5, e: "c", f: true, g: [])))
    }
    
    @Test func range() throws {
        let predicate = #Predicate<Object> {
            (3 ..< 5).contains($0.a)
        }
        let toMatch = 4
        let predicate2 = #Predicate<Object> {
            ($0.a ..< $0.d).contains(toMatch)
        }
        #expect(try predicate.evaluate(Object(a: 4, b: "", c: 0.0, d: 0, e: "c", f: true, g: [])))
        #expect(try predicate2.evaluate(Object(a: 3, b: "", c: 0.0, d: 5, e: "c", f: true, g: [])))
    }
    
    @Test func rangeContains() throws {
        let date = Date.distantPast
        let predicate = #Predicate<Object> {
            (date ..< date).contains($0.h)
        }
        
        #expect(try !predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 5, e: "c", f: true, g: [])))
    }
    
    @Test func types() throws {
        let predicate = #Predicate<Object> {
            ($0.i as? Int).flatMap { $0 == 3 } ?? false
        }
        let predicate2 = #Predicate<Object> {
            $0.i is Int
        }
        #expect(try predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [])))
        #expect(try predicate2.evaluate(Object(a: 3, b: "", c: 0.0, d: 5, e: "c", f: true, g: [])))
    }
    
    @Test func subscripts() throws {
        var predicate = #Predicate<Object> {
            $0.g[0] == 0
        }
        
        #expect(try predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [0])))
        #expect(try !predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [1])))
        #expect(throws: (any Error).self) {
            try predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: []))
        }
        
        predicate = #Predicate<Object> {
            $0.g[0 ..< 2].isEmpty
        }
        
        #expect(try !predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [0, 1, 2])))
        #expect(try !predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [0, 1])))
        #expect(throws: (any Error).self) {
            try predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [0]))
        }
        #expect(throws: (any Error).self) {
            try predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: []))
        }
    }
    
    @Test func lazyDefaultValueSubscript() throws {
        struct Foo : Codable, Sendable {
            var property: Int {
                fatalError("This property should not have been accessed")
            }
        }
        
        let foo = Foo()
        let predicate = #Predicate<[String : Int]> {
            $0["key", default: foo.property] == 1
        }
        #expect(try !predicate.evaluate(["key" : 2]))
    }
    
    @Test func staticValues() throws {
        func assertPredicate<T>(_ pred: Predicate<T>, value: T, expected: Bool, sourceLocation: SourceLocation = #_sourceLocation) throws {
            #expect(try pred.evaluate(value) == expected, sourceLocation: sourceLocation)
        }
        
        try assertPredicate(.true, value: "Hello", expected: true)
        try assertPredicate(.false, value: "Hello", expected: false)
    }
    
    @Test func maxMin() throws {
        var predicate = #Predicate<Object> {
            $0.g.max() == 2
        }
        #expect(try !predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [1, 3])))
        #expect(try predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [1, 2])))
        
        predicate = #Predicate<Object> {
            $0.g.min() == 2
        }
        #expect(try !predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [1, 3])))
        #expect(try predicate.evaluate(Object(a: 3, b: "", c: 0.0, d: 0, e: "c", f: true, g: [2, 3])))
    }
    
    #if FOUNDATION_FRAMEWORK
    
    @Test func caseInsensitiveCompare() throws {
        let equal = ComparisonResult.orderedSame
        let predicate = #Predicate<Object> {
            $0.b.caseInsensitiveCompare("ABC") == equal
        }
        #expect(try predicate.evaluate(Object(a: 3, b: "abc", c: 0.0, d: 0, e: "c", f: true, g: [1, 3])))
        #expect(try !predicate.evaluate(Object(a: 3, b: "def", c: 0.0, d: 0, e: "c", f: true, g: [1, 3])))
    }
    
    #endif
    
    @Test func buildDynamically() throws {
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
    
    @Test func resilientKeyPaths() {
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

    @Test
    func regex() throws {
        let literalRegex = #/[AB0-9]\/?[^\n]+/#
        var predicate = #Predicate<Object> {
            $0.b.contains(literalRegex)
        }
        #expect(try predicate.evaluate(Object(a: 0, b: "_0/bc", c: 0, d: 0, e: " ", f: true, g: [])))
        #expect(try !predicate.evaluate(Object(a: 0, b: "_C/bc", c: 0, d: 0, e: " ", f: true, g: [])))
        predicate = #Predicate<Object> {
            $0.b.contains(#/[AB0-9]\/?[^\n]+/#)
        }
        #expect(try predicate.evaluate(Object(a: 0, b: "_0/bc", c: 0, d: 0, e: " ", f: true, g: [])))
        #expect(try !predicate.evaluate(Object(a: 0, b: "_C/bc", c: 0, d: 0, e: " ", f: true, g: [])))
    }
    
    #if canImport(RegexBuilder)
    @Test
    func regex_RegexBuilder() throws {
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
        #expect(try predicate.evaluate(Object(a: 0, b: "_0/bc", c: 0, d: 0, e: " ", f: true, g: [])))
        #expect(try !predicate.evaluate(Object(a: 0, b: "_C/bc", c: 0, d: 0, e: " ", f: true, g: [])))
    }
    #endif
    
    @Test
    func debugDescription() throws {
        let date = Date.now
        let predicate = #Predicate<Object> {
            if let num = $0.i as? Int {
                num == 3
            } else {
                $0.h == date
            }
        }
        
        let dateName = _typeName(Date.self)
        let objectName = _typeName(Object.self)
        #expect(
            predicate.description ==
            """
            capture1 (Swift.Int): 3
            capture2 (\(dateName)): <Date \(date.timeIntervalSince1970)>
            Predicate<\(objectName)> { input1 in
                (input1.i as? Swift.Int).flatMap({ variable1 in
                    variable1 == capture1
                }) ?? (input1.h == capture2)
            }
            """
        )
        
        let debugDescription = predicate.debugDescription.replacing(#/Variable\([0-9]+\)/#, with: "Variable(#)")
        let predicateName = _typeName(Predicate<Object>.self)
        #expect(
            debugDescription ==
            "\(predicateName)(variable: (Variable(#)), expression: NilCoalesce(lhs: OptionalFlatMap(wrapped: ConditionalCast(input: KeyPath(root: Variable(#), keyPath: \\PredicateTestObject.i), desiredType: Swift.Int), variable: Variable(#), transform: Equal(lhs: Variable(#), rhs: Value<Swift.Int>(3))), rhs: Equal(lhs: KeyPath(root: Variable(#), keyPath: \\PredicateTestObject.h), rhs: Value<\(dateName)>(\(date.debugDescription)))))"
        )
    }

    #if FOUNDATION_FRAMEWORK
    @Test
    func nested() throws {
        let predicateA = #Predicate<Object> {
            $0.a == 3
        }

        let predicateB = #Predicate<Object> {
            predicateA.evaluate($0) && $0.a > 2
        }

        #expect(try predicateA.evaluate(Object(a: 3, b: "abc", c: 0.0, d: 0, e: "c", f: true, g: [1, 3])))
        #expect(try !predicateA.evaluate(Object(a: 2, b: "abc", c: 0.0, d: 0, e: "c", f: true, g: [1, 3])))
        #expect(try predicateB.evaluate(Object(a: 3, b: "abc", c: 0.0, d: 0, e: "c", f: true, g: [1, 3])))
        #expect(try !predicateB.evaluate(Object(a: 2, b: "abc", c: 0.0, d: 0, e: "c", f: true, g: [1, 3])))
        #expect(try !predicateB.evaluate(Object(a: 4, b: "abc", c: 0.0, d: 0, e: "c", f: true, g: [1, 3])))
    }
    #endif
    
    @Test
    func expression() throws {
        let expression = #Expression<Int, Int> {
            $0 + 1
        }
        for i in 0 ..< 10 {
            #expect(try expression.evaluate(i) == i + 1)
        }
    }
}
