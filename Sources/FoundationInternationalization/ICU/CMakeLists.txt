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

target_include_directories(FoundationInternationalization PRIVATE .)
target_sources(FoundationInternationalization PRIVATE
    ICU+CaseMap.swift
    ICU+Enumeration.swift
    ICU+Enums.swift
    ICU+FieldPositer.swift
    ICU+Foundation.swift
    ICUPatternGenerator.swift)
