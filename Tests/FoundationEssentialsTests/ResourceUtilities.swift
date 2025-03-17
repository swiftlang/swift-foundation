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

#if canImport(TestSupport)
import TestSupport
#endif

#if canImport(Glibc)
@preconcurrency import Glibc
#endif

#if FOUNDATION_FRAMEWORK
import Foundation
#else
import FoundationEssentials
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
#if os(macOS)
    let subdir: String
    if let subdirectory {
        subdir = "Resources/" + subdirectory
    } else {
        subdir = "Resources"
    }

    guard let url = Bundle.module.url(forResource: resource, withExtension: ext, subdirectory: subdir) else {
        return nil
    }
    
    let essentialsURL = FoundationEssentials.URL(filePath: url.path)

    return try? Data(contentsOf: essentialsURL)
#else
    // swiftpm drops the resources next to the executable, at:
    // ./swift-foundation_FoundationEssentialsTests.resources/Resources/
    // Hard-coding the path is unfortunate, but a temporary need until we have a better way to handle this

    var toolsResourcesDir = URL(filePath: ProcessInfo.processInfo.arguments[0])
        .deletingLastPathComponent()
        .appending(component: "swift-foundation_FoundationEssentialsTests-tool.resources", directoryHint: .isDirectory)

    // On Linux the tests are built for the "host" because there are macro tests, on Windows
    // the tests are only built for the "target" so we need to figure out whether `-tools`
    // resources exist and if so, use them.
    let resourcesDir = if FileManager.default.fileExists(atPath: toolsResourcesDir.path) {
        toolsResourcesDir
    } else {
        URL(filePath: ProcessInfo.processInfo.arguments[0])
            .deletingLastPathComponent()
            .appending(component: "swift-foundation_FoundationEssentialsTests.resources", directoryHint: .isDirectory)
    }

    var path = resourcesDir.appending(component: "Resources", directoryHint: .isDirectory)
    if let subdirectory {
        path.append(path: subdirectory, directoryHint: .isDirectory)
    }
    path.append(component: resource + "." + ext, directoryHint: .notDirectory)
    return try? Data(contentsOf: path)
#endif
#endif
}
