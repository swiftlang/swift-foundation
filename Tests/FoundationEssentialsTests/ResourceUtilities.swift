//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//

#if canImport(Glibc)
import Glibc
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable import FoundationEssentials
#endif // FOUNDATION_FRAMEWORK

#if FOUNDATION_FRAMEWORK
// Always compiled into the Tests project
final internal class Canary { }
#endif

func testData(forResource resource: String, withExtension ext: String, subdirectory: String? = nil) -> Data? {
#if FOUNDATION_FRAMEWORK
    guard let url = Bundle(for: Canary.self).url(forResource: resource, withExtension: ext, subdirectory: subdirectory) else {
        return nil
    }
    return try? Data(contentsOf: url)
#else
    // SwiftPM generates a `resource_bundle_accessor.swift` file which defines `Bundle.module`
    // specifically from `Foundation.Bundle`. This means we can't use `Bundle.module` in
    // SwiftFoundation because `Bundle` is(will be) defined under `FoundationEssentials`.
    // rdar://125972133 (SwiftPM should support a Bundle independent mode when generating resource_bundle_accessor.swift)

    // swiftpm drops the resources next to the executable, at:
    // - macOS: ./FoundationPreview_FoundationEssentialsTests.bundle/Resources/
    // - Linux: ./FoundationPreview_FoundationEssentialsTests.resources/Resources/
    // (these hardcoded path will be generated after rdar://125972133)
#if os(Linux)
    let bundleSuffix = "resources"
#else
    let bundleSuffix = "bundle"
#endif

    var path = Platform.getFullExecutablePath()!
        .deletingLastPathComponent() +
        "/FoundationPreview_FoundationEssentialsTests.\(bundleSuffix)/Resources/"
    if let subdirectory {
        path += subdirectory + "/"
    }
    path += resource + "." + ext
    return try? Data(contentsOf: path)
#endif
}
