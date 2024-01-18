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

@available(FoundationPredicate 0.3, *)
package struct DebugStringConversionState {
    private var variables: [PredicateExpressions.VariableID : String]
    private var nextVariable = 1
    private var captures: [String] = []
    private var nextCapture = 1

    var captureDecl: String {
        captures.joined(separator: "\n")
    }

    init(_ variables: [PredicateExpressions.VariableID]) {
        self.variables = Dictionary(uniqueKeysWithValues: variables.enumerated().map {
            ($1, "input\($0 + 1)")
        })
    }

    subscript(_ variable: PredicateExpressions.VariableID) -> String {
        variables[variable] ?? "unknownVariable\(variable.id)"
    }

    mutating func setupVariable(_ variable: PredicateExpressions.VariableID) {
        variables[variable] = "variable\(nextVariable)"
        nextVariable += 1
    }

    mutating func addCapture(_ value: Any) -> String {
        let valueConstruction = switch value as Any {
        case Optional<Any>.none: "nil"
        case let b as Bool: "\(b)"
        case let i as any Numeric: "\(i)"
        case let s as String: "\"\(s.replacing("\"", with: "\\\""))\""
        case let d as Date: "<Date \(d.timeIntervalSince1970)>"
        case let d as Data: "<Data \(d.base64EncodedString())>"
        case let u as UUID: "<UUID \(u.uuidString)>"
        default: "<\(_typeName(type(of: value))): \(String(describing: value).replacing("\n", with: ", "))>"
        }
        captures.append("capture\(nextCapture) (\(_typeName(type(of: value)))): \(valueConstruction)")
        defer { nextCapture += 1 }
        return "capture\(nextCapture)"
    }
}

extension String {
    fileprivate func indentedWithinClosure() -> String {
        var startIndex = self.startIndex
        var endIndex = self.endIndex
        if self.starts(with: "(") {
            self.formIndex(after: &startIndex)
        }
        if self.hasSuffix(")") {
            self.formIndex(before: &endIndex)
        }
        return String(self[startIndex ..< endIndex].replacing("\n", with: "\n    "))
    }
}

extension AnyKeyPath {
    fileprivate var debugStringWithoutType: String {
        let pieces = self.debugDescription.split(separator: ".")
        var idx = pieces.endIndex - 1
        while idx > pieces.startIndex && !pieces[idx].hasSuffix(">") {
            idx -= 1
        }
        return "." + pieces[(idx + 1)...].joined(separator: ".")
    }
}

