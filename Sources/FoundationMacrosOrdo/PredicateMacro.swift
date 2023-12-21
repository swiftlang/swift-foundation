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

import SwiftSyntax
import SwiftSyntaxMacros

#if FOUNDATION_FRAMEWORK
@_implementationOnly import SwiftDiagnostics
@_implementationOnly import SwiftSyntaxBuilder
#else
package import SwiftDiagnostics
package import SwiftSyntaxBuilder
#endif

// A list of all functions supported by Predicate itself, any other functions called will be diagnosed as an error
// This allows for checking the function name, the number of arguments, and the argument labels, but the types of the arguments will need to be validated by the post-expansion type checking pass
// The trailingClosure parameter indicates whether the final argument is a closure and therefore supports dropping the final argument label in favor of a trailing closure
private var _knownSupportedFunctions: Set<FunctionStructure> = [
    FunctionStructure("contains", arguments: [.unlabeled]),
    FunctionStructure("contains", arguments: [.closure(labeled: "where")]),
    FunctionStructure("allSatisfy", arguments: [.closure(labeled: nil)]),
    FunctionStructure("flatMap", arguments: [.closure(labeled: nil)]),
    FunctionStructure("filter", arguments: [.closure(labeled: nil)]),
    FunctionStructure("subscript", arguments: [.unlabeled]),
    FunctionStructure("subscript", arguments: [.unlabeled, "default"]),
    FunctionStructure("starts", arguments: ["with"]),
    FunctionStructure("min", arguments: []),
    FunctionStructure("max", arguments: []),
    FunctionStructure("localizedStandardContains", arguments: [.unlabeled]),
    FunctionStructure("localizedCompare", arguments: [.unlabeled]),
    FunctionStructure("caseInsensitiveCompare", arguments: [.unlabeled])
]

private var knownSupportedFunctions: Set<FunctionStructure> {
    #if FOUNDATION_FRAMEWORK
    var result = _knownSupportedFunctions
    result.insert(FunctionStructure("evaluate", arguments: [.pack(labeled: nil)]))
    return result
    #else
    _knownSupportedFunctions
    #endif
}

private let supportedFunctionSuggestions: [FunctionStructure : FunctionStructure] = [
    FunctionStructure("hasPrefix", arguments: [.unlabeled]) : FunctionStructure("starts", arguments: ["with"]),
    FunctionStructure("localizedCaseInsensitiveContains", arguments: [.unlabeled]) : FunctionStructure("localizedStandardContains", arguments: [.unlabeled]),
    FunctionStructure("localizedCaseInsensitiveCompare", arguments: [.unlabeled]) : FunctionStructure("localizedCompare", arguments: [.unlabeled]),
    FunctionStructure("localizedStandardCompare", arguments: [.unlabeled]) : FunctionStructure("localizedCompare", arguments: [.unlabeled])
]

extension Array where Element == FunctionStructure.Argument {
    fileprivate func argumentsEqual(_ other: Self) -> Bool {
        let currentPackIndex = self.firstIndex { $0.kind == .pack }
        let otherPackIndex = other.firstIndex { $0.kind == .pack }

        var full: [FunctionStructure.Argument]
        var prefix: ArraySlice<FunctionStructure.Argument>
        var suffix: ArraySlice<FunctionStructure.Argument>
        switch (currentPackIndex, otherPackIndex) {
        // If neither contains a pack or both contain a pack, just compare arguments as-is
        case (nil, nil), (.some(_), .some(_)):
            return self == other

        // If one of them contains a pack, compare the prefix and suffix to allow the pack to lazily consume multiple arguments
        case (let .some(idx), nil):
            full = other
            prefix = self[..<idx]
            suffix = self[self.index(after: idx)...]
        case (nil, let .some(idx)):
            full = self
            prefix = other[..<idx]
            suffix = other[other.index(after: idx)...]
        }
        return full.starts(with: prefix) && full.reversed().starts(with: suffix.reversed())
    }

    fileprivate func expandingPackToMatchCount(_ otherCount: Int) -> Self {
        let countDifference = otherCount - self.count
        guard countDifference >= 0, let packIdx = self.firstIndex(where: { $0.kind == .pack }) else {
            return self
        }

        var copy = self
        copy[packIdx] = .init(label: copy[packIdx].label, kind: .standard)
        if countDifference > 0 {
            copy.insert(contentsOf: Array(repeating: .unlabeled, count: countDifference), at: packIdx + 1)
        }
        return copy
    }
}

//#if FOUNDATION_FRAMEWORK
//private let moduleName = "Foundation"
//#else
private let moduleName = "FoundationEssentials"
// #endif

private struct FunctionStructure: Hashable {
    struct Argument : Hashable, ExpressibleByStringLiteral {
        enum Kind : Hashable {
            case standard
            case closure
            case pack
        }
        
        let label: String?
        let kind: Kind
        
        init(stringLiteral: String) {
            label = stringLiteral
            kind = .standard
        }
        
        init(label: String?, kind: Kind) {
            self.label = label
            self.kind = kind
        }
        
        static func closure(labeled label: String?) -> Self {
            Self(label: label, kind: .closure)
        }
        
        static var unlabeled: Self {
            Self(label: nil, kind: .standard)
        }
            
        static func pack(labeled label: String?) -> Self {
            Self(label: label, kind: .pack)
        }
        
        static func ==(lhs: Self, rhs: Self) -> Bool {
            lhs.label == rhs.label
        }
    }
    let name: String
    let arguments: [Argument]
    let hasTrailingClosure: Bool
    
