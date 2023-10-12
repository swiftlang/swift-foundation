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

struct Mace {
    let p1: Int
    let p2: Int
    let p3: Int
    let p4: Int
    let p5: Int
}

struct Sword {
    let p1: Int
    let p2: Int
    let p3: Int
    let p4: Int
    let p5: Int
}

struct Lightsaber {
    let p1: Int
    let p2: Int
    let p3: Int
    let p4: Int
    let p5: Int
}

enum Weapon {
    case mace(Mace)
    case sword(Sword)
    case lightsaber(Lightsaber)

    var p1: Int {
        switch self {
        case let .mace(mace):
            mace.p1
        case let .sword(sword):
            sword.p1
        case let .lightsaber(lighsaber):
            lighsaber.p1
        }
    }

    var p2: Int {
        switch self {
        case let .mace(mace):
            mace.p2
        case let .sword(sword):
            sword.p2
        case let .lightsaber(lighsaber):
            lighsaber.p2
        }
    }

    var p3: Int {
        switch self {
        case let .mace(mace):
            mace.p3
        case let .sword(sword):
            sword.p3
        case let .lightsaber(lighsaber):
            lighsaber.p3
        }
    }

    var p4: Int {
        switch self {
        case let .mace(mace):
            mace.p4
        case let .sword(sword):
            sword.p4
        case let .lightsaber(lighsaber):
            lighsaber.p4
        }
    }

    var p5: Int {
        switch self {
        case let .mace(mace):
            mace.p5
        case let .sword(sword):
            sword.p5
        case let .lightsaber(lighsaber):
            lighsaber.p5
        }
    }
}

struct Monster {
    let name: String
    var level: Int
    var hp: Int
    var mana: Int
    var weapon: Weapon?
    var levelComputed: Int { level }
    var weaponP1: Int? { weapon?.p1 }
    var weaponP2: Int? { weapon?.p2 }
    var weaponP3: Int? { weapon?.p3 }
    var weaponP4: Int? { weapon?.p4 }
    var weaponP5: Int? { weapon?.p5 }
}

let benchmarks = {
    Benchmark.defaultConfiguration.maxIterations = 1_000_000_000
    Benchmark.defaultConfiguration.maxDuration = .seconds(5)
    Benchmark.defaultConfiguration.scalingFactor = .kilo

    if #available(macOS 14, *) {
        Benchmark("Predicate #1 - simple 'true' condition") { benchmark in
            let monster = Monster(name: "Orc", level: 80, hp: 100, mana: 0, weapon: .sword(Sword(p1: 1, p2: 2, p3: 3, p4: 4, p5: 5)))
            let predicate = #Predicate<Monster> { monster in
                true
            }

            benchmark.startMeasurement()
            var matched = 0
            for _ in benchmark.scaledIterations {
                if try predicate.evaluate(monster) {
                    matched += 1
                }
            }
            benchmark.stopMeasurement()

            guard matched == benchmark.scaledIterations.count else {
                fatalError("Internal error: wrong number of matched monsters")
            }
        }
    }

    if #available(macOS 14, *) {
        Benchmark("Predicate #2 - 1 KeyPath variable condition") { benchmark in
            let monster = Monster(name: "Orc", level: 80, hp: 100, mana: 0, weapon: .sword(Sword(p1: 1, p2: 2, p3: 3, p4: 4, p5: 5)))
            let predicate = #Predicate<Monster> { monster in
                (monster.level == 80)
            }

            benchmark.startMeasurement()
            var matched = 0
            for _ in benchmark.scaledIterations {
                if try predicate.evaluate(monster) {
                    matched += 1
                }
            }
            benchmark.stopMeasurement()

            guard matched == benchmark.scaledIterations.count else {
                fatalError("Internal error: wrong number of matched monsters")
            }
        }
    }

    if #available(macOS 14, *) {
        Benchmark("Predicate #3 - 1 KeyPath computed property condition") { benchmark in
            let monster = Monster(name: "Orc", level: 80, hp: 100, mana: 0, weapon: .sword(Sword(p1: 1, p2: 2, p3: 3, p4: 4, p5: 5)))
            let predicate = #Predicate<Monster> { monster in
                (monster.levelComputed == 80)
            }

            benchmark.startMeasurement()
            var matched = 0
            for _ in benchmark.scaledIterations {
                if try predicate.evaluate(monster) {
                    matched += 1
                }
            }
            benchmark.stopMeasurement()

            guard matched == benchmark.scaledIterations.count else {
                fatalError("Internal error: wrong number of matched monsters")
            }
        }
    }

    if #available(macOS 14, *) {
        Benchmark("Predicate #4 - 1 KeyPath nested computed property condition") { benchmark in
            let monster = Monster(name: "Orc", level: 80, hp: 100, mana: 0, weapon: .sword(Sword(p1: 1, p2: 2, p3: 3, p4: 4, p5: 5)))
            let predicate = #Predicate<Monster> { monster in
                (monster.weaponP1 == 1)
            }

            benchmark.startMeasurement()
            var matched = 0
            for _ in benchmark.scaledIterations {
                if try predicate.evaluate(monster) {
                    matched += 1
                }
            }
            benchmark.stopMeasurement()

            guard matched == benchmark.scaledIterations.count else {
                fatalError("Internal error: wrong number of matched monsters")
            }
        }
    }

    if #available(macOS 14, *) {
        Benchmark("Predicate #5 - 3 KeyPath nested computed property conditions") { benchmark in
            let monster = Monster(name: "Orc", level: 80, hp: 100, mana: 0, weapon: .sword(Sword(p1: 1, p2: 2, p3: 3, p4: 4, p5: 5)))
            let predicate = #Predicate<Monster> { monster in
                ((monster.weaponP1 == 1) &&
                 //(monster.weaponP2 == 2) &&
                 //(monster.weaponP3 == 3) &&
                 (monster.weaponP4 == 4) &&
                 (monster.weaponP5 == 5))
            }

            benchmark.startMeasurement()
            var matched = 0
            for _ in benchmark.scaledIterations {
                if try predicate.evaluate(monster) {
                    matched += 1
                }
            }
            benchmark.stopMeasurement()

            guard matched == benchmark.scaledIterations.count else {
                fatalError("Internal error: wrong number of matched monsters")
            }
        }
    }
}
