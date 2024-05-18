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

import Benchmark
import func Benchmark.blackHole

#if FOUNDATION_FRAMEWORK
import Foundation
#else
import FoundationEssentials
#endif

let monster = Monster(name: "Orc", level: 80, hp: 100, mana: 0, weapon: .sword(Sword(p1: 1, p2: 2, p3: 3, p4: 4, p5: 5)))
let monster2 = Monster(name: "Orc", level: 80, hp: 100, mana: 0, weapon: .sword(Sword(p1: 1, p2: 2, p3: 3, p4: 4, p5: 5)))

// These tests are disabled, as enabling them will make compilation fail due to https://github.com/apple/swift/issues/69277
#if false
func registerPredicateTests_disabled() {
    predicateTests.append(("predicateThreeKeypathNestedComputedPropertyCondition", #Predicate<Monster> { monster in
        ((monster.weaponP1 == 1) &&
         (monster.weaponP2 == 2) &&
         (monster.weaponP3 == 3))
    }))
    
    predicateTests.append(("predicateFiveKeypathNestedComputedPropertyCondition", #Predicate<Monster> { monster in
        ((monster.weaponP1 == 1) &&
         (monster.weaponP2 == 2) &&
         (monster.weaponP3 == 3) &&
         (monster.weaponP4 == 4) &&
         (monster.weaponP5 == 5))
    }))
    
    var variadicPredicateTests : [(String, Predicate<Monster, Monster>)] = []

    variadicPredicateTests.append(("predicateVariadicThreeKeypathNestedComputedPropertyCondition",
                                   #Predicate<Monster, Monster> { monster, monster2 in
        ((monster.weaponP1 == 1) &&
         (monster.weaponP2 == 2) &&
         (monster2.weaponP2 == 2))
    }))

    variadicPredicateTests.forEach { (testDescription, predicate) in
        Benchmark(testDescription) { benchmark in
            var matched = 0

            for _ in benchmark.scaledIterations {
                if try predicate.evaluate(monster, monster2) {
                    matched += 1
                }
            }

            guard matched == benchmark.scaledIterations.count else {
                fatalError("Internal error: wrong number of matched monsters")
            }
        }
    }
}
#endif

func registerPredicateTests() {
    if #available(macOS 14, *) {

        var predicateTests : [(String, Predicate<Monster>)] = []

        predicateTests.append(("predicateTrivialCondition", #Predicate<Monster> { monster in
            true
        }))

        predicateTests.append(("predicateKeypathPropertyCondition", #Predicate<Monster> { monster in
            (monster.level == 80)
        }))

        predicateTests.append(("predicateKeypathComputedPropertyCondition", #Predicate<Monster> { monster in
            (monster.levelComputed == 80)
        }))

        predicateTests.append(("predicateKeypathNestedComputedPropertyCondition", #Predicate<Monster> { monster in
            (monster.weaponP1 == 1)
        }))

        predicateTests.forEach { (testDescription, predicate) in
            Benchmark(testDescription) { benchmark in
                var matched = 0

                for _ in benchmark.scaledIterations {
                    if try predicate.evaluate(monster) {
                        matched += 1
                    }
                }

                guard matched == benchmark.scaledIterations.count else {
                    fatalError("Internal error: wrong number of matched monsters")
                }
            }
        }
    }
}

let benchmarks : () -> Void = {
    Benchmark.defaultConfiguration.maxIterations = 1_000_000_000
    Benchmark.defaultConfiguration.maxDuration = .seconds(3)
    Benchmark.defaultConfiguration.scalingFactor = .kilo
    Benchmark.defaultConfiguration.metrics = [.cpuTotal, .wallClock, .mallocCountTotal, .throughput]

    registerPredicateTests()
}