    var supportsTrailingClosure: Bool {
        hasTrailingClosure || arguments.last?.kind == .closure
    }
    
    var signature: String {
        let args = arguments.map { ($0.label ?? "_") + ":" }.joined()
        return "\(name)(\(args))"
    }
    
    init(_ name: String, arguments: [Argument], trailingClosure: Bool = false) {
        self.name = name
        self.arguments = arguments
        self.hasTrailingClosure = trailingClosure
    }
    
    func matches(_ other: FunctionStructure) -> Bool {
        guard self.name == other.name else { return false }
        
        switch (self.hasTrailingClosure, other.hasTrailingClosure) {
        case (true, true), (false, false):
            return self.arguments.argumentsEqual(other.arguments)
        case (true, false):
            guard let otherLast = other.arguments.last else { return false }
            return self.arguments.argumentsEqual(other.arguments.dropLast()) && otherLast.kind == .closure
        case (false, true):
            guard let last = self.arguments.last else { return false }
            return self.arguments.dropLast().argumentsEqual(other.arguments) && last.kind == .closure
        }
    }
    
    func fixItChanges(transformingFrom source: FunctionCallExprSyntax) -> [FixIt.Change]? {
        let sourceHasTrailingClosure = source.trailingClosure != nil
        if sourceHasTrailingClosure {
            guard supportsTrailingClosure else { return nil }
        }
        let sourceArgumentTotalCount = source.arguments.count + (sourceHasTrailingClosure ? 1 : 0)
        let argumentTotalCount = self.arguments.count + (hasTrailingClosure ? 1 : 0)
        guard argumentTotalCount == sourceArgumentTotalCount,
              let calledExpr = source.calledExpression.as(MemberAccessExprSyntax.self) else {
            return nil
        }
        var newFunctionCall = source
        newFunctionCall.calledExpression = ExprSyntax(calledExpr.with(\.declName, DeclReferenceExprSyntax(baseName: .identifier(name))))
        newFunctionCall.arguments = LabeledExprListSyntax(zip(source.arguments, arguments).map {
            if let newLabel = $1.label {
                return $0.with(\.label, .identifier(newLabel)).with(\.colon, .colonToken()).with(\.expression, $0.expression.with(\.leadingTrivia, [.spaces(1)]))
            } else {
                return $0.with(\.label, nil).with(\.colon, nil).with(\.trailingTrivia, []).with(\.expression, $0.expression.with(\.leadingTrivia, []))
            }
        })
        newFunctionCall.leadingTrivia = []
        newFunctionCall.trailingTrivia = []
        if self.hasTrailingClosure && source.trailingClosure == nil, let newTrailingClosure = source.arguments.last?.expression.as(ClosureExprSyntax.self) {
            newFunctionCall.trailingClosure = newTrailingClosure
        }
        return [.replace(oldNode: Syntax(source), newNode: Syntax(newFunctionCall))]
    }
}

private func _knownMatchingFunction(_ structure: FunctionStructure) -> FunctionStructure? {
    knownSupportedFunctions.first {
        $0.matches(structure)
    }
}

private func _suggestionForUnknownFunction(_ structure: FunctionStructure) -> FunctionStructure? {
    guard let key = supportedFunctionSuggestions.keys.first(where: { $0.matches(structure) }) else {
        return nil
    }
    return supportedFunctionSuggestions[key]
}

private class ShorthandArgumentIdentifierDetector: SyntaxVisitor {
    var found = false

    override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
        // Look for identifiers such as $0, $1, etc.
        if case let .dollarIdentifier(identifier) = node.baseName.tokenKind, identifier.dropFirst().allSatisfy(\.isNumber) {
            found = true
            return .skipChildren
        } else {
            return .visitChildren
        }
    }
}

extension SyntaxProtocol {
    var containsShorthandArgumentIdentifiers: Bool {
        let visitor = ShorthandArgumentIdentifierDetector(viewMode: .all)
        visitor.walk(self)
        return visitor.found
    }
}

private protocol PredicateSyntaxRewriter : SyntaxRewriter {
    var success: Bool { get }
    var diagnostics: [Diagnostic] { get }
}

extension PredicateSyntaxRewriter {
    var success: Bool { true }
    var diagnostics: [Diagnostic] { [] }
}

extension SyntaxProtocol {
    fileprivate func rewrite(with rewriter: some PredicateSyntaxRewriter) throws -> Syntax {
        let translated = rewriter.rewrite(Syntax(self))
        guard rewriter.success else {
            throw DiagnosticsError(diagnostics: rewriter.diagnostics)
        }
        return translated
    }
}

private class OptionalChainRewriter: SyntaxRewriter, PredicateSyntaxRewriter {
    var withinValidChainingTreeStart = true
    var withinChainingTree = false
    var optionalInput: ExprSyntax? = nil
    
    private func _prePossibleTopOfTree() -> Bool {
        if !withinChainingTree && withinValidChainingTreeStart {
            withinChainingTree = true
            return true
        }
        return false
    }
    
    private func _postTopOfTree(_ node: ExprSyntax) -> ExprSyntax {
        assert(withinChainingTree)
        withinChainingTree = false
        if let input = optionalInput {
            optionalInput = nil
            let visited = self.visit(input)
            let closure = ClosureExprSyntax(statements: [CodeBlockItemSyntax(item: CodeBlockItemSyntax.Item(node))])
            let functionMember = MemberAccessExprSyntax(base: visited, name: "flatMap")
            let functionCall = FunctionCallExprSyntax(calledExpression: functionMember, arguments: [], trailingClosure: closure)
            return ExprSyntax(functionCall)
        }
        return node
    }
    
