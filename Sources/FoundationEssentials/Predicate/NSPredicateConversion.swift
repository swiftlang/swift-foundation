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

#if FOUNDATION_FRAMEWORK

@_implementationOnly import Foundation_Private.NSExpression

private struct NSPredicateConversionState {
    private var nextLocalVariable: UInt = 1
    private var variables: [PredicateExpressions.VariableID : NSExpression]
    
    init(object: PredicateExpressions.VariableID) {
        variables = [object : NSExpression.expressionForEvaluatedObject()]
    }
    
    subscript(_ id: PredicateExpressions.VariableID) -> NSExpression {
        get {
            variables[id]!
        }
        set {
            variables[id] = newValue
        }
    }
    
    mutating func makeLocalVariable(for id: PredicateExpressions.VariableID) -> String {
        let variable = "_local_\(nextLocalVariable)"
        nextLocalVariable += 1
        variables[id] = NSExpression(forVariable: variable)
        return variable
    }
}

private enum ExpressionOrPredicate {
    case expression(NSExpression)
    case predicate(NSPredicate)
}

private protocol ConvertibleExpression : PredicateExpression {
    func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate
}

private extension NSPredicate {
    func asExpression() -> NSExpression {
        NSExpression(forConditional: self, trueExpression: NSExpression(forConstantValue: true), falseExpression: NSExpression(forConstantValue: false))
    }
}

private extension NSExpression {
    func asPredicate() -> NSPredicate {
        NSComparisonPredicate(leftExpression: self, rightExpression: NSExpression(forConstantValue: true), modifier: .direct, type: .equalTo)
    }
}

extension PredicateExpression {
    private func _convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        var caughtError: Error?
        do {
            if let convertible = self as? any ConvertibleExpression {
                return try convertible.convert(state: &state)
            }
        } catch {
            caughtError = error
        }
        
        if let collapsedValue = try? self.evaluate(PredicateBindings()), let compatibleValue = try? _expressionCompatibleValue(for: collapsedValue) {
            return .expression(NSExpression(forConstantValue: compatibleValue))
        } else {
            throw caughtError ?? NSPredicateConversionError.unsupportedType
        }
    }
    
    fileprivate func convertToExpression(state: inout NSPredicateConversionState) throws -> NSExpression {
        switch try self._convert(state: &state) {
        case .expression(let expr): return expr
        case .predicate(let pred): return pred.asExpression()
        }
    }
    
    fileprivate func convertToPredicate(state: inout NSPredicateConversionState) throws -> NSPredicate {
        switch try self._convert(state: &state) {
        case .expression(let expr): return expr.asPredicate()
        case .predicate(let pred): return pred
        }
    }
}

private enum NSPredicateConversionError : Error {
    case unsupportedKeyPath
    case unsupportedConstant
    case unsupportedType
}

private extension String {
    static let subscriptSelector = "objectFrom:withIndex:"
    static let additionSelector = "add:to:"
    static let subtractionSelector = "from:subtract:"
    static let multiplicationSelector = "multiply:by:"
    static let divisionSelector = "divide:by:"
}

private func _expressionCompatibleValue(for value: Any) throws -> Any? {
    switch value {
    case Optional<Any>.none:
        return nil
    case _ as String, _ as Bool, _ as any Numeric, _ as UUID, _ as Date, _ as Data:
        return value
    case let c as Character:
        return String(c)
    case let sequence as any Sequence:
        return try sequence.map(_expressionCompatibleValue(for:))
    case let range as ClosedRange<Int>:
        return [range.lowerBound, range.upperBound]
    default:
        throw NSPredicateConversionError.unsupportedConstant
    }
}

extension PredicateExpressions.Value : ConvertibleExpression {
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        .expression(NSExpression(forConstantValue: try _expressionCompatibleValue(for: self.value)))
    }
}

extension PredicateExpressions.Variable : ConvertibleExpression {
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        .expression(state[key])
    }
}

extension PredicateExpressions.KeyPath : ConvertibleExpression {
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        let rootExpr = try root.convertToExpression(state: &state)
        
        func keyPathExpr(for string: String) -> NSExpression {
            if rootExpr.expressionType == .evaluatedObject {
                return NSExpression(forKeyPath: string)
            } else if rootExpr.expressionType == .keyPath {
                return NSExpression(forKeyPath: "\(rootExpr.keyPath).\(string)")
            } else {
                return NSKeyPathExpression(operand: rootExpr, andKeyPath: NSExpression._newKeyPathExpression(for: string))
            }
        }
        
