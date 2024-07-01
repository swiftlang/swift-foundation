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

cmake_minimum_required(VERSION 3.24)

if(POLICY CMP0156)
    # Deduplicate linked libraries where appropriate
    cmake_policy(SET CMP0156 NEW)
endif()

if(POLICY CMP0157)
    # New Swift build model: improved incremental build performance and LSP support
    cmake_policy(SET CMP0157 NEW)
endif()

project(SwiftFoundation
    LANGUAGES C Swift)

if(NOT SWIFT_SYSTEM_NAME)
  if(CMAKE_SYSTEM_NAME STREQUAL Darwin)
    set(SWIFT_SYSTEM_NAME macosx)
  else()
    set(SWIFT_SYSTEM_NAME "$<LOWER_CASE:${CMAKE_SYSTEM_NAME}>")
  endif()
endif()

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_Swift_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/swift)

set(BUILD_TESTING NO)

set(COLLECTIONS_SINGLE_MODULE YES)
set(COLLECTIONS_FOUNDATION_TOOLCHAIN_MODULE YES)

# Make sure our dependencies exists
include(FetchContent)
if (_SwiftFoundationICU_SourceDIR)
    FetchContent_Declare(SwiftFoundationICU
        SOURCE_DIR ${_SwiftFoundationICU_SourceDIR})
else()
    FetchContent_Declare(SwiftFoundationICU
        GIT_REPOSITORY https://github.com/apple/swift-foundation-icu.git
        GIT_TAG 0.0.8)
endif()

if (_SwiftCollections_SourceDIR)
    FetchContent_Declare(SwiftCollections
        SOURCE_DIR ${_SwiftCollections_SourceDIR})
else()
    FetchContent_Declare(SwiftCollections
        GIT_REPOSITORY https://github.com/apple/swift-collections.git
        GIT_TAG 1.1.1)
endif()
FetchContent_MakeAvailable(SwiftFoundationICU SwiftCollections)

list(APPEND CMAKE_MODULE_PATH ${SwiftFoundation_SOURCE_DIR}/cmake/modules)

# Availability Macros (only applies to FoundationEssentials and FoundationInternationalization)
set(_SwiftFoundation_availability_macros)
list(APPEND _SwiftFoundation_availability_macros
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend \"AvailabilityMacro=FoundationPreview 0.1:macOS 13.3, iOS 16.4, tvOS 16.4, watchOS 9.4\">"
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend \"AvailabilityMacro=FoundationPreview 0.2:macOS 13.3, iOS 16.4, tvOS 16.4, watchOS 9.4\">"
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend \"AvailabilityMacro=FoundationPreview 0.3:macOS 13.3, iOS 16.4, tvOS 16.4, watchOS 9.4\">"
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend \"AvailabilityMacro=FoundationPreview 0.4:macOS 13.3, iOS 16.4, tvOS 16.4, watchOS 9.4\">"
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend \"AvailabilityMacro=FoundationPredicate 0.1:macOS 14, iOS 17, tvOS 17, watchOS 10\">"
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend \"AvailabilityMacro=FoundationPredicate 0.2:macOS 14, iOS 17, tvOS 17, watchOS 10\">"
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend \"AvailabilityMacro=FoundationPredicate 0.3:macOS 14, iOS 17, tvOS 17, watchOS 10\">"
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend \"AvailabilityMacro=FoundationPredicate 0.4:macOS 14, iOS 17, tvOS 17, watchOS 10\">"
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend \"AvailabilityMacro=FoundationPredicateRegex 0.1:macOS 10000, iOS 10000, tvOS 10000, watchOS 10000\">"
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend \"AvailabilityMacro=FoundationPredicateRegex 0.2:macOS 10000, iOS 10000, tvOS 10000, watchOS 10000\">"
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend \"AvailabilityMacro=FoundationPredicateRegex 0.3:macOS 10000, iOS 10000, tvOS 10000, watchOS 10000\">"
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend \"AvailabilityMacro=FoundationPredicateRegex 0.4:macOS 10000, iOS 10000, tvOS 10000, watchOS 10000\">")

include(GNUInstallDirs)
include(SwiftFoundationSwiftSupport)

add_subdirectory(Sources)
add_subdirectory(cmake/modules)
