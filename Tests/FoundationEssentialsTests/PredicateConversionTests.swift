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

#if FOUNDATION_FRAMEWORK

import Testing
import Foundation

struct NSPredicateConversionTests {
    private func convert<T: NSObject>(_ predicate: Predicate<T>) -> NSPredicate? {
        NSPredicate(predicate)
    }
    
    private func convert<T: NSObject, U>(_ expression: Expression<T, U>) -> NSExpression? {
        NSExpression(expression)
    }
    
    @objc class ObjCObject: NSObject {
        @objc var a: Int
        @objc var b: String
        @objc var c: Double
        @objc var d: Int
        @objc var f: Bool
        @objc var g: [Int]
        @objc var h: [String : Int]
        @objc var i: Date
        @objc var j: String?
        @objc var k: UUID
        @objc var l: Data
        @objc var m: URL
        var nonObjCKeypath: Int
        
        override init() {
            a = 1
            b = "Hello"
            c = 2.3
            d = 4
            f = true
            g = [5, 6, 7, 8, 9]
            h = ["A" : 1, "B" : 2]
            i = Date.distantFuture
            j = nil
            k = UUID()
            l = Data([1, 2, 3])
            m = URL(string: "http://apple.com")!
            nonObjCKeypath = 8
            super.init()
        }
    }
    
    struct NonObjCStruct : Codable, Sendable {
        var a: Int
        var b: [Int]
    }
    