    override func visit(_ node: ClosureExprSyntax) -> ExprSyntax {
        guard withinChainingTree else {
            // If we're not already in a chaining tree, just keep progressing with our current rewriter
            return super.visit(node)
        }
        
        // We're in the middle of a potential tree, so rewrite the closure with a fresh state
        // This ensures potential chaining in the closure isn't rewritten outside of the closure
        guard let rewritten = (try? node.rewrite(with: OptionalChainRewriter()))?.as(ExprSyntax.self) else {
            // If rewriting the closure failed, just leave the closure as-is
            return ExprSyntax(node)
        }
        return rewritten
    }
    
    override func visit(_ node: FunctionCallExprSyntax) -> ExprSyntax {
        let priorValidTreeStart = withinValidChainingTreeStart
        defer { withinValidChainingTreeStart = priorValidTreeStart }
        
        if node.arguments.containsShorthandArgumentIdentifiers {
            withinValidChainingTreeStart = false
        }
        
        let topOfTree = _prePossibleTopOfTree()
        let visited = super.visit(node)
        if topOfTree {
            return _postTopOfTree(visited)
        } else {
            return visited
        }
    }
    
    override func visit(_ node: MemberAccessExprSyntax) -> ExprSyntax {
        let topOfTree = _prePossibleTopOfTree()
        let visited = super.visit(node)
        if topOfTree {
            return _postTopOfTree(visited)
        } else {
            return visited
        }
    }
    
    override func visit(_ node: OptionalChainingExprSyntax) -> ExprSyntax {
        guard withinChainingTree else {
            return super.visit(node)
        }
        // Capture the optional input, and replace it in the output expression with a "$0"
        optionalInput = node.expression
        return .init(DeclReferenceExprSyntax(baseName: .dollarIdentifier("$0")))
    }
}

extension CodeBlockItemListSyntax.Element.Item {
    fileprivate var _expression: ExprSyntax? {
        switch self {
        case .expr(let expr): return expr
        case .stmt(let stmt): return stmt.as(ExpressionStmtSyntax.self)?.expression
        default: return nil
        }
    }
}

extension ConditionElementListSyntax {
    fileprivate var optionalBindings: [OptionalBindingConditionSyntax]? {
        var result = [OptionalBindingConditionSyntax]()
        for element in self {
            switch element.condition {
            case let .optionalBinding(binding):
                result.append(binding)
            default:
                return nil
            }
        }
        return result
    }
}

extension ClosureParameterListSyntax {
    fileprivate var withVariableWrappedTypes: Self {
        return Self(self.map {
            if let type = $0.type {
                $0.with(\.type, "PredicateExpressions.Variable<\(type)>")
            } else {
                $0
            }
        })
    }
}

extension KeyPathExprSyntax {
    private enum KeyPathDirectExpressionRewritingError : Error {
        case unknownKeypathComponentType
    }
    
    fileprivate func asDirectExpression(on base: some ExprSyntaxProtocol) -> ExprSyntax? {
        var result = ExprSyntax(base)
        for item in components {
            switch item.component {
            case .property(let prop):
                result = ExprSyntax(MemberAccessExprSyntax(base: result, declName: prop.declName))
            case .optional(let opt):
                if opt.questionOrExclamationMark.tokenKind == .exclamationMark {
                    result = ExprSyntax(ForceUnwrapExprSyntax(expression: result))
                } else {
                    result = ExprSyntax(OptionalChainingExprSyntax(expression: result))
                }
            case .subscript(let sub):
                result = ExprSyntax(SubscriptCallExprSyntax(calledExpression: result, arguments: sub.arguments))
#if FOUNDATION_FRAMEWORK
            default:
                return nil
#endif
            }
        }
        return result
    }
}

private class PredicateQueryRewriter: SyntaxRewriter, PredicateSyntaxRewriter {
    private let indentWidth: Trivia = .spaces(4)
    private var indentLevel = 0
    private var indent: Trivia {
        Trivia(pieces: Array(repeating: .spaces(4), count: indentLevel))
    }
    var validOptionalChainingTree = true
    var diagnostics: [Diagnostic] = []
    var success: Bool { diagnostics.isEmpty }
    
    private func diagnose(node: SyntaxProtocol, message: PredicateExpansionDiagnostic, fixIts: [FixIt] = []) {
        diagnostics.append(.init(node: Syntax(node), message: message, fixIts: fixIts))
    }
    
    private func makeArgument(label: String?, _ expression: ExprSyntax, shouldVisit: Bool = true, shouldIndent: Bool = true) -> LabeledExprSyntax {
        if shouldIndent {
            indentLevel += 1
        }
        defer {
            if shouldIndent {
                indentLevel -= 1
            }
        }
        
        let labelSyntax = label.map {
            TokenSyntax(.identifier($0), presence: .present)
        }?.with(\.leadingTrivia, indent)
        
        let colonSyntax = label.map { _ in
            TokenSyntax(.colon, presence: .present)
        }
        
        var argument = shouldVisit ? visit(expression) : expression
        
        if shouldVisit && argument == expression {
            argument = "PredicateExpressions.build_Arg(\(expression.with(\.leadingTrivia, []).with(\.trailingTrivia, [])))"
        }
        
        argument = argument.with(\.leadingTrivia, label == nil ? indent : .space)
        return .init(label: labelSyntax,
                     colon: colonSyntax,
                     expression: argument,
                     trailingComma: nil)
    }
    
