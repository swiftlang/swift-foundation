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
