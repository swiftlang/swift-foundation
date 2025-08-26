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
    AttributeContainer.swift
    AttributeScope.swift
    AttributedString+AttributeTransformation.swift
    AttributedString+CharacterView.swift
    AttributedString+Guts.swift
    AttributedString+IndexTracking.swift
    AttributedString+IndexValidity.swift
    AttributedString+Runs+AttributeSlices.swift
    AttributedString+Runs+Run.swift
    AttributedString+Runs.swift
    AttributedString+UnicodeScalarView.swift
    AttributedString+UTF8View.swift
    AttributedString+UTF16View.swift
    AttributedString+_InternalRun.swift
    AttributedString+_InternalRuns.swift
    AttributedString+_InternalRunsSlice.swift
    AttributedString.swift
    AttributedStringAttribute.swift
    AttributedStringAttributeConstrainingBehavior.swift
    AttributedStringAttributeStorage.swift
    AttributedStringCodable.swift
    AttributedStringProtocol.swift
    AttributedSubstring.swift
    Collection\ Stdlib\ Defaults.swift
    Conversion.swift
    DiscontiguousAttributedSubstring.swift
    FoundationAttributes.swift
    String.Index+ABI.swift)
