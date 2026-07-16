##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift open source project
##
## Copyright (c) 2026 Apple Inc. and the Swift project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.md for the list of Swift project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

add_library(_FoundationInternationalizationData STATIC
    ListFormatData.c)

target_include_directories(_FoundationInternationalizationData PUBLIC include)

target_compile_options(_FoundationInternationalizationData INTERFACE
  "$<BUILD_INTERFACE:$<$<COMPILE_LANGUAGE:Swift>:SHELL:-Xcc -fmodule-map-file=${CMAKE_CURRENT_SOURCE_DIR}/include/module.modulemap>>")

set_property(GLOBAL APPEND PROPERTY SWIFT_FOUNDATION_EXPORTS _FoundationInternationalizationData)

if(BUILD_SHARED_LIBS)
    set(install_directory swift)
else()
    set(install_directory swift_static)
endif()

# Copy Headers to known directory for direct client (XCTest) test builds
file(COPY
        include/
    DESTINATION
        ${CMAKE_BINARY_DIR}/_CModulesForClients/_FoundationInternationalizationData)

# Install headers
install(DIRECTORY
            include/
        DESTINATION
            lib/${install_directory}/_FoundationInternationalizationData)

if(NOT BUILD_SHARED_LIBS)
    get_swift_host_os(swift_os)
    install(TARGETS _FoundationInternationalizationData
        ARCHIVE DESTINATION lib/${install_directory}/${swift_os}
        LIBRARY DESTINATION lib/${install_directory}/${swift_os}
        RUNTIME DESTINATION bin)
endif()

