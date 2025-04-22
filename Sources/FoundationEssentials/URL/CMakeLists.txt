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
    URL.swift
    URL_Bridge.swift
    URL_ObjC.swift
    URL_Protocol.swift
    URL_Swift.swift
    URLComponents.swift
    URLComponents_ObjC.swift
    URLParser.swift
    URLTemplate_Expression.swift
    URLTemplate_PercentEncoding.swift
    URLTemplate_Substitution.swift
    URLTemplate_Value.swift
    URLTemplate_VariableName.swift
    URLTemplate.swift)
