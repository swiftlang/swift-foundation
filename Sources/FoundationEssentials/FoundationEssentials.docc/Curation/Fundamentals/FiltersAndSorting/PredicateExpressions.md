# ``/FoundationEssentials/PredicateExpressions``


## Topics

### Building conditional expressions

- ``build_Conditional(_:_:_:)``
- ``Conditional``

### Building comparison expressions

- ``build_Equal(lhs:rhs:)``
- ``Equal``
- ``build_NotEqual(lhs:rhs:)``
- ``NotEqual``
- ``build_Comparison(lhs:rhs:op:)``
- ``Comparison``
- ``ComparisonOperator``

### Building mathmatical expressions
- ``build_Arithmetic(lhs:rhs:op:)``
- ``ArithmeticOperator``
- ``Arithmetic``
- ``build_Division(lhs:rhs:)->PredicateExpressions.IntDivision<LHS,RHS>``                         <!-- static func build_Division<LHS, RHS>(lhs: LHS, rhs: RHS) -> PredicateExpressions.IntDivision<LHS, RHS> where LHS : PredicateExpression, RHS : PredicateExpression, LHS.Output : BinaryInteger, LHS.Output == RHS.Output -->
- ``IntDivision``
- ``build_Division(lhs:rhs:)->PredicateExpressions.FloatDivision<LHS,RHS>``                       <!-- static func build_Division<LHS, RHS>(lhs: LHS, rhs: RHS) -> PredicateExpressions.FloatDivision<LHS, RHS> where LHS : PredicateExpression, RHS : PredicateExpression, LHS.Output : FloatingPoint, LHS.Output == RHS.Output -->
- ``FloatDivision``
- ``build_Remainder(lhs:rhs:)``
- ``IntRemainder``
- ``build_UnaryMinus(_:)``
- ``UnaryMinus``
- ``build_Negation(_:)``
- ``Negation``

### Building argument expressions

- ``build_Arg(_:)->PredicateExpressions.Value<T>``                                                <!-- static func build_Arg<T>(_ arg: T) -> PredicateExpressions.Value<T> -->
- ``build_Arg(_:)->T``                                                                            <!-- static func build_Arg<T>(_ arg: T) -> T where T : PredicateExpression -->
- ``build_Arg(_:)->PredicateExpressions.Value<PredicateExpressions.PredicateRegex>``              <!-- static func build_Arg(_ component: some RegexComponent) -> PredicateExpressions.Value<PredicateExpressions.PredicateRegex> -->
- ``Value``
- ``PredicateRegex``

### Building subscript expressions

- ``build_subscript(_:_:)->PredicateExpressions.CollectionIndexSubscript<Wrapped,Index>``         <!-- static func build_subscript<Wrapped, Index>(_ wrapped: Wrapped, _ index: Index) -> PredicateExpressions.CollectionIndexSubscript<Wrapped, Index> where Wrapped : PredicateExpression, Index : PredicateExpression, Wrapped.Output : Collection, Index.Output == Wrapped.Output.Index -->
- ``CollectionIndexSubscript``
- ``build_subscript(_:_:)->PredicateExpressions.CollectionRangeSubscript<Wrapped,Range>``         <!-- static func build_subscript<Wrapped, Range>(_ wrapped: Wrapped, _ range: Range) -> PredicateExpressions.CollectionRangeSubscript<Wrapped, Range> where Wrapped : PredicateExpression, Range : PredicateExpression, Wrapped.Output : Collection, Range.Output == Range<Wrapped.Output.Index> -->
- ``CollectionRangeSubscript``
- ``build_subscript(_:_:)->PredicateExpressions.DictionaryKeySubscript<Wrapped,Key,Value>``       <!-- static func build_subscript<Wrapped, Key, Value>(_ wrapped: Wrapped, _ key: Key) -> PredicateExpressions.DictionaryKeySubscript<Wrapped, Key, Value> where Wrapped : PredicateExpression, Key : PredicateExpression, Wrapped.Output == [Key.Output : Value], Key.Output : Hashable -->
- ``DictionaryKeySubscript``
- ``build_subscript(_:_:default:)``
- ``DictionaryKeyDefaultValueSubscript``

### Building containment expressions