    override func visit(_ node: PrefixOperatorExprSyntax) -> ExprSyntax {
        switch node.operator.text {
        case "!":
            let syntax: ExprSyntax =
                """
                \(raw: indent)PredicateExpressions.build_Negation(
                \(makeArgument(label: nil, node.expression))
                \(raw: indent))
                """
            
            return syntax
        case "-":
            let syntax: ExprSyntax =
                """
                \(raw: indent)PredicateExpressions.build_UnaryMinus(
                \(makeArgument(label: nil, node.expression))
                \(raw: indent))
                """
            
            return syntax
        default:
            diagnose(node: node.operator, message: "The '\(node.operator.text)' operator is not supported in this predicate")
            return ExprSyntax(node)
        }
    }
    
    override func visit(_ node: InfixOperatorExprSyntax) -> ExprSyntax {
        let lhsOp =  node.leftOperand
        let rhsOp = node.rightOperand
        let opExpr = node.operator
        
        guard let opSyntax = opExpr.as(BinaryOperatorExprSyntax.self) else {
            diagnose(node: opExpr, message: "The '\(opExpr.description)' operator is not supported in this predicate")
            return ExprSyntax(node)
        }
        
        let (lhsLabel, rhsLabel) = switch opSyntax.operator.text {
        case "...", "..<": ("lower", "upper")
        default: ("lhs", "rhs")
        }
        
        let lhsArgument = makeArgument(label: lhsLabel, lhsOp).with(\.trailingTrivia, [])
        let rhsArgument = makeArgument(label: rhsLabel, rhsOp).with(\.trailingTrivia, [])
        
        switch (opSyntax.operator.text) {
        case "==":
            let syntax: ExprSyntax =
                """
                \(raw: indent)PredicateExpressions.build_Equal(
                \(lhsArgument),
                \(rhsArgument)
                \(raw: indent))
                """
            
            return syntax
        case "!=":
            let syntax: ExprSyntax =
                """
                \(raw: indent)PredicateExpressions.build_NotEqual(
                \(lhsArgument),
                \(rhsArgument)
                \(raw: indent))
                """
            
            return syntax
        case "<":
            let syntax: ExprSyntax =
                """
                \(raw: indent)PredicateExpressions.build_Comparison(
                \(lhsArgument),
                \(rhsArgument),
                \(raw: indent + indentWidth)op: .lessThan
                \(raw: indent))
                """
            
            return syntax
        case "<=":
            let syntax: ExprSyntax =
                """
                \(raw: indent)PredicateExpressions.build_Comparison(
                \(lhsArgument),
                \(rhsArgument),
                \(raw: indent + indentWidth)op: .lessThanOrEqual
                \(raw: indent))
                """
            
            return syntax
        case ">":
            let syntax: ExprSyntax =
                """
                \(raw: indent)PredicateExpressions.build_Comparison(
                \(lhsArgument),
                \(rhsArgument),
                \(raw: indent + indentWidth)op: .greaterThan
                \(raw: indent))
                """
            
            return syntax
        case ">=":
            let syntax: ExprSyntax =
                """
                \(raw: indent)PredicateExpressions.build_Comparison(
                \(lhsArgument),
                \(rhsArgument),
                \(raw: indent + indentWidth)op: .greaterThanOrEqual
                \(raw: indent))
                """
            
            return syntax
        case "||":
            let syntax: ExprSyntax =
                """
                \(raw: indent)PredicateExpressions.build_Disjunction(
                \(lhsArgument),
                \(rhsArgument)
                \(raw: indent))
                """
            
            return syntax
        case "&&":
            let syntax: ExprSyntax =
                """
                \(raw: indent)PredicateExpressions.build_Conjunction(
                \(lhsArgument),
                \(rhsArgument)
                \(raw: indent))
                """
            
            return syntax
        case "+":
            let syntax: ExprSyntax =
                """
                \(raw: indent)PredicateExpressions.build_Arithmetic(
                \(lhsArgument),
                \(rhsArgument),
                \(raw: indent + indentWidth)op: .add
                \(raw: indent))
                """
            
            return syntax
        case "-":
            let syntax: ExprSyntax =
                """
                \(raw: indent)PredicateExpressions.build_Arithmetic(
                \(lhsArgument),
                \(rhsArgument),
                \(raw: indent + indentWidth)op: .subtract
                \(raw: indent))
                """
            
            return syntax
        case "*":
            let syntax: ExprSyntax =
                """
                \(raw: indent)PredicateExpressions.build_Arithmetic(
                \(lhsArgument),
                \(rhsArgument),
                \(raw: indent + indentWidth)op: .multiply
                \(raw: indent))
                """
            
            return syntax
        case "/":
            let syntax: ExprSyntax =
                """
                \(raw: indent)PredicateExpressions.build_Division(
                \(lhsArgument),
                \(rhsArgument)
                \(raw: indent))
                """
            
            return syntax
        case "%":
            let syntax: ExprSyntax =
                """
                \(raw: indent)PredicateExpressions.build_Remainder(
                \(lhsArgument),
                \(rhsArgument)
                \(raw: indent))
                """
            
            return syntax
        case "??":
            let syntax: ExprSyntax =
                """
                \(raw: indent)PredicateExpressions.build_NilCoalesce(
                \(lhsArgument),
                \(rhsArgument)
                \(raw: indent))
                """
            
            return syntax
            
        case "...":
            let syntax: ExprSyntax =
                """
                \(raw: indent)PredicateExpressions.build_ClosedRange(
                \(lhsArgument),
                \(rhsArgument)
                \(raw: indent))
                """
            
            return syntax
            
        case "..<":
            let syntax: ExprSyntax =
                """
                \(raw: indent)PredicateExpressions.build_Range(
                \(lhsArgument),
                \(rhsArgument)
                \(raw: indent))
                """
            
            return syntax
        default:
            diagnose(node: opSyntax, message: "The '\(opSyntax.operator.text)' operator is not supported in this predicate")
            return ExprSyntax(node)
        }
    }
    
