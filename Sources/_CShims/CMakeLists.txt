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

add_library(_CShims STATIC
    platform_shims.c
    string_shims.c
    uuid.c)

target_include_directories(_CShims PUBLIC include)

set_property(GLOBAL APPEND PROPERTY SWIFT_FOUNDATION_EXPORTS _CShims)

if(BUILD_SHARED_LIBS)
    set(install_directory swift)
else()
    set(install_directory swift_static)
endif()

# Install headers
install(DIRECTORY
            include/
        DESTINATION
            lib/${install_directory}/_CShims)

