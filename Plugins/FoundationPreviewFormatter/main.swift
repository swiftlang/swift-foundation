//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

import PackagePlugin
import Foundation

@main
struct FoundationPreviewFormatter : CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        let swiftFormatTool = try context.tool(named: "swift-format")
        let toolExecURL = URL(fileURLWithPath: swiftFormatTool.path.string)
        let configFile = context.package.directory.appending(["linter-rules.json"])

        for target in context.package.targets {
            guard let sourceTarget = target as? SourceModuleTarget else {
                continue
            }

            let arguments = [
                "format",
                "--recursive",
                "--parallel",
                "--in-place",
                "--configuration",
                "\(configFile)",
                "\(sourceTarget.directory)",
            ]
            let process = try Process.run(toolExecURL, arguments: arguments)
            process.waitUntilExit()

            if process.terminationReason == Process.TerminationReason.exit &&
                process.terminationStatus == 0 {
                print("Finished linting source code in \(target.directory)")
            } else {
                let problem = "\(process.terminationReason):\(process.terminationStatus)"
                Diagnostics.error("Linting \(sourceTarget.directory) failed: \(problem)")
            }
        }
    }
}