    // We only hit this if our OptionalChainingRewriter was unable to rewrite them out of the expression tree
    override func visit(_ node: OptionalChainingExprSyntax) -> ExprSyntax {
        diagnose(node: node.questionMark, message: "Optional chaining is not supported here in this predicate. Use the flatMap(_:) function explicitly instead.")
        return .init(node)
    }
    
    override func visit(_ node: ForceUnwrapExprSyntax) -> ExprSyntax {
        return """
                \(raw: indent)PredicateExpressions.build_ForcedUnwrap(
                \(makeArgument(label: nil, node.expression))
                \(raw: indent))
                """
    }
    
    override func visit(_ node: NilLiteralExprSyntax) -> ExprSyntax {
        "PredicateExpressions.build_NilLiteral()"
    }
    
    override func visit(_ node: MemberAccessExprSyntax) -> ExprSyntax {
        guard let base = node.base else {
            diagnose(node: node, message: "Member access without an explicit base is not allowed in this predicate")
            return .init(node)
        }
        
        let newPropertyComponent = KeyPathPropertyComponentSyntax(declName: node.declName)
        let keyPath = KeyPathExprSyntax(components: [.init(period: TokenSyntax.periodToken(), component: .property(newPropertyComponent))])
        return """
                \(raw: indent)PredicateExpressions.build_KeyPath(
                \(makeArgument(label: "root", base)),
                \(makeArgument(label: "keyPath", .init(keyPath), shouldVisit: false).with(\.trailingTrivia, []))
                \(raw: indent))
                """
    }
    
    override func visit(_ node: FunctionCallExprSyntax) -> ExprSyntax {
        let memberAccess = node.calledExpression.as(MemberAccessExprSyntax.self)
        let base = memberAccess?.base
        let funcName = memberAccess?.declName.baseName.with(\.leadingTrivia, []).with(\.trailingTrivia, []).text ?? node.calledExpression.as(DeclReferenceExprSyntax.self)!.baseName.text
        return _processFunction(
            base: base,
            functionName: funcName,
            argumentList: node.arguments,
            trailingClosure: node.trailingClosure,
            diagnosticPoint: .init(memberAccess?.declName) ?? .init(node),
            functionCallExpr: node)
        ?? .init(node)
    }
    
    override func visit(_ node: SubscriptCallExprSyntax) -> ExprSyntax {
        return _processFunction(
            base: node.calledExpression,
            functionName: "subscript",
            argumentList: node.arguments,
            trailingClosure: node.trailingClosure,
            diagnosticPoint: .init(node.leftSquare))
        ?? .init(node)
    }
    
    private func _processFunction(base: ExprSyntax?, functionName: String, argumentList: LabeledExprListSyntax, trailingClosure: ClosureExprSyntax?, diagnosticPoint: Syntax, functionCallExpr: FunctionCallExprSyntax? = nil) -> ExprSyntax? {
        // The provided base is nil when calling global functions functions
        guard let base else {
            diagnose(node: diagnosticPoint, message: "Global functions are not supported in this predicate")
            return nil
        }
        
        // Check this function against our known list to provide rich diagnostics for functions we know we don't support
        let name = TokenSyntax(.identifier(functionName), presence: .present).with(\.leadingTrivia, []).with(\.trailingTrivia, [])
        let args = argumentList.map {
            let isClosure = $0.expression.is(ClosureExprSyntax.self) || $0.expression.is(KeyPathExprSyntax.self)
            return FunctionStructure.Argument(label: $0.label?.text, kind: isClosure ? .closure : .standard)
        }
        let structure = FunctionStructure(name.text, arguments: args, trailingClosure: trailingClosure != nil)
        guard let knownFunc = _knownMatchingFunction(structure) else {
            let diagnostic = PredicateExpansionDiagnostic("The \(structure.signature) function is not supported in this predicate")
            var fixIts = [FixIt]()
            if let functionCallExpr,
               let suggestion = _suggestionForUnknownFunction(structure),
               let changes = suggestion.fixItChanges(transformingFrom: functionCallExpr) {
                fixIts.append(FixIt(message: PredicateExpansionDiagnostic("Use \(suggestion.signature)", severity: .note), changes: changes))
            }
            diagnose(node: diagnosticPoint, message: diagnostic, fixIts: fixIts)
            return nil
        }
        
        var arguments: [LabeledExprSyntax] = []
        func addArgument(_ argument: ExprSyntax, label: String?, withComma: Bool) {
            arguments.append(
                makeArgument(label: label, argument)
                    .with(\.trailingComma, withComma ? TokenSyntax(.comma, presence: .present) : nil)
                    .with(\.trailingTrivia, withComma ? .newline : [])
            )
        }
        
        // Function arguments can contain dollar sign identifiers that can't be nested inside of a new closure
        // Prevent this function call from being placed inside of a flatMap due to optionalChaining
        let oldValidOptionalChainingTree = validOptionalChainingTree
        validOptionalChainingTree = false
        addArgument(base, label: nil, withComma: !argumentList.isEmpty)
        validOptionalChainingTree = oldValidOptionalChainingTree
        
        for (sourceArg, knownArgStructure) in zip(argumentList, knownFunc.arguments.expandingPackToMatchCount(argumentList.count)) {
            var expression = sourceArg.expression
            if knownArgStructure.kind == .closure, let kpExpr = sourceArg.expression.as(KeyPathExprSyntax.self) {
                guard !kpExpr.containsShorthandArgumentIdentifiers,
                      let memberAccess = kpExpr.asDirectExpression(on: DeclReferenceExprSyntax(baseName: .dollarIdentifier("$0"))),
                      let preparedMemberAccess = try? memberAccess.rewrite(with: OptionalChainRewriter()) else {
                    diagnose(node: kpExpr, message: "This key path is not supported here in this predicate. Use an explicit closure instead.")
                    return nil
                }
                expression = ExprSyntax(ClosureExprSyntax(statements: [CodeBlockItemSyntax(item: .expr(preparedMemberAccess.as(ExprSyntax.self)!))]))
            }
            addArgument(expression, label: sourceArg.label?.text, withComma: sourceArg.trailingComma != nil)
        }
        
        if let closure = trailingClosure {
            // Don't indent, because closures already get indented
            let closureArg = makeArgument(label: nil, ExprSyntax(closure), shouldIndent: false)
            return """
             \(raw: indent)PredicateExpressions.build_\(name.with(\.leadingTrivia, []).with(\.trailingTrivia, []))(
             \(LabeledExprListSyntax(arguments))
             \(raw: indent))\(raw: Trivia.space)\(closureArg.with(\.leadingTrivia, []).with(\.trailingTrivia, []))
             """
        } else {
            return """
             \(raw: indent)PredicateExpressions.build_\(name.with(\.leadingTrivia, []).with(\.trailingTrivia, []))(
             \(LabeledExprListSyntax(arguments))
             \(raw: indent))
             """
        }
    }
    
