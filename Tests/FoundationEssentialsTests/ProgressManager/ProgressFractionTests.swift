//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
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
#endif // FOUNDATION_FRAMEWORK

@Suite("Progress Fraction", .tags(.progressManager)) struct ProgressFractionTests {
    @Test func equal() {
        let f1 = ProgressFraction(completed: 5, total: 10)
        let f2 = ProgressFraction(completed: 100, total: 200)
        
        #expect(f1 == f2)
        
        let f3 = ProgressFraction(completed: 3, total: 10)
        #expect(f1 != f3)
        
        let f4 = ProgressFraction(completed: 5, total: 10)
        #expect(f1 == f4)
    }
    
    @Test func addSame() {
        let f1 = ProgressFraction(completed: 5, total: 10)
        let f2 = ProgressFraction(completed: 3, total: 10)

        let r = f1 + f2
        #expect(r.completed == 8)
        #expect(r.total == 10)
    }
    
    @Test func addDifferent() {
        let f1 = ProgressFraction(completed: 5, total: 10)
        let f2 = ProgressFraction(completed : 300, total: 1000)

        let r = f1 + f2
        #expect(r.completed == 800)
        #expect(r.total == 1000)
    }
    
    @Test func subtract() {
        let f1 = ProgressFraction(completed: 5, total: 10)
        let f2 = ProgressFraction(completed: 3, total: 10)

        let r = f1 - f2
        #expect(r.completed == 2)
        #expect(r.total == 10)
    }
    
    @Test func multiply() {
        let f1 = ProgressFraction(completed: 5, total: 10)
        let f2 = ProgressFraction(completed: 1, total: 2)

        let r = f1 * f2
        #expect(r?.completed == 5)
        #expect(r?.total == 20)
    }
    
    @Test func simplify() {
        let f1 = ProgressFraction(completed: 5, total: 10)
        let f2 = ProgressFraction(completed: 3, total: 10)

        let r = (f1 + f2).simplified()
        
        #expect(r?.completed == 4)
        #expect(r?.total == 5)
    }
    
    @Test func overflow() {
        // These prime numbers are problematic for overflowing
        let denominators : [Int] = [5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 69]
        
        var f1 = ProgressFraction(completed: 1, total: 3)
        for d in denominators {
            f1 = f1 + ProgressFraction(completed: 1, total: d)
        }
        
        let fractionResult = f1.fractionCompleted
        var expectedResult = 1.0 / 3.0
        for d in denominators {
            expectedResult = expectedResult + 1.0 / Double(d)
        }
        #expect(abs(fractionResult - expectedResult) < 0.00001)
    }
    
    @Test func addOverflow() {
        // These prime numbers are problematic for overflowing
        let denominators : [Int] = [5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 69]
        var f1 = ProgressFraction(completed: 1, total: 3)
        for d in denominators {
            f1 = f1 + ProgressFraction(completed: 1, total: d)
        }

        // f1 should be in overflow
        #expect(f1.overflowed)
        
        let f2 = ProgressFraction(completed: 1, total: 4) + f1
        
        // f2 should also be in overflow
        #expect(f2.overflowed)
        
        // And it should have completed value of about 1.0/4.0 + f1.fractionCompleted
        let expected = (1.0 / 4.0) + f1.fractionCompleted
        
        #expect(abs(expected - f2.fractionCompleted) < 0.00001)
    }
    
#if _pointerBitWidth(_64) // These tests assumes Int is Int64
    @Test func addAndSubtractOverflow() {
        let f1 = ProgressFraction(completed: 48, total: 60)
        let f2 = ProgressFraction(completed: 5880, total: 7200)
        let f3 = ProgressFraction(completed: 7048893638467736640, total: 8811117048084670800)
        
        let result1 = (f3 - f1) + f2
        #expect(result1.completed > 0)
        
        let result2 = (f3 - f2) + f1
        #expect(result2.completed < 60)
    }
    
    @Test func subtractOverflow() {
        let f1 = ProgressFraction(completed: 9855, total: 225066)
        let f2 = ProgressFraction(completed: 14985363210613129, total: 56427817205760000)
        
        let result = f2 - f1
        #expect(abs(Double(result.completed) / Double(result.total!) - 0.2217) < 0.01)
    }
    
    @Test func multiplyOverflow() {
        let f1 = ProgressFraction(completed: 4294967279, total: 4294967291)
        let f2 = ProgressFraction(completed: 4294967279, total: 4294967291)
        
        let result = f1 * f2
        #expect(abs(Double(result!.completed) / Double(result!.total!) - 1.0) < 0.01)
    }
#endif
    
    @Test func fractionFromDouble() {
        let d = 4.25 // exactly representable in binary
        let f1 = ProgressFraction(double: d)
        
        let simplified = f1.simplified()
        #expect(simplified?.completed == 17)
        #expect(simplified?.total == 4)
    }
    
    @Test func unnecessaryOverflow() {
        // just because a fraction has a large denominator doesn't mean it needs to overflow
        let f1 = ProgressFraction(completed: (Int.max - 1) / 2, total: Int.max - 1)
        let f2 = ProgressFraction(completed: 1, total: 16)
        
        let r = f1 + f2
        #expect(!r.overflowed)
    }
}
