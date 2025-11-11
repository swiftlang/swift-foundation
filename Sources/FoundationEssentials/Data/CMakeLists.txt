##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift open source project
##
## Copyright (c) 2024-2025 Apple Inc. and the Swift project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.md for the list of Swift project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

target_sources(FoundationEssentials PRIVATE
    Representations/Data+Inline.swift
    Representations/Data+InlineSlice.swift
    Representations/Data+LargeSlice.swift
    Representations/Data+Representation.swift
    Representations/DataStorage.swift
    
    Collections+DataProtocol.swift
    ContiguousBytes.swift
    Data.swift
    Data+Base64.swift
    Data+Bridging.swift
    Data+Deprecated.swift
    Data+Error.swift
    Data+Iterator.swift
    Data+Reading.swift
    Data+Searching.swift
    Data+Writing.swift
    DataProtocol.swift
    PathOrURL.swift
    Pointers+DataProtocol.swift)
