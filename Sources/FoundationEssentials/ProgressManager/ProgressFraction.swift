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

#if FOUNDATION_FRAMEWORK
internal import _ForSwiftFoundation
#endif

internal struct ProgressFraction : Sendable, Equatable, CustomDebugStringConvertible {
    var completed : Int
    var total : Int?
    /// Indicates whether mathematical operations on this fraction have exceeded integer limits,
    /// causing the fraction to fall back to floating-point representation for accuracy.
    private(set) var overflowed : Bool
    
    init() {
        completed = 0
        total = nil
        overflowed = false
    }
    
    init(double: Double, overflow: Bool = false) {
        if double == 0 {
            self.completed = 0
            self.total = 1
        } else if double == 1 {
            self.completed = 1
            self.total = 1
        } else {
            (self.completed, self.total) = ProgressFraction._fromDouble(double)
        }
        self.overflowed = overflow
    }
    
    init(completed: Int, total: Int?) {
        self.total = total
        self.completed = completed
        self.overflowed = false
    }
    
    // ----
    
#if FOUNDATION_FRAMEWORK
    // Glue code for _NSProgressFraction and ProgressFraction
    init(nsProgressFraction: _NSProgressFraction) {
        self.init(completed: Int(nsProgressFraction.completed), total: Int(nsProgressFraction.total))
    }
#endif

    internal mutating func simplify() {
        guard let total = self.total, total != 0 else {
            return
        }
        
        (self.completed, self.total) = ProgressFraction._simplify(completed, total)
    }
    
    internal func simplified() -> ProgressFraction? {
        if let total = self.total {
            let simplified = ProgressFraction._simplify(completed, total)
            return ProgressFraction(completed: simplified.0, total: simplified.1)
        } else {
            return nil
        }
    }
    
    /// A closure that performs floating-point arithmetic operations
    private typealias FloatingPointOperation = (_ lhs: Double, _ rhs: Double) -> Double
    
    /// A closure that performs integer arithmetic operations with overflow detection
    private typealias OverflowReportingOperation = (_ lhs: Int, _ rhs: Int) -> (Int, overflow: Bool)
    
    static private func _math(lhs: ProgressFraction, rhs: ProgressFraction, operation: FloatingPointOperation, overflowOperation: OverflowReportingOperation) -> ProgressFraction {
        // Mathematically, it is nonsense to add or subtract something with a denominator of 0. However, for the purposes of implementing Progress' fractions, we just assume that a zero-denominator fraction is "weightless" and return the other value. We still need to check for the case where they are both nonsense though.
        precondition(!(lhs.total == 0 && rhs.total == 0), "Attempt to add or subtract invalid fraction")
        guard let lhsTotal = lhs.total, lhsTotal != 0 else {
            return rhs
        }
        guard let rhsTotal = rhs.total, rhsTotal != 0 else {
            return lhs
        }
        
        guard !lhs.overflowed && !rhs.overflowed else {
            // If either has overflowed already, we preserve that
            return ProgressFraction(double: operation(lhs.fractionCompleted, rhs.fractionCompleted), overflow: true)
        }

        if let lcm = _leastCommonMultiple(lhsTotal, rhsTotal) {
            let result = overflowOperation(lhs.completed * (lcm / lhsTotal), rhs.completed * (lcm / rhsTotal))
            if result.overflow {
                return ProgressFraction(double: operation(lhs.fractionCompleted, rhs.fractionCompleted), overflow: true)
            } else {
                return ProgressFraction(completed: result.0, total: lcm)
            }
        } else {
            // Overflow - simplify and then try again
            let lhsSimplified = lhs.simplified()
            let rhsSimplified = rhs.simplified()
            
            guard let lhsSimplified = lhsSimplified,
                  let rhsSimplified = rhsSimplified,
                  let lhsSimplifiedTotal = lhsSimplified.total,
                  let rhsSimplifiedTotal = rhsSimplified.total else {
                // Simplification failed, fall back to double math
                return ProgressFraction(double: operation(lhs.fractionCompleted, rhs.fractionCompleted), overflow: true)
            }
            
            if let lcm = _leastCommonMultiple(lhsSimplifiedTotal, rhsSimplifiedTotal) {
                let result = overflowOperation(lhsSimplified.completed * (lcm / lhsSimplifiedTotal), rhsSimplified.completed * (lcm / rhsSimplifiedTotal))
                if result.overflow {
                    // Use original lhs/rhs here
                    return ProgressFraction(double: operation(lhs.fractionCompleted, rhs.fractionCompleted), overflow: true)
                } else {
                    return ProgressFraction(completed: result.0, total: lcm)
                }
            } else {
                // Still overflow
                return ProgressFraction(double: operation(lhs.fractionCompleted, rhs.fractionCompleted), overflow: true)
            }
        }
    }
    
