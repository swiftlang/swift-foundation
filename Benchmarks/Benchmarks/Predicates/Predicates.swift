import Benchmark
import func Benchmark.blackHole
import FoundationEssentials

enum Weapon: Int {
    case mace
    case sword
    case lightsaber
}

struct Monster {
    let name: String
    var level: Int
    var hp: Int
    var mana: Int
    var weapon: Int?
    var nameComputed: String { name }
    var levelComputer: Int { level }
    var hpComputed: Int { hp }
    var manaComputed: Int { mana }
    var weaponComputed: Int? { weapon }
}

let benchmarks = {
    Benchmark.defaultConfiguration.maxIterations = 1_000_000_000
    Benchmark.defaultConfiguration.maxDuration = .seconds(5)
    Benchmark.defaultConfiguration.scalingFactor = .kilo

    if #available(macOS 14, *) {
        Benchmark("Predicate #1 - simple 'true' condition") { benchmark in
            let monster = Monster(name: "Orc", level: 80, hp: 100, mana: 0, weapon: Weapon.sword.rawValue)
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
            let monster = Monster(name: "Orc", level: 80, hp: 100, mana: 0, weapon: Weapon.sword.rawValue)
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
            let monster = Monster(name: "Orc", level: 80, hp: 100, mana: 0, weapon: Weapon.sword.rawValue)
            let predicate = #Predicate<Monster> { monster in
                (monster.hpComputed == 100)
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
        Benchmark("Predicate #4 - 5 KeyPath variable conditions") { benchmark in
            let weapon = Weapon.sword.rawValue
            let monster = Monster(name: "Orc", level: 80, hp: 100, mana: 0, weapon: weapon)
            let predicate = #Predicate<Monster> { monster in
                ((monster.name == "Orc") &&
                 (monster.level == 80) &&
                 (monster.hp == 100) &&
                 (monster.mana == 0) &&
                 ((monster.weapon != nil) && (monster.weapon! == weapon)))
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
        Benchmark("Predicate #5 - 5 KeyPath computed property conditions") { benchmark in
            let weapon = Weapon.sword.rawValue
            let monster = Monster(name: "Orc", level: 80, hp: 100, mana: 0, weapon: weapon)
            let predicate = #Predicate<Monster> { monster in
                ((monster.nameComputed == "Orc") &&
                 (monster.levelComputer == 80) &&
                 (monster.hpComputed == 100) &&
                 (monster.manaComputed == 0) &&
                 ((monster.weaponComputed != nil) && (monster.weapon! == weapon)))
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
