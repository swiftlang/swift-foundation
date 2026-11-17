//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Benchmark
import func Benchmark.blackHole

#if os(macOS) && USE_PACKAGE
// Only the package, so that `PropertyListSerialization` is the one from FoundationEssentials.
import FoundationEssentials
#else
import Foundation
#endif

private struct Record : Encodable {
    var name: String
    var identifier: Int
    var score: Double
    var enabled: Bool
    var created: Date
    var tags: [String]
    var blob: Data
    var nested: [String : Int]
}

private struct InfoPlist : Encodable {
    var CFBundleIdentifier = "com.example.benchmark"
    var CFBundleName = "Benchmark"
    var CFBundleDisplayName = "Bénchmark"
    var CFBundleShortVersionString = "1.2.3"
    var CFBundleVersion = "456"
    var CFBundleExecutable = "Benchmark"
    var CFBundlePackageType = "APPL"
    var LSMinimumSystemVersion = "14.0"
    var NSHighResolutionCapable = true
    var CFBundleDocumentTypes = (0 ..< 4).map { ["CFBundleTypeName": "Document \($0)", "CFBundleTypeRole": "Editor", "LSHandlerRank": "Owner"] }
    var CFBundleURLTypes = [["CFBundleURLName": "com.example.benchmark", "CFBundleURLSchemes": "benchmark"]]
    var UTExportedTypeDeclarations = (0 ..< 3).map { ["UTTypeIdentifier": "com.example.type\($0)", "UTTypeDescription": "Type \($0)"] }
}

private func records(count: Int) -> [Record] {
    (0 ..< count).map { i in
        Record(
            // Every fourth name is not ASCII, so a binary property list has UTF-16 strings too.
            name: i % 4 == 0 ? "Zoë Record \(i) ✓" : "Record \(i)",
            identifier: i * 7919,
            score: Double(i) / 3,
            enabled: i % 2 == 0,
            created: Date(timeIntervalSinceReferenceDate: Double(i) * 3600),
            tags: ["red", "green", "blue", "tag\(i % 10)"],
            blob: Data((0 ..< 32).map { UInt8(truncatingIfNeeded: i &+ $0) }),
            nested: ["width": i % 100, "height": i % 37, "depth": 3]
        )
    }
}

private func encode<T: Encodable>(_ value: T, format: PropertyListDecoder.PropertyListFormat) -> Data {
    let encoder = PropertyListEncoder()
    encoder.outputFormat = format
    return try! encoder.encode(value)
}

/// An OpenStep property list with the shape of an Xcode `project.pbxproj` file.
private func projectFile(objectCount: Int) -> Data {
    var text = "// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {\n\t};\n\tobjectVersion = 56;\n\tobjects = {\n"
    for i in 0 ..< objectCount {
        let id = String(i, radix: 16, uppercase: true)
        text += "\t\t\(id)0000000000000001 /* File\(i).swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"File \(i).swift\"; sourceTree = \"<group>\"; };\n"
        text += "\t\t\(id)0000000000000002 /* File\(i).swift in Sources */ = {isa = PBXBuildFile; fileRef = \(id)0000000000000001 /* File\(i).swift */; settings = {COMPILER_FLAGS = \"-O\"; ATTRIBUTES = (Public, ); }; };\n"
    }
    text += "\t};\n\trootObject = 0000000000000000000000AA /* Project object */;\n}\n"
    return Data(text.utf8)
}

/// A `.strings` file, which is an OpenStep dictionary without the braces.
private func stringsFile(entryCount: Int, utf16: Bool) -> Data {
    var text = "/* Localizable strings */\n"
    for i in 0 ..< entryCount {
        text += "/* Comment for entry \(i) */\n\"Key number \(i)\" = \"Value number \(i), café \\\"quoted\\\"\";\n\n"
    }
    guard utf16 else {
        return Data(text.utf8)
    }
    var bytes: [UInt8] = [0xFF, 0xFE]
    for unit in text.utf16 {
        bytes.append(UInt8(truncatingIfNeeded: unit))
        bytes.append(UInt8(truncatingIfNeeded: unit >> 8))
    }
    return Data(bytes)
}

let benchmarks: @Sendable () -> Void = {
    let configuration = Benchmark.Configuration(
        metrics: [.cpuTotal, .wallClock, .mallocCountTotal, .throughput],
        scalingFactor: .one,
        maxDuration: .seconds(3),
        maxIterations: 1_000_000_000
    )

    let inputs: [(String, Data)] = [
        ("binary-large", encode(records(count: 2000), format: .binary)),
        ("xml-large", encode(records(count: 2000), format: .xml)),
        ("binary-info", encode(InfoPlist(), format: .binary)),
        ("xml-info", encode(InfoPlist(), format: .xml)),
        ("openStep-project", projectFile(objectCount: 2000)),
        ("openStep-strings-utf8", stringsFile(entryCount: 2000, utf16: false)),
        ("openStep-strings-utf16", stringsFile(entryCount: 2000, utf16: true)),
    ]

    for (name, data) in inputs {
        Benchmark("PropertyListSerialization-read-\(name)", configuration: configuration) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(try PropertyListSerialization.propertyList(from: data, options: [], format: nil))
            }
        }
    }
}