    static internal func +(lhs: ProgressFraction, rhs: ProgressFraction) -> ProgressFraction {
        return _math(lhs: lhs, rhs: rhs, operation: +, overflowOperation: { $0.addingReportingOverflow($1) })
    }
    
    static internal func -(lhs: ProgressFraction, rhs: ProgressFraction) -> ProgressFraction {
        return _math(lhs: lhs, rhs: rhs, operation: -, overflowOperation: { $0.subtractingReportingOverflow($1) })
    }
    
    static internal func *(lhs: ProgressFraction, rhs: ProgressFraction) -> ProgressFraction? {
        guard !lhs.overflowed && !rhs.overflowed else {
            // If either has overflowed already, we preserve that
            return ProgressFraction(double: lhs.fractionCompleted * rhs.fractionCompleted, overflow: true)
        }

        guard let lhsTotal = lhs.total, let rhsTotal = rhs.total else {
            return nil
        }
        
        let newCompleted = lhs.completed.multipliedReportingOverflow(by: rhs.completed)
        let newTotal = lhsTotal.multipliedReportingOverflow(by: rhsTotal)
        
        if newCompleted.overflow || newTotal.overflow {
            // Try simplifying, then do it again
            let lhsSimplified = lhs.simplified()
            let rhsSimplified = rhs.simplified()
            
            guard let lhsSimplified = lhsSimplified,
                  let rhsSimplified = rhsSimplified,
                  let lhsSimplifiedTotal = lhsSimplified.total,
                  let rhsSimplifiedTotal = rhsSimplified.total else {
                return nil
            }
            
            let newCompletedSimplified = lhsSimplified.completed.multipliedReportingOverflow(by: rhsSimplified.completed)
            let newTotalSimplified = lhsSimplifiedTotal.multipliedReportingOverflow(by: rhsSimplifiedTotal)
            
            if newCompletedSimplified.overflow || newTotalSimplified.overflow {
                // Still overflow
                return ProgressFraction(double: lhs.fractionCompleted * rhs.fractionCompleted, overflow: true)
            } else {
                return ProgressFraction(completed: newCompletedSimplified.0, total: newTotalSimplified.0)
            }
        } else {
            return ProgressFraction(completed: newCompleted.0, total: newTotal.0)
        }
    }
    
    static internal func /(lhs: ProgressFraction, rhs: Int) -> ProgressFraction? {
        guard !lhs.overflowed else {
            // If lhs has overflowed, we preserve that
            return ProgressFraction(double: lhs.fractionCompleted / Double(rhs), overflow: true)
        }
        
        guard let lhsTotal = lhs.total else {
            return nil
        }
        
        let newTotal = lhsTotal.multipliedReportingOverflow(by: rhs)
        
        if newTotal.overflow {
            let simplified = lhs.simplified()
            
            guard let simplified = simplified,
                  let simplifiedTotal = simplified.total else {
                return nil
            }
            
            let newTotalSimplified = simplifiedTotal.multipliedReportingOverflow(by: rhs)
            
            if newTotalSimplified.overflow {
                // Still overflow
                return ProgressFraction(double: lhs.fractionCompleted / Double(rhs), overflow: true)
            } else {
                return ProgressFraction(completed: lhs.completed, total: newTotalSimplified.0)
            }
        } else {
            return ProgressFraction(completed: lhs.completed, total: newTotal.0)
        }
    }
    