    override func visit(_ node: TupleExprSyntax) -> ExprSyntax {
        guard node.elements.count == 1, let element = node.elements.first else {
            diagnose(node: node, message: "Tuples are not supported in this predicate")
            return ExprSyntax(node)
        }
        
        // Support expressions like "(input as? Bool) == true" where parantheses used for grouping are treated like a single element tuple expression
        return visit(element.expression)
    }
    
    // Processes a code block and guarantees that the returned code block only contains one item
    func _processCodeBlock(_ statements: CodeBlockItemListSyntax, in node: Syntax, removeReturn: Bool = false) -> CodeBlockItemListSyntax? {
        guard statements.count == 1 else {
            diagnose(node: statements.isEmpty ? node : statements[statements.index(after: statements.startIndex)], message: "Predicate body may only contain one expression")
            return nil
        }
        
        indentLevel += 1
        var body = visit(statements)
        if success && body == statements {
            let wrapped: ExprSyntax =
                """
                \(raw: indent)PredicateExpressions.build_Arg(
                \(raw: indent + indentWidth)\(body.with(\.leadingTrivia, []).with(\.trailingTrivia, []))
                \(raw: indent))
                """
            body = [.init(item: .expr(wrapped))]
        }
        indentLevel -= 1
        
        if removeReturn, let first = body.first, case .stmt(let statement) = first.item, let returnStmt = statement.as(ReturnStmtSyntax.self), let returnExpr = returnStmt.expression {
            body = [.init(item: .expr(returnExpr.with(\.leadingTrivia, returnStmt.leadingTrivia)))]
        }
        return body
    }
    
    override func visit(_ node: CodeBlockSyntax) -> CodeBlockSyntax {
        guard let body = _processCodeBlock(node.statements, in: .init(node)) else {
            return node
        }
        return node.with(\.statements, body)
    }
    
    override func visit(_ node: ClosureExprSyntax) -> ExprSyntax {
        guard let body = _processCodeBlock(node.statements, in: .init(node)) else {
            return .init(node)
        }
        
        var resultingSignature = node.signature
        if let signature = node.signature {
            var visited = signature
            visited.returnClause = nil
            if case .parameterClause(let paramClause) = signature.parameterClause {
                let newParamClause = paramClause.with(\.parameters, paramClause.parameters.withVariableWrappedTypes)
                visited.parameterClause = .parameterClause(newParamClause)
            }
            resultingSignature = visited
        }
        
        return ExprSyntax(
            node
            .with(\.statements, body)
            .with(\.leftBrace, node.leftBrace.with(\.trailingTrivia, node.signature == nil ? .newline : .space))
            .with(\.signature, resultingSignature?.with(\.trailingTrivia, .newline))
            .with(\.rightBrace, node.rightBrace.with(\.leadingTrivia, .newline + indent))
        )
    }
    
    override func visit(_ node: TernaryExprSyntax) -> ExprSyntax {
        let condition = node.condition
        let firstChoice = node.thenExpression
        let secondChoice = node.elseExpression
        
        return """
         \(raw: indent)PredicateExpressions.build_Conditional(
         \(makeArgument(label: nil, condition).with(\.trailingTrivia, [])),
         \(makeArgument(label: nil, firstChoice).with(\.trailingTrivia, [])),
         \(makeArgument(label: nil, secondChoice).with(\.trailingTrivia, []))
         \(raw: indent))
         """
    }
    
    override func visit(_ node: IsExprSyntax) -> ExprSyntax {
        return """
         \(raw: indent)PredicateExpressions.TypeCheck<_, \(node.type)>(
         \(makeArgument(label: nil, node.expression).with(\.trailingTrivia, []))
         \(raw: indent))
         """
    }
    
