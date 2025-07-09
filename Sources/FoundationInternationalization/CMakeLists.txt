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

add_library(FoundationInternationalization
    BinaryFloatingPoint.swift
    Date+ICU.swift
    Duration+Utils.swift
    RangeExpression.swift
    TimeInterval+Utils.swift
    URLParser+ICU.swift)

add_subdirectory(Calendar)
add_subdirectory(Formatting)
add_subdirectory(ICU)
add_subdirectory(Locale)
add_subdirectory(Predicate)
add_subdirectory(String)
add_subdirectory(TimeZone)

target_compile_options(FoundationInternationalization PRIVATE
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend AccessLevelOnImport>"
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend StrictConcurrency>"
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-upcoming-feature -Xfrontend InferSendableFromCaptures>"
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-upcoming-feature -Xfrontend MemberImportVisibility>")
target_compile_options(FoundationInternationalization PRIVATE ${_SwiftFoundation_availability_macros})
target_compile_options(FoundationInternationalization PRIVATE ${_SwiftFoundation_wasi_libc_flags})
target_compile_options(FoundationInternationalization PRIVATE -package-name "SwiftFoundation")

target_link_libraries(FoundationInternationalization PUBLIC
    FoundationEssentials
    _FoundationCShims
    _FoundationICU)
target_link_libraries(FoundationInternationalization PUBLIC ${_SwiftFoundation_wasi_libc_libraries})

if(NOT BUILD_SHARED_LIBS)
    target_compile_options(FoundationInternationalization PRIVATE
        "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -public-autolink-library -Xfrontend _FoundationCShims>")
    target_compile_options(FoundationInternationalization PRIVATE
        "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -public-autolink-library -Xfrontend _FoundationICU>")
    target_compile_options(FoundationEssentials PRIVATE
        "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -public-autolink-library -Xfrontend $<$<PLATFORM_ID:Windows>:${CMAKE_STATIC_LIBRARY_PREFIX_Swift}>swiftSynchronization>")
endif()

set_target_properties(FoundationInternationalization PROPERTIES
    INSTALL_RPATH "$ORIGIN"
    INSTALL_REMOVE_ENVIRONMENT_RPATH ON)

set_property(GLOBAL APPEND PROPERTY SWIFT_FOUNDATION_EXPORTS FoundationInternationalization)
_swift_foundation_install_target(FoundationInternationalization)
