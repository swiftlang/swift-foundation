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
    BidirectionalCollection.swift
    BuiltInUnicodeScalarSet.swift
    RegexPatternCache.swift
    String+Bridging.swift
    String+Comparison.swift
    String+Encoding.swift
    String+EndianAdaptorSequence.swift
    String+Essentials.swift
    String+IO.swift
    String+Internals.swift
    String+Path.swift
    StringBlocks.swift
    StringProtocol+Essentials.swift
    StringProtocol+Stub.swift
    UnicodeScalar.swift)