    override func visit(_ node: AsExprSyntax) -> ExprSyntax {
        let castType: String
        switch node.questionOrExclamationMark?.tokenKind {
        case .none: fallthrough
        case .some(.exclamationMark):
            castType = "Force"
        case .some(.postfixQuestionMark):
            castType = "Conditional"
        default:
            fatalError("Unexpected question/exclamation mark token kind")
        }
        
        return """
         \(raw: indent)PredicateExpressions.\(raw: castType)Cast<_, \(node.type)>(
         \(makeArgument(label: nil, node.expression).with(\.trailingTrivia, []))
         \(raw: indent))
         """
    }
    
    override func visit(_ node: ReturnStmtSyntax) -> StmtSyntax {
        guard let expression = node.expression else {
            // No expansion needed when returning Void
            return StmtSyntax(node)
        }
        
        let visited = visit(expression)
        guard visited == expression else {
            // No expansion needed when returning transformed expression
            return StmtSyntax(node.with(\.expression, visited.with(\.leadingTrivia, [])).with(\.leadingTrivia, indent))
        }
        
        // Wrap constant return expressions in a build_Arg call
        let wrapped: ExprSyntax =
            """
            PredicateExpressions.build_Arg(
            \(visited.with(\.leadingTrivia, indent + indentWidth))
            \(raw: indent))
            """
        return StmtSyntax(node.with(\.expression, wrapped).with(\.leadingTrivia, indent))
    }
    
    override func visit(_ node: SwitchExprSyntax) -> ExprSyntax {
        self.diagnose(node: node, message: "Switch expressions are not supported in this predicate")
        return .init(node)
    }
    
    private func _rewriteConditionsAsExpression<C: BidirectionalCollection<ConditionElementListSyntax.Element>>(_ collection: C, in expr: IfExprSyntax) -> ExprSyntax? {
        guard let last = collection.last else {
            self.diagnose(node: expr, message: "This list of conditionals is unsupported in this predicate")
            return nil
        }
        guard case .expression(let lastExpr) = last.condition else {
            let type: String
            switch last.condition {
            case .availability(_):
                type = "Availability conditions"
            case .matchingPattern(_):
                type = "Matching pattern conditions"
            case .optionalBinding(_):
                self.diagnose(node: last, message: "Mixing optional bindings with other conditions is not supported in this predicate")
                return nil
            default:
                type = "These types of conditions"
            }
            self.diagnose(node: last, message: "\(type) are not supported in this predicate")
            return nil
        }
        let rest = collection.dropLast()
        if rest.isEmpty {
            return lastExpr
        } else {
            guard let restRewritten = _rewriteConditionsAsExpression(rest, in: expr) else {
                return nil
            }
            return .init(InfixOperatorExprSyntax(leftOperand: restRewritten, operator: BinaryOperatorExprSyntax(operator: .binaryOperator("&&")), rightOperand: lastExpr))
        }
    }
    
    private func _rewriteIfAsFlatMap(bindings: [OptionalBindingConditionSyntax], body: ExprSyntax, else: ExprSyntax) -> ExprSyntax? {
        indentLevel += bindings.count
        
        var prior: ExprSyntax = body
        for binding in bindings.reversed() {
            guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier else {
                self.diagnose(node: binding.pattern, message: "This optional binding condition is not supported in this predicate")
                return nil
            }
            let initializer = binding.initializer?.value ?? ExprSyntax(DeclReferenceExprSyntax(baseName: identifier))
            
            prior = """
             \(raw: indent)PredicateExpressions.build_flatMap(
             \(makeArgument(label: nil, initializer).with(\.trailingTrivia, []))
             \(raw: indent)) { \(identifier.with(\.trailingTrivia, []).with(\.leadingTrivia, [])) in
             \(makeArgument(label: nil, prior, shouldVisit: false).with(\.trailingTrivia, []))
             \(raw: indent)}
             """
            indentLevel -= 1
        }
        
        return """
         \(raw: indent)PredicateExpressions.build_NilCoalesce(
         \(makeArgument(label: "lhs", prior, shouldVisit: false)),
         \(makeArgument(label: "rhs", `else`, shouldVisit: false))
         \(raw: indent))
         """
    }
    
    private func _processIfBody(_ node: IfExprSyntax) -> ExprSyntax? {
        guard let visitedBody = _processCodeBlock(node.body.statements, in: .init(node.body), removeReturn: true) else {
            return nil
        }
        
        guard let bodyExpression = visitedBody.first?.item._expression else {
            self.diagnose(node: node.body, message: "This if expression body is not supported in this predicate")
            return nil
        }
        
        return bodyExpression
    }
    
    private func _processElseBody(_ node: IfExprSyntax) -> ExprSyntax? {
        guard let elseBody = node.elseBody else {
            self.diagnose(node: node, message: "If expressions without an else expression are not supported in this predicate")
            return nil
        }

        let elseExpression: ExprSyntax
        switch elseBody {
        case .codeBlock(let codeBlock):
            guard let visitedElseBody = _processCodeBlock(codeBlock.statements, in: .init(codeBlock), removeReturn: true) else {
                return nil
            }
            guard let expr = visitedElseBody.first?.item._expression else {
                self.diagnose(node: node.body, message: "This if expression else body is not supported in this predicate")
                return nil
            }
            elseExpression = expr
        case .ifExpr(let ifExpr):
            elseExpression = visit(ifExpr)
#if FOUNDATION_FRAMEWORK
        @unknown default:
            self.diagnose(node: elseBody, message: "This if expression else body is not supported in this predicate")
            return nil
#endif
        }
        
        return elseExpression
    }
    