    @Test func testBasics() throws {
        let obj = ObjCObject()
        let compareTo = 2
        var predicate = #Predicate<ObjCObject> {
            $0.a == compareTo
        }
        var converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "a == 2"))
        #expect(!converted.evaluate(with: obj))
        
        predicate = #Predicate<ObjCObject> {
            $0.a + 2 == 4
        }
        converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "a + 2 == 4"))
        #expect(!converted.evaluate(with: obj))
        
        predicate = #Predicate<ObjCObject> {
            $0.b.count == 5
        }
        converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "b.length == 5"))
        #expect(converted.evaluate(with: obj))
        
        predicate = #Predicate<ObjCObject> {
            $0.g.count == 5
        }
        converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "g.@count == 5"))
        #expect(converted.evaluate(with: obj))
        
        predicate = #Predicate<ObjCObject> { object in
            object.g.filter {
                $0 == object.d
            }.count > 0
        }
        converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "SUBQUERY(g, $_local_1, $_local_1 == d).@count > 0"))
        #expect(!converted.evaluate(with: obj))
    }
    
    @Test func testEquality() throws {
        var predicate = #Predicate<ObjCObject> {
            $0.a == 0
        }
        var converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "a == 0"))
        #expect(!converted.evaluate(with: ObjCObject()))
        
        predicate = #Predicate<ObjCObject> {
            $0.a != 0
        }
        converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "a != 0"))
        #expect(converted.evaluate(with: ObjCObject()))
    }
    
    @Test func testRanges() throws {
        let now = Date.now
        let range = now ..< now
        let closedRange = now ... now
        let from = now...
        let through = ...now
        let upTo = ..<now
        
        // Closed Range Operator
        var predicate = #Predicate<ObjCObject> {
            ($0.i ... $0.i).contains($0.i)
        }
        var converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "i BETWEEN {i, i}"))
        #expect(converted.evaluate(with: ObjCObject()))
        
        // Non-closed Range Operator
        predicate = #Predicate<ObjCObject> {
            ($0.i ..< $0.i).contains($0.i)
        }
        converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "i >= i AND i < i"))
        #expect(!converted.evaluate(with: ObjCObject()))
        
        // Various values
        predicate = #Predicate<ObjCObject> {
            range.contains($0.i)
        }
        converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "i >= %@ AND i < %@", now as NSDate, now as NSDate))
        #expect(!converted.evaluate(with: ObjCObject()))
        predicate = #Predicate<ObjCObject> {
            closedRange.contains($0.i)
        }
        converted = try #require(convert(predicate))
        let other = NSPredicate(format: "i BETWEEN %@", [now, now])
        #expect(converted == other)
        #expect(!converted.evaluate(with: ObjCObject()))
        predicate = #Predicate<ObjCObject> {
            from.contains($0.i)
        }
        converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "i >= %@", now as NSDate))
        #expect(converted.evaluate(with: ObjCObject()))
        predicate = #Predicate<ObjCObject> {
            through.contains($0.i)
        }
        converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "i <= %@", now as NSDate))
        #expect(!converted.evaluate(with: ObjCObject()))
        predicate = #Predicate<ObjCObject> {
            upTo.contains($0.i)
        }
        converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "i < %@", now as NSDate))
        #expect(!converted.evaluate(with: ObjCObject()))
    }
    
    @Test func testNonObjC() {
        let predicate = #Predicate<ObjCObject> {
            $0.nonObjCKeypath == 2
        }
        #expect(convert(predicate) == nil)
    }
    
    @Test func testNonObjCConstantKeyPath() throws {
        let nonObjC = NonObjCStruct(a: 1, b: [1, 2, 3])
        var predicate = #Predicate<ObjCObject> {
            $0.a == nonObjC.a
        }
        var converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "a == 1"))
        #expect(converted.evaluate(with: ObjCObject()))
        
        
        predicate = #Predicate<ObjCObject> {
            $0.f == nonObjC.b.contains([1, 2])
        }
        converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "f == YES"))
        #expect(converted.evaluate(with: ObjCObject()))
    }
    
    @Test func testSubscripts() throws {
        let obj = ObjCObject()
        var predicate = #Predicate<ObjCObject> {
            $0.g[0] == 2
        }
        var converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "(SELF.g)[0] == 2"))
        #expect(!converted.evaluate(with: obj))
        
        predicate = #Predicate<ObjCObject> {
            $0.h["A"] == 1
        }
        converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "(SELF.h)['A'] == 1"))
        #expect(converted.evaluate(with: obj))
    }
    
    @Test func testStringSearching() throws {
        let obj = ObjCObject()
        var predicate = #Predicate<ObjCObject> {
            $0.b.contains("foo")
        }
        var converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "b CONTAINS 'foo'"))
        #expect(!converted.evaluate(with: obj))
        
        
        predicate = #Predicate<ObjCObject> {
            $0.b.starts(with: "foo")
        }
        converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "b BEGINSWITH 'foo'"))
        #expect(!converted.evaluate(with: obj))
    }
    
    @Test func testExpressionEnforcement() throws {
        var predicate = #Predicate<ObjCObject> { _ in
            true
        }
        var converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "YES == YES"))
        #expect(converted.evaluate(with: "Hello"))
        
        predicate = #Predicate<ObjCObject> { _ in
            false
        }
        converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "NO == YES"))
        #expect(!converted.evaluate(with: "Hello"))
        
        predicate = #Predicate<ObjCObject> { _ in
            true && false
        }
        converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "(YES == YES) && (NO == YES)"))
        #expect(!converted.evaluate(with: "Hello"))
        
        predicate = #Predicate<ObjCObject> {
            $0.f
        }
        converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "f == YES"))
        #expect(converted.evaluate(with: ObjCObject()))
        
        predicate = #Predicate<ObjCObject> {
            ($0.f && true) == false
        }
        converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "TERNARY(f == YES AND YES == YES, YES, NO) == NO"))
        #expect(!converted.evaluate(with: ObjCObject()))
    }
    
    @Test func testConditional() throws {
        let predicate = #Predicate<ObjCObject> {
            $0.f ? true : false
        }
        let converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "TERNARY(f == YES, YES, NO) == YES"))
        #expect(converted.evaluate(with: ObjCObject()))
    }
    
    @Test func testOptionals() throws {
        var predicate = #Predicate<ObjCObject> {
            ($0.j ?? "").isEmpty
        }
        var converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "TERNARY(j != NULL, j, '').length == 0"))
        #expect(converted.evaluate(with: ObjCObject()))
        
        predicate = #Predicate<ObjCObject> {
            ($0.j?.count ?? -1) > 1
        }
        converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "TERNARY(TERNARY(j != nil, j.length, nil) != nil, TERNARY(j != nil, j.length, nil), 1 * -1) > 1"))
        #expect(!converted.evaluate(with: ObjCObject()))
        
        predicate = #Predicate<ObjCObject> {
            $0.j == nil
        }
        converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "j == nil"))
        #expect(converted.evaluate(with: ObjCObject()))
    }
    
    @Test func testUUID() throws {
        let obj = ObjCObject()
        let uuid = obj.k
        let predicate = #Predicate<ObjCObject> {
            $0.k == uuid
        }
        
        let converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "k == %@", uuid as NSUUID))
        #expect(converted.evaluate(with: obj))
        let obj2 = ObjCObject()
        #expect(obj2.k != uuid)
        #expect(!converted.evaluate(with: obj2))
    }
    
    @Test func testDate() throws {
        let now = Date.now
        let predicate = #Predicate<ObjCObject> {
            $0.i > now
        }
        
        let converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "i > %@", now as NSDate))
        #expect(converted.evaluate(with: ObjCObject()))
    }
    
    @Test func testData() throws {
        let data = Data([1, 2, 3])
        let predicate = #Predicate<ObjCObject> {
            $0.l == data
        }
        let converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "l == %@", data as NSData))
        #expect(converted.evaluate(with: ObjCObject()))
    }
    
    @Test func testURL() throws {
        let url = URL(string: "http://apple.com")!
        let predicate = #Predicate<ObjCObject> {
            $0.m == url
        }
        let converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "m == %@", url as NSURL))
        #expect(converted.evaluate(with: ObjCObject()))
    }
    
    @Test func testSequenceContainsWhere() throws {
        let predicate = #Predicate<ObjCObject> {
            $0.g.contains { $0 == 2 }
        }
        let converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "SUBQUERY(g, $_local_1, $_local_1 == 2).@count != 0"))
        #expect(!converted.evaluate(with: ObjCObject()))
    }
    
    @Test func testSequenceAllSatisfy() throws {
        let predicate = #Predicate<ObjCObject> {
            $0.g.allSatisfy { $0 == 2 }
        }
        let converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "SUBQUERY(g, $_local_1, NOT ($_local_1 == 2)).@count == 0"))
        #expect(!converted.evaluate(with: ObjCObject()))
    }
    
    @Test func testMaxMin() throws {
        let predicate = #Predicate<ObjCObject> {
            $0.g.max() == $0.g.min()
        }
        
        let converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "g.@max.#self == g.@min.#self"))
        #expect(!converted.evaluate(with: ObjCObject()))
    }
    
    @Test func testStringComparison() throws {
        let equal = ComparisonResult.orderedSame
        var predicate = #Predicate<ObjCObject> {
            $0.b.caseInsensitiveCompare("ABC") == equal
        }
        
        var converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "TERNARY(b ==[c] 'ABC', 0, TERNARY(b <[c] 'ABC', -1, 1)) == 0"))
        #expect(!converted.evaluate(with: ObjCObject()))
        
        predicate = #Predicate<ObjCObject> {
            $0.b.localizedCompare("ABC") == equal
        }
        
        converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "TERNARY(b ==[l] 'ABC', 0, TERNARY(b <[l] 'ABC', -1, 1)) == 0"))
        #expect(!converted.evaluate(with: ObjCObject()))
        
        predicate = #Predicate<ObjCObject> {
            $0.b.localizedStandardContains("ABC")
        }
        
        converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "b CONTAINS[cdl] 'ABC'"))
        #expect(!converted.evaluate(with: ObjCObject()))
    }
    
    @Test func testNested() throws {
        let predicateA = #Predicate<ObjCObject> {
            $0.a == 3
        }
        
        let predicateB = #Predicate<ObjCObject> {
            predicateA.evaluate($0) && $0.a > 2
        }
        
        let converted = try #require(convert(predicateB))
        #expect(converted == NSPredicate(format: "a == 3 AND a > 2"))
        #expect(!converted.evaluate(with: ObjCObject()))
    }
    
    @Test func testRegex() throws {
        let regex = #/[e-f][l-m]/#
        let predicate = #Predicate<ObjCObject> {
            $0.b.contains(regex)
        }
        let converted = try #require(convert(predicate))
        #expect(converted == NSPredicate(format: "b MATCHES '.*[e-f][l-m].*'"))
        #expect(converted.evaluate(with: ObjCObject()))
    }
    
    @Test func testExpression() throws {
        let expression = #Expression<ObjCObject, Int> {
            $0.a
        }
        let converted = try #require(convert(expression))
        #expect(converted == NSExpression(format: "a"))
        let obj = ObjCObject()
        let value = converted.expressionValue(with: obj, context: nil)
        #expect(value as? Int == obj.a, "Expression produced \(String(describing: value)) instead of \(obj.a)")
    }
}

#endif