    static internal func ==(lhs: ProgressFraction, rhs: ProgressFraction) -> Bool {
        if lhs.isNaN || rhs.isNaN {
            // NaN fractions are never equal
            return false
        } else if lhs.total == rhs.total {
            // Direct comparison of numerator
            return lhs.completed == rhs.completed
        } else if lhs.total == nil && rhs.total != nil {
            return false
        } else if lhs.total != nil && rhs.total == nil {
            return false
        } else if lhs.completed == 0 && rhs.completed == 0 {
            return true
        } else if lhs.completed == lhs.total && rhs.completed == rhs.total {
            // Both finished (1)
            return true
        } else if (lhs.completed == 0 && rhs.completed != 0) || (lhs.completed != 0 && rhs.completed == 0) {
            // One 0, one not 0
            return false
        } else {
            // Cross-multiply
            guard let lhsTotal = lhs.total, let rhsTotal = rhs.total else {
                return false
            }
            
            let left = lhs.completed.multipliedReportingOverflow(by: rhsTotal)
            let right = lhsTotal.multipliedReportingOverflow(by: rhs.completed)
            
            if !left.overflow && !right.overflow {
                if left.0 == right.0 {
                    return true
                }
            } else {
                // Try simplifying then cross multiply again
                let lhsSimplified = lhs.simplified()
                let rhsSimplified = rhs.simplified()
                
                guard let lhsSimplified = lhsSimplified,
                      let rhsSimplified = rhsSimplified,
                      let lhsSimplifiedTotal = lhsSimplified.total,
                      let rhsSimplifiedTotal = rhsSimplified.total else {
                    // Simplification failed, fall back to doubles
                    return lhs.fractionCompleted == rhs.fractionCompleted
                }
                
                let leftSimplified = lhsSimplified.completed.multipliedReportingOverflow(by: rhsSimplifiedTotal)
                let rightSimplified = lhsSimplifiedTotal.multipliedReportingOverflow(by: rhsSimplified.completed)

                if !leftSimplified.overflow && !rightSimplified.overflow {
                    if leftSimplified.0 == rightSimplified.0 {
                        return true
                    }
                } else {
                    // Ok... fallback to doubles. This doesn't use an epsilon
                    return lhs.fractionCompleted == rhs.fractionCompleted
                }
            }
        }
        
        return false
    }
    
    // ----
    
    internal var isFinished: Bool {
        guard let total else {
            return false
        }
        return completed >= total && completed > 0 && total > 0
    }
    
    internal var isIndeterminate: Bool {
        return total == nil
    }
    
    
    internal var fractionCompleted : Double {
        guard let total else {
            return 0.0
        }
        return Double(completed) / Double(total)
    }

    
    internal var isNaN : Bool {
        return total == 0
    }
    
    internal var debugDescription : String {
        return "\(completed) / \(total, default: "unknown") (\(fractionCompleted)), overflowed: \(overflowed)"
    }
    
    // ----
    
    private static func _fromDouble(_ d : Double) -> (Int, Int) {
        // This simplistic algorithm could someday be replaced with something better.
        // Basically - how many 1/Nths is this double?
        #if _pointerBitWidth(_32)
        let denominator = 1048576    // 2^20 - safe for 32-bit
        #elseif _pointerBitWidth(_64)
        let denominator = 1073741824 // 2^30 - high precision for 64-bit
        #else
        let denominator = 131072       // 2^17 - ultra-safe fallback
        #endif
        let numerator = Int(d / (1.0 / Double(denominator)))
        return (numerator, denominator)
    }
    
    private static func _greatestCommonDivisor(_ inA : Int, _ inB : Int) -> Int {
        // This is Euclid's algorithm. There are faster ones, like Knuth, but this is the simplest one for now.
        var a = inA
        var b = inB
        repeat {
            let tmp = b
            b = a % b
            a = tmp
        } while (b != 0)
        return a
    }
    
    private static func _leastCommonMultiple(_ a : Int, _ b : Int) -> Int? {
        // This division always results in an integer value because gcd(a,b) is a divisor of a.
        // lcm(a,b) == (|a|/gcd(a,b))*b == (|b|/gcd(a,b))*a
        let result = (a / _greatestCommonDivisor(a, b)).multipliedReportingOverflow(by: b)
        if result.overflow {
            return nil
        } else {
            return result.0
        }
    }
    
    private static func _simplify(_ n : Int, _ d : Int) -> (Int, Int) {
        let gcd = _greatestCommonDivisor(n, d)
        return (n / gcd, d / gcd)
    }
}
