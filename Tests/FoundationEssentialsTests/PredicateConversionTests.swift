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

final class NSPredicateConversionTests: XCTestCase {
    private func convert<T: NSObject>(_ predicate: Predicate<T>) -> NSPredicate? {
        NSPredicate(predicate)
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
    
    func testBasics() {
        let obj = ObjCObject()
        let compareTo = 2
        var predicate = #Predicate<ObjCObject> {
            $0.a == compareTo
        }
        var converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "a == 2"))
        XCTAssertFalse(converted!.evaluate(with: obj))
        
        predicate = #Predicate<ObjCObject> {
            $0.a + 2 == 4
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "a + 2 == 4"))
        XCTAssertFalse(converted!.evaluate(with: obj))
        
        predicate = #Predicate<ObjCObject> {
            $0.b.count == 5
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "b.length == 5"))
        XCTAssertTrue(converted!.evaluate(with: obj))
        
        predicate = #Predicate<ObjCObject> {
            $0.g.count == 5
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "g.@count == 5"))
        XCTAssertTrue(converted!.evaluate(with: obj))
        
        predicate = #Predicate<ObjCObject> { object in
            object.g.filter {
                $0 == object.d
            }.count > 0
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "SUBQUERY(g, $_local_1, $_local_1 == d).@count > 0"))
        XCTAssertFalse(converted!.evaluate(with: obj))
    }
    
    func testEquality() {
        var predicate = #Predicate<ObjCObject> {
            $0.a == 0
        }
        var converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "a == 0"))
        XCTAssertFalse(converted!.evaluate(with: ObjCObject()))
        
        predicate = #Predicate<ObjCObject> {
            $0.a != 0
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "a != 0"))
        XCTAssertTrue(converted!.evaluate(with: ObjCObject()))
    }
    
    func testRanges() {
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
        var converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "i BETWEEN {i, i}"))
        XCTAssertTrue(converted!.evaluate(with: ObjCObject()))
        
        // Non-closed Range Operator
        predicate = #Predicate<ObjCObject> {
            ($0.i ..< $0.i).contains($0.i)
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "i >= i AND i < i"))
        XCTAssertFalse(converted!.evaluate(with: ObjCObject()))
        
        // Various values
        predicate = #Predicate<ObjCObject> {
            range.contains($0.i)
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "i >= %@ AND i < %@", now as NSDate, now as NSDate))
        XCTAssertFalse(converted!.evaluate(with: ObjCObject()))
        predicate = #Predicate<ObjCObject> {
            closedRange.contains($0.i)
        }
        converted = convert(predicate)
        let other = NSPredicate(format: "i BETWEEN %@", [now, now])
        XCTAssertEqual(converted, other)
        XCTAssertFalse(converted!.evaluate(with: ObjCObject()))
        predicate = #Predicate<ObjCObject> {
            from.contains($0.i)
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "i >= %@", now as NSDate))
        XCTAssertTrue(converted!.evaluate(with: ObjCObject()))
        predicate = #Predicate<ObjCObject> {
            through.contains($0.i)
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "i <= %@", now as NSDate))
        XCTAssertFalse(converted!.evaluate(with: ObjCObject()))
        predicate = #Predicate<ObjCObject> {
            upTo.contains($0.i)
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "i < %@", now as NSDate))
        XCTAssertFalse(converted!.evaluate(with: ObjCObject()))
    }
    
    func testNonObjC() {
        let predicate = #Predicate<ObjCObject> {
            $0.nonObjCKeypath == 2
        }
        XCTAssertNil(convert(predicate))
    }
    
    func testNonObjCConstantKeyPath() {
        let nonObjC = NonObjCStruct(a: 1, b: [1, 2, 3])
        var predicate = #Predicate<ObjCObject> {
            $0.a == nonObjC.a
        }
        var converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "a == 1"))
        XCTAssertTrue(converted!.evaluate(with: ObjCObject()))
        
        
        predicate = #Predicate<ObjCObject> {
            $0.f == nonObjC.b.contains([1, 2])
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "f == YES"))
        XCTAssertTrue(converted!.evaluate(with: ObjCObject()))
    }
    
    func testSubscripts() {
        let obj = ObjCObject()
        var predicate = #Predicate<ObjCObject> {
            $0.g[0] == 2
        }
        var converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "(SELF.g)[0] == 2"))
        XCTAssertFalse(converted!.evaluate(with: obj))
        
        predicate = #Predicate<ObjCObject> {
            $0.h["A"] == 1
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "(SELF.h)['A'] == 1"))
        XCTAssertTrue(converted!.evaluate(with: obj))
    }
    
    func testStringSearching() {
        let obj = ObjCObject()
        var predicate = #Predicate<ObjCObject> {
            $0.b.contains("foo")
        }
        var converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "b CONTAINS 'foo'"))
        XCTAssertFalse(converted!.evaluate(with: obj))
        
        
        predicate = #Predicate<ObjCObject> {
            $0.b.starts(with: "foo")
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "b BEGINSWITH 'foo'"))
        XCTAssertFalse(converted!.evaluate(with: obj))
    }
    
    func testExpressionEnforcement() {
        var predicate = #Predicate<ObjCObject> { _ in
            true
        }
        var converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "YES == YES"))
        XCTAssertTrue(converted!.evaluate(with: "Hello"))
        
        predicate = #Predicate<ObjCObject> { _ in
            false
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "NO == YES"))
        XCTAssertFalse(converted!.evaluate(with: "Hello"))
        
        predicate = #Predicate<ObjCObject> { _ in
            true && false
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "(YES == YES) && (NO == YES)"))
        XCTAssertFalse(converted!.evaluate(with: "Hello"))
        
        predicate = #Predicate<ObjCObject> {
            $0.f
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "f == YES"))
        XCTAssertTrue(converted!.evaluate(with: ObjCObject()))
        
        predicate = #Predicate<ObjCObject> {
            ($0.f && true) == false
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "TERNARY(f == YES AND YES == YES, YES, NO) == NO"))
        XCTAssertFalse(converted!.evaluate(with: ObjCObject()))
    }
    
    func testConditional() {
        let predicate = #Predicate<ObjCObject> {
            $0.f ? true : false
        }
        let converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "TERNARY(f == YES, YES, NO) == YES"))
        XCTAssertTrue(converted!.evaluate(with: ObjCObject()))
    }
    
    func testOptionals() {
        var predicate = #Predicate<ObjCObject> {
            ($0.j ?? "").isEmpty
        }
        var converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "TERNARY(j != NULL, j, '').length == 0"))
        XCTAssertTrue(converted!.evaluate(with: ObjCObject()))
        
        predicate = #Predicate<ObjCObject> {
            ($0.j?.count ?? -1) > 1
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "TERNARY(TERNARY(j != nil, j.length, nil) != nil, TERNARY(j != nil, j.length, nil), 1 * -1) > 1"))
        XCTAssertFalse(converted!.evaluate(with: ObjCObject()))
        
        predicate = #Predicate<ObjCObject> {
            $0.j == nil
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "j == nil"))
        XCTAssertTrue(converted!.evaluate(with: ObjCObject()))
    }
    
    func testUUID() {
        let obj = ObjCObject()
        let uuid = obj.k
        let predicate = #Predicate<ObjCObject> {
            $0.k == uuid
        }
        
        let converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "k == %@", uuid as NSUUID))
        XCTAssertTrue(converted!.evaluate(with: obj))
        let obj2 = ObjCObject()
        XCTAssertNotEqual(obj2.k, uuid)
        XCTAssertFalse(converted!.evaluate(with: obj2))
    }
    
    func testDate() {
        let now = Date.now
        let predicate = #Predicate<ObjCObject> {
            $0.i > now
        }
        
        let converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "i > %@", now as NSDate))
        XCTAssertTrue(converted!.evaluate(with: ObjCObject()))
    }
    
    func testData() {
        let data = Data([1, 2, 3])
        let predicate = #Predicate<ObjCObject> {
            $0.l == data
        }
        let converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "l == %@", data as NSData))
        XCTAssertTrue(converted!.evaluate(with: ObjCObject()))
    }
    
    func testURL() {
        let url = URL(string: "http://apple.com")!
        let predicate = #Predicate<ObjCObject> {
            $0.m == url
        }
        let converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "m == %@", url as NSURL))
        XCTAssertTrue(converted!.evaluate(with: ObjCObject()))
    }
    
    func testSequenceContainsWhere() {
        let predicate = #Predicate<ObjCObject> {
            $0.g.contains { $0 == 2 }
        }
        let converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "SUBQUERY(g, $_local_1, $_local_1 == 2).@count != 0"))
        XCTAssertFalse(converted!.evaluate(with: ObjCObject()))
    }
    
    func testSequenceAllSatisfy() {
        let predicate = #Predicate<ObjCObject> {
            $0.g.allSatisfy { $0 == 2 }
        }
        let converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "SUBQUERY(g, $_local_1, NOT ($_local_1 == 2)).@count == 0"))
        XCTAssertFalse(converted!.evaluate(with: ObjCObject()))
    }
    
    func testMaxMin() {
        let predicate = #Predicate<ObjCObject> {
            $0.g.max() == $0.g.min()
        }
        
        let converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "g.@max.#self == g.@min.#self"))
        XCTAssertFalse(converted!.evaluate(with: ObjCObject()))
    }
    
    func testStringComparison() {
        let equal = ComparisonResult.orderedSame
        var predicate = #Predicate<ObjCObject> {
            $0.b.caseInsensitiveCompare("ABC") == equal
        }
        
        var converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "TERNARY(b ==[c] 'ABC', 0, TERNARY(b <[c] 'ABC', -1, 1)) == 0"))
        XCTAssertFalse(converted!.evaluate(with: ObjCObject()))
        
        predicate = #Predicate<ObjCObject> {
            $0.b.localizedCompare("ABC") == equal
        }
        
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "TERNARY(b ==[l] 'ABC', 0, TERNARY(b <[l] 'ABC', -1, 1)) == 0"))
        XCTAssertFalse(converted!.evaluate(with: ObjCObject()))
        
        predicate = #Predicate<ObjCObject> {
            $0.b.localizedStandardContains("ABC")
        }
        
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "b CONTAINS[cdl] 'ABC'"))
        XCTAssertFalse(converted!.evaluate(with: ObjCObject()))
    }
    
    func testNested() {
        let predicateA = Predicate<ObjCObject> {
            PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_KeyPath(
                    root: PredicateExpressions.build_Arg($0),
                    keyPath: \.a
                ),
                rhs: PredicateExpressions.build_Arg(3)
            )
        }
        
        let predicateB = Predicate<ObjCObject> {
            PredicateExpressions.build_Conjunction(
                lhs: PredicateExpressions.build_evaluate(
                    PredicateExpressions.build_Arg(predicateA),
                    PredicateExpressions.build_Arg($0)
                ),
                rhs: PredicateExpressions.build_Comparison(
                    lhs: PredicateExpressions.build_KeyPath(
                        root: PredicateExpressions.build_Arg($0),
                        keyPath: \.a
                    ),
                    rhs: PredicateExpressions.build_Arg(2),
                    op: .greaterThan
                )
            )
        }
        
        let converted = convert(predicateB)
        XCTAssertEqual(converted, NSPredicate(format: "a == 3 AND a > 2"))
        XCTAssertFalse(converted!.evaluate(with: ObjCObject()))
    }
    
    func testRegex() {
        let regex = #/[AB0-9]\/?[^\n]+/#
        let predicate = #Predicate<ObjCObject> {
            $0.b.contains(regex)
        }
        let converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "b MATCHES '[AB0-9]\\/?[^\\n]+'"))
        XCTAssertFalse(converted!.evaluate(with: ObjCObject()))
    }
}

#endif
