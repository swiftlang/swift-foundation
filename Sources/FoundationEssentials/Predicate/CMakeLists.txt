##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift open source project
##
## Copyright (c) 2024 Apple Inc. and the Swift project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.md for the list of Swift project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

target_sources(FoundationEssentials PRIVATE
    Archiving/EncodingContainers+PredicateExpression.swift
    Archiving/Predicate+Codable.swift
    Archiving/PredicateCodableConfiguration.swift
    Archiving/PredicateExpressionConstruction.swift
    
    Expressions/Aggregate.swift
    Expressions/Arithmetic.swift
    Expressions/Collection.swift
    Expressions/Comparison.swift
    Expressions/Conditional.swift
    Expressions/Conjunction.swift
    Expressions/Dictionary.swift
    Expressions/Disjunction.swift
    Expressions/Division.swift
    Expressions/Equality.swift
    Expressions/ExpressionEvaluation.swift
    Expressions/Filter.swift
    Expressions/Inequality.swift
    Expressions/Negation.swift
    Expressions/Optional.swift
    Expressions/PredicateEvaluation.swift
    Expressions/Range.swift
    Expressions/Regex.swift
    Expressions/Sequence.swift
    Expressions/StringComparison.swift
    Expressions/Types.swift
    Expressions/UnaryMinus.swift
    
    Expression.swift
    KeyPath+Inspection.swift
    NSPredicateConversion.swift
    Predicate+Description.swift
    Predicate.swift
    PredicateBindings.swift
    PredicateExpression.swift)
    