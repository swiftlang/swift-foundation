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
        var converted = NSPredicate(predicate)
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
        converted = NSPredicate(predicate)
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
        converted = NSPredicate(predicate)
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
        converted = NSPredicate(predicate)
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
        converted = NSPredicate(predicate)
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
        var converted = NSPredicate(predicate)
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
        converted = NSPredicate(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "a != 0"))
        XCTAssertTrue(converted!.evaluate(with: ObjCObject()))
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
        XCTAssertNil(NSPredicate(predicate))
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
        var converted = NSPredicate(predicate)
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
        converted = NSPredicate(predicate)
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
        var converted = NSPredicate(predicate)
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
        converted = NSPredicate(predicate)
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
        var converted = NSPredicate(predicate)
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
        converted = NSPredicate(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "b BEGINSWITH 'foo'"))
        XCTAssertFalse(converted!.evaluate(with: obj))
    }
    
    func testExpressionEnforcement() {
        var predicate = Predicate<ObjCObject> { _ in
            PredicateExpressions.build_Arg(true)
        }
        var converted = NSPredicate(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "YES == YES"))
        XCTAssertTrue(converted!.evaluate(with: "Hello"))
        
        predicate = Predicate<ObjCObject> { _ in
            PredicateExpressions.build_Arg(false)
        }
        converted = NSPredicate(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "NO == YES"))
        XCTAssertFalse(converted!.evaluate(with: "Hello"))
        
        predicate = Predicate<ObjCObject> { _ in
            PredicateExpressions.build_Conjunction(
                lhs: PredicateExpressions.build_Arg(true),
                rhs: PredicateExpressions.build_Arg(false)
            )
        }
        converted = NSPredicate(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "(YES == YES) && (NO == YES)"))
        XCTAssertFalse(converted!.evaluate(with: "Hello"))
        
        predicate = Predicate<ObjCObject> {
            PredicateExpressions.build_KeyPath(
                root: PredicateExpressions.build_Arg($0),
                keyPath: \.f
            )
        }
        converted = NSPredicate(predicate)
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
        converted = NSPredicate(predicate)
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
        let converted = NSPredicate(predicate)
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
        var converted = NSPredicate(predicate)
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
        converted = NSPredicate(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "TERNARY(TERNARY(j != nil, j.length, nil) != nil, TERNARY(j != nil, j.length, nil), -1) > 1"))
        XCTAssertFalse(converted!.evaluate(with: ObjCObject()))
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
        
        let converted = NSPredicate(predicate)
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
        
        let converted = NSPredicate(predicate)
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
        let converted = NSPredicate(predicate)
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
        let converted = NSPredicate(predicate)
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
        let converted = NSPredicate(predicate)
        XCTAssertEqual(converted, NSPredicate(format: "SUBQUERY(g, $_local_1, NOT ($_local_1 == 2)).@count == 0"))
        XCTAssertFalse(converted!.evaluate(with: ObjCObject()))
    }
}

#endif