@available(FoundationPredicate 0.3, *)
package protocol DebugStringConvertiblePredicateExpression : StandardPredicateExpression {
    func debugString(state: inout DebugStringConversionState) -> String
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.Variable : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        state[self.key]
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.KeyPath : DebugStringConvertiblePredicateExpression where Root : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        root.debugString(state: &state) + keyPath.debugStringWithoutType
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.Value : DebugStringConvertiblePredicateExpression where Self : StandardPredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        state.addCapture(value)
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.Conjunction : DebugStringConvertiblePredicateExpression where LHS : DebugStringConvertiblePredicateExpression, RHS : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        "(\(lhs.debugString(state: &state)) && \(rhs.debugString(state: &state)))"
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.Disjunction : DebugStringConvertiblePredicateExpression where LHS : DebugStringConvertiblePredicateExpression, RHS : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        "(\(lhs.debugString(state: &state)) || \(rhs.debugString(state: &state)))"
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.Equal : DebugStringConvertiblePredicateExpression where LHS : DebugStringConvertiblePredicateExpression, RHS : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        "(\(lhs.debugString(state: &state)) == \(rhs.debugString(state: &state)))"
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.NotEqual : DebugStringConvertiblePredicateExpression where LHS : DebugStringConvertiblePredicateExpression, RHS : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        "(\(lhs.debugString(state: &state)) != \(rhs.debugString(state: &state)))"
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.Arithmetic : DebugStringConvertiblePredicateExpression where LHS : DebugStringConvertiblePredicateExpression, RHS : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        let op = switch self.op {
        case .add: "+"
        case .multiply: "*"
        case .subtract: "-"
        }
        return "(\(lhs.debugString(state: &state)) \(op) \(rhs.debugString(state: &state)))"
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.Comparison : DebugStringConvertiblePredicateExpression where LHS : DebugStringConvertiblePredicateExpression, RHS : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        let op = switch self.op {
        case .greaterThan: ">"
        case .greaterThanOrEqual: ">="
        case .lessThan: "<"
        case .lessThanOrEqual: "<="
        }
        return "(\(lhs.debugString(state: &state)) \(op) \(rhs.debugString(state: &state)))"
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.UnaryMinus : DebugStringConvertiblePredicateExpression where Wrapped : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        "-\(wrapped.debugString(state: &state))"
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.SequenceMinimum : DebugStringConvertiblePredicateExpression where Elements : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        "\(elements.debugString(state: &state)).min()"
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.SequenceMaximum : DebugStringConvertiblePredicateExpression where Elements : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        "\(elements.debugString(state: &state)).max()"
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.ClosedRange : DebugStringConvertiblePredicateExpression where LHS : DebugStringConvertiblePredicateExpression, RHS : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        "(\(lower.debugString(state: &state)) ... \(upper.debugString(state: &state)))"
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.Range : DebugStringConvertiblePredicateExpression where LHS : DebugStringConvertiblePredicateExpression, RHS : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        "(\(lower.debugString(state: &state)) ..< \(upper.debugString(state: &state)))"
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.Conditional : DebugStringConvertiblePredicateExpression where Test : DebugStringConvertiblePredicateExpression, If : DebugStringConvertiblePredicateExpression, Else : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        """
        if \(test.debugString(state: &state)) {
            \(trueBranch.debugString(state: &state).indentedWithinClosure())
        } else {
            \(falseBranch.debugString(state: &state).indentedWithinClosure())
        }
        """
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.CollectionIndexSubscript : DebugStringConvertiblePredicateExpression where Wrapped : DebugStringConvertiblePredicateExpression, Index : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        "\(wrapped.debugString(state: &state))[\(index.debugString(state: &state))]"
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.CollectionRangeSubscript : DebugStringConvertiblePredicateExpression where Wrapped : DebugStringConvertiblePredicateExpression, Range : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        "\(wrapped.debugString(state: &state))[\(range.debugString(state: &state))]"
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.CollectionContainsCollection : DebugStringConvertiblePredicateExpression where Base : DebugStringConvertiblePredicateExpression, Other : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        "\(base.debugString(state: &state)).contains(\(other.debugString(state: &state)))"
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.ConditionalCast : DebugStringConvertiblePredicateExpression where Input : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        "(\(input.debugString(state: &state)) as? \(_typeName(Desired.self)))"
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.ForceCast : DebugStringConvertiblePredicateExpression where Input : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        "(\(input.debugString(state: &state)) as! \(_typeName(Desired.self)))"
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.TypeCheck : DebugStringConvertiblePredicateExpression where Input : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        "(\(input.debugString(state: &state)) is \(_typeName(Desired.self)))"
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.ForcedUnwrap : DebugStringConvertiblePredicateExpression where Inner : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        "\(inner.debugString(state: &state))!"
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.OptionalFlatMap : DebugStringConvertiblePredicateExpression where LHS : DebugStringConvertiblePredicateExpression, RHS : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        state.setupVariable(variable.key)
        return """
            \(wrapped.debugString(state: &state)).flatMap({ \(state[variable.key]) in
                \(transform.debugString(state: &state).indentedWithinClosure())
            })
            """
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.DictionaryKeySubscript : DebugStringConvertiblePredicateExpression where Wrapped : DebugStringConvertiblePredicateExpression, Key : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        "\(wrapped.debugString(state: &state))[\(key.debugString(state: &state))]"
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.DictionaryKeyDefaultValueSubscript : DebugStringConvertiblePredicateExpression where Wrapped : DebugStringConvertiblePredicateExpression, Key : DebugStringConvertiblePredicateExpression, Default : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        "\(wrapped.debugString(state: &state))[\(key.debugString(state: &state)), default: \(self.default.debugString(state: &state))]"
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.FloatDivision : DebugStringConvertiblePredicateExpression where LHS : DebugStringConvertiblePredicateExpression, RHS : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        "(\(lhs.debugString(state: &state)) / \(rhs.debugString(state: &state)))"
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.IntDivision : DebugStringConvertiblePredicateExpression where LHS : DebugStringConvertiblePredicateExpression, RHS : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        "(\(lhs.debugString(state: &state)) / \(rhs.debugString(state: &state)))"
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.IntRemainder : DebugStringConvertiblePredicateExpression where LHS : DebugStringConvertiblePredicateExpression, RHS : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        "(\(lhs.debugString(state: &state)) % \(rhs.debugString(state: &state)))"
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.Negation : DebugStringConvertiblePredicateExpression where Wrapped : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        "!\(wrapped.debugString(state: &state))"
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.NilCoalesce : DebugStringConvertiblePredicateExpression where LHS : DebugStringConvertiblePredicateExpression, RHS: DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        "(\(lhs.debugString(state: &state)) ?? \(rhs.debugString(state: &state)))"
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.NilLiteral : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        "nil"
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.RangeExpressionContains : DebugStringConvertiblePredicateExpression where RangeExpression : DebugStringConvertiblePredicateExpression, Element : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        "\(range.debugString(state: &state)).contains(\(element.debugString(state: &state)))"
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.SequenceContains : DebugStringConvertiblePredicateExpression where LHS : DebugStringConvertiblePredicateExpression, RHS: DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        "\(sequence.debugString(state: &state)).contains(\(element.debugString(state: &state)))"
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.SequenceStartsWith : DebugStringConvertiblePredicateExpression where Base : DebugStringConvertiblePredicateExpression, Prefix : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        "\(base.debugString(state: &state)).starts(with: \(prefix.debugString(state: &state)))"
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.SequenceContainsWhere : DebugStringConvertiblePredicateExpression where LHS : DebugStringConvertiblePredicateExpression, RHS : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        state.setupVariable(variable.key)
        return """
            \(sequence.debugString(state: &state)).contains(where: { \(state[variable.key]) in
                \(test.debugString(state: &state).indentedWithinClosure())
            })
            """
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.SequenceAllSatisfy : DebugStringConvertiblePredicateExpression where LHS : DebugStringConvertiblePredicateExpression, RHS : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        state.setupVariable(variable.key)
        return """
            \(sequence.debugString(state: &state)).allSatisfy({ \(state[variable.key]) in
                \(test.debugString(state: &state).indentedWithinClosure())
            })
            """
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.Filter : DebugStringConvertiblePredicateExpression where LHS : DebugStringConvertiblePredicateExpression, RHS : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        state.setupVariable(variable.key)
        return """
            \(sequence.debugString(state: &state)).filter({ \(state[variable.key]) in
                \(filter.debugString(state: &state).indentedWithinClosure())
            })
            """
    }
}

