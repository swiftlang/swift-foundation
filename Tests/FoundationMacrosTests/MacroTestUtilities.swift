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

import Testing
import Foundation
import FoundationMacros
import SwiftSyntax
import SwiftSyntaxMacros
import SwiftParser
import SwiftDiagnostics
import SwiftOperators
import SwiftSyntaxMacroExpansion

#if FOUNDATION_FRAMEWORK
let foundationModuleName = "Foundation"
#else
let foundationModuleName = "FoundationEssentials"
#endif

struct DiagnosticTest : ExpressibleByStringLiteral, Hashable, CustomStringConvertible {
    struct FixItTest : Hashable {
        let message: String
        let result: String
        
        init(_ message: String, result: String) {
            self.message = message
            self.result = result
        }
        
        func matches(_ fixIt: FixIt) -> Bool {
            fixIt.message.message == message && fixIt.changes.first?._result == result
        }
    }
    
    let message: String
    let fixIts: [FixItTest]
    var description: String { message }
    
    var mappedToExpression: Self {
        DiagnosticTest(
            message.replacing("Predicate", with: "Expression").replacing("predicate", with: "expression"),
            fixIts: fixIts.map {
                FixItTest($0.message, result: $0.result.replacing("#Predicate", with: "#Expression"))
            }
        )
    }
    
    init(stringLiteral value: StringLiteralType) {
        message = value
        fixIts = []
    }
    
    init(_ message: String, fixIts: [FixItTest] = []) {
        self.message = message
        self.fixIts = fixIts
    }
    
    func matches(_ diagnostic: Diagnostic) -> Bool {
        func hasProducedFixIt(_ fixIt: FixItTest) -> Bool {
            diagnostic.fixIts.contains { produced in
                fixIt.matches(produced)
            }
        }
        func hasExpectedFixIt(_ fixIt: FixIt) -> Bool {
            fixIts.contains { expected in
                expected.matches(fixIt)
            }
        }
        
        return diagnostic.debugDescription == message &&
                diagnostic.fixIts.allSatisfy(hasExpectedFixIt) &&
                fixIts.allSatisfy(hasProducedFixIt)
    }
}

extension FixIt.Change {
    fileprivate var _result: String {
        switch self {
        case let .replace(_, newNode):
            return newNode.description
        default:
            return "<trivia change>"
        }
    }
}

extension Diagnostic {
    fileprivate var _assertionDescription: String {
        if fixIts.isEmpty {
            return debugDescription
        } else {
            var result = "Message: \(debugDescription)\nFix-Its:\n"
            for fixIt in fixIts {
                result += "\t\(fixIt.message.message)\n\t\(fixIt.changes.first!._result.replacing("\n", with: "\n\t"))"
            }
            return result
        }
    }
}

extension DiagnosticTest {
    fileprivate var _assertionDescription: String {
        if fixIts.isEmpty {
            return message
        } else {
            var result = "Message: \(message)\nFix-Its:\n"
            for fixIt in fixIts {
                result += "\t\(fixIt.message)\n\t\(fixIt.result.replacing("\n", with: "\n\t"))"
            }
            return result
        }
    }
}

func AssertMacroExpansion(macros: [String : Macro.Type], testModuleName: String = "TestModule", testFileName: String = "test.swift", _ source: String, _ result: String = "", diagnostics: Set<DiagnosticTest> = [], sourceLocation: Testing.SourceLocation = #_sourceLocation) {
    let origSourceFile = Parser.parse(source: source)
    let expandedSourceFile: Syntax
    let context: BasicMacroExpansionContext
    do {
        let foldedSourceFile = try OperatorTable.standardOperators.foldAll(origSourceFile).cast(SourceFileSyntax.self)
        context = BasicMacroExpansionContext(sourceFiles: [foldedSourceFile : .init(moduleName: testModuleName, fullFilePath: testFileName)])
        expandedSourceFile = foldedSourceFile.expand(macros: macros) {
            BasicMacroExpansionContext(sharingWith: context, lexicalContext: [$0])
        }
    } catch {
        Issue.record("Operator folding on input source failed with error \(error)")
        return
    }
    let expansionResult = expandedSourceFile.description
    if !context.diagnostics.contains(where: { $0.diagMessage.severity == .error }) {
        #expect(expansionResult == result, sourceLocation: sourceLocation)
    }
    for diagnostic in context.diagnostics {
        if !diagnostics.contains(where: { $0.matches(diagnostic) }) {
            Issue.record("Produced extra diagnostic:\n\(diagnostic._assertionDescription)", sourceLocation: sourceLocation)
        } else {
            let location = context.location(of: diagnostic.node, at: .afterLeadingTrivia, filePathMode: .fileID)
            #expect(location != nil, "Produced diagnostic without attached source information:\n\(diagnostic._assertionDescription)", sourceLocation: sourceLocation)
        }
    }
    for diagnostic in diagnostics {
        if !context.diagnostics.contains(where: { diagnostic.matches($0) }) {
            Issue.record("Failed to produce diagnostic:\n\(diagnostic._assertionDescription)", sourceLocation: sourceLocation)
        }
    }
}

func AssertPredicateExpansion(_ source: String, _ result: String = "", diagnostics: Set<DiagnosticTest> = [], sourceLocation: Testing.SourceLocation = #_sourceLocation) {
    AssertMacroExpansion(
        macros: ["Predicate": PredicateMacro.self],
        source,
        result,
        diagnostics: diagnostics,
        sourceLocation: sourceLocation
    )
    AssertMacroExpansion(
        macros: ["Expression" : FoundationMacros.ExpressionMacro.self],
        source.replacing("#Predicate", with: "#Expression"),
        result.replacing(".Predicate", with: ".Expression"),
        diagnostics: Set(diagnostics.map(\.mappedToExpression)),
        sourceLocation: sourceLocation
    )
}
