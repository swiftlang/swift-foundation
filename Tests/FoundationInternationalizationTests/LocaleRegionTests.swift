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
import Foundation
#else
import FoundationEssentials
import FoundationInternationalization
#endif

@Suite("Locale.Region Tests")
struct LocaleRegionTests {
    @Test func regionCategory() async throws {
        #expect(Locale.Region.unknown.category == nil)
        #expect(Locale.Region.world.category == .world)
        #expect(Locale.Region.unitedStates.category == .territory)
        #expect(Locale.Region("EU").category == .grouping)
        #expect(Locale.Region("not a region").category == nil)

        let africa = Locale.Region("002")
        #expect(africa.category == .continent)

        let continentOfSpain = try #require(Locale.Region.spain.continent)
        #expect(continentOfSpain.category == .continent)
    }

    @Test func subcontinent() async throws {
        #expect(Locale.Region.unknown.subcontinent == nil)
        #expect(Locale.Region.world.subcontinent == nil)
        #expect(Locale.Region("not a region").subcontinent == nil)
        #expect(Locale.Region.argentina.subcontinent == Locale.Region("005"))
    }

    @Test func subRegionOfCategory() async throws {
        #expect(Locale.Region.unknown.subRegions(ofCategoy: .world) == [])
        #expect(Locale.Region.unknown.subRegions(ofCategoy: .territory) == [])

        #expect(Set(Locale.Region.world.subRegions(ofCategoy: .continent)) == Set(Locale.Region.isoRegions(ofCategory: .continent)))

        #expect(Locale.Region.argentina.subRegions(ofCategoy: .continent) == [])
        #expect(Locale.Region.argentina.subRegions(ofCategoy: .territory) == Locale.Region.argentina.subRegions)

        #expect(Locale.Region("not a region").subRegions(ofCategoy: .territory) == [])
    }
}
