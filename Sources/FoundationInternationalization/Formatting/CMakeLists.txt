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
    Date/Date+AnchoredRelativeFormatStyle.swift
    Date/Date+ComponentsFormatStyle+Stub.swift
    Date/Date+IntervalFormatStyle.swift
    Date/Date+RelativeFormatStyle.swift
    Date/Date+VerbatimFormatStyle.swift
    Date/DateFieldSymbol.swift
    Date/DateFormatString.swift
    Date/DateFormatStyle.swift
    Date/DateParseStrategy.swift
    Date/ICUDateFormatter.swift
    Date/ICUDateIntervalFormatter.swift
    Date/ICURelativeDateFormatter.swift
    
    Number/BinaryFloatingPoint+FormatStyle.swift
    Number/BinaryInteger+FormatStyle.swift
    Number/Decimal+FormatStyle.swift
    Number/Decimal+ParseStrategy.swift
    Number/FloatingPointFormatStyle.swift
    Number/FloatingPointParseStrategy.swift
    Number/ICULegacyNumberFormatter.swift
    Number/ICUNumberFormatter.swift
    Number/IntegerFormatStyle.swift
    Number/IntegerParseStrategy.swift
    Number/NumberAttributedFormat.swift
    Number/NumberFormatStyleConfiguration.swift
    
    ByteCountFormatStyle.swift
    Duration+Formatting.swift
    Duration+TimeFormatStyle.swift
    Duration+UnitsFormatStyle.swift
    ICUListFormatter.swift
    ListFormatStyle.swift
    Measurement+FormatStyle+Stub.swift)