    override func visit(_ node: IfExprSyntax) -> ExprSyntax {
        if let bindings = node.conditions.optionalBindings {
            indentLevel += bindings.count
            guard let bodyExpression = _processIfBody(node) else {
                return .init(node)
            }
            indentLevel -= bindings.count
            guard let elseExpression = _processElseBody(node) else {
                return .init(node)
            }
            return _rewriteIfAsFlatMap(bindings: bindings, body: bodyExpression, else: elseExpression) ?? .init(node)
        }
        
        guard let ifExpression = _rewriteConditionsAsExpression(node.conditions, in: node),
              let bodyExpression = _processIfBody(node),
              let elseExpression = _processElseBody(node) else {
            return .init(node)
        }

        return """
         \(raw: indent)PredicateExpressions.build_Conditional(
         \(makeArgument(label: nil, ifExpression).with(\.trailingTrivia, [])),
         \(makeArgument(label: nil, bodyExpression, shouldVisit: false).with(\.trailingTrivia, [])),
         \(makeArgument(label: nil, elseExpression, shouldVisit: false).with(\.trailingTrivia, []))
         \(raw: indent))
         """
    }
    
    override func visit(_ node: WhileStmtSyntax) -> StmtSyntax {
        self.diagnose(node: node, message: "While loops are not supported in this predicate")
        return .init(node)
    }
    
    override func visit(_ node: ForStmtSyntax) -> StmtSyntax {
        self.diagnose(node: node, message: "For-in loops are not supported in this predicate")
        return .init(node)
    }
    
    override func visit(_ node: DoStmtSyntax) -> StmtSyntax {
        self.diagnose(node: node, message: "Do statements are not supported in this predicate")
        return .init(node)
    }
    
    override func visit(_ node: CatchClauseSyntax) -> CatchClauseSyntax {
        self.diagnose(node: node, message: "Catch clauses are not supported in this predicate")
        return node
    }
    
    override func visit(_ node: RepeatStmtSyntax) -> StmtSyntax {
        self.diagnose(node: node, message: "Repeat-while loops are not supported in this predicate")
        return .init(node)
    }
    
    override func visit(_ node: CodeBlockItemSyntax) -> CodeBlockItemSyntax {
        // At this point, we know we're the only item in the code block because predicates only support single-expression code blocks
        
        // Diagnose any declarations
        if case .decl(_) = node.item {
            diagnose(node: node.item, message: "Declarations are not supported in this predicate")
            return node
        }
        
        if case let .stmt(statement) = node.item {
            // Unwrap a do statement with valid expression bodies
            if let doStatement = statement.as(DoStmtSyntax.self) {
                if let catchClause = doStatement.catchClauses.first {
                    diagnose(node: catchClause, message: "Catch clauses are not supported in this predicate")
                    return node
                }
                indentLevel -= 1
                let visitedBody = self.visit(doStatement.body)
                indentLevel += 1
                guard success else {
                    return node
                }
                guard let innerExpr = visitedBody.statements.first else {
                    diagnose(node: doStatement, message: "Do statement is not supported here in this predicate")
                    return node
                }
                return innerExpr
            }
        }
        
        return super.visit(node)
    }
}

private struct PredicateExpansionDiagnostic: DiagnosticMessage, FixItMessage, ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
    let message: String
    let severity: DiagnosticSeverity
    let diagnosticID: MessageID = .init(domain: "FoundationMacros", id: "PredicateDiagnostic")
    var fixItID: MessageID { diagnosticID }
    
    init(_ message: String, severity: DiagnosticSeverity = .error) {
        self.message = message
        self.severity = severity
    }
    
    init(stringLiteral value: String) {
        self.init(value)
    }
}

public struct PredicateMacro: ExpressionMacro, Sendable {
    public static var formatMode: FormatMode { .disabled }
    
    public static func expansion(of node: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) throws -> ExprSyntax {
        guard let closure = node.trailingClosure else {
            let fixIts: [FixIt]
            if let argument = node.argumentList.first?.expression.as(ClosureExprSyntax.self) {
                var newNode = node.with(\.leftParen, nil)
                    .with(\.rightParen, nil)
                    .with(\.trailingClosure, argument.with(\.leadingTrivia, [.spaces(1)]).with(\.trailingTrivia, []))
                newNode.argumentList = []
                fixIts = [
                    FixIt(message: PredicateExpansionDiagnostic("Use a trailing closure instead of a function parameter", severity: .note), changes: [
                        .replace(oldNode: Syntax(node), newNode: Syntax(newNode))
                    ])
                ]
            } else {
                fixIts = []
            }
            throw DiagnosticsError(diagnostics: [.init(
                node: Syntax(node),
                message: PredicateExpansionDiagnostic("#Predicate macro expansion requires a trailing closure"),
                fixIts: fixIts
            )])
        }
        
        let translatedClosure = try closure.rewrite(with: OptionalChainRewriter()).rewrite(with: PredicateQueryRewriter()).with(\.leadingTrivia, []).with(\.trailingTrivia, [])
        if let genericArgs = node.genericArgumentClause {
            return "\(raw: moduleName).Predicate\(genericArgs.with(\.leadingTrivia, []).with(\.trailingTrivia, []))(\(translatedClosure))"
        } else {
            // When the macro is specified without generic args (ex. "#Predicate { ... }") initialize a Predicate without generic args so they can be inferred from context
            return "\(raw: moduleName).Predicate(\(translatedClosure))"
        }
    }
}
