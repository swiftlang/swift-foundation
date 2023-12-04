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

#if canImport(Foundation_Private.NSExpression)
@_implementationOnly import Foundation_Private.NSExpression
@_implementationOnly import Foundation_Private.NSPredicate

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
    
    func addingKeyPath(_ keyPath: String) -> NSExpression {
        if self.expressionType == .evaluatedObject {
            return NSExpression(forKeyPath: keyPath)
        } else if self.expressionType == .keyPath && !self.keyPath.contains("@"){
            return NSExpression(forKeyPath: "\(self.keyPath).\(keyPath)")
        } else {
            return NSKeyPathExpression(operand: self, andKeyPath: NSExpression._newKeyPathExpression(for: keyPath))
        }
    }
}

extension PredicateExpression {
    fileprivate func convertToExpressionOrPredicate(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
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
        switch try self.convertToExpressionOrPredicate(state: &state) {
        case .expression(let expr): return expr
        case .predicate(let pred): return pred.asExpression()
        }
    }
    
    fileprivate func convertToPredicate(state: inout NSPredicateConversionState) throws -> NSPredicate {
        switch try self.convertToExpressionOrPredicate(state: &state) {
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

private protocol AnyClosedRange {
    var _bounds: (any Comparable, any Comparable) { get }
}

extension ClosedRange : AnyClosedRange {
    var _bounds: (any Comparable, any Comparable) {
        (lowerBound, upperBound)
    }
}

private func _expressionCompatibleValue(for value: Any) throws -> Any? {
    switch value {
    case Optional<Any>.none:
        return nil
    // Handle supported value types
    case is String, is UUID, is Date, is Data:
        return value
    // Handle supported numeric types
    case is Int, is Int8, is Int16, is Int32, is Int64,
        is UInt, is UInt8, is UInt16, is UInt32, is UInt64,
        is Float, is CGFloat, is Decimal, is Double,
        is Bool:
        return value
    case let result as ComparisonResult:
        return result.rawValue
    case let c as Character:
        return String(c)
    case let sequence as any Sequence:
        return try sequence.map(_expressionCompatibleValue(for:))
    case let range as any AnyClosedRange:
        return [try _expressionCompatibleValue(for: range._bounds.0), try _expressionCompatibleValue(for: range._bounds.1)]
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
        
        let countSyntax = (Root.Output.self == String.self || Root.Output.self == Substring.self) ? "length" : "@count"
        if let kvcString = keyPath._kvcKeyPathString {
            return .expression(rootExpr.addingKeyPath(kvcString))
        } else if let kind = self.kind {
            switch kind {
            case .collectionCount:
                return .expression(rootExpr.addingKeyPath(countSyntax))
            case .collectionIsEmpty:
                return .predicate(NSComparisonPredicate(leftExpression: rootExpr.addingKeyPath(countSyntax), rightExpression: NSExpression(forConstantValue: 0), modifier: .direct, type: .equalTo))
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

extension PredicateExpressions.PredicateEvaluate : ConvertibleExpression {
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        // Evaluate the subtree that provides the Predicate. We can only nest a predicate if the predicate is provided as a constant value
        guard let predicateValue = try? predicate.evaluate(.init()) else {
            throw NSPredicateConversionError.unsupportedType
        }
        
        repeat state[(each predicateValue.variable).key] = try (each input).convertToExpression(state: &state)
        return try predicateValue.expression.convertToExpressionOrPredicate(state: &state)
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
        .predicate(NSComparisonPredicate(leftExpression: try element.convertToExpression(state: &state), rightExpression: try sequence.convertToExpression(state: &state), modifier: .direct, type: (LHS.Output.self is any RangeExpression.Type) ? .between : .in))
    }
}

private protocol _RangeOperator {
    var _lower: any PredicateExpression { get }
    var _upper: any PredicateExpression { get }
}

extension PredicateExpressions.Range : _RangeOperator {
    var _lower: any PredicateExpression { self.lower }
    var _upper: any PredicateExpression { self.upper }
}

private enum AnyRange {
    case range(lower: any Comparable, upper: any Comparable)
    case closed(lower: any Comparable, upper: any Comparable)
    case from(lower: any Comparable)
    case through(upper: any Comparable)
    case upTo(upper: any Comparable)
}

extension RangeExpression {
    fileprivate var _anyRange: AnyRange? {
        switch self {
        case let range as Range<Bound>:
            .range(lower: range.lowerBound, upper: range.upperBound)
        case let closed as ClosedRange<Bound>:
            .closed(lower: closed.lowerBound, upper: closed.upperBound)
        case let from as PartialRangeFrom<Bound>:
            .from(lower: from.lowerBound)
        case let through as PartialRangeThrough<Bound>:
            .through(upper: through.upperBound)
        case let upTo as PartialRangeUpTo<Bound>:
            .upTo(upper: upTo.upperBound)
        default:
            nil
        }
    }
}

private protocol _RangeValue {
    var _anyRange: AnyRange? { get }
}

extension PredicateExpressions.Value : _RangeValue where Output : RangeExpression {
    fileprivate var _anyRange: AnyRange? {
        value._anyRange
    }
}

extension PredicateExpressions.RangeExpressionContains : ConvertibleExpression {
    private func _comparison(_ lhs: NSExpression, _ rhs: NSExpression, type: NSComparisonPredicate.Operator) -> NSPredicate {
        NSComparisonPredicate(leftExpression: lhs, rightExpression: rhs, modifier: .direct, type: type)
    }
    
    private func _expressionForBound(_ bound: any Comparable) throws -> NSExpression {
        NSExpression(forConstantValue: try _expressionCompatibleValue(for: bound))
    }
    
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        let elementExpr = try element.convertToExpression(state: &state)
        if let range = try? range.convertToExpression(state: &state) {
            // If the range can be converted to NSPredicate syntax, just use the BETWEEN operator
            return .predicate(_comparison(elementExpr, range, type: .between))
        } else if let rangeOp = range as? _RangeOperator {
            // Otherwise, if the range is formed via the range operator (..<) convert it to two comparison expressions
            // Note, the ClosedRange operator will unconditionally pass the above conversion if possible
            let lowerBoundExpr = try rangeOp._lower.convertToExpression(state: &state)
            let upperBoundExpr = try rangeOp._upper.convertToExpression(state: &state)
            return .predicate(NSCompoundPredicate(andPredicateWithSubpredicates: [
                _comparison(elementExpr, lowerBoundExpr, type: .greaterThanOrEqualTo),
                _comparison(elementExpr, upperBoundExpr, type: .lessThan)
            ]))
        } else if let rangeValue = (range as? _RangeValue)?._anyRange {
            // Otherwise, if the range is a captured value then convert it to appropriate comparison expressions based on the range type
            switch rangeValue {
            case let .range(upper, lower):
                let lowerBoundCondition = _comparison(elementExpr, try _expressionForBound(lower), type: .greaterThanOrEqualTo)
                let upperBoundCondition = _comparison(elementExpr, try _expressionForBound(upper), type: .lessThan)
                return .predicate(NSCompoundPredicate(andPredicateWithSubpredicates: [lowerBoundCondition, upperBoundCondition]))
            case let .closed(upper, lower):
                let lowerValue = try _expressionCompatibleValue(for: lower)
                let upperValue = try _expressionCompatibleValue(for: upper)
                return .predicate(NSComparisonPredicate(
                    leftExpression: elementExpr,
                    rightExpression: NSExpression(forConstantValue: [lowerValue, upperValue]),
                    modifier: .direct,
                    type: .between
                ))
            case let .from(lower):
                return .predicate(_comparison(elementExpr, try _expressionForBound(lower), type: .greaterThanOrEqualTo))
            case let .through(upper):
                return .predicate(_comparison(elementExpr, try _expressionForBound(upper), type: .lessThanOrEqualTo))
            case let .upTo(upper):
                return .predicate(_comparison(elementExpr, try _expressionForBound(upper), type: .lessThan))
            }
        } else {
            throw NSPredicateConversionError.unsupportedType
        }
    }
}

extension PredicateExpressions.SequenceContainsWhere : ConvertibleExpression {
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        let local = state.makeLocalVariable(for: self.variable.key)
        let subquery = NSExpression(forSubquery: try sequence.convertToExpression(state: &state), usingIteratorVariable: local, predicate: try test.convertToPredicate(state: &state))
        let count = subquery.addingKeyPath("@count")
        let equality = NSComparisonPredicate(leftExpression: count, rightExpression: NSExpression(forConstantValue: 0), modifier: .direct, type: .notEqualTo)
        return .predicate(equality)
    }
}

extension PredicateExpressions.SequenceAllSatisfy : ConvertibleExpression {
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        let local = state.makeLocalVariable(for: self.variable.key)
        let negatedTest = NSCompoundPredicate(notPredicateWithSubpredicate: try test.convertToPredicate(state: &state))
        let subquery = NSExpression(forSubquery: try sequence.convertToExpression(state: &state), usingIteratorVariable: local, predicate: negatedTest)
        let count = subquery.addingKeyPath("@count")
        let equality = NSComparisonPredicate(leftExpression: count, rightExpression: NSExpression(forConstantValue: 0), modifier: .direct, type: .equalTo)
        return .predicate(equality)
    }
}

extension PredicateExpressions.SequenceMaximum : ConvertibleExpression {
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        .expression(try elements.convertToExpression(state: &state).addingKeyPath("@max.self"))
    }
}

extension PredicateExpressions.SequenceMinimum : ConvertibleExpression {
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        .expression(try elements.convertToExpression(state: &state).addingKeyPath("@min.self"))
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

extension PredicateExpressions.NilLiteral : ConvertibleExpression {
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        .expression(NSExpression(forConstantValue: nil))
    }
}

extension ComparisonResult {
    fileprivate var expression: NSExpression {
        get throws {
            NSExpression(forConstantValue: try _expressionCompatibleValue(for: self))
        }
    }
}

extension NSComparisonPredicate.Options {
    fileprivate static var localized: Self {
        Self(rawValue: UInt(NSLocaleSensitivePredicateOption))
    }
}

private func _expressionForComparisonResult(_ lhs: some PredicateExpression, _ rhs: some PredicateExpression, state: inout NSPredicateConversionState, options: NSComparisonPredicate.Options) throws -> ExpressionOrPredicate {
    let equality = NSComparisonPredicate(leftExpression: try lhs.convertToExpression(state: &state), rightExpression: try rhs.convertToExpression(state: &state), modifier: .direct, type: .equalTo, options: options)
    let comparison = NSComparisonPredicate(leftExpression: try lhs.convertToExpression(state: &state), rightExpression: try rhs.convertToExpression(state: &state), modifier: .direct, type: .lessThan, options: options)
    let comparisonConditional = NSExpression(forConditional: comparison, trueExpression: try ComparisonResult.orderedAscending.expression, falseExpression: try ComparisonResult.orderedDescending.expression)
    let conditional = NSExpression(forConditional: equality, trueExpression: try ComparisonResult.orderedSame.expression, falseExpression: comparisonConditional)
    return .expression(conditional)
}

extension PredicateExpressions.StringCaseInsensitiveCompare : ConvertibleExpression {
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        try _expressionForComparisonResult(root, other, state: &state, options: .caseInsensitive)
    }
}

extension PredicateExpressions.StringLocalizedCompare : ConvertibleExpression {
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        try _expressionForComparisonResult(root, other, state: &state, options: .localized)
    }
}

extension PredicateExpressions.StringLocalizedStandardContains : ConvertibleExpression {
    fileprivate func convert(state: inout NSPredicateConversionState) throws -> ExpressionOrPredicate {
        .predicate(NSComparisonPredicate(leftExpression: try root.convertToExpression(state: &state), rightExpression: try other.convertToExpression(state: &state), modifier: .direct, type: .contains, options: [.caseInsensitive, .diacriticInsensitive, .localized]))
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

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension NSPredicate {
    public convenience init?<Input>(_ predicate: Predicate<Input>) where Input : NSObject {
        let variable = predicate.variable
        var state = NSPredicateConversionState(object: variable.key)
        guard let converted = try? predicate.expression.convertToPredicate(state: &state) else {
            return nil
        }
        self.init(existing: converted as! Self)
    }
}

#endif //canImport(Foundation_Private.NSExpression)
#endif
