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

add_library(FoundationBuildMacros INTERFACE)
export(TARGETS FoundationBuildMacros
    FILE
        ${SwiftFoundation_BINARY_DIR}/cmake/modules/FoundationBuildMacros.cmake)
if(SwiftFoundation_MACRO)
    message(STATUS "SwiftFoundation_MACRO provided, using macros in ${SwiftFoundation_MACRO}")
    target_compile_options(FoundationBuildMacros INTERFACE
        "SHELL:$<BUILD_INTERFACE:$<$<COMPILE_LANGUAGE:Swift>:-plugin-path ${SwiftFoundation_MACRO}>>")
else()
    message(STATUS "NO SwiftFoundation_MACRO, building macros from scratch")
    include(ExternalProject)
    # The macros are required for building Swift-Foundation. Build them for the
    # build machine.
    ExternalProject_Add(FoundationMacros
        SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/FoundationMacros"
        INSTALL_DIR "${CMAKE_CURRENT_BINARY_DIR}/FoundationMacros"
        CMAKE_ARGS
            -DCMAKE_BUILD_TYPE=Release
            -DCMAKE_Swift_COMPILER=${CMAKE_Swift_COMPILER}
            -DCMAKE_INSTALL_PREFIX=<INSTALL_DIR>
            -DSwiftFoundation_BUILD_EXECUTABLE_MACROS=YES)
    ExternalProject_Get_Property(FoundationMacros INSTALL_DIR)
    add_dependencies(FoundationBuildMacros FoundationMacros)
    if(CMAKE_HOST_WIN32)
        set(_SwiftFoundation_HOST_EXECUTABLE_SUFFIX .exe)
    endif()

    target_compile_options(FoundationBuildMacros INTERFACE
        "SHELL:$<BUILD_INTERFACE:$<$<COMPILE_LANGUAGE:Swift>:-load-plugin-executable ${INSTALL_DIR}/bin/FoundationMacros${_SwiftFoundation_HOST_EXECUTABLE_SUFFIX}#FoundationMacros>>")
    unset(_SwiftFoundation_HOST_EXECUTABLE_SUFFIX)
endif()

add_subdirectory(_FoundationCShims)
add_subdirectory(FoundationEssentials)
add_subdirectory(FoundationInternationalization)
