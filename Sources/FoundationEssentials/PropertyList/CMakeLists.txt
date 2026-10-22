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
    BPlistDecodingDocument.swift
    BPlistDecodingFormat.swift
    BPlistEncodingFormat.swift
    BPlistLegacyDecodingFormat.swift
    BPlistPrimitive.swift
    BPlistPrimitive+Scope.swift
    BPlistPrimitiveSource.swift
    BPlistScanner.swift
    OpenStepPlist.swift
    PlistDecoder.swift
    PlistDecoderGeneric.swift
    PlistDictionaryDecoder.swift
    PlistDictionaryEncoder.swift
    PlistEncoder.swift
    PlistEncoderGeneric.swift
    XMLPlistDecodingDocument.swift
    XMLPlistDecodingFormat.swift
    XMLPlistEncodingFormat.swift
    XMLPlistLegacyDecodingFormat.swift
    XMLPlistMap.swift
    XMLPlistMapBuildingSink.swift
    XMLPlistPrimitive.swift
    XMLPlistPrimitive+Scope.swift
    XMLPlistPrimitiveSource.swift
    XMLPlistScanner.swift
    XMLPlistScannerEventSource.swift)