- ``build_contains(_:_:)->PredicateExpressions.SequenceContains<LHS,RHS>``                        <!-- static func build_contains<LHS, RHS>(_ lhs: LHS, _ rhs: RHS) -> PredicateExpressions.SequenceContains<LHS, RHS> where LHS : PredicateExpression, RHS : PredicateExpression, LHS.Output : Sequence, RHS.Output : Equatable, RHS.Output == LHS.Output.Element -->
- ``SequenceContains``
- ``build_contains(_:_:)->PredicateExpressions.StringContainsRegex<Subject,Regex>``               <!-- static func build_contains<Subject, Regex>(_ subject: Subject, _ regex: Regex) -> PredicateExpressions.StringContainsRegex<Subject, Regex> where Subject : PredicateExpression, Regex : PredicateExpression, Subject.Output : BidirectionalCollection, Regex.Output : RegexComponent, Subject.Output.SubSequence == Substring -->
- ``StringContainsRegex``
- ``build_contains(_:_:)->PredicateExpressions.CollectionContainsCollection<Base,Other>``         <!-- static func build_contains<Base, Other>(_ base: Base, _ other: Other) -> PredicateExpressions.CollectionContainsCollection<Base, Other> where Base : PredicateExpression, Other : PredicateExpression, Base.Output : Collection, Other.Output : Collection, Base.Output.Element : Equatable, Base.Output.Element == Other.Output.Element -->
- ``CollectionContainsCollection``
- ``build_contains(_:_:)->PredicateExpressions.RangeExpressionContains<RangeExpression,Element>`` <!-- static func build_contains<RangeExpression, Element>(_ range: RangeExpression, _ element: Element) -> PredicateExpressions.RangeExpressionContains<RangeExpression, Element> where RangeExpression : PredicateExpression, Element : PredicateExpression, RangeExpression.Output : RangeExpression, Element.Output == RangeExpression.Output.Bound -->
- ``RangeExpressionContains``
- ``build_contains(_:where:)``
- ``SequenceContainsWhere``

### Building sequence expressions

- ``build_allSatisfy(_:_:)``
- ``SequenceAllSatisfy``
- ``build_filter(_:_:)``
- ``Filter``
- ``build_flatMap(_:_:)-36271``                                                                   <!-- static func build_flatMap<LHS, RHS, Wrapped, Result>(_ wrapped: LHS, _ builder: (PredicateExpressions.Variable<Wrapped>) -> RHS) -> PredicateExpressions.OptionalFlatMap<LHS, Wrapped, RHS, Result> where LHS : PredicateExpression, RHS : PredicateExpression, LHS.Output == Wrapped?, RHS.Output == Result? -->
- ``Variable``
- ``build_flatMap(_:_:)-g524``                                                                    <!-- static func build_flatMap<LHS, RHS, Wrapped, Result>(_ wrapped: LHS, _ builder: (PredicateExpressions.Variable<Wrapped>) -> RHS) -> PredicateExpressions.OptionalFlatMap<LHS, Wrapped, RHS, Result> where LHS : PredicateExpression, RHS : PredicateExpression, Result == RHS.Output, LHS.Output == Wrapped? -->
- ``OptionalFlatMap``
- ``build_starts(_:with:)``
- ``SequenceStartsWith``
- ``build_min(_:)``
- ``SequenceMinimum``
- ``build_max(_:)``
- ``SequenceMaximum``

### Building range expressions

- ``build_Range(lower:upper:)``
- ``Range``
- ``build_ClosedRange(lower:upper:)``
- ``ClosedRange``

### Building conjunction and disjunction expressions

- ``build_Conjunction(lhs:rhs:)``
- ``build_Disjunction(lhs:rhs:)``
- ``Disjunction``

### Building unwrap expressions

- ``build_ForcedUnwrap(_:)``
- ``ForcedUnwrap``

### Building key path expressions

- ``build_KeyPath(root:keyPath:)``
- ``KeyPath``

### Building evaluation expressions

- ``build_evaluate(_:_:)``
- ``ExpressionEvaluate``

### Building nil coalescing expressions

- ``build_NilCoalesce(lhs:rhs:)``
- ``NilCoalesce``

### Buildilng nil literal expressions

- ``build_NilLiteral()``
- ``NilLiteral``

### Supporting types

- ``ConditionalCast``
- ``ForceCast``
- ``TypeCheck``
- ``VariableID``
