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

#if canImport(FoundationInternationalization)
@testable import FoundationEssentials
@testable import FoundationInternationalization
#else
@testable import Foundation
#endif

// This actor is private and not exposed to tests to prevent accidentally writing tests annotated with @CurrentInternationalizationPreferencesActor which may have suspension points
// Using the global helper function below ensures that only synchronous work with no suspension points is queued
@globalActor
private actor CurrentInternationalizationPreferencesActor: GlobalActor {
    static let shared = CurrentInternationalizationPreferencesActor()
    
    private init() {}
    
    @CurrentInternationalizationPreferencesActor
    static func usingCurrentInternationalizationPreferences(
        body: () throws -> Void // Must be synchronous to prevent suspension points within body which could introduce a change in the preferences
    ) rethrows {
        try body()
        
        // Reset everything after the test runs to ensure custom values don't persist
        LocaleCache.cache.reset()
        CalendarCache.cache.reset()
        _ = TimeZoneCache.cache.reset()
        _ = TimeZone.resetSystemTimeZone()
    }
}

internal func usingCurrentInternationalizationPreferences(_ body: sending () throws -> Void) async rethrows {
    try await CurrentInternationalizationPreferencesActor.usingCurrentInternationalizationPreferences(body: body)
}
