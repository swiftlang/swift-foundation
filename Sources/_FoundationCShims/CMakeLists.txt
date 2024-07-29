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

add_library(_FoundationCShims STATIC
    platform_shims.c
    string_shims.c
    uuid.c)

target_include_directories(_FoundationCShims PUBLIC include)

target_compile_options(_FoundationCShims INTERFACE
  "$<$<COMPILE_LANGUAGE:Swift>:SHELL:-Xcc -fmodule-map-file=${CMAKE_CURRENT_SOURCE_DIR}/include/module.modulemap>")

set_property(GLOBAL APPEND PROPERTY SWIFT_FOUNDATION_EXPORTS _FoundationCShims)

if(BUILD_SHARED_LIBS)
    set(install_directory swift)
else()
    set(install_directory swift_static)
endif()

# Copy Headers to known directory for direct client (XCTest) test builds
file(COPY
        include/
    DESTINATION
        ${CMAKE_BINARY_DIR}/_CModulesForClients/_FoundationCShims)

# Install headers
install(DIRECTORY
            include/
        DESTINATION
            lib/${install_directory}/_FoundationCShims)

if(NOT BUILD_SHARED_LIBS)
    get_swift_host_os(swift_os)
    install(TARGETS _FoundationCShims
        ARCHIVE DESTINATION lib/${install_directory}/${swift_os}
        LIBRARY DESTINATION lib/${install_directory}/${swift_os}
        RUNTIME DESTINATION bin)
endif()

