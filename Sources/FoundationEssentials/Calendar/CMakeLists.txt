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
    Calendar.swift
    Calendar_Autoupdating.swift
    Calendar_Cache.swift
    Calendar_Enumerate.swift
    Calendar_Gregorian.swift
    Calendar_Protocol.swift
    Calendar_Recurrence.swift
    Date+FormatStyle.swift
    Date+Locale.swift
    DateComponents.swift
    RecurrenceRule.swift)