        let countSyntax = (Root.Output.self == String.self || Root.Output.self == Substring.self) ? "length" : "@count"
        if let kvcString = keyPath._kvcKeyPathString {
            return .expression(keyPathExpr(for: kvcString))
        } else if let kind = self.kind {
            switch kind {
            case .collectionCount:
                return .expression(keyPathExpr(for: countSyntax))
            case .collectionIsEmpty:
                return .predicate(NSComparisonPredicate(leftExpression: keyPathExpr(for: countSyntax), rightExpression: NSExpression(forConstantValue: 0), modifier: .direct, type: .equalTo))
            case .collectionFirst:
                return .expression(NSExpression(forFunction: rootExpr, selectorName: .subscriptSelector, arguments: [NSExpression(forSymbolicString: "FIRST")!]))
            case .bidirectionalCollectionLast:
                return .expression(NSExpression(forFunction: rootExpr, selectorName: .subscriptSelector, arguments: [NSExpression(forSymbolicString: "LAST")!]))
            }
        } else {
            throw NSPredicateConversionError.unsupportedKeyPath
        }
    }
}

extension PredicateExpressions.Conjunction : ConvertibleExpression {
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        .predicate(NSCompoundPredicate(andPredicateWithSubpredicates: [try lhs.convertToPredicate(state: &state), try rhs.convertToPredicate(state: &state)]))
    }
}

extension PredicateExpressions.Disjunction : ConvertibleExpression {
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        .predicate(NSCompoundPredicate(orPredicateWithSubpredicates: [try lhs.convertToPredicate(state: &state), try rhs.convertToPredicate(state: &state)]))
    }
}

extension PredicateExpressions.Equal : ConvertibleExpression {
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        .predicate(NSComparisonPredicate(leftExpression: try lhs.convertToExpression(state: &state), rightExpression: try rhs.convertToExpression(state: &state), modifier: .direct, type: .equalTo))
    }
}

extension PredicateExpressions.NotEqual : ConvertibleExpression {
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        .predicate(NSComparisonPredicate(leftExpression: try lhs.convertToExpression(state: &state), rightExpression: try rhs.convertToExpression(state: &state), modifier: .direct, type: .notEqualTo))
    }
}

extension PredicateExpressions.Arithmetic : ConvertibleExpression {
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        let funcName: String = switch op {
        case .add: .additionSelector
        case .subtract: .subtractionSelector
        case .multiply: .multiplicationSelector
        }
        return .expression(NSExpression(forFunction: funcName, arguments: [try lhs.convertToExpression(state: &state), try rhs.convertToExpression(state: &state)]))
    }
}

extension PredicateExpressions.UnaryMinus : ConvertibleExpression {
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        .expression(NSExpression(forFunction: .multiplicationSelector, arguments: [try wrapped.convertToExpression(state: &state), NSExpression(forConstantValue: -1)]))
    }
}

extension PredicateExpressions.Comparison : ConvertibleExpression {
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        let type: NSComparisonPredicate.Operator = switch op {
        case .greaterThan: .greaterThan
        case .greaterThanOrEqual: .greaterThanOrEqualTo
        case .lessThan: .lessThan
        case .lessThanOrEqual: .lessThanOrEqualTo
        }
        return .predicate(NSComparisonPredicate(leftExpression: try lhs.convertToExpression(state: &state), rightExpression: try rhs.convertToExpression(state: &state), modifier: .direct, type: type))
    }
}

extension PredicateExpressions.Negation : ConvertibleExpression {
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        .predicate(NSCompoundPredicate(notPredicateWithSubpredicate: try wrapped.convertToPredicate(state: &state)))
    }
}

extension PredicateExpressions.Filter : ConvertibleExpression {
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        let local = state.makeLocalVariable(for: self.variable.key)
        return .expression(NSExpression(forSubquery: try sequence.convertToExpression(state: &state), usingIteratorVariable: local, predicate: try filter.convertToPredicate(state: &state)))
    }
}

extension PredicateExpressions.FloatDivision : ConvertibleExpression {
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        .expression(NSExpression(forFunction: .divisionSelector, arguments: [try lhs.convertToExpression(state: &state), try rhs.convertToExpression(state: &state)]))
    }
}

extension PredicateExpressions.ClosedRange : ConvertibleExpression {
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        .expression(NSExpression(forAggregate: [try lower.convertToExpression(state: &state), try upper.convertToExpression(state: &state)]))
    }
}

extension PredicateExpressions.SequenceContains : ConvertibleExpression {
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        .predicate(NSComparisonPredicate(leftExpression: try element.convertToExpression(state: &state), rightExpression: try sequence.convertToExpression(state: &state), modifier: .direct, type: (LHS.Output.self is any RangeExpression<Int>.Type) ? .between : .in))
    }
}

