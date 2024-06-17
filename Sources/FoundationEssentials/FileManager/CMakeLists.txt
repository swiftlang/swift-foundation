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
    SearchPaths/FileManager+DarwinSearchPaths.swift
    SearchPaths/FileManager+SearchPaths.swift
    SearchPaths/FileManager+WindowsSearchPaths.swift
    SearchPaths/FileManager+XDGSearchPaths.swift

    FileManager+Basics.swift
    FileManager+Bridge.swift
    FileManager+Directories.swift
    FileManager+Files.swift
    FileManager+SymbolicLinks.swift
    FileManager+Utilities.swift
    FileOperations+Enumeration.swift
    FileOperations.swift
    SwiftFileManager.swift
    SwiftFileManagerDelegate.swift)
