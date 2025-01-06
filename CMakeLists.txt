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

# Don't enable WMO on Windows hosts due to linker failures, and the use of swift's
# old driver from build.ps1 when building for windows/android on a windows host.
if(NOT CMAKE_HOST_SYSTEM_NAME STREQUAL Windows)
    # Enable whole module optimization for release builds & incremental for debug builds
    if(POLICY CMP0157)
        set(CMAKE_Swift_COMPILATION_MODE "$<IF:$<CONFIG:Release>,wholemodule,incremental>")
    else()
        add_compile_options($<$<AND:$<COMPILE_LANGUAGE:Swift>,$<CONFIG:Release>>:-wmo>)
    endif()
endif()

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_Swift_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/swift)

set(BUILD_TESTING NO)

set(COLLECTIONS_SINGLE_MODULE YES)
set(COLLECTIONS_FOUNDATION_TOOLCHAIN_MODULE YES)

set(SwiftFoundation_MACRO "" CACHE STRING "Path to Foundation macro plugin")

# Make sure our dependencies exists
include(FetchContent)
if (_SwiftFoundationICU_SourceDIR)
    message(STATUS "_SwiftFoundationICU_SourceDIR provided, using swift-foundation-icu checkout at ${_SwiftFoundationICU_SourceDIR}")
    FetchContent_Declare(SwiftFoundationICU
        SOURCE_DIR ${_SwiftFoundationICU_SourceDIR})
else()
    message(STATUS "_SwiftFoundationICU_SourceDIR not provided, checking out local copy of swift-foundation-icu")
    FetchContent_Declare(SwiftFoundationICU
        GIT_REPOSITORY https://github.com/apple/swift-foundation-icu.git
        GIT_TAG 0.0.9)
endif()

if (_SwiftCollections_SourceDIR)
    message(STATUS "_SwiftCollections_SourceDIR provided, using swift-foundation-icu checkout at ${_SwiftCollections_SourceDIR}")
    FetchContent_Declare(SwiftCollections
        SOURCE_DIR ${_SwiftCollections_SourceDIR})
else()
    message(STATUS "_SwiftCollections_SourceDIR not provided, checking out local copy of swift-collections")
    FetchContent_Declare(SwiftCollections
        GIT_REPOSITORY https://github.com/apple/swift-collections.git
        GIT_TAG 1.1.2)
endif()
FetchContent_MakeAvailable(SwiftFoundationICU SwiftCollections)

list(APPEND CMAKE_MODULE_PATH ${SwiftFoundation_SOURCE_DIR}/cmake/modules)

# Availability Macros (only applies to FoundationEssentials and FoundationInternationalization)
set(_SwiftFoundation_BaseAvailability "macOS 13.3, iOS 16.4, tvOS 16.4, watchOS 9.4")
set(_SwiftFoundation_macOS14Availability "macOS 14, iOS 17, tvOS 17, watchOS 10")
set(_SwiftFoundation_macOS15Availability "macOS 15, iOS 18, tvOS 18, watchOS 11")
set(_SwiftFoundation_FutureAvailability "macOS 10000, iOS 10000, tvOS 10000, watchOS 10000")

# All versions to define for each availability name
list(APPEND _SwiftFoundation_versions
    "0.1"
    "0.2"
    "0.3"
    "0.4"
    "6.0.2"
    "6.1"
    "6.2"
    )

# Each availability name to define
list(APPEND _SwiftFoundation_availability_names
    "FoundationPreview"
    "FoundationPredicate"
    "FoundationPredicateRegex")

# The aligned availability for each name (in the same order)
list(APPEND _SwiftFoundation_availability_releases
    ${_SwiftFoundation_BaseAvailability}
    ${_SwiftFoundation_macOS14Availability}
    ${_SwiftFoundation_macOS15Availability})

foreach(version ${_SwiftFoundation_versions})
    foreach(name release IN ZIP_LISTS _SwiftFoundation_availability_names _SwiftFoundation_availability_releases)
        if(NOT DEFINED name OR NOT DEFINED release)
            message(FATAL_ERROR "_SwiftFoundation_availability_names and _SwiftFoundation_availability_releases are not the same length")
        endif()

        list(APPEND _SwiftFoundation_availability_macros
            "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend \"AvailabilityMacro=${name} ${version}:${release}\">")
    endforeach()
endforeach()

# wasi-libc emulation feature flags passed to the Swift compiler
set(_SwiftFoundation_wasi_libc_flags)
# wasi-libc emulation libraries to link against when building a shared library
set(_SwiftFoundation_wasi_libc_libraries)
if(CMAKE_SYSTEM_NAME STREQUAL "WASI")
    list(APPEND _SwiftFoundation_wasi_libc_flags
        "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xcc -D_WASI_EMULATED_GETPID>"
        "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xcc -D_WASI_EMULATED_SIGNAL>"
        "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xcc -D_WASI_EMULATED_MMAN>")
    if(BUILD_SHARED_LIBS)
        # Link emulation libraries to the shared library directly when building a shared library
        list(APPEND _SwiftFoundation_wasi_libc_libraries wasi-emulated-getpid wasi-emulated-signal wasi-emulated-mman)
    else()
        # Emit autolink entries to let clients to link against the emulation libraries
        list(APPEND _SwiftFoundation_wasi_libc_flags
            "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -public-autolink-library -Xfrontend wasi-emulated-getpid>"
            "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -public-autolink-library -Xfrontend wasi-emulated-signal>"
            "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -public-autolink-library -Xfrontend wasi-emulated-mman>")
    endif()
endif()

include(GNUInstallDirs)
include(SwiftFoundationSwiftSupport)

add_subdirectory(Sources)
add_subdirectory(cmake/modules)
