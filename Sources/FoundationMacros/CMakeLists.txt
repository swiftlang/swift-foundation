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

cmake_minimum_required(VERSION 3.22)

if(POLICY CMP0156)
    # Deduplicate linked libraries where appropriate
    cmake_policy(SET CMP0156 NEW)
endif()
if(POLICY CMP0157)
    # New Swift build model: improved incremental build performance and LSP support
  cmake_policy(SET CMP0157 NEW)
endif()

project(FoundationMacros
  LANGUAGES Swift)

if(NOT SWIFT_SYSTEM_NAME)
  if(CMAKE_SYSTEM_NAME STREQUAL Darwin)
    set(SWIFT_SYSTEM_NAME macosx)
  else()
    set(SWIFT_SYSTEM_NAME "$<LOWER_CASE:${CMAKE_SYSTEM_NAME}>")
  endif()
endif()

# SwiftSyntax Dependency
find_package(SwiftSyntax QUIET)
if(NOT SwiftSyntax_FOUND)
  message(STATUS "SwiftSyntax_DIR not provided, checking out local copy of swift-syntax")
    include(FetchContent)

    # If building at desk, check out and link against the SwiftSyntax repo's targets
    FetchContent_Declare(SwiftSyntax
        GIT_REPOSITORY https://github.com/swiftlang/swift-syntax.git
        GIT_TAG main)
    FetchContent_MakeAvailable(SwiftSyntax)
else()
  message(STATUS "SwiftSyntax_DIR provided, using swift-syntax from ${SwiftSyntax_DIR}")
endif()

if(NOT FoundationMacros_BuildLocalExecutable)
    add_library(FoundationMacros SHARED)
    target_compile_definitions(FoundationMacros PRIVATE FOUNDATION_MACROS_LIBRARY)
else()
    add_executable(FoundationMacros)
    target_link_libraries(FoundationMacros PUBLIC
        SwiftSyntax::SwiftCompilerPlugin)
endif()

# Parse the module as a library, even if it's an executable, because it uses an `@main` type to define its entry point.
target_compile_options(FoundationMacros PRIVATE -parse-as-library)

target_sources(FoundationMacros PRIVATE
    FoundationMacros.swift
    BundleMacro.swift
    PredicateMacro.swift)

target_compile_options(FoundationMacros PRIVATE
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend AccessLevelOnImport>"
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend StrictConcurrency>"
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-upcoming-feature -Xfrontend InferSendableFromCaptures>"
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-upcoming-feature -Xfrontend MemberImportVisibility>")

target_link_libraries(FoundationMacros PUBLIC
    SwiftSyntax::SwiftSyntax
    SwiftSyntax::SwiftSyntaxMacros
    SwiftSyntax::SwiftDiagnostics
    SwiftSyntax::SwiftSyntaxBuilder
)

set_target_properties(FoundationMacros PROPERTIES
    ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib
    PDB_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin

    INTERFACE_INCLUDE_DIRECTORIES ${CMAKE_BINARY_DIR}/lib

    # The macro is installed into lib/swift/host/plugins, but needs to load
    # libraries from lib/swift/host and lib/swift/${SWIFT_SYSTEM_NAME}
    INSTALL_RPATH "$ORIGIN/../../../swift/${SWIFT_SYSTEM_NAME}:$ORIGIN/.."
    INSTALL_REMOVE_ENVIRONMENT_RPATH ON)

if(NOT FoundationMacros_BuildLocalExecutable)
    install(TARGETS FoundationMacros
        LIBRARY DESTINATION lib/swift/host/plugins
        RUNTIME DESTINATION bin)
endif()
