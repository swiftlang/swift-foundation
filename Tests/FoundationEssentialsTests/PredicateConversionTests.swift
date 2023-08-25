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
        var predicate = Predicate<ObjCObject> {
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
        var converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "a == 2"))
        XCTAssertFalse(converted!.evaluate(with: obj))
        
        predicate = Predicate<ObjCObject> {
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
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "a + 2 == 4"))
        XCTAssertFalse(converted!.evaluate(with: obj))
        
        predicate = Predicate<ObjCObject> {
            // $0.b.count == 5
            PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_Arg(
                    PredicateExpressions.build_KeyPath(
                        root: PredicateExpressions.build_KeyPath(
                            root: $0,
                            keyPath: \.b
                        ),
                        keyPath: \.count
                    )
                ),
                rhs: PredicateExpressions.build_Arg(5)
            )
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "b.length == 5"))
        XCTAssertTrue(converted!.evaluate(with: obj))
        
        predicate = Predicate<ObjCObject> {
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
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "g.@count == 5"))
        XCTAssertTrue(converted!.evaluate(with: obj))
        
        predicate = Predicate<ObjCObject> { object in
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
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "SUBQUERY(g, $_local_1, $_local_1 == d).@count > 0"))
        XCTAssertFalse(converted!.evaluate(with: obj))
    }
    
    func testEquality() {
        var predicate = Predicate<ObjCObject> {
            // $0.a == 0
            PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_KeyPath(
                    root: PredicateExpressions.build_Arg($0),
                    keyPath: \.a
                ),
                rhs: PredicateExpressions.build_Arg(0)
            )
        }
        var converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "a == 0"))
        XCTAssertFalse(converted!.evaluate(with: ObjCObject()))
        
        predicate = Predicate<ObjCObject> {
            // $0.a != 0
            PredicateExpressions.build_NotEqual(
                lhs: PredicateExpressions.build_KeyPath(
                    root: PredicateExpressions.build_Arg($0),
                    keyPath: \.a
                ),
                rhs: PredicateExpressions.build_Arg(0)
            )
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "a != 0"))
        XCTAssertTrue(converted!.evaluate(with: ObjCObject()))
    }
    
    func testRanges() {
        let now = Date.now
        let range = now ..< now
        let intRange = 0 ..< 2
        let closedRange = now ... now
        let from = now...
        let through = ...now
        let upTo = ..<now
        
        // Closed Range Operator
        var predicate = Predicate<ObjCObject> {
            // ($0.i ... $0.i).contains($0.i)
            PredicateExpressions.build_contains(
                PredicateExpressions.build_ClosedRange(
                    lower: PredicateExpressions.build_KeyPath(
                        root: PredicateExpressions.build_Arg($0),
                        keyPath: \.i
                    ),
                    upper: PredicateExpressions.build_KeyPath(
                        root: PredicateExpressions.build_Arg($0),
                        keyPath: \.i
                    )
                ),
                PredicateExpressions.build_KeyPath(
                    root: PredicateExpressions.build_Arg($0),
                    keyPath: \.i
                )
            )
        }
        var converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "i BETWEEN {i, i}"))
        XCTAssertTrue(converted!.evaluate(with: ObjCObject()))
        
        // Non-closed Range Operator
        predicate = Predicate<ObjCObject> {
            // ($0.i ..< $0.i).contains($0.i)
            PredicateExpressions.build_contains(
                PredicateExpressions.build_Range(
                    lower: PredicateExpressions.build_KeyPath(
                        root: PredicateExpressions.build_Arg($0),
                        keyPath: \.i
                    ),
                    upper: PredicateExpressions.build_KeyPath(
                        root: PredicateExpressions.build_Arg($0),
                        keyPath: \.i
                    )
                ),
                PredicateExpressions.build_KeyPath(
                    root: PredicateExpressions.build_Arg($0),
                    keyPath: \.i
                )
            )
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "i >= i AND i < i"))
        XCTAssertFalse(converted!.evaluate(with: ObjCObject()))
        
        // Various values
        predicate = Predicate<ObjCObject> {
            // range.contains($0.i)
            PredicateExpressions.build_contains(
                PredicateExpressions.build_Arg(range),
                PredicateExpressions.build_KeyPath(
                    root: PredicateExpressions.build_Arg($0),
                    keyPath: \.i
                )
            )
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "i >= %@ AND i < %@", now as NSDate, now as NSDate))
        XCTAssertFalse(converted!.evaluate(with: ObjCObject()))
        predicate = Predicate<ObjCObject> {
            // closedRange.contains($0.i)
            PredicateExpressions.build_contains(
                PredicateExpressions.build_Arg(closedRange),
                PredicateExpressions.build_KeyPath(
                    root: PredicateExpressions.build_Arg($0),
                    keyPath: \.i
                )
            )
        }
        converted = convert(predicate)
        let other = NSPredicate(format: "i BETWEEN %@", [now, now])
        XCTAssertEqual(converted, other)
        XCTAssertFalse(converted!.evaluate(with: ObjCObject()))
        predicate = Predicate<ObjCObject> {
            // from.contains($0.i)
            PredicateExpressions.build_contains(
                PredicateExpressions.build_Arg(from),
                PredicateExpressions.build_KeyPath(
                    root: PredicateExpressions.build_Arg($0),
                    keyPath: \.i
                )
            )
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "i >= %@", now as NSDate))
        XCTAssertTrue(converted!.evaluate(with: ObjCObject()))
        predicate = Predicate<ObjCObject> {
            // through.contains($0.i)
            PredicateExpressions.build_contains(
                PredicateExpressions.build_Arg(through),
                PredicateExpressions.build_KeyPath(
                    root: PredicateExpressions.build_Arg($0),
                    keyPath: \.i
                )
            )
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "i <= %@", now as NSDate))
        XCTAssertFalse(converted!.evaluate(with: ObjCObject()))
        predicate = Predicate<ObjCObject> {
            // upTo.contains($0.i)
            PredicateExpressions.build_contains(
                PredicateExpressions.build_Arg(upTo),
                PredicateExpressions.build_KeyPath(
                    root: PredicateExpressions.build_Arg($0),
                    keyPath: \.i
                )
            )
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "i < %@", now as NSDate))
        XCTAssertFalse(converted!.evaluate(with: ObjCObject()))
    }
    
    func testNonObjC() {
        let predicate = Predicate<ObjCObject> {
            // $0.nonObjCKeypath == 2
            PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_Arg(
                    PredicateExpressions.build_KeyPath(
                        root: $0,
                        keyPath: \.nonObjCKeypath
                    )
                ),
                rhs: PredicateExpressions.build_Arg(2)
            )
        }
        XCTAssertNil(convert(predicate))
    }
    
    func testNonObjCConstantKeyPath() {
        let nonObjC = NonObjCStruct(a: 1, b: [1, 2, 3])
        var predicate = Predicate<ObjCObject> {
            // $0.a == nonObjC.a
            PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_KeyPath(
                    root: $0,
                    keyPath: \.a
                ),
                rhs: PredicateExpressions.build_KeyPath(
                    root: PredicateExpressions.build_Arg(nonObjC),
                    keyPath: \.a
                )
            )
        }
        var converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "a == 1"))
        XCTAssertTrue(converted!.evaluate(with: ObjCObject()))
        
        
        predicate = Predicate<ObjCObject> {
            // $0.f == nonObjC.b.contains([1, 2])
            PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_KeyPath(
                    root: $0,
                    keyPath: \.f
                ),
                rhs: PredicateExpressions.build_contains(
                    PredicateExpressions.build_KeyPath(
                        root: PredicateExpressions.build_Arg(nonObjC),
                        keyPath: \.b
                    ),
                    PredicateExpressions.build_Arg([1, 2])
                )
            )
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "f == YES"))
        XCTAssertTrue(converted!.evaluate(with: ObjCObject()))
    }
    
    func testSubscripts() {
        let obj = ObjCObject()
        var predicate = Predicate<ObjCObject> {
            // $0.g[0] == 2
            PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_subscript(
                    PredicateExpressions.build_KeyPath(
                        root: $0,
                        keyPath: \.g
                    ),
                    PredicateExpressions.build_Arg(0)
                ),
                rhs: PredicateExpressions.build_Arg(2)
            )
        }
        var converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "(SELF.g)[0] == 2"))
        XCTAssertFalse(converted!.evaluate(with: obj))
        
        predicate = Predicate<ObjCObject> {
            // $0.h["A"] == 1
            PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_subscript(
                    PredicateExpressions.build_KeyPath(
                        root: $0,
                        keyPath: \.h
                    ),
                    PredicateExpressions.build_Arg("A")
                ),
                rhs: PredicateExpressions.build_Arg(1)
            )
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "(SELF.h)['A'] == 1"))
        XCTAssertTrue(converted!.evaluate(with: obj))
    }
    
    func testStringSearching() {
        let obj = ObjCObject()
        var predicate = Predicate<ObjCObject> {
            // $0.b.contains("foo")
            PredicateExpressions.build_contains(
                PredicateExpressions.build_KeyPath(
                    root: $0,
                    keyPath: \.b
                ),
                PredicateExpressions.build_Arg("foo")
            )
        }
        var converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "b CONTAINS 'foo'"))
        XCTAssertFalse(converted!.evaluate(with: obj))
        
        
        predicate = Predicate<ObjCObject> {
            // $0.b.contains("foo")
            PredicateExpressions.build_starts(
                PredicateExpressions.build_KeyPath(
                    root: $0,
                    keyPath: \.b
                ),
                with: PredicateExpressions.build_Arg("foo")
            )
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "b BEGINSWITH 'foo'"))
        XCTAssertFalse(converted!.evaluate(with: obj))
    }
    
    func testExpressionEnforcement() {
        var predicate = Predicate<ObjCObject> { _ in
            PredicateExpressions.build_Arg(true)
        }
        var converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "YES == YES"))
        XCTAssertTrue(converted!.evaluate(with: "Hello"))
        
        predicate = Predicate<ObjCObject> { _ in
            PredicateExpressions.build_Arg(false)
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "NO == YES"))
        XCTAssertFalse(converted!.evaluate(with: "Hello"))
        
        predicate = Predicate<ObjCObject> { _ in
            PredicateExpressions.build_Conjunction(
                lhs: PredicateExpressions.build_Arg(true),
                rhs: PredicateExpressions.build_Arg(false)
            )
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "(YES == YES) && (NO == YES)"))
        XCTAssertFalse(converted!.evaluate(with: "Hello"))
        
        predicate = Predicate<ObjCObject> {
            PredicateExpressions.build_KeyPath(
                root: PredicateExpressions.build_Arg($0),
                keyPath: \.f
            )
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "f == YES"))
        XCTAssertTrue(converted!.evaluate(with: ObjCObject()))
        
        predicate = Predicate<ObjCObject> {
            PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_Conjunction(
                    lhs: PredicateExpressions.build_KeyPath(
                        root: $0,
                        keyPath: \.f
                    ),
                    rhs: PredicateExpressions.build_Arg(true)
                ),
                rhs: PredicateExpressions.build_Arg(false)
            )
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "TERNARY(f == YES AND YES == YES, YES, NO) == NO"))
        XCTAssertFalse(converted!.evaluate(with: ObjCObject()))
    }
    
    func testConditional() {
        let predicate = Predicate<ObjCObject> {
            PredicateExpressions.build_Conditional(
                PredicateExpressions.build_KeyPath(
                    root: PredicateExpressions.build_Arg($0),
                    keyPath: \.f
                ),
                PredicateExpressions.build_Arg(true),
                PredicateExpressions.build_Arg(false)
            )
        }
        let converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "TERNARY(f == YES, YES, NO) == YES"))
        XCTAssertTrue(converted!.evaluate(with: ObjCObject()))
    }
    
    func testOptionals() {
        var predicate = Predicate<ObjCObject> {
            PredicateExpressions.build_KeyPath(
                root: PredicateExpressions.build_NilCoalesce(
                    lhs: PredicateExpressions.build_KeyPath(
                        root: PredicateExpressions.build_Arg($0),
                        keyPath: \.j
                    ),
                    rhs: PredicateExpressions.build_Arg("")
                ),
                keyPath: \.isEmpty
            )
        }
        var converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "TERNARY(j != NULL, j, '').length == 0"))
        XCTAssertTrue(converted!.evaluate(with: ObjCObject()))
        
        predicate = Predicate<ObjCObject> {
            // ($0.j?.count ?? -1) > 1
            PredicateExpressions.build_Comparison(
                lhs: PredicateExpressions.build_NilCoalesce(
                    lhs: PredicateExpressions.build_flatMap(
                        PredicateExpressions.build_KeyPath(
                            root: PredicateExpressions.build_Arg($0),
                            keyPath: \.j
                        ),
                        {
                            PredicateExpressions.build_KeyPath(
                                root: PredicateExpressions.build_Arg($0),
                                keyPath: \.count
                            )
                        }
                    ),
                    rhs: PredicateExpressions.build_Arg(-1)
                ),
                rhs: PredicateExpressions.build_Arg(1),
                op: .greaterThan
            )
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "TERNARY(TERNARY(j != nil, j.length, nil) != nil, TERNARY(j != nil, j.length, nil), -1) > 1"))
        XCTAssertFalse(converted!.evaluate(with: ObjCObject()))
        
        predicate = Predicate<ObjCObject> {
            // $0.j == nil
            PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_KeyPath(
                    root: PredicateExpressions.build_Arg($0),
                    keyPath: \.j
                ),
                rhs: PredicateExpressions.build_NilLiteral()
            )
        }
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "j == nil"))
        XCTAssertTrue(converted!.evaluate(with: ObjCObject()))
    }
    
    func testUUID() {
        let obj = ObjCObject()
        let uuid = obj.k
        let predicate = Predicate<ObjCObject> {
            PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_KeyPath(
                    root: PredicateExpressions.build_Arg($0),
                    keyPath: \.k
                ),
                rhs: PredicateExpressions.build_Arg(uuid)
            )
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
        let predicate = Predicate<ObjCObject> {
            PredicateExpressions.build_Comparison(
                lhs: PredicateExpressions.build_KeyPath(
                    root: PredicateExpressions.build_Arg($0),
                    keyPath: \.i
                ),
                rhs: PredicateExpressions.build_Arg(now),
                op: .greaterThan
            )
        }
        
        let converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "i > %@", now as NSDate))
        XCTAssertTrue(converted!.evaluate(with: ObjCObject()))
    }
    
    func testData() {
        let data = Data([1, 2, 3])
        let predicate = Predicate<ObjCObject> {
            PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_KeyPath(
                    root: PredicateExpressions.build_Arg($0),
                    keyPath: \.l
                ),
                rhs: PredicateExpressions.build_Arg(data)
            )
        }
        let converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "l == %@", data as NSData))
        XCTAssertTrue(converted!.evaluate(with: ObjCObject()))
    }
    
    func testSequenceContainsWhere() {
        let predicate = Predicate<ObjCObject> {
            // $0.g.contains { $0 == 2 }
            PredicateExpressions.build_contains(
                PredicateExpressions.build_KeyPath(
                    root: PredicateExpressions.build_Arg($0),
                    keyPath: \.g
                )
            ) {
                PredicateExpressions.build_Equal(
                    lhs: PredicateExpressions.build_Arg($0),
                    rhs: PredicateExpressions.build_Arg(2)
                )
            }
        }
        let converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "SUBQUERY(g, $_local_1, $_local_1 == 2).@count != 0"))
        XCTAssertFalse(converted!.evaluate(with: ObjCObject()))
    }
    
    func testSequenceAllSatisfy() {
        let predicate = Predicate<ObjCObject> {
            // $0.g.allSatisfy { $0 == 2 }
            PredicateExpressions.build_allSatisfy(
                PredicateExpressions.build_KeyPath(
                    root: PredicateExpressions.build_Arg($0),
                    keyPath: \.g
                )
            ) {
                PredicateExpressions.build_Equal(
                    lhs: PredicateExpressions.build_Arg($0),
                    rhs: PredicateExpressions.build_Arg(2)
                )
            }
        }
        let converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "SUBQUERY(g, $_local_1, NOT ($_local_1 == 2)).@count == 0"))
        XCTAssertFalse(converted!.evaluate(with: ObjCObject()))
    }
    
    func testMaxMin() {
        let predicate = Predicate<ObjCObject> {
            PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_max(
                    PredicateExpressions.build_KeyPath(
                        root: $0,
                        keyPath: \.g
                    )
                ),
                rhs: PredicateExpressions.build_min(
                    PredicateExpressions.build_KeyPath(
                        root: $0,
                        keyPath: \.g
                    )
                )
            )
        }
        
        let converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "g.@max.#self == g.@min.#self"))
        XCTAssertFalse(converted!.evaluate(with: ObjCObject()))
    }
    
    func testStringComparison() {
        let equal = ComparisonResult.orderedSame
        var predicate = Predicate<ObjCObject> {
            // $0.b.caseInsensitiveCompare("ABC") == equal
            PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_caseInsensitiveCompare(
                    PredicateExpressions.build_KeyPath(
                        root: PredicateExpressions.build_Arg($0),
                        keyPath: \.b
                    ),
                    PredicateExpressions.build_Arg("ABC")
                ),
                rhs: PredicateExpressions.build_Arg(equal)
            )
        }
        
        var converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "TERNARY(b ==[c] 'ABC', 0, TERNARY(b <[c] 'ABC', -1, 1)) == 0"))
        XCTAssertFalse(converted!.evaluate(with: ObjCObject()))
        
        predicate = Predicate<ObjCObject> {
            // $0.string.localizedStandardCompare("ABC") == equal
            PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_localizedCompare(
                    PredicateExpressions.build_KeyPath(
                        root: PredicateExpressions.build_Arg($0),
                        keyPath: \.b
                    ),
                    PredicateExpressions.build_Arg("ABC")
                ),
                rhs: PredicateExpressions.build_Arg(equal)
            )
        }
        
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "TERNARY(b ==[l] 'ABC', 0, TERNARY(b <[l] 'ABC', -1, 1)) == 0"))
        XCTAssertFalse(converted!.evaluate(with: ObjCObject()))
        
        predicate = Predicate<ObjCObject> {
            // $0.string.localizedStandardContains("ABC")
            PredicateExpressions.build_localizedStandardContains(
                PredicateExpressions.build_KeyPath(
                    root: PredicateExpressions.build_Arg($0),
                    keyPath: \.b
                ),
                PredicateExpressions.build_Arg("ABC")
            )
        }
        
        converted = convert(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "b CONTAINS[cdl] 'ABC'"))
        XCTAssertFalse(converted!.evaluate(with: ObjCObject()))
    }
}

#endif
