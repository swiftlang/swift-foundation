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

add_library(FoundationEssentials
    _ThreadLocal.swift
    Bundle+Stub.swift
    Codable.swift
    CodableUtilities.swift
    CodableWithConfiguration.swift
    ComparisonResult.swift
    Date.swift
    DateInterval.swift
    FoundationEssentials.swift
    IndexPath.swift
    LockedState.swift
    Logging.swift
    OutputBuffer.swift
    Platform.swift
    SortComparator.swift
    UUID_Wrappers.swift
    UUID.swift
    WASILibc+Extensions.swift
    WinSDK+Extensions.swift)

add_subdirectory(AttributedString)
add_subdirectory(Calendar)
add_subdirectory(Data)
add_subdirectory(Decimal)
add_subdirectory(Error)
add_subdirectory(FileManager)
add_subdirectory(Formatting)
add_subdirectory(JSON)
add_subdirectory(Locale)
add_subdirectory(Predicate)
add_subdirectory(ProcessInfo)
add_subdirectory(PropertyList)
add_subdirectory(String)
add_subdirectory(TimeZone)
add_subdirectory(URL)

if(CMAKE_SYSTEM_NAME STREQUAL Linux OR CMAKE_SYSTEM_NAME STREQUAL Android)
    target_compile_options(FoundationEssentials PRIVATE
        "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -Xcc -Xfrontend -D_GNU_SOURCE>")
    list(APPEND CMAKE_REQUIRED_DEFINITIONS -D_GNU_SOURCE)
endif()

target_compile_options(FoundationEssentials PRIVATE
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend VariadicGenerics>"
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend AccessLevelOnImport>"
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend StrictConcurrency>"
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-upcoming-feature -Xfrontend InferSendableFromCaptures>")
target_compile_options(FoundationEssentials PRIVATE ${_SwiftFoundation_availability_macros})
target_compile_options(FoundationEssentials PRIVATE ${_SwiftFoundation_wasi_libc_flags})
target_compile_options(FoundationEssentials PRIVATE -package-name "SwiftFoundation")

target_link_libraries(FoundationEssentials PUBLIC
    FoundationBuildMacros
    _FoundationCShims
    _FoundationCollections)
target_link_libraries(FoundationEssentials PUBLIC ${_SwiftFoundation_wasi_libc_libraries})

if(NOT BUILD_SHARED_LIBS)
    target_compile_options(FoundationEssentials PRIVATE
        "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -public-autolink-library -Xfrontend _FoundationCShims>")
    target_compile_options(FoundationEssentials PRIVATE
        "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -public-autolink-library -Xfrontend _FoundationCollections>")
    target_compile_options(FoundationEssentials PRIVATE
        "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -public-autolink-library -Xfrontend swiftSynchronization>")
endif()

set_target_properties(FoundationEssentials PROPERTIES
    INSTALL_RPATH "$ORIGIN"
    INSTALL_REMOVE_ENVIRONMENT_RPATH ON)

set_property(GLOBAL APPEND PROPERTY SWIFT_FOUNDATION_EXPORTS FoundationEssentials)
_swift_foundation_install_target(FoundationEssentials)
