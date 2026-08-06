//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022-2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing
import FoundationMacros
import SwiftIfConfig

@Suite("#bundle Macro")
private struct BundleMacroTests {

    func buildConditions(_ conditions: Set<String>) -> StaticBuildConfiguration {
        StaticBuildConfiguration(customConditions: conditions, languageVersion: VersionTuple(components: [6, 0]), compilerVersion: VersionTuple(components: [6, 2]))
    }

    @Test func noBuildConfig() {
        AssertMacroExpansion(
            macros: ["bundle": BundleMacro.self],
            """
            #bundle
            """,
            diagnostics: ["1:1: #bundle was not provided a build configuration."]
        )
    }

    @Test func simple() {
        AssertMacroExpansion(
            macros: ["bundle": BundleMacro.self],
            """
            #bundle
            """,
            """
            unsafe Bundle(_dsoHandle: #dsohandle) ?? .main
            """,
            buildConfiguration: buildConditions([])
        )
    }

    @Test func simpleUsingParenthesis() {
        AssertMacroExpansion(
            macros: ["bundle": BundleMacro.self],
            """
            #bundle()
            """,
            """
            unsafe Bundle(_dsoHandle: #dsohandle) ?? .main
            """,
            buildConfiguration: buildConditions([])
        )
    }

    @Test func moduleResourceBundle() {
        AssertMacroExpansion(
            macros: ["bundle": BundleMacro.self],
            """
            #bundle
            """,
            """
            Bundle.module
            """,
            buildConfiguration: buildConditions(["SWIFT_MODULE_RESOURCE_BUNDLE_AVAILABLE"])
        )

        AssertMacroExpansion(
            macros: ["bundle": BundleMacro.self],
            """
            #bundle
            """,
            diagnostics: ["1:1: No resource bundle is available for this module. If resources are included elsewhere, specify the bundle manually."],
            buildConfiguration: buildConditions(["SWIFT_MODULE_RESOURCE_BUNDLE_UNAVAILABLE"])
        )

        AssertMacroExpansion(
            macros: ["bundle": BundleMacro.self],
            """
            #bundle
            """,
            diagnostics: ["1:1: Both SWIFT_MODULE_RESOURCE_BUNDLE_AVAILABLE and SWIFT_MODULE_RESOURCE_BUNDLE_UNAVAILABLE cannot be set when using #bundle."],
            buildConfiguration: buildConditions(["SWIFT_MODULE_RESOURCE_BUNDLE_AVAILABLE", "SWIFT_MODULE_RESOURCE_BUNDLE_UNAVAILABLE"])
        )
    }

    @Test func lookupHelper() {
        AssertMacroExpansion(
            macros: ["bundle": BundleMacro.self],
            """
            #bundle
            """,
            """
            Bundle(for: __BundleLookupHelper.self)
            """,
            buildConfiguration: buildConditions(["SWIFT_BUNDLE_LOOKUP_HELPER_AVAILABLE"])
        )
    }
}
