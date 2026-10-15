##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift open source project
##
## Copyright (c) 2026 Apple Inc. and the Swift project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.md for the list of Swift project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##
target_sources(FoundationEssentials PRIVATE
    CharacterSet.swift
    Annex.swift
    _CharacterSet.swift
    _CharacterSet+BitmapManipulationHelpers.swift
    _CharacterSet+ImmutableFunctions.swift
    _CharacterSet+MutableFunctions.swift
    _CharacterSet+SetAlgebra.swift
    _CharacterSet+StorageBitmap.swift
    _CharacterSet+StorageCompactBitmap.swift
    _CharacterSet+StorageConversionHelpers.swift
    _CharacterSet+StoragePredefined.swift
    _CharacterSet+StorageRange.swift
    _CharacterSet+StorageString.swift)
