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
import FoundationEssentials

let benchmarks = {
    Benchmark.defaultConfiguration.maxIterations = 1_000_000_000
    Benchmark.defaultConfiguration.maxDuration = .seconds(5)
    Benchmark.defaultConfiguration.scalingFactor = .kilo
    Benchmark.defaultConfiguration.metrics = .arc + [.cpuTotal, .wallClock, .mallocCountTotal, .throughput] // use ARC to see traffic
//  Benchmark.defaultConfiguration.metrics = [.cpuTotal, .wallClock, .mallocCountTotal, .throughput] // skip ARC as it has some overhead
//  Benchmark.defaultConfiguration.metrics = .all // Use all metrics to easily see which ones are of interest for this benchmark suite
    if #available(macOS 14, *) {

        let monster = Monster(name: "Orc", level: 80, hp: 100, mana: 0, weapon: .sword(Sword(p1: 1, p2: 2, p3: 3, p4: 4, p5: 5)))

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

        predicateTests.append(("predicateThreeKeypathNestedComputedPropertyCondition", #Predicate<Monster> { monster in
            ((monster.weaponP1 == 1) &&
             (monster.weaponP2 == 2) &&
             (monster.weaponP3 == 3))
        }))

    // This test disabled, as enabling it will make compilation fail due to https://github.com/apple/swift/issues/69277
    //      predicateTests.append(("predicateFiveKeypathNestedComputedPropertyCondition", #Predicate<Monster> { monster in
    //          ((monster.weaponP1 == 1) &&
    //           (monster.weaponP2 == 2) &&
    //           (monster.weaponP3 == 3) &&
    //           (monster.weaponP4 == 4) &&
    //           (monster.weaponP5 == 5))
    //      }))

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

        var multivariatePredicateTests : [(String, Predicate<Monster, Weapon>)] = []

        let weapon = Weapon.sword(.init(p1: 1, p2: 2, p3: 3, p4: 4, p5: 5))

        multivariatePredicateTests.append(("predicateMultivariateCondition",
                                           #Predicate<Monster, Weapon> { monster, weapon in
            ((monster.weaponP1 == 1) &&
             (weapon.p3 == 3))
        }))

        multivariatePredicateTests.forEach { (testDescription, predicate) in
            Benchmark(testDescription) { benchmark in
                var matched = 0

                for _ in benchmark.scaledIterations {
                    if try predicate.evaluate(monster, weapon) {
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
