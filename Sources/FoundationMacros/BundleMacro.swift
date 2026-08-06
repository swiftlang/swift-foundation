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

import SwiftSyntax
import SwiftSyntaxMacros
internal import SwiftSyntaxBuilder
internal import SwiftDiagnostics
internal import SwiftIfConfig

private struct BundleExpansionDiagnostic: DiagnosticMessage {
    let message: String
    let severity: DiagnosticSeverity
    let diagnosticID: MessageID = .init(domain: "FoundationMacros", id: "BundleDiagnostic")

    init(_ message: String, severity: DiagnosticSeverity = .error) {
        self.message = message
        self.severity = severity
    }
}

extension DiagnosticsError {
    fileprivate init(bundleDiagnostic: String, on node: SyntaxProtocol) {
        self.init(diagnostics: [
            Diagnostic(node: node, message: BundleExpansionDiagnostic(bundleDiagnostic))
        ])
    }
}

public struct BundleMacro: SwiftSyntaxMacros.ExpressionMacro, Sendable {
    public static func expansion(of node: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) throws -> ExprSyntax {
        guard let config = context.buildConfiguration else {
            throw DiagnosticsError(bundleDiagnostic: "#bundle was not provided a build configuration.", on: node)
        }

        if try config.isCustomConditionSet(name: "SWIFT_MODULE_RESOURCE_BUNDLE_AVAILABLE") {
            if try config.isCustomConditionSet(name: "SWIFT_MODULE_RESOURCE_BUNDLE_UNAVAILABLE") {
                throw DiagnosticsError(bundleDiagnostic: "Both SWIFT_MODULE_RESOURCE_BUNDLE_AVAILABLE and SWIFT_MODULE_RESOURCE_BUNDLE_UNAVAILABLE cannot be set when using #bundle.", on: node)
            }
            return "Bundle.module"
        } else if try config.isCustomConditionSet(name: "SWIFT_MODULE_RESOURCE_BUNDLE_UNAVAILABLE") {
            throw DiagnosticsError(bundleDiagnostic: "No resource bundle is available for this module. If resources are included elsewhere, specify the bundle manually.", on: node)
        } else if try config.isCustomConditionSet(name: "SWIFT_BUNDLE_LOOKUP_HELPER_AVAILABLE") {
            return "Bundle(for: __BundleLookupHelper.self)"
        } else {
            return "unsafe Bundle(_dsoHandle: #dsohandle) ?? .main"
        }
    }
}