extension PredicateExpressions.SequenceContainsWhere : ConvertibleExpression {
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        let local = state.makeLocalVariable(for: self.variable.key)
        let subquery = NSExpression(forSubquery: try sequence.convertToExpression(state: &state), usingIteratorVariable: local, predicate: try test.convertToPredicate(state: &state))
        let count = NSKeyPathExpression(operand: subquery, andKeyPath: NSExpression._newKeyPathExpression(for: "@count"))!
        let equality = NSComparisonPredicate(leftExpression: count, rightExpression: NSExpression(forConstantValue: 0), modifier: .direct, type: .notEqualTo)
        return .predicate(equality)
    }
}

extension PredicateExpressions.SequenceAllSatisfy : ConvertibleExpression {
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        let local = state.makeLocalVariable(for: self.variable.key)
        let negatedTest = NSCompoundPredicate(notPredicateWithSubpredicate: try test.convertToPredicate(state: &state))
        let subquery = NSExpression(forSubquery: try sequence.convertToExpression(state: &state), usingIteratorVariable: local, predicate: negatedTest)
        let count = NSKeyPathExpression(operand: subquery, andKeyPath: NSExpression._newKeyPathExpression(for: "@count"))!
        let equality = NSComparisonPredicate(leftExpression: count, rightExpression: NSExpression(forConstantValue: 0), modifier: .direct, type: .equalTo)
        return .predicate(equality)
    }
}

extension PredicateExpressions.Conditional : ConvertibleExpression {
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        let predicate = try test.convertToPredicate(state: &state)
        let trueExpr = try trueBranch.convertToExpression(state: &state)
        let falseExpr = try falseBranch.convertToExpression(state: &state)
        return .expression(NSExpression(forConditional: predicate, trueExpression: trueExpr, falseExpression: falseExpr))
    }
}

extension PredicateExpressions.NilCoalesce : ConvertibleExpression {
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        let lhsExpr = try lhs.convertToExpression(state: &state)
        let rhsExpr = try rhs.convertToExpression(state: &state)
        let nullCheck = NSComparisonPredicate(leftExpression: lhsExpr, rightExpression: NSExpression(forConstantValue: nil), modifier: .direct, type: .notEqualTo)
        return .expression(NSExpression(forConditional: nullCheck, trueExpression: lhsExpr, falseExpression: rhsExpr))
    }
}

extension PredicateExpressions.OptionalFlatMap : ConvertibleExpression {
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        let wrappedExpr = try wrapped.convertToExpression(state: &state)
        state[self.variable.key] = wrappedExpr
        let transformExpr = try transform.convertToExpression(state: &state)
        let nullCheck = NSComparisonPredicate(leftExpression: wrappedExpr, rightExpression: NSExpression(forConstantValue: nil), modifier: .direct, type: .notEqualTo)
        return .expression(NSExpression(forConditional: nullCheck, trueExpression: transformExpr, falseExpression: NSExpression(forConstantValue: nil)))
    }
}

fileprivate protocol _CollectionIndexSubscriptConvertible : Collection {}
extension Array : _CollectionIndexSubscriptConvertible {}

extension PredicateExpressions.CollectionIndexSubscript : ConvertibleExpression where Wrapped.Output : _CollectionIndexSubscriptConvertible {
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        .expression(NSExpression(forFunction: .subscriptSelector, arguments: [try wrapped.convertToExpression(state: &state), try index.convertToExpression(state: &state)]))
    }
}

extension PredicateExpressions.DictionaryKeySubscript : ConvertibleExpression {
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        .expression(NSExpression(forFunction: .subscriptSelector, arguments: [try wrapped.convertToExpression(state: &state), try key.convertToExpression(state: &state)]))
    }
}

extension PredicateExpressions.CollectionContainsCollection : ConvertibleExpression where Base.Output : StringProtocol, Other.Output : StringProtocol {
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        .predicate(NSComparisonPredicate(leftExpression: try base.convertToExpression(state: &state), rightExpression: try other.convertToExpression(state: &state), modifier: .direct, type: .contains))
    }
}

extension PredicateExpressions.SequenceStartsWith : ConvertibleExpression where Base.Output : StringProtocol, Prefix.Output : StringProtocol {
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        .predicate(NSComparisonPredicate(leftExpression: try base.convertToExpression(state: &state), rightExpression: try prefix.convertToExpression(state: &state), modifier: .direct, type: .beginsWith))
    }
}

private protocol OverwritingInitializable {
    init(existing: Self)
}

extension OverwritingInitializable {
    init(existing: Self) {
        self = existing
    }
}

extension NSPredicate : OverwritingInitializable {}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension NSPredicate {
    public convenience init?<Input>(_ predicate: Predicate<Input>) where Input : NSObject {
        var state = NSPredicateConversionState(object: predicate.variable.key)
        guard let converted = try? predicate.expression.convertToPredicate(state: &state) else {
            return nil
        }
        self.init(existing: converted as! Self)
    }
}

#endif