#if FOUNDATION_FRAMEWORK

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.PredicateEvaluate : DebugStringConvertiblePredicateExpression where Condition : DebugStringConvertiblePredicateExpression, repeat each Input : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        var inputStrings: [String] = []
        repeat inputStrings.append((each input).debugString(state: &state))
        return "\(predicate.debugString(state: &state)).evaluate(\(inputStrings.joined(separator: ", ")))"
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.StringCaseInsensitiveCompare : DebugStringConvertiblePredicateExpression where Root : DebugStringConvertiblePredicateExpression, Other : DebugStringConvertiblePredicateExpression {
    package func debugString(state: inout DebugStringConversionState) -> String {
        "\(root.debugString(state: &state)).caseInsensitiveCompare(\(other.debugString(state: &state)))"
    }
}

#endif

@available(FoundationPredicate 0.3, *)
extension Predicate : CustomStringConvertible {
    public var description: String {
        var variableIDs: [PredicateExpressions.VariableID] = []
        repeat variableIDs.append((each variable).key)
        guard let debugConvertible = self.expression as? any DebugStringConvertiblePredicateExpression else {
            fatalError("Internal inconsistency: StandardPredicateExpression does not conform to DebugStringConvertiblePredicateExpression")
        }
        var types: [Any.Type] = []
        repeat types.append((each Input).self)
        let typeNames = types.map {
            _typeName($0)
        }.joined(separator: ", ")
        var state = DebugStringConversionState(variableIDs)
        let variableNames = variableIDs.map {
            state[$0]
        }.joined(separator: ", ")
        let converted = debugConvertible.debugString(state: &state)
        var result = state.captureDecl.isEmpty ? "" : "\(state.captureDecl)\n"
        result.append("""
                        Predicate<\(typeNames)> { \(variableNames) in
                            \(converted.indentedWithinClosure())
                        }
                        """)
        return result
    }
}

@available(FoundationPredicate 0.3, *)
extension Predicate : CustomDebugStringConvertible {
    public var debugDescription: String {
        var variableDesc: [String] = []
        repeat variableDesc.append((each variable).description)
        return "\(_typeName(Self.self))(variable: (\(variableDesc.joined(separator: ", "))), expression: \(expression))"
    }
}
